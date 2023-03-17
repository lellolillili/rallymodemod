-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Get Table Value By Key'
C.description = "Gets a value from a table using a given key."
C.category = 'repeat_instant'
C.todo = "untested, tables should actually be avoided."

C.pinSchema = {
  { dir = 'in', type = 'table', tableType = 'generic', name = 'value', description = 'Defines the table to get key from.' },
  { dir = 'in', type = { 'string', 'number' }, name = 'key', description = 'Defines the key to get value for.' },
  { dir = 'out', type = 'any', name = 'value', description = 'Puts out the value for the given key.' },
}

C.tags = {}

function C:work()
  if self.pinIn.value.value then
    local res = self.pinIn.value.value[self.pinIn.key.value]
    if res then
      self.pinOut.value.value = res
    end
  else
    self.pinOut.value.value = nil
  end
end

return _flowgraph_createNode(C)
