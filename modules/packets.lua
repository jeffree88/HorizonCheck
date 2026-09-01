local M = {};
local incoming={};
local HC;
local handlers = {};
local text_handlers = {};
local tap_handlers = {};
local recent = {};

function M.init(ctx) HC = ctx; end

function M.register(id, name, fn)
    handlers[id] = handlers[id] or {};
    handlers[id][#handlers[id] + 1] = { name = name, fn = fn };
end

function M.register_text(name, fn)
    text_handlers[#text_handlers + 1] = { name = name, fn = fn };
end

function M.register_tap(name, fn)
    tap_handlers[#tap_handlers + 1] = { name = name, fn = fn };
end

function M.on_packet(e)
    if e == nil or e.injected then return; end
    local id = tonumber(e.id) or 0;

    -- v6.0.14: dispatch generic incoming-packet subscribers.
    -- v6.0.13 registered these callbacks but never invoked them.
    for name,fn in pairs(incoming) do
        local ok,err=pcall(fn,id,e.data_raw or e.data or e);
        if not ok and HC.modules.diagnostics then
            HC.modules.diagnostics.record_error('packet in '..tostring(name),err);
        end
    end

    recent[#recent + 1] = { at = os.time(), id = id, size = tonumber(e.size) or 0 };
    while #recent > 80 do table.remove(recent, 1); end

    for _, h in ipairs(tap_handlers) do
        local ok, err = pcall(h.fn, e);
        if not ok and HC.modules.diagnostics then
            HC.modules.diagnostics.record_error('packet tap ' .. h.name, err);
        end
    end

    local list = handlers[id];
    if list ~= nil then
        for _, h in ipairs(list) do
            local ok, err = pcall(h.fn, e);
            if not ok and HC.modules.diagnostics then
                HC.modules.diagnostics.record_error('packet ' .. h.name, err);
            end
        end
    end
end

function M.on_text(e)
    if e == nil or e.injected then return; end
    local s = HC.modules.core.clean_text(e.message);
    for _, h in ipairs(text_handlers) do
        local ok, err = pcall(h.fn, s, e);
        if not ok and HC.modules.diagnostics then
            HC.modules.diagnostics.record_error('text ' .. h.name, err);
        end
    end
end

function M.recent() return recent; end

function M.register_in(name,fn)
    if type(name)=='string' and type(fn)=='function' then incoming[name]=fn; end
end

return M;
