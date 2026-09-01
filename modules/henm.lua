local M={};
local HC;
local cache={at=0,items={}};

local LOC_SHORT={
    ['INVENTORY']='Inv',['SAFE']='Safe',['STORAGE']='Storage',['TEMP']='Temp',['LOCKER']='Locker',
    ['SATCHEL']='Satchel',['SACK']='Sack',['CASE']='Case',
    ['WARDROBE 1']='Wardrobe 1',['WARDROBE 2']='Wardrobe 2',['WARDROBE 3']='Wardrobe 3',['WARDROBE 4']='Wardrobe 4',
    ['WARDROBE 5']='Wardrobe 5',['WARDROBE 6']='Wardrobe 6',['WARDROBE 7']='Wardrobe 7',['WARDROBE 8']='Wardrobe 8',
};

local TIER1={
    id='tier1', tier=1, label='Tier 1', pop='Faded Stone', price=50000, exp=2500, shards=50,
    fights={
        {
            id='decapod',name='Despotic Decapod',zone='Jugner Forest',spawns='F-8 / H-9 / I-5',time='60m',members='18',slug='Despotic_Decapod',
            mobs='Overlord Arthro (Lv.88) + Lord\'s Bruiser + Lord\'s Wizard + Poisonous Crab adds',
            mechanics='Wizard/Bruiser adds at each 20% HP; Poisonous Crab every ~90s with 50 HP/tick aura; Arthro rages around 30%.',
            strategy='Stun -ga spells, kill Wizard first, clear Poisonous Crabs quickly, and avoid stacking several adds.',
            rewards={{'Overlord\'s Ring','Notable'},{'Sprinter\'s Belt','Notable'},{'Deflecting Band','Notable'},{'Duality Loop','Notable'},{'Damascene Cloth','Notable'},{'Reraiser','Guaranteed'},{'Hi-Elixir','Guaranteed'}},
        },
        {
            id='rocs',name='Ruinous Rocs',zone='Rolanberry Fields',spawns='E-10 / F-10 / J-8',time='60m',members='18',slug='Ruinous_Rocs',
            mobs='Teratornis (RDM 88) + Argentavis (BRD 88) + Kelenken (WHM 88)',
            mechanics='When one Roc dies the others use their two-hour abilities; Teratornis Chainspells AoE magic; Argentavis also gains a rage/Hundred Fists effect.',
            strategy='Recommended order WHM > RDM > BRD. Let the first two corpses fully despawn before killing the final Roc or drops can be lost.',
            rewards={{'Trotter Boots','Notable'},{"Rucke's Rung",'Notable'},{"Vaulter's Ring",'Notable'},{'Luftpause Mark','Notable'},{'Damascus Ingot','Notable'},{'Protectra V','Notable'},{'Reraiser','Guaranteed'},{'Hi-Elixir','Guaranteed'}},
        },
        {
            id='scorpions',name='Sacred Scorpions',zone='Sauromugue Champaign',spawns='F-5 / H-8 / K-9',time='60m',members='18',slug='Sacred_Scorpions',
            mobs='Batcheh (WHM 88) + Sefedsepu (WAR 88) + Ifdet (RDM 88)',
            mechanics='Random spawn order; must be killed in reverse spawn order. Petrification on attacks; 40-yalm TP effects; Venom Storm inflicts 100 HP/tick Poison.',
            strategy='Tank the three ~45 yalms apart in a triangle, bring Antidotes, kill in reverse spawn order, and use Stun aggressively.',
            rewards={{"Horus's Helm",'Notable'},{'Dilation Ring','Notable'},{'Carapace Bullet','Notable'},{'Opuntia Hoop','Notable'},{'Venomous Claw','Notable'},{'Reraiser','Guaranteed'},{'Hi-Elixir','Guaranteed'}},
        },
    },
};

local TIER2={
    id='tier2', tier=2, label='Tier 2', pop='Faded Gem', price=100000, exp=3750, shards=75,
    requirement='One Tier 1 clear is required to purchase Tier 2 pops.',
    fights={
        {
            id='mammet',name='Mammet-9999',zone='Misareaux Coast',spawns='I-6 / F-8 / I-11',time='60m',members='18',slug='Mammet-9999_(HENM)',hard='Yellow Liquid before any action',hard_reward='Ageist',
            mobs='Mammet-9999',
            mechanics='Four weapon phases: H2H 100-75%, Sword 75-50%, Polearm 50-25%, Staff 25-0%.',
            strategy='Hard Mode: use Yellow Liquid on Mammet-9999 before anyone takes an action against it.',
            rewards={{"Balladeer's Harp",'Normal'},{'Virology Ring','Normal'},{'Mammet Fiber','Normal'},{"Sharpshooter's Ring",'Normal'},{"9999's Broken Collar",'Normal'},{'Ageist','Hard Mode'}},
        },
        {
            id='tonberry',name='Tonberry Sovereign',zone='Yhoator Jungle',spawns='F-10 / H-10 / I-11',time='60m',members='18',slug='Tonberry_Sovereign_(HENM)',hard='Same-element MB phases + Uggalepih Necklace at 40%',hard_reward='Nihility',
            mobs='Tonberry Sovereign + Tonberry Shinobi / Sorcerer / Raider adds',
            mechanics='Adds spawn every ~30s. At each 20% threshold the boss becomes damage-immune and targets a player; skillchains + magic bursts are required to end the phase.',
            strategy='Hard Mode: use the same burst element through every phase; at the 40% phase have one alliance member wearing Uggalepih Necklace.',
            rewards={{'Begrudging Ring','Normal'},{'Hangeki Ring','Normal'},{"Maledictor's Shawl",'Normal'},{'Obscured Ring','Normal'},{'Montiont Silverpiece','Normal'},{'One Hundred Byne Bill','Normal'},{'Sovereign Coat','Normal'},{'Nihility','Hard Mode'}},
        },
        {
            id='ultimega',name='Ultimega',zone='Lufaise Meadows',spawns='J-7 / J-9 / K-9',time='60m',members='18',slug='Ultimega_(HENM)',hard='CCB Polymer Pump before any action',hard_reward='Levin',
            mobs='Neo-Ultima + Neo-Omega',
            mechanics='Keep both within 10% HP and roughly 20 yalms of each other; crossing each x0% threshold unevenly causes heavy TP spam.',
            strategy='Lower them together and cross HP thresholds together. Hard Mode: use CCB Polymer Pump before any action is taken.',
            rewards={{'Spirited Ring','Normal'},{"Ultima's Left Arm",'Normal'},{'Bravery Band','Normal'},{'Ensorcelled Shard','Normal'},{'Terminal Alloy','Normal'},{'Lungo-Nango Jadeshell','Normal'},{'Montiont Silverpiece','Normal'},{'Levin','Hard Mode'}},
        },
    },
};

local TIERS={TIER1,TIER2};

function M.init(ctx) HC=ctx; end

local function comma(n)
    local s=tostring(math.floor(tonumber(n) or 0));
    local sign=''; if s:sub(1,1)=='-' then sign='-'; s=s:sub(2); end
    local out=s;
    while true do
        local nrep; out,nrep=out:gsub('^(%d+)(%d%d%d)', '%1,%2');
        if nrep==0 then break; end
    end
    return sign..out;
end

local function open_url(slug)
    local url='https://horizonffxi.wiki/'..tostring(slug or 'Category:HENM');
    return pcall(function() os.execute('cmd /c start "" "'..url..'"'); end);
end

local function item_info(name)
    local now=os.time();
    cache.items=type(cache.items)=='table' and cache.items or {};
    local cached=cache.items[name];
    if cached and now-(tonumber(cached.at) or 0)<2 then return cached; end
    local out={name=name,count=0,owned=false,location='—',at=now};
    local s=HC.modules.skills;
    if not s or not s.collection_item_locations then cache.items[name]=out; return out; end
    local ok,rows,available=pcall(s.collection_item_locations,name,false);
    if not ok or available~=true then out.location='Checking...'; cache.items[name]=out; return out; end
    local locs={};
    if type(rows)=='table' then
        for _,row in ipairs(rows) do
            local n=math.max(0,tonumber(row and row.count) or 0);
            if n>0 then
                out.count=out.count+n;
                local label=LOC_SHORT[tostring(row.label or '')] or tostring(row.label or '');
                locs[#locs+1]=label..(n>1 and (' x'..tostring(n)) or '');
            end
        end
    end
    out.owned=out.count>0;
    if out.owned then out.location=table.concat(locs,', '); end
    if not out.owned and s.collection_item_location then
        local ok2,loc,available2=pcall(s.collection_item_location,name,false);
        if ok2 and available2==true and loc=='STORED' then out.owned=true; out.location='Porter Moogle'; end
    end
    cache.items[name]=out; return out;
end

local function pop_status(tier)
    local i=item_info(tier.pop);
    if i.owned then return 'POP HELD',i.location; end
    return 'NEED POP','Buy from Shady Tonberry';
end

local function draw_note(imgui,c,fight)
    c.henm_notes=type(c.henm_notes)=='table' and c.henm_notes or {};
    local key=tostring(fight.id);
    if imgui.SetNextItemWidth then pcall(function() imgui.SetNextItemWidth(-1); end); end
    local buf={tostring(c.henm_notes[key] or '')};
    local ok,changed=pcall(function() return imgui.InputText('##henm_note_'..key,buf,240); end);
    if ok and changed then
        local v=tostring(buf[1] or ''); c.henm_notes[key]=(v~='' and v or nil);
        HC.modules.state.save();
    elseif not ok then imgui.TextDisabled('[notes unavailable]'); end
end

local function draw_tier_table(c,tier)
    local imgui=HC.imgui;
    local pop_state,pop_loc=pop_status(tier);
    local hdr=string.format('%s  |  %s %s gil  |  %d EXP  |  %d Cerulean Shards##henm_%s',tier.label,tier.pop,comma(tier.price),tier.exp,tier.shards,tier.id);
    local flags=rawget(_G,'ImGuiTreeNodeFlags_DefaultOpen') or 0;
    if not imgui.CollapsingHeader(hdr,flags) then return; end
    imgui.TextDisabled(string.format('%s: %s%s',tier.pop,pop_state,pop_loc and (' - '..tostring(pop_loc)) or ''));
    if tier.requirement then imgui.TextDisabled(tier.requirement); end
    local tf=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
    local supported=imgui.BeginTable and imgui.TableSetupColumn and imgui.TableHeadersRow and imgui.TableNextRow and imgui.TableSetColumnIndex and imgui.EndTable;
    if supported and imgui.BeginTable('##henm_table_'..tier.id,7,tf) then
        imgui.TableSetupColumn('Fight',0,0.19); imgui.TableSetupColumn('Status',0,0.10); imgui.TableSetupColumn('Zone',0,0.16);
        imgui.TableSetupColumn('???',0,0.16); imgui.TableSetupColumn('Entry',0,0.13); imgui.TableSetupColumn('Reward',0,0.20);
        imgui.TableSetupColumn('',0,0.06); imgui.TableHeadersRow();
        for _,fight in ipairs(tier.fights) do
            local st,loc=pop_status(tier);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0); imgui.Text(tostring(fight.name));
            imgui.TableSetColumnIndex(1); if st=='POP HELD' then imgui.Text(st); else imgui.TextDisabled(st); end
            if imgui.IsItemHovered and imgui.IsItemHovered() then imgui.SetTooltip(tostring(loc or '')); end
            imgui.TableSetColumnIndex(2); imgui.TextDisabled(tostring(fight.zone));
            imgui.TableSetColumnIndex(3); imgui.TextDisabled(tostring(fight.spawns));
            imgui.TableSetColumnIndex(4); if st=='POP HELD' then imgui.Text(tostring(tier.pop)); else imgui.TextDisabled(tostring(tier.pop)); end
            imgui.TableSetColumnIndex(5); imgui.TextDisabled(string.format('%d EXP / %d Shards',tier.exp,tier.shards));
            imgui.TableSetColumnIndex(6); if imgui.SmallButton('GO##henm_'..fight.id) then open_url(fight.slug); end
        end
        imgui.EndTable();
    end
end

local function draw_fight_details(tier,fight,c,focus_id)
    local imgui=HC.imgui;
    if tostring(focus_id or '')==tostring(fight.id) and imgui.SetNextItemOpen then pcall(imgui.SetNextItemOpen,true,rawget(_G,'ImGuiCond_Always') or 1); end
    if not imgui.CollapsingHeader(fight.name..' Details##henm_details_'..fight.id) then return; end
    imgui.Text('Zone: '..fight.zone..'  |  ???: '..fight.spawns..'  |  Alliance: up to '..fight.members..'  |  Time: '..fight.time);
    imgui.TextDisabled('Entry: '..tier.pop..' ('..comma(tier.price)..' gil from Shady Tonberry in Rabao)');
    imgui.Spacing();
    imgui.Text('Enemies'); imgui.TextDisabled(fight.mobs);
    imgui.Text('Key mechanics'); imgui.TextDisabled(fight.mechanics);
    imgui.Text('Strategy'); imgui.TextDisabled(fight.strategy);
    if fight.hard then
        imgui.Text('Hard Mode'); imgui.TextDisabled(fight.hard..'  |  Guaranteed cosmetic: '..tostring(fight.hard_reward));
    end
    imgui.Spacing();
    imgui.Text('Notes');
    draw_note(imgui,c,fight);
    imgui.Spacing();
    imgui.Text('Rewards');
    local tf=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
    if imgui.BeginTable and imgui.BeginTable('##henm_rewards_'..fight.id,4,tf) then
        imgui.TableSetupColumn('Item',0,0.38); imgui.TableSetupColumn('Type',0,0.18); imgui.TableSetupColumn('Status',0,0.12); imgui.TableSetupColumn('Location',0,0.32); imgui.TableHeadersRow();
        for _,r in ipairs(fight.rewards or {}) do
            local info=item_info(r[1]);
            imgui.TableNextRow(); imgui.TableSetColumnIndex(0);
            if HC.modules.uikit and HC.modules.uikit.collection_item then HC.modules.uikit.collection_item(r[1],info.owned); elseif info.owned then imgui.Text(r[1]); else imgui.TextDisabled(r[1]); end
            imgui.TableSetColumnIndex(1); imgui.TextDisabled(r[2]);
            imgui.TableSetColumnIndex(2); if HC.modules.uikit and HC.modules.uikit.collection_status then HC.modules.uikit.collection_status(info.owned,'—'); else imgui.TextDisabled(info.owned and '✓' or '—'); end
            imgui.TableSetColumnIndex(3); if HC.modules.uikit and HC.modules.uikit.collection_location then HC.modules.uikit.collection_location(info.location,info.owned); else imgui.TextDisabled(info.owned and tostring(info.location) or '—'); end
        end
        imgui.EndTable();
    end
end

local function draw_reward_collection()
    local imgui=HC.imgui;
    local unique={}; local rows={};
    for _,tier in ipairs(TIERS) do
        for _,fight in ipairs(tier.fights) do
            for _,r in ipairs(fight.rewards or {}) do
                if not unique[r[1]] then unique[r[1]]=true; rows[#rows+1]={item=r[1],fight=fight.name,tier=tier.tier}; end
            end
        end
    end
    table.sort(rows,function(a,b) if a.tier~=b.tier then return a.tier<b.tier; end return a.item<b.item; end);
    local have=0; for _,r in ipairs(rows) do if item_info(r.item).owned then have=have+1; end end
    if not imgui.CollapsingHeader(string.format('HENM Reward Collection  %d/%d obtained##henm_collection',have,#rows)) then return; end
    imgui.TextDisabled('Items turn white when HorizonCheck finds them in inventory, storage, wardrobes, or known Porter storage. Consumables/currency can naturally disappear after use.');
    local tf=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
    if imgui.BeginTable and imgui.BeginTable('##henm_collection_table',5,tf) then
        imgui.TableSetupColumn('Tier',0,0.07); imgui.TableSetupColumn('Fight',0,0.24); imgui.TableSetupColumn('Item',0,0.31); imgui.TableSetupColumn('Status',0,0.10); imgui.TableSetupColumn('Location',0,0.28); imgui.TableHeadersRow();
        for _,r in ipairs(rows) do
            local info=item_info(r.item); imgui.TableNextRow(); imgui.TableSetColumnIndex(0); imgui.TextDisabled('T'..r.tier);
            imgui.TableSetColumnIndex(1); imgui.TextDisabled(r.fight);
            imgui.TableSetColumnIndex(2); if HC.modules.uikit and HC.modules.uikit.collection_item then HC.modules.uikit.collection_item(r.item,info.owned); elseif info.owned then imgui.Text(r.item); else imgui.TextDisabled(r.item); end
            imgui.TableSetColumnIndex(3); if HC.modules.uikit and HC.modules.uikit.collection_status then HC.modules.uikit.collection_status(info.owned,'—'); else imgui.TextDisabled(info.owned and '✓' or '—'); end
            imgui.TableSetColumnIndex(4); if HC.modules.uikit and HC.modules.uikit.collection_location then HC.modules.uikit.collection_location(info.location,info.owned); else imgui.TextDisabled(info.owned and tostring(info.location) or '—'); end
        end
        imgui.EndTable();
    end
end

function M.catalog_entries(c)
    local out={};
    for _,tier in ipairs(TIERS) do
        for _,fight in ipairs(tier.fights or {}) do
            out[#out+1]={
                kind='fight',name=tostring(fight.name),tier=tonumber(tier.tier),fight_id=tostring(fight.id),zone=tostring(fight.zone),spawns=tostring(fight.spawns),
                pop=tostring(tier.pop),detail=tostring(fight.mechanics),search=table.concat({fight.name,fight.zone,fight.spawns,tier.pop,fight.mechanics,fight.strategy or ''},' '),
            };
            for _,r in ipairs(fight.rewards or {}) do
                local info=item_info(r[1]);
                out[#out+1]={
                    kind='reward',name=tostring(r[1]),fight=tostring(fight.name),fight_id=tostring(fight.id),tier=tonumber(tier.tier),zone=tostring(fight.zone),
                    reward_type=tostring(r[2]),owned=info.owned==true,location=tostring(info.location or ''),search=table.concat({r[1],r[2],fight.name,fight.zone,'HENM'},' '),
                };
            end
        end
    end
    return out;
end

function M.draw(c)
    local imgui=HC.imgui; if not imgui then return; end
    c=c or HC.modules.state.get_char();
    local nav=(HC.modules.ui and HC.modules.ui.consume_focus) and HC.modules.ui.consume_focus('henm') or nil;
    local focus_id=type(nav)=='table' and tostring(nav.fight_id or '') or '';
    imgui.Text('HENM - Hyper Empty Notorious Monsters');
    imgui.TextDisabled('Current HorizonXI availability: Tier 1 + Tier 2. Up to 18 players; one pop item is needed for the alliance.');
    imgui.TextDisabled('Weekly reward lockout is per tier and resets with Conquest tally. First weekly clear: T1 = 2,500 EXP + 50 Shards | T2 = 3,750 EXP + 75 Shards.');
    imgui.TextDisabled('After a successful clear you may still help other groups, but you are loot-locked for that tier until the next Conquest tally. Failed attempts require another pop.');
    if imgui.SmallButton('Open HENM Overview##henm_overview') then open_url('Category:HENM'); end

    imgui.Spacing();
    draw_tier_table(c,TIER1);
    imgui.Spacing();
    draw_tier_table(c,TIER2);

    imgui.Spacing();
    if focus_id~='' and imgui.SetNextItemOpen then pcall(imgui.SetNextItemOpen,true,rawget(_G,'ImGuiCond_Always') or 1); end
    if imgui.CollapsingHeader('Fight Details / Strategy##henm_fight_details') then
        for _,tier in ipairs(TIERS) do
            imgui.Text(tier.label);
            for _,fight in ipairs(tier.fights) do draw_fight_details(tier,fight,c,focus_id); end
            imgui.Spacing();
        end
    end

    imgui.Spacing();
    draw_reward_collection();

    imgui.Spacing();
    if imgui.CollapsingHeader('Hard Mode / System Notes##henm_system_notes') then
        imgui.TextDisabled('Hard Mode currently applies to Tier 2 fights. Normal drops are promoted one Treasure Hunter rarity tier and each fight has a guaranteed cosmetic.');
        imgui.TextDisabled('Mammet-9999: Yellow Liquid before any action -> Ageist.');
        imgui.TextDisabled('Tonberry Sovereign: same-element magic-burst phases + Uggalepih Necklace at the 40% phase -> Nihility.');
        imgui.TextDisabled('Ultimega: CCB Polymer Pump before any action -> Levin.');
        imgui.TextDisabled('Players invited after the fight starts are not loot-eligible. A disconnected player must click the same ??? to regain Confrontation status.');
    end
end

return M;
