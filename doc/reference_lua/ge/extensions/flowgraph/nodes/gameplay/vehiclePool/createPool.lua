-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Create Vehicle Pool'
C.description = 'Creates a new vehicle pool object to manage activation and deactivation of vehicle objects.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'string', name = 'name', hidden = true, description = 'Vehicle pool name.' },
  { dir = 'out', type = 'table', name = 'vehPool', tableType = 'vehiclePool', description = 'Vehicle pool object.' }
}

C.dependencies = {'core_vehiclePoolingManager'}
C.tags = {'traffic', 'budget', 'pooling'}

function C:init()
  self:onNodeReset()
end

function C:_executionStopped()
  self:onNodeReset()
end

function C:onNodeReset()
  if self.vehPool then
    self.vehPool:deletePool(self.data.keepVehicles)
    self.vehPool = nil
  end
end

function C:drawCustomProperties()
  local var = im.BoolPtr(self.data.keepVehicles and true or false)
  if im.Checkbox('Keep Inactive Vehicles', var) then
    self.data.keepVehicles = var[0]
  end
end

function C:workOnce()
  if not self.vehPool then
    self.vehPool = core_vehiclePoolingManager.createPool({name = self.pinIn.name.value})
  end
  self.pinOut.vehPool.value = self.vehPool
end

return _flowgraph_createNode(C)