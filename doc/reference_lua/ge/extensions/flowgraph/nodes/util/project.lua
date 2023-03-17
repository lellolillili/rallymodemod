-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Get Project Info'
C.icon = "event_note"
C.description = "Gives some Info about the current project."
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'out', type = 'number', name = 'id', description = 'Id of the project.', hidden = true },
  { dir = 'out', type = 'string', name = 'name', description = 'Name of the project.' },
  { dir = 'out', type = 'string', name = 'description', description = 'Description of the project.' },
  { dir = 'out', type = 'flow', name = 'hasFilename', description = 'Flow when the project has been loaded from a file.', hidden = true },
  { dir = 'out', type = 'string', name = 'filename', description = 'Without .flow.json extension.', hidden = true },
  { dir = 'out', type = 'string', name = 'filepath', description = 'Complete savepath without .flow.json extension.', hidden = true },
  { dir = 'out', type = 'flow', name = 'hasLevel', description = 'Flow when the projects file was located inside a level folder.', hidden = true },
  { dir = 'out', type = 'string', name = 'level', description = 'Without .flow.json extension.', hidden = true },
  { dir = 'out', type = 'string', name = 'graph', description = 'Name of the current graph', hidden = true },
  { dir = 'out', type = 'number', name = 'graphId', description = 'Name of the current graph', hidden = true },
}

C.tags = {}

function C:init(mgr)
  self.clearOutPinsOnStart = false
end

function C:workOnce()
  self.pinOut.id.value = self.graph.mgr.id
  self.pinOut.name.value = self.graph.mgr.name
  self.pinOut.description.value = self.graph.mgr.description
  if self.mgr.savedFilename then
    self.pinOut.hasFilename.value = true
    local dir, fn, ext = path.splitWithoutExt(self.mgr.savedFilename, true)
    self.pinOut.filename.value = fn
    self.pinOut.filepath.value = self.mgr.savedDir .. fn
  end
  if self.mgr.savedDir then
    local level = path.levelFromPath(self.mgr.savedDir)
    if level then
      self.pinOut.hasLevel.value = true
      self.pinOut.level.value = level
    end
  end
  self.pinOut.graph.value = self.graph.name
  self.pinOut.graphId.value = self.graph.id
  self.pinOut.flow.value = true
end

return _flowgraph_createNode(C)
