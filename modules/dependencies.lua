local M={};
local HC;
local stats={sources={},targets={},last_at=nil,last_source=nil,last_reason=nil};

-- Dependency-driven cache invalidation. This module never performs heavy
-- reconstruction itself; it only marks dependent caches dirty so the owning
-- subsystem can rebuild lazily/event-driven on its next normal access.
local GRAPH={
    zone={'quests','planner','overview','weekly','releasehealth','synchealth','integrity'},
    missions={'quests','progression','search','overview','releasehealth','synchealth','integrity'},
    quests={'quests','progression','search','planner','overview','integrity'},
    keyitems={'quests','progression','overview','releasehealth','synchealth','integrity'},
    unlocks={'quests','progression','search','overview','integrity'},
    inventory={'seasonal','overview','integrity'},
    seasonal={'overview','integrity'},
    anniversary={'overview','integrity'},
    fame={'quests','progression','search','overview','releasehealth','synchealth','integrity'},
    eco={'overview','releasehealth','synchealth','integrity'},
    assault={'overview','releasehealth','synchealth','integrity'},
    assault_history={'progression','overview','releasehealth','synchealth','integrity'},
    weekly={'weekly','overview','releasehealth','synchealth','integrity'},
    account_weekly={'weekly','overview','integrity'},
    history={'quests','progression','search','planner','overview','releasehealth','synchealth','integrity'},
    progression={'quests','planner','overview','integrity'},
};

local function bump(t,k)
    t[k]=(tonumber(t[k]) or 0)+1;
end

local function invalidate_target(target,source,reason)
    local m=HC and HC.modules or {};
    if target=='quests' and m.quests and m.quests.invalidate_runtime_cache then
        pcall(m.quests.invalidate_runtime_cache,false);
    elseif target=='planner' and m.planner and m.planner.invalidate then
        pcall(m.planner.invalidate);
    elseif target=='overview' and m.smartdashboard and m.smartdashboard.invalidate then
        pcall(m.smartdashboard.invalidate);
    elseif target=='weekly' and m.weekly and m.weekly.invalidate_progress then
        pcall(m.weekly.invalidate_progress);
    elseif target=='releasehealth' and m.releasehealth and m.releasehealth.invalidate then
        pcall(m.releasehealth.invalidate);
    elseif target=='synchealth' and m.synchealth and m.synchealth.invalidate then
        pcall(m.synchealth.invalidate);
    elseif target=='search' and m.search and m.search.invalidate then
        pcall(m.search.invalidate);
    elseif target=='seasonal' and m.seasonal and m.seasonal.invalidate then
        pcall(m.seasonal.invalidate);
    elseif target=='history' and m.historyimport and m.historyimport.invalidate then
        pcall(m.historyimport.invalidate);
    elseif target=='progression' and m.progression and m.progression.invalidate then
        -- Mark progression dirty only. The progression engine batches bursts and
        -- reconciles on its low-cadence poll instead of rebuilding synchronously
        -- inside packet/inventory invalidation paths.
        pcall(m.progression.invalidate,source,reason);
    elseif target=='integrity' and m.integrity and m.integrity.invalidate then
        pcall(m.integrity.invalidate,source,reason);
    end
end

function M.invalidate(source,reason)
    source=string.lower(tostring(source or 'unknown'));
    local targets=GRAPH[source] or {};
    bump(stats.sources,source);
    stats.last_at=os.time(); stats.last_source=source; stats.last_reason=tostring(reason or 'state changed');
    local seen={};
    for _,target in ipairs(targets) do
        if not seen[target] then
            seen[target]=true; invalidate_target(target,source,reason); bump(stats.targets,target);
        end
    end
    if HC and HC.modules and HC.modules.profiler and HC.modules.profiler.bump then
        HC.modules.profiler.bump('dependencies.invalidate.'..source);
    end
    return #targets;
end

function M.invalidate_many(sources,reason)
    local done={}; local n=0;
    for _,source in ipairs(type(sources)=='table' and sources or {}) do
        local s=string.lower(tostring(source or 'unknown'));
        if not done[s] then done[s]=true; n=n+M.invalidate(s,reason); end
    end
    return n;
end

function M.status()
    local out={sources={},targets={},last_at=stats.last_at,last_source=stats.last_source,last_reason=stats.last_reason};
    for k,v in pairs(stats.sources) do out.sources[k]=v; end
    for k,v in pairs(stats.targets) do out.targets[k]=v; end
    return out;
end

function M.draw()
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local s=M.status();
    imgui.Text('Dependency-Driven Reconciliation');
    imgui.TextDisabled('Authoritative changes invalidate only dependent caches; expensive rebuilds remain lazy/event-driven.');
    if s.last_at then
        imgui.TextDisabled(string.format('Last invalidation: %s | %s | %s',os.date('%H:%M:%S',s.last_at),tostring(s.last_source or '?'),tostring(s.last_reason or '')));
    else
        imgui.TextDisabled('No dependency invalidations recorded this session yet.');
    end
    local rows={}; for k,v in pairs(s.sources or {}) do rows[#rows+1]={name=k,count=v}; end
    table.sort(rows,function(a,b) return (a.count or 0)>(b.count or 0); end);
    if #rows>0 then
        imgui.Text('Source Events');
        for i=1,math.min(12,#rows) do imgui.TextDisabled(string.format('%-18s %d',rows[i].name,rows[i].count or 0)); end
    end
end

function M.init(ctx) HC=ctx; end
return M;
