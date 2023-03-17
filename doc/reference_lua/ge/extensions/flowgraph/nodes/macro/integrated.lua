-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')


local C = {}

C.name = 'Integrated'
C.macro = 1
C.hidden = true
C.canHaveGraph = true
function C:representsGraph()
  return self.targetGraph
end

-- this node serializes it's pins, name and color

function C:init()
  self.savePins = true
  self.color = im.ImVec4(0.55,0.55,0.55,0.9)
end
function C:drawCustomProperties()
  local reason
  if im.Button("Manually Refresh Pins [Debug]") then
    self.mgr:refreshIntegratedPins(self)
  end

  if im.IsItemDeactivatedAfterEdit() then
      reason = "Changed color of Integrated Node."
  end

  return reason
end

function C:setTargetGraph(graph)
  if not graph then
    log('E', "integratedNode", "Trying to connect to nil graph!")
  end

  for _, node in pairs(graph.nodes) do
    if node.nodeType == "macro/io" then
      if node.ioType == "in" then
        self.inputNode = node
      elseif node.ioType == "out" then
        self.outputNode = node
        node.integratedNode = self
      end
    end
  end
  self.targetGraph = graph
  self.targetID = graph.id

  self.name = ui_flowgraph_editor.getGraphTypes()[self.targetGraph.type].abbreviation .. " " .. self.targetGraph.name
end

function C:_postDeserialize()
  self:setTargetGraph(self.mgr.graphs[self.targetID + self.mgr:getGraphNodeOffset()])
end

function C:gatherPins()
  self.pinList = {}
  self.pinIn = {}
  self.pinOut = {}
  self.pinInLocal = {}
  local inPins = {}
  local outPins = {}



  if self.inputNode then
    for _, pin in pairs(self.inputNode.pinList) do
      table.insert(inPins, self:createPin('in', pin.type, pin.name, pin.default, pin.description, true))
    end
  end
  if self.outputNode then
    for _, pin in pairs(self.outputNode.pinList) do
      table.insert(outPins,self:createPin('out', pin.type, pin.name, pin.default, pin.description, true))
    end
  end
  return inPins, outPins
end

function C:_onSerialize(res)
  res.name = self.name
  res.graphType = self.graphType
  if self.graphType == 'instance' then
    --print(self.mgr == nil and "mgr nil " or "mgr ok")
    --print(self.macroID == nil and "self.macroID nil " or "self.macroID ok")
    --print(self.mgr.macros[self.macroID] == nil and "self.mgr.macros[self.macroID] nil " or "self.mgr.macros[self.macroID] ok")
    --res.macroPath = self.mgr.macros[self.macroID].macroPath
    --if self.mgr.macros[self.macroID].macroPath then
    --  res.macroPath = self.mgr.macros[self.macroID].macroPath
    --else
      res.targetID = self.targetGraph.id
    --end
  else
    res.targetID = self.targetGraph.id
  end

  local col = self.color
  res.color = {col.x, col.y, col.z, col.w}

  --if self.inputNode then
  --  res.inputNodeId = self.inputNode.id
  --end
  --if self.outputNode then
  --  res.outputNodeId = self.outputNode.id
  --end
end

function C:_onDeserialized(nodeData)
  --dump("_onDeserialized")
  --dump(nodeData)
  self.name = nodeData.name
  self.color = im.ImVec4(nodeData.color[1], nodeData.color[2], nodeData.color[3], nodeData.color[4])
  if nodeData.graphType then
    if nodeData.graphType == "instance" and nodeData.macroPath then
      -- create graph from file through flowgraph_manager
      local target = self.mgr:createMacroInstanceFromPath(nodeData.macroPath,self)
      self.targetGraph = target
      self.targetID = target.id
      self.macroID = target.macroID
    else
      self.targetID = nodeData.targetID + self.mgr:getGraphNodeOffset()
      self.targetGraph = self.mgr.graphs[self.targetID + self.mgr:getGraphNodeOffset()]
    end
  end
  self.graphType = nodeData.graphType
end

function C:drawMiddle(builder, style)
  builder:Middle()
  if self.targetGraph then
    --im.Text(self.targetGraph.name)
    editor.uiIconImage(editor.icons.search, im.ImVec2(20, 20))
    if im.IsItemHovered() then
      -- display blue rectangle when node is hovered
      local cursor = im.GetCursorPos()
      local itemSize = {x = 150, y = 100}

      --disabled for now
      if self.mgr.fgEditor then
        self.mgr.fgEditor.nodePreviewPopup:setGraph(self.targetGraph)
      end
    end
    for _, name in ipairs(self.targetGraph.variables.sortedVariableNames) do
      local full = self.targetGraph.variables:getFull(name)
      if full.monitored then
        im.Text(name .. " = " .. dumps(full.value))
      end
    end

    --im.Text(self.graphType or "no graph type?!")
    --im.Text(self.macroID and (self.macroID..'') or "no macro id")
    --im.Text(self.targetGraph.macroID and (self.targetGraph.macroID..' target') or "no target id")
  else
    im.Text("No Target Graph! :(")
  end
end

function C:doubleClicked()
  if self.targetGraph then
    if self.graph.type == 'macro' then
      --local pos = arrayFindValueIndex(self.graph.children, self.targetGraph)
      --self.mgr:selectGraph(self.mgr.recentInstance.children[pos])
    else
      self.mgr:selectGraph(self.targetGraph)
    end
  end
end

function C:updatePins()
  -- copy over the pins to the input node and from the output node.
  -- the out pins of the input node and the output node of this node are not connected
  -- so it shouldnt be a problem
  if self.inputNode then
    for name, pin in pairs(self.pinIn) do
      if not pin._hardcodedDummyPin then
        self.inputNode.pinOut[name].value = pin.value
      end
    end
  end
  if self.outputNode then
    for name, pin in pairs(self.pinOut) do
      self.pinOut[name].value = self.outputNode.pinIn[name].value
    end
  end

end

function C:_afterTrigger()

  self:updatePins()
end

function C:_executionStarted()
  for _, pin in pairs(self.pinIn) do
    if pin._hardcodedDummyPin then
      if self.inputNode then
        self.inputNode.pinOut[pin.name].value = pin.value
        --print("Hardcoded pin: " .. pin.name .. " of " .. self.inputNode.pinOut[pin.name].id)
        --dumpz(self.inputNode.pinOut[pin.name],1)
      end
    end
  end
end

function C:_executionStopped()
  for _, pin in pairs(self.pinIn) do
    if pin._hardcodedDummyPin then
      if self.inputNode then
        self.inputNode.pinOut[pin.name].value = nil
      end
    end
  end
end


function C:work()
end

return _flowgraph_createNode(C)
