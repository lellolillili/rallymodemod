-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Freeze Vehicle'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle

C.description = 'Freezes or unfreezes a vehicle. If no ID is given, the current player vehicle is used.'
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Defines the id of the vehicle to freeze.' },
  { dir = 'in', type = 'bool', name = 'freeze', description = 'Defines if the vehicle should be frozen.' },
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}
C.tags = {}

function C:init()

end

function C:work()
  local veh
  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end
  if veh then
    --veh:queueLuaCommand('controller.setFreeze('..(self.pinIn.freeze.value and '1' or '0')..')')
    core_vehicleBridge.executeAction(veh,'setFreeze', self.pinIn.freeze.value)
  end
end


return _flowgraph_createNode(C)
