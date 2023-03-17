-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Is Walking Blacklisted'
C.description = 'Checks if a vehicles is allowed or denied to be entered from walking mode.'
C.color = ui_flowgraph_editor.nodeColors.walking
C.icon = ui_flowgraph_editor.nodeIcons.walking
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = "The Id of the vehicle that should be allowed/denied." },
  { dir = 'out', type = 'flow', name = 'allowed', description = "Outflow if the vehicle is allowed." },
  { dir = 'out', type = 'flow', name = 'denied', description = "Outflow if the vehicle is denied." },
  { dir = 'out', type = 'bool', name = 'value', description = "Boolean value of being allowed or denied.", hidden = true },
}
C.dependencies = {'gameplay_walk'}

function C:work(args)
  if self.pinIn.vehId.value then
    self.pinOut.bool.value = not gameplay_walk.isVehicleBlacklisted(self.pinIn.vehId.value)
    self.pinOut.allowed.value = self.pinOut.bool.value
    self.pinOut.denied.value = not self.pinOut.bool.value
  else
    self.pinOut.value.value = nil
    self.pinOut.allowed.value = nil
    self.pinOut.denied.value = nil
  end
end


return _flowgraph_createNode(C)
