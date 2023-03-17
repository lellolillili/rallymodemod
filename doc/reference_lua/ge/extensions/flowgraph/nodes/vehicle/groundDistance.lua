-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}

C.name = 'Distance from ground'

C.description = [[Reports the distance of the lowest vehicle's bounding box point from the terrain below.]]
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = "ID of the vehicle to use." },
  { dir = 'in', type = 'number', name = 'zOffset', hidden = true, default = 10, hardcoded = true, description = "Adjust the initial height of the raycast. Increase this if you are getting infinite values when the car is too close to the terrain." },
  { dir = 'out', type = 'number', name = 'lowestDistance', description = "Distance of the lowest point from the terrain below." },
}

C.tags = {'gameplay', 'utils'}
function C:init()
  self.data.drawDebug = false
end

function C:work()
  if not self.pinIn.vehId.value then return end

  local veh = scenetree.findObjectById(self.pinIn.vehId.value)
  if not veh then return end
  local oobb = veh:getSpawnWorldOOBB()
  if not oobb then return end
  local lowest = math.huge

  for i = 0, 7 do
    local point = vec3(oobb:getPoint(i))
    local hit = be:getSurfaceHeightBelow((point + vec3(0,0,self.pinIn.zOffset.value)))
    if hit then
      lowest = math.min(lowest, (point.z - hit))
      if self.data.drawDebug then
        debugDrawer:drawTextAdvanced(point, String(string.format("%0.3f",point.z - hit)), ColorF(1,1,1,1), true, false, ColorI(0,0,0,192))
      end
    end
  end

  self.pinOut.lowestDistance.value = lowest
end

return _flowgraph_createNode(C)