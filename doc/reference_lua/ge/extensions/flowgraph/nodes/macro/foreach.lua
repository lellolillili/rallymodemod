-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Foreach'
C.icon = "playlist_add"
C.color = im.ImVec4(0.9,0.2,0.9,.9)
C.description = "Creates one specific flowgraph for each object in a list and runs them."
C.category = 'logic'

C.pinSchema = {
    { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
    { dir = 'in', type = 'table', name = 'table', tableType = 'generic', description = 'The table to make flowgraphs for.' },
    { dir = 'in', type = 'string', name = 'elementFile', description = 'The file pointing to the flowgraph project to load for each element.' },
    --{ dir = 'out', type = 'flow', name = 'flow', hidden = true, description = 'Outflow for this node.' },
    --{ dir = 'out', type = 'flow', name = 'True', description = 'Outflow when the condition is true.' },
    --{ dir = 'out', type = 'flow', name = 'False', description = 'Outflow when the condition is false.' },
}

C.tags = {}


function C:init(mgr, ...)
  self.data.destroyTargetOnStop = true
  self.targets = nil
end

function C:postInit()
  self.pinInLocal.elementFile.allowFiles = {
    {"Flowgraph Files",".flow.json"},
  }
end

function C:_executionStopped()
  if self.targets and self.data.destroyTargetOnStop then
    -- kill target
    for _, mrg in ipairs(self.targets) do
      mgr:setRunning(false)
      core_flowgraphManager.removeNextFrame(self.mgr)
    end

  end
  self.targets = nil
end


function C:work()
  if self.pinIn.flow.value then
    if not self.done then
      local list = self.pinIn.table.value
      if list then
        self.targets = {}
        for key, value in ipairs(list) do
          local mgr = core_flowgraphManager.loadManager(self.pinIn.filepath.value)
          mgr.modules.foreach.key = key
          mgr.modules.foreach.value = value
          mgr:setRunning(true)
          table.insert(self.targets, mgr)
        end
      end
    end
    self.done = true
  end
end

return _flowgraph_createNode(C)
