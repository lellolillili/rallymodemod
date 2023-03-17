-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Get Gearboxmode'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle

C.description = 'Gets Gearboxmode. If no ID is given, the current player vehicle is used.'
C.category = 'once_f_duration'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Id of the vehicle to affect.' },
  { dir = 'out', type = 'any', name = 'value', description = 'The returned value.' },
}

C.tags = {}

function C:init()
  self:onNodeReset()
end
function C:_executionStarted()
  self:onNodeReset()
end

function C:onNodeReset()
  self.receivedInfo = nil
  self:setDurationState('inactive')
end

function C:workOnce()
  local veh
  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end
  if veh then
    core_vehicleBridge.requestValue(veh, function(val) self.receivedInfo = val.result end,"mainController", "gearboxMode")
    self:setDurationState('started')
  end
end

function C:work()
  if self.receivedInfo then
    self.pinOut.value.value = self.receivedInfo
    self.receivedInfo = nil
    self:setDurationState('finished')
  end
end




return _flowgraph_createNode(C)
