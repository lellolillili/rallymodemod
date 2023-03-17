-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'AI Follow Path'
C.description = 'Follows a ScriptAI path.'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'reset', description = 'Resets this node so the path can be followed anew.', impulse = true },
  { dir = 'in', type = 'table', tableType = 'aiPath', name = 'path', description = 'AI Path to follow.' },
  { dir = 'in', type = 'number', name = 'vehId', description = 'Id of vehicle that should follow path.' },
  { dir = 'in', type = 'number', name = 'loopCount', hidden = true, description = 'Defines how many loops of the path should be driven.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}
C.tags = {'manual', 'scriptai'}


function C:init()
  self.started = false
  self.complete = false
  self.loopMode = "neverReset"
  self.data.handBrakeWhenFinished = false
  self.data.straightenWheelsWhenFinished = false
  self.timeScale = 1.0
end


function C:drawCustomProperties()
  local sclFloat = im.FloatPtr(self.timeScale)
  if im.InputFloat("Timescale",sclFloat,0.05, 1) then
    if sclFloat[0] < 0.25 then
      sclFloat[0] = 0.25
    end
    self.timeScale = sclFloat[0]
  end

  if im.BeginCombo("Reset Mode##rMode"..self.id , self.loopMode) then
    for _, mode in ipairs({"neverReset","alwaysReset","startReset"}) do
      if im.Selectable1(mode, mode==self.loopMode) then
        self.loopMode = mode
      end
    end
    im.EndCombo()
  end
  if self.veh and im.Button("Reset AI") then
      self:endAI()
  end
end

function C:endAI()
  self.veh:queueLuaCommand('ai:scriptStop('..tostring(self.data.handBrakeWhenFinished)..','..tostring(self.data.straightenWheelsWhenFinished)..')')
end

function C:onVehicleSubmitInfo(id, info, nodeID)
  if nodeID == nil or nodeID ~= self.id then return end
  if not self.started or self.complete then return end
  if tonumber(id) ~= self.pinIn.vehId.value then return end
  if info == nil then
    self.complete = true
    if self.veh then
      print("Completed!")
      self:endAI()
    end
  end

end


function C:_executionStopped()

  if self.started and not self.complete then
    if self.veh then
      print("resetting veh")
      self:endAI()
    end
  end
  self.started = false
  self.complete = false
end

function C:loadPath()
  self.path = self.pinIn.path.value
end

function C:setupAI()

  self:loadPath()
  if not self.path then return end
  local veh
  if self.pinIn.vehId.value and self.pinIn.vehId.value ~= 0 then
    self.veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    self.veh = be:getPlayerVehicle(0)
  end
  if not self.veh then return end
  local loopCount = self.pinIn.loopCount.value or 0
  local loopType = self.loopMode
  local path = {}
  for i, p in ipairs(self.path.path) do
    path[i] = {x=p.x, y=p.y, z=p.z, t=p.t / self.timeScale, dir = p.dir or nil, up = p.up or nil}
  end
  --dumpz(path, 3)
  self.veh:queueLuaCommand('ai.startFollowing(' .. serialize({path=path}) .. ',nil,'..loopCount..',"'..loopType..'")')
  --dump('ai.startFollowing(' .. serialize(self.path) .. ',)')
end


function C:work()
  if self.pinIn.reset.value then
    self.complete = false
    self.started = false
  end
  if self.complete then
    self.pinOut.flow.value = true
  else
    if not self.started then
      self:setupAI()
      self.started = true
    end
    be:queueAllObjectLua('obj:queueGameEngineLua("extensions.hook(\\"onVehicleSubmitInfo\\","..tostring(objectId)..","..serialize(ai.scriptState())..",'..self.id..')")')
  end
end

function C:_onSerialize(res)
  res.timeScale = self.timeScale
end

function C:_onDeserialized(nodeData)
  self.timeScale = nodeData.timeScale or 1
end


function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text("Complete " .. tostring(self.complete))
  im.Text("Started " .. tostring(self.started))
end

return _flowgraph_createNode(C)
