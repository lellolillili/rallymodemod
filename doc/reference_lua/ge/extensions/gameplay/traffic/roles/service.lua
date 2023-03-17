-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

local slowSpeed = 2.5

function C:init()
  self.randomActionProbability = 0.4
  self.personalityModifiers = {
    aggression = {offset = 0.1},
    lawfulness = {offset = 0.5}
  }
  self.actions = {
    emergency = function (args)
      if self.veh.isAi then
        be:getObjectByID(self.veh.id):queueLuaCommand('ai.driveInLane("off")')
        be:getObjectByID(self.veh.id):queueLuaCommand('ai.setSpeedMode("off")')
        be:getObjectByID(self.veh.id):queueLuaCommand('ai.setAvoidCars("on")')
        be:getObjectByID(self.veh.id):queueLuaCommand('electrics.set_lightbar_signal(2)')
      end
      self.state = 'emergency'
    end
  }

  for k, v in pairs(self.baseActions) do
    self.actions[k] = v
  end
  self.baseActions = nil
end

function C:onRefresh()
  self.targetId = nil
  local personality = self.driver.personality

  local selfDamageAction, otherDamageAction = 'none', 'none'
  local damageThreshold = 0

  if self.veh.isAi then -- only calculates values if vehicle is AI
    damageThreshold = math.max(self.veh.damageLimits[1], square(((personality.bravery + personality.anger) * 0.5) * 10) * 10)
  end

  self.driver.behavioral = {
    pullOverWaitTime = personality.patience * 3,
    selfDamageThreshold = damageThreshold, -- minimum self damage to trigger action
    otherDamageThreshold = math.max(100, damageThreshold * 2), -- less concerned about other vehicles taking damage
    targetDistThreshold = 10 + personality.patience * 20, -- when target is over this distance, change action
    targetSightThreshold = 50 + personality.patience * 40 -- when target is over this interactive distance, prepare to reset action (give up)
  }
  self.driver.witnessed = {
    eventType = nil,
    selfHitCount = 0,
    otherHitCount = 0
  }
end

function C:tryRandomEvent()
  if math.random() <= self.randomActionProbability then
    local tagParkingSpots
    if gameplay_city and not next(self.flags) then
      --for _, tag in ipairs(self.veh.model.tags) do
      --end
    end

    if false and tagParkingSpots then
      local target = tagParkingSpots[1]
      local n1, n2 = map.findClosestRoad(target.pos)
      if n1 then
        local pos1, pos2 = map.getMap().nodes[n1].pos, map.getMap().nodes[n2].pos
        local tag
        if clamp(target.pos:xnormOnLine(pos1, pos2), 0, 1) > 0.5 then
          n1, n2 = n2, n1
        end

        self:setAction('driveToTarget', {target = n1})

        if tag == 'police' or tag == 'ambulance' or tag == 'fire' then
          self:setAction('emergency')
        end

        self.flags.mapTarget = true
        self.veh:modifyRespawnValues(600, 50)
      end
    end
  end
end

function C:onCollision(otherId, data)
  if self.veh.speed >= self.veh.tracking.speedLimit * 1.2 then -- speeding always means collision fault for self
    self.veh.collisions[otherId].fault = true
  end
  if self.driver.witnessed.eventType ~= 'selfCollision' then -- overrides previous events
    self.driver.witnessed.eventType = 'selfCollision'
    self:setTarget(otherId)
  end
  self.driver.witnessed.selfHitCount = data.count
end

function C:onOtherCollision(id1, id2, data)
  if self.driver.witnessed.eventType ~= 'selfCollision' then
    local targetVeh, secondVeh = gameplay_traffic.getTrafficData()[id1], gameplay_traffic.getTrafficData()[id2]
    if not targetVeh or not secondVeh then return end
    local targetId = targetVeh.speed < secondVeh.speed and id1 or id2 -- target the slower vehicle in collision
    if targetId == id2 then targetVeh = gameplay_traffic.getTrafficData()[targetId] end

    if self:checkTargetVisible(targetId) and self.veh:getInteractiveDistance(targetVeh.pos, true) <= square(self.driver.behavioral.targetSightThreshold) then
      if self.driver.witnessed.eventType ~= 'otherCollision' then
        self.driver.witnessed.eventType = 'otherCollision'
        self:setTarget(targetId)
      end
      self.driver.witnessed.otherHitCount = data.count
    end
  end
end

function C:onTrafficTick(tickTime)
  if self.state == 'disabled' then return end

  local targetVeh = self.targetId and gameplay_traffic.getTrafficData()[self.targetId]
  self.targetVisible = self:checkTargetVisible()
  self.targetNear = targetVeh and self.veh:getInteractiveDistance(targetVeh.pos, true) <= square(self.driver.behavioral.targetSightThreshold) or false

  if targetVeh then
    local driver = self.driver

    if self.targetVisible and self.targetNear then
      if self.state == 'none' then
        local brakeDist = self.veh:getBrakingDistance(self.veh.speed, driver.aggression * 1.5)

        -- target id collided with self
        if driver.witnessed.eventType == 'selfCollision' and self.veh.damage >= driver.behavioral.selfDamageThreshold then
          self:setAction('pullOver', {dist = brakeDist, reason = driver.witnessed.eventType, useWarnSignal = true})
          self.actionTimer = 7 + (driver.personality.bravery + driver.personality.patience) * 15

        -- target id visible and collided with other vehicle
        elseif driver.witnessed.eventType == 'otherCollision' and targetVeh.damage >= driver.behavioral.otherDamageThreshold then
          self:setAction('pullOver', {dist = brakeDist, reason = driver.witnessed.eventType, useWarnSignal = true})
          self.actionTimer = 7 + (driver.personality.bravery + driver.personality.patience) * 10
        end
      end
    else -- target not visible or out of range
      if self.state ~= 'none' then
        self:resetAction()
      end
    end
  end
end

function C:onUpdate(dt, dtSim)
  if self.state == 'disabled' then return end

  local targetVeh = self.targetId and gameplay_traffic.getTrafficData()[self.targetId]
  if targetVeh then
    if self.actionTimer > 0 then
      self.actionTimer = self.actionTimer - dtSim

      if self.flags.pullOver and self.actionTimer <= 0 then
        self:resetAction()
      end
    end
  end
end

return function(...) return require('/lua/ge/extensions/gameplay/traffic/baseRole')(C, ...) end