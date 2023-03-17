-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Is Player usable'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Whether or no a vehicle is usable'
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle to check, if useable.' },
  { dir = 'out', type = 'flow', name = 'true', description = 'Puts out flow, if vehicle was useable.' },
  { dir = 'out', type = 'flow', name = 'false', description = 'Puts out flow, if vehicle was not useable.' },
}

C.legacyPins = {
  _in = {
    vehiId = 'vehId'
  },
}
function C:init()

end


function C:work()
  local source
  if self.pinIn.vehId.value and self.pinIn.vehId.value ~= 0 then
    source = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    --source = be:getPlayerVehicle(0)
  end
  self.pinOut['true'].value = source.playerUsable
  self.pinOut['false'].value = not self.pinOut['true'].value
end


return _flowgraph_createNode(C)
