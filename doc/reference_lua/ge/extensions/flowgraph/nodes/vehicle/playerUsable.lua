-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Player usable'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Sets wether or not a vehicle should be able to be controlled by the player.'
C.todo = "PlayerUsable has some bugs and only works the first time."
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Id of vehicle to set usability for.' },
  { dir = 'in', type = 'bool', name = 'controllable', description = 'Should the vehicle be useable by the player or not.' },
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

  source.obj.playerUsable = self.pinIn.controllable.value
end


return _flowgraph_createNode(C)
