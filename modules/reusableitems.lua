local M = {};
local HC;

-- Shared charge-based / reusable-item tracker.  Modules register their own
-- items and consume normalized events instead of each implementing a separate
-- inventory Extra parser.  The framework intentionally knows nothing about
-- weekly gameplay rules; those stay in the feature module (for example rings).
local definitions = {};
local name_index = {};
local subscribers = {};
local containers = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
local cached_items = {};
local dirty = true;
local full_rescan_due = 0;
local cache_owner = nil;
local session_seen = {};

local function normalize_name(v)
    local s=string.lower(tostring(v or ''));
    s=s:gsub('[^%w%s%-]',' '):gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$','');
    return s;
end

local function request_save()
    local st=HC and HC.modules and HC.modules.state or nil;
    if st and st.request_save then pcall(st.request_save,1);
    elseif st and st.save then pcall(st.save); end
end

local function current_char()
    local st=HC and HC.modules and HC.modules.state or nil;
    if st and st.get_char then
        local ok,c=pcall(st.get_char);
        if ok and type(c)=='table' then return c; end
    end
    return nil;
end

local function current_profile_name()
    local st=HC and HC.modules and HC.modules.state or nil;
    if st and st.profile_name then
        local ok,name=pcall(st.profile_name);
        if ok then return tostring(name or 'Unknown'); end
    end
    return 'Unknown';
end

-- Inventory memory and 0x020 traffic can still be settling while the player is
-- logging in or switching characters.  Reusable-item caches are therefore
-- strictly owned by one character at a time.  The first live charge value seen
-- for an item in each character session is a baseline only; it must never be
-- interpreted as a recharge compared with an older saved value.
local function ensure_cache_owner()
    local owner=current_profile_name();
    if owner~=cache_owner then
        cache_owner=owner;
        cached_items={};
        session_seen={};
        dirty=true;
        full_rescan_due=0;
        return true;
    end
    return false;
end

local function ensure_state(c)
    if type(c)~='table' then return nil; end
    c.reusable_items=type(c.reusable_items)=='table' and c.reusable_items or {};
    return c.reusable_items;
end

local function extra_byte(extra,n)
    if extra==nil then return nil; end
    if type(extra)=='string' then return string.byte(extra,n); end
    local v=nil;
    pcall(function() v=tonumber(extra[n-1]); end);
    if v~=nil then return v; end
    pcall(function() v=tonumber(extra[n]); end);
    return v;
end

local function item_charges(entry,def)
    if not entry or not def then return nil; end
    local extra=nil;
    pcall(function() extra=entry.Extra; end);
    local offset=tonumber(def.charge_extra_byte) or 2;
    local ch=extra_byte(extra,offset);
    local mx=tonumber(def.max_charges);
    if type(ch)=='number' and (mx==nil or (ch>=0 and ch<=mx)) then return ch; end
    return nil;
end

local function dispatch(ev)
    if type(ev)~='table' then return; end
    for _,s in ipairs(subscribers) do
        local ok,err=pcall(s.fn,ev);
        if not ok and HC and HC.modules and HC.modules.diagnostics then
            HC.modules.diagnostics.record_error('reusable item subscriber '..tostring(s.name),err);
        end
    end
end

function M.register(def)
    if type(def)~='table' then return false; end
    local id=tonumber(def.id);
    local name=tostring(def.name or '');
    if not id or id<=0 or name=='' then return false; end
    local copy={};
    for k,v in pairs(def) do copy[k]=v; end
    copy.id=id;
    copy.name=name;
    copy.group=tostring(copy.group or 'reusable');
    copy.max_charges=tonumber(copy.max_charges);
    copy.charge_extra_byte=tonumber(copy.charge_extra_byte) or 2;
    definitions[id]=copy;
    name_index[normalize_name(name)]=copy;
    dirty=true;
    return true;
end

function M.subscribe(name,fn)
    if type(fn)~='function' then return false; end
    subscribers[#subscribers+1]={name=tostring(name or ('subscriber_'..tostring(#subscribers+1))),fn=fn};
    return true;
end

function M.invalidate(delay_seconds)
    ensure_cache_owner();
    dirty=true;
    local delay=math.max(0,tonumber(delay_seconds) or 1);
    full_rescan_due=os.time()+delay;
end

local function find_inventory()
    local inv=nil;
    pcall(function() inv=AshitaCore:GetMemoryManager():GetInventory(); end);
    return inv;
end

local function build_scan()
    local inv=find_inventory();
    if inv==nil then return nil; end
    local found={};
    for _,cid in ipairs(containers) do
        local mx=nil;
        pcall(function() mx=inv:GetContainerCountMax(cid); end);
        if type(mx)=='number' and mx>0 then
            for idx=0,mx do
                local e=nil;
                pcall(function() e=inv:GetContainerItem(cid,idx); end);
                if e~=nil then
                    local id=tonumber(e.Id);
                    local def=id and definitions[id] or nil;
                    if def then
                        local row={
                            id=id,name=def.name,group=def.group,max=def.max_charges,
                            rechargeable=def.rechargeable==true,charges=item_charges(e,def),
                            container=cid,index=idx,definition=def,
                        };
                        local old=found[id];
                        -- If multiple copies somehow exist, keep the copy with the
                        -- largest known charge count; otherwise keep first seen.
                        if old==nil or ((tonumber(row.charges) or -1)>(tonumber(old.charges) or -1)) then
                            found[id]=row;
                        end
                    end
                end
            end
        end
    end
    return found;
end

local reconcile_found;

local function u8_at(data,off)
    if type(data)~='string' then return nil; end
    return string.byte(data,(tonumber(off) or 0)+1);
end

local function u16le_at(data,off)
    local a=u8_at(data,off); local b=u8_at(data,(tonumber(off) or 0)+1);
    if a==nil or b==nil then return nil; end
    return a+b*256;
end

local function on_item_update(e)
    ensure_cache_owner();
    -- 0x020 carries the changed bag/slot and item id.  Re-read only that slot
    -- when it belongs to a registered reusable item (or was one previously)
    -- instead of walking all 17 inventory/storage/wardrobe containers.
    local data=e and (e.data or e.data_raw) or nil;
    if type(data)~='string' or #data<16 then M.invalidate(2); return; end
    local item_id=u16le_at(data,0x0C) or 0;
    local bag=u8_at(data,0x0E); local index=u8_at(data,0x0F);
    if bag==nil or index==nil then M.invalidate(2); return; end
    local old_id=nil;
    for id,row in pairs(cached_items) do
        if tonumber(row.container)==tonumber(bag) and tonumber(row.index)==tonumber(index) then old_id=tonumber(id); break; end
    end
    if definitions[item_id]==nil and old_id==nil then return; end

    local found={}; for id,row in pairs(cached_items) do found[id]=row; end
    if old_id then found[old_id]=nil; end
    if definitions[item_id] then
        local inv=find_inventory(); local entry=nil;
        if inv and inv.GetContainerItem then pcall(function() entry=inv:GetContainerItem(bag,index); end); end
        local def=definitions[item_id];
        if entry then
            found[item_id]={id=item_id,name=def.name,group=def.group,max=def.max_charges,
                rechargeable=def.rechargeable==true,charges=item_charges(entry,def),container=bag,index=index,definition=def};
        else
            -- Packet says the tracked item is here, but the memory mirror has not
            -- caught up yet.  Schedule one delayed safety scan rather than spin.
            M.invalidate(2); return;
        end
    end
    local c=current_char();
    local changed=reconcile_found(c,found,'0x020 item update');
    cached_items=found; dirty=false; full_rescan_due=0;
    if changed then request_save(); end
end

local function record_event(c,ev)
    if not (HC and HC.modules and HC.modules.automation and HC.modules.automation.record_external) then return; end
    local kind='reusable_item_'..tostring(ev.kind or 'changed');
    local detail=tostring(ev.name or 'Reusable item');
    if ev.before~=nil or ev.after~=nil then
        detail=detail..': '..tostring(ev.before or '?')..' -> '..tostring(ev.after or '?')..' charges';
    end
    pcall(HC.modules.automation.record_external,c,kind,detail,nil);
end

reconcile_found = function(c,found,source)
    if type(c)~='table' or type(found)~='table' then return false; end
    local store=ensure_state(c);
    local now=os.time();
    local changed=false;
    for id,row in pairs(found) do
        local def=definitions[id];
        local rec=type(store[id])=='table' and store[id] or {};
        store[id]=rec;
        local observed=tonumber(row.charges);
        local before=tonumber(rec.last_charges);
        local authoritative_until=tonumber(rec.authoritative_until) or 0;

        -- NPC recharge dialogue can arrive a fraction of a second before the
        -- inventory Extra update.  Hold the authoritative value briefly so an
        -- old packet cannot look like a ring use immediately after recharge.
        if observed~=nil and before~=nil and now<=authoritative_until and observed<before then
            row.charges=before;
            observed=before;
        end

        rec.name=def and def.name or row.name;
        rec.group=def and def.group or row.group;
        rec.max_charges=def and def.max_charges or row.max;
        rec.rechargeable=def and def.rechargeable==true or row.rechargeable==true;
        rec.last_seen_at=now;
        rec.container=row.container;

        if observed~=nil and session_seen[id]~=true then
            -- First live observation for this character/session is only a
            -- baseline. Saved charge values can be older than the current login
            -- and must not manufacture a false charges_increased/recharge event.
            session_seen[id]=true;
            if rec.last_charges~=observed then rec.last_charges=observed; changed=true; end
        elseif observed~=nil and before~=nil and observed~=before then
            local kind=(observed<before) and 'used' or 'charges_increased';
            rec.last_change_at=now;
            rec.last_change=kind;
            rec.last_change_source=source or 'inventory';
            rec.last_charges=observed;
            rec.authoritative_until=nil;
            local ev={kind=kind,id=id,name=rec.name,group=rec.group,before=before,after=observed,max=rec.max_charges,source=source or 'inventory',definition=def,session_baselined=true};
            record_event(c,ev);
            dispatch(ev);
            changed=true;
        elseif observed~=nil and rec.last_charges~=observed then
            rec.last_charges=observed;
            changed=true;
        end
    end
    return changed;
end

function M.scan(force)
    ensure_cache_owner();
    if force~=true and dirty~=true then return cached_items; end
    local found=build_scan();
    if found==nil then return cached_items; end
    local c=current_char();
    local changed=reconcile_found(c,found,'inventory');
    cached_items=found;
    dirty=false;
    full_rescan_due=0;
    if changed then request_save(); end
    return cached_items;
end

function M.group(group,force)
    local all=M.scan(force==true) or {};
    local out={};
    group=tostring(group or '');
    for _,row in pairs(all) do
        if tostring(row.group or '')==group then out[#out+1]=row; end
    end
    table.sort(out,function(a,b)
        local am=tonumber(a.max) or 0; local bm=tonumber(b.max) or 0;
        if am~=bm then return am>bm; end
        return tostring(a.name)<tostring(b.name);
    end);
    return out;
end

function M.primary(group,force)
    local rows=M.group(group,force);
    return rows[1];
end

function M.status(id,c)
    c=c or current_char();
    local store=ensure_state(c) or {};
    local rec=store[tonumber(id)];
    if type(rec)~='table' then return nil; end
    local out={}; for k,v in pairs(rec) do out[k]=v; end
    out.id=tonumber(id);
    return out;
end

function M.definition(id)
    return definitions[tonumber(id)];
end

function M.all_definitions()
    local out={}; for _,v in pairs(definitions) do out[#out+1]=v; end
    table.sort(out,function(a,b) return tostring(a.name)<tostring(b.name); end);
    return out;
end

local function recharge_from_text(s)
    ensure_cache_owner();
    local low=normalize_name(s);
    if low=='' or not low:find('has received',1,true) or not low:find('charges',1,true) then return false; end
    local ring_name,count,cost=low:match('your%s+([%a%s%-]+band)%s+has received%s+(%d+)%s+charges%s+in exchange for%s+(%d+)%s+conquest points');
    if not ring_name then return false; end
    ring_name=normalize_name(ring_name);
    local def=name_index[ring_name];
    if not def then return false; end
    local c=current_char(); if not c then return false; end
    local store=ensure_state(c); local rec=type(store[def.id])=='table' and store[def.id] or {}; store[def.id]=rec;
    local now=os.time();
    local before=tonumber(rec.last_charges);
    local after=tonumber(count) or tonumber(def.max_charges);
    if def.max_charges and low:find('fully recharged',1,true) then after=def.max_charges; end
    rec.name=def.name; rec.group=def.group; rec.max_charges=def.max_charges; rec.rechargeable=def.rechargeable==true;
    rec.last_charges=after; rec.last_seen_at=now; rec.last_change_at=now; rec.last_change='recharged'; rec.last_change_source='npc dialogue';
    rec.last_recharged_at=now; rec.last_conquest_cost=tonumber(cost); rec.authoritative_until=now+5;
    if cached_items[def.id] then cached_items[def.id].charges=after; end
    local ev={kind='recharged',id=def.id,name=def.name,group=def.group,before=before,after=after,max=def.max_charges,cost=tonumber(cost),source='npc dialogue',definition=def,authoritative=true};
    record_event(c,ev); dispatch(ev); request_save(); M.invalidate(2);
    return true;
end

function M.on_text(s)
    return recharge_from_text(s);
end

function M.poll()
    if not dirty then return; end
    if full_rescan_due>0 and os.time()<full_rescan_due then return; end
    M.scan(true);
end

function M.init(ctx)
    HC=ctx;
    local p=HC.modules and HC.modules.packets or nil;
    if p and p.register then
        -- 0x020 identifies the exact changed inventory slot, so normal charge
        -- updates no longer trigger a 17-container scan.  The old 0x01D/1E/1F
        -- blanket invalidations were intentionally removed; they can be noisy
        -- during ordinary gameplay and do not identify a reusable-item change.
        p.register(0x020,'reusable item targeted update',on_item_update);
    end
    if p and p.register_text then p.register_text('reusable item recharge',M.on_text); end
end

return M;
