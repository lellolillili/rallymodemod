-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Race Data'
C.description = 'Exposes some data from a race for a vehicle.'
C.category = 'repeat_instant'

C.color = im.ImVec4(1, 1, 0, 0.75)
C.pinSchema = {
  {dir = 'in', type = 'table', name = 'raceData', tableType = 'raceData', description = 'Data from the race for other nodes to process.'},
  {dir = 'in', type = 'number', name = 'vehId', description = 'The vehicle that should be tracked.'},
  {dir = 'out', type = 'string', name = 'formattedTime', description = 'Formatted time for this race.'},
  {dir = 'out', type = 'number', name = 'recoveriesUsed', description = 'Total times the vehicle has been recovered in this race'},
  {dir = 'out', type = 'number', name = 'placement', description = 'Estimated place in the race, if applicable.'}
}

C.tags = {'scenario'}

function C:work(args)
  local race = self.pinIn.raceData.value
  if not race then return end
  local state = race.states[self.pinIn.vehId.value]
  if not state then return end

  local endTime = state.complete and state.endTime or race.time
  if self.pinOut.formattedTime:isUsed() then
    self.pinOut.formattedTime.value = race:raceTime(endTime - state.startTime)
  end
  self.pinOut.recoveriesUsed.value = state.recoveriesUsed
  self.pinOut.placement.value = state.placement
end

return _flowgraph_createNode(C)
