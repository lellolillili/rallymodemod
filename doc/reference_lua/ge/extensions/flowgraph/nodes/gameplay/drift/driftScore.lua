-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}

C.name = 'Drift Score'

C.description = 'Gives the various drift scores'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'out', type = 'number', name = 'score', description = "The total score"},
  { dir = 'out', type = 'number', name = 'cachedScore', description = "The temporary score"},
  { dir = 'out', type = 'number', name = 'combo', description = "The current combo"},
}

C.tags = {'gameplay', 'utils'}

local score
function C:work()
  score = self.mgr.modules.drift:getScore()
  self.pinOut.score.value = score.score
  self.pinOut.cachedScore.value = score.cachedScore
  self.pinOut.combo.value = score.combo
end

return _flowgraph_createNode(C)