-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'AI Stop'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Lets the AI stop the vehicle.'
C.category = 'once_p_duration'
C.pinSchema = {
  { dir = 'out', type = 'flow', name = 'stopped', description = 'Outflow when the vehicle is stopped.' },
  { dir = 'in', type = 'number', name = 'aiVehId', description = 'ID of the target vehicle.' },
  { dir = 'in', type = 'number', name = 'checkVelocity', hidden = true, default = 0.01, hardcoded = true, description = 'If given, vehicle has to be slower than this to be considered arrived. Defaults to 0.01' },
}

C.tags = {'halt'}

function C:init()
  self.complete = false
end

function C:onNodeReset()
  self.complete = false
end

function C:_executionStarted()
  self:onNodeReset()
end

function C:workOnce()
  local source
  if self.pinIn.aiVehId.value and self.pinIn.aiVehId.value ~= 0 then
    source = scenetree.findObjectById(self.pinIn.aiVehId.value)
  else
    source = be:getPlayerVehicle(0)
  end
  if source then
    source:queueLuaCommand('ai.setState({mode = "stop"})')
  end
end

function C:work()
  if self.complete then
    self.pinOut.stopped.value = true
    return
  end

  local vData = map.objects[self.pinIn.aiVehId.value]
  if vData then
    self.complete = vData.vel:length() < (self.pinIn.checkVelocity.value or 0.01)
  end
end

return _flowgraph_createNode(C)
