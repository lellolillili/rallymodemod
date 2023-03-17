-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Reload Nav Graph'
C.description = "Reloads the Nav Graph. Only does so once."
C.category = 'once_instant'

C.pinSchema = {
}
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.tags = {'reload','reset','nav','map'}

function C:workOnce()
  map.reset()
end

return _flowgraph_createNode(C)
