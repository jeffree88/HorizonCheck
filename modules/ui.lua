local M = {};
local HC;
local pending_navigation=nil;
local current_tab='dashboard';

local TAB_ALIASES={
    overview='dashboard', dashboard='dashboard',
    ['daily / weekly']='dailyweekly', dailyweekly='dailyweekly',
    ['dragon / exp']='dailyweekly', dragon='dailyweekly',
    ['eco-war']='dailyweekly', ['eco war']='dailyweekly', eco='dailyweekly',
    ['black coffin']='blackcoffin', blackcoffin='blackcoffin',
    ['chocobo riding']='chocobo', chocobo='chocobo',
    enm='enm', assault='assault', dynamis='dynamis', limbus='limbus', henm='henm', missions='missions', quests='quests',
    anniversary='events', seasonal='events', events='events', ['sea / sky']='seasky', seasky='seasky',
    ['character info']='skills', skills='skills', ['job progression']='skills', jobprogression='skills',
    settings='status', status='status', diagnostics='diagnostics',
};

local function normalize_tab_key(tab)
    local s=string.lower(tostring(tab or '')):gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$','');
    return TAB_ALIASES[s] or s;
end

function M.init(ctx) HC=ctx; end

function M.navigate(tab,focus)
    local requested=string.lower(tostring(tab or '')):gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$','');
    local key=normalize_tab_key(tab);
    if key=='' then return false; end
    -- Dragon / EXP is now a subsection inside Daily / Weekly. Preserve old
    -- navigation callers/aliases by routing them into the new collapsible
    -- section instead of a removed top-level tab.
    if focus==nil and (requested=='dragon' or requested=='dragon / exp') then
        focus={section='dragon'};
    elseif focus==nil and (requested=='eco' or requested=='eco-war' or requested=='eco war') then
        focus={section='eco'};
    elseif focus==nil and requested=='anniversary' then
        focus={section='anniversary'};
    elseif focus==nil and requested=='seasonal' then
        focus={section='seasonal'};
    elseif requested=='job progression' or requested=='jobprogression' then
        focus=type(focus)=='table' and focus or {};
        focus.section=focus.section or 'jobprogression';
    end
    local c=HC and HC.modules and HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char() or nil;
    if c and key~='diagnostics' then
        c.settings=type(c.settings)=='table' and c.settings or {};
        c.settings.tabs=type(c.settings.tabs)=='table' and c.settings.tabs or {};
        if c.settings.tabs[key]==false then
            c.settings.tabs[key]=true;
            if HC.modules.state and HC.modules.state.request_save then HC.modules.state.request_save(1); end
        end
    end
    pending_navigation={tab=key,focus=focus,selected=false,at=os.time()};
    if HC and HC.ui and HC.ui.open then HC.ui.open[1]=true; end
    if key=='diagnostics' and HC and HC.ui then HC.ui.show_diagnostics_tab=true; end
    return true;
end

function M.consume_focus(tab)
    local key=normalize_tab_key(tab);
    local n=pending_navigation;
    if not n or n.tab~=key or n.selected~=true then return nil; end
    local focus=n.focus; n.focus=nil;
    return focus;
end

local function begin_tab_item(imgui,label,key)
    key=normalize_tab_key(key);
    local n=pending_navigation;
    if n and n.selected==true and n.focus==nil and os.time()-(tonumber(n.at) or 0)>=0 then
        pending_navigation=nil; n=nil;
    elseif n and os.time()-(tonumber(n.at) or 0)>8 then
        pending_navigation=nil; n=nil;
    end
    local wants=(n and n.tab==key and n.selected~=true);
    if wants then
        local flag=rawget(_G,'ImGuiTabItemFlags_SetSelected');
        if type(flag)~='number' then flag=2; end
        local ok,res=pcall(imgui.BeginTabItem,label,nil,flag);
        if ok then
            if res==true then n.selected=true; current_tab=key; end
            return res==true;
        end
    end
    local opened=imgui.BeginTabItem(label);
    if wants and opened==true then n.selected=true; end
    if opened==true then current_tab=key; end
    return opened==true;
end

local function tab_visible(c,key)
    local s=type(c.settings)=='table' and c.settings or {};
    local tabs=type(s.tabs)=='table' and s.tabs or {};
    return tabs[key]~=false;
end

local function dense_ui(c)
    return type(c.settings)=='table' and c.settings.ui_density=='dense';
end


local function safe_draw(name,fn,...)
    if type(fn)~='function' then return false,'draw function unavailable'; end
    local guard=HC and HC.modules and HC.modules.runtimeguard or nil;
    if guard and guard.draw then return guard.draw(name,fn,...); end
    local ok,err=pcall(fn,...);
    if not ok then
        local imgui=HC and HC.imgui or nil;
        if imgui then imgui.Text(tostring(name)..' encountered an error.'); imgui.TextDisabled('See Diagnostics -> Runtime Errors.'); end
        if HC and HC.modules and HC.modules.diagnostics then HC.modules.diagnostics.record_error(name,err); end
        return false,err;
    end
    return true;
end

-- Dense UI used to affect only a single optional separator, which made the
-- setting effectively invisible. Apply a scoped ImGui style to the entire
-- main HorizonCheck window instead. Because every tab/module is rendered
-- beneath this window, the reduced spacing is inherited consistently without
-- requiring each tracker to implement its own density branch.
local function push_density_style(c,imgui)
    if not dense_ui(c) or not imgui or not imgui.PushStyleVar or not imgui.PopStyleVar then return 0; end

    local vars={
        {rawget(_G,'ImGuiStyleVar_WindowPadding'),{6.0,4.0}},
        {rawget(_G,'ImGuiStyleVar_FramePadding'),{4.0,1.0}},
        {rawget(_G,'ImGuiStyleVar_ItemSpacing'),{6.0,2.0}},
        {rawget(_G,'ImGuiStyleVar_ItemInnerSpacing'),{4.0,2.0}},
        {rawget(_G,'ImGuiStyleVar_IndentSpacing'),14.0},
        {rawget(_G,'ImGuiStyleVar_CellPadding'),{4.0,1.0}},
    };
    local pushed=0;
    for _,entry in ipairs(vars) do
        local idx=entry[1];
        if type(idx)=='number' then
            local ok=pcall(imgui.PushStyleVar,idx,entry[2]);
            if ok then pushed=pushed+1; end
        end
    end
    return pushed;
end

local function pop_density_style(imgui,count)
    count=tonumber(count) or 0;
    if count>0 and imgui and imgui.PopStyleVar then pcall(imgui.PopStyleVar,count); end
end


local function push_shared_color_style(imgui)
    if not imgui or not imgui.PushStyleColor or not imgui.PopStyleColor then return 0; end
    local colors={
        {rawget(_G,'ImGuiCol_WindowBg'),{0.06,0.06,0.07,0.96}},
        {rawget(_G,'ImGuiCol_ChildBg'),{0.07,0.07,0.08,0.92}},
        {rawget(_G,'ImGuiCol_PopupBg'),{0.05,0.05,0.06,0.97}},
        {rawget(_G,'ImGuiCol_TitleBg'),{0.01,0.01,0.01,0.98}},
        {rawget(_G,'ImGuiCol_TitleBgActive'),{0.02,0.02,0.02,0.99}},
        {rawget(_G,'ImGuiCol_TitleBgCollapsed'),{0.01,0.01,0.01,0.98}},
        {rawget(_G,'ImGuiCol_FrameBg'),{0.10,0.10,0.12,0.88}},
        {rawget(_G,'ImGuiCol_FrameBgHovered'),{0.14,0.14,0.16,0.92}},
        {rawget(_G,'ImGuiCol_FrameBgActive'),{0.18,0.18,0.20,0.95}},
        {rawget(_G,'ImGuiCol_Header'),{0.18,0.20,0.24,0.92}},
        {rawget(_G,'ImGuiCol_HeaderHovered'),{0.24,0.27,0.32,0.96}},
        {rawget(_G,'ImGuiCol_HeaderActive'),{0.14,0.16,0.20,0.98}},
        {rawget(_G,'ImGuiCol_Button'),{0.22,0.24,0.28,0.90}},
        {rawget(_G,'ImGuiCol_ButtonHovered'),{0.28,0.31,0.36,0.94}},
        {rawget(_G,'ImGuiCol_ButtonActive'),{0.16,0.18,0.22,0.98}},
        {rawget(_G,'ImGuiCol_Tab'),{0.11,0.12,0.14,0.92}},
        {rawget(_G,'ImGuiCol_TabHovered'),{0.21,0.24,0.28,0.96}},
        {rawget(_G,'ImGuiCol_TabSelected'),{0.26,0.29,0.34,0.98}},
        {rawget(_G,'ImGuiCol_TabSelectedOverline'),{0.82,0.84,0.88,0.62}},
        {rawget(_G,'ImGuiCol_TabDimmed'),{0.10,0.10,0.12,0.90}},
        {rawget(_G,'ImGuiCol_TabDimmedSelected'),{0.19,0.21,0.25,0.96}},
        {rawget(_G,'ImGuiCol_TabDimmedSelectedOverline'),{0.72,0.74,0.78,0.52}},
        {rawget(_G,'ImGuiCol_TableHeaderBg'),{0.02,0.02,0.02,0.96}},
        {rawget(_G,'ImGuiCol_TableRowBg'),{1.00,1.00,1.00,0.02}},
        {rawget(_G,'ImGuiCol_TableRowBgAlt'),{1.00,1.00,1.00,0.06}},
        {rawget(_G,'ImGuiCol_ScrollbarBg'),{0.05,0.05,0.06,0.90}},
        {rawget(_G,'ImGuiCol_ScrollbarGrab'),{0.20,0.22,0.26,0.92}},
        {rawget(_G,'ImGuiCol_ScrollbarGrabHovered'),{0.28,0.31,0.36,0.96}},
        {rawget(_G,'ImGuiCol_ScrollbarGrabActive'),{0.16,0.18,0.22,0.98}},
        {rawget(_G,'ImGuiCol_Border'),{0.72,0.72,0.74,0.42}},
        {rawget(_G,'ImGuiCol_Separator'),{0.78,0.78,0.80,0.50}},
        {rawget(_G,'ImGuiCol_SeparatorHovered'),{0.90,0.90,0.92,0.72}},
        {rawget(_G,'ImGuiCol_SeparatorActive'),{1.00,1.00,1.00,0.86}},
        {rawget(_G,'ImGuiCol_TableBorderStrong'),{0.82,0.82,0.84,0.56}},
        {rawget(_G,'ImGuiCol_TableBorderLight'),{0.68,0.68,0.70,0.34}},
    };
    local pushed=0;
    for _,entry in ipairs(colors) do
        local idx=entry[1];
        if type(idx)=='number' then
            local ok=pcall(imgui.PushStyleColor,idx,entry[2]);
            if ok then pushed=pushed+1; end
        end
    end
    return pushed;
end

local function pop_shared_color_style(imgui,count)
    count=tonumber(count) or 0;
    if count>0 and imgui and imgui.PopStyleColor then pcall(imgui.PopStyleColor,count); end
end


local function push_tab_bar_style(imgui)
    if not imgui or not imgui.PushStyleVar or not imgui.PopStyleVar then return 0; end
    local pushed=0;
    local border=rawget(_G,'ImGuiStyleVar_TabBarBorderSize');
    if type(border)=='number' then
        local ok=pcall(imgui.PushStyleVar,border,0.0);
        if ok then pushed=pushed+1; end
    end
    local overline=rawget(_G,'ImGuiStyleVar_TabBarOverlineSize');
    if type(overline)=='number' then
        local ok=pcall(imgui.PushStyleVar,overline,0.0);
        if ok then pushed=pushed+1; end
    end
    return pushed;
end

local function pop_tab_bar_style(imgui,count)
    count=tonumber(count) or 0;
    if count>0 and imgui and imgui.PopStyleVar then pcall(imgui.PopStyleVar,count); end
end


-- Apply wrapping at the window level so ordinary Text/TextDisabled calls in
-- every module wrap to the current window or table-column edge. A wrap pos of
-- 0 is Dear ImGui's "use the current content-region edge" behavior.
local function push_global_text_wrap(imgui)
    if not imgui or not imgui.PushTextWrapPos or not imgui.PopTextWrapPos then return false; end
    return pcall(imgui.PushTextWrapPos,0.0);
end

local function pop_global_text_wrap(imgui,pushed)
    if pushed and imgui and imgui.PopTextWrapPos then pcall(imgui.PopTextWrapPos); end
end


-- Main-window geometry guard.
--
-- A brand-new ImGui window has no persisted geometry yet.  Without an explicit
-- first-use size Dear ImGui can derive a very narrow width from the first frame
-- of content, while the vertically stacked Character Info panels make it grow
-- almost the full height of the screen.  That produces the unusable ~350px-wide
-- first-run layout reported in v7.2.6.
--
-- FirstUseEver preserves every established user's saved size.  The recovery
-- check only repairs clearly-invalid tiny saved geometry (for example a window
-- created by the old first-run behavior); it does not continually force a size.
local invalid_main_size_recovered=false;
local function preferred_main_window_size(imgui)
    -- Keep this deliberately scalar-only. Some HorizonXI / Ashita builds expose
    -- ImVec2 values through the bundled sugar math namespace; indexing those
    -- values with `.x` / `.y` can throw `Math namespace ... x` at runtime.
    -- A fixed first-use size is safer, while still leaving the window fully
    -- resizable and preserving saved geometry for established users.
    return {1180.0,820.0};
end

local function apply_main_window_first_use_defaults(imgui)
    if not imgui then return; end
    local cond=rawget(_G,'ImGuiCond_FirstUseEver');
    if imgui.SetNextWindowSize and type(cond)=='number' then
        pcall(imgui.SetNextWindowSize,preferred_main_window_size(imgui),cond);
    end
    if imgui.SetNextWindowPos and type(cond)=='number' then
        pcall(imgui.SetNextWindowPos,{30.0,30.0},cond);
    end
end

local function recover_invalid_main_window_size(imgui)
    if invalid_main_size_recovered or not imgui or not imgui.SetWindowSize then return; end
    -- Use the scalar width/height APIs instead of GetWindowSize().x/.y. This is
    -- compatible with older HorizonXI Ashita builds whose ImVec2 bridge can
    -- collide with sugar/math.lua.
    local w,h=0,0;
    if imgui.GetWindowWidth then
        local ok,v=pcall(imgui.GetWindowWidth);
        if ok then w=tonumber(v) or 0; end
    end
    if imgui.GetWindowHeight then
        local ok,v=pcall(imgui.GetWindowHeight);
        if ok then h=tonumber(v) or 0; end
    end
    -- Only repair pathological geometry. Normal user-resized windows are left
    -- alone, and after one repair this session the user remains fully in control.
    if (w>0 and w<640) or (h>0 and h<420) then
        pcall(imgui.SetWindowSize,preferred_main_window_size(imgui));
    end
    invalid_main_size_recovered=true;
end

function M.draw()
    local imgui=HC.imgui; if imgui==nil then return; end
    if HC.ui.open[1] then
        local c=HC.modules.state.get_char();
            local density_style_count=push_density_style(c,imgui);
            local color_style_count=push_shared_color_style(imgui);
            apply_main_window_first_use_defaults(imgui);
            if imgui.Begin('HorizonXI Checklist##v55main',HC.ui.open) then
                recover_invalid_main_window_size(imgui);
                local text_wrap_pushed=push_global_text_wrap(imgui);
                imgui.Text('Character: '..HC.modules.core.character_name());

                local hp=HC.modules.weekly and HC.modules.weekly.progress and HC.modules.weekly.progress(c) or nil;
                if hp then
                    local function draw_overview_piece(label,done,total)
                        imgui.SameLine();
                        if tonumber(total) and tonumber(total)>0 and tonumber(done)>=tonumber(total) then
                            imgui.Text(string.format('%s %d/%d',label,done,total));
                        else
                            imgui.TextDisabled(string.format('%s %d/%d',label,done,total));
                        end
                    end

                    imgui.SameLine();
                    imgui.TextDisabled('|');
                    draw_overview_piece('Daily',hp.daily_done,hp.daily_total);
                    imgui.SameLine(); imgui.TextDisabled('|');
                    draw_overview_piece('Weekly',hp.weekly_done,hp.weekly_total);
                    imgui.SameLine(); imgui.TextDisabled('|');

                    if imgui.IsItemHovered and imgui.SetTooltip then
                        local ok=pcall(imgui.IsItemHovered);
                        if ok and imgui.IsItemHovered() then
                            imgui.SetTooltip('Completed overview categories use bright text; incomplete categories stay dimmed.');
                        end
                    end
                end

                imgui.SameLine();
                local developer_mode=(type(c.settings)=='table' and c.settings.developer_mode==true);
                if developer_mode then
                    imgui.TextDisabled('[DEVELOPER] v'..tostring(HC.version or '?'));
                else
                    imgui.TextDisabled('v'..tostring(HC.version or '?'));
                end
                if HC.modules.automation then imgui.SameLine(); imgui.TextDisabled('['..HC.modules.automation.status(c)..']'); end

                if HC.modules.learning and HC.modules.learning.active() then imgui.TextDisabled(HC.modules.learning.status()); end

                if HC.modules.search and HC.modules.search.draw_bar then
                    HC.modules.search.draw_bar(c);
                    if HC.modules.search.active and HC.modules.search.active() then
                        HC.modules.search.draw_results(c);
                        imgui.Separator();
                    end
                end

                c.settings=type(c.settings)=='table' and c.settings or {};
                if HC.modules.releasehealth and HC.modules.releasehealth.draw_setup then
                    safe_draw('Initial Synchronization',HC.modules.releasehealth.draw_setup,c);
                    if not dense_ui(c) and c.settings.setup_wizard_dismissed~=true then imgui.Separator(); end
                end

                -- v7.7.12: keep global Attention visible on every tab, including
                -- Overview, whenever there is an actual urgent DO NOW activity.
                -- Empty/non-urgent Attention still consumes no space.
                local show_global_attention=false;
                if HC.modules.planner and HC.modules.planner.build and HC.modules.planner.has_urgent then
                    local ok_model,model=pcall(HC.modules.planner.build,c,false);
                    if ok_model and type(model)=='table' then
                        local ok_urgent,urgent=pcall(HC.modules.planner.has_urgent,c,model);
                        show_global_attention=(ok_urgent and urgent==true);
                    end
                end
                if show_global_attention then
                    safe_draw('Attention',HC.modules.weekly.draw_attention,c);
                    imgui.Separator();
                end

                local tabs_supported=(imgui.BeginTabBar~=nil and imgui.BeginTabItem~=nil and imgui.EndTabItem~=nil and imgui.EndTabBar~=nil);
                local tab_style_count=push_tab_bar_style(imgui);
                if tabs_supported and imgui.BeginTabBar('HorizonCheckTabs##v6813') then
                    if tab_visible(c,'dashboard') and begin_tab_item(imgui,'Overview##hctab_dashboard_v6900','dashboard') then
                        if HC.modules.smartdashboard then safe_draw('Overview',HC.modules.smartdashboard.draw,c); else imgui.TextDisabled('Overview unavailable.'); end
                        imgui.EndTabItem();
                    end

                    if tab_visible(c,'dailyweekly') and begin_tab_item(imgui,'Daily / Weekly##hctab_dailyweekly','dailyweekly') then
                        local p=HC.modules.weekly.progress(c);
                        local default_open=ImGuiTreeNodeFlags_DefaultOpen or 0;
                        local daily_focus=M.consume_focus('dailyweekly');
                        local focus_section=type(daily_focus)=='table' and tostring(daily_focus.section or '') or '';
                        local focus_objective=type(daily_focus)=='table' and tostring(daily_focus.objective or '') or '';

                        local daily_label=string.format('Daily Objectives %d/%d complete | resets daily##dailyweekly_daily_section',p.daily_done,p.daily_total);
                        if (focus_section=='daily' or focus_section=='dailyweekly') and imgui.SetNextItemOpen then pcall(imgui.SetNextItemOpen,true,rawget(_G,'ImGuiCond_Always') or 1); end
                        if imgui.CollapsingHeader(daily_label,default_open) then
                            safe_draw('Daily Objectives',HC.modules.weekly.draw,c,'daily');
                        end

                        imgui.Spacing();
                        if HC.modules.weekly and HC.modules.weekly.draw_daily_avatars then
                            local av=(HC.modules.weekly.daily_avatar_summary and HC.modules.weekly.daily_avatar_summary(c)) or {held=0,total=8,completed=0};
                            local avatar_label=string.format('Daily Avatar Fights %d/%d key items held | %d/%d completed today | repeatable after Japanese midnight##dailyweekly_avatar_section',
                                tonumber(av.held) or 0,tonumber(av.total) or 8,tonumber(av.completed) or 0,tonumber(av.total) or 8);
                            if focus_section=='avatars' and imgui.SetNextItemOpen then pcall(imgui.SetNextItemOpen,true,rawget(_G,'ImGuiCond_Always') or 1); end
                            if imgui.CollapsingHeader(avatar_label,default_open) then
                                safe_draw('Daily Avatar Fights',HC.modules.weekly.draw_daily_avatars,c,true);
                            end
                        end

                        imgui.Spacing();
                        local weekly_label=string.format('Weekly Objectives %d/%d complete | resets with Conquest tally##dailyweekly_weekly_section',p.weekly_done,p.weekly_total);
                        if focus_section=='weekly' and imgui.SetNextItemOpen then pcall(imgui.SetNextItemOpen,true,rawget(_G,'ImGuiCond_Always') or 1); end
                        if imgui.CollapsingHeader(weekly_label,default_open) then
                            safe_draw('Weekly Objectives',HC.modules.weekly.draw,c,'weekly');
                        end

                        imgui.Spacing();
                        local eco_done,eco_total=0,3;
                        if HC.modules.eco and HC.modules.eco.rotation_count then
                            eco_done,eco_total=HC.modules.eco.rotation_count(c);
                        end
                        local eco_label=string.format('Eco-Warrior %d/%d cleared | resets with Conquest tally##dailyweekly_eco_section',tonumber(eco_done) or 0,tonumber(eco_total) or 3);
                        if focus_section=='eco' and imgui.SetNextItemOpen then pcall(imgui.SetNextItemOpen,true,rawget(_G,'ImGuiCond_Always') or 1); end
                        if imgui.CollapsingHeader(eco_label,default_open) then
                            safe_draw('Eco-Warrior',HC.modules.eco.draw,c,true);
                        end

                        imgui.Spacing();
                        local dragon_label=string.format('Weekly EXP Scrolls %d/%d complete | resets with Conquest tally##dailyweekly_dragon_section',p.dragon_done,p.dragon_total);
                        if focus_section=='dragon' and imgui.SetNextItemOpen then pcall(imgui.SetNextItemOpen,true,rawget(_G,'ImGuiCond_Always') or 1); end
                        if imgui.CollapsingHeader(dragon_label,default_open) then
                            safe_draw('Weekly EXP Scrolls',HC.modules.weekly.draw,c,'dragon');
                        end

                        if HC.modules.outposts then
                            imgui.Spacing();
                            if focus_objective=='conquest' and imgui.SetNextItemOpen then
                                pcall(imgui.SetNextItemOpen,true,rawget(_G,'ImGuiCond_Always') or 1);
                            end
                            if imgui.CollapsingHeader('Conquest / Outpost Details##dailyweekly_outpost_details') then
                                safe_draw('Conquest / Outposts',HC.modules.outposts.draw,c);
                            end
                        end
                        imgui.EndTabItem();
                    end


                    if tab_visible(c,'blackcoffin') and begin_tab_item(imgui,'Black Coffin##hctab_blackcoffin','blackcoffin') then
                        if HC.modules.blackcoffin then
                            safe_draw('Black Coffin',HC.modules.blackcoffin.draw,c);
                        else
                            imgui.TextDisabled('Black Coffin tracker unavailable.');
                        end
                        imgui.EndTabItem();
                    end

                    if tab_visible(c,'chocobo') and begin_tab_item(imgui,'Chocobo Riding##hctab_chocobo','chocobo') then
                        if HC.modules.chocobo then
                            safe_draw('Chocobo Riding',HC.modules.chocobo.draw,c);
                        else
                            imgui.TextDisabled('Chocobo Riding Game tracker unavailable.');
                        end
                        imgui.EndTabItem();
                    end

                    if tab_visible(c,'enm') and begin_tab_item(imgui,'ENM##hctab_enm','enm') then
                        safe_draw('ENM',HC.modules.enm.draw,c);
                        imgui.EndTabItem();
                    end

                    if tab_visible(c,'assault') and begin_tab_item(imgui,'Assault##hctab_assault','assault') then
                        if HC.modules.assault then safe_draw('Assault Tags',HC.modules.assault.draw,c); end
                        if HC.modules.assaultprogress then
                            imgui.Separator();
                            safe_draw('Assault Progress',HC.modules.assaultprogress.draw,c);
                        end
                        imgui.EndTabItem();
                    end

                    if tab_visible(c,'dynamis') and begin_tab_item(imgui,'Dynamis##hctab_dynamis','dynamis') then
                        if HC.modules.dynamis and HC.modules.dynamis.draw then
                            safe_draw('Dynamis',HC.modules.dynamis.draw,c);
                        else
                            imgui.TextDisabled('Dynamis progression tracker unavailable.');
                        end
                        imgui.EndTabItem();
                    end

                    if tab_visible(c,'limbus') and begin_tab_item(imgui,'Limbus##hctab_limbus','limbus') then
                        if HC.modules.limbus and HC.modules.limbus.draw then
                            safe_draw('Limbus',HC.modules.limbus.draw,c);
                        else
                            imgui.TextDisabled('Limbus tracker unavailable.');
                        end
                        imgui.EndTabItem();
                    end

                    if tab_visible(c,'henm') and begin_tab_item(imgui,'HENM##hctab_henm','henm') then
                        if HC.modules.henm and HC.modules.henm.draw then
                            safe_draw('HENM',HC.modules.henm.draw,c);
                        else
                            imgui.TextDisabled('HENM tracker unavailable.');
                        end
                        imgui.EndTabItem();
                    end

                    if tab_visible(c,'missions') and begin_tab_item(imgui,'Missions##hctab_missions','missions') then
                        if HC.modules.missions then
                            safe_draw('Missions',HC.modules.missions.draw,c);
                        else
                            imgui.TextDisabled('Mission checklist unavailable.');
                        end
                        imgui.EndTabItem();
                    end

                    if tab_visible(c,'quests') and begin_tab_item(imgui,'Quests##hctab_quests','quests') then
                        if HC.modules.quests and HC.modules.quests.draw then
                            safe_draw('Quests',HC.modules.quests.draw,c);
                        else
                            imgui.TextDisabled('Quest tracker unavailable.');
                        end
                        imgui.EndTabItem();
                    end

                    if tab_visible(c,'events') and begin_tab_item(imgui,'Events##hctab_events','events') then
                        local event_focus=M.consume_focus('events');
                        local event_section=type(event_focus)=='table' and tostring(event_focus.section or '') or '';
                        local event_default=ImGuiTreeNodeFlags_DefaultOpen or 0;

                        local ann=HC.modules.anniversary and HC.modules.anniversary.progress and HC.modules.anniversary.progress(c) or {};
                        local ann_done=(tonumber(ann.y2023_done) or 0)+(tonumber(ann.y2024_done) or 0)+(tonumber(ann.y2025_done) or 0);
                        local ann_total=(tonumber(ann.y2023_total) or 0)+(tonumber(ann.y2024_total) or 0)+(tonumber(ann.y2025_total) or 0);
                        local ann_label=string.format('Anniversary  %d/%d complete##events_anniversary',ann_done,ann_total);
                        if event_section=='anniversary' and imgui.SetNextItemOpen then pcall(imgui.SetNextItemOpen,true,rawget(_G,'ImGuiCond_Always') or 1); end
                        if imgui.CollapsingHeader(ann_label,event_default) then
                            if HC.modules.anniversary then safe_draw('Anniversary',HC.modules.anniversary.draw,c,true); else imgui.TextDisabled('Anniversary guide unavailable.'); end
                        end

                        imgui.Spacing();
                        local sea=HC.modules.seasonal and HC.modules.seasonal.progress and HC.modules.seasonal.progress(c) or {};
                        local seasonal_label=string.format('Seasonal Events  %d/%d rewards obtained##events_seasonal',tonumber(sea.rewards_obtained) or 0,tonumber(sea.rewards) or 0);
                        if event_section=='seasonal' and imgui.SetNextItemOpen then pcall(imgui.SetNextItemOpen,true,rawget(_G,'ImGuiCond_Always') or 1); end
                        if imgui.CollapsingHeader(seasonal_label,event_default) then
                            if HC.modules.seasonal then safe_draw('Seasonal',HC.modules.seasonal.draw,c,true,event_focus); else imgui.TextDisabled('Seasonal event tracker unavailable.'); end
                        end
                        imgui.EndTabItem();
                    end

                    if tab_visible(c,'seasky') and begin_tab_item(imgui,'Sea / Sky##hctab_seasky','seasky') then
                        if HC.modules.seasky and HC.modules.seasky.draw then
                            safe_draw('Sea / Sky',HC.modules.seasky.draw,c);
                        else
                            imgui.TextDisabled('Sea / Sky collection tracker unavailable.');
                        end
                        imgui.EndTabItem();
                    end

                    if tab_visible(c,'skills') and begin_tab_item(imgui,'Character Info##hctab_skills','skills') then
                        -- Account-wide item lookup is a frequent utility, so keep it
                        -- at the very top of Character Info instead of below the long
                        -- skills / fame / job progression content.
                        if HC.modules.itemlocator and HC.modules.itemlocator.draw then
                            safe_draw('Account Item Locator',HC.modules.itemlocator.draw,c);
                            imgui.Spacing();
                            imgui.Separator();
                            imgui.Spacing();
                        end
                        if HC.modules.skills and HC.modules.skills.draw then
                            safe_draw('Character Info',HC.modules.skills.draw,c);
                        else
                            imgui.TextDisabled('Combat skill reader unavailable.');
                        end
                        imgui.EndTabItem();
                    end

                    if tab_visible(c,'status') and begin_tab_item(imgui,'Settings##hctab_misc','status') then
                        c.settings=type(c.settings)=='table' and c.settings or {};
                        c.settings.tabs=type(c.settings.tabs)=='table' and c.settings.tabs or {};
                        c.settings.notifications=type(c.settings.notifications)=='table' and c.settings.notifications or {};

                        -- Keep this tab focused on readable status + user preferences.  Deep
                        -- troubleshooting remains in the dedicated Diagnostics tab/window.
                        local init=HC.modules.state.initialization_summary and HC.modules.state.initialization_summary(c) or nil;
                        local health=HC.modules.state.health and HC.modules.state.health(c) or {ok=true,issues=0,repaired=0,checks={}};

                        if HC.modules.releasehealth and HC.modules.releasehealth.draw_settings
                            and imgui.CollapsingHeader('Initial Setup & Release Health##status_release_health', ImGuiTreeNodeFlags_DefaultOpen or 0) then
                            safe_draw('Release Health Settings',HC.modules.releasehealth.draw_settings,c);
                        end

                        if imgui.CollapsingHeader('Character Systems##status_character_systems', ImGuiTreeNodeFlags_DefaultOpen or 0) then
                            if HC.modules.guild then
                                safe_draw('Guild Points',HC.modules.guild.draw,c);
                            else
                                imgui.TextDisabled('Guild Point tracker unavailable.');
                            end
                            if HC.modules.haap then
                                imgui.Spacing();
                                imgui.Separator();
                                safe_draw('HAAP',HC.modules.haap.draw,c);
                            end
                        end

                        if imgui.CollapsingHeader('Display & Tabs##status_display_tabs', ImGuiTreeNodeFlags_DefaultOpen or 0) then
                            local dense={dense_ui(c)};
                            if imgui.Checkbox('Dense UI##ui_density_dense',dense) then
                                c.settings.ui_density=dense[1] and 'dense' or 'normal';
                                HC.modules.state.save();
                            end
                            imgui.SameLine();
                            imgui.TextDisabled('Reduce spacing and control padding across all main tabs.');

                            local hide_attention={c.settings.hide_capped_attention==true};
                            if imgui.Checkbox('Hide complete/capped Attention items##hide_capped_attention',hide_attention) then
                                c.settings.hide_capped_attention=hide_attention[1];
                                HC.modules.state.save();
                            end

                            local global_incomplete={c.settings.global_incomplete_only==true};
                            if imgui.Checkbox('Incomplete items only##global_incomplete_only',global_incomplete) then
                                c.settings.global_incomplete_only=global_incomplete[1];
                                c.settings.hide_completed_daily=global_incomplete[1];
                                c.settings.hide_completed_conquest=global_incomplete[1];
                                c.settings.hide_completed_dragon=global_incomplete[1];
                                c.settings.hide_completed_missions=global_incomplete[1];
                                c.settings.hide_completed_quests=global_incomplete[1];
                                c.settings.hide_completed_assaults=global_incomplete[1];
                                c.settings.hide_completed_outposts=global_incomplete[1];
                                HC.modules.state.save();
                            end
                            imgui.TextDisabled('Applies the incomplete-only preference across supported trackers.');

                            imgui.Spacing();
                            imgui.Text('Visible Tabs');
                            imgui.TextDisabled('Choose which activity tabs appear in the main window.');
                            local tab_options={
                                {'dashboard','Overview'},{'dailyweekly','Daily / Weekly'},
                                {'blackcoffin','Black Coffin'},
                                {'chocobo','Chocobo Riding'},{'enm','ENM'},
                                {'assault','Assault'},{'dynamis','Dynamis'},{'limbus','Limbus'},{'henm','HENM'},{'missions','Missions'},{'quests','Quests'},
                                {'events','Events'},{'seasky','Sea / Sky'},{'skills','Character Info'},
                            };
                            local table_ok=(imgui.BeginTable~=nil and imgui.TableNextColumn~=nil and imgui.EndTable~=nil);
                            if table_ok and imgui.BeginTable('##status_visible_tabs',3,64+128+512) then
                                for _,opt in ipairs(tab_options) do
                                    imgui.TableNextColumn();
                                    local v={c.settings.tabs[opt[1]]~=false};
                                    if imgui.Checkbox(opt[2]..'##show_tab_'..opt[1],v) then
                                        c.settings.tabs[opt[1]]=v[1];
                                        HC.modules.state.save();
                                    end
                                end
                                imgui.EndTable();
                            else
                                for _,opt in ipairs(tab_options) do
                                    local v={c.settings.tabs[opt[1]]~=false};
                                    if imgui.Checkbox(opt[2]..'##show_tab_'..opt[1],v) then
                                        c.settings.tabs[opt[1]]=v[1];
                                        HC.modules.state.save();
                                    end
                                end
                            end
                        end

                        if imgui.CollapsingHeader('Notifications##status_notifications') then
                            imgui.TextDisabled('Routine chat notifications only. Errors and important warnings always show.');
                            local opts={
                                {'mission','Mission Sync'},{'assault','Assault / Rytaal'},
                                {'enm','ENM'},{'digging','Chocobo Digging'},
                                {'blackcoffin','Black Coffin'},{'weekly','Weekly / Lockouts'},
                                {'general','Other routine messages'},
                            };
                            local table_ok=(imgui.BeginTable~=nil and imgui.TableNextColumn~=nil and imgui.EndTable~=nil);
                            if table_ok and imgui.BeginTable('##status_notification_grid',2,64+128+512) then
                                for _,opt in ipairs(opts) do
                                    imgui.TableNextColumn();
                                    local v={c.settings.notifications[opt[1]]~=false};
                                    if imgui.Checkbox(opt[2]..'##notify_'..opt[1],v) then
                                        c.settings.notifications[opt[1]]=v[1];
                                        HC.modules.state.save();
                                    end
                                end
                                imgui.EndTable();
                            else
                                for _,opt in ipairs(opts) do
                                    local v={c.settings.notifications[opt[1]]~=false};
                                    if imgui.Checkbox(opt[2]..'##notify_'..opt[1],v) then
                                        c.settings.notifications[opt[1]]=v[1];
                                        HC.modules.state.save();
                                    end
                                end
                            end
                        end

                        if imgui.CollapsingHeader('Quest Preferences##status_quest_preferences') then
                            local qadv={c.settings.quest_ui_advanced==true};
                            if imgui.Checkbox('Show advanced Quest tools##quest_ui_advanced_misc',qadv) then
                                c.settings.quest_ui_advanced=qadv[1];
                                if not qadv[1] then
                                    c.settings.quest_mapped_only=false;
                                    c.settings.quest_catalog_gaps_only=false;
                                    c.settings.quest_missing_filter='all';
                                    c.settings.quest_expansion_filter='all';
                                    c.settings.quest_quality_filter='all';
                                    c.settings.quest_sort='smart';
                                end
                                HC.modules.state.save();
                            end
                            imgui.TextDisabled('Adds catalog health, data audits, advanced filters, and whole-quest confirmation controls to Quests.');

                            local qsplit={c.settings.quest_split_view~=false};
                            if imgui.Checkbox('Use two-pane Quest layout##quest_split_view_misc',qsplit) then
                                c.settings.quest_split_view=qsplit[1];
                                HC.modules.state.save();
                            end
                            imgui.TextDisabled('Keeps the quest list on the left and selected quest details on the right.');

                        end

                        if imgui.CollapsingHeader('Maintenance & Advanced##status_maintenance') then
                            local dev={c.settings.developer_mode==true};
                            if imgui.Checkbox('Developer Mode##hcheck_developer_mode',dev) then
                                c.settings.developer_mode=dev[1];
                                if not dev[1] then HC.ui.show_diagnostics_tab=false; end
                                HC.modules.state.save();
                            end
                            imgui.SameLine();
                            imgui.TextDisabled('Show the Diagnostics tab and capture tools.');

                            if HC.modules.userdata and HC.modules.userdata.status then
                                local uds=HC.modules.userdata.status();
                                imgui.Separator();
                                imgui.Text('User Data Storage');
                                imgui.TextDisabled(tostring(uds.root or '?'));
                                if uds.external then
                                    imgui.TextDisabled('CONFIG / WRITABLE - addon updates can replace the addon folder without replacing user data.');
                                    if uds.legacy_cleanup_attempted then
                                        if uds.legacy_cleanup_waiting then
                                            imgui.TextDisabled('Legacy addon cleanup: waiting for first validated config state save.');
                                        elseif uds.legacy_cleanup_complete then
                                            imgui.TextDisabled(string.format('Legacy addon cleanup: COMPLETE - %d file(s) removed%s.',tonumber(uds.legacy_cleanup_removed) or 0,(tonumber(uds.legacy_cleanup_preserved) or 0)>0 and (', '..tostring(uds.legacy_cleanup_preserved)..' preserved in config') or ''));
                                        else
                                            imgui.TextDisabled('Legacy addon cleanup: ATTENTION - '..tostring(uds.legacy_cleanup_failed or 0)..' file(s) could not be cleaned; sources were left in place.');
                                        end
                                    else
                                        imgui.TextDisabled('Legacy addon cleanup: waiting for validated state migration.');
                                    end
                                else
                                    imgui.TextDisabled('ADDON FOLDER FALLBACK - '..tostring(uds.reason or 'config path unavailable'));
                                end
                            end

                            if HC.modules.state.migration_status then
                                local ms=HC.modules.state.migration_status();
                                imgui.Separator();
                                imgui.Text('State Migration / Backup');
                                imgui.TextDisabled(string.format('Schema %s / %s | %s',tostring(ms.state_schema or '?'),tostring(ms.current_schema or '?'),tostring(ms.last_result or 'current')));
                                if ms.backup_path then imgui.TextDisabled('Pre-migration backup: '..tostring(ms.backup_path)); end
                                if ms.failed then imgui.Text('ATTENTION: '..tostring(ms.validation or 'migration failed')); end
                            end

                            if init then
                                imgui.Separator();
                                imgui.Text('Initialization');
                                if init.complete then
                                    imgui.TextDisabled('[OK] All core trackers initialized');
                                else
                                    imgui.TextDisabled(tostring(init.count)..' tracker(s) need initialization:');
                                    for _,step in ipairs(init.pending or {}) do
                                        imgui.TextDisabled('  - '..tostring(step));
                                    end
                                end
                            end

                            if HC.modules.state.tracker_confidence then
                                imgui.Separator();
                                imgui.Text('Tracker Confidence');
                                local tc=HC.modules.state.tracker_confidence(c);
                                local order={'assault','missions','digging','dynamis','limbus','exp_ring'};
                                local labels={assault='Assault Tags',missions='Missions',digging='Digging',dynamis='Dynamis',limbus='Limbus',exp_ring='EXP Ring'};
                                local table_ok=(imgui.BeginTable~=nil and imgui.TableNextColumn~=nil and imgui.EndTable~=nil);
                                if table_ok and imgui.BeginTable('##status_tracker_confidence',2,64+128+512) then
                                    for _,k in ipairs(order) do
                                        local t=tc[k] or {};
                                        imgui.TableNextColumn();
                                        imgui.TextDisabled(labels[k] or k);
                                        imgui.TableNextColumn();
                                        local line=tostring(t.confidence or 'UNKNOWN');
                                        if t.source then line=line..' - '..tostring(t.source); end
                                        imgui.TextDisabled(line);
                                    end
                                    imgui.EndTable();
                                else
                                    for _,k in ipairs(order) do
                                        local t=tc[k] or {};
                                        local line=(labels[k] or k)..': '..tostring(t.confidence or 'UNKNOWN');
                                        if t.source then line=line..' - '..tostring(t.source); end
                                        imgui.TextDisabled(line);
                                    end
                                end
                            end

                            imgui.Separator();
                            imgui.Text('State Health / Self-Test');
                            for _,check in ipairs(health.checks or {}) do
                                local mark=check.ok and '[OK]' or '[ATTN]';
                                imgui.TextDisabled(mark..' '..tostring(check.name)..' - '..tostring(check.detail or ''));
                            end
                            if not health.ok then
                                if imgui.Button('Repair Known Issues##state_health_repair') then
                                    local n=HC.modules.state.reconcile and HC.modules.state.reconcile(c) or 0;
                                    HC.modules.state.save();
                                    HC.msg('State Health: repaired '..tostring(n)..' known issue(s).');
                                end
                            end

                            imgui.Separator();
                            imgui.Text('Reset Interface');
                            imgui.TextDisabled('Resets display, filters, tabs, notifications, and Developer Mode only. Tracking data is preserved.');
                            if imgui.Button('Reset UI Settings##reset_ui_only') then
                                if HC.modules.state.reset_ui_settings then
                                    HC.modules.state.reset_ui_settings(c);
                                    HC.ui.show_diagnostics_tab=false;
                                    HC.msg('UI settings reset. Tracking data was not changed.');
                                end
                            end
                        end

                        imgui.EndTabItem();
                    end

                    local devmode=(type(c.settings)=='table' and c.settings.developer_mode==true) or HC.ui.show_diagnostics_tab==true;
                    if devmode and begin_tab_item(imgui,'Diagnostics##hctab_diag','diagnostics') then
                        if HC.modules.diagnostics and HC.modules.diagnostics.draw then
                            safe_draw('Diagnostics',HC.modules.diagnostics.draw,c);
                        else
                            imgui.TextDisabled('Diagnostics module unavailable.');
                        end
                        imgui.EndTabItem();
                    end

                    imgui.EndTabBar();
                else
                    -- Compatibility fallback for older Ashita ImGui builds.
                    safe_draw('Weekly Compatibility View',HC.modules.weekly.draw,c);
                    if HC.modules.outposts then safe_draw('Outposts Compatibility View',HC.modules.outposts.draw,c); end
                    if HC.modules.eco then safe_draw('Eco Compatibility View',HC.modules.eco.draw,c); end
                    if HC.modules.blackcoffin then safe_draw('Black Coffin Compatibility View',HC.modules.blackcoffin.draw,c); end
                    if HC.modules.chocobo then safe_draw('Chocobo Compatibility View',HC.modules.chocobo.draw,c); end
                    if HC.modules.enm then safe_draw('ENM Compatibility View',HC.modules.enm.draw,c); end
                    if HC.modules.assaultprogress then safe_draw('Assault Compatibility View',HC.modules.assaultprogress.draw,c); end
                    if HC.modules.guild then safe_draw('Guild Compatibility View',HC.modules.guild.draw,c); end
                end
                pop_tab_bar_style(imgui,tab_style_count);
                pop_global_text_wrap(imgui,text_wrap_pushed);
            end
            imgui.End();
            pop_shared_color_style(imgui,color_style_count);
            pop_density_style(imgui,density_style_count);
    end
end
return M;
