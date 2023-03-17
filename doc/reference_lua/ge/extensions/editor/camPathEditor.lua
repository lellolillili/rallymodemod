  -- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {'core_camera'}

local u_32_max_int = 4294967295
local logTag = 'editor_extension_test'
local toolWindowName = "pathCameraTool"
local windowTitle = "Path Camera Tool"
local editModeName = "Edit Camera Paths"
local im = ui_imgui
local imUtils = require('ui/imguiUtils')
local ffi = require('ffi')
local roadRiverGui = extensions.editor_roadRiverGui
local sqrt = math.sqrt
local xVector = vec3(1,0,0)
local yVector = vec3(0,1,0)
local zVector = vec3(0,0,1)

local currentMarkerIndex = nil
local secondsBetweenMarkers = 2

local markerRadius = 1
local markerVisibleRadius = 5

local ctrlPoints = {1}
local camTs = {0}
local startTime
local endTime
local lastCtrlPointsR2 = {}
local lastFramesR2 = {}
local replayToBeLoaded

local linkReplay = im.BoolPtr(true)
local displayPreview = im.BoolPtr(true)
local previewWindowSize

local drawDistance = 600 -- only draw in 200 meter radius
local windowAspectRatio

local hoveredMarker
local hoveredPath
local renderView
local viewPortRect = RectI()

local markerdetailsColumnWidthSet = false

local function toColorI(colorF)
  return ColorI(colorF.r * 255,
                colorF.g * 255,
                colorF.b * 255,
                colorF.a * 255)
end
local defaultFrustumColor = ColorF(0.8,0.3,0.8,1)
local defaultFrustumColorI = toColorI(defaultFrustumColor)

local selectedFrustumColor = ColorF(1,1,1,1)
local selectedFrustumColorI = toColorI(selectedFrustumColor)

local trackingFrustumColor = ColorF(1,0.7,1,1)
local trackingFrustumColorI = toColorI(trackingFrustumColor)

local movingFrustumColor = ColorF(1,1,0,1)
local movingFrustumColorI = toColorI(movingFrustumColor)

local gridColor = ColorF(1,1,1,1)

local splineResolutions = {0.1, 0.2, 0.25, 0.5}
local splineThresholds = {300, 500, 1000}

local function getSplineResolution(dist)
  for i, threshold in ipairs(splineThresholds) do
    if threshold > dist then
      return splineResolutions[i]
    end
  end
  return splineResolutions[#splineResolutions]
end

local function sortMarkers(a,b)
  if a.time == b.time then
    return a.cut and not b.cut
  end
  return a.time < b.time
end

local function setDirty(path)
  path.dirty = true

  local selectedMarker = currentMarkerIndex
  if selectedMarker then
    for i, marker in ipairs(path.markers) do
      marker.index = i
    end
  end
  table.sort(path.markers, sortMarkers)
  if selectedMarker then
    for i, marker in ipairs(path.markers) do
      if marker.index == selectedMarker then
        currentMarkerIndex = i
      end
      marker.index = nil
    end
  end
end

local function replayExists(replay)
  if replay == "" then return false end
  return FS:fileExists(replay)
end

local function selectPath(path)
  M.currentPath = path
  currentMarkerIndex = nil

  if path and path.replay and replayExists(path.replay) and path.replay ~= core_replay.getLoadedFile() then
    core_replay.loadFile(path.replay)
    if (core_replay.getState() == 'playing') and not core_replay.isPaused() then
      core_replay.togglePlay()
    end
  end
end

local function selectMarker(markerIndex)
  currentMarkerIndex = markerIndex
  if currentMarkerIndex then

    -- Setup for debug markers
    ctrlPoints = {currentMarkerIndex}
    camTs = {M.currentPath.markers[ctrlPoints[1]].time}
    lastCtrlPointsR2 = {}
    lastFramesR2 = {}

    if M.currentPath.looped then
      ctrlPoints = {currentMarkerIndex, (currentMarkerIndex > 1) and (currentMarkerIndex - 1) or #M.currentPath.markers}
      camTs = {M.currentPath.markers[ctrlPoints[1]].time, M.currentPath.markers[ctrlPoints[2]].time}
    else
      if currentMarkerIndex > 1 then
        table.insert(ctrlPoints, currentMarkerIndex - 1)
        table.insert(camTs, M.currentPath.markers[ctrlPoints[2]].time)
      end
    end
  end
end


-- Create Path
local function createPathActionRedo(actionData)
  if not actionData.path then
    actionData.path = core_paths.createPath(core_paths.getUniquePathName("camPath"))
    if core_replay.getLoadedFile() ~= "" then
      actionData.path.replay = core_replay.getLoadedFile()
    end
  else
    core_paths.addPath(actionData.path)
  end
  selectPath(actionData.path)
end

local function createPathActionUndo(actionData)
  if actionData.path.name == M.currentPath.name then
    selectPath(nil)
  end
  core_paths.deletePath(actionData.path)
end


-- Delete Path
local deletePathActionRedo = createPathActionUndo
local deletePathActionUndo = createPathActionRedo


-- Load Path
local function loadPathActionRedo(actionData)
  if not actionData.path then
    actionData.path = core_paths.loadPath(actionData.filepath)
  else
    core_paths.addPath(actionData.path)
  end
  selectPath(actionData.path)
end

local loadPathActionUndo = createPathActionUndo

-- Change Path Field
local function changePathFieldActionRedo(actionData)
  actionData.path[actionData.field] = actionData.newValue
  setDirty(actionData.path)
end

local function changePathFieldActionUndo(actionData)
  actionData.path[actionData.field] = actionData.oldValue
end


-- Change Replay Field
local function changeReplayFieldActionRedo(actionData)
  actionData.path.replay = actionData.newValue
  setDirty(actionData.path)
  if actionData.path.replay and actionData.path.replay ~= "" and replayExists(actionData.path.replay) then
    core_replay.loadFile(actionData.path.replay)
  else
    core_replay.stop()
  end
end

local function changeReplayFieldActionUndo(actionData)
  actionData.path.replay = actionData.oldValue
  if actionData.path.replay and actionData.path.replay ~= "" and replayExists(actionData.path.replay) then
    core_replay.loadFile(actionData.path.replay)
  else
    core_replay.stop()
  end
end


-- Create Marker
local function createMarkerActionRedo(actionData)
  table.insert(actionData.path.markers, actionData.marker)
  selectMarker(#actionData.path.markers)
  setDirty(actionData.path)
  if not actionData.index then
    actionData.index = currentMarkerIndex
  end
end

local function createMarkerActionUndo(actionData)
  table.remove(actionData.path.markers, actionData.index)
  selectMarker(nil)
end


-- Delete Marker
local function deleteMarkerActionRedo(actionData)
  if not actionData.marker then
    actionData.marker = actionData.path.markers[actionData.index]
  end
  table.remove(actionData.path.markers, actionData.index)
  selectMarker(nil)
end

local function deleteMarkerActionUndo(actionData)
  table.insert(actionData.path.markers, actionData.marker)
  selectMarker(#actionData.path.markers)
  setDirty(actionData.path)
end


-- Change Marker Field
local function changeMarkerFieldActionRedo(actionData)
  for index, values in pairs(actionData.markerValues) do
    actionData.path.markers[index][actionData.field] = values.new
  end
  setDirty(actionData.path)
end

local function changeMarkerFieldActionUndo(actionData)
  for index, values in pairs(actionData.markerValues) do
    actionData.path.markers[index][actionData.field] = values.old
  end
end

local function changeSingleMarker(path, index, field, new)
  local markerValues = {}
  markerValues[index] = {old = path.markers[index][field], new = new}
  editor.history:commitAction("ChangeMarkerField", {path = path, field = field, markerValues = markerValues}, changeMarkerFieldActionUndo, changeMarkerFieldActionRedo)
end

local function changeAllMarkers(path, field, new)
  local markerValues = {}
  for i = 1, #path.markers do
    markerValues[i] = {old = M.currentPath.markers[i][field], new = new}
  end
  editor.history:commitAction("ChangeMarkerField", {path = path, field = field, markerValues = markerValues}, changeMarkerFieldActionUndo, changeMarkerFieldActionRedo)
end


-- Set Marker pos to current
local function setMarkerTransformActionRedo(actionData)
  actionData.path.markers[actionData.index].pos = actionData.newPos
  actionData.path.markers[actionData.index].rot = actionData.newRot
  actionData.path.markers[actionData.index].fov = actionData.newFov
  setDirty(actionData.path)
end

local function setMarkerTransformActionUndo(actionData)
  actionData.path.markers[actionData.index].pos = actionData.oldPos
  actionData.path.markers[actionData.index].rot = actionData.oldRot
  actionData.path.markers[actionData.index].fov = actionData.oldFov
end


-- Set Marker cut
local function setMarkerCutActionRedo(actionData)
  local marker = actionData.path.markers[actionData.index]
  local nextMarker = actionData.path.markers[actionData.index+1]
  marker.cut = actionData.newCut

  if actionData.index < #actionData.path.markers then
    if marker.cut then
      nextMarker.time = marker.time
    else
      nextMarker.time = marker.time + 0.0001
    end
  end

  setDirty(actionData.path)
end

local function setMarkerCutActionUndo(actionData)
  actionData.path.markers[actionData.index].cut = actionData.oldCut
  actionData.path.markers[actionData.index+1].time = actionData.oldTime
end


local function setMarkersTTN(path, timeToNext)
  if #path.markers < 2 then return end
  local markerValues = {}
  local globalTime = path.markers[1].time + timeToNext
  for i = 2, #path.markers do
    markerValues[i] = {old = path.markers[i].time, new = globalTime}
    if not path.markers[i].cut then
      globalTime = globalTime + timeToNext
    end
  end

  editor.history:commitAction("ChangeMarkerField", {path = path, field = "time", markerValues = markerValues}, changeMarkerFieldActionUndo, changeMarkerFieldActionRedo)
end


local function playCurrentPath()
  if tableSize(M.currentPath.markers) < 1 then return end
  -- exit free cam
  if commands.isFreeCamera() then
    commands.setGameCamera()
  end

  core_paths.playPath(M.currentPath, nil)

  if linkReplay[0] and (core_replay.getState() == "playing") then
    core_replay.seek(M.currentPath.markers[1].time / core_replay.getTotalSeconds())
    if (core_replay.getState() == 'playing') and core_replay.isPaused() then
      core_replay.togglePlay()
    end
  end
end

local function calculateTnorm(d12, d23, d34, t1, t2, t3, t)
  return clamp((monotonicSteffen(0, d12, d12 + d23, d12 + d23 + d34, 0, t1, t1 + t2, t1 + t2 + t3, t1 + t) - d12) / d23, 0, 1)
end

local function displayViewBig(marker, dist, frustumColor, frustumColorI)
  local pos = marker.pos
  local q = marker.rot
  dist = dist or 10
  local fovRadians = (marker.fov or 60) / 180 * math.pi
  local x, y, z = q * xVector, q * yVector, q * zVector

  local center = pos + y*dist
  local height =  math.tan(fovRadians/2) * dist
  local width = height * windowAspectRatio

  local a = (center + x*width + z*height)
  local b = (center + x*width - z*height)
  local c = (center - x*width - z*height)
  local d = (center - x*width + z*height)
  debugDrawer:drawSphere(a, 0.2, frustumColor)
  debugDrawer:drawSphere(b, 0.2, frustumColor)
  debugDrawer:drawSphere(c, 0.2, frustumColor)
  debugDrawer:drawSphere(d, 0.2, frustumColor)
  debugDrawer:drawLine(pos, a, frustumColor)
  debugDrawer:drawLine(pos, b, frustumColor)
  debugDrawer:drawLine(pos, c, frustumColor)
  debugDrawer:drawLine(pos, d, frustumColor)
  debugDrawer:drawLine(a, b, frustumColor)
  debugDrawer:drawLine(b, c, frustumColor)
  debugDrawer:drawLine(c, d, frustumColor)
  debugDrawer:drawLine(d, a, frustumColor)

  debugDrawer:drawTriSolid((a * 0.48 + d * 0.52),
                          ((a * 0.5 + d * 0.5) + z*height/10),
                          (a * 0.52 + d * 0.48), frustumColorI)
  debugDrawer:drawTriSolid((a * 0.48 + d * 0.52),
                          (a * 0.52 + d * 0.48),
                          ((a * 0.5 + d * 0.5) + z*height/10), frustumColorI)
end

local function drawGrid(color)
  local pos = getCameraPosition()
  local q = quat(getCameraQuat())
  local dist = 10
  local fovRadians = (getCameraFovDeg() or 60) / 180 * math.pi
  local x, y, z = q * xVector, q * yVector, q * zVector

  local center = pos + y*dist
  local height =  (math.tan(fovRadians/2) * dist)
  local width = (height * windowAspectRatio)

  local r1 = (center + x*width + z*height/3)
  local r2 = (center + x*width - z*height/3)
  local l1 = (center - x*width + z*height/3)
  local l2 = (center - x*width - z*height/3)
  local u1 = (center - x*width/3 + z*height)
  local u2 = (center + x*width/3 + z*height)
  local d1 = (center - x*width/3 - z*height)
  local d2 = (center + x*width/3 - z*height)
  debugDrawer:drawLine(r1, l1, color, false)
  debugDrawer:drawLine(r2, l2, color, false)
  debugDrawer:drawLine(u1, d1, color, false)
  debugDrawer:drawLine(u2, d2, color, false)

  local camName = commands.isFreeCamera() and "Freecam" or core_camera.getActiveCamName() or "No cam name"
  local textPos = center - x*width/3 + z*height/3
  textPos = textPos + x*0.05 - z*0.05
  debugDrawer:drawTextAdvanced(textPos, String("Cam: " .. camName), ColorF(0,0,0,1),false, false, ColorI(0,0,0,255), false, false)
end

local beginDragRotation
local beginDragPos
local function gizmoBeginDrag()
  beginDragRotation = deepcopy(M.currentPath.markers[currentMarkerIndex].rot)
  beginDragPos = deepcopy(M.currentPath.markers[currentMarkerIndex].pos)
end

local function gizmoEndDrag()
  if editor.getAxisGizmoMode() == editor.AxisGizmoMode_Translate then
    local markerValues = {}
    markerValues[currentMarkerIndex] = {old = beginDragPos, new = M.currentPath.markers[currentMarkerIndex].pos}
    editor.history:commitAction("ChangeMarkerField", {path = M.currentPath, field = "pos", markerValues = markerValues}, changeMarkerFieldActionUndo, changeMarkerFieldActionRedo, true)
  elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Rotate then
    local markerValues = {}
    markerValues[currentMarkerIndex] = {old = beginDragRotation, new = M.currentPath.markers[currentMarkerIndex].rot}
    editor.history:commitAction("ChangeMarkerField", {path = M.currentPath, field = "rot", markerValues = markerValues}, changeMarkerFieldActionUndo, changeMarkerFieldActionRedo, true)
  end
end

local function gizmoDragging()
  -- update/save our gizmo matrix
  if editor.getAxisGizmoMode() == editor.AxisGizmoMode_Translate then
    M.currentPath.markers[currentMarkerIndex].pos = editor.getAxisGizmoTransform():getColumn(3)

  elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Rotate then
    local gizmoTransform = editor.getAxisGizmoTransform()
    local rotation = QuatF(0,0,0,1)
    rotation:setFromMatrix(gizmoTransform)

    if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local then
      M.currentPath.markers[currentMarkerIndex].rot = quat(rotation)
    else
      M.currentPath.markers[currentMarkerIndex].rot = beginDragRotation * quat(rotation)
    end
  end
  setDirty(M.currentPath)
end

local function getTimeToNext(path, index)
  local markers = path.markers
  return (index < #markers) and (markers[index+1].time - markers[index].time) or (path.looped and path.loopTime or 2)
end

local function getGlobalTime(path, index, looped)
  if looped and (index == 1) then
    return path.markers[#path.markers].time + (path.loopTime or 2)
  else
    return path.markers[index].time
  end
end

local function simulatePathCamera(markers, playerPosition, path, focusPos)
  if M.currentPath and path.name == M.currentPath.name then
    local linkedReplay = linkReplay[0] and (core_replay.getState() == "playing")
    local firstMarker
    local lastMarker
    if linkedReplay then
      firstMarker = 1
      lastMarker = #markers
    elseif currentMarkerIndex then
      firstMarker = currentMarkerIndex - 1
      lastMarker = currentMarkerIndex
    else
      return
    end
    -- simulate interpolated camera
    for i = 1, linkedReplay and 1 or #ctrlPoints do
      if linkedReplay then
        ctrlPoints = {1}
      end
      local n1, n2, n3, n4 =  core_paths.getMarkerIds(path, ctrlPoints[i])
      if linkedReplay then
        camTs[i] = core_replay.getPositionSeconds()
        if camTs[i] < markers[1].time then
          return
        end
      end

      local nextTime = getGlobalTime(path, n3, path.looped)
      while camTs[i] > nextTime and ctrlPoints[i] ~= lastMarker do
        lastCtrlPointsR2[i] = deepcopy(lastFramesR2[i])
        ctrlPoints[i] = (ctrlPoints[i] % #markers) + 1
        n1, n2, n3, n4 = core_paths.getMarkerIds(path, ctrlPoints[i])
        nextTime = getGlobalTime(path, n3, path.looped)
        if ctrlPoints[i] == 1 then
          camTs[i] = 0
        end
      end
      local camTLocal = camTs[i] - getGlobalTime(path, n2)
      local p1, p2, p3, p4 = markers[n1].pos, markers[n2].pos, markers[n3].pos, markers[n4].pos
      local t1, t2, t3 = getTimeToNext(path, n1), getTimeToNext(path, n2), getTimeToNext(path, n3)

      if path.markers[n2].movingStart and (n1 == n2) then
        -- Add a virtual marker at the start for p1, so the cam speed is smoother
        if (p3 - p2):length() == 0 then
          p1 = p2
          t1 = 0
        else
          local direction = catmullRomChordal(p1, p2, p3, p4, 0.1, markers[n2].positionSmooth) - p2
          p1 = p2 - direction
          t1 = t2 * (direction:length() / (p3 - p2):length())
        end
      end

      if path.markers[n2].movingEnd and (n3 == n4) then
        -- Add a virtual marker at the end for p4, so the cam speed is smoother
        if (p3 - p2):length() == 0 then
          p4 = p3
          t3 = 0
        else
          local direction = p3 - catmullRomChordal(p1, p2, p3, p4, 0.9, markers[n2].positionSmooth)
          p4 = p3 + direction
          t3 = t2 * (direction:length() / (p3 - p2):length())
        end
      end

      local tNorm = calculateTnorm(p1:distance(p2), p2:distance(p3), p3:distance(p4), t1, t2, t3, camTLocal)
      local pos = catmullRomChordal(p1, p2, p3, p4, tNorm, markers[n2].positionSmooth)

      local target = vec3(0,0,0)
      if playerPosition then
        target = playerPosition
      end
      local targetRotation = quatFromDir(target - pos, zVector)
      local r1 = lastCtrlPointsR2[i] or (markers[n1].trackPosition and targetRotation or markers[n1].rot)
      local r2 = markers[n2].trackPosition and targetRotation or markers[n2].rot
      local r3 = markers[n3].trackPosition and targetRotation or markers[n3].rot
      local r4 = markers[n4].trackPosition and targetRotation or markers[n4].rot

      if path.markers[n2].movingStart and (n1 == n2) then
        -- Set the correct rotation to the virtual marker at the start
        local catMullRot = catmullRomCentripetal(r1, r2, r3, r4, 0.1):normalized()
        r1 = r2:nlerp(catMullRot, -1)
      end

      if path.markers[n2].movingEnd and (n3 == n4) then
        -- Set the correct rotation to the virtual marker at the end
        local catMullRot = catmullRomCentripetal(r1, r2, r3, r4, 0.9):normalized()
        r4 = r3:nlerp(catMullRot, -1)
      end

      -- Fix rotations
      if r2:dot(r1) < 0 then r2 = -r2 end
      if r3:dot(r2) < 0 then r3 = -r3 end
      if r4:dot(r3) < 0 then r4 = -r4 end
      lastFramesR2[i] = r2

      local rot = catmullRomCentripetal(r1, r2, r3, r4, calculateTnorm(sqrt(r1:distance(r2)), sqrt(r2:distance(r3)), sqrt(r3:distance(r4)), t1, t2, t3, camTLocal)):normalized()
      local fov = monotonicSteffen(markers[n1].fov or 60, markers[n2].fov or 60, markers[n3].fov or 60, markers[n4].fov or 60, 0, t1, t1 + t2, t1 + t2 + t3, t1 + camTLocal)

      if i == 1 and previewWindowSize and previewWindowSize.x > 0 then
        if not renderView then
          renderView = RenderViewManagerInstance:getOrCreateView('cameraPathPreview')
          renderView.namedTexTargetColor = 'cameraPathPreview'
          -- make sure the view is deleted properly if the GC collects it
          renderView.luaOwned = true
        end
        local mat = QuatF(rot.x, rot.y, rot.z, rot.w):getMatrix()
        mat:setPosition(pos)
        renderView.cameraMatrix = mat
        renderView.resolution = Point2I(previewWindowSize.x, previewWindowSize.y)
        viewPortRect:set(0, 0, previewWindowSize.x, previewWindowSize.y)
        renderView.viewPort = viewPortRect
        local aspectRatio = previewWindowSize.x / previewWindowSize.y
        renderView.frustum = Frustum.construct(false, fov, aspectRatio, 0.1, 2000)
        renderView.fov = fov
      end

      movingFrustumColor.a = math.min(math.max(0, (pos - getCameraPosition()):length() - 5), 10) / 10
      debugDrawer:setTargetRenderView('main')
      debugDrawer:drawSphere(pos, 0.5, movingFrustumColor)
      local marker = {rot = rot, pos = pos, fov = fov}
      displayViewBig(marker, 3, movingFrustumColor, movingFrustumColorI)
      debugDrawer:clearTargetRenderView()

      -- restarting when reached the end
      if ctrlPoints[i] == lastMarker and (camTs[i] >= nextTime) then
        lastCtrlPointsR2[i] = nil
        lastFramesR2[i] = nil
        if path.looped then
          ctrlPoints[i] = (lastMarker > 1) and firstMarker or #markers
        else
          ctrlPoints[i] = math.max(1, firstMarker)
        end
        camTs[i] = markers[ctrlPoints[i]].time
      end
    end
  end
end

local function drawDebugPath(path, focusPos)
  if not path or #path.markers < 2 then return end

  if core_camera.getActiveCamName() == "path" and not commands.isFreeCamera() then
    return
  end

  local markers = path.markers
  -- Fix rotations
  for i = 1, #markers - 1 do
    if markers[i].rot:dot(markers[i + 1].rot) < 0 then
      markers[i + 1].rot = -markers[i + 1].rot
    end
  end

  local playerVehicle = be:getPlayerVehicle(0)
  local playerPosition = nil
  if playerVehicle then
    playerPosition = playerVehicle:getPosition()
  end

  simulatePathCamera(markers, playerPosition, path, focusPos)

  local lastPoint = nil
  for index, marker in ipairs(markers) do
    marker.pos = marker.pos
    marker.rot = quat(marker.rot)

    local color = roadRiverGui.highlightColors.node
    if hoveredPath and hoveredPath.name == path.name and hoveredMarker == index then
      color = roadRiverGui.highlightColors.hoveredNode
    end
    if M.currentPath and (M.currentPath.name == path.name) and currentMarkerIndex == index then
      color = roadRiverGui.highlightColors.selectedNode

      local marker = M.currentPath.markers[currentMarkerIndex]
      local rotation
      local transform
      if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local then
        local q = marker.rot
        rotation = QuatF(q.x, q.y, q.z, q.w)
        transform = rotation:getMatrix()
      else
        rotation = QuatF(0, 0, 0, 1)
        transform = rotation:getMatrix()
      end

      transform:setPosition(marker.pos)
      editor.setAxisGizmoTransform(transform)

      editor.updateAxisGizmo(gizmoBeginDrag, gizmoEndDrag, gizmoDragging)
      editor.drawAxisGizmo()
    end

    color.a = math.min(math.max(0, (marker.pos - getCameraPosition()):length() - markerVisibleRadius), 10) / 10
    if not (M.currentPath and path.name == M.currentPath.name) then
      color.a = color.a * 0.2
    end

    debugDrawer:drawSphere(marker.pos, markerRadius, color)
    if M.currentPath and path.name == M.currentPath.name then
      debugDrawer:drawText(marker.pos, String(tostring(index) .. "/" .. (#path.markers)  .. ' -- ' .. string.format('%0.1f', marker.time) .. 's'), ColorF(0,0,0,1))
    end
    if M.currentPath and path.name == M.currentPath.name then
      -- draw camera frustum
      local markerCopy = deepcopy(marker)
      local frustumColor = (index == currentMarkerIndex) and selectedFrustumColor or defaultFrustumColor
      local frustumColorI = (index == currentMarkerIndex) and selectedFrustumColorI or defaultFrustumColorI

      if markerCopy.trackPosition then
        frustumColor = trackingFrustumColor
        frustumColorI = trackingFrustumColorI
        local target = vec3(0,0,0)
        if playerPosition then
          target = playerPosition
        end
        markerCopy.rot = quatFromDir(target - markerCopy.pos, zVector)
      end
      displayViewBig(markerCopy, 5, frustumColor, frustumColorI)

      if lastPoint then
        debugDrawer:drawLine(marker.pos, lastPoint, ColorF(1,0,0,0.5))
      end
    end
    lastPoint = marker.pos
  end

  -- draw interpolated spline
  local splineColor
  if M.currentPath and path.name == M.currentPath.name then
    splineColor = ColorF(0,0,1,1)
  else
    splineColor = ColorF(0,0,1,0.3)
  end
  lastPoint = nil
  local camPos = getCameraPosition()
  for i = 1, core_paths.getEndIdx(path) do
    local n1, n2, n3, n4 = core_paths.getMarkerIds(path, i)
    local stepSize = getSplineResolution((markers[n2].pos - camPos):length())
    if not markers[n2].cut and stepSize < 1 then
      for t = 0, 1, stepSize do
        local marker = catmullRomChordal(markers[n1].pos, markers[n2].pos, markers[n3].pos, markers[n4].pos, t, markers[n2].positionSmooth)
        if lastPoint then
          debugDrawer:drawLine(marker, lastPoint, splineColor)
        end
        lastPoint = marker
      end
    end
  end
end

local function addMarker()
  local marker = {
    pos = getCameraPosition(),
    rot = quat(getCameraQuat()),
    time = 0,
    positionSmooth = 0.5,
    trackPosition = (#M.currentPath.markers > 1) and M.currentPath.markers[#M.currentPath.markers].trackPosition or false,
    fov = getCameraFovDeg(),
    bullettime = 1,
    movingStart = true,
    movingEnd = true
  }
  if #M.currentPath.markers > 0 then
    marker.time = M.currentPath.markers[#M.currentPath.markers].time + 2
  end
  if linkReplay[0] and (core_replay.getState() == "playing") then
    marker.time = core_replay.getPositionSeconds()
    if #M.currentPath.markers > 0 and marker.time == M.currentPath.markers[#M.currentPath.markers].time then
      M.currentPath.markers[#M.currentPath.markers].cut = true
    end
  end

  editor.history:commitAction("CreateMarker", {path = M.currentPath, marker = marker}, createMarkerActionUndo, createMarkerActionRedo)
end

local function deleteMarker(index)
  if not index then index = currentMarkerIndex end
  editor.history:commitAction("DeleteMarker", {path = M.currentPath, index = index}, deleteMarkerActionUndo, deleteMarkerActionRedo)
end

local function markerIsBeingCutTo(path, markerIndex)
  if path.looped then
    return path.markers[((markerIndex - 2) % #path.markers) + 1].cut
  else
    return path.markers[markerIndex-1] and path.markers[markerIndex-1].cut
  end
end

local markerPosition = im.ArrayFloat(3)
local function displayMarkerList()
  local buttonSize = im.CalcTextSize("Current FOV: 65.00 + -    Reset Freecam FOV --")
  if im.Button("Add marker") then
    addMarker()
  end
  im.SameLine()
  im.Dummy(im.ImVec2(im.GetContentRegionAvailWidth() - (buttonSize.x + 100 * im.uiscale[0]), 0))
  im.SameLine()

  local imVal = im.FloatPtr(getCameraFovDeg())
  im.PushItemWidth(120 * im.uiscale[0])
  if editor.uiInputFloat("freecam fov", imVal, 0.1, 1.0, nil, im.InputTextFlags_EnterReturnsTrue) then
    setCameraFovDeg(clamp(imVal[0], 10, 120))
  end
  im.SameLine()
  if im.Button("Reset freecam fov") then
    setCameraFovDeg(65)
  end

  local avail = im.GetContentRegionAvail()
  if not tableIsEmpty(M.currentPath.markers) then
    local textWidth = im.CalcTextSize("#100 X").x + 30 * im.uiscale[0]
    im.BeginChild1("markers", im.ImVec2(textWidth, avail.y - 80 * im.uiscale[0]), im.WindowFlags_ChildWindow)
      im.PushStyleColor2(im.Col_Button, im.ImVec4(0, 0, 0, 0))
      for index, marker in ipairs(M.currentPath.markers) do
        local x = im.GetCursorPosX()
        if im.Selectable1("#" .. index, index == currentMarkerIndex, nil, im.ImVec2(20 * im.uiscale[0],20 * im.uiscale[0])) then
          selectMarker(index)
        end

        im.SameLine()
        im.SetCursorPosY(im.GetCursorPosY() - 2)
        im.SetCursorPosX(x + 24 * im.uiscale[0])
        im.PushStyleColor2(im.Col_Text, im.ImVec4(1, 0.5, 0.5, 0.5))
        if editor.uiIconImageButton(editor.icons.delete, im.ImVec2(24, 24), nil, nil, nil, 'deleteMarker') then
          deleteMarker(index)
        end
        im.PopStyleColor()
        im.tooltip("Delete Marker")
      end
      im.PopStyleColor()
      if im.Button("+") then
        addMarker()
      end
    im.EndChild()

    if currentMarkerIndex then
      local marker = M.currentPath.markers[currentMarkerIndex]
      im.SameLine()
      if currentMarkerIndex then
        im.BeginChild1("currentMarkerInner", im.ImVec2(0, avail.y - 80 * im.uiscale[0]), im.WindowFlags_ChildWindow)

        if im.Button("Preview marker") then
          local pos = marker.pos
          local rot = marker.rot
          commands.setFreeCamera()
          setCameraPosRot(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
          setCameraFovDeg(marker.fov or 60)
        end
        im.tooltip("Moves the camera to the select marker position")

        im.SameLine()

        if im.Button("Overwrite with current camera") then
          editor.history:commitAction("ChangeMarkerTransform", {path = M.currentPath, index = currentMarkerIndex, oldPos = marker.pos, oldRot = marker.rot, oldFov = marker.fov, newPos = getCameraPosition(), newRot = quat(getCameraQuat()), newFov = getCameraFovDeg()}, setMarkerTransformActionUndo, setMarkerTransformActionRedo)
        end
        im.tooltip("Uses current camera position for the marker")

        im.Dummy(im.ImVec2(0, 5))
        im.Separator()
        im.Dummy(im.ImVec2(0, 5))

        markerPosition[0] = marker.pos.x
        markerPosition[1] = marker.pos.y
        markerPosition[2] = marker.pos.z
        im.Text("Marker Position")
        im.PushItemWidth(300 * im.uiscale[0])
        if im.InputFloat3("##markerPos", markerPosition, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
          changeSingleMarker(M.currentPath, currentMarkerIndex, "pos", vec3(markerPosition[0], markerPosition[1], markerPosition[2]))
        end
        im.PopItemWidth()
        im.Separator()

        if markerIsBeingCutTo(M.currentPath, currentMarkerIndex) then
          im.BeginDisabled()
        end
        local imVal = im.FloatPtr(marker.time)
        local editEnded = im.BoolPtr(false)
        im.Text("Global Time")
        im.PushItemWidth(120 * im.uiscale[0])
        if im.InputFloat("", imVal, 0.1, 1.0, format, im.InputTextFlags_EnterReturnsTrue) then
          if imVal[0] < 0 then
            imVal[0] = 0
          end
          changeSingleMarker(M.currentPath, currentMarkerIndex, "time", imVal[0])
        end
        im.tooltip("The marker's position in the global timeline")
        if markerIsBeingCutTo(M.currentPath, currentMarkerIndex) then
          im.EndDisabled()
        end

        imVal = im.FloatPtr((currentMarkerIndex < #M.currentPath.markers) and (M.currentPath.markers[currentMarkerIndex+1].time - marker.time) or 0)
        if M.currentPath.looped and currentMarkerIndex == #M.currentPath.markers then
          imVal[0] = M.currentPath.loopTime or 2
        end
        local oldTime = imVal[0]
        if marker.cut then
          im.BeginDisabled()
        end
        im.Text("Time to Next")
        im.PushItemWidth(120 * im.uiscale[0])
        editor.uiInputFloat("##ttn", imVal, 0.1, 1.0, format, im.InputTextFlags_EnterReturnsTrue, editEnded)
        if editEnded[0] then
          if imVal[0] < 0 then
            imVal[0] = 0
          elseif M.currentPath.looped and currentMarkerIndex == #M.currentPath.markers then
            editor.history:commitAction("ChangePathField", {path = M.currentPath, field = "loopTime", oldValue = M.currentPath.loopTime, newValue = imVal[0]}, changePathFieldActionUndo, changePathFieldActionRedo)
          else
            -- Add the difference to the time from the following markers
            local markerValues = {}
            local difference = imVal[0] - oldTime
            for i = currentMarkerIndex + 1, #M.currentPath.markers do
              markerValues[i] = {old = M.currentPath.markers[i].time, new = M.currentPath.markers[i].time + difference}
            end

            editor.history:commitAction("ChangeMarkerField", {path = M.currentPath, field = "time", markerValues = markerValues}, changeMarkerFieldActionUndo, changeMarkerFieldActionRedo)
          end
        end
        im.tooltip("Time to reach the next marker")
        im.PopItemWidth()

        im.SameLine()
        if imVal[0] == 0 then
          im.BeginDisabled()
        end
        if im.Button("Set for all##ttn") then
          setMarkersTTN(M.currentPath, imVal[0])
        end
        im.tooltip("Set this 'Time To Next' value for all markers")
        if imVal[0] == 0 then
          im.EndDisabled()
        end
        if marker.cut then
          im.EndDisabled()
        end

        if markerIsBeingCutTo(M.currentPath, currentMarkerIndex) or currentMarkerIndex == #M.currentPath.markers then
          im.BeginDisabled()
        end
        im.SameLine()
        local cut = im.BoolPtr(marker.cut or false)
        if im.Checkbox("Cut to next marker", cut) then
          editor.history:commitAction("ChangeMarkerCut", {path = M.currentPath, index = currentMarkerIndex, oldCut = marker.cut, newCut = cut[0], oldTime = M.currentPath.markers[currentMarkerIndex+1].time}, setMarkerCutActionUndo, setMarkerCutActionRedo)
        end
        if markerIsBeingCutTo(M.currentPath, currentMarkerIndex) or currentMarkerIndex == #M.currentPath.markers then
          im.EndDisabled()
        end

        im.Separator()

        im.Text("Field of View")
        im.PushItemWidth(120 * im.uiscale[0])
        imVal[0] = marker.fov or 60
        editor.uiInputFloat("##fov", imVal, 0.1, 1.0, format, im.InputTextFlags_EnterReturnsTrue, editEnded)
        if editEnded[0] then
          changeSingleMarker(M.currentPath, currentMarkerIndex, "fov", imVal[0])
        end
        im.PopItemWidth()

        im.SameLine()
        if im.Button("Set for all##fov") then
          changeAllMarkers(M.currentPath, "fov", imVal[0])
        end
        im.tooltip("Set this 'fov' value for all markers")

        im.Separator()
        im.Text("Position Smoothing")
        im.PushItemWidth(120 * im.uiscale[0])
        imVal[0] = marker.positionSmooth
        editor.uiInputFloat("##smooth", imVal, 0.1, 1.0, format, im.InputTextFlags_EnterReturnsTrue, editEnded)
        if editEnded[0] then
          changeSingleMarker(M.currentPath, currentMarkerIndex, "positionSmooth", imVal[0])
        end
        im.PopItemWidth()
        im.SameLine()
        if im.Button("Set for all##pos") then
          changeAllMarkers(M.currentPath, "positionSmooth", imVal[0])
        end
        im.tooltip("Set this 'Position Smooth' value for all markers")

        im.Separator()

        if M.currentPath.replay then
          im.Text("Bullet Time")
          im.PushItemWidth(120 * im.uiscale[0])
          imVal[0] = marker.bullettime
          editor.uiInputFloat("##bullet", imVal, 0.1, 1.0, format, im.InputTextFlags_EnterReturnsTrue, editEnded)
          imVal[0] = clamp(imVal[0], 0.1, 8)
          if editEnded[0] then
            changeSingleMarker(M.currentPath, currentMarkerIndex, "bullettime", imVal[0])
          end
          im.tooltip("Change playback speed at this marker")
          im.PopItemWidth()
          im.SameLine()
          if im.Button("Set for following") then
            local markerValues = {}
            for i = currentMarkerIndex, #M.currentPath.markers do
              markerValues[i] = {old = M.currentPath.markers[i].time, new = imVal[0]}
            end

            editor.history:commitAction("ChangeMarkerField", {path = M.currentPath, field = "bullettime", markerValues = markerValues}, changeMarkerFieldActionUndo, changeMarkerFieldActionRedo)
          end
          im.tooltip("Set this 'Bullet Time' value for all markers")
        end

        im.Dummy(im.ImVec2(0, 5))
        im.Separator()
        im.Dummy(im.ImVec2(0, 5))

        local trackPosition = im.BoolPtr(marker.trackPosition or false)
        if im.Checkbox("Track player vehicle", trackPosition) then
          changeSingleMarker(M.currentPath, currentMarkerIndex, "trackPosition", trackPosition[0])
        end
        im.tooltip("If enabled the marker will automatically rotate toward the player's vehicle")

        -- Moving Start
        local movingStart = im.BoolPtr(M.currentPath.markers[currentMarkerIndex].movingStart or false)
        if im.Checkbox("Moving Start", movingStart) then
          changeSingleMarker(M.currentPath, currentMarkerIndex, "movingStart", movingStart[0])
        end
        im.tooltip("This camera move will start already moving")
        im.SameLine()
        if im.Button("Set for all##startMove") then
          changeAllMarkers(M.currentPath, "movingStart", movingStart[0])
        end
        im.tooltip("Set this 'Moving Start' value for all markers")

        -- Moving End
        local movingEnd = im.BoolPtr(M.currentPath.markers[currentMarkerIndex].movingEnd or false)
        if im.Checkbox("Moving End", movingEnd) then
          changeSingleMarker(M.currentPath, currentMarkerIndex, "movingEnd", movingEnd[0])
        end
        im.tooltip("This camera move will not end with a standstill")
        im.SameLine()
        if im.Button("Set for all##endMove") then
          changeAllMarkers(M.currentPath, "movingEnd", movingEnd[0])
        end
        im.tooltip("Set this 'Moving End' value for all markers")

        im.EndChild()
      end
    end
  end
end

local function onEditorGui()
  if not editor.editMode or (editor.editMode.displayName ~= editModeName) then
    return
  end

  local format = "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f"
  for i = 1, #camTs do
    camTs[i] = camTs[i] + editor.getDeltaTime()
  end

  hoveredPath = nil
  hoveredMarker = nil
  if not (im.IsAnyItemHovered() or im.IsWindowHovered(im.HoveredFlags_AnyWindow)) then
    local camPos = getCameraPosition()
    local ray = getCameraMouseRay()
    local rayDir = ray.dir
    local minNodeDist = u_32_max_int
    for _, path in ipairs(core_paths.getPaths()) do
      for i, marker in ipairs(path.markers) do
        local distMarkerToCam = (marker.pos - camPos):length()
        if distMarkerToCam < minNodeDist and distMarkerToCam > markerVisibleRadius then
          local markerRayDistance = (marker.pos - camPos):cross(rayDir):length() / rayDir:length()
          if markerRayDistance <= markerRadius then
            hoveredMarker = i
            hoveredPath = path
            minNodeDist = distMarkerToCam
          end
        end
      end
    end
  end

  if im.IsMouseClicked(0) then
    if hoveredMarker then
      selectPath(hoveredPath)
      selectMarker(hoveredMarker)
    elseif editor.keyModifiers.shift and M.currentPath then
      addMarker()
    end
  end

  if editor.beginWindow(toolWindowName, windowTitle, im.WindowFlags_MenuBar, true) then
    if im.BeginMenuBar() then
      if im.MenuItem1("New") then
        editor.history:commitAction("CreatePath", {}, createPathActionUndo, createPathActionRedo)
      end
      if im.MenuItem1("Load...") then
        local currentLevelPath = (path.split(getMissionFilename()) or "") .. "camPaths"
        editor_fileDialog.openFile(function(data) editor.history:commitAction("LoadPath", {filepath = data.filepath}, loadPathActionUndo, loadPathActionRedo) end, {{"Camera Path Files",".camPath.json"}}, false, currentLevelPath)
      end
      local disabled = false
      if not (M.currentPath and M.currentPath.dirty) then im.BeginDisabled() disabled = true end
      if im.MenuItem1("Save") and M.currentPath.dirty then
        if M.currentPath.filename then
          core_paths.savePath(M.currentPath, M.currentPath.filename)
        else
          local currentLevelPath = (path.split(getMissionFilename()) or "") .. "camPaths"
          extensions.editor_fileDialog.saveFile(function(data) core_paths.savePath(M.currentPath, data.filepath) end, {{"Camera Path Files",".camPath.json"}}, false, currentLevelPath)
        end
      end
      if disabled then im.EndDisabled() end

      disabled = false
      if not M.currentPath then im.BeginDisabled() disabled = true end
      if im.MenuItem1("Delete") then
        editor.history:commitAction("DeletePath", {path = M.currentPath}, deletePathActionUndo, deletePathActionRedo)
      end
      if disabled then im.EndDisabled() end

      if im.MenuItem1("Render Options") then
        editor.showWindow("rendererComponents")
      end
      --[[if im.Checkbox("show camera preview", displayPreview) then
        if displayPreview[0] then
          editor.showWindow("cameraPathPreviewWindow")
        else
          editor.hideWindow("cameraPathPreviewWindow")
        end
      end]]
      im.EndMenuBar()
    end



    im.Text("Selected: ")
    im.SameLine()

    local showedName = M.currentPath and (M.currentPath.name .. (M.currentPath.dirty and "*" or "") ) or ""
    if im.BeginCombo("##paths", showedName) then
      for _, path in ipairs(core_paths.getPaths()) do
        if im.Selectable1(path.name) then
          selectPath(path)
        end
      end
      im.EndCombo()
    end

    if M.currentPath then
      local h = 6.7
      if not linkReplay[0] then h = 2.2 end
      im.BeginChild1("replay", im.ImVec2(0, im.GetFontSize() * h * im.uiscale[0]), im.WindowFlags_ChildWindow)
      linkReplay[0] = M.currentPath.replay == "" or M.currentPath.replay ~= nil and replayExists(M.currentPath.replay)
      if im.Checkbox("Link path to current replay", linkReplay) then
        if linkReplay[0] then
          if core_replay.getLoadedFile() then
            editor.history:commitAction("ChangeReplayField", {path = M.currentPath, oldValue = M.currentPath.replay, newValue = core_replay.getLoadedFile()}, changeReplayFieldActionUndo, changeReplayFieldActionRedo)
          else
            editor.history:commitAction("ChangeReplayField", {path = M.currentPath, oldValue = M.currentPath.replay, newValue = ""}, changeReplayFieldActionUndo, changeReplayFieldActionRedo)
          end
        else
          editor.history:commitAction("ChangeReplayField", {path = M.currentPath, oldValue = M.currentPath.replay, newValue = nil}, changeReplayFieldActionUndo, changeReplayFieldActionRedo)
        end
      end

      if linkReplay[0] then
        im.Text("Replay:")
        im.SameLine()

        if im.BeginCombo("##recordings", core_replay.getLoadedFile()) then
          local files = core_replay.getRecordings()
          arrayReverse(files)
          for _, recording in ipairs(files) do
            if im.Selectable1(recording.filename, nil) then
              replayToBeLoaded = recording.filename
            end
          end
          im.EndCombo()
        end
      end

      if replayToBeLoaded then
        im.OpenPopup("Load new replay")
      end
      if im.BeginPopupModal("Load new replay") then
        im.Text('Do you want to load replay: "' .. replayToBeLoaded .. '"?')
        if im.Button("Yes") then
          editor.history:commitAction("ChangeReplayField", {path = M.currentPath, oldValue = M.currentPath.replay, newValue = replayToBeLoaded}, changeReplayFieldActionUndo, changeReplayFieldActionRedo)
          replayToBeLoaded = nil
          im.CloseCurrentPopup()
        end
        im.SameLine()
        if im.Button("No") then
          replayToBeLoaded = nil
          im.CloseCurrentPopup()
        end
        im.EndPopup()
      end

      if (core_replay.getState() == "playing") then
        im.tooltip("New Markers will get the time of the current replay. Starting the path also starts the replay.")
        if linkReplay[0] then
          im.Text("Replay Controls")
          im.SameLine()

          local x = im.GetCursorPosX()
          if editor.uiIconImageButton(core_replay.isPaused() and editor.icons.play_arrow or editor.icons.pause, im.ImVec2(25,25), nil, nil, nil, 'togglePlay') then
            core_replay.togglePlay()
          end
          im.SameLine()
          im.PushItemWidth(im.GetContentRegionAvailWidth())
          local relativePos = im.FloatPtr(core_replay.getPositionSeconds())
          local maxSecs = core_replay.getTotalSeconds()
          if im.SliderFloat("##replay slider", relativePos, 0, maxSecs, "%.3f", 1) then
            core_replay.pause(true)
            core_replay.seek(relativePos[0] / maxSecs)
          end
          im.SetCursorPosX(x)
          if im.Button("-10") then core_replay.seek((relativePos[0] -10) / maxSecs) end im.SameLine()
          if im.Button("-2") then core_replay.seek((relativePos[0] -2) / maxSecs) end im.SameLine()
          if im.Button("-1") then core_replay.seek((relativePos[0] -1) / maxSecs) end im.SameLine()
          if im.Button("+1") then core_replay.seek((relativePos[0] +1) / maxSecs) end im.SameLine()
          if im.Button("+2") then core_replay.seek((relativePos[0] +2) / maxSecs) end im.SameLine()
          if im.Button("+10") then core_replay.seek((relativePos[0] +10) / maxSecs) end
        end
      end
      im.EndChild()

      -- Path parameters window
      local avail = im.GetContentRegionAvail()

      im.BeginChild1("M.currentPath", im.ImVec2(0, im.GetFontSize() * 5 * im.uiscale[0]), im.WindowFlags_ChildWindow)
      im.Text("Current Path")

      local pathNameField = im.ArrayChar(64, M.currentPath.name)
      if im.InputText("", pathNameField, 64, im.InputTextFlags_EnterReturnsTrue) then
        editor.history:commitAction("ChangePathField", {path = M.currentPath, field = "name", oldValue = M.currentPath.name, newValue = ffi.string(pathNameField)}, changePathFieldActionUndo, changePathFieldActionRedo)
      end

      local manualFov = im.BoolPtr(M.currentPath.manualFov or false)
      if im.Checkbox("Allow manual FOV change", manualFov) then
        editor.history:commitAction("ChangePathField", {path = M.currentPath, field = "manualFov", oldValue = M.currentPath.manualFov, newValue = manualFov[0]}, changePathFieldActionUndo, changePathFieldActionRedo)
      end
      im.tooltip("Allow the user to override the fov while the path camera is running")
      im.SameLine()
      local looped = im.BoolPtr(M.currentPath.looped or false)
      if im.Checkbox("Looped", looped) then
        editor.history:commitAction("ChangePathField", {path = M.currentPath, field = "looped", oldValue = M.currentPath.looped, newValue = looped[0]}, changePathFieldActionUndo, changePathFieldActionRedo)
      end
      im.tooltip("The path will repeat when it reaches the end")
      im.EndChild()

      displayMarkerList()

      im.Text('Path Controls')
      local avail = im.GetContentRegionAvail()

      local playerVehicle = be:getPlayerVehicle(0)
      if not playerVehicle then
        im.BeginDisabled()
      end
      im.PushStyleColor2(im.Col_Button, im.ImVec4(0, .5, 0, 0.5))
      im.PushStyleColor2(im.Col_ButtonHovered, im.ImVec4(0, .7, 0, 0.6))
      im.PushStyleColor2(im.Col_ButtonActive, im.ImVec4(0, .8, 0, 0.7))
      if im.Button("Play",im.ImVec2(avail.x/2 - 5, 0)) then
        playCurrentPath()
      end
      im.PopStyleColor(3)
      if not playerVehicle then
        im.EndDisabled()
        im.tooltip("You need an active vehicle to start the path camera")
      end

      im.SameLine()
      if not playerVehicle then
        im.BeginDisabled()
      end
      im.PushStyleColor2(im.Col_Button, im.ImVec4(0, .3, 0, 0.5))
      im.PushStyleColor2(im.Col_ButtonHovered, im.ImVec4(0, .5, 0, 0.6))
      im.PushStyleColor2(im.Col_ButtonActive, im.ImVec4(0, .6, 0, 0.7))
      if im.Button("Play (Close Editor)",im.ImVec2(avail.x/2 - 5, 0)) then
        editor.setEditorActive(false)
        playCurrentPath()
      end
      im.PopStyleColor(3)
      if not playerVehicle then
        im.EndDisabled()
        im.tooltip("You need an active vehicle to start the path camera")
      end

      im.PushStyleColor2(im.Col_Button, im.ImVec4(.5, 0, 0, 0.5))
      im.PushStyleColor2(im.Col_ButtonHovered, im.ImVec4(.7, 0, 0, 0.6))
      im.PushStyleColor2(im.Col_ButtonActive, im.ImVec4(.8, 0, 0, 0.7))
      if im.Button("Stop",im.ImVec2(avail.x - 2, 0)) then
        core_paths.stopCurrentPath()
        if (core_replay.getState() == 'playing') and not core_replay.isPaused() then
          core_replay.togglePlay()
        end
      end
      im.PopStyleColor(3)
    end
  end
  editor.endWindow()

  for i, path in ipairs(core_paths.getPaths()) do
    drawDebugPath(path, focusPos)
  end

  --[[if displayPreview[0] and M.currentPath then
    if editor.beginWindow('cameraPathPreviewWindow', 'Camera path preview') then
      previewWindowSize = im.GetContentRegionAvail()
      local texObj = imUtils.texObj('#cameraPathPreview')
      im.Image(texObj.texId, previewWindowSize)
      editor.endWindow()
    end
  end]]
end

local function onActivate()
  editor.clearObjectSelection()
  editor.showWindow(toolWindowName)
  editor.showWindow("cameraPathPreviewWindow")
end

local function onDeactivate()
  editor.hideWindow(toolWindowName)
end

local function onPreRender()
  if not editor or not editor.isEditorActive or not editor.isEditorActive() or not editor.editMode or (editor.editMode.displayName ~= editModeName) then
    return
  end
  local vm = GFXDevice.getVideoMode()
  local w, h = vm.width, vm.height
  windowAspectRatio = w/h
  drawGrid(gridColor)
end

local function onDeleteSelection()
  deleteMarker()
end

local function onEditorInitialized()
  editor.editModes.camPathEditMode =
  {
    displayName = editModeName,
    onUpdate = nop,
    onActivate = onActivate,
    onDeactivate = onDeactivate,
    onDeleteSelection = onDeleteSelection,
    actionMap = "CamPathEditor",
    icon = editor.icons.simobject_camera_path_node,
    iconTooltip = "Camera Path Editor",
    auxShortcuts = {},
    hideObjectIcons = true
  }
  editor.editModes.camPathEditMode.auxShortcuts[bit.bor(editor.AuxControl_LMB, editor.AuxControl_Shift)] = "Add new marker"
  editor.registerWindow(toolWindowName, im.ImVec2(200, 400))
  editor.registerWindow('cameraPathPreviewWindow', im.ImVec2(600, 400))
end

local function onClientStartMission()
  selectPath(nil)
end

M.onEditorInitialized = onEditorInitialized
M.onExtensionLoaded = onExtensionLoaded
M.onEditorGui = onEditorGui
M.onClientStartMission = onClientStartMission
M.onPreRender = onPreRender
M.selectPath = selectPath
return M
