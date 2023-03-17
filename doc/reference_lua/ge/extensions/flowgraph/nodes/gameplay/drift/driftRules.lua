-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}

C.name = 'Drift Rules'

C.description = 'Get the drift rules'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'out', type = 'number', name = 'maxWallDist', description = "How far a wall will be detected"},
  { dir = 'out', type = 'number', name = 'driftCoolDownTime', description = "The cooldown after which a drift will be validated"},
  { dir = 'out', type = 'number', name = 'maxCombo', description = "The maximum combo possible"},
  { dir = 'out', type = 'bool', name = 'allowTightDrift', description = "Get whether tight drifts are allowed"},
  { dir = 'out', type = 'bool', name = 'allowDonut', description = "Get whether donuts are allowed"},
}

C.tags = {'gameplay', 'utils'}

local options
function C:work()
  options = self.mgr.modules.drift:getDriftOptions()

  self.pinOut.maxWallDist.value = options.raycastDist
  self.pinOut.driftCoolDownTime.value = options.driftCoolDownTime
  self.pinOut.maxCombo.value = options.maxCombo
  self.pinOut.allowTightDrift.value = options.allowTightDrifts
  self.pinOut.allowDonut.value = options.allowDonut
end

return _flowgraph_createNode(C)