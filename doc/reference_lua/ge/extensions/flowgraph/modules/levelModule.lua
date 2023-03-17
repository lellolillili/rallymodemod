-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local C = {}
C.moduleOrder = 100 -- low first, high later

function C:init()
  self.funs = {}
  self.uniqueFuns = {}
  self.prefabs = {}
  self.isLoadingLevel = false
  self.reloadCollisionOnLevelLoading = false
  self.reloadCollisionOnAfterTrigger = false
  self:clear()
end
function C:clear()
  table.clear(self.funs)
  table.clear(self.uniqueFuns)
  table.clear(self.prefabs)
  self.isLoadingLevel = false
  self.reloadCollisionOnLevelLoading = false
  self.reloadCollisionOnAfterTrigger = false
end

function C:beginLoadingLevel()
  self.isLoadingLevel = true
end

function C:finishedLevelLoading()
  if self.reloadCollisionOnLevelLoading then
    self.reloadCollisionOnLevelLoading = false
    be:reloadCollision()
  end
  for _, fun in ipairs(self.funs) do
    fun()
  end
  table.clear(self.funs)
  self.isLoadingLevel = false
end

function C:afterTrigger()
  if self.reloadCollisionOnAfterTrigger then
    self.reloadCollisionOnAfterTrigger = false
    be:reloadCollision()
  end
end

-- this function will delay another function until finishedLevelLoading is called, or will call it instantly if not level is being loaded.
function C:delayOrInstantFunction(fun)
  if self.isLoadingLevel then
    table.insert(self.funs, fun)
  else
    fun()
  end
end

function C:prefabLoaded(id)
  if self.isLoadingLevel then
    self.reloadCollisionOnLevelLoading = true
  else
    self.reloadCollisionOnAfterTrigger = true
  end
  table.insert(self.prefabs, id)
end

function C:executionStopped()
  self:clear()
end

return _flowgraph_createModule(C)