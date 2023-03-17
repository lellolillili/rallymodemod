-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'RequestBusStopsApp'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.behaviour = { duration = true }
C.description = "Determine if the passengers will send a bus stop request."
C.category = 'repeat_instant'
C.todo = ""
C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = "Inflow for this node."},
  {dir = 'in', type = 'bool', name = 'requestStop', description = "Determines if passengers have requested a stop or not."},
  {dir = 'in', type = 'number', name = 'vehId', default = 0, description = "Vehicle ID. If not present, player vehicle will be used."},
  {dir = 'out', type = 'flow', name = 'flow', description = "Outflow for this node."}
}

C.tags = {'string','util'}

function C:_executionStarted()
end

function C:work()
  self.pinOut.flow.value = false
  self.mgr.modules.vehicle:requestBusStop(self.pinIn.vehId.value, {stopRequested = self.pinIn.requestStop.value})
  self.pinOut.flow.value = true
end

return _flowgraph_createNode(C)