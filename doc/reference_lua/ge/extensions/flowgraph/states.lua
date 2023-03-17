-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
local im  = ui_imgui


function C:init(mgr)
  self.mgr = mgr
  self.states = {}
  self.queuedTransitions = {}
  self.hookExists = {}
  self.resolveExtProxy = nil
end

function C:destroy()
  self:clear()
end

function C:clear()
  --print("Clearing states and killing ext proxies")
  --print(debug.tracesimple())
  if self.resolveExtProxy then
    core_flowgraphManager.runningProxies[self.resolveExtProxy.extName] = nil
    core_flowgraphManager.refreshDependencies()
    self.resolveExtProxy:submitEventSinks({},{})
    self.resolveExtProxy:destroy()
  end
  self.resolveExtProxy = nil

  for name, state in pairs(self.states) do
    -- clear extProxy
    if state.extProxy then
      core_flowgraphManager.runningProxies[state.extProxy.extName] = nil
      core_flowgraphManager.refreshDependencies()
      state.extProxy:submitEventSinks({},{})
      state.extProxy:destroy()
    end
  end
  core_flowgraphManager.refreshDependencies()
  extensions.refresh('core_flowgraphManager')
  self.states = {}
  self.hookExists = {}
end


function C:getTransitions(node)
  local stateGraph = node.graph
  local transitions = {}
  -- find all links that have our node as the source node.
  for id, link in pairs(stateGraph.links) do
    if link.sourceNode.id == node.id then
      local transitionName = link.sourcePin.name
      if transitions[transitionName] == nil then transitions[transitionName] = {} end
      table.insert(transitions[transitionName], {targetName = link.targetNode.name, link = link})
    end
  end
  table.sort(transitions)
  return transitions
end

-- adds a state to this states list. states always are based on a graph.
function C:addStateFromPortedNode(pnode)
  --dump("Creating State: " .. node.targetGraph.name)
  local node = pnode.node
  local state = {
    id = node.id,
    depth = pnode.depth,
    graph = node.targetGraph,
    name = node.name,
    autoStart = pnode.startingState or false,
    extProxy = newExtensionProxy(nil, self.mgr.extProxy.extName.."_state_"..node.name .. "-"..node.id),
    active = false,
    ports = pnode.ports or {},
    transitionStack = {},
  }
  core_flowgraphManager.runningProxies[state.extProxy.extName] = true
  state.extProxy:submitEventSinks({},{})
  -- plan the graph
  --dumpz(pnode, 2)
  if not node.targetGraph then
    node:__setNodeError("E","No target graph?=")
    node.targetGraph:plan()
  end
  -- get all hooks and dependencies for the extProxy
  local hooks, kDeps = node.targetGraph:getRecursiveHooksAndDependencies({}, {})
  local deps = {}
  for k, i in pairs(kDeps) do
    table.insert(deps, k)
  end
  table.insert(deps, self.mgr.extProxy.extName)
  state.extHooks = hooks
  state.extDeps = deps
  -- find all hooks of all nodes in hooks.
  for _, node in ipairs(hooks) do
    for k, func in pairs(node) do
      if string.sub(k, 1, 2) == 'on' and type(func) == 'function' then
        self.hookExists[k] = true
      end
    end
  end

  self.states[node.id] = state
  node.targetGraph.state = state
  log("D","","Added state " .. state.name)
end

function C:startAutoStartStates()
  for name, state in pairs(self.states) do
    if state.autoStart then
      self:startState(state.id)
    end
  end
end

function C:startState(id, transData)
  local state = self.states[id]
  if not state then log("E","","Could not find state to start: " .. dumps(id)) return end
  local name = "State ".. state.name.."/"..id
  state.extProxy:submitEventSinks(state.extHooks, state.extDeps)
  log("D","","Starting state. Calling onStateStarted: " ..name)
  if state.extProxy.hookProxies.onStateStarted then
    state.extProxy.hookProxies.onStateStarted(state)
  end
  log("D","","Calling onStateStartedTrigger for: " ..name)
  if state.extProxy.hookProxies.onStateStartedTrigger then
    state.extProxy.hookProxies.onStateStartedTrigger(state)
  end
  state.active = true
  log("D","","State has been started: " ..name)
  self.mgr:logEvent("State started: " ..state.name,"S","The state "..name.. " has been started.\n - Transition Stack data added: " .. dumps(transData).."\n - Stack: " .. dumpsz(state.transitionStack,2),{type = 'graph',graph = state.graph})
end

function C:stopState(id)
  local state = self.states[id]
  if not state then log("E","","Could not find state to stop: " .. dumps(id)) return end
  local name = "State ".. state.name.."/"..id
  log("D","","Stopping state. Calling onStateStopped: " .. name)
  if state.extProxy.hookProxies.onStateStopped then
    state.extProxy.hookProxies.onStateStopped(state)
  end
  log("D","","Calling onStateStoppedTrigger for: " ..name)
  if state.extProxy.hookProxies.onStateStoppedTrigger then
    state.extProxy.hookProxies.onStateStoppedTrigger(state)
  end
  state.extProxy:submitEventSinks({},{})
  state.active = false
  log("D","","State has been stopped: " .. name)
  self.mgr:logEvent("State stopped: " ..state.name,"S","The state "..name.. " has been stopped.", {type = 'graph',graph = state.graph})
end

function C:gatherNodesAndLinks()
  self:clear()
  self.stateGraph = self.mgr.stateGraph
  local nodes, links, group = {},{},{}
  C:gatherNodesAndLinksRecursion(self.stateGraph, nodes, links, group, {})
  return nodes, links, group
end

function C:gatherNodesAndLinksRecursion(graph, nodes, links, group, depth)
  -- find out if there is a connection from the entry node to any exit node. if so, this subgraph is invalid.
  for _, link in pairs(graph.links) do
    if link.sourceNode.nodeType == "states/stateEntry" and link.targetNode.nodeType == "states/stateExit" then
      log("E","","Connection fron Entry to Exit detected. This groupstate is invalid and will be ignored completely. " .. dumps(graph.name))
      return
    end
  end
  local currentDepth = deepcopy(depth)
  table.insert(currentDepth, graph.id)
  for _, node in pairs(graph.nodes) do
    if node.nodeType ~= 'debug/comment' then
    --print(node.nodeType)
      -- gather additional data per node.
      local elem = {
        node = node,
        depth = deepcopy(currentDepth)
      }

      -- store all groupstate nodes for quick reference
      if node.targetGraph and node.targetGraph.isStateGraph then
        group[node.id] = elem
        -- mark elem als no really a state
        elem.isConnector = true
        elem.targetGraph = node.targetGraph

      end

      --if it's an IO-node, find the parent graph
      if node.nodeType == 'states/stateEntry' or node.nodeType == 'states/stateExit' then
        -- mark elem als no really a state
        elem.isConnector = true
        local parent = nil
        for id, nd in pairs(group) do
          if nd.targetGraph.id == node.graph.id then
            parent = nd
          end
        end
        -- there might be no parent, if this is the root graph.
        if parent then
          elem.parentGraph = parent
          elem.parent = parent
          if node.nodeType == 'states/stateEntry' then
            parent.entry = elem
          --else
          --  parent.exit = elem
          end
        else
          elem.isRoot = true
          if node.nodeType == 'states/stateExit' then
            elem.stopProjectWhenReached = true
            elem.isConnector = false
          end
        end
      end

    nodes[node.id] = elem
    end
  end


  for _, link in pairs(graph.links) do
    local elem = {
      link = link,
      simple = 'from ' .. link.sourceNode.id.." to " .. link.targetNode.id,
      depth = deepcopy(currentDepth)
    }
    --flag this link for shortening, if it connects to any connector node.
    if   link.sourceNode.nodeType == 'states/stateEntry'
      or link.targetNode.nodeType == 'states/stateExit'
      or (link.sourceNode.targetGraph and link.sourceNode.targetGraph.isStateGraph)
      or (link.targetNode.targetGraph and link.targetNode.targetGraph.isStateGraph) then
        elem.doShorten = true
    end
    table.insert(links, elem)
  end

  for _, child in ipairs(graph:getChildren()) do self:gatherNodesAndLinksRecursion(child, nodes, links, group, deepcopy(currentDepth)) end
end

function C:resolveInterHops(nodes, links, group)
  --dumpz(nodes, 2)
  -- first, sort links into lists of regular, and to-be-shortened links. further split the to-be-shortened into source-connected and others.
  local regular, shorten, sourced = {},{},{}
  for _, lnk in ipairs(links) do
    if lnk.doShorten then
      -- shorten all links who'se source is a connector, but not the root node
      if nodes[lnk.link.sourceNode.id].isConnector and not nodes[lnk.link.sourceNode.id].isRoot then
        table.insert(shorten, lnk)
      else
        table.insert(sourced, lnk)
      end
    else
      table.insert(regular, lnk)
    end
  end
  --dumpz(nodes, 2)
  --dumpz(sourced, 2)
  --dumpz(shorten, 2)
  --dumpz(regular, 2)

  -- now, go over every sourced link, and follow all links to find all ends.
  local virtualLinks = {}
  for _, lnk in ipairs(sourced) do
    --dump("current from sourced: " .. lnk.simple)
    local exitReached = nil
    local stopProjectWhenReached = nil
    local targets = {}
    local open = {lnk}
    local unvisited = shallowcopy(shorten)
    repeat
      local successors = {}
      for _, current in ipairs(open) do
        --dump("current from open: " .. current.simple)
        local currentTargetNode = nodes[current.link.targetNode.id]
        --dumpz(currentTargetNode, 2)
        if currentTargetNode.isConnector then
          --print("case 1")
          -- case 1: the current link points to a connector node. proceed further down the line and save the path.
          -- the node which's connection we need to check is either the exit of the current node, or it's parent.
          local sibling = currentTargetNode.entry or currentTargetNode.parent
          local selected = {}
          local newUnvisited = {}
          for _, unv in ipairs(unvisited) do
            local insert = false
            -- only select links with the appropriate label if we go through an exit node
            if currentTargetNode.node.nodeType == 'states/stateExit' then
              if unv.link.sourceNode.id == currentTargetNode.parent.node.id and unv.link.sourcePin.name == currentTargetNode.node.transitionName then
                table.insert(selected, unv)
                insert = true
              end
              exitReached = currentTargetNode
            else
              -- if we go through the groupstate node, pick the links from the entry-node
              if unv.link.sourceNode.id == currentTargetNode.entry.node.id then
                table.insert(selected, unv)
                insert = true
              end
            end

            -- if not inserted, put into new unvisited list.
            if not insert then
              table.insert(newUnvisited, unv)
            end
          end
          unvisited = newUnvisited

          for _, sel in ipairs(selected) do
            --dump("Found sel! " .. sel.simple)
            table.insert(successors, sel)
          end
        else
          -- case 2: the current link is pointing to a non-connector (eg state) node. add to targets with path.
          --print("case 2")
          stopProjectWhenReached = currentTargetNode.stopProjectWhenReached and currentTargetNode.node.id or nil
          table.insert(targets, current.link.targetNode)
        end
      end
      open = successors
    until #open == 0
    -- now we have filled the targets list. add one virtual links for each target.
    for _, tgt in ipairs(targets) do
      local vlnk = {
        link = {
          sourcePin = lnk.link.sourcePin,
          sourceNode = lnk.link.sourceNode,
          targetNode = tgt,
        },
        virtual = true,
        exitPassed = exitReached,
        stopProjectWhenReached = stopProjectWhenReached
      }
      --dumpz(vlnk, 2)
      table.insert(regular, vlnk)
    end
  end
  -- return the final list of flattened links.
  return regular
end

function C:buildPortsAndStarts(nodes, links)
  -- go through all links and place them in the nodes ports list.
  -- ports list should be lightweight as possible.

  for _, lnk in ipairs(links) do
    local pName = lnk.link.sourcePin.name
    local node = nodes[lnk.link.sourceNode.id]
    if not node.ports then node.ports = {} end
    if not node.ports[pName] then node.ports[pName] = {targets = {}, stopDepth = lnk.exitPassed and lnk.exitPassed.depth, stopProjectWhenReached = lnk.stopProjectWhenReached} end
    table.insert(node.ports[pName].targets, lnk.link.targetNode.id)
  end

  -- find all valid nodes.
  local validNodes = {}
  for id, node in pairs(nodes) do
    if not node.isConnector then
      validNodes[id] = node
    end
  end

  -- find root nodes for starting
  local rootNodes = {}
  for id, node in pairs(nodes) do
    if node.isRoot then
      table.insert(rootNodes, node)
    end
  end
  for _, root in ipairs(rootNodes) do
    for name, port in pairs(root.ports or {}) do
      for _, targetId in ipairs(port.targets) do
        validNodes[targetId].startingState = true
      end
    end
  end

  return validNodes
end

function C:buildStates()

  -- put all nodes, links and group-infos into flat lists
  local allNodes, allLinks, groupInfo = self:gatherNodesAndLinks()
  local shortedLinks = self:resolveInterHops(allNodes, allLinks, groupInfo)
  self._interHopData = shortedLinks
  local portedNodes = self:buildPortsAndStarts(allNodes, shortedLinks)

  -- now that the heavy work is done, we can build the actual states :)
  for id, node in pairs(portedNodes) do
    if not node.stopProjectWhenReached then
      self:addStateFromPortedNode(node)
    end
  end

  -- build the state resolver ext proxy.
  self.resolveExtProxy = newExtensionProxy(nil, self.mgr.extProxy.extName.."_StateResolver")
  local deps = {}
  for id, state in pairs(self.states) do
    table.insert(deps, state.extProxy.extName)
    --dump(state.id .. dumps(state.ports))
  end
  self.resolveExtProxy:submitEventSinks({{
    onUpdate = function()
      if self.mgr.runningState == 'running' then
        self:resolveTransitions()
      end
    end
  }},deps)
  core_flowgraphManager.runningProxies[self.resolveExtProxy.extName] = true
  core_flowgraphManager.refreshDependencies()
  extensions.refresh('core_flowgraphManager')
  --extensions.printHooks('onUpdate')
end

function C:getTransitionStack(id)
  return self.states[id] and self.states[id].transitionStack or {}
end

function C:getStateIdForNode(node)
  for id, state in pairs(self.states) do
    if state.graph.id == node.graph:getRootGraph().id then return id end
  end
  return -1
end

function C:getStateNode(id)
  return self.states and self.states[id] and self.states[id].node
end

function C:getStateNodeByNode(node)
  log("E","","Deprecated getStateNodeByNode")
end


function C:findStateNodeInStateGraph(targetGraphId)
  return self:findStateNodeInStateGraphRecursive(self.mgr.stateGraph, targetGraphId)
end

function C:findStateNodeInStateGraphRecursive(graph, id)
  for _, node in pairs(graph.nodes) do
    if node.nodeType == 'states/stateNode' and node.targetGraph and node.targetGraph.id == id then return node end
  end
  local ret = nil
  for _, child in pairs(graph:getChildren()) do
    if not ret then
      ret = self:findStateNodeInStateGraphRecursive(child,id)
    end
  end
  return ret
end

-- queues a transition that will be resolved at the end of the frame.
function C:transition(sourceStateId, transitionName, transitionData, sourceNode)
  log("D","","Transition: " .. sourceStateId .." -> " .. transitionName)
  local sourceStateName = self.states[sourceStateId].name
  self.mgr:logEvent("Transition ("..sourceStateName.." / " ..transitionName..")","T","A Transition from the State " .. sourceStateName.. " with the transitionName " .. transitionName .. " has been triggered.",sourceNode and {type = 'node',node = sourceNode})
  table.insert(self.queuedTransitions, { sourceStateId = sourceStateId, transitionName = transitionName, transitionData = transitionData, mode = "transition"})

end

function C:resolveTransitions()

  local offStates, onStates = {}, {}
  local offSorted, onSorted = {}, {}
  local stopProject = false
  -- find out all states that need to be turned on/off over all transitions.
  for _, t in ipairs(self.queuedTransitions) do
    log("D","",string.format("Resolving %d -> %s", t.sourceStateId or -1, t.transitionName or ""))
    local sourceState = self.states[t.sourceStateId]
    if not sourceState then
      log("E","","Could not find source state for transition: " .. dumpsz(t,3))
    else
      local port = sourceState.ports[t.transitionName] or { targets = {}}
      if #port.targets == 0 then log("W","","Empty Port for transition: " .. dumpsz(t,3)) end
      for _, targetId in ipairs(port.targets) do
        --tData.link:doFlow()
        if not onStates[targetId] then
          if self.states[targetId] then
            onStates[targetId] = {true, t.transitionData or {}, sourceState.transitionStack or {}}
            table.insert(onSorted, targetId)
          end
        end
      end
      if t.mode == 'transition' then
        if not offStates[sourceState.id] then
          offStates[sourceState.id] = {true}
          table.insert(offSorted, sourceState.id)
        end
      end
      if port.stopDepth then
        local ids = self:getStateIdsForDepth(port.stopDepth)
        log("D","","Exiting groupstate. Stopping these states: " .. dumps(ids) .. " because of stopdepth: " .. dumps(port.stopDepth))
        for _, id in ipairs(ids) do
          if not offStates[id] then
            offStates[id] = {true}
            table.insert(offSorted, id)
          end
          onStates[id] = nil
        end
      end
      if port.stopProjectWhenReached then
        stopProject = port.stopProjectWhenReached
      end
    end
  end
  -- toggle the states.
  table.sort(offSorted)
  table.sort(onSorted)
  for _, id in ipairs(offSorted) do
    self:stopState(id)
  end
  for _, id in ipairs(onSorted) do
    if onStates[id] then
      if onStates[id][2] or onStates[id][3] then
        log("D","","Adding to transition stack of " .. dumps(self.states[id].name).."/"..dumps(id)..":")
        for key, val in pairs(onStates[id][3] or {}) do
          self.states[id].transitionStack[key] = val
        end
        for key, val in pairs(onStates[id][2] or {}) do
          self.states[id].transitionStack[key] = val
        end
        log("D","",dumpsz(self.states[id].transitionStack, 2))
      end
      self:startState(id, transData)
    end
  end

  if stopProject then
    if #onSorted > 0 then
      self.mgr:logEvent("Aborted Project Stopping","S","A final StateExit node has been reached, but in the same frame, another state has been started. Thus, the project was not stopped.",{type = 'node',node = self.mgr.stateGraph.nodes[stopProject]})
    else
      self.mgr:logEvent("Reached End-State","S","A final StateExit node has been reached, the project was stopped.",{type = 'node',node = self.mgr.stateGraph.nodes[stopProject]})
      self.mgr:setRunning(false)

    end
  end

  -- clear the transition list.
  table.clear(self.queuedTransitions)
end

function C:getStateIdsForDepth(depth)
  if not depth or #depth == 0 then return {} end
  local lastId = depth[#depth]
  local ids = {}
  for id, state in pairs(self.states) do
    if tableContains(state.depth, lastId) then
      table.insert(ids, id)
    end
  end
  return ids
end


function C:broadcastCall(functionName, ...)
  for id, state in pairs(self.states) do
    if state.extProxy and state.extProxy.hookProxies and state.extProxy.hookProxies[functionName] then
      state.extProxy.hookProxies[functionName](...)
    end
  end
end

function C:broadcastCallReturn(functionName, results, ...)
  for id, state in pairs(self.states) do
    if state.extProxy and state.extProxy.hookProxies and state.extProxy.hookProxies[functionName] then
      state.extProxy.hookProxies[functionName](results, ...)
    end
  end
end


function C:hasNodeForHook(functionName)
  return self.hookExists[functionName]
end

function C:isRunning(id)
  return self.states[id] and self.states[id].active or false
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end