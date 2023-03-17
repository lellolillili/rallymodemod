-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Generate License Plate'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.description = 'Generates a random vehicle license plate.'
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'ID of vehicle to change the plate to. If empty, player vehicle will be used.' },
}
C.tags = {'plate', 'license'}

function C:workOnce()
  local vehId = self.pinIn.vehId.value or be:getPlayerVehicleID(0)
  local veh = be:getObjectByID(vehId) or be:getPlayerVehicle(0)
  if not veh then return end
  core_vehicles.setPlateText(nil,nil,nil,nil,true)
  local generatedText = core_vehicles.regenerateVehicleLicenseText(veh)
  core_vehicles.setPlateText(generatedText, vehId)
end

return _flowgraph_createNode(C)
