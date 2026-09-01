local M = {};
local HC;
local cache={at=0,graph=nil};

local function key(log_id,quest_id)
    return tostring(tonumber(log_id) or log_id)..':'..tostring(tonumber(quest_id) or quest_id);
end

local function qmod()
    return HC and HC.modules and HC.modules.quests or nil;
end

local function build_graph(force)
    local now=os.time();
    if not force and cache.graph and now-(tonumber(cache.at) or 0)<10 then return cache.graph; end
    local q=qmod();
    local g={nodes={},edges={},reverse={},missing={},self_edges={},cycles={}};
    if not q or type(q.catalog_entries)~='function' then cache={at=now,graph=g}; return g; end

    local entries=q.catalog_entries() or {};
    for _,rec in ipairs(entries) do
        local k=key(rec.log_id,rec.quest_id);
        g.nodes[k]={key=k,log_id=tonumber(rec.log_id),quest_id=tonumber(rec.quest_id),name=tostring(rec.name or ''),detail=rec.detail or {}};
        g.edges[k]={};
        g.reverse[k]={};
    end

    local function add_edge(from,to_log,to_id,kind)
        local tk=key(to_log,to_id);
        local edge={from=from,to=tk,log_id=tonumber(to_log),quest_id=tonumber(to_id),kind=kind};
        g.edges[from]=g.edges[from] or {};
        g.edges[from][#g.edges[from]+1]=edge;
        if from==tk then g.self_edges[#g.self_edges+1]=edge; end
        if g.nodes[tk] then
            g.reverse[tk]=g.reverse[tk] or {};
            g.reverse[tk][#g.reverse[tk]+1]=edge;
        else
            g.missing[#g.missing+1]=edge;
        end
    end

    for k,node in pairs(g.nodes) do
        local req=type(node.detail.requirements)=='table' and node.detail.requirements or {};
        if type(req.quests)=='table' then
            for _,r in ipairs(req.quests) do
                local l=tonumber(r.log_id or r.log); local i=tonumber(r.quest_id or r.id);
                if l~=nil and i~=nil then add_edge(k,l,i,'complete'); end
            end
        end
        if type(req.quests_started)=='table' then
            for _,r in ipairs(req.quests_started) do
                local l=tonumber(r.log_id or r.log); local i=tonumber(r.quest_id or r.id);
                if l~=nil and i~=nil then add_edge(k,l,i,'started'); end
            end
        end
    end

    -- Static cycle detection over the final merged catalog graph.
    local color={}; local stack={}; local stack_pos={}; local seen_cycle={};
    local function dfs(k)
        color[k]=1; stack[#stack+1]=k; stack_pos[k]=#stack;
        for _,e in ipairs(g.edges[k] or {}) do
            local to=e.to;
            if g.nodes[to] then
                if color[to]==nil then
                    dfs(to);
                elseif color[to]==1 then
                    local start=stack_pos[to] or 1; local cycle={};
                    for i=start,#stack do cycle[#cycle+1]=stack[i]; end
                    cycle[#cycle+1]=to;
                    local sig=table.concat(cycle,'>');
                    if not seen_cycle[sig] then seen_cycle[sig]=true; g.cycles[#g.cycles+1]=cycle; end
                end
            end
        end
        stack_pos[k]=nil; table.remove(stack); color[k]=2;
    end
    for k in pairs(g.nodes) do if color[k]==nil then dfs(k); end end

    for _,lst in pairs(g.edges) do table.sort(lst,function(a,b) return a.to<b.to; end); end
    for _,lst in pairs(g.reverse) do table.sort(lst,function(a,b) return a.from<b.from; end); end
    cache={at=now,graph=g};
    return g;
end

local function edge_satisfied(edge)
    local q=qmod(); if not q then return nil; end
    if edge.kind=='started' and type(q.started_or_completed)=='function' then
        return q.started_or_completed(edge.log_id,edge.quest_id);
    end
    if type(q.is_completed)=='function' then return q.is_completed(edge.log_id,edge.quest_id); end
    return nil;
end

local function node_runtime(c,node)
    local q=qmod();
    if not q or not node then return 'UNKNOWN','quest module unavailable'; end
    if q.is_active and q.is_active(node.log_id,node.quest_id)==true then return 'ACTIVE','native quest log'; end
    local done=q.is_completed and q.is_completed(node.log_id,node.quest_id) or nil;
    if done==true and not (q.is_repeatable and q.is_repeatable(node.log_id,node.quest_id)) then return 'COMPLETED','native completed history'; end
    if q.availability then
        local ok,a,r=pcall(q.availability,c,node.log_id,node.quest_id);
        if ok then return a or 'UNKNOWN',r or ''; end
    end
    return 'UNKNOWN','availability unavailable';
end

local function choose_trace(c,g,k,visiting,depth,max_depth)
    local node=g.nodes[k];
    if not node then return {path={},terminal='MISSING',reason='Prerequisite quest is not in the mapped catalog'}; end
    depth=depth or 0; max_depth=max_depth or 16;
    if depth>max_depth then return {path={{key=k,node=node,state='UNKNOWN'}},terminal='DEPTH',reason='Dependency depth limit reached'}; end
    if visiting[k] then return {path={{key=k,node=node,state='CYCLE'}},terminal='CYCLE',reason='Circular quest dependency detected'}; end

    local state,reason=node_runtime(c,node);
    local head={key=k,node=node,state=state,reason=reason};
    if state=='AVAILABLE' or state=='ACTIVE' then
        return {path={head},terminal='ACTIONABLE',first_actionable=head};
    end
    if state=='COMPLETED' then return {path={head},terminal='COMPLETED'}; end

    local unresolved={};
    for _,e in ipairs(g.edges[k] or {}) do
        local sat=edge_satisfied(e);
        if sat~=true then unresolved[#unresolved+1]={edge=e,satisfied=sat}; end
    end
    if #unresolved==0 then
        return {path={head},terminal=state,reason=reason};
    end

    visiting[k]=true;
    local best=nil;
    for _,u in ipairs(unresolved) do
        local tr=choose_trace(c,g,u.edge.to,visiting,depth+1,max_depth);
        local p={head}; for _,x in ipairs(tr.path or {}) do p[#p+1]=x; end
        tr.path=p;
        tr.via=u.edge;
        local score=(tr.first_actionable and 0 or 1000)+#p;
        if not best or score<best.score then tr.score=score; best=tr; end
    end
    visiting[k]=nil;
    return best or {path={head},terminal=state,reason=reason};
end

function M.trace(c,log_id,quest_id,max_depth)
    local g=build_graph(false); local k=key(log_id,quest_id);
    local tr=choose_trace(c,g,k,{},0,max_depth or 16);
    tr.target=k;
    tr.direct_dependencies=#(g.edges[k] or {});
    tr.direct_dependents=#(g.reverse[k] or {});
    return tr;
end

function M.direct_dependencies(log_id,quest_id)
    local g=build_graph(false); local out={};
    for _,e in ipairs(g.edges[key(log_id,quest_id)] or {}) do
        local n=g.nodes[e.to];
        out[#out+1]={log_id=e.log_id,quest_id=e.quest_id,name=n and n.name or e.to,kind=e.kind,missing=n==nil};
    end
    return out;
end

function M.direct_dependents(log_id,quest_id)
    local g=build_graph(false); local out={};
    for _,e in ipairs(g.reverse[key(log_id,quest_id)] or {}) do
        local n=g.nodes[e.from];
        if n then out[#out+1]={log_id=n.log_id,quest_id=n.quest_id,name=n.name,kind=e.kind}; end
    end
    return out;
end

function M.transitive_dependents(log_id,quest_id)
    local g=build_graph(false); local start=key(log_id,quest_id); local seen={[start]=true}; local queue={start}; local out={};
    local qi=1;
    while qi<=#queue do
        local cur=queue[qi]; qi=qi+1;
        for _,e in ipairs(g.reverse[cur] or {}) do
            if not seen[e.from] then
                seen[e.from]=true; queue[#queue+1]=e.from;
                local n=g.nodes[e.from]; if n then out[#out+1]={log_id=n.log_id,quest_id=n.quest_id,name=n.name,key=e.from}; end
            end
        end
    end
    table.sort(out,function(a,b) return string.lower(a.name)<string.lower(b.name); end);
    return out;
end

function M.path_text(trace)
    local parts={};
    for _,r in ipairs((trace and trace.path) or {}) do
        local name=(r.node and r.node.name~='' and r.node.name) or tostring(r.key or '?');
        parts[#parts+1]=name..' ['..tostring(r.state or '?')..']';
    end
    return table.concat(parts,' -> ');
end

function M.summary(force)
    local g=build_graph(force==true); local edge_count=0;
    for _,lst in pairs(g.edges) do edge_count=edge_count+#lst; end
    local node_count=0; for _ in pairs(g.nodes) do node_count=node_count+1; end
    return {nodes=node_count,edges=edge_count,missing=#g.missing,self_edges=#g.self_edges,cycles=#g.cycles,missing_rows=g.missing,cycle_rows=g.cycles};
end

function M.invalidate() cache={at=0,graph=nil}; end

-- Small synthetic analyzer used by regression tests without touching live quest data.
function M.analyze_nodes(nodes)
    local missing=0; local self_edges=0; local adj={}; local known={};
    for k in pairs(nodes or {}) do known[k]=true; adj[k]={}; end
    for k,n in pairs(nodes or {}) do
        for _,to in ipairs((type(n)=='table' and n.deps) or {}) do
            adj[k][#adj[k]+1]=to;
            if to==k then self_edges=self_edges+1; end
            if not known[to] then missing=missing+1; end
        end
    end
    local color={}; local cycles=0;
    local function dfs(k)
        color[k]=1;
        for _,to in ipairs(adj[k] or {}) do
            if known[to] then
                if color[to]==nil then dfs(to); elseif color[to]==1 then cycles=cycles+1; end
            end
        end
        color[k]=2;
    end
    for k in pairs(known) do if color[k]==nil then dfs(k); end end
    return {missing=missing,self_edges=self_edges,cycles=cycles};
end

function M.init(ctx) HC=ctx; end
return M;
