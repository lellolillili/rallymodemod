-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Get Powertrain Data'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle

C.description = 'Gets arbitrary Powertrain Data. If no ID is given, the current player vehicle is used.'
C.category = 'once_f_duration'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Id of the vehicle to affect.' },
  { dir = 'in', type = 'string', name = 'device', description = 'Name of the device the data should be taken from.' },
  { dir = 'in', type = 'string', name = 'property', description = 'Property of the device the data should be taken from.' },
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
    core_vehicleBridge.requestValue(veh, function(val) dump(val) dumpz(self, 1) self.receivedInfo = val.result end,'powertrainDevice', self.pinIn.device.value, self.pinIn.property.value)
    self:setDurationState('started')
  end
end

function C:work()
  if self.receivedInfo then
    print("OK")
    self.pinOut.value.value = self.receivedInfo
    self.receivedInfo = nil
    self:setDurationState('finished')
  end
end




return _flowgraph_createNode(C)
