-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.name = 'Simple Timer'
C.description = "Creates a new Timer object inside an all-in-one node. Timer values can not be changed after creation in this node."
C.category = 'once_f_duration'

C.icon = ui_flowgraph_editor.nodeIcons.timer
C.color = ui_flowgraph_editor.nodeColors.timer
C.pinSchema = {
    { dir = 'in', type = 'number', name = 'duration', default = 5, hardcoded = true, description = 'How long the timer should run before considered complete.' },
    { dir = 'in', type = 'string', name = 'ref', hardcoded = true, default = "dtSim", hidden = true, description = 'Reference frame for the timer.' },
    { dir = 'in', type = 'bool', name = 'capTime', description = 'If true, elapsed, remaining and elapsedPercent will be capped if the timer is complete.', hidden = true },

    { dir = 'out', type = 'number', name = 'timerId', description = 'ID of the timer.', hidden = true },
    { dir = 'out', type = 'number', name = 'elapsed', description = 'Amount of time elapsed on the timer.' },
    { dir = 'out', type = 'number', name = 'remaining', description = 'Amount of time still remaining on the timer.', hidden = true },
    { dir = 'out', type = 'number', name = 'duration', description = 'How long the timer is running before considered complete.', hidden = true },
    { dir = 'out', type = 'number', name = 'elapsedPercent', description = 'How complete the timer is in percent. Returns value is betwen 0 and 1.', hidden = true },

}

function C:_executionStarted()
  self:setDurationState('inactive')
end

function C:postInit()
  self.pinInLocal.ref.hardTemplates = { { value = 'dtSim', label = "Simulation Time" }, { value = "dtReal", label = "Real Time" }, { value = "dtRaw", label = "Raw Time" } }
end

function C:onNodeReset()
print("setting timer back. id" .. dumps(self.pinOut.timerId.value))
  if self.pinOut.timerId.value then
    self:setDurationState('inactive')
    self.mgr.modules.timer:setElapsedTime(self.pinOut.timerId.value, 0)
    print("setting timer back." .. self.mgr.modules.timer:getElapsedTime(self.pinOut.timerId.value))
  end
end

function C:workOnce()
  self.pinOut.timerId.value = self.mgr.modules.timer:addTimer({ duration = self.pinIn.duration.value, mode = self.pinIn.ref.value })
  self:setDurationState('started')
end

function C:work()
  local id = self.pinOut.timerId.value
  local timer = self.mgr.modules.timer:getTimer(id)
  if id and timer then
    if self.durationState == 'started' and self.mgr.modules.timer:isComplete(id) then
      self:setDurationState('finished')
    end

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
  end
end

return _flowgraph_createNode(C)
