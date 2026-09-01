local M = {};
local HC;

local function normalize_item_name(s)
    s=string.lower(tostring(s or ''));
    s=s:gsub('[%c%p]+',' ');
    s=s:gsub('%s+',' ');
    s=s:gsub('^%s+',''):gsub('%s+$','');
    -- Normalize simple English plurals used by GP rewards.
    if s:sub(-3)=='ies' then
        s=s:sub(1,-4)..'y';
    elseif s:sub(-2)=='es' then
        local stem=s:sub(1,-3);
        if stem:sub(-1)=='s' or stem:sub(-1)=='x' or stem:sub(-1)=='z'
            or stem:sub(-2)=='ch' or stem:sub(-2)=='sh' then
            s=stem;
        elseif s:sub(-1)=='s' then
            s=s:sub(1,-2);
        end
    elseif s:sub(-1)=='s' and s:sub(-2)~='ss' then
        s=s:sub(1,-2);
    end
    return s;
end

local function text_debounced(g,key,value,seconds)
    g._text_seen=type(g._text_seen)=='table' and g._text_seen or {};
    local now=os.time();
    local sig=tostring(value or '');
    local prev=g._text_seen[key];
    if prev and prev.sig==sig and now-(prev.at or 0) <= (seconds or 2) then return true; end
    g._text_seen[key]={sig=sig,at=now};
    return false;
end


local guilds = {
    'Fishing','Woodworking','Smithing','Goldsmithing','Clothcraft',
    'Leathercraft','Bonecraft','Alchemy','Cooking'
};

-- HorizonXI maintains a server-specific master table of every rotating GP request.
-- Runtime linking intentionally does not scrape the wiki: the detected NPC item name
-- is sent to MediaWiki's exact/search route, which keeps the addon offline-safe while
-- still following Horizon-specific page naming and redirects.
local GP_MASTER_LIST_URL='https://horizonffxi.wiki/Guild_Points/Items';
local HORIZON_WIKI_SEARCH_BASE='https://horizonffxi.wiki/Special:Search/';

local function guild_trim(s)
    return tostring(s or ''):gsub('^%s+',''):gsub('%s+$','');
end

local function wiki_path_encode(s)
    s=tostring(s or '');
    -- Path-safe percent encoding. Spaces become %20; cmd.exe metacharacters are
    -- encoded as well so the quoted browser command never receives raw shell syntax.
    return (s:gsub('([^%w%-%._~])',function(ch)
        return string.format('%%%02X',string.byte(ch));
    end));
end

local function recipe_item_name(s)
    s=guild_trim(tostring(s or ''));
    s=s:gsub('[%?%!%.,]+$','');
    local low=string.lower(s);
    local prefixes={
        'a pair of ','a bowl of ','a plate of ','a dish of ','a serving of ',
        'a stack of ','a piece of ','an ','a '
    };
    for _,prefix in ipairs(prefixes) do
        if low:sub(1,#prefix)==prefix then
            s=guild_trim(s:sub(#prefix+1));
            break;
        end
    end
    -- Dialogue occasionally includes a trade quantity after the item name.
    s=s:gsub('%s+[xX]%s*%d+%s*$','');
    s=s:gsub('%s+',' ');
    return guild_trim(s);
end

local function requested_item_wiki_url(item)
    local clean=recipe_item_name(item);
    if clean=='' then return nil; end
    -- Special:Search is deliberately used rather than guessing MediaWiki title case.
    -- Exact item matches are resolved by the wiki while unusual punctuation / HQ names
    -- continue to produce a useful item search instead of a broken hard-coded URL.
    return HORIZON_WIKI_SEARCH_BASE..wiki_path_encode(clean);
end

local function open_url(url)
    if type(url)~='string' or url=='' then return false; end
    local ok=pcall(function() os.execute('cmd /c start "" "'..url..'"'); end);
    return ok;
end

local guild_by_union_npc = {
    ['fennella']='Fishing',
    ['andreas']='Woodworking',
    ['lorena']='Smithing',
    ['macuillie']='Smithing',
    ['ellard']='Goldsmithing',
    ['hauh colphioh']='Clothcraft',
    ['alivatand']='Leathercraft',
    ['samigo-pormigo']='Bonecraft',
    ['hemewmew']='Alchemy',
    ['qhum knaidjn']='Cooking',
};

local function normalize_npc_name(s)
    s=string.lower(tostring(s or ''));
    -- Do not depend on trim() here; this helper is declared earlier in the file.
    -- Strip control/punctuation noise from HorizonXI/Ashita speaker prefixes,
    -- normalize whitespace, and preserve internal '-' used by NPC names.
    s=s:gsub('[%c]+',' ');
    s=s:gsub('^%s+',''):gsub('%s+$','');
    s=s:gsub('%s+',' ');
    return s;
end

local function guild_from_union_npc(name)
    return guild_by_union_npc[normalize_npc_name(name)];
end

local last_menu = nil;
local learner = nil;

local function ensure(c)
    c.guild_points = type(c.guild_points) == 'table' and c.guild_points or {};
    local g = c.guild_points;
    g.guild = tostring(g.guild or 'Unknown');
    g.points = tonumber(g.points) or 0;
    g.packet = type(g.packet) == 'table' and g.packet or nil;
    g.text_auto = g.text_auto ~= false;
    g.pending_purchase = type(g.pending_purchase) == 'table' and g.pending_purchase or nil;

    -- v6.1.23: Guild Point assignments and completion are daily-only state.
    -- Preserve the selected guild and current GP balance across reset, but
    -- never carry yesterday's requested item/progress into a new game day.
    local day_key = HC and HC.modules and HC.modules.core and HC.modules.core.daily_key and HC.modules.core.daily_key() or nil;
    if day_key ~= nil and g.daily_key ~= day_key then
        g.daily_key = day_key;
        g.requested_item = nil;
        g.requested_item_at = nil;
        g.daily_status = nil;
        g.daily_confidence = nil;
        g.daily_remaining_gp = nil;
        g.daily_earned_gp = 0;
        g.daily_max_gp = nil;
        g.daily_progress_observed = nil;
        g.daily_progress_at = nil;
        g.daily_verified_at = nil;
        g.daily_verified_npc = nil;
        g.pending_purchase = nil;
        g.last_change = nil;

        c.daily = type(c.daily) == 'table' and c.daily or {};
        c.daily.guild_points = nil;

        if HC.modules.state then HC.modules.state.save(); end
    end

    return g;
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
            if idx == nil or tonumber(idx) == 0 then
                pcall(function() idx = t:GetTargetIndex(); end);
            end
        end

        idx = tonumber(idx);
        if ent ~= nil and idx ~= nil and idx > 0 then
            name = ent:GetName(idx);
        end
    end);
    return tostring(name or '');
end

local function u16le(s, pos)
    if type(s) ~= 'string' or #s < pos + 1 then return nil; end
    local a, b = string.byte(s, pos, pos + 1);
    return a + b * 256;
end

local function u32le(s, pos)
    if type(s) ~= 'string' or #s < pos + 3 then return nil; end
    local a,b,c,d = string.byte(s, pos, pos + 3);
    return a + b * 256 + c * 65536 + d * 16777216;
end

local function find_value_offsets(data, value)
    local out = {};
    if type(data) ~= 'string' then return out; end
    value = tonumber(value);
    if value == nil then return out; end

    for pos = 5, #data - 1 do
        if u16le(data, pos) == value then
            out[#out + 1] = { offset = pos, width = 2 };
        end
    end

    for pos = 5, #data - 3 do
        if u32le(data, pos) == value then
            out[#out + 1] = { offset = pos, width = 4 };
        end
    end

    return out;
end

local function read_mapping(data, map)
    if type(data) ~= 'string' or type(map) ~= 'table' then return nil; end
    local off = tonumber(map.offset);
    local width = tonumber(map.width);
    if off == nil or width == nil then return nil; end
    if width == 2 then return u16le(data, off); end
    if width == 4 then return u32le(data, off); end
    return nil;
end

local function same_target(a, b)
    if type(a) ~= 'string' or type(b) ~= 'string' then return false; end
    return string.lower(a) == string.lower(b);
end

local function valid_guild(name)
    local wanted = string.lower(tostring(name or ''));
    for _, g in ipairs(guilds) do
        if string.lower(g) == wanted then return g; end
    end
    return nil;
end

local function save_mapping(c, guild_name, npc, candidate)
    local g = ensure(c);
    g.guild = guild_name;
    g.packet = {
        packet_id = 0x034,
        npc = npc,
        offset = candidate.offset,
        width = candidate.width,
    };
    g.last_auto_update = os.time();
    HC.modules.state.save();
end

local function candidate_key(c)
    return tostring(c.offset) .. ':' .. tostring(c.width);
end

local function capture_menu(e)
    if e == nil or e.injected or tonumber(e.id) ~= 0x034 then return; end
    local npc = target_name();
    if npc == '' then return; end

    last_menu = {
        at = os.time(),
        npc = npc,
        data = e.data,
        size = tonumber(e.size) or 0,
    };

    local c = HC.modules.state.get_char();
    local g = ensure(c);
    local map = g.packet;

    if type(map) == 'table' and same_target(npc, map.npc) then
        local points = read_mapping(e.data, map);
        if type(points) == 'number' and points >= 0 and points <= 1000000 then
            if g.points ~= points then
                g.points = points;
                g.last_auto_update = os.time();
                HC.modules.state.save();
                HC.msg(string.format('Guild Points auto-updated: %s | %d GP', g.guild, g.points));
            end
        end
    end
end

local function trim(s)
    return tostring(s or ''):match('^%s*(.-)%s*$');
end

local function digits(s)
    s = tostring(s or ''):gsub(',', '');
    return tonumber(s);
end

local function item_key(s)
    s = string.lower(trim(s));
    s = s:gsub('[%?%!%.,]+$', '');
    s = s:gsub('^a pair of%s+', '');
    s = s:gsub('^an%s+', '');
    s = s:gsub('^a%s+', '');
    s = trim(s):gsub('%s+', ' ');
    -- Guild purchases commonly prompt with a plural item and award one singular item.
    s = s:gsub('s$', '');
    return s;
end

local function compact_requested_item(s)
    s=trim(tostring(s or ''));
    local low=string.lower(s);
    low=low:gsub('^a pair of%s+','');
    low=low:gsub('^a bowl of%s+','');
    low=low:gsub('^a plate of%s+','');
    low=low:gsub('^a dish of%s+','');
    low=low:gsub('^a serving of%s+','');
    low=low:gsub('^an%s+','');
    low=low:gsub('^a%s+','');
    low=trim(low):gsub('%s+',' ');
    return low;
end

local function daily_progress(g)
    local earned=math.max(0,math.floor(tonumber(g.daily_earned_gp) or 0));
    local remaining=tonumber(g.daily_remaining_gp);
    if remaining~=nil then remaining=math.max(0,math.floor(remaining)); end

    local maximum=tonumber(g.daily_max_gp);
    if maximum~=nil then maximum=math.max(0,math.floor(maximum)); end

    if remaining~=nil then
        local derived=earned+remaining;
        if maximum==nil or derived>maximum or g.daily_status=='AVAILABLE' or g.daily_status=='PARTIAL' then
            maximum=derived;
        end
    elseif g.daily_status=='COMPLETE' and earned>0 and maximum==nil then
        maximum=earned;
    end

    local percent=nil;
    if maximum and maximum>0 then
        percent=math.max(0,math.min(100,(earned/maximum)*100));
    end
    return earned,remaining,maximum,percent;
end


local function mark_daily_checked(c, why)
    c.daily=type(c.daily)=='table' and c.daily or {};
    if c.daily.guild_points~=true then
        c.daily.guild_points=true;
        if HC.modules.automation and HC.modules.automation.record_external then
            HC.modules.automation.record_external(c,'guild_points',tostring(why or 'Guild Union NPC checked'),{scope='daily',key='guild_points',old=nil});
        end
    end
end

local function set_last_change(g, kind, before, after, amount, item, source)
    g.last_change={
        at=os.time(), kind=tostring(kind or 'sync'), before=tonumber(before), after=tonumber(after),
        amount=tonumber(amount), item=item and tostring(item) or nil, source=tostring(source or 'unknown'),
    };
end

local function source_npc(s)
    local raw=tostring(s or '');
    local n=raw:match('^%s*([^:]+)%s*:');
    if n==nil then return nil; end

    -- Echoed chat may include a timestamp wrapper before the NPC name.
    n=n:gsub('^q%[[^%]]+%]%s*','');
    n=n:gsub('[%c]+',' ');
    n=n:gsub('^%s+',''):gsub('%s+$','');
    n=n:gsub('%s+',' ');
    if n=='' then return nil; end
    return n;
end

local function sync_guild_from_npc(g, npc, announce)
    local craft=guild_from_union_npc(npc);
    if not craft then return false; end

    local changed=g.guild~=craft;
    g.guild=craft;
    g.last_npc=npc;
    g.last_guild_auto_at=os.time();
    g.last_guild_auto_source='Guild Union NPC';

    if changed and announce then
        HC.msg(string.format('Guild auto-detected: %s (%s).',craft,tostring(npc)));
    end
    return changed;
end

local function on_text(s)
    local c = HC.modules.state.get_char();
    local g = ensure(c);
    if g.pending_purchase and os.time()-(g.pending_purchase.at or 0)>30 then g.pending_purchase=nil; end
    if not g.text_auto then return; end
    local lower = string.lower(tostring(s or ''));
    local now = os.time();

    -- Auto-identify the active Guildworker Union from the speaking NPC.
    -- This updates Guild: UNKNOWN even before the balance/requested-item line.
    local speaking_npc=source_npc(lower);
    local changed=false;
    if speaking_npc then
        changed=sync_guild_from_npc(g,speaking_npc,true) or changed;
    end

    -- Fallback: search the dialogue prefix for a known Union NPC name.
    -- This is safe because it only runs on Guild Points dialogue parsing and
    -- only accepts names in the explicit Guild Union mapping.
    if g.guild=='Unknown' then
        for npc_key,_ in pairs(guild_by_union_npc) do
            if lower:find(npc_key,1,true) then
                changed=sync_guild_from_npc(g,npc_key,true) or changed;
                break;
            end
        end
    end
    if changed then HC.modules.state.save(); end

    -- v6.0.12: Guild item turn-ins report the exact gain in chat.
    -- Example: "Obtained: 1054 guild points."
    local gp_gain = lower:match('obtained:%s*([%d,]+)%s+guild points');
    if gp_gain ~= nil then
        local gain = digits(gp_gain);
        if gain ~= nil and gain > 0 and gain <= 1000000 then
            gain = math.floor(gain);
            if text_debounced(g,'gp_gain',gain,3) then return; end
            local old = tonumber(g.points) or 0;
            g.points = old + gain;
            g.last_auto_update = now;
            set_last_change(g,'turnin',old,g.points,gain,nil,'guild item turn-in');
            mark_daily_checked(c,'Guild Point item turn-in confirmed');
            g.daily_status='COMPLETE';
            g.daily_confidence='VERIFIED BY GP REWARD';
            g.daily_remaining_gp=0;
            g.daily_earned_gp=math.max(0,math.floor(tonumber(g.daily_earned_gp) or 0));
            if g.daily_earned_gp>0 then g.daily_max_gp=g.daily_max_gp or g.daily_earned_gp; end
            g.daily_verified_at=now;
            g.daily_progress_observed=true;
            g.daily_progress_at=now;
            g.daily_earned_gp=math.max(0,math.floor(tonumber(g.daily_earned_gp) or 0))+gain;
            g.last_turnin = {
                at = now, amount = gain, before = old, after = g.points, confidence = 'CHAT CONFIRMED',
            };
            HC.modules.state.save();
            HC.msg(string.format('Guild Points earned: +%d GP | cached balance %d GP.', gain, g.points));
        end
        return;
    end

    -- Authoritative NPC balance line, observed on HorizonXI Guild Union NPCs:
    -- "you have 14371 guild points accumulated."
    local raw = lower:match('you have%s+([%d,]+)%s+guild points accumulated');
    if raw ~= nil then
        local value = digits(raw);
        if value ~= nil and value >= 0 and value <= 1000000 then
            value = math.floor(value);
            -- Horizon can echo one NPC line through multiple text events. Process one copy only.
            if text_debounced(g,'balance',value,3) then return; end
            local old = g.points;
            g.points = value;
            g.last_auto_update = now;
            g.last_text_sync = now;
            local npc=source_npc(lower) or g.last_npc;
            g.last_npc=npc;
            sync_guild_from_npc(g,npc,false);
            set_last_change(g,'npc_sync',old,g.points,g.points-old,nil,'NPC dialogue');
            -- Balance/menu dialogue is informational only. Do not complete the
            -- daily Guild Points checkbox until a positive GP turn-in is confirmed.
            local req = lower:match('current requested item is%s+(.+)%s*%.%s*you have%s+[%d,]+%s+guild points accumulated');
            if req ~= nil then
                req=trim(req);
                if g.requested_item and tostring(g.requested_item)~='' and item_key(g.requested_item)~=item_key(req) then
                    -- A different requested item is strong evidence that the GP assignment changed.
                    g.daily_status=nil;
                    g.daily_confidence=nil;
                    g.daily_remaining_gp=nil;
                    g.daily_earned_gp=0;
                    g.daily_max_gp=nil;
                    g.daily_progress_observed=nil;
                    g.daily_progress_at=nil;
                    g.daily_verified_at=nil;
                    g.daily_verified_npc=nil;
                    c.daily=type(c.daily)=='table' and c.daily or {};
                    c.daily.guild_points=nil;
                end
                g.requested_item=req;
            end
            g.pending_purchase = nil; -- a fresh spoken balance supersedes transaction estimates.
            HC.modules.state.save();
            if old ~= g.points then
                HC.msg(string.format('Guild Points synced from NPC dialogue: %d GP.', g.points));
            else
                HC.msg(string.format('Guild Points confirmed by NPC dialogue: %d GP.', g.points));
            end
        end
        return;
    end

    -- v6.0.94: HorizonXI Guild Union NPC authoritative daily lockout.
    -- Captured after a successful requested-item turn-in:
    -- "You are not eligible to receive guild points at this time."
    -- This is stronger than merely opening the GP menu and lets HorizonCheck
    -- recover today's completion even if the actual reward line was missed.
    if lower:find('you are not eligible to receive guild points at this time',1,true) then
        if not text_debounced(g,'daily_lockout','not_eligible',3) then
            mark_daily_checked(c,'Guild Union NPC confirms no further Guild Points eligibility today');
            g.daily_status='COMPLETE';
            g.daily_confidence='VERIFIED BY GUILD NPC';
            g.daily_remaining_gp=nil;
            g.daily_verified_at=now;
            g.daily_progress_observed=true;
            g.daily_progress_at=g.daily_progress_at or now;
            g.daily_verified_npc=source_npc(lower) or g.last_npc;
            g.last_auto_update=now;
            HC.modules.state.save();
            HC.msg('AUTO: Guild Points daily complete [VERIFIED BY GUILD NPC] - no further GP eligibility at this time.');
        end
        return;
    end

    -- v6.0.95: authoritative "still eligible" state observed from Andreas.
    -- Example: "You can still receive up to 3200 guild points by trading us the item..."
    local remaining_gp=lower:match('you can still receive up to%s+([%d,]+)%s+guild points');
    if remaining_gp then
        local amount=digits(remaining_gp);
        if amount and amount>=0 and amount<=1000000 then
            amount=math.floor(amount);

            c.daily=type(c.daily)=='table' and c.daily or {};
            c.daily.guild_points=nil;

            if g.daily_progress_observed==true then
                g.daily_status='PARTIAL';
            else
                g.daily_status='AVAILABLE';
            end
            g.daily_confidence='VERIFIED BY GUILD NPC';
            g.daily_remaining_gp=amount;
            g.daily_earned_gp=math.max(0,math.floor(tonumber(g.daily_earned_gp) or 0));
            g.daily_max_gp=g.daily_earned_gp+amount;
            g.daily_verified_at=now;
            g.daily_verified_npc=source_npc(lower) or g.last_npc;
            sync_guild_from_npc(g,g.daily_verified_npc,false);

            HC.modules.state.save();
            if not text_debounced(g,'daily_available',amount,3) then
                HC.msg(string.format(
                    'Guild Points daily %s: %d GP remaining [VERIFIED BY GUILD NPC].',
                    string.lower(tostring(g.daily_status or 'available')), amount
                ));
            end
        end
        return;
    end

    -- Remember a proposed GP purchase. Do not subtract yet; cancellation is possible.
    local amt, item = lower:match('trade%s+([%d,]+)%s+guild points%s+for%s+(.+)%s*%?');
    if amt ~= nil and item ~= nil then
        local value = digits(amt);
        if value ~= nil and value > 0 and value <= 1000000 then
            local key=item_key(item);
            if not text_debounced(g,'purchase',tostring(value)..':'..key,3) then
                g.pending_purchase = {
                    at = now,
                    amount = math.floor(value),
                    item = trim(item),
                    item_key = key,
                };
                HC.modules.state.save();
            end
        end
        return;
    end

    -- Only commit a cached subtraction after the corresponding item receipt appears.
    if type(g.pending_purchase) == 'table' and now - (tonumber(g.pending_purchase.at) or 0) <= 20 then
        -- Horizon appends control bytes after the visible receipt text, so never anchor this at end-of-line.
        local got = lower:match('obtained:%s*(.-)%s*%.') or lower:match('obtained:%s*([^%c]+)');
        if got ~= nil and got ~= '' and item_key(got) == tostring(g.pending_purchase.item_key or '') then
            local amount = tonumber(g.pending_purchase.amount) or 0;
            local old = tonumber(g.points) or 0;
            g.points = math.max(0, old - amount);
            g.last_auto_update = now;
            set_last_change(g,'purchase',old,g.points,-amount,trim(got),'confirmed item receipt');
            -- Spending GP does not count as completing today's requested-item turn-in.
            g.last_transaction = {
                at = now,
                amount = amount,
                item = trim(got),
                before = old,
                after = g.points,
                confidence = 'CHAT CONFIRMED',
            };
            g.pending_purchase = nil;
            HC.modules.state.save();
            HC.msg(string.format('Guild Point purchase confirmed: -%d GP | cached balance %d GP.', amount, g.points));
            return;
        end
    end

    if type(g.pending_purchase) == 'table' and now - (tonumber(g.pending_purchase.at) or 0) > 20 then
        g.pending_purchase = nil;
    end
end

function M.init(ctx)
    HC = ctx;
    HC.modules.packets.register(0x034, 'guild GP menu', capture_menu);
    HC.modules.packets.register_text('guild GP dialogue', on_text);
end

function M.requested_item(c)
    local g=ensure(c);
    local item=recipe_item_name(g.requested_item);
    if item=='' then return nil; end
    return item;
end

function M.requested_item_wiki_url(c)
    local item=M.requested_item(c);
    if not item then return nil; end
    return requested_item_wiki_url(item);
end

function M.open_requested_item_wiki(c)
    local url=M.requested_item_wiki_url(c);
    if not url then return false; end
    return open_url(url);
end

function M.open_gp_master_list()
    return open_url(GP_MASTER_LIST_URL);
end

function M.draw_recipe_link(c,id)
    local imgui=HC and HC.imgui or nil;
    if not imgui then return false; end
    local item=M.requested_item(c);
    if not item then return false; end
    local g=ensure(c);
    local label=(string.lower(tostring(g.guild or ''))=='fishing') and 'Item Wiki' or 'Recipe';
    id=tostring(id or 'guild_requested_item');
    if imgui.SmallButton(label..'##'..id) then
        M.open_requested_item_wiki(c);
    end
    if imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then
        if label=='Recipe' then
            imgui.SetTooltip('Open '..item..' on the HorizonXI Wiki to view its synthesis recipe.');
        else
            imgui.SetTooltip('Open '..item..' on the HorizonXI Wiki.');
        end
    end
    return true;
end

function M.status(c)
    local g=ensure(c);
    local guild=tostring(g.guild or 'Unknown');
    if guild=='Unknown' then guild='UNKNOWN'; end

    local parts={guild,'GP '..tostring(math.floor(tonumber(g.points) or 0))};
    if g.requested_item~=nil and tostring(g.requested_item)~='' then
        parts[#parts+1]=compact_requested_item(g.requested_item);
    else
        parts[#parts+1]='Request: --';
    end

    local earned,remaining,maxgp,pct=daily_progress(g);
    if g.daily_status=='COMPLETE' then
        parts[#parts+1]='COMPLETE';
    elseif g.daily_status=='PARTIAL' and remaining~=nil then
        parts[#parts+1]=string.format('PARTIAL | %d GP left',remaining);
    elseif g.daily_status=='AVAILABLE' and remaining~=nil then
        parts[#parts+1]=string.format('%d GP left',remaining);
    else
        parts[#parts+1]='CHECK NPC';
    end
    return table.concat(parts,' | ');
end

function M.draw(c)
    local imgui = HC.imgui;
    if imgui == nil then return; end

    local g = ensure(c);
    imgui.Text('Guild Points - ' .. M.status(c));

    if type(g.packet) == 'table' then
        imgui.TextDisabled(string.format(
            'Auto source: 0x034 from %s | offset %d | %d-bit',
            tostring(g.packet.npc or '?'),
            tonumber(g.packet.offset) or -1,
            (tonumber(g.packet.width) or 0) * 8
        ));
    elseif learner ~= nil then
        imgui.TextDisabled('GP learner: waiting for confirmation sample.');
    else
        imgui.TextDisabled('Automatic GP: speak to your Guild Union NPC, then use /hcheck gp learn <guild> <points>.');
    end

    if g.last_guild_auto_source then
        imgui.TextDisabled('Guild detection: '..tostring(g.guild or 'Unknown')..
            ' | NPC '..tostring(g.last_npc or '?')..
            ' | AUTO');
    end
    if g.requested_item ~= nil and tostring(g.requested_item) ~= '' then
        imgui.TextDisabled('Requested item: ' .. tostring(g.requested_item));
        imgui.SameLine();
        M.draw_recipe_link(c,'guild_detail_recipe');
        imgui.SameLine();
        if imgui.SmallButton('GP Item List##guild_gp_master_list') then M.open_gp_master_list(); end
        if imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then
            imgui.SetTooltip("Open HorizonXI's server-specific Guild Points/Items master list.");
        end
    end

    local earned_gp,remaining_gp,max_gp,progress_pct=daily_progress(g);
    if max_gp and max_gp>0 then
        imgui.TextDisabled(string.format(
            'Daily GP progress: %d / %d earned | %d remaining | %.1f%%',
            earned_gp,max_gp,remaining_gp or math.max(0,max_gp-earned_gp),progress_pct or 0
        ));
    elseif remaining_gp~=nil then
        imgui.TextDisabled(string.format('Daily GP remaining: %d',remaining_gp));
    end
    if type(g.last_change)=='table' then
        local lc=g.last_change; local delta=tonumber(lc.amount) or 0;
        local ds=(delta>0 and '+' or '')..tostring(delta);
        imgui.TextDisabled(string.format('Last GP change: %s GP | %s -> %s | %s',
            ds,tostring(lc.before or '?'),tostring(lc.after or '?'),tostring(lc.source or '?')));
    end
    if type(g.last_transaction) == 'table' then
        imgui.TextDisabled(string.format('Last GP purchase: -%d | %s | cached %d GP',
            tonumber(g.last_transaction.amount) or 0,
            tostring(g.last_transaction.item or '?'),
            tonumber(g.last_transaction.after) or g.points));
    end
    if type(g.last_turnin) == 'table' then
        imgui.TextDisabled(string.format('Last GP turn-in: +%d | cached %d GP',
            tonumber(g.last_turnin.amount) or 0,
            tonumber(g.last_turnin.after) or g.points));
    end
    if g.daily_status=='COMPLETE' then
        imgui.TextDisabled('Daily GP status: COMPLETE | '..tostring(g.daily_confidence or 'CONFIRMED'));
        if g.daily_verified_npc then
            imgui.TextDisabled('  Verified by: '..tostring(g.daily_verified_npc));
        end
    elseif g.daily_status=='PARTIAL' then
        imgui.TextDisabled('Daily GP status: PARTIAL | '..tostring(g.daily_remaining_gp or '?')..
            ' GP remaining | '..tostring(g.daily_confidence or 'CONFIRMED'));
        if g.daily_verified_npc then
            imgui.TextDisabled('  Verified by: '..tostring(g.daily_verified_npc));
        end
    elseif g.daily_status=='AVAILABLE' then
        imgui.TextDisabled('Daily GP status: AVAILABLE | '..tostring(g.daily_remaining_gp or '?')..
            ' GP remaining | '..tostring(g.daily_confidence or 'CONFIRMED'));
        if g.daily_verified_npc then
            imgui.TextDisabled('  Verified by: '..tostring(g.daily_verified_npc));
        end
    end
    imgui.TextDisabled('Dialogue balance is authoritative; confirmed purchases and GP turn-ins update the cached balance between NPC visits.');
    imgui.TextDisabled('Manual fallback: /hcheck gp <guild> <points>');
end

local function begin_learning(c, guild_name, points)
    if last_menu == nil or os.time() - (last_menu.at or 0) > 15 then
        HC.msg('No recent 0x034 NPC menu packet. Speak to your Guild Union NPC, then run the learn command within 15 seconds.');
        return;
    end

    local candidates = find_value_offsets(last_menu.data, points);
    if #candidates == 0 then
        HC.msg('Could not find that GP value in the recent 0x034 packet. The NPC may use a different packet/layout.');
        return;
    end

    local npc = last_menu.npc;
    local guild_name_valid = valid_guild(guild_name);
    if guild_name_valid == nil then
        HC.msg('Unknown guild name.');
        return;
    end

    if #candidates == 1 then
        save_mapping(c, guild_name_valid, npc, candidates[1]);
        ensure(c).points = points;
        HC.modules.state.save();
        HC.msg(string.format(
            'Guild GP packet learned automatically: %s @ %s, offset %d (%d-bit).',
            guild_name_valid, npc, candidates[1].offset, candidates[1].width * 8
        ));
        return;
    end

    learner = {
        guild = guild_name_valid,
        npc = npc,
        candidates = candidates,
        first_points = points,
        first_at = os.time(),
    };

    ensure(c).guild = guild_name_valid;
    ensure(c).points = points;
    HC.modules.state.save();

    HC.msg(string.format(
        'Found %d possible GP fields. Change your GP, speak to the same NPC again, then use /hcheck gp confirm <newpoints>.',
        #candidates
    ));
end

local function confirm_learning(c, points)
    if learner == nil then
        HC.msg('No GP learning session is active. Use /hcheck gp learn <guild> <points> first.');
        return;
    end
    if last_menu == nil or os.time() - (last_menu.at or 0) > 15 then
        HC.msg('No recent NPC menu packet. Speak to the same Guild Union NPC, then confirm within 15 seconds.');
        return;
    end
    if not same_target(last_menu.npc, learner.npc) then
        HC.msg('Different NPC detected. Speak to the same Guild Union NPC used for the first sample.');
        return;
    end

    local keep = {};
    for _, cand in ipairs(learner.candidates) do
        local v = read_mapping(last_menu.data, cand);
        if v == points then keep[#keep + 1] = cand; end
    end

    if #keep == 1 then
        save_mapping(c, learner.guild, learner.npc, keep[1]);
        local g = ensure(c);
        g.points = points;
        HC.modules.state.save();

        HC.msg(string.format(
            'Guild GP packet mapping confirmed: %s @ %s, offset %d (%d-bit). Future visits update automatically.',
            learner.guild, learner.npc, keep[1].offset, keep[1].width * 8
        ));
        learner = nil;
    elseif #keep == 0 then
        HC.msg('None of the candidate fields matched the new GP value. Start learning again.');
        learner = nil;
    else
        learner.candidates = keep;
        ensure(c).points = points;
        HC.modules.state.save();
        HC.msg(string.format(
            '%d candidate fields remain. Change GP again and repeat /hcheck gp confirm <newpoints>.',
            #keep
        ));
    end
end

function M.command(w)
    if string.lower(w[2] or '') ~= 'gp' then return false; end

    local c = HC.modules.state.get_char();
    local g = ensure(c);
    local action = string.lower(w[3] or '');

    if action == 'learn' then
        local p = tonumber(w[#w]);
        if p == nil or #w < 5 then
            HC.msg('Usage: /hcheck gp learn <guild> <points>');
            return true;
        end
        local parts = {};
        for i = 4, #w - 1 do parts[#parts + 1] = w[i]; end
        begin_learning(c, table.concat(parts, ' '), p);
        return true;
    elseif action == 'confirm' then
        local p = tonumber(w[4]);
        if p == nil then HC.msg('Usage: /hcheck gp confirm <newpoints>'); return true; end
        confirm_learning(c, p);
        return true;
    elseif action == 'forget' then
        g.packet = nil;
        learner = nil;
        HC.modules.state.save();
        HC.msg('Forgot automatic Guild Point packet mapping. Manual guild/GP values were kept.');
        return true;
    elseif action == 'textauto' then
        local v = string.lower(w[4] or 'status');
        if v == 'on' then g.text_auto = true; HC.modules.state.save(); HC.msg('Guild Point dialogue sync ON.');
        elseif v == 'off' then g.text_auto = false; g.pending_purchase=nil; HC.modules.state.save(); HC.msg('Guild Point dialogue sync OFF.');
        else HC.msg('Guild Point dialogue sync: ' .. (g.text_auto and 'ON' or 'OFF')); end
        return true;
    elseif action == 'status' then
        HC.msg(M.status(c));
        if last_menu ~= nil then
            HC.msg(string.format('Last 0x034 NPC menu: %s (%ds ago)', last_menu.npc, os.time() - last_menu.at));
        end
        return true;
    elseif action == 'points' then
        local p = tonumber(w[4]);
        if p == nil then HC.msg('Usage: /hcheck gp points <points>'); return true; end
        g.points = math.max(0, math.floor(p));
        HC.modules.state.save();
        HC.msg('Guild Points synced: ' .. M.status(c));
        return true;
    end

    -- Manual fallback: /hcheck gp <guild> <points>
    local p = tonumber(w[#w]);
    if p == nil or #w < 4 then
        HC.msg('Usage: /hcheck gp <guild> <points>');
        HC.msg('Auto learn: /hcheck gp learn <guild> <points>');
        return true;
    end

    local parts = {};
    for i = 3, #w - 1 do parts[#parts + 1] = w[i]; end
    local guild_name = valid_guild(table.concat(parts, ' '));
    if guild_name == nil then
        HC.msg('Unknown guild. Use Fishing, Woodworking, Smithing, Goldsmithing, Clothcraft, Leathercraft, Bonecraft, Alchemy, or Cooking.');
        return true;
    end

    g.guild = guild_name;
    g.points = math.max(0, math.floor(p));
    HC.modules.state.save();
    HC.msg('Guild Points synced: ' .. M.status(c));
    return true;
end

return M;
