local M = {};
local HC;

local VANA_EPOCH_OFFSET = 92514960;
local VANA_DAY_SECONDS = 86400;
local SPEED = 25;

-- City stable zone IDs:
-- Southern San d'Oria = 230
-- Bastok Mines       = 234
-- Windurst Woods     = 241
-- Kazham             = 250
local CITY_BY_ZONE = {
    [230]='sandoria',
    [234]='bastok',
    [241]='windurst',
    [250]='kazham',
};

-- Route confidence is deliberately per-route.  A route is marked capture-verified
-- only when the user has supplied a HorizonCheck capture for that exact origin NPC
-- and destination pair.  Current supplied captures verify Quelle -> Southern San d'Oria
-- and Orlaine -> Port Jeuno; the other schedule mappings remain predictions/reference data.
-- Reward/cutoff metadata is destination-specific. v7.2.22 corrected San d'Oria and Windurst
-- rows that had retained phase-index reward data after the destination rotations were verified.
-- The 2026-08-29 Orlaine -> Port Jeuno full-run capture independently confirms the
-- 15:29 Jeuno threshold boundary: 15:34 produced Gysahl Greens, and Narsha was the destination NPC.
-- The capture button is intentionally retained for full-run acceptance/completion evidence.
local CITIES = {
    bastok = {
        label='Bastok',
        zone='Bastok Mines',
        pos='J-9',
        verified=false,
        routes={
            [0]={
                npc='Azette',
                destination='Windurst Woods',
                cutoff='32:29',
                reward="Miratete's Memoirs",
                gear_needed=true,
                min_bonus=3,
            },
            [1]={
                npc='Eulaphe',
                destination='Lower Jeuno',
                cutoff='18:49',
                reward='Bastok Mines Glyph',
                gear_needed=false,
                min_bonus=0,
            },
            [2]={
                npc='Quelle',
                capture_verified=true,
                destination="Southern San d'Oria",
                cutoff='20:13',
                reward='Dragon Chronicles',
                gear_needed=false,
                min_bonus=0,
            },
        },
    },

    sandoria = {
        label="San d'Oria",
        zone="Southern San d'Oria",
        pos='I-11',
        verified=false,
        routes={
            [0]={
                npc='Camereine',
                destination='Bastok Mines',
                cutoff='19:59',
                reward='Dragon Chronicles',
                gear_needed=false,
                min_bonus=0,
            },
            [1]={
                npc='Emoussine',
                destination='Windurst Woods',
                cutoff='28:19',
                reward="Miratete's Memoirs",
                gear_needed=false,
                min_bonus=0,
            },
            [2]={
                npc='Meuneille',
                destination='Upper Jeuno',
                cutoff='13:15',
                reward="East San d'Oria Glyph",
                gear_needed=false,
                min_bonus=0,
            },
        },
    },

    windurst = {
        label='Windurst',
        zone='Windurst Woods',
        pos='K-12',
        verified=false,
        routes={
            -- HorizonXI rotates the Windurst renters left-to-right each Vana'diel day:
            -- Orlaine -> Sariale -> Amimi.  The earlier table had the two outer
            -- renters reversed, which made phase 0 display Amimi when Orlaine was
            -- actually the active Riding Game NPC.
            [0]={
                npc='Orlaine',
                capture_verified=true,
                destination='Port Jeuno',
                cutoff='15:29',
                reward='Windurst Woods Glyph',
                gear_needed=false,
                min_bonus=0,
            },
            [1]={
                npc='Sariale',
                destination="Southern San d'Oria",
                cutoff='28:36',
                reward="Miratete's Memoirs",
                gear_needed=false,
                min_bonus=0,
            },
            [2]={
                npc='Amimi',
                destination='Bastok Mines',
                cutoff='32:29',
                reward="Miratete's Memoirs",
                gear_needed=true,
                min_bonus=3,
            },
        },
    },

    -- FFXIclopedia reference data for A Chocobo Riding Game (Kazham):
    -- Tielleque at Kazham (F-9) sends the player to Norg.  The quest is offered
    -- on the same schedule as Bastok Mines -> Windurst Woods (our verified phase 0).
    -- Reward windows are retained exactly as listed by the supplied source until a
    -- HorizonXI run capture independently verifies them.
    kazham = {
        label='Kazham',
        zone='Kazham',
        pos='F-9',
        verified=false,
        source_reference='FFXIclopedia',
        routes={
            [0]={
                npc='Tielleque',
                destination='Norg',
                cutoff='2:29',
                reward="Page from Miratete's Memoirs",
                ticket_window='2:30 - 3:59',
                gear_needed=false,
                min_bonus=0,
                source_reference='FFXIclopedia',
                availability_phase=0,
            },
            [1]={
                npc='Tielleque',
                destination='Norg',
                cutoff='2:29',
                reward="Page from Miratete's Memoirs",
                ticket_window='2:30 - 3:59',
                gear_needed=false,
                min_bonus=0,
                source_reference='FFXIclopedia',
                availability_phase=0,
            },
            [2]={
                npc='Tielleque',
                destination='Norg',
                cutoff='2:29',
                reward="Page from Miratete's Memoirs",
                ticket_window='2:30 - 3:59',
                gear_needed=false,
                min_bonus=0,
                source_reference='FFXIclopedia',
                availability_phase=0,
            },
        },
    },
};

local function vana_total_seconds(now)
    now=tonumber(now) or os.time();
    return (now + VANA_EPOCH_OFFSET) * SPEED;
end

function M.vana_day(now)
    return math.floor(vana_total_seconds(now) / VANA_DAY_SECONDS);
end

function M.seconds_until_change(now)
    now=tonumber(now) or os.time();
    local total=vana_total_seconds(now);
    local into=total % VANA_DAY_SECONDS;
    return math.ceil((VANA_DAY_SECONDS-into)/SPEED);
end

local function get_zone_id()
    if HC.modules.automation and HC.modules.automation.get_zone_id then
        return HC.modules.automation.get_zone_id();
    end
    return nil;
end

local function city_key_from_zone(zid)
    return CITY_BY_ZONE[tonumber(zid)];
end

local function active_city_key()
    return city_key_from_zone(get_zone_id()) or 'bastok';
end

function M.current(now, city_key)
    city_key=city_key or active_city_key();
    local city=CITIES[city_key] or CITIES.bastok;
    local day=M.vana_day(now);
    local phase=day % 3;
    local r=city.routes[phase];
    local next_phase=(phase+1)%3;
    local n=city.routes[next_phase];

    return {
        city_key=city_key,
        city=city.label,
        zone=city.zone,
        pos=city.pos,
        verified=(r.capture_verified==true),
        route_verified=(r.capture_verified==true),
        vana_day=day,
        phase=phase,
        npc=r.npc,
        destination=r.destination,
        cutoff=r.cutoff,
        reward=r.reward,
        gear_needed=r.gear_needed,
        min_bonus=r.min_bonus,
        ticket_window=r.ticket_window,
        source_reference=r.source_reference or city.source_reference,
        available=(city_key~='kazham') or (phase==0),
        availability_phase=r.availability_phase,
        next_npc=n.npc,
        next_destination=n.destination,
        remaining=M.seconds_until_change(now),
    };
end

local function kazham_seconds_until_available(now)
    local phase=M.vana_day(now)%3;
    if phase==0 then return 0; end
    local remaining=M.seconds_until_change(now);
    if phase==1 then
        remaining=remaining+(VANA_DAY_SECONDS/SPEED);
    end
    return math.ceil(remaining);
end

local CANONICAL_REWARD_NAMES = {
    {"eastern san d'oria gate glyph", "Eastern San d'Oria Gate Glyph"},
    {"western san d'oria gate glyph", "Western San d'Oria Gate Glyph"},
    {"northern san d'oria gate glyph", "Northern San d'Oria Gate Glyph"},
    {"bastok mines gate glyph", "Bastok Mines Gate Glyph"},
    {"bastok markets gate glyph", "Bastok Markets Gate Glyph"},
    {"port bastok gate glyph", "Port Bastok Gate Glyph"},
    {"windurst waters gate glyph", "Windurst Waters Gate Glyph"},
    {"port windurst gate glyph", "Port Windurst Gate Glyph"},
    {"windurst woods gate glyph", "Windurst Woods Gate Glyph"},
    {"page from miratete's memoirs", "Page from Miratete's Memoirs"},
    {"page from the dragon chronicles", "Page from the Dragon Chronicles"},
    {"chocobo ticket", "Chocobo Ticket"},
    {"gysahl greens", "Gysahl Greens"},
};

local function clean_reward_name(value)
    local s=tostring(value or '');
    -- Strip packet/control bytes and common quantity/control suffix debris from
    -- item-obtained chat before persisting a reward label.
    s=s:gsub('[%z\1-\31\127]','');
    s=s:gsub('^%s+',''):gsub('%s+$','');

    local lower=string.lower(s);
    for _,entry in ipairs(CANONICAL_REWARD_NAMES) do
        if lower:find(entry[1],1,true) then return entry[2]; end
    end

    -- Generic cleanup for unknown rewards: an item name may be followed by
    -- packet-rendered quantity markers such as punctuation/x1 garbage.
    s=s:gsub('%s+[%p]*[xX]?%d+%s*$','');
    s=s:gsub('%s+[%?%!#%$%%&%*%+%-%./:;<=>@%^_`|~]+%s*$','');
    return s:gsub('^%s+',''):gsub('%s+$','');
end

local function normalize_saved_rewards(c,a)
    local changed=false;
    local function fix(t,k)
        if type(t)~='table' or t[k]==nil then return; end
        local old=tostring(t[k]);
        local new=clean_reward_name(old);
        if new~='' and new~=old then t[k]=new; changed=true; end
    end

    fix(a,'last_reward');
    for _,h in ipairs(type(a.history)=='table' and a.history or {}) do fix(h,'reward'); end
    for _,rec in pairs(type(a.route_records)=='table' and a.route_records or {}) do
        if type(rec)=='table' then
            fix(rec,'last_reward');
            for _,o in ipairs(type(rec.observations)=='table' and rec.observations or {}) do fix(o,'reward'); end
        end
    end
    if type(c.dragon_weekly)=='table' then fix(c.dragon_weekly,'dc_chocobo_reward'); end
    return changed;
end

local function ensure_activity(c)
    c.chocobo_riding=type(c.chocobo_riding)=='table' and c.chocobo_riding or {};
    local a=c.chocobo_riding;
    a.route_records=type(a.route_records)=='table' and a.route_records or {};
    a.history=type(a.history)=='table' and a.history or {};

    local wk=HC.modules.core.weekly_key();
    if a.postcheck_weekly_key~=wk then
        a.postcheck_weekly_key=wk;
        a.postcheck_npcs={};
        a.postcheck_verified_at=nil;
    end
    a.postcheck_npcs=type(a.postcheck_npcs)=='table' and a.postcheck_npcs or {};
    return a;
end

local function route_key(city,npc,destination)
    return string.lower(
        tostring(city or '?')..'|'..
        tostring(npc or '?')..'|'..
        tostring(destination or '?')
    );
end

local function fmt_seconds(sec)
    sec=math.max(0,math.floor(tonumber(sec) or 0));
    return string.format('%d:%02d',math.floor(sec/60),sec%60);
end

local function get_route_record(a,key)
    a.route_records=type(a.route_records)=='table' and a.route_records or {};
    local r=a.route_records[key];
    if type(r)~='table' then
        r={ runs=0, observations={} };
        a.route_records[key]=r;
    end
    r.observations=type(r.observations)=='table' and r.observations or {};
    return r;
end

-- Riding Game records remain stored under the character that actually made the
-- run, but statistics are read account-wide from the shared HorizonCheck state
-- file. This preserves character provenance while making PBs, run counts,
-- reward observations, and history immediately visible from every character.
local function account_characters()
    local root=(HC.modules.state.raw and HC.modules.state.raw()) or {};
    return type(root.chars)=='table' and root.chars or {};
end

local function account_route_record(key)
    local out={ runs=0, observations={} };
    local latest_at=-1;

    for character,cc in pairs(account_characters()) do
        local a=type(cc)=='table' and cc.chocobo_riding or nil;
        local rec=type(a)=='table' and type(a.route_records)=='table' and a.route_records[key] or nil;
        if type(rec)=='table' then
            out.runs=out.runs+(tonumber(rec.runs) or 0);

            local best=tonumber(rec.best_seconds);
            if best and (not tonumber(out.best_seconds) or best<tonumber(out.best_seconds)) then
                out.best_seconds=best;
                out.best_time=rec.best_time or fmt_seconds(best);
                out.best_at=rec.best_at;
                out.best_character=tostring(character);
            end

            for _,obs in ipairs(type(rec.observations)=='table' and rec.observations or {}) do
                if type(obs)=='table' then
                    out.observations[#out.observations+1]={
                        seconds=tonumber(obs.seconds),
                        time=obs.time,
                        reward=obs.reward,
                        at=tonumber(obs.at) or 0,
                        character=tostring(character),
                    };
                    local oat=tonumber(obs.at) or 0;
                    if oat>latest_at then
                        latest_at=oat;
                        out.last_reward=obs.reward or rec.last_reward;
                        out.last_time=obs.time or rec.last_time;
                        out.last_character=tostring(character);
                    end
                end
            end

            -- Older saved records may have a last result but no observations.
            local rat=tonumber(rec.last_completed_at) or tonumber(rec.best_at) or 0;
            if rec.last_reward and rat>latest_at then
                latest_at=rat;
                out.last_reward=rec.last_reward;
                out.last_time=rec.last_time;
                out.last_character=tostring(character);
            end
        end
    end

    table.sort(out.observations,function(x,y)
        local xa=tonumber(x.at) or 0; local ya=tonumber(y.at) or 0;
        if xa~=ya then return xa>ya; end
        return tostring(x.character or '')<tostring(y.character or '');
    end);
    return out;
end

local function account_history()
    local out={};
    for character,cc in pairs(account_characters()) do
        local a=type(cc)=='table' and cc.chocobo_riding or nil;
        for _,h in ipairs(type(a)=='table' and type(a.history)=='table' and a.history or {}) do
            if type(h)=='table' then
                out[#out+1]={
                    route_key=h.route_key, city=h.city, npc=h.npc, destination=h.destination,
                    completed_at=tonumber(h.completed_at) or 0, seconds=tonumber(h.seconds),
                    time=h.time, reward=h.reward, character=tostring(h.character or character),
                };
            end
        end
    end
    table.sort(out,function(x,y)
        local xa=tonumber(x.completed_at) or 0; local ya=tonumber(y.completed_at) or 0;
        if xa~=ya then return xa>ya; end
        return tostring(x.character or '')<tostring(y.character or '');
    end);
    return out;
end

local function trim_history(a)
    while #a.history>20 do table.remove(a.history); end
end

local function add_run_record(a)
    local key=a.active_route_key or route_key(a.started_city,a.started_npc,a.destination);
    local rec=get_route_record(a,key);
    rec.city=a.started_city;
    rec.npc=a.started_npc;
    rec.destination=a.destination;
    rec.runs=(tonumber(rec.runs) or 0)+1;
    rec.last_completed_at=tonumber(a.completed_at) or os.time();

    local entry={
        route_key=key,
        city=a.started_city,
        npc=a.started_npc,
        destination=a.destination,
        completed_at=tonumber(a.completed_at) or os.time(),
        seconds=tonumber(a.last_run_seconds),
        time=a.last_run_time,
        reward=nil,
        character=(HC.modules.state.profile_name and HC.modules.state.profile_name()) or nil,
    };
    table.insert(a.history,1,entry);
    trim_history(a);
    a.last_history_index=1;

    if entry.seconds and (not tonumber(rec.best_seconds) or entry.seconds<tonumber(rec.best_seconds)) then
        rec.best_seconds=entry.seconds;
        rec.best_time=entry.time or fmt_seconds(entry.seconds);
        rec.best_at=entry.completed_at;
    end
end

local function update_latest_run_metrics(a)
    local entry=a.history and a.history[1] or nil;
    if type(entry)~='table' then return; end
    if tonumber(a.last_run_seconds) then
        entry.seconds=tonumber(a.last_run_seconds);
        entry.time=a.last_run_time or fmt_seconds(entry.seconds);
        local rec=get_route_record(a,entry.route_key or route_key(entry.city,entry.npc,entry.destination));
        if not tonumber(rec.best_seconds) or entry.seconds<tonumber(rec.best_seconds) then
            rec.best_seconds=entry.seconds;
            rec.best_time=entry.time;
            rec.best_at=entry.completed_at or os.time();
        end
    end
end

local function update_latest_reward(a,reward)
    local entry=a.history and a.history[1] or nil;
    if type(entry)~='table' then return; end
    entry.reward=reward;

    local rec=get_route_record(a,entry.route_key or route_key(entry.city,entry.npc,entry.destination));
    local obs=rec.observations;
    table.insert(obs,1,{
        seconds=tonumber(entry.seconds),
        time=entry.time,
        reward=reward,
        at=entry.completed_at or os.time(),
    });
    while #obs>12 do table.remove(obs); end
    rec.last_reward=reward;
    rec.last_time=entry.time;
end

local function reconcile_activity(c)
    local a=ensure_activity(c);
    local now=os.time();
    if normalize_saved_rewards(c,a) then HC.modules.state.save(); end

    -- v6.1.14/v6.1.15 recovery: if the destination NPC already reported an
    -- Earth-time result, the ride reached the destination successfully.
    if a.active==true and a.last_run_time and not a.completed_at then
        a.active=false;
        a.arrived=true;
        a.state='COMPLETE';
        a.completed_at=tonumber(a.last_run_time_at) or now;
        a.completion_source='Recovered from captured destination completion time';
        c.weekly=type(c.weekly)=='table' and c.weekly or {};
        c.weekly.chocobo_game=true;
        HC.modules.state.save();
        return a;
    end

    -- Abandoned/disconnected rides should not remain IN PROGRESS forever.
    local accepted=tonumber(a.accepted_at);
    if a.active==true and accepted and now-accepted>5400 then
        a.active=false;
        a.arrived=false;
        a.state='READY';
        a.expired_at=now;
        a.expire_reason='Ride state expired after 90 minutes without delivery confirmation';
        HC.modules.state.save();
    end

    return a;
end

local function verify_postcomplete_npc(c,a,npc)
    a.postcheck_npcs=type(a.postcheck_npcs)=='table' and a.postcheck_npcs or {};
    if a.postcheck_npcs[npc]~=true then
        a.postcheck_npcs[npc]=true;
        a.postcheck_last_at=os.time();
        HC.modules.state.save();
    end

    local all=a.postcheck_npcs.camereine==true
        and a.postcheck_npcs.emoussine==true
        and a.postcheck_npcs.meuneille==true;

    if not all then return false; end

    a.active=false;
    a.arrived=true;
    a.state='COMPLETE';
    a.completed_at=a.completed_at or os.time();
    a.completion_source='Verified by all three stable NPC post-completion rental dialogues';
    a.postcheck_verified_at=os.time();

    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    c.weekly.chocobo_game=true;

    -- A completed Riding Game necessarily paid a Riding Game reward, even when
    -- HorizonCheck was loaded afterward and cannot know which exact item it was.
    c.dragon_weekly=type(c.dragon_weekly)=='table' and c.dragon_weekly or {};
    c.dragon_weekly.dc_chocobo=true;
    if not c.dragon_weekly.dc_chocobo_reward then
        c.dragon_weekly.dc_chocobo_reward='Previously completed - reward not observed';
    end

    HC.modules.state.save();
    HC.msg('AUTO: Chocobo Riding Game complete [VERIFIED BY CAMEREINE + EMOUSSINE + MEUNEILLE].');
    return true;
end

local function complete_run(c, source)
    local a=ensure_activity(c);
    if a.completed_at and os.time()-(tonumber(a.completed_at) or 0)<30 then return; end

    a.active=false;
    a.arrived=true;
    a.state='COMPLETE';
    a.completed_at=os.time();
    a.completion_source=source or 'Destination stable delivery confirmation';

    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    c.weekly.chocobo_game=true;

    add_run_record(a);
    HC.modules.state.save();
    HC.msg('AUTO: Chocobo Riding Game complete [VERIFIED BY DESTINATION DELIVERY].');
end

local function on_text(s)
    local c=HC.modules.state.get_char();
    local a=ensure_activity(c);
    local raw=tostring(s or '');
    local lower=string.lower(raw);
    local now=os.time();

    -- Capture-verified post-completion reconciliation.
    -- After the weekly Riding Game has been completed, all three game NPCs
    -- fall back to the same ordinary 100-gil rental dialogue. Require all
    -- three named NPCs during the same weekly key before reconciling COMPLETE.
    if lower:find('you can rent a chocobo for 100 gil',1,true)
        and lower:find('i see you currently have',1,true)
    then
        local npc=nil;
        if lower:find('camereine%s*:',1,false) then npc='camereine';
        elseif lower:find('emoussine%s*:',1,false) then npc='emoussine';
        elseif lower:find('meuneille%s*:',1,false) then npc='meuneille';
        end

        if npc then
            verify_postcomplete_npc(c,a,npc);
            return;
        end
    end

    -- Capture-verified acceptance:
    -- "Oh, thank you so very much! You shall be rewarded by our associates upon delivery of the chocobo."
    if lower:find('oh, thank you so very much!',1,true)
        and lower:find('rewarded by our associates upon delivery of the chocobo',1,true)
    then
        local r=M.current();
        a.active=true;
        a.arrived=false;
        a.state='IN PROGRESS';
        a.accepted_at=now;
        a.started_city=r.city;
        a.started_npc=r.npc;
        a.destination=r.destination;
        a.active_route_key=route_key(r.city,r.npc,r.destination);
        a.reward=r.reward;
        a.arrival_at=nil;
        a.completed_at=nil;
        a.completion_source=nil;
        a.last_run_seconds=nil;
        a.last_run_time=nil;
        a.last_run_time_at=nil;
        a.last_reward=nil;
        a.last_reward_at=nil;
        HC.modules.state.save();
        HC.msg('AUTO: Chocobo Riding Game accepted - IN PROGRESS ['..
            tostring(r.npc)..' -> '..tostring(r.destination)..'].');
        return;
    end

    -- Capture-verified in-route elapsed-time calibration.
    -- HorizonXI prints an authoritative Earth-time elapsed value after zoning
    -- during a Riding Game run.  The acceptance acknowledgement arrives a few
    -- seconds after the server actually starts the run, so calibrate accepted_at
    -- from this server-reported value to keep the live timer accurate across zones.
    if a.active==true
        and lower:find('time elapsed:',1,true)
        and lower:find("(vana'diel time)",1,true)
        and lower:find('(earth time)',1,true)
    then
        local mins,secs=lower:match('(%d+)%s+minutes?%s+and%s+(%d+)%s+seconds?%s+%(earth time%)');
        if mins and secs then
            local elapsed=(tonumber(mins)*60)+tonumber(secs);
            a.server_elapsed_seconds=elapsed;
            a.server_elapsed_at=now;
            a.accepted_at=now-elapsed;
            HC.modules.state.save();
        end
    end

    -- Capture-verified completion-time dialogue.
    if (a.active==true or (a.state=='COMPLETE' and tonumber(a.completed_at) and now-tonumber(a.completed_at)<=120))
        and lower:find('earth time',1,true)
        and lower:find('made it here in a mere',1,true)
    then
        local mins,secs=lower:match('%((%d+)%s+minutes?%s+and%s+(%d+)%s+seconds?%s+earth time%)');
        if mins and secs then
            a.last_run_seconds=(tonumber(mins)*60)+tonumber(secs);
            a.last_run_time=string.format('%d:%02d',tonumber(mins),tonumber(secs));
            a.last_run_time_at=now;
            update_latest_run_metrics(a);
            HC.modules.state.save();
        end
    end

    -- Destination delivery is authoritative completion. Reward quality varies
    -- by route and time, so no specific reward item is required.
    if a.active==true
        and lower:find("you've helped our poor girl find her way home!",1,true)
    then
        a.arrived=true;
        a.arrival_at=now;
        complete_run(c,'Destination stable delivery confirmation');
        return;
    end

    -- Record the item awarded immediately after a verified completion.
    -- This is informational only and does not determine ride completion.
    if a.state=='COMPLETE'
        and tonumber(a.completed_at)
        and now-tonumber(a.completed_at)<=120
        and lower:find('obtained:',1,true)
    then
        -- Parse from the original chat text so reward casing is preserved.
        -- Prefer stopping at the sentence-ending period; this prevents FFXI's
        -- trailing item/quantity formatting bytes from becoming part of the name.
        local reward=raw:match('[Oo][Bb][Tt][Aa][Ii][Nn][Ee][Dd]:%s*(.-)%s*%.')
            or raw:match('[Oo][Bb][Tt][Aa][Ii][Nn][Ee][Dd]:%s*(.-)%s*$');
        reward=clean_reward_name(reward);
        if reward and reward~='' then
            a.last_reward=reward;
            a.last_reward_at=now;
            update_latest_reward(a,reward);

            c.dragon_weekly=type(c.dragon_weekly)=='table' and c.dragon_weekly or {};
            c.dragon_weekly.dc_chocobo=true;
            c.dragon_weekly.dc_chocobo_reward=reward;
            c.dragon_weekly.dc_chocobo_time=a.last_run_time;
            c.dragon_weekly.dc_chocobo_reward_at=now;

            HC.modules.state.save();
            HC.msg('AUTO: Chocobo Riding Game reward source complete ['..
                tostring(reward)..(a.last_run_time and (' | '..tostring(a.last_run_time)) or '')..'].');
        end
        return;
    end
end

function M.status(c)
    local a=reconcile_activity(c);
    if a.active==true then
        local elapsed=tonumber(a.accepted_at) and math.max(0,os.time()-tonumber(a.accepted_at)) or 0;
        local rec=account_route_record(a.active_route_key or route_key(a.started_city,a.started_npc,a.destination));
        local pb=rec.best_time and (' | PB '..tostring(rec.best_time)..(rec.best_character and (' - '..tostring(rec.best_character)) or '')) or '';
        return string.format('IN PROGRESS | %s -> %s | Elapsed %s%s',
            tostring(a.started_npc or '?'),tostring(a.destination or '?'),fmt_seconds(elapsed),pb);
    elseif a.state=='COMPLETE' and c.weekly and c.weekly.chocobo_game==true then
        if a.postcheck_verified_at then
            return 'COMPLETE | Confirmed after the follow-up checks';
        end
        local extra='';
        if a.last_run_time then extra=extra..' | Last: '..tostring(a.last_run_time); end
        if a.last_reward then extra=extra..' | Reward: '..tostring(a.last_reward); end
        return 'COMPLETE | Confirmed'..extra;
    end

    local r=M.current();
    local confidence=r.route_verified and 'Known route' or (r.source_reference and 'Wiki route' or 'Likely route');
    local rec=account_route_record(route_key(r.city,r.npc,r.destination));
    local pb=rec.best_time and (' | PB '..tostring(rec.best_time)..(rec.best_character and (' - '..tostring(rec.best_character)) or '')) or '';
    if r.city_key=='kazham' and r.available~=true then
        return string.format('WAIT | %s -> %s | %s | Next offer phase in %s%s',
            r.npc,
            r.destination,
            confidence,
            HC.modules.core.format_duration(kazham_seconds_until_available()),
            pb
        );
    end
    return string.format('READY | %s -> %s | %s | Target <=%s%s',
        r.npc,
        r.destination,
        confidence,
        r.cutoff,
        pb
    );
end

local function draw_kv_rows(imgui,id,rows,label_header,value_header)
    local flags=HC.modules.uikit.table_flags();
    if imgui.BeginTable and imgui.TableNextColumn and imgui.EndTable then
        if imgui.BeginTable('##chocobo_rows_'..tostring(id),2,flags) then
            if imgui.TableSetupColumn then
                imgui.TableSetupColumn(tostring(label_header or 'Detail'),0,0.26);
                imgui.TableSetupColumn(tostring(value_header or 'Value'),0,0.74);
            end
            if imgui.TableHeadersRow then imgui.TableHeadersRow(); end
            for _,row in ipairs(rows or {}) do
                if imgui.TableNextRow then imgui.TableNextRow(); end
                if imgui.TableSetColumnIndex then imgui.TableSetColumnIndex(0); else imgui.TableNextColumn(); end
                imgui.Text(tostring(row.label or ''));
                if imgui.TableSetColumnIndex then imgui.TableSetColumnIndex(1); else imgui.TableNextColumn(); end
                if row.strong==true then imgui.Text(tostring(row.value or '')); else imgui.TextDisabled(tostring(row.value or '')); end
            end
            imgui.EndTable();
            return true;
        end
    end

    for _,row in ipairs(rows or {}) do
        local line=tostring(row.label or '')..' '..tostring(row.value or '');
        if row.strong==true then imgui.Text(line); else imgui.TextDisabled(line); end
    end
    return false;
end

local function draw_list_rows(imgui,id,rows,column_header)
    local flags=HC.modules.uikit.table_flags();
    if imgui.BeginTable and imgui.TableNextColumn and imgui.EndTable then
        if imgui.BeginTable('##chocobo_list_'..tostring(id),1,flags) then
            if imgui.TableSetupColumn then imgui.TableSetupColumn(tostring(column_header or 'Details'),0,1.0); end
            if imgui.TableHeadersRow then imgui.TableHeadersRow(); end
            for _,value in ipairs(rows or {}) do
                if imgui.TableNextRow then imgui.TableNextRow(); end
                if imgui.TableSetColumnIndex then imgui.TableSetColumnIndex(0); else imgui.TableNextColumn(); end
                imgui.TextDisabled(tostring(value or ''));
            end
            imgui.EndTable();
            return true;
        end
    end
    for _,value in ipairs(rows or {}) do imgui.TextDisabled(tostring(value or '')); end
    return false;
end

local function section_gap(imgui)
    imgui.Spacing();
end

local function draw_route_detail(imgui, city_key, developer)
    local r=M.current(nil,city_key);
    local rec=account_route_record(route_key(r.city,r.npc,r.destination));

    section_gap(imgui);
    local header=tostring(r.city)..' - '..tostring(r.zone)..' ('..tostring(r.pos)..')';
    if city_key=='kazham' then header='Kazham ('..tostring(r.pos)..')'; end
    HC.modules.uikit.section_header(header);

    local personal_best=tostring(rec.best_time or '--:--');
    if rec.best_character then personal_best=personal_best..' - '..tostring(rec.best_character); end
    personal_best=personal_best..'  |  Completed runs: '..tostring(rec.runs or 0);
    local rows={
        { label=(city_key=='kazham' and 'Quest NPC:' or 'Current NPC:'), value=r.npc, strong=true },
        { label='Destination:', value=r.destination },
        { label='Best reward target:', value=r.reward..'  |  Target: <= '..r.cutoff },
        { label='Personal best:', value=personal_best },
    };

    if rec.last_reward then
        rows[#rows+1]={
            label='Latest observed:',
            value=tostring(rec.last_time or '--:--')..' - '..tostring(rec.last_character or '?')..' -> '..tostring(rec.last_reward),
        };
    end

    if city_key=='kazham' then
        local wait=kazham_seconds_until_available();
        if r.available then
            rows[#rows+1]={
                label='Availability:',
                value='AVAILABLE NOW - same schedule as Bastok Mines -> Windurst Woods',
                strong=true,
            };
        else
            rows[#rows+1]={
                label='Availability:',
                value='Same schedule as Bastok Mines -> Windurst Woods  |  Next offer phase in '..HC.modules.core.format_duration(wait),
            };
        end
    else
        if r.gear_needed then
            rows[#rows+1]={
                label='Riding-time gear:',
                value='REQUIRED - minimum +'..tostring(r.min_bonus)..' min',
                strong=true,
            };
        else
            rows[#rows+1]={
                label='Riding-time gear:',
                value='NOT REQUIRED for best-reward cutoff',
            };
        end

        rows[#rows+1]={
            label='Next:',
            value=r.next_npc..' -> '..r.next_destination..' in '..HC.modules.core.format_duration(r.remaining),
        };
    end

    if developer==true then
        rows[#rows+1]={
            label='NPC/route phase:',
            value=r.route_verified and 'CAPTURE VERIFIED'
                or (r.source_reference and 'SOURCE REFERENCE - NEEDS HORIZON CAPTURE')
                or 'PREDICTED - NEEDS CAPTURE VALIDATION',
            strong=(r.route_verified~=true),
        };
    end

    draw_kv_rows(imgui,'city_'..tostring(city_key),rows,'Detail','Value');
end

function M.draw(c)
    if not HC.imgui then return; end
    local imgui=HC.imgui;
    local zid=get_zone_id();
    local key=city_key_from_zone(zid);
    local activity=reconcile_activity(c);

    local status='[READY]';
    if activity.active==true then
        status='[IN PROGRESS]';
    elseif activity.state=='COMPLETE' and c.weekly and c.weekly.chocobo_game==true then
        status='[COMPLETE]';
    elseif key=='kazham' and M.current(nil,'kazham').available~=true then
        status='[WAIT]';
    end
    local developer=(type(c.settings)=='table' and c.settings.developer_mode==true);
    HC.modules.uikit.section_header_action('Chocobo Riding Game','Progress Tracking '..status,function()
        if developer and HC.modules.learning and HC.modules.learning.capture_button then
            HC.modules.learning.capture_button('chocobo','chocobo_predictor');
        end
    end);

    if activity.active==true then
        local elapsed=tonumber(activity.accepted_at) and math.max(0,os.time()-tonumber(activity.accepted_at)) or 0;
        local rec=account_route_record(activity.active_route_key or route_key(activity.started_city,activity.started_npc,activity.destination));
        imgui.TextDisabled('Progress: request accepted -> deliver the lost chocobo to the destination stable.');
        imgui.TextDisabled('Active route: '..tostring(activity.started_npc or '?')..' -> '..tostring(activity.destination or '?'));
        local pb=tostring(rec.best_time or '--:--');
        if rec.best_character then pb=pb..' - '..tostring(rec.best_character); end
        imgui.TextDisabled('Live elapsed: '..fmt_seconds(elapsed)..' Earth time  |  Personal best: '..pb);
    elseif activity.state=='COMPLETE' and c.weekly and c.weekly.chocobo_game==true then
        if activity.postcheck_verified_at then
            imgui.TextDisabled('Weekly completion was confirmed after the follow-up stable checks.');
        else
            imgui.TextDisabled('Progress: delivery confirmed -> weekly Riding Game complete.');
        end
        if activity.last_run_time then imgui.TextDisabled('Last run time: '..tostring(activity.last_run_time)..' Earth time'); end
        if activity.last_reward then imgui.TextDisabled('Last reward: '..tostring(activity.last_reward)); end
    else
        local seen=0;
        for _,npc in ipairs({'camereine','emoussine','meuneille'}) do
            if activity.postcheck_npcs and activity.postcheck_npcs[npc]==true then seen=seen+1; end
        end
        if seen>0 then
            imgui.TextDisabled('Post-completion verification: '..tostring(seen)..'/3 stable NPCs confirmed.');
        else
            imgui.TextDisabled('Progress: talk to the active Riding Game NPC and accept the lost-chocobo delivery.');
        end
    end

    if key then
        imgui.TextDisabled('Detected stable city from current zone.');
        draw_route_detail(imgui,key,developer);
    else
        imgui.TextDisabled('Not currently in a supported city stable zone - showing all four.');
        draw_route_detail(imgui,'bastok',developer);
        draw_route_detail(imgui,'sandoria',developer);
        draw_route_detail(imgui,'windurst',developer);
        draw_route_detail(imgui,'kazham',developer);
    end

    section_gap(imgui);
    HC.modules.uikit.section_header('Run History / Reward Learning');
    imgui.TextDisabled('HorizonCheck combines completed runs from every character in this account state, while keeping the character name on each run.');
    imgui.TextDisabled('These observations are used as evidence only; unknown reward thresholds are not guessed.');

    local history=account_history();
    if #history==0 then
        imgui.TextDisabled('No completed rides recorded yet.');
    else
        local history_rows={};
        for i=1,math.min(5,#history) do
            local h=history[i];
            history_rows[#history_rows+1]={
                label=tostring(i)..'. '..tostring(h.npc or '?')..' -> '..tostring(h.destination or '?'),
                value=tostring(h.time or '--:--')..'  |  '..tostring(h.character or '?')..'  |  '..tostring(h.reward or 'reward not captured'),
            };
        end
        draw_kv_rows(imgui,'history',history_rows,'Route','Observed Result');
    end

    local current=M.current();
    local current_rec=account_route_record(route_key(current.city,current.npc,current.destination));
    if #current_rec.observations>0 then
        section_gap(imgui);
        HC.modules.uikit.section_header('Observed Results for Current Route');
        local observed={};
        for i=1,math.min(5,#current_rec.observations) do
            local o=current_rec.observations[i];
            observed[#observed+1]=tostring(o.time or '--:--')..' - '..tostring(o.character or '?')..' -> '..tostring(o.reward or '?');
        end
        draw_list_rows(imgui,'observed',observed,'Observed Result');
    end

    section_gap(imgui);
    HC.modules.uikit.section_header('Possible Rewards','Vary by route and completion time');
    draw_list_rows(imgui,'rewards',{
        '- Page from the Dragon Chronicles',
        "- Page from Miratete's Memoirs",
        '- Chocobo Ticket',
        '- Gysahl Greens',
        '- Other lower-tier route/time-dependent rewards may occur.',
    },'Reward Notes');
    imgui.TextDisabled('Reward tier does not determine completion; successful delivery completes the weekly activity.');

    section_gap(imgui);
    HC.modules.uikit.section_header('Riding Time Reference');
    draw_kv_rows(imgui,'riding_time',{
        { label='Base rented chocobo:', value='30:00' },
        { label='Riding-time gear:', value='Body +5  |  Legs +4  |  Hands +3  |  Feet +3  |  Full set +15 min' },
    },'Reference','Value');
end

function M.init(ctx)
    HC=ctx;
    HC.modules.packets.register_text('chocobo riding game',on_text);
    local ok,c=pcall(function() return HC.modules.state.get_char(); end);
    if ok and c then reconcile_activity(c); end
end

return M;
