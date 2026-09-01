local M={};
local HC;
local cache={at=0,char=nil,data=nil};
local CACHE_SECONDS=3;

local function age_text(seconds)
    seconds=tonumber(seconds); if not seconds then return 'never'; end
    if seconds<60 then return tostring(math.floor(seconds))..'s ago'; end
    if seconds<3600 then return tostring(math.floor(seconds/60))..'m ago'; end
    if seconds<86400 then return tostring(math.floor(seconds/3600))..'h ago'; end
    return tostring(math.floor(seconds/86400))..'d ago';
end

local function add(rows,id,label,state,detail,initialized,action)
    rows[#rows+1]={id=id,label=label,state=state,detail=detail,initialized=initialized==true,action=action};
end

local function milestones(c)
    c.sync_milestones=type(c.sync_milestones)=='table' and c.sync_milestones or {};
    return c.sync_milestones;
end

function M.snapshot(c,force)
    c=c or HC.modules.state.get_char();
    local char=HC.modules.state.profile_name(); local now=os.time();
    if force~=true and cache.data and cache.char==char and now-(tonumber(cache.at) or 0)<CACHE_SECONDS then return cache.data; end
    local rows={}; local ms=milestones(c);

    local mm=type(c.mission_meta)=='table' and c.mission_meta or {};
    local native=type(mm.native)=='table' and mm.native or {};
    local mage=native.last_seen_at and math.max(0,now-tonumber(native.last_seen_at)) or nil;
    add(rows,'missions','Mission history',not mage and 'NEEDS SYNC' or (mage>7*86400 and 'STALE' or 'HEALTHY'),
        mage and ('native history received '..age_text(mage)) or 'Native mission history has not been observed yet.',native.last_seen_at~=nil,
        not mage and 'Zone once to receive native mission history.' or (mage>7*86400 and 'Zone once if you want to refresh native mission history.' or 'No action needed.'));

    local kb=HC.modules.keyitems and HC.modules.keyitems.bitmap_status and HC.modules.keyitems.bitmap_status() or {};
    local kt=tonumber(kb.tables) or 0;
    add(rows,'keyitems','Permanent key-item bitmap',kt>0 and 'HEALTHY' or 'NEEDS SYNC',kt>0 and (tostring(kt)..' server bitmap table(s) cached this session') or 'Server key-item bitmap has not been observed this session.',kt>0,kt>0 and 'No action needed.' or 'Zone once to receive the server key-item tables.');

    local zs=HC.modules.zonesync and HC.modules.zonesync.status and HC.modules.zonesync.status() or {};
    add(rows,'zonesync','Zone reconciliation',zs.state=='COMPLETE' and 'HEALTHY' or ((zs.state=='SYNCING' or zs.state=='PENDING') and 'STALE' or 'NEEDS SYNC'),
        zs.state=='COMPLETE' and ('completed '..age_text(now-(tonumber(zs.last_completed_at) or now))) or ('state '..tostring(zs.state or 'WAITING')..' | phase '..tostring(zs.phase or 0)..'/3'),zs.last_completed_at~=nil,
        zs.state=='COMPLETE' and 'No action needed.' or 'Wait for zone reconciliation to finish; zoning again will schedule a fresh pass.');

    local ap=HC.modules.assaultprogress and HC.modules.assaultprogress.native_status and HC.modules.assaultprogress.native_status(c) or {};
    add(rows,'assault_history','Historical Assault clears',ap.synced and 'HEALTHY' or 'NEEDS SYNC',ap.synced and string.format('%d/50 native clear(s) known',tonumber(ap.native_completed) or 0) or 'Native Assault completion history has not been imported.',ap.synced==true,ap.synced and 'No action needed.' or 'Zone once to import historical Assault clears.');

    local hi=HC.modules.historyimport and HC.modules.historyimport.status and HC.modules.historyimport.status(c) or {};
    add(rows,'history','Historical progression import',hi.at and 'HEALTHY' or 'NEEDS SYNC',hi.at and ('last import '..age_text(now-tonumber(hi.at))) or 'Permanent-history reconstruction has not completed.',hi.at~=nil,hi.at and 'No action needed.' or 'Zone once or use Synchronize Now in Initial Synchronization.');

    local es=HC.modules.eco and HC.modules.eco.sync_status and HC.modules.eco.sync_status(c) or {};
    local eco_init=(ms.eco and ms.eco.at) or es.initialized;
    local eco_state=es.synced and 'HEALTHY' or (eco_init and 'STALE' or 'NEEDS SYNC');
    local eco_detail=es.synced and 'current Conquest-week rotation verified'
        or (eco_init and 'initial setup retained; current-week Eeko rotation has not been refreshed' or 'Talk to Eeko-Weeko once to initialize Eco-War tracking.');
    add(rows,'eco','Eco-War / Eeko-Weeko',eco_state,eco_detail,eco_init~=nil and eco_init~=false,
        eco_state=='HEALTHY' and 'No action needed.' or (eco_init and 'Talk to Eeko-Weeko to refresh the current Conquest-week rotation.' or 'Talk to Eeko-Weeko once to initialize Eco-War tracking.'));

    local ts=HC.modules.assault and HC.modules.assault.sync_status and HC.modules.assault.sync_status(c) or {};
    local tag_init=(ms.assault_tags and ms.assault_tags.at) or ts.initialized;
    local tage=ts.at and math.max(0,now-tonumber(ts.at)) or nil;
    local rs=HC.modules.assault and HC.modules.assault.rytaal_status and HC.modules.assault.rytaal_status(c) or {};
    local tag_stale=tag_init and ((rs and rs.regen_pending==true) or (tage and tage>48*3600));
    local tag_state=not tag_init and 'NEEDS SYNC' or (tag_stale and 'STALE' or 'HEALTHY');
    local tag_detail=not tag_init and 'Talk to Rytaal once to initialize Assault Tag tracking.'
        or (tag_stale and 'initial setup retained; live Rytaal count may need verification' or string.format('Character %s | Rytaal %s/3 | Total %s/4',tostring(ts.carried or '?'),tostring(ts.rytaal or '?'),tostring(ts.total or '?')));
    add(rows,'assault_tags','Assault Tags / Rytaal',tag_state,tag_detail,tag_init~=nil and tag_init~=false,
        tag_state=='HEALTHY' and 'No action needed.' or (tag_init and 'Talk to Rytaal to verify the current live tag count.' or 'Talk to Rytaal once to initialize Assault Tag tracking.'));

    local fs=HC.modules.fame and HC.modules.fame.sync_status and HC.modules.fame.sync_status(c) or {};
    local fame_init=(ms.fame and ms.fame.at) or fs.complete;
    add(rows,'fame','Fame / Reputation',fs.complete and 'HEALTHY' or 'NEEDS SYNC',
        fs.complete and string.format('%d/%d checker NPCs initialized',tonumber(fs.done) or 0,tonumber(fs.total) or 0)
            or string.format('%d/%d checker NPCs synchronized%s',tonumber(fs.done) or 0,tonumber(fs.total) or 0,(type(fs.missing)=='table' and #fs.missing>0) and (' | Missing: '..table.concat(fs.missing,', ')) or ''),fame_init~=nil and fame_init~=false,
        fs.complete and 'No action needed.' or ((type(fs.missing)=='table' and #fs.missing>0) and ('Talk to the missing fame checker(s): '..table.concat(fs.missing,', ')) or 'Talk to each supported fame/reputation checker once.'));

    local ps=HC.modules.progression and HC.modules.progression.status and HC.modules.progression.status(c) or {};
    add(rows,'progression','Normalized progression',((tonumber(ps.records) or 0)>0) and 'HEALTHY' or 'NEEDS SYNC',
        ((tonumber(ps.records) or 0)>0) and (tostring(ps.records)..' normalized fact(s)') or 'Waiting for progression reconciliation.',(tonumber(ps.records) or 0)>0,
        ((tonumber(ps.records) or 0)>0) and 'No action needed.' or 'Zone once and allow initial reconciliation to finish.');

    local healthy,stale,needs=0,0,0;
    for _,r in ipairs(rows) do
        if r.state=='HEALTHY' then healthy=healthy+1 elseif r.state=='STALE' then stale=stale+1 else needs=needs+1 end
    end
    local overall=needs>0 and 'NEEDS SYNC' or (stale>0 and 'STALE' or 'HEALTHY');
    local out={at=now,rows=rows,state=overall,healthy=healthy,stale=stale,needs_sync=needs,total=#rows};
    cache={at=now,char=char,data=out}; return out;
end

function M.invalidate() cache={at=0,char=nil,data=nil}; end
function M.status(c) return M.snapshot(c,false); end

function M.draw(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local s=M.snapshot(c,false);
    imgui.Text('Synchronization Health: '..tostring(s.state));
    imgui.TextDisabled(string.format('%d healthy | %d stale | %d need sync',s.healthy or 0,s.stale or 0,s.needs_sync or 0));
    imgui.TextDisabled('Initialization is permanent. STALE means live/current-cycle evidence could be refreshed; it never reopens Initial Synchronization.');
    local table_ok=imgui.BeginTable and imgui.TableSetupColumn and imgui.TableHeadersRow and imgui.TableNextRow and imgui.TableSetColumnIndex and imgui.EndTable;
    if table_ok and imgui.BeginTable('##hc_sync_health_v7100',4,64+128+512) then
        imgui.TableSetupColumn('State',0,90); imgui.TableSetupColumn('System',0,195); imgui.TableSetupColumn('Details',0,385); imgui.TableSetupColumn('Action',0,330); imgui.TableHeadersRow();
        for _,r in ipairs(s.rows or {}) do
            imgui.TableNextRow(); imgui.TableSetColumnIndex(0); if r.state=='HEALTHY' then imgui.Text(r.state); else imgui.TextDisabled(r.state); end
            imgui.TableSetColumnIndex(1); imgui.Text(tostring(r.label));
            imgui.TableSetColumnIndex(2); imgui.TextDisabled(tostring(r.detail or ''));
            imgui.TableSetColumnIndex(3); if r.state=='HEALTHY' then imgui.TextDisabled(tostring(r.action or 'No action needed.')); else imgui.TextWrapped(tostring(r.action or '')); end
        end
        imgui.EndTable();
    else
        for _,r in ipairs(s.rows or {}) do imgui.TextWrapped(tostring(r.state)..' | '..tostring(r.label)..' - '..tostring(r.detail or '')); if r.state~='HEALTHY' then imgui.TextDisabled('  Action: '..tostring(r.action or '')); end end
    end
    if imgui.Button('Refresh Sync Health##hc_sync_health_refresh') then M.invalidate(); M.snapshot(c,true); end
end

function M.init(ctx) HC=ctx; end
return M;
