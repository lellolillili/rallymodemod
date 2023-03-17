-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Race CP Reached'
C.description = "Lets the flow through once the player drives through a checkpoin."
C.category = 'repeat_instant'

C.pinSchema = {
    { dir = 'out', type = 'flow', name = 'checked', description = 'When a CP has been reached.', impulse = true },
    { dir = 'out', type = 'number', name = 'vehId', hidden = true, description = 'ID of the vehicle.' },
    { dir = 'out', type = 'number', name = 'index', description = 'Index of the CP' },
    { dir = 'out', type = 'number', name = 'lap', description = 'index of the current lap.' },

}
C.legacyPins = {
  out = {
    vehicleID = 'vehId'
  },
}

C.tags = {}

function C:init(mgr, ...)
  self.enterFlag = false
  self.lap = 1
  self.clearOutPinsOnStart = false
end

function C:_executionStarted()
  self.lap = 1
  self.enterFlag = false
end

function C:onRaceWaypointReached(data)
  self.pinOut.vehId.value = data.vehId
  self.pinOut.index.value = data.cur
  self.lap = self.lap + (data.lapDiff or 0)
  self.pinOut.lap.value = self.lap
  self.enterFlag = true
end

function C:work(args)
  self.pinOut.checked.value = self.enterFlag
  self.enterFlag = false
end

function C:onScenarioRestarted()
  self:_executionStarted()
end


return _flowgraph_createNode(C)
