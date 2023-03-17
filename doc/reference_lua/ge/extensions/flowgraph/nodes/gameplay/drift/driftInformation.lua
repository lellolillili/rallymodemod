-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}

C.name = 'Drift Information'

C.description = 'Gives drift related information for the given car'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.todo = "Tweak driftCleanliness, Make the raycast cleaner"
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'flow', impulse = true, name = 'resetTotalAngle', description = "Reset the total drift angle." },

  { dir = 'out', type = 'flow', name = 'drifting', description = "Outflow for this node." },
  { dir = 'out', type = 'flow', name = 'notDrifting', hidden = true, description = "Outflow for this node." },

  { dir = 'out', type = 'flow', name = 'tapped', impulse = true, description = "Emits signal when the vehicle taps a wall." },
  { dir = 'out', type = 'flow', name = 'crashed', impulse = true, description = "Emits signal when the vehicle bumps too hard into a wall." },
  { dir = 'out', type = 'flow', name = 'donutDetected', hidden = true, impulse = true, description = "Emits signal when a donut is detected" },
  { dir = 'out', type = 'flow', name = 'tightDriftDetected', hidden = true, impulse = true, description = "Emits signal when a tightDrift is detected" },
  { dir = 'out', type = 'flow', name = 'driftCompleted', impulse = true, description = "Emits signal when the drift has been completed." },
  { dir = 'out', type = 'number', name = 'driftCompletedScore', description = "The cached score when done with the drift" },

  { dir = 'out', type = 'number', name = 'closestWallDistance', description = "Distance from the closest wall" },
  { dir = 'out', type = 'number', name = 'driftAngle', description = "Current drift angle" },
  { dir = 'out', type = 'number', name = 'driftAngleAvg', hidden = true, description = "The average angle of the current drift"},
  { dir = 'out', type = 'number', name = 'driftVelocity', hidden = true, description = "Drift speed"},

  { dir = 'out', type = 'number', name = 'totalDriftDeg', hidden = true, description = "Total drift angle"},
  { dir = 'out', type = 'number', name = 'totalDriftDistance', hidden = true, description = "Total drift distance"},
  { dir = 'out', type = 'number', name = 'totalDriftTime', hidden = true, description = "Total drift time"},

  { dir = 'out', type = 'number', name = 'driftUniformity', hidden = true, description = "The closer the current drift angle is to the average drift angle, the closer to 0 this pin will be. Another way of seing this : The more the drift angle stays the same, the closer to 0 this pin will be"},
}

C.tags = {'gameplay', 'utils'}

local driftData
local callbacks

function C:work()
  driftData = self.mgr.modules.drift:getActiveDriftData()
  callbacks = self.mgr.modules.drift:getCallBacks()

  if self.pinIn.resetTotalAngle.value then
    self.mgr.modules.drift:resetDonut()
  end

  self.pinOut.tapped.value = callbacks.tap
  self.pinOut.crashed.value = callbacks.crash
  self.pinOut.donutDetected.value = callbacks.donut
  self.pinOut.tightDriftDetected.value = callbacks.tight
  self.pinOut.driftCompleted.value = callbacks.complete
  self.pinOut.driftCompletedScore.value = callbacks.complete or 0

  if driftData then
    self.pinOut.drifting.value = true
    self.pinOut.notDrifting.value = false

    self.pinOut.closestWallDistance.value = driftData.closestWallDistance
    self.pinOut.driftAngle.value = driftData.currDegAngle
    self.pinOut.driftAngleAvg.value = driftData.avgDriftAngle
    self.pinOut.driftVelocity.value = driftData.angleVelocity

    self.pinOut.totalDriftDeg.value = driftData.totalDriftAngle
    self.pinOut.totalDriftDistance.value = driftData.totalDriftDistance
    self.pinOut.totalDriftTime.value = driftData.totalDriftTime
  else
    self.pinOut.drifting.value = false
    self.pinOut.notDrifting.value = true

    self.pinOut.closestWallDistance.value = -1
    self.pinOut.driftAngle.value = -1
    self.pinOut.driftAngleAvg.value = -1
    self.pinOut.driftVelocity.value = -1

    self.pinOut.totalDriftDeg.value = -1
    self.pinOut.totalDriftDistance.value = -1
    self.pinOut.totalDriftTime.value = -1
  end
end


return _flowgraph_createNode(C)