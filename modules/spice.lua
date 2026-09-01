local M = {};
local HC;
local postcheck={ concern_at=0, convergence_at=0 };

local function ensure(c)
    c.spice_gals=type(c.spice_gals)=='table' and c.spice_gals or {};
    local a=c.spice_gals;
    local wk=HC.modules.core.weekly_key();
    if a.weekly_key~=wk then
        a.weekly_key=wk;
        a.state='READY';
        a.accepted_at=nil;
        a.postcheck_verified_at=nil;
        a.last_reason=nil;
    end
    if not a.state then a.state='READY'; end
    return a;
end

local function set_state(c,state,why)
    local a=ensure(c);
    if a.state==state then return false; end
    a.state=state;
    a.last_reason=why;
    a.last_change=os.time();
    HC.modules.state.save();
    HC.msg('AUTO: Spice Gals - '..state..(why and (' ['..why..']') or ''));
    return true;
end

local function on_text(s)
    local c=HC.modules.state.get_char();
    local a=ensure(c);
    local lower=string.lower(tostring(s or ''));

    -- Capture-verified post-pickup Rouva dialogue.
    -- After Spice Gals has been started for the week, Rouva falls back to a
    -- generic two-line sequence. Require both lines close together before
    -- reconciling IN PROGRESS after reload/login.
    if lower:find("my lady is concerned about san d'oria's future",1,true)
        and lower:find("worried how much we are bound to ceremony",1,true)
    then
        postcheck.concern_at=os.time();
    end

    if lower:find('the convergence of old and new has always been part of who we are',1,true) then
        postcheck.convergence_at=os.time();
    end

    if tonumber(postcheck.concern_at)>0 and tonumber(postcheck.convergence_at)>0
        and math.abs(tonumber(postcheck.concern_at)-tonumber(postcheck.convergence_at))<=10
    then
        if a.state~='COMPLETE' then
            a.state='IN PROGRESS';
            a.accepted_at=a.accepted_at or os.time();
            a.postcheck_verified_at=os.time();
            a.last_reason='Rouva post-pickup dialogue sequence';
            HC.modules.state.save();
            HC.msg('AUTO: Spice Gals - IN PROGRESS [VERIFIED BY ROUVA POST-PICKUP DIALOGUE].');
        end
        postcheck.concern_at=0;
        postcheck.convergence_at=0;
        return;
    end

    -- Capture-verified Rouva repeatable Rivernewort request dialogue.
    if lower:find('rouva',1,true) and (
        lower:find('collect another sprig of rivernewort',1,true)
        or (
            lower:find('sprig of rivernewort',1,true)
            and lower:find('authentic tavnazian dishes once again',1,true)
        )
    ) then
        if a.state~='COMPLETE' then
            a.accepted_at=os.time();
            set_state(c,'IN PROGRESS','Rouva Rivernewort request dialogue');
        end
        return;
    end

    if lower:find('obtained key item:',1,true) and lower:find('rivernewort',1,true) then
        a.rivernewort_owned=true;
        a.rivernewort_verified_at=os.time();
        a.rivernewort_source='Obtained key item text';
        if a.state~='COMPLETE' then a.state='KEY ITEM READY'; end
        a.last_reason='Rivernewort obtained';
        HC.modules.state.save();
        HC.msg('AUTO: Spice Gals - RIVERNEWORT OBTAINED [KEY ITEM READY].');
        return;
    end

    -- Existing automation may already have seen a verified Miratete reward.
    if c.dragon_weekly and c.dragon_weekly.mm_rivenwort==true then
        a.state='COMPLETE';
        a.completed_at=a.completed_at or os.time();
        a.last_reason='Existing verified Spice Gals reward state';
        HC.modules.state.save();
    end
end


function M.reconcile_keyitem_ownership(owned,source,id,label)
    local c=HC.modules.state.get_char();
    local a=ensure(c);
    local changed=(a.rivernewort_owned~=owned);
    a.rivernewort_owned=owned;
    a.rivernewort_verified_at=os.time();
    a.rivernewort_source=source;
    a.rivernewort_resource_id=id;
    if owned==true and a.state~='COMPLETE' then
        a.state='KEY ITEM READY';
        a.accepted_at=a.accepted_at or os.time();
        a.last_reason='Rivernewort ownership verified by '..tostring(source or 'key-item state');
        changed=true;
    elseif owned==false and a.state=='KEY ITEM READY' then
        -- Losing Rivernewort alone is not proof of completion. Fall back to
        -- in-progress unless the verified weekly reward already completed it.
        if c.dragon_weekly and c.dragon_weekly.mm_rivenwort==true then
            a.state='COMPLETE';
        else
            a.state='IN PROGRESS';
            a.last_reason='Rivernewort no longer held; completion not inferred';
        end
        changed=true;
    end
    if changed then HC.modules.state.save(); end
    return a;
end

function M.reconcile(c)
    local a=ensure(c);
    if c.dragon_weekly and c.dragon_weekly.mm_rivenwort==true and a.state~='COMPLETE' then
        a.state='COMPLETE';
        a.completed_at=os.time();
        a.last_reason='Verified reward state';
        HC.modules.state.save();
    end
    return a;
end

function M.row_status(c)
    local a=M.reconcile(c);
    if a.state=='COMPLETE' then
        return "COMPLETE | Reward: Miratete's Memoirs";
    elseif a.state=='KEY ITEM READY' or a.rivernewort_owned==true then
        return 'RIVERNEWORT OBTAINED | KI VERIFIED | Return to Rouva';
    elseif a.state=='IN PROGRESS' then
        if a.postcheck_verified_at then
            return 'IN PROGRESS | VERIFIED BY ROUVA | Obtain Rivernewort';
        end
        return 'IN PROGRESS | Obtain Rivernewort';
    end
    return 'READY | Talk to Rouva (L-6)';
end

function M.init(ctx)
    HC=ctx;
    HC.modules.packets.register_text('spice gals',on_text);
end

return M;
