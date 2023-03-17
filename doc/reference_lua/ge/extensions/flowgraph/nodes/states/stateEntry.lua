-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ufe = ui_flowgraph_editor
local C = {}

C.name = 'State Entry'
C.icon = "trending_down"
C.description = [[Entry point for this stategraph.]]

C.pinSchema = {
  {dir = 'out', type = 'state', name = 'flow', description = "This is a flow pin."},
}
C.hidden = true
C.color = im.ImVec4(0.4, 1, 0.4, 1)
C.undeleteable = true
C.uncopyable = true
C.type = 'node' --


return _flowgraph_createStateNode(C)
