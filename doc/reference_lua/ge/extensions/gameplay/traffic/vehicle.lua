-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local min = math.min
local max = math.max
local abs = math.abs
local random = math.random
local huge = math.huge

local C = {}

local logTag = 'traffic'
local daylightValues = {0.22, 0.78} -- sunset & sunrise
local damageLimits = {25, 1000, 30000}
local baseSightDirValue = 200
local baseSightStrength = 500
local lowSpeed = 2.5
local tickTime = 0.25

-- const vectors --
local vecUp = vec3(0, 0, 1)

function C:init(id, role)
  id = id or 0
  local obj = be:getObjectByID(id)
  if not obj then
    log('E', logTag, 'Unable to add vehicle object with id ['..id..'] to traffic!')
    return
  end

  local modelData = core_vehicles.getModel(obj.jbeam).model
  local modelType = modelData and string.lower(modelData.Type) or 'none'
  if not modelData or (modelType ~= 'car' and modelType ~= 'truck' and modelType ~= 'automation' and modelType ~= 'traffic') or obj.ignoreTraffic then
    log('W', logTag, 'Invalid vehicle type for traffic, now ignoring id ['..id..']')
    return
  end

  self.vars = gameplay_traffic.getTrafficVars()
  self.policeVars = gameplay_police.getPoliceVars()
  self.damageLimits = damageLimits
  self.collisions = {}
  self.zones = {}
  self.playerData = {}

  self:applyModelConfigData()
  self:setRole(role or self.autoRole)
  self:resetAll()

  self.id = id
  self.state = 'new'
  self.enableRespawn = true
  self.enableTracking = true
  self.enableAutoPooling = true
  self.camVisible = true
  self.headlights = false
  self.isAi = false
  self.isPlayerControlled = obj:isPlayerControlled()

  self.debugLine = true
  self.debugText = true

  self.pos, self.focusPos, self.dirVec, self.vel, self.driveVec = vec3(), vec3(), vec3(), vec3(), vec3()
  self.dist = 0
  self.distCam = 0
  self.damage = 0
  self.prevDamage = 0
  self.crashDamage = 0
  self.speed = 0
  self.alpha = 1
  self.respawnCount = 0
  self.tickTimer = 0
  self.sleepTimer = 0

  self:setPlayerData()
end

function C:applyModelConfigData() -- sets data that depends on the vehicle model & config, and returns the generated vehicle role
  local role = 'standard'
  local obj = be:getObjectByID(self.id)
  local modelData = core_vehicles.getModel(obj.jbeam).model
  local _, configKey = path.splitWithoutExt(obj.partConfig)
  local configData = core_vehicles.getModel(obj.jbeam).configs[configKey]

  local modelName = obj.jbeam
  local vehType = modelData.Type
  local configType = configData and configData['Config Type']
  local paintMode = 0
  local width = obj.initialNodePosBB:getExtents().x
  local length = obj.initialNodePosBB:getExtents().y

  if modelData.Name then
    modelName = modelData.Brand and modelData.Brand..' '..modelData.Name or modelData.Name
  end

  if modelData.paints and next(modelData.paints) and (not configType or configType == 'Factory' or vehType == 'Traffic') then
    paintMode = 1
  end

  local drivability = 0.25
  local offRoadScore = configData and configData['Off-Road Score']
  if offRoadScore then
    drivability = clamp(10 / max(1e-12, offRoadScore - 4 * max(0, width - 2) - 4 * max(0, length - 5)), 0, 1) -- minimum drivability
    -- large vehicles lower this value even more
  end

  local configTypeLower = string.lower(configType or '')
  if configTypeLower == 'police' or string.find(configKey, 'police') then
    role = 'police'
  elseif configTypeLower == 'service' then -- TODO: check vehicle tags
    role = 'service'
  end

  self.autoRole = role
  self.model = {
    key = obj.jbeam,
    name = modelName,
    tags = configData and configData.Tags or {},
    paintMode = paintMode, -- paint action after respawning (0 = none, 1 = common, 2 = any)
    paintPaired = tostring(obj.color) == tostring(obj.colorPalette0) -- matching dual paint style (i.e. roamer)
  }
  self.width = width
  self.length = length
  self.drivability = drivability
end

function C:resetPursuit()
  self.pursuit = {mode = 0, score = 0, addScore = 0, hitCount = 0, offensesCount = 0, uniqueOffensesCount = 0, sightValue = 0,
  offenses = {}, offensesList = {}, roadblocks = 0, policeWrecks = 0, timers = {main = 0, arrest = 0, evade = 0, roadblock = 0, arrestValue = 0, evadeValue = 0}}
end

function C:resetTracking()
  self.tracking = {isOnRoad = true, side = 1, lastSide = 1, driveScore = 1, intersectionScore = 1, directionScore = 1, speedScore = 1, speedLimit = 20, collisions = 0, delay = -1}
end

function C:resetValues()
  self.respawn = {
    sightDirValue = baseSightDirValue, -- smoothed sight direction value, from -200 (behind you) to 200 (ahead of you)
    sightStrength = max(baseSightStrength, 200 + be:getObjectByID(self.id):getPosition():distance(getCameraPosition())), -- camera distance comparator
    spawnDirBias = self.vars.spawnDirBias, -- probability of direction of next respawn, from -1 (towards you) to 1 (away from you)
    spawnRandomization = 1, -- spawn point search randomization (from 0 to 1; 0 = straight ahead, 1 = branching and scattering)
    spawnValue = self.vars.spawnValue, -- respawnability coefficient, from 0 (slow) to 3 (rapid); exactly 0 disables respawning
    spawnCoef = self.tempSpawnCoef or 1, -- coefficient for value in previous line
    finalSpawnValue = 1, -- calculated spawn value
    extraRadius = 0, -- additional radius to keep the vehicle from respawning
    finalRadius = 80, -- calculated radius to compare with player vehicle position and camera position
    readyValue = 0 -- readiness for respawn (from 0 to 1)
  }
  self.queuedFuncs = {} -- keys: timer, func, args, vLua (vLua string overrides func and args)
  self.headlights = false
  self.tempSpawnCoef = nil
end

function C:resetElectrics()
  local obj = be:getObjectByID(self.id)
  obj:queueLuaCommand('electrics.set_lightbar_signal(0)')
  obj:queueLuaCommand('electrics.set_warn_signal(0)')
  obj:queueLuaCommand('electrics.horn(false)')
end

function C:resetAll() -- resets everything
  table.clear(self.collisions)
  self:resetPursuit()
  self:resetTracking()
  self:resetValues()
end

function C:honkHorn(duration) -- set horn with duration
  be:getObjectByID(self.id):queueLuaCommand('electrics.horn(true)')
  self.queuedFuncs.horn = {timer = duration or 1, vLua = 'electrics.horn(false)'}
end

function C:setAiMode(mode) -- sets the AI mode
  mode = mode or self.vars.aiMode

  local obj = be:getObjectByID(self.id)
  obj:queueLuaCommand('ai.setMode("'..mode..'")')
  obj:queueLuaCommand('ai.reset()')
  if mode == 'traffic' then
    obj:queueLuaCommand('ai.setAggression('..self.vars.baseAggression..')')
    obj:queueLuaCommand('ai.setSpeedMode("legal")')
    obj:queueLuaCommand('ai.driveInLane("on")')
  end

  self.isAi = mode ~= 'disabled'
end

function C:setAiAware(mode) -- sets the AI awareness
  mode = mode or self.vars.aiAware

  be:getObjectByID(self.id):queueLuaCommand('ai.setAvoidCars("'..mode..'")')
  be:getObjectByID(self.id):queueLuaCommand('ai.reset()') -- this is called to reset the AI plan
end

function C:setRole(roleName) -- sets the driver role
  roleName = roleName or 'standard'
  local prevName
  local roleClass = gameplay_traffic.getRoleConstructor(roleName)
  if roleClass then
    if self.role then -- only if there is a previous role
      prevName = self.role.name
      self.role:onRoleEnded()
    end

    self.role = roleClass({veh = self, name = roleName})
    self.role:onRoleStarted()
    extensions.hook('onTrafficAction', self.id, {targetId = self.role.targetId or 0, name = 'role'..string.sentenceCase(roleName), prevName = prevName and 'role'..string.sentenceCase(prevName), data = {}})
  end
end

function C:getInteractiveDistance(pos, squared) -- returns the distance of the "look ahead" point from this vehicle
  if pos then
    return squared and (self.focusPos):squaredDistance(pos) or (self.focusPos):distance(pos)
  else
    return huge
  end
end

function C:modifyRespawnValues(addSightStrength, addExtraRadius, addSpawnDirBias) -- instantly modifies respawn values (can be used to keep a vehicle active for longer)
  self.respawn.sightStrength = self.respawn.sightStrength + (addSightStrength or 0)
  self.respawn.extraRadius = self.respawn.extraRadius + (addExtraRadius or 0)
  self.respawn.spawnDirBias = clamp(self.respawn.spawnDirBias + (addSpawnDirBias or 0), -1, 1)
end

function C:getBrakingDistance(speed, accel) -- gets estimated braking distance
  -- prevents division by zero gravity
  local gravity = core_environment.getGravity()
  gravity = max(0.1, abs(gravity)) * sign2(gravity)

  return square(speed or self.speed) / (2 * (accel or self.role.driver.aggression) * abs(gravity))
end

function C:checkCollisions() -- checks for contact with other tracked vehicles
  local traffic = gameplay_traffic.getTrafficData()

  for id, veh in pairs(traffic) do
    if self.id ~= id then
      local isCurrentCollision = map.objects[id] and map.objects[id].objectCollisions[self.id] == 1

      if not self.collisions[id] and isCurrentCollision then -- init collision table
        self.collisions[id] = {state = 'active', inArea = false, nearestDist = min(self.length + veh.length, self.pos:distance(veh.pos)), speed = self.speed, damage = 0, dot = 0, count = 0, stop = 0}
      end

      local collision = self.collisions[id]
      if collision then -- update existing collision table
        local dist = self.pos:squaredDistance(veh.pos)
        if isCurrentCollision then collision.damage = max(collision.damage, self.damage - self.prevDamage) end -- update damage value while in contact

        if collision.inArea and dist > square(collision.nearestDist + 1) then
          collision.inArea = false
        elseif not collision.inArea and isCurrentCollision and (collision.count == 0 or dist <= square(collision.nearestDist + 1)) then
          collision.inArea = true
          collision.count = collision.count + 1
          collision.dot = self.driveVec:dot((veh.pos - self.pos):normalized())
          if self.enableTracking then self.tracking.collisions = self.tracking.collisions + 1 end
          self.role:onCollision(id, collision)

          for otherId, otherVeh in pairs(traffic) do -- notify other traffic vehicles of collision
            if not otherVeh.otherCollisionFlag and otherId ~= self.id and otherId ~= id then
              otherVeh.role:onOtherCollision(self.id, id, collision)
              otherVeh.otherCollisionFlag = true
            end
          end
        end
      end
    else
      self.collisions[id] = nil
    end
  end
end

function C:trackCollision(otherId, dt) -- track and alter the state of the collision with other vehicle id
  otherId = otherId or 0
  local collision = self.collisions[otherId]
  local otherVeh = gameplay_traffic.getTrafficData()[otherId]
  if not collision or not otherVeh then return end

  local dist = self.pos:squaredDistance(otherVeh.pos)

  if collision.state == 'active' then
    if dist <= 2500 and self.speed <= lowSpeed then -- waiting near site of collision
      collision.stop = collision.stop + dt
      if collision.stop >= 5 then
        collision.state = 'resolved'
      end
    elseif dist > 2500 and self.speed > lowSpeed and self.driveVec:dot(self.pos - otherVeh.pos) > 0 then -- leaving site of collision
      collision.state = 'abandoned'
    end
  end
  if (collision.state == 'resolved' or collision.state == 'abandoned') and dist >= 14400 then -- clear collision data
    self.collisions[otherId] = nil
  end
end

function C:fade(rate, isFadeOut) -- fades vehicle mesh
  self.alpha = clamp(self.alpha + (rate or 0.1) * (isFadeOut and -1 or 1), 0, 1)
  be:getObjectByID(self.id):setMeshAlpha(self.alpha, '')

  if isFadeOut and self.alpha == 0 then
    self.state = 'queued'
  elseif not isFadeOut and self.alpha == 1 then
    self.state = 'active'
  end
end

function C:checkRayCast(pos) -- returns true if ray reaches position
  local targetVec = self.pos - pos
  local targetVecLen = targetVec:length()
  return castRayStatic(pos, targetVec:normalized(), targetVecLen) >= targetVecLen
end

function C:tryRespawn(queueCoef) -- tests if the vehicle is out of sight and ready to respawn
  if not self.enableRespawn or self.respawn.finalSpawnValue <= 0 then
    self.respawn.sightDirValue = baseSightDirValue
    self.respawn.sightStrength = baseSightStrength
    return
  end

  if be:getObjectByID(self.id):getActive() then
    queueCoef = queueCoef or 1 -- used as a coefficient if method is called on a cycle (not every frame)
    local radius = clamp(self.respawn.finalRadius, 40, 200) -- base radius for active area
    local dotDirVecFromCam = self.playerData.camDirVec:dot((self.pos - self.playerData.camPos):normalized()) -- directionality from camera
    local heightValue = max(0, square(self.playerData.camPos.z - self.pos.z) / 8 * dotDirVecFromCam) -- camera height augments final distance if generally looking at vehicle

    local sightCoef = -1 -- negative value reduces sight value until vehicle might respawn
    if self.camVisible then
      sightCoef = self.respawn.sightStrength <= 0 and 1 or 0
    end

    self.respawn.sightDirValue = lerp(self.respawn.sightDirValue, dotDirVecFromCam * 200, 0.01 * queueCoef) -- sight direction smoothing
    self.respawn.sightStrength = max(-radius, self.respawn.sightStrength + sightCoef * queueCoef) -- updated sight strength value
    local camRadius = radius + max(0, self.respawn.sightDirValue + self.respawn.sightStrength + heightValue) -- maximum radius to check if the vehicle should stay active
    self.respawn.readyValue = min(min(1, self.dist / radius), self.distCam / camRadius)

    -- player radius, camera sight virtual radius
    if self.dist >= radius and self.distCam >= camRadius then
      self.state = 'fadeOut'
    end
  else
    self.state = 'queued'
  end
end

function C:trackDriving(dt, fullTracking) -- basic tracking for how a vehicle drives on the road
  -- full tracking is heavier but tracks more driving data on the road
  -- this kind of functionality could be used in its own module
  local mapNodes = map.getMap().nodes
  local mapRules = map.getRoadRules()

  local n1, n2 = map.findClosestRoad(self.pos)
  local legalSide = mapRules.rightHandDrive and -1 or 1
  if n1 and mapNodes[n1] then
    local link = mapNodes[n1].links[n2] or mapNodes[n2].links[n1]
    self.tracking.speedLimit = max(5.556, link.speedLimit)
    local overSpeedValue = clamp(self.speed / self.tracking.speedLimit, 1, 3) * dt * 0.1

    if self.speed >= self.tracking.speedLimit * 1.2 then
      self.tracking.speedScore = max(0, self.tracking.speedScore - overSpeedValue)
    else
      self.tracking.speedScore = min(1, self.tracking.speedScore + overSpeedValue)
    end

    if fullTracking then
      if (link.oneWay and link.inNode == n2) or (not link.oneWay and (mapNodes[n2].pos - mapNodes[n1].pos):dot(self.driveVec) < 0) then
        n1, n2 = n2, n1
      end

      local p1, p2 = mapNodes[n1].pos, mapNodes[n2].pos
      local dir = (p2 - p1):z0():normalized()
      local xnorm = clamp(self.pos:xnormOnLine(p1, p2), 0, 1)
      local roadPos = linePointFromXnorm(p1, p2, xnorm)
      local radius = lerp(mapNodes[n1].radius, mapNodes[n2].radius, xnorm)
      local dot = self.driveVec:dot(dir)
      local reboundValue = dt * 0.025
      self.tracking.isOnRoad = self.pos:squaredDistance(roadPos) <= square(radius + 1)

      if self.speed > lowSpeed and self.tracking.isOnRoad and abs(dot) > 0.3 then -- player is driving parallel on the road
        if not link.oneWay then
          self.tracking.side = self.driveVec:z0():cross(vecUp):dot((self.pos - roadPos):z0()) * legalSide >= 0 and 1 or -1 -- legal or illegal side
        else
          self.tracking.side = dot >= 0.8 and 1 or -2 -- legal or illegal direction
        end
      else
        self.tracking.side = 1
      end

      if self.tracking.side < 0 then
        self.tracking.directionScore = max(0, self.tracking.directionScore + self.tracking.side * dt * 0.075) -- increments twice as fast if wrong way on oneWay
      else
        self.tracking.directionScore = min(1, self.tracking.directionScore + reboundValue)
      end

      -- reduces score if player is driving recklessly (rapidly crossing lanes, doing donuts, etc.)
      if self.tracking.side ~= self.tracking.lastSide then
        self.tracking.driveScore = max(0, self.tracking.driveScore - 0.05) -- decreases per instance of side switch
      else
        self.tracking.driveScore = min(1, self.tracking.driveScore + reboundValue * 0.5)
      end

      if core_trafficSignals then
        local signalsDict = core_trafficSignals.getSignalsDict()
        if not self.tracking.intersection and signalsDict and signalsDict.nodes[n2] then
          for _, v in ipairs(signalsDict.nodes[n2]) do
            local nPos = p1:squaredDistance(v.pos) > square(self.speed * 0.25) and v.pos or p2 -- ensure that intersection node doesn't get skipped due to tick
            if (self.pos - nPos):normalized():dot(v.dir) < 0 and self.driveVec:dot(v.dir) >= 0.7 then
              self.tracking.intersection = v
              break
            end
          end
        end

        local sData = self.tracking.intersection
        if sData then
          local aheadPos = sData.pos + sData.dir * 5
          if (self.pos - aheadPos):dot(sData.dir) >= 0 then
            if sData.action == 0.5 then
              self.tracking.intersectionFlag = true -- yellow light, ignore check
            end
            if not self.tracking.intersectionFlag and sData.action == 0 and self.speed >= lowSpeed then
              self.tracking.intersectionScore = max(0, self.tracking.intersectionScore - self.speed * max(0.25, self.driveVec:dot(sData.dir)) * dt * 0.05)
            end
          end

          if (mapRules.turnOnRed and sData.dir:cross(vecUp):normalized():dot(self.driveVec) >= 0.5 * legalSide) or self.pos:squaredDistance(aheadPos) >= 900 then
            self.tracking.intersection = nil
          end

          if not self.tracking.intersection then
            self.tracking.intersectionScore = 1
          end
        end
      end
    else
      self.tracking.driveScore, self.tracking.directionScore, self.tracking.intersectionScore = 1, 1, 1
    end
  end
  self.tracking.lastSide = self.tracking.side

  if self.tracking.delay < 0 then
    self.tracking.delay = min(0, self.tracking.delay + dt)
  end
end

function C:triggerOffense(data) -- triggers a pursuit offense
  if not data or not data.key then return end
  data.score = data.score or 100
  if self.isAi then data.score = data.score * 0.5 end -- half score if the vehicle is AI controlled
  local key = data.key
  data.key = nil

  if not self.pursuit.offenses[key] then
    self.pursuit.offenses[key] = data
    table.insert(self.pursuit.offensesList, key)
    self.pursuit.uniqueOffensesCount = self.pursuit.uniqueOffensesCount + 1

    local tempData = deepcopy(data)
    tempData.key = key
    extensions.hook('onPursuitOffense', self.id, tempData)
  end
  self.pursuit.offensesCount = self.pursuit.offensesCount + 1
  self.pursuit.offenseFlag = true
  self.pursuit.addScore = self.pursuit.addScore + data.score
end

function C:checkOffenses() -- tests for vechicle offenses for police
  -- Offenses: speeding, racing, hitPolice, hitTraffic, reckless, wrongWay, intersection
  if self.policeVars.strictness <= 0 then return end
  local pursuit = self.pursuit
  local minScore = clamp(self.policeVars.strictness, 0, 0.8) -- offense threshold

  if self.tracking.speedScore <= minScore then
    if self.speed >= self.tracking.speedLimit * 1.2 and not pursuit.offenses.speeding then
      self:triggerOffense({key = 'speeding', value = self.speed, maxLimit = self.tracking.speedLimit, score = 100})
    end
    if self.speed >= self.tracking.speedLimit * 2 and not pursuit.offenses.racing then
      self:triggerOffense({key = 'racing', value = self.speed, maxLimit = self.tracking.speedLimit, score = 200})
    end
  end
  if self.tracking.driveScore <= minScore and not pursuit.offenses.reckless then
    self:triggerOffense({key = 'reckless', value = self.tracking.driveScore, minLimit = minScore, score = 200})
  end
  if self.tracking.intersectionScore <= minScore and not pursuit.offenses.intersection then
    self:triggerOffense({key = 'intersection', value = self.tracking.intersectionScore, minLimit = minScore, score = 200})
  end
  if self.tracking.directionScore <= minScore and not pursuit.offenses.wrongWay then
    self:triggerOffense({key = 'wrongWay', value = self.tracking.directionScore, minLimit = minScore, score = 150})
  end

  for id, coll in pairs(self.collisions) do
    if not coll.offense and coll.dot >= 0.2 then -- simple comparison to check if current vehicle is at fault for collision
      local veh = gameplay_traffic.getTrafficData()[id]

      if veh.role.name == 'police' and coll.inArea then -- always triggers if police was hit
        local score = veh.isPlayerControlled and 80 or 200
        self:triggerOffense({key = 'hitPolice', value = id, score = score})
        pursuit.hitCount = pursuit.hitCount + 1
        coll.offense = true
      elseif pursuit.mode > 0 or coll.state == 'abandoned' then -- fleeing in a pursuit, or abandoning an accident
        self:triggerOffense({key = 'hitTraffic', value = id, score = 100})
        pursuit.hitCount = pursuit.hitCount + 1
        coll.offense = true
      end
    end
  end
end

function C:pullOver()
  self.tracking.pullOver = 1
end

function C:checkTimeOfDay() -- turns headlights on at night
  local timeObj = core_environment.getTimeOfDay()
  local isDaytime = true
  if timeObj and timeObj.time then
    isDaytime = (timeObj.time <= daylightValues[1] or timeObj.time >= daylightValues[2])
    if isDaytime and self.headlights then
      be:getObjectByID(self.id):queueLuaCommand('electrics.setLightsState(0)')
      self.headlights = false
    elseif not isDaytime and not self.headlights then
      if self.state == 'active' then
        self.queuedFuncs.headlights = {timer = random(10), vLua = 'electrics.setLightsState(1)'}
      else
        be:getObjectByID(self.id):queueLuaCommand('electrics.setLightsState(1)')
      end
      self.headlights = true
    end
  end

  return isDaytime
end

function C:checkZones() -- tests vehicle position in zones
  if not gameplay_city then return end
  local sites = gameplay_city.getSites()
  if not sites or not sites.tagsToZones.traffic then return end

  -- tunnels
  -- perhaps this should be a road property instead; it would be easier and lighter
  if sites.tagsToZones.tunnel then
    for _, zone in ipairs(sites.tagsToZones.tunnel) do
      if not self.zones[zone.name] and zone:containsPoint2D(self.pos) then -- zone not stored, and zone contains vehicle position
        self.zones[zone.name] = 1 -- only need to store the zone name as a key
        be:getObjectByID(self.id):queueLuaCommand('electrics.setLightsState(1)')
      elseif self.zones[zone.name] and not zone:containsPoint2D(self.pos) then -- zone stored, and zone no longer contains vehicle position
        self.zones[zone.name] = nil
        be:getObjectByID(self.id):queueLuaCommand('electrics.setLightsState(0)')
      end
    end
  end
end

function C:setPlayerData() -- automatically sets player and camera data
  if not self.playerData.pos then
    self.playerData.pos, self.playerData.camPos, self.playerData.camDirVec = vec3(), vec3(), vec3()
  end

  self.playerData.camPos:set(getCameraPosition())
  self.playerData.camDirVec:set(getCameraForward())
  if be:getPlayerVehicle(0) then
    self.playerData.pos:set(be:getPlayerVehicle(0):getPosition())
  else
    self.playerData.pos = self.playerData.camPos
  end
end

function C:onVehicleResetted() -- triggers whenever vehicle resets (automatically or manually)
  if self.role.flags.freeze then
    be:getObjectByID(self.id):queueLuaCommand('controller.setFreeze(0)')
    self.role.flags.freeze = false
  end
  self:resetTracking()
end

function C:onRespawn() -- triggers after vehicle respawns in traffic
  if self.model.paintMode and self.model.paintMode >= 1 then
    local paint
    if self.model.definedPaints then
      paint = self.model.definedPaints[random(#self.model.definedPaints)]
    else
      paint = gameplay_traffic.getRandomPaint(self.id, self.model.paintMode == 1 and 0.75 or 0)
    end
    core_vehicle_manager.setVehiclePaintsNames(self.id, {paint, self.model.paintPaired and paint})
  end

  self.respawnCount = self.respawnCount + 1
  self.state = 'reset'
end

function C:onRefresh() -- triggers whenever vehicle data needs to be refreshed
  if self.isAi then
    local obj = be:getObjectByID(self.id)
    local marker = core_settings_settings.getValue('trafficMinimap')
    obj.uiState = marker and 1 or 0

    self.vars = gameplay_traffic.getTrafficVars()
    self.policeVars = gameplay_police.getPoliceVars()
    self:resetAll()

    if self.vars.aiDebug == 'traffic' then
      obj:queueLuaCommand('ai.setVehicleDebugMode({debugMode = "off"})')
    else
      obj:queueLuaCommand('ai.setVehicleDebugMode({debugMode = "'..self.vars.aiDebug..'"})')
    end

    local isDaytime = self:checkTimeOfDay()

    if not isDaytime then
      self.respawn.spawnCoef = self.respawn.spawnCoef * 0.5
    end
    self.state = self.alpha == 1 and 'active' or 'fadeIn'

    if self.vars.aiMode ~= 'traffic' then -- disable traffic actions if AI mode is set to other than traffic
      self.role:resetAction()
      return
    end

    if self.tempRole then -- temp role gets cleared after vehicle gets refreshed
      self:setRole(self.autoRole)
      self.tempRole = nil
    end

    if not self.role.keepActionOnRefresh then
      self.role:resetAction()
    end
    if not self.role.keepPersonalityOnRefresh then
      self.role:applyPersonality(self.role:generatePersonality())
    end

    if self.vars.speedLimit then -- needs to be done after role stuff
      if self.vars.speedLimit >= 0 then
        obj:queueLuaCommand('ai.setSpeedMode("limit")')
        obj:queueLuaCommand('ai.setSpeed('..self.vars.speedLimit..')')
      else -- force legal speed
        obj:queueLuaCommand('ai.setSpeedMode("legal")')
      end
    end
  end

  self.tickTimer = 0
  self.forceTeleport = nil
  self.role:onRefresh()
end

function C:onTrafficTick(tickTime)
  if self.enableTracking then
    self:trackDriving(tickTime, not self.isAi)
  end
  if self.isAi then
    self:checkTimeOfDay()

    -- feature disabled
    --self.zoneTicks = self.zoneTicks + 1
    --if self.zoneTicks >= 4 then -- approx every 1 second
      --self:checkZones()
      --self.zoneTicks = 0
    --end
  end

  local tickDamage = self.damage - self.prevDamage
  self.crashDamage = max(self.crashDamage, tickDamage) -- highest tick damage experienced

  if tickDamage >= damageLimits[2] then
    self.role:onCrashDamage({speed = self.speed, damage = self.damage, tickDamage = tickDamage})

    for id, veh in pairs(gameplay_traffic.getTrafficData()) do
      if id ~= self.id then
        veh.role:onOtherCrashDamage(self.id, {speed = self.speed, damage = self.damage, tickDamage = tickDamage})
      end
    end
  end

  self.prevDamage = self.damage

  self.role:onTrafficTick(tickTime)
end

function C:onUpdate(dt, dtSim)
  local obj = be:getObjectByID(self.id)
  if not obj then return end
  self:setPlayerData()
  self.pos:set(obj:getPosition())
  self.dirVec:set(obj:getDirectionVector())
  self.vel:set(obj:getVelocity())
  self.speed = self.vel:length()

  self.distCam = self.pos:distance(self.playerData.camPos)
  self.dist = self.playerData.pos ~= self.playerData.camPos and self.pos:distance(self.playerData.pos) or self.distCam
  self.isPlayerControlled = obj:isPlayerControlled()

  if self.speed < 1 then
    self.driveVec = self.dirVec
  else
    self.driveVec:set(self.vel / (self.speed + 1e-12))
  end
  self.focusPos:set(self.pos + self.driveVec * clamp(self.speed * 2, 20, 50)) -- virtual point ahead of vehicle trajectory, dependent on speed

  if (not obj:getActive() or self.state == 'active') and not self.enableRespawn then
    self.state = 'locked'
  elseif self.state == 'locked' and self.enableRespawn then
    self.state = 'reset'
  end

  if map.objects[self.id] and obj:getActive() then
    self.damage = map.objects[self.id].damage
    if self.damage <= damageLimits[1] then
      self.crashDamage = 0
    else
      self.respawn.extraRadius = max(self.respawn.extraRadius, min(self.damage / 50, 100)) -- extra radius due to damage
    end

    self.camVisible = self:checkRayCast(self.playerData.camPos)

    self.respawn.finalSpawnValue = clamp(self.respawn.spawnValue * self.respawn.spawnCoef, 0, 3)
    self.respawn.finalRadius = self.respawn.extraRadius + 20 + 60 / (self.respawn.finalSpawnValue + 1e-12)
    if self.respawn.sightStrength > 0 then
      self.respawn.sightStrength = max(0, self.respawn.sightStrength - dtSim * self.respawn.finalSpawnValue * 40) -- linear reduce base sight strength (reduces rapid respawning if out of range)
    end

    if not self.isPlayerControlled and self.state == 'fadeOut' or self.state == 'fadeIn' then
      if self.state == 'fadeIn' then
        --obj:queueLuaCommand('thrusters.applyVelocity(obj:getDirectionVector() * '..(self.alpha * 3.333)..')') -- thrust vehicle to about 12 km/h after respawning
        -- temporarily disabled
      end
      self:fade(dtSim * 5, self.state == 'fadeOut')
    end

    if self.vars.aiMode ~= 'traffic' then return end -- if main AI mode is not traffic, ignore everything below meant for traffic

    if self.enableTracking and self.tracking.delay == 0 then
      self:checkCollisions()

      for id, _ in pairs(self.collisions) do
        self:trackCollision(id, dtSim)
      end

      if self.role.name ~= 'police' and self.pursuit.policeVisible and not self.pursuit.cooldown then
        self:checkOffenses()
      end
    end

    self.tickTimer = self.tickTimer + dtSim
    if self.tickTimer >= tickTime then
      self:onTrafficTick(tickTime)
      self.tickTimer = self.tickTimer - tickTime
    end

    -- queued functions
    for k, v in pairs(self.queuedFuncs) do
      if not v.timer then v.timer = 0 end
      v.timer = v.timer - dtSim
      if v.timer <= 0 then
        if not v.vLua then
          v.func(unpack(v.args))
        else
          obj:queueLuaCommand(v.vLua)
        end
        self.queuedFuncs[k] = nil
      end
    end

    self.role:onUpdate(dt, dtSim)
  else
    self.camVisible = false
  end

  if self.sleepTimer > 0 then
    self.sleepTimer = math.max(0, self.sleepTimer - dtSim)
  end
end

function C:onSerialize()
  local data = {
    id = self.id,
    isAi = self.isAi,
    respawnCount = self.respawnCount,
    enableRespawn = self.enableRespawn,
    enableTracking = self.enableTracking,
    enableAutoPooling = self.enableAutoPooling,
    role = self.role:onSerialize()
  }

  return data
end

function C:onDeserialized(data)
  self.id = data.id
  self.isAi = data.isAi
  self.respawnCount = data.respawnCount
  self.enableRespawn = data.enableRespawn
  self.enableTracking = data.enableTracking
  self.enableAutoPooling = data.enableAutoPooling

  self:applyModelConfigData()
  self:setRole(data.role.name)
  self:onRefresh()
  self.role:onDeserialized(data.role)
end

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  C.__index = C
  o:init(o.id)
  return o.model and o -- returns nil if invalid object
end