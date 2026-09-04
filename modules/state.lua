local M = {};
local HC;
local CURRENT_SCHEMA = 24;
local state = { schema = CURRENT_SCHEMA, chars = {}, account = {}, account_weekly = {} };
local pending_char = {}; -- transient pre-login profile; never serialized
local path;
local last_saved_at = nil;
local last_backup_at = 0;
local pending_save_due = nil;
local save_batch_depth = 0;
local save_deferred = false;
local loaded_state_snapshot = nil;
local init_load_error = nil;
local storage_status_cache = nil;

local function data_path(kind,filename)
    if HC and HC.modules and HC.modules.userdata and HC.modules.userdata.path then
        local ok,res=pcall(HC.modules.userdata.path,kind,filename);
        if ok and type(res)=='string' and res~='' then return res; end
    end
    return tostring(HC and HC.addon_path or '')..tostring(filename or '');
end

local function state_backup_path(suffix)
    return data_path('backups','horizoncheck_state.lua'..tostring(suffix or ''));
end

local migration_runtime = {
    attempted=false, current=false, failed=false, rolled_back=false,
    from_schema=nil, to_schema=CURRENT_SCHEMA, last_result=nil,
    backup_path=nil, at=nil, validation=nil,
};

local function deepcopy(v)
    if type(v)~='table' then return v; end
    local o={}; for k,x in pairs(v) do o[deepcopy(k)]=deepcopy(x); end return o;
end

local function archive_reset(c, scope, oldkey)
    c.reset_history=type(c.reset_history)=='table' and c.reset_history or {};
    local rec={at=os.time(),scope=scope,key=oldkey};
    if scope=='daily' then rec.daily=deepcopy(c.daily or {});
    else rec.weekly=deepcopy(c.weekly or {}); rec.dragon_weekly=deepcopy(c.dragon_weekly or {}); end
    c.reset_history[#c.reset_history+1]=rec;
    while #c.reset_history>20 do table.remove(c.reset_history,1); end
    c.last_reset={at=rec.at,scope=scope,old_key=oldkey};
end

local function serialize(v, indent)
    indent = indent or '';
    local tv = type(v);
    if tv == 'nil' then return 'nil'; end
    if tv == 'boolean' or tv == 'number' then return tostring(v); end
    if tv == 'string' then return string.format('%q', v); end
    if tv ~= 'table' then return 'nil'; end
    local keys = {};
    for k in pairs(v) do keys[#keys + 1] = k; end
    table.sort(keys, function(a,b) return tostring(a) < tostring(b); end);
    local out = { '{' };
    local child = indent .. '    ';
    for _, k in ipairs(keys) do
        local key = (type(k) == 'string' and string.match(k, '^[%a_][%w_]*$'))
            and k or ('[' .. serialize(k, child) .. ']');
        out[#out + 1] = '\n' .. child .. key .. ' = ' .. serialize(v[k], child) .. ',';
    end
    if #keys > 0 then out[#out + 1] = '\n' .. indent; end
    out[#out + 1] = '}';
    return table.concat(out);
end

local function copy_file(src, dst)
    local f = io.open(src, 'rb');
    if not f then return false; end
    local data = f:read('*a'); f:close();
    local o = io.open(dst, 'wb');
    if not o then return false; end
    o:write(data); o:close();
    return true;
end


local function validate_state_table(candidate)
    local issues={};
    if type(candidate)~='table' then return false,{'root is not a table'}; end
    if type(candidate.chars)~='table' then issues[#issues+1]='chars table missing'; end
    if type(candidate.account)~='table' then issues[#issues+1]='account table missing'; end
    if type(candidate.account_weekly)~='table' then issues[#issues+1]='account_weekly table missing'; end
    local schema=tonumber(candidate.schema);
    if not schema or schema<1 then issues[#issues+1]='invalid schema marker'; end
    if type(candidate.chars)=='table' then
        for name,c in pairs(candidate.chars) do
            if type(name)~='string' or name=='' then issues[#issues+1]='invalid character key'; break; end
            if type(c)~='table' then issues[#issues+1]='character record is not a table: '..tostring(name); break; end
            if c.settings~=nil and type(c.settings)~='table' then issues[#issues+1]='invalid settings table: '..tostring(name); break; end
            if c.weekly~=nil and type(c.weekly)~='table' then issues[#issues+1]='invalid weekly table: '..tostring(name); break; end
        end
    end
    return #issues==0,issues;
end

local function rotate_migration_backups()
    if not path then return; end
    os.remove(state_backup_path('.migration.bak3'));
    os.rename(state_backup_path('.migration.bak2'),state_backup_path('.migration.bak3'));
    os.rename(state_backup_path('.migration.bak1'),state_backup_path('.migration.bak2'));
end

local function create_migration_backup(from_schema,to_schema)
    if not path then return nil; end
    local f=io.open(path,'rb');
    if not f then return nil; end
    f:close();
    rotate_migration_backups();
    local dst=state_backup_path('.migration.bak1');
    if copy_file(path,dst) then
        local meta=io.open(state_backup_path('.migration.info'),'w');
        if meta then
            meta:write(string.format('created=%s\nfrom_schema=%s\nto_schema=%s\nversion=%s\n',
                os.date('%Y-%m-%d %H:%M:%S'),tostring(from_schema),tostring(to_schema),tostring(HC and HC.version or '?')));
            meta:close();
        end
        return dst;
    end
    return nil;
end

local function load_state_file(filepath)
    local fn,err=loadfile(filepath);
    if not fn then return nil,tostring(err); end
    local ok,data=pcall(fn);
    if not ok then return nil,tostring(data); end
    local valid,issues=validate_state_table(data);
    if not valid then return nil,table.concat(issues,'; '); end
    return data,nil;
end

local function backup_if_needed()
    local now = os.time();
    if now - last_backup_at < 60 then return; end
    local f = io.open(path, 'rb');
    if not f then return; end
    f:close();
    os.remove(state_backup_path('.bak3'));
    os.rename(state_backup_path('.bak2'), state_backup_path('.bak3'));
    os.rename(state_backup_path('.bak1'), state_backup_path('.bak2'));
    if copy_file(path, state_backup_path('.bak1')) then last_backup_at = now; end
end

function M.init(ctx)
    HC = ctx;
    path = data_path('root','horizoncheck_state.lua');
    local f = io.open(path, 'r');
    if f ~= nil then
        f:close();
        local data,err=load_state_file(path);
        if data then
            state=data;
            state.chars = type(state.chars) == 'table' and state.chars or {};
            state.account = type(state.account) == 'table' and state.account or {};
            state.account_weekly = type(state.account_weekly) == 'table' and state.account_weekly or {};
            state.schema = tonumber(state.schema) or 1;
            loaded_state_snapshot=deepcopy(state);
        else
            init_load_error=tostring(err or 'unknown state load error');
            -- Keep a clean in-memory state. The corrupt file is never overwritten
            -- until migration/load validation has had a chance to report it.
            state={schema=CURRENT_SCHEMA,chars={},account={},account_weekly={}};
            loaded_state_snapshot=deepcopy(state);
        end
    else
        state={schema=CURRENT_SCHEMA,chars={},account={},account_weekly={}};
        loaded_state_snapshot=deepcopy(state);
    end
end

local function save_now()
    -- Never overwrite a state file that failed to load. Preserve it and its
    -- backups for recovery until the user replaces/restores the file.
    if init_load_error then return false; end
    backup_if_needed();
    local tmp = path .. '.tmp';
    local f = io.open(tmp, 'w');
    if f == nil then return false; end
    f:write('return ' .. serialize(state) .. '\n');
    f:close();
    os.remove(path);
    local ok = os.rename(tmp, path);
    if not ok then
        copy_file(tmp, path);
        os.remove(tmp);
    end
    last_saved_at = os.time();
    if HC and HC.modules and HC.modules.profiler and HC.modules.profiler.bump then HC.modules.profiler.bump('state.save.write'); end
    return true;
end

function M.save(immediate)
    -- v7.9.26: hundreds of legacy detector call sites still use state.save().
    -- An immediate full-table serialization at each of those sites can hitch the
    -- game during packet bursts.  Treat ordinary save() as a coalesced request;
    -- flush()/save(true) remain available for unload and explicit durability.
    if immediate==true then
        pending_save_due=nil;
        save_deferred=false;
        return save_now();
    end
    if save_batch_depth > 0 then
        save_deferred = true;
        return true;
    end
    return M.request_save(2);
end

function M.request_save(delay_seconds)
    local delay=math.max(0,math.floor(tonumber(delay_seconds) or 1));
    local due=os.time()+delay;
    -- Keep the write behind the newest burst member so a zone-in packet storm
    -- becomes one serialization instead of one serialization per packet.
    if pending_save_due==nil or due>pending_save_due then pending_save_due=due; end
    if HC and HC.modules and HC.modules.profiler and HC.modules.profiler.bump then HC.modules.profiler.bump('state.save.request'); end
    return true;
end

function M.begin_save_batch()
    save_batch_depth=save_batch_depth+1;
    return save_batch_depth;
end

function M.end_save_batch(delay_seconds)
    if save_batch_depth>0 then save_batch_depth=save_batch_depth-1; end
    if save_batch_depth==0 and save_deferred then
        save_deferred=false;
        M.request_save(delay_seconds or 1);
    end
    return save_batch_depth;
end

function M.poll()
    if pending_save_due~=nil and os.time()>=pending_save_due and save_batch_depth==0 then
        pending_save_due=nil;
        return save_now();
    end
    return false;
end

function M.flush()
    pending_save_due=nil;
    save_deferred=false;
    save_batch_depth=0;
    return save_now();
end

function M.last_saved_at() return last_saved_at; end
function M.pending_save() return pending_save_due~=nil; end
function M.backup_paths() return {state_backup_path('.bak1'), state_backup_path('.bak2'), state_backup_path('.bak3')}; end

function M.current_schema() return CURRENT_SCHEMA; end
function M.state_path() return path; end

function M.storage_status(force)
    if storage_status_cache and force~=true then return deepcopy(storage_status_cache); end
    local test_path=(path or data_path('root','horizoncheck_state.lua'))..'.write_test';
    local f,err=io.open(test_path,'w');
    local writable=f~=nil;
    if f then f:write('ok\n'); f:close(); os.remove(test_path); end
    storage_status_cache={writable=writable,detail=writable and ('writable: '..tostring(path)) or ('not writable: '..tostring(err or path)),error=err,at=os.time()};
    return deepcopy(storage_status_cache);
end

function M.validate(candidate)
    return validate_state_table(candidate or state);
end

function M.migration_status()
    local out=deepcopy(migration_runtime);
    out.current_schema=CURRENT_SCHEMA;
    out.state_schema=tonumber(state.schema) or 0;
    out.current=(tonumber(state.schema) or 0)==CURRENT_SCHEMA and migration_runtime.failed~=true;
    out.load_error=init_load_error;
    out.backups={state_backup_path('.migration.bak1'),state_backup_path('.migration.bak2'),state_backup_path('.migration.bak3')};
    return out;
end

function M.restore_latest_migration_backup()
    if not path then return false,'state path unavailable'; end
    local src=state_backup_path('.migration.bak1');
    local data,err=load_state_file(src);
    if not data then return false,'migration backup unavailable or invalid: '..tostring(err); end
    local safety=state_backup_path('.before_restore.bak');
    copy_file(path,safety);
    if not copy_file(src,path) then return false,'could not restore backup file'; end
    state=data;
    init_load_error=nil;
    loaded_state_snapshot=deepcopy(state);
    migration_runtime.rolled_back=true;
    migration_runtime.failed=false;
    migration_runtime.last_result='manual restore from migration backup';
    migration_runtime.at=os.time();
    return true,nil;
end

function M.get_account()
    state.account=type(state.account)=='table' and state.account or {};
    return state.account;
end

function M.migrate_account_assault_tags(defer_save)
    state.account=type(state.account)=='table' and state.account or {};
    state.account.assault_tags=type(state.account.assault_tags)=='table' and state.account.assault_tags or {};
    local shared=state.account.assault_tags;

    if shared.count~=nil then
        shared.migrated=true;
        return true;
    end

    local best=nil;
    for _,c in pairs(state.chars or {}) do
        if type(c)=='table' and type(c.assault_tags)=='table' and c.assault_tags.count~=nil then
            local t=c.assault_tags;
            if best==nil then
                best=t;
            else
                local a=tonumber(t.last_rytaal_reconcile_at) or tonumber(t.last_regen_at) or 0;
                local b=tonumber(best.last_rytaal_reconcile_at) or tonumber(best.last_regen_at) or 0;
                if a>b then best=t; end
            end
        end
    end

    if best==nil then
        -- Do NOT mark migration complete. A different character loaded later
        -- may still contain the known Rytaal pool.
        return false;
    end

    local fields={
        'count','cap','next_at','timer_estimated','last_regen_at',
        'packet_auto','packet','last_rytaal_reconcile_at',
        'last_rytaal_reconcile_reason','last_rytaal_reconcile_count',
        'last_rytaal_reconcile_debug','rytaal_legacy_reconcile_done',
        'rytaal_legacy_reconcile_at','legacy_regen_repairs'
    };
    for _,k in ipairs(fields) do
        if best[k]~=nil then shared[k]=deepcopy(best[k]); end
    end
    shared.migrated=true;
    shared.migrated_at=os.time();
    if defer_save~=true then M.save(); end
    return true;
end

function M.get_account_weekly()
    state.account_weekly=type(state.account_weekly)=='table' and state.account_weekly or {};
    local a=state.account_weekly;
    local wk=HC.modules.core.weekly_key();

    if a.weekly_key~=wk then
        a.weekly_key=wk;
        a.dynamis_count=0;
        a.dynamis_run_started_at=nil;
        a.dynamis_run_zone=nil;
        a.dynamis_last_reentry_at=nil;
        a.dynamis_last_reentry_zone=nil;
        -- Black Coffin is account-wide but weekly. Never carry a completed or
        -- failed/locked chain across the Conquest reset.
        a.black_coffin=nil;
    end

    a.dynamis_count=math.max(0,math.min(3,math.floor(tonumber(a.dynamis_count) or 0)));
    return a;
end

local function reconcile_account_dynamis_current_cycle()
    local a=M.get_account_weekly();
    local wk=HC.modules.core.weekly_key();
    local total=0;

    -- Rebuild the account-wide total only from character counters that belong
    -- to the current Conquest cycle. Old character mirrors must never resurrect
    -- a previous week's account total after reset.
    for _,cc in pairs(state.chars or {}) do
        if type(cc)=='table' and cc.weekly_key==wk and type(cc.weekly)=='table' then
            local n=math.max(0,math.min(2,math.floor(tonumber(cc.weekly.dynamis_character_count) or 0)));
            total=total+n;
        end
    end
    a.dynamis_count=math.max(0,math.min(3,total));
    return a.dynamis_count;
end

local function sync_account_dynamis_mirror(c)
    local a=M.get_account_weekly();
    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    c.weekly.dynamis_1=(a.dynamis_count>=1) and true or nil;
    c.weekly.dynamis_2=(a.dynamis_count>=2) and true or nil;
    c.weekly.dynamis_3=(a.dynamis_count>=3) and true or nil;
end

local function audit_ensure(c)
    c.audit_history=type(c.audit_history)=='table' and c.audit_history or {};
    return c.audit_history;
end

function M.audit(c,system,message,confidence,source)
    c=c or M.get_char();
    local h=audit_ensure(c);
    h[#h+1]={
        at=os.time(),
        system=tostring(system or 'general'),
        message=tostring(message or ''),
        confidence=confidence and tostring(confidence) or nil,
        source=source and tostring(source) or nil,
    };
    while #h>30 do table.remove(h,1); end
    M.save();
end

function M.audit_recent(c,limit)
    c=c or M.get_char();
    local h=audit_ensure(c);
    local out={};
    local n=math.max(1,math.min(30,tonumber(limit) or 10));
    local start=math.max(1,#h-n+1);
    for i=start,#h do out[#out+1]=h[i]; end
    return out;
end


-- v6.9.20: shared activity lifecycle metadata.  Modules can mirror their
-- authoritative state here without surrendering their existing specialized
-- storage.  This provides one consistent vocabulary for READY / IN PROGRESS /
-- COOLDOWN / AVAILABLE while keeping migrations low-risk.
local ACTIVITY_STATES={
    AVAILABLE=true, PREP=true, READY=true, IN_PROGRESS=true, CLEARED=true,
    COOLDOWN=true, LOCKED=true, UNKNOWN=true,
};


-- v6.9.25: formal ownership/reset registry.  This is intentionally metadata-first:
-- existing specialized modules keep their proven storage, while reset and lifecycle
-- cleanup can now consult one authoritative declaration instead of guessing.
local ACTIVITY_DEFINITIONS={
    outposts={scope='character',reset='permanent'},
    missions={scope='character',reset='permanent'},
    assault_progress={scope='character',reset='permanent'},
    assault_tags={scope='account',reset='persistent'},
    anniversary={scope='character',reset='event'},

    eco={scope='character',reset='conquest'},
    limbus={scope='character',reset='conquest'},
    dynamis={scope='account',reset='conquest'},
    blackcoffin={scope='account',reset='conquest'},

    enm={scope='character',reset='cooldown'},
    isnm={scope='character',reset='activity'},
    chocobo={scope='character',reset='activity'},
    digging={scope='character',reset='daily'},
    plant_pots={scope='character',reset='daily'},
};

function M.activity_definition(system)
    local d=ACTIVITY_DEFINITIONS[tostring(system or '')];
    return d and deepcopy(d) or {scope='character',reset='activity'};
end

function M.activity_scope(system)
    return M.activity_definition(system).scope;
end

function M.activity_reset(system)
    return M.activity_definition(system).reset;
end

local function activity_reset_scope(c,reset_kind)
    if type(c.activity_state)~='table' then return 0; end
    local removed=0;
    for system,records in pairs(c.activity_state) do
        local def=ACTIVITY_DEFINITIONS[tostring(system)] or {scope='character',reset='activity'};
        if def.reset==reset_kind and type(records)=='table' then
            for key in pairs(records) do records[key]=nil; removed=removed+1; end
            c.activity_state[system]=nil;
        end
    end
    return removed;
end

function M.activity_reset_scope(c,reset_kind,defer_save)
    c=c or M.get_char();
    local n=activity_reset_scope(c,tostring(reset_kind or ''));
    if n>0 and defer_save~=true then M.save(); end
    return n;
end

function M.activity_set(c,system,key,value,source,confidence,expires_at,details,defer_save)
    c=c or M.get_char();
    c.activity_state=type(c.activity_state)=='table' and c.activity_state or {};
    system=tostring(system or 'general'); key=tostring(key or 'default');
    c.activity_state[system]=type(c.activity_state[system])=='table' and c.activity_state[system] or {};
    local v=string.upper(tostring(value or 'UNKNOWN'));
    if not ACTIVITY_STATES[v] then v='UNKNOWN'; end
    c.activity_state[system][key]={
        state=v, source=source and tostring(source) or nil,
        confidence=confidence and tostring(confidence) or 'TRACKING',
        verified_at=os.time(), expires_at=tonumber(expires_at), details=deepcopy(details),
    };
    if defer_save~=true then M.save(); end
    return c.activity_state[system][key];
end

function M.activity_get(c,system,key)
    c=c or M.get_char();
    local a=type(c.activity_state)=='table' and c.activity_state or {};
    local sys=type(a[system])=='table' and a[system] or nil;
    local rec=sys and sys[key] or nil;
    if type(rec)~='table' then return nil; end
    if tonumber(rec.expires_at) and tonumber(rec.expires_at)<=os.time() then
        sys[key]=nil; M.save(); return nil;
    end
    return rec;
end

function M.activity_clear(c,system,key)
    c=c or M.get_char();
    if type(c.activity_state)=='table' and type(c.activity_state[system])=='table' then
        c.activity_state[system][key]=nil; M.save();
    end
end

function M.notification_should_emit(c,key,value)
    c=c or M.get_char();
    c.notification_state=type(c.notification_state)=='table' and c.notification_state or {};
    local k=tostring(key or '');
    local v=tostring(value or '');
    if c.notification_state[k]==v then return false; end
    c.notification_state[k]=v;
    M.save();
    return true;
end

function M.tracker_confidence(c)
    c=c or M.get_char();
    local now=os.time();
    local out={};

    local at=type(c.assault_tags)=='table' and c.assault_tags or {};
    local aconf=at.carried_confidence or ((at.carried~=nil) and 'UNKNOWN' or 'UNKNOWN');
    local aage=at.carried_verified_at and math.max(0,now-at.carried_verified_at) or nil;
    if aconf=='VERIFIED' and aage and aage>(48*60*60) then aconf='VERIFY'; end
    out.assault={confidence=aconf,age=aage,source=at.carried_source};

    local mm=type(c.mission_meta)=='table' and c.mission_meta or {};
    local native=type(mm.native)=='table' and mm.native or {};
    local mage=native.last_seen_at and math.max(0,now-native.last_seen_at) or nil;
    out.missions={confidence=native.last_seen_at and ((mage and mage>(7*24*60*60)) and 'VERIFY' or 'VERIFIED') or 'UNKNOWN',
        age=mage,source=native.last_seen_at and 'Native mission data' or nil};

    local dg=type(c.digging)=='table' and c.digging or {};
    local dconf=dg.server_cap_confirmed==true and 'VERIFIED' or (dg.count~=nil and 'ESTIMATED' or 'UNKNOWN');
    out.digging={confidence=dconf,source=dg.server_cap_confirmed and 'Server cap dialogue' or (dg.count and 'Observed digs' or nil)};

    local aw=M.get_account_weekly and M.get_account_weekly() or {};
    out.dynamis={confidence=(aw.dynamis_count~=nil) and 'TRACKING' or 'UNKNOWN',source=(aw.dynamis_count~=nil) and 'Account weekly state' or nil};

    local limbus_known=type(c.weekly)=='table' and (c.weekly.limbus_1~=nil or c.weekly.limbus_2~=nil);
    out.limbus={confidence=limbus_known and 'TRACKING' or 'UNKNOWN',source=limbus_known and 'Weekly state' or nil};

    local rw=type(c.ring_week)=='table' and c.ring_week or {};
    out.exp_ring={confidence=rw.last_name and 'TRACKING' or 'UNKNOWN',source=rw.last_name and 'Inventory scan' or nil};

    return out;
end

function M.initialization_summary(c)
    c=c or M.get_char();
    local o=M.onboarding(c);
    local pending={};
    if not o.mission_ok then pending[#pending+1]='Zone once for Mission Sync'; end
    if not o.keyitems_ok then pending[#pending+1]='Zone once for permanent key-item sync'; end
    if not o.assault_history_ok then pending[#pending+1]='Zone once for historical Assault clear import'; end
    if not o.zonesync_ok then pending[#pending+1]='Wait for Zone Sync phase 3/3'; end
    return {complete=o.complete,pending=pending,count=#pending};
end

local function reconcile_character_state(c)
    local repaired=0;

    -- Digging: a server-confirmed cap must always display/persist at the
    -- verified rank maximum, including states saved by older builds.
    if type(c.digging)=='table' and c.digging.server_cap_confirmed==true then
        local caps={
            amateur=100,recruit=110,initiate=120,novice=130,apprentice=140,
            journeyman=150,craftsman=160,artisan=170,adept=180,veteran=190,expert=200,
        };
        local rank=string.lower(tostring(c.digging.rank or ''));
        local cap=caps[rank];
        if cap and tonumber(c.digging.count)~=cap then
            c.digging.health_reconciled_from=tonumber(c.digging.count) or 0;
            c.digging.count=cap;
            c.digging.health_reconciled_at=os.time();
            repaired=repaired+1;
        end
    end

    -- Assault carried-tag ownership is never mutated from c.assault_activity.
    -- Only assault.lua direct signup / Assault Orders evidence consumes a tag.

    -- Shared lifecycle records may expire naturally. Remove them at load-time
    -- so a stale READY/IN_PROGRESS state cannot survive indefinitely.
    if type(c.activity_state)=='table' then
        local now=os.time();
        for _,sys in pairs(c.activity_state) do
            if type(sys)=='table' then
                for k,rec in pairs(sys) do
                    if type(rec)~='table' or (tonumber(rec.expires_at) and tonumber(rec.expires_at)<=now) then
                        sys[k]=nil; repaired=repaired+1;
                    end
                end
            end
        end
    end

    -- ENM temporary runtime protection. A battlefield cannot legitimately stay
    -- active across a long logout/reload, so clear abandoned active sessions.
    if type(c.enm_runtime)=='table' and type(c.enm_runtime.active)=='table' then
        local entered=tonumber(c.enm_runtime.active.entered_at) or 0;
        if entered>0 and os.time()-entered>(3*60*60) then
            c.enm_runtime.last=c.enm_runtime.active;
            c.enm_runtime.last.state='ABANDONED / EXPIRED';
            c.enm_runtime.active=nil; repaired=repaired+1;
        end
    end

    -- Reject impossible persisted ENM timers on load as a second safety net.
    if type(c.enm)=='table' then
        local now=os.time();
        for id,rec in pairs(c.enm) do
            if type(rec)=='table' and tonumber(rec.ready_at) then
                local delta=tonumber(rec.ready_at)-now;
                if delta>(7*24*60*60) or delta<-(24*60*60) then
                    c.enm[id]=nil; repaired=repaired+1;
                end
            end
        end
    end

    c.state_health=type(c.state_health)=='table' and c.state_health or {};
    c.state_health.last_checked_at=os.time();
    c.state_health.last_repaired=repaired;
    return repaired;
end

function M.reconcile(c)
    c=c or M.get_char();
    return reconcile_character_state(c);
end

function M.health(c)
    c=c or M.get_char();
    local issues=0;
    local notes={};
    local checks={};
    local function add(name,ok,detail,repairable)
        checks[#checks+1]={name=name,ok=ok==true,detail=detail,repairable=repairable==true};
        if not ok then issues=issues+1; notes[#notes+1]=name; end
    end

    add('Daily reset key',c.daily_key==HC.modules.core.daily_key(),
        c.daily_key==HC.modules.core.daily_key() and 'current' or 'stale',false);
    add('Weekly reset key',c.weekly_key==HC.modules.core.weekly_key(),
        c.weekly_key==HC.modules.core.weekly_key() and 'current' or 'stale',false);

    local mm=type(c.mission_meta)=='table' and c.mission_meta or {};
    local native=type(mm.native)=='table' and mm.native or {};
    add('Mission sync',true,
        native.last_seen_at and 'VERIFIED - native data received' or 'NEEDS INITIALIZATION - zone once',false);

    local digging_ok=true;
    local digging_detail='not initialized';
    if type(c.digging)=='table' and c.digging.server_cap_confirmed==true then
        local caps={amateur=100,recruit=110,initiate=120,novice=130,apprentice=140,
            journeyman=150,craftsman=160,artisan=170,adept=180,veteran=190,expert=200};
        local cap=caps[string.lower(tostring(c.digging.rank or ''))];
        digging_ok=(cap==nil) or tonumber(c.digging.count)==cap;
        digging_detail=digging_ok and ('capped '..tostring(c.digging.count or '?')..'/'..tostring(cap or '?')) or 'cap/count mismatch';
    elseif type(c.digging)=='table' and c.digging.count~=nil then
        digging_detail='tracking';
    end
    add('Digging state',digging_ok,
        digging_ok and ((digging_detail=='not initialized') and 'NEEDS INITIALIZATION - dig once' or digging_detail)
            or digging_detail,
        not digging_ok);

    local at=type(c.assault_tags)=='table' and c.assault_tags or nil;
    local assault_initialized=at and (at.carried~=nil or at.last_rytaal_menu_left~=nil or at.count~=nil);
    add('Assault state',true,
        assault_initialized and 'TRACKING' or 'NEEDS INITIALIZATION - talk to Rytaal',
        false);


    local outposts_ok=type(c.outposts)=='table' and type(c.outposts.owned)=='table' and type(c.outposts.verified_owned)=='table';
    add('Outpost data',outposts_ok,outposts_ok and 'state valid' or 'state missing',false);

    return {ok=(issues==0),issues=issues,notes=notes,checks=checks,
        repaired=type(c.state_health)=='table' and (tonumber(c.state_health.last_repaired) or 0) or 0};
end

function M.onboarding(c)
    c=c or M.get_char();
    local mm=type(c.mission_meta)=='table' and c.mission_meta or {};
    local native=type(mm.native)=='table' and mm.native or {};
    local mission_ok=native.last_seen_at~=nil;
    local bitmap=HC.modules.keyitems and HC.modules.keyitems.bitmap_status and HC.modules.keyitems.bitmap_status() or {};
    local keyitems_ok=(tonumber(bitmap.tables) or 0)>0;
    local assault_native=HC.modules.assaultprogress and HC.modules.assaultprogress.native_status and HC.modules.assaultprogress.native_status(c) or {};
    local assault_history_ok=assault_native.synced==true;
    local zs=HC.modules.zonesync and HC.modules.zonesync.status and HC.modules.zonesync.status() or {};
    local zonesync_ok=zs.state=='COMPLETE';
    return {
        mission_ok=mission_ok,keyitems_ok=keyitems_ok,assault_history_ok=assault_history_ok,zonesync_ok=zonesync_ok,
        -- Legacy aliases retained for older UI/state callers.
        assault_ok=assault_history_ok,digging_ok=true,
        complete=mission_ok and keyitems_ok and assault_history_ok and zonesync_ok,
    };
end

function M.profile_name()
    local name=(HC and HC.modules and HC.modules.core and HC.modules.core.character_name and HC.modules.core.character_name()) or 'Unknown';
    return tostring(name or 'Unknown');
end

function M.profile_ready()
    local name=M.profile_name();
    return name~='' and name~='Unknown';
end

function M.get_char()
    local name = M.profile_name();
    local c=nil;
    local new_profile=false;
    if name=='Unknown' then
        -- Modules can initialize safely before login without creating a shared
        -- persisted "Unknown" character that could leak settings between users.
        pending_char=type(pending_char)=='table' and pending_char or {};
        c=pending_char;
    else
        if type(state.chars[name])~='table' then
            -- First time this character has ever loaded HorizonCheck. Seed
            -- developer mode OFF explicitly so new users always start in the
            -- normal player-facing UI, regardless of any transient/pre-login state.
            state.chars[name]={ settings={ developer_mode=false } };
            new_profile=true;
        end
        c = state.chars[name];
    end

    c.daily = type(c.daily) == 'table' and c.daily or {};
    c.weekly = type(c.weekly) == 'table' and c.weekly or {};
    c.weekly.dynamis_character_count=math.max(0,math.min(2,math.floor(tonumber(c.weekly.dynamis_character_count) or 0)));
    c.dragon_weekly = type(c.dragon_weekly) == 'table' and c.dragon_weekly or {};
    c.eco = type(c.eco) == 'table' and c.eco or {};
    c.enm = type(c.enm) == 'table' and c.enm or {};
    c.quest_flags = type(c.quest_flags) == 'table' and c.quest_flags or { learned = {} };
    c.eeko_packets = type(c.eeko_packets) == 'table' and c.eeko_packets or { signatures = {} };
    c.automation = type(c.automation) == 'table' and c.automation or { enabled = true, events = {} };
    if c.automation.enabled == nil then c.automation.enabled = true; end
    if c.automation.dry_run == nil then c.automation.dry_run = false; end
    c.automation.events = type(c.automation.events) == 'table' and c.automation.events or {};
    c.automation.systems = type(c.automation.systems) == 'table' and c.automation.systems or {};
    c.automation.sessions = type(c.automation.sessions) == 'table' and c.automation.sessions or {};
    c.activity_timeline = type(c.activity_timeline) == 'table' and c.activity_timeline or { events = {}, next_id = 1 };
    c.activity_timeline.events = type(c.activity_timeline.events) == 'table' and c.activity_timeline.events or {};
    c.activity_timeline.next_id = tonumber(c.activity_timeline.next_id) or 1;
    c.progression = type(c.progression) == 'table' and c.progression or { last_states = {} };
    c.progression.last_states = type(c.progression.last_states) == 'table' and c.progression.last_states or {};
    c.self_heal = type(c.self_heal) == 'table' and c.self_heal or { repair_signatures = {} };
    c.self_heal.repair_signatures = type(c.self_heal.repair_signatures) == 'table' and c.self_heal.repair_signatures or {};
    c.quest_quarantine = type(c.quest_quarantine) == 'table' and c.quest_quarantine or {};
    c.guided_captures = type(c.guided_captures) == 'table' and c.guided_captures or {};
    c.learning_summary = type(c.learning_summary) == 'table' and c.learning_summary or {};
    c.tag_learning = type(c.tag_learning) == 'table' and c.tag_learning or { observations = {} };
    c.tag_learning.observations = type(c.tag_learning.observations) == 'table' and c.tag_learning.observations or {};
    c.assault_tags = type(c.assault_tags) == 'table' and c.assault_tags or {};
    if c.assault_tags.packet_auto == nil then c.assault_tags.packet_auto = true; end
    c.settings = type(c.settings) == 'table' and c.settings or {};
    c.schema_version=tonumber(c.schema_version) or CURRENT_SCHEMA;
    if new_profile then
        c.settings.developer_mode=false;
    elseif c.settings.developer_mode == nil then
        c.settings.developer_mode=false;
    end
    if c.settings.onboarding_dismissed == nil then c.settings.onboarding_dismissed=false; end
    if c.settings.setup_wizard_dismissed == nil then c.settings.setup_wizard_dismissed=false; end
    c.release_health=type(c.release_health)=='table' and c.release_health or {};
    if c.settings.hide_completed_weekly == nil then c.settings.hide_completed_weekly=false; end
    if c.settings.hide_completed_daily == nil then
        c.settings.hide_completed_daily=c.settings.hide_completed_weekly==true;
    end
    if c.settings.hide_completed_conquest == nil then
        c.settings.hide_completed_conquest=c.settings.hide_completed_weekly==true;
    end
    if c.settings.hide_completed_dragon == nil then
        c.settings.hide_completed_dragon=c.settings.hide_completed_weekly==true;
    end
    if c.settings.hide_completed_missions == nil then c.settings.hide_completed_missions=false; end
    if c.settings.hide_completed_quests == nil then c.settings.hide_completed_quests=false; end
    if c.settings.hide_completed_assaults == nil then c.settings.hide_completed_assaults=false; end
    if c.settings.hide_completed_outposts == nil then c.settings.hide_completed_outposts=false; end
    if c.settings.hide_capped_attention == nil then c.settings.hide_capped_attention=false; end
    if c.settings.global_incomplete_only == nil then c.settings.global_incomplete_only=false; end
    c.notification_state=type(c.notification_state)=='table' and c.notification_state or {};
    if c.settings.ui_density == nil then c.settings.ui_density='normal'; end

    c.settings.tabs=type(c.settings.tabs)=='table' and c.settings.tabs or {};
    -- Removed top-level tabs keep no stale visibility preference after their
    -- content moves into another primary tab.
    c.settings.tabs.dragon=nil;
    c.settings.tabs.jobprogression=nil;
    c.settings.tabs.eco=nil;
    c.settings.tabs.anniversary=nil;
    c.settings.tabs.seasonal=nil;
    local tab_defaults={'dashboard','dailyweekly','blackcoffin','chocobo','enm','assault','dynamis','limbus','henm','missions','quests','events','skills','status'};
    for _,k in ipairs(tab_defaults) do
        if c.settings.tabs[k]==nil then c.settings.tabs[k]=true; end
    end

    c.settings.notifications=type(c.settings.notifications)=='table' and c.settings.notifications or {};
    local notification_defaults={'mission','assault','enm','digging','blackcoffin','weekly','general'};
    for _,k in ipairs(notification_defaults) do
        if c.settings.notifications[k]==nil then c.settings.notifications[k]=true; end
    end

    -- Persistent Outpost ownership is character progression, not weekly state.
    -- Keep it outside c.weekly so Conquest resets and addon reloads never erase it.
    c.anniversary = type(c.anniversary) == 'table' and c.anniversary or {};
    c.activity_state = type(c.activity_state) == 'table' and c.activity_state or {};
    c.plant_pots = type(c.plant_pots) == 'table' and c.plant_pots or {};
    c.plant_pots_daily = type(c.plant_pots_daily) == 'table' and c.plant_pots_daily or {};
    if c.plant_pots.target == nil and tonumber(c.plant_pots_daily.target) then
        c.plant_pots.target = math.max(0, math.floor(tonumber(c.plant_pots_daily.target) or 0));
    end
    c.plant_pots.target = math.max(0, math.min(10, math.floor(tonumber(c.plant_pots.target) or 0)));

    c.outposts = type(c.outposts) == 'table' and c.outposts or {};
    c.outposts.owned = type(c.outposts.owned) == 'table' and c.outposts.owned or {};
    c.outposts.verified_owned = type(c.outposts.verified_owned) == 'table' and c.outposts.verified_owned or {};

    c.assault_tags.packet = type(c.assault_tags.packet) == 'table' and c.assault_tags.packet or {};
    c.activity_sessions = type(c.activity_sessions) == 'table' and c.activity_sessions or { next_id=1, active={}, history={} };
    c.activity_sessions.active = type(c.activity_sessions.active) == 'table' and c.activity_sessions.active or {};
    c.activity_sessions.history = type(c.activity_sessions.history) == 'table' and c.activity_sessions.history or {};
    c.reset_history = type(c.reset_history) == 'table' and c.reset_history or {};

    local dk = HC.modules.core.daily_key();
    local wk = HC.modules.core.weekly_key();

    if c.daily_key ~= dk then
        if c.daily_key ~= nil then archive_reset(c,'daily',c.daily_key); end
        if HC.modules.sessions and HC.modules.sessions.reset_scope then pcall(HC.modules.sessions.reset_scope,c,'daily','daily reset'); end
        activity_reset_scope(c,'daily');
        c.daily = {};
        c.daily_key = dk;
        c.plant_pots_daily = {day_key=dk,checked=0,checked_ids={},feed_count=0,fed_ids={},feed_crystals={}};
    end
    if c.plant_pots_daily.day_key ~= dk then
        c.plant_pots_daily = {day_key=dk,checked=0,checked_ids={},feed_count=0,fed_ids={},feed_crystals={}};
        c.daily.plant_pots=nil;
    end
    c.plant_pots_daily.checked_ids=type(c.plant_pots_daily.checked_ids)=='table' and c.plant_pots_daily.checked_ids or {};
    c.plant_pots_daily.fed_ids=type(c.plant_pots_daily.fed_ids)=='table' and c.plant_pots_daily.fed_ids or {};
    c.plant_pots_daily.feed_crystals=type(c.plant_pots_daily.feed_crystals)=='table' and c.plant_pots_daily.feed_crystals or {};
    c.plant_pots_daily.feed_count=math.max(0,math.floor(tonumber(c.plant_pots_daily.feed_count) or 0));
    local pot_count=0; for _ in pairs(c.plant_pots_daily.checked_ids) do pot_count=pot_count+1; end
    if pot_count>0 then c.plant_pots_daily.checked=pot_count; end
    local pot_target=math.max(0,math.min(10,math.floor(tonumber(c.plant_pots.target) or 0)));
    c.plant_pots_daily.checked=math.max(0,math.min(10,math.floor(tonumber(c.plant_pots_daily.checked) or 0)));
    if pot_target>0 then c.daily.plant_pots=(c.plant_pots_daily.checked>=pot_target) and true or nil; end

    if c.weekly_key ~= wk then
        if c.weekly_key ~= nil then archive_reset(c,'weekly',c.weekly_key); end
        if HC.modules.sessions and HC.modules.sessions.reset_scope then pcall(HC.modules.sessions.reset_scope,c,'weekly','conquest reset'); end
        -- Centralized lifecycle cleanup for systems declared as Conquest-reset.
        -- Permanent character progression (for example Outposts and Missions) is excluded by definition.
        activity_reset_scope(c,'conquest');
        local keep_conquest = type(c.outposts)=='table' and c.outposts.permanent_complete==true;
        c.weekly = {};
        if keep_conquest then c.weekly.conquest=true; end
        c.dragon_weekly = {};
        c.weekly_key = wk;
        -- v6.9.57: EXP Ring recharge/replacement completion is Conquest-cycle scoped.
        -- Reset the ring's per-cycle latch here (before any UI draws) so a stale
        -- rw.recharged=true from the previous cycle cannot immediately re-check
        -- c.weekly.exp_ring. Preserve the last observed ring/charges as the new
        -- baseline so a real charge increase this cycle is still auto-detected.
        c.ring_week = type(c.ring_week)=='table' and c.ring_week or {};
        c.ring_week.key = wk;
        c.ring_week.recharged = false;
        c.ring_week.baseline_name = c.ring_week.last_name;
        c.ring_week.baseline_charges = c.ring_week.last_charges;
        if type(c.eco) == 'table' then c.eco.completed_this_week = nil; c.eco.active = nil; end
        if type(c.automation.sessions) == 'table' then c.automation.sessions = {}; end
    end

    reconcile_account_dynamis_current_cycle();
    sync_account_dynamis_mirror(c);
    reconcile_character_state(c);
    return c;
end

function M.reset_ui_settings(c)
    c=c or M.get_char();
    c.settings=type(c.settings)=='table' and c.settings or {};

    -- Reset presentation/preferences only. Never touch progression or tracker state.
    c.settings.developer_mode=false;
    c.settings.onboarding_dismissed=false;
    c.settings.setup_wizard_dismissed=(c.settings.setup_wizard_completed_at~=nil);
    c.settings.hide_completed_weekly=false;
    c.settings.hide_completed_daily=false;
    c.settings.hide_completed_conquest=false;
    c.settings.hide_completed_dragon=false;
    c.settings.hide_completed_missions=false;
    c.settings.hide_completed_quests=false;
    c.settings.hide_completed_assaults=false;
    c.settings.hide_completed_outposts=false;
    c.settings.ui_density='normal';
    c.settings.release_health_expanded=false;
    c.settings.quest_ui_advanced=false;
    c.settings.quest_split_view=false;
    c.settings.quest_candidate_mode='ready';
    c.settings.quest_view='active';
    c.settings.quest_search='';
    c.settings.quest_check_filter='all';
    c.settings.quest_locked_filter='all';
    c.settings.quest_expansion_filter='all';
    c.settings.quest_sort='smart';
    c.settings.quest_active_sort='smart';
    c.settings.quest_ready_sort='smart';

    c.settings.tabs={
        dashboard=true,dailyweekly=true,eco=true,blackcoffin=true,chocobo=true,
        enm=true,assault=true,dynamis=true,missions=true,quests=true,anniversary=true,seasonal=true,seasky=true,
        skills=true,status=true,
    };

    c.settings.notifications={
        mission=true,assault=true,enm=true,digging=true,blackcoffin=true,
        weekly=true,general=true,
    };

    M.save();
    return true;
end

local RETIRED_CHARACTER_FIELDS={
    'compact','compact_mode','activity_snapshot','dashboard_cache','planner_cache','search_cache','why','why_inspector',
};
local RETIRED_SETTING_FIELDS={
    'compact','compact_mode','attention_filter','attention_mode','attention_view','dashboard_filter','dashboard_mode','dashboard_focus','why_inspector','production_ui',
};

local function cleanup_retired_character_state(cc)
    if type(cc)~='table' then return {removed=0,keys={}}; end
    local removed=0; local keys={};
    local function drop(tbl,key,prefix)
        if type(tbl)=='table' and tbl[key]~=nil then tbl[key]=nil; removed=removed+1; keys[#keys+1]=tostring(prefix or '')..tostring(key); end
    end
    for _,k in ipairs(RETIRED_CHARACTER_FIELDS) do drop(cc,k,''); end
    cc.settings=type(cc.settings)=='table' and cc.settings or {};
    for _,k in ipairs(RETIRED_SETTING_FIELDS) do drop(cc.settings,k,'settings.'); end
    -- Retired tab keys from removed UI modes are safe to prune without touching
    -- user choices for active tabs.
    if type(cc.settings.tabs)=='table' then
        for _,k in ipairs({'compact','activity_snapshot','why'}) do drop(cc.settings.tabs,k,'settings.tabs.'); end
    end
    -- Old transient UI caches were never progression evidence. Keep the durable
    -- history/progression tables untouched.
    cc.state_cleanup=type(cc.state_cleanup)=='table' and cc.state_cleanup or {};
    cc.state_cleanup.last_at=os.time(); cc.state_cleanup.removed=removed; cc.state_cleanup.keys=keys; cc.state_cleanup.schema=CURRENT_SCHEMA;
    return {removed=removed,keys=keys};
end

function M.cleanup_retired(c,save_after)
    c=c or M.get_char(); local r=cleanup_retired_character_state(c);
    if r.removed>0 and save_after~=false then M.request_save(1); end
    return deepcopy(r);
end

function M.cleanup_all_retired(save_after)
    local total=0; local characters=0; local keys={};
    state.chars=type(state.chars)=='table' and state.chars or {};
    for name,cc in pairs(state.chars) do
        if type(cc)=='table' then
            local r=cleanup_retired_character_state(cc);
            if (tonumber(r.removed) or 0)>0 then
                characters=characters+1; total=total+(tonumber(r.removed) or 0);
                for _,k in ipairs(r.keys or {}) do keys[#keys+1]=tostring(name)..'.'..tostring(k); end
            end
        end
    end
    state.account=type(state.account)=='table' and state.account or {};
    state.account.last_state_cleanup={at=os.time(),schema=CURRENT_SCHEMA,removed=total,characters=characters};
    if total>0 and save_after~=false then M.request_save(1); end
    return {removed=total,characters=characters,keys=keys,schema=CURRENT_SCHEMA};
end

function M.cleanup_status(c)
    c=c or M.get_char(); local s=type(c.state_cleanup)=='table' and c.state_cleanup or {};
    return deepcopy({at=s.last_at,removed=tonumber(s.removed) or 0,keys=s.keys or {},schema=tonumber(s.schema) or 0});
end

function M.draw_cleanup(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    c=c or M.get_char(); local s=M.cleanup_status(c);
    imgui.Text('State Cleanup / Migration Pruning');
    imgui.TextDisabled('Removes retired UI/cache fields only. Progression, evidence, manual checkboxes and historical proof are never pruned by this pass.');
    imgui.Text(string.format('State schema: %d | Last cleanup removed: %d field(s)',CURRENT_SCHEMA,s.removed or 0));
    if s.at then imgui.TextDisabled('Last cleanup: '..os.date('%Y-%m-%d %H:%M:%S',s.at)); end
    if #(s.keys or {})>0 and imgui.CollapsingHeader('Removed Fields##hc_state_cleanup_fields') then
        for _,k in ipairs(s.keys or {}) do imgui.TextDisabled(tostring(k)); end
    end
    if imgui.Button('Run Safe State Cleanup##hc_state_cleanup_run') then
        local r=M.cleanup_retired(c,true); HC.msg('State cleanup: removed '..tostring(r.removed or 0)..' retired field(s).');
    end
end

local function apply_schema_migrations(oldschema)
    state.account=type(state.account)=='table' and state.account or {};
    state.account_weekly=type(state.account_weekly)=='table' and state.account_weekly or {};
    state.chars=type(state.chars)=='table' and state.chars or {};

    local c=M.get_char();
    M.get_account_weekly();

    -- Retain the proven legacy cleanup from earlier releases.
    reconcile_account_dynamis_current_cycle();
    sync_account_dynamis_mirror(c);

    if type(c.outposts)=='table' then
        local o=c.outposts;
        o.owned=type(o.owned)=='table' and o.owned or {};
        o.verified_owned=type(o.verified_owned)=='table' and o.verified_owned or {};
        if o.auto_endpoint=='GUSTABERG ONLY'
            or o.last_packet_kind=='GUSTABERG_ONLY'
            or o.last_classifier_kind=='GUSTABERG_ONLY'
            or o.last_raw_classifier=='GUSTABERG_ONLY'
            or (o.last_raw_a=='00 01 00' and o.last_raw_b=='0A 00 00')
            or (o.last_packet_a=='00 01 00' and o.last_packet_b=='0A 00 00')
        then
            o.verified_owned.gustaberg=true;
            o.owned.gustaberg=true;
        end
        if o.auto_endpoint=='ALL' then
            o.restore_all_from_endpoint=true;
        elseif o.auto_endpoint=='NONE' then
            o.restore_none_from_endpoint=true;
        end
    end

    -- Schema 24 prunes retired presentation/cache fields while preserving all
    -- progression and evidence. The migration remains guarded by the existing
    -- mandatory backup + validation + automatic rollback flow.
    local cleanup_total=0;
    for _,cc in pairs(state.chars) do
        if type(cc)=='table' then
            cc.settings=type(cc.settings)=='table' and cc.settings or {};
            if cc.settings.setup_wizard_dismissed==nil then cc.settings.setup_wizard_dismissed=false; end
            cc.release_health=type(cc.release_health)=='table' and cc.release_health or {};
            local cr=cleanup_retired_character_state(cc); cleanup_total=cleanup_total+(tonumber(cr.removed) or 0);
            cc.schema_version=CURRENT_SCHEMA;
        end
    end
    state.account.last_state_cleanup={at=os.time(),schema=CURRENT_SCHEMA,removed=cleanup_total};
    c.schema_version=CURRENT_SCHEMA;

    -- Preserve account Assault Tag migration semantics.
    pcall(M.migrate_account_assault_tags,true);
    return true;
end

function M.migrate()
    local oldschema=tonumber(state.schema) or 1;
    migration_runtime.at=os.time();
    migration_runtime.from_schema=oldschema;
    migration_runtime.to_schema=CURRENT_SCHEMA;
    migration_runtime.attempted=true;

    if init_load_error then
        migration_runtime.failed=true;
        migration_runtime.current=false;
        migration_runtime.last_result='state load failed; original file left untouched';
        migration_runtime.validation=init_load_error;
        return false,init_load_error;
    end
    if oldschema>CURRENT_SCHEMA then
        migration_runtime.failed=true;
        migration_runtime.current=false;
        migration_runtime.last_result='state was created by a newer HorizonCheck schema';
        migration_runtime.validation='refusing to downgrade schema '..tostring(oldschema)..' to '..tostring(CURRENT_SCHEMA);
        return false,migration_runtime.validation;
    end
    if oldschema==CURRENT_SCHEMA then
        local valid,issues=validate_state_table(state);
        migration_runtime.failed=not valid;
        migration_runtime.current=valid;
        migration_runtime.last_result=valid and 'already current' or 'current schema failed validation';
        migration_runtime.validation=valid and 'PASS' or table.concat(issues,'; ');
        return valid,migration_runtime.validation;
    end

    local original=deepcopy(loaded_state_snapshot or state);
    local backup=create_migration_backup(oldschema,CURRENT_SCHEMA);
    migration_runtime.backup_path=backup;
    if not backup then
        migration_runtime.failed=true;
        migration_runtime.current=false;
        migration_runtime.last_result='migration not started; pre-migration backup could not be created';
        migration_runtime.validation='state file was left unchanged';
        return false,migration_runtime.last_result;
    end

    local ok,err=pcall(apply_schema_migrations,oldschema);
    if not ok then
        state=original;
        if backup then copy_file(backup,path); end
        migration_runtime.failed=true;
        migration_runtime.rolled_back=true;
        migration_runtime.current=false;
        migration_runtime.last_result='migration failed; automatic rollback completed';
        migration_runtime.validation=tostring(err);
        return false,tostring(err);
    end

    state.schema=CURRENT_SCHEMA;
    state.account=type(state.account)=='table' and state.account or {};
    state.account.migration_history=type(state.account.migration_history)=='table' and state.account.migration_history or {};
    state.account.migration_history[#state.account.migration_history+1]={
        at=os.time(),from_schema=oldschema,to_schema=CURRENT_SCHEMA,
        version=HC and HC.version or nil,backup=backup,result='SUCCESS',
    };
    while #state.account.migration_history>12 do table.remove(state.account.migration_history,1); end

    local valid,issues=validate_state_table(state);
    if not valid then
        state=original;
        if backup then copy_file(backup,path); end
        migration_runtime.failed=true;
        migration_runtime.rolled_back=true;
        migration_runtime.current=false;
        migration_runtime.last_result='validation failed; automatic rollback completed';
        migration_runtime.validation=table.concat(issues,'; ');
        return false,migration_runtime.validation;
    end

    local saved=save_now();
    local verified,verify_err=nil,nil;
    if saved then verified,verify_err=load_state_file(path); end
    if not saved or not verified then
        state=original;
        if backup then copy_file(backup,path); end
        migration_runtime.failed=true;
        migration_runtime.rolled_back=true;
        migration_runtime.current=false;
        migration_runtime.last_result='save verification failed; automatic rollback completed';
        migration_runtime.validation=tostring(verify_err or 'state save failed');
        return false,migration_runtime.validation;
    end

    state=verified;
    loaded_state_snapshot=deepcopy(state);
    migration_runtime.failed=false;
    migration_runtime.rolled_back=false;
    migration_runtime.current=true;
    migration_runtime.last_result='schema '..tostring(oldschema)..' -> '..tostring(CURRENT_SCHEMA)..' successful';
    migration_runtime.validation='PASS';
    return true,migration_runtime.last_result;
end

function M.raw() return state; end

function M.command(w)
    local sub = string.lower(w[2] or '');
    if sub == 'reset' then
        local which = string.lower(w[3] or '');
        local c = M.get_char();
        if which == 'daily' then
            archive_reset(c,'daily',c.daily_key);
            if HC.modules.sessions then HC.modules.sessions.reset_scope(c,'daily','manual daily reset'); end
            c.daily = {};
            c.daily_key = HC.modules.core.daily_key();
            M.save(); HC.msg('Daily checklist reset and archived.'); return true;
        elseif which == 'weekly' then
            archive_reset(c,'weekly',c.weekly_key);
            if HC.modules.sessions then HC.modules.sessions.reset_scope(c,'weekly','manual weekly reset'); end
            local keep_conquest = type(c.outposts)=='table' and c.outposts.permanent_complete==true;
            c.weekly = {};
            if keep_conquest then c.weekly.conquest=true; end
            c.dragon_weekly = {};
            c.weekly_key = HC.modules.core.weekly_key();
            c.ring_week = type(c.ring_week)=='table' and c.ring_week or {};
            c.ring_week.key = c.weekly_key;
            c.ring_week.recharged = false;
            c.ring_week.baseline_name = c.ring_week.last_name;
            c.ring_week.baseline_charges = c.ring_week.last_charges;
            c.automation.sessions = {};
            state.account_weekly={
                weekly_key=HC.modules.core.weekly_key(),
                dynamis_count=0
            };
            sync_account_dynamis_mirror(c);
            M.save(); HC.msg('Weekly checklist reset and archived, including account-wide Dynamis.'); return true;
        end
    end
    return false;
end

return M;
