-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'onVehicleSpawned'
C.description = 'Triggers when a new vehicle is spawned.'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.category = 'logic'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.', impulse = true },
  { dir = 'out', type = 'number', name = 'vehId', description = 'Id of vehicle that was spawned.' },
}

C.legacyPins = {
  out = {
    vehicleID = 'vehId'
  },
}


function C:init(mgr, ...)

end

function C:_executionStarted()
  self.flag = false
  self.info = {}
end

function C:onVehicleSpawned(id)
  self.info.id = id
  self.flag = true
end

function C:work(args)
  if self.flag then
    self.pinOut.vehId.value = self.info.id
    self.pinOut.flow.value = true
    self.flag = false
  else
    self.pinOut.flow.value = false
  end
end

function C:_afterTrigger()
  self.flag = false
end

return _flowgraph_createNode(C)
