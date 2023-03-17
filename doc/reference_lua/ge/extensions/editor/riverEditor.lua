-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_riverEditor'
local meshEditor = dofile("/lua/ge/extensions/editor/meshEditor.lua")
meshEditor.type = "River"
meshEditor.preferencesName = "riverEditor"
meshEditor.niceName = "River"

local function onActivate()
  log('I', logTag, "onActivate")
  meshEditor.onActivate_()
end

local function onEditorInitialized()
  editor.editModes.riverEditMode =
  {
    displayName = "Edit " .. meshEditor.type,
    onActivate = onActivate,
    onUpdate = meshEditor.onUpdate_,
    onToolbar = meshEditor.onToolbar_,
    actionMap = "RiverEditor",
    onCopy = meshEditor.copySettingsAM,
    onPaste = meshEditor.pasteFieldsAM,
    onDeleteSelection = meshEditor.onDeleteSelection,
    onSelectAll = meshEditor.onSelectAll,
    icon = editor.icons.create_river,
    iconTooltip = "River Editor",
    auxShortcuts = {},
    hideObjectIcons = true
  }
  editor.editModes.riverEditMode.auxShortcuts[bit.bor(editor.AuxControl_LMB, editor.AuxControl_Alt)] = "Create river / Add node"
  editor.editModes.riverEditMode.auxShortcuts[editor.AuxControl_Copy] = "Copy river properties"
  editor.editModes.riverEditMode.auxShortcuts[editor.AuxControl_Paste] = "Paste river properties"
end

local function onExtensionLoaded()
  log('D', logTag, "initialized")
end

M.onEditorGui = meshEditor.onEditorGui_
M.onEditorInitialized = onEditorInitialized
M.onExtensionLoaded = onExtensionLoaded
M.onEditorInspectorHeaderGui = meshEditor.onEditorInspectorHeaderGui_
M.onEditorRegisterPreferences = meshEditor.onEditorRegisterPreferences_
M.onEditorPreferenceValueChanged = meshEditor.onEditorPreferenceValueChanged_
M.onEditorInspectorFieldChanged = meshEditor.onEditorInspectorFieldChanged_
M.onEditorAxisGizmoAligmentChanged = meshEditor.onEditorAxisGizmoAligmentChanged_
M.onEditorObjectSelectionChanged = meshEditor.onEditorObjectSelectionChanged_

M.deleteNodeAM = meshEditor.deleteNodeAM
M.selectAllNodes = meshEditor.selectAllNodes

return M