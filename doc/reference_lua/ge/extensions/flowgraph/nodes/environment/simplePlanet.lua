-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Simple Planet'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle

C.description = 'Creates a planet with the given parameters.'
C.todo = "This node needs testing to see if it actually works correctly"
C.category = 'once_p_duration'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Defines the id of the vehicle to apply gravity to.' },
  { dir = 'in', type = 'vec3', name = 'position', description = 'Defines the position to spawn planet in.' },
  { dir = 'in', type = 'number', name = 'radius', description = 'Defines the radius of the planet.' },
  { dir = 'in', type = 'number', name = 'mass', description = 'Defines the mass of the planet.' },
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}
C.tags = {}

function C:init()
  self.vehicle = nil
end

function C:onNodeReset()
  if self.vehicle then
    self.vehicle:queueLuaCommand("obj:setPlanets({})")
    self.vehicle = nil
  end
end

function C:workOnce()
  if self.pinIn.position.value == nil or self.pinIn.mass.value == nil or self.pinIn.radius.value == nil then
    return
  end

  local pos = vec3(self.pinIn.position.value)
  local radius = self.pinIn.radius.value
  local mass = self.pinIn.mass.value

  if self.pinIn.vehId.value then
    self.vehicle = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    self.vehicle = be:getPlayerVehicle(0)
  end

  local command = 'obj:setPlanets({'
  command = command .. (pos.x)..','..(pos.y)..','..(pos.z)..','
  command = command .. (radius) ..','
  command = command .. (mass)..'})'
  self.vehicle:queueLuaCommand(command)
end

function C:executionStopped()
  self:onNodeReset()
end


function C:drawMiddle(builder, style)
end


return _flowgraph_createNode(C)
