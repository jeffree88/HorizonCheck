local M = {};
local HC;

local function user_file(kind,name)
    if HC and HC.modules and HC.modules.userdata and HC.modules.userdata.path then
        local ok,res=pcall(HC.modules.userdata.path,kind,name);
        if ok and type(res)=='string' and res~='' then return res; end
    end
    return tostring(HC and HC.addon_path or '')..tostring(name or '');
end

local active=nil;
local last_result=nil;

local function lower(v) return string.lower(tostring(v or '')); end
local function sanitize(v)
    local s=tostring(v or 'Unknown'):gsub('[^%w%._%-]','_'); if s=='' then s='Unknown'; end; return s;
end
local function bool_text(v) if v==true then return 'YES' elseif v==false then return 'no' else return 'UNKNOWN' end end

local function char_name()
    return tostring(HC and HC.modules and HC.modules.core and HC.modules.core.character_name and HC.modules.core.character_name() or 'Unknown');
end

local function quest_state(log_id,quest_id)
    local q=HC and HC.modules and HC.modules.quests or nil;
    if q and q.raw_native_state then local ok,v=pcall(q.raw_native_state,log_id,quest_id); if ok then return v; end end
    return {log_id=log_id,quest_id=quest_id,active=nil,completed=nil,policy='UNKNOWN',reason='raw quest state unavailable'};
end

local function ki_snapshot()
    local k=HC and HC.modules and HC.modules.keyitems or nil;
    if k and k.permanent_snapshot then local ok,v=pcall(k.permanent_snapshot); if ok then return v; end end
    return nil;
end

local function owned_set(snap)
    local out={};
    for _,r in ipairs(type(snap)=='table' and snap.owned or {}) do if r.id then out[tonumber(r.id)]=tostring(r.name or '?'); end end
    return out;
end

local function diff_owned(a,b)
    local aa=owned_set(a); local bb=owned_set(b); local added={}; local removed={};
    for id,name in pairs(bb) do if not aa[id] then added[#added+1]={id=id,name=name}; end end
    for id,name in pairs(aa) do if not bb[id] then removed[#removed+1]={id=id,name=name}; end end
    table.sort(added,function(x,y) return x.id<y.id; end); table.sort(removed,function(x,y) return x.id<y.id; end);
    return added,removed;
end

local function ensure_history(c)
    c.guided_captures=type(c.guided_captures)=='table' and c.guided_captures or {};
    return c.guided_captures;
end

local function write_report(w,result,capture)
    local stamp=os.date('%Y%m%d_%H%M%S');
    local path=user_file('captures','horizoncheck_guided_'..sanitize(char_name())..'_'..stamp..'_quest_'..tostring(w.log_id)..'_'..tostring(w.quest_id)..'.txt');
    local f=io.open(path,'w'); if not f then return nil; end
    f:write('HorizonCheck v'..tostring(HC.version)..' Guided Capture Analysis\n');
    f:write('Character: '..char_name()..'\n');
    f:write('Quest: '..tostring(w.name)..'\n');
    f:write('Native ID: '..tostring(w.log_id)..':'..tostring(w.quest_id)..'\n');
    f:write('Capture mode: '..tostring(w.mode)..'\n');
    f:write('Started: '..os.date('%Y-%m-%d %H:%M:%S',w.started_at)..'\n');
    f:write('Ended: '..os.date('%Y-%m-%d %H:%M:%S',result.at)..'\n');
    f:write('Expected NPC: '..tostring(w.start_npc or 'not mapped')..'\n');
    f:write('Expected zone: '..tostring(w.start_zone or 'not mapped')..'\n');
    f:write('Canonical policy before capture: '..tostring(w.before.policy or '?')..' | '..tostring(w.before.reason or '')..'\n');
    f:write('\nNATIVE STATE BEFORE / AFTER\n');
    f:write('Active: '..bool_text(w.before.active)..' -> '..bool_text(result.after.active)..'\n');
    f:write('Completed: '..bool_text(w.before.completed)..' -> '..bool_text(result.after.completed)..'\n');
    f:write('Policy after: '..tostring(result.after.policy or '?')..' | '..tostring(result.after.reason or '')..'\n');
    f:write('\nCAPTURE SIGNALS\n');
    f:write('Packets: '..tostring(capture and capture.packet_total or 0)..'\n');
    f:write('0x056 packets: '..tostring(capture and capture.packet_counts and capture.packet_counts[0x056] or 0)..'\n');
    f:write('Text lines: '..tostring(capture and capture.text_total or 0)..'\n');
    f:write('Zone changes: '..tostring(capture and capture.zone_total or 0)..'\n');
    f:write('Underlying evidence report: '..tostring(result.learning_report or 'unavailable')..'\n');
    f:write('\nKEY ITEM DIFFERENCES\n');
    if #result.ki_added==0 and #result.ki_removed==0 then f:write('(none detected)\n'); end
    for _,r in ipairs(result.ki_added) do f:write(string.format('+ %d | %s\n',r.id,r.name)); end
    for _,r in ipairs(result.ki_removed) do f:write(string.format('- %d | %s\n',r.id,r.name)); end
    f:write('\nANALYSIS\n');
    f:write('Result: '..tostring(result.outcome)..'\n');
    f:write('Confidence: '..tostring(result.confidence)..'\n');
    f:write('Reason: '..tostring(result.reason)..'\n');
    f:write('Suggested action: '..tostring(result.suggested_action)..'\n');
    f:close(); return path;
end

local function analyze(w,capture,after,end_ki)
    local active_up=(w.before.active~=true and after.active==true);
    local complete_up=(w.before.completed~=true and after.completed==true);
    local p056=tonumber(capture and capture.packet_counts and capture.packet_counts[0x056]) or 0;
    local texts=tonumber(capture and capture.text_total) or 0;
    local added,removed=diff_owned(w.before_ki,end_ki);
    local outcome='INCONCLUSIVE'; local confidence='LOW'; local reason='No authoritative native transition was observed.';
    local suggested='Repeat the guided capture while performing only the requested quest interaction.';
    if complete_up then
        outcome='COMPLETION ID CONFIRMED'; confidence='HIGH';
        reason='The selected native completed bit changed from not-set to set during the guided capture.';
        suggested='Review the report and promote this native mapping to VERIFIED after confirming the dialogue/quest context.';
    elseif active_up then
        outcome='ACTIVE ID CONFIRMED'; confidence='HIGH';
        reason='The selected native active bit changed from not-set to set during the guided capture.';
        suggested='Review the report and promote this native mapping to VERIFIED after confirming the dialogue/quest context.';
    elseif p056>0 and texts>0 then
        outcome='USEFUL EVIDENCE'; confidence='MEDIUM';
        reason='Native quest packets and dialogue were captured, but the selected bit did not transition.';
        suggested='Compare the full evidence report for a different candidate ID or repeat from a clean before-state.';
    elseif p056>0 then
        outcome='NATIVE PACKETS ONLY'; confidence='LOW';
        reason='Native quest packets were captured without a selected-bit transition or dialogue context.';
        suggested='Repeat while speaking to the exact NPC and advancing the quest.';
    elseif texts>0 then
        outcome='DIALOGUE ONLY'; confidence='LOW';
        reason='Dialogue was captured but no native 0x056 quest packet arrived.';
        suggested='Zone or reopen the quest log during the capture, then repeat the interaction.';
    end
    return {at=os.time(),after=after,ki_added=added,ki_removed=removed,outcome=outcome,confidence=confidence,reason=reason,suggested_action=suggested};
end

function M.start_quest(log_id,quest_id,mode)
    if active then HC.msg('A guided capture is already active. Stop it before starting another.'); return false; end
    local c=HC.modules.state.get_char();
    if not (type(c.settings)=='table' and c.settings.developer_mode==true) then HC.msg('Guided captures require Developer Mode.'); return false; end
    local q=HC.modules.quests; local detail=q and q.detail and q.detail(log_id,quest_id) or {};
    local name=(q and q.quest_name and q.quest_name(log_id,quest_id)) or ('Quest '..tostring(log_id)..':'..tostring(quest_id));
    local learning=HC.modules.learning; if not learning or not learning.start then return false; end
    if learning.active and learning.active() then HC.msg('Stop the current evidence capture before starting the guided wizard.'); return false; end
    local ok=learning.start('questverify'); if not ok then return false; end
    active={kind='quest',log_id=tonumber(log_id),quest_id=tonumber(quest_id),mode=lower(mode or 'verify'),name=name,
        start_npc=type(detail)=='table' and detail.start_npc or nil,start_zone=type(detail)=='table' and detail.start_zone or nil,
        started_at=os.time(),before=quest_state(log_id,quest_id),before_ki=ki_snapshot()};
    if learning.mark then learning.mark('GUIDED START '..tostring(log_id)..':'..tostring(quest_id)..' '..tostring(active.mode)); end
    if HC.modules.timeline and HC.modules.timeline.record then
        HC.modules.timeline.record(c,'capture','Guided Quest Capture Started',name..' ['..tostring(log_id)..':'..tostring(quest_id)..']',{source='capture wizard',dedupe_seconds=1});
    end
    return true;
end

function M.stop(reason)
    if not active then return false; end
    local w=active; local learning=HC.modules.learning; local capture=learning and learning.current and learning.current() or nil;
    if learning and learning.mark then learning.mark('GUIDED END '..tostring(w.log_id)..':'..tostring(w.quest_id)); end
    local after=quest_state(w.log_id,w.quest_id); local end_ki=ki_snapshot();
    local result=analyze(w,capture,after,end_ki);
    if learning and learning.active and learning.active() and learning.stop then learning.stop(reason or 'guided capture complete'); end
    local c=HC.modules.state.get_char();
    result.kind='quest'; result.log_id=w.log_id; result.quest_id=w.quest_id; result.name=w.name; result.mode=w.mode;
    result.learning_report=type(c.learning_summary)=='table' and c.learning_summary.report_path or nil;
    result.report_path=write_report(w,result,capture);
    local h=ensure_history(c); h[#h+1]=result; while #h>40 do table.remove(h,1); end
    last_result=result; active=nil;
    if HC.modules.state and HC.modules.state.save then HC.modules.state.save(); end
    if HC.modules.timeline and HC.modules.timeline.record then
        HC.modules.timeline.record(c,'capture','Guided Quest Capture Complete',w.name..' - '..result.outcome..' ['..result.confidence..']',{source='capture wizard',evidence=result.report_path,dedupe_seconds=1});
    end
    HC.msg('Guided capture complete: '..result.outcome..' ['..result.confidence..']. Report: '..tostring(result.report_path or result.learning_report));
    return true;
end

function M.poll()
    if active and HC.modules.learning and HC.modules.learning.active and not HC.modules.learning.active() then
        M.stop('underlying capture stopped');
    end
end

function M.active() return active~=nil; end
function M.current() return active; end
function M.last() return last_result; end
function M.history(c) c=c or HC.modules.state.get_char(); return ensure_history(c); end

function M.capture_button(log_id,quest_id,mode,id)
    local imgui=HC and HC.imgui or nil; if not imgui then return false; end
    local same=active and active.log_id==tonumber(log_id) and active.quest_id==tonumber(quest_id);
    local suffix=tostring(id or (tostring(log_id)..'_'..tostring(quest_id)));
    local label=same and ('Stop Capture##guided_'..suffix) or ('Capture##guided_'..suffix);
    if imgui.SmallButton(label) then if same then M.stop('guided button') else M.start_quest(log_id,quest_id,mode); end; return true; end
    return false;
end

function M.draw(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    imgui.Text('Guided Capture Wizard');
    imgui.TextDisabled('Captures a before/after native quest state, packets, dialogue, zone changes, and key-item differences for one selected catalog record.');
    if active then
        imgui.Text('ACTIVE: '..tostring(active.name)..' ['..tostring(active.log_id)..':'..tostring(active.quest_id)..']');
        imgui.TextDisabled('Mode: '..tostring(active.mode)..' | NPC: '..tostring(active.start_npc or 'not mapped')..' | Zone: '..tostring(active.start_zone or 'not mapped'));
        imgui.TextWrapped('Perform only the requested interaction, then stop the capture. Open/reopen the quest log or zone if native 0x056 state does not refresh.');
        if HC.modules.learning and HC.modules.learning.mark then
            if imgui.SmallButton('Mark NPC Talk##guided_mark_npc') then HC.modules.learning.mark('NPC TALK'); end
            imgui.SameLine(); if imgui.SmallButton('Mark Accepted##guided_mark_accept') then HC.modules.learning.mark('QUEST ACCEPTED'); end
            imgui.SameLine(); if imgui.SmallButton('Mark Completed##guided_mark_complete') then HC.modules.learning.mark('QUEST COMPLETED'); end
        end
        if imgui.Button('Stop Guided Capture##guided_stop') then M.stop('guided diagnostics button'); end
    else
        imgui.TextDisabled('Select Capture beside a catalog-verification issue below, or use /hcheck guided <log> <quest> [start|complete|verify].');
    end
    local r=last_result;
    if r then
        imgui.Text('Last result: '..tostring(r.outcome)..' ['..tostring(r.confidence)..']');
        imgui.TextDisabled(tostring(r.name)..' | '..tostring(r.reason));
        if r.report_path then imgui.TextDisabled('Report: '..tostring(r.report_path)); end
    end
end

function M.status(c)
    local h=M.history(c); return {active=active~=nil,current=active,last=last_result,history=#h};
end

function M.command(w)
    local sub=lower(w[2]); if sub~='guided' and sub~='capturewizard' then return false; end
    local action=lower(w[3]);
    if action=='stop' then M.stop('command'); return true; end
    local log_id=tonumber(w[3]); local quest_id=tonumber(w[4]);
    if log_id and quest_id then M.start_quest(log_id,quest_id,w[5] or 'verify'); return true; end
    HC.msg('/hcheck guided <log> <quest> [start|complete|verify] | /hcheck guided stop'); return true;
end

function M.init(ctx) HC=ctx; end
return M;
