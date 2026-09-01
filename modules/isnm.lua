local M = {};
local HC;

local ENTRY_WINDOW_SECONDS = 15;
local RUN_STALE_SECONDS = 60 * 60;

local function ensure(c)
    c.isnm=type(c.isnm)=='table' and c.isnm or {};
    local s=c.isnm;
    s.order_held=s.order_held==true;
    s.last_isp=tonumber(s.last_isp);
    s.last_verified_at=tonumber(s.last_verified_at);
    s.order_break_at=tonumber(s.order_break_at);
    s.run_started_at=tonumber(s.run_started_at);
    s.last_clear_at=tonumber(s.last_clear_at);
    s.run_in_progress=s.run_in_progress==true;
    s.run_complete=s.run_complete==true;
    s.eligibility_denied=s.eligibility_denied==true;
    s.eligibility_denied_at=tonumber(s.eligibility_denied_at);
    return s;
end

local function source_is_shajaf(lower)
    lower=string.lower(tostring(lower or ''));
    return lower:find('shajaf',1,true)~=nil;
end

local function save()
    HC.modules.state.save();
end

local function u32le(raw,offset)
    if type(raw)~='string' then return nil; end
    offset=tonumber(offset) or 0;
    if #raw < offset+4 then return nil; end
    local b1,b2,b3,b4=raw:byte(offset+1,offset+4);
    if not b4 then return nil; end
    return b1 + b2*256 + b3*65536 + b4*16777216;
end

local function sync_isp(c,n,source)
    n=tonumber(n);
    if not n or n<0 or n>999999999 then return false; end
    n=math.floor(n);
    local st=ensure(c);
    local old=st.last_isp;
    st.last_isp=n;
    st.last_isp_at=os.time();
    st.last_isp_source=tostring(source or 'Currency data');

    -- Currency data proves only the current balance. Do not silently rewrite
    -- Shajaf eligibility/order evidence from the numeric ISP value alone.
    if old~=n then
        if HC.modules.state and HC.modules.state.request_save then HC.modules.state.request_save(1);
        else save(); end
    end
    return old~=n;
end

local function on_currency_packet(e)
    if e==nil or e.injected or tonumber(e.id)~=0x113 then return; end
    -- HorizonXI capture verified: Imperial Standing is a little-endian uint32
    -- at zero-based byte offset 0x7C in the full 252-byte Currency payload.
    -- Known sample: 19 05 00 00 => 1305 ISP, followed by 2610 Leujaoam AP.
    local raw=e.data or e.data_raw;
    if type(raw)~='string' or #raw<0x80 then raw=e.data_raw or e.data; end
    if type(raw)~='string' or #raw<0x80 then return; end
    local isp=u32le(raw,0x7C);
    if isp==nil then return; end
    sync_isp(HC.modules.state.get_char(),isp,'Currency data');
end

local function mark_order_held(c, source, order_name)
    local s=ensure(c);
    local changed=not s.order_held or tostring(s.order_name or '')~=tostring(order_name or '');

    s.order_held=true;
    s.order_name=order_name or 'Secret Imperial Order';
    s.state='ORDER HELD';
    s.confidence='VERIFIED BY SHAJAF / KEY ITEM';
    s.last_verified_at=os.time();
    s.last_source=source or 'Shajaf';
    s.order_break_at=nil;
    s.run_started_at=nil;
    s.run_in_progress=false;
    s.run_complete=false;
    s.battlefield=nil;
    s.clear_time_text=nil;
    s.eligibility_denied=false;
    s.eligibility_denied_at=nil;
    s.eligibility_denied_reason=nil;

    -- The Daily / Regular checkbox now represents a successfully cleared ISNM
    -- run. Merely obtaining/holding the order is status evidence, not a clear.
    c.daily=type(c.daily)=='table' and c.daily or {};
    c.daily.isnm=nil;

    save();

    if changed then
        HC.msg('AUTO: ISNM '..tostring(s.order_name)..' detected - ORDER HELD [VERIFIED].');
    end
end

local function mark_order_consumed(c)
    local s=ensure(c);
    local now=os.time();
    s.order_held=false;
    s.order_break_at=now;
    s.run_complete=false;
    s.state='ORDER CONSUMED';
    s.confidence='VERIFIED BY SECRET IMPERIAL ORDER BREAK';
    s.last_verified_at=now;
    s.last_source='Secret Imperial Order break';
    s.pending_order=nil;
    s.pending_order_at=nil;
    c.daily=type(c.daily)=='table' and c.daily or {};
    c.daily.isnm=nil;
    save();
end

local function mark_run_started(c, battlefield)
    local s=ensure(c);
    local now=os.time();
    if not s.order_break_at or (now-s.order_break_at)>ENTRY_WINDOW_SECONDS then return false; end

    local changed=not s.run_in_progress or tostring(s.battlefield or '')~=tostring(battlefield or '');
    s.run_in_progress=true;
    s.run_complete=false;
    s.run_started_at=now;
    s.battlefield=battlefield;
    s.state='RUN IN PROGRESS';
    s.confidence='VERIFIED BY ISNM BATTLEFIELD ENTRY';
    s.last_verified_at=now;
    s.last_source='Battlefield entry';
    c.daily=type(c.daily)=='table' and c.daily or {};
    c.daily.isnm=nil;
    save();

    if changed then
        HC.msg('AUTO: ISNM battlefield entry detected'..(battlefield and (' - '..battlefield) or '')..'. Waiting for a successful clear.');
    end
    return true;
end

local function mark_run_clear(c, clear_text)
    local s=ensure(c);
    local now=os.time();

    -- Battlefield-clear text is generic, so only accept it when this module has
    -- already verified an ISNM entry from the Secret Imperial Order break.
    if not s.run_in_progress or not s.run_started_at then return false; end
    if (now-s.run_started_at)>RUN_STALE_SECONDS then
        s.run_in_progress=false;
        s.state='RUN STATE EXPIRED';
        save();
        return false;
    end

    local changed=not s.run_complete;
    s.run_in_progress=false;
    s.run_complete=true;
    s.last_clear_at=now;
    s.clear_time_text=clear_text;
    s.state='CLEARED';
    s.confidence='VERIFIED BY BATTLEFIELD CLEAR TIME';
    s.last_verified_at=now;
    s.last_source='Battlefield clear time';
    s.order_break_at=nil;

    c.daily=type(c.daily)=='table' and c.daily or {};
    c.daily.isnm=true;
    save();

    if changed then
        HC.msg('AUTO: ISNM successful clear detected - Daily / Regular ISNM checked [VERIFIED].');
    end
    return true;
end

local function mark_eligibility_denied(c, reason)
    local s=ensure(c);
    local now=os.time();

    -- Capture verified 2026-08-22: Shajaf can explicitly reject the character
    -- after stating their Imperial Standing balance. This records only the
    -- observed rejection; it does not guess the server's ISP threshold.
    -- A verified Shajaf rejection proves there is no active Secret Imperial
    -- Order for this character. Clear any stale persisted ORDER HELD state
    -- before recording the rejection so status() cannot prefer the old order.
    s.order_held=false;
    s.order_name=nil;
    s.order_break_at=nil;
    s.run_started_at=nil;
    s.run_in_progress=false;
    s.run_complete=false;
    s.battlefield=nil;
    s.clear_time_text=nil;

    s.eligibility_denied=true;
    s.eligibility_denied_at=now;
    s.eligibility_denied_reason=reason or 'Shajaf rejected ISNM eligibility';
    s.state='NOT ELIGIBLE';
    s.confidence='VERIFIED BY SHAJAF REJECTION';
    s.last_verified_at=now;
    s.last_source='Shajaf eligibility dialogue';
    s.pending_order=nil;
    s.pending_order_at=nil;
    save();
end

local function on_text(s)
    local c=HC.modules.state.get_char();
    local st=ensure(c);
    local lower=string.lower(tostring(s or ''));

    -- Capture-verified exact key-item acquisition.
    if lower:find('obtained key item: secret imperial order',1,true) then
        mark_order_held(c,'Key item acquisition','Secret Imperial Order');
        return;
    end

    -- Capture verified 2026-08-22: ISNM entry consumes the order immediately
    -- before the battlefield-entry message.
    if lower:find('the secret imperial order breaks!',1,true) then
        mark_order_consumed(c);
        return;
    end

    -- Only pair generic battlefield-entry text with a recent verified order
    -- break, so other BCNM/ENM battlefields cannot trigger ISNM tracking.
    local battlefield=lower:match('entering the battlefield for%s+(.+)!');
    if battlefield then
        battlefield=battlefield:gsub('^%s+',''):gsub('%s+$','');
        mark_run_started(c,battlefield);
        return;
    end

    -- Capture verified 2026-08-22: successful completion emits this line.
    -- Duplicate log echoes are harmless because mark_run_clear is idempotent.
    local clear_time=lower:match('battlefield clear time:%s*(.-)!');
    if clear_time then
        mark_run_clear(c,clear_time);
        return;
    end

    if source_is_shajaf(lower) then
        -- Capture-verified "already on a job / order held" response.
        if lower:find('what are you doing, running off from a job? get back out there!',1,true) then
            mark_order_held(c,'Shajaf active-job dialogue','Secret Imperial Order');
            return;
        end

        -- Capture-verified order handoff dialogue. This is supportive evidence;
        -- the subsequent key-item message remains the strongest acquisition event.
        if lower:find("here, you'll need this secret imperial order",1,true) then
            st.pending_order='Secret Imperial Order';
            st.pending_order_at=os.time();
            st.last_source='Shajaf order handoff';
            save();
        end

        -- Capture verified 2026-08-22: after reporting the character's ISP,
        -- Shajaf explicitly rejects them with this line. Treat the dialogue
        -- itself as authoritative rejection evidence, without inferring a
        -- numeric requirement from the observed 1,705 ISP balance.
        if lower:find('pretend you never met me',1,true)
            or lower:find("meet again someday when you're ready",1,true) then
            mark_eligibility_denied(c,'Shajaf said to return when ready');
            return;
        end

        -- Capture-verified Imperial Standing balance spoken by Shajaf.
        -- Reaching this part of Shajaf's eligibility conversation is also
        -- negative possession evidence: when a Secret Imperial Order is
        -- already active, Shajaf uses the separate "get back out there"
        -- dialogue above instead of evaluating/reporting ISP. Therefore a
        -- fresh ISP read must clear any stale persisted ORDER HELD flag.
        local isp=lower:match('([%d,]+)%s+imperial standing credits');
        if isp then
            isp=tonumber((isp:gsub(',','')));
            if isp then
                st.order_held=false;
                st.order_name=nil;
                st.pending_order=nil;
                st.pending_order_at=nil;
                st.last_isp=math.floor(isp);
                st.last_isp_at=os.time();
                st.last_isp_source='Shajaf dialogue';
                st.last_source='Shajaf ISP dialogue';
                if not st.run_in_progress and not st.run_complete then
                    st.state='NO ORDER VERIFIED BY SHAJAF';
                    st.confidence='VERIFIED BY SHAJAF ISP CHECK';
                    st.last_verified_at=os.time();
                end
                save();
            end
        end
    end
end

function M.reconcile_order_ownership(owned, source, resource_id)
    local c=HC.modules.state.get_char();
    local s=ensure(c);
    local now=os.time();
    source=source or '0x055 key-item bitmap';

    if owned==true then
        -- Do not overwrite an active battlefield state; otherwise a current
        -- server ownership bitmap is authoritative proof that the order is held.
        if not s.run_in_progress then
            local changed=not s.order_held or s.order_name~='Secret Imperial Order' or s.last_source~=source;
            s.order_held=true;
            s.order_name='Secret Imperial Order';
            s.state='ORDER HELD';
            s.confidence='VERIFIED BY KEY ITEM BITMAP';
            s.last_verified_at=now;
            s.last_source=source;
            s.keyitem_resource_id=resource_id;
            s.order_break_at=nil;
            s.pending_order=nil;
            s.pending_order_at=nil;
            s.eligibility_denied=false;
            s.eligibility_denied_at=nil;
            s.eligibility_denied_reason=nil;
            c.daily=type(c.daily)=='table' and c.daily or {};
            c.daily.isnm=nil;
            save();
            if changed then HC.msg('AUTO: ISNM Secret Imperial Order confirmed held [0x055 KEY ITEM VERIFIED].'); end
            return changed;
        end
        return false;
    end

    if owned==false then
        -- A consumed order naturally disappears before battlefield entry. Keep
        -- that short-lived transition and any active/completed run intact.
        if s.run_in_progress or s.run_complete then return false; end
        if s.order_break_at and (now-s.order_break_at)<=ENTRY_WINDOW_SECONDS then return false; end

        local changed=s.order_held==true or s.pending_order~=nil or s.state=='ORDER HELD';
        s.order_held=false;
        s.order_name=nil;
        s.pending_order=nil;
        s.pending_order_at=nil;
        s.keyitem_resource_id=resource_id;
        s.last_verified_at=now;
        s.last_source=source;
        if not s.eligibility_denied then
            s.state='NO ORDER VERIFIED BY KEY ITEM';
            s.confidence='VERIFIED BY KEY ITEM BITMAP';
        end
        save();
        if changed then HC.msg('AUTO: Stale ISNM ORDER HELD cleared [0x055 KEY ITEM VERIFIED].'); end
        return changed;
    end
    return false;
end

function M.init(ctx)
    HC=ctx;
    HC.modules.packets.register_text('isnm shajaf/order/run',on_text);
    HC.modules.packets.register(0x113,'isnm_currency',on_currency_packet);
    if HC.request_currency then pcall(HC.request_currency); end
end

function M.status(c)
    if HC and HC.request_currency then pcall(HC.request_currency); end
    local s=ensure(c);
    local out;
    if s.run_complete then
        out='ISNM | CLEARED';
        if s.battlefield and s.battlefield~='' then out=out..' | '..tostring(s.battlefield); end
        if s.clear_time_text and s.clear_time_text~='' then out=out..' | '..tostring(s.clear_time_text); end
    elseif s.run_in_progress then
        out='ISNM | RUN IN PROGRESS';
        if s.battlefield and s.battlefield~='' then out=out..' | '..tostring(s.battlefield); end
    elseif s.order_held then
        out=tostring(s.order_name or 'Secret Imperial Order')..' | ORDER HELD';
    elseif s.eligibility_denied then
        out='ISNM | NOT ELIGIBLE [VERIFIED BY SHAJAF]';
    elseif s.order_break_at then
        out='Secret Imperial Order | CONSUMED / ENTRY PENDING';
    elseif s.pending_order then
        out=tostring(s.pending_order)..' | HANDOFF SEEN';
    elseif s.state=='NO ORDER VERIFIED BY SHAJAF' then
        out='ISNM | NO ORDER [VERIFIED BY SHAJAF]';
    elseif s.state=='NO ORDER VERIFIED BY KEY ITEM' then
        out='ISNM | NO ORDER [KEY ITEM VERIFIED]';
    else
        out='ISNM | NO VERIFIED ORDER';
    end
    if s.last_isp then out=out..' | ISP: '..tostring(s.last_isp); end
    return out;
end

function M.clear(c)
    local s=ensure(c);
    s.order_held=false;
    s.order_name=nil;
    s.state=nil;
    s.confidence=nil;
    s.pending_order=nil;
    s.pending_order_at=nil;
    s.order_break_at=nil;
    s.run_started_at=nil;
    s.run_in_progress=false;
    s.run_complete=false;
    s.battlefield=nil;
    s.last_clear_at=nil;
    s.clear_time_text=nil;
    s.eligibility_denied=false;
    s.eligibility_denied_at=nil;
    s.eligibility_denied_reason=nil;
    c.daily=type(c.daily)=='table' and c.daily or {};
    c.daily.isnm=nil;
    save();
end

return M;
