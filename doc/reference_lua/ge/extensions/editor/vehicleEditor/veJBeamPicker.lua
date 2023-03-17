-- This Source Code Form is subject to the terms of the bCDDL, var. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local imguiUtils = require('ui/imguiUtils')
local im = ui_imgui

local wndName = "JBeam Picker"
local wndOpen = false
local mainWndFlags = bit.bor(im.WindowFlags_MenuBar, im.WindowFlags_NoBringToFrontOnFocus)

M.menuEntry = "JBeam Debug/JBeam Picker"

local inputSuggestWndName = "inputSuggestionPopup"

local inputSuggestWndFlags = bit.bor(
    im.WindowFlags_NoTitleBar,
    im.WindowFlags_NoResize,
    im.WindowFlags_NoMove,
    im.WindowFlags_HorizontalScrollbar)

local nodeInputTextInput = im.ArrayChar(16)
local nodeInputTextPopupPos = im.ImVec2(0,0)
local nodeInputTextPopupSize = im.ImVec2(0,0)
local nodeInputTextPopupOpen = false

local beamInputTextInput = im.ArrayChar(16)
local beamInputTextPopupPos = im.ImVec2(0,0)
local beamInputTextPopupSize = im.ImVec2(0,0)
local beamInputTextPopupOpen = false

-- these are defined beam types in C, do not change the values
local NORMALTYPE = 0
local BEAM_ANISOTROPIC = 1
local BEAM_BOUNDED = 2
local BEAM_PRESSURED = 3
local BEAM_LBEAM = 4
local BEAM_BROKEN = 5
local BEAM_HYDRO = 6
local BEAM_SUPPORT = 7

local beamTypesNames = {
  [NORMALTYPE] = "NORMALTYPE",
  [BEAM_ANISOTROPIC] = "BEAM_ANISOTROPIC",
  [BEAM_BOUNDED] = "BEAM_BOUNDED",
  [BEAM_PRESSURED] = "BEAM_PRESSURED",
  [BEAM_LBEAM] = "BEAM_LBEAM",
  [BEAM_BROKEN] = "BEAM_BROKEN",
  [BEAM_HYDRO] = "BEAM_HYDRO",
  [BEAM_SUPPORT] = "BEAM_SUPPORT",
}

local plotLen = 1000
local plotOffset = 0

local showGraphs = im.BoolPtr(true)

local pickedColor = ColorF(1,0,0,1)
local hoveredColor = ColorF(1,0.65,0,1)
local regularColor = ColorF(0.75,1,0,1)

local beamHoveredColor = ColorF(1, 0, 1, 1)

local textColor = ColorF(1,1,1,1)
local textBackgroundColor = ColorI(0,0,0,192)

local STATE_READY = 1
local STATE_PICKING_NODES = 2
local STATE_PICKING_BEAMS = 3

local state = STATE_READY

local nodesAvaliable = nil
local nodeScale = 0
local nodeSelectedRadius = 0

local beamsAvaliable = nil
local beamScale = 0
local beamSelectedRadius = 0

local hitNodes = {}
local hitBeams = {}

local pickedNodes = {}
local pickedBeams = {}

M.nodeDataFromVELua = {}
M.beamDataFromVELua = {}

local function setLinePointFromXnorm(outVec, p0, p1, xnorm)
  outVec:set(p0.x + (p1.x-p0.x) * xnorm, p0.y + (p1.y-p0.y) * xnorm, p0.z + (p1.z-p0.z) * xnorm)
end

local tempVec = vec3()

local function getBeamLength(beamID)
  local beam = vEditor.vdata.beams[beamID]
  tempVec:set(vEditor.vehicleNodesPos[beam.id1])
  tempVec:setSub(vEditor.vehicleNodesPos[beam.id2])

  return tempVec:length()
end

local function getVELuaNodeData(id, varName, luaFunction)
  if not M.nodeDataFromVELua[id] then
    M.nodeDataFromVELua[id] = {}
  end

  M.nodeDataFromVELua[id][varName] = M.nodeDataFromVELua[id][varName] or 0

  local vehCmdString = '"editor_vehicleEditor_veJBeamPicker.nodeDataFromVELua[' .. id .. '].' .. varName .. ' =" .. ' .. luaFunction
  be:queueObjectFastLua(vEditor.vehicle:getID(), "obj:queueGameEngineLua(" .. vehCmdString .. ")")
end

local function getVELuaBeamData(id, varName, luaFunction)
  if not M.beamDataFromVELua[id] then
    M.beamDataFromVELua[id] = {}
  end

  M.beamDataFromVELua[id][varName] = M.beamDataFromVELua[id][varName] or 0

  local vehCmdString = '"editor_vehicleEditor_veJBeamPicker.beamDataFromVELua[' .. id .. '].' .. varName .. ' =" .. ' .. luaFunction
  be:queueObjectFastLua(vEditor.vehicle:getID(), "obj:queueGameEngineLua(" .. vehCmdString .. ")")
end

local nodeDataRendering = {
  {name = "Displacement",     enabled = im.BoolPtr(false),    units = "m",      digitsBeforeDP = 0,   color = rainbowColor(8, 0, 1),   data = function(id) return vEditor.vehicle:getNodePosition(id):length() end, plotData = {}},
  {name = "Speed",            enabled = im.BoolPtr(true),     units = "m/s",    digitsBeforeDP = 0,   color = rainbowColor(8, 1, 1),   data = function(id) return vEditor.vehicle:getNodeVelocity(id):length() end, plotData = {}},
  {name = "Relative Speed",   enabled = im.BoolPtr(false),    units = "m/s",    digitsBeforeDP = 0,   color = rainbowColor(8, 2, 1),   data = function(id) return (vEditor.vehicle:getVelocity() - vEditor.vehicle:getNodeVelocity(id)):length() end, plotData = {}},
  {name = "Force",            enabled = im.BoolPtr(false),    units = "N",      digitsBeforeDP = 0,   color = rainbowColor(8, 3, 1),   data = function(id) getVELuaNodeData(id, "force", "obj:getNodeForceVector(" .. id .. "):length()") return M.nodeDataFromVELua[id].force end, plotData = {}}
}

local beamDataRendering = {
  {name = "Length",           enabled = im.BoolPtr(true),     units = "m",      digitsBeforeDP = 0,   color = rainbowColor(8, 0, 1),   data = function(id) return getBeamLength(id) end, plotData = {}},
  {name = "Speed",            enabled = im.BoolPtr(false),    units = "m/s",    digitsBeforeDP = 0,   color = rainbowColor(8, 1, 1),   data = function(id) getVELuaBeamData(id, "speed", "obj:getBeamVelocity(" .. id .. ")") return M.beamDataFromVELua[id].speed end, plotData = {}},
  {name = "Force",            enabled = im.BoolPtr(false),    units = "N",      digitsBeforeDP = 0,   color = rainbowColor(8, 2, 1),   data = function(id) getVELuaBeamData(id, "force", "obj:getBeamForce(" .. id .. ")") return M.beamDataFromVELua[id].force end, plotData = {}},
  {name = "Stress",           enabled = im.BoolPtr(false),    units = "N",      digitsBeforeDP = 0,   color = rainbowColor(8, 3, 1),   data = function(id) getVELuaBeamData(id, "stress", "(select(1,obj:getBeamStressDamp(" .. id .. ")))") return M.beamDataFromVELua[id].stress end, plotData = {}},
  {name = "Damping",          enabled = im.BoolPtr(false),    units = "N",      digitsBeforeDP = 0,   color = rainbowColor(8, 4, 1),   data = function(id) getVELuaBeamData(id, "damping", "(select(2,obj:getBeamStressDamp(" .. id .. ")))") return M.beamDataFromVELua[id].damping end, plotData = {}},
}

local beamTypesRendering = {}

local function requestDrawnNodesCallback(nodes, scale)
  nodesAvaliable = nodes

  nodeScale = scale
  nodeSelectedRadius = nodeScale * 2
end

local function requestDrawnBeamsCallback(beams, scale)
  beamsAvaliable = beams

  beamScale = scale
  beamSelectedRadius = beamScale * 5
end

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

local pickedNodesCIDs = {}

local function pickNode()
  -- Get nodes drawn in Vehicle Lua bdebug.lua
  be:getPlayerVehicle(0):queueLuaCommand("bdebug.requestDrawnNodesGE('editor_vehicleEditor_veJBeamPicker.requestDrawnNodesCallback')")
  if not nodesAvaliable then return end

  table.clear(hitNodes)
  table.clear(pickedNodesCIDs)

  -- Generate lookup table for pickedNodes index based on node ID
  for k,v in ipairs(pickedNodes) do
    pickedNodesCIDs[v.cid] = k
  end

  local ray = getCameraMouseRay()

  local rayStartPos = ray.pos
  local rayDir = ray.dir

  local leftClicked = im.IsMouseClicked(0)
  local imguiNotHovered = not im.IsAnyItemHovered() and not im.IsWindowHovered(im.HoveredFlags_AnyWindow)

  -- Get list of nodes hovered over by mouse cursor
  for _, i in ipairs(nodesAvaliable) do
    local node = vEditor.vdata.nodes[i]
    local nodeID = node.cid

    local nodePos = vEditor.vehicleNodesPos[nodeID]

    local keyInPickedNodes = pickedNodesCIDs[nodeID] or -1

    -- Only pick nodes if not hovering IMGUI windows
    if imguiNotHovered then
      local dist, _ = intersectsRay_Sphere(rayStartPos, rayDir, nodePos, nodeSelectedRadius)

      if dist and dist < 100 then -- if mouse over node
        table.insert(hitNodes, {node = node, pos = nodePos, keyInPickedNodes = keyInPickedNodes})
      end
    end
  end

  -- Find closest node to camera
  local chosenNodeData = getClosestObjectToCamera(rayStartPos, hitNodes)
  if not chosenNodeData then return end

  -- After choosing closest node, if user left clicked then pick it, otherwise highlight it
  local chosenNodeID = chosenNodeData.node.cid
  local chosenNodeName = chosenNodeData.node.name
  local chosenNodeKeyInPickedNodes = chosenNodeData.keyInPickedNodes

  local chosenNodePos = chosenNodeData.pos

  if leftClicked then -- on left click
    -- Picked node!

    -- If already picked then unpick it, otherwise pick it
    if chosenNodeKeyInPickedNodes ~= -1 then
      table.remove(pickedNodes, chosenNodeKeyInPickedNodes)
    else
      table.insert(pickedNodes, chosenNodeData.node)
    end
  else -- on hover
    -- Highlight node
    debugDrawer:drawSphere(chosenNodePos, nodeSelectedRadius, hoveredColor)
    debugDrawer:drawTextAdvanced(chosenNodePos, chosenNodeName or chosenNodeID, textColor, true, false, textBackgroundColor)
  end
end

local tempBeamCenterPoses = {}
local tempLinePoint1 = vec3()
local tempLinePoint2 = vec3()
local pickedBeamsCIDs = {}

local function pickBeam()
  -- Get beams drawn in Vehicle Lua bdebug.lua
  be:getPlayerVehicle(0):queueLuaCommand("bdebug.requestDrawnBeamsGE('editor_vehicleEditor_veJBeamPicker.requestDrawnBeamsCallback')")
  if not beamsAvaliable then return end

  table.clear(hitBeams)
  table.clear(pickedBeamsCIDs)

  -- Generate lookup table for pickedBeams index based on beam ID
  for k,v in ipairs(pickedBeams) do
    pickedBeamsCIDs[v.cid] = k
  end

  local ray = getCameraMouseRay()

  local rayStartPos = ray.pos
  local rayDir = ray.dir
  local rayEndPos = rayStartPos + rayDir * 100

  local leftClicked = im.IsMouseClicked(0)
  local imguiNotHovered = not im.IsAnyItemHovered() and not im.IsWindowHovered(im.HoveredFlags_AnyWindow)

  -- Get list of beams hoverd over by mouse cursor
  for _, i in ipairs(beamsAvaliable) do
    local beam = vEditor.vdata.beams[i]
    local beamType = beam.beamType or 0

    if beamTypesRendering[beamType][0] then
      local beamID = beam.cid
      local beamPos1 = vEditor.vehicleNodesPos[beam.id1]
      local beamPos2 = vEditor.vehicleNodesPos[beam.id2]

      local keyInPickedBeams = pickedBeamsCIDs[beamID] or -1

      if imguiNotHovered then
        local xnorm1, xnorm2 = closestLinePoints(rayStartPos, rayEndPos, beamPos1, beamPos2)
        if xnorm2 >= 0 and xnorm2 <= 1 then
          setLinePointFromXnorm(tempLinePoint1, rayStartPos, rayEndPos, xnorm1)
          setLinePointFromXnorm(tempLinePoint2, beamPos1, beamPos2, clamp(xnorm2, 0, 1))

          local minSqPointDis = tempLinePoint1:squaredDistance(tempLinePoint2)

          if minSqPointDis < beamSelectedRadius * beamSelectedRadius then
            --local beamCenterPos = (beamPos2 - beamPos1) * 0.5 + beamPos1

            local beamCenterPos = tempBeamCenterPoses[beamID]

            if not tempBeamCenterPoses[beamID] then
              tempBeamCenterPoses[beamID] = vec3()
              beamCenterPos = tempBeamCenterPoses[beamID]
            end

            beamCenterPos:setSub2(beamPos2, beamPos1)
            beamCenterPos:setScaled(0.5)
            beamCenterPos:setAdd(beamPos1)

            table.insert(hitBeams, {beam = beam, pos = beamCenterPos, pos1 = beamPos1, pos2 = beamPos2, keyInPickedBeams = keyInPickedBeams})
          end
        end
      end
    end
  end

  -- Find closest beam to camera
  local chosenBeamData = getClosestObjectToCamera(rayStartPos, hitBeams)
  if not chosenBeamData then return end

  -- After choosing closest beam, if user left clicked then pick it, otherwise highlight it
  local chosenBeamID = chosenBeamData.beam.cid
  local chosenBeamKeyInPickedBeams = chosenBeamData.keyInPickedBeams

  local chosenBeamPos1 = chosenBeamData.pos1
  local chosenBeamPos2 = chosenBeamData.pos2
  local chosenBeamCenterPos = chosenBeamData.pos
  local chosenBeamNode1 = vEditor.vdata.nodes[chosenBeamData.beam.id1]
  local chosenBeamNode2 = vEditor.vdata.nodes[chosenBeamData.beam.id2]

  if leftClicked then -- on left click
    -- Picked beam!

    -- If already picked then unpick it, otherwise pick it
    if chosenBeamKeyInPickedBeams ~= -1 then
      table.remove(pickedBeams, chosenBeamKeyInPickedBeams)
    else
      table.insert(pickedBeams, chosenBeamData.beam)
    end
  else -- on hover
    -- Highlight beam
    --local beamColor = beamColors[chosenBeamData.beam.beamType or 0]
    --local newBeamColor = ColorF(1 - beamColor.r, 1 - beamColor.g, 1 - beamColor.b, beamColor.a)

    local text = string.format("%s - %s (%s)", chosenBeamNode1.name or chosenBeamNode1.cid, chosenBeamNode2.name or chosenBeamNode2.cid, chosenBeamID)

    debugDrawer:drawCylinder(chosenBeamPos1, chosenBeamPos2, beamSelectedRadius, beamHoveredColor)
    --debugDrawer:drawLineInstance(chosenBeamPos1, chosenBeamPos2, beamHoveredRenderSize, beamHoveredColor)
    debugDrawer:drawTextAdvanced(chosenBeamCenterPos, text, textColor, true, false, textBackgroundColor, false, false)
  end
end

local tempBeamCenterPos = vec3()

local function renderPickedJBeamObjs()
  for k, node in pairs(pickedNodes) do
    local nodeID = node.cid
    local nodeName = node.name
    local nodePos = vEditor.vehicleNodesPos[nodeID]

    debugDrawer:drawSphere(nodePos, nodeSelectedRadius, pickedColor, false)
    debugDrawer:drawTextAdvanced(nodePos, "#" .. k .. ": " .. (nodeName or nodeID), textColor, true, false, textBackgroundColor)
  end

  for k, beam in pairs(pickedBeams) do
    local beamID = beam.cid

    local beamNode1 = vEditor.vdata.nodes[beam.id1]
    local beamNode2 = vEditor.vdata.nodes[beam.id2]

    local text = string.format("%s - %s (%s)", beamNode1.name or beamNode1.cid, beamNode2.name or beamNode2.cid, beamID)

    local beam1Pos = vEditor.vehicleNodesPos[beam.id1]
    local beam2Pos = vEditor.vehicleNodesPos[beam.id2]

    tempBeamCenterPos:setSub2(beam2Pos, beam1Pos)
    tempBeamCenterPos:setScaled(0.5)
    tempBeamCenterPos:setAdd(beam1Pos)

    debugDrawer:drawCylinder(beam1Pos, beam2Pos, beamSelectedRadius, pickedColor, false)
    --debugDrawer:drawLineInstance(tempBeamPos1, tempBeamPos2, beamHoveredRenderSize, pickedColor)

    debugDrawer:drawTextAdvanced(tempBeamCenterPos, "#" .. k .. ": " .. text, textColor, true, false, textBackgroundColor)
  end
end

local function renderMenuBar()
  if im.BeginMenuBar() then
    if im.BeginMenu("File") then
      im.EndMenu()
    end
    if im.BeginMenu("View") then
      if im.BeginMenu("Nodes") then
        im.PushItemWidth(175)
        if im.BeginCombo("##nodeDataCombobox", "Set node data to view...", im.ComboFlags_HeightLarge) then
          for _, v in ipairs(nodeDataRendering) do
            if im.Checkbox(v.name .. "##nodeDataRenderingCheckbox", v.enabled) then end
          end
          im.EndCombo()
        end
        im.PopItemWidth()

        im.EndMenu()
      end
      if im.BeginMenu("Beams") then
        im.PushItemWidth(175)
        if im.BeginCombo("##beamDataCombobox", "Set beam data to view...", im.ComboFlags_HeightLarge) then
          for _, v in ipairs(beamDataRendering) do
            if im.Checkbox(v.name .. "##beamDataRenderingCheckbox", v.enabled) then end
          end
          im.EndCombo()
        end

        if im.BeginCombo("##beamTypesCombobox", "Set beam types to pick...", im.ComboFlags_HeightLarge) then
          for k, enabled in pairs(beamTypesRendering) do
            local beamType = beamTypesNames[k]

            if im.Checkbox(beamType .. "##beamTypeRenderingCheckbox", enabled) then end
          end
          im.EndCombo()
        end
        im.PopItemWidth()

        im.EndMenu()
      end
      if im.Checkbox("Show Graphs", showGraphs) then end
      im.EndMenu()
    end
    im.EndMenuBar()
  end
end

local nodeIDToNameList = {}
local pickedNodesCIDs = {}
local pickedBeamsCIDs = {}

local function renderNodeSelectionUI()
  local pickNodesBtnText = state == STATE_PICKING_NODES and "Picking Nodes..." or "Pick Nodes"

  if im.Button(pickNodesBtnText) then
    if state ~= STATE_PICKING_NODES then -- toggle on
      state = STATE_PICKING_NODES

    else -- toggle off
      state = STATE_READY
    end
  end

  im.SameLine()
  im.Text(" or ")
  im.SameLine()

  im.PushItemWidth(75)
  if im.InputText("Add Node by Name", nodeInputTextInput) then
    im.SetKeyboardFocusHere(-1)
  end
  im.PopItemWidth()

  local input = ffi.string(nodeInputTextInput)

  nodeInputTextPopupOpen = input ~= ""

  if nodeInputTextPopupOpen then
    local inputSize = im.GetItemRectSize()

    nodeInputTextPopupSize.x = inputSize.x
    nodeInputTextPopupSize.y = 100

    nodeInputTextPopupPos = im.GetItemRectMin()
    nodeInputTextPopupPos.y = nodeInputTextPopupPos.y + inputSize.y

    -- Generate lookup table for pickedNodes index based on node ID
    table.clear(pickedNodesCIDs)
    for k,v in ipairs(pickedNodes) do
      pickedNodesCIDs[v.cid] = k
    end

    im.PushAllowKeyboardFocus(false)

    -- Show tooltip of suggestions based on user input
    im.SetNextWindowPos(nodeInputTextPopupPos)
    im.SetNextWindowSize(nodeInputTextPopupSize)
    if im.Begin(inputSuggestWndName, nil, inputSuggestWndFlags) then
      for i = 0, tableSizeC(vEditor.vdata.nodes) - 1 do
        local node = vEditor.vdata.nodes[i]
        local nodeName = tostring(node.name or node.cid)

        if string.find(nodeName, input, 1, true) then
          -- on clicking suggestion, add to list!
          if im.Selectable1(nodeName) then
            ffi.copy(nodeInputTextInput, "")

            local keyInPickedNodes = pickedNodesCIDs[node.cid] or -1

            -- Add but don't remove from list!
            if keyInPickedNodes == -1 then
              table.insert(pickedNodes, node)
            end
          end
        end
      end
      im.End()
    end

    im.PopAllowKeyboardFocus()
  end
end

local function renderBeamSelectionUI()
  local pickBeamsBtnText = state == STATE_PICKING_BEAMS and "Picking Beams..." or "Pick Beams"

  if im.Button(pickBeamsBtnText) then
    if state ~= STATE_PICKING_BEAMS then
      state = STATE_PICKING_BEAMS

    else -- toggle off
      state = STATE_READY
    end
  end

  im.SameLine()
  im.Text(" or ")
  im.SameLine()

  im.PushItemWidth(75)
  if im.InputText("Add Beam by Name", beamInputTextInput) then
    im.SetKeyboardFocusHere(-1)
  end
  im.PopItemWidth()

  local input = ffi.string(beamInputTextInput)

  beamInputTextPopupOpen = input ~= ""

  if beamInputTextPopupOpen then
    local inputSize = im.GetItemRectSize()

    beamInputTextPopupSize.x = inputSize.x
    beamInputTextPopupSize.y = 100

    beamInputTextPopupPos = im.GetItemRectMin()
    beamInputTextPopupPos.y = beamInputTextPopupPos.y + inputSize.y

    -- Generate lookup table for node ID to node name
    for i = 0, tableSizeC(vEditor.vdata.nodes) - 1 do
      local node = vEditor.vdata.nodes[i]
      nodeIDToNameList[node.cid] = node.name
    end

    -- Generate lookup table for pickedbeams index based on beam ID
    table.clear(pickedBeamsCIDs)
    for k,v in ipairs(pickedBeams) do
      pickedBeamsCIDs[v.cid] = k
    end

    im.PushAllowKeyboardFocus(false)

    -- Show tooltip of suggestions based on user input
    im.SetNextWindowPos(beamInputTextPopupPos)
    im.SetNextWindowSize(beamInputTextPopupSize)
    if im.Begin(inputSuggestWndName, nil, inputSuggestWndFlags) then
      for i = 0, tableSizeC(vEditor.vdata.beams) - 1 do
        local beam = vEditor.vdata.beams[i]
        local node1ID = beam.id1
        local node2ID = beam.id2

        local node1Name = nodeIDToNameList[node1ID] or node1ID
        local node2Name = nodeIDToNameList[node2ID] or node2ID
        local beamName = node1Name .. " - " .. node2Name .. " (" .. (beam.name or beam.cid) .. ")"

        if string.find(beamName, input, 1, true) then
          -- on clicking suggestion, add to list!
          if im.Selectable1(beamName) then
            ffi.copy(beamInputTextInput, "")

            local keyInPickedbeams = pickedBeamsCIDs[beam.cid] or -1

            -- Add but don't remove from list!
            if keyInPickedbeams == -1 then
              table.insert(pickedBeams, beam)
            end
          end
        end
      end
      im.End()
    end

    im.PopAllowKeyboardFocus()
  end
end

local function renderPickedNodesTree()
  for pickedNodesKey, node in ipairs(pickedNodes) do
    local nodeID = node.cid
    local nodeName = node.name

    if im.Button("X##" .. nodeID .. "_nodeDeleteButton") then -- Remove item
      table.remove(pickedNodes, pickedNodesKey)
    end

    im.SameLine()

    if im.TreeNodeEx1("#" .. pickedNodesKey .. ": " .. (nodeName or nodeID) .. "##" .. nodeID .. "_pickedNodesData") then
      if im.TreeNodeEx1("Static Data##" .. nodeID .. "_pickedNodesData") then
        imguiUtils.addRecursiveTreeTable(node, '')
        im.TreePop()
      end

      if im.TreeNodeEx1("Live Data##" .. nodeID .. "_pickedNodesData") then
        for _, v in ipairs(nodeDataRendering) do
          if v.enabled[0] then
            local name = v.name
            local val = v.data(nodeID)
            local units = v.units

            if not v.plotData[nodeID] then
              v.plotData[nodeID] = ffi.new("float[" .. plotLen .. "]", 0)
            end

            v.plotData[nodeID][plotOffset] = val

            local absVal = math.abs(val)
            local strVal = string.format("%0" .. v.digitsBeforeDP .. ".2f", absVal)
            v.digitsBeforeDP = tostring(#strVal)
            strVal = (val < 0 and " -" or "+") .. strVal

            local avgVal = 0

            for i = 0, plotLen - 1 do
              avgVal = avgVal + v.plotData[nodeID][i]
            end

            avgVal = avgVal / plotLen

            local absAvgVal = math.abs(avgVal)
            local strAvgVal = string.format("%0" .. v.digitsBeforeDP .. ".2f", absAvgVal)
            strAvgVal = (val < 0 and " -" or "+") .. strAvgVal

            im.TextColored(im.ImVec4(v.color[1],v.color[2],v.color[3],v.color[4]), string.format("%s (live / avg) = %s / %s %s", name, strVal, strAvgVal, units))
            --im.Text(string.format("%s = %.2f %s", name, val, units))
            if showGraphs[0] then
              im.PlotLines1(units, v.plotData[nodeID], plotLen, plotOffset + 1 >= plotLen and 0 or plotOffset + 1, name, FLT_MAX, FLT_MAX, im.ImVec2(300, 100))
            end
          end
        end
        im.TreePop()
      end

      im.Spacing()
      im.Spacing()
      im.Spacing()
      im.Spacing()
      im.TreePop()
    end
    im.Separator()

  end
end

local function renderPickedBeamsTree()
  for pickedBeamsKey, beam in ipairs(pickedBeams) do
    local beamID = beam.cid

    local beamNode1 = vEditor.vdata.nodes[beam.id1]
    local beamNode2 = vEditor.vdata.nodes[beam.id2]

    local beamLabel = string.format("%s - %s (%s)", beamNode1.name or beamNode1.cid, beamNode2.name or beamNode2.cid, beamID)

    if im.Button("X##" .. beamID .. "_beamDeleteButton") then -- Remove item
      table.remove(pickedBeams, pickedBeamsKey)
    end

    im.SameLine()

    if im.TreeNodeEx1("#" .. pickedBeamsKey .. ": " .. beamLabel .. "##_pickedBeamsData") then
      if im.TreeNodeEx1("Static Data##" .. beamID .. "_pickedBeamsData") then
        imguiUtils.addRecursiveTreeTable(beam, '')
        im.TreePop()
      end

      if im.TreeNodeEx1("Live Data##" .. beamID .. "_pickedBeamsData") then
        for _, v in ipairs(beamDataRendering) do
          if v.enabled[0] then
            local name = v.name
            local val = v.data(beamID)
            local units = v.units

            if not v.plotData[beamID] then
              v.plotData[beamID] = ffi.new("float[" .. plotLen .. "]", 0)
            end

            v.plotData[beamID][plotOffset] = val

            local absVal = math.abs(val)
            local strVal = string.format("%0" .. v.digitsBeforeDP .. ".2f", absVal)
            v.digitsBeforeDP = tostring(#strVal)
            strVal = (val < 0 and " -" or "+") .. strVal

            local avgVal = 0

            for i = 0, plotLen - 1 do
              avgVal = avgVal + v.plotData[beamID][i]
            end

            avgVal = avgVal / plotLen

            local absAvgVal = math.abs(avgVal)
            local strAvgVal = string.format("%0" .. v.digitsBeforeDP .. ".2f", absAvgVal)
            strAvgVal = (val < 0 and " -" or "+") .. strAvgVal

            im.TextColored(im.ImVec4(v.color[1],v.color[2],v.color[3],v.color[4]), string.format("%s (live / avg) = %s / %s %s", name, strVal, strAvgVal, units))
            --im.Text(string.format("%s = %.2f %s", name, val, units))
            if showGraphs[0] then
              im.PlotLines1(units, v.plotData[beamID], plotLen, plotOffset + 1 >= plotLen and 0 or plotOffset + 1, name, FLT_MAX, FLT_MAX, im.ImVec2(300, 100))
            end
          end
        end
        im.TreePop()
      end

      --im.Text("Length = " .. string.format("%.2f", beamLength) .. " m")

      im.Spacing()
      im.Spacing()
      im.Spacing()
      im.Spacing()
      im.TreePop()
    end
    im.Separator()
  end
end

local function onVehicleEditorRenderJBeams(dtReal, dtSim, dtRaw)
  if not wndOpen or not vEditor.vehicle or not vEditor.vdata then return end

  -- Render picked stuff
  renderPickedJBeamObjs()

  if state == STATE_PICKING_NODES then
    pickNode()
  elseif state == STATE_PICKING_BEAMS then
    pickBeam()
  end
end

local function onEditorGui(dt)
  if editor.beginWindow(wndName, wndName, mainWndFlags) then
    wndOpen = true

    renderMenuBar()
    im.Text("Pick with Node/Beam Debug Modes (Ctrl + M/Ctrl + B)")
    im.Spacing()
    if im.BeginTabBar("##tabs") then
      if im.BeginTabItem("Nodes") then
        im.Spacing()
        renderNodeSelectionUI()
        im.Spacing()
        im.Separator()
        renderPickedNodesTree()

        im.EndTabItem()
      end
      if im.BeginTabItem("Beams") then
        im.Spacing()
        renderBeamSelectionUI()
        im.Spacing()
        im.Separator()
        renderPickedBeamsTree()

        im.EndTabItem()
      end

      im.EndTabBar()
    end

    -- Increment plot offset
    if be:getEnabled() then
      plotOffset = plotOffset + 1 >= plotLen and 0 or plotOffset + 1
    end

  else
    wndOpen = false
  end

  editor.endWindow()
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
  editor.registerWindow(wndName, im.ImVec2(200,200))

  -- Populate beamTypesRendering table
  for k,v in pairs(beamTypesNames) do
    beamTypesRendering[k] = im.BoolPtr(true)
    --table.insert(beamTypesRendering, {name = v, enabled = im.BoolPtr(true)})
  end
end

M.requestDrawnNodesCallback = requestDrawnNodesCallback
M.requestDrawnBeamsCallback = requestDrawnBeamsCallback
M.onVehicleEditorRenderJBeams = onVehicleEditorRenderJBeams
M.onEditorGui = onEditorGui
M.open = open
M.onEditorToolWindowShow = onEditorToolWindowShow
M.onEditorToolWindowHide = onEditorToolWindowHide
M.onEditorInitialized = onEditorInitialized

return M