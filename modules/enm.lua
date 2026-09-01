local M = {};
local HC;
local CD = 5 * 24 * 60 * 60;
local moritz_pending={ group_id=nil, selected_at=0, source=nil };
local moritz_last_result_at=0;
local MORITZ_ARM_SECONDS=20;
local venessa_pending_group=nil;
local venessa_pending_at=0;
local VENESSA_PENDING_SECONDS=30;
local MAX_REASONABLE_COOLDOWN_SECONDS=7 * 24 * 60 * 60;
local PAST_READY_GRACE_SECONDS=24 * 60 * 60;
local KI_ACQUISITION_HINT_SECONDS=30;

-- Session-local ownership baselines are intentionally not persisted. A true
-- 0x055 bit seen for the first time after addon load only proves the KI is
-- currently held; it does not reveal when the five-day timer started. Only a
-- false -> true transition observed during the current session starts a timer.
local ki_session_by_character={};
local ki_hint_by_character={};

local MONTHS = {
    jan=1,feb=2,mar=3,apr=4,may=5,jun=6,
    jul=7,aug=8,sep=9,oct=10,nov=11,dec=12,
};

local groups = {
    { id='promy_dem', name='Promyvion - Dem', key_item='Censer of Antipathy', enms={'You Are What You Eat'} },
    { id='promy_holla', name='Promyvion - Holla', key_item='Censer of Abandonment', enms={'Simulant'} },
    { id='promy_mea', name='Promyvion - Mea', key_item='Censer of Animus', enms={'Playing Host'} },
    { id='promy_vahzl', name='Promyvion - Vahzl', key_item='Censer of Acrimony', enms={'Pulling the Plug'} },
    { id='monarch_linn', name='Monarch Linn', key_item='Monarch Beard', enms={'Fire in the Sky','Bad Seed','Bugard in the Clouds','Beloved of the Atlantes'} },
    { id='shrouded_maw', name='The Shrouded Maw', key_item='Astral Covenant', enms={'Test Your Mite'} },
    { id='mine_2716', name='Mine Shaft #2716', key_item='Shaft Gate Operating Dial', enms={'Pulling the Strings','Automaton Assault','Bionic Bug'} },
    { id='bearclaw', name='Bearclaw Pinnacle', key_item='Zephyr Fan', enms={'When Hell Freezes Over','Brothers','Follow the White Rabbit','Holy Cow'} },
    { id='boneyard', name='Boneyard Gully', key_item='Miasma Filter', enms={'Like the Wind',"Sheep in Antlion's Clothing",'Shell We Dance?','Totentanz'} },
};


local function ensure_runtime(c)
    c.enm_runtime=type(c.enm_runtime)=='table' and c.enm_runtime or {};
    return c.enm_runtime;
end

local function session_character_key()
    local name='unknown';
    if HC and HC.modules and HC.modules.core and HC.modules.core.character_name then
        local ok,value=pcall(HC.modules.core.character_name);
        if ok and value and tostring(value)~='' then name=tostring(value); end
    end
    return string.lower(name);
end

local function session_ownership()
    local key=session_character_key();
    ki_session_by_character[key]=type(ki_session_by_character[key])=='table' and ki_session_by_character[key] or {};
    return ki_session_by_character[key];
end

local function session_hints()
    local key=session_character_key();
    ki_hint_by_character[key]=type(ki_hint_by_character[key])=='table' and ki_hint_by_character[key] or {};
    return ki_hint_by_character[key];
end

local function recent_acquisition_hint(group_id,now)
    local hints=session_hints();
    local hint=hints[group_id];
    if type(hint)~='table' then return nil; end
    now=tonumber(now) or os.time();
    if now-(tonumber(hint.observed_at) or 0)>KI_ACQUISITION_HINT_SECONDS then
        hints[group_id]=nil;
        return nil;
    end
    return hint;
end

local lifecycle;

local function set_prereq(c,group_id,state,source)
    local r=ensure_runtime(c);
    r.prereq=type(r.prereq)=='table' and r.prereq or {};
    if state==nil then
        r.prereq[group_id]=nil;
    else
        r.prereq[group_id]={
            state=state,
            verified_at=os.time(),
            source=source or 'ENM prerequisite evidence',
        };
    end
    -- Keep the legacy Boneyard field synchronized for old saved states/UI.
    if group_id=='boneyard' then r.boneyard_prereq=r.prereq[group_id]; end
    if state~=nil then lifecycle(c,group_id,'PREP',source,nil,{stage=state}); end
    HC.modules.state.save();
end

local function set_boneyard_prereq(c,state,source)
    local r=ensure_runtime(c);
    if state==nil then
        r.boneyard_prereq=nil;
    else
        r.boneyard_prereq={
            state=state,
            verified_at=os.time(),
            source=source or 'Boneyard prerequisite evidence',
        };
    end
    if state~=nil then lifecycle(c,'boneyard','PREP',source,nil,{stage=state}); end
    HC.modules.state.save();
end

local function set_bearclaw_prereq(c,state,source)
    set_prereq(c,'bearclaw',state,source);
end

local function prereq_state(c,group_id)
    local r=ensure_runtime(c);
    if type(r.prereq)=='table' and type(r.prereq[group_id])=='table' then return r.prereq[group_id]; end
    if group_id=='boneyard' and type(r.boneyard_prereq)=='table' then return r.boneyard_prereq; end
    return nil;
end

local function set_access_state(c,group_id,state,source)
    local r=ensure_runtime(c);
    r.access=type(r.access)=='table' and r.access or {};
    r.access[group_id]=type(r.access[group_id])=='table' and r.access[group_id] or {};
    local a=r.access[group_id];
    a.state=state;
    a.verified_at=os.time();
    a.source=source;
    if state=='KEY ITEM READY' then lifecycle(c,group_id,'READY',source,nil,{access=state});
    elseif state=='NO KEY ITEM' then lifecycle(c,group_id,'LOCKED',source,a.next_state_at,{access=state}); end
    HC.modules.state.save();
end

local function access_state(c,group_id)
    local r=ensure_runtime(c);
    r.access=type(r.access)=='table' and r.access or {};
    local a=r.access[group_id];
    return type(a)=='table' and a or nil;
end

local function clear_stale_consumed_access(c,group_id,force)
    local r=ensure_runtime(c);
    r.access=type(r.access)=='table' and r.access or {};
    local a=r.access[group_id];
    if type(a)~='table' or a.state~='KEY ITEM CONSUMED' then return false; end

    local active=(type(r.active)=='table' and r.active.group_id==group_id);
    local timer=type(c.enm)=='table' and c.enm[group_id] or nil;
    local cooling=(type(timer)=='table' and tonumber(timer.ready_at) and tonumber(timer.ready_at)>os.time());
    if force==true or (not active and not cooling) then
        r.access[group_id]=nil;
        return true;
    end
    return false;
end

local function find_enm_by_name(name)
    name=string.lower(tostring(name or ''));
    for _,g in ipairs(groups) do
        for _,e in ipairs(g.enms or {}) do
            if string.lower(e)==name then return g,e; end
        end
    end
    return nil,nil;
end

local function begin_battlefield(c, g, enm_name)
    local r=ensure_runtime(c);

    -- Battlefield entry is authoritative proof that the entry key item was
    -- consumed. Never allow an older KEY ITEM READY hint to survive entry.
    r.access=type(r.access)=='table' and r.access or {};
    local timer=type(c.enm)=='table' and c.enm[g.id] or nil;
    local ready_at=type(timer)=='table' and tonumber(timer.ready_at) or nil;
    r.access[g.id]={
        state='KEY ITEM CONSUMED',
        verified_at=os.time(),
        source='Battlefield entry',
        next_state_at=(ready_at and ready_at>os.time()) and ready_at or nil,
    };
    if type(r.prereq)=='table' then r.prereq[g.id]=nil; end
    if g.id=='boneyard' then r.boneyard_prereq=nil; end

    r.active={
        group_id=g.id,
        group_name=g.name,
        enm=enm_name,
        entered_at=os.time(),
        time_limit=(string.lower(tostring(enm_name or ''))=='fire in the sky') and 900 or 900,
        state='ENTERED',
    };
    r.last={
        group_id=g.id,
        group_name=g.name,
        enm=enm_name,
        entered_at=r.active.entered_at,
        state='ENTERED',
    };
    lifecycle(c,g.id,'IN_PROGRESS','Battlefield entry',r.active.entered_at+(3*60*60),{enm=enm_name});
    HC.modules.state.save();
    HC.msg('ENM: Entered '..enm_name..' - '..g.name..'. Battlefield tracker active.');
end


local function b0(data,offset)
    if type(data)~='string' then return nil; end
    return string.byte(data,(tonumber(offset) or 0)+1);
end

local function group_by_id(id)
    for _,g in ipairs(groups) do if g.id==id then return g; end end
    return nil;
end

lifecycle=function(c,id,state,source,expires_at,details)
    if HC.modules.state and HC.modules.state.activity_set then
        HC.modules.state.activity_set(c,'enm',id,state,source,'VERIFIED',expires_at,details,true);
    end
end

local function moritz_select_packet(e)
    if e==nil or e.injected or tonumber(e.id)~=0x05C then return; end
    local data=e.data;
    if type(data)~='string' or #data<12 then return; end

    -- IMPORTANT: timed captures proved bytes 0x08..0x0B change with the
    -- reported Moritz timer and are not a stable ENM-selection identifier.
    -- Keep them as diagnostic evidence only; never use them to choose a row.
    local c=HC.modules.state.get_char();
    local rt=ensure_runtime(c);
    rt.moritz_packet=type(rt.moritz_packet)=='table' and rt.moritz_packet or {};
    rt.moritz_packet.last_seen_at=os.time();
    rt.moritz_packet.byte_08=b0(data,0x08);
    rt.moritz_packet.byte_09=b0(data,0x09);
    rt.moritz_packet.byte_0a=b0(data,0x0A);
    rt.moritz_packet.byte_0b=b0(data,0x0B);
    HC.modules.state.save();
end

local function arm_moritz(id)
    local g=group_by_id(id);
    if not g then return false; end
    moritz_pending={
        group_id=id,
        selected_at=os.time(),
        source='User-armed timer verification',
    };
    HC.msg('Timer verification armed for '..g.name..' for '..tostring(MORITZ_ARM_SECONDS)..' seconds. Select that ENM at Moritz.');
    return true;
end


local function parse_earth_time(s)
    local year,mon,day,hh,mm,ss=s:match(
        '%((%d%d%d%d),%s*([%a]+)%.?%s*(%d%d?),%s*(%d%d?):(%d%d):(%d%d)%s+earth time%)'
    );
    if not year then return nil; end
    mon=MONTHS[string.lower(mon or '')];
    if not mon then return nil; end
    return os.time({
        year=tonumber(year),month=mon,day=tonumber(day),
        hour=tonumber(hh),min=tonumber(mm),sec=tonumber(ss)
    });
end

local function validate_ready_at(ready_at, source)
    ready_at=tonumber(ready_at);
    if not ready_at then return nil,'timestamp parse failed'; end
    local now=os.time();
    local delta=ready_at-now;
    -- Horizon ENM lockouts are roughly five days. Allow some slack for clock
    -- differences, but reject corrupt dates such as Moritz reporting 2058.
    if delta>MAX_REASONABLE_COOLDOWN_SECONDS then
        return nil,'timestamp too far in future';
    end
    if delta<-PAST_READY_GRACE_SECONDS then
        return nil,'timestamp too far in past';
    end
    return ready_at,nil;
end

local function remember_invalid_timer(c, source, id, parsed_at, reason)
    local rt=ensure_runtime(c);
    rt.invalid_timer=type(rt.invalid_timer)=='table' and rt.invalid_timer or {};
    rt.invalid_timer[id or 'unassigned']={
        source=source or 'ENM NPC',
        observed_at=os.time(),
        parsed_at=parsed_at,
        reason=reason or 'invalid timestamp',
    };
    HC.modules.state.save();
end

local function apply_moritz_locked(c,id,ready_at,source)
    local g=group_by_id(id);
    if not g or type(ready_at)~='number' then return false; end
    local valid,reason=validate_ready_at(ready_at,'Moritz');
    if not valid then
        remember_invalid_timer(c,'Moritz',id,ready_at,reason);
        HC.msg('ENM: Ignored implausible Moritz timer for '..g.name..'. Existing state preserved.');
        return false;
    end
    ready_at=valid;

    c.enm[id]=type(c.enm[id])=='table' and c.enm[id] or {};
    local r=c.enm[id];
    r.ready_at=ready_at;
    r.keyitem_at=ready_at-CD;
    r.last=g.name;
    r.moritz_verified_at=os.time();
    r.moritz_source=source or 'Moritz exact Earth-time';
    r.moritz_state='LOCKED';
    r.timer_source='Moritz exact Earth-time';
    r.timer_confidence='NPC VERIFIED';
    clear_stale_consumed_access(c,id,true);
    lifecycle(c,id,'COOLDOWN',source or 'Moritz exact Earth-time',ready_at,{ready_at=ready_at});
    HC.modules.state.save();

    HC.msg('AUTO: ENM '..g.name..' timer verified by Moritz.');
    return true;
end

local function apply_moritz_available(c,id,source)
    local g=group_by_id(id);
    if not g then return false; end

    -- Moritz's "sufficiently manifest" line is authoritative availability.
    c.enm[id]=nil;
    local rt=ensure_runtime(c);
    rt.moritz=type(rt.moritz)=='table' and rt.moritz or {};
    rt.moritz[id]={
        state='AVAILABLE',
        verified_at=os.time(),
        source=source or 'Moritz ready dialogue',
    };
    clear_stale_consumed_access(c,id,true);
    lifecycle(c,id,'AVAILABLE',source or 'Moritz ready dialogue',nil,{authoritative=true});
    HC.modules.state.save();

    HC.msg('AUTO: ENM '..g.name..' AVAILABLE [VERIFIED BY MORITZ].');
    return true;
end

local function handle_moritz_text(c,s)
    if not s:find('moritz',1,true) then return false; end

    local now=os.time();
    local id=nil;
    if moritz_pending.group_id
        and now-(tonumber(moritz_pending.selected_at) or 0)<=MORITZ_ARM_SECONDS
    then
        id=moritz_pending.group_id;
    end

    local is_locked=s:find("you won't be able to encounter that particular enm until",1,true)
        and s:find('earth time',1,true);
    local is_ready=s:find('the enm in that area should be sufficiently manifest for your next encounter',1,true);

    if not is_locked and not is_ready then return false; end

    -- Ashita commonly surfaces the same NPC line several times.
    if now-(tonumber(moritz_last_result_at) or 0)<=3 then
        return true;
    end
    moritz_last_result_at=now;

    if is_locked then
        local ready_at=parse_earth_time(s);
        if id and ready_at then
            apply_moritz_locked(c,id,ready_at,moritz_pending.source);
        else
            local rt=ensure_runtime(c);
            rt.moritz_unassigned={
                state='LOCKED',
                ready_at=ready_at,
                observed_at=now,
                reason=id and 'timer parse failed' or 'Moritz row was not armed',
            };
            HC.modules.state.save();
        end
        moritz_pending={group_id=nil,selected_at=0,source=nil};
        return true;
    end

    if is_ready then
        if id then
            apply_moritz_available(c,id,moritz_pending.source);
        else
            local rt=ensure_runtime(c);
            rt.moritz_unassigned={
                state='AVAILABLE',
                observed_at=now,
                reason='Moritz row was not armed',
            };
            HC.modules.state.save();
        end
        moritz_pending={group_id=nil,selected_at=0,source=nil};
        return true;
    end

    return false;
end

function M.init(ctx)
    HC = ctx;

    -- v6.9.12 migration: older builds incorrectly treated Venessa's
    -- "then you will need this censer" selection line as proof that the KI
    -- was held. Those exact legacy sources are invalidated on load so the
    -- false KEY ITEM READY label disappears without requiring another NPC talk.
    do
        local c=HC.modules.state.get_char();
        local r=ensure_runtime(c);
        r.access=type(r.access)=='table' and r.access or {};
        local changed=false;
        for _,id in ipairs({'promy_dem','promy_holla','promy_mea','promy_vahzl'}) do
            local a=r.access[id];
            local src=type(a)=='table' and tostring(a.source or '') or '';
            if type(a)=='table' and a.state=='KEY ITEM READY'
                and src:find('Venessa - Censer of ',1,true)==1
            then
                r.access[id]=nil;
                changed=true;
            end
        end
        if changed then HC.modules.state.save(); end
    end

    -- v6.92.2: KEY ITEM CONSUMED is transient battlefield evidence, not a
    -- lasting access state. Clear old saved markers once the battlefield is
    -- inactive and the five-day timer has ended or is no longer present.
    do
        local c=HC.modules.state.get_char();
        local changed=false;
        for _,g in ipairs(groups) do
            if clear_stale_consumed_access(c,g.id,false) then changed=true; end
        end
        if changed then HC.modules.state.save(); end
    end

    -- v6.9.20: synchronize existing ENM runtime/timer state into the shared
    -- lifecycle layer on load. This is intentionally read-mostly and does not
    -- alter proven ENM ownership/cooldown evidence.
    do
        local c=HC.modules.state.get_char();
        local rt=ensure_runtime(c);
        if rt.active and rt.active.group_id then
            lifecycle(c,rt.active.group_id,'IN_PROGRESS','Existing battlefield runtime',
                (tonumber(rt.active.entered_at) or os.time())+(3*60*60),{enm=rt.active.enm});
        end
        for _,g in ipairs(groups) do
            local a=access_state(c,g.id);
            local t=c.enm[g.id];
            if a and a.state=='KEY ITEM READY' then
                lifecycle(c,g.id,'READY',a.source or 'Existing key-item state',nil,{key_item=g.key_item});
            elseif t and tonumber(t.ready_at) and tonumber(t.ready_at)>os.time() then
                lifecycle(c,g.id,'COOLDOWN',t.moritz_source or t.jakaka_source or t.venessa_source or 'Existing ENM timer',
                    tonumber(t.ready_at),{ready_at=tonumber(t.ready_at)});
            end
        end
        HC.modules.state.save();
    end

    HC.modules.packets.register(0x05C,'Moritz ENM selection',moritz_select_packet);
    HC.modules.packets.register_text('enm tracking', function(s)
        s=string.lower(tostring(s or ''));
        local c=HC.modules.state.get_char();

        if handle_moritz_text(c,s) then return; end

        -- v6.9.14: capture-verified Boneyard Gully prerequisite chain.
        -- Flaxen Pouch and Pouch of Parradamo Stones are normal items, not
        -- battlefield key items. Track them as prerequisite progress only.
        if s:find('obtained: flaxen pouch',1,true) then
            set_boneyard_prereq(c,'FLAXEN POUCH READY','Obtained Flaxen Pouch');
        elseif s:find('obtained: pouch of parradamo stones',1,true) then
            set_boneyard_prereq(c,'PARRADAMO STONES READY','Obtained Pouch of Parradamo Stones');
        end

        -- v6.9.18: capture-verified Bearclaw Pinnacle prerequisite chain.
        -- Cotton Pouch and Chamnaet Ice are normal prerequisite items.
        if s:find('obtained: cotton pouch',1,true) then
            set_bearclaw_prereq(c,'COTTON POUCH READY','Obtained Cotton Pouch');
        elseif s:find('obtained: handful of chamnaet ice',1,true) then
            set_bearclaw_prereq(c,'COLLECTING CHAMNAET ICE','Obtained Chamnaet Ice');
        end

        -- Acquisition dialogue corroborates the structured 0x055
        -- ownership transition. It no longer starts or shifts the timer by
        -- itself because duplicate/localized chat can arrive before or after
        -- the authoritative bitmap update.
        if s:find('obtain',1,true) or s:find('receive',1,true) or s:find('key item',1,true) then
            for _, g in ipairs(groups) do
                if s:find(string.lower(g.key_item),1,true) then
                    if g.id=='boneyard' then set_boneyard_prereq(c,nil); end
                    if g.id=='bearclaw' then set_bearclaw_prereq(c,nil); end
                    M.note_acquisition_dialogue(g.id,'Obtained key-item dialogue');
                    break;
                end
            end
        end

        -- Capture-verified Venessa dialogue for Promyvion ENM censers.
        -- A "then you will need this censer" line identifies the selected
        -- Promyvion only; it is NOT proof that the key item was issued.
        if s:find('venessa',1,true) then
            local selected=nil;
            if s:find('holla, you say? then you will need this censer of abandonment',1,true) then
                selected='promy_holla';
            elseif s:find('dem, you say? then you will need this censer of antipathy',1,true) then
                selected='promy_dem';
            elseif s:find('mea, you say? then you will need this censer of animus',1,true) then
                selected='promy_mea';
            elseif s:find('vahzl, you say? then you will need this censer of acrimony',1,true) then
                selected='promy_vahzl';
            end
            if selected then
                venessa_pending_group=selected;
                venessa_pending_at=os.time();
                local r=ensure_runtime(c);
                r.venessa=type(r.venessa)=='table' and r.venessa or {};
                r.venessa.last_selected=selected;
                r.venessa.last_selected_at=venessa_pending_at;
                HC.modules.state.save();
            end

            local pending_ok=venessa_pending_group
                and (os.time()-(tonumber(venessa_pending_at) or 0)<=VENESSA_PENDING_SECONDS);

            if pending_ok
                and s:find('while i appreciate your assistance, i do not have any more censers to aid you on your travels into promyvion',1,true)
                and s:find('return at a later date',1,true)
            then
                -- Authoritative negative evidence: Vanessa did not issue a
                -- censer. Clear any stale READY state for the selected row.
                set_access_state(c,venessa_pending_group,'NO KEY ITEM','Venessa - no censer issued / return later');
            end

            if pending_ok
                and s:find('i may be able to provide you with another',1,true)
                and s:find('earth time',1,true)
                and s:find('and not a day sooner',1,true)
            then
                local parsed_at=parse_earth_time(s);
                local ready_at,invalid_reason=validate_ready_at(parsed_at,'Venessa');
                local g=group_by_id(venessa_pending_group);
                if parsed_at and not ready_at then remember_invalid_timer(c,'Venessa',venessa_pending_group,parsed_at,invalid_reason); end
                if ready_at and g then
                    c.enm[g.id]=type(c.enm[g.id])=='table' and c.enm[g.id] or {};
                    c.enm[g.id].ready_at=ready_at;
                    c.enm[g.id].keyitem_at=ready_at-CD;
                    c.enm[g.id].last=g.name;
                    c.enm[g.id].venessa_verified_at=os.time();
                    c.enm[g.id].venessa_source='Venessa exact Earth-time';
                    c.enm[g.id].timer_source='Venessa exact Earth-time';
                    c.enm[g.id].timer_confidence='NPC VERIFIED';

                    local r=ensure_runtime(c);
                    r.access=type(r.access)=='table' and r.access or {};
                    r.access[g.id]={
                        state='NO KEY ITEM',
                        next_state='AVAILABLE '..os.date('%b %d %H:%M',ready_at),
                        next_state_at=ready_at,
                        verified_at=os.time(),
                        source='Venessa exact Earth-time',
                    };
                    lifecycle(c,g.id,'COOLDOWN','Venessa exact Earth-time',ready_at,{ready_at=ready_at});
                    HC.modules.state.save();
                    HC.msg('AUTO: ENM '..g.name..' key item unavailable until '..os.date('%Y-%m-%d %H:%M:%S',ready_at)..' [VERIFIED BY VENESSA].');
                end
                venessa_pending_group=nil;
                venessa_pending_at=0;
            end
        end

        -- v6.9.15: capture-verified Jakaka post-clear cooldown for Boneyard Gully.
        -- Her exact Earth-time is authoritative and replaces any estimated timer.
        if s:find('jakaka',1,true)
            and s:find("stay clear 'til",1,true)
            and s:find('earth time',1,true)
        then
            local parsed_at=parse_earth_time(s);
            local ready_at,invalid_reason=validate_ready_at(parsed_at,'Jakaka');
            local g=group_by_id('boneyard');
            if parsed_at and not ready_at then remember_invalid_timer(c,'Jakaka','boneyard',parsed_at,invalid_reason); end
            if ready_at and g then
                c.enm[g.id]=type(c.enm[g.id])=='table' and c.enm[g.id] or {};
                c.enm[g.id].ready_at=ready_at;
                c.enm[g.id].keyitem_at=ready_at-CD;
                c.enm[g.id].last=g.name;
                c.enm[g.id].jakaka_verified_at=os.time();
                c.enm[g.id].jakaka_source='Jakaka exact Earth-time';
                c.enm[g.id].timer_source='Jakaka exact Earth-time';
                c.enm[g.id].timer_confidence='NPC VERIFIED';

                local r=ensure_runtime(c);
                r.access=type(r.access)=='table' and r.access or {};
                r.access[g.id]={
                    state='NO KEY ITEM',
                    next_state='AVAILABLE '..os.date('%b %d %H:%M',ready_at),
                    next_state_at=ready_at,
                    verified_at=os.time(),
                    source='Jakaka exact Earth-time',
                };
                r.boneyard_prereq=nil;
                lifecycle(c,g.id,'COOLDOWN','Jakaka exact Earth-time',ready_at,{ready_at=ready_at});
                HC.modules.state.save();
                HC.msg('AUTO: ENM Boneyard Gully unavailable until '..os.date('%Y-%m-%d %H:%M:%S',ready_at)..' [VERIFIED BY JAKAKA].');
            end
        end

        -- Capture-verified Morangeart dialogue when the Monarch Linn ENM
        -- entry artifact/key item is already in hand.
        if s:find('the wrath of the monsters that dwell on the cape will not easily be quelled',1,true)
            and s:find('if you ever need another one of these artifacts, do not hesitate to ask',1,true)
        then
            set_access_state(c,'monarch_linn','KEY ITEM READY','Morangeart dialogue');
        end

        -- v6.0.44: battlefield entry detector learned from the Boneyard capture.
        -- Example: "entering the battlefield for sheep in antlion's clothing!"
        local entered=s:match('entering the battlefield for%s+(.+)!');
        if entered then
            entered=entered:gsub('^%s+',''):gsub('%s+$','');
            -- Strip capture/control decoration around the battlefield name.
            entered=entered:gsub('[^%w%s%p]','');
            local g,e=find_enm_by_name(entered);
            if not g then
                -- Fallback substring matching for control-coded FFXI battlefield names.
                for _,gg in ipairs(groups) do
                    for _,ee in ipairs(gg.enms or {}) do
                        if s:find(string.lower(ee),1,true) then g=gg; e=ee; break; end
                    end
                    if g then break; end
                end
            end
            if g and e then begin_battlefield(c,g,e); end
            return;
        end

        local runtime=ensure_runtime(c);
        if runtime.active then
            local mins=tonumber(s:match('the time limit for this battle is%s+(%d+)%s+minutes'));
            if mins and mins>0 and mins<=180 then
                runtime.active.time_limit=mins*60;
                HC.modules.state.save();
            end
        end

        -- v6.9.14: a normal battlefield clear-time line is reusable completion
        -- evidence, but only after HorizonCheck has already verified an ENM entry.
        -- Do not use the one-time Horizon achievement message for completion.
        if runtime.active and s:find('battlefield clear time:',1,true) then
            local finished=runtime.active;
            finished.state='CLEARED';
            finished.cleared_at=os.time();
            local cm,cs=s:match('battlefield clear time:%s*(%d+)%s+minutes?,%s*(%d+)%s+seconds?');
            if cm and cs then finished.clear_duration=(tonumber(cm)*60)+tonumber(cs); end
            runtime.last={
                group_id=finished.group_id,
                group_name=finished.group_name,
                enm=finished.enm,
                entered_at=finished.entered_at,
                cleared_at=finished.cleared_at,
                time_limit=finished.time_limit,
                clear_duration=finished.clear_duration,
                state='CLEARED',
            };

            -- v6.9.64: retain per-ENM clear evidence separately from the
            -- five-day availability timer. Horizon's cooldown begins when the
            -- entry KI is obtained, so a clear must never move ready_at.
            c.enm=type(c.enm)=='table' and c.enm or {};
            c.enm[finished.group_id]=type(c.enm[finished.group_id])=='table' and c.enm[finished.group_id] or {};
            local er=c.enm[finished.group_id];
            er.last_clear={
                enm=finished.enm,
                entered_at=finished.entered_at,
                cleared_at=finished.cleared_at,
                clear_duration=finished.clear_duration,
                source='Battlefield clear time',
            };
            er.last=finished.enm or er.last;

            runtime.active=nil;
            clear_stale_consumed_access(c,finished.group_id,true);
            local next_state=(type(er.ready_at)=='number' and er.ready_at>os.time()) and 'COOLDOWN' or 'CLEARED';
            lifecycle(c,finished.group_id,next_state,'Battlefield clear time',er.ready_at,{enm=finished.enm,clear_duration=finished.clear_duration,clear_verified=true});
            HC.modules.state.save();
            local clear_text='';
            if finished.clear_duration then
                local mm=math.floor(finished.clear_duration/60);
                local ss=finished.clear_duration%60;
                clear_text=string.format(' | %d:%02d',mm,ss);
            end
            HC.msg('AUTO: ENM cleared - '..tostring(finished.enm or '?')..' - '..tostring(finished.group_name or '?')..clear_text..'.');
        end
    end);
end

function M.note_acquisition_dialogue(group_id,source)
    local g=group_by_id(group_id);
    if not g then return false; end
    local now=os.time();
    local hints=session_hints();
    hints[group_id]={observed_at=now,source=source or 'Obtained key-item dialogue'};

    -- Packet and text callbacks can arrive in either order. If the 0x055
    -- transition already started the timer moments ago, upgrade its confidence
    -- without changing keyitem_at or ready_at.
    local c=HC.modules.state.get_char();
    c.enm=type(c.enm)=='table' and c.enm or {};
    local timer=c.enm[group_id];
    if type(timer)=='table'
        and timer.timer_confidence=='KI TRANSITION'
        and tonumber(timer.keyitem_at)
        and math.abs(now-tonumber(timer.keyitem_at))<=KI_ACQUISITION_HINT_SECONDS
    then
        timer.timer_confidence='PASSIVE VERIFIED';
        timer.timer_source='0x055 key-item transition + obtain dialogue';
        timer.acquisition_dialogue_at=now;
        timer.acquisition_dialogue_source=source or 'Obtained key-item dialogue';
        local rt=ensure_runtime(c);
        rt.access=type(rt.access)=='table' and rt.access or {};
        if type(rt.access[group_id])=='table' and rt.access[group_id].state=='KEY ITEM READY' then
            rt.access[group_id].source=timer.timer_source;
            rt.access[group_id].timer_origin='KNOWN';
        end
        lifecycle(c,group_id,'READY',timer.timer_source,nil,{ready_at=timer.ready_at,passive_verified=true});
        HC.modules.state.save();
        return true;
    end
    return false;
end

function M.reconcile_keyitem(group_id, owned, source, resource_id)
    local c=HC.modules.state.get_char();
    c.enm=type(c.enm)=='table' and c.enm or {};
    local rt=ensure_runtime(c);
    rt.access=type(rt.access)=='table' and rt.access or {};
    local active=rt.active and rt.active.group_id==group_id;
    local a=rt.access[group_id];
    local now=os.time();
    local changed=false;

    -- First authoritative observation is a baseline only. The baseline is
    -- session-local so an addon reload while a KI is already held cannot be
    -- mistaken for a newly observed acquisition.
    local observations=session_ownership();
    local previous=observations[group_id];
    observations[group_id]={
        owned=owned==true,
        observed_at=now,
        source=source,
        resource_id=resource_id,
    };

    local acquired=(type(previous)=='table' and previous.owned==false and owned==true);
    if acquired and not active then
        local existing=c.enm[group_id];
        local recent_existing=type(existing)=='table' and tonumber(existing.keyitem_at)
            and math.abs(now-tonumber(existing.keyitem_at))<=KI_ACQUISITION_HINT_SECONDS;
        local hint=recent_acquisition_hint(group_id,now);
        local confidence=hint and 'PASSIVE VERIFIED' or 'KI TRANSITION';
        local timer_source=hint and '0x055 key-item transition + obtain dialogue' or '0x055 key-item transition';
        if not recent_existing then
            M.mark(group_id,(group_by_id(group_id) or {}).name or group_id,now,{
                source=timer_source,
                confidence=confidence,
                transition=true,
                resource_id=resource_id,
                dialogue_at=hint and hint.observed_at or nil,
                announce=true,
            });
        else
            -- A manual pickup click or another corroborating path may have
            -- created the same timer seconds earlier. Upgrade the evidence in
            -- place rather than shifting the acquisition timestamp.
            existing.timer_source=timer_source;
            existing.timer_confidence=confidence;
            existing.transition_verified_at=now;
            existing.resource_id=resource_id or existing.resource_id;
            existing.acquisition_dialogue_at=hint and hint.observed_at or existing.acquisition_dialogue_at;
            local access=rt.access[group_id];
            if type(access)=='table' and access.state=='KEY ITEM READY' then
                access.source=timer_source;
                access.resource_id=resource_id or access.resource_id;
                access.timer_origin='KNOWN';
            end
            lifecycle(c,group_id,'READY',timer_source,nil,{ready_at=existing.ready_at,timer_confidence=confidence});
            HC.modules.state.save();
        end
        session_hints()[group_id]=nil;
        return true;
    end

    if owned==true then
        -- Current ownership is authoritative for access. A first-session true
        -- snapshot with no timer is deliberately labeled TIMER UNKNOWN rather
        -- than inventing a five-day start time.
        if not active then
            if type(rt.prereq)=='table' and rt.prereq[group_id]~=nil then rt.prereq[group_id]=nil; changed=true; end
            if group_id=='boneyard' and rt.boneyard_prereq~=nil then rt.boneyard_prereq=nil; changed=true; end
            local timer=c.enm[group_id];
            local origin_known=type(timer)=='table' and tonumber(timer.keyitem_at)~=nil;
            if type(a)~='table' or a.state~='KEY ITEM READY' or a.source~=source
                or a.timer_origin~=(origin_known and 'KNOWN' or 'UNKNOWN')
            then
                rt.access[group_id]={
                    state='KEY ITEM READY',
                    verified_at=now,
                    source=source,
                    resource_id=resource_id,
                    timer_origin=origin_known and 'KNOWN' or 'UNKNOWN',
                    first_seen_owned=(previous==nil and not origin_known) and true or nil,
                };
                changed=true;
            else
                a.verified_at=now; a.resource_id=resource_id;
            end
            lifecycle(c,group_id,'READY',source,nil,{
                key_item_bitmap=true,
                resource_id=resource_id,
                timer_origin=origin_known and 'KNOWN' or 'UNKNOWN',
            });
        end
    elseif owned==false then
        -- Absence proves only that the entry KI is not presently held. It does
        -- not by itself prove cooldown/eligibility, so clear only stale READY.
        if not active and type(a)=='table' and a.state=='KEY ITEM READY' then
            rt.access[group_id]=nil;
            changed=true;
            local timer=c.enm and c.enm[group_id] or nil;
            if timer and tonumber(timer.ready_at) and tonumber(timer.ready_at)>now then
                lifecycle(c,group_id,'COOLDOWN',source,tonumber(timer.ready_at),{key_item_bitmap=false,resource_id=resource_id});
            else
                lifecycle(c,group_id,'AVAILABLE',source,nil,{key_item_bitmap=false,resource_id=resource_id});
            end
        elseif clear_stale_consumed_access(c,group_id,false) then
            changed=true;
        end
    end

    if changed then HC.modules.state.save(); end
    return changed;
end

function M.mark(id, label, picked_at, opts)
    opts=type(opts)=='table' and opts or {};
    local c = HC.modules.state.get_char();
    local at = tonumber(picked_at) or os.time();
    local source=tostring(opts.source or 'Manual key-item pickup');
    local confidence=tostring(opts.confidence or 'ESTIMATED');

    c.enm=type(c.enm)=='table' and c.enm or {};
    local rec=type(c.enm[id])=='table' and c.enm[id] or {};
    c.enm[id]=rec;
    rec.keyitem_at=at;
    rec.ready_at=at+CD;
    rec.last=label;
    rec.timer_source=source;
    rec.timer_confidence=confidence;
    rec.resource_id=opts.resource_id or rec.resource_id;
    rec.transition_verified_at=opts.transition==true and at or nil;
    rec.acquisition_dialogue_at=opts.dialogue_at;
    rec.acquisition_dialogue_source=opts.dialogue_at and 'Obtained key-item dialogue' or nil;

    -- Exact timer verification from an older cooldown must not label a newly
    -- acquired KI. Preserve unrelated clear history, but clear old timer proof.
    rec.moritz_verified_at=nil; rec.moritz_source=nil; rec.moritz_state=nil;
    rec.venessa_verified_at=nil; rec.venessa_source=nil;
    rec.jakaka_verified_at=nil; rec.jakaka_source=nil;

    local r=ensure_runtime(c);
    r.access=type(r.access)=='table' and r.access or {};
    r.access[id]={
        state='KEY ITEM READY',
        verified_at=at,
        source=source,
        resource_id=opts.resource_id,
        timer_origin='KNOWN',
    };
    lifecycle(c,id,'READY',source,nil,{ready_at=at+CD,timer_confidence=confidence});
    HC.modules.state.save();

    if opts.announce==true then
        local suffix=confidence=='PASSIVE VERIFIED' and ' [PASSIVE VERIFIED]' or ' [KI TRANSITION]';
        HC.msg('AUTO: ENM '..tostring(label or id)..' timer started from key-item ownership transition.'..suffix);
    end
    return rec;
end

function M.ready_count(c)
    local now=os.time();
    local ready=0;
    for _,g in ipairs(groups) do
        local r=c.enm[g.id];
        if r==nil or type(r.ready_at)~='number' or r.ready_at<=now then ready=ready+1; end
    end
    return ready,#groups;
end

function M.attention_rows(c)
    local now=os.time();
    local out={};
    local runtime=ensure_runtime(c);
    for _,g in ipairs(groups) do
        local access=access_state(c,g.id);
        local pre=prereq_state(c,g.id);
        local timer=c.enm[g.id];
        if runtime.active and runtime.active.group_id==g.id then
            out[#out+1]={priority=1,text='ENM '..g.name..' - RUN IN PROGRESS'..(runtime.active.enm and (' | '..runtime.active.enm) or '')};
        elseif access and access.state=='KEY ITEM READY' then
            out[#out+1]={priority=2,text='ENM '..g.name..' - KEY ITEM READY ('..g.key_item..')'};
        elseif pre and pre.state then
            out[#out+1]={priority=3,text='ENM '..g.name..' - '..tostring(pre.state)};
        elseif timer==nil or type(timer.ready_at)~='number' or timer.ready_at<=now then
            out[#out+1]={priority=4,text='ENM '..g.name..' - AVAILABLE'};
        end
    end
    table.sort(out,function(a,b) if a.priority~=b.priority then return a.priority<b.priority; end return a.text<b.text; end);
    return out;
end

function M.zone_rows(c,zone_name)
    c=c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    c.enm=type(c.enm)=='table' and c.enm or {};
    local wanted=string.lower(tostring(zone_name or ''));
    if wanted=='' or wanted=='unknown' then return {}; end
    local now=os.time(); local runtime=ensure_runtime(c); local out={};
    for _,g in ipairs(groups) do
        if string.lower(tostring(g.name or ''))==wanted then
            local access=access_state(c,g.id);
            local pre=prereq_state(c,g.id);
            local timer=c.enm[g.id];
            local status='AVAILABLE'; local detail='Entry readiness should be verified at the ENM NPC/key item.';
            if runtime.active and runtime.active.group_id==g.id then
                status='IN PROGRESS'; detail=tostring(runtime.active.enm or 'Battlefield active');
            elseif access and access.state=='KEY ITEM READY' then
                status='KEY ITEM READY'; detail=tostring(g.key_item);
            elseif pre and pre.state then
                status=tostring(pre.state); detail=tostring(g.key_item);
            elseif timer and type(timer.ready_at)=='number' and timer.ready_at>now then
                status='COOLDOWN';
                detail='Ready in '..((HC.modules.core and HC.modules.core.format_duration) and HC.modules.core.format_duration(timer.ready_at-now) or tostring(timer.ready_at-now));
            end
            out[#out+1]={kind='ENM',name=tostring(g.name),zone=tostring(g.name),status=status,detail=detail,key_item=tostring(g.key_item or ''),enms=g.enms};
        end
    end
    return out;
end

function M.upcoming_timers(c)
    local now=os.time();
    local out={};
    for _,g in ipairs(groups) do
        local r=c.enm[g.id];
        if r and type(r.ready_at)=='number' and r.ready_at>now then
            out[#out+1]={
                id=g.id,
                name=g.name,
                remaining=r.ready_at-now,
                ready_at=r.ready_at,
                state='COUNTING DOWN',
                verified=(r.moritz_verified_at~=nil or r.timer_confidence=='PASSIVE VERIFIED' or r.timer_confidence=='KI TRANSITION'),
                verified_at=r.moritz_verified_at or r.transition_verified_at,
                confidence=r.timer_confidence,
                source=r.timer_source,
            };
        end
    end
    table.sort(out,function(a,b)
        if a.ready_at~=b.ready_at then return a.ready_at<b.ready_at; end
        return a.name<b.name;
    end);
    return out;
end

local function age_text(ts)
    ts=tonumber(ts);
    if not ts then return nil; end
    local age=math.max(0,os.time()-ts);
    if age<60 then return tostring(age)..'s ago'; end
    if age<3600 then return tostring(math.floor(age/60))..'m ago'; end
    if age<86400 then return tostring(math.floor(age/3600))..'h ago'; end
    return tostring(math.floor(age/86400))..'d ago';
end

function M.next_timer(c)
    local all=M.upcoming_timers(c);
    return all[1];
end

local function sorted_groups(c)
    local now=os.time();
    local rows={};
    for _,g in ipairs(groups) do
        local r=c.enm[g.id];
        local available=(r==nil or type(r.ready_at)~='number' or r.ready_at<=now);
        rows[#rows+1]={g=g,r=r,available=available,remaining=available and 0 or (r.ready_at-now)};
    end
    table.sort(rows,function(a,b)
        if a.available~=b.available then return a.available; end
        if a.remaining~=b.remaining then return a.remaining<b.remaining; end
        return a.g.name<b.g.name;
    end);
    return rows;
end

local function row_status_label(c,g,row)
    local runtime=ensure_runtime(c);
    local access=access_state(c,g.id);
    local mv=runtime.moritz and runtime.moritz[g.id] or nil;
    local label=nil;

    -- Present lifecycle state first. Timer evidence is still preserved, but a
    -- confirmed held KI or active battlefield is more useful than a generic
    -- availability label.
    if runtime.active and runtime.active.group_id==g.id then
        label='RUN IN PROGRESS';
        if runtime.active.enm then label=label..' | '..tostring(runtime.active.enm); end
    elseif access and access.state=='KEY ITEM READY' then
        label='KEY ITEM READY';
        if access.timer_origin=='UNKNOWN' then label=label..' | TIMER UNKNOWN'; end
    elseif not row.available then
        label='COOLDOWN '..HC.modules.core.format_duration(row.remaining);
        if row.r and type(row.r.ready_at)=='number' then
            label=label..' | '..os.date('%b %d %H:%M',row.r.ready_at);
        end
        if row.r and row.r.timer_confidence=='PASSIVE VERIFIED' then
            label=label..' | PASSIVE VERIFIED';
        elseif row.r and row.r.timer_confidence=='KI TRANSITION' then
            label=label..' | KI VERIFIED';
        elseif row.r and row.r.moritz_verified_at then
            local age=age_text(row.r.moritz_verified_at);
            label=label..' | TIMER VERIFIED'..(age and (' '..age) or '');
        elseif row.r and (row.r.jakaka_verified_at or row.r.venessa_verified_at) then
            label=label..' | NPC VERIFIED';
        else
            label=label..' | ESTIMATED';
        end
    elseif prereq_state(c,g.id) and prereq_state(c,g.id).state then
        label=tostring(prereq_state(c,g.id).state);
    elseif mv and mv.state=='AVAILABLE' then
        local age=age_text(mv.verified_at);
        label='AVAILABLE | TIMER VERIFIED'..(age and (' '..age) or '');
    else
        label='AVAILABLE';
    end

    -- Preserve uncommon access evidence without replacing the standardized
    -- primary lifecycle label.
    local access_expired=access and tonumber(access.next_state_at) and tonumber(access.next_state_at)<=os.time();
    if access and access.state and access.state~='KEY ITEM READY' and access.state~='KEY ITEM CONSUMED' and not access_expired
        and not (runtime.active and runtime.active.group_id==g.id)
    then
        local access_text=tostring(access.state);
        if access.next_state and access.next_state~='' then
            access_text=access_text..' / '..tostring(access.next_state);
        end
        if not label:find(access_text,1,true) then label=label..' | '..access_text; end
    end
    return label,access;
end

local function clipped_cell_text(value,width)
    local s=tostring(value or '');
    width=math.max(1,tonumber(width) or 1);
    if #s<=width then return s; end
    if width<=3 then return string.sub(s,1,width); end
    return string.sub(s,1,width-3)..'...';
end

local function fixed_row_text(name,key_item,status)
    -- Ashita's default addon font is monospaced, so padded fields produce
    -- stable visual columns without relying on ImGui table support.
    return string.format('%-22s | %-27s | %-43s',
        clipped_cell_text(name,22),
        clipped_cell_text(key_item,27),
        clipped_cell_text(status,43)
    );
end

local function action_column_x(imgui)
    -- Keep ENM actions anchored near the right edge instead of allowing the
    -- buttons to crowd long cooldown/status text. SameLine offsets are
    -- relative to the current window content origin in Ashita ImGui.
    if imgui and imgui.GetWindowWidth then
        local ok,width=pcall(imgui.GetWindowWidth);
        if ok and tonumber(width) then
            return math.max(720,tonumber(width)-190);
        end
    end
    return nil;
end

local function same_line_actions(imgui)
    local x=action_column_x(imgui);
    if x then
        local ok=pcall(imgui.SameLine,x);
        if ok then return; end
    end
    imgui.SameLine();
end

local function timer_is_verified(timer)
    if type(timer)~='table' then return false; end
    local confidence=tostring(timer.timer_confidence or '');
    return confidence=='PASSIVE VERIFIED' or confidence=='KI TRANSITION' or confidence=='NPC VERIFIED'
        or timer.moritz_verified_at~=nil or timer.jakaka_verified_at~=nil or timer.venessa_verified_at~=nil;
end



local function row_needs_timer_verification(c,g,row)
    local access=access_state(c,g.id);
    local timer=type(c.enm)=='table' and c.enm[g.id] or nil;
    if type(access)=='table' and access.state=='KEY ITEM READY' and access.timer_origin=='UNKNOWN' then return true; end
    if row.available~=true and not timer_is_verified(timer) then return true; end
    return false;
end

function M.draw(c)
    local imgui=HC.imgui; if imgui==nil then return; end
    local ready,total=M.ready_count(c);
    imgui.Text(string.format('ENM availability: %d/%d ready',ready,total));
    local developer=(type(c.settings)=='table' and c.settings.developer_mode==true);
    if developer and HC.modules.learning and HC.modules.learning.capture_button then
        imgui.SameLine();
        HC.modules.learning.capture_button('enm','enm_section');
    end

    local rows=sorted_groups(c);
    local needs_timer_help=false;
    for _,row in ipairs(rows) do
        if row_needs_timer_verification(c,row.g,row) then
            needs_timer_help=true;
            break;
        end
    end

    if developer then
        imgui.TextDisabled('Horizon: cooldown starts when the entry key item is obtained. Ready ENMs are listed first.');
        imgui.TextDisabled('Passive tracking starts timers from an observed 0x055 KI transition. Use Verify Timer only to recover or correct an unknown/estimated timer through Moritz.');
    elseif needs_timer_help then
        imgui.TextDisabled('One or more ENM timers need verification; use Verify Timer on rows marked TIMER UNKNOWN or ESTIMATED.');
    end

    local runtime=ensure_runtime(c);
    if runtime.moritz_unassigned then
        local u=runtime.moritz_unassigned;
        local recent=(os.time()-(tonumber(u.observed_at) or 0)<=60);
        if developer or recent then
            imgui.TextDisabled('Last unassigned timer verification: '..tostring(u.state or '?')..' - no ENM row was armed.');
        end
    end
    if runtime.active then
        local elapsed=math.max(0,os.time()-(tonumber(runtime.active.entered_at) or os.time()));
        local limit=tonumber(runtime.active.time_limit) or 900;
        local remain=math.max(0,limit-elapsed);
        imgui.Text('ACTIVE ENM: '..tostring(runtime.active.enm or '?')..' - '..tostring(runtime.active.group_name or '?'));
        imgui.TextDisabled('Battlefield state: '..tostring(runtime.active.state or 'ENTERED')..
            ' | elapsed '..HC.modules.core.format_duration(elapsed)..
            ' | nominal remaining '..HC.modules.core.format_duration(remain));
    elseif runtime.last then
        local last_text='Last ENM entry: '..tostring(runtime.last.enm or '?')..' - '..tostring(runtime.last.group_name or '?');
        if runtime.last.state=='CLEARED' and tonumber(runtime.last.clear_duration) then
            local d=tonumber(runtime.last.clear_duration);
            last_text=last_text..string.format(' | CLEARED %d:%02d',math.floor(d/60),d%60);
        elseif runtime.last.state then
            last_text=last_text..' | '..tostring(runtime.last.state);
        end
        imgui.TextDisabled(last_text);
    end
    if runtime.active then
        if imgui.SmallButton('Clear Active ENM##enm_clear_active') then
            runtime.last=runtime.active;
            runtime.last.state='CLEARED MANUALLY';
            local finished_group=runtime.active.group_id;
            runtime.active=nil;
            clear_stale_consumed_access(c,finished_group,true);
            HC.modules.state.save();
        end
    end

    imgui.Spacing();
    imgui.Separator();
    imgui.TextDisabled('ENM List');

    local table_supported=(HC.modules.uikit and HC.modules.uikit.table_supported and HC.modules.uikit.table_supported(imgui)
        and imgui.TableSetupColumn~=nil and imgui.TableHeadersRow~=nil and imgui.TableNextRow~=nil and imgui.TableSetColumnIndex~=nil);

    -- Shared UI flags keep ENM consistent with the rest of HorizonCheck.
    local table_flags=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
    if table_supported and imgui.BeginTable('##enm_list_table_v68716',4,table_flags) then
        imgui.TableSetupColumn('Location',0,165);
        imgui.TableSetupColumn('Key Item',0,215);
        imgui.TableSetupColumn('Status',0,510);
        imgui.TableSetupColumn('Actions',0,220);
        imgui.TableHeadersRow();

        for _,row in ipairs(rows) do
            local g=row.g;
            local label,access=row_status_label(c,g,row);
            imgui.TableNextRow();

            imgui.TableSetColumnIndex(0);
            imgui.Text(tostring(g.name or ''));

            imgui.TableSetColumnIndex(1);
            imgui.Text(tostring(g.key_item or ''));

            imgui.TableSetColumnIndex(2);
            imgui.Text(tostring(label or ''));
            if imgui.IsItemHovered() then
                local tip='Status: '..tostring(label or '')..'\nKey item: '..g.key_item..'\nENMs:\n  '..table.concat(g.enms,'\n  ');
                if access and access.next_state then
                    tip=tip..'\nNext key item: '..tostring(access.next_state);
                end
                local timer=type(c.enm)=='table' and c.enm[g.id] or nil;
                if type(timer)=='table' and timer.timer_source then
                    tip=tip..'\nTimer source: '..tostring(timer.timer_source);
                end
                imgui.SetTooltip(tip);
            end

            imgui.TableSetColumnIndex(3);
            local armed=(moritz_pending.group_id==g.id)
                and (os.time()-(tonumber(moritz_pending.selected_at) or 0)<=MORITZ_ARM_SECONDS);
            if armed then
                local left=math.max(0,MORITZ_ARM_SECONDS-(os.time()-(tonumber(moritz_pending.selected_at) or 0)));
                imgui.TextDisabled('WAITING '..tostring(left)..'s');
                if not row.available then
                    imgui.SameLine();
                    if imgui.SmallButton('Reset##v55enmreset'..g.id) then c.enm[g.id]=nil; HC.modules.state.save(); end
                end
            else
                local action_drawn=false;
                local show_verify=developer or row_needs_timer_verification(c,g,row);
                if show_verify then
                    if imgui.SmallButton('Verify Timer##enm_moritz_'..g.id) then arm_moritz(g.id); end
                    action_drawn=true;
                end
                if action_drawn then imgui.SameLine(); end
                if row.available then
                    if imgui.SmallButton('KI Picked Up##v55enm'..g.id) then M.mark(g.id,g.name); end
                else
                    if imgui.SmallButton('Reset##v55enmreset'..g.id) then c.enm[g.id]=nil; HC.modules.state.save(); end
                end
            end
        end
        imgui.EndTable();
    else
        -- Fallback for older ImGui bindings: keep the previous single-line
        -- layout, but do not truncate the status text.
        imgui.TextDisabled(string.format('%-22s | %-27s | %s', 'Location','Key Item','Status'));
        imgui.Separator();
        for i,row in ipairs(rows) do
            if i>1 then imgui.Separator(); end
            local g=row.g;
            local label,access=row_status_label(c,g,row);
            imgui.Text(string.format('%-22s | %-27s | %s',
                clipped_cell_text(g.name,22),clipped_cell_text(g.key_item,27),tostring(label or '')));
            if imgui.IsItemHovered() then
                local tip='Status: '..tostring(label or '')..'\nKey item: '..g.key_item..'\nENMs:\n  '..table.concat(g.enms,'\n  ');
                if access and access.next_state then tip=tip..'\nNext key item: '..tostring(access.next_state); end
                local timer=type(c.enm)=='table' and c.enm[g.id] or nil;
                if type(timer)=='table' and timer.timer_source then tip=tip..'\nTimer source: '..tostring(timer.timer_source); end
                imgui.SetTooltip(tip);
            end
            imgui.SameLine();
            local armed=(moritz_pending.group_id==g.id)
                and (os.time()-(tonumber(moritz_pending.selected_at) or 0)<=MORITZ_ARM_SECONDS);
            if armed then
                local left=math.max(0,MORITZ_ARM_SECONDS-(os.time()-(tonumber(moritz_pending.selected_at) or 0)));
                imgui.TextDisabled('WAITING '..tostring(left)..'s');
            else
                local action_drawn=false;
                local show_verify=developer or row_needs_timer_verification(c,g,row);
                if show_verify then
                    if imgui.SmallButton('Verify Timer##enm_moritz_'..g.id) then arm_moritz(g.id); end
                    action_drawn=true;
                end
                if action_drawn then imgui.SameLine(); end
                if row.available then
                    if imgui.SmallButton('KI Picked Up##v55enm'..g.id) then M.mark(g.id,g.name); end
                else
                    if imgui.SmallButton('Reset##v55enmreset'..g.id) then c.enm[g.id]=nil; HC.modules.state.save(); end
                end
            end
        end
        imgui.Separator();
    end
end

function M.catalog_entries()
    local out={};
    for _,g in ipairs(groups) do out[#out+1]={id=g.id,name=g.name,key_item=g.key_item,enms=g.enms}; end
    return out;
end

function M.command(w)
    if string.lower(w[2] or '')~='enm' then return false; end
    local id=string.lower(w[3] or '');
    local hours=tonumber(w[4]);
    if id=='' then HC.msg('Usage: /hcheck enm <id> [hours-ago]'); return true; end
    local found=nil;
    for _,g in ipairs(groups) do if g.id==id then found=g; break; end end
    if not found then HC.msg('Unknown ENM id: '..id); return true; end
    local picked=os.time()-math.max(0,(hours or 0))*3600;
    M.mark(found.id,found.name,picked,{source='Manual ENM timer',confidence='ESTIMATED'});
    HC.msg('ENM timer set manually: '..found.name..(hours and (' (KI picked up '..tostring(hours)..'h ago)') or ''));
    return true;
end

return M;
