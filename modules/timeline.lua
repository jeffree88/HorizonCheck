local M = {};
local HC;

local MAX_EVENTS=120;

local function ensure(c)
    c=c or (HC and HC.modules and HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    c.activity_timeline=type(c.activity_timeline)=='table' and c.activity_timeline or {};
    local t=c.activity_timeline;
    t.events=type(t.events)=='table' and t.events or {};
    t.next_id=tonumber(t.next_id) or 1;
    return t,c;
end

local function trim(t)
    while #(t.events or {})>MAX_EVENTS do table.remove(t.events,1); end
end

local function same_recent(t,kind,title,detail,old_state,new_state,window)
    local last=t.events and t.events[#t.events] or nil;
    if not last then return nil; end
    if os.time()-(tonumber(last.at) or 0)>(tonumber(window) or 2) then return nil; end
    if tostring(last.kind)==tostring(kind)
        and tostring(last.title)==tostring(title)
        and tostring(last.detail)==tostring(detail)
        and tostring(last.old_state)==tostring(old_state)
        and tostring(last.new_state)==tostring(new_state)
    then return last; end
    return nil;
end

function M.record(c,kind,title,detail,opts)
    opts=type(opts)=='table' and opts or {};
    local t; t,c=ensure(c);
    local existing=same_recent(t,kind,title,detail,opts.old_state,opts.new_state,opts.dedupe_seconds);
    if existing then return existing; end
    local ev={
        id=t.next_id,
        at=tonumber(opts.at) or os.time(),
        kind=tostring(kind or 'event'),
        title=tostring(title or kind or 'Event'),
        detail=tostring(detail or ''),
        source=tostring(opts.source or ''),
        scope=tostring(opts.scope or 'character'),
        old_state=opts.old_state,
        new_state=opts.new_state,
        evidence=opts.evidence,
        automation_event_id=tonumber(opts.automation_event_id),
        undoable=opts.undoable==true,
        repair=opts.repair==true,
        zone_id=opts.zone_id,
        zone_name=opts.zone_name,
        undone=opts.undone==true,
    };
    t.next_id=t.next_id+1;
    t.events[#t.events+1]=ev;
    t.last_at=ev.at; t.last_id=ev.id;
    trim(t);
    if HC and HC.modules and HC.modules.state and HC.modules.state.request_save then
        HC.modules.state.request_save(1);
    end
    return ev;
end

function M.transition(c,key,label,old_state,new_state,opts)
    if old_state==nil or tostring(old_state)==tostring(new_state) then return nil; end
    opts=type(opts)=='table' and opts or {};
    opts.old_state=old_state; opts.new_state=new_state;
    return M.record(c,'transition',label or key,
        tostring(old_state)..' -> '..tostring(new_state),opts);
end

local function automation_event(c,id)
    local a=HC and HC.modules and HC.modules.automation or nil;
    if not a or not a.recent then return nil; end
    for _,ev in ipairs(a.recent(c) or {}) do
        if tonumber(ev.id)==tonumber(id) then return ev; end
    end
    return nil;
end

local function refresh_undo_flags(c,events)
    for _,ev in ipairs(events or {}) do
        if ev.automation_event_id then
            local aev=automation_event(c,ev.automation_event_id);
            if aev and aev.undone==true then ev.undone=true; end
        end
    end
end

function M.recent(c,limit)
    local t; t,c=ensure(c);
    refresh_undo_flags(c,t.events);
    limit=math.max(1,math.min(MAX_EVENTS,tonumber(limit) or 30));
    local out={};
    local first=math.max(1,#t.events-limit+1);
    for i=first,#t.events do out[#out+1]=t.events[i]; end
    return out;
end

local function title_case_words(s)
    s=tostring(s or ''):gsub('_',' '):gsub('%-',' ');
    return (s:gsub('(%a)([%w]*)',function(a,b) return string.upper(a)..string.lower(b); end));
end

local function player_event(ev)
    local kind=string.lower(tostring(ev and ev.kind or ''));
    if kind=='auto' then
        local title=string.lower(tostring(ev.title or ''));
        if title:find('candidate:',1,true)==1 then return false; end
        return true;
    end
    if kind=='transition' then return true; end
    return false;
end

local function player_display(ev)
    local out={}; for k,v in pairs(ev or {}) do out[k]=v; end
    local kind=string.lower(tostring(ev and ev.kind or ''));
    local title=tostring(ev and ev.title or 'Activity');
    if kind=='auto' then
        local low=string.lower(title);
        local labels={daily='Daily Objective',weekly='Weekly Objective',dragon='Dragon / EXP',highwind='Highwind'};
        out.display_title=labels[low] or title_case_words(title);
    elseif kind=='transition' then
        out.display_title=title;
    else
        out.display_title=title_case_words(title);
    end
    local detail=tostring(ev and ev.detail or '');
    if ev and ev.source and tostring(ev.source)~='' and tostring(ev.source)~='automation' then
        detail=detail..' | '..tostring(ev.source);
    end
    out.display_detail=detail;
    return out;
end

function M.player_recent(c,limit)
    local rows=M.recent(c,MAX_EVENTS);
    local out={};
    limit=math.max(1,math.min(20,tonumber(limit) or 6));
    for i=#rows,1,-1 do
        local ev=rows[i];
        if player_event(ev) then
            out[#out+1]=player_display(ev);
            if #out>=limit then break; end
        end
    end
    return out;
end

function M.undo(c,id)
    local t; t,c=ensure(c);
    id=tonumber(id); if not id then return false; end
    for i=#t.events,1,-1 do
        local ev=t.events[i];
        if tonumber(ev.id)==id then
            if ev.undone==true then
                if HC and HC.msg then HC.msg('Timeline event #'..tostring(id)..' was already undone.'); end
                return false;
            end
            if ev.automation_event_id and HC and HC.modules and HC.modules.automation and HC.modules.automation.undo_event then
                local ok=HC.modules.automation.undo_event(c,ev.automation_event_id);
                if ok then
                    ev.undone=true; ev.undone_at=os.time();
                    return true;
                end
            end
            if HC and HC.msg then HC.msg('Timeline event #'..tostring(id)..' is informational and cannot be undone.'); end
            return false;
        end
    end
    if HC and HC.msg then HC.msg('Timeline event #'..tostring(id)..' was not found.'); end
    return false;
end

function M.draw(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local rows=M.recent(c,30);
    imgui.Text('Activity Timeline / Repair History');
    imgui.TextDisabled('Automatic changes, normalized state transitions, zone reconciliations, and repairs are kept here.');
    if #rows==0 then imgui.TextDisabled('No timeline events recorded yet.'); return; end

    local table_ok=(imgui.BeginTable~=nil and imgui.TableSetupColumn~=nil and imgui.TableHeadersRow~=nil
        and imgui.TableNextRow~=nil and imgui.TableSetColumnIndex~=nil and imgui.EndTable~=nil);
    if table_ok and imgui.BeginTable('##hc_activity_timeline_v6880',5,64+128+512) then
        imgui.TableSetupColumn('Time',0,70);
        imgui.TableSetupColumn('Type',0,90);
        imgui.TableSetupColumn('Activity',0,190);
        imgui.TableSetupColumn('Change / Detail',0,430);
        imgui.TableSetupColumn('Repair',0,80);
        imgui.TableHeadersRow();
        for _,ev in ipairs(rows) do
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0); imgui.TextDisabled(os.date('%H:%M:%S',tonumber(ev.at) or os.time()));
            imgui.TableSetColumnIndex(1); imgui.TextDisabled(string.upper(tostring(ev.kind or 'event')));
            imgui.TableSetColumnIndex(2); imgui.Text(tostring(ev.title or ''));
            imgui.TableSetColumnIndex(3);
            local d=tostring(ev.detail or '');
            if ev.source and ev.source~='' then d=d..' | '..tostring(ev.source); end
            if ev.undone then d=d..' [UNDONE]'; end
            imgui.TextDisabled(d);
            imgui.TableSetColumnIndex(4);
            if ev.automation_event_id and not ev.undone then
                if imgui.SmallButton('Undo##hc_timeline_undo_'..tostring(ev.id)) then M.undo(c,ev.id); end
            elseif ev.repair then imgui.TextDisabled('REPAIR'); else imgui.TextDisabled('-'); end
        end
        imgui.EndTable();
    else
        for _,ev in ipairs(rows) do
            imgui.TextWrapped(string.format('%s  %s  %s - %s%s',
                os.date('%H:%M:%S',tonumber(ev.at) or os.time()),string.upper(tostring(ev.kind or 'event')),
                tostring(ev.title or ''),tostring(ev.detail or ''),ev.undone and ' [UNDONE]' or ''));
        end
    end
end

function M.status(c)
    local t=ensure(c);
    return {count=#(t.events or {}),last_at=t.last_at,last_id=t.last_id};
end

function M.command(w)
    local sub=string.lower(w[2] or '');
    if sub~='timeline' and sub~='history' then return false; end
    local c=HC.modules.state.get_char();
    local action=string.lower(w[3] or 'status');
    if action=='undo' and tonumber(w[4]) then M.undo(c,tonumber(w[4])); return true; end
    local rows=M.recent(c,10);
    HC.msg('Activity timeline: '..tostring(#rows)..' recent event(s).');
    for _,ev in ipairs(rows) do HC.msg(string.format('#%s %s %s - %s',tostring(ev.id),os.date('%H:%M:%S',ev.at),tostring(ev.title),tostring(ev.detail))); end
    return true;
end

function M.init(ctx) HC=ctx; end
return M;
