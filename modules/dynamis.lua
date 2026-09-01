local M = {};
local HC;

local SLOT_NAMES={'Head','Body','Hands','Legs','Feet'};
local ZONE_ORDER={
    'San d\'Oria','Bastok','Windurst','Jeuno','Beaucedine','Xarcabard',
    'Valkurm','Buburimu','Qufim','Tavnazia',
};
local ZONE_GROUP={
    ['San d\'Oria']='Original Dynamis',['Bastok']='Original Dynamis',['Windurst']='Original Dynamis',['Jeuno']='Original Dynamis',
    ['Beaucedine']='Original Dynamis',['Xarcabard']='Original Dynamis',
    ['Valkurm']='Dreamworld Dynamis',['Buburimu']='Dreamworld Dynamis',['Qufim']='Dreamworld Dynamis',['Tavnazia']='Dreamworld Dynamis',
};

-- Clear rewards are permanent key items awarded by the zone boss.
local CLEAR_KI={
    ['San d\'Oria']='Hydra Corps Command Scepter',
    ['Bastok']='Hydra Corps Eyeglass',
    ['Windurst']='Hydra Corps Lantern',
    ['Jeuno']='Hydra Corps Tactical Map',
    ['Beaucedine']='Hydra Corps Insignia',
    ['Xarcabard']='Hydra Corps Battle Standard',
    ['Valkurm']='Dynamis - Valkurm Sliver',
    ['Buburimu']='Dynamis - Buburimu Sliver',
    ['Qufim']='Dynamis - Qufim Sliver',
    ['Tavnazia']='Dynamis - Tavnazia Sliver',
};

-- NQ Relic Armor drop areas for the 18 jobs currently tracked by HorizonCheck.
-- Each slot contains the original Dynamis area and its Dreamworld alternate.
local NQ_ZONES={
    WAR={{'Windurst','Qufim'},{'Xarcabard','Tavnazia'},{'Jeuno','Buburimu'},{'Beaucedine','Tavnazia'},{'San d\'Oria','Valkurm'}},
    MNK={{'Xarcabard','Tavnazia'},{'Beaucedine','Tavnazia'},{'Jeuno','Qufim'},{'San d\'Oria','Buburimu'},{'Bastok','Valkurm'}},
    WHM={{'San d\'Oria','Buburimu'},{'Beaucedine','Tavnazia'},{'Xarcabard','Tavnazia'},{'Jeuno','Qufim'},{'Windurst','Valkurm'}},
    BLM={{'Xarcabard','Tavnazia'},{'Beaucedine','Tavnazia'},{'Windurst','Buburimu'},{'Bastok','Qufim'},{'Jeuno','Valkurm'}},
    RDM={{'Xarcabard','Tavnazia'},{'Beaucedine','Tavnazia'},{'Bastok','Buburimu'},{'Jeuno','Qufim'},{'San d\'Oria','Valkurm'}},
    THF={{'Windurst','Valkurm'},{'Bastok','Buburimu'},{'Xarcabard','Tavnazia'},{'Beaucedine','Tavnazia'},{'Jeuno','Qufim'}},
    PLD={{'Bastok','Qufim'},{'Xarcabard','Tavnazia'},{'San d\'Oria','Buburimu'},{'Beaucedine','Tavnazia'},{'Windurst','Valkurm'}},
    DRK={{'Xarcabard','Tavnazia'},{'Beaucedine','Tavnazia'},{'Windurst','Buburimu'},{'Jeuno','Qufim'},{'Bastok','Valkurm'}},
    BST={{'Windurst','Valkurm'},{'Bastok','Buburimu'},{'Xarcabard','Tavnazia'},{'San d\'Oria','Qufim'},{'Beaucedine','Tavnazia'}},
    BRD={{'San d\'Oria','Buburimu'},{'Beaucedine','Tavnazia'},{'Bastok','Qufim'},{'Xarcabard','Tavnazia'},{'Jeuno','Valkurm'}},
    RNG={{'Jeuno','Qufim'},{'Xarcabard','Tavnazia'},{'Windurst','Valkurm'},{'San d\'Oria','Buburimu'},{'Beaucedine','Tavnazia'}},
    SAM={{'Xarcabard','Tavnazia'},{'Beaucedine','Tavnazia'},{'Bastok','Qufim'},{'Windurst','Buburimu'},{'Jeuno','Valkurm'}},
    NIN={{'Windurst','Qufim'},{'Beaucedine','Tavnazia'},{'Xarcabard','Tavnazia'},{'San d\'Oria','Valkurm'},{'Jeuno','Buburimu'}},
    DRG={{'Xarcabard','Tavnazia'},{'Beaucedine','Tavnazia'},{'Jeuno','Qufim'},{'Bastok','Valkurm'},{'San d\'Oria','Buburimu'}},
    SMN={{'Xarcabard','Tavnazia'},{'Beaucedine','Tavnazia'},{'Bastok','Buburimu'},{'Windurst','Valkurm'},{'San d\'Oria','Qufim'}},
    BLU={{'Xarcabard','Tavnazia'},{'Beaucedine','Tavnazia'},{'San d\'Oria','Qufim'},{'Bastok','Buburimu'},{'Windurst','Valkurm'}},
    COR={{'Xarcabard','Tavnazia'},{'Beaucedine','Tavnazia'},{'Jeuno','Buburimu'},{'San d\'Oria','Valkurm'},{'Bastok','Qufim'}},
    PUP={{'Xarcabard','Tavnazia'},{'Beaucedine','Tavnazia'},{'Windurst','Qufim'},{'Jeuno','Valkurm'},{'San d\'Oria','Buburimu'}},
};

local ACCESSORY_ZONES={
    WAR={'Valkurm','Buburimu'}, MNK={'Qufim','Buburimu'}, WHM={'Valkurm','Qufim'}, BLM={'Valkurm','Buburimu'},
    RDM={'Buburimu','Qufim'}, THF={'Valkurm','Qufim'}, PLD={'Valkurm','Buburimu'}, DRK={'Qufim','Buburimu'},
    BST={'Valkurm','Qufim'}, BRD={'Valkurm','Buburimu'}, RNG={'Buburimu','Qufim'}, SAM={'Valkurm','Qufim'},
    NIN={'Valkurm','Buburimu'}, DRG={'Buburimu','Qufim'}, SMN={'Valkurm','Qufim'}, BLU={'Buburimu','Valkurm'},
    COR={'Qufim'}, PUP={'Buburimu','Qufim'},
};

local MINUS1_ZONE_BY_SLOT={
    [1]='Valkurm',   -- head
    [2]='Tavnazia',  -- body
    [3]='Buburimu',  -- hands
    [4]='Tavnazia',  -- legs
    [5]='Qufim',     -- feet
};

local clear_cache={at=0,rows={}};

local function contains(t,v)
    for _,x in ipairs(t or {}) do if x==v then return true; end end
    return false;
end

local function clear_status(zone,force,c)
    local now=os.time();
    if not force and clear_cache.at and (now-clear_cache.at)<5 and clear_cache.rows[zone] then return clear_cache.rows[zone]; end
    local ki=CLEAR_KI[zone];
    local owned,err,id,source=nil,'key-item module unavailable',nil,'unavailable';
    local ur=HC.modules.unlocks;
    if ur and ur.owned_name then
        local ok,a,r=pcall(ur.owned_name,ki,c);
        if ok and r then owned=a; err=r.error; id=r.id; source='unlock registry | '..tostring(r.source or ''); end
    end
    if owned==nil then
        local km=HC.modules.keyitems;
        if km then
            local known_id=km.known_id and km.known_id(ki) or nil;
            if known_id and km.ownership_id then
                local ok,a,b,cid,d=pcall(km.ownership_id,known_id,ki);
                if ok then owned,err,id,source=a,b,cid,d; else err=tostring(a); end
            elseif km.ownership_name then
                local ok,a,b,cid,d=pcall(km.ownership_name,ki);
                if ok then owned,err,id,source=a,b,cid,d; else err=tostring(a); end
            end
        end
    end
    local row={zone=zone,key_item=ki,owned=owned,error=err,id=id,source=source};
    clear_cache.rows[zone]=row; clear_cache.at=now;
    return row;
end

local function ensure_seen(c)
    c.dynamis_relic_seen=type(c.dynamis_relic_seen)=='table' and c.dynamis_relic_seen or {};
    return c.dynamis_relic_seen;
end

local function seen_key(kind,job,slot,name)
    return table.concat({tostring(kind or ''),tostring(job or ''),tostring(slot or ''),tostring(name or '')},'|');
end

local function remember_seen(c,kind,job,slot,name,location)
    if not location then return false; end
    local seen=ensure_seen(c); local key=seen_key(kind,job,slot,name);
    if seen[key] then return false; end
    seen[key]={at=os.time(),name=name,job=job,slot=slot,kind=kind,source=location};
    return true;
end

local function historical_location(c,kind,job,slot,name)
    local seen=ensure_seen(c); local rec=seen[seen_key(kind,job,slot,name)];
    if rec then return 'OBTAINED BEFORE'; end
    return nil;
end

local function build_zone_drops(c,force)
    local snap=nil;
    if HC.modules.skills and HC.modules.skills.relic_snapshot then
        local ok,res=pcall(HC.modules.skills.relic_snapshot,force==true);
        if ok then snap=res; end
    end
    local zones={}; for _,z in ipairs(ZONE_ORDER) do zones[z]={nq={},accessory={},minus1={}}; end
    local changed=false;
    local jobs=snap and snap.jobs or {};
    for job,jrow in pairs(jobs or {}) do
        local map=NQ_ZONES[job];
        if map then
            for slot=1,5 do
                local piece=jrow.armor and jrow.armor[slot] or nil;
                if piece then
                    local loc=piece.location or historical_location(c,'nq',job,slot,piece.name);
                    if piece.location and remember_seen(c,'nq',job,slot,piece.name,piece.location) then changed=true; end
                    for _,zone in ipairs(map[slot] or {}) do
                        zones[zone].nq[#zones[zone].nq+1]={job=job,slot=SLOT_NAMES[slot],name=piece.name,location=loc,item_id=piece.item_id};
                    end
                end
                local damaged=jrow.minus1 and jrow.minus1[slot] or nil;
                if damaged then
                    local loc=damaged.location or historical_location(c,'minus1',job,slot,damaged.name);
                    if damaged.location and remember_seen(c,'minus1',job,slot,damaged.name,damaged.location) then changed=true; end
                    local zone=MINUS1_ZONE_BY_SLOT[slot];
                    if zone then zones[zone].minus1[#zones[zone].minus1+1]={job=job,slot=SLOT_NAMES[slot],name=damaged.name,location=loc,item_id=damaged.item_id}; end
                end
            end
        end
        local acc=jrow.accessory;
        if acc and ACCESSORY_ZONES[job] then
            local loc=acc.location or historical_location(c,'accessory',job,'Accessory',acc.name);
            if acc.location and remember_seen(c,'accessory',job,'Accessory',acc.name,acc.location) then changed=true; end
            for _,zone in ipairs(ACCESSORY_ZONES[job]) do
                zones[zone].accessory[#zones[zone].accessory+1]={job=job,slot='Accessory',name=acc.name,location=loc,item_id=acc.item_id};
            end
        end
    end
    if changed and HC.modules.state and HC.modules.state.request_save then
        HC.modules.state.request_save(1);
    elseif changed and HC.modules.state and HC.modules.state.save then
        HC.modules.state.save();
    end
    return zones,snap;
end

local function row_sort(a,b)
    if tostring(a.job)~=tostring(b.job) then return tostring(a.job)<tostring(b.job); end
    return tostring(a.slot)<tostring(b.slot);
end

local function count_rows(section)
    local have,total=0,0;
    for _,kind in ipairs({'nq','accessory','minus1'}) do
        for _,r in ipairs(section[kind] or {}) do total=total+1; if r.location then have=have+1; end end
    end
    return have,total;
end

local function draw_drop_group(imgui,label,rows,missing_only)
    if not rows or #rows==0 then return; end
    table.sort(rows,row_sort);
    local have=0; for _,r in ipairs(rows) do if r.location then have=have+1; end end
    imgui.Text(string.format('%s  %d/%d obtained',label,have,#rows));
    for _,r in ipairs(rows) do
        if not missing_only or not r.location then
            local line=string.format('  %-3s  %-9s  %s',tostring(r.job),tostring(r.slot),tostring(r.name));
            if r.location then imgui.Text(line..'  ['..tostring(r.location)..']'); else imgui.TextDisabled(line..'  [MISSING]'); end
        end
    end
end

function M.draw(c)
    local imgui=HC.imgui; if not imgui then return; end
    c.settings=type(c.settings)=='table' and c.settings or {};

    if HC.modules.uikit then HC.modules.uikit.section_header('Dynamis Clears / Relic Drops'); else imgui.Text('Dynamis Clears / Relic Drops'); end
    if imgui.IsItemHovered and imgui.SetTooltip and imgui.IsItemHovered() then
        imgui.SetTooltip('Clear status uses the permanent boss-reward key item.\nRelic status scans inventory, storage, wardrobes, and supported Porter slips.\nBase Relic +1 counts as historical proof of the corresponding NQ and -1 pieces.');
    end

    local force=false;
    local missing={c.settings.dynamis_missing_only==true};
    if imgui.Checkbox('Missing Only##dyna_missing',missing) then c.settings.dynamis_missing_only=missing[1]; HC.modules.state.save(); end

    local zones,snap=build_zone_drops(c,force);
    local clears=0; local known=0;
    for _,z in ipairs(ZONE_ORDER) do local cs=clear_status(z,force,c); if cs.owned~=nil then known=known+1; end; if cs.owned==true then clears=clears+1; end end
    imgui.Text(string.format('Clears: %d/10%s',clears,known<10 and string.format('  (%d still checking)',10-known) or ''));
    if not (snap and snap.available) then imgui.TextDisabled('Inventory/Porter scan is not currently available from Ashita.'); end
    imgui.Separator();

    local current_group=nil;
    for _,zone in ipairs(ZONE_ORDER) do
        local group=ZONE_GROUP[zone];
        if group~=current_group then
            if current_group~=nil then imgui.Spacing(); end
            if HC.modules.uikit then HC.modules.uikit.section_header(group); else imgui.Text(group); imgui.Separator(); end; current_group=group;
        end
        local cs=clear_status(zone,false,c); local have,total=count_rows(zones[zone]);
        local clear_label=cs.owned==true and 'CLEAR' or (cs.owned==false and 'NO CLEAR' or 'CLEAR ?');
        local header=string.format('Dynamis - %s  [%s]  Relic %d/%d##dyna_zone_%s',zone,clear_label,have,total,zone:gsub('[^%w]','_'));
        if imgui.CollapsingHeader(header,0) then
            if cs.owned==true then
                imgui.Text('Clear: CONFIRMED - '..tostring(cs.key_item));
            elseif cs.owned==false then
                imgui.TextDisabled('Clear: NOT CONFIRMED - missing '..tostring(cs.key_item));
            else
                imgui.TextDisabled('Clear: CHECKING - '..tostring(cs.key_item)..(cs.error and (' ('..tostring(cs.error)..')') or ''));
            end
            imgui.Separator();
            draw_drop_group(imgui,'Relic Armor',zones[zone].nq,c.settings.dynamis_missing_only==true);
            if #zones[zone].accessory>0 then imgui.Separator(); draw_drop_group(imgui,'Relic Accessories',zones[zone].accessory,c.settings.dynamis_missing_only==true); end
            if #zones[zone].minus1>0 then imgui.Separator(); draw_drop_group(imgui,'Relic Armor -1',zones[zone].minus1,c.settings.dynamis_missing_only==true); end
        end
    end
end

function M.init(ctx) HC=ctx; end
return M;
