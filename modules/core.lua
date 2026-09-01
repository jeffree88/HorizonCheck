local M = {};
local HC;

function M.init(ctx) HC = ctx; end

function M.character_name()
    local name = nil;
    pcall(function()
        local p = AshitaCore:GetMemoryManager():GetParty();
        if p ~= nil then name = p:GetMemberName(0); end
    end);
    if type(name) ~= 'string' or name == '' then return 'Unknown'; end
    return name;
end

function M.jst_now()
    return os.time() + (9 * 60 * 60);
end

function M.daily_key()
    local t = os.date('!*t', M.jst_now());
    return string.format('%04d-%02d-%02d', t.year, t.month, t.day);
end

function M.weekly_key()
    local ts = M.jst_now();
    local t = os.date('!*t', ts);
    local days_since_monday = (t.wday + 5) % 7;
    local m = os.date('!*t', ts - (days_since_monday * 86400));
    return string.format('%04d-%02d-%02d', m.year, m.month, m.day);
end


function M.seconds_until_daily_reset()
    local ts = M.jst_now();
    local t = os.date('!*t', ts);
    local seconds_today = (t.hour * 3600) + (t.min * 60) + t.sec;
    local remain = 86400 - seconds_today;
    if remain <= 0 then remain = 86400; end
    return remain;
end

function M.next_daily_reset_jst()
    local remain = M.seconds_until_daily_reset();
    local t = os.date('!*t', M.jst_now() + remain);
    return string.format('%04d-%02d-%02d 00:00 JST', t.year, t.month, t.day);
end

function M.seconds_until_weekly_reset()
    local ts = M.jst_now();
    local t = os.date('!*t', ts);
    -- Lua wday: Sunday=1, Monday=2 ... Saturday=7.
    local days_until_monday = (9 - t.wday) % 7;

    -- If it is Monday, reset is next Monday unless we are exactly at 00:00:00.
    if days_until_monday == 0 then
        days_until_monday = 7;
    end

    local seconds_today = (t.hour * 3600) + (t.min * 60) + t.sec;
    local remain = (days_until_monday * 86400) - seconds_today;

    -- Defensive fallback.
    if remain <= 0 then remain = remain + (7 * 86400); end
    return remain;
end

function M.next_weekly_reset_jst()
    local remain = M.seconds_until_weekly_reset();
    local t = os.date('!*t', M.jst_now() + remain);
    return string.format('%04d-%02d-%02d 00:00 JST', t.year, t.month, t.day);
end

function M.format_duration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0));
    local d = math.floor(seconds / 86400);
    local h = math.floor((seconds % 86400) / 3600);
    local m = math.floor((seconds % 3600) / 60);
    local s = seconds % 60;
    if d > 0 then return string.format('%dd %02d:%02d:%02d', d, h, m, s); end
    return string.format('%02d:%02d:%02d', h, m, s);
end

function M.clean_text(s)
    s = tostring(s or '');
    s = s:gsub('[%z\1-\31]', ' ');
    s = s:gsub('%s+', ' ');
    return string.lower(s);
end

return M;
