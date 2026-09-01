local M={};
local HC;

local cache={token=nil,items={}};
local ACCOUNT_CACHE_SECONDS=5;
local account_cache={at=0,token=nil,rows={}};

local SHORT={
    ['INVENTORY']='Inventory',['SAFE']='Safe',['STORAGE']='Storage',['TEMP']='Temp',['LOCKER']='Locker',
    ['SATCHEL']='Satchel',['SACK']='Sack',['CASE']='Case',
    ['WARDROBE 1']='Wardrobe 1',['WARDROBE 2']='Wardrobe 2',['WARDROBE 3']='Wardrobe 3',['WARDROBE 4']='Wardrobe 4',
    ['WARDROBE 5']='Wardrobe 5',['WARDROBE 6']='Wardrobe 6',['WARDROBE 7']='Wardrobe 7',['WARDROBE 8']='Wardrobe 8',
    ['PORTER MOOGLE']='Porter Moogle',['STORED']='Porter Moogle',['OBTAINED']='Owned',
};

local function compact(v)
    return string.lower(tostring(v or '')):gsub('[^%w]+',' '):gsub('^%s+',''):gsub('%s+$',''):gsub('%s+',' ');
end

local function aliases(input)
    local out={};
    if type(input)=='table' then
        for _,v in ipairs(input) do if tostring(v or '')~='' then out[#out+1]=tostring(v); end end
    elseif tostring(input or '')~='' then out[1]=tostring(input); end
    return out;
end

local function cache_key(input)
    local a=aliases(input); local t={};
    for _,v in ipairs(a) do t[#t+1]=compact(v); end
    table.sort(t); return table.concat(t,'|');
end

local function scan_token()
    local s=HC and HC.modules and HC.modules.skills or nil;
    if s and s.collection_scan_token then
        local ok,v=pcall(s.collection_scan_token); if ok then return tostring(v); end
    end
    return 'na';
end

local function ensure_cache()
    local token=scan_token();
    if cache.token~=token then cache={token=token,items={}}; end
    return token;
end

local function resolve_ids(input)
    local s=HC and HC.modules and HC.modules.skills or nil;
    if not s or not s.collection_resolve_ids then return {}; end
    local ok,ids=pcall(s.collection_resolve_ids,aliases(input));
    if not ok or type(ids)~='table' then return {}; end
    local out={}; local seen={};
    for _,id in ipairs(ids) do id=tonumber(id); if id and not seen[id] then seen[id]=true; out[#out+1]=id; end end
    return out;
end

local function location_label(v)
    v=tostring(v or '');
    return SHORT[v] or v;
end

-- Authoritative current-character ownership facade. This is the one API normal
-- collection trackers should call instead of each reimplementing inventory,
-- wardrobe, Porter Moogle, name-alias, and count logic.
function M.resolve_ids(input) return resolve_ids(input); end

function M.current(input,force)
    local token=ensure_cache(); local key=cache_key(input);
    if force~=true and key~='' and cache.items[key] then return cache.items[key]; end
    local s=HC and HC.modules and HC.modules.skills or nil;
    local out={known=false,owned=false,state='CHECKING',name=aliases(input)[1],count=0,location='—',locations={},ids=resolve_ids(input),token=token,source='collection scan'};
    if not s or not s.collection_item_locations then
        out.source='inventory reader unavailable'; if key~='' then cache.items[key]=out; end; return out;
    end

    local ok,rows,available,matched,total=pcall(s.collection_item_locations,aliases(input),force==true);
    if not ok or available~=true then
        out.source=ok and 'inventory not ready' or tostring(rows); if key~='' then cache.items[key]=out; end; return out;
    end
    out.known=true; out.matched=matched; out.count=math.max(0,tonumber(total) or 0);
    local parts={};
    for _,row in ipairs(type(rows)=='table' and rows or {}) do
        local count=math.max(0,tonumber(row and row.count) or 0);
        if count>0 then
            local label=location_label(row.label);
            parts[#parts+1]=label..(count>1 and (' x'..tostring(count)) or '');
            out.locations[#out.locations+1]={location=label,count=count,container_id=tonumber(row.container_id)};
        end
    end
    if out.count>0 then
        out.owned=true; out.state='OWNED'; out.location=#parts>0 and table.concat(parts,', ') or 'Owned';
    else
        -- collection_item_locations intentionally reports only physical bins.
        -- Ask the same cached scan for Porter/storage-slip proof before calling
        -- the item missing.
        local loc=nil; local available2=false; local matched2=nil;
        if s.collection_item_location_ids and #out.ids>0 then
            local ok2,a,b,c=pcall(s.collection_item_location_ids,out.ids,aliases(input),false);
            if ok2 then loc,available2,matched2=a,b,c; end
        elseif s.collection_item_location then
            local ok2,a,b,c=pcall(s.collection_item_location,aliases(input),false);
            if ok2 then loc,available2,matched2=a,b,c; end
        end
        if available2==true and loc~=nil then
            out.owned=true; out.state='OWNED'; out.count=math.max(1,out.count); out.location=location_label(loc); out.matched=matched2 or out.matched;
            out.locations[#out.locations+1]={location=out.location,count=1};
        else
            out.state='MISSING'; out.location='—';
        end
    end
    if key~='' then cache.items[key]=out; end
    return out;
end

function M.owned(input,force)
    local r=M.current(input,force); return r.known and r.owned or nil,r;
end

function M.location(input,force)
    local r=M.current(input,force); return r.location,r.known,r;
end

function M.location_ids(item_ids,item_names,force)
    local s=HC and HC.modules and HC.modules.skills or nil;
    if not s or not s.collection_item_location_ids then return nil,false,nil; end
    local ok,loc,known,matched=pcall(s.collection_item_location_ids,type(item_ids)=='table' and item_ids or {},aliases(item_names),force==true);
    if not ok then return nil,false,nil; end
    return loc and location_label(loc) or nil,known==true,matched;
end

function M.count(input,force)
    local r=M.current(input,force); return r.count,r.known,r;
end

local function safe_name(v)
    if type(v)~='string' then return nil; end
    v=v:gsub('%z',''):gsub('^%s+',''):gsub('%s+$','');
    if #v<2 or #v>96 then return nil; end
    local controls,weird,letters=0,0,0;
    for i=1,#v do local b=v:byte(i); if b<32 or b==127 then controls=controls+1 elseif b>=128 then weird=weird+1 end end
    for _ in v:gmatch('[A-Za-z]') do letters=letters+1; end
    if controls>0 or weird>2 or letters<2 or v:match('^Item %d+$') then return nil; end
    return v;
end

local function account_rows(force)
    local now=os.time(); local token=scan_token();
    if force~=true and account_cache.token==token and now-(tonumber(account_cache.at) or 0)<ACCOUNT_CACHE_SECONDS then return account_cache.rows; end
    local raw=HC.modules.state and HC.modules.state.raw and HC.modules.state.raw() or {};
    local current=tostring(HC.modules.state and HC.modules.state.profile_name and HC.modules.state.profile_name() or '');
    local rows={};
    for char,cc in pairs(type(raw.chars)=='table' and raw.chars or {}) do
        local snap=type(cc)=='table' and type(cc.item_locator_snapshot)=='table' and cc.item_locator_snapshot or nil;
        if snap and type(snap.rows)=='table' then
            for _,r in ipairs(snap.rows) do
                rows[#rows+1]={character=tostring(char),current=tostring(char)==current,id=tonumber(r.id),name=safe_name(r.name),aliases=type(r.aliases)=='table' and r.aliases or {},count=tonumber(r.count) or 1,location=tostring(r.location or 'Owned'),at=tonumber(snap.at)};
            end
        end
    end
    account_cache={at=now,token=token,rows=rows}; return rows;
end

local function row_matches(row,names,idset)
    if row.id and idset[row.id] then return true; end
    local wanted={}; for _,v in ipairs(names) do wanted[compact(v)]=true; end
    local function hit(v)
        v=safe_name(v); if not v then return false; end
        local k=compact(v); if wanted[k] then return true; end
        for q in pairs(wanted) do if q~='' and k==q then return true; end end
        return false;
    end
    if hit(row.name) then return true; end
    for _,v in ipairs(row.aliases or {}) do if hit(v) then return true; end end
    return false;
end

-- Last-known account-wide ownership. Current character physical state remains
-- authoritative; offline rows are explicitly marked saved rather than live.
function M.account(input,opts)
    opts=type(opts)=='table' and opts or {};
    local names=aliases(input); local ids=resolve_ids(input); local idset={}; for _,id in ipairs(ids) do idset[id]=true; end
    local rows={}; local current=M.current(input,opts.force_current==true);
    if current.known and current.owned then
        rows[#rows+1]={character=tostring(HC.modules.state.profile_name()),current=true,owned=true,count=current.count,location=current.location,at=os.time(),freshness='LIVE'};
    end
    for _,r in ipairs(account_rows(opts.force==true)) do
        if not r.current and row_matches(r,names,idset) then
            rows[#rows+1]={character=r.character,current=false,owned=true,count=r.count,location=r.location,at=r.at,freshness='SAVED'};
        end
    end
    table.sort(rows,function(a,b) if a.current~=b.current then return a.current==true; end; return string.lower(a.character)<string.lower(b.character); end);
    return {owned=#rows>0,known=current.known or #rows>0,rows=rows,current=current,ids=ids,state=(#rows>0 and 'OWNED' or (current.known and 'MISSING' or 'CHECKING'))};
end

function M.refresh(force)
    local s=HC and HC.modules and HC.modules.skills or nil;
    if force==true and s and s.refresh_collection_scan then pcall(s.refresh_collection_scan); end
    cache={token=nil,items={}}; account_cache={at=0,token=nil,rows={}};
    local il=HC and HC.modules and HC.modules.itemlocator or nil;
    local c=HC and HC.modules and HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char() or nil;
    if il and il.refresh_current and c then pcall(il.refresh_current,c,force==true); end
    return true;
end

function M.status()
    local n=0; for _ in pairs(cache.items or {}) do n=n+1; end
    return {token=cache.token,cached_items=n,account_rows=#account_rows(false)};
end

function M.init(ctx) HC=ctx; end
return M;
