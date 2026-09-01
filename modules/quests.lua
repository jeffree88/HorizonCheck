local M = {};
local HC;

local function user_file(kind,name)
    if HC and HC.modules and HC.modules.userdata and HC.modules.userdata.path then
        local ok,res=pcall(HC.modules.userdata.path,kind,name);
        if ok and type(res)=='string' and res~='' then return res; end
    end
    return tostring(HC and HC.addon_path or '')..tostring(name or '');
end

local hydrated_character=nil;

-- Native FFXI active quest log state (packet 0x056).
-- Each packet contains 256 active-quest bits followed by a 16-bit offer port
-- that identifies the quest log/region. This is authoritative for ACTIVE
-- quests; completed quest history is a separate problem and is not inferred.
local current = {};       -- [log_id] = 32-byte ACTIVE bitmap payload
local completed = {};     -- [log_id] = 32-byte COMPLETED bitmap payload
local raw_056 = {};       -- [port/type] = {bitmap=..., seen=..., count=...}
local native_seen = {};   -- [log_id] = os.time()
local capture = nil;
local VERIFY_PACKETS = 1;
local listeners = {}; -- callbacks(log_id, previous_bitmap, current_bitmap)
local completed_listeners = {}; -- callbacks(log_id, previous_bitmap, current_bitmap)
local progression_overview_cache={at=0,char=nil,data=nil};
local canonical_policy_cache={};
local PROGRESSION_OVERVIEW_CACHE_SECONDS=10;
local dependency_index_cache=nil;
local quest_active; -- forward declaration used by requirement helpers defined before the decoder section

local function invalidate_progression_overview()
    progression_overview_cache={at=0,char=nil,data=nil};
end

local function request_state_save(delay)
    local st=HC and HC.modules and HC.modules.state or nil;
    if not st then return; end
    if st.request_save then st.request_save(delay or 1); elseif st.save then st.save(); end
end

local LOG_NAMES = {
    [0] = "San d'Oria",
    [1] = 'Bastok',
    [2] = 'Windurst',
    [3] = 'Jeuno',
    [4] = 'Other Areas',
    [5] = 'Outlands',
    [6] = 'Aht Urhgan',
    [7] = 'Crystal War',
    [8] = 'Abyssea',
    [9] = 'Adoulin',
    [10] = 'Coalition',
};


local QUEST_MAP_FILES = {
    [0] = 'sandoria',
    [1] = 'bastok',
    [2] = 'windurst',
    [3] = 'jeuno',
    [4] = 'other',
    [5] = 'outlands',
    [6] = 'toau',
    [7] = 'crystal_war',
    [8] = 'abyssea',
    [9] = 'adoulin',
    [10] = 'coalition',
};

local quest_names = {};
local quest_metadata = {};
local function load_quest_metadata()
    if next(quest_metadata)~=nil or HC==nil then return quest_metadata; end
    local path=HC.addon_path..'data\\quest_metadata.lua';
    local ok,t=pcall(dofile,path);
    if ok and type(t)=='table' then quest_metadata=t; else quest_metadata={}; end
    -- Optional bulk overlay for large catalog imports. It only enriches metadata;
    -- native 0x056 Active/Completed state remains authoritative.
    local bulk_path=HC.addon_path..'data\\quest_metadata_bulk.lua';
    local bok,bulk=pcall(dofile,bulk_path);
    if bok and type(bulk)=='table' then
        -- Bulk metadata is an enrichment layer, not a replacement layer.
        -- Older builds replaced the whole base record here, which could erase
        -- verified NPC/zone/expansion/next-step fields when a bulk row only
        -- supplied reward/keywords. Merge fields instead, and merge nested
        -- requirements independently so the base catalog remains a fallback.
        for k,v in pairs(bulk) do
            if type(k)=='string' and type(v)=='table' then
                local dst=quest_metadata[k];
                if type(dst)~='table' then dst={}; quest_metadata[k]=dst; end
                for field,value in pairs(v) do
                    if field=='requirements' and type(value)=='table' then
                        if type(dst.requirements)~='table' then dst.requirements={}; end
                        for rk,rv in pairs(value) do dst.requirements[rk]=rv; end
                    elseif field=='requirements_mapped' then
                        -- Never let a sparse bulk row downgrade a previously
                        -- structured mapping. A true value may promote it.
                        if value==true or dst.requirements_mapped~=true then
                            dst.requirements_mapped=value;
                        end
                    else
                        dst[field]=value;
                    end
                end
            end
        end
    elseif not bok and HC and HC.msg then
        HC.msg('Quest catalog warning: failed to load quest_metadata_bulk.lua: '..tostring(bulk));
    end

    -- Generated catalog overlay. Unlike the legacy bulk file, this merges fields
    -- conservatively so historical/reference imports fill gaps without erasing
    -- already verified Horizon metadata. Explicit manual_override fields emitted
    -- by the catalog builder are allowed to replace existing values.
    local generated_path=HC.addon_path..'data\\quest_metadata_generated.lua';
    local gok,generated=pcall(dofile,generated_path);
    if not gok and HC and HC.msg then
        HC.msg('Quest catalog warning: failed to load quest_metadata_generated.lua: '..tostring(generated));
    end
    if gok and type(generated)=='table' then
        local function list_has(t,value)
            if type(t)~='table' then return false; end
            for _,v in ipairs(t) do if v==value then return true; end end
            return false;
        end
        for k,v in pairs(generated) do
            if type(k)=='string' and type(v)=='table' then
                local dst=quest_metadata[k];
                if type(dst)~='table' then dst={}; quest_metadata[k]=dst; end
                for field,value in pairs(v) do
                    if field=='requirements' and type(value)=='table' then
                        if type(dst.requirements)~='table' then dst.requirements={}; end
                        for rk,rv in pairs(value) do
                            if dst.requirements[rk]==nil or list_has(v.catalog_override_requirements,rk) then
                                dst.requirements[rk]=rv;
                            end
                        end
                    elseif field=='requirements_mapped' and value==true then
                        -- A generated record with mapped requirements may promote a
                        -- legacy false/unknown flag once concrete requirement fields exist.
                        dst.requirements_mapped=true;
                    elseif field~='catalog_override_fields' and field~='catalog_override_requirements' then
                        if dst[field]==nil or dst[field]=='' or list_has(v.catalog_override_fields,field) then
                            dst[field]=value;
                        end
                    end
                end
            end
        end
    end
    -- Horizon-era scope/enrichment overlay. This final layer can explicitly
    -- disable out-of-era native DAT entries and apply reviewed large-pass fields.
    local scope_path=HC.addon_path..'data\\quest_metadata_scope.lua';
    local sok,scope=pcall(dofile,scope_path);
    if sok and type(scope)=='table' then
        for k,v in pairs(scope) do
            if type(k)=='string' and type(v)=='table' then
                local dst=quest_metadata[k];
                if type(dst)~='table' then dst={}; quest_metadata[k]=dst; end
                for field,value in pairs(v) do
                    if field=='requirements' and type(value)=='table' then
                        if type(dst.requirements)~='table' then dst.requirements={}; end
                        for rk,rv in pairs(value) do dst.requirements[rk]=rv; end
                    else
                        dst[field]=value;
                    end
                end
            end
        end
    elseif not sok and HC and HC.msg then
        HC.msg('Quest catalog warning: failed to load quest_metadata_scope.lua: '..tostring(scope));
    end


    local completion_path=HC.addon_path..'data\\quest_metadata_completion.lua';
    local cok,completion=pcall(dofile,completion_path);
    if cok and type(completion)=='table' then
        for k,v in pairs(completion) do
            if type(k)=='string' and type(v)=='table' then
                local dst=quest_metadata[k];
                if type(dst)~='table' then dst={}; quest_metadata[k]=dst; end
                for field,value in pairs(v) do
                    if field=='requirements' and type(value)=='table' then
                        if type(dst.requirements)~='table' then dst.requirements={}; end
                        for rk,rv in pairs(value) do dst.requirements[rk]=rv; end
                    else
                        dst[field]=value;
                    end
                end
            end
        end
    elseif not cok and HC and HC.msg then
        HC.msg('Quest catalog warning: failed to load quest_metadata_completion.lua: '..tostring(completion));
    end


    local completion2_path=HC.addon_path..'data\\quest_metadata_completion2.lua';
    local c2ok,completion2=pcall(dofile,completion2_path);
    if c2ok and type(completion2)=='table' then
        for k,v in pairs(completion2) do
            if type(k)=='string' and type(v)=='table' then
                local dst=quest_metadata[k];
                if type(dst)~='table' then dst={}; quest_metadata[k]=dst; end
                for field,value in pairs(v) do
                    if field=='requirements' and type(value)=='table' then
                        if type(dst.requirements)~='table' then dst.requirements={}; end
                        for rk,rv in pairs(value) do dst.requirements[rk]=rv; end
                    else
                        dst[field]=value;
                    end
                end
            end
        end
    elseif not c2ok and HC and HC.msg then
        HC.msg('Quest catalog warning: failed to load quest_metadata_completion2.lua: '..tostring(completion2));
    end

    local completion3_path=HC.addon_path..'data\\quest_metadata_completion3.lua';
    local c3ok,completion3=pcall(dofile,completion3_path);
    if c3ok and type(completion3)=='table' then
        for k,v in pairs(completion3) do
            if type(k)=='string' and type(v)=='table' then
                local dst=quest_metadata[k];
                if type(dst)~='table' then dst={}; quest_metadata[k]=dst; end
                for field,value in pairs(v) do
                    if field=='requirements' and type(value)=='table' then
                        if type(dst.requirements)~='table' then dst.requirements={}; end
                        for rk,rv in pairs(value) do dst.requirements[rk]=rv; end
                    elseif field=='requirements_mapped' then
                        -- Never downgrade an already verified mapping from an earlier overlay.
                        if dst.requirements_mapped~=true then dst.requirements_mapped=value; end
                    else
                        dst[field]=value;
                    end
                end
            end
        end
    elseif not c3ok and HC and HC.msg then
        HC.msg('Quest catalog warning: failed to load quest_metadata_completion3.lua: '..tostring(completion3));
    end

    local completion4_path=HC.addon_path..'data\\quest_metadata_completion4.lua';
    local c4ok,completion4=pcall(dofile,completion4_path);
    if c4ok and type(completion4)=='table' then
        for k,v in pairs(completion4) do
            if type(k)=='string' and type(v)=='table' then
                local dst=quest_metadata[k];
                if type(dst)~='table' then dst={}; quest_metadata[k]=dst; end
                for field,value in pairs(v) do
                    if field=='requirements' and type(value)=='table' then
                        if type(dst.requirements)~='table' then dst.requirements={}; end
                        for rk,rv in pairs(value) do dst.requirements[rk]=rv; end
                    else
                        dst[field]=value;
                    end
                end
            end
        end
    elseif not c4ok and HC and HC.msg then
        HC.msg('Quest catalog warning: failed to load quest_metadata_completion4.lua: '..tostring(completion4));
    end


    local quality_path=HC.addon_path..'data\\quest_metadata_quality.lua';
    local qok,quality=pcall(dofile,quality_path);
    if qok and type(quality)=='table' then
        for k,v in pairs(quality) do
            if type(k)=='string' and type(v)=='table' then
                local dst=quest_metadata[k];
                if type(dst)~='table' then dst={}; quest_metadata[k]=dst; end
                for field,value in pairs(v) do
                    if field=='requirements' and type(value)=='table' then
                        if type(dst.requirements)~='table' then dst.requirements={}; end
                        for rk,rv in pairs(value) do dst.requirements[rk]=rv; end
                    else
                        dst[field]=value;
                    end
                end
            end
        end
    elseif not qok and HC and HC.msg then
        HC.msg('Quest catalog warning: failed to load quest_metadata_quality.lua: '..tostring(quality));
    end


    local verify_path=HC.addon_path..'data\\quest_metadata_verify.lua';
    local vok,verify=pcall(dofile,verify_path);
    if vok and type(verify)=='table' then
        for k,v in pairs(verify) do
            if type(k)=='string' and type(v)=='table' then
                local dst=quest_metadata[k];
                if type(dst)~='table' then dst={}; quest_metadata[k]=dst; end
                for field,value in pairs(v) do
                    if field=='requirements' and type(value)=='table' then
                        if type(dst.requirements)~='table' then dst.requirements={}; end
                        for rk,rv in pairs(value) do dst.requirements[rk]=rv; end
                    else
                        dst[field]=value;
                    end
                end
            end
        end
    elseif not vok and HC and HC.msg then
        HC.msg('Quest catalog warning: failed to load quest_metadata_verify.lua: '..tostring(verify));
    end


    -- Structured CHECK REQS automation overlay.
    local checkreqs_path=HC.addon_path..'data\\quest_metadata_checkreqs.lua';
    local crok,checkreqs=pcall(dofile,checkreqs_path);
    if crok and type(checkreqs)=='table' then
        for k,v in pairs(checkreqs) do
            if type(k)=='string' and type(v)=='table' then
                local dst=quest_metadata[k];
                if type(dst)~='table' then dst={}; quest_metadata[k]=dst; end
                for field,value in pairs(v) do
                    if field=='requirements' and type(value)=='table' then
                        -- CHECKREQS is the authoritative prerequisite layer. Replace
                        -- legacy requirement tables so stale Manual prerequisite
                        -- strings cannot survive beneath a newer structured mapping.
                        dst.requirements=value;
                    elseif field=='requirements_mapped' then
                        if value==true then dst.requirements_mapped=true; end
                    else
                        dst[field]=value;
                    end
                end
            end
        end
    elseif not crok and HC and HC.msg then
        HC.msg('Quest catalog warning: failed to load quest_metadata_checkreqs.lua: '..tostring(checkreqs));
    end

    return quest_metadata;
end

local function metadata_for(log_id,quest_id)
    local t=load_quest_metadata();
    return t[tostring(log_id)..':'..tostring(quest_id)];
end

local function canonical_native_policy(log_id,quest_id)
    local key=tostring(tonumber(log_id) or log_id)..':'..tostring(tonumber(quest_id) or quest_id);
    local cached=canonical_policy_cache[key];
    if cached then return cached.policy,cached.reason,cached.record; end

    local policy,reason,record=nil,nil,nil;
    local meta=metadata_for(log_id,quest_id);
    local cm=HC and HC.modules and HC.modules.canonical or nil;
    if cm and cm.native_policy then
        local ok,p,r,rec=pcall(cm.native_policy,log_id,quest_id,meta);
        if ok and p then policy=tostring(p); reason=r; record=rec; end
    end
    if not policy then
        local h=type(meta)=='table' and type(meta.horizon)=='table' and meta.horizon or nil;
        if h and h.enabled==false then
            policy='BLOCK'; reason='Not currently available on HorizonXI';
        elseif h and h.enabled==true and h.verified==true then
            policy='ALLOW'; reason='Verified HorizonXI catalog fallback';
        else
            policy='QUARANTINE'; reason='Canonical authority unavailable and native mapping is not verified';
        end
    end
    cached={policy=policy,reason=reason,record=record};
    canonical_policy_cache[key]=cached;
    return cached.policy,cached.reason,cached.record;
end

local function quest_catalog_disabled(log_id,quest_id,policy)
    if policy==nil then policy=canonical_native_policy(log_id,quest_id); end
    if policy=='BLOCK' then return true; end
    local meta=metadata_for(log_id,quest_id);
    return type(meta)=='table' and type(meta.horizon)=='table' and meta.horizon.enabled==false;
end
local function load_quest_names(log_id)
    if quest_names[log_id] ~= nil then return quest_names[log_id]; end
    local stem=QUEST_MAP_FILES[log_id];
    if stem==nil or HC==nil then quest_names[log_id]={}; return quest_names[log_id]; end
    local path=HC.addon_path..'modules\\questmaps\\'..stem..'.lua';
    local ok,t=pcall(dofile,path);
    quest_names[log_id]=(ok and type(t)=='table') and t or {};
    return quest_names[log_id];
end

local function quest_name(log_id,quest_id)
    local t=load_quest_names(tonumber(log_id));
    local name=t and t[tonumber(quest_id)] or nil;
    if type(name)=='string' and name~='' then return name; end
    return 'Quest ID '..tostring(quest_id);
end

local function catalog_ids(log_id)
    local t=load_quest_names(tonumber(log_id));
    local out={};
    for qid,name in pairs(t or {}) do
        qid=tonumber(qid);
        if qid and qid>=0 and qid<=255 and type(name)=='string' and name~='' then
            local det=metadata_for(log_id,qid);
            if not (type(det)=='table' and type(det.horizon)=='table' and det.horizon.enabled==false) then
                out[#out+1]=qid;
            end
        end
    end
    table.sort(out);
    return out;
end

-- Availability is intentionally conservative. Metadata lives in data/quest_metadata.lua.
-- Only requirements HorizonCheck can verify are allowed to produce AVAILABLE/LOCKED;
-- anything else remains UNKNOWN instead of being guessed.
local function historical_rank(c,nation)
    if type(c)~='table' or type(c.mission_meta)~='table' or type(c.mission_meta.nation_ranks)~='table' then return nil; end
    return tonumber(c.mission_meta.nation_ranks[tostring(nation or '')]);
end

local function current_main_job_level()
    local level=nil;
    pcall(function()
        if not AshitaCore or not AshitaCore.GetMemoryManager then return; end
        local mm=AshitaCore:GetMemoryManager();
        if not mm or not mm.GetPlayer then return; end
        local player=mm:GetPlayer();
        if not player then return; end
        if player.GetMainJobLevel then
            level=tonumber(player:GetMainJobLevel());
        elseif player.GetLevel then
            level=tonumber(player:GetLevel());
        end
    end);
    return level;
end

local function manual_fame_level(c,log_id)
    if type(c)~='table' or type(c.quest_fame_overrides)~='table' then return nil; end
    local v=tonumber(c.quest_fame_overrides[tostring(log_id)]);
    if v==nil then return nil; end
    return math.max(1,math.min(9,math.floor(v)));
end

local function manual_requirement_state(c,log_id,quest_id)
    if type(c)~='table' or type(c.quest_manual_requirements)~='table' then return nil; end
    -- Do not call quest_key() here: this helper is declared before the local
    -- quest_key function, so Lua would otherwise resolve quest_key as a global
    -- and reload/runtime evaluation can fail with "attempt to call global
    -- 'quest_key' (a nil value)".
    local key=tostring(log_id)..':'..tostring(quest_id);
    local v=c.quest_manual_requirements[key];
    if type(v)=='table' and v.satisfied==true then return v; end
    return nil;
end

local function manual_reputation_level(c,name)
    if type(c)~='table' or type(c.quest_reputation_overrides)~='table' then return nil; end

    -- Reputation keys appear in catalog data in several equivalent spellings
    -- (for example selbina/rabao, selbina_rabao, Rabao, or Selbina).
    -- Fame dialogue capture stores the canonical key, so normalize both sides
    -- before comparing.  Without this, a confirmed Waylea profile could remain
    -- CHECK REQUIREMENTS simply because the quest used a slash in its key.
    local function norm(v)
        local key=string.lower(tostring(v or ''));
        key=key:gsub('%s+','_'):gsub('/','_'):gsub('%-','_');
        key=key:gsub('_+','_');
        if key=='norg' or key=='norg_tenshodo' then return 'tenshodo'; end
        if key=='selbina' or key=='rabao' or key=='rabao_selbina' then return 'selbina_rabao'; end
        return key;
    end

    local want=norm(name);
    for k,v in pairs(c.quest_reputation_overrides) do
        if norm(k)==want then
            local n=tonumber(v);
            if n~=nil then return math.max(1,math.min(9,math.floor(n))); end
        end
    end
    return nil;
end

local inferred_city_fame_cache={at=0,values={}};

local function inferred_city_fame_floor(log_id)
    log_id=tonumber(log_id);
    if log_id==nil or log_id<0 or log_id>3 then return nil; end

    local now=os.time();
    if inferred_city_fame_cache.at~=now then
        inferred_city_fame_cache.at=now;
        inferred_city_fame_cache.values={};
    end
    if inferred_city_fame_cache.values[log_id]~=nil then
        return inferred_city_fame_cache.values[log_id];
    end

    local floor=1;
    for _,qid in ipairs(catalog_ids(log_id)) do
        local det=metadata_for(log_id,qid);
        local req=(type(det)=='table' and type(det.requirements)=='table') and det.requirements or nil;
        local fame=req and tonumber(req.fame) or nil;
        if fame and fame>floor then
            -- Use completed history only here. quest_active() is declared later in
            -- this module; referencing that local from this earlier helper would
            -- resolve as a global and can fail during reload. Completed history is
            -- authoritative and sufficient for a conservative fame lower bound.
            local proven=(M.is_completed and M.is_completed(log_id,qid)==true);
            if proven then floor=fame; end
        end
    end
    inferred_city_fame_cache.values[log_id]=floor;
    return floor;
end


local function normalize_reputation_key(name)
    local key=string.lower(tostring(name or ''));
    key=key:gsub('%s+','_'):gsub('/','_'):gsub('%-','_');
    key=key:gsub('_+','_');
    if key=='norg' or key=='norg_tenshodo' then return 'tenshodo'; end
    if key=='selbina' or key=='rabao' or key=='rabao_selbina' then return 'selbina_rabao'; end
    return key;
end

local function manual_reputation_level_any(c,name)
    if type(c)~='table' or type(c.quest_reputation_overrides)~='table' then return nil; end
    local want=normalize_reputation_key(name);
    for k,v in pairs(c.quest_reputation_overrides) do
        if normalize_reputation_key(k)==want then
            local n=tonumber(v);
            if n then return math.max(1,math.min(9,math.floor(n))); end
        end
    end
    return nil;
end

-- Some older catalog rows encode an unknown-threshold fame gate as a manual
-- flag (for example, "Jeuno reputation requirement met").  If the relevant
-- fame checker dialogue has already been captured for this character, treat
-- that specific manual reputation flag as runtime-confirmed so the quest can
-- consume the same Skills / Fame profile instead of asking for a duplicate
-- checkbox confirmation.
local function auto_reputation_manual_flag(c,key,label)
    local k=string.lower(tostring(key or ''));
    local l=string.lower(tostring(label or ''));
    if k:find('jeuno_reputation',1,true) or l:find('jeuno reputation',1,true) then
        local v=manual_fame_level(c,3);
        return v~=nil,v,'Jeuno';
    end
    if k:find('windurst_reputation',1,true) or k:find('kazham_reputation',1,true) or k:find('mhaura_reputation',1,true)
        or l:find('windurst reputation',1,true) or l:find('kazham reputation',1,true) or l:find('mhaura reputation',1,true) then
        local v=manual_fame_level(c,2);
        return v~=nil,v,'Windurst / Mhaura / Kazham';
    end
    if k:find('bastok_reputation',1,true) or l:find('bastok reputation',1,true) then
        local v=manual_fame_level(c,1);
        return v~=nil,v,'Bastok';
    end
    if k:find('sandoria_reputation',1,true) or k:find('san_doria_reputation',1,true) or l:find("san d'oria reputation",1,true) then
        local v=manual_fame_level(c,0);
        return v~=nil,v,"San d'Oria";
    end
    if k:find('selbina_rabao_reputation',1,true) or l:find('selbina/rabao reputation',1,true) then
        local v=manual_reputation_level_any(c,'selbina_rabao');
        return v~=nil,v,'Selbina / Rabao';
    end
    if k:find('norg_reputation',1,true) or k:find('tenshodo_reputation',1,true) or l:find('norg reputation',1,true) or l:find('tenshodo reputation',1,true) then
        local v=manual_reputation_level_any(c,'tenshodo');
        return v~=nil,v,'Norg / Tenshodo';
    end
    return false,nil,nil;
end

-- Resolve legacy/generic `fame = N` requirements for regional Outlands quests
-- to the actual HorizonXI fame profile used by the quest's starting area.
-- This keeps older catalog rows useful without requiring every row to be
-- rewritten immediately.  City logs still use their native city-fame profile.
local function contextual_fame_profile(det,log_id)
    local zone=string.lower(tostring(type(det)=='table' and det.start_zone or ''));
    if zone:find('norg',1,true) then
        return 'reputation','tenshodo','Norg / Tenshodo';
    end
    if zone:find('rabao',1,true) or zone:find('selbina',1,true) then
        return 'reputation','selbina_rabao','Selbina / Rabao';
    end
    if zone:find('kazham',1,true) or zone:find('mhaura',1,true) then
        return 'city',2,'Windurst / Mhaura / Kazham';
    end
    local lid=tonumber(log_id);
    if lid~=nil and lid>=0 and lid<=3 then
        return 'city',lid,nil;
    end
    return nil,nil,nil;
end

local function inferred_named_reputation_floor(name)
    local want=normalize_reputation_key(name);
    local floor=nil;
    for log=0,6 do
        for _,qid in ipairs(catalog_ids(log)) do
            if M.is_completed and M.is_completed(log,qid)==true then
                local det=metadata_for(log,qid);
                local req=(type(det)=='table' and type(det.requirements)=='table') and det.requirements or nil;
                if req and req.reputation~=nil and normalize_reputation_key(req.reputation)==want then
                    local n=tonumber(req.reputation_level);
                    if n and (floor==nil or n>floor) then floor=n; end
                end
            end
        end
    end
    return floor;
end

function M.fame_snapshot(c)
    c=type(c)=='table' and c or {};
    local rows={};
    local function city(log_id,label,reporter,location,aliases)
        local manual=manual_fame_level(c,log_id);
        local inferred=inferred_city_fame_floor(log_id) or 1;
        local level=manual or inferred;
        rows[#rows+1]={label=label,level=level,confirmed=(manual~=nil),inferred=(manual==nil),reporter=reporter,location=location,aliases=aliases};
    end
    city(0,"San d'Oria",'Namonutice',"Southern San d'Oria (K-6)",'');
    city(1,'Bastok','Flaco','Port Bastok (E-6)','');
    city(2,'Windurst / Mhaura / Kazham','Zabirego-Hajigo / Ney Hiparujah','Windurst Waters (F-10) / Kazham (I-11)','Mhaura and Kazham share Windurst fame');
    city(3,'Jeuno','Mendi','Lower Jeuno (H-8)','');

    local sr_manual=manual_reputation_level_any(c,'selbina_rabao');
    local sr_inf=inferred_named_reputation_floor('selbina_rabao');
    rows[#rows+1]={label='Selbina / Rabao',level=sr_manual or sr_inf,confirmed=(sr_manual~=nil),inferred=(sr_manual==nil and sr_inf~=nil),reporter='Waylea',location='Rabao (G-9)',aliases='Selbina and Rabao share one reputation value'};

    local t_manual=manual_reputation_level_any(c,'tenshodo');
    local t_inf=inferred_named_reputation_floor('tenshodo');
    rows[#rows+1]={label='Norg / Tenshodo',level=t_manual or t_inf,confirmed=(t_manual~=nil),inferred=(t_manual==nil and t_inf~=nil),reporter='Vaultimand',location='Norg (H-8)',aliases='Separate Tenshodo reputation'};
    return rows;
end

local function manual_weapon_skill_level(c,name)
    -- Prefer the live in-game Combat Skills value when available.
    if HC and HC.modules and HC.modules.skills and HC.modules.skills.get then
        local ok,res=pcall(HC.modules.skills.get,name);
        if ok and type(res)=='table' and tonumber(res.value)~=nil then
            return math.max(0,math.floor(tonumber(res.value)));
        end
    end
    -- Keep the existing per-character manual profile as a fallback for clients
    -- where the combat-skill memory API is not yet available.
    if type(c)~='table' or type(c.quest_weapon_skill_overrides)~='table' then return nil; end
    local key=string.lower(tostring(name or ''));
    local v=tonumber(c.quest_weapon_skill_overrides[key]);
    if v==nil then return nil; end
    return math.max(0,math.floor(v));
end

local function manual_craft_skill_level(c,name)
    -- Prefer the same live craft-skill profile displayed on Skills / Fame.
    if HC and HC.modules and HC.modules.skills and HC.modules.skills.get_craft then
        local ok,res=pcall(HC.modules.skills.get_craft,name);
        if ok and type(res)=='table' and tonumber(res.value)~=nil then
            return math.max(0,math.floor(tonumber(res.value)));
        end
    end
    -- Preserve the per-character manual override as a fallback if the client
    -- cannot expose craft skills through the Ashita player API.
    if type(c)~='table' or type(c.quest_craft_skill_overrides)~='table' then return nil; end
    local key=string.lower(tostring(name or ''));
    local v=tonumber(c.quest_craft_skill_overrides[key]);
    if v==nil then return nil; end
    return math.max(0,math.floor(v));
end



local MAAT_JOB_ORDER={'WAR','MNK','WHM','BLM','RDM','THF','PLD','DRK','BST','BRD','RNG','SAM','NIN','DRG','SMN'};
local MAAT_JOB_IDS={WAR=1,MNK=2,WHM=3,BLM=4,RDM=5,THF=6,PLD=7,DRK=8,BST=9,BRD=10,RNG=11,SAM=12,NIN=13,DRG=14,SMN=15};

local function live_job_level(job)
    local id=MAAT_JOB_IDS[string.upper(tostring(job or ''))];
    if not id then return nil; end
    local p=nil;
    pcall(function() p=AshitaCore:GetMemoryManager():GetPlayer(); end);
    if not p or not p.GetJobLevel then return nil; end
    local level=nil;
    pcall(function() level=tonumber(p:GetJobLevel(id)); end);
    if level==nil then return nil; end
    return math.max(0,math.min(75,math.floor(level)));
end


local function manual_maat_job_won(c,job)
    if type(c)~='table' or type(c.quest_maat_job_wins)~='table' then return nil; end
    local key=string.upper(tostring(job or ''));
    if c.quest_maat_job_wins[key]==true then return true; end
    return nil;
end

local function maat_job_progress(c,required)
    local total=0; local done=0; local missing={};
    for _,job in ipairs(required or MAAT_JOB_ORDER) do
        total=total+1;
        if manual_maat_job_won(c,job)==true then
            done=done+1;
        else
            missing[#missing+1]=tostring(job);
        end
    end
    return done,total,missing;
end

local function manual_mercenary_points(c)
    if type(c)~='table' then return nil; end
    local v=tonumber(c.quest_mercenary_rank_points);
    if v==nil then return nil; end
    return math.max(0,math.min(25,math.floor(v)));
end

local MERCENARY_RANKS={
    'Private Second Class','Private First Class','Superior Private','Lance Corporal','Corporal',
    'Sergeant','Sergeant Major','Chief Sergeant','Second Lieutenant','First Lieutenant','Captain',
};
local MERCENARY_RANK_INDEX={};
for i,name in ipairs(MERCENARY_RANKS) do
    MERCENARY_RANK_INDEX[string.lower(name)]=i;
end

local function mercenary_rank_index(value)
    if type(value)=='number' then return math.max(1,math.min(#MERCENARY_RANKS,math.floor(value))); end
    return MERCENARY_RANK_INDEX[string.lower(tostring(value or ''))];
end

local function manual_mercenary_rank(c)
    if type(c)~='table' then return nil,nil; end
    local idx=mercenary_rank_index(c.quest_mercenary_rank_index);
    if not idx then return nil,nil; end
    return idx,MERCENARY_RANKS[idx];
end

local AVATAR_UNLOCK_ORDER={'Ifrit','Titan','Leviathan','Garuda','Shiva','Ramuh'};

local function manual_avatar_unlocked(c,name)
    if type(c)~='table' or type(c.quest_avatar_unlocks)~='table' then return nil; end
    local key=string.lower(tostring(name or ''));
    return c.quest_avatar_unlocks[key]==true and true or nil;
end

local function avatar_unlock_progress(c,required)
    local done,total,missing=0,0,{};
    for _,name in ipairs(required or AVATAR_UNLOCK_ORDER) do
        total=total+1;
        if manual_avatar_unlocked(c,name)==true then done=done+1 else missing[#missing+1]=tostring(name); end
    end
    return done,total,missing;
end

local function manual_condition_flag(c,key)
    if type(c)~='table' or type(c.quest_condition_flags)~='table' then return nil; end
    local v=c.quest_condition_flags[tostring(key or '')];
    if v==true then return true; end
    if type(v)=='table' and v.satisfied==true then return true; end
    return nil;
end

local function manual_flag_parts(spec)
    if type(spec)=='table' then
        return tostring(spec.key or spec.id or spec.label or ''),tostring(spec.label or spec.key or spec.id or 'Manual condition');
    end
    return tostring(spec or ''),tostring(spec or 'Manual condition');
end


-- v6.82.1: Central resolver for stale manual condition rows.  A manual flag is
-- automatically suppressed only when the same condition is independently
-- proven by live/recorded character evidence or by an equivalent structured
-- prerequisite on this quest.  This deliberately avoids guessing from vague
-- prose-only conditions.
local function auto_manual_flag_state(c,req,det,log_id,key,label)
    req=type(req)=='table' and req or {};
    local k=string.lower(tostring(key or ''));
    local l=string.lower(tostring(label or ''));

    local rep_ok,rep_level,rep_label=auto_reputation_manual_flag(c,key,label);
    if rep_ok then
        return true,string.format('confirmed %s fame %s',tostring(rep_label or 'reputation'),tostring(rep_level or '?')),'CONFIRMED FAME',true;
    end

    -- Duplicate structured fame gates: require a fame/reputation-shaped label
    -- before consuming the numeric structured gate.
    if req.fame~=nil and (l:find('fame',1,true) or l:find('reputation',1,true) or k:find('fame',1,true) or k:find('reputation',1,true)) then
        local need=tonumber(req.fame);
        local kind,pkey,plabel=contextual_fame_profile(det,log_id);
        if req.fame_log_id~=nil then kind='city'; pkey=tonumber(req.fame_log_id); end
        local have=nil; local source='';
        if kind=='reputation' then
            have=manual_reputation_level_any(c,pkey);
            source='confirmed '..tostring(plabel or pkey)..' fame';
        else
            local fl=tonumber(pkey or req.fame_log_id or log_id);
            local mf=(fl and fl>=0 and fl<=3) and manual_fame_level(c,fl) or nil;
            local inf=(fl and fl>=0 and fl<=3) and inferred_city_fame_floor(fl) or nil;
            have=(mf and inf) and math.max(mf,inf) or mf or inf;
            source=mf~=nil and 'confirmed city fame' or 'completed-quest fame floor';
        end
        if need and have and have>=need then return true,string.format('%s %d / need %d',source,have,need),'STRUCTURED FAME',true; end
    end

    if req.fishing_skill~=nil and (l:find('fishing',1,true) or k:find('fishing',1,true)) then
        local need=tonumber(req.fishing_skill); local have=manual_craft_skill_level(c,'Fishing');
        if need and have and have>=need then return true,string.format('Fishing %d / need %d',have,need),'LIVE CRAFT SKILL',false; end
    end

    if req.level~=nil and (l:find('level',1,true) or k:find('level',1,true)) then
        local need=tonumber(req.level); local have=current_main_job_level();
        if need and have and have>=need then return true,string.format('current job level %d / need %d',have,need),'LIVE JOB LEVEL',false; end
    end

    if req.weapon_skill~=nil then
        local sk=string.lower(tostring(req.weapon_skill));
        if l:find(sk,1,true) or k:find(sk:gsub('%s+','_'),1,true) then
            local need=tonumber(req.weapon_skill_level or req.skill_level or req.weapon_skill_min);
            local have=manual_weapon_skill_level(c,req.weapon_skill);
            if need and have and have>=need then return true,string.format('%s %d / need %d',tostring(req.weapon_skill),have,need),'LIVE COMBAT SKILL',false; end
        end
    end

    if req.nation_rank~=nil and (l:find('rank',1,true) or k:find('rank',1,true)) then
        local nation=req.nation or req.nation_id or ({[0]='sandoria',[1]='bastok',[2]='windurst'})[tonumber(log_id)];
        local need=tonumber(req.nation_rank); local have=historical_rank(c,nation);
        if need and have and have>=need then return true,string.format('%s rank %d / need %d',tostring(nation or 'nation'),have,need),'NATION RANK',true; end
    end

    if req.mercenary_points~=nil and (l:find('mercenary',1,true) or k:find('mercenary',1,true)) then
        local need=tonumber(req.mercenary_points); local have=manual_mercenary_points(c);
        if need and have and have>=need then return true,string.format('Mercenary Rank points %d / need %d',have,need),'MERCENARY PROFILE',false; end
    end

    if type(req.quests)=='table' then
        for _,q in ipairs(req.quests) do
            local ql=tonumber(q.log_id or q.log); local qi=tonumber(q.quest_id or q.id);
            if ql and qi and M.is_completed(ql,qi)==true then
                local qn=string.lower(tostring(quest_name(ql,qi) or ''));
                if qn~='' and (l:find(qn,1,true) or k:find(qn:gsub('[^%w]+','_'),1,true)) then
                    return true,'previous quest completed: '..tostring(quest_name(ql,qi)),'NATIVE QUEST HISTORY',true;
                end
            end
        end
    end

    if type(req.key_items)=='table' then
        for _,ki in ipairs(req.key_items) do
            local kin=string.lower(tostring(ki));
            if kin~='' and (l:find(kin,1,true) or k:find(kin:gsub('[^%w]+','_'),1,true)) then
                local owned=nil;
                if HC and HC.modules and HC.modules.keyitems and HC.modules.keyitems.ownership_name then owned=HC.modules.keyitems.ownership_name(tostring(ki)); end
                if owned==true then return true,'key item owned: '..tostring(ki),'LIVE KEY ITEM',false; end
            end
        end
    end
    return false,nil,nil,false;
end

local function current_zone_id()
    local zid=nil;
    pcall(function()
        if HC and HC.modules and HC.modules.automation and HC.modules.automation.get_zone_id then
            zid=tonumber(HC.modules.automation.get_zone_id());
        end
    end);
    return zid;
end


local function current_zone_name()
    local zid=current_zone_id();
    if zid==nil then return nil; end
    local name=nil;
    pcall(function()
        if AshitaCore and AshitaCore.GetResourceManager then
            local rm=AshitaCore:GetResourceManager();
            if rm and rm.GetString then
                name=rm:GetString('zones.names',zid);
                if not name or name=='' then name=rm:GetString('zones',zid); end
            end
        end
    end);
    if type(name)~='string' or name=='' then return nil; end
    return name;
end

local function normalized_zone_name(v)
    local s=string.lower(tostring(v or ''));
    s=s:gsub("[%[%]%(%)'’`%.%-]",' '):gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$','');
    return s;
end

local function quest_starts_in_current_zone(det)
    if type(det)~='table' then return false,nil; end
    local cur=current_zone_name();
    if not cur then return false,nil; end
    local a=normalized_zone_name(cur); local b=normalized_zone_name(det.start_zone);
    if a=='' or b=='' then return false,cur; end
    return a==b or a:find(b,1,true)~=nil or b:find(a,1,true)~=nil,cur;
end

local function current_status_names()
    local names={}; local available=false;
    pcall(function()
        if not AshitaCore or not AshitaCore.GetMemoryManager then return; end
        local mm=AshitaCore:GetMemoryManager();
        local player=mm and mm:GetPlayer() or nil;
        if not player then return; end
        local ids={};
        local raw=nil;
        if player.GetBuffs then
            local ok,val=pcall(function() return player:GetBuffs(); end);
            if ok then raw=val; end
        end
        if type(raw)=='table' then
            for _,id in pairs(raw) do ids[#ids+1]=tonumber(id); end
            available=true;
        elseif player.GetBuff then
            for i=0,31 do
                local ok,id=pcall(function() return player:GetBuff(i); end);
                if ok then ids[#ids+1]=tonumber(id); available=true; end
            end
        end
        local rm=nil;
        pcall(function() rm=AshitaCore:GetResourceManager(); end);
        for _,id in ipairs(ids) do
            if id and id>0 and id~=255 then
                local name=nil;
                if rm and rm.GetString then
                    pcall(function() name=rm:GetString('buffs.names',id); end);
                end
                if type(name)=='string' and name~='' then
                    names[string.lower(name)]=true;
                end
            end
        end
    end);
    return names,available;
end


local function current_party_snapshot()
    local snap={available=false,count=0,max_level=nil,levels_complete=true,members={}};
    pcall(function()
        if not AshitaCore or not AshitaCore.GetMemoryManager then return; end
        local mm=AshitaCore:GetMemoryManager();
        local party=mm and mm:GetParty() or nil;
        if not party then return; end

        local can_identify=(party.GetMemberName~=nil or party.GetMemberActive~=nil or party.GetMemberServerId~=nil);
        if not can_identify then return; end
        snap.available=true;

        for i=0,5 do
            local active=false;
            local name=nil;
            if party.GetMemberName then
                pcall(function() name=party:GetMemberName(i); end);
                if type(name)=='string' and name~='' then active=true; end
            end
            if not active and party.GetMemberActive then
                local v=nil; pcall(function() v=party:GetMemberActive(i); end);
                active=(v==true or (tonumber(v)~=nil and tonumber(v)~=0));
            end
            if not active and party.GetMemberServerId then
                local sid=nil; pcall(function() sid=tonumber(party:GetMemberServerId(i)); end);
                active=(sid~=nil and sid>0);
            end

            if active then
                local level=nil;
                if party.GetMemberLevel then
                    pcall(function() level=tonumber(party:GetMemberLevel(i)); end);
                end
                if level==nil and party.GetMemberMainJobLevel then
                    pcall(function() level=tonumber(party:GetMemberMainJobLevel(i)); end);
                end
                snap.count=snap.count+1;
                snap.members[#snap.members+1]={index=i,name=name,level=level};
                if level~=nil and level>0 then
                    snap.max_level=(snap.max_level==nil) and level or math.max(snap.max_level,level);
                else
                    snap.levels_complete=false;
                end
            end
        end
    end);
    return snap;
end

local function resource_item_name(item_id)
    item_id=tonumber(item_id);
    if not item_id then return nil; end
    local name=nil;
    pcall(function()
        local rm=AshitaCore and AshitaCore.GetResourceManager and AshitaCore:GetResourceManager() or nil;
        if not rm or not rm.GetItemById then return; end
        local item=rm:GetItemById(item_id);
        if not item then return; end
        if type(item.Name)=='table' then
            name=item.Name[1] or item.Name[0];
        elseif type(item.Name)=='string' then
            name=item.Name;
        end
    end);
    return (type(name)=='string' and name~='') and name or nil;
end

local function equipped_item_name_set()
    local names={}; local available=false;
    pcall(function()
        if not AshitaCore or not AshitaCore.GetMemoryManager then return; end
        local mm=AshitaCore:GetMemoryManager();
        local inv=mm and mm:GetInventory() or nil;
        if not inv or not inv.GetEquippedItem then return; end
        available=true;

        for slot=0,15 do
            local eq=nil;
            pcall(function() eq=inv:GetEquippedItem(slot); end);
            local packed=eq and tonumber(eq.Index or eq.ItemIndex) or nil;
            if packed and packed>0 then
                local container,index;
                if packed<2048 then
                    container=0; index=packed;
                else
                    container=math.floor(packed/256);
                    index=packed%256;
                end
                local item=nil;
                if inv.GetContainerItem then
                    pcall(function() item=inv:GetContainerItem(container,index); end);
                elseif inv.GetItem then
                    pcall(function() item=inv:GetItem(container,index); end);
                end
                local id=item and tonumber(item.Id) or nil;
                local name=id and resource_item_name(id) or nil;
                if name then names[string.lower(name)]=true; end
            end
        end
    end);
    return names,available;
end

local INVENTORY_CONTAINERS_MAIN={0};

local function inventory_item_count(item_id)
    item_id=tonumber(item_id);
    if not item_id then return nil; end
    local inv=nil;
    pcall(function()
        if AshitaCore and AshitaCore.GetMemoryManager then
            local mm=AshitaCore:GetMemoryManager();
            inv=mm and mm:GetInventory() or nil;
        end
    end);
    if not inv then return nil; end
    local total=0; local scanned=false;
    for _,cid in ipairs(INVENTORY_CONTAINERS_MAIN) do
        local mx=nil;
        pcall(function() mx=inv:GetContainerCountMax(cid); end);
        if type(mx)=='number' and mx>=0 then
            scanned=true;
            for idx=0,mx do
                local e=nil;
                pcall(function() e=inv:GetContainerItem(cid,idx); end);
                if e and tonumber(e.Id)==item_id then
                    total=total+math.max(0,tonumber(e.Count) or 0);
                end
            end
        end
    end
    if not scanned then return nil; end
    return math.floor(total);
end

local function hex_to_bitmap(h)
    if type(h)~='string' or #h~=64 or h:find('[^0-9A-Fa-f]') then return nil; end
    local out={};
    for i=1,#h,2 do out[#out+1]=string.char(tonumber(h:sub(i,i+1),16)); end
    return table.concat(out);
end

local function quest_completion_record(c,log_id,quest_id)
    if type(c)~='table' or type(c.quest_completed_at)~='table' then return nil; end
    local rec=c.quest_completed_at[tostring(log_id)..':'..tostring(quest_id)];
    if type(rec)=='number' then return {at=rec}; end
    return type(rec)=='table' and rec or nil;
end

-- Older HorizonCheck versions cached completed 0x056 history without a per-quest
-- completion timestamp.  If a quest is already present in that persistent history
-- but has no timestamp, it is legacy historical completion evidence rather than a
-- newly observed transition.  For post-quest Japanese-midnight gates, allow that
-- legacy history to satisfy the elapsed wait instead of leaving the quest stuck in
-- CHECK forever.  Newly observed completions still receive quest_completed_at and
-- therefore continue to enforce the real midnight boundary.
function M.legacy_completed_without_timestamp(c,log_id,quest_id)
    if quest_completion_record(c,log_id,quest_id)~=nil then return false; end
    if type(c)~='table' or type(c.quest_native_completed)~='table' then return false; end
    local h=c.quest_native_completed[tostring(log_id)];
    local b=hex_to_bitmap(h);
    if type(b)~='string' or #b<32 then return false; end
    local q=tonumber(quest_id);
    if not q or q<0 or q>255 then return false; end
    local byte=math.floor(q/8)+1; local bit=q%8; local mask=2^bit;
    local v=string.byte(b,byte) or 0;
    return (v%(mask*2))>=mask;
end

local function next_jst_midnight_epoch(ts)
    ts=tonumber(ts);
    if not ts then return nil; end
    local jst=ts+(9*60*60);
    return (math.floor(jst/86400)+1)*86400-(9*60*60);
end

local function update_quest_zone_state(c)
    if type(c)~='table' then return; end
    local zid=current_zone_id();
    if zid==nil then return; end
    if c.quest_last_zone_id==nil then
        c.quest_last_zone_id=zid;
        return;
    end
    if tonumber(c.quest_last_zone_id)~=zid then
        c.quest_last_zone_id=zid;
        c.quest_last_zone_change_at=os.time();
        invalidate_progression_overview();
        request_state_save(1)
    end
end

local function latest_zone_refresh_at(c)
    if type(c)~='table' then return nil; end
    local a=tonumber(c.quest_last_zone_change_at);
    local b=(type(c.automation)=='table') and tonumber(c.automation.last_zone_seen_at) or nil;
    if a and b then return math.max(a,b); end
    return a or b;
end

local function native_quest_started_or_completed(log_id,quest_id)
    log_id=tonumber(log_id); quest_id=tonumber(quest_id);
    if log_id==nil or quest_id==nil or quest_id<0 or quest_id>255 then return nil; end
    local policy=canonical_native_policy(log_id,quest_id);
    if policy=='BLOCK' or quest_catalog_disabled(log_id,quest_id,policy) then return false; end

    local function bitmap_has(payload,qid)
        if type(payload)~='string' then return nil; end
        local byte=math.floor(qid/8)+1;
        local bit=qid%8;
        local b=string.byte(payload,byte);
        if b==nil then return nil; end
        local m=2^bit;
        return (b%(m*2))>=m;
    end

    local active=bitmap_has(current[log_id],quest_id);
    local done=bitmap_has(completed[log_id],quest_id);
    if (active==true or done==true) and policy=='QUARANTINE' then return nil; end
    if active==true or done==true then return true; end
    if active==nil and done==nil then return nil; end
    return false;
end

local function native_quest_is_active(log_id,quest_id)
    return quest_active(log_id,quest_id);
end

local function manual_world_presence(c,name)
    if type(c)~='table' or type(c.quest_world_presence)~='table' then return nil; end
    local key=string.lower(tostring(name or ''));
    if c.quest_world_presence[key]==true then return true; end
    return nil;
end

local function requirement_result(c,req,log_id,quest_id)
    if type(req)~='table' then return nil,'No mapped requirements'; end
    local unknown={};
    if type(req.quests)=='table' then
        for _,q in ipairs(req.quests) do
            local log=tonumber(q.log_id or q.log); local id=tonumber(q.quest_id or q.id);
            local done=nil;
            if log~=nil and id~=nil and M.is_completed then done=M.is_completed(log,id); end
            if done==false then
                return false,'Requires '..quest_name(log,id);
            elseif done==nil then
                unknown[#unknown+1]='prerequisite quest state';
            end
        end
    end
    if type(req.quests_started)=='table' then
        for _,q in ipairs(req.quests_started) do
            local log=tonumber(q.log_id or q.log); local id=tonumber(q.quest_id or q.id);
            local started=nil;
            if log~=nil and id~=nil then started=native_quest_started_or_completed(log,id); end
            if started==false then
                return false,'Requires started quest: '..quest_name(log,id);
            elseif started==nil then
                unknown[#unknown+1]='started prerequisite quest state';
            end
        end
    end
    if type(req.exclusive_active_quests)=='table' then
        for _,q in ipairs(req.exclusive_active_quests) do
            local log=tonumber(q.log_id or q.log); local id=tonumber(q.quest_id or q.id);
            local active=nil;
            if log~=nil and id~=nil then active=native_quest_is_active(log,id); end
            if active==true then
                return false,'Conflicts with active quest: '..quest_name(log,id);
            elseif active==nil then
                unknown[#unknown+1]='conflicting quest state';
            end
        end
    end
    if type(req.exclusive_quests)=='table' then
        for _,q in ipairs(req.exclusive_quests) do
            local log=tonumber(q.log_id or q.log); local id=tonumber(q.quest_id or q.id);
            local started=nil;
            if log~=nil and id~=nil then started=native_quest_started_or_completed(log,id); end
            if started==true then
                return false,'Conflicts with quest: '..quest_name(log,id);
            elseif started==nil then
                unknown[#unknown+1]='mutually exclusive quest state';
            end
        end
    end
    if req.world_presence~=nil then
        local have=manual_world_presence(c,req.world_presence);
        if have~=true then
            unknown[#unknown+1]=tostring(req.world_presence)..' present in Al Zahbi';
        end
    end

    if type(req.status_any)=='table' then
        local have,available=current_status_names();
        if available then
            local matched=false;
            for _,name in ipairs(req.status_any) do
                if have[string.lower(tostring(name))]==true then matched=true; break; end
            end
            if not matched then
                return false,'Requires one active status: '..table.concat(req.status_any,', ');
            end
        else
            unknown[#unknown+1]='current status effects';
        end
    end

    if req.nation_rank~=nil then
        local n=req.nation or req.nation_id;
        if n==nil then
            local nation_by_log={[0]='sandoria',[1]='bastok',[2]='windurst'};
            n=nation_by_log[tonumber(log_id)];
        end
        local have=historical_rank(c,n);
        if have==nil then unknown[#unknown+1]='nation rank'
        elseif have<tonumber(req.nation_rank) then return false,string.format('Requires %s Rank %d',tostring(n),tonumber(req.nation_rank)); end
    end
    -- Fame 1 is the baseline/no-gate state and can be treated as satisfied.
    -- Generic Outlands `fame = N` rows are resolved from the quest's starting
    -- area so confirmed Norg/Tenshodo, Selbina/Rabao, or Windurst/Kazham fame
    -- can satisfy them automatically instead of leaving them in CHECK.
    if req.fame~=nil then
        local f=tonumber(req.fame);
        local det=(quest_id~=nil) and metadata_for(log_id,quest_id) or nil;
        local profile_kind,profile_key,profile_label=contextual_fame_profile(det,log_id);

        -- Explicit fame_log_id always wins when metadata provides one.
        if req.fame_log_id~=nil then
            profile_kind='city';
            profile_key=tonumber(req.fame_log_id);
        end

        if profile_kind=='reputation' then
            local have=manual_reputation_level(c,profile_key);
            if have~=nil and f~=nil then
                if have<f then
                    return false,string.format('Requires %s Fame %d (confirmed: %d)',tostring(profile_label or profile_key),f,have);
                end
            elseif f and f>1 then
                unknown[#unknown+1]=string.format('%s fame',tostring(profile_label or profile_key));
            end
        else
            local fame_log=tonumber(profile_key or req.fame_log_id or log_id);
            local manual_fame=(fame_log~=nil and fame_log>=0 and fame_log<=3) and manual_fame_level(c,fame_log) or nil;
            local inferred_fame=(fame_log~=nil and fame_log>=0 and fame_log<=3) and inferred_city_fame_floor(fame_log) or nil;
            local effective_fame=nil;
            if manual_fame and inferred_fame then effective_fame=math.max(manual_fame,inferred_fame)
            else effective_fame=manual_fame or inferred_fame; end

            if f and effective_fame then
                if effective_fame<f then
                    -- An inferred floor is only a lower bound and can never prove the
                    -- character is below a fame requirement. Only an explicit manual
                    -- profile may produce a LOCKED result.
                    if manual_fame and (not inferred_fame or manual_fame>=inferred_fame) then
                        return false,string.format('Requires Fame %d (manual profile: %d)',f,manual_fame);
                    else
                        unknown[#unknown+1]=string.format('fame %d (proven floor %d)',f,effective_fame);
                    end
                end
            elseif not f or f>1 then
                unknown[#unknown+1]='fame';
            end
        end
    end

    if req.reputation~=nil and req.reputation_level~=nil then
        local need=tonumber(req.reputation_level);
        local have=manual_reputation_level(c,req.reputation);
        if have==nil then
            unknown[#unknown+1]=tostring(req.reputation)..' reputation';
        elseif need and have<need then
            return false,string.format('Requires %s reputation %d (manual profile: %d)',tostring(req.reputation),need,have);
        end
    end

    if req.mercenary_points~=nil then
        local need=tonumber(req.mercenary_points);
        local have=manual_mercenary_points(c);
        -- Promotion quests are hard-gated by the current-rank point total.
        -- If the point profile has not been captured/set yet, do not present the
        -- promotion as AVAILABLE/CHECK: the required 25 points have not been
        -- proven. Keep it in LOCKED until the profile reaches the requirement.
        if have==nil then
            return false,string.format('Requires %d Mercenary Rank points (profile not set)',need or 0);
        elseif need and have<need then
            return false,string.format('Requires %d Mercenary Rank points (manual profile: %d)',need,have);
        end
    end

    if req.mercenary_rank_min~=nil then
        local need=mercenary_rank_index(req.mercenary_rank_min);
        local have,have_name=manual_mercenary_rank(c);
        if have==nil then
            unknown[#unknown+1]='Mercenary Rank';
        elseif need and have<need then
            return false,string.format('Requires Mercenary Rank %s or higher (profile: %s)',tostring(req.mercenary_rank_min),tostring(have_name));
        end
    end

    if req.party_size~=nil or req.party_max_level~=nil then
        local snap=current_party_snapshot();
        if not snap.available then
            unknown[#unknown+1]='party composition';
        else
            if req.party_size~=nil then
                local need=tonumber(req.party_size);
                if need and snap.count<need then
                    return false,string.format('Requires a party of %d (current %d)',need,snap.count);
                end
            end
            if req.party_max_level~=nil then
                local cap=tonumber(req.party_max_level);
                if not snap.levels_complete or snap.max_level==nil then
                    unknown[#unknown+1]='party member levels';
                elseif cap and snap.max_level>cap then
                    return false,string.format('Requires every party member at level %d or below (current max %d)',cap,snap.max_level);
                end
            end
        end
    end

    -- Current main job can be read safely from the same Ashita memory source
    -- HorizonCheck already uses elsewhere. Level remains VERIFY for now.
    if req.job~=nil then
        local current_job=nil;
        pcall(function()
            if not AshitaCore or not AshitaCore.GetMemoryManager then return; end
            local mm=AshitaCore:GetMemoryManager();
            if not mm or not mm.GetPlayer then return; end
            local player=mm:GetPlayer();
            if not player then return; end
            local jid=nil;
            if player.GetMainJob then jid=tonumber(player:GetMainJob());
            elseif player.GetMainJobId then jid=tonumber(player:GetMainJobId()); end
            local jobs={
                [1]='WAR',[2]='MNK',[3]='WHM',[4]='BLM',[5]='RDM',[6]='THF',
                [7]='PLD',[8]='DRK',[9]='BST',[10]='BRD',[11]='RNG',[12]='SAM',
                [13]='NIN',[14]='DRG',[15]='SMN',[16]='BLU',[17]='COR',[18]='PUP',
                [19]='DNC',[20]='SCH',[21]='GEO',[22]='RUN',
            };
            current_job=jobs[jid];
        end);
        if current_job then
            local match=false;
            for token in string.upper(tostring(req.job)):gmatch('[A-Z]+') do
                if token==current_job then match=true; break; end
            end
            if not match then return false,'Requires '..tostring(req.job)..' as current main job'; end
        else
            unknown[#unknown+1]='current job';
        end
    end
    if req.level~=nil then
        local need=tonumber(req.level);
        local have=current_main_job_level();
        if have==nil then
            unknown[#unknown+1]='job level';
        elseif need and have<need then
            return false,string.format('Requires level %d (current %d)',need,have);
        end
    end
    if type(req.maat_jobs)=='table' then
        local done,total,missing=maat_job_progress(c,req.maat_jobs);
        if done<total then
            unknown[#unknown+1]=string.format('Maat victories %d/%d (%s missing)',done,total,table.concat(missing,', '));
        end
    end

    if type(req.avatar_unlocks)=='table' then
        local done,total,missing=avatar_unlock_progress(c,req.avatar_unlocks);
        if done<total then
            unknown[#unknown+1]=string.format('avatar unlocks %d/%d (%s missing)',done,total,table.concat(missing,', '));
        end
    end
    if req.weapon_skill~=nil and req.weapon_skill_level~=nil then
        local need=tonumber(req.weapon_skill_level);
        local have=manual_weapon_skill_level(c,req.weapon_skill);
        if have==nil then
            unknown[#unknown+1]=tostring(req.weapon_skill)..' skill';
        elseif need and have<need then
            return false,string.format('Requires %s skill %d (manual profile: %d)',tostring(req.weapon_skill),need,have);
        end
    end
    if type(req.equip_proof_items)=='table' then
        local equipped,available=equipped_item_name_set();
        if not available then
            unknown[#unknown+1]='equipped-item proof';
        else
            local matched=false;
            for _,name in ipairs(req.equip_proof_items) do
                if equipped[string.lower(tostring(name))]==true then matched=true; break; end
            end
            if not matched then
                unknown[#unknown+1]='equip one of: '..table.concat(req.equip_proof_items,', ');
            end
        end
    end
    if req.fishing_skill~=nil then
        local need=tonumber(req.fishing_skill);
        local have=manual_craft_skill_level(c,'Fishing');
        if have==nil then
            unknown[#unknown+1]='Fishing skill';
        elseif need and have<need then
            return false,string.format('Requires Fishing skill %d (current skill: %d)',need,have);
        end
    end
    if req.ws_trial_exclusive==true then
        local clear=(type(c)=='table' and c.quest_ws_trial_clear==true);
        if not clear then unknown[#unknown+1]='another weaponskill trial may be active'; end
    end

    if type(req.wait_jst_midnight_after_quest)=='table' then
        local w=req.wait_jst_midnight_after_quest;
        local log=tonumber(w.log_id or w.log); local id=tonumber(w.quest_id or w.id);
        local rec=(log~=nil and id~=nil) and quest_completion_record(c,log,id) or nil;
        local legacy_elapsed=(log~=nil and id~=nil) and M.legacy_completed_without_timestamp(c,log,id) or false;
        local ready=rec and next_jst_midnight_epoch(rec.at) or nil;
        if not ready and legacy_elapsed then
            -- Persisted completion from an older build had no timestamp.  It is
            -- historical evidence, so do not strand this prerequisite as UNKNOWN.
        elseif not ready then
            unknown[#unknown+1]='completion timestamp for '..quest_name(log,id);
        elseif os.time()<ready then
            return false,'Available after next Japanese midnight: '..os.date('%Y-%m-%d %H:%M',ready);
        elseif req.zone_after_wait==true then
            local zt=latest_zone_refresh_at(c);
            if not zt or zt<ready then
                unknown[#unknown+1]='zone change after the Japanese-midnight wait';
            end
        end
    end
    if type(req.zone_after_quest)=='table' then
        local w=req.zone_after_quest;
        local log=tonumber(w.log_id or w.log); local id=tonumber(w.quest_id or w.id);
        local rec=(log~=nil and id~=nil) and quest_completion_record(c,log,id) or nil;
        local zt=latest_zone_refresh_at(c);
        if not rec or not tonumber(rec.at) then
            unknown[#unknown+1]='completion timestamp for '..quest_name(log,id);
        elseif not zt or zt<=tonumber(rec.at) then
            unknown[#unknown+1]='zone change after completing '..quest_name(log,id);
        end
    end

    if type(req.wait_seconds_after_quest)=='table' then
        local w=req.wait_seconds_after_quest;
        local log=tonumber(w.log_id or w.log); local id=tonumber(w.quest_id or w.id);
        local seconds=math.max(0,tonumber(w.seconds) or 0);
        local rec=(log~=nil and id~=nil) and quest_completion_record(c,log,id) or nil;
        local ready=rec and tonumber(rec.at) and (tonumber(rec.at)+seconds) or nil;
        local manual_key=tostring(w.manual_key or '');
        if ready then
            if os.time()<ready then
                return false,'Wait completes at '..os.date('%Y-%m-%d %H:%M',ready);
            end
        elseif manual_key~='' and manual_condition_flag(c,manual_key)==true then
            -- Manually confirmed historical wait when no trustworthy completion timestamp exists.
        else
            unknown[#unknown+1]=tostring(w.label or ('timed wait after '..quest_name(log,id)));
        end
    end

    if type(req.mission_active)=='table' then
        local m=req.mission_active;
        local active=nil;
        if HC and HC.modules and HC.modules.missions and HC.modules.missions.is_current then
            active=HC.modules.missions.is_current(m.series or m.story,m.number or m.id or m.value);
        end
        local manual_key=tostring(m.manual_key or '');
        if active==false then
            return false,'Requires active mission: '..tostring(m.label or ((m.series or m.story or 'mission')..' '..tostring(m.number or m.id or m.value or '')));
        elseif active~=true and not (manual_key~='' and manual_condition_flag(c,manual_key)==true) then
            unknown[#unknown+1]='active mission '..tostring(m.label or ((m.series or m.story or 'mission')..' '..tostring(m.number or m.id or m.value or '')));
        end
    end
    if type(req.mission_progress_min)=='table' then
        local m=req.mission_progress_min;
        local pass=nil;
        if HC and HC.modules and HC.modules.missions and HC.modules.missions.progress_at_least then
            pass=HC.modules.missions.progress_at_least(m.series or m.story,m.number or m.id or m.value);
        end
        local manual_key=tostring(m.manual_key or '');
        if pass==false then
            return false,'Requires mission progress: '..tostring(m.label or ((m.series or m.story or 'mission')..' '..tostring(m.number or m.id or m.value or '')))..' or later';
        elseif pass~=true and not (manual_key~='' and manual_condition_flag(c,manual_key)==true) then
            unknown[#unknown+1]='mission progress '..tostring(m.label or ((m.series or m.story or 'mission')..' '..tostring(m.number or m.id or m.value or '')));
        end
    end

    if req.mission_key~=nil then
        local key=tostring(req.mission_key);
        local done=(type(c)=='table' and type(c.mission_meta)=='table' and type(c.mission_meta.sources)=='table' and c.mission_meta.sources[key]~=nil);
        if not done then unknown[#unknown+1]='mission progress ('..key..')'; end
    end
    if type(req.mission_keys)=='table' then
        for _,mk in ipairs(req.mission_keys) do
            local key=tostring(mk);
            local done=(type(c)=='table' and type(c.mission_meta)=='table' and type(c.mission_meta.sources)=='table' and c.mission_meta.sources[key]~=nil);
            if not done then unknown[#unknown+1]='mission progress ('..key..')'; end
        end
    end
    if req.mission~=nil or req.missions~=nil then unknown[#unknown+1]='mission progress'; end
    if type(req.key_items)=='table' then
        for _,ki in ipairs(req.key_items) do
            local owned=nil; local err=nil;
            -- A completed quest is permanent historical proof for a permanent
            -- key item that was required to flag that quest.  This is important
            -- on Horizon/Ashita builds where IPlayer:HasKeyItem can return false
            -- for permanent key items even though temporary KIs are readable.
            if log_id~=nil and quest_id~=nil and M.is_completed(log_id,quest_id)==true
                and HC and HC.modules and HC.modules.keyitems and HC.modules.keyitems.is_permanent_name
                and HC.modules.keyitems.is_permanent_name(tostring(ki)) then
                if HC.modules.keyitems.confirm_permanent then
                    HC.modules.keyitems.confirm_permanent(tostring(ki),'Completed quest prerequisite: '..quest_name(log_id,quest_id));
                end
                owned=true;
            elseif HC and HC.modules and HC.modules.keyitems and HC.modules.keyitems.ownership_name then
                owned,err=HC.modules.keyitems.ownership_name(tostring(ki));
            end
            if owned==false then
                return false,'Requires key item: '..tostring(ki);
            elseif owned~=true then
                unknown[#unknown+1]='key item '..tostring(ki);
            end
        end
    elseif req.key_items~=nil then
        unknown[#unknown+1]='key item requirement';
    end
    if type(req.inventory_items)=='table' then
        for _,it in ipairs(req.inventory_items) do
            local id=tonumber(it.id or it.item_id);
            local need=math.max(1,tonumber(it.count) or 1);
            local label=tostring(it.name or ('item '..tostring(id or '?')));
            local have=inventory_item_count(id);
            if have==nil then
                unknown[#unknown+1]='inventory item '..label;
            elseif have<need then
                return false,string.format('Requires %s x%d in main Inventory (current %d)',label,need,have);
            end
        end
    end
    if type(req.manual_flags)=='table' then
        local det=metadata_for(log_id,quest_id);
        for _,spec in ipairs(req.manual_flags) do
            local key,label=manual_flag_parts(spec);
            local auto_ok=auto_manual_flag_state(c,req,det,log_id,key,label);
            if not auto_ok and (key=='' or manual_condition_flag(c,key)~=true) then
                unknown[#unknown+1]=label;
            end
        end
    end
    if req.custom~=nil and req.custom_blocking~=false then unknown[#unknown+1]='HorizonXI-specific condition'; end
    if #unknown>0 then return nil,'Needs verification: '..table.concat(unknown,', '); end
    return true,'Mapped prerequisites satisfied';
end

-- HorizonXI Available view is intentionally era-scoped. HorizonXI currently
-- targets content through Treasures of Aht Urhgan for this catalog view, so
-- post-ToAU quest logs are excluded from generated AVAILABLE candidates.
-- ACTIVE / COMPLETED remain authoritative and are never filtered here.
local function available_log_supported(log_id)
    log_id=tonumber(log_id);
    return log_id~=nil and log_id>=0 and log_id<=6; -- San d'Oria .. Aht Urhgan
end


local PORT_TO_LOG_ID = {
    [0x0050] = 0,
    [0x0058] = 1,
    [0x0060] = 2,
    [0x0068] = 3,
    [0x0070] = 4,
    [0x0078] = 5,
    [0x0080] = 6,
    [0x0088] = 7,
    [0x00E0] = 8,
    [0x00F0] = 9,
    [0x0100] = 10,
};


local COMPLETED_PORT_TO_LOG_ID = {
    [0x0090] = 0, -- San d'Oria completed
    [0x0098] = 1, -- Bastok completed
    [0x00A0] = 2, -- Windurst completed
    [0x00A8] = 3, -- Jeuno completed
    [0x00B0] = 4, -- Other Areas completed
    [0x00B8] = 5, -- Outlands completed
    [0x00C0] = 6, -- Aht Urhgan completed
    [0x00C8] = 7, -- Crystal War completed
    [0x00E8] = 8, -- Abyssea completed
    [0x00F8] = 9, -- Adoulin completed
    [0x0108] = 10, -- Coalition completed
};

-- Known quest IDs used only as probe anchors. These let us validate the native
-- decoder against quests HorizonCheck already understands without changing any
-- completion state.
local PROBE_QUESTS = {
    { log_id=0, quest_id=97, name="Eco-Warrior (San d'Oria)" },
    { log_id=1, quest_id=65, name='Eco-Warrior (Bastok)' },
    { log_id=2, quest_id=84, name='Eco-Warrior (Windurst)' },
};



-- Player-facing automation badges for quests HorizonCheck already understands.
-- ACTIVE state always comes from 0x056; these badges only add stronger context
-- from existing verified trackers/key-item ownership.
local AUTOMATED_QUESTS = {
    ['0:97']  = { kind='eco', nation='sandoria', label='Eco-Warrior', repeat_tag='CONQUEST', keywords='proof key item turn in' },
    ['1:65']  = { kind='eco', nation='bastok', label='Eco-Warrior', repeat_tag='CONQUEST', keywords='indigested ore proof key item turn in' },
    ['2:84']  = { kind='eco', nation='windurst', label='Eco-Warrior', repeat_tag='CONQUEST', keywords='indigested meat proof key item turn in' },
    ['0:110'] = { kind='spice', label='Spice Gals', keywords='spice gals' },
    ['4:73']  = { kind='ovens', label='Secrets of Ovens Lost', repeat_tag='WEEKLY', keywords='tavnazian cookbook cookbook miratete turn in' },
    ['4:81']  = { kind='uninvited', label='Uninvited Guests', repeat_tag='WEEKLY', keywords='monarch linn patrol permit permit justinius' },
};

local function quest_detail(log_id,quest_id)
    return metadata_for(log_id,quest_id);
end


local function reward_tags(det)
    if type(det)~='table' then return {}; end
    local r=string.lower(tostring(det.reward or ''));
    local tags={}; local seen={};
    local function add(t) if not seen[t] then tags[#tags+1]=t; seen[t]=true; end end
    if r:find('teleport',1,true) then add('TELEPORT'); end
    if r:find('map',1,true) then add('MAP'); end
    if r:find('spell',1,true) or r:find('scroll',1,true) then add('SPELL'); end
    if r:find('job',1,true) or r:find('unlock',1,true) then add('JOB'); end
    if r:find('artifact',1,true) or r:find(' af',1,true) then add('AF'); end
    if r:find('gil',1,true) then add('GIL'); end
    if r:find('key item',1,true) then add('KEY ITEM'); end
    if r~='' and #tags==0 then add('ITEM/REWARD'); end
    return tags;
end

local function metadata_confidence(det)
    if type(det)~='table' then return 'UNMAPPED'; end
    if type(det.horizon)=='table' and det.horizon.verified==true and det.requirements_mapped==true then return 'VERIFIED'; end
    if type(det.horizon)=='table' and det.horizon.verified==true then return 'HORIZON MAPPED'; end
    if det.requirements_mapped==true then return 'MAPPED'; end
    return 'PARTIAL';
end

local CATALOG_FIELDS = {
    {'start_npc','NPC'}, {'start_zone','Zone'}, {'expansion','Expansion'},
    {'objective','Objective'}, {'reward','Reward'}, {'next_step','Next step'},
};

local function catalog_completeness(det)
    if type(det)~='table' then return 0,7,{'Metadata'}; end
    local have,total=0,7; local missing={};
    for _,f in ipairs(CATALOG_FIELDS) do
        local v=det[f[1]];
        if v~=nil and tostring(v)~='' then have=have+1; else missing[#missing+1]=f[2]; end
    end
    local req_ok=(det.requirements_mapped==true) or (type(det.requirements)=='table' and next(det.requirements)~=nil);
    if req_ok then have=have+1; else missing[#missing+1]='Prerequisites'; end
    return have,total,missing;
end

local function catalog_status(det)
    local have,total=catalog_completeness(det);
    if have>=total then return 'COMPLETE'; end
    if have>=4 then return 'PARTIAL'; end
    return 'BASIC';
end


local function catalog_quality_issues(det)
    local issues={};
    if type(det)~='table' then issues[#issues+1]='Metadata'; return issues; end
    local function add(label) issues[#issues+1]=label; end
    local function low(v)
        v=tostring(v or ''):lower();
        return v;
    end
    local npc=low(det.start_npc);
    local zone=low(det.start_zone);
    local obj=low(det.objective);
    local reward=low(det.reward);

    if npc:find('quest npc',1,true) or npc:find('quest contact',1,true)
        or npc:find('elemental trial npc',1,true) or npc:find('aht urhgan quest contact',1,true) then add('NPC'); end
    if zone:find('quest region',1,true) or zone:find('jeuno / aht urhgan progression',1,true) then add('Zone'); end
    if obj:find("complete the quest's requested task",1,true)
        or obj:find('then return as directed',1,true)
        or obj:find('follow the horizonxi wiki',1,true)
        or obj:find('complete the requested',1,true) then add('Objective'); end
    if reward:find('quest reward documented by horizonxi wiki',1,true)
        or reward:find('quest progression reward',1,true)
        or reward=='varies' then add('Reward'); end

    if det.catalog_quality_verified==true and #issues==0 then return issues; end
    if #issues==0 and det.catalog_quality_verified~=true then add('Needs individual verification'); end
    return issues;
end

local function catalog_quality_verified(det)
    local issues=catalog_quality_issues(det);
    return type(det)=='table' and det.catalog_quality_verified==true and #issues==0;
end

local function catalog_source_verified(det)
    if type(det)~='table' or type(det.horizon)~='table' or det.horizon.verified~=true then return false; end
    local src=string.lower(tostring(det.horizon.source or ''));
    if src=='' then return false; end
    -- Build/fallback provenance is not a completed source audit.
    if src:find('metadata pending',1,true)
        or src:find('native quest id map',1,true)
        or src:find('catalog completion pass',1,true)
        or src:find('generated catalog pipeline',1,true)
        or src:find('catalog reference fallback',1,true) then
        return false;
    end
    return true;
end


local function catalog_quality_score(det)
    if type(det)~='table' then return 0,10,'NEEDS REVIEW'; end
    local function low(v) return string.lower(tostring(v or '')); end
    local npc,zone,obj,reward,nexts=low(det.start_npc),low(det.start_zone),low(det.objective),low(det.reward),low(det.next_step);
    local function generic_npc(v) return v=='' or v:find('quest npc',1,true) or v:find('quest contact',1,true) or v:find('elemental trial npc',1,true); end
    local function generic_zone(v) return v=='' or v:find('quest region',1,true) or v:find('progression',1,true); end
    local function generic_obj(v) return v=='' or v:find("complete the quest's requested task",1,true) or v:find('then return as directed',1,true) or v:find('follow the horizonxi wiki',1,true) or v:find('complete the requested',1,true); end
    local function generic_reward(v) return v=='' or v:find('quest reward documented by horizonxi wiki',1,true) or v:find('quest progression reward',1,true) or v=='varies'; end
    local score=0;
    if not generic_npc(npc) then score=score+1; end
    if not generic_zone(zone) then score=score+1; end
    if not generic_obj(obj) then score=score+2; end
    if not generic_reward(reward) then score=score+1; end
    if det.requirements_mapped==true or (type(det.requirements)=='table' and next(det.requirements)~=nil) then score=score+1; end
    if nexts~='' and not nexts:find('follow the horizonxi wiki',1,true) then score=score+1; end
    if type(det.horizon)=='table' and det.horizon.verified==true and det.horizon.source and tostring(det.horizon.source)~='' then score=score+1; end
    if det.catalog_quality_verified==true then score=score+2; end
    local label=(score>=9 and 'GOLD') or (score>=7 and 'SILVER') or (score>=5 and 'BRONZE') or 'NEEDS REVIEW';
    return score,10,label;
end

local function catalog_field_missing(det,field)
    field=tostring(field or 'all');
    if field=='all' or field=='' then return catalog_status(det)~='COMPLETE'; end
    if type(det)~='table' then return true; end
    if field=='npc' then return det.start_npc==nil or tostring(det.start_npc)==''; end
    if field=='zone' then return det.start_zone==nil or tostring(det.start_zone)==''; end
    if field=='objective' then return det.objective==nil or tostring(det.objective)==''; end
    if field=='reward' then return det.reward==nil or tostring(det.reward)==''; end
    if field=='prereq' then
        return not (det.requirements_mapped==true or (type(det.requirements)=='table' and next(det.requirements)~=nil));
    end
    return catalog_status(det)~='COMPLETE';
end

local function region_catalog_stats(log_id)
    local mapped,complete,partial,basic=0,0,0,0;
    for _,qid in ipairs(catalog_ids(log_id)) do
        mapped=mapped+1;
        local st=catalog_status(quest_detail(log_id,qid));
        if st=='COMPLETE' then complete=complete+1 elseif st=='PARTIAL' then partial=partial+1 else basic=basic+1 end
    end
    local enriched=complete+partial;
    local pct=(mapped>0) and math.floor((enriched*100/mapped)+0.5) or 0;
    return mapped,complete,partial,basic,enriched,pct;
end


local function region_quality_stats(log_id)
    local gold,silver,bronze,review,verified=0,0,0,0,0;
    for _,qid in ipairs(catalog_ids(log_id)) do
        local det=quest_detail(log_id,qid);
        local _,_,label=catalog_quality_score(det);
        if label=='GOLD' then gold=gold+1 elseif label=='SILVER' then silver=silver+1 elseif label=='BRONZE' then bronze=bronze+1 else review=review+1 end
        if catalog_source_verified(det) then verified=verified+1; end
    end
    return gold,silver,bronze,review,verified;
end

local function requirements_search_text(det)
    if type(det)~='table' then return ''; end
    local req=det.requirements; if type(req)~='table' then return ''; end
    local out={};
    for k,v in pairs(req) do
        if type(v)=='string' or type(v)=='number' then out[#out+1]=tostring(k)..' '..tostring(v);
        elseif type(v)=='table' then
            for _,x in pairs(v) do
                if type(x)=='string' or type(x)=='number' then out[#out+1]=tostring(x);
                elseif type(x)=='table' then for kk,vv in pairs(x) do if type(vv)=='string' or type(vv)=='number' then out[#out+1]=tostring(kk)..' '..tostring(vv); end end end
            end
        end
    end
    return table.concat(out,' ');
end

local function tags_text(det)
    local t=reward_tags(det); if #t==0 then return ''; end
    return '['..table.concat(t,'][')..']';
end

local function automated_def(log_id,quest_id)
    return AUTOMATED_QUESTS[tostring(log_id)..':'..tostring(quest_id)];
end

local function automated_status(c,log_id,quest_id)
    local d=automated_def(log_id,quest_id);
    if d==nil then return nil,false; end
    if d.kind=='ovens' and HC.modules.ovens and HC.modules.ovens.row_status then
        return HC.modules.ovens.row_status(c),true;
    elseif d.kind=='spice' and HC.modules.spice and HC.modules.spice.row_status then
        return HC.modules.spice.row_status(c),true;
    elseif d.kind=='uninvited' and HC.modules.automation and HC.modules.automation.uninvited_status then
        return HC.modules.automation.uninvited_status(c),true;
    elseif d.kind=='eco' and HC.modules.eco and HC.modules.eco.keyitem_status then
        local rec=HC.modules.eco.keyitem_status(c,d.nation);
        if type(rec)=='table' and rec.owned==true then
            return 'KEY ITEM READY | KI VERIFIED | TURN IN',true;
        end
        return 'ACTIVE | Eco-Warrior tracked',true;
    end
    return 'ACTIVE | AUTO TRACKED',true;
end

local function is_actionable_badge(st)
    st=string.upper(tostring(st or ''));
    return st:find('KEY ITEM READY',1,true)~=nil
        or st:find('COOKBOOK OBTAINED',1,true)~=nil
        or st:find('PERMIT READY',1,true)~=nil
        or st:find('RETURN TO',1,true)~=nil
        or st:find('READY |',1,true)~=nil;
end

local function quest_key(log_id,quest_id)
    return tostring(log_id)..':'..tostring(quest_id);
end

local function repeat_tag(log_id,quest_id)
    local d=automated_def(log_id,quest_id);
    return d and d.repeat_tag or nil;
end

-- A repeatable quest may come from the small automation table (weekly/conquest
-- repeatables) or from catalog metadata.  Normalize the catalog spellings so
-- the UI can expose one reliable Repeatable-only view.
local function quest_is_repeatable(log_id,quest_id)
    if repeat_tag(log_id,quest_id)~=nil then return true; end
    local det=quest_detail(log_id,quest_id);
    if type(det)~='table' then return false; end
    local rt=string.lower(tostring(det.repeat_type or det.repeatable or ''));
    rt=rt:gsub('^%s+',''):gsub('%s+$','');
    if rt=='' or rt=='nil' or rt=='false' or rt=='no' then return false; end
    if rt:find('not repeatable',1,true)~=nil then return false; end
    return rt=='yes' or rt=='true' or rt=='repeatable' or rt=='weekly' or rt=='daily'
        or rt=='conquest' or rt:find('repeat',1,true)~=nil;
end


local function jst_day_key(ts)
    ts=tonumber(ts) or os.time();
    return math.floor((ts+(9*60*60))/86400);
end

local function jst_week_key(ts)
    -- Sunday 00:00 JST begins a new weekly/conquest window.
    ts=tonumber(ts) or os.time();
    local shifted=ts+(9*60*60);
    local days=math.floor(shifted/86400);
    -- 1970-01-01 was Thursday; Sunday index is 0 here.
    local dow=(days+4)%7;
    return math.floor((days-dow)/7);
end

local function repeatable_status(c,log_id,quest_id)
    if not quest_is_repeatable(log_id,quest_id) then return nil,nil; end
    local active=(quest_active(log_id,quest_id)==true);
    if active then return 'ACTIVE','native quest log'; end
    local det=quest_detail(log_id,quest_id) or {};
    local kind=string.lower(tostring(det.repeat_type or det.repeatable or repeat_tag(log_id,quest_id) or 'repeatable'));
    local rec=quest_completion_record(c,log_id,quest_id);
    local at=rec and tonumber(rec.at) or nil;
    local completed_once=(M.is_completed(log_id,quest_id)==true);

    -- v6.86.0: repeat/reset interpretation is centralized in the system state
    -- engine so the quest tab, planner, and individual activity trackers use the
    -- same policy instead of maintaining slightly different reset math.
    local systems=HC and HC.modules and HC.modules.systems or nil;
    if systems and type(systems.repeat_status)=='function' then
        local auto=automated_def(log_id,quest_id);
        local nation=nil;
        if auto and auto.kind=='eco' then
            if tonumber(log_id)==0 and tonumber(quest_id)==97 then nation='sandoria'
            elseif tonumber(log_id)==1 and tonumber(quest_id)==65 then nation='bastok'
            elseif tonumber(log_id)==2 and tonumber(quest_id)==84 then nation='windurst'; end
        end
        local ok,st,src=pcall(systems.repeat_status,c,{
            kind=kind, system=auto and auto.kind or nil, nation=nation,
            active=active, completed=completed_once, completion_at=at,
            cooldown_hours=tonumber(det.cooldown_hours or det.repeat_cooldown_hours),
            repeat_tag=repeat_tag(log_id,quest_id), now=os.time(),
        });
        if ok and st~=nil then return st,src; end
    end

    -- Safe fallback for partial loads / module errors.
    if kind:find('daily',1,true) then
        if at and jst_day_key(at)==jst_day_key(os.time()) then return 'DONE TODAY','completion timestamp'; end
        if completed_once and not at then return 'UNKNOWN RESET','historical completion has no timestamp'; end
        return 'READY','daily reset window';
    end
    if kind:find('weekly',1,true) or kind:find('conquest',1,true) or string.upper(tostring(repeat_tag(log_id,quest_id) or ''))=='WEEKLY' or string.upper(tostring(repeat_tag(log_id,quest_id) or ''))=='CONQUEST' then
        if at and jst_week_key(at)==jst_week_key(os.time()) then return 'DONE THIS WEEK','completion timestamp'; end
        if completed_once and not at then return 'UNKNOWN RESET','historical completion has no timestamp'; end
        return 'READY','weekly/conquest reset window';
    end
    local cooldown=tonumber(det.cooldown_hours or det.repeat_cooldown_hours);
    if cooldown and cooldown>0 and at then
        local remain=(at+cooldown*3600)-os.time();
        if remain>0 then return 'WAITING '..tostring(math.ceil(remain/3600))..'H','catalog cooldown'; end
        return 'READY','cooldown elapsed';
    end
    return 'READY','repeatable anytime / no tracked cooldown';
end

local function automation_keywords(log_id,quest_id)
    local d=automated_def(log_id,quest_id);
    return d and tostring(d.keywords or '') or '';
end

local function quest_matches_filter(log_id,quest_id,name,status,search,automated_only,ready_only)
    if automated_only and automated_def(log_id,quest_id)==nil then return false; end
    if ready_only and not is_actionable_badge(status) then return false; end
    search=string.lower(tostring(search or ''));
    search=search:gsub('^%s+',''):gsub('%s+$','');
    if search=='' then return true; end
    local hay=string.lower(table.concat({
        tostring(name or ''), tostring(status or ''), M.log_name(log_id),
        tostring(repeat_tag(log_id,quest_id) or ''), automation_keywords(log_id,quest_id),
        tostring((quest_detail(log_id,quest_id) or {}).keywords or ''),
        tostring((quest_detail(log_id,quest_id) or {}).start_npc or ''),
        tostring((quest_detail(log_id,quest_id) or {}).start_zone or ''),
        tostring((quest_detail(log_id,quest_id) or {}).expansion or ''),
        tostring((quest_detail(log_id,quest_id) or {}).objective or ''),
        tostring((quest_detail(log_id,quest_id) or {}).items_needed or ''),
        tostring((quest_detail(log_id,quest_id) or {}).reward or ''),
        tostring((quest_detail(log_id,quest_id) or {}).next_step or ''),
        tostring((((quest_detail(log_id,quest_id) or {}).horizon or {}).source) or ''),
        requirements_search_text(quest_detail(log_id,quest_id)), catalog_status(quest_detail(log_id,quest_id)),
        tags_text(quest_detail(log_id,quest_id))
    },' '));
    return hay:find(search,1,true)~=nil;
end

local function row_priority(r)
    local p=0;
    if is_actionable_badge(r.status) then p=p+500; end
    if r.repeat_tag=='WEEKLY' then p=p+80;
    elseif r.repeat_tag=='CONQUEST' then p=p+60; end
    if r.is_auto then p=p+30; end
    return p;
end

local function sort_rows(rows)
    table.sort(rows,function(a,b)
        local pa,pb=row_priority(a),row_priority(b);
        if pa~=pb then return pa>pb; end
        local na,nb=string.lower(a.name or ''),string.lower(b.name or '');
        if na~=nb then return na<nb; end
        return (a.qid or 0)<(b.qid or 0);
    end);
end
local tracked = {
    chocobo_riding = { name='Chocobo Riding Game' },
    spice_gals = { name='Spice Gals' },
    ovens_lost = { name='Secrets of Ovens Lost' },
};

local function u16le(s,o)
    if type(s)~='string' or #s<o+1 then return nil; end
    return string.byte(s,o)+string.byte(s,o+1)*256;
end

local function parse_056(data)
    if type(data)~='string' or #data<40 then return nil,nil,nil; end
    -- Proven v6.9.53 decoder: Ashita packet data includes the 4-byte packet
    -- header. The 0x056 body is eight uint32 quest bitfields at bytes 5..36,
    -- then the 16-bit quest-log Type at bytes 37..38.
    local port=u16le(data,37);
    local log_id=PORT_TO_LOG_ID[port];
    if log_id==nil then return nil,nil,port; end
    return log_id,data:sub(5,36),port;
end

local function maps(c)
    c.quest_flags=type(c.quest_flags)=='table' and c.quest_flags or {};
    c.quest_flags.learned=type(c.quest_flags.learned)=='table' and c.quest_flags.learned or {};
    return c.quest_flags.learned;
end

local function bitset(s,byte,bit)
    local b=type(s)=='string' and string.byte(s,byte) or nil;
    if b==nil then return false; end
    local m=2^bit;
    return (b%(m*2))>=m;
end

quest_active = function(log_id,quest_id)
    log_id=tonumber(log_id); quest_id=tonumber(quest_id);
    if log_id==nil or quest_id==nil or quest_id<0 or quest_id>255 then return nil; end
    local policy=canonical_native_policy(log_id,quest_id);
    if policy=='BLOCK' or quest_catalog_disabled(log_id,quest_id,policy) then return false; end
    local p=current[log_id];
    if p==nil then return nil; end
    local byte=math.floor(quest_id/8)+1;
    local bit=quest_id%8;
    local raw=bitset(p,byte,bit);
    -- Quarantined native IDs remain available through raw_native_state() for
    -- diagnostics/capture, but cannot independently mark a quest ACTIVE.
    if raw==true and policy=='QUARANTINE' then return nil; end
    return raw;
end


local availability_state;

-- Centralized state/reason classification used by both list views and the
-- quest-detail diagnostics. Keeping this outside M.draw also makes it reusable
-- by the self-audit without adding another captured upvalue to the large UI.
local function requirement_reason_category(reason,det)
    local s=string.lower(tostring(reason or ''));
    local req=(type(det)=='table' and type(det.requirements)=='table') and det.requirements or {};
    local custom=string.lower(tostring(req.custom or ''));
    if custom:find('manual prerequisite check:',1,true) then return 'Mixed/Manual'; end
    -- Repeat/reset gating should outrank unrelated satisfied requirements such as
    -- fame.  Eco-Warrior historically showed CHECK | Fame simply because fame
    -- existed in the metadata even when the actual unresolved gate was the
    -- Conquest-period lockout.
    if s:find('conquest',1,true) or s:find('repeat eligibility',1,true)
        or s:find('reset',1,true) or s:find('done this week',1,true)
        or s:find('weekly',1,true) then return 'World State'; end
    if s:find('fame',1,true) or custom:find('fame',1,true) or req.fame~=nil then return 'Fame'; end
    if s:find('reputation',1,true) or req.reputation~=nil then return 'Reputation'; end
    if s:find('rank',1,true) or custom:find('rank',1,true) or req.nation_rank~=nil or req.mercenary_points~=nil or req.mercenary_rank_min~=nil then return 'Rank'; end
    if s:find('skill',1,true) or custom:find('skill ',1,true) or req.weapon_skill~=nil or req.fishing_skill~=nil or req.craft_skill~=nil or req.equip_proof_items~=nil or req.ws_trial_exclusive==true then return 'Skill/Trial'; end
    if s:find('present in al zahbi',1,true) or req.world_presence~=nil or req.status_any~=nil or req.exclusive_active_quests~=nil or req.exclusive_quests~=nil then return 'World State'; end
    if s:find('party',1,true) or req.party_size~=nil or req.party_max_level~=nil then return 'Party'; end
    if s:find('level',1,true) or s:find('job',1,true) or custom:find('level ',1,true) or custom:find(' job',1,true) or req.level~=nil or req.job~=nil or req.maat_jobs~=nil or req.avatar_unlocks~=nil then return 'Job/Level'; end
    if s:find('mission',1,true) or custom:find('mission',1,true) or custom:find('promathia',1,true) or custom:find('zilart',1,true) or req.mission_key~=nil or req.mission_keys~=nil or req.mission~=nil or req.missions~=nil or req.mission_active~=nil or req.mission_progress_min~=nil then return 'Mission'; end
    if s:find('key item',1,true) or custom:find('key item',1,true) or custom:find('key-item',1,true) or req.key_items~=nil or req.inventory_items~=nil then return 'Key Item'; end
    if s:find('quest',1,true) or custom:find('preced',1,true) or custom:find('complete',1,true) or (type(req.quests)=='table' and #req.quests>0) or (type(req.quests_started)=='table' and #req.quests_started>0) then return 'Previous Quest'; end
    if req.manual_flags~=nil then return 'Mixed/Manual'; end
    return 'Other';
end

local function evidence_confidence(source,value)
    local s=string.lower(tostring(source or ''));
    local v=string.lower(tostring(value or ''));
    if v:find('unknown',1,true) or v:find('unavailable',1,true) or v:find('not confirmed',1,true) then return 'UNKNOWN'; end
    if s:find('live',1,true) or s:find('player memory',1,true) or s:find('key%-item') then return 'LIVE'; end
    if s:find('native completed quest history',1,true) or s:find('native quest history',1,true) then return 'NATIVE'; end
    if s:find('confirmed',1,true) or s:find('dialogue',1,true) then return 'CONFIRMED'; end
    if s:find('inferred',1,true) then return 'INFERRED'; end
    if s:find('manual fallback',1,true) or s:find('character profile',1,true) then return 'PROFILE'; end
    return 'CATALOG';
end

local function build_dependency_index()
    if dependency_index_cache~=nil then return dependency_index_cache; end
    local idx={};
    for log=0,6 do
        if available_log_supported(log) then
            for _,qid in ipairs(catalog_ids(log)) do
                local det=metadata_for(log,qid);
                local req=(type(det)=='table' and type(det.requirements)=='table') and det.requirements or {};
                if type(req.quests)=='table' then
                    for _,q in ipairs(req.quests) do
                        local ql=tonumber(q.log_id or q.log); local qi=tonumber(q.quest_id or q.id);
                        if ql~=nil and qi~=nil then
                            local key=tostring(ql)..':'..tostring(qi);
                            idx[key]=idx[key] or {};
                            idx[key][#idx[key]+1]={log_id=log,quest_id=qid,name=quest_name(log,qid)};
                        end
                    end
                end
            end
        end
    end
    for _,rows in pairs(idx) do
        table.sort(rows,function(a,b) return string.lower(tostring(a.name or ''))<string.lower(tostring(b.name or '')); end);
    end
    dependency_index_cache=idx;
    return idx;
end

local function dependent_quest_count(log_id,quest_id)
    log_id=tonumber(log_id); quest_id=tonumber(quest_id);
    if log_id==nil or quest_id==nil then return 0,{}; end
    local rows=build_dependency_index()[tostring(log_id)..':'..tostring(quest_id)] or {};
    return #rows,rows;
end

local function priority_score(c,log_id,quest_id)
    local det=metadata_for(log_id,quest_id) or {};
    local score=0; local reasons={};
    local deps=dependent_quest_count(log_id,quest_id);
    if deps>0 then score=score+deps*20; reasons[#reasons+1]=tostring(deps)..' unlock'; end
    local here=quest_starts_in_current_zone(det);
    if here then score=score+45; reasons[#reasons+1]='current zone'; end
    local blob=string.lower(table.concat({tostring(det.reward or ''),tostring(det.tags or ''),tostring(det.objective or ''),tostring(det.next_step or '')},' '));
    local valuable={
        {'map',35,'map'}, {'key item',30,'key item'}, {'spell',22,'spell'}, {'avatar',40,'avatar'},
        {'job',25,'job'}, {'access',30,'access'}, {'teleport',25,'travel'}, {'warp',20,'travel'},
    };
    for _,x in ipairs(valuable) do if blob:find(x[1],1,true) then score=score+x[2]; reasons[#reasons+1]=x[3]; end end
    if quest_is_repeatable(log_id,quest_id) then
        local rs=repeatable_status(c,log_id,quest_id);
        if rs=='READY' then score=score+8; reasons[#reasons+1]='repeatable ready';
        elseif rs=='DONE TODAY' or rs=='DONE THIS WEEK' or rs=='WAITING' then score=score-40; end
    end
    return score,table.concat(reasons,', ');
end

local function progression_overview(c)
    c=c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    local now=os.time();
    local char=(HC and HC.modules and HC.modules.core and HC.modules.core.character_name and HC.modules.core.character_name()) or 'Unknown';
    if progression_overview_cache.data~=nil and progression_overview_cache.char==char and now-(tonumber(progression_overview_cache.at) or 0)<PROGRESSION_OVERVIEW_CACHE_SECONDS then
        return progression_overview_cache.data;
    end
    local out={ready=0,active=0,locked=0,check=0,here=0,recommended={},active_rows={},check_rows={},locked_rows={}};

    -- Build dependency impact once for the whole catalog. This keeps planner
    -- ranking cheap even when hundreds of Locked / Check quests are mapped.
    local dep_counts={}; local all={};
    for log=0,6 do
        for _,qid in ipairs(catalog_ids(log)) do
            local det=metadata_for(log,qid) or {};
            all[#all+1]={log_id=log,quest_id=qid,det=det};
            local req=type(det.requirements)=='table' and det.requirements or {};
            if type(req.quests)=='table' then
                for _,q in ipairs(req.quests) do
                    local ql=tonumber(q.log_id or q.log); local qi=tonumber(q.quest_id or q.id);
                    if ql~=nil and qi~=nil then
                        local k=tostring(ql)..':'..tostring(qi); dep_counts[k]=(dep_counts[k] or 0)+1;
                    end
                end
            end
        end
    end

    local function blocker_score(rec)
        local k=tostring(rec.log_id)..':'..tostring(rec.quest_id);
        local score=(tonumber(dep_counts[k]) or 0)*20;
        if quest_starts_in_current_zone(rec.det) then score=score+35; end
        return score;
    end

    for _,rec in ipairs(all) do
        local log=rec.log_id; local qid=rec.quest_id; local det=rec.det;
        local active=quest_active(log,qid)==true;
        local complete=M.is_completed(log,qid)==true;
        local rpt=quest_is_repeatable(log,qid);
        if active then
            out.active=out.active+1;
            local ps,why=priority_score(c,log,qid);
            out.active_rows[#out.active_rows+1]={log_id=log,quest_id=qid,name=quest_name(log,qid),score=ps,why=why,zone=tostring(det.start_zone or ''),here=quest_starts_in_current_zone(det),next_step=tostring(det.next_step or det.objective or '')};
        end
        if not active and (not complete or rpt) then
            local av,reason=availability_state(c,log,qid);
            if av=='AVAILABLE' then
                out.ready=out.ready+1;
                local here=quest_starts_in_current_zone(det);
                if here then out.here=out.here+1; end
                local ps,why=priority_score(c,log,qid);
                out.recommended[#out.recommended+1]={log_id=log,quest_id=qid,name=quest_name(log,qid),score=ps,why=why,zone=tostring(det.start_zone or ''),here=here};
            elseif av=='LOCKED' then
                out.locked=out.locked+1;
                local raw_reason=tostring(reason or 'Locked');
                local blocker=nil;
                if HC.modules and HC.modules.blockers and HC.modules.blockers.quest then
                    local okb,b=pcall(HC.modules.blockers.quest,c,log,qid,av,raw_reason);
                    if okb and type(b)=='table' then blocker=b; end
                end
                out.locked_rows[#out.locked_rows+1]={
                    log_id=log,quest_id=qid,name=quest_name(log,qid),score=blocker_score(rec),
                    reason=(blocker and tostring(blocker.summary or '')~='' and blocker.summary) or raw_reason,
                    raw_reason=raw_reason,blocker=blocker,zone=tostring(det.start_zone or ''),here=quest_starts_in_current_zone(det),
                    unlocks=tonumber(dep_counts[tostring(log)..':'..tostring(qid)]) or 0
                };
            elseif av=='CHECK' or av=='MANUAL' then
                out.check=out.check+1;
                out.check_rows[#out.check_rows+1]={log_id=log,quest_id=qid,name=quest_name(log,qid),score=blocker_score(rec),reason=tostring(reason or 'Needs verification'),zone=tostring(det.start_zone or ''),here=quest_starts_in_current_zone(det),unlocks=tonumber(dep_counts[tostring(log)..':'..tostring(qid)]) or 0};
            end
        end
    end
    local function sort_score(rows)
        table.sort(rows,function(a,b) if (a.score or 0)~=(b.score or 0) then return (a.score or 0)>(b.score or 0); end return string.lower(a.name)<string.lower(b.name); end);
    end
    sort_score(out.recommended); sort_score(out.active_rows); sort_score(out.check_rows); sort_score(out.locked_rows);
    progression_overview_cache={at=now,char=char,data=out};
    return out;
end

-- Job Progression Planner: find the next mapped quest(s) that explicitly
-- require a selected job. This reuses the same availability engine as the
-- Quests tab, so Character Info never invents a separate quest state.
local function job_progression(c,job_abbr,level)
    local job=string.upper(tostring(job_abbr or ''));
    local lvl=tonumber(level) or 0;
    local pending={}; local completed_count=0;
    local function job_matches(value)
        local text=string.upper(tostring(value or ''));
        if text=='' or job=='' then return false; end
        return text:match('%f[%a]'..job..'%f[^%a]')~=nil;
    end
    for log=0,6 do
        if available_log_supported(log) then
            for _,qid in ipairs(catalog_ids(log)) do
                local det=metadata_for(log,qid) or {};
                local req=type(det.requirements)=='table' and det.requirements or {};
                if job_matches(req.job or det.job) then
                    local active=quest_active(log,qid)==true;
                    local complete=M.is_completed(log,qid)==true;
                    local rpt=quest_is_repeatable(log,qid);
                    if complete and not active and not rpt then
                        completed_count=completed_count+1;
                    else
                        local av,reason=availability_state(c,log,qid);
                        local state=active and 'ACTIVE' or av or 'UNKNOWN';
                        local rank=6;
                        if state=='ACTIVE' then rank=1
                        elseif state=='AVAILABLE' then rank=2
                        elseif state=='CHECK' or state=='MANUAL' then rank=3
                        elseif state=='LOCKED' then rank=4
                        elseif state=='UNKNOWN' then rank=5 end
                        local display_reason=tostring(reason or '');
                        local blocker=nil;
                        if state=='LOCKED' and HC.modules and HC.modules.blockers and HC.modules.blockers.quest then
                            local okb,b=pcall(HC.modules.blockers.quest,c,log,qid,state,display_reason);
                            if okb and type(b)=='table' then blocker=b; display_reason=tostring(b.summary or display_reason); end
                        end
                        pending[#pending+1]={log_id=log,quest_id=qid,name=quest_name(log,qid),state=state,reason=display_reason,raw_reason=reason or '',blocker=blocker,rank=rank,zone=tostring(det.start_zone or ''),reward=tostring(det.reward or ''),required_level=tonumber(req.level)};
                    end
                end
            end
        end
    end
    table.sort(pending,function(a,b)
        if a.rank~=b.rank then return a.rank<b.rank; end
        return string.lower(tostring(a.name or ''))<string.lower(tostring(b.name or ''));
    end);
    local next_quest=pending[1];
    local target=next_quest and tonumber(next_quest.required_level) or nil;
    local target_source=target and 'quest' or nil;
    if target==nil and lvl<75 then
        local milestones={18,30,40,50,60,66,71,75};
        for _,m in ipairs(milestones) do
            if lvl<m then target=m; target_source='milestone'; break; end
        end
    end
    return {job=job,level=lvl,level_target=target,level_target_source=target_source,level_capped=(lvl>=75),completed_job_quests=completed_count,pending=pending,next=next_quest};
end

local function requirement_source_summary(c,log_id,quest_id)
    local det=metadata_for(log_id,quest_id);
    local req=(type(det)=='table' and type(det.requirements)=='table') and det.requirements or {};
    local rows={};
    local function add(label,value,source)
        local src=tostring(source or 'Catalog'); rows[#rows+1]={label=tostring(label),value=tostring(value),source=src,confidence=evidence_confidence(src,value)};
    end
    if req.fame~=nil then
        local kind,pkey,plabel=contextual_fame_profile(det,log_id);
        if req.fame_log_id~=nil then kind='city'; pkey=tonumber(req.fame_log_id); end
        if kind=='reputation' then
            local have=manual_reputation_level(c,pkey);
            add((plabel or tostring(pkey))..' Fame', tostring(have or 'unknown')..' / need '..tostring(req.fame), have~=nil and 'Confirmed fame dialogue/profile' or 'Profile not confirmed');
        else
            local fame_log=tonumber(pkey or req.fame_log_id or log_id);
            local mf=(fame_log and fame_log>=0 and fame_log<=3) and manual_fame_level(c,fame_log) or nil;
            local inf=(fame_log and fame_log>=0 and fame_log<=3) and inferred_city_fame_floor(fame_log) or nil;
            local eff=(mf and inf) and math.max(mf,inf) or mf or inf;
            add('Fame', tostring(eff or 'unknown')..' / need '..tostring(req.fame), mf~=nil and 'Confirmed fame profile' or (inf~=nil and 'Completed-quest inferred floor' or 'Profile not confirmed'));
        end
    end
    if req.reputation~=nil and req.reputation_level~=nil then
        local have=manual_reputation_level(c,req.reputation);
        add(tostring(req.reputation)..' reputation', tostring(have or 'unknown')..' / need '..tostring(req.reputation_level), have~=nil and 'Confirmed reputation profile' or 'Profile not confirmed');
    end
    if req.level~=nil then
        local have=current_main_job_level();
        add('Current job level', tostring(have or 'unknown')..' / need '..tostring(req.level), have~=nil and 'Live player memory' or 'Live value unavailable');
    end
    if req.fishing_skill~=nil then
        local have=manual_craft_skill_level(c,'Fishing');
        add('Fishing skill', tostring(have or 'unknown')..' / need '..tostring(req.fishing_skill), have~=nil and 'Live Craft Skills profile / manual fallback' or 'Craft profile unavailable');
    end
    if req.weapon_skill~=nil then
        local have=manual_weapon_skill_level(c,req.weapon_skill);
        add(tostring(req.weapon_skill)..' skill', tostring(have or 'unknown'), have~=nil and 'Live Skills profile / manual fallback' or 'Skill profile unavailable');
    end
    if req.nation_rank~=nil then
        local n=req.nation or req.nation_id or ({[0]='sandoria',[1]='bastok',[2]='windurst'})[tonumber(log_id)];
        local have=historical_rank(c,n);
        add(tostring(n or 'Nation')..' rank', tostring(have or 'unknown')..' / need '..tostring(req.nation_rank), have~=nil and 'Live/recorded nation rank' or 'Rank unavailable');
    end
    if req.mercenary_points~=nil then
        local have=manual_mercenary_points(c);
        add('Mercenary Rank points', tostring(have or 'unknown')..' / need '..tostring(req.mercenary_points), have~=nil and 'Character profile' or 'Profile not set');
    end
    if type(req.quests)=='table' then
        for _,q in ipairs(req.quests) do
            local ql=tonumber(q.log_id or q.log); local qi=tonumber(q.quest_id or q.id);
            if ql and qi then
                local done=M.is_completed(ql,qi);
                add('Previous quest: '..quest_name(ql,qi), done==true and 'PASS' or (done==false and 'FAIL' or 'UNKNOWN'), 'Native completed quest history');
            end
        end
    end
    if type(req.key_items)=='table' then
        for _,ki in ipairs(req.key_items) do
            local owned=nil;
            if HC and HC.modules and HC.modules.keyitems and HC.modules.keyitems.ownership_name then owned=HC.modules.keyitems.ownership_name(tostring(ki)); end
            add('Key item: '..tostring(ki), owned==true and 'OWNED' or (owned==false and 'MISSING' or 'UNKNOWN'), 'Live key-item ownership');
        end
    end
    return rows;
end

local function quest_self_audit(c)
    local issues={};
    local counts={contradiction=0,stale_manual=0,live_evidence=0,mapped_unknown=0};
    for log=0,6 do
        if completed[log]~=nil then
            for _,qid in ipairs(catalog_ids(log)) do
                if quest_active(log,qid)~=true and not M.is_completed(log,qid) then
                    local det=metadata_for(log,qid);
                    if type(det)=='table' then
                        local req=type(det.requirements)=='table' and det.requirements or {};
                        if type(req.manual_flags)=='table' then
                            for _,spec in ipairs(req.manual_flags) do
                                local key,label=manual_flag_parts(spec);
                                local pass,proof,source,safe=auto_manual_flag_state(c,req,det,log,key,label);
                                if pass and manual_condition_flag(c,key)~=true then
                                    counts.stale_manual=counts.stale_manual+1;
                                    issues[#issues+1]={log_id=log,quest_id=qid,name=quest_name(log,qid),kind='Stale manual check',detail=tostring(label)..' -> '..tostring(proof),manual_key=key,manual_label=label,fixable=safe==true,proof=proof,source=source};
                                end
                            end
                        end
                        local av,reason=availability_state(c,log,qid);
                        local low=string.lower(tostring(reason or ''));
                        if (av=='CHECK' or av=='MANUAL') and (low:find('requirement met',1,true) or low:find('requirements satisfied',1,true)) then
                            counts.contradiction=counts.contradiction+1;
                            issues[#issues+1]={log_id=log,quest_id=qid,name=quest_name(log,qid),kind='Contradiction',detail=tostring(av)..': '..tostring(reason)};
                        elseif av=='CHECK' and det.requirements_mapped==true and low:find('needs verification:',1,true) then
                            counts.live_evidence=counts.live_evidence+1;
                            issues[#issues+1]={log_id=log,quest_id=qid,name=quest_name(log,qid),kind='Missing live evidence',detail=tostring(reason)};
                        elseif av=='UNKNOWN' and det.requirements_mapped==true then
                            counts.mapped_unknown=counts.mapped_unknown+1;
                            issues[#issues+1]={log_id=log,quest_id=qid,name=quest_name(log,qid),kind='Mapped but unknown',detail=tostring(reason)};
                        end
                    end
                end
            end
        end
    end
    table.sort(issues,function(a,b)
        local order={['Contradiction']=1,['Stale manual check']=2,['Missing live evidence']=3,['Mapped but unknown']=4};
        local oa,ob=order[a.kind] or 9,order[b.kind] or 9;
        if oa~=ob then return oa<ob; end
        return string.lower(a.name or '')<string.lower(b.name or '');
    end);
    return issues,counts;
end

local function apply_safe_quest_autofixes(c,audit)
    if type(c)~='table' then return 0; end
    c.quest_condition_flags=type(c.quest_condition_flags)=='table' and c.quest_condition_flags or {};
    local fixed=0;
    for _,it in ipairs(type(audit)=='table' and audit or {}) do
        if it.kind=='Stale manual check' and it.fixable==true and tostring(it.manual_key or '')~='' and manual_condition_flag(c,it.manual_key)~=true then
            c.quest_condition_flags[it.manual_key]={
                satisfied=true, at=os.time(), label=tostring(it.manual_label or 'Auto-resolved condition'),
                auto=true, source=tostring(it.source or 'HorizonCheck auto-fix'), proof=tostring(it.proof or '')
            };
            fixed=fixed+1;
        end
    end
    if fixed>0 and HC and HC.modules and HC.modules.state and HC.modules.state.save then HC.modules.state.save(); end
    return fixed;
end

availability_state=function(c,log_id,quest_id)
    local meta=metadata_for(log_id,quest_id);
    local policy,policy_reason,canonical=canonical_native_policy(log_id,quest_id);
    local content_state=canonical and tostring(canonical.content_state or '') or '';
    if content_state=='UNAVAILABLE' or content_state=='FUTURE' or content_state=='DISABLED'
        or (type(meta)=='table' and type(meta.horizon)=='table' and meta.horizon.enabled==false)
    then
        return 'LOCKED',tostring(policy_reason or 'Not currently available on HorizonXI');
    end

    local raw_active=false; local raw_completed=false;
    local lp=current[tonumber(log_id)]; local cp=completed[tonumber(log_id)];
    if type(lp)=='string' then raw_active=bitset(lp,math.floor(tonumber(quest_id)/8)+1,tonumber(quest_id)%8); end
    if type(cp)=='string' then raw_completed=bitset(cp,math.floor(tonumber(quest_id)/8)+1,tonumber(quest_id)%8); end
    if policy=='QUARANTINE' and (raw_active==true or raw_completed==true) then
        return 'CHECK','Native quest ID '..tostring(log_id)..':'..tostring(quest_id)..' is quarantined until HorizonXI mapping is verified';
    end
    if raw_active==true then return 'ACTIVE','Already active'; end
    local was_completed=(raw_completed==true);
    -- Native quest history records that a repeatable was completed at least once,
    -- not that it can never be started again.  Keep normal quests completed, but
    -- re-evaluate repeatables against their current start requirements.
    if was_completed and not quest_is_repeatable(log_id,quest_id) then return 'COMPLETED','Already completed'; end
    if cp==nil then return 'UNKNOWN','Completed quest history for this region has not been received yet'; end

    if type(meta)~='table' then return 'UNKNOWN','Requirements metadata is not mapped'; end

    local req=(type(meta.requirements)=='table') and meta.requirements or {};
    local has_documented_req=(next(req)~=nil);

    -- v6.46.0: requirements_mapped means "fully structured/verified", while a
    -- non-empty requirements table is still useful documented metadata. Do not
    -- dump documented manual conditions into Verify just because HorizonCheck
    -- cannot read fame/mission/etc. from memory yet.
    if meta.requirements_mapped~=true and not has_documented_req then
        return 'UNKNOWN','Requirements metadata is not mapped';
    end

    -- Eco-Warrior's repeat gate is a Conquest-period world-state check, not a
    -- fame/manual prerequisite.  Native completed history only proves the quest
    -- was completed at least once, so use HorizonCheck's timestamp when present.
    -- If the completion predates tracking, keep the quest in CHECK with an
    -- explicit reset reason instead of blaming fame.
    local auto=automated_def(log_id,quest_id);
    local req_eval=req;
    if auto and auto.kind=='eco' then
        local rs,rsrc=repeatable_status(c,log_id,quest_id);
        if rs=='DONE THIS WEEK' then
            return 'LOCKED','Eco-Warrior already completed during the current Conquest period';
        elseif rs=='UNKNOWN RESET' then
            return 'CHECK','Eco-Warrior repeat eligibility is unknown: previous completion predates HorizonCheck tracking';
        elseif rs=='READY' then
            -- The custom text documents the level-cap / one-per-Conquest rule,
            -- but once the repeat window is known READY it should not create a
            -- second generic manual blocker.  Preserve every other requirement.
            req_eval={};
            for k,v in pairs(req) do req_eval[k]=v; end
            req_eval.custom_blocking=false;
        end
    end

    local ok,reason=requirement_result(c,req_eval,log_id,quest_id);
    if ok==false then return 'LOCKED',reason; end

    -- v6.47.0: a partial prerequisite record must never become AVAILABLE merely
    -- because every *known* structured field currently passes.  requirements_mapped
    -- is the catalog's assertion that the full start gate has been source-reviewed.
    -- Until then, keep the quest in CHECK unless the player explicitly verifies it.
    local manual=manual_requirement_state(c,log_id,quest_id);
    if manual then return 'AVAILABLE','Manual requirements verified'; end
    if ok==true and meta.requirements_mapped==true then return 'AVAILABLE',reason; end
    if ok==true and meta.requirements_mapped~=true then
        return 'CHECK','Known prerequisites satisfied; full prerequisite set is not yet verified';
    end

    local custom=string.lower(tostring(req.custom or ''));
    if custom:find('manual prerequisite check:',1,true) then
        return 'MANUAL',reason or 'Catalog documents this as a manual prerequisite check';
    end
    return 'CHECK',reason or 'Documented requirement needs a manual check';
end

local function dependent_quests(log_id,quest_id)
    local out={};
    local md=load_quest_metadata();
    for key,meta in pairs(md or {}) do
        if type(meta)=='table' and type(meta.requirements)=='table' then
            local lists={meta.requirements.quests,meta.requirements.quests_started};
            local matched=false;
            for _,lst in ipairs(lists) do
                if type(lst)=='table' and not matched then
                    for _,q in ipairs(lst) do
                        local ql=tonumber(q.log_id or q.log); local qi=tonumber(q.quest_id or q.id);
                        if ql==tonumber(log_id) and qi==tonumber(quest_id) then
                            local dl,di=tostring(key):match('^(%-?%d+):(%-?%d+)$');
                            dl=tonumber(dl); di=tonumber(di);
                            if dl~=nil and di~=nil then out[#out+1]={log_id=dl,quest_id=di,name=quest_name(dl,di)}; end
                            matched=true;
                            break;
                        end
                    end
                end
            end
        end
    end
    table.sort(out,function(a,b)
        local na,nb=string.lower(a.name or ''),string.lower(b.name or '');
        if na~=nb then return na<nb; end
        if a.log_id~=b.log_id then return a.log_id<b.log_id; end
        return a.quest_id<b.quest_id;
    end);
    return out;
end


local function safe_report_token(v)
    local s=tostring(v or 'unknown'):gsub('[^%w_%-]+','_');
    if s=='' then s='unknown'; end
    return s;
end

local function write_quest_state_report(c,log_id,quest_id)
    local det=quest_detail(log_id,quest_id) or {};
    local av,reason=availability_state(c,log_id,quest_id);
    local evidence=requirement_source_summary(c,log_id,quest_id) or {};
    local rpt_status,rpt_source=repeatable_status(c,log_id,quest_id);
    local zone=current_zone_name() or tostring(current_zone_id() or 'unknown');
    local char=(HC.modules.core and HC.modules.core.character_name and HC.modules.core.character_name()) or 'character';
    local path=user_file('reports','horizoncheck_quest_state_'..safe_report_token(char)..'_'..os.date('%Y%m%d_%H%M%S')..'_'..safe_report_token(det.name or quest_name(log_id,quest_id))..'.txt');
    local f=io.open(path,'w');
    if not f then return nil,'could not open report file'; end
    local function w(x) f:write(tostring(x or '')..'\n'); end
    w('HorizonCheck v'..tostring(HC.version)..' Quest State Report');
    w('Character: '..tostring(char));
    w('Generated: '..os.date('%Y-%m-%d %H:%M:%S'));
    w('Current zone: '..tostring(zone));
    w('Quest: '..tostring(det.name or quest_name(log_id,quest_id)));
    w(string.format('Native IDs: log %s | quest %s',tostring(log_id),tostring(quest_id)));
    w('Native active: '..tostring(quest_active(log_id,quest_id)));
    w('Native completed: '..tostring(M.is_completed(log_id,quest_id)));
    w('Availability: '..tostring(av));
    w('Reason: '..tostring(reason or ''));
    w('Reason category: '..tostring(requirement_reason_category(reason,det)));
    w('Start NPC: '..tostring(det.start_npc or ''));
    w('Start zone: '..tostring(det.start_zone or ''));
    w('Repeat type: '..tostring(det.repeat_type or repeat_tag(log_id,quest_id) or ''));
    w('Repeat status: '..tostring(rpt_status or 'not repeatable')..' ['..tostring(rpt_source or '')..']');
    w('Catalog status: '..tostring(catalog_status(det)));
    w('Source: '..tostring(type(det.horizon)=='table' and det.horizon.source or ''));
    w(''); w('REQUIREMENT EVIDENCE');
    if #evidence==0 then w('(none)'); else
        for _,ev in ipairs(evidence) do
            w(string.format('[%s] %s = %s | %s',tostring(ev.confidence or 'CATALOG'),tostring(ev.label or ''),tostring(ev.value or ''),tostring(ev.source or '')));
        end
    end
    w(''); w('RAW REQUIREMENTS');
    local req=type(det.requirements)=='table' and det.requirements or {};
    local keys={}; for k in pairs(req) do keys[#keys+1]=tostring(k); end; table.sort(keys);
    if #keys==0 then w('(none)'); else
        for _,k in ipairs(keys) do
            local v=req[k];
            if type(v)=='table' then
                local vals={}; for kk,vv in pairs(v) do vals[#vals+1]=tostring(kk)..'='..tostring(vv); end; table.sort(vals); v=table.concat(vals,'; ');
            end
            w(tostring(k)..' = '..tostring(v));
        end
    end
    f:close();
    c.quest_last_state_report=path;
    if HC.modules.state then HC.modules.state.save(); end
    return path,nil;
end

local function capture_availability_snapshot(c)
    local snap={};
    for log=0,6 do
        if completed[log] then
            for _,qid in ipairs(catalog_ids(log)) do
                if quest_passes_catalog_filters(log,qid) and quest_active(log,qid)~=true and M.is_completed(log,qid)~=true then
                    local av=availability_state(c,log,qid);
                    snap[quest_key(log,qid)]=av;
                end
            end
        end
    end
    return snap;
end

local function record_recent_unlocks(c,before)
    if type(before)~='table' then return; end
    c.quest_recent_unlocked=type(c.quest_recent_unlocked)=='table' and c.quest_recent_unlocked or {};
    local now=os.time();
    local seen={};
    for _,r in ipairs(c.quest_recent_unlocked) do seen[quest_key(r.log_id,r.quest_id)]=true; end
    for log=0,6 do
        if completed[log] then
            for _,qid in ipairs(catalog_ids(log)) do
                local key=quest_key(log,qid);
                if before[key]~=nil and before[key]~='AVAILABLE' and quest_active(log,qid)~=true and M.is_completed(log,qid)~=true then
                    local av=availability_state(c,log,qid);
                    if av=='AVAILABLE' and not seen[key] then
                        table.insert(c.quest_recent_unlocked,1,{log_id=log,quest_id=qid,name=quest_name(log,qid),time=now});
                        seen[key]=true;
                        HC.msg(string.format('Quest unlocked: %s - %s.',M.log_name(log),quest_name(log,qid)));
                    end
                end
            end
        end
    end
    while #c.quest_recent_unlocked>12 do table.remove(c.quest_recent_unlocked); end
end

local function active_ids(log_id)
    local out={};
    if current[log_id]==nil then return out; end
    for q=0,255 do if quest_active(log_id,q)==true then out[#out+1]=q; end end
    return out;
end

local function collect_candidates(before, after, log_id)
    local out={};
    if type(before)~='string' or type(after)~='string' then return out; end
    local n=math.min(#before,#after);
    for i=1,n do
        local a,b=string.byte(before,i),string.byte(after,i);
        if a~=b then
            for bit=0,7 do
                local m=2^bit;
                local was=(a%(m*2))>=m;
                local now=(b%(m*2))>=m;
                if not was and now then out[#out+1]={log_id=log_id,byte=i,bit=bit,quest_id=(i-1)*8+bit}; end
            end
        end
    end
    return out;
end

local function commit_candidate(x)
    local c=HC.modules.state.get_char();
    maps(c)[capture.key]={log_id=x.log_id,byte=x.byte,bit=x.bit,quest_id=x.quest_id,name=capture.name};
    HC.modules.state.save();
    HC.msg(string.format('Quest flag learned and verified: %s (log %d, quest %d).',capture.name,x.log_id,x.quest_id));
    capture=nil;
end

local function bitmap_changes(before,after,log_id)
    local added,removed={},{};
    if type(before)~='string' or type(after)~='string' then return added,removed; end
    for q=0,255 do
        local byte=math.floor(q/8)+1; local bit=q%8;
        local was=bitset(before,byte,bit);
        local now=bitset(after,byte,bit);
        if now and not was then added[#added+1]=q; end
        if was and not now then removed[#removed+1]=q; end
    end
    return added,removed;
end

local function announce_live_changes(log_id,previous,p)
    if previous==nil then return; end -- first table after load/zone is baseline, not a change event
    local added,removed=bitmap_changes(previous,p,log_id);
    for _,qid in ipairs(added) do
        HC.msg(string.format('Quest accepted / active: %s - %s.',M.log_name(log_id),quest_name(log_id,qid)));
    end
    for _,qid in ipairs(removed) do
        -- Leaving ACTIVE is authoritative, but it is not by itself proof of completion.
        HC.msg(string.format('Quest left active log: %s - %s.',M.log_name(log_id),quest_name(log_id,qid)));
    end
end

local function process_learning_update(log_id,p)
    if capture==nil then return; end
    if capture.candidates==nil then
        local before=capture.before[log_id];
        local candidates=collect_candidates(before,p,log_id);
        if #candidates==0 then return; end
        capture.candidates=candidates;
        capture.log_id=log_id;
        capture.confirmations=0;
        if #candidates==1 then
            HC.msg('Quest flag candidate found for '..capture.name..'; waiting for one more 0x056 confirmation.');
        else
            HC.msg('Quest flag candidates found for '..capture.name..' ('..tostring(#candidates)..'); waiting for another 0x056 packet to narrow them down.');
        end
        return;
    end
    if log_id~=capture.log_id then return; end
    local survivors={};
    for _,x in ipairs(capture.candidates) do if bitset(p,x.byte,x.bit) then survivors[#survivors+1]=x; end end
    capture.candidates=survivors;
    if #survivors==0 then
        HC.msg('Quest flag candidate did not persist for '..capture.name..'; learning was rejected.');
        capture=nil; return;
    end
    if #survivors>1 then return; end
    capture.confirmations=(capture.confirmations or 0)+1;
    if capture.confirmations>=VERIFY_PACKETS then commit_candidate(survivors[1]); end
end

local function bitmap_to_hex(s)
    if type(s)~='string' then return nil; end
    return (s:gsub('.',function(ch) return string.format('%02X',string.byte(ch)); end));
end

local function hydrate_completed_cache(c)
    if type(c)~='table' then return; end
    if type(c.quest_native_completed)=='table' then
        for k,h in pairs(c.quest_native_completed) do
            local log=tonumber(k); local b=hex_to_bitmap(h);
            if log~=nil and b~=nil and completed[log]==nil then completed[log]=b; end
        end
    end

    -- v6.9.79+: also retain every raw 0x056 Type independently.  This makes
    -- Completed resilient even when the UI was not open when a history table
    -- arrived, and lets future builds re-derive region history from raw state.
    if type(c.quest_native_056_raw)=='table' then
        for k,h in pairs(c.quest_native_056_raw) do
            local port=tonumber(k); local b=hex_to_bitmap(h);
            local log=port and COMPLETED_PORT_TO_LOG_ID[port] or nil;
            if log~=nil and b~=nil and completed[log]==nil then
                completed[log]=b;
                c.quest_native_completed=type(c.quest_native_completed)=='table' and c.quest_native_completed or {};
                c.quest_native_completed[tostring(log)]=bitmap_to_hex(b);
            end
        end
    end
end

local function persist_raw_056_cache(c,port,p)
    if type(c)~='table' or port==nil or type(p)~='string' or #p<32 then return; end
    c.quest_native_056_raw=type(c.quest_native_056_raw)=='table' and c.quest_native_056_raw or {};
    c.quest_native_056_raw[tostring(port)]=bitmap_to_hex(p:sub(1,32));
end


local function hydrate_active_cache(c)
    if type(c)~='table' then return; end
    -- Preferred cache written by current builds.
    if type(c.quest_native_active)=='table' then
        for k,h in pairs(c.quest_native_active) do
            local log=tonumber(k); local b=hex_to_bitmap(h);
            if log~=nil and b~=nil and current[log]==nil then current[log]=b; end
        end
    end
    -- Recovery/migration path: older 6.9.79+ builds often saved the raw 0x056
    -- Type table even when quest_native_active was never populated.  Rebuild
    -- ACTIVE logs from those raw tables before declaring the view empty.
    if type(c.quest_native_056_raw)=='table' then
        c.quest_native_active=type(c.quest_native_active)=='table' and c.quest_native_active or {};
        for k,h in pairs(c.quest_native_056_raw) do
            local port=tonumber(k); local b=hex_to_bitmap(h);
            local log=port and PORT_TO_LOG_ID[port] or nil;
            if log~=nil and b~=nil then
                if current[log]==nil then current[log]=b; end
                if c.quest_native_active[tostring(log)]==nil then
                    c.quest_native_active[tostring(log)]=bitmap_to_hex(b);
                end
            end
        end
    end
end

local function persist_active_cache(c,log,p)
    if type(c)~='table' or log==nil or type(p)~='string' or #p<32 then return; end
    c.quest_native_active=type(c.quest_native_active)=='table' and c.quest_native_active or {};
    c.quest_native_active[tostring(log)]=bitmap_to_hex(p:sub(1,32));
end

local function persist_completed_cache(c,log,p)
    if type(c)~='table' or log==nil or type(p)~='string' or #p<32 then return; end
    c.quest_native_completed=type(c.quest_native_completed)=='table' and c.quest_native_completed or {};
    c.quest_native_completed[tostring(log)]=bitmap_to_hex(p:sub(1,32));
end


local function completed_coverage()
    local have,missing={},{ }
    for log=0,6 do
        if completed[log]~=nil then have[#have+1]=log else missing[#missing+1]=log end
    end
    return have,missing
end

local function missing_log_names()
    local _,missing=completed_coverage(); local out={}
    for _,log in ipairs(missing) do out[#out+1]=M.log_name(log) end
    return out
end

local function mark_history_capture(c)
    c.quest_history_capture=type(c.quest_history_capture)=='table' and c.quest_history_capture or {}
    c.quest_history_capture.started_at=os.time()
    c.quest_history_capture.last_packet_at=nil
    c.quest_history_capture.complete=false
    c.quest_history_capture.active=true
end

local function update_history_capture(c)
    if type(c)~='table' then return end
    c.quest_history_capture=type(c.quest_history_capture)=='table' and c.quest_history_capture or {}
    local have,missing=completed_coverage()
    c.quest_history_capture.coverage=#have
    c.quest_history_capture.missing=missing
    c.quest_history_capture.last_packet_at=os.time()
    if #missing==0 then
        c.quest_history_capture.complete=true
        c.quest_history_capture.active=false
        c.quest_history_capture.completed_at=os.time()
    end
end

function M.begin_completed_history_capture()
    local c=HC.modules.state.get_char();
    mark_history_capture(c);

    -- The button cannot make the server resend 0x056 by itself.  First recover
    -- any completed tables that were already observed earlier in this session.
    local recovered=0;
    for port,log in pairs(COMPLETED_PORT_TO_LOG_ID) do
        local r=raw_056[port];
        if r and type(r.bitmap)=='string' and #r.bitmap>=32 then
            if completed[log]==nil then recovered=recovered+1; end
            completed[log]=r.bitmap:sub(1,32);
            persist_completed_cache(c,log,completed[log]);
        end
    end
    update_history_capture(c);
    HC.modules.state.save();

    local have,total,missing=M.completed_history_coverage();
    if have>=total then
        HC.msg('Quest history refresh complete: 7/7 HorizonXI-era completed logs cached.');
    else
        local names={}; for _,log in ipairs(missing) do names[#names+1]=M.log_name(log); end
        HC.msg(string.format('Quest history capture ARMED: %d/%d cached%s. Missing: %s. These tables are sent by the server; zone once to request a fresh 0x056 dump.',have,total,recovered>0 and (' ('..recovered..' recovered now)') or '',table.concat(names,', ')));
    end
    return true
end

function M.completed_history_coverage()
    local have,missing=completed_coverage()
    return #have,7,missing
end

local function sync_character_cache(force)
    if not HC or not HC.modules or not HC.modules.state or not HC.modules.core then return; end
    local name=HC.modules.core.character_name();
    if type(name)~='string' or name=='' or name=='Unknown' then return; end
    if not force and hydrated_character==name then return; end

    -- Module init can run before the party manager knows the character name.
    -- Never hydrate the persistent quest cache into the temporary "Unknown"
    -- character.  As soon as the real name exists, rebuild both native views
    -- from that character's saved bitmaps.
    for k in pairs(current) do current[k]=nil; end
    for k in pairs(completed) do completed[k]=nil; end
    for k in pairs(native_seen) do native_seen[k]=nil; end

    local c=HC.modules.state.get_char();
    hydrate_completed_cache(c);
    hydrate_active_cache(c);
    hydrated_character=name;
    invalidate_progression_overview();
end

local function record_completion_transitions(c,log_id,before,after)
    if type(c)~='table' or type(before)~='string' or type(after)~='string' then return; end
    if #before<32 or #after<32 then return; end
    c.quest_completed_at=type(c.quest_completed_at)=='table' and c.quest_completed_at or {};
    local now=os.time(); local zid=current_zone_id();
    for quest_id=0,255 do
        local byte=math.floor(quest_id/8)+1;
        local bit=quest_id%8; local mask=2^bit;
        local b1=string.byte(before,byte) or 0;
        local b2=string.byte(after,byte) or 0;
        local was=(b1%(mask*2))>=mask;
        local done=(b2%(mask*2))>=mask;
        if not was and done then
            c.quest_completed_at[tostring(log_id)..':'..tostring(quest_id)]={at=now,zone_id=zid};
        end
    end
end

function M.init(ctx)
    HC=ctx;
    -- Character name may still be Unknown during addon init.  Defer cache
    -- hydration until the real character is available.
    sync_character_cache(false);
    HC.modules.packets.register(0x056,'native quest log',function(e)
        -- v6.9.86: proven Ashita event-table packet path restored. Report exactly what
        -- delivered for every 0x056 and whether HorizonCheck classified/cached it.
        -- Ashita's packet event is not guaranteed to report Lua type 'table'.
        -- Access its fields directly (the same way official Ashita v4 addons do)
        -- and only validate the packet data itself.
        local data=nil;
        local ok_data,val=pcall(function() return e and e.data end);
        if ok_data then data=val; end
        local dtype=type(data);
        local dlen=(dtype=='string') and #data or 0;
        if dtype~='string' then
            HC.msg(string.format('QUEST056 RX: event=%s data=%s len=%d | REJECT no string data',type(e),dtype,tonumber(dlen) or 0));
            return;
        end
        if #data<40 then
            HC.msg(string.format('QUEST056 RX: event=%s data=string len=%d | REJECT short packet',type(e),#data));
            return;
        end

        sync_character_cache(false);
        local port=u16le(data,37);
        local p=data:sub(5,36);
        local active_log=port and PORT_TO_LOG_ID[port] or nil;
        local completed_log=port and COMPLETED_PORT_TO_LOG_ID[port] or nil;
        local class='UNKNOWN'; local log=nil;
        if completed_log~=nil then class='COMPLETED'; log=completed_log;
        elseif active_log~=nil then class='ACTIVE'; log=active_log; end

        local bits=0;
        if #p==32 then
            for i=1,32 do
                local b=string.byte(p,i) or 0;
                for bit=0,7 do local m=2^bit; if (b%(m*2))>=m then bits=bits+1; end end
            end
        end
        local cname=(HC.modules.core and HC.modules.core.character_name and HC.modules.core.character_name()) or '?';

        if port==nil or #p~=32 then
            return;
        end

        local c=HC.modules.state.get_char();
        persist_raw_056_cache(c,port,p);
        local r=raw_056[port] or {count=0};
        r.bitmap=p; r.seen=os.time(); r.count=(r.count or 0)+1; raw_056[port]=r;

        if completed_log~=nil then
            -- Persist COMPLETED immediately.  Older builds attempted to build a
            -- Recently Unlocked snapshot here using a render-local helper; that
            -- raised an error before the completed bitmap could ever be cached.
            local previous=completed[completed_log];
            completed[completed_log]=p;
            invalidate_progression_overview();
            record_completion_transitions(c,completed_log,previous,p);
            persist_completed_cache(c,completed_log,p);
            update_history_capture(c);
            request_state_save(1);
            for _,fn in ipairs(completed_listeners) do pcall(fn,completed_log,previous,p); end
            return;
        end

        if active_log==nil then
            request_state_save(1);
            return;
        end

        local previous=current[active_log];
        current[active_log]=p;
        invalidate_progression_overview();
        persist_active_cache(c,active_log,p);
        native_seen[active_log]=os.time();
        process_learning_update(active_log,p);
        announce_live_changes(active_log,previous,p);
        for _,fn in ipairs(listeners) do pcall(fn,active_log,previous,p); end
        request_state_save(1);
    end);
end

function M.register_update(fn)
    if type(fn)~='function' then return false; end
    listeners[#listeners+1]=fn;
    return true;
end
function M.register_completed_update(fn)
    if type(fn)~='function' then return false; end
    completed_listeners[#completed_listeners+1]=fn;
    return true;
end

function M.is_active(log_id,quest_id) sync_character_cache(false); return quest_active(log_id,quest_id); end
function M.active_ids(log_id) sync_character_cache(false); return active_ids(tonumber(log_id)); end
function M.log_name(log_id) return LOG_NAMES[tonumber(log_id)] or ('Log '..tostring(log_id)); end
function M.quest_name(log_id,quest_id) return quest_name(log_id,quest_id); end
function M.tables_seen()
    sync_character_cache(false);
    local n=0; for _ in pairs(current) do n=n+1; end return n;
end
function M.last_verified_at()
    local t=0; for _,v in pairs(native_seen) do if tonumber(v) and tonumber(v)>t then t=tonumber(v); end end
    return t>0 and t or nil;
end

function M.status(c,key)
    local m=maps(c)[key];
    if type(m)~='table' then
        if capture and capture.key==key then return capture.candidates and 'VERIFYING FLAG' or 'LEARNING'; end
        return 'UNLEARNED';
    end
    local log_id=tonumber(m.log_id or m.subtype);
    local qid=tonumber(m.quest_id);
    if qid==nil and m.byte and m.bit then qid=(tonumber(m.byte)-1)*8+tonumber(m.bit); end
    local v=quest_active(log_id,qid);
    if v==nil then return 'WAITING FOR 0x056'; end
    return v and 'FLAGGED / ACTIVE' or 'NOT FLAGGED';
end

function M.learn(key)
    if tracked[key]==nil then return false; end
    local snap={}; for log_id,p in pairs(current) do snap[log_id]=p; end
    capture={key=key,name=tracked[key].name,before=snap,candidates=nil,confirmations=0};
    HC.msg('Quest learn armed for '..tracked[key].name..'. Flag it now, then wait for another 0x056 update or zone once.');
    return true;
end

function M.clear_learned(key)
    if tracked[key]==nil then return false; end
    local c=HC.modules.state.get_char(); maps(c)[key]=nil; HC.modules.state.save();
    HC.msg('Cleared learned quest flag: '..tracked[key].name); return true;
end

local function ids_string(ids,maxn)
    maxn=maxn or 24;
    if #ids==0 then return '(none)'; end
    local out={};
    for i=1,math.min(#ids,maxn) do out[#out+1]=tostring(ids[i]); end
    if #ids>maxn then out[#out+1]='+'..tostring(#ids-maxn)..' more'; end
    return table.concat(out,', ');
end


local function completed_ids(log_id)
    local out={}; local p=completed[tonumber(log_id)];
    if p==nil then return out; end
    for q=0,255 do
        local byte=math.floor(q/8)+1; local bit=q%8;
        if bitset(p,byte,bit) then out[#out+1]=q; end
    end
    return out;
end

function M.is_completed(log_id,quest_id)
    log_id=tonumber(log_id); quest_id=tonumber(quest_id);
    local p=completed[log_id];
    if p==nil or quest_id==nil or quest_id<0 or quest_id>255 then return nil; end
    local policy=canonical_native_policy(log_id,quest_id);
    if policy=='BLOCK' or quest_catalog_disabled(log_id,quest_id,policy) then return false; end
    local raw=bitset(p,math.floor(quest_id/8)+1,quest_id%8);
    if raw==true and policy=='QUARANTINE' then return nil; end
    return raw;
end

function M.raw_native_state(log_id,quest_id,skip_sync)
    if skip_sync~=true then sync_character_cache(false); end
    log_id=tonumber(log_id); quest_id=tonumber(quest_id);
    if log_id==nil or quest_id==nil or quest_id<0 or quest_id>255 then return nil; end
    local a=nil; local d=nil;
    if type(current[log_id])=='string' then a=bitset(current[log_id],math.floor(quest_id/8)+1,quest_id%8); end
    if type(completed[log_id])=='string' then d=bitset(completed[log_id],math.floor(quest_id/8)+1,quest_id%8); end
    local policy,reason,record=canonical_native_policy(log_id,quest_id);
    return {log_id=log_id,quest_id=quest_id,active=a,completed=d,policy=policy,reason=reason,canonical=record,
        active_table=(type(current[log_id])=='string'),completed_table=(type(completed[log_id])=='string')};
end

function M.sync_native_cache(force) return sync_character_cache(force==true); end
function M.completed_ids(log_id) return completed_ids(tonumber(log_id)); end

function M.completed_tables_seen()
    local n=0; for _ in pairs(completed) do n=n+1; end return n;
end

function M.completed_probe()
    local ports={}; for port in pairs(raw_056) do ports[#ports+1]=port; end
    table.sort(ports);
    HC.msg('Completed Quest Probe: 0x056 types seen this session = '..tostring(#ports));
    for _,port in ipairs(ports) do
        local active_log=PORT_TO_LOG_ID[port]; local done_log=COMPLETED_PORT_TO_LOG_ID[port];
        local kind='UNKNOWN'; local label='unmapped'; local ids={};
        if active_log~=nil then kind='ACTIVE'; label=M.log_name(active_log); ids=active_ids(active_log);
        elseif done_log~=nil then kind='COMPLETED'; label=M.log_name(done_log); ids=completed_ids(done_log); end
        HC.msg(string.format('  Type 0x%04X | %s | %s | %d bits set | IDs: %s',port,kind,label,#ids,ids_string(ids,16)));
    end
    for log=0,10 do
        if completed[log] then
            local ids=completed_ids(log);
            HC.msg(string.format('  COMPLETED %s: %d | %s',M.log_name(log),#ids,ids_string(ids,12)));
        end
    end
    return true;
end

function M.probe(log_id,quest_id)
    if log_id~=nil and quest_id~=nil then
        local v=quest_active(log_id,quest_id);
        HC.msg(string.format('Quest probe: %s log=%d quest=%d => %s',M.log_name(log_id),tonumber(log_id),tonumber(quest_id),v==nil and 'WAITING FOR 0x056' or (v and 'ACTIVE' or 'NOT ACTIVE')));
        return v;
    end
    HC.msg('Quest State Probe: native 0x056 logs seen this session = '..tostring(M.tables_seen()));
    for log=0,10 do
        if current[log] then
            local ids=active_ids(log);
            HC.msg(string.format('  %s [%d]: %d active | IDs: %s',M.log_name(log),log,#ids,ids_string(ids,12)));
        end
    end
    for _,q in ipairs(PROBE_QUESTS) do
        local v=quest_active(q.log_id,q.quest_id);
        HC.msg(string.format('  anchor %s: %s',q.name,v==nil and 'WAITING' or (v and 'ACTIVE' or 'NOT ACTIVE')));
    end
    return true;
end

function M.command(w)
    local cmd=string.lower(w[2] or '');
    if cmd=='questlearn' then
        local a=string.lower(w[3] or '');
        local alias={chocobo='chocobo_riding',spice='spice_gals',cookbook='ovens_lost',ovens='ovens_lost',ovens_lost='ovens_lost'};
        if not M.learn(alias[a] or a) then HC.msg('Unknown tracked quest.'); end
        return true;
    elseif cmd=='questclear' then
        local a=string.lower(w[3] or '');
        local alias={chocobo='chocobo_riding',spice='spice_gals',cookbook='ovens_lost',ovens='ovens_lost',ovens_lost='ovens_lost'};
        if not M.clear_learned(alias[a] or a) then HC.msg('Unknown tracked quest.'); end
        return true;
    elseif cmd=='completedquests' or cmd=='questcompleted' or cmd=='completedprobe' then
        M.completed_probe(); return true;
    elseif cmd=='questhistory' or cmd=='historycapture' then
        M.begin_completed_history_capture(); return true;
    elseif cmd=='questprobe' or cmd=='quests' then
        local log=tonumber(w[3]); local q=tonumber(w[4]);
        M.probe(log,q); return true;
    end
    return false;
end


function M.actionable_rows(c)
    c=c or HC.modules.state.get_char();
    local rows={};
    for log=0,10 do
        if current[log] then
            for _,qid in ipairs(active_ids(log)) do
                local st=automated_status(c,log,qid);
                if st and is_actionable_badge(st) then
                    local det=metadata_for(log,qid) or {};
                    rows[#rows+1]={
                        log_id=log, quest_id=qid,
                        name=quest_name(log,qid),
                        status=st,
                        text=quest_name(log,qid)..' - '..st,
                        zone=tostring(det.start_zone or ''),
                        here=quest_starts_in_current_zone(det),
                    };
                end
            end
        end
    end
    return rows;
end

-- Keep the very large quest UI below Lua 5.1/Ashita's 60-upvalue function limit.
-- Route module-local helpers through one table so M.draw captures a single helper upvalue.
local DRAW_HELPERS = {
    active_ids = active_ids,
    automated_status = automated_status,
    availability_state = availability_state,
    available_log_supported = available_log_supported,
    avatar_unlock_progress = avatar_unlock_progress,
    catalog_completeness = catalog_completeness,
    catalog_field_missing = catalog_field_missing,
    catalog_ids = catalog_ids,
    catalog_quality_issues = catalog_quality_issues,
    catalog_quality_score = catalog_quality_score,
    catalog_quality_verified = catalog_quality_verified,
    catalog_source_verified = catalog_source_verified,
    catalog_status = catalog_status,
    completed_ids = completed_ids,
    current_main_job_level = current_main_job_level,
    current_party_snapshot = current_party_snapshot,
    current_status_names = current_status_names,
    current_zone_name = current_zone_name,
    quest_starts_in_current_zone = quest_starts_in_current_zone,
    contextual_fame_profile = contextual_fame_profile,
    auto_reputation_manual_flag = auto_reputation_manual_flag,
    auto_manual_flag_state = auto_manual_flag_state,
    apply_safe_quest_autofixes = apply_safe_quest_autofixes,
    dependent_quests = dependent_quests,
    equipped_item_name_set = equipped_item_name_set,
    historical_rank = historical_rank,
    inferred_city_fame_floor = inferred_city_fame_floor,
    inventory_item_count = inventory_item_count,
    is_actionable_badge = is_actionable_badge,
    latest_zone_refresh_at = latest_zone_refresh_at,
    live_job_level = live_job_level,
    maat_job_progress = maat_job_progress,
    manual_condition_flag = manual_condition_flag,
    manual_craft_skill_level = manual_craft_skill_level,
    manual_fame_level = manual_fame_level,
    manual_flag_parts = manual_flag_parts,
    manual_mercenary_points = manual_mercenary_points,
    manual_mercenary_rank = manual_mercenary_rank,
    manual_reputation_level = manual_reputation_level,
    manual_requirement_state = manual_requirement_state,
    manual_weapon_skill_level = manual_weapon_skill_level,
    manual_world_presence = manual_world_presence,
    mercenary_rank_index = mercenary_rank_index,
    native_quest_is_active = native_quest_is_active,
    native_quest_started_or_completed = native_quest_started_or_completed,
    next_jst_midnight_epoch = next_jst_midnight_epoch,
    quest_active = quest_active,
    quest_completion_record = quest_completion_record,
    quest_detail = quest_detail,
    quest_key = quest_key,
    quest_matches_filter = quest_matches_filter,
    quest_name = quest_name,
    region_catalog_stats = region_catalog_stats,
    region_quality_stats = region_quality_stats,
    repeat_tag = repeat_tag,
    automated_def = automated_def,
    quest_is_repeatable = quest_is_repeatable,
    repeatable_status = repeatable_status,
    write_quest_state_report = write_quest_state_report,
    requirements_search_text = requirements_search_text,
    requirement_reason_category = requirement_reason_category,
    requirement_source_summary = requirement_source_summary,
    dependent_quest_count = dependent_quest_count,
    priority_score = priority_score,
    progression_overview = progression_overview,
    quest_self_audit = quest_self_audit,
    sort_rows = sort_rows,
    tags_text = tags_text,
    update_quest_zone_state = update_quest_zone_state,
};

function M.draw(c)
    local imgui=HC.imgui;
    c=c or HC.modules.state.get_char();
    DRAW_HELPERS.update_quest_zone_state(c);
    c.settings=type(c.settings)=='table' and c.settings or {};
    c.settings.quest_region_open=type(c.settings.quest_region_open)=='table' and c.settings.quest_region_open or {};
    c.settings.quest_completed_region_open=type(c.settings.quest_completed_region_open)=='table' and c.settings.quest_completed_region_open or {};
    c.settings.quest_available_region_open=type(c.settings.quest_available_region_open)=='table' and c.settings.quest_available_region_open or {};
    c.settings.quest_quality_region_open=type(c.settings.quest_quality_region_open)=='table' and c.settings.quest_quality_region_open or {};
    c.settings.quest_verify_region_open=type(c.settings.quest_verify_region_open)=='table' and c.settings.quest_verify_region_open or {};
    c.settings.quest_detail_history=type(c.settings.quest_detail_history)=='table' and c.settings.quest_detail_history or {};
    if c.settings.quest_automated_only==nil then c.settings.quest_automated_only=false; end
    if c.settings.quest_ready_only==nil then c.settings.quest_ready_only=false; end
    if type(c.settings.quest_search)~='string' then c.settings.quest_search=''; end
    if c.settings.quest_view~='completed' and c.settings.quest_view~='available' and c.settings.quest_view~='locked' and c.settings.quest_view~='attention' and c.settings.quest_view~='verify' and c.settings.quest_view~='quality' and c.settings.quest_view~='reward_search' then c.settings.quest_view='active'; end
    if c.settings.quest_show_unknown_available==nil then c.settings.quest_show_unknown_available=true; end
    if c.settings.quest_ready_now_only==nil then c.settings.quest_ready_now_only=false; end
    c.settings.quest_locked_region_open=type(c.settings.quest_locked_region_open)=='table' and c.settings.quest_locked_region_open or {};
    if type(c.settings.quest_detail_selected)~='string' then c.settings.quest_detail_selected=''; end
    if c.settings.quest_mapped_only==nil then c.settings.quest_mapped_only=false; end
    if c.settings.quest_catalog_gaps_only==nil then c.settings.quest_catalog_gaps_only=false; end
    if type(c.settings.quest_missing_filter)~='string' then c.settings.quest_missing_filter='all'; end
    if type(c.settings.quest_expansion_filter)~='string' then c.settings.quest_expansion_filter='all'; end
    if type(c.settings.quest_sort)~='string' then c.settings.quest_sort='smart'; end
    if type(c.settings.quest_active_sort)~='string' then c.settings.quest_active_sort='smart'; end
    if type(c.settings.quest_ready_sort)~='string' then c.settings.quest_ready_sort='smart'; end
    if type(c.settings.quest_ready_zone_only)~='boolean' then c.settings.quest_ready_zone_only=false; end
    if type(c.settings.quest_quality_filter)~='string' then c.settings.quest_quality_filter='all'; end
    if type(c.settings.quest_check_filter)~='string' then c.settings.quest_check_filter='all'; end
    if type(c.settings.quest_manual_filter)~='string' then c.settings.quest_manual_filter='all'; end
    if type(c.settings.quest_show_catalog_diagnostics)~='boolean' then c.settings.quest_show_catalog_diagnostics=false; end
    if type(c.settings.quest_show_self_audit)~='boolean' then c.settings.quest_show_self_audit=false; end
    if type(c.settings.quest_locked_filter)~='string' then c.settings.quest_locked_filter='all'; end
    if type(c.settings.quest_ui_advanced)~='boolean' then c.settings.quest_ui_advanced=false; end
    if type(c.settings.quest_split_view)~='boolean' then c.settings.quest_split_view=true; end
    -- v6.80.1: restore the browse-left/details-right layout for existing v6.80.0
    -- profiles.  The migration runs once; users can still disable it afterward.
    if tonumber(c.settings.quest_ui_layout_version or 0)<2 then
        c.settings.quest_split_view=true;
        c.settings.quest_ui_layout_version=2;
    end
    if c.settings.quest_candidate_mode~='ready' and c.settings.quest_candidate_mode~='check' and c.settings.quest_candidate_mode~='all' then
        c.settings.quest_candidate_mode='ready';
    end

    -- v7.6.1: external Go/navigation actions that target a quest should open
    -- that quest's Details immediately after the Quests tab becomes selected.
    -- Previously ui.navigate() selected the tab but Quests never consumed its
    -- focus payload, so the requested quest was not selected in the details pane.
    local navigation_focus=(HC.modules.ui and HC.modules.ui.consume_focus) and HC.modules.ui.consume_focus('quests') or nil;
    if type(navigation_focus)=='table' then
        local focus_log=tonumber(navigation_focus.log_id);
        local focus_qid=tonumber(navigation_focus.quest_id);
        if (focus_log==nil or focus_qid==nil) and tostring(navigation_focus.name or '')~='' then
            local wanted=string.lower(tostring(navigation_focus.name or ''));
            for log=0,6 do
                if focus_log~=nil and log~=focus_log then
                    -- Keep an explicitly supplied log restriction while resolving by name.
                elseif DRAW_HELPERS.available_log_supported(log) then
                    for _,qid in ipairs(DRAW_HELPERS.catalog_ids(log)) do
                        if string.lower(tostring(DRAW_HELPERS.quest_name(log,qid) or ''))==wanted then
                            focus_log=log; focus_qid=qid; break;
                        end
                    end
                end
                if focus_qid~=nil then break; end
            end
        end
        if focus_log~=nil and focus_qid~=nil then
            c.settings.quest_detail_selected=DRAW_HELPERS.quest_key(focus_log,focus_qid);
            c.settings.quest_detail_history={};
            -- Keep the external navigation lightweight; the selected detail is
            -- useful immediately even if the quest is filtered out of the left list.
            if HC.modules.state and HC.modules.state.request_save then HC.modules.state.request_save(1); end
        end
    end
    -- Simple mode is intentionally deterministic for first-time and shared users.
    -- Advanced-only filters must never silently hide quests after a state file is copied.
    if not c.settings.quest_ui_advanced then
        c.settings.quest_mapped_only=false;
        c.settings.quest_catalog_gaps_only=false;
        c.settings.quest_missing_filter='all';
        c.settings.quest_expansion_filter='all';
        c.settings.quest_quality_filter='all';
        c.settings.quest_manual_filter='all';
        c.settings.quest_sort='smart';
        -- Active / Ready have their own normal browse sort preferences and are
        -- intentionally not reset here.
    end
    c.quest_fame_overrides=type(c.quest_fame_overrides)=='table' and c.quest_fame_overrides or {};
    c.quest_manual_requirements=type(c.quest_manual_requirements)=='table' and c.quest_manual_requirements or {};
    c.quest_reputation_overrides=type(c.quest_reputation_overrides)=='table' and c.quest_reputation_overrides or {};
    c.quest_weapon_skill_overrides=type(c.quest_weapon_skill_overrides)=='table' and c.quest_weapon_skill_overrides or {};
    c.quest_craft_skill_overrides=type(c.quest_craft_skill_overrides)=='table' and c.quest_craft_skill_overrides or {};
    c.quest_maat_job_wins=type(c.quest_maat_job_wins)=='table' and c.quest_maat_job_wins or {};
    c.quest_maat_job_win_meta=type(c.quest_maat_job_win_meta)=='table' and c.quest_maat_job_win_meta or {};
    c.quest_avatar_unlocks=type(c.quest_avatar_unlocks)=='table' and c.quest_avatar_unlocks or {};
    c.quest_condition_flags=type(c.quest_condition_flags)=='table' and c.quest_condition_flags or {};
    c.quest_completed_at=type(c.quest_completed_at)=='table' and c.quest_completed_at or {};
    if c.quest_mercenary_rank_points~=nil then
        c.quest_mercenary_rank_points=math.max(0,math.min(25,math.floor(tonumber(c.quest_mercenary_rank_points) or 0)));
    end
    if c.quest_mercenary_rank_index~=nil then
        c.quest_mercenary_rank_index=DRAW_HELPERS.mercenary_rank_index(c.quest_mercenary_rank_index);
    end
    c.quest_world_presence=type(c.quest_world_presence)=='table' and c.quest_world_presence or {};
    if type(c.quest_ws_trial_clear)~='boolean' then c.quest_ws_trial_clear=false; end
    local manual_confirmed=0;
    for _,mv in pairs(c.quest_manual_requirements) do
        if type(mv)=='table' and mv.satisfied==true then manual_confirmed=manual_confirmed+1; end
    end
    local condition_confirmed=0;
    for _,mv in pairs(c.quest_condition_flags) do
        if mv==true or (type(mv)=='table' and mv.satisfied==true) then condition_confirmed=condition_confirmed+1; end
    end

    local seen=M.tables_seen();
    local completed_seen=M.completed_tables_seen();
    local total_active,total_completed,total_remaining,total_available,total_check,total_manual,total_locked,total_unknown,auto_count,ready_count,attention_count=0,0,0,0,0,0,0,0,0,0,0;
    local total_available_here=0;
    for log=0,10 do
        if current[log] then
            for _,qid in ipairs(DRAW_HELPERS.active_ids(log)) do
                total_active=total_active+1;
                local st,is_auto=DRAW_HELPERS.automated_status(c,log,qid);
                if is_auto then auto_count=auto_count+1; end
                if st and DRAW_HELPERS.is_actionable_badge(st) then ready_count=ready_count+1; end
                local det=DRAW_HELPERS.quest_detail(log,qid); if DRAW_HELPERS.is_actionable_badge(st) or (det and det.next_step and det.next_step~='') then attention_count=attention_count+1; end
            end
        end
        if completed[log] then total_completed=total_completed+#DRAW_HELPERS.completed_ids(log); end
        if DRAW_HELPERS.available_log_supported(log) then
            for _,qid in ipairs(DRAW_HELPERS.catalog_ids(log)) do
                local is_repeatable=DRAW_HELPERS.quest_is_repeatable(log,qid);
                if DRAW_HELPERS.quest_active(log,qid)~=true and (M.is_completed(log,qid)~=true or is_repeatable) then
                    total_remaining=total_remaining+1;
                    local av=DRAW_HELPERS.availability_state(c,log,qid);
                    if av=='AVAILABLE' then
                        total_available=total_available+1;
                        local det=DRAW_HELPERS.quest_detail(log,qid);
                        if DRAW_HELPERS.quest_starts_in_current_zone(det) then total_available_here=total_available_here+1; end
                    elseif av=='CHECK' then total_check=total_check+1
                    elseif av=='MANUAL' then total_manual=total_manual+1
                    elseif av=='LOCKED' then total_locked=total_locked+1
                    else total_unknown=total_unknown+1 end
                end
            end
        end
    end

    local profile_name=(HC.modules.state and HC.modules.state.profile_name and HC.modules.state.profile_name()) or
        ((HC.modules.core and HC.modules.core.character_name and HC.modules.core.character_name()) or 'Unknown');
    local profile_ready=(HC.modules.state and HC.modules.state.profile_ready and HC.modules.state.profile_ready()) or (profile_name~='Unknown');
    imgui.Text('Quest Profile: '..tostring(profile_name));
    imgui.SameLine();
    imgui.TextDisabled(profile_ready and '(character-specific data)' or '(waiting for character login - changes are temporary)');

    local history_have,history_total,history_missing=M.completed_history_coverage();
    local mapped,complete,partial,basic=0,0,0,0;
    local source_verified,qgold,qsilver,qbronze,qreview=0,0,0,0,0;
    local req_full,req_partial,req_manual,req_empty=0,0,0,0;
    for log=0,6 do
        for _,qid in ipairs(DRAW_HELPERS.catalog_ids(log)) do
            mapped=mapped+1;
            local det=DRAW_HELPERS.quest_detail(log,qid);
            local st=DRAW_HELPERS.catalog_status(det);
            if st=='COMPLETE' then complete=complete+1 elseif st=='PARTIAL' then partial=partial+1 else basic=basic+1 end
            if DRAW_HELPERS.catalog_source_verified(det) then source_verified=source_verified+1; end
            local _,_,ql=DRAW_HELPERS.catalog_quality_score(det);
            if ql=='GOLD' then qgold=qgold+1 elseif ql=='SILVER' then qsilver=qsilver+1 elseif ql=='BRONZE' then qbronze=qbronze+1 else qreview=qreview+1 end
            local req=(type(det)=='table' and type(det.requirements)=='table') and det.requirements or {};
            local custom=string.lower(tostring(req.custom or ''));
            if det and det.requirements_mapped==true then req_full=req_full+1
            elseif custom:find('manual prerequisite check:',1,true) then req_manual=req_manual+1
            elseif next(req)~=nil then req_partial=req_partial+1
            else req_empty=req_empty+1 end
        end
    end
    local enriched=complete+partial;
    local high_quality=qgold+qsilver;
    local catalog_ready=(mapped>0 and enriched==mapped and req_full==mapped and high_quality==mapped and source_verified==mapped);
    M._last_summary={
        active=total_active, ready=total_available, check=total_check, manual=total_manual, locked=total_locked, completed=total_completed,
        mapped=mapped, source_verified=source_verified, catalog_ready=catalog_ready,
        history_have=history_have, history_total=history_total,
    };

    if history_have<history_total then
        imgui.TextDisabled(string.format('Quest history needs initialization: %d/%d logs cached.',history_have,history_total));
        imgui.SameLine();
        if imgui.Button('Refresh History##quest_history_capture') then M.begin_completed_history_capture(); end
        local cap=HC.modules.state.get_char().quest_history_capture;
        if type(cap)=='table' and cap.active then imgui.SameLine(); imgui.Text('ARMED'); end
        if #history_missing>0 then
            local names={}; for _,log in ipairs(history_missing) do names[#names+1]=M.log_name(log); end
            imgui.TextDisabled('Zone once while ARMED to receive: '..table.concat(names,', ')..'.');
        end
    end

    if c.settings.quest_ui_advanced then
        imgui.TextDisabled('Advanced tools are configured from Settings.');
        imgui.SameLine();
    end
    if imgui.Button('Reset Quest Tab##quest_ui_reset') then
        c.settings.quest_view='active';
        c.settings.quest_candidate_mode='ready';
        c.settings.quest_search='';
        c.settings.quest_check_filter='all';
        c.settings.quest_manual_filter='all';
        c.settings.quest_automated_only=false;
        c.settings.quest_ready_only=false;
        c.settings.quest_mapped_only=false;
        c.settings.quest_catalog_gaps_only=false;
        c.settings.quest_missing_filter='all';
        c.settings.quest_expansion_filter='all';
        c.settings.quest_quality_filter='all';
        c.settings.quest_sort='smart';
        c.settings.quest_ready_zone_only=false;
        c.settings.quest_split_view=true;
        c.settings.quest_ui_layout_version=2;
        c.settings.quest_detail_selected='';
        c.settings.quest_detail_history={};
        HC.modules.state.save();
    end
    if imgui.IsItemHovered~=nil and imgui.IsItemHovered() then
        imgui.SetTooltip('Resets only this character\'s Quest-tab view, search, and filters. Quest history and evidence profiles are preserved.');
    end
    if c.settings.quest_ui_advanced and imgui.CollapsingHeader('Catalog & Data Health##quest_catalog_health') then
        local pct=(mapped>0) and math.floor((enriched*100/mapped)+0.5) or 0;
        local hqpct=(mapped>0) and math.floor((high_quality*100/mapped)+0.5) or 0;
        local reqpct=(mapped>0) and math.floor((req_full*100/mapped)+0.5) or 0;
        local srcpct=(mapped>0) and math.floor((source_verified*100/mapped)+0.5) or 0;
        imgui.TextDisabled(string.format('History: %d/%d logs cached | Catalog: %d/%d enriched (%d%%)',history_have,history_total,enriched,mapped,pct));
        imgui.TextDisabled(string.format('Prerequisites: %d/%d structured (%d%%) | backlog %d partial / %d manual / %d empty',req_full,mapped,reqpct,req_partial,req_manual,req_empty));
        imgui.TextDisabled(string.format('Quality: %d/%d Gold+Silver (%d%%) | Gold %d / Silver %d / Bronze %d / Review %d',high_quality,mapped,hqpct,qgold,qsilver,qbronze,qreview));
        imgui.TextDisabled(string.format('Verified source provenance: %d/%d (%d%%)',source_verified,mapped,srcpct));
        if history_have==history_total then
            if imgui.Button('Recapture Completed History##quest_history_capture_advanced') then M.begin_completed_history_capture(); end
        end
    end

    if seen==0 and completed_seen==0 then
        imgui.TextDisabled('Waiting for quest data - zone once after loading HorizonCheck.');
        imgui.TextDisabled('The native 0x056 active/completed quest tables are normally received during zone-in.');
        return;
    end

    local verified=M.last_verified_at();
    if verified then imgui.TextDisabled('Quest log verified this session at '..os.date('%H:%M:%S',verified)..'.'); end

    local function open_quest_detail(log,qid)
        local key=DRAW_HELPERS.quest_key(log,qid);
        local cur=tostring(c.settings.quest_detail_selected or '');
        if cur~='' and cur~=key then
            local hist=c.settings.quest_detail_history;
            if hist[#hist]~=cur then hist[#hist+1]=cur; end
            while #hist>12 do table.remove(hist,1); end
        end
        c.settings.quest_detail_selected=key;
        HC.modules.state.save();
    end

    local function back_quest_detail()
        local hist=c.settings.quest_detail_history;
        if #hist==0 then return false; end
        c.settings.quest_detail_selected=tostring(table.remove(hist) or '');
        HC.modules.state.save();
        return true;
    end

    local function lock_reason_category(reason,det)
        return DRAW_HELPERS.requirement_reason_category(reason,det);
    end


    local check_categories={Fame=0,Reputation=0,Rank=0,['Skill/Trial']=0,['World State']=0,Party=0,['Job/Level']=0,['Previous Quest']=0,Mission=0,['Key Item']=0,['Mixed/Manual']=0,Other=0};
    if total_check>0 then
        for log=0,6 do
            if DRAW_HELPERS.available_log_supported(log) then
                for _,qid in ipairs(DRAW_HELPERS.catalog_ids(log)) do
                    if DRAW_HELPERS.quest_active(log,qid)~=true and M.is_completed(log,qid)~=true then
                        local av,reason=DRAW_HELPERS.availability_state(c,log,qid);
                        if av=='CHECK' then
                            local cat=lock_reason_category(reason,DRAW_HELPERS.quest_detail(log,qid));
                            check_categories[cat]=(check_categories[cat] or 0)+1;
                        end
                    end
                end
            end
        end
    end

    local locked_categories={Fame=0,Reputation=0,Rank=0,['Skill/Trial']=0,['World State']=0,Party=0,['Job/Level']=0,['Previous Quest']=0,Mission=0,['Key Item']=0,['Mixed/Manual']=0,Other=0};
    if total_locked>0 then
        for log=0,6 do
            if DRAW_HELPERS.available_log_supported(log) then
                for _,qid in ipairs(DRAW_HELPERS.catalog_ids(log)) do
                    if DRAW_HELPERS.quest_active(log,qid)~=true and M.is_completed(log,qid)~=true then
                        local av,reason=DRAW_HELPERS.availability_state(c,log,qid);
                        if av=='LOCKED' then
                            local cat=lock_reason_category(reason,DRAW_HELPERS.quest_detail(log,qid));
                            locked_categories[cat]=(locked_categories[cat] or 0)+1;
                        end
                    end
                end
            end
        end
    end

    -- Compact view selector.  Ready and Check are separate so first-time users
    -- do not have to understand the old combined Candidates view.
    local function select_quest_view(view,mode)
        c.settings.quest_view=view;
        if mode then
            c.settings.quest_candidate_mode=mode;
            c.settings.quest_ready_now_only=(mode=='ready');
            c.settings.quest_show_unknown_available=(mode~='ready');
        end
        HC.modules.state.save();
    end
    local function quest_nav_button(label,id,selected,view,mode)
        local text=(selected and ('['..label..']') or label)..'##'..id;
        if imgui.Button(text) then select_quest_view(view,mode); end
    end

    local candidate_mode=tostring(c.settings.quest_candidate_mode or 'ready');
    quest_nav_button('Active '..total_active,'quest_view_active',c.settings.quest_view=='active','active');
    imgui.SameLine();
    quest_nav_button('Ready '..total_available,'quest_view_ready',c.settings.quest_view=='available' and candidate_mode=='ready','available','ready');
    imgui.SameLine();
    quest_nav_button('Check '..(total_check+total_manual),'quest_view_check',c.settings.quest_view=='available' and candidate_mode=='check','available','check');
    imgui.SameLine();
    quest_nav_button('Locked '..total_locked,'quest_view_locked',c.settings.quest_view=='locked','locked');
    imgui.SameLine();
    quest_nav_button('Completed '..total_completed,'quest_view_completed',c.settings.quest_view=='completed','completed');
    imgui.SameLine();
    quest_nav_button('Reward Search','quest_view_reward_search',c.settings.quest_view=='reward_search','reward_search');

    if c.settings.quest_view=='locked' then
        imgui.TextDisabled('Locked reason filter:');
        local lock_buttons={{'All','all'},{'Fame','Fame'},{'Reputation','Reputation'},{'Rank','Rank'},{'Job/Level','Job/Level'},{'Skill/Trial','Skill/Trial'},{'Previous Quest','Previous Quest'},{'Mission','Mission'},{'Key Item','Key Item'},{'World State','World State'},{'Party','Party'},{'Other','Other'}};
        for i,b in ipairs(lock_buttons) do
            local cnt=(b[2]=='all') and total_locked or tonumber(locked_categories[b[2]] or 0);
            if b[2]=='all' or cnt>0 then
                local selected=(tostring(c.settings.quest_locked_filter or 'all')==b[2]);
                local lab=(selected and ('['..b[1]..' '..tostring(cnt)..']') or (b[1]..' '..tostring(cnt)))..'##quest_locked_filter_'..tostring(i);
                if imgui.Button(lab) then c.settings.quest_locked_filter=b[2]; HC.modules.state.save(); end
                imgui.SameLine();
            end
        end
        imgui.NewLine();
    end

    if c.settings.quest_ui_advanced then
        quest_nav_button('All Candidates '..(total_available+total_check+total_manual),'quest_view_candidates_all',c.settings.quest_view=='available' and candidate_mode=='all','available','all');
        imgui.SameLine();
        quest_nav_button('Next Steps '..attention_count,'quest_view_attention',c.settings.quest_view=='attention','attention');
        imgui.SameLine();
        quest_nav_button('Unmapped '..total_unknown,'quest_view_verify',c.settings.quest_view=='verify','verify');
        imgui.SameLine();
        quest_nav_button('Quality Audit','quest_view_quality',c.settings.quest_view=='quality','quality');
    elseif total_unknown>0 then
        quest_nav_button('Unmapped '..total_unknown,'quest_view_verify_simple',c.settings.quest_view=='verify','verify');
    end

    if c.settings.quest_view=='active' then
        imgui.TextDisabled(string.format('%d automated | %d ready to act | %d have mapped next steps',auto_count,ready_count,attention_count));
    elseif c.settings.quest_view=='attention' then
        imgui.TextDisabled(string.format('%d active quests have a mapped next step; this is coverage, not an error count.',attention_count));
    elseif c.settings.quest_view=='verify' then
        imgui.TextDisabled(string.format('%d quests have genuinely unmapped prerequisite metadata.',total_unknown));
    elseif c.settings.quest_view=='available' and candidate_mode=='ready' then
        imgui.TextDisabled(string.format('%d quests are proven ready to start for this character.',total_available));
    elseif c.settings.quest_view=='available' and candidate_mode=='check' then
        imgui.TextDisabled(string.format('%d quests need character-specific evidence or a runtime check.',total_check+total_manual));
    elseif c.settings.quest_view=='available' then
        imgui.TextDisabled(string.format('%d ready + %d check = %d candidates.',total_available,total_check+total_manual,total_available+total_check+total_manual));
    elseif c.settings.quest_view=='locked' then
        imgui.TextDisabled(string.format('%d quests are blocked by a verified prerequisite.',total_locked));
    elseif c.settings.quest_view=='quality' then
        imgui.TextDisabled('Catalog quality review tools. Normal users can leave this view closed.');
    else
        imgui.TextDisabled(string.format('%d completed quests verified from native history.',total_completed));
    end

    if c.settings.quest_view=='available' and candidate_mode=='ready' then
        local zone_name=DRAW_HELPERS.current_zone_name();
        if zone_name then
            imgui.TextDisabled('Current zone: '..tostring(zone_name));
            imgui.SameLine();
            local zsel=(c.settings.quest_ready_zone_only==true);
            local zlabel=(zsel and ('[Available Here '..tostring(total_available_here)..']') or ('Available Here '..tostring(total_available_here)))..'##quest_ready_zone_only';
            if imgui.SmallButton(zlabel) then
                c.settings.quest_ready_zone_only=not zsel;
                HC.modules.state.save();
            end
            imgui.SameLine();
            if zsel and imgui.SmallButton('Show All Ready##quest_ready_zone_clear') then
                c.settings.quest_ready_zone_only=false;
                HC.modules.state.save();
            end
            if total_available_here==0 then
                imgui.TextDisabled('No proven-ready quests start in this zone.');
            elseif zsel then
                imgui.TextDisabled('Showing only proven-ready quests that start in your current zone.');
            else
                imgui.TextDisabled('Use Available Here to turn the current-zone highlight into a filter.');
            end
        else
            imgui.TextDisabled('Current zone is not available yet; zone once to enable Available Here.');
        end
    end

    -- Active and Ready are the two everyday quest lists, so sorting should not
    -- be hidden behind Advanced mode.  Keep this compact and persist the choice.
    if c.settings.quest_view=='active' or (c.settings.quest_view=='available' and candidate_mode=='ready') then
        imgui.TextDisabled('Sort by');
        imgui.SameLine();
        local sort_buttons=nil;
        if c.settings.quest_view=='active' then
            sort_buttons={{'Smart','smart'},{'Priority','priority'},{'Here','current_zone'},{'Name','name'},{'Zone','zone'},{'Next Step','next_step'},{'Repeatable','repeatable'}};
        else
            sort_buttons={{'Smart','smart'},{'Priority','priority'},{'Here','current_zone'},{'Name','name'},{'Zone','zone'},{'Reward','reward'},{'Unlocks','unlocks'},{'Repeatable','repeatable'}};
        end
        local sort_key=(c.settings.quest_view=='active') and 'quest_active_sort' or 'quest_ready_sort';
        for i,b in ipairs(sort_buttons) do
            if i>1 then imgui.SameLine(); end
            local selected=(tostring(c.settings[sort_key] or 'smart')==b[2]);
            local label=(selected and ('['..b[1]..']') or b[1])..'##quest_primary_sort_'..b[2];
            if imgui.SmallButton(label) then
                c.settings[sort_key]=b[2];
                HC.modules.state.save();
            end
        end
    end

    imgui.TextDisabled('Search');
    imgui.SameLine();
    if imgui.SetNextItemWidth~=nil then pcall(function() imgui.SetNextItemWidth(-150); end); end
    local search_buf={c.settings.quest_search};
    local ok,changed=pcall(function() return imgui.InputText('##quest_search',search_buf,128); end);
    if ok and changed then
        c.settings.quest_search=tostring(search_buf[1] or '');
        HC.modules.state.save();
    elseif not ok then
        imgui.TextDisabled('Search box unavailable in this ImGui build.');
    end
    imgui.SameLine();
    if imgui.Button('Clear##quest_search_clear') then c.settings.quest_search=''; HC.modules.state.save(); end
    if c.settings.quest_view=='reward_search' then
        imgui.TextDisabled('Reward Search scans every mapped quest reward, regardless of Active / Ready / Locked / Completed state. Example: warp, scroll, map, key item.');
    end

    if c.settings.quest_view=='available' and (candidate_mode=='check' or candidate_mode=='all') then
        imgui.TextDisabled('Requirement category');
        local categories={
            {'All','all',total_check},
            {'Fame','fame',check_categories.Fame or 0},
            {'Reputation','reputation',check_categories.Reputation or 0},
            {'Rank','rank',check_categories.Rank or 0},
            {'Skill / Trial','skill/trial',check_categories['Skill/Trial'] or 0},
            {'World','world state',check_categories['World State'] or 0},
            {'Party','party',check_categories.Party or 0},
            {'Job / Level','job/level',check_categories['Job/Level'] or 0},
            {'Previous Quest','previous quest',check_categories['Previous Quest'] or 0},
            {'Mission','mission',check_categories.Mission or 0},
            {'Key Item','key item',check_categories['Key Item'] or 0},
            {'Manual Evidence','mixed/manual',check_categories['Mixed/Manual'] or 0},
            {'Other','other',check_categories.Other or 0},
        };
        local shown=0;
        for _,b in ipairs(categories) do
            if b[2]=='all' or b[3]>0 or c.settings.quest_ui_advanced then
                if shown>0 and shown%5~=0 then imgui.SameLine(); end
                local title=b[1]..((b[2]=='all') and '' or (' '..tostring(b[3])));
                local lab=(c.settings.quest_check_filter==b[2] and '['..title..']' or title)..'##quest_check_filter_'..b[2];
                if imgui.Button(lab) then c.settings.quest_check_filter=b[2]; HC.modules.state.save(); end
                shown=shown+1;
            end
        end

        if imgui.CollapsingHeader('Character Evidence Profile##quest_evidence_profile') then
            imgui.TextDisabled('Saved only for '..tostring(profile_name)..'. Use these controls when the game client cannot expose a prerequisite directly.');
        if c.settings.quest_check_filter=='fame' or c.settings.quest_check_filter=='reputation' then
            imgui.TextDisabled('Manual city fame profile (character-specific):');
            local fame_logs={{0,"San d'Oria"},{1,'Bastok'},{2,'Windurst'},{3,'Jeuno'}};
            for _,fl in ipairs(fame_logs) do
                local log_id,label=fl[1],fl[2];
                local cur=DRAW_HELPERS.manual_fame_level(c,log_id);
                imgui.TextDisabled(label..': '..tostring(cur or 'unset'));
                imgui.SameLine();
                for fame=1,9 do
                    if fame>1 then imgui.SameLine(); end
                    local bl=(cur==fame and '['..fame..']' or tostring(fame))..'##quest_fame_'..log_id..'_'..fame;
                    if imgui.SmallButton(bl) then
                        c.quest_fame_overrides[tostring(log_id)]=fame;
                        HC.modules.state.save();
                    end
                end
                imgui.SameLine();
                if imgui.SmallButton('Clear##quest_fame_clear_'..log_id) then
                    c.quest_fame_overrides[tostring(log_id)]=nil;
                    HC.modules.state.save();
                end
            end
            imgui.TextDisabled('City fame also gets a conservative automatic lower bound from COMPLETED quests. Manual profiles can raise that known value; inference never proves a quest locked.');

            imgui.TextDisabled('Named reputation profiles:');
            local reps={{'Tenshodo','tenshodo'}};
            for _,rp in ipairs(reps) do
                local label,key=rp[1],rp[2];
                local cur=DRAW_HELPERS.manual_reputation_level(c,key);
                imgui.TextDisabled(label..': '..tostring(cur or 'unset')); imgui.SameLine();
                for rv=1,9 do
                    if rv>1 then imgui.SameLine(); end
                    local bl=(cur==rv and '['..rv..']' or tostring(rv))..'##quest_rep_'..key..'_'..rv;
                    if imgui.SmallButton(bl) then c.quest_reputation_overrides[key]=rv; HC.modules.state.save(); end
                end
                imgui.SameLine();
                if imgui.SmallButton('Clear##quest_rep_clear_'..key) then c.quest_reputation_overrides[key]=nil; HC.modules.state.save(); end
            end
        end

        if c.settings.quest_check_filter=='rank' then
            imgui.TextDisabled('Mercenary Rank promotion points (current rank):');
            local mp=DRAW_HELPERS.manual_mercenary_points(c);
            imgui.TextDisabled('Points: '..tostring(mp or 'unset')); imgui.SameLine();
            for _,pv in ipairs({0,5,10,15,20,25}) do
                local bl=(mp==pv and '['..pv..']' or tostring(pv))..'##quest_merc_points_'..tostring(pv);
                if imgui.SmallButton(bl) then
                    c.quest_mercenary_rank_points=pv;
                    HC.modules.state.save();
                    mp=pv;
                end
                imgui.SameLine();
            end
            if imgui.SmallButton('Clear##quest_merc_points_clear') then
                c.quest_mercenary_rank_points=nil;
                HC.modules.state.save();
            end
            imgui.TextDisabled('Set the current-rank promotion total reported by Abquhbah. Points cap at 25 and reset after each promotion.');

            local mridx,mrname=DRAW_HELPERS.manual_mercenary_rank(c);
            imgui.TextDisabled('Mercenary Rank: '..tostring(mrname or 'unset')); imgui.SameLine();
            if imgui.SmallButton('-##quest_merc_rank_prev') then
                c.quest_mercenary_rank_index=math.max(1,(mridx or 2)-1);
                HC.modules.state.save();
            end
            imgui.SameLine();
            if imgui.SmallButton('+##quest_merc_rank_next') then
                c.quest_mercenary_rank_index=math.min(#MERCENARY_RANKS,(mridx or 0)+1);
                HC.modules.state.save();
            end
            imgui.SameLine();
            if imgui.SmallButton('Clear Rank##quest_merc_rank_clear') then
                c.quest_mercenary_rank_index=nil;
                HC.modules.state.save();
            end
            imgui.TextDisabled('Rank is a character-specific profile; promotion points are tracked separately for the current rank.');
        end

        if c.settings.quest_check_filter=='world state' then
            imgui.TextDisabled('Manual Al Zahbi general presence (character-specific):');
            local generals={
                {'Rughadjeen','rughadjeen'},
                {'Najelith','najelith'},
                {'Zazarg','zazarg'},
                {'Mihli Aliapoh','mihli aliapoh'},
                {'Gadalar','gadalar'},
            };
            for _,g in ipairs(generals) do
                local label,key=g[1],g[2];
                local present={c.quest_world_presence[key]==true};
                if imgui.Checkbox(label..' present##quest_world_'..key,present) then
                    c.quest_world_presence[key]=present[1] and true or nil;
                    HC.modules.state.save();
                end
            end
            imgui.TextDisabled('Use these only after confirming the general is currently in Al Zahbi. Unchecked means unknown, not absent.');
        end

        if c.settings.quest_check_filter=='mission' then
            local nation,zilart,cop=nil,nil,nil;
            if HC and HC.modules and HC.modules.missions and HC.modules.missions.native_current then
                nation=HC.modules.missions.native_current('nation');
                zilart=HC.modules.missions.native_current('zilart');
                cop=HC.modules.missions.native_current('cop');
            end
            imgui.TextDisabled(string.format('Native current mission values: Nation %s | Zilart %s | CoP %s',
                tostring(nation or 'unseen'),tostring(zilart or 'unseen'),tostring(cop or 'unseen')));
            imgui.TextDisabled('Zone once to refresh the native 0x056 current-mission snapshot. Quest details show the named mission test and a manual fallback only when the packet has not been observed.');
        end

        if c.settings.quest_check_filter=='mixed/manual' then
            imgui.TextDisabled('Per-condition confirmations are shown inside each quest detail panel. These replace broad all-or-nothing manual blockers and are saved per character.');
        end

        if c.settings.quest_check_filter=='party' then
            local ps=DRAW_HELPERS.current_party_snapshot();
            if ps.available then
                imgui.TextDisabled(string.format('Current party: %d member(s) | highest observed level: %s | level data: %s',
                    ps.count,tostring(ps.max_level or 'unknown'),ps.levels_complete and 'complete' or 'partial'));
                for _,m in ipairs(ps.members or {}) do
                    imgui.TextDisabled(string.format('  %s - level %s',tostring(m.name or ('Member '..tostring(m.index))),tostring(m.level or 'unknown')));
                end
            else
                imgui.TextDisabled('Current party information is unavailable from this Ashita build.');
            end
            imgui.TextDisabled('Level Sync is naturally honored when the party API reports synchronized member levels.');
        end

        if c.settings.quest_check_filter=='job/level' then
            local done,total=DRAW_HELPERS.maat_job_progress(c,MAAT_JOB_ORDER);
            imgui.TextDisabled(string.format('Shattering Stars victories for Beyond the Sun: %d/%d confirmed',done,total));
            for i,job in ipairs(MAAT_JOB_ORDER) do
                local won={c.quest_maat_job_wins[job]==true};
                if imgui.Checkbox(job..'##quest_maat_job_'..job,won) then
                    c.quest_maat_job_wins[job]=won[1] and true or nil;
                    c.quest_maat_job_win_meta=type(c.quest_maat_job_win_meta)=='table' and c.quest_maat_job_win_meta or {};
                    if won[1] then
                        c.quest_maat_job_win_meta[job]={source='Manual past-win confirmation',confidence='MANUAL',confirmed_at=os.time(),job=job};
                    else
                        c.quest_maat_job_win_meta[job]=nil;
                    end
                    HC.modules.state.save();
                end
                if i%5~=0 then imgui.SameLine(); end
            end
            if imgui.SmallButton('Clear Maat Victories##quest_maat_clear') then
                c.quest_maat_job_wins={};
                c.quest_maat_job_win_meta={};
                HC.modules.state.save();
            end
            imgui.TextDisabled('These are character-specific confirmations because the native quest log does not preserve which job won each repeatable Maat battlefield.');

            local adone,atotal=DRAW_HELPERS.avatar_unlock_progress(c,AVATAR_UNLOCK_ORDER);
            imgui.TextDisabled(string.format('Celestial avatar unlocks for Waking the Beast: %d/%d confirmed',adone,atotal));
            for i,name in ipairs(AVATAR_UNLOCK_ORDER) do
                local key=string.lower(name);
                local owned={c.quest_avatar_unlocks[key]==true};
                if imgui.Checkbox(name..'##quest_avatar_unlock_'..key,owned) then
                    c.quest_avatar_unlocks[key]=owned[1] and true or nil;
                    HC.modules.state.save();
                end
                if i%3~=0 then imgui.SameLine(); end
            end
            if imgui.SmallButton('Clear Avatar Unlocks##quest_avatar_clear') then
                c.quest_avatar_unlocks={};
                HC.modules.state.save();
            end
            imgui.TextDisabled('These confirmations represent the six avatars acquired through the full-size Trial by quests.');
        end

        if c.settings.quest_check_filter=='skill/trial' then
            imgui.TextDisabled('Combat skill requirements (live in-game value; manual fallback):');
            local skills={'Sword','Great Axe','Marksmanship','Great Sword','Hand-to-Hand','Polearm','Axe','Great Katana','Katana'};
            for _,sk in ipairs(skills) do
                local key=string.lower(sk);
                local cur=DRAW_HELPERS.manual_weapon_skill_level(c,sk);
                imgui.TextDisabled(sk..': '..tostring(cur or 'unset')); imgui.SameLine();
                if imgui.SmallButton((cur and cur>=250 and '[250+]' or '250+')..'##quest_ws_skill_'..key) then
                    c.quest_weapon_skill_overrides[key]=250;
                    HC.modules.state.save();
                end
                imgui.SameLine();
                if imgui.SmallButton('Clear##quest_ws_skill_clear_'..key) then
                    c.quest_weapon_skill_overrides[key]=nil;
                    HC.modules.state.save();
                end
            end
            local trial={c.quest_ws_trial_clear==true};
            if imgui.Checkbox('No other weaponskill trial currently active##quest_ws_trial_clear',trial) then
                c.quest_ws_trial_clear=trial[1];
                HC.modules.state.save();
            end
            imgui.TextDisabled('Live combat-skill values come from the Skills tab. The buttons below remain available as a fallback if Ashita cannot expose a skill value; active-trial state still needs confirmation.');

            imgui.TextDisabled('Fishing skill profile (live craft profile; manual fallback):');
            local fishing=DRAW_HELPERS.manual_craft_skill_level(c,'Fishing');
            imgui.TextDisabled('Fishing: '..tostring(fishing or 'unset')); imgui.SameLine();
            for _,fv in ipairs({20,30,78}) do
                if imgui.SmallButton((fishing and fishing>=fv and '['..fv..'+]' or fv..'+')..'##quest_fishing_'..tostring(fv)) then
                    c.quest_craft_skill_overrides.fishing=fv;
                    HC.modules.state.save();
                    fishing=fv;
                end
                imgui.SameLine();
            end
            if imgui.SmallButton('Clear##quest_fishing_clear') then
                c.quest_craft_skill_overrides.fishing=nil;
                HC.modules.state.save();
            end
            imgui.TextDisabled('Quest fishing requirements use the same live Fishing value shown in Character Info; the manual field below is only a fallback if the game API is unavailable.');
        end
        end
    end

    if c.settings.quest_ui_advanced then
        local audit_toggle={c.settings.quest_show_self_audit==true};
        if imgui.Checkbox('Self-audit##quest_self_audit_toggle',audit_toggle) then
            c.settings.quest_show_self_audit=audit_toggle[1]; HC.modules.state.save();
        end
        if imgui.IsItemHovered~=nil and imgui.IsItemHovered() then
            imgui.SetTooltip('Scans current character quest classifications for contradictions and mapped requirements that still lack live evidence.');
        end
        if c.settings.quest_show_self_audit then
            local audit,acounts=DRAW_HELPERS.quest_self_audit(c);
            acounts=type(acounts)=='table' and acounts or {};
            imgui.SameLine(); imgui.TextDisabled(string.format('%d issue(s)',#audit));
            imgui.TextDisabled(string.format('Contradictions %d | stale manual %d | missing live evidence %d | mapped unknown %d',tonumber(acounts.contradiction) or 0,tonumber(acounts.stale_manual) or 0,tonumber(acounts.live_evidence) or 0,tonumber(acounts.mapped_unknown) or 0));
            local safe_count=0; for _,it in ipairs(audit) do if it.fixable==true then safe_count=safe_count+1; end end
            if safe_count>0 then
                if imgui.Button('Apply Safe Auto-Fixes ('..tostring(safe_count)..')##quest_apply_safe_autofixes') then
                    local fixed=DRAW_HELPERS.apply_safe_quest_autofixes(c,audit);
                    c.settings.quest_last_autofix_count=fixed;
                end
                if imgui.IsItemHovered~=nil and imgui.IsItemHovered() then
                    imgui.SetTooltip('Persists only monotonic evidence that is already independently proven (for example confirmed fame or completed/rank progression). Live skills/items are never frozen by this button.');
                end
            end
            if tonumber(c.settings.quest_last_autofix_count or 0)>0 then imgui.SameLine(); imgui.TextDisabled('Last pass fixed '..tostring(c.settings.quest_last_autofix_count)..' stale condition(s).'); end
            if #audit==0 then
                imgui.TextDisabled('No classification contradictions or stale auto-provable checks detected in currently loaded Horizon-era quest logs.');
            else
                local max_show=math.min(#audit,14);
                for i=1,max_show do
                    local it=audit[i];
                    local fixmark=it.fixable==true and ' [SAFE FIX]' or '';
                    imgui.TextDisabled(string.format('%s%s: %s - %s',tostring(it.kind),fixmark,tostring(it.name),tostring(it.detail)));
                    imgui.SameLine();
                    if imgui.SmallButton('Details##quest_audit_'..tostring(it.log_id)..'_'..tostring(it.quest_id)..'_'..tostring(i)) then open_quest_detail(it.log_id,it.quest_id); end
                end
                if #audit>max_show then imgui.TextDisabled(string.format('...and %d more. Use quest filters/details to inspect them.',#audit-max_show)); end
            end
        end
    end

    if c.settings.quest_ui_advanced and c.settings.quest_view=='available'
        and (manual_confirmed>0 or condition_confirmed>0)
        and imgui.CollapsingHeader('Saved Confirmations##quest_saved_confirmations') then
        imgui.TextDisabled(string.format('Whole-quest confirmations: %d | per-condition confirmations: %d',manual_confirmed,condition_confirmed));
        if imgui.Button('Clear Whole-Quest Confirmations##quest_manual_clear_all') then
            c.quest_manual_requirements={};
            HC.modules.state.save();
        end
        imgui.SameLine();
        if imgui.Button('Clear Condition Confirmations##quest_condition_clear_all') then
            c.quest_condition_flags={};
            HC.modules.state.save();
        end
        if imgui.IsItemHovered~=nil and imgui.IsItemHovered() then
            imgui.SetTooltip('Clears character-specific confirmations only. Native quest history and catalog data are unchanged.');
        end
    end

    if c.settings.quest_view=='active' or c.settings.quest_view=='attention' then
        local auto_only={c.settings.quest_automated_only==true};
        if imgui.Checkbox('Automated only##quest_auto_only',auto_only) then
            c.settings.quest_automated_only=auto_only[1]; HC.modules.state.save();
        end
        imgui.SameLine();
        local ready_only={c.settings.quest_ready_only==true};
        if imgui.Checkbox('Ready only##quest_ready_only',ready_only) then
            c.settings.quest_ready_only=ready_only[1]; HC.modules.state.save();
        end
    end

    local region_open=c.settings.quest_region_open;
    if c.settings.quest_view=='completed' then region_open=c.settings.quest_completed_region_open
    elseif c.settings.quest_view=='available' then region_open=c.settings.quest_available_region_open
    elseif c.settings.quest_view=='locked' then region_open=c.settings.quest_locked_region_open
    elseif c.settings.quest_view=='verify' then region_open=c.settings.quest_verify_region_open
    elseif c.settings.quest_view=='quality' then region_open=c.settings.quest_quality_region_open
    elseif c.settings.quest_view=='reward_search' then region_open=c.settings.quest_available_region_open end

    if c.settings.quest_ui_advanced and imgui.CollapsingHeader('Advanced List Options##quest_advanced_filters') then
        if imgui.Button('Expand All##quest_expand_all') then
            for log=0,10 do region_open[log]=true; end HC.modules.state.save();
        end
        imgui.SameLine();
        if imgui.Button('Collapse All##quest_collapse_all') then
            for log=0,10 do region_open[log]=false; end HC.modules.state.save();
        end
        local mapped_only={c.settings.quest_mapped_only==true};
        if imgui.Checkbox('Mapped details only##quest_mapped_only',mapped_only) then
            c.settings.quest_mapped_only=mapped_only[1]; HC.modules.state.save();
        end
        imgui.SameLine();
        local gaps_only={c.settings.quest_catalog_gaps_only==true};
        if imgui.Checkbox('Catalog gaps only##quest_catalog_gaps_only',gaps_only) then
            c.settings.quest_catalog_gaps_only=gaps_only[1]; HC.modules.state.save();
        end
        if c.settings.quest_catalog_gaps_only then
            imgui.TextDisabled('Missing field');
            local gap_buttons={{'Any','all'},{'NPC','npc'},{'Zone','zone'},{'Objective','objective'},{'Reward','reward'},{'Prereq','prereq'}};
            for i,b in ipairs(gap_buttons) do
                if i>1 then imgui.SameLine(); end
                local glabel=(c.settings.quest_missing_filter==b[2] and '['..b[1]..']' or b[1])..'##quest_gap_'..b[2];
                if imgui.Button(glabel) then c.settings.quest_missing_filter=b[2]; HC.modules.state.save(); end
            end
        end

        imgui.TextDisabled('Era');
        local era_buttons={{'All','all'},{'Base','base'},{'Zilart','zilart'},{'CoP','cop'},{'ToAU','toau'}};
        for i,b in ipairs(era_buttons) do
            if i>1 then imgui.SameLine(); end
            local label=(c.settings.quest_expansion_filter==b[2] and '['..b[1]..']' or b[1])..'##quest_era_'..b[2];
            if imgui.Button(label) then c.settings.quest_expansion_filter=b[2]; HC.modules.state.save(); end
        end

        if not (c.settings.quest_view=='active' or (c.settings.quest_view=='available' and candidate_mode=='ready')) then
            imgui.TextDisabled('Sort');
            for i,sm in ipairs({'smart','name','zone','reward'}) do
                if i>1 then imgui.SameLine(); end
                local lab=(c.settings.quest_sort==sm and '['..string.upper(sm)..']' or string.upper(sm));
                if imgui.Button(lab..'##quest_sort_'..sm) then c.settings.quest_sort=sm; HC.modules.state.save(); end
            end
        end

        if c.settings.quest_view=='quality' then
            imgui.TextDisabled('Quality tier');
            local qbuttons={{'All','all'},{'Gold','gold'},{'Silver','silver'},{'Bronze','bronze'},{'Needs Review','needs review'}};
            for i,b in ipairs(qbuttons) do
                if i>1 then imgui.SameLine(); end
                local qlabel=(c.settings.quest_quality_filter==b[2] and '['..b[1]..']' or b[1])..'##quest_quality_filter_'..b[2];
                if imgui.Button(qlabel) then c.settings.quest_quality_filter=b[2]; HC.modules.state.save(); end
            end
        end
    end

    if type(c.quest_recent_unlocked)=='table' and #c.quest_recent_unlocked>0 then
        imgui.Separator();
        imgui.Text('Recently Unlocked');
        for i=1,math.min(#c.quest_recent_unlocked,5) do
            local r=c.quest_recent_unlocked[i];
            local age=''; if tonumber(r.time) then age=' - '..os.date('%H:%M',tonumber(r.time)); end
            imgui.TextDisabled(string.format('%s: %s%s',M.log_name(r.log_id),tostring(r.name or DRAW_HELPERS.quest_name(r.log_id,r.quest_id)),age));
        end
    end

    local function quest_wiki_url(log,qid)
        local det=DRAW_HELPERS.quest_detail(log,qid);
        local name=(det and det.name) or DRAW_HELPERS.quest_name(log,qid);
        if not name or name=='' then return nil; end
        -- MediaWiki accepts underscores for spaces. Percent-encode characters that
        -- can be interpreted by cmd.exe or are unsafe in a URL path.
        local slug=tostring(name):gsub(' ','_');
        slug=slug:gsub('([^%w%-%._~])',function(ch) return string.format('%%%02X',string.byte(ch)); end);
        return 'https://horizonffxi.wiki/'..slug;
    end

    local function open_quest_wiki(log,qid)
        local url=quest_wiki_url(log,qid);
        if not url then return false; end
        -- HorizonXI/Ashita runs on Windows. start opens the user's default browser.
        local ok=pcall(function() os.execute('cmd /c start "" "'..url..'"'); end);
        return ok;
    end

    local function draw_selected_quest_details()
        if c.settings.quest_detail_selected~='' then
            local sl,sq=c.settings.quest_detail_selected:match('^(%-?%d+):(%-?%d+)$');
            sl=tonumber(sl); sq=tonumber(sq);
            if sl~=nil and sq~=nil then
                if #c.settings.quest_detail_history>0 then
                    if imgui.Button('< Back##quest_detail_back') then back_quest_detail(); return; end
                    imgui.SameLine();
                end
                imgui.Text(DRAW_HELPERS.quest_name(sl,sq));
                imgui.SameLine(); imgui.TextDisabled('['..M.log_name(sl)..']');
                local a=DRAW_HELPERS.quest_active(sl,sq); local d=M.is_completed(sl,sq);
                local developer=(type(c.settings)=='table' and c.settings.developer_mode==true);
                local detail_meta=DRAW_HELPERS.quest_detail(sl,sq);
                local canonical=nil;
                if HC.modules.canonical and HC.modules.canonical.quest then
                    local ok,v=pcall(HC.modules.canonical.quest,sl,sq,detail_meta); if ok then canonical=v; end
                end
                local content_state=canonical and tostring(canonical.content_state or '') or '';
                local unavailable=(content_state=='UNAVAILABLE' or content_state=='FUTURE' or content_state=='DISABLED')
                    or (type(detail_meta)=='table' and type(detail_meta.horizon)=='table' and detail_meta.horizon.enabled==false);
                local state=(a==true and 'ACTIVE') or (d==true and 'COMPLETED') or 'NOT ACTIVE / NOT COMPLETED';
                local visible_state=unavailable and ((content_state=='FUTURE') and 'FUTURE CONTENT' or 'UNAVAILABLE') or state;
                imgui.Text('Status: '..visible_state);
                if content_state=='FUTURE' then
                    imgui.TextDisabled('HorizonXI availability: FUTURE CONTENT');
                elseif unavailable then
                    imgui.TextDisabled('HorizonXI availability: NOT CURRENTLY AVAILABLE');
                else
                    imgui.TextDisabled('HorizonXI availability: AVAILABLE');
                end

                if imgui.Button('Open HorizonXI Wiki##quest_wiki_'..tostring(sl)..'_'..tostring(sq)) then
                    open_quest_wiki(sl,sq);
                end
                if imgui.IsItemHovered~=nil and imgui.IsItemHovered() then
                    imgui.SetTooltip('Open this quest guide in your default browser.');
                end

                local det=DRAW_HELPERS.quest_detail(sl,sq);
                local av,reason=DRAW_HELPERS.availability_state(c,sl,sq);
                local advanced_flags=developer and (ImGuiTreeNodeFlags_DefaultOpen or 0) or 0;
                local advanced_details_open=imgui.CollapsingHeader('Advanced Details##quest_detail_advanced_'..tostring(sl)..'_'..tostring(sq),advanced_flags);
                if advanced_details_open then
                    if unavailable then
                        imgui.TextDisabled('Native state ignored because canonical HorizonXI availability is '..tostring(content_state~='' and content_state or 'DISABLED')..'.');
                    elseif canonical and canonical.native_policy=='QUARANTINE' then
                        imgui.TextDisabled('Native state: ID QUARANTINED - guided verification required');
                    else
                        imgui.TextDisabled('Native state: '..state);
                    end
                    imgui.TextDisabled(string.format('Native IDs: log %d | quest %d%s',sl,sq,canonical and (' | policy '..tostring(canonical.native_policy)) or ''));

                    if imgui.Button('Open FFXIclopedia##quest_ffxiclopedia_'..tostring(sl)..'_'..tostring(sq)) then
                        local det0=DRAW_HELPERS.quest_detail(sl,sq); local nm=(det0 and det0.name) or DRAW_HELPERS.quest_name(sl,sq);
                        if nm and nm~='' then
                            local slug=tostring(nm):gsub(' ','_'):gsub('([^%w%-%._~])',function(ch) return string.format('%%%02X',string.byte(ch)); end);
                            pcall(function() os.execute('cmd /c start "" "https://ffxiclopedia.fandom.com/wiki/'..slug..'"'); end);
                        end
                    end
                    if imgui.IsItemHovered~=nil and imgui.IsItemHovered() then
                        imgui.SetTooltip('Open the historical FFXIclopedia page. Verify information against the September 2007 cutoff before cataloging.');
                    end
                    imgui.SameLine();
                    if imgui.Button('Report State##quest_state_report_'..tostring(sl)..'_'..tostring(sq)) then
                        local path,err=DRAW_HELPERS.write_quest_state_report(c,sl,sq);
                        if path then HC.msg('Quest state report saved: '..tostring(path)); else HC.msg('Quest state report failed: '..tostring(err)); end
                    end
                    if imgui.IsItemHovered~=nil and imgui.IsItemHovered() then
                        imgui.SetTooltip("Export this quest's native state, evaluated requirements, evidence, repeat status, and catalog metadata for debugging.");
                    end

                    if det then
                        local ch,ct,cm=DRAW_HELPERS.catalog_completeness(det);
                        local qs,qt,ql=DRAW_HELPERS.catalog_quality_score(det);
                        local qissues=DRAW_HELPERS.catalog_quality_issues(det);
                        imgui.TextDisabled(string.format('Catalog: %s (%d/%d) | Quality: %s (%d/%d)',DRAW_HELPERS.catalog_status(det),ch,ct,ql,qs,qt));
                        imgui.TextDisabled('Data confidence: '..metadata_confidence(det));
                        if type(cm)=='table' and #cm>0 then imgui.TextDisabled('Missing catalog data: '..table.concat(cm,', ')); end
                        if type(qissues)=='table' and #qissues>0 then imgui.TextDisabled('Quality audit: '..table.concat(qissues,', ')); end
                        if type(det.horizon)=='table' and det.horizon.source and tostring(det.horizon.source)~='' then imgui.TextDisabled('Source: '..tostring(det.horizon.source)); end
                    end
                    local pscore,pwhy=DRAW_HELPERS.priority_score(c,sl,sq);
                    imgui.TextDisabled('Priority '..tostring(pscore)..((pwhy~='') and (' - '..pwhy) or ''));
                    local why_category=DRAW_HELPERS.requirement_reason_category(reason,det);
                    imgui.TextDisabled('WHY THIS STATE: '..tostring(av)..' | '..tostring(why_category)..' | '..tostring(reason or 'No additional reason'));
                    if av=='LOCKED' and HC.modules and HC.modules.blockers and HC.modules.blockers.quest then
                        local okb,blocker=pcall(HC.modules.blockers.quest,c,sl,sq,av,reason);
                        if okb and type(blocker)=='table' and tostring(blocker.summary or '')~='' then
                            imgui.Text('NEXT TO UNLOCK: '..tostring(blocker.summary));
                            if blocker.action_log_id~=nil and blocker.action_quest_id~=nil then
                                imgui.SameLine();
                                if imgui.SmallButton('Open Next##quest_blocker_next_'..tostring(sl)..'_'..tostring(sq)) then
                                    open_quest_detail(blocker.action_log_id,blocker.action_quest_id); return;
                                end
                            end
                        end
                    end
                    local evidence=DRAW_HELPERS.requirement_source_summary(c,sl,sq);
                    if type(evidence)=='table' and #evidence>0 then
                        imgui.TextDisabled('Requirement evidence:');
                        for _,ev in ipairs(evidence) do
                            imgui.TextDisabled('  ['..tostring(ev.confidence or 'CATALOG')..'] '..tostring(ev.label)..': '..tostring(ev.value)..' ['..tostring(ev.source)..']');
                        end
                    end
                end

                if det then
                    imgui.Separator();
                    imgui.Text('START');
                    if det.start_npc and det.start_npc~='' then imgui.TextWrapped('NPC: '..det.start_npc); else imgui.TextDisabled('NPC: not verified'); end
                    if det.start_zone and det.start_zone~='' then imgui.TextWrapped('Location: '..det.start_zone); else imgui.TextDisabled('Location: not verified'); end
                    if det.expansion and det.expansion~='' then imgui.TextDisabled('Expansion: '..det.expansion); end
                    local tag=det.repeat_type or DRAW_HELPERS.repeat_tag(sl,sq); if tag then imgui.TextDisabled('Repeat: '..tostring(tag)); end
                if DRAW_HELPERS.quest_is_repeatable(sl,sq) then
                        local rs,rsrc=DRAW_HELPERS.repeatable_status(c,sl,sq);
                        imgui.TextDisabled('Repeat status: '..tostring(rs or 'UNKNOWN'));
                        if advanced_details_open then imgui.TextDisabled('Repeat evidence: '..tostring(rsrc or 'no reset evidence')); end
                    end
                    local dep_count,dependents=DRAW_HELPERS.dependent_quest_count(sl,sq);
                    if advanced_details_open and dep_count>0 then
                        imgui.TextDisabled('Progression impact: unlocks '..tostring(dep_count)..' mapped later quest(s).');
                        if c.settings.quest_ui_advanced then
                            local names={}; for i=1,math.min(dep_count,5) do names[#names+1]=tostring(dependents[i].name or 'Unknown'); end
                            imgui.TextDisabled('  Leads to: '..table.concat(names,', ')..(dep_count>5 and (' +'..tostring(dep_count-5)..' more') or ''));
                        end
                    end

                    -- v6.86.0 dependency graph: show the shortest mapped chain to
                    -- the first actionable prerequisite rather than only the first
                    -- direct blocker. This remains advisory; native quest state and
                    -- availability evaluation stay authoritative.
                    local qgraph=HC.modules and HC.modules.questgraph or nil;
                    if advanced_details_open and qgraph and qgraph.trace then
                        local ok_graph,tr=pcall(qgraph.trace,c,sl,sq,16);
                        if ok_graph and type(tr)=='table' and ((tonumber(tr.direct_dependencies) or 0)>0 or (tonumber(tr.direct_dependents) or 0)>0) then
                            imgui.Separator(); imgui.Text('DEPENDENCY PATH');
                            local transitive=qgraph.transitive_dependents and qgraph.transitive_dependents(sl,sq) or {};
                            imgui.TextDisabled(string.format('Direct prerequisites: %d | Direct dependents: %d | Transitive unlock reach: %d',tonumber(tr.direct_dependencies) or 0,tonumber(tr.direct_dependents) or 0,#transitive));
                            local pathtext=qgraph.path_text and qgraph.path_text(tr) or '';
                            if pathtext~='' then imgui.TextWrapped(pathtext); end
                            if tr.first_actionable and tr.first_actionable.node then
                                local an=tr.first_actionable.node;
                                if tonumber(an.log_id)~=sl or tonumber(an.quest_id)~=sq then
                                    imgui.Text('First actionable prerequisite: '..tostring(an.name or 'Quest'));
                                    imgui.SameLine();
                                    if imgui.SmallButton('Open##quest_graph_action_'..tostring(an.log_id)..'_'..tostring(an.quest_id)) then open_quest_detail(an.log_id,an.quest_id); return; end
                                else
                                    imgui.TextDisabled('This quest itself is the first actionable step.');
                                end
                            elseif tr.reason and tostring(tr.reason)~='' then
                                imgui.TextDisabled('Chain stops at: '..tostring(tr.reason));
                            end
                        end
                    end

                    imgui.Separator();
                    imgui.Text('REQUIREMENTS');
                    imgui.Text('Can I start this?');
                    if state=='COMPLETED' and not DRAW_HELPERS.quest_is_repeatable(sl,sq) then
                        imgui.TextDisabled('Already completed.');
                    elseif state=='ACTIVE' then
                        imgui.TextDisabled('Already active - this quest is in your native quest log.');
                    elseif av=='AVAILABLE' then
                        imgui.Text('YES - mapped prerequisites are satisfied.');
                    elseif av=='LOCKED' then
                        imgui.Text('NO - '..tostring(reason or 'a mapped prerequisite is not satisfied'));
                    else
                        imgui.TextDisabled('CHECK REQUIREMENTS - '..tostring(reason or 'some requirements cannot be verified yet'));
                    end
                    local req=det.requirements or {};
                    local has_documented_req=false;
                    if type(req.quests)=='table' and #req.quests>0 then
                        has_documented_req=true;
                        for _,q in ipairs(req.quests) do
                            local ql=tonumber(q.log_id or q.log); local qi=tonumber(q.quest_id or q.id);
                            if ql and qi then
                                local done=M.is_completed(ql,qi);
                                imgui.TextDisabled(string.format('Prerequisite: %s [%s]',DRAW_HELPERS.quest_name(ql,qi),done==true and 'COMPLETE' or (done==false and 'NOT COMPLETE' or 'UNKNOWN')));
                                imgui.SameLine();
                                if imgui.SmallButton('Details##quest_req_detail_'..ql..'_'..qi) then open_quest_detail(ql,qi); return; end
                            end
                        end
                    end
                    if type(req.quests_started)=='table' and #req.quests_started>0 then
                        has_documented_req=true;
                        for _,rq in ipairs(req.quests_started) do
                            local ql=tonumber(rq.log_id or rq.log); local qi=tonumber(rq.quest_id or rq.id);
                            if ql and qi then
                                local started=DRAW_HELPERS.native_quest_started_or_completed(ql,qi);
                                imgui.TextDisabled(string.format('Prerequisite started: %s [%s]',DRAW_HELPERS.quest_name(ql,qi),
                                    started==true and 'STARTED/COMPLETE' or (started==false and 'NOT STARTED' or 'UNKNOWN')));
                                imgui.SameLine();
                                if imgui.SmallButton('Details##quest_req_started_'..ql..'_'..qi) then open_quest_detail(ql,qi); return; end
                            end
                        end
                    end
                    if req.fame~=nil then
                        has_documented_req=true;
                        local kind,pkey,plabel=DRAW_HELPERS.contextual_fame_profile(det,sl);
                        if req.fame_log_id~=nil then kind='city'; pkey=tonumber(req.fame_log_id); end
                        local need=tonumber(req.fame);

                        if kind=='reputation' then
                            local have=DRAW_HELPERS.manual_reputation_level(c,pkey);
                            local label=tostring(plabel or pkey or 'Reputation')..' Fame';
                            if have~=nil then
                                local result=(need and tonumber(have)<need) and 'CONFIRMED - BELOW REQUIREMENT' or 'CONFIRMED';
                                imgui.Text(string.format('%s: %s / %s required [%s]',label,tostring(have),tostring(req.fame),result));
                            else
                                imgui.TextDisabled(string.format('%s: unknown / %s required [NOT CONFIRMED]',label,tostring(req.fame)));
                            end
                        else
                            local fame_log=tonumber(pkey or req.fame_log_id or sl);
                            local mf=(fame_log and fame_log>=0 and fame_log<=3) and DRAW_HELPERS.manual_fame_level(c,fame_log) or nil;
                            local inf=(fame_log and fame_log>=0 and fame_log<=3) and DRAW_HELPERS.inferred_city_fame_floor(fame_log) or nil;
                            local eff=nil;
                            if mf and inf then eff=math.max(mf,inf) else eff=mf or inf; end
                            local city_labels={[0]="San d'Oria",[1]='Bastok',[2]='Windurst',[3]='Jeuno'};
                            local label=(city_labels[fame_log] and (city_labels[fame_log]..' Fame')) or 'Fame';

                            if mf~=nil then
                                local shown=eff or mf;
                                local result=(need and tonumber(shown)<need) and 'CONFIRMED - BELOW REQUIREMENT' or 'CONFIRMED';
                                imgui.Text(string.format('%s: %s / %s required [%s]',label,tostring(shown),tostring(req.fame),result));
                            elseif inf~=nil then
                                local result=(need and tonumber(inf)>=need) and 'PROVEN BY QUEST HISTORY' or 'INFERRED FLOOR';
                                imgui.TextDisabled(string.format('%s: at least %s / %s required [%s]',label,tostring(inf),tostring(req.fame),result));
                            else
                                imgui.TextDisabled(string.format('%s: unknown / %s required [NOT CONFIRMED]',label,tostring(req.fame)));
                            end
                        end
                    end
                    if req.world_presence~=nil then
                        has_documented_req=true;
                        local wp=DRAW_HELPERS.manual_world_presence(c,req.world_presence);
                        imgui.TextDisabled('World-state prerequisite: '..tostring(req.world_presence)..' present in Al Zahbi ['..(wp==true and 'CONFIRMED' or 'NOT VERIFIED')..']');
                    end
                    if type(req.status_any)=='table' then
                        has_documented_req=true;
                        local buffs,available=DRAW_HELPERS.current_status_names();
                        local matched=nil;
                        if available then
                            matched=false;
                            for _,bn in ipairs(req.status_any) do
                                if buffs[string.lower(tostring(bn))]==true then matched=true; break; end
                            end
                        end
                        imgui.TextDisabled('Active-status requirement: one of '..table.concat(req.status_any,', ')..
                            ' ['..(matched==true and 'PASS' or (matched==false and 'NOT ACTIVE' or 'UNKNOWN'))..']');
                    end
                    if type(req.exclusive_active_quests)=='table' and #req.exclusive_active_quests>0 then
                        has_documented_req=true;
                        local conflicts={};
                        for _,rq in ipairs(req.exclusive_active_quests) do
                            local ql=tonumber(rq.log_id or rq.log); local qi=tonumber(rq.quest_id or rq.id);
                            if ql and qi and DRAW_HELPERS.native_quest_is_active(ql,qi)==true then conflicts[#conflicts+1]=DRAW_HELPERS.quest_name(ql,qi); end
                        end
                        imgui.TextDisabled('Mutual-exclusion check: '..(#conflicts==0 and 'CLEAR' or ('BLOCKED by '..table.concat(conflicts,', '))));
                    end
                    if type(req.exclusive_quests)=='table' and #req.exclusive_quests>0 then
                        has_documented_req=true;
                        local conflicts={};
                        for _,rq in ipairs(req.exclusive_quests) do
                            local ql=tonumber(rq.log_id or rq.log); local qi=tonumber(rq.quest_id or rq.id);
                            if ql and qi and DRAW_HELPERS.native_quest_started_or_completed(ql,qi)==true then conflicts[#conflicts+1]=DRAW_HELPERS.quest_name(ql,qi); end
                        end
                        imgui.TextDisabled('Permanent mutual-exclusion check: '..(#conflicts==0 and 'CLEAR' or ('BLOCKED by '..table.concat(conflicts,', '))));
                    end
                    if req.reputation~=nil and req.reputation_level~=nil then
                        has_documented_req=true;
                        local need=tonumber(req.reputation_level);
                        local mr=DRAW_HELPERS.manual_reputation_level(c,req.reputation);
                        local label=tostring(req.reputation):gsub('_',' ');
                        if mr~=nil then
                            local result=(need and mr<need) and 'CONFIRMED - BELOW REQUIREMENT' or 'CONFIRMED';
                            imgui.Text(string.format('%s Reputation: %s / %s required [%s]',
                                label,tostring(mr),tostring(req.reputation_level),result));
                        else
                            imgui.TextDisabled(string.format('%s Reputation: unknown / %s required [NOT CONFIRMED]',
                                label,tostring(req.reputation_level)));
                        end
                    end
                    if req.nation_rank~=nil then
                        has_documented_req=true;
                        local nation=tostring(req.nation or req.nation_id or M.log_name(sl));
                        local have=DRAW_HELPERS.historical_rank(c,req.nation or req.nation_id);
                        imgui.TextDisabled(string.format('Nation rank: %s %s [have: %s]',nation,tostring(req.nation_rank),have and tostring(have) or 'unknown'));
                    end
                    if req.mercenary_points~=nil then
                        has_documented_req=true;
                        local have=DRAW_HELPERS.manual_mercenary_points(c);
                        local need=tonumber(req.mercenary_points);
                        local st=(have==nil and 'UNKNOWN') or ((not need or have>=need) and 'PASS' or 'FAIL');
                        imgui.TextDisabled(string.format('Mercenary Rank points: need %s | profile %s [%s]',
                            tostring(req.mercenary_points),tostring(have or 'unset'),st));
                    end
                    if req.mercenary_rank_min~=nil then
                        has_documented_req=true;
                        local have,have_name=DRAW_HELPERS.manual_mercenary_rank(c);
                        local need=DRAW_HELPERS.mercenary_rank_index(req.mercenary_rank_min);
                        local st=(have==nil and 'UNKNOWN') or ((not need or have>=need) and 'PASS' or 'FAIL');
                        imgui.TextDisabled(string.format('Mercenary Rank: need %s or higher | profile %s [%s]',
                            tostring(req.mercenary_rank_min),tostring(have_name or 'unset'),st));
                    end
                    if req.level~=nil or req.job~=nil then
                        has_documented_req=true;
                        local live_level=DRAW_HELPERS.current_main_job_level();
                        imgui.TextDisabled('Job/level requirement: '..tostring(req.job or 'Any')..' '..tostring(req.level or '')..' | current level: '..tostring(live_level or 'unknown'));
                    end
                    if type(req.maat_jobs)=='table' then
                        has_documented_req=true;
                        local done,total,missing=DRAW_HELPERS.maat_job_progress(c,req.maat_jobs);
                        imgui.TextDisabled(string.format('Maat victories: %d/%d [%s]',done,total,done==total and 'PASS' or ('UNKNOWN - missing '..table.concat(missing,', '))));
                        imgui.TextDisabled('Job levels:');
                        local first_job=true;
                        for _,maat_job in ipairs(req.maat_jobs) do
                            local jl=DRAW_HELPERS.live_job_level(maat_job);
                            if not first_job then imgui.SameLine(); imgui.TextDisabled('|'); end
                            imgui.SameLine();
                            local label=tostring(maat_job)..' '..tostring(jl~=nil and jl or '?');
                            if tonumber(jl or 0)>=75 then imgui.Text(label); else imgui.TextDisabled(label); end
                            first_job=false;
                        end
                    end
                    if type(req.avatar_unlocks)=='table' then
                        has_documented_req=true;
                        local done,total,missing=DRAW_HELPERS.avatar_unlock_progress(c,req.avatar_unlocks);
                        imgui.TextDisabled(string.format('Avatar unlocks: %d/%d [%s]',done,total,done==total and 'PASS' or ('UNKNOWN - missing '..table.concat(missing,', '))));
                    end
                    if req.party_size~=nil or req.party_max_level~=nil then
                        has_documented_req=true;
                        local ps=DRAW_HELPERS.current_party_snapshot();
                        if ps.available then
                            local parts={string.format('current party %d',ps.count)};
                            if req.party_size~=nil then parts[#parts+1]='need '..tostring(req.party_size); end
                            if req.party_max_level~=nil then parts[#parts+1]='max level '..tostring(req.party_max_level)..' (observed '..tostring(ps.max_level or 'unknown')..')'; end
                            local pass=true;
                            if tonumber(req.party_size) and ps.count<tonumber(req.party_size) then pass=false; end
                            if tonumber(req.party_max_level) and ps.max_level and ps.max_level>tonumber(req.party_max_level) then pass=false; end
                            local st=(ps.levels_complete or req.party_max_level==nil) and (pass and 'PASS' or 'FAIL') or 'UNKNOWN';
                            imgui.TextDisabled('Party requirement: '..table.concat(parts,' | ')..' ['..st..']');
                        else
                            imgui.TextDisabled('Party requirement: mapped [party API unavailable]');
                        end
                    end
                    if req.weapon_skill~=nil and req.weapon_skill_level~=nil then
                        has_documented_req=true;
                        local have=DRAW_HELPERS.manual_weapon_skill_level(c,req.weapon_skill);
                        imgui.TextDisabled(string.format('Weapon skill requirement: %s %s | manual profile: %s',
                            tostring(req.weapon_skill),tostring(req.weapon_skill_level),tostring(have or 'unset')));
                    end
                    if req.fishing_skill~=nil then
                        has_documented_req=true;
                        local have=DRAW_HELPERS.manual_craft_skill_level(c,'Fishing');
                        local need=tonumber(req.fishing_skill);
                        local st=(have==nil and 'UNKNOWN') or ((not need or have>=need) and 'PASS' or 'FAIL');
                        imgui.TextDisabled(string.format('Fishing skill: need %s | profile %s [%s]',tostring(req.fishing_skill),tostring(have or 'unset'),st));
                    end
                    if type(req.equip_proof_items)=='table' then
                        has_documented_req=true;
                        local equipped,available=DRAW_HELPERS.equipped_item_name_set();
                        local matched=nil;
                        if available then
                            matched=false;
                            for _,iname in ipairs(req.equip_proof_items) do
                                if equipped[string.lower(tostring(iname))]==true then matched=true; break; end
                            end
                        end
                        imgui.TextDisabled('Equipability proof: equip one of '..table.concat(req.equip_proof_items,', ')..
                            ' ['..(matched==true and 'PASS' or (matched==false and 'NOT OBSERVED' or 'UNKNOWN'))..']');
                    end
                    if req.ws_trial_exclusive==true then
                        has_documented_req=true;
                        imgui.TextDisabled('Weaponskill trial slot: '..(c.quest_ws_trial_clear==true and 'CLEAR [manual]' or 'NOT VERIFIED'));
                    end
                    if type(req.mission_active)=='table' then
                        has_documented_req=true;
                        local m=req.mission_active;
                        local active=nil;
                        if HC and HC.modules and HC.modules.missions and HC.modules.missions.is_current then
                            active=HC.modules.missions.is_current(m.series or m.story,m.number or m.id or m.value);
                        end
                        local manual_key=tostring(m.manual_key or '');
                        local fallback=(manual_key~='' and DRAW_HELPERS.manual_condition_flag(c,manual_key)==true);
                        imgui.TextDisabled('Active mission: '..tostring(m.label or ((m.series or m.story or 'mission')..' '..tostring(m.number or m.id or m.value or '')))..
                            ' ['..(active==true and 'PASS' or (active==false and 'FAIL' or (fallback and 'PASS [manual]' or 'UNKNOWN')))..']');
                        if active==nil and manual_key~='' then
                            local current={fallback};
                            local idkey=manual_key:gsub('[^%w]+','_');
                            if imgui.Checkbox('Confirm active mission manually##quest_mission_active_'..sl..'_'..sq..'_'..idkey,current) then
                                c.quest_condition_flags[manual_key]=current[1] and {satisfied=true,at=os.time(),label=tostring(m.label or 'Active mission confirmed')} or nil;
                                HC.modules.state.save();
                            end
                        end
                    end
                    if type(req.mission_progress_min)=='table' then
                        has_documented_req=true;
                        local m=req.mission_progress_min;
                        local pass=nil;
                        if HC and HC.modules and HC.modules.missions and HC.modules.missions.progress_at_least then
                            pass=HC.modules.missions.progress_at_least(m.series or m.story,m.number or m.id or m.value);
                        end
                        local manual_key=tostring(m.manual_key or '');
                        local fallback=(manual_key~='' and DRAW_HELPERS.manual_condition_flag(c,manual_key)==true);
                        imgui.TextDisabled('Mission progress: '..tostring(m.label or ((m.series or m.story or 'mission')..' '..tostring(m.number or m.id or m.value or '')))..' or later ['..
                            (pass==true and 'PASS' or (pass==false and 'FAIL' or (fallback and 'PASS [manual]' or 'UNKNOWN')))..']');
                        if pass==nil and manual_key~='' then
                            local current={fallback};
                            local idkey=manual_key:gsub('[^%w]+','_');
                            if imgui.Checkbox('Confirm mission progress manually##quest_mission_progress_'..sl..'_'..sq..'_'..idkey,current) then
                                c.quest_condition_flags[manual_key]=current[1] and {satisfied=true,at=os.time(),label=tostring(m.label or 'Mission progress confirmed')} or nil;
                                HC.modules.state.save();
                            end
                        end
                    end
                    if req.mission_key~=nil then
                        has_documented_req=true;
                        local mdone=(type(c.mission_meta)=='table' and type(c.mission_meta.sources)=='table' and c.mission_meta.sources[tostring(req.mission_key)]~=nil);
                        imgui.TextDisabled('Mission prerequisite: '..tostring(req.mission_key)..' ['..(mdone and 'COMPLETE' or 'NOT VERIFIED')..']');
                    end
                    if type(req.mission_keys)=='table' then
                        has_documented_req=true;
                        for _,mk in ipairs(req.mission_keys) do
                            local mdone=(type(c.mission_meta)=='table' and type(c.mission_meta.sources)=='table' and c.mission_meta.sources[tostring(mk)]~=nil);
                            imgui.TextDisabled('Mission prerequisite: '..tostring(mk)..' ['..(mdone and 'COMPLETE' or 'NOT VERIFIED')..']');
                        end
                    end
                    if req.mission~=nil or req.missions~=nil then has_documented_req=true; imgui.TextDisabled('Mission prerequisite: '..tostring(req.mission or 'mapped')..' [runtime verification pending]'); end
                    if type(req.key_items)=='table' then
                        has_documented_req=true;
                        for _,ki in ipairs(req.key_items) do
                            local owned=nil; local err=nil;
                            if HC and HC.modules and HC.modules.keyitems and HC.modules.keyitems.ownership_name then
                                owned,err=HC.modules.keyitems.ownership_name(tostring(ki));
                            end
                            imgui.TextDisabled('Key item: '..tostring(ki)..' ['..(owned==true and 'OWNED' or (owned==false and 'NOT OWNED' or ('UNKNOWN'..(err and (': '..tostring(err)) or ''))))..']');
                        end
                    elseif req.key_items~=nil then
                        has_documented_req=true;
                        imgui.TextDisabled('Key item prerequisite: mapped [0x055 ownership check when available]');
                    end
                    if type(req.inventory_items)=='table' then
                        has_documented_req=true;
                        for _,it in ipairs(req.inventory_items) do
                            local id=tonumber(it.id or it.item_id);
                            local need=math.max(1,tonumber(it.count) or 1);
                            local label=tostring(it.name or ('item '..tostring(id or '?')));
                            local have=DRAW_HELPERS.inventory_item_count(id);
                            local st=(have==nil and 'UNKNOWN') or (have>=need and 'PASS' or 'FAIL');
                            imgui.TextDisabled(string.format('Inventory item: %s x%d | current %s [%s]',label,need,tostring(have or 'unknown'),st));
                        end
                    end
                    if type(req.wait_jst_midnight_after_quest)=='table' then
                        has_documented_req=true;
                        local w=req.wait_jst_midnight_after_quest;
                        local ql=tonumber(w.log_id or w.log); local qi=tonumber(w.quest_id or w.id);
                        local rec=(ql and qi) and DRAW_HELPERS.quest_completion_record(c,ql,qi) or nil;
                        local legacy_elapsed=(ql and qi) and M.legacy_completed_without_timestamp(c,ql,qi) or false;
                        local ready=rec and DRAW_HELPERS.next_jst_midnight_epoch(rec.at) or nil;
                        local zt=DRAW_HELPERS.latest_zone_refresh_at(c);
                        if not ready and legacy_elapsed then
                            imgui.TextDisabled('Japanese-midnight wait: legacy completed history; wait treated as elapsed [PASS]');
                        elseif not ready then
                            imgui.TextDisabled('Japanese-midnight wait: completion timestamp not observed for '..quest_name(ql,qi)..' [UNKNOWN]');
                        elseif os.time()<ready then
                            imgui.TextDisabled('Japanese-midnight wait: ready '..os.date('%Y-%m-%d %H:%M',ready)..' [WAIT]');
                        elseif req.zone_after_wait==true and (not zt or zt<ready) then
                            imgui.TextDisabled('Japanese-midnight wait: elapsed; zone change still required [UNKNOWN]');
                        else
                            imgui.TextDisabled('Japanese-midnight wait: elapsed'..(req.zone_after_wait==true and ' and zone refreshed' or '')..' [PASS]');
                        end
                    end
                    if type(req.zone_after_quest)=='table' then
                        has_documented_req=true;
                        local w=req.zone_after_quest;
                        local ql=tonumber(w.log_id or w.log); local qi=tonumber(w.quest_id or w.id);
                        local rec=(ql and qi) and DRAW_HELPERS.quest_completion_record(c,ql,qi) or nil;
                        local zt=DRAW_HELPERS.latest_zone_refresh_at(c);
                        local pass=(rec and tonumber(rec.at) and zt and zt>tonumber(rec.at));
                        imgui.TextDisabled('Post-quest zone change after '..quest_name(ql,qi)..' ['..(pass and 'PASS' or 'UNKNOWN')..']');
                    end
                    if type(req.wait_seconds_after_quest)=='table' then
                        has_documented_req=true;
                        local w=req.wait_seconds_after_quest;
                        local ql=tonumber(w.log_id or w.log); local qi=tonumber(w.quest_id or w.id);
                        local seconds=math.max(0,tonumber(w.seconds) or 0);
                        local rec=(ql and qi) and DRAW_HELPERS.quest_completion_record(c,ql,qi) or nil;
                        local ready=rec and tonumber(rec.at) and (tonumber(rec.at)+seconds) or nil;
                        local manual_key=tostring(w.manual_key or '');
                        local manual_ok=(manual_key~='' and DRAW_HELPERS.manual_condition_flag(c,manual_key)==true);
                        if ready then
                            imgui.TextDisabled(tostring(w.label or 'Timed wait')..': '..(os.time()>=ready and 'PASS' or ('WAIT until '..os.date('%Y-%m-%d %H:%M',ready))));
                        else
                            imgui.TextDisabled(tostring(w.label or 'Timed wait')..': '..(manual_ok and 'PASS [manual]' or 'UNKNOWN - completion timestamp not observed'));
                            if manual_key~='' then
                                local current={manual_ok};
                                local idkey=manual_key:gsub('[^%w]+','_');
                                if imgui.Checkbox('Confirm historical wait elapsed##quest_wait_'..sl..'_'..sq..'_'..idkey,current) then
                                    c.quest_condition_flags[manual_key]=current[1] and {satisfied=true,at=os.time(),label=tostring(w.label or 'Timed wait elapsed')} or nil;
                                    HC.modules.state.save();
                                end
                            end
                        end
                    end
                    if type(req.manual_flags)=='table' then
                        has_documented_req=true;
                        for _,spec in ipairs(req.manual_flags) do
                            local key,label=DRAW_HELPERS.manual_flag_parts(spec);
                            local auto_ok,auto_proof,auto_source=DRAW_HELPERS.auto_manual_flag_state(c,req,det,sl,key,label);
                            if auto_ok then
                                imgui.TextDisabled(tostring(label)..' [PASS - '..tostring(auto_proof or auto_source or 'auto-proven')..']');
                            else
                                local current={DRAW_HELPERS.manual_condition_flag(c,key)==true};
                                local idkey=key:gsub('[^%w]+','_');
                                if imgui.Checkbox(label..'##quest_condition_'..sl..'_'..sq..'_'..idkey,current) then
                                    c.quest_condition_flags[key]=current[1] and {satisfied=true,at=os.time(),label=label} or nil;
                                    HC.modules.state.save();
                                end
                            end
                        end
                        imgui.TextDisabled('Condition confirmations are character-specific and can be cleared at any time.');
                    end
                    if req.custom~=nil then
                        has_documented_req=true;
                        local auto_def=DRAW_HELPERS.automated_def and DRAW_HELPERS.automated_def(sl,sq) or nil;
                        if auto_def and auto_def.kind=='eco' then
                            imgui.TextDisabled('HorizonXI condition: '..tostring(req.custom)..' [tracked by Conquest-period repeat status]');
                        else
                            imgui.TextDisabled('HorizonXI condition: '..tostring(req.custom)..' [manual/runtime verification pending]');
                        end
                    end
                    if not has_documented_req and det.requirements_mapped~=true then imgui.TextDisabled('Prerequisites: not yet verified for HorizonXI.'); end

                    local manual_state=DRAW_HELPERS.manual_requirement_state(c,sl,sq);
                    local detail_auto=DRAW_HELPERS.automated_def and DRAW_HELPERS.automated_def(sl,sq) or nil;
                    local allow_manual_check=not (detail_auto and detail_auto.kind=='eco');
                    if av=='CHECK' and allow_manual_check then
                        if imgui.Button('Mark Manual Reqs Satisfied##quest_manual_req_ok_'..sl..'_'..sq) then
                            c.quest_manual_requirements[DRAW_HELPERS.quest_key(sl,sq)]={satisfied=true,at=os.time(),reason=tostring(reason or 'manual verification')};
                            HC.modules.state.save();
                        end
                        if imgui.IsItemHovered~=nil and imgui.IsItemHovered() then
                            imgui.SetTooltip('Use only after you personally confirm the remaining manual prerequisite(s). Known failed structured requirements still override this.');
                        end
                    elseif manual_state then
                        imgui.TextDisabled('Manual prerequisite verification: SATISFIED');
                        imgui.SameLine();
                        if imgui.SmallButton('Clear Manual Verification##quest_manual_req_clear_'..sl..'_'..sq) then
                            c.quest_manual_requirements[DRAW_HELPERS.quest_key(sl,sq)]=nil;
                            HC.modules.state.save();
                        end
                    end

                    imgui.Separator();
                    imgui.Text('BRING');
                    if det.items_needed and det.items_needed~='' then imgui.TextWrapped(tostring(det.items_needed)); else imgui.TextDisabled('No required-item list has been individually verified yet.'); end

                    imgui.Separator();
                    imgui.Text('WALKTHROUGH');
                    if det.objective and det.objective~='' then imgui.TextWrapped(tostring(det.objective)); else imgui.TextDisabled('Walkthrough not verified.'); end
                    if det.next_step and det.next_step~='' then imgui.TextWrapped('Next: '..tostring(det.next_step)); end

                    imgui.Separator();
                    imgui.Text('REWARD');
                    if det.reward and det.reward~='' then
                        imgui.TextWrapped(tostring(det.reward));
                        local dtags=DRAW_HELPERS.tags_text(det); if dtags~='' then imgui.TextDisabled('Tags: '..dtags); end
                    else
                        imgui.TextDisabled('Reward not verified.');
                    end

                    local prereqs=(det.requirements and det.requirements.quests) or nil;
                    local deps=DRAW_HELPERS.dependent_quests(sl,sq);
                    if (type(prereqs)=='table' and #prereqs>0) or #deps>0 then
                        imgui.Separator();
                        imgui.Text('QUEST CHAIN');
                        local chain_total=1+#deps+((type(prereqs)=='table') and #prereqs or 0);
                        local chain_done=(M.is_completed(sl,sq)==true) and 1 or 0;
                        if type(prereqs)=='table' then
                            for _,cq in ipairs(prereqs) do
                                local cql=tonumber(cq.log_id or cq.log); local cqi=tonumber(cq.quest_id or cq.id);
                                if cql~=nil and cqi~=nil and M.is_completed(cql,cqi)==true then chain_done=chain_done+1; end
                            end
                        end
                        for _,cq in ipairs(deps) do if M.is_completed(cq.log_id,cq.quest_id)==true then chain_done=chain_done+1; end end
                        imgui.TextDisabled(string.format('Progress: %d/%d complete',chain_done,chain_total));
                        if type(prereqs)=='table' then
                            for _,q in ipairs(prereqs) do
                                local ql=tonumber(q.log_id or q.log); local qi=tonumber(q.quest_id or q.id);
                                if ql~=nil and qi~=nil then
                                    local done=M.is_completed(ql,qi);
                                    imgui.TextDisabled(string.format('Previous: %s - %s',DRAW_HELPERS.quest_name(ql,qi),done==true and 'COMPLETE' or (done==false and 'NOT COMPLETE' or 'UNKNOWN'))); imgui.SameLine(); if imgui.SmallButton('Details##quest_chain_prev_'..ql..'_'..qi) then open_quest_detail(ql,qi); return; end;
                                end
                            end
                        end
                        for _,q in ipairs(deps) do
                            local av,why=DRAW_HELPERS.availability_state(c,q.log_id,q.quest_id);
                            local state2=M.is_completed(q.log_id,q.quest_id)==true and 'COMPLETED' or (DRAW_HELPERS.quest_active(q.log_id,q.quest_id)==true and 'ACTIVE' or av);
                            imgui.TextDisabled(string.format('Next: %s - %s%s',q.name,state2,(why and why~='' and (' ('..why..')') or ''))); imgui.SameLine(); if imgui.SmallButton('Details##quest_chain_next_'..q.log_id..'_'..q.quest_id) then open_quest_detail(q.log_id,q.quest_id); return; end;
                        end
                    end
                    local tag=DRAW_HELPERS.repeat_tag(sl,sq); if tag and det.repeat_type==nil then imgui.TextDisabled('Repeat: '..tag); end
                    local ast=DRAW_HELPERS.automated_status(c,sl,sq); if ast then imgui.Text('Tracker: '..ast); end
                    if det.horizon_notes and tostring(det.horizon_notes)~='' then
                        imgui.Separator(); imgui.Text('HORIZON NOTES'); imgui.TextWrapped(tostring(det.horizon_notes));
                    end
                else
                    imgui.TextDisabled('Detailed NPC/prerequisite metadata has not been mapped for this quest yet.');
                end
                if imgui.Button('Close Details##quest_detail_close') then c.settings.quest_detail_selected=''; c.settings.quest_detail_history={}; HC.modules.state.save(); end
            end
        end
    end

    imgui.Separator();
    local split_supported=(c.settings.quest_split_view==true and imgui.BeginTable~=nil and imgui.TableNextColumn~=nil and imgui.EndTable~=nil and imgui.BeginChild~=nil and imgui.EndChild~=nil);
    local split_open=false;
    local split_height=650;
    if split_supported and imgui.BeginTable('##quest_split_view_v6801',2,512) then
        split_open=true;
        if imgui.TableSetupColumn~=nil then
            -- Stretch weights keep the list compact while giving walkthroughs room.
            pcall(function() imgui.TableSetupColumn('Quests',0,0.38,0); end);
            pcall(function() imgui.TableSetupColumn('Quest Details',0,0.62,1); end);
        end
        imgui.TableNextColumn();
        imgui.BeginChild('##quest_list_pane_v6801',{0,split_height},(ImGuiChildFlags_Borders or 1),0);
    end
    local visible_total=0;
    local search=string.lower(tostring(c.settings.quest_search or '')):gsub('^%s+',''):gsub('%s+$','');

    local function quest_passes_catalog_filters(log,qid)
        local det=DRAW_HELPERS.quest_detail(log,qid);
        if type(det)=='table' and type(det.horizon)=='table' and det.horizon.enabled==false then return false; end
        if c.settings.quest_mapped_only and det==nil then return false; end
        if c.settings.quest_catalog_gaps_only and not DRAW_HELPERS.catalog_field_missing(det,c.settings.quest_missing_filter) then return false; end
        local ef=tostring(c.settings.quest_expansion_filter or 'all');
        if ef~='all' then
            if det==nil then return false; end
            local ex=string.lower(tostring(det.expansion or ''));
            if ef=='base' and ex~='base' then return false; end
            if ef=='zilart' and ex~='rise of the zilart' then return false; end
            if ef=='cop' and ex~='chains of promathia' then return false; end
            if ef=='toau' and ex~='treasures of aht urhgan' then return false; end
        end
        return true;
    end

    local function current_sort_mode()
        if c.settings.quest_view=='active' or c.settings.quest_view=='attention' then
            return tostring(c.settings.quest_active_sort or 'smart');
        end
        if c.settings.quest_view=='available' and tostring(c.settings.quest_candidate_mode or 'ready')=='ready' then
            return tostring(c.settings.quest_ready_sort or 'smart');
        end
        return tostring(c.settings.quest_sort or 'smart');
    end

    local function sort_view_rows(rows,log)
        local mode=current_sort_mode();
        if mode=='smart' and (c.settings.quest_view=='active' or c.settings.quest_view=='attention') then DRAW_HELPERS.sort_rows(rows); return; end
        if mode=='smart' then return; end
        table.sort(rows,function(a,b)
            local da,db=DRAW_HELPERS.quest_detail(log,a.qid) or {},DRAW_HELPERS.quest_detail(log,b.qid) or {};
            if mode=='unlocks' then
                local ca=tonumber(DRAW_HELPERS.dependent_quest_count(log,a.qid) or 0) or 0;
                local cb=tonumber(DRAW_HELPERS.dependent_quest_count(log,b.qid) or 0) or 0;
                if ca~=cb then return ca>cb; end
            end
            local va,vb;
            if mode=='current_zone' then
                local ha=DRAW_HELPERS.quest_starts_in_current_zone(da);
                local hb=DRAW_HELPERS.quest_starts_in_current_zone(db);
                if ha~=hb then return ha==true; end
                va,vb=string.lower(tostring(da.start_zone or 'zzzz')),string.lower(tostring(db.start_zone or 'zzzz'));
            elseif mode=='zone' then
                va,vb=string.lower(tostring(da.start_zone or 'zzzz')),string.lower(tostring(db.start_zone or 'zzzz'));
            elseif mode=='reward' then
                va,vb=string.lower(DRAW_HELPERS.tags_text(da)..tostring(da.reward or 'zzzz')),string.lower(DRAW_HELPERS.tags_text(db)..tostring(db.reward or 'zzzz'));
            elseif mode=='next_step' then
                va,vb=string.lower(tostring(a.next_step or da.next_step or 'zzzz')),string.lower(tostring(b.next_step or db.next_step or 'zzzz'));
            else
                va,vb=string.lower(a.name or ''),string.lower(b.name or '');
            end
            if va~=vb then return va<vb; end
            local na,nb=string.lower(a.name or ''),string.lower(b.name or '');
            if na~=nb then return na<nb; end
            return (a.qid or 0)<(b.qid or 0);
        end);
    end

    for log=0,10 do
        local rows={};
        if c.settings.quest_view=='reward_search' then
            if search~='' then
                for _,qid in ipairs(DRAW_HELPERS.catalog_ids(log)) do
                    if quest_passes_catalog_filters(log,qid) then
                        local det=DRAW_HELPERS.quest_detail(log,qid) or {};
                        local reward=tostring(det.reward or '');
                        if reward~='' and string.lower(reward):find(search,1,true)~=nil then
                            local name=DRAW_HELPERS.quest_name(log,qid);
                            local state='UNKNOWN';
                            if DRAW_HELPERS.quest_active(log,qid)==true then
                                state='ACTIVE';
                            elseif M.is_completed(log,qid)==true then
                                state='COMPLETED';
                            else
                                local av=DRAW_HELPERS.availability_state(c,log,qid);
                                if av=='AVAILABLE' then state='READY'
                                elseif av=='CHECK' then state='CHECK'
                                elseif av=='MANUAL' then state='MANUAL'
                                elseif av=='LOCKED' then state='LOCKED'
                                else state='UNMAPPED' end
                            end
                            rows[#rows+1]={qid=qid,name=name,reward=reward,reward_state=state};
                        end
                    end
                end
                table.sort(rows,function(a,b)
                    local ra,rb=string.lower(tostring(a.reward or '')),string.lower(tostring(b.reward or ''));
                    if ra~=rb then return ra<rb; end
                    local na,nb=string.lower(a.name or ''),string.lower(b.name or '');
                    if na~=nb then return na<nb; end
                    return (a.qid or 0)<(b.qid or 0);
                end);
            end
        elseif (c.settings.quest_view=='active' or c.settings.quest_view=='attention') and current[log] then
            for _,qid in ipairs(DRAW_HELPERS.active_ids(log)) do
                if quest_passes_catalog_filters(log,qid) then
                local name=DRAW_HELPERS.quest_name(log,qid);
                local status,is_auto=DRAW_HELPERS.automated_status(c,log,qid);
                local det=DRAW_HELPERS.quest_detail(log,qid);
                local attention=(DRAW_HELPERS.is_actionable_badge(status) or (det and det.next_step and det.next_step~=''));
                local repeat_only=(current_sort_mode()=='repeatable');
                if (not repeat_only or DRAW_HELPERS.quest_is_repeatable(log,qid))
                    and (c.settings.quest_view~='attention' or attention)
                    and DRAW_HELPERS.quest_matches_filter(log,qid,name,status,c.settings.quest_search,c.settings.quest_automated_only,c.settings.quest_ready_only) then
                    rows[#rows+1]={qid=qid,name=name,status=status,is_auto=is_auto,repeat_tag=DRAW_HELPERS.repeat_tag(log,qid),next_step=(det and det.next_step or nil)};
                end
                end
            end
            sort_view_rows(rows,log);
        elseif c.settings.quest_view=='available' and DRAW_HELPERS.available_log_supported(log) then
            for _,qid in ipairs(DRAW_HELPERS.catalog_ids(log)) do
                local is_repeatable=DRAW_HELPERS.quest_is_repeatable(log,qid);
                if quest_passes_catalog_filters(log,qid) and DRAW_HELPERS.quest_active(log,qid)~=true and (M.is_completed(log,qid)~=true or is_repeatable) then
                    local name=DRAW_HELPERS.quest_name(log,qid);
                    local av,reason=DRAW_HELPERS.availability_state(c,log,qid);
                    local mode=tostring(c.settings.quest_candidate_mode or 'ready');
                    local include=(mode=='ready' and av=='AVAILABLE')
                        or (mode=='check' and (av=='CHECK' or av=='MANUAL'))
                        or (mode=='all' and (av=='AVAILABLE' or av=='CHECK' or av=='MANUAL'));
                    local repeat_only=(current_sort_mode()=='repeatable');
                        local det=DRAW_HELPERS.quest_detail(log,qid) or {};
                    local zone_only=(c.settings.quest_ready_zone_only==true);
                    local starts_here=(not zone_only) or DRAW_HELPERS.quest_starts_in_current_zone(det);
                    if include and starts_here and (not repeat_only or is_repeatable) then
                        local reason_category=lock_reason_category(reason,det);
                        local cf=string.lower(tostring(c.settings.quest_check_filter or 'all'));
                        local check_filter_ok=(av~='CHECK') or cf=='all' or string.lower(reason_category)==cf;
                        local manually_ok=(DRAW_HELPERS.manual_requirement_state(c,log,qid)~=nil);
                        local mf=string.lower(tostring(c.settings.quest_manual_filter or 'all'));
                        local manual_filter_ok=(mf=='all') or (mf=='confirmed' and manually_ok) or (mf=='unconfirmed' and not manually_ok);
                        local hay=string.lower(table.concat({name,M.log_name(log),tostring(qid),av,reason,reason_category,tostring(det.start_npc or ''),tostring(det.start_zone or ''),tostring(det.expansion or ''),tostring(det.objective or ''),tostring(det.items_needed or ''),tostring(det.reward or ''),tostring(det.next_step or ''),DRAW_HELPERS.requirements_search_text(det),DRAW_HELPERS.catalog_status(det)},' '));
                        if check_filter_ok and manual_filter_ok and (search=='' or hay:find(search,1,true)~=nil) then
                            rows[#rows+1]={qid=qid,name=name,availability=av,reason=reason,reason_category=reason_category};
                        end
                    end
                end
            end
            if current_sort_mode()=='smart' then
                table.sort(rows,function(a,b)
                    local rank={AVAILABLE=4,CHECK=3,MANUAL=2,LOCKED=1,UNKNOWN=0}; local pa,pb=rank[a.availability] or 0,rank[b.availability] or 0;
                    if pa~=pb then return pa>pb; end
                    local na,nb=string.lower(a.name or ''),string.lower(b.name or '');
                    if na~=nb then return na<nb; end
                    return (a.qid or 0)<(b.qid or 0);
                end);
            else
                sort_view_rows(rows,log);
            end
        elseif c.settings.quest_view=='locked' and DRAW_HELPERS.available_log_supported(log) then
            for _,qid in ipairs(DRAW_HELPERS.catalog_ids(log)) do
                if quest_passes_catalog_filters(log,qid) and DRAW_HELPERS.quest_active(log,qid)~=true and M.is_completed(log,qid)~=true then
                    local name=DRAW_HELPERS.quest_name(log,qid);
                    local av,reason=DRAW_HELPERS.availability_state(c,log,qid);
                    if av=='LOCKED' then
                        local det=DRAW_HELPERS.quest_detail(log,qid) or {};
                        local raw_reason=tostring(reason or 'Locked');
                        local blocker=nil;
                        if HC.modules and HC.modules.blockers and HC.modules.blockers.quest then
                            local okb,b=pcall(HC.modules.blockers.quest,c,log,qid,av,raw_reason);
                            if okb and type(b)=='table' then blocker=b; end
                        end
                        local display_reason=(blocker and tostring(blocker.summary or '')~='' and blocker.summary) or raw_reason;
                        local rcat=lock_reason_category(raw_reason,det);
                        local lf=tostring(c.settings.quest_locked_filter or 'all');
                        local lock_filter_ok=(lf=='all' or lf==rcat);
                        local hay=string.lower(table.concat({name,M.log_name(log),tostring(qid),display_reason,raw_reason,rcat,tostring(det.start_npc or ''),tostring(det.start_zone or ''),tostring(det.expansion or ''),tostring(det.objective or ''),tostring(det.items_needed or ''),tostring(det.reward or ''),tostring(det.next_step or ''),DRAW_HELPERS.requirements_search_text(det),DRAW_HELPERS.catalog_status(det)},' '));
                        if lock_filter_ok and (search=='' or hay:find(search,1,true)~=nil) then
                            rows[#rows+1]={qid=qid,name=name,availability=av,reason=display_reason,raw_reason=raw_reason,blocker=blocker,reason_category=rcat};
                        end
                    end
                end
            end
            table.sort(rows,function(a,b)
                local ca,cb=tostring(a.reason_category or 'Other'),tostring(b.reason_category or 'Other');
                if ca~=cb then return ca<cb; end
                local na,nb=string.lower(a.name or ''),string.lower(b.name or '');
                if na~=nb then return na<nb; end
                return (a.qid or 0)<(b.qid or 0);
            end);
        elseif c.settings.quest_view=='verify' and DRAW_HELPERS.available_log_supported(log) then
            for _,qid in ipairs(DRAW_HELPERS.catalog_ids(log)) do
                if quest_passes_catalog_filters(log,qid) and DRAW_HELPERS.quest_active(log,qid)~=true and M.is_completed(log,qid)~=true then
                    local name=DRAW_HELPERS.quest_name(log,qid);
                    local av,reason=DRAW_HELPERS.availability_state(c,log,qid);
                    if av=='UNKNOWN' then
                        local det=DRAW_HELPERS.quest_detail(log,qid) or {};
                        local reqcat=lock_reason_category(reason,det);
                        local hay=string.lower(table.concat({name,M.log_name(log),tostring(qid),reason,reqcat,tostring(det.start_npc or ''),tostring(det.start_zone or ''),tostring(det.expansion or ''),DRAW_HELPERS.requirements_search_text(det)},' '));
                        if search=='' or hay:find(search,1,true)~=nil then
                            rows[#rows+1]={qid=qid,name=name,availability=av,reason=reason,reason_category=reqcat};
                        end
                    end
                end
            end
            table.sort(rows,function(a,b)
                local ca,cb=tostring(a.reason_category or 'Other'),tostring(b.reason_category or 'Other');
                if ca~=cb then return ca<cb; end
                local na,nb=string.lower(a.name or ''),string.lower(b.name or '');
                if na~=nb then return na<nb; end
                return (a.qid or 0)<(b.qid or 0);
            end);
        elseif c.settings.quest_view=='quality' and DRAW_HELPERS.available_log_supported(log) then
            for _,qid in ipairs(DRAW_HELPERS.catalog_ids(log)) do
                if quest_passes_catalog_filters(log,qid) then
                    local det=DRAW_HELPERS.quest_detail(log,qid) or {};
                    local issues=DRAW_HELPERS.catalog_quality_issues(det);
                    if not DRAW_HELPERS.catalog_quality_verified(det) then
                        local name=DRAW_HELPERS.quest_name(log,qid);
                        local issue_text=table.concat(issues,', ');
                        local qscore,qtotal,qlabel=DRAW_HELPERS.catalog_quality_score(det);
                        local qfilter=string.lower(tostring(c.settings.quest_quality_filter or 'all'));
                        local tier_ok=(qfilter=='all' or string.lower(qlabel)==qfilter);
                        local hay=string.lower(table.concat({name,M.log_name(log),tostring(qid),issue_text,qlabel,tostring(det.start_npc or ''),tostring(det.start_zone or ''),tostring(det.expansion or ''),tostring(det.objective or ''),tostring(det.items_needed or ''),tostring(det.reward or ''),tostring(det.next_step or '')},' '));
                        if tier_ok and (search=='' or hay:find(search,1,true)~=nil) then
                            rows[#rows+1]={qid=qid,name=name,quality_issues=issue_text,quality_score=qscore,quality_total=qtotal,quality_label=qlabel};
                        end
                    end
                end
            end
            table.sort(rows,function(a,b)
                local sa,sb=tonumber(a.quality_score or 0),tonumber(b.quality_score or 0);
                if sa~=sb then return sa<sb; end
                local na,nb=string.lower(a.name or ''),string.lower(b.name or '');
                if na~=nb then return na<nb; end
                return (a.qid or 0)<(b.qid or 0);
            end);
        elseif c.settings.quest_view=='completed' and completed[log] then
            for _,qid in ipairs(DRAW_HELPERS.completed_ids(log)) do
                if quest_passes_catalog_filters(log,qid) then
                local name=DRAW_HELPERS.quest_name(log,qid);
                local det=DRAW_HELPERS.quest_detail(log,qid) or {}; local hay=string.lower(table.concat({name,M.log_name(log),tostring(qid),tostring(det.start_npc or ''),tostring(det.start_zone or ''),tostring(det.expansion or ''),tostring(det.objective or ''),tostring(det.items_needed or ''),tostring(det.reward or ''),tostring(det.next_step or ''),DRAW_HELPERS.requirements_search_text(det),DRAW_HELPERS.catalog_status(det)},' '));
                if search=='' or hay:find(search,1,true)~=nil then
                    rows[#rows+1]={qid=qid,name=name};
                end
                end
            end
            table.sort(rows,function(a,b)
                local na,nb=string.lower(a.name or ''),string.lower(b.name or '');
                if na~=nb then return na<nb; end
                return (a.qid or 0)<(b.qid or 0);
            end);
        end

        if #rows>0 and current_sort_mode()~='smart' then sort_view_rows(rows,log); end

        if #rows>0 then
            visible_total=visible_total+#rows;
            local open=region_open[log];
            if open==nil then open=true; region_open[log]=true; end
            if search~='' then open=true; end -- search results should never remain hidden inside a collapsed region
            local arrow=open and 'v' or '>';
            local suffix=' shown';
            if c.settings.quest_view=='completed' then suffix=' completed'
            elseif c.settings.quest_view=='available' and candidate_mode=='ready' then suffix=' ready'
            elseif c.settings.quest_view=='available' and candidate_mode=='check' then suffix=' check'
            elseif c.settings.quest_view=='available' then suffix=' candidates'
            elseif c.settings.quest_view=='locked' then suffix=' locked'
            elseif c.settings.quest_view=='verify' then suffix=' unmapped'
            elseif c.settings.quest_view=='attention' then suffix=' next steps'
            elseif c.settings.quest_view=='quality' then suffix=' quality audit'
            elseif c.settings.quest_view=='reward_search' then suffix=' reward matches' end
            local a_ct=current[log] and #DRAW_HELPERS.active_ids(log) or 0; local d_ct=completed[log] and #DRAW_HELPERS.completed_ids(log) or 0;
            local av_ct,check_ct,manual_ct,lk_ct=0,0,0,0;
            if DRAW_HELPERS.available_log_supported(log) then
                for _,qid in ipairs(DRAW_HELPERS.catalog_ids(log)) do
                    if DRAW_HELPERS.quest_active(log,qid)~=true and M.is_completed(log,qid)~=true then
                        local av=DRAW_HELPERS.availability_state(c,log,qid);
                        if av=='AVAILABLE' then av_ct=av_ct+1
                        elseif av=='CHECK' then check_ct=check_ct+1
                        elseif av=='MANUAL' then manual_ct=manual_ct+1
                        elseif av=='LOCKED' then lk_ct=lk_ct+1 end
                    end
                end
            end
            local mapped_ct,complete_ct,partial_ct,basic_ct,enriched_ct,enriched_pct=DRAW_HELPERS.region_catalog_stats(log);
            local progress=(mapped_ct>0 and string.format(' | completed %d/%d | catalog %d/%d enriched (%d%%)',d_ct,mapped_ct,enriched_ct,mapped_ct,enriched_pct) or '');
            if c.settings.quest_view=='quality' then
                local qg,qs,qb,qr,qv=DRAW_HELPERS.region_quality_stats(log);
                progress=progress..string.format(' | quality G%d S%d B%d R%d | verified %d',qg,qs,qb,qr,qv);
            end
            local label=nil;
            if c.settings.quest_ui_advanced then
                label=string.format('%s  %s - %d%s | %d active | %d ready | %d check | %d locked%s##questlog_toggle_%s_%d',arrow,M.log_name(log),#rows,suffix,a_ct,av_ct,check_ct+manual_ct,lk_ct,progress,c.settings.quest_view,log);
            else
                label=string.format('%s  %s - %d%s##questlog_toggle_%s_%d',arrow,M.log_name(log),#rows,suffix,c.settings.quest_view,log);
            end
            local header_pressed=false;
            if type(imgui.Button)=='function' then
                local ok,res=pcall(imgui.Button,label,{-1,0});
                if ok then
                    header_pressed=(res==true);
                else
                    header_pressed=imgui.Button(label);
                end
            end
            if header_pressed then
                region_open[log]=not open; HC.modules.state.save(); open=not open;
            end
            if open then
                for _,r in ipairs(rows) do
                    local is_sel=(c.settings.quest_detail_selected==DRAW_HELPERS.quest_key(log,r.qid));
                    if split_open then
                        local state='';
                        if c.settings.quest_view=='active' or c.settings.quest_view=='attention' then
                            state=tostring(r.status or 'ACTIVE');
                        elseif c.settings.quest_view=='available' then
                            if r.availability=='AVAILABLE' then state='READY'
                            elseif r.availability=='CHECK' then state='CHECK: '..tostring(r.reason_category or 'Other')
                            elseif r.availability=='MANUAL' then state='MANUAL'
                            else state='UNMAPPED' end
                        elseif c.settings.quest_view=='locked' then state='LOCKED: '..tostring(r.reason_category or 'Other')
                        elseif c.settings.quest_view=='verify' then state='UNMAPPED'
                        elseif c.settings.quest_view=='quality' then state=tostring(r.quality_label or 'AUDIT')
                        elseif c.settings.quest_view=='reward_search' then state=tostring(r.reward_state or 'MATCH')
                        else state='COMPLETED' end
                        local row_label=tostring(r.name)..'  ['..state..']##quest_select_'..tostring(c.settings.quest_view)..'_'..tostring(log)..'_'..tostring(r.qid);
                        local pressed=false;
                        if type(imgui.Selectable)=='function' then
                            local ok,res=pcall(imgui.Selectable,row_label,is_sel);
                            if ok then
                                pressed=(res==true);
                            else
                                pressed=imgui.Button((is_sel and '> ' or '  ')..row_label);
                            end
                        else
                            pressed=imgui.Button((is_sel and '> ' or '  ')..row_label);
                        end
                        if pressed then open_quest_detail(log,r.qid); end
                    else
                        if imgui.Button((is_sel and '[Details]' or 'Details')..'##quest_detail_'..tostring(c.settings.quest_view)..'_'..tostring(log)..'_'..tostring(r.qid)) then
                            open_quest_detail(log,r.qid);
                        end
                        imgui.SameLine();
                        imgui.Text(r.name);
                    end
                    local rdet=DRAW_HELPERS.quest_detail(log,r.qid); local rtags=DRAW_HELPERS.tags_text(rdet);
                    if c.settings.quest_view=='reward_search' and split_open then
                        imgui.TextDisabled('Reward: '..tostring(r.reward or (rdet and rdet.reward) or ''));
                    end
                    if not split_open then
                    if rtags~='' then imgui.SameLine(); imgui.TextDisabled(rtags); end
                    if rdet and (c.settings.quest_ui_advanced or c.settings.quest_view=='quality') then
                        local _,_,rql=DRAW_HELPERS.catalog_quality_score(rdet);
                        imgui.SameLine(); imgui.TextDisabled('['..tostring(rql)..']');
                    end
                    if c.settings.quest_view=='active' or c.settings.quest_view=='attention' then
                        if r.repeat_tag then imgui.SameLine(); imgui.TextDisabled('['..r.repeat_tag..']'); end
                        if r.status then imgui.SameLine(); imgui.TextDisabled('['..r.status..']');
                        else imgui.SameLine(); imgui.TextDisabled('[ACTIVE]'); end
                        if r.next_step and r.next_step~='' then imgui.TextDisabled('  Next: '..tostring(r.next_step)); end
                    elseif c.settings.quest_view=='available' then
                        imgui.SameLine();
                        if r.availability=='AVAILABLE' then
                            imgui.TextDisabled('[CAN START]');
                            if DRAW_HELPERS.quest_is_repeatable(log,r.qid) then
                                local rs=DRAW_HELPERS.repeatable_status(c,log,r.qid);
                                imgui.SameLine(); imgui.TextDisabled('['..tostring(rs or 'REPEATABLE')..']');
                            end
                        elseif r.availability=='CHECK' then
                            imgui.TextDisabled('[CHECK: '..tostring(r.reason_category or 'Other')..']');
                            if c.settings.quest_ui_advanced then
                                imgui.TextDisabled('  '..tostring(r.reason or 'character evidence required'));
                                if imgui.SmallButton('Confirm Whole Quest##quest_row_manual_ok_'..log..'_'..r.qid) then
                                    c.quest_manual_requirements[DRAW_HELPERS.quest_key(log,r.qid)]={satisfied=true,at=os.time(),reason=tostring(r.reason or 'manual verification')};
                                    HC.modules.state.save();
                                end
                            end
                        elseif r.availability=='MANUAL' then
                            imgui.TextDisabled('[MANUAL CATALOG CHECK]');
                            if c.settings.quest_ui_advanced and imgui.SmallButton('Confirm Whole Quest##quest_row_manual_ok_'..log..'_'..r.qid) then
                                c.quest_manual_requirements[DRAW_HELPERS.quest_key(log,r.qid)]={satisfied=true,at=os.time(),reason='generic catalog prerequisite manually confirmed'};
                                HC.modules.state.save();
                            end
                        else imgui.TextDisabled('[UNMAPPED: '..tostring(r.reason or 'verification needed')..']') end
                    elseif c.settings.quest_view=='locked' then
                        imgui.SameLine(); imgui.TextDisabled('[LOCKED: '..tostring(r.reason_category or 'Other')..']');
                        if c.settings.quest_ui_advanced then imgui.TextDisabled('  '..tostring(r.reason or 'mapped prerequisite')); end
                    elseif c.settings.quest_view=='verify' then
                        imgui.SameLine(); imgui.TextDisabled('[VERIFY '..tostring(r.reason_category or 'Requirements')..': '..tostring(r.reason or 'manual verification needed')..']');
                    elseif c.settings.quest_view=='quality' then
                        imgui.SameLine(); imgui.TextDisabled(string.format('[%s %d/%d | %s]',tostring(r.quality_label or 'AUDIT'),tonumber(r.quality_score or 0),tonumber(r.quality_total or 10),tostring(r.quality_issues or 'verification needed')));
                    else
                        imgui.SameLine(); imgui.TextDisabled('[COMPLETED]');
                    end
                    end -- not split_open: split rows already include status in the selector
                end
            end
        end
    end

    if search~='' and visible_total>0 then
        imgui.TextDisabled(string.format('Search results: %d quest(s)',visible_total));
    end

    if visible_total==0 then
        if c.settings.quest_view=='completed' and completed_seen==0 then
            imgui.TextDisabled('Waiting for completed quest history - zone once.');
        elseif (c.settings.quest_view=='available' or c.settings.quest_view=='locked' or c.settings.quest_view=='verify') and completed_seen==0 then
            imgui.TextDisabled('Waiting for completed quest history - zone once.');
        else
            imgui.TextDisabled('No quests match the current view/filter.');
        end
    end
    if split_open then
        imgui.EndChild();
        imgui.TableNextColumn();
        imgui.BeginChild('##quest_details_pane_v6801',{0,split_height},(ImGuiChildFlags_Borders or 1),0);
        imgui.Text('Quest Details');
        imgui.Separator();
        if c.settings.quest_detail_selected~='' then
            draw_selected_quest_details();
        else
            imgui.TextDisabled('Select a quest in the left pane to view its prerequisites, walkthrough, rewards, and quest chain here.');
        end
        imgui.EndChild();
        imgui.EndTable();
    elseif c.settings.quest_detail_selected~='' then
        imgui.Separator();
        draw_selected_quest_details();
    end

    imgui.Separator();
    if c.settings.quest_view=='active' then
        imgui.TextDisabled('ACTIVE state is native 0x056 verified. Use Details for mapped NPC/zone/next-step information; leaving ACTIVE alone is not treated as completion.');
    elseif c.settings.quest_view=='available' and candidate_mode=='ready' then
        imgui.TextDisabled('Ready lists only quests whose mapped prerequisites are currently satisfied for this character.');
        imgui.TextDisabled('Reward Search searches reward text across the entire mapped catalog, so items such as Warp scrolls can be found even when the quest is Locked or Completed.');
    elseif c.settings.quest_view=='available' and candidate_mode=='check' then
        imgui.TextDisabled('Check lists quests that still need live client data or character-specific evidence. Open Details to see each PASS / FAIL / UNKNOWN condition.');
    elseif c.settings.quest_view=='available' then
        imgui.TextDisabled('All Candidates combines Ready and Check quests.');
    elseif c.settings.quest_view=='locked' then
        imgui.TextDisabled('Locked is grouped and filterable by the blocking requirement. Use the reason buttons above to focus on the progression blocker you want to clear.');
    elseif c.settings.quest_view=='verify' then
        imgui.TextDisabled('Unmapped contains only quests without usable prerequisite metadata. Documented manual requirements stay under Available* as CHECK REQS.');
    elseif c.settings.quest_view=='attention' then
        imgui.TextDisabled('Next Steps is active-quest coverage, not an error list.');
    elseif c.settings.quest_view=='quality' then
        imgui.TextDisabled('Quality Audit is catalog-data QA only. It does not alter Active, Completed, Available, or Locked state. Use Details to review the flagged fields.');
    else
        imgui.TextDisabled('COMPLETED state is read directly from native 0x056 completed-history tables and cached per character. Use Capture Missing History once, then open the in-game Completed quest regions so every log is retained across zones and allegiance changes.');
    end
end


-- Read-only catalog/runtime accessors used by the dependency graph and
-- catalog-integrity engines. They intentionally expose normalized records rather
-- than the mutable metadata table itself.
function M.catalog_entries()
    local out={};
    for log=0,6 do
        if available_log_supported(log) then
            for _,qid in ipairs(catalog_ids(log)) do
                local det=metadata_for(log,qid) or {};
                out[#out+1]={log_id=log,quest_id=qid,name=quest_name(log,qid),detail=det};
            end
        end
    end
    table.sort(out,function(a,b) if a.log_id~=b.log_id then return a.log_id<b.log_id; end return a.quest_id<b.quest_id; end);
    return out;
end
function M.detail(log_id,quest_id) return quest_detail(log_id,quest_id); end
function M.availability(c,log_id,quest_id) return availability_state(c,log_id,quest_id); end
function M.is_repeatable(log_id,quest_id) return quest_is_repeatable(log_id,quest_id); end
function M.repeat_status(c,log_id,quest_id) return repeatable_status(c,log_id,quest_id); end
function M.started_or_completed(log_id,quest_id) return native_quest_started_or_completed(log_id,quest_id); end
function M.starts_in_current_zone(log_id,quest_id) return quest_starts_in_current_zone(metadata_for(log_id,quest_id)); end
function M.current_zone() return current_zone_name(); end

function M.progression_overview(c) return progression_overview(c); end
function M.invalidate_runtime_cache(clear_canonical)
    invalidate_progression_overview();
    if clear_canonical==true then canonical_policy_cache={}; end
end
function M.priority_score(c,log_id,quest_id) return priority_score(c,log_id,quest_id); end
function M.job_progression(c,job_abbr,level) return job_progression(c,job_abbr,level); end
function M.quest_tab_summary()
    return M._last_summary;
end

return M;
