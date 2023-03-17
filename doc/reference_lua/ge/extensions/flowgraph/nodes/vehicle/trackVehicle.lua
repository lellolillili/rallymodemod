-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

--require('/lua/vehicle/controller')

local C = {}

C.name = 'Track Vehicle'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Allow Flowgraph to track the vehicle spawned outside Flowgraph.'
C.todo = ""
C.category = 'repeat_instant'

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = "Inflow for this node."},
  { dir = 'in', type = 'number', name = 'vehId', default = 0, description = "Vehicle ID. If not present, player vehicle will be used." },
  { dir = 'in', type = 'bool', name = 'dontDelete', hidden = true, default = true, description = 'If true, the vehicle will not be deleted when you stop the project.' }
}

C.legacyPins = {
  _in = {
    vehicleID = 'vehId'
  },
}

function C:init()
end


function C:work()
  local veh = scenetree.findObjectById(self.pinIn.vehId.value)
  if veh then
    self.mgr.modules.vehicle:addVehicle(veh, {dontDelete = self.pinIn.dontDelete.value})
  end
end

function C:_executionStopped()

end


return _flowgraph_createNode(C)