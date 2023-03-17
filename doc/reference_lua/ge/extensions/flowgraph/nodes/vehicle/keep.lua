-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Keep Vehicle'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle

C.description = 'Marks a vehicle to be kept after the flowgraph stops. By default, vehicles spawned during runtime will be removed at the end.'
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'The Id of the vehicle to be affected.' },
  { dir = 'in', type = 'bool', name = 'keep', description = 'If the vehicle should be kept after stopping.' },
}

C.tags = {}

function C:init()

end

function C:workOnce()
  if self.pinIn.vehId.value then
    print("keeping " .. self.pinIn.vehId.value, self.pinIn.keep.value)
    self.mgr.modules.vehicle:setKeepVehicle(self.pinIn.vehId.value, self.pinIn.keep.value)
  end
  self.pinOut.flow.value = self.pinIn.flow.value
end


return _flowgraph_createNode(C)
