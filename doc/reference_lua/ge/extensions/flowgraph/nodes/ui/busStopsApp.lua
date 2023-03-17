-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'BusStopsApp'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.behaviour = { duration = true }
C.description = "Update the bus stops App."
C.category = 'repeat_instant'
C.todo = ""
C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = "Inflow for this node."},
  {dir = 'out', type = 'flow', name = 'flow', description = "Outflow for this node."},
  {dir = 'in', type = 'string', name = 'direction', description = "Direction of the bus route."},
  {dir = 'in', type = 'string', name = 'routeId', description = "Id of the bus route."},
  {dir = 'in', type = 'string', name = 'ColorHex', description = "Color of the route in hexadecimal."},
  {dir = 'in', type = 'number', name = 'stopIdx', description = "The index of the actual stop."},
  { dir = 'in', type = 'number', name = 'vehId', default = 0, description = "Vehicle ID. If not present, player vehicle will be used." }
}

C.tags = {'string','util'}

function C:_executionStarted()
end

function C:work()
  local Route = self.mgr.activity.missionTypeData.tasklist or {}
  local Dir = self.pinIn.direction.value
  local RouteId = self.pinIn.routeId.value
  local RouteColor = self.pinIn.ColorHex.value

  -- reset all out pins
  self.pinOut.flow.value = false

  -- put all the items into a list

  local out = {}
  local targetObj = nil
  for nameCount = self.pinIn.stopIdx.value, #Route do
    targetObj = scenetree.findObject(Route[nameCount])
    table.insert(out, {0, targetObj:getDynDataFieldbyName("stopname", 0)})
  end

  --guihooks.trigger('BusDisplayUpdate', {routeId = RouteId, direction = Dir, routeColor= RouteColor, tasklist= out})
  self.mgr.modules.vehicle:updateBusDisplayData(self.pinIn.vehId.value, {routeID = RouteId, direction = Dir, routeColor= RouteColor, tasklist= out})

  self.pinOut.flow.value = true
end

return _flowgraph_createNode(C)
