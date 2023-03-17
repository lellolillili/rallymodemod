-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Get Vehicle Wheel Center'
C.description = 'Provides Vehicle front wheel center.'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', default = 0, description = "Vehicle ID. If not present, player vehicle will be used." },
  { dir = 'out', type = 'vec3', name = 'wheelCenter', description = "Average of all wheel positions." },
}
C.tags = {'telemtry','vehicle info'}

function C:init(mgr, ...)
end

local wCenter = vec3()
function C:work(args)
  local veh
  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end
  if not veh then return end

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
    wCenter = wCenter + veh:getPosition()
  end
  self.pinOut.wheelCenter.value = wCenter:toTable()

end

return _flowgraph_createNode(C)
