-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Is Bus'
C.description = 'Checks if the a vehicle is a bus.'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = "directions_bus"
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Id of vehicle A.' },
  { dir = 'out', type = 'flow', name = 'isBus', description = 'Puts out flow, when the vehicle is a bus.' },
  { dir = 'out', type = 'flow', name = 'isNotBus', description = 'Puts out flow, when the vehicle is not a bus.' },
  { dir = 'out', type = 'bool', name = 'isBusBool', description = 'True if the vehicle is a bus.' },
}

function C:work(args)
  self.pinOut['isBus'].value = self.mgr.modules.vehicle:isBus(self.pinIn.vehId.value)
  self.pinOut['isNotBus'].value = not self.pinOut['isBus'].value
  self.pinOut['isBusBool'].value = self.pinOut['isBus'].value
end

return _flowgraph_createNode(C)
