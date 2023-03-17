-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_object_tool'
local imgui = ui_imgui
local objectHistoryActions = require("editor/api/objectHistoryActions")()
local copyObjectsArray = {}
local colorBlinkTimer = 0

local raycastMode = false
local clickedHoveredObject = false

local mouseDragStartPos = nil
local objectsInRect = {}
local duplicationDrag

local cubePoints =
{
  vec3(-0.5, -0.5, -0.5), vec3(-0.5, -0.5, 0.5), vec3(-0.5, 0.5, -0.5), vec3(-0.5, 0.5, 0.5),
  vec3(0.5, -0.5, -0.5), vec3(0.5, -0.5, 0.5), vec3(0.5, 0.5, -0.5), vec3(0.5, 0.5, 0.5)
}

local axisGizmoEventState = {
  mouseDown = false,
  objectSelectionManipulated = false,
  dragAndDuplicate = false,
  oldTransforms = {},
  oldScales = {},
  objectHeights = {},
  objects = {}
}

local function drawSelectionBBox(objMat, color)
  -- 8 corner points of the box
  for i = 1, 8 do
    -- 3 lines per corner point
    for j = 1, 3 do
      local startPt = vec3(cubePoints[i].x, cubePoints[i].y, cubePoints[i].z);
      local endPt = vec3(startPt.x, startPt.y, startPt.z);
      if j == 1 then
        endPt.x = endPt.x * 0.8
      end
      if j == 2 then
        endPt.y = endPt.y * 0.8
      end
      if j == 3 then
        endPt.z = endPt.z * 0.8
      end
      startPt = objMat:mulP3F(startPt)
      endPt = objMat:mulP3F(endPt)
      debugDrawer:drawLine(startPt, endPt, color)
    end
  end
end

local function drawSelectedObjectBBox(obj, color)
  -- if this SimObject is not a visual sceneobject with a transform, then ignore it
  if not obj["getTransform"] then return end

  if obj:isSubClassOf("BeamNGVehicle") then
    -- The vehicles are special, display the position and the rotation of the reference nodes instead
    local veh = Sim.upcast(obj)
    local pos = veh:getPosition()
    local rot = quat(veh:getRefNodeRotation())
    local scl = 1
    if not editor.getPreference("gizmos.general.fixedRefnodeVisualization") then
      local distance = (getCameraPosition() - pos):length()
      scl = clamp(distance/15, 0.0, 1.75) + 0.125
    end
    local alpha = 0.5
    debugDrawer:drawSphere(pos, 0.3*scl, ColorF(1,0,1,1*alpha))
    debugDrawer:drawCylinder(pos, pos + (rot * vec3(0, -2*scl, 0)), 0.1*scl, ColorF(1,0,0,1*alpha))
    debugDrawer:drawCylinder(pos, pos + (rot * vec3(0, 0, 2*scl)), 0.1*scl, ColorF(0,0,1,1*alpha))
    debugDrawer:drawCylinder(pos, pos + (rot * vec3(2*scl, 0, 0)), 0.1*scl, ColorF(0,1,0,1*alpha))
    return
  end

  local objMat = obj:getTransform()
  local objBox = obj:getObjBox()
  local objScale = obj:getScale()
  local boxScale = objBox:getExtents()
  local boxCenter = obj:getWorldBox():getCenter()

  objMat:scale(objScale)
  objMat:scale(boxScale)
  objMat:setPosition(boxCenter)
  drawSelectionBBox(objMat, color)
end

local scale = vec3(1, 1, 1)
local function updateObjectSelectionAxisGizmo()
  if editor.selection.object and not tableIsEmpty(editor.selection.object) then
    local xform = MatrixF(true)
    local obj = scenetree.findObjectById(editor.selection.object[#editor.selection.object])
    if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local then
      -- we use last object's transform when local gizmo alignment, for the selection
      if obj and obj.getTransform then
        xform = obj:getTransform()
      end
    end
    if tableSize(editor.selection.object) > 1 then
      if editor.getPreference("snapping.general.snapToGrid") and editor.getPreference("snapping.grid.useLastObjectSelected") then
        xform:setPosition(obj:getPosition())
      else
        xform:setPosition(editor.objectSelectionBBox:getCenter())
      end
    else
      if editor.getPreference("gizmos.general.useObjectBoxCenter") then
        xform:setPosition(editor.getSelectionCentroid())
      elseif obj and obj.getPosition then
        xform:setPosition(obj:getPosition())
      end
    end

    editor.setAxisGizmoTransform(xform, scale)
  end
end

local function getMementoFromSelection()
  local mementos = {}
  for _, id in ipairs(editor.selection.object) do
    local memento = SimObjectMemento()
    local obj = scenetree.findObjectById(id)
    if obj then
      memento:save(obj, 4) -- 2nd arg is flag SimObject::IgnoreCanSave
      editor.logDebug("Copy id " .. tostring(obj:getId()));
    end
    table.insert(mementos, memento)
  end
  return mementos
end

local function getParentIds(objectIDs)
  local parentIds = {}
  for i, id in ipairs(objectIDs) do
    local obj = scenetree.findObjectById(id)
    parentIds[i] = tonumber(obj:getField("parentGroup", 0))
  end
  return parentIds
end

local function pasteObjects(objectMementos, objectIDs, parentIds)
  if not parentIds then
    parentIds = getParentIds(editor.selection.object)
  end

  local newObjectIDs = {}
  local missionGroup = scenetree.MissionGroup
  for i, v in ipairs(objectMementos) do
    if objectIDs and objectIDs[i] then
      SimObject.setForcedId(objectIDs[i])
    end
    local obj = v:restore()
    if obj then
      if obj:getClassName() == "Prefab" then
        local pos = Sim.upcast(obj):getTransform():getColumn(3)
        local posString = "" .. pos.x .. " " .. pos.y .. " " .. pos.z
        local rot = Sim.upcast(obj):getRotation()
        local rotString = "" .. rot.x .. " " .. rot.y .. " " .. rot.z .. " " .. rot.w
        local scale = Sim.upcast(obj):getScale()
        local scaleString = "" .. scale.x .. " " .. scale.y .. " " .. scale.z
        local name = obj:getName()
        local filename = Sim.upcast(obj):getField('filename', '')
        obj:delete()
        if objectIDs and objectIDs[i] then
          SimObject.setForcedId(objectIDs[i])
        end
        obj = spawnPrefab(name, filename, posString, rotString, scaleString)
        if obj then
          obj.loadMode = 0
        end
      end
      if obj then
        local newGroup = nil
        if parentIds and parentIds[i] then newGroup = scenetree.findObjectById(parentIds[i]) end
        local grp = newGroup or missionGroup
        grp:addObject(obj)
        table.insert(newObjectIDs, obj:getId())
        if obj:isSubClassOf("DecalRoad") then -- regenerate, so the BB is correct immediately
          Sim.upcast(obj):regenerate()
        end
      end
    end
  end
  editor.clearObjectSelection()
  editor.selectObjects(newObjectIDs, editor.SelectMode_Add)
  editor.setDirty()
  return newObjectIDs
end

local function pasteObjectsRedo(actionData)
  if not actionData.parentIds then
    actionData.parentIds = getParentIds(editor.selection.object)
  end
  actionData.objectIds = pasteObjects(actionData.objects, actionData.objectIds, actionData.parentIds)
end

local function pasteObjectsUndo(actionData)
  for _, id in ipairs(actionData.objectIds) do
    editor.deleteObject(id)
  end
  editor.clearObjectSelection()
end

local function pasteAndPositionRedo(actionData)
  if not actionData.parentIds then
    actionData.parentIds = getParentIds(editor.selection.object)
  end
  actionData.objectIds = pasteObjects(actionData.objects, actionData.objectIds, actionData.parentIds)
  for i, id in ipairs(actionData.objectIds) do
    scenetree.findObjectById(id):setPosition(actionData.newPositions[i])
  end
  editor.selectObjects(actionData.objectIds, editor.SelectMode_New)
end

local pasteAndPositionUndo = pasteObjectsUndo

local function duplicateSelectionAtCamera()
  if editor.selection.object and editor.selection.object[1] then
    local camDir = quat(getCameraQuat()) * vec3(0,1,0)
    camDir = camDir * 10
    local targetPos = getCameraPosition() + camDir
    local newPositions = {}
    local delta = targetPos - editor.getAxisGizmoTransform():getColumn(3)
    for i, id in ipairs(editor.selection.object) do
      table.insert(newPositions, scenetree.findObjectById(editor.selection.object[i]):getPosition() + delta)
    end
    editor.history:commitAction("DuplicateObjectsAtCamera", {objects = getMementoFromSelection(), newPositions = newPositions}, pasteAndPositionUndo, pasteAndPositionRedo)
  end
end

local function repositionSelectionRedo(actionData)
  editor.clearObjectSelection()
  for i, id in ipairs(actionData.objects) do
    scenetree.findObjectById(id):setPosition(actionData.newPositions[i])
  end
  -- Reselects objects the first time
  actionData.nCount = actionData.nCount or 0
  if actionData.nCount == 0 then
    editor.selectObjects(actionData.objects, editor.SelectMode_New)
  end
  actionData.nCount = actionData.nCount + 1
end

local function repositionSelectionUndo(actionData)
  editor.clearObjectSelection()
  for i, id in ipairs(actionData.objects) do
    scenetree.findObjectById(id):setPosition(actionData.oldPositions[i])
  end
end

local function moveSelectionAtCamera()
  -- There must be at least 1 object selected
  if (editor.selection.object and editor.selection.object[1]) == nil then return end
  -- Calculates new positions and prepares history action data
  local camDir = quat(getCameraQuat()) * vec3(0,1,0)
  camDir = camDir * 10
  local targetPos = getCameraPosition() + camDir
  local delta = targetPos - editor.getAxisGizmoTransform():getColumn(3)
  local selectedObjects = {}  -- filtered selection
  local oldPositions = {}     -- old position tracker for undo
  local newPositions = {}     -- new position tracker for redo
  for i, id in ipairs(editor.selection.object) do
    local obj = scenetree.findObjectById(id)
    if obj:getClassName() ~= 'SimGroup' then   -- ignores groups
      table.insert(selectedObjects, id)
      local oldPosition = obj:getPosition()
      table.insert(oldPositions, oldPosition)  -- backs up old position
      table.insert(newPositions, oldPosition + delta)
    end
  end
  -- Adds history action
  if #selectedObjects ~= 0 then
    editor.history:commitAction(
      "MoveSelectionAtCamera",
      {
        objects = selectedObjects, --editor.selection.object,
        newPositions = newPositions,
        oldPositions = oldPositions
      },
      repositionSelectionUndo, repositionSelectionRedo)
  end
end

local function gizmoBeginDrag()
  axisGizmoEventState.oldTransforms = {}
  axisGizmoEventState.objectHeights = {}
  axisGizmoEventState.oldScales = {}
  local objectBBs = {}
  axisGizmoEventState.objects = {}
  axisGizmoEventState.dragAndDuplicate = false

  local objects = {}
  for i = 1, tableSize(editor.selection.object) do
    objects[i] = scenetree.findObjectById(editor.selection.object[i])
    if not editor.canManipulateObject(objects[i]) then
      return
    end
  end

  for i = 1, tableSize(editor.selection.object) do
    local obj = objects[i]
    if obj.getTransform then
      table.insert(axisGizmoEventState.objects, obj)
      table.insert(axisGizmoEventState.oldTransforms, obj:getTransform())
      table.insert(objectBBs, obj:getWorldBox())
      table.insert(axisGizmoEventState.objectHeights, obj:getObjBox().maxExtents.z)
      table.insert(axisGizmoEventState.oldScales, obj:getScale())
    end
  end
  -- lets check if we want to drag and duplicate the selection
  local shiftDown = editor.keyModifiers.shift

  if shiftDown and not tableIsEmpty(axisGizmoEventState.objects) then
    axisGizmoEventState.dragAndDuplicate = true
  end
  axisGizmoEventState.initialGizmoTransform = editor.getAxisGizmoTransform()
  if worldEditorCppApi.getAxisGizmoMode() == editor.AxisGizmoMode_Translate then
    editor.beginGizmoTranslate(axisGizmoEventState.oldTransforms, objectBBs, axisGizmoEventState.objectHeights, axisGizmoEventState.objects)
  end
end

local function gizmoDragging()
  if axisGizmoEventState.dragAndDuplicate and editor.keyModifiers.shift then
    -- ok, we duplicate
    axisGizmoEventState.dragAndDuplicate = false
    editor.duplicate()

    axisGizmoEventState.objects = {}
    for i = 1, tableSize(editor.selection.object) do
      local obj = scenetree.findObjectById(editor.selection.object[i])
      if obj and obj.getTransform then
        table.insert(axisGizmoEventState.objects, obj)
      end
    end
  end

  local objects = {}
  for i = 1, tableSize(editor.selection.object) do
    objects[i] = scenetree.findObjectById(editor.selection.object[i])
    if not editor.canManipulateObject(objects[i]) then
      return
    end
  end

  if worldEditorCppApi.getAxisGizmoMode() == editor.AxisGizmoMode_Translate then
    local newTransforms = editor.getTransformsGizmoTranslate(axisGizmoEventState.objects, axisGizmoEventState.objectHeights)
    for index, transform in ipairs(newTransforms) do
      local obj = objects[index]
      obj:setTransform(transform)
    end
  elseif worldEditorCppApi.getAxisGizmoMode() == editor.AxisGizmoMode_Rotate then
    editor.rotateObjectSelection(editor.getAxisGizmoTransform(), editor.getAxisGizmoTransform():getColumn(3), axisGizmoEventState.oldTransforms, axisGizmoEventState.initialGizmoTransform)
  elseif worldEditorCppApi.getAxisGizmoMode() == editor.AxisGizmoMode_Scale then
    local delta = worldEditorCppApi.getAxisGizmoScaleOffset()
    editor.scaleObjectSelection(delta, editor.getAxisGizmoTransform():getColumn(3))
  end
end

local function getMementoFromManipulableSelection()
  local mementos = {}
  for _, id in ipairs(editor.selection.object) do
    local memento = SimObjectMemento()
    local obj = scenetree.findObjectById(id)
    if obj then
      if editor.canManipulateObject(obj) then
        memento:save(obj, 4)
        table.insert(mementos, memento)
      end
    end
  end
  return mementos
end

local function gizmoEndDrag()
  local objects = {}
  for i = 1, tableSize(editor.selection.object) do
    objects[i] = scenetree.findObjectById(editor.selection.object[i])
    if not editor.canManipulateObject(objects[i]) then
      updateObjectSelectionAxisGizmo()
      return
    end
  end

  -- set the final transforms
  if duplicationDrag then
    local duplicableObjects = getMementoFromManipulableSelection()
    if not tableIsEmpty(duplicableObjects) then
      editor.history:commitAction("DuplicateObjects", {objects = duplicableObjects, objectIds = deepcopy(editor.selection.object), parentIds = getParentIds(editor.selection.object)}, pasteObjectsUndo, pasteObjectsRedo, true)
      editor.computeSelectionBBox()
    end
    duplicationDrag = false
  elseif worldEditorCppApi.getAxisGizmoMode() == editor.AxisGizmoMode_Scale then
    editor.history:beginTransaction("ScaleObjectSelection")
    for i = 1, tableSize(editor.selection.object) do
      local obj = objects[i]
      local objId = obj:getId()
      if obj and obj:getClassName() ~= "SimSet" and obj:getClassName() ~= "SimGroup" and obj.getScale then
        editor.history:commitAction("SetObjectScale", {objectId = objId, newScale = obj:getScale(), oldScale = axisGizmoEventState.oldScales[i]}, objectHistoryActions.setObjectScaleUndo, objectHistoryActions.setObjectScaleRedo, true)
        editor.history:commitAction("SetObjectTransform", {objectId = objId, newTransform = editor.matrixToTable(obj:getTransform()), oldTransform = editor.matrixToTable(axisGizmoEventState.oldTransforms[i])}, objectHistoryActions.setObjectTransformUndo, objectHistoryActions.setObjectTransformRedo, true)
      end
    end
    editor.history:endTransaction()
  else
    editor.history:beginTransaction("TransformObjectSelection")
    for i = 1, tableSize(editor.selection.object) do
      local obj = objects[i]
      local objId = obj:getId()
      if obj and obj:getClassName() ~= "SimSet" and obj:getClassName() ~= "SimGroup" and obj.getTransform then
        editor.history:commitAction("SetObjectTransform", {objectId = objId, newTransform = editor.matrixToTable(obj:getTransform()), oldTransform = editor.matrixToTable(axisGizmoEventState.oldTransforms[i])}, objectHistoryActions.setObjectTransformUndo, objectHistoryActions.setObjectTransformRedo, true)
      end
    end
    editor.history:endTransaction()
  end
  editor.setDirty()
  -- reset variables
  axisGizmoEventState.oldTransforms = {}
  axisGizmoEventState.oldScales = {}
  updateObjectSelectionAxisGizmo()
end

local function drawObjectSelectionGizmos()
  if editor.selection.object and not tableIsEmpty(editor.selection.object) then
    local colorX = math.abs(math.sin(colorBlinkTimer))
    local c1 = ColorF(0, 0.5, 0, 1)
    local c2 = ColorF(1, 1, 1, 1)
    local blinkColor = ColorF(c1.r + colorX * (c2.r - c1.r), c1.g + colorX * (c2.g - c1.g), c1.b + colorX * (c2.b - c1.b), 1)
    local blinkColorLocked = ColorF(1,colorX, colorX, 1)
    local boxColor
    -- draw a box for each object
    local drawGizmo = not raycastMode
    for i = 1, tableSize(editor.selection.object) do
      local obj = scenetree.findObjectById(editor.selection.object[i])
      if obj then
        if obj.getTransform then
          if obj:isLocked() then boxColor = blinkColorLocked else boxColor = blinkColor end
          drawSelectedObjectBBox(obj, boxColor)
        else
          drawGizmo = false
        end

        if drawGizmo then
          if editor.getAxisGizmoMode() == editor.AxisGizmoMode_Translate then
            if obj:getField('position','0') == "" then drawGizmo = false end
          elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Rotate then
            if obj:getField('rotation','0') == "" then drawGizmo = false end
          elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Scale then
            if obj:getField('scale','0') == "" then drawGizmo = false end
          end
        end
      end
    end

    if drawGizmo then
      -- draw big selection box
      if tableSize(editor.selection.object) > 1 then
        local mtx = MatrixF(true)
        mtx:setPosition(editor.objectSelectionBBox:getCenter())
        local scl = editor.objectSelectionBBox:getExtents()
        mtx:scale(scl)
        drawSelectionBBox(mtx, blinkColor)
      end

      editor.updateAxisGizmo(gizmoBeginDrag, gizmoEndDrag, gizmoDragging)
      editor.drawAxisGizmo()
    end
    colorBlinkTimer = colorBlinkTimer + editor.getDeltaTime() * 5.0
  end
end

local function objectSelectActivate()
  updateObjectSelectionAxisGizmo()
  worldEditorCppApi.setAxisGizmoSelectedElement(-1)
end

local function objectSelectDeactivate()
end

local function drawFrustumRect(frustum)
  local topLeftFrustum = vec3(frustum:getNearLeft() * 2, frustum:getNearDist() * 2, frustum:getNearTop() * 2)
  local topRightFrustum = vec3(frustum:getNearRight() * 2, frustum:getNearDist() * 2, frustum:getNearTop() * 2)
  local bottomLeftFrustum = vec3(frustum:getNearLeft() * 2, frustum:getNearDist() * 2, frustum:getNearBottom() * 2)
  local bottomRightFrustum = vec3(frustum:getNearRight() * 2, frustum:getNearDist() * 2, frustum:getNearBottom() * 2)

  local pos = getCameraPosition()
  local q = quat(getCameraQuat())
  local topLeftWorld, bottomRightWorld = (q * topLeftFrustum) + pos, (q * bottomRightFrustum) + pos
  local topRightWorld, bottomLeftWorld = (q * topRightFrustum) + pos, (q * bottomLeftFrustum) + pos

  -- Draw the selection rectangle
  debugDrawer:drawLine(topLeftWorld, topRightWorld, ColorF(1, 0, 0, 1))
  debugDrawer:drawLine(topRightWorld, bottomRightWorld, ColorF(1, 0, 0, 1))
  debugDrawer:drawLine(bottomRightWorld, bottomLeftWorld, ColorF(1, 0, 0, 1))
  debugDrawer:drawLine(bottomLeftWorld, topLeftWorld, ColorF(1, 0, 0, 1))
end

local function filterObjects(objects)
  local filteredIndices = {}
  for index, object in ipairs(objects) do
    local className = object:getClassName()
    if className == "TerrainBlock"
      or className == "WaterPlane"
      or className == "Forest"
      or not editor.isObjectSelectable(object) then
      table.insert(filteredIndices, index)
    end
  end

  for index = #filteredIndices, 1, -1 do
    table.remove(objects, filteredIndices[index])
  end
end

local function objectSelectUpdate()
  local res = getCameraMouseRay()
  local objectIdByIconClick = editor.objectIconHitId
  local hoveredObjectID = editor.isAxisGizmoHovered() and 0 or editor.objectIconHoverId
  worldEditorCppApi.setHoveredObjectId(hoveredObjectID)

  if imgui.IsMouseClicked(0)
      and (res or objectIdByIconClick)
      and not editor.isAxisGizmoHovered()
      and editor.isViewportHovered()
      and not imgui.GetIO().WantCaptureMouse then

    local ctrlDown = editor.keyModifiers.ctrl
    local shiftDown = editor.keyModifiers.shift
    local altDown = editor.keyModifiers.alt
    local selectMode = editor.SelectMode_New

    if ctrlDown then selectMode = editor.SelectMode_Toggle end
    if altDown then selectMode = editor.SelectMode_Remove end
    if shiftDown then selectMode = editor.SelectMode_Add end

    if objectIdByIconClick and objectIdByIconClick ~= 0 then
      local object = scenetree.findObjectById(objectIdByIconClick)
      if worldEditorCppApi.getClassIsSelectable(object:getClassName())
         and editor.isObjectSelectable(object) then
        editor.selectObjectById(objectIdByIconClick, selectMode)
      end
    else
      local hoveredObject = nil
      if not imgui.GetIO().WantCaptureMouse and editor.isViewportHovered() and not editor.isAxisGizmoHovered() then
        if core_forest.getForestObject() and not worldEditorCppApi.getClassIsSelectable("Forest") then core_forest.getForestObject():disableCollision() end
        local defaultFlags = bit.bor(SOTTerrain, SOTWater, SOTStaticShape, SOTStaticObject, SOTPlayer, SOTItem, SOTVehicle, SOTForest)
        if not worldEditorCppApi.getClassIsSelectable("TSStatic") then
          defaultFlags = bit.band(defaultFlags, bit.bnot(SOTStaticShape))
        end
        local rayCastInfo = cameraMouseRayCast(true, defaultFlags)
        if core_forest.getForestObject() then core_forest.getForestObject():enableCollision() end

        if rayCastInfo then
          hoveredObject = rayCastInfo.object

          -- Get the top level prefab as the hovered object
          local prefab
          repeat
            prefab = Prefab.getPrefabByChild(hoveredObject)
            if prefab then
              hoveredObject = prefab
            end
          until not prefab
        end
      end
      if hoveredObject and editor.isObjectSelectable(hoveredObject) then
        editor.selectObjectById(hoveredObject:getID(), selectMode)
        clickedHoveredObject = true
      else
        editor.clearObjectSelection()
      end
    end
    updateObjectSelectionAxisGizmo()
  end

  if clickedHoveredObject and imgui.IsMouseReleased(0) then
    clickedHoveredObject = false
  end

  if clickedHoveredObject and raycastMode and imgui.IsMouseDragging(0, 1) then
    if core_forest.getForestObject() and not worldEditorCppApi.getClassIsSelectable("Forest") then core_forest.getForestObject():disableCollision() end
    local defaultFlags = bit.bor(SOTTerrain, SOTWater, SOTStaticShape, SOTStaticObject, SOTPlayer, SOTItem, SOTVehicle, SOTForest)
    if not worldEditorCppApi.getClassIsSelectable("TSStatic") then
      defaultFlags = bit.band(defaultFlags, bit.bnot(SOTStaticShape))
    end
    local selectedObjects = {}
    for i = 1, tableSize(editor.selection.object) do
      local obj = scenetree.findObjectById(editor.selection.object[i])
      table.insert(selectedObjects, obj)
      obj:disableCollision()
    end
    local rayCastInfo = cameraMouseRayCast(true, defaultFlags)
    if core_forest.getForestObject() then core_forest.getForestObject():enableCollision() end
    for _, obj in ipairs(selectedObjects) do
      obj:enableCollision()
      if rayCastInfo then
        obj:setPosition(rayCastInfo.pos)
      end
    end
  end

  if res and not raycastMode then
    drawObjectSelectionGizmos()
  end

  if imgui.IsMouseClicked(0)
      and editor.isViewportHovered()
      and not imgui.GetIO().WantCaptureMouse
      and not editor.isAxisGizmoHovered() then
    mouseDragStartPos = imgui.GetMousePos()
  end

  if not (clickedHoveredObject and raycastMode) and imgui.IsMouseDragging(0) and mouseDragStartPos then
    local colorX = math.abs(math.sin(colorBlinkTimer))

    local delta = imgui.GetMouseDragDelta(0)
    local topLeft2I = editor.screenToClient(Point2I(mouseDragStartPos.x, mouseDragStartPos.y))
    local topLeft = vec3(topLeft2I.x, topLeft2I.y, 0)
    local bottomRight = (topLeft + vec3(delta.x, delta.y, 0))

    local frustum
    objectsInRect, frustum = editor.getObjectsByRectangle({topLeft = topLeft, bottomRight = bottomRight})

    drawFrustumRect(frustum)
    filterObjects(objectsInRect)

    for _, object in ipairs(objectsInRect) do
      drawSelectedObjectBBox(object, ColorF(colorX, colorX, colorX, 1))
    end
  end

  if mouseDragStartPos and imgui.IsMouseReleased(0) then
    mouseDragStartPos = nil
    editor.selectObjectsByRef(objectsInRect)
    objectsInRect = {}
  end
end

local function onEditorAxisGizmoAligmentChanged()
  if not editor.editMode or (editor.editMode.displayName ~= editor.editModes.objectSelect.displayName) then
    return
  end
  updateObjectSelectionAxisGizmo()
end

local function onDeleteSelection()
  if not editor.isViewportFocused() then return end
  objectHistoryActions.deleteSelectedObjectsWithUndo()
  editor.setDirty()
end

local function copySelectionToClipboard()
  copyObjectsArray = getMementoFromSelection()
  --TODO: the problem with this clipboard is that it will hold these objects until paste objects is
  -- done, we should use the system clipboard
end

local function onCut()
  if not editor.isViewportFocused() then return end
  if not editor.selection.object or tableIsEmpty(editor.selection.object) then return end
  --TODO cut objects to clipboard
end

local function onCopy()
  if not editor.isViewportFocused() then return end
  if not editor.selection.object or tableIsEmpty(editor.selection.object) then return end
  copySelectionToClipboard()
end

local function onPaste()
  if not editor.isViewportFocused() then return end
  local objects = deepcopy(copyObjectsArray)

  -- Use the group of the current selection as the group to put the pasted objects into
  local parentIds = {}
  local groupID
  if editor.selection.object and editor.selection.object[1] then
    groupID = scenetree.findObjectById(editor.selection.object[1]):getField("parentGroup", 0)
  end
  for i = 1, #objects do
    parentIds[i] = groupID
  end

  editor.history:commitAction("PasteObjects", {objects = objects, parentIds = parentIds}, pasteObjectsUndo, pasteObjectsRedo)
end

local function onDuplicate()
  if not editor.isViewportFocused() then return end
  if editor.selection.object and editor.selection.object[1] then
    if imgui.IsMouseDown(0) then
      pasteObjects(getMementoFromManipulableSelection())
      duplicationDrag = true
    else
      editor.history:commitAction("DuplicateObjects", {objects = getMementoFromSelection()}, pasteObjectsUndo, pasteObjectsRedo)
    end
  end
end

local function onDeselect()
  editor.deselectObjectSelection()
end

local function hiddenObjectIconsUI(cat, subCat, item)
  imgui.Separator()
  local classes = worldEditorCppApi.getObjectClassNames()
  local hiddenObjectIconClasses = editor.getPreference("gizmos.objectIcons.hiddenObjectIconClasses")
  imgui.TextUnformatted("Hidden Object Icons (select to hide):")
  imgui.Separator()
  imgui.BeginChild1("icon object classes", imgui.ImVec2(0, 200))
  for k = 1, tableSize(classes) do
    imgui.PushID1(tostring(k))
    local isSel = tableContains(hiddenObjectIconClasses, classes[k])
    if imgui.Selectable1(classes[k], isSel) then
      if isSel then
        local key = tableFindKey(hiddenObjectIconClasses, classes[k])
        table.remove(hiddenObjectIconClasses, key)
      else
        table.insert(hiddenObjectIconClasses, classes[k])
      end
      editor.setPreference(item.path, hiddenObjectIconClasses)
    end
    imgui.PopID()
  end
  imgui.EndChild()
end

local function registerApi()
  --TODO: maybe move these to object.lua
  editor.updateObjectSelectionAxisGizmo = updateObjectSelectionAxisGizmo
  editor.drawSelectedObjectBBox = drawSelectedObjectBBox
  editor.duplicateSelectionAtCamera = duplicateSelectionAtCamera
  editor.moveSelectionAtCamera = moveSelectionAtCamera
end

local function iconBackgroundTypeFromString(value)
  if value == "None" then return 0 end
  if value == "Circle" then return 1 end
  if value == "Square" then return 2 end
end

local function onEditorPreferenceValueChanged(path, value)
  if path == "gizmos.general.useObjectBoxCenter" then worldEditorCppApi.setUseObjectsBoxCenter(value) end
  if path == "gizmos.general.drawObjectIcons" then worldEditorCppApi.setDrawObjectIcons(value) end
  if path == "gizmos.general.drawObjectsText" then worldEditorCppApi.setDrawObjectsText(value) end
  if path == "gizmos.objectIcons.drawIconShadow" then worldEditorCppApi.setDrawIconShadow(value) end
  if path == "gizmos.objectIcons.constantSizeIcons" then worldEditorCppApi.setConstantSizeIcons(value) end
  if path == "gizmos.objectIcons.constantSizeIconScale" then worldEditorCppApi.setConstantSizeIconScale(value) end
  if path == "gizmos.objectIcons.iconWorldScale" then worldEditorCppApi.setIconWorldScale(value) end
  if path == "gizmos.objectIcons.fadeIcons" then worldEditorCppApi.setFadeIcons(value) end
  if path == "gizmos.objectIcons.useIconColor" then worldEditorCppApi.setUseIconColor(value) end
  if path == "gizmos.objectIcons.randomIconColorSeed" then worldEditorCppApi.setRandomIconColorSeed(value) end
  if path == "gizmos.objectIcons.fadeIconsDistance" then worldEditorCppApi.setFadeIconsDistance(value) end
  if path == "gizmos.objectIcons.iconBackgroundType" then worldEditorCppApi.setIconBackgroundType(iconBackgroundTypeFromString(value)) end
  if path == "gizmos.objectIcons.iconBackgroundScale" then worldEditorCppApi.setIconBackgroundScale(value) end
  if path == "gizmos.objectIcons.monoIconColor" then worldEditorCppApi.setMonoIconColor(value) end
  if path == "gizmos.objectIcons.selectedIconColor" then worldEditorCppApi.setSelectedIconColor(value) end
  if path == "gizmos.objectIcons.iconShadowColor" then worldEditorCppApi.setIconShadowColor(value) end
  if path == "gizmos.objectIcons.iconBackgroundColor" then worldEditorCppApi.setIconBackgroundColor(value) end
  if path == "gizmos.objectIcons.selectedIconBackgroundColor" then worldEditorCppApi.setSelectedIconBgColor(value) end
  if path == "gizmos.objectIcons.objectTextBackgroundColor" then worldEditorCppApi.setObjectTextBackgroundColor(value) end
  if path == "gizmos.objectIcons.objectTextColor" then worldEditorCppApi.setObjectTextColor(value) end
  if path == "gizmos.objectIcons.iconShadowOffset" then worldEditorCppApi.setIconShadowOffset(value) end
  if path == "gizmos.general.fineMoveScalar" then worldEditorCppApi.setFineMoveScalar(value) end
  if path == "gizmos.general.drawGizmoPlane" then
    worldEditorCppApi.setAxisGizmoRenderPlane(value)
    worldEditorCppApi.setAxisGizmoRenderPlaneHashes(value)
    worldEditorCppApi.setAxisGizmoRenderMoveGrid(value)
  end
  if path == "gizmos.general.gizmoPlaneSize" then worldEditorCppApi.setGizmoPlaneSize(value) end
  if path == "gizmos.general.gizmoPlaneColor" then worldEditorCppApi.setGizmoPlaneColor(value) end
  if path == "gizmos.general.gizmoPlaneGridColor" then worldEditorCppApi.setGizmoPlaneGridLineColor(value) end
  if path == "gizmos.general.fineRotationScalar" then worldEditorCppApi.setFineRotationScalar(value) end
  if path == "gizmos.general.fineScaleScalar" then worldEditorCppApi.setFineScaleScalar(value) end

  if string.find(path, "snapping.general") then
    -- setup snapping into engine
    editor.setAxisGizmoTranslateSnap(editor.getPreference("snapping.general.snapToGrid"), editor.getPreference("snapping.general.gridSize"))
    editor.setAxisGizmoRotateSnap(editor.getPreference("snapping.general.rotateSnapEnabled"), editor.getPreference("snapping.general.rotateSnapSize"))
  end

  if path == "gizmos.objectIcons.hiddenObjectIconClasses" then
    local hiddenObjectIconClasses = editor.getPreference("gizmos.objectIcons.hiddenObjectIconClasses")
    local classes = worldEditorCppApi.getObjectClassNames()
    for _, val in ipairs(classes) do
      worldEditorCppApi.setHideIconClass(val, tableContains(hiddenObjectIconClasses, val))
    end
  end

  if string.find(path, "gizmos.") then
    if editor.updateObjectSelectionAxisGizmo then
      editor.updateObjectSelectionAxisGizmo()
    end
  end
end

local function onEditorRegisterPreferences(prefsRegistry)
  prefsRegistry:registerCategory("gizmos")
  prefsRegistry:registerSubCategory("gizmos", "general")
  prefsRegistry:registerSubCategory("gizmos", "brush")
  prefsRegistry:registerSubCategory("gizmos", "objectIcons")

  prefsRegistry:registerCategory("snapping")
  prefsRegistry:registerSubCategory("snapping", "general")
  prefsRegistry:registerSubCategory("snapping", "terrain")
  prefsRegistry:registerSubCategory("snapping", "grid")

  prefsRegistry:registerPreferences("gizmos", "general",
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {useObjectBoxCenter = {"bool", false, "Use the object bounding box center as axis gizmo position, else use the pivot"}},
    {drawObjectIcons = {"bool", true, "Draw the object type icons in the world space"}},
    {drawObjectsText = {"bool", false, "Draw the object type name as text in the world space"}},
    {drawGizmoPlane = {"bool", true, "Draw the gizmo plane"}},
    {gizmoPlaneSize = {"float", 500.0, "Value used for gizmo plane size"}},
    {gizmoPlaneColor = {"ColorI", ColorI(255, 255, 255, 20), "Gizmo plane color"}},
    {gizmoPlaneGridColor = {"ColorI", ColorI(255, 255, 255, 40), "Gizmo Plane Grid color"}},
    {fineMoveScalar = {"float", 0.02, "Value used for fine moving as multiplier"}},
    {fineRotationScalar = {"float", 0.02, "Value used for fine rotation as multiplier"}},
    {fineScaleScalar = {"float", 0.02, "Value used for fine scaling as multiplier"}},
    {localCoordinatesModeDefault = {"bool", false, "Set local coordinates mode as default"}},
    {fixedRefnodeVisualization = {"bool", false, "Refnode Visualization having a fixed size."}},
  })

  prefsRegistry:registerPreferences("gizmos", "brush",
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {marginSize = {"float", 0.2, "The brush edge/margin size, used by terrain, forest editors"}},
    {createBrushColor = {"ColorF", ColorF(0, 0, 1, 0.5), "Color of the creating brush modes"}},
    {deleteBrushColor = {"ColorF", ColorF(1, 0, 0, 0.5), "Color of the deleting brush modes"}},
  })

  prefsRegistry:registerPreferences("gizmos", "objectIcons",
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {drawIconShadow = {"bool", true, "Draw a shadow under the object icons"}},
    {constantSizeIcons = {"bool", true, "Draw the object type icons with a constant screen size"}},
    {constantSizeIconScale = {"float", 0.8, "The scale of the constant size icons"}},
    {iconWorldScale = {"float", 0.2, "The scale of the icons when rendered in world size"}},
    {fadeIcons = {"bool", true, "Fade the icons based on their distance to the camera"}},
    {useIconColor = {"bool", false, "Draw the object icons with different colors"}},
    {randomIconColorSeed = {"float", 0, "The color random seed used for coloured icon rendering"}},
    {fadeIconsDistance = {"float", 30, "The distance from where icons will start to fade out"}},
    {fadeIconsDistanceModifySpeed = {"float", 10, "The multiplier speed for fade icon distance when it is modified"}},
    {iconBackgroundType = {"enum", "None", "The icon background shape type", nil, nil, nil, nil, nil, nil, {"None", "Circle", "Square"}}},
    {iconBackgroundScale = {"float", 1.4, "The icon background scale factor"}},
    {monoIconColor = {"ColorI", ColorI(255, 255, 255, 255), "The color of the icons when using a single color for all"}},
    {selectedIconColor = {"ColorI", ColorI(255, 128, 0, 255), "The color of a selected icon"}},
    {iconShadowColor = {"ColorI", ColorI(0, 0, 0, 255), "The object icon's shadow color"}},
    {iconBackgroundColor = {"ColorI", ColorI(0, 255, 255, 255), "The object icon's background color"}},
    {selectedIconBackgroundColor = {"ColorI", ColorI(178, 102, 0, 255), "Selected object icon's background color"}},
    {objectTextBackgroundColor = {"ColorI", ColorI(0, 0, 0, 255), "World space object name text background color"}},
    {objectTextColor = {"ColorI", ColorI(255, 255, 255, 255), "World space object name text color"}},
    {iconShadowOffset = {"Point2F", Point2F(3, 3), "The offset in pixels, for the shadow of the object icons"}},
    {hiddenObjectIconClasses = {"table", {"TSStatic"}, nil, nil, nil, nil, nil, nil, hiddenObjectIconsUI}},
  })

  prefsRegistry:registerPreferences("snapping", "general",
  {
    {snapToGrid = {"bool", false, "Snap objects to the grid"}},
    {gridSize = {"float", 1, "Grid size used for snapping objects to"}},
    {rotateSnapEnabled = {"bool", false, "Snap objects to fixed angles when rotating"}},
    {rotateSnapSize = {"float", 15, "Rotate snap angle step when rotating"}},
  })

  prefsRegistry:registerPreferences("snapping", "terrain",
  {
    {enabled = {"bool", false, "Snap objects to the terrain"}},
    {keepHeight = {"bool", false, "Keep the relative height when snapping"}},
    {snapToCenter = {"bool", false, "Snap objects to the center of their bounding box"}},
    {snapToBB = {"bool", false, "Snap objects to the bottom of their bounding box", "Snap To Bounding Box"}},
    {relRotation = {"bool", false, "Use relative rotation to terrain when snapping", "Relative Rotation"}},
    {indObjects = {"bool", false, "When snapping, snap each objects in the selection individually not as a group", "Treat Objects Individually"}},
    {useRayCast = {"bool", false, "Use raycast to find objects below to snap on"}},
  })

  prefsRegistry:registerPreferences("snapping", "grid",
  {
    {useLastObjectSelected = {"bool", false, "Use the last object selected as reference object for grid snapping"}},
  })

end

local function extendedSceneTreeObjectMenuItems(node)
  moveSelectionAtCamera()
end

local function onEditorInitialized()
  editor.editModes.objectSelect =
  {
    displayName = "Manipulate Object(s)",
    onActivate = objectSelectActivate,
    onDeactivate = objectSelectDeactivate,
    onUpdate = objectSelectUpdate,
    onToolbar = nil,
    actionMap = "ObjectTool",
    onCut = onCut,
    onCopy = onCopy,
    onPaste = onPaste,
    onDeselect = onDeselect,
    onDeleteSelection = onDeleteSelection,
    onDuplicate = onDuplicate,
    icon = editor.icons.mode_edit,
    iconTooltip = "Object Select",
    auxShortcuts = {}
  }

  editor.editModes.objectSelect.auxShortcuts[editor.AuxControl_Copy] = "Copy objects"
  editor.editModes.objectSelect.auxShortcuts[editor.AuxControl_Paste] = "Paste objects"
  editor.editModes.objectSelect.auxShortcuts[editor.AuxControl_Cut] = "Cut objects"
  editor.editModes.objectSelect.auxShortcuts[editor.AuxControl_Duplicate] = "Duplicate objects"
  editor.editModes.objectSelect.auxShortcuts[editor.AuxControl_Delete] = "Delete objects"
  editor.editModes.objectSelect.auxShortcuts[bit.bor(editor.AuxControl_Shift, editor.AuxControl_Duplicate)] = "Duplicate at cam pos"
  editor.editModes.objectSelect.auxShortcuts["Shift + Drag Gizmo"] = "Duplicate objects"
  registerApi()

  if editor.getPreference("gizmos.general.localCoordinatesModeDefault") then
    editor.setAxisGizmoAlignment(editor.AxisGizmoAlignment_Local)
  end

  editor.addExtendedSceneTreeObjectMenuItem({
    title = "Move Selection At Camera",
    extendedSceneTreeObjectMenuItems = extendedSceneTreeObjectMenuItems,
  })
end

local function onEditorInspectorFieldChanged(selectedIds, fieldName, fieldValue, arrayIndex)
  local selectedId = selectedIds[1]
  if selectedId and fieldName == "startTime" then
    local object = scenetree.findObjectById(selectedId)
    if object and object:getClassName() == "TimeOfDay" then
      local tod = core_environment.getTimeOfDay()
      if tod then
        tod.time = tod.startTime
        core_environment.setTimeOfDay(tod)
      end
    end
  end
end

M.onEditorInitialized = onEditorInitialized
M.onEditorPreferenceValueChanged = onEditorPreferenceValueChanged
M.onEditorAxisGizmoAligmentChanged = onEditorAxisGizmoAligmentChanged
M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onEditorInspectorFieldChanged = onEditorInspectorFieldChanged

return M