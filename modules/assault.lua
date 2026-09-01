local M = {};
local HC;
local INTERVAL = 24 * 60 * 60;
local RYTAAL_WINDOW = 5;
local last_rytaal_text_at = 0;
local last_packet_seen_at = 0;

local function ensure(c)
    c.assault_tags = type(c.assault_tags) == 'table' and c.assault_tags or {};
    local char = c.assault_tags;

    local account = HC.modules.state.get_account and HC.modules.state.get_account() or {};
    account.assault_tags = type(account.assault_tags) == 'table' and account.assault_tags or {};
    local shared = account.assault_tags;

    -- v6.1.33 migration: seed the shared pool from ANY saved character that
    -- has known Assault Tag data. Never let an empty character permanently
    -- mark migration complete.
    if shared.count==nil and HC.modules.state.migrate_account_assault_tags then
        HC.modules.state.migrate_account_assault_tags();
        account=HC.modules.state.get_account();
        account.assault_tags=type(account.assault_tags)=='table' and account.assault_tags or {};
        shared=account.assault_tags;
    end

    -- If this currently-loaded character has known data and the shared pool is
    -- still empty, use it immediately and persist it.
    if shared.count==nil and char.count~=nil then
        local fields={
            'count','cap','next_at','timer_estimated','last_regen_at',
            'packet_auto','packet','last_rytaal_reconcile_at',
            'last_rytaal_reconcile_reason','last_rytaal_reconcile_count',
            'last_rytaal_menu_left','last_rytaal_authoritative_at',
            'last_rytaal_reconcile_debug','rytaal_legacy_reconcile_done',
            'rytaal_legacy_reconcile_at','legacy_regen_repairs'
        };
        for _,k in ipairs(fields) do if char[k]~=nil then shared[k]=char[k]; end end
        shared.migrated=true;
        shared.migrated_at=os.time();
        HC.modules.state.save();
    end

    shared.cap=tonumber(shared.cap) or 4;
    if shared.packet_auto==nil then shared.packet_auto=true; end
    shared.packet=type(shared.packet)=='table' and shared.packet or {};

    if char.carried~=nil then char.carried=(tonumber(char.carried) or 0)>0 and 1 or 0; end

    -- v6.4.02 migration: older builds accidentally stored carried-tag pickup
    -- timestamps in the shared account pool. If this character is currently
    -- marked as carrying a tag, recover that evidence into character scope.
    if tonumber(char.carried)==1 and char.last_tag_pickup_at==nil and shared.last_tag_pickup_at~=nil then
        char.last_tag_pickup_at=shared.last_tag_pickup_at;
        char.last_tag_pickup_protect_until=shared.last_tag_pickup_protect_until;
        char.last_tag_pickup_reason=shared.last_tag_pickup_reason;
        char.last_tag_pickup_verified=shared.last_tag_pickup_verified;
        char.last_tag_transfer_from=shared.last_tag_transfer_from;
        char.last_tag_transfer_to=shared.last_tag_transfer_to;
        HC.modules.state.save();
    end

    -- Proxy routes account-pool fields to shared storage while keeping all
    -- carried-tag ownership evidence character-specific.
    local character_fields={
        carried=true,
        carried_estimated=true,
        last_tag_pickup_at=true,
        last_tag_pickup_protect_until=true,
        last_tag_pickup_reason=true,
        last_tag_pickup_verified=true,
        last_tag_transfer_from=true,
        last_tag_transfer_to=true,
        last_tag_used_at=true,
        last_tag_used_reason=true,
        last_carried_reconcile_at=true,
        last_carried_reconcile_reason=true,
        carried_source=true,
        carried_confidence=true,
        carried_verified_at=true,
    };

    local proxy={};
    setmetatable(proxy,{
        __index=function(_,k)
            if character_fields[k] then return char[k]; end
            return shared[k];
        end,
        __newindex=function(_,k,v)
            if character_fields[k] then char[k]=v; else shared[k]=v; end
        end
    });
    return proxy;
end

local function target_name()
    local name = nil;
    pcall(function()
        local mm = AshitaCore:GetMemoryManager();
        local t = mm:GetTarget();
        local ent = mm:GetEntity();
        local idx = nil;
        if t ~= nil then
            pcall(function() idx = t:GetTargetIndex(0); end);
            if idx == nil or tonumber(idx) == 0 then pcall(function() idx = t:GetTargetIndex(); end); end
        end
        idx = tonumber(idx);
        if ent ~= nil and idx ~= nil and idx > 0 then name = ent:GetName(idx); end
    end);
    return tostring(name or '');
end

local function b0(data, offset)
    if type(data) ~= 'string' then return nil; end
    local pos = tonumber(offset);
    if pos == nil then return nil; end
    return string.byte(data, pos + 1);
end

local function looks_like_rytaal_menu(e)
    if e == nil or e.injected or tonumber(e.id) ~= 0x034 then return false; end
    local data = e.data;
    local size = tonumber(e.size) or (type(data) == 'string' and #data or 0);
    if size ~= 52 or type(data) ~= 'string' then return false; end

    -- Stable bytes observed in the HorizonXI Rytaal 0x034 menu packets captured
    -- at known tag totals 4 and 3. Sequence bytes at 0x02-0x03 are intentionally ignored.
    local sig = {
        [0x04]=0x9B, [0x05]=0x20, [0x06]=0x03, [0x07]=0x01,
        [0x08]=0x02, [0x09]=0x00, [0x0A]=0x00, [0x0B]=0x00,
        [0x28]=0x9B, [0x29]=0x00, [0x2A]=0x32, [0x2B]=0x00,
        [0x2C]=0x0C, [0x2D]=0x01, [0x2E]=0x08, [0x2F]=0x00,
    };
    for off,val in pairs(sig) do if b0(data,off) ~= val then return false; end end

    local tn = string.lower(target_name());
    local recent_text = (os.time() - (last_rytaal_text_at or 0)) <= RYTAAL_WINDOW;
    return tn == 'rytaal' or recent_text;
end

local function normalize(c)
    local t = ensure(c);
    if t.count == nil then return false; end
    local now = os.time();
    local changed=false;
    local generated=0;

    if t.count >= t.cap then
        if t.count ~= t.cap then t.count=t.cap; changed=true; end
        if t.next_at ~= nil then t.next_at=nil; changed=true; end
        if changed then HC.modules.state.save(); end
        return changed;
    end

    if type(t.next_at) ~= 'number' then
        t.next_at = now + INTERVAL;
        t.timer_estimated = true;
        changed=true;
    end

    -- Assault tags regenerate every 24 Earth hours while Rytaal is below his
    -- stored-tag cap. The timer is locally projected from the last observation,
    -- so advance the displayed estimate when it expires instead of freezing at
    -- VERIFY. A later direct Rytaal menu remains authoritative and reconciles
    -- the estimate if the projection was wrong.
    if t.count < t.cap and type(t.next_at)=='number' and now >= t.next_at then
        while t.count < t.cap and type(t.next_at)=='number' and now >= t.next_at do
            local carried=(tonumber(t.carried) or 0)>0 and 1 or 0;
            local stored=tonumber(t.last_rytaal_menu_left);
            if stored==nil then stored=math.max(0,(tonumber(t.count) or 0)-carried); end
            if stored>=3 then
                t.next_at=nil;
                break;
            end

            t.count=math.min(t.cap,(tonumber(t.count) or 0)+1);
            t.last_rytaal_menu_left=math.min(3,stored+1);
            generated=generated+1;
            t.last_regen_at=t.next_at;
            t.regen_pending=nil;
            t.regen_pending_at=nil;
            t.timer_estimated=true;

            if t.last_rytaal_menu_left>=3 or t.count>=t.cap then
                t.next_at=nil;
            else
                t.next_at=t.next_at+INTERVAL;
            end
            changed=true;
        end
    end

    if changed then
        HC.modules.state.save();
    end

    if generated > 0 and HC.msg then
        local carried=(tonumber(t.carried) or 0)>0 and 1 or 0;
        local rytaal=math.max(0,(tonumber(t.count) or 0)-carried);
        local rytaal_cap=math.max(0,(tonumber(t.cap) or 4)-carried);
        HC.msg(string.format('Assault Tag regenerated: Rytaal now holding %d/%d | Total %d/%d.',
            rytaal,rytaal_cap,t.count,t.cap));
    end

    return changed;
end

local function assault_consumes_current_tag(c,t)
    -- Saved/current assault_activity is not authoritative for ownership of a
    -- newly-picked-up Imperial Army I.D. Tag. It can refresh long after the
    -- Assault it describes. Only M.auto_used() may consume Character 1 -> 0,
    -- using direct signup / Assault Orders evidence.
    return false;
end


local EVIDENCE_RANK={
    UNKNOWN=0,
    ESTIMATED=10,
    MANUAL=20,
    INFERRED=30,
    PACKET=40,
    KEYITEM=50,
    DIALOGUE=60,
    ORDERS=70,
    BITMAP=80,
};

local function evidence_rank(name)
    return EVIDENCE_RANK[tostring(name or 'UNKNOWN')] or 0;
end

local function current_evidence_rank(t)
    return tonumber(t.carried_evidence_rank) or evidence_rank(t.carried_evidence_type);
end

local function set_carried_evidence(c,value,evidence_type,source)
    c.assault_tags=type(c.assault_tags)=='table' and c.assault_tags or {};
    local t=ensure(c);
    local incoming=evidence_rank(evidence_type);
    local current=current_evidence_rank(t);

    -- Weaker evidence must never overwrite stronger ownership evidence.
    if incoming<current then
        if HC.modules.state and HC.modules.state.audit then
            HC.modules.state.audit(c,'assault',
                'Ignored weaker carried-tag evidence: '..tostring(source or evidence_type),
                tostring(evidence_type),'evidence hierarchy');
        end
        return false;
    end

    local old=(tonumber(t.carried) or 0)>0 and 1 or 0;
    t.carried=value and 1 or 0;
    t.carried_estimated=(evidence_type=='ESTIMATED') and true or nil;
    t.carried_evidence_type=evidence_type;
    t.carried_evidence_rank=incoming;
    t.carried_source=source or evidence_type;
    t.carried_confidence=(incoming>=50 and 'VERIFIED')
        or (evidence_type=='MANUAL' and 'MANUAL')
        or (evidence_type=='ESTIMATED' and 'ESTIMATED')
        or (evidence_type=='INFERRED' and 'INFERRED')
        or 'UNKNOWN';
    t.carried_verified_at=os.time();

    if HC.modules.state and HC.modules.state.audit and old~=t.carried then
        HC.modules.state.audit(c,'assault',
            string.format('Character tag %d -> %d',old,t.carried),
            t.carried_confidence,t.carried_source);
    end
    return true;
end

local function split_counts(c)
    local t=ensure(c);

    -- Rytaal's directly observed stored count is account-wide.
    local rytaal=tonumber(t.last_rytaal_menu_left);
    if rytaal~=nil then rytaal=math.max(0,math.min(3,math.floor(rytaal))); end

    -- Carried ownership is strictly per-character. Never infer 1 merely
    -- because tags exist in the shared Rytaal pool.
    if t.carried==nil then
        return nil,rytaal,true;
    end

    local carried=math.max(0,math.min(1,tonumber(t.carried) or 0));

    -- Ownership invariant: Total = Character + Rytaal.
    -- A verified stored count lower than the preserved total proves the
    -- difference is on this character. This repairs missed pickup text/packets.
    if rytaal~=nil and t.count~=nil then
        local total=math.max(0,math.min(4,tonumber(t.count) or 0));
        local inferred=math.max(0,math.min(1,total-rytaal));
        if inferred>carried then
            local accepted=set_carried_evidence(c,inferred==1,'INFERRED',
                'Total minus authoritative Rytaal stored count');
            if accepted then
                carried=inferred;
                t.last_tag_pickup_at=t.last_tag_pickup_at or os.time();
                t.last_tag_pickup_reason=t.last_tag_pickup_reason or
                    'RECONCILED from total minus authoritative Rytaal stored count';
                t.last_tag_pickup_verified=true;
                HC.modules.state.save();
            end
        end
    end

    if rytaal==nil and t.count~=nil then
        rytaal=math.max(0,math.min(3,(tonumber(t.count) or 0)-carried));
    end
    return carried,rytaal,false;
end

function M.split_status(c)
    local carried,rytaal,estimated=split_counts(c);
    if carried==nil then return 'On Character: ? | Rytaal (Account): ?'; end
    return string.format('On Character: %d | Rytaal (Account): %d%s',
        carried, rytaal, estimated and ' | estimated' or '');
end

function M.carried_evidence(c)
    local t=ensure(c);
    local conf=t.carried_confidence;
    if not conf then conf=(t.carried_estimated==true) and 'ESTIMATED' or 'UNKNOWN'; end
    return {
        confidence=conf,
        source=t.carried_source,
        verified_at=t.carried_verified_at,
        evidence_type=t.carried_evidence_type or 'UNKNOWN',
        evidence_rank=current_evidence_rank(t),
    };
end

function M.rytaal_status(c)
    normalize(c);
    local t=ensure(c);
    local carried,rytaal,estimated=split_counts(c);
    local next_remaining=nil;
    local stored=tonumber(rytaal);
    if stored~=nil and stored<3 and type(t.next_at)=='number' and t.regen_pending~=true then
        local remain=t.next_at-os.time();
        if remain>0 then next_remaining=remain; end
    end

    if carried==nil then
        return {
            carried=nil,
            rytaal=stored,
            total=nil,
            cap=4,
            rytaal_cap=3,
            next_remaining=next_remaining,
            regen_pending=t.regen_pending==true,
            timer_state=(t.regen_pending==true) and 'VERIFY' or
                ((next_remaining~=nil) and 'COUNTING DOWN' or 'UNKNOWN'),
            capped=false,
            estimated=true,
            carried_confidence=M.carried_evidence(c).confidence,
            carried_source=M.carried_evidence(c).source,
        };
    end

    local total=(stored~=nil) and (stored+carried) or nil;
    return {
        carried=carried,
        rytaal=stored,
        total=total,
        cap=4,
        rytaal_cap=3,
        next_remaining=next_remaining,
        regen_pending=t.regen_pending==true,
        timer_state=(stored~=nil and stored>=3) and 'CAPPED' or
            ((t.regen_pending==true) and 'VERIFY' or
            ((next_remaining~=nil) and 'COUNTING DOWN' or 'UNKNOWN')),
        capped=(stored~=nil and stored>=3 and carried>=1),
        estimated=estimated,
        carried_confidence=M.carried_evidence(c).confidence,
        carried_source=M.carried_evidence(c).source,
    };
end


function M.sync_status(c)
    c=c or (HC and HC.modules and HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    normalize(c);
    local t=ensure(c);
    local rs=M.rytaal_status(c);
    local direct=(tonumber(t.last_rytaal_menu_left)~=nil);
    local initialized=direct and rs.rytaal~=nil and rs.total~=nil;
    return {
        initialized=initialized,
        rytaal=rs.rytaal,total=rs.total,carried=rs.carried,
        at=tonumber(t.last_rytaal_authoritative_at) or tonumber(t.last_rytaal_reconcile_at),
        source=t.last_rytaal_reconcile_reason,
    };
end

function M.status(c)
    local rs=M.rytaal_status(c);
    local ry=(rs.rytaal~=nil) and tostring(rs.rytaal) or '?';

    if rs.carried==nil then
        local tail='';
        if rs.regen_pending then
            tail=' | Regen due - verify with Rytaal';
        elseif rs.next_remaining then
            tail=' | Next Rytaal: '..HC.modules.core.format_duration(rs.next_remaining);
        end
        return string.format('Character ? | Rytaal %s/3 | Total ?/4%s',ry,tail);
    end

    local total=rs.total~=nil and tostring(rs.total) or '?';
    if rs.capped then
        return string.format('%s/4 tags | Character %d | Rytaal %s/3 CAPPED',
            total,rs.carried,ry);
    end
    local nexttxt=rs.next_remaining and HC.modules.core.format_duration(rs.next_remaining) or 'CAPPED';
    return string.format('%s/4 tags | Character %d | Rytaal %s/3 | Next Rytaal: %s',
        total,rs.carried,ry,nexttxt);
end

function M.packet_status(c)
    local t=ensure(c); local p=t.packet or {};
    if t.packet_auto==false then return 'RYTAAL PACKET LEARNING OFF'; end
    if not p.last_seen_at then return 'RYTAAL PACKET LEARNING - waiting for Rytaal'; end
    return string.format('RYTAAL PACKET VERIFIED - evidence seen %s | byte 0x0C decoded',
        os.date('%H:%M:%S',tonumber(p.last_seen_at) or os.time()));
end

function M.next_timer(c)
    normalize(c);
    local t=ensure(c);

    if t.count==nil then
        return {state='UNKNOWN',remaining=nil,count=nil,cap=t.cap};
    end
    if t.count>=t.cap then
        return {state='CAPPED',remaining=nil,count=t.count,cap=t.cap};
    end
    if type(t.next_at)~='number' then
        return {state='UNKNOWN',remaining=nil,count=t.count,cap=t.cap};
    end
    if t.regen_pending==true then
        return {
            state='VERIFY',
            remaining=nil,
            next_at=t.next_at,
            count=t.count,
            cap=t.cap,
            pending_verification=true,
            estimated=t.timer_estimated==true,
        };
    end

    local remain=t.next_at-os.time();
    if remain<=0 then
        -- Never surface a dead 00:00:00 countdown. Estimated elapsed timers
        -- require a Rytaal observation before stored count can change.
        t.regen_pending=true;
        t.regen_pending_at=os.time();
        HC.modules.state.save();
        return {
            state='VERIFY',remaining=nil,next_at=t.next_at,count=t.count,cap=t.cap,
            pending_verification=true,estimated=t.timer_estimated==true,
        };
    end

    return {
        state='COUNTING DOWN',
        remaining=remain,
        next_at=t.next_at,
        count=t.count,
        cap=t.cap,
        estimated=t.timer_estimated==true,
    };
end

function M.full_at(c)
    normalize(c);
    local t=ensure(c);
    if t.count==nil then return nil; end
    if t.count>=t.cap then return os.time(); end
    if type(t.next_at)~='number' then return nil; end
    return t.next_at + math.max(0,t.cap-t.count-1)*INTERVAL;
end

function M.auto_used(c, why)
    normalize(c);
    local t=ensure(c);

    -- Assault Orders are authoritative proof that the character's carried
    -- Imperial Army I.D. tag was consumed. Drive consumption from carried
    -- ownership so a cancellation-returned tag cannot remain stuck at 1.
    local carried=(tonumber(t.carried) or 0)>0 and 1 or 0;
    if carried==0 then return false; end

    local oldcount=t.count;
    local oldnext=t.next_at;
    local oldcarried=t.carried;
    local wascap=(t.count~=nil and t.count>=t.cap) or false;

    if t.count~=nil and t.count>0 then
        t.count=t.count-1;
    end
    set_carried_evidence(c,false,'ORDERS',why or 'Assault tag consumed');
    t.last_tag_used_at=os.time();
    t.last_tag_used_reason=why or 'auto';

    if t.count~=nil and (wascap or t.next_at==nil) then
        t.next_at=os.time()+INTERVAL;
        t.timer_estimated=true;
        t.regen_pending=nil;
        t.regen_pending_at=nil;
    end

    if HC.modules.automation and HC.modules.automation.record_external then
        HC.modules.automation.record_external(c,'assault_tags','Assault Tag used - '..tostring(why or 'auto'),{
            scope='assault_tags',count=oldcount,next_at=oldnext,carried=oldcarried
        });
    end

    HC.modules.state.save();
    HC.msg('AUTO: Assault Tag used - '..M.status(c)..(why and (' ['..why..']') or ''));
    return true;
end

local reconcile_rytaal;

local function packet_sync(e)
    if not looks_like_rytaal_menu(e) then return; end
    local c=HC.modules.state.get_char();
    local t=ensure(c);
    if t.packet_auto==false then return; end

    local now=os.time();
    local stored=b0(e.data,0x0C);

    t.packet.last_seen_at=now;
    t.packet.packet_id=0x034;
    t.packet.byte_0c=stored;
    t.packet.byte_14=b0(e.data,0x14);
    t.packet.byte_1c=b0(e.data,0x1C);
    last_packet_seen_at=now;

    if type(stored)=='number' and stored>=0 and stored<=3 then
        local previous_stored=tonumber(t.last_rytaal_menu_left);
        local carried_before=(tonumber(t.carried) or 0)>0 and 1 or 0;

        -- A verified Rytaal stored-count decrease of exactly one while the
        -- character was not carrying a tag means that tag moved from Rytaal
        -- onto this character. Preserve total tags and record the transfer.
        if previous_stored~=nil
            and previous_stored==stored+1
            and carried_before==0
        then
            c.assault_tags=type(c.assault_tags)=='table' and c.assault_tags or {};
            c.assault_tags.carried=1;
            c.assault_tags.carried_estimated=nil;
            c.assault_tags.last_tag_pickup_at=now;
            c.assault_tags.last_tag_pickup_protect_until=now+3;

            c.assault_tags=type(c.assault_tags)=='table' and c.assault_tags or {};
            c.assault_tags.carried=1;
            c.assault_tags.carried_estimated=nil;
            c.assault_tags.last_tag_pickup_at=now;
            c.assault_tags.last_tag_pickup_protect_until=now+3;

            t.carried=1;
            t.carried_estimated=nil;
            t.last_tag_pickup_at=now;
            t.last_tag_pickup_protect_until=now+3;
            t.last_tag_pickup_reason='AUTHORITATIVE Rytaal stored count decreased by one';
            t.last_tag_pickup_verified=true;
            t.last_tag_transfer_from=previous_stored;
            t.last_tag_transfer_to=stored;
        end

        t.last_rytaal_menu_left=stored;
        t.last_rytaal_authoritative_at=now;
        t.last_rytaal_reconcile_at=now;
        t.last_rytaal_reconcile_reason='Rytaal 0x034 authoritative stored count';
        t.regen_pending=nil;
        t.regen_pending_at=nil;
        t.packet.experimental=false;
        t.packet.safe_decode=true;

        -- Reconcile the Character/Rytaal split before rebuilding Total.
        -- Preserve the pre-packet total as evidence: if Total was 1 and Rytaal
        -- now verifies 0, the missing tag is necessarily on this character.
        local previous_total=tonumber(t.count);
        if t.carried~=nil then
            local carried=(tonumber(t.carried) or 0)>0 and 1 or 0;

            if previous_total~=nil then
                previous_total=math.max(0,math.min(4,math.floor(previous_total)));
                local inferred=math.max(0,math.min(1,previous_total-stored));
                if inferred>carried then
                    carried=inferred;
                    set_carried_evidence(c,inferred==1,'PACKET',
                        'Rytaal packet total/stored reconciliation');
                    t.last_tag_pickup_at=t.last_tag_pickup_at or now;
                    t.last_tag_pickup_reason=t.last_tag_pickup_reason or
                        'RECONCILED from previous total minus Rytaal packet count';
                    t.last_tag_pickup_verified=true;
                end
            end

            t.count=math.min(4,stored+carried);
            t.last_rytaal_reconcile_count=t.count;
        elseif previous_total~=nil and previous_total>stored then
            -- Carried state was unknown, but total-vs-stored proves possession.
            set_carried_evidence(c,true,'PACKET',
                'Rytaal packet total/stored reconciliation');
            t.last_tag_pickup_at=t.last_tag_pickup_at or now;
            t.last_tag_pickup_reason=t.last_tag_pickup_reason or
                'RECONCILED from previous total minus Rytaal packet count';
            t.last_tag_pickup_verified=true;
            t.count=math.min(4,stored+1);
            t.last_rytaal_reconcile_count=t.count;
        end

        if stored<3 then
            if type(t.next_at)~='number' or t.next_at<=now then
                t.next_at=now+INTERVAL;
                t.timer_estimated=true;
            end
        else
            t.next_at=nil;
            t.timer_estimated=nil;
        end

        HC.modules.state.save();
        if HC.modules.dependencies and HC.modules.dependencies.invalidate then HC.modules.dependencies.invalidate('assault','Rytaal authoritative packet synchronization'); end
        local carried=(t.carried~=nil) and (((tonumber(t.carried) or 0)>0) and 1 or 0) or nil;
        if carried==nil then
            HC.msg(string.format('AUTO: Rytaal packet sync - Character ? | Rytaal %d/3 | Total ?/4.',stored));
        else
            HC.msg(string.format('AUTO: Rytaal packet sync - Character %d | Rytaal %d/3 | Total %d/4.',
                carried,stored,stored+carried));
        end
        return;
    end

    t.packet.experimental=true;
    t.packet.safe_decode=false;
    HC.modules.state.save();
end


reconcile_rytaal = function(c, why)
    local t=ensure(c);
    local before=tonumber(t.count);

    -- Normal catch-up first. This handles every elapsed 24-hour interval
    -- when next_at still reflects the true regeneration schedule.
    normalize(c);

    local repaired=false;
    local now=os.time();

    -- One-time migration repair for the specific pre-v6.0.54 rollover bug:
    -- old builds could advance next_at but fail to increment a carried-1 /
    -- stored-0 state. We only apply this once, only on a direct Rytaal
    -- interaction, and only when no successful regeneration has ever been
    -- recorded by the fixed code.
    local effective_carried,effective_rytaal,carried_estimated=split_counts(c);
    local carried=tonumber(effective_carried) or 0;
    local rytaal=effective_rytaal;
    if t.count~=nil
        and t.count<t.cap
        and carried==1
        and rytaal==0
        and type(t.next_at)=='number'
        and t.next_at>now
        and t.timer_estimated==true
        and t.last_regen_at==nil
        and t.last_rytaal_authoritative_at==nil
        and t.rytaal_legacy_reconcile_done~=true
        and (tonumber(t.legacy_regen_repairs) or 0)==0
    then
        t.count=math.min(t.cap,t.count+1);
        if carried==1 and t.carried==nil then
            t.carried=1;
            t.carried_estimated=nil;
        end
        t.rytaal_legacy_reconcile_done=true;
        t.rytaal_legacy_reconcile_at=now;
        repaired=true;
        if t.count>=t.cap then t.next_at=nil; end
        HC.modules.state.save();
    end

    if not repaired and t.count~=nil then
        t.last_rytaal_reconcile_debug=string.format(
            'count=%s cap=%s carried=%s rytaal=%s next=%s future=%s estimated=%s lastregen=%s legacydone=%s repairs=%s',
            tostring(t.count),tostring(t.cap),tostring(carried),tostring(rytaal),
            tostring(t.next_at),tostring(type(t.next_at)=='number' and t.next_at>now),
            tostring(t.timer_estimated==true),tostring(t.last_regen_at),
            tostring(t.rytaal_legacy_reconcile_done==true),
            tostring(tonumber(t.legacy_regen_repairs) or 0)
        );
    end

    t.last_rytaal_reconcile_at=now;
    t.last_rytaal_reconcile_reason=why or 'Rytaal interaction';
    t.last_rytaal_reconcile_count=t.count;
    HC.modules.state.save();

    local carried2=(tonumber(t.carried) or 0)>0 and 1 or 0;
    local rytaal2=(t.count~=nil) and math.max(0,(tonumber(t.count) or 0)-carried2) or nil;
    local rcap=math.max(0,(tonumber(t.cap) or 4)-carried2);

    if repaired then
        HC.msg(string.format(
            'AUTO: Rytaal reconciled missed tag regeneration - Character %d | Rytaal %d/%d | Total %d/%d. Current timer preserved.',
            carried2,rytaal2 or 0,rcap,t.count,t.cap
        ));
    elseif before~=t.count then
        HC.msg(string.format(
            'AUTO: Rytaal tag state reconciled - Character %d | Rytaal %d/%d | Total %d/%d.',
            carried2,rytaal2 or 0,rcap,t.count,t.cap
        ));
    else
        HC.msg(string.format(
            'Rytaal tag check: Character %d | Rytaal %d/%d | Total %s/%d.',
            carried2,rytaal2 or 0,rcap,tostring(t.count or '?'),t.cap
        ));
    end

    return repaired or before~=t.count;
end

function M.reconcile_rytaal(c, why)
    return reconcile_rytaal(c or HC.modules.state.get_char(), why);
end

local function apply_rytaal_left_count(c,left)
    left=tonumber(left);
    if left==nil then return false; end
    left=math.max(0,math.min(3,math.floor(left)));

    local t=ensure(c);
    local now=os.time();
    local previous_stored=tonumber(t.last_rytaal_menu_left);
    local carried_before=(tonumber(t.carried) or 0)>0 and 1 or 0;

    if previous_stored~=nil
        and previous_stored==left+1
        and carried_before==0
    then
        t.carried=1;
        t.carried_estimated=nil;
        t.last_tag_pickup_at=now;
        t.last_tag_pickup_protect_until=now+3;
        t.last_tag_pickup_reason='AUTHORITATIVE Rytaal menu stored count decreased by one';
        t.last_tag_pickup_verified=true;
        t.last_tag_transfer_from=previous_stored;
        t.last_tag_transfer_to=left;
    end

    t.last_rytaal_menu_left=left;
    t.last_rytaal_authoritative_at=now;
    t.last_rytaal_reconcile_at=os.time();
    t.last_rytaal_reconcile_reason='Rytaal menu text authoritative stored count';
    t.regen_pending=nil;
    t.regen_pending_at=nil;

    local previous_total=tonumber(t.count);
    if t.carried~=nil then
        local carried=(tonumber(t.carried) or 0)>0 and 1 or 0;

        if previous_total~=nil then
            previous_total=math.max(0,math.min(4,math.floor(previous_total)));
            local inferred=math.max(0,math.min(1,previous_total-left));
            if inferred>carried then
                carried=inferred;
                set_carried_evidence(c,inferred==1,'PACKET',
                    'Rytaal menu total/stored reconciliation');
                t.last_tag_pickup_at=t.last_tag_pickup_at or now;
                t.last_tag_pickup_reason=t.last_tag_pickup_reason or
                    'RECONCILED from previous total minus Rytaal menu count';
                t.last_tag_pickup_verified=true;
            end
        end

        t.count=math.min(4,left+carried);
        t.last_rytaal_reconcile_count=t.count;
    elseif previous_total~=nil and previous_total>left then
        set_carried_evidence(c,true,'PACKET',
            'Rytaal menu total/stored reconciliation');
        t.last_tag_pickup_at=t.last_tag_pickup_at or now;
        t.last_tag_pickup_reason=t.last_tag_pickup_reason or
            'RECONCILED from previous total minus Rytaal menu count';
        t.last_tag_pickup_verified=true;
        t.count=math.min(4,left+1);
        t.last_rytaal_reconcile_count=t.count;
    end

    if left<3 then
        if type(t.next_at)~='number' or t.next_at<=os.time() then
            t.next_at=os.time()+INTERVAL;
            t.timer_estimated=true;
        end
    else
        t.next_at=nil;
        t.timer_estimated=nil;
    end

    HC.modules.state.save();
    if HC.modules.dependencies and HC.modules.dependencies.invalidate then HC.modules.dependencies.invalidate('assault','Rytaal authoritative menu synchronization'); end
    return true;
end


local function mark_character_has_tag(c,reason,evidence_type)
    local t=ensure(c);
    local now=os.time();
    evidence_type=evidence_type or 'DIALOGUE';

    if not set_carried_evidence(c,true,evidence_type,reason or 'Rytaal possession dialogue') then
        return false;
    end

    t.last_tag_pickup_at=now;
    t.last_tag_pickup_protect_until=now+5;
    t.last_tag_pickup_reason=reason or 'Rytaal possession dialogue';
    t.last_tag_pickup_verified=(evidence_rank(evidence_type)>=50);

    local stored=tonumber(t.last_rytaal_menu_left);
    if stored~=nil then
        stored=math.max(0,math.min(3,math.floor(stored)));
        t.count=math.min(4,stored+1);
    elseif t.count==nil or tonumber(t.count)<1 then
        t.count=1;
    end

    t.last_rytaal_reconcile_count=t.count;
    t.last_rytaal_reconcile_at=now;
    t.last_rytaal_reconcile_reason=reason or 'Rytaal possession dialogue';
    HC.modules.state.save();
    if HC.modules.dependencies and HC.modules.dependencies.invalidate then HC.modules.dependencies.invalidate('assault','Assault Tag possession synchronized'); end
    return true;
end



function M.reconcile_character_tag_ownership(owned,source,resource_id)
    local c=HC.modules.state.get_char();
    if type(c)~='table' or owned==nil then return false; end
    local t=ensure(c);
    local old=(tonumber(t.carried) or 0)>0 and 1 or 0;
    local accepted=set_carried_evidence(c,owned==true,'BITMAP',source or '0x055 key-item bitmap');
    if not accepted then return false; end

    t.carried_keyitem_resource_id=tonumber(resource_id) or t.carried_keyitem_resource_id;
    t.carried_bitmap_verified_at=os.time();

    -- The bitmap is authoritative only for the tag currently on this
    -- character. Rytaal's stored/account count remains sourced from Rytaal.
    -- Do not manufacture or decrement stored tags from ownership alone.
    if owned==true and old==0 then
        t.last_tag_pickup_at=t.last_tag_pickup_at or os.time();
        t.last_tag_pickup_reason='0x055 confirms Imperial Army I.D. Tag on character';
        t.last_tag_pickup_verified=true;
    end
    HC.modules.state.save();
    return true;
end

local function on_text(s)
    local low=string.lower(tostring(s or ''));

    -- Rytaal menu: "I need an Imperial Army I.D. tag. (2 left)"
    -- This direct count outranks timer/regeneration estimates.
    local left=low:match('imperial army i%.d%. tag%.%s*%((%d+)%s+left%)');
    if left then
        last_rytaal_text_at=os.time();
        apply_rytaal_left_count(HC.modules.state.get_char(),left);
        return;
    end

    local possession_dialogue=
        low:find('cannot issue a new imperial army i.d. tag',1,true)
        and low:find('while you have one in your possession',1,true);

    if possession_dialogue then
        last_rytaal_text_at=os.time();
        local c=HC.modules.state.get_char();
        mark_character_has_tag(c,'AUTHORITATIVE Rytaal possession dialogue','DIALOGUE');
        HC.msg('AUTO: Rytaal confirms I.D. Tag on character - '..M.split_status(c));
        return;
    end

    local signed_mission=low:match('you have signed up for%s+(.+)%.?$');
    if signed_mission then
        -- Successful mission signup is authoritative that the carried I.D. tag
        -- has been committed. Consume it immediately; Assault Orders remains
        -- an idempotent backup detector a few lines later.
        M.auto_used(HC.modules.state.get_char(),'Assault mission signed up');
    end

    if low:find('rytaal',1,true) and (low:find('commissions agency',1,true) or low:find('imperial army i.d. tag',1,true) or low:find('present this at one of the counters',1,true)) then
        last_rytaal_text_at=os.time();
        local c=HC.modules.state.get_char();
        local t=ensure(c);
        local last=tonumber(t.last_rytaal_reconcile_at) or 0;
        if os.time()-last>=3 then
            reconcile_rytaal(c,'Rytaal dialogue');
        end
    elseif low:find('obtained key item',1,true) and low:find('assault orders',1,true) then
        local c=HC.modules.state.get_char();
        M.auto_used(c,'Assault Orders obtained');
        return;
    elseif low:find('obtained key item',1,true) and low:find('imperial army i.d. tag',1,true) then
        last_rytaal_text_at=os.time();
        local c=HC.modules.state.get_char(); local t=ensure(c);
        local now=os.time();

        -- The pickup text is authoritative that one tag moved from Rytaal to
        -- this character. 0x055 bitmap ownership can arrive first and mark the
        -- character as carrying the tag, so do NOT gate this transfer on
        -- carried==0. That old gate left Rytaal unchanged (for example 2/3 ->
        -- 2/3) and incorrectly inflated Total when the bitmap won the race.
        --
        -- If the Rytaal 0x034 packet already observed the exact 1-tag decrease
        -- during this pickup, it recorded last_tag_transfer_from/to; in that
        -- case the transfer has already been applied and must not be decremented
        -- a second time.
        local stored=tonumber(t.last_rytaal_menu_left);
        local recent_transfer=(tonumber(t.last_tag_pickup_at) or 0) >= now-3
            and tonumber(t.last_tag_transfer_from)~=nil
            and tonumber(t.last_tag_transfer_to)~=nil
            and tonumber(t.last_tag_transfer_from)==tonumber(t.last_tag_transfer_to)+1;

        if stored~=nil and not recent_transfer then
            local before=math.max(0,math.min(3,math.floor(stored)));
            local after=math.max(0,before-1);
            t.last_rytaal_menu_left=after;
            -- Pickup transfers an existing tag; it does not create a new one.
            -- Rebuild Total from the post-transfer split so a prior bitmap
            -- carried=1 update cannot leave Total one too high.
            t.count=math.min(4,after+1);
            t.last_rytaal_authoritative_at=now;
            t.last_rytaal_reconcile_at=now;
            t.last_rytaal_reconcile_count=t.count;
            t.last_rytaal_reconcile_reason='Imperial Army I.D. Tag pickup decremented Rytaal stored count';
            t.last_tag_transfer_from=before;
            t.last_tag_transfer_to=after;
        elseif stored==nil and t.count~=nil then
            -- No direct stored-count cache yet. Preserve the known total; after
            -- carried is marked below, split_counts() can derive stored=total-1.
            t.last_rytaal_reconcile_reason='Imperial Army I.D. Tag pickup; stored count derived from total';
        end

        mark_character_has_tag(c,'AUTHORITATIVE obtained Imperial Army I.D. Tag key item','KEYITEM');
        HC.msg('AUTO: Imperial Army I.D. Tag picked up - '..M.split_status(c));
    end
end

function M.init(ctx)
    HC = ctx;
    if HC.modules.state.migrate_account_assault_tags then
        pcall(HC.modules.state.migrate_account_assault_tags);
    end
    HC.modules.packets.register(0x034,'Rytaal Assault Tag sync',packet_sync);
    HC.modules.packets.register_text('Rytaal Assault Tag text',on_text);
end

function M.repair_missed_regen(c)
    normalize(c);
    local t=ensure(c);
    if t.count==nil then
        HC.msg('Cannot repair Assault Tag regeneration: total tag count is unknown.');
        return false;
    end
    if t.count>=t.cap then
        HC.msg('Assault Tags are already capped; no missed regeneration can be added.');
        return false;
    end

    local oldcount=t.count;
    local oldnext=t.next_at;
    local oldcarried=t.carried;

    t.count=math.min(t.cap,t.count+1);
    t.legacy_regen_repairs=(tonumber(t.legacy_regen_repairs) or 0)+1;
    t.last_repair_at=os.time();

    if t.count>=t.cap then
        t.next_at=nil;
    else
        t.next_at=oldnext;
    end

    if HC.modules.automation and HC.modules.automation.record_external then
        HC.modules.automation.record_external(
            c,
            'assault_tag_repair',
            'Repaired one missed legacy Assault Tag regeneration',
            {scope='assault_tags',count=oldcount,next_at=oldnext,carried=oldcarried}
        );
    end

    HC.modules.state.save();

    local carried=(tonumber(t.carried) or 0)>0 and 1 or 0;
    local rytaal=math.max(0,t.count-carried);
    local rytaal_cap=math.max(0,t.cap-carried);
    HC.msg(string.format(
        'Assault Tag repair applied: Rytaal %d/%d | Total %d/%d. Current next-tag timer preserved.',
        rytaal,rytaal_cap,t.count,t.cap
    ));
    return true;
end

function M.draw(c)
    local imgui = HC.imgui;
    if imgui == nil then return; end
    normalize(c);
    local t = ensure(c);
    local rs=M.rytaal_status(c);

    if HC.modules.uikit then HC.modules.uikit.section_header('Assault Tags'); else imgui.Text('Assault Tags'); imgui.Separator(); end

    local ce=M.carried_evidence(c);
    local verified=(ce and ce.evidence_type=='BITMAP');
    local full=M.full_at(c);
    local total_text=(rs.total==nil) and 'UNKNOWN'
        or string.format('%d / %d%s',rs.total,rs.cap,rs.capped and '  CAPPED' or '');
    local carried_text=(rs.total==nil) and '?'
        or string.format('%d / 1%s',rs.carried or 0,rs.estimated and '  ESTIMATED' or '');
    local rytaal_text=(rs.total==nil) and '?'
        or string.format('%d / %d%s',rs.rytaal or 0,rs.rytaal_cap or 0,rs.capped and '  CAPPED' or '');
    local next_text='-';
    if rs.next_remaining~=nil then
        next_text=HC.modules.core.format_duration(rs.next_remaining);
    elseif rs.capped then
        next_text='CAPPED';
    end
    local full_text='-';
    if full and t.count~=nil and t.count<t.cap then
        full_text=os.date('%b %d %H:%M',full);
    elseif rs.capped then
        full_text='CAPPED';
    end


    local table_supported=(imgui.BeginTable~=nil and imgui.TableNextColumn~=nil and imgui.EndTable~=nil);
    if table_supported and imgui.BeginTable('##assault_tag_status_v6960',2,(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512)) then
        imgui.TableNextColumn(); imgui.TextDisabled('Total');
        imgui.TableNextColumn(); imgui.Text(total_text);

        imgui.TableNextColumn(); imgui.TextDisabled('On Character');
        imgui.TableNextColumn(); imgui.Text(carried_text);
        if verified then imgui.SameLine(); imgui.TextDisabled('[Confirmed]'); end

        imgui.TableNextColumn(); imgui.TextDisabled('At Rytaal (Account)');
        imgui.TableNextColumn(); imgui.Text(rytaal_text);

        imgui.TableNextColumn(); imgui.TextDisabled('Next Tag');
        imgui.TableNextColumn(); imgui.Text(next_text);

        imgui.TableNextColumn(); imgui.TextDisabled('Full At');
        imgui.TableNextColumn(); imgui.Text(full_text);
        imgui.EndTable();
    else
        imgui.Text('Total: '..total_text);
        imgui.TextDisabled('On Character: '..carried_text..(verified and '  [Confirmed]' or ''));
        imgui.TextDisabled('At Rytaal (Account): '..rytaal_text);
        imgui.TextDisabled('Next Tag: '..next_text);
        imgui.TextDisabled('Full At: '..full_text);
    end

    if t.regen_pending then
        imgui.Spacing();
        imgui.TextDisabled('Verification needed: a tag regeneration is due. Talk to Rytaal to sync.');
    end

end

function M.draw_manual_adjust(c)
    local imgui=HC.imgui;
    if imgui==nil then return; end
    normalize(c);
    local t=ensure(c);
    local rs=M.rytaal_status(c);

    if t.count==nil then
        imgui.TextDisabled('Assault Tag count is not initialized yet. Talk to Rytaal before using manual repair controls.');
        return;
    end

    local carried=(rs and rs.carried~=nil) and tostring(rs.carried)..'/1' or '?';
    local rytaal=(rs and rs.rytaal~=nil) and tostring(rs.rytaal)..'/'..tostring(rs.rytaal_cap or 3) or '?';
    imgui.Text(string.format('Current tracked total: %d / %d',t.count or 0,t.cap or 4));
    imgui.TextDisabled('On Character: '..carried..'  |  At Rytaal: '..rytaal);
    imgui.TextDisabled('Use these only to repair a tracker mismatch. Normal Assault Tag updates are automatic.');

    if imgui.SmallButton('- Used##diag_tag_used') and t.count > 0 then
        local wascap = t.count >= t.cap;
        t.count = t.count - 1;
        if (tonumber(t.carried) or 0)>0 then t.carried=0; t.carried_estimated=nil; end
        if wascap or t.next_at == nil then t.next_at = os.time() + INTERVAL; t.timer_estimated=true; end
        HC.modules.state.save();
        HC.msg('Assault Tag manual repair: marked one tag used.');
    end
    imgui.SameLine();
    if imgui.SmallButton('+ Received##diag_tag_received') then
        t.count = math.min(t.cap, t.count + 1);
        if t.carried==nil then t.carried=(t.count>0) and 1 or 0; t.carried_estimated=true; end
        if t.count >= t.cap then t.next_at = nil; t.timer_estimated=nil; end
        HC.modules.state.save();
        HC.msg('Assault Tag manual repair: marked one tag received.');
    end
end

function M.command(w)
    if string.lower(w[2] or '') ~= 'tags' then return false; end
    local c=HC.modules.state.get_char(); local t=ensure(c);
    local a=string.lower(w[3] or '');
    if a=='auto' then
        local v=string.lower(w[4] or 'status');
        if v=='on' then t.packet_auto=true; HC.modules.state.save(); HC.msg('Rytaal Assault Tag packet sync enabled. Direct Rytaal menus overwrite stored-count estimates.');
        elseif v=='off' then t.packet_auto=false; HC.modules.state.save(); HC.msg('Rytaal Assault Tag packet sync disabled; Assault Orders consumption tracking remains active.');
        else HC.msg('Rytaal Assault Tag packet sync: '..M.packet_status(c)); end
        return true;
    end
    if a=='repair' then
        M.repair_missed_regen(c);
        return true;
    end

    if a=='carried' then
        local v=tonumber(w[4]);
        if v==nil or (v~=0 and v~=1) then HC.msg('Usage: /hcheck tags carried <0|1>'); return true; end
        set_carried_evidence(c,v==1,'MANUAL','Manual /hcheck tags carried');
        HC.modules.state.save();
        HC.msg('Assault carried-tag state updated: '..M.split_status(c));
        return true;
    end

    local count = tonumber(w[3]);
    local cap = tonumber(w[4]) or 4;
    if count == nil then HC.msg('Usage: /hcheck tags <count> [cap] | /hcheck tags carried <0|1> | /hcheck tags repair | /hcheck tags auto on|off|status'); return true; end
    t.cap = math.max(1, math.floor(cap));
    t.count = math.max(0, math.min(t.cap, math.floor(count)));
    if t.count==0 then
        t.carried=0; t.carried_estimated=nil;
    elseif t.carried==nil then
        t.carried=1; t.carried_estimated=true;
    end
    t.next_at = (t.count < t.cap) and (os.time() + INTERVAL) or nil;
    t.timer_estimated = t.count < t.cap and true or nil;
    HC.modules.state.save();
    HC.msg('Assault tags synced manually: ' .. M.status(c));
    return true;
end

return M;
