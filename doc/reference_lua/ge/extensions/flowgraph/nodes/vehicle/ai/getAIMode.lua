-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Get AI Mode'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Get AI mode of a vehicle.'
C.category = 'repeat_p_duration'
C.pinSchema = {
  { dir = 'in', type = 'number', name = 'VehId', description = 'ID of the vehicle. If empty, the Player vehicle will be used' },
  { dir = 'out', type = 'string', name = 'aiMode', description = 'Returns the current AI mode on the vehicle' },
}

C.tags = {}

function C:init()

end

function C:work()
  local veh
  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end
  if not veh then
    return
  end
  veh:queueLuaCommand(self:getCmd())
  if self.returnedMode ~= nil then
    self.pinOut.aiMode.value = self.returnedMode
  end
end

function C:_executionStarted()
  self.returnedMode = nil
end

function C:getCmd()
  return 'obj:queueGameEngineLua("core_flowgraphManager.getManagerByID('..self.mgr.id..').graphs['..self.graph.id..'].nodes['..self.id..']:getAIMode(\'"..ai.getState().mode.."\')")'
end

function C:getAIMode(mode)
  self.returnedMode = mode
end

return _flowgraph_createNode(C)
