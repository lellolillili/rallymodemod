-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Custom Vehicle Lua'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.description = 'Calls a custom vehicle lua function.'
C.category = 'repeat_p_duration'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'The Id of the vehicle which will receive the lua command.' },
  { dir = 'in', type = 'string', name = 'func', description = 'The function that will be called in vehicle Lua.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
  { dir = 'out', type = 'number', name = 'vehId', description = "The vehicle this trigger is for.", hidden = true },
}
C.legacyPins = {
  _in = {
    vehicleId = 'vehId'
  },
  out = {
    vehicleId = 'vehId'
  }
}
C.tags = {'vlua','custom vehicle command', 'vehicle code'}

function C:work()
  local veh
  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end
  if not veh or not self.pinIn.func.value then
    return
  end
  veh:queueLuaCommand(self.pinIn.func.value)
  self.pinOut.vehId.value  = self.pinIn.vehId.value
end

function C:drawMiddle(builder, style)
  builder:Middle()
end

function C:_onDeserialized(data)
  if data.data.func then
    data.hardcodedPins = {
      func = {value = data.data.func, type = 'string' }
    }
  end
  self.data.func = nil
end

return _flowgraph_createNode(C)
