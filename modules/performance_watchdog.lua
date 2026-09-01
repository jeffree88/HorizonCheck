local M={};
local HC;

-- Session-only performance watchdog. It samples existing profiler counters at a
-- deliberately low cadence and never performs inventory/catalog work itself.
local SAMPLE_SECONDS=60;
local WINDOW_MIN_SECONDS=30;
local last_sample_at=0;
local previous={at=nil,counters={}};
local last={at=nil,state='WARMING UP',issues={},window_seconds=0,rates={},cache_rows={}};

local RATE_LIMITS={
    ['inventory.full_scan']=12,          -- per minute
    ['seasonal.snapshot.rebuild']=30,
    ['historyimport.scan']=6,
    ['integrity.scan']=6,
    ['state.save.write']=20,
    ['state.save.request']=90,
};
local CACHE_WATCH={
    ['inventory.collection_scan']=true,
    ['seasonal.ownership']=true,
    ['planner.model']=true,
    ['search.index']=true,
    ['skills.job_levels']=true,
    ['historyimport.reconcile']=true,
};
local CACHE_MIN_SAMPLES=20;
local CACHE_MIN_HIT_RATE=40;
local DEPENDENCY_INVALIDATE_LIMIT=120; -- aggregate per minute

local function counter_map()
    local out={};
    local p=HC and HC.modules and HC.modules.profiler or nil;
    local rows=p and p.counter_snapshot and p.counter_snapshot() or {};
    for _,r in ipairs(rows or {}) do
        out[tostring(r.name)]={count=tonumber(r.count) or 0,hits=tonumber(r.hits) or 0,misses=tonumber(r.misses) or 0};
    end
    return out;
end

local function delta(cur,old,key)
    local a=type(cur[key])=='table' and cur[key] or {};
    local b=type(old[key])=='table' and old[key] or {};
    return math.max(0,(tonumber(a.count) or 0)-(tonumber(b.count) or 0)),
        math.max(0,(tonumber(a.hits) or 0)-(tonumber(b.hits) or 0)),
        math.max(0,(tonumber(a.misses) or 0)-(tonumber(b.misses) or 0));
end

local function add_issue(rows,kind,name,detail)
    rows[#rows+1]={kind=kind,name=name,detail=tostring(detail or '')};
end

function M.sample(force)
    local now=os.time();
    if not force and last_sample_at>0 and now-last_sample_at<SAMPLE_SECONDS then return last; end
    local cur=counter_map();
    if previous.at==nil then
        previous={at=now,counters=cur}; last_sample_at=now;
        last={at=now,state='WARMING UP',issues={},window_seconds=0,rates={},cache_rows={}};
        return last;
    end
    local seconds=math.max(1,now-(tonumber(previous.at) or now));
    if seconds<WINDOW_MIN_SECONDS and not force then return last; end
    local rows={}; local rates={}; local cache_rows={};

    for name,limit in pairs(RATE_LIMITS) do
        local d=delta(cur,previous.counters,name);
        local rate=d*60/seconds; rates[name]=rate;
        if rate>limit then
            add_issue(rows,'RATE',name,string.format('%.1f/min exceeds watchdog threshold %.1f/min over %ds.',rate,limit,seconds));
        end
    end

    local dep_delta=0;
    for name in pairs(cur) do
        if tostring(name):find('dependencies.invalidate.',1,true)==1 then
            local d=delta(cur,previous.counters,name); dep_delta=dep_delta+d;
        end
    end
    local dep_rate=dep_delta*60/seconds; rates['dependencies.invalidate.*']=dep_rate;
    if dep_rate>DEPENDENCY_INVALIDATE_LIMIT then
        add_issue(rows,'RATE','dependencies.invalidate.*',string.format('%.1f/min aggregate invalidations exceeds %.1f/min.',dep_rate,DEPENDENCY_INVALIDATE_LIMIT));
    end

    for name in pairs(CACHE_WATCH) do
        local _,hits,misses=delta(cur,previous.counters,name);
        local total=hits+misses;
        if total>=CACHE_MIN_SAMPLES then
            local hit_rate=hits/total*100;
            cache_rows[#cache_rows+1]={name=name,total=total,hits=hits,misses=misses,hit_rate=hit_rate};
            if hit_rate<CACHE_MIN_HIT_RATE then
                add_issue(rows,'CACHE',name,string.format('%.0f%% cache hit rate across %d recent reads; repeated rebuilds may be occurring.',hit_rate,total));
            end
        end
    end
    table.sort(cache_rows,function(a,b) return tostring(a.name)<tostring(b.name); end);

    local ph=HC and HC.modules and HC.modules.profiler and HC.modules.profiler.release_health and HC.modules.profiler.release_health() or {};
    if (tonumber(ph.persistent_warnings) or 0)>0 then
        add_issue(rows,'TIMING','measured sections',string.format('%d persistent profiler budget warning(s): %s',tonumber(ph.persistent_warnings) or 0,table.concat(ph.slow or {},', ')));
    end

    last={at=now,state=(#rows>0 and 'WARNING' or 'HEALTHY'),issues=rows,window_seconds=seconds,rates=rates,cache_rows=cache_rows};
    previous={at=now,counters=cur}; last_sample_at=now;
    if HC and HC.modules and HC.modules.profiler and HC.modules.profiler.bump then HC.modules.profiler.bump('watchdog.sample'); end
    return last;
end

function M.poll() return M.sample(false); end
function M.status()
    local s=last;
    return {at=s.at,state=s.state,issues=#(s.issues or {}),window_seconds=s.window_seconds or 0};
end
function M.reset()
    previous={at=nil,counters={}}; last_sample_at=0; last={at=nil,state='WARMING UP',issues={},window_seconds=0,rates={},cache_rows={}};
    return M.sample(true);
end

function M.draw()
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local s=last.at and last or M.sample(true);
    imgui.Text('Performance Watchdog: '..tostring(s.state or 'WARMING UP'));
    imgui.TextDisabled('Samples profiler telemetry once per minute. It does not scan inventory, quests, or catalogs itself.');
    if imgui.Button('Sample Now##hc_watchdog_sample') then s=M.sample(true); end
    imgui.SameLine(); if imgui.Button('Reset Watchdog Window##hc_watchdog_reset') then s=M.reset(); end
    if (tonumber(s.window_seconds) or 0)>0 then imgui.TextDisabled('Observation window: '..tostring(s.window_seconds)..' sec'); end
    if #(s.issues or {})==0 then
        imgui.TextDisabled(s.state=='WARMING UP' and 'Collecting a baseline sample.' or 'No abnormal cache, scan, save, invalidation, or timing pattern detected.');
    else
        for _,r in ipairs(s.issues or {}) do imgui.TextWrapped(tostring(r.name)..' - '..tostring(r.detail)); end
    end
end

function M.command(w)
    local sub=string.lower(tostring(w[2] or ''));
    if sub~='watchdog' and sub~='perfwatch' and sub~='performancewatchdog' then return false; end
    local s=M.sample(true); HC.msg(string.format('Performance watchdog: %s | %d warning(s).',tostring(s.state),#(s.issues or {}))); return true;
end
function M.init(ctx) HC=ctx; end
return M;
