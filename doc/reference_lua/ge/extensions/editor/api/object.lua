-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-------------------------------------------------------------------------------
-- Exposed event hooks
-------------------------------------------------------------------------------
-- onEditorObjectCreated
-- onEditorObjectDelete
-- onEditorObjectSelectionChanged
-- onEditorObjectSelectionLocked
-- onEditorObjectSelectionUnlocked
-- onEditorObjectSelectionShown
-- onEditorObjectSelectionHidden
-- onEditorObjectSelectionTransformChanged
-- onEditorPrefabCreated
-- onEditorPrefabExploded

local editor

local selectionCentroidValid = false
local selectionCentroid = vec3(0, 0, 0)
local selectionBoxCentroid = vec3(0, 0, 0)
local containsGlobalBounds = false

local im = ui_imgui

local function matrixToTable(mtx)
  return {
    c0 = mtx:getColumn(0),
    c1 = mtx:getColumn(1),
    c2 = mtx:getColumn(2),
    c3 = mtx:getColumn(3)}
end

local function tableToMatrix(tbl)
  local mtx = MatrixF(true)
  mtx:setColumn(0, tbl.c0)
  mtx:setColumn(1, tbl.c1)
  mtx:setColumn(2, tbl.c2)
  mtx:setColumn(3, tbl.c3)
  return mtx
end

local function canManipulateObject(object)
  if object then
    return object:getClassName() ~= "SimSet"
          and object:getClassName() ~= "SimGroup"
          and not object:isLocked()
  else
    return false
  end
end

local function isObjectSelectable(object)
  if object:isSubClassOf("SceneObject") then
    return object:isSelectionEnabled()
  else
    return true
  end
end

local function isObjectSelectionEmpty()
  return (not editor.selection.object or tableIsEmpty(editor.selection.object))
end

local function updateCentroid()
  if selectionCentroidValid then
    return
  end

  selectionCentroidValid = true
  selectionCentroid:set(0, 0, 0)
  selectionBoxCentroid = selectionCentroid
  local bbox = Box3F()
  bbox:setExtents(vec3(-1e10 - 1e10, -1e10 - 1e10, -1e10 - 1e10))
  bbox:setCenter(vec3(0, 0, 0))
  containsGlobalBounds = false

  if editor.isObjectSelectionEmpty() then
    return
  end

  for _, objId in ipairs(editor.selection.object) do
    local obj = scenetree.findObjectById(objId)
    if obj and obj.getTransform then
      local mat = obj:getTransform()
      local wPos = mat:getColumn(3)

      selectionCentroid.x = selectionCentroid.x + wPos.x
      selectionCentroid.y = selectionCentroid.y + wPos.y
      selectionCentroid.z = selectionCentroid.z + wPos.z

      local objBounds = obj:getWorldBox()
      bbox:extend(objBounds.minExtents)
      bbox:extend(objBounds.maxExtents)

      if obj:isGlobalBounds() then
        containsGlobalBounds = true
      end
    end
  end

  local numObjects = tableSize(editor.selection.object)

  selectionCentroid.x = selectionCentroid.x / numObjects;
  selectionCentroid.y = selectionCentroid.y / numObjects;
  selectionCentroid.z = selectionCentroid.z / numObjects;
  selectionBoxCentroid = bbox:getCenter()
end

local function getSelectionCentroid()
  if editor.isObjectSelectionEmpty() then
    return vec3(0, 0, 0)
  end

  if containsGlobalBounds then
    return selectionCentroid
  end

  if editor.getPreference("gizmos.general.useObjectBoxCenter") then
    return selectionBoxCentroid
  end

  return selectionCentroid
end

local function computeSelectionBBox(updateGizmo)
  if updateGizmo == nil then updateGizmo = true end
  editor.objectSelectionBBox = Box3F()
  editor.objectSelectionBBox.minExtents:set(editor.FloatMax, editor.FloatMax, editor.FloatMax)
  editor.objectSelectionBBox.maxExtents:set(editor.FloatMin, editor.FloatMin, editor.FloatMin)

  if tableIsEmpty(editor.selection.object) then
    return
  end

  for i = 1, tableSize(editor.selection.object) do
    local obj = Sim.findObjectById(editor.selection.object[i])
    if obj and obj.getWorldBox then
      local wb = obj:getWorldBox()
      editor.objectSelectionBBox:extend(wb.minExtents)
      editor.objectSelectionBBox:extend(wb.maxExtents)
    end
  end

  selectionCentroidValid = false
  editor.objectSelectionRadius = editor.objectSelectionBBox:getLength() * 0.5
  updateCentroid()
  if updateGizmo then
    editor.updateObjectSelectionAxisGizmo()
  end
end

local function getFieldValue(objectId, fieldName, arrayIndex)
  local obj = Sim.findObjectById(objectId)
  if arrayIndex and arrayIndex >= 0 then arrayIndex = tostring(arrayIndex) elseif not arrayIndex then arrayIndex = "" end
  if obj then
    return obj:getField(fieldName, arrayIndex)
  end
  return ""
end

local function setObjectSelectedBool(objectIds, selected)
  if objectIds then
    for _, objId in ipairs(objectIds) do
      local obj = scenetree.findObjectById(objId)
      if obj then obj:setSelected(selected or false) end
    end
  end
end

local function setObjectSelectedBoolSingle(objectId, selected)
  if objectId then
    local obj = scenetree.findObjectById(objectId)
    if obj then obj:setSelected(selected) end
  end
end

--- This function will enable editing mode on all objects. Usually used internally by the toggle editor mode.
-- @param enable if true, it will enable the edit mode on the objects
local function enableEditorOnObjects(enable)
  if not levelLoaded then return end
  local objs = scenetree.getAllObjects()
  for _, objName in pairs(objs) do
    local obj = scenetree.findObject(objName)
    if obj and type(obj["onEditorEnable"]) == "function" and type(obj["onEditorDisable"]) == "function" then
      if enable then
        obj:onEditorEnable()
      else
        obj:onEditorDisable()
      end
    end
  end
end

local function validateObjectName(name, newName)
  if newName and name == "" then
    return false
  end
  if not isValidObjectName(name) then
    return false
  end
  return true
end

--- Set an object's field value.
-- For dynamic fields, use `editor.setDynamicFieldValue`
-- @param objectId [number] the object id
-- @param fieldName [string] the field name
-- @param fieldValue [string] the field value as string
local function setFieldValue(objectId, fieldName, value, arrayIndex)
  local obj = Sim.findObjectById(objectId)
  if obj then
    obj:preApply()
    obj:setField(fieldName, tostring(arrayIndex), value)
    obj:setEditorDirty(true)
    obj:postApply()
  end
end

--- Set an object's dynamic field value.
-- For static fields, use `editor.setFieldValue`
-- @param objectId [number] the object id
-- @param fieldName [string] the field name
-- @param fieldValue [string] the field value as string
local function setDynamicFieldValue(objectId, fieldName, value, arrayIndex)
  local obj = Sim.findObjectById(objectId)
  if obj then
    obj:preApply()
    obj:setDynDataFieldbyName(fieldName, arrayIndex or 0, value)
    obj:setEditorDirty(true)
    obj:postApply()
  end
end

--- Returns a table with object field information
-- @param objectId the object's id
-- @param fieldName the field name
-- @returns the field info table
local function getFieldInfo(objectId, fieldName)
  local obj = Sim.findObjectById(objectId)
  if obj then
    return
    {
      type = obj:getFieldType(fieldName),
      flags = obj:getFieldFlags(fieldName)
    }
  end
  return {}
end

local function getFields(objectId)
  local obj = Sim.findObjectById(objectId)
  if obj then
    return obj:getFieldsForEditor()
  end
  return nil
end

local function getDynamicFields(objectId)
  local obj = Sim.findObjectById(objectId)
  if obj then
    return obj:getDynamicFields()
  end
  return nil
end

local function copyFields(objectID)
  local result = {}
  result.fields = {}
  result.dynamicFields = {}
  result.arrayElements = {}

  local fields = editor.getFields(objectID)

  local fieldData = {}
  for fieldName, data in pairs(fields) do
    fieldData[data.id] = data
    fieldData[data.id].fieldName = fieldName
  end

  local sortedFieldData = {}

  local i = 0
  while true do
    if fieldData[i] then
      table.insert(sortedFieldData, fieldData[i])
    end
    i = i + 1

    if tableSize(sortedFieldData) == tableSize(fieldData) then
      break
    end
  end

  local index = 1
  while index <= table.getn(sortedFieldData) do
    local data = sortedFieldData[index]
    if data.groupName ~= "Transform" and data.fieldName ~= "name" and data.fieldName ~= "persistentId" and data.fieldName ~= "parentGroup" then
      if data.type == "beginArray" then
        for i = 0, data.elementCount - 1 do
          for arrayFieldName, arrayField in pairs(data.fields) do
            local value = editor.getFieldValue(objectID, arrayFieldName, i)
            table.insert(result.arrayElements, {fieldName = arrayFieldName, arrayIndex = i, value = value})
          end
        end
      else
        local value = editor.getFieldValue(objectID, data.fieldName)
        if value then
          result.fields[data.fieldName] = value
        end
      end
    end
    index = index + 1
  end

  local dynamicFields = editor.getDynamicFields(objectID)
  for _, fieldName in ipairs(dynamicFields) do
    local value = editor.getFieldValue(objectID, fieldName)
    if value then
      result.dynamicFields[fieldName] = value
    end
  end

  return result
end

local function pasteFields(fields, targetObjectID)
  if fields.fields then
    for fieldName, value in pairs(fields.fields) do
      editor.setFieldValue(targetObjectID, fieldName, value)
    end
  end

  if fields.arrayElements then
    for _, data in ipairs(fields.arrayElements) do
      editor.setFieldValue(targetObjectID, data.fieldName, data.value, data.arrayIndex)
    end
  end

  if fields.dynamicFields then
    for fieldName, value in pairs(fields.dynamicFields) do
      editor.setDynamicFieldValue(targetObjectID, fieldName, value)
    end

    if fields.dynamicFields["useTemplate"] == "true" then
      editor_roadUtils.reloadTemplates()
    end
  end
  editor.setDirty()
end

local function deleteSelectedObjects()
  if not editor.selection.object then return end
  for i = 1, tableSize(editor.selection.object) do
    editor.deleteObject(editor.selection.object[i])
  end
  editor.selection.object = {}
end

local function clearObjectSelection()
  -- deselect current selected objects
  editor.setObjectSelectedBool(editor.selection.object, false)
  editor.selection.object = nil
  editor.computeSelectionBBox()
  extensions.hook("onEditorObjectSelectionChanged")
end

local function modifySelection(idArray, selectMode)
  local selectionChanged = false
  if not idArray or tableIsEmpty(idArray) then return false end
  -- new selection
  if selectMode == editor.SelectMode_New or not selectMode then
    -- deselect for C++ the old selection
    setObjectSelectedBool(editor.selection.object, false)
    editor.selection = {}
    editor.selection.object = idArray
    selectionChanged = true
  -- add to selection
  elseif selectMode == editor.SelectMode_Add then
    if not editor.selection.object then editor.selection.object = {} end
    for i = 1, tableSize(idArray) do
      if not arrayFindValueIndex(editor.selection.object, idArray[i]) then
        table.insert(editor.selection.object, idArray[i])
        selectionChanged = true
      end
    end
  -- remove from selection
  elseif selectMode == editor.SelectMode_Remove then
    if not editor.selection.object then editor.selection.object = {} end
    local idx
    for i = 1, tableSize(idArray) do
      idx = arrayFindValueIndex(editor.selection.object, idArray[i])
      if idx then
        -- deselect for C++ the old selection
        setObjectSelectedBoolSingle(editor.selection.object[idx], false)
        table.remove(editor.selection.object, idx)
        selectionChanged = true
      end
    end
  -- toggle selection
  elseif selectMode == editor.SelectMode_Toggle then
    if not editor.selection.object then editor.selection.object = {} end
    local idx
    for i = 1, tableSize(idArray) do
      idx = arrayFindValueIndex(editor.selection.object, idArray[i])
      if idx then
        -- deselect for C++ the old selection
        setObjectSelectedBoolSingle(editor.selection.object[idx], false)
        table.remove(editor.selection.object, idx)
      else
        table.insert(editor.selection.object, idArray[i])
      end
      selectionChanged = true
    end
  end

  if selectionChanged then
    computeSelectionBBox()
    -- select for C++
    setObjectSelectedBool(editor.selection.object, true)
  end

  return selectionChanged
end

--- Select object ids.
-- @param idArray* - the array of object IDs
-- @param selectMode* - the select mode (if nil/not present, the mode is *editor.SelectMode_New*):
-- *editor.SelectMode_New* - the old selection is discarded
-- *editor.SelectMode_Add* - add (uniquely) the object ids to the current selection
-- *editor.SelectMode_Remove* - remove the ids from the current selection (if present)
-- *editor.SelectMode_Toggle* - if the ids are present, remove them, if they're absent, add them
local function selectObjects(idArray, selectMode)
  local oldSel = deepcopy(editor.selection.object)
  local selChanged = modifySelection(idArray, selectMode)
  -- deselect current selected objects
  editor.setObjectSelectedBool(oldSel, false)
  -- select current selected objects
  editor.setObjectSelectedBool(editor.selection.object, true)
  editor.computeSelectionBBox()
  if selChanged then extensions.hook("onEditorObjectSelectionChanged") end
  return selChanged
end

local function selectObjectsByRef(objects, selectMode)
  local idArray = {}

  for _, object in ipairs(objects) do
    table.insert(idArray, object:getID())
  end

  return selectObjects(idArray, selectMode)
end

--- Select objects by a rectangle in the current camera viewport, screen space.
-- @param rect the 2D screen viewport rectangle object
-- @param selectMode the selection mode, see editor.selectObjects
local function getObjectsByRectangle(rect, forestData)
  local viewportSizeIm = im.GetMainViewport().Size
  local viewportSize = vec3(viewportSizeIm.x, viewportSizeIm.y, 0)

  local viewFrustum = Engine.sceneGetCameraFrustum()
  local rectFrustum = Frustum(
                      false,
                      viewFrustum:getNearLeft() * (viewportSize.x/2 - rect.topLeft.x)/(viewportSize.x/2),
                      viewFrustum:getNearRight() * (rect.bottomRight.x - viewportSize.x/2)/(viewportSize.x/2),
                      viewFrustum:getNearTop() * (viewportSize.y/2 - rect.topLeft.y)/(viewportSize.y/2),
                      viewFrustum:getNearBottom() * (rect.bottomRight.y - viewportSize.y/2)/(viewportSize.y/2),
                      viewFrustum:getNearDist(),
                      viewFrustum:getFarDist(),
                      viewFrustum:getCameraCenterOffset(),
                      viewFrustum:getTransform())

  if forestData then
    return forestData:getItemsFrustum(rectFrustum), rectFrustum
  else
    local defaultFlags = bit.bor(SOTTerrain, SOTWater, SOTStaticShape, SOTPlayer, SOTItem, SOTVehicle, SOTLight)
    return findObjectListFrustum(rectFrustum, defaultFlags), rectFrustum
  end
end

local function selectObjectsByNameMask(nameMask, selectMode)
  local objects = scenetree.getAllObjects()
  local newSelection = {}
  for _, objName in pairs(objects) do
    if string.find(objName, nameMask) then
      --TODO: cant we get the object refs and not the names? faster
      local obj = scenetree.findObject(objName)
      --TODO: insert unique
      if obj then
        table.insert(newSelection, obj:getId())
      end
    end
  end
  local selChanged = modifySelection(newSelection, selectMode)
  if selChanged then extensions.hook("onEditorObjectSelectionChanged") end
  return selChanged
end

--- Select objects by class name.
-- @param className the class name of the objects to be selected
-- @param selectMode the selection mode, see editor.selectObjects
local function selectObjectsByType(typeName, selectMode)
  local objects = scenetree.getAllObjects()
  local newSelection = {}
  for _, objName in pairs(objects) do
    --TODO: cant we get the object refs and not the names? faster
    local obj = scenetree.findObject(objName)
    if obj and obj.className == typeName then
      --TODO: insert unique
      table.insert(newSelection, obj:getId())
      editor.logDebug("Selected by type: ".. objName .. " id: " .. tostring(obj:getId()))
    end
    if not obj then
      editor.logDebug("Cannot find ".. objName)
    end
  end
  local selChanged = modifySelection(newSelection, selectMode)
  if selChanged then extensions.hook("onEditorObjectSelectionChanged") end
  return selChanged
end

--- Select object by id, using selectMode.
-- @param id the object id
-- @param selectMode the selection mode, see editor.selectObjects
local function selectObjectById(id, selectMode)
  local selChanged = modifySelection({id}, selectMode)
  if selChanged then extensions.hook("onEditorObjectSelectionChanged") end
  return selChanged
end

local function deselectObjectSelection()
  -- deselect current selected objects
  setObjectSelectedBool(editor.selection.object, false)
  editor.selection.object = {}
  extensions.hook("onEditorObjectSelectionChanged")
end

--- Select all the objects in the level, care must be taken this might slow things down for various operations
local function lockObjectSelection()
  for i = 1, tableSize(editor.selection.object) do
    editor.setFieldValue(editor.selection.object[i], "locked", "true")
  end
end

local function unlockObjectSelection()
  for i = 1, tableSize(editor.selection.object) do
    editor.setFieldValue(editor.selection.object[i], "locked", "false")
  end
end

local function hideObjectSelection()
  for i = 1, tableSize(editor.selection.object) do
    editor.setFieldValue(editor.selection.object[i], "hidden", "true")
  end
end

local function showObjectSelection()
  for i = 1, tableSize(editor.selection.object) do
    editor.setFieldValue(editor.selection.object[i], "hidden", "false")
  end
end

--- Align objects by their bounding box, on the specific axis.
-- @param boundsAxis the axis for the bounds, values allowed:
-- *editor.AxisX* - the X axis
-- *editor.AxisY* - the Y axis
-- *editor.AxisZ* - the Z axis
local function alignObjectSelectionByBounds(boundsAxis)
  if boundsAxis < 0 or boundsAxis > 5 then
    return false
  end
  if tableSize(editor.selection.object) < 2 then
    return true
  end
  local axis = editor.AxisX
  local useMax = false

  if boundsAxis >= 3 then
    axis = boundsAxis - 3
  else
    axis = boundsAxis;
    useMax = true
  end

  -- find out which selected object has its bounds the farthest out
  local pos = 0
  local baseObjIndex = 0

  if useMax then
    pos = editor.FloatMin
  else
    pos = editor.FloatMax
  end

  for i = 2, tableSize(editor.selection.object) do
    local object = Sim.findObjectById(editor.selection.object[i])
    if object then
      local bounds = object:getWorldBox()
      if useMax then
        if bounds.maxExtents:getAxis(axis) > pos then
          pos = bounds.maxExtents:getAxis(axis)
          baseObjIndex = i;
        end
      else
        if bounds.minExtents:getAxis(axis) < pos then
          pos = bounds.minExtents:getAxis(axis)
          baseObjIndex = i
        end
      end
    end
  end
  -- move all selected objects to align with the calculated bounds
  for i = 1, tableSize(editor.selection.object) do
    if i ~= baseObjIndex then
      local object = Sim.findObjectById(editor.selection.object[i])
      if object then
        local bounds = object:getWorldBox()
        local delta = 0
        if useMax then
          delta = pos - bounds.maxExtents:getAxis(axis)
        else
          delta = pos - bounds.minExtents:getAxis(axis)
        end
        local objPos = object:getPosition()
        objPos:setAxis(axis, objPos:getAxis(axis) + delta)
        local newPosStr = tostring(objPos.x) .. " " .. tostring(objPos.y) .. " " .. tostring(objPos.z)
        editor.setFieldValue(object:getID(), "position", newPosStr)
      end
    end
  end
end

--- Align objects by their common averaged center, on the specific axis.
-- @param axis the center axis, values allowed:
-- *editor.AxisX* - the X axis
-- *editor.AxisY* - the Y axis
-- *editor.AxisZ* - the Z axis
local function alignObjectSelectionByCenter(axis)
  if axis < 0 or axis > 2 then
    return false
  end
  if tableSize(editor.selection.object) < 2 then
    return true
  end
  local object = Sim.findObjectById(editor.selection.object[1])
  if not object then
    return false
  end
  -- all objects will be repositioned to line up with the first selected object
  local pos = object:getPosition()
  for i = 1, tableSize(editor.selection.object) do
    local object = Sim.findObjectById(editor.selection.object[i])
    if canManipulateObject(object) then
      local objPos = object:getPosition()
      objPos:setAxis(axis, pos:getAxis(axis))
      local newPosStr = tostring(objPos.x) .. " " .. tostring(objPos.y) .. " " .. tostring(objPos.z)
      editor.setFieldValue(object:getID(), "position", newPosStr)
    end
  end
end

local function setObjectSelectionTransformFromCamera()
  local camMtx = editor.getCamera():getTransform()
  --TODO: undo
  for i = 1, tableSize(editor.selection.object) do
    local object = Sim.findObjectById(editor.selection.object[i])
    if canManipulateObject(object) then
      local objScl = object:getScale()
      object:setTransform(camMtx)
      object:setScale(objScl)
    end
  end
end

--- Reset the object selection transform, sets rotation to zero and scale to 1,1,1.
local function resetObjectSelectionTransform()
  editor.resetObjectSelectionRotation()
  editor.resetObjectSelectionScale()
end

--- Reset the object selection's rotation to zero.
local function resetObjectSelectionRotation()
  for i = 1, tableSize(editor.selection.object) do
    local object = Sim.findObjectById(editor.selection.object[i])
    if canManipulateObject(object) then
      editor.setFieldValue(object:getId(), "rotation", "0 0 0 0")
    end
  end
end

--- Reset the object selection's scale to 1,1,1.
local function resetObjectSelectionScale()
  for i = 1, tableSize(editor.selection.object) do
    local object = Sim.findObjectById(editor.selection.object[i])
    if canManipulateObject(object) then
      editor.setFieldValue(object:getId(), "scale", "1 1 1")
    end
  end
end

--- Translate the object selection by the delta value.
-- @param deltaTranslate [vec3] delta value to move the selection
local function translateObjectSelection(deltaTranslate)
  for i = 1, tableSize(editor.selection.object) do
    local object = Sim.findObjectById(editor.selection.object[i])
    if canManipulateObject(object) and object.getPosition then
      local pos = object:getPosition()
      pos = pos + deltaTranslate
      editor.setFieldValue(object:getId(), "position", tostring(pos.x) .. " " .. tostring(pos.y) .. " " .. tostring(pos.z))
    end
  end
end

local function copyMat(mat)
  if mat then
    return mat * MatrixF(true)
  else
    return MatrixF(true)
  end
end

--- Rotate the selected objects by the delta quaternion.
-- @param deltaRotation* [QuatF] the delta quaternion object
-- @param centerPoint [vec3] if not nil, will be used to scale around it, relative to it
local function rotateObjectSelection(gizmoTransform, centerPoint, initialTransformations, initialGizmoTransform)
  if not initialTransformations then return end
  for i = 1, tableSize(editor.selection.object) do
    local object = Sim.findObjectById(editor.selection.object[i])
    if editor.canManipulateObject(object) then

      -- Rotate the positions
      local initialObjectRot = QuatF(1,1,1,1)
      initialObjectRot:setFromMatrix(initialTransformations[i])
      initialObjectRot = quat(initialObjectRot)

      local initialGizmoRot = QuatF(1,1,1,1)
      initialGizmoRot:setFromMatrix(initialGizmoTransform)
      initialGizmoRot = quat(initialGizmoRot)
      local inverseGizmoRot = initialGizmoRot:inversed()

      local currentGizmoRot = QuatF(1,1,1,1)
      currentGizmoRot:setFromMatrix(gizmoTransform)
      currentGizmoRot = quat(currentGizmoRot)
      local diffRot = currentGizmoRot:__div(initialGizmoRot)

      local objectPos = initialTransformations[i]:getColumn(3)
      objectPos = objectPos - centerPoint
      objectPos = inverseGizmoRot * objectPos
      objectPos = diffRot:__mul(objectPos)
      objectPos = initialGizmoRot * objectPos
      objectPos = objectPos + centerPoint

      local objectRot = initialObjectRot
      objectRot = objectRot * inverseGizmoRot
      objectRot = objectRot:__mul(diffRot)
      objectRot = objectRot * initialGizmoRot
      object:setPosRot(objectPos.x, objectPos.y, objectPos.z, objectRot.x, objectRot.y, objectRot.z, objectRot.w)
    end
  end
end

local minScale = 0.01
local maxScale = 1000

--- Scale the selected objects by the delta scale.
-- @param deltaScale [vec3] delta scale value
-- @param centerPoint [vec3] if not nil, will be used to scale around it, relative to it
local function scaleObjectSelection(deltaScale, centerPoint)
  if deltaScale:length() == 0 then return end
  local objects = {}

  -- Adjust the delta scale based on the maximum scale of the selected objects
  local currentMax = 0
  for i = 1, tableSize(editor.selection.object) do
    objects[i] = Sim.findObjectById(editor.selection.object[i])
    local object = objects[i]
    local scale = object:getScale()
    currentMax = math.max(math.abs(scale.x * sign(deltaScale.x)), currentMax)
    currentMax = math.max(math.abs(scale.y * sign(deltaScale.y)), currentMax)
    currentMax = math.max(math.abs(scale.z * sign(deltaScale.z)), currentMax)
  end
  currentMax = currentMax / 2
  local adjustedDeltaScale = vec3(deltaScale.x / currentMax, deltaScale.y / currentMax, deltaScale.z / currentMax)
  local delta = vec3(1,1,1) + adjustedDeltaScale

  -- Get minimum/maximum nextScale
  local minNextScale = math.huge
  local maxNextScale = -math.huge
  local minPrevScale = math.huge
  local maxPrevScale = -math.huge
  for i = 1, tableSize(editor.selection.object) do
    local object = objects[i]
    local prevScale = object:getScale()
    minNextScale = math.min(prevScale.x * delta.x, prevScale.y * delta.y, prevScale.z * delta.z, minNextScale)
    maxNextScale = math.max(prevScale.x * delta.x, prevScale.y * delta.y, prevScale.z * delta.z, maxNextScale)

    -- Get the minimum axis from the axes that are being edited
    local adjustedPrevScale = vec3(deltaScale.x == 0 and math.huge or prevScale.x,
                                  deltaScale.y == 0 and math.huge or prevScale.y,
                                  deltaScale.z == 0 and math.huge or prevScale.z)
    minPrevScale = math.min(adjustedPrevScale.x, adjustedPrevScale.y, adjustedPrevScale.z)

    -- Get the maximum axis from the axes that are being edited
    local adjustedPrevScale = vec3(deltaScale.x == 0 and -math.huge or prevScale.x,
                                  deltaScale.y == 0 and -math.huge or prevScale.y,
                                  deltaScale.z == 0 and -math.huge or prevScale.z)
    maxPrevScale = math.max(adjustedPrevScale.x, adjustedPrevScale.y, adjustedPrevScale.z)
  end

  local center = centerPoint or vec3(editor.objectSelectionBBox:getCenter())
  for i = 1, tableSize(editor.selection.object) do
    local object = objects[i]
    if canManipulateObject(object) then
      local prevScale = object:getScale()
      local nextScale = vec3(prevScale.x * delta.x, prevScale.y * delta.y, prevScale.z * delta.z)

      -- clamp scale to sensible limits
      if minNextScale < minScale then
        -- Scale the object so that its smallest axis is equal to minScale, but ignore the axes that are not being edited
        nextScale = (prevScale / minPrevScale) * minScale
      elseif maxNextScale > maxScale then
        -- Scale the object so that its biggest axis is equal to maxScale, but ignore the axes that are not being edited
        nextScale = (prevScale / maxPrevScale) * maxScale
      end
      if deltaScale.x == 0 then nextScale.x = prevScale.x end
      if deltaScale.y == 0 then nextScale.y = prevScale.y end
      if deltaScale.z == 0 then nextScale.z = prevScale.z end

      -- apply the scale first, if the object's scale doesn't change with
      -- this operation then this object doesn't scale.  In this case
      -- we don't want to continue with the offset operation.
      object:setScale(nextScale)

      -- determine the actual scale factor to apply to the object offset
      -- need to account for the scale limiting above to prevent offsets
      -- being reduced to 0 which then cannot be restored by unscaling
      local adjustedScale = vec3()
      adjustedScale.x = nextScale.x / prevScale.x
      adjustedScale.y = nextScale.y / prevScale.y
      adjustedScale.z = nextScale.z / prevScale.z

      local mat = object:getTransform()
      local pos = mat:getColumn(3)
      local offset = pos - center

      -- Convert to local rotation, then scale the offset and rotate back
      local rot = QuatF(0,0,0,1)
      rot:setFromMatrix(editor.getAxisGizmoTransform())
      offset = quat(rot):inversed() * offset
      offset.x = offset.x * adjustedScale.x
      offset.y = offset.y * adjustedScale.y
      offset.z = offset.z * adjustedScale.z
      offset = quat(rot) * offset

      local newPos = offset + center
      object:setPosition(newPos)
    end
  end
end

local function getObjectLevelRec(object, level)
  local parent = object:getGroup()
  if parent then
    level = level + 1
    return getObjectLevelRec(parent, level)
  end
  return level
end

local function getObjectLevel(object)
  return getObjectLevelRec(object, 0)
end

local function getHighestObject(objects)
  local levelHighestObject = math.huge
  local highestObject
  for i, id in ipairs(objects) do
    local object = scenetree.findObjectById(id)
    local level = getObjectLevel(object)
    if level < levelHighestObject then
      levelHighestObject = level
      highestObject = object
    end
  end
  return highestObject
end

--- Create a new prefab from the current selection.
-- @param newPrefabFilename prefab destination filename
--TODO: add undo
local function createPrefabFromObjectSelection(newPrefabFilename, objName, loadmode, pathNative)
  if tableIsEmpty(editor.selection.object) then
    return
  end

  local stack = {}
  local found = {}

  for i = 1, tableSize(editor.selection.object) do
    local obj = scenetree.findObjectById(editor.selection.object[i])
    if obj then table.insert(stack, obj) end
  end

  local cleanup = {}

  while #stack ~= 0 do
    local obj = stack[#stack]
    table.remove(stack, #stack)
    if Prefab.isValidChild(obj, true) then
      table.insert(found, obj)
    else
      local grp = obj
      if grp:isSubClassOf("SimGroup") and grp["size"] then
        for i = 0, grp:size() - 1 do
          table.insert(stack, grp:at(i))
        end
        if tableIsEmpty(cleanup) then -- we only need to delete the root simgroup which will delete every child
          table.insert(cleanup, grp)
        end
      end
    end
  end

  if 0 == #found then
    editor.logWarn("No valid objects selected.")
    return
  end
  local parentGroup = getHighestObject(editor.selection.object):getGroup()

  -- SimGroup we collect prefab objects into.
  local group = SimGroup()
  group:registerObject("")

  -- add the group to the MissionGroup object so it adds the proper __parent property to the prefab.json file
  parentGroup:addObject(group)

  -- Transform from World to Prefab space.
  local fabMat = MatrixF(true)
  editor.computeSelectionBBox()
  local centroid = editor.getSelectionCentroid()
  fabMat:setPosition(centroid)
  fabMat:inverse()

  group:setField("groupPosition", "", tostring(centroid.x) .. " " .. tostring(centroid.y) .. " " .. tostring(centroid.z))

  for i = 1, #found do
    local obj = Sim.upcast(found[i])
    if obj:isSubClassOf("SceneObject") then
      local objMat = MatrixF(true)
      objMat:mul(fabMat)
      objMat:mul(obj:getTransform())
      obj:setTransform(objMat)
      obj:setCanSave(true)
    end
    group:addObject(obj)
  end

  -- modify path real to virtual
  local fname
  if pathNative then fname = FS:native2Virtual(newPrefabFilename) else fname = newPrefabFilename end
  -- save out .prefab file
  --TODO: TS must be removed!
  local success = group:save(fname, false, "$ThisPrefab = ")
  if not success then
    editor.logError("Couldn't save prefab file at: " .. fname .. " (" .. newPrefabFilename .. ")")
  end

  -- allocate Prefab object and add to level
  local prefab = Prefab()
  prefab:setFile(BString(fname))
  local prefabFilename = string.match(newPrefabFilename, "[^/]*$")
  local prefabName = string.match(prefabFilename, "(.+)[.]")
  if prefabName then
    prefab:setName(prefabName)
  end
  fabMat:inverse()
  prefab:setTransform(fabMat)

  -- delete original objects and temporary SimGroup
  -- will solve name conflicts with the prefabs objects
  editor.onRemoveObjectFromSet(group, group:getGroup())
  group:deleteObject()

  for i = 1, #cleanup do
    if cleanup[i] ~= nil then
      editor.onRemoveObjectFromSet(cleanup[i], cleanup[i]:getGroup())
      cleanup[i]:deleteObject()
    end
  end

  -- now register prefab
  prefab:registerObject("")
  parentGroup:addObject(prefab)

  -- select it, mark level as dirty
  editor.clearObjectSelection()
  editor.selectObjectById(prefab:getId())
  editor.computeSelectionBBox()
  editor.setDirty()

  -- set the prefab load mode
  if loadmode then
    if loadmode == "auto" then
      prefab:setLoadMode(0) -- PREFAB_Load_Automatically, maybe export this enum to Lua
    else
      if loadmode == "manual" then
        prefab:setLoadMode(1) -- PREFAB_Load_Manually
        if prefab:isLoaded() then
          prefab:unload()
        end
      end
    end
  end

  return prefab
end

--- Explode the current selected object(s) from prefab to objects.
local function explodeSelectedPrefab()
  local prefabList = {}

  for i = 1, #editor.selection.object do
    local obj = scenetree.findObjectById(editor.selection.object[i])
    if obj then
      table.insert(prefabList, obj)
    end
  end

  if #prefabList == 0 then
    return
  end

  editor.clearObjectSelection()
  local groups = {}
  for i = 1, #prefabList do
    local prefab = prefabList[i]
    local newGroup = prefab:explode(true)
    if not newGroup then
      editor.logError("Could not explode prefab into a group " .. prefab:getName())
    else
      local name = "prefab"

      if prefab:getName() and prefab:getName() ~= "" then
          name = prefab:getName()
      end

      name = name .. "_unpacked"
      name = Sim.getUniqueName(name)
      newGroup:setName(name)
      prefab:deleteObject()
      table.insert(groups, newGroup)
      if editor_sceneTree then
        editor_sceneTree.refreshNodeNames({newGroup:getId()})
      end
    end
  end

  editor.setDirty()
  extensions.hook("onEditorPrefabExploded", groups)
  return groups
end

-- debug functions
local function debugObjectSelection()
  editor.logDebug("Selection:")
  for i = 1, tableSize(editor.selection.object) do
    local object = Sim.findObjectById(editor.selection.object[i])
    if object then
      editor.logDebug("Name: "..object.name.." ID: "..object:getID())
    end
  end
end

local function findFirstSelectedByType(classname)
  if editor.selection.object then
    for i = 1, tableSize(editor.selection.object) do
      local selectedObject = scenetree.findObjectById(editor.selection.object[i])
      if selectedObject and selectedObject:getClassName() == classname then
        return selectedObject
      end
    end
  end
  return nil
end

local function getObjectSelection()
  return editor.selection.object or {}
end

local function removeInvalidObjects(objectIds)
  local selection = deepcopy(objectIds)
  objectIds = {}
  for _, id in ipairs(selection) do
    if scenetree.findObjectById(id) then
      table.insert(objectIds, id)
    end
  end
  return objectIds
end

local function removeInvalidSelectedObjects()
  editor.selection.object = removeInvalidObjects(editor.selection.object)
end

local function initialize(editorInstance)
  editor = editorInstance
  editor.SelectMode_New = 1
  editor.SelectMode_Add = 2
  editor.SelectMode_Remove = 3
  editor.SelectMode_Toggle = 4
  editor.objectSelectionBBox = Box3F()

  editor.matrixToTable = matrixToTable
  editor.tableToMatrix = tableToMatrix
  editor.getObjectSelection = getObjectSelection
  editor.isObjectSelectionEmpty = isObjectSelectionEmpty
  editor.getSelectionCentroid = getSelectionCentroid
  editor.enableEditorOnObjects = enableEditorOnObjects
  editor.validateObjectName = validateObjectName
  editor.setFieldValue = setFieldValue
  editor.setDynamicFieldValue = setDynamicFieldValue
  editor.getFieldValue = getFieldValue
  editor.getFieldInfo = getFieldInfo
  editor.getFields = getFields
  editor.getDynamicFields = getDynamicFields
  editor.copyFields = copyFields
  editor.pasteFields = pasteFields
  editor.deleteSelectedObjects = deleteSelectedObjects
  editor.clearObjectSelection = clearObjectSelection
  editor.selectObjects = selectObjects
  editor.selectObjectsByRef = selectObjectsByRef
  editor.getObjectsByRectangle = getObjectsByRectangle
  editor.selectObjectsByNameMask = selectObjectsByNameMask
  editor.selectObjectsByType = selectObjectsByType
  editor.selectObjectById = selectObjectById
  editor.deselectObjectSelection = deselectObjectSelection
  editor.lockObjectSelection = lockObjectSelection
  editor.unlockObjectSelection = unlockObjectSelection
  editor.hideObjectSelection = hideObjectSelection
  editor.showObjectSelection = showObjectSelection
  editor.alignObjectSelectionByBounds = alignObjectSelectionByBounds
  editor.alignObjectSelectionByCenter = alignObjectSelectionByCenter
  editor.setObjectSelectionTransformFromCamera = setObjectSelectionTransformFromCamera
  editor.resetObjectSelectionTransform = resetObjectSelectionTransform
  editor.resetObjectSelectionRotation = resetObjectSelectionRotation
  editor.resetObjectSelectionScale = resetObjectSelectionScale
  editor.translateObjectSelection = translateObjectSelection
  editor.rotateObjectSelection = rotateObjectSelection
  editor.scaleObjectSelection = scaleObjectSelection
  editor.findFirstSelectedByType = findFirstSelectedByType
  editor.createPrefabFromObjectSelection = createPrefabFromObjectSelection
  editor.explodeSelectedPrefab = explodeSelectedPrefab
  editor.matrixToTable = matrixToTable
  editor.tableToMatrix = tableToMatrix
  editor.computeSelectionBBox = computeSelectionBBox
  editor.setObjectSelectedBool = setObjectSelectedBool
  editor.setObjectSelectedBoolSingle = setObjectSelectedBoolSingle
  editor.isObjectSelectable = isObjectSelectable
  editor.removeInvalidObjects = removeInvalidObjects
  editor.removeInvalidSelectedObjects = removeInvalidSelectedObjects
  editor.canManipulateObject = canManipulateObject
end

local M = {}
M.initialize = initialize

return M