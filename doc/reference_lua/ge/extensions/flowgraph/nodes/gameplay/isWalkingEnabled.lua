-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Is Walking Enabled'
C.description = 'Check whether the walking is enabled or not: If the player is allowed to enter or exit vehicles by themselves.'
C.color = ui_flowgraph_editor.nodeColors.walking
C.icon = ui_flowgraph_editor.nodeIcons.walking
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'out', type = 'flow', name = 'allowed', description = "Outflow if the player is allowed to enter or exit vehicles." },
  { dir = 'out', type = 'flow', name = 'denied', description = "Outflow if the player is denied to enter or exit vehicles." },
  { dir = 'out', type = 'bool', name = 'value', description = "Boolean value of being allowed or denied.", hidden = true },
}
C.dependencies = {'gameplay_walk'}

function C:work(args)
  self.pinOut.value.value = gameplay_walk.isTogglingEnabled()
  self.pinOut.allowed.value = self.pinOut.value.value
  self.pinOut.denied.value = not self.pinOut.value.value
end

return _flowgraph_createNode(C)
