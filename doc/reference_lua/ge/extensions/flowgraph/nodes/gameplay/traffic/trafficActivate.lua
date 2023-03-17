-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Traffic Activator'
C.description = 'Enables traffic mode and sets vehicles to act as traffic.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'once_instant'
C.tags = {'traffic', 'ai', 'activate', 'enable'}


C.pinSchema = {
  { dir = 'in', type = 'table', name = 'vehicleIds', tableType = 'vehicleIds', description = 'Table of vehicle ids; use the Spawn Vehicle Group node.' },

  { dir = 'out', type = 'flow', name = 'activated', impulse = true, description = 'Flows once after traffic gets activated.' },
  { dir = 'out', type = 'table', name = 'vehicleIds', tableType = 'vehicleIds', description = 'Table of active and validated vehicle ids.' },
  { dir = 'out', type = 'number', name = 'total', hidden = true, description = 'Total number of AI traffic vehicles.' }
}
C.legacyPins = {
  _in = {
    data = 'vehicleIds'
  }
}

function C:init()
  self:onNodeReset()
end

function C:_executionStopped()
  self:onNodeReset()
end

function C:onNodeReset()
  self.mgr.modules.traffic:deactivateTraffic()
  self.flags = {activated = false}
  self.vehIds = nil
end

function C:workOnce()
  self.vehIds = self.pinIn.vehicleIds.value
  if self.vehIds then
    self.mgr.modules.traffic:activateTraffic(self.vehIds)
    self.flags.activated = true
  end

  self.pinOut.vehicleIds.value = gameplay_traffic.getTrafficList()
end

function C:work()
  self.pinOut.total.value = gameplay_traffic.getNumOfTraffic()
  self.pinOut.activated.value = self.flags.activated
  self.flags.activated = false
end

return _flowgraph_createNode(C)