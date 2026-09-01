local M = {};
local HC;

local function ensure(c)
    c.activity_sessions = type(c.activity_sessions) == 'table' and c.activity_sessions or {};
    local s = c.activity_sessions;
    s.next_id = tonumber(s.next_id) or 1;
    s.active = type(s.active) == 'table' and s.active or {};
    s.history = type(s.history) == 'table' and s.history or {};
    return s;
end

local function trim(s)
    while #s.history > 30 do table.remove(s.history, 1); end
end

local function confidence_info(rec)
    rec=type(rec)=='table' and rec or {};
    local raw=string.upper(tostring(
        (rec.completion and rec.completion.confidence) or rec.confidence or ''
    ));
    local reason=string.lower(tostring(
        (rec.completion and rec.completion.reason) or rec.reason or ''
    ));

    -- VERIFIED = direct authoritative completion/reward evidence.
    if raw:find('CHAT CONFIRMED',1,true)
        or reason:find('successful completion',1,true)
        or reason:find('assault points gained',1,true)
        or reason:find('3000 exp',1,true)
        or reason:find('3000 gil',1,true)
        or reason:find('reward pair',1,true)
        or reason:find('reward',1,true)
        or reason:find('key item',1,true)
    then
        return {
            tier='VERIFIED',
            evidence='authoritative completion/reward message',
            raw=raw~='' and raw or 'CHAT/REWARD',
        };
    end

    -- CONFIRMED = direct world/zone observation plus matching activity context.
    if raw:find('CONTEXT + ZONE',1,true) then
        return {
            tier='CONFIRMED',
            evidence='activity context + zone transition',
            raw=raw,
        };
    end
    if raw:find('ZONE CONFIRMED',1,true) then
        return {
            tier='CONFIRMED',
            evidence='direct zone entry',
            raw=raw,
        };
    end
    if raw=='CONFIRMED' then
        return {
            tier='CONFIRMED',
            evidence='direct detector evidence',
            raw=raw,
        };
    end

    -- INFERRED = state reconstructed after reload or completion without start.
    if rec.inferred==true or rec.recovered==true
        or raw:find('RECOVERED',1,true)
        or reason:find('inferred',1,true)
    then
        return {
            tier='INFERRED',
            evidence=rec.recovered and 'recovered after reload' or 'derived from surrounding evidence',
            raw=raw~='' and raw or 'INFERRED',
        };
    end

    if raw:find('MANUAL',1,true) or reason:find('manual',1,true) then
        return {
            tier='MANUAL',
            evidence='user-entered state',
            raw=raw~='' and raw or 'MANUAL',
        };
    end

    return {
        tier='OBSERVED',
        evidence=reason~='' and reason or 'activity observed',
        raw=raw~='' and raw or 'UNSPECIFIED',
    };
end


local function stamp(rec, state, reason, confidence)
    rec.state = state;
    rec.updated_at = os.time();
    if reason ~= nil then rec.reason = tostring(reason); end
    if confidence ~= nil then rec.confidence = tostring(confidence); end
end

local function archive(c, rec)
    local s=ensure(c);
    s.history[#s.history+1]=rec;
    trim(s);
end

function M.init(ctx) HC=ctx; end

function M.ensure(c) return ensure(c); end

function M.start(c, kind, opts)
    opts=type(opts)=='table' and opts or {};
    local s=ensure(c); kind=tostring(kind or 'activity');
    local cur=s.active[kind];
    if type(cur)=='table' and cur.active==true then
        if opts.zone_id then cur.zone_id=opts.zone_id; end
        if opts.zone_name then cur.zone_name=opts.zone_name; end
        cur.recovered=false; stamp(cur,'ACTIVE',opts.reason or cur.reason,opts.confidence or cur.confidence); return cur,false;
    end
    local rec={
        id=s.next_id, kind=kind, active=true, state='ACTIVE',
        started_at=tonumber(opts.started_at) or os.time(), updated_at=os.time(),
        zone_id=opts.zone_id, zone_name=opts.zone_name, reason=opts.reason,
        confidence=opts.confidence or 'ZONE CONFIRMED', recovered=opts.recovered==true,
        completion=nil,
    };
    s.next_id=s.next_id+1; s.active[kind]=rec;
    return rec,true;
end

function M.recover(c, kind, opts)
    opts=type(opts)=='table' and opts or {}; opts.recovered=true; opts.confidence=opts.confidence or 'RECOVERED';
    local rec,created=M.start(c,kind,opts); rec.recovered=true; rec.state='RECOVERED'; return rec,created;
end

function M.complete(c, kind, reason, confidence)
    local s=ensure(c); kind=tostring(kind or 'activity'); local rec=s.active[kind];
    if type(rec)~='table' then
        rec=M.start(c,kind,{reason='inferred from completion',confidence=confidence or 'CHAT CONFIRMED'});
        rec.inferred=true;
    end
    rec.completion={at=os.time(),reason=tostring(reason or 'completion detected'),confidence=tostring(confidence or 'CONFIRMED')};
    stamp(rec,'COMPLETED',reason,confidence or 'CONFIRMED'); return rec;
end

function M.close(c, kind, reason, state)
    local s=ensure(c); kind=tostring(kind or 'activity'); local rec=s.active[kind];
    if type(rec)~='table' then return nil,false; end
    rec.active=false; rec.ended_at=os.time(); stamp(rec,state or (rec.completion and 'COMPLETED' or 'EXITED'),reason or rec.reason,rec.confidence);
    archive(c,rec); s.active[kind]=nil; return rec,true;
end

function M.abort(c, kind, reason) return M.close(c,kind,reason or 'aborted','ABORTED'); end
function M.current(c,kind) return ensure(c).active[tostring(kind or '')]; end
function M.active(c) return ensure(c).active; end
function M.history(c) return ensure(c).history; end

function M.confidence_info(rec)
    return confidence_info(rec);
end

function M.summary(c,kind)
    local rec=M.current(c,kind); if not rec then return 'inactive'; end
    local age=os.time()-(tonumber(rec.started_at) or os.time());
    local ci=confidence_info(rec);
    return string.format('#%s %s | %s | [%s] %s%s',
        tostring(rec.id or '?'),
        tostring(rec.state or 'ACTIVE'),
        HC.modules.core.format_duration(age),
        tostring(ci.tier),
        tostring(ci.evidence),
        rec.recovered and ' | reload baseline' or '');
end

function M.reset_scope(c,scope,reason)
    local s=ensure(c); local close={};
    for kind,rec in pairs(s.active) do
        if scope=='weekly' and (kind=='dynamis' or kind=='limbus') then close[#close+1]=kind;
        elseif scope=='daily' and kind=='assault' then close[#close+1]=kind; end
    end
    for _,kind in ipairs(close) do M.close(c,kind,reason or (scope..' reset'),'RESET'); end
end

function M.command(w)
    if string.lower(w[2] or '')~='session' and string.lower(w[2] or '')~='sessions' then return false; end
    local c=HC.modules.state.get_char(); local sub=string.lower(w[3] or 'status');
    if sub=='status' or sub=='' then
        local any=false; for kind,_ in pairs(M.active(c)) do any=true; HC.msg(string.upper(kind)..' session: '..M.summary(c,kind)); end
        if not any then HC.msg('No active activity sessions.'); end
    elseif sub=='abort' then
        local kind=string.lower(w[4] or ''); if kind=='' then HC.msg('Usage: /hcheck session abort <type>'); return true; end
        local _,ok=M.abort(c,kind,'manual abort'); if ok then HC.modules.state.save(); HC.msg('Session aborted: '..kind); else HC.msg('No active '..kind..' session.'); end
    else HC.msg('Usage: /hcheck session status | abort <type>'); end
    return true;
end

return M;
