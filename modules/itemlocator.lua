local M={};
local HC;
local buffer={''};
local poll_at=0;
local POLL_SECONDS=10;

local LOC_SHORT={
    ['INVENTORY']='Inv',['SAFE']='Safe',['STORAGE']='Storage',['TEMP']='Temp',['LOCKER']='Locker',
    ['SATCHEL']='Satchel',['SACK']='Sack',['CASE']='Case',
    ['WARDROBE 1']='W1',['WARDROBE 2']='W2',['WARDROBE 3']='W3',['WARDROBE 4']='W4',
    ['WARDROBE 5']='W5',['WARDROBE 6']='W6',['WARDROBE 7']='W7',['WARDROBE 8']='W8',
    ['PORTER MOOGLE']='Porter',
};

local function lower(v) return string.lower(tostring(v or '')); end
local function compact(v) return lower(v):gsub('[^%w]+',' '):gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$',''); end

local function short_location(v)
    local s=tostring(v or '');
    for long,short in pairs(LOC_SHORT) do s=s:gsub(long,short); end
    return s;
end

local function ensure(c)
    c.item_locator_snapshot=type(c.item_locator_snapshot)=='table' and c.item_locator_snapshot or {};
    c.item_locator_snapshot.rows=type(c.item_locator_snapshot.rows)=='table' and c.item_locator_snapshot.rows or {};
    return c.item_locator_snapshot;
end

function M.refresh_current(c,force)
    c=c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or nil;
    if type(c)~='table' or not HC.modules.skills or not HC.modules.skills.collection_inventory_snapshot then return false,'inventory reader unavailable'; end
    local saved=ensure(c);
    local token=(HC.modules.skills.collection_scan_token and HC.modules.skills.collection_scan_token()) or nil;
    if force~=true and tonumber(saved.version)==3 and saved.token~=nil and token~=nil and tostring(saved.token)==tostring(token) and #saved.rows>0 then return false,'current'; end
    local ok,snap=pcall(HC.modules.skills.collection_inventory_snapshot,force==true);
    if not ok or type(snap)~='table' or snap.available~=true then return false,'inventory not ready'; end
    local rows={};
    for _,r in ipairs(snap.rows or {}) do
        if r.name and tostring(r.name)~='' then
            rows[#rows+1]={id=tonumber(r.id),name=tostring(r.name),aliases=type(r.aliases)=='table' and r.aliases or {},count=tonumber(r.count) or 1,location=short_location(r.location)};
        end
    end
    saved.rows=rows;
    saved.at=os.time();
    saved.token=tostring(snap.token or token or saved.at);
    saved.version=3;
    if HC.modules.state and HC.modules.state.request_save then HC.modules.state.request_save(2); end
    return true,'updated';
end

function M.poll(c)
    local now=os.time(); if now-(tonumber(poll_at) or 0)<POLL_SECONDS then return false; end
    poll_at=now;
    return M.refresh_current(c,false);
end

local function safe_saved_name(v)
    if type(v)~='string' then return nil; end
    v=v:gsub('%z',''):gsub('^%s+',''):gsub('%s+$','');
    if #v<2 or #v>96 then return nil; end
    local controls=0; local weird=0; local qmarks=0; local hashes=0; local letters=0;
    for i=1,#v do
        local b=v:byte(i);
        if b<32 or b==127 then controls=controls+1;
        elseif b>=128 then weird=weird+1; end
    end
    for _ in v:gmatch('%?') do qmarks=qmarks+1; end
    for _ in v:gmatch('#') do hashes=hashes+1; end
    for _ in v:gmatch('[A-Za-z]') do letters=letters+1; end
    if controls>0 or weird>2 or qmarks>1 or hashes>1 or letters<2 then return nil; end
    if v:match('^Item %d+$') then return nil; end
    return v;
end

local function matches_text(value,q)
    value=safe_saved_name(value);
    if not value then return false; end
    q=compact(q); if q=='' then return false; end
    local h=compact(value);
    for tok in q:gmatch('%S+') do if not h:find(tok,1,true) then return false; end end
    return true;
end

local function row_matches_text(r,q)
    if matches_text(r and r.name,q) then return true; end
    for _,alias in ipairs(type(r and r.aliases)=='table' and r.aliases or {}) do
        if matches_text(alias,q) then return true; end
    end
    return false;
end

-- Existing v7.9.0/7.9.1 snapshots already contain item IDs even on clients
-- where Ashita did not expose a usable resource display string.  Resolve the
-- typed phrase through HorizonCheck's tracked-item catalog and match those IDs
-- so old snapshots begin working immediately without logging every alt again.
local function catalog_id_matches(q)
    local ids={}; local names={};
    local search=HC.modules and HC.modules.search or nil;
    local skills=HC.modules and HC.modules.skills or nil;
    if not (search and search.query and skills and skills.collection_resolve_ids) then return ids,names; end
    local c=HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char() or {};
    local ok,rows=pcall(search.query,q,c,80);
    if not ok then return ids,names; end
    for _,row in ipairs(rows or {}) do
        local kind=tostring(row.kind or '');
        if kind=='Job Gear' or kind=='Sea / Sky' or kind=='Assault Reward' or kind=='Limbus Item' or kind=='HENM Reward' or kind=='Event Reward' then
            local okid,resolved=pcall(skills.collection_resolve_ids,row.name);
            if okid then
                for _,id in ipairs(resolved or {}) do
                    id=tonumber(id); if id then ids[id]=true; names[id]=names[id] or tostring(row.name); end
                end
            end
        end
    end
    return ids,names;
end

function M.query(q,limit)
    q=tostring(q or ''); if compact(q)=='' then return {}; end
    local current=HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char() or nil;
    if type(current)=='table' then M.refresh_current(current,false); end
    local id_matches,id_names=catalog_id_matches(q);
    local raw=HC.modules.state and HC.modules.state.raw and HC.modules.state.raw() or {};
    local chars=type(raw.chars)=='table' and raw.chars or {};
    local out={};
    for char,cc in pairs(chars) do
        local snap=type(cc)=='table' and type(cc.item_locator_snapshot)=='table' and cc.item_locator_snapshot or nil;
        if snap and type(snap.rows)=='table' then
            for _,r in ipairs(snap.rows) do
                local rid=tonumber(r.id);
                if row_matches_text(r,q) or (rid and id_matches[rid]) then
                    local display=safe_saved_name(r.name);
                    if not display then display=safe_saved_name(id_names[rid]); end
                    if display then
                    out[#out+1]={
                        character=tostring(char),
                        name=display,
                        count=tonumber(r.count) or 1,
                        location=tostring(r.location or 'Owned'),
                        at=tonumber(snap.at),
                        current=(tostring(char)==tostring(HC.modules.state.profile_name())),
                    };
                    end
                end
            end
        end
    end
    table.sort(out,function(a,b)
        local aq,bq=compact(a.name),compact(b.name); local qq=compact(q);
        local ae=(aq==qq) and 1 or 0; local be=(bq==qq) and 1 or 0;
        if ae~=be then return ae>be; end
        if a.name~=b.name then return lower(a.name)<lower(b.name); end
        if a.current~=b.current then return a.current==true; end
        return lower(a.character)<lower(b.character);
    end);
    local maxn=math.max(1,tonumber(limit) or 30); while #out>maxn do table.remove(out); end
    return out;
end

local function age_label(at)
    at=tonumber(at); if not at then return 'Not refreshed'; end
    local age=math.max(0,os.time()-at);
    if age<120 then return 'Now'; elseif age<3600 then return tostring(math.floor(age/60))..'m ago';
    elseif age<86400 then return tostring(math.floor(age/3600))..'h ago'; end
    return tostring(math.floor(age/86400))..'d ago';
end

local function draw_rows(imgui,rows,id)
    if #rows==0 then imgui.TextDisabled('No saved inventory match found. If the counter above is 0, click Refresh This Character on each character once.'); return; end
    local flags=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
    local table_ok=imgui.BeginTable and imgui.TableSetupColumn and imgui.TableHeadersRow and imgui.TableNextRow and imgui.TableSetColumnIndex and imgui.EndTable;
    if table_ok and imgui.BeginTable('##item_locator_'..tostring(id),4,flags) then
        imgui.TableSetupColumn('Item',0,0.35); imgui.TableSetupColumn('Character',0,0.20); imgui.TableSetupColumn('Location',0,0.30); imgui.TableSetupColumn('Updated',0,0.15); imgui.TableHeadersRow();
        for _,r in ipairs(rows) do
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0); imgui.Text(tostring(r.name)..((tonumber(r.count) or 1)>1 and (' x'..tostring(r.count)) or ''));
            imgui.TableSetColumnIndex(1); if r.current then imgui.Text(tostring(r.character)); else imgui.TextDisabled(tostring(r.character)); end
            imgui.TableSetColumnIndex(2); imgui.TextDisabled(tostring(r.location));
            imgui.TableSetColumnIndex(3); imgui.TextDisabled(age_label(r.at));
        end
        imgui.EndTable();
    else
        for _,r in ipairs(rows) do imgui.Text(tostring(r.name)..' - '..tostring(r.character)); imgui.SameLine(); imgui.TextDisabled(tostring(r.location)); end
    end
end

function M.draw_search_matches(q)
    local imgui=HC and HC.imgui or nil; if not imgui or compact(q)=='' then return; end
    local rows=M.query(q,12);
    if #rows==0 then return; end
    imgui.Spacing();
    imgui.Text('Across Your Characters'); imgui.SameLine(); imgui.TextDisabled(tostring(#rows)..' location match'..(#rows==1 and '' or 'es'));
    draw_rows(imgui,rows,'global');
end

function M.draw(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    M.poll(c);
    if not imgui.CollapsingHeader('Account Item Locator##character_info_item_locator') then return; end
    imgui.TextDisabled('Find where an item was last seen across your saved characters. Each character refreshes when you use HorizonCheck while logged into that character.');
    local st=M.status();
    imgui.TextDisabled(string.format('Saved inventories: %d character%s | %d item entries',tonumber(st.characters) or 0,(tonumber(st.characters) or 0)==1 and '' or 's',tonumber(st.items) or 0));
    local ok=pcall(function() imgui.InputText('##hc_account_item_search',buffer,120); end);
    if not ok then imgui.TextDisabled('Item search is unavailable in this UI build.'); return; end
    imgui.SameLine();
    if imgui.SmallButton('Refresh This Character##hc_account_item_refresh') then M.refresh_current(c,true); end
    if tostring(buffer[1] or '')=='' then
        imgui.TextDisabled('Try: Homam, Haubergeon, Rabbit Belt, Ancient Beastcoin...');
        return;
    end
    draw_rows(imgui,M.query(buffer[1],30),'character_info');
end

function M.status()
    local raw=HC.modules.state and HC.modules.state.raw and HC.modules.state.raw() or {};
    local chars=type(raw.chars)=='table' and raw.chars or {}; local n=0; local items=0;
    for _,cc in pairs(chars) do
        local snap=type(cc)=='table' and cc.item_locator_snapshot or nil;
        if type(snap)=='table' and type(snap.rows)=='table' and #snap.rows>0 then n=n+1; items=items+#snap.rows; end
    end
    return {characters=n,items=items};
end

function M.init(ctx) HC=ctx; end
return M;
