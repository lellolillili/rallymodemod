-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Is Coupled'
C.description = 'Detect whether or not two vehicles are coupled.'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = "link"
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehA', description = 'Id of vehicle A.' },
  { dir = 'in', type = 'number', name = 'vehB', description = 'Id of vehicle B.' },
  { dir = 'out', type = 'flow', name = 'coupled', description = 'Puts out flow, when the vehicles are coupled.' },
  { dir = 'out', type = 'flow', name = 'decoupled', description = 'Puts out flow, when the vehicles are not coupled.' },
  { dir = 'out', type = 'bool', name = 'isCoupled', description = 'True if the vehicles are coupled.' },
}

C.tags = {'event','attach','detach'}


function C:work(args)
  self.pinOut['coupled'].value = self.mgr.modules.vehicle:isCoupledTo(self.pinIn.vehA.value, self.pinIn.vehB.value)
  self.pinOut['decoupled'].value = not self.pinOut['coupled'].value
  self.pinOut['isCoupled'].value = self.pinOut['coupled'].value
end

return _flowgraph_createNode(C)
