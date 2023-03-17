-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Custom Button TEST'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.description = "TEST"
C.category = 'once_instant'

C.todo = "TEST"
C.pinSchema = {
  { dir = 'out', type = 'flow', name = 'btn_1', description = 'Outflow once when the button is pressed.' },
}
C.dependencies = {'core_input_bindings'}

function C:init()
  self.open = false
end

function C:_executionStarted()
  self.open = false
end

function C:_executionStopped()
  if self.open then
    self:closeDialogue()
  end
end

function C:buttonPushed(action)
  for nm, pn in pairs(self.pinOut) do
    self.pinOut[nm].value = nm == action
  end
end

function C:getCmd(action)
  return 'core_flowgraphManager.getManagerByID('..self.mgr.id..').graphs['..self.graph.id..'].nodes['..self.id..']:buttonPushed("'..action..'")'
end

function C:closeDialogue()
  guihooks.trigger('CustomFGButtons', {}) -- empty list means show no buttons
end

function C:openDialogue()
  local data = {
    {
      name = "Click me!",
      fun = self:getCmd('btn_1') -- this contains the function that will call the "buttonPushed" function above
    }
  }
  guihooks.trigger('CustomFGButtons', data);
  self.done = true;
end

function C:onNodeReset()
  if self.open then
    self:closeDialogue()
  end
end

function C:workOnce()
  local data = {
    {
      name = "Click me!",
      fun = self:getCmd('btn_1') -- this contains the function that will call the "buttonPushed" function above
    }
  }
  guihooks.trigger('CustomFGButtons', data);
end


return _flowgraph_createNode(C)
