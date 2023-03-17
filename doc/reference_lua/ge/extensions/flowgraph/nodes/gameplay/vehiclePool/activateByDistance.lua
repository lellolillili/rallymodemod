-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Activate Vehicles By Distance'
C.description = 'Activates or deactivates all vehicles in the pool based on distance to a given point.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'table', name = 'vehPool', tableType = 'vehiclePool', description = 'Vehicle pool object; use the Create Pool node.' },
  { dir = 'in', type = 'vec3', name = 'pos', description = 'Focus position; if none given, uses the camera position.' },
  { dir = 'in', type = 'number', name = 'distance', description = 'Maximum distance to keep vehicles activated.' },
}

C.dependencies = {'core_vehiclePoolingManager'}
C.tags = {'traffic', 'budget', 'pooling'}

function C:work()
  if self.pinIn.vehPool.value then
    local pos = self.pinIn.pos.value and vec3(self.pinIn.pos.value) or vec3(getCameraPosition())
    self.pinIn.vehPool.value:activateByDistanceTo(pos, self.pinIn.distance.value)
  end
end

return _flowgraph_createNode(C)