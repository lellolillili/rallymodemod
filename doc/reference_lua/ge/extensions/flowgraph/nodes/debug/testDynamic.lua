-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = 'CategoryTest'
C.category = 'once_f_duration'

function C:init(mgr, ...)
  self.timer = 0
  self:setDurationState('inactive')
end

function C:_executionStarted()
  self.timer = 0
  self:setDurationState('inactive')
end

function C:onNodeReset()
  self.timer = 0
  self:setDurationState('inactive')
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.ProgressBar(self.timer / 5, im.ImVec2(50, 0))
end

function C:workOnce()
  timer = 0
  self:setDurationState('started')
end

function C:work(args)
  if not self.durationState == 'started' then
    return
  end
  dump('Called work')
  self.timer = self.timer + self.mgr.dtReal
  if self.timer >= 5 then
    self:setDurationState('finished')
  end
end

return _flowgraph_createNode(C)
