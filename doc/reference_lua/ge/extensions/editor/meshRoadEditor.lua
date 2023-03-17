-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_meshRoadEditor'
local meshEditor = dofile("/lua/ge/extensions/editor/meshEditor.lua")
meshEditor.type = "MeshRoad"
meshEditor.preferencesName = "meshRoadEditor"
meshEditor.niceName = "Mesh Road"

local function onActivate()
  log('I', logTag, "onActivate")
  meshEditor.onActivate_()
end

local function onEditorInitialized()
  editor.editModes.meshRoadEditMode =
  {
    displayName = "Edit " .. meshEditor.type,
    onActivate = onActivate,
    onUpdate = meshEditor.onUpdate_,
    onToolbar = meshEditor.onToolbar_,
    actionMap = "MeshRoadEditor",
    onCopy = meshEditor.copySettingsAM,
    onPaste = meshEditor.pasteFieldsAM,
    onDeleteSelection = meshEditor.onDeleteSelection,
    onSelectAll = meshEditor.onSelectAll,
    icon = editor.icons.create_road_mesh,
    iconTooltip = "Mesh Road Editor",
    auxShortcuts = {},
    hideObjectIcons = true
  }
  editor.editModes.meshRoadEditMode.auxShortcuts[bit.bor(editor.AuxControl_LMB, editor.AuxControl_Alt)] = "Create mesh road / Add node"
  editor.editModes.meshRoadEditMode.auxShortcuts[editor.AuxControl_Copy] = "Copy mesh road properties"
  editor.editModes.meshRoadEditMode.auxShortcuts[editor.AuxControl_Paste] = "Paste mesh road properties"
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