-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local C = {}
C.moduleOrder = 000 -- low first, high later
C.idCounter = 0
function C:getFreeId()
  self.idCounter = self.idCounter +1
  return self.idCounter
end

function C:init()
  self:clear()
end

function C:clear()
  self.storedActions = {}
  self.actionsByName = {}
  self.addActions = {}
  self.removeActions = {}
  self.lists = {}
end

function C:registerList(list)
  local id = self:getFreeId()
  self.lists[id] = list
  return id
end

function C:blockActions(id)
  for k, p in ipairs(self.lists[id] or {}) do
    self.addActions[k] = p
  end
  self.changed = true
end

function C:allowActions(id)
  for k, p in ipairs(self.lists[id] or {}) do
    self.removeActions[k] = p
  end
  self.changed = true
end

function C:afterTrigger()
  if not self.changed then return end
  for _, act in ipairs(self.addActions) do
    self.actionsByName[act] = true
  end
  for _, act in ipairs(self.removeActions) do
    self.actionsByName[act] = nil
  end
  local list = {}
  for k, v in pairs(self.actionsByName) do
    table.insert(list, k)
  end

  core_input_actionFilter.setGroup('fg_filter_'..self.mgr.id, list)
  core_input_actionFilter.addAction(0, 'fg_filter_'..self.mgr.id, true)
  self.changed = false
end

function C:executionStopped()
  core_input_actionFilter.setGroup('fg_filter_'..self.mgr.id, list)
  core_input_actionFilter.addAction(0, 'fg_filter_'..self.mgr.id, false)
end

function C:executionStarted()

end


return _flowgraph_createModule(C)