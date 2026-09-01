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

function M.collection_item(name,owned)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    if owned==true then imgui.Text(tostring(name or '')); else imgui.TextDisabled(tostring(name or '')); end
end

function M.collection_status(owned,missing_label)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    if owned==true then imgui.Text('✓'); else imgui.TextDisabled(tostring(missing_label or '—')); end
end

function M.collection_location(location,owned)
    local imgui=HC and HC.imgui or nil; if not imgui then return; end
    if owned==true and location and tostring(location)~='' then imgui.TextDisabled(tostring(location)); else imgui.TextDisabled('—'); end
end

function M.developer_control(c,fn)
    if type(c)=='table' and type(c.settings)=='table' and c.settings.developer_mode==true and type(fn)=='function' then fn(); return true; end
    return false;
end

function M.init(ctx) HC=ctx; end
return M;
