local M = {};
local HC;
local errors={};
local error_index={};
local last_monitor_error_msg=0;
local evidence_filter={''};

function M.init(ctx) HC=ctx; end

local function error_signature(where,err)
    local s=tostring(err or 'unknown error')
        :gsub('table: 0x[%da-fA-F]+','table:<addr>')
        :gsub('function: 0x[%da-fA-F]+','function:<addr>');
    return tostring(where or 'runtime')..'|'..s,s;
end

function M.record_error(where,err)
    local now=os.time();
    local sig,normalized=error_signature(where,err);
    local rec=error_index[sig];
    if rec then
        rec.count=(tonumber(rec.count) or 1)+1;
        rec.suppressed=(tonumber(rec.suppressed) or 0)+1;
        rec.last_at=now;
        rec.at=now;
        return rec;
    end
    rec={at=now,first_at=now,last_at=now,where=tostring(where),err=normalized,count=1,suppressed=0,signature=sig};
    errors[#errors+1]=rec; error_index[sig]=rec;
    while #errors>30 do
        local old=table.remove(errors,1); if old then error_index[old.signature]=nil; end
    end
    return rec;
end

function M.error_status()
    local total=0; local suppressed=0;
    for _,e in ipairs(errors) do total=total+(tonumber(e.count) or 1); suppressed=suppressed+(tonumber(e.suppressed) or 0); end
    return {distinct=#errors,total=total,suppressed=suppressed,last=errors[#errors]};
end

function M.errors()
    local out={}; for _,e in ipairs(errors) do local c={}; for k,v in pairs(e) do c[k]=v; end; out[#out+1]=c; end return out;
end

function M.clear_errors() errors={}; error_index={}; return true; end

local function learned_quests(c)
    local n=0; local q=c.quest_flags and c.quest_flags.learned or {};
    if type(q)=='table' then for _ in pairs(q) do n=n+1; end end return n;
end

local function section(imgui,label,id,default_open)
    if imgui.CollapsingHeader~=nil then
        local flags=default_open and (ImGuiTreeNodeFlags_DefaultOpen or 0) or 0;
        return imgui.CollapsingHeader(label..'##'..id,flags);
    end
    imgui.Separator();
    imgui.Text(label);
    return true;
end


local function guarded_draw(name,fn,...)
    if type(fn)~='function' then return false; end
    local g=HC and HC.modules and HC.modules.runtimeguard or nil;
    if g and g.draw then return g.draw(name,fn,...); end
    local ok,err=pcall(fn,...);
    if not ok then M.record_error(name,err); end
    return ok;
end

local function draw_automation(c)
    local imgui=HC.imgui; local a=HC.modules.automation;
    if not a then imgui.Text('Automation: MISSING'); return; end
    imgui.Text('Automation Monitor');
    imgui.Text('Global: '..a.status(c));
    local dr={a.dry_run and a.dry_run(c) or false};
    if imgui.Checkbox('Dry Run (detect only)##v57dryrun',dr) then
        c.automation.dry_run=dr[1]; HC.modules.state.save();
    end
    imgui.TextDisabled('Dry Run records detector candidates without changing checklist state or Assault Tags.');
    local zid=a.get_zone_id and a.get_zone_id() or nil;
    imgui.Text('Current zone id: '..tostring(zid or 'unavailable'));
    imgui.TextWrapped('Last AUTO event: '..a.last_event(c));
    local se=HC.modules.sessions;
    imgui.Text('Activity Session Engine');
    imgui.TextDisabled('Confidence: VERIFIED = authoritative completion/reward | CONFIRMED = direct zone/context | INFERRED = reconstructed | MANUAL = user-set');
    for _,fam in ipairs({'dynamis','limbus','assault'}) do
        local s=se and se.current(c,fam) or nil;
        if s then
            local ci=se.confidence_info and se.confidence_info(s) or {tier=tostring(s.confidence or '?'),evidence=''};
            imgui.Text(string.format('%s: #%s %s | %s | [%s]',
                string.upper(fam),tostring(s.id or '?'),tostring(s.state or 'ACTIVE'),
                tostring(s.zone_name or s.zone_id or 'no zone'),tostring(ci.tier or '?')));
            imgui.TextDisabled('  Evidence: '..tostring(ci.evidence or '?')..
                (ci.raw and (' | raw: '..tostring(ci.raw)) or '')..
                (s.recovered and ' | reload baseline' or ''));
        else
            imgui.Text(string.upper(fam)..': inactive');
        end
    end
    if se then
        local sh=se.history(c) or {};
        if #sh>0 then
            imgui.TextDisabled('Recent closed sessions:');
            for i=math.max(1,#sh-4),#sh do
                local s=sh[i];
                if s then
                    local ci=se.confidence_info and se.confidence_info(s) or {tier=tostring(s.confidence or '?'),evidence=''};
                    imgui.TextDisabled(string.format('#%s %s - %s | [%s] %s',
                        tostring(s.id or '?'),string.upper(tostring(s.kind or '?')),
                        tostring(s.state or '?'),tostring(ci.tier or '?'),tostring(ci.evidence or '')));
                end
            end
        end
    end
    imgui.Separator();
    imgui.Text('Per-system automation');
    for _,sys in ipairs(a.systems()) do
        local on=a.system_status(c,sys)=='ON'; local box={on};
        if imgui.Checkbox(sys..'##v57autosys'..sys,box) then
            c.automation.systems[sys]=box[1]; HC.modules.state.save();
        end
    end
end

local function draw_events(c)
    local imgui=HC.imgui; local a=HC.modules.automation; if not a then return; end
    imgui.Text('Automation Event History');
    local ev=a.recent(c) or {};
    if #ev==0 then imgui.TextDisabled('No automatic events recorded for this character.'); return; end
    for i=math.max(1,#ev-14),#ev do
        local e=ev[i]; if e then
            imgui.TextWrapped(string.format('#%s  %s  %-12s  %s%s%s',tostring(e.id or '?'),os.date('%H:%M:%S',e.at or os.time()),tostring(e.kind or ''),tostring(e.detail or ''),type(e.undo)=='table' and '  [UNDOABLE]' or '',e.undone and ' [UNDONE]' or ''));
        end
    end
end


function M.draw_evidence_inspector()
    local imgui=HC and HC.imgui or nil;
    local ev=HC and HC.modules and HC.modules.evidence or nil;
    if not imgui then return; end
    imgui.Text('Detection Inspector');
    if not ev then imgui.Text('Evidence resolver: MISSING'); return; end

    local st=ev.status and ev.status() or {};
    if not st.last_refresh and ev.refresh then
        pcall(ev.refresh);
        st=ev.status and ev.status() or st;
    end
    imgui.TextDisabled(string.format('Resolved fact store: %d fact(s) | %d provider(s)%s',
        tonumber(st.facts) or 0,tonumber(st.providers) or 0,
        st.last_refresh and (' | refreshed '..os.date('%H:%M:%S',st.last_refresh)) or ''));
    if imgui.Button('Refresh Evidence##hc_evidence_refresh') then
        local ok,errs=ev.refresh();
        if HC and HC.msg then HC.msg(ok and 'Evidence refresh complete.' or ('Evidence refresh: '..tostring(#errs)..' provider error(s).')); end
    end
    imgui.SameLine();
    if imgui.Button('Show Conflicts##hc_evidence_conflicts') then evidence_filter[1]='conflict'; end
    imgui.SameLine();
    if imgui.Button('Clear Filter##hc_evidence_clear') then evidence_filter[1]=''; end

    imgui.TextDisabled('Filter'); imgui.SameLine();
    if imgui.SetNextItemWidth~=nil then pcall(function() imgui.SetNextItemWidth(280); end); end
    local ok_input=pcall(function() imgui.InputText('##hc_evidence_filter',evidence_filter,96); end);
    if not ok_input then imgui.TextDisabled('InputText unavailable in this ImGui build.'); end

    local raw_filter=tostring(evidence_filter[1] or '');
    local want_conflict=(string.lower(raw_filter)=='conflict');
    local rows=ev.inspect(want_conflict and '' or raw_filter,80) or {};
    local shown=0;
    for _,r in ipairs(rows) do
        if (not want_conflict) or r.conflict then
            shown=shown+1;
            local suffix=r.conflict and '  [CONFLICT]' or '';
            local shown=(r.state=='VALUE') and tostring(r.value) or tostring(r.state);
            local line=string.format('%s = %s  [%s]  %s%s',tostring(r.key),shown,tostring(r.confidence),tostring(r.source),suffix);
            if r.state=='UNKNOWN' then imgui.TextDisabled(line); else imgui.Text(line); end
            if r.details and tostring(r.details)~='' then imgui.TextDisabled('  '..tostring(r.details)); end
            local src=ev.source_rows and ev.source_rows(r.key) or {};
            if #src>1 then
                local parts={};
                for _,e in ipairs(src) do
                    parts[#parts+1]=string.format('%s=%s/r%d',tostring(e.source),tostring(e.state),tonumber(e.rank) or 0);
                end
                imgui.TextDisabled('  Sources: '..table.concat(parts,' | '));
            end
        end
    end
    if shown==0 then imgui.TextDisabled('No evidence facts match this filter.'); end
end

local function draw_learning(c)
    local imgui=HC.imgui; local l=HC.modules.learning;
    imgui.Text('Learning / Packet Capture');
    if not l then imgui.Text('Learning module: MISSING'); return; end
    imgui.TextWrapped('Status: '..l.status());
    local cur=l.current();
    if l.active() then
        imgui.Text(string.format('Target: %s | phase=%s | packets=%d | text=%d | zone changes=%d', tostring(cur.target or '?'), tostring(cur.phase or 'capture'), tonumber(cur.packet_total) or 0, tonumber(cur.text_total) or 0, tonumber(cur.zone_total) or 0));
        imgui.Text(string.format('Markers: %d', #(cur.markers or {})));
        if cur.target == 'tags' then
            imgui.Text(string.format('Rytaal learner: 0x034 packets=%d | known count=%s | tag text=%d', #(cur.tag_menu_packets or {}), tostring(cur.known_tag_count ~= nil and cur.known_tag_count or '?'), #(cur.rytaal_text or {})));
            imgui.TextDisabled('Label the KNOWN stored-tag count after talking to Rytaal:');
            for n=0,4 do
                if n > 0 then imgui.SameLine(); end
                if imgui.Button(tostring(n)..'##v58knowntag'..tostring(n)) then l.known_tags(n); end
            end
        end
        if imgui.Button('Mark Action##v57markaction') then l.mark('action'); end
        imgui.SameLine(); if imgui.Button('Mark Reward##v57markreward') then l.mark('reward'); end
        imgui.SameLine(); if imgui.Button('Mark Done##v57markdone') then l.mark('done'); end
        if imgui.Button('Stop Capture##v57learnstop') then l.stop('monitor button'); end
        imgui.SameLine(); imgui.TextDisabled('Command: /hcheck learn stop');
        imgui.Text('Top packet IDs this capture');
        for _,r in ipairs(l.top_packets(10)) do imgui.Text(string.format('0x%03X  x%d',tonumber(r.id) or 0,tonumber(r.count) or 0)); end
    else
        local s=c.learning_summary or {};
        if s.target then
            imgui.TextWrapped(string.format('Last capture: %s | packets=%s | IDs=%s | text=%s | ended %s', tostring(s.target), tostring(s.packet_total or 0), tostring(s.unique_packet_ids or 0), tostring(s.text_total or 0), s.ended_at and os.date('%Y-%m-%d %H:%M:%S',s.ended_at) or '?'));
            if s.log_path then imgui.TextWrapped('Raw log: '..tostring(s.log_path)); end
            if s.report_path then imgui.TextWrapped('Evidence report: '..tostring(s.report_path)); end
            imgui.Text(string.format('Markers: %s', tostring(s.marker_total or 0)));
            if s.target == 'tags' then
                imgui.Text(string.format('Last tag capture: 0x034=%s | known=%s | persisted observations=%s | known states=%s', tostring(s.tag_menu_packets or 0), tostring(s.known_tag_count ~= nil and s.known_tag_count or '?'), tostring(s.tag_observations or 0), tostring(s.tag_known_states or 0)));
            end
        else imgui.TextDisabled('No completed learning capture for this character.'); end
        local ts=l.tag_learning_status(c);
        imgui.Text(string.format('Assault Tag learner database: %d observation(s) | %d known count state(s) | %d candidate offset(s)', ts.observations or 0, ts.known_states or 0, #(ts.candidates or {})));
        if ts.known_counts and #ts.known_counts > 0 then
            local kn={}; for _,n in ipairs(ts.known_counts) do kn[#kn+1]=tostring(n); end
            imgui.TextDisabled('Known counts captured: '..table.concat(kn, ', '));
        end
        imgui.TextDisabled('Start: /hcheck learn <activity> [seconds]');
        imgui.TextDisabled('Profiles: assault, tags, limbus, dynamis, eco, guild, enm, dragon, highwind, haap, chocobo, blackcoffin, outposts, pots, currency, keyitem, questmenu');
        imgui.TextDisabled('During capture: /hcheck learn mark <label>');
        if imgui.Button('Clear Learning Log##v57learnclear') then l.clear_log(); end
    end
end

function M.draw(c)
    local imgui=HC and HC.imgui or nil;
    if imgui==nil then return false; end
    c=c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or nil;
    if not c then
        imgui.TextDisabled('Diagnostics unavailable: character state is not ready.');
        return false;
    end

    local function subsection(label)
        imgui.Spacing();
        imgui.Text(tostring(label));
        imgui.Separator();
    end

    local function draw_quick_actions()
        if imgui.Button('Save Now##v737diagsave') then
            HC.modules.state.save();
            HC.msg('State saved.');
        end
        imgui.SameLine();
        if imgui.Button('Undo Last AUTO##v737diagundo') then
            if HC.modules.automation then HC.modules.automation.undo_last(c); end
        end
        imgui.SameLine();
        if imgui.Button('Run Self-Test##v737selftest') then
            HC.msg('Use /hcheck selftest for full module test.');
        end
        local saved=HC.modules.state.last_saved_at and HC.modules.state.last_saved_at() or nil;
        imgui.TextDisabled('Last save: '..(saved and os.date('%H:%M:%S',saved) or 'not this session')..'  |  State auto-saves during normal use.');
    end

    local function draw_state_audit()
        local hist=HC.modules.state.audit_recent(c,10);
        if #hist==0 then
            imgui.TextDisabled('No state changes recorded yet.');
            return;
        end
        for _,e in ipairs(hist) do
            local ts=e.at and os.date('%H:%M:%S',e.at) or '--:--:--';
            local extra='';
            if e.confidence then extra=extra..' ['..tostring(e.confidence)..']'; end
            if e.source then extra=extra..' - '..tostring(e.source); end
            imgui.TextDisabled(ts..' '..tostring(e.system or 'general')..': '..tostring(e.message or '')..extra);
        end
    end

    local function draw_repairs()
        imgui.TextDisabled('Recovery controls for tracker mismatches. These are not needed during normal use.');
        if HC.modules.assault and HC.modules.assault.draw_manual_adjust then
            imgui.Text('Assault Tags');
            HC.modules.assault.draw_manual_adjust(c);
        else
            imgui.TextDisabled('Assault Tag repair controls unavailable.');
        end
        if HC.modules.weekly and HC.modules.weekly.draw_lockout_repairs then
            imgui.Separator();
            HC.modules.weekly.draw_lockout_repairs(c);
        else
            imgui.TextDisabled('Dynamis / Limbus repair controls unavailable.');
        end
    end

    local function draw_system_health()
        local packets=(HC.modules.packets~=nil) and 'OK' or 'MISSING';
        local assault=(HC.modules.assault~=nil) and 'OK' or 'MISSING';
        local enm=(HC.modules.enm~=nil) and 'OK' or 'MISSING';
        local learning=(HC.modules.learning~=nil) and 'OK' or 'MISSING';
        imgui.TextWrapped(string.format('State OK  |  Packets %s  |  Assault %s  |  ENM %s  |  Learning %s',packets,assault,enm,learning));
        if HC.modules.assault and HC.modules.assault.packet_status then
            imgui.TextDisabled('Assault Tags: '..HC.modules.assault.packet_status(c));
        end
        local guild_mode=(c.guild_points and c.guild_points.packet) and 'AUTO MAPPING LEARNED' or 'TEXT AUTO / MANUAL FALLBACK';
        imgui.Text('Guild GP: '..guild_mode);
        if HC.modules.guild then imgui.TextDisabled('  '..HC.modules.guild.status(c)); end
        if HC.modules.digging then imgui.Text('Digging: '..HC.modules.digging.status(c)); end
        imgui.Text(string.format('Quest flags learned: %d/4',learned_quests(c)));
        if HC.modules.userdata and HC.modules.userdata.status then
            local uds=HC.modules.userdata.status();
            local mode=uds.external and 'CONFIG / WRITABLE' or 'ADDON FALLBACK';
            imgui.TextDisabled('User Data: '..tostring(uds.root or '?')..' - '..mode);
            if uds.fallback and uds.reason then imgui.TextDisabled('  Fallback reason: '..tostring(uds.reason)); end
            if uds.external and uds.legacy_cleanup_attempted then
                if uds.legacy_cleanup_waiting then
                    imgui.TextDisabled('Legacy addon cleanup: WAITING | first validated config state save');
                elseif uds.legacy_cleanup_complete then
                    imgui.TextDisabled(string.format('Legacy addon cleanup: PASS | removed %d | collision archives %d',tonumber(uds.legacy_cleanup_removed) or 0,tonumber(uds.legacy_cleanup_preserved) or 0));
                else
                    imgui.TextDisabled('Legacy addon cleanup: ATTENTION | failures '..tostring(uds.legacy_cleanup_failed or 0));
                    for _,e in ipairs(uds.legacy_cleanup_errors or {}) do imgui.TextDisabled('  '..tostring(e)); end
                end
            end
        end
        imgui.TextDisabled('Backups: backups\\horizoncheck_state.lua.bak1 / .bak2 / .bak3');
        imgui.TextDisabled('Audit logs: logs\\horizoncheck_audit_<character>.log');
        if c.last_reset then
            imgui.TextDisabled(string.format('Last reset archive: %s | %s',tostring(c.last_reset.scope or '?'),os.date('%Y-%m-%d %H:%M:%S',c.last_reset.at or os.time())));
        end
        imgui.TextDisabled('Reset archives retained: '..tostring(#(c.reset_history or {}))..'/20');
        if HC.modules.availability and HC.modules.availability.status then
            local av=HC.modules.availability.status(); imgui.TextDisabled(string.format('Availability engine: %d future | %d unverified',tonumber(av.future) or 0,tonumber(av.unverified) or 0));
        end
        if HC.modules.canonical and HC.modules.canonical.status then
            local cs=HC.modules.canonical.status(); imgui.TextDisabled(string.format('Canonical registry: %d quarantined native ID(s) | %d explicit collision(s)',tonumber(cs.quarantined) or 0,tonumber(cs.collisions) or 0));
        end
        if HC.modules.catalog_coverage and HC.modules.catalog_coverage.status then
            local cv=HC.modules.catalog_coverage.status(); imgui.TextDisabled(string.format('Catalog coverage: %.1f%% verified | %d issue(s)',tonumber(cv.scores and cv.scores.overall) or 0,tonumber(cv.issues) or 0));
        end
        if HC.modules.integrity and HC.modules.integrity.status then
            local si=HC.modules.integrity.status(c); imgui.TextDisabled(string.format('State integrity: %s | %d repair(s) | %d unresolved',tostring(si.state or '?'),tonumber(si.repairs) or 0,tonumber(si.unresolved) or 0));
        end
        if HC.modules.synchealth and HC.modules.synchealth.status then
            local sy=HC.modules.synchealth.status(c); imgui.TextDisabled(string.format('Synchronization health: %s | %d stale | %d need sync',tostring(sy.state or '?'),tonumber(sy.stale) or 0,tonumber(sy.needs_sync) or 0));
        end
        if HC.modules.unlocks and HC.modules.unlocks.status then
            local us=HC.modules.unlocks.status(c); imgui.TextDisabled(string.format('Unlock registry: %d tracked | %d owned',tonumber(us.total) or 0,tonumber(us.counts and us.counts.OWNED) or 0));
        end
        if HC.modules.profiler and HC.modules.profiler.status then
            local ps=HC.modules.profiler.status(); imgui.TextDisabled(string.format('Profiler: %d section(s) | %d warning(s)',tonumber(ps.sections) or 0,tonumber(ps.warnings) or 0));
        end
        if HC.modules.performance_watchdog and HC.modules.performance_watchdog.status then
            local pw=HC.modules.performance_watchdog.status(); imgui.TextDisabled(string.format('Performance watchdog: %s | %d warning(s)',tostring(pw.state or 'WARMING UP'),tonumber(pw.issues) or 0));
        end
        if HC.modules.seasonal and HC.modules.seasonal.catalog_status then
            local ss=HC.modules.seasonal.catalog_status();
            imgui.TextDisabled(string.format('Seasonal catalog: %d/%d exact item IDs | year %s: %d current-verified, %d historical',tonumber(ss.resolved) or 0,tonumber(ss.total) or 0,tostring(ss.current_year or '?'),tonumber(ss.current_verified) or 0,tonumber(ss.historical) or 0));
        end
        if HC.modules.anniversary and HC.modules.anniversary.automation_status then
            local aa=HC.modules.anniversary.automation_status(c);
            imgui.TextDisabled(string.format('Anniversary automation: %d/%d NPC lane(s) observed | %d advancement(s) | %d backfilled | %d verified counter completion(s)',tonumber(aa.lanes_observed) or 0,tonumber(aa.lanes_total) or 0,tonumber(aa.advancements) or 0,tonumber(aa.backfilled) or 0,tonumber(aa.counter_verified) or 0));
        end
    end

    local function draw_regression()
        if HC.modules.regression and HC.modules.regression.draw then
            HC.modules.regression.draw();
        else
            imgui.TextDisabled('Regression module unavailable.');
        end
        imgui.Separator();
        imgui.Text('Self-test: '..((HC.self_test_failures and #HC.self_test_failures>0) and 'ATTENTION' or 'PASS'));
        if HC.self_test_failures and #HC.self_test_failures>0 then
            for _,e in ipairs(HC.self_test_failures) do imgui.TextWrapped('FAIL: '..e); end
        end
    end

    local function draw_runtime_errors()
        local error_summary=M.error_status();
        if #errors==0 then
            imgui.TextDisabled('No runtime errors captured this session.');
            return;
        end
        imgui.TextDisabled(string.format('%d total error event(s) | %d duplicate repeat(s) collapsed',
            tonumber(error_summary.total) or 0,tonumber(error_summary.suppressed) or 0));
        for i=math.max(1,#errors-9),#errors do
            local e=errors[i];
            if e then
                local count=(tonumber(e.count) or 1)>1 and (' x'..tostring(e.count)) or '';
                imgui.TextWrapped(os.date('%H:%M:%S',e.last_at or e.at)..' '..e.where..count..': '..e.err);
                if e.first_at and e.last_at and e.first_at~=e.last_at then
                    imgui.TextDisabled('  first '..os.date('%H:%M:%S',e.first_at)..' | last '..os.date('%H:%M:%S',e.last_at));
                end
            end
        end
        if imgui.Button('Clear Errors##v737clearerrors') then M.clear_errors(); end
        if HC.modules.runtimeguard and HC.modules.runtimeguard.retry_all then
            imgui.SameLine();
            if imgui.Button('Retry Paused Operations##v737retryguards') then HC.modules.runtimeguard.retry_all(); end
        end
    end

    local function draw_recent_packets()
        local r=HC.modules.packets and HC.modules.packets.recent and HC.modules.packets.recent() or {};
        if #r==0 then
            imgui.TextDisabled('No recent packets recorded.');
            return;
        end
        for i=math.max(1,#r-9),#r do
            local p=r[i];
            if p then imgui.Text(string.format('0x%03X  size=%d',p.id,p.size)); end
        end
    end

    local ok,err=xpcall(function()
        imgui.Text('HorizonCheck v'..HC.version);
        imgui.SameLine();
        imgui.TextDisabled('| '..tostring(HC.modules.core.character_name()));

        local release=HC.modules.releasehealth and HC.modules.releasehealth.status and HC.modules.releasehealth.status(c,false) or {};
        local sync=HC.modules.synchealth and HC.modules.synchealth.status and HC.modules.synchealth.status(c) or {};
        local integ=HC.modules.integrity and HC.modules.integrity.status and HC.modules.integrity.status(c) or {};
        local perf=HC.modules.performance_watchdog and HC.modules.performance_watchdog.status and HC.modules.performance_watchdog.status() or {};
        local es=M.error_status();
        imgui.TextDisabled(string.format('Release: %s  |  Sync: %s  |  Errors: %d  |  State: %s  |  Performance: %s',
            tostring(release.state or 'UNKNOWN'),tostring(sync.state or 'UNKNOWN'),tonumber(es.distinct) or 0,
            tostring(integ.state or 'UNKNOWN'),tostring(perf.state or 'WARMING UP')));
        imgui.TextDisabled('Diagnostics are grouped by purpose. Expand a section only when troubleshooting.');
        imgui.Separator();

        -- 1) Health & Errors
        local health_open=(tonumber(es.distinct) or 0)>0 or (tonumber(integ.unresolved) or 0)>0;
        if section(imgui,'Health & Errors','v737diag_health_errors',health_open) then
            subsection('Quick Actions');
            draw_quick_actions();

            if HC.modules.releasehealth and HC.modules.releasehealth.draw then
                subsection('Release Health');
                guarded_draw('Release Health',HC.modules.releasehealth.draw,c);
            end
            if HC.modules.synchealth and HC.modules.synchealth.draw then
                subsection('Synchronization Health');
                guarded_draw('Synchronization Health',HC.modules.synchealth.draw,c);
            end

            subsection('System Health');
            draw_system_health();

            if HC.modules.runtimeguard and HC.modules.runtimeguard.draw_status then
                subsection('Module Error Isolation');
                guarded_draw('Runtime Guard Status',HC.modules.runtimeguard.draw_status);
            end

            subsection('Runtime Errors ('..tostring(es.distinct or 0)..' distinct)');
            draw_runtime_errors();
        end

        -- 2) State & Recovery
        if section(imgui,'State & Recovery','v737diag_state_recovery',false) then
            if HC.modules.integrity and HC.modules.integrity.draw then
                subsection('State Integrity / Automatic Repair');
                guarded_draw('State Integrity Diagnostics',HC.modules.integrity.draw,c);
            end
            if HC.modules.selfheal and HC.modules.selfheal.draw then
                subsection('Self-Healing / Contradictions');
                guarded_draw('Self-Healing',HC.modules.selfheal.draw,c);
            end
            if HC.modules.state and HC.modules.state.audit_recent then
                subsection('Recent State Audit');
                draw_state_audit();
            end
            if HC.modules.timeline and HC.modules.timeline.draw then
                subsection('Activity Timeline & Repair History');
                guarded_draw('Activity Timeline',HC.modules.timeline.draw,c);
            end
            if HC.modules.state and HC.modules.state.draw_cleanup then
                subsection('State Cleanup / Migration Pruning');
                guarded_draw('State Cleanup',HC.modules.state.draw_cleanup,c);
            end
            subsection('Advanced Repairs');
            draw_repairs();
        end

        -- 3) Detection & Evidence
        if section(imgui,'Detection & Evidence','v737diag_detection_evidence',false) then
            if HC.modules.keyitems and HC.modules.keyitems.draw then
                subsection('Key Item Diagnostics');
                guarded_draw('Key Item Diagnostics',HC.modules.keyitems.draw,c);
            end
            subsection('Detection Inspector');
            M.draw_evidence_inspector();
            subsection('Learning / Packet Capture');
            draw_learning(c);
            if HC.modules.anniversary and HC.modules.anniversary.draw_automation_diagnostics then
                subsection('Anniversary Automation Evidence');
                guarded_draw('Anniversary Automation Evidence',HC.modules.anniversary.draw_automation_diagnostics,c);
            end
        end

        -- 4) Progression & Sync
        if section(imgui,'Progression & Sync','v737diag_progression_sync',false) then
            if HC.modules.characterregistry and HC.modules.characterregistry.draw then
                subsection('Character Registry');
                guarded_draw('Character Registry',HC.modules.characterregistry.draw);
            end
            if HC.modules.assaultprogress and HC.modules.assaultprogress.draw_native_diagnostics then
                subsection('Assault History Validation');
                guarded_draw('Assault History Validation',HC.modules.assaultprogress.draw_native_diagnostics,c);
            end
            if HC.modules.historyimport and HC.modules.historyimport.draw then
                subsection('Historical Progression Import');
                guarded_draw('Historical Progression Import',HC.modules.historyimport.draw,c);
            end
            if HC.modules.zonesync and HC.modules.zonesync.draw then
                subsection('Zone Snapshot / Reconciliation');
                guarded_draw('Zone Sync Diagnostics',HC.modules.zonesync.draw,c);
            end
            if HC.modules.progression and HC.modules.progression.draw then
                subsection('Progression State Engine');
                guarded_draw('Progression Diagnostics',HC.modules.progression.draw,c);
            end
            subsection('Automation & Sessions');
            draw_automation(c);
        end

        -- 5) Performance
        if section(imgui,'Performance','v737diag_performance',false) then
            if HC.modules.profiler and HC.modules.profiler.draw then
                subsection('Performance Profiler');
                guarded_draw('Performance Profiler',HC.modules.profiler.draw,c);
            end
            if HC.modules.performance_watchdog and HC.modules.performance_watchdog.draw then
                subsection('Performance Watchdog');
                guarded_draw('Performance Watchdog',HC.modules.performance_watchdog.draw,c);
            end
        end

        -- 6) Advanced / Developer
        if section(imgui,'Advanced / Developer','v737diag_advanced',false) then
            imgui.TextDisabled('Low-level validation and development tools. Usually not needed during normal play.');
            if HC.modules.availability and HC.modules.availability.draw then
                subsection('HorizonXI Availability / Era Validation');
                guarded_draw('Availability Diagnostics',HC.modules.availability.draw,c);
            end
            if HC.modules.canonical and HC.modules.canonical.draw then
                subsection('Canonical Content / Native-ID Protection');
                guarded_draw('Canonical Diagnostics',HC.modules.canonical.draw,c);
            end
            if HC.modules.unlocks and HC.modules.unlocks.draw then
                subsection('Permanent Unlock Registry');
                guarded_draw('Unlock Diagnostics',HC.modules.unlocks.draw,c);
            end
            if HC.modules.dependencies and HC.modules.dependencies.draw then
                subsection('Dependency Reconciliation');
                guarded_draw('Dependency Reconciliation',HC.modules.dependencies.draw,c);
            end
            subsection('Legacy Automation Event History');
            draw_events(c);
            if HC.modules.systems and HC.modules.systems.draw then
                subsection('System State Engines');
                guarded_draw('System State Engines',HC.modules.systems.draw,c);
            end
            if HC.modules.catalog_integrity and HC.modules.catalog_integrity.draw then
                subsection('Catalog Integrity');
                guarded_draw('Catalog Integrity',HC.modules.catalog_integrity.draw,c);
            end
            if HC.modules.catalog_coverage and HC.modules.catalog_coverage.draw then
                subsection('Catalog Coverage / Guided Verification');
                guarded_draw('Catalog Coverage',HC.modules.catalog_coverage.draw,c);
            end
            subsection('Regression & Self-Test');
            draw_regression();
            subsection('Recent Packets');
            draw_recent_packets();
        end
    end,function(e) return tostring(e); end);

    if not ok then
        M.record_error('diagnostics tab body',err);
        imgui.Text('Diagnostics encountered an error.');
        imgui.TextDisabled('The error was captured under Health & Errors. Other HorizonCheck tabs remain available.');
        local now=os.time();
        if now-last_monitor_error_msg>=10 then
            last_monitor_error_msg=now;
            HC.msg('Diagnostics tab error captured. See Diagnostics -> Health & Errors.');
        end
    end
    return ok;
end

return M;
