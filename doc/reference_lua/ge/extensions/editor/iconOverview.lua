-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_icon_overview'
local imgui = ui_imgui
local imUtils = require('ui/imguiUtils')
local toolWindowName = "iconOverview"
local icons
local size = imgui.ImVec2(32,32)
local style
local io
local filter = imgui.ImGuiTextFilter()

local function menu()
  if imgui.BeginMenuBar() then
    if imgui.MenuItem1("Re-create icon atlas") then
      editor.createIconAtlas()
      icons = tableKeys(editor.icons)
      table.sort(icons)
    end
    imgui.EndMenuBar()
  end
end

local function onEditorGui()
  if editor.beginWindow(toolWindowName, "Icons") then
    menu()
    M.drawContent(function(v) imgui.SetClipboardText(v) end)
  end
  editor.endWindow()
end

local function drawContent(selectedFun)
  if not selectedFun then selectedFun = nop end
  local availableWidth = imgui.GetContentRegionAvailWidth() - imgui.GetStyle().ScrollbarSize
  local itemSize = ((size.x * imgui.uiscale[0]  + style.ItemSpacing.x))
  local itemsPerRow = math.floor(availableWidth / itemSize)
  if editor.uiInputSearchTextFilter("##iconFilter", filter, imgui.GetContentRegionAvailWidth(), nil, editEnded) then
    if ffi.string(imgui.TextFilter_GetInputBuf(filter)) == "" then
      imgui.ImGuiTextFilter_Clear(filter)
    end
  end
  if imgui.BeginChild1("iconChild") then
    local i = 0
    for k,v in pairs(icons) do
      if imgui.ImGuiTextFilter_PassFilter(filter, v) then
        if i % itemsPerRow ~= 0 then imgui.SameLine() end
        if editor.icons[v] then
          if editor.uiIconImageButton(editor.icons[v], size, imgui.ImColorByRGB(255,255,255,255).Value, nil, imgui.ImColorByRGB(128,128,128,128).Value, v) then
            selectedFun(v)
          end
        else
          log('E', logTag, "Icon with key '" .. v .. "' not existent!")
        end
        imgui.tooltip(v)
        i = i + 1
      end
    end
  end
  imgui.EndChild()
end

local function onEditorActivated()
end

local function onWindowMenuItem()
  editor.showWindow(toolWindowName)
end

local function onEditorInitialized()
  icons = tableKeys(editor.icons)
  table.sort(icons)
  style = imgui.GetStyle()
  editor.registerWindow(toolWindowName, imgui.ImVec2(600, 600))
  editor.addWindowMenuItem("Icons", onWindowMenuItem, {groupMenuName = 'Experimental'})
end

local function onExtensionLoaded()
end

M.onEditorInitialized = onEditorInitialized
M.onEditorActivated = onEditorActivated
M.onEditorGui = onEditorGui
M.onExtensionLoaded = onExtensionLoaded
M.open = onWindowMenuItem
M.drawContent = drawContent
return M