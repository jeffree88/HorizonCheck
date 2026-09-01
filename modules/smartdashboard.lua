local M={};
local HC;
local cache={at=0,char=nil,data=nil};
local account_cache={at=0,data=nil};
local CACHE_SECONDS=2;
local ACCOUNT_CACHE_SECONDS=5;
local account_sort='name';
local action_filter='all';

local function mission_totals(c)
    local done,total=0,0;
    local m=HC.modules.missions;
    if m and m.progress_summary then
        local ok,rows=pcall(m.progress_summary,c);
        if ok and type(rows)=='table' then
            for _,r in ipairs(rows) do done=done+(tonumber(r.done) or 0); total=total+(tonumber(r.total) or 0); end
        end
    end
    return done,total;
end

local function limbus_used(c)
    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    return (c.weekly.limbus_1==true and 1 or 0)+(c.weekly.limbus_2==true and 1 or 0);
end

local function seasonal_saved_progress(c)
    local obtained=type(c.seasonal)=='table' and type(c.seasonal.obtained)=='table' and c.seasonal.obtained or {};
    local have,total=0,0;
    local events=HC.modules.seasonal and HC.modules.seasonal.events and HC.modules.seasonal.events() or {};
    for _,event in ipairs(events) do
        for _,reward in ipairs(event.rewards or {}) do
            total=total+1;
            local key=tostring(event.id)..':'..tostring(reward.id);
            if obtained[key]==true then have=have+1; end
        end
    end
    return have,total;
end

local function anniversary_total(c)
    local a=HC.modules.anniversary and HC.modules.anniversary.progress and HC.modules.anniversary.progress(c) or {};
    local done=(tonumber(a.y2023_done) or 0)+(tonumber(a.y2024_done) or 0)+(tonumber(a.y2025_done) or 0);
    local total=(tonumber(a.y2023_total) or 0)+(tonumber(a.y2024_total) or 0)+(tonumber(a.y2025_total) or 0);
    return done,total;
end

local function persist_profile_summary(c,skill,facts)
    if type(c)~='table' or type(skill)~='table' then return; end
    facts=type(facts)=='table' and facts or {};
    c.overview_profile=type(c.overview_profile)=='table' and c.overview_profile or {};
    local p=c.overview_profile; local now=os.time(); local changed=false;
    local values={
        summary_version=2,job=tostring(skill.job or '---'),level=tonumber(skill.level) or 0,
        jobs_75=tonumber(skill.jobs_75) or 0,jobs_total=tonumber(skill.jobs_total) or 0,
        mission_done=tonumber(facts.mission_done) or 0,mission_total=tonumber(facts.mission_total) or 0,
        outposts_have=tonumber(facts.outposts_have) or 0,outposts_total=tonumber(facts.outposts_total) or 0,
        anniversary_done=tonumber(facts.anniversary_done) or 0,anniversary_total=tonumber(facts.anniversary_total) or 0,
        seasonal_done=tonumber(facts.seasonal_done) or 0,seasonal_total=tonumber(facts.seasonal_total) or 0,
        overview_pct=tonumber(facts.overview_pct),
    };
    for k,v in pairs(values) do if v~=nil and p[k]~=v then p[k]=v; changed=true; end end
    if not p.last_seen_at or now-(tonumber(p.last_seen_at) or 0)>=300 then p.last_seen_at=now; changed=true; end
    if changed then
        account_cache={at=0,data=nil};
        if HC.modules.state and HC.modules.state.request_save then HC.modules.state.request_save(1); end
    end
end

local function overview_percent(r)
    local parts={};
    local function add(done,total)
        done=tonumber(done) or 0; total=tonumber(total) or 0;
        if total>0 then parts[#parts+1]=math.max(0,math.min(1,done/total)); end
    end
    add(r.jobs_75,r.jobs_total); add(r.mission_done,r.mission_total); add(r.outposts_have,r.outposts_total);
    add(r.anniversary_done,r.anniversary_total); add(r.seasonal_done,r.seasonal_total);
    if #parts==0 then return nil; end
    local n=0; for _,v in ipairs(parts) do n=n+v; end
    return math.floor((n/#parts)*100+0.5);
end

function M.snapshot(c,force)
    c=type(c)=='table' and c or HC.modules.state.get_char();
    local char=HC.modules.core.character_name();
    local now=os.time();
    if force~=true and cache.data and cache.char==char and now-(tonumber(cache.at) or 0)<CACHE_SECONDS then return cache.data; end

    -- v7.6.7: Overview is action-first. This snapshot is now only responsible
    -- for the compact per-character profile used by the optional Account /
    -- Characters panel. Do not run weekly, ENM, quest, unlock, or Sea/Sky
    -- summary scans here; their dedicated trackers already own that data.
    local skill={job='---',level=0,jobs_75=0,jobs_total=0};
    if HC.modules.skills and HC.modules.skills.overview_summary then
        local ok,s=pcall(HC.modules.skills.overview_summary); if ok and type(s)=='table' then skill=s; end
    end
    local md,mt=mission_totals(c);
    local op_have,op_total=0,0;
    if HC.modules.outposts and HC.modules.outposts.verified_count then
        local ok,a,b=pcall(HC.modules.outposts.verified_count,c); if ok then op_have=tonumber(a) or 0; op_total=tonumber(b) or 0; end
    end
    local ann={};
    if HC.modules.anniversary and HC.modules.anniversary.progress then local ok,a=pcall(HC.modules.anniversary.progress,c); if ok and type(a)=='table' then ann=a; end end
    local seasonal={};
    if HC.modules.seasonal and HC.modules.seasonal.progress then local ok,a=pcall(HC.modules.seasonal.progress,c); if ok and type(a)=='table' then seasonal=a; end end

    local data={
        char=char,skill=skill,mission_done=md,mission_total=mt,
        outposts_have=op_have,outposts_total=op_total,anniversary=ann,seasonal=seasonal,at=now,
    };
    local ad=(tonumber(ann.y2023_done) or 0)+(tonumber(ann.y2024_done) or 0)+(tonumber(ann.y2025_done) or 0);
    local at=(tonumber(ann.y2023_total) or 0)+(tonumber(ann.y2024_total) or 0)+(tonumber(ann.y2025_total) or 0);
    local sd=tonumber(seasonal.rewards_obtained) or 0; local st=tonumber(seasonal.rewards) or 0;
    local profile_row={jobs_75=skill.jobs_75,jobs_total=skill.jobs_total,mission_done=md,mission_total=mt,outposts_have=op_have,outposts_total=op_total,anniversary_done=ad,anniversary_total=at,seasonal_done=sd,seasonal_total=st};
    profile_row.overview_pct=overview_percent(profile_row);
    persist_profile_summary(c,skill,profile_row);
    cache={at=now,char=char,data=data};
    return data;
end

local ACCOUNT_DAILY_IDS={'guild_points','isnm','digging','plant_pots'};
local ACCOUNT_WEEKLY_IDS={'uninvited','requiem_sin','highwind','eco_warrior','black_coffin','chocobo_game','exp_ring','conquest'};
local ACCOUNT_AVATAR_NAMES={'Titan','Ifrit','Leviathan','Ramuh','Garuda','Shiva','Fenrir','Diabolos'};

local function saved_flag_count(values,ids)
    values=type(values)=='table' and values or {};
    local n=0; for _,id in ipairs(ids or {}) do if values[id]==true then n=n+1; end end
    return n,#(ids or {});
end

local function saved_cycle_activity(cc,current_day,current_week)
    local daily_current=(type(cc)=='table' and cc.daily_key==current_day);
    local weekly_current=(type(cc)=='table' and cc.weekly_key==current_week);
    local daily=daily_current and type(cc.daily)=='table' and cc.daily or {};
    local weekly=weekly_current and type(cc.weekly)=='table' and cc.weekly or {};
    local daily_done,daily_total=saved_flag_count(daily,ACCOUNT_DAILY_IDS);
    local weekly_done,weekly_total=saved_flag_count(weekly,ACCOUNT_WEEKLY_IDS);
    local avatars=type(daily.avatar_fights)=='table' and daily.avatar_fights or {};
    local avatar_done=0; for _,name in ipairs(ACCOUNT_AVATAR_NAMES) do if avatars[name]==true then avatar_done=avatar_done+1; end end
    return {daily_done=daily_done,daily_total=daily_total,avatar_done=avatar_done,avatar_total=#ACCOUNT_AVATAR_NAMES,weekly_task_done=weekly_done,weekly_task_total=weekly_total};
end

local function account_dynamis_limits(cc,account_used,current_week)
    local used=0;
    if type(cc)=='table' and cc.weekly_key==current_week and type(cc.weekly)=='table' then
        used=math.max(0,math.min(2,math.floor(tonumber(cc.weekly.dynamis_character_count) or 0)));
    end
    local remaining=math.max(0,3-account_used);
    local cap=math.max(used,math.min(2,used+remaining));
    return used,cap;
end

function M.account_snapshot(force)
    local now=os.time();
    if force~=true and account_cache.data and now-(tonumber(account_cache.at) or 0)<ACCOUNT_CACHE_SECONDS then return account_cache.data; end
    local raw=HC.modules.state and HC.modules.state.raw and HC.modules.state.raw() or {};
    local chars=type(raw.chars)=='table' and raw.chars or {};
    local aw=HC.modules.state and HC.modules.state.get_account_weekly and HC.modules.state.get_account_weekly() or {};
    local account_used=math.max(0,math.min(3,math.floor(tonumber(aw.dynamis_count) or 0)));
    local week=HC.modules.core.weekly_key();
    local day=HC.modules.core.daily_key();
    local current=HC.modules.core.character_name();
    local rows={};
    local jobs_75_sum,jobs_total_sum,overview_sum,overview_n=0,0,0,0;

    for name,cc in pairs(chars) do
        if type(cc)=='table' and tostring(name)~='Unknown' then
            local du,dcap=account_dynamis_limits(cc,account_used,week);
            local lu=0;
            if cc.weekly_key==week and type(cc.weekly)=='table' then lu=limbus_used(cc); end
            local profile=type(cc.overview_profile)=='table' and cc.overview_profile or {};
            local current_row=tostring(name)==tostring(current);

            -- v7 account summaries prefer the compact saved profile. Older
            -- characters transparently fall back to their saved tracker tables
            -- once, without any live inventory/resource scan.
            local md,mt,oh,ot,ad,at,sd,st;
            if tonumber(profile.summary_version)==2 then
                md,mt=tonumber(profile.mission_done) or 0,tonumber(profile.mission_total) or 0;
                oh,ot=tonumber(profile.outposts_have) or 0,tonumber(profile.outposts_total) or 0;
                ad,at=tonumber(profile.anniversary_done) or 0,tonumber(profile.anniversary_total) or 0;
                sd,st=tonumber(profile.seasonal_done) or 0,tonumber(profile.seasonal_total) or 0;
            else
                md,mt=mission_totals(cc);
                oh,ot=0,0;
                if HC.modules.outposts and HC.modules.outposts.verified_count then
                    local ok,a,b=pcall(HC.modules.outposts.verified_count,cc); if ok then oh=tonumber(a) or 0; ot=tonumber(b) or 0; end
                end
                ad,at=anniversary_total(cc);
                sd,st=seasonal_saved_progress(cc);
            end

            local activity=saved_cycle_activity(cc,day,week);
            local row={name=tostring(name),current=current_row,dynamis_used=du,dynamis_cap=dcap,
                limbus_used=lu,daily_done=activity.daily_done,daily_total=activity.daily_total,avatar_done=activity.avatar_done,avatar_total=activity.avatar_total,
                weekly_task_done=activity.weekly_task_done,weekly_task_total=activity.weekly_task_total,
                mission_done=md,mission_total=mt,outposts_have=oh,outposts_total=ot,
                anniversary_done=ad,anniversary_total=at,seasonal_done=sd,seasonal_total=st,
                jobs_75=tonumber(profile.jobs_75) or 0,jobs_total=tonumber(profile.jobs_total) or 0,
                last_seen_at=tonumber(profile.last_seen_at),job=profile.job,level=tonumber(profile.level)};

            if current_row and cache.data and type(cache.data.skill)=='table' then
                row.jobs_75=tonumber(cache.data.skill.jobs_75) or row.jobs_75; row.jobs_total=tonumber(cache.data.skill.jobs_total) or row.jobs_total;
                row.job=tostring(cache.data.skill.job or row.job or '---'); row.level=tonumber(cache.data.skill.level) or row.level;
                row.mission_done=tonumber(cache.data.mission_done) or row.mission_done; row.mission_total=tonumber(cache.data.mission_total) or row.mission_total;
                row.outposts_have=tonumber(cache.data.outposts_have) or row.outposts_have; row.outposts_total=tonumber(cache.data.outposts_total) or row.outposts_total;
                local aa=cache.data.anniversary or {};
                row.anniversary_done=(tonumber(aa.y2023_done) or 0)+(tonumber(aa.y2024_done) or 0)+(tonumber(aa.y2025_done) or 0);
                row.anniversary_total=(tonumber(aa.y2023_total) or 0)+(tonumber(aa.y2024_total) or 0)+(tonumber(aa.y2025_total) or 0);
                local ss=cache.data.seasonal or {};
                row.seasonal_done=tonumber(ss.rewards_obtained) or row.seasonal_done; row.seasonal_total=tonumber(ss.rewards) or row.seasonal_total;
                row.last_seen_at=now;
            end

            row.dynamis_complete=(row.dynamis_cap or 0)>0 and row.dynamis_used>=row.dynamis_cap;
            row.dynamis_state=(row.dynamis_cap or 0)<=0 and 'POOL EMPTY' or (row.dynamis_complete and 'COMPLETE' or 'AVAILABLE');
            row.limbus_complete=row.limbus_used>=2;
            row.limbus_state=row.limbus_complete and 'COMPLETE' or 'AVAILABLE';
            row.overview_pct=overview_percent(row);
            row.mission_pct=(row.mission_total or 0)>0 and math.floor((row.mission_done/row.mission_total)*100+0.5) or nil;
            local event_done=(row.anniversary_done or 0)+(row.seasonal_done or 0);
            local event_total=(row.anniversary_total or 0)+(row.seasonal_total or 0);
            row.events_pct=event_total>0 and math.floor((event_done/event_total)*100+0.5) or nil;
            row.open_weekly_slots=math.max(0,(row.weekly_task_total or 0)-(row.weekly_task_done or 0))+math.max(0,(row.dynamis_cap or 0)-(row.dynamis_used or 0))+math.max(0,2-(row.limbus_used or 0));
            rows[#rows+1]=row;
            jobs_75_sum=jobs_75_sum+(row.jobs_75 or 0); jobs_total_sum=jobs_total_sum+(row.jobs_total or 0);
            if row.overview_pct~=nil then overview_sum=overview_sum+row.overview_pct; overview_n=overview_n+1; end
        end
    end

    local function by_name(a,b)
        if a.current~=b.current then return a.current==true; end
        return string.lower(a.name)<string.lower(b.name);
    end
    if account_sort=='progress' then
        table.sort(rows,function(a,b)
            local ap,bp=tonumber(a.overview_pct) or -1,tonumber(b.overview_pct) or -1;
            if ap~=bp then return ap>bp; end
            return by_name(a,b);
        end);
    elseif account_sort=='weekly' then
        table.sort(rows,function(a,b)
            local aa,bb=tonumber(a.open_weekly_slots) or 0,tonumber(b.open_weekly_slots) or 0;
            if aa~=bb then return aa>bb; end
            return by_name(a,b);
        end);
    elseif account_sort=='last_seen' then
        table.sort(rows,function(a,b)
            local aa,bb=tonumber(a.last_seen_at) or 0,tonumber(b.last_seen_at) or 0;
            if aa~=bb then return aa>bb; end
            return by_name(a,b);
        end);
    else
        table.sort(rows,by_name);
    end

    local account=type(raw.account)=='table' and raw.account or {};
    local tags=type(account.assault_tags)=='table' and tonumber(account.assault_tags.count) or nil;
    local data={rows=rows,characters=#rows,dynamis_used=account_used,dynamis_cap=3,dynamis_remaining=math.max(0,3-account_used),assault_tags=tags,at=now,
        jobs_75=jobs_75_sum,jobs_total=jobs_total_sum,overview_avg=(overview_n>0 and math.floor(overview_sum/overview_n+0.5) or nil),sort=account_sort};
    account_cache={at=now,data=data};
    return data;
end

function M.invalidate()
    cache={at=0,char=nil,data=nil};
    account_cache={at=0,data=nil};
end


local function age_label(at,current)
    if current then return 'Now'; end
    at=tonumber(at); if not at then return '--'; end
    local age=math.max(0,os.time()-at);
    if age<120 then return 'Now'; end
    if age<3600 then return tostring(math.floor(age/60))..'m'; end
    if age<86400 then return tostring(math.floor(age/3600))..'h'; end
    return tostring(math.floor(age/86400))..'d';
end

local function pct_text(v)
    return v~=nil and (tostring(math.max(0,math.min(100,math.floor(tonumber(v) or 0))))..'%') or '--';
end

local function set_account_sort(mode)
    if account_sort==mode then return; end
    account_sort=mode; account_cache={at=0,data=nil};
end

local function saved_character_count()
    local raw=HC.modules.state and HC.modules.state.raw and HC.modules.state.raw() or {};
    local chars=type(raw.chars)=='table' and raw.chars or {};
    local n=0; for name,cc in pairs(chars) do if type(cc)=='table' and tostring(name)~='Unknown' then n=n+1; end end
    return n;
end

local function draw_account_count(imgui,done,total)
    done=tonumber(done) or 0; total=tonumber(total) or 0; local label=string.format('%d/%d',done,total);
    if total>0 and done>=total then imgui.Text(label); else imgui.TextDisabled(label); end
end

local function draw_account_overview(imgui,c)
    imgui.Spacing();
    local count=saved_character_count();
    local label=string.format('Account / Characters  %d saved##overview_account_characters',count);
    if not imgui.CollapsingHeader(label) then return; end

    -- Refresh the current character's compact saved profile only when the user
    -- deliberately expands this optional account panel. This keeps the normal
    -- action-first Overview from running mission/event/outpost summary scans.
    M.snapshot(c,false);
    local a=M.account_snapshot(false);

    local aggregate=string.format('Jobs at 75: %d/%d',a.jobs_75 or 0,a.jobs_total or 0);
    if a.overview_avg~=nil then aggregate=aggregate..' | Average overview: '..tostring(a.overview_avg)..'%'; end
    imgui.TextDisabled(aggregate);
    local shared=string.format('Shared resources: Dynamis %d/%d used | %d remaining',a.dynamis_used or 0,a.dynamis_cap or 3,a.dynamis_remaining or 0);
    if a.assault_tags~=nil then shared=shared..' | Assault Tags '..tostring(a.assault_tags)..'/4'..((tonumber(a.assault_tags) or 0)>=4 and ' CAPPED' or ''); end
    imgui.TextDisabled(shared);
    imgui.TextDisabled('Offline characters use compact saved summaries only; HorizonCheck does not scan another character\'s live inventory or quest state.');

    imgui.TextDisabled('Sort:'); imgui.SameLine();
    if imgui.SmallButton((account_sort=='name' and '[Name]' or 'Name')..'##hc_account_sort_name') then set_account_sort('name'); a=M.account_snapshot(true); end
    imgui.SameLine(); if imgui.SmallButton((account_sort=='progress' and '[Progress]' or 'Progress')..'##hc_account_sort_progress') then set_account_sort('progress'); a=M.account_snapshot(true); end
    imgui.SameLine(); if imgui.SmallButton((account_sort=='weekly' and '[Weekly]' or 'Weekly')..'##hc_account_sort_weekly') then set_account_sort('weekly'); a=M.account_snapshot(true); end
    imgui.SameLine(); if imgui.SmallButton((account_sort=='last_seen' and '[Last Seen]' or 'Last Seen')..'##hc_account_sort_seen') then set_account_sort('last_seen'); a=M.account_snapshot(true); end

    local table_ok=HC.modules.uikit and HC.modules.uikit.table_supported(imgui) and HC.modules.uikit.wide_enough(imgui,820);

    imgui.Spacing();
    imgui.TextDisabled('Saved current-reset activity plus basic job progress for every character.');

    if table_ok and imgui.BeginTable('##hc_account_status_v796',8,HC.modules.uikit.table_flags()) then
        imgui.TableSetupColumn('Character',0,0.23);
        imgui.TableSetupColumn('Jobs 75',0,0.10);
        imgui.TableSetupColumn('Daily',0,0.10);
        imgui.TableSetupColumn('Avatars',0,0.11);
        imgui.TableSetupColumn('Weekly',0,0.11);
        imgui.TableSetupColumn('Dynamis',0,0.11);
        imgui.TableSetupColumn('Limbus',0,0.11);
        imgui.TableSetupColumn('Last Seen',0,0.13);
        imgui.TableHeadersRow();

        for _,r in ipairs(a.rows or {}) do
            imgui.TableNextRow();

            imgui.TableSetColumnIndex(0);
            imgui.Text(r.name..(r.current and ' (Current)' or ''));
            if r.job and tostring(r.job)~='' and tostring(r.job)~='---' then
                imgui.TextDisabled(string.format('%s Lv.%d',tostring(r.job),tonumber(r.level) or 0));
            end

            imgui.TableSetColumnIndex(1);
            imgui.Text(string.format('%d/%d',r.jobs_75 or 0,r.jobs_total or 0));

            imgui.TableSetColumnIndex(2);
            draw_account_count(imgui,r.daily_done,r.daily_total);
            if imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then
                imgui.SetTooltip('Daily Objectives completed this Japanese-midnight cycle.');
            end

            imgui.TableSetColumnIndex(3);
            draw_account_count(imgui,r.avatar_done,r.avatar_total);
            if imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then
                imgui.SetTooltip('Prime-avatar fights completed today.');
            end

            imgui.TableSetColumnIndex(4);
            draw_account_count(imgui,r.weekly_task_done,r.weekly_task_total);
            if imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then
                imgui.SetTooltip('Weekly Objectives excluding the separate Dynamis and Limbus entry counters.');
            end

            imgui.TableSetColumnIndex(5);
            if (r.dynamis_cap or 0)<=0 then
                imgui.TextDisabled('—');
            else
                draw_account_count(imgui,r.dynamis_used,r.dynamis_cap);
            end

            imgui.TableSetColumnIndex(6);
            draw_account_count(imgui,r.limbus_used,2);

            imgui.TableSetColumnIndex(7);
            imgui.TextDisabled(age_label(r.last_seen_at,r.current));
        end
        imgui.EndTable();
    else
        for i,r in ipairs(a.rows or {}) do
            if i>1 then imgui.Separator(); end
            imgui.Text(r.name..(r.current and ' (Current)' or ''));
            imgui.TextDisabled(string.format(
                '%s Lv.%d | Jobs 75 %d/%d | Daily %d/%d | Avatars %d/%d | Weekly %d/%d | Dynamis %d/%d | Limbus %d/2 | Seen %s',
                tostring(r.job or '---'),tonumber(r.level) or 0,
                r.jobs_75 or 0,r.jobs_total or 0,
                r.daily_done or 0,r.daily_total or 4,
                r.avatar_done or 0,r.avatar_total or 8,
                r.weekly_task_done or 0,r.weekly_task_total or 8,
                r.dynamis_used or 0,r.dynamis_cap or 0,
                r.limbus_used or 0,
                age_label(r.last_seen_at,r.current)
            ));
        end
    end

    if #(a.rows or {})==0 then imgui.TextDisabled('No additional saved character profiles yet.'); end
end

local function navigation_for_action(row)
    row=type(row)=='table' and row or {};
    if row.category=='quest' then
        return 'quests',{log_id=row.log_id,quest_id=row.quest_id};
    end
    if row.category=='mission' then
        return 'missions',row.focus or {series_id=row.series_id,number=row.mission_number};
    end
    if row.tab then return row.tab,row.focus; end
    local source=string.lower(tostring(row.source or ''));
    local map={
        assault='assault', enm='enm', dynamis='dynamis', eco='eco', rings='dailyweekly',
        limbus='dailyweekly', isnm='dailyweekly', reset='dailyweekly',
    };
    local tab=map[source];
    local focus=nil;
    if source=='limbus' then focus={section='weekly',objective='limbus'};
    elseif source=='isnm' then focus={section='daily',objective='isnm'};
    elseif source=='rings' then focus={section='weekly',objective='exp_ring'};
    elseif source=='reset' then focus={section='dailyweekly'};
    end
    return tab,focus;
end

local function go_button(imgui,row,id)
    local ui=HC.modules and HC.modules.ui or nil;
    if not (ui and ui.navigate) then return; end
    local tab,focus=navigation_for_action(row);
    if not tab then return; end
    if imgui.SmallButton('Go##overview_go_'..tostring(id)) then ui.navigate(tab,focus); end
end

local function action_matches(row,mode)
    if mode=='here' then return row.here==true; end
    if mode=='now' then return row.tier=='DO NOW'; end
    if mode=='ready' then return row.tier=='READY'; end
    if mode=='prep' then return row.tier=='PREP'; end
    if mode=='ending' then return row.tier=='SOON'; end
    if mode=='blocked' then return row.tier=='LOCKED'; end
    return true;
end

local function planner_rows(c)
    local p=HC.modules and HC.modules.planner or nil;
    if not (p and p.build) then return {},{},nil; end
    local ok,model=pcall(p.build,c,false);
    if not ok or type(model)~='table' then return {},{},nil; end
    local rows={}; local counts={['DO NOW']=0,READY=0,PREP=0,SOON=0,LOCKED=0};
    local tiers=(action_filter=='ending') and {'SOON'} or ((action_filter=='blocked') and {'LOCKED'} or {'DO NOW','READY','PREP'});
    for _,tier in ipairs({'DO NOW','READY','PREP','SOON','LOCKED'}) do
        for _,r in ipairs((model.groups and model.groups[tier]) or {}) do
            r.tier=tier; if action_matches(r,action_filter) then counts[tier]=counts[tier]+1; end
        end
    end
    for _,tier in ipairs(tiers) do
        local tmp={};
        for _,r in ipairs((model.groups and model.groups[tier]) or {}) do
            r.tier=tier; if action_matches(r,action_filter) then tmp[#tmp+1]=r; end
        end
        table.sort(tmp,function(a,b)
            local as=tonumber(a.score) or 0; local bs=tonumber(b.score) or 0;
            if tier=='SOON' then
                local ax=tonumber(a.seconds) or math.huge; local bx=tonumber(b.seconds) or math.huge; if ax~=bx then return ax<bx; end
            end
            if as~=bs then return as>bs; end
            return (tonumber(a.priority) or 100)<(tonumber(b.priority) or 100);
        end);
        for _,r in ipairs(tmp) do rows[#rows+1]=r; end
    end
    return rows,counts,model;
end

local function draw_next_actions(imgui,c)
    if HC.modules.uikit then HC.modules.uikit.section_header('What Should I Do?'); else imgui.Text('What Should I Do?'); imgui.Separator(); end
    local rows,counts,model=planner_rows(c);
    local focus=rows[1];
    if focus then
        local focus_label=(action_filter=='blocked') and 'Top blocker: ' or 'Best next: ';
        imgui.Text(focus_label..tostring(focus.text or ''));
        if focus.reason and tostring(focus.reason)~='' then imgui.SameLine(); imgui.TextDisabled('['..tostring(focus.reason)..']'); end
        imgui.SameLine(); go_button(imgui,focus,'best');
    else
        imgui.TextDisabled('Best next: no matching actionable objective detected.');
    end
    imgui.TextDisabled('View:'); imgui.SameLine();
    local options={{'all','All'},{'here','Here'},{'now','Do Now'},{'ready','Ready'},{'ending','Soon'},{'prep','Prep'},{'blocked','Blocked'}};
    for i,opt in ipairs(options) do
        if i>1 then imgui.SameLine(); end
        if imgui.SmallButton((action_filter==opt[1] and '['..opt[2]..']' or opt[2])..'##overview_action_filter_'..opt[1]) then action_filter=opt[1]; rows,counts,model=planner_rows(c); end
    end
    imgui.TextDisabled(string.format('Do Now %d | Ready %d | Prep/Verify %d | Blocked %d | Ending Soon %d',counts['DO NOW'] or 0,counts.READY or 0,counts.PREP or 0,counts.LOCKED or 0,counts.SOON or 0));
    if #rows==0 then imgui.TextDisabled('No matching actions detected.'); return; end
    local flags=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
    local table_ok=imgui.BeginTable and imgui.TableSetupColumn and imgui.TableHeadersRow and imgui.TableNextRow and imgui.TableSetColumnIndex and imgui.EndTable;
    if table_ok and imgui.BeginTable('##overview_next_actions_v750',5,flags) then
        imgui.TableSetupColumn('State',0,0.16); imgui.TableSetupColumn('Action',0,0.40); imgui.TableSetupColumn('Why',0,0.23); imgui.TableSetupColumn('Source',0,0.13); imgui.TableSetupColumn('Open',0,0.08); imgui.TableHeadersRow();
        for i,r in ipairs(rows) do
            if i>10 then break; end
            local state=(r.tier=='DO NOW' and 'DO NOW') or (r.tier=='READY' and 'READY NOW') or (r.tier=='SOON' and 'ENDING SOON') or (r.tier=='LOCKED' and 'BLOCKED') or 'PREP / VERIFY';
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0); if r.tier=='PREP' or r.tier=='SOON' or r.tier=='LOCKED' then imgui.TextDisabled(state); else imgui.Text(state); end
            imgui.TableSetColumnIndex(1); imgui.Text(tostring(r.text or ''));
            imgui.TableSetColumnIndex(2); imgui.TextDisabled(tostring(r.reason or (r.here and 'current zone' or '-')));
            imgui.TableSetColumnIndex(3); imgui.TextDisabled(tostring(r.source or (r.category=='quest' and 'Quests' or 'Activity')));
            imgui.TableSetColumnIndex(4); go_button(imgui,r,i);
        end
        imgui.EndTable();
        if #rows>10 then imgui.TextDisabled('+'..tostring(#rows-10)..' more matching action(s).'); end
    else
        for i,r in ipairs(rows) do if i>10 then break; end; imgui.Text(tostring(r.tier)..' - '..tostring(r.text)); if r.reason then imgui.SameLine(); imgui.TextDisabled(tostring(r.reason)); end end
    end
end

local function draw_content_readiness(imgui,c)
    local r=HC.modules and HC.modules.readiness or nil; if not (r and r.rows) then return; end
    c.settings=type(c.settings)=='table' and c.settings or {};
    local include_done=(c.settings.show_completed_readiness==true);
    local rows=r.rows(c,include_done);
    imgui.Spacing();
    local actionable,verify=0,0;
    for _,x in ipairs(rows or {}) do
        if x.state=='ACTIVE' or x.state=='READY' then actionable=actionable+1;
        elseif x.state=='VERIFY' or x.state=='PREP' or x.state=='COOLDOWN' then verify=verify+1; end
    end
    local label=string.format('Content Readiness - %d ready / active | %d prep / verify##overview_content_readiness',actionable,verify);
    local open=imgui.CollapsingHeader(label);
    if not open then return; end
    local show={include_done};
    if imgui.Checkbox('Show completed##overview_readiness_show_done',show) then
        c.settings.show_completed_readiness=show[1] and true or false;
        if HC.modules.state and HC.modules.state.save then HC.modules.state.save(); end
        include_done=show[1]; rows=r.rows(c,include_done);
    end
    if #rows==0 then imgui.TextDisabled('No outstanding readiness checks.'); return; end
    local tf=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
    local table_ok=imgui.BeginTable and imgui.TableSetupColumn and imgui.TableHeadersRow and imgui.TableNextRow and imgui.TableSetColumnIndex and imgui.EndTable;
    if table_ok and imgui.BeginTable('##overview_readiness_v770',4,tf) then
        imgui.TableSetupColumn('Content',0,0.22); imgui.TableSetupColumn('State',0,0.16); imgui.TableSetupColumn('Why',0,0.54); imgui.TableSetupColumn('Open',0,0.08); imgui.TableHeadersRow();
        for i,x in ipairs(rows) do
            if i>12 then break; end
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0); imgui.Text(tostring(x.label or x.id or 'Content'));
            imgui.TableSetColumnIndex(1); if x.done then imgui.TextDisabled(tostring(x.state)); else imgui.Text(tostring(x.state)); end
            imgui.TableSetColumnIndex(2); imgui.TextDisabled(tostring(x.reason or '-'));
            imgui.TableSetColumnIndex(3);
            if x.tab and HC.modules.ui and HC.modules.ui.navigate and imgui.SmallButton('Go##readiness_go_'..tostring(i)) then HC.modules.ui.navigate(x.tab,x.focus); end
        end
        imgui.EndTable();
        if #rows>12 then imgui.TextDisabled('+'..tostring(#rows-12)..' more readiness item(s).'); end
    else
        for _,x in ipairs(rows) do imgui.Text(tostring(x.label)..' - '..tostring(x.state)); imgui.SameLine(); imgui.TextDisabled(tostring(x.reason or '')); end
    end
end

local function draw_zone_intelligence(imgui,c)
    local z=HC.modules and HC.modules.zoneintel or nil;
    if not (z and z.draw) then return; end
    local s=z.status and z.status(c) or nil;
    -- Empty-section suppression: when the current zone has no tracked
    -- actionable content, keep Overview focused on actual next actions rather
    -- than rendering an empty Zone Intelligence block.
    if type(s)=='table' and type(s.rows)=='table' and #s.rows==0 then return; end
    imgui.Spacing();
    if HC.modules.uikit then
        HC.modules.uikit.section_header("While You're Here",s and tostring(s.zone or '') or nil);
    else
        imgui.Text('Zone Intelligence'); imgui.Separator();
    end
    z.draw(c,true);
end


local function simple_action_rows(c)
    local p=HC.modules and HC.modules.planner or nil;
    if not (p and p.build) then return {},nil; end
    local ok,model=pcall(p.build,c,false);
    if not ok or type(model)~='table' then return {},nil; end
    local rows={};
    for _,tier in ipairs({'DO NOW','READY'}) do
        local tmp={};
        for _,r in ipairs((model.groups and model.groups[tier]) or {}) do
            r.tier=tier;
            tmp[#tmp+1]=r;
        end
        table.sort(tmp,function(a,b)
            local as=tonumber(a.score) or 0; local bs=tonumber(b.score) or 0;
            if as~=bs then return as>bs; end
            return (tonumber(a.priority) or 100)<(tonumber(b.priority) or 100);
        end);
        for _,r in ipairs(tmp) do rows[#rows+1]=r; end
    end
    return rows,model;
end

local function simple_priority_label(row,index)
    if index==1 then return 'BEST'; end
    if row and row.here==true then return 'HERE'; end
    return row and row.tier=='DO NOW' and 'NOW' or 'READY';
end

local function draw_simple_next(imgui,c)
    if HC.modules.uikit then HC.modules.uikit.section_header('What to Do Next'); else imgui.Text('What to Do Next'); imgui.Separator(); end
    local rows,model=simple_action_rows(c);
    if #rows==0 then
        imgui.Text('Nothing urgent right now.');
        imgui.TextDisabled('Open Daily / Weekly, Quests, or another activity tab whenever you want to pick something specific.');
        return;
    end

    local flags=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
    local table_ok=imgui.BeginTable and imgui.TableSetupColumn and imgui.TableHeadersRow and imgui.TableNextRow and imgui.TableSetColumnIndex and imgui.EndTable;
    local shown=math.min(6,#rows);
    if table_ok and imgui.BeginTable('##overview_simple_actions_v7834',3,flags) then
        imgui.TableSetupColumn('',0,0.10);
        imgui.TableSetupColumn('What to do',0,0.82);
        imgui.TableSetupColumn('',0,0.08);
        imgui.TableHeadersRow();
        for i=1,shown do
            local r=rows[i];
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);
            if i==1 or r.tier=='DO NOW' then imgui.Text(simple_priority_label(r,i)); else imgui.TextDisabled(simple_priority_label(r,i)); end
            imgui.TableSetColumnIndex(1);
            imgui.TextWrapped(tostring(r.text or ''));
            if r.reason and tostring(r.reason)~='' and tostring(r.reason)~='current zone' then
                if imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then imgui.SetTooltip(tostring(r.reason)); end
            end
            imgui.TableSetColumnIndex(2); go_button(imgui,r,'simple_'..tostring(i));
        end
        imgui.EndTable();
    else
        for i=1,shown do
            local r=rows[i];
            imgui.Text(simple_priority_label(r,i)..' - '..tostring(r.text or ''));
            imgui.SameLine(); go_button(imgui,r,'simple_'..tostring(i));
        end
    end

    if #rows>shown then
        imgui.TextDisabled('+'..tostring(#rows-shown)..' more ready option(s)');
    end

    -- Keep the less urgent planner states available without putting them in a
    -- new user's face. This replaces the old seven-button filter bar.
    local extra={};
    for _,tier in ipairs({'PREP','SOON','LOCKED'}) do
        for _,r in ipairs((model and model.groups and model.groups[tier]) or {}) do
            r.tier=tier; extra[#extra+1]=r;
        end
    end
    if #extra>0 and imgui.CollapsingHeader('More Suggestions  '..tostring(#extra)..'##overview_more_suggestions') then
        local n=math.min(8,#extra);
        if table_ok and imgui.BeginTable('##overview_more_actions_v7834',2,flags) then
            imgui.TableSetupColumn('Suggestion',0,0.92); imgui.TableSetupColumn('',0,0.08); imgui.TableHeadersRow();
            for i=1,n do
                local r=extra[i];
                imgui.TableNextRow();
                imgui.TableSetColumnIndex(0); imgui.TextDisabled(tostring(r.text or ''));
                if r.reason and imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then imgui.SetTooltip(tostring(r.reason)); end
                imgui.TableSetColumnIndex(1); go_button(imgui,r,'more_'..tostring(i));
            end
            imgui.EndTable();
        else
            for i=1,n do imgui.TextDisabled(tostring(extra[i].text or '')); end
        end
        if #extra>n then imgui.TextDisabled('+'..tostring(#extra-n)..' more suggestion(s)'); end
    end
end

local function draw_simple_readiness(imgui,c)
    local r=HC.modules and HC.modules.readiness or nil; if not (r and r.rows) then return; end
    local rows=r.rows(c,false) or {};
    local prep={};
    for _,x in ipairs(rows) do
        if x.done~=true and x.state~='ACTIVE' and x.state~='READY' then prep[#prep+1]=x; end
    end
    if #prep==0 then return; end
    imgui.Spacing();
    if not imgui.CollapsingHeader('Things to Prepare  '..tostring(#prep)..'##overview_simple_prepare') then return; end
    imgui.TextDisabled('These are not urgent. They are here when you want to get something ready for later.');
    local flags=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
    local table_ok=imgui.BeginTable and imgui.TableSetupColumn and imgui.TableHeadersRow and imgui.TableNextRow and imgui.TableSetColumnIndex and imgui.EndTable;
    if table_ok and imgui.BeginTable('##overview_simple_prepare_table',3,flags) then
        imgui.TableSetupColumn('Content',0,0.24); imgui.TableSetupColumn('What it needs',0,0.68); imgui.TableSetupColumn('',0,0.08); imgui.TableHeadersRow();
        for i,x in ipairs(prep) do
            if i>8 then break; end
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0); imgui.Text(tostring(x.label or x.id or 'Content'));
            imgui.TableSetColumnIndex(1); imgui.TextDisabled(tostring(x.reason or 'Check this activity for details.'));
            imgui.TableSetColumnIndex(2);
            if x.tab and HC.modules.ui and HC.modules.ui.navigate and imgui.SmallButton('Go##simple_readiness_'..tostring(i)) then HC.modules.ui.navigate(x.tab,x.focus); end
        end
        imgui.EndTable();
        if #prep>8 then imgui.TextDisabled('+'..tostring(#prep-8)..' more item(s) to prepare'); end
    end
end

function M.draw(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    imgui.Text('Overview');
    imgui.Separator();

    draw_simple_next(imgui,c);
    draw_simple_readiness(imgui,c);

    -- The original full planner is still useful for troubleshooting and power
    -- users, but it is intentionally hidden from normal players.
    local developer=type(c.settings)=='table' and c.settings.developer_mode==true;
    if developer then
        imgui.Spacing();
        if imgui.CollapsingHeader('Advanced Planner##overview_advanced_planner') then
            draw_next_actions(imgui,c);
            draw_content_readiness(imgui,c);
            draw_zone_intelligence(imgui,c);
        end
    end

    draw_account_overview(imgui,c);
end

function M.status(c) return M.snapshot(c,false); end
function M.init(ctx) HC=ctx; end
return M;
