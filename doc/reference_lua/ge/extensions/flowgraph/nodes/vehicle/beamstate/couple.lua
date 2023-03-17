-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Toggle Coupling'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = "link"
C.description = [[Couples or decouples a vehicle. Mode can be toggle, activate, disable or detach.]]
C.category = 'repeat_p_duration'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Defines the id of the vehicle to couple.' },
  --{dir = 'in', type = 'bool', name = 'couple', description = 'Defines if the vehicle should be coupled.'},
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}
C.tags = {'attach','detach','trailer', 'couple'}

function C:init(mgr, ...)
  self.data.mode = "activate"
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
  if self.data.mode == 'toggle' then
    veh:queueLuaCommand("beamstate.toggleCouplers()")
  elseif self.data.mode == 'activate' then
    veh:queueLuaCommand("beamstate.activateAutoCoupling()")
  elseif self.data.mode == 'disable' then
    --veh:stopLatching()
    veh:queueLuaCommand("beamstate.disableAutoCoupling()")
  elseif self.data.mode == 'detach' then
    veh:queueLuaCommand("beamstate.detachCouplers()")
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text(self.data.mode)

  if not (
    self.data.mode == 'disable' or
    self.data.mode == 'activate' or
    self.data.mode == 'detach' or
    self.data.mode == 'toggle') then
    im.SameLine()
    im.Text("(!)")
  end
end

return _flowgraph_createNode(C)
