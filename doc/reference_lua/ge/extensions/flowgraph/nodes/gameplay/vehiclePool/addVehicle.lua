-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Add Vehicle (Pool)'
C.description = 'Adds a vehicle to the pool.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'table', name = 'vehPool', tableType = 'vehiclePool', description = 'Vehicle pool object; use the Create Pool node.' },
  { dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle Id.' }
}

C.dependencies = {'core_vehiclePoolingManager'}
C.tags = {'traffic', 'budget', 'pooling'}

function C:workOnce()
  if self.pinIn.vehPool.value and self.pinIn.vehId.value then
    self.pinIn.vehPool.value:insertVeh(self.pinIn.vehId.value)
  end
end

return _flowgraph_createNode(C)