-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Get Vehicle Data'
C.description = 'Provides Vehicle Position, Orientation,Velocities and Damage'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', default = 0, description = "Vehicle ID. If not present, player vehicle will be used." },
  { dir = 'out', type = 'vec3', name = 'position', description = "Position of the ref-node of the vehicle." },
  { dir = 'out', type = 'vec3', name = 'dirVec', description = "Normalized Vec3 of vehicle looking dir." },
  { dir = 'out', type = 'vec3', name = 'dirVecUp', hidden = true, description = "Normalized Vec3 of vehicle up direction." },
  { dir = 'out', type = 'quat', name = 'rotation', hidden = true, description = "Rotation of the vehicle." },
  { dir = 'out', type = 'number', name = 'velocity', description = "Velocity of the Vehicle in m/s." },
  { dir = 'out', type = 'vec3', name = 'velocityVector', hidden = true, description = "Velocity Vec3 of the vehicle." },
  { dir = 'out', type = 'bool', name = 'active', hidden = true, description = "Is the Vehicle active?" },
  { dir = 'out', type = 'number', name = 'damage', description = "Amount of Damage (Not Monetary Value!)" },

}



C.tags = {'telemtry','damage','velocity','direction', 'vehicle info'}

function C:init(mgr, ...)

end
local vehId, vehicleData
function C:work(args)
  vehId = -1
  if self.pinIn.vehId.value then
    local veh = scenetree.findObjectById(self.pinIn.vehId.value)
    if veh then vehId = self.pinIn.vehId.value end
  else
    vehId = be:getPlayerVehicleID(0)
  end
  vehicleData = map.objects[vehId]
  if not vehId then return end


  if vehicleData then

    self.pinOut.active.value = vehicleData.active
    self.pinOut.damage.value = vehicleData.damage
    if self.pinOut.dirVec:isUsed() then
      self.pinOut.dirVec.value = vehicleData.dirVec:toTable()
    end
    if self.pinOut.dirVecUp:isUsed() then
      self.pinOut.dirVecUp.value = vehicleData.dirVecUp:toTable()
    end
    if self.pinOut.position:isUsed() then
      self.pinOut.position.value = vehicleData.pos:toTable()
    end
    if self.pinOut.velocityVector:isUsed() then
      self.pinOut.velocityVector.value = vehicleData.vel:toTable()
    end
    if self.pinOut.velocity:isUsed() then
      self.pinOut.velocity.value = vehicleData.vel:length()
    end
    if self.pinOut.rotation:isUsed() then
      self.pinOut.rotation:valueSetQuat(quatFromDir(vehicleData.dirVec, vehicleData.dirVecUp))
    end
  end
end

return _flowgraph_createNode(C)
