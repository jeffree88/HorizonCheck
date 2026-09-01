local M = {};
local HC;
local cache={at=0,snapshot=nil};
local queue_filter='ALL';

local function lower(v) return string.lower(tostring(v or '')); end
local function is_blank(v) return v==nil or tostring(v):match('^%s*$')~=nil; end
local function generic_text(v)
    local s=lower(v);
    return s=='' or s:find("complete the quest's requested task",1,true)
        or s:find('then return as directed',1,true)
        or s:find('quest reward documented',1,true)
        or s:find('quest progression reward',1,true)
        or s:find('quest npc',1,true)
        or s:find('quest contact',1,true)
        or s=='varies';
end

local function completeness(detail)
    detail=type(detail)=='table' and detail or {};
    local missing={}; local score=0; local total=8;
    if not is_blank(detail.start_npc) and not generic_text(detail.start_npc) then score=score+1 else missing[#missing+1]='NPC'; end
    if not is_blank(detail.start_zone) and not generic_text(detail.start_zone) then score=score+1 else missing[#missing+1]='Zone'; end
    if not is_blank(detail.objective) and not generic_text(detail.objective) then score=score+1 else missing[#missing+1]='Objective'; end
    if not is_blank(detail.reward) and not generic_text(detail.reward) then score=score+1 else missing[#missing+1]='Reward'; end
    if not is_blank(detail.next_step) and not generic_text(detail.next_step) then score=score+1 else missing[#missing+1]='Next step'; end
    if detail.requirements_mapped==true or (type(detail.requirements)=='table' and next(detail.requirements)~=nil) then score=score+1 else missing[#missing+1]='Requirements'; end
    if detail.catalog_quality_verified==true then score=score+1 else missing[#missing+1]='Quality review'; end
    if type(detail.horizon)=='table' and detail.horizon.verified==true and not is_blank(detail.horizon.source) then score=score+1 else missing[#missing+1]='Horizon source'; end
    return score,total,missing;
end

local function add_issue(out,priority,kind,rec,detail,capture_mode)
    out.issues[#out.issues+1]={priority=priority,kind=kind,key=rec.key,name=rec.name,log_id=rec.log_id,quest_id=rec.quest_id,
        detail=tostring(detail or ''),capture_mode=capture_mode or 'verify',record=rec};
end

local function issue_bucket(it)
    local kind=lower(it and it.kind or '');
    if tonumber(it and it.priority)==1 or kind:find('collision',1,true) or kind:find('mismatch',1,true) then return 'COLLISIONS'; end
    if kind:find('native',1,true) then return 'NATIVE IDS'; end
    if kind:find('availability',1,true) then return 'AVAILABILITY'; end
    return 'CATALOG FIELDS';
end

local function issue_matches_filter(it,filter)
    filter=tostring(filter or 'ALL'); return filter=='ALL' or issue_bucket(it)==filter;
end

local function build_snapshot()
    local out={at=os.time(),groups={},issues={},totals={quests=0,verified=0,incomplete=0,unavailable=0,future=0,unverified=0,quarantined=0,blocked=0,collisions=0},score_counts={native={ok=0,total=0},availability={ok=0,total=0},npc_zone={ok=0,total=0},requirements={ok=0,total=0},rewards={ok=0,total=0},waits={ok=0,total=0},completion_evidence={ok=0,total=0}}};
    local canonical=HC and HC.modules and HC.modules.canonical or nil;
    local q=HC and HC.modules and HC.modules.quests or nil;
    if not canonical or not canonical.snapshot then return out; end
    local s=canonical.snapshot(false);
    for _,rec in pairs(s.records or {}) do
        out.totals.quests=out.totals.quests+1;
        local log_name=(q and q.log_name and q.log_name(rec.log_id)) or ('Log '..tostring(rec.log_id));
        local g=out.groups[log_name] or {name=log_name,total=0,verified=0,incomplete=0,unavailable=0,future=0,unverified=0,quarantined=0,blocked=0}; out.groups[log_name]=g;
        g.total=g.total+1;
        local score,total,missing=completeness(rec.detail);
        rec.coverage_score=score; rec.coverage_total=total; rec.coverage_missing=missing;
        local sc=out.score_counts;
        sc.native.total=sc.native.total+1; if rec.native_policy~='QUARANTINE' then sc.native.ok=sc.native.ok+1; end
        sc.availability.total=sc.availability.total+1; if rec.content_state~='UNVERIFIED' then sc.availability.ok=sc.availability.ok+1; end
        local actionable=(rec.content_state=='AVAILABLE' or rec.content_state=='HORIZON_CUSTOM');
        if actionable then
            sc.npc_zone.total=sc.npc_zone.total+1;
            if not is_blank(rec.detail and rec.detail.start_npc) and not generic_text(rec.detail.start_npc) and not is_blank(rec.detail.start_zone) and not generic_text(rec.detail.start_zone) then sc.npc_zone.ok=sc.npc_zone.ok+1; end
            sc.requirements.total=sc.requirements.total+1;
            if rec.detail and (rec.detail.requirements_mapped==true or (type(rec.detail.requirements)=='table' and next(rec.detail.requirements)~=nil)) then sc.requirements.ok=sc.requirements.ok+1; end
            sc.rewards.total=sc.rewards.total+1;
            if rec.detail and not is_blank(rec.detail.reward) and not generic_text(rec.detail.reward) then sc.rewards.ok=sc.rewards.ok+1; end
            local req=rec.detail and type(rec.detail.requirements)=='table' and rec.detail.requirements or {};
            local has_wait=req.wait_seconds_after_quest~=nil or req.wait_jst_midnight_after_quest~=nil or req.zone_after_wait~=nil;
            if has_wait then sc.waits.total=sc.waits.total+1; if rec.detail.catalog_quality_verified==true then sc.waits.ok=sc.waits.ok+1; end end
            sc.completion_evidence.total=sc.completion_evidence.total+1;
            if rec.native_policy=='ALLOW' and rec.detail and type(rec.detail.horizon)=='table' and rec.detail.horizon.verified==true and not is_blank(rec.detail.horizon.source) then sc.completion_evidence.ok=sc.completion_evidence.ok+1; end
        end
        if rec.content_state=='UNAVAILABLE' then g.unavailable=g.unavailable+1; out.totals.unavailable=out.totals.unavailable+1;
        elseif rec.content_state=='FUTURE' then g.future=g.future+1; out.totals.future=out.totals.future+1;
        elseif rec.content_state=='UNVERIFIED' then g.unverified=g.unverified+1; out.totals.unverified=out.totals.unverified+1;
        end
        if rec.native_policy=='QUARANTINE' then g.quarantined=g.quarantined+1; out.totals.quarantined=out.totals.quarantined+1;
        elseif rec.native_policy=='BLOCK' then g.blocked=g.blocked+1; out.totals.blocked=out.totals.blocked+1; end
        if rec.collision then out.totals.collisions=out.totals.collisions+1; add_issue(out,1,'Native ID collision / mismatch',rec,rec.reason,'availability'); end
        if rec.native_policy=='QUARANTINE' then add_issue(out,2,'Native mapping unverified',rec,rec.source_reason or rec.reason,'start'); end
        if rec.content_state=='UNVERIFIED' then add_issue(out,3,'HorizonXI availability unverified',rec,rec.reason,'availability'); end
        if score>=total and rec.native_policy=='ALLOW' then g.verified=g.verified+1; out.totals.verified=out.totals.verified+1;
        elseif rec.content_state=='AVAILABLE' or rec.content_state=='HORIZON_CUSTOM' then
            g.incomplete=g.incomplete+1; out.totals.incomplete=out.totals.incomplete+1;
            if #missing>0 then add_issue(out,4,'Catalog fields need review',rec,table.concat(missing,', '),'verify'); end
        end
    end
    table.sort(out.issues,function(a,b)
        if a.priority~=b.priority then return a.priority<b.priority; end
        if a.kind~=b.kind then return a.kind<b.kind; end
        return lower(a.name)<lower(b.name);
    end);
    out.group_rows={}; for _,g in pairs(out.groups) do out.group_rows[#out.group_rows+1]=g; end
    table.sort(out.group_rows,function(a,b) return a.name<b.name; end);
    out.issue_counts={ALL=#out.issues,['COLLISIONS']=0,['NATIVE IDS']=0,['AVAILABILITY']=0,['CATALOG FIELDS']=0};
    for _,it in ipairs(out.issues) do local b=issue_bucket(it); out.issue_counts[b]=(out.issue_counts[b] or 0)+1; end
    out.scores={}; local sum=0; local nscore=0;
    for name,r in pairs(out.score_counts) do
        local pct=(tonumber(r.total) or 0)>0 and ((tonumber(r.ok) or 0)/(tonumber(r.total) or 1)*100) or 100;
        out.scores[name]={ok=r.ok,total=r.total,pct=pct}; sum=sum+pct; nscore=nscore+1;
    end
    out.scores.overall=nscore>0 and (sum/nscore) or 100;
    return out;
end

function M.snapshot(force)
    local now=os.time(); if not force and cache.snapshot then return cache.snapshot; end
    cache={at=now,snapshot=build_snapshot()}; return cache.snapshot;
end
function M.invalidate() cache={at=0,snapshot=nil}; end
function M.issues(force) return M.snapshot(force).issues or {}; end

function M.draw(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    c=c or HC.modules.state.get_char(); local s=M.snapshot(false); local t=s.totals;
    imgui.Text('Catalog Coverage / Verification Dashboard');
    imgui.TextDisabled('Shows which HorizonXI records are verified, incomplete, unavailable, future, or unsafe to infer from native IDs.');
    imgui.Text(string.format('Quests %d | Verified %d | Incomplete %d | Unverified %d | Quarantined IDs %d | Explicit collisions %d',
        t.quests or 0,t.verified or 0,t.incomplete or 0,t.unverified or 0,t.quarantined or 0,t.collisions or 0));
    local sc=s.scores or {};
    imgui.Text(string.format('HorizonXI Catalog Verification Score: %.1f%%',tonumber(sc.overall) or 0));
    local score_order={{'native','Native IDs'},{'availability','Availability'},{'npc_zone','NPC / Zone'},{'requirements','Prerequisites'},{'rewards','Rewards'},{'waits','Wait Conditions'},{'completion_evidence','Completion Evidence'}};
    local parts={}; for _,pair in ipairs(score_order) do local r=sc[pair[1]] or {}; parts[#parts+1]=string.format('%s %.0f%%',pair[2],tonumber(r.pct) or 0); end
    imgui.TextDisabled(table.concat(parts,' | '));
    if imgui.Button('Rebuild Coverage Audit##hc_coverage_refresh') then s=M.snapshot(true); end

    local table_ok=(imgui.BeginTable~=nil and imgui.TableSetupColumn~=nil and imgui.TableHeadersRow~=nil and imgui.TableNextRow~=nil and imgui.TableSetColumnIndex~=nil and imgui.EndTable~=nil);
    if table_ok and imgui.BeginTable('##hc_coverage_groups',8,64+128+512) then
        for _,h in ipairs({'Quest Log','Total','Verified','Incomplete','Unverified','Unavailable','Future','ID Quarantine'}) do imgui.TableSetupColumn(h); end
        imgui.TableHeadersRow();
        for _,g in ipairs(s.group_rows or {}) do
            imgui.TableNextRow(); local vals={g.name,g.total,g.verified,g.incomplete,g.unverified,g.unavailable,g.future,g.quarantined};
            for i,v in ipairs(vals) do imgui.TableSetColumnIndex(i-1); if i==1 then imgui.Text(tostring(v)) else imgui.TextDisabled(tostring(v or 0)); end end
        end
        imgui.EndTable();
    else
        for _,g in ipairs(s.group_rows or {}) do imgui.Text(string.format('%s: %d total | %d verified | %d incomplete | %d quarantined',g.name,g.total,g.verified,g.incomplete,g.quarantined)); end
    end

    imgui.Separator();
    if HC.modules.capturewizard and HC.modules.capturewizard.draw then HC.modules.capturewizard.draw(c); end
    imgui.Separator();
    imgui.Text('Highest-Priority Verification Queue');
    imgui.TextDisabled('Prioritized work queue for HorizonXI collisions, unsafe native IDs, availability gaps, and incomplete catalog fields.');
    local ic=s.issue_counts or {};
    for i,opt in ipairs({'ALL','COLLISIONS','NATIVE IDS','AVAILABILITY','CATALOG FIELDS'}) do
        if i>1 then imgui.SameLine(); end
        local label=opt..' ('..tostring(ic[opt] or 0)..')##hc_cov_filter_'..tostring(i);
        if imgui.SmallButton(label) then queue_filter=opt; end
    end
    imgui.TextDisabled('Showing: '..tostring(queue_filter));
    local developer=type(c.settings)=='table' and c.settings.developer_mode==true;
    local shown=0;
    if table_ok and imgui.BeginTable('##hc_coverage_issues',5,64+128+512) then
        imgui.TableSetupColumn('Priority',0,70); imgui.TableSetupColumn('Quest',0,260); imgui.TableSetupColumn('Issue',0,190); imgui.TableSetupColumn('Detail',0,430); imgui.TableSetupColumn('Capture',0,90); imgui.TableHeadersRow();
        for _,it in ipairs(s.issues or {}) do
            if issue_matches_filter(it,queue_filter) then
            if shown>=30 then break; end; shown=shown+1; imgui.TableNextRow();
            imgui.TableSetColumnIndex(0); imgui.TextDisabled(tostring(it.priority));
            imgui.TableSetColumnIndex(1); imgui.Text(tostring(it.name)..' ['..tostring(it.key)..']');
            imgui.TableSetColumnIndex(2); imgui.TextDisabled(tostring(it.kind));
            imgui.TableSetColumnIndex(3); imgui.TextDisabled(tostring(it.detail));
            imgui.TableSetColumnIndex(4);
            if developer and HC.modules.capturewizard and HC.modules.capturewizard.capture_button then
                HC.modules.capturewizard.capture_button(it.log_id,it.quest_id,it.capture_mode,'coverage_'..tostring(it.key):gsub(':','_')..'_'..tostring(shown));
            else imgui.TextDisabled(developer and '-' or 'DEV'); end
            end
        end
        imgui.EndTable();
    else
        for _,it in ipairs(s.issues or {}) do
            if issue_matches_filter(it,queue_filter) then
                if shown>=20 then break; end; shown=shown+1; imgui.TextWrapped(string.format('P%d %s [%s] - %s: %s',it.priority,it.name,it.key,it.kind,it.detail));
            end
        end
    end
    local filtered_total=0; for _,it in ipairs(s.issues or {}) do if issue_matches_filter(it,queue_filter) then filtered_total=filtered_total+1; end end
    if shown==0 then imgui.TextDisabled('No verification issues in this queue.');
    elseif filtered_total>shown then imgui.TextDisabled('+'..tostring(filtered_total-shown)..' more issue(s) in this queue'); end
    if not developer then imgui.TextDisabled('Enable Developer Mode to start guided captures from the verification queue.'); end
end

function M.status()
    local s=M.snapshot(false); return {at=s.at,totals=s.totals,issues=#(s.issues or {}),issue_counts=s.issue_counts or {},scores=s.scores or {}};
end

function M.work_queue(force)
    local s=M.snapshot(force==true); local out={counts=s.issue_counts or {},next={}};
    for _,it in ipairs(s.issues or {}) do if #out.next<10 then out.next[#out.next+1]=it; else break; end end
    return out;
end

function M.command(w)
    local sub=lower(w[2]); if sub~='coverage' and sub~='catalogcoverage' and sub~='verifycatalog' then return false; end
    local s=M.snapshot(true); HC.msg(string.format('Catalog coverage: %.1f%% verification score | %d verified | %d incomplete | %d unverified | %d quarantined native ID(s).',tonumber(s.scores and s.scores.overall) or 0,s.totals.verified or 0,s.totals.incomplete or 0,s.totals.unverified or 0,s.totals.quarantined or 0)); return true;
end

function M.init(ctx) HC=ctx; end
return M;
