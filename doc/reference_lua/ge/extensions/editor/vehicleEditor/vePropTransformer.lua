-- This Source Code Form is subject to the terms of the bCDDL, var. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local im = ui_imgui

local wndName = "Prop Transformer"
local wndOpen = false
local mainWndFlags = bit.bor(im.WindowFlags_NoBringToFrontOnFocus)
M.menuEntry = "JBeam Editor/Prop Transformer"

local nodeRenderRadius = 0.02
local nodeHoveredRenderRadius = 0.03
local nodeCollisionRadius = 0.035

local zeroVec = vec3(0,0,0)
local arrowHeadVec = vec3(0,0.075,0)

local q1 = quatFromEuler(0, 0, math.pi * 11/12)
local q2 = quatFromEuler(0, 0, -math.pi * 11/12)
local q3 = quatFromEuler(0, math.pi / 2, 0)

local hoveredColor = ColorF(1,0.65,0,1)
local regularColor = ColorF(0.75,1,0,1)

local blankColor = ColorF(0,0,0,0)
local redColor = ColorF(1,0,0,1)
local yellowColor = ColorF(1,1,0,1)
local greenColor = ColorF(0,1,0,1)
local blueColor = ColorF(0,0,1,1)
local whiteColor = ColorF(1,1,1,1)
local whiteColor255 = ColorI(255,255,255,255)

local textBackgroundColor = ColorI(0,0,0,192)

-- Template
local initStateTemplate = {
  mode = 1,
  propertyEditing = nil, -- baseTranslationGlobal, baseRotationGlobal
  propsData = nil,
  hitPropRefNodes = {},
  propSelectorIdx = 1,
  propSelectorCount = 1,
  pickedProp = nil,
  lastPropBaseTranslationGlobal = vec3(),
  lastPropBaseRotationGlobal = quat(),
  axisGizmo = {
    startPos = vec3()
  }
}

local initStates = {}
local states = {}
local initVehDatas = {}

local initState = nil
local state = nil
local initVehData = nil

local inputBaseTranslationGlobal = im.ArrayFloat(3)
local inputBaseTranslation = im.ArrayFloat(3)
local inputBaseRotation = im.ArrayFloat(3)
local inputBaseRotationGlobal = im.ArrayFloat(3)


local function getClosestObjectToCamera(cameraPos, hitObjects)
  if next(hitObjects) == nil then return nil end

  local chosenObjData = hitObjects[1]
  if #hitObjects > 1 then
    -- If multiple hit objects, use closest one to camera

    local minDist = (chosenObjData.pos - cameraPos):length()

    for k, objData in ipairs(hitObjects) do
      if k >= 2 then
        local dist = (objData.pos - cameraPos):length()

        if dist < minDist then
          minDist = dist
          chosenObjData = objData
        end
      end
    end
  end

  return chosenObjData
end

local dragging = false

local function gizmoBeginDrag()
  local prop = state.pickedProp
  if not prop then return end
  local propObj = vEditor.vehicle:getProp(prop.pid)

  state.lastPropBaseTranslationGlobal:set(propObj:getBaseTranslationGlobal())
  state.lastPropBaseRotationGlobal:set(propObj:getBaseRotationGlobalQuat())

  state.axisGizmo.startPos = editor.getAxisGizmoTransform():inverse():getColumn(3)
  state.axisGizmo.startRot = quat(editor.getAxisGizmoTransform():toQuatF())

  dragging = true
end

local function gizmoDragging()
  local prop = state.pickedProp
  if not prop then return end
  local propObj = vEditor.vehicle:getProp(prop.pid)

  -- Delta pos in local coordinates
  local pos = editor.getAxisGizmoTransform():inverse():getColumn(3)
  local deltaPos = -(pos - state.axisGizmo.startPos)

  local rot = quat(editor.getAxisGizmoTransform():toQuatF())
  local deltaRot = rot * state.axisGizmo.startRot:inversed()

  if state.propertyEditing == "baseTranslationGlobal" then
    propObj:setBaseTranslationGlobal(deltaPos + state.lastPropBaseTranslationGlobal)

  elseif state.propertyEditing == "baseRotationGlobal" then
    local newRot = state.lastPropBaseRotationGlobal * deltaRot
    propObj:setBaseRotationGlobalQuat(QuatF(newRot.x, newRot.y, newRot.z, newRot.w))
  end
end

local function gizmoEndDrag()
  dragging = false
end

local function transformProp()
  local prop = state.pickedProp
  if not prop then return end

  local dirFront = vEditor.vehicle:getDirectionVector()
  local dirUp = vEditor.vehicle:getDirectionVectorUp()

  local refPos = vEditor.vdata.nodes[vEditor.vdata.refNodes[0].ref].pos

  -- Vehicle coordinates -> Prop coordinates
  local rot = quatFromDir(-dirFront, dirUp)

  local propObj = vEditor.vehicle:getProp(prop.pid)
  local baseTranslationJBeamCoords = propObj:getBaseTranslationGlobal()

  local axisGizmoPos = quatFromDir(-dirFront, dirUp) * (baseTranslationJBeamCoords - refPos)
  axisGizmoPos:setAdd(vEditor.vehiclePos)

  if not dragging then
    worldEditorCppApi.setAxisGizmoRenderPlane(false)
    worldEditorCppApi.setAxisGizmoRenderPlaneHashes(false)
    worldEditorCppApi.setAxisGizmoRenderMoveGrid(false)

    editor.setAxisGizmoAlignment(editor.AxisGizmoAlignment_Local)
    local transform = QuatF(rot.x, rot.y, rot.z, rot.w):getMatrix()
    transform:setPosition(axisGizmoPos)
    editor.setAxisGizmoTransform(transform)
  end

  if state.propertyEditing then
    editor.updateAxisGizmo(gizmoBeginDrag, gizmoEndDrag, gizmoDragging)
    editor.drawAxisGizmo()
  end

  return dragging
end

local tempVec = vec3()

local function pickProp(transforming)
  table.clear(state.hitPropRefNodes)

  local ray = getCameraMouseRay()

  local rayStartPos = ray.pos
  local rayDir = ray.dir

  local leftClicked = im.IsMouseClicked(0)
  local imguiNotHovered = not im.IsAnyItemHovered() and not im.IsWindowHovered(im.HoveredFlags_AnyWindow)

  local dirFront = vEditor.vehicle:getDirectionVector()
  local dirUp = vEditor.vehicle:getDirectionVectorUp()

  local refPos = vEditor.vdata.nodes[vEditor.vdata.refNodes[0].ref].pos
  local rot = quatFromDir(-dirFront, dirUp)

  -- 1st, get list of prop ref nodes hovered over by mouse cursor
  for i = 0, tableSizeC(state.propsData) - 1 do
    local prop = state.propsData[i]
    local node = vEditor.vdata.nodes[prop.idRef]

    -- Initial node position superimposed on vehicle
    tempVec:setSub2(node.pos, refPos)

    local nodePos = vEditor.vehiclePos + rot * tempVec --vEditor.vehicleNodesPos[nodeID]

    -- Only pick nodes if not hovering IMGUI windows
    if imguiNotHovered and not transforming then
      local dist, _ = intersectsRay_Sphere(rayStartPos, rayDir, nodePos, nodeCollisionRadius)

      if dist and dist < 100 then -- if mouse over node
        table.insert(state.hitPropRefNodes, {node = node, pos = nodePos})
      end
    end

    debugDrawer:drawSphere(nodePos, nodeRenderRadius, regularColor, false)
  end

  if transforming then return end

  -- 2nd, find closest node to camera
  local chosenData = getClosestObjectToCamera(rayStartPos, state.hitPropRefNodes)

  -- If no nodes hovered, then return
  if not chosenData then
    return
  end

  -- 3rd, after choosing closest ref node, get props related to ref node
  -- and have user select specific prop using mouse scroll wheel
  local chosenNodeID = chosenData.node.cid
  local chosenNodePos = chosenData.pos

  local id = 1

  for i = 0, tableSizeC(state.propsData) - 1 do
    local prop = state.propsData[i]
    local node = vEditor.vdata.nodes[prop.idRef]

    if node.cid == chosenNodeID then
      -- On left click, pick node!
      if state.propSelectorIdx == id and leftClicked then
        local propObj = vEditor.vehicle:getProp(prop.pid)

        state.pickedProp = prop
        state.lastPropBaseTranslationGlobal:set(propObj:getBaseTranslationGlobal())
        state.lastPropBaseRotationGlobal:set(propObj:getBaseRotationGlobalQuat())

        inputBaseTranslationGlobal[0] = im.Float(0)
        inputBaseTranslationGlobal[1] = im.Float(0)
        inputBaseTranslationGlobal[2] = im.Float(0)

        inputBaseTranslation[0] = im.Float(0)
        inputBaseTranslation[1] = im.Float(0)
        inputBaseTranslation[2] = im.Float(0)

        inputBaseRotation[0] = im.Float(0)
        inputBaseRotation[1] = im.Float(0)
        inputBaseRotation[2] = im.Float(0)

        inputBaseRotationGlobal[0] = im.Float(0)
        inputBaseRotationGlobal[1] = im.Float(0)
        inputBaseRotationGlobal[2] = im.Float(0)

        state.mode = 1

        return
      end

      local text = string.format("mesh: %s | func: %s | node: %s", prop.mesh, prop.func, node.name or node.cid)
      local color = state.propSelectorIdx == id and redColor or whiteColor

      debugDrawer:drawSphere(chosenNodePos, nodeHoveredRenderRadius, hoveredColor, false)
      debugDrawer:drawTextAdvanced(chosenNodePos, text, color, true, false, textBackgroundColor)

      id = id + 1
    end
  end

  state.propSelectorCount = id
end

local function renderPickedProp()
  local prop = state.pickedProp
  if not prop then return end

  local propObj = vEditor.vehicle:getProp(prop.pid)

  local dirFront = vEditor.vehicle:getDirectionVector()
  local dirUp = vEditor.vehicle:getDirectionVectorUp()

  local propRefNode = vEditor.vdata.nodes[prop.idRef]
  local propRefXNode = vEditor.vdata.nodes[prop.idX]
  local propRefYNode = vEditor.vdata.nodes[prop.idY]

  local propRefPos = propRefNode.pos
  local propRefXPos = propRefXNode.pos
  local propRefYPos = propRefYNode.pos

  local nX = propRefXPos - propRefPos
  local nY = propRefYPos - propRefPos

  local nZ = nY:cross(nX)
  nZ:normalize()

  local propRefZPos = propRefPos + nZ

  local refPos = vEditor.vdata.nodes[vEditor.vdata.refNodes[0].ref].pos
  local rot = quatFromDir(-dirFront, dirUp)

  local propRefWorldPos = rot * (propRefPos - refPos) + vEditor.vehiclePos
  local propRefXWorldPos = rot * (propRefXPos - refPos) + vEditor.vehiclePos
  local propRefYWorldPos = rot * (propRefYPos - refPos) + vEditor.vehiclePos
  local propRefZWorldPos = rot * (propRefZPos - refPos) + vEditor.vehiclePos

  local text = string.format("mesh: %s | func: %s | node: %s", prop.mesh, prop.func, propRefNode.name or propRefNode.cid)

  debugDrawer:drawSphere(propRefWorldPos, nodeHoveredRenderRadius, hoveredColor, false)
  debugDrawer:drawTextAdvanced(propRefWorldPos, text, whiteColor, true, false, ColorI(0,0,0,192))

  debugDrawer:drawSphere(propRefWorldPos, nodeHoveredRenderRadius, whiteColor, false)
  debugDrawer:drawSphere(propRefXWorldPos, nodeHoveredRenderRadius, redColor, false)
  debugDrawer:drawSphere(propRefYWorldPos, nodeHoveredRenderRadius, greenColor, false)

  debugDrawer:drawLine(zeroVec, zeroVec, blankColor) -- workaround for bug
  debugDrawer:drawLine(propRefWorldPos, propRefXWorldPos, redColor)
  debugDrawer:drawLine(propRefWorldPos, propRefYWorldPos, greenColor)
  debugDrawer:drawLine(propRefWorldPos, propRefZWorldPos, blueColor)

  -- special rendering for lights

  if prop.mesh == "SPOTLIGHT" then
    local lightRange = prop.lightRange
    local lightCol = ColorF(prop.lightColor.r / 255, prop.lightColor.g / 255, prop.lightColor.b / 255, 1)
    local lightCol255 = ColorI(prop.lightColor.r, prop.lightColor.g, prop.lightColor.b, 255)

    local worldMat = propObj:getLiveTransformWorld()

    local lightPos = worldMat:getColumn(3) + vEditor.vehiclePos
    local qDir = quat(worldMat:toQuatF())
    local dirVec = qDir * vec3(0, lightRange, 0)

    debugDrawer:drawSphere(lightPos, 0.04, lightCol)
    debugDrawer:drawLine(lightPos, lightPos + dirVec, lightCol)

    -- two arrow heads so can be viewed from any angle
    debugDrawer:drawTriSolid(
      lightPos + dirVec,
      lightPos + q1 * qDir * arrowHeadVec + dirVec,
      lightPos + q2 * qDir * arrowHeadVec + dirVec,
      lightCol255
    )
    debugDrawer:drawTriSolid(
      lightPos + dirVec,
      lightPos + q1 * q3 * qDir * arrowHeadVec + dirVec,
      lightPos + q2 * q3 * qDir * arrowHeadVec + dirVec,
      lightCol255
    )

  elseif prop.mesh == "POINTLIGHT" then
    local lightRange = prop.lightRange
    local lightCol1 = ColorF(prop.lightColor.r / 255, prop.lightColor.g / 255, prop.lightColor.b / 255, 1.0)
    local lightCol2 = ColorF(prop.lightColor.r / 255, prop.lightColor.g / 255, prop.lightColor.b / 255, 0.1)

    local worldMat = propObj:getLiveTransformWorld()
    local lightPos = worldMat:getColumn(3) + vEditor.vehiclePos

    debugDrawer:drawSphere(lightPos, 0.04, lightCol1)
    debugDrawer:drawSphere(lightPos, lightRange, lightCol2)
  end
end

local function removeVehicle(vehID)
  if vehID == -1 then return end

  initVehDatas[vehID] = nil
  initStates[vehID] = nil
  states[vehID] = nil
end

local function switchVehicle(vehID)
  if vehID == -1 then return end

  if not initVehDatas[vehID] then
    local vehData = core_vehicle_manager.getVehicleData(vehID)

    if vehData then
      initVehDatas[vehID] = deepcopy(vehData)
      initStates[vehID] = deepcopy(initStateTemplate)
      initStates[vehID].propsData = deepcopy(initVehDatas[vehID].vdata.props)
      states[vehID] = deepcopy(initStates[vehID])
    end
  end

  initVehData = initVehDatas[vehID]
  initState = initStates[vehID]
  state = states[vehID]
end

local function onVehicleEditorRenderJBeams(dtReal, dtSim, dtRaw)
  if not (wndOpen and vEditor.vehicle and vEditor.vdata) then return end

  -- Initialize initial state with vehicle data
  if not initVehData then
    switchVehicle(vEditor.vehicle:getID())
  end

  -- Render picked stuff
  renderPickedProp()

  -- Transform picked prop
  transformProp()

  if state.mode == 2 then
    pickProp()
  end
end

local function onEditorGui(dt)
  if not vEditor.vehicle then return end

  if editor.beginWindow(wndName, wndName, mainWndFlags) then
    wndOpen = true

    if state then
      local io = im.GetIO()
      state.propSelectorIdx = clamp(state.propSelectorIdx + clamp(io.MouseWheel, -1, 1), 1, state.propSelectorCount - 1)

      if im.Button("Pick Prop") then
        if state.mode ~= 2 then
          state.pickedProp = nil
          state.mode = 2
        else
          state.mode = 1
        end
      end

      local prop = state.pickedProp

      if prop then
        local propObj = vEditor.vehicle:getProp(prop.pid)

        local baseTranslation = propObj:getBaseTranslation()
        local baseTranslationGlobal = propObj:getBaseTranslationGlobal()
        local baseRotation = propObj:getBaseRotation()
        local baseRotationGlobal = propObj:getBaseRotationGlobal()

        inputBaseTranslation[0] = im.Float(baseTranslation.x)
        inputBaseTranslation[1] = im.Float(baseTranslation.y)
        inputBaseTranslation[2] = im.Float(baseTranslation.z)

        inputBaseTranslationGlobal[0] = im.Float(baseTranslationGlobal.x)
        inputBaseTranslationGlobal[1] = im.Float(baseTranslationGlobal.y)
        inputBaseTranslationGlobal[2] = im.Float(baseTranslationGlobal.z)

        inputBaseRotation[0] = im.Float(baseRotation.x * 180.0 / math.pi)
        inputBaseRotation[1] = im.Float(baseRotation.y * 180.0 / math.pi)
        inputBaseRotation[2] = im.Float(baseRotation.z * 180.0 / math.pi)

        inputBaseRotationGlobal[0] = im.Float(baseRotationGlobal.x * 180.0 / math.pi)
        inputBaseRotationGlobal[1] = im.Float(baseRotationGlobal.y * 180.0 / math.pi)
        inputBaseRotationGlobal[2] = im.Float(baseRotationGlobal.z * 180.0 / math.pi)

        if im.InputFloat3("baseTranslation", inputBaseTranslation, "%0.3f") then
          propObj:setBaseTranslation(vec3(inputBaseTranslation[0], inputBaseTranslation[1], inputBaseTranslation[2]))
        end
        if im.InputFloat3("baseTranslationGlobal", inputBaseTranslationGlobal, "%0.3f") then
          propObj:setBaseTranslationGlobal(vec3(inputBaseTranslationGlobal[0], inputBaseTranslationGlobal[1], inputBaseTranslationGlobal[2]))
        end
        if im.InputFloat3("baseRotation", inputBaseRotation, "%0.3f", im.InputTextFlags_EnterReturnsTrue) then
          local rot = vec3(inputBaseRotation[0] * math.pi / 180.0, inputBaseRotation[1] * math.pi / 180.0, inputBaseRotation[2] * math.pi / 180.0)
          propObj:setBaseRotation(rot)
        end
        if im.InputFloat3("baseRotationGlobal", inputBaseRotationGlobal, "%0.3f", im.InputTextFlags_EnterReturnsTrue) then
          local rot = vec3(inputBaseRotationGlobal[0] * math.pi / 180.0, inputBaseRotationGlobal[1] * math.pi / 180.0, inputBaseRotationGlobal[2] * math.pi / 180.0)
          propObj:setBaseRotationGlobal(rot)
        end

        if im.Button("Set baseTranslationGlobal w/ Gizmo") then
          editor.setAxisGizmoMode(editor.AxisGizmoMode_Translate)
          state.propertyEditing = "baseTranslationGlobal"
        end
        if im.Button("Set baseRotationGlobal w/ Gizmo") then
          editor.setAxisGizmoMode(editor.AxisGizmoMode_Rotate)
          state.propertyEditing = "baseRotationGlobal"
        end
      end
    end
  else
    wndOpen = false
  end
  editor.endWindow()
end

local function onVehicleSwitched(oldVehicle, newVehicle, player)
  switchVehicle(newVehicle)
end

local function onVehicleSpawned(id)
  removeVehicle(id)
  switchVehicle(id)
end

local function open()
  editor.showWindow(wndName)
end

local function onEditorToolWindowShow(window)
  if window == wndName then
    wndOpen = true
  end
end

local function onEditorToolWindowHide(window)
  if window == wndName then
    wndOpen = false
  end
end

local function onEditorInitialized()
  editor.registerWindow(wndName, im.ImVec2(200,100))
end

M.onVehicleEditorRenderJBeams = onVehicleEditorRenderJBeams
M.onEditorGui = onEditorGui
M.onVehicleSwitched = onVehicleSwitched
M.onVehicleSpawned = onVehicleSpawned
M.open = open
M.onEditorToolWindowShow = onEditorToolWindowShow
M.onEditorToolWindowHide = onEditorToolWindowHide
M.onEditorInitialized = onEditorInitialized

return M