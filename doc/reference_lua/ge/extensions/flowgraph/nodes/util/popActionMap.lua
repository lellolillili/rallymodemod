-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Pop Action Map'
C.description = "Removes an action map from the stack."
C.todo = "Weird behaviour if multiple projects use the same action map."
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'string', name = 'name', description = 'Defines the name of the action map to pop.' },
}

C.tags = {}

function C:init(mgr, ...)
  self:_executionStopped()
end

function C:workOnce()
  popActionMap(self.mapName)
end

return _flowgraph_createNode(C)
