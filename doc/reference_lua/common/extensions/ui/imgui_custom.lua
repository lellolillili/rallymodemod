-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = ffi.C -- shortcut to prevent lookups all the time

return function(M)

  M.uiscale = ffi.new('float[1]', 1)

  --default values
  M.plotLineColor = 4288453788
  M.plotLineBgColor = 2323270185

  --=== struct ImVec2 ===
  function M.ImVec2(x, y)
    local res = ffi.new("ImVec2")
    res.x = x
    res.y = y
    return res
  end

  function M.ImVec2Ptr(x, y)
    local res = ffi.new("ImVec2")
    res[0].x = x
    res[0].y = y
    return res
  end
  --===
  --=== struct ImVec4 ===
  function M.ImVec4(x, y, z, w)
    local res = ffi.new("ImVec4")
    res.x = x
    res.y = y
    res.z = z
    res.w = w
    return res
  end

  function M.ImVec4Ptr(x, y, z, w)
    local res = ffi.new("ImVec4[1]")
    res[0].x = x
    res[0].y = y
    res[0].z = z
    res[0].w = w
    return res
  end
  --===

  function M.Bool(x) return ffi.new("bool", x) end
  function M.BoolPtr(x) return ffi.new("bool[1]", x) end
  function M.CharPtr(x) return ffi.new("char[1]", x) end
  function M.Int(x) return ffi.new("int", x) end
  function M.IntPtr(x) return ffi.new("int[1]", x) end
  function M.Float(x) return ffi.new("float", x) end
  function M.FloatPtr(x) return ffi.new("float[1]", x) end
  function M.Double(x) return ffi.new("double", x) end
  function M.DoublePtr(x) return ffi.new("double[1]", x) end
  -- function M.ArrayChar(x) return ffi.new("char[?]", x) end
  function M.ArrayChar(x, val)
    if val then
      return ffi.new("char["..x.."]", val)
    else
      return ffi.new("char[?]", x)
    end
  end
  function M.ArrayInt(size) return ffi.new("int[?]", size) end
  function M.ArrayFloat(size) return ffi.new("float[?]", size) end
  function M.ArrayImVec4(size) return ffi.new("ImVec4[?]", size) end

  function M.BoolTrue() return ffi.new("bool", true) end
  function M.BoolFalse() return ffi.new("bool", false) end

  -- custom constructors
  function M.ImGuiTextFilter(default_filter)
    local res = ffi.new("ImGuiTextFilter")
    -- res.default_filter = default_filter
    return res
  end

  function M.ImGuiTextFilterPtr(default_filter)
    local res = ffi.new("ImGuiTextFilter[1]")
    -- res[0].default_filter = default_filter
    return res
  end

  function M.ImDrawList(shared_data)
    local res = ffi.new("ImDrawList")
    res.shared_data = shared_data
    return res
  end

  function M.ImDrawListPtr(shared_data)
    local res = ffi.new("ImDrawList[1]")
    res[0].shared_data = shared_data
    return res
  end

  function M.ImVec4ToFloatPtr(imVec4) return ffi.cast("float*", imVec4) end

  function M.ArrayBoolByTbl(tbl)
    local arr = ffi.new("bool[" .. #tbl .. "]")
    for i = 0, #tbl - 1 do
      arr[i] = ffi.new("bool", tbl[i+1])
    end
    return arr
  end

  function M.ArrayBoolPtrByTbl(tbl)
    local arr = ffi.new("bool*[" .. #tbl .. "]")
    for i = 0, #tbl - 1 do
      arr[i] = ffi.new("bool[1]", tbl[i+1])
    end
    return arr
  end

  function M.ArrayIntPtrByTbl(tbl)
    local arr = ffi.new("int*[" .. #tbl .. "]")
    for i = 0, #tbl - 1 do
      arr[i] = ffi.new("int[1]", tbl[i+1])
    end
    return arr
  end

  function M.ArrayFloatByTbl(tbl)
    local arr = ffi.new("float[?]", #tbl)
    for i = 1, #tbl do
      arr[i - 1] = tbl[i]
    end
    return arr
  end

  function M.ArrayFloatPtrByTbl(tbl)
    local arr = ffi.new("float*[" .. #tbl .. "]")
    for i = 1, #tbl do
      arr[i - 1] = ffi.new("float[1]", tbl[i])
    end
    return arr
  end

  function M.ImVec2(x, y)
    local res = ffi.new("ImVec2")
    res.x = x
    res.y = y
    return res
  end

  function M.ImVec2Ptr(x, y)
    local res = ffi.new("ImVec2[1]")
    res[0].x = x or 0
    res[0].y = y or 0
    return res
  end

  function M.ImVec3(x, y, z)
    local res = ffi.new("ImVec3")
    res.x = x
    res.y = y
    res.z = z
    return res
  end

  function M.ImVec3Ptr(x, y, z)
    local res = ffi.new("ImVec3[1]")
    res[0].x = x
    res[0].y = y
    res[0].z = z
    return res
  end

  function M.ImVec4(x, y, z, w)
    local res = ffi.new("ImVec4")
    res.x = x
    res.y = y
    res.z = z
    res.w = w
    return res
  end

  function M.ImVec4Ptr(x, y, z, w)
    local res = ffi.new("ImVec4[1]")
    res[0].x = x
    res[0].y = y
    res[0].z = z
    res[0].w = w
    return res
  end

  function M.ImColorByRGB(r, g, b, a)
    local res = ffi.new("ImColor")
    local sc = 1/255
    res.Value = M.ImVec4(r * sc, g * sc, b * sc, (a or 255) * sc)
    return res
  end

  function M.Begin(string_name, bool_p_open, ImGuiWindowFlags_flags)
    -- bool_p_open is optional and can be nil
    if ImGuiWindowFlags_flags == nil then ImGuiWindowFlags_flags = M.WindowFlags_NoFocusOnAppearing end
    if string_name == nil then log("E", "", "Parameter 'string_name' of function 'Begin' cannot be nil, as the c type is 'const char *'") ; return end
    return C.imgui_Begin(string_name, bool_p_open, ImGuiWindowFlags_flags)
  end

  --
  function M.InputText(label, buf, buf_size, flags, callback, user_data, editEnded)
    if not buf_size then buf_size = ffi.sizeof(buf) end
    if not flags then flags = 0 end

    return C.imgui_InputText(label, buf, buf_size, flags, callback, user_data)
  end

  function M.InputTextMultiline(label, buf, buf_size, size, flags, callback, user_data)
    if not buf_size then buf_size = ffi.sizeof(buf) end
    if not size then size = M.ImVec2(0,0) end
    if not flags then flags = 0 end

    return C.imgui_InputTextMultiline(label, buf, buf_size, size, flags, callback, user_data)
  end

  function M.Combo1(label, current_item, items, items_count, popup_max_height_in_items)
    if popup_max_height_in_items == nil then popup_max_height_in_items = -1 end
    if items_count == nil then items_count = M.GetLengthArrayCharPtr(items) end
    return C.imgui_Combo1(label, current_item, items, items_count, popup_max_height_in_items)
  end

  function M.PushFont2(index)
    return C.imgui_PushFont2(index)
  end

  function M.PushFont3(uniqueId)
    return C.imgui_PushFont3(uniqueId)
  end

  function M.TextGlyph(unicode)
    return C.imgui_TextGlyph(unicode)
  end

  function M.IoFontsGetCount()
    return C.imgui_IoFontsGetCount()
  end

  function M.IoFontsGetName(index)
    return C.imgui_IoFontsGetName(index)
  end

  function M.SetDefaultFont(index)
    return C.imgui_SetDefaultFont(index)
  end

  function M.GetImGuiIO_FontAllowUserScaling() return C.imgui_GetImGuiIO_FontAllowUserScaling() end
  function M.GetImGuiIO_FontAllowUserScaling() return C.imgui_GetImGuiIO_FontAllowUserScaling() end

  -- ImTextureHandler helper code for constructor
  local ImTextureHandler_mt = {
    __gc = function(hnd) C.imgui_ImTextureHandler_set(hnd, '') end,
    getID = function(hnd) return C.imgui_ImTextureHandler_get(hnd) end,
    setID = function(hnd, path) return C.imgui_ImTextureHandler_set(hnd, path) end,
    getSize = function(hnd) local vec2 = M.ImVec2(0, 0) C.imgui_ImTextureHandler_size(hnd, vec2) return vec2 end,
    getFormat = function(hnd) return C.imgui_ImTextureHandler_format(hnd) end,
  }
  ImTextureHandler_mt.__index = ImTextureHandler_mt

  local ImTextureHandler_constructor = ffi.metatype("ImTextureHandler", ImTextureHandler_mt)

  function M.ImTextureHandler(path)
    local res = ImTextureHandler_constructor()
    C.imgui_ImTextureHandler_set(res, path)
    return res
  end

  function M.ImTextureHandlerIsCached(path)
    return C.imgui_ImTextureHandler_isCached(path)
  end

  -- MULTIPLOT & MULTIHISTOGRAM
  function M.PlotMultiLines(label, num_datas, names, colors, datas, values_count, overlay_text, scale_min, scale_max, graph_size)
    local FFInames = M.ArrayCharPtrByTbl(names)
    local FFIcolors = ffi.new("ImColor["..tostring(num_datas).."]", colors)
    local FFiDataConv = {}
    for i=1,num_datas do
      table.insert(FFiDataConv, ffi.new('float['..tostring(values_count)..']', datas[i]))
    end
    local FFIdatas = ffi.new('float*['..tostring(num_datas)..']', FFiDataConv)
    C.imgui_PlotMultiLines(label, num_datas, FFInames, FFIcolors, FFIdatas, values_count, overlay_text, scale_min, scale_max, graph_size)
  end

  function M.PlotMultiHistograms(label, num_hists, names, colors, datas, values_count, overlay_text, scale_min, scale_max, graph_size, sumValues)
    local FFInames = M.ArrayCharPtrByTbl(names)
    local FFIcolors = ffi.new("ImColor["..tostring(num_hists).."]", colors)
    local FFiDataConv = {}
    for i=1,num_hists do
      table.insert(FFiDataConv, ffi.new('float['..tostring(values_count)..']', datas[i]))
    end
    local FFIdatas = ffi.new('float*['..tostring(num_hists)..']', FFiDataConv)
    C.imgui_PlotMultiHistograms(label, num_hists, FFInames, FFIcolors, FFIdatas, values_count, overlay_text, scale_min, scale_max, graph_size, sumValues)
  end

  function M.PlotMulti2Options_init(label,names,colors,num_format)
    local tmp = {c = ffi.new("struct PlotMulti2Options")}
    local mt = {__index = function (t, k) if k=="c" then return t.c else return t.c[k] end end,
    __newindex = function (t, key, val)
      if(key == "names") then
        rawset(t, key, val)
        t.c.names = M.ArrayCharPtrByTbl(t[key])
      elseif(key== "num_format")then
        rawset(t, key, val)
        t.c.num_format = ffi.new("int["..tostring(t.num_datas).."]",t[key])
      elseif key== "colors" then
        rawset(t, key, val)
        t.c.colors = ffi.new("ImColor["..tostring(t.num_datas).."]", t[key])
      else
        --print("set normal "..tostring(key))
        t.c[key] = val
      end
    end,
    }
    setmetatable(tmp, mt)
    tmp.label = label
    tmp.names = names
    tmp.num_datas = #names
    tmp.colors = colors
    tmp.num_format = num_format --enum PlotMulti2NumberFormat
    tmp.background_alpha = 1.0
    return tmp
  end
  function M.PlotMulti2Lines(options, datas)
    options.c.names = M.ArrayCharPtrByTbl(options.names) --Pointer become invalid just after init /shrug
    options.c.num_format = ffi.new("int["..tostring(options.num_datas).."]",options.num_format)
    options.c.colors = ffi.new("ImColor["..tostring(options.num_datas).."]", options.colors)
    local FFiDataConv = {}
    for i=1,options.num_datas do
      table.insert(FFiDataConv, ffi.new('float['..tostring(#datas[i])..']', datas[i]))
      options.values_count = #datas[i]
    end
    options.datas = ffi.new('float*['..tostring(options.num_datas)..']', FFiDataConv)
    C.imgui_PlotMulti2Lines(options.c)
  end
  M.PlotMulti2NumberFormat = {USE_FIRST_Y_AXIS = 0,
    USE_SECOND_Y_AXIS = 1,
    GRID_ENABLE = 16,
    FORMAT_NONE = 256,
    FORMAT_METRIC = 512,
    FORMAT_BYTE = 1024}

  -- HELPER
  function M.ArraySize(arr) return ffi.sizeof(arr) / ffi.sizeof(arr[0]) end
  function M.GetLengthArrayBool(array) return ffi.sizeof(array) / ffi.sizeof("bool") end
  function M.GetLengthArrayFloat(array) return ffi.sizeof(array) / ffi.sizeof("float") end
  function M.GetLengthArrayInt(array) return ffi.sizeof(array) / ffi.sizeof("int") end
  function M.GetLengthArrayCharPtr(array) return (ffi.sizeof(array) / ffi.sizeof("char*")) - 1 end
  function M.GetLengthArrayImVec4(array) return ffi.sizeof(array) / ffi.sizeof("ImVec4") end
  function M.ArrayCharPtrByTbl(tbl) return ffi.new("const char*[".. #tbl + 1 .."]", tbl) end

  -- WRAPPER
  -- Context creation and access
  function M.GetMainContext() return C.ImGui_GetMainContext() end

  function M.CreateTable(size)
    local tbl = {}
    for i = 1, size, 1 do
      tbl[i] = 0
    end
    return tbl
  end

  function M.TableToArrayFloat( tbl )
    local array = ffi.new("float[?]", tableSize(tbl))
    for k,v in pairs(tbl) do
      array[k - 1] = v
    end
    return array
  end

  -- Helper functions
    -- Imgui Helper

  function M.ShowHelpMarker(desc, sameLine)
    if sameLine == true then M.SameLine() end
    M.TextDisabled("(?)")
    if M.IsItemHovered() then
      M.BeginTooltip()
      M.PushTextWrapPos(M.GetFontSize() * 35.0)
      M.TextUnformatted(desc)
      M.PopTextWrapPos()
      M.EndTooltip()
    end
  end

  function M.tooltip(message)
    if M.IsItemHovered() then
      M.SetTooltip(message)
    end
  end

  function M.ImGuiTextFilter(default_filter)
    local res = ffi.new("ImGuiTextFilter")
    --res.default_filter = default_filter
    return res
  end

  function M.DockBuilderDockWindow(window_name, node_id) C.imgui_DockBuilderDockWindow(window_name, node_id) end

  function M.DockBuilderAddNode(node_id, ref_size, flags)
    if not flags then flags = 0 end
    C.imgui_DockBuilderAddNode(node_id, ref_size, flags)
  end

  function M.DockBuilderSplitNode(node_id, split_dir, size_ratio_for_node_at_dir, out_id_dir, out_id_other) return C.imgui_DockBuilderSplitNode(node_id, split_dir, size_ratio_for_node_at_dir, out_id_dir, out_id_other) end

  function M.DockBuilderFinish(node_id) C.imgui_DockBuilderFinish(node_id) end

  -- TextEdit below
  function M.createTextEditor() return C.imgui_createTextEditor() end
  function M.destroyTextEditor(te) C.imgui_destroyTextEditor(te) end
  function M.TextEditor_SetLanguageDefinition(te, lang)
    if lang == nil then lang = 'lua' end
    C.imgui_TextEditor_SetLanguageDefinition(te, lang)
  end

  function M.TextEditor_Render(te, title, size, border)
    if title == nil then title = 'Text Editor' end
    if size == nil then size = M.ImVec2(100,100) end
    if border == nil then border = false end
    C.imgui_TextEditor_Render(te, title, size, border)
  end

  function M.TextEditor_SetText(te, txt)
    C.imgui_TextEditor_SetText(te, txt)
  end

  function M.TextEditor_GetText(te)
    return C.imgui_TextEditor_GetText(te)
  end

  function M.TextEditor_IsTextChanged(te)
    return C.imgui_TextEditor_IsTextChanged(te)
  end

  function M.readGlobalActions()
    C.imgui_readGlobalActions()
  end

  function M.BeginDisabled(disable)
    if disable == nil then disable = true end
    C.imgui_BeginDisabled(disable)
  end

  function M.EndDisabled()
    C.imgui_EndDisabled()
  end

  function M.TextFilter_GetInputBuf(filter)
    return C.imgui_TextFilter_GetInputBuf(filter)
  end

  function M.TextFilter_SetInputBuf(filter, text)
    return C.imgui_TextFilter_SetInputBuf(filter, text)
  end

  function M.getMonitorIndex()
    return C.imgui_getMonitorIndex()
  end

  function M.getCurrentMonitorSize()
    local vec2 = M.ImVec2(0, 0)
    C.imgui_getCurrentMonitorSize(vec2)
    return vec2
  end

  function M.loadIniSettingsFromDisk(filename)
    C.imgui_LoadIniSettingsFromDisk(FS:getFileRealPath(filename))
  end

  function M.ClearActiveID()
    C.imgui_ClearActiveID()
  end

  function M.saveIniSettingsToDisk(filename)
    local filepath = getUserPath() .. filename
    C.imgui_SaveIniSettingsToDisk(filepath)
  end

  -- Wrapper function, this was removed in the latest imgui version
  function M.GetContentRegionAvailWidth()
     return M.GetContentRegionAvail().x
  end

  local matchColor = M.ImVec4(1,0.5,0,1)
  function M.HighlightText(label, highlightText)
    M.PushStyleVar2(M.StyleVar_ItemSpacing, M.ImVec2(0, 0))
    if highlightText == "" then
      M.TextColored(matchColor,label)
    else
      local pos1 = 1
      local pos2 = 0
      local labelLower = label:lower()
      local highlightLower = highlightText:lower()
      local highlightLowerLen = string.len(highlightLower) - 1
      for i = 0, 6 do -- up to 6 matches overall ...
        pos2 = labelLower:find(highlightLower, pos1, true)
        if not pos2 then
          M.Text(label:sub(pos1))
          break
        elseif pos1 < pos2 then
          M.Text(label:sub(pos1, pos2 - 1))
          M.SameLine()
        end

        local pos3 = pos2 + highlightLowerLen
        M.TextColored(matchColor, label:sub(pos2, pos3))
        M.SameLine()
        pos1 = pos3 + 1
      end
    end
    M.PopStyleVar()
  end

  function M.HighlightSelectable(label, highlightText, selected)
    local cursor = M.GetCursorPos()
    local width = M.GetContentRegionAvailWidth()
    M.BeginGroup()
    local x = M.GetCursorPosX()
    M.HighlightText(label, highlightText)
    local spacing = M.GetStyle().ItemSpacing
    M.SameLine()
    M.Dummy(M.ImVec2(width - M.GetCursorPosX(), 1))
    M.EndGroup()
    if M.IsItemHovered() then

      local itemSize = M.GetItemRectSize()
      M.ImDrawList_AddRectFilled(M.GetWindowDrawList(), M.ImVec2(cursor.x + M.GetWindowPos().x - 2,
                        cursor.y + M.GetWindowPos().y + (spacing.y/2) - 2 - M.GetScrollY()),
                        M.ImVec2(cursor.x + M.GetWindowPos().x + itemSize.x + (spacing.y/2),
                        cursor.y + M.GetWindowPos().y + itemSize.y + 2 - M.GetScrollY()),
                        M.GetColorU321(M.IsAnyMouseDown() and M.Col_HeaderActive or M.Col_HeaderHovered), 1, 1)

    elseif selected then
      local itemSize = M.GetItemRectSize()
      M.ImDrawList_AddRectFilled(M.GetWindowDrawList(), M.ImVec2(cursor.x + M.GetWindowPos().x - 2,
                        cursor.y + M.GetWindowPos().y + (spacing.y/2) - 2 - M.GetScrollY()),
                        M.ImVec2(cursor.x + M.GetWindowPos().x + itemSize.x + (spacing.y/2),
                        cursor.y + M.GetWindowPos().y + itemSize.y + 2 - M.GetScrollY()),
                        M.GetColorU321(M.Col_Header), 1, 1)
    end
  end

  local headerDefaultColor = M.ImVec4(1,0.6,0,8,0.75)
  function M.HeaderText(text, color)
    color = color or headerDefaultColor
    M.PushFont3("cairo_regular_medium")
    M.TextColored(color, text)
    M.PopFont()
  end

end -- return end add things above, not below

