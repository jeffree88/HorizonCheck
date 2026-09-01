local M={};
local HC;

local Y2023={
    "Heavens Tower basement - by Bebibi",
    "Chateau d'Oraguille (F-7) - Queen's Garden flower bed",
    "Metalworks (G-8) - Cid's room",
    "South Gustaberg (M-10) - bottom of lighthouse",
    "South Gustaberg (M-10) - top of lighthouse",
    "South Gustaberg (I-8) - top of Vomp Hill",
    "North Gustaberg (F-7) - waterfall; enter from Dangruf Wadi (J-3)",
    "West Sarutabaruta (I-6) - Starfall Hillock tree",
    "East Sarutabaruta (F-9) - west side of Lake Tepokalipuka",
    "East Ronfaure (J-11) - bottom of watchtower ladders",
    "West Ronfaure (E-8) - reach through Bostaunieux Oubliette; do not Escape",
    "La Theine Plateau (K-5)",
    "Konschtat Highlands (D-8)",
    "Tahrongi Canyon (F-6) - southwest of Tahrongi Cacti",
    "Buburimu Peninsula (F-6) - rock near Maze of Shakhrami entrance",
    "Valkurm Dunes (B-6) - north side of secret beach",
    "Ship bound for Selbina/Mhaura - very front; pirates must not be present",
    "Rolanberry Fields (E-11) - exit through Crawlers' Nest; hug right wall",
    "Sauromugue Champaign (K-10) - Garlaige Gate 1 -> Gate 3 -> Roc exit -> fort top",
    "Batallia Downs (D-7) - top of hill",
    "Ru'Lude Gardens (H-7) - second-floor balcony opposite Audience Chamber",
    "Qufim Island (F-8) - by BST quest/night flowers",
    "Lower Delkfutt's Tower 1F (E-7) - just past basement door",
    "Stellar Fulcrum (F-10) - behind teleporter after entering",
    "The Sanctuary of Zi'Tah (J-7) - near Keeper of Halidom",
    "The Boyahda Tree Map 2 (I-12) - behind waterfall near Cloister of Storms",
    "Hall of the Gods (H-8) - circular platform before Cermet Grate",
    "Xarcabard (G-10) - outside Boreal Hound cave",
    "Uleguerand Range (F-8) - mountain slide into north/right hole",
    "Attohwa Chasm (J-8) - top of Mount Parradamo Tor",
    "Bastok Markets (F-9) - fountain edge",
    "Jugner Forest (E-6) - north side of Maiden's Spring",
    "Misareaux Coast (G-5) - beneath bridge",
    "Tavnazian Safehold (F-9) - path near river",
    "Beaucedine Glacier (I-5) - west of Fei'Yin entrance",
    "Yhoator Jungle (L-10) - near Teardrop Spring",
    "Cloister of Gales - behind proto-crystal",
    "Lufaise Meadows (J-6) - Blueblade Fell",
};

local Y2024={
    {zone="Xarcabard (I-8)",npc="Tracent + Drowsy",items={
        {name='Royal Jelly',get='Death Jacket in Crawlers\' Nest; also several higher-level bee NMs/mobs. Exclusive, so farm it yourself.'},{name='Lufet Salt',get='River Crab at Knightwell, West Ronfaure (G-10/H-11). Exclusive; cannot be bought/traded.'},{name='Jack-o\'-Lantern',get='Cooking synthesis (Fire Crystal + Ogre Pumpkin + Beeswax) or Auction House.'},{name='Kazham Peppers x12',get='Ghemi Sinterilo, Kazham (G-7), or Culinarians\' Guild in Windurst Waters; buy 12.'},
        {name='Shaman Garlic',get='Auction House; common cooking ingredient from low-level monster/vendor sources.'},{name='Mole Broth',get='Cooking synthesis or Auction House.'},{name='Bloody Chocolate',get='Cooking synthesis or Auction House.'},{name='Wild Cookie x33',get='Goblin-family drops or Auction House; collect 33.'}}},
    {zone="The Boyahda Tree (J-7)",npc="Kipling + Ah Puch",items={
        {name='Ancient Papyrus',get='Lich-family drops in Eldieme Necropolis.'},{name='Smooth Velvet',get='Auction House; clothcraft-related material/drop.'},{name='Silver Obi +1',get='High-quality Clothcraft synthesis of Silver Obi; Auction House if available.'},{name='Raxa',get='High-level cloth material; Auction House or high-level monster/crafting supply.'},
        {name='Phoenix Feather',get='High-level bird/BCNM sources; Auction House.'},{name='Chocobo Bedding',get='Crafted furnishing; Auction House or crafter.'},{name='Luminicloth',get='Ghost/high-level undead source; Auction House.'},{name='Black Chocobo Feather x3',get='Chocobo-related acquisition or Auction House; collect 3.'}}},
    {zone="Yhoator Jungle (H-9)",npc="Kore + Tiberon",items={
        {name='Tahrongi Cactus',get='Harvest/quest item from Tahrongi Canyon.'},{name='Rich Humus',get='Gardening/plant-related source; Auction House.'},{name='Wisteria Lumber',get='Woodworking material; craft from Wisteria Log or Auction House.'},{name='Thunder Staff',get='Crafted elemental staff; Auction House.'},
        {name='Spruce Lumber',get='Woodworking material; Auction House.'},{name='Tenshodo Invite',get='Obtain through the Tenshodo quest line; use a tradable invite item.'},{name='Warp Cudgel',get='Crafted Warp Cudgel or Auction House; any remaining charge count works.'},{name='Commode',get='Woodworking furnishing; craft or Auction House.'}}},
    {zone="Throne Room",npc="Frank + Hookstar",items={
        {name='Lanolin',get='Ram/sheep-family drop; Auction House.'},{name='San d\'Orian Boots',get='San d\'Oria armor vendor or Auction House.'},{name='Feral Gloves',get='Leathercraft armor; Auction House.'},{name='Cuir Highboots +1',get='HQ Leathercraft synthesis of Cuir Highboots; Auction House.'},
        {name='Ram Leather Missive',get='Gigas-related Delkfutt-style source; Auction House if available.'},{name='Powder Boots',get='Crafted/enchantment footwear; Auction House; charge count does not matter.'},{name='Moblin Mask',get='Moblin-related drop/reward; Auction House.'},{name='High-Quality Bugard Skin',get='Higher-level Bugard-family drop; Auction House.'}}},
    {zone="Korroloka Tunnel Map 2 (I-10)",npc="Kanryu + Tangent",items={
        {name='White Memosphere',get='Promyvion Empty-family source; farm in Promyvion.'},{name='Desert Venom',get='Scorpion-family drop in desert areas; Auction House.'},{name='Photoanima',get='Alchemy synthesis from anima materials; Auction House.'},{name='Cactuar Needle',get='Cactuar-family drop in Altepa/desert zones; Auction House.'},
        {name='Demon Pen',get='Demon-family source; Auction House.'},{name='Frog Lure',get='Crafted fishing lure; Auction House.'},{name='Sieglinde Putty',get='Quest/crafting material; Auction House if available.'},{name='Hallowed Water',get='Alchemy synthesis or Auction House.'}}},
    {zone="Ru'Aun Gardens (H-12)",npc="Hugin",items={
        {name='Fat Greedie',get='Fish in Selbina waters.'},{name='Silver Shark',get='Saltwater fishing around Selbina/Mhaura/open-sea routes.'},{name='Giant Donko',get='Freshwater fishing, including desert oasis waters.'},{name='Bluetail',get='Saltwater fishing; common mid-level catch.'},{name='Cave Cherax',get='Fishing in Korroloka Tunnel.'},{name='Drill Calamary',get='Fishing on the Selbina-Mhaura ferry/open-sea route.'},{name='Cheval Salmon',get='Freshwater fishing in Ronfaure/San d\'Oria region.'},{name='Armored Pisces',get='Fishing in cave/quarry waters; commonly associated with mining-tunnel zones.'}}},
    {zone="Beaucedine Glacier (F-7)",npc="Annona",items={
        {name='Shoalweed',get='Coastal/tunnel gathering or fishing-related source; Auction House.'},{name='Bruised Starfruit',get='Harvest/gathering material; Auction House.'},{name='Elm Log',get='Logging or Auction House.'},{name='King Locust',get='Harvesting/insect gathering in field zones; Auction House.'},{name='Red Moko Grass x6',get='Harvesting or Auction House; collect 6.'},{name='Jacknife',get='Fishing in reef/coastal waters; Auction House.'},{name='Tropical Clam',get='Fishing in warm coastal waters; Auction House.'},{name='Dyer\'s Woad',get='Harvesting/gardening dye material; Auction House.'}}},
    {zone="Oldton Movalpolos (K-10)",npc="Beasty + Flam",items={
        {name='Gold Orcmask',get='Higher-rank Orc/NM source; Auction House if tradable.'},{name='Siren\'s Tear',get='North Gustaberg creek/quest interaction; obtain through the Siren\'s Tear quest step.'},{name='Bastokan Mittens',get='Bastok armor vendor or Auction House.'},{name='Vision Ring',get='Crafted/enchantment ring; Auction House; charge count does not matter.'},
        {name='Carbuncle\'s Ruby',get='Leech-family drop used for Summoner unlock; farm leeches or Auction House.'},{name='Sphene Earring',get='Goldsmithing synthesis or Auction House.'},{name='Cornette',get='Instrument merchant or Auction House.'},{name='Spark Degen',get='Conquest Points reward/weapon or Auction House.'}}},
    {zone="Ifrit's Cauldron Map 8 (F-9)",npc="Siknoz",items={
        {name='Smooth Stone',get='Mining/gathering source; Auction House if tradable.'},{name='Pickaxe x3',get='General-goods/tool merchants or Auction House; bring 3.'},{name='Sulfur x3',get='Mining or Bomb-family drops; Auction House; bring 3.'},{name='Chicken Bone x12',get='Bonecraft material from bird/chicken-type sources; Auction House; bring 12.'},{name='Field Tunica',get='Field gear merchant or Auction House.'},{name='Antlion Jaw',get='Antlion-family drop in Attohwa/related areas; Auction House.'},{name='High-Quality Scorpion Shell',get='Scorpion-family high-quality drop; Auction House.'},{name='Adaman Ore',get='High-level mining/HNM/BCNM sources; Auction House.'}}},
    {zone="Attohwa Chasm (G-7)",npc="Beirabear + Ariseis",items={
        {name='New Linkshell',get='Buy a fresh Linkshell from a Linkshell vendor; use a new Linkshell item.'},{name='Horn Ring',get='Bonecraft synthesis or Auction House.'},{name='Skeleton Key',get='Crafted Thief tool; Auction House.'},{name='Oxblood',get='Sea Monk/large aquatic monster source; Auction House.'},
        {name='Delkfutt Key',get='Obtained through Delkfutt\'s Tower progression/key-holder mobs.'},{name='Cold Bone',get='Undead/bone-family source in cold/high-level zones; Auction House.'},{name='Fang Necklace',get='Bonecraft synthesis or Auction House.'},{name='Black Pearl',get='Clam/fishing/treasure source or Auction House.'}}},
    {zone="The Garden of Ru'Hmet Map 4 (J-12)",npc="Damarus",items={
        {name='Red Jar',get='Excavation/gathering pottery item; Auction House.'},{name='Shell Bug',get='Bug item from gathering/harvesting; Auction House.'},{name='Tree Saplings',get='Gardening result or Auction House.'},{name='Arcane Flowerpot',get='Furnishing from crafting/vendor/quest sources; Auction House.'},{name='Maple Table',get='Woodworking furnishing; craft or Auction House.'},{name='Tarutaru Rice',get='Food ingredient vendors in Windurst/region vendors or Auction House.'},{name='Reishi Mushroom',get='Harvesting/monster source in forest-type zones; Auction House.'},{name='Faded Crystal',get='Obtained by fading a crystal through the related NPC/process; Auction House if listed.'}}},
    {zone="Southern San d'Oria (G-7)",npc="Violet + Abdiah",items={
        {name='Quadav Charm',get='Quadav-family drop; farm Palborough/Beadeaux-era Quadav.'},{name='Steel Ingot',get='Smithing synthesis or Auction House.'},{name='Paktong Ingot',get='Smithing synthesis; Auction House.'},{name='Pellet Belt',get='Crafted equipment; Auction House.'},
        {name='Magicked Steel',get='Special smithing material from quest/monster/crafting sources; Auction House if available.'},{name='Eight of Swords (Card)',get='Cardian-family drop in Horutoto/Toraimarai-style areas; Auction House.'},{name='Darksteel Pick',get='Smithing-crafted pick; Auction House.'},{name='Decurion\'s Dagger (Bastok 2nd place)',get='Conquest reward from Bastok while Bastok is in 2nd place; check Bastok Conquest guards.'}}},
};

-- Capture-verified Tracent/Drowsy dialogue signatures. Riddle-only dialogue
-- identifies requested items but never proves completion. Counter dialogue is
-- emitted after a successful turn-in and is therefore authoritative for the
-- four-item NPC set.
local TRACENT_DROWSY_RIDDLES={
    tracent={
        {index=1,needle='from the hive where queens meet'},
        {index=2,needle="from a crab's claw"},
        {index=3,needle='carved with a grin'},
        {index=4,needle='twelve fiery fruits'},
    },
    drowsy={
        {index=5,needle="from the shaman's wreath"},
        {index=6,needle='fish leaps forth from the jug'},
        {index=7,needle='blood and cocoa'},
        {index=8,needle='thirty-three cookies'},
    },
};

local TRACENT_DROWSY_ITEMS={
    tracent={1,2,3,4},
    drowsy={5,6,7,8},
};

-- Capture-verified Kipling/Ah Puch request riddles from The Boyahda Tree.
-- This NPC pair emits all four clues for its lane in one interaction, so these
-- signatures identify the requested items ONLY.  Seeing later clues in the same
-- batch must never backfill earlier items as completed.
local KIPLING_AHPUCH_RIDDLES={
    kipling={
        {index=1,needle="in the tomb's dark silence"},
        {index=2,needle='dark and smooth, caressed by air'},
        {index=3,needle='crafted with care, too strong to break'},
        {index=4,needle='woven from crystal, yet soft to touch'},
    },
    ahpuch={
        {index=5,needle='from flames reborn, i rise and fly'},
        {index=6,needle='soft and warm, i line the floor'},
        {index=7,needle="woven by a ghost, in moon's pale light"},
        {index=8,needle='three dark feathers, soft and light'},
    },
};

local KIPLING_AHPUCH_ITEMS={
    kipling={1,2,3,4},
    ahpuch={5,6,7,8},
};

-- Only these lanes currently have capture-verified successful-turn-in signatures.
-- Other lanes may safely advance from a later current-riddle observation, but
-- HorizonCheck never fabricates a generic completion-counter pattern.
local VERIFIED_TURNIN_LANES={tracent=true,drowsy=true,kipling=true,ahpuch=true};

local Y2024_BONUS={
    {name='Scroll of Dispel',get='Spell scroll from BCNM/monster sources; Auction House.'},{name='Empress Band',get='Conquest Points EXP ring from a Conquest guard.'},{name='Scroll of Stun',get='Spell scroll from BCNM/monster sources; Auction House.'},{name='Giant Scale',get='Riverne-area large flying beast/scale source; Auction House.'},
    {name='Test Answers',get='Quest/event item from the related school/test quest line.'},{name='Bronze Key',get='Low-level chest/key drop; farm the appropriate key-dropping mobs.'},{name='Frank\'s Stick',get='Drop from NM Frank in Crawlers\' Nest.'},{name='Counterfeit Gil',get='Goblin/Moblin-related quest/drop item; Auction House if tradable.'},
};

local Y2025={
    {"Mycophile","Carpenters' Landing (I-11)","Trade Sleepshroom + Woozyshroom + Danceshroom to ???"},
    {"Treant","Batallia Downs (D-5)","Weeping Willow area"},
    {"Tom Tit Tat","West Sarutabaruta","NM spawn area"},
    {"Thread Leech","Valkurm Dunes (B-7)","Secret beach"},
    {"Cursed Puppet","Ro'Maeve (H-6)",""},
    {"Swamfisk","East Ronfaure","Swamfisk spawn area"},
    {"Stealth Bat","Yughott Grotto Map 2","Near BCNM"},
    {"Utukku","Eldieme Necropolis Map 2 (E-6)","Enter from Batallia Downs (F-5)"},
    {"Goblin Smithy / Goblin Furrier","Sanctuary of Zi'Tah (L-9)","Near Mandau/SAM quest tree"},
    {"Abraxas","Lufaise Meadows (K-7)","Birds near water"},
    {"Darter","The Boyahda Tree Map 3 (E-11)","Ancient Goobbue area"},
    {"Exoray","Crawlers' Nest Map 2 (G-9)",""},
    {"Fyuu the Seabellow","Sea Serpent Grotto (L-11/M-11)",""},
    {"Carnero","South Gustaberg","Carnero spawn area; widescan helpful"},
    {"Specter","Fei'Yin (F-7/G-7)","Southern shadow room area"},
    {"Ooze","Castle Oztroja Map 2 (H-9)","Basement pool"},
    {"Demon Knight/Pawn/Warlock/Wizard","Castle Zvahl Keep Map 3 (I-9)","SE quadrant near teleporters"},
    {"Volcanic Bomb","Ifrit's Cauldron Map 7 (J-4)","Bomb room"},
    {"Pyrodrake","Riverne - Site B01 (J-6)",""},
    {"Shrieker","Ordelle's Caves Map 2 (G-7)","Near PLD Stalactite Dew area"},
    {"Greater Pugil","Gusgen Mines Map 3 (H-7)","Near Wounded Wurfel"},
    {"Ice Elemental","Uleguerand Range (G-7/G-8)","Jormungand area"},
    {"Diremite","Pso'Xja Map 8 (H-8)","Lv40 tower north of outpost; first circle room"},
    {"Greater Manticore","Cape Teriggan (G-5)","Closest to Cermet Headstone"},
    {"Tartarus Eft","Bibiki Bay (G-10)","Bottom of map / cliff area"},
    {"Snipper","Dangruf Wadi (H-3/H-4)","Behind waterfall"},
    {"Garm","Bostaunieux Oubliette Map 2 (J-7/K-7)",""},
    {"Mischievous Micholas","Yuhtunga Jungle (F-8/G-8)","NM spawn area"},
    {"Thread Leech","Pashhow Marshlands (F-5)","Near Bloodpool Vorax"},
    {"Phasma","Upper Delkfutt's Tower","Floors 11-12"},
};

local function ensure(c)
    c.anniversary=type(c.anniversary)=='table' and c.anniversary or {};
    for _,year in ipairs({'2023','2024','2025'}) do
        c.anniversary[year]=type(c.anniversary[year])=='table' and c.anniversary[year] or {};
    end
    c.anniversary['2024_bonus']=type(c.anniversary['2024_bonus'])=='table' and c.anniversary['2024_bonus'] or {};
    c.anniversary.auto=type(c.anniversary.auto)=='table' and c.anniversary.auto or {};
    c.anniversary.auto.npc_turnins=type(c.anniversary.auto.npc_turnins)=='table' and c.anniversary.auto.npc_turnins or {};
    return c.anniversary;
end

local function count(tbl,total)
    local n=0;
    for i=1,total do if tbl[i]==true then n=n+1; end end
    return n;
end

-- Anniversary open-state is owned by HorizonCheck instead of Dear ImGui.
-- On the HorizonXI/Ashita ImGui bridge a CollapsingHeader can lose its internal
-- open state when a live checkbox changes after an NPC trade. A Selectable
-- header gives us the same full-width row interaction while the actual open /
-- closed boolean remains stable in Lua until the user explicitly clicks it.
local anniversary_open_state={};
local function sticky_anniversary_header(id,label,default_open)
    local imgui=HC and HC.imgui or nil; if not imgui then return false; end
    id=tostring(id or label or 'section');
    local open=anniversary_open_state[id];
    if open==nil then open=default_open==true; anniversary_open_state[id]=open; end
    local visible=(open and '▼ ' or '▶ ')..tostring(label or '');
    if type(imgui.Selectable)=='function' then
        local ok,clicked=pcall(imgui.Selectable,visible..'##hc_anniv_sticky_'..id,true);
        if ok and clicked==true then
            open=not open; anniversary_open_state[id]=open;
        end
        return open;
    end
    -- Compatibility fallback for an unusual ImGui build without Selectable.
    local flags=(open and default_open==true) and (rawget(_G,'ImGuiTreeNodeFlags_DefaultOpen') or 0) or 0;
    local ok,v=pcall(imgui.CollapsingHeader,tostring(label or '')..'##hc_anniv_sticky_'..id,flags);
    if ok then anniversary_open_state[id]=(v==true); return v==true; end
    return open;
end

local function invalidate_anniversary(reason)
    if HC and HC.modules and HC.modules.dependencies and HC.modules.dependencies.invalidate then
        pcall(HC.modules.dependencies.invalidate,'anniversary',reason or 'Anniversary state changed');
    elseif HC and HC.modules and HC.modules.smartdashboard and HC.modules.smartdashboard.invalidate then
        pcall(HC.modules.smartdashboard.invalidate);
    end
end

local function checkbox(c,tbl,key,label)
    local v={tbl[key]==true};
    if HC.imgui.Checkbox(label..'##anniv_'..tostring(key)..'_'..label,v) then
        tbl[key]=v[1] and true or nil;
        HC.modules.state.save();
        invalidate_anniversary('manual Anniversary checkbox changed');
    end
end

-- Anniversary 2024 ownership/location display ---------------------------------
-- v7.2.4: Resolve the entire 2024 + Aerec item catalog to exact client item IDs
-- once per session.  Catalog labels are allowed to be human-friendly (quantity
-- suffixes, explanatory parentheticals, full words), while ownership checks use
-- the authoritative Ashita resource ID whenever the local client can resolve it.
-- Name aliases remain a fallback only for older/custom resource layouts.
local ANNIV_2024_ITEM_ALIASES={
    ['High-Quality Bugard Skin']={'High-Quality Bugard Skin','H.Q. Bugard Skin','HQ Bugard Skin'},
    ['High-Quality Scorpion Shell']={'High-Quality Scorpion Shell','H.Q. Scorpion Shell','HQ Scorpion Shell'},
    ['New Linkshell']={'New Linkshell','Linkshell'},
    ['Tree Saplings']={'Tree Saplings','Tree Sapling'},
    -- FFXI client/resources abbreviate item 845 even though the HorizonXI
    -- Anniversary guide uses the full name.
    ['Black Chocobo Feather']={'Black Chocobo Feather','Black C. Feather'},
};
local ANNIV_2024_FIXED_IDS={
    ['Black Chocobo Feather']={845},
};
local anniv_2024_location_cache={token=nil,at=0,rows={}};
local anniv_2024_resolved_ids={};
local anniv_2024_registry_warmed=false;
local ANNIV_2024_LOCATION_TTL=10;

local function anniv_2024_inventory_base(name)
    local base=tostring(name or '');
    base=base:gsub('%s+[xX]%d+%s*$',''):gsub('%s+$','');
    -- Some catalog labels include a guide-only parenthetical, e.g.
    -- "Eight of Swords (Card)" or "Decurion's Dagger (Bastok 2nd place)".
    -- Strip only trailing parentheticals for resource lookup; the visible label
    -- remains untouched.
    while base:match('%s*%b()%s*$') do
        base=base:gsub('%s*%b()%s*$',''):gsub('%s+$','');
    end
    return base;
end

local function anniv_2024_inventory_aliases(name)
    local base=anniv_2024_inventory_base(name);
    local out={}; local seen={};
    local function add(v)
        v=tostring(v or ''):gsub('^%s+',''):gsub('%s+$','');
        if v~='' and not seen[v] then out[#out+1]=v; seen[v]=true; end
    end
    add(base);
    for _,v in ipairs(ANNIV_2024_ITEM_ALIASES[base] or {}) do add(v); end

    -- Common FFXI resource abbreviation conventions.  These are candidates for
    -- exact resource lookup, not fuzzy ownership matches, so a candidate only
    -- becomes authoritative when Ashita resolves it to a real item ID.
    if base:find('High%-Quality',1,false) then
        add(base:gsub('High%-Quality','H.Q.'));
        add(base:gsub('High%-Quality','HQ'));
    end

    -- FFXI often shortens a middle word to an initial (Black Chocobo Feather ->
    -- Black C. Feather).  Generate one-middle-token-at-a-time candidates and let
    -- the ResourceManager decide whether that exact item actually exists.
    local words={};
    for w in base:gmatch('%S+') do words[#words+1]=w; end
    if #words>=3 then
        for i=2,#words-1 do
            local first=words[i]:match('^([%a])[%a%-]+$');
            if first then
                local tmp={}; for j,w in ipairs(words) do tmp[j]=w; end
                tmp[i]=first..'.';
                add(table.concat(tmp,' '));
            end
        end
    end

    return out;
end

local function merge_item_ids(out,seen,ids)
    for _,id in ipairs(type(ids)=='table' and ids or {}) do
        id=tonumber(id);
        if id and id>0 and not seen[id] then out[#out+1]=id; seen[id]=true; end
    end
end

local function anniv_2024_resolve_ids(name)
    local own=HC.modules and HC.modules.ownership or nil;
    local base=anniv_2024_inventory_base(name);
    local cached=anniv_2024_resolved_ids[base];
    if cached~=nil then return cached; end

    local out={}; local seen={};
    merge_item_ids(out,seen,ANNIV_2024_FIXED_IDS[base]);
    local candidates=anniv_2024_inventory_aliases(base);
    if own and own.resolve_ids then
        local ok,ids=pcall(own.resolve_ids,candidates);
        if ok then merge_item_ids(out,seen,ids); end
    end
    anniv_2024_resolved_ids[base]=out;
    return out;
end

local function anniv_2024_warm_id_registry()
    if anniv_2024_registry_warmed then return; end
    anniv_2024_registry_warmed=true;
    -- One bounded resource-resolution pass when the 2024 page is first opened.
    -- This is not an inventory scan and never runs from the frame loop again.
    for _,g in ipairs(Y2024) do
        for _,item in ipairs(g.items or {}) do
            anniv_2024_resolve_ids(type(item)=='table' and item.name or item);
        end
    end
    for _,item in ipairs(Y2024_BONUS) do
        anniv_2024_resolve_ids(type(item)=='table' and item.name or item);
    end
end

local function anniv_2024_item_location(name)
    local own=HC.modules and HC.modules.ownership or nil;
    if not own or not own.current then return nil; end
    local now=os.time();
    local token=(own.status and own.status().token) or 'na';
    if anniv_2024_location_cache.token~=token or (now-tonumber(anniv_2024_location_cache.at or 0))>=ANNIV_2024_LOCATION_TTL then
        anniv_2024_location_cache={token=token,at=now,rows={}};
    end
    local key=tostring(name or '');
    local cached=anniv_2024_location_cache.rows[key];
    if cached~=nil then return cached~=false and cached or nil; end

    local aliases=anniv_2024_inventory_aliases(key);
    local ids=anniv_2024_resolve_ids(key);
    local loc,scan_ok=nil,false;
    if own.location_ids and #ids>0 then
        loc,scan_ok=own.location_ids(ids,aliases,false);
    end
    if loc==nil then
        local info=own.current(aliases,false);
        scan_ok=info.known==true; loc=info.owned and info.location or nil;
    end
    local refreshed=(own.status and own.status().token) or token;
    if refreshed~=anniv_2024_location_cache.token then
        anniv_2024_location_cache={token=refreshed,at=now,rows={}};
    end
    anniv_2024_location_cache.rows[key]=(scan_ok==true and loc) or false;
    return (scan_ok==true) and loc or nil;
end

function M.item_id_registry_status()
    anniv_2024_warm_id_registry();
    local total,resolved=0,0;
    local function add_item(item)
        total=total+1;
        local name=type(item)=='table' and item.name or item;
        if #(anniv_2024_resolve_ids(name) or {})>0 then resolved=resolved+1; end
    end
    for _,g in ipairs(Y2024) do for _,item in ipairs(g.items or {}) do add_item(item); end end
    for _,item in ipairs(Y2024_BONUS) do add_item(item); end
    return {resolved=resolved,total=total,unresolved=math.max(0,total-resolved)};
end

local function draw_2024_item_location(name)
    local loc=anniv_2024_item_location(name);
    if not loc then return; end
    HC.imgui.SameLine();
    HC.imgui.TextDisabled('[OWNED - '..tostring(loc)..']');
end

local function draw_2023(c,a)
    local imgui=HC.imgui;
    local d=count(a['2023'],#Y2023);
    imgui.Text(string.format('2023 Anniversary Scavenger Hunt: %d/%d locations',d,#Y2023));
    imgui.TextDisabled('Start: Heavens Tower basement. Requires CoP 1-3 and access to nation mission 2-3 areas.');
    imgui.TextDisabled('Rewards: Mandragora Suit, Mandragora Masque, +5 Mog Satchel; final route awards HorizonXI Shirt.');
    imgui.Separator();
    for i,step in ipairs(Y2023) do
        checkbox(c,a['2023'],i,string.format('%02d. %s',i,step));
    end
    imgui.Spacing();
    imgui.Text('Final HorizonXI Shirt step');
    imgui.TextDisabled('After Location 38, revisit locations in server-launch-date order: 12 -> 17 -> 22.');
    imgui.TextDisabled('12: La Theine Plateau | 17: Ship | 22: Qufim Island. Click each once.');
end

local function comma_number(v)
    local s=tostring(math.max(0,math.floor(tonumber(v) or 0)));
    local out=s:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','');
    return out;
end


local function count_2024_group(a, group_index)
    local offset=0
    for gi=1,group_index-1 do
        offset=offset+#(Y2024[gi].items or {})
    end
    local total=#(Y2024[group_index].items or {})
    local done=0
    for i=1,total do
        if a['2024'][offset+i]==true then done=done+1 end
    end
    return done,total
end

local npc_names, npc_lane_bounds, group_base_index;

local function draw_turnin_status(a,npc,label,group_index,item_indexes)
    local imgui=HC.imgui;
    local auto=type(a.auto)=='table' and a.auto or {};
    local states=type(auto.npc_turnins)=='table' and auto.npc_turnins or {};
    local st=type(states[npc])=='table' and states[npc] or nil;
    if not st then return; end

    imgui.Text(label..': '..tostring(st.status or 'OBSERVED'));
    if st.status=='TURN-IN COMPLETE' and tonumber(st.completed) and tonumber(st.remaining) then
        local total=tonumber(st.completed)+tonumber(st.remaining);
        local noun=(npc=='tracent') and 'Bugs' or 'Quests';
        imgui.TextDisabled(string.format('%s: %s / %s complete | %s remaining',noun,comma_number(st.completed),comma_number(total),comma_number(st.remaining)));
        if st.next_clue and tostring(st.next_clue)~='' then
            imgui.TextDisabled('Next clue: '..tostring(st.next_clue));
        end
    elseif st.status=='ITEMS REQUESTED' then
        local requested={};
        local g=Y2024[tonumber(group_index) or 1];
        for _,item_index in ipairs(item_indexes or {}) do
            if type(st.requested)=='table' and st.requested[item_index]==true then
                local item=g and g.items and g.items[item_index] or nil;
                requested[#requested+1]=type(item)=='table' and tostring(item.name) or tostring(item or ('Item '..item_index));
            end
        end
        if #requested>0 then imgui.TextDisabled('Requested: '..table.concat(requested,', ')); end
    end
    if type(st.accepted)=='table' then
        local accepted={}; local g=Y2024[tonumber(group_index) or 1];
        for _,item_index in ipairs(item_indexes or {}) do
            if st.accepted[item_index]==true then
                local item=g and g.items and g.items[item_index] or nil;
                accepted[#accepted+1]=type(item)=='table' and tostring(item.name) or tostring(item or ('Item '..item_index));
            end
        end
        if #accepted>0 then imgui.TextDisabled('Turned in: '..table.concat(accepted,', ')); end
    end
end


local function display_speaker_name(g,speaker)
    local lowers=npc_names(g.npc); local originals={};
    for n in tostring(g.npc or ''):gmatch('[^+]+') do originals[#originals+1]=n:gsub('^%s+',''):gsub('%s+$',''); end
    for i,n in ipairs(lowers) do if n==speaker then return originals[i] or speaker; end end
    return speaker;
end

local function draw_2024_lane_status(a,group_index,g)
    local auto=type(a.auto)=='table' and a.auto or {}; local progress=type(auto.npc_progress)=='table' and auto.npc_progress or {};
    local any=false;
    for _,speaker in ipairs(npc_names(g.npc)) do
        local st=progress[tostring(group_index)..':'..tostring(speaker)];
        if type(st)=='table' then
            local first,last=npc_lane_bounds(group_index,speaker); local done=0; local total=(first and last) and (last-first+1) or 0; local base=group_base_index(group_index);
            if first then for i=first,last do if a['2024'][base+i]==true then done=done+1; end end end
            local item=(tonumber(st.current_item) and g.items[tonumber(st.current_item)]) or nil;
            local item_name=type(item)=='table' and item.name or item;
            imgui.TextDisabled(string.format('%s auto: %d/%d confirmed%s',display_speaker_name(g,speaker),done,total,item_name and (' | current request: '..tostring(item_name)) or ''));
            any=true;
        end
    end
    if any then imgui.Separator(); end
end

local function anniversary_section_gap()
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    if type(imgui.Spacing)=='function' then imgui.Spacing(); end
end

local function draw_2024(c,a)
    local imgui=HC.imgui;
    anniv_2024_warm_id_registry();
    local total=0; for _,g in ipairs(Y2024) do total=total+#g.items; end
    local d=count(a['2024'],total);
    local progress_text=(HC.modules.uikit and HC.modules.uikit.progress_label) and HC.modules.uikit.progress_label('2024 Anniversary Item Hunt',d,total) or string.format('2024 Anniversary Item Hunt - %d/%d',d,total);
    imgui.Text(progress_text);
    imgui.TextDisabled("Trade requested items one at a time. Current-riddle backfill is tracked separately for each NPC, so paired NPCs cannot complete each other's riddles.");
    imgui.TextDisabled('Each item includes a concise acquisition hint. AH references mean the item is normally tradable/listable.');
    imgui.TextDisabled('Items currently found on this character show [OWNED - LOCATION] beside the item name.');
    imgui.TextDisabled('Major rewards: Anniversary Ring, free haircut, Goblin Masque, nation earrings, Tinfoil Hat.');
    imgui.Separator();

    local idx=0;
    for gi,g in ipairs(Y2024) do
        if gi>1 then anniversary_section_gap(); end
        local group_done,group_total=count_2024_group(a,gi)
        local header=g.zone..' - '..g.npc
        if group_total>0 and group_done>=group_total then header=header..' - COMPLETE'; end
        if sticky_anniversary_header('2024_group_'..tostring(gi),header,false) then
            if g.npc=='Tracent + Drowsy' then
                draw_turnin_status(a,'tracent','Tracent',1,TRACENT_DROWSY_ITEMS.tracent);
                draw_turnin_status(a,'drowsy','Drowsy',1,TRACENT_DROWSY_ITEMS.drowsy);
                local ts=type(a.auto)=='table' and type(a.auto.npc_turnins)=='table' and a.auto.npc_turnins or {};
                if ts.tracent or ts.drowsy then imgui.Separator(); end
            elseif g.npc=='Kipling + Ah Puch' then
                draw_turnin_status(a,'kipling','Kipling',2,KIPLING_AHPUCH_ITEMS.kipling);
                draw_turnin_status(a,'ahpuch','Ah Puch',2,KIPLING_AHPUCH_ITEMS.ahpuch);
                local ts=type(a.auto)=='table' and type(a.auto.npc_turnins)=='table' and a.auto.npc_turnins or {};
                if ts.kipling or ts.ahpuch then imgui.Separator(); end
            end
            draw_2024_lane_status(a,gi,g);
            for _,item in ipairs(g.items) do
                idx=idx+1;
                local name=type(item)=='table' and item.name or tostring(item);
                checkbox(c,a['2024'],idx,name);
                draw_2024_item_location(name);
                if type(item)=='table' and item.get then
                    imgui.TextDisabled('    Get: '..item.get);
                end
            end
        else
            idx=idx+#g.items;
        end
    end

    anniversary_section_gap();
    local bd=count(a['2024_bonus'],#Y2024_BONUS);
    local bonus_header=string.format('Aerec Bonus Riddles - Lower Jeuno (J-8)  %d/%d',bd,#Y2024_BONUS);
    if #Y2024_BONUS>0 and bd>=#Y2024_BONUS then bonus_header=bonus_header..' - COMPLETE'; end
    if sticky_anniversary_header('2024_bonus',bonus_header,false) then
        imgui.TextDisabled('Turn in all 8 bonus items to Aerec for +5 Mog Satchel capacity.');
        for i,item in ipairs(Y2024_BONUS) do
            local name=type(item)=='table' and item.name or tostring(item);
            checkbox(c,a['2024_bonus'],i,name);
            draw_2024_item_location(name);
            if type(item)=='table' and item.get then
                imgui.TextDisabled('    Get: '..item.get);
            end
        end
    end
end

local function draw_2025(c,a)
    local imgui=HC.imgui;
    local d=count(a['2025'],#Y2025);
    imgui.Text(string.format('2025 Anniversary Sehri Hunts: %d/%d',d,#Y2025));
    imgui.TextDisabled('Start: Sehri, Kazham (I-11). Random hunts auto-check after HorizonCheck observes the assignment and remains completion.');
    imgui.TextDisabled('Kill the assigned target until you receive the remains message, then return to Sehri.');
    imgui.TextDisabled('Rewards: Anniversary Ring (1), Korrigan Beret (5), Ophidian Sword (12), Coeurl Mount (23), +5 Mog Satchel (30).');
    imgui.Separator();
    for i,h in ipairs(Y2025) do
        local label=string.format('%02d. %s - %s',i,h[1],h[2]);
        checkbox(c,a['2025'],i,label);
        if h[3]~='' then
            imgui.SameLine();
            imgui.TextDisabled('- '..h[3]);
        end
    end
end



-- v6.9.13 anniversary auto-sync -------------------------------------------------
-- The anniversary content is server-custom and does not expose a proven native
-- completed-bitfield.  Keep automatic updates conservative: only infer progress
-- from authoritative NPC/current-riddle dialogue or an explicit 2025 remains
-- completion while a Sehri assignment is known.

local function norm_item_name(name)
    local s=tostring(name or ''):lower()
    s=s:gsub('x%d+','')
    s=s:gsub('%(card%)','')
    s=s:gsub('%b()','')
    s=s:gsub('[^%w%s%+%-\' ]',' ')
    s=s:gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$','')
    return s
end

npc_names=function(label)
    local out={}
    for n in tostring(label or ''):gmatch('[^+]+') do
        n=n:lower():gsub('^%s+',''):gsub('%s+$','')
        if n~='' then out[#out+1]=n end
    end
    return out
end

local function speaker_from_label(s,label)
    s=tostring(s or ''):lower()
    for _,n in ipairs(npc_names(label)) do
        local pos=s:find(n,1,true);
        if pos then
            -- Ashita chat text may retain control bytes between the speaker name
            -- and colon, so inspect a short suffix rather than requiring `name:`.
            local tail=s:sub(pos+#n,pos+#n+12);
            if tail:find(':',1,true) then return n; end
        end
    end
    return nil
end

local function line_from_npc(s,label)
    return speaker_from_label(s,label)~=nil
end

group_base_index=function(group_index)
    local base=0
    for gi,g in ipairs(Y2024) do
        if gi==group_index then break end
        base=base+#(g.items or {})
    end
    return base
end

-- Each paired 2024 location is two independent four-riddle NPC lanes. A single
-- NPC owns the full eight-riddle lane. Keeping inference inside the speaker's
-- lane prevents talking to the second NPC from falsely completing the first
-- NPC's four riddles.
npc_lane_bounds=function(group_index,speaker)
    local g=Y2024[tonumber(group_index) or 0]; if not g then return nil,nil; end
    local names=npc_names(g.npc); local total=#(g.items or {}); if total<=0 then return nil,nil; end
    if #names<=1 then return 1,total; end
    speaker=tostring(speaker or ''):lower();
    local which=nil; for i,n in ipairs(names) do if n==speaker then which=i; break; end end
    if not which then return nil,nil; end
    local lane=math.floor(total/#names); if lane<1 then return nil,nil; end
    local first=(which-1)*lane+1;
    local last=(which==#names) and total or (first+lane-1);
    return first,last
end

local function mark_2024_lane_before(c, group_index, speaker, item_index, source)
    local a=ensure(c); local base=group_base_index(group_index);
    local first,last=npc_lane_bounds(group_index,speaker); item_index=tonumber(item_index);
    if not first or not item_index or item_index<first or item_index>last then return 0; end
    local changed=0
    for i=first,item_index-1 do
        local k=base+i
        if a['2024'][k]~=true then a['2024'][k]=true; changed=changed+1 end
    end
    if changed>0 then
        a.auto=type(a.auto)=='table' and a.auto or {}
        a.auto.last_2024_sync={at=os.time(),source=source or 'Anniversary NPC current riddle',group=group_index,current=item_index,speaker=speaker,added=changed}
        a.auto.npc_progress=type(a.auto.npc_progress)=='table' and a.auto.npc_progress or {}
        local key=tostring(group_index)..':'..tostring(speaker);
        a.auto.npc_progress[key]=type(a.auto.npc_progress[key])=='table' and a.auto.npc_progress[key] or {}
        a.auto.npc_progress[key].backfilled=(tonumber(a.auto.npc_progress[key].backfilled) or 0)+changed
        HC.modules.state.request_save(1)
        invalidate_anniversary('2024 NPC lane progress backfilled');
        HC.msg('Anniversary Sync: marked '..tostring(changed)..' earlier '..tostring(speaker)..' riddle(s) complete from current NPC progress.')
    end
    return changed
end

local function observe_2024_current(c,a,group_index,speaker,item_index,raw,source)
    local first,last=npc_lane_bounds(group_index,speaker); item_index=tonumber(item_index);
    if not first or not item_index or item_index<first or item_index>last then return false; end
    mark_2024_lane_before(c,group_index,speaker,item_index,source);
    a.auto=type(a.auto)=='table' and a.auto or {}; a.auto.npc_progress=type(a.auto.npc_progress)=='table' and a.auto.npc_progress or {};
    local key=tostring(group_index)..':'..tostring(speaker);
    local st=type(a.auto.npc_progress[key])=='table' and a.auto.npc_progress[key] or {}; a.auto.npc_progress[key]=st;
    local body=tostring(raw or ''):match(':%s*(.-)%s*$') or tostring(raw or ''); body=body:gsub('^%s+',''):gsub('%s+$','');
    local previous=tonumber(st.current_item);
    local changed=previous~=item_index or tostring(st.last_riddle or '')~=body;
    if previous and item_index>previous then
        st.advancements=(tonumber(st.advancements) or 0)+1;
        st.last_advanced_from=previous; st.last_advanced_to=item_index; st.last_advanced_at=os.time();
        st.last_advanced_source='same-NPC current-riddle progression';
    end
    st.group=group_index; st.speaker=speaker; st.first=first; st.last=last; st.current_item=item_index; st.current_abs=group_base_index(group_index)+item_index;
    st.status='ITEMS REQUESTED'; st.last_riddle=body; st.observed_at=os.time(); st.source=source or 'NPC current-riddle dialogue';
    if changed then HC.modules.state.request_save(1); end
    return true
end

local function mark_2024_bonus_before(c,item_index,source)
    local a=ensure(c); local changed=0
    for i=1,item_index-1 do
        if a['2024_bonus'][i]~=true then a['2024_bonus'][i]=true; changed=changed+1 end
    end
    if changed>0 then
        a.auto=type(a.auto)=='table' and a.auto or {}
        a.auto.last_2024_bonus_sync={at=os.time(),source=source or 'Aerec current riddle',current=item_index,added=changed}
        HC.modules.state.request_save(1)
        invalidate_anniversary('Aerec bonus progress backfilled');
        HC.msg('Anniversary Sync: marked '..tostring(changed)..' earlier Aerec bonus riddle(s) complete.')
    end
    return changed
end

local function sehri_target_index(s)
    s=tostring(s or ''):lower()
    for i,h in ipairs(Y2025) do
        local raw=tostring(h[1] or ''):lower()
        -- Some rows contain slash-separated families.  Match any sufficiently
        -- distinctive component instead of requiring the display label verbatim.
        for part in raw:gmatch('[^/]+') do
            part=part:gsub('^%s+',''):gsub('%s+$','')
            if #part>=4 and s:find(part,1,true) then return i end
        end
    end
    return nil
end

local function dialogue_body(raw)
    local body=tostring(raw or ''):match(':%s*(.-)%s*$') or tostring(raw or '');
    body=body:gsub('^%s+',''):gsub('%s+$','');
    return body;
end

local function npc_turnin_state(a,npc)
    a.auto=type(a.auto)=='table' and a.auto or {};
    a.auto.npc_turnins=type(a.auto.npc_turnins)=='table' and a.auto.npc_turnins or {};
    a.auto.npc_turnins[npc]=type(a.auto.npc_turnins[npc])=='table' and a.auto.npc_turnins[npc] or {};
    return a.auto.npc_turnins[npc];
end

local function observe_requested_riddle(c,a,npc,item_index,raw)
    local st=npc_turnin_state(a,npc);
    st.requested=type(st.requested)=='table' and st.requested or {};
    local changed=st.requested[item_index]~=true or st.status==nil;
    st.requested[item_index]=true;
    -- Riddle-only dialogue must never erase a saved successful turn-in.
    if st.status~='TURN-IN COMPLETE' and st.status~='TURN-IN PARTIAL' then st.status='ITEMS REQUESTED'; end
    st.last_riddle=dialogue_body(raw);
    st.observed_at=os.time();
    if changed then HC.modules.state.save(); end
end

-- v7.2.12 Boyahda successful-turn-in correlation ----------------------------
-- Captures on 2026-08-29 proved that both Ah Puch and Kipling acknowledge a
-- successful item trade with the same generic line: "Ah! Yes this is one of
-- the items I was looking for."  The dialogue itself does not name the item.
-- Both captures also showed the same inventory refresh pattern, including the
-- 0x020 Item Update that clears/decrements the traded Inventory slot in the same
-- second.  Keep a tiny Inventory-only slot cache so the pre-update item ID can
-- be correlated with that generic success line.  This is deliberately strict:
-- no recent requested-item inventory delta = no automatic completion.
local BOYAHDA_SUCCESS_WINDOW=5;
local BOYAHDA_SUCCESS_NEEDLE='yes this is one of the items i was looking for';

-- Capture-verified post-turn-in dialogue after all four requested items for an
-- NPC lane have been accepted.  Unlike BOYAHDA_SUCCESS_NEEDLE, these lines are
-- authoritative lane-completion evidence: they were observed only after the
-- full four-item set had been handed in.  They also let a later NPC check
-- reconcile a lane if HorizonCheck missed one of the individual trade packets.
local BOYAHDA_COMPLETE_SIGNATURES={
    kipling={
        "huh i didn't expect that character to be able to use that combo",
        "guess it is time to nerf aerec's favorite job again",
    },
    ahpuch={
        'catch the cheaters, stop their game',
        "we'll ban them fast, they've got no claim",
        "fair play's the rule, it's all the same",
    },
};
local BOYAHDA_POST_COMPLETE_CLUES={
    kipling='a symbol of power, on fingers worn',
    ahpuch='it holds a realm in every gleam',
};

local boyahda_slot_cache={};
local boyahda_item_by_id=nil;
local boyahda_recent_removals={};
local boyahda_pending_success=nil;

local function u8_at(data,offset)
    if type(data)~='string' then return nil; end
    return string.byte(data,(tonumber(offset) or 0)+1);
end

local function u16le_at(data,offset)
    local a=u8_at(data,offset); local b=u8_at(data,(tonumber(offset) or 0)+1);
    if a==nil or b==nil then return nil; end
    return a+b*256;
end

local function u32le_at(data,offset)
    local a=u8_at(data,offset); local b=u8_at(data,(tonumber(offset) or 0)+1);
    local c=u8_at(data,(tonumber(offset) or 0)+2); local d=u8_at(data,(tonumber(offset) or 0)+3);
    if a==nil or b==nil or c==nil or d==nil then return nil; end
    return a+b*256+c*65536+d*16777216;
end

local function boyahda_build_item_map()
    if boyahda_item_by_id~=nil then return boyahda_item_by_id; end
    boyahda_item_by_id={};
    local g=Y2024[2]; local base=#(Y2024[1] and Y2024[1].items or {});
    if g and g.items then
        for local_index,item in ipairs(g.items) do
            local name=type(item)=='table' and item.name or tostring(item or '');
            local npc=(local_index<=4) and 'kipling' or 'ahpuch';
            for _,id in ipairs(anniv_2024_resolve_ids(name) or {}) do
                id=tonumber(id);
                if id and id>0 then
                    boyahda_item_by_id[id]={id=id,local_index=local_index,global_index=base+local_index,npc=npc,name=name};
                end
            end
        end
    end
    return boyahda_item_by_id;
end

local function boyahda_scan_inventory()
    local map=boyahda_build_item_map(); local next_cache={};
    pcall(function()
        if not AshitaCore or not AshitaCore.GetMemoryManager then return; end
        local mm=AshitaCore:GetMemoryManager(); local inv=mm and mm:GetInventory() or nil;
        if not inv or not inv.GetContainerItem then return; end
        local mx=nil; if inv.GetContainerCountMax then pcall(function() mx=tonumber(inv:GetContainerCountMax(0)); end); end
        if type(mx)~='number' or mx<0 then mx=80; end
        for idx=0,mx do
            local e=nil; pcall(function() e=inv:GetContainerItem(0,idx); end);
            local id=e and tonumber(e.Id) or nil; local count=e and tonumber(e.Count) or 0;
            if id and id>0 and map[id] then next_cache[idx]={id=id,count=math.max(0,count or 0)}; end
        end
    end);
    boyahda_slot_cache=next_cache;
end

local function boyahda_prune_events(now)
    now=tonumber(now) or os.time(); local keep={};
    for _,ev in ipairs(boyahda_recent_removals) do
        if now-(tonumber(ev.at) or 0)<=BOYAHDA_SUCCESS_WINDOW then keep[#keep+1]=ev; end
    end
    boyahda_recent_removals=keep;
    if boyahda_pending_success and now-(tonumber(boyahda_pending_success.at) or 0)>BOYAHDA_SUCCESS_WINDOW then boyahda_pending_success=nil; end
end

local function mark_boyahda_item_turnin(c,a,npc,ev,raw)
    if not ev or ev.npc~=npc or not tonumber(ev.local_index) or not tonumber(ev.global_index) then return false; end
    local st=npc_turnin_state(a,npc); st.accepted=type(st.accepted)=='table' and st.accepted or {};
    local local_index=tonumber(ev.local_index); local global_index=tonumber(ev.global_index);
    local newly=st.accepted[local_index]~=true or a['2024'][global_index]~=true;
    st.accepted[local_index]=true; a['2024'][global_index]=true;
    st.last_accepted_item=tostring(ev.name or ('Item '..local_index)); st.last_accepted_at=os.time();
    st.last_acceptance=dialogue_body(raw); st.last_inventory_delta=tonumber(ev.delta) or 1;
    st.source='Capture-verified success dialogue + 0x020 inventory delta';
    local required=KIPLING_AHPUCH_ITEMS[npc] or {}; local all=true;
    for _,ii in ipairs(required) do if st.accepted[ii]~=true then all=false; break; end end
    st.status=all and 'TURN-IN COMPLETE' or 'TURN-IN PARTIAL';
    if newly then
        HC.modules.state.save(); invalidate_anniversary('capture-verified Boyahda item turn-in');
        local label=(npc=='ahpuch') and 'Ah Puch' or 'Kipling';
        HC.msg('Anniversary Sync: '..label..' accepted '..tostring(ev.name or 'requested item')..' - marked complete.');
    end
    return true;
end

local function complete_boyahda_lane_from_dialogue(c,a,npc,raw)
    local required=KIPLING_AHPUCH_ITEMS[npc] or {}; if #required==0 then return false; end
    local st=npc_turnin_state(a,npc); st.accepted=type(st.accepted)=='table' and st.accepted or {};
    local base=#(Y2024[1] and Y2024[1].items or {}); local changed=st.status~='TURN-IN COMPLETE';
    for _,local_index in ipairs(required) do
        if st.accepted[local_index]~=true then st.accepted[local_index]=true; changed=true; end
        local global_index=base+local_index;
        if a['2024'][global_index]~=true then a['2024'][global_index]=true; changed=true; end
    end
    st.status='TURN-IN COMPLETE';
    st.completed_at=st.completed_at or os.time();
    st.last_completion_dialogue=dialogue_body(raw);
    st.last_completion_at=os.time();
    st.source='Capture-verified post-turn-in dialogue';
    if changed then
        HC.modules.state.save(); invalidate_anniversary('capture-verified Boyahda lane completion dialogue');
        local label=(npc=='ahpuch') and 'Ah Puch' or 'Kipling';
        HC.msg('Anniversary Sync: '..label..' full four-item turn-in confirmed from completion dialogue.');
    end
    return true;
end

local function observe_boyahda_post_complete_clue(a,npc,raw)
    local st=npc_turnin_state(a,npc);
    if st.status~='TURN-IN COMPLETE' or not tonumber(st.last_completion_at) then return false; end
    if os.time()-tonumber(st.last_completion_at)>20 then return false; end
    local body=dialogue_body(raw); if body=='' then return true; end
    if st.next_clue~=body then st.next_clue=body; st.next_clue_at=os.time(); HC.modules.state.save(); end
    return true;
end

local function resolve_boyahda_success(c,a,npc,raw)
    local now=os.time(); boyahda_prune_events(now);
    for i=#boyahda_recent_removals,1,-1 do
        local ev=boyahda_recent_removals[i];
        if ev.npc==npc and now-(tonumber(ev.at) or 0)<=BOYAHDA_SUCCESS_WINDOW then
            table.remove(boyahda_recent_removals,i);
            return mark_boyahda_item_turnin(c,a,npc,ev,raw);
        end
    end
    boyahda_pending_success={npc=npc,at=now,raw=raw};
    local st=npc_turnin_state(a,npc); st.last_unresolved_acceptance=dialogue_body(raw); st.last_unresolved_acceptance_at=now;
    return false;
end

local function boyahda_on_item_update(e)
    local data=e and (e.data or e.data_raw) or nil; if type(data)~='string' or #data<16 then return; end
    local count=u32le_at(data,0x04) or 0; local item_id=u16le_at(data,0x0C) or 0;
    local bag=u8_at(data,0x0E); local index=u8_at(data,0x0F); if bag~=0 or index==nil then return; end
    local map=boyahda_build_item_map(); local old=boyahda_slot_cache[index]; local now=os.time();
    if old and map[old.id] then
        local remaining=(item_id==old.id) and count or 0; local delta=(tonumber(old.count) or 0)-(tonumber(remaining) or 0);
        if delta>0 then
            local spec=map[old.id];
            local ev={at=now,id=old.id,delta=delta,local_index=spec.local_index,global_index=spec.global_index,npc=spec.npc,name=spec.name,slot=index};
            boyahda_recent_removals[#boyahda_recent_removals+1]=ev; boyahda_prune_events(now);
            if boyahda_pending_success and boyahda_pending_success.npc==ev.npc and now-(tonumber(boyahda_pending_success.at) or 0)<=BOYAHDA_SUCCESS_WINDOW then
                local c=HC.modules.state.get_char(); local a=ensure(c); local pending=boyahda_pending_success; boyahda_pending_success=nil;
                mark_boyahda_item_turnin(c,a,ev.npc,ev,pending.raw);
                boyahda_recent_removals[#boyahda_recent_removals]=nil;
            end
        end
    end
    if item_id>0 and count>0 and map[item_id] then boyahda_slot_cache[index]={id=item_id,count=count}; else boyahda_slot_cache[index]=nil; end
end

local function complete_npc_turnin(c,a,npc,completed,remaining,raw)
    local st=npc_turnin_state(a,npc);
    local announce=st.status~='TURN-IN COMPLETE';
    local changed=announce;
    for _,item_index in ipairs(TRACENT_DROWSY_ITEMS[npc] or {}) do
        if a['2024'][item_index]~=true then a['2024'][item_index]=true; changed=true; announce=true; end
    end
    completed=tonumber(completed); remaining=tonumber(remaining);
    if st.completed~=completed or st.remaining~=remaining then changed=true; end
    st.status='TURN-IN COMPLETE';
    st.completed=completed;
    st.remaining=remaining;
    st.last_counter=dialogue_body(raw);
    st.last_counter_at=os.time();
    st.completed_at=st.completed_at or os.time();
    st.source='Capture-verified NPC counter dialogue';
    if changed then HC.modules.state.save(); invalidate_anniversary('capture-verified Anniversary turn-in'); end
    if announce then
        local label=(npc=='tracent') and 'Tracent' or 'Drowsy';
        HC.msg('Anniversary Sync: '..label..' turn-in confirmed from NPC counter dialogue.');
    end
end

local function observe_followup_clue(a,npc,raw)
    local st=npc_turnin_state(a,npc);
    if st.status~='TURN-IN COMPLETE' or not tonumber(st.last_counter_at) then return false; end
    if os.time()-tonumber(st.last_counter_at)>20 then return false; end
    local body=dialogue_body(raw);
    if body=='' then return true; end
    if st.next_clue~=body then
        st.next_clue=body;
        st.next_clue_at=os.time();
        HC.modules.state.save();
    end
    return true;
end

local function clear_unmapped_2024(a,group_index,speaker)
    local unmapped=type(a.auto)=='table' and type(a.auto.unmapped_2024)=='table' and a.auto.unmapped_2024 or nil;
    if not unmapped then return; end
    local key=tostring(group_index)..':'..tostring(speaker);
    if unmapped[key]~=nil then
        unmapped[key]=nil;
        HC.modules.state.request_save(1);
    end
end

local function remember_unmapped_2024(a,group_index,speaker,raw)
    local body=dialogue_body(raw); if body=='' then return; end
    -- Keep one bounded observation per NPC lane. This is evidence collection for
    -- future signature mapping only; it never changes completion state.
    a.auto=type(a.auto)=='table' and a.auto or {};
    a.auto.unmapped_2024=type(a.auto.unmapped_2024)=='table' and a.auto.unmapped_2024 or {};
    local key=tostring(group_index)..':'..tostring(speaker);
    local st=type(a.auto.unmapped_2024[key])=='table' and a.auto.unmapped_2024[key] or {};
    local changed=tostring(st.text or '')~=body;
    st.group=group_index; st.speaker=speaker; st.text=body; st.observed_at=os.time(); st.count=(tonumber(st.count) or 0)+1;
    a.auto.unmapped_2024[key]=st;
    if changed then HC.modules.state.request_save(1); end
end

local function on_text(s)
    local c=HC.modules.state.get_char(); local a=ensure(c)
    local raw=tostring(s or '');
    s=raw:lower()

    -- Capture-verified Tracent/Drowsy completion counters. These lines occur
    -- after successful item turn-ins; their following riddle is stored as the
    -- next clue. Riddle-only dialogue never marks completion.
    if line_from_npc(s,'Tracent') then
        local completed,remaining=s:match('bug%s*#([%d,]+)%s+down%.+only%.+([%d,]+)%s+to%s+go');
        if completed and remaining then
            complete_npc_turnin(c,a,'tracent',completed:gsub(',',''),remaining:gsub(',',''),raw);
            return;
        end
        for _,spec in ipairs(TRACENT_DROWSY_RIDDLES.tracent) do
            if s:find(spec.needle,1,true) then
                observe_requested_riddle(c,a,'tracent',spec.index,raw);
                observe_2024_current(c,a,1,'tracent',spec.index,raw,'capture-verified Tracent riddle');
                return;
            end
        end
        if observe_followup_clue(a,'tracent',raw) then return; end
    elseif line_from_npc(s,'Drowsy') then
        local completed,remaining=s:match('quest%s*#([%d,]+)%s+down%.+only%.+([%d,]+)%s+to%s+go');
        if completed and remaining then
            complete_npc_turnin(c,a,'drowsy',completed:gsub(',',''),remaining:gsub(',',''),raw);
            return;
        end
        for _,spec in ipairs(TRACENT_DROWSY_RIDDLES.drowsy) do
            if s:find(spec.needle,1,true) then
                observe_requested_riddle(c,a,'drowsy',spec.index,raw);
                observe_2024_current(c,a,1,'drowsy',spec.index,raw,'capture-verified Drowsy riddle');
                return;
            end
        end
        if observe_followup_clue(a,'drowsy',raw) then return; end
    end

    -- Capture-verified Boyahda successful trades. Kipling and Ah Puch use the
    -- same generic acknowledgement, so an individual item completion is
    -- accepted only when the line can be correlated with a recent 0x020
    -- decrease/removal of one of that speaker's exact requested item IDs.
    if line_from_npc(s,'Kipling') and s:find(BOYAHDA_SUCCESS_NEEDLE,1,true) then
        resolve_boyahda_success(c,a,'kipling',raw);
        return;
    elseif line_from_npc(s,'Ah Puch') and s:find(BOYAHDA_SUCCESS_NEEDLE,1,true) then
        resolve_boyahda_success(c,a,'ahpuch',raw);
        return;
    end

    -- Capture-verified Boyahda lane-completion dialogue.  These signatures are
    -- emitted after all four items for that NPC have been turned in, so they
    -- are authoritative reconciliation evidence even if an earlier individual
    -- trade packet was missed.  The following reward/next-clue line is retained
    -- for diagnostics but is not needed to prove completion.
    if line_from_npc(s,'Kipling') then
        for _,needle in ipairs(BOYAHDA_COMPLETE_SIGNATURES.kipling) do
            if s:find(needle,1,true) then complete_boyahda_lane_from_dialogue(c,a,'kipling',raw); return; end
        end
        if s:find(BOYAHDA_POST_COMPLETE_CLUES.kipling,1,true) and observe_boyahda_post_complete_clue(a,'kipling',raw) then return; end
    elseif line_from_npc(s,'Ah Puch') then
        for _,needle in ipairs(BOYAHDA_COMPLETE_SIGNATURES.ahpuch) do
            if s:find(needle,1,true) then complete_boyahda_lane_from_dialogue(c,a,'ahpuch',raw); return; end
        end
        if s:find(BOYAHDA_POST_COMPLETE_CLUES.ahpuch,1,true) and observe_boyahda_post_complete_clue(a,'ahpuch',raw) then return; end
    end

    -- Capture-verified Boyahda pair request riddles.  Kipling and Ah Puch
    -- each emit all four lane clues together, so this records the requested
    -- item set without calling observe_2024_current() or marking anything done.
    if line_from_npc(s,'Kipling') then
        for _,spec in ipairs(KIPLING_AHPUCH_RIDDLES.kipling) do
            if s:find(spec.needle,1,true) then
                observe_requested_riddle(c,a,'kipling',spec.index,raw);
                clear_unmapped_2024(a,2,'kipling');
                return;
            end
        end
    elseif line_from_npc(s,'Ah Puch') then
        for _,spec in ipairs(KIPLING_AHPUCH_RIDDLES.ahpuch) do
            if s:find(spec.needle,1,true) then
                observe_requested_riddle(c,a,'ahpuch',spec.index,raw);
                clear_unmapped_2024(a,2,'ah puch');
                return;
            end
        end
    end

    -- 2024 main hunt: current-riddle backfill is lane-scoped. For paired
    -- locations the first NPC owns items 1-4 and the second owns 5-8; a current
    -- request can therefore prove only earlier riddles from the same speaker.
    for gi,g in ipairs(Y2024) do
        local speaker=speaker_from_label(s,g.npc);
        if speaker then
            for ii,item in ipairs(g.items) do
                local needle=norm_item_name(type(item)=='table' and item.name or item)
                if needle~='' and s:find(needle,1,true) then
                    if observe_2024_current(c,a,gi,speaker,ii,raw,tostring(speaker)..' current riddle') then
                        a.auto=type(a.auto)=='table' and a.auto or {}
                        local cur=type(a.auto.current_2024)=='table' and a.auto.current_2024 or nil
                        if not cur or tonumber(cur.group)~=gi or tonumber(cur.item)~=ii or tostring(cur.npc or '')~=tostring(speaker) then
                            a.auto.current_2024={group=gi,item=ii,at=os.time(),npc=speaker,source='NPC current-riddle dialogue'}
                            HC.modules.state.request_save(1)
                        end
                        return
                    end
                end
            end
            remember_unmapped_2024(a,gi,speaker,raw)
            return
        end
    end

    -- 2024 Aerec bonus riddles are ordered as well.
    if line_from_npc(s,'Aerec') then
        for ii,item in ipairs(Y2024_BONUS) do
            local needle=norm_item_name(type(item)=='table' and item.name or item)
            if needle~='' and s:find(needle,1,true) then
                mark_2024_bonus_before(c,ii,'Aerec current riddle')
                a.auto=type(a.auto)=='table' and a.auto or {}
                local cur=type(a.auto.current_2024_bonus)=='table' and a.auto.current_2024_bonus or nil
                if not cur or tonumber(cur.item)~=ii then
                    a.auto.current_2024_bonus={item=ii,at=os.time(),source='Aerec current-riddle dialogue'}
                    HC.modules.state.request_save()
                end
                return
            end
        end
    end

    -- 2025 Sehri hunts are random, so historical identities cannot safely be
    -- reconstructed from a count.  We can still auto-check an exact hunt going
    -- forward once Sehri has identified the assignment and the remains message
    -- confirms that assignment was completed.
    if line_from_npc(s,'Sehri') then
        local idx=sehri_target_index(s)
        if idx then
            a.auto=type(a.auto)=='table' and a.auto or {}
            local previous=tonumber(a.auto.sehri_active)
            -- If Sehri assigns a different hunt after we returned, the previous
            -- assignment was necessarily turned in successfully.
            if previous and previous~=idx and a['2025'][previous]~=true then
                a['2025'][previous]=true
                invalidate_anniversary('Sehri advanced to a new hunt');
                HC.msg('Anniversary Sync: previous Sehri hunt marked complete.')
            end
            if tonumber(a.auto.sehri_active)~=idx then
                a.auto.sehri_active=idx; a.auto.sehri_seen_at=os.time(); a.auto.sehri_source='Sehri assignment dialogue'
                HC.modules.state.request_save()
            else
                a.auto.sehri_seen_at=os.time()
            end
            return
        end
    end

    if s:find('remains',1,true) and type(a.auto)=='table' then
        local idx=tonumber(a.auto.sehri_active)
        if idx and Y2025[idx] and a['2025'][idx]~=true then
            a['2025'][idx]=true
            a.auto.sehri_completed_at=os.time()
            HC.modules.state.save()
            invalidate_anniversary('Sehri remains completion');
            HC.msg('Anniversary Sync: Sehri hunt completed - '..tostring(Y2025[idx][1])..'.')
        end
    end
end

function M.draw(c,embedded)
    local imgui=HC.imgui; if not imgui then return; end
    local a=ensure(c);

    local developer=(type(c.settings)=='table' and c.settings.developer_mode==true);
    -- Keep Anniversary evidence capture out of the normal player UI.  In
    -- Developer Mode it sits directly beside the Quest Guide heading.  Every
    -- optional ImGui/helper call is guarded so a binding mismatch cannot abort
    -- the Anniversary draw (or poison the parent UI frame).
    if embedded~=true and type(imgui.Text)=='function' then imgui.Text('HorizonXI Anniversary Quest Guide'); end
    if developer and HC.modules.learning and type(HC.modules.learning.capture_button)=='function' then
        if embedded~=true and type(imgui.SameLine)=='function' then pcall(imgui.SameLine); end
        local ok_capture,capture_err=pcall(HC.modules.learning.capture_button,'anniversary','anniversary_quest_guide',0);
        if not ok_capture and HC.modules.diagnostics and HC.modules.diagnostics.record_error then
            pcall(HC.modules.diagnostics.record_error,'anniversary capture control',capture_err);
        end
    end
    if embedded~=true and type(imgui.Separator)=='function' then imgui.Separator(); end
    if HC.modules.uikit and type(HC.modules.uikit.wrapped_note)=='function' then
        HC.modules.uikit.wrapped_note('Saved per character. Known 2024 riddles track requested items; capture-verified counters confirm turn-ins only where available. 2025 hunts auto-check from Sehri assignment + remains.');
    elseif type(imgui.TextDisabled)=='function' then
        imgui.TextDisabled('Saved per character. Known 2024 riddles track requested items; capture-verified counters confirm turn-ins only where available. 2025 hunts auto-check from Sehri assignment + remains.');
    end
    if developer and HC.modules.learning and type(HC.modules.learning.active)=='function' then
        local ok_active,active=pcall(HC.modules.learning.active);
        if ok_active and active then
            local cur=nil;
            if type(HC.modules.learning.current)=='function' then
                local ok_cur,v=pcall(HC.modules.learning.current); if ok_cur then cur=v; end
            end
            if cur and cur.target=='anniversary' and type(imgui.TextDisabled)=='function' then
                imgui.TextDisabled('CAPTURE ARMED - perform the Anniversary NPC interaction, then click Stop Capture.');
            end
        end
    end

    -- These year rows use HorizonCheck-owned open-state rather than Dear ImGui
    -- CollapsingHeader state. Progress text may change freely after a trade;
    -- the 2024 section stays open until the user explicitly clicks its row.
    local p23=count(a['2023'],#Y2023); local t24=0; for _,g in ipairs(Y2024) do t24=t24+#g.items; end; local p24=count(a['2024'],t24); local p25=count(a['2025'],#Y2025);
    local l23=(HC.modules.uikit and HC.modules.uikit.progress_label) and HC.modules.uikit.progress_label('2023 - 1st Anniversary Scavenger Hunt',p23,#Y2023) or string.format('2023 - 1st Anniversary Scavenger Hunt - %d/%d',p23,#Y2023);
    local l24=(HC.modules.uikit and HC.modules.uikit.progress_label) and HC.modules.uikit.progress_label('2024 - 2nd Anniversary Item Hunt',p24,t24) or string.format('2024 - 2nd Anniversary Item Hunt - %d/%d',p24,t24);
    local l25=(HC.modules.uikit and HC.modules.uikit.progress_label) and HC.modules.uikit.progress_label('2025 - 3rd Anniversary Sehri Hunts',p25,#Y2025) or string.format('2025 - 3rd Anniversary Sehri Hunts - %d/%d',p25,#Y2025);
    if sticky_anniversary_header('year_2023',l23,true) then draw_2023(c,a); end
    anniversary_section_gap();
    if sticky_anniversary_header('year_2024',l24,false) then draw_2024(c,a); end
    anniversary_section_gap();
    if sticky_anniversary_header('year_2025',l25,false) then draw_2025(c,a); end
end

function M.progress(c)
    local a=ensure(c);
    local t24=0; for _,g in ipairs(Y2024) do t24=t24+#g.items; end
    return {
        y2023_done=count(a['2023'],#Y2023), y2023_total=#Y2023,
        y2024_done=count(a['2024'],t24), y2024_total=t24,
        y2025_done=count(a['2025'],#Y2025), y2025_total=#Y2025,
    };
end

function M.valid_2024_pointer(group_index,item_index)
    local g=Y2024[tonumber(group_index) or 0]; local i=tonumber(item_index);
    return g~=nil and i~=nil and i==math.floor(i) and i>=1 and i<=#(g.items or {});
end

function M.automation_status(c)
    local a=ensure(c); local auto=type(a.auto)=='table' and a.auto or {}; local progress=type(auto.npc_progress)=='table' and auto.npc_progress or {};
    local lanes_total=0; local lanes_observed=0; local backfilled=0;
    for gi,g in ipairs(Y2024) do
        for _,speaker in ipairs(npc_names(g.npc)) do
            lanes_total=lanes_total+1;
            local st=progress[tostring(gi)..':'..tostring(speaker)];
            if type(st)=='table' then lanes_observed=lanes_observed+1; backfilled=backfilled+(tonumber(st.backfilled) or 0); end
        end
    end
    local td=type(auto.npc_turnins)=='table' and auto.npc_turnins or {}; local counters=0;
    if type(td.tracent)=='table' and td.tracent.status=='TURN-IN COMPLETE' then counters=counters+1; end
    if type(td.drowsy)=='table' and td.drowsy.status=='TURN-IN COMPLETE' then counters=counters+1; end
    local advancements=0; for _,st in pairs(progress) do if type(st)=='table' then advancements=advancements+(tonumber(st.advancements) or 0); end end
    local unmapped=0; for _ in pairs(type(auto.unmapped_2024)=='table' and auto.unmapped_2024 or {}) do unmapped=unmapped+1; end
    local verified_lanes=0; for _ in pairs(VERIFIED_TURNIN_LANES) do verified_lanes=verified_lanes+1; end
    return {lanes_total=lanes_total,lanes_observed=lanes_observed,backfilled=backfilled,counter_verified=counters,advancements=advancements,unmapped_lanes=unmapped,verified_turnin_lanes=verified_lanes,sehri_active=tonumber(auto.sehri_active)};
end

function M.draw_automation_diagnostics(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local a=ensure(c); local st=M.automation_status(c); local auto=type(a.auto)=='table' and a.auto or {};
    imgui.Text('Anniversary Automation Coverage');
    imgui.TextDisabled(string.format('%d/%d NPC lanes observed | %d safe advancement(s) | %d riddle(s) backfilled',st.lanes_observed or 0,st.lanes_total or 0,st.advancements or 0,st.backfilled or 0));
    imgui.TextDisabled(string.format('%d capture-verified turn-in lane(s) | %d verified counter completion(s) | %d unmapped lane observation(s)',st.verified_turnin_lanes or 0,st.counter_verified or 0,st.unmapped_lanes or 0));
    local reg=M.item_id_registry_status();
    imgui.TextDisabled(string.format('2024 item-ID registry: %d/%d exact resource ID(s) resolved%s',reg.resolved or 0,reg.total or 0,(reg.unresolved or 0)>0 and (' | '..tostring(reg.unresolved)..' name-fallback') or ''));
    imgui.TextDisabled('Unmapped dialogue is stored only as evidence for future signature mapping; it never marks an item complete.');
    local unmapped=type(auto.unmapped_2024)=='table' and auto.unmapped_2024 or {};
    if next(unmapped) and imgui.CollapsingHeader('Unmapped 2024 NPC Dialogue##hc_anniv_unmapped') then
        local keys={}; for k in pairs(unmapped) do keys[#keys+1]=k; end; table.sort(keys);
        for _,k in ipairs(keys) do local r=unmapped[k]; imgui.Text(tostring(r.speaker or k)); imgui.TextDisabled('  '..tostring(r.text or '')); end
    end
end

function M.init(ctx)
    HC=ctx;
    boyahda_build_item_map();
    boyahda_scan_inventory();
    if HC.modules.packets then
        HC.modules.packets.register_text('anniversary auto sync',on_text);
        HC.modules.packets.register(0x020,'anniversary Boyahda inventory correlation',boyahda_on_item_update);
        HC.modules.packets.register(0x01D,'anniversary Boyahda inventory refresh',function() boyahda_scan_inventory(); end);
    end
end
return M;
