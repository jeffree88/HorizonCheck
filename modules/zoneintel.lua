local M={};
local HC;
local cache={at=0,char=nil,zone=nil,data=nil};
local CACHE_SECONDS=1;

local function current_zone()
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

local function norm_zone(v)
    local s=string.lower(tostring(v or ''));
    s=s:gsub('%s*%b()','');
    s=s:gsub(',%s*north$',''):gsub(',%s*south$','');
    return s:gsub('^%s+',''):gsub('%s+$','');
end

local function location_zone(v)
    local s=tostring(v or '');
    s=s:gsub('%s*%b()','');
    s=s:gsub(',%s*[Nn]orth$',''):gsub(',%s*[Ss]outh$','');
    return s:gsub('^%s+',''):gsub('%s+$','');
end

local function same_zone(a,b)
    a=norm_zone(a); b=norm_zone(b);
    return a~='' and b~='' and a==b;
end

local function classify(row)
    local st=string.upper(tostring(row.status or row.state or ''));
    if st=='ACTIVE' or st=='IN PROGRESS' or st=='KEY ITEM READY' or st=='KILL PHASE' or st=='RETURN TO LUMOMO' or st=='RETURN TO NOREJAIE' then return 'DO NOW',1; end
    if st=='READY' or st=='AVAILABLE' or st=='HELD' then return 'READY',2; end
    if st=='GEAR TARGET' or st:find('GEAR OBTAINED',1,true) then return 'READY',3; end
    if st=='VERIFY / OBTAIN' or st=='VERIFY' or st=='CHECKING' or st=='NEED KEY ITEM' or st=='NOT HELD' then return 'PREP',4; end
    if st=='COOLDOWN' or st=='LOCKED' then return 'PREP',5; end
    return tostring(row.tier or 'PREP'),6;
end

local function add(out,seen,row)
    if type(row)~='table' then return; end
    if row.done==true then return; end
    if tonumber(row.total) and tonumber(row.obtained) and tonumber(row.total)>0 and tonumber(row.obtained)>=tonumber(row.total) then return; end
    local key=string.lower(tostring(row.kind or '')..'|'..tostring(row.name or ''));
    if seen[key] then return; end
    seen[key]=true;
    row.tier,row.tier_rank=classify(row);
    row.priority=tonumber(row.priority) or 100;
    out[#out+1]=row;
end

local function quest_rows(c,out,seen)
    local q=HC.modules and HC.modules.quests or nil;
    if not (q and q.progression_overview) then return; end
    local ok,po=pcall(q.progression_overview,c);
    if not ok or type(po)~='table' then return; end
    for _,r in ipairs(po.active_rows or {}) do
        if r.here==true then
            add(out,seen,{kind='Quest',name=tostring(r.name or 'Quest'),status='IN PROGRESS',detail=tostring(r.next_step or 'Continue this active quest here.'),score=tonumber(r.score) or 0,priority=10,log_id=r.log_id,quest_id=r.quest_id});
        end
    end
    for _,r in ipairs(po.recommended or {}) do
        if r.here==true then
            add(out,seen,{kind='Quest',name=tostring(r.name or 'Quest'),status='READY',detail=tostring(r.why or 'Quest starts or advances in this zone.'),score=tonumber(r.score) or 0,priority=30,log_id=r.log_id,quest_id=r.quest_id});
        end
    end
end

local function avatar_rows(c,zone,out,seen)
    local w=HC.modules and HC.modules.weekly or nil;
    if not (w and w.avatar_daily_status) then return; end
    local ok,rows=pcall(w.avatar_daily_status,false);
    if not ok or type(rows)~='table' then return; end
    local completed=type(c.daily)=='table' and type(c.daily.avatar_fights)=='table' and c.daily.avatar_fights or {};
    for _,r in ipairs(rows) do
        local rz=location_zone(r.location);
        if same_zone(rz,zone) and completed[tostring(r.avatar)]~=true then
            local status=(r.owned==true and 'KEY ITEM READY' or (r.owned==false and 'NEED KEY ITEM' or 'CHECKING'));
            add(out,seen,{kind='Daily Avatar',name=tostring(r.avatar or 'Avatar'),status=status,detail=tostring(r.npc or '?')..' - '..tostring(r.location or '')..' | '..tostring(r.key_item or ''),priority=20});
        end
    end
end

local function module_zone_rows(module_name,c,zone,out,seen)
    local m=HC.modules and HC.modules[module_name] or nil;
    if not (m and m.zone_rows) then return; end
    local ok,rows=pcall(m.zone_rows,c,zone);
    if not ok or type(rows)~='table' then return; end
    for _,r in ipairs(rows) do
        if module_name=='seasky' then
            local have=tonumber(r.obtained) or 0; local total=tonumber(r.total) or 0;
            if total>0 and have<total then
                r.status='GEAR TARGET'; r.detail=string.format('%d/%d obtained | %d missing from %s',have,total,total-have,tostring(r.name or 'this boss')); r.priority=40;
                add(out,seen,r);
            end
        else
            add(out,seen,r);
        end
    end
end

local function readiness_zone_rows(c,zone,out,seen)
    local r=HC.modules and HC.modules.readiness or nil; if not (r and r.zone_rows) then return; end
    local ok,rows=pcall(r.zone_rows,c,zone); if not ok then return; end
    for _,x in ipairs(rows or {}) do add(out,seen,x); end
end

function M.snapshot(c,force)
    c=type(c)=='table' and c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    local zone=current_zone(); local char=(HC.modules.core and HC.modules.core.character_name and HC.modules.core.character_name()) or 'Unknown'; local now=os.time();
    if force~=true and cache.data and cache.char==char and cache.zone==zone and now-(tonumber(cache.at) or 0)<CACHE_SECONDS then return cache.data; end
    local rows={}; local seen={};
    quest_rows(c,rows,seen);
    avatar_rows(c,zone,rows,seen);
    module_zone_rows('seasky',c,zone,rows,seen);
    module_zone_rows('enm',c,zone,rows,seen);
    readiness_zone_rows(c,zone,rows,seen);
    table.sort(rows,function(a,b)
        if (tonumber(a.tier_rank) or 9)~=(tonumber(b.tier_rank) or 9) then return (tonumber(a.tier_rank) or 9)<(tonumber(b.tier_rank) or 9); end
        if (tonumber(a.priority) or 100)~=(tonumber(b.priority) or 100) then return (tonumber(a.priority) or 100)<(tonumber(b.priority) or 100); end
        local as=tonumber(a.score) or 0; local bs=tonumber(b.score) or 0; if as~=bs then return as>bs; end
        return string.lower(tostring(a.name or ''))<string.lower(tostring(b.name or ''));
    end);
    local counts={}; for _,r in ipairs(rows) do counts[r.tier]=(counts[r.tier] or 0)+1; counts[r.kind]=(counts[r.kind] or 0)+1; end
    local data={zone=zone,rows=rows,counts=counts,at=now}; cache={at=now,char=char,zone=zone,data=data}; return data;
end

local function navigation_for_row(r)
    if r.tab then return r.tab,r.focus; end
    local kind=tostring(r and r.kind or '');
    if kind=='Quest' then return 'quests',{log_id=r.log_id,quest_id=r.quest_id,name=r.name}; end
    if kind=='Daily Avatar' then return 'dailyweekly',{section='avatars',avatar=r.name}; end
    if kind=='ENM' then return 'enm',{name=r.name}; end
    if kind=='Sea / Sky' then return 'seasky',{section=r.section or '',boss=r.name}; end
    if kind=='Assault' then return 'assault',{mission=r.name}; end
    if kind=='Outpost' then return 'dailyweekly',{section='outposts'}; end
    return nil,nil;
end

local function draw_go(imgui,r,id)
    local ui=HC.modules and HC.modules.ui or nil; if not (ui and ui.navigate) then return; end
    local tab,focus=navigation_for_row(r); if not tab then return; end
    if imgui.SmallButton('Go##zoneintel_go_'..tostring(id)) then ui.navigate(tab,focus); end
end

function M.draw(c,embedded)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local s=M.snapshot(c,false);
    if embedded~=true then
        imgui.Text("While You're Here"); imgui.SameLine(); imgui.TextDisabled(tostring(s.zone)); imgui.Separator();
    end
    imgui.TextDisabled(string.format('Do now %d | Ready %d | Prep %d',s.counts['DO NOW'] or 0,s.counts.READY or 0,s.counts.PREP or 0));
    if #s.rows==0 then imgui.TextDisabled('No unfinished tracked content detected in this zone.'); return; end
    local flags=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
    local table_ok=imgui.BeginTable and imgui.TableSetupColumn and imgui.TableHeadersRow and imgui.TableNextRow and imgui.TableSetColumnIndex and imgui.EndTable;
    if table_ok and imgui.BeginTable('##zone_intelligence_v770',5,flags) then
        imgui.TableSetupColumn('Priority',0,0.13); imgui.TableSetupColumn('Type',0,0.15); imgui.TableSetupColumn('Activity',0,0.27); imgui.TableSetupColumn('What to do here',0,0.37); imgui.TableSetupColumn('Open',0,0.08); imgui.TableHeadersRow();
        for i,r in ipairs(s.rows) do
            if i>14 then break; end
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0); if r.tier=='PREP' then imgui.TextDisabled(tostring(r.tier)); else imgui.Text(tostring(r.tier)); end
            imgui.TableSetColumnIndex(1); imgui.TextDisabled(tostring(r.kind or 'Activity'));
            imgui.TableSetColumnIndex(2); imgui.Text(tostring(r.name or ''));
            imgui.TableSetColumnIndex(3); imgui.TextDisabled(tostring(r.detail or r.status or r.zone or '-'));
            imgui.TableSetColumnIndex(4); draw_go(imgui,r,i);
        end
        imgui.EndTable();
        if #s.rows>14 then imgui.TextDisabled('+'..tostring(#s.rows-14)..' more thing(s) to do here.'); end
    else
        for i,r in ipairs(s.rows) do if i>14 then break; end; imgui.Text(tostring(r.tier)..' - '..tostring(r.name)); imgui.SameLine(); imgui.TextDisabled(tostring(r.detail or r.status or '-')); end
    end
end

function M.invalidate() cache={at=0,char=nil,zone=nil,data=nil}; end
function M.status(c) return M.snapshot(c,false); end
function M.init(ctx) HC=ctx; end
return M;
