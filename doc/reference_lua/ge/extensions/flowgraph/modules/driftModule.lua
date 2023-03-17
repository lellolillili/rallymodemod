-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.moduleOrder = 0 -- low first, high later
C.hooks = {'onDriftTap', 'onDriftCrash', 'onDriftDonut', 'onTightDrift', 'onDriftCompleted'}
C.dependencies = {'gameplay_drift'}

function C:resetModule()
  self.tap = 0
  self.crash = 0
  self.donut = {ttl = 0}
  self.tight = {ttl = 0}
  self.driftComplete = {ttl = 0}
end

function C:resetExtension()
  gameplay_drift.reset()
end

function C:init()
  self:resetModule()
end

function C:executionStopped() 
  if gameplay_drift then
    gameplay_drift.stop()
  end
end

function C:onUpdate()
  if self.tight.ttl > 0 then self.tight.ttl = self.tight.ttl - 1 end
  if self.donut.ttl > 0 then self.donut.ttl = self.donut.ttl - 1 end
  if self.crash > 0 then self.crash = self.crash - 1 end
  if self.tap > 0 then self.tap = self.tap - 1 end
  if self.driftComplete.ttl > 0 then self.driftComplete.ttl = self.driftComplete.ttl - 1 end
end


function C:getCallBacks()
  return {
    tap = ((self.tap or 0) > 0) and true,
    crash = ((self.crash or 0) > 0) and true,
    donut = ((self.donut.ttl or 0) > 0) and self.donut.score,
    tight = ((self.tight.ttl or 0) > 0) and self.tight.score,
    complete = ((self.driftComplete.ttl or 0) > 0) and self.driftComplete.score,
  }
end

function C:onDriftCrash()
  self.crash = 2
end

function C:onDriftTap()
  self.tap = 2
end

function C:onTightDrift(score)
  self.tight = {ttl = 2, score = score}
end

function C:onDriftDonut(score)
  self.donut = {ttl = 2, score = score}
end

function C:onDriftCompleted(score)
  self.driftComplete = {ttl = 2, score = score}
end


function C:getScore()
  return gameplay_drift.getScore()
end

function C:getActiveDriftData()
  return gameplay_drift.getActiveDriftData()
end

function C:getVehId()
  return gameplay_drift.getVehId()
end

function C:getDriftOptions()
  return gameplay_drift.getDriftOptions()
end

function C:setTightDriftZone(newZone)
  gameplay_drift.setTightDriftZone(newZone)
end

function C:setVehId(vehId)
  gameplay_drift.setVehId(vehId)
end

function C:setAllowDonut(value)
  gameplay_drift.setAllowDonut(value)
end

function C:setAllowDrift(value)
  gameplay_drift.setAllowDrift(value)
end

function C:setAllowTightDrift(value)
  gameplay_drift.setAllowTightDrift(value)
end

function C:resetDonut()
  gameplay_drift.resetDonut()
end

return _flowgraph_createModule(C)