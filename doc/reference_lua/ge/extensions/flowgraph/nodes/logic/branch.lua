-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Branch'
C.icon = "fg_sideways"
C.description = "Lets the flow through either out pin depending on a condition."
C.category = 'logic'

C.pinSchema = {
    { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
    { dir = 'in', type = 'bool', name = 'condition', description = 'The condition to be checked against.' },
    { dir = 'out', type = 'flow', name = 'flow', hidden = true, description = 'Outflow for this node.' },
    { dir = 'out', type = 'flow', name = 'True', description = 'Outflow when the condition is true.' },
    { dir = 'out', type = 'flow', name = 'False', description = 'Outflow when the condition is false.' },
}

C.tags = {}

function C:work()
  if self.pinIn.flow.value then
    self.pinOut.flow.value = self.pinIn.flow.value
    if self.pinIn.condition.value then
      self.pinOut.True.value = true
      self.pinOut.False.value = false
    else
      self.pinOut.True.value = false
      self.pinOut.False.value = true
    end
  else
    self.pinOut.True.value = false
    self.pinOut.False.value = false
    self.pinOut.flow.value = false
  end
end

return _flowgraph_createNode(C)
