-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Set UI Race Recovery'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.behaviour = { duration = true }
C.description = "Sets the UI Race Recoveries Used app to a specific value."
C.category = 'repeat_instant'
C.author = 'BeamNG'

C.pinSchema = {
  { dir = 'in', type = {'number', 'string'}, name = 'cur', description = 'Number of Recoveries Used.' },
  { dir = 'in', type = 'number', name = 'max', description = 'Max Number of Recoveries available.' },

}
C.tags = {'string','util'}


function C:work()
  if self.pinIn.cur.value and self.pinIn.flow.value then
    if type(self.pinIn.cur.value) == 'string' then
      guihooks.trigger('RaceRecoveryCounterSet', self.pinIn.cur.value)
    else
      if self.pinIn.max.value then
        guihooks.trigger('RaceRecoveryCounterSet', string.format("Recoveries Used: %d / %d",self.pinIn.cur.value, self.pinIn.max.value))
      else
        guihooks.trigger('RaceRecoveryCounterSet', string.format("Recoveries Used: %d",self.pinIn.cur.value))
      end
    end
  else
    guihooks.trigger('RaceRecoveryCounterReset')
  end
end


return _flowgraph_createNode(C)
