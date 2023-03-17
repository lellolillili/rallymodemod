-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Set License Plate'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.behaviour = {once = true}
C.description = 'Changes a vehicle license plate text.'
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.', impulse = true },
  { dir = 'in', type = 'flow', name = 'reset', description = 'Resets this node.', impulse = true },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.', impulse = true },
  { dir = 'in', type = 'number', name = 'vehId', description = 'ID of vehicle to change the plate to. If empty, player vehicle will be used.' },
  { dir = 'in', type = 'string', name = 'text', description = 'Text to use on plate.' },
}
C.tags = {'plate', 'license'}

function C:init(mgr, ...)
  self.ready = true
end

function C:_executionStopped()
  self.ready = true
end

function C:work()

  if self.pinIn.reset.value then
    self.ready = true
    self.pinOut.flow.value = false
  else
    if self.ready then
      if self.pinIn.flow.value then
        local veh = self.pinIn.vehId.value or be:getPlayerVehicleID(0)
        if not veh then return end
        if self.pinIn.text.value ~= '' then
          core_vehicles.setPlateText(self.pinIn.text.value, veh)
        end
        self.pinOut.flow.value = true
        self.ready = false
      else
        self.pinOut.flow.value = false
      end
      else
      self.pinOut.flow.value = false
    end
  end

end

return _flowgraph_createNode(C)
