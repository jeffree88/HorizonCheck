local M = {};
local HC;
local eeko_sync={heard_windurst=false,heard_bastok=false,heard_sandoria=false,next_sandoria=false,next_bastok=false,windurst_only=false,next_sandoria_or_bastok=false,last_at=0};
local order={'bastok','sandoria','windurst'};
local q={
    bastok={name='Bastok'},
    sandoria={name="San d'Oria"},
    windurst={name='Windurst'},
};
local last_sig=nil;
local last_known=false;
local raifa_postcomplete_last_at=0;
local sandoria_text_last={sig=nil,at=0};
local windurst_text_last={sig=nil,at=0};

local function ensure(c)
    c.eco=type(c.eco)=='table' and c.eco or {};
    c.eco.cycle=type(c.eco.cycle)=='table' and c.eco.cycle or {};
    c.eco.eeko=type(c.eco.eeko)=='table' and c.eco.eeko or {};

    local wk=HC.modules.core.weekly_key();

    -- v6.46.0: once a full 3/3 Eco-Warrior rotation has been cleared, the
    -- following weekly reset starts a fresh cycle at 0/3.  Stamp the week so
    -- reloads do not repeatedly reset the same cycle.
    if c.eco.rotation_weekly_key==nil then
        c.eco.rotation_weekly_key=wk;
    elseif c.eco.rotation_weekly_key~=wk then
        local cleared=0;
        for _,id in ipairs(order) do if c.eco.cycle[id]==true then cleared=cleared+1; end end
        if cleared>=3 then
            c.eco.cycle={};
            c.eco.active=nil;
            c.eco.completed_this_week=nil;
            c.eco.completed_this_week_weekly_key=nil;

            -- Old Eeko availability belongs to the previous conquest week.
            c.eco.eeko=type(c.eco.eeko)=='table' and c.eco.eeko or {};
            c.eco.eeko.available=nil;
            c.eco.eeko.next=nil;
            c.eco.eeko.state=nil;
            c.eco.eeko.detail=nil;
            c.eco.eeko.confidence=nil;
            c.eco.eeko.authoritative_weekly_key=nil;

            -- Completion lifecycle records are weekly observations. Keep the
            -- tables, but return their state to READY for the new week.
            c.eco.bastok_activity=type(c.eco.bastok_activity)=='table' and c.eco.bastok_activity or {};
            c.eco.bastok_activity.state='READY';
            c.eco.bastok_activity.completed_at=nil;
            c.eco.bastok_activity.postcheck_verified_at=nil;
            c.eco.bastok_activity.last_reason='Weekly reset after 3/3 Eco-Warrior rotation';

            c.eco.windurst_activity=type(c.eco.windurst_activity)=='table' and c.eco.windurst_activity or {};
            c.eco.windurst_activity.state='READY';
            c.eco.windurst_activity.completed_at=nil;
            c.eco.windurst_activity.postcheck_verified_at=nil;
            c.eco.windurst_activity.accepted_weekly_key=nil;
            c.eco.windurst_activity.field_at=nil;
            c.eco.windurst_activity.level_cap_at=nil;
            c.eco.windurst_activity.return_ready_at=nil;
            c.eco.windurst_activity.last_reason='Weekly reset after 3/3 Eco-Warrior rotation';

            if HC.modules.state and HC.modules.state.audit then
                HC.modules.state.audit(c,'eco','Eco-Warrior rotation 3/3 -> 0/3 at weekly reset','AUTO','weekly reset');
            end
        end
        c.eco.rotation_weekly_key=wk;
        if HC.modules.state and HC.modules.state.save then HC.modules.state.save(); end
    end

    -- Never carry a "completed this week" badge into a later weekly key.
    if c.eco.completed_this_week_weekly_key~=nil
        and c.eco.completed_this_week_weekly_key~=wk
    then
        c.eco.completed_this_week=nil;
        c.eco.completed_this_week_weekly_key=nil;
    end

    -- v6.46.0 recovery:
    -- Older builds could leave a completed current-week nation as the ONLY raw
    -- cycle flag after the final turn-in. If the persisted Eeko state explicitly
    -- identifies the other two nations as cleared and names this completed nation
    -- as the available third, restore the two cleared flags.
    --
    -- We intentionally key this repair off:
    --   1) a CURRENT-week direct completion, and
    --   2) a specific Eeko state/detail that names the other cleared nations.
    -- This avoids inferring rotation history from a generic/stale availability flag.
    if c.eco.completed_this_week_weekly_key==wk and c.eco.completed_this_week~=nil then
        local completed_id=tostring(c.eco.completed_this_week);
        local estate=string.lower(tostring((c.eco.eeko and c.eco.eeko.state) or ''));
        local edetail=string.lower(tostring((c.eco.eeko and c.eco.eeko.detail) or ''));
        local repaired=false;

        local function mark(id)
            if q[id]~=nil and c.eco.cycle[id]~=true then
                c.eco.cycle[id]=true;
                repaired=true;
            end
        end

        if estate=='all_three_done_next_week' then
            mark('bastok');
            mark('sandoria');
            mark('windurst');
        elseif completed_id=='bastok' and (
            estate=='sandoria_windurst_done_bastok_next'
            or (edetail:find("san d'oria",1,true)
                and edetail:find('windurst',1,true)
                and edetail:find('bastok available',1,true))
        ) then
            mark('sandoria');
            mark('windurst');
            mark('bastok');
        elseif completed_id=='sandoria' and (
            estate=='windurst_bastok_done_sandoria_next'
            or (edetail:find('windurst',1,true)
                and edetail:find('bastok',1,true)
                and (edetail:find("san d'oria next",1,true) or edetail:find("san d'oria available",1,true)))
        ) then
            mark('windurst');
            mark('bastok');
            mark('sandoria');
        elseif completed_id=='sandoria' and estate=='windurst_done_sandoria_or_bastok_available' then
            -- This state only proves Windurst plus the just-completed San d'Oria.
            -- Do not invent Bastok completion.
            mark('windurst');
            mark('sandoria');
        elseif completed_id=='bastok' and estate=='windurst_done_sandoria_or_bastok_available' then
            -- This state only proves Windurst plus the just-completed Bastok.
            -- Do not invent San d'Oria completion.
            mark('windurst');
            mark('bastok');
        else
            -- Always preserve the directly verified current-week completion itself.
            mark(completed_id);
        end

        -- The direct completion supersedes an old Eeko "available" bit for that nation.
        if type(c.eco.eeko)=='table' and type(c.eco.eeko.available)=='table'
            and q[completed_id]~=nil and c.eco.eeko.available[completed_id]==true
        then
            c.eco.eeko.available[completed_id]=false;
            repaired=true;
        end

        -- If repair reconstructed all three nations, bind the Eeko snapshot to
        -- the current week so the draw/count path cannot mask a restored flag.
        local all3=c.eco.cycle.bastok==true
            and c.eco.cycle.sandoria==true
            and c.eco.cycle.windurst==true;
        if all3 and type(c.eco.eeko)=='table' then
            c.eco.eeko.authoritative_weekly_key=wk;
            c.eco.eeko.available=type(c.eco.eeko.available)=='table' and c.eco.eeko.available or {};
            c.eco.eeko.available.bastok=false;
            c.eco.eeko.available.sandoria=false;
            c.eco.eeko.available.windurst=false;
            c.eco.eeko.rotation_complete_repaired_at=os.time();
            repaired=true;
        end

        if repaired and HC.modules.state and HC.modules.state.save then
            HC.modules.state.save();
        end
    end


    c.eco.sandoria_activity=type(c.eco.sandoria_activity)=='table' and c.eco.sandoria_activity or {};
    local a=c.eco.sandoria_activity;
    if a.weekly_key~=wk then
        a.weekly_key=wk;
        a.state='READY';
        a.accepted_at=nil;
        a.key_item_at=nil;
        a.return_ready_at=nil;
        a.completed_at=nil;
        a.postcheck_verified_at=nil;
        a.last_reason=nil;
        a.evidence_source=nil;
    end
    if not a.state then a.state='READY'; end

    return c.eco;
end


local function reset_eeko_sync()
    eeko_sync.heard_windurst=false;
    eeko_sync.heard_bastok=false;
    eeko_sync.heard_sandoria=false;
    eeko_sync.next_sandoria=false;
    eeko_sync.next_bastok=false;
    eeko_sync.windurst_only=false;
    eeko_sync.next_sandoria_or_bastok=false;
    eeko_sync.last_at=0;
end

local function record_eeko_state(c,e,state,detail,changed)
    local now=os.time();
    e.eeko.last_sync_at=now;
    e.eeko.state=state;
    e.eeko.confidence='VERIFIED BY EEKO-WEEKO';
    e.eeko.detail=detail;
    if HC.modules.automation and HC.modules.automation.record_external then
        HC.modules.automation.record_external(
            c,'eco_eeko_sync',detail,{scope='eco_eeko_sync'}
        );
    end
    HC.modules.state.save();
    if HC.modules.dependencies and HC.modules.dependencies.invalidate then HC.modules.dependencies.invalidate('eco','Eeko-Weeko rotation synchronized');
    elseif HC.modules.releasehealth and HC.modules.releasehealth.invalidate then HC.modules.releasehealth.invalidate(); end
    if changed then
        HC.msg('AUTO: Eeko-Weeko synced Eco-Warrior rotation [VERIFIED] - '..detail);
    else
        HC.msg('Eeko-Weeko rotation verified - '..detail..' No correction needed.');
    end
end

local function rotation_is_locked_complete(e)
    if type(e)~='table' or type(e.cycle)~='table' then return false; end
    if e.cycle.bastok~=true or e.cycle.sandoria~=true or e.cycle.windurst~=true then return false; end
    return e.rotation_weekly_key==HC.modules.core.weekly_key();
end

local function on_eeko_text(s)
    s=string.lower(tostring(s or ''));
    if not s:find('eeko-weeko',1,true) then return; end

    local c=HC.modules.state.get_char();
    local e=ensure(c);
    local now=os.time();

    -- v6.46.0: 3/3 is a conquest-week lockout. Once all three nations are
    -- cleared in the current weekly key, later Eeko dialogue in the SAME week
    -- may refresh diagnostics but must never remove a cleared nation or make
    -- the rotation fall back to 2/3, 1/3, etc. Only ensure() at an actual
    -- weekly-key change is allowed to perform 3/3 -> 0/3.
    if rotation_is_locked_complete(e) then
        if s:find("all three nation's vermin representatives",1,true)
            and s:find('could use a bravey-wavey adventurer next week',1,true)
        then
            e.eeko=type(e.eeko)=='table' and e.eeko or {};
            e.eeko.next='all_three_next_week';
            e.eeko.authoritative_weekly_key=HC.modules.core.weekly_key();
            e.eeko.available={bastok=false,sandoria=false,windurst=false};
            e.eeko.rotation_complete=true;
            e.eeko.rotation_complete_at=now;
            e.eeko.state='all_three_done_next_week';
            e.eeko.detail="All three nations cleared; all available next week";
            e.eeko.confidence='VERIFIED BY EEKO-WEEKO';
            e.eeko.last_sync_at=now;
            HC.modules.state.save();
            if HC.modules.dependencies and HC.modules.dependencies.invalidate then HC.modules.dependencies.invalidate('eco','Eeko-Weeko all-three completion verification'); end
        end
        return;
    end

    -- Captured state #1 (Mabalzich):
    -- "windurst consulate and bastok consulate"
    -- followed by "check with san d'oria ... next week"
    if s:find('windurst consulate',1,true) and s:find('bastok consulate',1,true) then
        eeko_sync.heard_windurst=true;
        eeko_sync.heard_bastok=true;
        eeko_sync.last_at=now;
    end

    if s:find("check with san d'oria",1,true) and s:find('next week',1,true) then
        eeko_sync.next_sandoria=true;
        eeko_sync.last_at=now;
    end

    if eeko_sync.heard_windurst and eeko_sync.heard_bastok and eeko_sync.next_sandoria then
        local changed=false;
        if e.cycle.windurst~=true then e.cycle.windurst=true; changed=true; end
        if e.cycle.bastok~=true then e.cycle.bastok=true; changed=true; end
        if e.cycle.sandoria==true then e.cycle.sandoria=nil; changed=true; end
        if e.completed_this_week=='sandoria' then e.completed_this_week=nil; changed=true; end
        if e.active~='sandoria' then e.active='sandoria'; changed=true; end
        e.eeko.next='sandoria';
        e.eeko.authoritative_weekly_key=HC.modules.core.weekly_key();
        e.eeko.available={bastok=false,sandoria=true,windurst=false};
        record_eeko_state(
            c,e,
            'windurst_bastok_done_sandoria_next',
            "Windurst + Bastok cleared; San d'Oria next",
            changed
        );
        reset_eeko_sync();
        return;
    end

    -- Captured state #2 (Ciladan):
    -- "coming from the direction of the san d'oria consulate and windurst consulate"
    -- followed by "check with bastok ... next week too"
    if s:find("san d'oria consulate",1,true) and s:find('windurst consulate',1,true) then
        eeko_sync.heard_sandoria=true;
        eeko_sync.heard_windurst=true;
        eeko_sync.last_at=now;
    end

    if s:find('check with bastok',1,true) and s:find('next week',1,true) then
        eeko_sync.next_bastok=true;
        eeko_sync.last_at=now;
    end

    if eeko_sync.heard_sandoria and eeko_sync.heard_windurst and eeko_sync.next_bastok then
        local changed=false;

        -- Eeko-Weeko is authoritative here: San d'Oria + Windurst are the two
        -- cleared nations and Bastok is the available one. Remove any stale
        -- Bastok completion/lifecycle state that would otherwise keep it at 3/3.
        local wanted={sandoria=true,windurst=true};
        for _,id in ipairs(order) do
            local want=wanted[id]==true;
            if (e.cycle[id]==true)~=want then
                e.cycle[id]=want and true or nil;
                changed=true;
            end
        end

        if e.completed_this_week=='bastok' then
            e.completed_this_week=nil;
            e.completed_this_week_weekly_key=nil;
            changed=true;
        end
        if e.active=='bastok' then e.active=nil; changed=true; end

        e.bastok_activity=type(e.bastok_activity)=='table' and e.bastok_activity or {};
        if e.bastok_activity.state~='READY'
            or e.bastok_activity.completed_at~=nil
            or e.bastok_activity.postcheck_verified_at~=nil
        then changed=true; end
        e.bastok_activity.state='READY';
        e.bastok_activity.completed_at=nil;
        e.bastok_activity.postcheck_verified_at=nil;
        e.bastok_activity.last_reason='Eeko-Weeko verified Bastok available';

        e.eeko.next='bastok';
        e.eeko.authoritative_weekly_key=HC.modules.core.weekly_key();
        e.eeko.available={bastok=true,sandoria=false,windurst=false};
        record_eeko_state(
            c,e,
            'sandoria_windurst_done_bastok_next',
            "San d'Oria + Windurst cleared; Bastok available",
            changed
        );
        reset_eeko_sync();
        return;
    end

    -- Captured state #3 (Admiral):
    -- "coming from the direction of the windurst consulate"
    -- followed by "check with san d'oria or bastok ... this week too"
    if s:find('coming from the direction of the windurst consulate',1,true)
        and not s:find('bastok consulate',1,true)
    then
        eeko_sync.windurst_only=true;
        eeko_sync.last_at=now;
    end

    if s:find("check with san d'oria or bastok",1,true)
        and s:find('this week',1,true)
    then
        eeko_sync.next_sandoria_or_bastok=true;
        eeko_sync.last_at=now;
    end

    if eeko_sync.windurst_only and eeko_sync.next_sandoria_or_bastok then
        local changed=false;
        -- Only preserve a locally verified completion when it belongs to the
        -- CURRENT conquest week. Older builds did not stamp the week, which
        -- could leave Bastok stuck as COMPLETED THIS WEEK after rollover.
        local keep_week=nil;
        if e.completed_this_week_weekly_key==HC.modules.core.weekly_key() then
            keep_week=e.completed_this_week;
        elseif e.completed_this_week~=nil then
            e.completed_this_week=nil;
            changed=true;
        end

        -- Eeko is authoritative for rotation history, but a completion that
        -- HorizonCheck directly verified THIS conquest period must remain counted.
        local wanted={windurst=true};
        if keep_week=='sandoria' then wanted.sandoria=true; end
        if keep_week=='bastok' then wanted.bastok=true; end

        for _,id in ipairs(order) do
            local want=wanted[id]==true;
            if (e.cycle[id]==true)~=want then
                e.cycle[id]=want and true or nil;
                changed=true;
            end
        end

        -- Eeko-Weeko is authoritative for availability. If San d'Oria was
        -- completed this week and he says San d'Oria OR Bastok is available,
        -- Bastok MUST remain available; stale Raifa/lifecycle state cannot win.
        if keep_week~='bastok' then
            if e.cycle.bastok~=nil then e.cycle.bastok=nil; changed=true; end
            e.bastok_activity=type(e.bastok_activity)=='table' and e.bastok_activity or {};
            if e.bastok_activity.state~='READY'
                or e.bastok_activity.completed_at~=nil
                or e.bastok_activity.postcheck_verified_at~=nil
            then changed=true; end
            e.bastok_activity.state='READY';
            e.bastok_activity.completed_at=nil;
            e.bastok_activity.postcheck_verified_at=nil;
            e.bastok_activity.last_reason='Eeko-Weeko verified Bastok available';
        end

        if e.active~=nil then e.active=nil; changed=true; end
        e.eeko.next='sandoria_or_bastok';
        e.eeko.authoritative_weekly_key=HC.modules.core.weekly_key();
        e.eeko.available={
            bastok=(keep_week~='bastok'),
            sandoria=(keep_week~='sandoria'),
            windurst=false,
        };

        local detail="Windurst cleared";
        if keep_week=='sandoria' then
            detail=detail.."; San d'Oria completed this week; Bastok still available in rotation";
        elseif keep_week=='bastok' then
            detail=detail.."; Bastok completed this week; San d'Oria still available in rotation";
        else
            detail=detail.."; San d'Oria or Bastok available";
        end

        record_eeko_state(c,e,
            'windurst_done_sandoria_or_bastok_available',
            detail,changed);
        reset_eeko_sync();
        return;
    end

    -- v6.46.0 captured Eeko-Weeko state:
    -- "...it sounds like all three nation's vermin representatives could use
    -- a bravey-wavey adventurer next week..."
    --
    -- This dialogue is authoritative that the CURRENT rotation is finished:
    -- none of the three nations are available again until next conquest week.
    if s:find("all three nation's vermin representatives",1,true)
        and s:find('could use a bravey-wavey adventurer next week',1,true)
    then
        local changed=false;
        for _,id in ipairs(order) do
            if e.cycle[id]~=true then e.cycle[id]=true; changed=true; end
        end
        if e.active~=nil then e.active=nil; changed=true; end

        e.eeko.next='all_three_next_week';
        e.eeko.authoritative_weekly_key=HC.modules.core.weekly_key();
        e.eeko.available={bastok=false,sandoria=false,windurst=false};
        e.eeko.rotation_complete=true;
        e.eeko.rotation_complete_at=now;

        record_eeko_state(
            c,e,
            'all_three_done_next_week',
            "All three nations cleared; all available next week",
            changed
        );
        reset_eeko_sync();
        return;
    end

    -- Prevent fragments from one interaction leaking into a much later one.
    if eeko_sync.last_at>0 and now-eeko_sync.last_at>12 then
        reset_eeko_sync();
    end
end


local function on_bastok_completion_text(s)
    local lower=string.lower(tostring(s or ''));
    local c=HC.modules.state.get_char();
    local e=ensure(c);

    -- Capture-verified Raifa Bastok Eco-War turn-in.
    -- This dialogue is authoritative for Bastok completion and does not depend
    -- on the one-time HorizonXI achievement message.
    if lower:find('raifa',1,true)
        and lower:find('an indigested ore from the creatures',1,true)
        and lower:find('i knew you were committed to our cause',1,true)
        and lower:find('here is your reward, as promised',1,true)
    then
        e.active='bastok';
        local ok=M.auto_complete(c,'VERIFIED BY RAIFA - Indigested Ore turn-in');
        if ok then
            e.bastok_activity=type(e.bastok_activity)=='table' and e.bastok_activity or {};
            e.bastok_activity.state='COMPLETE';
            e.bastok_activity.completed_at=os.time();
            e.bastok_activity.postcheck_verified_at=nil;
            e.bastok_activity.last_reason='Raifa completion dialogue';
            HC.modules.state.save();
        end
        return true;
    end

    -- Raifa's baked-popoto line is generic dialogue, NOT completion evidence.
    if lower:find('raifa',1,true)
        and lower:find("i can't believe there are people who throw away the skins of baked popotoes",1,true)
        and lower:find("they're so tasty and so good for you",1,true)
    then
        local now=os.time();
        if now-(tonumber(raifa_postcomplete_last_at) or 0)<=3 then return true; end
        raifa_postcomplete_last_at=now;
        e.bastok_activity=type(e.bastok_activity)=='table' and e.bastok_activity or {};
        e.bastok_activity.last_checked_at=now;
        e.bastok_activity.last_reason='Raifa generic baked-popoto dialogue - NOT COMPLETION';
        e.bastok_activity.generic_dialogue=true;
        HC.modules.state.save();
        HC.msg('Eco-Warrior Bastok: Raifa generic dialogue observed - NOT marked complete.');
        return true;
    end

    return false;
end

local function sandoria_debounce(sig)
    local now=os.time();
    if sandoria_text_last.sig==sig and now-(tonumber(sandoria_text_last.at) or 0)<=3 then
        return false;
    end
    sandoria_text_last.sig=sig;
    sandoria_text_last.at=now;
    return true;
end

local function set_sandoria_state(c,state,reason,source)
    local e=ensure(c);
    local a=e.sandoria_activity;
    local now=os.time();

    a.state=state;
    a.last_reason=reason;
    a.evidence_source=source or 'chat';
    a.last_verified_at=now;

    if state=='IN PROGRESS' then
        a.accepted_at=a.accepted_at or now;
        e.active='sandoria';
    elseif state=='KEY ITEM READY' then
        a.accepted_at=a.accepted_at or now;
        a.key_item_at=now;
        e.active='sandoria';
    elseif state=='RETURN TO NOREJAIE' then
        a.accepted_at=a.accepted_at or now;
        a.key_item_at=a.key_item_at or now;
        a.return_ready_at=now;
        e.active='sandoria';
    elseif state=='COMPLETE' then
        a.completed_at=a.completed_at or now;
        a.postcheck_verified_at=now;
        e.cycle.sandoria=true;
        e.completed_this_week='sandoria';
        e.completed_this_week_weekly_key=HC.modules.core.weekly_key();
        e.active=nil;
        c.dragon_weekly=type(c.dragon_weekly)=='table' and c.dragon_weekly or {};
        c.dragon_weekly.dc_eco=true;
    end

    if HC.modules.state and HC.modules.state.audit then
        HC.modules.state.audit(c,'eco',
            "San d'Oria Eco-War -> "..state,
            'VERIFIED',source or reason);
    end
    HC.modules.state.save();
end

local function on_sandoria_lifecycle_text(s)
    local lower=string.lower(tostring(s or ''));
    local c=HC.modules.state.get_char();

    -- Capture verified: field agent confirms the assignment/objective.
    if lower:find('rojaireaut',1,true)
        and lower:find('v.e.r.m.i.n. extermination operation',1,true)
    then
        if sandoria_debounce('sandoria_active') then
            set_sandoria_state(c,'IN PROGRESS',
                'Rojaireaut V.E.R.M.I.N. assignment dialogue',
                'Rojaireaut assignment dialogue');
            HC.msg("AUTO: Eco-Warrior San d'Oria - ACTIVE [VERIFIED BY ROJAIREAUT].");
        end
        return true;
    end

    -- Capture verified: the required proof key item was obtained.
    if lower:find('obtained key item',1,true)
        and lower:find('indigested stalagmite',1,true)
    then
        if sandoria_debounce('sandoria_key_item') then
            set_sandoria_state(c,'KEY ITEM READY',
                'Indigested Stalagmite obtained',
                'Key item acquisition');
            HC.msg("AUTO: Eco-Warrior San d'Oria - KEY ITEM READY [Indigested Stalagmite].");
        end
        return true;
    end

    -- Capture verified: Rojaireaut recognizes the proof and sends the player
    -- back to Norejaie.
    if lower:find('rojaireaut',1,true)
        and lower:find('indigested stalagmite from the fiend',1,true)
        and lower:find('proof enough for norejaie',1,true)
        and lower:find("take it back to her in san d'oria",1,true)
    then
        if sandoria_debounce('sandoria_return') then
            set_sandoria_state(c,'RETURN TO NOREJAIE',
                'Rojaireaut confirmed proof; return to Norejaie',
                'Rojaireaut proof dialogue');
            HC.msg("AUTO: Eco-Warrior San d'Oria - RETURN TO NOREJAIE [VERIFIED].");
        end
        return true;
    end

    -- Capture verified repeatable completion signal: Norejaie accepts the proof
    -- and explicitly gives the reward. This does not depend on the one-time
    -- achievement message.
    if lower:find('norejaie',1,true)
        and lower:find("you've brought me an indigested stalagmite from the vanquished fiend",1,true)
        and lower:find("here's your reward, as promised",1,true)
    then
        if sandoria_debounce('sandoria_complete_reward') then
            local e=ensure(c);
            e.active='sandoria';
            M.auto_complete(c,'VERIFIED BY NOREJAIE - Indigested Stalagmite turn-in');
            set_sandoria_state(c,'COMPLETE',
                'Norejaie reward dialogue',
                'Norejaie turn-in dialogue');
            HC.msg("AUTO: Eco-Warrior San d'Oria COMPLETE [VERIFIED BY NOREJAIE REWARD DIALOGUE].");
        end
        return true;
    end

    -- Capture verified repeatable post-completion recovery. Norejaie's mulsum
    -- line is available after the weekly San d'Oria Eco-War is already done,
    -- so it can reconstruct completion after reload/login.
    if lower:find('norejaie',1,true)
        and lower:find("i'm glad they've run out of mulsum",1,true)
        and lower:find('it would completely ruin my diet',1,true)
    then
        if sandoria_debounce('sandoria_postcomplete') then
            set_sandoria_state(c,'COMPLETE',
                'Norejaie post-completion mulsum dialogue',
                'Norejaie post-completion dialogue');
            HC.msg("AUTO: Eco-Warrior San d'Oria COMPLETE [VERIFIED BY NOREJAIE POST-COMPLETION DIALOGUE].");
        end
        return true;
    end

    return false;
end

local function on_norejaie_text(s)
    if on_sandoria_lifecycle_text(s) then return; end
    local lower=string.lower(tostring(s or ''));
    if not lower:find('norejaie',1,true) then return; end

    local c=HC.modules.state.get_char();
    local e=ensure(c);
    local a=e.sandoria_activity;
    local now=os.time();

    -- Capture-verified quest acceptance.
    if lower:find("i knew you'd come through for us!",1,true)
        and lower:find("bring me proof that you've defeated the creature",1,true)
    then
        a.state='IN PROGRESS';
        a.accepted_at=now;
        a.postcheck_verified_at=nil;
        a.last_reason='Norejaie acceptance dialogue';
        e.active='sandoria';
        HC.modules.state.save();
        HC.msg("AUTO: Eco-Warrior San d'Oria - IN PROGRESS [Norejaie acceptance].");
        return;
    end

    -- Capture-verified post-pickup / reload recovery.
    if lower:find('rojaireaut, our v.e.r.m.i.n. agent in the field',1,true)
        and lower:find('will be waiting with further instructions in the caves',1,true)
    then
        if e.completed_this_week~='sandoria' then
            a.state='IN PROGRESS';
            a.accepted_at=a.accepted_at or now;
            a.postcheck_verified_at=now;
            a.last_reason='Norejaie post-pickup dialogue';
            e.active='sandoria';
            HC.modules.state.save();
            HC.msg("AUTO: Eco-Warrior San d'Oria - IN PROGRESS [VERIFIED BY NOREJAIE].");
        end
        return;
    end
end


local function windurst_debounce(sig)
    local now=os.time();
    if windurst_text_last.sig==sig and (now-(tonumber(windurst_text_last.at) or 0))<=2 then return false; end
    windurst_text_last.sig=sig;
    windurst_text_last.at=now;
    return true;
end

local function set_windurst_state(c,state,reason,source)
    local e=ensure(c);
    e.windurst_activity=type(e.windurst_activity)=='table' and e.windurst_activity or {};
    local a=e.windurst_activity;
    local now=os.time();
    local wk=HC.modules.core.weekly_key();

    a.state=state;
    a.last_reason=reason;
    a.evidence_source=source or 'chat';
    a.last_verified_at=now;
    if state=='IN PROGRESS' then
        a.accepted_at=a.accepted_at or now;
        a.accepted_weekly_key=wk;
        e.active='windurst';
    elseif state=='FIELD PHASE' then
        a.accepted_at=a.accepted_at or now;
        a.accepted_weekly_key=wk;
        a.field_at=now;
        e.active='windurst';
    elseif state=='KILL PHASE' then
        a.accepted_at=a.accepted_at or now;
        a.accepted_weekly_key=wk;
        a.field_at=a.field_at or now;
        a.level_cap_at=now;
        e.active='windurst';
    elseif state=='KEY ITEM READY' then
        a.accepted_at=a.accepted_at or now;
        a.accepted_weekly_key=wk;
        a.key_item_at=now;
        e.active='windurst';
    elseif state=='RETURN TO LUMOMO' then
        a.accepted_at=a.accepted_at or now;
        a.accepted_weekly_key=wk;
        a.key_item_at=a.key_item_at or now;
        a.return_ready_at=now;
        e.active='windurst';
    end
    if HC.modules.state and HC.modules.state.audit then
        HC.modules.state.audit(c,'eco','Windurst Eco-War -> '..state,'VERIFIED',source or reason);
    end
    HC.modules.state.save();
end

local function on_windurst_lifecycle_text(s)
    local lower=string.lower(tostring(s or ''));
    local c=HC.modules.state.get_char();
    local e=ensure(c);
    local a=type(e.windurst_activity)=='table' and e.windurst_activity or {};

    -- 2026-08-30 capture: Lumomo explicitly accepts the Windurst Eco-War
    -- assignment and directs the player to Ahko Mhalijikhari in Shakhrami.
    if lower:find('lumomo',1,true)
        and lower:find('excellentaru!',1,true)
        and lower:find("bring me back proof",1,true)
        and lower:find("trouncy-wounced the beasties",1,true)
    then
        if windurst_debounce('lumomo_accept') then
            set_windurst_state(c,'IN PROGRESS','Lumomo accepted Eco-War assignment','Lumomo acceptance dialogue');
            HC.msg('AUTO: Eco-Warrior Windurst - IN PROGRESS [VERIFIED BY LUMOMO].');
        end
        return true;
    end

    if lower:find('lumomo',1,true)
        and lower:find('ahko mhalijikhari',1,true)
        and lower:find('maze',1,true)
        and lower:find('further instructions',1,true)
    then
        if windurst_debounce('lumomo_agent') then
            set_windurst_state(c,'IN PROGRESS','Lumomo directed player to Ahko Mhalijikhari','Lumomo field-agent dialogue');
        end
        return true;
    end

    -- 2026-08-30 capture: Ahko gives the field objective around I-10 and
    -- prepares/applies the special ointment used for the capped kill phase.
    if lower:find('ahko mhalijikhari',1,true)
        and lower:find("find and defeat the creatures",1,true)
        and lower:find('take the proof',1,true)
        and lower:find('lumomo',1,true)
    then
        if windurst_debounce('ahko_field') then
            set_windurst_state(c,'FIELD PHASE','Ahko Mhalijikhari field instructions','Ahko assignment dialogue');
        end
        return true;
    end

    if lower:find('ahko mhalijikhari',1,true)
        and lower:find('mostly around i-10',1,true)
    then
        if windurst_debounce('ahko_i10') then
            set_windurst_state(c,'FIELD PHASE','Ahko identified Eco-War targets around I-10','Ahko target-location dialogue');
        end
        return true;
    end

    if lower:find('level is currently restricted to 20',1,true)
        and a.accepted_weekly_key==HC.modules.core.weekly_key()
        and (a.state=='FIELD PHASE' or a.state=='IN PROGRESS' or a.field_at~=nil)
    then
        if windurst_debounce('windurst_level20') then
            set_windurst_state(c,'KILL PHASE','Level restriction 20 applied after Ahko ointment','Level restriction confirmation');
        end
        return true;
    end

    -- 2026-08-30 capture: direct KI acquisition line. 0x055 remains the
    -- authoritative ownership source; this dialogue gives a readable lifecycle cue.
    if lower:find('obtained key item',1,true)
        and lower:find('indigested meat',1,true)
    then
        if windurst_debounce('windurst_meat') then
            set_windurst_state(c,'KEY ITEM READY','Indigested Meat obtained','Key item acquisition dialogue');
        end
        return true;
    end

    -- 2026-08-30 capture: Ahko recognizes the proof and sends the player back
    -- to Lumomo; the level restriction immediately falls afterward.
    if lower:find('ahko mhalijikhari',1,true)
        and lower:find('chunk of indigested meat',1,true)
        and lower:find('take it back to lumomo',1,true)
    then
        if windurst_debounce('ahko_return') then
            set_windurst_state(c,'RETURN TO LUMOMO','Ahko confirmed Indigested Meat; return to Lumomo','Ahko proof dialogue');
            HC.msg('AUTO: Eco-Warrior Windurst - RETURN TO LUMOMO [VERIFIED].');
        end
        return true;
    end

    if lower:find('level restriction effect wears off',1,true)
        and a.accepted_weekly_key==HC.modules.core.weekly_key()
        and (a.state=='RETURN TO LUMOMO' or a.state=='KEY ITEM READY')
    then
        if windurst_debounce('windurst_uncap') then
            set_windurst_state(c,'RETURN TO LUMOMO','Level restriction removed after Ahko proof check','Level restriction removal');
        end
        return true;
    end

    -- 2026-08-30 final Windurst capture: Lumomo explicitly accepts the
    -- Indigested Meat and announces the reward.  Keep this as pending proof
    -- until the immediately-following Dragon Chronicles reward line arrives;
    -- the two-line correlation avoids promoting unrelated/stale dialogue.
    if lower:find('lumomo',1,true)
        and lower:find('yuck!',1,true)
        and lower:find('indigested meat',1,true)
        and lower:find("here's your reward",1,true)
        and a.accepted_weekly_key==HC.modules.core.weekly_key()
        and (a.state=='RETURN TO LUMOMO' or a.state=='KEY ITEM READY')
    then
        if windurst_debounce('lumomo_reward_dialogue') then
            a.completion_pending_at=os.time();
            a.completion_pending_weekly_key=HC.modules.core.weekly_key();
            a.completion_pending_source='Lumomo reward dialogue';
            a.last_reason='Lumomo accepted Indigested Meat; waiting for reward confirmation';
            a.last_verified_at=os.time();
            HC.modules.state.save();
        end
        return true;
    end

    -- Capture-correlated reward confirmation.  Page from the Dragon Chronicles
    -- followed Lumomo's turn-in dialogue by five seconds in the verified run.
    -- Require the pending dialogue from this same weekly cycle and a short
    -- correlation window before marking Windurst COMPLETE.
    if lower:find('obtained:',1,true)
        and lower:find('page from the dragon chronicles',1,true)
        and a.completion_pending_weekly_key==HC.modules.core.weekly_key()
        and tonumber(a.completion_pending_at)~=nil
        and (os.time()-tonumber(a.completion_pending_at))<=20
    then
        if windurst_debounce('windurst_final_reward') then
            e.active='windurst';
            local completed=M.auto_complete(c,'Lumomo turn-in + Dragon Chronicles reward [VERIFIED]');
            if completed then
                local wa=ensure(c).windurst_activity;
                wa.completion_verified_at=os.time();
                wa.completion_evidence='Lumomo reward dialogue + Page from the Dragon Chronicles';
                wa.evidence_source='capture-verified final turn-in';
                wa.reward_item='Page from the Dragon Chronicles';
                wa.completion_pending_at=nil;
                wa.completion_pending_weekly_key=nil;
                wa.completion_pending_source=nil;
                HC.modules.state.save();
                HC.msg('AUTO: Eco-Warrior Windurst COMPLETE [VERIFIED BY LUMOMO REWARD].');
            end
        end
        return true;
    end

    return false;
end

function M.windurst_status(c)
    local e=ensure(c);
    local a=type(e.windurst_activity)=='table' and e.windurst_activity or {};
    if e.completed_this_week=='windurst' or a.state=='COMPLETE' then return 'COMPLETE THIS WEEK'; end
    if a.state=='RETURN TO LUMOMO' then return 'RETURN TO LUMOMO | Indigested Meat ready'; end
    if a.state=='KEY ITEM READY' then return 'KEY ITEM READY | Talk to Ahko Mhalijikhari'; end
    if a.state=='KILL PHASE' then return 'KILL PHASE | Level capped at 20 | Targets near I-10'; end
    if a.state=='FIELD PHASE' then return 'FIELD PHASE | Talk to Ahko / targets near I-10'; end
    if a.state=='IN PROGRESS' then return 'IN PROGRESS | Go to Maze of Shakhrami'; end
    return 'READY | Talk to Lumomo';
end


function M.sync_status(c)
    c=c or (HC and HC.modules and HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    local e=ensure(c);
    local ee=type(e.eeko)=='table' and e.eeko or {};
    local wk=HC.modules.core.weekly_key();
    local current=(ee.authoritative_weekly_key==wk);
    local ever_at=tonumber(ee.last_sync_at);
    local synced=current and ever_at~=nil;
    return {
        synced=synced, initialized=ever_at~=nil, current_week=current, at=ever_at,
        state=ee.state, detail=ee.detail, confidence=ee.confidence,
        weekly_key=ee.authoritative_weekly_key,
    };
end

function M.sandoria_status(c)
    local e=ensure(c);
    local a=e.sandoria_activity;

    if e.completed_this_week=='sandoria' or a.state=='COMPLETE' then
        if a.postcheck_verified_at then
            return 'COMPLETE THIS WEEK | VERIFIED';
        end
        return 'COMPLETE THIS WEEK';
    elseif a.state=='RETURN TO NOREJAIE' then
        return "RETURN TO NOREJAIE | Indigested Stalagmite ready";
    elseif a.state=='KEY ITEM READY' then
        return "KEY ITEM READY | Talk to Rojaireaut in Ordelle's Caves";
    elseif a.state=='IN PROGRESS' then
        if a.postcheck_verified_at then
            return "IN PROGRESS | VERIFIED BY NOREJAIE | Talk to Rojaireaut in Ordelle's Caves";
        end
        return "IN PROGRESS | Go to Ordelle's Caves";
    end
    return 'READY | Talk to Norejaie';
end




-- v6.9.52: authoritative Eco-Warrior quest acceptance from native 0x056
-- active quest logs. This complements the 0x055 proof-KI ownership path:
-- 0x056 proves the weekly quest is accepted/in progress; 0x055 proves the
-- proof key item is held and ready to turn in. Leaving the active quest log
-- alone is never treated as completion.
local ECO_QUESTS={
    [0]={nation='sandoria', quest_id=97, label="Eco-Warrior (San d'Oria)"},
    [1]={nation='bastok',   quest_id=65, label='Eco-Warrior (Bastok)'},
    [2]={nation='windurst', quest_id=84, label='Eco-Warrior (Windurst)'},
};

local function reconcile_native_quest(log_id)
    local def=ECO_QUESTS[tonumber(log_id)];
    if def==nil or not HC.modules.quests or not HC.modules.quests.is_active then return false; end
    local active=HC.modules.quests.is_active(log_id,def.quest_id);
    if active==nil then return false; end

    local c=HC.modules.state.get_char();
    local e=ensure(c);
    e.quest_state=type(e.quest_state)=='table' and e.quest_state or {};
    local rec=type(e.quest_state[def.nation])=='table' and e.quest_state[def.nation] or {};
    e.quest_state[def.nation]=rec;
    local now=os.time();
    local changed=(rec.active~=(active==true));
    rec.active=(active==true);
    rec.verified_at=now;
    rec.source='0x056 active quest bitmap';
    rec.log_id=log_id;
    rec.quest_id=def.quest_id;

    if active==true then
        local completed_current=(e.completed_this_week==def.nation
            and e.completed_this_week_weekly_key==HC.modules.core.weekly_key());
        if not completed_current then
            local field=def.nation..'_activity';
            e[field]=type(e[field])=='table' and e[field] or {};
            local a=e[field];
            local windurst_guard=(def.nation=='windurst'
                and a.accepted_weekly_key~=HC.modules.core.weekly_key()
                and (a.state==nil or a.state=='READY'));
            if not windurst_guard
                and a.state~='COMPLETE' and a.state~='KEY ITEM READY'
                and a.state~='RETURN TO NOREJAIE' and a.state~='RETURN TO LUMOMO'
            then
                if e.active~=def.nation then e.active=def.nation; changed=true; end
                if a.state~='IN PROGRESS' and a.state~='FIELD PHASE' and a.state~='KILL PHASE' then changed=true; end
                if a.state~='FIELD PHASE' and a.state~='KILL PHASE' then a.state='IN PROGRESS'; end
                a.accepted_at=a.accepted_at or now;
                a.last_reason=def.label..' active [0x056 QUEST VERIFIED]';
                a.evidence_source=rec.source;
            elseif windurst_guard then
                rec.note='ACTIVE bit observed but not promoted without current-week Lumomo/Ahko evidence';
            end
        end
    else
        -- Absence from ACTIVE is authoritative only for "not currently active".
        -- It is not proof of success, so never mark COMPLETE here.
        if e.active==def.nation then
            e.active=nil;
            changed=true;
        end
    end

    if changed and HC.modules.state and HC.modules.state.save then HC.modules.state.save(); end
    return changed;
end

local function on_native_quest_update(log_id,previous,current_bitmap)
    if ECO_QUESTS[tonumber(log_id)]~=nil then
        reconcile_native_quest(tonumber(log_id));
    end
end

function M.init(ctx)
    HC=ctx;
    if HC.modules.packets then
        HC.modules.packets.register_text('eco_eeko',on_eeko_text);
        HC.modules.packets.register_text('eco_bastok_raifa',on_bastok_completion_text);
        HC.modules.packets.register_text('eco_sandoria_lifecycle',on_sandoria_lifecycle_text);
        HC.modules.packets.register_text('eco_sandoria_norejaie',on_norejaie_text);
        HC.modules.packets.register_text('eco_windurst_lifecycle',on_windurst_lifecycle_text);
    end
    HC.modules.packets.register(0x034,'Eeko-Weeko',function(e) M.on_menu(e); end);
    if HC.modules.quests and HC.modules.quests.register_update then
        HC.modules.quests.register_update(on_native_quest_update);
    end
end

local function target_name()
    local name=nil;
    pcall(function()
        local mm=AshitaCore:GetMemoryManager();
        local t=mm:GetTarget(); local ent=mm:GetEntity();
        local idx; pcall(function() idx=t:GetTargetIndex(0); end);
        if idx and idx>0 then name=ent:GetName(idx); end
    end);
    return tostring(name or '');
end

local function hex(s)
    if type(s)~='string' then return nil; end
    local o={}; for i=1,#s do o[#o+1]=string.format('%02X',string.byte(s,i)); end
    return table.concat(o);
end

function M.on_menu(e)
    if string.lower(target_name())~='eeko-weeko' then return; end
    local sig=hex(e.data); if sig==nil then return; end
    last_sig=sig;
    local c=HC.modules.state.get_char();
    c.eeko_packets=type(c.eeko_packets)=='table' and c.eeko_packets or {signatures={}};
    c.eeko_packets.signatures=type(c.eeko_packets.signatures)=='table' and c.eeko_packets.signatures or {};
    local snap=c.eeko_packets.signatures[sig];
    if type(snap)=='table' then
        c.eco.cycle=snap.cycle or {};
        c.eco.completed_this_week=snap.completed_this_week;
        c.eco.active=snap.active;
        c.eco.eeko=type(c.eco.eeko)=='table' and c.eco.eeko or {};
        c.eco.eeko.last_sync_at=os.time();
        c.eco.eeko.authoritative_weekly_key=HC.modules.core.weekly_key();
        c.eco.eeko.confidence='VERIFIED BY EEKO-WEEKO PACKET';
        c.eco.eeko.detail=c.eco.eeko.detail or 'Current Eco-Warrior rotation synchronized from Eeko-Weeko';
        last_known=true;
        HC.modules.state.save();
        if HC.modules.dependencies and HC.modules.dependencies.invalidate then HC.modules.dependencies.invalidate('eco','Eeko-Weeko packet synchronization');
        elseif HC.modules.releasehealth and HC.modules.releasehealth.invalidate then HC.modules.releasehealth.invalidate(); end
        HC.msg('Eeko-Weeko packet recognized: Eco rotation updated.');
    else
        last_known=false;
        HC.msg('Eeko-Weeko packet captured: use /hcheck eeko learn after syncing the rotation.');
    end
end


function M.auto_complete(c, why)
    local e=ensure(c);
    local id=e.active;
    if id==nil or q[id]==nil then
        HC.msg('AUTO: Eco-Warrior completion detected, but the active nation is unknown; rotation was not guessed.');
        return false;
    end
    local old_cycle=e.cycle[id];
    local old_completed=e.completed_this_week;
    local old_active=e.active;
    -- Never roll the rotation over at completion time. A full 3/3 rotation
    -- must remain 3/3 until the actual conquest weekly reset. Older code
    -- cleared the raw cycle here when all three flags were already present
    -- (for example, two real clears plus a stale Eeko availability flag),
    -- which could turn a final Bastok completion into 1/3.
    e.cycle[id]=true;
    e.completed_this_week=id;
    e.completed_this_week_weekly_key=HC.modules.core.weekly_key();
    e.active=nil;

    -- A directly verified completion is newer evidence than an earlier
    -- Eeko-Weeko availability snapshot. Keep the snapshot for diagnostics,
    -- but stop it from masking this nation as "available" in the rotation.
    if type(e.eeko)=='table'
        and e.eeko.authoritative_weekly_key==HC.modules.core.weekly_key()
        and type(e.eeko.available)=='table'
    then
        e.eeko.available[id]=false;
        e.eeko.last_completion_override=id;
        e.eeko.last_completion_override_at=os.time();
    end
    if id=='sandoria' then
        e.sandoria_activity=type(e.sandoria_activity)=='table' and e.sandoria_activity or {};
        e.sandoria_activity.state='COMPLETE';
        e.sandoria_activity.completed_at=os.time();
        e.sandoria_activity.last_reason=why or 'Eco-Warrior completion';
    elseif id=='bastok' then
        e.bastok_activity=type(e.bastok_activity)=='table' and e.bastok_activity or {};
        e.bastok_activity.state='COMPLETE';
        e.bastok_activity.completed_at=os.time();
        e.bastok_activity.last_reason=why or 'Eco-Warrior completion';
    elseif id=='windurst' then
        e.windurst_activity=type(e.windurst_activity)=='table' and e.windurst_activity or {};
        e.windurst_activity.state='COMPLETE';
        e.windurst_activity.completed_at=os.time();
        e.windurst_activity.last_reason=why or 'Eco-Warrior completion';
    end
    if type(e.keyitems)=='table' and type(e.keyitems[id])=='table' then
        e.keyitems[id].owned=false;
        e.keyitems[id].completed_at=os.time();
    end
    c.dragon_weekly.dc_eco=true;
    if HC.modules.automation and HC.modules.automation.record_external then
        HC.modules.automation.record_external(c,'eco_rotation',
            q[id].name..' - '..tostring(why or 'Eco-Warrior completion'),
            {scope='eco_rotation',key=id,old_cycle=old_cycle,old_completed=old_completed,old_active=old_active});
    end
    HC.modules.state.save();
    HC.msg('AUTO: Eco-Warrior '..q[id].name..' marked complete in rotation.');
    return true;
end

-- v6.9.37: authoritative Eco-Warrior proof key-item ownership from the
-- server 0x055 bitmap.  This deliberately tracks only READY-TO-TURN-IN proof;
-- it never treats disappearance of a proof KI as quest completion.
function M.reconcile_keyitem_ownership(nation,owned,source,resource_id,label)
    nation=string.lower(tostring(nation or ''));
    if q[nation]==nil or owned==nil then return false; end
    local c=HC.modules.state.get_char();
    local e=ensure(c);
    e.keyitems=type(e.keyitems)=='table' and e.keyitems or {};
    local rec=type(e.keyitems[nation])=='table' and e.keyitems[nation] or {};
    e.keyitems[nation]=rec;
    local now=os.time();
    local changed=(rec.owned~=owned) or (rec.resource_id~=resource_id) or (rec.source~=source);
    rec.owned=owned==true;
    rec.verified_at=now;
    rec.source=source or '0x055 key-item bitmap';
    rec.resource_id=resource_id;
    rec.label=label or rec.label;

    if owned==true then
        e.active=nation;
        rec.ready_at=rec.ready_at or now;
        if nation=='sandoria' then
            e.sandoria_activity=type(e.sandoria_activity)=='table' and e.sandoria_activity or {};
            if e.sandoria_activity.state~='COMPLETE' and e.sandoria_activity.state~='RETURN TO NOREJAIE' then
                e.sandoria_activity.state='KEY ITEM READY';
                e.sandoria_activity.key_item_at=now;
                e.sandoria_activity.last_reason=(label or 'Eco-War proof')..' owned [0x055 KI VERIFIED]';
                e.sandoria_activity.evidence_source=rec.source;
            end
        elseif nation=='bastok' then
            e.bastok_activity=type(e.bastok_activity)=='table' and e.bastok_activity or {};
            if e.bastok_activity.state~='COMPLETE' then
                e.bastok_activity.state='KEY ITEM READY';
                e.bastok_activity.key_item_at=now;
                e.bastok_activity.last_reason=(label or 'Eco-War proof')..' owned [0x055 KI VERIFIED]';
            end
        elseif nation=='windurst' then
            e.windurst_activity=type(e.windurst_activity)=='table' and e.windurst_activity or {};
            if e.windurst_activity.state~='COMPLETE' then
                e.windurst_activity.state='KEY ITEM READY';
                e.windurst_activity.accepted_at=e.windurst_activity.accepted_at or now;
                e.windurst_activity.accepted_weekly_key=HC.modules.core.weekly_key();
                e.windurst_activity.key_item_at=now;
                e.windurst_activity.last_reason=(label or 'Eco-War proof')..' owned [0x055 KI VERIFIED]';
                e.windurst_activity.evidence_source=rec.source;
            end
        end
    end

    if changed and HC.modules.state and HC.modules.state.save then HC.modules.state.save(); end
    return changed;
end

function M.keyitem_status(c,nation)
    c=c or HC.modules.state.get_char();
    local e=ensure(c);
    local rec=type(e.keyitems)=='table' and e.keyitems[string.lower(tostring(nation or ''))] or nil;
    if type(rec)~='table' then return nil; end
    return rec;
end

function M.rotation_count(c)
    local e=ensure(c);
    local eeko_current=e.eeko
        and e.eeko.authoritative_weekly_key==HC.modules.core.weekly_key()
        and type(e.eeko.available)=='table';
    local n=0;
    for _,id in ipairs(order) do
        local completed_current=(e.completed_this_week==id
            and e.completed_this_week_weekly_key==HC.modules.core.weekly_key());
        local cleared=e.cycle[id]==true or completed_current;
        if eeko_current and e.eeko.available[id]==true and not completed_current then cleared=false; end
        if cleared then n=n+1; end
    end
    return n,3;
end

function M.draw(c,embedded)
    local imgui=HC.imgui; if imgui==nil then return; end
    local e=ensure(c);
    local developer=(type(c.settings)=='table' and c.settings.developer_mode==true);
    local eeko_current=e.eeko
        and e.eeko.authoritative_weekly_key==HC.modules.core.weekly_key()
        and type(e.eeko.available)=='table';

    local n=0;
    for _,id in ipairs(order) do
        local completed_current=(e.completed_this_week==id
            and e.completed_this_week_weekly_key==HC.modules.core.weekly_key());
        local cleared=e.cycle[id]==true or completed_current;
        if eeko_current and e.eeko.available[id]==true and not completed_current then cleared=false; end
        if cleared then n=n+1; end
    end

    if embedded~=true then
        HC.modules.uikit.section_header_action('Eco-Warrior',string.format('Rotation %d/3 cleared',n),function()
            if developer and HC.modules.learning and HC.modules.learning.capture_button then
                HC.modules.learning.capture_button('eco','eco_rotation');
            end
        end);
    elseif developer and HC.modules.learning and HC.modules.learning.capture_button then
        HC.modules.learning.capture_button('eco','eco_rotation');
    end

    local eco_rows={};
    for _,id in ipairs(order) do
        local eeko_available=eeko_current and e.eeko.available[id]==true;
        local completed_current=(e.completed_this_week==id
            and e.completed_this_week_weekly_key==HC.modules.core.weekly_key());
        local ki=(type(e.keyitems)=='table') and e.keyitems[id] or nil;
        local ki_ready=(type(ki)=='table' and ki.owned==true and not completed_current);

        local status='AVAILABLE';
        local detail=nil;

        if ki_ready then
            status='TURN IN';
            detail=tostring(ki.label or 'Eco-War proof')..' | KI VERIFIED';
        elseif completed_current then
            status='COMPLETED THIS WEEK';
            detail='VERIFIED';
        elseif id=='windurst' and type(e.windurst_activity)=='table' and e.windurst_activity.state=='RETURN TO LUMOMO' then
            status='TURN IN';
            detail='Return to Lumomo | VERIFIED';
        elseif id=='windurst' and type(e.windurst_activity)=='table' and e.windurst_activity.state=='KILL PHASE' then
            status='ACTIVE';
            detail='Level 20 kill phase | I-10';
        elseif id=='windurst' and type(e.windurst_activity)=='table' and e.windurst_activity.state=='FIELD PHASE' then
            status='ACTIVE';
            detail='Ahko Mhalijikhari | I-10';
        elseif e.active==id then
            status='ACTIVE';
            if id=='windurst' and type(e.windurst_activity)=='table' and e.windurst_activity.last_reason then
                detail=e.windurst_activity.last_reason;
            end
        elseif eeko_available then
            status='AVAILABLE';
            detail='EEKO VERIFIED';
        elseif e.cycle[id] then
            status='CLEARED';
            if id=='bastok' and e.bastok_activity and e.bastok_activity.state=='COMPLETE' then
                detail=e.bastok_activity.postcheck_verified_at and 'RAIFA VERIFIED' or 'RAIFA';
            end
        end

        eco_rows[#eco_rows+1]={
            id=id,
            name=q[id].name,
            status=status,
            detail=detail,
        };
    end

    local table_supported=(imgui.BeginTable~=nil and imgui.TableSetupColumn~=nil
        and imgui.TableHeadersRow~=nil and imgui.TableNextRow~=nil
        and imgui.TableSetColumnIndex~=nil and imgui.EndTable~=nil);
    local table_flags=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
    if table_supported and imgui.BeginTable('##eco_rotation_table_v68732',3,table_flags) then
        imgui.TableSetupColumn('Nation',0,120);
        imgui.TableSetupColumn('Status',0,190);
        imgui.TableSetupColumn('Notes',0,340);
        imgui.TableHeadersRow();

        for _,row in ipairs(eco_rows) do
            imgui.TableNextRow();

            imgui.TableSetColumnIndex(0);
            imgui.Text(tostring(row.name or ''));

            imgui.TableSetColumnIndex(1);
            imgui.Text(tostring(row.status or ''));

            imgui.TableSetColumnIndex(2);
            if row.detail and row.detail~='' then
                imgui.TextDisabled(tostring(row.detail));
            else
                imgui.TextDisabled('-');
            end
            if developer then
                imgui.SameLine();
                if imgui.SmallButton('Complete##v5eco'..row.id) then
                    e.cycle[row.id]=true;
                    e.completed_this_week=row.id;
                    e.completed_this_week_weekly_key=HC.modules.core.weekly_key();
                    e.active=nil;
                    if type(e.eeko)=='table'
                        and e.eeko.authoritative_weekly_key==HC.modules.core.weekly_key()
                        and type(e.eeko.available)=='table'
                    then
                        e.eeko.available[row.id]=false;
                    end
                    c.dragon_weekly.dc_eco=true;
                    HC.modules.state.save();
                end
            end
        end
        imgui.EndTable();
    else
        for _,row in ipairs(eco_rows) do
            imgui.Text(string.format('%-10s | %-19s', tostring(row.name or ''), tostring(row.status or '')));
            imgui.SameLine();
            imgui.TextDisabled(row.detail and tostring(row.detail) or '-');
            if developer then
                imgui.SameLine();
                if imgui.SmallButton('Complete##v5eco'..row.id) then
                    e.cycle[row.id]=true;
                    e.completed_this_week=row.id;
                    e.completed_this_week_weekly_key=HC.modules.core.weekly_key();
                    e.active=nil;
                    if type(e.eeko)=='table'
                        and e.eeko.authoritative_weekly_key==HC.modules.core.weekly_key()
                        and type(e.eeko.available)=='table'
                    then
                        e.eeko.available[row.id]=false;
                    end
                    c.dragon_weekly.dc_eco=true;
                    HC.modules.state.save();
                end
            end
        end
    end

    if n>=3 then
        imgui.Separator();
        local remain=HC.modules.core.seconds_until_weekly_reset();
        imgui.TextDisabled('All nations available next week in: '..HC.modules.core.format_duration(remain));
    end

    -- Keep packet/lifecycle troubleshooting available in developer mode only.
    if developer then
        imgui.Separator();
        imgui.TextDisabled('Diagnostics');
        imgui.TextDisabled('Eeko packet: '..(last_sig and (last_known and 'LEARNED' or 'UNLEARNED') or 'waiting'));
        if e.eeko and e.eeko.state then
            imgui.TextDisabled('Eeko sync: '..tostring(e.eeko.confidence or 'OBSERVED'));
            if e.eeko.detail then imgui.TextDisabled('  '..tostring(e.eeko.detail)); end
        end
        local a=e.sandoria_activity or {};
        if a.state and a.state~='READY' then
            local line='San d\'Oria lifecycle: '..tostring(a.state);
            if a.last_reason then line=line..' - '..tostring(a.last_reason); end
            imgui.TextDisabled(line);
        end
    end
end

function M.command(w)
    if string.lower(w[2] or '')~='eeko' then return false; end
    local action=string.lower(w[3] or 'status');
    local c=HC.modules.state.get_char(); local e=ensure(c);
    c.eeko_packets=type(c.eeko_packets)=='table' and c.eeko_packets or {signatures={}};
    c.eeko_packets.signatures=type(c.eeko_packets.signatures)=='table' and c.eeko_packets.signatures or {};
    if action=='learn' then
        if last_sig==nil then HC.msg('Speak with Eeko-Weeko first.'); return true; end
        c.eeko_packets.signatures[last_sig]={cycle=e.cycle,completed_this_week=e.completed_this_week,active=e.active};
        HC.modules.state.save(); last_known=true; HC.msg('Eeko packet signature learned.');
    elseif action=='forget' then
        c.eeko_packets.signatures={}; HC.modules.state.save(); last_known=false; HC.msg('Eeko signatures cleared.');
    else
        local n=0; for _ in pairs(c.eeko_packets.signatures) do n=n+1; end
        HC.msg('Eeko signatures learned: '..tostring(n));
    end
    return true;
end

return M;
