-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Load Project'
C.description = "Loads a project by name and starts it."
C.category = 'once_p_duration'

C.color = ui_flowgraph_editor.nodeColors.thread
C.icon = ui_flowgraph_editor.nodeIcons.thread
C.pinSchema = {
  { dir = 'in', type = 'string', name = 'path', description = 'Defines the file path to load the project from.' },
  { dir = 'out', type = 'number', name = 'id', description = 'Project ID for further processing.' },
}

C.tags = {}

function C:init(mgr, ...)
  self.targetId = nil
end

function C:postInit()
  self.pinInLocal.path.allowFiles = {
    {"Flowgraph Files",".flow.json"},
  }
end

function C:_executionStarted()
  self.targetId = nil
end

function C:_executionStopped()
  self.targetId = nil
end

function C:workOnce()
  local fp = self.mgr:getRelativeAbsolutePath({self.pinIn.path.value, self.pinIn.path.value .. ".flow.json"})
  self.targetId = self.mgr.modules.thread:startProjectFromFilepath(fp, self)
  self.pinOut.id.value = self.targetId
end


return _flowgraph_createNode(C)
