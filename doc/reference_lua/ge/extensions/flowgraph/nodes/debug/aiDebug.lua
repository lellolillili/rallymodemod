-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

local modes = { 'off', 'target', 'trajectory', 'speeds', 'route' }

C.name = 'AI Debug Display'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Lets you hide or show various debug visualizations for AI.'
C.category = 'dynamic_p_duration'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', default = 0, description = "ID of the AI vehicle. no input will use the player vehicle." },
  { dir = 'in', type = 'string', name = 'mode', default = "off", hidden = true, hardcoded = true, description = "Mode can be off, target, trajectory, speeds or route." },
}

C.tags = { 'target', 'trajectory', 'route', 'debug' }

function C:init()

end

function C:postInit()
  local modeTypes = {}
  for _, tmp in ipairs(modes) do
    table.insert(modeTypes, { value = tmp })
  end
  self.pinInLocal.mode.hardTemplates = modeTypes
end

function C:workOnce()
  self:SetAIDebugMode()
end

function C:work()
  if self.dynamicMode == 'repeat' then
    self:SetAIDebugMode()
  end
end

function C:SetAIDebugMode()
  local veh
  if self.pinIn.vehId.value and self.pinIn.vehId.value ~= 0 then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end

  local mode = 'off'
  if self.pinIn.mode.value then
    mode = self.pinIn.mode.value
  end

  if veh then
    veh:queueLuaCommand('ai.setVehicleDebugMode({debugMode = "' .. mode .. '"})')
  end
end


return _flowgraph_createNode(C)
