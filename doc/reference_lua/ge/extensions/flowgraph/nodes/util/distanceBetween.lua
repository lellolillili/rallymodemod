-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}

C.name = 'Distance Between'

C.description = 'Calculates distance between vehicles and or vectors. Returns 0 as default.'
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = {'number','vec3'}, name = 'posA', description = "Position a, can be either id of vehicle or vector." },
  { dir = 'in', type = {'number','vec3'}, name = 'posB', description = "Position b, can be either id of vehicle or vector." },
  { dir = 'out', type = 'number', name = 'distance', description = "Distance between position a and b." }
}

C.color = ui_flowgraph_editor.nodeColors.default

local zeroVec = vec3()

local posA = vec3()
local posB = vec3()
function C:work()
  posA:set(self:getPosition(self.pinIn.posA.value))
  posB:set(self:getPosition(self.pinIn.posB.value))

  if posA and posB then
    self.pinOut.distance.value = posB:distance(posA)
  else
    self.pinOut.distance.value = 0
  end
end

local pos = vec3()
function C:getPosition(pinInput)
  if type(pinInput) == 'number' then
    local veh = be:getObjectByID(pinInput)

    if veh then
      return veh:getPosition()
    else
      return zeroVec
    end
  elseif pinInput then
    pos:setFromTable(pinInput)
    return pos
  end
end

return _flowgraph_createNode(C)
