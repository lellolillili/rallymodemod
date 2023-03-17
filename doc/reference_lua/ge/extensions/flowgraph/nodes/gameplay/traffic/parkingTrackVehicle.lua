-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = 'Track Vehicle Parking'
C.description = 'Tracks the parking status of a target vehicle while the parking system is active.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
-- C.category = 'repeat_instant'
C.tags = {'traffic', 'parking'}

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow' },
  { dir = 'in', type = 'flow', name = 'reset', impulse = true },
  { dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle id to track' },

  { dir = 'out', type = 'flow', name = 'flow'},
  { dir = 'out', type = 'flow', name = 'enter', impulse = true, description = 'Sends a pulse when the vehicle is parking.'},
  { dir = 'out', type = 'flow', name = 'inside', description = 'True while the vehicle is parking.'},
  { dir = 'out', type = 'flow', name = 'exit', impulse = true, description = 'Sends a pulse when the vehicle is not parking.'},
  { dir = 'out', type = 'flow', name = 'outside', description = 'True while the vehicle is not parking.'},
  { dir = 'out', type = 'flow', name = 'spotExists', description = 'Sends flow while a target parking spot exists.'},
  { dir = 'out', type = 'table', name = 'spot', tableType = 'parkingSpotData', description = 'Current target parking spot.' }
}

function C:init()
  self:reset()
end

function C:_executionStopped()
  self:reset()
end

function C:reset()
  if self.pinIn.vehId.value then
    gameplay_parking.disableTracking(self.pinIn.vehId.value)
  end
  self.vehData = nil
  self.inside = false
  self.pinOut.inside.value = false
  self.pinOut.outside.value = false
  self.pinOut.spotExists.value = false
end

function C:work()
  if self.pinIn.reset.value then
    self:reset()
  end
  self.pinOut.enter.value = false
  self.pinOut.exit.value = false

  if not self.pinIn.vehId.value then return end

  if not self.vehData then
    gameplay_parking.enableTracking(self.pinIn.vehId.value)
  end
  self.vehData = gameplay_parking.getTrackingData()[self.pinIn.vehId.value]

  if self.vehData then
    if not self.inside and self.vehData.isParked then
      self.pinOut.enter.value = true
      self.pinOut.inside.value = true
      self.pinOut.outside.value = false
      self.inside = true
    elseif self.inside and not self.vehData.isParked then
      self.pinOut.exit.value = true
      self.pinOut.inside.value = false
      self.pinOut.outside.value = true
      self.inside = false
    end

    self.pinOut.spot.value = self.vehData.parkingSpot
    self.pinOut.spotExists.value = self.vehData.parkingSpot and true or false
  end
end

return _flowgraph_createNode(C)