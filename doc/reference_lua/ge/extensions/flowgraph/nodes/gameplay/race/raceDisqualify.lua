-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Race Disqualify'
C.description = 'Disqualifies a vehicle from a race.'
C.category = 'repeat_instant'

C.color = im.ImVec4(1, 1, 0, 0.75)
C.pinSchema = {
  {dir = 'in', type = 'table', name = 'raceData', tableType = 'raceData', description = 'Data from the race for other nodes to process.'},
  {dir = 'in', type = 'number', name = 'vehId', description = 'The Vehicle that should be disqualified.'},
}

C.tags = {'scenario'}


function C:init()

end
function C:work()
  self.pinIn.raceData.value:abortRace(self.pinIn.vehId.value)
end


return _flowgraph_createNode(C)
