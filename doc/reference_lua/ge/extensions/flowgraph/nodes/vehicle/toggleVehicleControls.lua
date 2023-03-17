-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Toggle Vehicle Controls'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Sets wether or not a vehicle should be able to be controlled by the player.'
C.todo = "PlayerUsable has some bugs and only works the first time."
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'bool', name = 'controllable', description = 'Should the vehicle be controllable by the player.' },
}

function C:init()

end


function C:work()
  local o = scenetree.findObject("VehicleCommonActionMap")
  if o then o:setEnabled(self.pinIn.controllable.value) end
end

function C:_executionStopped()
  -- undo all stuff you did
  local o = scenetree.findObject("VehicleCommonActionMap")
  if o then o:setEnabled(true) end
end


return _flowgraph_createNode(C)
