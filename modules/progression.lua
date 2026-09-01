local M = {};
local HC;

local facts_by_char={};
local last_poll=0;
local dirty=true;
local dirty_due=0;
local dirty_sources={};
local BATCH_SECONDS=1;
local FALLBACK_SECONDS=60;

local CANONICAL={
    UNKNOWN=true,LOCKED=true,AVAILABLE=true,PREP=true,READY=true,ACTIVE=true,COMPLETE=true,COOLDOWN=true,
};
local ALIAS={
    ['DONE']='COMPLETE',['CLEARED']='COMPLETE',['COMPLETED']='COMPLETE',['COMPLETED THIS WEEK']='COMPLETE',
    ['DONE THIS WEEK']='COMPLETE',['DONE TODAY']='COMPLETE',['CAPPED']='COMPLETE',
    ['KEY ITEM READY']='READY',['TURN IN']='READY',['IN PROGRESS']='ACTIVE',['RUN IN PROGRESS']='ACTIVE',
    ['VERIFY']='UNKNOWN',['CHECK']='UNKNOWN',['UNKNOWN RESET']='UNKNOWN',['WAITING']='COOLDOWN',
    ['COUNTING DOWN']='COOLDOWN',['SOON']='COOLDOWN',['BLOCKED']='LOCKED',
};

local SOURCE_RANK={
    server_bitmap=100,saved_permanent=95,native_packet=90,dialogue=85,inventory=75,system_engine=70,
    historical=60,manual=50,inferred=40,unknown=0,
};

local CRITICAL_KI={
    {id=734,name='Cosmo-Cleanse',key='ki:cosmo_cleanse',owned_state='READY'},
    {id=486,name='Hydra Corps Command Scepter',key='ki:dynamis_sandoria',owned_state='COMPLETE'},
    {id=487,name='Hydra Corps Eyeglass',key='ki:dynamis_bastok',owned_state='COMPLETE'},
    {id=488,name='Hydra Corps Lantern',key='ki:dynamis_windurst',owned_state='COMPLETE'},
    {id=489,name='Hydra Corps Tactical Map',key='ki:dynamis_jeuno',owned_state='COMPLETE'},
    {id=490,name='Hydra Corps Insignia',key='ki:dynamis_beaucedine',owned_state='COMPLETE'},
    {id=491,name='Hydra Corps Battle Standard',key='ki:dynamis_xarcabard',owned_state='COMPLETE'},
    {id=739,name='Dynamis - Valkurm sliver',key='ki:dynamis_valkurm',owned_state='COMPLETE'},
    {id=740,name='Dynamis - Buburimu sliver',key='ki:dynamis_buburimu',owned_state='COMPLETE'},
    {id=741,name='Dynamis - Qufim sliver',key='ki:dynamis_qufim',owned_state='COMPLETE'},
    {id=742,name='Dynamis - Tavnazia sliver',key='ki:dynamis_tavnazia',owned_state='COMPLETE'},
};

local function char_name()
    return tostring((HC and HC.modules and HC.modules.core and HC.modules.core.character_name and HC.modules.core.character_name()) or 'Unknown');
end

local function fact_store()
    local name=char_name(); facts_by_char[name]=facts_by_char[name] or {}; return facts_by_char[name];
end

function M.normalize_state(state)
    local s=string.upper(tostring(state or 'UNKNOWN'));
    s=s:gsub('^%s+',''):gsub('%s+$','');
    if CANONICAL[s] then return s; end
    if ALIAS[s] then return ALIAS[s]; end
    if s:find('COOLDOWN',1,true) or s:find('WAITING',1,true) then return 'COOLDOWN'; end
    if s:find('READY',1,true) or s:find('AVAILABLE',1,true) then return s:find('READY',1,true) and 'READY' or 'AVAILABLE'; end
    if s:find('ACTIVE',1,true) or s:find('IN PROGRESS',1,true) then return 'ACTIVE'; end
    if s:find('COMPLETE',1,true) or s:find('CLEARED',1,true) or s:find('DONE',1,true) then return 'COMPLETE'; end
    if s:find('LOCK',1,true) then return 'LOCKED'; end
    return 'UNKNOWN';
end

local function rank_for(source,opts)
    opts=type(opts)=='table' and opts or {};
    if tonumber(opts.rank) then return tonumber(opts.rank); end
    local s=string.lower(tostring(opts.source_type or source or 'unknown'));
    s=s:gsub('[^%w]+','_');
    if s:find('0x055',1,true) or s:find('bitmap',1,true) then return SOURCE_RANK.server_bitmap; end
    if s:find('saved_permanent',1,true) or s:find('saved permanent',1,true) then return SOURCE_RANK.saved_permanent; end
    if s:find('native',1,true) or s:find('packet',1,true) then return SOURCE_RANK.native_packet; end
    if s:find('dialogue',1,true) or s:find('npc',1,true) then return SOURCE_RANK.dialogue; end
    if s:find('inventory',1,true) then return SOURCE_RANK.inventory; end
    if s:find('system',1,true) then return SOURCE_RANK.system_engine; end
    if s:find('histor',1,true) then return SOURCE_RANK.historical; end
    if s:find('manual',1,true) then return SOURCE_RANK.manual; end
    return SOURCE_RANK.inferred;
end

local function ensure_progression(c)
    c.progression=type(c.progression)=='table' and c.progression or {};
    c.progression.last_states=type(c.progression.last_states)=='table' and c.progression.last_states or {};
    return c.progression;
end

function M.observe(c,key,state,opts)
    c=c or HC.modules.state.get_char(); opts=type(opts)=='table' and opts or {};
    key=tostring(key or ''); if key=='' then return nil; end
    local store=fact_store();
    store[key]=store[key] or {key=key,sources={}};
    local source=tostring(opts.source or opts.source_id or 'unknown');
    local source_id=string.lower(source):gsub('[^%w]+','_'); if source_id=='' then source_id='unknown'; end
    local rec={
        state=M.normalize_state(state),raw_state=tostring(state or ''),source=source,source_id=source_id,
        rank=rank_for(source,opts),at=tonumber(opts.at) or os.time(),detail=opts.detail,evidence=opts.evidence,
        meta=opts.meta,
    };
    store[key].sources[source_id]=rec;
    return M.resolve(c,key);
end

function M.resolve(c,key)
    c=c or HC.modules.state.get_char(); key=tostring(key or '');
    local store=fact_store(); local f=store[key];
    if not f then return {key=key,state='UNKNOWN',source='no evidence',rank=0}; end
    local rows={}; for _,r in pairs(f.sources or {}) do rows[#rows+1]=r; end
    table.sort(rows,function(a,b)
        if (tonumber(a.rank) or 0)~=(tonumber(b.rank) or 0) then return (tonumber(a.rank) or 0)>(tonumber(b.rank) or 0); end
        return (tonumber(a.at) or 0)>(tonumber(b.at) or 0);
    end);
    local w=rows[1]; if not w then return {key=key,state='UNKNOWN',source='no evidence',rank=0}; end
    return {key=key,state=w.state,raw_state=w.raw_state,source=w.source,rank=w.rank,at=w.at,detail=w.detail,evidence=w.evidence,meta=w.meta,rows=rows};
end

local function transition_if_changed(c,key,label,res,reason)
    local p=ensure_progression(c); local old=p.last_states[key]; local new=res and res.state or 'UNKNOWN';
    local changed=(old~=new);
    if old~=nil and changed and HC.modules.timeline and HC.modules.timeline.transition then
        HC.modules.timeline.transition(c,key,label or key,old,new,{
            source=res.source or reason or 'progression engine',evidence=res.evidence,scope='character',dedupe_seconds=1,
        });
    end
    p.last_states[key]=new;
    return changed;
end

local function observe_systems(c)
    local systems=HC.modules.systems;
    if not systems or not systems.snapshot then return false; end
    -- Reuse Systems' shared snapshot cache. Forcing this every reconcile rebuilt
    -- all activity engines even when no authoritative input had changed.
    local ok,snap=pcall(systems.snapshot,c,false); if not ok or type(snap)~='table' then return false; end
    local changed=false;
    for id,row in pairs(snap.systems or {}) do
        local key='system:'..tostring(id);
        local res=M.observe(c,key,row.state,{source='system engine',source_type='system_engine',rank=70,
            detail=row.reason,evidence=row.reset,meta={label=row.label,id=id}});
        if transition_if_changed(c,key,row.label or id,res,'system engine') then changed=true; end
    end
    return changed;
end

local function observe_critical_kis(c)
    local ki=HC.modules.keyitems; if not ki or not ki.ownership_id then return false; end
    local changed=false;
    for _,def in ipairs(CRITICAL_KI) do
        local ok,owned,err,id,source=pcall(ki.ownership_id,def.id,def.name);
        if ok then
            local state='UNKNOWN';
            if owned==true then state=def.owned_state or 'READY'; elseif owned==false then state='AVAILABLE'; end
            local res=M.observe(c,def.key,state,{source=source or 'key-item ownership',detail=err,evidence='KI '..tostring(id or def.id),
                meta={id=id or def.id,name=def.name,owned=owned}});
            if transition_if_changed(c,def.key,def.name,res,'key-item ownership') then changed=true; end
        end
    end
    return changed;
end

local function observe_unlocks(c)
    local u=HC.modules.unlocks; if not u or not u.snapshot then return false; end
    local ok,s=pcall(u.snapshot,c,false); if not ok or type(s)~='table' then return false; end
    local changed=false;
    for _,r in ipairs(s.rows or {}) do
        local state='UNKNOWN'; if r.owned==true then state='COMPLETE'; elseif r.owned==false then state='AVAILABLE'; end
        local source_type=(tostring(r.source or ''):find('0x055',1,true) and 'server_bitmap') or (tostring(r.source or ''):find('saved',1,true) and 'saved_permanent') or 'system_engine';
        local res=M.observe(c,'unlock:'..tostring(r.key),state,{source='unlock registry: '..tostring(r.source or ''),source_type=source_type,
            detail=r.category,evidence='KI '..tostring(r.id or '?'),meta={id=r.id,name=r.name,category=r.category,owned=r.owned}});
        if transition_if_changed(c,'unlock:'..tostring(r.key),r.name,res,'unlock registry') then changed=true; end
    end
    return changed;
end

function M.reconcile(c,opts)
    c=c or HC.modules.state.get_char(); opts=type(opts)=='table' and opts or {};
    local p=ensure_progression(c); local changed=false;
    if observe_systems(c) then changed=true; end
    if observe_critical_kis(c) then changed=true; end
    if observe_unlocks(c) then changed=true; end
    p.last_reconcile_at=os.time(); p.last_reason=tostring(opts.reason or 'periodic reconcile');
    if changed and HC.modules.state and HC.modules.state.request_save then HC.modules.state.request_save(1); end
    dirty=false; dirty_due=0; dirty_sources={}; last_poll=p.last_reconcile_at;
    if HC.modules.profiler and HC.modules.profiler.bump then
        HC.modules.profiler.bump('progression.reconcile');
        if changed then HC.modules.profiler.bump('progression.changed'); end
    end
    return M.snapshot(c);
end

function M.invalidate(source,reason)
    dirty=true;
    dirty_due=os.time()+BATCH_SECONDS;
    dirty_sources[tostring(source or 'unknown')]=tostring(reason or 'authoritative state changed');
    if HC and HC.modules and HC.modules.profiler and HC.modules.profiler.bump then HC.modules.profiler.bump('progression.invalidate'); end
    return true;
end

function M.snapshot(c)
    c=c or HC.modules.state.get_char(); local store=fact_store(); local out={generated_at=os.time(),records={},counts={}};
    for key,f in pairs(store) do
        local r=M.resolve(c,key); out.records[key]=r; out.counts[r.state]=(out.counts[r.state] or 0)+1;
    end
    return out;
end

function M.get(key,c) return M.resolve(c,key); end
function M.all(c) return M.snapshot(c).records; end
function M.source_rank(name) return rank_for(name,{}); end

function M.poll()
    if not HC.modules.state or not HC.modules.state.profile_ready or not HC.modules.state.profile_ready() then return; end
    local now=os.time();
    if dirty and now>=dirty_due then
        return M.reconcile(HC.modules.state.get_char(),{reason='event-driven reconcile'});
    end
    if not dirty and (last_poll==0 or now-last_poll>=FALLBACK_SECONDS) then
        return M.reconcile(HC.modules.state.get_char(),{reason='fallback safety reconcile'});
    end
end

function M.draw(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local snap=M.reconcile(c,{reason='diagnostics'});
    imgui.Text('Central Progression State Engine');
    imgui.TextDisabled('Canonical states: UNKNOWN / LOCKED / AVAILABLE / PREP / READY / ACTIVE / COMPLETE / COOLDOWN.');
    imgui.TextDisabled('Evidence priority: server bitmap > permanent proof > native packet > dialogue > inventory > system engine > history > manual/inferred.');
    local keys={}; for k in pairs(snap.records or {}) do keys[#keys+1]=k; end; table.sort(keys);
    for _,key in ipairs(keys) do
        local r=snap.records[key];
        imgui.Text(string.format('%-28s  %-9s',tostring(key),tostring(r.state)));
        imgui.SameLine(); imgui.TextDisabled(tostring(r.source or '')..(r.detail and (' | '..tostring(r.detail)) or ''));
    end
end

function M.status(c)
    c=c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    local p=ensure_progression(c); local snap=M.snapshot(c); local n=0; for _ in pairs(snap.records) do n=n+1; end
    return {records=n,counts=snap.counts,last_reconcile_at=p.last_reconcile_at,last_reason=p.last_reason};
end

function M.command(w)
    local sub=string.lower(w[2] or ''); if sub~='progression' and sub~='progress' then return false; end
    local c=HC.modules.state.get_char(); local s=M.reconcile(c,{reason='manual command'}); local n=0; for _ in pairs(s.records or {}) do n=n+1; end
    HC.msg('Progression state engine reconciled '..tostring(n)..' fact(s).'); return true;
end

function M.init(ctx) HC=ctx; dirty=true; dirty_due=0; last_poll=0; end
return M;
