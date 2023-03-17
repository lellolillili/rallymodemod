-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Get Vehicle Bounds'
C.description = 'Provides the vehicle bounds..'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', default = 0, description = "Vehicle ID. If not present, player vehicle will be used." },
  { dir = 'out', type = 'vec3', name = 'corner_FR', description = "Position of the FR Corner"},
  { dir = 'out', type = 'vec3', name = 'corner_FL', description = "Position of the FL Corner"},
  { dir = 'out', type = 'vec3', name = 'corner_BR', description = "Position of the BR Corner"},
  { dir = 'out', type = 'vec3', name = 'corner_BL', description = "Position of the BL Corner"},
}


C.tags = {'telemtry','vehicle info'}

function C:init(mgr, ...)
end

function C:work(args)
  local veh
  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end
  if not veh then return end
  local oobb = veh:getSpawnWorldOOBB()
  self.pinOut.corner_FL.value = oobb:getPoint(0):toTable()
  self.pinOut.corner_FR.value = oobb:getPoint(3):toTable()
  self.pinOut.corner_BR.value = oobb:getPoint(7):toTable()
  self.pinOut.corner_BL.value = oobb:getPoint(4):toTable()

end

return _flowgraph_createNode(C)
