-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Timed Trigger'
C.icon = "timer"
C.behaviour = {once = true, duration = true}
C.description = 'Needs to have input on charge for a certain amount of time before triggering. Resets if no input on charge for a fixed time.'
C.category = 'logic'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'charge', description = 'Node timer will charge as long as this pin has flow.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
  { dir = 'out', type = 'flow', name = 'complete', description = 'Outflow once on completion.', impulse = true },
}


C.tags = {}

function C:init(mgr, ...)
  self.data.resetTimer = 1
  self.data.duration = 3
  self.timer = 0
  self.reset = 0
  self.charging = false
  self.completeTrigger = false
  self.completeReady = true
end

function C:_executionStopped()
  self.timer = 0
  self.reset = 0
  self.charging = false
  self.completeTrigger = false
  self.completeReady = true
end

function C:_onSerialize(res)
  res.duration = self.data.duration
end

function C:_onDeserialized(res)
  self.data.duration = res.duration
end
function C:updateCharge()
  self.charging = self.pinIn.charge.value
  if self.charging then
    self.reset = 0
    self.timer = self.timer + self.mgr.dtSim
    if self.timer >= self.data.duration then
      self.completeTrigger = true
    end
  else
    self.reset = self.reset + self.mgr.dtSim
    if self.reset >= self.data.resetTimer then
      self.timer = 0
      self.reset = self.data.resetTimer
      self.completeReady = true
      self.completeTrigger = false
    end
  end

end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.ProgressBar(self.timer / self.data.duration, im.ImVec2(50,0))
  im.SameLine()
  im.Text("%0.1f", self.data.duration-self.timer)
  im.ProgressBar(self.reset / self.data.resetTimer, im.ImVec2(50,0))
  im.SameLine()
  im.Text("%0.1f", self.data.resetTimer-self.reset)
end

function C:work(args)
  self.charging = self.pinIn.charge.value
  self:updateCharge()

  self.pinOut.flow.value = self.timer >= self.data.duration
  self.pinOut.complete.value = self.completeTrigger and self.completeReady
  if self.pinOut.complete.value then
    self.completeReady = false
  end
  self.completeTrigger = false
end

return _flowgraph_createNode(C)
