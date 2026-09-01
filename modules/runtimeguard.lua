local M = {};
local HC;

-- Runtime operation isolation.  Each operation keeps its own error history so
-- one broken tracker can be paused without taking down the rest of the addon.
local records = {};
local ERROR_WINDOW_SECONDS = 60;
local ERROR_THRESHOLD = 3;
local QUARANTINE_SECONDS = 30;

local function now() return os.time(); end

local function ensure(name)
    name=tostring(name or 'unknown');
    local r=records[name];
    if not r then
        r={name=name,total=0,consecutive=0,suppressed=0,first_at=nil,last_at=nil,
            signature=nil,quarantined_until=nil,last_error=nil,last_success_at=nil};
        records[name]=r;
    end
    return r;
end

local function signature(err)
    local s=tostring(err or 'unknown error');
    -- Line numbers remain useful, but collapse changing table addresses so the
    -- same root error is not recorded as a new failure every frame.
    s=s:gsub('table: 0x[%da-fA-F]+','table:<addr>');
    s=s:gsub('function: 0x[%da-fA-F]+','function:<addr>');
    return s;
end

local function note_error(name,err)
    local r=ensure(name);
    local t=now();
    local sig=signature(err);
    if r.last_at and t-r.last_at>ERROR_WINDOW_SECONDS then r.consecutive=0; end
    r.total=(tonumber(r.total) or 0)+1;
    r.consecutive=(tonumber(r.consecutive) or 0)+1;
    r.first_at=r.first_at or t;
    r.last_at=t;
    r.last_error=tostring(err or 'unknown error');
    if r.signature==sig then r.suppressed=(tonumber(r.suppressed) or 0)+1; end
    r.signature=sig;

    if r.consecutive>=ERROR_THRESHOLD then
        r.quarantined_until=t+QUARANTINE_SECONDS;
    end

    if HC and HC.modules and HC.modules.diagnostics and HC.modules.diagnostics.record_error then
        pcall(HC.modules.diagnostics.record_error,name,err);
    end
    return r;
end

local function note_success(name)
    local r=ensure(name);
    r.consecutive=0;
    r.last_success_at=now();
    if r.quarantined_until and r.quarantined_until<=now() then r.quarantined_until=nil; end
end

function M.is_quarantined(name)
    local r=ensure(name);
    local until_at=tonumber(r.quarantined_until);
    if until_at and until_at>now() then return true,until_at-now(),r; end
    if until_at then r.quarantined_until=nil; end
    return false,0,r;
end

function M.retry(name)
    local r=ensure(name);
    r.quarantined_until=nil;
    r.consecutive=0;
    return true;
end

function M.retry_all()
    for _,r in pairs(records) do
        r.quarantined_until=nil;
        r.consecutive=0;
    end
    return true;
end

-- pcall-compatible guarded execution with profiler integration.  Callers
-- receive true/results or false/error exactly as they would from pcall.
function M.pcall(name,fn,...)
    if type(fn)~='function' then return false,'function unavailable'; end
    local quarantined,left=M.is_quarantined(name);
    if quarantined then return true,nil,'quarantined'; end

    local args={n=select('#',...),...};
    local started=os.clock()*1000.0;
    local function pack(...) return {n=select('#',...),...}; end
    local result=pack(pcall(fn,(table.unpack or unpack)(args,1,args.n)));
    local elapsed=os.clock()*1000.0-started;
    if HC and HC.modules and HC.modules.profiler and HC.modules.profiler.record then
        pcall(HC.modules.profiler.record,tostring(name),elapsed);
    end

    if result[1] then
        note_success(name);
    else
        note_error(name,result[2]);
    end
    return (table.unpack or unpack)(result,1,result.n);
end

-- Draw one module inside a protected boundary.  Failure text is rendered in
-- place so the rest of the current tab and all other tabs remain usable.
function M.draw(name,fn,...)
    local imgui=HC and HC.imgui or nil;
    local quarantined,left=M.is_quarantined(name);
    if quarantined then
        if imgui then
            imgui.TextDisabled(tostring(name)..' is temporarily paused after repeated errors.');
            imgui.TextDisabled('Automatic retry in '..tostring(left)..'s.');
            if imgui.SmallButton('Retry Now##runtimeguard_retry_'..tostring(name):gsub('[^%w]','_')) then M.retry(name); end
        end
        return false,'quarantined';
    end

    local ok,a,b,c,d,e=M.pcall(name,fn,...);
    if not ok then
        if imgui then
            imgui.Text(tostring(name)..' encountered an error.');
            imgui.TextDisabled('Other HorizonCheck systems remain available.');
            if imgui.SmallButton('Retry##runtimeguard_retry_'..tostring(name):gsub('[^%w]','_')) then M.retry(name); end
            imgui.SameLine();
            imgui.TextDisabled('See Diagnostics -> Runtime Errors.');
        end
        return false,a;
    end
    return true,a,b,c,d,e;
end

function M.snapshot()
    local rows={}; local quarantined=0; local total=0; local suppressed=0;
    for _,r in pairs(records) do
        local row={}; for k,v in pairs(r) do row[k]=v; end
        local q,left=M.is_quarantined(r.name); row.quarantined=q; row.retry_in=left;
        rows[#rows+1]=row;
        total=total+(tonumber(r.total) or 0);
        suppressed=suppressed+(tonumber(r.suppressed) or 0);
        if q then quarantined=quarantined+1; end
    end
    table.sort(rows,function(a,b)
        if a.quarantined~=b.quarantined then return a.quarantined; end
        return (tonumber(a.last_at) or 0)>(tonumber(b.last_at) or 0);
    end);
    return {rows=rows,operations=#rows,total_errors=total,suppressed=suppressed,quarantined=quarantined};
end

function M.status()
    local s=M.snapshot();
    return {operations=s.operations,total_errors=s.total_errors,suppressed=s.suppressed,quarantined=s.quarantined};
end

function M.draw_status()
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local s=M.snapshot();
    imgui.Text(string.format('Protected operations: %d | errors: %d | suppressed repeats: %d | paused: %d',
        s.operations,s.total_errors,s.suppressed,s.quarantined));
    if #s.rows==0 then imgui.TextDisabled('No guarded runtime failures this session.'); return; end
    for _,r in ipairs(s.rows) do
        local state=r.quarantined and ('PAUSED '..tostring(r.retry_in)..'s') or 'READY';
        imgui.TextWrapped(string.format('%s | %s | %d error(s)%s',tostring(r.name),state,tonumber(r.total) or 0,
            (tonumber(r.suppressed) or 0)>0 and (' | '..tostring(r.suppressed)..' repeat(s) collapsed') or ''));
        if r.last_error then imgui.TextDisabled('  '..tostring(r.last_error)); end
        if r.quarantined then
            if imgui.SmallButton('Retry##runtimeguard_status_'..tostring(r.name):gsub('[^%w]','_')) then M.retry(r.name); end
        end
    end
    if s.quarantined>0 and imgui.Button('Retry All Paused Operations##runtimeguard_retry_all') then M.retry_all(); end
end

function M.command(w)
    local sub=string.lower(tostring(w[2] or ''));
    if sub~='guard' and sub~='runtimeguard' then return false; end
    local action=string.lower(tostring(w[3] or 'status'));
    if action=='retry' then M.retry_all(); HC.msg('Runtime guard retries enabled for all operations.');
    else
        local s=M.status(); HC.msg(string.format('Runtime guard: %d errors | %d collapsed repeats | %d paused operation(s).',s.total_errors,s.suppressed,s.quarantined));
    end
    return true;
end

function M.init(ctx) HC=ctx; end
return M;
