-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = 'Fade Sequence'
C.description = 'Fades the screen to and from black, with an optional pause time.'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.category = 'once_f_duration'

C.fadedTriggered = false -- needed for impulse of faded pin
C.pinSchema = {
  { dir = 'in', type = 'number', name = 'startDuration', description = 'Duration of fade transition to black screen.', default = 1, hardcoded = true },
  { dir = 'in', type = 'number', name = 'pauseDuration', description = 'Duration of pause at black screen.', default = 0, hardcoded = true },
  { dir = 'in', type = 'number', name = 'endDuration', description = 'Duration of fade transition from black screen.', default = 1, hardcoded = true },
  { dir = 'out', type = 'flow', name = 'faded', impulse = true },
}

C.legacyPins = {
  out = {
    done = 'complete'
  },
}

C.dependencies = { 'ui_fadeScreen' }
C.tags = { 'ui' }

function C:init()
  self:setDurationState('inactive')
  self.fadedTriggered = false
end

function C:postInit()
  self.pinInLocal.startDuration.hardTemplates = {
    {label = "Default Mission Fade Duration", value = gameplay_missions_missionManager.fadeDuration},
  }
  self.pinInLocal.endDuration.hardTemplates = {
    {label = "Default Mission Fade Duration", value = gameplay_missions_missionManager.fadeDuration},
  }
end

function C:_executionStopped()
  --ui_fadeScreen.stop(0)
  self:setDurationState('inactive')
  self.fadedTriggered = false
  self.pinOut.faded.value = false
end

function C:onNodeReset()
  self.pinOut.faded.value = false
  self:setDurationState('inactive')
  self.fadedTriggered = false
end

function C:workOnce()
  ui_fadeScreen.cycle(self.pinIn.startDuration.value or 1, self.pinIn.pauseDuration.value or 0, self.pinIn.endDuration.value or 1)
  self:setDurationState('started')
end

function C:work()
  if not self.fadedTriggered and self.pinOut.faded.value then
    self.fadedTriggered = true
  else
    self.pinOut.faded.value = false
  end
end

function C:onScreenFadeState(state)
  if state == 1 then
    self.pinOut.faded.value = true
  elseif state == 3 then
    self:setDurationState('finished')
  end
end

return _flowgraph_createNode(C)