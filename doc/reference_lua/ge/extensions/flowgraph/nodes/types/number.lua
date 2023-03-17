-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Number'
C.description = "Provides a number."
C.category = 'provider'

C.pinSchema = {
  { dir = 'out', type = 'number', name = 'value', description = 'The numeric value.' },
}


function C:init()
  self.data.value = 0
    self.clearOutPinsOnStart = false
end

function C:work()
  self.pinOut.value.value = self.data.value
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text(tostring(self.data.value))
end

function C:onSerialize(res)
end

function C:onDeserialized(nodeData)
end

return _flowgraph_createNode(C)
