-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ufe = ui_flowgraph_editor
local C = {}

C.name = 'State Node'

C.description = [[State Node]]
C.icon = ui_flowgraph_editor.nodeIcons.state
C.pinSchema = {
  {dir = 'in',  type = 'state', name = 'flow', description = "This is a flow pin."},
  {dir = 'out', type = 'state', name = 'success', description = "This is a flow pin."},
  {dir = 'out', type = 'state', name = 'fail', description = "This is a flow pin."},
  --{dir = 'out', type = 'state', name = 'transA', description = "This is a flow pin."},
  --{dir = 'out', type = 'state', name = 'transB', description = "This is a flow pin."},
}
C.hidden = true

-- when adding a new node "family", create a new color entry in lua/common/extensions/ui/flowgraph/editor.lua
C.color = ufe.nodeColors.state
local startColor = im.ImVec4(0.4, 1, 0.4, 1)

C.type = 'node' --
C.allowedManualPinTypes = {
  state = true,
}

function C:representsGraph()
  return self.targetGraph
end
C.canHaveGraph = true

-- This gets called when the node has been created for the first time. Init field here
function C:init(mgr)

  self.allowCustomOutPins = true
  self.savePins = true
end

function C:setTargetGraph(graph)
  self.targetGraph = graph
  if self.targetGraph then
    self.name = self.targetGraph.name
    if self.color == ufe.nodeColors.state then
      if self.targetGraph.isStateGraph then
        self.color = ufe.nodeColors.groupstate
      end
    end
  else
    self.name = "No Target!"
  end
end

function C:setAutoStart(val)

end


-- write custom imgui code here that gets displayed in the property window when the node is selected.
-- return a string so a history point will be created (redo/undo)
function C:drawCustomProperties()


  local rootGraphs = {}
  for _, graph in pairs(self.mgr.graphs) do
    if graph.type == "graph" and graph:getParent() == nil and (not self.mgr.stateGraph or graph.id ~= self.mgr.stateGraph.id) then
      table.insert(rootGraphs, graph)
    end
  end
  table.sort(rootGraphs, function(a,b) return a.id<b.id end)
  local label = "None"
  local reason
  local id = self.targetGraph and self.targetGraph.id or -1
  if self.targetGraph then label = self.targetGraph.name end
  if im.BeginCombo("Target Graph", label) then
    for _, graph in pairs(rootGraphs) do
      if im.Selectable1(graph.id .. "-"..graph.name, graph.id == id) then
        self:setTargetGraph(graph)
        reason = "Changed Target graph to " .. graph.name
      end
    end
    im.EndCombo()
  end
  im.Separator()

  if im.Button("Export State") then
    extensions.editor_fileDialog.saveFile(
      function(data)
        local dir, filename, ext = path.splitWithoutExt(data.filepath, true)
        local saveData = self:_onSerializeState()
        saveData.name = filename
        jsonWriteFile(data.filepath, saveData, true)
        log("I","","Saved State to " .. data.filepath)
      end,
      {{"Flow State Files",".state.flow.json"}}, false, "flowEditor/states/")
  end

  return reason
end

function C:getTransitionNames()
  local names = {}
  for n, pin in pairs(self.pinOut) do
    table.insert(names,n)
  end
  table.sort(names)
  return names
end

function C:doubleClicked()
  if self.targetGraph then
    self.mgr:selectGraph(self.targetGraph)
  end
end



function C:drawMiddle(builder, style)
  builder:Middle()
  --self.color = ufe.nodeColors.state
  if self.targetGraph then
    self.name = self.targetGraph.name
    im.Text(self.targetGraph.name)
    if self.targetGraph.isStateGraph then
      im.Text("Groupstate")
      --self.color = ufe.nodeColors.groupstate
    end
    self.description = self.targetGraph.description
  else
    im.Text("No Target")
    self.description = "No Target."
  end

  --im.BeginChild1("child",im.ImVec2(self.sliderWidth[0],50), true)
  if self.targetGraph and self.targetGraph.state and self.targetGraph.state.active then
    self._frameLastUsed = self.graph.mgr.frameCount
  end

end



function C:EndPin()
end

-- Serialize (saving) custom fields into res here.
-- You dont need to serialize fields in self.data
function C:_onSerialize(res)
  if self.targetGraph then
    res.targetGraphId = self.targetGraph.id
  end
end

-- Deserialize (loading) custo fields from data here.
-- self.data will be restored automatically.
function C:_onDeserialized(data)
  self.targetGraphId = data.targetGraphId or nil
end

function C:_postDeserialize()
  if self.targetGraphId then
    local tgtGraph = self.mgr.graphs[self.targetGraphId + self.mgr:getGraphNodeOffset()]
    if tgtGraph then
      self:setTargetGraph(tgtGraph)
      self.targetGraphId = nil
      log("D","","Set target graph successfully")
    else
      log("E","","Could not find previous target graph for state node...")
    end
  end
end

function C:onCustomNameChanged(name)
  if self.targetGraph then
    local oldName = self.targetGraph.name
    self.targetGraph.name = name
    return "Changed graph name from " .. oldName .. " to " .. name
  end
end


function C:_onSerializeState()
  local res = {}
  res.type = 'state'
  res.node = self:__onSerialize()
  res.node.pos = nil
  res.graph = self.targetGraph:_onSerialize()
  return res

end


return _flowgraph_createStateNode(C)
