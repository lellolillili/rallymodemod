-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Set UI Race Laps'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.behaviour = { duration = true }
C.description = "Sets the UI Race Laps app to a specific value."
C.category = 'repeat_instant'
C.author = 'BeamNG'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'cur', description = 'Current lap. If not set, will clear the app.' },
  { dir = 'in', type = 'number', name = 'max', description = 'Maximum laps.' },
}
C.tags = {'string','util'}


function C:work()
  if self.pinIn.cur.value then
    guihooks.trigger('RaceLapChangeCustom', {current = self.pinIn.cur.value, count = self.pinIn.max.value})
  else
    guihooks.trigger('RaceLapClear')
  end
end


return _flowgraph_createNode(C)
