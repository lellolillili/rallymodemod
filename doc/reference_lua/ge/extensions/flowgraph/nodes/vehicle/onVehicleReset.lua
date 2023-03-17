-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'on Vehicle Reset'
C.description = 'Detects when a vehicle is reset.'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.category = 'logic'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.', impulse = true },
  { dir = 'in', type = 'number', name = 'vehId', description = 'If has a value, will onyl trigger for that vehicle.' },
  { dir = 'out', type = 'number', name = 'vehId', hidden = true, description = 'Id of vehicle that was reset.' },
}
C.legacyPins = {
  _in = {
    vehicleID = 'vehId'
  },
  out = {
    vehicleID = 'vehId'
  }
}



function C:init(mgr, ...)

end

function C:_executionStarted()
  self.flag = false
  self.info = {}
end

function C:onVehicleResetted(id)
  if self.pinIn.vehId.value then
    if id == self.pinIn.vehId.value then
      self.info.id = id
      self.flag = true
    end
  else
    self.info.id = id
    self.flag = true
  end
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
