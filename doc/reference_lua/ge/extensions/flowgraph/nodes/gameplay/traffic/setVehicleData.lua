-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Set Traffic Vehicle Data'
C.description = 'Sets parameters for an individual vehicle currently active as traffic.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'once_instant'
C.tags = {'traffic', 'ai', 'mode', 'settings', 'parameters'}

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle Id.' },
  { dir = 'in', type = 'string', name = 'role', description = 'Class or role of the vehicle (standard, police, service, etc.).' },
  { dir = 'in', type = 'bool', name = 'enableRespawn', default = true, description = 'Enables or disables respawning for the vehicle.' },
  { dir = 'in', type = 'bool', name = 'enableTracking', default = true, description = 'Enables or disables tracking of driving stats, offenses, and police interactions.' },
  { dir = 'in', type = 'bool', name = 'enablePoolCycle', hidden = true, default = true, description = 'Enables or disables hiding the vehicle in the vehicle pool.' },
  { dir = 'in', type = 'bool', name = 'enableActions', hidden = true, default = true, description = 'Enables or disables automatic AI changes based on role.' },
  { dir = 'in', type = 'bool', name = 'changePaint', hidden = true, default = true, description = 'Enables or disables automatic color changes for the vehicle.' }
}

function C:init()
  self.vars = {}
end

function C:workOnce()
  local veh = gameplay_traffic.getTrafficData()[self.pinIn.vehId.value or 0]
  if veh then
    table.clear(self.vars)

    if self.pinIn.role.value ~= nil then
      veh:setRole(self.pinIn.role.value)
    end
    if self.pinIn.enableRespawn.value ~= nil then
      self.vars.enableRespawn = self.pinIn.enableRespawn.value
    end
    if self.pinIn.enableTracking.value ~= nil then
      self.vars.enableTracking = self.pinIn.enableTracking.value
    end
    if self.pinIn.enablePoolCycle.value ~= nil then
      self.vars.enableAutoPooling = self.pinIn.enablePoolCycle.value
    end
    if self.pinIn.enableActions.value ~= nil then
      veh.role.lockAction = not self.pinIn.enableActions.value
    end

    if self.pinIn.changePaint.value ~= nil then
      veh.model.paintMode = self.pinIn.changePaint.value and 1 or 0
    end

    for k, v in pairs(self.vars) do
      veh[k] = v
    end
  end
end

return _flowgraph_createNode(C)