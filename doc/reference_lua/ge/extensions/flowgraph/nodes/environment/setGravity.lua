-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Set Gravity'
C.description = "Sets the global gravity."
C.category = 'dynamic_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'value', hardcoded = true, default = 0, description = 'Gravity in m/s^2.' },
}

C.tags = {}

function C:init(mgr)
  self.data.restoreGravity = true
end

function C:_executionStarted()
  self.storedGravity = core_environment.getGravity()
end
function C:_executionStopped()
  if self.data.restoreGravity and self.storedGravity then
    core_environment.setGravity(self.storedGravity)
    self.storedGravity = nil
  end
end

function C:workOnce()
  core_environment.setGravity(self.pinIn.value.value)
end

function C:work()
  if self.dynamicMode == 'repeat' then
    if self.pinInLocal.value:isUsed() then
      core_environment.setGravity(self.pinIn.value.value)
    end
  end
end

return _flowgraph_createNode(C)
