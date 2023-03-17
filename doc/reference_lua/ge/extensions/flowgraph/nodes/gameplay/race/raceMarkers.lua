-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Race Markers'
C.description = 'Displays the Race Markers for one Vehicle.'
C.category = 'repeat_instant'

C.color = im.ImVec4(1, 1, 0, 0.75)
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'clear', description = 'Clears markers.', impulse = true },
  { dir = 'in', type = 'table', name = 'raceData', tableType = 'raceData', description = 'Data from the race for other nodes to process.' },
  { dir = 'in', type = 'number', name = 'vehId', description = 'The Vehicle that should be tracked.' },
  { dir = 'in', type = 'bool', name = 'ignoreRecovery', hidden = true, description = 'When true, recovery types are ignored.' },
  { dir = 'in', type = 'number', name = 'minAlpha', default = 0.15, hardcoded = true, hidden = true, description = 'Opacity when vehicle is closest.' },
  { dir = 'in', type = 'number', name = 'maxAlpha', default = 1, hardcoded = true, hidden = true, description = 'Opacity when vehicle is furthest.' },
  { dir = 'in', type = 'number', name = 'minDistance', default = 5, hardcoded = true, hidden = true, description = 'Distance for closest opacity.' },
  { dir = 'in', type = 'number', name = 'maxDistance', default = 50, hardcoded = true, hidden = true, description = 'Distance for furthest opacity.' },
  { dir = 'in', type = 'bool', name = 'alwaysShowFinal', hidden = true, description = 'Always show final Marker.' }
}

C.tags = { 'scenario' }

C.legacyPins = {
  _in = {
    reset = 'clear'
  }
}

function C:init()
  self.markers = nil
end
function C:work()
  if self.pinIn.clear.value then
    self:_executionStopped()
  elseif self.pinIn.flow.value then
    if self.pinIn.raceData.value then
      if self.markers == nil then
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

      if events.rollingStarted or events.pathnodeReached or events.raceStarted then
        local wps = {}
        for _, e in ipairs(state.nextPathnodes) do
          wps[e[1].id] = e[2]
        end
        for _, e in ipairs(state.overNextPathnodes) do
          wps[e[1].id] = 'next'
        end
        if self.pinIn.alwaysShowFinal.value then
          for _, id in ipairs(self.pinIn.raceData.value.path.config.finalSegments) do
            wps[self.pinIn.raceData.value.path.config.graph[id].targetNode] = 'final'
          end
        end
        --dump(wps)
        if self.pinIn.ignoreRecovery.value then
          for k, v in pairs(wps) do
            if v == 'recovery' then
              v = 'default'
            end
          end
        end
        self.markers.setModes(wps)
      end
    end
  end
end

function C:onPreRender(dt, dtSim)
  if self.markers then

    self.markers.render(dt, dtSim)
  end
end

function C:_executionStopped()
  if self.markers then
    self.markers.onClientEndMission()
    self.markers = nil
  end
end

function C:onClientEndMission()
  self:_executionStopped()
end


function C:destroy()
  self:_executionStopped()
end

return _flowgraph_createNode(C)

