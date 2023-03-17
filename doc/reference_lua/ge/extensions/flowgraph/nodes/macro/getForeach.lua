-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Get Foreach'
C.icon = "playlist_play"
C.color = im.ImVec4(0.9,0.2,0.9,.9)
C.description = "If this flowgraph was created by a foreach node, this table will get the Element."
C.category = 'provider'

C.pinSchema = {
    { dir = 'out', type = {'string','id'},  name = 'key', description = 'The Key of this Element.' },
    { dir = 'out', type = {'any'},          name = 'value', description = 'The value of this Element.' },
}

C.tags = {}
C.tags = {"for","for each", "each","list","flowgraph","getforeach", "get for each"}

function C:init(mgr, ...)

end

function C:postInit()

end

function C:_executionStarted()
  self.pinOut.key.value = self.mgr.modules.foreach.key
  self.pinOut.value.value = self.mgr.modules.foreach.value
end



return _flowgraph_createNode(C)
