-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Multiseat'
C.description = 'Enables Multiseat.'
C.category = 'once_instant'

C.pinSchema = {
}

function C:init(mgr, ...)
  self.activated = false
end

function C:_executionStarted()
  self.activated = false
end

function C:workOnce()
  self.activated = true
  self.previous =  settings.getValue('multiseat', false)
  settings.setValue('multiseat', true)
end

function C:_executionStopped()
  if self.activated then
    settings.setValue('multiseat', self.previous)
    self.activated = false
    self.previous = nil
  end
end

return _flowgraph_createNode(C)
