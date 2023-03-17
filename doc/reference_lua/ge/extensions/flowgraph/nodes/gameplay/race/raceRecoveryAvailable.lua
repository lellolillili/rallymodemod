-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Race Recovery Available'
C.description = 'Lets the flow through when a vehicle hs a recovery.'
C.category = 'logic'

C.color = im.ImVec4(1, 1, 0, 0.75)
C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.'},
  {dir = 'in', type = 'table', name = 'raceData', tableType = 'raceData', description = 'Data from the race for other nodes to process.'},
  {dir = 'in', type = 'number', name = 'vehId', description = 'The Vehicle that should be tracked.'},
  {dir = 'out', type = 'flow', name = 'true', description = 'Outflow from this node when a recovery is availble.'},
  {dir = 'out', type = 'flow', name = 'false', description = 'Outflow from this node.'},
}

C.tags = {'scenario'}



C.tags = {}

function C:work()
  self.race = self.pinIn.raceData.value
  if not self.race or not self.pinIn.vehId.value then return end
  self.pinOut['true'].value = self.race:hasRecoveryPosition(self.pinIn.vehId.value)
  self.pinOut['false'].value = not self.pinOut['true'].value
end

return _flowgraph_createNode(C)
