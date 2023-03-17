-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'on Cannon Fired'
C.description = 'Detects when a cannon is fired.'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.category = 'repeat_instant'

C.pinSchema = {
    { dir = 'out', type = 'flow', name = 'cannonFired', description = "Outflow once when a cannon is fired.", impulse = true },
}
C.dependencies = {}



function C:workOnce()
  self.flag = false
end

function C:work(args)
  if self.flag then
    self.pinOut.cannonFired.value = true
    self.flag = false
  else
    self.pinOut.cannonFired.value = false
  end
end

function C:onCannonFired(id)
  self.flag = true
end

return _flowgraph_createNode(C)
