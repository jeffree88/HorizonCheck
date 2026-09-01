local M={};
local HC;
local cache_by_char={};
local CACHE_SECONDS=15;

local ADVANCED_JOBS={BST=true,BRD=true,RNG=true,SAM=true,NIN=true,DRG=true,SMN=true,BLU=true,COR=true,PUP=true};
local LIMIT_BREAKS={
    {key='limit_break_1',name='Limit Break 1',level=51},
    {key='limit_break_2',name='Limit Break 2',level=56},
    {key='limit_break_3',name='Limit Break 3',level=61},
    {key='limit_break_4',name='Limit Break 4',level=66},
    {key='limit_break_5',name='Limit Break 5',level=71},
};

local function char_name()
    return tostring(HC.modules.core and HC.modules.core.character_name and HC.modules.core.character_name() or 'Unknown');
end

local function ensure(c)
    c.historical_import=type(c.historical_import)=='table' and c.historical_import or {};
    local h=c.historical_import;
    h.quests=type(h.quests)=='table' and h.quests or {};
    h.missions=type(h.missions)=='table' and h.missions or {};
    h.unlocks=type(h.unlocks)=='table' and h.unlocks or {};
    h.jobs=type(h.jobs)=='table' and h.jobs or {};
    h.limit_breaks=type(h.limit_breaks)=='table' and h.limit_breaks or {};
    return h;
end

local function set_proof(tbl,key,row)
    local prev=tbl[key];
    if type(prev)=='table' and prev.proven==true then return false; end
    tbl[key]=row; return true;
end

local function observe_complete(c,key,source,detail,evidence)
    local p=HC.modules.progression;
    if p and p.observe then
        pcall(p.observe,c,key,'COMPLETE',{source=source,source_type='saved_permanent',rank=104,detail=detail,evidence=evidence});
    end
    c.progression=type(c.progression)=='table' and c.progression or {last_states={}};
    c.progression.last_states=type(c.progression.last_states)=='table' and c.progression.last_states or {};
    c.progression.last_states[key]='COMPLETE';
end

function M.reconcile(c,force,reason)
    c=c or HC.modules.state.get_char(); local h=ensure(c); local now=os.time(); local ck=char_name();
    local cached=cache_by_char[ck];
    if force~=true and cached and now-(tonumber(cached.at) or 0)<CACHE_SECONDS then
        if HC.modules.profiler and HC.modules.profiler.cache then HC.modules.profiler.cache('historyimport.reconcile',true); end
        return cached;
    end
    if HC.modules.profiler and HC.modules.profiler.cache then HC.modules.profiler.cache('historyimport.reconcile',false); end
    if HC.modules.profiler and HC.modules.profiler.bump then HC.modules.profiler.bump('historyimport.scan'); end
    local changed=0; local counts={quests=0,missions=0,unlocks=0,jobs=0,limit_breaks=0};
    local coverage={quest_native_observed=0,quest_allowed=0,quest_quarantined=0,quest_blocked=0,quest_other=0,missions_observed=0,unlocks_observed=0,jobs_observed=0,limit_breaks_observed=0};
    local skipped={};

    -- Native completed quest history is safe only when the HorizonXI canonical
    -- registry explicitly ALLOWs the mapping. Repeatable current-cycle state is
    -- intentionally not inferred from this permanent historical proof.
    local q=HC.modules.quests; local canonical=HC.modules.canonical;
    if q and q.sync_native_cache then pcall(q.sync_native_cache,false); end
    if q and q.completed_ids and q.detail and canonical and canonical.native_policy then
        for log_id=0,6 do
            local ok,ids=pcall(q.completed_ids,log_id);
            if ok and type(ids)=='table' then
                for _,quest_id in ipairs(ids) do
                    coverage.quest_native_observed=coverage.quest_native_observed+1;
                    local detail=q.detail(log_id,quest_id) or {};
                    local policy=canonical.native_policy(log_id,quest_id,detail);
                    if policy=='ALLOW' then
                        coverage.quest_allowed=coverage.quest_allowed+1;
                        local key=tostring(log_id)..':'..tostring(quest_id);
                        local name=(q.quest_name and q.quest_name(log_id,quest_id)) or detail.name or key;
                        local newly=set_proof(h.quests,key,{proven=true,name=name,log_id=log_id,quest_id=quest_id,source='Native completed quest history',verified_at=now});
                        if newly then changed=changed+1; end
                        counts.quests=counts.quests+1;
                        local pg=HC.modules.progression and HC.modules.progression.get and HC.modules.progression.get('quest:'..key,c) or nil;
                        if newly or not pg or pg.state~='COMPLETE' then
                            observe_complete(c,'quest:'..key,'historical import: native quest history',name,'0x056 completed history');
                        end
                    else
                        if policy=='QUARANTINE' then coverage.quest_quarantined=coverage.quest_quarantined+1;
                        elseif policy=='BLOCK' then coverage.quest_blocked=coverage.quest_blocked+1;
                        else coverage.quest_other=coverage.quest_other+1; end
                        if #skipped<12 then
                            local name=(q.quest_name and q.quest_name(log_id,quest_id)) or detail.name or (tostring(log_id)..':'..tostring(quest_id));
                            skipped[#skipped+1]={key=tostring(log_id)..':'..tostring(quest_id),name=name,policy=tostring(policy or 'UNKNOWN')};
                        end
                    end
                end
            end
        end
    end

    local missions=HC.modules.missions;
    if missions and missions.catalog_entries then
        local ok,entries=pcall(missions.catalog_entries,c);
        if ok then for _,e in ipairs(entries or {}) do if e.completed==true then
            coverage.missions_observed=coverage.missions_observed+1;
            local key=tostring(e.series_id)..':'..tostring(e.key);
            local newly=set_proof(h.missions,key,{proven=true,name=e.name,series_id=e.series_id,number=e.number,source='Native/saved mission history',verified_at=now}); if newly then changed=changed+1; end
            counts.missions=counts.missions+1;
            local pg=HC.modules.progression and HC.modules.progression.get and HC.modules.progression.get('mission:'..key,c) or nil;
            if newly or not pg or pg.state~='COMPLETE' then observe_complete(c,'mission:'..key,'historical import: mission history',e.name,'native/saved mission completion'); end
        end end end
    end

    local unlocks=HC.modules.unlocks;
    if unlocks and unlocks.snapshot then
        local ok,s=pcall(unlocks.snapshot,c,false);
        if ok and type(s)=='table' then for _,r in ipairs(s.rows or {}) do if r.owned==true then
            coverage.unlocks_observed=coverage.unlocks_observed+1;
            if set_proof(h.unlocks,tostring(r.key),{proven=true,name=r.name,id=r.id,category=r.category,source=r.source,verified_at=now}) then changed=changed+1; end
            counts.unlocks=counts.unlocks+1;
        end end end
    end

    local max_level=0; local jobs_75=0; local jobs_total=0; local skills=HC.modules.skills;
    if skills and skills.job_levels then
        local ok,rows=pcall(skills.job_levels,false);
        if ok then for _,r in ipairs(rows or {}) do
            local lv=tonumber(r.level) or 0; if lv>max_level then max_level=lv; end
            jobs_total=jobs_total+1; if lv>=75 then jobs_75=jobs_75+1; end
            local abbr=tostring(r.abbr or '');
            if lv>0 and ADVANCED_JOBS[abbr] then
                coverage.jobs_observed=coverage.jobs_observed+1;
                local newly=set_proof(h.jobs,abbr,{proven=true,name=tostring(r.name or abbr),level=lv,source='Job level history',verified_at=now}); if newly then changed=changed+1; end
                counts.jobs=counts.jobs+1;
                local pg=HC.modules.progression and HC.modules.progression.get and HC.modules.progression.get('job_unlock:'..abbr,c) or nil;
                if newly or not pg or pg.state~='COMPLETE' then observe_complete(c,'job_unlock:'..abbr,'historical import: job level',abbr..' unlocked','job level '..tostring(lv)); end
            end
        end end
        c.overview_profile=type(c.overview_profile)=='table' and c.overview_profile or {};
        c.overview_profile.jobs_75=jobs_75; c.overview_profile.jobs_total=jobs_total; c.overview_profile.last_seen_at=now;
        if skills.overview_summary then
            local ok2,ov=pcall(skills.overview_summary); if ok2 and type(ov)=='table' then
                c.overview_profile.job=tostring(ov.job or '---'); c.overview_profile.level=tonumber(ov.level) or 0;
            end
        end
    end
    for _,lb in ipairs(LIMIT_BREAKS) do
        if max_level>=lb.level then
            coverage.limit_breaks_observed=coverage.limit_breaks_observed+1;
            local newly=set_proof(h.limit_breaks,lb.key,{proven=true,name=lb.name,source='Job level threshold',level=max_level,verified_at=now}); if newly then changed=changed+1; end
            counts.limit_breaks=counts.limit_breaks+1;
            local pg=HC.modules.progression and HC.modules.progression.get and HC.modules.progression.get('unlock:'..lb.key,c) or nil;
            if newly or not pg or pg.state~='COMPLETE' then observe_complete(c,'unlock:'..lb.key,'historical import: level threshold',lb.name,'observed job level '..tostring(max_level)); end
        end
    end

    local assault={};
    if HC.modules.assaultprogress and HC.modules.assaultprogress.native_status then
        local ok,a=pcall(HC.modules.assaultprogress.native_status,c); if ok and type(a)=='table' then assault=a; end
    end
    h.last_at=now; h.last_reason=tostring(reason or 'historical reconciliation'); h.counts=counts; h.coverage=coverage; h.skipped=skipped; h.assault=assault; h.last_added=changed;
    local snap={at=now,counts=counts,coverage=coverage,skipped=skipped,assault=assault,added=changed,reason=h.last_reason}; cache_by_char[ck]=snap;
    if (changed>0 or jobs_total>0) and HC.modules.state and HC.modules.state.request_save then HC.modules.state.request_save(1); end
    if changed>0 and HC.modules.dependencies and HC.modules.dependencies.invalidate then HC.modules.dependencies.invalidate('history','historical progression import changed'); end
    return snap;
end

function M.status(c)
    c=c or HC.modules.state.get_char(); local h=ensure(c);
    return {at=h.last_at,counts=h.counts or {},coverage=h.coverage or {},skipped=h.skipped or {},assault=h.assault or {},added=tonumber(h.last_added) or 0,reason=h.last_reason};
end

function M.invalidate() cache_by_char={}; end

function M.draw(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local s=M.status(c); local n=s.counts or {};
    if HC.modules.uikit then HC.modules.uikit.section_header('Historical Progression Import'); else imgui.Text('Historical Progression Import'); imgui.Separator(); end
    imgui.TextDisabled('One-way permanent backfill from native completion history, permanent unlocks, job levels and limit-break thresholds. Repeatable current-cycle completion is never inferred.');
    imgui.Text(string.format('Quests %d | Missions %d | Unlocks %d | Advanced jobs %d | Limit breaks %d',n.quests or 0,n.missions or 0,n.unlocks or 0,n.jobs or 0,n.limit_breaks or 0));
    local cv=s.coverage or {}; local a=s.assault or {};
    imgui.Separator();
    imgui.Text('Import Coverage');
    local table_ok=imgui.BeginTable~=nil and imgui.TableSetupColumn~=nil and imgui.TableHeadersRow~=nil and imgui.TableNextRow~=nil and imgui.TableSetColumnIndex~=nil and imgui.EndTable~=nil;
    local rows={
        {'Native quests',cv.quest_allowed or 0,cv.quest_native_observed or 0,(cv.quest_quarantined or 0)+(cv.quest_blocked or 0)+(cv.quest_other or 0)},
        {'Missions',n.missions or 0,cv.missions_observed or n.missions or 0,0},
        {'Permanent unlocks',n.unlocks or 0,cv.unlocks_observed or n.unlocks or 0,0},
        {'Advanced jobs',n.jobs or 0,cv.jobs_observed or n.jobs or 0,0},
        {'Limit breaks',n.limit_breaks or 0,cv.limit_breaks_observed or n.limit_breaks or 0,0},
        {'Assaults',tonumber(a.tracked_completed) or 0,tonumber(a.native_completed) or 0,0},
    };
    if table_ok and imgui.BeginTable('##hc_history_coverage_v6980',4,64+128+512) then
        imgui.TableSetupColumn('Source',0,170); imgui.TableSetupColumn('Imported / Proven',0,120); imgui.TableSetupColumn('Observed',0,90); imgui.TableSetupColumn('Skipped / Unsafe',0,110); imgui.TableHeadersRow();
        for _,r in ipairs(rows) do imgui.TableNextRow(); for i,v in ipairs(r) do imgui.TableSetColumnIndex(i-1); if i==1 then imgui.Text(tostring(v)) else imgui.TextDisabled(tostring(v or 0)); end end end
        imgui.EndTable();
    else
        for _,r in ipairs(rows) do imgui.TextDisabled(string.format('%s: %s proven / %s observed / %s skipped',r[1],r[2],r[3],r[4])); end
    end
    if #(s.skipped or {})>0 then
        imgui.TextDisabled('Unsafe native quest history is intentionally not imported.');
        if imgui.CollapsingHeader('Skipped Native Quest Mappings##hc_history_skipped') then
            for _,r in ipairs(s.skipped or {}) do imgui.TextDisabled(tostring(r.name)..' ['..tostring(r.key)..'] - '..tostring(r.policy)); end
        end
    end
    if s.at then imgui.TextDisabled('Last reconcile: '..os.date('%Y-%m-%d %H:%M:%S',s.at)..' | Added '..tostring(s.added or 0)..' proof(s)'); end
    if imgui.Button('Reconcile Historical Progress##hc_history_reconcile') then M.reconcile(c,true,'diagnostics manual import'); end
end

function M.command(w)
    local sub=string.lower(w[2] or ''); if sub~='historyimport' and sub~='history' then return false; end
    local s=M.reconcile(HC.modules.state.get_char(),true,'command'); HC.msg(string.format('Historical import: %d new proof(s).',s.added or 0)); return true;
end

function M.init(ctx) HC=ctx; end
return M;
