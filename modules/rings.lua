local M = {};
local HC;

local rings = {
    [15761] = { id=15761, name='Chariot Band', max_charges=3, rechargeable=true, group='exp_ring' },
    [15762] = { id=15762, name='Empress Band', max_charges=10, rechargeable=true, group='exp_ring' },
    [15763] = { id=15763, name='Emperor Band', max_charges=5, rechargeable=true, group='exp_ring' },
    [15793] = { id=15793, name='Anniversary Ring', max_charges=10, rechargeable=false, group='exp_ring' },
};

-- Keep a tiny compatibility cache because several release contracts and older
-- callers expect rings.scan() to be cheap and dirty-cache based.  The actual
-- Extra parsing now lives in reusableitems.lua.
local cached_scan=nil;
M.dirty=true;

local function current_char()
    if HC and HC.modules and HC.modules.state and HC.modules.state.get_char then
        local ok,c=pcall(HC.modules.state.get_char); if ok then return c; end
    end
    return nil;
end

local function mark_weekly_recharged(c,ring_name,before,after,cost,source)
    if type(c)~='table' then return false; end
    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    c.ring_week=type(c.ring_week)=='table' and c.ring_week or {};
    local rw=c.ring_week;
    local wk=HC.modules.core.weekly_key();
    if rw.key~=wk then rw.key=wk; rw.recharged=false; end
    rw.recharged=true;
    rw.last_name=ring_name;
    rw.last_charges=after;
    rw.last_recharged_at=os.time();
    rw.last_recharge_cost=tonumber(cost) or rw.last_recharge_cost;
    rw.last_recharge_source=source or 'reusable item tracker';

    local first=(c.weekly.exp_ring~=true);
    c.weekly.exp_ring=true;
    if first and HC.modules.automation and HC.modules.automation.record_external then
        HC.modules.automation.record_external(c,'exp_ring',string.format('%s recharged: %s -> %s charges%s',
            tostring(ring_name or 'EXP Ring'),tostring(before or '?'),tostring(after or '?'),
            cost and (' for '..tostring(cost)..' Conquest Points') or ''),{scope='weekly',key='exp_ring',old=nil});
    end
    if HC.modules.state and HC.modules.state.request_save then HC.modules.state.request_save(1); else HC.modules.state.save(); end
    if first then
        HC.msg(string.format('AUTO: EXP Ring weekly complete - %s recharge confirmed at %s charges%s.',
            tostring(ring_name or 'EXP Ring'),tostring(after or '?'),cost and (' for '..tostring(cost)..' Conquest Points') or ''));
    end
    return first;
end

local function on_reusable_event(ev)
    if type(ev)~='table' or tostring(ev.group or '')~='exp_ring' then return; end
    M.dirty=true;
    local c=current_char(); if not c then return; end
    c.ring_week=type(c.ring_week)=='table' and c.ring_week or {};
    local rw=c.ring_week;
    local wk=HC.modules.core.weekly_key();
    if rw.key~=wk then rw.key=wk; rw.recharged=false; rw.baseline_name=nil; rw.baseline_charges=nil; end
    rw.last_name=ev.name;
    rw.last_charges=ev.after;
    if ev.kind=='used' then
        rw.last_used_at=os.time();
        rw.last_use_before=ev.before;
        rw.last_use_after=ev.after;
        if HC.modules.state and HC.modules.state.request_save then HC.modules.state.request_save(1); end
    elseif ev.kind=='recharged' or ev.kind=='charges_increased' then
        mark_weekly_recharged(c,ev.name,ev.before,ev.after,ev.cost,ev.source);
    end
end

function M.init(ctx)
    HC=ctx;
    local ri=HC.modules.reusableitems;
    if ri and ri.register then for _,def in pairs(rings) do ri.register(def); end end
    if ri and ri.subscribe then ri.subscribe('exp rings',on_reusable_event); end
    -- Compatibility dirtiness: callers can still force a fresh ring facade scan.
    HC.modules.packets.register(0x01D,'ring inventory',function() M.dirty=true; end);
    HC.modules.packets.register(0x01E,'ring inventory',function() M.dirty=true; end);
    HC.modules.packets.register(0x01F,'ring inventory',function() M.dirty=true; end);
    HC.modules.packets.register(0x020,'ring inventory',function() M.dirty=true; end);
end

function M.scan(force)
    if force~=true and M.dirty~=true then return cached_scan; end
    local ri=HC.modules.reusableitems;
    local rows=ri and ri.group and ri.group('exp_ring',force==true or M.dirty==true) or {};
    local row=nil;
    for _,candidate in ipairs(rows or {}) do
        if row==nil or (candidate.rechargeable==true and row.rechargeable~=true)
            or (candidate.rechargeable==row.rechargeable and (tonumber(candidate.max) or 0)>(tonumber(row.max) or 0)) then
            row=candidate;
        end
    end
    if row then
        cached_scan={id=row.id,name=row.name,max=row.max,rechargeable=row.rechargeable,charges=row.charges,container=row.container};
    else cached_scan=nil; end
    M.dirty=false;
    return cached_scan;
end

local function reconcile(c)
    local r=M.scan(false);
    if not r then return nil,nil; end
    c.ring_week=type(c.ring_week)=='table' and c.ring_week or {};
    local rw=c.ring_week;
    local wk=HC.modules.core.weekly_key();
    local changed=false;
    if rw.key~=wk then
        rw.key=wk; rw.recharged=false; rw.baseline_name=rw.last_name; rw.baseline_charges=rw.last_charges; changed=true;
    end
    if rw.last_name~=r.name then rw.last_name=r.name; changed=true; end
    if rw.last_charges~=r.charges then rw.last_charges=r.charges; changed=true; end
    if rw.recharged==true and (not c.weekly or c.weekly.exp_ring~=true) then mark_weekly_recharged(c,r.name,rw.baseline_charges,r.charges,nil,'saved ring state'); end
    if changed and HC.modules.state and HC.modules.state.request_save then HC.modules.state.request_save(1); end
    return r,rw;
end

local function charge_label(r)
    local ch=tonumber(r and r.charges); local mx=tonumber(r and r.max) or 0;
    if ch==nil then return '?/'..tostring(mx),'CHECKING'; end
    if ch<=0 then return string.format('%d/%d',ch,mx),'NEEDS RECHARGE'; end
    if mx>0 and ch>=mx then return string.format('%d/%d',ch,mx),'FULL'; end
    return string.format('%d/%d',ch,mx),'CHARGES AVAILABLE';
end

function M.status(c)
    c=c or current_char(); if not c then return 'EXP Ring - character unavailable'; end
    local r,rw=reconcile(c);
    if not r then return 'EXP Ring - none found'; end
    local ch,state=charge_label(r);
    local weekly=(r.rechargeable and rw and rw.recharged==true) and ' | weekly recharge used' or '';
    return string.format('%s | %s | %s%s',tostring(r.name),ch,state,weekly);
end

function M.all(force)
    local ri=HC.modules.reusableitems;
    local rows=ri and ri.group and ri.group('exp_ring',force==true) or {};
    local out={};
    for _,r in ipairs(rows or {}) do
        out[#out+1]={id=r.id,name=r.name,max=r.max,rechargeable=r.rechargeable,charges=r.charges,container=r.container};
    end
    return out;
end

local function draw_status(c,disabled_when_missing)
    local imgui=HC.imgui; if imgui==nil then return false; end
    local rows=M.all(false);
    if #rows==0 then
        if disabled_when_missing then imgui.TextDisabled('EXP Ring - none found'); else imgui.Text('EXP Ring - none found'); end
        return false;
    end
    local rw=type(c.ring_week)=='table' and c.ring_week or {};
    for _,r in ipairs(rows) do
        local ch,state=charge_label(r);
        local text=string.format('%s | %s | %s',tostring(r.name),ch,state);
        if state=='NEEDS RECHARGE' then imgui.TextDisabled(text); else imgui.Text(text); end
        if r.rechargeable then
            imgui.SameLine();
            local weekly=rw.recharged==true and 'Recharge this week: USED' or 'Recharge this week: AVAILABLE/UNKNOWN';
            imgui.TextDisabled(weekly);
        end
    end
    return true;
end

function M.draw_attention(c) return draw_status(c,true); end
function M.draw(c) draw_status(c,false); end

return M;
