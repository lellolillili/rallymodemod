-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Enter Vehicle'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle

C.description = 'Enters a vehicle and sets the camera to orbit. PlayerID can be set for multiseat.'
C.category = 'dynamic_instant'

C.todo = "Needs further testing."
C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Defines the id of the vehicle to enter.' },
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}
C.tags = {}
C.dependencies = {'gameplay_walk'}

function C:workOnce()
  self:enterVehicle()
end

function C:work()
  if self.dynamicMode == 'repeat' then
    self:enterVehicle()
  end
end

function C:enterVehicle()
  local veh
  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end
  --be:enterVehicle(self.data.playerID or 0, veh)
  gameplay_walk.getInVehicle(veh)
  --core_camera.setByName(0, 'orbit')
  commands.setGameCamera()
end

return _flowgraph_createNode(C)
