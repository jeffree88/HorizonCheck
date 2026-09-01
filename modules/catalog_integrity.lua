local M = {};
local HC;
local last={at=nil,errors=0,warnings=0,infos=0,issues={},summary={}};

local KNOWN_REQ={
    fame=true,fame_log_id=true,rank=true,job=true,level=true,quests=true,quests_started=true,key_items=true,key_item=true,mission=true,missions=true,
    mission_key=true,mission_keys=true,reputation=true,reputation_level=true,weapon_skill=true,weapon_skill_level=true,fishing_skill=true,
    mercenary_points=true,status_any=true,wait_jst_midnight_after_quest=true,zone_after_wait=true,zone_after_quest=true,inventory_items=true,
    party_size=true,party_max_level=true,equip_proof_items=true,maat_jobs=true,avatar_unlocks=true,mercenary_rank_min=true,mission_active=true,
    mission_progress_min=true,wait_seconds_after_quest=true,manual_flags=true,ws_trial_exclusive=true,custom=true,custom_blocking=true,
    exclusive_active_quests=true,exclusive_quests=true,world_presence=true,craft_skill=true,
};
local KNOWN_REPEAT={['']=true,['no']=true,['false']=true,['repeatable']=true,['weekly']=true,['daily']=true,['conquest']=true,['memory reset']=true,['memory_reset']=true,['true']=true,['yes']=true};

local function issue(sev,kind,key,name,detail)
    local r={severity=sev,kind=kind,key=key,name=name,detail=tostring(detail or '')}; last.issues[#last.issues+1]=r;
    if sev=='ERROR' then last.errors=last.errors+1 elseif sev=='WARN' then last.warnings=last.warnings+1 else last.infos=last.infos+1 end
end

function M.run(c,announce)
    last={at=os.time(),errors=0,warnings=0,infos=0,issues={},summary={}};
    c=type(c)=='table' and c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    local q=HC.modules.quests; local graph=HC.modules.questgraph;
    if not q or not q.catalog_entries then issue('ERROR','Module','catalog','Quest Catalog','quests.catalog_entries unavailable'); return last; end
    local entries=q.catalog_entries() or {}; local enabled=0; local mapped=0; local repeatables=0;
    for _,rec in ipairs(entries) do
        local det=rec.detail or {}; local k=tostring(rec.log_id)..':'..tostring(rec.quest_id); local name=tostring(rec.name or k); local hor=type(det.horizon)=='table' and det.horizon or nil;
        if not hor or hor.enabled~=false then enabled=enabled+1; end
        if det.requirements_mapped==true then mapped=mapped+1; end
        local req=type(det.requirements)=='table' and det.requirements or {};
        for rk in pairs(req) do if not KNOWN_REQ[rk] then issue('ERROR','Unknown requirement field',k,name,rk); end end
        if hor and hor.verified==true and (not hor.source or tostring(hor.source)=='') then issue('WARN','Missing source',k,name,'Horizon verified record has no source label'); end
        if det.requirements_mapped==true and hor and hor.enabled==false then issue('WARN','Disabled mapped quest',k,name,'Requirements are mapped but quest is disabled on HorizonXI'); end
        local rt=string.lower(tostring(det.repeat_type or '')):gsub('^%s+',''):gsub('%s+$','');
        if rt~='' then
            repeatables=repeatables+1;
            if not KNOWN_REPEAT[rt] and not rt:find('repeat',1,true) then issue('WARN','Unknown repeat policy',k,name,tostring(det.repeat_type)); end
        end
        if det.requirements_mapped==true and (not det.start_zone or tostring(det.start_zone)=='') then issue('WARN','Missing start zone',k,name,'Fully mapped requirements but no start zone'); end
        if type(req.quests)=='table' then
            for _,r in ipairs(req.quests) do
                local rl=tonumber(r.log_id or r.log); local ri=tonumber(r.quest_id or r.id);
                if rl==tonumber(rec.log_id) and ri==tonumber(rec.quest_id) then issue('ERROR','Self dependency',k,name,'Quest requires itself completed'); end
            end
        end
        if type(req.quests_started)=='table' then
            for _,r in ipairs(req.quests_started) do
                local rl=tonumber(r.log_id or r.log); local ri=tonumber(r.quest_id or r.id);
                if rl==tonumber(rec.log_id) and ri==tonumber(rec.quest_id) then issue('ERROR','Self dependency',k,name,'Quest requires itself started'); end
            end
        end
    end

    local canonical=HC.modules.canonical;
    local canonical_status={collisions=0,quarantined=0};
    if canonical and canonical.snapshot then
        local ok,cs=pcall(canonical.snapshot,false);
        if ok and type(cs)=='table' then
            canonical_status.collisions=#(cs.collisions or {}); canonical_status.quarantined=#(cs.quarantined or {});
            for _,r in ipairs(cs.collisions or {}) do issue('ERROR','Native ID collision / mismatch',tostring(r.key),tostring(r.name),tostring(r.reason)); end
        end
    end

    local gs=graph and graph.summary and graph.summary(true) or {};
    for _,e in ipairs(gs.missing_rows or {}) do issue('ERROR','Missing prerequisite target',tostring(e.from),'Quest '..tostring(e.from),'References unmapped quest '..tostring(e.to)); end
    for _,cy in ipairs(gs.cycle_rows or {}) do issue('ERROR','Dependency cycle',tostring(cy[1] or '?'),'Quest dependency cycle',table.concat(cy,' -> ')); end

    -- Dynamic contradiction pass: a mapped AVAILABLE quest must not have a
    -- prerequisite edge that is currently known unsatisfied.
    if graph and q.availability then
        for _,rec in ipairs(entries) do
            local av=q.availability(c,rec.log_id,rec.quest_id);
            if av=='AVAILABLE' then
                for _,d in ipairs(graph.direct_dependencies(rec.log_id,rec.quest_id) or {}) do
                    local sat=(d.kind=='started' and q.started_or_completed and q.started_or_completed(d.log_id,d.quest_id)) or (q.is_completed and q.is_completed(d.log_id,d.quest_id));
                    if sat==false then issue('ERROR','Runtime contradiction',tostring(rec.log_id)..':'..tostring(rec.quest_id),tostring(rec.name),'AVAILABLE while prerequisite '..tostring(d.name)..' is not satisfied'); break; end
                end
            end
        end
    end

    table.sort(last.issues,function(a,b)
        local rank={ERROR=1,WARN=2,INFO=3}; local ra,rb=rank[a.severity] or 9,rank[b.severity] or 9;
        if ra~=rb then return ra<rb; end; if a.kind~=b.kind then return a.kind<b.kind; end; return string.lower(a.name)<string.lower(b.name);
    end);
    last.summary={entries=#entries,enabled=enabled,requirements_mapped=mapped,repeatables=repeatables,graph_nodes=tonumber(gs.nodes) or 0,graph_edges=tonumber(gs.edges) or 0,
        canonical_collisions=canonical_status.collisions,canonical_quarantined=canonical_status.quarantined};
    if announce and HC and HC.msg then HC.msg(string.format('Catalog integrity: %d error(s), %d warning(s) across %d quest records.',last.errors,last.warnings,#entries)); end
    return last;
end

function M.status() return last; end
function M.draw(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    imgui.Text('Catalog Integrity Engine');
    if imgui.Button('Run Catalog Integrity##hc_catalog_integrity') then M.run(c,true); end
    if last.at then imgui.SameLine(); imgui.Text(string.format('%d error(s) | %d warning(s)',last.errors,last.warnings)); else imgui.SameLine(); imgui.TextDisabled('Not run this session'); end
    local s=last.summary or {}; if last.at then imgui.TextDisabled(string.format('%d records | %d enabled | %d fully mapped | graph %d nodes / %d edges | native quarantine %d / collisions %d',tonumber(s.entries) or 0,tonumber(s.enabled) or 0,tonumber(s.requirements_mapped) or 0,tonumber(s.graph_nodes) or 0,tonumber(s.graph_edges) or 0,tonumber(s.canonical_quarantined) or 0,tonumber(s.canonical_collisions) or 0)); else imgui.TextDisabled('Run on demand to audit the final merged catalog and live prerequisite contradictions.'); end
    local shown=0; for _,r in ipairs(last.issues or {}) do if shown>=20 then break; end; shown=shown+1; local text=string.format('%s - %s - %s: %s',r.severity,r.kind,r.name,r.detail); if r.severity=='WARN' then imgui.TextDisabled(text); else imgui.TextWrapped(text); end end
    if #(last.issues or {})>shown then imgui.TextDisabled('+'..tostring(#last.issues-shown)..' more issue(s)'); elseif shown==0 and last.at then imgui.TextDisabled('No catalog integrity issues detected.'); end
end
function M.command(w) local sub=string.lower(w[2] or ''); if sub=='catalogaudit' or sub=='catalogintegrity' then M.run(nil,true); return true; end return false; end
function M.init(ctx) HC=ctx; end
return M;
