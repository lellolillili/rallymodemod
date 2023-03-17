-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- This file contains helper functions to group and ungroup nodes in the flowgraph editor.
local C = {}
local im = ui_imgui

function C:init(mgr)
  self.mgr = mgr
end

function C:getRectCenter(nodes)
  local rect = {math.huge, math.huge, -math.huge, -math.huge} -- minX, minY, maxX, maxY
  for _, node in ipairs(nodes) do
    local nodeSize = ui_flowgraph_editor.GetNodeSize(node.id)
    local nodePos = ui_flowgraph_editor.GetNodePosition(node.id)
    if nodeSize.x == 0 and nodeSize.y == 0 then
      nodeSize.x = 200
      nodeSize.y = 100
    end
    if nodePos.x < rect[1] then
      rect[1] = nodePos.x
    end
    if nodePos.x + nodeSize.x > rect[3] then
      rect[3] = nodePos.x + nodeSize.x
    end
    if nodePos.y < rect[2] then
      rect[2] = nodePos.y
    end
    if nodePos.y + nodeSize.y > rect[4] then
      rect[4] = nodePos.y + nodeSize.y
    end
  end
  local center = {(rect[1]+rect[3])/2, (rect[2]+rect[4])/2}
  return rect, center
end

function C:centerNodes(nodes, pos)
  local r, center = self:getRectCenter(nodes)
  for _, node in ipairs(nodes) do
    local nodeSize = ui_flowgraph_editor.GetNodeSize(node.id)
    if nodeSize.x == 0 and nodeSize.y == 0 then
      nodeSize.x = 200
      nodeSize.y = 100
    end
    local nodePos = ui_flowgraph_editor.GetNodePosition(node.id)
    if nodePos.x < -2e8 or nodePos.y < -2e8 or nodePos.x > 2e8 or nodePos.y > 2e8 then
      nodePos.x = -nodeSize.x/2 + center[1]
      nodePos.y = -nodeSize.y/2 + center[2]
    end

    local offset = {nodePos.x - center[1] , nodePos.y - center[2]}

    node:alignToGrid(pos[1]+offset[1], pos[2]+offset[2] - nodeSize.y/2)
  end
end

function C:centerMultiNodes(fixNodes, moveNodes)
  -- get the rect enclosing the fixNodes.
  local r, fixCenter = self:getRectCenter(fixNodes)
  -- get the rect enclosing the moveNodes.
  self:centerNodes(moveNodes, fixCenter)
end

local function getEntryExitNode(graph)
  local entry, exit = nil, nil
  for _, node in pairs(graph.nodes) do
    if node.nodeType == 'states/stateEntry' then
      entry = node
    end
    if node.nodeType == 'states/stateExit' then
      exit = node
    end
  end
  return entry, exit
end

local function sortLinks(nodeIds, graph)
  local inLinks, middleLinks, outLinks = {},{},{}
  local nodeLookup = tableValuesAsLookupDict(nodeIds)
  --dump(nodeLookup)
  for id, lnk in pairs(graph.links) do
    local i, o = nodeLookup[lnk.targetNode.id], nodeLookup[lnk.sourceNode.id]
    if i and o then table.insert(middleLinks, lnk)
    elseif i then   table.insert(inLinks, lnk)
    elseif o then   table.insert(outLinks, lnk)
    end
  end
  return inLinks, middleLinks, outLinks
end

function C:createGroupingFromSelection()
  if self.mgr.graph.isStateGraph then
    return self:groupStateNodes()
  else
    return self:groupFlowNodes()
  end
end

function C:groupStateNodes()
  local oldGraph = self.mgr.graph

  -- remove entry and exit nodes from selected node.
  local selectedNodes = {}
  for id, _ in pairs(self.mgr.selectedNodes) do
    if oldGraph.nodes[id].nodeType ~= 'states/stateEntry' and oldGraph.nodes[id].nodeType ~= 'states/stateExit' then
      table.insert(selectedNodes, id)
    end
  end

  local groupGraph, groupNode = self.mgr:createGroupState("new group")
  local entry, exit = getEntryExitNode(groupGraph)
  local inLinks, middleLinks, outLinks = sortLinks(selectedNodes, oldGraph)

  -- move all middleLinks and all selectedNodes to the new graph
  for _, id in ipairs(selectedNodes) do
    local nd = oldGraph.nodes[id]
    oldGraph.nodes[id] = nil
    groupGraph.nodes[id] = nd
    nd.graph = groupGraph
  end
  for _, lnk in ipairs(middleLinks) do
    oldGraph.links[lnk.id] = nil
    groupGraph.links[lnk.id] = lnk
    lnk.graph = groupGraph
  end


  -- move all in and outlinks to link to the groupnode and make a new link in the groupGraph
  local pinHasBeenLinked = {}
  local inPin, outPin = groupNode.pinInLocal.flow, groupNode.pinOut.success
  for _, lnk in ipairs(inLinks) do
    if not pinHasBeenLinked[lnk.targetPin.id] then
      groupGraph:createLink(entry.pinOut.flow, lnk.targetPin)
      pinHasBeenLinked[lnk.targetPin.id] = true
    end
    if not pinHasBeenLinked[lnk.sourcePin.id] then
      oldGraph:createLink(lnk.sourcePin, inPin)
      pinHasBeenLinked[lnk.sourcePin.id] = true
    end
    oldGraph:deleteLink(lnk)
  end
  for _, lnk in ipairs(outLinks) do
    if not pinHasBeenLinked[lnk.sourcePin.id] then
      groupGraph:createLink(lnk.sourcePin, exit.pinInLocal.flow)
      pinHasBeenLinked[lnk.sourcePin.id] = true
    end
    if not pinHasBeenLinked[lnk.targetPin.id] then
      oldGraph:createLink(outPin, lnk.targetPin)
      pinHasBeenLinked[lnk.targetPin.id] = true
    end
    oldGraph:deleteLink(lnk)
  end

  -- align stuff nicely
  local selectedNodesNodes = {}
  for _, id in ipairs(selectedNodes) do
    table.insert(selectedNodesNodes, groupGraph.nodes[id])
  end

  local rect, center = self:getRectCenter(selectedNodesNodes)
  self:centerMultiNodes(selectedNodesNodes, {groupNode})
  local entryPos = ui_flowgraph_editor.GetNodePosition(entry.id)

  exit:alignToGrid(entryPos.x + rect[3]-rect[1] + 500, entryPos.y)
  self:centerMultiNodes({entry, exit}, selectedNodesNodes)

  return groupNode
end

function C:groupFlowNodes()
  local oldGraph = self.mgr.graph
  local newGraph = self.mgr:createGraph("",oldGraph.type == 'macro')
  newGraph.parentId = oldGraph.id
  --table.insert(oldGraph.children, newGraph)
  if self.mgr.graph.subGraphName and self.mgr.graph.subGraphName~='' then
    newGraph.name = self.mgr.graph.subGraphName
  else
    newGraph.name = (self.mgr.graph.type == "graph" and 'Subgraph ' or 'Submacro ') .. newGraph.id
  end
  newGraph.type = self.mgr.graph.type
  if newGraph.type == "macro" then
    self.mgr.macros[newGraph.id] = newGraph
  end
  newGraph.variables:_onDeserialized(oldGraph.variables:_onSerialize())
  local selectedNodes = shallowcopy(self.mgr.selectedNodes)
  local integratedNodes = {}

  -- first: clone nodes
  local oldIdMap = {}
  local graphRect = {math.huge, math.huge, -math.huge, -math.huge} -- minX, minY, maxX, maxY
  for nodeId, _ in pairs(selectedNodes) do
    local oldNode = oldGraph.nodes[nodeId]
    local nodeData = oldNode:__onSerialize()

    if oldNode.nodeType == 'macro/integrated' then
      -- special case where the node will be moved manually. this is to
      -- preserve the graphs and avoid the serialize/deserialize madness.

      --local childIndex = arrayFindValueIndex(oldGraph.children, oldNode.targetGraph)
      --table.remove(oldGraph.children, childIndex)
      --table.insert(newGraph.children, oldNode.targetGraph)
      newGraph.nodes[oldNode.id] = oldNode
      integratedNodes[oldNode.id] = true
      oldNode.graph = newGraph
      oldIdMap[oldNode.id] = oldNode
    else
      local newNode = newGraph:createNode(nodeData.type)
      newNode:__onDeserialized(nodeData)
      oldIdMap[oldNode.id] = newNode

    end
    local nodeSize = ui_flowgraph_editor.GetNodeSize(nodeId)

    if nodeData.pos[1] < graphRect[1] then
      graphRect[1] = nodeData.pos[1]
    end
    if nodeData.pos[1] + nodeSize.x > graphRect[3] then
      graphRect[3] = nodeData.pos[1] + nodeSize.x
    end

    if nodeData.pos[2] < graphRect[2] then
      graphRect[2] = nodeData.pos[2]
    end
    if nodeData.pos[2] + nodeSize.y > graphRect[4] then
      graphRect[4] = nodeData.pos[2] + nodeSize.y
    end
  end
  --print('graphRect = ' .. dumps(graphRect))

  -- next: find link types
  local internalLinks = {}
  local inputLinks = {}
  local outputLinks = {}
  for lid, link in pairs(oldGraph.links) do
    local sourceContained = selectedNodes[link.sourceNode.id]
    local targetContained = selectedNodes[link.targetNode.id]
    if sourceContained and targetContained then
      table.insert(internalLinks, link)
    elseif not sourceContained and targetContained then
      table.insert(inputLinks, link)
    elseif sourceContained and not targetContained then
      table.insert(outputLinks, link)
    end
  end

  --print("internalLinks: " .. dumpsz(internalLinks, 1))
  --print("inputLinks: " .. dumpsz(inputLinks, 1))
  --print("outputLinks: " .. dumpsz(outputLinks, 1))

  -- first, the easy links: the completely internal ones
  for _, link in pairs(internalLinks) do
    local linkData = link:__onSerialize()
    local sourceNode = oldIdMap[linkData[1]]
    local sourcePin = sourceNode.pinOut[linkData[2]]
    local targetNode = oldIdMap[linkData[3]]
    local targetPin = targetNode.pinInLocal[linkData[4]]
    if not sourcePin or not targetPin then
      log('E', '', 'unable to recreate link: unable to find pins: ' .. dumps(linkData))
    else
      local link = newGraph:createLink(sourcePin, targetPin)
      link:__onDeserialized(linkData)
    end
  end

  -- make sure flow pins are at the top
  local function sortFlowPins(a, b)
    if a.type ~= b.type then return a.type < b.type end
    return a.id < b.id
  end

  table.sort(inputLinks, sortFlowPins)
  table.sort(outputLinks, sortFlowPins)
  local groupedPins = {}

  -- second: the input links
  local inputNode
  inputNode = newGraph:createNode('macro/io')
  inputNode.color = im.ImVec4(1,1,0,1)
  inputNode.name = 'input'
  inputNode.ioType = 'in'
  inputNode.allowCustomOutPins = true
  for _, link in pairs(inputLinks) do
    if not groupedPins[link.sourcePin.id] then
      groupedPins[link.sourcePin.id] = inputNode:createPin('out', link.targetPin.type, link.targetPin.accessName or link.targetPin.name, link.targetPin.default, link.targetPin.description, true)
    end
    local newInputPin = groupedPins[link.sourcePin.id]

    local linkData = link:__onSerialize()
    local sourceNode = inputNode
    local sourcePin = newInputPin
    local targetNode = oldIdMap[link.targetNode.id]
    local targetPin = targetNode.pinInLocal[link.targetPin.name]
    if not sourcePin or not targetPin then
      log('E', '', 'unable to recreate link: unable to find pins: ' .. dumps(linkData))
    else
      local link = newGraph:createLink(sourcePin, targetPin)
      link:__onDeserialized(linkData)
      link.virtual = 'input'
    end
  end

  -- third: the output links
  local outputNode
  outputNode = newGraph:createNode('macro/io')
  outputNode.color = im.ImVec4(1,0,1,1)
  outputNode.name = 'output'
  outputNode.ioType = 'out'
  outputNode.allowCustomInPins = true
  table.clear(groupedPins)

  for _, link in pairs(outputLinks) do
    if not groupedPins[link.sourcePin.id] then
      groupedPins[link.sourcePin.id] = outputNode:createPin('in', link.sourcePin.type, link.sourcePin.accessName or link.sourcePin.name, link.sourcePin.default, link.sourcePin.description, true)
    end
    local newOutputPin = groupedPins[link.sourcePin.id]
    local linkData = link:__onSerialize()
    local sourceNode = oldIdMap[link.sourceNode.id]
    local sourcePin = sourceNode.pinOut[link.sourcePin.name]
    local targetNode = outputNode
    local targetPin = newOutputPin
    if not sourcePin or not targetPin then
      log('E', '', 'unable to recreate link: unable to find pins: ' .. dumps(linkData))
    else
      local link = newGraph:createLink(sourcePin, targetPin)
      link:__onDeserialized(linkData)
      link.virtual = 'output'
    end
  end

  -- find nice positions for input/output node
  -- graphRect  -- minX, minY, maxX, maxY

  local centerPosY = graphRect[2] + ((graphRect[4] - graphRect[2]) * 0.5)
  local centerPosX = graphRect[1] + ((graphRect[3] - graphRect[1]) * 0.5)
  if inputNode then
    ui_flowgraph_editor.SetNodePosition(inputNode.id, im.ImVec2(graphRect[1] - 250, centerPosY - #inputLinks*15 -15))
    inputNode:alignToGrid()
  end
  if outputNode then
    ui_flowgraph_editor.SetNodePosition(outputNode.id, im.ImVec2(graphRect[3] + 150, centerPosY - #outputLinks*15 -15))
    outputNode:alignToGrid()
  end
  --print('centerPosX = ' .. tostring(centerPosX))
  --print('centerPosY = ' .. tostring(centerPosY))

  -- so, finally create the macro template node in the original graph to replace the cloned nodes

  for nodeId, _ in pairs(selectedNodes) do
    local node = oldGraph.nodes[nodeId]
    if integratedNodes[nodeId] then
      oldGraph.nodes[nodeId] = nil
    else
      oldGraph:deleteNode(node)
    end
  end
  groupedPins = {}
  local integratedNode = oldGraph:createNode('macro/integrated')
  integratedNode.name = newGraph.name
  integratedNode.targetGraph = newGraph
  integratedNode.targetID = integratedNode.targetGraph.id
  integratedNode.graphType = 'graph'
  integratedNode:setTargetGraph(newGraph)

  if #inputLinks > 0 then
    for _, link in pairs(inputLinks) do
      if not groupedPins[link.sourcePin.id] then
        groupedPins[link.sourcePin.id] = integratedNode:createPin('in', link.targetPin.type, link.targetPin.accessName or link.targetPin.name, link.targetPin.default, link.targetPin.description, true)
      end
      local newInputPin = groupedPins[link.sourcePin.id]
      local linkData = link:__onSerialize()
      --local sourceNode = link.sourceNode
      local sourcePin = link.sourcePin
      --local targetNode = integratedNode
      local targetPin = newInputPin
      if not sourcePin or not targetPin then
        log('E', '', 'unable to recreate link: unable to find pins: ' .. dumps(linkData))
      else
        local link = oldGraph:createLink(sourcePin, targetPin)
        link:__onDeserialized(linkData)
        link.virtual = 'input'
      end
    end
  end

  if #outputLinks > 0 then
    for _, link in pairs(outputLinks) do
      if not groupedPins[link.sourcePin.id] then
        groupedPins[link.sourcePin.id] = integratedNode:createPin('out', link.sourcePin.type, link.sourcePin.accessName or link.sourcePin.name, link.sourcePin.default, link.sourcePin.description, true)
      end
      local newOutputPin = groupedPins[link.sourcePin.id]
      local linkData = link:__onSerialize()
      --local sourceNode = integratedNode
      local sourcePin = newOutputPin
      --local targetNode = link.targetNode
      local targetPin = link.targetPin
      if not sourcePin or not targetPin then
        log('E', '', 'unable to recreate link: unable to find pins: ' .. dumps(linkData))
      else
        local link = oldGraph:createLink(sourcePin, targetPin)
        link:__onDeserialized(linkData)
        link.virtual = 'output'
      end
    end
  end

  ui_flowgraph_editor.SetNodePosition(integratedNode.id, im.ImVec2(centerPosX - 100, centerPosY - math.max(#outputLinks+1,#inputLinks+1)*15))
  integratedNode:alignToGrid()

  return integratedNode
end


function C:ungroupSelection()
  if self.mgr.graph.isStateGraph then
    return self:ungroupStateNode()
  else
    return self:ungroupFlowNode()
  end
end

function C:ungroupStateNode()
  local newGraph = self.mgr.graph
  local groupNode = newGraph.nodes[tableKeys(self.mgr.selectedNodes)[1]]
  local groupedGraph = groupNode:representsGraph()
  local entry, exit = getEntryExitNode(groupedGraph)
  -- get all nodes inside the grouped graph which are not entry/exit nodes
  local innerNodes = {}
  for id, nd in pairs(groupedGraph.nodes) do
    if nd.nodeType ~= 'states/stateEntry' and nd.nodeType ~= 'states/stateExit' then
      table.insert(innerNodes, id)
    end
  end
  -- figure out which links we can "uplift" easily
  local inLinks, middleLinks, outLinks = sortLinks(innerNodes, groupedGraph)
  -- get all the links coming in and out of the groupnode
  local gInLinks, gOutLinks = {},{}
  for id, lnk in pairs(newGraph.links) do
    if lnk.targetNode.id == groupNode.id then
      table.insert(gInLinks, lnk)
    elseif lnk.sourceNode.id == groupNode.id then
      table.insert(gOutLinks, lnk)
    end
  end

  -- move all innerNodes and middleLinks to the current graph
  for _, id in ipairs(innerNodes) do
    local nd = groupedGraph.nodes[id]
    groupedGraph.nodes[id] = nil
    newGraph.nodes[id] = nd
    nd.graph = newGraph
  end
  for _, lnk in ipairs(middleLinks) do
    groupedGraph.links[lnk.id] = nil
    newGraph.links[lnk.id] = lnk
    lnk.graph = newGraph
  end

  -- make a link for every source of gInLinks to every target of inLinks
  for _, gi in ipairs(gInLinks) do
    for _, i in ipairs(inLinks) do
      newGraph:createLink(gi.sourcePin, i.targetPin)
    end
  end
  -- make a link for every target of gOutLinks to every source of outLinks, depending on the setting of the stateExit node they reach
  for _, o in ipairs(outLinks) do
    local oLabel = o.targetNode.transitionName
    for _, go in ipairs(gOutLinks) do
      local goLabel = go.sourcePin.name
      if oLabel == goLabel then
        newGraph:createLink(o.sourcePin, go.targetPin)
      end
    end
  end

  -- remove all gIn and gOut links
  for _, lnk in ipairs(gInLinks) do newGraph:deleteLink(lnk) end
  for _, lnk in ipairs(gOutLinks) do newGraph:deleteLink(lnk) end

  -- move all innerNodes to the center of the groupNode
  local innerNodesNodes = {}
  for _, id in ipairs(innerNodes) do
    table.insert(innerNodesNodes, newGraph.nodes[id])
  end
  self:centerMultiNodes({groupNode}, innerNodesNodes)
  -- remove groupNode
  newGraph:deleteNode(groupNode)

  -- done!
end


return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end