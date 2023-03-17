-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Set Camera Mode'
C.description = "Sets the current camera mode."
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'string', name = 'mode', description = 'The current camera mode.' },
}

C.color = ui_flowgraph_editor.nodeColors.camera
C.icon = ui_flowgraph_editor.nodeIcons.camera
C.tags = {'orbit','observer'}
C.dependencies = {'core_camera'}

function C:work()
  if self.pinIn.mode.value and self.pinIn.mode.value ~= "" then
    core_camera.setByName(0,self.pinIn.mode.value)
  end
end

return _flowgraph_createNode(C)
