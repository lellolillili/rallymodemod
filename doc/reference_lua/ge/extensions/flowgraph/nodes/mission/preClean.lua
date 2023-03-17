-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'Mission Cleanup'
C.color = im.ImVec4(0.13, 0.3, 0.64, 0.75)
C.description = "Cleans up the world state before a mission, if desired. Stashes all vehicles and unstashes when the mission completes."
C.category = 'once_p_duration'

C.pinSchema = {
  {dir = 'in', type = 'bool', name = 'keepPlayer', description = 'If true, the player vehicle will not be stashed, but all others.'},
  {dir = 'in', type = 'bool', name = 'keepTraffic', description = 'If true, the traffic vehicles will not be stashed, if they exist.'},
}
C.tags = { 'activity' }

function C:workOnce()
  self.mgr.modules.mission:stashWithParams({
    keepPlayer = self.pinIn.keepPlayer.value,
    keepTraffic = self.pinIn.keepTraffic.value
  })

end

return _flowgraph_createNode(C)