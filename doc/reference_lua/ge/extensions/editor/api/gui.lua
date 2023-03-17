-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local editor
local ffi = require('ffi')
local imgui = ui_imgui
local imguiUtils = require('ui/imguiUtils')

local logTag = "gui.lua"

local displaySize
local atlas
local atlasPath = "/core/art/gui/images/iconAtlas.png"
local atlasJsonPath = "/core/art/gui/images/iconAtlas.json"
local windowsStateFileName = "settings/editor/windowsState.json"
local iconsTex = nil
local icon_width = 48
local icon_height = 48
local canvasObject
local dockOpen = imgui.BoolPtr(true)
local windowsState = {}
local fileDialogContexts = {}
local windowVisibleStack = {} -- used for beginWindow/endWindow
local modalWindowVisibleStack = {} -- used for beginModalWindow/endModalWindow
local defaultIconButtonSize = imgui.ImVec2(32, 32)
local WindowsStateFileFormatVersion = 1

--- Returns a table with the loaded texture information
-- @param path the path to a texture image
local function texObj(path)
  local res = {}
  res.file = string.match(path, "^.+/(.+)$")
  res.path = path
  res.tex = imgui.ImTextureHandler(path)
  if not res.tex then return nil end
  res.texId = res.tex:getID()
  res.size = res.tex:getSize()
  res.format = ffi.string(res.tex:getFormat())
  return res
end

local function getFileName(path, withoutExtension)
  local filename = path:match("^.+/(.+)$")
  if withoutExtension then
    filename = string.sub(filename, 1, #filename - 4)
  end
  filename = filename:gsub("%s+", "")
  return filename
end

local function setDefaultIconButtonSize(size)
  defaultIconButtonSize = imgui.ImVec2(size, size)
end

--- Load and create the editor icon texture atlas. It also creates the editor.icons table with all the icons.
local function createIconAtlas()
  -- the icon atlas is generated from svg files by the jenkins tools
  -- for devs: the material and editor icons are found in gitlab/beamng.ui/content.icons/tree/master/src/Sprites
  editor.icons = {}

  local atlasInfo = jsonReadFile(atlasJsonPath)
  editor.icons = atlasInfo.icons
  local iconsCount = tableSize(editor.icons)

  if atlasInfo.iconDuplicates then
    editor.logError("Duplicate editor icons: " .. tostring(atlasInfo.iconDuplicates))
  end

  local iconsPerRow = atlasInfo.atlasWidth / icon_width
  local iconsPerCol = atlasInfo.atlasHeight / icon_height
  editor.atlasWidth = atlasInfo.atlasWidth
  editor.atlasHeight = atlasInfo.atlasHeight
  atlas = GBitmap()
  if atlas then
    atlas:init(editor.atlasWidth, editor.atlasHeight, true)
    atlas:loadFile(atlasPath)
    iconsTex = imguiUtils.texObj(atlasPath)
  else
    editor.logError("Cannot create GBitmap for icon atlas")
  end
end

local function uiTextUnformattedRightAlign(string_label, bool_sameLine, offset)
  if not string_label then return end
  if bool_sameLine == true then
    imgui.SameLine()
  end
  imgui.SetCursorPosX(imgui.GetCursorPosX() + imgui.GetContentRegionAvailWidth() - imgui.CalcTextSize(string_label).x + ((offset) and offset or 0))
  imgui.TextUnformatted(string_label)
end

local function uiTextColoredWithFont(color, text, fontName)
  imgui.PushFont3(fontName)
  if not color then
    imgui.Text(text)
  else
    imgui.TextColored(color or imgui.GetStyleColorVec4(imgui.Col_Text), text)
  end
  imgui.PopFont()
end

local function uiButtonRightAlign(string_label, ImVec2_size, bool_sameLine, id, offset)
  if not string_label then return end
  if bool_sameLine == true then
    imgui.SameLine()
  end
  imgui.SetCursorPosX(imgui.GetCursorPosX() + imgui.GetContentRegionAvailWidth() - ((ImVec2_size and ImVec2_size.x > 0) and ImVec2_size.x or (imgui.CalcTextSize(string_label).x +  2*imgui.GetStyle().FramePadding.x)) + ((offset) and offset or 0))
  if imgui.Button((id) and string_label .. "##" .. id or string_label, ImVec2_size) then
    return true
  end
end

--- Draw an icon image widget.
local function uiIconImage(icon, size, col, borderCol, label)
  if not size then size = imgui.ImVec2(32 * imgui.uiscale[0], 32 * imgui.uiscale[0]) else size = imgui.ImVec2(size.x * imgui.uiscale[0], size.y * imgui.uiscale[0]) end
  if not col then col = imgui.GetStyleColorVec4(imgui.Col_Text) end
  --if not borderCol then borderCol = imgui.GetStyleColorVec4(imgui.Col_Border) end
  local ux = icon.x / editor.atlasWidth
  local uy = icon.y / editor.atlasHeight
  local vx = (icon.x + icon_width) / editor.atlasWidth
  local vy = (icon.y + icon_height) / editor.atlasHeight
  if imgui.Image(iconsTex.texId, size, imgui.ImVec2(ux, uy), imgui.ImVec2(vx, vy), col, borderCol) then return true end
  if label then imgui.SameLine() imgui.Text(label) end
end

local textHighlightColor = imgui.ImVec4(1, 1, 0, 1)

local function uiHighlightedText(text, highlightText, textColor)
  if not textColor then textColor = imgui.GetStyleColorVec4(imgui.Col_Text) end
  if highlightText and highlightText ~= '' then
    imgui.BeginGroup()
    imgui.PushStyleVar2(imgui.StyleVar_ItemSpacing, imgui.ImVec2(0, 0))
    local pos1 = 1
    local pos2 = 0
    local textLower = text:lower()
    local highlightLower = highlightText:lower()
    local highlightLowerLen = string.len(highlightLower) - 1
    for i = 0, 6 do -- up to 6 matches overall ...
      pos2 = textLower:find(highlightLower, pos1, true)
      if not pos2 then
        imgui.TextColored(textColor, text:sub(pos1))
        break
      elseif pos1 < pos2 then
        imgui.TextColored(textColor, text:sub(pos1, pos2 - 1))
        imgui.SameLine()
      end

      local pos3 = pos2 + highlightLowerLen
      imgui.TextColored(textHighlightColor, text:sub(pos2, pos3))
      imgui.SameLine()
      pos1 = pos3 + 1
    end
    imgui.PopStyleVar()
    imgui.EndGroup()
  else
    imgui.TextColored(textColor, text)
  end
end

--- Draw an icon image button widget.
local function uiIconImageButton(icon, size, col, label, backgroundCol, id, textColor, textBG, onRelease, highlightText)
  if not size then size = defaultIconButtonSize end
  if not col then col = imgui.GetStyleColorVec4(imgui.Col_Text) end
  if not backgroundCol then backgroundCol = imgui.GetStyleColorVec4(imgui.Col_Button) end
  local ux = icon.x / editor.atlasWidth
  local uy = icon.y / editor.atlasHeight
  local vx = (icon.x + icon_width) / editor.atlasWidth
  local vy = (icon.y + icon_height) / editor.atlasHeight
  if label then
    imgui.BeginGroup()
    uiIconImage(icon, size, col)
    imgui.SameLine()
    if textBG then
      local textSize = imgui.CalcTextSize(label)
      local topLeft = imgui.GetCursorScreenPos()
      local bottomRight = imgui.ImVec2(topLeft.x + textSize.x, topLeft.y + textSize.y)
      imgui.ImDrawList_AddRectFilled(imgui.GetWindowDrawList(), topLeft, bottomRight, textBG, 0, nil)
    end

    uiHighlightedText(label, highlightText, textColor)
    imgui.EndGroup()
    if onRelease then
      if imgui.IsItemHovered() and imgui.IsMouseReleased(0) and not imgui.IsMouseDragging(0) then
        return true
      end
    else
      if imgui.IsItemClicked(0) then return true end
    end
  else
    size = imgui.ImVec2(size.x * imgui.uiscale[0], size.y * imgui.uiscale[0])
    if id then imgui.PushID1(id) end
    imgui.ImageButton(iconsTex.texId, size, imgui.ImVec2(ux, uy), imgui.ImVec2(vx, vy), 0, backgroundCol, col)
    if id then imgui.PopID() end
    if onRelease then
      if imgui.IsItemHovered() and imgui.IsMouseReleased(0) and not imgui.IsMouseDragging(0) then
        return true
      end
    else
      if imgui.IsItemClicked(0) then return true end
    end
  end
  return false
end

--- Show the visibility helper tool window.
local function showVizHelperWindow()
  if editor_vizHelper then
    editor_vizHelper.openWindow()
  end
end

local function uiVertSeparator(float_height, vec2_offset, width)
  imgui.SameLine()
  local winPos = imgui.GetWindowPos()
  local cursor = imgui.GetCursorPos()
  imgui.ImDrawList_AddLine(
    imgui.GetWindowDrawList(),
    (vec2_offset and imgui.ImVec2(winPos.x + cursor.x + vec2_offset.x, winPos.y + cursor.y + vec2_offset.y) or imgui.ImVec2(winPos.x + cursor.x, winPos.y + cursor.y)),
    (vec2_offset and imgui.ImVec2(winPos.x + cursor.x + vec2_offset.x, winPos.y + cursor.y + imgui.uiscale[0] * (float_height or imgui.GetFontSize()) + vec2_offset.y) or imgui.ImVec2(winPos.x + cursor.x, winPos.y + cursor.y + imgui.uiscale[0] * (float_height or imgui.GetFontSize()))),
    imgui.GetColorU321(imgui.Col_Separator),
    width or 1
  )
  imgui.SetCursorPosX(cursor.x + (1 + imgui.GetStyle().ItemSpacing.x))
end

local function drawBrushSolidEdgeEllipse(pos, fromPoint, toPoint, color)
  local fromOffsetted = fromPoint + vec3(vec3(pos.x, pos.y, fromPoint.z) - fromPoint):normalized() * editor.getPreference("gizmos.brush.marginSize")
  local toOffsetted = toPoint + vec3(vec3(pos.x, pos.y, toPoint.z) - toPoint):normalized() * editor.getPreference("gizmos.brush.marginSize")
  debugDrawer:drawQuadSolid(fromPoint, fromOffsetted, toOffsetted, toPoint, color)
end

local function drawBrushSolidEdgeBox(fromPoint, toPoint, offset, color)
  local fromOffsetted = fromPoint + offset * editor.getPreference("gizmos.brush.marginSize")
  local toOffsetted = toPoint + offset * editor.getPreference("gizmos.brush.marginSize")
  -- reverse to keep backface cull off
  debugDrawer:drawQuadSolid(toPoint, toOffsetted, fromOffsetted, fromPoint, color)
end

-- TODO: move this to gizmo.lua
local xVec = vec3(1, 0, 0)
local yVec = vec3(0, 1, 0)
local negXVec = -xVec
local negYVec = -yVec

local function drawBrush(brushType, pos, radius, numberOfSegments, color, terrainBlock, brushRatio, brushRotation, onlyTerrain)
  if not pos then return end
  if not radius then return end
  if not numberOfSegments then numberOfSegments = 128 end
  if not color then color = ColorF(1, 1, 1, 1) end
  if not brushRatio then brushRatio = 1 end
  if not brushRotation then brushRotation = 0 end
  if brushType == 'ellipse' then
    for i=0, numberOfSegments-1, 1 do
      local fromPoint = vec3(
        pos.x + radius * ((brushRatio > 1) and  (2-brushRatio) or 1) * math.cos(i/numberOfSegments * 2 * math.pi + brushRotation/180*math.pi),
        pos.y + radius * ((brushRatio < 1) and brushRatio or 1) * math.sin(i/numberOfSegments * 2 * math.pi + brushRotation/180*math.pi),
        pos.z + 0.1
      )
      local toPoint = vec3(
        pos.x + radius * ((brushRatio > 1) and (2-brushRatio) or 1) * math.cos((i+1)/numberOfSegments* 2 * math.pi + brushRotation/180*math.pi),
        pos.y + radius * ((brushRatio < 1) and brushRatio or 1) * math.sin((i+1)/numberOfSegments* 2 * math.pi + brushRotation/180*math.pi),
        pos.z + 0.1
      )
      if onlyTerrain then
        if terrainBlock then
          fromPoint.z = terrainBlock:getHeight(vec3(fromPoint.x,fromPoint.y,0)) + 0.1
          toPoint.z = terrainBlock:getHeight(vec3(toPoint.x,toPoint.y,0)) + 0.1
        end
      else
        local rayStart = fromPoint
        rayStart.z = rayStart.z + radius
        local rayDir = vec3(0,0,-1)
        local rayDist = castRayStatic(rayStart, rayDir, radius*2)
        if rayDist < radius*2 then
          fromPoint.z = rayStart.z - rayDist + 0.1
        end

        local rayStart = toPoint
        rayStart.z = rayStart.z + radius
        local rayDist = castRayStatic(rayStart, rayDir, radius*2)
        if rayDist < radius*2 then
          toPoint.z = rayStart.z - rayDist + 0.1
        end
      end
      drawBrushSolidEdgeEllipse(pos, fromPoint, toPoint, color)
    end
  elseif brushType == 'box' then
    local line1 = {}
    profilerPushEvent("brush segments")
    for i = 0, numberOfSegments, 1 do
      table.insert(line1, vec3(
        pos.x - radius,
        pos.y - radius + (i*2*radius/numberOfSegments),
        pos.z + 0.1
      ))
    end
    local line2 = {}
    for i = 0, numberOfSegments, 1 do
      table.insert(line2, vec3(
        pos.x - radius + (i*2*radius/numberOfSegments),
        pos.y + radius,
        pos.z + 0.1
      ))
    end
    local line3 = {}
    for i = 0, numberOfSegments, 1 do
      table.insert(line3, vec3(
        pos.x + radius,
        pos.y + radius - (i*2*radius/numberOfSegments),
        pos.z + 0.1
      ))
    end
    local line4 = {}
    for i = 0, numberOfSegments, 1 do
      table.insert(line4, vec3(
        pos.x + radius - (i*2*radius/numberOfSegments),
        pos.y - radius,
        pos.z + 0.1
      ))
    end
    profilerPopEvent("brush segments")
    profilerPushEvent("brush terrainBlock")
    if terrainBlock then
      for k,v in ipairs(line1) do
        v.z = terrainBlock:getHeight(vec3(v.x,v.y,0)) + 0.1
      end
      for k,v in ipairs(line2) do
        v.z = terrainBlock:getHeight(vec3(v.x,v.y,0)) + 0.1
      end
      for k,v in ipairs(line3) do
        v.z = terrainBlock:getHeight(vec3(v.x,v.y,0)) + 0.1
      end
      for k,v in ipairs(line4) do
        v.z = terrainBlock:getHeight(vec3(v.x,v.y,0)) + 0.1
      end
    end
    profilerPopEvent("brush terrainBlock")
    profilerPushEvent("brush edgebox")
    for i=1, #line1-1, 1 do
      drawBrushSolidEdgeBox(line1[i], line1[i+1], xVec, color)
    end
    for i=1, #line2-1, 1 do
      drawBrushSolidEdgeBox(line2[i], line2[i+1], negYVec, color)
    end
    for i=1, #line3-1, 1 do
      drawBrushSolidEdgeBox(line3[i], line3[i+1], negXVec, color)
    end
    for i=1, #line4-1, 1 do
      drawBrushSolidEdgeBox(line4[i], line4[i+1], yVec, color)
    end
    profilerPopEvent("brush edgebox")
  end
end

local function windowResized(size)
  -- check if windows are out of bounds and move them accordingly
  --[[
    -- TODO: FIXME
  local i = 0
  while imgui.GetWindow(i) ~= nil do
    local window = imgui.GetWindow(i)
    if window[0].Pos.x < 0 then window[0].Pos.x = 0 end
    if window[0].Pos.y < 0 then window[0].Pos.y = 0 end
    if window[0].Pos.x + window[0].Size.x > size.x then window[0].Pos.x = size.x - window[0].Size.x end
    if window[0].Pos.y + window[0].Size.y > size.y  then window[0].Pos.y = size.y - window[0].Size.y end
    i = i + 1
  end
  --]]
end

--- Check if the main window got resized. It will call extensions hook onWindowResized with the new size as imgui ImVec2 as parameter.
local function checkWindowResize()
  local imguiIO = imgui.GetIO()
  if not displaySize then displaySize = {x=imguiIO.DisplaySize.x, y=imguiIO.DisplaySize.y} end

  if displaySize.x ~= imguiIO.DisplaySize.x or displaySize.y ~= imguiIO.DisplaySize.y then
    extensions.hook("onWindowResized", imguiIO.DisplaySize)
    windowResized(imguiIO.DisplaySize)
  end
  displaySize = {x=imguiIO.DisplaySize.x, y=imguiIO.DisplaySize.y}
end

--- Returns true if the 3D game viewport is hovered only.
local function isViewportHovered()
  return not (imgui.IsAnyItemHovered() or imgui.IsWindowHovered(imgui.HoveredFlags_AnyWindow))
end

local function isViewportFocused()
  return not imgui.IsAnyItemActive()
end

--- Used by editor, present the entire editor UI
local function presentGui(dtReal, dtSim, dtRaw)
  -- enable the dockspace
  local io = imgui.GetIO()

  if bit.band(io.ConfigFlags, imgui.ConfigFlags_DockingEnable) ~= 0 then
    -- this adds a transparent window we can dock into
    local viewport = imgui.GetMainViewport()
    imgui.SetNextWindowPos(viewport.Pos);
    imgui.SetNextWindowSize(viewport.Size);
    imgui.SetNextWindowViewport(viewport.ID);
    imgui.PushStyleVar1(imgui.StyleVar_WindowRounding, 0)
    imgui.PushStyleVar1(imgui.StyleVar_WindowBorderSize, 0)
    imgui.PushStyleVar2(imgui.StyleVar_WindowPadding, imgui.ImVec2(0, 0))
    local window_flags = bit.bor(imgui.WindowFlags_MenuBar, imgui.WindowFlags_NoDocking, imgui.WindowFlags_NoTitleBar, imgui.WindowFlags_NoCollapse, imgui.WindowFlags_NoResize, imgui.WindowFlags_NoMove, imgui.WindowFlags_NoBringToFrontOnFocus, imgui.WindowFlags_NoNavFocus, imgui.WindowFlags_NoBackground, imgui.WindowFlags_NoFocusOnAppearing)
    imgui.Begin("MainDockSpace", dockOpen, window_flags);
    imgui.PopStyleVar(3)
    -- init the dockspace
    imgui.DockSpace(imgui.GetID1("MainDockspace1"), imgui.ImVec2(0, 0), imgui.DockNodeFlags_PassthruCentralNode)
    imgui.End()
  end

  extensions.hook("onEditorGuiMainMenu")
  extensions.hook("onEditorGuiToolBar")
  extensions.hook("onEditorGui", dtReal, dtSim, dtRaw)
  extensions.hook("onEditorGuiStatusBar")
  checkWindowResize()
end

local function screenToClient(pt2i)
  --TODO: remove any Canvas usage, maybe use imgui
  if not canvasObject then canvasObject = scenetree.findObject("Canvas") end
  return canvasObject:screenToClient(pt2i)
end

-----------------------
-- Editing Wrappers
-----------------------
local function uiDragFloat(label, v, v_speed, v_min, v_max, format, flags, editEnded)
  local res = imgui.DragFloat(label, v, v_speed, v_min, v_max, format, flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiDragFloat2(label, v, v_speed, v_min, v_max, format, flags, editEnded)
  local res = imgui.DragFloat2(label, v, v_speed, v_min, v_max, format, flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiDragFloat3(label, v, v_speed, v_min, v_max, format, flags, editEnded)
  local res = imgui.DragFloat3(label, v, v_speed, v_min, v_max, format, flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiDragFloat4(label, v, v_speed, v_min, v_max, format, flags, editEnded)
  local res = imgui.DragFloat4(label, v, v_speed, v_min, v_max, format, flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiDragFloatRange2(label, v_current_min, v_current_max, v_speed, v_min, v_max, format, format_max, flags, editEnded)
  local res = imgui.DragFloatRange2(label, v_current_min, v_current_max, v_speed, v_min, v_max, format, format_max, flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiDragInt(label, v, v_speed, v_min, v_max, format, flags, editEnded)
  local res = imgui.DragInt(label, v, v_speed, v_min, v_max, format, flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiDragInt2(label, v, v_speed, v_min, v_max, format, flags, editEnded)
  local res = imgui.DragInt2(label, v, v_speed, v_min, v_max, format, flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiDragInt3(label, v, v_speed, v_min, v_max, format, flags, editEnded)
  local res = imgui.DragInt3(label, v, v_speed, v_min, v_max, format, flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiDragInt4(label, v, v_speed, v_min, v_max, format, flags, editEnded)
  local res = imgui.DragInt4(label, v, v_speed, v_min, v_max, format, flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiDragIntRange2(label, v_current_min, v_current_max, v_speed, v_min, v_max, format, format_max, flags, editEnded)
  local res = imgui.DragIntRange2(label, v_current_min, v_current_max, v_speed, v_min, v_max, format, format_max, flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiDragScalar(label, data_type, v, v_speed, v_min, v_max, format, flags, editEnded)
  local res = imgui.DragScalar(label, data_type, v, v_speed, v_min, v_max, format, flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiDragScalarN(label, data_type, v, components, v_speed, v_min, v_max, format, flags, editEnded)
  local res = imgui.DragScalarN(label, data_type, v, components, v_speed, v_min, v_max, format, flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end

-- Widgets: Input with Keyboard
local function uiInputText(label, buf, buf_size, flags, callback, user_data, editEnded)
  local res =  imgui.InputText(label, buf, buf_size, flags, callback, user_data)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiInputTextMultiline(label, buf, buf_size, size, flags, callback, user_data, editEnded)
  local res =  imgui.InputTextMultiline(label, buf, buf_size, size, flags, callback, user_data)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiInputTextMultilineReadOnly(label, buf, size, flags, callback, user_data, editEnded)
  local res =  imgui.InputTextMultilineReadOnly(label, buf, size, flags, callback, user_data)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiInputFloat(label, v, step, step_fast, format, extra_flags, editEnded)
  if not extra_flags then extra_flags = imgui.InputTextFlags_None end
  local res =  imgui.InputFloat(label, v, step, step_fast, format, extra_flags)
  if editEnded then
    if bit.band(extra_flags, imgui.InputTextFlags_EnterReturnsTrue) ~= 0 then
      editEnded[0] = imgui.IsItemDeactivatedAfterEdit() or res
    else
      editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
    end
  end
  return res
end
local function uiInputFloat2(label, v, format, extra_flags, editEnded)
  local res =  imgui.InputFloat2(label, v, format, extra_flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiInputFloat3(label, v, format, extra_flags, editEnded)
  local res =  imgui.InputFloat3(label, v, format, extra_flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiInputFloat4(label, v, format, extra_flags, editEnded)
  local res =  imgui.InputFloat4(label, v, format, extra_flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiInputInt(label, v, step, step_fast, extra_flags, editEnded)
  if not extra_flags then extra_flags = imgui.InputTextFlags_None end
  local res =  imgui.InputInt(label, v, step, step_fast, extra_flags)
  if editEnded then
    if bit.band(extra_flags, imgui.InputTextFlags_EnterReturnsTrue) ~= 0 then
      editEnded[0] = imgui.IsItemDeactivatedAfterEdit() or res
    else
      editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
    end
  end
  return res
end
local function uiInputInt2(label, v, extra_flags, editEnded)
  local res =  imgui.InputInt2(label, v, extra_flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiInputInt3(label, v, extra_flags, editEnded)
  local res =  imgui.InputInt3(label, v, extra_flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiInputInt4(label, v, extra_flags, editEnded)
  local res =  imgui.InputInt4(label, v, extra_flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiInputDouble(label, v, step, step_fast, format, extra_flags, editEnded)
  local res =  imgui.InputDouble(label, v, step, step_fast, format or "%.6f", extra_flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiInputScalar(label, data_type, v, step, step_fast, format, extra_flags, editEnded)
  local res =  imgui.InputScalar(label, data_type, v, step, step_fast, format, extra_flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiInputScalarN(label, data_type, v, components, step, step_fast, format, extra_flags, editEnded)
  local res =  imgui.InputScalarN(label, data_type, v, components, step, step_fast, format, extra_flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiInputSearch(label, text, width, extra_flags, editEnded)
  local style = imgui.GetStyle()
  local dispErase = ffi.string(text):len() > 0
  local uiScale = ui_imgui.GetIO().FontGlobalScale --editor.getPreference("ui.general.scale")
  local imgsize = (imgui.CalcTextSize("yes").y + style.FramePadding.y * 2)
  imgui.BeginChild1("", imgui.ImVec2(width, imgsize), false)
  local frame = imgui.GetStyleColorVec4(imgui.Col_FrameBg)
  local bgcol = imgui.ImVec4(frame.x, frame.y, frame.z, frame.w)
  bgcol.w = bgcol.w * 0.6 --because of reasons
  imgui.PushStyleColor2(imgui.Col_Button, bgcol)
  imgui.PushStyleVar2(imgui.StyleVar_ItemSpacing,imgui.ImVec2(0, 0))
  local res = editor.uiIconImageButton(editor.icons.search, {x=imgsize/ uiScale, y=imgsize/ uiScale})
  imgui.SameLine()
  if label and label ~= "" then
    imgui.tooltip(label)
  end
  imgui.PushItemWidth(width- imgsize*(dispErase and 2 or 1))
  local txtres = imgui.InputText("##" .. (label or ""), text, extra_flags)
  imgui.SameLine()
  if dispErase and editor.uiIconImageButton(editor.icons.close, {x=imgsize/ uiScale, y=imgsize/ uiScale}) then --editor.icons.backspace
    ffi.copy(text, "")
    res = true
  end
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  imgui.PopStyleVar()
  imgui.PopStyleColor()
  imgui.EndChild()
  return res or txtres
end

local function uiInputSearchTextFilter(label, txtfilter, width, extra_flags, editEnded)
  local text = imgui.ArrayChar(256, ffi.string(imgui.TextFilter_GetInputBuf(txtfilter)))
  local r = uiInputSearch(label, text, width, extra_flags, editEnded)
  if r then
    imgui.TextFilter_SetInputBuf(txtfilter, ffi.string(text))
    imgui.ImGuiTextFilter_Build(txtfilter)
  end
  return r
end

-- Widgets: Sliders
local function uiSliderFloat(label, v, v_min, v_max, format, power, editEnded)
  local res = imgui.SliderFloat(label, v, v_min, v_max, format, power)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiSliderFloat2(label, v, v_min, v_max, format, power, editEnded)
  local res = imgui.SliderFloat2(label, v, v_min, v_max, format, power)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiSliderFloat3(label, v, v_min, v_max, format, power, editEnded)
  local res = imgui.SliderFloat3(label, v, v_min, v_max, format, power)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiSliderFloat4(label, v, v_min, v_max, format, power, editEnded)
  local res = imgui.SliderFloat4(label, v, v_min, v_max, format, power)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiSliderAngle(label, v_rad, v_degrees_min, v_degrees_max, editEnded)
  local res = imgui.SliderAngle(label, v_rad, v_degrees_min or -360.0, v_degrees_max or 360.0)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiSliderInt(label, v, v_min, v_max, format, editEnded)
  local res =  imgui.SliderInt(label, v, v_min, v_max, format)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiSliderInt2(label, v, v_min, v_max, format, editEnded)
  local res =  imgui.SliderInt2(label, v, v_min, v_max, format)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiSliderInt3(label, v, v_min, v_max, format, editEnded)
  local res =  imgui.SliderInt3(label, v, v_min, v_max, format)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiSliderInt4(label, v, v_min, v_max, format, editEnded)
  local res =  imgui.SliderInt4(label, v, v_min, v_max, format)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiSliderScalar(label, data_type, v, v_min, v_max, format, power, editEnded)
  local res = imgui.SliderScalar(label, data_type, v, v_min, v_max, format, power)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiSliderScalarN(label, data_type, v, components, v_min, v_max, format, power, editEnded)
  local res = imgui.SliderScalarN(label, data_type, v, components, v_min, v_max, format, power)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiVSliderFloat(label, size, v, v_min, v_max, format, power, editEnded)
  local res = imgui.VSliderFloat(label, size, v, v_min, v_max, format, power)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiVSliderInt(label, size, v, v_min, v_max, format, editEnded)
  local res = imgui.VSliderInt(label, size, v, v_min, v_max, format)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiVSliderScalar(label, size, data_type, v, v_min, v_max, format, power, editEnded)
  local res = imgui.VSliderScalar(label, size, data_type, v, v_min, v_max, format, power)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end

-- Widgets: Color Editor/Picker
local function uiColorEdit3(label, col, flags, editEnded)
  local res = imgui.ColorEdit3(label, col, flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiColorEdit4(label, col, flags, editEnded)
  local res = imgui.ColorEdit4(label, col, flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end

local function uiColorEdit8(label, col, flags, editEnded)
  if imgui.ColorButton(label..'clrButton', imgui.ImVec4(col.clr[0], col.clr[1], col.clr[2], col.clr[3]), flags) then
    imgui.OpenPopup(label..'##colorEdit8')
  end
  imgui.Button(string.format("Metal: %0.1f | Rough: %0.1f | Coat: %0.1f | CoatRough: %0.1f", col.pbr[1][0], col.pbr[2][0], col.pbr[3][0], col.pbr[4][0]))
  if imgui.IsItemClicked() then
    imgui.OpenPopup(label..'##colorEdit8')
  end

  if imgui.BeginPopup(label..'##colorEdit8') then
    editor.uiColorPicker4(label, col.clr, flags, nil, editEnded)
    if editEnded then editEnded[0] = editEnded[0] or imgui.IsItemDeactivatedAfterEdit() end

    uiSliderFloat(label..'##clrMetallic', col.pbr[1], 0, 1, "Metallic: %0.3f", nil)
    if editEnded then editEnded[0] = editEnded[0] or imgui.IsItemDeactivatedAfterEdit() end
    uiSliderFloat(label..'##clrRoughness', col.pbr[2], 0, 1, "Roughness: %0.3f", nil)
    if editEnded then editEnded[0] = editEnded[0] or imgui.IsItemDeactivatedAfterEdit() end
    uiSliderFloat(label..'##clrClearcoat', col.pbr[3], 0, 1, "Clearcoat: %0.3f", nil)
    if editEnded then editEnded[0] = editEnded[0] or imgui.IsItemDeactivatedAfterEdit() end
    uiSliderFloat(label..'##clrClearcoatRoughness', col.pbr[4], 0, 1, "Clearcoat Roughness: %0.3f", nil)
    if editEnded then editEnded[0] = editEnded[0] or imgui.IsItemDeactivatedAfterEdit() end
    imgui.EndPopup()
  end
  return nil
end

local function uiColorPicker3(label, col, flags, editEnded)
  local res = imgui.ColorPicker3(label, col, flags)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiColorPicker4(label, col, flags, ref_col, editEnded)
  local res = imgui.ColorPicker4(label, col, flags, ref_col)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end
local function uiColorButton(desc_id, col, flags, size, editEnded)
  local res = imgui.ColorButton(desc_id, col, flags, size)
  if editEnded then
    editEnded[0] = imgui.IsItemDeactivatedAfterEdit()
  end
  return res
end

local function uiPlotLines1(string_label, float_values, int_values_count, int_values_offset, string_overlay_text, float_scale_min, float_scale_max, ImVec2_graph_size, int_stride, auto_resize)
  if int_values_offset == nil then int_values_offset = 0 end
  if float_scale_min == nil then float_scale_min = FLT_MAX end
  if float_scale_max == nil then float_scale_max = FLT_MAX end
  if ImVec2_graph_size == nil then
    if auto_resize then
      ImVec2_graph_size = imgui.ImVec2(imgui.GetWindowSize().x - 2*imgui.GetStyle().WindowPadding.x - imgui.CalcTextSize(string_label).x, imgui.GetWindowSize().y - 5*imgui.GetStyle().WindowPadding.y)
    else
      ImVec2_graph_size = imgui.ImVec2(0,0)
    end
  end
  if int_stride == nil then int_stride = ffi.sizeof('float') end
  imgui.PlotLines1(string_label, float_values, int_values_count, int_values_offset, string_overlay_text, float_scale_min, float_scale_max, ImVec2_graph_size, int_stride)
end

local function IsItemDoubleClicked(int_mouse_button)
  if not int_mouse_button then int_mouse_button = 0 end
  return imgui.IsItemHovered() and imgui.IsMouseDoubleClicked(int_mouse_button)
end

local function IsItemClicked(int_mouse_button)
  if not int_mouse_button then int_mouse_button = 0 end
  return imgui.IsItemHovered() and imgui.IsMouseClicked(int_mouse_button)
end

--- Returns a table with all the fonts imgui has available
local function getFontList()
  local fonts = {}
  for i = 0, imgui.IoFontsGetCount() - 1 do
    table.insert(fonts,
    {
      name = ffi.string(imgui.IoFontsGetName(i))
    })
  end

  return fonts
end

--- Register a given window name, usually must be called in onEditorInitialized() of the editor extension.
-- For more usage of the window api, @see [Tutorial - Step #2, Writing base code](../../../../tutorials/world_editor/create_editor_tool/_index.md).
-- @param windowName the name of the window to register
-- @param defaultSize the default first time size of the window, as imgui ImVec2
-- @param defaultPos the default first time size of the window, as imgui ImVec2
-- @param defaultVisibleBoolean if this is not nil, it will be the default first time open state of the window
-- @param modal if the window is a modal window
-- @param centered if the window is centered by default
local function registerWindow(windowName, defaultSize, defaultPos, defaultVisibleBoolean, modal, centered, groupName)
  local prevVis = defaultVisibleBoolean or false
  if windowsState[windowName] then prevVis = windowsState[windowName].visible[0] end
  windowsState[windowName] =
  {
    visible = imgui.BoolPtr(prevVis),
    backupVisible = prevVis, -- used to check if window was closed by X, to trigger window close hook
    defaultSize = defaultSize,
    defaultPos = defaultPos,
    modal = modal,
    groupName = groupName,
    centered = centered
  }
end

local function isWindowRegistered(windowName)
  return windowsState[windowName] ~= nil
end

if windowsState[windowName] then prevVis = windowsState[windowName].visible[0] end

--- Register a given modal window name, usually must be called in onEditorInitialized() of the editor extension.
-- For more usage of the window api, @see [Tutorial - Step #2, Writing base code](../../../../tutorials/world_editor/create_editor_tool/_index.md).
-- @param windowName the name of the window to register
-- @param defaultSize the default first time size of the window, as imgui ImVec2
-- @param defaultPos the default first time size of the window, as imgui ImVec2
-- @param defaultVisibleBoolean if this is not nil, it will be the default first time open state of the window
-- @param centered if the window is centered by default
local function registerModalWindow(windowName, defaultSize, defaultPos, centered)
  registerWindow(windowName, defaultSize, defaultPos, nil, true, centered)
end

local function checkAndTriggerWindowHooks(wndName, wnd)
  if not wnd or not wnd.visible then return end
  if wnd.backupVisible ~= wnd.visible[0] then
    if wnd.visible[0] then
      extensions.hook("onEditorToolWindowShow", wndName)
    else
      extensions.hook("onEditorToolWindowLostFocus", wndName)
      extensions.hook("onEditorToolWindowHide", wndName)
    end
  end
  wnd.backupVisible = wnd.visible[0]
end

---- Unregister a given window name. For example when a tool window was closed, you dont want it in the saved state of the editor anymore.
-- Call this function right after the imgui.Begin call, if the editor.isWindowVisible(yourWindowName) is false.
-- If you just want to hide the window, the call editor.hideWindow(yourWindowName) only.
-- For more usage of the window api, see [Tutorial - Step #2, Writing base code](../../../../tutorials/world_editor/create_editor_tool/_index.md).
-- @param windowName the name of the window to unregister
local function unregisterWindow(windowName)
  windowsState[windowName] = nil
end

local function isWindowVisible(windowName)
  local wnd = windowsState[windowName]
  if not wnd then
    return false
  else
    checkAndTriggerWindowHooks(windowName, wnd)
    return wnd.visible[0]
  end
end

--- Return the boolean pointer of imgui which stores the visibility of the window, used in imgui.Begin call.
-- @param windowName the name of the window
local function getWindowVisibleBoolPtr(windowName)
  local wnd = windowsState[windowName]
  if not wnd then
    return nil
  else
    return wnd.visible
  end
end

--- Hide the named window, sets the visible boolean to false.
-- @param windowName the name of the window
local function hideWindow(windowName)
  local wnd = windowsState[windowName]
  if not wnd or not wnd.visible[0] then
    return
  else
    wnd.visible[0] = false
    extensions.hook("onEditorToolWindowLostFocus", windowName)
    extensions.hook("onEditorToolWindowHide", windowName)
  end
end

--- Hide all registered windows
local function hideAllWindows()
  for key, val in pairs(windowsState) do
    if val.visible[0] then
      val.visible[0] = false
      extensions.hook("onEditorToolWindowLostFocus", key)
      extensions.hook("onEditorToolWindowHide", key)
    end
  end
end

--- Show the named window, sets the visible boolean to false.
-- @param windowName the name of the window
local function showWindow(windowName, show)
  local wnd = windowsState[windowName]
  if not wnd then
    return
  else
    if show ~= nil then
      wnd.visible[0] = show
    else
      wnd.visible[0] = true
    end
  end
end

local function setWindowVisibility(windowName, visible)
  showWindow(windowName, visible)
end

local function setWindowGroupVisibility(groupName, visible)
  for key, val in pairs(windowsState) do
    if val.groupName == groupName then
      setWindowVisibility(key, visible)
    end
  end
end

--- Setup the window's default size and position. Must be called before imgui.Begin.
-- @param windowName the name of the window
local function setupWindow(windowName)
  local wnd = windowsState[windowName]
  if not wnd then return end

  checkAndTriggerWindowHooks(windowName, wnd)

  local flag = imgui.Cond_FirstUseEver

  if wnd.defaultSize then
    imgui.SetNextWindowSize(wnd.defaultSize, flag)
  end

  if wnd.centered then
    local pos = imgui.ImVec2(imgui.GetMainViewport().Pos.x + imgui.GetMainViewport().Size.x / 2, imgui.GetMainViewport().Pos.y + imgui.GetMainViewport().Size.y / 2)
    imgui.SetNextWindowPos(pos, imgui.Cond_Appearing, imgui.ImVec2(0.5, 0.5))
  else
    if wnd.defaultPos then
      imgui.SetNextWindowPos(wnd.defaultPos, flag)
    end
  end
end

local function checkWindowFocus(windowName)
  local wnd = windowsState[windowName]
  if not wnd then return end

  if imgui.IsWindowFocused(imgui.FocusedFlags_RootAndChildWindows) then
    if not wnd.focused then
      wnd.focused = true
      extensions.hook("onEditorToolWindowGotFocus", windowName)
    end
  else
    if wnd.focused then
      wnd.focused = false
      extensions.hook("onEditorToolWindowLostFocus", windowName)
    end
  end
end

local function beginWindow(windowName, title, flags, noClose)
  if not windowsState[windowName] then
    editor.logWarn("No registered window named: " .. windowName)
    return false
  end
  -- push windowName's visibility bool in a table stack so endWindow can grab it and check if window is visible
  local isWndVisible = isWindowVisible(windowName)
  if not windowsState[windowName].modal then
    table.insert(windowVisibleStack, isWndVisible)
  end

  if not windowsState[windowName].title then
    windowsState[windowName].title = title
  end

  if not isWndVisible then return false end
  setupWindow(windowName)
  local visPtr = nil
  if not noClose then visPtr = getWindowVisibleBoolPtr(windowName) end
  local ret
  if not windowsState[windowName].modal then
    ret = imgui.Begin(title, visPtr, flags)
  else
    ret = imgui.BeginPopupModal(title, visPtr, flags)
    table.insert(modalWindowVisibleStack, ret)
  end
  if ret then checkWindowFocus(windowName) end
  return ret
end

local function beginModalWindow(windowName, title, flags, noClose)
  -- we check to see if the modal is marked as visible by openModalWindow
  -- because OpenPopup doesnt work if its called from within another Begin - End in imgui
  if windowsState[windowName].visible[0] == true then
    imgui.OpenPopup(title)
  end
  return beginWindow(windowName, title, flags, noClose)
end

local function endWindow()
  local isWndVisible = table.remove(windowVisibleStack, #windowVisibleStack)
  if isWndVisible then imgui.End() end
end

local function endModalWindow()
  local isWndVisible = table.remove(modalWindowVisibleStack, #modalWindowVisibleStack)
  if isWndVisible then imgui.EndPopup() end
end

local function openModalWindow(windowName)
  showWindow(windowName)
end

local function closeModalWindow(windowName)
  hideWindow(windowName)
  imgui.CloseCurrentPopup()
end

local function saveWindowsState(customFilename)
  -- we must collapse the visible imgui.BoolPtr to a normal bool
  local state = {}
  state.version = WindowsStateFileFormatVersion
  for key, val in pairs(windowsState) do
    -- we do this because we cant serialize ffi and C++ objects
    val.isVisible = val.visible[0]

    -- we hide any modal windows, they wont show up on next session, unless openModalWindow is called
    if val.modal then val.isVisible = false end

    if val.defaultSize then
      val.defaultWindowSize = {x = val.defaultSize.x, y = val.defaultSize.y}
    end
    if val.defaultPos then
      val.defaultWindowPos = {x = val.defaultPos.x, y = val.defaultPos.y}
    end
  end
  -- let extensions save their gui instances info
  state.guiInstancers = {}
  extensions.hook("onEditorSaveGuiInstancerState", state.guiInstancers)
  extensions.hook("onEditorSaveWindowsState", windowsState)
  state.windowsState = windowsState
  jsonWriteFile(customFilename or windowsStateFileName, state, true)
end

local function loadWindowsState(customFilename, toolName)
  local finalFilename = customFilename or windowsStateFileName
  local wstate = readJsonFile(finalFilename) or {}
  local wstateFileExists = FS:fileExists(finalFilename)

  if (wstateFileExists and wstate.version ~= WindowsStateFileFormatVersion) or (not wstateFileExists) then
    local defaultWindowsStateFileName = "settings/" .. (toolName or "editor") .. "/layouts/Default/windowsState.json"

    editor.logWarn("Editor windows state file '" .. tostring(finalFilename) .. "' format version mismatch. Expected: " .. WindowsStateFileFormatVersion .. " File: " .. tostring(wstate.version) .. ", will upgrade.")
    wstate = readJsonFile(defaultWindowsStateFileName)
    --TODO: upgrade code for older versions of the file
  end

  if not wstateFileExists then
    print("Windows state file does not exists: " .. finalFilename)
  end

  -- hide all registered windows and set isVisible (used in the json and below code) to false
  -- we need this so only the visible windows in the loaded windows state are shown
  hideAllWindows()

  for key, val in pairs(windowsState) do
    val.isVisible = false
  end

  -- copy over the state for each window
  for key, val in pairs(wstate.windowsState or {}) do
    windowsState[key] = val
  end

  -- resolve the size, pos and visibility
  for key, val in pairs(windowsState) do
    val.visible = imgui.BoolPtr(val.isVisible or false)
    if val.defaultWindowSize and val.defaultWindowSize.x and val.defaultWindowSize.y then
      val.defaultSize = imgui.ImVec2(val.defaultWindowSize.x, val.defaultWindowSize.y)
    end
    if val.defaultWindowPos and val.defaultWindowPos.x and val.defaultWindowPos.y then
      val.defaultPos = imgui.ImVec2(val.defaultWindowPos.x, val.defaultWindowPos.y)
    end
    -- delete the serialized bool member
    val.isVisible = nil
  end

  extensions.hook("onEditorLoadWindowsState", wstate.windowsState or {})
  extensions.hook("onEditorLoadGuiInstancerState", wstate.guiInstancers or {})
end

local function callShowWindowHookForVisibleWindows()
  for key, val in pairs(windowsState) do
    if val.visible[0] then
      extensions.hook("onEditorToolWindowShow", key)
    end
  end
end

local function defocusFocusedWindow()
  for key, val in pairs(windowsState) do
    if val.focused then
      val.focused = false
      extensions.hook("onEditorToolWindowLostFocus", key)
    end
  end
end

local function setWindowGroup(windowName, groupName)
  if windowsState[windowName] then
    windowsState[windowName].groupName = groupName
  end
end

local function addWindowsStateApi()
  editor.registerWindow = registerWindow
  editor.isWindowRegistered = isWindowRegistered
  editor.registerModalWindow = registerModalWindow
  editor.unregisterWindow = unregisterWindow
  editor.isWindowVisible = isWindowVisible
  editor.getWindowVisibleBoolPtr = getWindowVisibleBoolPtr
  editor.hideWindow = hideWindow
  editor.hideAllWindows = hideAllWindows
  editor.callShowWindowHookForVisibleWindows = callShowWindowHookForVisibleWindows
  editor.showWindow = showWindow
  editor.setWindowVisibility = setWindowVisibility
  editor.setWindowGroupVisibility = setWindowGroupVisibility
  editor.setWindowGroup = setWindowGroup
  editor.setupWindow = setupWindow
  editor.saveWindowsState = saveWindowsState
  editor.loadWindowsState = loadWindowsState
  editor.getWindowsState = function() return windowsState end
  editor.checkWindowFocus = checkWindowFocus
  editor.beginWindow = beginWindow
  editor.endWindow = endWindow
  editor.defocusFocusedWindow = defocusFocusedWindow
  editor.openModalWindow = openModalWindow
  editor.closeModalWindow = closeModalWindow
  editor.beginModalWindow = beginModalWindow
  editor.endModalWindow = endModalWindow
end

local function addGuiCoreApi()
  editor.checkWindowResize = checkWindowResize
  editor.texObj = texObj
  editor.showVizHelperWindow = showVizHelperWindow
  editor.createIconAtlas = createIconAtlas
  editor.isViewportFocused = isViewportFocused
  editor.isViewportHovered = isViewportHovered
  editor.screenToClient = screenToClient
  editor.getFontList = getFontList
end

local function addUndoReadyWidgetsApi()
  editor.setDefaultIconButtonSize = setDefaultIconButtonSize
  editor.uiHighlightedText = uiHighlightedText
  editor.uiIconImage = uiIconImage
  editor.uiIconImageButton = uiIconImageButton
  editor.uiDragFloat = uiDragFloat
  editor.uiDragFloat2 = uiDragFloat2
  editor.uiDragFloat3 = uiDragFloat3
  editor.uiDragFloat4 = uiDragFloat4
  editor.uiDragFloatRange2 = uiDragFloatRange2
  editor.uiDragInt = uiDragInt
  editor.uiDragInt2 = uiDragInt2
  editor.uiDragInt3 = uiDragInt3
  editor.uiDragInt4 = uiDragInt4
  editor.uiDragIntRange2 = uiDragIntRange2
  editor.uiDragScalar = uiDragScalar
  editor.uiDragScalarN = uiDragScalarN
  editor.uiInputText = uiInputText
  editor.uiInputTextMultiline = uiInputTextMultiline
  editor.uiInputTextMultilineReadOnly = uiInputTextMultilineReadOnly
  editor.uiInputFloat = uiInputFloat
  editor.uiInputFloat2 = uiInputFloat2
  editor.uiInputFloat3 = uiInputFloat3
  editor.uiInputFloat4 = uiInputFloat4
  editor.uiInputInt = uiInputInt
  editor.uiInputInt2 = uiInputInt2
  editor.uiInputInt3 = uiInputInt3
  editor.uiInputInt4 = uiInputInt4
  editor.uiInputDouble = uiInputDouble
  editor.uiInputScalar = uiInputScalar
  editor.uiInputScalarN = uiInputScalarN
  editor.uiInputSearch = uiInputSearch
  editor.uiInputSearchTextFilter = uiInputSearchTextFilter
  editor.uiSliderFloat = uiSliderFloat
  editor.uiSliderFloat2 = uiSliderFloat2
  editor.uiSliderFloat3 = uiSliderFloat3
  editor.uiSliderFloat4 = uiSliderFloat4
  editor.uiSliderAngle = uiSliderAngle
  editor.uiSliderInt = uiSliderInt
  editor.uiSliderInt2 = uiSliderInt2
  editor.uiSliderInt3 = uiSliderInt3
  editor.uiSliderInt4 = uiSliderInt4
  editor.uiSliderScalar = uiSliderScalar
  editor.uiSliderScalarN = uiSliderScalarN
  editor.uiVSliderFloat = uiVSliderFloat
  editor.uiVSliderInt = uiVSliderInt
  editor.uiVSliderScalar = uiVSliderScalar
  editor.uiColorEdit3 = uiColorEdit3
  editor.uiColorEdit4 = uiColorEdit4
  editor.uiColorEdit8 = uiColorEdit8
  editor.uiColorPicker3 = uiColorPicker3
  editor.uiColorPicker4 = uiColorPicker4
  editor.uiColorButton = uiColorButton
  editor.uiPlotLines1 = uiPlotLines1
  editor.IsItemDoubleClicked = IsItemDoubleClicked
  editor.IsItemClicked = IsItemClicked
  editor.uiTextUnformattedRightAlign = uiTextUnformattedRightAlign
  editor.uiTextColoredWithFont = uiTextColoredWithFont
  editor.uiButtonRightAlign = uiButtonRightAlign
  editor.uiVertSeparator = uiVertSeparator
end

local tempBoolPtr = imgui.BoolPtr(false)
local tempIntPtr = imgui.IntPtr(0)
local tempIntArr2 = ffi.new("int[2]", {0, 0})
local tempFloatPtr = imgui.FloatPtr(0)
local tempFloatArr2 = ffi.new("float[2]", {0, 0})
local tempFloatArr3 = ffi.new("float[3]", {0, 0, 0})
local tempFloatArr4 = ffi.new("float[4]", {0, 0, 0, 0})
local tempImVec4 = imgui.ImVec4(1,1,1,1)
local tempCharPtr = imgui.ArrayChar(256, "")
local tempTextureObj = nil
local tempVec3 = vec3(0,0,0)
local tempImVec4 = imgui.ImVec4(0,0,0,0)

-- in: bool, out: bool pointer
-- in: nil, out: bool
local function getTempBool_BoolBool(value)
  if value ~= nil then
    if value == true then
      tempBoolPtr[0] = true
      return tempBoolPtr
    elseif value == false then
      tempBoolPtr[0] = false
      return tempBoolPtr
    end
  else
    return tempBoolPtr[0]
  end
end

-- in string; out bool pointer
-- in nil; out string
local function getTempBool_StringString(value)
  local valueType = type(value)

  if valueType == 'boolean' then
    tempBoolPtr[0] = value
    return tempBoolPtr
  else
    if value then
      local res = tonumber(value)
      if res then
        tempBoolPtr[0] = (res == 1 and true or false)
      else
        -- editor.logError(logTag .. "Cannot parse value '" .. value .. "'! Fallback to false.")
        tempBoolPtr[0] = false
      end
      return tempBoolPtr
    else
      return (tempBoolPtr[0] == true and "1" or "0")
    end
  end
end

-- in: number, out: int pointer
-- in: nil, out: number
local function getTempInt_NumberNumber(value)
  if value then
    tempIntPtr[0] = value
    return tempIntPtr
  else
    return tempIntPtr[0]
  end
end

-- in string; out int pointer
-- in nil; out number
local function getTempInt_StringString(value)
  if value then
    local res = tonumber(value)
    if res then
      tempIntPtr[0] = res
    else
      editor.logError(logTag .. "Cannot parse int value '" .. value .. "'! Fallback to 0.")
      tempIntPtr[0] = 0
    end
    return tempIntPtr
  else
    return string.format('%i', tempIntPtr[0])
  end
end

-- in string; out int pointer/array
-- in nil; out string
local function getTempIntArray2_StringString(value)
  if value then
    local res = split(value, " ")
    local tblLength = #res

    if tblLength == 2 then
      tempIntArr2[0] = tonumber(res[1])
      tempIntArr2[1] = tonumber(res[2])
    else
      editor.logError(logTag .. "Cannot parse value'" .. value .. "'!")
      tempIntArr2[0] = 0
      tempIntArr2[1] = 0
    end
    return tempIntArr2
  else
    return string.format('%d %d', tempIntArr2[0], tempIntArr2[1])
  end
end

-- in: number, out: float pointer
-- in: nil, out: number
local function getTempFloat_NumberNumber(value)
  if value then
    tempFloatPtr[0] = value
    return tempFloatPtr
  else
    return tempFloatPtr[0]
  end
end

-- in string; out float pointer
-- in nil; out number
local function getTempFloat_StringString(value)
  if value then
    local res = tonumber(value)
    if res then
      tempFloatPtr[0] = res
    else
      editor.logError(logTag .. "Cannot parse float value '" .. value .. "'! Fallback to 0.")
      tempFloatPtr[0] = 0
    end
    return tempFloatPtr
  else
    return string.format('%f', tempFloatPtr[0])
  end
end

-- in string; out float pointer/array
-- in nil; out string
local function getTempFloatArray2_StringString(value)
  if value then
    local res = split(value, " ")
    local tblLength = #res

    if tblLength == 2 then
      tempFloatArr2[0] = tonumber(res[1])
      tempFloatArr2[1] = tonumber(res[2])
    else
      editor.logError(logTag .. "Cannot parse value'" .. value .. "'!")
      tempFloatArr2[0] = 1.0
      tempFloatArr2[1] = 1.0
    end
    return tempFloatArr2
  else
    return string.format('%f %f', tempFloatArr2[0], tempFloatArr2[1])
  end
end

-- in table; out float pointer/array
-- in nil; out table
local function getTempFloatArray2_TableTable(value)
  if value and type(value) == 'table' then
    if #value == 2 then
      tempFloatArr4[0] = value[1]
      tempFloatArr4[1] = value[2]
    else
      editor.logError(logTag .. "Table length incorrect!")
      tempFloatArr4[0] = 1.0
      tempFloatArr4[1] = 1.0
    end
    return tempFloatArr4
  else
    return {tempFloatArr4[0], tempFloatArr4[1]}
  end
end

-- in table; out float pointer/array
-- in nil; out table
local function getTempFloatArray3_TableTable(value)
  if value and type(value) == 'table' then
    if #value == 3 then
      tempFloatArr3[0] = value[1]
      tempFloatArr3[1] = value[2]
      tempFloatArr3[2] = value[3]
    else
      editor.logError(logTag .. "Table length incorrect!")
      tempFloatArr3[0] = 1.0
      tempFloatArr3[1] = 1.0
      tempFloatArr3[2] = 1.0
    end
    return tempFloatArr3
  else
    return {tempFloatArr3[0], tempFloatArr3[1], tempFloatArr3[2]}
  end
end

local function getTempFloatArray3_Vec3Vec3(value)
  if value and type(value) == 'cdata' then
    tempFloatArr3[0] = value.x
    tempFloatArr3[1] = value.y
    tempFloatArr3[2] = value.z
    return tempFloatArr3
  else
    tempVec3.x = tempFloatArr3[0]
    tempVec3.y = tempFloatArr3[1]
    tempVec3.z = tempFloatArr3[2]
    return tempVec3
  end
end

-- in table; out float pointer/array
-- in nil; out table
local function getTempFloatArray4_TableTable(value)
  if value and type(value) == 'table' then
    if #value == 4 then
      tempFloatArr4[0] = value[1]
      tempFloatArr4[1] = value[2]
      tempFloatArr4[2] = value[3]
      tempFloatArr4[3] = value[4]
    else
      editor.logError(logTag .. "Table length incorrect!")
      tempFloatArr4[0] = 1.0
      tempFloatArr4[1] = 1.0
      tempFloatArr4[2] = 1.0
      tempFloatArr4[3] = 1.0
    end
    return tempFloatArr4
  else
    return {tempFloatArr4[0], tempFloatArr4[1], tempFloatArr4[2], tempFloatArr4[3]}
  end
end

-- in string; out float pointer/array
-- in nil; out string
local function getTempFloatArray4_StringString(value)
  if value then
    local res = split(value, " ")
    local tblLength = #res

    if tblLength == 4 then
      tempFloatArr4[0] = tonumber(res[1])
      tempFloatArr4[1] = tonumber(res[2])
      tempFloatArr4[2] = tonumber(res[3])
      tempFloatArr4[3] = tonumber(res[4])
    elseif tblLength == 1 then
      local col = getStockColor(res[1])
      if col ~= nil then
        tempFloatArr4[0] = col[1]
        tempFloatArr4[1] = col[2]
        tempFloatArr4[2] = col[3]
        tempFloatArr4[3] = col[4]
      else
        editor.logError(logTag .. "Cannot find stock color '" .. value .. "'! Fallback to white.")
        res = ffi.new("float[4]", {1.0, 1.0, 1.0, 1.0})
      end
    elseif tblLength == 3 then
      tempFloatArr4[0] = tonumber(res[1])
      tempFloatArr4[1] = tonumber(res[2])
      tempFloatArr4[2] = tonumber(res[3])
      tempFloatArr4[3] = 1.0
    else
      editor.logError(logTag .. "Cannot parse color string '" .. value .. "'! Fallback to white.")
      tempFloatArr4[0] = 1.0
      tempFloatArr4[1] = 1.0
      tempFloatArr4[2] = 1.0
      tempFloatArr4[3] = 1.0
    end

    return tempFloatArr4
  else
    return string.format('%f %f %f %f', tempFloatArr4[0], tempFloatArr4[1], tempFloatArr4[2], tempFloatArr4[3])
  end
end


-- in table; out float pointer/array
-- in nil; out table
local function getTempImVec4_TableTable(value)
  if value and type(value) == 'table' then
    if #value == 4 then
      tempImVec4.x = value[1]
      tempImVec4.y = value[2]
      tempImVec4.z = value[3]
      tempImVec4.w = value[4]
    else
      editor.logError(logTag .. "Table length incorrect!")
      tempImVec4.x = 1.0
      tempImVec4.y = 1.0
      tempImVec4.z = 1.0
      tempImVec4.w = 1.0
    end
    return tempImVec4
  else
    return {tempImVec4.x, tempImVec4.y, tempImVec4.z, tempImVec4.w}
  end
end

-- in string; out char pointer
-- in nil; out string
local function getTempCharPtr(value)
  if value then
    ffi.copy(tempCharPtr, value)
    return tempCharPtr
  else
    return ffi.string(tempCharPtr)
  end
end

-- in: string/path, out: texture object
-- in: nil, out: texture object
local function getTempTextureObj(value)
  if value then
    tempTextureObj = editor.texObj(value)
    return tempTextureObj
  else
    return tempTextureObj
  end
end

-- in table; out float ImVec4
-- in nil; out ImVec4
local function getTempImVec4_TableImVec4(value)
  if value and type(value) == 'table' then
    if #value == 4 then
      tempImVec4.x = value[1]
      tempImVec4.y = value[2]
      tempImVec4.z = value[3]
      tempImVec4.w = value[4]
    else
      editor.logError(logTag .. "Table length incorrect!")
      tempImVec4.x = 1.0
      tempImVec4.y = 1.0
      tempImVec4.z = 1.0
      tempImVec4.w = 1.0
    end
    return tempImVec4
  else
    return tempImVec4
  end
end

local function addCTypeHelperApi()
  editor.getTempBool_BoolBool = getTempBool_BoolBool
  editor.getTempBool_StringString = getTempBool_StringString
  editor.getTempInt_NumberNumber = getTempInt_NumberNumber
  editor.getTempInt_StringString = getTempInt_StringString
  editor.getTempIntArray2_StringString = getTempIntArray2_StringString
  editor.getTempFloat_NumberNumber = getTempFloat_NumberNumber
  editor.getTempFloat_StringString = getTempFloat_StringString
  editor.getTempFloatArray2_StringString = getTempFloatArray2_StringString
  editor.getTempFloatArray2_TableTable = getTempFloatArray2_TableTable
  editor.getTempFloatArray3_TableTable = getTempFloatArray3_TableTable
  editor.getTempFloatArray3_Vec3Vec3 = getTempFloatArray3_Vec3Vec3
  editor.getTempFloatArray4_TableTable = getTempFloatArray4_TableTable
  editor.getTempFloatArray4_StringString = getTempFloatArray4_StringString
  editor.getTempImVec4_TableTable = getTempImVec4_TableTable
  editor.getTempCharPtr = getTempCharPtr
  editor.getTempTextureObj = getTempTextureObj
  editor.getTempImVec4_TableImVec4 = getTempImVec4_TableImVec4
end

local function setKeyModifier(mod, pressed)
  pressed = pressed == 1
  if mod == editor.KeyModifier_LShift then editor.keyModifiers.shift = pressed editor.keyModifiers.lShift = pressed end
  if mod == editor.KeyModifier_LCtrl then editor.keyModifiers.ctrl = pressed editor.keyModifiers.lCtrl = pressed end
  if mod == editor.KeyModifier_LAlt then editor.keyModifiers.alt = pressed editor.keyModifiers.lAlt = pressed end
  if mod == editor.KeyModifier_RShift then editor.keyModifiers.shift = pressed editor.keyModifiers.rShift = pressed end
  if mod == editor.KeyModifier_RCtrl then editor.keyModifiers.ctrl = pressed editor.keyModifiers.rCtrl = pressed end
  if mod == editor.KeyModifier_RAlt then editor.keyModifiers.alt = pressed editor.keyModifiers.rAlt = pressed end
end

local defaultAlternateRowsColors = { imgui.ImVec4(48/255,48/255,48/255,0.6), imgui.ImVec4(0,0,0,0) }

-- Render alternate-color rows current window/child
-- Based on approach in https://github.com/ocornut/imgui/issues/2668
-- IMPORTANT: Requires to be surrounded by Begin/BeginChild, End/EndChild
local function uiRenderAlternateRows(lineHeight, mOddColor, mEvenColor)
  -- Handles optional arguments. Supported types ImVec4 and ImColor.
  if mOddColor == nil then mOddColor = defaultAlternateRowsColors[1] end
  if mEvenColor == nil then mEvenColor = defaultAlternateRowsColors[2] end
  if type(mOddColor) ~= 'cdata' or type(mEvenColor) ~= "cdata" then return end
  local function testOddImColor() mOddColor = mOddColor.Value end
  local status, msg = pcall(testOddImColor)
  if not status then
    local function testOddImVec4() local tmp = mOddColor.x end
    status, msg = pcall(testOddImVec4)
    if not status then return end
  end
  local function testEvenImColor() mEvenColor = mEvenColor.Value end
  status, msg = pcall(testEvenImColor)
  if not status then
    local function testEvenImVec4() local tmp = mEvenColor.x end
    status, msg = pcall(testEvenImVec4)
    if not status then return end
  end
  -- End arguments handling
  local mDrawList = imgui.GetWindowDrawList()
  local mStyle = imgui.GetStyle()
  if lineHeight == nil then lineHeight = imgui.GetTextLineHeight() end
  -- Somehow, using this approach seems working for height calculation ¯\_(ツ)_/¯
  lineHeight = lineHeight + mStyle.ItemSpacing.y
  local uiScaling = editor.getPreference("ui.general.scale") or defaultUiScale
  local mHeight = math.floor(lineHeight + mStyle.ItemSpacing.y * uiScaling / 2)
  -- Calculates rows area
  local scrollOffsetH = imgui.GetScrollX()
  local scrollOffsetV = imgui.GetScrollY()
  local scrolledOutLines = math.floor(scrollOffsetV / mHeight)
  scrollOffsetV = scrollOffsetV - mHeight * scrolledOutLines
  local winPos = imgui.GetWindowPos()
  local clipRectMin = imgui.ImVec2(winPos.x, winPos.y)
  local clipRectMax = imgui.ImVec2(winPos.x + imgui.GetWindowWidth(), winPos.y + imgui.GetWindowHeight())
  if imgui.GetScrollMaxY() > 0 then -- Doesn't highlight the area under the scrollbar
    clipRectMax.x = clipRectMax.x - mStyle.ScrollbarSize
  end
  imgui.ImDrawList_PushClipRect(mDrawList, clipRectMin, clipRectMax)

  local yMin = clipRectMin.y - scrollOffsetV + imgui.GetCursorPosY()
  local yMax = clipRectMax.y - scrollOffsetV + lineHeight
  local xMin = clipRectMin.x + scrollOffsetH + imgui.GetWindowContentRegionMin().x
  local xMax = clipRectMax.x + scrollOffsetH + imgui.GetWindowContentRegionMax().x

  local y = yMin                            -- running height
  local isOdd = scrolledOutLines % 2 ~= 0   -- alternation indicator
  while y < yMax do
    local mColor = imgui.ColorConvertFloat4ToU32(not isOdd and mEvenColor or mOddColor)
    imgui.ImDrawList_AddRectFilled(mDrawList, imgui.ImVec2(xMin, y - mStyle.ItemSpacing.y), imgui.ImVec2(xMax, y + mHeight), mColor)

    y = y + mHeight     -- increments running height for next iteration
    isOdd = not isOdd   -- inverts alternation for next iteration
  end

  imgui.ImDrawList_PopClipRect(mDrawList)
end

local function initialize(editorInstance)
  log('D', 'gui', "initialize")
  editor = editorInstance
  --TODO: do we init imgui there in that file
  require('editor/api/guiTheme')

  editor.drawBrush = drawBrush

  addWindowsStateApi()
  addGuiCoreApi()
  addUndoReadyWidgetsApi()
  addCTypeHelperApi()
  createIconAtlas()
  editor.uiRenderAlternateRows = uiRenderAlternateRows
  if editor.setupEditorGuiTheme then
    editor.setupEditorGuiTheme()
  end

  editor.KeyModifier_LShift = 4
  editor.KeyModifier_LCtrl = 5
  editor.KeyModifier_LAlt = 6
  editor.KeyModifier_RShift = 7
  editor.KeyModifier_RCtrl = 8
  editor.KeyModifier_RAlt = 9
  editor.keyModifiers = {}
  editor.keyModifiers.shift = false
  editor.keyModifiers.ctrl = false
  editor.keyModifiers.alt = false
  editor.keyModifiers.lShift = false
  editor.keyModifiers.lCtrl = false
  editor.keyModifiers.lAlt = false
  editor.keyModifiers.rShift = false
  editor.keyModifiers.rCtrl = false
  editor.keyModifiers.rAlt = false
  editor.setKeyModifier = setKeyModifier
end

local M = {}
M.initialize = initialize
M.presentGui = presentGui

return M