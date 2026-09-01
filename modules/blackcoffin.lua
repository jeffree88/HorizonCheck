local M = {};
local HC;

local ORDER = {
    {
        key='scouting',
        name='Scouting the Ashu Talif',
        npc='Halshaob - Nashmau (H-10)',
        item='Imperial Bronze Piece x3',
    },
    {
        key='painter',
        name='Royal Painter Escort',
        npc='Halshaob - Nashmau (H-10)',
        item='Imperial Silver Piece x1',
    },
    {
        key='captain',
        name='Targeting the Captain',
        npc='Halshaob - Nashmau (H-10)',
        item='Imperial Mythril Piece x1',
    },
};

local REWARD_SUMMARY = {
    scouting = {
        boxes='1-2',
        rewards='Koga Shuriken | gems / beastcoins | ??? Box',
        bonus="Swiftwinged Gekko: bonus ??? Dagger (Matron's Knife possible) + ??? Box / PUP attachments",
    },
    painter = {
        boxes='1-3',
        rewards="Koga Shuriken (100%) | Yoichi's Sash | ??? Headpiece | ??? Box",
        bonus='Extra boxes: defeat Black Bartholomew; keep Faluuya undamaged | ??? Box: crafting mats / PUP attachments',
    },
    captain = {
        boxes='1-3',
        rewards="Wardrobe 3 +5 slots (first clear) | Koga Shuriken | Barbarossa's Zerehs / Moufles | ??? Box",
        bonus='Extra boxes: defeat Bubbly before captain; surprise Cutthroat Kabsalah | ??? Box: rare mats / PUP attachments',
    },
};

local reward_textures = {};

local function reward_asset_path(icon)
    return string.format('%saddons/horizoncheck/resources/blackcoffin_rewards/%s.png',
        AshitaCore:GetInstallPath(),icon);
end

local function draw_reward_icon(imgui,icon)
    if not (imgui and imgui.CreateTextureFromFile and imgui.Image) then
        return false;
    end
    if reward_textures[icon]==nil then
        local ok,tex=pcall(imgui.CreateTextureFromFile,reward_asset_path(icon));
        reward_textures[icon]=(ok and tex) or false;
    end
    local tex=reward_textures[icon];
    if not tex or tex==false then return false; end
    local ok=pcall(imgui.Image,tex,{32,32});
    return ok==true;
end

local function draw_mission_heading(imgui,text)
    imgui.Separator();
    imgui.Text('=== '..string.upper(tostring(text))..' ===');
end

local JOBS={
    [1]='WAR',[2]='MNK',[3]='WHM',[4]='BLM',[5]='RDM',[6]='THF',
    [7]='PLD',[8]='DRK',[9]='BST',[10]='BRD',[11]='RNG',[12]='SAM',
    [13]='NIN',[14]='DRG',[15]='SMN',[16]='BLU',[17]='COR',[18]='PUP',
    [19]='DNC',[20]='SCH',[21]='GEO',[22]='RUN',
};

local function current_main_job()
    local job=nil;
    pcall(function()
        if not AshitaCore or not AshitaCore.GetMemoryManager then return; end
        local mm=AshitaCore:GetMemoryManager();
        if not mm or not mm.GetPlayer then return; end
        local p=mm:GetPlayer();
        if not p then return; end
        local id=nil;
        if p.GetMainJob then id=tonumber(p:GetMainJob());
        elseif p.GetMainJobId then id=tonumber(p:GetMainJobId()); end
        job=JOBS[id];
    end);
    return job;
end

local function job_can_equip(job,jobs)
    if not job or not jobs then return false; end
    for token in tostring(jobs):gmatch('%S+') do
        if token==job then return true; end
    end
    return false;
end

local function draw_reward_row(imgui,r,index)
    local prefix=(index%2)==0 and '[2] ' or '[1] ';
    local drew=draw_reward_icon(imgui,r.icon);
    if drew then imgui.SameLine(); end
    imgui.Text(prefix..tostring(r.name));
    if r.stats then imgui.TextDisabled('    Stats: '..tostring(r.stats)); end
    if r.jobs then
        imgui.TextDisabled('    Jobs:  '..tostring(r.jobs));
        local job=current_main_job();
        if job and job_can_equip(job,r.jobs) then
            imgui.Text('    CURRENT JOB CAN EQUIP ('..job..')');
        elseif job then
            imgui.TextDisabled('    Current job: '..job..' - cannot equip');
        end
    end
    if r.note then imgui.TextDisabled('    Note:  '..tostring(r.note)); end
    imgui.Separator();
end

local function account_state()
    local aw=HC.modules.state.get_account_weekly();
    aw.black_coffin=type(aw.black_coffin)=='table' and aw.black_coffin or {};
    local b=aw.black_coffin;
    b.cleared=type(b.cleared)=='table' and b.cleared or {};
    b.locked_out=b.locked_out==true;
    b.failed_step=type(b.failed_step)=='string' and b.failed_step or nil;
    b.legacy_tag_notice=b.legacy_tag_notice==true;
    return b,aw;
end

local function count_done(b)
    local n=0;
    for _,it in ipairs(ORDER) do
        if b.cleared[it.key]==true then n=n+1; end
    end
    return n;
end

local function lifecycle(c,key,state,source,expires_at,details)
    if HC.modules.state and HC.modules.state.activity_set then
        HC.modules.state.activity_set(c,'blackcoffin',key,state,source,'VERIFIED',expires_at,details,true);
    end
end

local function step_by_key(key)
    for _,it in ipairs(ORDER) do if it.key==key then return it; end end
    return nil;
end

local function mission_key_from_text(s)
    s=string.lower(tostring(s or ''));
    if s:find('scouting the ashu talif',1,true) then return 'scouting'; end
    if s:find('royal painter escort',1,true) then return 'painter'; end
    if s:find('targeting the captain',1,true) then return 'captain'; end
    return nil;
end

local function next_step(b)
    if b.locked_out then return nil; end
    for _,it in ipairs(ORDER) do
        if b.cleared[it.key]~=true then return it; end
    end
    return nil;
end

local function sync_character_mirror(c,b)
    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    -- The Weekly / Conquest checkbox represents whether this week's Black
    -- Coffin opportunity is finished, not only whether all three missions
    -- were successfully cleared.  A failure permanently locks the account
    -- out until the weekly reset, so it is also a terminal weekly state.
    if count_done(b)>=3 or b.locked_out==true then
        c.weekly.black_coffin=true;
    else
        c.weekly.black_coffin=nil;
    end
end

local function can_complete(b,key)
    if b.locked_out then return false,'Account is locked out for this week.'; end

    if key=='scouting' then
        if b.cleared.scouting==true then return false,'Scouting is already cleared this week.'; end
        return true,nil;
    end

    -- Every current-week chain must begin with Scouting. A carried-over tag may
    -- still be usable in game, but using it cannot advance the new weekly chain.
    if b.cleared.scouting~=true then
        return false,'Current-week progress must begin with Scouting the Ashu Talif.';
    end

    if key=='painter' then
        if b.cleared.painter==true then return false,'Royal Painter Escort is already cleared this week.'; end
        return true,nil;
    end

    if key=='captain' then
        if b.cleared.painter~=true then
            return false,'Royal Painter Escort must be cleared before Targeting the Captain.';
        end
        if b.cleared.captain==true then return false,'Targeting the Captain is already cleared this week.'; end
        return true,nil;
    end

    return false,'Unknown Black Coffin step.';
end

function M.complete(key,source)
    local c=HC.modules.state.get_char();
    local b=account_state();
    local ok,why=can_complete(b,key);
    if not ok then
        HC.msg('Black Coffin: '..tostring(why));
        return false;
    end

    b.cleared[key]=true;
    b.last_completed_step=key;
    b.last_completed_at=os.time();
    b.last_source=source or 'manual';
    b.active_step=nil;
    b.active_state=nil;
    lifecycle(c,key,'CLEARED',source or 'manual',nil,{completed=true});
    sync_character_mirror(c,b);
    HC.modules.state.save();

    local step=nil;
    for _,it in ipairs(ORDER) do if it.key==key then step=it; break; end end
    HC.msg('Black Coffin weekly: '..tostring(step and step.name or key)..' complete ['..tostring(count_done(b))..'/3 account-wide].');
    return true;
end

function M.fail(key,source)
    local c=HC.modules.state.get_char();
    local b=account_state();
    if b.locked_out then return false; end

    b.locked_out=true;
    b.failed_step=key;
    b.failed_at=os.time();
    b.failed_source=source or 'manual';
    b.active_step=nil;
    b.active_state=nil;
    lifecycle(c,key or 'weekly','LOCKED',source or 'manual',nil,{failed=true,weekly_lockout=true});
    sync_character_mirror(c,b);
    HC.modules.state.save();

    local name=key;
    for _,it in ipairs(ORDER) do if it.key==key then name=it.name; break; end end
    HC.msg('Black Coffin weekly: FAILED / ACCOUNT LOCKED OUT - '..tostring(name)..'. No character can continue this week.');
    return true;
end

function M.status(c)
    local b=account_state();
    sync_character_mirror(c,b);
    local done=count_done(b);

    if b.locked_out then
        local failed=b.failed_step or '?';
        for _,it in ipairs(ORDER) do if it.key==failed then failed=it.name; break; end end
        return string.format('%d/3 | FAILED / LOCKED OUT | %s',done,tostring(failed));
    end

    if done>=3 then
        return '3/3 | COMPLETE | Resets next weekly tally';
    end

    if b.active_step and b.active_state then
        local it=step_by_key(b.active_step);
        return string.format('%d/3 | %s | %s',done,tostring(b.active_state),tostring(it and it.name or b.active_step));
    end

    local nxt=next_step(b);
    if done==0 then
        return '0/3 | START: Scouting the Ashu Talif';
    end
    return string.format('%d/3 | Next: %s',done,tostring(nxt and nxt.name or '?'));
end

local function draw_capture_button(imgui,it)
    if not (HC.modules.learning and HC.modules.learning.start and HC.modules.learning.stop) then return; end
    local learning=HC.modules.learning;
    local cur=learning.current and learning.current() or nil;
    local marker='blackcoffin_'..it.key;
    local active_here=(learning.active and learning.active()==true
        and type(cur)=='table' and cur.target=='blackcoffin' and cur.phase==marker);
    local cap_label=active_here and ('Stop##blackcoffin_capture_'..it.key)
        or ('Capture##blackcoffin_capture_'..it.key);
    if imgui.SmallButton(cap_label) then
        if active_here then
            learning.stop('black coffin row button');
        else
            learning.start('blackcoffin');
            if learning.mark then learning.mark(marker); end
        end
    end
    if imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then
        if active_here then
            imgui.SetTooltip('Stop the evidence capture for '..tostring(it.name)..'.');
        else
            imgui.SetTooltip('Capture packets/text for '..tostring(it.name)..' and tag the report to this mission.');
        end
    end
end

local function draw_chain_table(imgui,b,c)
    local developer=(type(c)=='table' and type(c.settings)=='table' and c.settings.developer_mode==true);
    local flags=HC.modules.uikit.table_flags();
    local supported=(imgui.BeginTable and imgui.TableNextColumn and imgui.EndTable);
    if supported and imgui.BeginTable('##blackcoffin_chain_table',4,flags) then
        if imgui.TableSetupColumn then
            imgui.TableSetupColumn('Mission',0,0.31);
            imgui.TableSetupColumn('State',0,0.12);
            imgui.TableSetupColumn('Start / Entry Cost',0,0.36);
            imgui.TableSetupColumn('Actions',0,0.21);
        end
        if imgui.TableHeadersRow then imgui.TableHeadersRow(); end

        local nxt=next_step(b);
        for i,it in ipairs(ORDER) do
            local cleared=b.cleared[it.key]==true;
            local label=cleared and 'COMPLETE' or 'PENDING';
            if not cleared and not b.locked_out and nxt and nxt.key==it.key then label='NEXT'; end
            if b.locked_out and b.failed_step==it.key then label='FAILED'; end

            if imgui.TableNextRow then imgui.TableNextRow(); end
            if imgui.TableSetColumnIndex then imgui.TableSetColumnIndex(0); else imgui.TableNextColumn(); end
            imgui.Text(tostring(i)..'. '..it.name);

            if imgui.TableSetColumnIndex then imgui.TableSetColumnIndex(1); else imgui.TableNextColumn(); end
            if cleared then imgui.Text(label); else imgui.TextDisabled(label); end

            if imgui.TableSetColumnIndex then imgui.TableSetColumnIndex(2); else imgui.TableNextColumn(); end
            imgui.TextDisabled(it.npc..' | '..it.item);

            if imgui.TableSetColumnIndex then imgui.TableSetColumnIndex(3); else imgui.TableNextColumn(); end
            if not cleared and not b.locked_out then
                if imgui.SmallButton('Complete##blackcoffin_done_'..it.key) then M.complete(it.key,'manual UI'); end
                imgui.SameLine();
                if imgui.SmallButton('Fail##blackcoffin_fail_'..it.key) then M.fail(it.key,'manual UI'); end
                if developer and HC.modules.learning and HC.modules.learning.start and HC.modules.learning.stop then
                    imgui.SameLine(); draw_capture_button(imgui,it);
                end
            else
                imgui.TextDisabled('-');
            end
        end
        imgui.EndTable();
        return;
    end

    -- Compatibility fallback for older ImGui table builds.
    for i,it in ipairs(ORDER) do
        local cleared=b.cleared[it.key]==true;
        local label=cleared and 'COMPLETE' or 'PENDING';
        local nxt=next_step(b);
        if not cleared and not b.locked_out and nxt and nxt.key==it.key then label='NEXT'; end
        if b.locked_out and b.failed_step==it.key then label='FAILED'; end
        imgui.Text(tostring(i)..'. '..it.name..' - '..label);
        imgui.TextDisabled('   '..it.npc..' | '..it.item);
        if not cleared and not b.locked_out then
            if imgui.SmallButton('Complete##blackcoffin_done_fallback_'..it.key) then M.complete(it.key,'manual UI'); end
            imgui.SameLine();
            if imgui.SmallButton('Fail##blackcoffin_fail_fallback_'..it.key) then M.fail(it.key,'manual UI'); end
            if developer and HC.modules.learning and HC.modules.learning.start and HC.modules.learning.stop then
                imgui.SameLine(); draw_capture_button(imgui,it);
            end
        end
        imgui.Separator();
    end
end

local function draw_rewards_table(imgui)
    local flags=HC.modules.uikit.table_flags();
    local supported=(imgui.BeginTable and imgui.TableNextColumn and imgui.EndTable);
    if supported and imgui.BeginTable('##blackcoffin_reward_table',3,flags) then
        if imgui.TableSetupColumn then
            imgui.TableSetupColumn('Mission',0,0.24);
            imgui.TableSetupColumn('Lockboxes',0,0.10);
            imgui.TableSetupColumn('Known Notable Rewards / Bonus',0,0.66);
        end
        if imgui.TableHeadersRow then imgui.TableHeadersRow(); end
        for _,it in ipairs(ORDER) do
            local r=REWARD_SUMMARY[it.key] or {};
            if imgui.TableNextRow then imgui.TableNextRow(); end
            if imgui.TableSetColumnIndex then imgui.TableSetColumnIndex(0); else imgui.TableNextColumn(); end
            imgui.Text(it.name);
            if imgui.TableSetColumnIndex then imgui.TableSetColumnIndex(1); else imgui.TableNextColumn(); end
            imgui.TextDisabled(tostring(r.boxes or '?'));
            if imgui.TableSetColumnIndex then imgui.TableSetColumnIndex(2); else imgui.TableNextColumn(); end
            imgui.TextDisabled(tostring(r.rewards or ''));
            if r.bonus and r.bonus~='' then imgui.TextDisabled('Bonus: '..tostring(r.bonus)); end
        end
        imgui.EndTable();
        return;
    end

    for _,it in ipairs(ORDER) do
        local r=REWARD_SUMMARY[it.key] or {};
        imgui.Text(it.name..' - '..tostring(r.boxes or '?')..' lockbox(es)');
        imgui.TextDisabled('  '..tostring(r.rewards or ''));
        if r.bonus and r.bonus~='' then imgui.TextDisabled('  Bonus: '..tostring(r.bonus)); end
    end
end

function M.draw(c)
    if not HC.imgui then return; end
    local imgui=HC.imgui;
    local b=account_state();
    sync_character_mirror(c,b);
    local done=count_done(b);

    HC.modules.uikit.section_header('Black Coffin Weekly',M.status(c));
    imgui.TextDisabled('Account-wide: complete all 3 battlefields in order. Resets with the weekly Conquest tally.');
    imgui.TextDisabled('A carried-over tag can still be used, but it does not advance the new weekly chain.');
    if b.locked_out then
        imgui.TextDisabled('FAILED: this account cannot continue the chain until the next weekly reset.');
    end

    imgui.Spacing();
    local chain_flags=(done<3) and (ImGuiTreeNodeFlags_DefaultOpen or 0) or 0;
    if imgui.CollapsingHeader('Weekly Chain##blackcoffin_chain',chain_flags) then
        draw_chain_table(imgui,b,c);
    end

    imgui.Spacing();
    HC.modules.uikit.section_header('Rewards','condensed HorizonXI reference');
    draw_rewards_table(imgui);
    imgui.TextDisabled('Known notable rewards only; Horizon-specific full pools and drop rates may still need live verification.');
end

function M.reset_weekly(c)
    -- Account-wide state is automatically reset by state.get_account_weekly()
    -- when the weekly key changes. This function only refreshes the character mirror.
    local b=account_state();
    sync_character_mirror(c,b);
end

local function on_text(s)
    local c=HC.modules.state.get_char();
    local b=account_state();
    local now=os.time();

    -- Capture-verified Halshaob acceptance. Viewing the mission description is
    -- not enough; only the explicit payment/acceptance line arms the step.
    if s:find("in exchange fer lettin' you take on",1,true) then
        local key=mission_key_from_text(s);
        if key then
            b.active_step=key;
            b.active_state='ACCEPTED';
            b.accepted_at=now;
            b.accepted_source='Halshaob mission acceptance';
            lifecycle(c,key,'READY',b.accepted_source,now+(6*60*60),{phase='accepted'});
            HC.modules.state.save();
            return;
        end
    end

    -- Capture-verified Ashu Talif entry signal. The zone transition and 30-minute
    -- message follow this line, so it is strong evidence that the accepted run
    -- actually started.
    if s:find('the order has been given to invade the ashu talif!',1,true) then
        local key=b.active_step or next_step(b) and next_step(b).key or 'scouting';
        b.active_step=key;
        b.active_state='IN PROGRESS';
        b.entered_at=now;
        b.time_limit_seconds=30*60;
        lifecycle(c,key,'IN_PROGRESS','Ashu Talif invasion order',now+(45*60),{time_limit_seconds=30*60});
        HC.modules.state.save();
        return;
    end

    if b.active_state=='IN PROGRESS' and s:find('you have 30 minutes',1,true) and s:find('complete this mission',1,true) then
        b.time_limit_seconds=30*60;
        b.time_limit_verified_at=now;
        HC.modules.state.save();
    end
end

function M.init(ctx)
    HC=ctx;
    if HC.modules.packets and HC.modules.packets.register_text then
        HC.modules.packets.register_text('blackcoffin',on_text);
    end
end

return M;
