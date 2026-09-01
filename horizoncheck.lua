-- HorizonCheck v7.9.8
-- Modular rewrite for HorizonXI / Ashita v4.

addon.name = 'horizoncheck';
addon.author = 'OpenAI';
addon.version = '7.9.8';
addon.desc = 'HorizonXI daily/weekly activity dashboard.';
addon.link = 'https://horizonxi.com/';

require('common');

local imgui_ok, imgui = pcall(require, 'imgui');
local chat_ok, chat = pcall(require, 'chat');

local function loadmod(name)
    local path = addon.path .. 'modules\\' .. name .. '.lua';
    local ok, mod = pcall(dofile, path);
    if not ok then
        return nil, tostring(mod);
    end
    if type(mod) ~= 'table' then
        return nil, 'module did not return a table: ' .. name;
    end
    return mod, nil;
end

local HC = {
    version = '7.9.8',
    imgui = imgui_ok and imgui or nil,
    chat = chat_ok and chat or nil,
    addon_path = addon.path,
    ui = { open = { true }, show_diagnostics_tab = false },
    modules = {},
    errors = {},
};

local hc_msg_last={ text=nil, at=0 };

local function notification_category(text)
    local low=string.lower(tostring(text or ''));
    if low:find('mission sync',1,true) or low:find('mission checkbox',1,true) then return 'mission'; end
    if low:find('assault',1,true) or low:find('rytaal',1,true) or low:find('i.d. tag',1,true) then return 'assault'; end
    if low:find('enm',1,true) or low:find('moritz',1,true) then return 'enm'; end
    if low:find('digging',1,true) or low:find('chocobo dig',1,true) then return 'digging'; end
    if low:find('black coffin',1,true) then return 'blackcoffin'; end
    if low:find('weekly',1,true) or low:find('conquest',1,true) or low:find('limbus',1,true) or low:find('dynamis',1,true) then return 'weekly'; end
    return 'general';
end

local function notification_enabled(category)
    if not HC.modules or not HC.modules.state or not HC.modules.state.get_char then return true; end
    local ok,c=pcall(HC.modules.state.get_char);
    if not ok or type(c)~='table' then return true; end
    local s=type(c.settings)=='table' and c.settings or nil;
    local n=s and type(s.notifications)=='table' and s.notifications or nil;
    if not n then return true; end
    return n[category]~=false;
end

local function developer_mode_enabled()
    if not HC.modules or not HC.modules.state or not HC.modules.state.get_char then return false; end
    local ok,c=pcall(HC.modules.state.get_char);
    return ok and type(c)=='table' and type(c.settings)=='table' and c.settings.developer_mode==true;
end

-- Normal players should see plain-English notifications. Developer Mode
-- intentionally keeps the original technical wording for troubleshooting.
local function friendly_chat_message(text)
    local out=tostring(text or '');

    -- Remove implementation labels that are useful to developers but add no
    -- value to ordinary gameplay notifications.
    out=out:gsub('^AUTO:%s*','');
    out=out:gsub('^FAME AUTO:%s*','Fame: ');
    out=out:gsub('%s*%[VERIFIED BY [^%]]+%]','');
    out=out:gsub('%s*%[VERIFIED%]','');
    out=out:gsub('%s*%[AUTO%]','');
    out=out:gsub('%s*%[0x[%x]+[^%]]*%]','');

    -- Prefer everyday wording for the remaining status text.
    local replacements={
        {'UNVERIFIED','not confirmed'}, {'Unverified','Not confirmed'}, {'unverified','not confirmed'},
        {'VERIFIED','confirmed'}, {'Verified','Confirmed'}, {'verified','confirmed'},
        {'synchronized','updated'}, {'Synchronized','Updated'},
        {'synchronization','update'}, {'Synchronization','Update'},
        {'synced','updated'}, {'Synced','Updated'},
        {'reconciled','updated'}, {'Reconciled','Updated'},
        {'reconciliation','update'}, {'Reconciliation','Update'},
        {'auto%-detected','found'}, {'Auto%-detected','Found'},
        {'auto%-updated','updated'}, {'Auto%-updated','Updated'},
        {'detected','noticed'}, {'Detected','Noticed'},
        {'native history','past game history'}, {'Native history','Past game history'},
        {'native','game'}, {'Native','Game'},
        {'packet sync','game update'}, {'Packet sync','Game update'},
        {'packet','game data'}, {'Packet','Game data'},
        {'evidence','details'}, {'Evidence','Details'},
        {'bitmap','key item data'}, {'Bitmap','Key item data'},
    };
    for _,r in ipairs(replacements) do out=out:gsub(r[1],r[2]); end

    -- A few common system phrases read much better as direct user guidance.
    out=out:gsub('Initial HorizonCheck update complete%. Review the one%-time update summary%.','HorizonCheck setup is complete.');
    out=out:gsub('Self%-test passed%.','HorizonCheck check passed.');
    local issues=out:match('Self%-test failed:%s*(%d+)%s*issue%(s%)%.');
    if issues then out='HorizonCheck found '..tostring(issues)..' issue(s). Open Diagnostics for details.'; end
    local startup=out:match('HorizonCheck loaded with%s*(%d+)%s*self%-test issue%(s%)%. Open the Diagnostics tab%.');
    if startup then out='HorizonCheck loaded, but found '..tostring(startup)..' issue(s). Open Diagnostics for details.'; end
    out=out:gsub('UI module error captured%. Diagnostics remain in the main HorizonCheck window%.','HorizonCheck ran into a display error. Open Diagnostics for details.');

    -- Clean spacing/punctuation left after removing bracketed developer tags.
    out=out:gsub('%s+',' '):gsub('%s+([,%.%!%?])','%1');
    out=out:gsub('%[%s*%]','');
    out=out:gsub('%s+%- %s*$','');
    out=out:gsub('^%s+',''):gsub('%s+$','');
    return out;
end

local function low_value_runtime_message(text)
    local low=string.lower(tostring(text or ''));

    -- Normal play should announce meaningful completions, warnings, errors,
    -- unlocks, and obtained rewards -- not every intermediate packet/state
    -- transition. Developer Mode keeps the full stream for evidence work.
    if low:sub(1,5)=='auto:' then
        local meaningful=(
            low:find('complete',1,true) or low:find('completed',1,true)
            or low:find('obtained',1,true) or low:find('successful clear',1,true)
            or low:find('victory',1,true) or low:find('promoted',1,true)
            or low:find('recharged',1,true) or low:find('unlocked',1,true)
            or low:find('daily cap',1,true) or low:find('warning',1,true)
            or low:find('failed',1,true) or low:find('error',1,true)
        );
        return not meaningful;
    end

    local routine_prefixes={
        'guild auto-detected:',
        'guild points auto-updated:',
        'guild points synced from npc dialogue:',
        'guild points confirmed by npc dialogue:',
        'quest accepted / active:',
        'quest left active log:',
        'eeko-weeko packet recognized:',
        'eeko-weeko packet captured:',
        'eeko-weeko rotation verified',
    };
    for _,prefix in ipairs(routine_prefixes) do
        if low:sub(1,#prefix)==prefix then return true; end
    end
    return false;
end

function HC.msg(s)
    local text=tostring(s);
    local now=os.time();
    local developer=developer_mode_enabled();

    local low=string.lower(text);
    if not developer and low_value_runtime_message(text) then return; end
    local always_show=low:find('loaded',1,true) or low:find('error',1,true)
        or low:find('self-test',1,true) or low:find('state health',1,true);
    if not always_show then
        local category=notification_category(text);
        if not notification_enabled(category) then return; end

        -- Digging threshold/cap notices are intentionally reset-scoped.  The
        -- digging module already persists warned_75/warned_90/warned_95/
        -- warned_cap and clears those latches at the daily reset.  Do not pass
        -- these messages through the permanent exact-text notification_state
        -- deduper or a warning seen yesterday will be suppressed forever.
        local reset_scoped_digging_notice = category=='digging' and (
            low:find('digging progress:',1,true)
            or low:find('digging fatigue warning:',1,true)
            or low:find('digging fatigue:',1,true)
            or low:find('auto: digging daily cap complete',1,true)
        );

        if not reset_scoped_digging_notice
            and HC.modules and HC.modules.state and HC.modules.state.notification_should_emit then
            local ok,c=pcall(HC.modules.state.get_char);
            if ok and type(c)=='table' then
                local key='notify:'..category..':'..text;
                if not HC.modules.state.notification_should_emit(c,key,'seen') then return; end
            end
        end
    end

    local display_text=developer and text or friendly_chat_message(text);
    if display_text=='' then return; end

    -- Global duplicate-notification guard. Ashita may surface the same event
    -- through multiple callback paths; suppress the same player-facing message
    -- repeated within 2 seconds, even if its internal confirmation source differs.
    if hc_msg_last.text==display_text and now-(tonumber(hc_msg_last.at) or 0)<=2 then
        return;
    end
    hc_msg_last.text=display_text;
    hc_msg_last.at=now;

    if HC.chat ~= nil then
        print(HC.chat.header('HorizonCheck'):append(HC.chat.message(' ' .. display_text)));
    else
        print('[HorizonCheck] ' .. display_text);
    end
end

local order = {
    'core',
    'userdata',
    'state',
    'timeline',
    'runtimeguard',
    'packets',
    'evidence',
    'keyitems',
    'guild',
    'haap',
    'assault',
    'assaultprogress',
    'rings',
    'enm',
    'skills',
    'dynamis',
    'limbus',
    'henm',
    'quests',
    'questgraph',
    'blockers',
    'fame',
    'eco',
    'blackcoffin',
    'chocobo',
    'outposts',
    'digging',
    'plantpots',
    'isnm',
    'ovens',
    'spice',
    'missions',
    'availability',
    'canonical',
    'unlocks',
    'historyimport',
    'systems',
    'readiness',
    'progression',
    'selfheal',
    'profiler',
    'performance_watchdog',
    'dependencies',
    'integrity',
    'uikit',
    'zonesync',
    'synchealth',
    'characterregistry',
    'itemlocator',
    'releasehealth',
    'catalog_integrity',
    'catalog_coverage',
    'planner',
    'search',
    'zoneintel',
    'smartdashboard',
    'weekly',
    'sessions',
    'automation',
    'learning',
    'capturewizard',
    'diagnostics',
    'regression',
    'anniversary',
    'seasonal',
    'seasky',
    'ui',
};

for _, name in ipairs(order) do
    local mod, err = loadmod(name);
    if mod == nil then
        HC.errors[#HC.errors + 1] = name .. ': ' .. tostring(err);
    else
        HC.modules[name] = mod;
        if type(mod.init) == 'function' then
            local ok, ierr = pcall(mod.init, HC);
            if not ok then
                HC.errors[#HC.errors + 1] = name .. ' init: ' .. tostring(ierr);
            end
        end
    end
end

local function self_test()
    local required = {
        core = { 'character_name', 'weekly_key', 'daily_key' },
        userdata = { 'path', 'root', 'dirs', 'status', 'external', 'cleanup_legacy' },
        state = { 'get_char', 'profile_name', 'profile_ready', 'save', 'request_save', 'poll', 'migrate', 'reconcile', 'health', 'onboarding', 'reset_ui_settings', 'audit', 'audit_recent', 'initialization_summary', 'current_schema', 'storage_status', 'validate', 'migration_status', 'restore_latest_migration_backup', 'cleanup_retired', 'cleanup_status', 'draw_cleanup' },
        timeline = { 'record', 'transition', 'recent', 'player_recent', 'undo', 'draw', 'status' },
        runtimeguard = { 'pcall', 'draw', 'retry', 'retry_all', 'snapshot', 'status', 'draw_status' },
        packets = { 'on_packet', 'on_text' },
        evidence = { 'submit', 'resolve', 'resolve_rows', 'inspect', 'refresh', 'register_provider', 'status' },
        keyitems = { 'probe', 'status', 'draw', 'ownership_name', 'ownership_id', 'evidence_key', 'poll', 'index_status', 'permanent_snapshot', 'known_id' },
        assault = { 'status', 'packet_status', 'sync_status' },
        assaultprogress = { 'count', 'is_complete', 'sync_native_history', 'native_status', 'native_diagnostics', 'draw_native_diagnostics', 'native_rows' },
        eco = { 'sync_status' },
        fame = { 'status', 'sync_status' },
        haap = { 'status' },
        digging = { 'status', 'draw_row' },
        plantpots = { 'status', 'poll', 'relearn' },
        isnm = { 'status' },
        questgraph = { 'trace', 'summary', 'direct_dependencies', 'transitive_dependents', 'analyze_nodes' },
        blockers = { 'quest', 'summary', 'status' },
        availability = { 'quest', 'mission', 'system', 'is_actionable', 'snapshot', 'draw', 'status' },
        canonical = { 'quest', 'mission', 'native_policy', 'native_allowed', 'is_actionable', 'snapshot', 'collisions', 'quarantined', 'invalidate', 'draw', 'status' },
        unlocks = { 'refresh', 'get', 'by_name', 'by_id', 'owned', 'owned_name', 'snapshot', 'draw', 'status' },
        historyimport = { 'reconcile', 'status', 'invalidate', 'draw', 'command' },
        systems = { 'snapshot', 'get', 'action_rows', 'timer_rows', 'repeat_status', 'status' },
        progression = { 'normalize_state', 'observe', 'resolve', 'reconcile', 'snapshot', 'get', 'all', 'poll', 'draw', 'status' },
        selfheal = { 'scan', 'poll', 'draw', 'status' },
        profiler = { 'record', 'measure', 'pcall', 'snapshot', 'draw', 'status', 'release_health', 'reset', 'bump', 'cache', 'counter_snapshot' },
        performance_watchdog = { 'sample', 'poll', 'status', 'reset', 'draw' },
        dependencies = { 'invalidate', 'invalidate_many', 'status', 'draw' },
        integrity = { 'scan', 'invalidate', 'poll', 'status', 'draw' },
        uikit = { 'table_flags', 'window_width', 'wide_enough', 'table_supported', 'section_header', 'section_header_action', 'wrapped_note', 'status_row', 'responsive_two_column', 'collapsing_section', 'progress_label', 'simple_table', 'developer_control' },
        zonesync = { 'poll', 'force', 'status', 'draw' },
        synchealth = { 'snapshot', 'status', 'draw', 'invalidate' },
        characterregistry = { 'snapshot', 'status', 'draw', 'remove', 'invalidate' },
        itemlocator = { 'poll', 'refresh_current', 'query', 'draw_search_matches', 'draw', 'status' },
        releasehealth = { 'status', 'setup_status', 'draw_setup', 'draw_settings', 'draw', 'export', 'reopen_setup', 'invalidate', 'initial_sync_report' },
        catalog_integrity = { 'run', 'status', 'draw' },
        catalog_coverage = { 'snapshot', 'issues', 'invalidate', 'draw', 'status', 'work_queue' },
        planner = { 'build', 'draw', 'status', 'classify', 'ranked' },
        search = { 'query', 'draw_bar', 'draw_results', 'text', 'active', 'clear', 'invalidate', 'rebuild', 'status' },
        smartdashboard = { 'snapshot', 'account_snapshot', 'draw', 'status' },
        weekly = { 'draw', 'draw_attention', 'draw_daily_avatars', 'avatar_daily_status' },
        sessions = { 'start', 'recover', 'complete', 'close', 'current' },
        automation = { 'poll', 'status' },
        learning = { 'poll', 'status', 'start', 'stop', 'mark' },
        capturewizard = { 'start_quest', 'stop', 'poll', 'active', 'current', 'history', 'capture_button', 'draw', 'status' },
        diagnostics = { 'record_error', 'error_status', 'errors', 'clear_errors', 'draw', 'draw_evidence_inspector' },
        regression = { 'run', 'status', 'draw' },
        anniversary = { 'draw', 'progress', 'automation_status', 'valid_2024_pointer', 'draw_automation_diagnostics' },
        seasonal = { 'draw', 'progress', 'events', 'reconcile', 'invalidate' },
        ui = { 'draw', 'navigate', 'consume_focus' },
    };

    local failures = {};
    for modname, fns in pairs(required) do
        local m = HC.modules[modname];
        if type(m) ~= 'table' then
            failures[#failures + 1] = modname .. ' missing';
        else
            for _, fn in ipairs(fns) do
                if type(m[fn]) ~= 'function' then
                    failures[#failures + 1] = modname .. '.' .. fn .. ' missing';
                end
            end
        end
    end

    for _, e in ipairs(HC.errors) do
        failures[#failures + 1] = e;
    end

    if HC.modules.regression and HC.modules.regression.run then
        local ok,rr=pcall(HC.modules.regression.run,false);
        if not ok then
            failures[#failures+1]='regression suite error: '..tostring(rr);
        elseif type(rr)=='table' and (tonumber(rr.failed) or 0)>0 then
            failures[#failures+1]='regression suite: '..tostring(rr.failed)..' failure(s)';
        end
    end

    HC.self_test_failures = failures;
    return #failures == 0;
end

ashita.events.register('load', 'horizoncheck_load', function()
    local migration_ok=true;
    local migration_err=nil;
    if HC.modules.state and HC.modules.state.migrate then
        local called,a,b=pcall(HC.modules.state.migrate);
        migration_ok=called and a~=false;
        migration_err=called and b or a;
        if not migration_ok and HC.modules.diagnostics then
            HC.modules.diagnostics.record_error('state migration',migration_err or 'migration failed');
            HC.ui.open[1]=true;
            HC.ui.show_diagnostics_tab=true;
        end
    end

    if migration_ok and HC.modules.userdata and HC.modules.userdata.cleanup_legacy then
        local cleanup_called,cleanup_ok,cleanup_err=pcall(HC.modules.userdata.cleanup_legacy);
        if (not cleanup_called or cleanup_ok==false) and HC.modules.diagnostics then
            HC.modules.diagnostics.record_error('user-data cleanup',cleanup_called and (cleanup_err or 'legacy addon cleanup failed') or cleanup_ok);
        end
    end

    local ok = self_test();
    if not ok then
        HC.msg('HorizonCheck loaded with ' .. tostring(#HC.self_test_failures) .. ' self-test issue(s). Open the Diagnostics tab.');
        HC.ui.open[1] = true;
        HC.ui.show_diagnostics_tab = true;
    end
    if HC.modules.releasehealth and HC.modules.releasehealth.invalidate then pcall(HC.modules.releasehealth.invalidate); end
end);

ashita.events.register('unload', 'horizoncheck_unload', function()
    if HC.modules.learning and HC.modules.learning.active and HC.modules.learning.active() then
        pcall(HC.modules.learning.stop, 'addon unload');
    end
    if HC.modules.state and HC.modules.state.save then
        pcall(HC.modules.state.save);
    end
end);

ashita.events.register('packet_in', 'horizoncheck_packet_in', function(e)
    local p = HC.modules.packets;
    if p and p.on_packet then
        local g=HC.modules.runtimeguard;
        local ok,err,guarded=nil,nil,false;
        if g and g.pcall then ok,err=g.pcall('packet_in',p.on_packet,e); guarded=true; else ok,err=pcall(p.on_packet,e); end
        if not ok and not guarded and HC.modules.diagnostics then HC.modules.diagnostics.record_error('packet_in',err); end
    end
end);

ashita.events.register('text_in', 'horizoncheck_text_in', function(e)
    local p = HC.modules.packets;
    if p and p.on_text then
        local g=HC.modules.runtimeguard;
        local ok,err,guarded=nil,nil,false;
        if g and g.pcall then ok,err=g.pcall('text_in',p.on_text,e); guarded=true; else ok,err=pcall(p.on_text,e); end
        if not ok and not guarded and HC.modules.diagnostics then HC.modules.diagnostics.record_error('text_in',err); end
    end
end);

local function words(s)
    local out = {};
    for w in string.gmatch(tostring(s or ''), '%S+') do out[#out + 1] = w; end
    return out;
end

-- Global HorizonCheck window hotkey: Shift+C.
-- Uses DirectInput key events directly instead of creating an Ashita /bind,
-- so HorizonCheck does not overwrite or remove a user's persistent bind table.
-- DirectInput scan codes: LSHIFT=42, RSHIFT=54, C=46.
local hc_hotkey_shift_down = false;

ashita.events.register('key_data', 'horizoncheck_shift_c_hotkey', function(e)
    local key = tonumber(e.key);
    if key == 42 or key == 54 then
        hc_hotkey_shift_down = (e.down == true);
        return;
    end

    if key == 46 and e.down == true and hc_hotkey_shift_down then
        HC.ui.open[1] = not HC.ui.open[1];
        -- Block the initial C key from normal game input while the modifier is held.
        -- This does not create or modify any Ashita /bind entry.
        e.blocked = true;
    end
end);

ashita.events.register('command', 'horizoncheck_command', function(e)
    local w = words(e.command);
    if #w == 0 then return; end
    local cmd = string.lower(w[1]);
    if cmd ~= '/hcheck' and cmd ~= '/horizoncheck' then return; end
    e.blocked = true;

    local sub = string.lower(w[2] or '');
    if sub == '' then
        HC.ui.open[1] = not HC.ui.open[1];
        return;
    elseif sub == 'show' then
        HC.ui.open[1] = true;
        return;
    elseif sub == 'hide' then
        HC.ui.open[1] = false;
        return;
    elseif sub == 'diag' or sub == 'diagnostics' then
        HC.ui.open[1] = true;
        HC.ui.show_diagnostics_tab = true;
        HC.msg('Diagnostics are in the main HorizonCheck window -> Diagnostics tab.');
        return;
    elseif sub == 'selftest' then
        local ok = self_test();
        HC.msg(ok and 'Self-test passed.' or ('Self-test failed: ' .. tostring(#HC.self_test_failures) .. ' issue(s).'));
        return;
    end

    for _, name in ipairs(order) do
        local m = HC.modules[name];
        if m and type(m.command) == 'function' then
            local g=HC.modules.runtimeguard;
            local ok,handled=nil,nil;
            if g and g.pcall then ok,handled=g.pcall('command.'..tostring(name),m.command,w,e.command);
            else ok,handled=pcall(m.command,w,e.command); end
            if ok and handled == true then return; end
        end
    end

    if developer_mode_enabled() then
        HC.msg('/hcheck | show | hide | diagnostics | selftest | health | setup | guard | evidence | regression | catalogaudit | coverage | canonical | integrity | selfheal | guided | availability | unlocks | profiler | watchdog | synchealth | dependencies | systems | progression | zonesync | timeline | auto | undo [event-id] | session | learn | tags | enm | digging | haap | keyitems | questprobe [log id]');
    else
        HC.msg('Commands: /hcheck opens or closes HorizonCheck. You can also use /hcheck show, /hcheck hide, /hcheck diagnostics, or /hcheck setup.');
    end
end);

local function profiled_pcall(label,fn,...)
    local g=HC.modules.runtimeguard;
    if g and g.pcall then
        local ok,a,b,c,d,e=g.pcall(label,fn,...);
        return ok,a,true,b,c,d,e;
    end
    local p=HC.modules.profiler;
    if p and p.pcall then return p.pcall(label,fn,...); end
    return pcall(fn,...);
end

ashita.events.register('d3d_present', 'horizoncheck_present', function()
    if HC.modules.state and HC.modules.state.poll then
        local ok, err, guarded = profiled_pcall('poll.state',HC.modules.state.poll);
        if not ok and not guarded and HC.modules.diagnostics then HC.modules.diagnostics.record_error('state deferred save poll', err); end
    end
    if HC.modules.keyitems and HC.modules.keyitems.poll then
        local ok, err, guarded = profiled_pcall('poll.keyitems',HC.modules.keyitems.poll);
        if not ok and not guarded and HC.modules.diagnostics then HC.modules.diagnostics.record_error('keyitems incremental poll', err); end
    end
    if HC.modules.learning and HC.modules.learning.poll then
        local ok, err, guarded = profiled_pcall('poll.learning',HC.modules.learning.poll);
        if not ok and not guarded and HC.modules.diagnostics then HC.modules.diagnostics.record_error('learning poll', err); end
    end
    if HC.modules.capturewizard and HC.modules.capturewizard.poll then
        local ok, err, guarded = profiled_pcall('poll.capturewizard',HC.modules.capturewizard.poll);
        if not ok and not guarded and HC.modules.diagnostics then HC.modules.diagnostics.record_error('capture wizard poll', err); end
    end
    if HC.modules.automation and HC.modules.automation.poll then
        local ok, err, guarded = profiled_pcall('poll.automation',HC.modules.automation.poll);
        if not ok and not guarded and HC.modules.diagnostics then HC.modules.diagnostics.record_error('automation poll', err); end
    end
    if HC.modules.progression and HC.modules.progression.poll then
        local ok, err, guarded = profiled_pcall('poll.progression',HC.modules.progression.poll);
        if not ok and not guarded and HC.modules.diagnostics then HC.modules.diagnostics.record_error('progression poll', err); end
    end
    if HC.modules.integrity and HC.modules.integrity.poll then
        local ok, err, guarded = profiled_pcall('poll.integrity',HC.modules.integrity.poll);
        if not ok and not guarded and HC.modules.diagnostics then HC.modules.diagnostics.record_error('state integrity poll', err); end
    end
    if HC.modules.performance_watchdog and HC.modules.performance_watchdog.poll then
        local ok, err, guarded = profiled_pcall('poll.performance_watchdog',HC.modules.performance_watchdog.poll);
        if not ok and not guarded and HC.modules.diagnostics then HC.modules.diagnostics.record_error('performance watchdog poll', err); end
    end
    if HC.modules.selfheal and HC.modules.selfheal.poll then
        local ok, err, guarded = profiled_pcall('poll.selfheal',HC.modules.selfheal.poll);
        if not ok and not guarded and HC.modules.diagnostics then HC.modules.diagnostics.record_error('self-healing provider poll', err); end
    end
    if HC.modules.zonesync and HC.modules.zonesync.poll then
        local ok, err, guarded = profiled_pcall('poll.zonesync',HC.modules.zonesync.poll);
        if not ok and not guarded and HC.modules.diagnostics then HC.modules.diagnostics.record_error('zone sync poll', err); end
    end
    if HC.modules.plantpots and HC.modules.plantpots.poll then
        local ok, err, guarded = profiled_pcall('poll.plantpots',HC.modules.plantpots.poll);
        if not ok and not guarded and HC.modules.diagnostics then HC.modules.diagnostics.record_error('plantpots poll', err); end
    end
    local u = HC.modules.ui;
    if u and u.draw then
        local ok, err, guarded = profiled_pcall('ui.main',u.draw);
        if not ok then
            if not guarded and HC.modules.diagnostics then
                HC.modules.diagnostics.record_error('ui', err);
            end
            HC.ui.open[1] = true;
            HC.ui.show_diagnostics_tab = true;
            HC.msg('UI module error captured. Diagnostics remain in the main HorizonCheck window.');
            -- Surface the actual runtime reason as well; the old generic-only
            -- message made field reports impossible to diagnose when a binding
            -- differed from the release-test stub.
            if err ~= nil then HC.msg('UI error: '..tostring(err)); end
        end
    end
end);
