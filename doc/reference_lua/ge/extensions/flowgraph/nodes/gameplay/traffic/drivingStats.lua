-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Traffic Driving Stats'
C.description = 'Gives information about the driving stats of a vehicle.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'repeat_instant'
C.tags = {'police', 'cops', 'pursuit', 'chase', 'traffic', 'ai'}


C.pinSchema = {
  {dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle id to get information from; if none given, uses the player vehicle.'},
  {dir = 'out', type = 'number', name = 'speedLimit', description = 'Speed limit of the current road.'},
  {dir = 'out', type = 'number', name = 'speedRatio', description = 'Vehicle speed divided by the speed limit.'},
  {dir = 'out', type = 'number', name = 'collisions', description = 'Number of collisions with other traffic vehicles.'},
  {dir = 'out', type = 'number', name = 'driveScore', description = 'Value for how neatly the vehicle is driving (from 0 to 1).'},
  {dir = 'out', type = 'number', name = 'directionScore', description = 'Value for how often the vehicle is on the correct side of the road (from 0 to 1).'},
  {dir = 'out', type = 'number', name = 'intersectionScore', description = 'Value for vehicle obeying traffic signals (from 0 to 1).'}
}

-- All "score" numbers are set from 0 (bad) to 1 (good) depending on how long the offense is done; the default minimum cutoff to trigger a pursuit offense is 0.5 .

function C:work()
  local vehId = self.pinIn.vehId.value or be:getPlayerVehicleID(0)
  local vehData = gameplay_traffic.getTrafficData()[vehId]
  if not vehData then return end

  local tracking = vehData.tracking
  self.pinOut.speedLimit.value = tracking.speedLimit
  self.pinOut.speedRatio.value = vehData.speed / tracking.speedLimit
  self.pinOut.collisions.value = tracking.collisions
  self.pinOut.driveScore.value = tracking.driveScore
  self.pinOut.directionScore.value = tracking.directionScore
  self.pinOut.intersectionScore.value = tracking.intersectionScore
end

return _flowgraph_createNode(C)