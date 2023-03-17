-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Once'
C.icon = "keyboard_tab"
C.behaviour = {once = true}
C.description = 'Only lets the flow through once. Can be reset.'
C.category = 'logic'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'reset', description = 'Resets this node.', impulse = true },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.', impulse = true },
}

C.tags = {}

function C:init(mgr, ...)
  self.ready = true
end

function C:_executionStopped()
  self.ready = true
end

function C:work(args)
  if self.pinIn.reset.value then
    self.ready = true
    self.pinOut.flow.value = false
  else
    if self.ready then
      if self.pinIn.flow.value then
        self.pinOut.flow.value = true
        self.ready = false
      else
        self.pinOut.flow.value = false
      end
      else
      self.pinOut.flow.value = false
    end
  end
end

return _flowgraph_createNode(C)
