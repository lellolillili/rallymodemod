-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Move Vehicle To'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle

C.description = [[Moves a Vehicle to a predefined spot and rotates it.]]
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Defines the id of the vehicle to move.' },
  { dir = 'in', type = 'vec3', name = 'pos', description = 'Defines the position to move the vehicle to.' },
  { dir = 'in', type = 'quat', name = 'rot', description = 'Defines the rotation to set the vehicle to.' },
  { dir = 'in', type = 'bool', name = 'safeTeleport', description = 'Use safeTeleport to find a good spot for the vehicle automatically.', hidden=true },
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}
C.tags = {'rotation', 'position', 'move'}

function C:init()
  --self.data.useWheelCenter = false
end

function C:work()
  self:resetVehicle()
end

function C:resetVehicle()
  local veh
  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end
  if not veh then
    return
  end
  local pos = self.pinIn.pos.value
  if not pos or #pos ~= 3 then return end
  local rot = self.pinIn.rot.value or {0,0,0,0}

  --if not rot or #rot ~= 4 then return end
  if self.data.useWheelCenter then
    local wCenter = vec3(0,0,0)
    local wCount = veh:getWheelCount()-1
    if wCount > 0 then
      for i=0, wCount do
        local axisNodes = veh:getWheelAxisNodes(i)
        local nodePos = veh:getNodePosition(axisNodes[1])
        local wheelNodePos = vec3(nodePos.x, nodePos.y, nodePos.z)
        wCenter = wCenter + wheelNodePos
      end
      wCenter = wCenter / (wCount+1)
      wCenter = wCenter:toTable()
    end

    pos[1] = pos[1] - wCenter[1]
    pos[2] = pos[2] - wCenter[2]
    pos[3] = pos[3] - wCenter[3]
  end

  if self.pinIn.safeTeleport.value then
    if not pos or #pos ~= 3 or not rot then return end
    local correctedRot = quat(rot) * quat(0,0,-1,0)
    spawn.safeTeleport(veh, vec3(pos), quat(correctedRot))
  else
    vehicleSetPositionRotation(veh:getId(), pos[1], pos[2], pos[3], rot[1], rot[2], rot[3], rot[4])
  end
end

return _flowgraph_createNode(C)
