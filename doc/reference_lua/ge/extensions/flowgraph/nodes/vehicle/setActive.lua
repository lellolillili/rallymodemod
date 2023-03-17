-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Set Active'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Sets the active state of a vehicle (visible / invisible).'
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Id of vehicle to set visibility for; if none given, the player vehicle will be used.' },
  { dir = 'in', type = 'bool', name = 'active', description = 'Visibility state.' }
}

function C:workOnce()
  local obj
  if self.pinIn.vehId.value then
    obj = be:getObjectByID(self.pinIn.vehId.value)
  else
    obj = be:getPlayerVehicle(0)
  end

  if obj then
    obj:setActive(self.pinIn.active.value and 1 or 0)
  end
end

return _flowgraph_createNode(C)
