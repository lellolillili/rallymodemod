-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'UpdateBusStopsApp'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.behaviour = { duration = true }
C.description = "Update the bus stops App."
C.category = 'repeat_instant'
C.todo = ""
C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = "Inflow for this node."},
  {dir = 'in', type = 'table', tableType = 'busRouteStops', name = 'stopsRoute', description = 'Last route of the mission.'},
  {dir = 'in', type = 'number', name = 'stopIdx', description = "The index of the actual stop."},
  {dir = 'in', type = 'number', name = 'vehId', default = 0, description = "Vehicle ID. If not present, player vehicle will be used."},
  {dir = 'out', type = 'flow', name = 'flow', description = "Outflow for this node."},
}

C.tags = {'string','util'}

function C:_executionStarted()
end

function C:work()
  self.pinOut.flow.value = false

  local Route = self.pinIn.stopsRoute.value or {}
  -- put all the items into a list
  local out = {}
  local targetObj = nil
  for nameCount = self.pinIn.stopIdx.value, #Route do
    targetObj = scenetree.findObject(Route[nameCount])
    table.insert(out, {0, targetObj:getDynDataFieldbyName("stopname", 0)})
  end
  self.mgr.modules.vehicle:updateBusDisplayData(self.pinIn.vehId.value, {tasklist= out})
  self.pinOut.flow.value = true
end

return _flowgraph_createNode(C)