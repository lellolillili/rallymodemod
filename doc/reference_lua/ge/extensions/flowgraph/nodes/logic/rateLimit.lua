-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Flow Interval'
C.icon = ui_flowgraph_editor.nodeIcons.logic
C.description = "Lets the flow through in a regular interval. Flows instantly the first time it has flow."
C.category = 'logic'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'reset', hidden = true, description = 'Resets this node.', impulse = true },
  { dir = 'in', type = 'number', name = 'dt', hidden = true, description = 'The delta time for the interval. If no value, uses simulation dt.' },
  { dir = 'in', type = 'number', name = 'input', default = 1, description = 'Can be the frequency or the duration depending on the asDuration bool' , hardcoded = true},
  { dir = 'in', type = 'bool', name = 'reverseHit', default = true, description = 'If true, the flow will be let through at the end of each cycle, as opposed to the beginning of each cycle.' },
  { dir = 'in', type = 'bool', default = false, name = 'asDuration', description = "Will reset right after it's done.", hidden = true },

  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.', impulse = true }
}

C.tags = {'fps', 'tick', 'rate', 'ratelimit', 'rate limit', 'repeat'}

C.legacyPins = {
  _in = {
    fps = 'frequency',
    interval = 'frequency'
  }
}

function C:init()
  self.time = 0
  self.prevFps = -1
end

function C:_executionStarted()
  self.time = 0
  self.prevFps = -1
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.ProgressBar((self.pinIn.input.value - self.time) / self.pinIn.input.value, im.ImVec2(50, 0))
end

function C:work()
  local fps = math.abs(self.pinIn.input.value)
  if self.pinIn.reset.value or fps ~= self.prevFps then
    self.prevFps = fps
    if self.pinIn.asDuration.value then
      self.time = self.pinIn.input.value
    else
      self.time = self.pinIn.reverseHit.value and (1 / fps) or 0
    end
    self.pinOut.flow.value = false
  end

  if self.pinIn.flow.value then
    self.time = self.time - (self.pinIn.dt.value or self.mgr.dtSim)
    if self.time <= 0 then
      if self.pinIn.asDuration.value then
        self.time = self.pinIn.input.value
      else
        self.time = self.time + (1 / fps)
      end

      self.pinOut.flow.value = true
    else
      self.pinOut.flow.value = false
    end
  end
end

return _flowgraph_createNode(C)
