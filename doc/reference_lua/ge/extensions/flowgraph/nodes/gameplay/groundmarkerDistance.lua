-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Groundmarker Remaining Distance'
C.icon = "navigation"
C.description = 'If groundmarkers are active, gives the remaining position'
C.category = 'repeat_instant'

C.color = im.ImVec4(1, 1, 0, 0.75)
C.pinSchema = {
  { dir = 'out', type = 'flow', name = 'active', description = "Outflow only when groundmarkers are active." },
  { dir = 'out', type = 'number', name = 'distance', description = "Remaining distance of the groundmarkers in m." }
}

C.tags = {'arrow', 'path', 'destination', 'navigation'}
C.dependencies = {'core_groundMarkers'}

function C:work(args)
  self.pinOut.active.value = false
  if core_groundMarkers and core_groundMarkers.routePlanner and core_groundMarkers.routePlanner.path[1] then
    self.pinOut.distance.value = core_groundMarkers.routePlanner.path[1].distToTarget
    self.pinOut.active.value = true
  end
end

return _flowgraph_createNode(C)
