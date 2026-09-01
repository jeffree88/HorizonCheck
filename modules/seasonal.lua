local M={};
local HC;

-- Recurring seasonal-event families documented by the HorizonXI Wiki Guides /
-- Special Events catalog. Anniversary has its own dedicated HorizonCheck tab.
-- Reward lists intentionally focus on unique/collectible rewards; repeatable
-- food, fireworks, colored drops and temporary costumes are described in the
-- event notes instead of being treated as permanent collection goals.
local EVENTS={
    {
        id='egg_hunt', name='Egg Hunt Egg-stravaganza', season='Spring / April',
        source='HorizonXI Egg Hunt Egg-stravaganza 2025', verified_years={2025},
        note='2025 standard + Era+ collectible rewards. Repeatable Chocobo Tickets, colored drops and temporary Beastman costumes are not collection-tracked.',
        rewards={
            {id='egg_helm',name='Egg Helm',source='First Three'},
            {id='fortune_egg',name='Fortune Egg',source='Seven of a Kind'},
            {id='happy_egg',name='Happy Egg',source='Initial Straight Eight'},
            {id='wing_egg',name='Wing Egg',source='National Egg'},
            {id='lamp_egg',name='Lamp Egg',source='National Egg'},
            {id='flower_egg',name='Flower Egg',source='National Egg'},
            {id='jeweled_egg',name='Jeweled Egg',source='National Egg follow-up'},
            {id='orphic_egg',name='Orphic Egg',source='Weekday element combo'},
            {id='she_slime_candy',name='She-Slime Candy',source='PEEPS'},
            {id='hatchling_shield',name='Hatchling Shield',source='YOLKED'},
            {id='rabbit_belt',name='Rabbit Belt',source='HOPPER'},
            {id='she_slime_shield',name='She-Slime Shield',source='DEVILED'},
            {id='rabbit_cap',name='Rabbit Cap',source='WHISKERS'},
            {id='melodious_egg',name='Melodious Egg',source='CHATEAU'},
            {id='hatchling_egg',name='Hatchling Egg',source='HEAVENS'},
            {id='clockwork_egg',name='Clockwork Egg',source='MARKETS'},
            {id='gyokuto_obi_egg',name='Gyokuto Obi',source='BOUNCER',aliases={'Gyokuto Obi'}},
            {id='worm_belt',name='Worm Belt',source='SULFURIC'},
        },
    },
    {
        id='sunbreeze', name='Sunbreeze Festival', season='Summer / August',
        source='HorizonXI Sunbreeze Festival 2025 Guide', verified_years={2025},
        note='Tracks the documented collectible festival rewards. Fireworks, colored drops, Super Scoops and other consumables are not collection goals.',
        rewards={
            {id='swim_top_nq',name='RSE Swimming Top',source='Whack-a-Mandie - 20 points',aliases={'Hume Top','Hume Gilet','Mithra Top','Elvaan Top','Elvaan Gilet','Galka Gilet','Tarutaru Top','Tarutaru Maillot'}},
            {id='swim_bottom_nq',name='RSE Swimming Bottom',source='Whack-a-Mandie - 20 points',aliases={'Hume Shorts','Hume Trunks','Mithra Shorts','Elvaan Shorts','Elvaan Trunks','Galka Trunks','Tarutaru Shorts','Tarutaru Trunks'}},
            {id='festive_yukata',name='Festive Yukata',source='Whack-a-Mandie - 25 points',aliases={'Omina Yukata','Onoko Yukata'}},
            {id='upgraded_yukata',name='Upgraded Yukata',source='Whack-a-Mandie - 35 points',aliases={"Lady's Yukata","Lord's Yukata"}},
            {id='swim_top_hq',name='RSE Swimming Top +1',source='Racetrack win',aliases={'Hume Top +1','Hume Gilet +1','Mithra Top +1','Elvaan Top +1','Elvaan Gilet +1','Galka Gilet +1','Tarutaru Top +1','Tarutaru Maillot +1'}},
            {id='swim_bottom_hq',name='RSE Swimming Bottom +1',source='Racetrack win',aliases={'Hume Shorts +1','Hume Trunks +1','Mithra Shorts +1','Elvaan Shorts +1','Elvaan Trunks +1','Galka Trunks +1','Tarutaru Shorts +1','Tarutaru Trunks +1'}},
            {id='midgard_top',name='Midgardsormr RSE Top +1',source='Defeat Midgardsormr',aliases={'Custom Gilet +1','Custom Top +1','Savage Top +1','Magna Gilet +1','Magna Top +1','Elder Gilet +1','Wonder Maillot +1','Wonder Top +1'}},
            {id='goldfish_set',name='Goldfish Set',source='Goldfish Scooping - 65 points'},
            {id='white_butterfly',name='White Butterfly',source='Goldfish Scooping - 70 points'},
            {id='bell_cricket',name='Bell Cricket',source='Goldfish Scooping - 70 points'},
            {id='glowfly',name='Glowfly',source='Goldfish Scooping - 70 points'},
        },
    },
    {
        id='harvest', name='Harvest Festival', season='Autumn / Halloween',
        source='HorizonXI Harvest Festival 2025 Guide', verified_years={2025},
        note='2025 confirmed collectible rewards. Eerie Cloak +1, Witch Hat and Coven Hat are not included because the 2025 guide did not confirm them.',
        rewards={
            {id='eerie_cloak',name='Eerie Cloak',source='Pumpkin King - 1 kill'},
            {id='goblin_suit',name='Goblin Suit',source='Pumpkin King - 5 kills'},
            {id='pitchfork',name='Pitchfork',source='Trick or Treat'},
            {id='pitchfork_p1',name='Pitchfork +1',source='Trick or Treat upgrade'},
            {id='trick_staff',name='Trick Staff',source='Trick or Treat'},
            {id='trick_staff_ii',name='Trick Staff II',source='Trick or Treat'},
            {id='pumpkin_head',name='Pumpkin Head',source='Trick or Treat'},
            {id='pumpkin_head_ii',name='Pumpkin Head II',source='Trick or Treat'},
            {id='horror_head',name='Horror Head',source='Trick or Treat upgrade'},
            {id='horror_head_ii',name='Horror Head II',source='Trick or Treat upgrade'},
            {id='treat_staff',name='Treat Staff',source='Trick or Treat upgrade'},
            {id='treat_staff_ii',name='Treat Staff II',source='Trick or Treat upgrade'},
        },
    },
    {
        id='starlight', name='Starlight Celebration', season='Winter / December',
        source='HorizonXI Starlight Celebration 2025 Guide', verified_years={2025},
        note='Unique equipment/furnishing rewards from the 2025 quests, token tables and festival vendors. Repeatable food and celebration toys are not collection-tracked.',
        rewards={
            {id='dream_robe',name='Dream Robe',source='Star-themed Gift Token'},
            {id='dream_robe_p1',name='Dream Robe +1',source='Star-themed Gift Token'},
            {id='dream_pants',name='Dream Pants / Trousers',source='Goblin Merrymaker - first completion',aliases={'Dream Pants','Dream Trousers'}},
            {id='dream_pants_p1',name='Dream Pants / Trousers +1',source='Goblin Merrymaker - second completion',aliases={'Dream Pants +1','Dream Trousers +1'}},
            {id='dream_boots',name='Dream Boots',source='Bell-themed Gift Token'},
            {id='dream_boots_p1',name='Dream Boots +1',source='Bell-themed Gift Token'},
            {id='dream_mittens',name='Dream Mittens',source='Snow-themed Gift Token'},
            {id='dream_mittens_p1',name='Dream Mittens +1',source='Snow-themed Gift Token'},
            {id='dream_hat',name='Dream Hat',source='Starlight seasonal reward'},
            {id='dream_hat_p1',name='Dream Hat +1',source='Smilebringer fame reward'},
            {id='dream_bell',name='Dream Bell',source='Token redemption'},
            {id='dream_bell_p1',name='Dream Bell +1',source='All three tokens / repeat'},
            {id='snowman_cap',name='Snowman Cap',source='Festival vendor / reward'},
            {id='sandorian_tree',name="San d'Orian Tree",source='Festival reward / vendor'},
            {id='bastokan_tree',name='Bastokan Tree',source='Festival reward / vendor'},
            {id='windurstian_tree',name='Windurstian Tree',source='Festival reward / vendor'},
            {id='jeunoan_tree',name='Jeunoan Tree',source='Smilebringer Bootcamp - first completion'},
            {id='snowman_knight',name='Snowman Knight',source='Star-themed Gift Token / vendor'},
            {id='snowman_miner',name='Snowman Miner',source='Snow-themed Gift Token / vendor'},
            {id='snowman_mage',name='Snowman Mage',source='Bell-themed Gift Token / vendor'},
            {id='leafberry_wreath',name='Leafberry Wreath',source='Bell-themed Gift Token'},
            {id='silberkranz',name='Silberkranz',source='Snow-themed Gift Token'},
            {id='couronne_des_etoiles',name='Couronne des Etoiles',source='Star-themed Gift Token'},
            {id='gyokuto_obi_starlight',name='Gyokuto Obi',source='Starlight reward',aliases={'Gyokuto Obi'}},
        },
    },
};


local function year_set(v)
    local out={}; for _,y in ipairs(type(v)=='table' and v or {}) do out[tonumber(y)]=true; end return out;
end
local function latest_verified_year(event,reward)
    local ys=(type(reward)=='table' and reward.verified_years) or event.verified_years or {};
    local latest=nil; for _,y in ipairs(ys) do y=tonumber(y); if y and (latest==nil or y>latest) then latest=y; end end
    return latest;
end
local function reward_year_state(event,reward,year)
    year=tonumber(year) or tonumber(os.date('%Y'));
    local verified=year_set((type(reward)=='table' and reward.verified_years) or event.verified_years);
    local unavailable=year_set((type(reward)=='table' and reward.unavailable_years) or {});
    if unavailable[year] then return 'NOT AVAILABLE THIS YEAR',year; end
    if verified[year] then return 'CURRENT',year; end
    local latest=latest_verified_year(event,reward);
    if latest and year>latest then return 'HISTORICAL',latest; end
    return 'YEAR UNVERIFIED',latest;
end

local function ensure(c)
    c.seasonal=type(c.seasonal)=='table' and c.seasonal or {};
    c.seasonal.obtained=type(c.seasonal.obtained)=='table' and c.seasonal.obtained or {};
    c.seasonal.meta=type(c.seasonal.meta)=='table' and c.seasonal.meta or {};
    return c.seasonal;
end

local function reward_key(event,reward)
    return tostring(event.id)..':'..tostring(reward.id);
end

local function aliases(reward)
    if type(reward.aliases)=='table' and #reward.aliases>0 then return reward.aliases; end
    return {reward.name};
end

local reward_id_cache={};
local catalog_status_cache=nil;
local function reward_item_ids(reward)
    local key=tostring(reward.id or reward.name or '');
    if reward_id_cache[key]~=nil then return reward_id_cache[key]; end
    local ids={};
    if HC.modules.ownership and HC.modules.ownership.resolve_ids then
        ids=HC.modules.ownership.resolve_ids(aliases(reward)) or {};
    end
    reward_id_cache[key]=ids;
    return ids;
end

local function current_location(reward)
    local own=HC.modules.ownership;
    if not own or not own.current then return nil,false,nil; end
    local info=own.current(aliases(reward),false);
    return info.owned and info.location or nil,info.known,info.matched;
end

-- Cache the full Seasonal ownership view so reward rows, event counts and
-- persistence reconciliation do not repeat resource lookups several times in
-- the same rendered frame. The shared collection scan still invalidates from
-- Ashita inventory updates; this cache simply coalesces duplicate reads.
local ownership_cache={};
local OWNERSHIP_TTL=2;

local function char_cache_key(c)
    return tostring(HC.modules.core and HC.modules.core.character_name and HC.modules.core.character_name() or c);
end

local function invalidate_ownership_cache(c)
    ownership_cache[char_cache_key(c)]=nil;
end

local function ownership_snapshot(c,force)
    local s=ensure(c);
    local ck=char_cache_key(c);
    local now=os.time();
    local token=(HC.modules.skills and HC.modules.skills.collection_scan_token and HC.modules.skills.collection_scan_token()) or 'na';
    local cached=ownership_cache[ck];
    if not force and cached and cached.token==token and (now-tonumber(cached.at or 0))<OWNERSHIP_TTL then
        if HC.modules.profiler and HC.modules.profiler.cache then HC.modules.profiler.cache('seasonal.ownership',true); end
        return cached;
    end
    if HC.modules.profiler and HC.modules.profiler.cache then HC.modules.profiler.cache('seasonal.ownership',false); end
    if HC.modules.profiler and HC.modules.profiler.bump then HC.modules.profiler.bump('seasonal.snapshot.rebuild'); end

    local available=false;
    if HC.modules.skills and HC.modules.skills.collection_scan_available then
        available=HC.modules.skills.collection_scan_available(false)==true;
    end
    -- collection_scan_available may have refreshed the shared scan, so read
    -- the token again before publishing this snapshot.
    token=(HC.modules.skills and HC.modules.skills.collection_scan_token and HC.modules.skills.collection_scan_token()) or token;

    local snap={at=now,token=token,available=available,rows={},counts={}};
    local changed=false;
    for _,event in ipairs(EVENTS) do
        local have=0;
        for _,reward in ipairs(event.rewards) do
            local key=reward_key(event,reward);
            local loc,scan_ok,matched=nil,available,nil;
            if available then loc,scan_ok,matched=current_location(reward); end
            if scan_ok and loc and s.obtained[key]~=true then
                s.obtained[key]=true;
                s.meta[key]={at=now,source='Inventory / storage / wardrobe scan',location=loc,matched=matched};
                changed=true;
            end
            local owned=(loc~=nil) or s.obtained[key]==true;
            local status=loc or (s.obtained[key]==true and 'SAVED' or (scan_ok and 'MISSING' or 'UNKNOWN'));
            local year_state,year_basis=reward_year_state(event,reward,tonumber(os.date('%Y')));
            snap.rows[key]={owned=owned,status=status,matched=matched or (s.meta[key] and s.meta[key].matched or nil),item_ids=reward_item_ids(reward),year_state=year_state,year_basis=year_basis};
            if owned then have=have+1; end
        end
        snap.counts[event.id]={have=have,total=#event.rewards};
    end
    ownership_cache[ck]=snap;
    if changed and HC.modules.state then HC.modules.state.request_save(); end
    return snap;
end

local function reconcile(c,force)
    local snap=ownership_snapshot(c,force==true);
    return false,snap.available==true;
end

local function reward_status(c,event,reward,snap)
    snap=snap or ownership_snapshot(c,false);
    local row=snap.rows[reward_key(event,reward)] or {};
    return row.owned==true,row.status or 'UNKNOWN',row.matched;
end

local SEASONAL_STATUS_SHORT={
    ['INVENTORY']='Inv', ['SAFE']='Safe', ['STORAGE']='Storage', ['TEMP']='Temp', ['LOCKER']='Locker',
    ['SATCHEL']='Satchel', ['SACK']='Sack', ['CASE']='Case', ['MANUAL']='Saved', ['SAVED']='Saved',
    ['WARDROBE 1']='W1', ['WARDROBE 2']='W2', ['WARDROBE 3']='W3', ['WARDROBE 4']='W4',
    ['WARDROBE 5']='W5', ['WARDROBE 6']='W6', ['WARDROBE 7']='W7', ['WARDROBE 8']='W8',
};

local function short_status_label(status)
    local key=string.upper(tostring(status or ''));
    return SEASONAL_STATUS_SHORT[key] or tostring(status or '');
end

local function draw_reward_table(c,event,snap)
    local imgui=HC.imgui; local s=ensure(c);
    local table_ok=imgui.BeginTable~=nil and imgui.TableSetupColumn~=nil and imgui.TableHeadersRow~=nil
        and imgui.TableNextRow~=nil and imgui.TableSetColumnIndex~=nil and imgui.EndTable~=nil;
    if table_ok and imgui.BeginTable('##seasonal_rewards_'..event.id,3,(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512)) then
        imgui.TableSetupColumn('Reward',0,225);
        imgui.TableSetupColumn('Source',0,340);
        imgui.TableSetupColumn('Status',0,115);
        imgui.TableHeadersRow();
        for _,reward in ipairs(event.rewards) do
            local owned,status,matched=reward_status(c,event,reward,snap);
            local key=reward_key(event,reward);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);
            imgui.Text(tostring(reward.name));
            if matched and matched~=reward.name and imgui.IsItemHovered and imgui.IsItemHovered() then
                imgui.SetTooltip('Detected item: '..tostring(matched));
            end
            imgui.TableSetColumnIndex(1);
            imgui.TextDisabled(tostring(reward.source or '-'));
            imgui.TableSetColumnIndex(2);
            local v={owned==true};
            if imgui.Checkbox((owned and 'OBTAINED' or 'MISSING')..'##seasonal_'..key,v) then
                s.obtained[key]=v[1] and true or nil;
                if v[1] then
                    s.meta[key]={at=os.time(),source='Manual confirmation',location='MANUAL'};
                else
                    s.meta[key]=nil;
                end
                invalidate_ownership_cache(c);
                HC.modules.state.save();
            end
            if status and status~='MISSING' and status~='UNKNOWN' then
                imgui.SameLine(); imgui.TextDisabled('['..short_status_label(status)..']');
            end
            local yr=snap.rows[key] or {};
            if yr.year_state=='HISTORICAL' then imgui.SameLine(); imgui.TextDisabled('[Older '..tostring(yr.year_basis or '?')..']');
            elseif yr.year_state=='NOT AVAILABLE THIS YEAR' then imgui.SameLine(); imgui.TextDisabled('[Not this year]');
            elseif yr.year_state=='YEAR UNVERIFIED' then imgui.SameLine(); imgui.TextDisabled('[Year ?]'); end
        end
        imgui.EndTable();
    else
        for _,reward in ipairs(event.rewards) do
            local owned,status=reward_status(c,event,reward,snap);
            local key=reward_key(event,reward);
            local v={owned==true};
            if imgui.Checkbox(tostring(reward.name)..'##seasonal_'..key,v) then
                s.obtained[key]=v[1] and true or nil;
                if v[1] then s.meta[key]={at=os.time(),source='Manual confirmation',location='MANUAL'}; else s.meta[key]=nil; end
                invalidate_ownership_cache(c);
                HC.modules.state.save();
            end
            imgui.SameLine();
            if owned then imgui.Text('OBTAINED'); else imgui.TextDisabled('MISSING'); end
            if status and status~='MISSING' and status~='UNKNOWN' then imgui.SameLine(); imgui.TextDisabled('['..tostring(status)..']'); end
        end
    end
end

local function event_counts(c,event,snap)
    snap=snap or ownership_snapshot(c,false);
    local row=snap.counts[event.id];
    if row then return row.have,row.total; end
    return 0,#event.rewards;
end

local initial_scan_done={};

function M.draw(c,embedded,focus)
    local imgui=HC.imgui; if not imgui then return; end
    ensure(c);
    local char_key=tostring(HC.modules.core and HC.modules.core.character_name and HC.modules.core.character_name() or c);
    if initial_scan_done[char_key]~=true then
        if HC.modules.skills and HC.modules.skills.refresh_collection_scan then
            HC.modules.skills.refresh_collection_scan();
        end
        initial_scan_done[char_key]=true;
    end
    local snap=ownership_snapshot(c,false);
    if embedded~=true then imgui.Text('HorizonXI Seasonal'); end
    imgui.TextDisabled('Recurring HorizonXI seasonal events and their collectible rewards.');
    imgui.TextDisabled('HorizonCheck looks for these in your inventory, storage, and Wardrobes 1-8, and remembers them once found. Use the checkbox for older rewards hidden in storage HorizonCheck cannot scan.');
    if embedded~=true then imgui.Separator(); end

    for _,event in ipairs(EVENTS) do
        local have,total=event_counts(c,event,snap);
        local header=string.format('%s - %d/%d obtained',event.name,have,total);
        if total>0 and have>=total then header=header..' - COMPLETE'; end
        if type(focus)=='table' and tostring(focus.event_id or '')==tostring(event.id) and imgui.SetNextItemOpen then pcall(imgui.SetNextItemOpen,true,rawget(_G,'ImGuiCond_Always') or 1); end
        if imgui.CollapsingHeader(header..'##seasonal_event_'..event.id) then
            imgui.TextDisabled('Season: '..tostring(event.season));
            imgui.TextDisabled('Source basis: '..tostring(event.source));
            local current_year=tonumber(os.date('%Y')); local ys=year_set(event.verified_years);
            if ys[current_year] then imgui.TextDisabled('Year availability: '..tostring(current_year)..' available');
            else imgui.TextDisabled('Year availability: '..tostring(current_year)..' not confirmed | latest confirmed year '..tostring(latest_verified_year(event,{}) or '?')); end
            imgui.TextDisabled(tostring(event.note));
            draw_reward_table(c,event,snap);
        end
    end
end

function M.reconcile(c,force)
    c=c or HC.modules.state.get_char();
    local before=type(c.seasonal)=='table' and type(c.seasonal.obtained)=='table' and 0 or 0;
    local s=ensure(c); for _ in pairs(s.obtained) do before=before+1; end
    local snap=ownership_snapshot(c,force==true);
    local after=0; for _ in pairs(s.obtained) do after=after+1; end
    return {changed=math.max(0,after-before),available=snap.available==true,at=snap.at,token=snap.token};
end

function M.invalidate(c) invalidate_ownership_cache(c or HC.modules.state.get_char()); end

function M.progress(c)
    ensure(c); local snap=ownership_snapshot(c,false);
    local out={events=0,events_complete=0,rewards=0,rewards_obtained=0};
    for _,event in ipairs(EVENTS) do
        local have,total=event_counts(c,event,snap);
        out.events=out.events+1; out.rewards=out.rewards+total; out.rewards_obtained=out.rewards_obtained+have;
        if total>0 and have>=total then out.events_complete=out.events_complete+1; end
    end
    return out;
end

function M.events()
    return EVENTS;
end

function M.catalog_entries(c)
    c=c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    local snap=ownership_snapshot(c,false);
    local out={};
    for _,event in ipairs(EVENTS) do
        for _,reward in ipairs(event.rewards or {}) do
            local row=snap.rows[reward_key(event,reward)] or {};
            out[#out+1]={
                name=tostring(reward.name),event=tostring(event.name),event_id=tostring(event.id),season=tostring(event.season),source=tostring(reward.source or ''),
                owned=row.owned==true,location=tostring(row.status or ''),section='seasonal',
                search=table.concat({reward.name,event.name,event.season,reward.source or '',table.concat(reward.aliases or {},' ')},' '),
            };
        end
    end
    return out;
end

function M.catalog_status()
    if catalog_status_cache then return catalog_status_cache; end
    local total,resolved=0,0; local unresolved={};
    for _,event in ipairs(EVENTS) do
        for _,reward in ipairs(event.rewards or {}) do
            total=total+1;
            local ids=reward_item_ids(reward);
            if #ids>0 then resolved=resolved+1; else unresolved[#unresolved+1]=tostring(event.name)..' - '..tostring(reward.name); end
        end
    end
    local current_year=tonumber(os.date('%Y')); local current_verified=0; local historical=0; local unavailable_current=0;
    for _,event in ipairs(EVENTS) do for _,reward in ipairs(event.rewards or {}) do
        local ys=reward_year_state(event,reward,current_year);
        if ys=='CURRENT' then current_verified=current_verified+1 elseif ys=='HISTORICAL' then historical=historical+1 elseif ys=='NOT AVAILABLE THIS YEAR' then unavailable_current=unavailable_current+1 end
    end end
    catalog_status_cache={total=total,resolved=resolved,unresolved=unresolved,current_year=current_year,current_verified=current_verified,historical=historical,unavailable_current=unavailable_current};
    return catalog_status_cache;
end

function M.year_status(event,reward,year) return reward_year_state(event,reward,year); end
function M.init(ctx) HC=ctx; reward_id_cache={}; catalog_status_cache=nil; end
return M;
