local M = {};
local HC;
local buffer={''};
local index_cache={at=0,char=nil,rows={}};
local CACHE_SECONDS=30;

local function lower(v) return string.lower(tostring(v or '')); end
local function compact(v) return lower(v):gsub('[^%w]+',' '):gsub('%s+',' '); end
local function matches(haystack,query)
    local q=compact(query); if q=='' then return true; end
    local h=compact(haystack);
    for token in q:gmatch('%S+') do if not h:find(token,1,true) then return false; end end
    return true;
end

local TAB_BY_KIND={
    Quest='Quests',Mission='Missions',Unlock='Character Info',ENM='ENM',System='Settings',
    ['Job Gear']='Character Info',['Sea / Sky']='Sea / Sky',['Daily Avatar']='Daily / Weekly',
    ['Assault Reward']='Assault',['Limbus Area']='Limbus',['Limbus Item']='Limbus',
    ['HENM Fight']='HENM',['HENM Reward']='HENM',['Event Reward']='Events',
};

local function add(rows,kind,name,subtitle,search_text,meta,where,tab,detail)
    kind=tostring(kind or 'Other'); meta=meta or {};
    rows[#rows+1]={
        kind=kind,name=tostring(name or ''),subtitle=tostring(subtitle or ''),search_text=tostring(search_text or ''),meta=meta,
        where=tostring(where or ''),tab=tostring(tab or TAB_BY_KIND[kind] or ''),detail=tostring(detail or ''),
    };
end

local function build_index(c,force)
    local now=os.time();
    local char=(HC.modules.core and HC.modules.core.character_name and HC.modules.core.character_name()) or 'Unknown';
    if not force and index_cache.rows and index_cache.char==char and now-(tonumber(index_cache.at) or 0)<CACHE_SECONDS then
        if HC.modules.profiler and HC.modules.profiler.cache then HC.modules.profiler.cache('search.index',true); end
        return index_cache.rows;
    end
    if HC.modules.profiler and HC.modules.profiler.cache then HC.modules.profiler.cache('search.index',false); end
    local rows={};

    local q=HC.modules.quests;
    if q and q.catalog_entries then
        local ok,entries=pcall(q.catalog_entries);
        if ok then
            for _,e in ipairs(entries or {}) do
                local detail=type(e.detail)=='table' and e.detail or {};
                local subtitle=(q.log_name and q.log_name(e.log_id) or ('Log '..tostring(e.log_id)))..' | Quest '..tostring(e.quest_id);
                local extra=table.concat({tostring(detail.start_npc or ''),tostring(detail.start_zone or ''),tostring(detail.reward or ''),tostring(detail.horizon_notes or '')},' ');
                local where=table.concat({tostring(detail.start_npc or ''),tostring(detail.start_zone or '')},' - '):gsub('^%s*%-?%s*',''):gsub('%s*%-$','');
                local dparts={}; if detail.reward and tostring(detail.reward)~='' then dparts[#dparts+1]='Reward: '..tostring(detail.reward); end; if detail.requirements then dparts[#dparts+1]='Requirements mapped'; end
                add(rows,'Quest',e.name,subtitle,e.name..' '..subtitle..' '..extra,{log_id=e.log_id,quest_id=e.quest_id,detail=detail},where,'Quests',table.concat(dparts,' | '));
            end
        end
    end

    local missions=HC.modules.missions;
    if missions and missions.catalog_entries then
        local ok,entries=pcall(missions.catalog_entries,c);
        if ok then
            for _,e in ipairs(entries or {}) do
                local subtitle=tostring(e.series_name or e.series_id or 'Mission')..' | '..tostring(e.number or '');
                add(rows,'Mission',e.name,subtitle,e.name..' '..subtitle..' '..tostring(e.type or '')..' '..tostring(e.reward or ''),e,tostring(e.zone or e.location or ''),'Missions',tostring(e.reward or ''));
            end
        end
    end

    local unlocks=HC.modules.unlocks;
    if unlocks and unlocks.definitions then
        local ok,defs=pcall(unlocks.definitions);
        if ok then
            for _,d in ipairs(defs or {}) do
                add(rows,'Unlock',d.name,tostring(d.category or 'Permanent Unlock'),d.name..' '..tostring(d.category or '')..' '..tostring(d.key or '')..' '..tostring(d.id or ''),d,tostring(d.location or ''),'Character Info','Permanent unlock');
            end
        end
    end

    local enm=HC.modules.enm;
    if enm and enm.catalog_entries then
        local ok,entries=pcall(enm.catalog_entries);
        if ok then
            for _,e in ipairs(entries or {}) do
                add(rows,'ENM',e.name,tostring(e.key_item or ''),e.name..' '..tostring(e.key_item or '')..' '..table.concat(e.enms or {},' '),e,tostring(e.zone or e.location or ''),'ENM','Key item: '..tostring(e.key_item or ''));
            end
        end
    end

    local weekly=HC.modules.weekly;
    if weekly and weekly.avatar_daily_status then
        local ok,entries=pcall(weekly.avatar_daily_status,false);
        if ok then
            local completed=type(c.daily)=='table' and type(c.daily.avatar_fights)=='table' and c.daily.avatar_fights or {};
            for _,e in ipairs(entries or {}) do
                add(rows,'Daily Avatar',e.avatar,tostring(e.key_item or ''),table.concat({tostring(e.avatar or ''),tostring(e.npc or ''),tostring(e.location or ''),tostring(e.key_item or '')},' '),
                    {avatar=e.avatar,owned=e.owned,completed=completed[tostring(e.avatar)]==true},tostring(e.npc or '')..' - '..tostring(e.location or ''),'Daily / Weekly','Required KI: '..tostring(e.key_item or ''));
            end
        end
    end

    local skills=HC.modules.skills;
    if skills and skills.gear_collection_snapshot then
        local ok,snap=pcall(skills.gear_collection_snapshot,false);
        if ok and type(snap)=='table' then
            for job,jr in pairs(snap.jobs or {}) do
                for _,set in pairs(jr.sets or {}) do
                    for _,it in ipairs(set.items or {}) do
                        if it.name and tostring(it.name)~='' then
                            add(rows,'Job Gear',it.name,tostring(job)..' | '..tostring(set.label or ''),table.concat({tostring(it.name),tostring(job),tostring(jr.name or ''),tostring(set.label or ''),tostring(it.location or '')},' '),
                                {owned=it.obtained==true,location=it.location,not_needed=it.not_needed==true,job=job,set=set.label},tostring(it.location or 'Not detected'),'Character Info',tostring(jr.name or job)..' - '..tostring(set.label or 'Gear'));
                        end
                    end
                end
            end
        end
    end

    local seasky=HC.modules.seasky;
    if seasky and seasky.catalog_entries then
        local ok,entries=pcall(seasky.catalog_entries,c);
        if ok then
            for _,e in ipairs(entries or {}) do
                add(rows,'Sea / Sky',e.name,tostring(e.section or '')..' | '..tostring(e.boss or ''),table.concat({tostring(e.name or ''),tostring(e.section or ''),tostring(e.boss or ''),tostring(e.zone or ''),tostring(e.source or ''),tostring(e.location or '')},' '),
                    {owned=e.owned==true,location=e.location,boss=e.boss,section=e.section},tostring(e.boss or '')..' - '..tostring(e.zone or ''),'Sea / Sky','Source: '..tostring(e.source or ''));
            end
        end
    end

    local assaultprogress=HC.modules.assaultprogress;
    if assaultprogress and assaultprogress.reward_catalog_entries then
        local ok,entries=pcall(assaultprogress.reward_catalog_entries,c);
        if ok then
            for _,e in ipairs(entries or {}) do
                add(rows,'Assault Reward',e.name,tostring(e.area)..' | '..tostring(e.cost)..' AP',
                    table.concat({e.name,e.area,e.vendor,e.vendor_pos,tostring(e.cost),'Assault Points'},' '),
                    e,tostring(e.location or ''),'Assault',tostring(e.vendor)..' - '..tostring(e.vendor_pos));
            end
        end
    end

    local limbus=HC.modules.limbus;
    if limbus and limbus.catalog_entries then
        local ok,entries=pcall(limbus.catalog_entries,c);
        if ok then
            for _,e in ipairs(entries or {}) do
                local kind=(e.kind=='area') and 'Limbus Area' or 'Limbus Item';
                local where=(e.kind=='area') and tostring(e.section or '') or tostring(e.location or '');
                local detail=(e.kind=='area') and table.concat({tostring(e.reward or ''),tostring(e.af or ''),tostring(e.detail or '')},' | ') or tostring(e.section or '');
                add(rows,kind,e.name,tostring(e.section or ''),tostring(e.search or e.name),e,where,'Limbus',detail);
            end
        end
    end

    local henm=HC.modules.henm;
    if henm and henm.catalog_entries then
        local ok,entries=pcall(henm.catalog_entries,c);
        if ok then
            for _,e in ipairs(entries or {}) do
                local kind=(e.kind=='fight') and 'HENM Fight' or 'HENM Reward';
                local where=(e.kind=='fight') and (tostring(e.zone or '')..' - '..tostring(e.spawns or '')) or tostring(e.location or '');
                local detail=(e.kind=='fight') and tostring(e.detail or '') or (tostring(e.fight or '')..' | '..tostring(e.reward_type or ''));
                add(rows,kind,e.name,'Tier '..tostring(e.tier or ''),tostring(e.search or e.name),e,where,'HENM',detail);
            end
        end
    end

    local seasonal=HC.modules.seasonal;
    if seasonal and seasonal.catalog_entries then
        local ok,entries=pcall(seasonal.catalog_entries,c);
        if ok then
            for _,e in ipairs(entries or {}) do
                add(rows,'Event Reward',e.name,tostring(e.event or ''),tostring(e.search or e.name),e,tostring(e.location or ''),'Events',tostring(e.source or ''));
            end
        end
    end

    local systems=HC.modules.systems;
    if systems and systems.snapshot then
        local ok,snap=pcall(systems.snapshot,c,false);
        if ok and type(snap)=='table' then
            for id,s in pairs(snap.systems or {}) do
                add(rows,'System',s.label or id,tostring(s.state or ''),tostring(s.label or id)..' '..tostring(s.state or '')..' '..tostring(s.reason or '')..' '..tostring(id),{id=id},'','Settings',tostring(s.reason or ''));
            end
        end
    end

    table.sort(rows,function(a,b) if a.kind~=b.kind then return a.kind<b.kind; end return lower(a.name)<lower(b.name); end);
    index_cache={at=now,char=char,rows=rows}; return rows;
end

local function live_state(row,c)
    local m=row.meta or {};
    if row.kind=='Quest' then
        local cm=HC.modules.canonical;
        if cm and cm.quest then
            local ok,r=pcall(cm.quest,m.log_id,m.quest_id,m.detail);
            if ok and type(r)=='table' then
                if r.content_state=='UNAVAILABLE' or r.content_state=='FUTURE' or r.content_state=='DISABLED' then return tostring(r.content_state); end
                if r.native_policy=='QUARANTINE' then return 'ID QUARANTINED'; end
            end
        end
        local q=HC.modules.quests;
        if q then
            if q.is_completed and q.is_completed(m.log_id,m.quest_id) then return 'COMPLETE'; end
            if q.is_active and q.is_active(m.log_id,m.quest_id) then return 'ACTIVE'; end
            if q.availability then local ok,v=pcall(q.availability,c,m.log_id,m.quest_id); if ok and v then return tostring(v); end end
        end
        return 'CATALOG';
    elseif row.kind=='Mission' then
        if m.completed==true then return 'COMPLETE'; end
        local av=HC.modules.availability;
        if av and av.mission then local ok,v=pcall(av.mission,m.series_id,m.number,m); if ok and type(v)=='table' then return tostring(v.state or ''); end end
        return 'AVAILABLE';
    elseif row.kind=='Unlock' then
        local u=HC.modules.unlocks;
        if u and u.by_id and m.id then local ok,r=pcall(u.by_id,m.id,c); if ok and r then return r.owned==true and 'OWNED' or (r.owned==false and 'MISSING' or 'UNKNOWN'); end end
        return 'UNKNOWN';
    elseif row.kind=='Job Gear' or row.kind=='Sea / Sky' or row.kind=='Assault Reward' or row.kind=='Limbus Item' or row.kind=='HENM Reward' or row.kind=='Event Reward' then
        if m.not_needed==true then return 'NOT NEEDED'; end
        return m.owned==true and 'OWNED' or 'MISSING';
    elseif row.kind=='Limbus Area' then
        return tostring(m.status or 'CHECK');
    elseif row.kind=='HENM Fight' then
        return 'AVAILABLE';
    elseif row.kind=='Daily Avatar' then
        if m.completed==true then return 'DONE TODAY'; end
        if m.owned==true then return 'KEY ITEM READY'; end
        if m.owned==false then return 'NEED KEY ITEM'; end
        return 'CHECKING';
    elseif row.kind=='System' then
        local s=HC.modules.systems;
        if s and s.get then local ok,r=pcall(s.get,m.id,c); if ok and r then return tostring(r.state or 'UNKNOWN'); end end
    elseif row.kind=='ENM' then
        return 'TRACKED';
    end
    return '';
end

function M.query(text,c,limit)
    if HC.modules.profiler and HC.modules.profiler.bump then HC.modules.profiler.bump('search.query.count'); end
    c=c or (HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    text=tostring(text or ''); if text=='' then return {}; end
    local out={}; local cq=compact(text);
    for _,r in ipairs(build_index(c,false)) do
        if matches(r.search_text,text) then
            local copy={}; for k,v in pairs(r) do copy[k]=v; end
            copy.state=live_state(r,c);
            if copy.kind=='Quest' and copy.state=='LOCKED' and HC.modules and HC.modules.blockers and HC.modules.blockers.quest then
                local m=copy.meta or {};
                local okb,b=pcall(HC.modules.blockers.quest,c,m.log_id,m.quest_id,copy.state,nil);
                if okb and type(b)=='table' and tostring(b.summary or '')~='' then
                    local prefix=(copy.detail and copy.detail~='') and (copy.detail..' | ') or '';
                    copy.detail=prefix..'Blocker: '..tostring(b.summary);
                end
            end
            local cn=compact(copy.name); local score=0;
            if cn==cq then score=1000; elseif cn:find(cq,1,true)==1 then score=700; elseif cn:find(cq,1,true) then score=500; end
            if compact(copy.where):find(cq,1,true) then score=score+120; end
            if compact(copy.tab):find(cq,1,true) then score=score+60; end
            copy.search_score=score; out[#out+1]=copy;
        end
    end
    table.sort(out,function(a,b)
        if (a.search_score or 0)~=(b.search_score or 0) then return (a.search_score or 0)>(b.search_score or 0); end
        if a.kind~=b.kind then return a.kind<b.kind; end
        return lower(a.name)<lower(b.name);
    end);
    local maxn=math.max(1,tonumber(limit) or 20); while #out>maxn do table.remove(out); end
    return out;
end

function M.text() return tostring(buffer[1] or ''); end
function M.active() return M.text()~=''; end
function M.clear() buffer[1]=''; end
function M.invalidate() index_cache={at=0,char=nil,rows={}}; end
function M.rebuild(c) M.invalidate(); return build_index(c,true); end

function M.draw_bar(c)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    imgui.TextDisabled('Find anything:'); imgui.SameLine();
    local ok=pcall(function() imgui.InputText('##hc_global_search',buffer,160); end);
    if not ok then imgui.TextDisabled('Search input unavailable in this ImGui build.'); return; end
    if M.active() then imgui.SameLine(); if imgui.SmallButton('Clear##hc_global_search_clear') then M.clear(); end else imgui.SameLine(); imgui.TextDisabled('quests, missions, gear, Assault, Limbus, HENM, events, items'); end
end

local function navigation_target(row)
    local tab=tostring(row and row.tab or '');
    if tab=='' then return nil,nil; end
    local focus=nil;
    if row.kind=='Job Gear' and type(row.meta)=='table' then focus={job=row.meta.job,item=row.name};
    elseif row.kind=='Quest' and type(row.meta)=='table' then focus={log_id=row.meta.log_id,quest_id=row.meta.quest_id};
    elseif row.kind=='Daily Avatar' then focus={section='avatars',avatar=row.name};
    elseif row.kind=='Sea / Sky' and type(row.meta)=='table' then focus={section=row.meta.section,boss=row.meta.boss,item=row.name};
    elseif row.kind=='Assault Reward' and type(row.meta)=='table' then focus={section='rewards',area=row.meta.area_id,item=row.name};
    elseif (row.kind=='Limbus Area' or row.kind=='Limbus Item') and type(row.meta)=='table' then
        local sec=tostring(row.meta.section or '');
        local low=string.lower(sec);
        if low:find('af%+1') then sec='af';
        elseif low=='homam' or low=='nashira' then sec='boss';
        elseif low:find('temenos',1,true) then sec='temenos';
        else sec='apollyon'; end
        focus={section=sec,item=row.name};
    elseif (row.kind=='HENM Fight' or row.kind=='HENM Reward') and type(row.meta)=='table' then focus={fight_id=row.meta.fight_id,item=row.name};
    elseif row.kind=='Event Reward' and type(row.meta)=='table' then focus={section='seasonal',event_id=row.meta.event_id,item=row.name};
    end
    return tab,focus;
end

local function draw_go(imgui,row,id)
    local ui=HC.modules and HC.modules.ui or nil; if not (ui and ui.navigate) then return; end
    local tab,focus=navigation_target(row); if not tab then return; end
    if imgui.SmallButton('Go##hc_search_go_'..tostring(id)) then ui.navigate(tab,focus); end
end

function M.draw_results(c)
    local imgui=HC and HC.imgui or nil; if not imgui or not M.active() then return; end
    local profiler=HC.modules.profiler;
    local results=nil;
    if profiler and profiler.measure then results=profiler.measure('search.query',M.query,M.text(),c,8); else results=M.query(M.text(),c,8); end
    imgui.Text('Search Results'); imgui.SameLine(); imgui.TextDisabled(tostring(#results)..' shown');
    if #results==0 then imgui.TextDisabled('No tracker records match "'..M.text()..'".'); end
    local table_ok=(imgui.BeginTable~=nil and imgui.TableSetupColumn~=nil and imgui.TableHeadersRow~=nil and imgui.TableNextRow~=nil and imgui.TableSetColumnIndex~=nil and imgui.EndTable~=nil);
    local flags=(HC.modules.uikit and HC.modules.uikit.table_flags and HC.modules.uikit.table_flags()) or (64+128+512);
    if #results>0 and table_ok and imgui.BeginTable('##hc_global_search_results_v790',6,flags) then
        imgui.TableSetupColumn('Type',0,0.12); imgui.TableSetupColumn('Name',0,0.27); imgui.TableSetupColumn('State',0,0.14); imgui.TableSetupColumn('Where',0,0.26); imgui.TableSetupColumn('Tab',0,0.13); imgui.TableSetupColumn('Open',0,0.08); imgui.TableHeadersRow();
        for i,r in ipairs(results) do
            imgui.TableNextRow(); imgui.TableSetColumnIndex(0); imgui.TextDisabled(r.kind);
            imgui.TableSetColumnIndex(1); imgui.Text(r.name);
            if imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then
                local tip=tostring(r.subtitle or ''); if r.detail and r.detail~='' then tip=tip..'\n'..tostring(r.detail); end; imgui.SetTooltip(tip);
            end
            imgui.TableSetColumnIndex(2); imgui.TextDisabled(tostring(r.state or ''));
            imgui.TableSetColumnIndex(3); imgui.TextDisabled((r.where and r.where~='') and r.where or '-');
            imgui.TableSetColumnIndex(4); imgui.TextDisabled((r.tab and r.tab~='') and r.tab or '-');
            imgui.TableSetColumnIndex(5); draw_go(imgui,r,i);
        end
        imgui.EndTable();
    elseif #results>0 then
        for _,r in ipairs(results) do imgui.Text(r.kind..' - '..r.name); imgui.SameLine(); imgui.TextDisabled('['..tostring(r.state or '')..'] '..tostring(r.where or r.subtitle)..' | '..tostring(r.tab or '')); end
    end
    if HC.modules.itemlocator and HC.modules.itemlocator.draw_search_matches then HC.modules.itemlocator.draw_search_matches(M.text()); end
end

function M.status(c) return {indexed=#build_index(c,false),active=M.active(),query=M.text()}; end
function M.command(w)
    local sub=lower(w[2]); if sub~='search' and sub~='find' then return false; end
    local q=table.concat(w,' ',3); buffer[1]=q; local rows=M.query(q,nil,5); HC.msg('Search: '..tostring(#rows)..' result(s) shown for '..q); return true;
end
function M.init(ctx) HC=ctx; end
return M;
