-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Get Camera Mode'
C.description = "Gets the current camera mode."
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'out', type = 'string', name = 'mode', description = 'The current camera mode.' },
}

C.color = ui_flowgraph_editor.nodeColors.camera
C.icon = ui_flowgraph_editor.nodeIcons.camera
C.tags = {'orbit','observer'}
C.dependencies = {'core_camera'}

function C:work()
  self.pinOut.mode.value = core_camera.getActiveCamName(0)
end

return _flowgraph_createNode(C)
