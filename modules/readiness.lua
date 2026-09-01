local M={};
local HC;
local cache={at=0,char=nil,data=nil};
local CACHE_SECONDS=1;

local function lower(v) return string.lower(tostring(v or '')); end
local function upper(v) return string.upper(tostring(v or '')); end

local function current_char(c)
    return type(c)=='table' and c or (HC and HC.modules and HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
end

local function row(id,label,state,reason,tab,focus,priority,extra)
    local r={
        id=tostring(id or ''), label=tostring(label or id or ''), state=upper(state or 'UNKNOWN'),
        reason=tostring(reason or ''), tab=tab, focus=focus, priority=tonumber(priority) or 100,
    };
    for k,v in pairs(type(extra)=='table' and extra or {}) do r[k]=v; end
    r.done=(r.state=='DONE' or r.state=='COMPLETE' or r.state=='DONE TODAY' or r.state=='DONE THIS WEEK');
    return r;
end

local function system_row(c,id,label,tab,priority)
    local systems=HC.modules and HC.modules.systems or nil;
    if not (systems and systems.get) then return nil; end
    local ok,s=pcall(systems.get,id,c); if not ok or type(s)~='table' then return nil; end
    local st=upper(s.state or 'UNKNOWN');
    if st=='WAITING' then st='PREP'; elseif st=='UNKNOWN' then st='VERIFY'; end
    return row(id,label,st,s.reason or '',tab,nil,priority,{
        reset=s.reset, remaining=s.remaining, used=s.used, total=s.total,
    });
end

local function avatar_row(c)
    local w=HC.modules and HC.modules.weekly or nil;
    if not (w and w.daily_avatar_summary) then return nil; end
    local ok,s=pcall(w.daily_avatar_summary,c); if not ok or type(s)~='table' then return nil; end
    local total=tonumber(s.total) or 0; local completed=tonumber(s.completed) or 0; local held=tonumber(s.held) or 0; local checking=tonumber(s.checking) or 0;
    local state='PREP'; local reason=string.format('%d/%d completed today | %d key item(s) held',completed,total,held);
    if total>0 and completed>=total then state='DONE'; reason=string.format('%d/%d completed today',completed,total);
    elseif held>0 then state='READY';
    elseif checking>0 then state='VERIFY'; reason=reason..' | '..tostring(checking)..' checking'; end
    return row('avatars','Daily Avatar Fights',state,reason,'dailyweekly',{section='avatars'},22,{completed=completed,total=total,held=held});
end

local function eco_row(c)
    local m=HC.modules and HC.modules.eco or nil; if not m then return nil; end
    local done,total=0,3;
    if m.rotation_count then local ok,a,b=pcall(m.rotation_count,c); if ok then done=tonumber(a) or 0; total=tonumber(b) or 3; end end
    if done>=total then return row('eco','Eco-Warrior','DONE',string.format('%d/%d rotation cleared',done,total),'eco',nil,35,{completed=done,total=total}); end
    local states={};
    if m.sandoria_status then local ok,v=pcall(m.sandoria_status,c); if ok and v then states[#states+1]="San d'Oria: "..tostring(v); end end
    if m.windurst_status then local ok,v=pcall(m.windurst_status,c); if ok and v then states[#states+1]='Windurst: '..tostring(v); end end
    local active=(type(c.eco)=='table' and c.eco.active~=nil); for _,v in ipairs(states) do if v:find('IN PROGRESS',1,true) or v:find('RETURN TO',1,true) or v:find('KEY ITEM READY',1,true) or v:find('KILL PHASE',1,true) or v:find('FIELD PHASE',1,true) then active=true; break; end end
    return row('eco','Eco-Warrior',active and 'ACTIVE' or 'READY',string.format('%d/%d rotation cleared',done,total),'eco',nil,30,{completed=done,total=total});
end

local function chocobo_row(c)
    local m=HC.modules and HC.modules.chocobo or nil; if not (m and m.status) then return nil; end
    local ok,s=pcall(m.status,c); if not ok then return nil; end
    s=tostring(s or ''); local st='READY';
    if s:find('IN PROGRESS',1,true) then st='ACTIVE'; elseif s:find('COMPLETE',1,true) then st='DONE'; end
    return row('chocobo','Chocobo Riding',st,s,'chocobo',nil,38);
end

local function blackcoffin_row(c)
    local m=HC.modules and HC.modules.blackcoffin or nil; if not (m and m.status) then return nil; end
    local ok,s=pcall(m.status,c); if not ok then return nil; end
    s=tostring(s or ''); local st='READY';
    if s:find('COMPLETE',1,true) then st='DONE'; elseif s:find('FAILED',1,true) then st='LOCKED'; elseif s:find('IN PROGRESS',1,true) or s:find('ACTIVE',1,true) then st='ACTIVE'; end
    return row('blackcoffin','Black Coffin',st,s,'blackcoffin',nil,34);
end

local function enm_aggregate(c)
    local m=HC.modules and HC.modules.enm or nil; if not m then return nil; end
    local candidates=0; local ki_ready=0;
    if m.attention_rows then
        local ok,rows=pcall(m.attention_rows,c); if ok then
            for _,x in ipairs(rows or {}) do
                local t=tostring(x.text or '');
                if t:find('KEY ITEM READY',1,true) then candidates=candidates+1; ki_ready=ki_ready+1;
                elseif t:find('AVAILABLE',1,true) then candidates=candidates+1; end
            end
        end
    end
    local timer_ready,total=0,0;
    if m.ready_count then local ok,a,b=pcall(m.ready_count,c); if ok then timer_ready=tonumber(a) or 0; total=tonumber(b) or 0; end end
    local st=candidates>0 and 'READY' or ((timer_ready>0) and 'VERIFY' or 'COOLDOWN');
    local reason='';
    if candidates>0 then reason=string.format('%d ENM group(s) actionable | %d key item ready',candidates,ki_ready);
    elseif timer_ready>0 then reason=string.format('%d/%d timer-ready; verify entry prerequisite / key item',timer_ready,total);
    else reason='No ENM group currently timer-ready'; end
    return row('enm','ENM',st,reason,'enm',nil,18,{ready=candidates,timer_ready=timer_ready,total=total});
end

local function build(c)
    c=current_char(c); c.weekly=type(c.weekly)=='table' and c.weekly or {};
    local rows={}; local function add(r) if type(r)=='table' then rows[#rows+1]=r; end end
    add(system_row(c,'dynamis','Dynamis','dynamis',10));
    local lim=system_row(c,'limbus','Limbus','dailyweekly',12); if lim then lim.focus={section='weekly',objective='limbus'}; add(lim); end
    add(system_row(c,'assault','Assault','assault',14));
    local isnm=system_row(c,'isnm','ISNM','dailyweekly',16); if isnm then isnm.focus={section='daily',objective='isnm'}; add(isnm); end
    add(enm_aggregate(c));
    add(avatar_row(c));
    add(eco_row(c));
    add(blackcoffin_row(c));
    add(chocobo_row(c));

    table.sort(rows,function(a,b)
        local rank={ACTIVE=1,READY=2,VERIFY=3,PREP=4,COOLDOWN=5,LOCKED=6,DONE=9,COMPLETE=9};
        local ar=rank[a.state] or 7; local br=rank[b.state] or 7;
        if ar~=br then return ar<br; end
        if a.priority~=b.priority then return a.priority<b.priority; end
        return lower(a.label)<lower(b.label);
    end);
    local counts={}; for _,r in ipairs(rows) do counts[r.state]=(counts[r.state] or 0)+1; end
    return {at=os.time(),rows=rows,counts=counts};
end

function M.snapshot(c,force)
    c=current_char(c);
    local char=(HC.modules.core and HC.modules.core.character_name and HC.modules.core.character_name()) or 'Unknown'; local now=os.time();
    if force~=true and cache.data and cache.char==char and now-(tonumber(cache.at) or 0)<CACHE_SECONDS then return cache.data; end
    local data=build(c); cache={at=now,char=char,data=data}; return data;
end

function M.rows(c,include_done)
    local s=M.snapshot(c,false); local out={};
    for _,r in ipairs(s.rows or {}) do if include_done==true or r.done~=true then out[#out+1]=r; end end
    return out;
end

local function same_zone(a,b)
    local function norm(v)
        local s=lower(v):gsub('%s*%b()',''):gsub(',%s*north$',''):gsub(',%s*south$','');
        return s:gsub('^%s+',''):gsub('%s+$','');
    end
    a=norm(a); b=norm(b); return a~='' and b~='' and a==b;
end

function M.zone_rows(c,zone_name)
    c=current_char(c); local zone=tostring(zone_name or ''); if zone=='' or lower(zone)=='unknown' then return {}; end
    local out={};

    -- Outpost intelligence is useful exactly when the player is already in the
    -- corresponding region. Do not guess ownership: only a verified snapshot
    -- suppresses the suggestion.
    local op=HC.modules and HC.modules.outposts or nil;
    if op and op.list then
        if op.reconcile then pcall(op.reconcile,c); end
        local ok,list=pcall(op.list); if ok then
            local verified=type(c.outposts)=='table' and type(c.outposts.verified_owned)=='table' and c.outposts.verified_owned or {};
            for _,it in ipairs(list or {}) do
                if same_zone(it.area,zone) and verified[it.key]~=true then
                    out[#out+1]={kind='Outpost',name=tostring(it.name)..' Outpost',status='VERIFY / OBTAIN',detail='Regional Teleport outpost in '..tostring(it.area),tab='dailyweekly',focus={section='outposts'},priority=60};
                end
            end
        end
    end

    local zl=lower(zone);
    if zl:find('dynamis',1,true) then
        local r=system_row(c,'dynamis','Dynamis','dynamis',10); if r and r.done~=true then out[#out+1]={kind='Readiness',name='Dynamis entry',status=r.state,detail=r.reason,tab='dynamis',priority=10}; end
    end
    if zl:find('apollyon',1,true) or zl:find('temenos',1,true) then
        local r=system_row(c,'limbus','Limbus','dailyweekly',12); if r and r.done~=true then out[#out+1]={kind='Readiness',name='Limbus entry',status=r.state,detail=r.reason,tab='dailyweekly',priority=12}; end
    end

    -- In an Assault battlefield, show unfinished missions for that exact area
    -- only when the character has a usable/stored tag state to act on.
    local ap=HC.modules and HC.modules.assaultprogress or nil; local assault=system_row(c,'assault','Assault','assault',14);
    if ap and ap.ranks and assault and (assault.state=='READY' or assault.state=='ACTIVE') then
        local ok,ranks=pcall(ap.ranks); if ok then
            for _,rank in ipairs(ranks or {}) do
                for _,mission in ipairs(rank.missions or {}) do
                    if same_zone(mission[2],zone) and (not ap.is_complete or ap.is_complete(c,mission[1])~=true) then
                        out[#out+1]={kind='Assault',name=tostring(mission[1]),status='READY',detail=tostring(rank.abbr or rank.name)..' | '..tostring(assault.reason or 'Assault tag available'),tab='assault',priority=20};
                    end
                end
            end
        end
    end
    return out;
end

function M.invalidate() cache={at=0,char=nil,data=nil}; end
function M.status(c) return M.snapshot(c,false); end
function M.init(ctx) HC=ctx; end
return M;
