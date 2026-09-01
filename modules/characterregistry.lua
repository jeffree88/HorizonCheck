local M={};
local HC;
local cache={at=0,data=nil};
local CACHE_SECONDS=5;
local pending_remove=nil;

local function age_label(at)
    at=tonumber(at); if not at then return 'Never'; end
    local age=math.max(0,os.time()-at);
    if age<120 then return 'Now'; end
    if age<3600 then return tostring(math.floor(age/60))..'m ago'; end
    if age<86400 then return tostring(math.floor(age/3600))..'h ago'; end
    return tostring(math.floor(age/86400))..'d ago';
end

local function pct(v)
    v=tonumber(v); if not v then return '--'; end
    return tostring(math.max(0,math.min(100,math.floor(v+0.5))))..'%';
end

local function initialized_state(cc)
    local s=type(cc.settings)=='table' and cc.settings or {};
    local ms=type(cc.sync_milestones)=='table' and cc.sync_milestones or {};
    if tonumber(s.setup_wizard_completed_at) then return 'COMPLETE'; end
    local n=0;
    if type(ms.eco)=='table' and tonumber(ms.eco.at) then n=n+1; end
    if type(ms.assault_tags)=='table' and tonumber(ms.assault_tags.at) then n=n+1; end
    if type(ms.fame)=='table' and tonumber(ms.fame.at) then n=n+1; end
    return n>0 and ('PARTIAL '..tostring(n)..'/3') or 'NOT INITIALIZED';
end

function M.snapshot(force)
    local now=os.time();
    if force~=true and cache.data and now-(tonumber(cache.at) or 0)<CACHE_SECONDS then return cache.data; end
    local raw=HC.modules.state and HC.modules.state.raw and HC.modules.state.raw() or {};
    local chars=type(raw.chars)=='table' and raw.chars or {};
    local current=tostring(HC.modules.state.profile_name() or 'Unknown');
    local rows={};
    for name,cc in pairs(chars) do
        if type(cc)=='table' and tostring(name)~='Unknown' then
            local p=type(cc.overview_profile)=='table' and cc.overview_profile or {};
            local seen=tonumber(p.last_seen_at);
            local age=seen and math.max(0,now-seen) or nil;
            rows[#rows+1]={
                name=tostring(name),current=tostring(name)==current,last_seen_at=seen,last_seen=age_label(seen),
                stale=age~=nil and age>90*86400 or false,
                schema=tonumber(cc.schema_version) or tonumber(raw.schema) or 0,
                initialized=initialized_state(cc),
                job=tostring(p.job or '---'),level=tonumber(p.level) or 0,jobs_75=tonumber(p.jobs_75) or 0,jobs_total=tonumber(p.jobs_total) or 0,
                overview_pct=tonumber(p.overview_pct),
            };
        end
    end
    table.sort(rows,function(a,b)
        if a.current~=b.current then return a.current==true; end
        local aa,bb=tonumber(a.last_seen_at) or 0,tonumber(b.last_seen_at) or 0;
        if aa~=bb then return aa>bb; end
        return string.lower(a.name)<string.lower(b.name);
    end);
    local stale=0; for _,r in ipairs(rows) do if r.stale then stale=stale+1; end end
    local out={at=now,rows=rows,count=#rows,stale=stale,current=current,pending_remove=pending_remove};
    cache={at=now,data=out}; return out;
end

function M.invalidate() cache={at=0,data=nil}; end

function M.remove(name)
    name=tostring(name or '');
    local current=tostring(HC.modules.state.profile_name() or 'Unknown');
    if name=='' or name=='Unknown' then return false,'invalid character'; end
    if name==current then return false,'current character cannot be removed'; end
    local raw=HC.modules.state.raw(); raw.chars=type(raw.chars)=='table' and raw.chars or {};
    if type(raw.chars[name])~='table' then return false,'character record not found'; end
    raw.chars[name]=nil; pending_remove=nil;
    if HC.modules.state and HC.modules.state.save then HC.modules.state.save(); end
    if HC.modules.smartdashboard and HC.modules.smartdashboard.invalidate then HC.modules.smartdashboard.invalidate(); end
    M.invalidate();
    return true,'removed saved character '..name;
end

function M.status()
    local s=M.snapshot(false); return {characters=s.count,stale=s.stale,current=s.current};
end

function M.draw()
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local s=M.snapshot(false);
    imgui.Text('Character Registry');
    imgui.TextDisabled('Saved account profiles only. Removing a profile never affects the character on HorizonXI; it deletes only that character\'s HorizonCheck saved tracker state.');
    imgui.TextDisabled(string.format('%d saved character%s | %d not seen for 90+ days',s.count or 0,(s.count or 0)==1 and '' or 's',s.stale or 0));
    local table_ok=imgui.BeginTable and imgui.TableSetupColumn and imgui.TableHeadersRow and imgui.TableNextRow and imgui.TableSetColumnIndex and imgui.EndTable;
    if table_ok and imgui.BeginTable('##hc_character_registry_v7100',7,64+128+512) then
        imgui.TableSetupColumn('Character',0,150); imgui.TableSetupColumn('Job',0,90); imgui.TableSetupColumn('Jobs 75',0,75);
        imgui.TableSetupColumn('Overview',0,75); imgui.TableSetupColumn('Initial Sync',0,130); imgui.TableSetupColumn('Last Seen',0,90); imgui.TableSetupColumn('Saved State',0,145); imgui.TableHeadersRow();
        for _,r in ipairs(s.rows or {}) do
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0); imgui.Text(r.name..(r.current and ' (Current)' or ''));
            imgui.TableSetColumnIndex(1); imgui.TextDisabled(string.format('%s %d',r.job or '---',r.level or 0));
            imgui.TableSetColumnIndex(2); imgui.Text(string.format('%d/%d',r.jobs_75 or 0,r.jobs_total or 0));
            imgui.TableSetColumnIndex(3); imgui.TextDisabled(pct(r.overview_pct));
            imgui.TableSetColumnIndex(4); if r.initialized=='COMPLETE' then imgui.Text('COMPLETE'); else imgui.TextDisabled(r.initialized); end
            imgui.TableSetColumnIndex(5); imgui.TextDisabled(r.last_seen..(r.stale and ' [STALE]' or ''));
            imgui.TableSetColumnIndex(6);
            if r.current then imgui.TextDisabled('Protected');
            elseif pending_remove==r.name then
                if imgui.SmallButton('Confirm Remove##hc_registry_confirm_'..r.name) then
                    local ok,msg=M.remove(r.name); HC.msg(ok and ('Character Registry: '..msg) or ('Character Registry: '..tostring(msg))); s=M.snapshot(true);
                end
                imgui.SameLine(); if imgui.SmallButton('Cancel##hc_registry_cancel_'..r.name) then pending_remove=nil; M.invalidate(); end
            else
                if imgui.SmallButton('Remove...##hc_registry_remove_'..r.name) then pending_remove=r.name; M.invalidate(); end
            end
        end
        imgui.EndTable();
    else
        for _,r in ipairs(s.rows or {}) do
            imgui.Text(r.name..(r.current and ' (Current)' or ''));
            imgui.SameLine(); imgui.TextDisabled(string.format('%s %d | Jobs 75 %d/%d | %s | Last seen %s',r.job or '---',r.level or 0,r.jobs_75 or 0,r.jobs_total or 0,r.initialized,r.last_seen));
            if not r.current then
                if pending_remove==r.name then
                    if imgui.SmallButton('Confirm Remove##hc_registry_confirm_small_'..r.name) then local ok,msg=M.remove(r.name); HC.msg(ok and ('Character Registry: '..msg) or ('Character Registry: '..tostring(msg))); end
                    imgui.SameLine(); if imgui.SmallButton('Cancel##hc_registry_cancel_small_'..r.name) then pending_remove=nil; M.invalidate(); end
                elseif imgui.SmallButton('Remove Saved Profile...##hc_registry_remove_small_'..r.name) then pending_remove=r.name; M.invalidate(); end
            end
        end
    end
    if imgui.Button('Refresh Character Registry##hc_registry_refresh') then M.invalidate(); M.snapshot(true); end
end

function M.init(ctx) HC=ctx; end
return M;
