-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Get Pause'
C.description = 'Returns if the game is paused or not.'
C.color = ui_flowgraph_editor.nodeColors.ui
C.category = 'provider'
C.icon = 'pause'
C.author = 'BeamNG'

C.pinSchema = {
  { dir = 'out', type = 'bool', name = 'value', description = 'If the game is paused or not.' },
}

C.tags = {'pause', 'freeze', 'halt', 'stop', 'interrupt'}

function C:work()
  self.pinOut.value.value = bullettime.getPause()
end


return _flowgraph_createNode(C)
