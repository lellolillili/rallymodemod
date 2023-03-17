-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Race CP/Lap Change'
C.description = 'Lets flow through when the current checkpoint or lap changes.'
C.category = 'repeat_instant'
C.color = im.ImVec4(1, 1, 0, 0.75)
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'table', name = 'raceData', tableType = 'raceData', description = 'Data from the race for other nodes to process.' },
  { dir = 'in', type = 'number', name = 'vehId', description = 'The Vehicle that should be tracked.' },

  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow from this node.' },
  { dir = 'out', type = 'flow', name = 'changed', description = 'Outflow from this node when something changed.', impulse = true},
  { dir = 'out', type = 'number', name = 'curCP', description = 'Current Checkpoint' },
  { dir = 'out', type = 'number', name = 'maxCP', description = 'Max number of Checkpoints' },
  { dir = 'out', type = 'number', name = 'curLap', description = 'Current Lap' },
  { dir = 'out', type = 'number', name = 'maxLap', description = 'Max number of Laps' },
  { dir = 'out', type = 'bool', name = 'recoveryReached', description = 'If the reached CP contained a recovery.' },
  { dir = 'out', type = 'bool', name = 'usedRecovery', description = 'If the player got here by recovering back.' },
}


function C:work()
  self.pinOut.flow.value = self.pinIn.flow.value
  self.pinOut.changed.value = false
  if self.pinIn.flow.value then
    if false and self.markers == nil then -- Q: is this code block needed? It reinitializes the race markers, causing badness if they were already active
      self.markers = require('scenario/race_marker')
      self.markers.init()
      local wps = {}
      for _, pn in ipairs(self.pinIn.raceData.value.path.pathnodes.sorted) do
        table.insert(wps, {name = pn.id, pos = pn.pos, radius = pn.radius, normal = pn.hasNormal and pn.normal or nil})
      end
      self.markers.setupMarkers(wps)
    end
    local state = self.pinIn.raceData.value.states[self.pinIn.vehId.value]
    if not state then return end
    local events = state.events
    if not events then return end

    if events.rollingStarted or events.pathnodeReached or events.raceStarted or events.lapComplete or events.raceComplete then
      local race = self.pinIn.raceData.value
      local curSeg1 = state.currentSegments[1]
      if curSeg1 then
        local graphSeg = race.path.config.graph[curSeg1]
        self.pinOut.curCP.value = graphSeg.linearCPIndex or nil
      else
        self.pinOut.curCP.value = nil
      end
      self.pinOut.maxCP.value = #(race.path.pathnodes.sorted)
      self.pinOut.curLap.value = state.currentLap+1
      self.pinOut.maxLap.value = race.lapCount
      self.pinOut.changed.value = true
      self.pinOut.recoveryReached.value = events.recoveryReached or false
      self.pinOut.usedRecovery.value = (events.recovered and true) or false
    end
  end
end


return _flowgraph_createNode(C)
