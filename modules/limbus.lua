local M={};
local HC;
local cache={at=0,snapshot=nil};
local currency_request_at=0;

local JOBS={'WAR','MNK','WHM','BLM','RDM','THF','PLD','DRK','BST','BRD','RNG','SAM','NIN','DRG','SMN','BLU','COR','PUP'};

local APOLLYON_MATS={
    WAR='Argyro Rivet', MNK='Ancient Brass', WHM='Benedict Yarn', BLM='Diabolic Yarn',
    RDM='Cardinal Cloth', THF='Light Filament', PLD='White Rivet', DRK='Black Rivet',
    BST='Fetid Lanolin', BRD='Brown Doeskin', RNG='Charcoal Cotton', SAM='Kurogane',
    NIN='Ebony Lacquer', DRG='Blue Rivet', SMN='Astral Leather', BLU='Flameshun Cloth',
    COR='Canvas Toile', PUP='Corduroy Cloth',
};

local TEMENOS_MATS={
    WAR='Ecarlate Cloth', MNK='Ut. Gold Thread', WHM='Benedict Silk', BLM='Diabolic Silk',
    RDM='Ruby Silk Thread', THF='Supple Skin', PLD='Snowy Cermet', DRK='Dark Orichalcum',
    BST='Smalt Leather', BRD='Coiled Yarn', RNG='Chameleon Yarn', SAM='Scarlet Odoshi',
    NIN='Plaited Cord', DRG='Cbl. Myth. Sheet', SMN='Glittering Yarn', BLU='Luminian Thread',
    COR='Silkworm Thread', PUP='Pantin Wire',
};

local APOLLYON={
    {id='nw', name='NW Apollyon', card='Red Card', chips={}, reward='Magenta Chip', time='30-90m', coins='45-55', af='All 18 jobs', slug='NW_Apollyon'},
    {id='sw', name='SW Apollyon', card='Red Card', chips={}, reward='Charcoal Chip', time='30-60m', coins='~40', af='All 18 jobs', slug='SW_Apollyon'},
    {id='ne', name='NE Apollyon', card='Black Card', chips={}, reward='Smoky Chip', time='30-90m', coins='~60', af='All 18 jobs', slug='NE_Apollyon'},
    {id='se', name='SE Apollyon', card='Black Card', chips={}, reward='Smalt Chip', time='30-60m', coins='~45', af='All 18 jobs', slug='SE_Apollyon'},
    {id='omega', name='Central Apollyon (Omega)', card={'Red Card','Black Card'}, chips={'Magenta Chip','Charcoal Chip','Smoky Chip','Smalt Chip'}, reward='Homam armor', time='30m', coins='Boss', af='Omega parts -> Homam', slug='Central_Apollyon'},
    {id='cs', name='CS Apollyon', card={'Red Card','Black Card'}, chips={'Metal Chip'}, reward='Ancient Beastcoins', time='20-30m', coins='Coin farm', af='No AF+1 focus', slug='CS_Apollyon'},
};

local TEMENOS={
    {id='west', name='Temenos - Western Tower', card='White Card', chips={}, reward='Emerald Chip', time='30-120m', coins='Coins + AF', af='All 18 jobs', slug='Temenos_-_Western_Tower'},
    {id='north', name='Temenos - Northern Tower', card='White Card', chips={}, reward='Ivory Chip', time='30-120m', coins='Coins + AF', af='All 18 jobs', slug='Temenos_-_Northern_Tower'},
    {id='east', name='Temenos - Eastern Tower', card='White Card', chips={}, reward='Scarlet Chip', time='30-120m', coins='Coins + AF', af='All 18 jobs', slug='Temenos_-_Eastern_Tower'},
    {id='c1', name='Central Temenos - 1st Floor', card='White Card', chips={'Emerald Chip'}, reward='Orchid Chip', time='45m', coins='6 +', af='WHM RNG BLM WAR SMN PUP RDM BST PLD THF', slug='Central_Temenos_-_1st_Floor'},
    {id='c2', name='Central Temenos - 2nd Floor', card='White Card', chips={'Scarlet Chip'}, reward='Cerulean Chip', time='45m', coins='~40', af='DRK BLM RNG PLD BST PUP', slug='Central_Temenos_-_2nd_Floor'},
    {id='c3', name='Central Temenos - 3rd Floor', card='White Card', chips={'Ivory Chip'}, reward='Silver Chip', time='45m', coins='~50', af='WHM THF NIN MNK DRG WAR COR', slug='Central_Temenos_-_3rd_Floor'},
    {id='ultima', name='Central Temenos - 4th Floor (Ultima)', card='White Card', chips={'Orchid Chip','Cerulean Chip','Silver Chip'}, reward='Nashira armor', time='60m', coins='Boss', af='Ultima parts -> Nashira', slug='Central_Temenos_-_4th_Floor'},
    {id='b1', name='Central Temenos - Basement 1', card='White Card', chips={'Metal Chip'}, reward='Ancient Beastcoins', time='15-35m', coins='Coin farm', af='No AF+1 focus', slug='Central_Temenos_-_Basement_1'},
};

local BOSS_GEAR={
    {set='Homam',part="Omega's Eye",item='Homam Zucchetto'},
    {set='Homam',part="Omega's Heart",item='Homam Corazza'},
    {set='Homam',part="Omega's Foreleg",item='Homam Manopolas'},
    {set='Homam',part="Omega's Hind Leg",item='Homam Cosciales'},
    {set='Homam',part="Omega's Tail",item='Homam Gambieras'},
    {set='Nashira',part="Ultima's Cerebrum",item='Nashira Turban'},
    {set='Nashira',part="Ultima's Heart",item='Nashira Manteel'},
    {set='Nashira',part="Ultima's Claw",item='Nashira Gages'},
    {set='Nashira',part="Ultima's Leg",item='Nashira Seraweels'},
    {set='Nashira',part="Ultima's Tail",item='Nashira Crackows'},
};

local LOC_SHORT={
    ['INVENTORY']='Inv',['SAFE']='Safe',['STORAGE']='Storage',['TEMP']='Temp',['LOCKER']='Locker',
    ['SATCHEL']='Satchel',['SACK']='Sack',['CASE']='Case',
    ['WARDROBE 1']='Wardrobe 1',['WARDROBE 2']='Wardrobe 2',['WARDROBE 3']='Wardrobe 3',['WARDROBE 4']='Wardrobe 4',
    ['WARDROBE 5']='Wardrobe 5',['WARDROBE 6']='Wardrobe 6',['WARDROBE 7']='Wardrobe 7',['WARDROBE 8']='Wardrobe 8',
};

local function u16le(raw,offset)
    if type(raw)~='string' then return nil; end
    offset=tonumber(offset) or 0;
    if #raw < offset+2 then return nil; end
    local b1,b2=raw:byte(offset+1,offset+2);
    if not b2 then return nil; end
    return b1 + b2*256;
end

local function ensure_currency(c)
    c.limbus_currency=type(c.limbus_currency)=='table' and c.limbus_currency or {};
    c.limbus_currency.ancient_beastcoins=tonumber(c.limbus_currency.ancient_beastcoins);
    c.limbus_currency.last_verified_at=tonumber(c.limbus_currency.last_verified_at);
    return c.limbus_currency;
end

local function on_currency_packet(e)
    if e==nil or e.injected or tonumber(e.id)~=0x113 then return; end
    local raw=e.data or e.data_raw;
    if type(raw)~='string' or #raw<0x1C then raw=e.data_raw or e.data; end
    if type(raw)~='string' or #raw<0x1C then return; end
    local n=u16le(raw,0x1A);
    if n==nil then return; end
    local c=HC.modules.state.get_char();
    local cur=ensure_currency(c);
    local old=cur.ancient_beastcoins;
    cur.ancient_beastcoins=math.max(0,math.floor(n));
    cur.last_verified_at=os.time();
    cur.last_source='Currency menu';
    cache={at=0,snapshot=nil};
    if old~=cur.ancient_beastcoins and HC.modules.state and HC.modules.state.request_save then
        HC.modules.state.request_save(1);
    elseif HC.modules.state and HC.modules.state.save then
        HC.modules.state.save();
    end
end

local function request_currency()
    local now=os.time();
    if now-(tonumber(currency_request_at) or 0)<30 then return false; end
    currency_request_at=now;
    return pcall(function()
        if AshitaCore and AshitaCore.GetPacketManager then
            local pm=AshitaCore:GetPacketManager();
            if pm and pm.AddOutgoingPacket and struct and struct.pack then
                pm:AddOutgoingPacket(0x010F,struct.pack('L',0):totable());
            end
        end
    end);
end

function M.init(ctx)
    HC=ctx;
    if HC.modules.packets then HC.modules.packets.register(0x113,'limbus_currency',on_currency_packet); end
    request_currency();
end

local function open_url(slug)
    local url='https://horizonffxi.wiki/'..tostring(slug or 'Category:Limbus');
    return pcall(function() os.execute('cmd /c start "" "'..url..'"'); end);
end

local function item_info(name)
    local out={name=name,count=0,location='-',owned=false};
    local s=HC.modules.skills;
    if not s or not s.collection_item_locations then return out; end
    local ok,rows,available=pcall(s.collection_item_locations,name,false);
    if not ok or available~=true then out.location='Checking...'; return out; end
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
    return out;
end

local function ki_info(name)
    local out={name=name,owned=nil,source=nil};
    local k=HC.modules.keyitems;
    if not k or not k.ownership_name then return out; end
    local ok,owned,err,id,source=pcall(k.ownership_name,name);
    if ok then out.owned=owned; out.source=source or err; out.id=id; end
    return out;
end

local function weekly_used(c)
    local w=type(c.weekly)=='table' and c.weekly or {};
    local n=0; if w.limbus_1==true then n=n+1; end; if w.limbus_2==true then n=n+1; end;
    return n;
end

local function af_plus1_progress(gear,job)
    local row=gear and gear.jobs and gear.jobs[job] or nil;
    local set=row and row.sets and row.sets.af_p1 or nil;
    return tonumber(set and set.obtained) or 0,tonumber(set and set.total) or 5;
end

local function build_snapshot(c)
    local now=os.time();
    if cache.snapshot and now-(tonumber(cache.at) or 0)<2 then return cache.snapshot; end
    local snap={};
    snap.used=weekly_used(c); snap.remaining=math.max(0,2-snap.used);
    snap.cleanse=(HC.modules.keyitems and HC.modules.keyitems.cosmo_cleanse_status and HC.modules.keyitems.cosmo_cleanse_status()) or {owned=nil};
    snap.kis={};
    for _,name in ipairs({'Red Card','Black Card','White Card'}) do snap.kis[name]=ki_info(name); end
    snap.items={};
    local names={'Magenta Chip','Charcoal Chip','Smoky Chip','Smalt Chip','Emerald Chip','Ivory Chip','Scarlet Chip','Orchid Chip','Cerulean Chip','Silver Chip','Metal Chip'};
    for _,name in ipairs(names) do snap.items[name]=item_info(name); end
    for _,job in ipairs(JOBS) do
        snap.items[APOLLYON_MATS[job]]=item_info(APOLLYON_MATS[job]);
        snap.items[TEMENOS_MATS[job]]=item_info(TEMENOS_MATS[job]);
    end
    for _,r in ipairs(BOSS_GEAR) do snap.items[r.item]=item_info(r.item); end
    snap.gear=(HC.modules.skills and HC.modules.skills.gear_collection_snapshot and HC.modules.skills.gear_collection_snapshot(false)) or nil;
    cache={at=now,snapshot=snap}; return snap;
end

local function have_ki(snap,req)
    if type(req)=='table' then
        local unknown=false;
        for _,name in ipairs(req) do
            local v=snap.kis[name] and snap.kis[name].owned;
            if v==true then return true; end
            if v==nil then unknown=true; end
        end
        return unknown and nil or false;
    end
    return snap.kis[req] and snap.kis[req].owned;
end

local function zone_status(snap,row)
    if snap.used>=2 then return 'LOCKED','2/2 weekly entries used'; end
    if snap.cleanse and snap.cleanse.owned==false then return 'NEED CLEANSE','Cosmo-Cleanse missing'; end
    local uncertain=(not snap.cleanse or snap.cleanse.owned==nil);
    local card=have_ki(snap,row.card);
    if card==false then
        if type(row.card)=='table' then return 'NEED CARD','Red or Black Card required'; end
        return 'NEED CARD',tostring(row.card)..' required';
    elseif card==nil then uncertain=true; end
    for _,chip in ipairs(row.chips or {}) do
        local info=snap.items[chip];
        if info and info.owned~=true then return 'NEED CHIP',tostring(chip)..' required'; end
    end
    if uncertain then return 'CHECK','Verify entry key items'; end
    return 'READY','Entry items held';
end


local function draw_entry_piece(imgui,label,owned)
    if owned==true then imgui.Text(tostring(label)); else imgui.TextDisabled(tostring(label)); end
end

local function draw_entry_requirements(imgui,snap,row)
    -- Keep every requirement on its own line. Inline SameLine() segments can
    -- collapse into one-character wrapping inside ImGui table cells when a
    -- Central battlefield needs several chips.
    local function draw_line(label,owned,prefix)
        local text=tostring(prefix or '')..tostring(label or '');
        draw_entry_piece(imgui,text,owned==true);
    end

    if type(row.card)=='table' then
        draw_line('Red / Black Card',have_ki(snap,row.card)==true,'Card: ');
    else
        local owned=(snap.kis[row.card] and snap.kis[row.card].owned==true);
        draw_line(tostring(row.card),owned,'Card: ');
    end

    for i,chip in ipairs(row.chips or {}) do
        local info=snap.items[chip];
        draw_line(tostring(chip),info and info.owned==true,(i==1 and 'Chip: ' or '      '));
    end
end

local function draw_zone_note(imgui,row)
    local c=HC.modules.state.get_char();
    c.limbus_notes=type(c.limbus_notes)=='table' and c.limbus_notes or {};
    local note_key=tostring(row.id or row.name or 'zone');
    if type(imgui.SetNextItemWidth)=='function' then
        pcall(function() imgui.SetNextItemWidth(-1); end);
    end
    local buf={tostring(c.limbus_notes[note_key] or '')};
    local ok,changed=pcall(function()
        return imgui.InputText('##limbus_note_'..note_key,buf,240);
    end);
    if ok and changed then
        local value=tostring(buf[1] or '');
        c.limbus_notes[note_key]=(value~='' and value or nil);
        HC.modules.state.save();
    elseif not ok then
        imgui.TextDisabled('[notes unavailable]');
    end
end

local function draw_zone_table(title,rows,snap,force_open)
    local imgui=HC.imgui;
    local flags=rawget(_G,'ImGuiTreeNodeFlags_DefaultOpen') or 0;
    if force_open==true and imgui.SetNextItemOpen then pcall(imgui.SetNextItemOpen,true,rawget(_G,'ImGuiCond_Always') or 1); end
    if not imgui.CollapsingHeader(title..'##limbus_'..string.lower(title),flags) then return; end
    local tf=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
    local supported=imgui.BeginTable and imgui.TableSetupColumn and imgui.TableHeadersRow and imgui.TableNextRow and imgui.TableSetColumnIndex and imgui.EndTable;
    if supported and imgui.BeginTable('##limbus_table_'..string.lower(title),8,tf) then
        imgui.TableSetupColumn('Area',0,0.18); imgui.TableSetupColumn('Status',0,0.09); imgui.TableSetupColumn('Entry',0,0.18);
        imgui.TableSetupColumn('Reward',0,0.12); imgui.TableSetupColumn('AF+1 focus',0,0.15); imgui.TableSetupColumn('Time',0,0.06);
        imgui.TableSetupColumn('Notes',0,0.17); imgui.TableSetupColumn('',0,0.05);
        imgui.TableHeadersRow();
        for _,row in ipairs(rows) do
            local st,why=zone_status(snap,row);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0); imgui.Text(tostring(row.name));
            imgui.TableSetColumnIndex(1); if st=='READY' then imgui.Text(st); else imgui.TextDisabled(st); end
            if imgui.IsItemHovered and imgui.IsItemHovered() then imgui.SetTooltip(tostring(why or '')); end
            imgui.TableSetColumnIndex(2);
            draw_entry_requirements(imgui,snap,row);
            imgui.TableSetColumnIndex(3); imgui.TextDisabled(tostring(row.reward));
            imgui.TableSetColumnIndex(4); imgui.TextDisabled(tostring(row.af));
            imgui.TableSetColumnIndex(5); imgui.TextDisabled(tostring(row.time));
            imgui.TableSetColumnIndex(6); draw_zone_note(imgui,row);
            imgui.TableSetColumnIndex(7); if imgui.SmallButton('GO##limbus_'..tostring(row.id)) then open_url(row.slug); end
        end
        imgui.EndTable();
    else
        for _,row in ipairs(rows) do
            local st=zone_status(snap,row);
            imgui.Text(tostring(row.name)..' | '..tostring(st)); imgui.SameLine(); imgui.TextDisabled(tostring(row.reward)..' | '..tostring(row.af));
        end
    end
end

local function material_cell(imgui,info,name)
    if info and info.owned then
        local suffix=info.count and info.count>1 and (' x'..tostring(info.count)) or '';
        imgui.Text(tostring(name)..suffix..' - '..tostring(info.location));
    else
        imgui.TextDisabled(tostring(name)..' - missing');
    end
end

local function draw_af_materials(snap,force_open)
    local imgui=HC.imgui;
    if force_open==true and imgui.SetNextItemOpen then pcall(imgui.SetNextItemOpen,true,rawget(_G,'ImGuiCond_Always') or 1); end
    if not imgui.CollapsingHeader('AF+1 Upgrade Materials##limbus_af_materials') then return; end
    imgui.TextDisabled('Each AF+1 piece uses the same job-specific Apollyon material + Temenos material. The base AF piece and crafted ingredient determine the armor slot.');
    imgui.TextDisabled('Sagheera in Port Jeuno (I-8) also requires 15-40 Ancient Beastcoins depending on the piece.');
    local tf=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
    if imgui.BeginTable and imgui.BeginTable('##limbus_af_material_table',5,tf) then
        imgui.TableSetupColumn('Job',0,0.07);
        imgui.TableSetupColumn('Apollyon Material',0,0.31);
        imgui.TableSetupColumn('Temenos Material',0,0.31);
        imgui.TableSetupColumn('AF+1',0,0.23);
        imgui.TableSetupColumn('',0,0.08);
        imgui.TableHeadersRow();
        for _,job in ipairs(JOBS) do
            local have,total=af_plus1_progress(snap.gear,job);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0); imgui.Text(job);
            imgui.TableSetColumnIndex(1); material_cell(imgui,snap.items[APOLLYON_MATS[job]],APOLLYON_MATS[job]);
            imgui.TableSetColumnIndex(2); material_cell(imgui,snap.items[TEMENOS_MATS[job]],TEMENOS_MATS[job]);
            imgui.TableSetColumnIndex(3); if have>=total then imgui.Text(string.format('%d/%d COMPLETE',have,total)); else imgui.TextDisabled(string.format('%d/%d | %d piece(s) left',have,total,math.max(0,total-have))); end
            imgui.TableSetColumnIndex(4);
            if imgui.SmallButton('GO##limbus_afplus1_'..tostring(job)) then
                if HC.modules.ui and HC.modules.ui.navigate then
                    HC.modules.ui.navigate('Character Info',{section='jobprogression',job=tostring(job)});
                end
            end
            if imgui.IsItemHovered and imgui.IsItemHovered() then
                imgui.SetTooltip('Open Character Info -> Job Progression for '..tostring(job)..' to view obtained AF+1 pieces.');
            end
        end
        imgui.EndTable();
    end
end

local function draw_boss_gear(snap,force_open)
    local imgui=HC.imgui;
    if force_open==true and imgui.SetNextItemOpen then pcall(imgui.SetNextItemOpen,true,rawget(_G,'ImGuiCond_Always') or 1); end
    local homam,nashira=0,0;
    for _,r in ipairs(BOSS_GEAR) do if snap.items[r.item] and snap.items[r.item].owned then if r.set=='Homam' then homam=homam+1 else nashira=nashira+1 end end end
    if not imgui.CollapsingHeader(string.format('Omega / Ultima Armor  |  Homam %d/5  |  Nashira %d/5##limbus_boss_gear',homam,nashira)) then return; end
    imgui.TextDisabled('Trade Proto-Omega / Proto-Ultima body parts to Wilhelm in Mhaura (G-10) for Homam / Nashira armor.');
    local tf=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
    if imgui.BeginTable and imgui.BeginTable('##limbus_boss_gear_table',5,tf) then
        imgui.TableSetupColumn('Set',0,0.12); imgui.TableSetupColumn('Boss Part',0,0.24); imgui.TableSetupColumn('Item',0,0.28); imgui.TableSetupColumn('Status',0,0.10); imgui.TableSetupColumn('Location',0,0.26); imgui.TableHeadersRow();
        for _,r in ipairs(BOSS_GEAR) do
            local info=snap.items[r.item] or {owned=false,location='—'};
            imgui.TableNextRow(); imgui.TableSetColumnIndex(0); imgui.Text(r.set); imgui.TableSetColumnIndex(1); imgui.TextDisabled(r.part);
            imgui.TableSetColumnIndex(2); if HC.modules.uikit and HC.modules.uikit.collection_item then HC.modules.uikit.collection_item(r.item,info.owned); elseif info.owned then imgui.Text(r.item); else imgui.TextDisabled(r.item); end
            imgui.TableSetColumnIndex(3); if HC.modules.uikit and HC.modules.uikit.collection_status then HC.modules.uikit.collection_status(info.owned,'—'); elseif info.owned then imgui.Text('✓'); else imgui.TextDisabled('—'); end
            imgui.TableSetColumnIndex(4); if HC.modules.uikit and HC.modules.uikit.collection_location then HC.modules.uikit.collection_location(info.location,info.owned); else imgui.TextDisabled(info.owned and tostring(info.location) or '—'); end
        end
        imgui.EndTable();
    end
end

function M.catalog_entries(c)
    c=c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    local snap=build_snapshot(c);
    local out={};
    local function add_zone(section,row)
        local st,why=zone_status(snap,row);
        out[#out+1]={
            kind='area',name=tostring(row.name),section=section,status=st,detail=tostring(why or ''),
            reward=tostring(row.reward or ''),af=tostring(row.af or ''),time=tostring(row.time or ''),
            search=table.concat({tostring(row.name),tostring(row.reward),tostring(row.af),type(row.card)=='table' and table.concat(row.card,' ') or tostring(row.card),table.concat(row.chips or {},' ')},' '),
        };
    end
    for _,r in ipairs(APOLLYON) do add_zone('apollyon',r); end
    for _,r in ipairs(TEMENOS) do add_zone('temenos',r); end
    local seen={};
    local function add_item(name,section)
        if not name or name=='Homam armor' or name=='Nashira armor' or name=='Ancient Beastcoins' or seen[name] then return; end; seen[name]=true;
        local info=snap.items[name] or item_info(name);
        out[#out+1]={kind='item',name=tostring(name),section=section,owned=info and info.owned==true,location=info and tostring(info.location or '') or '',search=tostring(name)..' '..tostring(section)};
    end
    for _,r in ipairs(APOLLYON) do add_item(r.reward,'Apollyon'); for _,x in ipairs(r.chips or {}) do add_item(x,'Apollyon chip'); end end
    for _,r in ipairs(TEMENOS) do add_item(r.reward,'Temenos'); for _,x in ipairs(r.chips or {}) do add_item(x,'Temenos chip'); end end
    for _,job in ipairs(JOBS) do add_item(APOLLYON_MATS[job],job..' AF+1'); add_item(TEMENOS_MATS[job],job..' AF+1'); end
    for _,r in ipairs(BOSS_GEAR) do add_item(r.item,r.set); end
    return out;
end

function M.draw(c)
    local imgui=HC.imgui; if not imgui then return; end
    c=c or HC.modules.state.get_char();
    local nav=(HC.modules.ui and HC.modules.ui.consume_focus) and HC.modules.ui.consume_focus('limbus') or nil;
    local focus=type(nav)=='table' and string.lower(tostring(nav.section or '')) or '';
    local snap=build_snapshot(c);
    local remain=HC.modules.core and HC.modules.core.seconds_until_weekly_reset and HC.modules.core.seconds_until_weekly_reset() or nil;
    local reset=remain and HC.modules.core.format_duration(remain) or '?';
    local cleanse=(snap.cleanse and snap.cleanse.owned==true) and 'HELD' or ((snap.cleanse and snap.cleanse.owned==false) and 'MISSING' or 'CHECK');
    local currency=ensure_currency(c);
    if not currency.last_verified_at or os.time()-(tonumber(currency.last_verified_at) or 0)>60 then request_currency(); end

    imgui.Text(string.format('Limbus  |  Weekly entries %d/2 used  |  %d remaining  |  Cosmo-Cleanse %s',snap.used,snap.remaining,cleanse));
    imgui.TextDisabled('Resets with Conquest tally in '..tostring(reset)..'  |  Entry requires Al\'Taieu access and consumes Cosmo-Cleanse + the listed card/chips.');
    if currency.ancient_beastcoins~=nil then
        imgui.TextDisabled(string.format('Ancient Beastcoins Stored: %d  |  Currency menu',currency.ancient_beastcoins));
    else
        imgui.TextDisabled('Ancient Beastcoins Stored: checking Currency menu...');
    end

    imgui.Spacing();
    imgui.TextDisabled('Chip paths: NW / SW / NE / SE -> four Apollyon chips -> Proto-Omega | West / East / North -> Central 1 / 2 / 3 -> three Temenos chips -> Proto-Ultima.');
    imgui.Spacing();

    draw_zone_table('Apollyon',APOLLYON,snap,focus=='apollyon');
    imgui.Spacing();
    draw_zone_table('Temenos',TEMENOS,snap,focus=='temenos');
    imgui.Spacing();
    draw_af_materials(snap,focus=='af');
    imgui.Spacing();
    draw_boss_gear(snap,focus=='boss');

    if type(c.settings)=='table' and c.settings.developer_mode==true then
        imgui.Spacing(); imgui.Separator(); imgui.TextDisabled('Developer: Limbus zone entry is auto-counted from Temenos/Apollyon zone transitions; detailed lockout repair remains in Diagnostics.');
    end
end

return M;
