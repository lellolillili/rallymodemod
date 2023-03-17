-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local editor
local imgui = ui_imgui
local axisGizmoAlignmentLastFrame

local axisGizmoEventState = {
  mouseDown = false,
  objectSelectionManipulated = false
}

local function drawObjectIcons()
  if editor.getCamera() and not editor.hideObjectIcons then
    worldEditorCppApi.drawClosestObjectIcons()
  end
end

local function copyMat(mat)
  return mat * MatrixF(true)
end

local function updateObjectIcons()
  local pt2i = editor.screenToClient(Point2I(imgui.GetMousePos().x, imgui.GetMousePos().y))
  local pt = Point2F(pt2i.x, pt2i.y)
  editor.objectIconHitId = worldEditorCppApi.checkObjectIconHit(pt)

  if not imgui.IsMouseDown(0) and  not imgui.IsMouseDown(1) and not imgui.IsMouseDown(2) and not imgui.GetIO().WantCaptureMouse then
    editor.objectIconHoverId = editor.objectIconHitId
  else
    editor.objectIconHoverId = 0
  end
end

--- Set the axis gizmo's transform, used for custom editing of object parts or other visual handles.
-- @param matrix (MatrixF) the world transform matrix of the gizmo
-- @param scale (Point3F) of the gizmo, so to avoid non uniform scale decomposition problems
local function setAxisGizmoTransform(matrix, scale)
  worldEditorCppApi.setAxisGizmoTransform(matrix, matrix:getColumn(3), scale or vec3(1, 1, 1))
end

--- Return the axis gizmo current matrix transform as a MatrixF object.
local function getAxisGizmoTransform()
  return worldEditorCppApi.getAxisGizmoTransform()
end

--- Return the axis gizmo current scale as a Point3F object.
local function getAxisGizmoScale()
  return worldEditorCppApi.getAxisGizmoScale()
end

-- terrain snapping state
local initialGizmoTerrainOffset = nil
local initialGizmoTerrainNormal = nil
local gizmoBBOffset = nil
local objectGizmoOffsets = {}
local objectRotations = {}
local objectTerrainOffsets = {}
local objectTerrainNormals = {}
local objectBBOffsets = {}
local objectBBExtents = {}
local lastGizmoTerrainHeight = nil
local maxRayCastHeightDown = 50
local selectionBox
local currentTransforms

local function castRayDown(startPoint, endPoint)
  if not endPoint then
    endPoint = startPoint - vec3(0,0,100)
  end
  local res = Engine.castRay((startPoint + vec3(0,0,1)), endPoint, true, false)
  if not res then
    res = Engine.castRay((startPoint + vec3(0,0,100)), (startPoint - vec3(0,0,1000)), true, false)
  end
  return res
end

local function calcSelectionBox(objectBBs)
  local bbox = Box3F()
  bbox:setExtents(vec3(-1e10 - 1e10, -1e10 - 1e10, -1e10 - 1e10))
  bbox:setCenter(vec3(0, 0, 0))

  for _, bb in ipairs(objectBBs) do
    bbox:extend(bb.minExtents)
    bbox:extend(bb.maxExtents)
  end
  selectionBox = bbox
end

-- Call this once when starting to drag the gizmo
local function beginGizmoTranslate(objectTransforms, objectBBs, objectHeights, objects)
  currentTransforms = {}
  calcSelectionBox(objectBBs)

  local gizmoPos = editor.getAxisGizmoTransform():getColumn(3)
  if editor.getPreference("snapping.terrain.enabled") then
    if editor.getPreference("snapping.terrain.useRayCast") then
      for _, object in ipairs(objects) do
        object:disableCollision()
      end
      local rayCastRes = castRayDown(gizmoPos + vec3(0, 0, selectionBox.maxExtents.z), gizmoPos - vec3(0, 0, selectionBox.maxExtents.z + 50))

      if rayCastRes then
        initialGizmoTerrainOffset = gizmoPos.z - rayCastRes.pt.z
        initialGizmoTerrainNormal = rayCastRes.norm
        lastGizmoTerrainHeight = rayCastRes.pt.z
      end
    else
      if core_terrain.getTerrain() then
        initialGizmoTerrainOffset = gizmoPos.z - core_terrain.getTerrainHeight(gizmoPos)
        initialGizmoTerrainNormal = core_terrain.getTerrainSmoothNormal(gizmoPos)
        lastGizmoTerrainHeight = core_terrain.getTerrainHeight(gizmoPos)
      else
        initialGizmoTerrainOffset = 0
        initialGizmoTerrainNormal = vec3(0, 1, 0)
        lastGizmoTerrainHeight = 0
      end
    end
    gizmoBBOffset = (selectionBox:getCenter().z - gizmoPos.z)
  end

  for index, objectTransform in ipairs(objectTransforms) do
    table.insert(currentTransforms, copyMat(objectTransform))
    if editor.getPreference("snapping.terrain.enabled") then
      local objPos = objectTransform:getColumn(3)
      objectGizmoOffsets[index] = objPos - gizmoPos
      local rotation = QuatF(0,0,0,1)
      rotation:setFromMatrix(objectTransform)
      objectRotations[index] = quat(rotation)

      if editor.getPreference("snapping.terrain.indObjects") then
        if editor.getPreference("snapping.terrain.useRayCast") then
          local rayCastStart = vec3(objPos)
          rayCastStart.z = rayCastStart.z + objectHeights[index]
          local rayCastRes = castRayDown(rayCastStart, objPos - vec3(0,0,50))

          if rayCastRes then
            objectTerrainOffsets[index] = objPos.z - rayCastRes.pt.z
            objectTerrainNormals[index] = rayCastRes.norm
          end
        else
          if core_terrain.getTerrain() then
            objectTerrainOffsets[index] = objPos.z - core_terrain.getTerrainHeight(objPos)
            objectTerrainNormals[index] = core_terrain.getTerrainSmoothNormal(objPos)
          else
            objectTerrainOffsets[index] = 0
            objectTerrainNormals[index] = vec3(0, 1, 0)
          end
        end
        objectBBOffsets[index] = objectBBs[index]:getCenter().z - objPos.z
        objectBBExtents[index] = objectBBs[index]:getExtents().z
      end
    end
  end

  if editor.getPreference("snapping.terrain.enabled") and editor.getPreference("snapping.terrain.useRayCast") then
    for _, object in ipairs(objects) do
      object:enableCollision()
    end
  end
end

-- Returns the new transforms every frame when dragging the gizmo after "beginGizmoTranslate" was called once
-- TODO Why do we not have that function for rotation as well?
local function getTransformsGizmoTranslate(objects, objectHeights)
  if not currentTransforms then return {} end
  local newGizmoPos
  local newGizmoTerrainHeight
  local newGizmoTerrainNormal
  if editor.getPreference("snapping.terrain.enabled") then
    local gizmoPos = editor.getAxisGizmoTransform():getColumn(3)
    local delta = worldEditorCppApi.getAxisGizmoTotalRotateOffset()
    newGizmoPos = gizmoPos + delta

    if editor.getPreference("snapping.terrain.useRayCast") then
      for _, object in ipairs(objects) do
        object:disableCollision()
      end
      local rayStart = newGizmoPos
      rayStart.z = lastGizmoTerrainHeight

      local rayCastRes = castRayDown(rayStart + vec3(0, 0, selectionBox.maxExtents.z), rayStart - vec3(0, 0, selectionBox.maxExtents.z + 50))
      if rayCastRes then
        newGizmoTerrainHeight = rayCastRes.pt.z
        newGizmoTerrainNormal = rayCastRes.norm
      end
    else
      if core_terrain.getTerrain() then
        newGizmoTerrainHeight = core_terrain.getTerrainHeight(newGizmoPos)
        newGizmoTerrainNormal = core_terrain.getTerrainSmoothNormal(newGizmoPos)
      else
        newGizmoTerrainHeight = 0
        newGizmoTerrainNormal = vec3(0, 1, 0)
      end
    end
    lastGizmoTerrainHeight = newGizmoTerrainHeight
  end

  for index, transform in ipairs(currentTransforms) do
    transform:setPosition(transform:getColumn(3) + worldEditorCppApi.getAxisGizmoTranslateOffset())
  end

  if editor.getPreference("snapping.terrain.enabled") then
    for index = 1, #currentTransforms do
      local newPos = currentTransforms[index]:getColumn(3)
      local rotatedOffsetPos = objectGizmoOffsets[index]
      local objectTerrainHeight = core_terrain.getTerrainHeight(newPos) or 0
      local objectTerrainNormal = core_terrain.getTerrainSmoothNormal(newPos) or vec3(0, 1, 0)
      local skipTranslation = false

      if editor.getPreference("snapping.terrain.useRayCast") then
        local rayCastStart = vec3(newPos)
        rayCastStart.z = rayCastStart.z + objectHeights[index]
        local rayCastRes = castRayDown(rayCastStart, newPos - vec3(0,0,50))

        if not rayCastRes or
           not newGizmoTerrainHeight or
           not initialGizmoTerrainOffset or
           (editor.getPreference("snapping.terrain.indObjects") and not objectTerrainOffsets[index]) then
          skipTranslation = true
        else
          objectTerrainHeight = rayCastRes.pt.z
          objectTerrainNormal = rayCastRes.norm
        end
      end
      if not skipTranslation then
        if editor.getPreference("snapping.terrain.relRotation") then
          local rot
          if editor.getPreference("snapping.terrain.indObjects") then
            rot = objectRotations[index] * objectTerrainNormals[index]:getRotationTo(objectTerrainNormal)
          else
            rot = objectRotations[index] * initialGizmoTerrainNormal:getRotationTo(newGizmoTerrainNormal)
            rotatedOffsetPos = rotatedOffsetPos:rotated(initialGizmoTerrainNormal:getRotationTo(newGizmoTerrainNormal))
          end
          currentTransforms[index] = QuatF(rot.x, rot.y, rot.z, rot.w):getMatrix()
        end

        if editor.getPreference("snapping.terrain.keepHeight") then
          if editor.getPreference("snapping.terrain.indObjects") then
            newPos.z = objectTerrainHeight + objectTerrainOffsets[index]
          else
            newPos.z = newGizmoTerrainHeight + initialGizmoTerrainOffset + rotatedOffsetPos.z
          end
        elseif editor.getPreference("snapping.terrain.snapToCenter") then
          -- The gizmo is not always in the middle of the BB, so we need to shift the objects a bit
          if editor.getPreference("snapping.terrain.indObjects") then
            newPos.z = objectTerrainHeight - objectBBOffsets[index]
          else
            newPos.z = (newGizmoTerrainHeight + rotatedOffsetPos.z) - gizmoBBOffset
          end

        elseif editor.getPreference("snapping.terrain.snapToBB") then
          if editor.getPreference("snapping.terrain.indObjects") then
            newPos.z = objectTerrainHeight - objectBBOffsets[index] + objectBBExtents[index]/2
          else
            newPos.z = ((newGizmoTerrainHeight + rotatedOffsetPos.z) - gizmoBBOffset) + (selectionBox.maxExtents.z - selectionBox.minExtents.z)/2
          end
        else
          if editor.getPreference("snapping.terrain.indObjects") then
            newPos.z = objectTerrainHeight
          else
            newPos.z = ((newGizmoTerrainHeight + rotatedOffsetPos.z) - gizmoBBOffset) + (selectionBox.maxExtents.z - selectionBox.minExtents.z)/2
          end
        end

        currentTransforms[index]:setColumn(3, newPos)
      end
    end

    if editor.getPreference("snapping.terrain.useRayCast") then
      for _, object in ipairs(objects) do
        object:enableCollision()
      end
    end
  end
  return currentTransforms
end

--- Updates the axis gizmo internals, checking mouse manipulation events and so on.
-- Only call this together with "editor.drawAxisGizmo"
-- @param onStartGizmoDragFunc this function is called when the gizmo axes/handles are starting to being dragged (no args)
-- @param onEndGizmoDragFunc this function is called when the gizmo axes/handles ended being dragged (no args)
-- @param onGizmoDraggingFunc this function is called when the gizmo axes/handles are currently being dragged (no args)
local function updateAxisGizmo(onStartGizmoDragFunc, onEndGizmoDragFunc, onGizmoDraggingFunc)
  worldEditorCppApi.setEventControlModifiers(editor.keyModifiers.shiftDown, editor.keyModifiers.alt, editor.keyModifiers.ctrl)

  local camMouseRay = getCameraMouseRay()

  if camMouseRay then
    local mousePos = Point2I(imgui.GetMousePos().x, imgui.GetMousePos().y) --TODO: single call
    -- start to drag object selection's gizmo
    if not axisGizmoEventState.mouseDown
        and imgui.IsMouseDown(0)
        and editor.isViewportHovered()
        and not imgui.GetIO().WantCaptureMouse then

      worldEditorCppApi.onAxisGizmoMouseDown(mousePos, camMouseRay.pos, camMouseRay.dir)
      axisGizmoEventState.bulletTimePaused = bullettime.getPause()

      local hasGizmoElementHovered = worldEditorCppApi.getAxisGizmoSelectedElement() ~= -1

      -- if an axis gizmo element is selected, then do start a manipulation
      if hasGizmoElementHovered then
        axisGizmoEventState.mouseDown = true
        bullettime.pause(true)
      end

      axisGizmoEventState.objectSelectionManipulated = false
      if hasGizmoElementHovered and onStartGizmoDragFunc then onStartGizmoDragFunc() end

    -- end dragging the gizmo, finalize transform and add undo
    elseif axisGizmoEventState.mouseDown and not imgui.IsMouseDown(0) then
      axisGizmoEventState.mouseDown = false
      worldEditorCppApi.onAxisGizmoMouseUp(mousePos, camMouseRay.pos, camMouseRay.dir)

      -- set the final transforms
      if axisGizmoEventState.objectSelectionManipulated then
        if onEndGizmoDragFunc then onEndGizmoDragFunc() end
      end

      bullettime.pause(axisGizmoEventState.bulletTimePaused)

      -- reset variables
      axisGizmoEventState.objectSelectionManipulated = false

    -- if it's dragging right now
    elseif axisGizmoEventState.mouseDown and imgui.IsMouseDragging(0, 1) then
      worldEditorCppApi.onAxisGizmoMouseDragged(mousePos, camMouseRay.pos, camMouseRay.dir)
      axisGizmoEventState.objectSelectionManipulated = true
      if onGizmoDraggingFunc then onGizmoDraggingFunc() end
    else
      worldEditorCppApi.onAxisGizmoMouseMove(mousePos, camMouseRay.pos, camMouseRay.dir)
    end
  end

  -- The alignment might be changed from the c++ side, so we need to test for that here
  if editor.getAxisGizmoAlignment() ~= axisGizmoAlignmentLastFrame then
    extensions.hook("onEditorAxisGizmoAligmentChanged")
    axisGizmoAlignmentLastFrame = editor.getAxisGizmoAlignment()
  end
end

--- Draw the axis gizmo with its current transform and mode.
local function drawAxisGizmo()
  if editor.getCamera() then
    debugDrawer:drawAxisGizmo()
    editor_gizmoHelper.gizmoDrawCalled()
  end
end

--- Set the current axis gizmo mode. Usually called when the edit mode is activated.
-- @param mode the mode of the axis gizmo to be set:
--  *editor.AxisGizmoMode_Translate*
--  *editor.AxisGizmoMode_Rotate*
--  *editor.AxisGizmoMode_Scale*
local function setAxisGizmoMode(mode)
  worldEditorCppApi.setAxisGizmoMode(mode)
  extensions.hook("onEditorAxisGizmoModeChanged", mode)
end

--- Set the current axis gizmo alignment. Usually called when the edit mode is activated.
-- @param alignment the alignment of the axis gizmo to be set:
--  *editor.AxisGizmoAlignment_World* the gizmo is aligned with the world axes
--  *editor.AxisGizmoAlignment_Local* the gizmo is aligned with the local axes of the gizmo transform
local function setAxisGizmoAlignment(alignment)
  worldEditorCppApi.setAxisGizmoAlignment(alignment)
  extensions.hook("onEditorAxisGizmoAligmentChanged")
  axisGizmoAlignmentLastFrame = alignment
end

--- Set the lock on translation on certain axes
-- @param x true to allow translation on X axis
-- @param y true to allow translation on Y axis
-- @param z true to allow translation on Z axis
local function setAxisGizmoTranslateLock(x, y, z)
  worldEditorCppApi.setAxisGizmoTranslateLock(x, y, z)
end

--- Set the lock on rotation on certain axes
-- @param x true to allow rotation on X axis
-- @param y true to allow rotation on Y axis
-- @param z true to allow rotation on Z axis
local function setAxisGizmoRotateLock(x, y, z)
  worldEditorCppApi.setAxisGizmoRotateLock(x, y, z)
end

--- Set the lock on scaling on certain axes
-- @param x true to allow scaling on X axis
-- @param y true to allow scaling on Y axis
-- @param z true to allow scaling on Z axis
local function setAxisGizmoScaleLock(x, y, z)
  worldEditorCppApi.setAxisGizmoScaleLock(x, y, z)
end

--- Return the axis gizmo mode.
-- @see setAxisGizmoMode
local function getAxisGizmoMode()
  return worldEditorCppApi.getAxisGizmoMode()
end

--- Return the axis gizmo alignment.
-- @see setAxisGizmoAlignment
local function getAxisGizmoAlignment()
  return worldEditorCppApi.getAxisGizmoAlignment()
end

--- Return true if the axis gizmo has any hovered elements (axes).
local function isAxisGizmoHovered()
  return worldEditorCppApi.getAxisGizmoSelectedElement() ~= -1
end

--- Return the axis gizmo selected element (axis or plane).
local function getAxisGizmoSelectedElement()
  return worldEditorCppApi.getAxisGizmoSelectedElement()
end

--- Set the axis gizmo translation snapping parameters.
-- @param enabled true to enable snapping
-- @param gridSize a float specifying the grid cell size for snapping
local function setAxisGizmoTranslateSnap(enabled, gridSize)
  worldEditorCppApi.setGridSnap(enabled, gridSize)
end

--- Set the axis gizmo rotation snapping parameters.
-- @param enabled true to enable snapping
-- @param gridSize a float specifying the angle step for snapping
local function setAxisGizmoRotateSnap(enabled, rotationSnap)
  worldEditorCppApi.setRotateSnap(enabled, rotationSnap)
end

--- Set the axis gizmo scale snapping parameters.
-- @param enabled true to enable snapping
-- @param gridSize a float specifying the scale step for snapping
local function setAxisGizmoScaleSnap(enabled, scaleSnap)
  worldEditorCppApi.setScaleSnap(enabled, scaleSnap)
end

--- Switches between local and world gizmo axes alignment
local function toggleAxisGizmoAlignment()
  if getAxisGizmoAlignment() == editor.AxisGizmoAlignment_World then
    setAxisGizmoAlignment(editor.AxisGizmoAlignment_Local)
  else
    setAxisGizmoAlignment(editor.AxisGizmoAlignment_World)
  end
end

--- Toggle draw gizmo plane
local function toggleDrawGizmoPlane()
  editor.setPreference("gizmos.general.drawGizmoPlane", not editor.getPreference("gizmos.general.drawGizmoPlane"))
  if editor.getPreference("gizmos.general.drawGizmoPlane") then
    worldEditorCppApi.setAxisGizmoRenderPlane(true)
    worldEditorCppApi.setAxisGizmoRenderPlaneHashes(true)
    worldEditorCppApi.setAxisGizmoRenderMoveGrid(true)
  else
    worldEditorCppApi.setAxisGizmoRenderPlane(false)
    worldEditorCppApi.setAxisGizmoRenderPlaneHashes(false)
    worldEditorCppApi.setAxisGizmoRenderMoveGrid(false)
  end
end

--- Toggle draw object icons in the world scene view
local function toggleDrawObjectIcons()
  editor.setPreference("gizmos.general.drawObjectIcons", not editor.getPreference("gizmos.general.drawObjectIcons"))
  worldEditorCppApi.setDrawObjectIcons(editor.getPreference("gizmos.general.drawObjectIcons"))
end

--- Toggle draw object name text in the world scene view
local function toggleDrawObjectText()
  editor.setPreference("gizmos.general.drawObjectText", not editor.getPreference("gizmos.general.drawObjectText"))
  worldEditorCppApi.setDrawObjectsText(editor.getPreference("gizmos.general.drawObjectText"))
end

--- Modify the distance of the object icons fading by a delta value
local function modifyFadeIconsDistance(deltaValue)
  if 0 ~= deltaValue then
    local val = editor.getPreference("gizmos.objectIcons.fadeIconsDistance") + deltaValue * editor.getPreference("gizmos.objectIcons.fadeIconsDistanceModifySpeed")
    val = clamp(val, 1, 50000)
    editor.setPreference("gizmos.objectIcons.fadeIconsDistance", val)
  end
end

--- Toggle enable snapping for rotate and translate
local function toggleSnapping(value)
  if editor.preferencesRegistry then
    if not editor.getPreference("snapping.general.rotateSnapEnabled") then
      if value == 0 then
        editor.setAxisGizmoRotateSnap(false, editor.getPreference("snapping.general.rotateSnapSize"))
      elseif value == 1 then
        editor.setAxisGizmoRotateSnap(true, editor.getPreference("snapping.general.rotateSnapSize"))
      end
    end

    if not editor.getPreference("snapping.general.snapToGrid") then
      if value == 0 then
        editor.setAxisGizmoTranslateSnap(false, editor.getPreference("snapping.general.gridSize"))
      elseif value == 1 then
        editor.setAxisGizmoTranslateSnap(true, editor.getPreference("snapping.general.gridSize"))
      end
    end
  end
end

local function initialize(editorInstance)
  editor = editorInstance

  -- constants
  editor.AxisX = 0
  editor.AxisY = 1
  editor.AxisZ = 2
  editor.AxisW = 3
  editor.AxisGizmoMode_Translate = 1
  editor.AxisGizmoMode_Rotate = 2
  editor.AxisGizmoMode_Scale = 3
  editor.AxisGizmoAlignment_World = 0
  editor.AxisGizmoAlignment_Local = 1

  -- variables
  editor.objectIconHitId = 0

  -- functions
  editor.updateObjectIcons = updateObjectIcons
  editor.drawObjectIcons = drawObjectIcons
  editor.setAxisGizmoTransform = setAxisGizmoTransform
  editor.getAxisGizmoTransform = getAxisGizmoTransform
  editor.getAxisGizmoScale = getAxisGizmoScale
  editor.updateAxisGizmo = updateAxisGizmo
  editor.drawAxisGizmo = drawAxisGizmo
  editor.setAxisGizmoMode = setAxisGizmoMode
  editor.setAxisGizmoAlignment = setAxisGizmoAlignment
  editor.getAxisGizmoMode = getAxisGizmoMode
  editor.getAxisGizmoAlignment = getAxisGizmoAlignment
  editor.toggleAxisGizmoAlignment = toggleAxisGizmoAlignment
  editor.toggleDrawObjectIcons = toggleDrawObjectIcons
  editor.toggleDrawGizmoPlane = toggleDrawGizmoPlane
  editor.toggleDrawObjectText = toggleDrawObjectText
  editor.isAxisGizmoHovered = isAxisGizmoHovered
  editor.getAxisGizmoSelectedElement = getAxisGizmoSelectedElement
  editor.setAxisGizmoTranslateSnap = setAxisGizmoTranslateSnap
  editor.setAxisGizmoRotateSnap = setAxisGizmoRotateSnap
  editor.setAxisGizmoScaleSnap = setAxisGizmoScaleSnap
  editor.toggleSnapping = toggleSnapping
  editor.setAxisGizmoTranslateLock = setAxisGizmoTranslateLock
  editor.setAxisGizmoRotateLock = setAxisGizmoRotateLock
  editor.setAxisGizmoScaleLock = setAxisGizmoScaleLock
  editor.modifyFadeIconsDistance = modifyFadeIconsDistance
  editor.beginGizmoTranslate = beginGizmoTranslate
  editor.getTransformsGizmoTranslate = getTransformsGizmoTranslate
end

local M = {}
M.initialize = initialize

return M