-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Load Project'
C.description = "Loads a project by name and executes it. Paths relative to flowEditor/, also you can omit the file ending."
C.category = 'once_p_duration'

C.pinSchema = {
  { dir = 'in', type = 'string', name = 'filepath', description = 'Defines the file path to load the project from.' },
}

C.tags = {}

function C:init(mgr, ...)
  self.data.destroyTargetOnStop = true
  self.target = nil
end
function C:postInit()
  self.pinInLocal.filepath.allowFiles = {
    {"Flowgraph Files",".flow.json"},
  }
end


function C:_executionStopped()
  if self.target and self.data.destroyTargetOnStop then
    -- kill target
    self.target:setRunning(false)
    core_flowgraphManager.removeNextFrame(self.target)
  end
  self.target = nil
end

function C:workOnce()
  local mgr = core_flowgraphManager.loadManager("flowEditor/" .. self.pinIn.filepath.value .. ".flow.json")
  mgr:setRunning(true)
  self.target = mgr
end


return _flowgraph_createNode(C)
