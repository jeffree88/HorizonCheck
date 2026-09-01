local M = {};
local HC;

local current_zone=nil;
local pending=nil;
local last_poll=0;
local last_status={state='WAITING',zone_id=nil,zone_name=nil,last_completed_at=nil,phase=0,reason='not initialized'};

local PHASE_DELAYS={1,3,6};

local function zone_id()
    local a=HC and HC.modules and HC.modules.automation or nil;
    if a and a.get_zone_id then local ok,v=pcall(a.get_zone_id); if ok then return tonumber(v); end end
    local z=nil;
    pcall(function()
        local mm=AshitaCore:GetMemoryManager();
        local party=mm and mm:GetParty() or nil;
        if party and party.GetMemberZone then z=tonumber(party:GetMemberZone(0)); end
    end);
    return z;
end

local function zone_name()
    local q=HC and HC.modules and HC.modules.quests or nil;
    if q and q.current_zone then local ok,v=pcall(q.current_zone); if ok and v then return tostring(v); end end
    return nil;
end

local function schedule(zid,reason)
    local now=os.time();
    pending={zone_id=zid,zone_name=zone_name(),started_at=now,phase=0,reason=tostring(reason or 'zone change')};
    if HC.modules.dependencies and HC.modules.dependencies.invalidate then
        pcall(HC.modules.dependencies.invalidate,'zone','zone change scheduled');
    end
    last_status.state='PENDING'; last_status.zone_id=zid; last_status.zone_name=pending.zone_name; last_status.phase=0; last_status.reason=pending.reason;
    local c=HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char() or nil;
    if c and HC.modules.timeline and HC.modules.timeline.record then
        HC.modules.timeline.record(c,'zone','Zone Change',tostring(pending.zone_name or ('Zone '..tostring(zid))),{
            source='zone watcher',zone_id=zid,zone_name=pending.zone_name,dedupe_seconds=1,
        });
    end
end

local function phase_one(c)
    if HC.modules.state and HC.modules.state.reconcile then pcall(HC.modules.state.reconcile,c); end
    if HC.modules.missions and HC.modules.missions.sync then pcall(HC.modules.missions.sync,c,{silent=true,deferred=true}); end
    if HC.modules.assaultprogress and HC.modules.assaultprogress.sync_native_history then
        pcall(HC.modules.assaultprogress.sync_native_history,c,{silent=true,source='zone snapshot cache'});
    end
    if HC.modules.dependencies and HC.modules.dependencies.invalidate_many then
        pcall(HC.modules.dependencies.invalidate_many,{'missions','assault_history'},'zone phase 1 authoritative history');
    end
end

local function phase_two(c)
    if HC.modules.keyitems and HC.modules.keyitems.publish_all_evidence then pcall(HC.modules.keyitems.publish_all_evidence); end
    if HC.modules.evidence and HC.modules.evidence.refresh then pcall(HC.modules.evidence.refresh); end
    if HC.modules.unlocks and HC.modules.unlocks.refresh then pcall(HC.modules.unlocks.refresh,c,true); end
    if HC.modules.seasonal and HC.modules.seasonal.reconcile then pcall(HC.modules.seasonal.reconcile,c,true); end
    if HC.modules.dependencies and HC.modules.dependencies.invalidate_many then
        pcall(HC.modules.dependencies.invalidate_many,{'keyitems','unlocks','seasonal'},'zone phase 2 authoritative ownership');
    end
    -- Canonical availability and catalog coverage are static catalog audits.
    -- They are now built lazily and cached instead of being force-rebuilt on
    -- every zone, which previously caused a noticeable main-thread hitch.
end

local function phase_three(c)
    if HC.modules.historyimport and HC.modules.historyimport.reconcile then pcall(HC.modules.historyimport.reconcile,c,true,'zone snapshot historical import'); end
    if HC.modules.systems and HC.modules.systems.snapshot then pcall(HC.modules.systems.snapshot,c,true); end
    local heal=nil;
    if HC.modules.selfheal and HC.modules.selfheal.scan then
        local ok,v=pcall(HC.modules.selfheal.scan,c,true,'zone snapshot'); if ok then heal=v; end
    end
    local ps=nil;
    if HC.modules.progression and HC.modules.progression.reconcile then
        local ok,v=pcall(HC.modules.progression.reconcile,c,{reason='zone snapshot'}); if ok then ps=v; end
    end
    if HC.modules.state and HC.modules.state.reconcile then pcall(HC.modules.state.reconcile,c); end
    if HC.modules.state and HC.modules.state.request_save then HC.modules.state.request_save(1); end
    if HC.modules.dependencies and HC.modules.dependencies.invalidate_many then
        pcall(HC.modules.dependencies.invalidate_many,{'history','progression','zone'},'zone phase 3 reconciliation complete');
    else
        if HC.modules.quests and HC.modules.quests.invalidate_runtime_cache then pcall(HC.modules.quests.invalidate_runtime_cache,false); end
        if HC.modules.planner and HC.modules.planner.invalidate then pcall(HC.modules.planner.invalidate); end
        if HC.modules.smartdashboard and HC.modules.smartdashboard.invalidate then pcall(HC.modules.smartdashboard.invalidate); end
        if HC.modules.weekly and HC.modules.weekly.invalidate_progress then pcall(HC.modules.weekly.invalidate_progress); end
        if HC.modules.releasehealth and HC.modules.releasehealth.invalidate then pcall(HC.modules.releasehealth.invalidate); end
    end

    local bitmap=HC.modules.keyitems and HC.modules.keyitems.bitmap_status and HC.modules.keyitems.bitmap_status() or {};
    local pcount=0; if ps and ps.records then for _ in pairs(ps.records) do pcount=pcount+1; end end
    local us=HC.modules.unlocks and HC.modules.unlocks.status and HC.modules.unlocks.status(c) or {};
    local av=HC.modules.availability and HC.modules.availability.status and HC.modules.availability.status() or {};
    local cs=HC.modules.canonical and HC.modules.canonical.status and HC.modules.canonical.status() or {};
    last_status.state='COMPLETE'; last_status.last_completed_at=os.time(); last_status.phase=3;
    last_status.bitmap_tables=tonumber(bitmap.tables) or 0; last_status.progression_records=pcount;
    last_status.unlocks=tonumber(us.total) or 0; last_status.future_content=tonumber(av.future) or 0;
    last_status.quarantined_native=tonumber(cs.quarantined) or 0; last_status.self_heal_repairs=tonumber(heal and heal.repairs) or 0;
    if HC.modules.timeline and HC.modules.timeline.record then
        HC.modules.timeline.record(c,'reconcile','Zone Snapshot Reconciled',
            string.format('%s | KI tables %d | progression facts %d',tostring(pending and pending.zone_name or last_status.zone_name or 'zone'),last_status.bitmap_tables,pcount),{
                source='zone reconciliation',zone_id=last_status.zone_id,zone_name=last_status.zone_name,dedupe_seconds=1,
            });
    end
end

local function run_due_phases()
    if not pending then return; end
    local elapsed=os.time()-(tonumber(pending.started_at) or os.time());
    local c=HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char() or nil; if not c then return; end
    while pending and pending.phase<3 and elapsed>=PHASE_DELAYS[pending.phase+1] do
        pending.phase=pending.phase+1; last_status.phase=pending.phase; last_status.state='SYNCING';
        local profiler=HC.modules.profiler;
        if pending.phase==1 then
            if profiler and profiler.measure then profiler.measure('zonesync.phase1',phase_one,c); else phase_one(c); end
        elseif pending.phase==2 then
            if profiler and profiler.measure then profiler.measure('zonesync.phase2',phase_two,c); else phase_two(c); end
        elseif pending.phase==3 then
            if profiler and profiler.measure then profiler.measure('zonesync.phase3',phase_three,c); else phase_three(c); end
            pending=nil;
        end
    end
end

function M.force(reason)
    local zid=zone_id(); if not zid then return false; end
    schedule(zid,reason or 'manual reconcile'); return true;
end

function M.poll()
    local now=os.time(); if now==last_poll then return; end; last_poll=now;
    if not HC.modules.state or not HC.modules.state.profile_ready or not HC.modules.state.profile_ready() then return; end
    local zid=zone_id(); if zid then
        if current_zone==nil then current_zone=zid; schedule(zid,'addon/login snapshot');
        elseif zid~=current_zone then current_zone=zid; schedule(zid,'zone change'); end
    end
    run_due_phases();
end

function M.status()
    local out={}; for k,v in pairs(last_status) do out[k]=v; end
    if pending then out.state='SYNCING'; out.phase=pending.phase; out.zone_id=pending.zone_id; out.zone_name=pending.zone_name; out.reason=pending.reason; out.started_at=pending.started_at; end
    return out;
end

function M.draw(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local s=M.status();
    imgui.Text('Automatic Zone Snapshot / Reconciliation');
    imgui.TextDisabled('ZONE -> native state arrives -> evidence refresh -> progression reconcile -> save.');
    imgui.Text('State: '..tostring(s.state or 'WAITING'));
    imgui.TextDisabled('Zone: '..tostring(s.zone_name or s.zone_id or 'unknown')..' | Phase '..tostring(s.phase or 0)..'/3');
    if s.last_completed_at then
        imgui.TextDisabled('Last complete: '..os.date('%H:%M:%S',s.last_completed_at)..' | KI tables '..tostring(s.bitmap_tables or 0)..' | progression facts '..tostring(s.progression_records or 0)..' | unlocks '..tostring(s.unlocks or 0)..' | native quarantine '..tostring(s.quarantined_native or 0)..' | repairs '..tostring(s.self_heal_repairs or 0));
    end
    if imgui.Button('Reconcile Current Zone##hc_zonesync_force') then M.force('diagnostics manual reconcile'); end
end

function M.command(w)
    local sub=string.lower(w[2] or ''); if sub~='zonesync' and sub~='snapshot' then return false; end
    if M.force('command') then HC.msg('Zone reconciliation scheduled.'); else HC.msg('Zone reconciliation unavailable until character/zone data is ready.'); end
    return true;
end

function M.init(ctx) HC=ctx; end
return M;
