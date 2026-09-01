local M = {};
local HC;
local rules=nil;
local cache={at=0,snapshot=nil};

local VALID={AVAILABLE=true,FUTURE=true,HORIZON_CUSTOM=true,UNVERIFIED=true,DISABLED=true};

local function lower(v) return string.lower(tostring(v or '')); end
local function load_rules()
    if rules~=nil then return rules; end
    rules={mission_caps={},unavailable_expansions={}};
    if not HC or not HC.addon_path then return rules; end
    local path=HC.addon_path..'data\\horizon_availability.lua';
    local ok,t=pcall(dofile,path);
    if ok and type(t)=='table' then rules=t; end
    rules.mission_caps=type(rules.mission_caps)=='table' and rules.mission_caps or {};
    rules.unavailable_expansions=type(rules.unavailable_expansions)=='table' and rules.unavailable_expansions or {};
    return rules;
end

local function result(state,reason,source,verified,meta)
    state=string.upper(tostring(state or 'UNVERIFIED'));
    if not VALID[state] then state='UNVERIFIED'; end
    return {state=state,reason=tostring(reason or ''),source=tostring(source or ''),verified=verified==true,meta=meta};
end

function M.quest(log_id,quest_id,detail)
    local q=HC and HC.modules and HC.modules.quests or nil;
    if type(detail)~='table' and q and q.detail then
        local ok,v=pcall(q.detail,log_id,quest_id); if ok then detail=v; end
    end
    detail=type(detail)=='table' and detail or {};
    local h=type(detail.horizon)=='table' and detail.horizon or nil;
    if h then
        if h.enabled==false then
            return result('FUTURE','Explicitly disabled for the current HorizonXI catalog.',h.source or 'quest catalog',h.verified==true,{log_id=log_id,quest_id=quest_id});
        end
        local src=lower(h.source);
        if h.custom==true or src:find('custom',1,true) then
            return result('HORIZON_CUSTOM','HorizonXI-specific/customized content.',h.source or 'quest catalog',h.verified==true,{log_id=log_id,quest_id=quest_id});
        end
        if h.enabled==true and h.verified==true then
            return result('AVAILABLE','Verified in the HorizonXI quest catalog.',h.source or 'quest catalog',true,{log_id=log_id,quest_id=quest_id});
        end
        if h.enabled==true then
            return result('UNVERIFIED','Cataloged for HorizonXI but not yet fully verified.',h.source or 'quest catalog',false,{log_id=log_id,quest_id=quest_id});
        end
    end

    local exp=lower(detail.expansion);
    local r=load_rules().unavailable_expansions[exp];
    if r then return result(r.state or 'FUTURE',r.reason,r.source,false,{log_id=log_id,quest_id=quest_id}); end
    return result('UNVERIFIED','No explicit HorizonXI availability record.',h and h.source or 'quest catalog',false,{log_id=log_id,quest_id=quest_id});
end

function M.mission(series_id,number,meta)
    local sid=lower(series_id); local n=tonumber(number); local rr=load_rules();
    local cap=rr.mission_caps[sid];
    if cap and n then
        if n>tonumber(cap.current or math.huge) then
            return result('FUTURE',cap.future_reason or ('Beyond current mission cap '..tostring(cap.current)),cap.source or 'mission availability profile',true,{series_id=sid,number=n,cap=cap.current});
        end
        return result('AVAILABLE','Within the current HorizonXI mission progression range.',cap.source or 'mission availability profile',true,{series_id=sid,number=n,cap=cap.current});
    end
    if sid=='crystal_war' or sid=='wotg' then
        local r=rr.unavailable_expansions['crystal war'] or {};
        return result(r.state or 'FUTURE',r.reason or 'Not currently available on HorizonXI.',r.source or 'mission availability profile',true,{series_id=sid,number=n});
    end
    return result('AVAILABLE','Supported mission series in the current HorizonCheck profile.','mission catalog',true,{series_id=sid,number=n});
end

function M.system(id)
    return result('AVAILABLE','Runtime tracker is present in this HorizonCheck build.','runtime system profile',true,{id=tostring(id or '')});
end

function M.is_actionable(v)
    local s=type(v)=='table' and tostring(v.state or '') or tostring(v or '');
    s=string.upper(s);
    return s~='FUTURE' and s~='DISABLED';
end

function M.snapshot(force)
    local now=os.time(); if not force and cache.snapshot then return cache.snapshot; end
    local out={at=now,counts={AVAILABLE=0,FUTURE=0,HORIZON_CUSTOM=0,UNVERIFIED=0,DISABLED=0},future={},unverified={}};
    local q=HC and HC.modules and HC.modules.quests or nil;
    if q and q.catalog_entries then
        local ok,rows=pcall(q.catalog_entries); if ok then
            for _,e in ipairs(rows or {}) do
                local a=M.quest(e.log_id,e.quest_id,e.detail); out.counts[a.state]=(out.counts[a.state] or 0)+1;
                if a.state=='FUTURE' then out.future[#out.future+1]={kind='quest',name=e.name,key=tostring(e.log_id)..':'..tostring(e.quest_id),reason=a.reason};
                elseif a.state=='UNVERIFIED' then out.unverified[#out.unverified+1]={kind='quest',name=e.name,key=tostring(e.log_id)..':'..tostring(e.quest_id),reason=a.reason}; end
            end
        end
    end
    for n=1,48 do
        local a=M.mission('toau',n); out.counts[a.state]=(out.counts[a.state] or 0)+1;
        if a.state=='FUTURE' then out.future[#out.future+1]={kind='mission',name='ToAU Mission '..tostring(n),key='toau:'..tostring(n),reason=a.reason}; end
    end
    cache={at=now,snapshot=out}; return out;
end

function M.draw()
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local s=M.snapshot(false);
    imgui.Text('HorizonXI Availability / Era Validation');
    imgui.TextDisabled('Actionable content is separated from future/disabled era content before it reaches the planner.');
    imgui.Text(string.format('Available %d | Horizon Custom %d | Future %d | Unverified %d',
        tonumber(s.counts.AVAILABLE) or 0,tonumber(s.counts.HORIZON_CUSTOM) or 0,tonumber(s.counts.FUTURE) or 0,tonumber(s.counts.UNVERIFIED) or 0));
    imgui.TextDisabled('ToAU: missions 1-18 current; 19-48 remain visible as FUTURE reference content.');
    imgui.TextDisabled('Crystal War / Wings of the Goddess: FUTURE / not actionable in the current HorizonXI profile.');
    if imgui.Button('Rebuild Availability Snapshot##hc_availability_refresh') then M.snapshot(true); end
end

function M.status() local s=M.snapshot(false); return {counts=s.counts,at=s.at,future=#(s.future or {}),unverified=#(s.unverified or {})}; end
function M.command(w)
    local sub=lower(w[2]); if sub~='availability' and sub~='era' then return false; end
    local s=M.snapshot(true); HC.msg(string.format('Availability: %d available | %d future | %d unverified',s.counts.AVAILABLE or 0,s.counts.FUTURE or 0,s.counts.UNVERIFIED or 0)); return true;
end
function M.init(ctx) HC=ctx; load_rules(); end
return M;
