local M = {};
local HC;

local function user_file(kind,name)
    if HC and HC.modules and HC.modules.userdata and HC.modules.userdata.path then
        local ok,res=pcall(HC.modules.userdata.path,kind,name);
        if ok and type(res)=='string' and res~='' then return res; end
    end
    return tostring(HC and HC.addon_path or '')..tostring(name or '');
end


local DYNAMIS_ZONES = {
    [39]='Dynamis - Valkurm', [40]='Dynamis - Buburimu', [41]='Dynamis - Qufim', [42]='Dynamis - Tavnazia',
    [134]='Dynamis - Beaucedine', [135]='Dynamis - Xarcabard',
    [185]="Dynamis - San d'Oria", [186]='Dynamis - Bastok', [187]='Dynamis - Windurst', [188]='Dynamis - Jeuno',
};
local LIMBUS_ZONES = { [37]='Temenos', [38]='Apollyon' };
local DYNAMIS_RUN_WINDOW = 12600; -- 3.5 hours from the first verified entry
local SYSTEMS = {'dynamis','limbus','assault','guild_points','eco','dragon','highwind'};

local last_poll = 0;
local session_zone = nil;
local initialized_zone = false;
local last_hits = {};
local reward_context = { key=nil, at=0, source=nil };
local uninvited_watch = { mammet_defeated_at=0, battlefield_clear_at=0, justinius_confirm_at=0, justinius_reward_at=0 };
local assault_watch = {
    mission=nil,
    accepted_at=0,
    orders_at=0,
    armband_at=0,
    entered_at=0,
    started_at=0,
    expires_at=0,
    objective_at=0,
    cleared_at=0,
    verified_at=0,
    completed_at=0,
    ap=nil,
    objective=nil,
};
local highwind_watch = {
    armed=false,
    index=nil,
    server_id=nil,
    armed_at=0,
    last_seen_at=0,
    last_hp=nil,
    exp3000_at=0,
    gil3000_at=0,
    verified_at=0,
};

local function ensure(c)
    c.automation = type(c.automation) == 'table' and c.automation or {};
    local a = c.automation;
    if a.enabled == nil then a.enabled = true; end
    if a.dry_run == nil then a.dry_run = false; end
    a.events = type(a.events) == 'table' and a.events or {};
    a.systems = type(a.systems) == 'table' and a.systems or {};
    a.sessions = type(a.sessions) == 'table' and a.sessions or {}; -- legacy v5.x session mirror
    a.next_event_id = tonumber(a.next_event_id) or 1;
    for _,s in ipairs(SYSTEMS) do if a.systems[s] == nil then a.systems[s] = true; end end
    for _,ev in ipairs(a.events) do if ev.id==nil then ev.id=a.next_event_id; a.next_event_id=a.next_event_id+1; end end
    return a;
end

local function system_enabled(c, sys)
    local a=ensure(c);
    return a.enabled ~= false and a.systems[sys] ~= false;
end

local function dry_run(c)
    return ensure(c).dry_run == true;
end

local function audit_line(c, ev)
    local name=HC.modules.core.character_name():gsub('[^%w_%-]','_');
    local path=user_file('logs','horizoncheck_audit_'..name..'.log');
    local f=io.open(path,'a'); if not f then return; end
    f:write(string.format('%s | #%s | %s | %s\n',os.date('%Y-%m-%d %H:%M:%S',ev.at),tostring(ev.id or '?'),tostring(ev.kind),tostring(ev.detail)));
    f:close();
end

local function event(c, kind, detail, undo)
    local a = ensure(c);
    local ev={ id=a.next_event_id, at=os.time(), kind=tostring(kind or 'event'), detail=tostring(detail or ''), undo=undo, undone=false };
    a.next_event_id=a.next_event_id+1;
    a.last_event_at=ev.at; a.last_event=ev.kind; a.last_detail=ev.detail;
    a.events[#a.events+1]=ev;
    while #a.events>50 do table.remove(a.events,1); end
    audit_line(c,ev);
    if HC and HC.modules and HC.modules.timeline and HC.modules.timeline.record then
        pcall(HC.modules.timeline.record,c,'auto',tostring(kind or 'AUTO'),tostring(detail or ''),{
            source='automation',scope='character',automation_event_id=ev.id,undoable=type(undo)=='table',dedupe_seconds=1,
        });
    end
    return ev;
end
function M.record_external(c, kind, detail, undo)
    event(c,kind,detail,undo);
end

local function candidate(c, kind, detail)
    event(c, 'candidate:' .. tostring(kind), tostring(detail or 'would update'), nil);
    HC.modules.state.save();
    HC.msg('DRY RUN: ' .. tostring(detail or kind));
end

local function save_event(c, kind, detail, undo)
    event(c, kind, detail, undo);
    HC.modules.state.save();
end

local function mark_daily(id, why, sys)
    local c=HC.modules.state.get_char(); if not system_enabled(c,sys or id) then return false; end
    if c.daily[id]~=true then
        if dry_run(c) then candidate(c,'daily',tostring(id)..' would complete ['..tostring(why or 'auto')..']'); return true; end
        local old=c.daily[id]; c.daily[id]=true;
        save_event(c,'daily',tostring(id)..' - '..tostring(why or 'auto'),{scope='daily',key=id,old=old});
        HC.msg('AUTO: '..tostring(id)..' completed'..(why and (' ['..why..']') or '')); return true;
    end
    return false;
end

local function mark_weekly(id, why, sys)
    local c=HC.modules.state.get_char(); if not system_enabled(c,sys or id) then return false; end
    if c.weekly[id]~=true then
        if dry_run(c) then candidate(c,'weekly',tostring(id)..' would complete ['..tostring(why or 'auto')..']'); return true; end
        local old=c.weekly[id]; c.weekly[id]=true;
        save_event(c,'weekly',tostring(id)..' - '..tostring(why or 'auto'),{scope='weekly',key=id,old=old});
        HC.msg('AUTO: '..tostring(id)..' completed'..(why and (' ['..why..']') or '')); return true;
    end
    return false;
end

local function mark_dragon(id, why)
    local c=HC.modules.state.get_char(); if not system_enabled(c,'dragon') then return false; end
    if c.dragon_weekly[id]~=true then
        if dry_run(c) then candidate(c,'dragon',tostring(id)..' would complete ['..tostring(why or 'auto')..']'); return true; end
        local old=c.dragon_weekly[id]; c.dragon_weekly[id]=true;
        save_event(c,'dragon',tostring(id)..' - '..tostring(why or 'auto'),{scope='dragon_weekly',key=id,old=old});
        HC.msg('AUTO: EXP-scroll source '..tostring(id)..' completed'..(why and (' ['..why..']') or '')); return true;
    end
    return false;
end

local function dynamis_entry_counts(c, zid)
    local aw=HC.modules.state.get_account_weekly and HC.modules.state.get_account_weekly() or nil;
    if not aw then return true; end

    local now=os.time();
    local started=tonumber(aw.dynamis_run_started_at);

    if started and started>0 and (now-started)<DYNAMIS_RUN_WINDOW then
        aw.dynamis_last_reentry_at=now;
        aw.dynamis_last_reentry_zone=zid;
        HC.modules.state.save();

        HC.msg('AUTO: Dynamis re-entry detected within the same 3.5-hour run window; account-wide weekly count unchanged.');
        return false;
    end

    aw.dynamis_run_started_at=now;
    aw.dynamis_run_zone=zid;
    aw.dynamis_last_reentry_at=nil;
    aw.dynamis_last_reentry_zone=nil;
    HC.modules.state.save();
    return true;
end

local function increment_account_dynamis(c, why)
    if not system_enabled(c,'dynamis') then return false; end
    local aw=HC.modules.state.get_account_weekly and HC.modules.state.get_account_weekly() or nil;
    if not aw then return false; end

    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    local char_count=math.max(0,math.min(2,math.floor(tonumber(c.weekly.dynamis_character_count) or 0)));
    local account_count=math.max(0,math.min(3,math.floor(tonumber(aw.dynamis_count) or 0)));

    if account_count>=3 then
        HC.msg('AUTO: Dynamis entry detected, but the account-wide 3/3 weekly cap is already reached.');
        return false;
    end
    if char_count>=2 then
        HC.msg('AUTO: Dynamis entry detected, but this character is already 2/2 for the week; account-wide count unchanged.');
        return false;
    end

    if dry_run(c) then
        candidate(c,'dynamis',
            string.format('Dynamis would count: character %d/2 -> %d/2 | account %d/3 -> %d/3 [%s]',
                char_count,char_count+1,account_count,account_count+1,tostring(why or 'zone entry')));
        return true;
    end

    char_count=char_count+1;
    account_count=account_count+1;
    c.weekly.dynamis_character_count=char_count;
    aw.dynamis_count=account_count;

    c.weekly.dynamis_1=(account_count>=1) and true or nil;
    c.weekly.dynamis_2=(account_count>=2) and true or nil;
    c.weekly.dynamis_3=(account_count>=3) and true or nil;

    event(c,'dynamis',
        string.format('Dynamis character %d/2 | account-wide %d/3 - %s',
            char_count,account_count,tostring(why or 'zone entry')),
        nil);
    HC.modules.state.save();
    HC.msg(string.format(
        'AUTO: Dynamis lockout detected - character %d/2 | account-wide %d/3 [%s]',
        char_count,account_count,tostring(why or 'zone entry')
    ));
    return true;
end

local function increment_pair(c, akey, bkey, label, why, sys)
    if not system_enabled(c,sys) then return false; end
    local key=nil;
    if c.weekly[akey]~=true then key=akey elseif c.weekly[bkey]~=true then key=bkey else return false; end
    if dry_run(c) then candidate(c,string.lower(label),tostring(label)..' run would count ['..tostring(why or 'zone entry')..']'); return true; end
    local old=c.weekly[key]; c.weekly[key]=true;
    save_event(c,string.lower(label),tostring(why or 'zone entry'),{scope='weekly',key=key,old=old});
    local n=(c.weekly[akey] and 1 or 0)+(c.weekly[bkey] and 1 or 0);
    HC.msg(string.format('AUTO: %s run detected (%d/2) [%s]',label,n,tostring(why or 'zone entry'))); return true;
end

local function reset_assault_watch()
    assault_watch.mission=nil;
    assault_watch.accepted_at=0;
    assault_watch.orders_at=0;
    assault_watch.armband_at=0;
    assault_watch.entered_at=0;
    assault_watch.started_at=0;
    assault_watch.expires_at=0;
    assault_watch.objective_at=0;
    assault_watch.cleared_at=0;
    assault_watch.verified_at=0;
    assault_watch.completed_at=0;
    assault_watch.ap=nil;
    assault_watch.objective=nil;
end

local function assault_event(c, state, detail)
    if dry_run(c) then
        candidate(c,'assault_state',tostring(state)..' | '..tostring(detail or ''));
        return;
    end
    c.assault_activity=type(c.assault_activity)=='table' and c.assault_activity or {};
    c.assault_activity.state=state;
    c.assault_activity.mission=assault_watch.mission;
    c.assault_activity.updated_at=os.time();
    c.assault_activity.detail=detail;
    c.assault_activity.ap=assault_watch.ap;
    c.assault_activity.accepted_at=assault_watch.accepted_at;
    c.assault_activity.orders_at=assault_watch.orders_at;
    c.assault_activity.entered_at=assault_watch.entered_at;
    c.assault_activity.started_at=assault_watch.started_at;
    c.assault_activity.expires_at=assault_watch.expires_at;
    c.assault_activity.objective_at=assault_watch.objective_at;
    c.assault_activity.cleared_at=assault_watch.cleared_at;
    c.assault_activity.verified_at=assault_watch.verified_at;
    c.assault_activity.objective=assault_watch.objective;
    HC.modules.state.save();
end

local function restore_assault_watch(c)
    local a=type(c.assault_activity)=='table' and c.assault_activity or nil;
    if not a then return; end
    if not assault_watch.mission and a.mission then assault_watch.mission=a.mission; end
    if assault_watch.accepted_at==0 then assault_watch.accepted_at=tonumber(a.accepted_at) or 0; end
    if assault_watch.orders_at==0 then assault_watch.orders_at=tonumber(a.orders_at) or 0; end
    if assault_watch.entered_at==0 then assault_watch.entered_at=tonumber(a.entered_at) or 0; end
    if assault_watch.started_at==0 then assault_watch.started_at=tonumber(a.started_at) or 0; end
    if assault_watch.expires_at==0 then assault_watch.expires_at=tonumber(a.expires_at) or 0; end
    if assault_watch.objective_at==0 then assault_watch.objective_at=tonumber(a.objective_at) or 0; end
    if assault_watch.cleared_at==0 then assault_watch.cleared_at=tonumber(a.cleared_at) or 0; end
    if assault_watch.verified_at==0 then assault_watch.verified_at=tonumber(a.verified_at) or 0; end
    assault_watch.ap=assault_watch.ap or tonumber(a.ap);
    assault_watch.objective=assault_watch.objective or a.objective;
end

local function assault_success(c, why, ap)
    restore_assault_watch(c);
    local now=os.time();

    -- AP gain is the authoritative in-run clear. Only process the clear once.
    if assault_watch.cleared_at>0 and (now-assault_watch.cleared_at)<180 then
        if tonumber(ap) then
            assault_watch.ap=tonumber(ap);
            assault_event(c,'CLEARED',why);
        end
        return false;
    end

    assault_watch.cleared_at=now;
    assault_watch.completed_at=now; -- legacy compatibility
    assault_watch.ap=tonumber(ap) or assault_watch.ap;
    assault_event(c,'CLEARED',why);

    if assault_watch.mission and HC.modules.assaultprogress and HC.modules.assaultprogress.mark_complete then
        HC.modules.assaultprogress.mark_complete(c,assault_watch.mission,why);
    end

    if HC.modules.sessions then
        HC.modules.sessions.complete(c,'assault',why,'CHAT CONFIRMED');
    end
    mark_daily('assault',why,'assault');
    if HC.modules.sessions then
        HC.modules.sessions.close(c,'assault','successful completion','COMPLETED');
        HC.modules.state.save();
    end

    HC.msg('AUTO: Assault CLEARED'..
        (assault_watch.mission and (' - '..assault_watch.mission) or '')..
        (assault_watch.ap and (' | '..tostring(assault_watch.ap)..' AP') or ''));
    return true;
end

local function assault_verify(c, why)
    restore_assault_watch(c);
    local now=os.time();
    if assault_watch.verified_at>0 and (now-assault_watch.verified_at)<180 then return false; end

    assault_watch.verified_at=now;
    assault_event(c,'VERIFIED',why);

    -- If HorizonCheck was reloaded after the clear but before Rytaal verification,
    -- the persisted mission still lets this final confirmation check the right row.
    if assault_watch.mission and HC.modules.assaultprogress and HC.modules.assaultprogress.mark_complete then
        HC.modules.assaultprogress.mark_complete(c,assault_watch.mission,why);
    end

    HC.msg('AUTO: Assault VERIFIED'..
        (assault_watch.mission and (' - '..assault_watch.mission) or '')..
        (assault_watch.ap and (' | '..tostring(assault_watch.ap)..' AP') or ''));
    return true;
end


local function current_target_info()
    local out={index=nil,name='',hp=nil,server_id=nil};
    pcall(function()
        local mm=AshitaCore:GetMemoryManager();
        local t=mm:GetTarget();
        local ent=mm:GetEntity();
        local idx=nil;
        if t~=nil then
            pcall(function() idx=t:GetTargetIndex(0); end);
            if idx==nil or tonumber(idx)==0 then pcall(function() idx=t:GetTargetIndex(); end); end
        end
        idx=tonumber(idx);
        if ent~=nil and idx~=nil and idx>0 then
            out.index=idx;
            pcall(function() out.name=tostring(ent:GetName(idx) or ''); end);
            pcall(function() out.hp=tonumber(ent:GetHPPercent(idx)); end);
            pcall(function() out.server_id=tonumber(ent:GetServerId(idx)); end);
        end
    end);
    return out;
end

local function watched_highwind_info()
    if not highwind_watch.armed or not highwind_watch.index then return nil; end
    local out={index=highwind_watch.index,name='',hp=nil,server_id=nil};
    pcall(function()
        local ent=AshitaCore:GetMemoryManager():GetEntity();
        if ent~=nil then
            pcall(function() out.name=tostring(ent:GetName(highwind_watch.index) or ''); end);
            pcall(function() out.hp=tonumber(ent:GetHPPercent(highwind_watch.index)); end);
            pcall(function() out.server_id=tonumber(ent:GetServerId(highwind_watch.index)); end);
        end
    end);
    return out;
end

local function reset_highwind_watch()
    highwind_watch.armed=false;
    highwind_watch.index=nil;
    highwind_watch.server_id=nil;
    highwind_watch.armed_at=0;
    highwind_watch.last_seen_at=0;
    highwind_watch.last_hp=nil;
    highwind_watch.exp3000_at=0;
    highwind_watch.gil3000_at=0;
    highwind_watch.verified_at=0;
end

local function highwind_complete_verified(c)
    if highwind_watch.verified_at>0 and os.time()-highwind_watch.verified_at<30 then return false; end
    if dry_run(c) then
        candidate(c,'highwind','Highwind VERIFIED completion: combat context + 3000 EXP + 3000 gil');
        return true;
    end

    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    local old=c.weekly.highwind;
    c.weekly.highwind=true;
    save_event(c,'highwind',
        'Highwind VERIFIED - combat context + 3000 EXP + 3000 gil',
        {scope='weekly',key='highwind',old=old});

    if HC.modules.sessions then
        local rec=HC.modules.sessions.complete(
            c,'highwind',
            'Highwind reward pair: 3000 EXP + 3000 gil',
            'CHAT CONFIRMED'
        );
        if rec then
            rec.highwind_verified=true;
            rec.highwind_evidence={
                combat_context=true,
                exp3000_at=highwind_watch.exp3000_at,
                gil3000_at=highwind_watch.gil3000_at,
            };
            HC.modules.sessions.close(c,'highwind','Highwind rewards verified','COMPLETED');
        end
    end

    highwind_watch.verified_at=os.time();
    HC.modules.state.save();
    HC.msg('AUTO: Highwind weekly complete [VERIFIED] - combat context + 3000 EXP + 3000 gil.');
    return true;
end

local function highwind_reward_pair_check(c)
    if not highwind_watch.armed then return false; end
    local now=os.time();
    if now-(highwind_watch.last_seen_at or 0)>120 then return false; end
    local e=highwind_watch.exp3000_at or 0;
    local g=highwind_watch.gil3000_at or 0;
    if e<=0 or g<=0 or math.abs(e-g)>5 then return false; end
    return highwind_complete_verified(c);
end

local function poll_highwind()
    local c=HC.modules.state.get_char();
    if not system_enabled(c,'highwind') or c.weekly.highwind==true then
        reset_highwind_watch();
        return;
    end

    local now=os.time();
    local cur=current_target_info();
    local lname=string.lower(tostring(cur.name or ''));

    -- Arm only from the actual target entity, never from player chat.
    if not highwind_watch.armed and (lname=='highwind' or lname=='the highwind') then
        highwind_watch.armed=true;
        highwind_watch.index=cur.index;
        highwind_watch.server_id=cur.server_id;
        highwind_watch.armed_at=now;
        highwind_watch.last_seen_at=now;
        highwind_watch.last_hp=cur.hp;
        highwind_watch.exp3000_at=0;
        highwind_watch.gil3000_at=0;
        highwind_watch.verified_at=0;
        if HC.modules.sessions and not HC.modules.sessions.current(c,'highwind') then
            HC.modules.sessions.start(c,'highwind',{
                reason='The Highwind combat context armed',
                confidence='OBSERVED',
            });
            HC.modules.state.save();
        end
        HC.msg('AUTO: Highwind target detected; reward verifier armed.');
        return;
    end

    if not highwind_watch.armed then return; end

    -- Safety timeout: an abandoned/stale target must never complete the weekly.
    if now-(highwind_watch.armed_at or 0)>300 then
        reset_highwind_watch();
        return;
    end

    local w=watched_highwind_info();
    if not w then return; end

    local same_entity=true;
    if highwind_watch.server_id and w.server_id and highwind_watch.server_id~=w.server_id then
        same_entity=false;
    end
    if not same_entity then
        reset_highwind_watch();
        return;
    end

    local wn=string.lower(tostring(w.name or ''));
    if wn=='highwind' or wn=='the highwind' then highwind_watch.last_seen_at=now; end
    if w.hp~=nil then highwind_watch.last_hp=w.hp; end

    -- HP 0 is supporting evidence only. The recent capture showed the
    -- authoritative weekly reward pair is 3000 EXP + 3000 gil.
    if w.hp~=nil and w.hp<=0 and now-(highwind_watch.armed_at or 0)>=2 then
        highwind_watch.last_hp=0;
        highwind_watch.last_seen_at=now;
    end
end

function M.reconcile_uninvited_permit(owned,source,id,label)
    if owned==nil then return; end
    local c=HC.modules.state.get_char();
    c.uninvited_activity=type(c.uninvited_activity)=='table' and c.uninvited_activity or {};
    local u=c.uninvited_activity;
    local now=os.time();
    local changed=false;

    if u.permit_owned~=owned then u.permit_owned=owned; changed=true; end
    u.permit_verified_at=now;
    u.permit_source=source or '0x055 key-item bitmap';
    u.permit_resource_id=id;
    u.permit_label=label or 'Monarch Linn Patrol Permit';

    if owned==true then
        if u.state~='PERMIT READY' then u.state='PERMIT READY'; changed=true; end
        if not u.permit_at then u.permit_at=now; changed=true; end
        u.updated_at=now;
        u.source=u.permit_source;
    elseif owned==false and u.state=='PERMIT READY' and c.weekly and c.weekly.uninvited~=true then
        -- Do not infer success from disappearance.  The permit can be consumed
        -- on entry and a failed run still uses the weekly opportunity.
        u.state='PERMIT NOT HELD';
        u.updated_at=now;
        u.source=u.permit_source;
        changed=true;
    end

    if changed and HC.modules.state and HC.modules.state.save then HC.modules.state.save(); end
end

function M.uninvited_status(c)
    local u=type(c.uninvited_activity)=='table' and c.uninvited_activity or {};
    if c.weekly and c.weekly.uninvited==true then return 'COMPLETE FOR THE WEEK'; end
    if u.state=='CLEARED' then return 'CLEARED | Return to Justinius'; end
    if u.permit_owned==true then return 'Permit ready | Head to Monarch Linn'; end
    if u.state=='PERMIT READY' then return 'Permit ready | Head to Monarch Linn'; end
    if u.state=='PERMIT NOT HELD' then return 'Permit not held | Talk to Justinius'; end
    if u.state=='OFFERED' then return 'Offered | Accept from Justinius'; end
    return 'Ready | Talk to Justinius';
end

function M.highwind_status(c)
    if c.weekly.highwind==true then return 'Confirmed'; end
    if highwind_watch.armed then
        local hp=highwind_watch.last_hp;
        return hp~=nil and ('Watching | HP '..tostring(hp)..'%') or 'Watching';
    end
    return 'Ready';
end

local function get_zone_id()
    local zid=nil;
    pcall(function()
        local p=AshitaCore:GetMemoryManager():GetParty();
        if p~=nil and p.GetMemberZone~=nil then zid=tonumber(p:GetMemberZone(0)); end
    end);
    if zid~=nil and zid>0 then return zid; end
    pcall(function()
        local e=AshitaCore:GetMemoryManager():GetEntity();
        if e~=nil and e.GetLocalPlayer~=nil then local lp=e:GetLocalPlayer(); if lp and lp.ZoneId then zid=tonumber(lp.ZoneId); end end
    end);
    return zid;
end
M.get_zone_id=get_zone_id;

local function family(zid)
    if DYNAMIS_ZONES[zid] then return 'dynamis'; end
    if LIMBUS_ZONES[zid] then return 'limbus'; end
    return nil;
end

local function handle_zone(zid)
    if not zid or zid<=0 then return; end
    local c=HC.modules.state.get_char(); local a=ensure(c); local fam=family(zid); local se=HC.modules.sessions;
    if not initialized_zone then
        initialized_zone=true; session_zone=zid; a.last_zone_id=zid; a.last_zone_seen_at=os.time();
        if fam and se then
            se.recover(c,fam,{zone_id=zid,zone_name=DYNAMIS_ZONES[zid] or LIMBUS_ZONES[zid],reason='addon loaded inside activity'});
            HC.modules.state.save();
        end
        return;
    end
    if zid==session_zone then return; end
    local old=session_zone; local oldfam=family(old); local newfam=fam;
    session_zone=zid; a.last_zone_id=zid; a.last_zone_seen_at=os.time();
    local dirty=false;
    if oldfam and oldfam~=newfam and se then se.close(c,oldfam,'zone exit','EXITED'); dirty=true; end
    if system_enabled(c,'assault') and assault_watch.armband_at>0 and (os.time()-assault_watch.armband_at)<1800 and old~=zid then
        -- A full capture showed staging -> Assault battlefield as a second zone change.
        -- Do not key this to one Lebros zone ID; arm it from the Assault Armband/transport context.
        if assault_watch.entered_at==0 and assault_watch.orders_at>0 then
            assault_watch.entered_at=os.time();
            assault_event(c,'ENTERED','Assault battlefield zone transition');
            if se then se.start(c,'assault',{zone_id=zid,reason='Assault battlefield entry',confidence='CONTEXT + ZONE'}); end
        end
    end

    if newfam and oldfam~=newfam then
        if se then se.start(c,newfam,{zone_id=zid,zone_name=DYNAMIS_ZONES[zid] or LIMBUS_ZONES[zid],reason='zone entry',confidence='ZONE CONFIRMED'}); end
        dirty=true;
        if newfam=='dynamis' then
            if dynamis_entry_counts(c,zid) then
                increment_account_dynamis(c,DYNAMIS_ZONES[zid]);
            end
            dirty=false;
        elseif newfam=='limbus' then
            increment_pair(c,'limbus_1','limbus_2','Limbus',LIMBUS_ZONES[zid],'limbus');
            dirty=false;
        end
    end
    if dirty then HC.modules.state.save(); end
end

local function once(key,seconds)
    local now=os.time(); local prev=tonumber(last_hits[key]) or 0;
    if now-prev<(seconds or 8) then return false; end last_hits[key]=now; return true;
end

local function on_text(s)
    local c=HC.modules.state.get_char(); if ensure(c).enabled==false then return; end

    -- Remember short-lived reward context because FFXI commonly splits the quest
    -- hand-in dialogue and the actual EXP-scroll reward across separate chat lines.
    -- Do not complete anything from context alone; it is only consumed by a
    -- subsequent matching Miratete reward line.
    if system_enabled(c,'dragon') then
        if s:find('tavnazian cookbook',1,true) or s:find('secrets of ovens lost',1,true) or s:find('jonette',1,true) then
            reward_context={key='mm_cookbook',at=os.time(),source='Secrets of Ovens Lost'};
        elseif (s:find('rouva',1,true) and s:find('rivernewort',1,true))
            or (s:find('rouva',1,true) and s:find('token of my gratitude',1,true)) then
            reward_context={key='mm_rivenwort',at=os.time(),source='Spice Gals turn-in'};
        elseif s:find('uninvited guests',1,true) or s:find('justinius',1,true) then
            reward_context={key='uninvited',at=os.time(),source='Uninvited Guests'};
        end
    end
    if system_enabled(c,'dragon') then
        c.uninvited_activity=type(c.uninvited_activity)=='table' and c.uninvited_activity or {};
        local u=c.uninvited_activity;

        -- Capture-verified Uninvited Guests clear path. The Mammet-800 defeat
        -- arms a short-lived clear watch; only the subsequent battlefield clear
        -- message advances the weekly to CLEARED. This deliberately does not
        -- mark the weekly complete because the Justinius return/reward step is
        -- still required.
        if s:find('defeats the mammet-800',1,true) then
            uninvited_watch.mammet_defeated_at=os.time();
        elseif s:find('battlefield clear time:',1,true)
            and uninvited_watch.mammet_defeated_at>0
            and (os.time()-uninvited_watch.mammet_defeated_at)<=120
        then
            uninvited_watch.battlefield_clear_at=os.time();
            u.state='CLEARED';
            u.cleared_at=os.time();
            u.updated_at=os.time();
            u.source='Mammet-800 defeat + battlefield clear time';
            u.permit_owned=false;
            HC.modules.state.save();
        end

        -- Capture-verified successful turn-in. Justinius first confirms that the
        -- Monarch Linn enemies were routed, then explicitly offers the reward.
        -- Only that paired dialogue (or the immediately-following named
        -- achievement) completes the weekly; a generic reward item alone does not.
        if s:find('so, you have routed those black-robed menaces from monarch linn?',1,true)
            and s:find('excellent news',1,true)
        then
            uninvited_watch.justinius_confirm_at=os.time();
            u.state='TURN-IN CONFIRMED';
            u.updated_at=os.time();
            u.source='Justinius clear confirmation';
            HC.modules.state.save();
        elseif s:find('your reward--for a job well done',1,true)
            and uninvited_watch.justinius_confirm_at>0
            and (os.time()-uninvited_watch.justinius_confirm_at)<=30
        then
            uninvited_watch.justinius_reward_at=os.time();
            local completed=mark_weekly('uninvited','Justinius clear confirmation + reward','dragon');
            if not dry_run(c) then
                u.state='COMPLETE';
                u.completed_at=os.time();
                u.updated_at=os.time();
                u.source='Justinius reward dialogue';
                u.permit_owned=false;
                HC.modules.state.save();
            end
            reward_context={key=nil,at=0,source=nil};
        elseif s:find("achievement unlocked: complete 'uninvited guests'",1,true)
            and uninvited_watch.justinius_confirm_at>0
            and (os.time()-uninvited_watch.justinius_confirm_at)<=45
        then
            mark_weekly('uninvited','Uninvited Guests achievement after Justinius turn-in','dragon');
            if not dry_run(c) then
                u.state='COMPLETE';
                u.completed_at=os.time();
                u.updated_at=os.time();
                u.source='Named achievement after Justinius turn-in';
                u.permit_owned=false;
                HC.modules.state.save();
            end
            reward_context={key=nil,at=0,source=nil};
        elseif s:find('black-robed intruders you chased away from monarch linn',1,true)
            and s:find("we've had another sighting",1,true)
        then
            u.state='OFFERED';
            u.updated_at=os.time();
            u.source='Justinius offer dialogue';
            HC.modules.state.save();
        elseif s:find('obtained key item:',1,true) and s:find('monarch linn patrol permit',1,true) then
            u.state='PERMIT READY';
            u.permit_owned=true;
            u.permit_at=os.time();
            u.permit_verified_at=os.time();
            u.updated_at=os.time();
            u.source='Monarch Linn Patrol Permit acquisition';
            HC.modules.state.save();
        elseif s:find('take the monarch linn patrol permit and head for monarch linn',1,true) then
            u.state='PERMIT READY';
            u.permit_at=os.time();
            u.updated_at=os.time();
            u.source='Justinius permit-ready dialogue';
            HC.modules.state.save();
        elseif s:find('excellent. take this and make your way to monarch linn',1,true) then
            u.state='PERMIT READY';
            u.permit_at=os.time();
            u.updated_at=os.time();
            u.source='Justinius acceptance dialogue';
            HC.modules.state.save();
        end
    end

    -- Uninvited Guests consumes the weekly opportunity even when the BCNM is failed.
    -- Justinius explicitly confirms this by saying the Monarch Linn Patrol Permit was
    -- lost / that another permit will take time to approve. Treat that lockout dialogue
    -- as authoritative weekly-used evidence; do not require a Miratete reward.
    if system_enabled(c,'dragon') and once('uninvited_lockout',15) and (
        s:find('lost the monarch linn patrol permit',1,true) or
        (s:find('another permit',1,true) and s:find('approved',1,true)) or
        (s:find('monarch linn patrol permit',1,true) and s:find('lost',1,true))
    ) then
        mark_weekly('uninvited','Uninvited Guests weekly lockout confirmed by Justinius','dragon');
        reward_context={key=nil,at=0,source=nil};
    end
    if system_enabled(c,'assault') then
        -- Mission signup. Example captured: "Famad: you have signed up for Lebros Supplies."
        local mission=s:match('you have signed up for%s+(.+)%.?$');
        if mission and once('assault_signup',5) then
            reset_assault_watch();
            assault_watch.mission=mission:gsub('%.','');
            assault_watch.accepted_at=os.time();
            assault_event(c,'ACCEPTED','Mission signed up');
            if not dry_run(c) and HC.modules.assault and HC.modules.assault.auto_used then
                HC.modules.assault.auto_used(c,'Assault mission signed up');
            end
        end

        -- The Imperial Army I.D. Tag is consumed when Assault Orders are issued,
        -- not when AP is awarded at the end.
        if s:find('obtained key item',1,true) and s:find('assault orders',1,true) and once('assault_orders',10) then
            assault_watch.orders_at=os.time();
            assault_event(c,'ORDERS RECEIVED','Assault Orders obtained');
            if not dry_run(c) and HC.modules.assault and HC.modules.assault.auto_used then
                HC.modules.assault.auto_used(c,'Assault Orders obtained');
            end
        end

        if s:find('obtained key item',1,true) and s:find('assault armband',1,true) and once('assault_armband',10) then
            assault_watch.armband_at=os.time();
            assault_event(c,'COMMAND VERIFIED','Assault Armband obtained');
        end

        if s:find('participation in assault',1,true) and once('assault_transport',10) then
            assault_event(c,'STAGING','Transported to Assault staging point');
        end

        -- Generic area-entry wording observed for Ilrusi and usable for other
        -- Assault areas without hard-coding mission names.
        local invade_area=s:match('the order has been given to invade the%s+(.+)!$');
        if invade_area and once('assault_entering',10) then
            restore_assault_watch(c);
            assault_event(c,'ENTERING','Invading '..tostring(invade_area));
        end

        -- Mission-start line is authoritative and contains the exact mission.
        -- Example: "commencing lamia no.13! objective: eliminate lamia no.13"
        local start_mission,start_objective=s:match('commencing%s+(.+)!%s*objective:%s*(.+)$');
        if start_mission and once('assault_commencing',10) then
            restore_assault_watch(c);
            local clean=start_mission:gsub('^%s+',''):gsub('%s+$','');
            assault_watch.mission=clean;
            assault_watch.objective=start_objective and start_objective:gsub('^%s+',''):gsub('%s+$','') or nil;
            assault_watch.started_at=os.time();
            assault_watch.entered_at=(assault_watch.entered_at>0) and assault_watch.entered_at or assault_watch.started_at;
            assault_event(c,'IN PROGRESS','Mission commenced');
        end

        local minutes=s:match('you have%s+(%d+)%s+minutes%s+%(earth time%)%s+to complete this mission');
        if minutes and once('assault_time_limit',10) then
            restore_assault_watch(c);
            local mins=tonumber(minutes);
            if mins and mins>0 then
                assault_watch.expires_at=os.time()+(mins*60);
                assault_event(c,'IN PROGRESS',tostring(mins)..'-minute time limit');
            end
        end

        if s:find('mission objective completed',1,true) and s:find('rune of release',1,true) and once('assault_objective',10) then
            assault_watch.objective_at=os.time();
            assault_event(c,'OBJECTIVE COMPLETE','Rune of Release unlocked');
        end

        -- Authoritative successful-completion signals learned from the full
        -- Lebros Supplies capture.
        local ap=s:match('you gain%s+(%d+)%s+assault points');
        if ap and once('assault_ap_gain',10) then
            assault_success(c,'Assault Points gained',tonumber(ap));
        elseif s:find('awarded assault points',1,true) and s:find('successful completion of your mission',1,true) and once('assault_success_text',10) then
            assault_verify(c,'Rytaal successful completion confirmed');
        end
    end
    if system_enabled(c,'eco') and s:find('eco-warrior',1,true) and (s:find('complete',1,true) or s:find('dragon chronicles',1,true)) then
        mark_weekly('eco_warrior','Eco-Warrior completion','eco');
        mark_dragon('dc_eco','Eco-Warrior completion');
        if not dry_run(c) and HC.modules.eco and HC.modules.eco.auto_complete then HC.modules.eco.auto_complete(c,'Eco-Warrior completion'); end
    end
    if system_enabled(c,'dragon') and s:find('dragon chronicles',1,true) and (s:find('receive',1,true) or s:find('obtained',1,true)) then
        if s:find('haap',1,true) then mark_weekly('haap','HAAP reward','dragon'); mark_dragon('dc_haap','HAAP reward');
        elseif s:find('chocobo',1,true) then mark_weekly('chocobo_game','Chocobo Riding Game reward','dragon'); mark_dragon('dc_chocobo','Chocobo Riding Game reward'); end
    end
    -- HorizonXI achievement unlock messages can be one-time only.
    -- Do not use them as repeatable weekly completion evidence.
    if system_enabled(c,'dragon') and s:find('miratete',1,true) and (s:find('receive',1,true) or s:find('obtained',1,true)) then
        local handled=false;
        if s:find('rivernewort',1,true) or s:find('spice gals',1,true) or s:find('rouva',1,true) then
            handled=mark_dragon('mm_rivenwort','Spice Gals reward') or handled;
        elseif s:find('cookbook',1,true) or s:find('ovens lost',1,true) or s:find('jonette',1,true) then
            handled=mark_dragon('mm_cookbook','Secrets of Ovens Lost reward') or handled;
        elseif s:find('uninvited guests',1,true) then
            handled=mark_weekly('uninvited','Uninvited Guests reward','dragon') or handled;
        elseif reward_context.key and (os.time()-(tonumber(reward_context.at) or 0))<=45 then
            if reward_context.key=='mm_cookbook' then
                handled=mark_dragon('mm_cookbook','Secrets of Ovens Lost reward [context confirmed]') or handled;
            elseif reward_context.key=='mm_rivenwort' then
                handled=mark_dragon('mm_rivenwort','Spice Gals Rivernewort turn-in + Miratete reward') or handled;
            elseif reward_context.key=='uninvited' then
                handled=mark_weekly('uninvited','Uninvited Guests reward [context confirmed]','dragon') or handled;
            end
        end
        if handled then reward_context={key=nil,at=0,source=nil}; end
    end
    -- Captured authoritative Highwind completion: BOTH exact rewards,
    -- while the Highwind watcher is armed from recent combat context.
    if system_enabled(c,'highwind') and highwind_watch.armed then
        if s:find('gains 3000 experience points',1,true) then
            highwind_watch.exp3000_at=os.time();
            highwind_reward_pair_check(c);
        elseif s:find('obtained 3000 gil',1,true) then
            highwind_watch.gil3000_at=os.time();
            highwind_reward_pair_check(c);
        end
    end
end

function M.init(ctx) HC=ctx; HC.modules.packets.register_text('automation',on_text); end
function M.poll() local now=os.time(); if now==last_poll then return; end last_poll=now; handle_zone(get_zone_id()); poll_highwind(); end
function M.status(c) local a=ensure(c); if a.enabled==false then return 'AUTO OFF'; end return a.dry_run and 'AUTO DRY RUN' or 'AUTO ON'; end
function M.dry_run(c) return dry_run(c); end
function M.system_status(c,sys) return system_enabled(c,sys) and 'ON' or 'OFF'; end
function M.systems() return SYSTEMS; end
function M.sessions(c) return (HC.modules.sessions and HC.modules.sessions.active(c)) or ensure(c).sessions; end
function M.last_event(c) local a=ensure(c); if not a.last_event_at then return 'None this character'; end return string.format('%s - %s',os.date('%H:%M:%S',a.last_event_at),tostring(a.last_detail or a.last_event or 'event')); end
function M.recent(c) return ensure(c).events; end

local function apply_undo(c, ev)
    if not ev or type(ev.undo)~='table' or ev.undone==true then return false; end
    local u=ev.undo;
    if u.scope=='daily' then c.daily[u.key]=u.old;
    elseif u.scope=='weekly' then c.weekly[u.key]=u.old;
    elseif u.scope=='dragon_weekly' then c.dragon_weekly[u.key]=u.old;
    elseif u.scope=='assault_tags' then
        c.assault_tags=type(c.assault_tags)=='table' and c.assault_tags or {};
        c.assault_tags.count=u.count; c.assault_tags.next_at=u.next_at;
        if u.carried~=nil then c.assault_tags.carried=u.carried; c.assault_tags.carried_estimated=nil; end;
    elseif u.scope=='eco_rotation' then
        c.eco=type(c.eco)=='table' and c.eco or {};
        c.eco.cycle=type(c.eco.cycle)=='table' and c.eco.cycle or {};
        c.eco.cycle[u.key]=u.old_cycle;
        c.eco.completed_this_week=u.old_completed;
        c.eco.active=u.old_active;
    elseif u.scope=='guild_points_gain' then
        c.guild=type(c.guild)=='table' and c.guild or {};
        c.guild.points=tonumber(u.before) or c.guild.points;
    elseif u.scope=='haap_reward' then
        c.weekly=type(c.weekly)=='table' and c.weekly or {};
        c.dragon_weekly=type(c.dragon_weekly)=='table' and c.dragon_weekly or {};
        c.weekly.haap=u.old_weekly;
        c.dragon_weekly.dc_haap=u.old_dragon;
    elseif u.scope=='haap_scroll' then
        c.weekly=type(c.weekly)=='table' and c.weekly or {};
        c.dragon_weekly=type(c.dragon_weekly)=='table' and c.dragon_weekly or {};
        c.dragon_weekly[u.key]=u.old_scroll;
        c.weekly.haap=u.old_weekly;
    else return false; end
    ev.undone=true; ev.undone_at=os.time();
    local a=ensure(c); a.last_event_at=os.time(); a.last_event='undo'; a.last_detail='Undid #'..tostring(ev.id)..': '..tostring(ev.detail);
    audit_line(c,{id='undo-'..tostring(ev.id),at=os.time(),kind='undo',detail=a.last_detail});
    if HC.modules.timeline and HC.modules.timeline.record then
        pcall(HC.modules.timeline.record,c,'repair','Undo AUTO #'..tostring(ev.id),tostring(ev.detail),{
            source='automation undo',repair=true,dedupe_seconds=1,
        });
    end
    HC.modules.state.save(); HC.msg('Undid AUTO event #'..tostring(ev.id)..': '..tostring(ev.detail)); return true;
end

function M.undo_event(c,id)
    id=tonumber(id); if not id then return false; end
    local a=ensure(c); for i=#a.events,1,-1 do local ev=a.events[i]; if tonumber(ev.id)==id then
        if apply_undo(c,ev) then return true; end
        HC.msg('AUTO event #'..tostring(id)..' is not undoable or was already undone.'); return false;
    end end
    HC.msg('AUTO event #'..tostring(id)..' was not found in recent history.'); return false;
end

function M.undo_last(c)
    local a=ensure(c);
    for i=#a.events,1,-1 do local ev=a.events[i]; if type(ev.undo)=='table' and ev.undone~=true then return apply_undo(c,ev); end end
    HC.msg('No automatic event is available to undo.'); return false;
end

function M.command(w)
    local sub=string.lower(w[2] or '');
    if sub=='undo' then local c=HC.modules.state.get_char(); if tonumber(w[3]) then M.undo_event(c,tonumber(w[3])) else M.undo_last(c) end; return true; end
    if sub~='auto' and sub~='automation' then return false; end
    local c=HC.modules.state.get_char(); local a=ensure(c); local target=string.lower(w[3] or ''); local value=string.lower(w[4] or '');
    if target=='dryrun' then
        if value=='on' then a.dry_run=true; HC.modules.state.save(); HC.msg('Automation DRY RUN enabled; detections will be recorded without changing checklist state.');
        elseif value=='off' then a.dry_run=false; HC.modules.state.save(); HC.msg('Automation DRY RUN disabled; enabled detectors can update checklist state.');
        else HC.msg('Automation dry run: '..(a.dry_run and 'ON' or 'OFF')); end
    elseif target=='on' then a.enabled=true; HC.modules.state.save(); HC.msg('Automation enabled.');
    elseif target=='off' then a.enabled=false; HC.modules.state.save(); HC.msg('Automation disabled; manual controls remain available.');
    elseif target=='status' or target=='' then HC.msg('Automation: '..M.status(c)..' | Last: '..M.last_event(c));
    elseif target=='undo' then M.undo_last(c);
    else
        local known=false; for _,s in ipairs(SYSTEMS) do if s==target then known=true; break; end end
        if not known then HC.msg('Usage: /hcheck auto [on|off|status|dryrun on|off|<system> on|off]'); return true; end
        if value~='on' and value~='off' then HC.msg(target..' automation: '..M.system_status(c,target)); return true; end
        a.systems[target]=(value=='on'); HC.modules.state.save(); HC.msg(target..' automation '..string.upper(value)..'.');
    end
    return true;
end

return M;
