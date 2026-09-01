local M={};
local HC=nil;

local function user_file(kind,name)
    if HC and HC.modules and HC.modules.userdata and HC.modules.userdata.path then
        local ok,res=pcall(HC.modules.userdata.path,kind,name);
        if ok and type(res)=='string' and res~='' then return res; end
    end
    return tostring(HC and HC.addon_path or '')..tostring(name or '');
end

local mission_capture={ active=false, started_at=0, file=nil, packets=0, types={}, pages={}, last_data=nil, selected_story=nil };

local function hex_bytes(s)
    if type(s)~='string' then return ''; end
    local out={};
    for i=1,#s do out[#out+1]=string.format('%02X',s:byte(i)); end
    return table.concat(out,' ');
end

local function hex_range(s,a,b)
    if type(s)~='string' then return ''; end
    a=math.max(1,tonumber(a) or 1);
    b=math.min(#s,tonumber(b) or #s);
    local out={};
    for i=a,b do out[#out+1]=string.format('%02X',s:byte(i)); end
    return table.concat(out,' ');
end

local function nonzero_map(s,a,b)
    if type(s)~='string' then return ''; end
    a=math.max(1,tonumber(a) or 1);
    b=math.min(#s,tonumber(b) or #s);
    local out={};
    for i=a,b do
        local v=s:byte(i);
        if v and v~=0 then out[#out+1]=string.format('%02d:%02X',i,v); end
    end
    return #out>0 and table.concat(out,' ') or '(none)';
end

local function packet_sequence(data)
    -- FFXI header bytes 3-4 contain size/sequence flags. Keep both raw bytes
    -- and a compact sequence candidate for comparing a zone-in burst.
    if type(data)~='string' or #data<4 then return nil,nil,nil; end
    local b3,b4=data:byte(3,4);
    return b3,b4,((b4 or 0)*256+(b3 or 0));
end

local function page_marker(data)
    -- In the first HorizonXI capture byte 37 advanced 0x50,0x58,0x60...
    -- across the burst. Treat it as an observed page/slot marker only.
    if type(data)~='string' or #data<37 then return nil; end
    return data:byte(37);
end

local function capture_path()
    local stamp=os.date('%Y%m%d_%H%M%S');
    return user_file('captures','horizoncheck_mission_packets_'..stamp..'.txt');
end

local function capture_write(line)
    if not mission_capture.active or not mission_capture.file then return; end
    local f=io.open(mission_capture.file,'a');
    if not f then return; end
    f:write(tostring(line),'\n');
    f:close();
end

local function select_capture_story(label)
    mission_capture.selected_story=tostring(label or 'unlabeled');
    return true;
end


-- Manual mission checklist with full mission names.
-- Data is intentionally static; completion is per-character and user-controlled.

local series={
    {
        id='sandoria', name="San d'Oria", group_label='Rank',
        missions={
            {'1','1-1','Smash the Orcish Scouts','Repeatable','Rank Points'},
            {'1','1-2','Bat Hunt','Repeatable','Rank Points'},
            {'1','1-3','Save the Children','Repeatable',"Rank 2 / 1,000 gil / San d'Orian Ring"},
            {'2','2-1','The Rescue Drill','Quest','Rank Points'},
            {'2','2-2','The Davoi Report','Repeatable','Rank Points'},
            {'2','2-3','Journey Abroad','BCNM','Rank 3 / 3,000 gil / Adventurer Certificate / Mog Wardrobe +10 / Jeuno Outpost Teleport'},
            {'3','3-1','Infiltrate Davoi','Repeatable','Rank Points'},
            {'3','3-2','The Crystal Spring','Repeatable','Rank Points'},
            {'3','3-3','Appointment to Jeuno','Fight','Rank 4 / 5,000 gil'},
            {'4','4-1','Magicite','Quest','Rank 5 / 10,000 gil / Airship Pass'},
            {'5','5-1',"The Ruins of Fei'Yin",'BCNM','Rank Points'},
            {'5','5-2','The Shadow Lord','BCNM','Rank 6 / 20,000 gil / Unlock Zilart + Dynamis / Mog Wardrobe +10'},
            {'6','6-1',"Leaute's Last Wishes",'Fight','Rank Points'},
            {'6','6-2',"Ranperre's Final Rest",'Fight','Rank 7 / 40,000 gil'},
            {'7','7-1','Prestige of the Papsque','Fight','Rank Points'},
            {'7','7-2','Secret Weapon','BCNM','Rank 8 / 60,000 gil / Mog Wardrobe +10'},
            {'8','8-1','Coming of Age','Fight','Rank Points'},
            {'8','8-2','Lightbringer','Fight','Rank 9 / 80,000 gil'},
            {'9','9-1','Breaking Barriers','Fight','Rank Points'},
            {'9','9-2','The Heir to the Light','BCNM',"Rank 10 / 100,000 gil / San d'Orian Flag"},
        },
    },
    {
        id='bastok', name='Bastok', group_label='Rank',
        missions={
            {'1','1-1','The Zeruhn Report','Quest','Rank Points'},
            {'1','1-2','A Geological Survey','Quest','Rank Points'},
            {'1','1-3','Fetichism','Repeatable','Rank 2 / 1,000 gil / Bastokan Ring'},
            {'2','2-1','The Crystal Line','Quest','Rank Points'},
            {'2','2-2','Wading Beasts','Repeatable','Rank Points'},
            {'2','2-3','The Emissary','BCNM','Rank 3 / 3,000 gil / Adventurer Certificate / Mog Wardrobe +10 / Jeuno Outpost Teleport'},
            {'3','3-1','The Four Musketeers','Quest','Rank Points'},
            {'3','3-2','To the Forsaken Mines','Repeatable','Rank Points'},
            {'3','3-3','Jeuno','Fight','Rank 4 / 5,000 gil'},
            {'4','4-1','Magicite','Quest','Rank 5 / 10,000 gil / Airship Pass'},
            {'5','5-1','Darkness Rising','BCNM','Rank Points'},
            {'5','5-2','Xarcabard, Land of Truths','BCNM','Rank 6 / 20,000 gil / Unlock Zilart + Dynamis / Mog Wardrobe +10'},
            {'6','6-1','Return of the Talekeeper','Fight','Rank Points'},
            {'6','6-2',"The Pirates' Cove",'Fight','Rank 7 / 40,000 gil'},
            {'7','7-1','The Final Image','Fight','Rank Points'},
            {'7','7-2','On My Way','BCNM','Rank 8 / 60,000 gil / Mog Wardrobe +10'},
            {'8','8-1','The Chains That Bind Us','Fight','Rank Points'},
            {'8','8-2','Enter the Talekeeper','Fight','Rank 9 / 80,000 gil'},
            {'9','9-1','The Salt of the Earth','Fight','Rank Points'},
            {'9','9-2','Where Two Paths Converge','BCNM','Rank 10 / 100,000 gil / Bastokan Flag'},
        },
    },
    {
        id='windurst', name='Windurst', group_label='Rank',
        missions={
            {'1','1-1','The Horutoto Ruins Experiment','Quest','Rank Points'},
            {'1','1-2','The Heart of the Matter','Quest','Rank Points'},
            {'1','1-3','The Price of Peace','Quest','Rank 2 / 1,000 gil / Windurstian Ring'},
            {'2','2-1','Lost for Words','Quest','Rank Points'},
            {'2','2-2','A Testing Time','Repeatable','Rank Points'},
            {'2','2-3','The Three Kingdoms','BCNM','Rank 3 / 3,000 gil / Adventurer Certificate / Mog Wardrobe +10 / Jeuno Outpost Teleport'},
            {'3','3-1','To Each His Own Right','Quest','Rank Points / Starway Stairway bauble'},
            {'3','3-2','Written in the Stars','Repeatable','Rank Points / Portal charm'},
            {'3','3-3','A New Journey','Fight','Rank 4 / 5,000 gil'},
            {'4','4-1','Magicite','Quest','Rank 5 / 10,000 gil / Airship Pass'},
            {'5','5-1','The Final Seal','BCNM','Rank Points'},
            {'5','5-2','The Shadow Awaits','BCNM','Rank 6 / 20,000 gil / Unlock Zilart + Dynamis / Mog Wardrobe +10'},
            {'6','6-1','Full Moon Fountain','Fight','Rank Points'},
            {'6','6-2','Saintly Invitation','BCNM','Rank 7 / 40,000 gil / Ashura Necklace'},
            {'7','7-1','The Sixth Ministry','Fight','Rank Points'},
            {'7','7-2','Awakening of the Gods','Fight','Rank 8 / 60,000 gil / Mog Wardrobe +10'},
            {'8','8-1','Vain','Fight','Rank Points'},
            {'8','8-2',"The Jester Who'd Be King",'Fight','Rank 9 / 80,000 gil'},
            {'9','9-1','Doll of the Dead','Quest','Rank Points'},
            {'9','9-2','Moon Reading','BCNM','Rank 10 / 100,000 gil / Windurstian Flag'},
        },
    },
    {
        id='zilart', name='Rise of the Zilart', group_label='Arc',
        missions={
            {'','1','The New Frontier','Cutscene','Map of Norg'},
            {'','2',"Welcome t'Norg",'Cutscene','—'},
            {'','3',"Kazham's Chieftainess",'Cutscene','Sacrificial Chamber key'},
            {'','4','The Temple of Uggalepih','Dungeon/BCNM','Dark Fragment / Mog Wardrobe 2 +5'},
            {'','5','Headstone Pilgrimage','Quest/Fight','Seven elemental fragments'},
            {'','6','Through the Quicksand Caves','Dungeon/BCNM','Mog Wardrobe 2 +5'},
            {'','7','The Chamber of Oracles','Cutscene','Prismatic fragment'},
            {'','8',"Return to Delkfutt's Tower",'Dungeon/BCNM','Mog Wardrobe 2 +5'},
            {'','9',"Ro'Maeve",'Quest','—'},
            {'','10','The Temple of Desolation','Cutscene','—'},
            {'','11','The Hall of the Gods','Quest','—'},
            {'','12','The Mithra and the Crystal','Dungeon/Fight','Cerulean crystal'},
            {'','13','The Gate of the Gods','Cutscene',"Access to Tu'Lia"},
            {'','14','Ark Angels','BCNM','Five Ark Angel shards / Divine Might option'},
            {'','15','The Sealed Shrine','Cutscene','—'},
            {'','16','The Celestial Nexus','Dungeon/BCNM','—'},
            {'','17','Awakening','Finale','—'},
        },
    },
    {
        id='cop', name='Chains of Promathia', group_label='Chapter',
        missions={
            {'1','1-1','The Rites of Life','Cutscene','Mysterious amulet'},
            {'1','1-2','Below the Arks','Dungeon/BCNM','Access to Promyvions'},
            {'1','1-3','The Mothercrystals','Dungeon/BCNM','Lights of Dem/Holla/Mea / Tavnazia access / Mog Wardrobe 2 +5'},
            {'2','2-1','An Invitation West','Cutscene','Mysterious amulet'},
            {'2','2-2','The Lost City','Cutscene','Access to Phomiuna Aqueducts'},
            {'2','2-3','Distant Beliefs','Cutscene/Fight','—'},
            {'2','2-4','An Eternal Melody','Cutscene','Riverne - Site A01 access'},
            {'2','2-5','Ancient Vows','Dungeon/BCNM','Mog Wardrobe 2 +2'},
            {'3','3-1','The Call of the Wyrmking','Cutscene','—'},
            {'3','3-2','A Vessel Without a Captain','Cutscene','—'},
            {'3','3-3','The Road Forks','Quest/Fight','—'},
            {'3','3-4','Tending Aged Wounds','Cutscene','—'},
            {'3','3-5','Darkness Named','Dungeon/BCNM',"Pso'Xja pass / Dreamworld Dynamis access"},
            {'4','4-1','Sheltering Doubt','Cutscene','Riverne - Site B01 access'},
            {'4','4-2','The Savage','Dungeon/BCNM','Access to Sacrarium / Mog Wardrobe 2 +3'},
            {'4','4-3','The Secrets of Worship','Dungeon/Fight','—'},
            {'4','4-4','Slanderous Utterings','Cutscene','—'},
            {'5','5-1','The Enduring Tumult of War','Cutscene/Fight','Access to Promyvion - Vahzl'},
            {'5','5-2','Desires of Emptiness','Dungeon/Fight/BCNM','Light of Vahzl / Mog Wardrobe 2 +5'},
            {'5','5-3','Three Paths','Quest/Fight/BCNM','Complete Louverance / Tenzen / Ulmia paths / Mog Wardrobe 2 +5'},
            {'6','6-1','For Whom the Verse is Sung','Cutscene','—'},
            {'6','6-2','A Place to Return','Fight','—'},
            {'6','6-3','More Questions than Answers','Cutscene','—'},
            {'6','6-4','One to be Feared','BCNM',"Ducal Guard's Ring / Mog Wardrobe 2 +3"},
            {'7','7-1','Chains and Bonds','Cutscene','—'},
            {'7','7-2','Flames in the Darkness','Cutscene','—'},
            {'7','7-3','Fire in the Eyes of Men','Cutscene','—'},
            {'7','7-4','Calm Before the Storm','Cutscene/Fight','—'},
            {'7','7-5',"The Warrior's Path",'BCNM',"Light of Al'Taieu / Access to Al'Taieu + Limbus / Mog Wardrobe 2 +5"},
            {'8','8-1','Garden of Antiquity','Fight','Tavnazian Ring'},
            {'8','8-2','A Fate Decided','Dungeon/Fight','—'},
            {'8','8-3','When Angels Fall','Dungeon/BCNM','Mog Wardrobe 2 +2'},
            {'8','8-4','Dawn','BCNM/Finale','Rajas / Sattva / Tamas Ring / Mog Wardrobe 2 +5'},
            {'Epilogue','8-5','The Last Verse','Finale','—'},
        },
    },
    {
        id='toau', name='Treasures of Aht Urhgan', group_label='Arc',
        missions={
            {'','1','Land of Sacred Serpents','Cutscene','Supplies Package'},
            {'','2','Immortal Sentries','Quest','150 Imperial Standing / PSC Wildcat Badge / Mog Locker access / Sanction access'},
            {'','3','President Salaheem','Cutscene','Assault access'},
            {'','4','Knight of Gold','Cutscene',"Raillefal's Letter"},
            {'','5','Confessions of Royalty','Cutscene','—'},
            {'','6','Easterly Winds','Cutscene','Imperial Bronze Piece x10 (optional)'},
            {'','7','Westerly Winds','Cutscene',"Raillefal's Note / Imperial Silver Piece x2"},
            {'','8','A Mercenary Life','Cutscene','1 in-game day wait -> Undersea Scouting'},
            {'','9','Undersea Scouting','Quest','Astral Compass'},
            {'','10','Astral Waves','Cutscene','JP midnight wait -> Imperial Schemes'},
            {'','11','Imperial Schemes','Cutscene','JP midnight wait -> Royal Puppeteer'},
            {'','12','Royal Puppeteer','Quest','Vial of Spectral Scent'},
            {'','13','Lost Kingdom','Fight','Ephramadian Gold Coin / Mog Wardrobe 3 +5'},
            {'','14','The Dolphin Crest','Cutscene','—'},
            {'','15','The Black Coffin','Battlefield','Mog Wardrobe 3 +5'},
            {'','16','Ghosts of the Past','Cutscene','—'},
            {'','17','Guests of the Empire','Cutscene','Imperial Mythril Piece / Salvage access'},
            {'','18','Passing Glory','Current HorizonXI cap','Continuation in a future HorizonXI patch'},
            {'','19','Sweets for the Soul','Cutscene','—'},
            {'','20','Teahouse Tumult','Quest','—'},
            {'','21','Finders Keepers','Cutscene','—'},
            {'','22','Shield of Diplomacy','BCNM','—'},
            {'','23','Social Graces','Cutscene','JP midnight wait'},
            {'','24','Foiled Ambition','Cutscene','Imperial Gold Piece x5'},
            {'','25','Playing the Part','Cutscene','—'},
            {'','26','Seal of the Serpent','Cutscene','—'},
            {'','27','Misplaced Nobility','Quest','—'},
            {'','28','Bastion of Knowledge','Cutscene','—'},
            {'','29','Puppet in Peril','BCNM','—'},
            {'','30','Prevalence of Pirates','Quest','Periqia Assault Area Entry Permit'},
            {'','31','Shades of Vengeance','BCNM','—'},
            {'','32','In the Blood','Cutscene','Imperial Gold Piece x1'},
            {'','33',"Sentinels' Honor",'Cutscene','—'},
            {'','34','Testing the Waters','Quest','Percipient Eye'},
            {'','35','Legacy of the Lost','BCNM','—'},
            {'','36','Gaze of the Saboteur','Cutscene','Luminian Dagger'},
            {'','37','Path of Blood','Cutscene','—'},
            {'','38','Stirrings of War','Cutscene','Allied Council Summons'},
            {'','39','Allied Rumblings','Cutscene','—'},
            {'','40','Unraveling Reason','Cutscene','—'},
            {'','41','Light of Judgment','Cutscene','Nyzul Isle Route'},
            {'','42','Path of Darkness','BCNM','—'},
            {'','43','Fangs of the Lion','Cutscene','Mythril Mirror'},
            {'','44',"Nashmeira's Plea",'BCNM','—'},
            {'','45','Ragnarok','Cutscene','—'},
            {'','46','Imperial Coronation','Cutscene',"Imperial Standard / Balrahn's, Ulthalam's, or Jalzahn's Ring"},
            {'','47','The Empress Crowned','Cutscene','Glory Crown'},
            {'','48','Eternal Mercenary','Cutscene','Ability to purchase Atma of the Sellsword'},
        },
    },
};

local function ensure(c)
    c.missions=type(c.missions)=='table' and c.missions or {};
    for _,s in ipairs(series) do
        c.missions[s.id]=type(c.missions[s.id])=='table' and c.missions[s.id] or {};
    end
    return c.missions;
end

local function key_for(number,name)
    return (tostring(number)..'_'..tostring(name)):gsub('[^%w]+','_'):lower();
end

local ensure_meta;
local source_key;
local function count_done(c,s)
    local n=0;
    for _,m in ipairs(s.missions) do
        if c.missions[s.id][key_for(m[2],m[3])]==true then n=n+1; end
    end
    return n;
end

function M.progress_summary(c)
    ensure(c);
    local out={};
    for _,s in ipairs(series) do
        out[#out+1]={id=s.id,name=s.name,done=count_done(c,s),total=#s.missions};
    end
    return out;
end

local function set_manual_checked(c,sid,k,value)
    local ok,err=pcall(function()
        ensure(c);
        c.missions[sid][k]=value and true or false;
        local meta=ensure_meta(c);
        meta.sources[source_key(sid,k)]={source='MANUAL',at=os.time()};
        HC.modules.state.save();
    end);
    if not ok then
        if HC and HC.msg then HC.msg('Mission checkbox save error: '..tostring(err)); end
        return false;
    end
    return true;
end

local function mission_display_type(s,m)
    local typ=tostring(m[4] or '');
    local a=HC and HC.modules and HC.modules.availability or nil;
    if a and a.mission then
        local ok,r=pcall(a.mission,s.id,m[2],{name=m[3],type=m[4]});
        if ok and type(r)=='table' and r.state=='FUTURE' then return 'FUTURE | '..typ,r; end
    end
    return typ,nil;
end

local function draw_row_fallback(imgui,c,s,m)
    local k=key_for(m[2],m[3]);
    local v={c.missions[s.id][k]==true};
    if imgui.Checkbox('##mission_'..s.id..'_'..k,v) then
        set_manual_checked(c,s.id,k,v[1]);
    end
    imgui.SameLine();
    local dtype=mission_display_type(s,m);
    imgui.Text(string.format('%-9s | %-7s | %-36s | %-24s | %s',
        tostring(m[1] or ''),tostring(m[2] or ''),tostring(m[3] or ''),
        tostring(dtype or ''),tostring(m[5] or '')));
end

local function draw_series_table(imgui,c,s)
    local table_supported=(imgui.BeginTable~=nil and imgui.TableSetupColumn~=nil
        and imgui.TableHeadersRow~=nil and imgui.TableNextRow~=nil
        and imgui.TableSetColumnIndex~=nil and imgui.EndTable~=nil);

    local table_flags=0;
    -- ImGuiTableFlags_BordersInnerH = 64, BordersOuterH = 128,
    -- BordersInnerV = 512. Numeric flags avoid depending on enum globals
    -- that differ between Ashita ImGui bindings.
    table_flags=64+128+512;

    if table_supported and imgui.BeginTable('##mission_table_'..s.id,6,table_flags) then
        imgui.TableSetupColumn('Done');
        imgui.TableSetupColumn(s.group_label or 'Group');
        imgui.TableSetupColumn('Number');
        imgui.TableSetupColumn('Mission Name');
        imgui.TableSetupColumn('Type');
        imgui.TableSetupColumn('Reward / Info');
        imgui.TableHeadersRow();

        for _,m in ipairs(s.missions) do
            local k=key_for(m[2],m[3]);
            local is_done=(c.missions[s.id][k]==true);
            if not (type(c.settings)=='table' and c.settings.hide_completed_missions==true and is_done) then
            local v={is_done};
            imgui.TableNextRow();

            imgui.TableSetColumnIndex(0);
            if imgui.Checkbox('##mission_'..s.id..'_'..k,v) then
                set_manual_checked(c,s.id,k,v[1]);
            end
            imgui.TableSetColumnIndex(1); imgui.Text(tostring(m[1] or ''));
            imgui.TableSetColumnIndex(2); imgui.Text(tostring(m[2] or ''));
            imgui.TableSetColumnIndex(3); imgui.Text(tostring(m[3] or ''));
            imgui.TableSetColumnIndex(4);
            local dtype,availability=mission_display_type(s,m);
            if availability and availability.state=='FUTURE' then
                imgui.TextDisabled(tostring(dtype));
                if imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then imgui.SetTooltip(tostring(availability.reason or 'Future HorizonXI content.')); end
            else imgui.Text(tostring(dtype)); end
            imgui.TableSetColumnIndex(5); imgui.TextWrapped(tostring(m[5] or ''));
            end
        end
        imgui.EndTable();
    else
        imgui.TextDisabled(string.format('%-4s %-9s | %-7s | %-36s | %-16s | %s',
            'Done',s.group_label or 'Group','Number','Mission Name','Type','Reward / Info'));
        imgui.Separator();
        local shown=0;
        for _,m in ipairs(s.missions) do
            local k=key_for(m[2],m[3]);
            local is_done=(c.missions[s.id][k]==true);
            if not (type(c.settings)=='table' and c.settings.hide_completed_missions==true and is_done) then
                if shown>0 then imgui.Separator(); end
                draw_row_fallback(imgui,c,s,m);
                shown=shown+1;
            end
        end
        if shown==0 then imgui.TextDisabled('All missions in this section are complete.'); end
    end
end


local nation_ids={
    [0]='sandoria',
    [1]='bastok',
    [2]='windurst',
};

-- Missions that are guaranteed by having reached a given nation rank.
-- We deliberately do NOT mark optional/repeatable rank-point missions.
local nation_required_by_rank={
    [2]={'1-3'},
    [3]={'2-3'},
    [4]={'3-3'},
    [5]={'4-1'},
    [6]={'5-1','5-2'},
    [7]={'6-1','6-2'},
    [8]={'7-1','7-2'},
    [9]={'8-1','8-2'},
    [10]={'9-1','9-2'},
};

local function find_series(id)
    for _,s in ipairs(series) do
        if s.id==id then return s; end
    end
    return nil;
end

local function find_mission_key_by_number(s,number)
    if not s then return nil,nil; end
    for _,m in ipairs(s.missions) do
        if tostring(m[2])==tostring(number) then
            return key_for(m[2],m[3]),m;
        end
    end
    return nil,nil;
end

ensure_meta = function(c)
    c.mission_meta=type(c.mission_meta)=='table' and c.mission_meta or {};
    c.mission_meta.sources=type(c.mission_meta.sources)=='table' and c.mission_meta.sources or {};
    c.mission_meta.sync=type(c.mission_meta.sync)=='table' and c.mission_meta.sync or {};
    c.mission_meta.nation_ranks=type(c.mission_meta.nation_ranks)=='table' and c.mission_meta.nation_ranks or {};
    for _,sid in ipairs({'sandoria','bastok','windurst'}) do
        local r=tonumber(c.mission_meta.nation_ranks[sid]);
        if r~=nil then
            c.mission_meta.nation_ranks[sid]=math.max(1,math.min(10,math.floor(r)));
        end
    end
    return c.mission_meta;
end

local function current_nation_rank()
    local nation=nil;
    local rank=nil;
    local ok=pcall(function()
        if not AshitaCore or not AshitaCore.GetMemoryManager then return; end
        local mm=AshitaCore:GetMemoryManager();
        if not mm or not mm.GetPlayer then return; end
        local p=mm:GetPlayer();
        if not p then return; end

        if p.GetNation then
            nation=tonumber(p:GetNation());
        elseif p.GetNationId then
            nation=tonumber(p:GetNationId());
        end

        if p.GetRank then
            rank=tonumber(p:GetRank());
        elseif p.GetNationRank then
            rank=tonumber(p:GetNationRank());
        end
    end);
    if not ok then return nil,nil; end
    return nation,rank;
end

source_key = function(series_id,mission_key)
    return tostring(series_id)..':'..tostring(mission_key);
end

local function mark_synced(c,series_id,mission_key,source)
    ensure(c);
    local meta=ensure_meta(c);
    if c.missions[series_id][mission_key]~=true then
        c.missions[series_id][mission_key]=true;
    end
    meta.sources[source_key(series_id,mission_key)]={
        source=source,
        at=os.time(),
    };
end


local nation_names={
    sandoria="San d'Oria",
    bastok='Bastok',
    windurst='Windurst',
};

local function set_historical_rank(c,sid,rank,source)
    local meta=ensure_meta(c);
    rank=math.max(1,math.min(10,math.floor(tonumber(rank) or 1)));
    local old=tonumber(meta.nation_ranks[sid]) or 0;

    -- Automatic observations never lower known historical progress.
    if source=='OBSERVED CURRENT NATION' then
        if rank>old then meta.nation_ranks[sid]=rank; end
    else
        meta.nation_ranks[sid]=rank;
    end
    meta.sync.rank_source=type(meta.sync.rank_source)=='table' and meta.sync.rank_source or {};
    meta.sync.rank_source[sid]=source or 'MANUAL HISTORY';
    meta.sync.rank_source_at=type(meta.sync.rank_source_at)=='table' and meta.sync.rank_source_at or {};
    meta.sync.rank_source_at[sid]=os.time();
end

local function backfill_nation_rank(c,sid,rank,source)
    local s=find_series(sid);
    if not s then return 0; end
    rank=math.max(1,math.min(10,math.floor(tonumber(rank) or 1)));
    local added=0;

    -- Rank N proves every mandatory gate needed to reach ranks 2..N.
    for achieved=2,rank do
        for _,number in ipairs(nation_required_by_rank[achieved] or {}) do
            local k=find_mission_key_by_number(s,number);
            if k then
                if c.missions[sid][k]~=true then added=added+1; end
                mark_synced(c,sid,k,source or ('HISTORICAL '..string.upper(sid)..' RANK '..tostring(rank)));
            end
        end
    end
    return added;
end

local function backfill_all_saved_nations(c)
    ensure(c);
    local meta=ensure_meta(c);
    local added=0;
    local parts={};

    for _,sid in ipairs({'sandoria','bastok','windurst'}) do
        local rank=tonumber(meta.nation_ranks[sid]);
        if rank then
            local n=backfill_nation_rank(
                c,sid,rank,
                'HISTORICAL '..string.upper(sid)..' RANK '..tostring(rank)
            );
            added=added+n;
            parts[#parts+1]=string.format('%s R%d +%d',nation_names[sid] or sid,rank,n);
        end
    end
    return added,parts;
end

function M.set_all_nations_rank10(c)
    local ok,err=pcall(function()
        ensure(c);
        for _,sid in ipairs({'sandoria','bastok','windurst'}) do
            set_historical_rank(c,sid,10,'MANUAL ALL NATIONS RANK 10');
        end
        local added,parts=backfill_all_saved_nations(c);
        local meta=ensure_meta(c);
        meta.sync.last_at=os.time();
        meta.sync.last_added=added;
        meta.sync.last_message='All nation histories set to Rank 10; '..tostring(added)..' mandatory mission checkbox(es) added.';
        HC.modules.state.save();
        HC.msg('Mission Sync: '..meta.sync.last_message);
    end);
    if not ok then
        HC.msg('Mission Sync error: '..tostring(err));
        return false;
    end
    return true;
end

local function adjust_historical_rank(c,sid,delta)
    local meta=ensure_meta(c);
    local cur=tonumber(meta.nation_ranks[sid]) or 1;
    local next_rank=math.max(1,math.min(10,cur+(tonumber(delta) or 0)));
    set_historical_rank(c,sid,next_rank,'MANUAL HISTORY');
    local added=backfill_nation_rank(c,sid,next_rank,'HISTORICAL '..string.upper(sid)..' RANK '..tostring(next_rank));
    meta.sync.last_at=os.time();
    meta.sync.last_added=added;
    meta.sync.last_message=string.format('%s historical rank set to %d; %d mandatory mission checkbox(es) added.',
        nation_names[sid] or sid,next_rank,added);
    HC.modules.state.save();
end

function M.sync(c,opts)
    opts=type(opts)=='table' and opts or {};
    local ok,err=pcall(function()
        ensure(c);
        local meta=ensure_meta(c);
        local nation,rank=current_nation_rank();

        meta.sync.last_at=os.time();
        meta.sync.last_nation=nation;
        meta.sync.last_rank=rank;
        meta.sync.last_added=0;
        meta.sync.last_message=nil;

        local observed_sid=nation_ids[nation];
        if observed_sid and rank and rank>=1 and rank<=10 then
            set_historical_rank(c,observed_sid,rank,'OBSERVED CURRENT NATION');
        end

        local added,parts=backfill_all_saved_nations(c);
        meta.sync.last_added=added;

        if observed_sid and rank then
            meta.sync.last_message=string.format(
                'Observed %s Rank %d; synced saved nation history. %d mandatory mission checkbox(es) added.',
                nation_names[observed_sid] or observed_sid,rank,added
            );
        elseif #parts>0 then
            meta.sync.last_message=string.format(
                'Current nation/rank unavailable; synced saved nation history. %d mandatory mission checkbox(es) added.',
                added
            );
        else
            meta.sync.last_message='No nation-rank history is known yet; no mission boxes changed.';
        end

        if opts.deferred and HC.modules.state.request_save then HC.modules.state.request_save(1); else HC.modules.state.save(); end
        if HC.modules.dependencies and HC.modules.dependencies.invalidate then HC.modules.dependencies.invalidate('missions','mission synchronization'); end
        if not opts.silent then HC.msg('Mission Sync: '..meta.sync.last_message); end
    end);

    if not ok then
        if not opts.silent then HC.msg('Mission Sync error: '..tostring(err)); end
        return 0;
    end
    return 1;
end



local allegiance_name_to_sid={
    ["san d'oria"]='sandoria',
    ['bastok']='bastok',
    ['windurst']='windurst',
};

local function normalize_chat_text(s)
    return tostring(s or ''):lower():gsub('%s+',' ');
end

local function on_allegiance_text(s)
    local low=normalize_chat_text(s);
    if low=='' then return; end
    local c=HC.modules.state.get_char();
    if not c then return; end
    ensure(c);
    local meta=ensure_meta(c);

    -- Nation transfer NPCs explicitly report the historical rank that will be
    -- retained for the destination nation.  This is authoritative historical
    -- evidence and must never erase progress stored for the other nations.
    local nation_name,rank_text=low:match("retain your current rank in ([^,]+), which is presently rank (%d+)")
    local sid=nation_name and allegiance_name_to_sid[nation_name] or nil;
    local rank=tonumber(rank_text);
    if sid and rank and rank>=1 and rank<=10 then
        local old=tonumber(meta.nation_ranks[sid]) or 0;
        -- Never lower historical progress from transfer dialogue.
        if rank>old then
            set_historical_rank(c,sid,rank,'ALLEGIANCE NPC VERIFIED');
        else
            meta.sync.rank_source=type(meta.sync.rank_source)=='table' and meta.sync.rank_source or {};
            meta.sync.rank_source[sid]='ALLEGIANCE NPC VERIFIED';
            meta.sync.rank_source_at=type(meta.sync.rank_source_at)=='table' and meta.sync.rank_source_at or {};
            meta.sync.rank_source_at[sid]=os.time();
        end
        local added=backfill_nation_rank(c,sid,rank,'ALLEGIANCE NPC VERIFIED RANK '..tostring(rank));
        meta.sync.last_at=os.time();
        meta.sync.last_added=added;
        meta.sync.last_message=string.format('%s historical Rank %d verified by allegiance NPC; %d mandatory mission checkbox(es) added.',nation_names[sid] or sid,rank,added);
        HC.modules.state.save();
        HC.msg('Mission Sync: '..meta.sync.last_message);
        return;
    end

    -- Final citizenship message is the authoritative point at which the
    -- character's current allegiance changes.  Store it immediately so the UI
    -- does not need to wait for a reload/zone, while preserving every nation's
    -- independent historical mission data.
    local citizen_name=low:match("you are now a citizen of ([^!]+)!")
    sid=citizen_name and allegiance_name_to_sid[citizen_name] or nil;
    if sid then
        local old_sid=meta.current_nation_sid;
        -- Reset only the active Conquest/Outpost verification view when the
        -- allegiance truly changes. Preserve the previous nation's snapshot.
        if old_sid~=sid and HC.modules.outposts and HC.modules.outposts.on_nation_changed then
            HC.modules.outposts.on_nation_changed(c,old_sid,sid);
        end
        meta.current_nation_sid=sid;
        meta.current_nation_source='CITIZENSHIP MESSAGE VERIFIED';
        meta.current_nation_at=os.time();
        meta.sync.last_nation=nation_ids and ({sandoria=0,bastok=1,windurst=2})[sid] or meta.sync.last_nation;
        HC.modules.state.save();
        HC.msg('Mission Sync: Current nation updated to '..(nation_names[sid] or sid)..'; saved mission history for all nations preserved.');
    end
end

local function mission_source(c,sid,k)
    local meta=ensure_meta(c);
    return meta.sources[source_key(sid,k)];
end



local function u16le(s,pos)
    if type(s)~='string' or #s<(pos+1) then return nil; end
    local a,b=s:byte(pos,pos+1); return a+(b*256);
end

local function u32le(s,pos)
    if type(s)~='string' or #s<(pos+3) then return nil; end
    local a,b,c,d=s:byte(pos,pos+3);
    return a+(b*256)+(c*65536)+(d*16777216);
end

local function decode_ffff_diagnostic(data)
    if type(data)~='string' or #data<38 then return nil; end
    return {
        nation=u32le(data,5),
        current_nation=u32le(data,9),
        current_roz=u32le(data,13),
        current_cop=u32le(data,17),
        unknown1=u32le(data,21),
        current_acp=(data:byte(25) or 0)%16,
        current_mkd=math.floor((data:byte(25) or 0)/16),
        current_asa=(data:byte(26) or 0)%16,
        current_soa=u32le(data,29),
        current_rov=u32le(data,33),
    };
end

local function mission_packet_payload(data)
    -- Ashita packet buffers include the 4-byte FFXI packet header.
    -- For incoming 0x056 the 32-byte variant payload is bytes 5..36 and
    -- the uint16 Type field is bytes 37..38.
    if type(data)~='string' or #data<38 then return nil,nil; end
    local typ=u16le(data,37);
    return typ,5;
end

local function bit_is_set(data,byte_pos,bit_index)
    local b=data:byte(byte_pos);
    if not b then return false; end
    local mask=2^(bit_index%8);
    return (b % (mask*2)) >= mask;
end

local function payload_bit(data,payload_start,field_offset,mission_id)
    if type(mission_id)~='number' or mission_id<0 then return false; end
    local byte_pos=payload_start+field_offset+math.floor(mission_id/8);
    return bit_is_set(data,byte_pos,mission_id%8);
end

local native_ids={
    -- Nation DAT mission IDs. The 2-3 mission has several branch IDs in the
    -- client DAT; the umbrella mission itself is ID 5, which is sufficient
    -- for HorizonCheck's single 2-3 row.
    sandoria={
        ['1-1']=0,['1-2']=1,['1-3']=2,
        ['2-1']=3,['2-2']=4,['2-3']=5,
        ['3-1']=10,['3-2']=11,['3-3']=12,
        ['4-1']=13,
        ['5-1']=14,['5-2']=15,
        ['6-1']=16,['6-2']=17,
        ['7-1']=18,['7-2']=19,
        ['8-1']=20,['8-2']=21,
        ['9-1']=22,['9-2']=23,
    },
    bastok={
        ['1-1']=0,['1-2']=1,['1-3']=2,
        ['2-1']=3,['2-2']=4,['2-3']=5,
        ['3-1']=10,['3-2']=11,['3-3']=12,
        ['4-1']=13,
        ['5-1']=14,['5-2']=15,
        ['6-1']=16,['6-2']=17,
        ['7-1']=18,['7-2']=19,
        ['8-1']=20,['8-2']=21,
        ['9-1']=22,['9-2']=23,
    },
    windurst={
        ['1-1']=0,['1-2']=1,['1-3']=2,
        ['2-1']=3,['2-2']=4,['2-3']=5,
        ['3-1']=10,['3-2']=11,['3-3']=12,
        ['4-1']=13,
        ['5-1']=14,['5-2']=15,
        ['6-1']=16,['6-2']=17,
        ['7-1']=18,['7-2']=19,
        ['8-1']=20,['8-2']=21,
        ['9-1']=22,['9-2']=23,
    },

    -- HorizonCheck intentionally omits ZM "The Outlands" (DAT ID 2) and
    -- "The Last Verse" (DAT ID 31), so these IDs map exactly to its 17 rows.
    zilart={
        ['1']=0, ['2']=4, ['3']=6, ['4']=8, ['5']=10, ['6']=12,
        ['7']=14, ['8']=16, ['9']=18, ['10']=20, ['11']=22,
        ['12']=23, ['13']=24, ['14']=26, ['15']=27, ['16']=28, ['17']=30,
    },
};

-- CoP is linear and has no completed bitfield. 0xFFFF carries a "current
-- CoP mission" mapping value. These are the values for HorizonCheck's rows.
local cop_progress_ids={
    ['1-1']=110, ['1-2']=118, ['1-3']=128,
    ['2-1']=138, ['2-2']=218, ['2-3']=228, ['2-4']=238, ['2-5']=248,
    ['3-1']=258, ['3-2']=318, ['3-3']=325, ['3-4']=350, ['3-5']=358,
    ['4-1']=368, ['4-2']=418, ['4-3']=428, ['4-4']=438,
    ['5-1']=448, ['5-2']=518, ['5-3']=530,
    ['6-1']=578, ['6-2']=618, ['6-3']=628, ['6-4']=638,
    ['7-1']=648, ['7-2']=718, ['7-3']=728, ['7-4']=738, ['7-5']=748,
    ['8-1']=800, ['8-2']=818, ['8-3']=828, ['8-4']=840, ['8-5']=850,
};

local function native_current_value(c,series_id)
    if type(c)~='table' or type(c.mission_meta)~='table' or type(c.mission_meta.native)~='table' then return nil; end
    local n=c.mission_meta.native;
    series_id=string.lower(tostring(series_id or ''));
    if series_id=='nation' then return tonumber(n.current_nation); end
    if series_id=='zilart' or series_id=='roz' then return tonumber(n.current_roz); end
    if series_id=='cop' or series_id=='promathia' then return tonumber(n.current_cop); end
    return nil;
end

local function native_target_value(series_id,number)
    series_id=string.lower(tostring(series_id or ''));
    local token=tostring(number or '');
    if series_id=='nation' then return tonumber(native_ids.sandoria[token]); end
    if series_id=='zilart' or series_id=='roz' then return tonumber(native_ids.zilart[token]); end
    if series_id=='cop' or series_id=='promathia' then return tonumber(cop_progress_ids[token] or number); end
    return tonumber(number);
end

function M.native_current(series_id)
    local c=HC and HC.modules and HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char() or nil;
    return native_current_value(c,series_id);
end

function M.is_current(series_id,number)
    local current=M.native_current(series_id);
    local target=native_target_value(series_id,number);
    if current==nil or target==nil then return nil; end
    return current==target;
end

function M.progress_at_least(series_id,number)
    local current=M.native_current(series_id);
    local target=native_target_value(series_id,number);
    if current==nil or target==nil then return nil; end
    return current>=target;
end

function M.native_target(series_id,number)
    return native_target_value(series_id,number);
end

local function mark_native_completed(c,sid,key,source,packet_type)
    ensure(c);
    local changed=(c.missions[sid][key]~=true);
    c.missions[sid][key]=true;
    local meta=ensure_meta(c);
    meta.sources[source_key(sid,key)]={
        source=source or 'NATIVE COMPLETED MISSIONS',
        at=os.time(),
        automatic=true,
        packet=packet_type or '0x056',
    };
    return changed and 1 or 0;
end

local function apply_bitfield_series(c,data,payload_start,sid,field_offset,id_map,source,packet_type)
    local s=find_series(sid);
    if not s then return 0; end
    local changed=0;
    for _,mission in ipairs(s.missions) do
        local number=tostring(mission[2] or '');
        local mission_id=id_map[number];
        if mission_id~=nil and payload_bit(data,payload_start,field_offset,mission_id) then
            changed=changed+mark_native_completed(
                c,sid,key_for(mission[2],mission[3]),source,packet_type
            );
        end
    end
    return changed;
end

local function apply_native_d0(c,data,payload_start)
    local changed=0;
    changed=changed+apply_bitfield_series(
        c,data,payload_start,'sandoria',0,native_ids.sandoria,
        'NATIVE COMPLETED MISSIONS','0x056/0x00D0'
    );
    changed=changed+apply_bitfield_series(
        c,data,payload_start,'bastok',8,native_ids.bastok,
        'NATIVE COMPLETED MISSIONS','0x056/0x00D0'
    );
    changed=changed+apply_bitfield_series(
        c,data,payload_start,'windurst',16,native_ids.windurst,
        'NATIVE COMPLETED MISSIONS','0x056/0x00D0'
    );
    changed=changed+apply_bitfield_series(
        c,data,payload_start,'zilart',24,native_ids.zilart,
        'NATIVE COMPLETED MISSIONS','0x056/0x00D0'
    );
    return changed;
end

local function apply_native_d8(c,data,payload_start)
    local s=find_series('toau');
    if not s then return 0; end
    local changed=0;

    -- Completed ToAU Missions occupies the first 8 bytes of 0x00D8.
    -- ToAU story mission IDs are 0..47 in the same order as HorizonCheck rows.
    for index,mission in ipairs(s.missions) do
        local mission_id=index-1;
        if payload_bit(data,payload_start,0,mission_id) then
            changed=changed+mark_native_completed(
                c,'toau',key_for(mission[2],mission[3]),
                'NATIVE COMPLETED MISSIONS','0x056/0x00D8'
            );
        end
    end
    return changed;
end

local function apply_native_ffff(c,data,payload_start)
    if type(data)~='string' or #data<38 then return 0; end

    -- 0xFFFF layout:
    -- +0x04 Nation (u32)
    -- +0x08 Current Nation Mission (u32)
    -- +0x0C Current ROZ Mission (u32)
    -- +0x10 Current COP Mission (u32)
    local nation=u32le(data,payload_start);
    local current_nation=u32le(data,payload_start+4);
    local current_roz=u32le(data,payload_start+8);
    local current_cop=u32le(data,payload_start+12);

    local meta=ensure_meta(c);
    meta.native=type(meta.native)=='table' and meta.native or {};
    meta.native.current_seen_at=os.time();
    meta.native.nation=nation;
    meta.native.current_nation=current_nation;
    meta.native.current_roz=current_roz;
    meta.native.current_cop=current_cop;

    local changed=0;

    -- CoP is linear: every HorizonCheck CoP row whose progression ID is below
    -- the current server value is necessarily complete. The row equal to the
    -- current value remains unchecked because it is active, not completed.
    if current_cop and current_cop>0 then
        local s=find_series('cop');
        if s then
            for _,mission in ipairs(s.missions) do
                local number=tostring(mission[2] or '');
                local id=cop_progress_ids[number];
                -- The Last Verse (CoP 8-5 / ZM18) is a permanent conclusion
                -- sentinel: after Apocalypse Nigh it remains the current mission
                -- indefinitely. Therefore equality means complete for 8-5 only.
                local complete=(id and id<current_cop) or
                    (number=='8-5' and id and id==current_cop);
                if complete then
                    changed=changed+mark_native_completed(
                        c,'cop',key_for(mission[2],mission[3]),
                        number=='8-5' and 'NATIVE FINAL SENTINEL' or 'NATIVE PROGRESSION INFERRED',
                        '0x056/0xFFFF'
                    );
                end
            end
        end
    end

    return changed;
end

local function apply_native_mission_packet(c,data)
    local typ,payload_start=mission_packet_payload(data);
    if not typ then return 0,nil; end

    local changed=0;
    if typ==0x00D0 then
        changed=apply_native_d0(c,data,payload_start);
    elseif typ==0x00D8 then
        changed=apply_native_d8(c,data,payload_start);
    elseif typ==0xFFFF then
        changed=apply_native_ffff(c,data,payload_start);
    else
        return 0,typ;
    end

    local meta=ensure_meta(c);
    meta.native=type(meta.native)=='table' and meta.native or {};
    meta.native.last_seen_at=os.time();
    meta.native.last_type=string.format('0x%04X',typ);
    meta.native.last_added=changed;
    meta.native.decoder='v4';
    HC.modules.state.save();
    if HC.modules.dependencies and HC.modules.dependencies.invalidate then HC.modules.dependencies.invalidate('missions','native 0x056 mission history received'); end
    return changed,typ;
end

function M.init(ctx)
    HC=ctx;
    if HC.modules.packets and HC.modules.packets.register_text then
        HC.modules.packets.register_text('missions allegiance history',on_allegiance_text);
    end
    if HC.modules.packets and HC.modules.packets.register then
        HC.modules.packets.register(0x056,'missions_native_056',function(e)
            local data=e and (e.data or e.data_raw);
            if type(data)~='string' then return; end

            local typ=mission_packet_payload(data);
            if mission_capture.active then
                mission_capture.packets=mission_capture.packets+1;
                local key=typ and string.format('0x%04X',typ) or 'UNKNOWN';
                mission_capture.types[key]=(mission_capture.types[key] or 0)+1;
                local h3,h4,seq=packet_sequence(data);
                local page=page_marker(data);
                local pagekey=page and string.format('0x%02X',page) or 'NONE';
                mission_capture.pages[pagekey]=(mission_capture.pages[pagekey] or 0)+1;

                capture_write(string.format(
                    '[%s] #%02d PACKET 0x056 | size=%d | typeCandidate=%s | hdr3=%s hdr4=%s | seqCandidate=%s | page37=%s | storyline=%s',
                    os.date('%H:%M:%S'),mission_capture.packets,#data,key,
                    h3 and string.format('0x%02X',h3) or 'nil',
                    h4 and string.format('0x%02X',h4) or 'nil',
                    tostring(seq),pagekey,tostring(mission_capture.selected_story or '-')
                ));
                capture_write('HEAD 01-40 | '..hex_range(data,1,40));
                capture_write('NONZERO 05-40 | '..nonzero_map(data,5,40));

                if mission_capture.last_data then
                    local diffs={};
                    local lim=math.min(40,#data,#mission_capture.last_data);
                    for i=5,lim do
                        local a=mission_capture.last_data:byte(i);
                        local b=data:byte(i);
                        if a~=b then diffs[#diffs+1]=string.format('%02d:%02X>%02X',i,a or 0,b or 0); end
                    end
                    capture_write('DELTA PREV 05-40 | '..(#diffs>0 and table.concat(diffs,' ') or '(none)'));
                else
                    capture_write('DELTA PREV 05-40 | (first packet)');
                end

                if typ==0xFFFF then
                    local d=decode_ffff_diagnostic(data);
                    if d then
                        capture_write(string.format(
                            'DECODE FFFF | Nation=%s | CurrentNation=%s | ROZ=%s | COP=%s | ACP=%s | MKD=%s | ASA=%s | SOA=%s | ROV=%s | Unknown1=%s',
                            tostring(d.nation),tostring(d.current_nation),tostring(d.current_roz),
                            tostring(d.current_cop),tostring(d.current_acp),tostring(d.current_mkd),
                            tostring(d.current_asa),tostring(d.current_soa),tostring(d.current_rov),
                            tostring(d.unknown1)
                        ));
                    end
                end
                capture_write('HEX '..hex_bytes(data));
                capture_write('');
                mission_capture.last_data=data;
            end

            local c=HC.modules.state.get_char();
            local added,native_type=apply_native_mission_packet(c,data);
            if added>0 then
                local noun=(added==1) and 'mission' or 'missions';
                HC.msg('Mission Sync: Updated '..tostring(added)..' completed '..noun..'.');

                local meta=ensure_meta(c);
                meta.native=type(meta.native)=='table' and meta.native or {};
                meta.native.last_chat_update_type=native_type and string.format('0x%04X',native_type) or nil;
                meta.native.last_chat_update_count=added;
                meta.native.last_chat_update_at=os.time();
            end
        end);
    end
end

function M.start_packet_capture()
    if mission_capture.active then return false; end
    mission_capture.active=true;
    mission_capture.started_at=os.time();
    mission_capture.file=capture_path();
    mission_capture.packets=0;
    mission_capture.types={};
    mission_capture.pages={};
    mission_capture.last_data=nil;

    capture_write('HorizonCheck Mission Storyline Capture v6.1.73');
    capture_write('Started: '..os.date('%Y-%m-%d %H:%M:%S'));
    capture_write('Storyline: '..tostring(mission_capture.selected_story or 'unlabeled'));
    capture_write('Purpose: capture the full HorizonXI 0x056 zone-in mission dump under a known storyline label.');
    capture_write('Analysis fields: packet index, header/sequence candidate, byte-37 page marker, first 40 bytes, non-zero map, and delta from previous packet.');
    capture_write('No packets are injected or modified.');
    capture_write('');

    HC.msg('Mission Capture STARTED ['..tostring(mission_capture.selected_story or 'unlabeled')..']. Zone once, wait 5-10 seconds, then stop.');
    return true;
end

function M.stop_packet_capture()
    if not mission_capture.active then return nil; end
    local file=mission_capture.file;

    capture_write('SUMMARY');
    capture_write('Storyline: '..tostring(mission_capture.selected_story or 'unlabeled'));
    capture_write('Packets: '..tostring(mission_capture.packets));

    local keys={};
    for k in pairs(mission_capture.types) do keys[#keys+1]=k; end
    table.sort(keys);
    for _,k in ipairs(keys) do
        capture_write(k..' = '..tostring(mission_capture.types[k]));
    end

    capture_write('PAGE37 MARKERS');
    local pages={};
    for k in pairs(mission_capture.pages) do pages[#pages+1]=k; end
    table.sort(pages);
    for _,k in ipairs(pages) do
        capture_write(k..' = '..tostring(mission_capture.pages[k]));
    end

    capture_write('Stopped: '..os.date('%Y-%m-%d %H:%M:%S'));
    mission_capture.active=false;
    mission_capture.file=nil;
    HC.msg('Mission Capture STOPPED: '..tostring(file));
    return file;
end


local function active_nation_sid(c)
    local meta=ensure_meta(c);
    if meta.current_nation_sid and find_series(meta.current_nation_sid) then return meta.current_nation_sid; end
    local nation=current_nation_rank();
    local sid=nation_ids[tonumber(nation)];
    if sid then return sid; end
    local native=type(meta.native)=='table' and meta.native or {};
    return nation_ids[tonumber(native.nation)];
end

local function mission_availability(s,m)
    local av=HC and HC.modules and HC.modules.availability or nil;
    if av and av.mission then
        local ok,r=pcall(av.mission,s.id,m[2],{name=m[3],type=m[4]});
        if ok and type(r)=='table' then return r; end
    end
    return {state='AVAILABLE',reason='Mission catalog entry'};
end

local function exact_current_index(c,s)
    if not s then return nil; end
    local current=nil;
    if s.id=='sandoria' or s.id=='bastok' or s.id=='windurst' then
        if active_nation_sid(c)~=s.id then return nil; end
        current=native_current_value(c,'nation');
        if current==nil then return nil; end
        for i,m in ipairs(s.missions) do
            local target=native_ids[s.id] and native_ids[s.id][tostring(m[2] or '')] or nil;
            if target~=nil and tonumber(target)==tonumber(current) and c.missions[s.id][key_for(m[2],m[3])]~=true then return i; end
        end
    elseif s.id=='zilart' then
        current=native_current_value(c,'zilart');
        if current==nil then return nil; end
        for i,m in ipairs(s.missions) do
            local target=native_ids.zilart[tostring(m[2] or '')];
            if target~=nil and tonumber(target)==tonumber(current) and c.missions[s.id][key_for(m[2],m[3])]~=true then return i; end
        end
    elseif s.id=='cop' then
        current=native_current_value(c,'cop');
        if current==nil then return nil; end
        for i,m in ipairs(s.missions) do
            local target=cop_progress_ids[tostring(m[2] or '')];
            if target~=nil and tonumber(target)==tonumber(current) and c.missions[s.id][key_for(m[2],m[3])]~=true then return i; end
        end
    end
    return nil;
end

local function first_actionable_incomplete_index(c,s,start_at)
    start_at=math.max(1,tonumber(start_at) or 1);
    for i=start_at,#(s.missions or {}) do
        local m=s.missions[i]; local k=key_for(m[2],m[3]);
        if c.missions[s.id][k]~=true then
            local a=mission_availability(s,m);
            if tostring(a.state or '')~='FUTURE' and tostring(a.state or '')~='DISABLED' then return i; end
        end
    end
    return nil;
end

local function series_progress_state(c,s)
    local exact=exact_current_index(c,s);
    local is_nation=(s.id=='sandoria' or s.id=='bastok' or s.id=='windurst');
    -- Nation mission history contains optional/repeatable rank-point missions,
    -- so first-unchecked is not safe as a current-mission fallback. Require the
    -- native current pointer for the active nation instead of sending a Rank 10
    -- character back to an old optional 1-x row. Linear story series can safely
    -- fall back to the first actionable incomplete row.
    local first=(not is_nation) and first_actionable_incomplete_index(c,s,1) or nil;
    local current=exact or first;
    local next_idx=current and first_actionable_incomplete_index(c,s,current+1) or nil;
    return current,next_idx,exact~=nil;
end

-- Player-facing mission intelligence. This deliberately reports only facts the
-- current HorizonCheck mission catalog/native packet data can support: current
-- or next mission, type, reward/unlock text, and Horizon availability. It does
-- not invent NPC/zone steps that are not present in the mission catalog.
function M.current_progress(c)
    c=type(c)=='table' and c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    ensure(c);
    local ids={}; local nation=active_nation_sid(c); if nation then ids[#ids+1]=nation; end
    ids[#ids+1]='zilart'; ids[#ids+1]='cop'; ids[#ids+1]='toau';
    local out={};
    for _,sid in ipairs(ids) do
        local ss=find_series(sid);
        if ss then
            local current_idx,next_idx,native_exact=series_progress_state(c,ss);
            local current=current_idx and ss.missions[current_idx] or nil;
            local nextm=next_idx and ss.missions[next_idx] or nil;
            local done=count_done(c,ss);
            local rec={
                series_id=sid,series_name=ss.name,done=done,total=#ss.missions,
                current=current and {number=current[2],name=current[3],type=current[4],reward=current[5],key=key_for(current[2],current[3]),index=current_idx} or nil,
                next=nextm and {number=nextm[2],name=nextm[3],type=nextm[4],reward=nextm[5],key=key_for(nextm[2],nextm[3]),index=next_idx} or nil,
                native_current=native_exact,
            };
            if current then
                local a=mission_availability(ss,current); rec.availability=a.state; rec.availability_reason=a.reason;
                rec.state=native_exact and 'CURRENT' or 'NEXT';
            elseif (sid=='sandoria' or sid=='bastok' or sid=='windurst') and done<#ss.missions then
                rec.state='VERIFY'; rec.availability='AVAILABLE'; rec.verify_reason='Current nation mission pointer has not been synchronized yet';
            else
                rec.state='COMPLETE'; rec.availability='AVAILABLE';
            end
            out[#out+1]=rec;
        end
    end
    return out;
end

function M.series_state(c,series_id)
    c=type(c)=='table' and c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    ensure(c); local ss=find_series(series_id); if not ss then return nil; end
    local current_idx,next_idx,native_exact=series_progress_state(c,ss);
    return {current_index=current_idx,next_index=next_idx,native_current=native_exact,active_nation=(active_nation_sid(c)==ss.id)};
end

function M.catalog_entries(c)
    if type(c)=='table' then ensure(c); end
    local out={};
    for _,s in ipairs(series) do
        for _,m in ipairs(s.missions) do
            local k=key_for(m[2],m[3]);
            out[#out+1]={series_id=s.id,series_name=s.name,group=m[1],number=m[2],name=m[3],type=m[4],reward=m[5],key=k,completed=(type(c)=='table' and c.missions and c.missions[s.id] and c.missions[s.id][k]==true) or false};
        end
    end
    return out;
end

local function wiki_title_slug(title)
    if title==nil or tostring(title)=='' then return nil; end
    local slug=tostring(title):gsub(' ','_');
    -- Keep the browser command shell-safe by percent-encoding punctuation in
    -- the MediaWiki title. This matches the established quest/wiki launcher.
    slug=slug:gsub('([^%w%-%._~])',function(ch) return string.format('%%%02X',string.byte(ch)); end);
    return slug;
end

local function mission_wiki_title(row)
    if type(row)~='table' or type(row.current)~='table' then return nil; end
    local sid=tostring(row.series_id or '');
    local num=tostring(row.current.number or '');
    if num=='' then return nil; end
    -- Nation mission names can collide with zone/article names (for example
    -- Full Moon Fountain), so use the canonical numbered mission page. The
    -- expansion wikis likewise expose stable numbered Zilart/Promathia pages.
    if sid=='sandoria' then return "San d'Oria Mission "..num; end
    if sid=='bastok' then return 'Bastok Mission '..num; end
    if sid=='windurst' then return 'Windurst Mission '..num; end
    if sid=='zilart' then return 'Zilart Mission '..num; end
    if sid=='cop' then return 'Promathia Mission '..num; end
    -- ToAU pages are primarily keyed by their mission title on HorizonXI Wiki.
    -- A couple of ambiguous article names use an explicit mission-qualified page.
    if sid=='toau' then
        if num=='16' then return 'Aht Urhgan Mission 16: Ghosts of the Past'; end
        if num=='45' then return 'Aht Urhgan Mission 45: Ragnarok'; end
        return tostring(row.current.name or '');
    end
    return tostring(row.current.name or '');
end

local function mission_wiki_url(row)
    local slug=wiki_title_slug(mission_wiki_title(row));
    if not slug then return nil; end
    return 'https://horizonffxi.wiki/'..slug;
end

local function open_mission_wiki(row)
    local url=mission_wiki_url(row);
    if not url then return false; end
    -- HorizonXI/Ashita runs on Windows; start opens the player's default browser.
    local ok=pcall(function() os.execute('cmd /c start "" "'..url..'"'); end);
    return ok;
end

local function draw_current_mission_cell(imgui,row,id_suffix)
    if type(row)=='table' and row.current then
        imgui.Text(tostring(row.current.number or '')..' - '..tostring(row.current.name or ''));
        imgui.SameLine();
        if imgui.SmallButton('GO##mission_story_wiki_'..tostring(id_suffix or row.series_id or 'row')) then
            open_mission_wiki(row);
        end
        if imgui.IsItemHovered~=nil and imgui.IsItemHovered() then
            imgui.SetTooltip('Open this mission guide on HorizonXI Wiki.');
        end
    elseif type(row)=='table' and row.state=='VERIFY' then
        imgui.TextDisabled('Zone once to synchronize current mission');
    else
        imgui.TextDisabled('Current Horizon content complete');
    end
end

function M.draw(c)
    local imgui=HC.imgui; if not imgui then return; end
    ensure(c);

    local meta=ensure_meta(c);
    local native=type(meta.native)=='table' and meta.native or {};

    if HC.modules.uikit then HC.modules.uikit.section_header('Mission Progress','[CHARACTER]'); else imgui.TextDisabled('[CHARACTER] Mission progress'); end
    c.settings=type(c.settings)=='table' and c.settings or {};
    local hide_completed={c.settings.hide_completed_missions==true};
    if imgui.Checkbox('Hide completed missions##mission_hide_completed',hide_completed) then
        c.settings.hide_completed_missions=hide_completed[1];
        HC.modules.state.save();
    end
    local focus=(HC.modules.ui and HC.modules.ui.consume_focus) and HC.modules.ui.consume_focus('missions') or nil;
    local focus_series=type(focus)=='table' and tostring(focus.series_id or '') or '';

    -- Action-first story summary: show the current/next mission for the active
    -- nation plus Zilart, CoP, and ToAU. The per-series headers below retain
    -- full historical completion counts, so the old large progress-summary
    -- block is intentionally replaced rather than duplicated.
    local current_rows=M.current_progress(c);
    if HC.modules.uikit then HC.modules.uikit.section_header('Current Story / Next Mission'); else imgui.Text('Current Story / Next Mission'); imgui.Separator(); end
    local shared_rows={};
    for _,r in ipairs(current_rows or {}) do
        -- Capture a per-row local before creating the renderer closure so every
        -- GO button keeps the correct story/mission target.
        local row=r;
        shared_rows[#shared_rows+1]={
            tostring(row.series_name or row.series_id),
            tostring(row.state or 'NEXT'),
            function() draw_current_mission_cell(imgui,row,tostring(row.series_id or '')..'_shared'); end,
            row.current and tostring(row.current.type or '-') or '-',
            row.current and tostring(row.current.reward or '-') or '-',
            row.next and (tostring(row.next.number or '')..' - '..tostring(row.next.name or '')) or '-',
            complete=true,
        };
    end
    local used_shared=false;
    if HC.modules.uikit and HC.modules.uikit.simple_table then
        used_shared=HC.modules.uikit.simple_table('##mission_current_story_v770_shared',
            {{label='Series',width=0.20},{label='State',width=0.11},{label='Current / Next',width=0.27},{label='Type',width=0.12},{label='Reward / Unlock',width=0.22},{label='After',width=0.18}},
            shared_rows,760);
    end
    local table_ok=imgui.BeginTable and imgui.TableSetupColumn and imgui.TableHeadersRow and imgui.TableNextRow and imgui.TableSetColumnIndex and imgui.EndTable;
    local table_flags=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
    if not used_shared and table_ok and imgui.BeginTable('##mission_current_story_v770',6,table_flags) then
        imgui.TableSetupColumn('Series',0,0.20);
        imgui.TableSetupColumn('State',0,0.11);
        imgui.TableSetupColumn('Current / Next',0,0.27);
        imgui.TableSetupColumn('Type',0,0.12);
        imgui.TableSetupColumn('Reward / Unlock',0,0.22);
        imgui.TableSetupColumn('After',0,0.18);
        imgui.TableHeadersRow();
        for _,r in ipairs(current_rows or {}) do
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0); imgui.Text(tostring(r.series_name or r.series_id));
            imgui.TableSetColumnIndex(1); if r.state=='COMPLETE' then imgui.TextDisabled('COMPLETE'); else imgui.Text(tostring(r.state or 'NEXT')); end
            imgui.TableSetColumnIndex(2);
            draw_current_mission_cell(imgui,r,tostring(r.series_id or '')..'_direct');
            imgui.TableSetColumnIndex(3); imgui.TextDisabled(r.current and tostring(r.current.type or '-') or '-');
            imgui.TableSetColumnIndex(4); imgui.TextDisabled(r.current and tostring(r.current.reward or '-') or '-');
            imgui.TableSetColumnIndex(5); imgui.TextDisabled(r.next and (tostring(r.next.number or '')..' - '..tostring(r.next.name or '')) or '-');
        end
        imgui.EndTable();
    elseif not used_shared then
        for _,r in ipairs(current_rows or {}) do
            local cur=r.current and (tostring(r.current.number or '')..' - '..tostring(r.current.name or '')) or ((r.state=='VERIFY') and 'VERIFY CURRENT MISSION' or 'COMPLETE');
            imgui.Text(tostring(r.series_name)..': '..cur);
            if r.current then
                imgui.SameLine();
                if imgui.SmallButton('GO##mission_story_wiki_'..tostring(r.series_id or '')..'_compact') then open_mission_wiki(r); end
                if imgui.IsItemHovered~=nil and imgui.IsItemHovered() then imgui.SetTooltip('Open this mission guide on HorizonXI Wiki.'); end
            end
        end
    end
    imgui.Separator();

    -- Healthy native synchronization is intentionally silent. Only surface
    -- the setup action when the character has not supplied mission history yet.
    if not native.last_seen_at then
        imgui.TextDisabled('Mission history will load after you zone once.');
        imgui.Separator();
    end

    -- Historical rank fallback remains available internally for migration and
    -- legacy saved-state recovery, but authoritative mission sync is now the
    -- normal player-facing path, so the manual Advanced / Historical Sync UI
    -- is intentionally hidden.

    for _,s in ipairs(series) do
        local done=count_done(c,s);
        local flags=(done<#s.missions) and (ImGuiTreeNodeFlags_DefaultOpen or 0) or 0;
        local label=(HC.modules.uikit and HC.modules.uikit.progress_label) and HC.modules.uikit.progress_label(s.name,done,#s.missions)
            or string.format('%s - %d/%d%s',s.name,done,#s.missions,(done>=#s.missions and ' - COMPLETE' or ''));
        if focus_series==s.id and imgui.SetNextItemOpen then pcall(imgui.SetNextItemOpen,true); end
        if imgui.CollapsingHeader(label..'##mission_series_'..s.id, flags)
        then
            draw_series_table(imgui,c,s);
        end
    end
end

return M;
