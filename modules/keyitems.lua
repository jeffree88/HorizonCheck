local M = {};
local HC;
local bit = require('bit');

local TARGETS = {
    { key='miasma_filter', label='Miasma Filter', needles={'miasma filter'} },
    { key='zephyr_fan', label='Zephyr Fan', needles={'zephyr fan'} },
    { key='enm_promy_dem', label='Censer of Antipathy', needles={'censer of antipathy'} },
    { key='enm_promy_holla', label='Censer of Abandonment', needles={'censer of abandonment'} },
    { key='enm_promy_mea', label='Censer of Animus', needles={'censer of animus'} },
    { key='enm_promy_vahzl', label='Censer of Acrimony', needles={'censer of acrimony'} },
    { key='enm_monarch_linn', label='Monarch Beard', needles={'monarch beard'} },
    { key='enm_shrouded_maw', label='Astral Covenant', needles={'astral covenant'} },
    { key='enm_mine_2716', label='Shaft Gate Operating Dial', needles={'shaft gate operating dial'} },
    { key='secret_imperial_order', label='Secret Imperial Order', needles={'secret imperial order'} },
    { key='cosmo_cleanse', label='Cosmo-Cleanse', needles={'cosmo-cleanse','cosmo cleanse'} },
    { key='imperial_army_id_tag', label='Imperial Army I.D. Tag', needles={'imperial army i.d. tag','imperial army id tag'} },
    { key='eco_bastok_proof', label='Indigested Ore', needles={'indigested ore'} },
    { key='eco_sandoria_proof', label='Indigested Stalagmite', needles={'indigested stalagmite'} },
    { key='eco_windurst_proof', label='Indigested Meat', needles={'indigested meat'} },
    { key='tavnazian_cookbook', label='Tavnazian Cookbook', needles={'tavnazian cookbook'} },
    { key='rivernewort', label='Rivernewort', needles={'rivernewort'} },
    { key='uninvited_permit', label='Monarch Linn Patrol Permit', needles={'monarch linn patrol permit'} },
};

local resolved = {};
local last = { at=nil, api_ok=false, rows={}, error=nil };
local last_test = nil;
local last_scan = nil;
local ki_bitmap = {};
local ki_packet_seen = {};
local last_bitmap = { at=nil, tables=0, cosmo=nil, api=nil, rows={} };

-- Resource-name indexing used to scan all 65,536 key-item resource slots from
-- inside every 0x055 packet callback.  A zone can deliver many 0x055 tables,
-- multiplying that work into millions of ResourceManager calls and visibly
-- freezing the client.  v6.86.1 builds the index incrementally from d3d_present
-- and keeps packet callbacks O(1).
local generic_resolved_by_name = {};
local generic_name_index = {};
local resource_index_next = 0;
local resource_index_complete = false;
local resource_index_started_at = nil;
local resource_index_completed_at = nil;
local RESOURCE_INDEX_MAX = 65535;
local RESOURCE_INDEX_CHUNK = 384;
local pending_bitmap_reconcile = false;
local full_index_reconcile_done = false;

local function lower(s) return string.lower(tostring(s or '')); end

local function normalize_ki_name(s)
    s=lower(s)
    s=s:gsub('’', "'"):gsub('`', "'")
    s=s:gsub('[^%w]+',' ')
    s=s:gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$','')
    return s
end

-- Verified HorizonXI key-item resource IDs captured from the server's 0x055
-- ownership bitmap.  These IDs let critical ownership checks work immediately
-- after the relevant bitmap table arrives, without waiting for the incremental
-- 65,536-name resource index to finish.  The resource index still supplements
-- this registry for all other key items and duplicate-name candidates.
local VERIFIED_KEY_ITEM_IDS = {
    [normalize_ki_name('Cosmo-Cleanse')] = { id=734, name='Cosmo-Cleanse' },
    [normalize_ki_name('Hydra Corps Command Scepter')] = { id=486, name='Hydra Corps Command Scepter' },
    [normalize_ki_name('Hydra Corps Eyeglass')] = { id=487, name='Hydra Corps Eyeglass' },
    [normalize_ki_name('Hydra Corps Lantern')] = { id=488, name='Hydra Corps Lantern' },
    [normalize_ki_name('Hydra Corps Tactical Map')] = { id=489, name='Hydra Corps Tactical Map' },
    [normalize_ki_name('Hydra Corps Insignia')] = { id=490, name='Hydra Corps Insignia' },
    [normalize_ki_name('Hydra Corps Battle Standard')] = { id=491, name='Hydra Corps Battle Standard' },
    [normalize_ki_name('Dynamis - Valkurm Sliver')] = { id=739, name='Dynamis - Valkurm sliver' },
    [normalize_ki_name('Dynamis - Buburimu Sliver')] = { id=740, name='Dynamis - Buburimu sliver' },
    [normalize_ki_name('Dynamis - Qufim Sliver')] = { id=741, name='Dynamis - Qufim sliver' },
    [normalize_ki_name('Dynamis - Tavnazia Sliver')] = { id=742, name='Dynamis - Tavnazia sliver' },
    [normalize_ki_name('Serpent Rumors')] = { id=1977, name='Serpent Rumors' },
};

function M.known_id(name)
    local r=VERIFIED_KEY_ITEM_IDS[normalize_ki_name(name)];
    return r and r.id or nil;
end

function M.evidence_key(name)
    local key=normalize_ki_name(name):gsub('%s+','_');
    return 'keyitem:'..key;
end

local function evidence_submit(name,value,source,confidence,rank,details,meta)
    local ev=HC and HC.modules and HC.modules.evidence or nil;
    if not ev or not ev.submit then return nil; end
    local result=nil;
    pcall(function()
        result=ev.submit(M.evidence_key(name),value,{
            source=source,
            source_id='keyitems:'..tostring(source or 'unknown'),
            confidence=confidence or 'UNKNOWN',
            rank=rank,
            details=details,
            meta=meta,
        });
    end);
    return result;
end

local PERMANENT_KEY_ITEMS = {
    [normalize_ki_name('Serpent Rumors')] = true,
    -- Dynamis boss-clear rewards are permanent progression key items.
    [normalize_ki_name('Hydra Corps Command Scepter')] = true,
    [normalize_ki_name('Hydra Corps Eyeglass')] = true,
    [normalize_ki_name('Hydra Corps Lantern')] = true,
    [normalize_ki_name('Hydra Corps Tactical Map')] = true,
    [normalize_ki_name('Hydra Corps Insignia')] = true,
    [normalize_ki_name('Hydra Corps Battle Standard')] = true,
    [normalize_ki_name('Dynamis - Valkurm Sliver')] = true,
    [normalize_ki_name('Dynamis - Buburimu Sliver')] = true,
    [normalize_ki_name('Dynamis - Qufim Sliver')] = true,
    [normalize_ki_name('Dynamis - Tavnazia Sliver')] = true,
};

local function permanent_store()
    if not HC or not HC.modules or not HC.modules.state or not HC.modules.state.get_char then return nil; end
    local c=HC.modules.state.get_char();
    if type(c)~='table' then return nil; end
    c.permanent_key_items=type(c.permanent_key_items)=='table' and c.permanent_key_items or {};
    return c.permanent_key_items,c;
end

local function permanent_proof(name)
    local key=normalize_ki_name(name);
    if PERMANENT_KEY_ITEMS[key]~=true then return nil; end
    local store=permanent_store();
    local rec=store and store[key] or nil;
    if rec==true then return {source='saved permanent key-item proof'}; end
    if type(rec)=='table' and rec.owned==true then return rec; end
    return nil;
end

function M.is_permanent_name(name)
    return PERMANENT_KEY_ITEMS[normalize_ki_name(name)]==true;
end

function M.confirm_permanent(name,source)
    local key=normalize_ki_name(name);
    if PERMANENT_KEY_ITEMS[key]~=true then return false; end
    local store,c=permanent_store();
    if not store then return false; end
    local old=store[key];
    if type(old)=='table' and old.owned==true then return true; end
    store[key]={owned=true,name=tostring(name),source=tostring(source or 'confirmed permanent key-item proof'),verified_at=os.time()};
    evidence_submit(name,true,tostring(source or 'saved permanent key-item proof'),'VERIFIED',100,'Permanent key-item proof is sticky and cannot be consumed.');
    if HC.modules.state and HC.modules.state.save then HC.modules.state.save(); end
    return true;
end

local function on_text(s,e)
    local low=normalize_ki_name(s);
    if low=='' then return; end
    for key in pairs(PERMANENT_KEY_ITEMS) do
        if low:find('obtained key item',1,true) and low:find(key,1,true) then
            M.confirm_permanent(key,'Obtained key item message');
        end
    end
end

local function get_player()
    local player=nil;
    local ok,err=pcall(function()
        local mm=AshitaCore:GetMemoryManager();
        player=mm and mm:GetPlayer() or nil;
    end);
    if not ok or player==nil then return nil,'GetPlayer unavailable: '..tostring(err or 'nil player'); end
    local api_test_ok=pcall(function() player:HasKeyItem(0); end);
    if not api_test_ok then return nil,'IPlayer:HasKeyItem(id) is unavailable on this Ashita build.'; end
    return player,nil;
end

local function resource_name(id)
    local rm=nil;
    local ok=pcall(function() rm=AshitaCore:GetResourceManager(); end);
    if not ok or rm==nil or not rm.GetString then return nil; end
    local name=nil;
    pcall(function() name=rm:GetString('keyitems.names',id); end);
    if type(name)=='string' and #name>1 then return name; end
    return nil;
end

local function index_resource_id(id)
    local rn=resource_name(id);
    if not rn then return; end
    local k=normalize_ki_name(rn);
    if k=='' then return; end
    local rows=generic_name_index[k];
    if not rows then rows={}; generic_name_index[k]=rows; end
    rows[#rows+1]={id=id,name=rn};
end

local function build_resource_index_chunk(limit)
    if resource_index_complete then return true; end
    if resource_index_started_at==nil then resource_index_started_at=os.time(); end
    limit=math.max(32,math.floor(tonumber(limit) or RESOURCE_INDEX_CHUNK));
    local last=math.min(RESOURCE_INDEX_MAX,resource_index_next+limit-1);
    for id=resource_index_next,last do index_resource_id(id); end
    resource_index_next=last+1;
    if resource_index_next>RESOURCE_INDEX_MAX then
        resource_index_complete=true;
        resource_index_completed_at=os.time();
        -- Populate target first-match compatibility cache without any new scan.
        for _,t in ipairs(TARGETS) do
            local rows=generic_name_index[normalize_ki_name(t.label)];
            resolved[t.key]=(rows and rows[1]) or false;
        end
    end
    return resource_index_complete;
end

local function indexed_candidates(name)
    local key=normalize_ki_name(name);
    local indexed=generic_name_index[key];
    local verified=VERIFIED_KEY_ITEM_IDS[key];
    if verified then
        local out={{id=verified.id,name=verified.name or resource_name(verified.id)}};
        local seen={[tonumber(verified.id)]=true};
        for _,r in ipairs(type(indexed)=='table' and indexed or {}) do
            local id=tonumber(r.id);
            if id and not seen[id] then
                seen[id]=true;
                out[#out+1]=r;
            end
        end
        return out;
    end
    if type(indexed)=='table' and #indexed>0 then return indexed; end
    return nil;
end

local function resolve_target(t)
    if resolved[t.key] ~= nil then return resolved[t.key] or nil; end
    local rows=indexed_candidates(t.label);
    if rows then resolved[t.key]=rows[1]; return rows[1]; end
    if resource_index_complete then resolved[t.key]=false; end
    return nil;
end


local function has_key_item(player,id)
    local ok,val=pcall(function() return player:HasKeyItem(id); end);
    if not ok then return nil,tostring(val); end
    return val==true,nil;
end

local function u16le(s, offset)
    local b1,b2=string.byte(s,offset,offset+1);
    if not b1 or not b2 then return nil; end
    return b1 + bit.lshift(b2,8);
end

local function u32le(s, offset)
    local b1,b2,b3,b4=string.byte(s,offset,offset+3);
    if not b1 or not b2 or not b3 or not b4 then return nil; end
    return b1 + bit.lshift(b2,8) + bit.lshift(b3,16) + bit.lshift(b4,24);
end

local function bitmap_has(id)
    id=tonumber(id);
    if not id then return nil,'invalid id'; end
    local table_index=math.floor(id/512);
    local bit_index=id%512;
    local dword_index=math.floor(bit_index/32);
    local bit_offset=bit_index%32;
    local tbl=ki_bitmap[table_index];
    if not tbl then return nil,'table '..tostring(table_index)..' not received'; end
    local dword=tbl[dword_index] or 0;
    return bit.band(dword,bit.lshift(1,bit_offset))~=0,nil;
end

local function bitmap_table_count()
    local n=0; for _ in pairs(ki_packet_seen) do n=n+1; end; return n;
end

local function reconcile_target(t, owned, id)
    if owned==nil or not HC or not HC.modules then return; end
    local source='0x055 key-item bitmap';
    evidence_submit(t.label,owned,source,'VERIFIED',90,'Authoritative server key-item bitmap.',{id=id,key=t.key});

    -- ENM battlefield key items: bitmap ownership is authoritative for whether
    -- the KI is presently held. ENM compares session-local false -> true bitmap
    -- transitions to start the five-day timer without inventing a timestamp
    -- from the first snapshot after addon load.
    if HC.modules.enm and HC.modules.enm.reconcile_keyitem then
        local enm_group_by_key={
            miasma_filter='boneyard',
            zephyr_fan='bearclaw',
            enm_promy_dem='promy_dem',
            enm_promy_holla='promy_holla',
            enm_promy_mea='promy_mea',
            enm_promy_vahzl='promy_vahzl',
            enm_monarch_linn='monarch_linn',
            enm_shrouded_maw='shrouded_maw',
            enm_mine_2716='mine_2716',
        };
        local group_id=enm_group_by_key[t.key];
        if group_id then pcall(HC.modules.enm.reconcile_keyitem,group_id,owned,source,id); end
    end
    if t.key=='secret_imperial_order' and HC.modules.isnm and HC.modules.isnm.reconcile_order_ownership then
        pcall(HC.modules.isnm.reconcile_order_ownership,owned,source,id);
    end

    -- Cosmo-Cleanse is consumed/obtained outside a dedicated Limbus module.
    -- Keep the authoritative bitmap result here for Weekly / Attention UI.
    if t.key=='imperial_army_id_tag' and HC.modules.assault and HC.modules.assault.reconcile_character_tag_ownership then
        pcall(HC.modules.assault.reconcile_character_tag_ownership,owned,source,id);
    end

    -- Eco-Warrior proof KIs are authoritative evidence that the battlefield
    -- objective is complete and the character has proof ready to turn in.
    -- Absence never marks an Eco-War complete; completion still requires the
    -- existing nation NPC/reward evidence.
    if HC.modules.eco and HC.modules.eco.reconcile_keyitem_ownership then
        if t.key=='eco_bastok_proof' then
            pcall(HC.modules.eco.reconcile_keyitem_ownership,'bastok',owned,source,id,t.label);
        elseif t.key=='eco_sandoria_proof' then
            pcall(HC.modules.eco.reconcile_keyitem_ownership,'sandoria',owned,source,id,t.label);
        elseif t.key=='eco_windurst_proof' then
            pcall(HC.modules.eco.reconcile_keyitem_ownership,'windurst',owned,source,id,t.label);
        end
    end

    if t.key=='tavnazian_cookbook' and HC.modules.ovens and HC.modules.ovens.reconcile_keyitem_ownership then
        pcall(HC.modules.ovens.reconcile_keyitem_ownership,owned,source,id,t.label);
    end
    if t.key=='rivernewort' and HC.modules.spice and HC.modules.spice.reconcile_keyitem_ownership then
        pcall(HC.modules.spice.reconcile_keyitem_ownership,owned,source,id,t.label);
    end

    -- Uninvited Guests permit ownership is authoritative from the 0x055
    -- bitmap.  Ownership means the weekly battlefield is ready to enter.
    -- Absence alone never means completion because the permit is consumed on
    -- battlefield entry and a failed run also consumes the weekly opportunity.
    if t.key=='uninvited_permit' and HC.modules.automation and HC.modules.automation.reconcile_uninvited_permit then
        pcall(HC.modules.automation.reconcile_uninvited_permit,owned,source,id,t.label);
    end

    if t.key=='cosmo_cleanse' then
        local c=HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char() or nil;
        if type(c)=='table' then
            c.limbus_keyitem=type(c.limbus_keyitem)=='table' and c.limbus_keyitem or {};
            local lk=c.limbus_keyitem;
            if lk.cosmo_cleanse_owned~=owned or lk.source~=source then
                lk.cosmo_cleanse_owned=owned;
                lk.verified_at=os.time();
                lk.source=source;
                lk.resource_id=id;
                if HC.modules.state then
                    if HC.modules.state.request_save then HC.modules.state.request_save(1); elseif HC.modules.state.save then HC.modules.state.save(); end
                end
            else
                lk.verified_at=os.time();
            end
        end
    end
end

local function reconcile_bitmap_targets()
    for _,t in ipairs(TARGETS) do
        -- Candidate IDs come from the incremental one-time resource index.
        -- Packet handling therefore touches only the handful of exact IDs for
        -- each tracked KI instead of rescanning all 65,536 resources.
        local rows=indexed_candidates(t.label);
        local seen=false; local chosen_id=nil; local any_owned=false;
        for _,r in ipairs(rows or {}) do
            local owned=select(1,bitmap_has(r.id));
            if owned~=nil then
                seen=true; chosen_id=chosen_id or r.id;
                if owned==true then any_owned=true; chosen_id=r.id; break; end
            end
        end
        if seen then reconcile_target(t,any_owned,chosen_id); end
    end
end

-- Permanent KIs are not all part of TARGETS.  Reconcile the verified permanent
-- registry directly whenever a new 0x055 table arrives so boss-clear proof is
-- persisted even if no UI panel happens to query that key item during the
-- current session.  This is especially important for Dynamis clears: after one
-- authoritative bitmap observation, a reload can use sticky proof without
-- waiting for another zone packet burst.
local function reconcile_verified_permanent_ids()
    for key,meta in pairs(VERIFIED_KEY_ITEM_IDS) do
        if PERMANENT_KEY_ITEMS[key]==true and meta and meta.id then
            local owned=select(1,bitmap_has(meta.id));
            if owned==true then
                M.confirm_permanent(meta.name or key,'0x055 key-item bitmap');
            end
        end
    end
end

local function refresh_bitmap_status(announce)
    last_bitmap={at=os.time(),tables=bitmap_table_count(),cosmo=nil,api=nil,rows={}};
    local player=get_player();
    for _,t in ipairs(TARGETS) do
        local r=resolve_target(t);
        local row={key=t.key,label=t.label,id=r and r.id or nil,name=r and r.name or nil};
        if r then
            row.bitmap,row.bitmap_error=bitmap_has(r.id);
            if player then row.api=select(1,has_key_item(player,r.id)); end
            if t.key=='cosmo_cleanse' then last_bitmap.cosmo=row.bitmap; last_bitmap.api=row.api; end
        else
            row.bitmap_error='resource name not found';
        end
        last_bitmap.rows[#last_bitmap.rows+1]=row;
    end
    if announce and HC then
        HC.msg(string.format('KI Bitmap Test: %d 0x055 table(s) received.',last_bitmap.tables));
        for _,row in ipairs(last_bitmap.rows) do
            local b=row.bitmap==true and 'OWNED' or (row.bitmap==false and 'NOT OWNED' or 'UNKNOWN');
            local a=row.api==true and 'OWNED' or (row.api==false and 'NOT OWNED' or 'UNKNOWN');
            HC.msg(string.format('KI Bitmap: %s [id %s] packet=%s api=%s%s',row.label,tostring(row.id or '?'),b,a,row.bitmap_error and (' ('..row.bitmap_error..')') or ''));
        end
    end
    return last_bitmap;
end

local function on_ki_packet(e)
    local pkt=e and (e.data or e.data_raw) or nil;
    if type(pkt)~='string' or #pkt<0x88 then return; end
    local table_index=u16le(pkt,0x84+1);
    if table_index==nil or table_index<0 or table_index>127 then return; end
    local tbl={};
    for i=0,15 do
        tbl[i]=u32le(pkt,0x04+1+(i*4)) or 0;
    end
    ki_bitmap[table_index]=tbl;
    ki_packet_seen[table_index]=os.time();
    -- Never scan resources or serialize state from packet_in.  Defer all
    -- reconciliation to the lightweight per-frame poll after the packet burst.
    pending_bitmap_reconcile=true;
end

local function find_target(token)
    token=lower(token);
    if token=='' or token=='cosmo' or token=='cosmocleanse' or token=='cosmo-cleanse' then
        token='cosmo_cleanse';
    end
    for _,t in ipairs(TARGETS) do
        if t.key==token or lower(t.label)==token or lower(t.label):find(token,1,true) then return t; end
    end
    return nil;
end

function M.probe()
    last={at=os.time(),api_ok=false,rows={},error=nil};
    local player,err=get_player();
    if not player then
        last.error=err;
        if HC then HC.msg('Key Item probe failed: '..last.error); end
        return last;
    end
    last.api_ok=true;

    for _,t in ipairs(TARGETS) do
        local r=resolve_target(t);
        local row={key=t.key,label=t.label,id=r and r.id or nil,name=r and r.name or nil,owned=nil};
        if r then row.owned,row.error=has_key_item(player,r.id); else row.error='resource name not found'; end
        last.rows[#last.rows+1]=row;
    end

    if HC then
        HC.msg('Key Item API probe complete. Results are diagnostic only.');
        for _,row in ipairs(last.rows) do
            if row.id then
                HC.msg(string.format('KI Probe: %s [resource id %d] = %s',row.label,row.id,row.owned==true and 'OWNED' or (row.owned==false and 'NOT OWNED' or 'UNKNOWN')));
            else
                HC.msg('KI Probe: '..row.label..' = UNRESOLVED');
            end
        end
    end
    return last;
end

function M.test_target(token,radius)
    local t=find_target(token or 'cosmo');
    radius=math.max(1,math.min(64,tonumber(radius) or 16));
    last_test={at=os.time(),target=token or 'cosmo',radius=radius,error=nil,resolved=nil,checks={},owned_nearby={}};
    if not t then last_test.error='Unknown target.'; if HC then HC.msg('KI Test: unknown target.'); end; return last_test; end
    local player,err=get_player();
    if not player then last_test.error=err; if HC then HC.msg('KI Test failed: '..err); end; return last_test; end
    local r=resolve_target(t);
    if not r then last_test.error='Resource name not found.'; if HC then HC.msg('KI Test: resource name not found for '..t.label); end; return last_test; end
    last_test.resolved={key=t.key,label=t.label,id=r.id,name=r.name};

    local candidates={r.id,r.id-1,r.id+1};
    local seen={};
    for _,id in ipairs(candidates) do
        if id>=0 and not seen[id] then
            seen[id]=true;
            local owned,e=has_key_item(player,id);
            last_test.checks[#last_test.checks+1]={id=id,name=resource_name(id),owned=owned,error=e};
        end
    end
    local a=math.max(0,r.id-radius); local b=r.id+radius;
    for id=a,b do
        local owned=has_key_item(player,id);
        if owned==true then last_test.owned_nearby[#last_test.owned_nearby+1]={id=id,name=resource_name(id)}; end
    end
    if HC then
        HC.msg(string.format('KI Test: %s resolved to resource id %d (%s).',t.label,r.id,r.name or '?'));
        for _,row in ipairs(last_test.checks) do
            HC.msg(string.format('KI Test candidate %d [%s] = %s',row.id,row.name or '?',row.owned==true and 'OWNED' or (row.owned==false and 'NOT OWNED' or 'UNKNOWN')));
        end
        if #last_test.owned_nearby==0 then
            HC.msg(string.format('KI Test: no HasKeyItem=true IDs found within +/- %d of resource id %d.',radius,r.id));
        else
            for _,row in ipairs(last_test.owned_nearby) do HC.msg(string.format('KI Test nearby OWNED: id %d [%s]',row.id,row.name or '?')); end
        end
    end
    return last_test;
end

function M.scan_range(first,last_id)
    first=math.floor(tonumber(first) or 650); last_id=math.floor(tonumber(last_id) or 850);
    if first>last_id then first,last_id=last_id,first; end
    first=math.max(0,first); last_id=math.min(65535,last_id);
    if (last_id-first)>2048 then last_id=first+2048; end
    last_scan={at=os.time(),first=first,last_id=last_id,error=nil,owned={}};
    local player,err=get_player();
    if not player then last_scan.error=err; if HC then HC.msg('KI Scan failed: '..err); end; return last_scan; end
    for id=first,last_id do
        local owned=has_key_item(player,id);
        if owned==true then last_scan.owned[#last_scan.owned+1]={id=id,name=resource_name(id)}; end
    end
    if HC then
        HC.msg(string.format('KI Scan %d-%d complete: %d owned ID(s) reported.',first,last_id,#last_scan.owned));
        if #last_scan.owned==0 then HC.msg('KI Scan: no HasKeyItem=true IDs in this range.');
        else
            for _,row in ipairs(last_scan.owned) do HC.msg(string.format('KI Scan OWNED: id %d [%s]',row.id,row.name or '?')); end
        end
    end
    return last_scan;
end


local function build_key_item_name_index()
    -- Compatibility accessor: indexing is intentionally incremental.
    return generic_name_index;
end

local function resolve_key_item_candidates(name)
    local want=normalize_ki_name(name);
    if want=='' then return nil; end
    if generic_resolved_by_name[want]~=nil then return generic_resolved_by_name[want] or nil; end
    build_key_item_name_index();
    local rows=indexed_candidates(name);
    if type(rows)=='table' and #rows>0 then
        -- Before the full index completes, do not permanently cache partial
        -- duplicate candidates.  Exact duplicates discovered later must still
        -- participate in ownership resolution.
        if resource_index_complete then generic_resolved_by_name[want]=rows; end
        return rows;
    end
    if resource_index_complete then generic_resolved_by_name[want]=false; end
    return nil;
end

local function resolve_key_item_name(name)
    local rows=resolve_key_item_candidates(name);
    return rows and rows[1] or nil;
end

function M.ownership_id(id,name)
    id=tonumber(id);
    if not id then return nil,'invalid id',nil,'unavailable'; end
    name=tostring(name or resource_name(id) or ('Key Item '..tostring(id)));

    -- Exact-ID path for callers with a verified HorizonXI resource ID.  This
    -- bypasses resource-name indexing entirely and reads the authoritative
    -- 0x055 table directly.
    local bitmap_owned,bitmap_error=bitmap_has(id);
    if bitmap_owned~=nil then
        evidence_submit(name,bitmap_owned,'0x055 key-item bitmap','VERIFIED',90,
            'Authoritative server bitmap for verified key-item ID.',{id=id});
        if bitmap_owned==true and M.is_permanent_name(name) then
            M.confirm_permanent(name,'0x055 key-item bitmap');
        end
        return bitmap_owned,bitmap_error,id,'0x055 key-item bitmap';
    end

    local proof=permanent_proof(name);
    if proof then
        evidence_submit(name,true,proof.source or 'saved permanent key-item proof','VERIFIED',100,
            'Historical proof for a permanent key item.',{id=id});
        return true,nil,id,proof.source or 'saved permanent key-item proof';
    end

    -- HorizonXI/Ashita HasKeyItem(false) is a known false-negative.  A true
    -- result is still safe as positive fallback evidence; false remains UNKNOWN.
    local player=get_player();
    if player then
        local api_owned,api_error=has_key_item(player,id);
        if api_owned==true then
            evidence_submit(name,true,'Ashita HasKeyItem','LIVE',60,'Positive API fallback for verified key-item ID.',{id=id});
            return true,nil,id,'Ashita HasKeyItem';
        elseif api_owned==false then
            return nil,'HasKeyItem=false ignored on HorizonXI; waiting for authoritative 0x055 table',id,'Ashita HasKeyItem (diagnostic only)';
        elseif api_error then
            return nil,api_error,id,'unavailable';
        end
    end
    return nil,bitmap_error,id,'unavailable';
end

function M.ownership_name(name)
    local rows=resolve_key_item_candidates(name);
    if not rows then
        if not resource_index_complete then
            local pct=math.floor((math.min(resource_index_next,RESOURCE_INDEX_MAX+1)/(RESOURCE_INDEX_MAX+1))*100);
            return nil,'resource index building ('..tostring(pct)..'%)',nil,'indexing';
        end
        return nil,'resource name not found',nil,'unavailable';
    end

    local ev=HC and HC.modules and HC.modules.evidence or nil;
    local key=M.evidence_key(name);

    -- Sticky proof for explicitly permanent key items. This is stronger than a
    -- client API false-negative because the item cannot be consumed once earned.
    local proof=permanent_proof(name);
    if proof then
        evidence_submit(name,true,proof.source or 'saved permanent key-item proof','VERIFIED',100,'Historical proof for a permanent key item.',{id=rows[1].id});
    end

    -- Saved packet-confirmed Cosmo-Cleanse state bridges reloads until a newer
    -- authoritative 0x055 observation arrives. It outranks HasKeyItem(), which
    -- is known to false-negative this KI on HorizonXI, but not a fresh bitmap.
    local saved_cosmo_owned=nil;
    local saved_cosmo_source=nil;
    local saved_cosmo_id=nil;
    if normalize_ki_name(name)==normalize_ki_name('Cosmo-Cleanse') then
        local c=HC and HC.modules and HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char() or nil;
        local lk=type(c)=='table' and type(c.limbus_keyitem)=='table' and c.limbus_keyitem or nil;
        if lk and lk.cosmo_cleanse_owned~=nil then
            saved_cosmo_owned=lk.cosmo_cleanse_owned==true;
            saved_cosmo_source=lk.source or 'saved 0x055 state';
            saved_cosmo_id=tonumber(lk.resource_id) or M.known_id('Cosmo-Cleanse');
            local saved_rank=(saved_cosmo_owned==true) and 75 or 50;
            evidence_submit(name,saved_cosmo_owned,saved_cosmo_source,'CONFIRMED',saved_rank,
                'Persisted Cosmo-Cleanse ownership from a previous packet-confirmed state. A live 0x055 bitmap supersedes this saved bridge.',
                {id=saved_cosmo_id,verified_at=lk.verified_at});
        end
    end

    -- Aggregate every exact same-name resource candidate before publishing one
    -- API observation. A single legacy candidate reporting false must never
    -- erase another exact candidate that reports true.
    local player=get_player();
    local api_seen=false;
    local api_owned=false;
    local api_error=nil;
    local api_true_id=nil;
    if player then
        for _,r in ipairs(rows) do
            local owned,err=has_key_item(player,r.id);
            if owned~=nil then
                api_seen=true;
                if owned==true then api_owned=true; api_true_id=r.id; break; end
            elseif err then api_error=api_error or err; end
        end
        if api_seen then
            evidence_submit(name,api_owned,'Ashita HasKeyItem','LIVE',60,
                string.format('Aggregated %d exact resource candidate(s).',#rows),
                {id=api_true_id or rows[1].id,candidates=#rows});
        end
    end

    -- Server 0x055 bitmap is authoritative for currently-held consumable KIs.
    -- Again aggregate every exact same-name resource candidate.
    local bitmap_seen=false;
    local bitmap_owned=false;
    local bitmap_error=nil;
    local bitmap_true_id=nil;
    for _,r in ipairs(rows) do
        local owned,err=bitmap_has(r.id);
        if owned~=nil then
            bitmap_seen=true;
            if owned==true then bitmap_owned=true; bitmap_true_id=r.id; break; end
        elseif err then bitmap_error=bitmap_error or err; end
    end
    if bitmap_seen then
        evidence_submit(name,bitmap_owned,'0x055 key-item bitmap','VERIFIED',90,
            string.format('Server bitmap across %d exact resource candidate(s).',#rows),
            {id=bitmap_true_id or rows[1].id,candidates=#rows});
    end

    -- Runtime ownership policy on HorizonXI:
    --   1) If the relevant server 0x055 table is cached, its bit is the answer.
    --      Do not route this through the generic resolver: HasKeyItem(false) is
    --      a confirmed false-negative on this client and must never alter it.
    --   2) Before a bitmap table has arrived, sticky permanent proof / saved
    --      Cosmo packet state may bridge reloads.
    --   3) HasKeyItem(true) can be accepted as positive fallback evidence, but
    --      HasKeyItem(false) is diagnostic-only and resolves to UNKNOWN.
    if bitmap_seen then
        local id=bitmap_true_id or rows[1].id;
        if bitmap_owned==true and M.is_permanent_name(name) then
            M.confirm_permanent(name,'0x055 key-item bitmap');
        end
        return bitmap_owned,bitmap_error,id,'0x055 key-item bitmap';
    end
    if proof then
        return true,nil,rows[1].id,proof.source or 'saved permanent key-item proof';
    end
    if saved_cosmo_owned~=nil then
        return saved_cosmo_owned,nil,saved_cosmo_id or rows[1].id,saved_cosmo_source or 'saved 0x055 state';
    end
    if api_seen and api_owned==true then
        return true,nil,api_true_id or rows[1].id,'Ashita HasKeyItem';
    end
    if api_seen then
        return nil,'HasKeyItem=false ignored on HorizonXI; waiting for authoritative 0x055 table',rows[1].id,'Ashita HasKeyItem (diagnostic only)';
    end
    if ev and ev.resolve then
        local result=ev.resolve(key);
        local id=result and result.meta and result.meta.id or rows[1].id;
        if result and result.value==true then return true,nil,id,result.source; end
    end
    return nil,api_error or bitmap_error,rows[1].id,'unavailable';
end

function M.ownership(token)
    local t=find_target(token or '');
    if not t then return nil,'unknown target',nil; end
    local r=resolve_target(t);
    if not r then return nil,'resource name not found',nil; end
    local owned,err=bitmap_has(r.id);
    return owned,err,r.id;
end

function M.cosmo_cleanse_status()
    local owned,err,id,source=M.ownership_name('Cosmo-Cleanse');
    local ev=HC and HC.modules and HC.modules.evidence or nil;
    local resolved=ev and ev.resolve and ev.resolve(M.evidence_key('Cosmo-Cleanse')) or nil;
    return {
        owned=owned,
        error=err,
        id=id,
        source=source or (resolved and resolved.source) or 'key-item ownership unavailable',
        confidence=resolved and resolved.confidence or 'UNKNOWN',
        conflict=resolved and resolved.conflict or false,
        tables=bitmap_table_count(),
    };
end

function M.owned_key_items()
    -- Return every currently-owned key item represented by the 0x055 tables
    -- received this session.  Do not limit this to the original 0..6 table
    -- range: permanent KIs can live in higher key-item log tables.
    local out={};
    for table_index,tbl in pairs(ki_bitmap) do
        if type(tbl)=='table' then
            for dword_index=0,15 do
                local dword=tbl[dword_index] or 0;
                if dword~=0 then
                    for bit_offset=0,31 do
                        if bit.band(dword,bit.lshift(1,bit_offset))~=0 then
                            local id=(tonumber(table_index) or 0)*512 + dword_index*32 + bit_offset;
                            out[#out+1]={id=id,name=resource_name(id),table_index=table_index};
                        end
                    end
                end
            end
        end
    end
    table.sort(out,function(a,b) return (a.id or 0)<(b.id or 0); end);
    return out;
end


local function bitmap_table_indices()
    local out={};
    for idx in pairs(ki_bitmap) do out[#out+1]=tonumber(idx) or idx; end
    table.sort(out,function(a,b) return tonumber(a or 0)<tonumber(b or 0); end);
    return out;
end

local function all_indexed_resource_rows()
    local out={};
    local seen={};
    for _,rows in pairs(generic_name_index) do
        for _,r in ipairs(rows or {}) do
            local id=tonumber(r.id);
            if id and not seen[id] then
                seen[id]=true;
                out[#out+1]={id=id,name=r.name or resource_name(id)};
            end
        end
    end
    table.sort(out,function(a,b) return (a.id or 0)<(b.id or 0); end);
    return out;
end

-- Direct KI snapshot used by the permanent-key-item learner.  Unlike Learn's
-- packet window, this reads the key-item bitmap that HorizonCheck has already
-- cached since addon load.  It also performs a user-triggered HasKeyItem scan
-- across only resource IDs that actually resolve as key items once the
-- incremental resource index is complete.  This avoids the old 65,536-ID
-- ResourceManager scan in packet callbacks while still giving us discovery
-- coverage for KIs whose 0x055 table was not cached.
function M.permanent_snapshot()
    local snap={
        at=os.time(),
        bitmap_tables=bitmap_table_count(),
        bitmap_indices=bitmap_table_indices(),
        resource_index=M.index_status(),
        api_ok=false,
        api_error=nil,
        api_scan_complete=false,
        bitmap_owned_count=0,
        api_owned_count=0,
        owned={},
        known_permanent={},
    };

    local merged={};
    local function ensure_row(id,name,table_index)
        id=tonumber(id);
        if not id then return nil; end
        local row=merged[id];
        if not row then
            row={id=id,name=name or resource_name(id),table_index=table_index,bitmap=false,api=false,known_permanent=false,saved_proof=false};
            merged[id]=row;
        else
            if (not row.name or row.name=='') and name then row.name=name; end
            if row.table_index==nil and table_index~=nil then row.table_index=table_index; end
        end
        row.known_permanent=M.is_permanent_name(row.name or '');
        local proof=permanent_proof(row.name or '');
        row.saved_proof=proof~=nil;
        row.proof_source=proof and proof.source or nil;
        return row;
    end

    for _,r in ipairs(M.owned_key_items()) do
        local row=ensure_row(r.id,r.name,r.table_index);
        if row then row.bitmap=true; snap.bitmap_owned_count=snap.bitmap_owned_count+1; end
    end

    local player,perr=get_player();
    snap.api_ok=player~=nil;
    snap.api_error=perr;
    if player and resource_index_complete then
        snap.api_scan_complete=true;
        for _,r in ipairs(all_indexed_resource_rows()) do
            local owned=select(1,has_key_item(player,r.id));
            if owned==true then
                local row=ensure_row(r.id,r.name,nil);
                if row and not row.api then row.api=true; snap.api_owned_count=snap.api_owned_count+1; end
            end
        end
    end

    for _,row in pairs(merged) do snap.owned[#snap.owned+1]=row; end
    table.sort(snap.owned,function(a,b) return (a.id or 0)<(b.id or 0); end);

    -- Always include HorizonCheck's known permanent map, even when a KI is not
    -- owned, so a capture is useful for validating exact resource IDs and
    -- ownership behavior on this HorizonXI build.
    for key in pairs(PERMANENT_KEY_ITEMS) do
        local candidates=indexed_candidates(key);
        local krow={key=key,label=key,id=nil,name=nil,bitmap=nil,api=nil,saved_proof=permanent_proof(key)~=nil};
        local bitmap_seen=false; local bitmap_owned=false;
        local api_seen=false; local api_owned=false;
        for _,r in ipairs(candidates or {}) do
            krow.id=krow.id or r.id;
            krow.name=krow.name or r.name;
            krow.label=krow.name or key;
            local bv=select(1,bitmap_has(r.id));
            if bv~=nil then bitmap_seen=true; if bv==true then bitmap_owned=true; krow.id=r.id; krow.name=r.name; krow.label=r.name or key; end end
            if player then
                local av=select(1,has_key_item(player,r.id));
                if av~=nil then api_seen=true; if av==true then api_owned=true; krow.id=r.id; krow.name=r.name; krow.label=r.name or key; end end
            end
        end
        if bitmap_seen then
            krow.bitmap=bitmap_owned;
            if bitmap_owned==true then M.confirm_permanent(krow.name or key,'0x055 key-item bitmap'); end
        end
        if api_seen then krow.api=api_owned; end
        snap.known_permanent[#snap.known_permanent+1]=krow;
    end
    table.sort(snap.known_permanent,function(a,b) return lower(a.label)<lower(b.label); end);
    return snap;
end

function M.poll()
    -- Spread the one-time 65k resource-name index over many frames. Verified
    -- critical IDs (for example Cosmo-Cleanse 734) do not wait for this index:
    -- each incoming 0x055 table is reconciled on the next frame. Once indexing
    -- finishes, run one final reconciliation for all name-discovered targets.
    if not resource_index_complete then build_resource_index_chunk(RESOURCE_INDEX_CHUNK); end
    local need_reconcile=pending_bitmap_reconcile or (resource_index_complete and not full_index_reconcile_done);
    if need_reconcile then
        pending_bitmap_reconcile=false;
        local st=HC and HC.modules and HC.modules.state or nil;
        if st and st.begin_save_batch then st.begin_save_batch(); end
        local ok1,err1=pcall(refresh_bitmap_status,false);
        local ok2,err2=pcall(reconcile_bitmap_targets);
        local ok3,err3=pcall(reconcile_verified_permanent_ids);
        if st and st.end_save_batch then st.end_save_batch(1); end
        if resource_index_complete then full_index_reconcile_done=true; end
        if ok1 and ok2 and ok3 and HC and HC.modules and HC.modules.dependencies and HC.modules.dependencies.invalidate then
            HC.modules.dependencies.invalidate('keyitems','0x055 deferred key-item reconciliation');
        end
        if (not ok1 or not ok2 or not ok3) and HC and HC.modules and HC.modules.diagnostics and HC.modules.diagnostics.record_error then
            HC.modules.diagnostics.record_error('keyitems deferred reconcile',tostring(err1 or err2 or err3));
        end
    end
end

function M.index_status()
    local total=RESOURCE_INDEX_MAX+1;
    local done=math.min(resource_index_next,total);
    return {complete=resource_index_complete,done=done,total=total,percent=math.floor((done/total)*100),started_at=resource_index_started_at,completed_at=resource_index_completed_at,pending_reconcile=pending_bitmap_reconcile};
end

function M.publish_all_evidence()
    for _,t in ipairs(TARGETS) do
        pcall(M.ownership_name,t.label);
    end
    -- Permanent quest prerequisites may not be in TARGETS; publish saved proof
    -- records too so the inspector can explain them.
    local store=permanent_store();
    if type(store)=='table' then
        for key,rec in pairs(store) do
            if rec==true or (type(rec)=='table' and rec.owned==true) then
                local label=(type(rec)=='table' and rec.name) or key;
                evidence_submit(label,true,(type(rec)=='table' and rec.source) or 'saved permanent key-item proof','VERIFIED',100,
                    'Saved permanent key-item proof.');
            end
        end
    end
    return true;
end

function M.status() return last; end
function M.bitmap_status() return last_bitmap; end
function M.bitmap_test() return refresh_bitmap_status(true); end
function M.test_status() return last_test; end
function M.scan_status() return last_scan; end

function M.draw(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    imgui.Text('Key Item API Test Lab');
    imgui.TextDisabled('0x055 bitmap ownership is authoritative for ENM / ISNM / Limbus / carried Assault I.D. Tag / Eco-War proof state. HasKeyItem tests remain diagnostic only.');
    if imgui.Button('Check Key Items##hcheck_ki_probe') then M.probe(); end
    imgui.SameLine();
    if imgui.Button('Test Cosmo-Cleanse##hcheck_ki_cosmo') then M.test_target('cosmo_cleanse',16); end
    imgui.SameLine();
    if imgui.Button('Scan 650-850##hcheck_ki_scan') then M.scan_range(650,850); end
    imgui.SameLine();
    if imgui.Button('0x055 Bitmap Test##hcheck_ki_bitmap') then M.bitmap_test(); end

    imgui.TextDisabled('0x055 is the server key-item bitmap sent on zone / KI updates. HorizonCheck accepts all key-item table types, including higher permanent-KI tables.');
    local ix=M.index_status();
    imgui.TextDisabled(string.format('Resource index: %d%% (%d/%d)%s',ix.percent or 0,ix.done or 0,ix.total or 0,ix.complete and ' READY' or ' - building incrementally'));

    if last.at then
        imgui.TextDisabled('Last probe: '..os.date('%Y-%m-%d %H:%M:%S',last.at));
        if last.error then imgui.TextDisabled('ERROR: '..last.error);
        else
            for _,row in ipairs(last.rows or {}) do
                local value=row.owned==true and 'OWNED' or (row.owned==false and 'NOT OWNED' or 'UNKNOWN');
                local id=row.id and ('resource ID '..tostring(row.id)) or 'resource ID ?';
                imgui.TextDisabled(string.format('%s - %s - %s',row.label,id,value));
            end
        end
    end
    if last_test and last_test.resolved then
        imgui.Separator();
        imgui.Text('Cosmo / Target Mapping Test');
        imgui.TextDisabled(string.format('%s resolved resource ID: %d',last_test.resolved.label,last_test.resolved.id));
        for _,row in ipairs(last_test.checks or {}) do
            imgui.TextDisabled(string.format('ID %d [%s] = %s',row.id,row.name or '?',row.owned==true and 'OWNED' or (row.owned==false and 'NOT OWNED' or 'UNKNOWN')));
        end
        imgui.TextDisabled(string.format('Owned IDs nearby (+/-%d): %d',last_test.radius or 0,#(last_test.owned_nearby or {})));
        for _,row in ipairs(last_test.owned_nearby or {}) do imgui.TextDisabled(string.format('  %d - %s',row.id,row.name or '?')); end
    end
    if last_bitmap and last_bitmap.at then
        imgui.Separator();
        imgui.Text('0x055 Key Item Bitmap');
        imgui.TextDisabled(string.format('Tables received: %d',last_bitmap.tables or 0));
        for _,row in ipairs(last_bitmap.rows or {}) do
            local b=row.bitmap==true and 'OWNED' or (row.bitmap==false and 'NOT OWNED' or 'UNKNOWN');
            local a=row.api==true and 'OWNED' or (row.api==false and 'NOT OWNED' or 'UNKNOWN');
            imgui.TextDisabled(string.format('%s - packet=%s | HasKeyItem=%s',row.label,b,a));
        end
    end
    if last_scan then
        imgui.Separator();
        imgui.Text(string.format('Owned-ID Scan %d-%d',last_scan.first,last_scan.last_id));
        imgui.TextDisabled(string.format('%d HasKeyItem=true result(s)',#(last_scan.owned or {})));
        for _,row in ipairs(last_scan.owned or {}) do imgui.TextDisabled(string.format('  %d - %s',row.id,row.name or '?')); end
    end
end

function M.command(w,raw)
    local sub=string.lower(w[2] or '');
    if sub=='keyitems' or sub=='ki' then
        local action=string.lower(w[3] or 'probe');
        if action=='probe' or action=='check' or action=='' then M.probe(); return true; end
        if action=='test' then M.test_target(w[4] or 'cosmo',tonumber(w[5]) or 16); return true; end
        if action=='scan' then M.scan_range(w[4] or 650,w[5] or 850); return true; end
        if action=='bitmap' or action=='055' then M.bitmap_test(); return true; end
    end
    return false;
end

function M.init(ctx)
    HC=ctx;
    if HC and HC.modules and HC.modules.packets and HC.modules.packets.register then
        HC.modules.packets.register(0x055,'keyitems_bitmap',on_ki_packet);
    end
    if HC and HC.modules and HC.modules.packets and HC.modules.packets.register_text then
        HC.modules.packets.register_text('keyitems_permanent',on_text);
    end
    if HC and HC.modules and HC.modules.evidence and HC.modules.evidence.register_provider then
        HC.modules.evidence.register_provider('keyitems',M.publish_all_evidence);
    end
end
return M;
