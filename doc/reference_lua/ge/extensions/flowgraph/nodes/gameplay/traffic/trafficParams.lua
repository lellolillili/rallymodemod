-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Traffic Parameters'
C.description = 'Sets various parameters for the traffic system.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'once_instant'
C.tags = {'traffic', 'ai', 'mode', 'settings', 'parameters'}

C.pinSchema = {
  { dir = 'in', type = 'string', name = 'aiMode', default = 'traffic', description = 'AI mode of all vehicles in traffic.' },
  { dir = 'in', type = 'number', name = 'spawnRate', default = 1, description = 'Respawn rate of traffic; can be between 0 and 3.' },
  { dir = 'in', type = 'number', name = 'directionBias', description = 'Respawn direction bias; can be between -1 and 1 (-1 is away from you, and 1 is towards you).' },
  { dir = 'in', type = 'number', name = 'risk', description = 'Average risk (or aggression) value of all traffic vehicles.' },
  { dir = 'in', type = 'number', name = 'poolAmount', hidden = true, description = 'Amount of inactive (or active) vehicles for the vehicle pooling system; check the Node Properties.' },
  { dir = 'in', type = 'bool', name = 'enableRandomEvents', hidden = true, default = true, description = 'Enable or disable random events in traffic (suspects, emergencies, etc.).' }
}

local aiModes = {'traffic', 'random', 'flee', 'chase', 'follow', 'stop'}

function C:init()
  self.vars = {}
  self.data.useActiveAmount = false
end

function C:postInit()
  local template = {}
  for _, v in ipairs(aiModes) do
    table.insert(template, {value = v})
  end
  self.pinInLocal.aiMode.hardTemplates = template
end

function C:workOnce()
  table.clear(self.vars)

  if self.pinIn.aiMode.value ~= nil then
    self.vars.aiMode = self.pinIn.aiMode.value
  end
  if self.pinIn.spawnRate.value ~= nil then
    self.vars.spawnValue = self.pinIn.spawnRate.value
  end
  if self.pinIn.directionBias.value ~= nil then
    self.vars.spawnDirBias = self.pinIn.directionBias.value
  end
  if self.pinIn.risk.value ~= nil then
    self.vars.baseAggression = self.pinIn.risk.value
  end
  if self.pinIn.poolAmount.value ~= nil then
    if self.data.useActiveAmount then
      self.vars.activeAmount = self.pinIn.poolAmount.value -- sets active amount
    else
      self.vars.activeAmount = gameplay_traffic.getNumOfTraffic() - self.pinIn.poolAmount.value -- sets inactive amount
    end
  end
  if self.pinIn.enableRandomEvents.value ~= nil then
    self.vars.enableRandomEvents = self.pinIn.enableRandomEvents.value
  end

  gameplay_traffic.setTrafficVars(self.vars)
end

return _flowgraph_createNode(C)