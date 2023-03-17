-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}

C.name = 'Transition'

C.description = [[Ends the current state and switches to a new one.]]

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = "This is a flow pin.", fixed = true},
}

-- add extensions you require in here, instead of loading them through "extensions.foo". this will increase performance
C.dependencies = {}

-- when adding a new node "family", create a new color entry in lua/common/extensions/ui/flowgraph/editor.lua
C.color = ui_flowgraph_editor.nodeColors.state
C.icon = ui_flowgraph_editor.nodeIcons.state

C.type = 'node' -- can also be 'simple', then it wont have a header
C.allowedManualPinTypes = {
  flow = false,
  string = true,
  number = true,
  bool = true,
  any = true,
  table = true,
  vec3 = true,
  quat = true,
  color = true,
}

function C:init()
  self.savePins = true
  self.allowCustomInPins = true
  self.transitionName = 'success'
end

function C:makePinTemplates()
  local pins = {}
  for node in self.mgr:allNodes() do
    if node.nodeType == 'states/transition' then
      -- collect the in-pins of this node
      for name, pin in pairs(node.pinInLocal) do
        if name ~= 'flow' then
          if not pins[name] then
            pins[name] = type(pin.type) == 'string' and pin.type or 'any'
          end
        end
      end
    end
    if node.nodeType == 'states/transitionStack' then
      -- collect the out-pins of this node
      for name, pin in pairs(node.pinOut) do
        if name ~= 'flow' then
          if not pins[name] then
            pins[name] = type(pin.type) == 'string' and pin.type or 'any'
          end
        end
      end
    end
  end
  self._pinTemplates = {_in = {}, _out = {}}
  for name, type in pairs(pins) do  table.insert(self._pinTemplates._in,  {name = name, type = type}) end
  table.sort(self._pinTemplates._in,  function(a,b) return a.name < b.name end)
  self._pinTemplates._out = deepcopy(self._pinTemplates._in)
end

function C:drawCustomProperties()
  local reason = nil
  if not self._pinTemplates then self:makePinTemplates() end
  local target = self.mgr.states:findStateNodeInStateGraph(self.graph.id)
  if target then
    if im.BeginCombo("Transition Name", self.transitionName) then
      for _, tName in ipairs(target:getTransitionNames()) do
        if im.Selectable1(tName, tName == self.transitionName) then
          self.transitionName = tName
          reason = "Changed Transition Name to " .. tName
        end
      end
      im.EndCombo()
    end
    im.Separator()
  end
  return reason
end

function C:hideProperties()
  self._pinTemplates = nil
end


-- This gets called when the node should execute it's actual function in the flowgraph.
function C:work()
  local stateId = self.mgr.states:getStateIdForNode(self)
  if self.pinIn.flow.value then
    local tData = {}
    local added = false
    for name, pin in pairs(self.pinIn) do
      if name ~= 'flow' then
        tData[name] = pin.value
        added = true
      end
    end
    self.mgr.states:transition(stateId, self.transitionName, added and tData or nil, self)
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text(self.transitionName or "No Transition!")
  --im.BeginChild1("child",im.ImVec2(self.sliderWidth[0],50), true)
end

function C:_onSerialize(res)
  res.transitionName = self.transitionName
end

function C:_onDeserialized(data)
  self.transitionName = data.transitionName or 'success'
end

function C:customContextMenu()
  --local stateId = self.mgr.states:getStateIdForNode(self)
  local hops = nil
  if self.mgr.runningState ~= 'stopped' then
    hops = self.mgr.states._interHopData
  else
    hops = self.mgr.states:resolveInterHops(self.mgr.states:gatherNodesAndLinks())
  end
  local target = nil
  if im.BeginMenu("Go to target...") then
    im.SetWindowFontScale(1/editor.getPreference("ui.general.scale"))
    for _, hop in ipairs(hops) do
      local lnk = hop.link

      if lnk.sourceNode and lnk.sourceNode.targetGraph and lnk.sourceNode.targetGraph.id == self.graph.id
         and lnk.targetNode and lnk.targetNode.targetGraph
         and lnk.sourcePin and lnk.sourcePin.name == self.transitionName then
        local name = lnk.targetNode.targetGraph:getLocation(true)
        if editor.getPreference("flowgraph.debug.displayIds") then
          name = string.format(name.." [%d]", lnk.targetNode.targetGraph.id)
        end
        if im.MenuItem1(name) then
          target = lnk.targetNode.targetGraph
        end
      end
    end
    im.SetWindowFontScale(1)
    im.EndMenu()
  end
  if target then
    self.mgr:unselectAll()
    self.mgr:selectGraph(target)
  end
end

return _flowgraph_createNode(C)
