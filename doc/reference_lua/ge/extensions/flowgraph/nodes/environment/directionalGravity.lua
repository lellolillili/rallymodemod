-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Directional Gravity'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle

C.description = 'Sets directional gravity using really large, really distant planets.'
C.category = 'dynamic_p_duration'
C.todo = "This node needs testing to see if it actually works correctly"

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Id of target vehicle.' },
  { dir = 'in', type = 'vec3', name = 'direction', hardcoded = true, default = {0,0,-1}, description = 'Direction of the gravity. Will be normalized in the node.' },
  { dir = 'in', type = 'number', name = 'magnitude', hardcoded = true, default = 1, description = 'Magnitude of the gravity in m/s^2.' },
}

C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}

C.tags = {}
C.gConst = 6.6742 * math.pow(10, -11) --(m3,s-2,kg-1)
function C:init()
  --self.data.clearPlanets = true
  self.data.showDebug = true
  self.planet = {}
end

function C:workOnce()
  self:setDirectionalGravity()
end

function C:work()
  if self.dynamicMode == 'repeat' then
    self:setDirectionalGravity()
  end
end

function C:setDirectionalGravity()
  if self.pinIn.direction.value == nil or self.pinIn.magnitude.value == nil then
    return
  end

  local veh
  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end

  if not veh then
    return
  end
  --if self.data.clearPlanets then
  -- veh:queueLuaCommand('obj:setPlanet')
  -- end
  local magnitude = self.pinIn.magnitude.value or 0
  local radius = 1000000
  local mass = (magnitude * radius * radius) / C.gConst
  local origin = veh:getPosition()
  local off = vec3(self.pinIn.direction.value)
  off = off:normalized()
  off = off * radius
  origin = origin + off

  local command = 'obj:setPlanets({'
  command = command .. (origin.x) .. ',' .. (origin.y) .. ',' .. (origin.z) .. ','
  command = command .. (radius) .. ','
  command = command .. (mass) .. '})'
  veh:queueLuaCommand(command)
  self.planet.origin = origin
  self.planet.mass = mass
  self.planet.radius = radius
end

function C:drawMiddle(builder, style)
  builder:Middle()

  if self.data.showDebug and self.planet.origin then

    local veh
    if self.pinIn.vehId.value then
      veh = scenetree.findObjectById(self.pinIn.vehId.value)
    else
      veh = be:getPlayerVehicle(0)
    end

    if veh then
      local center = vec3(self.planet.origin)
      local vehPos = veh:getPosition()
      local origin = veh:getPosition()
      local off = vec3(self.pinIn.direction.value):normalized() * 5

      debugDrawer:drawLine((origin + off), (origin - off),ColorF(0,0,1,0.5))
      local h = center:distance(vehPos)
      local grav = C.gConst * (self.planet.mass / (h*h))
      debugDrawer:drawText(veh:getPosition(), String("Force: " .. string.format('%0.2E', grav)), ColorF(0,0,0,1))
    end
  end

  if self.pinIn.mass.value and self.pinIn.radius.value then
    local surfaceGravity = C.gConst * (self.pinIn.mass.value / (self.pinIn.radius.value*self.pinIn.radius.value))
    im.Text("Surface Gravity: %0.3f", surfaceGravity)
  end
end


return _flowgraph_createNode(C)
