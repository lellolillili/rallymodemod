-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
-- data holding and computation 'class'
local im = ui_imgui

local debug_work_order = nil

local optick_enabled = false
local optick_grouping = "type" -- "type", "individual"

local gcprobe_grouping = "individual" -- "type", "individual"

local ffi = require('ffi')
local logTag = "fg_graph"

function C:init(mgr, name, forceId)
  self.mgr = mgr
  self.id = forceId or mgr:getNextFreeGraphNodeId()
  if mgr.__safeIds then
    if mgr:checkDuplicateId(self.id) then
      log("E", "", "Duplicate ID error! Graph")
      print(debug.tracesimple())
    end
  end
  self.name = name or ("Graph " .. self.id)
  self.type = "graph" -- graph, macro or instance
  --self.parent = nil
  --self.children = {}
  self.parentId = nil
  self.showTab = im.BoolPtr(true)
  self.dirty = true
  self.description = "This is the description for graph " .. self.name
  self.onUpdateNodeId = nil

  -- unique id / object dicts
  self.nodes = {}
  self.links = {}
  self.pins = {}

  self.variables = require('/lua/ge/extensions/flowgraph/variableStorage')(self.mgr)

  self.hookList = {}

  self.gcprobeTable = {
    total = 0,
    history = {},
    entries = {},
    totalHistory = {}
  }

  self._replan = true
  self.viewPos = im.ImVec2Ptr(-200, -200)
  self.viewZoom = im.FloatPtr(1)
end

function C:getParent()
  return self.mgr.graphs[self.parentId]
end

local function idSort(a, b)
  return a.id < b.id
end
function C:getChildren()
  local children = {}
  for _, gr in pairs(self.mgr.graphs) do
    if gr.parentId == self.id then
      table.insert(children, gr)
    end
  end
  table.sort(children, idSort)
  --dump(children)
  return children
end

function C:clearVariableChangesChildren()
  self.variables.variableChanges = {}
  for _, child in ipairs(self:getChildren()) do
    child:clearVariableChangesChildren()
  end
end

function C:getRootGraph()
  local ret = self
  while ret and ret:getParent() do
    ret = ret:getParent()
  end
  return ret
end

function C:getDirtyChildren(dirtyChildren)
  if dirtyChildren == nil then
    dirtyChildren = {}
  end

  for _, child in ipairs(self:getChildren()) do
    if child.type == "instance" and child.macroID then
      if self.mgr.macros[child.macroID].dirty then
        dirtyChildren[child.macroID] = true
      end
    end
    child:getDirtyChildren(dirtyChildren)
  end

  return dirtyChildren
end

function C:setDirty(dirty, startFromRoot)
  if startFromRoot == nil then
    startFromRoot = true
  end
  if startFromRoot then
    local root = self:getRootGraph()
    root:setDirty(dirty, false)
    return
  end

  self.dirty = dirty
  for _, child in ipairs(self:getChildren()) do
    if child.type == self.type then
      child:setDirty(dirty, false)
    end
  end
end

function C:gatherNodesAndLinks(rNodes, rLinks, interInfo)
  local integratedNodes = {}

  -- collect all nodes and additionally put all integrated nodes into a second list.
  for _, node in pairs(self.nodes) do
    if node.nodeType == 'macro/integrated' then
      table.insert(integratedNodes, node)
    end
    table.insert(rNodes, node)
  end
  -- gather all links which are not connected to neither an integrated node nor an IO node.
  for _, link in pairs(self.links) do
    if not (link.sourceNode.nodeType == 'macro/integrated' or link.sourceNode.nodeType == 'macro/io'
            or link.targetNode.nodeType == 'macro/integrated' or link.targetNode.nodeType == 'macro/io') then
      table.insert(rLinks, link)
    end
  end

  -- add custom links for integrated nodes
  for _, iNode in ipairs(integratedNodes) do
    interInfo[iNode] = { inLinks = {}, outLinks = {} }
    if iNode.inputNode then
      interInfo[iNode.inputNode] = {}
    end
    if iNode.outputNode then
      interInfo[iNode.outputNode] = {}
    end

    for id, link in pairs(iNode.graph.links) do
      if link.targetNode == iNode then
        if interInfo[iNode].inLinks[link.targetPin.name] == nil then
          interInfo[iNode].inLinks[link.targetPin.name] = {}
        end
        table.insert(interInfo[iNode].inLinks[link.targetPin.name], link)
      elseif link.sourceNode == iNode then
        if interInfo[iNode].outLinks[link.sourcePin.name] == nil then
          interInfo[iNode].outLinks[link.sourcePin.name] = {}
        end
        table.insert(interInfo[iNode].outLinks[link.sourcePin.name], link)
      end
    end
    -- get links in target graph that connect from either i/o node
    for id, link in pairs(iNode.targetGraph.links) do
      if link.sourceNode == iNode.inputNode then
        if interInfo[iNode.inputNode][link.sourcePin.name] == nil then
          interInfo[iNode.inputNode][link.sourcePin.name] = {}
        end
        table.insert(interInfo[iNode.inputNode][link.sourcePin.name], link)
      elseif link.targetNode == iNode.outputNode then
        if interInfo[iNode.outputNode][link.targetPin.name] == nil then
          interInfo[iNode.outputNode][link.targetPin.name] = {}
        end
        table.insert(interInfo[iNode.outputNode][link.targetPin.name], link)
      end
    end

  end

  --if self.children then
  for _, child in ipairs(self:getChildren()) do
    child:gatherNodesAndLinks(rNodes, rLinks, interInfo)
  end
  -- end
end

function C:resolveInterHops(rLinks, interInfo)
  -- find all links whose source node is not an integrated nor an IO node.
  -- all other links go into the other list.
  -- build linklist per node.
  local linkList = {}
  local sourceLinks = {}
  local allLinks = {}
  for node, list in pairs(interInfo) do
    if node.nodeType == "macro/integrated" then
      for pinName, lnkList in pairs(list.inLinks) do
        for _, link in ipairs(lnkList) do
          if link.sourceNode.nodeType ~= 'macro/integrated' and link.sourceNode.nodeType ~= 'macro/io' then
            table.insert(sourceLinks, link)
          end
        end
      end
    elseif node.nodeType == "macro/io" and node.ioType == "out" then
      for pinName, lnkList in pairs(list) do
        for _, link in ipairs(lnkList) do
          if link.sourceNode.nodeType ~= 'macro/integrated' and link.sourceNode.nodeType ~= 'macro/io' then
            table.insert(sourceLinks, link)
          end
        end
      end
    end
  end

  -- for every source link, follow the links / integrated->io connections
  -- create links for every integrated or regular node reached.
  for _, sLink in ipairs(sourceLinks) do
    local targets = {}
    local open = { { sLink, sLink.sourcePin.name } }
    local unvisited = shallowcopy(allLinks)

    repeat
      local successors = {}
      for _, oPair in ipairs(open) do
        local current = oPair[1]
        -- insert target of current link into targets list
        table.insert(targets, { current.targetNode, current.targetPin })
        if interInfo[current.targetNode] ~= nil then
          --if we reach a node which we have info on
          --find counter part and add outgoing links from the same pin to successors list
          if current.targetNode.nodeType == 'macro/integrated' then
            if interInfo[current.targetNode.inputNode] then
              for _, lnk in ipairs(interInfo[current.targetNode.inputNode][current.targetPin.name] or {}) do
                table.insert(successors, { lnk, current.targetPin.name })
              end
            end
          elseif current.targetNode.nodeType == 'macro/io' then
            if interInfo[current.targetNode.integratedNode] then
              for _, lnk in ipairs(interInfo[current.targetNode.integratedNode].outLinks[current.targetPin.name] or {}) do
                table.insert(successors, { lnk, current.targetPin.name })
              end
            end
          end
        end
      end
      open = successors
    until #open == 0

    for _, tgt in ipairs(targets) do
      table.insert(rLinks, {
        targetNode = tgt[1],
        targetPin = tgt[2],
        sourceNode = sLink.sourceNode,
        sourcePin = sLink.sourcePin,
        virtualLink = true
      })
      --print("Connecting intergraph pins: " .. sLink.sourcePin.id .. " -> " .. tgt[2].id)
    end
  end
end

function C:plan()
  if self.type == "macro" then
    return
  end
  if self.parentId ~= nil then
    return
  end
  --if not self._replan then return end
  self._replan = false

  self.gcprobeTable = {
    total = 0,
    history = {},
    entries = {},
    totalHistory = {}
  }

  local nodeDeps = {}

  local outDict = {}
  local outList = {}
  local noflowList = {}

  -- make list of all nodes and links in this and all children graphs
  local allNodes = {}
  local allLinks = {}
  local interInfo = {}
  self:gatherNodesAndLinks(allNodes, allLinks, interInfo)
  self:resolveInterHops(allLinks, interInfo)

  if self.mgr.gcprobe_enabled then
    for id, node in pairs(allNodes) do
      if gcprobe_grouping == 'type' then
        self.gcprobeTable.entries[node.nodeType] = self.gcprobeTable.entries[node.nodeType] or {graphId = node.graph.id, count = 0, total = 0, history = {}, totalHistory = {}}
        self.gcprobeTable.entries[node.nodeType].count = self.gcprobeTable.entries[node.nodeType].count + 1
      elseif gcprobe_grouping == 'individual' then
        self.gcprobeTable.entries[node.id] = {graphId = node.graph.id, count = 1, total = 0, history = {}, totalHistory = {}}
      end
    end
  end

  for _, node in ipairs(allNodes) do
    table.clear(node._mInFlow)
    table.clear(node._mInFlowPins)
  end

  local outNodeIdx = {}
  local nodeInFlows = {}
  for _, link in pairs(allLinks) do
    local tPin = link.targetPin
    local tnode = link.targetNode

    -- build internal many-flow pins
    if tPin.type == 'flow' and tnode ~= nil then
      if tnode._mInFlow[tPin.name] == nil then
        tnode._mInFlow[tPin.name] = {}
      end
      table.insert(tnode._mInFlow[tPin.name], link.sourcePin)
    end
    if link.virtualLink then
      rawset(link.targetNode.pinIn, link.targetPin.name, link.sourceNode.pinOut[link.sourcePin.name])
    end

    -- build output link map (to the right)
    if outNodeIdx[link.sourcePin] == nil then
      outNodeIdx[link.sourcePin] = {}
    end
    outNodeIdx[link.sourcePin][link.targetNode] = 1

    -- build input flow map (flow to the left)
    if link.sourcePin.type == 'flow' then
      if nodeInFlows[link.targetNode] == nil then
        nodeInFlows[link.targetNode] = {}
      end
      table.insert(nodeInFlows[link.targetNode], link.sourcePin)
    end
  end

  for id, node in pairs(allNodes) do
    table.clear(node._flowColors)
    node._uncolored = false

    local deplist = {}
    local depdict = {}
    node._triggerCode = nil
    node._trigger = nil
    node._triggerBackup = nil

    -- find root nodes
    if node.triggerable then
      node._flowColors[node] = 1
      table.insert(outList, node)
      outDict[node] = true
    else
      if next(node.pinInLocal) == nil then
        if not node.ignoreAsRoot then
          for _, pin in pairs(node.pinOut) do
            if pin.type == 'flow' then
              node._flowColors[node] = 1
              table.insert(outList, node)
              outDict[node] = true
              break
            end
          end
        end
      end
    end

    -- build dependency map
    for _, pin in pairs(node.pinIn) do
      local parentNode = pin.node
      if parentNode and pin.type ~= 'flow' then
        if depdict[parentNode] == nil then
          depdict[parentNode] = 1
          table.insert(deplist, parentNode)
        end
      end
    end

    for _, mPin in pairs(node._mInFlow) do
      for _, pin in ipairs(mPin) do
        local parentNode = pin.node
        if parentNode then
          if depdict[parentNode] == nil then
            depdict[parentNode] = 1
            table.insert(deplist, parentNode)
          end
        end
      end
    end

    -- find nodes without flow pins
    if next(node._mInFlow) == nil then
      local hasOutFlow = false
      for _, pin in pairs(node.pinOut) do
        if pin.type == 'flow' then
          hasOutFlow = true
          break
        end
      end
      if not hasOutFlow then
        table.insert(noflowList, node)
      end
    end

    nodeDeps[id] = deplist
  end

  local inNodes = shallowcopy(allNodes)
  local flowLevel = 0
  local prevOutCount

  -- resolve input dependencies, propagate colors to the right
  repeat
    prevOutCount = #outList
    for id, node in pairs(inNodes) do
      local depsOk = true
      local ndeps = nodeDeps[id]
      for i = 1, #ndeps do
        if not outDict[ndeps[i]] then
          depsOk = false
          break
        end
      end
      if depsOk then
        for i = 1, #ndeps do
          local dnode = ndeps[i]
          for color, _ in pairs(dnode._flowColors) do
            node._flowColors[color] = 1
          end
        end
        inNodes[id] = nil
        table.insert(outList, node)
        node._flowLevel = flowLevel
        outDict[node] = true
      end
    end
    flowLevel = flowLevel + 1
  until prevOutCount == #outList

  local uncolored = {}
  local uncoloredDict = {}
  -- build uncolored node list, map
  for i = 1, #outList do
    local node = outList[i]
    if next(node._flowColors) == nil then
      node._uncolored = true
      table.insert(uncolored, node)
      uncoloredDict[node] = 1
    end
  end

  -- resolve uncolored nodes by propagating colors to the left
  local colNotPropagated
  repeat
    colNotPropagated = true
    for _, node in ipairs(uncolored) do
      local sourceColor = node._flowColors
      for _, p in pairs(node.pinOut) do
        if outNodeIdx[p] then
          for targetNode, _ in pairs(outNodeIdx[p]) do
            for color, _ in pairs(targetNode._flowColors) do
              if sourceColor[color] == nil then
                colNotPropagated = false
                sourceColor[color] = 1
              end
            end
          end
        end
      end
    end
  until colNotPropagated

  -- build color work lists
  local rootWork = {}
  local rootWorkDict = {}
  local colorInDeps = {}
  local colorOutDeps = {}

  -- propagate color work lists and flow pin link information
  for i = 1, #outList do
    local n = outList[i]
    for pname, mPin in pairs(n._mInFlow) do
      if #mPin > 1 then
        -- add dummy pin for multi-inflows
        n._mInFlowPins[pname] = { value = false, type = 'flow' }

        --[[ n._mInFlowPins[pname] = setmetatable({type = 'flow'},
         { __index = {value = function()
           for _,v in pairs(mPin) do
             print(mPin.value)
             if mPin.value == true then
               return true
             end
           end
           return false
         end}})]]

        n.pinIn[pname] = n._mInFlowPins[pname]
      end
    end

    for color, _ in pairs(n._flowColors) do
      if rootWork[color] == nil then
        rootWork[color] = {}
        rootWorkDict[color] = { [color] = 1 }
      end

      if colorInDeps[color] == nil then
        colorInDeps[color] = {}
      end
      if colorOutDeps[color] == nil then
        colorOutDeps[color] = {}
      end

      if uncoloredDict[n] ~= nil then
        table.insert(rootWork[color], n)
        rootWorkDict[color][n] = 1

        colorOutDeps[color][n] = { [{ { value = true } }] = 1 }
      else
        if colorInDeps[color][n] == nil then
          colorInDeps[color][n] = {}
          colorOutDeps[color][n] = {}
        end
        if next(n.pinIn) ~= nil then
          for _, mPin in pairs(n._mInFlow) do
            for _, pin in ipairs(mPin) do
              if rootWorkDict[color][pin.node] == 1 then
                table.insert(colorInDeps[color][n], pin)
                colorOutDeps[color][pin.node][pin] = 1
              end
            end
          end
          if next(colorInDeps[color][n]) == nil then
            local hasFlowPin = false
            for _, pin in pairs(n.pinInLocal) do
              if pin.type == 'flow' then
                hasFlowPin = true
                break
              end
            end
            if not hasFlowPin then
              table.insert(rootWork[color], n)
              rootWorkDict[color][n] = 1
            end
          end
          if next(colorInDeps[color][n]) ~= nil then
            table.insert(rootWork[color], n)
            rootWorkDict[color][n] = 1
          end
        end
      end
    end
  end

  -- build final worklists
  table.clear(self.hookList)
  for color, orderList in pairs(rootWork) do
    if string.sub(color.name, 1, 2) == 'on' then
      if self.hookList[color.name] == nil then
        self.hookList[color.name] = {}
      end
      table.insert(self.hookList, color)
    end

    for _, p in pairs(color.pinOut) do
      if p.type == 'flow' then
        if p.value == nil then
          p.value = p.default or false
        end
      end
    end

    local arrayInDeps = {}
    local cInDeps = colorInDeps[color]
    local cInDepsDict = {}

    local cOutDeps = colorOutDeps[color]
    local arrayOutDeps = {}

    local tmp = {}
    local tmp1 = {}
    local fun = { 'return function(self)' }

    if self.mgr.gcprobe_enabled then
      table.insert(fun, '\n local currentGarbage, garbageTmp, garbageTotal = {}, 0, 0')
    end

    if optick_enabled then
      table.insert(fun, '\n  profilerPushEvent("' .. string.format("Graph: %s%d", self.name, self.id) .. '")')
    end

    if optick_enabled then
      table.insert(fun, '\n  profilerPushEvent("preTrigger Modules")')
    end
    for _, mod in ipairs(self.mgr.moduleOrder) do
      if self.mgr.modules[mod].preTrigger then
        table.insert(fun, '\n  self.mgr.modules.' .. mod .. ':preTrigger()')
      end
    end
    if optick_enabled then
      table.insert(fun, '\n  profilerPopEvent("preTrigger Modules")')
    end

    for i = 1, #orderList do
      local node = orderList[i]
      local profilerName = "Node"
      if optick_grouping == 'individual' then
        profilerName = string.format("Node: %s%d", node.name, node.id)
      elseif optick_grouping == 'type' then
        profilerName = string.format("Node: %s", node.nodeType)
      end

      node._flowInDeps = node._flowInDeps or {}
      table.clear(node._flowInDeps)
      if optick_enabled then
        table.insert(fun, '\n  profilerPushEvent("' .. profilerName .. '")')
      end


      if cInDeps[node] == nil or next(cInDeps[node]) == nil then
        table.insert(fun, '\n  -- ' .. (node.name or '') .. ': ' .. node.id)
        if debug_work_order then
          table.insert(fun, '\nlog("D","","Work:"..orderList[' .. i .. '].name.."/"..orderList[' .. i .. '].id)')
        end

        -- use the correct work function depending on the node dynamic mode.

        if node.dynamicMode == 'repeat' then
          table.insert(fun, '\n  orderList[' .. i .. ']:_workDynamicRepeat()\n')
        elseif node.dynamicMode == 'once' then
          table.insert(fun, '\n  orderList[' .. i .. ']:_workDynamicOnce()\n')
        end


      else
        table.insert(fun, '\n  -- ' .. (node.name or '') .. ': ' .. node.id)
        table.clear(tmp);
        table.clear(tmp1)
        for _, p in pairs(cInDeps[node]) do
          local pnum = cInDepsDict[p]
          if pnum == nil then
            table.insert(arrayInDeps, p)
            pnum = #arrayInDeps
            cInDepsDict[p] = pnum
          end
          table.insert(tmp1, p.name)
          table.insert(tmp, 'inDeps[' .. pnum .. '].value')
          table.insert(node._flowInDeps, p)
        end
        table.insert(fun, '\n  -- pins: ' .. table.concat(tmp1, ' '))
        table.insert(fun, '\n  if ' .. table.concat(tmp, ' or ') .. ' then')

        -- calculate multi-flow pins
        if next(node._mInFlowPins) ~= nil then
          table.insert(fun, '\n    -- multi-inflow pins')
          for pname, dOutPin in pairs(node._mInFlowPins) do
            table.clear(tmp)
            for _, p in pairs(node._mInFlow[pname]) do
              local pnum = cInDepsDict[p]
              if pnum == nil then
                table.insert(arrayInDeps, p)
                pnum = #arrayInDeps
                cInDepsDict[p] = pnum
              end
              table.insert(tmp, 'inDeps[' .. pnum .. '].value')
              table.insert(node._flowInDeps, p)
            end
            table.insert(arrayOutDeps, dOutPin)
            table.insert(fun, '\n    outDeps[' .. #arrayOutDeps .. '].value=' .. table.concat(tmp, ' or '))
          end
        end

        -- call work
        if debug_work_order then
          table.insert(fun, '\n    log("D","","Work:"..orderList[' .. i .. '].name.."/"..orderList[' .. i .. '].id)')
        end
        if self.mgr.gcprobe_enabled then
          -- before work()
          table.insert(fun, '\n garbageTmp = collectgarbage("count") * 1024 ')
        end
        -- use the correct work function depending on the node dynamic mode.
        if node.dynamicMode == 'repeat' then
          table.insert(fun, '\n    orderList[' .. i .. ']:_workDynamicRepeat()\n')
        elseif node.dynamicMode == 'once' then
          table.insert(fun, '\n    orderList[' .. i .. ']:_workDynamicOnce()\n')
        end
        if self.mgr.gcprobe_enabled then
          -- after
          table.insert(fun, '\n garbageTmp = max(0,collectgarbage("count") * 1024 - garbageTmp)')
          if gcprobe_grouping == 'individual' then
            table.insert(fun, '\n currentGarbage['..node.id..'] = garbageTmp garbageTotal = garbageTotal + garbageTmp')
          end
        end

        -- else cleanup outFlow pins
        if cOutDeps[node] and next(cOutDeps[node]) ~= nil then
          table.clear(tmp)
          for p, _ in pairs(cOutDeps[node]) do
            if p.value == nil then
              p.value = p.default or false
            end
            table.insert(arrayOutDeps, p)
            table.insert(tmp, 'outDeps[' .. #arrayOutDeps .. '].value=false')
          end
          table.insert(fun, '\n  else\n    ' .. table.concat(tmp, ';'))
        end
        table.insert(fun, '\n  end\n')
      end
      if optick_enabled then
        table.insert(fun, '\n  profilerPopEvent("' .. profilerName .. '")')
      end
    end
    -- resolve variable changes
    if optick_enabled then
      table.insert(fun, '\n  profilerPushEvent("afterTrigger Events")')
    end
    table.insert(fun, '\n self.mgr:resolveVariableChanges() \n')

    -- call _afterTrigger for every node in this color
    for i = 1, #orderList do
      local node = orderList[i]
      if type(node._afterTrigger) == 'function' then
        table.insert(fun, '\n  orderList[' .. i .. ']:_afterTrigger()')
      end
    end

    for _, mod in ipairs(self.mgr.moduleOrder) do
      if self.mgr.modules[mod].afterTrigger then
        table.insert(fun, '\n  self.mgr.modules.' .. mod .. ':afterTrigger()')
      end
    end

    if optick_enabled then
      table.insert(fun, '\n  profilerPopEvent("afterTrigger Events")')
      table.insert(fun, '\n  profilerPopEvent("' .. string.format("Graph: %s%d", self.name, self.id) .. '")')
    end
    if self.mgr.gcprobe_enabled then
      if gcprobe_grouping == 'individual' then
        table.insert(fun, '\n  for k, v in pairs(currentGarbage) do\n    gcprobeTable.entries[k].total = (gcprobeTable.entries[k].total or 0) + v\n    gcprobeTable.entries[k].count = (gcprobeTable.entries[k].count or 0) + 1\n    gcprobeTable.entries[k].history[self.mgr.frameCount+1] = v\n    gcprobeTable.entries[k].totalHistory[self.mgr.frameCount+1] = gcprobeTable.entries[k].total end ')
        table.insert(fun, '\n  gcprobeTable.total = gcprobeTable.total + garbageTotal\n  gcprobeTable.history[self.mgr.frameCount+1] = garbageTotal\n  gcprobeTable.totalHistory[self.mgr.frameCount+1] = gcprobeTable.total')
      end
    end

    table.insert(fun, '\nend')

    -- build root/color node trigger function
    local funstr = table.concat(fun)
    --local exprFunc, message = load(funstr, nil, 't', {inDeps = arrayInDeps, outDeps = arrayOutDeps, orderList = orderList})
    local env = { inDeps = arrayInDeps, outDeps = arrayOutDeps, orderList = orderList, log = log }
    if optick_enabled then
      env.profilerPushEvent = profilerPushEvent
      env.profilerPopEvent = profilerPopEvent
    end
    if self.mgr.gcprobe_enabled then
      env.collectgarbage = collectgarbage
      env.max = math.max
      env.pairs = pairs
      env.gcprobeTable = self.gcprobeTable
    end

    local exprFunc, message = load(funstr, "Compiled FG Code for " .. dumps(self.mgr.name) .. " / " .. dumps(color.name), 't', env)
    -- print(message)
    if exprFunc then
      --execute the loaded code in protected mode to catch any non syntax errors
      local success, result = pcall(exprFunc)
      if not success then
        log('E', "flowgraph_graph.trigger.parse", "Trigger function generation failed, message: " .. result)
        color._triggerCode = ''
        color._trigger = nop
      end
      color._triggerCode = funstr
      color._trigger = result
    else
      color._triggerCode = ''
      color._trigger = nop
    end
  end

  --self.mgr:updateNodeHooks(self.hookList)
end

function C:clear()
  if self.type == 'instance' then
    if self.mgr.recentInstance == self then
      self.mgr._recentInstanceRestore = true
    end
  end
  --dumpz(self.children, 2)
  local children = {}
  for _, child in ipairs(self:getChildren()) do
    table.insert(children, child)
  end
  for _, child in ipairs(children) do
    self.mgr:deleteGraph(child)
  end
  --for id, node in pairs(self.nodes) do
  --  if node.nodeType == "macro/integrated" then
  --    self.mgr:deleteGraph(node.targetGraph)
  --  end
  --end
  for _, node in pairs(self.nodes) do
    node:_destroy()
  end
  self.nodes = {}
  self.links = {}
  self.pins = {}
  --self.children = {}
  --self._replan = true
end

function C:createNode(nodeType, forceId, ...)
  local _, lookup = self.mgr:getAvailableNodeTemplates()
  if not lookup[nodeType] then
    log('E', '', 'unable to find node type: "' .. tostring(nodeType) .. '". Available types: ' .. dumps(tableKeys(lookup)))
    return
  end

  local node = lookup[nodeType].create(self.mgr, self, forceId, ...)
  node.nodeType = nodeType
  node.sourcePath = lookup[nodeType].sourcePath
  node.splitPath = lookup[nodeType].splitPath

  -- check legacyPins
  if node.legacyPins then
    node.legacyPins._in = node.legacyPins._in or {}
    node.legacyPins.out = node.legacyPins.out or {}
  end

  -- check obsolete
  if node.obsolete then
    log('W', self.mgr.logTag, 'Node ' .. node.name .. " is obsolete: " .. dumps(node.obsolete))
    node.name = node.name .. " (OBSOLETE)"
  end

  -- store onUpdateNodeId
  if node.nodeType == "events/onUpdate" and not self.onUpdateNodeId then
    self.onUpdateNodeId = node.id
  end

  -- check for auto link for reset pin
  if editor.getPreference and editor.getPreference("flowgraph.general.autoConnectResetPins") -- check if preference is set
          and node.category and ui_flowgraph_editor.isOnceNode(node.category) and node.pinInLocal["reset"] -- check if is once node
          and not forceId                                                      -- don't affect deserialized nodes
          and self.onUpdateNodeId then                                         -- check that there is a onUpdate node

    local enterStatePin = self.nodes[self.onUpdateNodeId].pinOut["enterState"]
    local resetPin = node.pinInLocal["reset"]
    local link = self:createLink(enterStatePin,resetPin)
    link.hidden = true
  end

  self.nodes[node.id] = node
  return node
end

function C:moveNodeToGraph(node, newGraph)
  self.nodes[node.id] = nil
  -- delete any links to it
  for linkId, link in pairs(self.links) do
    if link.sourceNode == node or link.targetNode == node then
      self:deleteLink(link)
    end
  end
  newGraph.nodes[node.id] = node
end

function C:deleteNode(node, ignoreIntegratedNodes)
  if not node or type(node.id) ~= 'number' then
    log('E', self.mgr.logTag, 'Graph.deleteNode. Invalid node: ' .. dumpsz(node, 2))
    return
  end
  if self.nodes[node.id] == nil then
    return
  end
  if editor.getPreference and not editor.getPreference("flowgraph.debug.editorDebug") and node.undeleteable then
    -- dont allow removing io nodes.
    return
  end
  if node.representsGraph and node:representsGraph() ~= nil and not ignoreIntegratedNodes then
    self.mgr:deleteGraph(node:representsGraph())
    -- graph deletion will take care of this node
    return
  end

  -- clear onUpdateNodeId
  if node.nodeType == "events/onUpdate" and self.onUpdateNodeId then
    self.onUpdateNodeId = nil
  end

  -- delete any links to it
  for linkId, link in pairs(self.links) do
    if link.sourceNode == node or link.targetNode == node then
      self:deleteLink(link)
    end
  end
  --dump("Deleting..................................................................")
  --dumpz(node, 1)
  --print(debug.tracesimple())
  --ui_flowgraph_editor.DeleteNode(node.id)
  self.mgr.nodesToRemove[node.id] = true
  self.nodes[node.id]:_destroy()
  self.nodes[node.id] = nil
end

local _createLink = require('/lua/ge/extensions/flowgraph/link')
function C:createLink(startPin, endPin, ...)
  endPin.node:_setHardcodedDummyInputPin(endPin, nil)
  local res = _createLink(self, startPin, endPin, ...)
  return res
end

function C:deleteLink(link)
  if not link or type(link.id) ~= 'number' then
    log('E', self.mgr.logTag, 'Graph.deleteLink. Invalid link: ' .. dumpsz(link, 2))
    return
  end

  local mPin = link.targetNode._mInFlow[link.targetPin.name]
  if link.targetPin.type == 'flow' and mPin then
    for i, pin in ipairs(mPin) do
      if pin == link.sourcePin then
        table.remove(mPin, i)
        break
      end
    end
    if #mPin == 0 then
      rawset(link.targetNode.pinIn, link.targetPin.name, nil)
    end
  else
    rawset(link.targetNode.pinIn, link.targetPin.name, nil)
  end

  link.sourcePin:_onUnlink(link)
  link.targetPin:_onUnlink(link)

  link.sourceNode:_onUnlink(link)
  link.targetNode:_onUnlink(link)

  --ui_flowgraph_editor.DeleteLink(link.id)
  -- defer deletion to end of frame through manager
  self.mgr.linksToRemove[link.id] = true
  self.links[link.id] = nil
end

function C:_onSerialize()
  local dirty = self.dirty
  local children = {}
  local nodes = {}
  local pinOrder = {}
  local pinC = 1
  local minId = math.huge

  for nid, node in pairs(self.nodes) do
    nodes[nid] = node:__onSerialize()
    minId = math.min(nid, minId)
    for _, p in ipairs(node.pinList) do
      pinOrder[p] = pinC
      pinC = pinC + 1
    end
  end

  -- order links
  local orderedLinks = {}
  for _, link in pairs(self.links) do
    if pinOrder[link.targetPin] then
      table.insert(orderedLinks, { link.targetPin, link:__onSerialize() })
    end
  end
  table.sort(orderedLinks, function(a, b)
    return pinOrder[a[1]] < pinOrder[b[1]]
  end)

  -- extract links
  local links = {}
  for _, keyLink in ipairs(orderedLinks) do
    table.insert(links, keyLink[2])
  end

  -- children
  for _, child in ipairs(self:getChildren()) do
    local csaveID = child.id
    if child.type == 'instance' and child.macroID then
      local reference = self.mgr.macros[child.macroID]
      if reference.macroPath then
        children[csaveID] = { path = reference.macroPath }
      else
        children[csaveID] = { macroID = child.macroID }
      end
    else
      local data, mid = child:_onSerialize()
      minId = math.min(mid, minId)
      children[csaveID] = mid
    end
  end

  local viewPos
  local viewZoom
  if self.viewPos and self.viewZoom then
    viewPos = { self.viewPos[0].x, self.viewPos[0].y }
    viewZoom = self.viewZoom[0]
  end

  -- variables
  local variables = self.variables:_onSerialize()

  return {
    name = self.name,
    nodes = nodes,
    links = links,
    type = self.type,
    --children = children,
    dirty = dirty,
    description = self.description,
    variables = variables,
    viewPos = viewPos,
    viewZoom = viewZoom,
    showTab = self.showTab[0] or false,
    isStateGraph = self.isStateGraph,
    parentId = self.parentId
  }, minId
end

function C:_onDeserialized(data)
  if not data.nodes then
    return
  end
  if type(data.name) == 'string' then
    self.name = data.name
  end
  if type(data.type) == 'string' then
    self.type = data.type
  end
  --print("Deserializing " .. self.name .."/" ..self.type)
  if data.viewPos and data.viewZoom then
    self.viewPos = im.ImVec2Ptr(data.viewPos[1], data.viewPos[2])
    self.viewZoom = im.FloatPtr(data.viewZoom)
    self.restoreView = true
  end
  self.variables:clear()
  self.variables:_onDeserialized(data.variables)
  self.showTab[0] = self.type ~= 'instance'
  self.description = string.gsub(data.description or "", "\\\n", "\n") or ""
  self.isStateGraph = data.isStateGraph
  self.parentId = data.parentId or nil

  local integratedNodes = {}

  local nodeKeys = tableKeys(data.nodes)
  table.sort(nodeKeys)

  for _, nid in ipairs(nodeKeys) do
    local nodeData = data.nodes[nid]
    local node = self:createNode(nodeData.type, tonumber(nid) + self.mgr:getGraphNodeOffset())
    if node then
      node:__onDeserialized(nodeData)
      if node.nodeType == 'macro/integrated' then
        integratedNodes[node.targetID] = node
      end
    else
      -- the node with the given path does not exist (anymore)
      -- create a ghost node with some generic in-/outputs
      node = self:createNode('util/ghost', tonumber(nid) + self.mgr:getGraphNodeOffset())
      log('W', self.mgr.logTag, 'Created ghost node replacement!')
      node:__onDeserialized(nodeData)
      --oldNodeIdMap[tonumber(nid)] = node
    end
  end
  for lid, linkData in ipairs(data.links) do
    local sourceNode = self.nodes[linkData[1] + self.mgr:getGraphNodeOffset()]
    if sourceNode then
      local sourcePin = sourceNode.pinOut[linkData[2]]
      if not sourcePin and sourceNode.legacyPins then
        sourcePin = sourceNode.pinOut[sourceNode.legacyPins.out[linkData[2]]]
      end
      local targetNode = self.nodes[linkData[3] + self.mgr:getGraphNodeOffset()]
      if targetNode then
        local targetPin = targetNode.pinInLocal[linkData[4]]
        if not targetPin and targetNode.legacyPins then
          targetPin = targetNode.pinInLocal[targetNode.legacyPins._in[linkData[4]]]
        end
        if not sourcePin or not targetPin then
          log('E', self.mgr.logTag, 'unable to recreate link: unable to find pins: ' .. dumps(linkData) .. ". Tried to create links between " .. sourceNode.name .. "(" .. linkData[2] .. ") -> " .. targetNode.name .. "(" .. linkData[4] .. ")")

          if not sourcePin and sourceNode.nodeType == 'util/ghost' then
            sourcePin = sourceNode:createPin('out', 'any', linkData[2], nil, "")
            log('W', self.mgr.logTag, 'Added generic sourcePin to ghost node.')
          end
          if not targetPin and targetNode.nodeType == 'util/ghost' then
            targetPin = targetNode:createPin('in', 'any', linkData[4], nil, "")
            log('W', self.mgr.logTag, 'Added generic targetPin to ghost node.')
          end
          if sourcePin and targetPin then
            local link = self:createLink(sourcePin, targetPin)
            link:__onDeserialized(linkData)
          end
        else
          local link = self:createLink(sourcePin, targetPin)
          link:__onDeserialized(linkData)
        end
      else
        log('E', self.mgr.logTag, 'targetNode node not found: ' .. tostring(linkData[3]))
      end
    else
      log('E', self.mgr.logTag, 'Source node not found: ' .. tostring(linkData[1]))
    end
  end
  -- disable children deserialization for now
  --[[
  for childId, child in pairs(data.children) do
    local cid = tonumber(childId) + self.mgr:getGraphNodeOffset()
    local iNode = integratedNodes[tonumber(cid)]

    if not iNode and not self.isStateGraph then
      log('E', self.mgr.logTag, 'No Integrated node found for child graph: '..cid)
    else
      local cGraph
      if child.macroID then
        --local macro = oldNodeIdMap[tonumber(child.macroID)]
        --if not macro then
        local macro = self.mgr.macros[tonumber(child.macroID)]
        --end
        if macro then
          cGraph = self.mgr:createInstanceFromMacro(macro, integratedNodes[tonumber(cid)], tonumber(cid) )
        else
          log('E', self.mgr.logTag, 'Failed to find Macro original when creating child.')
        end
      elseif child.path then
        --print("Creating macro instance path. "..self.name .. " => " ..child.path)
        cGraph = self.mgr:createMacroInstanceFromPath(child.path, integratedNodes[tonumber(cid)] )
      else
        --print("Deserializing Child "..self.name .. " => " ..child.name)
        cGraph = self.mgr:createGraph('for deserializing child',self.type == 'macro', tonumber(cid))
        if self.type == 'macro' then
          --print("Creating macro child "..self.name .. " => " ..child.name)
          self.mgr.macros[cGraph.id] = cGraph
        end
        child.type = self.type
        cGraph:_onDeserialized(child)
        table.insert(self.children, cGraph)
        cGraph.parent = self
        if iNode then
          iNode:setTargetGraph(cGraph)
        end
      end
      --oldNodeIdMap[tonumber(cid)] = cGraph
    end
  end
  ]]

  --print("Completed deserializing " .. self.name)
  self.dirty = data.dirty
end

function C:linkExists(startPin, endPin)
  for k, link in pairs(self.links) do
    if link.sourcePin.id == startPin.id and link.targetPin.id == endPin.id then
      return true
    end
  end
  return false
end

function C:hasLink(pin)
  for k, link in pairs(self.links) do
    if pin.type ~= 'flow' and pin.type ~= 'state' and link.targetPin.id == pin.id then
      return true
    end
  end
  return false
end

function C:pinsCompatible(sourcePin, targetPin)
  if sourcePin.type == 'state' then
    return targetPin.type == 'state'
  end
  -- switch pins for comparison in here?
  if sourcePin.direction == 'in' and targetPin.direction == 'out' then
    local t = sourcePin
    sourcePin = targetPin
    targetPin = t
  end

  --if targetPin.type == 'any' and sourcePin.type ~= 'flow' then return true end
  --if sourcePin.type == 'any' and targetPin.type ~= 'flow' then return true end
  local targetTypes = {}
  local sourceTypes = {}
  if type(targetPin.type) ~= 'table' then
    targetTypes[targetPin.type] = 1
  else
    targetTypes = tableValuesAsLookupDict(targetPin.type)
  end

  --dumpz(targetTypes, 2)
  --dumpz(sourceTypes, 2)

  if type(sourcePin.type) ~= 'table' then
    sourceTypes[sourcePin.type] = 1
  else
    sourceTypes = tableValuesAsLookupDict(sourcePin.type)
  end
  if sourceTypes['any'] then
    return true
  end
  for typeA, _ in pairs(sourceTypes) do
    if targetTypes['any'] then
      return true
    end
    if targetTypes[typeA] then
      if typeA == 'table' then
        if sourcePin:getTableType() == targetPin:getTableType() or sourcePin:getTableType() == 'generic' or targetPin:getTableType() == 'generic' then
          return true
        end
      else
        return true
      end
    end
  end

end

function C:canCreateLink(a, b, newLinkInfo)
  if a.direction == 'in' then
    local t = a
    a = b
    b = t
  end
  if not a or not b
          or a.node.id == b.node.id
          or a == b or a.direction == b.direction
          or not self:pinsCompatible(a, b)
          or a.node == b.node
          or self:linkExists(a, b)
          or (newLinkInfo and not newLinkInfo[a.node.id].allowed and not newLinkInfo[b.node.id].allowed)
          or (a.matchName and b.matchName and a.name ~= b.name) then
    return false
  else
    return true
  end
end

function C:findPin(pinId)
  if not pinId then
    return
  end
  return self.pins[pinId]
end

function C:updateChildrenTypes(t, ignoreType)
  if ignoreType and ignoreType == self.type then
    return
  end
  self.type = t
  for _, child in ipairs(self:getChildren()) do
    child:updateChildrenTypes(t, ignoreType)
  end
end

function C:_executionStarted()
  for _, node in pairs(self.nodes) do
    if node._executionStarted then
      node:__executionStarted()
    end
  end
end

function C:_onClear()
  for _, node in pairs(self.nodes) do
    node:_onClear()
  end
  self.variables:_onClear()
end

function C:_executionStopped()
  for _, node in pairs(self.nodes) do
    if node._executionStopped then
      node:__executionStopped()
    end
  end
  self.variables:_executionStopped()
end

function C:getMacro()
  if self.type ~= 'instance' then
    return nil
  end
  local root = self:getInstanceRoot()
  local indexes = self:getChildPosition()
  --print("Root ID " .. root.id)
  for _, m in pairs(self.mgr.macros) do
    if m.id == root.macroID then
      return m:getDeepChild(indexes)
    end
  end
end

function C:getInstanceRoot()
  if not self:getParent() then
    return self
  end
  if self.macroID == nil then
    return self:getParent():getInstanceRoot()
  else
    return self
  end
end

function C:getChildPosition()
  local indexes = {}
  local root = self:getInstanceRoot()
  local current = self
  while current ~= root do
    table.insert(indexes, 1, arrayFindValueIndex(current:getParent():getChildren(), current))
    current = current:getParent()
  end
  return indexes
end

function C:getDeepChild(indexes)
  local current = self
  for _, i in ipairs(indexes) do
    current = current.children[i]
  end
  return current
end

function C:getRecursiveHooksAndDependencies(hooks, deps)
  for _, node in pairs(self.nodes) do
    table.insert(hooks, node)
    for _, dep in ipairs(node.dependencies or {}) do
      deps[dep] = true
    end
  end
  for _, g in pairs(self:getChildren()) do
    g:getRecursiveHooksAndDependencies(hooks, deps)
  end
  return hooks, deps
end

function C:findNodeInChildren(id)
  return self:findNodeRecursive(id)
end
function C:findNodeRecursive(id)
  for _, node in pairs(self.nodes) do
    if node.id == id then
      return node
    end
  end
  local ret = nil
  for _, child in pairs(self:getChildren()) do
    if not ret then
      ret = child:findNodeRecursive(id)
    end
  end
  return ret
end

function C:forceRecursiveNodeUpdatePosition()
  for _, gr in pairs(self:getChildren()) do
    gr:forceRecursiveNodeUpdatePosition()
  end
  for _, nd in pairs(self.nodes) do
    nd:updateNodePosition()
  end
end

function C:toString()
  return self.name .. " (" .. self.id .. " / " .. self.type .. ")"
end

function C:_printStructure(depth)
  local s = ''
  for i = 0, depth * 2 do
    s = s .. ' '
  end
  s = s .. self:toString()
  print(s)
  for _, c in ipairs(self:getChildren()) do
    c:_printStructure(depth + 1)
  end
end

function C:printStructure()
  if self:getParent() then
    return nil
  end
  self:_printStructure(0)
end
local function reverseList(list)
  local i, j = 1, #list
  while i < j do
    list[i], list[j] = list[j], list[i]
    i = i + 1
    j = j - 1
  end
end

function C:getParentWithStates()
  local parent = self:getParent()
  if not parent then
    -- find stategraph with this graph as child
    local state = nil
    for _, gr in pairs(self.mgr.graphs) do
      if gr.isStateGraph and state == nil then
        for _, node in pairs(gr.nodes) do
          if node:representsGraph() and node:representsGraph().id == self.id then
            state = gr
            break
          end
        end
      end
    end
    if state then
      parent = state
    end
  end
  return parent
end

function C:getChildrenWithStates()
  if not self.isStateGraph then
    return self:getChildren()
  else
    local children = self:getChildren()
    for _, node in pairs(self.nodes) do
      if node:representsGraph() and not node:representsGraph().isStateGraph then
        table.insert(children, node:representsGraph())
      end
    end
    table.sort(children, idSort)
    return children
  end
end
function C:getSiblings()
  local parent = self:getParentWithStates()

  if parent then
    print(parent.name)
    -- find all children and represented flowgraphs
    if not parent.isStateGraph then
      return parent:getChildren()
    else
      local children = parent:getChildren()
      for _, node in pairs(parent.nodes) do
        if node:representsGraph() and not node:representsGraph().isStateGraph then
          table.insert(children, node:representsGraph())
        end
      end
      table.sort(children, idSort)
      return children
    end
  else
    local children = {}
    for _, gr in pairs(self.mgr.graphs) do
      if gr:getParentWithStates() == nil then
        table.insert(children, gr)
      end
    end
    table.sort(children, idSort)
    return children
  end

end

function C:getLocation(withIds)
  local parent = self:getParent()
  local last = self
  local ids = { self.id }
  local graphs = { self.name }
  while parent ~= nil do
    table.insert(graphs, parent.name)
    table.insert(ids, parent.id)
    last = parent
    parent = parent:getParent()
  end
  if not self.isStateGraph then
    local state = nil
    for _, gr in pairs(self.mgr.graphs) do
      --print(gr.isStateGraph)
      --print(gr.name)
      if gr.isStateGraph and state == nil then
        for _, node in pairs(gr.nodes) do
          if node:representsGraph() and node:representsGraph().id == last.id then
            state = gr
            break
          end
        end
      end
    end
    if state then
      parent = state:getParent()
      last = state
      table.insert(graphs, state.name)
      table.insert(ids, state.id)
      while parent ~= nil do
        table.insert(graphs, parent.name)
        table.insert(ids, parent.id)
        last = parent
        parent = parent:getParent()
      end
    end
  end
  reverseList(graphs)
  reverseList(ids)
  if withIds then
    for i, gr in ipairs(graphs) do
      graphs[i] = gr .. "(" .. ids[i] .. ")"
    end
  end
  return table.concat(graphs, " / "), graphs, ids

end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end