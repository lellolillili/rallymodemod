-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Race Recovery Used'
C.description = 'Lets the flow through when a vehicle hs used a recovery.'
C.category = 'logic'

C.color = im.ImVec4(1, 1, 0, 0.75)
C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.'},
  {dir = 'in', type = 'table', name = 'raceData', tableType = 'raceData', description = 'Data from the race for other nodes to process.'},
  {dir = 'in', type = 'number', name = 'vehId', description = 'The Vehicle that should be tracked.'},
  {dir = 'out', type = 'flow', name = 'flow', description = 'Outflow from this node.'},
  {dir = 'out', type = 'flow', name = 'impulse', description = 'Outflow from this node.', impulse=true},
  {dir = 'out', type = 'number', name = 'recoveriesUsed', description = 'Total times the vehicle has been recovered in this race'},
}

C.tags = {'scenario'}

function C:work(args)
  self.race = self.pinIn.raceData.value
  if not self.race or not self.pinIn.vehId.value then return end
  local events = self.race.states[self.pinIn.vehId.value].events
  if not events then return end
  self.pinOut.impulse.value = false
  if events.recovered then
    self.pinOut.flow.value = true
    self.pinOut.impulse.value = true
  end

  self.pinOut.recoveriesUsed.value = self.race.states[self.pinIn.vehId.value].recoveriesUsed
end




return _flowgraph_createNode(C)
