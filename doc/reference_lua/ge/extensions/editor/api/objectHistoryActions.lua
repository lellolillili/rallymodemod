-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local function getNextObjIdInGroup(obj)
  local parentGroup = obj:getGroup()
  if parentGroup then
    for i = 0, parentGroup:size() - 1 do
      local child = parentGroup:at(i)
      if child then
        if child:getID() == obj:getId() and i < parentGroup:size() - 1 then
          return parentGroup:at(i+1):getID()
        end
      end
    end
  end
end

local function createObjectUndo(actionData)
  local obj = Sim.findObjectById(actionData.objectId)
  if obj then
    obj:delete()
    actionData.objectId = nil
  end
end

local function createObjectRedo(actionData)
  if actionData.objectId then
    SimObject.setForcedId(actionData.objectId)
  end
  local obj = createObject(actionData.className)
  obj:registerObject(actionData.name)
  if actionData.parentId then
    local parent = scenetree.findObjectById(actionData.parentId)
    parent:addObject(obj.obj)
  else
    local missionGroup = scenetree.MissionGroup
    if not missionGroup then
      editor.logDebug("MissionGroup does not exist")
      return
    end
    missionGroup:addObject(obj.obj)
  end
  editor.logDebug("Spawned object with ID: " .. obj:getId())
  actionData.objectId = obj:getId()
  extensions.hook("onEditorObjectAdded", actionData.objectId)
  return obj:getId()
end

local function deleteObjectUndo(actionData)
  -- restore a whole group
  if actionData.isSimSet then
    -- restore group
    local deserializeRecursively = function (fn, tbl)
      -- first, deserialize group
      SimObject.setForcedId(tbl.objectId)
      Sim.deserializeObjectsFromText(tbl.json, true, true)

      for i = 1, #tbl.children do
        if tbl.children[i].children then
          fn(fn, tbl.children[i])
        else
          -- deserialize object
          SimObject.setForcedId(tbl.children[i].objectId)
          Sim.deserializeObjectsFromText(tbl.children[i].json, true, true)
        end
      end
    end
    deserializeRecursively(deserializeRecursively, actionData.serializedData)
  else
    -- deserialize object
    if actionData.objectId then
      SimObject.setForcedId(actionData.objectId)
      Sim.deserializeObjectsFromText(actionData.serializedData, true, true)
    end
  end
  local obj = scenetree.findObjectById(actionData.objectId)
  if obj and actionData.nextObjIdInGroup then
    local otherObj = scenetree.findObjectById(actionData.nextObjIdInGroup)
    if otherObj then
      local parentGroupID = otherObj:getField("parentGroup", 0)
      if parentGroupID then
        local parentGroup = scenetree.findObjectById(parentGroupID)
        if parentGroup then
          parentGroup:reorderChild(obj, otherObj)
        end
      end
    end
  end

  extensions.hook("onEditorObjectAdded", actionData.objectId)
end

local function deleteObjectRedo(actionData)
  local obj = Sim.findObjectById(actionData.objectId)
  if obj and not obj:isLocked() then
    if not obj:isSubClassOf("SimSet") and obj:getClassName() ~= "SimGroup" and obj:getClassName() ~= "SimSet" then
      actionData.serializedData = "[" .. obj:serialize(true, -1) .. "]"
    else
      -- special case for group deletion, save the group and all its hierarchy
      actionData.isSimSet = true
      local serializeRecursively = function(fn, parent, tbl)
        parent = Sim.upcast(parent)
        tbl.json = "[" .. parent:serializeForEditor(true, -1, "group") .. "]"
        tbl.objectId = parent:getID()
        tbl.children = {}
        for i = 0, parent:size() - 1 do
          local chd = parent:at(i)
          if chd then
            if chd:isSubClassOf("SimSet") or chd:getClassName() == "SimGroup" or chd:getClassName() == "SimSet" then
              local childTbl = {}
              fn(fn, chd, childTbl)
              table.insert(tbl.children, childTbl)
            else
              local childTbl = {
                objectId = chd:getID(),
                json = "[" .. chd:serializeForEditor(true, -1, "") .. "]",
              }
              table.insert(tbl.children, childTbl)
            end
          end
        end
      end
      actionData.serializedData = {}
      serializeRecursively(serializeRecursively, obj, actionData.serializedData)
    end

    actionData.nextObjIdInGroup = getNextObjIdInGroup(obj)
    editor.deleteObject(actionData.objectId)
  end
end

local function changeObjectFieldUndo(actionData)
  for i = 1, tableSize(actionData.objectIds) do
    editor.setFieldValue(actionData.objectIds[i], actionData.fieldName, actionData.oldFieldValues[i] or "", actionData.arrayIndex)
  end

  if editor.updateObjectSelectionAxisGizmo then editor.updateObjectSelectionAxisGizmo() end

  if actionData.fieldName == "position" or actionData.fieldName == "rotation" or actionData.fieldName == "scale" then
    editor.computeSelectionBBox()
  end

  extensions.hook("onEditorInspectorFieldChanged", actionData.objectIds, actionData.fieldName, actionData.oldFieldValues, actionData.arrayIndex)
end

local function changeObjectFieldRedo(actionData)
  for i = 1, tableSize(actionData.objectIds) do
    editor.setFieldValue(actionData.objectIds[i], actionData.fieldName, actionData.newFieldValue, actionData.arrayIndex)
  end

  if editor.updateObjectSelectionAxisGizmo then editor.updateObjectSelectionAxisGizmo() end

  if actionData.fieldName == "position" or actionData.fieldName == "rotation" or actionData.fieldName == "scale" then
    editor.computeSelectionBBox()
  end

  extensions.hook("onEditorInspectorFieldChanged", actionData.objectIds, actionData.fieldName, actionData.newFieldValue, actionData.arrayIndex)
end

local function changeObjectDynFieldUndo(actionData)
  for i = 1, tableSize(actionData.objectIds) do
    editor.setDynamicFieldValue(actionData.objectIds[i], actionData.fieldName, actionData.oldFieldValues[i] or "", actionData.arrayIndex)
  end
  extensions.hook("onEditorInspectorDynFieldChanged", actionData.objectIds, actionData.fieldName, actionData.oldFieldValues, actionData.arrayIndex)
end

local function changeObjectDynFieldRedo(actionData)
  for i = 1, tableSize(actionData.objectIds) do
    editor.setDynamicFieldValue(actionData.objectIds[i], actionData.fieldName, actionData.newFieldValue, actionData.arrayIndex)
  end
  extensions.hook("onEditorInspectorDynFieldChanged", actionData.objectIds, actionData.fieldName, actionData.newFieldValue, actionData.arrayIndex)
end

local function selectObjectsUndo(actionData)
  -- deselect current selected objects
  editor.setObjectSelectedBool(editor.selection.object, false)
  editor.selection.object = deepcopy(actionData.oldSelection)
  -- select current selected objects
  editor.setObjectSelectedBool(editor.selection.object, true)
  editor.computeSelectionBBox()
  extensions.hook("onEditorObjectSelectionChanged")
end

local function selectObjectsRedo(actionData)
  -- deselect current selected objects
  editor.setObjectSelectedBool(editor.selection.object, false)
  editor.selection.object = deepcopy(actionData.newSelection)
  -- select current selected objects
  editor.setObjectSelectedBool(editor.selection.object, true)
  editor.computeSelectionBBox()
  extensions.hook("onEditorObjectSelectionChanged")
end

local function setObjectTransformUndo(actionData)
  local obj = Sim.findObjectById(actionData.objectId)
  if obj then
    obj:setTransform(editor.tableToMatrix(actionData.oldTransform))
  end
  editor.computeSelectionBBox()
  if editor.updateObjectSelectionAxisGizmo then editor.updateObjectSelectionAxisGizmo() end
end

local function setObjectTransformRedo(actionData)
  local obj = Sim.findObjectById(actionData.objectId)
  if obj then
    obj:setTransform(editor.tableToMatrix(actionData.newTransform))
  end
  editor.computeSelectionBBox()
  if editor.updateObjectSelectionAxisGizmo then editor.updateObjectSelectionAxisGizmo() end
end

local function setObjectScaleUndo(actionData)
  local obj = Sim.findObjectById(actionData.objectId)
  if obj then
    obj:setScale(actionData.oldScale)
  end
  editor.computeSelectionBBox()
  if editor.updateObjectSelectionAxisGizmo then editor.updateObjectSelectionAxisGizmo() end
end

local function setObjectScaleRedo(actionData)
  local obj = Sim.findObjectById(actionData.objectId)
  if obj then
    obj:setScale(actionData.newScale)
  end
  editor.computeSelectionBBox()
  if editor.updateObjectSelectionAxisGizmo then editor.updateObjectSelectionAxisGizmo() end
end

-------------------------------------------------------------------------------
-- Utility functions
-------------------------------------------------------------------------------

local function createObjectWithUndo(name, className)
  editor.history:commitAction("CreateObject", {name = name, className = className}, createObjectUndo, createObjectRedo)
  editor.setDirty()
end

local function deleteObjectWithUndo(objId)
  editor.history:commitAction("DeleteObject", {objectId = objId}, deleteObjectUndo, deleteObjectRedo)
  editor.clearObjectSelection()
  editor.setDirty()
end

local function deleteSelectedObjectsWithUndo()
  if not editor.selection.object or tableIsEmpty(editor.selection.object) then return end
  editor.history:beginTransaction("DeleteSelectedObjects")
  for _, objId in ipairs(editor.selection.object) do
    editor.history:commitAction("DeleteObject", {objectId = objId}, deleteObjectUndo, deleteObjectRedo)
  end
  editor.history:endTransaction()
  editor.clearObjectSelection()
  editor.setDirty()
end

local function changeObjectFieldWithUndo(objIds, fieldName, newFieldValue, arrayIndex)
  if arrayIndex and arrayIndex >= 0 then arrayIndex = tostring(arrayIndex) elseif not arrayIndex then arrayIndex = "" end
  local oldFieldValues = {}
  for i, id in ipairs(objIds) do
    local obj = Sim.findObjectById(id)
    if obj then
      oldFieldValues[i] = obj:getField(fieldName, arrayIndex)
    end
  end

  editor.history:commitAction("ChangeField", {objectIds = objIds, fieldName = fieldName, arrayIndex = arrayIndex, oldFieldValues = oldFieldValues, newFieldValue = newFieldValue}, changeObjectFieldUndo, changeObjectFieldRedo)
end

local function changeObjectFieldWithOldValues(objIds, fieldName, newFieldValue, oldFieldValues, arrayIndex)
  if arrayIndex and arrayIndex >= 0 then arrayIndex = tostring(arrayIndex) elseif not arrayIndex then arrayIndex = "" end
  editor.history:commitAction("ChangeField", {objectIds = objIds, fieldName = fieldName, arrayIndex = arrayIndex, oldFieldValues = oldFieldValues, newFieldValue = newFieldValue}, changeObjectFieldUndo, changeObjectFieldRedo)
end

local function changeObjectDynFieldWithUndo(objIds, fieldName, newFieldValue, arrayIndex)
  local oldFieldValues = {}
  for i, id in ipairs(objIds) do
    local obj = Sim.findObjectById(id)
    if obj then
      oldFieldValues[i] = obj:getDynDataFieldbyName(fieldName, arrayIndex)
    end
  end
  editor.history:commitAction("ChangeDynField", {objectIds = objIds, fieldName = fieldName, arrayIndex = arrayIndex, oldFieldValues = oldFieldValues, newFieldValue = newFieldValue}, changeObjectDynFieldUndo, changeObjectDynFieldRedo)
end

local function lockObjectSelectionWithUndo()
  changeObjectFieldWithUndo(editor.selection.object, "locked", "true")
end

local function unlockObjectSelectionWithUndo()
  changeObjectFieldWithUndo(editor.selection.object, "locked", "false")
end

local function hideObjectSelectionWithUndo()
  changeObjectFieldWithUndo(editor.selection.object, "hidden", "true")
end

local function showObjectSelectionWithUndo()
  changeObjectFieldWithUndo(editor.selection.object, "hidden", "false")
end

local function callHookUndo(actionData)
  extensions.hook(actionData.hookName, unpack(actionData.args))
end

local function callHookRedo(actionData)
  extensions.hook(actionData.hookName, unpack(actionData.args))
end

local function callHookWithUndo(hookName, ...)
  editor.history:commitAction("CallHook", { hookName = hookName, args = {...} },
  callHookUndo, callHookRedo)
end

local M = {}

M.createObjectUndo = createObjectUndo
M.createObjectRedo = createObjectRedo
M.deleteObjectUndo = deleteObjectUndo
M.deleteObjectRedo = deleteObjectRedo
M.changeObjectFieldUndo = changeObjectFieldUndo
M.changeObjectFieldRedo = changeObjectFieldRedo
M.changeObjectDynFieldUndo = changeObjectDynFieldUndo
M.changeObjectDynFieldRedo = changeObjectDynFieldRedo
M.selectObjectsUndo = selectObjectsUndo
M.selectObjectsRedo = selectObjectsRedo
M.setObjectTransformUndo = setObjectTransformUndo
M.setObjectTransformRedo = setObjectTransformRedo
M.setObjectScaleUndo = setObjectScaleUndo
M.setObjectScaleRedo = setObjectScaleRedo

M.createObjectWithUndo = createObjectWithUndo
M.deleteObjectWithUndo = deleteObjectWithUndo
M.deleteSelectedObjectsWithUndo = deleteSelectedObjectsWithUndo
M.changeObjectFieldWithUndo = changeObjectFieldWithUndo
M.changeObjectFieldWithOldValues = changeObjectFieldWithOldValues
M.changeObjectDynFieldWithUndo = changeObjectDynFieldWithUndo
M.callHookWithUndo = callHookWithUndo

return function()
  editor.lockObjectSelectionWithUndo = lockObjectSelectionWithUndo
  editor.unlockObjectSelectionWithUndo = unlockObjectSelectionWithUndo
  editor.hideObjectSelectionWithUndo = hideObjectSelectionWithUndo
  editor.showObjectSelectionWithUndo = showObjectSelectionWithUndo
  return M
end