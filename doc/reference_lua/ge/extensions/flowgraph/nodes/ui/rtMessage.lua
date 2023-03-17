-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'RT Message'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.description = "Shows a Message using the ScenarioRealtimeMessage method. Needs to be erased manually."
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'any', name = 'message', description = 'Defines the text to display.' },
  { dir = 'in', type = 'flow', name = 'clear', description = 'Clears RT message.', impulse = true },
}

C.tags = {'string','util'}

function C:init()

end
function C:_executionStopped()
  guihooks.trigger('ScenarioRealtimeDisplay', {msg = ""})
end

local messageData = {}
function C:work()
  if self.pinIn.clear.value then
    table.clear(messageData)
    messageData.msg = ""
    guihooks.trigger('ScenarioRealtimeDisplay', messageData)
  else
    if self.pinIn.flow.value then
      if type(self.pinIn.message.value) == 'table' then
        -- this app wants the message in a different format :/
        messageData.msg = self.pinIn.message.value.txt
        messageData.context = self.pinIn.message.value.context
        guihooks.trigger('ScenarioRealtimeDisplay', messageData)
      else
        table.clear(messageData)
        messageData.msg = self.pinIn.message.value
        guihooks.trigger('ScenarioRealtimeDisplay', {msg = self.pinIn.message.value})
      end
    end
  end
end

return _flowgraph_createNode(C)
