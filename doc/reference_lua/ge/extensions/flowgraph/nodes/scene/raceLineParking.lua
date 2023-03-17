-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'RacelineParking'
C.description = 'Manages raceline parking.'
C.category = 'repeat_instant'

C.author = 'BeamNG'
C.pinSchema = {
  { dir = 'in', type = 'bool', name = 'imgui', description = "", hidden = true},
  { dir = 'in', type = 'flow', name = 'clear', description = "Triggering this will remove the markers.", impulse = true },
  { dir = 'in', type = 'number', name = 'vehId', description = "Id of the Vehicle to track." },
  { dir = 'in', type = 'vec3', name = 'position', description = "The position of this spot." },
  { dir = 'in', type = 'quat', name = 'rotation', description = "The rotation of this spot." },
  { dir = 'in', type = 'vec3', name = 'scale', description = "The scale of this spot." },
  { dir = 'in', type = 'bool', name = 'onlyForward', hidden = true, default = false, hardcoded = true, description = "If the vehicle can only park forward.." },
  { dir = 'in', type = 'bool', name = 'visibleMarkers', hidden = true, default = true, hardcoded = true, description = "Show visible markers." },
  { dir = 'in', type = 'number', name = 'stop_timer', hidden = true, hardcoded = true, default = 1, description = "Time until a vehicle is considered parked." },
  { dir = 'in', type = 'color', name = 'color_out', hidden = true, hardcoded = true, default = { 1, 0, 0, 1 }, description = "Color when Inside" },
  { dir = 'in', type = 'color', name = 'color_in', hidden = true, hardcoded = true, default = { 1, 0.5, 0, 1 }, description = "Color when Outside" },
  { dir = 'out', type = 'flow', name = 'inside', description = "Outflow for this node." },
  --{dir = 'out', type = 'flow', name = 'partlyInside', description = "Outflow for this node."},
  {dir = 'out', type = 'flow', name = 'stopped', description = "Outflow when the vehicle does not move for stop_timer seconds. (defaults to 1)"},
  {dir = 'out', type = 'flow', name = 'stopping', description = "When the vehicle is currently stopping.", hidden=true},
  { dir = 'out', type = 'number', name = 'stoppedPercent', description = "How much time has passed to stop the vehicle.", hidden = true },
  { dir = 'out', type = 'number', name = 'dotAngle', description = "Alignment of the Vehicle. 1 is perfectly aligned, 0 is right angle." },
  { dir = 'out', type = 'bool', name = 'forward', description = "True if the vehicle is parked forward, false if it is parked backwards." },
  { dir = 'out', type = 'number', name = 'sideDistance', description = "Distance in the left/right direction from the vehicle center to the position in." },
  { dir = 'out', type = 'number', name = 'forwardDistance', description = "Distance in the front/back direction from the vehicle center to the position in." },
}
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.tags = {}

function C:init(mgr, ...)

end

function C:_executionStarted()
  self.stopTimer = nil
end

function C:_executionStopped()
  self.stopTimer = nil
end

function C:onClientEndMission()
  self:_executionStopped()

end


function C:work(args)
  local name = "node_trigger_" .. tostring(os.time()) .. "_" .. self.id
  if self.pinIn.clear.value then
    self:_executionStopped()
    for _, p in pairs(self.pinOut) do p.value = nil end
  end
  if self.pinIn.flow.value then
    self:checkParking()
    self:drawDebug()
    if self.pinIn.imgui.value then
      self:drawImgui()
    end
  end
end

local scale = 35
local centerOffset = vec3(140,20)
local tlCenter = im.ImVec2(0,0)
local dl, wp
function C:toInternal2d(pos)
  --unit vectors in target space
  local rot = quat(self.pinIn.rotation.value)
  local xn, yn = rot * vec3(1,0,0), rot * vec3(0,-1,0)
  --
  local diff = pos - vec3(self.pinIn.position.value)
  return vec3(diff:dot(xn)*scale+centerOffset.x+tlCenter.x, diff:dot(yn)*scale + centerOffset.y+tlCenter.y, 0)
end
local colorWhite = im.GetColorU322(im.ImVec4(1, 1, 1, 1))
local cRed   = im.GetColorU322(im.ImVec4(1, 0.5, 0.5, 0.5))
local cGreen = im.GetColorU322(im.ImVec4(0.5, 1, 0.5, 0.5))
local cYellow = im.GetColorU322(im.ImVec4(1, 1, 0.5, 0.5))
local aL, bL = im.ImVec2(0,0), im.ImVec2(0,0)
function C:drawLine(line, color, thickness)
  for i = 1, #line-1 do
    aL.x = line[i].x
    aL.y = line[i].y
    bL.x = line[i+1].x
    bL.y = line[i+1].y
    im.ImDrawList_AddLine(dl, aL, bL, color or colorWhite, thickness)
  end
end

local wlml = {}
function C:worldLineToMapLine(line)
  table.clear(wlml)
  for _, p in ipairs(line) do
    table.insert(wlml,self:toInternal2d(p))
  end
  return wlml
end


function C:drawImgui()
  local childSize = im.ImVec2(280,300)
  tlCenter = im.GetCursorScreenPos()
  im.BeginChild1("parkingPreview", childSize, true, im.WindowFlags_NoScrollbar+im.WindowFlags_NoScrollWithMouse)
  local rot = quat(self.pinIn.rotation.value)
  dl = im.GetWindowDrawList()
  -- draw U-shape
  local x, y = rot * vec3(self.pinIn.scale.value[1],0,0), rot * vec3(0,self.pinIn.scale.value[2],0)
  local pos = vec3(self.pinIn.position.value)
  local clr
  clr = (self.frontOK and cGreen ) or (self.frontYellow and cYellow) or cRed
  self:drawLine(self:worldLineToMapLine({pos+x, pos-x}), clr, 8)
  self:drawLine(self:worldLineToMapLine({pos+x-y*self.pinIn.scale.value[3]/self.pinIn.scale.value[2], pos-x-y*self.pinIn.scale.value[3]/self.pinIn.scale.value[2]}), clr, 3)

  clr = self.leftOK and cGreen or cRed
  self:drawLine(self:worldLineToMapLine({pos-x-y, pos-x}), clr, 7)

  clr = self.rightOK and cGreen or cRed
  self:drawLine(self:worldLineToMapLine({pos+x, pos+x-y}), clr, 7)

  local veh = be:getPlayerVehicle(0)
  local ob = veh:getSpawnWorldOOBB()
  local vPos = vec3(map.objects[veh:getId()].pos)
  --self:drawLine(self:worldLineToMapLine({vPos, pos + vec3(0,10,0)}))
  self:drawLine(self:worldLineToMapLine({vec3(ob:getPoint(0)) , vec3(ob:getPoint(3)) , vec3(ob:getPoint(7)) , vec3(ob:getPoint(4)), vec3(ob:getPoint(0))}), nil, 2)
  local wCenter, w1, w2 = self:getVehicleFrontwheelsCenterPosition(veh, vec3())
  self:drawLine(self:worldLineToMapLine({w1,w2}), nil, 3)

  if self.frontOK and self.rightOK and self.leftOK then
    local rad = 130 - 125*self.pinOut.stoppedPercent.value
    local list = {}
    for i = 0, 24 do
      local off = quatFromEuler(0,0,math.pi*i/12) * vec3(rad, 0,0)
      table.insert(list,vec3(140,150)+vec3(tlCenter.x, tlCenter.y)+off)
    end
    self:drawLine(list, nil, 1)
  end

  im.EndChild()
end

function C:checkParking()
  local veh
  if self.pinIn.vehicleID.value then
    veh = scenetree.findObjectById(self.pinIn.vehicleID.value)
  else
    veh = be:getPlayerVehicle(0)
  end
  if not veh then return end
  local vehicleData = map.objects[veh:getId()]

  local vDirVec=veh:getDirectionVector()
  local tr = self.pinIn.rotation.value or {0,0,0,0}
  tr = quat(tr[1],tr[2],tr[3],tr[4])
  local yVec = tr*vec3(0,1,0)
  local tpos = vec3(self.pinIn.position.value or {0,0,0})


  local front = ((vDirVec:dot(yVec) > 0) and 1 or 0) +1
  local contained = false
  local clrIn = self.pinIn.color_in.value or {1,0.5,0,1}
  local clrOut = self.pinIn.color_out.value or {1,0,0,1}

  local fwd = veh:getDirectionVector():normalized()
  local zVec,yVec,xVec = tr*vec3(0,0,1), tr*vec3(0,1,0), tr*vec3(1,0,0)
  local fwdAligned = fwd:projectToOriginPlane(zVec):normalized()
  self.pinOut.dotAngle.value = math.abs(fwdAligned:dot(yVec))
  self.pinOut.forward.value = fwdAligned:dot(yVec) > 0



  local wCenter, w1, w2 = self:getVehicleFrontwheelsCenterPosition(veh, tpos)
  local alignedOffset = (wCenter - tpos):projectToOriginPlane(zVec)
  local w1Off, w2Off = (w1 - tpos):projectToOriginPlane(zVec), (w2 - tpos):projectToOriginPlane(zVec)
  self.pinOut.sideDistance.value = alignedOffset:dot(xVec)
  self.pinOut.forwardDistance.value = math.min(-w1Off:dot(yVec), -w2Off:dot(yVec))

  self.leftOK =  self.pinOut.sideDistance.value > -self.pinIn.scale.value[1]
  self.rightOK = self.pinOut.sideDistance.value <  self.pinIn.scale.value[1]
  self.frontOK = self.leftOK and self.rightOK and self.pinOut.forwardDistance.value >= 0 and self.pinOut.forwardDistance.value < self.pinIn.scale.value[3]
  self.frontYellow = self.leftOK and self.rightOK and self.pinOut.forwardDistance.value >= 0 and self.pinOut.forwardDistance.value < self.pinIn.scale.value[3]*2
  self.pinOut.inside.value = self.leftOK and self.rightOK and self.frontOK
  if not self.stopTimer then self.stopTimer = self.pinIn.stop_timer.value or 1 end

  self.pinOut.stopping.value = false
  if self.pinOut.inside.value and vehicleData.vel:length() <= 0.05 then
    self.stopTimer = self.stopTimer-self.mgr.dtSim
    self.pinOut.stoppedPercent.value = 1-clamp(self.stopTimer / (self.pinIn.stop_timer.value or 1), 0, 1)
    self.pinOut.stopping.value = true
  else
    self.stopTimer = self.pinIn.stop_timer.value or 1
    self.pinOut.stopping.value = false
    self.pinOut.stoppedPercent.value = 0
  end
  self.pinOut.stopped.value = self.stopTimer < 0
  if self.stopTimer < 0 then
    self.pinOut.stopping.value = false
  end

end

local function getTwoSmallestValues(values)
  local min1 = values[1]
  local min2 = values[2]

  if (min2.distance < min1.distance) then
    min1 = values[2]
    min2 = values[1]
  end

  for i=3, #values do
    if (values[i].distance < min1.distance) then
      min2 = min1
      min1 = values[i]
    elseif values[i].distance < min2.distance then
      min2 = values[i]
    end
  end

  if #values % 2 ~= 0 then
    return {min1, min1}
  end

  return {min1, min2}
end

function C:getVehicleFrontwheelsCenterPosition(vehicle, pos)
  if vehicle and pos then
    local wheels = {}
    local forward = map.objects[vehicle:getID()].dirVec
    forward = vec3(forward.x, forward.y, forward.z)
    -- We need to identify all vehicle wheels and then calculate the distance from the start line for each wheel
    for i=0, vehicle:getWheelCount()-1 do
      local axisNodes = vehicle:getWheelAxisNodes(i)
      local nodePos = vehicle:getNodePosition(axisNodes[1])
      nodePos = vec3(nodePos.x, nodePos.y, nodePos.z)
      table.insert(wheels,{wheelNodePos = vehicle:getPosition() + nodePos, distance = -nodePos:dot(forward)})
      --debugDrawer:drawTextAdvanced(vehicle:getPosition() + nodePos, String(tostring(-nodePos:dot(forward))),  ColorF(1,1,1,1), true, false, ColorI(0,0,0,192))
    end
    -- we need to find the wheels that are closest to the start line
    local closestWheels = getTwoSmallestValues(wheels)
    local wheel1 = closestWheels[1].wheelNodePos
    local wheel2 = closestWheels[2].wheelNodePos
    -- Point inbetween both wheels is calculated so that we can get a somewhat accurate distance measurement
    return  vec3((wheel1.x + wheel2.x)/2, (wheel1.y + wheel2.y)/2, (wheel1.z + wheel2.z)/2), vec3(wheel1), vec3(wheel2)
  end
end



function C:drawMiddle(builder, style)
  builder:Middle()
end

function C:_onSerialize(res)

end

function C:_onDeserialized(res)

end

function C:drawDebug()

  --local clr = clr or rainbowColor(0, 0, 1)


  local shapeAlpha = (drawMode == 'highlight') and 0.5 or 0.25
  local white, red, green, yellow = {1,1,1,1}, {1,0.5,0.5,1}, {0.5,1,0.5,1}, {1,1,0.5,1}
  local clr = white
  --debugDrawer:drawSphere((pos), 2, ColorF(clr[1],clr[2],clr[3],shapeAlpha))
  local rot = quat(self.pinIn.rotation.value)
  local x, y, z = rot * vec3(self.pinIn.scale.value[1],0,0), rot * vec3(0,self.pinIn.scale.value[2],0), rot * vec3(0,0,1)
  local pos = vec3(self.pinIn.position.value)

  clr = (self.frontOK and green ) or (self.frontYellow and yellow) or red
  -- one side
  debugDrawer:drawTriSolid(
    vec3(pos + x + z),
    vec3(pos + x    ),
    vec3(pos - x    ),
    ColorI(clr[1]*255,clr[2]*255,clr[3]*255,shapeAlpha*255))
  debugDrawer:drawTriSolid(
    vec3(pos - x    ),
    vec3(pos - x + z),
    vec3(pos + x + z),
    ColorI(clr[1]*255,clr[2]*255,clr[3]*255,shapeAlpha*255))
  -- other side
  debugDrawer:drawTriSolid(
    vec3(pos + x + z),
    vec3(pos - x    ),
    vec3(pos + x    ),
    ColorI(clr[1]*255,clr[2]*255,clr[3]*255,shapeAlpha*255))
  debugDrawer:drawTriSolid(
    vec3(pos - x    ),
    vec3(pos + x + z),
    vec3(pos - x + z),
    ColorI(clr[1]*255,clr[2]*255,clr[3]*255,shapeAlpha*255))

  clr = self.leftOK and green or red
  debugDrawer:drawTriSolid(
    vec3(pos - x + z),
    vec3(pos - x - y),
    vec3(pos - x    ),
    ColorI(clr[1]*255,clr[2]*255,clr[3]*255,shapeAlpha*255))
  debugDrawer:drawTriSolid(
    vec3(pos - x + z),
    vec3(pos - x    ),
    vec3(pos - x - y),
    ColorI(clr[1]*255,clr[2]*255,clr[3]*255,shapeAlpha*255))

  clr = self.rightOK and green or red
  debugDrawer:drawTriSolid(
    vec3(pos + x + z),
    vec3(pos + x - y),
    vec3(pos + x    ),
    ColorI(clr[1]*255,clr[2]*255,clr[3]*255,shapeAlpha*255))
  debugDrawer:drawTriSolid(
    vec3(pos + x + z),
    vec3(pos + x    ),
    vec3(pos + x - y),
    ColorI(clr[1]*255,clr[2]*255,clr[3]*255,shapeAlpha*255))


end

return _flowgraph_createNode(C)
