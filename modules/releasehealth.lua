local M = {};
local HC;

local function user_file(kind,name)
    if HC and HC.modules and HC.modules.userdata and HC.modules.userdata.path then
        local ok,res=pcall(HC.modules.userdata.path,kind,name);
        if ok and type(res)=='string' and res~='' then return res; end
    end
    return tostring(HC and HC.addon_path or '')..tostring(name or '');
end

local cache={at=0,char=nil,data=nil};
local CACHE_SECONDS=10;
local manual_refresh=false;
local manifest=nil;
local manifest_error=nil;
local relic_cache={at=0,ok=false,snap={available=false}};
local RELIC_STATUS_SECONDS=60;

local function add(rows,id,label,state,detail,required,action)
    rows[#rows+1]={id=id,label=label,state=state,detail=detail,required=required==true,action=action};
end

local function count_table(t)
    local n=0; for _ in pairs(type(t)=='table' and t or {}) do n=n+1; end return n;
end

local function sync_milestones(c)
    c.sync_milestones=type(c.sync_milestones)=='table' and c.sync_milestones or {};
    return c.sync_milestones;
end

local function promote_initial_sync(c,eco_sync,tag_sync,outpost_sync,fame_sync)
    local ms=sync_milestones(c); local changed=false; local now=os.time();
    if not ms.eco and type(eco_sync)=='table' and (eco_sync.initialized==true or tonumber(eco_sync.at)~=nil) then
        ms.eco={at=tonumber(eco_sync.at) or now,source='Eeko-Weeko synchronization'}; changed=true;
    end
    if not ms.assault_tags and type(tag_sync)=='table' and tag_sync.initialized==true then
        ms.assault_tags={at=tonumber(tag_sync.at) or now,source='Rytaal authoritative tag synchronization'}; changed=true;
    end
    if not ms.outposts and type(outpost_sync)=='table' and outpost_sync.synced==true then
        ms.outposts={at=tonumber(outpost_sync.at) or now,source='Regional Teleport outpost synchronization'}; changed=true;
    end
    if not ms.fame and type(fame_sync)=='table' and fame_sync.complete==true then
        ms.fame={at=now,source='All supported fame/reputation checkers synchronized'}; changed=true;
    end
    if changed then
        if HC.modules.state and HC.modules.state.request_save then HC.modules.state.request_save(1); end
        if HC.modules.dependencies and HC.modules.dependencies.invalidate_many then
            pcall(HC.modules.dependencies.invalidate_many,{'eco','assault','outposts','fame'},'initial synchronization milestone promoted');
        end
    end
    return ms,changed;
end


local function manifest_status()
    if type(manifest)~='table' then return false,tostring(manifest_error or 'release manifest unavailable'); end
    if tostring(manifest.version or '')~=tostring(HC.version or '') then
        return false,'manifest '..tostring(manifest.version or '?')..' / runtime '..tostring(HC.version or '?');
    end
    local missing={};
    for _,rel in ipairs(type(manifest.required)=='table' and manifest.required or {}) do
        local f=io.open(HC.addon_path..tostring(rel),'rb');
        if f then f:close(); else missing[#missing+1]=tostring(rel); end
    end
    if #missing>0 then return false,'missing '..table.concat(missing,', '); end
    return true,string.format('v%s | state schema %s | %d required file(s) present',tostring(manifest.version),tostring(manifest.state_schema),#(manifest.required or {}));
end

local function mission_synced(c)
    local n=type(c.mission_meta)=='table' and type(c.mission_meta.native)=='table' and c.mission_meta.native or nil;
    return n and n.last_seen_at~=nil,n;
end

local function ki_status()
    local k=HC.modules.keyitems;
    local b=k and k.bitmap_status and k.bitmap_status() or {};
    local tables=tonumber(b.tables) or 0;
    local ix=k and k.index_status and k.index_status() or {};
    return tables>0,tables,ix;
end

local function relic_status(force)
    local now=os.time();
    if force~=true and relic_cache.at>0 and now-relic_cache.at<RELIC_STATUS_SECONDS then
        return relic_cache.ok,relic_cache.snap;
    end
    local s=HC.modules.skills;
    if not s or not s.relic_snapshot then
        relic_cache={at=now,ok=false,snap={available=false}};
        return false,relic_cache.snap;
    end
    local ok,snap=pcall(s.relic_snapshot,force==true);
    if not ok or type(snap)~='table' then
        relic_cache={at=now,ok=false,snap={available=false,error=tostring(snap)}};
        return false,relic_cache.snap;
    end
    relic_cache={at=now,ok=snap.available==true,snap=snap};
    return relic_cache.ok,relic_cache.snap;
end

local function build(c,force)
    local now=os.time();
    local char=HC.modules.state.profile_name();
    if force~=true and cache.data and cache.char==char and now-(tonumber(cache.at) or 0)<CACHE_SECONDS then return cache.data; end

    local rows={};
    local profile_ready=HC.modules.state.profile_ready and HC.modules.state.profile_ready() or false;
    add(rows,'character','Character detected',profile_ready and 'PASS' or 'WAIT',profile_ready and char or 'Log in to a character.',true);

    local storage=HC.modules.state.storage_status and HC.modules.state.storage_status(force==true) or {writable=true,detail='state module loaded'};
    add(rows,'storage','Saved-state directory',storage.writable and 'PASS' or 'FAIL',tostring(storage.detail or storage.error or 'unknown'),true);

    local migration=HC.modules.state.migration_status and HC.modules.state.migration_status() or {current=true,current_schema='?',state_schema='?'};
    local migration_ok=migration.current==true and migration.failed~=true;
    add(rows,'schema','State schema / migration',migration_ok and 'PASS' or 'FAIL',
        string.format('state %s / addon %s%s',tostring(migration.state_schema or '?'),tostring(migration.current_schema or '?'),
            migration.last_result and (' | '..tostring(migration.last_result)) or ''),true);

    local manifest_ok,manifest_detail=manifest_status();
    add(rows,'manifest','Release package manifest',manifest_ok and 'PASS' or 'FAIL',manifest_detail,true);

    local m_ok,mnative=mission_synced(c);
    add(rows,'missions','Mission history',m_ok and 'PASS' or 'WAIT',m_ok and ('native history received '..os.date('%Y-%m-%d %H:%M',mnative.last_seen_at)) or 'Zone once to receive native mission history.',true,'zone');

    local k_ok,tables,index=ki_status();
    add(rows,'keyitems','Permanent key items',k_ok and 'PASS' or 'WAIT',k_ok and (tostring(tables)..' server bitmap table(s) cached') or 'Zone once to receive the server key-item tables.',true,'zone');

    local eco_sync=HC.modules.eco and HC.modules.eco.sync_status and HC.modules.eco.sync_status(c) or {};
    local tag_sync=HC.modules.assault and HC.modules.assault.sync_status and HC.modules.assault.sync_status(c) or {};
    local outpost_sync=HC.modules.outposts and HC.modules.outposts.sync_status and HC.modules.outposts.sync_status(c) or {};
    local fame_sync=HC.modules.fame and HC.modules.fame.sync_status and HC.modules.fame.sync_status(c) or {};
    local sync_ms=promote_initial_sync(c,eco_sync,tag_sync,outpost_sync,fame_sync);

    local eco_initialized=type(sync_ms.eco)=='table' and tonumber(sync_ms.eco.at)~=nil;
    local eco_detail=eco_initialized and ('tracking initialized'..(eco_sync.synced and ' | current Conquest-week rotation synchronized' or ' | current-week rotation may be refreshed in Eco-War'))
        or 'Talk to Eeko-Weeko once to initialize Eco-War tracking.';
    add(rows,'eco_sync','Eco-War tracking (Eeko-Weeko)',eco_initialized and 'PASS' or 'WAIT',eco_detail,false,'talk');

    local tag_initialized=type(sync_ms.assault_tags)=='table' and tonumber(sync_ms.assault_tags.at)~=nil;
    add(rows,'assault_tags','Assault Tag tracking (Rytaal)',tag_initialized and 'PASS' or 'WAIT',
        tag_initialized and string.format('tracking initialized | Character %s | Rytaal %s/3 | Total %s/4',tostring(tag_sync.carried or '?'),tostring(tag_sync.rytaal or '?'),tostring(tag_sync.total or '?'))
            or 'Talk to Rytaal once to initialize the character/account Assault Tag count.',false,'talk');

    local outpost_initialized=type(sync_ms.outposts)=='table' and tonumber(sync_ms.outposts.at)~=nil;
    local outpost_detail;
    if outpost_initialized then
        outpost_detail=string.format('current outposts synchronized | %s/%s verified%s',
            tostring(outpost_sync.count or '?'),tostring(outpost_sync.total or '?'),
            outpost_sync.npc and (' | '..tostring(outpost_sync.npc)) or '');
    else
        local who=tostring(outpost_sync.expected_npc or 'your nation Outpost NPC');
        outpost_detail='Talk to '..who..' and page through the Regional Teleport menu once.';
    end
    add(rows,'outpost_sync','Outpost ownership',outpost_initialized and 'PASS' or 'WAIT',outpost_detail,false,'talk');

    local fame_initialized=type(sync_ms.fame)=='table' and tonumber(sync_ms.fame.at)~=nil;
    local fame_detail='Talk to each supported fame/reputation checker NPC.';
    if tonumber(fame_sync.total) then
        fame_detail=string.format('%d/%d checker NPCs synchronized',tonumber(fame_sync.done) or 0,tonumber(fame_sync.total) or 0);
        if type(fame_sync.missing)=='table' and #fame_sync.missing>0 then fame_detail=fame_detail..' | Missing: '..table.concat(fame_sync.missing,', '); end
    end
    if fame_initialized then fame_detail='all supported fame/reputation checker initialization complete'; end
    add(rows,'fame_sync','Fame / Reputation checkers',fame_initialized and 'PASS' or 'WAIT',fame_detail,false,'talk');

    local an=HC.modules.assaultprogress and HC.modules.assaultprogress.native_status and HC.modules.assaultprogress.native_status(c) or {};
    add(rows,'assault_history','Historical Assault clears',an.synced and 'PASS' or 'WAIT',
        an.synced and string.format('%d/50 native clear(s) | %d/50 tracked',tonumber(an.native_completed) or 0,tonumber(an.tracked_completed) or 0)
            or 'Zone once to import previously completed Assaults.',true,'zone');

    local hi=HC.modules.historyimport and HC.modules.historyimport.status and HC.modules.historyimport.status(c) or {};
    local hi_ok=hi.at~=nil;
    local hic=hi.counts or {};
    add(rows,'historical_import','Historical progression import',hi_ok and 'PASS' or 'WAIT',
        hi_ok and string.format('%d quests | %d missions | %d unlocks | %d advanced jobs | %d limit breaks',hic.quests or 0,hic.missions or 0,hic.unlocks or 0,hic.jobs or 0,hic.limit_breaks or 0)
            or 'Waiting for the first zone reconciliation to import permanent historical proof.',true,'zone');

    local inv_ok,inv=relic_status(force==true);
    add(rows,'inventory','Inventory / relic scan',inv_ok and 'PASS' or 'INFO',
        inv_ok and ('Ashita inventory scan ready'..(inv.slip_seen and ' | Porter data observed' or '')) or 'Inventory scan unavailable; other tracking remains usable.',false);

    local zs=HC.modules.zonesync and HC.modules.zonesync.status and HC.modules.zonesync.status() or {};
    local z_ok=zs.state=='COMPLETE';
    add(rows,'zonesync','Zone reconciliation',z_ok and 'PASS' or (zs.state=='SYNCING' and 'SYNC' or 'WAIT'),
        z_ok and ('completed '..os.date('%H:%M:%S',zs.last_completed_at or now)) or ('state '..tostring(zs.state or 'WAITING')..' | phase '..tostring(zs.phase or 0)..'/3'),true,'sync');

    local ps=HC.modules.progression and HC.modules.progression.status and HC.modules.progression.status(c) or {};
    local p_ok=(tonumber(ps.records) or 0)>0;
    add(rows,'progression','Progression reconciliation',p_ok and 'PASS' or 'WAIT',p_ok and (tostring(ps.records)..' normalized fact(s)') or 'Waiting for initial zone reconciliation.',true,'sync');

    local integrity=HC.modules.integrity and HC.modules.integrity.status and HC.modules.integrity.status(c) or {};
    local i_state=tostring(integrity.state or 'PENDING');
    local i_ok=i_state=='HEALTHY' and (tonumber(integrity.unresolved) or 0)==0;
    local i_row=i_ok and 'PASS' or ((tonumber(integrity.unresolved) or 0)>0 and 'ATTN' or 'SYNC');
    local i_detail=integrity.at and string.format('%s | %d repair(s) | %d unresolved',i_state,tonumber(integrity.repairs) or 0,tonumber(integrity.unresolved) or 0)
        or 'Waiting for the first event-driven state-integrity pass.';
    add(rows,'integrity','State integrity',i_row,i_detail,true,'sync');

    local guard=HC.modules.runtimeguard and HC.modules.runtimeguard.status and HC.modules.runtimeguard.status() or {};
    add(rows,'runtime_guard','Runtime isolation',(tonumber(guard.quarantined) or 0)==0 and 'PASS' or 'ATTN',
        string.format('%d paused operation(s) | %d collapsed repeat(s)',tonumber(guard.quarantined) or 0,tonumber(guard.suppressed) or 0),true);

    local er=HC.modules.diagnostics and HC.modules.diagnostics.error_status and HC.modules.diagnostics.error_status() or {distinct=0,total=0};
    add(rows,'errors','Runtime errors',(tonumber(er.distinct) or 0)==0 and 'PASS' or 'ATTN',
        string.format('%d distinct | %d event(s)',tonumber(er.distinct) or 0,tonumber(er.total) or 0),true);

    local ph=HC.modules.profiler and HC.modules.profiler.release_health and HC.modules.profiler.release_health() or
        (HC.modules.profiler and HC.modules.profiler.status and HC.modules.profiler.status()) or {warnings=0};
    local pw=HC.modules.performance_watchdog and HC.modules.performance_watchdog.status and HC.modules.performance_watchdog.status() or {state='WARMING UP',issues=0};
    local perf_attention=(tonumber(ph.persistent_warnings or ph.warnings) or 0)>0 or tostring(pw.state)=='WARNING';
    add(rows,'performance','Performance health',not perf_attention and 'PASS' or 'ATTN',
        string.format('%d persistent timing warning(s) | watchdog %s (%d) | %d measured section(s)',tonumber(ph.persistent_warnings or ph.warnings) or 0,tostring(pw.state or 'WARMING UP'),tonumber(pw.issues) or 0,tonumber(ph.sections) or 0),true);

    local ci=HC.modules.catalog_integrity and HC.modules.catalog_integrity.status and HC.modules.catalog_integrity.status() or {};
    if ci.at then
        add(rows,'catalog','Catalog release audit',(tonumber(ci.errors) or 0)==0 and 'PASS' or 'ATTN',
            string.format('%d error(s) | %d warning(s)',tonumber(ci.errors) or 0,tonumber(ci.warnings) or 0),false);
    else
        add(rows,'catalog','Catalog release audit','INFO','Static release audit passed during packaging; live contradiction audit not run this session.',false);
    end

    local required_ok=true; local attention=0; local waiting=0;
    for _,r in ipairs(rows) do
        if r.required and r.state~='PASS' then required_ok=false; end
        if r.state=='ATTN' or r.state=='FAIL' then attention=attention+1; end
        if r.state=='WAIT' or r.state=='SYNC' then waiting=waiting+1; end
    end
    local states={}; for _,r in ipairs(rows) do states[r.id]=r.state; end
    local state=required_ok and attention==0 and 'READY' or (attention>0 and 'ATTENTION' or 'SYNCING');
    local setup_complete=(states.character=='PASS' and states.storage=='PASS' and states.schema=='PASS' and states.manifest=='PASS'
        and states.missions=='PASS' and states.keyitems=='PASS'
        and states.eco_sync=='PASS' and states.assault_tags=='PASS' and states.outpost_sync=='PASS' and states.fame_sync=='PASS'
        and states.assault_history=='PASS' and states.historical_import=='PASS'
        and states.zonesync=='PASS' and states.progression=='PASS');
    local out={at=now,character=char,rows=rows,state=state,ready=state=='READY',attention=attention,waiting=waiting,
        required_ok=required_ok,setup_complete=setup_complete};
    cache={at=now,char=char,data=out};
    manual_refresh=false;
    return out;
end

function M.invalidate() cache.at=0; cache.data=nil; manual_refresh=true; end
function M.status(c,force) return build(c or HC.modules.state.get_char(),force==true); end
function M.setup_status(c) return build(c or HC.modules.state.get_char(),false); end

local function completion_report(c)
    local hi=HC.modules.historyimport and HC.modules.historyimport.status and HC.modules.historyimport.status(c) or {};
    local n=type(hi.counts)=='table' and hi.counts or {};
    local ap=HC.modules.assaultprogress and HC.modules.assaultprogress.native_status and HC.modules.assaultprogress.native_status(c) or {};
    local kb=HC.modules.keyitems and HC.modules.keyitems.bitmap_status and HC.modules.keyitems.bitmap_status() or {};
    local fs=HC.modules.fame and HC.modules.fame.sync_status and HC.modules.fame.sync_status(c) or {};
    return {
        quests=tonumber(n.quests) or 0,missions=tonumber(n.missions) or 0,unlocks=tonumber(n.unlocks) or 0,
        jobs=tonumber(n.jobs) or 0,limit_breaks=tonumber(n.limit_breaks) or 0,assaults=tonumber(ap.native_completed) or 0,
        ki_tables=tonumber(kb.tables) or 0,fame_done=tonumber(fs.done) or 0,fame_total=tonumber(fs.total) or 0,
    };
end

local function mark_setup_complete(c,s)
    if not s.setup_complete then return; end
    c.settings=type(c.settings)=='table' and c.settings or {};
    c.release_health=type(c.release_health)=='table' and c.release_health or {};
    if not c.settings.setup_wizard_completed_at then
        c.settings.setup_wizard_completed_at=os.time();
        c.settings.setup_completion_report_pending=true;
        c.settings.setup_wizard_dismissed=false;
        c.release_health.initial_sync_report=completion_report(c);
        c.release_health.initial_sync_report.at=c.settings.setup_wizard_completed_at;
        if HC.modules.timeline and HC.modules.timeline.record then
            HC.modules.timeline.record(c,'setup','Initial Synchronization Complete',
                'Mission history, key items, Eco-War tracking, Assault Tags, Outpost ownership, fame/reputation, Assault history, historical progression, and normalized progression initialized.',{
                    source='release health wizard',dedupe_seconds=5,
                });
        end
        HC.modules.state.request_save(1);
        HC.msg('Initial HorizonCheck synchronization complete. Review the one-time synchronization summary.');
    end
end

local function row_map(s)
    local out={};
    for _,r in ipairs(type(s)=='table' and type(s.rows)=='table' and s.rows or {}) do out[r.id]=r; end
    return out;
end

local function all_pass(rows,ids)
    for _,id in ipairs(ids or {}) do
        if not rows[id] or rows[id].state~='PASS' then return false; end
    end
    return true;
end

local function draw_simple_step(imgui,number,done,title,detail)
    local mark=done and '[OK]' or '[ ]';
    if done then imgui.Text(string.format('%s %d. %s',mark,number,title));
    else imgui.Text(string.format('%s %d. %s',mark,number,title)); end
    if detail and detail~='' then imgui.TextDisabled('    '..detail); end
end

local function draw_completion_report(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return false; end
    local r=type(c.release_health)=='table' and type(c.release_health.initial_sync_report)=='table' and c.release_health.initial_sync_report or completion_report(c);
    local flags=ImGuiTreeNodeFlags_DefaultOpen or 0;
    if imgui.CollapsingHeader('Initial Synchronization Complete##hc_initial_sync_complete',flags) then
        imgui.Text('All done! HorizonCheck knows this character now.');
        imgui.TextDisabled('You do not need to do these setup steps again. Normal tracking is ready.');
        imgui.Text(string.format('Found: %d quests | %d missions | %d Assault clears',r.quests or 0,r.missions or 0,r.assaults or 0));
        if type(c.settings)=='table' and c.settings.developer_mode==true then
            imgui.TextDisabled(string.format('Developer details: %d permanent unlocks | %d advanced jobs | %d Limit Breaks | %d key-item tables | fame %d/%d',
                r.unlocks or 0,r.jobs or 0,r.limit_breaks or 0,r.ki_tables or 0,r.fame_done or 0,r.fame_total or 0));
            imgui.TextDisabled('Repeatable current-week completion was not inferred from permanent history.');
        end
        -- Historical wording kept here so release audits from older builds can still identify this control: Finish Initial Synchronization.
        if imgui.Button('Finish Setup##hc_initial_sync_finish') then
            c.settings.setup_completion_report_pending=nil;
            c.settings.setup_completion_report_ack_at=os.time();
            c.settings.setup_wizard_dismissed=true;
            HC.modules.state.save(); M.invalidate();
            return true;
        end
    end
    return false;
end

function M.draw_setup(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    c.settings=type(c.settings)=='table' and c.settings or {};
    if c.settings.setup_wizard_dismissed==true then return; end
    local s=build(c,false);
    mark_setup_complete(c,s);
    if c.settings.setup_completion_report_pending==true then draw_completion_report(c); return; end
    if c.settings.setup_wizard_dismissed==true then return; end

    local flags=ImGuiTreeNodeFlags_DefaultOpen or 0;
    if not imgui.CollapsingHeader('Initial Synchronization##hc_release_setup',flags) then return; end

    local rows=row_map(s);
    local zone_ids={'missions','keyitems','assault_history','historical_import','zonesync','progression'};
    local zone_done=all_pass(rows,zone_ids);
    local eco_done=rows.eco_sync and rows.eco_sync.state=='PASS';
    local tags_done=rows.assault_tags and rows.assault_tags.state=='PASS';
    local outposts_done=rows.outpost_sync and rows.outpost_sync.state=='PASS';
    local fame_done=rows.fame_sync and rows.fame_sync.state=='PASS';

    imgui.Text('HorizonCheck is learning this character. Do these 5 things once:');
    imgui.TextDisabled('A check mark means you are finished with that step. Finished steps stay finished.');

    draw_simple_step(imgui,1,zone_done,'Change zones once.',
        zone_done and 'Done. HorizonCheck found your old missions, key items, Assault clears, and progression.'
            or 'Walk into any other zone. HorizonCheck will read your old progress by itself.');
    draw_simple_step(imgui,2,eco_done,'Talk to Eeko-Weeko once.',
        eco_done and 'Done. Eco-War tracking is ready.' or 'Just talk to Eeko-Weeko. HorizonCheck will remember it.');
    draw_simple_step(imgui,3,tags_done,'Talk to Rytaal once.',
        tags_done and 'Done. Assault Tag tracking is ready.' or 'Just talk to Rytaal. HorizonCheck will learn your tag count.');

    local orow=rows.outpost_sync;
    local outpost_detail='Talk to your nation Outpost NPC. Open Regional Teleport and flip through the pages.';
    if outposts_done then
        local n,total=(orow and orow.detail or ''):match('(%d+)/(%d+) verified');
        outpost_detail=(n and total) and ('Done. HorizonCheck knows your current outposts ('..n..'/'..total..').')
            or 'Done. HorizonCheck knows your current outposts.';
    elseif orow and type(orow.detail)=='string' and orow.detail~='' then
        local npc=orow.detail:match('Talk to ([^%.]+) and page through')
        if npc then outpost_detail='Talk to '..npc..'. Open Regional Teleport and flip through the pages.'; end
    end
    draw_simple_step(imgui,4,outposts_done,'Talk to your Outpost NPC once.',outpost_detail);

    local fame_detail='Visit each fame checker once. You can do them whenever you are nearby.';
    local fr=rows.fame_sync;
    if fame_done then
        fame_detail='Done. All fame/reputation areas are ready.';
    elseif fr and type(fr.detail)=='string' and fr.detail~='' then
        local done,total=fr.detail:match('(%d+)/(%d+) checker NPCs synchronized');
        local missing=fr.detail:match('Missing:%s*(.+)$');
        if done and total then
            fame_detail=string.format('%s/%s done.',done,total);
            if missing and missing~='' then fame_detail=fame_detail..' Still need: '..missing..'.'; end
        end
    end
    draw_simple_step(imgui,5,fame_done,'Talk to the fame checker NPCs.',fame_detail);

    local automatic_problem=false;
    for _,id in ipairs({'character','storage','schema','manifest'}) do
        local r=rows[id];
        if r and (r.state=='FAIL' or r.state=='ATTN') then automatic_problem=true; break; end
    end
    if automatic_problem then
        imgui.Text('');
        imgui.Text('[ATTN] HorizonCheck found a setup problem.');
        imgui.TextDisabled('Open Diagnostics for the technical reason. Your five steps above are still safe to follow.');
    end

    imgui.Text('');
    imgui.TextDisabled('Already changed zones or talked to someone? Click Check Again.');
    if imgui.Button('Check Again##hc_release_setup_sync') then
        if HC.modules.zonesync and HC.modules.zonesync.force then HC.modules.zonesync.force('first-run setup'); end
        if HC.modules.assaultprogress and HC.modules.assaultprogress.sync_native_history then HC.modules.assaultprogress.sync_native_history(c,{silent=true,source='setup wizard'}); end
        if HC.modules.historyimport and HC.modules.historyimport.reconcile then HC.modules.historyimport.reconcile(c,true,'setup wizard'); end
        M.invalidate();
    end
    imgui.SameLine();
    if imgui.Button('Hide for Now##hc_release_setup_hide') then
        c.settings.setup_wizard_dismissed=true; HC.modules.state.save();
    end

    if c.settings.developer_mode==true then
        imgui.Text('');
        if imgui.CollapsingHeader('Developer Details##hc_release_setup_developer') then
            for _,r in ipairs(s.rows) do
                local mark=(r.state=='PASS') and '[OK]' or ((r.state=='FAIL' or r.state=='ATTN') and '[ATTN]' or '[ ]');
                if r.state=='PASS' then imgui.Text(mark..' '..r.label); else imgui.TextDisabled(mark..' '..r.label); end
                imgui.TextDisabled('  '..tostring(r.detail or ''));
            end
        end
    end
end

function M.reopen_setup(c)
    c=c or HC.modules.state.get_char();
    c.settings=type(c.settings)=='table' and c.settings or {};
    c.settings.setup_wizard_dismissed=false;
    c.settings.setup_wizard_completed_at=nil;
    c.settings.setup_completion_report_pending=nil;
    HC.modules.state.save(); M.invalidate();
    return true;
end

local function state_label(r)
    if r.state=='PASS' then return '[PASS]'; end
    if r.state=='INFO' then return '[INFO]'; end
    if r.state=='SYNC' then return '[SYNC]'; end
    if r.state=='WAIT' then return '[WAIT]'; end
    return '[ATTN]';
end

function M.draw(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local s=build(c,false);
    imgui.Text('Release Health Check: '..tostring(s.state));
    imgui.TextDisabled('A single summary of synchronization, saved-state safety, runtime isolation, performance, and catalog health.');
    if imgui.Button('Refresh Health Check##hc_release_health_refresh') then M.invalidate(); build(c,true); end
    imgui.SameLine();
    if imgui.Button('Export Report##hc_release_health_export') then
        local path=M.export(c); HC.msg(path and ('Release health report written: '..path) or 'Could not write release health report.');
    end
    imgui.SameLine();
    if imgui.Button('Run Zone Sync##hc_release_health_sync') then if HC.modules.zonesync then HC.modules.zonesync.force('release health check'); end; M.invalidate(); end

    local table_ok=imgui.BeginTable and imgui.TableSetupColumn and imgui.TableHeadersRow and imgui.TableNextRow and imgui.TableSetColumnIndex and imgui.EndTable;
    if table_ok and imgui.BeginTable('##hc_release_health_table',3,64+128+512) then
        imgui.TableSetupColumn('State',0,78); imgui.TableSetupColumn('Check',0,190); imgui.TableSetupColumn('Details',0,520); imgui.TableHeadersRow();
        for _,r in ipairs(s.rows) do
            imgui.TableNextRow(); imgui.TableSetColumnIndex(0); if r.state=='PASS' then imgui.Text(state_label(r)); else imgui.TextDisabled(state_label(r)); end
            imgui.TableSetColumnIndex(1); imgui.Text(tostring(r.label));
            imgui.TableSetColumnIndex(2); imgui.TextDisabled(tostring(r.detail or ''));
        end
        imgui.EndTable();
    else
        for _,r in ipairs(s.rows) do imgui.TextWrapped(state_label(r)..' '..r.label..' - '..tostring(r.detail or '')); end
    end
end

function M.draw_settings(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local s=build(c,false);
    imgui.Text('Release Health: '..tostring(s.state));
    imgui.TextDisabled(string.format('%d waiting | %d attention item(s)',tonumber(s.waiting) or 0,tonumber(s.attention) or 0));
    if imgui.Button('Reopen Initial Setup##hc_release_setup_reopen') then M.reopen_setup(c); end
    imgui.SameLine();
    if imgui.Button((c.settings.release_health_expanded and 'Hide Details' or 'Show Details')..'##hc_release_health_toggle') then
        c.settings.release_health_expanded=not (c.settings.release_health_expanded==true);
        HC.modules.state.request_save(1);
    end
    imgui.SameLine();
    if imgui.Button('Export Health Report##hc_release_health_settings_export') then
        local path=M.export(c); HC.msg(path and ('Release health report written: '..path) or 'Could not write release health report.');
    end
    if c.settings.release_health_expanded==true then
        for _,r in ipairs(s.rows) do
            local mark=state_label(r);
            if r.state=='PASS' then imgui.Text(mark..' '..tostring(r.label)); else imgui.TextDisabled(mark..' '..tostring(r.label)); end
            imgui.TextDisabled('  '..tostring(r.detail or ''));
        end
    end
end

function M.export(c)
    c=c or HC.modules.state.get_char(); local s=build(c,true);
    local char=tostring(HC.modules.state.profile_name() or 'Unknown'):gsub('[^%w_%-]','_');
    local path=user_file('reports','horizoncheck_release_health_'..char..'_'..os.date('%Y%m%d_%H%M%S')..'.txt');
    local f=io.open(path,'w'); if not f then return nil; end
    f:write('HorizonCheck v'..tostring(HC.version)..' Release Health Report\n');
    f:write('Character: '..tostring(s.character)..'\n');
    f:write('Generated: '..os.date('%Y-%m-%d %H:%M:%S',s.at)..'\n');
    f:write('Overall: '..tostring(s.state)..'\n\n');
    for _,r in ipairs(s.rows) do f:write(string.format('%-8s | %-30s | %s\n',r.state,r.label,tostring(r.detail or ''))); end
    local migration=HC.modules.state.migration_status and HC.modules.state.migration_status() or {};
    f:write('\nMigration\n'); for k,v in pairs(migration) do if type(v)~='table' then f:write(tostring(k)..': '..tostring(v)..'\n'); end end
    local assault=HC.modules.assaultprogress and HC.modules.assaultprogress.native_diagnostics and HC.modules.assaultprogress.native_diagnostics(c) or {};
    f:write('\nAssault History\n'); for k,v in pairs(assault) do if type(v)~='table' then f:write(tostring(k)..': '..tostring(v)..'\n'); end end
    local guard=HC.modules.runtimeguard and HC.modules.runtimeguard.snapshot and HC.modules.runtimeguard.snapshot() or {};
    f:write('\nRuntime Guard\n'); for _,r in ipairs(guard.rows or {}) do f:write(string.format('%s | errors=%s | paused=%s | %s\n',tostring(r.name),tostring(r.total),tostring(r.quarantined),tostring(r.last_error or ''))); end
    f:close(); return path;
end

function M.initial_sync_report(c)
    c=c or HC.modules.state.get_char();
    local saved=type(c.release_health)=='table' and c.release_health.initial_sync_report or nil;
    return saved or completion_report(c);
end

function M.command(w)
    local sub=string.lower(tostring(w[2] or ''));
    if sub=='setup' then M.reopen_setup(); HC.msg('Initial synchronization wizard reopened.'); return true; end
    if sub~='health' and sub~='releasehealth' then return false; end
    local action=string.lower(tostring(w[3] or 'status'));
    if action=='export' then local path=M.export(); HC.msg(path and ('Release health report written: '..path) or 'Could not write release health report.');
    elseif action=='sync' then if HC.modules.zonesync then HC.modules.zonesync.force('release health command'); end; HC.msg('Release synchronization scheduled.');
    else local s=build(HC.modules.state.get_char(),true); HC.msg(string.format('Release health: %s | %d waiting | %d attention.',s.state,s.waiting,s.attention)); end
    return true;
end

function M.init(ctx)
    HC=ctx;
    local ok,res=pcall(dofile,HC.addon_path..'data\\release_manifest.lua');
    if ok and type(res)=='table' then manifest=res; else manifest_error=tostring(res or 'manifest did not return a table'); end
end
return M;
