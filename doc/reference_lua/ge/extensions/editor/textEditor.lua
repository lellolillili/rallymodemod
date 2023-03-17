-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_scene_tree'
local imgui = ui_imgui
local guiInstancer = require("editor/api/guiInstancer")()
local objectHistoryActions = require("editor/api/objectHistoryActions")()
local windowNamePrefix = "Text Editor "
local textInputSize = 16384

local function removeInstance(index)
  local wndName = windowNamePrefix .. index
  guiInstancer:removeInstance(index)
  editor.unregisterWindow(wndName)
end

local function idsToString(ids)
  local res = "(" .. ids[1]
  for i = 2, #ids do
    res = res .. ", " .. ids[i]
  end
  res = res .. ")"
  return res
end

local function onEditorGui()
  for index, instance in pairs(guiInstancer.instances) do
    if instance.registerNameAsync then
      editor.registerWindow(instance.registerNameAsync, imgui.ImVec2(300, 500))
      editor.showWindow(instance.registerNameAsync)
      instance.registerNameAsync = nil
    end

    local wndName = windowNamePrefix .. index
    if editor.beginWindow(wndName, "Text Editor " .. idsToString(instance.objIds) .. " " .. instance.fieldName .. "##" .. index) then
      if editor.uiInputTextMultiline('##text' .. index, instance.textInput, textInputSize, imgui.ImVec2(imgui.GetContentRegionAvailWidth(), imgui.GetWindowSize().y - imgui.CalcTextSize('Cancel Ok').y * 4), imgui.InputTextFlags_AllowTabInput, nil, nil, nil) then
      end
    end

    if imgui.Button("Cancel") then
      editor.hideWindow(wndName)
    end

    imgui.SameLine()
    if imgui.Button("Ok") then
      objectHistoryActions.changeObjectFieldWithUndo(instance.objIds, instance.fieldName, ffi.string(instance.textInput), 0)
      editor.hideWindow(wndName)
    end
    editor.endWindow()

    if not editor.isWindowVisible(wndName) then
      removeInstance(index)
    end
  end
end

local function newTextEditorInstance(objIds, fieldName)
  -- Remove existing instances where ids collide
  local removeList = {}
  for index, instance in pairs(guiInstancer.instances) do
    for _, objId in ipairs(objIds) do
      for _, objId2 in ipairs(instance.objIds) do
        if objId == objId2 then
          table.insert(removeList, index)
        end
      end
    end
  end
  for _, index in ipairs(removeList) do
    removeInstance(index)
  end

  local index = guiInstancer:addInstance()
  guiInstancer.instances[index].objIds = objIds
  guiInstancer.instances[index].fieldName = fieldName
  local obj = scenetree.findObjectById(objIds[1])
  guiInstancer.instances[index].textInput = imgui.ArrayChar(textInputSize, tableSize(objIds) == 1 and obj:getField(fieldName, "") or "")
  local wndName = windowNamePrefix .. index
  guiInstancer.instances[index].registerNameAsync = wndName
end

local function onDeserialize(state)
  for index, instance in pairs(state) do
    newTextEditorInstance(instance.objIds, instance.fieldName)
  end
end

local function onSerialize()
  local instancesCopy = deepcopy(guiInstancer.instances)
  for key, instance in pairs(instancesCopy) do
    instance.textInput = nil
  end
  return instancesCopy
end

local function onEditorInitialized()
  editor.newTextEditorInstance = newTextEditorInstance
end

M.onEditorInitialized = onEditorInitialized
M.onEditorGui = onEditorGui
M.onSerialize = onSerialize
M.onDeserialize = onDeserialize

return M