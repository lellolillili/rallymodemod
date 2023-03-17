-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Get action control'
C.description = 'Returns the control to a given input action'
C.color = im.ImVec4(1, 1, 0, 0.75)
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'string', name = 'actionName', description = 'The name of the input action' },
  { dir = 'out', type = 'string', name = 'controlName', description = 'The name of the control for that action' }
}

C.tags = {'scenario'}

function C:work(args)
  self.pinOut.controlName.value = core_input_bindings.getControlForAction(self.pinIn.actionName.value)
end

return _flowgraph_createNode(C)
