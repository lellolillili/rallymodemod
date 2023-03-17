-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

--require('/lua/vehicle/controller')

local C = {}

C.name = 'Bus Controls Detection'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = 'directions_bus'
C.description = 'Gets the bus door and kneel status. Use with Register Bus Data node..'
C.todo = ""
C.category = 'repeat_instant'

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = "Inflow for this node."},
  { dir = 'in', type = 'number', name = 'vehId', default = 0, description = "Vehicle ID. If not present, player vehicle will be used." },
  {dir = 'out', type = 'flow', name = 'flow', description = "Outflow for this node."},
  {dir = 'out', type = 'bool', name = 'isKneeling', description = ""},
  {dir = 'out', type = 'bool', name = 'doorsOpen', description = ""}
}

function C:init()
  self.pinOut.isKneeling.value = false
  self.pinOut.doorsOpen.value = false
end

function C:work()
  self.pinOut.isKneeling.value = self.mgr.modules.vehicle:isBusKneel(self.pinIn.vehId.value)
  self.pinOut.doorsOpen.value = self.mgr.modules.vehicle:isBusDoorOpen(self.pinIn.vehId.value)
  self.pinOut.flow.value = true
end

function C:executionStarted()
  self.pinOut.isKneeling.value = false
  self.pinOut.doorsOpen.value = false
end

return _flowgraph_createNode(C)
