-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Boost Vehicle'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle

C.description = 'Boost your vehicle'
C.category = 'repeat_p_duration'

C.todo = "Dont know if this actually works. Invokes the core_booster extension."
C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Defines the id of the vehicle to boost.' },
  { dir = 'in', type = 'number', name = 'power', description = 'Defines the power of the boost.' },
  { dir = 'in', type = 'number', name = 'dt', description = 'Defines the delta time for the boost.' },
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}

C.tags = {}

function C:work()
  local veh
  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end
  veh:queueLuaCommand('core_booster.boost({'..(self.pinIn.power.value or 0) .. ',0,0},' .. (self.pinIn.dt.value)..')')
end


return _flowgraph_createNode(C)
