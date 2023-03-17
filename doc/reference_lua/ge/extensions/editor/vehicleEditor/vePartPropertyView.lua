-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local im = ui_imgui

local wndName = 'Part Properties'

local genericInspector1

local lastEditTarget

local fields = {}

local function _editNewTable()
  fields = {}
  for k, v in pairs(vEditor.propertyTableEditTarget or {}) do
    if k ~= '__astNodeIdx' and type(v) ~= 'table' and k ~= '__schemaProcessed' then
      local t = {}
      t.groupName = ''
      t.name = tostring(k)
      t.type = 'string'
      t.value = tostring(v)
      if type(v) == 'number' then
        t.type = 'float'
      elseif type(v) == 'boolean' then
        t.type = 'bool'
      end
      t.defaultValue = t.value
      table.insert(fields, t)
    end
  end
  lastEditTarget = vEditor.propertyTableEditTarget
end

local function onEditorGui()
  if editor.beginWindow(wndName, wndName) then

    if vEditor.propertyTableEditTarget ~= lastEditTarget then
      _editNewTable()
    end

    genericInspector1:inspectorGui(fields)
  end
  editor.endWindow()
end

local function open()
  editor.showWindow(wndName)
end

local function onEditorInitialized()
  editor.registerWindow(wndName, im.ImVec2(500,400))

  local genericInspectorSetter = function (fieldName, newValue, arrayIndex, fieldInfo)
    if not lastEditTarget then return end
    if arrayIndex ~= nil and fieldInfo.elementCount then
      fieldInfo.value[arrayIndex] = newValue
    else
      fieldInfo.value = newValue
    end
    lastEditTarget[fieldName] = newValue
  end

  genericInspector1 = require("editor/api/genericInspector")()
  genericInspector1:initialize(genericInspectorSetter)
end

M.onEditorGui = onEditorGui
M.open = open
M.onEditorInitialized = onEditorInitialized

return M