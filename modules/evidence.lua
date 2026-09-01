local M = {};
local HC;

-- HorizonCheck Evidence Resolver
--
-- Every detector can publish observations about a fact without directly
-- overwriting another detector's result.  Resolution is tri-state:
--   true / false / nil (UNKNOWN)
-- and is driven by explicit source rank, confidence, and recency.
--
-- Higher rank wins.  Within the same rank, the newest observation wins.
-- UNKNOWN observations never turn into false by accident.

local facts = {};
local providers = {};
local seq = 0;
local last_refresh = nil;

local CONFIDENCE_RANK = {
    VERIFIED = 90,
    LIVE = 80,
    NATIVE = 70,
    CONFIRMED = 60,
    INFERRED = 40,
    PROFILE = 30,
    CATALOG = 20,
    UNKNOWN = 0,
};

local function now() return os.time(); end

local function norm_key(s)
    s=string.lower(tostring(s or ''));
    s=s:gsub('’', "'"):gsub('`', "'");
    s=s:gsub('[^%w%._:%-]+','_');
    s=s:gsub('_+','_'):gsub('^_+',''):gsub('_+$','');
    return s;
end

local function normalize_confidence(s)
    s=string.upper(tostring(s or 'UNKNOWN'));
    if CONFIDENCE_RANK[s]==nil then s='UNKNOWN'; end
    return s;
end

local function value_state(v)
    if v==true then return 'TRUE'; end
    if v==false then return 'FALSE'; end
    if v==nil then return 'UNKNOWN'; end
    return 'VALUE';
end

local function same_value(a,b)
    if a==nil or b==nil then return true; end
    return type(a)==type(b) and a==b;
end

local function default_rank(confidence)
    return CONFIDENCE_RANK[normalize_confidence(confidence)] or 0;
end

local function copy_row(r)
    if type(r)~='table' then return nil; end
    local out={};
    for k,v in pairs(r) do out[k]=v; end
    return out;
end

-- Pure resolver used by the live store and the regression suite.
function M.resolve_rows(rows)
    local candidates={};
    for _,r in ipairs(type(rows)=='table' and rows or {}) do
        if type(r)=='table' then
            local expires_at=tonumber(r.expires_at);
            if not expires_at or expires_at>=now() then
                candidates[#candidates+1]=r;
            end
        end
    end
    table.sort(candidates,function(a,b)
        local ar=tonumber(a.rank) or default_rank(a.confidence);
        local br=tonumber(b.rank) or default_rank(b.confidence);
        if ar~=br then return ar>br; end
        local aa=tonumber(a.at) or 0; local ba=tonumber(b.at) or 0;
        if aa~=ba then return aa>ba; end
        return (tonumber(a.seq) or 0)>(tonumber(b.seq) or 0);
    end);

    local winner=candidates[1];
    if not winner then
        return {value=nil,state='UNKNOWN',confidence='UNKNOWN',source='no evidence',rank=0,at=nil,conflict=false,rows={}};
    end

    local conflict=false;
    local winner_state=value_state(winner.value);
    if winner_state~='UNKNOWN' then
        for i=2,#candidates do
            local other=candidates[i];
            if value_state(other.value)~='UNKNOWN' and not same_value(winner.value,other.value) then conflict=true; break; end
        end
    end

    return {
        value=winner.value,
        state=winner_state,
        confidence=normalize_confidence(winner.confidence),
        source=tostring(winner.source or winner.source_id or 'unknown source'),
        source_id=tostring(winner.source_id or winner.source or 'unknown'),
        rank=tonumber(winner.rank) or default_rank(winner.confidence),
        at=winner.at,
        seq=winner.seq,
        details=winner.details,
        meta=winner.meta,
        conflict=conflict,
        rows=candidates,
    };
end

function M.submit(key,value,opts)
    key=norm_key(key);
    if key=='' then return nil,'invalid evidence key'; end
    opts=type(opts)=='table' and opts or {};
    local source_id=norm_key(opts.source_id or opts.source or 'unknown');
    if source_id=='' then source_id='unknown'; end
    local confidence=normalize_confidence(opts.confidence);
    seq=seq+1;
    local rec={
        key=key,
        value=value,
        state=value_state(value),
        confidence=confidence,
        source=tostring(opts.source or opts.source_id or 'unknown'),
        source_id=source_id,
        rank=tonumber(opts.rank) or default_rank(confidence),
        at=tonumber(opts.at) or now(),
        seq=seq,
        details=opts.details,
        meta=opts.meta,
        expires_at=opts.expires_at,
        persistent=opts.persistent==true,
    };
    facts[key]=facts[key] or {key=key,sources={}};
    facts[key].sources[source_id]=rec;
    facts[key].updated_at=rec.at;
    return M.resolve(key),nil;
end

function M.resolve(key)
    key=norm_key(key);
    local f=facts[key];
    if not f then return M.resolve_rows({}); end
    local rows={};
    for _,r in pairs(f.sources or {}) do rows[#rows+1]=r; end
    local result=M.resolve_rows(rows);
    result.key=key;
    return result;
end

function M.clear(key,source_id)
    key=norm_key(key);
    if key=='' then return false; end
    if not facts[key] then return false; end
    if source_id then
        source_id=norm_key(source_id);
        facts[key].sources[source_id]=nil;
        if next(facts[key].sources)==nil then facts[key]=nil; end
    else
        facts[key]=nil;
    end
    return true;
end

function M.clear_prefix(prefix)
    prefix=norm_key(prefix);
    local n=0;
    for key in pairs(facts) do
        if prefix=='' or key:sub(1,#prefix)==prefix then facts[key]=nil; n=n+1; end
    end
    return n;
end

function M.register_provider(name,fn)
    if type(name)~='string' or type(fn)~='function' then return false; end
    providers[norm_key(name)]=fn;
    return true;
end

function M.refresh()
    local errs={};
    for name,fn in pairs(providers) do
        local ok,err=pcall(fn);
        if not ok then errs[#errs+1]=name..': '..tostring(err); end
    end
    last_refresh=now();
    return #errs==0,errs;
end

function M.inspect(filter,limit)
    filter=string.lower(tostring(filter or ''));
    limit=math.max(1,math.min(250,tonumber(limit) or 80));
    local rows={};
    for key in pairs(facts) do
        local r=M.resolve(key);
        local hay=string.lower(key..' '..tostring(r.source or '')..' '..tostring(r.details or ''));
        if filter=='' or hay:find(filter,1,true) then
            rows[#rows+1]=r;
        end
    end
    table.sort(rows,function(a,b)
        if a.state~=b.state then
            local w={TRUE=1,VALUE=1,FALSE=2,UNKNOWN=3};
            return (w[a.state] or 9)<(w[b.state] or 9);
        end
        return tostring(a.key)<tostring(b.key);
    end);
    while #rows>limit do table.remove(rows); end
    return rows;
end

function M.source_rows(key)
    local r=M.resolve(key);
    local out={};
    for _,row in ipairs(r.rows or {}) do out[#out+1]=copy_row(row); end
    return out;
end

function M.status()
    local n=0; for _ in pairs(facts) do n=n+1; end
    local p=0; for _ in pairs(providers) do p=p+1; end
    return {facts=n,providers=p,last_refresh=last_refresh};
end

function M.confidence_rank(name) return default_rank(name); end
function M.normalize_key(s) return norm_key(s); end

function M.command(w,raw)
    local sub=string.lower(w[2] or '');
    if sub~='evidence' and sub~='ev' then return false; end
    local action=string.lower(w[3] or 'status');
    if action=='refresh' then
        local ok,errs=M.refresh();
        if HC then HC.msg(ok and 'Evidence refresh complete.' or ('Evidence refresh completed with '..tostring(#errs)..' error(s).')); end
        return true;
    end
    local filter='';
    if action~='status' and action~='list' then filter=tostring(w[3] or ''); end
    local rows=M.inspect(filter,20);
    if HC then
        HC.msg(string.format('Evidence Inspector: %d fact(s)%s.',#rows,filter~='' and (' matching "'..filter..'"') or ''));
        for _,r in ipairs(rows) do
            local shown=(r.state=='VALUE') and tostring(r.value) or r.state;
            HC.msg(string.format('%s = %s [%s] %s%s',r.key,shown,r.confidence,r.source,r.conflict and ' [CONFLICT]' or ''));
        end
    end
    return true;
end

function M.init(ctx) HC=ctx; end
return M;
