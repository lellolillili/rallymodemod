-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

--require('/lua/vehicle/controller')

local C = {}

C.name = 'Check Players Position'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Detects the trigger of the star line for the player.'
C.todo = ""
C.category = 'repeat_instant'

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = "Inflow for this node."},
  {dir = 'in', type = 'flow', name = 'reset', description = 'Reset this node.', impulse = true},
  {dir = 'in', type = 'number', name = 'vehId', description = 'Id of the vehicle.'},
  {dir = 'in', type = 'number', name = 'distance', description = 'Distance of the center of the closets wheels to a position.'},
  {dir = 'in', type = 'number', name = 'velocity', description = 'Velocity of the vehicle.'},
  {dir = 'out', type = 'flow', name = 'flow', description = "Outflow for this node."},
  {dir = 'out', type = 'flow', name = 'inLine', description = "Outflow if the vehicle is in position."},
  {dir = 'out', type = 'flow', name = 'outLineForward', description = "Outflow when the vehicle is not in position."},
  {dir = 'out', type = 'flow', name = 'outLineBackward', description = "Outflow when the vehicle is not in position."}
}

C.legacyPins = {
  _in = {
    vehicleID = 'vehId'
  },
}

function C:_executionStarted()
  self.vehicle = self.mgr.modules.vehicle:getVehicle(self.pinIn.vehId.value) or nil
end

function C:init()
  self.vehicle = nil
end

function C:work()
  if self.pinIn.reset.value then
    self.pinOut.outLineForward.value = false
    self.pinOut.outLineBackward.value = false
    self.pinOut.inLine.value = false
    return
  end

  if self.pinIn.distance.value then
    if self.pinIn.distance.value > 0.35 then
      --guihooks.trigger('Message', {ttl = 0.25, msg = "Align your front wheels with the starting line. (Move forward)", category = "align", icon = "arrow_upward"})
      self.pinOut.outLineForward.value = true
      self.pinOut.outLineBackward.value = false
      self.pinOut.inLine.value = false

    elseif self.pinIn.distance.value < 0 then
      --guihooks.trigger('Message', {ttl = 0.25, msg = "Align your front wheels with the starting line. (Move backward)", category = "align", icon = "arrow_downward"})
      self.pinOut.outLineBackward.value = true
      self.pinOut.outLineForward.value = false
      self.pinOut.inLine.value = false
    else
      --guihooks.trigger('Message', {ttl = 0.25, msg = "Stop your vehicle now.", category = "align", icon = "check"})
      self.pinOut.outLineForward.value = false
      self.pinOut.outLineBackward.value = false
      self.pinOut.inLine.value = true
    end
  end
end

return _flowgraph_createNode(C)
