-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local im = ui_imgui
local toolWindowName = "objectToSplineEditor"
local toolName = "Object To Spline Editor"

local guideId, objId, guideErrorTxt
local savedPoints, savedParams = {}, {}
local objTypes = {"TSStatic", "BeamNGVehicle"} -- sensible world object classes
local guideTypes = {"DecalRoad", "MeshRoad"} -- sensible spline object classes
local gap = im.FloatPtr(0)
local startOffset = im.FloatPtr(0)
local endOffset = im.FloatPtr(0)
local objAxis = im.IntPtr(1)
local objLimit = im.IntPtr(500)
local useNormal = im.BoolPtr(true)
local useSimGroup = im.BoolPtr(false)

local allowRandom = im.BoolPtr(false)
local maxRandomGap = im.FloatPtr(0)
local randomPosOffset = im.FloatPtr(0)
local randomRotOffset = im.FloatPtr(0)
local useRandomPosZ = im.BoolPtr(false)
local useRandomRotXY = im.BoolPtr(false)
local useGauss = im.BoolPtr(false)

local vecUp = vec3(0, 0, 1)
local objColor = ColorF(1, 1, 0, 0.5)
local guideColor = ColorF(0, 1, 0, 1)
local _changed = false

local function getRandom(scl, gauss) -- returns a random number, scaled and centered at zero
  scl = scl or 1
  return gauss and (randomGauss3() / 3 - 0.5) * 2 * scl or (math.random() - 0.5) * 2 * scl
end

local function getNewExtents(objId, useWorldBox) -- returns the scaled object extents
  local obj = scenetree.findObjectById(objId)
  local extents = useWorldBox and obj:getWorldBox():getExtents() or obj:getObjectBox():getExtents()
  local scl = obj:getScale() * 0.5
  return vec3(extents.x * scl.x, extents.y * scl.y, extents.z * scl.z)
end

local function setObjectTransform(id, pos, rot) -- sets the object position and rotation
  local obj = scenetree.findObjectById(id)
  if not obj then return end

  local transform = QuatF(rot.x, rot.y, rot.z, rot.w):getMatrix()
  transform:setPosition(pos)
  obj:setTransform(transform)
end

local function createObjects(objId, points, params, presetIds) -- actually creates objects with the given positions
  local obj = scenetree.findObjectById(objId)
  if not obj or not points then return end

  params = params or {}
  local newIds = {}
  local newGroup = scenetree.findObjectById(tonumber(obj:getField("parentGroup", 0)))
  local groupId

  if params.useSimGroup then
    newGroup = createObject("SimGroup")
    newGroup:registerObject(Sim.getUniqueName("SplineObjects"))
    scenetree.MissionGroup:addObject(newGroup)
    groupId = newGroup:getId()
  end

  local memento = SimObjectMemento()
  memento:save(obj, 4) -- original object
  local grp = newGroup or scenetree.MissionGroup

  for _, v in ipairs(points) do
    if presetIds and presetIds[i] then
      SimObject.setForcedId(presetIds[i])
    end
    local obj = memento:restore()
    grp:addObject(obj)
    table.insert(newIds, obj:getId())

    setObjectTransform(obj:getId(), v.pos, v.rot)
  end

  return newIds, groupId -- only returns group id if new group was created
end

local function createSplineArray(guideId, gap, startOffset, endOffset, params) -- returns an array of positions and rotations along the decal road
  local guide = scenetree.findObjectById(guideId)
  if not guide then return end

  params = params or {}

  gap = math.max(0.001, gap)
  local currDist = 0
  local innerDist = gap * 0.5 + (startOffset or 0)
  local maxDist = math.huge
  local edgeCount = guide:getEdgeCount()
  local pos1, pos2, dirVec, dirVecUp = vec3(), vec3(), vec3(), vec3()
  local points = {}
  local hasTerrain = core_terrain.getTerrain() and true or false

  if endOffset and endOffset ~= 0 then
    local totalDist = 0
    for i = 0, edgeCount - 2 do
      pos1:set(guide.className == "DecalRoad" and guide:getMiddleEdgePosition(i) or guide:getTopMiddleEdgePosition(i))
      pos2:set(guide.className == "DecalRoad" and guide:getMiddleEdgePosition(i + 1) or guide:getTopMiddleEdgePosition(i + 1))
      totalDist = totalDist + pos1:distance(pos2)
    end
    maxDist = totalDist - endOffset
  end

  if not params.useNormal then
    dirVecUp:set(vecUp)
  end

  local count = 0
  local limit = math.min(params.objLimit or 10000, 10000)
  for i = 0, edgeCount - 2 do
    pos1:set(guide.className == "DecalRoad" and guide:getMiddleEdgePosition(i) or guide:getTopMiddleEdgePosition(i))
    pos2:set(guide.className == "DecalRoad" and guide:getMiddleEdgePosition(i + 1) or guide:getTopMiddleEdgePosition(i + 1))
    local dist = math.max(1e-12, pos2:distance(pos1))
    currDist = currDist + dist
    if currDist > maxDist then break end

    while innerDist <= dist do
      local dirSide = params.flipX and 1 or -1
      local dirForwards = params.flipY and -1 or 1
      dirVec:set((pos2 - pos1):normalized() * dirForwards)

      local posOffset, rotOffset = vec3(0, 0, 0), quat(0, 0, 0, 1)
      if params.randomPosOffset and params.randomPosOffset ~= 0 then
        local n = params.randomPosOffset
        posOffset:set(getRandom(n, params.useGauss), getRandom(n, params.useGauss), params.useRandomPosZ and getRandom(n, params.useGauss) or 0)
      end

      if params.randomRotOffset and params.randomRotOffset ~= 0 then
        local n = params.randomRotOffset
        local useXY = params.useRandomRotXY
        rotOffset:set(quatFromEuler(useXY and getRandom(n, params.useGauss) or 0, useXY and getRandom(n, params.useGauss) or 0, getRandom(n, params.useGauss)))
      end

      local pos = linePointFromXnorm(pos1, pos2, innerDist / dist) + posOffset
      if params.useNormal then
        local validSurface = true
        if hasTerrain then
          local z = core_terrain.getTerrainHeight(pos)
          if math.abs(pos.z - z) >= 0.1 then -- terrain is below or above the current surface
            validSurface = false
          else
            pos.z = z
            dirVecUp:set(core_terrain.getTerrainSmoothNormal(pos))
          end
        end
        if not hasTerrain or not validSurface then
          pos.z = be:getSurfaceHeightBelow(pos + vecUp)
          dirVecUp:set(map.surfaceNormal(pos, 1))
        end
      end
      pos.z = pos.z + posOffset.z -- adjust after snapping

      if params.useCross then
        dirVec:set(dirVec:cross(dirVecUp) * dirSide)
      end

      table.insert(points, {pos = pos, rot = quatFromDir(dirVec, dirVecUp) * rotOffset * quatFromEuler(math.pi, math.pi, math.pi)})
      count = count + 1
      if count >= limit then break end

      local nextGap = params.maxRandomGap and gap + math.random() * params.maxRandomGap or gap
      nextGap = math.max(0.001, nextGap) -- prevents infinite loop
      innerDist = dist * (innerDist / dist) + nextGap
    end
    if count >= limit then break end
    innerDist = innerDist - dist
  end

  return points
end

local function createObjectsUndo(data)
  for _, id in ipairs(data.objectIds) do
    editor.deleteObject(id)
  end
  if data.groupId then
    editor.deleteObject(data.groupId)
  end
  editor.clearObjectSelection()
end

local function createObjectsRedo(data)
  data.objectIds, data.groupId = createObjects(data.objId, data.points, data.params, data.objectIds)
end

local function work(guideId, objId, params, doCreate, keepPoints) -- runs the main functionality
  params = params or {}
  params.gap = params.gap or 0
  params.startOffset = params.startOffset or 0
  params.endOffset = params.endOffset or 0

  local obj = scenetree.findObjectById(objId or 0)
  if obj then
    local length = 0
    local extents = getNewExtents(objId)
    if params.axisMode then
      length = extents[params.axisMode] * 2
    else
      if extents.x >= extents.y then
        length = extents.x * 2
        params.axisMode = "x"
      else
        length = extents.y * 2
        params.axisMode = "y"
      end
    end
    params.useCross = params.axisMode == "x"
    params.gap = params.gap + length
  end

  -- uses the same data shown from the Preview button
  local points = (keepPoints and savedPoints[1]) and savedPoints or createSplineArray(guideId, params.gap, params.startOffset, params.endOffset, params)

  if doCreate then
    local actionData = {objId = objId, points = deepcopy(points), params = deepcopy(params)}
    editor.history:commitAction("Create Objects At Spline", actionData, createObjectsUndo, createObjectsRedo)
    --createObjects(objId, points, params)
    table.clear(savedPoints)
  else
    savedPoints = points
  end
end

local function getSelection(classNames) -- validates the current editor selection
  local id
  if editor.selection and editor.selection.object and editor.selection.object[1] then
    local currId = editor.selection.object[1]
    if not classNames or arrayFindValueIndex(classNames, scenetree.findObjectById(currId).className) then
      id = currId
    end
  end
  return id
end

local function onEditorGui()
  if editor.beginWindow(toolWindowName, toolName) then
    if objId and not scenetree.findObjectById(objId) then
      objId = nil
    end
    if guideId and not scenetree.findObjectById(guideId) then
      guideId = nil
    end

    im.Columns(2)
    im.SetColumnWidth(0, 60)

    -- object selection
    local str = "none"
    im.TextUnformatted("Object: ")
    im.NextColumn()

    if objId then
      if editor.uiIconImageButton(editor.icons.check_circle, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0])) then
        editor.selectEditMode(editor.editModes.objectSelect)
        editor.selectObjectById(objId)
        editor.fitViewToSelectionSmooth()
      end
      im.SameLine()
      str = tostring(scenetree.findObjectById(objId):getName()).." ["..objId.."]"
    end
    im.TextUnformatted(str)
    im.SameLine()
    if im.Button("Get From Selection##objectMode") then
      objId = getSelection()
    end
    im.tooltip("Select the object that you want to make copies of.")
    im.NextColumn()

    -- spline selection
    str = guideId or "none"
    im.TextUnformatted("Spline: ")
    im.NextColumn()

    if guideId then
      if editor.uiIconImageButton(editor.icons.check_circle, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0])) then
        editor.selectEditMode(editor.editModes.objectSelect)
        editor.selectObjectById(guideId)
        editor.fitViewToSelectionSmooth()
      end
      im.SameLine()
      str = tostring(scenetree.findObjectById(guideId):getName()).." ["..guideId.."]"
    end
    im.TextUnformatted(str)
    im.SameLine()
    if im.Button("Get From Selection##splineMode") then
      guideId = getSelection(guideTypes)
      if guideId then
        guideErrorTxt = nil
        be:reloadCollision() -- rebuild collision for mesh roads
      else
        guideErrorTxt = "Needs: DecalRoad or MeshRoad"
      end
    end
    im.tooltip("Select the road that you want to use as a spline or guide.")
    if guideErrorTxt then
      im.SameLine()
      im.TextColored(im.ImVec4(1, 1, 0, 1), guideErrorTxt)
    end

    im.NextColumn()

    im.Columns(1)
    im.Separator()

    -- basic parameters
    im.TextUnformatted("Setup")

    im.PushItemWidth(100)
    if im.InputFloat("Object Spacing##objectSpline", gap, 0.1, nil, "%.2f") then _changed = true end
    im.PopItemWidth()

    im.PushItemWidth(100)
    if im.InputFloat("Start Offset##objectSpline", startOffset, 0.1, nil, "%.2f") then _changed = true end
    im.PopItemWidth()

    im.PushItemWidth(100)
    if im.InputFloat("End Offset##objectSpline", endOffset, 0.1, nil, "%.2f") then _changed = true end
    im.PopItemWidth()

    if im.Checkbox("Align to Terrain", useNormal) then _changed = true end

    im.Checkbox("Use New Folder", useSimGroup)

    -- advanced parameters
    im.Dummy(im.ImVec2(0, 5))
    im.TextUnformatted("Advanced")

    if im.RadioButton2("Auto ##objectSpline", objAxis, im.Int(1)) then _changed = true end
    im.tooltip("Uses the longest side: X or Y")
    im.SameLine()
    if im.RadioButton2("X ##objectSpline", objAxis, im.Int(2)) then _changed = true end
    im.SameLine()
    if im.RadioButton2("Y ##objectSpline", objAxis, im.Int(3)) then _changed = true end
    im.SameLine()
    if im.RadioButton2("-X ##objectSpline", objAxis, im.Int(4)) then _changed = true end
    im.SameLine()
    if im.RadioButton2("-Y ##objectSpline", objAxis, im.Int(5)) then _changed = true end
    im.SameLine()
    im.TextUnformatted("Object Axis")

    im.Checkbox("Enable Random Offsets", allowRandom)
    if allowRandom[0] then
      im.PushItemWidth(100)
      if im.InputFloat("Added Random Spacing##objectSpline", maxRandomGap, 0.1, nil, "%.2f") then _changed = true end
      im.PopItemWidth()

      im.PushItemWidth(100)
      if im.InputFloat("Random Position Offset ##objectSpline", randomPosOffset, 0.1, nil, "%.2f") then _changed = true end
      im.PopItemWidth()

      im.SameLine()
      if im.Checkbox("Do Random Height", useRandomPosZ) then _changed = true end

      im.PushItemWidth(100)
      if im.InputFloat("Random Rotation Offset ##objectSpline", randomRotOffset, 0.1, nil, "%.2f") then _changed = true end
      im.PopItemWidth()

      im.SameLine()
      if im.Checkbox("Do Random Tilt", useRandomRotXY) then _changed = true end

      if im.Checkbox("Use Gaussian Randomization", useGauss) then _changed = true end
    end

    im.PushItemWidth(100)
    if im.InputInt("Object Limit##objectSpline", objLimit, 10) then _changed = true end
    im.PopItemWidth()

    local valid = guideId and objId
    if not valid then
      im.BeginDisabled()
    end

    local axisMode -- TODO: needs improvement
    if objAxis[0] == 2 or objAxis[0] == 4 then
      axisMode = "x"
    elseif objAxis[0] == 3 or objAxis[0] == 5 then
      axisMode = "y"
    end

    im.Separator()

    savedParams.gap = gap[0]
    savedParams.startOffset = startOffset[0]
    savedParams.endOffset = endOffset[0]
    savedParams.objLimit = objLimit[0]
    savedParams.axisMode = axisMode
    savedParams.flipX = objAxis[0] == 4
    savedParams.flipY = objAxis[0] == 5
    savedParams.useNormal = useNormal[0]
    savedParams.useSimGroup = useSimGroup[0]

    if allowRandom[0] then
      savedParams.maxRandomGap = maxRandomGap[0]
      savedParams.randomPosOffset = randomPosOffset[0]
      savedParams.randomRotOffset = randomRotOffset[0]
      savedParams.useRandomPosZ = useRandomPosZ[0]
      savedParams.useRandomRotXY = useRandomRotXY[0]
      savedParams.useGauss = useGauss[0]
    else -- set values to 0
      savedParams.maxRandomGap, savedParams.randomPosOffset, savedParams.randomRotOffset = 0, 0, 0
    end

    -- procedure
    if im.Button("Preview") then
      work(guideId, objId, savedParams, false)
    end
    im.SameLine()
    if im.Button("Create") then
      work(guideId, objId, savedParams, true, not _changed)
      _changed = false
    end

    if not valid then
      im.EndDisabled()
    end

    -- debug view
    local count = #savedPoints
    for i, v in ipairs(savedPoints) do
      local c = rainbowColor(count, i, 1)
      debugDrawer:drawSphere(v.pos, 0.5, ColorF(c[1], c[2], c[3], 0.6))
    end

    if objId then
      local obj = scenetree.findObjectById(objId)
      local offset = vec3(0, 0, 0)

      local extents = getNewExtents(objId, true)
      local currAxis = savedParams.axisMode
      if not currAxis then
        local temp = getNewExtents(objId)
        currAxis = temp.x >= temp.y and "x" or "y"
      end

      offset[currAxis] = extents[currAxis]
      if savedParams.flipX or savedParams.flipY then
        offset[currAxis] = -offset[currAxis]
      end

      local pos = obj:getPosition() + offset * 1.1
      pos.z = be:getSurfaceHeightBelow(pos + vecUp) + 0.1

      debugDrawer:drawSquarePrism(pos, pos + (pos - obj:getPosition()):z0():normalized(), Point2F(0.5, 0.5), Point2F(0.5, 0), objColor)
    end

    if guideId then
      local guide = scenetree.findObjectById(guideId)
      local up = vecUp * 0.01

      for i = 0, guide:getEdgeCount() - 2 do
        local pos1 = guide.className == "DecalRoad" and guide:getMiddleEdgePosition(i) + up or guide:getTopMiddleEdgePosition(i) + up
        local pos2 = guide.className == "DecalRoad" and guide:getMiddleEdgePosition(i + 1) + up or guide:getTopMiddleEdgePosition(i + 1) + up
        debugDrawer:drawLine(pos1, pos2, guideColor)
      end
    end
  end
  editor.endWindow()
end

local function onWindowMenuItem()
  editor.showWindow(toolWindowName)
end

local function onEditorInitialized()
  editor.addWindowMenuItem(toolName, onWindowMenuItem)
  editor.registerWindow(toolWindowName, im.ImVec2(420, 500))
end

M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized

return M