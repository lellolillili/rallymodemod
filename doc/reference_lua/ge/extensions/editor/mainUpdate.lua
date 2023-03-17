-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_main_update'
local imgui = ui_imgui

local function updateMainEditor()
  editor.updateObjectIcons()
  -- on each frame, we call the hook for the preferences that were changed during the last frame
  if editor.preferencesRegistry:broadcastPreferenceValueChanged() then
    -- if we had any item changed, then save the prefs to file
    editor.savePreferences()
  end
end

local function drawMainEditorGizmos()
  editor.drawObjectIcons()
end

local function onUpdate(dtReal, dtSim, dtRaw)
  if editor.active then
    updateMainEditor()
    if editor.editMode and editor.editMode.onUpdate then
      editor.editMode.onUpdate(dtReal, dtSim, dtRaw)
    end
    if not editor.hideObjectIcons then
      drawMainEditorGizmos()
    end
    editor.guiModule.presentGui(dtReal, dtSim, dtRaw)
    editor.valueInspectorCopyPasteMenu()
  end
end

local function onExtensionLoaded()
end

local function onExtensionUnloaded()
end

M.onEditorInitialized = nil
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onUpdate = onUpdate

return M