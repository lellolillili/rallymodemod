-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Play ScriptAI Recording'
C.description = 'Plays a recording made by the scriptAiManager. vehId can be nil to use player vehicle.'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.category = 'repeat_p_duration' -- technically f_duration, but no callback for complete pins

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'start', description = 'Starts the recording.', impulse = true},
  { dir = 'in', type = 'flow', name = 'stop', description = 'Stops the recording.', impulse = true },
  { dir = 'in', type = 'string', name = 'fileName', description = 'Defines the path to load recording from.' },
  { dir = 'in', type = 'number', name = 'vehId', description = 'Defines the vehicle to play recording on. If empty, the player vehicle is used.' },
  { dir = 'in', type = 'number', name = 'loopCount', description = 'Defines how often the recording should loop.' },
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}
C.tags = {'manual', 'scriptai'}

local trackFilePath = '/replays/scriptai/tracks/'
local trackFileExt = '.track.json'

function C:init()
  self.recording = nil
  self.data.renderDebug = false
  self.running = false
end

function C:postInit()
  self.pinInLocal.fileName.allowFiles = {
    {"ScriptAI Files",".track.json"},
  }
end

function C:play()
  self:loadRecording()
  if not self.recording then return end
  local veh
  if self.pinIn.vehId.value and self.pinIn.vehId.value ~= 0 then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end
  self.recording.recording.loopCount = self.pinIn.loopCount.value or -1
  self.recording.recording.loopType = "firstOnlyTeleport"
  veh:queueLuaCommand('ai.startFollowing(' .. serialize(self.recording.recording) .. ')')
  self.running = true
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
end


function C:loadRecording()
  local json = readJsonFile(self.mgr:getRelativeAbsolutePath(tostring(self.pinIn.fileName.value) .. trackFileExt))
  if not json then
    json = jsonReadFile(trackFilePath .. tostring(self.pinIn.fileName.value) .. trackFileExt)
  end
  self.recording = json
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
  if not self.recording then
    im.Text("No Recording found :")
    im.Text(tostring( self.pinIn.fileName.value))
  else
    im.Text("Recording Info:")
    im.Text("Veh: " .. self.recording.vehicle)
    im.Text("Lvl: " .. self.recording.levelName)
    im.Text("#Path: " .. #self.recording.recording.path)
    im.Text("Duration: " .. self.recording.recording.path[#self.recording.recording.path].t)

    if self.data.renderDebug then
      local lastP
      for _, p in pairs(self.recording.recording.path) do
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
