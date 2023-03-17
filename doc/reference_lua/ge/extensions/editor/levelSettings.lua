-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'level_settings'
local imgui = ui_imgui

local function inspectorGui(inspectorInstance)
  imgui.Text("Level Settings")
end

local function onExtensionLoaded()
end

local function showLevelSettings()
  editor.selection = {}
  editor.selection.level_settings = {1}
end

local function onEditorActivated()
  editor.registerInspectorTypeHandler("level_settings", inspectorGui)
  editor.showLevelSettings = showLevelSettings
end

local function onEditorDeactivated()
  editor.unregisterInspectorTypeHandler("level_settings")
end

M.onEditorActivated = onEditorActivated
M.onEditorDeactivated = onEditorDeactivated
M.onExtensionLoaded = onExtensionLoaded

return M