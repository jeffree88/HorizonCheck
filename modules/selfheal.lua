local M = {};
local HC;
local last_poll=0;
local last={at=nil,issues={},repairs=0,unresolved=0,reason='not run'};
local POLL_SECONDS=120;

local function lower(v) return string.lower(tostring(v or '')); end
local function ensure(c)
    c.self_heal=type(c.self_heal)=='table' and c.self_heal or {};
    c.self_heal.repair_signatures=type(c.self_heal.repair_signatures)=='table' and c.self_heal.repair_signatures or {};
    c.quest_quarantine=type(c.quest_quarantine)=='table' and c.quest_quarantine or {};
    return c.self_heal;
end

local function add_issue(rows,kind,key,title,detail,authority,repairable)
    local r={kind=kind,key=key,title=title,detail=tostring(detail or ''),authority=tostring(authority or ''),repairable=repairable==true,resolved=false};
    rows[#rows+1]=r; return r;
end

local function timeline_repair(c,title,detail,source,evidence)
    local t=HC and HC.modules and HC.modules.timeline or nil;
    if t and t.record then
        t.record(c,'repair',title,detail,{source=source or 'self-healing engine',evidence=evidence,repair=true,dedupe_seconds=2});
    end
end

local function mark_once(c,signature)
    local s=ensure(c); local prev=tonumber(s.repair_signatures[signature]) or 0;
    s.repair_signatures[signature]=os.time();
    return prev==0;
end

local function repair_native_quarantine(c,rec,raw,issue)
    local key=tostring(rec.key); local state=(rec.native_policy=='BLOCK') and 'LOCKED' or 'UNKNOWN';
    local oldq=type(c.quest_quarantine[key])=='table' and c.quest_quarantine[key] or nil;
    c.progression=type(c.progression)=='table' and c.progression or {last_states={}};
    c.progression.last_states=type(c.progression.last_states)=='table' and c.progression.last_states or {};
    local pkey='quest:'..key; local old=c.progression.last_states[pkey];
    local changed=(old~=state)
        or oldq==nil
        or oldq.policy~=rec.native_policy
        or oldq.reason~=rec.reason
        or oldq.raw_active~=raw.active
        or oldq.raw_completed~=raw.completed;

    if changed then
        c.quest_quarantine[key]={at=os.time(),name=rec.name,policy=rec.native_policy,reason=rec.reason,raw_active=raw.active,raw_completed=raw.completed,source=rec.source};
        c.progression.last_states[pkey]=state;
        local progression=HC.modules.progression;
        if progression and progression.observe then
            pcall(progression.observe,c,pkey,state,{source='canonical content registry',source_type='server_bitmap',rank=110,detail=rec.reason,evidence='native ID '..key,meta={canonical=true,policy=rec.native_policy}});
        end
        if mark_once(c,'native:'..key..':'..tostring(raw.active)..':'..tostring(raw.completed)..':'..rec.native_policy) then
            timeline_repair(c,'Quest Native State Quarantined',tostring(rec.name)..' ['..key..'] | '..tostring(old or 'unset')..' -> '..state,'canonical content registry','raw native bit retained for diagnostics');
        end
        issue.repair='Derived quest state set to '..state..'; raw packet evidence retained.';
    else
        issue.repair='Already quarantined; no state write required.';
    end
    issue.resolved=true;
    return changed;
end

local function scan_native(c,rows,repair)
    local canonical=HC.modules.canonical; local quests=HC.modules.quests;
    if not canonical or not canonical.snapshot or not quests or not quests.raw_native_state then return 0; end
    local repaired=0; local s=canonical.snapshot(false);
    if quests.sync_native_cache then pcall(quests.sync_native_cache,false); end
    for _,rec in pairs(s.records or {}) do
        if rec.native_policy~='ALLOW' then
            local ok,raw=pcall(quests.raw_native_state,rec.log_id,rec.quest_id,true);
            if ok and type(raw)=='table' and (raw.active==true or raw.completed==true) then
                local issue=add_issue(rows,'UNSAFE_NATIVE_ID',rec.key,rec.name,
                    string.format('Raw active=%s, completed=%s while policy=%s. %s',tostring(raw.active),tostring(raw.completed),tostring(rec.native_policy),tostring(rec.reason)),
                    'canonical content registry',true);
                if repair and repair_native_quarantine(c,rec,raw,issue) then repaired=repaired+1; end
            end
        end
    end
    return repaired;
end

local function scan_limbus(c,rows,repair)
    local k=HC.modules.keyitems; if not k or not k.cosmo_cleanse_status then return 0; end
    local ok,ks=pcall(k.cosmo_cleanse_status); if not ok or type(ks)~='table' or ks.owned==nil then return 0; end
    c.limbus_keyitem=type(c.limbus_keyitem)=='table' and c.limbus_keyitem or {};
    local saved=c.limbus_keyitem.cosmo_cleanse_owned;
    if saved==ks.owned then return 0; end
    local issue=add_issue(rows,'CONSUMABLE_KI_STATE','ki:cosmo_cleanse','Cosmo-Cleanse',
        'Saved held state '..tostring(saved)..' disagrees with authoritative current ownership '..tostring(ks.owned)..'.','0x055 key-item bitmap',true);
    if repair then
        c.limbus_keyitem.cosmo_cleanse_owned=ks.owned; c.limbus_keyitem.verified_at=os.time(); c.limbus_keyitem.source=ks.source; c.limbus_keyitem.resource_id=ks.id;
        if mark_once(c,'cosmo:'..tostring(saved)..':'..tostring(ks.owned)) then
            timeline_repair(c,'Cosmo-Cleanse State Repaired',tostring(saved)..' -> '..tostring(ks.owned),tostring(ks.source),'KI '..tostring(ks.id or 734));
        end
        issue.resolved=true; issue.repair='Saved consumable KI bridge updated from live ownership.'; return 1;
    end
    return 0;
end

local function scan_unlock_progression(c,rows,repair)
    local u=HC.modules.unlocks; local p=HC.modules.progression; if not u or not u.snapshot or not p or not p.get then return 0; end
    local ok,s=pcall(u.snapshot,c,false); if not ok or type(s)~='table' then return 0; end
    local repaired=0;
    for _,r in ipairs(s.rows or {}) do
        if r.owned==true then
            local key='unlock:'..tostring(r.key); local got=p.get(key,c);
            if not got or got.state~='COMPLETE' then
                local issue=add_issue(rows,'UNLOCK_PROGRESSION',key,tostring(r.name or r.key),
                    'Permanent unlock is owned but normalized progression is '..tostring(got and got.state or 'missing')..'.','permanent unlock registry',true);
                if repair then
                    p.observe(c,key,'COMPLETE',{source='self-heal: permanent unlock registry',source_type='saved_permanent',rank=105,detail=r.category,evidence='KI '..tostring(r.id or '?')});
                    c.progression=type(c.progression)=='table' and c.progression or {last_states={}}; c.progression.last_states=type(c.progression.last_states)=='table' and c.progression.last_states or {}; c.progression.last_states[key]='COMPLETE';
                    if mark_once(c,'unlock:'..tostring(r.key)) then timeline_repair(c,'Permanent Unlock Progression Repaired',tostring(r.name)..' -> COMPLETE','permanent unlock registry','KI '..tostring(r.id or '?')); end
                    issue.resolved=true; issue.repair='Normalized progression promoted to COMPLETE.'; repaired=repaired+1;
                end
            end
        end
    end
    return repaired;
end

local function scan_seasonal(c,rows,repair)
    local s=HC.modules.seasonal; if not s or not s.reconcile then return 0; end
    if not repair then return 0; end
    local ok,res=pcall(s.reconcile,c,false);
    if not ok or type(res)~='table' or (tonumber(res.changed) or 0)<=0 then return 0; end
    local issue=add_issue(rows,'SEASONAL_OWNERSHIP','seasonal:ownership','Seasonal Reward Ownership',
        tostring(res.changed)..' reward ownership proof(s) were discovered in current collection storage.','shared inventory/wardrobe collection scan',true);
    issue.resolved=true; issue.repair='Seasonal permanent ownership cache updated.';
    timeline_repair(c,'Seasonal Ownership Reconciled',tostring(res.changed)..' newly detected reward(s)','collection ownership scan');
    return 1;
end

local function scan_historical(c,rows,repair)
    local h=HC.modules.historyimport; if not h or not h.reconcile or not repair then return 0; end
    -- Historical import iterates only native completed IDs currently present; periodic self-heal only invokes it before the first successful import. Zone reconciliation
    -- is the normal event-driven refresh path thereafter.
    local hs=h.status and h.status(c) or {};
    if hs and hs.at then return 0; end
    local ok,res=pcall(h.reconcile,c,false,'self-healing initial historical import');
    if not ok or type(res)~='table' or (tonumber(res.added) or 0)<=0 then return 0; end
    local issue=add_issue(rows,'HISTORICAL_IMPORT','history:permanent','Historical Progression Import',
        tostring(res.added)..' permanent historical proof(s) were imported.','native/saved permanent evidence',true);
    issue.resolved=true; issue.repair='Historical permanent proofs imported and normalized.';
    timeline_repair(c,'Historical Progression Reconciled',tostring(res.added)..' permanent proof(s) imported','historical import engine');
    return 1;
end

local function scan_reset_keys(c,rows,repair)
    local core=HC.modules.core; if not core then return 0; end
    local dk=core.daily_key and core.daily_key() or nil; local wk=core.weekly_key and core.weekly_key() or nil;
    if (dk and c.daily_key~=dk) or (wk and c.weekly_key~=wk) then
        local issue=add_issue(rows,'RESET_SCOPE','state:reset_keys','Daily / Weekly Reset State',
            'Saved reset keys are stale: daily '..tostring(c.daily_key)..' / weekly '..tostring(c.weekly_key)..'.','state reset engine',true);
        if repair and HC.modules.state and HC.modules.state.get_char then
            -- get_char() applies the authoritative reset migration before returning.
            pcall(HC.modules.state.get_char); issue.resolved=true; issue.repair='Reset scopes reconciled by the state engine.';
            timeline_repair(c,'Reset Scope Reconciled','Stale daily/weekly keys repaired','state reset engine'); return 1;
        end
    end
    return 0;
end


local function copy_missing(dst,src,depth)
    depth=tonumber(depth) or 0; if depth>8 or type(dst)~='table' or type(src)~='table' then return 0; end
    local changed=0;
    for k,v in pairs(src) do
        if dst[k]==nil then
            if type(v)=='table' then local t={}; copy_missing(t,v,depth+1); dst[k]=t; else dst[k]=v; end
            changed=changed+1;
        elseif type(dst[k])=='table' and type(v)=='table' then
            changed=changed+copy_missing(dst[k],v,depth+1);
        end
    end
    return changed;
end

local function profile_seen(cc)
    if type(cc)~='table' then return 0; end
    local p=type(cc.overview_profile)=='table' and cc.overview_profile or {};
    local candidates={p.last_seen_at,cc.last_seen_at,cc.updated_at,cc.state_health and cc.state_health.last_checked_at};
    local best=0; for _,v in ipairs(candidates) do best=math.max(best,tonumber(v) or 0); end
    return best;
end

local function scan_duplicate_profiles(c,rows,repair)
    local st=HC.modules.state; if not st or not st.raw then return 0; end
    local raw=st.raw(); raw.chars=type(raw.chars)=='table' and raw.chars or {};
    local groups={};
    for name,cc in pairs(raw.chars) do
        if type(name)=='string' and name~='' and type(cc)=='table' then
            local key=string.lower(name); groups[key]=groups[key] or {}; groups[key][#groups[key]+1]={name=name,cc=cc};
        end
    end
    local repaired=0; local current=tostring(st.profile_name and st.profile_name() or '');
    for key,g in pairs(groups) do
        if #g>1 then
            table.sort(g,function(a,b)
                if a.name==current and b.name~=current then return true; end
                if b.name==current and a.name~=current then return false; end
                local aa,bb=profile_seen(a.cc),profile_seen(b.cc); if aa~=bb then return aa>bb; end
                return a.name<b.name;
            end);
            local keep=g[1]; local names={}; for _,x in ipairs(g) do names[#names+1]=x.name; end
            local issue=add_issue(rows,'DUPLICATE_CHARACTER_PROFILE','chars:'..key,'Duplicate Saved Character Profile',
                'Case-insensitive duplicate records found: '..table.concat(names,', ')..'. Keeping '..keep.name..'.','saved character registry',true);
            if repair then
                local merged=0;
                for i=2,#g do merged=merged+copy_missing(keep.cc,g[i].cc,0); raw.chars[g[i].name]=nil; end
                issue.resolved=true; issue.repair='Merged missing fields into '..keep.name..' and removed '..tostring(#g-1)..' duplicate record(s).';
                timeline_repair(c,'Duplicate Character Profiles Repaired',table.concat(names,', ')..' -> '..keep.name,'character registry','case-insensitive duplicate');
                repaired=repaired+1;
            end
        end
    end
    return repaired;
end

local function scan_blackcoffin_chain(c,rows,repair)
    local st=HC.modules.state; if not st or not st.get_account_weekly then return 0; end
    local aw=st.get_account_weekly(); local b=type(aw.black_coffin)=='table' and aw.black_coffin or nil;
    if not b then return 0; end
    b.cleared=type(b.cleared)=='table' and b.cleared or {};
    local changed=false; local detail={};
    if b.cleared.captain==true and b.cleared.painter~=true then detail[#detail+1]='captain clear without painter'; if repair then b.cleared.painter=true; changed=true; end end
    if (b.cleared.captain==true or b.cleared.painter==true) and b.cleared.scouting~=true then detail[#detail+1]='later clear without scouting'; if repair then b.cleared.scouting=true; changed=true; end end
    local done=(b.cleared.scouting==true and 1 or 0)+(b.cleared.painter==true and 1 or 0)+(b.cleared.captain==true and 1 or 0);
    if done>=3 and b.locked_out==true then detail[#detail+1]='complete chain also marked locked out'; if repair then b.locked_out=false; b.failed_step=nil; b.failed_at=nil; b.failed_source=nil; changed=true; end end
    if b.locked_out==true and (b.active_step~=nil or b.active_state~=nil or b.accepted_at~=nil or b.entered_at~=nil) then
        detail[#detail+1]='weekly lockout still has active mission state';
        if repair then b.active_step=nil; b.active_state=nil; b.accepted_at=nil; b.entered_at=nil; b.time_limit_seconds=nil; b.time_limit_verified_at=nil; changed=true; end
    end
    local terminal=(done>=3 or b.locked_out==true);
    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    if terminal and c.weekly.black_coffin~=true then detail[#detail+1]='character weekly mirror missing terminal state'; if repair then c.weekly.black_coffin=true; changed=true; end
    elseif not terminal and c.weekly.black_coffin==true then detail[#detail+1]='character weekly mirror falsely complete'; if repair then c.weekly.black_coffin=nil; changed=true; end end
    if #detail==0 then return 0; end
    local issue=add_issue(rows,'BLACK_COFFIN_CHAIN','weekly:blackcoffin','Black Coffin Weekly Chain',table.concat(detail,'; '),'account-weekly chain order',true);
    if repair then
        issue.resolved=true; issue.repair='Normalized chain order, terminal lockout/completion, and character mirror.';
        if changed then timeline_repair(c,'Black Coffin Chain Repaired',table.concat(detail,'; '),'Black Coffin chain rules'); return 1; end
    end
    return 0;
end

local function scan_retired_fields(c,rows,repair)
    local st=HC.modules.state; if not st or not st.cleanup_all_retired then return 0; end
    if not repair then return 0; end
    local ok,res=pcall(st.cleanup_all_retired,false); if not ok or type(res)~='table' or (tonumber(res.removed) or 0)<=0 then return 0; end
    local issue=add_issue(rows,'RETIRED_STATE','state:retired_fields','Retired Saved-State Fields',
        string.format('%d retired presentation/cache field(s) remained across %d character profile(s).',tonumber(res.removed) or 0,tonumber(res.characters) or 0),'safe state cleanup registry',true);
    issue.resolved=true; issue.repair='Removed retired fields without touching progression/evidence.';
    timeline_repair(c,'Retired State Cleaned',tostring(res.removed)..' field(s) pruned across saved profiles','safe state cleanup registry');
    return 1;
end

local function refresh_derived(c)
    -- Repairs update authoritative/normalized state first. Downstream caches are
    -- dirtied through the dependency graph and rebuild lazily on demand; do not
    -- synchronously rebuild Search/Planner/catalog work from a self-heal pass.
    if HC.modules.progression and HC.modules.progression.reconcile then
        pcall(HC.modules.progression.reconcile,c,{reason='self-healing repair'});
    end
    if HC.modules.dependencies and HC.modules.dependencies.invalidate_many then
        pcall(HC.modules.dependencies.invalidate_many,{'weekly','quests','unlocks','seasonal','history','progression'},'self-healing repair');
    else
        if HC.modules.quests and HC.modules.quests.invalidate_runtime_cache then pcall(HC.modules.quests.invalidate_runtime_cache,false); end
        if HC.modules.planner and HC.modules.planner.invalidate then pcall(HC.modules.planner.invalidate); end
        if HC.modules.smartdashboard and HC.modules.smartdashboard.invalidate then pcall(HC.modules.smartdashboard.invalidate); end
        if HC.modules.weekly and HC.modules.weekly.invalidate_progress then pcall(HC.modules.weekly.invalidate_progress); end
    end
end

function M.scan(c,repair,reason)
    c=c or HC.modules.state.get_char(); ensure(c); local rows={}; local repairs=0;
    repairs=repairs+scan_reset_keys(c,rows,repair==true);
    repairs=repairs+scan_duplicate_profiles(c,rows,repair==true);
    repairs=repairs+scan_retired_fields(c,rows,repair==true);
    repairs=repairs+scan_blackcoffin_chain(c,rows,repair==true);
    repairs=repairs+scan_native(c,rows,repair==true);
    repairs=repairs+scan_limbus(c,rows,repair==true);
    repairs=repairs+scan_unlock_progression(c,rows,repair==true);
    repairs=repairs+scan_seasonal(c,rows,repair==true);
    repairs=repairs+scan_historical(c,rows,repair==true);
    if repair and repairs>0 then refresh_derived(c); if HC.modules.state and HC.modules.state.request_save then HC.modules.state.request_save(1); end end
    local unresolved=0; for _,r in ipairs(rows) do if not r.resolved then unresolved=unresolved+1; end end
    last={at=os.time(),issues=rows,repairs=repairs,unresolved=unresolved,reason=tostring(reason or (repair and 'repair scan' or 'audit scan'))};
    local sh=ensure(c); sh.last_scan_at=last.at; sh.last_repairs=repairs; sh.last_unresolved=unresolved; sh.last_reason=last.reason;
    return last;
end

function M.poll()
    -- v7.0: the centralized State Integrity engine owns event-driven scheduling.
    -- Keep this legacy provider API for diagnostics/backward compatibility, but
    -- do not run a second independent periodic whole-state scan when Integrity
    -- is available.
    if HC.modules.integrity then return; end
    local now=os.time(); if now-last_poll<POLL_SECONDS then return; end; last_poll=now;
    if not HC.modules.state or not HC.modules.state.profile_ready or not HC.modules.state.profile_ready() then return; end
    local c=HC.modules.state.get_char();
    local profiler=HC.modules.profiler;
    if profiler and profiler.measure then profiler.measure('selfheal.scan',M.scan,c,true,'periodic self-heal'); else M.scan(c,true,'periodic self-heal'); end
end

function M.status(c)
    c=c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    local sh=ensure(c); return {at=last.at or sh.last_scan_at,issues=#(last.issues or {}),repairs=last.repairs or sh.last_repairs or 0,unresolved=last.unresolved or sh.last_unresolved or 0,reason=last.reason or sh.last_reason};
end

function M.draw(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    c=c or HC.modules.state.get_char(); local s=M.status(c);
    imgui.Text('Self-Healing State / Contradiction Engine');
    imgui.TextDisabled('Repairs stale/contradictory state using canonical availability, authoritative ownership, reset scope, chain rules, duplicate-profile cleanup, and safe legacy pruning. Raw packet evidence is never deleted.');
    if imgui.Button('Scan & Repair Now##hc_selfheal_run') then M.scan(c,true,'diagnostics manual repair'); s=M.status(c); end
    imgui.SameLine(); if imgui.Button('Audit Only##hc_selfheal_audit') then M.scan(c,false,'diagnostics audit'); s=M.status(c); end
    imgui.Text(string.format('Last scan: %s | repairs %d | unresolved %d',s.at and os.date('%H:%M:%S',s.at) or 'never',tonumber(s.repairs) or 0,tonumber(s.unresolved) or 0));
    if #(last.issues or {})==0 then imgui.TextDisabled('No contradictions detected in the last scan.'); return; end
    for _,r in ipairs(last.issues) do
        local suffix=r.resolved and (' [REPAIRED: '..tostring(r.repair or '')..']') or ' [UNRESOLVED]';
        if r.resolved then imgui.TextDisabled(tostring(r.title)..' - '..tostring(r.detail)..suffix); else imgui.TextWrapped(tostring(r.title)..' - '..tostring(r.detail)..suffix); end
    end
end

function M.command(w)
    local sub=lower(w[2]); if sub~='selfheal' and sub~='repair' and sub~='contradictions' then return false; end
    local audit=lower(w[3])=='audit'; local r=M.scan(nil,not audit,'command'); HC.msg(string.format('Self-heal: %d contradiction(s), %d repair(s), %d unresolved.',#(r.issues or {}),r.repairs or 0,r.unresolved or 0)); return true;
end

function M.init(ctx) HC=ctx; end
return M;
