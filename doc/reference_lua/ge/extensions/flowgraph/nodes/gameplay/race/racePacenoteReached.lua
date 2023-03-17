-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Race Pacenote Reached'
C.description = 'Lets the flow through when a vehicle reaches any Pacenote.'
C.category = 'logic'

C.color = im.ImVec4(1, 1, 0, 0.75)
C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.'},
  {dir = 'in', type = 'table', name = 'raceData', tableType = 'raceData', description = 'Data from the race for other nodes to process.'},
  {dir = 'in', type = 'number', name = 'vehId', description = 'The Vehicle that should be tracked.'},
  {dir = 'out', type = 'flow', name = 'flow', description = 'Outflow from this node.', impulse = true},
  {dir = 'out', type = 'string', name = 'note', description = 'Note of the pacenote.'},
}

C.tags = {'scenario'}


function C:init(mgr, ...)
  self.data.detailed = false
end

function C:drawMiddle(builder, style)

end

function C:work(args)
  self.race = self.pinIn.raceData.value
  if not self.race or not self.pinIn.vehId.value then return end
  local events = self.race.states[self.pinIn.vehId.value].events
  if not events then return end
  if events.pacenoteReached then
    self.pinOut.flow.value = true
    self.pinOut.note.value = self.race.path.pacenotes.objects[events.pacenoteIdReached].note
  else
    self.pinOut.flow.value = false
    self.pinOut.note.value = nil
  end
end




return _flowgraph_createNode(C)
