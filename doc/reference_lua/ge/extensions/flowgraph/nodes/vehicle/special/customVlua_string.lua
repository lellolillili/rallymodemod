-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Custom vlua - deprecated'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.description = 'Deprecated vlua node.'
C.category = 'repeat_p_duration'

C.pinSchema = {
  { dir = 'in', type = 'string', name = 'customLUA', description = "The message that will be displayed. Bug: can not start directly with a number." },
  { dir = 'in', type = 'number', name = 'vehId', description = 'Defines the id of the vehicle to apply lua code to.' },
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}
C.tags = {}
C.obsolete = "Replaced by Custom vlua node."

function C:init()
  self.data.func = self.pinIn.customLUAString.value
end



function C:work()
  local customLUAString
  local veh
  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  customLUAString = self.pinIn.customLUA.value
  end
  if not veh then
    return
  end
  veh:queueLuaCommand(customLUAString)


end

function C:drawMiddle(builder, style)
  builder:Middle()
end



return _flowgraph_createNode(C)
