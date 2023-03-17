-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Set Lightbar'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle

C.description = 'Sets the lightbar for the vehicle. This is usually on top of the car. If no ID is given, the current player vehicle is used.'
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Id of the vehicle to affect.' },
  { dir = 'in', type = 'number', name = 'mode', description = 'Lightmode to set.' },
}

C.tags = {}

function C:init()

end
function C:postInit()
  self.pinInLocal.mode.hardTemplates = {{value = 0, label='Off' },{value = 1, label='On'}, {value=2, label='Siren'}}
end

function C:work()
  local veh
  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end
  if veh then
    core_vehicleBridge.executeAction(veh,'setLightbarMode', self.pinIn.mode.value)
  end
end


return _flowgraph_createNode(C)
