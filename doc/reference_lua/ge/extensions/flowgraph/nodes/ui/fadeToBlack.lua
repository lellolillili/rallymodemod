-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Fade To Black'
C.description = 'Fades the screen to black.'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.category = 'once_f_duration'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'duration', description = 'Duration of fade transition to black screen.', default = gameplay_missions_missionManager.fadeDuration, hardcoded = true },
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
end

function C:postInit()
  self.pinInLocal.duration.hardTemplates = {
    {label = "Default Mission Fade Duration", value = gameplay_missions_missionManager.fadeDuration},
  }
end

function C:_executionStopped()
  --ui_fadeScreen.stop(0)
  self:setDurationState('inactive')
end

function C:onNodeReset()
  self:setDurationState('inactive')
end

function C:workOnce()
  self:setDurationState('started')
  ui_fadeScreen.start(self.pinIn.duration.value)
end

function C:onScreenFadeState(state)
  if state == 1 then
    self:setDurationState('finished')
  end
end

return _flowgraph_createNode(C)