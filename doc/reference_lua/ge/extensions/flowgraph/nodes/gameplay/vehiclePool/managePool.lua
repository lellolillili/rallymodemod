-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Manage Vehicle Pool'
C.description = 'Sets and gets properties of a vehicle pool object.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'table', name = 'vehPool', tableType = 'vehiclePool', description = 'Vehicle pool object; use the Create Pool node.' },
  { dir = 'in', type = 'number', name = 'maxActive', description = 'Maximum active vehicles in the pool.' },

  { dir = 'out', type = 'table', name = 'vehicleIds', tableType = 'vehicleIds', description = 'Table of vehicle IDs.' },
  { dir = 'out', type = 'number', name = 'activeAmount', description = 'Amount of active vehicles in this pool.' },
  { dir = 'out', type = 'number', name = 'inactiveAmount', description = 'Amount of inactive vehicles in this pool.' }
}

C.dependencies = {'core_vehiclePoolingManager'}
C.tags = {'traffic', 'budget', 'pooling'}

function C:init()
  self.data.onlyActiveVehsTable = false
end

function C:workOnce()
  local pool = self.pinIn.vehPool.value

  if pool then
    local amount = self.pinIn.maxActive.value
    if amount and amount >= 0 then
      pool:setMaxActiveVehs(amount)
    else
      pool:setMaxActiveVehs(math.huge)
    end

    local vehIds = self.data.onlyActiveVehsTable and deepcopy(pool.activeVehs) or pool:getVehs()

    self.pinOut.vehicleIds.value = vehIds
    self.pinOut.activeAmount.value = #pool.activeVehs
    self.pinOut.inactiveAmount.value = #pool.inactiveVehs
  end
end

return _flowgraph_createNode(C)