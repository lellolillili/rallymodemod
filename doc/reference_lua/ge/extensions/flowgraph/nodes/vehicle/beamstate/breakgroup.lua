-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Breakgroup'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.behaviour = { duration = true }
C.description = [[Breaks a breakgroup.
Uses player vehicle if no ID is given.]]
C.category = 'repeat_p_duration'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Defines the id of the vehicle.' },
  { dir = 'in', type = 'string', name = 'group', default = "*", description = "Groups to break. Can be a table or a singular string." }
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}
C.tags = {'destroy'}

function C:work()
  if self.pinIn.group.value == nil then
    return
  end

  local veh
  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end
  if not veh then
    log('E', '', 'Vehicle not found')
    return
  end

  local groups
  if type(self.pinIn.group.value == 'string') then
    if self.pinIn.group.value == '*' then
      veh:queueLuaCommand("beamstate.breakAllBreakgroups()")
    else
      groups = {self.pinIn.group.value}
    end
  else -- table
    groups = self.pinIn.group.value
  end
  if groups then
    for _,g in pairs(groups) do
      veh:queueLuaCommand("beamstate.breakBreakGroup('" .. g .. "')")
    end
  end
end

return _flowgraph_createNode(C)
