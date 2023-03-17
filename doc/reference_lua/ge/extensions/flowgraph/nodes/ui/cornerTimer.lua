-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Set UI Timer'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.behaviour = { duration = true }
C.description = "Sets the UI timer app to a specific value."
C.category = 'repeat_instant'
C.author = 'BeamNG'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'value', description = 'Time to show in seconds. If not connected, will clear the time.' },
  { dir = 'in', type = 'string', name = 'color', description = 'Color to use. leave empty for default (white)' },
}
C.tags = {'string','util'}

function C:postInit()
  local temps = {}
  for _, clr in ipairs({'white','red','green','blue'}) do
    table.insert(temps, {label = clr, value = clr})
  end
  self.pinInLocal.color.hardTemplates = temps
end

local raceTimeData = {}
function C:work()
  if self.pinIn.value.value then
    raceTimeData.time = self.pinIn.value.value
    raceTimeData.timeColor = self.pinIn.color.value
    guihooks.trigger('raceTime', raceTimeData)
  else
    guihooks.trigger('ScenarioResetTimer')
  end
end


return _flowgraph_createNode(C)
