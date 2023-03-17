-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Random Quaternion'
C.tags = {'quaternion', 'random'}
C.description = "Provides a random quaternion."
C.category = 'provider'
C.todo = "Add constraints"

C.pinSchema = {
  { dir = 'out', type = 'quat', name = 'quaternion', description = "The quaternion value." },
}


function C:work()
  local a = math.random(0, 1)
  local b = math.random(0, 1)
  local c = math.random(0, 1)
  local d = math.random(0, 1)
  self.pinOut.quaternion.value = {math.random(), math.random(), math.random(), math.random()}
end

return _flowgraph_createNode(C)
