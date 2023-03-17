

-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Wait'
C.icon = "timer"
C.behaviour = {duration = true, once = true}
C.description = [[Once flow reaches this node, it waits the assigned time before passing on the flow signal.
Requires constant flow to work.]]
C.category = 'logic'

C.todo = "Sometimes bugs out, reason unknown. TimedTrigger node can be used instead"
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node. Need continious flow.' },
  { dir = 'in', type = 'flow', name = 'reset', description = 'Resets this node.', impulse = true },
  { dir = 'in', type = 'number', hardcoded = true, default = 3, name = 'duration', description = 'The time to wait'},
  { dir = 'in', type = 'bool', default = false, name = 'useDtSim', description = 'Use dtSim instead of dtReal.', hidden = true },

  { dir = 'out', type = 'flow', name = 'flow', description = 'Puts out flow, when wait is finished.' },
  { dir = 'out', type = 'flow', name = 'impulse', description = 'Puts out flow once, when wait is finished. ', impulse = true },
}


C.tags = {}

function C:init(mgr, ...)
  self.timer = 0
  self.running = false
end

function C:_executionStarted()
  self.timer = 0
  self.running = false
end

function C:_onDeserialized(res)
  if res.duration then
    self:_setHardcodedDummyInputPin(self.pinInLocal.duration, res.duration)
    self.data.duration = nil
  end
end

function C:updateTimer()
  if not self.running then return end
  self.timer = self.timer + (self.pinIn.useDtSim.value and self.mgr.dtSim or self.mgr.dtReal)
  if self.timer >= self.pinIn.duration.value then
    self.running = false
    self.pinOut.impulse.value = true
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  if self.pinIn.duration.value == nil then return end

  im.ProgressBar(self.timer / self.pinIn.duration.value, im.ImVec2(50,0))
  if im.SmallButton("Reset") then
    self.timer = 0
    self.running = false
  end
end

function C:work(args)
  self.pinOut.impulse.value = false
  if self.pinIn.flow.value and not self.running and self.timer < self.pinIn.duration.value then
    self.running = true
    self.timer = 0
  end
  if self.pinIn.reset.value then
    self.timer = 0
    self.running = false
  end
  self:updateTimer()

  self.pinOut.flow.value = self.timer >= self.pinIn.duration.value and self.pinIn.flow.value
end

return _flowgraph_createNode(C)
