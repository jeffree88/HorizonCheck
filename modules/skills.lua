local M = {};
local HC;

-- HorizonXI-era combat skill ranks and cap table (levels 1-75).
-- Live skill values come from Ashita. Caps are calculated from current main job + level.
local JOBS={
    [1]='WAR',[2]='MNK',[3]='WHM',[4]='BLM',[5]='RDM',[6]='THF',[7]='PLD',[8]='DRK',[9]='BST',
    [10]='BRD',[11]='RNG',[12]='SAM',[13]='NIN',[14]='DRG',[15]='SMN',[16]='BLU',[17]='COR',[18]='PUP',
};

-- HorizonXI / classic FFXI cumulative leveling curve through the Lv.75 cap.
-- Overall job progress is EXP-weighted rather than level-count weighted, so
-- later levels correctly represent much more of the 1-75 leveling journey.
local EXP_TO_NEXT_75={
    [1]=500,[2]=750,[3]=1000,[4]=1250,[5]=1500,[6]=1750,[7]=2000,[8]=2200,[9]=2400,[10]=2600,
    [11]=2800,[12]=3000,[13]=3200,[14]=3400,[15]=3600,[16]=3800,[17]=4000,[18]=4200,[19]=4400,[20]=4600,
    [21]=4800,[22]=5000,[23]=5100,[24]=5200,[25]=5300,[26]=5400,[27]=5500,[28]=5600,[29]=5700,[30]=5800,
    [31]=5900,[32]=6000,[33]=6100,[34]=6200,[35]=6300,[36]=6400,[37]=6500,[38]=6600,[39]=6700,[40]=6800,
    [41]=6900,[42]=7000,[43]=7100,[44]=7200,[45]=7300,[46]=7400,[47]=7500,[48]=7600,[49]=7700,[50]=7800,
    [51]=8000,[52]=9200,[53]=10400,[54]=11600,[55]=12800,[56]=14000,[57]=15200,[58]=16400,[59]=17600,[60]=18800,
    [61]=20000,[62]=21500,[63]=23000,[64]=24500,[65]=26000,[66]=27500,[67]=29000,[68]=30500,[69]=32000,[70]=34000,
    [71]=36000,[72]=38000,[73]=40000,[74]=42000,
};
local EXP_AT_LEVEL_75={[1]=0};
local EXP_TOTAL_TO_75=0;
do
    local running=0;
    for level=1,74 do
        running=running+(tonumber(EXP_TO_NEXT_75[level]) or 0);
        EXP_AT_LEVEL_75[level+1]=running;
    end
    EXP_TOTAL_TO_75=running; -- 801,350 EXP from Lv.1 to Lv.75.
end

local function format_number(n)
    n=math.floor(tonumber(n) or 0);
    local str=tostring(n); local sign='';
    if str:sub(1,1)=='-' then sign='-'; str=str:sub(2); end
    local rev=str:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','');
    return sign..rev;
end

local function job_exp_progress(j)
    local level=math.max(1,math.min(75,math.floor(tonumber(j and j.level or 1) or 1)));
    local earned=tonumber(EXP_AT_LEVEL_75[level]) or 0;
    -- Ashita exposes current-level EXP only for the equipped main job. Include
    -- it when present so that job's percentage moves continuously while leveling.
    if level<75 and j and j.exp_current~=nil then
        local within=math.max(0,tonumber(j.exp_current) or 0);
        local need=tonumber(EXP_TO_NEXT_75[level]) or 0;
        if need>0 then within=math.min(within,need); end
        earned=earned+within;
    end
    earned=math.max(0,math.min(EXP_TOTAL_TO_75,earned));
    local pct=(EXP_TOTAL_TO_75>0) and math.floor((earned*100/EXP_TOTAL_TO_75)+0.5) or 0;
    return earned,EXP_TOTAL_TO_75,pct;
end


local JOB_ORDER={
    {1,'WAR','Warrior'},{2,'MNK','Monk'},{3,'WHM','White Mage'},{4,'BLM','Black Mage'},{5,'RDM','Red Mage'},{6,'THF','Thief'},
    {7,'PLD','Paladin'},{8,'DRK','Dark Knight'},{9,'BST','Beastmaster'},{10,'BRD','Bard'},{11,'RNG','Ranger'},{12,'SAM','Samurai'},
    {13,'NIN','Ninja'},{14,'DRG','Dragoon'},{15,'SMN','Summoner'},{16,'BLU','Blue Mage'},{17,'COR','Corsair'},{18,'PUP','Puppetmaster'},
};


-- HorizonXI-era Artifact Armor (head/body/hands/legs/feet) by job.
-- The AF weapon/animator is intentionally not included here; this tracker is
-- for the five-piece armor set shown in Character Info -> Job Progression.
local AF_SETS={
    WAR={"Fighter's Mask","Fighter's Lorica","Fighter's Mufflers","Fighter's Cuisses","Fighter's Calligae"},
    MNK={"Temple Crown","Temple Cyclas","Temple Gloves","Temple Hose","Temple Gaiters"},
    WHM={"Healer's Cap","Healer's Bliaut","Healer's Mitts","Healer's Pantaloons","Healer's Duckbills"},
    BLM={"Wizard's Petasos","Wizard's Coat","Wizard's Gloves","Wizard's Tonban","Wizard's Sabots"},
    RDM={"Warlock's Chapeau","Warlock's Tabard","Warlock's Gloves","Warlock's Tights","Warlock's Boots"},
    THF={"Rogue's Bonnet","Rogue's Vest","Rogue's Armlets","Rogue's Culottes","Rogue's Poulaines"},
    PLD={"Gallant Coronet","Gallant Surcoat","Gallant Gauntlets","Gallant Breeches","Gallant Leggings"},
    DRK={"Chaos Burgeonet","Chaos Cuirass","Chaos Gauntlets","Chaos Flanchard","Chaos Sollerets"},
    BST={"Beast Helm","Beast Jackcoat","Beast Gloves","Beast Trousers","Beast Gaiters"},
    BRD={"Choral Roundlet","Choral Justaucorps","Choral Cuffs","Choral Cannions","Choral Slippers"},
    RNG={"Hunter's Beret","Hunter's Jerkin","Hunter's Bracers","Hunter's Braccae","Hunter's Socks"},
    SAM={"Myochin Kabuto","Myochin Domaru","Myochin Kote","Myochin Haidate","Myochin Sune-Ate"},
    NIN={"Ninja Hatsuburi","Ninja Chainmail","Ninja Tekko","Ninja Hakama","Ninja Kyahan"},
    DRG={"Drachen Armet","Drachen Mail","Drachen Finger Gauntlets","Drachen Brais","Drachen Greaves"},
    SMN={"Evoker's Horn","Evoker's Doublet","Evoker's Bracers","Evoker's Spats","Evoker's Pigaches"},
    BLU={"Magus Keffiyeh","Magus Jubbah","Magus Bazubands","Magus Shalwar","Magus Charuqs"},
    COR={"Corsair's Tricorne","Corsair's Frac","Corsair's Gants","Corsair's Culottes","Corsair's Bottes"},
    PUP={"Puppetry Taj","Puppetry Tobe","Puppetry Dastanas","Puppetry Churidars","Puppetry Babouches"},
};



-- HorizonXI Relic Armor and damaged Relic Armor -1 (head/body/hands/legs/feet).
-- Relic is stored on Storage Slip 06; Relic -1 is stored on Storage Slip 12.
local RELIC_SETS={
    WAR={"Warrior's Mask","Warrior's Lorica","Warrior's Mufflers","Warrior's Cuisses","Warrior's Calligae"},
    MNK={"Melee Crown","Melee Cyclas","Melee Gloves","Melee Hose","Melee Gaiters"},
    WHM={"Cleric's Cap","Cleric's Bliaut","Cleric's Mitts","Cleric's Pantaloons","Cleric's Duckbills"},
    BLM={"Sorcerer's Petasos","Sorcerer's Coat","Sorcerer's Gloves","Sorcerer's Tonban","Sorcerer's Sabots"},
    RDM={"Duelist's Chapeau","Duelist's Tabard","Duelist's Gloves","Duelist's Tights","Duelist's Boots"},
    THF={"Assassin's Bonnet","Assassin's Vest","Assassin's Armlets","Assassin's Culottes","Assassin's Poulaines"},
    PLD={"Valor Coronet","Valor Surcoat","Valor Gauntlets","Valor Breeches","Valor Leggings"},
    DRK={"Abyss Burgeonet","Abyss Cuirass","Abyss Gauntlets","Abyss Flanchard","Abyss Sollerets"},
    BST={"Monster Helm","Monster Jackcoat","Monster Gloves","Monster Trousers","Monster Gaiters"},
    BRD={"Bard's Roundlet","Bard's Justaucorps","Bard's Cuffs","Bard's Cannions","Bard's Slippers"},
    RNG={"Scout's Beret","Scout's Jerkin","Scout's Bracers","Scout's Braccae","Scout's Socks"},
    SAM={"Saotome Kabuto","Saotome Domaru","Saotome Kote","Saotome Haidate","Saotome Sune-Ate"},
    NIN={"Koga Hatsuburi","Koga Chainmail","Koga Tekko","Koga Hakama","Koga Kyahan"},
    DRG={"Wyrm Armet","Wyrm Mail","Wyrm Finger Gauntlets","Wyrm Brais","Wyrm Greaves"},
    SMN={"Summoner's Horn","Summoner's Doublet","Summoner's Bracers","Summoner's Spats","Summoner's Pigaches"},
    BLU={"Mirage Keffiyeh","Mirage Jubbah","Mirage Bazubands","Mirage Shalwar","Mirage Charuqs"},
    COR={"Commodore Tricorne","Commodore Frac","Commodore Gants","Commodore Trews","Commodore Bottes"},
    PUP={"Pantin Taj","Pantin Tobe","Pantin Dastanas","Pantin Churidars","Pantin Babouches"},
};
local AF_PLUS1_SETS={};
-- Dreamworld Dynamis Relic Accessories (Level 70 waist/back pieces).
-- These are part of the Relic set and are stored on Storage Slip 06.
local RELIC_ACCESSORIES={
    WAR="Warrior's Stone", MNK="Melee Cape", WHM="Cleric's Belt", BLM="Sorcerer's Belt", RDM="Duelist's Belt",
    THF="Assassin's Cape", PLD="Valor Cape", DRK="Abyss Cape", BST="Monster Belt", BRD="Bard's Cape",
    RNG="Scout's Belt", SAM="Saotome Koshi-Ate", NIN="Koga Sarashi", DRG="Wyrm Belt", SMN="Summoner's Cape",
    BLU="Mirage Mantle", COR="Commodore Belt", PUP="Pantin Cape",
};

local RELIC_PLUS1_SETS={};
local RELIC_MINUS1_SETS={};
do
    for job,set in pairs(AF_SETS) do
        AF_PLUS1_SETS[job]={};
        for i,piece in ipairs(set) do AF_PLUS1_SETS[job][i]=piece..' +1'; end
    end
    for job,set in pairs(RELIC_SETS) do
        RELIC_PLUS1_SETS[job]={};
        RELIC_MINUS1_SETS[job]={};
        for i,piece in ipairs(set) do
            RELIC_PLUS1_SETS[job][i]=piece..' +1';
            RELIC_MINUS1_SETS[job][i]=piece..' -1';
        end
    end
end

local RELIC_STORAGE_SLIP_ID=29317; -- Storage Slip 06
local RELIC_PLUS1_STORAGE_SLIP_ID=29318; -- Storage Slip 07 (Relic +1)
local RELIC_MINUS1_STORAGE_SLIP_ID=29323; -- Storage Slip 12

-- Exact Porter Moogle slip item order from ThornyFFXI/Porter. Using the real
-- item IDs avoids resource/log-name abbreviation differences completely.
-- Slip 06 is interleaved per job: 5 relic armor pieces + 1 Dreamworld
-- accessory. Slip 07 and Slip 12 are five armor pieces per job.
local RELIC_STORAGE_SLIP_ITEMS={
    15072,15087,15102,15117,15132,15871,15073,15088,15103,15118,15133,15478,
    15074,15089,15104,15119,15134,15872,15075,15090,15105,15120,15135,15874,
    15076,15091,15106,15121,15136,15873,15077,15092,15107,15122,15137,15480,
    15078,15093,15108,15123,15138,15481,15079,15094,15109,15124,15139,15479,
    15080,15095,15110,15125,15140,15875,15081,15096,15111,15126,15141,15482,
    15082,15097,15112,15127,15142,15876,15083,15098,15113,15128,15143,15879,
    15084,15099,15114,15129,15144,15877,15085,15100,15115,15130,15145,15878,
    15086,15101,15116,15131,15146,15484,11465,11292,15025,16346,11382,16244,
    11468,11295,15028,16349,11385,15920,11471,11298,15031,16352,11388,16245,
    11478,11305,15038,16360,11396,16248,11480,11307,15040,16362,11398,15925,
};
local RELIC_PLUS1_STORAGE_SLIP_ITEMS={
    15245,14500,14909,15580,15665,15246,14501,14910,15581,15666,15247,14502,14911,15582,15667,
    15248,14503,14912,15583,15668,15249,14504,14913,15584,15669,15250,14505,14914,15585,15670,
    15251,14506,14915,15586,15671,15252,14507,14916,15587,15672,15253,14508,14917,15588,15673,
    15254,14509,14918,15589,15674,15255,14510,14919,15590,15675,15256,14511,14920,15591,15676,
    15257,14512,14921,15592,15677,15258,14513,14922,15593,15678,15259,14514,14923,15594,15679,
    11466,11293,15026,16347,11383,11469,11296,15029,16350,11386,11472,11299,15032,16353,11389,
    11479,11306,15039,16361,11397,11481,11308,15041,16363,11399,
};
local RELIC_MINUS1_STORAGE_SLIP_ITEMS={
    2033,2034,2035,2036,2037,2038,2039,2040,2041,2042,2043,2044,2045,2046,2047,
    2048,2049,2050,2051,2052,2053,2054,2055,2056,2057,2058,2059,2060,2061,2062,
    2063,2064,2065,2066,2067,2068,2069,2070,2071,2072,2073,2074,2075,2076,2077,
    2078,2079,2080,2081,2082,2083,2084,2085,2086,2087,2088,2089,2090,2091,2092,
    2093,2094,2095,2096,2097,2098,2099,2100,2101,2102,2103,2104,2105,2106,2107,
    2662,2663,2664,2665,2666,2667,2668,2669,2670,2671,2672,2673,2674,2675,2676,
    2718,2719,2720,2721,2722,2723,2724,2725,2726,2727,
};

local RELIC_ITEM_IDS={};
local RELIC_ACCESSORY_ITEM_IDS={};
local RELIC_PLUS1_ITEM_IDS={};
local RELIC_MINUS1_ITEM_IDS={};
do
    for ji,j in ipairs(JOB_ORDER) do
        local job=j[2];
        RELIC_ITEM_IDS[job]={}; RELIC_PLUS1_ITEM_IDS[job]={}; RELIC_MINUS1_ITEM_IDS[job]={};
        local six=(ji-1)*6;
        for slot=1,5 do RELIC_ITEM_IDS[job][slot]=RELIC_STORAGE_SLIP_ITEMS[six+slot]; end
        RELIC_ACCESSORY_ITEM_IDS[job]=RELIC_STORAGE_SLIP_ITEMS[six+6];
        local five=(ji-1)*5;
        for slot=1,5 do
            RELIC_PLUS1_ITEM_IDS[job][slot]=RELIC_PLUS1_STORAGE_SLIP_ITEMS[five+slot];
            RELIC_MINUS1_ITEM_IDS[job][slot]=RELIC_MINUS1_STORAGE_SLIP_ITEMS[five+slot];
        end
    end
end

local MAAT_JOBS={WAR=true,MNK=true,WHM=true,BLM=true,RDM=true,THF=true,PLD=true,DRK=true,BST=true,BRD=true,RNG=true,SAM=true,NIN=true,DRG=true,SMN=true};
local INVENTORY_CONTAINERS={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};

-- Porter Moogle Storage Slip 04 contains the original five-piece artifact
-- armor sets for the 15 pre-ToAU jobs.  The slip stores ownership as a bit
-- mask in the slip item's Extra data; the bit index matches this item list.
-- Reading the slip directly lets AF stored with a Porter Moogle count without
-- requiring the armor to be withdrawn first.
local AF_STORAGE_SLIP_ID=29315;
local AF_PLUS1_STORAGE_SLIP_ID=29316; -- Storage Slip 05 (Artifact +1)
-- Direct item IDs from Porter Storage Slip 05 order.  The first 90 entries
-- cover the 18 Horizon-era jobs shown by HorizonCheck (15 original + BLU/COR/PUP).
-- Using IDs avoids Ashita resource-name abbreviation/localization issues for +1 gear.
local AF_PLUS1_STORAGE_SLIP_ITEMS={
    15225,14473,14890,15561,15352,15226,14474,14891,15562,15353,15227,14475,14892,15563,15354,
    15228,14476,14893,15564,15355,15229,14477,14894,15565,15356,15230,14478,14895,15566,15357,
    15231,14479,14896,15567,15358,15232,14480,14897,15568,15359,15233,14481,14898,15569,15360,
    15234,14482,14899,15570,15361,15235,14483,14900,15362,15571,15236,14484,14901,15572,15363,
    15237,14485,14902,15573,15364,15238,14486,14903,15574,15365,15239,14487,14904,15575,15366,
    11464,11291,15024,16345,11381,11467,11294,15027,16348,11384,11470,11297,15030,16351,11387,
};
local AF_PLUS1_ITEM_IDS={};
do
    local idx=1;
    for _,j in ipairs(JOB_ORDER) do
        AF_PLUS1_ITEM_IDS[j[2]]={};
        for slot=1,5 do
            AF_PLUS1_ITEM_IDS[j[2]][slot]=AF_PLUS1_STORAGE_SLIP_ITEMS[idx];
            idx=idx+1;
        end
    end
end
local AF_STORAGE_SLIP_ITEMS={
    12511,12638,13961,14214,14089,12512,12639,13962,14215,14090,13855,12640,13963,14216,14091,
    13856,12641,13964,14217,14092,12513,12642,13965,14218,14093,12514,12643,13966,14219,14094,
    12515,12644,13967,14220,14095,12516,12645,13968,14221,14096,12517,12646,13969,14222,14097,
    13857,12647,13970,14223,14098,12518,12648,13971,14224,14099,13868,13781,13972,14225,14100,
    13869,13782,13973,14226,14101,12519,12649,13974,14227,14102,12520,12650,13975,14228,14103,
    15265,14521,14928,15600,15684,15266,14522,14929,15601,15685,15267,14523,14930,15602,15686,
};

-- Direct item-id map for the 15 original AF sets.  This avoids depending on
-- resource-manager English names when gear is stored in wardrobes.
local AF_ITEM_IDS={};
do
    local idx=1;
    for _,j in ipairs(JOB_ORDER) do
        AF_ITEM_IDS[j[2]]={};
        for slot=1,5 do
            AF_ITEM_IDS[j[2]][slot]=AF_STORAGE_SLIP_ITEMS[idx];
            idx=idx+1;
        end
    end
end

-- Storage Slip 05 stores Artifact +1 pieces.  Use names here because the
-- slip bit order mirrors the AF armor order and resource IDs vary by client
-- resource set.  A +1 piece counts as completion of the corresponding base AF row.
local AF_PLUS1_SLIP_ORDER={};
do
    for _,j in ipairs(JOB_ORDER) do
        local set=AF_SETS[j[2]];
        if type(set)=='table' then
            for _,piece in ipairs(set) do AF_PLUS1_SLIP_ORDER[#AF_PLUS1_SLIP_ORDER+1]=piece..' +1'; end
        end
    end
end

local CRAFT_ORDER={
    {0,'Fishing'},{1,'Woodworking'},{2,'Smithing'},{3,'Goldsmithing'},{4,'Clothcraft'},
    {5,'Leathercraft'},{6,'Bonecraft'},{7,'Alchemy'},{8,'Cooking'},
};

local CRAFT_RANK_NAMES={
    [0]='Amateur',[1]='Recruit',[2]='Initiate',[3]='Novice',[4]='Apprentice',[5]='Journeyman',
    [6]='Craftsman',[7]='Artisan',[8]='Adept',[9]='Veteran',[10]='Expert',
};

local CAP_BY_RANK={
    ['A+']={6,9,12,15,18,21,24,27,30,33,36,39,42,45,48,51,54,57,60,63,66,69,72,75,78,81,84,87,90,93,96,99,102,105,108,111,114,117,120,123,126,129,132,135,138,141,144,147,150,153,158,163,168,173,178,183,188,193,198,203,207,212,217,222,227,232,236,241,246,251,256,261,266,271,276},
    ['A-']={6,9,12,15,18,21,24,27,30,33,36,39,42,45,48,51,54,57,60,63,66,69,72,75,78,81,84,87,90,93,96,99,102,105,108,111,114,117,120,123,126,129,132,135,138,141,144,147,150,153,158,163,168,173,178,183,188,193,198,203,207,211,215,219,223,227,231,235,239,244,249,254,259,264,269},
    ['B+']={5,7,10,13,16,19,22,25,28,31,34,36,39,42,45,48,51,54,57,60,63,65,68,71,74,77,80,83,86,89,92,94,97,100,103,106,109,112,115,118,121,123,126,129,132,135,138,141,144,147,151,156,161,166,171,176,181,186,191,196,199,203,207,210,214,218,221,225,229,233,237,241,246,251,256},
    ['B']={5,7,10,13,16,19,22,25,28,31,34,36,39,42,45,48,51,54,57,60,63,65,68,71,74,77,80,83,86,89,92,94,97,100,103,106,109,112,115,118,121,123,126,129,132,135,138,141,144,147,151,156,161,166,171,176,181,186,191,196,199,202,205,208,212,215,218,221,225,228,232,236,240,245,250},
    ['B-']={5,7,10,13,16,19,22,25,28,31,34,36,39,42,45,48,51,54,57,60,63,65,68,71,74,77,80,83,86,89,92,94,97,100,103,106,109,112,115,118,121,123,126,129,132,135,138,141,144,147,151,156,161,166,171,176,181,186,191,196,198,201,204,206,209,212,214,217,220,223,226,229,232,236,240},
    ['C+']={5,7,10,13,16,19,21,24,27,30,33,35,38,41,44,47,49,52,55,58,61,63,66,69,72,75,77,80,83,86,89,91,94,97,100,103,105,108,111,114,117,119,122,125,128,131,133,136,139,142,146,151,156,161,166,170,175,180,185,190,192,195,197,200,202,205,207,210,212,215,218,221,224,227,230},
    ['C']={5,7,10,13,16,19,21,24,27,30,33,35,38,41,44,47,49,52,55,58,61,63,66,69,72,75,77,80,83,86,89,91,94,97,100,103,105,108,111,114,117,119,122,125,128,131,133,136,139,142,146,151,156,161,166,170,175,180,185,190,192,194,196,199,201,203,205,208,210,212,214,217,219,222,225},
    ['C-']={5,7,10,13,16,19,21,24,27,30,33,35,38,41,44,47,49,52,55,58,61,63,66,69,72,75,77,80,83,86,89,91,94,97,100,103,105,108,111,114,117,119,122,125,128,131,133,136,139,142,146,151,156,161,166,170,175,180,185,190,192,194,196,198,200,202,204,206,208,210,212,214,216,218,220},
    ['D']={4,6,9,12,14,17,20,22,25,28,31,33,36,39,41,44,47,49,52,55,58,60,63,66,68,71,74,76,79,82,85,87,90,93,95,98,101,103,106,109,112,114,117,120,122,125,128,130,133,136,140,145,150,154,159,164,168,173,178,183,184,186,188,190,192,194,195,197,199,201,203,205,207,208,210},
    ['E']={4,6,9,11,14,16,19,21,24,26,29,31,34,36,39,41,44,46,49,51,54,56,59,61,64,66,69,71,74,76,79,81,84,86,89,91,94,96,99,101,104,106,109,111,114,116,119,121,124,126,130,135,139,144,148,153,157,162,166,171,172,174,176,178,180,182,184,186,188,190,192,194,196,198,200},
    ['F']={4,6,8,10,13,15,17,20,22,24,27,29,31,33,36,38,40,43,45,47,50,52,54,56,59,61,63,66,68,70,73,75,77,79,82,84,86,89,91,93,96,98,100,102,105,107,109,112,114,116,120,124,128,133,137,141,146,150,154,159,161,163,165,167,169,171,173,175,177,179,181,183,185,187,189},
};

local JOB_SKILL_RANKS={
    WAR={['Hand-to-Hand']='D',['Dagger']='B-',['Sword']='B',['Great Sword']='B+',['Axe']='A-',['Great Axe']='A+',['Polearm']='B-',['Club']='B-',['Staff']='B',['Archery']='D',['Marksmanship']='D',['Throwing']='D',['Evasion']='C',['Shield']='C+',['Parrying']='C-'},
    MNK={['Hand-to-Hand']='A+',['Club']='C+',['Staff']='B',['Throwing']='E',['Guarding']='A-',['Evasion']='B+',['Parrying']='E'},
    WHM={['Club']='B+',['Staff']='C+',['Throwing']='E',['Evasion']='E',['Shield']='D',['Divine Magic']='A-',['Healing Magic']='A+',['Enhancing Magic']='C+',['Enfeebling Magic']='C'},
    BLM={['Dagger']='D',['Club']='E',['Staff']='B-',['Throwing']='D',['Evasion']='E',['Dark Magic']='A-',['Elemental Magic']='A+',['Enfeebling Magic']='C+',['Enhancing Magic']='E'},
    RDM={['Dagger']='B',['Sword']='B',['Club']='D',['Archery']='D',['Throwing']='F',['Evasion']='D',['Shield']='F',['Parrying']='E',['Dark Magic']='E',['Divine Magic']='E',['Elemental Magic']='C+',['Enfeebling Magic']='A+',['Enhancing Magic']='B+',['Healing Magic']='C-'},
    THF={['Hand-to-Hand']='E',['Dagger']='A-',['Sword']='D',['Club']='E',['Archery']='C-',['Marksmanship']='C+',['Throwing']='D',['Evasion']='A+',['Shield']='F',['Parrying']='A-'},
    PLD={['Dagger']='C-',['Sword']='A+',['Great Sword']='B',['Polearm']='E',['Club']='A-',['Staff']='A-',['Evasion']='C',['Shield']='A+',['Parrying']='C',['Divine Magic']='B+',['Healing Magic']='C',['Enhancing Magic']='D'},
    DRK={['Dagger']='C',['Sword']='B-',['Great Sword']='A-',['Axe']='C-',['Great Axe']='C+',['Scythe']='A+',['Club']='C-',['Marksmanship']='E',['Evasion']='C',['Parrying']='E',['Dark Magic']='A-',['Elemental Magic']='B+',['Enfeebling Magic']='C'},
    BST={['Dagger']='C+',['Sword']='E',['Axe']='A-',['Scythe']='B-',['Club']='D',['Evasion']='C',['Shield']='E',['Parrying']='C'},
    BRD={['Dagger']='B-',['Sword']='C-',['Club']='D',['Staff']='C+',['Throwing']='E',['Evasion']='D',['Parrying']='E',['Singing']='C',['String Instrument']='C',['Wind Instrument']='C'},
    RNG={['Dagger']='B-',['Sword']='D',['Axe']='B-',['Club']='E',['Archery']='A-',['Marksmanship']='A-',['Throwing']='C-',['Evasion']='E'},
    SAM={['Dagger']='E',['Sword']='C+',['Great Katana']='A+',['Polearm']='B-',['Club']='E',['Archery']='C+',['Throwing']='C',['Evasion']='B+',['Parrying']='A-'},
    NIN={['Hand-to-Hand']='E',['Dagger']='C+',['Sword']='C',['Great Katana']='C-',['Katana']='A-',['Club']='E',['Archery']='E',['Marksmanship']='C',['Throwing']='A-',['Evasion']='A-',['Parrying']='A-',['Ninjutsu']='A-'},
    DRG={['Dagger']='E',['Sword']='C-',['Polearm']='A+',['Club']='E',['Staff']='B-',['Evasion']='C-',['Parrying']='C'},
    SMN={['Dagger']='E',['Club']='E',['Staff']='B',['Evasion']='E',['Summoning Magic']='A-'},
    BLU={['Sword']='A+',['Club']='B-',['Evasion']='C-',['Parrying']='D',['Blue Magic']='A+'},
    COR={['Dagger']='B+',['Sword']='B-',['Marksmanship']='B',['Throwing']='C+',['Evasion']='D',['Parrying']='A-'},
    PUP={['Hand-to-Hand']='B',['Dagger']='C-',['Club']='D',['Throwing']='C+',['Guarding']='B-',['Evasion']='B',['Parrying']='D'},
};

local GROUPS = {
    { title='Weapons', rows={
        {1,'Hand-to-Hand','Hand-to-Hand'},{2,'Dagger','Dagger'},{3,'Sword','Sword'},{4,'Great Sword','Great Sword'},
        {5,'Axe','Axe'},{6,'Great Axe','Great Axe'},{7,'Scythe','Scythe'},{8,'Polearm','Polearm'},
        {9,'Katana','Katana'},{10,'Great Katana','Great Katana'},{11,'Club','Club'},{12,'Staff','Staff'},
        {25,'Archery','Archery'},{26,'Marksmanship','Marksmanship'},{27,'Throwing','Throwing'},
    }},
    { title='Defensive', rows={{28,'Guarding','Guarding'},{29,'Evasion','Evasion'},{30,'Shield','Shield'},{31,'Parrying','Parrying'}} },
    { title='Magic', rows={
        {32,'Divine Magic','Divine'},{33,'Healing Magic','Healing'},{34,'Enhancing Magic','Enhancing'},{35,'Enfeebling Magic','Enfeebling'},
        {36,'Elemental Magic','Elemental'},{37,'Dark Magic','Dark'},{38,'Summoning Magic','Summon'},{39,'Ninjutsu','Ninjutsu'},
        {40,'Singing','Singing'},{41,'String Instrument','String'},{42,'Wind Instrument','Wind'},{43,'Blue Magic','Blue Magic'},
    }},
    { title='Automaton', rows={{22,'Automaton Melee','Automaton Melee'},{23,'Automaton Ranged','Automaton Ranged'},{24,'Automaton Magic','Automaton Magic'}} },
};

local by_name={};
for _,group in ipairs(GROUPS) do
    for _,row in ipairs(group.rows) do
        by_name[string.lower(row[2])]=row;
        by_name[string.lower(row[3])]=row;
    end
end

local function get_player()
    local player=nil;
    local ok=pcall(function()
        if not AshitaCore or not AshitaCore.GetMemoryManager then return; end
        local mm=AshitaCore:GetMemoryManager();
        player=mm and mm:GetPlayer() or nil;
    end);
    if not ok then return nil; end
    return player;
end


local function add_resource_item_names(out,item_id)
    item_id=tonumber(item_id);
    if not item_id or type(out)~='table' then return; end
    pcall(function()
        local rm=AshitaCore and AshitaCore.GetResourceManager and AshitaCore:GetResourceManager() or nil;
        if not rm or not rm.GetItemById then return; end
        local item=rm:GetItemById(item_id);
        if not item then return; end
        local function add(v)
            if type(v)=='string' and v~='' then out[string.lower(v)]=true; end
        end
        local function add_field(v)
            if type(v)=='string' then add(v);
            elseif type(v)=='table' then
                for _,x in pairs(v) do add(x); end
            end
        end
        -- Ashita resource layouts differ between builds.  Name may be a
        -- localized table while LogName / SingularName can hold the English
        -- display text, so keep every string alias the resource exposes.
        add_field(item.Name);
        add_field(item.LogName);
        add_field(item.SingularName);
        add_field(item.PluralName);
        add_field(item.DisplayName);
    end);
end

local function normalize_item_name(v)
    local s=string.lower(tostring(v or ''));
    s=s:gsub('[’‘`]',"'");
    s=s:gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$','');
    return s;
end

-- Ashita / FFXI resource names are not always the same strings shown in the
-- UI.  In particular, log/resource aliases frequently abbreviate gear names
-- (for example: "War. Calligae -1", "Clr. Duckbills", or shortened
-- words such as "Pantaln.").  Match those aliases safely without requiring
-- a hand-maintained abbreviation list for every AF/relic piece.
local function item_name_parts(v)
    local s=normalize_item_name(v);
    local upgrade='base';
    if s:match('%+%s*1%s*$') then upgrade='plus1'; s=s:gsub('%+%s*1%s*$','');
    elseif s:match('%-%s*1%s*$') then upgrade='minus1'; s=s:gsub('%-%s*1%s*$',''); end
    s=s:gsub("'s",'s');
    s=s:gsub('[^%w]+',' '):gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$','');
    local tokens={};
    for tok in s:gmatch('%w+') do tokens[#tokens+1]=tok; end
    return tokens,upgrade;
end

local function token_is_subsequence(shorter,longer)
    shorter=tostring(shorter or ''); longer=tostring(longer or '');
    if #shorter<3 or #longer<#shorter or shorter:sub(1,1)~=longer:sub(1,1) then return false; end
    local j=1;
    for i=1,#longer do
        if longer:sub(i,i)==shorter:sub(j,j) then
            j=j+1;
            if j>#shorter then return true; end
        end
    end
    return false;
end

local function item_name_equivalent(canonical,observed)
    local a,ua=item_name_parts(canonical);
    local b,ub=item_name_parts(observed);
    if ua~=ub or #a~=#b or #a==0 then return false; end
    for i=1,#a do
        local x,y=a[i],b[i];
        if x~=y then
            local shorter,longer=x,y;
            if #shorter>#longer then shorter,longer=longer,shorter; end
            if not token_is_subsequence(shorter,longer) then return false; end
        end
    end
    return true;
end

local function extra_byte(extra,pos)
    pos=tonumber(pos);
    if not extra or not pos or pos<1 then return nil; end
    local v=nil;
    -- Ashita exposes Extra as a binary string-like object on current builds.
    -- Keep several access paths so Horizon/Ashita revisions do not break the
    -- slip decoder.
    pcall(function()
        if type(extra)=='string' then v=string.byte(extra,pos); return; end
        if extra.byte then v=extra:byte(pos); return; end
        if extra.totable then
            local t=extra:totable();
            v=t and tonumber(t[pos]) or nil;
            return;
        end
        v=tonumber(extra[pos-1] or extra[pos]);
    end);
    if v and v<0 then v=v+256; end
    return v;
end

local function add_porter_af_from_slip(names,stored_names,stored_ids,item)
    if not item or tonumber(item.Id)~=AF_STORAGE_SLIP_ID then return false; end
    local extra=item.Extra;
    if not extra then return false; end
    local decoded=false;
    for storage_index,item_id in ipairs(AF_STORAGE_SLIP_ITEMS) do
        local bit_index=storage_index-1;
        local b=extra_byte(extra,math.floor(bit_index/8)+1);
        if b then
            decoded=true;
            local flag=math.floor(b/(2^(bit_index%8)))%2;
            if flag==1 then
                add_resource_item_names(names,item_id);
                add_resource_item_names(stored_names,item_id);
                if type(stored_ids)=='table' then stored_ids[item_id]=true; end
            end
        end
    end
    return decoded;
end


local function add_porter_id_slip(names,stored_names,stored_ids,item,slip_id,ordered_ids)
    if not item or tonumber(item.Id)~=tonumber(slip_id) then return false; end
    local extra=item.Extra; if not extra then return false; end
    local decoded=false;
    for storage_index,item_id in ipairs(ordered_ids or {}) do
        local bit_index=storage_index-1;
        local b=extra_byte(extra,math.floor(bit_index/8)+1);
        if b then
            decoded=true;
            local flag=math.floor(b/(2^(bit_index%8)))%2;
            if flag==1 and tonumber(item_id) then
                item_id=tonumber(item_id);
                if type(stored_ids)=='table' then stored_ids[item_id]=true; end
                add_resource_item_names(names,item_id);
                add_resource_item_names(stored_names,item_id);
            end
        end
    end
    return decoded;
end

local function add_porter_named_slip(names,stored_names,item,slip_id,ordered_names)
    if not item or tonumber(item.Id)~=tonumber(slip_id) then return false; end
    local extra=item.Extra; if not extra then return false; end
    local decoded=false;
    for storage_index,piece in ipairs(ordered_names or {}) do
        local bit_index=storage_index-1;
        local b=extra_byte(extra,math.floor(bit_index/8)+1);
        if b then
            decoded=true;
            local flag=math.floor(b/(2^(bit_index%8)))%2;
            if flag==1 then
                local key=normalize_item_name(piece);
                names[key]=true; stored_names[key]=true;
            end
        end
    end
    return decoded;
end

-- Character Info progression can render every frame, but a full inventory/wardrobe scan is
-- expensive (17 containers x up to 81 slots plus resource lookups).  Cache the
-- scan for a few seconds and allow the UI to explicitly invalidate it.
local GEAR_SCAN_TTL=5;
local gear_scan_cache={at=0,update_counter=nil};
local gear_alias_match_cache={};

local function invalidate_gear_scan_cache()
    gear_scan_cache={at=0,update_counter=nil};
    gear_alias_match_cache={};
end

local function inventory_update_counter()
    local value=nil;
    pcall(function()
        if not AshitaCore or not AshitaCore.GetMemoryManager then return; end
        local mm=AshitaCore:GetMemoryManager();
        local inv=mm and mm:GetInventory() or nil;
        if inv and inv.GetContainerUpdateCounter then
            value=tonumber(inv:GetContainerUpdateCounter());
        end
    end);
    return value;
end

local function owned_item_name_set(force)
    local now=os.time();
    local update_counter=inventory_update_counter();
    local cache_current=(update_counter==nil or gear_scan_cache.update_counter==nil or update_counter==gear_scan_cache.update_counter);
    if not force and cache_current and gear_scan_cache.at and (now-tonumber(gear_scan_cache.at or 0))<GEAR_SCAN_TTL and gear_scan_cache.names then
        if HC.modules.profiler and HC.modules.profiler.cache then HC.modules.profiler.cache('inventory.collection_scan',true); end
        return gear_scan_cache.names,gear_scan_cache.available,gear_scan_cache.stored_names,gear_scan_cache.slip_seen,gear_scan_cache.slip_decoded,gear_scan_cache.owned_ids,gear_scan_cache.stored_ids,gear_scan_cache.owned_containers,gear_scan_cache.owned_counts,gear_scan_cache.owned_container_counts;
    end
    if HC.modules.profiler and HC.modules.profiler.cache then HC.modules.profiler.cache('inventory.collection_scan',false); end
    if HC.modules.profiler and HC.modules.profiler.bump then HC.modules.profiler.bump('inventory.full_scan'); end
    gear_alias_match_cache={};
    local names={}; local owned_ids={}; local owned_containers={}; local owned_counts={}; local owned_container_counts={}; local stored_names={}; local stored_ids={}; local available=false; local slip_seen=false; local slip_decoded=false;
    pcall(function()
        if not AshitaCore or not AshitaCore.GetMemoryManager then return; end
        local mm=AshitaCore:GetMemoryManager();
        local inv=mm and mm:GetInventory() or nil;
        if not inv or not inv.GetContainerItem then return; end
        available=true;
        for _,cid in ipairs(INVENTORY_CONTAINERS) do
            local mx=nil;
            if inv.GetContainerCountMax then
                pcall(function() mx=tonumber(inv:GetContainerCountMax(cid)); end);
            end
            -- Some Horizon/Ashita builds report 0 for inactive wardrobe
            -- containers even though GetContainerItem can still read them.
            -- Wardrobes are 80-slot containers, so always probe at least 0..80.
            if not mx or mx<80 then mx=80; end
            for idx=0,mx do
                local e=nil;
                pcall(function() e=inv:GetContainerItem(cid,idx); end);
                local id=e and tonumber(e.Id) or nil;
                if id and id>0 then
                    owned_ids[id]=true;
                    owned_containers[id]=cid;
                    local stack_count=math.max(1,tonumber(e.Count) or 1);
                    owned_counts[id]=(tonumber(owned_counts[id]) or 0)+stack_count;
                    owned_container_counts[id]=type(owned_container_counts[id])=='table' and owned_container_counts[id] or {};
                    owned_container_counts[id][cid]=(tonumber(owned_container_counts[id][cid]) or 0)+stack_count;
                    add_resource_item_names(names,id);
                    if id==AF_STORAGE_SLIP_ID then
                        slip_seen=true;
                        if add_porter_af_from_slip(names,stored_names,stored_ids,e) then slip_decoded=true; end
                    elseif id==AF_PLUS1_STORAGE_SLIP_ID then
                        slip_seen=true;
                        if add_porter_id_slip(names,stored_names,stored_ids,e,AF_PLUS1_STORAGE_SLIP_ID,AF_PLUS1_STORAGE_SLIP_ITEMS) then slip_decoded=true; end
                    elseif id==RELIC_STORAGE_SLIP_ID then
                        slip_seen=true;
                        if add_porter_id_slip(names,stored_names,stored_ids,e,RELIC_STORAGE_SLIP_ID,RELIC_STORAGE_SLIP_ITEMS) then slip_decoded=true; end
                    elseif id==RELIC_PLUS1_STORAGE_SLIP_ID then
                        slip_seen=true;
                        if add_porter_id_slip(names,stored_names,stored_ids,e,RELIC_PLUS1_STORAGE_SLIP_ID,RELIC_PLUS1_STORAGE_SLIP_ITEMS) then slip_decoded=true; end
                    elseif id==RELIC_MINUS1_STORAGE_SLIP_ID then
                        slip_seen=true;
                        if add_porter_id_slip(names,stored_names,stored_ids,e,RELIC_MINUS1_STORAGE_SLIP_ID,RELIC_MINUS1_STORAGE_SLIP_ITEMS) then slip_decoded=true; end
                    end
                end
            end
        end
    end);
    gear_scan_cache={
        at=now,update_counter=update_counter,names=names,available=available,stored_names=stored_names,
        slip_seen=slip_seen,slip_decoded=slip_decoded,owned_ids=owned_ids,stored_ids=stored_ids,owned_containers=owned_containers,owned_counts=owned_counts,
        owned_container_counts=owned_container_counts,
    };
    return names,available,stored_names,slip_seen,slip_decoded,owned_ids,stored_ids,owned_containers,owned_counts,owned_container_counts;
end

local function exact_piece_owned(names,piece)
    if type(names)~='table' then return false; end
    local key=normalize_item_name(piece);
    if names[key]==true then return true; end
    local cache_key=tostring(names)..'|'..key;
    local cached=gear_alias_match_cache[cache_key];
    if cached~=nil then return cached==true; end
    for n,_ in pairs(names) do
        if normalize_item_name(n)==key or item_name_equivalent(piece,n) then
            gear_alias_match_cache[cache_key]=true;
            return true;
        end
    end
    gear_alias_match_cache[cache_key]=false;
    return false;
end

local function exact_piece_location(names,stored_names,owned_ids,stored_ids,piece,direct_id)
    -- Prefer known direct item IDs when a set provides them.  For entries such
    -- as Dreamworld relic accessories that do not have a hard-coded ID table,
    -- fall back to the normalized resource names collected during the cached
    -- inventory/wardrobe scan.  Do not call a global name->ID helper here;
    -- older Ashita builds do not expose one and v6.84.22 could error every frame.
    direct_id=tonumber(direct_id);
    if direct_id and type(stored_ids)=='table' and stored_ids[direct_id]==true then return 'STORED'; end
    if direct_id and type(owned_ids)=='table' and owned_ids[direct_id]==true then return 'OBTAINED'; end
    if not exact_piece_owned(names,piece) then return nil; end
    if type(stored_names)=='table' and exact_piece_owned(stored_names,piece) then return 'STORED'; end
    return 'OBTAINED';
end


-- Shared collection lookup used by non-gear trackers (seasonal rewards, etc.).
-- It reuses the cached 17-container scan so opening another tracker does not
-- introduce another full inventory/wardrobe walk every frame.
local COLLECTION_CONTAINER_LABELS={
    [0]='INVENTORY',[1]='SAFE',[2]='STORAGE',[3]='TEMP',[4]='LOCKER',[5]='SATCHEL',[6]='SACK',[7]='CASE',
    [8]='WARDROBE 1',[9]='WARDROBE 5',[10]='WARDROBE 2',[11]='WARDROBE 3',[12]='WARDROBE 4',
    [13]='WARDROBE 6',[14]='WARDROBE 7',[15]='WARDROBE 8',[16]='WARDROBE 8',
};

local collection_resource_id_cache={}

local function resource_item_id_by_name(name)
    local result=nil;
    name=tostring(name or '');
    if name=='' then return nil; end
    local cache_key=normalize_item_name(name);
    local cached=collection_resource_id_cache[cache_key];
    if cached~=nil then return cached~=false and cached or nil; end
    pcall(function()
        local rm=AshitaCore and AshitaCore.GetResourceManager and AshitaCore:GetResourceManager() or nil;
        if not rm or not rm.GetItemByName then return; end
        local item=rm:GetItemByName(name,0);
        if not item then item=rm:GetItemByName(name,2); end
        if not item then return; end
        result=tonumber(item.ItemId) or tonumber(item.Id) or tonumber(item.ID);
    end);
    collection_resource_id_cache[cache_key]=result or false;
    return result;
end

function M.collection_resolve_ids(item_names)
    local list=type(item_names)=='table' and item_names or {item_names};
    local out={}; local seen={};
    for _,piece in ipairs(list) do
        local id=resource_item_id_by_name(tostring(piece or ''));
        if id and not seen[id] then out[#out+1]=id; seen[id]=true; end
    end
    return out;
end

function M.collection_item_location_ids(item_ids,item_names,force)
    local names,available,stored_names,_,_,owned_ids,stored_ids,owned_containers=owned_item_name_set(force==true);
    if available~=true then return nil,false,nil; end
    for _,id in ipairs(type(item_ids)=='table' and item_ids or {}) do
        id=tonumber(id);
        if id and type(stored_ids)=='table' and stored_ids[id]==true then return 'STORED',true,id; end
        if id and type(owned_ids)=='table' and owned_ids[id]==true then
            local cid=type(owned_containers)=='table' and tonumber(owned_containers[id]) or nil;
            return COLLECTION_CONTAINER_LABELS[cid] or 'OBTAINED',true,id;
        end
    end
    if item_names~=nil then
        local list=type(item_names)=='table' and item_names or {item_names};
        for _,piece in ipairs(list) do
            local label=tostring(piece or '');
            local loc=exact_piece_location(names,stored_names,owned_ids,stored_ids,label,nil);
            if loc then return loc,true,label; end
        end
    end
    return nil,true,nil;
end

function M.collection_item_location(item_names,force)
    local names,available,stored_names,_,_,owned_ids,stored_ids,owned_containers=owned_item_name_set(force==true);
    if available~=true then return nil,false,nil; end
    local list=type(item_names)=='table' and item_names or {item_names};
    for _,piece in ipairs(list) do
        local label=tostring(piece or '');
        -- Prefer an exact resource-name -> item-id lookup. This avoids Ashita
        -- resource Name fields that are exposed as FFI arrays/userdata rather
        -- than ordinary Lua strings, which caused collection-only trackers to
        -- miss Wardrobe items even though the container scan saw their IDs.
        local item_id=resource_item_id_by_name(label);
        if item_id and type(stored_ids)=='table' and stored_ids[item_id]==true then
            return 'STORED',true,label;
        end
        if item_id and type(owned_ids)=='table' and owned_ids[item_id]==true then
            local cid=type(owned_containers)=='table' and tonumber(owned_containers[item_id]) or nil;
            return COLLECTION_CONTAINER_LABELS[cid] or 'OBTAINED',true,label;
        end
        -- Keep normalized-name matching as a fallback for aliases that the
        -- resource manager does not resolve directly on a given client build.
        local loc=exact_piece_location(names,stored_names,owned_ids,stored_ids,label,nil);
        if loc then return loc,true,label; end
    end
    return nil,true,nil;
end

function M.collection_item_count(item_names,force)
    local _,available,_,_,_,_,_,_,owned_counts=owned_item_name_set(force==true);
    if available~=true then return nil,false,nil; end
    local list=type(item_names)=='table' and item_names or {item_names};
    local total=0; local matched=nil;
    for _,piece in ipairs(list) do
        local label=tostring(piece or '');
        local item_id=resource_item_id_by_name(label);
        if item_id then
            local count=tonumber(type(owned_counts)=='table' and owned_counts[item_id] or 0) or 0;
            if count>0 then matched=matched or label; end
            total=total+math.max(0,count);
        end
    end
    return total,true,matched;
end

-- Returns the physical container breakdown for collection items without
-- performing another inventory walk. This shares the cached collection scan
-- used by collection_item_count/location, so callers can show both a total and
-- exactly where those stacks are stored.
function M.collection_item_locations(item_names,force)
    local _,available,_,_,_,_,_,_,_,owned_container_counts=owned_item_name_set(force==true);
    if available~=true then return {},false,nil,0; end
    local list=type(item_names)=='table' and item_names or {item_names};
    local by_container={}; local matched=nil; local seen_ids={}; local total=0;
    for _,piece in ipairs(list) do
        local label=tostring(piece or '');
        local item_id=resource_item_id_by_name(label);
        if item_id and not seen_ids[item_id] then
            seen_ids[item_id]=true;
            local bins=type(owned_container_counts)=='table' and owned_container_counts[item_id] or nil;
            if type(bins)=='table' then
                for cid,count in pairs(bins) do
                    count=math.max(0,tonumber(count) or 0);
                    if count>0 then
                        cid=tonumber(cid);
                        by_container[cid]=(tonumber(by_container[cid]) or 0)+count;
                        total=total+count;
                        matched=matched or label;
                    end
                end
            end
        end
    end
    local rows={}; local emitted={};
    for _,cid in ipairs(INVENTORY_CONTAINERS) do
        cid=tonumber(cid);
        local count=math.max(0,tonumber(by_container[cid]) or 0);
        if count>0 then
            rows[#rows+1]={container_id=cid,label=COLLECTION_CONTAINER_LABELS[cid] or ('CONTAINER '..tostring(cid)),count=count};
            emitted[cid]=true;
        end
    end
    -- Defensive fallback in case a future Horizon/Ashita container id is added
    -- to the scanner before INVENTORY_CONTAINERS is updated here.
    for cid,count in pairs(by_container) do
        if not emitted[cid] and count>0 then
            rows[#rows+1]={container_id=cid,label=COLLECTION_CONTAINER_LABELS[cid] or ('CONTAINER '..tostring(cid)),count=count};
        end
    end
    return rows,true,matched,total;
end

function M.collection_scan_available(force)
    local _,available=owned_item_name_set(force==true);
    return available==true;
end

function M.collection_scan_token()
    -- Collection consumers need a token that changes only when the inventory
    -- state changes.  Do not include gear_scan_cache.at here: that timestamp
    -- advances whenever the shared five-second cache is rebuilt and previously
    -- made the Account Item Locator believe inventory changed every ~10 seconds,
    -- causing an unnecessary 17-container snapshot rebuild and visible stutter.
    local update_counter=inventory_update_counter();
    if update_counter~=nil then return 'inv:'..tostring(update_counter); end
    -- Older Ashita builds may not expose GetContainerUpdateCounter.  Keep a
    -- stable fallback token; itemlocator.lua performs a very low-frequency
    -- safety refresh for that case rather than forcing rhythmic scans.
    return 'inv:na';
end

local function collection_resource_aliases(item_id)
    local out={}; local seen={};
    item_id=tonumber(item_id);
    if not item_id then return out; end

    local function readable_resource_name(v)
        if type(v)~='string' then return nil; end
        v=v:gsub('%z',''):gsub('^%s+',''):gsub('%s+$','');
        if #v<2 or #v>96 then return nil; end
        local controls=0; local weird=0; local letters=0; local qmarks=0; local hashes=0;
        for i=1,#v do
            local b=v:byte(i);
            if b<32 or b==127 then controls=controls+1;
            elseif b>=128 then weird=weird+1; end
        end
        for _ in v:gmatch('[A-Za-z]') do letters=letters+1; end
        for _ in v:gmatch('%?') do qmarks=qmarks+1; end
        for _ in v:gmatch('#') do hashes=hashes+1; end
        if controls>0 or weird>2 or qmarks>1 or hashes>1 then return nil; end
        if letters<2 and not v:match('%d+%s+[A-Za-z]') then return nil; end
        if v:match('^%?+%s*') then return nil; end
        return v;
    end

    local function add(v)
        v=readable_resource_name(v);
        if v then
            local key=string.lower(v);
            if not seen[key] then seen[key]=true; out[#out+1]=v; end
        end
    end
    local function read_field(v)
        if type(v)=='string' then add(v); return; end
        if type(v)=='table' then for _,x in pairs(v) do add(x); end; return; end
        -- Some Ashita resource builds expose fixed char arrays/userdata rather
        -- than Lua strings/tables. Probe common localized indexes and ffi.string
        -- without making either representation mandatory.
        if v~=nil then
            pcall(function() add(v[1]); end);
            pcall(function() add(v[0]); end);
            pcall(function()
                local okffi,ffi=pcall(require,'ffi');
                if okffi and ffi and ffi.string then add(ffi.string(v)); end
            end);
        end
    end
    pcall(function()
        local rm=AshitaCore and AshitaCore.GetResourceManager and AshitaCore:GetResourceManager() or nil;
        if not rm or not rm.GetItemById then return; end
        local item=rm:GetItemById(item_id); if not item then return; end
        read_field(item.SingularName); read_field(item.Name); read_field(item.LogName);
        read_field(item.DisplayName); read_field(item.PluralName);
    end);
    return out;
end

local function collection_display_name(item_id)
    local aliases=collection_resource_aliases(item_id);
    if #aliases>0 then
        -- Prefer a readable English-ish alias rather than abbreviated log text
        -- when multiple resource fields are available.
        table.sort(aliases,function(a,b)
            local aa,bb=#tostring(a),#tostring(b);
            if aa~=bb then return aa>bb; end
            return string.lower(tostring(a))<string.lower(tostring(b));
        end);
        return aliases[1],aliases;
    end
    return 'Item '..tostring(item_id),{};
end

-- Compact physical/storage inventory snapshot for account-wide item lookup.
-- This reuses the existing cached collection scan and does not introduce a
-- second container walk.  The snapshot is persisted by itemlocator.lua only
-- when the inventory update token changes.
function M.collection_inventory_snapshot(force)
    local _,available,_,_,_,owned_ids,stored_ids,_,owned_counts,owned_container_counts=owned_item_name_set(force==true);
    if available~=true then return {available=false,at=os.time(),token=M.collection_scan_token(),rows={}}; end
    local ids={}; local seen={};
    for id in pairs(type(owned_ids)=='table' and owned_ids or {}) do
        id=tonumber(id); if id and id>0 and not seen[id] then seen[id]=true; ids[#ids+1]=id; end
    end
    for id in pairs(type(stored_ids)=='table' and stored_ids or {}) do
        id=tonumber(id); if id and id>0 and not seen[id] then seen[id]=true; ids[#ids+1]=id; end
    end
    table.sort(ids);
    local rows={};
    for _,id in ipairs(ids) do
        local locs={};
        local bins=type(owned_container_counts)=='table' and owned_container_counts[id] or nil;
        if type(bins)=='table' then
            local cids={}; for cid in pairs(bins) do cids[#cids+1]=tonumber(cid); end; table.sort(cids);
            for _,cid in ipairs(cids) do
                local count=math.max(0,tonumber(bins[cid]) or 0);
                if count>0 then
                    local label=COLLECTION_CONTAINER_LABELS[cid] or ('CONTAINER '..tostring(cid));
                    locs[#locs+1]=label..(count>1 and (' x'..tostring(count)) or '');
                end
            end
        end
        if type(stored_ids)=='table' and stored_ids[id]==true then locs[#locs+1]='PORTER MOOGLE'; end
        local count=math.max(0,tonumber(type(owned_counts)=='table' and owned_counts[id] or 0) or 0);
        if count==0 and type(stored_ids)=='table' and stored_ids[id]==true then count=1; end
        local display_name,aliases=collection_display_name(id);
        rows[#rows+1]={
            id=id,
            name=display_name,
            aliases=aliases,
            count=count,
            location=(#locs>0 and table.concat(locs,', ') or 'OBTAINED'),
        };
    end
    table.sort(rows,function(a,b) return string.lower(tostring(a.name))<string.lower(tostring(b.name)); end);
    return {available=true,at=os.time(),token=M.collection_scan_token(),rows=rows};
end

function M.refresh_collection_scan()
    invalidate_gear_scan_cache();
    owned_item_name_set(true);
    return true;
end

local function af_piece_location_for_job(names,stored_names,owned_ids,stored_ids,job,piece_index,piece)
    local ids=AF_ITEM_IDS[tostring(job or '')];
    local item_id=ids and tonumber(ids[tonumber(piece_index or 0)]);
    return exact_piece_location(names,stored_names,owned_ids,stored_ids,piece,item_id);
end

local function af_plus1_piece_location_for_job(names,stored_names,owned_ids,stored_ids,job,piece_index,piece)
    local ids=AF_PLUS1_ITEM_IDS[tostring(job or '')];
    local item_id=ids and tonumber(ids[tonumber(piece_index or 0)]);
    return exact_piece_location(names,stored_names,owned_ids,stored_ids,piece,item_id);
end

local function relic_piece_location_for_job(names,stored_names,owned_ids,stored_ids,job,piece_index,piece)
    local ids=RELIC_ITEM_IDS[tostring(job or '')];
    local item_id=ids and tonumber(ids[tonumber(piece_index or 0)]);
    return exact_piece_location(names,stored_names,owned_ids,stored_ids,piece,item_id);
end

local function relic_plus1_piece_location_for_job(names,stored_names,owned_ids,stored_ids,job,piece_index,piece)
    local ids=RELIC_PLUS1_ITEM_IDS[tostring(job or '')];
    local item_id=ids and tonumber(ids[tonumber(piece_index or 0)]);
    return exact_piece_location(names,stored_names,owned_ids,stored_ids,piece,item_id);
end

local function upgraded_base_progress_location(base_location,upgrade_location)
    -- Upgrading an AF or Relic piece consumes the base item, but the +1 is
    -- permanent historical proof that the base piece was obtained. Preserve
    -- a direct base location when one still exists while also identifying the
    -- slot as upgraded for the progression display.
    if upgrade_location then
        if base_location then return tostring(base_location)..' + UPGRADED'; end
        return 'UPGRADED';
    end
    return base_location;
end

local function af_base_progress_location_for_job(names,stored_names,owned_ids,stored_ids,job,piece_index,piece)
    local base_location=af_piece_location_for_job(names,stored_names,owned_ids,stored_ids,job,piece_index,piece);
    local plus_set=AF_PLUS1_SETS[tostring(job or '')];
    local plus_piece=plus_set and plus_set[tonumber(piece_index or 0)] or nil;
    local upgrade_location=plus_piece and af_plus1_piece_location_for_job(
        names,stored_names,owned_ids,stored_ids,job,piece_index,plus_piece) or nil;
    return upgraded_base_progress_location(base_location,upgrade_location);
end

local function relic_base_progress_location_for_job(names,stored_names,owned_ids,stored_ids,job,piece_index,piece)
    local base_location=relic_piece_location_for_job(names,stored_names,owned_ids,stored_ids,job,piece_index,piece);
    local plus_set=RELIC_PLUS1_SETS[tostring(job or '')];
    local plus_piece=plus_set and plus_set[tonumber(piece_index or 0)] or nil;
    local upgrade_location=plus_piece and relic_plus1_piece_location_for_job(
        names,stored_names,owned_ids,stored_ids,job,piece_index,plus_piece) or nil;
    return upgraded_base_progress_location(base_location,upgrade_location);
end

local function relic_minus1_piece_location_for_job(names,stored_names,owned_ids,stored_ids,job,piece_index,piece)
    local ids=RELIC_MINUS1_ITEM_IDS[tostring(job or '')];
    local item_id=ids and tonumber(ids[tonumber(piece_index or 0)]);
    return exact_piece_location(names,stored_names,owned_ids,stored_ids,piece,item_id);
end


local function relic_minus1_progress_location_for_job(names,stored_names,owned_ids,stored_ids,job,piece_index,piece)
    local physical_location=relic_minus1_piece_location_for_job(
        names,stored_names,owned_ids,stored_ids,job,piece_index,piece);
    local plus_set=RELIC_PLUS1_SETS[tostring(job or '')];
    local plus_piece=plus_set and plus_set[tonumber(piece_index or 0)] or nil;
    local plus_location=plus_piece and relic_plus1_piece_location_for_job(
        names,stored_names,owned_ids,stored_ids,job,piece_index,plus_piece) or nil;

    -- Once the matching Relic +1 exists, the damaged -1 component is no
    -- longer required for progression. A satisfied slot should count as found
    -- for display progress even if the physical -1 was consumed during the
    -- upgrade process.
    if plus_location then
        if physical_location then
            return tostring(physical_location)..' | NOT NEEDED',true;
        end
        return 'NOT NEEDED',true;
    end
    return physical_location,physical_location~=nil;
end

local function relic_accessory_location_for_job(names,stored_names,owned_ids,stored_ids,job,piece)
    local item_id=tonumber(RELIC_ACCESSORY_ITEM_IDS[tostring(job or '')]);
    return exact_piece_location(names,stored_names,owned_ids,stored_ids,piece,item_id);
end

function M.relic_snapshot(force)
    local names,available,stored_names,slip_seen,slip_decoded,owned_ids,stored_ids=owned_item_name_set(force==true);
    local out={available=available==true,slip_seen=slip_seen==true,slip_decoded=slip_decoded==true,jobs={}};
    for _,j in ipairs(JOB_ORDER) do
        local job=tostring(j[2]);
        local row={job=job,name=j[3],armor={},minus1={},plus1={},accessory=nil};
        local relic=RELIC_SETS[job] or {};
        local relic_p1=RELIC_PLUS1_SETS[job] or {};
        local relic_m1=RELIC_MINUS1_SETS[job] or {};
        for slot=1,5 do
            local base=relic[slot]; local p1=relic_p1[slot]; local m1=relic_m1[slot];
            local base_loc=base and relic_piece_location_for_job(names,stored_names,owned_ids,stored_ids,job,slot,base) or nil;
            local p1_loc=p1 and relic_plus1_piece_location_for_job(names,stored_names,owned_ids,stored_ids,job,slot,p1) or nil;
            local m1_loc=m1 and relic_minus1_piece_location_for_job(names,stored_names,owned_ids,stored_ids,job,slot,m1) or nil;
            -- A +1 piece is irreversible historical proof that both the NQ relic
            -- and the damaged -1 component were obtained previously.
            base_loc=upgraded_base_progress_location(base_loc,p1_loc);
            if not m1_loc and p1_loc then m1_loc='USED FOR +1'; end
            row.armor[slot]={name=base,item_id=RELIC_ITEM_IDS[job] and RELIC_ITEM_IDS[job][slot] or nil,location=base_loc};
            row.plus1[slot]={name=p1,item_id=RELIC_PLUS1_ITEM_IDS[job] and RELIC_PLUS1_ITEM_IDS[job][slot] or nil,location=p1_loc};
            row.minus1[slot]={name=m1,item_id=RELIC_MINUS1_ITEM_IDS[job] and RELIC_MINUS1_ITEM_IDS[job][slot] or nil,location=m1_loc};
        end
        local acc=RELIC_ACCESSORIES[job];
        if acc then
            row.accessory={name=acc,item_id=RELIC_ACCESSORY_ITEM_IDS[job],location=relic_accessory_location_for_job(names,stored_names,owned_ids,stored_ids,job,acc)};
        end
        out.jobs[job]=row;
    end
    return out;
end

-- Unified AF / Relic collection snapshot used by the Collections tab.  This
-- reuses the exact same inventory/wardrobe/Porter-slip evidence as Character
-- Info so the two views cannot disagree about ownership.
function M.gear_collection_snapshot(force)
    local names,available,stored_names,slip_seen,slip_decoded,owned_ids,stored_ids=owned_item_name_set(force==true);
    local out={
        available=available==true,
        slip_seen=slip_seen==true,
        slip_decoded=slip_decoded==true,
        jobs={},
        total=0,
        obtained=0,
    };

    local function piece(name,location,not_needed)
        local got=(location~=nil);
        if got then out.obtained=out.obtained+1; end
        out.total=out.total+1;
        return {name=name,location=location,obtained=got,not_needed=not_needed==true};
    end

    for _,j in ipairs(JOB_ORDER) do
        local job=tostring(j[2]);
        local row={job=job,name=tostring(j[3]),sets={},obtained=0,total=0};
        local af=AF_SETS[job] or {};
        local afp=AF_PLUS1_SETS[job] or {};
        local relic=RELIC_SETS[job] or {};
        local relicp=RELIC_PLUS1_SETS[job] or {};
        local relicm=RELIC_MINUS1_SETS[job] or {};

        local function add_set(id,label,items)
            local have=0;
            for _,it in ipairs(items) do if it.obtained then have=have+1; end end
            row.sets[id]={id=id,label=label,items=items,obtained=have,total=#items};
            row.obtained=row.obtained+have;
            row.total=row.total+#items;
        end

        local items={};
        for slot=1,5 do
            local name=af[slot];
            local loc=name and af_base_progress_location_for_job(names,stored_names,owned_ids,stored_ids,job,slot,name) or nil;
            items[#items+1]=piece(name,loc,false);
        end
        add_set('af','AF',items);

        items={};
        for slot=1,5 do
            local name=afp[slot];
            local loc=name and af_plus1_piece_location_for_job(names,stored_names,owned_ids,stored_ids,job,slot,name) or nil;
            items[#items+1]=piece(name,loc,false);
        end
        add_set('af_p1','AF +1',items);

        items={};
        for slot=1,5 do
            local name=relic[slot];
            local loc=name and relic_base_progress_location_for_job(names,stored_names,owned_ids,stored_ids,job,slot,name) or nil;
            items[#items+1]=piece(name,loc,false);
        end
        local acc=RELIC_ACCESSORIES[job];
        if acc then
            local loc=relic_accessory_location_for_job(names,stored_names,owned_ids,stored_ids,job,acc);
            items[#items+1]=piece(acc,loc,false);
        end
        add_set('relic','Relic',items);

        items={};
        for slot=1,5 do
            local name=relicp[slot];
            local loc=name and relic_plus1_piece_location_for_job(names,stored_names,owned_ids,stored_ids,job,slot,name) or nil;
            items[#items+1]=piece(name,loc,false);
        end
        add_set('relic_p1','Relic +1',items);

        items={};
        for slot=1,5 do
            local name=relicm[slot];
            local loc,counts=nil,false;
            if name then
                loc,counts=relic_minus1_progress_location_for_job(names,stored_names,owned_ids,stored_ids,job,slot,name);
            end
            local not_needed=type(loc)=='string' and loc:find('NOT NEEDED',1,true)~=nil;
            -- piece() counts any non-nil location.  For the -1 set the helper's
            -- explicit satisfied flag is authoritative when a +1 consumed it.
            local it=piece(name,(counts==true and (loc or 'NOT NEEDED')) or loc,not_needed);
            it.obtained=(counts==true) or it.location~=nil;
            items[#items+1]=it;
        end
        add_set('relic_m1','Relic -1',items);

        out.jobs[job]=row;
    end

    -- v7.9.27: remember a compact, last-known gear summary when Character Info
    -- (or another collection screen) already performed the expensive ownership
    -- scan. Overview reads only this saved summary and never initiates a new
    -- 17-container scan just to decorate the dashboard.
    pcall(function()
        local c=HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char() or nil;
        if type(c)~='table' then return; end
        c.overview_profile=type(c.overview_profile)=='table' and c.overview_profile or {};
        c.overview_profile.job_gear=type(c.overview_profile.job_gear)=='table' and c.overview_profile.job_gear or {};
        local changed=false;
        local function first_five(set)
            local have,total=0,0;
            for i,it in ipairs(type(set)=='table' and set.items or {}) do
                if i>5 then break; end
                total=total+1; if it and it.obtained==true then have=have+1; end
            end
            return have,total;
        end
        for job,row in pairs(out.jobs or {}) do
            local dst=type(c.overview_profile.job_gear[job])=='table' and c.overview_profile.job_gear[job] or {};
            local af_h,af_t=first_five(row.sets and row.sets.af);
            local af1_h,af1_t=first_five(row.sets and row.sets.af_p1);
            local rel_h,rel_t=first_five(row.sets and row.sets.relic);
            local rel1_h,rel1_t=first_five(row.sets and row.sets.relic_p1);
            local relm1_h,relm1_t=first_five(row.sets and row.sets.relic_m1);
            local vals={af_have=af_h,af_total=af_t,af1_have=af1_h,af1_total=af1_t,
                relic_have=rel_h,relic_total=rel_t,relic1_have=rel1_h,relic1_total=rel1_t,
                relicm1_have=relm1_h,relicm1_total=relm1_t,at=os.time()};
            for k,v in pairs(vals) do
                if k~='at' and dst[k]~=v then dst[k]=v; changed=true; end
            end
            if changed or not dst.at then dst.at=vals.at; end
            c.overview_profile.job_gear[job]=dst;
        end
        if changed and HC.modules.state and HC.modules.state.request_save then HC.modules.state.request_save(2); end
    end);
    return out;
end

local current_job_level;

local function ensure_maat_tracking(c)
    if type(c)~='table' then return nil,nil; end
    c.quest_maat_job_wins=type(c.quest_maat_job_wins)=='table' and c.quest_maat_job_wins or {};
    c.quest_maat_job_win_meta=type(c.quest_maat_job_win_meta)=='table' and c.quest_maat_job_win_meta or {};
    c.maat_runtime=type(c.maat_runtime)=='table' and c.maat_runtime or {};
    return c.quest_maat_job_wins,c.quest_maat_job_win_meta;
end

local function maat_status(c,job,level)
    if not MAAT_JOBS[job] then return 'N/A',nil,nil; end
    local wins,meta=ensure_maat_tracking(c);
    local won=wins and wins[job]==true;
    local m=meta and meta[job] or nil;
    if won then
        local tag='CONFIRMED';
        if type(m)=='table' then
            local src=string.lower(tostring(m.source or ''));
            if src:find('battlefield clear',1,true) or src:find('automatic',1,true) then tag='AUTO';
            elseif src:find('manual',1,true) then tag='MANUAL'; end
        end
        return 'BEAT ['..tag..']',true,m;
    end
    local lvl=tonumber(level or 0) or 0;
    if lvl>=66 then return 'OPEN',false,m; end
    return 'OPENS AT Lv.66',false,m;
end

local function confirm_maat_win(c,job,source,confidence)
    if type(c)~='table' or not MAAT_JOBS[job] then return false; end
    local wins,meta=ensure_maat_tracking(c);
    local now=os.time();
    local changed=(wins[job]~=true);
    wins[job]=true;
    local prev=type(meta[job])=='table' and meta[job] or nil;
    if not prev or confidence=='AUTO' or tostring(prev.confidence or '')~='AUTO' then
        meta[job]={
            source=tostring(source or 'Maat victory confirmation'),
            confidence=tostring(confidence or 'CONFIRMED'),
            confirmed_at=now,
            job=job,
        };
        changed=true;
    end
    if changed and HC and HC.modules and HC.modules.state and HC.modules.state.save then HC.modules.state.save(); end
    return changed;
end

local function clear_maat_runtime(c,reason)
    if type(c)~='table' then return; end
    c.maat_runtime=type(c.maat_runtime)=='table' and c.maat_runtime or {};
    if c.maat_runtime.active then
        c.maat_runtime.last_aborted={
            job=c.maat_runtime.active.job,
            entered_at=c.maat_runtime.active.entered_at,
            at=os.time(),
            reason=tostring(reason or 'cleared'),
        };
        c.maat_runtime.active=nil;
    end
end

local function maat_tracker_on_text(s)
    if not HC or not HC.modules or not HC.modules.state then return; end
    local c=HC.modules.state.get_char();
    if type(c)~='table' then return; end
    ensure_maat_tracking(c);
    local low=string.lower(tostring(s or ''));
    if low=='' then return; end

    -- Shattering Stars is repeatable per job.  The normal Maat dialogue does not
    -- reveal historical per-job wins, but a verified battlefield entry followed
    -- by the normal clear-time line is strong reusable evidence of a fresh win.
    if low:find('entering the battlefield for',1,true) and low:find('shattering stars',1,true) then
        local job,level=current_job_level();
        job=tostring(job or '');
        if MAAT_JOBS[job] and tonumber(level or 0)>=66 then
            c.maat_runtime.active={job=job,level=level,entered_at=os.time(),source='Shattering Stars battlefield entry'};
            if HC.modules.state.save then HC.modules.state.save(); end
            if HC.modules.state.audit then HC.modules.state.audit(c,'maat','Shattering Stars entry armed for '..job,'LIVE','Battlefield entry text'); end
        end
        return;
    end

    local active=c.maat_runtime and c.maat_runtime.active or nil;
    if active then
        local age=os.time()-(tonumber(active.entered_at) or 0);
        if age>3600 then
            clear_maat_runtime(c,'entry expired');
            if HC.modules.state.save then HC.modules.state.save(); end
            return;
        end

        if low:find('battlefield clear time:',1,true) then
            local job=tostring(active.job or '');
            if MAAT_JOBS[job] then
                local changed=confirm_maat_win(c,job,'Shattering Stars battlefield clear time','AUTO');
                c.maat_runtime.last={job=job,entered_at=active.entered_at,cleared_at=os.time(),source='Battlefield clear time'};
                c.maat_runtime.active=nil;
                if HC.modules.state.save then HC.modules.state.save(); end
                if HC.modules.state.audit then HC.modules.state.audit(c,'maat',job..' Maat victory confirmed automatically','AUTO','Shattering Stars battlefield clear time'); end
                if changed and HC.msg then HC.msg('AUTO: Maat victory confirmed for '..job..'.'); end
            end
            return;
        end

        if low:find('leaving the battlefield',1,true) or low:find('you have failed',1,true) or low:find('battlefield has ended',1,true) then
            clear_maat_runtime(c,'battlefield ended without clear');
            if HC.modules.state.save then HC.modules.state.save(); end
        end
    end
end

current_job_level=function()
    local p=get_player(); if not p then return nil,nil; end
    local jid=nil; local level=nil;
    pcall(function()
        if p.GetMainJob then jid=tonumber(p:GetMainJob()); elseif p.GetMainJobId then jid=tonumber(p:GetMainJobId()); end
        if p.GetMainJobLevel then level=tonumber(p:GetMainJobLevel()); end
    end);
    local job=JOBS[jid];
    if level then level=math.max(1,math.min(75,math.floor(level))); end
    return job,level;
end

local job_levels_cache={at=0,rows=nil};
local function all_job_levels(force)
    local now=os.time();
    if not force and job_levels_cache.rows and (now-tonumber(job_levels_cache.at or 0))<2 then
        if HC.modules.profiler and HC.modules.profiler.cache then HC.modules.profiler.cache('skills.job_levels',true); end
        return job_levels_cache.rows;
    end
    if HC.modules.profiler and HC.modules.profiler.cache then HC.modules.profiler.cache('skills.job_levels',false); end
    local p=get_player();
    local main_job_id=nil; local main_exp_current=nil;
    if p then
        pcall(function()
            if p.GetMainJob then main_job_id=tonumber(p:GetMainJob()); end
            if p.GetExpCurrent then main_exp_current=tonumber(p:GetExpCurrent()); end
        end);
    end
    local out={};
    for _,j in ipairs(JOB_ORDER) do
        local level=nil;
        if p and p.GetJobLevel then
            pcall(function() level=tonumber(p:GetJobLevel(j[1])); end);
        end
        if level==nil then level=0; end
        level=math.max(0,math.min(75,math.floor(level)));
        out[#out+1]={
            id=j[1],abbr=j[2],name=j[3],level=level,
            exp_current=(main_job_id==j[1] and level>0 and level<75) and main_exp_current or nil,
        };
    end
    job_levels_cache={at=now,rows=out};
    return out;
end

local function all_craft_skills()
    local p=get_player();
    local out={};
    for _,craft in ipairs(CRAFT_ORDER) do
        local value=nil; local rank=nil; local capped=false;
        if p and p.GetCraftSkill then
            pcall(function()
                local skill=p:GetCraftSkill(craft[1]);
                if skill then
                    if skill.GetSkill then value=tonumber(skill:GetSkill()); end
                    if skill.GetRank then rank=tonumber(skill:GetRank()); end
                    if skill.IsCapped then capped=(skill:IsCapped()==true); end
                end
            end);
        end
        if value~=nil then value=math.max(0,math.floor(value)); end
        if rank~=nil then rank=math.max(0,math.floor(rank)); end
        out[#out+1]={index=craft[1],name=craft[2],level=value,rank=rank,rank_name=CRAFT_RANK_NAMES[rank],capped=capped};
    end
    return out;
end

local function skill_cap(name,job,level)
    if not job or not level then return nil,nil; end
    local ranks=JOB_SKILL_RANKS[job]; if type(ranks)~='table' then return nil,nil; end
    local rank=ranks[name]; if not rank then return 0,nil; end
    local caps=CAP_BY_RANK[rank]; if not caps then return nil,rank; end
    return tonumber(caps[level]),rank;
end

local function read_index(index)
    local player=get_player();
    if not player or not player.GetCombatSkill then return nil,'player combat-skill API unavailable'; end
    local skill=nil;
    local ok,err=pcall(function() skill=player:GetCombatSkill(tonumber(index)); end);
    if not ok or skill==nil then return nil,tostring(err or 'skill unavailable'); end
    local value=nil;
    pcall(function() if skill.GetSkill then value=tonumber(skill:GetSkill()); end end);
    if value==nil then return nil,'skill value unavailable'; end
    return {value=math.max(0,math.floor(value)),index=index},nil;
end

function M.get(name)
    local row=by_name[string.lower(tostring(name or ''))];
    if not row then return nil,'unknown combat skill'; end
    return read_index(row[1]);
end

function M.get_craft(name)
    local wanted=string.lower(tostring(name or ''));
    for _,craft in ipairs(CRAFT_ORDER) do
        if string.lower(tostring(craft[2]))==wanted then
            local p=get_player();
            if not p or not p.GetCraftSkill then return nil,'player craft-skill API unavailable'; end
            local skill=nil;
            local ok,err=pcall(function() skill=p:GetCraftSkill(craft[1]); end);
            if not ok or skill==nil then return nil,tostring(err or 'craft skill unavailable'); end
            local value=nil; local rank=nil; local capped=false;
            pcall(function() if skill.GetSkill then value=tonumber(skill:GetSkill()); end end);
            pcall(function() if skill.GetRank then rank=tonumber(skill:GetRank()); end end);
            pcall(function() if skill.IsCapped then capped=(skill:IsCapped()==true); end end);
            if value==nil then return nil,'craft skill value unavailable'; end
            return {value=math.max(0,math.floor(value)),index=craft[1],rank=rank and math.max(0,math.floor(rank)) or nil,capped=capped},nil;
        end
    end
    return nil,'unknown craft skill';
end

function M.cap(name)
    local job,level=current_job_level();
    local cap,rank=skill_cap(tostring(name or ''),job,level);
    return cap,rank,job,level;
end

function M.overview_summary()
    local job,level=current_job_level();
    local rows=all_job_levels(false);
    local capped=0;
    for _,r in ipairs(rows or {}) do if tonumber(r.level or 0)>=75 then capped=capped+1; end end
    return {job=job or '---',level=tonumber(level) or 0,jobs_75=capped,jobs_total=#(rows or {})};
end

local job_progress_summary;

function M.job_progress_summary(c,abbr)
    c=c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    local target=nil; for _,j in ipairs(all_job_levels(false) or {}) do if tostring(j.abbr)==tostring(abbr) then target=j; break; end end
    if not target then return nil; end
    return job_progress_summary(c,target);
end

function M.job_levels(force)
    local out={};
    for _,r in ipairs(all_job_levels(force==true) or {}) do
        out[#out+1]={abbr=tostring(r.abbr or r.job or ''),name=tostring(r.name or r.abbr or ''),level=tonumber(r.level) or 0};
    end
    return out;
end

function M.snapshot()
    local out={}; local job,level=current_job_level();
    for _,group in ipairs(GROUPS) do
        local g={title=group.title,rows={}};
        for _,row in ipairs(group.rows) do
            local v,err=read_index(row[1]);
            local cap,rank=skill_cap(row[2],job,level);
            g.rows[#g.rows+1]={name=row[2],index=row[1],value=v and v.value or nil,error=err,cap=cap,rank=rank};
        end
        out[#out+1]=g;
    end
    return out;
end

local function draw_group(imgui,group,job,level)
    if not imgui.CollapsingHeader(group.title..'##skills_'..string.lower(group.title):gsub('%s+','_'), ImGuiTreeNodeFlags_DefaultOpen or 0) then return; end
    for _,row in ipairs(group.rows) do
        local v,err=read_index(row[1]);
        local cap,rank=skill_cap(row[2],job,level);
        if group.title=='Automaton' then
            if v then imgui.Text(string.format('%-20s %3d / frame',row[2],v.value));
            else imgui.TextDisabled(string.format('%-20s  -- / frame',row[2])); end
        elseif cap==0 then
            if v then imgui.TextDisabled(string.format('%-20s %3d /  --   [NO NATIVE SKILL]',row[2],v.value));
            else imgui.TextDisabled(string.format('%-20s  -- /  --   [NO NATIVE SKILL]',row[2])); end
        elseif v and cap then
            local capped=(v.value>=cap);
            imgui.Text(string.format('%-20s %3d / %3d  [%s]%s',row[2],v.value,cap,tostring(rank or '?'),capped and ' [CAPPED]' or ''));
        elseif v then
            imgui.Text(string.format('%-20s %3d /  --',row[2],v.value));
        else
            imgui.TextDisabled(string.format('%-20s  -- / %3s',row[2],cap and tostring(cap) or '--'));
            if err and imgui.IsItemHovered~=nil and imgui.IsItemHovered() then imgui.SetTooltip(tostring(err)); end
        end
    end
end


local job_plan_cache={character=nil,at=0,plans={}};
local current_job_static_cache={at=0,job=nil,level=nil,data=nil};
local CURRENT_JOB_STATIC_CACHE_SECONDS=30;

local function current_job_static_detail(c,job,level)
    local now=os.time();
    if current_job_static_cache.data and current_job_static_cache.job==job and current_job_static_cache.level==level
        and now-(tonumber(current_job_static_cache.at) or 0)<CURRENT_JOB_STATIC_CACHE_SECONDS then
        return current_job_static_cache.data;
    end
    local maat_label,maat_won=maat_status(c,tostring(job),tonumber(level) or 0);
    local capped,total=0,0;
    for _,group in ipairs(GROUPS or {}) do
        if tostring(group.title)~='Automaton' then
            for _,row in ipairs(group.rows or {}) do
                local cap=skill_cap(row[2],job,level);
                if cap and tonumber(cap) and tonumber(cap)>0 then
                    total=total+1;
                    local v=read_index(row[1]);
                    if v and tonumber(v.value) and tonumber(v.value)>=tonumber(cap) then capped=capped+1; end
                end
            end
        end
    end
    local saved=nil;
    if type(c)=='table' and type(c.overview_profile)=='table' and type(c.overview_profile.job_gear)=='table' then
        saved=c.overview_profile.job_gear[tostring(job)];
    end
    local out={maat=maat_label,maat_won=maat_won==true,skills_capped=capped,skills_total=total,gear=type(saved)=='table' and saved or nil};
    current_job_static_cache={at=now,job=job,level=level,data=out};
    return out;
end

local function cached_job_plan(c,abbr,level_now)
    local now=os.time();
    if job_plan_cache.character~=c or (now-tonumber(job_plan_cache.at or 0))>=2 then
        job_plan_cache={character=c,at=now,plans={}};
    end
    local key=tostring(abbr)..':'..tostring(level_now);
    if job_plan_cache.plans[key]~=nil then
        local v=job_plan_cache.plans[key];
        return v~=false and v or nil;
    end
    local plan=nil;
    if HC.modules.quests and HC.modules.quests.job_progression then
        local ok,res=pcall(HC.modules.quests.job_progression,c,abbr,level_now);
        if ok then plan=res; end
    end
    job_plan_cache.plans[key]=plan or false;
    return plan;
end

-- v7.9.22: compact live progression detail for the logged-in main job.
-- This is the same EXP-weighted data shown by the expanded Character Info job
-- row, exposed so Overview does not invent a second progression calculation.
function M.current_job_progress_detail(c)
    c=c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    local job,level=current_job_level();
    if not job or not level then return nil; end
    local target=nil;
    for _,j in ipairs(all_job_levels(false) or {}) do
        if tostring(j.abbr)==tostring(job) then target=j; break; end
    end
    if not target then return nil; end
    local exp_done,exp_total,pct=job_exp_progress(target);
    local plan=cached_job_plan(c,job,level);
    local qdone=tonumber(plan and plan.completed_job_quests) or 0;
    local qtotal=qdone+#(plan and plan.pending or {});
    local static=current_job_static_detail(c,job,level);
    return {
        job=tostring(job),level=tonumber(level) or 0,
        exp_done=tonumber(exp_done) or 0,exp_total=tonumber(exp_total) or EXP_TOTAL_TO_75,
        mapped_done=qdone,mapped_total=qtotal,overall_pct=tonumber(pct) or 0,
        maat=static and static.maat or 'N/A',maat_won=static and static.maat_won==true or false,
        skills_capped=tonumber(static and static.skills_capped) or 0,skills_total=tonumber(static and static.skills_total) or 0,
        gear=static and static.gear or nil,
    };
end

local function progression_piece_progress(names,stored_names,owned_ids,stored_ids,job,set,kind)
    local have=0; local total=type(set)=='table' and #set or 0; local locations={};
    for piece_index,piece in ipairs(type(set)=='table' and set or {}) do
        local location=nil; local counts_as_found=nil;
        if kind=='af' then
            location=af_base_progress_location_for_job(names,stored_names,owned_ids,stored_ids,job,piece_index,piece);
        elseif kind=='af_p1' then
            location=af_plus1_piece_location_for_job(names,stored_names,owned_ids,stored_ids,job,piece_index,piece);
        elseif kind=='relic' then
            location=relic_base_progress_location_for_job(names,stored_names,owned_ids,stored_ids,job,piece_index,piece);
        elseif kind=='relic_p1' then
            location=relic_plus1_piece_location_for_job(names,stored_names,owned_ids,stored_ids,job,piece_index,piece);
        elseif kind=='relic_m1' then
            location,counts_as_found=relic_minus1_progress_location_for_job(names,stored_names,owned_ids,stored_ids,job,piece_index,piece);
        end
        locations[piece_index]=location;
        if counts_as_found==nil then counts_as_found=(location~=nil); end
        if counts_as_found then have=have+1; end
    end
    return have,total,locations;
end

job_progress_summary=function(c,j)
    local level=math.max(0,math.min(75,tonumber(j.level or 0) or 0));
    local _,_,pct=job_exp_progress(j);
    local remaining={};
    if level<75 then remaining[1]=string.format('%d level%s to Lv.75',75-level,(75-level)==1 and '' or 's'); end
    return {
        done=level,
        total=75,
        pct=pct,
        remaining=remaining,
        rows={{label='Level',have=level,total=75}},
        level=level,
    };
end

local function job_progression_score(c,j,plan,gear_row)
    -- Overall progress is intentionally leveling-only; gear, mapped quests,
    -- and Maat never change it. Unlike the retired equal-per-level ratio, this uses the
    -- actual 801,350 EXP curve from Lv.1 to Lv.75.
    local _,_,pct=job_exp_progress(j);
    return pct;
end

local function job_gear_summary(row,id)
    local set=type(row)=='table' and type(row.sets)=='table' and row.sets[id] or nil;
    if not set then return '0/0'; end
    return string.format('%d/%d',tonumber(set.obtained) or 0,tonumber(set.total) or 0);
end

local function first_missing_gear(row)
    if type(row)~='table' or type(row.sets)~='table' then return nil; end
    for _,id in ipairs({'af','af_p1','relic','relic_p1','relic_m1'}) do
        local set=row.sets[id];
        for _,it in ipairs(type(set)=='table' and set.items or {}) do
            if it and it.obtained~=true and it.name and tostring(it.name)~='' then
                return tostring(it.name),tostring(set.label or 'Gear');
            end
        end
    end
    return nil;
end

local function next_progression_text(c,j,plan,gear_row)
    local job=tostring(j and j.abbr or '');
    local level=tonumber(j and j.level or 0) or 0;
    local maat_label,maat_won=maat_status(c,job,level);
    if MAAT_JOBS[job] and level>=66 and maat_won~=true then
        return 'Beat Maat','Limit-break progression';
    end
    if plan and plan.next then
        local n=plan.next; local st=string.upper(tostring(n.state or 'UNKNOWN'));
        if st=='AVAILABLE' then st='READY'; end
        if st=='READY' or st=='ACTIVE' then
            return tostring(n.name or 'Mapped job quest'),st..((n.zone and n.zone~='') and (' | '..tostring(n.zone)) or '');
        end
    end
    local missing,set=first_missing_gear(gear_row);
    if missing then return 'Obtain '..tostring(missing),tostring(set or 'Gear'); end
    if plan and plan.next then
        local n=plan.next; local st=string.upper(tostring(n.state or 'UNKNOWN'));
        local why=tostring(n.reason or '');
        return tostring(n.name or 'Mapped job quest'),st..(why~='' and (' | '..why) or '');
    end
    if level<75 then return 'Level to Lv.75',tostring(75-level)..' level(s) remaining'; end
    return 'Mapped progression complete','No mapped next action';
end

local function draw_job_progression_sections(c,navigation_focus)
    local imgui=HC.imgui;
    local developer=(type(c.settings)=='table' and c.settings.developer_mode==true);
    local job_rows=all_job_levels();
    local gear_snapshot=M.gear_collection_snapshot(false);
    c.settings=type(c.settings)=='table' and c.settings or {};
    local missing_buf={c.settings.job_progression_missing_only==true};
    local owned_names,inventory_available,porter_stored_names,porter_slip_seen,porter_slip_decoded,owned_ids,porter_stored_ids=owned_item_name_set(false);

    local summary_jobs,summary_maat_won,summary_maat_total=0,0,0;
    for _ in pairs(MAAT_JOBS) do summary_maat_total=summary_maat_total+1; end
    for _,summary_job in ipairs(job_rows) do
        local summary_level=tonumber(summary_job.level or 0) or 0;
        if summary_level>0 then
            summary_jobs=summary_jobs+1;
            if MAAT_JOBS[tostring(summary_job.abbr)] then
                local _,summary_won=maat_status(c,tostring(summary_job.abbr),summary_level);
                if summary_won==true then summary_maat_won=summary_maat_won+1; end
            end
        end
    end
    imgui.TextDisabled(string.format('Jobs %d  |  Maat %d/%d',summary_jobs,summary_maat_won,summary_maat_total));
    if imgui.Checkbox('Missing gear only##job_progression_missing_only',missing_buf) then
        c.settings.job_progression_missing_only=missing_buf[1]==true;
        if HC.modules.state then HC.modules.state.save(); end
    end
    local missing_only=missing_buf[1]==true;
    navigation_focus=type(navigation_focus)=='table' and navigation_focus or nil;
    local focus_job=type(navigation_focus)=='table' and tostring(navigation_focus.job or '') or '';
    if developer and HC.modules.learning and HC.modules.learning.capture_button then
        HC.modules.learning.capture_button('maat','job_progression_maat',0);
        if HC.modules.learning.active and HC.modules.learning.active() and HC.modules.learning.current and HC.modules.learning.current().target=='maat' then
            imgui.SameLine(); imgui.TextDisabled('CAPTURE ARMED - speak to Maat, complete his dialogue/menu, then click Stop Capture.');
        else
            imgui.SameLine(); imgui.TextDisabled('Use this if you want HorizonCheck to look for old Maat wins on this job.');
        end
    end
    -- Keep each job compact until opened. This preserves the full progression
    -- detail while letting Character Info stay readable as one consolidated tab.
    for _,j in ipairs(job_rows) do
            local level_now=tonumber(j.level or 0);
            if level_now>0 then
                local plan=cached_job_plan(c,j.abbr,level_now);
                local level_goal=plan and plan.level_target or nil;
                local goal_source=plan and plan.level_target_source or nil;
                local gear_row=gear_snapshot.jobs and gear_snapshot.jobs[tostring(j.abbr)] or nil;
                local overall_score=job_progression_score(c,j,plan,gear_row);
                local maat_head,maat_won_head=maat_status(c,tostring(j.abbr),level_now);
                local maat_compact='';
                if MAAT_JOBS[tostring(j.abbr)] and level_now>=66 then maat_compact='  |  Maat '..(maat_won_head==true and 'BEAT' or 'OPEN'); end
                local head=string.format('%-3s Lv.%d  |  %d%% overall%s',tostring(j.abbr),level_now,overall_score,maat_compact);

                local job_open=true;
                local requested=(focus_job~='' and string.upper(focus_job)==string.upper(tostring(j.abbr)));
                if requested and imgui.SetNextItemOpen then pcall(imgui.SetNextItemOpen,true,rawget(_G,'ImGuiCond_Always') or 1); end
                if imgui.CollapsingHeader~=nil then
                    job_open=imgui.CollapsingHeader(head..'##job_progression_'..tostring(j.abbr),0);
                else
                    imgui.Text(head);
                end
                if requested and job_open and imgui.SetScrollHereY then pcall(imgui.SetScrollHereY,0.15); end

                if job_open then
                    local qdone=tonumber(plan and plan.completed_job_quests) or 0; local qtotal=qdone+#(plan and plan.pending or {});
                    local next_text,next_reason=next_progression_text(c,j,plan,gear_row);
                    imgui.Text('Next Progression: '..tostring(next_text));
                    if next_reason and next_reason~='' then imgui.SameLine(); imgui.TextDisabled('['..tostring(next_reason)..']'); end
                    local exp_done,exp_total=job_exp_progress(j);
                    imgui.TextDisabled(string.format('Lv.%d/75 | EXP %s/%s | Mapped quests %d/%d | Overall %d%%',level_now,format_number(exp_done),format_number(exp_total),qdone,qtotal,overall_score));
                    if imgui.Separator then imgui.Separator(); end
                    local maat_label,maat_won,maat_meta=maat_status(c,tostring(j.abbr),level_now);
                    if maat_won==true then
                        imgui.Text('  Maat: '..maat_label);
                        if type(maat_meta)=='table' and maat_meta.confirmed_at then
                            imgui.SameLine(); imgui.TextDisabled(os.date('%Y-%m-%d',tonumber(maat_meta.confirmed_at)));
                        end
                    elseif maat_label=='N/A' then
                        imgui.TextDisabled('  Maat: N/A for this job');
                    else
                        imgui.TextDisabled('  Maat: '..maat_label);
                        if MAAT_JOBS[tostring(j.abbr)] then
                            imgui.SameLine();
                            if imgui.SmallButton('Confirm Past Win##maat_manual_'..tostring(j.abbr)) then
                                confirm_maat_win(c,tostring(j.abbr),'Manual past-win confirmation','MANUAL');
                            end
                        end
                    end

                    local af=AF_SETS[tostring(j.abbr)];
                    local af_p1=AF_PLUS1_SETS[tostring(j.abbr)];
                    local relic=RELIC_SETS[tostring(j.abbr)];
                    local relic_p1=RELIC_PLUS1_SETS[tostring(j.abbr)];
                    local relic_m1=RELIC_MINUS1_SETS[tostring(j.abbr)];
                    local function draw_row_separator()
                        if imgui.Separator~=nil then imgui.Separator(); end
                    end
                    local function draw_gear_column(title,set,kind)
                        if type(set)~='table' then imgui.TextDisabled(title..': N/A'); return; end
                        local have=0; local locations={};
                        if inventory_available then
                            have,_,locations=progression_piece_progress(owned_names,porter_stored_names,owned_ids,porter_stored_ids,j.abbr,set,kind=='relic_m1' and 'relic_m1' or kind);
                        end
                        local summary=string.format('%s: %d/%d found',title,have,#set);
                        if have>=#set and #set>0 then imgui.Text(summary); else imgui.TextDisabled(summary); end
                        draw_row_separator();
                        local shown_pieces=0;
                        for piece_index,piece in ipairs(set) do
                            local location=locations[piece_index];
                            if not (missing_only and location~=nil) then
                                shown_pieces=shown_pieces+1;
                                local line=tostring(piece)..(location and ('  ['..location..']') or '');
                                if location then imgui.Text(line); else imgui.TextDisabled(line); end
                                draw_row_separator();
                            end
                        end
                        if shown_pieces==0 then imgui.TextDisabled('No missing pieces.'); end
                        if kind=='relic' then
                            local accessory=RELIC_ACCESSORIES[tostring(j.abbr)];
                            if accessory then
                                draw_row_separator();
                                local accessory_location=nil;
                                if inventory_available then accessory_location=relic_accessory_location_for_job(owned_names,porter_stored_names,owned_ids,porter_stored_ids,j.abbr,accessory); end
                                local accessory_summary='Relic Accessory: '..(accessory_location and '1/1 found' or '0/1 found');
                                if not (missing_only and accessory_location~=nil) then
                                    if accessory_location then imgui.Text(accessory_summary); else imgui.TextDisabled(accessory_summary); end
                                    draw_row_separator();
                                    local accessory_line=tostring(accessory)..(accessory_location and ('  ['..accessory_location..']') or '');
                                    if accessory_location then imgui.Text(accessory_line); else imgui.TextDisabled(accessory_line); end
                                end
                            end
                        end
                    end
                    draw_row_separator();
                    local gear_table=false;
                    if imgui.BeginTable~=nil and imgui.TableNextColumn~=nil and imgui.EndTable~=nil then
                        -- Keep each upgraded set immediately to the right of its base set.
                        gear_table=imgui.BeginTable('##job_gear_progress_'..tostring(j.abbr),5,64+128+512);
                    end
                    if gear_table then
                        imgui.TableNextColumn(); draw_gear_column('AF Armor',af,'af');
                        imgui.TableNextColumn(); draw_gear_column('AF +1',af_p1,'af_p1');
                        imgui.TableNextColumn(); draw_gear_column('Relic Armor',relic,'relic');
                        imgui.TableNextColumn(); draw_gear_column('Relic +1',relic_p1,'relic_p1');
                        imgui.TableNextColumn(); draw_gear_column('Relic -1',relic_m1,'relic_m1');
                        imgui.EndTable();
                    else
                        draw_gear_column('AF Armor',af,'af');
                        draw_row_separator();
                        draw_gear_column('AF +1',af_p1,'af_p1');
                        draw_row_separator();
                        draw_gear_column('Relic Armor',relic,'relic');
                        draw_row_separator();
                        draw_gear_column('Relic +1',relic_p1,'relic_p1');
                        draw_row_separator();
                        draw_gear_column('Relic -1',relic_m1,'relic_m1');
                    end
                    draw_row_separator();
                    if not inventory_available then
                        imgui.TextDisabled('  Inventory scan unavailable - zone once or reopen the tab.');
                    elseif porter_slip_seen and not porter_slip_decoded then
                        imgui.TextDisabled('  A supported storage slip was found, but its stored-item data could not be decoded on this Ashita build.');
                    end

                    if level_now>=75 then
                        imgui.Text('  Level milestone: Lv.75 [LEVEL CAP]');
                        draw_row_separator();
                    end

                    if plan and plan.next then
                        local n=plan.next; local st=tostring(n.state or 'UNKNOWN');
                        if st=='AVAILABLE' then st='READY'; end
                        if n.required_level then
                            local met=level_now>=tonumber(n.required_level);
                            if level_now>=75 then
                                imgui.Text(string.format('  Next job quest level: Lv.%d%s',tonumber(n.required_level),met and ' [MET]' or ''));
                            else
                                imgui.TextDisabled(string.format('  Next job quest level: Lv.%d%s',tonumber(n.required_level),met and ' [MET]' or ''));
                            end
                            draw_row_separator();
                        elseif level_goal and goal_source=='milestone' and level_now<75 then
                            imgui.TextDisabled(string.format('  Next level milestone: Lv.%d [no mapped quest level]',tonumber(level_goal)));
                        end
                        imgui.TextDisabled(string.format('  Next mapped job quest: %s [%s]',tostring(n.name or 'Unknown'),st));
                        draw_row_separator();
                        if n.zone and n.zone~='' then
                            imgui.TextDisabled('  Start: '..tostring(n.zone));
                            draw_row_separator();
                        end
                        if (st=='LOCKED' or st=='CHECK' or st=='MANUAL' or st=='UNKNOWN') and n.reason and n.reason~='' then
                            imgui.TextDisabled('  Blocker: '..tostring(n.reason));
                        end
                    elseif plan then
                        if level_goal and goal_source=='milestone' and level_now<75 then
                            imgui.TextDisabled(string.format('  Next level milestone: Lv.%d [no mapped job quest level]',tonumber(level_goal)));
                            imgui.Text(string.format('  No additional mapped job quests available at this time. %d completed.',tonumber(plan.completed_job_quests or 0)));
                        else
                            imgui.Text(string.format('  Job progression complete - %d mapped job quests completed.',tonumber(plan.completed_job_quests or 0)));
                        end
                    else
                        imgui.TextDisabled('  Job quest planner data unavailable until the quest module initializes.');
                    end
                end
            end
        end
end

function M.draw_job_progression(c)
    -- Backward-compatible entry point for older callers. The standalone tab was
    -- removed in v7.8.16; progression now lives at the bottom of Character Info.
    draw_job_progression_sections(c,nil);
end

function M.draw(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local job,level=current_job_level();
    local navigation_focus=(HC.modules.ui and HC.modules.ui.consume_focus) and HC.modules.ui.consume_focus('skills') or nil;

    local split_supported=(imgui.BeginTable~=nil and imgui.TableNextColumn~=nil and imgui.EndTable~=nil and imgui.BeginChild~=nil and imgui.EndChild~=nil);
    local split_height=650;
    local split_open=false;
    if split_supported and imgui.BeginTable('##skills_fame_split_v6815',2,512) then
        split_open=true;
        if imgui.TableSetupColumn~=nil then
            pcall(function() imgui.TableSetupColumn('Skills',0,0.50,0); end);
            pcall(function() imgui.TableSetupColumn('Fame',0,0.50,1); end);
        end
        imgui.TableNextColumn();
        imgui.BeginChild('##skills_left_v6815',{0,split_height},(ImGuiChildFlags_Borders or 1),0);
    end

    -- Left pane: live combat skills and current-job caps.
    imgui.Text('Combat Skills');
    if job and level then
        imgui.SameLine(); imgui.TextDisabled(string.format('- %s Lv.%d',job,level));
    else
        imgui.SameLine(); imgui.TextDisabled('- current job/level unavailable');
    end
    imgui.TextDisabled('Live value / current-job cap. Cap is calculated from HorizonXI job skill rank and current main-job level.');
    imgui.TextDisabled('Automaton skill caps are frame/head-dependent.');
    imgui.Separator();
    local player=get_player();
    if not player or not player.GetCombatSkill then
        imgui.TextDisabled('Combat-skill data is not available yet. Log in fully or zone once, then reopen this tab.');
    else
        for _,group in ipairs(GROUPS) do draw_group(imgui,group,job,level); end
    end

    if split_open then
        imgui.EndChild();
        imgui.TableNextColumn();
        imgui.BeginChild('##skills_right_v6815',{0,split_height},(ImGuiChildFlags_Borders or 1),0);
    else
        imgui.Separator();
    end

    -- Right pane: fame / reputation evidence.
    imgui.Text('Fame / Reputation');
    local developer=(type(c.settings)=='table' and c.settings.developer_mode==true);
    if developer and HC.modules.learning and HC.modules.learning.capture_button then
        imgui.SameLine();
        HC.modules.learning.capture_button('fame','skills_fame',0);
    end
    imgui.TextDisabled('Exact saved value when confirmed; otherwise a conservative floor proven by completed quests.');
    if developer and HC.modules.learning and HC.modules.learning.active and HC.modules.learning.active() then
        local cur=HC.modules.learning.current and HC.modules.learning.current() or nil;
        if cur and cur.target=='fame' then
            imgui.TextDisabled('CAPTURE ARMED - speak to one fame checker, finish the dialogue, then click Stop Capture.');
        end
    end
    imgui.Separator();
    local rows=nil;
    if HC.modules.quests and HC.modules.quests.fame_snapshot then rows=HC.modules.quests.fame_snapshot(c); end
    if type(rows)=='table' and #rows>0 then
        for _,r in ipairs(rows) do
            local value='unknown';
            if tonumber(r.level) then
                if r.confirmed then value=string.format('%d  [CONFIRMED]',tonumber(r.level));
                elseif r.inferred then value=string.format('>= %d  [PROVEN FLOOR]',tonumber(r.level));
                else value=tostring(r.level); end
            end
            imgui.Text(string.format('%-28s %s',tostring(r.label or ''),value));
            imgui.TextDisabled(string.format('  Check NPC: %s - %s',tostring(r.reporter or 'Unknown'),tostring(r.location or 'Unknown')));
            if r.aliases and tostring(r.aliases)~='' then imgui.TextDisabled('  '..tostring(r.aliases)); end
            imgui.Separator();
        end
    else
        imgui.TextDisabled('Fame details are not ready yet for this character.');
    end
    if developer then
        imgui.TextDisabled('FFXI does not expose a direct fame number in player memory.');
        imgui.TextDisabled('Use Capture while speaking to a listed checker if you want HorizonCheck to learn your exact fame rank from that dialogue.');
    end

    imgui.Separator();
    imgui.Text('Craft Skills');
    imgui.TextDisabled('Live crafting skill and guild rank from the game.');
    local craft_rows=all_craft_skills();
    local crafts_table=false;
    if imgui.BeginTable~=nil and imgui.TableNextColumn~=nil and imgui.EndTable~=nil then
        crafts_table=imgui.BeginTable('##skills_fame_craft_skills_v68124',2,64+128+512);
    end
    for _,craft in ipairs(craft_rows) do
        if crafts_table then imgui.TableNextColumn(); end
        if craft.level~=nil then
            local rank_text=craft.rank_name or (craft.rank~=nil and ('Rank '..tostring(craft.rank)) or 'Rank ?');
            local line=string.format('%-13s %3d  [%s]%s',tostring(craft.name),tonumber(craft.level),rank_text,craft.capped and ' [CAPPED]' or '');
            imgui.Text(line);
        else
            imgui.TextDisabled(string.format('%-13s  --  [unavailable]',tostring(craft.name)));
        end
    end
    if crafts_table then imgui.EndTable(); end

    if split_open then
        imgui.EndChild();
        imgui.EndTable();
    end

    -- Job Progression now lives at the bottom of Character Info instead of
    -- occupying a separate top-level tab. Keep the section visually distinct
    -- and collapsible so the combined page remains compact and easy to scan.
    imgui.Spacing();
    imgui.Separator();
    local progression_open=true;
    local progression_requested=type(navigation_focus)=='table' and (navigation_focus.section=='jobprogression' or navigation_focus.job~=nil);
    if progression_requested and imgui.SetNextItemOpen then
        pcall(imgui.SetNextItemOpen,true,rawget(_G,'ImGuiCond_Always') or 1);
    end
    if imgui.CollapsingHeader then
        progression_open=imgui.CollapsingHeader('Job Progression##character_info_job_progression', ImGuiTreeNodeFlags_DefaultOpen or 0);
    else
        imgui.Text('Job Progression');
    end
    if progression_requested and progression_open and imgui.SetScrollHereY then pcall(imgui.SetScrollHereY,0.0); end
    if progression_open then
        draw_job_progression_sections(c,navigation_focus);
    end
end

function M.init(ctx)
    HC=ctx;
    if HC.modules and HC.modules.packets and HC.modules.packets.register_text then
        HC.modules.packets.register_text('maat_victory_tracker',maat_tracker_on_text);
    end
end
return M;
