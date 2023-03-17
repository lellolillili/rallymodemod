-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}

C.name = 'Drift Donut'

C.description = "Detect Donuts"
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'out', type = 'flow', impulse = true, name = 'donutDrift', description = "Will fire when a donut is detected"},
  { dir = 'out', type = 'number', name = 'donutScore', description = "The score obtained from the donut"},
}

C.tags = {'gameplay', 'utils'}

local callbacks
function C:work()
  callbacks = self.mgr.modules.drift:getCallBacks()

  self.pinOut.donutDrift.value = callbacks.donut
  self.pinOut.donutScore.value = callbacks.donut

end

return _flowgraph_createNode(C)