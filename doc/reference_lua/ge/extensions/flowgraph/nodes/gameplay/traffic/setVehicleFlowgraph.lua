-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Set Vehicle Flowgraph'
C.description = 'Sets a custom flowgraph to run using the traffic vehicle id; ideal for custom AI roles and actions.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'once_instant'
C.tags = {'traffic', 'ai', 'mode', 'flowgraph'}


C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle Id.', fixed = true },
  { dir = 'in', type = 'string', name = 'fgFile', description = 'Flowgraph file to run.', fixed = true }
}

C.allowedManualPinTypes = {
  flow = false,
  string = true,
  number = true,
  bool = true,
  any = true,
  table = true,
  vec3 = true,
  quat = true,
  color = true,
}


function C:init()
  self.savePins = true
  self.allowCustomInPins = true
  self:onNodeReset()
end

function C:_executionStopped()
  self:onNodeReset()
end

function C:onNodeReset()
  if self.vehId then
    local veh = gameplay_traffic.getTrafficData()[self.vehId]
    if veh then
      veh.role:clearFlowgraph()
    end
  end
  self.vehId = nil
end

function C:workOnce()
  self.vehId = self.pinIn.vehId.value
  local varData = {}
  for name, pin in pairs(self.pinIn) do
    if name ~= 'flow' and not pin.fixed then
      varData[name] = deepcopy(pin.value)
    end
  end



  local veh = gameplay_traffic.getTrafficData()[self.vehId or 0]
  if veh then
    veh.role:setupFlowgraph(self.pinIn.fgFile.value, varData)
    -- maybe do an error check here
  end
end

return _flowgraph_createNode(C)