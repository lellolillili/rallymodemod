-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Race Request Recovery'
C.description = 'Tries to recover the vehicle to the most recent recovery point.'
C.category = 'repeat_instant'

C.color = im.ImVec4(1, 1, 0, 0.75)
C.pinSchema = {
  { dir = 'in', type = 'table', name = 'raceData', tableType = 'raceData', description = 'Data from the race for other nodes to process.' },
  { dir = 'in', type = 'number', name = 'vehId', description = 'The Vehicle that should be tracked.' },
  { dir = 'out', type = 'flow', name = 'success', hidden = true, description = 'Can Recover.' },
  { dir = 'out', type = 'flow', name = 'fail', hidden = true, description = 'Cannot recover.' },

}

C.tags = {'scenario'}

function C:work(args)
  self.race = self.pinIn.raceData.value
  if not self.race or not self.pinIn.vehId.value then return end
  local succ = self.race:requestRecover(self.pinIn.vehId.value)
  self.pinOut.success.value = succ
  self.pinOut.fail.value = not succ
end




return _flowgraph_createNode(C)
