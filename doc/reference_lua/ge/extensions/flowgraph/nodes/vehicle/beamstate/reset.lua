-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Reset Vehicle'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle

C.description = [[Resets a vehicle.
Uses player vehicle if no ID is given.]]
C.category = 'repeat_p_duration'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Defines the id of the vehicle to reset.' },
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}
C.tags = {}

function C:work()
  local veh
  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end
  if not veh then
    return
  end
  veh:requestReset(RESET_PHYSICS)
  veh:resetBrokenFlexMesh()
end

return _flowgraph_createNode(C)
