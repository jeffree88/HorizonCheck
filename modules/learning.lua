local M = {};
local HC;

local function user_file(kind,name)
    if HC and HC.modules and HC.modules.userdata and HC.modules.userdata.path then
        local ok,res=pcall(HC.modules.userdata.path,kind,name);
        if ok and type(res)=='string' and res~='' then return res; end
    end
    return tostring(HC and HC.addon_path or '')..tostring(name or '');
end


local PROFILES = {
    assault = { seconds = 0, manual_stop = true, desc = 'Assault full run: entry, objective progress, completion/failure, exit, and AP reward. Manual stop only.' },
    limbus = { seconds = 300, desc = 'Limbus preparation and entry: Cosmo-Cleanse acquisition/consumption, Temenos/Apollyon zone entry, and weekly lockout evidence.' },
    dynamis = { seconds = 180, desc = 'Dynamis entry only: capture the zone transition that consumes/increments the weekly Dynamis lockout.' },
    eco = { seconds = 180, desc = 'Eco-Warrior NPC/quest/reward interaction.' },
    guild = { seconds = 120, desc = 'Guild Union NPC menu and Guild Point update.' },
    enm = { seconds = 1200, desc = 'ENM full attempt: battlefield entry, battle, completion/failure, reward, and cooldown evidence. 20-minute capture window.' },
    dragon = { seconds = 180, desc = 'Dragon Chronicles / Miratete reward interaction.' },
    highwind = { seconds = 180, desc = 'Highwind monster engagement and kill behavior.' },
    haap = { seconds = 120, desc = 'HAAP.I point balance, reward claim, and post-purchase refresh.' },
    chocobo = { seconds = 0, manual_stop = true, desc = 'Chocobo Riding Game full attempt: pickup, ride, zone transitions, finish time, and reward. Manual stop only.' },
    anniversary = { seconds = 0, manual_stop = true, desc = 'Anniversary quest-guide evidence: capture NPC riddle, counter, turn-in, assignment, and completion dialogue while testing Anniversary automation. Manual stop only.' },
    daily_avatar = { seconds = 0, manual_stop = true, desc = 'Daily Avatar Fight evidence: capture tuning-fork/key-item state, avatar battlefield interaction, completion, and post-fight reset behavior. Manual stop only.' },
    blackcoffin = { seconds = 180, desc = 'Black Coffin rotation quest pickup, progress, and completion interaction.' },
    outposts = { seconds = 180, desc = 'Outpost Teleporter / Conquest Overseer menu for learning completed Supply Run ownership.' },
    tags = { seconds = 150, desc = 'Rytaal Assault Tag menu/count interaction. Use /hcheck learn known <0-4> after checking your known stored-tag count.' },
    uninvited = { seconds = 0, manual_stop = true, desc = 'Uninvited Guests: manually capture entry, completion/reward, or weekly lockout evidence. Stop when the interaction/run segment is finished.' },
    requiem = { seconds = 0, manual_stop = true, desc = "Requiem of Sin: capture weekly key-item acquisition/consumption, Boneyard Gully battlefield clear, and reward evidence. Stop when finished." },
    exp_ring = { seconds = 0, manual_stop = true, desc = 'EXP Ring: manually capture recharge/replacement NPC interaction, charge update, and weekly eligibility evidence. Stop when finished.' },
    isnm = { seconds = 0, manual_stop = true, desc = 'ISNM Order / Run: manually capture Shajaf order purchase, eligibility/lockout dialogue, battlefield entry, or completion evidence. Stop when finished.' },
    pots = { seconds = 0, manual_stop = true, desc = 'Mog House plant pots: inspect one or more planted flowerpots, then stop after all related messages/packets finish.' },
    questmenu = { seconds = 0, manual_stop = true, desc = 'Native Quest menu: open Quests and browse several regions/categories, including active and completed entries, then stop manually.' },
    questverify = { seconds = 0, manual_stop = true, desc = 'Guided quest verification: capture one NPC interaction with before/after native quest state, dialogue, 0x056 packets, and key-item differences.' },
    fame = { seconds = 0, manual_stop = true, desc = 'Fame / reputation checker dialogue: start capture, speak to a listed fame NPC, then stop after the dialogue finishes.' },
    maat = { seconds = 0, manual_stop = true, desc = 'Maat progress discovery: speak to Maat in Ru\'Lude Gardens and complete his dialogue/menu. Captures full candidate server/menu payloads so per-job Shattering Stars clear tracking can be decoded.' },
    permkeyitems = { seconds = 0, manual_stop = true, desc = 'Permanent key-item discovery: directly snapshot HorizonCheck cached 0x055 ownership plus indexed HasKeyItem results at capture start and stop.' },
};

local capture = {
    active = false,
    target = nil,
    started_at = nil,
    ends_at = nil,
    zone_id = nil,
    packet_total = 0,
    text_total = 0,
    zone_total = 0,
    packet_counts = {},
    packet_samples = {},
    text_samples = {},
    text_tail = {},
    zone_samples = {},
    markers = {},
    phase = 'capture',
    phase_counts = {},
    log_path = nil,
    report_path = nil,
    tag_menu_packets = {},
    rytaal_text = {},
    known_tag_count = nil,
    known_tag_at = nil,
    permkey_start = nil,
    permkey_end = nil,
    recent_text_sigs = {},
};

local function sanitize(s)
    s = tostring(s or 'Unknown');
    s = string.gsub(s, '[^%w%._%-]', '_');
    if s == '' then s = 'Unknown'; end
    return s;
end

local function nowstamp(t)
    return os.date('%Y-%m-%d %H:%M:%S', t or os.time());
end

local function append_log(line)
    if not capture.log_path then return; end
    local f = io.open(capture.log_path, 'a');
    if not f then return; end
    f:write(tostring(line or '') .. '\n');
    f:close();
end

local function data_hex(data, maxbytes)
    if type(data) ~= 'string' then return nil; end
    local n = math.min(#data, tonumber(maxbytes) or 48);
    local out = {};
    for i = 1, n do out[#out + 1] = string.format('%02X', string.byte(data, i)); end
    return table.concat(out, ' ');
end

local function hex_bytes(hex)
    local out = {};
    for h in string.gmatch(tostring(hex or ''), '%x%x') do out[#out + 1] = tonumber(h, 16); end
    return out;
end

local function unique_packet_ids()
    local n = 0;
    for _ in pairs(capture.packet_counts) do n = n + 1; end
    return n;
end

local function sorted_counts(t)
    local rows = {};
    for id, count in pairs(t or {}) do rows[#rows + 1] = { id = id, count = count }; end
    table.sort(rows, function(a,b)
        if a.count == b.count then return a.id < b.id; end
        return a.count > b.count;
    end);
    return rows;
end

local function reset_runtime()
    capture.active = false;
    capture.target = nil;
    capture.started_at = nil;
    capture.ends_at = nil;
    capture.zone_id = nil;
    capture.packet_total = 0;
    capture.text_total = 0;
    capture.zone_total = 0;
    capture.packet_counts = {};
    capture.packet_samples = {};
    capture.text_samples = {};
    capture.text_tail = {};
    capture.zone_samples = {};
    capture.markers = {};
    capture.phase = 'capture';
    capture.phase_counts = {};
    capture.log_path = nil;
    capture.report_path = nil;
    capture.tag_menu_packets = {};
    capture.rytaal_text = {};
    capture.known_tag_count = nil;
    capture.known_tag_at = nil;
    capture.permkey_start = nil;
    capture.permkey_end = nil;
    capture.recent_text_sigs = {};
end

local function ensure_tag_learning(c)
    c.tag_learning = type(c.tag_learning) == 'table' and c.tag_learning or {};
    c.tag_learning.observations = type(c.tag_learning.observations) == 'table' and c.tag_learning.observations or {};
    return c.tag_learning;
end

local function distinct_known_counts(obs)
    local seen = {};
    for _,o in ipairs(obs or {}) do
        local n = tonumber(o.known_count);
        if n ~= nil then seen[n] = true; end
    end
    local rows = {};
    for n in pairs(seen) do rows[#rows + 1] = n; end
    table.sort(rows);
    return rows;
end

local function candidate_offsets(obs)
    local bysize = {};
    for _,o in ipairs(obs or {}) do
        local count = tonumber(o.known_count);
        local size = tonumber(o.size);
        if count ~= nil and size and o.hex then
            bysize[size] = bysize[size] or {};
            bysize[size][#bysize[size] + 1] = o;
        end
    end

    local result = {};
    for size, rows in pairs(bysize) do
        local counts = distinct_known_counts(rows);
        if #counts >= 2 then
            local parsed = {};
            local minlen = nil;
            for i,o in ipairs(rows) do
                parsed[i] = hex_bytes(o.hex);
                minlen = minlen and math.min(minlen, #parsed[i]) or #parsed[i];
            end
            for pos = 1, (minlen or 0) do
                local values = {};
                local valid = true;
                for i,o in ipairs(rows) do
                    local cnt = tonumber(o.known_count);
                    local val = parsed[i][pos];
                    if values[cnt] == nil then values[cnt] = val;
                    elseif values[cnt] ~= val then valid = false; break; end
                end
                if valid then
                    local unique = {};
                    local unique_n = 0;
                    for _,v in pairs(values) do if not unique[v] then unique[v] = true; unique_n = unique_n + 1; end end
                    if unique_n >= 2 then
                        local map = {};
                        local direct = true;
                        local inverse = true;
                        for _,cnt in ipairs(counts) do
                            local v = values[cnt];
                            map[#map + 1] = tostring(cnt) .. '=>' .. string.format('0x%02X', v or 0);
                            if v ~= cnt then direct = false; end
                            if v ~= (4 - cnt) then inverse = false; end
                        end
                        result[#result + 1] = {
                            size = size,
                            offset = pos - 1,
                            map = table.concat(map, ', '),
                            direct = direct,
                            inverse = inverse,
                            counts = #counts,
                            samples = #rows,
                        };
                    end
                end
            end
        end
    end
    table.sort(result, function(a,b)
        if a.direct ~= b.direct then return a.direct; end
        if a.inverse ~= b.inverse then return a.inverse; end
        if a.counts ~= b.counts then return a.counts > b.counts; end
        return a.offset < b.offset;
    end);
    return result;
end

local function write_tag_evidence(f)
    if capture.target ~= 'tags' then return; end
    local c = HC.modules.state.get_char();
    local tl = ensure_tag_learning(c);

    f:write('\nRYTAAL / ASSAULT TAG EVIDENCE\n');
    f:write('Candidate menu packet: 0x034 (captured only; not yet treated as a decoded tag-count field)\n');
    f:write('0x034 packets this capture: ' .. tostring(#capture.tag_menu_packets) .. '\n');
    f:write('Known stored-tag label this capture: ' .. tostring(capture.known_tag_count ~= nil and capture.known_tag_count or 'not supplied') .. '\n');
    f:write('Rytaal/tag text matches: ' .. tostring(#capture.rytaal_text) .. '\n');

    if #capture.tag_menu_packets == 0 then
        f:write('No 0x034 packets were captured.\n');
    else
        for i,p in ipairs(capture.tag_menu_packets) do
            f:write(string.format('MENU #%d  %s  size=%d  known=%s  phase=%s\n', i, nowstamp(p.at), tonumber(p.size) or 0, tostring(p.known_count ~= nil and p.known_count or '?'), tostring(p.phase or 'capture')));
            f:write('  ' .. tostring(p.hex or '') .. '\n');
        end
    end

    if #capture.rytaal_text > 0 then
        f:write('\nRYTAAL TEXT\n');
        for _,r in ipairs(capture.rytaal_text) do f:write(nowstamp(r.at) .. '  [' .. tostring(r.kind) .. ']  ' .. tostring(r.text) .. '\n'); end
    end

    local observations = tl.observations or {};
    local counts = distinct_known_counts(observations);
    f:write('\nPERSISTED KNOWN-COUNT OBSERVATIONS\n');
    f:write('Observations: ' .. tostring(#observations) .. ' | distinct known counts: ' .. tostring(#counts) .. '\n');
    if #counts > 0 then
        local labels = {}; for _,n in ipairs(counts) do labels[#labels + 1] = tostring(n); end
        f:write('Known counts represented: ' .. table.concat(labels, ', ') .. '\n');
    end

    local candidates = candidate_offsets(observations);
    f:write('\nCANDIDATE BYTE OFFSETS\n');
    if #counts < 2 then
        f:write('Need captures from at least two different KNOWN stored-tag counts before byte-offset comparison is meaningful.\n');
    elseif #candidates == 0 then
        f:write('No byte offset is yet stable within each known count while also changing across counts. More repeated samples are needed.\n');
    else
        f:write('Offsets are zero-based and include the packet header. Candidates require a stable value within each known count and a change across counts.\n');
        for i=1,math.min(#candidates,40) do
            local q = candidates[i];
            local hint = q.direct and ' [DIRECT count match]' or (q.inverse and ' [4-count match]' or '');
            f:write(string.format('size=%d offset=0x%02X  %s%s  samples=%d\n', q.size, q.offset, q.map, hint, q.samples));
        end
    end
end

local MAAT_JOB_NAMES={
    [1]='WAR',[2]='MNK',[3]='WHM',[4]='BLM',[5]='RDM',[6]='THF',[7]='PLD',[8]='DRK',[9]='BST',
    [10]='BRD',[11]='RNG',[12]='SAM',[13]='NIN',[14]='DRG',[15]='SMN',[16]='BLU',[17]='COR',[18]='PUP',
};

local function current_job_context()
    local jid=nil; local lvl=nil;
    pcall(function()
        local mm=AshitaCore and AshitaCore.GetMemoryManager and AshitaCore:GetMemoryManager() or nil;
        local p=mm and mm:GetPlayer() or nil;
        if not p then return; end
        if p.GetMainJob then jid=tonumber(p:GetMainJob()); elseif p.GetMainJobId then jid=tonumber(p:GetMainJobId()); end
        if p.GetMainJobLevel then lvl=tonumber(p:GetMainJobLevel()); end
    end);
    return MAAT_JOB_NAMES[jid],lvl,jid;
end

local function write_maat_evidence(f)
    if capture.target~='maat' then return; end
    local job,lvl,jid=current_job_context();
    local c=HC.modules.state.get_char();
    f:write('\nMAAT PROGRESS CONTEXT\n');
    f:write('Purpose: discover HorizonXI persistent per-job Shattering Stars / Maat victory evidence.\n');
    f:write('Current main job during report: '..tostring(job or 'unknown')..' (id='..tostring(jid or '?')..') Lv.'..tostring(lvl or '?')..'\n');
    f:write('Already confirmed by HorizonCheck before this capture:\n');
    local wins=type(c)=='table' and type(c.quest_maat_job_wins)=='table' and c.quest_maat_job_wins or {};
    local any=false;
    for i=1,15 do
        local ab=MAAT_JOB_NAMES[i];
        if wins[ab]==true then f:write('  '..ab..' = BEAT\n'); any=true; end
    end
    if not any then f:write('  (none)\n'); end
    f:write('Analysis note: compare full menu/dialogue payloads between characters/jobs with known cleared and uncleared Maat fights before assigning any bit field.\n');
end

local function write_permkey_snapshot(f, label, snap)
    f:write('\nPERMANENT KEY ITEM DIRECT SNAPSHOT - ' .. tostring(label or 'SNAPSHOT') .. '\n');
    if type(snap)~='table' then f:write('(snapshot unavailable)\n'); return; end
    f:write('Captured: ' .. nowstamp(snap.at) .. '\n');
    local ix=type(snap.resource_index)=='table' and snap.resource_index or {};
    f:write(string.format('Resource index: %d%% (%d/%d) | complete=%s\n', tonumber(ix.percent) or 0, tonumber(ix.done) or 0, tonumber(ix.total) or 0, ix.complete==true and 'YES' or 'NO'));
    local inds={}; for _,n in ipairs(snap.bitmap_indices or {}) do inds[#inds+1]=tostring(n); end
    f:write(string.format('Cached 0x055 tables: %d | indices: %s\n', tonumber(snap.bitmap_tables) or 0, #inds>0 and table.concat(inds, ', ') or '(none)'));
    f:write(string.format('Owned from cached bitmap: %d | HasKeyItem=true from indexed scan: %d | API scan complete=%s\n', tonumber(snap.bitmap_owned_count) or 0, tonumber(snap.api_owned_count) or 0, snap.api_scan_complete==true and 'YES' or 'NO'));
    if snap.api_error then f:write('HasKeyItem API error: ' .. tostring(snap.api_error) .. '\n'); end
    if snap.api_ok and not snap.api_scan_complete then f:write('NOTE: full API discovery scan skipped because the incremental key-item resource index was not complete yet. The stop snapshot may contain it.\n'); end
    if (tonumber(snap.bitmap_tables) or 0)==0 then f:write('NOTE: no cached server KI bitmap tables were available. Zone once while HorizonCheck is loaded, then stop/repeat the capture for authoritative bitmap ownership.\n'); end

    f:write('\nOWNED KEY ITEMS (merged direct discovery)\n');
    f:write('Format: ID | TABLE | NAME | SOURCES | KNOWN_PERMANENT\n');
    if #(snap.owned or {})==0 then f:write('(none detected)\n'); end
    for _,r in ipairs(snap.owned or {}) do
        local sources={};
        if r.bitmap==true then sources[#sources+1]='0x055'; end
        if r.api==true then sources[#sources+1]='HasKeyItem'; end
        if r.saved_proof==true then sources[#sources+1]='saved-proof'; end
        f:write(string.format('%d | %s | %s | %s | %s\n', tonumber(r.id) or -1, tostring(r.table_index~=nil and r.table_index or '-'), tostring(r.name or '?'), #sources>0 and table.concat(sources, '+') or 'unknown', r.known_permanent==true and 'YES' or 'no'));
    end

    f:write('\nKNOWN PERMANENT KEY ITEM MAP\n');
    f:write('Format: ID | NAME | BITMAP | API | SAVED_PROOF\n');
    for _,r in ipairs(snap.known_permanent or {}) do
        local b=r.bitmap==true and 'OWNED' or (r.bitmap==false and 'NOT OWNED' or 'UNKNOWN');
        local a=r.api==true and 'OWNED' or (r.api==false and 'NOT OWNED' or 'UNKNOWN');
        f:write(string.format('%s | %s | %s | %s | %s\n', tostring(r.id or '?'), tostring(r.name or r.label or r.key or '?'), b, a, r.saved_proof==true and 'YES' or 'no'));
    end
end

local function write_report(reason)
    local char = sanitize(HC.modules.core.character_name());
    local stamp = os.date('%Y%m%d_%H%M%S');
    local target = sanitize(capture.target or 'activity');
    local path = user_file('captures','horizoncheck_capture_' .. char .. '_' .. stamp .. '_' .. target .. '.txt');
    local f = io.open(path, 'w');
    if not f then return nil; end

    f:write('HorizonCheck v' .. tostring(HC.version) .. ' Detector Evidence Report\n');
    f:write('Character: ' .. tostring(HC.modules.core.character_name()) .. '\n');
    f:write('Target: ' .. tostring(capture.target or 'activity') .. '\n');
    f:write('Started: ' .. nowstamp(capture.started_at) .. '\n');
    f:write('Ended: ' .. nowstamp() .. '\n');
    f:write('Reason: ' .. tostring(reason or 'stopped') .. '\n');
    f:write(string.format('Totals: %d packets | %d unique packet IDs | %d text lines | %d zone changes\n\n', capture.packet_total, unique_packet_ids(), capture.text_total, capture.zone_total));

    f:write('TOP PACKET IDS\n');
    local rows = sorted_counts(capture.packet_counts);
    for i = 1, math.min(#rows, 30) do
        f:write(string.format('0x%03X  x%d\n', tonumber(rows[i].id) or 0, tonumber(rows[i].count) or 0));
    end

    f:write('\nMARKERS / PHASES\n');
    if #capture.markers == 0 then f:write('(none)\n'); end
    for _,m in ipairs(capture.markers) do
        f:write(string.format('%s  +%ds  %s\n', nowstamp(m.at), math.max(0,(m.at or 0)-(capture.started_at or 0)), tostring(m.label or 'mark')));
    end
    local phases = {};
    for phase in pairs(capture.phase_counts) do phases[#phases + 1] = phase; end
    table.sort(phases);
    for _,phase in ipairs(phases) do
        f:write('\nPHASE: ' .. tostring(phase) .. '\n');
        local pr = sorted_counts(capture.phase_counts[phase]);
        for i=1,math.min(#pr,15) do f:write(string.format('0x%03X  x%d\n', tonumber(pr[i].id) or 0, tonumber(pr[i].count) or 0)); end
    end

    f:write('\nZONE TRANSITIONS\n');
    if #capture.zone_samples == 0 then f:write('(none)\n'); end
    for _,z in ipairs(capture.zone_samples) do
        f:write(string.format('%s  %s -> %s\n', nowstamp(z.at), tostring(z.old or 'unknown'), tostring(z.new or 'unknown')));
    end

    write_tag_evidence(f);
    write_maat_evidence(f);
    if capture.target=='permkeyitems' then
        write_permkey_snapshot(f,'START',capture.permkey_start);
        write_permkey_snapshot(f,'END',capture.permkey_end);
    end

    if capture.target=='outposts' then
        f:write('\nPACKET SAMPLES (Outposts: full 0x017 payloads; other packets first 48 bytes; up to 3 unique samples per ID/size)\n');
    elseif capture.target=='currency' then
        f:write('\nPACKET SAMPLES (Currency: full 0x113 payloads; other packets first 48 bytes; up to 3 unique samples per ID/size)\n');
    elseif capture.target=='questmenu' then
        f:write('\nPACKET SAMPLES (Quest Menu: full 0x063 and 0x119 payloads; other packets first 48 bytes; up to 32 unique samples per ID/size)\n');
    elseif capture.target=='questverify' then
        f:write('\nPACKET SAMPLES (Guided Quest Verification: full 0x056, 0x063, and 0x119 payloads; other packets first 48 bytes; up to 32 unique samples per ID/size)\n');
    elseif capture.target=='maat' then
        f:write('\nPACKET SAMPLES (Maat: full non-movement payloads; movement packets first 48 bytes; up to 32 unique samples per ID/size)\n');
    else
        f:write('\nPACKET SAMPLES (first 48 bytes, up to 3 unique samples per ID/size)\n');
    end
    local keys = {};
    for key in pairs(capture.packet_samples) do keys[#keys + 1] = key; end
    table.sort(keys);
    for _,key in ipairs(keys) do
        for _,s in ipairs(capture.packet_samples[key]) do
            f:write(string.format('%s  id=0x%03X size=%d  %s\n', nowstamp(s.at), tonumber(s.id) or 0, tonumber(s.size) or 0, tostring(s.hex)));
        end
    end

    f:write('\nTEXT SAMPLES - START OF CAPTURE\n');
    if #capture.text_samples == 0 then f:write('(none)\n'); end
    for _,t in ipairs(capture.text_samples) do f:write(nowstamp(t.at) .. '  ' .. tostring(t.text) .. '\n'); end

    f:write('\nTEXT SAMPLES - END OF CAPTURE\n');
    if #capture.text_tail == 0 then f:write('(none)\n'); end
    local first_tail=1;
    -- Avoid duplicating the entire beginning on short captures.
    if capture.text_total<=120 then first_tail=#capture.text_tail+1; end
    for i=first_tail,#capture.text_tail do
        local t=capture.text_tail[i];
        f:write(nowstamp(t.at) .. '  ' .. tostring(t.text) .. '\n');
    end
    f:close();
    return path;
end

local function persist_tag_observations()
    if capture.target ~= 'tags' then return; end
    local c = HC.modules.state.get_char();
    local tl = ensure_tag_learning(c);
    local added = 0;
    for _,p in ipairs(capture.tag_menu_packets) do
        if p.known_count ~= nil then
            local duplicate = false;
            for _,o in ipairs(tl.observations) do
                if tonumber(o.known_count) == tonumber(p.known_count) and tonumber(o.size) == tonumber(p.size) and tostring(o.hex) == tostring(p.hex) then duplicate = true; break; end
            end
            if not duplicate then
                tl.observations[#tl.observations + 1] = {
                    at = p.at,
                    known_count = p.known_count,
                    size = p.size,
                    hex = p.hex,
                    phase = p.phase,
                };
                added = added + 1;
            end
        end
    end
    while #tl.observations > 40 do table.remove(tl.observations, 1); end
    tl.last_capture_at = os.time();
    tl.last_added = added;
end

local function store_summary(reason)
    local c = HC.modules.state.get_char();
    c.learning_summary = type(c.learning_summary) == 'table' and c.learning_summary or {};
    c.learning_summary.target = capture.target;
    c.learning_summary.started_at = capture.started_at;
    c.learning_summary.ended_at = os.time();
    c.learning_summary.reason = reason or 'stopped';
    c.learning_summary.packet_total = capture.packet_total;
    c.learning_summary.unique_packet_ids = unique_packet_ids();
    c.learning_summary.text_total = capture.text_total;
    c.learning_summary.zone_total = capture.zone_total;
    c.learning_summary.marker_total = #capture.markers;
    c.learning_summary.log_path = capture.log_path;
    c.learning_summary.report_path = capture.report_path;
    c.learning_summary.tag_menu_packets = #capture.tag_menu_packets;
    c.learning_summary.known_tag_count = capture.known_tag_count;
    if capture.target == 'tags' then
        local tl = ensure_tag_learning(c);
        c.learning_summary.tag_observations = #(tl.observations or {});
        c.learning_summary.tag_known_states = #distinct_known_counts(tl.observations or {});
    end
    HC.modules.state.save();
end

function M.start(target, seconds)
    target = string.lower(tostring(target or 'activity'));
    local profile = PROFILES[target];
    local manual_stop = profile and profile.manual_stop==true;

    if manual_stop and seconds==nil then
        seconds = 0;
    else
        seconds = tonumber(seconds) or (profile and profile.seconds) or 120;
        if seconds < 15 then seconds = 15; end
        if seconds > 3600 then seconds = 3600; end
    end

    if capture.active then M.stop('restarted'); end
    reset_runtime();
    capture.active = true;
    capture.target = target;
    capture.started_at = os.time();
    if manual_stop and seconds==0 then
        capture.ends_at = nil;
    else
        capture.ends_at = capture.started_at + seconds;
    end
    capture.zone_id = HC.modules.automation and HC.modules.automation.get_zone_id and HC.modules.automation.get_zone_id() or nil;
    capture.phase_counts[capture.phase] = {};

    local char = sanitize(HC.modules.core.character_name());
    capture.log_path = user_file('logs','horizoncheck_learning_' .. char .. '.log');
    append_log('');
    append_log('=== HorizonCheck v' .. tostring(HC.version) .. ' LEARN START ===');
    append_log('time=' .. nowstamp(capture.started_at) .. ' target=' .. target .. ' duration=' .. ((manual_stop and seconds==0) and 'manual-stop' or (tostring(seconds)..'s')) .. ' zone=' .. tostring(capture.zone_id or 'unknown'));
    if profile then append_log('profile=' .. target .. ' desc=' .. profile.desc); end
    if target=='maat' then
        append_log('MAAT MODE: preserve full non-movement packet payloads and up to 32 unique samples per packet shape.');
        append_log('Speak to Maat in Ru\'Lude Gardens, complete all dialogue/menu steps, then stop. Do not infer victory bits from a single capture.');
    elseif target=='outposts' then
        append_log('OUTPOST MODE: full 0x017 packet payloads are retained; other packet samples remain capped to the first 48 bytes.');
        append_log('Use this mode on Regional Teleportation Service NPCs to compare _CUSTOM_MENU destination payloads between known ownership states.');
    elseif target=='currency' then
        append_log('CURRENCY MODE: full 0x113 packet payloads are retained; other packet samples remain capped to the first 48 bytes.');
        append_log('Open the native Currency menu and leave it visible briefly so HAAP / Shining Stars / Imperial Standing / Assault Points can be correlated to the authoritative server payload.');
    elseif target=='permkeyitems' then
        append_log('PERMKEY MODE: direct snapshots read HorizonCheck cached 0x055 key-item ownership and indexed HasKeyItem results; a new packet does not need to arrive during this Learn window.');
        local km=HC.modules.keyitems;
        if km and km.permanent_snapshot then
            local ok,snap=pcall(km.permanent_snapshot);
            if ok then capture.permkey_start=snap; append_log(string.format('PERMKEY START SNAPSHOT bitmap_tables=%d owned=%d api_owned=%d',tonumber(snap.bitmap_tables) or 0,#(snap.owned or {}),tonumber(snap.api_owned_count) or 0));
            else append_log('PERMKEY START SNAPSHOT ERROR: '..tostring(snap)); end
        end
    elseif target=='questverify' then
        append_log('QUEST VERIFY MODE: full 0x056/0x063/0x119 payloads are retained with up to 32 unique samples per packet shape.');
        append_log('Use the Guided Capture Wizard so before/after native state and key-item differences are analyzed automatically.');
    else
        append_log('Packet samples contain only the first 48 bytes and are capped per packet shape.');
    end
    if target == 'permkeyitems' then
        local s=capture.permkey_start or {};
        HC.msg(string.format('LEARN permkeyitems started. Direct snapshot: %d cached 0x055 table(s), %d owned KI row(s). Stop capture to record a second snapshot.',tonumber(s.bitmap_tables) or 0,#(s.owned or {})));
    elseif target == 'tags' then
        append_log('TAG MODE: full candidate 0x034 packets are retained for comparison. Label a known stored-tag count with /hcheck learn known <0-4>.');
        HC.msg('LEARN tags started. Talk to Rytaal, then use /hcheck learn known <0-4> if you know the stored-tag count.');
    elseif manual_stop and seconds==0 then
        append_log('MANUAL STOP MODE: capture has no automatic timeout.');
        HC.msg('LEARN started for "' .. target .. '" (manual stop). Click Stop Capture or use /hcheck learn stop when finished.');
    else
        HC.msg('LEARN started for "' .. target .. '" (' .. tostring(seconds) .. 's). Use /hcheck learn mark <label> at important moments; /hcheck learn stop when finished.');
    end
    return true;
end

function M.mark(label)
    if not capture.active then HC.msg('Learning mode is not active.'); return false; end
    label = sanitize(label or 'mark');
    local m = { at = os.time(), label = label };
    capture.markers[#capture.markers + 1] = m;
    capture.phase = label;
    capture.phase_counts[label] = capture.phase_counts[label] or {};
    append_log(string.format('MARK %s +%ds %s', nowstamp(m.at), math.max(0,m.at-(capture.started_at or m.at)), label));
    HC.msg('LEARN marker: ' .. label);
    return true;
end

function M.known_tags(count)
    if not capture.active or capture.target ~= 'tags' then HC.msg('Start /hcheck learn tags before labeling a known tag count.'); return false; end
    count = tonumber(count);
    if count == nil or count < 0 or count > 4 or math.floor(count) ~= count then HC.msg('Known stored-tag count must be 0 through 4.'); return false; end
    local now = os.time();
    capture.known_tag_count = count;
    capture.known_tag_at = now;
    local linked = 0;
    for _,p in ipairs(capture.tag_menu_packets) do
        if p.known_count == nil and math.abs((p.at or now) - now) <= 20 then p.known_count = count; linked = linked + 1; end
    end
    append_log(string.format('TAG_KNOWN %s count=%d linked_0x034=%d', nowstamp(now), count, linked));
    HC.msg(string.format('LEARN tags: known stored-tag count = %d; linked to %d nearby 0x034 packet(s).', count, linked));
    return true;
end

function M.stop(reason)
    if not capture.active then return false; end
    if capture.target=='permkeyitems' then
        local km=HC.modules.keyitems;
        if km and km.permanent_snapshot then
            local ok,snap=pcall(km.permanent_snapshot);
            if ok then capture.permkey_end=snap; append_log(string.format('PERMKEY END SNAPSHOT bitmap_tables=%d owned=%d api_owned=%d',tonumber(snap.bitmap_tables) or 0,#(snap.owned or {}),tonumber(snap.api_owned_count) or 0));
            else append_log('PERMKEY END SNAPSHOT ERROR: '..tostring(snap)); end
        end
    end
    persist_tag_observations();
    append_log('summary packets=' .. tostring(capture.packet_total) .. ' unique_ids=' .. tostring(unique_packet_ids()) .. ' text=' .. tostring(capture.text_total) .. ' zones=' .. tostring(capture.zone_total) .. ' markers=' .. tostring(#capture.markers));
    append_log('time=' .. nowstamp() .. ' reason=' .. tostring(reason or 'manual'));
    append_log('=== LEARN END ===');
    capture.report_path = write_report(reason or 'manual');
    store_summary(reason or 'manual');
    local path = capture.log_path;
    local report = capture.report_path;
    local target = capture.target;
    local packets = capture.packet_total;
    local ids = unique_packet_ids();
    capture.active = false;
    HC.msg(string.format('LEARN stopped: %s | %d packets across %d IDs. Evidence: %s', tostring(target), packets, ids, tostring(report or path)));
    return true;
end

local function packet_sample_key(id, size)
    return string.format('%03X:%d', tonumber(id) or 0, tonumber(size) or 0);
end

function M.on_packet(e)
    if not capture.active or e == nil or e.injected then return; end
    local id = tonumber(e.id) or 0;
    local size = tonumber(e.size) or 0;
    capture.packet_total = capture.packet_total + 1;
    capture.packet_counts[id] = (capture.packet_counts[id] or 0) + 1;
    local phase = capture.phase or 'capture';
    capture.phase_counts[phase] = capture.phase_counts[phase] or {};
    capture.phase_counts[phase][id] = (capture.phase_counts[phase][id] or 0) + 1;

    if capture.target == 'tags' and id == 0x034 then
        local now = os.time();
        local known = nil;
        if capture.known_tag_count ~= nil and capture.known_tag_at and math.abs(now - capture.known_tag_at) <= 20 then known = capture.known_tag_count; end
        local p = { at = now, id = id, size = size, hex = data_hex(e.data, math.max(64, size)), phase = phase, known_count = known };
        capture.tag_menu_packets[#capture.tag_menu_packets + 1] = p;
        append_log(string.format('TAG_MENU %s phase=%s id=0x034 size=%d known=%s hex=%s', nowstamp(now), tostring(phase), size, tostring(known ~= nil and known or '?'), tostring(p.hex or '')));
    end

    local key = packet_sample_key(id, size);
    local samples = capture.packet_samples[key] or {};
    local sample_limit = ((capture.target=='questmenu' or capture.target=='questverify' or capture.target=='maat') and 32) or 3;
    if #samples < sample_limit then
        local sample_bytes=48;
        if capture.target=='outposts' and id==0x017 then
            -- Regional Teleportation Service menus are emitted as 0x017
            -- _CUSTOM_MENU packets. The destination entries can extend well
            -- beyond byte 48, so preserve the entire packet for decoding.
            sample_bytes=math.max(48,size);
        elseif capture.target=='currency' and id==0x113 then
            -- The native Currency menu's authoritative values are carried in
            -- 0x113. HAAP is not in the first 48 bytes in our known sample, so
            -- retain the complete payload for offset correlation/decoding.
            sample_bytes=math.max(48,size);
        elseif (capture.target=='questmenu' or capture.target=='questverify') and (id==0x056 or id==0x063 or id==0x119) then
            -- Quest-menu browsing on HorizonXI is dominated by 0x063 state/menu
            -- records plus a 0x119 table. Preserve the complete payloads so the
            -- quest IDs/status fields can be correlated instead of truncating at
            -- byte 48. Keep many unique samples because 0x063 has several
            -- subtypes and multiple records of the same packet size.
            sample_bytes=math.max(48,size);
        elseif capture.target=='maat' and id~=0x00E and id~=0x015 and id~=0x00D then
            -- Maat progress is server-persistent and may be exposed in an NPC/menu
            -- payload whose exact packet ID is not known yet. Preserve full
            -- non-movement payloads so a per-job clear mask can be correlated.
            sample_bytes=math.max(48,size);
        end
        local hx = data_hex(e.data, sample_bytes);
        local sig = hx or '<packet bytes unavailable>';
        local duplicate = false;
        for _, old in ipairs(samples) do if old.hex == sig then duplicate = true; break; end end
        if not duplicate then
            local sample = {
                at = os.time(),
                id = id,
                size = size,
                hex = sig,
                full_payload = ((capture.target=='outposts' and id==0x017) or (capture.target=='currency' and id==0x113) or ((capture.target=='questmenu' or capture.target=='questverify') and (id==0x056 or id==0x063 or id==0x119)) or (capture.target=='maat' and id~=0x00E and id~=0x015 and id~=0x00D)) and true or false,
            };
            samples[#samples + 1] = sample;
            capture.packet_samples[key] = samples;
            append_log(string.format('PACKET %s phase=%s id=0x%03X size=%d hex=%s', nowstamp(sample.at), tostring(phase), id, size, sig));
        end
    end
end

local function capture_text_signature(s)
    s=tostring(s or '');
    -- The Horizon text hook can emit both the raw dialogue and one or more
    -- normalized q[HH:MM:SS] mirrors. Strip those transport-only stamps so
    -- the evidence report keeps the dialogue once instead of three times.
    s=string.gsub(s,'[%z\1-\31\127]',' ');
    s=string.gsub(s,'q%[%d%d:%d%d:%d%d%]%s*','');
    s=string.lower(s);
    s=string.gsub(s,'%s+',' ');
    s=string.gsub(s,'^%s+','');
    s=string.gsub(s,'%s+$','');
    return s;
end

local function duplicate_capture_text(s)
    local sig=capture_text_signature(s);
    if sig=='' then return true; end
    local now=os.time();
    capture.recent_text_sigs=type(capture.recent_text_sigs)=='table' and capture.recent_text_sigs or {};
    local prev=tonumber(capture.recent_text_sigs[sig]);
    capture.recent_text_sigs[sig]=now;
    for k,at in pairs(capture.recent_text_sigs) do
        if now-(tonumber(at) or 0)>4 then capture.recent_text_sigs[k]=nil; end
    end
    return prev~=nil and (now-prev)<=2;
end

function M.on_text(s, e)
    if not capture.active then return; end
    s = tostring(s or '');
    if s == '' then return; end
    if duplicate_capture_text(s) then return; end
    capture.text_total = capture.text_total + 1;
    local text_event={ at = os.time(), text = s };
    if #capture.text_samples < 120 then
        capture.text_samples[#capture.text_samples + 1] = text_event;
    end
    capture.text_tail[#capture.text_tail + 1] = text_event;
    while #capture.text_tail > 160 do table.remove(capture.text_tail,1); end

    if capture.target == 'tags' then
        local low = string.lower(s);
        local kind = nil;
        if string.find(low, 'rytaal', 1, true) and string.find(low, 'welcome to the commissions agency', 1, true) then kind = 'rytaal_welcome';
        elseif string.find(low, 'cannot issue a new imperial army i.d. tag while you have one in your possession', 1, true) then kind = 'has_id_tag';
        elseif string.find(low, 'imperial army i.d. tag', 1, true) then kind = 'tag_text'; end
        if kind then
            capture.rytaal_text[#capture.rytaal_text + 1] = { at = os.time(), kind = kind, text = s };
            append_log('TAG_TEXT ' .. nowstamp() .. ' kind=' .. kind .. ' ' .. s);
        end
    end

    append_log('TEXT ' .. nowstamp() .. ' phase=' .. tostring(capture.phase or 'capture') .. ' ' .. s);
end

function M.poll()
    if not capture.active then return; end
    local now = os.time();
    if capture.ends_at and now >= capture.ends_at then M.stop('timer expired'); return; end

    local zid = HC.modules.automation and HC.modules.automation.get_zone_id and HC.modules.automation.get_zone_id() or nil;
    if zid and zid ~= capture.zone_id then
        local old = capture.zone_id;
        capture.zone_id = zid;
        capture.zone_total = capture.zone_total + 1;
        local z = { at = now, old = old, new = zid };
        capture.zone_samples[#capture.zone_samples + 1] = z;
        while #capture.zone_samples > 30 do table.remove(capture.zone_samples, 1); end
        append_log(string.format('ZONE %s phase=%s %s -> %s', nowstamp(now), tostring(capture.phase or 'capture'), tostring(old or 'unknown'), tostring(zid)));
    end
end

function M.status()
    if not capture.active then return 'IDLE'; end
    if capture.ends_at==nil then
        return string.format('LEARNING %s | %s | MANUAL STOP | %d packets | %d text',
            tostring(capture.target), tostring(capture.phase or 'capture'), capture.packet_total, capture.text_total);
    end
    local remain = math.max(0, capture.ends_at - os.time());
    if capture.target == 'tags' then
        return string.format('LEARNING tags | %ds left | 0x034=%d | known=%s | Rytaal text=%d', remain, #capture.tag_menu_packets, tostring(capture.known_tag_count ~= nil and capture.known_tag_count or '?'), #capture.rytaal_text);
    end
    return string.format('LEARNING %s | %s | %ds left | %d packets | %d text', tostring(capture.target), tostring(capture.phase or 'capture'), remain, capture.packet_total, capture.text_total);
end

function M.active() return capture.active; end
function M.current() return capture; end
function M.profiles() return PROFILES; end

function M.profile_mode(target)
    target=string.lower(tostring(target or ''));
    local p=PROFILES[target];
    if not p then return 'unknown'; end
    if p.manual_stop==true then return 'manual-stop'; end
    return tostring(tonumber(p.seconds) or 120)..'s';
end

function M.capture_button(target, id, seconds)
    if not HC or not HC.imgui or type(HC.imgui.SmallButton)~='function' then return false; end
    target=string.lower(tostring(target or 'activity'));
    id=tostring(id or target);

    local cur=M.current();
    local same=M.active() and cur and cur.target==target;
    local label=same and ('Stop Capture##hcap_'..id) or ('Capture##hcap_'..id);

    local ok_button,clicked=pcall(HC.imgui.SmallButton,label);
    if ok_button and clicked then
        local ok_action,action_err;
        if same then
            ok_action,action_err=pcall(M.stop,'one-click button');
        else
            ok_action,action_err=pcall(M.start,target,seconds);
        end
        if not ok_action and HC.msg then HC.msg('Capture control error: '..tostring(action_err)); end
        return ok_action==true;
    end

    -- IsItemHovered / SetTooltip are not guaranteed by every Ashita imgui
    -- binding build.  Tooltips are optional; a missing helper must never take
    -- down an otherwise functional tab.
    if type(HC.imgui.IsItemHovered)=='function' and type(HC.imgui.SetTooltip)=='function' then
        local ok_hover,hovered=pcall(HC.imgui.IsItemHovered);
        if ok_hover and hovered then
            local tip;
            if same then
                tip='Stop the active '..target..' evidence capture.';
            else
                local p=PROFILES[target];
                tip='Start HorizonCheck evidence capture: '..target..(p and ('\n'..p.desc) or '');
            end
            pcall(HC.imgui.SetTooltip,tip);
        end
    end
    return false;
end

function M.top_packets(limit)
    local rows = sorted_counts(capture.packet_counts);
    while #rows > (limit or 12) do table.remove(rows); end
    return rows;
end

function M.tag_learning_status(c)
    c = c or HC.modules.state.get_char();
    local tl = ensure_tag_learning(c);
    local counts = distinct_known_counts(tl.observations or {});
    local candidates = candidate_offsets(tl.observations or {});
    return {
        observations = #(tl.observations or {}),
        known_states = #counts,
        known_counts = counts,
        candidates = candidates,
    };
end

function M.clear_tag_learning()
    if capture.active then HC.msg('Stop learning before clearing Assault Tag observations.'); return false; end
    local c = HC.modules.state.get_char();
    c.tag_learning = { observations = {} };
    HC.modules.state.save();
    HC.msg('Assault Tag learner observations cleared.');
    return true;
end

function M.clear_log()
    if capture.active then HC.msg('Stop learning before clearing learning files.'); return false; end
    local char = sanitize(HC.modules.core.character_name());
    local p = user_file('logs','horizoncheck_learning_' .. char .. '.log');
    os.remove(p);
    local c = HC.modules.state.get_char();
    if c.learning_summary and c.learning_summary.report_path then os.remove(c.learning_summary.report_path); end
    c.learning_summary = {};
    HC.modules.state.save();
    HC.msg('Learning log, last evidence report, and learning summary cleared.');
    return true;
end

function M.command(w)
    local sub = string.lower(w[2] or '');
    if sub ~= 'learn' and sub ~= 'learning' then return false; end
    local what = string.lower(w[3] or 'status');
    if what == 'stop' then
        if not M.stop('manual') then HC.msg('Learning mode is not active.'); end
    elseif what == 'status' then
        HC.msg(M.status());
    elseif what == 'clear' then
        M.clear_log();
    elseif what == 'cleartags' then
        M.clear_tag_learning();
    elseif what == 'tagstatus' then
        local s = M.tag_learning_status();
        local labels = {}; for _,n in ipairs(s.known_counts or {}) do labels[#labels + 1] = tostring(n); end
        HC.msg(string.format('Tag learner: %d observation(s), %d known state(s) [%s], %d candidate offset(s).', s.observations, s.known_states, table.concat(labels, ','), #(s.candidates or {})));
    elseif what == 'known' then
        M.known_tags(w[4]);
    elseif what == 'profiles' then
        HC.msg('LEARN profiles: assault, tags, limbus, dynamis, eco, guild, enm, dragon, highwind, haap, chocobo, blackcoffin, outposts, pots, questmenu, fame, maat, permkeyitems, questverify.');
    elseif what == 'mark' then
        local label = w[4] or 'mark';
        M.mark(label);
    elseif what == 'help' then
        HC.msg('/hcheck learn <activity> [seconds] | mark <label> | known <0-4> | tagstatus | cleartags | stop | status | profiles | clear');
    else
        M.start(what, tonumber(w[4]));
    end
    return true;
end

function M.init(ctx)
    HC = ctx;
    if HC.modules.packets then
        HC.modules.packets.register_tap('learning', M.on_packet);
        HC.modules.packets.register_text('learning', M.on_text);
    end
end

return M;
