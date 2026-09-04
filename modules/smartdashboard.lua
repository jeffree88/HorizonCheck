local M={};
local HC;
local cache={at=0,char=nil,data=nil};
local account_cache={at=0,data=nil};
local CACHE_SECONDS=5;
local ACCOUNT_CACHE_SECONDS=10;
local account_sort='name';
local action_filter='all';
local overview_session={char=nil,baseline={}};

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
        outposts_have=tonumber(facts.outposts_have) or 0,outposts_total=tonumber(facts.outposts_total) or 0,
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
    -- v7.9.26: Missions, Anniversary, and Seasonal Rewards were removed from
    -- normal Overview in v7.9.23.  Do not keep recomputing those retired
    -- summaries every few seconds just to populate invisible compatibility
    -- fields.  Preserve any older saved profile values without live scans.
    local profile=type(c.overview_profile)=='table' and c.overview_profile or {};
    local md,mt=tonumber(profile.mission_done) or 0,tonumber(profile.mission_total) or 0;
    local op_have,op_total=0,0;
    if HC.modules.outposts and HC.modules.outposts.verified_count then
        local ok,a,b=pcall(HC.modules.outposts.verified_count,c); if ok then op_have=tonumber(a) or 0; op_total=tonumber(b) or 0; end
    end
    local ann={y2023_done=0,y2023_total=0,y2024_done=0,y2024_total=0,y2025_done=0,y2025_total=0};
    local seasonal={rewards_obtained=0,rewards=0};

    local job_progress=nil;
    if HC.modules.skills and HC.modules.skills.current_job_progress_detail then
        local ok,jp=pcall(HC.modules.skills.current_job_progress_detail,c);
        if ok and type(jp)=='table' then job_progress=jp; end
    end
    local data={
        char=char,skill=skill,current_job_progress=job_progress,mission_done=md,mission_total=mt,
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
    return {daily_done=daily_done,daily_total=daily_total,avatar_done=avatar_done,avatar_total=#ACCOUNT_AVATAR_NAMES,weekly_task_done=weekly_done,weekly_task_total=weekly_total,daily_valid=daily_current,weekly_valid=weekly_current};
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
                weekly_task_done=activity.weekly_task_done,weekly_task_total=activity.weekly_task_total,daily_valid=activity.daily_valid,weekly_valid=activity.weekly_valid,
                mission_done=md,mission_total=mt,outposts_have=oh,outposts_total=ot,
                anniversary_done=ad,anniversary_total=at,seasonal_done=sd,seasonal_total=st,
                jobs_75=tonumber(profile.jobs_75) or 0,jobs_total=tonumber(profile.jobs_total) or 0,
                last_seen_at=tonumber(profile.last_seen_at),job=profile.job,level=tonumber(profile.level)};

            if current_row and cache.data and type(cache.data.skill)=='table' then
                row.jobs_75=tonumber(cache.data.skill.jobs_75) or row.jobs_75; row.jobs_total=tonumber(cache.data.skill.jobs_total) or row.jobs_total;
                row.job=tostring(cache.data.skill.job or row.job or '---'); row.level=tonumber(cache.data.skill.level) or row.level;
                row.current_job_progress=type(cache.data.current_job_progress)=='table' and cache.data.current_job_progress or nil;
                row.outposts_have=tonumber(cache.data.outposts_have) or row.outposts_have; row.outposts_total=tonumber(cache.data.outposts_total) or row.outposts_total;
                row.last_seen_at=now;
            end

            -- v7.9.21: keep the account comparison on the same 13-objective
            -- weekly scale shown in the main header.  The saved weekly task
            -- table contains the eight character-scoped objectives; the
            -- account-wide Dynamis pool contributes three more and Limbus
            -- contributes two character entries.
            row.weekly_done=(row.weekly_valid==false) and 0 or ((row.weekly_task_done or 0)+account_used+(row.limbus_used or 0));
            row.weekly_total=(row.weekly_valid==false) and 0 or ((row.weekly_task_total or 0)+5);

            -- The logged-in character can use the authoritative live summary
            -- instead of the compact saved-cycle approximation.
            if current_row and HC.modules.weekly then
                if HC.modules.weekly.progress then
                    local ok,wp=pcall(HC.modules.weekly.progress,cc,false);
                    if ok and type(wp)=='table' then
                        row.daily_done=tonumber(wp.daily_done) or row.daily_done;
                        row.daily_total=tonumber(wp.daily_total) or row.daily_total;
                        row.weekly_done=tonumber(wp.weekly_done) or row.weekly_done;
                        row.weekly_total=tonumber(wp.weekly_total) or row.weekly_total;
                        row.daily_valid=true; row.weekly_valid=true;
                    end
                end
                if HC.modules.weekly.daily_avatar_summary then
                    local ok,av=pcall(HC.modules.weekly.daily_avatar_summary,cc);
                    if ok and type(av)=='table' then
                        row.avatar_done=tonumber(av.completed) or row.avatar_done;
                        row.avatar_total=tonumber(av.total) or row.avatar_total;
                    end
                end
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

local function draw_account_count(imgui,done,total,valid)
    if valid==false then imgui.TextDisabled('—'); return; end
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
    imgui.TextDisabled('Reset-scoped values expire automatically at the daily/weekly reset. Permanent progression stays saved; offline live data is clearly marked as last known.');

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
        imgui.TableSetupColumn('Data',0,0.13);
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
            draw_account_count(imgui,r.daily_done,r.daily_total,r.daily_valid);
            if imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then
                imgui.SetTooltip(r.daily_valid==false and 'This saved daily cycle has expired; HorizonCheck does not carry it into the current reset.' or 'Daily Objectives completed this Japanese-midnight cycle.');
            end

            imgui.TableSetColumnIndex(3);
            draw_account_count(imgui,r.avatar_done,r.avatar_total,r.daily_valid);
            if imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then
                imgui.SetTooltip(r.daily_valid==false and 'This saved avatar cycle has expired; HorizonCheck does not carry it into the current reset.' or 'Prime-avatar fights completed today.');
            end

            imgui.TableSetColumnIndex(4);
            draw_account_count(imgui,r.weekly_task_done,r.weekly_task_total,r.weekly_valid);
            if imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then
                imgui.SetTooltip(r.weekly_valid==false and 'This saved weekly cycle has expired; HorizonCheck does not carry it into the current Conquest week.' or 'Weekly Objectives excluding the separate Dynamis and Limbus entry counters.');
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
            if HC.modules.uikit and HC.modules.uikit.data_badge then HC.modules.uikit.data_badge('saved',{current=r.current,last_seen_at=r.last_seen_at}); else imgui.TextDisabled(age_label(r.last_seen_at,r.current)); end
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
                r.daily_valid==false and 0 or (r.daily_done or 0),r.daily_valid==false and 0 or (r.daily_total or 4),
                r.daily_valid==false and 0 or (r.avatar_done or 0),r.daily_valid==false and 0 or (r.avatar_total or 8),
                r.weekly_valid==false and 0 or (r.weekly_task_done or 0),r.weekly_valid==false and 0 or (r.weekly_task_total or 8),
                r.dynamis_used or 0,r.dynamis_cap or 0,
                r.limbus_used or 0,
                age_label(r.last_seen_at,r.current)
            ));
        end
    end

    if #(a.rows or {})==0 then imgui.TextDisabled('No additional saved character profiles yet.'); end
end

local function format_overview_number(n)
    n=math.floor(tonumber(n) or 0);
    local str=tostring(n); local sign='';
    if str:sub(1,1)=='-' then sign='-'; str=str:sub(2); end
    local rev=str:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','');
    return sign..rev;
end

local function overview_ratio(done,total,valid)
    if valid==false then return '—'; end
    done=tonumber(done) or 0; total=tonumber(total) or 0;
    if total<=0 then return '—'; end
    return string.format('%d/%d',done,total);
end

local function draw_metric_grid(imgui,metrics,id)
    local table_ok=HC.modules.uikit and HC.modules.uikit.table_supported(imgui) and HC.modules.uikit.wide_enough(imgui,620);
    if table_ok and imgui.BeginTable('##hc_overview_metrics_'..tostring(id),4,HC.modules.uikit.table_flags()) then
        imgui.TableSetupColumn('Metric',0,0.17); imgui.TableSetupColumn('Status',0,0.33);
        imgui.TableSetupColumn('Metric',0,0.17); imgui.TableSetupColumn('Status',0,0.33);
        for i=1,#metrics,2 do
            imgui.TableNextRow();
            local a=metrics[i]; local b=metrics[i+1];
            imgui.TableSetColumnIndex(0); imgui.TextDisabled(tostring(a and a[1] or ''));
            imgui.TableSetColumnIndex(1); if a then imgui.Text(tostring(a[2] or '—')); end
            imgui.TableSetColumnIndex(2); imgui.TextDisabled(tostring(b and b[1] or ''));
            imgui.TableSetColumnIndex(3); if b then imgui.Text(tostring(b[2] or '—')); end
        end
        imgui.EndTable();
    else
        for _,m in ipairs(metrics or {}) do
            imgui.TextDisabled(tostring(m[1] or '')); imgui.SameLine(); imgui.Text(tostring(m[2] or '—'));
        end
    end
end

local function current_account_row(a)
    for _,r in ipairs((a and a.rows) or {}) do if r.current==true then return r; end end
    return nil;
end

local function overview_open(tab,focus)
    local ui=HC.modules and HC.modules.ui or nil;
    if ui and ui.navigate then ui.navigate(tab,focus); return true; end
    return false;
end

local function overview_clickable_text(imgui,label,id,tab,focus,bright,tooltip)
    if bright==false then imgui.TextDisabled(tostring(label or '—')); else imgui.Text(tostring(label or '—')); end
    if tab and imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then
        imgui.SetTooltip(tostring(tooltip or 'Open '..tostring(tab)));
    end
    if tab and imgui.IsItemClicked and imgui.IsItemClicked() then overview_open(tab,focus); end
end

local function overview_age_long(at)
    at=tonumber(at); if not at then return 'unknown'; end
    local age=math.max(0,os.time()-at);
    if age<120 then return 'just now'; end
    if age<3600 then return tostring(math.floor(age/60))..'m ago'; end
    if age<86400 then return tostring(math.floor(age/3600))..'h ago'; end
    return tostring(math.floor(age/86400))..'d ago';
end

local function overview_available(total,used)
    return math.max(0,(tonumber(total) or 0)-(tonumber(used) or 0));
end

-- v7.9.28: session-change markers intentionally live only in memory.  They
-- reset on addon reload / character swap and never add state writes or scans.
local function overview_session_delta(char,key,value)
    char=tostring(char or 'Unknown');
    if overview_session.char~=char then overview_session={char=char,baseline={}}; end
    value=tonumber(value); if value==nil then return nil; end
    if overview_session.baseline[key]==nil then overview_session.baseline[key]=value; return nil; end
    local delta=value-(tonumber(overview_session.baseline[key]) or value);
    return delta~=0 and delta or nil;
end

local function overview_delta_note(delta,unit)
    delta=tonumber(delta); if not delta or delta==0 then return nil; end
    unit=tostring(unit or '');
    if unit~='' and unit:sub(1,1)~=' ' then unit=' '..unit; end
    return string.format('%+d%s this session',delta,unit);
end

local function overview_join_notes(a,b)
    a=tostring(a or ''); b=tostring(b or '');
    if a=='' then return b~='' and b or nil; end
    if b=='' then return a; end
    return a..'  •  '..b;
end

local function overview_progress_card(done,total,valid,kind)
    done=tonumber(done) or 0; total=tonumber(total) or 0;
    if valid==false then return 'RESET','Saved cycle expired',false; end
    if total<=0 then return '—',nil,false; end
    local left=math.max(0,total-done);
    local ratio=string.format('%d/%d',done,total);
    if left<=0 then return 'COMPLETE',ratio,true; end
    if kind=='jobs' then return tostring(done)..' AT 75',tostring(left)..' remaining',true; end
    return tostring(left)..' LEFT',ratio,done>0;
end

local function overview_entry_card(available,total,label)
    available=math.max(0,tonumber(available) or 0); total=math.max(0,tonumber(total) or 0);
    label=tostring(label or 'entry');
    if total<=0 then return 'POOL EMPTY','No '..label..' available',false; end
    if available<=0 then return 'NO ENTRY','0 available',false; end
    local noun=available==1 and label or (label..'s');
    return 'READY',tostring(available)..' '..noun..' available',true;
end

local function overview_tooltip(title,detail,action)
    local parts={tostring(title or '')};
    if detail and tostring(detail)~='' then parts[#parts+1]=tostring(detail); end
    if action and tostring(action)~='' then parts[#parts+1]=tostring(action); end
    return table.concat(parts,'\n');
end

local function overview_section_break(imgui)
    if HC.modules.uikit and HC.modules.uikit.section_gap then HC.modules.uikit.section_gap();
    else imgui.Spacing(); imgui.Separator(); imgui.Spacing(); end
end

local function draw_overview_cards(imgui,metrics,id,preferred_columns)
    metrics=type(metrics)=='table' and metrics or {};
    local cols=tonumber(preferred_columns) or 3;
    local width=HC.modules.uikit and HC.modules.uikit.window_width and HC.modules.uikit.window_width(imgui) or 0;
    if width>0 and width<620 then cols=1; elseif width>0 and width<850 then cols=2; end
    local table_ok=HC.modules.uikit and HC.modules.uikit.table_supported(imgui);
    if table_ok and imgui.BeginTable('##hc_overview_cards_'..tostring(id),cols,HC.modules.uikit.table_flags()) then
        for i,m in ipairs(metrics) do
            if ((i-1)%cols)==0 and imgui.TableNextRow then imgui.TableNextRow(); end
            if imgui.TableSetColumnIndex then imgui.TableSetColumnIndex((i-1)%cols); else imgui.TableNextColumn(); end
            imgui.TextDisabled(string.upper(tostring(m.label or '')));
            overview_clickable_text(imgui,m.value,m.id,m.tab,m.focus,m.bright,m.tooltip);
            if m.note and tostring(m.note)~='' then imgui.TextDisabled(tostring(m.note)); end
        end
        imgui.EndTable();
    else
        for _,m in ipairs(metrics) do
            imgui.TextDisabled(string.upper(tostring(m.label or ''))); imgui.SameLine();
            overview_clickable_text(imgui,m.value,m.id,m.tab,m.focus,m.bright,m.tooltip);
            if m.note and tostring(m.note)~='' then imgui.SameLine(); imgui.TextDisabled(tostring(m.note)); end
        end
    end
end

local function gear_ratio(g,have_key,total_key)
    if type(g)~='table' then return '—'; end
    local have=tonumber(g[have_key]); local total=tonumber(g[total_key]);
    if have==nil or total==nil or total<=0 then return '—'; end
    return string.format('%d/%d%s',have,total,(have>=total) and ' ✓' or '');
end

local function draw_character_identity(imgui,r,jp)
    local job=tostring(r.job or '---'); local level=tonumber(r.level) or 0;
    local table_ok=HC.modules.uikit and HC.modules.uikit.table_supported(imgui) and HC.modules.uikit.wide_enough(imgui,620);
    if table_ok and imgui.BeginTable('##hc_overview_identity',3,HC.modules.uikit.table_flags()) then
        imgui.TableSetupColumn('Character',0,0.34); imgui.TableSetupColumn('Leveling',0,0.36); imgui.TableSetupColumn('Current Job',0,0.30);
        imgui.TableNextRow();
        imgui.TableSetColumnIndex(0);
        imgui.Text(tostring(r.name));
        imgui.TextDisabled(string.format('%s Lv.%d  |  LIVE',job,level));
        imgui.TableSetColumnIndex(1);
        if jp then
            overview_clickable_text(imgui,string.format('Lv.%d/75  |  %d%% overall',tonumber(jp.level) or level,tonumber(jp.overall_pct) or 0),
                'identity_level','skills',{section='jobprogression',job=job},true,'Open current-job progression');
            imgui.TextDisabled(string.format('%s / %s EXP',format_overview_number(jp.exp_done),format_overview_number(jp.exp_total)));
        else
            imgui.TextDisabled('Level progression unavailable');
        end
        imgui.TableSetColumnIndex(2);
        if jp then
            local maat=tostring(jp.maat or 'N/A'):gsub('%s*%[.-%]','');
            imgui.Text(string.format('Mapped quests %d/%d',tonumber(jp.mapped_done) or 0,tonumber(jp.mapped_total) or 0));
            imgui.TextDisabled('Maat '..maat..'  |  Skills '..tostring(tonumber(jp.skills_capped) or 0)..'/'..tostring(tonumber(jp.skills_total) or 0)..' capped');
        else
            imgui.TextDisabled('Job progression unavailable');
        end
        imgui.EndTable();
    else
        imgui.Text(string.format('%s  |  %s Lv.%d',tostring(r.name),job,level)); imgui.SameLine(); imgui.TextDisabled('| LIVE');
        if jp then
            overview_clickable_text(imgui,string.format('Lv.%d/75 | EXP %s/%s | Overall %d%%',tonumber(jp.level) or level,
                format_overview_number(jp.exp_done),format_overview_number(jp.exp_total),tonumber(jp.overall_pct) or 0),
                'identity_level_fallback','skills',{section='jobprogression',job=job},true,'Open current-job progression');
        end
    end
end

local function draw_current_character_overview(imgui,c,a)
    local r=current_account_row(a);
    local current=HC.modules.core.character_name();
    if HC.modules.uikit then HC.modules.uikit.section_header('Current Character',current); else imgui.Text('Current Character - '..tostring(current)); imgui.Separator(); end
    if not r then imgui.TextDisabled('Current character summary is still being prepared.'); return; end

    local job=tostring(r.job or '---');
    local jp=type(r.current_job_progress)=='table' and r.current_job_progress or nil;
    draw_character_identity(imgui,r,jp);
    if jp then
        local exp_delta=overview_session_delta(current,'exp_done',jp.exp_done);
        if exp_delta and exp_delta>0 then imgui.TextDisabled('+'..format_overview_number(exp_delta)..' EXP this session'); end
    end

    local dyn_cap=tonumber(r.dynamis_cap) or 0;
    local dyn_avail=overview_available(dyn_cap,r.dynamis_used);
    local lim_avail=overview_available(2,r.limbus_used);

    local jobs_value,jobs_note,jobs_bright=overview_progress_card(r.jobs_75,r.jobs_total,true,'jobs');
    jobs_note=overview_join_notes(jobs_note,overview_delta_note(overview_session_delta(current,'jobs75',r.jobs_75),'job'));
    local out_value,out_note,out_bright=overview_progress_card(r.outposts_have,r.outposts_total,true);
    out_note=overview_join_notes(out_note,overview_delta_note(overview_session_delta(current,'outposts',r.outposts_have),'outpost'));
    local daily_value,daily_note,daily_bright=overview_progress_card(r.daily_done,r.daily_total,r.daily_valid);
    daily_note=overview_join_notes(daily_note,overview_delta_note(overview_session_delta(current,'daily',r.daily_valid~=false and r.daily_done or nil),'objective'));
    local avatar_value,avatar_note,avatar_bright=overview_progress_card(r.avatar_done,r.avatar_total,r.daily_valid);
    avatar_note=overview_join_notes(avatar_note,overview_delta_note(overview_session_delta(current,'avatars',r.daily_valid~=false and r.avatar_done or nil),'fight'));
    local weekly_value,weekly_note,weekly_bright=overview_progress_card(r.weekly_done,r.weekly_total,r.weekly_valid);
    weekly_note=overview_join_notes(weekly_note,overview_delta_note(overview_session_delta(current,'weekly',r.weekly_valid~=false and r.weekly_done or nil),'objective'));
    local dyn_value,dyn_note,dyn_bright=overview_entry_card(dyn_avail,dyn_cap,'entry');
    dyn_note=overview_join_notes(dyn_note,overview_delta_note(overview_session_delta(current,'dynamis_available',dyn_avail),'entry'));
    local lim_value,lim_note,lim_bright=overview_entry_card(lim_avail,2,'entry');
    lim_note=overview_join_notes(lim_note,overview_delta_note(overview_session_delta(current,'limbus_available',lim_avail),'entry'));

    imgui.Spacing();
    if HC.modules.uikit then HC.modules.uikit.section_header('Character Status'); else imgui.Text('Character Status'); imgui.Separator(); end
    draw_overview_cards(imgui,{
        {label='Jobs at 75',value=jobs_value,note=jobs_note,id='jobs75',tab='skills',focus={section='jobprogression'},bright=jobs_bright,
            tooltip=overview_tooltip('Jobs at 75',string.format('%d of %d jobs are level 75.',tonumber(r.jobs_75) or 0,tonumber(r.jobs_total) or 0),'Click to open Job Progression.')},
        {label='Outposts',value=out_value,note=out_note,id='outposts',tab='dailyweekly',focus={section='outposts'},bright=out_bright,
            tooltip=overview_tooltip('Outposts',string.format('%d of %d outpost warps verified.',tonumber(r.outposts_have) or 0,tonumber(r.outposts_total) or 0),'Click to open Conquest / Outpost Details.')},
        {label='Daily',value=daily_value,note=daily_note,id='daily',tab='dailyweekly',focus={section='daily'},bright=daily_bright,
            tooltip=overview_tooltip('Daily Objectives',r.daily_valid==false and 'This saved daily cycle has expired.' or string.format('%d/%d complete • %d remaining.',tonumber(r.daily_done) or 0,tonumber(r.daily_total) or 0,math.max(0,(tonumber(r.daily_total) or 0)-(tonumber(r.daily_done) or 0))),'Click to open Daily Objectives.')},
        {label='Avatars',value=avatar_value,note=avatar_note,id='avatars',tab='dailyweekly',focus={section='avatars'},bright=avatar_bright,
            tooltip=overview_tooltip('Daily Avatar Fights',r.daily_valid==false and 'This saved daily cycle has expired.' or string.format('%d/%d completed today • %d remaining.',tonumber(r.avatar_done) or 0,tonumber(r.avatar_total) or 0,math.max(0,(tonumber(r.avatar_total) or 0)-(tonumber(r.avatar_done) or 0))),'Click to open Daily Avatar Fights.')},
        {label='Weekly',value=weekly_value,note=weekly_note,id='weekly',tab='dailyweekly',focus={section='weekly'},bright=weekly_bright,
            tooltip=overview_tooltip('Weekly Objectives',r.weekly_valid==false and 'This saved Conquest cycle has expired.' or string.format('%d/%d complete • %d remaining, including entry counters.',tonumber(r.weekly_done) or 0,tonumber(r.weekly_total) or 0,math.max(0,(tonumber(r.weekly_total) or 0)-(tonumber(r.weekly_done) or 0))),'Click to open Weekly Objectives.')},
        {label='Dynamis',value=dyn_value,note=dyn_note,id='dynamis',tab='dynamis',bright=dyn_bright,
            tooltip=overview_tooltip('Dynamis',string.format('%d character entr%s available • shared account pool %d/%d used.',dyn_avail,dyn_avail==1 and 'y' or 'ies',tonumber(a and a.dynamis_used) or 0,tonumber(a and a.dynamis_cap) or 3),'Click to open Dynamis.')},
        {label='Limbus',value=lim_value,note=lim_note,id='limbus',tab='limbus',bright=lim_bright,
            tooltip=overview_tooltip('Limbus',string.format('%d of 2 character entries currently available.',lim_avail),'Click to open Limbus.')},
    },'current_status',3);

    imgui.Spacing();
    if HC.modules.uikit then HC.modules.uikit.section_header('Current Job',job); else imgui.Text('Current Job - '..job); imgui.Separator(); end
    if jp then
        local maat=tostring(jp.maat or 'N/A'):gsub('%s*%[.-%]','');
        local g=type(jp.gear)=='table' and jp.gear or nil;
        local overall_delta=overview_session_delta(current,'overall_pct',jp.overall_pct);
        local job_metrics={
            {label='Level',value=string.format('%d/75',tonumber(jp.level) or tonumber(r.level) or 0),note=overview_delta_note(overview_session_delta(current,'job_level',jp.level),'level'),id='job_level',tab='skills',focus={section='jobprogression',job=job},bright=true,tooltip=overview_tooltip('Current Job Level','Level progress toward 75.','Click to open current-job progression.')},
            {label='Overall',value=tostring(tonumber(jp.overall_pct) or 0)..'%',note=overall_delta and overview_delta_note(overall_delta,'%') or nil,id='job_overall',tab='skills',focus={section='jobprogression',job=job},bright=true,tooltip=overview_tooltip('Overall EXP Progress',string.format('%s / %s EXP toward Lv.75.',format_overview_number(jp.exp_done),format_overview_number(jp.exp_total)),'Click to open current-job progression.')},
            {label='Maat',value=maat,id='job_maat',tab='skills',focus={section='jobprogression',job=job},bright=(jp.maat_won==true or maat=='N/A'),tooltip=overview_tooltip('Maat',maat=='N/A' and 'This job is not part of the original 15-job Maat set.' or ('Current Maat state: '..maat..'.'),'Click to open current-job progression.')},
            {label='Mapped Quests',value=string.format('%d/%d',tonumber(jp.mapped_done) or 0,tonumber(jp.mapped_total) or 0),note=overview_delta_note(overview_session_delta(current,'mapped_quests',jp.mapped_done),'quest'),id='job_quests',tab='skills',focus={section='jobprogression',job=job},bright=true,tooltip=overview_tooltip('Mapped Job Quests',string.format('%d of %d mapped progression quests complete.',tonumber(jp.mapped_done) or 0,tonumber(jp.mapped_total) or 0),'Click to open current-job progression.')},
            {label='Skills',value=string.format('%d/%d capped',tonumber(jp.skills_capped) or 0,tonumber(jp.skills_total) or 0),note=overview_delta_note(overview_session_delta(current,'skills_capped',jp.skills_capped),'skill'),id='job_skills',tab='skills',focus={section='skills'},bright=(tonumber(jp.skills_capped) or 0)>0,tooltip=overview_tooltip('Combat Skills',string.format('%d of %d tracked combat skills are capped.',tonumber(jp.skills_capped) or 0,tonumber(jp.skills_total) or 0),'Click to open Combat Skills.')},
        };
        if g then
            local function add_gear_card(label,have_key,total_key,id)
                local have,total=tonumber(g[have_key]) or 0,tonumber(g[total_key]) or 0;
                local value,note,bright=overview_progress_card(have,total,true);
                note=overview_join_notes(note,overview_delta_note(overview_session_delta(current,id,have),'piece'));
                job_metrics[#job_metrics+1]={label=label,value=value,note=note,id=id,tab='skills',focus={section='jobprogression',job=job},bright=bright,
                    tooltip=overview_tooltip(label,string.format('%d/%d pieces accounted for in the last observed collection summary.',have,total),'Click to open current-job gear.')};
            end
            add_gear_card('AF','af_have','af_total','job_af');
            add_gear_card('AF +1','af1_have','af1_total','job_af1');
            add_gear_card('Relic','relic_have','relic_total','job_relic');
            add_gear_card('Relic -1','relicm1_have','relicm1_total','job_relicm1');
        end
        draw_overview_cards(imgui,job_metrics,'current_job',3);
        if not g then imgui.TextDisabled('Gear summary appears here after Character Info has observed your AF / Relic collection.'); end
    else
        imgui.TextDisabled('Current-job progression is still being prepared.');
    end
end

local function draw_other_characters_overview(imgui,a)
    local others={};
    for _,r in ipairs((a and a.rows) or {}) do if r.current~=true then others[#others+1]=r; end end
    overview_section_break(imgui);
    if HC.modules.uikit then HC.modules.uikit.section_header('Other Characters',tostring(#others)..' saved'); else imgui.Text('Other Characters'); imgui.Separator(); end
    if #others==0 then imgui.TextDisabled('No other saved characters on this account yet.'); return; end

    local table_ok=HC.modules.uikit and HC.modules.uikit.table_supported(imgui) and HC.modules.uikit.wide_enough(imgui,720);
    if table_ok and imgui.BeginTable('##hc_overview_other_characters_v7928',6,HC.modules.uikit.table_flags()) then
        imgui.TableSetupColumn('Character',0,0.24); imgui.TableSetupColumn('Job',0,0.13); imgui.TableSetupColumn('Daily',0,0.15);
        imgui.TableSetupColumn('Weekly',0,0.15); imgui.TableSetupColumn('Dynamis',0,0.18); imgui.TableSetupColumn('Seen',0,0.15);
        if imgui.TableHeadersRow then imgui.TableHeadersRow(); end
        for _,r in ipairs(others) do
            local job=tostring(r.job or '---'); local level=tonumber(r.level) or 0;
            local daily_value=select(1,overview_progress_card(r.daily_done,r.daily_total,r.daily_valid));
            local weekly_value=select(1,overview_progress_card(r.weekly_done,r.weekly_total,r.weekly_valid));
            local dyn_cap=tonumber(r.dynamis_cap) or 0; local dyn_avail=overview_available(dyn_cap,r.dynamis_used);
            local dyn_value=select(1,overview_entry_card(dyn_avail,dyn_cap,'entry'));
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);
            local open=imgui.CollapsingHeader(tostring(r.name)..'##overview_other_'..tostring(r.name));
            imgui.TableSetColumnIndex(1); imgui.Text(string.format('%s Lv.%d',job,level));
            imgui.TableSetColumnIndex(2); if r.daily_valid==false then imgui.TextDisabled(daily_value) else imgui.Text(daily_value) end
            if imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then imgui.SetTooltip(r.daily_valid==false and 'Saved daily cycle expired.' or string.format('%d/%d daily objectives complete.',tonumber(r.daily_done) or 0,tonumber(r.daily_total) or 0)); end
            imgui.TableSetColumnIndex(3); if r.weekly_valid==false then imgui.TextDisabled(weekly_value) else imgui.Text(weekly_value) end
            if imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then imgui.SetTooltip(r.weekly_valid==false and 'Saved Conquest cycle expired.' or string.format('%d/%d weekly objectives complete.',tonumber(r.weekly_done) or 0,tonumber(r.weekly_total) or 0)); end
            imgui.TableSetColumnIndex(4); if dyn_avail>0 then imgui.Text(dyn_value) else imgui.TextDisabled(dyn_value) end
            if imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then imgui.SetTooltip(string.format('%d Dynamis entr%s available for this saved character.',dyn_avail,dyn_avail==1 and 'y' or 'ies')); end
            imgui.TableSetColumnIndex(5); imgui.TextDisabled(overview_age_long(r.last_seen_at));
            if open then
                local lim_avail=overview_available(2,r.limbus_used);
                imgui.TableNextRow();
                local expanded={
                    {'Jobs 75',overview_ratio(r.jobs_75,r.jobs_total,true),true},
                    {'Avatars',(r.daily_valid==false) and 'RESET' or overview_ratio(r.avatar_done,r.avatar_total,true),r.daily_valid~=false},
                    {'Limbus',tostring(lim_avail)..' available',lim_avail>0},
                    {'Outposts',overview_ratio(r.outposts_have,r.outposts_total,true),true},
                    {'Last Seen',overview_age_long(r.last_seen_at),false},
                    {'Data',((r.daily_valid==false or r.weekly_valid==false) and 'RESET-SCOPED' or 'SAVED'),not (r.daily_valid==false or r.weekly_valid==false)},
                };
                for i,m in ipairs(expanded) do
                    imgui.TableSetColumnIndex(i-1); imgui.TextDisabled(string.upper(m[1]));
                    if m[3] then imgui.Text(m[2]) else imgui.TextDisabled(m[2]) end
                end
            end
        end
        imgui.EndTable();
    else
        for _,r in ipairs(others) do
            local job=tostring(r.job or '---'); local level=tonumber(r.level) or 0;
            local daily_value=select(1,overview_progress_card(r.daily_done,r.daily_total,r.daily_valid));
            local weekly_value=select(1,overview_progress_card(r.weekly_done,r.weekly_total,r.weekly_valid));
            local dyn_cap=tonumber(r.dynamis_cap) or 0; local dyn_avail=overview_available(dyn_cap,r.dynamis_used);
            local dyn_value=select(1,overview_entry_card(dyn_avail,dyn_cap,'entry'));
            local header=string.format('%s — %s Lv.%d  |  %s  |  %s  |  %s  |  %s##overview_other_%s',
                tostring(r.name),job,level,daily_value,weekly_value,dyn_value,overview_age_long(r.last_seen_at),tostring(r.name));
            if imgui.CollapsingHeader(header) then
                local lim_avail=overview_available(2,r.limbus_used);
                draw_overview_cards(imgui,{
                    {label='Jobs at 75',value=overview_ratio(r.jobs_75,r.jobs_total,true),bright=true},
                    {label='Avatars',value=(r.daily_valid==false) and 'RESET' or overview_ratio(r.avatar_done,r.avatar_total,true),bright=r.daily_valid~=false},
                    {label='Limbus',value=tostring(lim_avail)..' available',bright=lim_avail>0},
                    {label='Outposts',value=overview_ratio(r.outposts_have,r.outposts_total,true),bright=true},
                    {label='Last Seen',value=overview_age_long(r.last_seen_at),bright=false},
                },'other_'..tostring(r.name),3);
            end
        end
    end
end

local function draw_shared_account_overview(imgui,a)
    overview_section_break(imgui);
    if HC.modules.uikit then HC.modules.uikit.section_header('Shared Account'); else imgui.Text('Shared Account'); imgui.Separator(); end
    local tags=(a and a.assault_tags~=nil) and (tostring(a.assault_tags)..'/4'..(((tonumber(a.assault_tags) or 0)>=4) and ' ✓' or '')) or '—';
    local used=tonumber(a and a.dynamis_used) or 0; local cap=tonumber(a and a.dynamis_cap) or 3; local remaining=tonumber(a and a.dynamis_remaining) or 0;
    local dyn_value=(remaining<=0) and 'POOL EMPTY' or 'READY';
    draw_overview_cards(imgui,{
        {label='Characters',value=tostring(a and a.characters or 0),bright=true,tooltip=overview_tooltip('Characters',tostring(a and a.characters or 0)..' saved character profiles on this account.')},
        {label='Assault Tags',value=tags,id='shared_tags',tab='assault',bright=true,tooltip=overview_tooltip('Assault Tags',tags..' currently tracked.','Click to open Assault.')},
        {label='Dynamis Pool',value=dyn_value,note=string.format('%d remaining  •  %d/%d used',remaining,used,cap),id='shared_dyn_pool',tab='dynamis',bright=remaining>0,tooltip=overview_tooltip('Shared Dynamis Pool',string.format('%d of %d account-wide entries used • %d remaining.',used,cap,remaining),'Click to open Dynamis.')},
    },'shared',3);
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


local function intelligence_rows(c)
    local out={};
    local function push(tier,score,text,tab,focus,reason)
        out[#out+1]={tier=tier,score=score,priority=10,text=text,tab=tab,focus=focus,reason=reason,source='intelligence'};
    end

    local bc=HC.modules.blackcoffin;
    if bc and bc.summary then
        local ok,b=pcall(bc.summary,c);
        if ok and type(b)=='table' and not b.complete and not b.locked and b.name then
            local tier=(b.state=='ACTIVE' or b.state=='IN PROGRESS') and 'DO NOW' or 'READY';
            local text='Black Coffin - '..tostring(b.state)..': '..tostring(b.name);
            if b.item then text=text..' | '..tostring(b.item); end
            push(tier,tier=='DO NOW' and 175 or 125,text,'blackcoffin',nil,'current weekly chain state');
        end
    end

    local apm=HC.modules.assaultprogress;
    if apm and apm.reward_summary then
        local ok,a=pcall(apm.reward_summary,c);
        if ok and type(a)=='table' then
            local shown=0;
            for _,area in ipairs(a.areas or {}) do
                if (tonumber(area.affordable) or 0)>0 and shown<2 then
                    shown=shown+1;
                    local ap=tonumber(area.ap);
                    local text=string.format('%s - %d unowned reward%s affordable%s',tostring(area.area),tonumber(area.affordable) or 0,(tonumber(area.affordable) or 0)==1 and '' or 's',ap and (' | '..tostring(ap)..' AP') or '');
                    push('READY',110-(shown-1)*5,text,'assault',{section='rewards',area=area.id},'live Assault Point balance + current collection ownership');
                end
            end
        end
    end

    -- Limbus already contributes an action through systems.lua. Only enrich it
    -- here when entry state is especially clear and there is no stronger Black
    -- Coffin/Assault signal competing for the compact six-row Overview.
    local lm=HC.modules.limbus;
    if lm and lm.summary then
        local ok,l=pcall(lm.summary,c);
        if ok and type(l)=='table' and (tonumber(l.remaining) or 0)>0 and l.cleanse==true then
            push('READY',92,string.format('Limbus - %d entr%s available | Cosmo-Cleanse held',tonumber(l.remaining) or 0,(tonumber(l.remaining) or 0)==1 and 'y' or 'ies'),'limbus',nil,'current weekly entry count + held entry key item');
        end
    end
    return out;
end

function M.intelligence(c)
    return intelligence_rows(c or HC.modules.state.get_char());
end

local function simple_action_rows(c)
    local p=HC.modules and HC.modules.planner or nil;
    if not (p and p.build) then return {},nil; end
    local ok,model=pcall(p.build,c,false);
    if not ok or type(model)~='table' then return {},nil; end
    local rows={};
    for _,r in ipairs(intelligence_rows(c)) do rows[#rows+1]=r; end
    for _,tier in ipairs({'DO NOW','READY'}) do
        for _,r in ipairs((model.groups and model.groups[tier]) or {}) do r.tier=tier; rows[#rows+1]=r; end
    end
    table.sort(rows,function(a,b)
        local at=(a.tier=='DO NOW') and 0 or 1; local bt=(b.tier=='DO NOW') and 0 or 1;
        if at~=bt then return at<bt; end
        local as=tonumber(a.score) or 0; local bs=tonumber(b.score) or 0;
        if as~=bs then return as>bs; end
        return (tonumber(a.priority) or 100)<(tonumber(b.priority) or 100);
    end);
    local deduped,seen={},{};
    for _,r in ipairs(rows) do
        local key=string.lower(tostring(r.text or '')):gsub('%s+',' ');
        if not seen[key] then seen[key]=true; deduped[#deduped+1]=r; end
    end
    return deduped,model;
end

local function simple_priority_label(row,index)
    if index==1 then return 'BEST'; end
    if row and row.here==true then return 'HERE'; end
    return row and row.tier=='DO NOW' and 'NOW' or 'READY';
end

local function draw_simple_next(imgui,c)
    if HC.modules.uikit then HC.modules.uikit.section_header('What to Do Next'); else imgui.Text('What to Do Next'); imgui.Separator(); end
    local rows,model=simple_action_rows(c);
    imgui.TextDisabled('Prioritized from current zone, weekly state, entry items, currencies, and collection ownership.');
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

end

function M.draw(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    imgui.Text('Overview');
    imgui.Separator();

    -- v7.9.21: Overview is a true character/account status page.  Action
    -- planning already has a permanent home in the Attention / Next Up strip,
    -- so the normal Overview no longer duplicates a What-to-Do-Next list.
    M.snapshot(c,false);
    local a=M.account_snapshot(false);
    draw_current_character_overview(imgui,c,a);
    draw_other_characters_overview(imgui,a);
    draw_shared_account_overview(imgui,a);

    -- Keep the old planner available only as a developer troubleshooting tool;
    -- it is intentionally not part of the normal Overview experience.
    local developer=type(c.settings)=='table' and c.settings.developer_mode==true;
    if developer then
        imgui.Spacing();
        if imgui.CollapsingHeader('Advanced Planner##overview_advanced_planner') then
            draw_next_actions(imgui,c);
            draw_content_readiness(imgui,c);
            draw_zone_intelligence(imgui,c);
        end
    end
end

function M.status(c) return M.snapshot(c,false); end
function M.init(ctx) HC=ctx; end
return M;
