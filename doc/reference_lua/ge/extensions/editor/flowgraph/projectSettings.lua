-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local fg_utils = require('/lua/ge/extensions/flowgraph/utils')

local C = {}
C.windowName = 'projectSettings'
C.windowDescription = 'Project Settings'


function C:attach(mgr)
  self.mgr = mgr
  self.mgrNameField = im.ArrayChar(64, mgr.name)
  self.mgrAuthorField = im.ArrayChar(128, mgr.authors)
  self.diffPtr = im.IntPtr(mgr.difficulty)
end

function C:init()
  editor.registerWindow(self.windowName, im.ImVec2(150,300), nil, false)
end

function C:draw()

  if not editor.isWindowVisible(self.windowName) then return end
  self:Begin(self.windowDescription)
  im.Columns(2)
  im.SetColumnWidth(0, 100 * im.uiscale[0])
  im.Text("Project Name: ")
  im.NextColumn()
  im.PushItemWidth(im.GetContentRegionAvailWidth())
  if im.InputText("##projectName", self.mgrNameField,64) then
    local oldName = self.mgr.name
    self.mgr.name = ffi.string(self.mgrNameField)
    self.fgEditor.addHistory("Changed project name from " .. oldName .. " to " ..self.mgr.name, false)
  end
  im.PopItemWidth()
  im.NextColumn()
  im.Text("Description: ")
  im.NextColumn()
  local textinput = im.ArrayChar(512, tostring(self.mgr.description or ''))
  local editEnded = im.BoolPtr(false)
  if editor.uiInputTextMultiline('##prDesc', textinput, 512,im.ImVec2(im.GetContentRegionAvailWidth(),100), nil, nil, nil, editEnded) then
    self.mgr.description = ffi.string(textinput)
  end
  im.NextColumn()

  im.Text("Authors:")
  im.NextColumn()
  im.PushItemWidth(im.GetContentRegionAvailWidth())
  if im.InputText("##authors", self.mgrAuthorField,128) then
    local oldName = self.mgr.authors
    self.mgr.authors = ffi.string(self.mgrAuthorField)
    self.fgEditor.addHistory("Changed project Author from " .. oldName .. " to " ..self.mgr.authors, false)
  end
  im.NextColumn()

  im.Text("Difficulty:")
  im.NextColumn()
  im.PushItemWidth(im.GetContentRegionAvailWidth() - 100)
  editEnded = im.BoolPtr(false)
  editor.uiSliderInt('##Difficulty',self.diffPtr,0,100, nil, editEnded)
  if editEnded[0] then
    self.mgr.difficulty = self.diffPtr[0]
    self.fgEditor.addHistory("Changed project Difficulty to " .. self.mgr.difficulty, false)
  end
  local diffs = {'Easy','Medium','Hard','Very Hard'}
  im.SameLine()
  im.Text(diffs[math.floor(self.diffPtr[0]/25)+1] or 'Very Hard')
  im.NextColumn()

  im.Text("Is Scenario:")
  im.NextColumn()
  if im.Checkbox("##isScenario",im.BoolPtr(self.mgr.isScenario)) then
    self.mgr.isScenario = not self.mgr.isScenario
    self.fgEditor.addHistory("Changed project Scenario mode to " .. (self.mgr.isScenario and "'Scenario'" or "'Not Scenario'"), false)
  end
  im.NextColumn()

  if editor.getPreference("flowgraph.debug.editorDebug") then
    im.Text("Status")
    im.NextColumn()
    if self.mgr.hidden then
      editor.uiIconImage(editor.icons.visibility_off, im.ImVec2(20, 20))
      ui_flowgraph_editor.tooltip("This project is invisible. You can see it because you have Dev Mode enabled.")
      im.SameLine()
    end
    if self.mgr.transient then
      editor.uiIconImage(editor.icons.goat, im.ImVec2(20, 20))
      ui_flowgraph_editor.tooltip("This project is transient. It cannot be saved.")
      im.SameLine()
    end
    im.NextColumn()
  end

  im.Text("Filename")
  im.NextColumn()
  im.Text(tostring(self.mgr.savedFilename))
  im.NextColumn()

  im.Text("Save Directory")
  im.NextColumn()
  im.Text(tostring(self.mgr.savedDir))
  im.NextColumn()

  im.Columns(1)
  if im.Button("Save") then
    self.fgEditor.save()
  end
  im.SameLine()
  if im.Button("Save as...") then
    extensions.editor_fileDialog.saveFile(function(data)self.fgEditor.saveAsFile(data)end, {{"Node graph Files",".flow.json"}}, false, "/flowEditor/")
  end
  self:End()
end

function C:_onSerialize(data)

end

function C:_onDeserialized(data)

end

return _flowgraph_createMgrWindow(C)
