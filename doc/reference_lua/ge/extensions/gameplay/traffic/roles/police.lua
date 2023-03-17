-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

function C:init()
  self.class = 'emergency'
  self.keepActionOnRefresh = true
  self.personalityModifiers = {
    aggression = {offset = 0.2},
    lawfulness = {offset = 0.5}
  }
  self.veh.drivability = clamp(0.5, self.veh.vars.baseDrivability, 1)
  self.cooldownTimer = -1
  self.validTargets = {}
  self.actions = {
    pursuitStart = function (args)
      local firstMode = 'chase'
      local modeNum = 0
      local obj = be:getObjectByID(self.veh.id)

      if self.veh.isAi then
        obj:queueLuaCommand('ai.setSpeedMode("off")')
        obj:queueLuaCommand('electrics.set_lightbar_signal(2)')

        if args.targetId then
          local targetVeh = gameplay_traffic.getTrafficData()[args.targetId]
          if targetVeh then
            modeNum = targetVeh.pursuit.mode
            firstMode = modeNum <= 1 and 'follow' or 'chase'
            if self.veh.driveVec:dot(targetVeh.pos - self.veh.pos) < 0 then
              firstMode = 'random'
            end
          end
        end

        obj:queueLuaCommand('ai.setMode("'..firstMode..'")')
        obj:queueLuaCommand('ai.driveInLane("'..(modeNum <= 1 and 'on' or 'off')..'")')

        if firstMode == 'random' then
          obj:queueLuaCommand('ai.setSpeedMode("limit")')
          obj:queueLuaCommand('ai.setSpeed(9)')
          obj:queueLuaCommand('ai.setAggressionMode("off")')
          obj:queueLuaCommand('ai.setAggression('..self.veh.vars.baseAggression..')')
        end
      end

      self.targetPursuitMode = modeNum
      self.state = firstMode
      self.flags.roadblock = nil
      self.flags.busy = 1
      self.cooldownTimer = -1

      if not self.flags.pursuit then
        self.veh:modifyRespawnValues(600, 50, -0.6)
        self.flags.pursuit = 1
      end
    end,
    pursuitEnd = function ()
      if self.veh.isAi then
        be:getObjectByID(self.veh.id):queueLuaCommand('ai.setMode("stop")')
        be:getObjectByID(self.veh.id):queueLuaCommand('electrics.set_lightbar_signal(1)')
        be:getObjectByID(self.veh.id):queueLuaCommand('ai.setAggression('..self.driver.aggression..')')
      end
      self.flags.pursuit = nil
      self.flags.reset = 1
      self.flags.cooldown = 1
      self.cooldownTimer = 10
      self.state = 'stop'

      self.targetPursuitMode = 0
    end,
    crashed = function ()
      if self.veh.isAi then
        be:getObjectByID(self.veh.id):queueLuaCommand('ai.setMode("stop")')
        be:getObjectByID(self.veh.id):queueLuaCommand('electrics.set_lightbar_signal(0)')
      end
      self.state = 'disabled'
    end,
    roadblock = function ()
      if self.veh.isAi then
        be:getObjectByID(self.veh.id):queueLuaCommand('ai.setMode("stop")')
        be:getObjectByID(self.veh.id):queueLuaCommand('electrics.set_lightbar_signal(2)')
      end
      self.flags.roadblock = 1
      self.state = 'stop'
      self.veh:modifyRespawnValues(300)
    end
  }

  for k, v in pairs(self.baseActions) do
    self.actions[k] = v
  end
  self.baseActions = nil

  self.targetPursuitMode = 0
end

function C:checkTarget()
  local traffic = gameplay_traffic.getTrafficData()
  local targetId
  local bestScore = 0

  for id, veh in pairs(traffic) do
    if id ~= self.veh.id and veh.role.name ~= 'police' then
      if veh.pursuit.mode >= 1 and veh.pursuit.score > bestScore then
        bestScore = veh.pursuit.score
        targetId = id
      end
    end
  end

  return targetId
end

function C:onRefresh()
  if self.flags.reset then
    self:resetAction()
  end

  local targetId = self:checkTarget()
  if targetId then
    self:setTarget(targetId)
    local targetVeh = gameplay_traffic.getTrafficData()[targetId]
    if not targetVeh.pursuit.roadblockPos or (targetVeh.pursuit.roadblockPos and be:getObjectByID(self.veh.id):getPosition():squaredDistance(targetVeh.pursuit.roadblockPos) > 400) then
      -- ignores this if vehicle is at a roadblock
      self:setAction('pursuitStart', {targetId = targetId})
    end
    self.veh:modifyRespawnValues(750 - self.targetPursuitMode * 150, 50, -0.6)
  else
    if self.flags.pursuit then
      self:resetAction()
    end
  end

  if self.flags.pursuit then
    self.veh.respawn.spawnRandomization = 0.25
  end
end

function C:onTrafficTick(dt)
  for id, veh in pairs(gameplay_traffic.getTrafficData()) do -- update data of potential targets
    if id ~= self.veh.id and veh.role.name ~= 'police' then
      if not self.validTargets[id] then self.validTargets[id] = {} end
      local interDist = self.veh:getInteractiveDistance(veh.pos, true)

      self.validTargets[id].dist = self.veh.pos:squaredDistance(veh.pos)
      self.validTargets[id].interDist = interDist
      self.validTargets[id].visible = interDist <= 10000 and self:checkTargetVisible(id) -- between 150 m ahead and 50 m behind target
    else
      self.validTargets[id] = nil
    end
  end

  if self.veh.isAi and self.flags.pursuit then
    if self.state ~= 'disabled' and self.veh.state == 'active' and self.veh.damage > self.veh.damageLimits[3] then
      self:setAction('crashed')
      local targetVeh = self.targetId and gameplay_traffic.getTrafficData()[self.targetId]
      if targetVeh and self.veh.pos:squaredDistance(targetVeh.pos) <= 400 then
        targetVeh.pursuit.policeWrecks = targetVeh.pursuit.policeWrecks + 1
      end
    end
  end

  if self.cooldownTimer <= 0 then
    if self.cooldownTimer ~= -1 then
      self.cooldownTimer = -1
      self.flags.reset = nil
      self.flags.busy = nil
      self.flags.cooldown = nil
    end
  else
    self.cooldownTimer = self.cooldownTimer - dt
  end
end

function C:onUpdate(dt, dtSim)
  if not self.flags.pursuit or self.state == 'none' then return end
  local targetVeh = self.targetId and gameplay_traffic.getTrafficData()[self.targetId]
  if not targetVeh or (targetVeh and not targetVeh.role.flags.flee) then
    self:resetAction()
    return
  end

  if self.veh.isAi then
    if self.state == 'disabled' then return end

    local obj = be:getObjectByID(self.veh.id)
    local distSq = self.veh.pos:squaredDistance(targetVeh.pos)

    if self.flags.pursuit and self.state ~= 'none' and self.state ~= 'disabled' and self.veh.vars.aiMode == 'traffic' then
      local minSpeed = (4 - targetVeh.pursuit.mode) * 4
      if self.flags.roadblock == 1 then minSpeed = 0 end
      local mode = targetVeh.pursuit.mode <= 1 and 'follow' or 'chase'

      if self.state == 'random' then -- in this mode, the vehicle is driving ahead of the suspect and will try to block
        local matchSpeedDist = square(math.max(40, targetVeh.speed * 2))
        if distSq <= matchSpeedDist and not self.flags.matchSpeed then
          obj:queueLuaCommand('ai.setSpeed('..targetVeh.speed..')') -- try to match target speed
          self.flags.matchSpeed = 1
        elseif distSq > matchSpeedDist and self.flags.matchSpeed then
          obj:queueLuaCommand('ai.setSpeed(9)')
          self.flags.matchSpeed = nil
        end

        if distSq <= 400 then
          -- consider adding this kind of blocking logic directly to the AI Chase mode
          local sideDist = self.veh.driveVec:cross(obj:getDirectionVectorUp()):dot(targetVeh.pos - self.veh.pos)
          self.veh.queuedFuncs.laneChange = {timer = 0.25, vLua = 'ai.laneChange(nil, '..self.veh:getBrakingDistance(self.veh.speed, 1)..', '..sideDist..')'}
          self.flags.matchSpeed = nil
          self.state = 'alert'
        end
      end

      if (self.state == 'alert' and targetVeh.driveVec:dot(targetVeh.pos - self.veh.pos) > 0)
      or (self.state == 'alert' and (distSq > 400 or self.veh.speed < 3))
      or (self.flags.roadblock and targetVeh.vel:dot((targetVeh.pos - targetVeh.pursuit.roadblockPos):normalized()) >= 9)
      or targetVeh.pursuit.timers.evadeValue >= 0.5 then
        obj:queueLuaCommand('ai.setSpeedMode("off")')
        obj:queueLuaCommand('ai.setMode("'..mode..'")')
        obj:queueLuaCommand('ai.setAggressionMode("rubberBand")')
        obj:queueLuaCommand('ai.setAggression(1)')
        self.state = 'chase'
        self.flags.roadblock = nil
      end

      if targetVeh.speed <= minSpeed and self.validTargets[self.targetId or 0] and self.validTargets[self.targetId].visible and distSq <= square(self.veh:getBrakingDistance(self.veh.speed, 1) + 20) then
        -- pull over near target vehicle
        if self.state == 'chase' and targetVeh.driveVec:dot(targetVeh.pos - self.veh.pos) > 0 then
          self:setAction('pullOver')
        end
      else
        if self.state == 'pullOver' then
          obj:queueLuaCommand('ai.setMode("'..mode..'")')
          self.state = 'chase'
        end
      end
    end
  end
end

return function(...) return require('/lua/ge/extensions/gameplay/traffic/baseRole')(C, ...) end