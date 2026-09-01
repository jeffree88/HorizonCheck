local M = {};
local HC;

local ZONES = {
    'Leujaoam Sanctum',
    'Mamool Ja Training Grounds',
    'Lebros Cavern',
    'Periqia',
    'Ilrusi Atoll',
};

-- v7.8.21: Standard Assault Point vendor rewards.
-- Sources: HorizonXI Wiki Assault area/vendor pages current as of 2026-08-31.
-- Leujaoam's current Horizon pages individually confirm multiple entries and
-- use the same original-era vendor table; the complete 11-item set is retained
-- here so all five standard Assault areas present a consistent collection view.
local ASSAULT_POINT_REWARDS = {
    {
        id='leujaoam', area='Leujaoam Sanctum', vendor='Yahsra', vendor_pos='Whitegate L-10',
        items={
            {'Stoic Earring',3000},
            {'Unfettered Ring',5000},
            {'Tempered Chain',8000},
            {'Potent Belt',10000},
            {'Miraculous Cape',10000},
            {'Yigit Bulawa',15000},
            {'Imperial Bhuj',15000},
            {'Pahluwan Patas',15000},
            {'Amir Kolluks',20000},
            {'Pahluwan Qalansuwa',20000},
            {'Yigit Seraweels',20000},
        },
    },
    {
        id='mamool', area='Mamool Ja Training Grounds', vendor='Isdebaaq', vendor_pos='Whitegate L-10',
        items={
            {'Antivenom Earring',3000},
            {'Ebullient Ring',5000},
            {'Enlightened Chain',8000},
            {'Spectral Belt',10000},
            {'Bullseye Cape',10000},
            {'Storm Tulwar',15000},
            {'Imperial Neza',15000},
            {'Storm Tabar',15000},
            {'Yigit Gages',20000},
            {'Amir Boots',20000},
            {'Pahluwan Seraweels',20000},
        },
    },
    {
        id='lebros', area='Lebros Cavern', vendor='Famad', vendor_pos='Whitegate L-10',
        items={
            {'Insomnia Earring',3000},
            {'Hale Ring',5000},
            {'Chivalrous Chain',8000},
            {'Precise Belt',10000},
            {'Intensifying Cape',10000},
            {'Imperial Pole',15000},
            {'Doombringer',15000},
            {'Sayosamonji',15000},
            {'Pahluwan Dastanas',20000},
            {'Yigit Crackows',20000},
            {'Amir Korazin',20000},
        },
    },
    {
        id='periqia', area='Periqia', vendor='Lageegee', vendor_pos='Whitegate L-9',
        items={
            {'Vision Earring',3000},
            {'Unyielding Ring',5000},
            {'Fortified Chain',8000},
            {'Resolute Belt',10000},
            {'Bushido Cape',10000},
            {'Khanjar',15000},
            {'Hotarumaru',15000},
            {'Imperial Gun',15000},
            {'Amir Puggaree',20000},
            {'Pahluwan Crackows',20000},
            {'Yigit Gomlek',20000},
        },
    },
    {
        id='ilrusi', area='Ilrusi Atoll', vendor='Bhoy Yhupplo', vendor_pos='Whitegate L-9',
        items={
            {'Velocity Earring',3000},
            {'Garrulous Ring',5000},
            {'Grandiose Chain',8000},
            {'Hurling Belt',10000},
            {'Invigorating Cape',10000},
            {'Imperial Kaman',15000},
            {'Storm Zaghnal',15000},
            {'Storm Fife',15000},
            {'Yigit Turban',20000},
            {'Amir Dirs',20000},
            {'Pahluwan Khazagand',20000},
        },
    },
};

local ASSAULT_REWARD_LOCATION_SHORT={
    ['INVENTORY']='Inventory',['SAFE']='Safe',['STORAGE']='Storage',['TEMP']='Temp',['LOCKER']='Locker',
    ['SATCHEL']='Satchel',['SACK']='Sack',['CASE']='Case',
    ['WARDROBE 1']='Wardrobe 1',['WARDROBE 2']='Wardrobe 2',['WARDROBE 3']='Wardrobe 3',['WARDROBE 4']='Wardrobe 4',
    ['WARDROBE 5']='Wardrobe 5',['WARDROBE 6']='Wardrobe 6',['WARDROBE 7']='Wardrobe 7',['WARDROBE 8']='Wardrobe 8',
};

local function assault_reward_location(name)
    if not HC.modules.skills or not HC.modules.skills.collection_item_locations then
        return false,'Inventory scan unavailable';
    end
    local ok,rows,available=pcall(HC.modules.skills.collection_item_locations,name,false);
    if not ok or available~=true then return false,'Checking...'; end
    local parts={}; local total=0;
    if type(rows)=='table' then
        for _,row in ipairs(rows) do
            local count=math.max(0,tonumber(row and row.count) or 0);
            if count>0 then
                total=total+count;
                local raw=tostring(row.label or '');
                parts[#parts+1]=(ASSAULT_REWARD_LOCATION_SHORT[raw] or raw)..(count>1 and (' x'..tostring(count)) or '');
            end
        end
    end
    if total>0 then return true,table.concat(parts,', '); end

    -- Porter Moogle / non-physical collection proof is useful fallback context
    -- even though the requested display focuses on inventory and wardrobes.
    if HC.modules.skills.collection_item_location then
        local ok2,loc,available2=pcall(HC.modules.skills.collection_item_location,name,false);
        if ok2 and available2==true and loc=='STORED' then return true,'Porter Moogle'; end
    end
    return false,'—';
end

local function assault_reward_area_progress(area)
    local have=0;
    for _,rec in ipairs(area.items or {}) do
        local owned=assault_reward_location(rec[1]);
        if owned==true then have=have+1; end
    end
    return have,#(area.items or {});
end

local function draw_assault_point_rewards(c,focus)
    local imgui=HC.imgui; if not imgui then return; end
    imgui.Spacing();
    imgui.Separator();
    imgui.Spacing();

    local total_have,total_items=0,0;
    for _,area in ipairs(ASSAULT_POINT_REWARDS) do
        local h,t=assault_reward_area_progress(area);
        total_have=total_have+h; total_items=total_items+t;
    end

    local flags=rawget(_G,'ImGuiTreeNodeFlags_DefaultOpen') or 0;
    if type(focus)=='table' and focus.section=='rewards' and imgui.SetNextItemOpen then pcall(imgui.SetNextItemOpen,true,rawget(_G,'ImGuiCond_Always') or 1); end
    if not imgui.CollapsingHeader(string.format('Assault Point Rewards  %d/%d obtained##assault_point_rewards',total_have,total_items),flags) then
        return;
    end
    imgui.TextDisabled('Standard area-specific Assault Point gear. Owned items are detected from inventory/storage/Wardrobes; Porter storage is shown when known.');

    local table_supported=(imgui.BeginTable~=nil and imgui.TableSetupColumn~=nil
        and imgui.TableHeadersRow~=nil and imgui.TableNextRow~=nil
        and imgui.TableSetColumnIndex~=nil and imgui.EndTable~=nil);
    local table_flags=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);

    for _,area in ipairs(ASSAULT_POINT_REWARDS) do
        local have,total=assault_reward_area_progress(area);
        imgui.Spacing();
        local label=string.format('%s  %d/%d  |  %s - %s##assault_rewards_%s',
            tostring(area.area),have,total,tostring(area.vendor),tostring(area.vendor_pos),tostring(area.id));
        if type(focus)=='table' and tostring(focus.area or '')==tostring(area.id) and imgui.SetNextItemOpen then pcall(imgui.SetNextItemOpen,true,rawget(_G,'ImGuiCond_Always') or 1); end
        if imgui.CollapsingHeader(label,0) then
            if table_supported and imgui.BeginTable('##assault_reward_table_'..tostring(area.id),4,table_flags) then
                imgui.TableSetupColumn('Item',0,0.38);
                imgui.TableSetupColumn('Cost',0,0.15);
                imgui.TableSetupColumn('Status',0,0.15);
                imgui.TableSetupColumn('Location',0,0.32);
                imgui.TableHeadersRow();
                for _,rec in ipairs(area.items or {}) do
                    local item,cost=rec[1],tonumber(rec[2]) or 0;
                    local owned,location=assault_reward_location(item);
                    imgui.TableNextRow();
                    imgui.TableSetColumnIndex(0);
                    if HC.modules.uikit and HC.modules.uikit.collection_item then HC.modules.uikit.collection_item(item,owned); elseif owned then imgui.Text(tostring(item)); else imgui.TextDisabled(tostring(item)); end
                    imgui.TableSetColumnIndex(1);
                    imgui.TextDisabled(string.format('%s AP',tostring(cost):reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','')));
                    imgui.TableSetColumnIndex(2);
                    if HC.modules.uikit and HC.modules.uikit.collection_status then HC.modules.uikit.collection_status(owned,'—'); elseif owned then imgui.Text('✓'); else imgui.TextDisabled('—'); end
                    imgui.TableSetColumnIndex(3);
                    if HC.modules.uikit and HC.modules.uikit.collection_location then HC.modules.uikit.collection_location(location,owned); elseif owned then imgui.TextDisabled(tostring(location)); else imgui.TextDisabled('—'); end
                end
                imgui.EndTable();
            else
                for _,rec in ipairs(area.items or {}) do
                    local owned,location=assault_reward_location(rec[1]);
                    local line=string.format('%s | %d AP | %s',tostring(rec[1]),tonumber(rec[2]) or 0,owned and tostring(location) or 'MISSING');
                    if owned then imgui.Text(line); else imgui.TextDisabled(line); end
                end
            end
        end
    end

    imgui.Spacing();
    imgui.TextDisabled('Nyzul Isle is not included here because it uses Tokens rather than the five standard area-specific Assault Point pools.');
end

local RANKS = {
    {
        id='psc', abbr='PSC', name='Private Second Class', badge='PSC Wildcat Badge', promotion_qid=nil,
        missions={
            {'Leujaoam Cleansing','Leujaoam Sanctum'},
            {'Imperial Agent Rescue','Mamool Ja Training Grounds'},
            {'Excavation Duty','Lebros Cavern'},
            {'Seagull Grounded','Periqia'},
            {'Golden Salvage','Ilrusi Atoll'},
        },
    },
    {
        id='pfc', abbr='PFC', name='Private First Class', badge='PFC Wildcat Badge', promotion_qid=90,
        missions={
            {'Orichalcum Survey','Leujaoam Sanctum'},
            {'Preemptive Strike','Mamool Ja Training Grounds'},
            {'Lebros Supplies','Lebros Cavern'},
            {'Requiem','Periqia'},
            {'Lamia No.13','Ilrusi Atoll'},
        },
    },
    {
        id='sp', abbr='SP', name='Superior Private', badge='SP Wildcat Badge', promotion_qid=91,
        missions={
            {'Escort Professor Chanoix','Leujaoam Sanctum'},
            {'Sagelord Elimination','Mamool Ja Training Grounds'},
            {'Troll Fugitives','Lebros Cavern'},
            {'Saving Private Ryaaf','Periqia'},
            {'Extermination','Ilrusi Atoll'},
        },
    },
    {
        id='lc', abbr='LC', name='Lance Corporal', badge='LC Wildcat Badge', promotion_qid=92,
        missions={
            {'Shanarha Grass Conservation','Leujaoam Sanctum'},
            {'Breaking Morale','Mamool Ja Training Grounds'},
            {'Evade and Escape','Lebros Cavern'},
            {'Shooting Down the Baron','Periqia'},
            {'Demolition Duty','Ilrusi Atoll'},
        },
    },
    {
        id='c', abbr='C', name='Corporal', badge='C Wildcat Badge', promotion_qid=93,
        missions={
            {'Counting Sheep','Leujaoam Sanctum'},
            {'The Double Agent','Mamool Ja Training Grounds'},
            {'Siegemaster Assassination','Lebros Cavern'},
            {'Building Bridges','Periqia'},
            {'Searat Salvation','Ilrusi Atoll'},
        },
    },
    {
        id='s', abbr='S', name='Sergeant', badge='S Wildcat Badge', promotion_qid=94,
        missions={
            {'Supplies Recovery','Leujaoam Sanctum'},
            {'Imperial Treasure Retrieval','Mamool Ja Training Grounds'},
            {'Apkallu Breeding','Lebros Cavern'},
            {'Stop the Bloodshed','Periqia'},
            {'Apkallu Seizure','Ilrusi Atoll'},
        },
    },
    {
        id='sm', abbr='SM', name='Sergeant Major', badge='SM Wildcat Badge', promotion_qid=95,
        missions={
            {'Azure Experiments','Leujaoam Sanctum'},
            {'Blitzkrieg','Mamool Ja Training Grounds'},
            {'Wamoura Farm Raid','Lebros Cavern'},
            {'Defuse the Threat','Periqia'},
            {'Lost and Found','Ilrusi Atoll'},
        },
    },
    {
        id='cs', abbr='CS', name='Chief Sergeant', badge='CS Wildcat Badge', promotion_qid=96,
        missions={
            {'Imperial Code','Leujaoam Sanctum'},
            {'Marids in the Mist','Mamool Ja Training Grounds'},
            {'Egg Conservation','Lebros Cavern'},
            {'Operation: Snake Eyes','Periqia'},
            {'Deserter','Ilrusi Atoll'},
        },
    },
    {
        id='sl', abbr='SL', name='Second Lieutenant', badge='SL Wildcat Badge', promotion_qid=97,
        missions={
            {'Red Versus Blue','Leujaoam Sanctum'},
            {'Azure Ailments','Mamool Ja Training Grounds'},
            {'Operation: Black Pearl','Lebros Cavern'},
            {'Wake the Puppet','Periqia'},
            {'Desperately Seeking Cephalopods','Ilrusi Atoll'},
        },
    },
    {
        id='fl', abbr='FL', name='First Lieutenant', badge='FL Wildcat Badge', promotion_qid=98,
        missions={
            {'Bloody Rondo','Leujaoam Sanctum'},
            {'The Susanoo Shuffle','Mamool Ja Training Grounds'},
            {'Better Than One','Lebros Cavern'},
            {'The Price is Right','Periqia'},
            {"Bellerophon's Bliss",'Ilrusi Atoll'},
        },
    },
};

local function key(name)
    return string.lower(tostring(name or ''))
        :gsub('[^%w]+','_')
        :gsub('^_+','')
        :gsub('_+$','');
end

local function ensure(c)
    c.assault_progress=type(c.assault_progress)=='table' and c.assault_progress or {};
    local p=c.assault_progress;
    p.completed=type(p.completed)=='table' and p.completed or {};
    p.sources=type(p.sources)=='table' and p.sources or {};
    p.native_proof=type(p.native_proof)=='table' and p.native_proof or {};
    p.native=type(p.native)=='table' and p.native or {};
    -- Player-authored mission notes are permanent per-character state.  Keep
    -- them separate from completion proof so native sync / manual progress
    -- changes can never overwrite or clear the user's text.
    p.notes=type(p.notes)=='table' and p.notes or {};
    return p;
end


-- Native completed-Assault history is sent on zone-in in packet 0x056,
-- subtype 0x00C0. Windower's packet definition places a 16-byte
-- "Completed Assaults" bitfield at packet offset 0x14, after the first
-- 16-byte Completed TOAU Quests field. Assault DAT IDs are 1..50 and are
-- arranged by area (ten missions per area); bit zero is not a standard
-- Assault mission. Missing bits are never used to erase stronger saved proof.
local NATIVE_HISTORY_TYPE=0x00C0;
local NATIVE_ASSAULT_OFFSET=0x14;
local NATIVE_ASSAULT_BYTES=16;
local NATIVE_ASSAULT_PAYLOAD_INDEX=(NATIVE_ASSAULT_OFFSET-0x04)+1;
local NATIVE_STANDARD_TOTAL=50;
local NATIVE_MAPPING_VERSION=1;
local pending_native_payload=nil;
local native_rows_cache=nil;
local last_draw_native_sync_at=0;

local function u16le(s,pos)
    if type(s)~='string' or #s<(tonumber(pos) or 0)+1 then return nil; end
    local a,b=s:byte(pos,pos+1);
    if not a or not b then return nil; end
    return a+(b*256);
end

local function bytes_to_hex(s)
    if type(s)~='string' then return nil; end
    return (s:gsub('.',function(ch) return string.format('%02X',string.byte(ch)); end));
end

local function hex_to_bytes(h)
    if type(h)~='string' then return nil; end
    h=h:gsub('%s+','');
    if #h<2 or (#h%2)~=0 or h:find('[^0-9A-Fa-f]') then return nil; end
    local out={};
    for i=1,#h,2 do out[#out+1]=string.char(tonumber(h:sub(i,i+1),16)); end
    return table.concat(out);
end

local function bitmap_has_id(bitmap,id)
    id=tonumber(id);
    if type(bitmap)~='string' or not id or id<0 then return false; end
    local byte_pos=math.floor(id/8)+1;
    local b=bitmap:byte(byte_pos);
    if not b then return false; end
    local mask=2^(id%8);
    return (b%(mask*2))>=mask;
end

local function native_rows()
    if native_rows_cache then return native_rows_cache; end
    local rows={};
    for zone_index,zone in ipairs(ZONES) do
        for rank_index,rank in ipairs(RANKS) do
            local found=nil;
            for _,mission in ipairs(rank.missions) do
                if mission[2]==zone then found=mission; break; end
            end
            if found then
                local native_id=((zone_index-1)*10)+rank_index;
                rows[native_id]={
                    id=native_id,
                    name=found[1],
                    zone=zone,
                    rank=rank.abbr,
                    key=key(found[1]),
                };
            end
        end
    end
    native_rows_cache=rows;
    return rows;
end

local function tracked_count_from_progress(p)
    local done=0;
    for _,row in pairs(native_rows()) do
        if p.completed[row.key]==true then done=done+1; end
    end
    return done;
end

local function cached_native_payload(c)
    local raw=type(c)=='table' and type(c.quest_native_056_raw)=='table' and
        (c.quest_native_056_raw[tostring(NATIVE_HISTORY_TYPE)] or c.quest_native_056_raw[NATIVE_HISTORY_TYPE]) or nil;
    local payload=hex_to_bytes(raw);
    if type(payload)=='string' and #payload>=32 then return payload:sub(1,32); end
    return nil;
end

local function apply_native_payload(c,payload,opts)
    opts=type(opts)=='table' and opts or {};
    if type(c)~='table' or type(payload)~='string' or #payload<32 then return nil; end
    payload=payload:sub(1,32);
    local p=ensure(c);
    local native=p.native;
    local payload_hex=bytes_to_hex(payload);
    local bitmap=payload:sub(NATIVE_ASSAULT_PAYLOAD_INDEX,NATIVE_ASSAULT_PAYLOAD_INDEX+NATIVE_ASSAULT_BYTES-1);
    local bitmap_hex=bytes_to_hex(bitmap);
    local now=tonumber(opts.at) or os.time();
    local rows=native_rows();

    -- Identical Assault history normally needs no work. Check only the 50
    -- supported rows so a manual/developer edit cannot erase authoritative
    -- native proof while still avoiding per-frame catalog work.
    if native.synced==true and native.bitmap_hex==bitmap_hex then
        local needs_repair=false;
        for id=1,NATIVE_STANDARD_TOTAL do
            local row=rows[id];
            if row and bitmap_has_id(bitmap,id) then
                local proof=p.native_proof[row.key];
                local source=p.sources[row.key];
                if p.completed[row.key]~=true
                    or type(proof)~='table'
                    or tonumber(proof.native_id)~=id
                    or type(source)~='table'
                    or source.source~='NATIVE ASSAULT HISTORY'
                then
                    needs_repair=true;
                    break;
                end
            end
        end
        if not needs_repair then
            native.last_runtime_seen_at=now;
            native.payload_hex=payload_hex;
            return {
                synced=true, unchanged=true, added=0,
                native_completed=tonumber(native.native_completed) or 0,
                tracked_completed=tracked_count_from_progress(p),
            };
        end
    end

    local first_sync=native.synced~=true;
    local previous_bitmap=tostring(native.bitmap_hex or '');
    local imported={};
    local native_completed=0;
    local changed=first_sync or previous_bitmap~=tostring(bitmap_hex or '');

    for id=1,NATIVE_STANDARD_TOTAL do
        local row=rows[id];
        if row and bitmap_has_id(bitmap,id) then
            native_completed=native_completed+1;

            local proof=p.native_proof[row.key];
            if type(proof)~='table' then
                proof={first_seen_at=now};
                changed=true;
            end
            if tonumber(proof.native_id)~=id or proof.packet~='0x056/0x00C0'
                or proof.source~='NATIVE ASSAULT HISTORY'
            then
                changed=true;
            end
            proof.native_id=id;
            proof.packet='0x056/0x00C0';
            proof.source='NATIVE ASSAULT HISTORY';
            proof.last_seen_at=now;
            p.native_proof[row.key]=proof;

            local source=p.sources[row.key];
            if type(source)~='table' or source.source~='NATIVE ASSAULT HISTORY' then
                p.sources[row.key]={
                    source='NATIVE ASSAULT HISTORY',
                    packet='0x056/0x00C0',
                    native_id=id,
                    at=now,
                    automatic=true,
                };
                changed=true;
            else
                source.last_seen_at=now;
                source.native_id=id;
            end

            if p.completed[row.key]~=true then
                p.completed[row.key]=true;
                imported[#imported+1]=row;
                changed=true;
            end
        end
    end

    native.synced=true;
    native.synced_at=now;
    native.last_runtime_seen_at=now;
    native.packet='0x056/0x00C0';
    native.source=tostring(opts.source or 'native zone-in packet');
    native.payload_hex=payload_hex;
    native.bitmap_hex=bitmap_hex;
    native.native_completed=native_completed;
    native.mapping_version=NATIVE_MAPPING_VERSION;
    native.packet_received_at=now;
    native.payload_bytes=#payload;
    native.bitmap_bytes=#bitmap;
    native.imported_last=#imported;
    native.imported_total=(tonumber(native.imported_total) or 0)+#imported;
    native.tracked_completed=tracked_count_from_progress(p);

    if #imported>0 then
        p.last_completed=imported[#imported].name;
        p.last_completed_at=now;
        p.last_reason='NATIVE ASSAULT HISTORY | 0x056/0x00C0';
    end

    if changed and HC and HC.modules and HC.modules.state and HC.modules.state.request_save then
        HC.modules.state.request_save(1);
    end

    if (#imported>0 or (first_sync and native_completed>0)) and opts.silent~=true then
        local tracked=tracked_count_from_progress(p);
        if #imported>0 then
            HC.msg(string.format('Assault history synchronized: imported %d previous clear(s); tracker now %d/50.',#imported,tracked));
        else
            HC.msg(string.format('Assault history synchronized: %d/50 previous clears verified.',native_completed));
        end
    end

    if #imported>0 and HC and HC.modules and HC.modules.timeline and HC.modules.timeline.record then
        local names={};
        for i=1,math.min(#imported,5) do names[#names+1]=imported[i].name; end
        local detail=string.format('Imported %d previous clear(s) from native mission history | %d/50 tracked',#imported,tracked_count_from_progress(p));
        if #names>0 then detail=detail..' | '..table.concat(names,', ')..(#imported>#names and ', ...' or ''); end
        HC.modules.timeline.record(c,'import','Assault History Synchronized',detail,{
            source='0x056/0x00C0 Completed Assaults',scope='character',dedupe_seconds=2,
        });
    end

    return {
        synced=true, first_sync=first_sync, added=#imported,
        native_completed=native_completed,
        tracked_completed=tracked_count_from_progress(p),
    };
end

function M.sync_native_history(c,opts)
    opts=type(opts)=='table' and opts or {};
    c=c or (HC and HC.modules and HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or nil;
    if type(c)~='table' then return {synced=false,reason='character unavailable'}; end

    if pending_native_payload then
        local payload=pending_native_payload;
        pending_native_payload=nil;
        return apply_native_payload(c,payload,{silent=opts.silent,source='deferred live 0x056 packet'});
    end

    local payload=cached_native_payload(c);
    if payload then
        return apply_native_payload(c,payload,{silent=opts.silent,source=opts.source or 'saved 0x056 cache'});
    end

    local p=ensure(c);
    return {
        synced=p.native.synced==true,
        native_completed=tonumber(p.native.native_completed) or 0,
        tracked_completed=tracked_count_from_progress(p),
        reason='waiting for 0x056/0x00C0',
    };
end

function M.native_status(c)
    c=c or (HC and HC.modules and HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    local p=ensure(c);
    local n=p.native;
    return {
        synced=n.synced==true,
        synced_at=tonumber(n.synced_at),
        packet_received_at=tonumber(n.packet_received_at or n.last_runtime_seen_at),
        native_completed=tonumber(n.native_completed) or 0,
        tracked_completed=tracked_count_from_progress(p),
        imported_last=tonumber(n.imported_last) or 0,
        imported_total=tonumber(n.imported_total) or 0,
        source=n.source,
        packet=n.packet,
        mapping_version=tonumber(n.mapping_version) or NATIVE_MAPPING_VERSION,
        payload_bytes=tonumber(n.payload_bytes) or (n.payload_hex and math.floor(#n.payload_hex/2) or 0),
        bitmap_bytes=tonumber(n.bitmap_bytes) or (n.bitmap_hex and math.floor(#n.bitmap_hex/2) or 0),
        bitmap_hex=n.bitmap_hex,
    };
end

function M.native_diagnostics(c)
    c=c or (HC and HC.modules and HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    local p=ensure(c); local n=M.native_status(c); local rows=native_rows();
    local mapped=0; local duplicate_names=0; local seen={};
    for id=1,NATIVE_STANDARD_TOTAL do
        local row=rows[id];
        if row and row.name and row.zone and row.key then
            mapped=mapped+1;
            if seen[row.key] then duplicate_names=duplicate_names+1; else seen[row.key]=id; end
        end
    end
    local native_proof=0;
    for _,proof in pairs(p.native_proof or {}) do
        if type(proof)=='table' and proof.source=='NATIVE ASSAULT HISTORY' then native_proof=native_proof+1; end
    end
    return {
        synced=n.synced,packet_received=n.packet_received_at~=nil,packet_received_at=n.packet_received_at,
        packet=n.packet or '0x056/0x00C0',payload_bytes=n.payload_bytes,bitmap_bytes=n.bitmap_bytes,
        native_bits_set=n.native_completed,imported_last=n.imported_last,imported_total=n.imported_total,
        tracked_completed=n.tracked_completed,native_proof=native_proof,mapping_version=n.mapping_version,
        mapped_rows=mapped,mapping_complete=(mapped==NATIVE_STANDARD_TOTAL and duplicate_names==0),
        duplicate_names=duplicate_names,source=n.source or 'waiting for zone-in history',
        one_way_proof=true,
    };
end

function M.draw_native_diagnostics(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local d=M.native_diagnostics(c);
    imgui.Text('Native Completed-Assault History');
    imgui.TextDisabled('The server history may add verified clears. Missing bits never erase saved, live, or manual completion proof.');
    imgui.Text('Packet received: '..(d.packet_received and 'YES' or 'NO'));
    imgui.TextDisabled('Packet: '..tostring(d.packet)..' | payload '..tostring(d.payload_bytes or 0)..' bytes | Assault bitmap '..tostring(d.bitmap_bytes or 0)..' bytes');
    imgui.Text(string.format('Native bits set: %d | native proof rows: %d | tracked: %d/50',
        tonumber(d.native_bits_set) or 0,tonumber(d.native_proof) or 0,tonumber(d.tracked_completed) or 0));
    imgui.TextDisabled(string.format('Imported last sync: %d | imported total: %d | mapping version: %d',
        tonumber(d.imported_last) or 0,tonumber(d.imported_total) or 0,tonumber(d.mapping_version) or 0));
    imgui.Text((d.mapping_complete and '[PASS] ' or '[ATTN] ')..string.format('Mapping coverage: %d/50 | duplicate mission keys: %d',
        tonumber(d.mapped_rows) or 0,tonumber(d.duplicate_names) or 0));
    if d.packet_received_at then imgui.TextDisabled('Last packet/history observation: '..os.date('%Y-%m-%d %H:%M:%S',d.packet_received_at)); end
    imgui.TextDisabled('Source: '..tostring(d.source));
    if imgui.Button('Sync From Cached History##assault_native_diag_sync') then
        local r=M.sync_native_history(c,{silent=false,source='diagnostics validation'});
        if r and r.synced then HC.msg('Assault history validation synchronized cached native history.');
        else HC.msg('Assault history table has not been received yet. Zone once and try again.'); end
    end
end

local function find_mission(name)
    local low=string.lower(tostring(name or ''));
    low=low:gsub('%s+$',''):gsub('^%s+',''):gsub('%.+$','');
    for _,rank in ipairs(RANKS) do
        for _,m in ipairs(rank.missions) do
            if string.lower(m[1])==low then return rank,m; end
        end
    end
    return nil,nil;
end

function M.init(ctx)
    HC=ctx;
    if HC.modules.packets and HC.modules.packets.register then
        HC.modules.packets.register(0x056,'assault completed history',function(e)
            local data=nil;
            pcall(function() data=e and (e.data or e.data_raw); end);
            if type(data)~='string' or #data<38 then return; end
            local typ=u16le(data,37);
            if typ~=NATIVE_HISTORY_TYPE then return; end

            local payload=data:sub(5,36);
            local ready=HC.modules.state and HC.modules.state.profile_ready and HC.modules.state.profile_ready();
            if ready~=true then
                pending_native_payload=payload;
                return;
            end

            local c=HC.modules.state.get_char();
            apply_native_payload(c,payload,{source='live 0x056 zone-in packet'});
        end);
    end
end

function M.is_complete(c,name)
    return ensure(c).completed[key(name)]==true;
end

function M.mark_complete(c,name,why)
    local rank,m=find_mission(name);
    if not m then return false; end
    local p=ensure(c);
    local k=key(m[1]);
    if p.completed[k]==true then return false; end
    p.completed[k]=true;
    p.sources[k]={source=tostring(why or 'LIVE ASSAULT CLEAR'),at=os.time(),automatic=true};
    p.last_completed=m[1];
    p.last_completed_at=os.time();
    p.last_reason=why;
    HC.modules.state.save();
    HC.msg('AUTO: Assault mission clear recorded - '..m[1]..' ['..rank.abbr..']');
    return true;
end

function M.set_complete(c,name,value)
    local rank,m=find_mission(name);
    if not m then return false; end
    local p=ensure(c);
    local k=key(m[1]);
    p.completed[k]=value and true or nil;
    if value then
        p.sources[k]={source='MANUAL',at=os.time(),automatic=false};
    else
        p.sources[k]=nil;
    end
    HC.modules.state.save();
    return true;
end

function M.count(c)
    local p=ensure(c);
    local done=0;
    for _,rank in ipairs(RANKS) do
        for _,m in ipairs(rank.missions) do
            if p.completed[key(m[1])]==true then done=done+1; end
        end
    end
    return done,50;
end

local function rank_count(c,rank)
    local p=ensure(c); local done=0;
    for _,m in ipairs(rank.missions) do
        if p.completed[key(m[1])]==true then done=done+1; end
    end
    return done,#rank.missions;
end

-- Returns the highest mercenary rank HorizonCheck can prove.  Promotion quest
-- completion is authoritative when the completed quest history is available.
-- The currently-held Wildcat Badge is also authoritative; because promotions
-- replace the previous badge, a higher badge proves every lower rank as well.
local rank_evidence_cache={at=0,badge_index=0,badge_name=nil};
local function badge_rank_index()
    local now=os.time();
    if (now-tonumber(rank_evidence_cache.at or 0))<5 then
        return tonumber(rank_evidence_cache.badge_index or 0),rank_evidence_cache.badge_name;
    end
    rank_evidence_cache.at=now;
    rank_evidence_cache.badge_index=0;
    rank_evidence_cache.badge_name=nil;
    if not (HC.modules.keyitems and HC.modules.keyitems.ownership_name) then return 0,nil; end
    for i=#RANKS,1,-1 do
        local owned=HC.modules.keyitems.ownership_name(RANKS[i].badge);
        if owned==true then
            rank_evidence_cache.badge_index=i;
            rank_evidence_cache.badge_name=RANKS[i].badge;
            break;
        end
    end
    return rank_evidence_cache.badge_index,rank_evidence_cache.badge_name;
end

function M.current_rank_index(c)
    local highest=0; local source=nil;
    if HC.modules.quests and HC.modules.quests.is_completed then
        for i,rank in ipairs(RANKS) do
            if rank.promotion_qid~=nil and HC.modules.quests.is_completed(6,rank.promotion_qid)==true and i>highest then
                highest=i;
                source='Promotion quest completed';
            end
        end
    end
    local bi,bname=badge_rank_index();
    if bi>highest then
        highest=bi;
        source=tostring(bname)..' [0x055 KEY ITEM VERIFIED]';
    end
    return highest,source;
end

function M.rank_confirmed(c,rank_index)
    local highest,source=M.current_rank_index(c);
    return highest>=tonumber(rank_index or 0),source,highest;
end

local function draw_mission_note(p,mission_name)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local mission_key=key(mission_name);
    p.notes=type(p.notes)=='table' and p.notes or {};
    if type(imgui.SetNextItemWidth)=='function' then
        -- Fill the Notes table cell so every editor begins and ends on the
        -- same vertical guides regardless of mission/location text length.
        pcall(function() imgui.SetNextItemWidth(-1); end);
    end
    local buf={tostring(p.notes[mission_key] or '')};
    local ok,changed=pcall(function()
        return imgui.InputText('##assault_note_'..mission_key,buf,480);
    end);
    if ok and changed then
        local value=tostring(buf[1] or '');
        -- Empty notes do not need a serialized key, but non-empty text is saved
        -- immediately so /addon reload and logout/login preserve every edit.
        p.notes[mission_key]=(value~='' and value or nil);
        HC.modules.state.save();
    elseif not ok then
        imgui.TextDisabled('[note input unavailable]');
    end
end

local function draw_mission_status(c,p,m,complete)
    local imgui=HC.imgui;
    local mission_name=m[1];
    local mission_key=key(mission_name);
    if complete then
        if type(c.settings)=='table' and c.settings.developer_mode==true then
            local box={true};
            if imgui.Checkbox(mission_name..'##assault_done_'..mission_key,box) then
                p.completed[mission_key]=box[1] and true or nil;
                HC.modules.state.save();
            end
        else
            imgui.Text('✓ '..mission_name);
        end
    else
        -- Keep incomplete missions visually dimmed/grey while still allowing
        -- manual completion in Developer Mode for old/pre-addon clears.
        imgui.TextDisabled('[ ] '..mission_name);
    end

    imgui.SameLine();
    imgui.TextDisabled('- '..tostring(m[2] or ''));

    if type(c.settings)=='table' and c.settings.developer_mode==true then
        if not complete then
            imgui.SameLine();
            if imgui.SmallButton('Mark Complete##assault_mark_'..mission_key) then
                p.completed[mission_key]=true;
                HC.modules.state.save();
            end
        end
        if HC.modules.learning and HC.modules.learning.capture_button then
            imgui.SameLine();
            HC.modules.learning.capture_button('assault','assault_mission_'..mission_key);
        end
    end
end

function M.draw(c)
    local imgui=HC.imgui; if not imgui then return; end
    local p=ensure(c);
    local nav=(HC.modules.ui and HC.modules.ui.consume_focus) and HC.modules.ui.consume_focus('assault') or nil;
    local now=os.time();
    if p.native.synced~=true or (now-last_draw_native_sync_at)>=30 then
        last_draw_native_sync_at=now;
        M.sync_native_history(c,{silent=true,source='Assault tab cache'});
    end
    local done,total=M.count(c);
    c.settings=type(c.settings)=='table' and c.settings or {};
    local hide_completed={c.settings.hide_completed_assaults==true};

    -- Assault tag ownership/timing is rendered once by modules/assault.lua.
    -- Keep this view focused on mission completion progress; the old duplicated
    -- tag diagnostics and Current Assault block were intentionally removed.


    -- Rank summary: white means the mercenary rank itself is proven attained;
    -- grey means the rank is not yet proven.  Mission x/5 progress remains
    -- independent of rank proof.
    local highest_rank,rank_source=M.current_rank_index(c);
    for i,rank in ipairs(RANKS) do
        local rd,rt=rank_count(c,rank);
        if i>1 then
            imgui.SameLine(); imgui.TextDisabled('|'); imgui.SameLine();
        end
        local label=string.format('%s %d/%d',rank.abbr,rd,rt);
        if i<=highest_rank then imgui.Text(label); else imgui.TextDisabled(label); end
    end
    if highest_rank>0 and rank_source then
        imgui.TextDisabled('Highest proven rank: '..tostring(RANKS[highest_rank].name)..' - '..tostring(rank_source));
    end

    local native=M.native_status(c);
    if native.synced then
        imgui.TextDisabled(string.format('Past Assaults loaded: %d/50 found | %d/50 tracked',native.native_completed,native.tracked_completed));
        if imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then
            imgui.SetTooltip('HorizonCheck can fill in older completed Assaults after you zone. Missing game history will never erase progress you already have saved.');
        end
    else
        imgui.TextDisabled('Past Assaults will load after you zone once.');
    end

    imgui.Text(string.format('Assault Mission Progress: %d/%d',done,total));
    if done==total then
        imgui.Text('All 50 standard Assault missions completed - Captain Assault requirement complete.');
    else
        imgui.TextDisabled(string.format('%d mission(s) remaining for 50/50 Assault completion.',total-done));
    end

    for _,rank in ipairs(RANKS) do
        local rd,rt=rank_count(c,rank);
        local flags=(rd<rt) and (ImGuiTreeNodeFlags_DefaultOpen or 0) or 0;
        if imgui.CollapsingHeader(string.format('%s - %s (%d/%d)##assault_rank_%s',
            rank.abbr,rank.name,rd,rt,rank.id),flags) then

            local shown=0;
            local visible={};
            for _,m in ipairs(rank.missions) do
                local complete=p.completed[key(m[1])]==true;
                if not (c.settings.hide_completed_assaults==true and complete) then
                    shown=shown+1;
                    visible[#visible+1]={mission=m,complete=complete};
                end
            end

            -- Two aligned columns keep every Notes editor on the same guide.
            -- Keep the mission/location side narrower so Notes begins closer
            -- to the location text while still leaving enough room for the
            -- longest standard Assault mission/location labels without overlap.
            local table_supported=(imgui.BeginTable~=nil and imgui.TableSetupColumn~=nil
                and imgui.TableHeadersRow~=nil and imgui.TableNextRow~=nil
                and imgui.TableSetColumnIndex~=nil and imgui.EndTable~=nil);
            local table_flags=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
            if shown>0 and table_supported and imgui.BeginTable('##assault_rank_table_'..rank.id,2,table_flags) then
                imgui.TableSetupColumn('Assault / Location',0,0.38);
                imgui.TableSetupColumn('Notes',0,0.62);
                imgui.TableHeadersRow();
                for _,row in ipairs(visible) do
                    imgui.TableNextRow();
                    imgui.TableSetColumnIndex(0);
                    draw_mission_status(c,p,row.mission,row.complete);
                    imgui.TableSetColumnIndex(1);
                    draw_mission_note(p,row.mission[1]);
                end
                imgui.EndTable();
            elseif shown>0 then
                -- Fallback for older ImGui bindings: keep the previous stacked
                -- rendering rather than making the Assault tab unavailable.
                for _,row in ipairs(visible) do
                    draw_mission_status(c,p,row.mission,row.complete);
                    imgui.TextDisabled('Notes:');
                    draw_mission_note(p,row.mission[1]);
                end
            end
            if shown==0 then imgui.TextDisabled('All Assaults in this rank are complete.'); end
        end
    end

    imgui.Separator();
    imgui.TextDisabled('Rank abbreviations turn white when the promotion is proven by completed quest history or the current Wildcat Badge key item. Completed Assaults show ✓; incomplete Assaults are greyed out.');

    draw_assault_point_rewards(c,nav);
end

function M.command(w)
    if string.lower(w[2] or '')~='assaultprogress' then return false; end
    local c=HC.modules.state.get_char();
    local sub=string.lower(w[3] or '');
    if sub=='status' or sub=='' then
        M.sync_native_history(c,{silent=true,source='status command'});
        local d,t=M.count(c); local ns=M.native_status(c);
        HC.msg(string.format('Assault mission progress: %d/%d | native history: %s.',d,t,ns.synced and (tostring(ns.native_completed)..'/50 synced') or 'waiting - zone once'));
        return true;
    elseif sub=='sync' then
        local ns=M.sync_native_history(c,{silent=false,source='manual sync command'});
        if ns and ns.synced then
            HC.msg(string.format('Assault history is synchronized: %d/50 native clears | %d/50 tracked.',tonumber(ns.native_completed) or 0,tonumber(ns.tracked_completed) or 0));
        else
            HC.msg('Assault history is waiting for the native zone-in table. Zone once, then check again.');
        end
        return true;
    elseif sub=='clear' then
        local p=ensure(c);
        local saved_notes=p.notes;
        c.assault_progress={completed={},notes=saved_notes};
        HC.modules.state.save();
        HC.msg('Assault mission progress cleared. Saved mission notes were preserved.');
        return true;
    end
    HC.msg('Usage: /hcheck assaultprogress status|sync|clear');
    return true;
end

function M.reward_catalog_entries(c)
    local out={};
    for _,area in ipairs(ASSAULT_POINT_REWARDS) do
        for _,rec in ipairs(area.items or {}) do
            local owned,location=assault_reward_location(rec[1]);
            out[#out+1]={
                name=tostring(rec[1]),cost=tonumber(rec[2]) or 0,area=tostring(area.area),area_id=tostring(area.id),
                vendor=tostring(area.vendor),vendor_pos=tostring(area.vendor_pos),owned=owned==true,location=tostring(location or ''),
            };
        end
    end
    return out;
end

function M.ranks() return RANKS; end
function M.native_rows() return native_rows(); end

return M;
