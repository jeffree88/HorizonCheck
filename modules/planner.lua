local M = {};
local HC;

local TIER_ORDER={['DO NOW']=1,READY=2,PREP=3,SOON=4,LOCKED=5};
local ACTION_LIMITS={['DO NOW']=6,READY=8,PREP=5,LOCKED=4};
local ATTENTION_TIERS={'DO NOW'};
local SOON_LIMIT=7;
local build_cache={at=0,char=nil,data=nil,hits=0,misses=0};
local BUILD_CACHE_SECONDS=1;

local function safe_weekly_remaining()
    if HC and HC.modules and HC.modules.core and HC.modules.core.seconds_until_weekly_reset then
        local ok,v=pcall(HC.modules.core.seconds_until_weekly_reset);
        if ok and type(v)=='number' then return math.max(0,v); end
    end
    return nil;
end

local function safe_daily_remaining()
    if HC and HC.modules and HC.modules.core and HC.modules.core.seconds_until_daily_reset then
        local ok,v=pcall(HC.modules.core.seconds_until_daily_reset);
        if ok and type(v)=='number' then return math.max(0,v); end
    end
    return nil;
end

local function fmt_duration(v)
    if HC and HC.modules and HC.modules.core and HC.modules.core.format_duration and type(v)=='number' then
        local ok,s=pcall(HC.modules.core.format_duration,v);
        if ok and s then return tostring(s); end
    end
    return tostring(v or '?');
end

local function pair_count(values,a,b)
    values=type(values)=='table' and values or {};
    return (values[a]==true and 1 or 0)+(values[b]==true and 1 or 0);
end

function M.classify(state,opts)
    opts=type(opts)=='table' and opts or {};
    local s=string.upper(tostring(state or ''));
    if s=='IN PROGRESS' or s=='ACTIVE' or opts.capped==true then return 'DO NOW'; end
    if s=='READY' or s=='AVAILABLE' then
        local remain=tonumber(opts.reset_remaining);
        local urgent=tonumber(opts.urgent_within) or 0;
        if remain and urgent>0 and remain<=urgent then return 'DO NOW'; end
        return 'READY';
    end
    if s=='PREP' or s=='CHECK' or s=='VERIFY' or s=='UNKNOWN' then return 'PREP'; end
    if s=='SOON' or s=='COUNTING DOWN' then return 'SOON'; end
    if s=='LOCKED' then return 'LOCKED'; end
    return 'PREP';
end

local function add(model,tier,priority,text,opts)
    opts=type(opts)=='table' and opts or {};
    tier=tier or 'READY';
    model.groups[tier]=model.groups[tier] or {};
    local row={
        tier=tier,
        priority=tonumber(priority) or 100,
        text=tostring(text or ''),
        category=tostring(opts.category or 'activity'),
        source=tostring(opts.source or ''),
        seconds=tonumber(opts.seconds),
        score=tonumber(opts.score),
        here=opts.here==true,
        log_id=opts.log_id,
        quest_id=opts.quest_id,
        reason=opts.reason,
        urgency=tostring(opts.urgency or ''),
        series_id=opts.series_id,
        mission_number=opts.mission_number,
        tab=opts.tab,
        focus=opts.focus,
    };
    model.groups[tier][#model.groups[tier]+1]=row;
    model.counts[tier]=(model.counts[tier] or 0)+1;
    return row;
end

local function add_timer(model,name,seconds,label,opts)
    if type(seconds)~='number' or seconds<0 then return; end
    opts=type(opts)=='table' and opts or {};
    local text=tostring(name)..': '..fmt_duration(seconds);
    if label and tostring(label)~='' then text=text..' | '..tostring(label); end
    add(model,'SOON',seconds,text,{category=opts.category or 'activity',source=opts.source or '',seconds=seconds});
end

local function include_row(row,filter)
    if filter=='quests' then return row.category=='quest'; end
    if filter=='activities' then return row.category~='quest'; end
    return true;
end

local function sorted_rows(model,tier,filter)
    local out={};
    for _,r in ipairs(model.groups[tier] or {}) do if include_row(r,filter) then out[#out+1]=r; end end
    table.sort(out,function(a,b)
        if tier=='SOON' then
            local as=tonumber(a.seconds) or math.huge; local bs=tonumber(b.seconds) or math.huge;
            if as~=bs then return as<bs; end
        end
        local ap=tonumber(a.score) or 0; local bp=tonumber(b.score) or 0;
        if ap~=bp then return ap>bp; end
        if a.priority~=b.priority then return a.priority<b.priority; end
        return string.lower(a.text)<string.lower(b.text);
    end);
    return out;
end

local function add_activity_rows(model,c,weekly_remaining)
    -- v6.86.0: activity lifecycle/reset interpretation lives in modules/systems.lua.
    -- The planner only renders normalized actions, preventing dashboard-specific
    -- copies of Assault/Limbus/Dynamis/ENM rules from drifting out of sync.
    local systems=HC.modules and HC.modules.systems or nil;
    if systems and systems.action_rows then
        local ok,rows=pcall(systems.action_rows,c);
        if ok then
            for _,r in ipairs(rows or {}) do
                local tier=tostring(r.tier or 'READY');
                add(model,tier,tonumber(r.priority) or 100,tostring(r.text or ''),{
                    source=tostring(r.source or 'systems'), category='activity', seconds=r.seconds,
                    reason=r.reason, urgency=r.urgency,
                });
            end
        end
        return;
    end
end

local function add_quest_rows(model,c)
    local q=HC.modules.quests;
    if not q or not q.progression_overview then return; end
    local function canonical_actionable(row)
        local cm=HC.modules and HC.modules.canonical or nil;
        if cm and cm.quest then
            local ok,r=pcall(cm.quest,row.log_id,row.quest_id);
            if ok and type(r)=='table' then return cm.is_actionable(r) and r.native_policy=='ALLOW'; end
        end
        local av=HC.modules and HC.modules.availability or nil;
        if av and av.quest then local ok,a=pcall(av.quest,row.log_id,row.quest_id); if ok then return av.is_actionable(a); end end
        return true;
    end
    local ok,po=pcall(q.progression_overview,c);
    if not ok or type(po)~='table' then return; end
    model.quest_snapshot=po;

    -- The dashboard is intentionally local: only surface quests whose mapped
    -- start/current action zone matches the player's current zone. Travel-wide
    -- quest recommendations remain in the full Quests tab.
    local active_here=0;
    local shown_active=0;
    for _,r in ipairs(po.active_rows or {}) do
        local era_ok=canonical_actionable(r);
        if r.here==true and era_ok then
            active_here=active_here+1;
            if shown_active<4 then
                shown_active=shown_active+1;
                local nextstep=tostring(r.next_step or '');
                local suffix=nextstep~='' and (' - '..nextstep) or '';
                add(model,'DO NOW',20+shown_active,'Quest here: '..tostring(r.name or 'Quest')..suffix,{category='quest',source='quests',score=r.score,log_id=r.log_id,quest_id=r.quest_id,here=true});
            end
        end
    end

    local ready_here=0;
    for _,r in ipairs(po.recommended or {}) do
        local era_ok=canonical_actionable(r);
        if r.here==true and era_ok then
            ready_here=ready_here+1;
            local why=(r.why and r.why~='') and (' ['..tostring(r.why)..']') or '';
            add(model,'READY',35+ready_here,'Quest here: '..tostring(r.name or 'Quest')..why,{category='quest',source='quests',score=r.score,log_id=r.log_id,quest_id=r.quest_id,here=true});
        end
    end

    -- Surface the highest-impact blocked quests as an explicit blocker queue.
    -- These never compete with actionable recommendations in the default view,
    -- but Overview can switch to a dedicated Blocked filter and show the exact
    -- prerequisite chain produced by modules/blockers.lua.
    local blocked_shown=0;
    for _,r in ipairs(po.locked_rows or {}) do
        if blocked_shown>=8 then break; end
        local era_ok=canonical_actionable(r);
        if era_ok then
            blocked_shown=blocked_shown+1;
            add(model,'LOCKED',80+blocked_shown,'Quest: '..tostring(r.name or 'Quest'),{
                category='quest',source='quests',score=tonumber(r.score) or 0,log_id=r.log_id,quest_id=r.quest_id,
                here=r.here==true,reason=tostring(r.reason or 'Progression requirement not satisfied'),
            });
        end
    end
    model.blocked_total=tonumber(po.locked) or blocked_shown;
    model.quest_here_snapshot={ready=ready_here,active=active_here};
end

local function add_mission_rows(model,c)
    local m=HC.modules and HC.modules.missions or nil;
    if not (m and m.current_progress) then return; end
    local ok,rows=pcall(m.current_progress,c); if not ok or type(rows)~='table' then return; end
    local shown=0;
    for _,r in ipairs(rows) do
        if r.current and tostring(r.availability or '')~='FUTURE' then
            shown=shown+1;
            local native=r.native_current==true;
            local label='Mission: '..tostring(r.series_name or r.series_id)..' '..tostring(r.current.number or '')..' - '..tostring(r.current.name or '');
            local reason=native and 'current mission confirmed by native mission state' or 'next incomplete mission in tracked progression';
            add(model,'PREP',55+shown,label,{
                category='mission',source='missions',score=native and 120 or 60,reason=reason,
                series_id=r.series_id,mission_number=r.current.number,
                focus={series_id=r.series_id,number=r.current.number,name=r.current.name},
            });
        end
    end
end

local function add_soon_rows(model,c,daily_remaining,weekly_remaining)
    local systems=HC.modules and HC.modules.systems or nil;
    if systems and systems.timer_rows then
        local ok,rows=pcall(systems.timer_rows,c);
        if ok then
            for _,r in ipairs(rows or {}) do
                add_timer(model,tostring(r.name or 'Activity'),tonumber(r.seconds),r.label,{source=tostring(r.source or 'systems')});
            end
        end
    end
    add_timer(model,'Daily reset',daily_remaining,'daily objectives',{source='reset'});
    add_timer(model,'Conquest reset',weekly_remaining,'weekly objectives',{source='reset'});
end

local SCORE_BASE={['DO NOW']=1000,READY=700,PREP=400,SOON=250,LOCKED=0};

local function score_reason(row,model)
    local score=tonumber(row.score) or 0;
    score=score+(SCORE_BASE[row.tier] or 0);
    local reasons={};
    if row.here==true then score=score+300; reasons[#reasons+1]='current zone'; end
    local txt=string.lower(tostring(row.text or ''));
    if txt:find('key item ready',1,true) or txt:find('held',1,true) then score=score+120; reasons[#reasons+1]='KI ready'; end
    if txt:find('capped',1,true) then score=score+100; reasons[#reasons+1]='capped'; end
    if row.category=='quest' then score=score+30; end
    if row.category~='quest' and tonumber(model.weekly_remaining) and model.weekly_remaining<=24*3600 and (row.tier=='READY' or row.tier=='DO NOW') then
        score=score+150; reasons[#reasons+1]='weekly reset soon';
    end
    if row.reason and tostring(row.reason)~='' then reasons[#reasons+1]=tostring(row.reason); end
    row.score=score;
    if #reasons>0 then row.reason=table.concat(reasons,' | '); end
end

local function score_model(model)
    for tier,rows in pairs(model.groups or {}) do
        for _,r in ipairs(rows or {}) do r.tier=tier; score_reason(r,model); end
    end
end

local function choose_focus(model)
    for _,tier in ipairs({'DO NOW','READY'}) do
        local rows=sorted_rows(model,tier,'all');
        if #rows>0 then model.focus=rows[1]; return; end
    end
end

local function build_impl(c)
    c=type(c)=='table' and c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    local progression_status=nil;
    if HC.modules.progression and HC.modules.progression.status then
        local ok,v=pcall(HC.modules.progression.status,c); if ok then progression_status=v; end
    end
    local model={generated_at=os.time(),groups={['DO NOW']={},READY={},PREP={},SOON={},LOCKED={}},counts={['DO NOW']=0,READY=0,PREP=0,SOON=0,LOCKED=0}};
    local weekly_remaining=safe_weekly_remaining();
    local daily_remaining=safe_daily_remaining();
    model.weekly_remaining=weekly_remaining; model.daily_remaining=daily_remaining; model.progression_status=progression_status;
    add_activity_rows(model,c,weekly_remaining);
    add_quest_rows(model,c);
    add_mission_rows(model,c);
    add_soon_rows(model,c,daily_remaining,weekly_remaining);
    score_model(model);
    choose_focus(model);
    return model;
end

function M.build(c,force)
    c=type(c)=='table' and c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    local char=(HC.modules.core and HC.modules.core.character_name and HC.modules.core.character_name()) or 'Unknown';
    local now=os.time();
    if force~=true and build_cache.data and build_cache.char==char
        and now-(tonumber(build_cache.at) or 0)<BUILD_CACHE_SECONDS
    then
        build_cache.hits=(tonumber(build_cache.hits) or 0)+1;
        if HC.modules.profiler and HC.modules.profiler.cache then HC.modules.profiler.cache('planner.model',true); end
        return build_cache.data;
    end
    local p=HC and HC.modules and HC.modules.profiler or nil;
    local model=nil;
    if p and p.measure then model=p.measure('planner.build',build_impl,c); else model=build_impl(c); end
    build_cache={at=now,char=char,data=model,hits=tonumber(build_cache.hits) or 0,misses=(tonumber(build_cache.misses) or 0)+1};
    if HC.modules.profiler and HC.modules.profiler.cache then HC.modules.profiler.cache('planner.model',false); end
    return model;
end

local function ranked_from_model(model,limit)
    model=type(model)=='table' and model or {groups={}};
    local out={};
    for _,tier in ipairs({'DO NOW','READY','PREP'}) do
        for _,r in ipairs(sorted_rows(model,tier,'all')) do
            out[#out+1]=r;
        end
    end
    table.sort(out,function(a,b)
        local as=tonumber(a.score) or 0; local bs=tonumber(b.score) or 0;
        if as~=bs then return as>bs; end
        if a.priority~=b.priority then return a.priority<b.priority; end
        return string.lower(a.text)<string.lower(b.text);
    end);
    local n=math.max(1,tonumber(limit) or #out); while #out>n do table.remove(out); end
    return out;
end

function M.ranked(c,limit,model)
    return ranked_from_model(model or M.build(c),limit);
end

function M.ranked_from_model(model,limit)
    return ranked_from_model(model,limit);
end

function M.invalidate()
    build_cache.at=0;
    build_cache.char=nil;
    build_cache.data=nil;
end

local function draw_wrapped(imgui,text,disabled)
    text=tostring(text or '');
    local pushed=false;
    if imgui.PushTextWrapPos and imgui.PopTextWrapPos then
        local ok=pcall(imgui.PushTextWrapPos,0.0);
        pushed=ok==true;
    end
    if disabled then
        imgui.TextDisabled(text);
    elseif imgui.TextWrapped and not pushed then
        imgui.TextWrapped(text);
    else
        imgui.Text(text);
    end
    if pushed then pcall(imgui.PopTextWrapPos); end
end

local function draw_group(imgui,model,tier,filter,limit)
    local rows=sorted_rows(model,tier,filter);
    if #rows==0 then return false; end
    local heading=tier;
    if tier=='DO NOW' then heading='DO NOW'; elseif tier=='READY' then heading='READY'; elseif tier=='PREP' then heading='PREP'; elseif tier=='LOCKED' then heading='BLOCKED'; end
    imgui.TextDisabled(heading..'  '..tostring(#rows));
    local shown=0;
    for _,r in ipairs(rows) do
        if shown>=limit then break; end; shown=shown+1;
        local prefix=(tier=='DO NOW' and '> ') or (tier=='READY' and '- ') or (tier=='PREP' and '- ') or '- ';
        if tier=='LOCKED' then draw_wrapped(imgui,prefix..r.text,true); else draw_wrapped(imgui,prefix..r.text,false); end
    end
    if #rows>shown then imgui.TextDisabled('  +'..tostring(#rows-shown)..' more'); end
    return true;
end

local function urgent_rows(model)
    local out={critical={},soon={},other={}};
    for _,r in ipairs(sorted_rows(model,'DO NOW','activities')) do
        local u=string.upper(tostring(r.urgency or ''));
        if u=='CRITICAL' then out.critical[#out.critical+1]=r;
        elseif u=='SOON' then out.soon[#out.soon+1]=r;
        else out.other[#out.other+1]=r; end
    end
    return out;
end

function M.has_urgent(c,model)
    model=model or M.build(c);
    local rows=urgent_rows(model);
    return (#rows.critical+#rows.soon+#rows.other)>0;
end

local function draw_urgent_group(imgui,label,rows,limit)
    if #rows==0 then return false; end
    imgui.TextDisabled(label..'  '..tostring(#rows));
    local shown=0;
    for _,r in ipairs(rows) do
        if shown>=limit then break; end
        shown=shown+1;
        draw_wrapped(imgui,'> '..tostring(r.text or ''),false);
    end
    if #rows>shown then imgui.TextDisabled('  +'..tostring(#rows-shown)..' more'); end
    return true;
end

local function draw_left(c,imgui,model)
    imgui.Text('Attention');
    imgui.Separator();
    local rows=urgent_rows(model);
    local any=false;
    if draw_urgent_group(imgui,'CRITICAL',rows.critical,ACTION_LIMITS['DO NOW'] or 6) then any=true; end
    if any and #rows.soon>0 then imgui.Spacing(); end
    if draw_urgent_group(imgui,'EXPIRING SOON',rows.soon,ACTION_LIMITS['DO NOW'] or 6) then any=true; end
    if any and #rows.other>0 then imgui.Spacing(); end
    if draw_urgent_group(imgui,'DO NOW',rows.other,ACTION_LIMITS['DO NOW'] or 6) then any=true; end
    return any;
end

local function draw_right(c,imgui,model)
    imgui.Text('Next Up');
    imgui.Separator();
    local filter='activities';
    local soon=sorted_rows(model,'SOON',filter);
    local shown=0;
    for _,r in ipairs(soon) do
        if shown>=SOON_LIMIT then break; end; shown=shown+1; draw_wrapped(imgui,r.text,true); end
    if #soon>shown then imgui.TextDisabled('+'..tostring(#soon-shown)..' more timers'); end
    if shown==0 then imgui.TextDisabled('No activity timers.'); end
end

function M.draw_next_up(c,model)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    draw_right(c,imgui,model or M.build(c));
end

function M.draw(c,model)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    model=model or M.build(c);
    local has=M.has_urgent(c,model);
    if not has then
        -- Empty Attention is hidden entirely; Next Up remains visible on its own.
        draw_right(c,imgui,model);
        return;
    end
    local table_supported=(imgui.BeginTable~=nil and imgui.TableNextColumn~=nil and imgui.EndTable~=nil);
    if table_supported and imgui.BeginTable('##hc_planner_columns_v6930',2,512) then
        imgui.TableNextColumn(); draw_left(c,imgui,model);
        imgui.TableNextColumn(); draw_right(c,imgui,model);
        imgui.EndTable();
    else
        draw_left(c,imgui,model); imgui.Spacing(); imgui.Separator(); draw_right(c,imgui,model);
    end
end

function M.status(c)
    local m=M.build(c);
    return {focus=m.focus,counts=m.counts,quest_snapshot=m.quest_snapshot,quest_here_snapshot=m.quest_here_snapshot,weekly_remaining=m.weekly_remaining,daily_remaining=m.daily_remaining,ranked=ranked_from_model(m,8),cache_hits=build_cache.hits or 0,cache_misses=build_cache.misses or 0};
end

function M.init(ctx) HC=ctx; end
return M;
