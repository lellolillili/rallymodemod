-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Frame Delay'
C.icon = "timer"
C.description = "Will output flow after n frames after having been triggered by an inpulse"
C.category = 'logic'
C.todo = ""

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node. Need continious flow.' },
  { dir = 'in', type = 'flow', name = 'reset', description = 'Resets this node.', impulse = true },
  { dir = 'in', type = 'number', name = 'frames', hidden = true, hardcoded = true, default = 1, description = 'Calls until this node will let the flow through.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
}


C.tags = {'delay','wait','pause','frame'}



function C:init(mgr, ...)
  self.counter = 0
  self.running = false
end

function C:_executionStarted()
  self.counter = 0
  self.running = false
end

function C:_onSerialize(res)
  res.duration = self.data.duration
end

function C:_onDeserialized(res)
  self.data.duration = res.duration
end

function C:updateCounter()
  if not self.running then return end
  self.counter = self.counter+1
  if self.counter > (self.pinIn.frames.value or 0) then
    self.running = false
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.ProgressBar(self.pinIn.frames.value and (self.counter / self.pinIn.frames.value) or 0, im.ImVec2(50,0))
  if im.SmallButton("Reset") then
    self.counter = 0
    self.running = false
  end

end

function C:work(args)
  if self.pinIn.reset.value then
    self.counter = 0
    self.running = false
  end
  if self.pinIn.flow.value and not self.running and self.counter < (self.pinIn.frames.value or 0) then
    self.running = true
    self.counter = 0
  end
  self:updateCounter()
  self.pinOut.flow.value = self.counter >= (self.pinIn.frames.value or 0)
end

return _flowgraph_createNode(C)
