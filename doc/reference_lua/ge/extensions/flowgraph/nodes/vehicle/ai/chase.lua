-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'AI Chase'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Chases another vehicle or object until another command is given.'
C.category = 'once_p_duration'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'aiVehId', description = 'Defines the id of the vehicle to activate chase AI on.' },
  { dir = 'in', type = 'number', name = 'targetId', description = 'Defines the id of the vehicle to be chased.' },
}

C.tags = {}

function C:workOnce()
  if self.pinIn.targetId.value and self.pinIn.targetId.value ~= 0 then
    self:__setNodeError("work",nil)
    local source
    if self.pinIn.aiVehId.value and self.pinIn.aiVehId.value ~= 0 then
      source = scenetree.findObjectById(self.pinIn.aiVehId.value)
    else
      source = be:getPlayerVehicle(0)
    end
    source:queueLuaCommand('ai.setMode("chase")')
    source:queueLuaCommand('ai.setTargetObjectID('..self.pinIn.targetId.value..')')
  else
    self:__setNodeError("work","No target id given!")
  end
end

return _flowgraph_createNode(C)
