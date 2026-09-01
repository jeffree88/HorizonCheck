local M={};
local HC;

local function trim(v)
    local s=tostring(v or '');
    s=s:gsub('^%s+',''):gsub('%s+$','');
    return s;
end

local function compact_reason(reason)
    local s=trim(reason);
    if s=='' then return 'Progression requirement not satisfied'; end
    s=s:gsub('^Requires started quest:%s*','Need quest started: ');
    s=s:gsub('^Requires key item:%s*','Need key item: ');
    s=s:gsub('^Requires mission progress:%s*','Need mission progress: ');
    s=s:gsub('^Requires active mission:%s*','Need active mission: ');
    s=s:gsub('^Requires%s+','Need ');
    return s;
end

local function same_quest(node,log_id,quest_id)
    return type(node)=='table' and tonumber(node.log_id)==tonumber(log_id) and tonumber(node.quest_id)==tonumber(quest_id);
end

-- Explain a quest's current blocker in player-facing terms. Availability remains
-- authoritative in modules/quests.lua; this layer only turns that evidence into
-- a concise dependency chain and identifies the next mapped actionable quest.
function M.quest(c,log_id,quest_id,state,reason)
    local q=HC and HC.modules and HC.modules.quests or nil;
    if not q then return {state='UNKNOWN',summary='Quest tracker unavailable',raw_reason='Quest tracker unavailable'}; end
    if state==nil and q.availability then
        local ok,a,r=pcall(q.availability,c,log_id,quest_id);
        if ok then state=a; reason=r; end
    end
    state=tostring(state or 'UNKNOWN');
    reason=trim(reason);
    local out={
        state=state,
        raw_reason=reason,
        summary=compact_reason(reason),
        category='requirement',
        chain={},
        next_action=nil,
        action_log_id=nil,
        action_quest_id=nil,
    };

    if state~='LOCKED' and state~='CHECK' and state~='MANUAL' and state~='UNKNOWN' then return out; end

    local graph=HC.modules and HC.modules.questgraph or nil;
    if not (graph and graph.trace) then return out; end
    local ok,tr=pcall(graph.trace,c,log_id,quest_id,16);
    if not ok or type(tr)~='table' then return out; end
    out.trace=tr;

    local path=type(tr.path)=='table' and tr.path or {};
    for i=2,#path do
        local step=path[i]; local node=step and step.node or nil;
        if node then
            out.chain[#out.chain+1]={
                log_id=tonumber(node.log_id),quest_id=tonumber(node.quest_id),name=tostring(node.name or 'Quest'),state=tostring(step.state or 'UNKNOWN')
            };
        end
    end

    local direct=out.chain[1];
    local actionable=tr.first_actionable;
    local anode=actionable and actionable.node or nil;
    if anode and not same_quest(anode,log_id,quest_id) then
        out.next_action=tostring(anode.name or 'Quest');
        out.action_log_id=tonumber(anode.log_id);
        out.action_quest_id=tonumber(anode.quest_id);
    end

    if direct then
        out.category='quest';
        if out.next_action then
            if tonumber(direct.log_id)==tonumber(out.action_log_id) and tonumber(direct.quest_id)==tonumber(out.action_quest_id) then
                out.summary='Need '..tostring(direct.name)..' — ready to work on now';
            else
                out.summary='Need '..tostring(direct.name)..' → do '..tostring(out.next_action)..' next';
            end
        else
            out.summary='Need '..tostring(direct.name);
            if tr.reason and trim(tr.reason)~='' then out.summary=out.summary..' — '..compact_reason(tr.reason); end
        end
    elseif out.next_action then
        out.category='quest';
        out.summary='Do '..tostring(out.next_action)..' next';
    end

    if #out.chain>0 then
        local names={};
        for i=1,math.min(4,#out.chain) do names[#names+1]=tostring(out.chain[i].name); end
        out.chain_text=table.concat(names,' → ');
        if #out.chain>4 then out.chain_text=out.chain_text..' +'..tostring(#out.chain-4); end
    else
        out.chain_text='';
    end
    return out;
end

function M.summary(c,log_id,quest_id,state,reason)
    return M.quest(c,log_id,quest_id,state,reason).summary;
end

function M.status()
    return {ready=(HC and HC.modules and HC.modules.quests~=nil and HC.modules.questgraph~=nil)};
end

function M.init(ctx) HC=ctx; end
return M;
