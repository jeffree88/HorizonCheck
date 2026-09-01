local M={};
local HC;

function M.table_flags()
    -- BordersInnerH + BordersOuterH + BordersInnerV. Shared across HorizonCheck.
    return 64+128+512;
end

function M.window_width(imgui)
    imgui=imgui or (HC and HC.imgui); if not imgui then return 0; end
    -- Scalar API only: avoids ImVec2 `.x` access on HorizonXI builds where the
    -- value is proxied through sugar/math.lua and may raise a namespace error.
    if imgui.GetWindowWidth then
        local ok,v=pcall(imgui.GetWindowWidth); if ok then return tonumber(v) or 0; end
    end
    return 0;
end

function M.wide_enough(imgui,min_width)
    local w=M.window_width(imgui);
    return w<=0 or w>=(tonumber(min_width) or 800);
end

function M.table_supported(imgui)
    imgui=imgui or (HC and HC.imgui);
    return imgui~=nil and imgui.BeginTable~=nil and imgui.TableNextColumn~=nil and imgui.EndTable~=nil;
end

function M.section_header_action(title,subtitle,action_fn)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    imgui.Text(tostring(title or ''));
    if subtitle and tostring(subtitle)~='' then
        imgui.SameLine(); imgui.TextDisabled(tostring(subtitle));
    end
    if type(action_fn)=='function' then
        imgui.SameLine(); action_fn();
    end
    imgui.Separator();
end

function M.section_header(title,subtitle)
    return M.section_header_action(title,subtitle,nil);
end

function M.wrapped_note(text,prefix)
    local imgui=HC and HC.imgui or nil; if not imgui or text==nil or tostring(text)=='' then return; end
    imgui.TextDisabled(tostring(prefix or '')..tostring(text));
end

function M.status_row(label,value,complete)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local line=tostring(label or '')..': '..tostring(value or '');
    if complete==true then imgui.Text(line); else imgui.TextDisabled(line); end
end

function M.responsive_two_column(id,left_fn,right_fn,min_width)
    local imgui=HC and HC.imgui or nil; if not imgui then return false; end
    if M.table_supported(imgui) and M.wide_enough(imgui,min_width or 820) and imgui.BeginTable(tostring(id),2,M.table_flags()) then
        imgui.TableNextColumn(); left_fn();
        imgui.TableNextColumn(); right_fn();
        imgui.EndTable();
        return true;
    end
    left_fn(); imgui.Spacing();
    right_fn();
    return false;
end

function M.collapsing_section(label,id,default_open,body_fn)
    local imgui=HC and HC.imgui or nil; if not imgui then return false; end
    local flags=default_open==true and (rawget(_G,'ImGuiTreeNodeFlags_DefaultOpen') or 0) or 0;
    if imgui.CollapsingHeader(tostring(label)..'##'..tostring(id or label),flags) then
        if type(body_fn)=='function' then body_fn(); end
        return true;
    end
    return false;
end

function M.progress_label(label,done,total)
    done=tonumber(done) or 0; total=tonumber(total) or 0;
    return string.format('%s - %d/%d%s',tostring(label or ''),done,total,(total>0 and done>=total) and ' - COMPLETE' or '');
end

function M.simple_table(id,columns,rows,min_width)
    local imgui=HC and HC.imgui or nil; if not imgui or type(columns)~='table' or type(rows)~='table' then return false; end
    if not M.table_supported(imgui) or not M.wide_enough(imgui,min_width or 620) then return false; end
    if not imgui.BeginTable(tostring(id),#columns,M.table_flags()) then return false; end
    if imgui.TableSetupColumn and imgui.TableHeadersRow then
        for _,col in ipairs(columns) do imgui.TableSetupColumn(tostring(col.label or col[1] or col),0,tonumber(col.width or col[2]) or 0); end
        imgui.TableHeadersRow();
    end
    for _,row in ipairs(rows) do
        if imgui.TableNextRow then imgui.TableNextRow(); end
        for i=1,#columns do
            if imgui.TableSetColumnIndex then imgui.TableSetColumnIndex(i-1); else imgui.TableNextColumn(); end
            local v=row[i]; if type(v)=='function' then v(); elseif row.complete==true then imgui.Text(tostring(v or '')); else imgui.TextDisabled(tostring(v or '')); end
        end
    end
    imgui.EndTable(); return true;
end

function M.collection_item(name,state)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local m=M.status_meta(state,{checkmark=false});
    if m.bright then imgui.Text(tostring(name or '')); else imgui.TextDisabled(tostring(name or '')); end
end

function M.collection_status(state,missing_label)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    if type(state)=='boolean' then
        if state==true then imgui.Text('✓ OWNED'); else imgui.TextDisabled(tostring(missing_label or 'MISSING')); end
        return;
    end
    return M.draw_status(state,{label=(state and tostring(state) or tostring(missing_label or 'MISSING'))});
end

function M.collection_location(location,state)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local m=M.status_meta(state,{checkmark=false});
    if m.complete and location and tostring(location)~='' and tostring(location)~='—' then imgui.TextDisabled(tostring(location)); else imgui.TextDisabled('—'); end
end

-- Unified status/freshness vocabulary. Trackers may keep their own raw
-- lifecycle states, but normal collection/status tables render through this
-- small shared vocabulary so OWNED / AVAILABLE / LOCKED / MISSING / etc. look
-- and behave consistently across HorizonCheck.
local STATUS_ALIASES={
    ['CLEARED']='COMPLETE',['DONE']='COMPLETE',['VERIFIED']='COMPLETE',
    ['HELD']='OWNED',['OBTAINED']='OWNED',
    ['NEXT']='READY',['IN PROGRESS']='ACTIVE',['ACCEPTED']='ACTIVE',
    ['NEED']='MISSING',['NEEDED']='MISSING',['NOT OWNED']='MISSING',
    ['UNKNOWN']='CHECKING',['CHECK']='CHECKING',['VERIFY']='CHECKING',
    ['POOL EMPTY']='LOCKED',['FAILED']='LOCKED',
};

function M.normalize_status(state,opts)
    opts=type(opts)=='table' and opts or {};
    if type(state)=='boolean' then return state and 'OWNED' or tostring(opts.false_state or 'MISSING'); end
    local s=string.upper(tostring(state or opts.default or 'CHECKING'));
    s=STATUS_ALIASES[s] or s;
    if s:find('^NEED ') then return 'MISSING'; end
    if s=='NEED CARD' or s=='NEED CHIP' or s=='NEED CLEANSE' then return 'MISSING'; end
    return s;
end

function M.status_meta(state,opts)
    opts=type(opts)=='table' and opts or {};
    local s=M.normalize_status(state,opts);
    local label=tostring(opts.label or s);
    local bright=(s=='OWNED' or s=='COMPLETE' or s=='AVAILABLE' or s=='AFFORDABLE' or s=='ACTIVE' or s=='READY' or s=='NOT NEEDED');
    local complete=(s=='OWNED' or s=='COMPLETE' or s=='NOT NEEDED');
    local prefix=(complete and opts.checkmark~=false) and '✓ ' or '';
    return {state=s,label=prefix..label,bright=bright,complete=complete};
end

function M.draw_status(state,opts)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local m=M.status_meta(state,opts);
    if m.bright then imgui.Text(m.label); else imgui.TextDisabled(m.label); end
    return m;
end

function M.data_freshness(kind,opts)
    opts=type(opts)=='table' and opts or {};
    kind=string.lower(tostring(kind or 'saved'));
    if kind=='permanent' then return {state='PERMANENT',label='Permanent',bright=true}; end
    if opts.current==true then return {state='LIVE',label='Live',bright=true}; end
    if opts.cycle_valid==false then return {state='EXPIRED',label='Reset',bright=false}; end
    local at=tonumber(opts.last_seen_at);
    if not at then return {state='UNKNOWN',label='No saved data',bright=false}; end
    local age=math.max(0,os.time()-at);
    local age_label;
    if age<120 then age_label='just now';
    elseif age<3600 then age_label=tostring(math.floor(age/60))..'m ago';
    elseif age<86400 then age_label=tostring(math.floor(age/3600))..'h ago';
    else age_label=tostring(math.floor(age/86400))..'d ago'; end
    return {state='SAVED',label='Saved '..age_label,bright=age<3600,age=age};
end

function M.data_badge(kind,opts)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    local f=M.data_freshness(kind,opts);
    if f.bright then imgui.Text(tostring(f.label)); else imgui.TextDisabled(tostring(f.label)); end
    return f;
end

function M.developer_control(c,fn)
    if type(c)=='table' and type(c.settings)=='table' and c.settings.developer_mode==true and type(fn)=='function' then fn(); return true; end
    return false;
end

function M.init(ctx) HC=ctx; end
return M;
