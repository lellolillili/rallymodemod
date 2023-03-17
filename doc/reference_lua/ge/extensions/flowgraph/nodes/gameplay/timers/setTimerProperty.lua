-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.name = 'Set Timer Property'
C.description = "Sets various Timer properties. Properties where the pin is not set will not be changed."
C.category = 'repeat_instant'
C.icon = ui_flowgraph_editor.nodeIcons.timer
C.color = ui_flowgraph_editor.nodeColors.timer

C.pinSchema = {
  {dir = 'in', type = 'number', name = 'timerId', description = 'ID of the timer.'},
  {dir = 'in', type = 'number', name = 'progress', default = 0, description = 'Progress of the timer in seconds..'},
  {dir = 'in', type = 'bool',   name = 'pause', description = 'If the timer should be paused or not.'},
  {dir = 'in', type = 'number', name = 'duration', default = 5, description = 'How long the timer should run before considered complete.'},
  {dir = 'in', type = 'string', name = 'ref', default="dtSim", description = 'Reference frame for the timer.'},
}

function C:postInit()
  self.pinInLocal.ref.hardTemplates = {{value='dtSim',label="Simulation Time"},{value="dtReal",label="Real Time"},{value="dtRaw",label="Raw Time"}}
end

function C:work()
  local id = self.pinIn.timerId.value
  local timer = self.mgr.modules.timer:getTimer(id)
  if id and timer then
    if self.pinIn.progress.value ~= nil then
      self.mgr.modules.timer:setElapsedTime(id, self.pinIn.progress.value)
    end
    if self.pinIn.pause.value ~= nil then
      self.mgr.modules.timer:setPause(id, self.pinIn.pause.value)
    end
    if self.pinIn.duration.value ~= nil then
      self.mgr.modules.timer:set(id, "duration", self.pinIn.duration.value)
    end
    if self.pinIn.ref.value ~= nil then
      self.mgr.modules.timer:set(id, "ref", self.pinIn.ref.value)
    end
  end
end

return _flowgraph_createNode(C)
