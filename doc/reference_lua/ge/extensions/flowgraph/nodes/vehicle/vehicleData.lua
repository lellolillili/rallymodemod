-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Get Vehicle Data'
C.description = 'Provides some vehicle related data.'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.category = 'repeat_instant'

C.obsolete = "Replaced by a new vehicle data, vehicle OOBB and vehicle wheels node."
C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', default = 0, description = "Vehicle ID. If not present, player vehicle will be used." },
  { dir = 'out', type = 'bool', name = 'active', hidden = true, description = "Is the Vehicle active?" },
  { dir = 'out', type = 'number', name = 'damage', description = "Amount of Damage (Not Monetary Value!)" },
  { dir = 'out', type = 'vec3', name = 'dirVec', description = "Normalized Vec3 of vehicle looking dir." },
  { dir = 'out', type = 'vec3', name = 'dirVecUp', hidden = true, description = "Normalized Vec3 of vehicle up direction." },
  { dir = 'out', type = 'quat', name = 'rotation', hidden = true, description = "Rotation of the vehicle." },
  { dir = 'out', type = 'vec3', name = 'position', description = "Position of the ref-node of the vehicle." },
  { dir = 'out', type = 'vec3', name = 'corner_FR', description = "Position of the FR Corner" , hidden=true},
  { dir = 'out', type = 'vec3', name = 'corner_FL', description = "Position of the FL Corner" , hidden=true },
  { dir = 'out', type = 'vec3', name = 'corner_BR', description = "Position of the BR Corner" , hidden=true },
  { dir = 'out', type = 'vec3', name = 'corner_BL', description = "Position of the BL Corner" , hidden=true },
  { dir = 'out', type = 'vec3', name = 'wheelCenter', description = "Average of all wheel positions." },
  { dir = 'out', type = 'vec3', name = 'velocityVector', hidden = true, description = "Velocity Vec3 of the vehicle." },
  { dir = 'out', type = 'number', name = 'velocity', description = "Velocity of the Vehicle in m/s." },

  --{dir = 'out', type = 'string', name = 'model', hidden=true, description = "Model of this vehicle."},
  --{dir = 'out', type = 'string', name = 'config', hidden=true, description = "Config of this vehicle."},
}

C.legacyPins = {
  _in = {
    vehicleID = 'vehId'
  },
}

C.tags = {'telemtry','damage','velocity','direction', 'vehicle info'}

function C:init(mgr, ...)

end

local veh, vehicleData
local wCenter = vec3()
function C:work(args)


  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end
  if not veh then return end

  vehicleData = map.objects[veh:getId()]

  if vehicleData then
    self.pinOut.active.value = vehicleData.active
    self.pinOut.damage.value = vehicleData.damage
    self.pinOut.dirVec.value = vehicleData.dirVec:toTable()
    self.pinOut.dirVecUp.value = vehicleData.dirVecUp:toTable()
    self.pinOut.position.value = vehicleData.pos:toTable()
    self.pinOut.velocityVector.value = vehicleData.vel:toTable()
    self.pinOut.velocity.value = vehicleData.vel:length()
    self.pinOut.rotation:valueSetQuat(quatFromDir(vehicleData.dirVec, vehicleData.dirVecUp))

    wCenter:set(0,0,0)
    local wCount = veh:getWheelCount()-1
    if wCount > 0 then
      for i=0, wCount do
        local axisNodes = veh:getWheelAxisNodes(i)
        local nodePos = veh:getNodePosition(axisNodes[1])
        local wheelNodePos = vec3(nodePos.x, nodePos.y, nodePos.z)
        wCenter = wCenter + wheelNodePos
      end
      wCenter = wCenter / (wCount+1)
      wCenter = wCenter + vehicleData.pos
    end
    self.pinOut.wheelCenter.value = wCenter:toTable()

    local oobb = veh:getSpawnWorldOOBB()
    self.pinOut.corner_FL.value = oobb:getPoint(0):toTable()
    self.pinOut.corner_FR.value = oobb:getPoint(3):toTable()
    self.pinOut.corner_BR.value = oobb:getPoint(7):toTable()
    self.pinOut.corner_BL.value = oobb:getPoint(4):toTable()

    --[[
    -- disabled due to not working
      local extract = extractVehicleData(veh:getId())
      self.pinOut.model.value = extract.model
      self.pinOut.config.value = extract.config
    ]]
  end
end

return _flowgraph_createNode(C)
