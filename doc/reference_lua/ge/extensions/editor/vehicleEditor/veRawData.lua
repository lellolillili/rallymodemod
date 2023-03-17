-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local imguiUtils = require('ui/imguiUtils')
local im = ui_imgui

local wndName = "Raw Vehicle Data"
M.menuEntry = "Debug/Raw Vehicle Data"

local function onEditorGui()
  if not (vEditor.vehicle or vEditor.vehData) then return end

  if editor.beginWindow(wndName, wndName) then
    imguiUtils.addRecursiveTreeTable(vEditor.vehData, '', false)
  end
  editor.endWindow()
end

local function open()
  editor.showWindow(wndName)
end

local function onEditorInitialized()
  editor.registerWindow(wndName, im.ImVec2(500,400))
end

M.onEditorGui = onEditorGui
M.open = open
M.onEditorInitialized = onEditorInitialized

return M