-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Get Traffic State'
C.description = 'Returns the traffic state and values.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'repeat_instant'
C.tags = {'traffic', 'ai', 'enabled', 'disabled'}

C.pinSchema = {
  {dir = 'out', type = 'flow', name = 'on', description = 'Flows if state is "on".'},
  {dir = 'out', type = 'flow', name = 'spawning', hidden = true, description = 'Flows if state is "spawning".'},
  {dir = 'out', type = 'flow', name = 'loading', hidden = true, description = 'Flows if state is "loading".'},
  {dir = 'out', type = 'flow', name = 'off', description = 'Flows if state is "off".'},
  {dir = 'out', type = 'bool', name = 'onBool', description = 'True if state is "on".'},
  {dir = 'out', type = 'string', name = 'state', description = 'Traffic state.'},
  {dir = 'out', type = 'number', name = 'amount', description = 'Total number of AI traffic vehicles.'},
  {dir = 'out', type = 'number', name = 'activeAmount', hidden = true, description = 'Total number of active AI traffic vehicles, from the vehicle pool.'}
}

local states = {'on', 'off', 'spawning', 'loading'}
function C:work()
  self.pinOut.state.value = self.mgr.modules.traffic:getTrafficState()
  for _, s in ipairs(states) do
    self.pinOut[s].value = self.pinOut.state.value == s
  end
  self.pinOut.onBool.value = self.pinOut.state.value == 'on'
  self.pinOut.amount.value = gameplay_traffic.getNumOfTraffic()
  self.pinOut.activeAmount.value = gameplay_traffic.getNumOfTraffic(true)
end

return _flowgraph_createNode(C)