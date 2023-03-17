-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Get Vehicle Id From Table'
C.description = 'Gets a vehicle from an array of vehicle IDs (such as traffic) via an index.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'repeat_instant'
C.tags = {'id', 'traffic'}


C.pinSchema = {
  {dir = 'in', type = 'table', name = 'vehicleIds', tableType = 'vehicleIds', description = 'Array of vehicle IDs.'},
  {dir = 'in', type = 'number', name = 'index', description = 'Array index.'},
  {dir = 'out', type = 'number', name = 'vehId', description = 'Vehicle Id.'}
}

function C:work()
  self.pinOut.vehId.value = nil

  if self.pinIn.vehicleIds.value and self.pinIn.index.value then
    local id = self.pinIn.vehicleIds.value[self.pinIn.index.value]
    if type(id) == 'number' then
      self.pinOut.vehId.value = id
    end
  end
end

return _flowgraph_createNode(C)