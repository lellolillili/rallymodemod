-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'AI Disable'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Disables AI behaviour for this vehicle.'
C.category = 'repeat_p_duration'
C.pinSchema = {
  { dir = 'in', type = 'number', name = 'aiVehId', description = 'Defines the id of the vehicle to disable AI on.' },
}

C.tags = {}

function C:init()
  self.data.useScriptStop = false
  self.data.handBrakeWhenFinished = false
  self.data.straightenWheelsWhenFinished = false
end


function C:work()
  local source
  if self.pinIn.aiVehId.value and self.pinIn.aiVehId.value ~= 0 then
    source = scenetree.findObjectById(self.pinIn.aiVehId.value)
  else
    source = be:getPlayerVehicle(0)
  end
  if self.data.useScriptStop then
    source:queueLuaCommand('ai:scriptStop('..tostring(self.data.handBrakeWhenFinished)..','..tostring(self.data.straightenWheelsWhenFinished)..')')
  else
    source:queueLuaCommand('ai.setState({mode = "disabled"})')
  end
end


return _flowgraph_createNode(C)
