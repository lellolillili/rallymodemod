-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.name = 'Get Timer'
C.description = "Gets various timer values."
C.icon = ui_flowgraph_editor.nodeIcons.timer
C.color = ui_flowgraph_editor.nodeColors.timer
C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.'},
  {dir = 'in', type = 'flow', name = 'reset', description = 'Resets this node.', impulse=true, hidden=true},
  {dir = 'in', type = 'number', name = 'timerId', description = 'ID of the timer.'},
  {dir = 'in', type = 'bool', name = 'capTime', description = 'If true, elapsed, remaining and elapsedPercent will be capped if the timer is complete.', hidden=true},

  {dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.'},
  {dir = 'out', type = 'flow', name = 'complete', description = 'Outflow when the timer is complete.'},
  {dir = 'out', type = 'flow', name = 'completed', description = 'Outflow once when the timer is complete.', impulse=true, hidden=true},
  {dir = 'out', type = 'flow', name = 'incomplete', description = 'Outflow when the timer is incomplete.', hidden=true},
  {dir = 'out', type = 'number', name = 'elapsed', description = 'Amount of time elapsed on the timer.'},
  {dir = 'out', type = 'number', name = 'remaining', description = 'Amount of time still remaining on the timer.', hidden=true},
  {dir = 'out', type = 'number', name = 'duration', description = 'How long the timer is running before considered complete.', hidden=true},
  {dir = 'out', type = 'number', name = 'elapsedPercent', description = 'How complete the timer is in percent. Returns value is betwen 0 and 1.', hidden=true},
}

function C:_executionStarted()
  self.wasComplete = nil
end

function C:work()
  self.pinOut.flow.value = false
  if self.pinIn.reset.value then
    self.wasComplete = nil
  end
  if self.pinIn.flow.value then
    local id = self.pinIn.timerId.value
    local timer = self.mgr.modules.timer:getTimer(id)
    if id and timer then
      -- calculate basic values.
      self.pinOut.complete.value = self.mgr.modules.timer:isComplete(id)
      self.pinOut.incomplete.value = not self.pinOut.complete.value
      self.pinOut.elapsed.value = self.mgr.modules.timer:getElapsedTime(id)
      self.pinOut.duration.value = timer.duration.value
      self.pinOut.remaining.value = self.pinOut.duration.value - self.pinOut.elapsed.value
      self.pinOut.elapsedPercent.value = self.pinOut.elapsed.value / self.pinOut.duration.value

      -- cap values if desired.
      if self.pinIn.capTime.value then
        self.pinOut.elapsed.value = math.min(self.pinOut.elapsed.value, self.pinOut.duration.value)
        self.pinOut.remaining.value = math.max(self.pinOut.remaining.value, 0)
        self.pinOut.elapsedPercent.value = math.min(self.pinOut.elapsedPercent.value, 1)
      end

      -- check comepletion impulse.
      self.pinOut.completed.value = false
      if not self.wasComplete and self.pinOut.complete.value then
        self.pinOut.completed.value = true
        self.wasComplete = true
      end

      self.pinOut.flow.value = true
    end
  end
end

return _flowgraph_createNode(C)
