-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'Get Level Data'
C.description = "Gets information about the current level"
C.color = im.ImVec4(0.03, 0.41, 0.64, 0.75)
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'out', type = 'flow', name = 'loaded', description = 'Puts out flow, once data is loaded.' },
  { dir = 'out', type = 'string', name = 'devName', default = "", description = "Name of the level" },
  { dir = 'out', type = 'string', name = 'directory', hidden = true, default = "", description = "Directory for the level" },
  { dir = 'out', type = 'string', name = 'path', hidden = true, default = "", description = "Path of the level" },
}


C.tags = {'gameplay', 'utils'}

function C:init()
  self.data.delayBufferFrames = 30
  self.bufferDelay = 0
end

function C:onClientStartMission(levelPath)
  self.bufferDelay = self.data.delayBufferFrames
end

function C:onClientEndMission()
  self.pinOut.loaded.value = false
end

function C:work()
  local levelPath = getMissionFilename()
  --log('I', logTag, "GetLevelData Node: "..tostring(levelPath))
  local dir, filename, ext = path.split(levelPath)
  --log('I', logTag, "dir: "..tostring(dir) .. "   filename: "..tostring(filename))
  -- local json = jsonReadFile(levelPath)
  local devName = string.gsub(dir, "(.*/)(.*)/", "%2")

  self.pinOut.directory.value = tostring(dir)
  self.pinOut.path.value = tostring(levelPath)
  self.pinOut.devName.value = tostring(devName)
  self.pinOut.loaded.value = self.bufferDelay <= self.data.delayBufferFrames
  self.bufferDelay = self.bufferDelay - 1
end

return _flowgraph_createNode(C)
