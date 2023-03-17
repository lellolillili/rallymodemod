-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'AI Flee'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Flees from another vehicle or object until another command is given.'
C.category = 'once_p_duration'
C.pinSchema = {
  { dir = 'in', type = 'number', name = 'aiVehId', description = 'Defines the id of the vehicle to activate the AI on.' },
  { dir = 'in', type = 'number', name = 'targetId', description = 'Defines the id of the vehicle to flee from.' },
}

C.tags = {}

function C:workOnce()
  if self.pinIn.targetId.value and self.pinIn.targetId.value ~= 0 then
    self:__setNodeError("work",nil)
    if self.pinIn.flow.value == true  then
      local source
      if self.pinIn.aiVehId.value and self.pinIn.aiVehId.value ~= 0 then
        source = scenetree.findObjectById(self.pinIn.aiVehId.value)
      else
        source = be:getPlayerVehicle(0)
      end

      source:queueLuaCommand('ai.setMode("flee")')
      source:queueLuaCommand('ai.setTargetObjectID('..self.pinIn.targetId.value..')')
    end
  else
    self:__setNodeError("work","No target id given!")
  end
end

return _flowgraph_createNode(C)
