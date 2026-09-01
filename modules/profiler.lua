local M = {};
local HC;
local stats={};
local counters={};
local enabled=true;

local DEFAULT_BUDGETS={
    ['poll.state']=2.0,['poll.keyitems']=4.0,['poll.learning']=2.0,['poll.automation']=4.0,
    ['poll.progression']=5.0,['poll.selfheal']=8.0,['poll.capturewizard']=2.0,['poll.zonesync']=3.0,['poll.plantpots']=2.0,['ui.main']=12.0,
    ['selfheal.scan']=12.0,['zonesync.phase1']=25.0,['zonesync.phase2']=35.0,['zonesync.phase3']=35.0,['planner.build']=5.0,['search.query']=8.0,
};

local function now_ms() return os.clock()*1000.0; end
local function ensure(name)
    name=tostring(name or 'unknown'); local r=stats[name];
    if not r then r={name=name,count=0,total_ms=0,last_ms=0,max_ms=0,ema_ms=0,budget_ms=DEFAULT_BUDGETS[name]}; stats[name]=r; end
    return r;
end

function M.record(name,ms)
    if not enabled then return; end
    local r=ensure(name); ms=tonumber(ms) or 0; r.count=r.count+1; r.total_ms=r.total_ms+ms; r.last_ms=ms; if ms>r.max_ms then r.max_ms=ms; end
    r.ema_ms=(r.count==1) and ms or (r.ema_ms*0.85+ms*0.15); r.last_at=os.time();
    r.over_budget=(r.budget_ms and (r.ema_ms>r.budget_ms or r.last_ms>r.budget_ms*2)) or false;
end

function M.measure(name,fn,...)
    if not enabled or type(fn)~='function' then return fn(...); end
    local args={n=select('#',...),...}; local t=now_ms();
    local function pack(...) return {n=select('#',...),...}; end
    local result=pack(pcall(fn,(table.unpack or unpack)(args,1,args.n)));
    M.record(name,now_ms()-t);
    if not result[1] then error(result[2],0); end
    return (table.unpack or unpack)(result,2,result.n);
end

function M.pcall(name,fn,...)
    if type(fn)~='function' then return false,'function unavailable'; end
    local args={n=select('#',...),...}; local t=now_ms();
    local function pack(...) return {n=select('#',...),...}; end
    local result=pack(pcall(fn,(table.unpack or unpack)(args,1,args.n)));
    M.record(name,now_ms()-t);
    return (table.unpack or unpack)(result,1,result.n);
end

function M.set_budget(name,ms) ensure(name).budget_ms=tonumber(ms); end

local function ensure_counter(name)
    name=tostring(name or 'unknown');
    local r=counters[name];
    if not r then r={name=name,count=0,hits=0,misses=0,last_at=nil}; counters[name]=r; end
    return r;
end

function M.bump(name,delta)
    if not enabled then return; end
    local r=ensure_counter(name); r.count=r.count+(tonumber(delta) or 1); r.last_at=os.time();
end

function M.cache(name,hit)
    if not enabled then return; end
    local r=ensure_counter(name); r.count=r.count+1; r.last_at=os.time();
    if hit==true then r.hits=r.hits+1; else r.misses=r.misses+1; end
end

function M.counter_snapshot()
    local rows={};
    for _,r in pairs(counters) do
        local c={}; for k,v in pairs(r) do c[k]=v; end
        local total=(tonumber(c.hits) or 0)+(tonumber(c.misses) or 0);
        c.hit_rate=total>0 and ((tonumber(c.hits) or 0)/total*100) or nil;
        rows[#rows+1]=c;
    end
    table.sort(rows,function(a,b) return tostring(a.name)<tostring(b.name); end);
    return rows;
end

function M.reset() stats={}; counters={}; end
function M.set_enabled(v) enabled=(v~=false); end
function M.enabled() return enabled; end

function M.snapshot()
    local rows={}; local warnings=0;
    for _,r in pairs(stats) do
        local c={}; for k,v in pairs(r) do c[k]=v; end; c.avg_ms=(c.count>0) and c.total_ms/c.count or 0; rows[#rows+1]=c; if c.over_budget then warnings=warnings+1; end
    end
    table.sort(rows,function(a,b) if a.over_budget~=b.over_budget then return a.over_budget; end return (a.ema_ms or 0)>(b.ema_ms or 0); end);
    return {rows=rows,warnings=warnings,enabled=enabled,counters=M.counter_snapshot()};
end

function M.draw()
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local s=M.snapshot();
    imgui.Text('Performance Profiler');
    imgui.TextDisabled('Low-overhead timing for live polls, planner work, UI rendering, and staged zone reconciliation.');
    imgui.Text(string.format('Status: %s | Budget warnings: %d',s.enabled and 'ON' or 'OFF',s.warnings or 0));
    local table_ok=(imgui.BeginTable~=nil and imgui.TableSetupColumn~=nil and imgui.TableHeadersRow~=nil and imgui.TableNextRow~=nil and imgui.TableSetColumnIndex~=nil and imgui.EndTable~=nil);
    if table_ok and imgui.BeginTable('##hc_profiler_v6890',6,64+128+512) then
        imgui.TableSetupColumn('Section',0,180); imgui.TableSetupColumn('Last ms',0,70); imgui.TableSetupColumn('EMA ms',0,70); imgui.TableSetupColumn('Max ms',0,70); imgui.TableSetupColumn('Budget',0,70); imgui.TableSetupColumn('State',0,80); imgui.TableHeadersRow();
        for _,r in ipairs(s.rows) do
            imgui.TableNextRow(); imgui.TableSetColumnIndex(0); imgui.Text(tostring(r.name));
            imgui.TableSetColumnIndex(1); imgui.TextDisabled(string.format('%.2f',r.last_ms or 0));
            imgui.TableSetColumnIndex(2); imgui.TextDisabled(string.format('%.2f',r.ema_ms or 0));
            imgui.TableSetColumnIndex(3); imgui.TextDisabled(string.format('%.2f',r.max_ms or 0));
            imgui.TableSetColumnIndex(4); imgui.TextDisabled(r.budget_ms and string.format('%.1f',r.budget_ms) or '-');
            imgui.TableSetColumnIndex(5); if r.over_budget then imgui.Text('SLOW'); else imgui.TextDisabled('OK'); end
        end
        imgui.EndTable();
    else
        for _,r in ipairs(s.rows) do imgui.TextDisabled(string.format('%-24s last %.2f | ema %.2f | max %.2f%s',r.name,r.last_ms or 0,r.ema_ms or 0,r.max_ms or 0,r.over_budget and ' | SLOW' or '')); end
    end
    if #(s.counters or {})>0 then
        imgui.Separator();
        imgui.Text('Runtime Counters / Cache Health');
        imgui.TextDisabled('Event-driven counters make repeated scans and cache churn visible without adding frame-time work.');
        if table_ok and imgui.BeginTable('##hc_profiler_counters_v6980',5,64+128+512) then
            imgui.TableSetupColumn('Counter',0,220); imgui.TableSetupColumn('Total',0,80); imgui.TableSetupColumn('Hits',0,80); imgui.TableSetupColumn('Misses',0,80); imgui.TableSetupColumn('Hit Rate',0,90); imgui.TableHeadersRow();
            for _,r in ipairs(s.counters or {}) do
                imgui.TableNextRow();
                imgui.TableSetColumnIndex(0); imgui.Text(tostring(r.name));
                imgui.TableSetColumnIndex(1); imgui.TextDisabled(tostring(r.count or 0));
                imgui.TableSetColumnIndex(2); imgui.TextDisabled(tostring(r.hits or 0));
                imgui.TableSetColumnIndex(3); imgui.TextDisabled(tostring(r.misses or 0));
                imgui.TableSetColumnIndex(4); imgui.TextDisabled(r.hit_rate and string.format('%.0f%%',r.hit_rate) or '-');
            end
            imgui.EndTable();
        else
            for _,r in ipairs(s.counters or {}) do
                imgui.TextDisabled(string.format('%s: %d%s',tostring(r.name),tonumber(r.count) or 0,r.hit_rate and string.format(' | %.0f%% hit',r.hit_rate) or ''));
            end
        end
    end
    if imgui.Button('Reset Profiler##hc_profiler_reset') then M.reset(); end
end

function M.status() local s=M.snapshot(); return {warnings=s.warnings,enabled=s.enabled,sections=#s.rows,counters=#(s.counters or {})}; end

function M.release_health()
    local s=M.snapshot(); local persistent=0; local slow={};
    for _,r in ipairs(s.rows or {}) do
        local count=tonumber(r.count) or 0;
        local budget=tonumber(r.budget_ms);
        local ema=tonumber(r.ema_ms) or 0;
        local last=tonumber(r.last_ms) or 0;
        local is_persistent=(count>=3 and budget and ema>budget) or (count>=2 and budget and last>budget*3);
        if is_persistent then persistent=persistent+1; slow[#slow+1]=r.name; end
    end
    return {enabled=s.enabled,warnings=s.warnings,persistent_warnings=persistent,sections=#(s.rows or {}),slow=slow,counters=#(s.counters or {})};
end
function M.command(w)
    local sub=string.lower(tostring(w[2] or '')); if sub~='profile' and sub~='profiler' and sub~='performance' then return false; end
    local s=M.snapshot(); HC.msg('Performance profiler: '..tostring(#s.rows)..' sections | '..tostring(s.warnings)..' warning(s).'); return true;
end
function M.init(ctx) HC=ctx; end
return M;
