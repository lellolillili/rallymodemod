-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local min = math.min
local max = math.max
local ceil = math.ceil
local random = math.random

local C = {}

local slowSpeed = 2.5

function C:init()
  self.randomActionProbability = 0.25
  self.autoRandomActionProbability = true
  self.personalityModifiers = {}
  self.actions = {
    fleePostCrash = function (args)
      if self.veh.isAi then
        self.veh:setAiMode('flee')
        local obj = be:getObjectByID(self.veh.id)
        obj:queueLuaCommand('ai.driveInLane("off")')
        obj:queueLuaCommand('ai.setAggressionMode("off")')
        obj:queueLuaCommand('ai.setAggression(0.6)')
      end
      self.state = 'flee'
      self.flags.askInsurance = nil
    end,
    followPostCrash = function (args)
      if self.veh.isAi then
        self.veh:setAiMode('follow')
        local obj = be:getObjectByID(self.veh.id)
        obj:queueLuaCommand('ai.driveInLane("off")')
        obj:queueLuaCommand('ai.setAggressionMode("off")')
        obj:queueLuaCommand('ai.setAggression(0.3)')
      end
      self.state = 'follow'
      self.flags.askInsurance = nil
    end,
    askInsurance = function (args)
      if self.veh.isAi then
        self.veh:setAiMode('stop')
      end
      self.flags.askInsurance = nil
    end
  }

  for k, v in pairs(self.baseActions) do
    self.actions[k] = v
  end
  self.baseActions = nil
end

function C:onRefresh()
  self.targetId = nil
  self.actionTimer = 0
  if self.autoRandomActionProbability then
    self.randomActionProbability = min(0.25, 1 / max(1, gameplay_traffic.getNumOfTraffic(true))) -- dependent on amount of traffic
  end
  local personality = self.driver.personality

  local trafficPlayer = gameplay_traffic.getTrafficData()[be:getPlayerVehicleID(0)]
  local trafficPlayerRole = trafficPlayer and trafficPlayer.role.name
  local selfDamageAction, otherDamageAction = 'none', 'none'
  local damageThreshold = 1000
  local hitThreshold = 1
  local patienceValue = 0

  if self.veh.isAi and trafficPlayerRole ~= 'police' then -- only calculates values if vehicle is AI, and the player is not police
    local actionValue = (personality.bravery + personality.anger) * 0.5
    local result = lerp(actionValue - 0.5, actionValue + 0.5, random())

    -- higher actionValue results in a probability bias towards a higher result
    if result > 2 / 3 then
      selfDamageAction = 'followPostCrash'
    elseif result > 1 / 3 then
      selfDamageAction = 'stop'
    else
      selfDamageAction = 'fleePostCrash'
      hitThreshold = clamp(ceil(personality.bravery * 10 - 2), 2, 8)
    end

    damageThreshold = max(self.veh.damageLimits[1], square(actionValue * 10) * 10)

    actionValue = personality.bravery
    result = lerp(actionValue - 0.5, actionValue + 0.5, random())

    if result > 0.5 then
      otherDamageAction = 'none'
    else
      otherDamageAction = 'fleePostCrash'
    end

    patienceValue = personality.patience
  end

  self.driver.behavioral = {
    selfDamageAction = selfDamageAction,
    otherDamageAction = otherDamageAction,
    selfDamageThreshold = damageThreshold, -- minimum self damage to trigger action
    otherDamageThreshold = max(500, damageThreshold * 4), -- less concerned about other vehicles taking damage
    selfHitThreshold = hitThreshold,
    otherHitThreshold = hitThreshold + 1,
    willHelp = patienceValue > 0.25,
    targetDistThreshold = 10 + patienceValue * 20, -- distance threshold for stuff like askInsurance
    targetSightThreshold = 20 + patienceValue * 60, -- general sight threshold
    askInsurance = true
  }
  self.driver.witnessed = { -- reactions
    eventType = nil,
    otherHelpers = 0,
    selfHitCount = 0,
    otherHitCount = 0
  }
end

function C:tryRandomEvent()
  if random() <= self.randomActionProbability then
    local trafficPlayer = gameplay_traffic.getTrafficData()[be:getPlayerVehicleID(0)]
    local minLawfulness = 0.25
    if trafficPlayer and trafficPlayer.role.name == 'police' then
      minLawfulness = trafficPlayer.role.flags.busy == 1 and 0 or 0.5 -- normal value if player is not busy with a subtask
    end
    if self.driver.personality.lawfulness < minLawfulness then
      gameplay_police.setSuspect(self.veh.id)
    end
  end
end

function C:onCrashDamage(data)
  -- triggers if self is currently not in a collision or witness to one
  if self.driver.witnessed.eventType ~= 'selfCollision' and self.driver.witnessed.eventType ~= 'otherCollision' then
    self.driver.witnessed.eventType = 'selfCrash'
  end
end

function C:onOtherCrashDamage(otherId, data)
  -- triggers if self is currently not in a collision or witness to one
  if self.driver.witnessed.eventType ~= 'selfCollision' and self.driver.witnessed.eventType ~= 'otherCollision' then
    self.driver.witnessed.eventType = 'otherCrash'
    self:setTarget(otherId)
  end
end

function C:onCollision(otherId, data)
  if self.veh.speed >= self.veh.tracking.speedLimit * 1.2 then -- speeding always means collision fault for self
    self.veh.collisions[otherId].fault = true
  end
  if self.driver.witnessed.eventType ~= 'selfCollision' then -- overrides previous events
    self.driver.witnessed.eventType = 'selfCollision'
    self.driver.behavioral.targetSightThreshold = min(120, self.driver.behavioral.targetSightThreshold * 1.4)
    self:setTarget(otherId)

    if self.driver.personality.anger > 0.7 then
      self.veh:honkHorn(max(0.25, (self.driver.personality.anger - 0.7) * 4))
    end
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

        if self.driver.personality.anger > 0.7 then
          self.veh:honkHorn(max(0.25, (self.driver.personality.anger - 0.7) * 2))
        end
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
      local brakeDist = self.veh:getBrakingDistance(self.veh.speed, driver.aggression * 1.5)
      local driveVecDotTarget = self.veh.driveVec:dot(targetVeh.pos - self.veh.pos)

      -- target id collided with self
      if driver.witnessed.eventType == 'selfCollision' and self.veh.damage >= driver.behavioral.selfDamageThreshold then
        if driver.witnessed.selfHitCount >= driver.behavioral.selfHitThreshold then
          if driver.behavioral.selfDamageAction == 'followPostCrash' and self.state ~= 'follow' then
            self:setAction('followPostCrash', {reason = driver.witnessed.eventType, targetId = self.targetId})
            self.actionTimer = 7 + driver.personality.bravery * 10
          elseif driver.behavioral.selfDamageAction == 'fleePostCrash' and self.state ~= 'flee' then
            self:setAction('fleePostCrash', {reason = driver.witnessed.eventType, targetId = self.targetId})
            self.actionTimer = 7 - driver.personality.bravery * 5
          end
          driver.behavioral.selfHitThreshold = driver.behavioral.selfHitThreshold * 2
        end

        if self.state == 'none' then
          self:setAction('pullOver', {dist = brakeDist, reason = driver.witnessed.eventType, useWarnSignal = true})
          if self.driver.behavioral.askInsurance then
            self.flags.askInsurance = 1
            self.actionTimer = 5
          end
        end

      -- target id visible and collided with other vehicle
      elseif driver.witnessed.eventType == 'otherCollision' and targetVeh.damage >= driver.behavioral.otherDamageThreshold then
        if driver.witnessed.otherHitCount >= driver.behavioral.otherHitThreshold then
          if driver.behavioral.otherDamageAction == 'fleePostCrash' and self.state ~= 'flee' then
            self:setAction('fleePostCrash', {reason = driver.witnessed.eventType, targetId = self.targetId})
          end
          driver.behavioral.otherHitThreshold = driver.behavioral.otherHitThreshold * 2
        end

        if self.state == 'none' and driver.behavioral.willHelp and driveVecDotTarget > 0 then
          self:setAction('followPostCrash', {reason = driver.witnessed.eventType, targetId = self.targetId})
          self.actionTimer = 2 + (driver.personality.bravery + driver.personality.patience) * 15
        end

      -- target id visible and crashed by itself
      elseif driver.witnessed.eventType == 'otherCrash' then
        if not self.flags.pullOver and driver.behavioral.willHelp and driveVecDotTarget > 0 then
          self:setAction('pullOver', {dist = brakeDist, reason = driver.witnessed.eventType, useWarnSignal = true})
          self.flags.stopAndHelp = 1
          self.actionTimer = 2 + (driver.personality.bravery + driver.personality.patience) * 10
        end
      end
    else -- target not visible or out of range
      if self.state ~= 'none' and self.veh.pos:squaredDistance(targetVeh.pos) >= 14400 then -- check if state needs to be reset
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

      if self.flags.askInsurance then
        if self.actionTimer <= 0 then
          if self.targetVisible and self.veh.speed <= slowSpeed and targetVeh.speed <= slowSpeed and self.veh.pos:squaredDistance(targetVeh.pos) <= square(self.driver.behavioral.targetDistThreshold) then
            self:setAction('askInsurance') -- exchange insurance information
            if gameplay_traffic.showMessages and self.targetId == be:getPlayerVehicleID(0) then
              ui_message('ui.traffic.interactions.insuranceExchanged', 5, 'traffic', 'traffic')
            end
            self.targetId = nil
          else
            self.actionTimer = 5 -- bounce time
          end
        end
      elseif self.actionName == 'followPostCrash' or self.actionName == 'fleePostCrash' then
        if self.veh.speed <= slowSpeed then
          self.actionTimer = math.min(10, self.actionTimer - dtSim) -- faster timer, so that mode can switch faster
        end
        if self.veh.pos:squaredDistance(targetVeh.pos) > 1600 or self.actionTimer <= 0 then
          if self.driver.behavioral.askInsurance and self.veh.collisions[self.targetId] then -- switch to askInsurance mode
            self:setAction('pullOver', {dist = self.veh:getBrakingDistance(self.veh.speed, self.driver.aggression * 1.5), reason = 'selfCollision', useWarnSignal = true})
            self.flags.askInsurance = 1
            self.actionTimer = 5
          else
            self:resetAction()
          end
        end
      elseif self.flags.stopAndHelp then
        if self.actionTimer <= 0 then
          self:resetAction()
        end
      end
    end
  end
end

return function(...) return require('/lua/ge/extensions/gameplay/traffic/baseRole')(C, ...) end