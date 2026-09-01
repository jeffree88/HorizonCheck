local M = {};
local HC;
local QUEST_LOG_ID = 4; -- Other Areas
local QUEST_ID = 73;    -- Secrets of Ovens Lost
local postcheck = { children_at=0, trouble_at=0 };

local function ensure(c)
    c.ovens_lost=type(c.ovens_lost)=='table' and c.ovens_lost or {};
    local a=c.ovens_lost;
    local wk=HC.modules.core.weekly_key();
    if a.weekly_key~=wk then
        -- HorizonXI can keep/resend the native ACTIVE bit for Secrets of Ovens
        -- Lost even after a successful turn-in.  When a new weekly cycle begins,
        -- remember whether the prior cycle was authoritatively complete before
        -- clearing that cycle's evidence.  A zone-in 0x056 ACTIVE immediately
        -- after reset must not masquerade as a brand-new weekly acceptance.
        local prior_key=a.weekly_key;
        local prior_complete=(a.state=='COMPLETE' or (tonumber(a.reward_at)~=nil and a.reward~=nil));
        a.weekly_key=wk;
        a.state='READY';
        a.accepted_at=nil;
        a.cookbook_at=nil;
        a.cookbook_owned=nil;
        a.turnin_at=nil;
        a.completed_at=nil;
        a.reward=nil;
        a.reward_at=nil;
        a.native_quest_active=nil;
        a.native_active_reset_guard=(prior_key~=nil and prior_complete==true) and true or nil;
        a.native_active_reset_guard_from=prior_complete and prior_key or nil;
        a.native_active_reset_guard_at=prior_complete and os.time() or nil;
    end
    -- v6.86.2: recover a same-week completion if an older build regressed
    -- COMPLETE back to IN PROGRESS after zoning.  reward_at is only written
    -- after the verified cookbook turn-in + actual Miratete reward, and it is
    -- cleared whenever weekly_key rolls over, so it is safe current-cycle
    -- completion evidence.
    if a.state~='COMPLETE' and tonumber(a.reward_at)~=nil and a.reward~=nil then
        a.state='COMPLETE';
        a.completed_at=a.completed_at or a.reward_at;
        a.last_reason='restored from current-week Miratete reward evidence';
        c.dragon_weekly=type(c.dragon_weekly)=='table' and c.dragon_weekly or {};
        c.dragon_weekly.mm_cookbook=true;
    end
    return a;
end

local function set_state(c,state,why)
    local a=ensure(c);
    if a.state==state then return false; end
    a.state=state;
    a.last_reason=why;
    a.last_change=os.time();
    HC.modules.state.save();
    HC.msg('AUTO: Secrets of Ovens Lost - '..state..(why and (' ['..why..']') or ''));
    return true;
end

local function complete(c,why)
    local a=ensure(c);
    if a.state=='COMPLETE' then return false; end
    a.state='COMPLETE';
    a.completed_at=os.time();
    a.last_reason=why or 'verified cookbook turn-in';

    c.dragon_weekly=type(c.dragon_weekly)=='table' and c.dragon_weekly or {};
    c.dragon_weekly.mm_cookbook=true;

    HC.modules.state.save();
    HC.msg("AUTO: Secrets of Ovens Lost complete ["..tostring(a.last_reason).."].");
    return true;
end

local function cookbook_evidence(a)
    return a.cookbook_owned==true or tonumber(a.cookbook_at)~=nil;
end

-- Called from the authoritative 0x055 key-item bitmap when available.
function M.reconcile_keyitem_ownership(owned,source,id,label)
    local c=HC.modules.state.get_char();
    local a=ensure(c);
    local now=os.time();
    local was=a.cookbook_owned;
    a.cookbook_owned=owned==true;
    a.cookbook_ki_source=source;
    a.cookbook_ki_id=id;
    a.cookbook_ki_verified_at=now;

    if owned==true then
        -- Holding the current Tavnazian Cookbook is stronger evidence than the
        -- post-reset stale-ACTIVE guard, so a real new-week run may advance.
        a.native_active_reset_guard=nil;
        a.cookbook_at=a.cookbook_at or now;
        if a.state~='COMPLETE' then set_state(c,'COOKBOOK OBTAINED','Tavnazian Cookbook KI verified'); end
    elseif was==true then
        -- Losing the KI alone is NOT completion evidence.  The quest must also
        -- leave the authoritative 0x056 ACTIVE bitmap after a verified turn-in,
        -- or the actual Miratete reward must be observed.
        HC.modules.state.save();
    else
        HC.modules.state.save();
    end
end

local function on_quest_update(log_id,previous,current)
    if tonumber(log_id)~=QUEST_LOG_ID or not HC.modules.quests then return; end
    local c=HC.modules.state.get_char();
    local a=ensure(c);
    local active=HC.modules.quests.is_active(QUEST_LOG_ID,QUEST_ID);
    if active==nil then return; end
    local was=a.native_quest_active;
    a.native_quest_active=active;
    a.native_quest_verified_at=os.time();

    if active then
        -- For this HorizonXI weekly, the 0x056 ACTIVE bit can still be present
        -- after a successful turn-in and can be resent during zoning.  A
        -- current-week COMPLETE backed by the verified Miratete reward/turn-in
        -- must therefore outrank that stale ACTIVE bit until weekly_key rolls.
        if a.state=='COMPLETE' then
            a.native_active_after_complete_at=os.time();
            a.native_quest_conflict='0x056 ACTIVE observed after current-week COMPLETE';
            c.dragon_weekly=type(c.dragon_weekly)=='table' and c.dragon_weekly or {};
            c.dragon_weekly.mm_cookbook=true;
            HC.modules.state.save();
            return;
        elseif a.state=='READY' then
            if a.native_active_reset_guard==true then
                -- Prior week was complete and HorizonXI resent the stale ACTIVE
                -- bit on zone-in after reset.  Keep the new cycle READY until
                -- fresh Jonette dialogue or current-week Cookbook ownership is
                -- observed.  This is diagnostic evidence only and intentionally
                -- does not produce an AUTO chat message.
                a.native_active_ignored_after_reset_at=os.time();
                a.native_quest_conflict='stale 0x056 ACTIVE ignored after weekly reset';
                HC.modules.state.save();
                return;
            end
            a.accepted_at=a.accepted_at or os.time();
            if a.cookbook_owned==true then
                set_state(c,'COOKBOOK OBTAINED','0x056 confirms quest ACTIVE + cookbook held');
            else
                set_state(c,'IN PROGRESS','0x056 confirms quest ACTIVE');
            end
        else
            HC.modules.state.save();
        end
        return;
    end

    -- Completion from native quest state requires a real prior ACTIVE state,
    -- verified cookbook evidence, and recent turn-in context.  Merely talking
    -- to Jonette twice cannot satisfy these conditions.
    local now=os.time();
    if was==true and cookbook_evidence(a) and tonumber(a.turnin_at)
        and now-tonumber(a.turnin_at)<=180
    then
        complete(c,'0x056 ACTIVE->INACTIVE after verified Tavnazian Cookbook turn-in');
    else
        HC.modules.state.save();
    end
end

local function on_text(s)
    local c=HC.modules.state.get_char();
    local a=ensure(c);
    local lower=string.lower(tostring(s or ''));
    local now=os.time();

    -- Old Jonette post-completion dialogue is retained only as historical
    -- evidence.  It can no longer complete the weekly quest by itself.
    if lower:find('i feel sorry for the children all cooped up here in the safehold',1,true) then
        postcheck.children_at=now;
    end
    if lower:find('there are three troublemakers who have taken it upon themselves to ignore this rule',1,true) then
        postcheck.trouble_at=now;
    end
    if tonumber(postcheck.children_at)>0 and tonumber(postcheck.trouble_at)>0
        and math.abs(tonumber(postcheck.children_at)-tonumber(postcheck.trouble_at))<=10
    then
        a.postcheck_seen_at=now;
        postcheck.children_at=0;
        postcheck.trouble_at=0;
        -- This paired Jonette sequence is useful as immediate request/acceptance
        -- evidence, but it is never completion evidence.  Only advance a fresh
        -- weekly READY state; stronger cookbook/turn-in/complete states win.
        if a.state=='READY' then
            a.native_active_reset_guard=nil;
            a.accepted_at=now;
            set_state(c,'IN PROGRESS','Jonette request dialogue');
        else
            HC.modules.state.save();
        end
    end

    -- Weekly request / active quest dialogue.
    if lower:find('the information you have brought me on tavnazian cuisine has been a wonderful help!',1,true)
        or lower:find('if you happen to find any more, the children would be so delighted.',1,true)
    then
        if a.state~='COMPLETE' then
            a.native_active_reset_guard=nil;
            a.accepted_at=now;
            set_state(c,'IN PROGRESS','Jonette request dialogue');
        end
        return;
    end

    -- Explicit key-item acquisition remains strong evidence even before the
    -- next 0x055 bitmap refresh.
    if lower:find('obtained key item:',1,true)
        and lower:find('tavnazian cookbook',1,true)
    then
        a.cookbook_at=now;
        a.cookbook_owned=true;
        set_state(c,'COOKBOOK OBTAINED','Tavnazian Cookbook key item obtained');
        return;
    end

    -- Turn-in recognition is accepted only after cookbook ownership/acquisition
    -- has been verified.  Generic Jonette dialogue cannot create turn-in state.
    if lower:find('a tavnazian cookbook',1,true)
        and lower:find('exactly the information i have been searching for',1,true)
    then
        if cookbook_evidence(a) then
            a.turnin_at=now;
            set_state(c,'TURNING IN','Jonette recognized verified Tavnazian Cookbook');
        end
        return;
    end

    if lower:find('please accept this as a token of my appreciation',1,true) then
        if cookbook_evidence(a) then
            a.turnin_at=now;
            if a.state~='COMPLETE' then set_state(c,'TURNING IN','Jonette appreciation dialogue after verified cookbook'); end
        end
        return;
    end

    -- Repeatable completion fallback: actual Miratete reward in recent verified
    -- cookbook turn-in context.  This works even if the next 0x056 refresh is
    -- delayed until zoning.
    if lower:find('obtained:',1,true)
        and lower:find("miratete's memoirs",1,true)
        and cookbook_evidence(a)
        and tonumber(a.turnin_at)
        and now-tonumber(a.turnin_at)<=45
    then
        a.reward="Page from Miratete's Memoirs";
        a.reward_at=now;
        a.cookbook_owned=false;
        complete(c,'verified cookbook turn-in + Miratete reward');
        return;
    end

    -- One-time achievement remains evidence only.
    if lower:find("achievement unlocked: complete 'secrets of ovens lost'",1,true) then
        a.achievement_seen_at=now;
        HC.modules.state.save();
        return;
    end
end

function M.status(c)
    local a=ensure(c);
    local state=a.state or 'READY';
    if state=='READY' then return 'READY | Jonette -> obtain Tavnazian Cookbook'; end
    if state=='IN PROGRESS' then return 'IN PROGRESS | Obtain Tavnazian Cookbook'; end
    if state=='COOKBOOK OBTAINED' then return 'COOKBOOK OBTAINED | Return to Jonette'; end
    if state=='TURNING IN' then return 'TURNING IN | Awaiting quest completion / Miratete reward'; end
    if state=='COMPLETE' then return "COMPLETE | Reward: "..tostring(a.reward or "Miratete's Memoirs"); end
    return tostring(state);
end

function M.row_status(c)
    local a=ensure(c);
    local state=a.state or 'READY';
    if state=='READY' then
        return "READY | Jonette (G-9) | Talk to Jonette";
    elseif state=='IN PROGRESS' then
        return "IN PROGRESS | Obtain Tavnazian Cookbook";
    elseif state=='COOKBOOK OBTAINED' then
        return "COOKBOOK OBTAINED | Return to Jonette";
    elseif state=='TURNING IN' then
        return "TURNING IN | Finish Jonette dialogue";
    elseif state=='COMPLETE' then
        return "COMPLETE | Reward: "..tostring(a.reward or "Miratete's Memoirs");
    end
    return tostring(state);
end

function M.draw(c)
    if not HC.imgui then return; end
    local imgui=HC.imgui;
    imgui.Text('Secrets of Ovens Lost');
    imgui.SameLine();
    imgui.TextDisabled('['..M.row_status(c)..']');
end

function M.init(ctx)
    HC=ctx;
    HC.modules.packets.register_text('ovens lost',on_text);
    if HC.modules.quests and HC.modules.quests.register_update then
        HC.modules.quests.register_update(on_quest_update);
    end
end

return M;
