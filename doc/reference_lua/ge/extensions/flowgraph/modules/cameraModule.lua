-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- tracking player vehicle yes/no, observercam

local C = {}
C.moduleOrder = -500 -- low first, high later

C.idCounter = 0
function C:getFreeId()
  self.idCounter = self.idCounter +1
  return self.idCounter
end

function C:getUniqueName(prefix)
  return prefix.."-"..self:getFreeId()
end

function C:init()
  self.variables = require('/lua/ge/extensions/flowgraph/variableStorage')(self.mgr)
  self:clear()
end

function C:clear()
  self.variables:clear()
  self.activePathId = nil
  self.loopActivePath = nil
  self.completions = nil
  self.storedPaths = {}
  self.pathIds = {}
end

function C:findPath(name)
  if self.pathIds[name] then return self.pathIds[name] end
  local file, succ = self.mgr:getRelativeAbsolutePath({name, name..'.camPath.json'})
  if not succ then
    log("E","", "Could not find path to load!" .. name)
  end
  local path = core_paths.loadPath(file)
  local id = self:getFreeId()
  --dump(path)
  self.storedPaths[id] = path
  self.pathIds[name] = id
  return id
end

function C:addCustomPath(name, path, force)
  if not force and self.pathIds[name] then return self.pathIds[name] end
  local id = self:getFreeId()
  self.storedPaths[id] = path
  self.pathIds[name] = id
  return self.pathIds[name]
end


function C:getPath(id)
  return self.storedPaths[id]
end

function C:getPathDuration(id)
 return self.storedPaths[id] and self.storedPaths[id].markers[#self.storedPaths[id].markers].time or 0
end

function C:isPathComplete(id)
  return self.activePathId == id and self.completions > 0
end

function C:startPath(id, loop)
  local path = self.storedPaths[id]
  if not path then return end
  if commands.isFreeCamera() then
    commands.setGameCamera()
  end

  local initData = {}
  initData.useDtReal = true
  initData.reset = function (this) end
  --initData.getNextPath = function(this) return self.pathName end
  --initData.onNextControlPoint = nop--function(this,i,c) self:onNextControlPoint(i,c) end
  initData.finishedPath = function(this)
    self:finishedPath()
  end
  --local path = core_paths.loadPath(self.pathName)
  core_paths.playPath(path, 0, initData)

  self.loopActivePath = loop
  self.activePathId = id
  self.completions = 0
end

function C:cancelPathCam()
  core_paths.stopCurrentPath()
end

function C:finishedPath()
  if not self.loopActivePath then
    self:cancelPathCam()
    self.loopActivePath = nil
  end
  self.completions = (self.completions or 0) + 1
end

function C:endActivePath(id)
  if id and id ~= self.activePathId or not self.activePathId then
    return
  end
  self:cancelPathCam()
  self.activePathId = nil
  self.loopActivePath = nil
  self.completions = nil
end

function C:restartActivePath(id)
  if id and id ~= self.activePathId or not self.activePathId then
    return
  end
  self:startPath(id, self.loopActivePath)
end


function C:getCmd(id)
  return 'core_flowgraphManager.getManagerByID('..self.mgr.id..').modules.button:buttonClicked('..id..')'
end


function C:afterTrigger()
  self.variables:finalizeChanges()
  if self.scheduleAction then

  end
end

function C:executionStopped()
  if self.activePathId then
    self:cancelPathCam()
  end
  self:clear()
end

return _flowgraph_createModule(C)