-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Race Suspend'
C.description = 'Suspends or resumes a race.'
C.color = im.ImVec4(1, 1, 0, 0.75)
C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.'},
  {dir = 'in', type = 'flow', name = 'suspend', description = 'Inflow for this node.'},
  {dir = 'in', type = 'flow', name = 'resume', description = 'Inflow for this node.'},
  {dir = 'in', type = 'table', name = 'raceData', tableType = 'raceData', description = 'Data from the race for other nodes to process.'},
  {dir = 'out', type = 'flow', name = 'flow', description = 'Outflow from this node.'},
}

C.tags = {'scenario'}


function C:init()

end
function C:work()
  if self.pinIn.suspend.value then
    self.pinIn.raceData.value:doSuspend(true)
  elseif self.pinIn.resume.value then
    self.pinIn.raceData.value:doSuspend(false)
  end

  self.pinOut.flow.value = true
end


return _flowgraph_createNode(C)
