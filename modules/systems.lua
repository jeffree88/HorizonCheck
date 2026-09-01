local M = {};
local HC;
local cache={at=0,char=nil,data=nil};

local function fmt_duration(v)
    if HC and HC.modules and HC.modules.core and HC.modules.core.format_duration and type(v)=='number' then
        local ok,s=pcall(HC.modules.core.format_duration,v); if ok and s then return tostring(s); end
    end
    return tostring(v or '?');
end

local function weekly_remaining()
    local core=HC and HC.modules and HC.modules.core or nil;
    if core and core.seconds_until_weekly_reset then local ok,v=pcall(core.seconds_until_weekly_reset); if ok and type(v)=='number' then return math.max(0,v); end end
    return nil;
end

local function daily_remaining()
    local core=HC and HC.modules and HC.modules.core or nil;
    if core and core.seconds_until_daily_reset then local ok,v=pcall(core.seconds_until_daily_reset); if ok and type(v)=='number' then return math.max(0,v); end end
    return nil;
end

local function pair_count(values,a,b)
    values=type(values)=='table' and values or {};
    return (values[a]==true and 1 or 0)+(values[b]==true and 1 or 0);
end

local function row(tier,priority,text,source,extra)
    local r={tier=tier,priority=priority,text=tostring(text or ''),source=source};
    for k,v in pairs(type(extra)=='table' and extra or {}) do r[k]=v; end
    return r;
end

local function timer(name,seconds,label,source)
    return {name=name,seconds=tonumber(seconds),label=label,source=source};
end

local function assault_engine(c)
    local out={id='assault',label='Assault Tags',state='UNKNOWN',actions={},timers={},reset='rolling'};
    local m=HC.modules.assault; if not m then out.reason='module unavailable'; return out; end
    local rs=m.rytaal_status and m.rytaal_status(c) or nil;
    if rs then
        local char=(rs.carried~=nil) and tostring(rs.carried) or '?'; local ry=(rs.rytaal~=nil) and tostring(rs.rytaal) or '?'; local total=(rs.total~=nil) and tostring(rs.total) or '?';
        local conf=rs.carried_confidence and (' | '..tostring(rs.carried_confidence)) or '';
        if rs.capped then out.state='READY'; out.reason='tag storage capped'; out.actions[#out.actions+1]=row('DO NOW',1,'Assault Tags capped - spend a tag | Character '..char..'/1 | Rytaal '..ry..'/3 | Total '..total..'/4'..conf,'assault',{urgency='CRITICAL'});
        elseif (rs.carried or 0)>0 then out.state='READY'; out.reason='tag held'; out.actions[#out.actions+1]=row('READY',12,'Assault Tag on character | '..char..'/1 | Rytaal '..ry..'/3 | Total '..total..'/4'..conf,'assault');
        elseif (rs.rytaal or 0)>0 then out.state='READY'; out.reason='tag waiting at Rytaal'; out.actions[#out.actions+1]=row('READY',18,'Pick up Assault Tag from Rytaal | Character '..char..'/1 | Rytaal '..ry..'/3'..conf,'assault');
        elseif rs.regen_pending==true then out.state='VERIFY'; out.reason='regeneration due; Rytaal verification needed'; end
    end
    if m.next_timer then
        local ok,a=pcall(m.next_timer,c); if ok and a and a.state=='COUNTING DOWN' and a.remaining then out.timers[#out.timers+1]=timer('Assault Tag',a.remaining,'regeneration','assault'); end
    end
    return out;
end

local function isnm_engine(c)
    local out={id='isnm',label='ISNM',state='UNKNOWN',actions={},timers={},reset='entry lifecycle'}; local m=HC.modules.isnm;
    if not m or not m.status then out.reason='module unavailable'; return out; end
    local s=tostring(m.status(c) or ''); out.reason=s;
    if s:find('RUN IN PROGRESS',1,true) then out.state='ACTIVE'; out.actions[#out.actions+1]=row('DO NOW',2,s,'isnm',{urgency='CRITICAL'});
    elseif s:find('CONSUMED / ENTRY PENDING',1,true) then out.state='ACTIVE'; out.actions[#out.actions+1]=row('DO NOW',3,s,'isnm',{urgency='CRITICAL'});
    elseif s:find('ORDER HELD',1,true) then out.state='READY'; out.actions[#out.actions+1]=row('READY',10,s,'isnm');
    else out.state='WAITING'; end
    return out;
end

local function enm_engine(c)
    local out={id='enm',label='ENM',state='WAITING',actions={},timers={},reset='per-ENM cooldown'}; local m=HC.modules.enm;
    if not m then out.state='UNKNOWN'; out.reason='module unavailable'; return out; end
    local ready_seen=0;
    if m.attention_rows then
        local rows=m.attention_rows(c) or {};
        for _,r in ipairs(rows) do
            local text=tostring(r.text or '');
            if text:find('RUN IN PROGRESS',1,true) then out.state='ACTIVE'; out.actions[#out.actions+1]=row('DO NOW',4,text,'enm',{urgency='CRITICAL'});
            elseif text:find('KEY ITEM READY',1,true) then ready_seen=ready_seen+1; out.state='READY'; if ready_seen<=4 then out.actions[#out.actions+1]=row('READY',14,text,'enm'); end
            elseif text:find('AVAILABLE',1,true) then ready_seen=ready_seen+1; out.state='READY'; if ready_seen<=4 then out.actions[#out.actions+1]=row('READY',20,text,'enm'); end
            end
        end
    end
    if m.upcoming_timers then
        local ok,rows=pcall(m.upcoming_timers,c); if ok then
            local n=0; for _,e in ipairs(rows or {}) do if n>=5 then break; end; n=n+1; out.timers[#out.timers+1]=timer('ENM - '..tostring(e.name),tonumber(e.remaining),'cooldown | '..(e.verified and 'VERIFIED' or 'ESTIMATED'),'enm'); end
        end
    end
    out.reason=ready_seen>0 and (tostring(ready_seen)..' ready') or 'no ready ENM detected';
    return out;
end

local function limbus_engine(c,wremain)
    local used=pair_count(c.weekly,'limbus_1','limbus_2');
    local out={id='limbus',label='Limbus',state=used>=2 and 'DONE' or 'UNKNOWN',actions={},timers={},reset='conquest',used=used,total=2,remaining=2-used};
    if used>=2 then out.reason='2/2 weekly entries used'; return out; end
    local ks=nil; local owned=nil;
    if HC.modules.keyitems and HC.modules.keyitems.cosmo_cleanse_status then local ok,v=pcall(HC.modules.keyitems.cosmo_cleanse_status); if ok then ks=v; owned=v and v.owned or nil; end end
    if owned==true then
        out.state='READY'; out.reason='Cosmo-Cleanse held'; local tier=(wremain and wremain<=6*3600) and 'DO NOW' or 'READY';
        out.actions[#out.actions+1]=row(tier,tier=='DO NOW' and 6 or 16,string.format('Limbus - Cosmo-Cleanse held | %d/2 used | %d remaining',used,2-used),'limbus',tier=='DO NOW' and {urgency='SOON'} or nil);
    elseif owned==false then out.state='PREP'; out.reason='Cosmo-Cleanse missing';
    else out.state='VERIFY'; out.reason='Cosmo-Cleanse ownership unknown'..((ks and ks.source) and (' | '..tostring(ks.source)) or ''); end
    return out;
end

local function dynamis_engine(c,wremain)
    local limits=(HC.modules.weekly and HC.modules.weekly.dynamis_limits) and HC.modules.weekly.dynamis_limits(c) or nil;
    local aw=HC.modules.state.get_account_weekly and HC.modules.state.get_account_weekly() or {};
    local acct=limits and limits.account_used or math.max(0,math.min(3,math.floor(tonumber(aw.dynamis_count) or 0)));
    local char=limits and limits.character_used or math.max(0,math.min(2,math.floor(tonumber(c.weekly.dynamis_character_count) or 0)));
    local cap=limits and limits.character_cap or math.max(char,math.min(2,char+math.max(0,3-acct)));
    local remaining=limits and limits.character_remaining or math.max(0,cap-char);
    local out={id='dynamis',label='Dynamis',state='DONE',actions={},timers={},reset='conquest',account_used=acct,character_used=char,character_cap=cap,remaining=remaining};
    if remaining>0 then
        out.state='READY'; out.reason='entry available'; local tier=(wremain and wremain<=6*3600) and 'DO NOW' or 'READY';
        out.actions[#out.actions+1]=row(tier,tier=='DO NOW' and 7 or 18,string.format('Dynamis - Character %d/%d used | %d remaining | Account %d/3 used',char,cap,remaining,acct),'dynamis',tier=='DO NOW' and {urgency='SOON'} or nil);
    else out.reason='character/account entry limit reached'; end
    return out;
end

local function ring_engine(c,wremain)
    local out={id='exp_ring',label='EXP Ring',state='DONE',actions={},timers={},reset='conquest'}; local m=HC.modules.rings;
    if not m or not m.scan then out.state='UNKNOWN'; out.reason='ring scanner unavailable'; return out; end
    local ok,ring=pcall(m.scan); if not ok or not ring then out.reason='no rechargeable ring detected'; return out; end
    local max=tonumber(ring.max or 0); local charges=tonumber(ring.charges);
    if ring.rechargeable and charges and charges<max and not (type(c.weekly)=='table' and c.weekly.exp_ring==true) then
        out.state='READY'; out.reason='weekly recharge available'; local tier=(wremain and wremain<=6*3600) and 'DO NOW' or 'READY';
        out.actions[#out.actions+1]=row(tier,tier=='DO NOW' and 8 or 24,string.format('EXP Ring - %s %d/%d charges | weekly recharge not yet recorded',tostring(ring.name),charges,max),'rings',tier=='DO NOW' and {urgency='SOON'} or nil);
    else out.reason='no recharge action needed'; end
    return out;
end

local function eco_engine(c)
    local out={id='eco',label='Eco-Warrior',state='UNKNOWN',actions={},timers={},reset='conquest'}; local m=HC.modules.eco;
    if not m or not m.rotation_count then out.reason='module unavailable'; return out; end
    local ok,n,total=pcall(m.rotation_count,c); if ok then out.progress=tonumber(n) or 0; out.total=tonumber(total) or 3; out.state=(out.progress>=out.total) and 'DONE' or 'READY'; out.reason=string.format('%d/%d rotation cleared',out.progress,out.total); end
    return out;
end

local ENGINES={assault_engine,isnm_engine,enm_engine,limbus_engine,dynamis_engine,ring_engine,eco_engine};

function M.snapshot(c,force)
    c=type(c)=='table' and c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {}; c.weekly=type(c.weekly)=='table' and c.weekly or {};
    local char=(HC.modules.core and HC.modules.core.character_name and HC.modules.core.character_name()) or 'Unknown'; local now=os.time();
    if not force and cache.data and cache.char==char and now-(tonumber(cache.at) or 0)<1 then return cache.data; end
    local wr=weekly_remaining(); local dr=daily_remaining(); local data={generated_at=now,weekly_remaining=wr,daily_remaining=dr,systems={},actions={},timers={}};
    for _,fn in ipairs(ENGINES) do
        local ok,s=pcall(fn,c,wr,dr); if ok and type(s)=='table' then
            data.systems[s.id]=s;
            for _,a in ipairs(s.actions or {}) do data.actions[#data.actions+1]=a; end
            for _,t in ipairs(s.timers or {}) do if type(t.seconds)=='number' and t.seconds>=0 then data.timers[#data.timers+1]=t; end end
        elseif not ok then
            local id='engine_'..tostring(#data.systems+1); data.systems[id]={id=id,label=id,state='ERROR',reason=tostring(s),actions={},timers={}};
        end
    end
    table.sort(data.actions,function(a,b) if tostring(a.tier)~=tostring(b.tier) then return tostring(a.tier)<tostring(b.tier); end return (tonumber(a.priority) or 100)<(tonumber(b.priority) or 100); end);
    table.sort(data.timers,function(a,b) return (tonumber(a.seconds) or math.huge)<(tonumber(b.seconds) or math.huge); end);
    cache={at=now,char=char,data=data}; return data;
end

function M.get(id,c) local s=M.snapshot(c,false); return s.systems[tostring(id or '')]; end
function M.action_rows(c) return M.snapshot(c,false).actions or {}; end
function M.timer_rows(c) return M.snapshot(c,false).timers or {}; end

local function jst_day_key(ts) ts=tonumber(ts) or os.time(); return math.floor((ts+9*3600)/86400); end
local function jst_week_key(ts) ts=tonumber(ts) or os.time(); local shifted=ts+9*3600; local days=math.floor(shifted/86400); local dow=(days+4)%7; return math.floor((days-dow)/7); end

-- Central reset-policy engine for repeatable quests. Quests passes only observed
-- state; this module owns daily/conquest/cooldown interpretation.
function M.repeat_status(c,ctx)
    ctx=type(ctx)=='table' and ctx or {}; local kind=string.lower(tostring(ctx.kind or 'repeatable')); local now=tonumber(ctx.now) or os.time(); local at=tonumber(ctx.completion_at);
    if ctx.active==true then return 'ACTIVE','native quest log'; end

    if tostring(ctx.system or '')=='eco' then
        local nation=ctx.nation; local eco=type(c)=='table' and type(c.eco)=='table' and c.eco or nil; local wk=HC.modules.core and HC.modules.core.weekly_key and HC.modules.core.weekly_key() or nil;
        if eco and nation and eco.completed_this_week==nation and eco.completed_this_week_weekly_key==wk then return 'DONE THIS WEEK','Eco-Warrior system state'; end
    end

    if kind:find('daily',1,true) then
        if at and jst_day_key(at)==jst_day_key(now) then return 'DONE TODAY','daily reset engine'; end
        if ctx.completed==true and not at then return 'UNKNOWN RESET','historical completion has no timestamp'; end
        return 'READY','daily reset engine';
    end
    if kind:find('weekly',1,true) or kind:find('conquest',1,true) or string.upper(tostring(ctx.repeat_tag or ''))=='WEEKLY' or string.upper(tostring(ctx.repeat_tag or ''))=='CONQUEST' then
        if at and jst_week_key(at)==jst_week_key(now) then return 'DONE THIS WEEK','conquest reset engine'; end
        if ctx.completed==true and not at then return 'UNKNOWN RESET','historical completion has no timestamp'; end
        return 'READY','conquest reset engine';
    end
    local cooldown=tonumber(ctx.cooldown_hours);
    if cooldown and cooldown>0 and at then
        local remain=(at+cooldown*3600)-now; if remain>0 then return 'WAITING '..tostring(math.ceil(remain/3600))..'H','cooldown engine'; end
        return 'READY','cooldown engine';
    end
    return 'READY','repeatable anytime';
end

function M.draw(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local s=M.snapshot(c,true); imgui.Text('System State Engines'); imgui.TextDisabled('One owner per reset/entry lifecycle; planner reads these normalized states.');
    local ids={}; for id in pairs(s.systems or {}) do ids[#ids+1]=id; end; table.sort(ids);
    for _,id in ipairs(ids) do local r=s.systems[id]; imgui.Text(string.upper(id)..': '..tostring(r.state)); imgui.SameLine(); imgui.TextDisabled(tostring(r.reason or '')..' | reset='..tostring(r.reset or 'n/a')); end
end

function M.status(c) return M.snapshot(c,false); end
function M.command(w) local sub=string.lower(w[2] or ''); if sub=='systems' or sub=='systemstate' then local s=M.snapshot(nil,true); if HC and HC.msg then HC.msg('System engines refreshed: '..tostring(#(s.actions or {}))..' action(s), '..tostring(#(s.timers or {}))..' timer(s).'); end; return true; end return false; end
function M.init(ctx) HC=ctx; end
return M;
