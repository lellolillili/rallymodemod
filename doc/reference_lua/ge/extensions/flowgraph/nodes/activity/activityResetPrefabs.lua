-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'Activity Reset Prefab'
C.color = im.ImVec4(0.03, 0.41, 0.64, 0.75)
C.description = "Resets the vehicles inside all prefabs loaded by the associated activity."
C.category = 'once_p_duration'

C.tags = { 'activity' }

function C:workOnce()
    gameplay_missions_missionManager.resetActivityPrefabVehicles(self.mgr.activity)
end

return _flowgraph_createNode(C)