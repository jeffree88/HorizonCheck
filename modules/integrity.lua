local M={};
local HC;

local BATCH_SECONDS=2;
local FALLBACK_SECONDS=600;
local dirty=true;
local dirty_due=0;
local dirty_sources={initial=true};
local scanning=false;
local last={at=nil,state='PENDING',issues={},repairs=0,unresolved=0,reason='not run',sources={}};

local HEAVY_SOURCES={
    initial=true,manual=true,fallback=true,keyitems=true,unlocks=true,history=true,
    quests=true,missions=true,weekly=true,progression=true,zone=true,
};

local function lower(v) return string.lower(tostring(v or '')); end
local function clamp(v,lo,hi)
    v=math.floor(tonumber(v) or 0);
    if v<lo then return lo; end
    if v>hi then return hi; end
    return v;
end

local function ensure(c)
    c.state_integrity=type(c.state_integrity)=='table' and c.state_integrity or {};
    c.state_integrity.repair_signatures=type(c.state_integrity.repair_signatures)=='table' and c.state_integrity.repair_signatures or {};
    return c.state_integrity;
end

local function add_issue(rows,kind,key,title,detail,authority,repairable)
    local r={kind=kind,key=key,title=title,detail=tostring(detail or ''),authority=tostring(authority or ''),repairable=repairable==true,resolved=false};
    rows[#rows+1]=r;
    return r;
end

local function mark_once(c,signature)
    local s=ensure(c);
    local prev=tonumber(s.repair_signatures[signature]) or 0;
    s.repair_signatures[signature]=os.time();
    return prev==0;
end

local function timeline_repair(c,title,detail,source,evidence)
    local t=HC and HC.modules and HC.modules.timeline or nil;
    if t and t.record then
        t.record(c,'repair',title,detail,{source=source or 'state integrity engine',evidence=evidence,repair=true,dedupe_seconds=2});
    end
end

local function source_snapshot()
    local out={};
    for k,v in pairs(dirty_sources) do if v then out[#out+1]=tostring(k); end end
    table.sort(out);
    return out;
end

local function should_run_heavy(sources,reason)
    if lower(reason):find('manual',1,true) or lower(reason):find('fallback',1,true) then return true; end
    for _,s in ipairs(sources or {}) do if HEAVY_SOURCES[s]==true then return true; end end
    return false;
end

local function scan_assault_tags(c,rows,repair)
    local st=HC.modules.state; if not st or not st.raw then return 0; end
    local raw=st.raw();
    raw.account=type(raw.account)=='table' and raw.account or {};
    local shared=type(raw.account.assault_tags)=='table' and raw.account.assault_tags or nil;
    local repaired=0;

    if shared then
        if shared.cap~=nil and tonumber(shared.cap)~=4 then
            local issue=add_issue(rows,'ASSAULT_TAG_CAP','assault:cap','Assault Tag Capacity',
                'Saved account tag capacity is '..tostring(shared.cap)..'; HorizonXI Assault Tag total capacity is 4.','Assault Tag state engine',true);
            if repair then
                shared.cap=4; issue.resolved=true; issue.repair='Capacity normalized to 4.'; repaired=repaired+1;
                if mark_once(c,'assault:cap') then timeline_repair(c,'Assault Tag Capacity Repaired','Saved capacity normalized to 4','state integrity engine'); end
            end
        end
        if shared.count~=nil then
            local n=clamp(shared.count,0,4);
            if tonumber(shared.count)~=n then
                local issue=add_issue(rows,'ASSAULT_TAG_TOTAL','assault:count','Assault Tag Total',
                    'Saved total '..tostring(shared.count)..' is outside the valid 0-4 range.','Assault Tag state engine',true);
                if repair then
                    shared.count=n; issue.resolved=true; issue.repair='Total clamped to '..tostring(n)..'.'; repaired=repaired+1;
                    timeline_repair(c,'Assault Tag Total Repaired','Out-of-range total -> '..tostring(n),'state integrity engine');
                end
            end
            if n>=4 and shared.next_at~=nil then
                local issue=add_issue(rows,'ASSAULT_TAG_TIMER','assault:timer','Assault Tag Regeneration Timer',
                    'A regeneration timer remained active while the saved total was already capped at 4.','Assault Tag state engine',true);
                if repair then
                    shared.next_at=nil; shared.timer_estimated=nil; issue.resolved=true; issue.repair='Impossible capped timer cleared.'; repaired=repaired+1;
                    timeline_repair(c,'Assault Tag Timer Repaired','Cleared regeneration timer at 4/4 tags','state integrity engine');
                end
            end
        end
        if shared.last_rytaal_menu_left~=nil then
            local n=clamp(shared.last_rytaal_menu_left,0,3);
            if tonumber(shared.last_rytaal_menu_left)~=n then
                local issue=add_issue(rows,'RYTAAL_STORED_BOUNDS','assault:rytaal','Rytaal Stored Tag Count',
                    'Saved authoritative Rytaal count '..tostring(shared.last_rytaal_menu_left)..' is outside the valid 0-3 range.','Rytaal synchronization state',true);
                if repair then
                    shared.last_rytaal_menu_left=n; issue.resolved=true; issue.repair='Stored count clamped to '..tostring(n)..'.'; repaired=repaired+1;
                    timeline_repair(c,'Rytaal Stored Count Repaired','Out-of-range stored count -> '..tostring(n),'state integrity engine');
                end
            end
        end
    end

    c.assault_tags=type(c.assault_tags)=='table' and c.assault_tags or {};
    if c.assault_tags.carried~=nil then
        local n=(tonumber(c.assault_tags.carried) or 0)>0 and 1 or 0;
        if tonumber(c.assault_tags.carried)~=n then
            local issue=add_issue(rows,'ASSAULT_CARRIED_BOUNDS','assault:carried','Character Assault Tag Ownership',
                'Saved carried-tag value '..tostring(c.assault_tags.carried)..' is not a valid 0/1 ownership value.','character Assault Tag evidence',true);
            if repair then
                c.assault_tags.carried=n; issue.resolved=true; issue.repair='Carried ownership normalized to '..tostring(n)..'.'; repaired=repaired+1;
                timeline_repair(c,'Character Assault Tag State Repaired','Carried ownership normalized to '..tostring(n),'state integrity engine');
            end
        end
    end
    return repaired;
end

local function scan_dynamis_pool(c,rows,repair)
    local st=HC.modules.state; local core=HC.modules.core;
    if not st or not st.raw or not st.get_account_weekly or not core or not core.weekly_key then return 0; end
    local raw=st.raw(); local chars=type(raw.chars)=='table' and raw.chars or {};
    local week=core.weekly_key(); local sum=0; local repaired=0;

    for name,cc in pairs(chars) do
        if type(cc)=='table' and cc.weekly_key==week and type(cc.weekly)=='table' and cc.weekly.dynamis_character_count~=nil then
            local old=tonumber(cc.weekly.dynamis_character_count) or 0;
            local n=clamp(old,0,2);
            sum=sum+n;
            if old~=n then
                local issue=add_issue(rows,'DYNAMIS_CHARACTER_BOUNDS','dynamis:'..tostring(name),tostring(name)..' Dynamis Usage',
                    'Saved character usage '..tostring(old)..' is outside the valid 0-2 weekly range.','character weekly state',true);
                if repair then
                    cc.weekly.dynamis_character_count=n; issue.resolved=true; issue.repair='Character usage clamped to '..tostring(n)..'.'; repaired=repaired+1;
                    timeline_repair(c,'Dynamis Character Usage Repaired',tostring(name)..' -> '..tostring(n)..'/2','state integrity engine');
                end
            end
        end
    end

    local aw=st.get_account_weekly();
    local actual=clamp(aw.dynamis_count,0,3);
    local reconstructable=math.min(3,sum);
    if reconstructable>actual then
        local issue=add_issue(rows,'DYNAMIS_ACCOUNT_UNDERCOUNT','dynamis:account','Dynamis Account Pool',
            string.format('Account pool says %d/3 used, but current-week character counters prove at least %d/3.',actual,reconstructable),'current-week character usage',true);
        if repair then
            aw.dynamis_count=reconstructable; issue.resolved=true; issue.repair='Account usage promoted to proven minimum '..tostring(reconstructable)..'/3.'; repaired=repaired+1;
            timeline_repair(c,'Dynamis Account Pool Repaired',string.format('%d/3 -> %d/3 from character usage',actual,reconstructable),'state integrity engine');
        end
    elseif actual>reconstructable then
        -- Never downgrade stronger account-wide usage when the exact character
        -- attribution is missing. Preserve it and surface the discrepancy.
        add_issue(rows,'DYNAMIS_ACCOUNT_ATTRIBUTION','dynamis:account_attribution','Dynamis Account Attribution',
            string.format('Account pool records %d/3 used while saved current-week character counters explain %d/3. Account usage was preserved because attribution is incomplete.',actual,reconstructable),'account weekly state',false);
    end

    -- The old dynamis_1/2/3 booleans are display/compatibility mirrors only.
    -- They may be safely repaired to the stronger account-wide count.
    local effective=math.max(actual,reconstructable);
    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    local desired={effective>=1 and true or nil,effective>=2 and true or nil,effective>=3 and true or nil};
    local changed=false;
    for i=1,3 do
        local k='dynamis_'..tostring(i);
        if c.weekly[k]~=desired[i] then changed=true; if repair then c.weekly[k]=desired[i]; end end
    end
    if changed then
        local issue=add_issue(rows,'DYNAMIS_LEGACY_MIRROR','dynamis:mirror','Dynamis Compatibility Mirror',
            'Character compatibility flags disagreed with the current account-wide Dynamis usage.','account weekly state',true);
        if repair then issue.resolved=true; issue.repair='Compatibility mirror synchronized.'; repaired=repaired+1; end
    end
    return repaired;
end

local function scan_limbus_sequence(c,rows,repair)
    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    if c.weekly.limbus_2==true and c.weekly.limbus_1~=true then
        local issue=add_issue(rows,'LIMBUS_SEQUENCE','limbus:sequence','Limbus Weekly Sequence',
            'Second weekly Limbus usage is recorded while the first usage is missing.','character weekly state',true);
        if repair then
            c.weekly.limbus_1=true; issue.resolved=true; issue.repair='First usage restored because 2/2 necessarily implies 1/2.';
            timeline_repair(c,'Limbus Weekly State Repaired','Restored missing first usage from second-use proof','state integrity engine');
            return 1;
        end
    end
    return 0;
end

local function scan_overview_profiles(c,rows,repair)
    local st=HC.modules.state; if not st or not st.raw then return 0; end
    local raw=st.raw(); local repaired=0;
    for name,cc in pairs(type(raw.chars)=='table' and raw.chars or {}) do
        local p=type(cc)=='table' and type(cc.overview_profile)=='table' and cc.overview_profile or nil;
        if p then
            local total=tonumber(p.jobs_total);
            local jobs=tonumber(p.jobs_75);
            if total and total>=0 and jobs and (jobs<0 or jobs>total) then
                local n=math.max(0,math.min(math.floor(total),math.floor(jobs)));
                local issue=add_issue(rows,'OVERVIEW_JOB_SUMMARY','overview:'..tostring(name)..':jobs',tostring(name)..' Overview Job Summary',
                    string.format('Saved Jobs-at-75 summary %s/%s is impossible.',tostring(jobs),tostring(total)),'saved character overview profile',true);
                if repair then p.jobs_75=n; issue.resolved=true; issue.repair='Saved summary normalized to '..tostring(n)..'/'..tostring(math.floor(total))..'.'; repaired=repaired+1; end
            end
            if p.level~=nil then
                local old=tonumber(p.level) or 0; local n=clamp(old,0,75);
                if old~=n then
                    local issue=add_issue(rows,'OVERVIEW_LEVEL_SUMMARY','overview:'..tostring(name)..':level',tostring(name)..' Overview Level Summary',
                        'Saved current-job level '..tostring(old)..' is outside HorizonXI level range 0-75.','saved character overview profile',true);
                    if repair then p.level=n; issue.resolved=true; issue.repair='Saved level normalized to '..tostring(n)..'.'; repaired=repaired+1; end
                end
            end
            if p.overview_pct~=nil then
                local old=tonumber(p.overview_pct) or 0; local n=clamp(old,0,100);
                if old~=n then
                    local issue=add_issue(rows,'OVERVIEW_PERCENT_SUMMARY','overview:'..tostring(name)..':percent',tostring(name)..' Overview Percentage',
                        'Saved Overview percentage '..tostring(old)..' is outside 0-100%.','saved character overview profile',true);
                    if repair then p.overview_pct=n; issue.resolved=true; issue.repair='Saved percentage normalized to '..tostring(n)..'%.'; repaired=repaired+1; end
                end
            end
        end
    end
    return repaired;
end

local function scan_anniversary_runtime(c,rows,repair)
    local a=type(c.anniversary)=='table' and c.anniversary or nil;
    if not a or type(a.auto)~='table' then return 0; end
    local repaired=0;
    local cur=a.auto.current_2024;
    if type(cur)=='table' then
        local gi=tonumber(cur.group); local ii=tonumber(cur.item);
        local auto=HC.modules.anniversary;
        local valid=auto and auto.valid_2024_pointer and auto.valid_2024_pointer(gi,ii) or true;
        if valid==false then
            local issue=add_issue(rows,'ANNIVERSARY_POINTER','anniversary:current_2024','Anniversary Current-Riddle Pointer',
                'Saved 2024 current-riddle pointer no longer maps to a valid catalog item.','Anniversary catalog',true);
            if repair then a.auto.current_2024=nil; issue.resolved=true; issue.repair='Invalid transient pointer removed; completion checkboxes were untouched.'; repaired=repaired+1; end
        end
    end
    local si=tonumber(a.auto.sehri_active);
    if si and (si<1 or si>30 or si~=math.floor(si)) then
        local issue=add_issue(rows,'ANNIVERSARY_SEHRI_POINTER','anniversary:sehri','Sehri Active Hunt Pointer',
            'Saved Sehri hunt index '..tostring(a.auto.sehri_active)..' is outside the 1-30 hunt catalog.','Anniversary 2025 catalog',true);
        if repair then a.auto.sehri_active=nil; issue.resolved=true; issue.repair='Invalid transient Sehri pointer removed; completed hunts were untouched.'; repaired=repaired+1; end
    end
    return repaired;
end

local function append_selfheal(c,rows,repair,reason,sources)
    if not should_run_heavy(sources,reason) then return 0; end
    local sh=HC.modules.selfheal; if not sh or not sh.scan then return 0; end
    local ok,res=pcall(sh.scan,c,repair,'state integrity provider: '..tostring(reason or 'scan'));
    if not ok or type(res)~='table' then
        add_issue(rows,'PROVIDER_ERROR','provider:selfheal','Legacy Self-Heal Provider',tostring(res),'runtime guard',false);
        return 0;
    end
    for _,r in ipairs(res.issues or {}) do
        local copy={}; for k,v in pairs(r) do copy[k]=v; end
        copy.provider='selfheal'; rows[#rows+1]=copy;
    end
    return tonumber(res.repairs) or 0;
end


local function scan_reset_keys(c,rows,repair)
    local core=HC.modules.core; local st=HC.modules.state; if not core or not st then return 0; end
    local repaired=0; local wk=core.weekly_key and core.weekly_key() or nil; local dk=core.daily_key and core.daily_key() or nil;
    local stale=(wk and c.weekly_key~=wk) or (dk and c.daily_key~=dk);
    if stale then
        local issue=add_issue(rows,'RESET_SCOPE_STALE','reset:keys','Reset Scope State',
            'Saved daily/weekly reset keys are stale relative to the current reset window.','state reset engine',true);
        if repair and st.reconcile then
            local ok=pcall(st.reconcile); local now_ok=(not wk or c.weekly_key==wk) and (not dk or c.daily_key==dk);
            if ok and now_ok then issue.resolved=true; issue.repair='State reset reconciliation applied current daily/weekly keys.'; repaired=repaired+1; end
        end
    end
    return repaired;
end

local function scan_fame_bounds(c,rows,repair)
    local repaired=0;
    local function scan_table(tbl,label,prefix)
        if type(tbl)~='table' then return; end
        for k,v in pairs(tbl) do
            local n=tonumber(v);
            if n~=nil and (n<1 or n>9 or n~=math.floor(n)) then
                local fixed=clamp(n,1,9);
                local issue=add_issue(rows,'FAME_BOUNDS',prefix..':'..tostring(k),label..' '..tostring(k),
                    'Saved derived rank '..tostring(v)..' is outside the supported 1-9 range.','derived fame/reputation profile',true);
                if repair then tbl[k]=fixed; issue.resolved=true; issue.repair='Derived rank normalized to '..tostring(fixed)..'.'; repaired=repaired+1; end
            end
        end
    end
    scan_table(c.quest_fame_overrides,'Fame profile','fame');
    scan_table(c.quest_reputation_overrides,'Reputation profile','reputation');
    for k,ev in pairs(type(c.quest_fame_dialogue_evidence)=='table' and c.quest_fame_dialogue_evidence or {}) do
        if type(ev)=='table' and ev.level~=nil then
            local n=tonumber(ev.level);
            if n==nil or n<1 or n>9 or n~=math.floor(n) then
                add_issue(rows,'FAME_EVIDENCE_BOUNDS','fame_evidence:'..tostring(k),'Fame Dialogue Evidence',
                    'Stored direct dialogue evidence has an impossible rank '..tostring(ev.level)..'. Evidence was preserved for review.','raw dialogue evidence',false);
            end
        end
    end
    return repaired;
end

local function scan_outpost_consistency(c,rows,repair)
    local op=HC.modules.outposts; if not op or not op.verified_count then return 0; end
    local have,total=op.verified_count(c); have=tonumber(have) or 0; total=tonumber(total) or 0;
    c.outposts=type(c.outposts)=='table' and c.outposts or {}; c.weekly=type(c.weekly)=='table' and c.weekly or {};
    local repaired=0;
    if total>0 and have>=total and c.outposts.permanent_complete~=true then
        local issue=add_issue(rows,'OUTPOST_PERMANENT_MIRROR','outposts:permanent','Outpost Permanent Completion',
            string.format('%d/%d outposts are verified but the permanent completion mirror is missing.',have,total),'verified outpost ownership',true);
        if repair then c.outposts.permanent_complete=true; c.weekly.conquest=true; issue.resolved=true; issue.repair='Permanent completion mirror restored.'; repaired=repaired+1; end
    elseif c.outposts.permanent_complete==true and c.weekly.conquest~=true then
        local issue=add_issue(rows,'OUTPOST_WEEKLY_MIRROR','outposts:weekly','Outpost Compatibility Mirror',
            'Permanent outpost completion is proven but the compatibility weekly mirror is missing.','permanent outpost proof',true);
        if repair then c.weekly.conquest=true; issue.resolved=true; issue.repair='Compatibility mirror restored.'; repaired=repaired+1; end
    end
    return repaired;
end

local function scan_anniversary_progress_bounds(c,rows,repair)
    local a=type(c.anniversary)=='table' and c.anniversary or nil; if not a or type(a.auto)~='table' then return 0; end
    local repaired=0; local auto=a.auto; local prog=type(auto.npc_progress)=='table' and auto.npc_progress or {};
    for key,st in pairs(prog) do
        if type(st)=='table' then
            local b=tonumber(st.backfilled);
            if b and (b<0 or b>4 or b~=math.floor(b)) then
                local fixed=clamp(b,0,4); local issue=add_issue(rows,'ANNIVERSARY_BACKFILL_COUNT','anniversary:lane:'..tostring(key),'Anniversary Lane Backfill Count',
                    'Derived lane backfill counter '..tostring(b)..' is outside 0-4.','Anniversary derived automation metrics',true);
                if repair then st.backfilled=fixed; issue.resolved=true; issue.repair='Derived lane counter normalized to '..tostring(fixed)..'.'; repaired=repaired+1; end
            end
            local adv=tonumber(st.advancements);
            if adv and adv<0 then
                local issue=add_issue(rows,'ANNIVERSARY_ADVANCEMENT_COUNT','anniversary:adv:'..tostring(key),'Anniversary Lane Advancement Count',
                    'Derived advancement counter is negative.','Anniversary derived automation metrics',true);
                if repair then st.advancements=0; issue.resolved=true; issue.repair='Derived advancement count normalized to 0.'; repaired=repaired+1; end
            end
        end
    end
    return repaired;
end

local function scan_seasonal_metadata(c,rows,repair)
    local sea=HC.modules.seasonal; if not sea or not sea.events then return 0; end
    local valid={}; for _,event in ipairs(sea.events() or {}) do for _,reward in ipairs(event.rewards or {}) do valid[tostring(event.id)..':'..tostring(reward.id)]=true; end end
    local s=type(c.seasonal)=='table' and c.seasonal or nil; if not s then return 0; end
    local repaired=0;
    for k in pairs(type(s.meta)=='table' and s.meta or {}) do
        if type(s.obtained)~='table' or s.obtained[k]~=true then
            local issue=add_issue(rows,'SEASONAL_ORPHAN_META','seasonal:meta:'..tostring(k),'Seasonal Metadata',
                'Saved reward metadata exists without corresponding obtained proof.','derived Seasonal metadata',true);
            if repair then s.meta[k]=nil; issue.resolved=true; issue.repair='Orphan metadata removed; ownership proof was not changed.'; repaired=repaired+1; end
        end
    end
    for k,v in pairs(type(s.obtained)=='table' and s.obtained or {}) do
        if v==true and not valid[k] then
            add_issue(rows,'SEASONAL_UNKNOWN_KEY','seasonal:unknown:'..tostring(k),'Seasonal Historical Key',
                'Saved obtained key is no longer present in the current Seasonal catalog. It was preserved as historical evidence.','saved collection history',false);
        end
    end
    return repaired;
end

local function scan_mission_chain_audit(c,rows)
    local m=HC.modules.missions; if not m or not m.catalog_entries then return 0; end
    local by={};
    for _,rec in ipairs(m.catalog_entries(c) or {}) do by[rec.series_id]=by[rec.series_id] or {}; by[rec.series_id][#by[rec.series_id]+1]=rec; end
    for sid,list in pairs(by) do
        local latest=0; for i,r in ipairs(list) do if r.completed==true then latest=i; end end
        if latest>1 then
            for i=1,latest-1 do if list[i].completed~=true then
                add_issue(rows,'MISSION_CHAIN_GAP','mission:'..tostring(sid)..':'..tostring(i),'Mission Chain Gap',
                    tostring(list[latest].name)..' is completed while earlier '..tostring(list[i].name)..' is not recorded complete. No completion evidence was invented.','mission completion history',false);
                break;
            end end
        end
    end
    return 0;
end

local function scan_quest_chain_audit(c,rows)
    local q=HC.modules.quests; local g=HC.modules.questgraph; if not q or not g or not q.completed_ids or not g.direct_dependencies then return 0; end
    local reported=0;
    for log_id=0,10 do
        for _,qid in ipairs(q.completed_ids(log_id) or {}) do
            for _,dep in ipairs(g.direct_dependencies(log_id,qid) or {}) do
                if dep.kind=='complete' and dep.missing~=true then
                    local done=q.is_completed and q.is_completed(dep.log_id,dep.quest_id) or nil;
                    if done==false then
                        add_issue(rows,'QUEST_CHAIN_GAP','quest:'..tostring(log_id)..':'..tostring(qid),'Quest Chain Gap',
                            string.format('Completed quest %s [%d:%d] requires %s [%d:%d], but that prerequisite is not in completed native history. Raw history was preserved.',
                                tostring((q.name and q.name(log_id,qid)) or (log_id..':'..qid)),log_id,qid,tostring(dep.name),tonumber(dep.log_id) or -1,tonumber(dep.quest_id) or -1),'native completed quest history',false);
                        reported=reported+1; if reported>=20 then return 0; end
                    end
                end
            end
        end
    end
    return 0;
end

local function scan_seasonal_only(c,rows,repair,sources)
    local needed=false;
    for _,s in ipairs(sources or {}) do if s=='inventory' or s=='seasonal' then needed=true; break; end end
    if not needed or should_run_heavy(sources,'') then return 0; end
    if not repair then return 0; end
    local sea=HC.modules.seasonal; if not sea or not sea.reconcile then return 0; end
    local ok,res=pcall(sea.reconcile,c,false);
    if ok and type(res)=='table' and (tonumber(res.changed) or 0)>0 then
        local issue=add_issue(rows,'SEASONAL_OWNERSHIP','seasonal:ownership','Seasonal Reward Ownership',
            tostring(res.changed)..' permanent reward ownership proof(s) were discovered in current storage.','shared inventory/wardrobe collection scan',true);
        issue.resolved=true; issue.repair='Seasonal ownership cache synchronized.';
        timeline_repair(c,'Seasonal Ownership Reconciled',tostring(res.changed)..' newly detected reward(s)','state integrity engine');
        return 1;
    end
    return 0;
end

local function invalidate_after_repairs()
    local deps=HC.modules.dependencies;
    if deps and deps.invalidate_many then
        pcall(deps.invalidate_many,{'weekly','assault','seasonal','progression'},'state integrity repair');
    else
        if HC.modules.smartdashboard and HC.modules.smartdashboard.invalidate then pcall(HC.modules.smartdashboard.invalidate); end
        if HC.modules.weekly and HC.modules.weekly.invalidate_progress then pcall(HC.modules.weekly.invalidate_progress); end
    end
end

function M.scan(c,repair,reason,source_override)
    if scanning then return last; end
    scanning=true;
    c=c or HC.modules.state.get_char(); ensure(c);
    local sources=type(source_override)=='table' and source_override or source_snapshot();
    if #sources==0 then sources={'manual'}; end
    local rows={}; local repairs=0;

    repairs=repairs+scan_assault_tags(c,rows,repair==true);
    repairs=repairs+scan_dynamis_pool(c,rows,repair==true);
    repairs=repairs+scan_limbus_sequence(c,rows,repair==true);
    repairs=repairs+scan_reset_keys(c,rows,repair==true);
    repairs=repairs+scan_fame_bounds(c,rows,repair==true);
    repairs=repairs+scan_overview_profiles(c,rows,repair==true);
    repairs=repairs+scan_outpost_consistency(c,rows,repair==true);
    repairs=repairs+scan_anniversary_runtime(c,rows,repair==true);
    repairs=repairs+scan_anniversary_progress_bounds(c,rows,repair==true);
    repairs=repairs+scan_seasonal_metadata(c,rows,repair==true);
    repairs=repairs+scan_seasonal_only(c,rows,repair==true,sources);
    if should_run_heavy(sources,reason) then scan_mission_chain_audit(c,rows); scan_quest_chain_audit(c,rows); end
    repairs=repairs+append_selfheal(c,rows,repair==true,reason,sources);

    if repair and repairs>0 then
        if HC.modules.state and HC.modules.state.request_save then HC.modules.state.request_save(1); end
        invalidate_after_repairs();
    end

    local unresolved=0;
    for _,r in ipairs(rows) do if r.resolved~=true then unresolved=unresolved+1; end end
    local now=os.time();
    last={at=now,state=(unresolved>0 and 'ATTENTION' or 'HEALTHY'),issues=rows,repairs=repairs,unresolved=unresolved,
        reason=tostring(reason or (repair and 'repair scan' or 'audit scan')),sources=sources};
    local s=ensure(c);
    s.last_scan_at=now; s.last_state=last.state; s.last_repairs=repairs; s.last_unresolved=unresolved; s.last_reason=last.reason; s.last_sources=sources;
    if HC.modules.profiler and HC.modules.profiler.bump then
        HC.modules.profiler.bump('integrity.scan');
        if repairs>0 then HC.modules.profiler.bump('integrity.repairs',repairs); end
    end
    dirty=false; dirty_due=0; dirty_sources={}; scanning=false;
    return last;
end

function M.invalidate(source,reason)
    if scanning then return false; end
    source=lower(source); if source=='' then source='unknown'; end
    dirty=true; dirty_sources[source]=true;
    dirty_due=os.time()+BATCH_SECONDS;
    local s=HC and HC.modules and HC.modules.state and HC.modules.state.profile_ready and HC.modules.state.profile_ready() and HC.modules.state.get_char() or nil;
    if type(s)=='table' then
        local si=ensure(s); si.last_dirty_at=os.time(); si.last_dirty_source=source; si.last_dirty_reason=tostring(reason or 'authoritative state changed');
    end
    if HC and HC.modules and HC.modules.profiler and HC.modules.profiler.bump then HC.modules.profiler.bump('integrity.invalidate.'..source); end
    return true;
end

function M.poll()
    if not HC.modules.state or not HC.modules.state.profile_ready or not HC.modules.state.profile_ready() then return; end
    local now=os.time(); local c=HC.modules.state.get_char();
    local persisted=ensure(c); local last_at=tonumber(last.at or persisted.last_scan_at) or 0;
    if dirty and now>=dirty_due then
        return M.scan(c,true,'event-driven integrity reconciliation');
    end
    if not dirty and last_at>0 and now-last_at>=FALLBACK_SECONDS then
        dirty_sources={fallback=true}; dirty=true; dirty_due=now;
        return M.scan(c,true,'fallback integrity safety audit');
    end
end

function M.status(c)
    c=c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    local s=ensure(c);
    local at=last.at or s.last_scan_at;
    local state=last.at and last.state or (s.last_state or (dirty and 'PENDING' or 'UNKNOWN'));
    return {
        at=at,state=state,dirty=dirty,repairs=last.at and last.repairs or (tonumber(s.last_repairs) or 0),
        unresolved=last.at and last.unresolved or (tonumber(s.last_unresolved) or 0),
        issues=last.at and #(last.issues or {}) or 0,reason=last.at and last.reason or s.last_reason,
        sources=last.at and last.sources or s.last_sources or {},due_at=dirty_due,
    };
end

function M.draw(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    c=c or HC.modules.state.get_char(); local s=M.status(c);
    imgui.Text('State Integrity: '..tostring(s.state or 'PENDING'));
    imgui.TextDisabled('Checks derived state for contradictions and repairs only safe/reconstructable values. Raw packet/native evidence is never deleted or downgraded.');
    if imgui.Button('Scan & Repair Now##hc_integrity_repair') then M.scan(c,true,'diagnostics manual repair',{'manual'}); s=M.status(c); end
    imgui.SameLine();
    if imgui.Button('Audit Only##hc_integrity_audit') then M.scan(c,false,'diagnostics manual audit',{'manual'}); s=M.status(c); end
    imgui.Text(string.format('Last scan: %s | repairs %d | unresolved %d%s',
        s.at and os.date('%H:%M:%S',s.at) or 'pending',tonumber(s.repairs) or 0,tonumber(s.unresolved) or 0,s.dirty and ' | RESCAN QUEUED' or ''));
    if type(s.sources)=='table' and #s.sources>0 then imgui.TextDisabled('Triggered by: '..table.concat(s.sources,', ')); end
    if #(last.issues or {})==0 then
        if s.at then imgui.TextDisabled('No contradictions detected in the last integrity pass.'); end
        return;
    end
    for _,r in ipairs(last.issues or {}) do
        local suffix=r.resolved and (' [REPAIRED: '..tostring(r.repair or '')..']') or ' [PRESERVED / REVIEW]';
        if r.resolved then imgui.TextDisabled(tostring(r.title)..' - '..tostring(r.detail)..suffix); else imgui.TextWrapped(tostring(r.title)..' - '..tostring(r.detail)..suffix); end
    end
end

function M.command(w)
    local sub=lower(w[2]); if sub~='integrity' and sub~='stateintegrity' then return false; end
    local audit=lower(w[3])=='audit';
    local r=M.scan(nil,not audit,'command manual '..(audit and 'audit' or 'repair'),{'manual'});
    HC.msg(string.format('State integrity: %s | %d repair(s) | %d unresolved.',tostring(r.state),tonumber(r.repairs) or 0,tonumber(r.unresolved) or 0));
    return true;
end

function M.init(ctx)
    HC=ctx; dirty=true; dirty_due=os.time()+3; dirty_sources={initial=true};
end

return M;
