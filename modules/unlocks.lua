local M = {};
local HC;
local defs=nil;
local cache_by_char={};
local REFRESH_SECONDS=8;

local function lower(v) return string.lower(tostring(v or '')); end
local function norm(v)
    local s=lower(v):gsub('[^%w]+','_'):gsub('_+','_'):gsub('^_',''):gsub('_$',''); return s;
end

local function load_defs()
    if defs then return defs; end
    defs={};
    if HC and HC.addon_path then
        local ok,t=pcall(dofile,HC.addon_path..'data\\permanent_unlocks.lua');
        if ok and type(t)=='table' then defs=t; end
    end
    return defs;
end

local function char_name()
    return tostring((HC and HC.modules and HC.modules.core and HC.modules.core.character_name and HC.modules.core.character_name()) or 'Unknown');
end

local function store(c)
    c.unlock_registry=type(c.unlock_registry)=='table' and c.unlock_registry or {};
    c.unlock_registry.proofs=type(c.unlock_registry.proofs)=='table' and c.unlock_registry.proofs or {};
    return c.unlock_registry;
end

local function dynamic_def(row)
    local name=tostring(row and row.name or ''); local l=lower(name);
    if l:find('^map of ') then return {key='map:'..norm(name),id=row.id,name=name,category='Map',sticky=true,dynamic=true}; end
    if l:find('gate crystal$',1,false) then return {key='teleport:'..norm(name),id=row.id,name=name,category='Teleport',sticky=true,dynamic=true}; end
    return nil;
end

local function merged_defs()
    local out={}; local seen={};
    for _,d in ipairs(load_defs()) do out[#out+1]=d; seen[tonumber(d.id) or -1]=true; end
    local ki=HC and HC.modules and HC.modules.keyitems or nil;
    if ki and ki.owned_key_items then
        local ok,rows=pcall(ki.owned_key_items); if ok then
            for _,r in ipairs(rows or {}) do
                if not seen[tonumber(r.id)] then local d=dynamic_def(r); if d then out[#out+1]=d; seen[tonumber(r.id)]=true; end end
            end
        end
    end
    return out;
end

function M.refresh(c,force)
    c=c or HC.modules.state.get_char(); local name=char_name(); local now=os.time();
    local cached=cache_by_char[name]; if not force and cached and now-(cached.at or 0)<REFRESH_SECONDS then return cached; end
    local reg=store(c); local rows={}; local by_key={}; local by_name={}; local by_id={}; local changed=false;
    local ki=HC.modules.keyitems;
    for _,d in ipairs(merged_defs()) do
        local proof=reg.proofs[d.key]; local owned=nil; local source='no evidence'; local err=nil;
        if ki and ki.ownership_id and tonumber(d.id) then
            local ok,a,b,_,src=pcall(ki.ownership_id,tonumber(d.id),d.name);
            if ok then owned=a; err=b; source=src or 'key-item ownership'; else err=tostring(a); end
        end
        if owned~=true and type(proof)=='table' and proof.owned==true then owned=true; source='saved unlock proof'; end
        if owned==true and d.sticky==true and not (type(proof)=='table' and proof.owned==true) then
            reg.proofs[d.key]={owned=true,id=d.id,name=d.name,category=d.category,source=source,verified_at=now}; changed=true;
        end
        local r={key=d.key,id=d.id,name=d.name,category=d.category or 'Other',owned=owned,source=source,error=err,sticky=d.sticky==true,dynamic=d.dynamic==true};
        rows[#rows+1]=r; by_key[r.key]=r; by_name[lower(r.name)]=r; by_id[tonumber(r.id) or -1]=r;
    end
    table.sort(rows,function(a,b) if a.category~=b.category then return a.category<b.category; end return lower(a.name)<lower(b.name); end);
    local snap={at=now,rows=rows,by_key=by_key,by_name=by_name,by_id=by_id,counts={}};
    for _,r in ipairs(rows) do local k=r.owned==true and 'OWNED' or (r.owned==false and 'MISSING' or 'UNKNOWN'); snap.counts[k]=(snap.counts[k] or 0)+1; end
    cache_by_char[name]=snap;
    if changed and HC.modules.state and HC.modules.state.request_save then HC.modules.state.request_save(1); end
    return snap;
end

function M.get(key,c) return M.refresh(c,false).by_key[tostring(key or '')]; end
function M.by_name(name,c) return M.refresh(c,false).by_name[lower(name)]; end
function M.by_id(id,c) return M.refresh(c,false).by_id[tonumber(id) or -1]; end
function M.owned(key,c) local r=M.get(key,c); return r and r.owned or nil,r; end
function M.owned_name(name,c) local r=M.by_name(name,c); return r and r.owned or nil,r; end
function M.snapshot(c,force) return M.refresh(c,force==true); end
function M.definitions() return merged_defs(); end

function M.draw(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local s=M.refresh(c,false);
    imgui.Text('Permanent Unlock Registry');
    imgui.TextDisabled('Shared registry for maps, teleport crystals, access passes, crafting unlocks, and permanent Dynamis clear proof.');
    imgui.Text(string.format('Owned %d | Missing %d | Unknown %d',s.counts.OWNED or 0,s.counts.MISSING or 0,s.counts.UNKNOWN or 0));
    local category=nil;
    for _,r in ipairs(s.rows) do
        if r.category~=category then category=r.category; imgui.Separator(); imgui.Text(category); end
        local state=r.owned==true and 'OWNED' or (r.owned==false and 'MISSING' or 'UNKNOWN');
        if r.owned==true then imgui.Text(string.format('%-30s %s',r.name,state)); else imgui.TextDisabled(string.format('%-30s %s',r.name,state)); end
    end
    if imgui.Button('Refresh Unlock Registry##hc_unlock_refresh') then M.refresh(c,true); end
end

function M.status(c) local s=M.refresh(c,false); return {at=s.at,counts=s.counts,total=#s.rows}; end
function M.command(w)
    local sub=lower(w[2]); if sub~='unlocks' and sub~='unlock' then return false; end
    local s=M.refresh(HC.modules.state.get_char(),true); HC.msg(string.format('Unlock registry: %d owned | %d missing | %d unknown',s.counts.OWNED or 0,s.counts.MISSING or 0,s.counts.UNKNOWN or 0)); return true;
end
function M.init(ctx) HC=ctx; load_defs(); end
return M;
