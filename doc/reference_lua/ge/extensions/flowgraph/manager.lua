-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

local im = ui_imgui

local ffi = require('ffi')

local createBuilder = require('/lua/ge/extensions/flowgraph/builder')
local fg_utils = require('/lua/ge/extensions/flowgraph/utils')

function C:attach(fgEditor)
  self.fgEditor = fgEditor
  self:updateEditorPosition()
end

function C:detached()
  self.selectedNodeCount = 0
  self.selectedNodes = {}
  self.selectedLinkCount = 0
  self.selectedLinks = {}
end

function C:checkDuplicateId(id)
  if self.graphs[i] or self.macros[i] then
    print("Duplicate ID in graphs or macros. " .. id)
    return true
  else
    for _, graph in pairs(self.graphs) do
      if graph.nodes[i] then
        print("Duplicate id in graph " .. graph.name .. "/" .. node.name .. ": " .. id)
        return true
      end
    end
    if not occupied then
      for _, macro in pairs(self.macros) do
        if macro.nodes[i] then
          print("Duplicate id in macro " .. macro.name .. "/" .. node.name .. ": " .. id)
          return true
        end
      end
    end
  end
end

function C:getNextFreeGraphNodeId()
  local i = self.__nextFreeGraphNodeStart or 0
  local found = false
  while not found do
    i = i + 1
    local occupied = false
    if self.graphs[i] or self.macros[i] then
      occupied = true
    else
      for _, graph in pairs(self.graphs) do
        if graph.nodes[i] then
          occupied = true
          break
        end
      end
      if not occupied then
        for _, macro in pairs(self.macros) do
          if macro.nodes[i] then
            occupied = true
            break
          end
        end
      end
    end
    found = not occupied
  end
  self.__nextFreeGraphNodeStart = i
  return i
end

function C:getGraphNodeOffset()
  return self.__graphNodeOffset or 0
end

function C:autoGraphNodeOffset()
  local max = 0
  for grId, graph in pairs(self.graphs) do
    max = math.max(max, grId)
    for nId, node in pairs(graph.nodes) do
      max = math.max(max, nId)
    end
  end
  for mId, macro in pairs(self.macros) do
    max = math.max(max, mId)
    for nId, node in pairs(macro.nodes) do
      max = math.max(max, nId)
    end
  end
  self.__graphNodeOffset = max
end

function C:getNextFreePinLinkId()
  local i = self.__nextFreePinLinkStart or 2 ^ 29
  local found = false

  while not found do
    local occupied = false
    for _, graph in pairs(self.graphs or {}) do
      if graph.pins[i] or graph.links[i] then
        occupied = true
        break
      end
    end
    for _, graph in pairs(self.macros or {}) do
      if graph.pins[i] or graph.links[i] then
        occupied = true
        break
      end
    end
    found = not occupied
    i = i - 1
  end
  self.__nextFreePinLinkStart = i
  return i
end

function C:init(parent)
  self.graphs = {}
  -- This is a debugging code that will log each time the self.graphs table is manipulated in any way.
  --[[
  setmetatable(self.graphs, {
    __newindex = function(s, key, value)
      if value ~= nil then
        log('E', '', 'Added graph to graphs. ' .. value.name .. " / " ..value.id .. " / " ..value.type)
      else
        log('E', '', 'Removing Graph.'..key)
        print(debug.tracesimple())
      end
      rawset(s, key, value)
     end,
  })
  ]]


  self.__safeIds = true
  self.macros = {}
  self.fgMgr = parent
  self.__graphIdCounter = 0
  -- dummy graph
  self.graph = self:createGraph('New State')
  self.graph:createNode("events/onUpdate")
  self.recentInstance = nil

  self.hookList = {}
  --self.fgEditor.ectx = nil -- warning: ectx not set yet
  self.runningState = "stopped" -- "paused" "running"
  self.allowEditing = true
  self.createNewNode = false
  self.newLinkPin = nil
  self.newNodeLinkPin = nil
  self.id = self:getNextUniqueIdentifier()
  self.name = "New Project"
  self.logTag = self.name
  self.description = "Project description."
  self.isScenario = false
  self.authors = "Anonymous"
  self.difficulty = 40
  self.debugEnabled = false
  self.macroTags = {}
  self.selectedNodeCount = 0
  self.selectedNodes = {}
  self.selectedLinkCount = 0
  self.selectedLinks = {}
  self.graphsToUpdate = {}
  self.variables = require('/lua/ge/extensions/flowgraph/variableStorage')(self)
  self.customNodeLookup = nil

  self.modules = { }
  for _, m in ipairs({ 'drift', 'vehicle', 'level', 'prefab', 'timer', 'button', 'action', 'camera', 'file', 'traffic', 'mission', 'foreach', 'thread', 'ui' }) do
    self.modules[m] = require('/lua/ge/extensions/flowgraph/modules/' .. m .. 'Module').create(self)
  end
  self.moduleOrder = {}
  for k, _ in pairs(self.modules) do
    table.insert(self.moduleOrder, k)
  end
  table.sort(self.moduleOrder, function(a, b)
    return self.modules[a].moduleOrder < self.modules[b].moduleOrder
  end)
  self.extToUnload = {}

  -- drag'n'drop
  self.dragging = false
  self.dragDropData = nil

  self.frameCount = 0

  self.steps = 0
  self.dtReal = 0
  self.dtRaw = 0
  self.dtSim = 0

  self.selectedNodes = {}
  self.copiedNodes = {}
  self.linksToRemove = {}
  self.nodesToRemove = {}

  self.history = {}
  self.maxHistoryCount = 99
  self.currentHistoryIndex = 0

  self.events = {}
  self.eventDuplicateCheck = {}
  self.startTime = 0

  self.transient = false
  self:setupStateGraph()
  self.states = require('/lua/ge/extensions/flowgraph/states')(self)
  self.newStateTemplateAdded = true

  self.groupHelper = require('/lua/ge/extensions/flowgraph/groupHelper')(self)

  self.stopRunningOnClientEndMission = false
  self.extProxy = newExtensionProxy(parent, "FG_" .. self.name .. "_" .. self.id)
  core_flowgraphManager.runningProxies[self.extProxy.extName] = true
  self.extProxy:submitEventSinks({}, {})
  core_flowgraphManager.refreshDependencies()
  extensions.refresh('core_flowgraphManager')
  --self.extProxy.eNxtame = "flowgraph_extProxy_" .. self.name.."_"..self.id
  self:historySnapshot("Start of History")


end

function C:setupStateGraph(empty)
  -- setting up the default state graph
  self.stateGraph = self:createGraph("States")
  self.stateGraph.isStateGraph = true
  local node = nil
  if not empty then
    --dumpz(node, 2)
    node = self.stateGraph:createNode('states/stateNode')
    node:setTargetGraph(self.graph)
    node:alignToGrid(380, 0)

  end

  local entry = self.stateGraph:createNode('states/stateEntry')
  local exit = self.stateGraph:createNode('states/stateExit')
  entry:alignToGrid(0, 0)
  exit:alignToGrid(800, 0)
  exit.transitionName = ''
  if not empty then
    self.stateGraph:createLink(entry.pinOut.flow, node.pinInLocal.flow)
  end
  return self.stateGraph, entry, exit
end

function C:createGraphAsState(name, isStateGraph)
  -- setting up the default state graph
  local graph = self:createGraph(name)
  graph.isStateGraph = isStateGraph
  --table.insert(self.graphs, stateGraph)
  local node = self.graph:createNode('states/stateNode')
  --dumpz(node, 2)
  node:setTargetGraph(graph)
  --node:setAutoStart(true)
  return graph, node
end

function C:createGroupState(name)
  local childGraph = self:createGraph(name)
  childGraph.isStateGraph = true
  childGraph.parentId = self.graph.id
  --table.insert(self.graph.children, childGraph)
  local node = self.graph:createNode('states/stateNode')
  node:setTargetGraph(childGraph)

  local entry = childGraph:createNode('states/stateEntry')
  local exit = childGraph:createNode('states/stateExit')
  entry:alignToGrid(0, 0)
  exit:alignToGrid(800, 0)
  exit:alignToGrid()
  exit.transitionName = "success"
  return childGraph, node
end

function C:createStateFromLibrary(data)
  local graph = self:createGraph()
  local node = self.graph:createNode('states/stateNode')

  self:autoGraphNodeOffset()
  if data.minId then
    self.__graphNodeOffset = self.__graphNodeOffset - data.minId + 1
  end

  graph:_onDeserialized(data.graph, oldIdMap)
  graph.name = data.name or graph.name
  --oldIdMap[tonumber(graphId)] = graph
  node:__onDeserialized(data.node)
  node:setTargetGraph(graph)
  return graph, node
end

function C:selectGraph(graph)
  if not graph then
    return
  end
  -- fix up selection in old graph
  graph.restoreView = true
  --[[
  ui_flowgraph_editor.ClearSelection()
  if self.graph then
    for _, node in pairs(self.graph.nodes) do
      node._isSelected = nil
    end
    for _, link in pairs(self.graph.links) do
      link._isSelected = nil
    end
  end
  ]]
  graph.showTab[0] = true
  self.focusGraph = graph
  if graph.type == 'instance' then
    self.recentInstance = graph
    if self.runningState == 'stopped' then
      graph = graph:getMacro()
    end
  end
  self.graph = graph
  self:unselectAll()
  --self.graph:forceRecursiveNodeUpdatePosition()
end

function C:createGraph(name, hidden, forceId)
  --print("Creating Graph. "..tostring(name).. "-" ..tostring(hidden))
  local graph = require('/lua/ge/extensions/flowgraph/graph')(self, name, forceId)
  if not hidden then
    self.graphs[graph.id] = graph
  end
  return graph
end

function C:copyGraph(oldGraph, newName, hidden)
  local newGraph = self:createGraph(newName or oldGraph.name, hidden)--require('/lua/ge/extensions/flowgraph/graph')(self, newName or oldGraph.name)
  local macroID = oldGraph.macroID
  local serialized = oldGraph:_onSerialize()
  local map = {}
  newGraph:_onDeserialized(serialized, map)
  newGraph.name = newName or oldGraph.name
  --[[ if not hidden then
     self.graphs[newGraph.id] = newGraph
   end--]]
  newGraph.macroID = macroID
  return newGraph
end

function C:convertToMacro(graph)
  if not graph then
    return
  end
  -- first, save the copy of the graph as a macro file. put copy into macro list.
  ui_flowgraph_editor.SetCurrentEditor(self.fgEditor.ectx)
  local serialized = graph:_onSerialize()
  --serialized.dirty = true

  local macro = require('/lua/ge/extensions/flowgraph/graph')(self)
  local map = {}
  macro:_onDeserialized(serialized, map)
  macro:updateChildrenTypes("macro", 'instance')
  self.macros[macro.id] = macro
  --self.graphs[macro.id] = macro

  --original graph becomes instance of this new graph
  graph:updateChildrenTypes("instance")
  graph.macroID = macro.id
  graph.name = macro.name
  graph.dirty = false
  graph.showTab[0] = false

  -- find the node that represents this instance.
  local node = self:findIntegratedNode(graph)
  if not node then
    log('E', "convertToMacro", "Could not find integrated node for converted graph!")
    return
  end
  node.macroID = macro.id
  node.name = macro.name
  node.graphType = 'instance'

  --  self:queueGraphForUpdate(graph)
  --graph:setDirty(true)
  self:selectGraph(graph)
  return macro
end

function C:refreshIntegratedPins(node)
  local inLinks = {}
  local outLinks = {}
  local hardCoded = {}
  local hidden = { p_in = {}, p_out = {} }
  local graph = node.graph
  node.name = node.targetGraph.name
  node.description = node.targetGraph.description
  -- find all links that are connected to this node.
  for lid, link in pairs(graph.links) do
    if link.sourceNode.id == node.id then
      table.insert(outLinks, link)
    end
    if link.targetNode.id == node.id then
      table.insert(inLinks, link)
    end
  end


  -- Find all Pins
  local pins = {}
  for _, pin in pairs(node.pinList) do
    table.insert(pins, pin)

    if pin.direction == 'in' and pin.pinMode == 'hardcoded' then
      local iPin = node.pinIn[pin.name]
      hardCoded[pin.name] = { value = iPin.value, hardCodeType = iPin.hardCodeType }
    end
    if pin.hidden then
      hidden['p_' .. pin.direction][pin.name] = true
    end
  end

  -- remove all links and pins.
  for _, link in pairs(inLinks) do
    graph:deleteLink(link)
  end
  for _, link in pairs(outLinks) do
    graph:deleteLink(link)
  end
  for _, pin in pairs(pins) do
    node:removePin(pin)
  end

  -- add new Pins from i/o nodes
  local inPins, outPins = node:gatherPins()
  for name, vals in pairs(hardCoded) do
    if node.pinInLocal[name] ~= nil then
      node:_setHardcodedDummyInputPin(node.pinInLocal[name], vals.value, vals.hardCodeType)
    end
  end
  for name, _ in pairs(hidden.p_in) do
    if node.pinInLocal[name] ~= nil then
      node.pinInLocal[name].hidden = true
    end
  end
  for name, _ in pairs(hidden.p_out) do
    if node.pinOut[name] ~= nil then
      node.pinOut[name].hidden = true
    end
  end


  -- connect old links to new pins. remove links which no longer connected.
  if #inLinks > 0 then
    for _, link in pairs(inLinks) do
      local newPin = nil
      -- find target pin.
      for index, pin in ipairs(inPins) do
        if pin.name == link.targetPin.name then
          newPin = pin
          table.remove(inPins, index)
          break
        end
      end
      local linkData = link:__onSerialize()
      if newPin then
        -- remove to have less to look for next time
        local sourcePin = link.sourcePin

        if not sourcePin or not newPin then
          log('E', '', 'unable to recreate link: unable to find pins: ' .. dumps(linkData))
        elseif graph:canCreateLink(sourcePin, newPin) then
          local link = graph:createLink(sourcePin, newPin)
          link:__onDeserialized(linkData)
          link.virtual = 'input'
        end
      else
        -- link is now obsolete or could not be connected.
        log('E', '', 'Link no longer valid: ' .. dumps(linkData))
      end
    end
  end

  if #outLinks > 0 then
    for _, link in pairs(outLinks) do
      local newPin = nil
      -- find target pin.
      for index, pin in ipairs(outPins) do
        if pin.name == link.sourcePin.name then
          newPin = pin
          --table.remove(outPins, index)
          break
        end
      end
      local linkData = link:__onSerialize()
      if newPin then
        -- remove to have less to look for next time
        local targetPin = link.targetPin

        if not newPin or not targetPin then
          log('E', '', 'unable to recreate link: unable to find pins: ' .. dumps(linkData))
        elseif graph:canCreateLink(newPin, targetPin) then
          local link = graph:createLink(newPin, targetPin)
          link:__onDeserialized(linkData)
          link.virtual = 'input'
        end
      else
        -- link is now obsolete or could not be connected.
        log('E', '', 'Link no longer valid: ' .. dumps(linkData))
      end
    end
  end
end

function C:findIntegratedNode(graph)
  -- find the node that represents this graph
  local integratedNode

  if graph:getParent() then
    for _, n in pairs(graph:getParent().nodes) do
      if n.nodeType == 'macro/integrated' then
        if n.targetGraph.id == graph.id then
          integratedNode = n
        end
      end
    end
  end

  return integratedNode
end

function C:updateSubgraphs(graph)
  --print("Update Subgraphs is called.")
  for id, node in pairs(graph.nodes) do
    if (node.nodeType == "macro/integrated") then
      local subgraph = self:copyGraph(self.graphs[node.targetGraph.id])
      subgraph.parentId = graph.id
      subgraph.type = 'instance'
      --table.insert(graph.children, subgraph)
      node:setTargetGraph(subgraph)
      self:updateSubgraphs(subgraph)
    end
  end
end

function C:updateInstances(macro)

  if macro then
    -- get root of the the macro
    macro = macro:getRootGraph()
    --print("Changed Macro " .. macro.name .. " (" .. macro.id .. ")")
    ui_flowgraph_editor.SetCurrentEditor(self.fgEditor.ectx)
    macro:forceRecursiveNodeUpdatePosition()
    local serializedData = macro:_onSerialize()
    serializedData.type = "instance"
    serializedData.dirty = false

    -- Save graph ids in array to loop over. We need to do it like this because we add stuff to self.graphs while looping
    local graphIds = {}
    for id, graph in pairs(self.graphs) do
      table.insert(graphIds, graph.id)
    end

    -- Find the instances and update them

    local graphsToBeDeleted = {}
    local storedPreviousInstance = self.recentInstance:getChildPosition()
    for _, graphID in ipairs(graphIds) do
      local graph = self.graphs[graphID]
      if graph and (graph.type == "instance") then
        if graph.macroID == macro.id then
          --print("Updating Instance " .. graph.name .. " ("..graph.id..")")
          -- find the node that represents this macro
          local integratedNode = self:findIntegratedNode(graph)

          table.insert(graphsToBeDeleted, graph)
          if integratedNode then
            graph:clear()
            graph:_onDeserialized(serializedData, {})
            graph:updateChildrenTypes('instance')
            graph:setDirty(false, false)
            if self._recentInstanceRestore then
              --print("restoring instance .")
              self.recentInstance = graph:getDeepChild(storedPreviousInstance)
              self._recentInstanceRestore = nil
            end
            --self:updateSubgraphs(graph)

            -- link i/o nodes to node.
            integratedNode:setTargetGraph(graph)
            self:refreshIntegratedPins(integratedNode)
          else
            log('E', "updateInstances", "Could not find integrated node for converted graph!")
          end
        end
      end
    end

    self:selectGraph(self.recentInstance)
  end
end

function C:saveMacro(macro, savedata)
  local root = macro:getRootGraph()
  if root.type ~= "macro" then
    log('E', logTag, 'root is not a macro')
    return
  end

  ui_flowgraph_editor.SetCurrentEditor(self.fgEditor.ectx)
  for id, graph in pairs(self.graphs) do
    if graph.type == "instance" then
      if graph.macroID == root.id then

        -- find the node that represents this macro
        local integratedNode = self:findIntegratedNode(graph)
        integratedNode.macroPath = savedata.filepath
      end
    end
  end
  root.macroPath = savedata.filepath
  root:setDirty(false)
  local macroSerialized = root:_onSerialize()
  if self.macroTags then
    macroSerialized.tags = self.macroTags
  end
  jsonWriteFile(savedata.filepath, macroSerialized, true, 20)
  self.newMacroAdded = true
  self.macroTags = {}
  --  jsonWriteFile(savedata.filepath, macroSerialized, true)
  -- self.newMacroAdded = true
  -- Find the graph with the same filename to update
  --[[local oldGraph
  for id,graph in pairs(self.macros) do
    if graph.macroPath == savedata.filepath then
      oldGraph = graph
      break
    end
  end

  if oldGraph then
    oldGraph:clear()
    oldGraph:_onDeserialized(macroSerialized, {})

    -- Save graph ids in array to loop over
    local graphIds = {}
    for id, graph in pairs(self.graphs) do
      table.insert(graphIds, graph.id)
    end

    -- Find the instances and update them
    local graphsToBeDeleted = {}
    for _, graphID in ipairs(graphIds) do
      local graph = self.graphs[graphID]
      if graph.type == "instance" then
        if graph.macroID == oldGraph.id then

          -- find the node that represents this macro
          local integratedNode = self:findIntegratedNode(graph)

          if not integratedNode then
            log('E', "saveMacro", "Could not find integrated node for converted graph!")
            return
          end
          table.insert(graphsToBeDeleted, graph)
          self:createMacroInstanceFromPath(savedata.filepath, integratedNode)
          self:refreshIntegratedPins(integratedNode)
        end
      end
    end

    -- Delete old instances of this macro
    for i=1,#graphsToBeDeleted do
      self:deleteGraph(graphsToBeDeleted[i])
    end
  end]]
end

function C:createNewMacroNode(path)
  local node = self.graph:createNode('macro/integrated')
  local instance = self:createMacroInstanceFromPath(path, node)
  node:setTargetGraph(instance)
  node:gatherPins()
end

function C:createInstanceFromMacro(macro, node, forceId)
  local serializedData
  --print("createInstanceFromMacro ".. macro.name)
  --ui_flowgraph_editor.SetCurrentEditor(self.fgEditor.ectx)
  local serializedData = macro:_onSerialize()
  serializedData.type = "instance"
  if not serializedData then
    return
  end

  -- create actual graph.
  local instance = self:createGraph('', true, forceId)
  local map = {}
  instance:_onDeserialized(serializedData, map)
  instance:updateChildrenTypes('instance')
  instance.macroID = macro.id
  if node then
    instance.parentId = node.graph.id
  end
  instance:setDirty(false, false)

  --table.insert(node.graph.children, instance)
  self.graphs[instance.id] = instance
  if node then
    -- link i/o nodes to node.
    node:setTargetGraph(instance)
    node.macroID = macro.id
    node.graphType = 'instance'
    node.targetGraph = instance
    node.targetID = instance.id
    node.name = instance.name
  end
  return instance
end

function C:createMacroInstanceFromPath(path, node)
  local serializedData, macroID

  -- check if we have the macro already loaded.
  --ui_flowgraph_editor.SetCurrentEditor(self.fgEditor.ectx)
  for id, macro in pairs(self.macros) do
    if macro.macroPath == path then
      serializedData = macro:_onSerialize()
      macroID = macro.id
    end
  end

  -- if not found, load from file.
  if serializedData == nil then
    --print("Loading Macro from File.")
    serializedData = jsonReadFile(path)
    local macro = self:createGraph('for from file loading', true)
    local map = {}
    macro.type = "macro"
    macro:_onDeserialized(serializedData, map)
    macro.macroPath = path
    self.macros[macro.id] = macro
    --self.graphs[macro.id] = macro
    macroID = macro.id
    --print("Done loading Macro from File.")
  end
  if not serializedData then
    return
  end
  -- create actual graph.
  local instance = self:createGraph('for from file instancing', true)
  local map = {}
  serializedData.type = (node.graph.type == 'macro') and 'macro' or "instance"
  --print("node for instance from path graphs type is "  ..node.graph.type)
  instance:_onDeserialized(serializedData, map)
  instance:updateChildrenTypes('instance')
  instance.macroID = macroID
  instance.parentId = node.graph.id

  instance:setDirty(false, false)

  --table.insert(node.graph.children, instance)
  if node.graph.type == 'macro' then
    self.macros[instance.id] = instance
  else
    self.graphs[instance.id] = instance
  end

  -- link i/o nodes to node.
  node:setTargetGraph(instance)
  node.macroID = macroID
  node.graphType = 'instance'
  node.targetGraph = instance
  node.targetID = instance.id
  node.name = instance.name
  node.macroPath = path
  return instance
end

function C:deleteGraph(graph)
  -- if graph is not inside graph or macro list, ignore
  local contained = false
  for _, gr in pairs(self.graphs) do
    contained = contained or gr == graph
  end
  for _, gr in pairs(self.macros) do
    contained = contained or gr == graph
  end
  if not contained then
    log('E', '', 'Tried to remove graph when graphs was actually not in manager! ' .. debug.tracesimple())
    return
  end
  if graph.flaggedForDelete then
    return
  end

  graph.flaggedForDelete = true
  graph:clear()
  local iNode = nil
  if graph:getParent() then
    -- delete integrated node from parent
    local iNode = nil
    for nId, node in pairs(graph:getParent().nodes) do
      if node:representsGraph() and node:representsGraph().id == graph.id then
        iNode = node
        break
      end
    end
  end
  if not iNode then
    -- check all graphs, there is probably be one in the state graphs.
    for _, g in pairs(self.graphs) do
      for nId, node in pairs(g.nodes) do
        --dump(g.id.."/"..nId)
        if node:representsGraph() and node:representsGraph().id == graph.id then
          iNode = node
          break
        end
      end
    end
  end
  if iNode then
    iNode.graph:deleteNode(iNode, true)
  end

  if self.graph.id == graph.id then
    self:selectGraph(self.graphs[next(self.graphs)])
  end
  self.graphs[graph.id] = nil
  self.macros[graph.id] = nil
end

function C:setupCreationWorkflow()
  if editor.getPreference("flowgraph.debug.editorDebug") then
    return
  end
  if self.graph.isStateGraph then
    return
  end
  if self._creationWorkflowInfo then
    return
  end
  local pinId = ffi.new('fge_PinId[1]', 0)
  local originPin = nil
  if ui_flowgraph_editor.QueryNewNode1(pinId) then
    originPin = self.graph:findPin(tonumber(pinId[0]))
  end
  if not originPin then
    return
  end

  self._creationWorkflowInfo = {}
  -- do a breadth first from the current node to the opposite direction of the selected pin, to find all disallowed nodes.
  local edge = {}
  edge[originPin.node.id] = true
  local dir = originPin.direction
  for _, node in pairs(self.graph.nodes) do
    self._creationWorkflowInfo[node.id] = { allowed = true }
  end
  -- do the actual bfs
  local hasNext = true
  repeat
    local nextEdge = {}
    for nId, _ in pairs(edge) do
      print(nId)
      local node = self.graph.nodes[nId]
      self._creationWorkflowInfo[node.id].allowed = false
      local targets, sources = node:getLinks()
      -- if the origin pin is an in-pin, use sources list and target nodes of those links.
      if dir == 'in' then
        for _, lnk in ipairs(sources) do
          nextEdge[lnk.targetNode.id] = true
        end
      end
      -- if the origin pin is an out-pin, use target list and source nodes of those links.
      if dir == 'out' then
        for _, lnk in ipairs(targets) do
          nextEdge[lnk.sourceNode.id] = true
        end
      end
    end
    edge = nextEdge
    hasNext = next(edge)
  until not hasNext

end

function C:creationWorkflow()
  local mp = im.GetMousePos()
  if ui_flowgraph_editor.BeginCreate(im.ImVec4(1, 1, 1, 1), 2) then
    self:setupCreationWorkflow()
    local startPinId = ffi.new('fge_PinId[1]', 0)
    local endPinId = ffi.new('fge_PinId[1]', 0)

    -- create a new link?
    if ui_flowgraph_editor.QueryNewLink1(startPinId, endPinId) then
      local startPin = self.graph:findPin(tonumber(startPinId[0]))
      local endPin = self.graph:findPin(tonumber(endPinId[0]))

      if startPin then
        self.newLinkPin = startPin
      else
        self.newLinkPin = endPin
      end

      if startPin and startPin.direction == 'in' then
        local t = startPin
        startPin = endPin
        endPin = t
        t = startPinId
        startPinId = endPinId
        endPinId = t
      end
      if startPin and endPin then
        if startPin == endPin then
          ui_flowgraph_editor.RejectNewItem2(im.ImVec4(1, 0, 0, 1), 2)

        elseif startPin.node.id == endPin.node.id then
          fg_utils.showLabel("x Cannot connect to the same node!", im.ImVec4(0.176, 0.125, 0.125, 0.706))
          ui_flowgraph_editor.RejectNewItem2(im.ImVec4(1, 0.5, 0.5, 1), 2)

        elseif endPin.direction == startPin.direction then
          fg_utils.showLabel("x Cannot connect In- to Out-Pins.", im.ImVec4(0.176, 0.125, 0.125, 0.706))
          ui_flowgraph_editor.RejectNewItem2(im.ImVec4(1, 0, 0, 1), 2)

        elseif not self.graph:pinsCompatible(startPin, endPin) then
          if (startPin.type == "table" or (type(startPin.type) == "table" and tableContains(startPin.type, "table")))
                  and (endPin.type == "table" or (type(endPin.type) == "table" and tableContains(endPin.type, "table")))
                  and (startPin:getTableType() ~= endPin:getTableType() and startPin:getTableType() ~= 'generic' and endPin:getTableType() ~= 'generic') then
            fg_utils.showLabel("x Incompatible Table Types: " .. tostring(startPin:getTableType()) .. ' and ' .. tostring(endPin:getTableType()), im.ImVec4(0.176, 0.125, 0.125, 0.706))
          else
            fg_utils.showLabel("x Incompatible Types: " .. tostring(startPin.type) .. ' and ' .. tostring(endPin.type), im.ImVec4(0.176, 0.125, 0.125, 0.706))
          end
          ui_flowgraph_editor.RejectNewItem2(im.ImVec4(1, 0.5, 0.5, 1), 2)

        elseif self.graph:linkExists(startPin, endPin) then
          fg_utils.showLabel("Link already exists!")

        elseif self._creationWorkflowInfo and
                not self._creationWorkflowInfo[endPin.node.id].allowed and not self._creationWorkflowInfo[startPin.node.id].allowed then

          fg_utils.showLabel("x Cannot connect backwards!", im.ImVec4(0.176, 0.125, 0.125, 0.706))
          ui_flowgraph_editor.RejectNewItem2(im.ImVec4(1, 0.5, 0.5, 1), 2)

        elseif startPin.chainFlow == true then
          local p1 = self.graph:findPin(tonumber(startPinId[0]))
          local p2 = self.graph:findPin(tonumber(endPinId[0]))
          local replacedLinks = false

          if ui_flowgraph_editor.AcceptNewItem2(im.ImVec4(0.5, 1, 0.5, 1), 4) then

            for _, v in pairs(self.graph.links) do
              if self.graph:linkExists(startPin, v.targetPin) then
                replacedLinks = true
                self.graph:deleteLink(v)
              end
            end

            --[[
            for _, v in pairs(self.graph.links) do
              if self.graph:linkExists(v.sourcePin, endPin) then
                replacedLinks = true
                self.graph:deleteLink(v)
              end
            end
            --]]

            self.graph:createLink(p1, p2)

            if replacedLinks then
              self.fgEditor.addHistory("Replaced Link " .. p1.name .. " and " .. p2.name)
            end
          end
        elseif self.graph:hasLink(endPin) then
          fg_utils.showLabel("Replace link")
          if ui_flowgraph_editor.AcceptNewItem2(im.ImVec4(0.5, 1, 0.5, 1), 4) then
            local p1 = self.graph:findPin(tonumber(startPinId[0]))
            local p2 = self.graph:findPin(tonumber(endPinId[0]))
            for k, v in pairs(self.graph.links) do
              if v.targetPin.id == p2.id then
                self.graph:deleteLink(v)
              end
            end
            self.graph:createLink(p1, p2)
            self.fgEditor.addHistory("Replaced Link " .. p1.name .. " and " .. p2.name)
          end
        else
          fg_utils.showLabel("+ Create Link", im.ImVec4(0.125, 0.176, 0.125, 0.706))
          if ui_flowgraph_editor.AcceptNewItem2(im.ImVec4(0.5, 1, 0.5, 1), 4) then
            local p1 = self.graph:findPin(tonumber(startPinId[0]))
            local p2 = self.graph:findPin(tonumber(endPinId[0]))
            self.graph:createLink(p1, p2)
            self.fgEditor.addHistory("Linked " .. p1.name .. " and " .. p2.name)
          end
        end
      end
    end

    -- create new node?
    local pinId = ffi.new('fge_PinId[1]', 0)
    if ui_flowgraph_editor.QueryNewNode1(pinId) then
      self.newLinkPin = self.graph:findPin(tonumber(pinId[0]))
      if self.newLinkPin then
        fg_utils.showLabel("+ Create Node", im.ImVec4(0.125, 0.176, 0.125, 0.706))
      end

      if ui_flowgraph_editor.AcceptNewItem1() then
        self.createNewNode = true
        self.newNodeLinkPin = self.graph:findPin(tonumber(pinId[0]))
        self.fgEditor.nodelib:setNewNodeLinkPin(self.newNodeLinkPin)
        self.newLinkPin = nil
        self.openPopupPosition = mp

        self._nodeTemplates = nil -- force refresh
        ui_flowgraph_editor.Suspend()
        im.OpenPopup("BackgroundContextMenu")
        ui_flowgraph_editor.Resume()
      end
    end
  else
    self.newLinkPin = nil
    self._creationWorkflowInfo = nil
  end
  ui_flowgraph_editor.EndCreate()
end

function C:DrawTypeIcon(dataType, connected, alpha, typeIconSize, innercolor)
  local color = ui_flowgraph_editor.getTypeColor(dataType)
  if alpha then
    color.w = alpha
  end
  if connected == nil then
    connected = false
  end
  if typeIconSize == nil then
    typeIconSize = ui_flowgraph_editor.defaultTypeIconSize
  end
  local iconType = ui_flowgraph_editor.getTypeIcon(dataType)
  if innercolor == nil then
    innercolor = im.ImVec4(0.125, 0.125, 0.125, alpha)
  end
  local uiscale = im.uiscale[0]
  im.PushStyleVar2(im.StyleVar_ItemSpacing, im.ImVec2(0, 0))
  im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(0, 0))

  im.BeginGroup()--"",im.ImVec2(24* uiscale,24))
  im.SetCursorPosY(im.GetCursorPosY() + 3 * uiscale)
  im.SetCursorPosX(im.GetCursorPosX() + 3 * uiscale)
  editor.uiIconImage(editor.icons[iconType .. "_" .. (connected and 1 or 2)], im.ImVec2(typeIconSize * uiscale, typeIconSize * uiscale), color)
  im.SetCursorPosY(im.GetCursorPosY() + 3 * uiscale)
  im.SetCursorPosX(im.GetCursorPosX() + 3 * uiscale)
  im.EndGroup()

  im.PopStyleVar(2)
  --ui_flowgraph_editor.Icon(ui_imgui.ctx, im.ImVec2(typeIconSize * uiscale, typeIconSize * uiscale), iconType, connected, color, innercolor)
end

function C:deletionWorkflow()
  if ui_flowgraph_editor.BeginDelete() then
    for lId, _ in pairs(self.linksToRemove) do
      ui_flowgraph_editor.DeleteLink(lId)
    end
    for nId, _ in pairs(self.nodesToRemove) do
      ui_flowgraph_editor.DeleteNode(nId)
    end

    local linkId = ffi.new('fge_LinkId[1]', 0)
    while ui_flowgraph_editor.QueryDeletedLink(linkId, nil, nil) do
      if ui_flowgraph_editor.AcceptDeletedItem() then
      end
    end

    local nodeId = ffi.new('fge_NodeId[1]', 0)
    while ui_flowgraph_editor.QueryDeletedNode(nodeId) do
      if ui_flowgraph_editor.AcceptDeletedItem() then
      end
    end
  end
  ui_flowgraph_editor.EndDelete()
  self.linksToRemove = {}
  self.nodesToRemove = {}
end

function C:unselectAll()
  for nId, _ in ipairs(self.selectedNodes) do
    ui_flowgraph_editor.DeselectNode(nId)
  end
  table.clear(self.selectedNodes)
  for lId, _ in ipairs(self.selectedLinks) do
    ui_flowgraph_editor.DeselectLink(lId)
  end
  table.clear(self.selectedLinks)
end

-- updates the nodes/links table with the item that are selected in the C++ side of things
function C:updateEditorSelections()
  if not ui_flowgraph_editor.HasSelectionChanged() then
    return
  end
  local selectCountMax = ui_flowgraph_editor.GetSelectedObjectCount()

  -- nodes
  local selectNodeIdArray = ffi.new('fge_NodeId[' .. tostring(selectCountMax) .. ']')
  self.selectedNodeCount = ui_flowgraph_editor.GetSelectedNodes(selectNodeIdArray, selectCountMax)
  self.selectedNodes = {}
  for i = 1, self.selectedNodeCount do
    self.selectedNodes[tonumber(selectNodeIdArray[i - 1])] = 1
  end
  for id, node in pairs(self.graph.nodes) do
    node._isSelected = self.selectedNodes[node.id]
  end

  -- links
  local selectLinkIdArray = ffi.new('fge_LinkId[' .. tostring(selectCountMax) .. ']')
  self.selectedLinkCount = ui_flowgraph_editor.GetSelectedLinks(selectLinkIdArray, selectCountMax)
  self.selectedLinks = {}
  for i = 1, self.selectedLinkCount do
    self.selectedLinks[tonumber(selectLinkIdArray[i - 1])] = 1
    local isHidden = self:findLinkIdFromHiddenLinkId(tonumber(selectLinkIdArray[i - 1]))
    if isHidden then
      self.graph.links[isHidden].hidden = false
      ui_flowgraph_editor.SelectLink(isHidden, true)
    end
  end
  for id, link in pairs(self.graph.links) do
    link._isSelected = self.selectedLinks[link.id]
  end
end

function C:findLinkIdFromHiddenLinkId(hiddenId)
  for _, link in pairs(self.graph.links) do
    if link.hiddenId == hiddenId then
      return link.id
    end
  end
  return nil
end

function C:onDragStarted()
  self.dragging = true
end

function C:onDrag()
  if not dragging then
    self:onDragStarted()
  end
end

function C:onDragEnded()
  self.dragDropData = nil
  self.dragging = false
end

function C:dragDropTarget(payloadType)
  if im.BeginDragDropTarget() then
    local payload = im.AcceptDragDropPayload(payloadType)
    if payload ~= nil then
      assert(payload.DataSize == ffi.sizeof "char[64]");
      local path = ffi.string(ffi.cast("char*", payload.Data))
    end
    im.EndDragDropTarget()
  end
end

function C:dragDropSource(payloadType, data)
  if im.BeginDragDropSource() then
    self:onDrag()
    if not self.dragDropData then
      self.dragDropData = {}
    end
    if not self.dragDropData.payloadType then
      self.dragDropData.payloadType = payloadType
    end
    if not self.dragDropData.node then
      self.dragDropData.node = data
    end
    if not self.dragDropData.name then
      self.dragDropData.name = ffi.new('char[64]', data.path)
    end
    im.SetDragDropPayload(payloadType, self.dragDropData.name, ffi.sizeof 'char[64]', im.Cond_Once)

    if data.text then
      --  im.Text(data.text)
    end
    im.EndDragDropSource()
  end
end

function C:copyNodes()

  ui_flowgraph_editor.SetCurrentEditor(self.fgEditor.ectx)
  self.copyData = {
    nodes = {},
    graphs = {},
    links = {},
    --macros = {}
    mgrID = self.id,
    minId = math.huge

  }
  for id, _ in pairs(self.selectedNodes) do
    self.copyData.minId = math.min(id, self.copyData.minId)
    local selectedNode = self.graph.nodes[id]
    if selectedNode and not selectedNode.uncopyable then
      local n = {}
      n = selectedNode:__onSerialize()
      -- TODO: figure out how to copy macros between graphs...
      if selectedNode.representsGraph and selectedNode:representsGraph() ~= nil then
        local serialData, minId = self.graphs[selectedNode:representsGraph().id]:_onSerialize()
        self.copyData.minId = math.min(minId, self.copyData.minId)
        self.copyData.graphs[selectedNode:representsGraph().id] = serialData
        n.__representedGraphId = selectedNode:representsGraph().id
        if selectedNode:representsGraph().parentId == nil then
          n.__graphWasRoot = true
        end
      end
      self.copyData.nodes[id] = n
    end
  end

  for id, link in pairs(self.graph.links) do
    if self.selectedNodes[link.targetNode.id] ~= nil and self.selectedNodes[link.sourceNode.id] ~= nil
            and not link.sourceNode.uncopyable and not link.targetNode.uncopyable then
      self.copyData.links[link.id] = link:__onSerialize()
    end
  end
  if self.copyData.minId < math.huge then
    self.fgEditor.copyData = self.copyData
  else
    self.fgEditor.copyData = nil
  end
end

function C:pasteNodes()
  if not self.allowEditing then
    return
  end
  self.copyData = self.fgEditor.copyData
  if not self.copyData then
    return
  end
  self:autoGraphNodeOffset()
  --dumpz(self.copyData,2)
  --for _, gr in pairs(self.copyData.graphs) do
  --  dumpz(gr.nodes,1)
  --end
  self.__graphNodeOffset = self.__graphNodeOffset - self.copyData.minId + 1
  ui_flowgraph_editor.SetCurrentEditor(self.fgEditor.ectx)
  ui_flowgraph_editor.ClearSelection()
  local copiedNodesTblSize = tableSize(self.copyData.nodes)
  local mousePos = ui_flowgraph_editor.ScreenToCanvas(im.GetMousePos())
  local center = im.ImVec2(0, 0)
  for _, nodeData in pairs(self.copyData.nodes) do
    center.x = center.x + nodeData.pos[1]--.x
    center.y = center.y + nodeData.pos[2]--.y
  end
  center.x = center.x / copiedNodesTblSize
  center.y = center.y / copiedNodesTblSize
  local ids = {}
  --local oldIdMap = {}
  for id, nodeData in pairs(self.copyData.nodes) do
    if nodeData then
      local node
      node = self.graph:createNode(nodeData.type, tostring(id) + self:getGraphNodeOffset())
      node:__onDeserialized(nodeData)
      if node.canHaveGraph then
        local newGraph
        --if self.copyData.mgrID == self.id then
        --  newGraph = self:copyGraph(self.graphs[nodeData.__representedGraphId])
        --else
        newGraph = require('/lua/ge/extensions/flowgraph/graph')(self, "copiedGraph", nodeData.__representedGraphId + self:getGraphNodeOffset())
        local map = {}
        newGraph:_onDeserialized(self.copyData.graphs[nodeData.__representedGraphId])
        newGraph.type = 'graph'
        node.graphType = 'graph'
        --end
        --oldIdMap[nodeData.__representedGraphId] = newGraph
        if not nodeData.__graphWasRoot then
          newGraph.parentId = self.graph.id
          --table.insert(self.graph.children, newGraph)
        end
        self.graphs[newGraph.id] = newGraph
        if node.nodeType == 'macro/integrated' then
          node:setTargetGraph(newGraph)
        end
      else
        -- copy over data from copied node to pasted node
        --node:setData(deepcopy(nodeData.data))
      end
      ids[id] = node
      ui_flowgraph_editor.SetNodePosition(node.id, im.ImVec2(mousePos.x + (nodeData.pos[1] - center.x), mousePos.y + (nodeData.pos[2] - center.y)))
      node:alignToGrid(mousePos.x + (nodeData.pos[1] - center.x), mousePos.y + (nodeData.pos[2] - center.y))
      ui_flowgraph_editor.SelectNode(node.id, true)
    end
  end
  for id, node in pairs(ids) do
    if node.nodeType == 'macro/integrated' then
      self:refreshIntegratedPins(node)
    end
    if node.nodeType == 'states/stateNode' then
      node:_postDeserialize()
    end
  end
  for id, linkData in pairs(self.copyData.links) do
    local sourceNode = ids[linkData[1]]
    if sourceNode then
      local sourcePin = sourceNode.pinOut[linkData[2]]
      local targetNode = ids[linkData[3]]
      if targetNode then
        local targetPin = targetNode.pinInLocal[linkData[4]]
        if not sourcePin or not targetPin then
          log('E', '', 'unable to recreate link: unable to find pins: ' .. dumps(linkData))
          if not sourcePin and sourceNode.nodeType == 'util/ghost' then
            sourcePin = sourceNode:createPin('out', 'any', linkData[2], nil, "")
            log('W', '', 'Added generic sourcePin to ghost node.')
          end
          if not targetPin and targetNode.nodeType == 'util/ghost' then
            targetPin = targetNode:createPin('in', 'any', linkData[4], nil, "")
            log('W', '', 'Added generic targetPin to ghost node.')
          end
          if sourcePin and targetPin then
            local link = self.graph:createLink(sourcePin, targetPin)
            link:__onDeserialized(linkData)
          end
        else
          local link = self.graph:createLink(sourcePin, targetPin)
          link:__onDeserialized(linkData)
        end
      else
        log('E', '', 'targetNode node not found: ' .. tostring(linkData[3]))
      end
    else
      log('E', '', 'Source node not found: ' .. tostring(linkData[1]))
    end
  end

  self.fgEditor.addHistory("Pasted nodes")
end

function C:goToHistory(index)
  if self.history[index] == nil then
    return
  end
  self:_onDeserialized(self.history[index].data)
  self.currentHistoryIndex = index
  self.focusGraph = self.graph
  self._ignoreMove = true
end

function C:undo()
  if self.history[self.currentHistoryIndex - 1] == nil then
    return
  end
  self:_onDeserialized(self.history[self.currentHistoryIndex - 1].data)
  self.currentHistoryIndex = self.currentHistoryIndex - 1
  self.focusGraph = self.graph
  self._ignoreMove = true
end

function C:redo()
  if self.history[self.currentHistoryIndex + 1] == nil then
    return
  end
  self:_onDeserialized(self.history[self.currentHistoryIndex + 1].data)
  self.currentHistoryIndex = self.currentHistoryIndex + 1
  self.focusGraph = self.graph
  self._ignoreMove = true
end

function C:historySnapshot(title)
  --print("Snapshot History: " .. title)
  if not self.allowEditing then
    return
  end
  if self.currentHistoryIndex == self.maxHistoryCount then
    -- shift all entries back one
    for i = 1, self.maxHistoryCount - 1 do
      self.history[i] = self.history[i + 1]
    end
  end
  if self.currentHistoryIndex < self.maxHistoryCount then
    self.currentHistoryIndex = self.currentHistoryIndex + 1
  end

  self.history[self.currentHistoryIndex] = { title = title, data = self:_onSerialize() }

  for i = self.currentHistoryIndex + 1, self.maxHistoryCount do
    self.history[i] = nil
  end
end

function C:deleteSelectionButton()
  if not next(self.selectedNodes) and not next(self.selectedLinks) then
    return
  end
  self:deleteSelection()
  self.fgEditor.addHistory("Deleted Selection")
end

function C:deleteSelection()

  if self.allowEditing then
    for id, _ in pairs(self.selectedNodes) do
      local node = self.graph.nodes[id]
      if node then
        self.graph:deleteNode(node)
      end
    end

    for id, _ in pairs(self.selectedLinks) do
      local link = self.graph.links[id]
      if link then
        self.graph:deleteLink(link)
      end
    end
  end
end

function C:draw(dtReal, dtSim, dtRaw)
  --  self.dtReal = dtReal
  --  self.dtSim = dtSim
  --  self.dtRaw = dtRaw
end

function C:getAvailableMacros()
  local macroPath = '/flowEditor/macros/'
  local lookup = {}
  for i, filename in ipairs(FS:findFiles(macroPath, '*.json', -1, true, false)) do
    local dirname, fn, e = path.split(filename)
    local data = readJsonFile(filename)
    local macroName = string.match(fn, "(%a*)")
    data.path = filename
    lookup[macroName] = data
  end
  return lookup
end

function C:getAvailableStateTemplates()
  return self.fgMgr.getAvailableStateTemplates()
end

function C:getAvailableNodeTemplates()

  -- get customNodes if not loaded yet
  if not self.customNodeLookup and self.savedDir then
    self.customNodeLookup = self:getCustomNodeTemplates()
  end

  -- get basic nodes
  local res, lookup = self.fgMgr.getAvailableNodeTemplates()

  -- merge tables
  if self.customNodeLookup then
    lookup = tableMerge(lookup, self.customNodeLookup.lookup)
    res = tableMerge(res, self.customNodeLookup.res)
  end

  return res, lookup
end

function C:getCustomNodeTemplates()
  local res = {}
  local lookup = {}
  local customNodePath = self.savedDir .. "customNodes/"
  for _, filename in ipairs(FS:findFiles(customNodePath, '*Node.lua', -1, true, false)) do
    local dirname, fn, e = path.split(filename)
    -- TODO: clear up hack with filepaths (issue when loading a FG as a mission)
    local path = dirname:sub(string.len(customNodePath) + string.find(dirname, customNodePath))
    local pathArgs = split(path, '/')
    table.insert(pathArgs, 1, "customNodes")

    local treeNode = res
    for i = 1, #pathArgs do
      if pathArgs[i] ~= '' then
        if not treeNode[pathArgs[i]] then
          treeNode[pathArgs[i]] = { nodes = {} }
        end
        treeNode = treeNode[pathArgs[i]]
      end
    end
    local moduleName = string.sub(fn, 1, string.len(fn) - 4)
    local requireFilename = string.sub(filename, 1, string.len(filename) - 4)
    local status, node = pcall(rerequire, requireFilename)
    if not status then
      log('E', '', 'error while loading node ' .. tostring(requireFilename) .. ' : ' .. tostring(node) .. '. ' .. debug.tracesimple())
    else
      node.path = path .. moduleName
      node.sourcePath = customNodePath .. path .. moduleName .. '.lua'
      node.splitPath = pathArgs
      node.splitPath[#node.splitPath] = moduleName
      node.splitPath[#node.splitPath + 1] = node.node.name
      node.availablePinTypes = self.fgMgr.getAvailablePinTypes(node.node)
      treeNode.nodes[moduleName] = node
      lookup[path .. moduleName] = node
    end
  end
  return { lookup = lookup, res = res }
end

function C:clearGraph(graph)
  if graph == nil then
    graph = self.graph
  end
  for k, node in pairs(graph.nodes) do
    ui_flowgraph_editor.DeleteNode(node.id)
  end
  for k, link in pairs(graph.links) do
    ui_flowgraph_editor.DeleteLink(link.id)
  end
  graph:clear()
end

function C:deleteGraphs()
  for k, graph in pairs(self.graphs) do
    self:deleteGraph(graph)
  end
  for k, macro in pairs(self.macros) do
    self:deleteGraph(macro)
  end
end

-- intentionally unique between all editor instances to prevent possible problems in c++
local _uid = 0 -- do not use ever
-- intentionally unique between all editor instances to prevent possible problems in c++
function C:getNextUniqueIdentifier()
  return self.fgMgr.getNextUniqueIdentifier()
end

function C:_onSerialize()

  self:_onClear()
  local graphs = {}
  local macros = {}
  self:updateNodePositions()

  -- pairs is non deterministic, so sort this ourselfs
  local graphKeys = tableKeys(self.graphs)
  table.sort(graphKeys)
  for _, graphKey in ipairs(graphKeys) do
    local graph = self.graphs[graphKey]
    if graph.type == "graph" then
      --and graph.parentId == nil then
      graphs[graph.id] = graph:_onSerialize()
    end
    if graph.type == 'instance' then
      graphs[graph.id] = {
        macroID = graph.macroID,
        parentId = graph.parentId
      }
    end
  end

  local macroKeys = tableKeys(self.macros)
  table.sort(macroKeys)
  for _, macroKey in ipairs(macroKeys) do
    local macro = self.macros[macroKey]
    if macro.type == "macro" then
      -- serialize only local macros. other ones will be in their own files
      if macro.macroPath == nil then
        --and macro.parentId == nil then
        macros[macro.id] = macro:_onSerialize()
      end
    end
  end

  local res = {
    graphs = graphs,
    macros = macros,
    debugEnabled = self.debugEnabled,
    name = self.name,
    description = string.gsub(self.description, "\n", "\\n"),
    authors = self.authors,
    date = os.time(),
    difficulty = self.difficulty,
    isScenario = self.isScenario,
    currentGraphID = self.graph.id,
    variables = self.variables:_onSerialize(),
    savedDir = self.savedDir,
    savedFilename = self.savedFilename,
    version = ui_flowgraph_editor.flowgraphVersion,
    frecency = self.frecency or {},
  }
  if self.stateGraph then
    res.stateGraphId = self.stateGraph.id
  end

  if self.graph then
    res.activeGraphId = self.graph.id
  end
  jsonWriteFile("flowEditor/data-temp.json", res, true, 20)

  return res
end

function C:_onDeserialized(data)
  self.frameCount = 0
  self.updatedEditorPositions = nil
  self:setRunning(false)

  if next(data) then
    self.version = data.version or 0
    self.name = data.name or self.name
    self.description = string.gsub(data.description or "", "\\n", "\n") or self.description
    self.authors = data.authors or self.authors
    self.difficulty = data.difficulty or self.difficulty
    self.isScenario = data.isScenario or self.isScenario

    self.savedDir = data.savedDir
    self.savedFilename = data.savedFilename
    self.logTag = self.savedFilename or self.savedDir or self.name
    self.debugEnabled = data.debugEnabled
    self.frecency = data.frecency or {}
    self:deleteGraphs()
    table.clear(self.graphs)
    table.clear(self.macros)
    self:autoGraphNodeOffset()
    self.variables:_onDeserialized(data.variables)
    --local oldIdMap = {}
    -- first deserialize macros, so we have something to create later.

    if data.macros then
      -- create dependency map to figure out which macros to load first
      local dependencyMap = self:findDependencyMap(data.macros)

      for _, mID in ipairs(dependencyMap) do
        local macroID = self:getGraphNodeOffset() + tonumber(mID)
        local macroData = data.macros[mID]
        local macro = self:createGraph("empty", true, tonumber(macroID))
        macro:_onDeserialized(macroData)
        --print("Deserialized macro " .. macro.name)
        --oldIdMap[tonumber(macroID)] = macro
        self.macros[macro.id] = macro
      end
    end

    -- flatten lists for graphs before deserializing further!
    --dump(data.version)
    if data.version == 0.1 then
      log("I", "", "This is an older version (" .. data.version .. " vs " .. ui_flowgraph_editor.flowgraphVersion .. "). Updating format.")
      local currentGraphs = data.graphs
      local doFlatten = true
      while doFlatten do
        doFlatten = false
        local newGraphs = {}
        for gId, g in pairs(currentGraphs) do
          for cId, c in pairs(g.children or {}) do
            --dump(cId)
            newGraphs[cId] = c
            c.parentId = tonumber(gId) + self:getGraphNodeOffset()
            doFlatten = true -- continue to flatten
            log("I", "", "Flattened child: " .. gId .. "/" .. cId)
          end
          g.children = nil
          newGraphs[gId] = g
        end
        currentGraphs = newGraphs
      end

      data.graphs = currentGraphs
      log("I", "", "Successfully updated format.")
      --dumpz(data.graphs, 2)
    end

    if data.graphs then
      local activeGraphSet = false

      local graphKeys = tableKeys(data.graphs)
      table.sort(graphKeys)

      for _, graphId in ipairs(graphKeys) do
        local graphData = data.graphs[graphId]
        local grId = tonumber(graphId) + self:getGraphNodeOffset()
        if graphData.macroID then
          local cGraph = self:createInstanceFromMacro(self.macros[tonumber(graphData.macroID) + self:getGraphNodeOffset()], nil, tonumber(grId))
          cGraph.parentId = graphData.parentId + self:getGraphNodeOffset()
        else
          local graph = self:createGraph(nil, nil, grId)
          graph:_onDeserialized(graphData)
          -- oldIdMap[tonumber(graphId)] = graph
          if data.activeGraphId and tonumber(grId) == data.activeGraphId then
            activeGraphSet = true
            self.graph = graph
          end
        end
      end

      if activeGraphSet == false then
        self.graph = self.graphs[next(self.graphs)]
      end

    end
    if data.currentGraphID then
      self.selectGraph(self.graphs[data.currentGraphID + self:getGraphNodeOffset()])
    end
    --for k, v in pairs(oldIdMap) do print(k .. "=>" .. (v.nodeType ~= nil and "Node" or "Graph") .. dumps(v.name)) end
    -- rebuild stategraph or create new one
    if data.stateGraphId then
      self.stateGraph = self.graphs[data.stateGraphId + self:getGraphNodeOffset()]
    else
      self.stateGraph = nil
    end
    if not self.stateGraph then
      log("D", "", "Auto-Generating stategraph.")
      local gr, entry, exit = self:setupStateGraph(true)
      -- create one state node for each root graph.
      local tGraphs = {}

      local graphKeys = tableKeys(self.graphs)
      table.sort(graphKeys)
      for _, graphKey in ipairs(graphKeys) do
        local graph = self.graphs[graphKey]
        if graph.type == 'graph' and not graph.isStateGraph and graph.parentId == nil then
          table.insert(tGraphs, graph)
        end
      end
      for i, graph in ipairs(tGraphs) do
        log("D", "", "Auto State for graph: " .. graph.name)
        local node = self.stateGraph:createNode('states/stateNode')
        node:alignToGrid(380, (i - #tGraphs / 2) * 400)

        node:setTargetGraph(graph)
        self.stateGraph:createLink(entry.pinOut.flow, node.pinInLocal.flow)
      end
    end

    -- now we have the stategraph
    -- go through all nodes in all graphs, do postSetup

    for _, graph in pairs(self.graphs) do
      for _, node in pairs(graph.nodes) do
        node:_postDeserialize()
      end
    end
    --[[dumpz(node, 2)
    if node.nodeType == 'states/stateNode' and node.targetGraphId then
      log("D","","Restoring state node with tgtId: " .. node.targetGraphId)
      local tgtGraph = oldIdMap[node.targetGraphId]
      if tgtGraph then
        node:setTargetGraph(tgtGraph)
        node.targetGraphId = nil
        log("D","","Set target graph successfully")
      else
        log("E","","Could not find previous target graph for state node...")
      end
    end
  end
    ]]

    --dumpz(oldIdMap, 2)
  end
  self:updateEditorPosition()
  self.graphsToUpdate = {}
end

function C:updateEditorPosition(force)
  if self.fgEditor and self.fgEditor.ectx then
    ui_flowgraph_editor.SetCurrentEditor(self.fgEditor.ectx)
    for _, gr in pairs(self.graphs) do
      for _, node in pairs(gr.nodes) do
        node:updateEditorPosition()
      end
    end
    for _, gr in pairs(self.macros) do
      for _, node in pairs(gr.nodes) do
        node:updateEditorPosition()
      end
    end
    self.updatedEditorPositions = true
  end
end

function C:updateNodePositions()
  if self.fgEditor and self.fgEditor.ectx then
    ui_flowgraph_editor.SetCurrentEditor(self.fgEditor.ectx)
    for _, gr in pairs(self.graphs) do
      for _, node in pairs(gr.nodes) do
        node:updateNodePosition()
      end
    end
  end
end

function C:findMacrosUsedInChildren(graph, list)
  for id, child in pairs(graph.children or {}) do
    if child.macroID then
      table.insert(list, tostring(child.macroID))
    elseif child.nodes then
      self:findMacrosUsedInChildren(child, list)
    end
  end
end

function C:findDependencyMap(serializedMacros)
  -- generate map from macros to children.
  local map = {}
  local orderedDependency = {}

  for id, macro in pairs(serializedMacros) do
    local list = {}
    self:findMacrosUsedInChildren(macro, list)
    map[id] = list
  end
  repeat
    -- find resolved macros: those which have no children
    local resolved = {}
    for id, list in pairs(map) do
      if next(list) == nil then
        table.insert(resolved, id)
        table.insert(orderedDependency, id)
        map[id] = nil
      end
    end
    -- remove resolved from the list of others
    for _, res in ipairs(resolved) do
      for id, list in pairs(map) do
        if arrayFindValueIndex(list, res) then
          table.remove(list, arrayFindValueIndex(list, res))
        end
      end
    end
  until next(map) == nil
  return orderedDependency
end

local function revertMacroInstanceToSubgraph(self)
  for nodeId, _ in pairs(self.selectedNodes) do
    local oldNode = self.graph.nodes[nodeId]
    local nodeData = oldNode:__onSerialize()
    local oldGraph = self.graphs[nodeData.targetID]
    local newGraph = self:createGraph(oldGraph.name)
    local serialized = oldGraph:_onSerialize()
    local map = {}
    serialized.type = "graph"
    newGraph:_onDeserialized(serialized, map)
    newGraph.parentId = self.graph.id
    --table.insert(self.graph.children, newGraph)
    self.graphs[newGraph.id] = newGraph
    local integratedNode = self:findIntegratedNode(oldGraph)
    integratedNode:setTargetGraph(newGraph)
    integratedNode:setTargetGraph(newGraph)
    self:deleteGraph(oldGraph)
  end
end

function C:createSubgraphFromMacroInstance()
  revertMacroInstanceToSubgraph(self)
end

function C:createSubgraphFromSelection()
  local ret = self.groupHelper:createGroupingFromSelection()
  return ret
end

function C:resolveHooksAndReset()

  if self.queueReset then
    if self.graph.type == 'instance' then
      --self.focusGraph = self.graph:getMacro()
      self.graph = self.graph:getMacro()
    end
    self:_executionStopped()
    self:_onClear()
    self.queueReset = false
  end
  if self.queueRestart then
    self:setRunning(false)
    self:_executionStopped()
    self:_onClear()
    self:setRunning(true)
    self.queueReset = false
    self.queueRestart = false
  end
  --if self.runningState == 'running' then
  --  self.states:resolveTransitions()
  --end

end

function C:onUpdate(dtReal, dtSim, dtRaw)
  self.frameCount = self.frameCount + 1
  self.dtReal = dtReal
  self.dtSim = dtSim
  self.dtRaw = dtRaw
  if self.steps > 0 then
    self.steps = self.steps - 1
    if -self.steps == 0 then
      self:setPaused(true)
    end
  end
  for _, mod in ipairs(self.moduleOrder) do
    self.modules[mod]:onUpdate(dtReal, dtSim, dtRaw)
  end
end

function C:logEvent(name, type, description, meta)
  local gTime = os.date("*t")
  local event = {
    name = name,
    type = type or "",
    description = description or "",
    time = Engine.Platform.getRuntime(),
    frame = self.frameCount,
    meta = meta
  }
  event.globalTime = string.format("%02d:%02d:%02d", gTime.hour, gTime.min, gTime.sec)

  table.insert(self.events, event)
  if self.eventDuplicateCheck[name] then
    self.events[self.eventDuplicateCheck[name]].duplicates = (self.events[self.eventDuplicateCheck[name]].duplicates or 1) + 1
    self.events[#self.events].isDuplicate = true
  else
    self.eventDuplicateCheck[name] = #self.events
  end
  self._newEvent = true
end

function C:getHooklist()

  if self.runningState ~= "running" then
    return {}
  end
  local hookList = {}
  table.insert(hookList, self)

  local moduleHooks = {}
  for _, mod in ipairs(self.moduleOrder) do
    local m = self.modules[mod]
    for _, h in ipairs(m.hooks or {}) do
      moduleHooks[h] = moduleHooks[h] or {}
      table.insert(moduleHooks[h], m)
    end
  end

  local hooks = {}
  for h, ms in pairs(moduleHooks) do
    hooks[h] = function(mh, ...)
      for _, m in ipairs(ms) do
        local status, err, res = xpcall(m[h], debug.traceback, m, ...)
        if not status then
          self:logEvent("Error with hook  " .. dumps(h), "E", 'Error while executing Hook ' .. dumps(h) .. ": " .. tostring(err))
        end
      end
    end
  end
  table.insert(hookList, hooks)
  --dumpz(hookList, 2)
  -- put all the nodes in there (if not in there already)
  --[[for _, graph in pairs(self.graphs) do
    if graph.type ~= 'macro' then
      for _, node in pairs(graph.nodes) do
        table.insert(hookList, node)
      end
    end
  end]]
  return hookList
end

function C:getDependencies()
  if self.runningState ~= "running" then
    return {}
  end
  local depKeys = {}
  for _, graph in pairs(self.graphs) do
    if graph.type ~= 'macro' then
      for _, node in pairs(graph.nodes) do
        for _, dep in ipairs(node.dependencies or {}) do
          depKeys[dep] = true
        end
      end
    end
  end
  for _, m in pairs(self.modules) do
    for _, dep in ipairs(m.dependencies or {}) do
      depKeys[dep] = true
    end
  end

  local deps = {}
  for k, _ in pairs(depKeys) do
    table.insert(deps, k)
  end
  table.sort(deps)
  return deps
end

function C:checkCompileWarnings()
  local dualColorChecked = {}
  for _, graph in pairs(self.graphs) do
    for _, node in pairs(graph.nodes) do
      local chk = node._flowColors
      local insert = {}
      local triggerNodes = {}
      for i, c in pairs(chk) do
        table.insert(insert, i.id)
        table.insert(triggerNodes, i)
      end
      if #insert > 1 then
        local contained = false
        for _, dc in ipairs(dualColorChecked) do
          local same = true
          for idx, id in ipairs(dc) do
            same = same and id == insert[idx]
          end
          if same then
            contained = true
            break
          end
        end
        if not contained then
          local warning = 'Multiple root nodes for a section of this graph detected.\nThe following nodes share nodes which they will reach:\n'
          for _, nd in ipairs(triggerNodes) do
            warning = warning .. " - " .. nd:toString() .. "\n"
          end
          warning = warning .. "Please only use one triggering node for each group of nodes in your project."
          log('E', 'flowEditor', warning)
          table.insert(dualColorChecked, insert)
        end
      end
      table.insert(dualColorChecked, {})
    end
  end
end

function C:setRunning(running, stopInstant)
  self.stopRunningOnClientEndMission = false -- default disabled, will be enabled when started as scenario
  local oldState = self.runningState
  self.runningState = running and "running" or "stopped"
  self.allowEditing = not running --and self.graph.type ~= 'instance'
  self.extProxy:submitEventSinks(self:getHooklist(), self:getDependencies())
  extensions.refresh('core_flowgraphManager')
  if running then
    table.clear(self.events)
    table.clear(self.eventDuplicateCheck)
    self.startTime = Engine.Platform.getRuntime()
    extensions.load('core_trailerRespawn')
    core_trailerRespawn.setEnabled(false)
    self:logEvent("Project Started", nil, "The Project has been started.")
    self.groupedEvents = {}
    self.gcprobe_enabled = false
    if editor and editor.getPreference and editor.getPreference("flowgraph.debug.debugGarbage") then
      log("I","","Garbage Debug is enabled for Flowgraph " .. self.name .. " (" ..self.id..")")
      self.gcprobe_enabled = true
    end
    self.garbageData = nil
    for _, g in pairs(self.graphs) do
      if g.parentId == nil then
        g:plan()
        --if self.fgEditor ~= nil and self.fgEditor.mgr == self then
        self:checkCompileWarnings()
        --end
      end
    end
    self.states:buildStates()
    if oldState == 'stopped' then
      self:_executionStarted()
      self:broadcastCall("onExecutionStarted")
    end
    self.states:startAutoStartStates()
  else
    if oldState ~= 'stopped' then
      --[[
      for _, graph in pairs(self.graphs) do
        for _, node in pairs(graph.nodes) do
          if node.changedRunningState then
            node:changedRunningState('stopped')
          end
        end
      end
      -- replaced by broadscastCall below - to be tested
      ]]
      self:broadcastCall("onRemoveNextFrame")
      if self.removeOnStopping then
        core_flowgraphManager.removeNextFrame(self)
      end
      if stopInstant then
        log("E", "", "Stopping instantly!")
        self:_executionStopped()
        --self:_onClear()
        self:destroy()
      else
        -- queueing reset so it is reset at the END of the frame
        self.queueReset = true
      end

      core_trailerRespawn.setEnabled(true)
      self:logEvent("Project Stopped", nil, "The Project has been stopped.")
    end
  end
  if oldState == 'stopped' and running then
  end
  self.blocksOnResetGameplayCache = nil
end

function C:setPaused(paused)
  if self.runningState == "stopped" then
    return
  end
  self.runningState = paused and "paused" or "running"
  self.extProxy:submitEventSinks(self:getHooklist())


end

function C:queueForRestart()
  self.queueRestart = true
end

function C:_executionStarted()
  if self.graph.type == 'macro' and self.recentInstance and self.recentInstance.macroID == self.graph.id then
    self.graph = self.recentInstance
    self.focusGraph = self.recentInstance
  end

  for _, graph in pairs(self.graphs) do
    graph:_executionStarted()
  end
  for _, mod in ipairs(self.moduleOrder) do
    self.modules[mod]:executionStarted()
  end
end

function C:_onClear()

  for _, graph in pairs(self.graphs) do
    graph:_onClear()
  end
  self.variables:_onClear()
  for _, mod in ipairs(self.moduleOrder) do
    self.modules[mod]:onClear()
  end
  self.states:clear()
end

function C:_executionStopped()
  self.garbageData = {
      graphs = {},
      nodes = {},
      frames = self.frameCount
    }
  for grId, graph in pairs(self.graphs) do
    graph:_executionStopped()
    self.garbageData.graphs[grId] = graph.gcprobeTable
    for nId, entry in pairs(graph.gcprobeTable.entries or {}) do
      self.garbageData.nodes[nId] = entry
      --self.garbageData.nodes[nId].graphId = grId
    end
  end
  self.variables:_executionStopped()
  for _, mod in ipairs(self.moduleOrder) do
    self.modules[mod]:executionStopped()
  end
  core_flowgraphManager.runningProxies[self.extProxy.extName] = nil
  self.states:clear()

  for _, ext in ipairs(self.extToUnload or {}) do
    extensions.unload(ext)
  end
  self.extToUnload = {}

  self.steps = 0
  self.frameCount = 0
end

function C:destroy()
  if self.runningState ~= 'stopped' then
    self:_executionStopped()
    self:_onClear()
    self:setRunning(false)
  end

  self.states:destroy()
  core_flowgraphManager.runningProxies[self.extProxy.extName] = nil
  core_flowgraphManager.refreshDependencies()
  extensions.refresh('core_flowgraphManager')
  self.extProxy:destroy()
  self.destroyed = true
end

function C:getGraphByName(name)
  for _, gr in pairs(self.graphs) do
    if gr.name == name then
      return gr
    end
  end
  return nil
end

function C:resolveVariableChanges()
  self.variables:finalizeChanges()
  for _, graph in pairs(self.graphs) do
    graph.variables:finalizeChanges()
  end
end

function C:broadcastCall(functionName, ...)
  if self.runningState == "running" then
    if self.extProxy and self.extProxy.hookProxies and self.extProxy.hookProxies[functionName] then
      self.extProxy.hookProxies[functionName](...)
    end
    self.states:broadcastCall(functionName, ...)
  end
end

function C:broadcastCallReturn(functionName, ...)
  local results = {}
  if self.runningState == "running" then
    if self.extProxy and self.extProxy.hookProxies and self.extProxy.hookProxies[functionName] then
      self.extProxy.hookProxies[functionName](results, ...)
    end
    self.states:broadcastCallReturn(functionName, results, ...)
  end
  return results
end

function C:hasNodeForHook(functionName)
  if self.runningState == "running" then
    if self.extProxy and self.extProxy.hookProxies and self.extProxy.hookProxies[functionName] then
      return true
    end
    if self.states and self.states:hasNodeForHook(functionName) then
      return true
    end
  end
  return false
end

local function allNodesIterator(ctx)
  local mgr = ctx.mgr
  local currentGraph = mgr.graphs[ctx.graphIdx]
  local nextNode = next(currentGraph.nodes, ctx.nodeIdx)

  -- if there is no next node, get the next graph's first node until we have one or run out of graphs
  if not nextNode then
    while currentGraph and not nextNode do
      ctx.graphIdx = next(mgr.graphs, ctx.graphIdx)
      currentGraph = mgr.graphs[ctx.graphIdx]
      if currentGraph then
        nextNode = next(currentGraph.nodes)
      end
    end
  end
  -- if we have a nextNode, advance state and return
  if nextNode then
    ctx.nodeIdx = nextNode
    return currentGraph.nodes[nextNode]
  end
  -- end iterator
  return nil
end

function C:blocksOnResetGameplay()
  if self.runningState == 'stopped' then
    return false
  end
  if self.blocksOnResetGameplayCache == nil then
    for node in self:allNodes() do
      if node.data and node.data.blocksOnResetGameplay then
        self.blocksOnResetGameplayCache = true
        return true
      end
    end
    self.blocksOnResetGameplayCache = false
  end
  return self.blocksOnResetGameplayCache
end

function C:allNodes()
  local firstGraph = next(self.graphs)
  if not firstGraph then
    return nop, {}
  end
  return allNodesIterator, {
    mgr = self,
    graphIdx = firstGraph,
    nodeIdx = nil,
  }
end

function C:onClientEndMission()
  if self.stopRunningOnClientEndMission then
    -- this requires the project to be stopped instantly, instead of end of frame.
    self:setRunning(false, true)
  end
end

function C:getRelativeAbsolutePath(p, disableLogEntryOnFail)
  if not p or p == "" then
    return nil
  end
  local paths = p
  if type(p) == 'string' then
    paths = { p }
  end
  local success = false
  local files = {}
  for _, path in ipairs(paths) do
    if path ~= "" then
      table.insert(files, path)
      if self.savedDir then
        table.insert(files, self.savedDir .. path)
      end
      if self.activity and self.activity.missionFolder then
        table.insert(files, self.activity.missionFolder .. "/" .. path)
      end
    end
  end
  for _, path in ipairs(files) do
    if FS:fileExists(path) then
      return path, true
    end
  end
  if not disableLogEntryOnFail then
    log("E", "", "Unable to locate file for flowgraph " .. dumps(self.name) .. ", in neither of these paths: " .. dumps(files))
  end
  return files[1], false
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end