local M = {};
local HC;
local rules=nil;
local cache={at=0,snapshot=nil};
local quest_cache={};
local mission_cache={};

local CONTENT_STATES={AVAILABLE=true,HORIZON_CUSTOM=true,UNVERIFIED=true,FUTURE=true,UNAVAILABLE=true,DISABLED=true};
local NATIVE_POLICIES={ALLOW=true,QUARANTINE=true,BLOCK=true};

local function lower(v) return string.lower(tostring(v or '')); end
local function trim(v) return tostring(v or ''):gsub('^%s+',''):gsub('%s+$',''); end
local function qkey(log_id,quest_id) return tostring(tonumber(log_id) or log_id)..':'..tostring(tonumber(quest_id) or quest_id); end
local function normalize_name(v)
    return lower(v):gsub('[%p%c]+',' '):gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$','');
end

local function load_rules()
    if rules~=nil then return rules; end
    rules={schema=1,quests={},mission_caps={},generic_source_patterns={}};
    if HC and HC.addon_path then
        local ok,t=pcall(dofile,HC.addon_path..'data\\horizon_canonical_content.lua');
        if ok and type(t)=='table' then rules=t; end
    end
    rules.quests=type(rules.quests)=='table' and rules.quests or {};
    rules.mission_caps=type(rules.mission_caps)=='table' and rules.mission_caps or {};
    rules.generic_source_patterns=type(rules.generic_source_patterns)=='table' and rules.generic_source_patterns or {};
    return rules;
end

local function trusted_source(detail)
    detail=type(detail)=='table' and detail or {};
    local h=type(detail.horizon)=='table' and detail.horizon or nil;
    if not h or h.verified~=true then return false,'catalog source is not verified'; end
    local src=trim(h.source);
    if src=='' then return false,'verified catalog record has no source'; end
    local l=lower(src);
    for _,pat in ipairs(load_rules().generic_source_patterns or {}) do
        if l:find(lower(pat),1,true) then return false,'generic/build-derived source: '..src; end
    end
    return true,src;
end

local function content_from_availability(a)
    local state=type(a)=='table' and string.upper(tostring(a.state or 'UNVERIFIED')) or 'UNVERIFIED';
    if state=='DISABLED' then return 'UNAVAILABLE'; end
    if CONTENT_STATES[state] then return state; end
    return 'UNVERIFIED';
end

local function copy_table(t)
    local out={}; for k,v in pairs(type(t)=='table' and t or {}) do out[k]=v; end; return out;
end

function M.quest(log_id,quest_id,detail)
    local key=qkey(log_id,quest_id);
    local cached=quest_cache[key];
    if cached~=nil then return cached; end
    if type(detail)~='table' then
        local q=HC and HC.modules and HC.modules.quests or nil;
        if q and q.detail then local ok,v=pcall(q.detail,log_id,quest_id); if ok then detail=v; end end
    end
    detail=type(detail)=='table' and detail or {};
    local override=load_rules().quests[key];
    local av=nil;
    local am=HC and HC.modules and HC.modules.availability or nil;
    if am and am.quest then local ok,v=pcall(am.quest,log_id,quest_id,detail); if ok then av=v; end end
    local content_state=content_from_availability(av);
    local reason=type(av)=='table' and tostring(av.reason or '') or '';
    local source=type(av)=='table' and tostring(av.source or '') or '';
    local verified=type(av)=='table' and av.verified==true or false;
    local native_policy=nil;
    local source_trusted=false;
    local source_reason=nil;

    if type(override)=='table' then
        if override.availability then content_state=string.upper(tostring(override.availability)); end
        if override.reason then reason=tostring(override.reason); end
        if override.source then source=tostring(override.source); end
        if override.verified~=nil then verified=override.verified==true; end
        if override.native_policy then native_policy=string.upper(tostring(override.native_policy)); end
    end

    if content_state=='DISABLED' then content_state='UNAVAILABLE'; end
    if not CONTENT_STATES[content_state] then content_state='UNVERIFIED'; end

    source_trusted,source_reason=trusted_source(detail);
    if not native_policy then
        local h=type(detail.horizon)=='table' and detail.horizon or nil;
        if content_state=='UNAVAILABLE' or content_state=='FUTURE' or (h and h.enabled==false) then
            native_policy='BLOCK';
        elseif type(override)=='table' and type(override.collision)=='table' then
            native_policy='QUARANTINE';
        elseif h and h.enabled==true and h.verified==true and source_trusted then
            native_policy='ALLOW';
        else
            native_policy='QUARANTINE';
        end
    end
    if not NATIVE_POLICIES[native_policy] then native_policy='QUARANTINE'; end

    if reason=='' then
        if native_policy=='ALLOW' then reason='HorizonXI availability and native mapping are verified.';
        elseif native_policy=='BLOCK' then reason='Content is unavailable/future and native bits are blocked.';
        else reason='Native quest mapping is not sufficiently verified; corroborating capture evidence is required.'; end
    end
    if source=='' then source=(type(detail.horizon)=='table' and tostring(detail.horizon.source or '')) or 'canonical registry'; end

    local rec={
        kind='quest',key=key,log_id=tonumber(log_id),quest_id=tonumber(quest_id),
        name=tostring((override and override.name) or detail.name or ''),
        content_state=content_state,native_policy=native_policy,reason=reason,source=source,
        verified=verified,source_trusted=source_trusted,source_reason=source_reason,
        collision=type(override)=='table' and override.collision or nil,
        detail=detail,override=override,
    };
    quest_cache[key]=rec;
    return rec;
end

function M.mission(series_id,number,meta)
    local mkey=lower(series_id)..':'..tostring(tonumber(number) or number);
    local cached=mission_cache[mkey];
    if cached~=nil then return cached; end
    local av=HC and HC.modules and HC.modules.availability or nil;
    local a=nil; if av and av.mission then local ok,v=pcall(av.mission,series_id,number,meta); if ok then a=v; end end
    local content_state=content_from_availability(a);
    local native_policy=(content_state=='FUTURE' or content_state=='UNAVAILABLE' or content_state=='DISABLED') and 'BLOCK' or 'ALLOW';
    local rec={
        kind='mission',key=mkey,series_id=lower(series_id),number=tonumber(number),
        name=type(meta)=='table' and tostring(meta.name or '') or '',
        content_state=content_state,native_policy=native_policy,
        verified=type(a)=='table' and a.verified==true or false,
        reason=type(a)=='table' and tostring(a.reason or '') or '',source=type(a)=='table' and tostring(a.source or '') or 'mission catalog',meta=meta,
    };
    mission_cache[mkey]=rec;
    return rec;
end

function M.native_policy(log_id,quest_id,detail)
    local r=M.quest(log_id,quest_id,detail);
    return r.native_policy,r.reason,r;
end

function M.native_allowed(log_id,quest_id,detail)
    local policy,reason,r=M.native_policy(log_id,quest_id,detail);
    if policy=='ALLOW' then return true,reason,r; end
    if policy=='BLOCK' then return false,reason,r; end
    return nil,reason,r;
end

function M.is_actionable(v)
    local s=type(v)=='table' and tostring(v.content_state or v.state or '') or tostring(v or '');
    s=string.upper(s);
    return s~='UNAVAILABLE' and s~='FUTURE' and s~='DISABLED';
end

local function build_snapshot()
    local out={at=os.time(),records={},missions={},unlocks={},counts={content={},native={}},collisions={},quarantined={},duplicate_names={}};
    local names={};
    local q=HC and HC.modules and HC.modules.quests or nil;
    if q and q.catalog_entries then
        local ok,rows=pcall(q.catalog_entries);
        if ok then
            for _,e in ipairs(rows or {}) do
                local r=M.quest(e.log_id,e.quest_id,e.detail);
                if r.name=='' then r.name=tostring(e.name or r.key); end
                out.records[r.key]=r;
                out.counts.content[r.content_state]=(out.counts.content[r.content_state] or 0)+1;
                out.counts.native[r.native_policy]=(out.counts.native[r.native_policy] or 0)+1;
                if r.collision then out.collisions[#out.collisions+1]=r; end
                if r.native_policy=='QUARANTINE' then out.quarantined[#out.quarantined+1]=r; end
                local nn=normalize_name(r.name); if nn~='' then names[nn]=names[nn] or {}; names[nn][#names[nn]+1]=r; end
            end
        end
    end
    for name,rows in pairs(names) do
        if #rows>1 then out.duplicate_names[#out.duplicate_names+1]={name=name,rows=rows}; end
    end
    table.sort(out.collisions,function(a,b) return lower(a.name)<lower(b.name); end);
    table.sort(out.quarantined,function(a,b) return lower(a.name)<lower(b.name); end);
    table.sort(out.duplicate_names,function(a,b) return a.name<b.name; end);

    local missions=HC and HC.modules and HC.modules.missions or nil;
    local c=HC and HC.modules and HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char() or nil;
    if missions and missions.catalog_entries then
        local ok,rows=pcall(missions.catalog_entries,c);
        if ok then for _,e in ipairs(rows or {}) do out.missions[#out.missions+1]=M.mission(e.series_id,e.number,e); end end
    end

    local unlocks=HC and HC.modules and HC.modules.unlocks or nil;
    if unlocks and unlocks.definitions then
        local ok,defs=pcall(unlocks.definitions);
        if ok then
            for _,d in ipairs(defs or {}) do
                out.unlocks[#out.unlocks+1]={kind='unlock',key=tostring(d.key or d.id),name=tostring(d.name or ''),id=d.id,category=d.category,content_state='AVAILABLE',native_policy='ALLOW',verified=true,source='permanent unlock registry'};
            end
        end
    end
    return out;
end

function M.snapshot(force)
    if not force and cache.snapshot then return cache.snapshot; end
    if force then quest_cache={}; mission_cache={}; end
    local now=os.time();
    cache={at=now,snapshot=build_snapshot()}; return cache.snapshot;
end

function M.invalidate()
    cache={at=0,snapshot=nil};
    quest_cache={};
    mission_cache={};
end
function M.collisions(force) return M.snapshot(force).collisions or {}; end
function M.quarantined(force) return M.snapshot(force).quarantined or {}; end

function M.draw()
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local s=M.snapshot(false); local cc=s.counts.content or {}; local nc=s.counts.native or {};
    imgui.Text('HorizonXI Canonical Content Registry');
    imgui.TextDisabled('Server-specific availability and native-ID authority override retail/native assumptions before quest state reaches the Planner.');
    imgui.Text(string.format('Quest content: %d available | %d unavailable | %d future | %d unverified',
        tonumber(cc.AVAILABLE) or 0,tonumber(cc.UNAVAILABLE) or 0,tonumber(cc.FUTURE) or 0,tonumber(cc.UNVERIFIED) or 0));
    imgui.Text(string.format('Native mappings: %d allowed | %d quarantined | %d blocked',
        tonumber(nc.ALLOW) or 0,tonumber(nc.QUARANTINE) or 0,tonumber(nc.BLOCK) or 0));
    imgui.TextDisabled('A quarantined bit is retained as raw evidence but cannot independently mark a quest ACTIVE or COMPLETE.');
    if imgui.Button('Rebuild Canonical Registry##hc_canonical_refresh') then M.snapshot(true); end
    if #(s.collisions or {})>0 then
        imgui.Text('Explicit collision / mismatch protections');
        for _,r in ipairs(s.collisions) do imgui.TextWrapped(string.format('%s [%s] - %s',r.name,r.key,r.reason)); end
    end
    if #(s.quarantined or {})>0 then
        imgui.TextDisabled('Top native mappings needing verification:');
        for i=1,math.min(12,#s.quarantined) do
            local r=s.quarantined[i]; imgui.TextDisabled(string.format('%s [%s] - %s',r.name,r.key,r.source_reason or r.reason));
        end
        if #s.quarantined>12 then imgui.TextDisabled('+'..tostring(#s.quarantined-12)..' more quarantined mapping(s)'); end
    end
end

function M.status()
    local s=M.snapshot(false); return {at=s.at,counts=s.counts,collisions=#(s.collisions or {}),quarantined=#(s.quarantined or {}),duplicates=#(s.duplicate_names or {})};
end

function M.command(w)
    local sub=lower(w[2]); if sub~='canonical' and sub~='contentregistry' and sub~='collisions' then return false; end
    local s=M.snapshot(true); local nc=s.counts.native or {};
    HC.msg(string.format('Canonical registry: %d allowed | %d quarantined | %d blocked | %d explicit collision(s).',tonumber(nc.ALLOW) or 0,tonumber(nc.QUARANTINE) or 0,tonumber(nc.BLOCK) or 0,#(s.collisions or {})));
    return true;
end

function M.init(ctx) HC=ctx; load_rules(); end
return M;
