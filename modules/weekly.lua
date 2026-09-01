local M = {};
local HC;
local progress_cache={at=0,char=nil,data=nil};
local PROGRESS_CACHE_SECONDS=1;

local daily = {
    { id='guild_points', name='Guild Points', note='Assigned guild + total GP. Check today\'s requested guild item / turn-in.' },
    { id='isnm', name='ISNM Order / Run', note='Shajaf - Aht Urhgan Whitegate (F-8). 2,000 ISP Confidential or 3,000 ISP Secret Imperial Order.' },
    { id='digging', name='Digging', note='' },
    { id='plant_pots', name='Check Plant Pots', note='Mog House gardening - automatically tracks each unique planted flowerpot.' },
};

-- Repeatable prime-avatar fights available again after Japanese midnight
-- after the previous reward is claimed.  These are intentionally kept out of
-- the normal Daily Objectives completion total: this panel is a readiness
-- view showing whether the character currently holds each required key item.
local daily_avatars = {
    { avatar='Titan',     npc='Juroro',       location='Port Bastok (I-8)',              key_item='Tuning fork of earth' },
    { avatar='Ifrit',     npc='Ronta-Onta',   location='Kazham (J-9)',                   key_item='Tuning fork of fire' },
    { avatar='Leviathan', npc='Edal-Tahdal',  location='Norg (H-9)',                     key_item='Tuning fork of water' },
    { avatar='Ramuh',     npc='Ripapa',        location='Mhaura (I-9)',                   key_item='Tuning fork of lightning' },
    { avatar='Garuda',    npc='Agado-Pugado', location='Rabao (G-9)',                    key_item='Tuning fork of wind' },
    { avatar='Shiva',     npc='Gulmama',       location="Northern San d'Oria (E-7)",    key_item='Tuning fork of ice' },
    { avatar='Fenrir',    npc='Leepe-Hoppe',   location='Windurst Waters, South (J-9)', key_item='Moon Bauble' },
    { avatar='Diabolos',  npc='Kerutoto',      location='Windurst Waters, South (J-8)', key_item='Vial of Dream Incense' },
};

local avatar_ki_cache={ at=0, rows=nil };
local AVATAR_KI_CACHE_SECONDS=1;

local weekly = {
    { id='uninvited', name='Uninvited Guests', note='Justinius - Tavnazian Safehold. Permit and weekly lockout auto-tracked.' },
    { id='requiem_sin', name="Requiem of Sin (X's Knife)", note="Despachiaire - Tavnazian Safehold (K-10). Once per Conquest cycle; enter Boneyard Gully. X's Knife is one possible reward." },
    { id='highwind', name='Highwind', note='Weekly Highwind monster kill. Completed automatically when HorizonCheck sees Highwind go down.' },
    { id='eco_warrior', name='Eco-Warrior', note='One Eco-Warrior completion per Conquest period. Rotation tracked separately below.' },
    { id='black_coffin', name='Black Coffin Weekly', note='Account-wide 3-step weekly chain. Failure locks the account until weekly reset.' },
    { id='chocobo_game', name='Chocobo Riding Game', note='Progress: READY -> IN PROGRESS -> COMPLETE. Tracks live elapsed time, route PBs, run history, and observed rewards.' },
    { id='exp_ring', name='EXP Ring', note='Check weekly recharge/replacement eligibility. Ring status shown under Attention.' },
    { id='conquest', name='Conquest / Outposts', note='Check regional control after tally, complete missing Supply Runs, unlock Outpost warps.' },
};

local dragon = {
    { id='dc_eco', name='Eco-Warrior', note='Any national Eco-Warrior. Reward includes Dragon Chronicles.' },
    { id='dc_haap', name='HAAP.I - Dragon Chronicles', note='Selbina (H-8). Weekly Dragon Chronicles claim.' },
    { id='mm_haap', name="HAAP.I - Miratete's Memoirs", note='Selbina (H-8). Weekly Miratete claim.' },
    { id='mm_rivenwort', name='Spice Gals - Rivernewort', quest_key='spice_gals', note='Rouva - Southern San d\'Oria (L-6). Capture retained for Rivernewort pickup and completion evidence.' },
    { id='mm_cookbook', name='Secrets of Ovens Lost - Cookbook', quest_key='ovens_lost', note='' },
};

local REQUIEM_KEY_ITEMS={
    'Letter from the Mithran Trackers',
    'Letter from Shikaree Y',
};

local requiem_on_text=nil;

local function current_zone_name()
    local q=HC and HC.modules and HC.modules.quests or nil;
    if q and q.current_zone then
        local ok,v=pcall(q.current_zone);
        if ok and v and tostring(v)~='' then return tostring(v); end
    end
    local zs=HC and HC.modules and HC.modules.zonesync or nil;
    if zs and zs.status then
        local ok,s=pcall(zs.status);
        if ok and type(s)=='table' and (s.zone_name or s.zone_id) then return tostring(s.zone_name or s.zone_id); end
    end
    return 'Unknown';
end

local function requiem_key_item_state()
    local ki=HC and HC.modules and HC.modules.keyitems or nil;
    if not (ki and ki.ownership_name) then return nil,nil,false; end
    local known_false=0;
    for _,name in ipairs(REQUIEM_KEY_ITEMS) do
        local ok,owned=pcall(ki.ownership_name,name);
        if ok and owned==true then return true,name,false; end
        if ok and owned==false then known_false=known_false+1; end
    end
    return false,nil,(known_false==#REQUIEM_KEY_ITEMS);
end

local function remember_requiem_key_item(c,name,source)
    if type(c)~='table' then return false; end
    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    if c.weekly.requiem_sin==true then return false; end
    local changed=(c.weekly.requiem_ki_seen~=true or c.weekly.requiem_ki_name~=name);
    c.weekly.requiem_ki_seen=true;
    c.weekly.requiem_ki_name=tostring(name or c.weekly.requiem_ki_name or 'Requiem key item');
    c.weekly.requiem_ki_seen_at=tonumber(c.weekly.requiem_ki_seen_at) or os.time();
    c.weekly.requiem_ki_source=tostring(source or c.weekly.requiem_ki_source or 'key-item observation');
    if changed and HC.modules.state and HC.modules.state.save then pcall(HC.modules.state.save); end
    return changed;
end

local function refresh_requiem_key_item(c)
    if type(c)~='table' then return nil,nil,false; end
    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    local held,name,known_absent=requiem_key_item_state();
    if held==true then remember_requiem_key_item(c,name,'0x055 key-item ownership'); end
    if held==false and known_absent==true and c.weekly.requiem_ki_seen==true then
        c.weekly.requiem_ki_consumed=true;
        c.weekly.requiem_ki_consumed_at=tonumber(c.weekly.requiem_ki_consumed_at) or os.time();
    end
    return held,name,known_absent;
end

local function mark_requiem_complete(c,source)
    if type(c)~='table' then return false; end
    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    if c.weekly.requiem_sin==true then return false; end
    c.weekly.requiem_sin=true;
    c.weekly.requiem_ki_consumed=true;
    c.weekly.requiem_clear_at=os.time();
    c.weekly.requiem_clear_source=tostring(source or 'Boneyard Gully battlefield clear');
    if M.invalidate_progress then M.invalidate_progress(); end
    if HC.modules.state and HC.modules.state.audit then
        pcall(HC.modules.state.audit,c,'weekly','Requiem of Sin completed this Conquest cycle','VERIFIED',c.weekly.requiem_clear_source);
    elseif HC.modules.state and HC.modules.state.save then
        pcall(HC.modules.state.save);
    end
    if HC.msg then HC.msg('AUTO: Requiem of Sin COMPLETE [battlefield clear + consumed weekly key item].'); end
    return true;
end

requiem_on_text=function(s,e)
    local low=string.lower(tostring(s or ''));
    if low=='' then return; end
    local c=HC and HC.modules and HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char() or nil;
    if type(c)~='table' then return; end
    c.weekly=type(c.weekly)=='table' and c.weekly or {};

    if low:find('obtained key item',1,true) then
        for _,name in ipairs(REQUIEM_KEY_ITEMS) do
            if low:find(string.lower(name),1,true) then
                remember_requiem_key_item(c,name,'obtained key item message');
                break;
            end
        end
    end

    if low:find('battlefield clear time:',1,true) then
        local held,_,known_absent=refresh_requiem_key_item(c);
        local zone=string.lower(current_zone_name());
        local in_boneyard=(zone:find('boneyard gully',1,true)~=nil);
        local armed=(c.weekly.requiem_ki_seen==true);
        local consumed=(c.weekly.requiem_ki_consumed==true or held~=true);
        -- A generic battlefield-clear line is not sufficient by itself. Require
        -- current-cycle Requiem KI proof, the KI no longer being held, and
        -- Boneyard Gully. The KI may become unreadable immediately after entry,
        -- so an authoritative current-cycle seen flag plus a Boneyard clear is
        -- allowed to close the run even when the post-consumption bitmap is not
        -- yet fully indexed.
        if in_boneyard and armed and consumed then
            mark_requiem_complete(c,'Boneyard Gully battlefield clear + Requiem key-item consumption');
        end
    end
end

function M.init(ctx)
    HC=ctx;
    if HC.modules and HC.modules.packets and HC.modules.packets.register_text then
        HC.modules.packets.register_text('weekly_requiem_sin',requiem_on_text);
    end
end

local function developer_mode(c)
    return type(c)=='table' and type(c.settings)=='table' and c.settings.developer_mode==true;
end


-- Global text wrapping is safest when long prose starts with the full content
-- width. Keep short status notes inline, but move longer explanatory notes to
-- their own row so SameLine() cannot leave only a few pixels for wrapping.
local function draw_note(imgui,text,prefix)
    text=tostring(text or '');
    if text=='' then return; end
    prefix=tostring(prefix or '- ');
    if #text>64 then
        imgui.TextDisabled('  '..prefix..text);
    else
        imgui.SameLine();
        imgui.TextDisabled(prefix..text);
    end
end


local function count_list(list,values)
    local done=0;
    for _,it in ipairs(list) do if values[it.id]==true then done=done+1; end end
    return done,#list;
end

local function pair_count(values,a,b)
    return (values[a]==true and 1 or 0)+(values[b]==true and 1 or 0);
end

-- Dynamis has a shared account-wide pool of three entries and a maximum of
-- two entries per character. A character's visible quota therefore shrinks
-- when another character has already consumed part of the account pool.
-- Example: account 2/3 + untouched character = character 0/1, not 0/2.
function M.dynamis_limits(c)
    c=type(c)=='table' and c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    c.weekly=type(c.weekly)=='table' and c.weekly or {};
    local aw=HC.modules.state.get_account_weekly and HC.modules.state.get_account_weekly() or {};
    local account_used=math.max(0,math.min(3,math.floor(tonumber(aw.dynamis_count) or 0)));
    local character_used=math.max(0,math.min(2,math.floor(tonumber(c.weekly.dynamis_character_count) or 0)));
    local account_remaining=math.max(0,3-account_used);
    local character_cap=math.max(character_used,math.min(2,character_used+account_remaining));
    local character_remaining=math.max(0,character_cap-character_used);
    return {
        account_used=account_used,
        account_cap=3,
        account_remaining=account_remaining,
        character_used=character_used,
        character_cap=character_cap,
        character_remaining=character_remaining,
        complete=(character_remaining<=0),
    };
end

local function draw_run_counter(c,label,a,b,note,id)
    local imgui=HC.imgui;
    local done=pair_count(c.weekly,a,b);

    -- Auto-completion indicator: checked only when this character has used
    -- both weekly lockouts. Manual repair controls live in Diagnostics.
    local auto_done={done>=2};
    imgui.Checkbox('##weekly_auto_done_'..tostring(id),auto_done);
    if imgui.IsItemHovered~=nil and imgui.IsItemHovered() then
        imgui.SetTooltip('This checks itself when you have used both weekly entries.');
    end
    imgui.SameLine();
    imgui.Text(string.format('%s: %d/2 used | %d remaining',label,done,2-done));
    if HC.modules.automation and (label=='Dynamis' or label=='Limbus') then imgui.SameLine(); imgui.TextDisabled('[Tracks this for you]'); end
    local ki_detail=nil;
    if label=='Limbus' and HC.modules.keyitems and HC.modules.keyitems.cosmo_cleanse_status then
        local ks=HC.modules.keyitems.cosmo_cleanse_status();
        if ks and ks.owned==true then imgui.SameLine(); imgui.TextDisabled('[Cosmo-Cleanse held]'); ki_detail='Cosmo-Cleanse held'; end
    end
    if developer_mode(c) and HC.modules.learning and HC.modules.learning.capture_button and (label=='Dynamis' or label=='Limbus') then
        imgui.SameLine();
        HC.modules.learning.capture_button(string.lower(label),'weekly_run_'..id);
    end
    if note then draw_note(imgui,note,'- '); end
end

function M.progress(c,force)
    c=type(c)=='table' and c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    local char=(HC.modules.core and HC.modules.core.character_name and HC.modules.core.character_name()) or 'Unknown';
    local now=os.time();
    if force~=true and progress_cache.data and progress_cache.char==char
        and now-(tonumber(progress_cache.at) or 0)<PROGRESS_CACHE_SECONDS
    then
        return progress_cache.data;
    end
    refresh_requiem_key_item(c);
    if HC.modules.haap and HC.modules.haap.reconcile then HC.modules.haap.reconcile(c,false); end
    if HC.modules.outposts and HC.modules.outposts.reconcile then HC.modules.outposts.reconcile(c); end
    local dd,dt=count_list(daily,c.daily);
    local wd,wt=count_list(weekly,c.weekly);
    local aw=HC.modules.state.get_account_weekly and HC.modules.state.get_account_weekly() or {};
    wd=wd+math.max(0,math.min(3,math.floor(tonumber(aw.dynamis_count) or 0)))+pair_count(c.weekly,'limbus_1','limbus_2');
    wt=wt+5;
    local gd,gt=count_list(dragon,c.dragon_weekly);
    local data={daily_done=dd,daily_total=dt,weekly_done=wd,weekly_total=wt,dragon_done=gd,dragon_total=gt};
    progress_cache={at=now,char=char,data=data};
    return data;
end

function M.invalidate_progress()
    progress_cache={at=0,char=nil,data=nil};
end

function M.draw_attention(c)
    local imgui=HC.imgui; if imgui==nil then return; end
    if HC.modules.planner and HC.modules.planner.draw then
        -- Planner hides the empty Attention column while keeping Next Up visible.
        HC.modules.planner.draw(c);
    else
        imgui.TextDisabled('Planner unavailable.');
    end
end

local function capture_profile_for_daily(id)
    -- Guild Points capture button removed: core GP dialogue states are now verified.
    if id=='isnm' then return 'isnm'; end
    if id=='assault_tags' then return 'tags'; end
    if id=='assault' then return 'assault'; end
    if id=='plant_pots' then return 'pots'; end
    return nil;
end

local function capture_profile_for_weekly(id)
    if id=='eco_warrior' then return 'eco'; end
    if id=='highwind' then return 'highwind'; end
    if id=='chocobo_game' then return 'chocobo'; end
    if id=='black_coffin' then return 'blackcoffin'; end
    if id=='uninvited' then return 'uninvited'; end
    if id=='requiem_sin' then return 'requiem'; end
    if id=='exp_ring' then return 'exp_ring'; end
    return nil;
end

local function capture_profile_for_dragon(id)
    -- HAAP tracking is fully automatic; do not fall through to the generic
    -- Dragon capture profile for these rows.
    if id=='dc_haap' or id=='mm_haap' then return nil; end
    if id=='mm_cookbook' then return nil; end
    return 'dragon';
end

local function draw_capture(profile,id)
    local c=HC.modules.state.get_char();
    if not developer_mode(c) then return; end
    if profile and HC.modules.learning and HC.modules.learning.capture_button then
        HC.imgui.SameLine();
        HC.modules.learning.capture_button(profile,id);
    end
end

local function draw_dynamis_account_counter(c,limits)
    local imgui=HC.imgui;
    limits=limits or M.dynamis_limits(c);
    local account_n=limits.account_used;
    local char_n=limits.character_used;
    local char_cap=limits.character_cap;
    local char_remaining=limits.character_remaining;

    -- Completion is based on the entries this character can still consume
    -- from the current account-wide pool, not always a hard-coded 2/2.
    local auto_done={limits.complete==true};
    imgui.Checkbox('##weekly_auto_done_dynamis',auto_done);
    if imgui.IsItemHovered~=nil and imgui.IsItemHovered() then
        imgui.SetTooltip('Automatically checked when this character has no Dynamis entries remaining. The character quota is reduced when other characters use the shared 3-entry account pool.');
    end
    imgui.SameLine();
    if char_cap>0 then
        imgui.Text(string.format('Dynamis: Character %d/%d used | %d remaining | Account %d/3 used',char_n,char_cap,char_remaining,account_n));
    else
        imgui.Text(string.format('Dynamis: Character %d used | 0 remaining | Account %d/3 used',char_n,account_n));
    end
    imgui.SameLine();
    if HC.modules.automation then imgui.TextDisabled('[AUTO '..HC.modules.automation.system_status(c,'dynamis')..']'); end

    if developer_mode(c) and HC.modules.learning and HC.modules.learning.capture_button then
        imgui.SameLine();
        HC.modules.learning.capture_button('dynamis','weekly_run_dynamis');
    end

    draw_note(imgui,'3 lockouts shared account-wide; max 2 per character. Same 3.5-hour run re-entry does not count again.','- ');
end

local function avatar_key_item_rows(force)
    local now=os.time();
    if not force and avatar_ki_cache.rows and (now-(tonumber(avatar_ki_cache.at) or 0))<AVATAR_KI_CACHE_SECONDS then
        return avatar_ki_cache.rows;
    end
    local out={};
    local keyitems=HC and HC.modules and HC.modules.keyitems or nil;
    for _,it in ipairs(daily_avatars) do
        local owned,err,id,source=nil,'key-item tracker unavailable',nil,'unavailable';
        if keyitems and type(keyitems.ownership_name)=='function' then
            local ok,a,b,c,d=pcall(keyitems.ownership_name,it.key_item);
            if ok then owned,err,id,source=a,b,c,d else err=tostring(a); end
        end
        out[#out+1]={
            avatar=it.avatar,npc=it.npc,location=it.location,key_item=it.key_item,
            owned=owned,id=id,source=source,error=err,
        };
    end
    avatar_ki_cache={at=now,rows=out};
    return out;
end

local function reconcile_avatar_daily_completion(c,rows)
    c=type(c)=='table' and c or {};
    c.daily=type(c.daily)=='table' and c.daily or {};
    c.daily.avatar_fights=type(c.daily.avatar_fights)=='table' and c.daily.avatar_fights or {};
    c.daily.avatar_seen_held=type(c.daily.avatar_seen_held)=='table' and c.daily.avatar_seen_held or {};
    c.daily.avatar_missing_since=type(c.daily.avatar_missing_since)=='table' and c.daily.avatar_missing_since or {};
    local changed=false;
    local now=os.time();

    for _,r in ipairs(rows or {}) do
        local key=tostring(r.avatar or '');

        if r.owned==true then
            -- A currently held entry key item is authoritative: the fight has
            -- not been completed for this daily window. This also repairs old
            -- false completions caused by a brief key-item read gap.
            if c.daily.avatar_seen_held[key]~=true then
                c.daily.avatar_seen_held[key]=true;
                changed=true;
            end
            if c.daily.avatar_missing_since[key]~=nil then
                c.daily.avatar_missing_since[key]=nil;
                changed=true;
            end
            if c.daily.avatar_fights[key]==true then
                c.daily.avatar_fights[key]=nil;
                changed=true;
            end

        elseif r.owned==false and c.daily.avatar_seen_held[key]==true and c.daily.avatar_fights[key]~=true then
            -- Do not complete from a single NOT HELD sample. Key-item tables
            -- can briefly report false during zoning/login, so require a few
            -- seconds of continuous absence after the KI was previously HELD.
            local missing_at=tonumber(c.daily.avatar_missing_since[key]);
            if missing_at==nil then
                c.daily.avatar_missing_since[key]=now;
                changed=true;
            elseif now-missing_at>=3 then
                c.daily.avatar_fights[key]=true;
                c.daily.avatar_missing_since[key]=nil;
                changed=true;
            end

        elseif r.owned==nil and c.daily.avatar_missing_since[key]~=nil then
            -- An unknown/checking sample breaks the continuous absence proof.
            c.daily.avatar_missing_since[key]=nil;
            changed=true;
        end
    end

    if changed and HC.modules.state and HC.modules.state.save then HC.modules.state.save(); end
    return c.daily.avatar_fights;
end

function M.daily_avatar_summary(c)
    c=type(c)=='table' and c or {};
    local rows=avatar_key_item_rows(false);
    local completed=reconcile_avatar_daily_completion(c,rows);
    local held,checking,completed_n=0,0,0;
    for _,r in ipairs(rows) do
        if r.owned==true then held=held+1 elseif r.owned==nil then checking=checking+1; end
        if completed[tostring(r.avatar)]==true then completed_n=completed_n+1; end
    end
    return { held=held,total=#rows,completed=completed_n,checking=checking };
end

function M.draw_daily_avatars(c,embedded)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    c.settings=type(c.settings)=='table' and c.settings or {};
    local rows=avatar_key_item_rows(false);
    local completed=reconcile_avatar_daily_completion(c,rows);
    local held,checking=0,0;
    for _,r in ipairs(rows) do
        if r.owned==true then held=held+1 elseif r.owned==nil then checking=checking+1; end
    end

    local completed_n=0; for _,r in ipairs(rows) do if completed[tostring(r.avatar)]==true then completed_n=completed_n+1; end end
    if embedded~=true then
        imgui.Text('Daily Avatar Fights');
        imgui.SameLine();
        imgui.TextDisabled(string.format('%d/%d key items held | %d/%d completed today | repeatable after Japanese midnight',held,#rows,completed_n,#rows));
        if developer_mode(c) and HC.modules.learning and HC.modules.learning.capture_button then
            imgui.SameLine();
            HC.modules.learning.capture_button('daily_avatar','daily_avatar_fights',0);
        end
    elseif developer_mode(c) and HC.modules.learning and HC.modules.learning.capture_button then
        HC.modules.learning.capture_button('daily_avatar','daily_avatar_fights',0);
    end
    local hide_completed={c.settings.hide_completed_daily_avatars==true};
    if imgui.Checkbox('Hide completed objectives##daily_avatar_hide_completed',hide_completed) then
        c.settings.hide_completed_daily_avatars=hide_completed[1];
        HC.modules.state.save();
    end
    imgui.Separator();

    local table_supported=(imgui.BeginTable~=nil and imgui.TableSetupColumn~=nil
        and imgui.TableHeadersRow~=nil and imgui.TableNextRow~=nil
        and imgui.TableSetColumnIndex~=nil and imgui.EndTable~=nil);
    local table_flags=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
    if table_supported and imgui.BeginTable('##daily_avatar_table_v7226',4,table_flags) then
        imgui.TableSetupColumn('Avatar',0,110);
        imgui.TableSetupColumn('NPC / Location',0,330);
        imgui.TableSetupColumn('Key Item',0,270);
        imgui.TableSetupColumn('Status',0,130);
        imgui.TableHeadersRow();
        for _,r in ipairs(rows) do
            local is_complete=completed[tostring(r.avatar)]==true;
            if not (c.settings.hide_completed_daily_avatars==true and is_complete) then
                imgui.TableNextRow();
                imgui.TableSetColumnIndex(0);
                if r.owned==true or is_complete then imgui.Text(tostring(r.avatar)) else imgui.TextDisabled(tostring(r.avatar)) end

                imgui.TableSetColumnIndex(1);
                local who=string.format('%s - %s',tostring(r.npc),tostring(r.location));
                if r.owned==true or is_complete then imgui.Text(who) else imgui.TextDisabled(who) end

                imgui.TableSetColumnIndex(2);
                if r.owned==true or is_complete then imgui.Text(tostring(r.key_item)) else imgui.TextDisabled(tostring(r.key_item)) end

                imgui.TableSetColumnIndex(3);
                local state=is_complete and 'COMPLETE' or ((r.owned==true and 'HELD') or (r.owned==false and 'NOT HELD') or 'CHECKING');
                if r.owned==true or is_complete then imgui.Text(state) else imgui.TextDisabled(state) end
            end
        end
        imgui.EndTable();
    else
        for _,r in ipairs(rows) do
            local is_complete=completed[tostring(r.avatar)]==true;
            if not (c.settings.hide_completed_daily_avatars==true and is_complete) then
                local state=is_complete and '[COMPLETE]' or ((r.owned==true and '[HELD]') or (r.owned==false and '[NOT HELD]') or '[CHECKING]');
                local line=string.format('%-9s - %s - %s - KI: %s  %s',
                    tostring(r.avatar),tostring(r.npc),tostring(r.location),tostring(r.key_item),state);
                if r.owned==true or is_complete then imgui.Text(line) else imgui.TextDisabled(line) end
            end
        end
    end
    if checking>0 then
        imgui.TextDisabled(string.format('%d key item status(es) are still checking.',checking));
    end
    imgui.TextDisabled('A fight is marked COMPLETE only after its key item was HELD and then stays NOT HELD after the fight. If the key item is still held, the fight stays incomplete.');
    imgui.TextDisabled('The six elemental trials, Fenrir, and Diabolos are repeatable after Japanese midnight once their previous reward has been claimed.');
end

function M.avatar_daily_status(force)
    return avatar_key_item_rows(force==true);
end

function M.draw_lockout_repairs(c)
    local imgui=HC.imgui; if imgui==nil then return; end
    c.weekly=type(c.weekly)=='table' and c.weekly or {};

    imgui.Text('Dynamis Lockouts');
    local aw=HC.modules.state.get_account_weekly and HC.modules.state.get_account_weekly() or {};
    local limits=M.dynamis_limits(c);
    local account_n=limits.account_used;
    local char_n=limits.character_used;
    imgui.TextDisabled(string.format('Character %d/%d | Account %d/3',char_n,limits.character_cap,account_n));
    if imgui.SmallButton('+ Run##diag_dynamis_add') and account_n<3 and char_n<2 then
        aw.dynamis_count=account_n+1;
        c.weekly.dynamis_character_count=char_n+1;
        HC.modules.state.save();
    end
    imgui.SameLine();
    if imgui.SmallButton('Undo##diag_dynamis_undo') and account_n>0 and char_n>0 then
        aw.dynamis_count=account_n-1;
        c.weekly.dynamis_character_count=char_n-1;
        HC.modules.state.save();
    end

    imgui.Spacing();
    imgui.Text('Limbus Lockouts');
    local limbus_n=pair_count(c.weekly,'limbus_1','limbus_2');
    imgui.TextDisabled(string.format('Character %d/2',limbus_n));
    if imgui.SmallButton('+ Run##diag_limbus_add') and limbus_n<2 then
        if c.weekly.limbus_1~=true then c.weekly.limbus_1=true else c.weekly.limbus_2=true end
        HC.modules.state.save();
    end
    imgui.SameLine();
    if imgui.SmallButton('Undo##diag_limbus_undo') and limbus_n>0 then
        if c.weekly.limbus_2==true then c.weekly.limbus_2=nil else c.weekly.limbus_1=nil end
        HC.modules.state.save();
    end
end


local function daily_table_supported(imgui)
    return imgui.BeginTable~=nil and imgui.TableSetupColumn~=nil
        and imgui.TableHeadersRow~=nil and imgui.TableNextRow~=nil
        and imgui.TableSetColumnIndex~=nil and imgui.EndTable~=nil;
end

local function draw_daily_objectives_table(c)
    local imgui=HC.imgui;
    local flags=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
    if not daily_table_supported(imgui) then return false; end
    if not imgui.BeginTable('##daily_objectives_table_v7226',3,flags) then return true; end
    imgui.TableSetupColumn('Objective',0,220);
    imgui.TableSetupColumn('Status',0,430);
    imgui.TableSetupColumn('Notes',0,520);
    imgui.TableHeadersRow();

    for _,it in ipairs(daily) do
        local completed=(c.daily[it.id]==true);
        if not (c.settings.hide_completed_daily==true and completed) then
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);

            if it.id=='digging' and HC.modules.digging then
                local box={completed};
                imgui.Checkbox('##daily_table_'..it.id,box); imgui.SameLine(); imgui.Text(it.name);
            elseif it.id=='plant_pots' then
                c.plant_pots=type(c.plant_pots)=='table' and c.plant_pots or {};
                c.plant_pots_daily=type(c.plant_pots_daily)=='table' and c.plant_pots_daily or {};
                local target=math.max(0,math.min(10,math.floor(tonumber(c.plant_pots.target) or 0)));
                local checked=math.max(0,math.min(10,math.floor(tonumber(c.plant_pots_daily.checked) or 0)));
                if target>0 then c.daily.plant_pots=(checked>=target) and true or nil; completed=(c.daily.plant_pots==true); end
                local box={c.daily.plant_pots==true};
                if imgui.Checkbox('##daily_table_'..it.id,box) then c.daily.plant_pots=box[1]; HC.modules.state.save(); end
                imgui.SameLine(); imgui.Text(it.name);
            else
                local box={completed};
                if imgui.Checkbox('##daily_table_'..it.id,box) then c.daily[it.id]=box[1]; HC.modules.state.save(); completed=box[1]; end
                imgui.SameLine(); imgui.Text(it.name);
            end

            imgui.TableSetColumnIndex(1);
            local status=completed and 'COMPLETE' or 'READY';
            if it.id=='guild_points' and HC.modules.guild then status=HC.modules.guild.status(c);
            elseif it.id=='isnm' and HC.modules.isnm then status=HC.modules.isnm.status(c);
            elseif it.id=='digging' and HC.modules.digging and HC.modules.digging.status then status=HC.modules.digging.status(c);
            elseif it.id=='plant_pots' and HC.modules.plantpots and HC.modules.plantpots.status then status=HC.modules.plantpots.status(c);
            end
            if completed then imgui.Text(tostring(status)) else imgui.TextDisabled(tostring(status)) end
            if it.id=='guild_points' and HC.modules.guild and HC.modules.guild.draw_recipe_link then
                local requested=HC.modules.guild.requested_item and HC.modules.guild.requested_item(c) or nil;
                if requested then
                    imgui.SameLine();
                    HC.modules.guild.draw_recipe_link(c,'daily_weekly_gp_recipe');
                end
            end
            if it.id=='plant_pots' and imgui.SmallButton('Relearn Pots##daily_table_relearn_pots') and HC.modules.plantpots then HC.modules.plantpots.relearn(); end
            if it.id~='plant_pots' then draw_capture(capture_profile_for_daily(it.id),'daily_'..it.id); else draw_capture('pots','daily_plant_pots'); end

            imgui.TableSetColumnIndex(2);
            local note=it.note or '';
            if it.id=='plant_pots' then
                local target=math.max(0,math.min(10,math.floor(tonumber(c.plant_pots and c.plant_pots.target) or 0)));
                note=(target>0) and "Counts only when you examine a pot. Feeding is tracked separately and makes that pot need another examine." or "First learn how many pots you have by checking each planted pot once. Feeding is tracked separately and does not count as an examine.";
            end
            imgui.TextDisabled(note~='' and tostring(note) or '-');
        end
    end
    imgui.EndTable();
    return true;
end

local function requiem_sin_status(c,completed)
    if completed==true then return 'COMPLETE | Conquest-cycle run used'; end
    local held,name,known_absent=refresh_requiem_key_item(c);
    if held==true then return 'READY | '..tostring(name or 'Requiem key item')..' HELD | Head to Boneyard Gully'; end
    if c.weekly and c.weekly.requiem_ki_seen==true and (c.weekly.requiem_ki_consumed==true or known_absent==true) then
        return 'Key item used | waiting for the battle result';
    end
    return "CHECK DESPACHAIRE | Tavnazian Safehold (K-10) | X's Knife reward chance";
end

local function weekly_row_status(c,it,completed)
    if it.id=='requiem_sin' then return requiem_sin_status(c,completed); end
    if it.id=='black_coffin' and HC.modules.blackcoffin then return HC.modules.blackcoffin.status(c); end
    if it.id=='haap' and HC.modules.haap then return HC.modules.haap.status(c); end
    if it.id=='conquest' and HC.modules.outposts then return HC.modules.outposts.short_status(c); end
    if it.id=='uninvited' and HC.modules.automation and HC.modules.automation.uninvited_status then return HC.modules.automation.uninvited_status(c); end
    if it.id=='highwind' and HC.modules.automation and HC.modules.automation.highwind_status then
        if c.weekly.highwind==true then return 'Reward confirmed: 3000 EXP + 3000 gil'; end
        return 'Tracks this for you';
    end
    if it.id=='chocobo_game' and HC.modules.chocobo then return HC.modules.chocobo.status(c); end
    return completed and 'COMPLETE' or 'READY';
end

local function weekly_open_target(id)
    local map={
        eco_warrior={'eco'},
        requiem_sin={'quests',{log_id=4,quest_id=83,name='Requiem of Sin'}},
        black_coffin={'blackcoffin'},
        chocobo_game={'chocobo'},
        conquest={'dailyweekly',{section='weekly',objective='conquest'}},
        exp_ring={'dailyweekly',{section='weekly',objective='exp_ring'}},
    };
    local v=map[tostring(id or '')];
    if not v then return nil,nil; end
    return v[1],v[2];
end

local function draw_weekly_open(imgui,id)
    local tab,focus=weekly_open_target(id);
    if not tab or not (HC.modules.ui and HC.modules.ui.navigate) then
        imgui.TextDisabled('-');
        return;
    end
    if imgui.SmallButton('Go##weekly_open_'..tostring(id)) then HC.modules.ui.navigate(tab,focus); end
end

local function weekly_note_tooltip(imgui,it)
    if not (imgui.IsItemHovered and imgui.SetTooltip) then return; end
    local ok,hovered=pcall(imgui.IsItemHovered);
    if not ok or hovered~=true then return; end
    local note=tostring((it and it.note) or '');
    if it and it.id=='conquest' then
        note=note.." Update from Conrad (Bastok), Jeanvirgaud (San d'Oria), or Rottata (Windurst) via Regional Teleport.";
    end
    if note~='' then imgui.SetTooltip(note); end
end

local function dragon_row_status(c,it,completed)
    if (it.id=='dc_haap' or it.id=='mm_haap') and HC.modules.haap then
        return HC.modules.haap.row_status(c,it.id);
    end
    if it.id=='mm_cookbook' and HC.modules.ovens then
        return HC.modules.ovens.row_status(c);
    end
    if it.id=='mm_rivenwort' and HC.modules.spice then
        return HC.modules.spice.row_status(c);
    end
    if it.id=='dc_eco' and HC.modules.eco and HC.modules.eco.sandoria_status then
        return HC.modules.eco.sandoria_status(c);
    end
    return completed and 'COMPLETE' or 'READY';
end

local function draw_dragon_objectives_table(c)
    local imgui=HC.imgui;
    local flags=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
    if not daily_table_supported(imgui) then return false; end
    if not imgui.BeginTable('##dragon_exp_sources_table_v771',3,flags) then return true; end
    imgui.TableSetupColumn('Objective',0,310);
    imgui.TableSetupColumn('Status',0,430);
    imgui.TableSetupColumn('Notes',0,560);
    imgui.TableHeadersRow();

    for _,it in ipairs(dragon) do
        local completed=(c.dragon_weekly[it.id]==true);
        if not (c.settings.hide_completed_dragon==true and completed) then
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);
            local box={completed};
            if imgui.Checkbox('##dragon_table_'..it.id,box) then
                c.dragon_weekly[it.id]=box[1];
                completed=box[1];
                HC.modules.state.save();
            end
            imgui.SameLine();
            imgui.Text(tostring(it.name or ''));

            imgui.TableSetColumnIndex(1);
            local status=dragon_row_status(c,it,completed);
            if completed then imgui.Text(tostring(status)) else imgui.TextDisabled(tostring(status)) end
            draw_capture(capture_profile_for_dragon(it.id),'dragon_'..it.id);

            imgui.TableSetColumnIndex(2);
            local note=tostring(it.note or '');
            if note~='' then imgui.TextDisabled(note); else imgui.TextDisabled('-'); end
        end
    end

    imgui.EndTable();
    return true;
end

local function draw_weekly_objectives_table(c)
    local imgui=HC.imgui;
    local flags=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
    if not daily_table_supported(imgui) then return false; end
    if not imgui.BeginTable('##weekly_objectives_table_v764',3,flags) then return true; end
    imgui.TableSetupColumn('Objective',0,260);
    imgui.TableSetupColumn('Status',0,720);
    imgui.TableSetupColumn('Open',0,90);
    imgui.TableHeadersRow();

    for _,it in ipairs(weekly) do
        local completed=(c.weekly[it.id]==true);
        if it.id=='black_coffin' and HC.modules.blackcoffin then
            local s=HC.modules.blackcoffin.status(c);
            if type(s)=='string' and s:find('FAILED / LOCKED OUT',1,true) then completed=true; c.weekly.black_coffin=true; end
        end
        if not (c.settings.hide_completed_conquest==true and completed) then
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);
            local box={completed};
            if it.id=='conquest' and HC.modules.outposts then
                HC.modules.outposts.reconcile(c);
                local permanent=HC.modules.outposts.permanent_complete and HC.modules.outposts.permanent_complete(c);
                box[1]=(permanent==true) or c.weekly.conquest==true;
                imgui.Checkbox('##weekly_table_'..it.id,box);
                if permanent then c.weekly.conquest=true; end
            else
                if imgui.Checkbox('##weekly_table_'..it.id,box) then
                    c.weekly[it.id]=box[1]; completed=box[1];
                    if it.id=='haap' and HC.modules.haap and HC.modules.haap.reconcile then HC.modules.haap.reconcile(c,false); end
                    HC.modules.state.save();
                end
            end
            imgui.SameLine(); imgui.Text(it.name);
            weekly_note_tooltip(imgui,it);

            imgui.TableSetColumnIndex(1);
            local status=weekly_row_status(c,it,completed);
            if completed then imgui.Text(tostring(status)) else imgui.TextDisabled(tostring(status)) end
            if it.id~='highwind' then draw_capture(capture_profile_for_weekly(it.id),'weekly_'..it.id); end

            imgui.TableSetColumnIndex(2);
            draw_weekly_open(imgui,it.id);
        end
    end

    local limits=M.dynamis_limits(c);
    if not (c.settings.hide_completed_conquest==true and limits.complete==true) then
        imgui.TableNextRow();
        imgui.TableSetColumnIndex(0);
        local box={limits.complete==true}; imgui.Checkbox('##weekly_table_dynamis',box); imgui.SameLine(); imgui.Text('Dynamis'); weekly_note_tooltip(imgui,{note='3 lockouts shared account-wide; max 2 per character. Same 3.5-hour run re-entry does not count again.'});
        imgui.TableSetColumnIndex(1);
        local ds=limits.character_cap>0 and string.format('Character %d/%d used | %d remaining | Account %d/3 used',limits.character_used,limits.character_cap,limits.character_remaining,limits.account_used)
            or string.format('Character %d used | 0 remaining | Account %d/3 used',limits.character_used,limits.account_used);
        imgui.TextDisabled(ds);
        if HC.modules.automation then imgui.SameLine(); imgui.TextDisabled('[AUTO '..HC.modules.automation.system_status(c,'dynamis')..']'); end
        if developer_mode(c) and HC.modules.learning and HC.modules.learning.capture_button then imgui.SameLine(); HC.modules.learning.capture_button('dynamis','weekly_run_dynamis'); end
        imgui.TableSetColumnIndex(2);
        if HC.modules.ui and HC.modules.ui.navigate and imgui.SmallButton('Go##weekly_open_dynamis') then HC.modules.ui.navigate('dynamis'); end
    end

    local limbus_n=pair_count(c.weekly,'limbus_1','limbus_2');
    imgui.TableNextRow();
    imgui.TableSetColumnIndex(0);
    local lbox={limbus_n>=2}; imgui.Checkbox('##weekly_table_limbus',lbox); imgui.SameLine(); imgui.Text('Limbus'); weekly_note_tooltip(imgui,{note='HorizonXI: 2 lockouts per Conquest tally.'});
    imgui.TableSetColumnIndex(1);
    imgui.TextDisabled(string.format('%d/2 used | %d remaining',limbus_n,2-limbus_n));
    if HC.modules.automation then imgui.SameLine(); imgui.TextDisabled('[AUTO '..HC.modules.automation.system_status(c,'limbus')..']'); end
    if HC.modules.keyitems and HC.modules.keyitems.cosmo_cleanse_status then
        local ks=HC.modules.keyitems.cosmo_cleanse_status();
        if ks and ks.owned==true then imgui.SameLine(); imgui.TextDisabled('[Cosmo-Cleanse held]'); end
    end
    if developer_mode(c) and HC.modules.learning and HC.modules.learning.capture_button then imgui.SameLine(); HC.modules.learning.capture_button('limbus','weekly_run_limbus'); end
    imgui.TableSetColumnIndex(2); imgui.TextDisabled('-');

    imgui.EndTable();
    return true;
end

function M.draw(c, section)
    local imgui=HC.imgui; if imgui==nil then return; end
    section=string.lower(tostring(section or 'all'));
    if HC.modules.haap and HC.modules.haap.reconcile then HC.modules.haap.reconcile(c,false); end
    c.settings=type(c.settings)=='table' and c.settings or {};

    local hide_key=nil;
    if section=='daily' then
        hide_key='hide_completed_daily';
    elseif section=='weekly' then
        hide_key='hide_completed_conquest';
    elseif section=='dragon' then
        hide_key='hide_completed_dragon';
    end

    if section~='all' and hide_key then
        local hide_completed={c.settings[hide_key]==true};
        if imgui.Checkbox('Hide completed objectives##weekly_hide_completed_'..section,hide_completed) then
            c.settings[hide_key]=hide_completed[1];
            HC.modules.state.save();
        end
        imgui.Separator();
    end

    local p=M.progress(c);

    -- The dedicated Daily / Weekly tab uses the same clean table-first layout
    -- as Eco-War: fixed columns, compact status cells, and a separate Notes
    -- column. Keep the legacy rendering below as the compatibility fallback.
    if section=='daily' and draw_daily_objectives_table(c) then return; end
    if section=='weekly' and draw_weekly_objectives_table(c) then return; end
    if section=='dragon' and draw_dragon_objectives_table(c) then return; end

    if section=='all' or section=='daily' then
        local daily_label=(HC.modules.uikit and HC.modules.uikit.progress_label) and HC.modules.uikit.progress_label('Daily / Regular',p.daily_done,p.daily_total) or string.format('Daily / Regular - %d/%d',p.daily_done,p.daily_total); local open=(section~='all') or imgui.CollapsingHeader(daily_label..'##v55daily', ImGuiTreeNodeFlags_DefaultOpen or 0);
        if open then
        for _,it in ipairs(daily) do
            local completed=(c.daily[it.id]==true);
            if not (c.settings.hide_completed_daily==true and completed) then
            if it.id=='digging' and HC.modules.digging then
                HC.modules.digging.draw_row(c);
            elseif it.id=='plant_pots' then
                c.plant_pots=type(c.plant_pots)=='table' and c.plant_pots or {};
                c.plant_pots_daily=type(c.plant_pots_daily)=='table' and c.plant_pots_daily or {};
                local target=math.max(0,math.min(10,math.floor(tonumber(c.plant_pots.target) or 0)));
                local checked=math.max(0,math.min(10,math.floor(tonumber(c.plant_pots_daily.checked) or 0)));
                if target>0 then c.daily.plant_pots=(checked>=target) and true or nil; end
                local label=(target>0) and string.format('Check Plant Pots - %d/%d##v55dailyplant_pots',checked,target)
                    or string.format('Check Plant Pots - %d/?##v55dailyplant_pots',checked);
                local box={c.daily.plant_pots==true};
                if imgui.Checkbox(label,box) then
                    c.daily.plant_pots=box[1];
                    HC.modules.state.save();
                end
                imgui.SameLine();
                if imgui.SmallButton('Relearn Pots##plant_pots_relearn') and HC.modules.plantpots then
                    HC.modules.plantpots.relearn();
                end
                draw_capture('pots','daily_plant_pots');
                imgui.SameLine();
                local fed=math.max(0,math.floor(tonumber(c.plant_pots_daily.feed_count) or 0));
                if target>0 then imgui.TextDisabled(string.format('- examine-only credit; feed then examine again | %d crystal%s fed.',fed,fed==1 and '' or 's'))
                else imgui.TextDisabled(string.format('- learning total; %d crystal%s fed automatically.',fed,fed==1 and '' or 's')) end
            else
                local box={c.daily[it.id]==true};
                if imgui.Checkbox(it.name..'##v55daily'..it.id,box) then c.daily[it.id]=box[1]; HC.modules.state.save(); end
                if it.id=='guild_points' and HC.modules.guild then imgui.SameLine(); imgui.TextDisabled('- '..HC.modules.guild.status(c)); end
                if it.id=='isnm' and HC.modules.isnm then imgui.SameLine(); imgui.TextDisabled('['..HC.modules.isnm.status(c)..']'); end
                if it.id=='assault_tags' then imgui.SameLine(); imgui.TextDisabled('- '..HC.modules.assault.status(c)); end
                if it.id=='assault' and c.assault_activity and c.assault_activity.state then
                    imgui.SameLine();
                    imgui.TextDisabled('[CURRENT: '..tostring(c.assault_activity.state)..
                        (c.assault_activity.mission and (' - '..tostring(c.assault_activity.mission)) or '')..']');
                end
                local detail=nil;
                if it.id=='guild_points' and HC.modules.guild then detail=HC.modules.guild.status(c);
                elseif it.id=='isnm' and HC.modules.isnm then detail=HC.modules.isnm.status(c);
                elseif it.id=='assault_tags' and HC.modules.assault then detail=HC.modules.assault.status(c);
                elseif it.id=='assault' and c.assault_activity then detail=tostring(c.assault_activity.state or 'idle'); end
                if it.id~='plant_pots' then draw_capture(capture_profile_for_daily(it.id),'daily_'..it.id); end
                if it.id~='plant_pots' and it.note and it.note~='' then draw_note(imgui,it.note,'- '); end
            end
            end
        end
        end
    end

    if section=='all' or section=='weekly' then
        local weekly_label=(HC.modules.uikit and HC.modules.uikit.progress_label) and HC.modules.uikit.progress_label('Weekly / Conquest Tally',p.weekly_done,p.weekly_total) or string.format('Weekly / Conquest Tally - %d/%d',p.weekly_done,p.weekly_total); local open=(section~='all') or imgui.CollapsingHeader(weekly_label..'##v55weekly', ImGuiTreeNodeFlags_DefaultOpen or 0);
        if open then
        for _,it in ipairs(weekly) do
            local completed=(c.weekly[it.id]==true);
            -- Black Coffin failure consumes the account-wide weekly
            -- opportunity. Treat FAILED / LOCKED OUT as complete for the
            -- weekly checkbox even though the 3-step chain was not cleared.
            if it.id=='black_coffin' and HC.modules.blackcoffin then
                local bc_status=HC.modules.blackcoffin.status(c);
                if type(bc_status)=='string' and bc_status:find('FAILED / LOCKED OUT',1,true) then
                    completed=true;
                    c.weekly.black_coffin=true;
                end
            end
            if not (c.settings.hide_completed_conquest==true and completed) then
            local box={completed};
            if it.id=='conquest' and HC.modules.outposts then
                HC.modules.outposts.reconcile(c);
                local permanent=HC.modules.outposts.permanent_complete and HC.modules.outposts.permanent_complete(c);
                box[1]=(permanent==true) or c.weekly.conquest==true;
                imgui.Checkbox(it.name..'##v55weekly'..it.id,box);
                if permanent then
                    -- Ignore attempts to uncheck permanent 17/17 progression.
                    c.weekly.conquest=true;
                end
            else
                if imgui.Checkbox(it.name..'##v55weekly'..it.id,box) then
                    c.weekly[it.id]=box[1];
                    if it.id=='haap' and HC.modules.haap and HC.modules.haap.reconcile then
                        HC.modules.haap.reconcile(c,false);
                    end
                    HC.modules.state.save();
                end
            end
            if it.id=='black_coffin' and HC.modules.blackcoffin then
                imgui.SameLine();
                imgui.TextDisabled('['..HC.modules.blackcoffin.status(c)..']');
            end
            if it.id=='haap' and HC.modules.haap then imgui.SameLine(); imgui.TextDisabled('['..HC.modules.haap.status(c)..']'); end
            if it.id=='conquest' and HC.modules.outposts then
                imgui.SameLine();
                imgui.TextDisabled('['..HC.modules.outposts.short_status(c)..']');
                imgui.SameLine();
                imgui.TextDisabled('- Update: talk to Conrad (Bastok), Jeanvirgaud (San d\'Oria), or Rottata (Windurst) and page through the Regional Teleport menu.');
            end
            if it.id=='uninvited' and HC.modules.automation and HC.modules.automation.uninvited_status then
                imgui.SameLine();
                imgui.TextDisabled('['..HC.modules.automation.uninvited_status(c)..']');
            end
            if it.id=='highwind' and HC.modules.automation and HC.modules.automation.highwind_status then
                imgui.SameLine();
                if c.weekly.highwind==true then
                    imgui.TextDisabled('[Reward confirmed: 3000 EXP + 3000 gil]');
                else
                    imgui.TextDisabled('[Tracks this for you]');
                end
            end
            if it.id=='chocobo_game' and HC.modules.chocobo then
                imgui.SameLine();
                imgui.TextDisabled('['..HC.modules.chocobo.status(c)..']');
            end
            local detail=nil;
            if it.id=='black_coffin' and HC.modules.blackcoffin then detail=HC.modules.blackcoffin.status(c);
            elseif it.id=='haap' and HC.modules.haap then detail=HC.modules.haap.status(c);
            elseif it.id=='uninvited' and HC.modules.automation and HC.modules.automation.uninvited_status then detail=HC.modules.automation.uninvited_status(c);
            elseif it.id=='highwind' and HC.modules.automation and HC.modules.automation.highwind_status then detail=HC.modules.automation.highwind_status(c);
            elseif it.id=='chocobo_game' and HC.modules.chocobo then detail=HC.modules.chocobo.status(c);
            elseif it.id=='conquest' and HC.modules.outposts then detail=HC.modules.outposts.short_status(c); end
            if it.id~='highwind' then
                draw_capture(capture_profile_for_weekly(it.id),'weekly_'..it.id);
            end
            if it.note and it.note~='' then draw_note(imgui,it.note,'- '); end
            end
        end
        local dynamis_limits=M.dynamis_limits(c);
        if not (c.settings.hide_completed_conquest==true and dynamis_limits.complete==true) then
            draw_dynamis_account_counter(c,dynamis_limits);
        end
        draw_run_counter(c,'Limbus','limbus_1','limbus_2','HorizonXI: 2 lockouts per Conquest tally.','limbus');

        end
    end

    if section=='all' or section=='dragon' then
        local open=(section~='all') or imgui.CollapsingHeader(string.format('Weekly EXP Scrolls - %d/%d | resets with Conquest tally##v55dragon',p.dragon_done,p.dragon_total), ImGuiTreeNodeFlags_DefaultOpen or 0);
        if open then
        for _,it in ipairs(dragon) do
            local completed=(c.dragon_weekly[it.id]==true);
            if not (c.settings.hide_completed_dragon==true and completed) then
            local box={completed};
            if imgui.Checkbox(it.name..'##v55dragon'..it.id,box) then c.dragon_weekly[it.id]=box[1]; HC.modules.state.save(); end
            if (it.id=='dc_haap' or it.id=='mm_haap') and HC.modules.haap then
                imgui.SameLine();
                imgui.TextDisabled('['..HC.modules.haap.row_status(c,it.id)..']');
            elseif it.id=='mm_cookbook' and HC.modules.ovens then
                imgui.SameLine();
                imgui.TextDisabled('['..HC.modules.ovens.row_status(c)..']');
            elseif it.id=='mm_rivenwort' and HC.modules.spice then
                imgui.SameLine();
                imgui.TextDisabled('['..HC.modules.spice.row_status(c)..']');
            elseif it.id=='dc_eco' and HC.modules.eco and HC.modules.eco.sandoria_status then
                imgui.SameLine();
                imgui.TextDisabled('['..HC.modules.eco.sandoria_status(c)..']');
            end
            draw_capture(capture_profile_for_dragon(it.id),'dragon_'..it.id);
            if it.note and it.note~='' then draw_note(imgui,it.note,'- '); end
            end
        end
        end
    end
end

return M;
