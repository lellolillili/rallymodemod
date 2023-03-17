-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local C = {}
C.moduleOrder = 1000 -- low first, high later

function C:init()
  self:clear()
end

function C:clear()
  self.parentGraphId = nil
  self.key = nil
  self.value = nil
end


function C:afterTrigger()

end

function C:executionStopped()

end

function C:executionStarted()
--  self.mgr:logEvent("This FG is a foreach-Child.","I", "Key: " .. dumps(self.key) .. "  \n  Value: " ..  dumps(self.value))
end

return _flowgraph_createModule(C)