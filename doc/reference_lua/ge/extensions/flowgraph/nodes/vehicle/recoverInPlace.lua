-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Recover In Place'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle

C.description = 'Recovers the vehicle in place. It will be reset and be placed so it doesnt intersect obstacles, but might be moved around a little.'
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Defines the id of the vehicle to freeze.' },
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}
C.tags = {}

function C:init()

end

function C:workOnce()
  local veh
  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end
  if veh then
    --print("Recover in Place")
    veh:resetBrokenFlexMesh()
    spawn.safeTeleport(veh, veh:getPosition(),quatFromDir(veh:getDirectionVector(), veh:getDirectionVectorUp()))
  end
end


return _flowgraph_createNode(C)
