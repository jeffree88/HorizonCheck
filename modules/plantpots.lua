local M = {};
local HC;
local last_new_at=0;
local learn_started_at=0;
local AUTO_SETTLE_SECONDS=8;
local FEED_DEDUPE_SECONDS=2;
local FEED_LINK_SECONDS=4;
local FEED_PROMPT_SECONDS=5;
local last_pot_id=nil;
local last_pot_at=0;
local pending_feed=nil;
local last_feed_text=nil;
local last_feed_text_at=0;
local feed_prompt_at=0;

local function count_keys(t)
    local n=0; if type(t)~='table' then return 0; end
    for _ in pairs(t) do n=n+1; end
    return n;
end

local function ensure(c)
    local dk=HC.modules.core.daily_key();
    c.daily=type(c.daily)=='table' and c.daily or {};
    c.plant_pots=type(c.plant_pots)=='table' and c.plant_pots or {};
    c.plant_pots.target=math.max(0,math.min(10,math.floor(tonumber(c.plant_pots.target) or 0)));
    c.plant_pots_daily=type(c.plant_pots_daily)=='table' and c.plant_pots_daily or {};
    if c.plant_pots_daily.day_key~=dk then
        c.plant_pots_daily={day_key=dk,checked=0,checked_ids={},feed_count=0,fed_ids={},feed_crystals={}};
        c.daily.plant_pots=nil;
    end
    c.plant_pots_daily.checked_ids=type(c.plant_pots_daily.checked_ids)=='table' and c.plant_pots_daily.checked_ids or {};
    c.plant_pots_daily.checked=count_keys(c.plant_pots_daily.checked_ids);
    c.plant_pots_daily.fed_ids=type(c.plant_pots_daily.fed_ids)=='table' and c.plant_pots_daily.fed_ids or {};
    c.plant_pots_daily.feed_crystals=type(c.plant_pots_daily.feed_crystals)=='table' and c.plant_pots_daily.feed_crystals or {};
    c.plant_pots_daily.feed_count=math.max(0,math.floor(tonumber(c.plant_pots_daily.feed_count) or 0));
    return c.plant_pots,c.plant_pots_daily;
end

local function decode_pot_id(raw)
    if type(raw)~='string' or #raw<12 then return nil; end
    -- Verified HorizonXI Mog House flowerpot interaction signature from capture:
    -- 0x0FA ... DB 00 ... <pot-id little-endian at bytes 11-12>.
    local b5,b6=raw:byte(5),raw:byte(6);
    if b5~=0xDB or b6~=0x00 then return nil; end
    local lo,hi=raw:byte(11),raw:byte(12);
    if not lo or not hi then return nil; end
    local id=lo+(hi*256);
    if id<0x0100 or id>0x01FF then return nil; end
    return id;
end

local function pot_key(id)
    if not id then return nil; end
    return string.format('%04X',tonumber(id) or 0);
end

local function link_feed_to_pot(d,id)
    local key=pot_key(id);
    if not key then return false; end
    d.fed_ids=type(d.fed_ids)=='table' and d.fed_ids or {};
    if d.fed_ids[key] then return false; end
    d.fed_ids[key]=true;
    return true;
end

local function sync_completion(c,cfg,d)
    d.checked_ids=type(d.checked_ids)=='table' and d.checked_ids or {};
    d.checked=count_keys(d.checked_ids);
    if cfg.target>0 and d.checked>=cfg.target then c.daily.plant_pots=true;
    else c.daily.plant_pots=nil; end
end

local function invalidate_checked_pot(c,cfg,d,id)
    local key=pot_key(id);
    if not key then return false; end
    d.checked_ids=type(d.checked_ids)=='table' and d.checked_ids or {};
    local changed=d.checked_ids[key]~=nil;
    d.checked_ids[key]=nil;
    sync_completion(c,cfg,d);
    return changed;
end

local function record_feed_text(s)
    local lower=string.lower(tostring(s or ''));
    local now=os.time();
    -- The confirmation prompt arms the next flowerpot interaction as a feed action,
    -- so its 0x0FA packet is not mistaken for an examine/check.
    if lower:find('use this crystal, kupo?',1,true) then
        feed_prompt_at=now;
        return;
    end
    if not lower:find('your moogle uses the ',1,true) or not lower:find(' crystal on the plant',1,true) then return; end
    local crystal=lower:match('your moogle uses the ([%a]+) crystal on the plant') or 'unknown';
    local sig='feed:'..tostring(crystal);
    if last_feed_text==sig and now-last_feed_text_at<=FEED_DEDUPE_SECONDS then return; end
    last_feed_text=sig; last_feed_text_at=now;

    local c=HC.modules.state.get_char();
    local cfg,d=ensure(c);
    d.feed_count=math.max(0,math.floor(tonumber(d.feed_count) or 0))+1;
    d.feed_crystals=type(d.feed_crystals)=='table' and d.feed_crystals or {};
    d.feed_crystals[crystal]=math.max(0,math.floor(tonumber(d.feed_crystals[crystal]) or 0))+1;
    d.last_feed_at=now;
    d.last_feed_crystal=crystal;

    if last_pot_id and now-last_pot_at<=FEED_LINK_SECONDS then
        link_feed_to_pot(d,last_pot_id);
        -- Feeding is a separate action from examining. A feed invalidates this
        -- pot's earlier daily check so it must be examined again afterward.
        invalidate_checked_pot(c,cfg,d,last_pot_id);
        pending_feed=nil;
    else
        pending_feed={at=now,crystal=crystal};
        -- Do not allow an already-complete daily objective to remain complete
        -- when a feed could not yet be associated with a pot.
        c.daily.plant_pots=nil;
    end
    feed_prompt_at=0;
    HC.modules.state.save();
end

local function on_pot_packet(e)
    local raw=e and (e.data or e.data_raw);
    local id=decode_pot_id(raw);
    if not id then return; end
    local now=os.time();
    last_pot_id=id; last_pot_at=now;
    local c=HC.modules.state.get_char();
    local cfg,d=ensure(c);
    local feed_packet=(feed_prompt_at>0 and now-feed_prompt_at<=FEED_PROMPT_SECONDS);
    local linked=false;
    if type(pending_feed)=='table' and now-tonumber(pending_feed.at or 0)<=FEED_LINK_SECONDS then
        linked=link_feed_to_pot(d,id);
        invalidate_checked_pot(c,cfg,d,id);
        pending_feed=nil;
        feed_packet=true;
    end
    if feed_packet then
        -- Crystal-feeding and examining use the same flowerpot packet family.
        -- A packet armed by the Moogle feed prompt is not daily examine credit.
        if linked then HC.modules.state.save(); end
        return;
    end
    local key=pot_key(id);
    if d.checked_ids[key] then return; end
    d.checked_ids[key]=true;
    d.checked=count_keys(d.checked_ids);
    last_new_at=now;
    if learn_started_at==0 then learn_started_at=last_new_at; end

    if cfg.target>0 and d.checked>cfg.target then cfg.target=math.min(10,d.checked); end
    sync_completion(c,cfg,d);
    HC.modules.state.save();
end

function M.init(ctx)
    HC=ctx;
    if HC.modules.packets and HC.modules.packets.register then
        HC.modules.packets.register(0x0FA,'plantpots_unique',on_pot_packet);
    end
    if HC.modules.packets and HC.modules.packets.register_text then
        HC.modules.packets.register_text('plantpots_crystal_feed',record_feed_text);
    end
end

function M.poll()
    if last_new_at==0 or os.time()-last_new_at<AUTO_SETTLE_SECONDS then return; end
    local c=HC.modules.state.get_char();
    local cfg,d=ensure(c);
    local n=count_keys(d.checked_ids);
    if n>0 and (cfg.target==0 or n>cfg.target) then
        cfg.target=math.min(10,n);
        d.checked=n;
        c.daily.plant_pots=(n>=cfg.target) and true or nil;
        HC.modules.state.save();
        HC.msg(string.format('Plant pots learned: %d pot%s. Daily pot objective is now automatic.',cfg.target,cfg.target==1 and '' or 's'));
    elseif cfg.target>0 then
        local before=c.daily.plant_pots;
        sync_completion(c,cfg,d);
        if before~=c.daily.plant_pots then HC.modules.state.save(); end
    end
    last_new_at=0;
    learn_started_at=0;
end

function M.relearn()
    local c=HC.modules.state.get_char();
    local cfg,d=ensure(c);
    cfg.target=0;
    d.checked_ids={}; d.checked=0;
    c.daily.plant_pots=nil;
    last_new_at=0; learn_started_at=0;
    last_pot_id=nil; last_pot_at=0; pending_feed=nil; feed_prompt_at=0;
    HC.modules.state.save();
    HC.msg('Plant pot count cleared. Inspect every planted pot once to relearn this character.');
end

function M.status(c)
    c=c or HC.modules.state.get_char();
    local cfg,d=ensure(c);
    local n=math.floor(tonumber(d.checked) or 0);
    local t=math.floor(tonumber(cfg.target) or 0);
    local fed=math.max(0,math.floor(tonumber(d.feed_count) or 0));
    if t>0 then return string.format('%d/%d checked | %d crystal%s fed',n,t,fed,fed==1 and '' or 's'); end
    return string.format('%d/? checked | %d crystal%s fed - learning pot total',n,fed,fed==1 and '' or 's');
end

return M;
