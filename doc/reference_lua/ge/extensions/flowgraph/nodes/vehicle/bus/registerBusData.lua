-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

--require('/lua/vehicle/controller')

local C = {}

C.name = 'Register Bus Data'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = 'directions_bus'
C.description = 'Registers the bus value change callback for kneeling and opening doors. Call after spawning the bus.'
C.todo = ""
C.category = 'once_instant'

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = "Inflow for this node."},
  { dir = 'in', type = 'number', name = 'vehId', default = 0, description = "Vehicle ID. If not present, player vehicle will be used." },
  {dir = 'out', type = 'flow', name = 'flow', description = "Outflow for this node."},

}

function C:workOnce()
  local fun = function()
    local veh = scenetree.findObjectById(self.pinIn.vehId.value)
    self.mgr.modules.vehicle:registerBusChangeNotification(self.pinIn.vehId.value)
  end
  self.mgr.modules.level:delayOrInstantFunction(fun)
  self.pinOut.flow.value = true
end



return _flowgraph_createNode(C)
