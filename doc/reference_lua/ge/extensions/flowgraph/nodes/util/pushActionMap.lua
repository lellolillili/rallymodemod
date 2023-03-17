-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Push Action Map'
C.description = "Pushed an action map on the stack."
C.category = 'once_instant'
C.todo = "Weird behaviour if multiple projects use the same action map."

C.pinSchema = {
  { dir = 'in', type = 'string', name = 'name', description = 'Defines the name of the action map to push.' },
}

C.tags = {}

function C:init(mgr, ...)
  self:_executionStopped()
end

function C:_executionStopped()
  if self.mapName then
    popActionMap(self.mapName)
    self.mapName = nil
  end
end

function C:workOnce()
  self.mapName = self.pinIn.name.value
  pushActionMap(self.mapName)
end

function C:drawMiddle(builder, style)
  if self.mapName then
    im.Text(self.mapName .. " pushed.")
  end
end


return _flowgraph_createNode(C)
