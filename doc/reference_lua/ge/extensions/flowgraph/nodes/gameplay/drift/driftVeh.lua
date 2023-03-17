-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}

C.name = 'Drift Veh'

C.description = "Set the drift vehicle, if none specified, player's vehicle will be taken"
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'flow', impulse = true, name = 'setVehId', description = "When flow, the vehicle id will be changed"},

  { dir = 'in', type = 'number', name = 'vehId', description = "The vehicle id to use as a reference for the drift module"},
  { dir = 'out', type = 'number', name = 'vehId', description = "The vehicle id used as a reference for the drift module"},
}

C.tags = {'gameplay', 'utils'}

function C:work()
  if self.pinIn.setVehId.value then
    self.mgr.modules.drift:setVehId(self.pinIn.vehId.value)
  end

  self.pinOut.vehId.value = self.mgr.modules.drift:getVehId()
end

return _flowgraph_createNode(C)