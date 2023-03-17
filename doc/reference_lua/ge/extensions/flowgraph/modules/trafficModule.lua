-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.moduleOrder = 0 -- low first, high later
C.hooks = {'onTrafficStarted', 'onTrafficStopped'}

function C:init()
  self:clear()
end

function C:clear()
  self.trafficActive = false
  self.keepTrafficState = false
end

function C:onTrafficStarted()
  self.trafficActive = true
  gameplay_traffic.setTrafficVars({enableRandomEvents = false})
end

function C:onTrafficStopped()
  self.trafficActive = false
  gameplay_traffic.setTrafficVars({enableRandomEvents = true})
end

function C:insertTraffic(id)
  gameplay_traffic.insertTraffic(id)
end

function C:removeTraffic(id)
  gameplay_traffic.removeTraffic(id)
end

function C:activateTraffic(vehList)
  gameplay_traffic.activate(vehList)
end

function C:deactivateTraffic()
  if self.trafficActive and not self.keepTrafficState then
    gameplay_traffic.deactivate()
  end
  self:clear()
end

function C:executionStopped()
  self:deactivateTraffic()
end

function C:getTrafficState()
  return gameplay_traffic.getState()
end

return _flowgraph_createModule(C)