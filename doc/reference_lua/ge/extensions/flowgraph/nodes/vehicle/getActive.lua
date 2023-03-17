-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Get Active'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Gets the active state of a vehicle (visible / invisible).'
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Id of vehicle to set visibility for; if none given, the player vehicle will be used.' },
  { dir = 'out', type = 'flow', name = 'true', description = 'Vehicle is active (visible).' },
  { dir = 'out', type = 'flow', name = 'false', description = 'Vehicle is inactive (invisible).' },
  { dir = 'out', type = 'bool', name = 'isActive', description = 'Visibility state.' }
}

function C:work()
  local obj
  if self.pinIn.vehId.value then
    obj = be:getObjectByID(self.pinIn.vehId.value)
  else
    obj = be:getPlayerVehicle(0)
  end

  if obj then
    local isActive = obj:getActive()
    self.pinOut['true'].value = isActive
    self.pinOut['false'].value = not isActive
    self.pinOut.isActive.value = isActive
  end
end

return _flowgraph_createNode(C)
