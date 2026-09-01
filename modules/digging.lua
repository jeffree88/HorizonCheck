local M = {};
local HC;
local dig_window={ at=0, seq=false };

local ranks = {
    { id='amateur',    name='Amateur',    max=100, min_skill=0 },
    { id='recruit',    name='Recruit',    max=110, min_skill=10 },
    { id='initiate',   name='Initiate',   max=120, min_skill=20 },
    { id='novice',     name='Novice',     max=130, min_skill=30 },
    { id='apprentice', name='Apprentice', max=140, min_skill=40 },
    { id='journeyman', name='Journeyman', max=150, min_skill=50 },
    { id='craftsman',  name='Craftsman',  max=160, min_skill=60 },
    { id='artisan',    name='Artisan',     max=170, min_skill=70 },
    { id='adept',      name='Adept',       max=180, min_skill=80 },
    { id='veteran',    name='Veteran',     max=190, min_skill=90 },
    { id='expert',     name='Expert',      max=200, min_skill=100 },
};

local by_id = {};
for i,r in ipairs(ranks) do by_id[r.id]=i; end

-- HorizonXI / FFXI item ID: bunch of Gysahl Greens = 4545.
-- Chocobo digging consumes greens from the character's main Inventory, so the
-- row reports that container rather than counting storage/wardrobes.
local GYSAHL_GREENS_ID=4545;

local function gysahl_greens_count()
    local inv=nil;
    pcall(function()
        inv=AshitaCore:GetMemoryManager():GetInventory();
    end);
    if inv==nil then return nil; end

    local max=nil;
    pcall(function()
        max=inv:GetContainerCountMax(0);
    end);
    if type(max)~='number' or max<0 then return nil; end

    local total=0;
    for idx=0,max do
        local e=nil;
        pcall(function()
            e=inv:GetContainerItem(0,idx);
        end);
        if e~=nil and tonumber(e.Id)==GYSAHL_GREENS_ID then
            total=total+math.max(0,tonumber(e.Count) or 0);
        end
    end
    return math.floor(total);
end

local function ensure(c)
    c.digging = type(c.digging)=='table' and c.digging or {};
    if by_id[string.lower(tostring(c.digging.rank or ''))] == nil then c.digging.rank='amateur'; end

    -- v6.1.49 migration:
    -- Old builds may have persisted Expert/200 and later cleared the metadata
    -- that originally marked it as inferred. Treat Expert as trusted only when
    -- the newer verified_rank field explicitly confirms Expert.
    if string.lower(tostring(c.digging.rank or ''))=='expert'
        and string.lower(tostring(c.digging.verified_rank or ''))~='expert'
    then
        c.digging.rank='veteran';
        c.digging.verified_rank='veteran';
        c.digging.verified_rank_at=os.time();
        c.digging.rank_auto=nil;
        c.digging.rank_auto_confidence='MIGRATED UNVERIFIED EXPERT TO VETERAN';
        c.digging.rank_auto_observed=nil;
        c.digging.rank_auto_at=os.time();
        c.digging.rank_migration_6149=true;
    end

    local dk=HC.modules.core.daily_key();
    if c.digging.daily_key ~= dk then
        c.digging.daily_key=dk;
        c.digging.count=0;
        c.digging.first_success_at=nil;
        c.digging.last_success_at=nil;
        c.digging.attempts=0;
        c.digging.misses=0;
        c.digging.session_items={};
        c.digging.last_miss_at=nil;
        c.digging.last_miss_sig=nil;
        c.digging.warned_75=false;
        c.digging.warned_90=false;
        c.digging.warned_95=false;
        c.digging.warned_cap=false;
        c.digging.server_cap_confirmed=false;
        c.digging.server_cap_at=nil;
        c.digging.rank_auto=nil;
        c.digging.rank_auto_confidence=nil;
        c.digging.rank_auto_observed=nil;
        c.digging.rank_auto_at=nil;
        c.digging.cap_reconciled=nil;
        c.digging.cap_reconciled_from=nil;
        c.digging.cap_reconciled_at=nil;
        c.daily=type(c.daily)=='table' and c.daily or {};
        c.daily.digging=nil;
    end

    -- Persisted-state reconciliation:
    -- A server-confirmed cap is authoritative even across addon reloads.
    -- Older builds could save server_cap_confirmed=true with an observed
    -- count one short (for example 189/190). Normalize that stale state here
    -- so UI/status always reflects the verified daily cap.
    if c.digging.server_cap_confirmed==true then
        local ridx=by_id[string.lower(tostring(c.digging.rank or ''))] or 1;
        local r=ranks[ridx];
        local old=tonumber(c.digging.count) or 0;
        if old~=r.max then
            c.digging.server_cap_reconciled_from=old;
            c.digging.server_cap_reconciled_to=r.max;
            c.digging.count=r.max;
        end
    end

    c.digging.count=math.max(0,math.floor(tonumber(c.digging.count) or 0));
    c.digging.attempts=math.max(c.digging.count,math.floor(tonumber(c.digging.attempts) or c.digging.count));
    c.digging.misses=math.max(0,math.floor(tonumber(c.digging.misses) or 0));
    c.digging.session_items=type(c.digging.session_items)=='table' and c.digging.session_items or {};
    c.digging.first_success_at=tonumber(c.digging.first_success_at);
    c.digging.last_success_at=tonumber(c.digging.last_success_at);
    c.digging.warned_75=c.digging.warned_75==true;
    c.digging.warned_90=c.digging.warned_90==true;
    c.digging.warned_95=c.digging.warned_95==true;
    c.digging.warned_cap=c.digging.warned_cap==true;
    c.digging.server_cap_confirmed=c.digging.server_cap_confirmed==true;
    c.digging.server_cap_at=tonumber(c.digging.server_cap_at);
    return c.digging;
end

local function rankinfo(d)
    local verified=string.lower(tostring(d.verified_rank or ''));
    local id=(by_id[verified] and verified) or string.lower(tostring(d.rank or 'amateur'));
    local i=by_id[id] or 1;
    d.rank=ranks[i].id;
    return ranks[i],i;
end


local function remaining(c)
    local d=ensure(c); local r=rankinfo(d);
    if d.server_cap_confirmed then return 0,r; end
    return math.max(0,r.max-d.count),r;
end

local function daily_stats(c)
    local d=ensure(c); local left,r=remaining(c);
    local display_count=d.count;
    if d.server_cap_confirmed then display_count=r.max; end
    local pct=0;
    if r.max>0 then pct=math.min(100,(display_count/r.max)*100); end
    return {
        count=display_count,
        max=r.max,
        remaining=left,
        percent=pct,
        rank=r.name,
        server_cap_confirmed=d.server_cap_confirmed==true,
    };
end

local function fatigue_warning(c)
    local d=ensure(c); local s=daily_stats(c);
    if s.server_cap_confirmed or s.count>=s.max then
        if not d.warned_cap then
            d.warned_cap=true;
            HC.msg(string.format('DIGGING FATIGUE: Daily cap reached - %d/%d (%s).',s.count,s.max,s.rank));
        end
    elseif s.percent>=95 and not d.warned_95 then
        d.warned_95=true;
        HC.msg(string.format('DIGGING FATIGUE WARNING: %.0f%% complete - %d digs remaining.',s.percent,s.remaining));
    elseif s.percent>=90 and not d.warned_90 then
        d.warned_90=true;
        HC.msg(string.format('DIGGING FATIGUE WARNING: %.0f%% complete - %d digs remaining.',s.percent,s.remaining));
    elseif s.percent>=75 and not d.warned_75 then
        d.warned_75=true;
        HC.msg(string.format('Digging progress: %.0f%% complete - %d digs remaining.',s.percent,s.remaining));
    end
end

local function sync_complete(c, why)
    local d=ensure(c); local r=rankinfo(d);
    local complete=d.server_cap_confirmed or d.count>=r.max;
    local old=c.daily.digging==true;
    if complete and not old then
        c.daily.digging=true;
        if HC.modules.automation and HC.modules.automation.record_external then
            HC.modules.automation.record_external(c,'digging',
                string.format('%d/%d successful daily digs - %s',d.count,r.max,tostring(why or 'daily cap reached')),
                {scope='daily',key='digging',old=nil});
        end
        HC.msg(string.format('AUTO: Digging daily cap complete - %d/%d (%s).',d.count,r.max,r.name));
    elseif not complete and old then
        c.daily.digging=nil;
    end
    fatigue_warning(c);
end

local function set_rank(c, id, announce)
    id=string.lower(tostring(id or ''));
    local idx=by_id[id];
    if not idx then return false; end
    local d=ensure(c);
    local changed=d.rank~=id;
    d.rank=id;
    d.verified_rank=id;
    d.verified_rank_at=os.time();
    sync_complete(c,'rank updated');
    HC.modules.state.save();
    if announce and changed then HC.msg(string.format('Digging rank set to %s; daily cap %d.',ranks[idx].name,ranks[idx].max)); end
    return true;
end

local function rank_from_skill(skill)
    skill=tonumber(skill);
    if not skill then return nil; end
    local idx=1;
    for i,r in ipairs(ranks) do if skill>=r.min_skill then idx=i; end end
    return ranks[idx].id;
end

local function promote_rank_from_observed_count(c)
    -- v6.1.47: rank is verification-only; counters never promote rank.
    return false;
end

local function promote_rank_from_observed_count_DISABLED(c)
    local d=ensure(c);
    local current,current_idx=rankinfo(d);
    if d.count<=current.max then return false; end

    -- A character cannot still be at a rank whose daily cap has already been
    -- exceeded. Promote to the first rank whose cap can contain the observed
    -- successful-dig count. Never use this path to downgrade.
    local target_idx=current_idx;
    while target_idx<#ranks and d.count>ranks[target_idx].max do
        target_idx=target_idx+1;
    end

    if target_idx>current_idx then
        local target=ranks[target_idx];
        d.rank=target.id;
        d.rank_auto=true;
        d.rank_auto_confidence='INFERRED FROM OBSERVED DIG COUNT';
        d.rank_auto_observed=d.count;
        d.rank_auto_at=os.time();

        HC.msg(string.format(
            'AUTO: Digging rank promoted to %s; observed %d digs exceeds the previous %s cap of %d. New cap %d.',
            target.name,d.count,current.name,current.max,target.max
        ));
        return true;
    end
    return false;
end

local function rank_from_capped_count(count)
    count=tonumber(count);
    if not count then return nil,nil; end
    count=math.max(0,math.floor(count));

    -- Daily caps are spaced by 10 digs. Allow only a one-dig shortfall because
    -- the live detector can miss the final successful item result immediately
    -- before HorizonXI emits its authoritative maxed-for-today message.
    local best=nil;
    for _,r in ipairs(ranks) do
        local miss=r.max-count;
        if miss>=0 and miss<=1 then
            if not best or miss<best.miss then best={rank=r,miss=miss}; end
        end
    end
    if best then return best.rank,best.miss; end
    return nil,nil;
end

local function reconcile_server_cap(c)
    -- v6.1.47: a fatigue/cap message verifies completion, not rank.
    return false;
end

local function reconcile_server_cap_DISABLED(c)
    local d=ensure(c);
    if not d.server_cap_confirmed then return false; end

    local observed=d.count;
    local inferred,miss=rank_from_capped_count(observed);
    if inferred then
        local oldrank=d.rank;
        d.rank=inferred.id;
        d.rank_auto=true;
        d.rank_auto_confidence='VERIFIED BY HORIZONXI DAILY CAP';
        d.rank_auto_observed=observed;
        d.rank_auto_at=os.time();

        -- Once HorizonXI explicitly says the daily cap is reached, the rank cap
        -- is authoritative. Reconcile a one-missed-result counter to the cap.
        d.count=inferred.max;
        d.cap_reconciled=true;
        d.cap_reconciled_from=observed;
        d.cap_reconciled_at=os.time();

        if oldrank~=inferred.id or miss>0 then
            HC.msg(string.format(
                'AUTO: Digging rank %s [VERIFIED BY DAILY CAP] - observed %d successful digs; reconciled to %d/%d.',
                inferred.name,observed,inferred.max,inferred.max
            ));
        end
        return true;
    end

    d.rank_auto=false;
    d.rank_auto_confidence='CAP CONFIRMED - COUNT DID NOT MATCH A KNOWN RANK WITHIN 1 DIG';
    d.rank_auto_observed=observed;
    d.rank_auto_at=os.time();
    return false;
end


local function is_obtained_item(s)
    s=string.lower(tostring(s or ''));
    if not s:find('obtained:',1,true) then return false; end
    if s:find('guild points',1,true) then return false; end
    if s:find('key item',1,true) then return false; end
    return true;
end

local function is_success(s)
    local now=os.time();
    if not dig_window.seq or now-dig_window.at>5 then return false; end
    if not is_obtained_item(s) then return false; end
    dig_window.at=0;
    dig_window.seq=false;
    return true;
end

local function on_text(s)
    local c=HC.modules.state.get_char(); local d=ensure(c);
    local lower=string.lower(tostring(s or ''));

    -- v6.0.20: HorizonXI's own fatigue message is authoritative.
    if lower:find('you have maxed your player digging for today',1,true) then
        if not d.server_cap_confirmed then
            d.server_cap_confirmed=true;
            d.server_cap_at=os.time();
            c.daily=type(c.daily)=='table' and c.daily or {};
            c.daily.digging=true;
            d.warned_cap=true;

            local observed_before=d.count;
            local rr=rankinfo(d);

            -- The server cap message is authoritative. If a success/result line
            -- was missed by chat parsing, reconcile the displayed count to the
            -- verified rank's daily maximum instead of leaving e.g. 189/190.
            d.count=rr.max;
            d.server_cap_reconciled_from=observed_before;
            d.server_cap_reconciled_to=rr.max;

            if HC.modules.automation and HC.modules.automation.record_external then
                HC.modules.automation.record_external(
                    c,'digging_cap',
                    string.format('HorizonXI confirmed daily digging cap; observed %d, reconciled %d/%d, rank %s',
                        observed_before,d.count,rr.max,rr.name),
                    {scope='daily',key='digging',old=nil}
                );
            end
            HC.modules.state.save();
            HC.msg(string.format(
                'DIGGING FATIGUE: HorizonXI confirmed the daily cap. %d successful digs observed; reconciled to %d/%d (%s); 0 remaining.',
                observed_before,d.count,rr.max,rr.name
            ));
        end
        return;
    end

    -- Once HorizonXI explicitly confirms the daily cap, additional dig-result
    -- spam is informational only and must not mutate today's session counters.
    if d.server_cap_confirmed and (
        lower:find('you dig and you dig, but find nothing',1,true) or
        is_obtained_item(lower)
    ) then
        return;
    end

    -- Capture-verified miss result.
    if lower:find('you dig and you dig, but find nothing',1,true) then
        local now=os.time();
        local sig=lower:gsub('%c',''):gsub('%s+',' ');
        if d.last_miss_sig~=sig or d.last_miss_at==nil or now-d.last_miss_at>=2 then
            d.misses=d.misses+1;
            d.attempts=d.attempts+1;
            d.last_miss_at=now;
            d.last_miss_sig=sig;
            HC.modules.state.save();
        end
        return;
    end

    if is_success(lower) then
        local now=os.time();
        local sig=lower:gsub('%c',''):gsub('%s+',' ');
        -- Horizon/chat filters may echo the same success line. Count one unique result only.
        if d.last_success_sig~=sig or d.last_success_at==nil or now-d.last_success_at>=2 then
            d.count=d.count+1;
            d.attempts=d.attempts+1;
            if not d.first_success_at then d.first_success_at=now; end
            d.last_success_at=now;
            d.last_success_sig=sig;
            d.last_success_text=sig;

            local item=lower:match('obtained:%s*(.-)%s*%.?%s*$');
            if item and item~='' then
                item=item:gsub('^%s+',''):gsub('%s+$','');
                d.session_items[item]=(tonumber(d.session_items[item]) or 0)+1;
            end

            -- If the current rank cap has been exceeded, the rank is stale.
            -- Promote first so completion/remaining are evaluated against the
            -- correct higher cap rather than leaving impossible states such as
            -- 115/100 Amateur.
            sync_complete(c,'successful chocobo dig');
            HC.modules.state.save();
        end
        return;
    end

    -- Horizon exposes messages such as:
    -- "Your Chocobo Digging skill increases by .1 raising it to 99.2!"
    -- Parse the FINAL skill value, not the ".1" increase amount. Skill text is
    -- secondary evidence: it may promote a stale rank but must never downgrade
    -- a stronger rank (especially one verified from the daily cap).
    -- Skill values are not rank evidence. Only explicit text that actually
    -- identifies a digging rank may change the stored rank.
    if lower:find('digg',1,true) and lower:find('rank',1,true) then
        for _,r in ipairs(ranks) do
            if lower:find(r.id,1,true) then
                d.rank_auto=true;
                d.rank_auto_confidence='VERIFIED BY EXPLICIT RANK TEXT';
                d.rank_auto_at=os.time();
                set_rank(c,r.id,true);
                break;
            end
        end
    end
end


local function on_packet(id,data)
    local now=os.time();
    -- Successful digging capture showed a characteristic action/result sequence
    -- including 0x01D / 0x01E / 0x020 / 0x02A / 0x02F before the Obtained line.
    -- Arm only from the rare 0x02F action packet, then accept a nearby Obtained item.
    if id==0x02F then
        dig_window.at=now;
        dig_window.seq=true;
        local c=HC.modules.state.get_char();
        local d=ensure(c);
        d.last_packet_at=now;
    elseif dig_window.seq and now-dig_window.at>4 then
        dig_window.at=0;
        dig_window.seq=false;
    end
end

function M.init(ctx)
    HC=ctx;
    if HC.modules.packets then
        HC.modules.packets.register_text('digging',on_text);
        if HC.modules.packets.register_in then HC.modules.packets.register_in('digging',on_packet); end
    end
end

function M.status(c)
    local d=ensure(c); local s=daily_stats(c);
    local greens=gysahl_greens_count();
    local green_text=greens~=nil and (tostring(greens)..' Gysahl Greens remain') or 'Gysahl Greens remaining: ?';
    if d.server_cap_confirmed then
        return string.format('CAPPED | %d/%d successful | %s rank | %s',
            s.count,s.max,s.rank,green_text);
    end
    return string.format('%d/%d successful | %d remaining | %s rank | %s',
        s.count,s.max,s.remaining,s.rank,green_text);
end

function M.draw_row(c)
    local imgui=HC.imgui; if not imgui then return; end
    local d=ensure(c);
    local r=rankinfo(d);
    local stats=daily_stats(c);
    local complete=d.server_cap_confirmed or d.count>=r.max;
    local box={complete};

    imgui.Checkbox('Digging##v605diggingdone',box);
    imgui.SameLine();

    local greens=gysahl_greens_count();
    local status='';
    if stats.server_cap_confirmed then
        status=string.format('CAPPED | %d/%d successful | %s rank',
            stats.count,stats.max,r.name);
    else
        status=string.format('%d/%d successful | %d remaining | %s rank',
            stats.count,stats.max,stats.remaining,r.name);
    end

    if greens~=nil then
        status=status..' | '..tostring(greens)..' Gysahl Greens remain';
    else
        status=status..' | Gysahl Greens remaining: ?';
    end

    imgui.Text(status);


end

function M.command(w)
    if string.lower(w[2] or '')~='digging' and string.lower(w[2] or '')~='dig' then return false; end
    local c=HC.modules.state.get_char(); local d=ensure(c);
    local sub=string.lower(w[3] or 'status');
    if sub=='status' then
        local stats=daily_stats(c);
        HC.msg('Digging: '..M.status(c));
        HC.msg(string.format('Daily progress: %.1f%% | %d remaining.',stats.percent,stats.remaining));
        if stats.server_cap_confirmed then
            HC.msg('Fatigue: DAILY CAP REACHED - CONFIRMED BY HORIZONXI.');
        elseif stats.percent>=100 then HC.msg('Fatigue: DAILY CAP REACHED.');
        elseif stats.percent>=95 then HC.msg('Fatigue: CRITICAL - almost capped.');
        elseif stats.percent>=90 then HC.msg('Fatigue: HIGH.');
        elseif stats.percent>=75 then HC.msg('Fatigue: approaching daily cap.');
        else HC.msg('Fatigue: normal.'); end
        if d.last_packet_at then HC.msg('Last digging packet 0x02F detected '..tostring(os.time()-d.last_packet_at)..'s ago.'); else HC.msg('No digging 0x02F packet detected yet.'); end
        if d.last_success_at then HC.msg('Last successful dig detected '..tostring(os.time()-d.last_success_at)..'s ago.'); else HC.msg('No successful dig result detected yet today.'); end;
        return true;
    elseif sub=='rank' then
        local id=string.lower(w[4] or '');
        if set_rank(c,id,true) then return true; end
        HC.msg('Digging ranks: amateur, recruit, initiate, novice, apprentice, journeyman, craftsman, artisan, adept, veteran, expert.');
        return true;
    elseif sub=='set' then
        local n=tonumber(w[4]);
        if n then d.count=math.max(0,math.floor(n)); sync_complete(c,'manual count set'); HC.modules.state.save(); HC.msg('Digging count set: '..M.status(c)); end
        return true;
    elseif sub=='+' or sub=='add' then
        d.count=d.count+1; sync_complete(c,'manual correction'); HC.modules.state.save(); return true;
    elseif sub=='-' or sub=='sub' then
        d.count=math.max(0,d.count-1); sync_complete(c,'manual correction'); HC.modules.state.save(); return true;
    elseif sub=='reset' then
        d.count=0;
        d.server_cap_confirmed=false;
        d.server_cap_at=nil;
        d.warned_cap=false;
        d.rank_auto=nil;
        d.rank_auto_confidence=nil;
        d.rank_auto_observed=nil;
        d.rank_auto_at=nil;
        d.cap_reconciled=nil;
        d.cap_reconciled_from=nil;
        d.cap_reconciled_at=nil;
        c.daily.digging=nil;
        HC.modules.state.save();
        HC.msg('Digging count and server-cap confirmation reset for today.');
        return true;
    end
    return true;
end

function M.ranks() return ranks; end
return M;
