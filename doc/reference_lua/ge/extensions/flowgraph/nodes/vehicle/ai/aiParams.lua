-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'AI Parameters'
C.description = 'Sets various parameters of the AI.'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.category = 'repeat_p_duration'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', default = 0, description = 'ID of the AI vehicle. no input will use the player vehicle.' },
  { dir = 'in', type = 'number', name = 'risk', default = 0.3, description = 'Riskiness of the vehicle.' },
  { dir = 'in', type = 'number', name = 'routeSpeed', default = 0, description = 'Route speed of the vehicle in m/s (meters per second)' },
  { dir = 'in', type = 'string', name = 'routeMode', default = 'off', description = 'How the vehicle should interpret the route speed. Available: off, set, limit.' },
  { dir = 'in', type = 'number', name = 'drivabilityCO', hidden = true, default = 0, description = 'Only drives on roads with higher drivability. Use values below 1, otherwise no road will be allowed.' },
  { dir = 'in', type = 'bool', name = 'inLane', default = false, description = 'Whether or not the vehicle should use lanes.' },
  { dir = 'in', type = 'bool', name = 'avoidCars', hidden = true, default = true, description = 'Whether or not the vehicle should try to avoid collisions.' },
  { dir = 'in', type = 'bool', name = 'forceRisk', hidden = true, default = false, description = 'Forces the risk value to be used for flee and chase modes.' },
  { dir = 'in', type = 'bool', name = 'activateNitrous', hidden = true, default = false, description = 'Activate or desactivate the Nitrous Oxide Injection of the vehicle.' }
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}
C.tags = { 'risk', 'route', 'lane', 'drivability', 'behaviour', 'traffic' }

function C:postInit()
  self.pinInLocal.risk.numericSetup = {
    min = 0.1,
    max = 2.0,
    type = 'float',
    gizmo = 'slider',
  }

  self.pinInLocal.routeMode.hardTemplates = {
    { label = 'off', value = 'off' },
    { label = 'set', value = 'set' },
    { label = 'limit', value = 'limit' },
  }
end

function C:work()
  local veh
  if self.pinIn.vehId.value and self.pinIn.vehId.value ~= 0 then
    veh = be:getObjectByID(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end

  if self.pinIn.risk.value ~= nil then
    veh:queueLuaCommand('ai.setAggression('..clamp(self.pinIn.risk.value,0.1,2.0)..')')
  end
  if self.pinIn.routeSpeed.value ~= nil then
    veh:queueLuaCommand('ai.setSpeed('..self.pinIn.routeSpeed.value..')')
  end
  if self.pinIn.routeMode.value ~= nil then
    veh:queueLuaCommand('ai.setSpeedMode("'..self.pinIn.routeMode.value..'")')
  end
  if self.pinIn.drivabilityCO.value ~= nil then
    veh:queueLuaCommand('ai.setCutOffDrivability('..self.pinIn.drivabilityCO.value..')')
  end
  if self.pinIn.inLane.value ~= nil then
    veh:queueLuaCommand('ai.driveInLane("'..(self.pinIn.inLane.value and 'on' or 'off')..'")')
  end
  if self.pinIn.avoidCars.value ~= nil then
    veh:queueLuaCommand('ai.setAvoidCars("'..(self.pinIn.avoidCars.value and 'on' or 'off')..'")')
  end
  if self.pinIn.forceRisk.value ~= nil then
    veh:queueLuaCommand('ai.setAggressionMode("'..(self.pinIn.forceRisk.value and 'off' or 'rubberBand')..'")')
  end
  if self.pinIn.activateNitrous.value ~= nil then
    if self.pinIn.activateNitrous.value then
      veh:queueLuaCommand('if electrics.values.jatoInput then electrics.values.jatoInput = 1 end')
      veh:queueLuaCommand([[local nc = controller.getController("nitrousOxideInjection")
      if nc then
        local engine = powertrain.getDevice("mainEngine")
        if engine and engine.nitrousOxideInjection and not engine.nitrousOxideInjection.isArmed then
          nc.toggleActive()
        end
      end]])
    else
      veh:queueLuaCommand('if electrics.values.jatoInput then electrics.values.jatoInput = 0 end')
      veh:queueLuaCommand([[local nc = controller.getController("nitrousOxideInjection")
      if nc then
        local engine = powertrain.getDevice("mainEngine")
        if engine and engine.nitrousOxideInjection and engine.nitrousOxideInjection.isArmed then
          nc.toggleActive()
        end
      end]])
    end
  end
end


return _flowgraph_createNode(C)
