local M = {};
local HC;
local rings = {
    [15761] = { name = 'Chariot Band', max = 3, rechargeable = true },
    [15762] = { name = 'Empress Band', max = 10, rechargeable = true },
    [15763] = { name = 'Emperor Band', max = 5, rechargeable = true },
    [15793] = { name = 'Anniversary Ring', max = 10, rechargeable = false },
};
local containers = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
local cached_scan=nil;
M.dirty=true;

function M.init(ctx)
    HC = ctx;
    HC.modules.packets.register(0x01D, 'ring inventory', function() M.dirty = true; end);
    HC.modules.packets.register(0x01E, 'ring inventory', function() M.dirty = true; end);
    HC.modules.packets.register(0x01F, 'ring inventory', function() M.dirty = true; end);
    HC.modules.packets.register(0x020, 'ring inventory', function() M.dirty = true; end);
end

local function extra_byte(extra, n)
    if extra == nil then return nil; end
    if type(extra) == 'string' then return string.byte(extra, n); end
    local v;
    pcall(function() v = tonumber(extra[n - 1]); end);
    if v ~= nil then return v; end
    pcall(function() v = tonumber(extra[n]); end);
    return v;
end

local function charges(entry, maxch)
    local extra;
    pcall(function() extra = entry.Extra; end);
    local ch = extra_byte(extra, 2);
    if type(ch) == 'number' and ch >= 0 and ch <= maxch then return ch; end
    return nil;
end

function M.scan(force)
    if force~=true and M.dirty~=true then return cached_scan; end
    local inv;
    pcall(function() inv = AshitaCore:GetMemoryManager():GetInventory(); end);
    if inv == nil then return cached_scan; end
    local best;
    for _, cid in ipairs(containers) do
        local mx;
        pcall(function() mx = inv:GetContainerCountMax(cid); end);
        if type(mx) == 'number' and mx > 0 then
            for idx = 0, mx do
                local e;
                pcall(function() e = inv:GetContainerItem(cid, idx); end);
                if e ~= nil then
                    local def = rings[tonumber(e.Id)];
                    if def ~= nil then
                        local r = { id=e.Id, name=def.name, max=def.max, rechargeable=def.rechargeable,
                            charges=charges(e, def.max), container=cid };
                        if best == nil or (r.rechargeable and not best.rechargeable) then best = r; end
                    end
                end
            end
        end
    end
    cached_scan=best;
    M.dirty=false;
    return cached_scan;
end

local function mark_weekly_recharged(c, ring_name, before, after)
    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    if c.weekly.exp_ring==true then return false; end
    c.weekly.exp_ring=true;
    if HC.modules.automation and HC.modules.automation.record_external then
        HC.modules.automation.record_external(
            c,'exp_ring',
            string.format('%s recharged: %s -> %s charges',
                tostring(ring_name or 'EXP Ring'),tostring(before or '?'),tostring(after or '?')),
            {scope='weekly',key='exp_ring',old=nil}
        );
    end
    HC.modules.state.save();
    HC.msg(string.format('AUTO: EXP Ring weekly complete - %s recharged (%s -> %s charges).',
        tostring(ring_name or 'EXP Ring'),tostring(before or '?'),tostring(after or '?')));
    return true;
end

local function reconcile(c)
    local r=M.scan(false);
    if r==nil then return nil,nil; end

    c.ring_week=type(c.ring_week)=='table' and c.ring_week or {};
    local rw=c.ring_week;
    local wk=HC.modules.core.weekly_key();
    local changed=false;
    if rw.key~=wk then
        rw.key=wk;
        rw.recharged=false;
        rw.baseline_name=rw.last_name;
        rw.baseline_charges=rw.last_charges;
        changed=true;
    end
    if r.rechargeable and rw.last_name==r.name and type(r.charges)=='number' and type(rw.last_charges)=='number'
        and r.charges>rw.last_charges and rw.recharged~=true then
        local before=rw.last_charges;
        rw.recharged=true;
        changed=true;
        mark_weekly_recharged(c,r.name,before,r.charges);
    end
    if rw.last_name~=r.name then rw.last_name=r.name; changed=true; end
    if rw.last_charges~=r.charges then rw.last_charges=r.charges; changed=true; end
    if changed then HC.modules.state.save(); end
    if rw.recharged==true and (not c.weekly or c.weekly.exp_ring~=true) then
        mark_weekly_recharged(c,r.name,rw.baseline_charges,r.charges);
    end
    return r,rw;
end

local function draw_status(c,disabled_when_missing)
    local imgui=HC.imgui; if imgui==nil then return false; end
    local r,rw=reconcile(c);
    if r==nil then
        if disabled_when_missing then imgui.TextDisabled('EXP Ring - none found'); else imgui.Text('EXP Ring - none found'); end
        return false;
    end

    local ch=(r.charges~=nil) and string.format('%d/%d',r.charges,r.max) or ('?/'..tostring(r.max));
    imgui.Text('EXP Ring - '..r.name..' - '..ch..' charges');
    imgui.SameLine();
    local recharge_text=r.rechargeable
        and ('Recharge this week: '..(rw.recharged and 'YES' or 'NO/UNKNOWN'))
        or 'Non-rechargeable';
    if r.rechargeable and rw.recharged==true then imgui.Text(recharge_text); else imgui.TextDisabled(recharge_text); end
    return true;
end

function M.draw_attention(c)
    return draw_status(c,true);
end

function M.draw(c)
    draw_status(c,false);
end

return M;
