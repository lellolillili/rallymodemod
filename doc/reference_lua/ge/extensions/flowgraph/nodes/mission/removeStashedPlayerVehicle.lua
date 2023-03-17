-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'Remove Stashed Player Vehicle'
C.color = im.ImVec4(0.13, 0.3, 0.64, 0.75)
C.description = "Removes a stashed player vehicle from the mission cleanup node."
C.category = 'once_p_duration'

C.pinSchema = {
}
C.tags = { 'activity' }

function C:workOnce()
  print("removing...")
  self.mgr.modules.mission:removeStashedPlayerVehicle()
end

return _flowgraph_createNode(C)