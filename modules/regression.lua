local M = {};
local HC;
local last={at=nil,passed=0,failed=0,rows={}};

local function add(name,ok,detail)
    last.rows[#last.rows+1]={name=name,ok=ok==true,detail=tostring(detail or '')};
    if ok then last.passed=last.passed+1; else last.failed=last.failed+1; end
end

local function winner(rows)
    local ev=HC and HC.modules and HC.modules.evidence or nil;
    if not ev or not ev.resolve_rows then return nil; end
    return ev.resolve_rows(rows);
end

function M.run(announce)
    last={at=os.time(),passed=0,failed=0,rows={}};
    local ev=HC and HC.modules and HC.modules.evidence or nil;
    if not ev then add('Evidence module available',false,'module missing'); return last; end

    local r=winner({});
    add('No evidence stays UNKNOWN',r and r.value==nil and r.state=='UNKNOWN',r and r.state or 'nil');

    r=winner({
        {value=false,source='Ashita HasKeyItem',confidence='LIVE',rank=60,at=100,seq=1},
        {value=true,source='0x055 bitmap',confidence='VERIFIED',rank=90,at=90,seq=2},
    });
    add('Authoritative bitmap TRUE beats API FALSE',r and r.value==true and r.source=='0x055 bitmap',r and (r.state..' via '..r.source) or 'nil');

    r=winner({
        {value=true,source='saved packet state',confidence='CONFIRMED',rank=75,at=100,seq=1},
        {value=false,source='0x055 bitmap',confidence='VERIFIED',rank=90,at=110,seq=2},
    });
    add('Fresh authoritative FALSE can clear consumable held state',r and r.value==false and r.source=='0x055 bitmap',r and (r.state..' via '..r.source) or 'nil');

    r=winner({
        {value=false,source='saved packet state',confidence='CONFIRMED',rank=50,at=100,seq=1},
        {value=true,source='Ashita HasKeyItem',confidence='LIVE',rank=60,at=110,seq=2},
    });
    add('Live TRUE can supersede stale saved consumable FALSE',r and r.value==true and r.source=='Ashita HasKeyItem',r and (r.state..' via '..r.source) or 'nil');

    r=winner({
        {value=true,source='permanent proof',confidence='VERIFIED',rank=100,at=80,seq=1},
        {value=false,source='Ashita HasKeyItem',confidence='LIVE',rank=60,at=120,seq=2},
    });
    add('Permanent proof survives weaker API false-negative',r and r.value==true and r.source=='permanent proof',r and (r.state..' via '..r.source) or 'nil');

    r=winner({
        {value=true,source='0x055 bitmap',source_id='bitmap',confidence='VERIFIED',rank=90,at=100,seq=1},
        {value=false,source='0x055 bitmap',source_id='bitmap',confidence='VERIFIED',rank=90,at=120,seq=2},
    });
    add('Newer equal-rank observation wins',r and r.value==false,r and r.state or 'nil');

    r=winner({
        {value=nil,source='table not received',confidence='UNKNOWN',rank=0,at=200,seq=2},
        {value=true,source='saved confirmed state',confidence='CONFIRMED',rank=75,at=100,seq=1},
    });
    add('UNKNOWN never overwrites confirmed TRUE',r and r.value==true,r and r.state or 'nil');

    r=winner({
        {value=false,source='API',confidence='LIVE',rank=60,at=100,seq=1},
        {value=true,source='bitmap',confidence='VERIFIED',rank=90,at=101,seq=2},
    });
    add('Conflicting sources are surfaced',r and r.conflict==true,r and tostring(r.conflict) or 'nil');

    r=winner({{value=9,source='fame dialogue',confidence='VERIFIED',rank=90,at=100,seq=1}});
    add('Numeric facts are preserved',r and r.value==9 and r.state=='VALUE',r and (tostring(r.value)..'/'..tostring(r.state)) or 'nil');

    local ki=HC.modules and HC.modules.keyitems or nil;
    add('Key-item resolver integrated',ki and type(ki.ownership_name)=='function' and type(ki.evidence_key)=='function','ownership_name + evidence_key');

    local diag=HC.modules and HC.modules.diagnostics or nil;
    add('Detection Inspector integrated',diag and type(diag.draw_evidence_inspector)=='function','diagnostics.draw_evidence_inspector');

    local qg=HC.modules and HC.modules.questgraph or nil;
    add('Quest dependency graph integrated',qg and type(qg.trace)=='function' and type(qg.summary)=='function','questgraph.trace + summary');
    if qg and qg.analyze_nodes then
        local ga=qg.analyze_nodes({A={deps={'B'}},B={deps={}}});
        add('Dependency graph accepts valid chain',ga and ga.missing==0 and ga.cycles==0 and ga.self_edges==0,string.format('missing=%s cycles=%s self=%s',tostring(ga and ga.missing),tostring(ga and ga.cycles),tostring(ga and ga.self_edges)));
        ga=qg.analyze_nodes({A={deps={'B'}},B={deps={'A'}}});
        add('Dependency graph detects cycles',ga and (tonumber(ga.cycles) or 0)>0,tostring(ga and ga.cycles));
        ga=qg.analyze_nodes({A={deps={'MISSING'}}});
        add('Dependency graph detects missing targets',ga and ga.missing==1,tostring(ga and ga.missing));
    end

    local systems=HC.modules and HC.modules.systems or nil;
    add('System state engines integrated',systems and type(systems.snapshot)=='function' and type(systems.repeat_status)=='function','systems.snapshot + repeat_status');
    if systems and systems.repeat_status then
        local st=systems.repeat_status({}, {kind='weekly',completed=true,completion_at=nil,now=os.time()});
        add('System reset engine preserves unknown historical weekly completion',st=='UNKNOWN RESET',tostring(st));
        st=systems.repeat_status({}, {kind='daily',completed=false,completion_at=nil,now=os.time()});
        add('System reset engine marks clean daily repeat READY',st=='READY',tostring(st));
    end

    local ci=HC.modules and HC.modules.catalog_integrity or nil;
    add('Catalog integrity engine integrated',ci and type(ci.run)=='function' and type(ci.status)=='function','catalog_integrity.run + status');

    local canonical=HC.modules and HC.modules.canonical or nil;
    add('Canonical content registry integrated',canonical and type(canonical.native_policy)=='function' and type(canonical.snapshot)=='function','canonical.native_policy + snapshot');
    if canonical and canonical.native_policy then
        local policy,reason=canonical.native_policy(3,92);
        add('Unavailable HorizonXI quest blocks native ID',policy=='BLOCK',tostring(policy)..' | '..tostring(reason));
    end
    local quests=HC.modules and HC.modules.quests or nil;
    add('Raw native quest evidence accessor integrated',quests and type(quests.raw_native_state)=='function','quests.raw_native_state');
    local coverage=HC.modules and HC.modules.catalog_coverage or nil;
    add('Catalog coverage dashboard integrated',coverage and type(coverage.snapshot)=='function' and type(coverage.issues)=='function','catalog_coverage.snapshot + issues');
    local wizard=HC.modules and HC.modules.capturewizard or nil;
    add('Guided capture wizard integrated',wizard and type(wizard.start_quest)=='function' and type(wizard.stop)=='function','capturewizard.start_quest + stop');
    local healer=HC.modules and HC.modules.selfheal or nil;
    add('Self-healing contradiction engine integrated',healer and type(healer.scan)=='function' and type(healer.status)=='function','selfheal.scan + status');

    local planner=HC.modules and HC.modules.planner or nil;
    add('Planner module integrated',planner and type(planner.build)=='function' and type(planner.classify)=='function','planner.build + classify');
    if planner and planner.classify then
        add('Planner promotes capped work to DO NOW',planner.classify('READY',{capped=true})=='DO NOW',planner.classify('READY',{capped=true}));
        add('Planner promotes expiring Ready work to DO NOW',planner.classify('READY',{reset_remaining=300,urgent_within=3600})=='DO NOW',planner.classify('READY',{reset_remaining=300,urgent_within=3600}));
        add('Planner keeps normal actionable work READY',planner.classify('READY',{reset_remaining=7200,urgent_within=3600})=='READY',planner.classify('READY',{reset_remaining=7200,urgent_within=3600}));
        add('Planner keeps verification work in PREP',planner.classify('CHECK',{})=='PREP',planner.classify('CHECK',{}));
        add('Planner keeps hard blockers BLOCKED',planner.classify('LOCKED',{})=='LOCKED',planner.classify('LOCKED',{}));
    end

    if announce and HC then
        HC.msg(string.format('Regression suite: %d passed, %d failed.',last.passed,last.failed));
        for _,row in ipairs(last.rows) do
            if not row.ok then HC.msg('Regression FAIL: '..row.name..' - '..row.detail); end
        end
    end
    return last;
end

function M.status() return last; end

function M.draw()
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    if imgui.Button('Run Regression Suite##hc_regression_run') then M.run(true); end
    imgui.SameLine();
    if last.at then
        imgui.Text(string.format('%d passed / %d failed',last.passed,last.failed));
    else
        imgui.TextDisabled('Not run this session.');
    end
    if last.at then
        for _,row in ipairs(last.rows or {}) do
            if row.ok then imgui.TextDisabled('PASS - '..row.name);
            else imgui.Text('FAIL - '..row.name..' - '..row.detail); end
        end
    end
end

function M.command(w,raw)
    local sub=string.lower(w[2] or '');
    if sub=='regress' or sub=='regression' or sub=='tests' then M.run(true); return true; end
    return false;
end

function M.init(ctx) HC=ctx; end
return M;
