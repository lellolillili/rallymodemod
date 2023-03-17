-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Get Traffic Vehicle Data'
C.description = 'Gets parameters for an individual vehicle currently active as traffic.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'repeat_instant'
C.tags = {'traffic', 'ai', 'mode', 'settings', 'parameters'}


C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle Id.' },

  { dir = 'out', type = 'string', name = 'role', description = 'Class or role of the vehicle (standard, police, service, etc.).' },
  { dir = 'out', type = 'string', name = 'state', description = 'Traffic state of the vehicle.' },
  { dir = 'out', type = 'bool', name = 'camVisible', description = 'Is true if the game camera can see the vehicle.' },
  { dir = 'out', type = 'number', name = 'crashDamage', description = 'Maximum amount of damage recorded in a short time.' },
  { dir = 'out', type = 'number', name = 'respawnCount', description = 'Number of times the vehicle has respawned.' }
}

function C:work()
  local veh = gameplay_traffic.getTrafficData()[self.pinIn.vehId.value or 0]
  if veh then
    self.pinOut.role.value = veh.role.name
    self.pinOut.state.value = veh.state
    self.pinOut.camVisible.value = veh.camVisible
    self.pinOut.crashDamage.value = veh.crashDamage
    self.pinOut.respawnCount.value = veh.respawnCount
  end
end

return _flowgraph_createNode(C)