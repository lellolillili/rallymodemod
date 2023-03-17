-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}

C.name = 'Get Transition Variables'

C.description = [[Gets data from the transition Stack variables.]]

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = "This is a flow pin.", fixed = true},
  {dir = 'out', type = 'flow', name = 'flow', description = "This is a flow pin.", fixed = true},
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
  self.allowCustomOutPins = true
end

function C:onStateStarted(state)
  local stack = state.transitionStack
  self._stack = stack or {}

end
function C:_executionStopped()
  self._stack = nil
end

function C:work()
  if self._stack then
    for name, pin in pairs(self.pinOut) do
      self.pinOut[name].value = self._stack[name]
    end
  end
  self.pinOut.flow.value = self.pinIn.flow.value

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
  if not self._pinTemplates then self:makePinTemplates() end
end

function C:hideProperties()
  self._pinTemplates = nil
end

function C:drawMiddle(builder, style)
  builder:Middle()
  if self._stack then
    im.Text("(Stack)")
    ui_flowgraph_editor.tooltip(dumps(self._stack))
  else
    im.Text("(nil)")
  end
end



return _flowgraph_createNode(C)
