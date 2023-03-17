-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'AI Directly To'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Drives directly towards a target position.'
C.behaviour = { duration = true, once = true }
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'reset', description = 'Resets this node.', impulse = true },
  { dir = 'in', type = 'number', name = 'vehId', description = 'Id of vehicle to direct.' },
  { dir = 'in', type = 'vec3', name = 'target', description = 'Position to direct vehicle to.' },
  { dir = 'in', type = 'number', name = 'targetVelocity', description = 'Target velocity while driving to target position.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}
C.tags = {'manual', 'driveTo'}

function C:init()
  self.started = false
  self.complete = false
  self.data.minDistance = 1.5
  self.data.handBrakeWhenFinished = false
  self.data.straightenWheelsWhenFinished = false
  self.data.maxStepDistance = 5
end

function C:_executionStopped()
  self:reset()
end

function C:reset()
  self.started = false
  self.complete = false
  self:endAI()
end

function C:endAI()
  if self.pinIn.vehId.value and self.pinIn.vehId.value ~= 0 then
    local veh = scenetree.findObjectById(self.pinIn.vehId.value)
    if veh then
      veh:queueLuaCommand('ai:scriptStop('..tostring(self.data.handBrakeWhenFinished)..','..tostring(self.data.straightenWheelsWhenFinished)..')')
    end
  end
end

function C:setupAI()
  local veh
  if self.pinIn.vehId.value and self.pinIn.vehId.value ~= 0 then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  end
  if not veh then
    log("E","directlyTo","No Vehicle found!")
    return
  end

  local origin = vec3(veh:getPosition())
  local target = vec3(self.pinIn.target.value)
  local distance = (origin-target):length()
  local speed = self.pinIn.targetVelocity.value
  target = target - origin
  local steps = math.ceil(distance / self.data.maxStepDistance)
  local path = {}
  for i = 1, steps+3 do
    local vec = origin + (i/steps) * target
    local dst = (origin - vec):length()
    local t = dst / speed
    table.insert(path,{x = vec.x, y = vec.y, z = vec.z, t = t})
  end

  --[[ handle first node
  local up = vec3(0,0,1) -- hardcode up as up..
  local dir = vec3(road:getNodePosition(1)) - vec3(road:getNodePosition(0))
  dir = dir:normalized()
  path[1].dir = {x = dir.x, y = dir.y, z = dir.z}
  path[1].up = {x = up.x, y = up.y, z = up.z}
  ]]
  local aiPath = {path = path}
  veh:queueLuaCommand('ai.startFollowing(' .. serialize(aiPath) .. ', nil, 0, "neverReset")')
end


function C:work()
  if self.pinIn.reset.value then
    self:reset()
  end
  if self.pinIn.flow.value then
    if not self.complete then
      if not self.started then
        self:setupAI()
        self.started = true
      else
        local veh
        if self.pinIn.vehId.value and self.pinIn.vehId.value ~= 0 then
          veh = scenetree.findObjectById(self.pinIn.vehId.value)
        end
        if not veh then return end

        local origin = veh:getPosition()
        local target = vec3(self.pinIn.target.value)
        local distance = (origin - target):length()
        if distance < self.data.minDistance then
          self:endAI()
          self.complete = true
        end
      end
    end
    if self.complete then
      self.pinOut.flow.value = true
    end
  end
end


function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text("Complete " .. tostring(self.complete))
  im.Text("Started " .. tostring(self.started))
  --debugDrawer:drawSphere(self.position, 0.25, self.markerColor)
end

return _flowgraph_createNode(C)
