-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'im Race Times'
C.description = 'Draws the race times for a vehicle in imgui.'
C.category = 'repeat_instant'

C.color = im.ImVec4(1, 1, 0, 0.75)
C.pinSchema = {
  {dir = 'in', type = 'table', name = 'raceData', tableType = 'raceData', description = 'Data from the race for other nodes to process.'},
  {dir = 'in', type = 'number', name = 'vehId', description = 'The Vehicle that should be tracked.'},
}

C.tags = {'scenario'}


function C:init(mgr, ...)
  self.data.detailed = false
end

function C:drawMiddle(builder, style)

end

function C:work(args)
  self.race = self.pinIn.raceData.value
  if not self.race then return end

  local avail = im.GetContentRegionAvail()
  --im.BeginChild1("Times", im.ImVec2(avail.x, avail.y/2-5), 0, im.WindowFlags_AlwaysVerticalScrollbar)
  if self.race:inDrawTimes(self.pinIn.vehId.value, im, self.data.detailed) then
    self.data.detailed = not self.data.detailed
  end
  --im.EndChild()
end




return _flowgraph_createNode(C)
