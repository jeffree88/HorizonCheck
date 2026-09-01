local M = {};
local HC;
local last = {};
local reward_context = { at=0 };

local function ensure(c)
    c.haap = type(c.haap)=='table' and c.haap or {};
    c.haap.points = tonumber(c.haap.points);
    c.haap.last_verified_at = tonumber(c.haap.last_verified_at);
    c.haap.reward_pending = c.haap.reward_pending==true;
    c.haap.reward_pending_at = tonumber(c.haap.reward_pending_at);
    return c.haap;
end

local function once(key,value,seconds)
    local now=os.time();
    local sig=tostring(value or '');
    local p=last[key];
    if p and p.sig==sig and now-(p.at or 0)<=(seconds or 2) then return false; end
    last[key]={sig=sig,at=now};
    return true;
end


local function automation_enabled(c)
    local a=type(c.automation)=='table' and c.automation or {};
    if a.enabled==false then return false; end
    if type(a.systems)=='table' and a.systems.dragon==false then return false; end
    return true;
end

local function record(c,kind,detail,undo)
    if HC.modules.automation and HC.modules.automation.record_external then
        HC.modules.automation.record_external(c,kind,detail,undo);
    end
end

local function u32le(raw,offset)
    if type(raw)~='string' then return nil; end
    offset=tonumber(offset) or 0;
    if #raw < offset+4 then return nil; end
    local b1,b2,b3,b4=raw:byte(offset+1,offset+4);
    if not b4 then return nil; end
    return b1 + b2*256 + b3*65536 + b4*16777216;
end

local function sync_balance(c,n,source,announce_change)
    n=tonumber(n);
    if not n or n<0 or n>999999999 then return false; end
    n=math.floor(n);
    local h=ensure(c);
    local now=os.time();
    local old=h.points;
    h.points=n;
    h.last_verified_at=now;
    h.last_source=tostring(source or 'game data');
    h.reward_pending=false;
    h.reward_pending_at=nil;
    if old~=n then
        h.last_change={before=old,after=n,delta=(old and (n-old) or nil),at=now,source=h.last_source};
        record(c,'haap_balance',string.format('HAAP balance synced: %d points',n),nil);
    end
    HC.modules.state.save();
    if announce_change and old~=n then
        HC.msg(string.format('HAAP points synced from %s: %d.',h.last_source,n));
    end
    return true;
end

local function on_currency_packet(e)
    if e==nil or e.injected or tonumber(e.id)~=0x113 then return; end
    -- HorizonXI native Currency menu, verified from the full 252-byte 0x113
    -- payload. H.A.A.P. Points are a little-endian uint32 at zero-based
    -- byte offset 0xE0 (224). Known capture: 0B 00 00 00 => 11 points.
    local raw=e.data or e.data_raw;
    if type(raw)~='string' or #raw<228 then
        raw=e.data_raw or e.data;
    end
    if type(raw)~='string' or #raw<228 then return; end
    local points=u32le(raw,0xE0);
    if points==nil then return; end
    local c=HC.modules.state.get_char();
    sync_balance(c,points,'Currency menu',true);
end

local function sync_weekly_complete(c, announce)
    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    c.dragon_weekly=type(c.dragon_weekly)=='table' and c.dragon_weekly or {};
    local should_complete=(c.dragon_weekly.dc_haap==true and c.dragon_weekly.mm_haap==true);
    local was_complete=(c.weekly.haap==true);

    if should_complete then
        c.weekly.haap=true;
        if announce and not was_complete then
            HC.msg('AUTO: HAAP Weekly Scrolls completed - Dragon Chronicles + Miratete\'s Memoirs both claimed.');
        end
    elseif was_complete then
        -- Parent is derived from the two child scrolls; repair stale manual state too.
        c.weekly.haap=nil;
        if announce then
            HC.msg('AUTO: HAAP Weekly Scrolls reopened because one or more HAAP scroll claims are not complete.');
        end
    end

    return should_complete, was_complete~=should_complete;
end

function M.reconcile(c, announce)
    local complete,changed=sync_weekly_complete(c,announce==true);
    if changed then HC.modules.state.save(); end
    return complete,changed;
end

local function mark_scroll(c, key, label, why)
    if not automation_enabled(c) then return; end
    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    c.dragon_weekly=type(c.dragon_weekly)=='table' and c.dragon_weekly or {};

    local old_weekly=c.weekly.haap;
    local old_scroll=c.dragon_weekly[key];
    if old_scroll==true then return; end

    c.dragon_weekly[key]=true;
    sync_weekly_complete(c,true);

    record(c,'haap_scroll',tostring(why or ('HAAP '..label..' claimed')),{
        scope='haap_scroll',
        key=key,
        old_scroll=old_scroll,
        old_weekly=old_weekly,
    });

    local dragon=c.dragon_weekly.dc_haap==true;
    local mira=c.dragon_weekly.mm_haap==true;
    HC.msg(string.format(
        'AUTO: HAAP %s marked complete. Weekly HAAP scrolls: Dragon %s | Miratete %s.',
        label,
        dragon and 'DONE' or 'OPEN',
        mira and 'DONE' or 'OPEN'
    ));
end

local function on_text(s)
    local c=HC.modules.state.get_char();
    local h=ensure(c);
    local now=os.time();
    s=string.lower(tostring(s or ''));

    -- Authoritative HAAP balance from the NPC.
    local points=s:match('you currently have%s+(%d+)%s+points');
    if points then
        local n=tonumber(points);
        if n and once('balance',n,2) then
            sync_balance(c,n,'HAAP.I NPC',true);
        end
        return;
    end

    -- HAAP reward context from captured repeatable dialogue.
    if s:find('haap.i',1,true) and s:find('thank you for being a friend',1,true) and s:find('here is your reward',1,true) then
        reward_context.at=now;
        h.reward_pending=true;
        h.reward_pending_at=now;
        h.last_source='reward claimed; awaiting balance refresh';
        HC.modules.state.save();
        return;
    end

    -- HAAP scroll receipts are tracked independently each week.
    if s:find('obtained:',1,true) and s:find('page from the dragon chronicles',1,true)
        and reward_context.at>0 and now-reward_context.at<=20 then
        mark_scroll(c,'dc_haap','Dragon Chronicles','HAAP Dragon Chronicles reward');
        h.reward_pending=true;
        h.reward_pending_at=now;
        h.last_source='Dragon Chronicles reward; awaiting HAAP balance refresh';
        reward_context.at=0;
        HC.modules.state.save();
        return;
    end

    if s:find('obtained:',1,true) and s:find("page from miratete",1,true)
        and reward_context.at>0 and now-reward_context.at<=20 then
        mark_scroll(c,'mm_haap',"Miratete's Memoirs","HAAP Miratete reward");
        h.reward_pending=true;
        h.reward_pending_at=now;
        h.last_source="Miratete's Memoirs reward; awaiting HAAP balance refresh";
        reward_context.at=0;
        HC.modules.state.save();
        return;
    end

    if h.reward_pending and h.reward_pending_at and now-h.reward_pending_at>90 then
        h.reward_pending=false;
        h.reward_pending_at=nil;
        HC.modules.state.save();
    end
end

function M.init(ctx)
    HC=ctx;
    if HC.modules.packets then
        HC.modules.packets.register_text('haap',on_text);
        HC.modules.packets.register(0x113,'haap_currency',on_currency_packet);
    end
end

function M.status(c)
    local h=ensure(c);
    M.reconcile(c,false);
    c.dragon_weekly=type(c.dragon_weekly)=='table' and c.dragon_weekly or {};
    local pts=h.points and (tostring(h.points)..' pts') or 'unknown points';
    local scrolls=string.format('Dragon %s | Miratete %s',
        c.dragon_weekly.dc_haap==true and 'DONE' or 'OPEN',
        c.dragon_weekly.mm_haap==true and 'DONE' or 'OPEN');
    if h.reward_pending then return pts..' | '..scrolls..' | reward claimed - recheck NPC'; end
    return pts..' | '..scrolls;
end

function M.row_status(c,key)
    local h=ensure(c);
    c.dragon_weekly=type(c.dragon_weekly)=='table' and c.dragon_weekly or {};
    local pts=h.points and (tostring(h.points)..' pts') or 'unknown pts';
    if key=='dc_haap' then
        return string.format('%s | Dragon %s',pts,c.dragon_weekly.dc_haap==true and 'DONE' or 'OPEN');
    elseif key=='mm_haap' then
        return string.format('%s | Miratete %s',pts,c.dragon_weekly.mm_haap==true and 'DONE' or 'OPEN');
    end
    return pts;
end

function M.draw(c)
    if not HC.imgui then return; end
    local h=ensure(c);
    M.reconcile(c,false);
    HC.imgui.Text('HAAP Points: '..(h.points and tostring(h.points) or 'Unknown'));
    c.dragon_weekly=type(c.dragon_weekly)=='table' and c.dragon_weekly or {};
    HC.imgui.TextDisabled('Weekly Dragon Chronicles: '..(c.dragon_weekly.dc_haap==true and 'DONE' or 'OPEN'));
    HC.imgui.TextDisabled("Weekly Miratete's Memoirs: "..(c.dragon_weekly.mm_haap==true and 'DONE' or 'OPEN'));
    if h.last_verified_at then
        HC.imgui.TextDisabled('Last updated from '..tostring(h.last_source or 'game data')..': '..tostring(math.max(0,os.time()-h.last_verified_at))..'s ago');
    else
        HC.imgui.TextDisabled('Checking the game Currency data automatically...');
    end
    if h.reward_pending then
        HC.imgui.TextDisabled('Reward claimed - waiting for the automatic Currency refresh.');
    end
    if type(h.last_change)=='table' and h.last_change.before~=nil and h.last_change.after~=nil then
        local d=tonumber(h.last_change.delta);
        local ds=d and string.format('%+d',d) or '?';
        HC.imgui.TextDisabled(string.format('Last HAAP change: %s | %s -> %s',ds,tostring(h.last_change.before),tostring(h.last_change.after)));
    end
end

function M.command(w)
    if string.lower(w[2] or '')~='haap' then return false; end
    local c=HC.modules.state.get_char(); local h=ensure(c);
    local sub=string.lower(w[3] or 'status');
    if sub=='status' then
        HC.msg('HAAP: '..M.status(c));
        return true;
    elseif sub=='set' then
        local n=tonumber(w[4]);
        if n then h.points=math.max(0,math.floor(n)); h.last_source='manual'; HC.modules.state.save(); HC.msg('HAAP points manually set to '..tostring(h.points)..'.'); end
        return true;
    end
    HC.msg('/hcheck haap status | /hcheck haap set <points>');
    return true;
end

return M;
