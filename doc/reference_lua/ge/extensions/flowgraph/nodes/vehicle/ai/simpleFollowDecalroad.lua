-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Follow Decalroad'
C.description = 'Lets a Vehicle follow a Decalroad very simply.'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.behaviour = { duration = true }
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'start', description = 'When receiving flow, starts the AI.' },
  { dir = 'in', type = 'flow', name = 'stop', description = 'When receiving flow, stops the AI.' },
  { dir = 'in', type = 'string', name = 'roadName', description = 'Defines the name of the road to follow.' },
  { dir = 'in', type = 'number', name = 'vehId', description = 'Defines the id of the vehicle to activate AI on.' },
  { dir = 'in', type = 'number', name = 'loopCount', hidden = true, description = 'Defines the amount of loops for the AI to drive.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
  { dir = 'out', type = 'flow', name = 'active', description = 'Puts out flow, while the AI is active.' },
  { dir = 'out', type = 'flow', name = 'finished', description = 'Puts out flow, when the AI is finished.' },
  { dir = 'out', type = 'number', name = 'progress', description = 'Puts out the relative progress from 0 to 1.' },
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}
C.tags = {'scriptai','path'}

function C:init()
  self.path = nil
  self.data.renderDebug = false
  self.data.speed = 5
  self.data.loopMode = "startReset"
  self.running = false
  self.flags = {
    finished = false
  }
  self.progress = 0
  self.receivedInfo = false
  be:queueAllObjectLua('obj:queueGameEngineLua("extensions.hook(\\"onVehicleSubmitInfo\\","..tostring(objectId)..","..serialize(ai.scriptState())..")")')
end

function C:onVehicleSubmitInfo(id, info)

  if not self.running then return end
  if tonumber(id) ~= self.pinIn.vehId.value then return end
  if info == nil then
    self.pinOut.active = false
    self.pinOut.finished = true
    self.running = false
  end
  local prog = info.scriptTime / info.endScriptTime
  self.pinOut.progress.value = prog
  self.receivedInfo = true
end


function C:play()
  self:loadRecording()
  if not self.path then return end
  local veh
  if self.pinIn.vehId.value and self.pinIn.vehId.value ~= 0 then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end

  veh:queueLuaCommand('ai.startFollowing(' .. serialize(self.path) .. ',nil,'..(self.pinIn.loopCount.value or -1)..',"'..self.data.loopMode..'")')
  --dump('ai.startFollowing(' .. serialize(self.path) .. ',)')
  self.running = true
  self.pinOut.finished.value = false
  self.pinOut.active.value = true
  self.receivedInfo = true
  self.pinOut.progress.value = 0
end

function C:stop()
  local veh
  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end
  veh:queueLuaCommand('ai.stopFollowing()')
  self.running = false
  self.pinOut.finished.value = false
  self.pinOut.active.value = false
end


function C:loadRecording()
  local road = scenetree.findObject(self.pinIn.roadName.value or "")
  if not road then return end

  self.distance = 0
  local path = {}
  local segCount = road:getNodeCount() - 1
  for i = 0, segCount-1 do
    local vec = vec3(road:getNodePosition(i))
    table.insert(path,{x = vec.x, y = vec.y, z = vec.z, t = self.distance / self.data.speed})
    self.distance = self.distance + (vec3(road:getNodePosition(i+1)) - vec3(road:getNodePosition(i))):length()
  end

  -- handle first node
  local up = vec3(0,0,1) -- hardcode up as up..
  local dir = vec3(road:getNodePosition(1)) - vec3(road:getNodePosition(0))
  dir = dir:normalized()
  path[1].dir = {x = dir.x, y = dir.y, z = dir.z}
  path[1].up = {x = up.x, y = up.y, z = up.z}

  self.path = {path = path, loopCount = self.pinIn.loopCount.value or -1}
end

function C:work()
  if self.pinIn.start.value then
    self:play()
  elseif self.pinIn.stop.value then
    self:stop()
  end

end


function C:drawMiddle(builder, style)
  builder:Middle()
  if im.SmallButton("Load") then
    self:loadRecording()
  end
  if self.running then
    im.Text("Running.")
  else
    im.Text("Stopped.")
  end
  if not self.path then
    im.Text("No Road found:")
    im.Text(tostring( self.pinIn.roadName.value))
  else
    im.Text("Path Info:")
    im.Text("#Nodes: " .. #self.path.path)
    im.Text("Distance: %0.2f", self.distance)

    if self.data.renderDebug then
      local lastP
      for _, p in pairs(self.path.path) do
        debugDrawer:drawSphere(vec3(p), 0.1, ColorF(1,0,1,1))
        if lastP then
          debugDrawer:drawSquarePrism(vec3(lastP), vec3(p), Point2F(0.6, 0.1), Point2F(0.6, 0.1), ColorF(1,0,1,0.1))
        end
        lastP = p
      end
    end
  end
end

return _flowgraph_createNode(C)
