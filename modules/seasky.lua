local M={};
local HC;

-- Keep the Elemental Obis / Gorgets open state in HorizonCheck rather than
-- relying on the Ashita ImGui bridge. Live ownership changes alter the header
-- count, and some bridge builds can otherwise collapse the section when a
-- checkbox is toggled.
local science_section_open=false;

-- HorizonXI collection catalog for Tu'Lia (Sky) and Lumoria (Sea).
-- Sky includes the named god drops plus the wearable gear produced from each
-- god's abjurations. Sea includes the seven Jailers, three Ix'aern cape
-- exchanges, and Absolute Virtue equipment.
local SKY={
    {
        id='genbu',name='Genbu',zone="Ru'Aun Gardens",
        items={
            {name="Genbu's Shield",kind='Direct drop'},
            {name="Genbu's Kabuto",kind='Direct drop'},
            {name='Zenith Mitts',kind='Aquarian Abjuration: Hands'},
            {name='Zenith Mitts +1',kind='Aquarian Abjuration: Hands (HQ)'},
            {name='Shura Sune-Ate',kind='Dryadic Abjuration: Feet'},
            {name='Shura Sune-Ate +1',kind='Dryadic Abjuration: Feet (HQ)'},
            {name='Koenig Handschuhs',kind='Martial Abjuration: Hands'},
            {name='Kaiser Handschuhs',kind='Martial Abjuration: Hands (HQ)'},
            {name='Crimson Greaves',kind='Wyrmal Abjuration: Feet'},
            {name='Blood Greaves',kind='Wyrmal Abjuration: Feet (HQ)'},
        },
    },
    {
        id='suzaku',name='Suzaku',zone="Ru'Aun Gardens",
        items={
            {name="Suzaku's Scythe",kind='Direct drop'},
            {name="Suzaku's Sune-Ate",kind='Direct drop'},
            {name='Zenith Slacks',kind='Aquarian Abjuration: Legs'},
            {name='Zenith Slacks +1',kind='Aquarian Abjuration: Legs (HQ)'},
            {name='Shura Kote',kind='Dryadic Abjuration: Hands'},
            {name='Shura Kote +1',kind='Dryadic Abjuration: Hands (HQ)'},
            {name='Adaman Celata',kind='Earthen Abjuration: Head'},
            {name='Armada Celata',kind='Earthen Abjuration: Head (HQ)'},
            {name='Hecatomb Leggings',kind='Neptunal Abjuration: Feet'},
            {name='Hecatomb Leggings +1',kind='Neptunal Abjuration: Feet (HQ)'},
        },
    },
    {
        id='seiryu',name='Seiryu',zone="Ru'Aun Gardens",
        items={
            {name="Seiryu's Sword",kind='Direct drop'},
            {name="Seiryu's Kote",kind='Direct drop'},
            {name='Zenith Slacks',kind='Aquarian Abjuration: Legs'},
            {name='Zenith Slacks +1',kind='Aquarian Abjuration: Legs (HQ)'},
            {name='Shura Zunari Kabuto',kind='Dryadic Abjuration: Head'},
            {name='Shura Zunari Kabuto +1',kind='Dryadic Abjuration: Head (HQ)'},
            {name='Koenig Schaller',kind='Martial Abjuration: Head'},
            {name='Kaiser Schaller',kind='Martial Abjuration: Head (HQ)'},
            {name='Crimson Finger Gauntlets',kind='Wyrmal Abjuration: Hands'},
            {name='Blood Finger Gauntlets',kind='Wyrmal Abjuration: Hands (HQ)'},
        },
    },
    {
        id='byakko',name='Byakko',zone="Ru'Aun Gardens",
        items={
            {name="Byakko's Axe",kind='Direct drop'},
            {name="Byakko's Haidate",kind='Direct drop'},
            {name='Zenith Crown',kind='Aquarian Abjuration: Head'},
            {name='Zenith Crown +1',kind='Aquarian Abjuration: Head (HQ)'},
            {name='Shura Haidate',kind='Dryadic Abjuration: Legs'},
            {name='Shura Haidate +1',kind='Dryadic Abjuration: Legs (HQ)'},
            {name='Adaman Sollerets',kind='Earthen Abjuration: Feet'},
            {name='Armada Sollerets',kind='Earthen Abjuration: Feet (HQ)'},
            {name='Hecatomb Mittens',kind='Neptunal Abjuration: Hands'},
            {name='Hecatomb Mittens +1',kind='Neptunal Abjuration: Hands (HQ)'},
        },
    },
    {
        id='kirin',name='Kirin',zone="Shrine of Ru'Avitau",
        items={
            {name="Kirin's Pole",kind='Direct drop'},
            {name="Kirin's Osode",kind='Direct drop'},
            {name='Shura Togi',kind='Dryadic Abjuration: Body'},
            {name='Shura Togi +1',kind='Dryadic Abjuration: Body (HQ)'},
            {name='Hecatomb Harness',kind='Neptunal Abjuration: Body'},
            {name='Hecatomb Harness +1',kind='Neptunal Abjuration: Body (HQ)'},
            {name='Crimson Cuisses',kind='Wyrmal Abjuration: Legs'},
            {name='Blood Cuisses',kind='Wyrmal Abjuration: Legs (HQ)'},
        },
    },
};

local SEA={
    {id='temperance',name='Jailer of Temperance',zone="Grand Palace of Hu'Xzoi",items={
        {name='Temperance Axe',kind='Direct drop'},{name='Temperance Torque',kind='Direct drop'},
    }},
    {id='fortitude',name='Jailer of Fortitude',zone="The Garden of Ru'Hmet",items={
        {name='Fortitude Axe',kind='Direct drop'},{name='Fortitude Torque',kind='Direct drop'},
    }},
    {id='faith',name='Jailer of Faith',zone="The Garden of Ru'Hmet",items={
        {name='Faith Baghnakhs',kind='Direct drop'},{name='Faith Torque',kind='Direct drop'},
    }},
    {id='justice',name='Jailer of Justice',zone="Al'Taieu",items={
        {name='Justice Sword',kind='Direct drop'},{name='Justice Torque',kind='Direct drop'},
    }},
    {id='hope',name='Jailer of Hope',zone="Al'Taieu",items={
        {name='Hope Staff',kind='Direct drop'},{name='Hope Torque',kind='Direct drop'},
    }},
    {id='prudence',name='Jailer of Prudence',zone="Al'Taieu",items={
        {name='Prudence Rod',kind='Direct drop'},{name='Prudence Torque',kind='Direct drop'},
    }},
    {id='love',name='Jailer of Love',zone="Al'Taieu",items={
        {name='Love Halberd',kind='Direct drop'},{name='Love Torque',kind='Direct drop'},
        {name='Novio Earring',kind='Aura of Adulation -> Meret'},{name='Novia Earring',kind='Aura of Voracity -> Meret'},
    }},
    {id='ixaern_mnk',name="Ix'aern (MNK)",zone="Grand Palace of Hu'Xzoi",items={
        {name='Merciful Cape',kind='Vice of Antipathy -> Meret'},
    }},
    {id='ixaern_drk',name="Ix'aern (DRK)",zone="The Garden of Ru'Hmet",items={
        {name='Altruistic Cape',kind='Vice of Avarice -> Meret'},
    }},
    {id='ixaern_drg',name="Ix'aern (DRG)",zone="The Garden of Ru'Hmet",items={
        {name='Astute Cape',kind='Vice of Aspersion -> Meret'},
    }},
    {id='av',name='Absolute Virtue',zone="Al'Taieu",items={
        {name='Futsuno Mitama',kind='Sea God reward -> Meret'},
        {name='Aureole',kind='Sea God reward -> Meret'},
        {name="Raphael's Rod",kind='Sea God reward -> Meret'},
        {name="Ninurta's Sash",kind='Sea God reward -> Meret'},
        {name="Mars's Ring",kind='Sea God reward -> Meret'},
        {name="Bellona's Ring",kind='Sea God reward -> Meret'},
        {name="Minerva's Ring",kind='Sea God reward -> Meret'},
    }},
};


-- Elemental Obi / Gorget progression from the Lumoria quest "In the Name of Science".
-- Keep this separate from Sea boss-drop totals: these are crafted quest rewards whose
-- progress is driven by owned organs/materials and the finished item itself.
local SEA_SCIENCE={
    obis={
        {id='karin_obi',name='Karin Obi',materials={{name='Silver Obi',qty=1},{name='Red Chip',qty=1},{name='Phuabo Organ',qty=7},{name='Xzomit Organ',qty=3},{name='Luminian Tissue',qty=3}}},
        {id='dorin_obi',name='Dorin Obi',materials={{name='Silver Obi',qty=1},{name='Yellow Chip',qty=1},{name='Hpemde Organ',qty=7},{name='Aern Organ',qty=3},{name='Luminian Tissue',qty=3}}},
        {id='suirin_obi',name='Suirin Obi',materials={{name='Silver Obi',qty=1},{name='Blue Chip',qty=1},{name='Hpemde Organ',qty=7},{name='Phuabo Organ',qty=3},{name='Luminian Tissue',qty=3}}},
        {id='furin_obi',name='Furin Obi',materials={{name='Silver Obi',qty=1},{name='Green Chip',qty=1},{name='Aern Organ',qty=7},{name='Hpemde Organ',qty=3},{name='Luminian Tissue',qty=3}}},
        {id='hyorin_obi',name='Hyorin Obi',materials={{name='Silver Obi',qty=1},{name='Clear Chip',qty=1},{name='Xzomit Organ',qty=7},{name='Phuabo Organ',qty=3},{name='Luminian Tissue',qty=3}}},
        {id='rairin_obi',name='Rairin Obi',materials={{name='Silver Obi',qty=1},{name='Purple Chip',qty=1},{name='Phuabo Organ',qty=7},{name='Hpemde Organ',qty=3},{name='Luminian Tissue',qty=3}}},
        {id='korin_obi',name='Korin Obi',materials={{name='Silver Obi',qty=1},{name='White Chip',qty=1},{name='Xzomit Organ',qty=7},{name='Aern Organ',qty=3},{name='Luminian Tissue',qty=3}}},
        {id='anrin_obi',name='Anrin Obi',materials={{name='Silver Obi',qty=1},{name='Black Chip',qty=1},{name='Aern Organ',qty=7},{name='Xzomit Organ',qty=3},{name='Luminian Tissue',qty=3}}},
    },
    gorgets={
        {id='flame_gorget',name='Flame Gorget',materials={{name='Gorget',qty=1},{name='Red Chip',qty=1},{name='Phuabo Organ',qty=10},{name='Xzomit Organ',qty=5},{name='Yovra Organ',qty=1}}},
        {id='soil_gorget',name='Soil Gorget',materials={{name='Gorget',qty=1},{name='Yellow Chip',qty=1},{name='Xzomit Organ',qty=10},{name='Aern Organ',qty=5},{name='Yovra Organ',qty=1}}},
        {id='aqua_gorget',name='Aqua Gorget',materials={{name='Gorget',qty=1},{name='Blue Chip',qty=1},{name='Aern Organ',qty=10},{name='Hpemde Organ',qty=5},{name='Yovra Organ',qty=1}}},
        {id='breeze_gorget',name='Breeze Gorget',materials={{name='Gorget',qty=1},{name='Green Chip',qty=1},{name='Phuabo Organ',qty=10},{name='Hpemde Organ',qty=5},{name='Yovra Organ',qty=1}}},
        {id='snow_gorget',name='Snow Gorget',materials={{name='Gorget',qty=1},{name='Clear Chip',qty=1},{name='Phuabo Organ',qty=10},{name='Aern Organ',qty=5},{name='Yovra Organ',qty=1}}},
        {id='thunder_gorget',name='Thunder Gorget',materials={{name='Gorget',qty=1},{name='Purple Chip',qty=1},{name='Xzomit Organ',qty=10},{name='Hpemde Organ',qty=5},{name='Yovra Organ',qty=1}}},
        {id='light_gorget',name='Light Gorget',materials={{name='Gorget',qty=1},{name='White Chip',qty=1},{name='Aern Organ',qty=7},{name='Phuabo Organ',qty=3},{name='Hpemde Organ',qty=3},{name='Yovra Organ',qty=2}}},
        {id='shadow_gorget',name='Shadow Gorget',materials={{name='Gorget',qty=1},{name='Black Chip',qty=1},{name='Hpemde Organ',qty=7},{name='Phuabo Organ',qty=3},{name='Aern Organ',qty=3},{name='Yovra Organ',qty=2}}},
    },
};

local function normalize(s)
    return tostring(s or ''):lower():gsub('[^%w]+','_'):gsub('^_+',''):gsub('_+$','');
end

local function ensure(c)
    c.sea_sky=type(c.sea_sky)=='table' and c.sea_sky or {};
    c.sea_sky.obtained=type(c.sea_sky.obtained)=='table' and c.sea_sky.obtained or {};
    c.sea_sky.meta=type(c.sea_sky.meta)=='table' and c.sea_sky.meta or {};
    c.sea_sky.ui=type(c.sea_sky.ui)=='table' and c.sea_sky.ui or {};
    return c.sea_sky;
end

local function section_ui(c,id)
    local s=ensure(c); id=tostring(id or '');
    s.ui[id]=type(s.ui[id])=='table' and s.ui[id] or {};
    local u=s.ui[id];
    if u.missing_only==nil then u.missing_only=false; end
    if u.hide_complete==nil then u.hide_complete=false; end
    return u;
end

local function item_key(item)
    return normalize(item and item.name or item);
end

-- Sky abjuration equipment has mutually exclusive NQ/HQ results. Treat the
-- two quality variants as one collection slot so the tracker does not imply
-- that both versions are required. Direct drops remain separate items.
local SKY_PAIR_BASES={};
do
    for _,group in ipairs(SKY) do
        for _,item in ipairs(group.items or {}) do
            local kind=tostring(item.kind or '');
            local base=kind:match('^(.-) %(HQ%)$');
            if base and base~='' then SKY_PAIR_BASES[base]=true; end
        end
    end
end

local function sky_pair_base(item)
    local kind=tostring(item and item.kind or '');
    local base=kind:match('^(.-) %(HQ%)$') or kind;
    if SKY_PAIR_BASES[base]==true then return base; end
    return nil;
end

local function sky_slot_key(item)
    local base=sky_pair_base(item);
    if base then return 'sky_pair_'..normalize(base); end
    return item_key(item);
end

local function display_rows(items,is_sky)
    local rows={};
    if not is_sky then
        for _,item in ipairs(items or {}) do
            rows[#rows+1]={name=item.name,kind=item.kind,items={item},key=item_key(item)};
        end
        return rows;
    end

    local pairs={};
    for _,item in ipairs(items or {}) do
        local base=sky_pair_base(item);
        if base then
            pairs[base]=pairs[base] or {};
            if tostring(item.kind or ''):match(' %(HQ%)$') then pairs[base].hq=item; else pairs[base].nq=item; end
        end
    end

    local emitted={};
    for _,item in ipairs(items or {}) do
        local base=sky_pair_base(item);
        if base then
            if not emitted[base] then
                emitted[base]=true;
                local pair=pairs[base] or {};
                local nq=pair.nq; local hq=pair.hq;
                local names={}; local variants={};
                if nq then names[#names+1]=nq.name; variants[#variants+1]=nq; end
                if hq then names[#names+1]=hq.name; variants[#variants+1]=hq; end
                if #variants==0 then variants={item}; names={item.name}; end
                rows[#rows+1]={
                    name=table.concat(names,' / '),
                    kind=base..' (NQ / HQ)',
                    items=variants,
                    key='sky_pair_'..normalize(base),
                };
            end
        else
            rows[#rows+1]={name=item.name,kind=item.kind,items={item},key=item_key(item)};
        end
    end
    return rows;
end

local function collection_location(item)
    local own=HC.modules.ownership; if not own or not own.current then return nil,false,nil; end
    local info=own.current(item.name,false);
    return info.owned and info.location or nil,info.known,info.matched;
end

local function unique_catalog(groups)
    local out={}; local seen={};
    for _,group in ipairs(groups) do
        for _,item in ipairs(group.items or {}) do
            local k=item_key(item);
            if not seen[k] then seen[k]=true; out[#out+1]=item; end
        end
    end
    return out;
end

local SKY_UNIQUE=unique_catalog(SKY);
local SEA_UNIQUE=unique_catalog(SEA);
local SKY_SLOTS={};
do
    local seen={};
    for _,group in ipairs(SKY) do
        for _,row in ipairs(display_rows(group.items,true)) do
            if not seen[row.key] then seen[row.key]=true; SKY_SLOTS[#SKY_SLOTS+1]=row; end
        end
    end
end
local ALL_UNIQUE={};
do
    local seen={};
    for _,list in ipairs({SKY_UNIQUE,SEA_UNIQUE}) do
        for _,item in ipairs(list) do
            local k=item_key(item);
            if not seen[k] then seen[k]=true; ALL_UNIQUE[#ALL_UNIQUE+1]=item; end
        end
    end
    for _,list in ipairs({SEA_SCIENCE.obis,SEA_SCIENCE.gorgets}) do
        for _,rec in ipairs(list or {}) do
            local item={name=rec.name,kind='In the Name of Science'};
            local k=item_key(item);
            if not seen[k] then seen[k]=true; ALL_UNIQUE[#ALL_UNIQUE+1]=item; end
        end
    end
end

local ownership_cache={};
local OWNERSHIP_TTL=2;

local function char_cache_key(c)
    return tostring(HC.modules.core and HC.modules.core.character_name and HC.modules.core.character_name() or c);
end

local function invalidate_ownership_cache(c)
    ownership_cache[char_cache_key(c)]=nil;
end

local function ownership_snapshot(c,force)
    local s=ensure(c); local ck=char_cache_key(c); local now=os.time();
    local token=(HC.modules.skills and HC.modules.skills.collection_scan_token and HC.modules.skills.collection_scan_token()) or 'na';
    local cached=ownership_cache[ck];
    if not force and cached and cached.token==token and (now-tonumber(cached.at or 0))<OWNERSHIP_TTL then
        if HC.modules.profiler and HC.modules.profiler.cache then HC.modules.profiler.cache('seasky.ownership',true); end
        return cached;
    end
    if HC.modules.profiler and HC.modules.profiler.cache then HC.modules.profiler.cache('seasky.ownership',false); end
    if HC.modules.profiler and HC.modules.profiler.bump then HC.modules.profiler.bump('seasky.snapshot.rebuild'); end

    local available=(HC.modules.skills and HC.modules.skills.collection_scan_available and HC.modules.skills.collection_scan_available(false)==true) or false;
    token=(HC.modules.skills and HC.modules.skills.collection_scan_token and HC.modules.skills.collection_scan_token()) or token;
    local snap={at=now,token=token,available=available,rows={}}; local changed=false;
    for _,item in ipairs(ALL_UNIQUE) do
        local key=item_key(item); local loc,scan_ok,matched=nil,available,nil;
        if available then loc,scan_ok,matched=collection_location(item); end
        if scan_ok==true and loc and s.obtained[key]~=true then
            s.obtained[key]=true;
            s.meta[key]={at=now,source='Inventory / storage / wardrobe scan',location=loc,matched=matched};
            changed=true;
        end
        local owned=(loc~=nil) or s.obtained[key]==true;
        local status=loc or (s.obtained[key]==true and 'SAVED' or (scan_ok and 'MISSING' or 'CHECKING'));
        snap.rows[key]={owned=owned,status=status,matched=matched};
    end
    ownership_cache[ck]=snap;
    if changed and HC.modules.state then HC.modules.state.request_save(); end
    return snap;
end

local function owned_state(c,item,snap)
    snap=snap or ownership_snapshot(c,false);
    local row=snap.rows[item_key(item)] or {};
    return row.owned==true,row.status or 'CHECKING',row.matched;
end

local function row_owned_state(c,row,snap)
    local s=ensure(c); snap=snap or ownership_snapshot(c,false);
    local owned=false; local statuses={}; local matched=nil;
    for _,item in ipairs(row.items or {}) do
        local item_owned,status,item_matched=owned_state(c,item,snap);
        if item_owned then
            owned=true;
            local display_status=status;
            if status=='SAVED' then
                local meta=type(s.meta[item_key(item)])=='table' and s.meta[item_key(item)] or nil;
                local saved_loc=meta and tostring(meta.location or '') or '';
                if saved_loc~='' and saved_loc~='MANUAL' then display_status=saved_loc; end
            end
            if display_status and display_status~='MISSING' and display_status~='CHECKING' then
                local duplicate=false;
                for _,v in ipairs(statuses) do if v==display_status then duplicate=true; break; end end
                if not duplicate then statuses[#statuses+1]=display_status; end
            end
            matched=matched or item_matched;
        end
    end
    if s.obtained[row.key]==true then owned=true; end
    local status=nil;
    if #statuses>0 then status=table.concat(statuses,' + ');
    elseif s.obtained[row.key]==true then status='SAVED';
    else
        local checking=false;
        for _,item in ipairs(row.items or {}) do
            local _,item_status=owned_state(c,item,snap);
            if item_status=='CHECKING' then checking=true; break; end
        end
        status=checking and 'CHECKING' or 'MISSING';
    end
    return owned,status,matched;
end

local function count_sky_slots(c,snap)
    local n=0; snap=snap or ownership_snapshot(c,false);
    for _,row in ipairs(SKY_SLOTS) do
        if row_owned_state(c,row,snap) then n=n+1; end
    end
    return n,#SKY_SLOTS;
end

local function count_unique(c,items,snap)
    local n=0; snap=snap or ownership_snapshot(c,false);
    for _,item in ipairs(items) do
        local owned=owned_state(c,item,snap);
        if owned then n=n+1; end
    end
    return n,#items;
end

local function group_snapshot(c,section_id,group,snap)
    local is_sky=(section_id=='sky');
    local rows=display_rows(group.items or {},is_sky);
    local obtained=0;
    for _,row in ipairs(rows) do
        local owned=row_owned_state(c,row,snap);
        if owned then obtained=obtained+1; end
    end
    return rows,obtained,#rows;
end

local function draw_group_panel(c,section_id,group,snap,opts)
    local imgui=HC.imgui; local s=ensure(c); opts=type(opts)=='table' and opts or {};
    local rows=opts.rows; local obtained=opts.obtained; local total=opts.total;
    if type(rows)~='table' then rows,obtained,total=group_snapshot(c,section_id,group,snap); end
    obtained=tonumber(obtained) or 0; total=tonumber(total) or #rows;

    imgui.Text(tostring(group.name));
    imgui.SameLine();
    local boss_status=(total>0 and obtained>=total) and 'COMPLETE' or string.format('%d/%d',obtained,total);
    imgui.TextDisabled(string.format('| %s | %s',tostring(group.zone or '-'),boss_status));

    local shown={};
    for _,row in ipairs(rows) do
        local owned=row_owned_state(c,row,snap);
        if opts.missing_only~=true or not owned then shown[#shown+1]=row; end
    end
    if #shown==0 then
        if total>0 and obtained>=total then imgui.TextDisabled('All tracked gear obtained.');
        else imgui.TextDisabled('No gear matches the current filter.'); end
        return;
    end

    if imgui.BeginTable and imgui.TableSetupColumn and imgui.TableHeadersRow and imgui.TableNextRow and imgui.TableSetColumnIndex and imgui.EndTable
        and imgui.BeginTable('##seasky_table_'..section_id..'_'..group.id,3,HC.modules.uikit.table_flags()) then
        imgui.TableSetupColumn('Gear',0,0.55);
        imgui.TableSetupColumn('Location',0,0.27);
        imgui.TableSetupColumn('Owned',0,0.18);
        imgui.TableHeadersRow();
        for _,row in ipairs(shown) do
            local owned,status,matched=row_owned_state(c,row,snap); local key=row.key;
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);
            imgui.Text(tostring(row.name));
            if imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then
                local tip='Source: '..tostring(row.kind or '-');
                if #(row.items or {})>1 then tip=tip..'\nEither quality counts as this collection piece.'; end
                if matched and tostring(matched)~=tostring(row.name) then tip=tip..'\nDetected item: '..tostring(matched); end
                imgui.SetTooltip(tip);
            end

            imgui.TableSetColumnIndex(1);
            local location='-';
            if owned then
                if status=='SAVED' or status=='MANUAL' then
                    local meta=type(s.meta[key])=='table' and s.meta[key] or nil;
                    local saved_loc=meta and tostring(meta.location or '') or '';
                    if saved_loc~='' and saved_loc~='MANUAL' then location=saved_loc; else location='SAVED'; end
                elseif status and status~='MISSING' and status~='CHECKING' then location=tostring(status);
                else location='SAVED'; end
            elseif status=='CHECKING' then location='CHECKING'; end
            imgui.TextDisabled(location);

            imgui.TableSetColumnIndex(2);
            local v={owned==true};
            if imgui.Checkbox('##seasky_item_'..section_id..'_'..group.id..'_'..key,v) then
                if v[1] then
                    s.obtained[key]=true;
                    s.meta[key]={at=os.time(),source='Manual confirmation',location='MANUAL'};
                else
                    s.obtained[key]=nil; s.meta[key]=nil;
                    for _,item in ipairs(row.items or {}) do
                        local ik=item_key(item); s.obtained[ik]=nil; s.meta[ik]=nil;
                    end
                end
                invalidate_ownership_cache(c);
                if HC.modules.state then HC.modules.state.save(); end
            end
            imgui.SameLine();
            if owned then
                local short=(status and status~='SAVED' and status~='MANUAL' and status~='MISSING' and status~='CHECKING') and tostring(status) or 'Owned';
                imgui.TextDisabled(short);
            else
                imgui.TextDisabled(status=='CHECKING' and '...' or 'Missing');
            end
        end
        imgui.EndTable();
    else
        for _,row in ipairs(shown) do
            local owned,status=row_owned_state(c,row,snap);
            imgui.Text((owned and '[x] ' or '[ ] ')..tostring(row.name));
            if imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then imgui.SetTooltip('Source: '..tostring(row.kind or '-')); end
            imgui.SameLine(); imgui.TextDisabled(owned and 'Owned' or (status=='CHECKING' and 'Checking' or 'Missing'));
        end
    end
end

local function draw_section(c,id,title,groups,unique_items,snap,force_open)
    local imgui=HC.imgui;
    local have,total;
    if id=='sky' then have,total=count_sky_slots(c,snap); else have,total=count_unique(c,unique_items,snap); end
    local flags=rawget(_G,'ImGuiTreeNodeFlags_DefaultOpen') or 0;
    if force_open==true and imgui.SetNextItemOpen then pcall(imgui.SetNextItemOpen,true,rawget(_G,'ImGuiCond_Always') or 1); end
    if not imgui.CollapsingHeader(string.format('%s  |  %d/%d##seasky_section_%s',title,have,total,id),flags) then return; end

    local ui=section_ui(c,id);
    local missing={ui.missing_only==true};
    if imgui.Checkbox('Missing gear only##seasky_missing_'..id,missing) then
        ui.missing_only=missing[1]==true; if HC.modules.state then HC.modules.state.save(); end
    end
    imgui.SameLine();
    local hide={ui.hide_complete==true};
    if imgui.Checkbox('Hide completed bosses##seasky_hide_complete_'..id,hide) then
        ui.hide_complete=hide[1]==true; if HC.modules.state then HC.modules.state.save(); end
    end

    local visible={}; local complete_bosses=0;
    for _,group in ipairs(groups or {}) do
        local rows,obtained,gtotal=group_snapshot(c,id,group,snap);
        local complete=(gtotal>0 and obtained>=gtotal);
        if complete then complete_bosses=complete_bosses+1; end
        if not (ui.hide_complete==true and complete) then
            visible[#visible+1]={group=group,rows=rows,obtained=obtained,total=gtotal};
        end
    end
    imgui.TextDisabled(string.format('%d/%d bosses complete%s',complete_bosses,#(groups or {}),ui.missing_only and ' | showing missing gear only' or ''));

    if #visible==0 then
        imgui.TextDisabled('All bosses in this section are complete.');
        return;
    end

    local can_grid=(imgui.BeginTable and imgui.TableSetupColumn and imgui.TableNextRow and imgui.TableSetColumnIndex and imgui.EndTable);
    if can_grid and imgui.BeginTable('##seasky_group_grid_'..id,2,512) then
        imgui.TableSetupColumn('##seasky_group_left_'..id,0,0.5);
        imgui.TableSetupColumn('##seasky_group_right_'..id,0,0.5);
        for i,rec in ipairs(visible) do
            if (i%2)==1 then imgui.TableNextRow(); end
            imgui.TableSetColumnIndex((i-1)%2);
            draw_group_panel(c,id,rec.group,snap,{rows=rec.rows,obtained=rec.obtained,total=rec.total,missing_only=ui.missing_only});
        end
        imgui.EndTable();
    else
        for _,rec in ipairs(visible) do
            draw_group_panel(c,id,rec.group,snap,{rows=rec.rows,obtained=rec.obtained,total=rec.total,missing_only=ui.missing_only});
            imgui.Spacing();
        end
    end
end


local function science_item_state(c,rec,snap)
    local item={name=rec.name};
    local owned,status=owned_state(c,item,snap);
    return owned==true,tostring(status or 'CHECKING');
end

local function science_material_count(name)
    local own=HC.modules.ownership; if not own or not own.current then return nil,false; end
    local info=own.current(name,false); if not info.known then return nil,false; end
    return tonumber(info.count) or 0,true;
end

local SCIENCE_LOCATION_SHORT={
    ['INVENTORY']='Inv',['SAFE']='Safe',['STORAGE']='Storage',['TEMP']='Temp',['LOCKER']='Locker',
    ['SATCHEL']='Satchel',['SACK']='Sack',['CASE']='Case',
    ['WARDROBE 1']='Wd1',['WARDROBE 2']='Wd2',['WARDROBE 3']='Wd3',['WARDROBE 4']='Wd4',
    ['WARDROBE 5']='Wd5',['WARDROBE 6']='Wd6',['WARDROBE 7']='Wd7',['WARDROBE 8']='Wd8',
};

local function science_material_locations(name)
    local own=HC.modules.ownership; if not own or not own.current then return '',false; end
    local info=own.current(name,false); if not info.known then return '',false; end
    if not info.owned then return '',true; end
    local parts={};
    for _,row in ipairs(info.locations or {}) do
        local raw=tostring(row.location or '');
        local label=SCIENCE_LOCATION_SHORT[string.upper(raw)] or raw;
        parts[#parts+1]=string.format('%s(%d)',label,math.max(0,tonumber(row.count) or 0));
    end
    if #parts==0 and info.location and info.location~='—' then parts[1]=tostring(info.location); end
    if #parts==0 then return '',true; end
    return ' - '..table.concat(parts,', '),true;
end

local function science_material_compact(rec,final_owned)
    local parts={}; local enough=0; local total=0; local checking=false;
    for _,mat in ipairs(rec.materials or {}) do
        total=total+1;
        local need=math.max(1,tonumber(mat.qty) or 1);
        if final_owned then
            enough=enough+1;
            parts[#parts+1]=string.format('%s x%d used',tostring(mat.name),need);
        else
            local count,available=science_material_count(mat.name);
            if available~=true or count==nil then
                checking=true;
                parts[#parts+1]=string.format('%s ?/%d',tostring(mat.name),need);
            else
                count=math.max(0,tonumber(count) or 0);
                if count>=need then enough=enough+1; end
                parts[#parts+1]=string.format('%s %d/%d',tostring(mat.name),math.min(count,999),need);
            end
        end
    end
    return table.concat(parts,' | '),enough,total,checking;
end

local function science_list_progress(c,list,snap)
    local have=0;
    for _,rec in ipairs(list or {}) do
        local ok,owned=pcall(science_item_state,c,rec,snap);
        if ok and owned==true then have=have+1; end
    end
    return have,#(list or {});
end

local function science_material_lines(rec,final_owned)
    local lines={}; local enough=0; local total=0; local checking=false;
    for _,mat in ipairs(rec.materials or {}) do
        total=total+1;
        local need=math.max(1,tonumber(mat.qty) or 1);
        if final_owned then
            enough=enough+1;
            lines[#lines+1]={
                text=string.format('%s - used x%d',tostring(mat.name),need),
                complete=true,
            };
        else
            local count,available=science_material_count(mat.name);
            if available~=true or count==nil then
                checking=true;
                lines[#lines+1]={
                    text=string.format('%s - ?/%d',tostring(mat.name),need),
                    complete=false,
                };
            else
                count=math.max(0,tonumber(count) or 0);
                local met=(count>=need);
                if met then enough=enough+1; end
                local location_text='';
                if count>0 then
                    local ok_loc,loc=pcall(science_material_locations,mat.name);
                    if ok_loc and type(loc)=='string' then location_text=loc; end
                end
                lines[#lines+1]={
                    text=string.format('%s - %d/%d%s',tostring(mat.name),math.min(count,999),need,location_text),
                    complete=met,
                };
            end
        end
    end
    return lines,enough,total,checking;
end

local function science_entry_view(c,rec,snap)
    local ok_state,owned,status=pcall(science_item_state,c,rec,snap);
    if not ok_state then owned=false; status='CHECKING'; end
    local ok_mat,lines,enough,mat_total,checking=pcall(science_material_lines,rec,owned==true);
    if not ok_mat then lines={'Material scan unavailable'}; enough=0; mat_total=#(rec.materials or {}); checking=true; end
    local ready=(not owned and not checking and mat_total>0 and enough>=mat_total);
    local state='MISSING';
    if owned then state='OWNED';
    elseif status=='CHECKING' or checking then state='CHECKING';
    elseif ready then state='READY';
    else state=string.format('%d/%d mats',enough,mat_total); end
    return owned,tostring(rec.name)..' - '..state,lines;
end

local function science_set_manual(c,rec,value,snap)
    -- Keep the manual mutation itself free of fallible helper work. The earlier
    -- implementation performed cache-key/save calls inline with the click, so
    -- an unexpected helper failure could abort the callback before the checkbox
    -- visibly latched. Persist the authoritative state first, then refresh/save
    -- defensively.
    if type(rec)~='table' or not rec.name then return false; end
    local s=ensure(c);
    local key=normalize(rec.name);
    if value==true then
        s.obtained[key]=true;
        s.meta[key]={at=os.time(),source='Manual confirmation',location='MANUAL'};
    else
        s.obtained[key]=nil;
        s.meta[key]=nil;
    end

    -- Update the already-built snapshot too so the current frame reflects the
    -- click immediately instead of waiting for a full ownership rescan.
    if type(snap)=='table' and type(snap.rows)=='table' then
        snap.rows[key]={
            owned=(value==true),
            status=(value==true) and 'MANUAL' or 'MISSING',
            matched=nil,
        };
    end

    pcall(invalidate_ownership_cache,c);
    if HC.modules.state then
        if type(HC.modules.state.request_save)=='function' then
            pcall(HC.modules.state.request_save);
        elseif type(HC.modules.state.save)=='function' then
            pcall(HC.modules.state.save);
        end
    end
    return true;
end

local function fixed_cell(text,width)
    text=tostring(text or ''); width=math.max(8,tonumber(width) or 42);
    if #text>width then text=text:sub(1,width-3)..'...'; end
    return text..string.rep(' ',math.max(0,width-#text));
end

local function draw_science_pair(c,index,left_rec,right_rec,snap)
    local imgui=HC.imgui;
    local lok,lowned,lheader,lmats=pcall(science_entry_view,c,left_rec,snap);
    if not lok then
        lowned=false;
        lheader=tostring(left_rec and left_rec.name or 'Obi')..' - CHECKING';
        lmats={{text='Material display unavailable',complete=false}};
    end
    local rok=false; local rowned=false; local rheader=''; local rmats={};
    if right_rec then
        rok,rowned,rheader,rmats=pcall(science_entry_view,c,right_rec,snap);
        if not rok then
            rowned=false;
            rheader=tostring(right_rec.name or 'Gorget')..' - CHECKING';
            rmats={{text='Material display unavailable',complete=false}};
        end
    end

    -- Keep this section table-free for HorizonXI compatibility. Each Obi/Gorget
    -- pair is rendered inside a shallow bordered child so the pairs read as
    -- distinct collection cards without opening another table/column stack.
    local child_open=false;
    local child_colors=0;
    local max_mats=math.max(type(lmats)=='table' and #lmats or 0,type(rmats)=='table' and #rmats or 0);
    if imgui.BeginChild and imgui.EndChild then
        local bg=rawget(_G,'ImGuiCol_ChildBg');
        if type(bg)=='number' and imgui.PushStyleColor then
            local shade=(index%2)==0 and {0.075,0.085,0.10,0.84} or {0.045,0.050,0.060,0.82};
            if pcall(imgui.PushStyleColor,bg,shade) then child_colors=child_colors+1; end
        end
        local height=42+(math.max(1,max_mats)*18);
        local border_flags=rawget(_G,'ImGuiChildFlags_Borders') or 1;
        local ok=pcall(function()
            imgui.BeginChild('##science_pair_'..tostring(index),{0,height},border_flags,0);
        end);
        child_open=ok;
    end

    local lv={lowned==true};
    if imgui.Checkbox('##science_obi_'..tostring(index),lv) then pcall(science_set_manual,c,left_rec,lv[1],snap); end
    imgui.SameLine();
    imgui.Text(fixed_cell(lheader,43));
    imgui.SameLine();
    imgui.TextDisabled('|');
    if right_rec then
        imgui.SameLine();
        local rv={rowned==true};
        if imgui.Checkbox('##science_gorget_'..tostring(index),rv) then pcall(science_set_manual,c,right_rec,rv[1],snap); end
        imgui.SameLine();
        imgui.Text(tostring(rheader));
    end
    imgui.Separator();

    local n=max_mats;
    for i=1,n do
        local lrow=(type(lmats)=='table' and lmats[i]) or nil;
        local rrow=(type(rmats)=='table' and rmats[i]) or nil;
        local ltext=(type(lrow)=='table' and lrow.text) or tostring(lrow or '');
        local rtext=(type(rrow)=='table' and rrow.text) or tostring(rrow or '');
        if type(lrow)=='table' and lrow.complete==true then
            imgui.Text('   '..fixed_cell(ltext,47));
        else
            imgui.TextDisabled('   '..fixed_cell(ltext,47));
        end
        imgui.SameLine();
        imgui.TextDisabled('|');
        if rrow then
            imgui.SameLine();
            if type(rrow)=='table' and rrow.complete==true then
                imgui.Text(rtext);
            else
                imgui.TextDisabled(rtext);
            end
        end
    end

    if child_open and imgui.EndChild then pcall(imgui.EndChild); end
    if child_colors>0 and imgui.PopStyleColor then pcall(imgui.PopStyleColor,child_colors); end
    imgui.Spacing();
end

local function draw_science_section(c,snap,force_open)
    local imgui=HC.imgui;
    local obi_have,obi_total=science_list_progress(c,SEA_SCIENCE.obis,snap);
    local gorget_have,gorget_total=science_list_progress(c,SEA_SCIENCE.gorgets,snap);
    local have=obi_have+gorget_have; local total=obi_total+gorget_total;
    if force_open==true then science_section_open=true; end
    if imgui.SetNextItemOpen then
        pcall(imgui.SetNextItemOpen,science_section_open==true,rawget(_G,'ImGuiCond_Always') or 1);
    end
    local ok,open=pcall(imgui.CollapsingHeader,string.format('Elemental Obis / Gorgets  |  %d/%d##seasky_science_section',have,total),0);
    if not ok then return; end
    science_section_open=(open==true);
    if not science_section_open then return; end
    imgui.TextDisabled('In the Name of Science - live material counts and container locations from inventory, storage, and wardrobes.');
    imgui.Text('Obis'); imgui.SameLine(); imgui.TextDisabled(fixed_cell('',38)); imgui.SameLine(); imgui.Text('Gorgets');
    imgui.Separator();

    local max_rows=math.max(#SEA_SCIENCE.obis,#SEA_SCIENCE.gorgets);
    for i=1,max_rows do
        local left_rec=SEA_SCIENCE.obis[i]; local right_rec=SEA_SCIENCE.gorgets[i];
        if left_rec then
            local ok=pcall(draw_science_pair,c,i,left_rec,right_rec,snap);
            if not ok then
                imgui.TextDisabled(tostring(left_rec.name or 'Obi')..' / '..tostring(right_rec and right_rec.name or 'Gorget')..' - display unavailable');
            end
        end
    end
end

function M.draw(c)
    if not HC.imgui then return; end
    local imgui=HC.imgui; ensure(c);
    local snap=ownership_snapshot(c,false);
    local sky_have,sky_total=count_sky_slots(c,snap);
    local sea_have,sea_total=count_unique(c,SEA_UNIQUE,snap);
    imgui.Text('Sea / Sky Collection');
    imgui.TextDisabled(string.format('Obtained: Sky Gods %d/%d  |  Sea Bosses %d/%d',sky_have,sky_total,sea_have,sea_total));
    imgui.TextDisabled('Auto-scan checks inventory, storage, and wardrobes. Manual checks save per character.');
    imgui.Separator();
    local navigation_focus=(HC.modules.ui and HC.modules.ui.consume_focus) and HC.modules.ui.consume_focus('seasky') or nil;
    local focus_section=type(navigation_focus)=='table' and string.lower(tostring(navigation_focus.section or '')) or '';
    draw_section(c,'sky','Sky Gods',SKY,SKY_UNIQUE,snap,focus_section:find('sky',1,true)~=nil);
    imgui.Spacing();
    draw_section(c,'sea','Sea Bosses',SEA,SEA_UNIQUE,snap,focus_section:find('sea',1,true)~=nil);
    imgui.Spacing();
    draw_science_section(c,snap,focus_section:find('obi',1,true)~=nil or focus_section:find('gorget',1,true)~=nil or focus_section:find('science',1,true)~=nil);
end


function M.catalog_entries(c)
    c=type(c)=='table' and c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    local snap=ownership_snapshot(c,false);
    local out={};
    local function append(section,groups)
        local is_sky=(section=='Sky');
        for _,group in ipairs(groups or {}) do
            for _,row in ipairs(display_rows(group.items or {},is_sky)) do
                local owned,status=row_owned_state(c,row,snap);
                out[#out+1]={
                    section=section,
                    boss=tostring(group.name or ''),
                    zone=tostring(group.zone or ''),
                    name=tostring(row.name or ''),
                    source=tostring(row.kind or ''),
                    owned=owned==true,
                    location=tostring(status or ''),
                };
            end
        end
    end
    append('Sky',SKY); append('Sea',SEA);
    for _,pair in ipairs({{'Sea - Obis',SEA_SCIENCE.obis},{'Sea - Gorgets',SEA_SCIENCE.gorgets}}) do
        for _,rec in ipairs(pair[2] or {}) do
            local owned,status=science_item_state(c,rec,snap);
            local req={};
            for _,mat in ipairs(rec.materials or {}) do req[#req+1]=tostring(mat.name)..' x'..tostring(mat.qty or 1); end
            out[#out+1]={
                section=pair[1], boss='In the Name of Science', zone='Tavnazian Safehold',
                name=tostring(rec.name), source=table.concat(req,', '), owned=owned==true, location=tostring(status or ''),
            };
        end
    end
    return out;
end

function M.progress(c)
    ensure(c); local snap=ownership_snapshot(c,false);
    local sh,st=count_sky_slots(c,snap); local eh,et=count_unique(c,SEA_UNIQUE,snap);
    return {sky_done=sh,sky_total=st,sea_done=eh,sea_total=et};
end

function M.zone_rows(c,zone_name)
    c=c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    local wanted=string.lower(tostring(zone_name or ''));
    if wanted=='' or wanted=='unknown' then return {}; end
    local snap=ownership_snapshot(c,false);
    local out={};
    for _,section in ipairs({{id='sky',groups=SKY},{id='sea',groups=SEA}}) do
        for _,group in ipairs(section.groups or {}) do
            if string.lower(tostring(group.zone or ''))==wanted then
                local _,have,total=group_snapshot(c,section.id,group,snap);
                out[#out+1]={
                    kind='Sea / Sky',
                    section=section.id,
                    name=tostring(group.name),
                    zone=tostring(group.zone or ''),
                    status=string.format('%d/%d gear obtained',have,total),
                    obtained=have,
                    total=total,
                };
            end
        end
    end
    return out;
end

function M.init(ctx)
    HC=ctx;
end

return M;
