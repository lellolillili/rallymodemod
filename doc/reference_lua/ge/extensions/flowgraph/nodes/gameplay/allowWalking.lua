-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Allow Walking'
C.description = 'Allows or denies the use of Walking mode. This includes entering and exiting vehicles.'
C.color = ui_flowgraph_editor.nodeColors.walking
C.icon = ui_flowgraph_editor.nodeIcons.walking
-- C.category = 'rework_needed'
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = "Inflow for this node." },
  { dir = 'in', type = 'flow', name = 'allow', description = "Allows the usage of walking mode, letting the player enter and exit vehicles." },
  { dir = 'in', type = 'flow', name = 'deny', description = "Denies the usage of walking mode, forbidding players to enter or exit vehicles." },
  { dir = 'in', type = 'flow', name = 'set', description = "Sets walking mode to be allowed or denied, depending on the 'enable' pin below.", hidden = true },
  { dir = 'in', type = 'bool', name = 'enable', description = "If walking mode should be allowed or denied, used with the 'set' pin.", hidden = true },

  { dir = 'out', type = 'flow', name = 'flow', description = "Outflow for this node." },
}
C.dependencies = {'gameplay_walk'}

function C:work(args)

  if self.pinIn.flow.value then
    if self.pinIn.allow.value then
      gameplay_walk.enableToggling(true)
    end
    if self.pinIn.deny.value then
      gameplay_walk.enableToggling(false)
    end
    if self.pinIn.set.value then
      gameplay_walk.enableToggling(self.pinIn.enable.value)
    end
  end
  self.pinOut.flow.value = self.pinIn.flow.value
end

return _flowgraph_createNode(C)
