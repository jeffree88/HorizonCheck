local M = {};
local HC;

local status={
    root=nil,
    requested_root=nil,
    external=false,
    writable=false,
    fallback=false,
    reason=nil,
    migrated_state=false,
    migrated_outposts=false,
    copied_legacy_files=false,
    legacy_cleanup_attempted=false,
    legacy_cleanup_complete=false,
    legacy_cleanup_removed=0,
    legacy_cleanup_preserved=0,
    legacy_cleanup_failed=0,
    legacy_cleanup_at=nil,
    legacy_cleanup_waiting=false,
    legacy_cleanup_errors={},
};

local dirs={};

local state_backup_suffixes={
    '.bak1','.bak2','.bak3',
    '.migration.bak1','.migration.bak2','.migration.bak3',
    '.migration.info','.before_restore.bak',
};

local legacy_patterns={
    {'horizoncheck_capture_*.txt','captures'},
    {'horizoncheck_guided_*.txt','captures'},
    {'horizoncheck_mission_packets_*.txt','captures'},
    {'horizoncheck_learning_*.log','logs'},
    {'horizoncheck_audit_*.log','logs'},
    {'horizoncheck_release_health_*.txt','reports'},
    {'horizoncheck_quest_state_*.txt','reports'},
};

local function trim_slash(s)
    return tostring(s or ''):gsub('[\\/]+$','');
end

local function exists(path)
    local f=io.open(path,'rb');
    if f then f:close(); return true; end
    return false;
end

local function mkdir(path)
    if type(path)~='string' or path=='' then return false; end
    pcall(function() os.execute('mkdir "'..path..'" >NUL 2>NUL'); end);
    return true;
end

local function copy_file(src,dst)
    local f=io.open(src,'rb');
    if not f then return false; end
    local data=f:read('*a'); f:close();
    local o=io.open(dst,'wb');
    if not o then return false; end
    o:write(data); o:close();
    return true;
end

local function same_file(a,b)
    local fa=io.open(a,'rb');
    if not fa then return false; end
    local fb=io.open(b,'rb');
    if not fb then fa:close(); return false; end
    local same=true;
    while true do
        local ca=fa:read(65536);
        local cb=fb:read(65536);
        if ca~=cb then same=false; break; end
        if ca==nil then break; end
    end
    fa:close(); fb:close();
    return same;
end

local function validate_state_file(path)
    local fn,err=loadfile(path);
    if not fn then return false,tostring(err); end
    local ok,data=pcall(fn);
    if not ok or type(data)~='table' then return false,tostring(data or 'state root is not a table'); end
    if type(data.chars)~='table' then return false,'chars table missing'; end
    if type(data.account)~='table' then return false,'account table missing'; end
    if type(data.account_weekly)~='table' then return false,'account_weekly table missing'; end
    if tonumber(data.schema)==nil then return false,'schema marker missing'; end
    return true,nil;
end

local function writable_dir(path)
    mkdir(path);
    local test=trim_slash(path)..'\\.horizoncheck_write_test';
    local f,err=io.open(test,'w');
    if not f then return false,err; end
    f:write('ok\n'); f:close(); os.remove(test);
    return true,nil;
end

local function set_fallback(reason)
    local root=tostring(HC and HC.addon_path or '');
    status.root=root;
    status.external=false;
    status.writable=true;
    status.fallback=true;
    status.reason=tostring(reason or 'external user-data folder unavailable');
    dirs={root=root,backups=root,captures=root,logs=root,reports=root};
end

local function configure_external(root)
    root=trim_slash(root)..'\\';
    local ok,err=writable_dir(root);
    if not ok then set_fallback('config user-data folder is not writable: '..tostring(err or root)); return false; end

    dirs={
        root=root,
        backups=root..'backups\\',
        captures=root..'captures\\',
        logs=root..'logs\\',
        reports=root..'reports\\',
    };
    for k,p in pairs(dirs) do
        local dir=trim_slash(p);
        mkdir(dir);
        local subok,suberr=writable_dir(dir);
        if not subok then
            set_fallback('config user-data '..tostring(k)..' folder is not writable: '..tostring(suberr or dir));
            return false;
        end
    end

    status.root=root;
    status.external=true;
    status.writable=true;
    status.fallback=false;
    return true;
end

local function verified_copy(src,dst)
    if not copy_file(src,dst) then return false,'copy failed'; end
    if not same_file(src,dst) then
        os.remove(dst);
        return false,'copy verification failed';
    end
    return true,nil;
end

local function list_pattern(source,pattern)
    local out={};
    if status.external~=true or not dirs.root then return out; end
    local listfile=dirs.root..'.legacy_cleanup_list.tmp';
    os.remove(listfile);
    pcall(function()
        os.execute('dir /B /A-D "'..trim_slash(source)..'\\'..tostring(pattern)..'" > "'..listfile..'" 2>NUL');
    end);
    local f=io.open(listfile,'r');
    if f then
        for line in f:lines() do
            local name=tostring(line or ''):gsub('[\r\n]+$','');
            if name~='' and not name:find('[\\/]') then out[#out+1]=name; end
        end
        f:close();
    end
    os.remove(listfile);
    return out;
end

local function unique_legacy_path(dir,name)
    local base=trim_slash(dir)..'\\legacy_addon_'..tostring(name);
    if not exists(base) then return base; end
    local n=2;
    while n<1000 do
        local p=trim_slash(dir)..'\\legacy_addon_'..tostring(n)..'_'..tostring(name);
        if not exists(p) then return p; end
        n=n+1;
    end
    return trim_slash(dir)..'\\legacy_addon_'..tostring(os.time())..'_'..tostring(name);
end

local function migrate_state()
    if status.external~=true then return true; end
    local old=tostring(HC.addon_path or '')..'horizoncheck_state.lua';
    local new=dirs.root..'horizoncheck_state.lua';
    if exists(new) or not exists(old) then return true; end

    local tmp=new..'.migrate_tmp';
    os.remove(tmp);
    if not copy_file(old,tmp) then return false,'could not copy legacy state'; end
    local valid,err=validate_state_file(tmp);
    if not valid then os.remove(tmp); return false,'legacy state validation failed: '..tostring(err); end
    os.remove(new);
    if not os.rename(tmp,new) then
        if not copy_file(tmp,new) then os.remove(tmp); return false,'could not install migrated state'; end
        os.remove(tmp);
    end
    local installed,install_err=validate_state_file(new);
    if not installed then
        os.remove(new);
        return false,'migrated state verification failed: '..tostring(install_err);
    end
    status.migrated_state=true;
    return true;
end

local function migrate_state_backups()
    if status.external~=true then return; end
    local oldbase=tostring(HC.addon_path or '')..'horizoncheck_state.lua';
    local newbase=dirs.backups..'horizoncheck_state.lua';
    for _,suffix in ipairs(state_backup_suffixes) do
        local src=oldbase..suffix; local dst=newbase..suffix;
        if exists(src) and not exists(dst) then
            local ok=verified_copy(src,dst);
            if ok then status.copied_legacy_files=true; end
        end
    end
end

local function migrate_outposts(install_root)
    if status.external~=true then return; end
    local dst=dirs.root..'horizoncheck_outposts_persistent.lua';
    if exists(dst) then return; end
    local candidates={
        tostring(HC.addon_path or '')..'horizoncheck_outposts_persistent.lua',
    };
    if install_root and install_root~='' then candidates[#candidates+1]=trim_slash(install_root)..'\\config\\HorizonCheck_outposts.lua'; end
    for _,src in ipairs(candidates) do
        if exists(src) then
            local ok=verified_copy(src,dst);
            if ok then status.migrated_outposts=true; status.copied_legacy_files=true; return; end
        end
    end
end

local function copy_legacy_patterns()
    if status.external~=true then return; end
    local source=trim_slash(HC.addon_path or '');
    if source=='' then return; end
    for _,it in ipairs(legacy_patterns) do
        local destination=dirs[it[2]];
        for _,name in ipairs(list_pattern(source,it[1])) do
            local src=source..'\\'..name;
            local dst=destination..name;
            if not exists(dst) then
                local ok=verified_copy(src,dst);
                if ok then status.copied_legacy_files=true; end
            elseif same_file(src,dst) then
                status.copied_legacy_files=true;
            end
        end
    end
end

local function cleanup_error(text)
    status.legacy_cleanup_failed=(tonumber(status.legacy_cleanup_failed) or 0)+1;
    local errors=status.legacy_cleanup_errors;
    errors[#errors+1]=tostring(text or 'unknown cleanup error');
end

local function remove_verified_legacy(src,dst,collision_dir,name)
    if not exists(src) then return true; end

    if exists(dst) then
        if not same_file(src,dst) then
            local archive=unique_legacy_path(collision_dir,name);
            local ok,err=verified_copy(src,archive);
            if not ok then
                cleanup_error('could not preserve '..tostring(name)..' before cleanup: '..tostring(err));
                return false;
            end
            status.legacy_cleanup_preserved=(tonumber(status.legacy_cleanup_preserved) or 0)+1;
        end
    else
        local ok,err=verified_copy(src,dst);
        if not ok then
            cleanup_error('could not migrate '..tostring(name)..' before cleanup: '..tostring(err));
            return false;
        end
    end

    if not os.remove(src) then
        cleanup_error('could not remove legacy addon file: '..tostring(name));
        return false;
    end
    status.legacy_cleanup_removed=(tonumber(status.legacy_cleanup_removed) or 0)+1;
    return true;
end

local function remove_temp(src,name)
    if not exists(src) then return true; end
    if not os.remove(src) then
        cleanup_error('could not remove abandoned temporary file: '..tostring(name));
        return false;
    end
    status.legacy_cleanup_removed=(tonumber(status.legacy_cleanup_removed) or 0)+1;
    return true;
end

local function has_legacy_user_files(source)
    local exact={
        'horizoncheck_state.lua',
        'horizoncheck_outposts_persistent.lua',
        'horizoncheck_state.lua.tmp',
        'horizoncheck_state.lua.migrate_tmp',
        'horizoncheck_state.lua.write_test',
        '.horizoncheck_write_test',
    };
    for _,suffix in ipairs(state_backup_suffixes) do exact[#exact+1]='horizoncheck_state.lua'..suffix; end
    for _,name in ipairs(exact) do
        if exists(source..'\\'..name) then return true; end
    end
    for _,it in ipairs(legacy_patterns) do
        if #list_pattern(source,it[1])>0 then return true; end
    end
    return false;
end

function M.cleanup_legacy()
    status.legacy_cleanup_attempted=true;
    status.legacy_cleanup_complete=false;
    status.legacy_cleanup_removed=0;
    status.legacy_cleanup_preserved=0;
    status.legacy_cleanup_failed=0;
    status.legacy_cleanup_errors={};
    status.legacy_cleanup_at=os.time();
    status.legacy_cleanup_waiting=false;

    if status.external~=true then
        cleanup_error('config-backed user data is not active; legacy addon data was left untouched');
        return false,status.legacy_cleanup_errors[1];
    end

    local source=trim_slash(HC.addon_path or '');
    if source=='' then
        cleanup_error('addon path unavailable; legacy addon data was left untouched');
        return false,status.legacy_cleanup_errors[1];
    end

    -- Fresh installs have nothing to clean and may not have written their first
    -- state file yet. Treat that as a clean result rather than a storage error.
    if not has_legacy_user_files(source) then
        status.legacy_cleanup_complete=true;
        return true,nil;
    end

    local new_state=dirs.root..'horizoncheck_state.lua';
    if not exists(new_state) then
        -- A brand-new config profile is persisted on the normal save path. Do
        -- not remove any legacy files until that authoritative file exists.
        status.legacy_cleanup_waiting=true;
        return true,'waiting for first config state save';
    end
    local valid,err=validate_state_file(new_state);
    if not valid then
        cleanup_error('config state did not pass validation; legacy addon data was left untouched: '..tostring(err));
        return false,status.legacy_cleanup_errors[1];
    end

    -- Active state: when the config state has diverged from the legacy copy,
    -- preserve the old copy under config\\backups before removing it.
    remove_verified_legacy(
        source..'\\horizoncheck_state.lua',
        new_state,
        dirs.backups,
        'horizoncheck_state.lua'
    );

    for _,suffix in ipairs(state_backup_suffixes) do
        local name='horizoncheck_state.lua'..suffix;
        remove_verified_legacy(
            source..'\\'..name,
            dirs.backups..name,
            dirs.backups,
            name
        );
    end

    local outpost_name='horizoncheck_outposts_persistent.lua';
    remove_verified_legacy(
        source..'\\'..outpost_name,
        dirs.root..outpost_name,
        dirs.backups,
        outpost_name
    );

    for _,it in ipairs(legacy_patterns) do
        local destination=dirs[it[2]];
        for _,name in ipairs(list_pattern(source,it[1])) do
            remove_verified_legacy(
                source..'\\'..name,
                destination..name,
                destination,
                name
            );
        end
    end

    -- These are incomplete transaction/write probes, not user history. They are
    -- safe to remove only after the authoritative config state validated above.
    local temps={
        'horizoncheck_state.lua.tmp',
        'horizoncheck_state.lua.migrate_tmp',
        'horizoncheck_state.lua.write_test',
        '.horizoncheck_write_test',
    };
    for _,name in ipairs(temps) do remove_temp(source..'\\'..name,name); end

    status.legacy_cleanup_complete=(tonumber(status.legacy_cleanup_failed) or 0)==0;
    if status.legacy_cleanup_complete then return true,nil; end
    return false,table.concat(status.legacy_cleanup_errors,'; ');
end

function M.init(ctx)
    HC=ctx;
    local install=nil;
    pcall(function()
        if AshitaCore and AshitaCore.GetInstallPath then install=AshitaCore:GetInstallPath(); end
    end);
    install=trim_slash(install);
    if install=='' then
        set_fallback('Ashita install path unavailable');
    else
        status.requested_root=install..'\\config\\addons\\horizoncheck\\';
        configure_external(status.requested_root);
    end

    if status.external then
        local ok,err=migrate_state();
        if not ok then
            -- Never silently abandon a legacy state file. If it cannot be
            -- validated/copied, continue using the old proven addon location.
            set_fallback(err);
        else
            migrate_state_backups();
            migrate_outposts(install);
            copy_legacy_patterns();
        end
    end

    HC.user_data_path=status.root;
    HC.user_dirs=dirs;
end

function M.path(kind,filename)
    local base=dirs[tostring(kind or 'root')] or dirs.root or (HC and HC.addon_path) or '';
    return tostring(base or '')..tostring(filename or '');
end

function M.root() return status.root; end
function M.dirs()
    local o={}; for k,v in pairs(dirs) do o[k]=v; end return o;
end
function M.status()
    local o={};
    for k,v in pairs(status) do
        if type(v)=='table' then
            local t={}; for i,x in ipairs(v) do t[i]=x; end o[k]=t;
        else o[k]=v; end
    end
    return o;
end
function M.external() return status.external==true; end

return M;
