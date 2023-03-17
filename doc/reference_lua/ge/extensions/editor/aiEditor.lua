-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local actionMapName = "AIEditor"
local editModeName = "Edit AI"
local ffi = require('ffi')
local roadRiverGui = extensions.editor_roadRiverGui
local im = ui_imgui

local upVector = vec3(0, 0, 1)
local downVector = vec3(0, 0, -1)

local colLightGrey = ColorF(0.9, 0.9, 0.9, 0.3)
local linkBaseColor = ColorF(0, 0, 0, 0.7)
local arrowBaseColor = ColorF(0, 0, 0, 1)
local arrowAltColor = ColorF(0.5, 0, 0, 1)
local arrowSize1 = Point2F(0.7, 1)
local arrowSize2 = Point2F(0.7, 0)

local laneColor1 = ColorF(1, 0.2, 0.2, 1)
local laneColor2 = ColorF(0.2, 0.4, 1, 1)
local laneSize = Point2F(1, 0.2)

local linkLineColor = ColorF(0, 1, 0, 1)
local linkLineOffset = vec3(0, 0, 0.5)

local maxMainRenderDistance = 200
local maxTextRenderDistance = 150
local maxConnectionRenderDistance = 100

local camPos
local mapNodes = {}
local navgraphDirty = false
local selectedOnMouseClick
local rotateLastPlacedNodes

local quadtree = require('quadtree')
local qtNodes
local updateQt

local onlySelectedNode
local hoveredNode
local selectedLink
local hoveredLink
local linkToSnapTo
local heldNode

local nodesToLinkTo = {}
local focusPoint
local mouseButtonHeldOnNode = false
local dragMouseStartPos = vec3(0, 0, 0)
local dragStartPosition
local nodeOldPositions = {}
local oldNodeWidth
local tempNodes = {}
local temporaryLink
local tempNodesOldPositions
local addNodeMode
local drawMode = nil
local drawModes = {
  drivability = false,
  type = false,
  speedLimit = false
}

local toolWindowName = 'AIEditor'

local function setDirty()
  navgraphDirty = true
  editor.setDirty()
end

local function isSelected(item)
  if type(item) == "table" then
    -- item is a link
    local nid1Links = editor.selection.aiLink and editor.selection.aiLink[item.nid1]
    return nid1Links and nid1Links[item.nid2]
  else
    -- item is a node
    return editor.selection.aiNode and editor.selection.aiNode[item]
  end
end

-- gets the color depending on the datas drivability, from red to green.
local drivabilityColorCache = {}
local function getDrivabilityColor(data)
  if data.drivability == nil then return colLightGrey end
  if not drivabilityColorCache[data.drivability] then
    local rainbow = rainbowColor(50, clamp(data.drivability,0,1)*15, 1)
    drivabilityColorCache[data.drivability] = ColorF(rainbow[1], rainbow[2], rainbow[3],0.5)
  end
  return drivabilityColorCache[data.drivability]
end

-- gets the color depending on the datas type.
local typeColors = {
  public = ColorF(0, 0, 1, 0.5),
  private = ColorF(1, 0, 0, 0.5)
}
local function getTypeColor(data)
  if data.type == nil then return colLightGrey end
  return typeColors[data.type or 'public']
end

-- gets the color depending on the datas speedLimit, as a gradient from red over green to blue.
local speedLimitCache = {}
local function getSpeedLimitColor(data)
  if not speedLimitCache[data.speedLimit] then
    local rainbow = rainbowColor(50, clamp(data.speedLimit, 0, 36), 1)
    local clr = ColorF(rainbow[1], rainbow[2], rainbow[3],0.5)
    speedLimitCache[data.speedLimit] = clr
  end
  return speedLimitCache[data.speedLimit]
end

-- selects the apropriate color-selecting function for a link.
local drawFunctions = {
  drivability = getDrivabilityColor,
  type = getTypeColor,
  speedLimit = getSpeedLimitColor
}
local function getLinkColor(data)
  if drawMode and drawFunctions[drawMode] then return drawFunctions[drawMode](data) or linkBaseColor end
  return linkBaseColor
end

-- returns the link-text that should be displayed up-close.
local linkTextFunctions = {
  drivability = function(data) if data.drivability == nil then return "-" else return string.format("%g", data.drivability) end end,
  type = function(data) return data.type or "-" end,
  speedLimit = function(data) if data.speedLimit == nil then return "-" else return string.format("%g m/s", data.speedLimit) end end
}

local function getLinkText(data)
  if drawMode then
    return linkTextFunctions[drawMode] and linkTextFunctions[drawMode](data) or "-"
  else
    return ""
  end
end

local distances = {}
local distancesOfLinks = {}

local function getNodeWithSmallestDist(nodes)
  local min = math.huge
  local res
  for nid, _ in pairs(nodes) do
    if distances[nid] < min or not res then
      res = nid
      min = distances[nid]
    end
  end
  return res
end

local function findDistanceFromNode(nid)
  -- using Dijkstra
  -- init
  table.clear(distances)
  table.clear(distancesOfLinks)
  if not nid then return end
  local node = mapNodes[nid]
  local nodesToCheck = deepcopy(mapNodes)

  -- remove all nodes that are too far away
  for otherNid, data in pairs(mapNodes) do
    if data.pos:squaredDistance(node.pos) > square(maxConnectionRenderDistance) then
      -- remove the links
      for otherNid2, _ in pairs(data.links) do
        if nodesToCheck[otherNid2] then
          nodesToCheck[otherNid2].links[otherNid] = nil
        end
      end
      -- remove the node
      nodesToCheck[otherNid] = nil
    else
      distances[otherNid] = math.huge
    end
  end
  distances[nid] = 0

  -- actual algo
  while not tableIsEmpty(nodesToCheck) do
    local nextNid = getNodeWithSmallestDist(nodesToCheck)
    local nextNodeData = nodesToCheck[nextNid]
    nodesToCheck[nextNid] = nil

    for neighbor, otherLinkData in pairs(nextNodeData.links) do
      if nodesToCheck[neighbor] and otherLinkData.inNode == nextNid then
        local distOfPathThroughNextNode = distances[nextNid] + nextNodeData.pos:distance(nodesToCheck[neighbor].pos)
        if distOfPathThroughNextNode < distances[neighbor] then
          distances[neighbor] = distOfPathThroughNextNode
          if not distancesOfLinks[neighbor] then
            distancesOfLinks[neighbor] = {}
          end
          if not distancesOfLinks[nextNid] then
            distancesOfLinks[nextNid] = {}
          end
          distancesOfLinks[neighbor][nextNid] = distOfPathThroughNextNode
          distancesOfLinks[nextNid][neighbor] = distOfPathThroughNextNode
        end
      end
    end
  end

  -- Add distances to the links that are close enough, but not on any shortest route from any node
  for otherNid, data in pairs(mapNodes) do
    if distancesOfLinks[otherNid] then
      for neighbor, linkData in pairs(data.links) do
        if distancesOfLinks[neighbor] and not distancesOfLinks[otherNid][neighbor] then
          local newDist = (distances[otherNid] + distances[neighbor]) / 2 + data.pos:distance(mapNodes[neighbor].pos)
          distancesOfLinks[otherNid][neighbor] = newDist
          distancesOfLinks[neighbor][otherNid] = newDist
        end
      end
    end
  end
end

local function shouldLineBeDrawn(nid1, nid2)
  return distancesOfLinks[nid1] and distancesOfLinks[nid1][nid2] and distancesOfLinks[nid1][nid2] < maxConnectionRenderDistance
end

local function selectNode(id, addToSelection)
  if id == nil then
    if editor.selection then
      editor.selection.aiNode = nil
    end
    table.clear(nodesToLinkTo)
    onlySelectedNode = nil
    findDistanceFromNode(nil)
    return
  end

  if not editor.selection.aiNode then editor.selection.aiNode = {} end
  if editor.keyModifiers.ctrl or addToSelection then
    if editor.selection.aiNode[id] then
      editor.selection.aiNode[id] = nil
      table.remove(nodesToLinkTo, tableFindKey(nodesToLinkTo, id))
    else
      editor.selection.aiNode[id] = true
    end
  else
    editor.selection.aiNode = {}
    table.clear(nodesToLinkTo)
    editor.selection.aiNode[id] = true
  end

  if tableSize(editor.selection.aiNode) == 1 then
    onlySelectedNode = id
    findDistanceFromNode(id)
  else
    onlySelectedNode = nil
    findDistanceFromNode(nil)
  end

  if editor.selection.aiNode[id] then
    table.insert(nodesToLinkTo, id)
  end
  if tableIsEmpty(editor.selection.aiNode) then editor.selection.aiNode = nil end
end

local function selectNodes(ids)
  editor.selection.aiNode = {}
  table.clear(nodesToLinkTo)
  for _, id in ipairs(ids) do
    selectNode(id, true)
  end
end

local function getOnlySelectedLink()
  local result
  for nid1, nodeLinks in pairs(editor.selection.aiLink) do
    for nid2, _ in pairs(nodeLinks) do
      if result then return nil end
      result = {}
      result["nid1"] = nid1
      result["nid2"] = nid2
    end
  end
  return result
end

local function isLinkSelectionEmpty()
  for nid1, nodeLinks in pairs(editor.selection.aiLink) do
    for nid2, _ in pairs(nodeLinks) do
      return false
    end
  end
  return true
end

local function selectLink(link)
  if link == nil then
    if editor.selection then
      editor.selection.aiLink = nil
    end
    selectedLink = nil
    return
  end
  if not editor.selection.aiLink then editor.selection.aiLink = {} end
  if not editor.selection.aiLink[link.nid1] then
    editor.selection.aiLink[link.nid1] = {}
  end
  if editor.keyModifiers.ctrl then
    if editor.selection.aiLink[link.nid1][link.nid2] then
      editor.selection.aiLink[link.nid1][link.nid2] = nil
    else
      editor.selection.aiLink[link.nid1][link.nid2] = true
    end
  else
    editor.selection.aiLink = {}
    editor.selection.aiLink[link.nid1] = {}
    editor.selection.aiLink[link.nid1][link.nid2] = true
  end

  selectedLink = getOnlySelectedLink()
  if isLinkSelectionEmpty() then editor.selection.aiLink = nil end
end

local function changeLinkDirection(link)
  local linkData = mapNodes[link.nid1].links[link.nid2]
  if linkData.inNode == link.nid1 then
    linkData.inNode = link.nid2
  else
    linkData.inNode = link.nid1
  end
end

-- Change Link Direction
local function changeLinkDirectionActionUndo(actionData)
  changeLinkDirection(actionData.link)
end

local changeLinkDirectionActionRedo = changeLinkDirectionActionUndo

local function setLinkField(link, fieldName, value)
  local linkData = mapNodes[link.nid1].links[link.nid2]
  if linkData then
    linkData[fieldName] = value
  end
end

-- Change Link Field
local function changeLinkFieldActionUndo(actionData)
  setLinkField(actionData.link, actionData.fieldName, actionData.oldValue)
end

local function changeLinkFieldActionRedo(actionData)
  setLinkField(actionData.link, actionData.fieldName, actionData.newValue)
end


local function setNodeField(nid, fieldName, value)
  local node = mapNodes[nid]
  if node then
    node[fieldName] = value
  end
end

-- Change Node Field
local function changeNodeFieldActionUndo(actionData)
  for nid, _ in pairs(actionData.nids) do
    setNodeField(nid, actionData.fieldName, actionData.oldValues[nid])
  end
end

local function changeNodeFieldActionRedo(actionData)
  for nid, _ in pairs(actionData.nids) do
    setNodeField(nid, actionData.fieldName, actionData.newValues[nid])
  end
end

local function setNodePosition(nid, position, safeStartPos)
  if safeStartPos then
    dragStartPosition = dragStartPosition or mapNodes[nid].pos
  end
  mapNodes[nid].pos = position
end

local function getConnectedLinks(nids)
  local result = {}
  for nid, _ in pairs(nids) do
    result[nid] = mapNodes[nid].links
  end
  return result
end

local function areNodesConnected(nid1, nid2)
  return mapNodes[nid1].links[nid2] or mapNodes[nid2].links[nid1]
end

local function getNewNodeName(prefix, idx)
  local nodeName = prefix..idx
  if mapNodes[nodeName] then
    nodeName = nodeName.."_"
    local postfix = 1
    while mapNodes[nodeName..postfix] do
      postfix = postfix + 1
    end
    nodeName = nodeName..postfix
  end
  return nodeName
end

-- TODO
local function addNode(pos, radius, nid)
  nid = nid or getNewNodeName("manual", "")
  mapNodes[nid] = {pos = vec3(pos), radius = radius, normal = map.surfaceNormal(pos, radius * 0.5), links = {}}
  updateQt = true
  return nid
end

local function addLink(nid1, nid2, drivability, speedLimit)
  if not nid1 or not nid2 then return end
  drivability = drivability or 1
  speedLimit = speedLimit or 50
  local linkInfo = {inNode = nid1, drivability = drivability, speedLimit = speedLimit}
  mapNodes[nid2].links[nid1] = linkInfo
  mapNodes[nid1].links[nid2] = linkInfo
  updateQt = true
end

local function deleteLink(nid1, nid2)
  mapNodes[nid2].links[nid1] = nil
  mapNodes[nid1].links[nid2] = nil
  updateQt = true
end

-- TODO
local function deleteNode(nid)
  local nids = {}
  nids[nid] = true
  for nid1, links in pairs(getConnectedLinks(nids)) do
    for nid2, link in pairs(links) do
      deleteLink(nid1, nid2)
    end
  end
  mapNodes[nid] = nil

  updateQt = true
end

-- Add Node
local function addNodeLinkActionUndo(actionData)
  if actionData.linkInfos then
    for nid1, links in pairs(actionData.linkInfos) do
      for nid2, linkInfo in pairs(links) do
        deleteLink(nid1, nid2)
      end
    end
  end
  if actionData.nodeInfos then
    for _, nodeInfo in ipairs(actionData.nodeInfos) do
      deleteNode(nodeInfo.nid)
    end
  end

  selectLink(nil)
  selectNode(nil)
  updateQt = true
end

local function addNodeLinkActionRedo(actionData)
  if actionData.nodeInfos then
    for _, nodeInfo in ipairs(actionData.nodeInfos) do
      addNode(nodeInfo.pos, nodeInfo.radius, nodeInfo.nid)
      mapNodes[nodeInfo.nid].links = nodeInfo.links
    end
  end

  if actionData.linkInfos then
    for nid1, links in pairs(actionData.linkInfos) do
      for nid2, linkInfo in pairs(links) do
        mapNodes[nid1].links[nid2] = linkInfo
        mapNodes[nid2].links[nid1] = linkInfo
      end
    end
  end
  updateQt = true
end

-- Delete Node
local deleteNodeLinkActionUndo = addNodeLinkActionRedo
local deleteNodeLinkActionRedo = addNodeLinkActionUndo

-- returns the displacement value of the lane (negative = left, positive = right)
local function getLaneOffset(nid1, nid2, width, lane, laneCount)
  local link = mapNodes[nid1].links[nid2] or mapNodes[nid2].links[nid1]
  if link.inNode == nid2 then
    nid1, nid2 = nid2, nid1
  end

  return (lane - laneCount / 2 - 0.5) * (width / laneCount)
end

local function drawNode(nid, n)
  local color
  if hoveredNode == nid then
    color = roadRiverGui.highlightColors.hoveredNode
  elseif editor.selection.aiNode and editor.selection.aiNode[nid] then
    color = roadRiverGui.highlightColors.selectedNode
  elseif distances[nid] and distances[nid] < maxConnectionRenderDistance then
    color = linkLineColor
  else
    color = roadRiverGui.highlightColors.nodeTransparent
  end
  debugDrawer:drawSphere(n.pos, n.radius, color)

  local camNodeSqDist = camPos:squaredDistance(n.pos)
  if camNodeSqDist < square(maxTextRenderDistance) then
    debugDrawer:drawText(n.pos, String(tostring(nid)), linkBaseColor)
  end

  -- draw edges
  for lid, data in pairs(n.links) do
    if mapNodes[lid] and data.inNode == nid then
      local lidPos = mapNodes[lid].pos

      local linkColor = getLinkColor(data)
      if hoveredLink and hoveredLink.nid1 == nid and hoveredLink.nid2 == lid then
        linkColor = roadRiverGui.highlightColors.hoveredNode
      end
      if editor.selection.aiLink and editor.selection.aiLink[nid] and editor.selection.aiLink[nid][lid] then
        linkColor = roadRiverGui.highlightColors.selectedNode
      end
      debugDrawer:drawSquarePrism(n.pos, lidPos, Point2F(0.6, n.radius*2), Point2F(0.6, mapNodes[lid].radius*2), linkColor)
      if shouldLineBeDrawn(nid, lid) then
        debugDrawer:drawCylinder(n.pos + linkLineOffset, lidPos + linkLineOffset, 0.3, linkLineColor)
      end
      local inNodePos = mapNodes[data.inNode].pos
      local edgeDirVec = mapNodes[data.inNode ~= lid and lid or nid].pos - inNodePos
      local edgeLength = edgeDirVec:length()
      edgeDirVec:normalize()

      if data.lanes then
        local laneCount = string.len(data.lanes) / 2
        local right1 = edgeDirVec:cross(n.normal)
        local right2 = edgeDirVec:cross(mapNodes[lid].normal)

        for i = 1, laneCount do -- draw lanes
          local offset1 = getLaneOffset(nid, lid, n.radius * 2, i, laneCount)
          local offset2 = getLaneOffset(nid, lid, mapNodes[lid].radius * 2, i, laneCount)
          color = string.sub(data.lanes, i * 2 - 1, i * 2 - 1) == "-" and laneColor1 or laneColor2
          debugDrawer:drawSquarePrism(n.pos + right1 * offset1, lidPos + right2 * offset2, laneSize, laneSize, color)
        end
      end

      if data.oneWay then
        local edgeProgress = 0.5
        while edgeProgress <= edgeLength do
          color = getCameraForward():dot(edgeDirVec) >= 0 and arrowBaseColor or arrowAltColor
          debugDrawer:drawSquarePrism((inNodePos + edgeProgress * edgeDirVec), (inNodePos + (edgeProgress + 2) * edgeDirVec), arrowSize1, arrowSize2, color)
          edgeProgress = edgeProgress + 15
        end
      end
    end
  end
end

local function staticRayCast()
  if core_forest.getForestObject() then core_forest.getForestObject():disableCollision() end
  local rayCast = cameraMouseRayCast()
  if core_forest.getForestObject() then core_forest.getForestObject():enableCollision() end

  return rayCast
end

local function importDecalroads()
  selectNode(nil)
  selectLink(nil)
  mapNodes = deepcopy(map.getMap().nodes)
  for nid1, node in pairs(mapNodes) do
    for nid2, link in pairs(node.links) do
      mapNodes[nid2].links[nid1] = link
    end
  end
  updateQt = true
end

local function applyMapNodes()
  editor.saveLevel()
  local mapNodesCopy = deepcopy(mapNodes)
  for nid1, node in pairs(mapNodes) do
    for nid2, link in pairs(node.links) do
      -- TODO set oneWay to true. This should go away in the future because lanes are always one way
      mapNodesCopy[nid1].links[nid2].oneWay = true
    end
  end
  map.reset(mapNodesCopy)
end

local multiLane = im.BoolPtr(false)
local leftLanes = im.IntPtr(1)
local rightLanes = im.IntPtr(1)
local laneGap = im.FloatPtr(0)
local multiLaneVerticalOffset = vec3(0, 0, 3)

local function rotateNodes(nodes, useFocusPoint)
  local tempNodeLinkedNode = next(mapNodes[tempNodes[1]].links)
  local roadVec = mapNodes[tempNodes[1]].pos - (tempNodeLinkedNode and mapNodes[tempNodeLinkedNode].pos or vec3(0, 1, 0))
  local roadPerpendicularVec = roadVec:cross(upVector):normalized()

  local nodeCounter = 2
  local center = useFocusPoint and focusPoint or mapNodes[nodes[1]].pos

  for i=1, leftLanes[0] do
    local nodePos = center - roadPerpendicularVec * ((i * 2 * mapNodes[nodes[1]].radius) + laneGap[0]) + multiLaneVerticalOffset
    local rayCastDist = castRayStatic(nodePos, downVector, 10, true)
    setNodePosition(nodes[nodeCounter], nodePos - vec3(0, 0, rayCastDist))
    nodeCounter = nodeCounter + 1
  end

  for i=1, rightLanes[0] do
    local nodePos = center + roadPerpendicularVec * ((i * 2 * mapNodes[nodes[1]].radius) + laneGap[0]) + multiLaneVerticalOffset
    local rayCastDist = castRayStatic(nodePos, downVector, 10, true)
    setNodePosition(nodes[nodeCounter], nodePos - vec3(0, 0, rayCastDist))
    nodeCounter = nodeCounter + 1
  end
end

local function onEditorGui()
  local editModeOpen = (editor.editMode and (editor.editMode.displayName == editModeName))
  if editModeOpen then
    if editor.beginWindow(toolWindowName, "AI Mode") then
      if im.Button("Import all decal roads") then
        importDecalroads()
        setDirty()
      end
      if im.Button("Apply changes to navgraph (We should do this on saving in the end)") then
        applyMapNodes()
      end

      im.Checkbox("Create additional lanes", multiLane)

      if not multiLane[0] then
        im.BeginDisabled()
      end
      editor.uiInputInt("Number of left lanes", leftLanes, 1, 2, nil)
      editor.uiInputInt("Number of right lanes", rightLanes, 1, 2, nil)
      editor.uiInputFloat("Gap between lanes", laneGap, 0.1, 0.5, "%0.1f")
      if not multiLane[0] then
        im.EndDisabled()
      end

      --im.Checkbox("Draw lines", multiLane)
    end
    editor.endWindow()
  end

  if editModeOpen or drawMode then
    if not qtNodes or updateQt then
      qtNodes = quadtree.newQuadtree()
      if mapNodes then
        for nid, n in pairs(mapNodes) do
          local nPos = n.pos
          local radius = n.radius
          qtNodes:preLoad(nid, quadtree.pointBBox(nPos.x, nPos.y, radius))
        end
      end
      qtNodes:build()
      updateQt = false
    end
    camPos = getCameraPosition()
  end

  if editModeOpen then
    local rayCast = staticRayCast()
    focusPoint = rayCast and rayCast.pos

    -- TODO: undo/redo history

    -- Get hovered node
    hoveredNode = nil
    hoveredLink = nil
    if rayCast and not (im.IsAnyItemHovered() or im.IsWindowHovered(im.HoveredFlags_AnyWindow)) then
      local minHitDist = rayCast.distance
      local ray = getCameraMouseRay()
      local rayDir = ray.dir
      for nid in qtNodes:query(quadtree.pointBBox(camPos.x, camPos.y, 200)) do
        local node = mapNodes[nid]
        if not tableContains(tempNodes, nid) then
          local minSphereHitDist, _ = intersectsRay_Sphere(ray.pos, rayDir, node.pos, node.radius)
          if minSphereHitDist and minSphereHitDist < minHitDist then
            hoveredNode = nid
            hoveredLink = nil
            minHitDist = minSphereHitDist
          end
        end

        for otherNid, link in pairs(node.links) do
          if link.inNode == nid then
            local linkDir = mapNodes[otherNid].pos - node.pos
            local perpendicularDir = linkDir:normalized():cross(upVector)
            local p1 = node.pos + perpendicularDir * node.radius + vec3(0, 0, 0.5)
            local p2 = node.pos + -perpendicularDir * node.radius + vec3(0, 0, 0.5)
            local p3 = mapNodes[otherNid].pos + -perpendicularDir * mapNodes[otherNid].radius + vec3(0, 0, 0.5)
            local p4 = mapNodes[otherNid].pos + perpendicularDir * mapNodes[otherNid].radius + vec3(0, 0, 0.5)
            local hitDist1 = intersectsRay_Triangle(camPos, rayDir, p1, p2, p3)
            local hitDist2 = intersectsRay_Triangle(camPos, rayDir, p1, p3, p4)
            local hitDist = math.min(hitDist1, hitDist2)
            if hitDist < minHitDist then
              minHitDist = hitDist
              hoveredLink = {}
              hoveredLink["nid1"] = nid
              hoveredLink["nid2"] = otherNid
              hoveredNode = nil
            end
          end
        end
      end
    end

    if focusPoint then
      -- Hovers on the map
      if editor.keyModifiers.alt then
        addNodeMode = true

        if not hoveredNode and not tempNodes[1] then
          if temporaryLink then
            deleteLink(temporaryLink.nid1, temporaryLink.nid2)
            temporaryLink = nil
          end

          -- Add Node
          table.insert(tempNodes, addNode(focusPoint, onlySelectedNode and mapNodes[onlySelectedNode].radius or 1))
          addLink(nodesToLinkTo[#tempNodes], tempNodes[#tempNodes])
          if multiLane[0] then
            for i = 1, leftLanes[0] do
              table.insert(tempNodes, addNode(focusPoint, onlySelectedNode and mapNodes[onlySelectedNode].radius or 1))
              addLink(tempNodes[#tempNodes], nodesToLinkTo[#tempNodes])
            end
            for i = 1, rightLanes[0] do
              table.insert(tempNodes, addNode(focusPoint, onlySelectedNode and mapNodes[onlySelectedNode].radius or 1))
              addLink(nodesToLinkTo[#tempNodes], tempNodes[#tempNodes])
            end
          end
        end

        if not mouseButtonHeldOnNode then
          if hoveredNode then
            -- delete the temp node
            if not tableIsEmpty(tempNodes) then
              for _, id in ipairs(tempNodes) do
                deleteNode(id)
              end
              table.clear(tempNodes)
            end

            -- add a link to the hovered node
            if onlySelectedNode and not temporaryLink and not areNodesConnected(hoveredNode, onlySelectedNode) then
              addLink(onlySelectedNode, hoveredNode)
              temporaryLink = {nid1 = onlySelectedNode, nid2 = hoveredNode}
            end

          elseif hoveredLink and selectedLink and hoveredLink.nid1 == selectedLink.nid1 and hoveredLink.nid2 == selectedLink.nid2 then
            -- snap the temp node to the hovered link
            local n1 = mapNodes[hoveredLink.nid1]
            local n2 = mapNodes[hoveredLink.nid2]
            local linkVec = n2.pos - n1.pos
            local tempVec = focusPoint - n1.pos
            local dotProduct = linkVec:dot(tempVec)
            linkToSnapTo = selectedLink
            setNodePosition(tempNodes[1], n1.pos + (linkVec:normalized() * dotProduct / linkVec:length()))
            mapNodes[tempNodes[1]].radius = (n1.radius + n2.radius) / 2
          elseif tempNodes[1] then
            setNodePosition(tempNodes[1], focusPoint)
            mapNodes[tempNodes[1]].radius = (onlySelectedNode and mapNodes[onlySelectedNode].radius) or 1

            if multiLane[0] then
              -- set the positions of the other temp nodes
              if rotateLastPlacedNodes then
                -- Rotate the last placed nodes correctly
                rotateNodes(rotateLastPlacedNodes, false)
              end

              -- Rotate the temp nodes
              rotateNodes(tempNodes, true)
            end
          end
        end
      end

      -- Mouse click on map
      if im.IsMouseClicked(0) and not (im.IsAnyItemHovered() or im.IsWindowHovered(im.HoveredFlags_AnyWindow)) then
        if editor.keyModifiers.alt then
          -- Clicked while in create mode
          if addNodeMode and focusPoint then
            mouseButtonHeldOnNode = true
            if tempNodes[1] then
              oldNodeWidth = mapNodes[tempNodes[1]].radius
            end
          end
        end
      end

      -- User let go of alt
      if addNodeMode and not editor.keyModifiers.alt then
        if temporaryLink then
          deleteLink(temporaryLink.nid1, temporaryLink.nid2)
          temporaryLink = nil
        end
        if not tableIsEmpty(tempNodes) then
          if rotateLastPlacedNodes and tempNodesOldPositions then
            -- Reset multilane rotation when letting go of alt
            for i, node in ipairs(rotateLastPlacedNodes) do
              setNodePosition(node, tempNodesOldPositions[i])
            end
          end

          for _, id in ipairs(tempNodes) do
            deleteNode(id)
          end
          table.clear(tempNodes)
        end
        addNodeMode = false
        mouseButtonHeldOnNode = false
        rotateLastPlacedNodes = nil
        tempNodesOldPositions = nil
      end
    end

    -- Handle mouse click
    if im.IsMouseClicked(0) and not (im.IsAnyItemHovered() or im.IsWindowHovered(im.HoveredFlags_AnyWindow)) then
      dragMouseStartPos = vec3(im.GetMousePos().x, im.GetMousePos().y, 0)
      if not editor.keyModifiers.alt then
        if not (hoveredLink and isSelected(hoveredLink)) then
          selectLink(hoveredLink)
          if hoveredLink then
            selectedOnMouseClick = true
          end
        end
        if not (hoveredNode and isSelected(hoveredNode)) then
          selectNode(hoveredNode)
          if hoveredNode then
            selectedOnMouseClick = true
          end
        end
        heldNode = hoveredNode
        if hoveredNode then
          mouseButtonHeldOnNode = true
          if not tableIsEmpty(editor.selection.aiNode) then
            for nodeId, _ in pairs(editor.selection.aiNode) do
              nodeOldPositions[nodeId] = mapNodes[nodeId].pos
            end
          end
        end
      end
    end

    if im.IsMouseReleased(0) then

      -- User released LMB after holding it down on a node
      if mouseButtonHeldOnNode then
        if editor.keyModifiers.alt then
          -- Place new node permanently
          addNodeMode = false

          if tempNodes[1] then
            -- Undo action for placed node
            if linkToSnapTo then
              -- Snap node to an existing link
              if mapNodes[linkToSnapTo.nid1].links[linkToSnapTo.nid2].inNode == linkToSnapTo.nid1 then
                addLink(linkToSnapTo.nid1, tempNodes[1])
                addLink(tempNodes[1], linkToSnapTo.nid2)
              else
                addLink(linkToSnapTo.nid2, tempNodes[1])
                addLink(tempNodes[1], linkToSnapTo.nid1)
              end
              selectLink(nil)
              editor.history:beginTransaction("InsertAINode")
              local linkInfos = {}
              linkInfos[linkToSnapTo.nid1] = {}
              linkInfos[linkToSnapTo.nid1][linkToSnapTo.nid2] = mapNodes[linkToSnapTo.nid1].links[linkToSnapTo.nid2]
              editor.history:commitAction("DeleteAILink", {linkInfos = linkInfos}, deleteNodeLinkActionUndo, deleteNodeLinkActionRedo)
            end

            -- Add the new node
            local nodeIds = {}
            local nodeInfos = {}
            local oldPositions = {}
            for i, nodeId in ipairs(tempNodes) do
              table.insert(nodeInfos, {nid = nodeId, pos = vec3(mapNodes[nodeId].pos), radius = mapNodes[nodeId].radius, links = deepcopy(mapNodes[nodeId].links)})
              nodeIds[nodeId] = true
              oldPositions[i] = vec3(mapNodes[nodeId].pos)
            end

            if not linkToSnapTo then
              -- Create a history action for resetting the node positions
              if rotateLastPlacedNodes then
                editor.history:beginTransaction("AddAINode")
                local oldValues = {}
                local newValues = {}
                for i, node in ipairs(rotateLastPlacedNodes) do
                  oldValues[node] = vec3(tempNodesOldPositions[i])
                  newValues[node] = vec3(mapNodes[node].pos)
                end
                editor.history:commitAction("MoveOldAINodes", {nids = deepcopy(oldValues), fieldName = "pos", oldValues = deepcopy(oldValues), newValues = newValues}, changeNodeFieldActionUndo, changeNodeFieldActionRedo, true)
              end
            end

            editor.history:commitAction("AddAINode", {nodeInfos = nodeInfos, linkInfos = deepcopy(getConnectedLinks(nodeIds))}, addNodeLinkActionUndo, addNodeLinkActionRedo, true)

            if not linkToSnapTo then
              if rotateLastPlacedNodes then
                editor.history:endTransaction()
              end
            end
            if tableIsEmpty(mapNodes[tempNodes[1]].links) then
              rotateLastPlacedNodes = deepcopy(tempNodes)
              tempNodesOldPositions = oldPositions
            else
              rotateLastPlacedNodes = nil
              tempNodesOldPositions = nil
            end

            if linkToSnapTo then
              editor.history:endTransaction()
              deleteLink(linkToSnapTo.nid1, linkToSnapTo.nid2)
              linkToSnapTo = nil
            end
            selectNodes(tempNodes)
          elseif temporaryLink then
            -- Add only a new link
            local linkInfos = {}
            linkInfos[temporaryLink.nid1] = {}
            linkInfos[temporaryLink.nid1][temporaryLink.nid2] = mapNodes[temporaryLink.nid1].links[temporaryLink.nid2]
            editor.history:commitAction("AddAILink", {linkInfos = linkInfos}, addNodeLinkActionUndo, addNodeLinkActionRedo, true)
            selectNode(hoveredNode)
          end
          setDirty()

          --editor.setPreference("aiEditor.general.defaultRadius", nodeInfo.radius)
          table.clear(tempNodes)
          temporaryLink = nil
        elseif (not dragMouseStartPos) and not tableIsEmpty(editor.selection.aiNode) then
          local newValues = {}
          for nid, _ in pairs(editor.selection.aiNode) do
            newValues[nid] = vec3(mapNodes[nid].pos)
          end
          editor.history:commitAction("PositionAINode", {nids = deepcopy(editor.selection.aiNode), fieldName = "pos", oldValues = deepcopy(nodeOldPositions), newValues = newValues}, changeNodeFieldActionUndo, changeNodeFieldActionRedo, true)
          setDirty()
        elseif not selectedOnMouseClick then
          if hoveredNode then
            selectNode(hoveredNode)
          elseif hoveredLink then
            selectLink(hoveredLink)
          end
        end

        mouseButtonHeldOnNode = false
        dragMouseStartPos = nil
        dragStartPosition = nil
      end
      selectedOnMouseClick = false
    end

    -- The mouse button is down
    if mouseButtonHeldOnNode and im.IsMouseDown(0) then
      local cursorPosImVec = im.GetMousePos()
      local cursorPos = vec3(cursorPosImVec.x, cursorPosImVec.y, 0)

      -- Set the width of the node by dragging
      if editor.keyModifiers.alt then
        if tempNodes[1] and editor.getPreference('aiEditor.general.dragWidth') then
          local width = math.max(oldNodeWidth + (cursorPos.x - dragMouseStartPos.x) / 10.0, 0)
          mapNodes[tempNodes[1]].radius = width
        end

      -- Put the grabbed node on the position of the cursor
      else
        if tableIsEmpty(editor.selection.aiNode) then
          mouseButtonHeldOnNode = false
          dragMouseStartPos = nil
          dragStartPosition = nil
        elseif dragMouseStartPos and (dragMouseStartPos - cursorPos):length() <= 5 then
          -- Snap the node to the old position, if it is close enough
          --setNodePosition(onlySelectedNode, nodeOldPositions, true)
        else
          if focusPoint then
            -- Move all nodes by the offset and project them to the ground
            local nodeOffset = focusPoint - nodeOldPositions[heldNode]
            if core_forest.getForestObject() then core_forest.getForestObject():disableCollision() end
            for nodeId, _ in pairs(editor.selection.aiNode) do
              local rayDist = castRayStatic(nodeOldPositions[nodeId] + nodeOffset + upVector, downVector, 10)
              local newPos = nodeOldPositions[nodeId] + nodeOffset + vec3(0, 0, 1 - math.min(rayDist, 10))
              setNodePosition(nodeId, newPos, true)
            end
            if core_forest.getForestObject() then core_forest.getForestObject():enableCollision() end
          end
          dragMouseStartPos = nil
        end
      end
    end
  end

  if editModeOpen or drawMode then
    if not editModeOpen and tableIsEmpty(mapNodes) then
      -- import the decal roads when the edit mode is not open
      importDecalroads()
    end
    -- Draw nodes
    if qtNodes then
      for nid in qtNodes:query(quadtree.pointBBox(camPos.x, camPos.y, maxMainRenderDistance)) do
        local node = mapNodes[nid]
        if node then
          drawNode(nid, node)
        end
      end
    end
  end
end

local function onActivate()
  editor.clearObjectSelection()
  --editor.hideAllSceneTreeInstances()
  editor.showWindow(toolWindowName)
end

local function onDeactivate()
  --editor.showAllSceneTreeInstances()
  editor.hideWindow(toolWindowName)
end

-- These methods are for the action map to call
local function copySettingsAM()
end

local function cycleHoveredRoadsAM(value)
end

local function onDuplicate()
  if not editor.isViewportFocused() then return end
end

local function onEditorObjectSelectionChanged()
  if not editor.editMode or (editor.editMode.displayName ~= editModeName) then
    return
  end
end

local function aiNodeInspectorGui(inspectorInfo)
  if onlySelectedNode then
    local nid = next(editor.selection.aiNode)
    local node = mapNodes[nid]
    local editEnded = im.BoolPtr(false)

    -- name
    im.Text("Node: " .. nid)

    -- position
    if node.pos then
      local posArray = im.ArrayFloat(3)
      posArray[0] = im.Float(node.pos.x)
      posArray[1] = im.Float(node.pos.y)
      posArray[2] = im.Float(node.pos.z)
      editor.uiInputFloat3("Position", posArray, nil, nil, editEnded)
      if editEnded[0] then
        local oldValues = {}
        local newValues = {}
        oldValues[nid] = node.pos
        newValues[nid] = vec3(posArray[0], posArray[1], posArray[2])
        editor.history:commitAction("PositionAINode", {nids = deepcopy(editor.selection.aiNode), fieldName = "pos", oldValues = oldValues, newValues = newValues}, changeNodeFieldActionUndo, changeNodeFieldActionRedo)
      end
    end

    -- radius
    local radPtr = im.FloatPtr(node.radius)
    editor.uiInputFloat("Radius", radPtr, 0.1, 0.5, nil, nil, editEnded)
    if editEnded[0] then
      local oldValues = {}
      local newValues = {}
      oldValues[nid] = node.radius
      newValues[nid] = radPtr[0]
      editor.history:commitAction("ChangeAINodeRadius", {nids = deepcopy(editor.selection.aiNode), fieldName = "radius", oldValues = oldValues, newValues = newValues}, changeNodeFieldActionUndo, changeNodeFieldActionRedo)
    end
  end
end

local function aiLinkInspectorGui(inspectorInfo)
  if selectedLink then
    local linkData = mapNodes[selectedLink.nid1].links[selectedLink.nid2]
    local editEnded = im.BoolPtr(false)

    -- drivability
    local drivabilityPtr = im.FloatPtr(linkData.drivability)
    editor.uiInputFloat("Drivability", drivabilityPtr, 0.1, 0.5, nil, nil, editEnded)
    if editEnded[0] then
      editor.history:commitAction("ChangeAILinkDrivability", {link = selectedLink, fieldName = "drivability", oldValue = linkData.drivability, newValue = drivabilityPtr[0]}, changeLinkFieldActionUndo, changeLinkFieldActionRedo)
    end

    -- speed limit
    local speedLimitPtr = im.FloatPtr(linkData.speedLimit)
    editor.uiInputFloat("Speed Limit", speedLimitPtr, 0.1, 0.5, nil, nil, editEnded)
    if editEnded[0] then
      editor.history:commitAction("ChangeAILinkSpeedLimit", {link = selectedLink, fieldName = "speedLimit", oldValue = linkData.speedLimit, newValue = speedLimitPtr[0]}, changeLinkFieldActionUndo, changeLinkFieldActionRedo)
    end

    -- direction
    if im.Button("Change Direction") then
      editor.history:commitAction("ChangeAILinkDirection", {link = selectedLink}, changeLinkDirectionActionUndo, changeLinkDirectionActionRedo)
    end
  end
end

--local function onWindowMenuItem()
--  editor.selectEditMode(editor.editModes[editModeName])
--end

local function onDeleteSelection()
  if editor.selection.aiNode and not tableIsEmpty(editor.selection.aiNode) then
    local nodeInfos = {}
    for nid, _ in pairs(editor.selection.aiNode) do
      local nodeInfo = {nid = nid, pos = vec3(mapNodes[nid].pos), radius = mapNodes[nid].radius, links = deepcopy(mapNodes[nid].links)}
      table.insert(nodeInfos, nodeInfo)
    end

    local nids = editor.selection.aiNode
    editor.history:commitAction("DeleteAINodes", {nodeInfos = nodeInfos, linkInfos = deepcopy(getConnectedLinks(nids))}, deleteNodeLinkActionUndo, deleteNodeLinkActionRedo)
  elseif editor.selection.aiLink and not isLinkSelectionEmpty() then
    local linkInfos = {}
    for nid1, nodeLinks in pairs(editor.selection.aiLink) do
      for nid2, _ in pairs(nodeLinks) do
        if not linkInfos[nid1] then linkInfos[nid1] = {} end
        linkInfos[nid1][nid2] = mapNodes[nid1].links[nid2]
      end
    end
    editor.history:commitAction("DeleteAILinks", {linkInfos = linkInfos}, deleteNodeLinkActionUndo, deleteNodeLinkActionRedo)
  end
end

local function loadMapNodes()
  log('I','',"Trying to load navgraph from file navgraph.json")
  local levelDir = path.split(getMissionFilename())
  if not levelDir then return end
  local loadedNavgraph = jsonReadFile(levelDir .. "navgraph.json")
  if loadedNavgraph then
    mapNodes = loadedNavgraph
    for nid1, node in pairs(mapNodes) do
      for nid2, link in pairs(node.links) do
        mapNodes[nid2].links[nid1] = link
      end
      node.pos = vec3(node.pos)
      node.normal = vec3(node.normal)
    end

    log('I','',"Loaded navgraph from file")
    selectLink(nil)
    selectNode(nil)
  end
end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(600, 200))
  editor.editModes[editModeName] =
  {
    displayName = editModeName,
    onUpdate = updateEdit,
    onActivate = onActivate,
    onDeactivate = onDeactivate,
    onDeleteSelection = onDeleteSelection,
    actionMap = actionMapName,
    onCopy = copySettingsAM,
    onPaste = pasteFieldsAM,
    onDuplicate = onDuplicate,
    iconTooltip = "AI Editor",
    auxShortcuts = {},
    hideObjectIcons = true
  }

  --editor.editModes[editModeName].icon = editor.icons.directions_bike

  editor.registerInspectorTypeHandler("aiNode", aiNodeInspectorGui)
  editor.registerInspectorTypeHandler("aiLink", aiLinkInspectorGui)

  loadMapNodes()
end

local function onEditorRegisterPreferences(prefsRegistry)
  --[[prefsRegistry:registerCategory("aiEditor")
  prefsRegistry:registerSubCategory("aiEditor", "general", nil,
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {dragWidth = {"bool", false, "Drag Width", nil, nil, nil, false}}
  })]]
end

local function onEditorPreferenceValueChanged(path, value)

end

local function onNavgraphReloaded()
  qtNodes = nil
  mapNodes = {}
  loadMapNodes()
end

local function computeDrawMode()
  drawMode = nil
  for k, v in pairs(drawModes) do
    if v then drawMode = k end
  end
end

local function enableDrawMode(mode, enabled)
  if drawModes[mode] == nil then log('E','',"Drawmode " .. dumps(mode) .. " does not exist for aiEditor!") return end
  -- disable all other drawmodes
  if enabled then
    for k, v in pairs(drawModes) do
      drawModes[k] = false
    end
  end
  drawModes[mode] = enabled
  computeDrawMode()
end

local function getDrawMode()
  return drawMode
end

local function onEditorAfterSaveLevel()
  if navgraphDirty then
    local mapNodesCopy = deepcopy(mapNodes)
    for nid1, node in pairs(mapNodes) do
      for nid2, link in pairs(node.links) do
        if link.inNode ~= nid1 then
          mapNodesCopy[nid1].links[nid2] = nil
        end
      end
      mapNodesCopy[nid1].pos = node.pos:toDict()
      mapNodesCopy[nid1].normal = node.normal:toDict()
    end

    local levelDir = path.split(getMissionFilename())
    jsonWriteFile(levelDir .. "navgraph.json", mapNodesCopy, true)
    navgraphDirty = false
  end
end

local function onSerialize()
  local data = {
    navgraphDirty = navgraphDirty
  }
  return data
end

local function onDeserialized(data)
  if data then
    navgraphDirty = data.navgraphDirty
  end
end

M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized
M.onEditorObjectSelectionChanged = onEditorObjectSelectionChanged
M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onEditorPreferenceValueChanged = onEditorPreferenceValueChanged
M.onEditorAfterSaveLevel = onEditorAfterSaveLevel
M.onNavgraphReloaded = onNavgraphReloaded

M.copySettingsAM = copySettingsAM
M.pasteFieldsAM = pasteFieldsAM
M.cycleHoveredRoadsAM = cycleHoveredRoadsAM
M.selectAllNodes = selectAllNodes

M.enableDrawMode = enableDrawMode
M.getDrawMode = getDrawMode

return M