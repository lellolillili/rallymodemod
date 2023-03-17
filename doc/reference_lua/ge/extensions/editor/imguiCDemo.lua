-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local windowOpen = ui_imgui.BoolPtr(false)

local M = {}

local function onEditorGui()
  if windowOpen[0] then
    ui_imgui.ShowDemoWindow(windowOpen)
  end
end

local function onWindowMenuItem()
  windowOpen[0] = true
end

local function onEditorInitialized()
  editor.addWindowMenuItem("ImGui C Demo", onWindowMenuItem, {groupMenuName = 'Experimental'})
end

M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized

return M