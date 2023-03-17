-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.name = 'Create Timer'
C.description = "Creates a new Timer object."
C.icon = ui_flowgraph_editor.nodeIcons.timer
C.color = ui_flowgraph_editor.nodeColors.timer
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'duration', default = 5, description = 'How long the timer should run before considered complete.' },
  { dir = 'in', type = 'string', name = 'ref', hardcoded = true, default = "dtSim", hidden = true, description = 'Reference frame for the timer.' },
  { dir = 'out', type = 'number', name = 'timerId', description = 'ID of the timer.' },
}

function C:_executionStarted()
  self.done = false
end

function C:postInit()
  self.pinInLocal.ref.hardTemplates = {{value='dtSim',label="Simulation Time"},{value="dtReal",label="Real Time"},{value="dtRaw",label="Raw Time"}}
end

function C:workOnce()
  self.pinOut.timerId.value = self.mgr.modules.timer:addTimer({duration = self.pinIn.duration.value, mode = self.pinIn.ref.value})
end

return _flowgraph_createNode(C)
