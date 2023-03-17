-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'AI Path from File'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Provides a ScriptAI path.'
C.category = 'provider'

C.pinSchema = {
  { dir = 'out', type = 'table',  tableType = 'aiPath', name = 'path', description = 'AI path loaded from file.' },
}

C.tags = {'manual', 'driveTo', 'scriptai'}
local trackFilePath = '/replays/scriptai/tracks/'
local trackFileExt = '.track.json'

function C:init()
   self.files = FS:findFiles(trackFilePath, '*' .. trackFileExt, -1, true, false)
   self.fnShort = ""
   self.fileName = ""
   self.loadedFile = nil
end

function C:_executionStopped()
end

function C:drawCustomProperties()
  if im.Button("Refresh Files") then
    self.files = FS:findFiles(trackFilePath, '*' .. trackFileExt, -1, true, false)
    self.fnShort = ""
    self.fileName = ""
    self.loadedFile = nil
  end
  if im.BeginCombo("File##file" , self.fnShort) then
    for _, fileName in pairs(self.files) do
      local fnShort = string.sub(fileName, string.len(trackFilePath) + 1)
      fnShort = string.sub(fnShort, 1, string.len(fnShort) - string.len(trackFileExt))
      if im.Selectable1(fnShort, fnShort==self.fnShort) then
        self.fnShort = fnShort
        self.fileName = fileName
        self.loadedFile = nil
      end
    end
    im.EndCombo()
  end
end

function C:work()
  if self.loadedFile == nil then
    self.loadedFile = jsonReadFile(self.mgr:getRelativeAbsolutePath(self.fileName))
  end
  self.pinOut.path.value = self.loadedFile.recording
end


function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text(self.fnShort)
  im.Text((self.loadedFile == nil) and "Not Loaded." or "Loaded ")
end

function C:_onSerialize(res)
  res.fileName = self.fileName
end

function C:_onDeserialized(nodeData)
  self.fileName = nodeData.fileName or ""
  if self.fileName and self.fileName ~= "" then
    local fnShort = string.sub(self.fileName, string.len(trackFilePath) + 1)
    self.fnShort = string.sub(fnShort, 1, string.len(fnShort) - string.len(trackFileExt))
  end
end

return _flowgraph_createNode(C)
