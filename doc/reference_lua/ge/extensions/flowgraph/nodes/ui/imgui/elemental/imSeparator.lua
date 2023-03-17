-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'im Separator'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.description = "Makes a Separator in Imgui."
C.category = 'repeat_instant'

C.todo = ""
C.pinSchema = {}


function C:init()
  self.data.aboveSpacing = 5
  self.data.belowSpacing = 5
end
function C:postInit()

end

function C:_executionStarted()
  for _, p in pairs(self.pinOut) do
    p.value = false
  end
end

function C:work()
  if self.data.aboveSpacing > 0 then
    im.Dummy(im.ImVec2(0,self.data.aboveSpacing))
  end
  im.Separator()
  if self.data.belowSpacing > 0 then
    im.Dummy(im.ImVec2(0,self.data.belowSpacing))
  end
end

return _flowgraph_createNode(C)
