local M = {};
local HC;
local last_conquest_text_at=0;
local pending_conquest_034=nil;
local pending_conquest_034_at=0;
local durable_loaded=false;
local durable_state={chars={}};

local OUTPOSTS = {
    { key='gustaberg', name='Gustaberg', area='North Gustaberg' },
    { key='ronfaure', name='Ronfaure', area='West Ronfaure' },
    { key='sarutabaruta', name='Sarutabaruta', area='West Sarutabaruta' },
    { key='zulkheim', name='Zulkheim', area='Valkurm Dunes' },
    { key='kolshushu', name='Kolshushu', area='Buburimu Peninsula' },
    { key='aragoneu', name='Aragoneu', area='Meriphataud Mountains' },
    { key='derfland', name='Derfland', area='Pashhow Marshlands' },
    { key='norvallen', name='Norvallen', area='Jugner Forest' },
    { key='qufim', name='Qufim', area='Qufim Island' },
    { key='tavnazian', name='Tavnazian Archipelago', area='Lufaise Meadows' },
    { key='elshimo_lowlands', name='Elshimo Lowlands', area='Yuhtunga Jungle' },
    { key='fauregandi', name='Fauregandi', area='Beaucedine Glacier' },
    { key='litelor', name="Li'Telor", area="The Sanctuary of Zi'Tah" },
    { key='kuzotz', name='Kuzotz', area='Eastern Altepa Desert' },
    { key='valdeaunia', name='Valdeaunia', area='Xarcabard' },
    { key='elshimo_uplands', name='Elshimo Uplands', area='Yhoator Jungle' },
    { key='vollbow', name='Vollbow', area='Cape Teriggan' },
};

local function serialize(v,indent)
    indent=indent or '';
    local tv=type(v);
    if tv=='nil' then return 'nil'; end
    if tv=='boolean' or tv=='number' then return tostring(v); end
    if tv=='string' then return string.format('%q',v); end
    if tv~='table' then return 'nil'; end
    local keys={};
    for k in pairs(v) do keys[#keys+1]=k; end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b); end);
    local out={'{'}; local child=indent..'    ';
    for _,k in ipairs(keys) do
        local key=(type(k)=='string' and string.match(k,'^[%a_][%w_]*$'))
            and k or ('['..serialize(k,child)..']');
        out[#out+1]='\n'..child..key..' = '..serialize(v[k],child)..',';
    end
    if #keys>0 then out[#out+1]='\n'..indent; end
    out[#out+1]='}';
    return table.concat(out);
end

local function durable_path()
    if HC and HC.modules and HC.modules.userdata and HC.modules.userdata.path then
        local ok,res=pcall(HC.modules.userdata.path,'root','horizoncheck_outposts_persistent.lua');
        if ok and type(res)=='string' and res~='' then return res; end
    end
    return HC.addon_path..'horizoncheck_outposts_persistent.lua';
end

local function load_durable()
    if durable_loaded then return; end
    durable_loaded=true;
    durable_state={chars={}};
    local path=durable_path();
    local fn=loadfile(path);
    if fn then
        local ok,data=pcall(fn);
        if ok and type(data)=='table' then
            durable_state=data;
            durable_state.chars=type(durable_state.chars)=='table' and durable_state.chars or {};
        end
    end
end

local function save_durable()
    load_durable();
    local path=durable_path();
    local dir=path:match('^(.*)[\\/][^\\/]+$');
    if dir then
        pcall(function()
            os.execute('mkdir "'..dir..'" >NUL 2>NUL');
        end);
    end
    local tmp=path..'.tmp';
    local f=io.open(tmp,'w');
    if not f then return false; end
    f:write('return '..serialize(durable_state)..'\n');
    f:close();
    os.remove(path);
    local ok=os.rename(tmp,path);
    if not ok then
        local src=io.open(tmp,'rb');
        local dst=io.open(path,'wb');
        if src and dst then dst:write(src:read('*a')); end
        if src then src:close(); end
        if dst then dst:close(); end
        os.remove(tmp);
    end
    return true;
end

local function durable_char()
    load_durable();
    local name=HC.modules.core.character_name();
    durable_state.chars[name]=type(durable_state.chars[name])=='table' and durable_state.chars[name] or {};
    local d=durable_state.chars[name];
    d.verified_owned=type(d.verified_owned)=='table' and d.verified_owned or {};
    return d;
end

local NATION_NAMES={sandoria="San d'Oria",bastok='Bastok',windurst='Windurst'};
local NPC_NATION={conrad='bastok',jeanvirgaud='sandoria',rottata='windurst'};
local NATION_NPC={bastok='Conrad',sandoria='Jeanvirgaud',windurst='Rottata'};

local function current_nation_sid(c)
    if type(c)=='table' and type(c.mission_meta)=='table' then
        local sid=c.mission_meta.current_nation_sid;
        if NATION_NAMES[sid] then return sid; end
    end
    if type(c)=='table' and type(c.outposts)=='table' and NATION_NAMES[c.outposts.active_nation_sid] then
        return c.outposts.active_nation_sid;
    end
    return nil;
end

local function durable_nation(sid,create)
    local d=durable_char();
    d.nations=type(d.nations)=='table' and d.nations or {};
    if not NATION_NAMES[sid] then return nil; end
    if create then
        d.nations[sid]=type(d.nations[sid])=='table' and d.nations[sid] or {};
        d.nations[sid].verified_owned=type(d.nations[sid].verified_owned)=='table' and d.nations[sid].verified_owned or {};
    end
    return d.nations[sid];
end

local function durable_target_for(c,o,sid_override)
    local sid=sid_override or current_nation_sid(c) or (type(o)=='table' and o.active_nation_sid) or nil;
    if sid then return durable_nation(sid,true),sid; end
    return durable_char(),nil;
end

local function sync_durable_from_outposts(o,sid_override,c_override)
    local c=c_override or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or nil;
    local d,sid=durable_target_for(c,o,sid_override);
    d.verified_owned=type(d.verified_owned)=='table' and d.verified_owned or {};
    for k,v in pairs(o.verified_owned or {}) do
        if v==true then d.verified_owned[k]=true; end
    end
    d.auto_endpoint=o.auto_endpoint;
    d.permanent_complete=o.permanent_complete==true and true or nil;
    d.last_verified_at=os.time();
    d.active_nation_sid=sid;
    save_durable();
end

local function replace_durable_from_outposts(o,source,sid_override,c_override)
    local c=c_override or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or nil;
    local d,sid=durable_target_for(c,o,sid_override);

    d.verified_owned={};
    for _,it in ipairs(OUTPOSTS) do
        if o.verified_owned and o.verified_owned[it.key]==true then
            d.verified_owned[it.key]=true;
        end
    end

    d.auto_endpoint=o.auto_endpoint;
    d.permanent_complete=o.permanent_complete==true and true or nil;
    d.last_verified_at=os.time();
    d.snapshot_mode='REPLACE';
    d.snapshot_source=source or 'trusted snapshot';
    d.snapshot_count=0;
    d.active_nation_sid=sid;
    for _ in pairs(d.verified_owned) do d.snapshot_count=d.snapshot_count+1; end

    save_durable();
end


-- Verified HorizonXI Conquest NPC 0x034 endpoint evidence:
-- bytes 0x18-0x1A and 0x20-0x22 are all zero on a character with NO outposts;
-- repeated known ALL-outposts samples keep A=E0 FF 9F stable while B varies; A is authoritative for 17/17.
-- Individual region-bit mapping is intentionally not guessed yet.
local VERIFIED_NONE_A      = {0x00,0x00,0x00};
local VERIFIED_NONE_B      = {0x00,0x00,0x00};
local VERIFIED_GUSTABERG_A = {0x00,0x01,0x00};
local VERIFIED_GUSTABERG_B = {0x0A,0x00,0x00};
local VERIFIED_GUS_SAR_A   = {0x00,0x05,0x00};
local VERIFIED_GUS_SAR_B   = {0x14,0x00,0x00};
local VERIFIED_GUS_SAR_QUF_A = {0x00,0x85,0x00};
local VERIFIED_GUS_SAR_QUF_B = {0x50,0x00,0x00};
local VERIFIED_GUS_SAR_QUF_DER_A = {0x00,0x87,0x00};
local VERIFIED_GUS_SAR_QUF_DER_B = {0x78,0x00,0x00};
local VERIFIED_GUS_SAR_QUF_DER_LIT_A = {0x00,0x87,0x01};
local VERIFIED_GUS_SAR_QUF_DER_LIT_B = {0xA0,0x00,0x00};
local VERIFIED_GUS_SAR_QUF_DER_LIT_ZUL_A = {0x40,0x87,0x01};
local VERIFIED_GUS_SAR_QUF_DER_LIT_ZUL_B = {0xBE,0x00,0x00};
local VERIFIED_ALL_A       = {0xE0,0xFF,0x9F};
local VERIFIED_ALL_B       = {0xEA,0x89,0x03}; -- historical sample only; not used for ALL classification

-- HorizonXI Outpost Teleportation / Supply Run regions.
local TRUSTED_TELEPORT_NPCS = {
    ['conrad']=true,
    ['jeanvirgaud']=true,
    ['rottata']=true,
};

local REGION_ALIASES = {
    ["ronfaure"]='ronfaure',
    ["zulkheim"]='zulkheim',
    ["norvallen"]='norvallen',
    ["gustaberg"]='gustaberg',
    ["derfland"]='derfland',
    ["sarutabaruta"]='sarutabaruta',
    ["kolshushu"]='kolshushu',
    ["aragoneu"]='aragoneu',
    ["fauregandi"]='fauregandi',
    ["valdeaunia"]='valdeaunia',
    ["qufim"]='qufim',
    ["li'telor"]='litelor',
    ["kuzotz"]='kuzotz',
    ["vollbow"]='vollbow',
    ["elshimo lowlands"]='elshimo_lowlands',
    ["elshimo uplands"]='elshimo_uplands',
    ["tavnazia"]='tavnazian',
};

local function packet_ascii(data)
    if type(data)~='string' then return ''; end
    local out={};
    for i=1,#data do
        local b=string.byte(data,i) or 0;
        if b>=32 and b<=126 then out[#out+1]=string.char(b); else out[#out+1]=' '; end
    end
    return table.concat(out);
end

local function teleport_menu_regions(data)
    local txt=string.lower(packet_ascii(data));
    if not txt:find('_custom_menu',1,true) then return nil,nil,nil; end
    if not txt:find('which region would you like to teleport to?',1,true) then return nil,nil,nil; end
    local found={};
    local ordered={};
    for label,key in pairs(REGION_ALIASES) do
        if txt:find(label,1,true) then
            found[key]=true;
            ordered[#ordered+1]=key;
        end
    end
    table.sort(ordered);
    return found,ordered,txt;
end

local teleport_scan={active=false,trusted=false,npc='',seen={},pages=0};
local recent_trusted_teleport={npc='',at=0};
local function reset_teleport_scan()
    teleport_scan={active=false,trusted=false,npc='',seen={},pages=0};
end



local function current_target_name()
    local name='';
    pcall(function()
        local em=AshitaCore:GetMemoryManager():GetEntity();
        local ti=AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0);
        if em and ti and ti>0 then name=tostring(em:GetName(ti) or ''); end
    end);
    return name;
end

local function conquest_target_name(name)
    local low=string.lower(tostring(name or ''));
    if low=='' then return false; end
    -- Known nation Conquest guard title suffixes. Keep this strict so a random
    -- NPC with a coincidentally matching 0x034 payload can never alter outposts.
    if low:find(', t.k.',1,true) then return true; end   -- Temple Knight
    if low:find(', i.m.',1,true) then return true; end   -- Iron Musketeer
    if low:find(', w.w.',1,true) then return true; end   -- War Warlock
    return false;
end

local function conquest_context_active()
    if os.time()-(last_conquest_text_at or 0)<=8 then return true; end
    return conquest_target_name(current_target_name());
end

local function b0(data,offset)
    if type(data)~='string' then return nil; end
    return string.byte(data,(tonumber(offset) or 0)+1);
end

local function triplet(data,offset)
    return {b0(data,offset),b0(data,offset+1),b0(data,offset+2)};
end

local function same3(a,b)
    return a and b and a[1]==b[1] and a[2]==b[2] and a[3]==b[3];
end

local function hex3(v)
    if not v then return '?? ?? ??'; end
    return string.format('%02X %02X %02X',v[1] or 0,v[2] or 0,v[3] or 0);
end

local function ensure(c)
    c.outposts=type(c.outposts)=='table' and c.outposts or {};
    local o=c.outposts;
    o.owned=type(o.owned)=='table' and o.owned or {};
    o.verified_owned=type(o.verified_owned)=='table' and o.verified_owned or {};

    -- Load durable verified ownership stored outside the versioned addon folder.
    -- New trusted Regional Teleport snapshots use replacement semantics so an
    -- older incorrect 17/17 record cannot be re-added after a correct 6/17 scan.
    local sid=current_nation_sid(c);
    if sid and not o.active_nation_sid then o.active_nation_sid=sid; end
    local root=durable_char();
    local d=(sid and durable_nation(sid,false)) or nil;
    -- Backward compatibility: before per-nation snapshots existed, the durable
    -- file contained one character-wide snapshot. Use that only until an
    -- allegiance change explicitly invalidates it.
    if not d and o.needs_nation_refresh~=true and o.suppress_legacy_durable~=true then d=root; end
    if o.needs_nation_refresh~=true and d then
        if d.snapshot_mode=='REPLACE' then
            o.verified_owned={};
            o.owned={};
            for k,v in pairs(d.verified_owned or {}) do
                if v==true then
                    o.verified_owned[k]=true;
                    o.owned[k]=true;
                end
            end
            o.auto_endpoint=d.auto_endpoint;
            o.permanent_complete=d.permanent_complete==true and true or nil;
        else
            for k,v in pairs(d.verified_owned or {}) do
                if v==true then
                    o.verified_owned[k]=true;
                    o.owned[k]=true;
                end
            end
            if not o.auto_endpoint and d.auto_endpoint then o.auto_endpoint=d.auto_endpoint; end
            if d.permanent_complete==true then o.permanent_complete=true; end
        end
    end

    -- Durable verified evidence is authoritative across reloads.
    -- Rebuild the visible checkbox table from it every time.
    if o.verified_owned.gustaberg==true then
        o.owned.gustaberg=true;
    end

    -- Backward repair from older diagnostic evidence.
    if o.auto_endpoint=='GUSTABERG ONLY'
        or o.last_packet_kind=='GUSTABERG_ONLY'
        or o.last_classifier_kind=='GUSTABERG_ONLY'
        or o.last_raw_classifier=='GUSTABERG_ONLY'
        or (o.last_raw_a=='00 01 00' and o.last_raw_b=='0A 00 00')
        or (o.last_packet_a=='00 01 00' and o.last_packet_b=='0A 00 00')
    then
        o.verified_owned.gustaberg=true;
        o.owned.gustaberg=true;
    end

    -- v6.0.78: known ground truth from Ciladan with exactly Gustaberg +
    -- Sarutabaruta unlocked.
    if o.auto_endpoint=='GUSTABERG + SARUTABARUTA'
        or o.last_packet_kind=='GUSTABERG_SARUTABARUTA'
        or o.last_classifier_kind=='GUSTABERG_SARUTABARUTA'
        or o.last_raw_classifier=='GUSTABERG_SARUTABARUTA'
        or (o.last_raw_a=='00 05 00' and o.last_raw_b=='14 00 00')
        or (o.last_packet_a=='00 05 00' and o.last_packet_b=='14 00 00')
    then
        o.verified_owned.gustaberg=true;
        o.verified_owned.sarutabaruta=true;
        o.owned.gustaberg=true;
        o.owned.sarutabaruta=true;
    end

    -- v6.0.81: known ground truth with exactly Gustaberg + Sarutabaruta + Qufim.
    if o.auto_endpoint=='GUSTABERG + SARUTABARUTA + QUFIM'
        or o.last_packet_kind=='GUSTABERG_SARUTABARUTA_QUFIM'
        or o.last_classifier_kind=='GUSTABERG_SARUTABARUTA_QUFIM'
        or o.last_raw_classifier=='GUSTABERG_SARUTABARUTA_QUFIM'
        or (o.last_raw_a=='00 85 00' and o.last_raw_b=='50 00 00')
        or (o.last_packet_a=='00 85 00' and o.last_packet_b=='50 00 00')
    then
        o.verified_owned.gustaberg=true;
        o.verified_owned.sarutabaruta=true;
        o.verified_owned.qufim=true;
        o.owned.gustaberg=true;
        o.owned.sarutabaruta=true;
        o.owned.qufim=true;
    end

    if o.auto_endpoint=='GUSTABERG + SARUTABARUTA + QUFIM + DERFLAND'
        or o.last_packet_kind=='GUSTABERG_SARUTABARUTA_QUFIM_DERFLAND'
        or o.last_classifier_kind=='GUSTABERG_SARUTABARUTA_QUFIM_DERFLAND'
        or o.last_raw_classifier=='GUSTABERG_SARUTABARUTA_QUFIM_DERFLAND'
        or (o.last_raw_a=='00 87 00' and o.last_raw_b=='78 00 00')
        or (o.last_packet_a=='00 87 00' and o.last_packet_b=='78 00 00')
    then
        o.verified_owned.gustaberg=true;
        o.verified_owned.sarutabaruta=true;
        o.verified_owned.qufim=true;
        o.verified_owned.derfland=true;
        o.owned.gustaberg=true;
        o.owned.sarutabaruta=true;
        o.owned.qufim=true;
        o.owned.derfland=true;
    end

    if o.auto_endpoint=="GUSTABERG + SARUTABARUTA + QUFIM + DERFLAND + LI'TELOR"
        or o.last_packet_kind=='GUSTABERG_SARUTABARUTA_QUFIM_DERFLAND_LITELOR'
        or o.last_classifier_kind=='GUSTABERG_SARUTABARUTA_QUFIM_DERFLAND_LITELOR'
        or o.last_raw_classifier=='GUSTABERG_SARUTABARUTA_QUFIM_DERFLAND_LITELOR'
        or (o.last_raw_a=='00 87 01' and o.last_raw_b=='A0 00 00')
        or (o.last_packet_a=='00 87 01' and o.last_packet_b=='A0 00 00')
    then
        o.verified_owned.gustaberg=true;
        o.verified_owned.sarutabaruta=true;
        o.verified_owned.qufim=true;
        o.verified_owned.derfland=true;
        o.verified_owned.litelor=true;
        o.owned.gustaberg=true;
        o.owned.sarutabaruta=true;
        o.owned.qufim=true;
        o.owned.derfland=true;
        o.owned.litelor=true;
    end

    if o.auto_endpoint=="GUSTABERG + SARUTABARUTA + QUFIM + DERFLAND + LI'TELOR + ZULKHEIM"
        or o.last_packet_kind=='GUSTABERG_SARUTABARUTA_QUFIM_DERFLAND_LITELOR_ZULKHEIM'
        or o.last_classifier_kind=='GUSTABERG_SARUTABARUTA_QUFIM_DERFLAND_LITELOR_ZULKHEIM'
        or o.last_raw_classifier=='GUSTABERG_SARUTABARUTA_QUFIM_DERFLAND_LITELOR_ZULKHEIM'
        or (o.last_raw_a=='40 87 01' and o.last_raw_b=='BE 00 00')
        or (o.last_packet_a=='40 87 01' and o.last_packet_b=='BE 00 00')
    then
        o.verified_owned.gustaberg=true;
        o.verified_owned.sarutabaruta=true;
        o.verified_owned.qufim=true;
        o.verified_owned.derfland=true;
        o.verified_owned.litelor=true;
        o.verified_owned.zulkheim=true;
        o.owned.gustaberg=true;
        o.owned.sarutabaruta=true;
        o.owned.qufim=true;
        o.owned.derfland=true;
        o.owned.litelor=true;
        o.owned.zulkheim=true;
    end

    return o;
end

local function counts(c)
    local o=ensure(c);
    local owned=0;
    local missing={};
    for _,it in ipairs(OUTPOSTS) do
        if o.owned[it.key]==true then
            owned=owned+1;
        else
            missing[#missing+1]=it;
        end
    end
    return owned,#OUTPOSTS,missing;
end

local sync_parent;

local function set_all(c,value)
    local o=ensure(c);
    for _,it in ipairs(OUTPOSTS) do
        o.owned[it.key]=value and true or nil;
    end
end

local function classify_endpoint(data)
    if type(data)~='string' or #data<35 then return nil,nil,nil; end
    local a=triplet(data,0x18);
    local b=triplet(data,0x20);

    if same3(a,VERIFIED_NONE_A) and same3(b,VERIFIED_NONE_B) then
        return 'NONE',a,b;
    end
    if same3(a,VERIFIED_GUSTABERG_A) and same3(b,VERIFIED_GUSTABERG_B) then
        return 'GUSTABERG_ONLY',a,b;
    end
    if same3(a,VERIFIED_GUS_SAR_A) and same3(b,VERIFIED_GUS_SAR_B) then
        return 'GUSTABERG_SARUTABARUTA',a,b;
    end
    if same3(a,VERIFIED_GUS_SAR_QUF_A) and same3(b,VERIFIED_GUS_SAR_QUF_B) then
        return 'GUSTABERG_SARUTABARUTA_QUFIM',a,b;
    end
    if same3(a,VERIFIED_GUS_SAR_QUF_DER_A) and same3(b,VERIFIED_GUS_SAR_QUF_DER_B) then
        return 'GUSTABERG_SARUTABARUTA_QUFIM_DERFLAND',a,b;
    end
    if same3(a,VERIFIED_GUS_SAR_QUF_DER_LIT_A) and same3(b,VERIFIED_GUS_SAR_QUF_DER_LIT_B) then
        return 'GUSTABERG_SARUTABARUTA_QUFIM_DERFLAND_LITELOR',a,b;
    end
    if same3(a,VERIFIED_GUS_SAR_QUF_DER_LIT_ZUL_A) and same3(b,VERIFIED_GUS_SAR_QUF_DER_LIT_ZUL_B) then
        return 'GUSTABERG_SARUTABARUTA_QUFIM_DERFLAND_LITELOR_ZULKHEIM',a,b;
    end

    -- v6.0.71: repeated known-17/17 captures prove A=E0 FF 9F is stable,
    -- while the previously-used B field changes between interactions.
    -- Therefore ALL is keyed only from the repeatedly verified A field.
    if same3(a,VERIFIED_ALL_A) then
        return 'ALL',a,b;
    end

    return 'PARTIAL_OR_UNKNOWN',a,b;
end

local function apply_endpoint(c,kind,a,b,source)
    local o=ensure(c);
    o.last_packet_at=os.time();
    o.last_packet_kind=kind;
    o.last_packet_a=hex3(a);
    o.last_packet_b=hex3(b);
    o.last_packet_source=source or 'Conquest NPC 0x034';

    if kind=='ALL' then
        set_all(c,true);
        o.verified_owned=type(o.verified_owned)=='table' and o.verified_owned or {};
        for _,it in ipairs(OUTPOSTS) do o.verified_owned[it.key]=true; end
        o.auto_endpoint='ALL';
        o.permanent_complete=true;
        o.auto_confidence='CAPTURE VERIFIED ALL (A FIELD)';
        sync_parent(c);
        HC.modules.state.save();
        sync_durable_from_outposts(o);
        HC.msg('AUTO: Conquest NPC confirms ALL outposts obtained (17/17).');
        return true;
    elseif kind=='NONE' then
        set_all(c,false);
        o.verified_owned={};
        o.auto_endpoint='NONE';
        o.auto_confidence='CAPTURE VERIFIED ENDPOINT';
        sync_parent(c);
        HC.modules.state.save();
        sync_durable_from_outposts(o);
        HC.msg('AUTO: Conquest NPC confirms no outposts obtained (0/17).');
        return true;
    elseif kind=='GUSTABERG_ONLY' then
        set_all(c,false);
        o.verified_owned=type(o.verified_owned)=='table' and o.verified_owned or {};
        o.verified_owned.gustaberg=true;
        o.owned.gustaberg=true;
        o.auto_endpoint='GUSTABERG ONLY';
        o.auto_confidence='CAPTURE VERIFIED PARTIAL';
        o.last_applied_owned_count=1;
        o.last_applied_at=os.time();
        sync_parent(c);
        HC.modules.state.save();
        sync_durable_from_outposts(o);
        HC.msg('AUTO: Conquest NPC confirms Gustaberg obtained (1/17).');
        return true;
    elseif kind=='GUSTABERG_SARUTABARUTA' then
        set_all(c,false);
        o.verified_owned=type(o.verified_owned)=='table' and o.verified_owned or {};
        o.verified_owned.gustaberg=true;
        o.verified_owned.sarutabaruta=true;
        o.owned.gustaberg=true;
        o.owned.sarutabaruta=true;
        o.auto_endpoint='GUSTABERG + SARUTABARUTA';
        o.auto_confidence='CAPTURE VERIFIED PARTIAL';
        o.last_applied_owned_count=2;
        o.last_applied_at=os.time();
        sync_parent(c);
        HC.modules.state.save();
        sync_durable_from_outposts(o);
        HC.msg('AUTO: Conquest NPC confirms Gustaberg + Sarutabaruta obtained (2/17).');
        return true;
    elseif kind=='GUSTABERG_SARUTABARUTA_QUFIM' then
        set_all(c,false);
        o.verified_owned=type(o.verified_owned)=='table' and o.verified_owned or {};
        o.verified_owned.gustaberg=true;
        o.verified_owned.sarutabaruta=true;
        o.verified_owned.qufim=true;
        o.owned.gustaberg=true;
        o.owned.sarutabaruta=true;
        o.owned.qufim=true;
        o.auto_endpoint='GUSTABERG + SARUTABARUTA + QUFIM';
        o.auto_confidence='CAPTURE VERIFIED PARTIAL';
        o.last_applied_owned_count=3;
        o.last_applied_at=os.time();
        sync_parent(c);
        HC.modules.state.save();
        sync_durable_from_outposts(o);
        HC.msg('AUTO: Conquest NPC confirms Gustaberg + Sarutabaruta + Qufim obtained (3/17).');
        return true;
    elseif kind=='GUSTABERG_SARUTABARUTA_QUFIM_DERFLAND' then
        set_all(c,false);
        o.verified_owned=type(o.verified_owned)=='table' and o.verified_owned or {};
        o.verified_owned.gustaberg=true;
        o.verified_owned.sarutabaruta=true;
        o.verified_owned.qufim=true;
        o.verified_owned.derfland=true;
        o.owned.gustaberg=true;
        o.owned.sarutabaruta=true;
        o.owned.qufim=true;
        o.owned.derfland=true;
        o.auto_endpoint='GUSTABERG + SARUTABARUTA + QUFIM + DERFLAND';
        o.auto_confidence='CAPTURE VERIFIED PARTIAL';
        o.last_applied_owned_count=4;
        o.last_applied_at=os.time();
        sync_parent(c);
        HC.modules.state.save();
        sync_durable_from_outposts(o);
        HC.msg('AUTO: Conquest NPC confirms Gustaberg + Sarutabaruta + Qufim + Derfland obtained (4/17).');
        return true;
    elseif kind=='GUSTABERG_SARUTABARUTA_QUFIM_DERFLAND_LITELOR' then
        set_all(c,false);
        o.verified_owned=type(o.verified_owned)=='table' and o.verified_owned or {};
        o.verified_owned.gustaberg=true;
        o.verified_owned.sarutabaruta=true;
        o.verified_owned.qufim=true;
        o.verified_owned.derfland=true;
        o.verified_owned.litelor=true;
        o.owned.gustaberg=true;
        o.owned.sarutabaruta=true;
        o.owned.qufim=true;
        o.owned.derfland=true;
        o.owned.litelor=true;
        o.auto_endpoint="GUSTABERG + SARUTABARUTA + QUFIM + DERFLAND + LI'TELOR";
        o.auto_confidence='CAPTURE VERIFIED PARTIAL';
        o.last_applied_owned_count=5;
        o.last_applied_at=os.time();
        sync_parent(c);
        HC.modules.state.save();
        sync_durable_from_outposts(o);
        HC.msg("AUTO: Conquest NPC confirms Gustaberg + Sarutabaruta + Qufim + Derfland + Li'Telor obtained (5/17).");
        return true;
    elseif kind=='GUSTABERG_SARUTABARUTA_QUFIM_DERFLAND_LITELOR_ZULKHEIM' then
        set_all(c,false);
        o.verified_owned=type(o.verified_owned)=='table' and o.verified_owned or {};
        o.verified_owned.gustaberg=true;
        o.verified_owned.sarutabaruta=true;
        o.verified_owned.qufim=true;
        o.verified_owned.derfland=true;
        o.verified_owned.litelor=true;
        o.verified_owned.zulkheim=true;
        o.owned.gustaberg=true;
        o.owned.sarutabaruta=true;
        o.owned.qufim=true;
        o.owned.derfland=true;
        o.owned.litelor=true;
        o.owned.zulkheim=true;
        o.auto_endpoint="GUSTABERG + SARUTABARUTA + QUFIM + DERFLAND + LI'TELOR + ZULKHEIM";
        o.auto_confidence='CAPTURE VERIFIED PARTIAL';
        o.last_applied_owned_count=6;
        o.last_applied_at=os.time();
        sync_parent(c);
        HC.modules.state.save();
        sync_durable_from_outposts(o);
        HC.msg("AUTO: Conquest NPC confirms Gustaberg + Sarutabaruta + Qufim + Derfland + Li'Telor + Zulkheim obtained (6/17).");
        return true;
    end

    -- Intermediate bit patterns are recorded for learning but never used to
    -- guess individual ownership until a known partial character is captured.
    o.auto_endpoint='PARTIAL/UNKNOWN';
    o.auto_confidence='LEARNING - INDIVIDUAL BITS UNMAPPED';
    HC.modules.state.save();
    return false;
end

sync_parent = function(c)
    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    local o=ensure(c);
    local owned,total=counts(c);
    local complete=(owned==total);

    -- Outpost unlocks are permanent character progression. Once all 17 are
    -- verified, keep a durable permanent-complete marker that is independent
    -- of the weekly/conquest reset table.
    if complete then
        o.permanent_complete=true;
    elseif o.auto_endpoint=='NONE' then
        o.permanent_complete=nil;
    end

    local effective_complete=(o.permanent_complete==true) or complete;
    local changed=(c.weekly.conquest==true)~=effective_complete;
    c.weekly.conquest=effective_complete and true or nil;
    return effective_complete,changed;
end


local function apply_teleport_scan(c)
    local o=ensure(c);
    local n=0;
    for _ in pairs(teleport_scan.seen or {}) do n=n+1; end
    if n<=0 then return false; end

    o.last_teleport_scan_at=os.time();
    o.last_teleport_scan_npc=teleport_scan.npc;
    o.last_teleport_scan_count=n;
    o.last_teleport_scan_pages=tonumber(teleport_scan.pages) or 0;
    o.last_teleport_scan_regions={};
    for k,v in pairs(teleport_scan.seen or {}) do if v then o.last_teleport_scan_regions[k]=true; end end

    if teleport_scan.trusted then
        o.owned={};
        o.verified_owned={};
        for k,v in pairs(teleport_scan.seen or {}) do
            if v then
                o.owned[k]=true;
                o.verified_owned[k]=true;
            end
        end

        o.auto_endpoint='TELEPORT MENU';
        o.auto_confidence='VERIFIED BY TELEPORT MENU';
        o.needs_nation_refresh=nil;
        o.suppress_legacy_durable=true;
        local scan_sid=NPC_NATION[string.lower(tostring(teleport_scan.npc or ''))] or current_nation_sid(c);
        if scan_sid then o.active_nation_sid=scan_sid; end
        o.last_applied_owned_count=n;
        o.last_applied_at=os.time();
        if n==#OUTPOSTS then o.permanent_complete=true; else o.permanent_complete=nil; end

        -- Commit the authoritative menu snapshot first. sync_parent() calls
        -- ensure(), so writing durable state before reconciliation prevents an
        -- old additive 17/17 durable record from being merged back immediately.
        replace_durable_from_outposts(o,
            'Regional Teleport menu - '..tostring(teleport_scan.npc or '?'),o.active_nation_sid,c);

        sync_parent(c);
        HC.modules.state.save();

        HC.msg(string.format('AUTO: Regional Teleport menu verified %d/%d outposts from %s.',
            n,#OUTPOSTS,tostring(teleport_scan.npc or '?')));
        if HC.modules.releasehealth and HC.modules.releasehealth.invalidate then
            pcall(HC.modules.releasehealth.invalidate);
        end
        return true;
    end

    o.custom_teleport_candidate=true;
    o.custom_teleport_candidate_npc=teleport_scan.npc;
    o.custom_teleport_candidate_count=n;
    HC.modules.state.save();
    HC.msg(string.format(
        'Outpost diagnostic: custom teleport NPC %s exposed %d regions; ownership was NOT changed.',
        tostring(teleport_scan.npc or '?'),n));
    return false;
end

function M.init(ctx)
    HC=ctx;

    HC.modules.packets.register_text('Trusted Regional Teleport NPC context',function(s)
        local low=string.lower(tostring(s or ''));
        local npc=nil;
        if low:find('conrad',1,true) and low:find('welcome to the regional teleporation service',1,true) then
            npc='Conrad';
        elseif low:find('jeanvirgaud',1,true) and low:find('welcome to the regional teleporation service',1,true) then
            npc='Jeanvirgaud';
        elseif low:find('rottata',1,true) and low:find('welcome to the regional teleporation service',1,true) then
            npc='Rottata';
        end
        if npc then
            recent_trusted_teleport.npc=npc;
            recent_trusted_teleport.at=os.time();
        end
    end);

    HC.modules.packets.register(0x017,'Outpost Teleport Menu',function(e)
        if not e or e.injected or type(e.data)~='string' then return; end
        local regions,ordered,txt=teleport_menu_regions(e.data);
        if not regions then return; end

        local npc=current_target_name();
        local low=string.lower(tostring(npc or ''));
        local trusted=TRUSTED_TELEPORT_NPCS[low]==true;

        -- If a trusted teleport scan is already in progress, keep that identity
        -- for the full menu session. HorizonXI can clear/change the live target
        -- while paging, and a 17/17 menu can take >10 seconds to reach Go Back.
        if teleport_scan.active and teleport_scan.trusted==true
            and TRUSTED_TELEPORT_NPCS[string.lower(tostring(teleport_scan.npc or ''))]==true
        then
            npc=teleport_scan.npc;
            low=string.lower(tostring(npc or ''));
            trusted=true;
        elseif not trusted and recent_trusted_teleport.at>0
            and os.time()-recent_trusted_teleport.at<=20
        then
            local recent_low=string.lower(tostring(recent_trusted_teleport.npc or ''));
            if TRUSTED_TELEPORT_NPCS[recent_low]==true then
                npc=recent_trusted_teleport.npc;
                low=recent_low;
                trusted=true;
            end
        end

        if not teleport_scan.active or teleport_scan.npc~=npc then
            reset_teleport_scan();
            teleport_scan.active=true;
            teleport_scan.trusted=trusted;
            teleport_scan.npc=npc;
        end

        for k,v in pairs(regions) do if v then teleport_scan.seen[k]=true; end end
        teleport_scan.pages=(tonumber(teleport_scan.pages) or 0)+1;

        local c=HC.modules.state.get_char();
        local o=ensure(c);
        o.last_teleport_packet_at=os.time();
        o.last_teleport_packet_npc=npc;
        o.last_teleport_packet_trusted=trusted;
        o.last_teleport_trust_source=trusted and 'TRUSTED NPC CONTEXT' or 'UNTRUSTED';
        o.last_teleport_page_regions=ordered;
        HC.modules.state.save();

        -- Captured menus use "Go Back" on the final page.
        if txt:find('go back',1,true) then
            apply_teleport_scan(c);
            reset_teleport_scan();
        end
    end);

    local c0=HC.modules.state.get_char();
    local o0=ensure(c0);
    if o0.restore_all_from_endpoint==true or o0.auto_endpoint=='ALL' or o0.permanent_complete==true then
        set_all(c0,true);
        o0.permanent_complete=true;
        o0.restore_all_from_endpoint=nil;
        sync_parent(c0);
        HC.modules.state.save();
        sync_durable_from_outposts(o0);
    elseif o0.restore_none_from_endpoint==true or o0.auto_endpoint=='NONE' then
        set_all(c0,false);
        o0.restore_none_from_endpoint=nil;
        sync_parent(c0);
        HC.modules.state.save();
    elseif o0.auto_endpoint=="GUSTABERG + SARUTABARUTA + QUFIM + DERFLAND + LI'TELOR + ZULKHEIM"
        or (o0.verified_owned.gustaberg==true and o0.verified_owned.sarutabaruta==true and o0.verified_owned.qufim==true and o0.verified_owned.derfland==true and o0.verified_owned.litelor==true and o0.verified_owned.zulkheim==true)
    then
        o0.verified_owned.gustaberg=true;
        o0.verified_owned.sarutabaruta=true;
        o0.verified_owned.qufim=true;
        o0.verified_owned.derfland=true;
        o0.verified_owned.litelor=true;
        o0.verified_owned.zulkheim=true;
        o0.owned.gustaberg=true;
        o0.owned.sarutabaruta=true;
        o0.owned.qufim=true;
        o0.owned.derfland=true;
        o0.owned.litelor=true;
        o0.owned.zulkheim=true;
        sync_parent(c0);
        HC.modules.state.save();
        sync_durable_from_outposts(o0);
    elseif o0.auto_endpoint=="GUSTABERG + SARUTABARUTA + QUFIM + DERFLAND + LI'TELOR"
        or (o0.verified_owned.gustaberg==true and o0.verified_owned.sarutabaruta==true and o0.verified_owned.qufim==true and o0.verified_owned.derfland==true and o0.verified_owned.litelor==true)
    then
        o0.verified_owned.gustaberg=true;
        o0.verified_owned.sarutabaruta=true;
        o0.verified_owned.qufim=true;
        o0.verified_owned.derfland=true;
        o0.verified_owned.litelor=true;
        o0.owned.gustaberg=true;
        o0.owned.sarutabaruta=true;
        o0.owned.qufim=true;
        o0.owned.derfland=true;
        o0.owned.litelor=true;
        sync_parent(c0);
        HC.modules.state.save();
        sync_durable_from_outposts(o0);
    elseif o0.auto_endpoint=='GUSTABERG + SARUTABARUTA + QUFIM + DERFLAND'
        or (o0.verified_owned.gustaberg==true and o0.verified_owned.sarutabaruta==true and o0.verified_owned.qufim==true and o0.verified_owned.derfland==true)
    then
        o0.verified_owned.gustaberg=true;
        o0.verified_owned.sarutabaruta=true;
        o0.verified_owned.qufim=true;
        o0.verified_owned.derfland=true;
        o0.owned.gustaberg=true;
        o0.owned.sarutabaruta=true;
        o0.owned.qufim=true;
        o0.owned.derfland=true;
        sync_parent(c0);
        HC.modules.state.save();
        sync_durable_from_outposts(o0);
    elseif o0.auto_endpoint=='GUSTABERG + SARUTABARUTA + QUFIM'
        or (o0.verified_owned.gustaberg==true and o0.verified_owned.sarutabaruta==true and o0.verified_owned.qufim==true)
    then
        o0.verified_owned.gustaberg=true;
        o0.verified_owned.sarutabaruta=true;
        o0.verified_owned.qufim=true;
        o0.owned.gustaberg=true;
        o0.owned.sarutabaruta=true;
        o0.owned.qufim=true;
        sync_parent(c0);
        HC.modules.state.save();
        sync_durable_from_outposts(o0);
    elseif o0.auto_endpoint=='GUSTABERG + SARUTABARUTA'
        or (o0.verified_owned.gustaberg==true and o0.verified_owned.sarutabaruta==true)
    then
        o0.verified_owned.gustaberg=true;
        o0.verified_owned.sarutabaruta=true;
        o0.owned.gustaberg=true;
        o0.owned.sarutabaruta=true;
        sync_parent(c0);
        HC.modules.state.save();
        sync_durable_from_outposts(o0);
    elseif o0.auto_endpoint=='GUSTABERG ONLY' or o0.verified_owned.gustaberg==true then
        o0.verified_owned.gustaberg=true;
        o0.owned.gustaberg=true;
        sync_parent(c0);
        HC.modules.state.save();
    end

    local function consume_conquest_packet(data,source)
        -- Ashita's e.size can correctly report 52 bytes while e.data itself
        -- is backed by a larger/padded buffer. Do not require #data == 52.
        -- We only need enough bytes to read through ownership field B.
        if type(data)~='string' or #data<35 then return false; end
        local kind,a,b=classify_endpoint(data);
        if not kind then return false; end
        local c=HC.modules.state.get_char();
        local o=ensure(c);
        o.last_classifier_kind=kind;
        o.last_classifier_at=os.time();
        local ok,err=pcall(apply_endpoint,c,kind,a,b,source or 'Conquest NPC 0x034');
        if not ok then
            o.last_sync_error=tostring(err);
            HC.modules.state.save();
            if HC.modules.diagnostics then
                HC.modules.diagnostics.record_error('outpost auto-sync',err);
            end
            return false;
        end
        o.last_sync_error=nil;
        HC.modules.state.save();
        return true;
    end

    HC.modules.packets.register_text('Conquest Outpost NPC context',function(s)
        local low=string.lower(tostring(s or ''));
        if (low:find('conquest campaign',1,true) and
            (low:find('temple knight',1,true) or low:find('iron musketeer',1,true) or low:find('war warlock',1,true)))
            or low:find('bring supplies to the outpost border guards',1,true)
            or low:find('choose which outpost you want to go to',1,true)
        then
            local now=os.time();
            last_conquest_text_at=now;

            -- HorizonXI normally sends 0x034 before the associated NPC text.
            -- Consume the cached packet once the dialogue proves this really
            -- was the Conquest/Supply Mission NPC.
            if pending_conquest_034 and now-(pending_conquest_034_at or 0)<=8 then
                consume_conquest_packet(pending_conquest_034,'Conquest NPC 0x034 + dialogue');
                pending_conquest_034=nil;
                pending_conquest_034_at=0;
            end
        end
    end);

    local function observe_packet(e)
        if e==nil or e.injected or tonumber(e.id)~=0x034 then return; end
        local data=e.data or e.data_raw;
        local size=tonumber(e.size) or (type(data)=='string' and #data or 0);

        local c=HC.modules.state.get_char();
        local o=ensure(c);
        o.tap_034_seen_at=os.time();
        o.tap_034_size=size;
        o.tap_034_data_type=type(data);
        HC.modules.state.save();

        if type(data)~='string' then
            o.last_sync_error='0x034 seen on packet tap but packet bytes were not a string.';
            HC.modules.state.save();
            return;
        end

        o.last_034_seen_at=os.time();
        o.last_034_size=size;
        HC.modules.state.save();

        if size~=52 and #data~=52 then return; end

        local kind,a,b=classify_endpoint(data);
        o.last_raw_classifier=kind;
        o.last_raw_a=hex3(a);
        o.last_raw_b=hex3(b);
        HC.modules.state.save();

        if kind=='NONE' or kind=='GUSTABERG_ONLY' or kind=='GUSTABERG_SARUTABARUTA' or kind=='GUSTABERG_SARUTABARUTA_QUFIM' or kind=='GUSTABERG_SARUTABARUTA_QUFIM_DERFLAND' or kind=='GUSTABERG_SARUTABARUTA_QUFIM_DERFLAND_LITELOR' or kind=='GUSTABERG_SARUTABARUTA_QUFIM_DERFLAND_LITELOR_ZULKHEIM' or kind=='ALL' then
            if conquest_context_active() then
                consume_conquest_packet(data,'Verified Conquest 0x034 via packet tap');
            else
                o.last_rejected_kind=kind;
                o.last_rejected_at=os.time();
                o.last_rejected_target=current_target_name();
                o.last_rejected_reason='verified-looking 0x034 outside Conquest NPC context';
                HC.modules.state.save();
            end
            return;
        end

        if conquest_context_active() then
            pending_conquest_034=data;
            pending_conquest_034_at=os.time();

            if os.time()-(last_conquest_text_at or 0)<=8 then
                consume_conquest_packet(data,'Conquest NPC partial/unknown 0x034 via packet tap');
            end
        end
    end

    -- Use the exact same packet-tap dispatcher as Detector Capture.
    -- This path is proven by the user's successful outpost capture reports.
    HC.modules.packets.register_tap('outposts',observe_packet);
end

function M.on_nation_changed(c,old_sid,new_sid)
    if type(c)~='table' or not NATION_NAMES[new_sid] then return false; end
    c.outposts=type(c.outposts)=='table' and c.outposts or {};
    local o=c.outposts;
    o.owned=type(o.owned)=='table' and o.owned or {};
    o.verified_owned=type(o.verified_owned)=='table' and o.verified_owned or {};

    -- If the old nation was not known from mission state, the last trusted
    -- conquest NPC tells us which nation's snapshot is currently on screen.
    if not NATION_NAMES[old_sid] and o.last_teleport_scan_npc then
        old_sid=NPC_NATION[string.lower(tostring(o.last_teleport_scan_npc))];
    end
    if NATION_NAMES[old_sid] and old_sid~=new_sid then
        replace_durable_from_outposts(o,'Preserved before allegiance change',old_sid,c);
    end

    -- A nation's outpost ownership must be re-read after allegiance changes.
    -- Clear only the active display/verification state; nation snapshots remain
    -- durable and can be revalidated if the character later switches back.
    o.owned={};
    o.verified_owned={};
    o.auto_endpoint=nil;
    o.auto_confidence=nil;
    o.permanent_complete=nil;
    o.last_teleport_scan_npc=nil;
    o.last_teleport_scan_count=nil;
    o.last_teleport_scan_pages=nil;
    o.last_teleport_scan_regions=nil;
    o.last_applied_owned_count=nil;
    o.last_applied_at=nil;
    o.active_nation_sid=new_sid;
    o.needs_nation_refresh=true;
    o.needs_nation_refresh_since=os.time();
    o.needs_nation_refresh_reason='ALLEGIANCE CHANGED';
    o.suppress_legacy_durable=true;

    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    c.weekly.conquest=nil;
    HC.modules.state.save();
    HC.msg('AUTO: Allegiance changed to '..NATION_NAMES[new_sid]..'; Conquest / Outposts reset to UNVERIFIED until the new nation Regional Teleport menu is checked.');
    return true;
end

function M.reconcile(c)
    local complete,changed=sync_parent(c);
    if changed then HC.modules.state.save(); end
    return complete,changed;
end

function M.permanent_complete(c)
    local o=ensure(c);
    if o.needs_nation_refresh==true then return false; end
    if o.permanent_complete==true then return true; end
    local owned,total=counts(c);
    if owned==total then
        o.permanent_complete=true;
        HC.modules.state.save();
        sync_durable_from_outposts(o);
        return true;
    end
    return false;
end

local function verified_owned_count(c)
    c.outposts=type(c.outposts)=='table' and c.outposts or {};
    local o=c.outposts;
    o.verified_owned=type(o.verified_owned)=='table' and o.verified_owned or {};
    local n=0;
    for _,it in ipairs(OUTPOSTS) do
        if o.verified_owned[it.key]==true then n=n+1; end
    end
    return n;
end

local function all_verified_owned(c)
    return verified_owned_count(c)>=#OUTPOSTS;
end

function M.verified_count(c)
    return verified_owned_count(c),#OUTPOSTS;
end

function M.sync_status(c)
    local o=ensure(c);
    local sid=o.active_nation_sid or current_nation_sid(c);
    local trusted=(o.needs_nation_refresh~=true)
        and o.auto_endpoint=='TELEPORT MENU'
        and o.auto_confidence=='VERIFIED BY TELEPORT MENU'
        and (tonumber(o.last_teleport_scan_at)~=nil or tonumber(o.last_applied_at)~=nil);
    return {
        synced=trusted==true,
        at=tonumber(o.last_teleport_scan_at) or tonumber(o.last_applied_at),
        npc=o.last_teleport_scan_npc,
        expected_npc=NATION_NPC[sid],
        count=verified_owned_count(c),
        total=#OUTPOSTS,
        nation=sid and NATION_NAMES[sid] or nil,
        needs_nation_refresh=o.needs_nation_refresh==true,
    };
end

function M.status(c)
    local o=ensure(c);
    if o.needs_nation_refresh==true then
        local sid=o.active_nation_sid or current_nation_sid(c);
        return 'NEEDS UPDATE FOR '..string.upper(NATION_NAMES[sid] or 'NEW NATION');
    end
    local n=verified_owned_count(c);
    if n>=#OUTPOSTS then return 'All outposts obtained'; end
    return string.format('%d/%d outposts verified',n,#OUTPOSTS);
end


function M.short_status(c)
    local o=ensure(c);
    if o.needs_nation_refresh==true then
        local sid=o.active_nation_sid or current_nation_sid(c);
        return 'NEEDS UPDATE FOR '..string.upper(NATION_NAMES[sid] or 'NEW NATION');
    end
    local n=verified_owned_count(c);
    if n>=#OUTPOSTS then return 'All outposts obtained'; end
    return string.format('%d/%d outposts verified',n,#OUTPOSTS);
end


function M.draw(c)
    if not HC.imgui then return; end
    local imgui=HC.imgui;
    local o=ensure(c);
    local owned,total,missing=counts(c);
    local verified_count=verified_owned_count(c);

    -- Compact, user-facing summary only. Packet/classifier diagnostics were
    -- removed from this panel now that the Regional Teleport decoder is stable.
    if o.needs_nation_refresh==true then
        local sid=o.active_nation_sid or current_nation_sid(c);
        imgui.Text('Outposts: NEEDS UPDATE FOR '..string.upper(NATION_NAMES[sid] or 'NEW NATION'));
        imgui.TextDisabled('Ownership is currently unverified after allegiance change.');
        imgui.TextDisabled('Talk to the new nation Conquest NPC and page through Regional Teleport.');
    elseif verified_count==#OUTPOSTS then
        -- Once all ownership is verified, the detailed manual list and proof
        -- metadata add no normal-user value. Diagnostics retains the source.
        imgui.Text('All outposts obtained');
        return;
    else
        imgui.Text(string.format('Outposts obtained: %d/%d',verified_count,#OUTPOSTS));
        if #missing>0 then
            local names={};
            for _,it in ipairs(missing) do names[#names+1]=it.name; end
            imgui.TextDisabled('Missing: '..table.concat(names,', '));
        end
    end

    imgui.Separator();
    imgui.TextDisabled('Outpost ownership');

    c.settings=type(c.settings)=='table' and c.settings or {};
    local hide_completed={c.settings.hide_completed_outposts==true};
    if imgui.Checkbox('Hide completed outposts##outposts_hide_completed',hide_completed) then
        c.settings.hide_completed_outposts=hide_completed[1];
        HC.modules.state.save();
    end

    -- Keep the per-region checkboxes as a manual fallback for unusual server
    -- states, but allow completed ownership rows to be hidden for readability.
    local shown=0;
    for _,it in ipairs(OUTPOSTS) do
        local is_owned=(o.verified_owned[it.key]==true);
        if not (c.settings.hide_completed_outposts==true and is_owned) then
        shown=shown+1;
        local box={is_owned};
        if imgui.Checkbox(it.name..'##outpost_'..it.key,box) then
            o.owned[it.key]=box[1] and true or nil;
            o.verified_owned[it.key]=box[1] and true or nil;
            if box[1]~=true then
                o.permanent_complete=nil;
                if o.auto_endpoint=='TELEPORT MENU' then
                    o.auto_endpoint=nil;
                    o.auto_confidence=nil;
                end
            end
            sync_parent(c);
            HC.modules.state.save();
            sync_durable_from_outposts(o);
        end
        imgui.SameLine();
        imgui.TextDisabled('- '..it.area);
        end
    end
    if shown==0 then
        imgui.TextDisabled('All outposts are complete.');
    end
end

function M.list() return OUTPOSTS; end

return M;
