-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}

C.name = 'Drift tight drift'

C.description = "Set the tight drift zones"
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'vec3', name = 'zonePos', description = "The zone position"},
  { dir = 'in', type = 'quat', name = 'zoneRot', description = "The zone rotation"},
  { dir = 'in', type = 'vec3', name = 'zoneScl', description = "The zone scale"},

  { dir = 'out', type = 'flow', impulse = true, name = 'tightDrift', description = "Will fire when a tight drift is detected"},
  { dir = 'out', type = 'number', name = 'tightDriftScore', description = "The score obtained from the tight drift"},
}

C.tags = {'gameplay', 'utils'}

local callbacks
function C:work()
  callbacks = self.mgr.modules.drift:getCallBacks()

  local rot = quat(self.pinIn.zoneRot.value or {0,0,0,0})
  local scl = vec3(self.pinIn.zoneScl.value or {1, 1, 1})

  self.mgr.modules.drift:setTightDriftZone(
    {pos = vec3(self.pinIn.zonePos.value), 
      x = rot * vec3(scl.x,0,0), 
      y = rot * vec3(0,scl.y,0), 
      z = rot * vec3(0,0,scl.z)
    })

  self.pinOut.tightDrift.value = callbacks.tight
  self.pinOut.tightDriftScore.value = callbacks.tight

end

return _flowgraph_createNode(C)