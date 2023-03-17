-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {'gameplay_police', 'gameplay_parking', 'core_vehiclePoolingManager'}

local logTag = 'traffic'

local traffic, trafficAiVehsList, player = {}, {}, {}
local positionsCache, rolesCache = {}, {}
local mapNodes, mapRules
local trafficPool, trafficPoolId
local trafficVehicle = require('lua/ge/extensions/gameplay/traffic/vehicle')

-- const vectors --
local vecUp = vec3(0, 0, 1)
local vecY = vec3(0, 1, 0)

-- common functions --
local min = math.min
local max = math.max
local random = math.random

--------
local queuedVehicle = 0
local respawnTicks = 0
local minRadius = 2.25
local state = 'off'
local worldLoaded = false

local defaultCountries = {usa = 'United States', germany = 'Germany', italy = 'Italy', japan = 'Japan'} -- temporary country list
local defaultTrafficCar = {model = 'pickup'}
local defaultPoliceCar = {model = 'fullsize', config = 'police'} -- ideal police car
local spawnProcess = {}
local vars

local debugColors = {
  black = ColorF(0, 0, 0, 1),
  white = ColorF(1, 1, 1, 1),
  green = ColorF(0.2, 1, 0.2, 1),
  red = ColorF(0.5, 0, 0, 1),
  blackAlt = ColorI(0, 0, 0, 255),
  greenAlt = ColorI(0, 64, 0, 255)
}

local commonPaintsCache = {}
local commonPaints = {
  {0.83, 0.83, 0.83, 1}, -- white
  {0, 0, 0, 1}, -- black
  {0.33, 0.33, 0.33, 1}, -- grey
  {0.65, 0.65, 0.65, 1}, -- silver
  {0, 0.1, 0.42, 1}, -- blue
  {0.58, 0.12, 0.12, 1} -- red
}

M.debugMode = false -- visual and logging debug mode
M.showMessages = true -- if enabled, UI messages can be automatically shown
M.queueTeleport = false -- sets a flag to make all traffic vehicles teleport when they are ready

local function getAmountFromSettings() -- gets saved or calculated amount of vehicles
  local amount = settings.getValue('trafficAmount') -- get amount from gameplay settings
  if amount == 0 then -- use CPU-based value
    amount = getMaxVehicleAmount(10)
  end
  return amount
end

local function getIdealSpawnAmount(amount) -- gets the ideal amount of vehicles to spawn based on current world state
  if not amount or amount < 0 then
    amount = getAmountFromSettings()
  end

  local vehCount = 0
  for _, v in ipairs(getAllVehiclesByType()) do
    if v:getActive() then
      vehCount = vehCount + 1
    end
  end
  return amount - vehCount
end

local function colorDifference(c1, c2) -- returns the color difference value
  -- https://stackoverflow.com/questions/9018016/how-to-compare-two-colors-for-similarity-difference/9085524#9085524
  local avg = (c1[1] + c2[1]) * 0.5
  local r = c1[1] - c2[1]
  local g = c1[2] - c2[2]
  local b = c1[3] - c2[3]
  return math.sqrt(bit.rshift(((512 + avg) * r * r), 8) + 4 * g * g + bit.rshift(((767 - avg) * b * b), 8))
end

local function getRandomPaint(vehId, commonChance) -- gets a random paint name, with a bias for real world paints
  local obj = be:getObjectByID(vehId or 0)
  local model = obj and obj.jbeam or 'pessima' -- safe default
  local config = obj and tostring(obj.partConfig)
  local paint
  commonChance = commonChance or 0

  local modelData = core_vehicles.getModel(model).model
  if modelData and modelData.paints then
    local paintNames = tableKeys(modelData.paints)

    if random() <= commonChance then -- if true, selects a color that is typically found in the real world
      local n = math.ceil(square(random()) * 6 - 0.2) -- default paint plus six common paints
      -- default paint chance: 18%
      if commonPaints[n] then
        local bestVal = math.huge
        local bestPaint
        local c = commonPaints[n]
        local c1 = {c[1] * 255, c[2] * 255, c[3] * 255}

        for k, v in pairs(modelData.paints) do
          local bc = v.baseColor
          if bc[1] == c[1] and bc[2] == c[2] and bc[3] == c[3] then -- exact match (ends the loop early)
            paint = k
            bestPaint = nil
            break
          else
            local c2 = {bc[1] * 255, bc[2] * 255, bc[3] * 255}
            local val = colorDifference(c1, c2)
            if val < bestVal then
              bestVal = val
              bestPaint = k
            end
          end
        end

        if bestPaint then
          paint = bestPaint
        end
      else
        if config then
          local _, configKey = path.splitWithoutExt(config)
          local configData = core_vehicles.getModel(model).configs[configKey]
          paint = configData and configData.defaultPaintName1 or modelData.defaultPaintName1
        else
          paint = 'Pearl White' -- fallback
        end
      end
    else -- selects any color
      paint = paintNames[random(#paintNames)]
    end
  end
  return paint
end

local function getNumOfTraffic(activeOnly) -- returns current amount of AI traffic
  return (activeOnly and trafficPool) and #trafficPool.activeVehs or #trafficAiVehsList
end

local function getCountry() -- gets the country from the info
  local dir = path.split(getMissionFilename()) or ''
  local json = jsonReadFile(dir..'info.json')
  if json and json.country then
    local countryKey = string.match(json.country, '%w+.%w+.%w+.(%w+)') or json.country
    local countryStr = 'default'
    if countryKey and defaultCountries[countryKey] then
      countryStr = defaultCountries[countryKey]
    end
    return countryStr and string.lower(countryStr) or countryKey
  else
    return 'default'
  end
end

local function showMessage(str, time, category, icon) -- displays an informative message in the Messages app
  if not M.showMessages then return end
  ui_message(str or '', time or 5, category or 'traffic', icon or 'traffic')
end

local function setMapData() -- updates all map related data
  mapNodes = map.getMap().nodes
  mapRules = map.getRoadRules()
end

local function getPointDataOfPath(path, dist) -- returns the road data of the distant point along the path
  -- needs optimization
  if not path then return end
  dist = dist or 0
  local n1, n2, xnorm = map.getNodesFromPathDist(path, dist)

  if n1 and n2 and mapNodes[n1] and mapNodes[n2] then
    local link = mapNodes[n1].links[n2] or mapNodes[n2].links[n1]
    if link then
      local p1, p2 = mapNodes[n1].pos, mapNodes[n2].pos
      local pos = linePointFromXnorm(p1, p2, xnorm)
      local rot = (p2 - p1):normalized()
      local normal = (mapNodes[n1].normal + mapNodes[n2].normal):normalized()
      local radius = lerp(mapNodes[n1].radius, mapNodes[n2].radius, xnorm)

      return {n1 = n1, n2 = n2, pos = pos, rot = rot, normal = normal, radius = radius, link = link}
    end
  end
end

local function checkSpawnPos(pos, camRadius, plRadius, vehRadius) -- tests if the spawn point interferes with other vehicles
  vehRadius = vehRadius or 15
  camRadius = max(vehRadius, camRadius or 100)
  plRadius = max(vehRadius, plRadius or 100)

  if pos:squaredDistance(getCameraPosition()) < square(camRadius) then
    return false
  end

  for _, v in ipairs(positionsCache) do -- previous spawn point positions in the same frame
    if pos:squaredDistance(v) < square(vehRadius) then
      return false
    end
  end

  for _, v in ipairs(getAllVehicles()) do
    if v:getActive() then
      local vPos = vec3(v:getPosition())
      local relSpeed = max(0, vec3(v:getVelocity()):dot((pos - vPos):normalized()))
      local radius = v:isPlayerControlled() and plRadius or vehRadius
      if pos:squaredDistance(vPos) < square(square(relSpeed) / 20 + radius) then
        return false
      end
    end
  end

  return true
end

local function findSpawnPoint(startPos, startDir, minDist, maxDist, extraArgs) -- finds and returns a spawn point on the map
  setMapData()
  extraArgs = type(extraArgs) == 'table' and extraArgs or {}
  startDir = startDir:z0():normalized()
  minDist = minDist or 80  -- minimum distance along path to check for spawn points
  maxDist = maxDist or 240 -- maximum distance along path to check for spawn points; can get modified by camera dir and height

  local lateralDist = extraArgs.lateralDist or 0 -- lateral (side) distance from the start to use for searching for a path (such as divided highways)
  local innerDist = 0 -- current distance along valid spawn segment of spawn path (starting from the minimum distance)
  local maxLoopCount = 50
  local road
  local status = 'working'

  local pathRandomization = extraArgs.pathRandom or 1
  local width = extraArgs.width or 2
  local length = extraArgs.length or 5
  local drivability = extraArgs.drivability or 0.25

  --[[ with the above values, a path will be generated along the road ahead, and points between the minimum distance and maximum distance
  will be tested and validated before returning a new spawn point ]]--
  if M.debugMode then
    log('I', logTag, 'Spawn point params: minDist = '..minDist..', maxDist = '..maxDist..', lateralDist = '..lateralDist)
  end

  if lateralDist ~= 0 then
    startPos = startPos + startDir:cross(vecUp) * lateralDist
  end
  local n1, n2 = map.findClosestRoad(startPos)

  if n1 and mapNodes[n1] then
    local p1, p2 = mapNodes[n1].pos, mapNodes[n2].pos
    if (p2 - p1):dot(startDir) < 0 then
      n1, n2 = n2, n1
      p1, p2 = p2, p1
    end

    -- spawn point is along path in direction set by startDir, with possible branching
    local path = map.getGraphpath():getRandomPathG(n1, startDir, maxDist + 50, pathRandomization, 1, false)
    local pathDist = map.getPathLen(path)
    local xnorm = clamp(startPos:xnormOnLine(p1, p2), 0, 1)
    local offset = linePointFromXnorm(p1, p2, xnorm):distance(p1)
    local randomValue = square(random()) -- to test with drivability
    local loopCount = 1

    while status == 'working' do
      if loopCount > maxLoopCount then
        status = 'loopLimit'
        break
      end
      if minDist + innerDist >= pathDist then -- extend pathDist
        local pathLen = #path
        local pathNode1, pathNode2 = path[pathLen], path[pathLen - 1]
        local tempDir = (mapNodes[pathNode1].pos - mapNodes[pathNode2].pos):normalized()
        local newPath = map.getGraphpath():getRandomPathG(pathNode1, tempDir, 100, pathRandomization, 1, false)
        local tempDist = map.getPathLen(newPath)
        table.remove(newPath, 1)
        pathDist = pathDist + tempDist
        path = arrayConcat(path, newPath)
      end

      road = getPointDataOfPath(path, offset + minDist + innerDist)
      if road then
        -- spawn check fails if road is not suitable enough
        local linkDrivability = road.link.drivability
        local linkCoef = road.link.oneWay and 0.5 or clamp(road.radius / minRadius, 0.5, 1) -- width coefficient

        if road.link.type == 'private' then -- traffic will never spawn on private roads
          status = 'roadTypeFail'
          break
        end

        if not extraArgs.ignoreRoadCheck then
          if linkDrivability < drivability or
          linkDrivability < lerp(drivability, 1, randomValue) or
          road.radius < (width + max(0, (length - 5) / 20)) * linkCoef then
            status = 'roadTestFail'
            break
          end
        end

        local relDot = startDir:dot((road.pos - startPos):normalized())
        local heightValue = clamp(square(startPos.z - road.pos.z) / 8 * relDot, 0, 200) -- augments final distance with camera height if looking at point
        local currDist = minDist + innerDist
        local foundSpawn = false

        if extraArgs.ignoreRaycast or currDist >= max(minDist, maxDist * relDot) + heightValue then
          foundSpawn = true
        else
          local posUp = road.pos + vecUp * 2 -- raise height a bit to "look" over hills
          local rayDirVecCross = (posUp - startPos):z0():normalized():cross(vecUp) -- side vector to test for narrow objects such as lampposts

          for i = -1, 1 do -- three point check for static raycast (checks for thin statics such as trees)
            local rayDirVec = (posUp + rayDirVecCross * i * 1.5) - startPos
            local rayDistMax = rayDirVec:length()
            rayDirVec = rayDirVec / (rayDistMax + 1e-30)
            local rayDist = castRayStatic(startPos, rayDirVec, rayDistMax) -- tests if spawn point is blocked by ray from start position
            if rayDist >= rayDistMax then
              break
            end

            foundSpawn = i == 1 -- true if loop did not break
          end
        end

        if foundSpawn then
          if M.debugMode then
            log('I', logTag, 'Spawn point found at distance: '..currDist)
          end
          foundSpawn = checkSpawnPos(road.pos, minDist, minDist, extraArgs.checkRadius) -- ensure valid spawn point
        end

        if foundSpawn then
          road.startPos = startPos
          road.startDir = startDir
          -- create value with approximate road network density
          local branches = map.getGraphpath():getBranchNodesAround(n1, 200) -- number of found branches within area
          local baseDensity = (road.link.oneWay and road.radius >= 3) and 0.8 or 0.6 -- base density value
          local trafficValue = max(0, 4 - getNumOfTraffic(true)) * 0.1 -- active traffic vehicles modifier
          baseDensity = baseDensity + trafficValue -- if there are only a few vehicles, increase this number
          road.density = min(1 + trafficValue, (baseDensity + #branches / 24)) -- coefficient to use with vehicle spawn value

          if M.debugMode then
            log('I', logTag, 'Spawn point validated!')
            dump({n1 = road.n1, n2 = road.n2, pos = road.pos, rot = road.rot, radius = road.radius})
          end
          return road
        end

        innerDist = innerDist + max((1 - linkDrivability) * 100, road.link.speedLimit * 1.5) -- lower drivability or higher speed limit = bigger gaps
      end
      loopCount = loopCount + 1
    end
  else
    status = 'spawnPathFail'
  end

  if M.debugMode then
    log('W', logTag, 'Spawn point failed! Reason: '..status)
  end
end

local function placeOnRoad(spawnData, placeData) -- sets a position and rotation on road
  local pos
  local rot = spawnData.rot or (mapNodes[spawnData.n2].pos - mapNodes[spawnData.n1].pos):normalized()
  local radius = spawnData.radius
  if not radius then radius = mapNodes[spawnData.n1] and lerp(mapNodes[spawnData.n1].radius, mapNodes[spawnData.n2].radius, 0.5) or minRadius end
  local roadWidth = radius * 2
  local laneWidth = roadWidth >= 6.1 and 3.05 or 2.4 -- gets modified for very narrow roads
  local slope = rot:dot(vecUp)
  local dirBias = placeData and placeData.dirBias or 0 -- negative = away from you, positive = towards you
  local legalSide = mapRules.rightHandDrive and -1 or 1
  local origRot = rot
  if spawnData.startPos and spawnData.startDir then
    if (spawnData.pos - spawnData.startPos):dot(spawnData.startDir) < 0 then
      dirBias = min(1, dirBias + 0.5) -- vehicles spawning on the path behind should mostly drive towards you
    end
  end

  local laneCount = max(1, math.floor(roadWidth / laneWidth)) -- estimated number of lanes (this will change when real lanes exist)
  if spawnData.link and not spawnData.link.oneWay and laneCount % 2 ~= 0 then -- two way roads currently have an even amount of expected lanes
    laneCount = max(1, laneCount - 1)
  end
  local laneChoice, roadDir, offset

  if spawnData.link and spawnData.link.oneWay then
    laneChoice = random(laneCount)
    roadDir = spawnData.link.inNode == spawnData.n1 and 1 or -1 -- spawn facing the correct way
  else
    if laneCount == 1 then
      roadDir = 1 -- always spawn facing forwards on narrow roads
      laneChoice = 1
    else
      -- if road is steep, try spawning facing downhill
      if math.abs(slope) > 0.15 then
        roadDir = -sign2(slope)
      else
        roadDir = dirBias > random() * 2 - 1 and -1 or 1
      end

      local laneMin = roadDir == -1 and 1 or max(1, math.floor(laneCount * 0.5) + 1)
      local laneMax = roadDir == -1 and max(1, math.floor(laneCount * 0.5)) or laneCount
      laneChoice = random(laneMin, laneMax)
    end
  end

  offset = (laneChoice - (laneCount * 0.5 + 0.5)) * (roadWidth / laneCount) * legalSide -- lateral offset
  if placeData then -- custom placements
    offset = placeData.offset or offset
    roadDir = placeData.roadDir or roadDir
  end

  pos = spawnData.pos + origRot:z0():cross(vecUp) * offset
  rot = rot * roadDir

  local surfaceHeight = be:getSurfaceHeightBelow((pos + vecUp * 2.5))
  if surfaceHeight >= -1e6 then
    pos.z = surfaceHeight
  end
  return pos, rot
end

local function getNextSpawnPoint(id, spawnData, placeData) -- sets the new spawn point of a vehicle
  if id and be:getObjectByID(id) then
    local playerId = be:getPlayerVehicleID(0)
    if not spawnData then
      local spawnValue = traffic[id] and traffic[id].respawn.finalSpawnValue or 1
      if spawnValue > 0 then
        local freeCamMode = commands.isFreeCamera() or not traffic[playerId]
        local dirVec = freeCamMode and getCameraForward() or vec3(traffic[playerId].vel) / (traffic[playerId].speed + 1e-30)
        local speedValue = freeCamMode and 40 or traffic[playerId].speed * 2
        local minDist = clamp(80 / spawnValue + speedValue, 40, 200)
        local maxDist = clamp(minDist * 2.5, 140, 400)
        local maxRandomValue = traffic[id] and traffic[id].respawn.spawnRandomization or 1
        local maxLateralDist = maxRandomValue * 0.25
        dirVec:setAdd(dirVec:cross(vecUp):normalized() * (random() * maxRandomValue * 2 - maxRandomValue)) -- small randomization of start direction

        local extraArgs = {}
        extraArgs.lateralDist = random(speedValue * -maxLateralDist, speedValue * maxLateralDist)
        extraArgs.pathRandom = freeCamMode and 1 or clamp((100 - speedValue) / 60, 0, maxRandomValue)

        if traffic[id] then
          extraArgs.width, extraArgs.length = traffic[id].width, traffic[id].length
          extraArgs.drivability = clamp(traffic[id].drivability, vars.baseDrivability, 1)
        end

        for i = 1, 2 do
          spawnData = findSpawnPoint(getCameraPosition(), dirVec, minDist, maxDist, extraArgs)
          if spawnData then
            if traffic[id] then traffic[id].tempSpawnCoef = spawnData.density end -- set initial spawn value coef to the spawn point density value
            break
          end
          dirVec = -dirVec -- try reverse search direction once
        end
      end
    end
  end

  if spawnData then
    local pos, rot = placeOnRoad(spawnData, placeData)
    local normal = map.surfaceNormal(pos, 1)
    rot = quatFromDir(vecY:rotated(quatFromDir(rot, normal)), normal)
    return pos, rot
  end
end

local function respawnVehicle(id, pos, rot) -- moves the vehicle to a new position and rotation
  local obj = id and be:getObjectByID(id)
  if not obj or not pos or not rot then return end

  spawn.safeTeleport(obj, pos, rot, true) -- this is slower, but prevents vehicles from spawning inside a static object if the navgraph is not perfect
  obj:resetBrokenFlexMesh()
  --rot = rot * quat(0, 0, 1, 0)
  --obj:setPositionRotation(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
  --obj:autoplace(false)
  --obj:queueLuaCommand('ai.reset()')

  table.insert(positionsCache, vec3(pos))
  respawnTicks = 5

  if traffic[id] then
    traffic[id]:onRespawn()
  end
end

local function forceTeleport(id, pos, rot, minDist, maxDist) -- force teleports a traffic vehicle
  setMapData()
  minDist = minDist or 180
  maxDist = maxDist or 500

  local vehObj = be:getObjectByID(id)
  pos = pos or getCameraPosition()
  rot = rot or vec3(vecY:rotated(getCameraQuat()))

  if vehObj and vehObj:getActive() then
    local data = findSpawnPoint(pos, rot, minDist, maxDist, {ignoreRoadCheck = true, ignoreRaycast = true})
    if data then
      local newPos, newRot = getNextSpawnPoint(id, data)
      respawnVehicle(id, newPos, newRot)
    else -- no valid spawn point found
      vehObj:setActive(0)
      if traffic[id] then
        traffic[id].state = 'reset'
        traffic[id].sleepTimer = 5
      end
    end
  end
end

local function forceTeleportAll(minDist, maxDist) -- force teleports all traffic vehicles in one handy function
  for _, id in ipairs(trafficAiVehsList) do
    forceTeleport(id, nil, nil, minDist, maxDist)
  end
end

local function createTrafficPool() -- sets the main traffic vehicle pooling object
  if not core_vehiclePoolingManager then extensions.load('core_vehiclePoolingManager') end
  local maxAmount = spawnProcess.vehList and math.huge or vars.activeAmount
  trafficPool = core_vehiclePoolingManager.createPool()
  trafficPool.name = 'traffic'
  trafficPoolId = trafficPool.id
  trafficPool:setMaxActiveVehs(maxAmount)
end

local function deleteTrafficPool() -- deletes the traffic pool and resets variables
  if trafficPool then
    trafficPool:deletePool(true)
    trafficPool, trafficPoolId = nil, nil
  end
  vars.activeAmount = math.huge
end

local function updateTrafficPool(nearTele) -- updates the main traffic vehicle pooling object
  trafficPool:setMaxActiveVehs(vars.activeAmount)
  for i = 1, vars.activeAmount - #trafficPool.activeVehs do
    local id = trafficPool.inactiveVehs[i]
    if not id then break end
    if traffic[id] then traffic[id].forceTeleport = true end
  end
  trafficPool:setAllVehs(true)
  for id, v in pairs(traffic) do -- force teleport vehicles that got newly activated
    if v.forceTeleport then
      be:getObjectByID(id):setMeshAlpha(0, '')
      v.alpha = 0
      forceTeleport(v.id, nil, nil, nearTele and 0) -- nearTele forces vehicles to spawn in view of the player (maybe the distance can be higher than 0)
    end
  end
end

local function setTrafficPool(poolId, autoCycle) -- sets the pool id for traffic to use
  local vehPool = core_vehiclePoolingManager.getPoolById(poolId)
  if vehPool then
    if autoCycle then -- automatically process the new group
      if trafficPool then
        trafficPool:setAllVehs(false) -- first, sets all vehicles in current pool as inactive
        trafficPool.prevPoolId = trafficPoolId
      end

      trafficPool, trafficPoolId = vehPool, poolId -- then, sets traffic pool to new object
      trafficPool:setMaxActiveVehs(vars.activeAmount)
      trafficPool:setAllVehs(true) -- finally, sets all vehicles in new pool as active
      forceTeleportAll()
    else
      trafficPool.prevPoolId = trafficPoolId
      trafficPool, trafficPoolId = vehPool, poolId
    end
  end
end

local function getNextVehFromPool() -- returns the next usable inactive vehicle, or nil if none found
  if trafficPool then
    local pool = trafficPool
    if trafficPool.prevPoolId and core_vehiclePoolingManager.getPoolById(trafficPool.prevPoolId) then -- alternate vehicle pool for cycling
      pool = core_vehiclePoolingManager.getPoolById(trafficPool.prevPoolId)
    end
    for _, id in ipairs(pool.inactiveVehs) do
      if traffic[id] and traffic[id].state ~= 'locked' then
        return id
      end
    end
  end
end

local function processNextSpawn(veh) -- processes the next vehicle respawn action
  local newPos, newRot
  local oldId, newId = veh.id, veh.id
  local nextId = getNextVehFromPool()

  if nextId then -- if enableAutoPooling is false, bypasses the vehicle pool cycling system
    if #trafficPool.activeVehs < trafficPool.maxActiveVehs then -- amount of active vehicles is less than the expected limit
      newId = nextId
    elseif veh.enableAutoPooling then
      oldId, newId = trafficPool:crossCycle(trafficPool.prevPoolId, oldId, nextId) -- cycles the pool; if a previous pool exists, use a vehicle from there
    end
  end

  newPos, newRot = getNextSpawnPoint(newId, nil, {dirBias = veh.respawn.spawnDirBias})
  if newPos then
    be:getObjectByID(newId):setActive(1) --trafficPool:setVeh(newId, true)
    respawnVehicle(newId, newPos, newRot)
  else
    veh:onRefresh()
    veh.sleepTimer = 5
  end
end

local function setDebugMode(value) -- sets the debug mode
  vars.aiDebug = value and 'traffic' or 'off'
end

local function refreshVehicles() -- resets core traffic vehicle data
  for _, veh in pairs(traffic) do
    veh:onRefresh()
  end
end

local function resetTrafficVars() -- resets traffic variables to default
  vars = {
    baseAggression = 0.3,
    baseDrivability = 0.25,
    spawnValue = 1,
    spawnDirBias = 0.2,
    activeAmount = math.huge,
    aiMode = 'traffic',
    aiAware = 'auto',
    aiDebug = 'off',
    enableRandomEvents = true
  }

  refreshVehicles()
end
resetTrafficVars()

local function setTrafficVars(data) -- sets various traffic variables
  if type(data) ~= 'table' then return end

  for k, v in pairs(data) do
    if k == 'aiMode' or k == 'aiDebug' or k == 'aiAware' then
      data[k] = type(v) == 'string' and string.lower(v) or v
    end
  end

  vars = tableMerge(vars, data)

  for _, id in ipairs(trafficAiVehsList) do
    local veh = traffic[id]

    if data.aiMode then
      veh:setAiMode(vars.aiMode)
    end
    if data.aiAware then
      veh:setAiAware(vars.aiAware)
    end
    if data.speedLimit or data.baseAggression then
      refreshVehicles()
    end
    if data.spawnValue then
      veh.respawn.spawnValue = data.spawnValue
    end
  end

  if data.aiDebug then
    M.debugMode = data.aiDebug == 'traffic'
    refreshVehicles()
  end
  if data.activeAmount and trafficPool then
    updateTrafficPool()
  end
end

local function setPursuitMode(mode) -- sets pursuit mode; -1 = busted, 0 = off, 1 and higher = pursuit level
  extensions.gameplay_police.setPursuitMode(mode)
end

local function getRoleConstructor(roleName) -- gets the role constructor module
  if not rolesCache[roleName] then
    if not FS:fileExists('/lua/ge/extensions/gameplay/traffic/roles/'..roleName..'.lua') then
      log('W', logTag, 'Traffic role does not exist: '..roleName)
      roleName = 'standard'
    end
    rolesCache[roleName] = require('/lua/ge/extensions/gameplay/traffic/roles/'..roleName)
  end
  return rolesCache[roleName]
end

local function insertTraffic(id, ignoreAi) -- inserts new vehicles into the traffic table
  -- ignoreAi prevents AI and respawn logic from getting applied to the given vehicle
  local obj = be:getObjectByID(id)

  if obj and not traffic[id] and obj.jbeam ~= 'unicycle' then
    obj:setMeshAlpha(1, '')

    traffic[id] = trafficVehicle({id = id})
    if not traffic[id] then -- traffic vehicle object creation failed
      return
    end

    obj:setDynDataFieldbyName('isTraffic', 0, not ignoreAi and 'true' or 'false')
    if not ignoreAi then
      table.insert(trafficAiVehsList, id)
      traffic[id]:setAiMode(vars.aiMode)
      gameplay_walk.addVehicleToBlacklist(id)

      if not settings.getValue('trafficEnableSwitching') then
        obj.playerUsable = false
      end

      if not trafficPool then
        createTrafficPool()
      end
      trafficPool:insertVeh(id)
    end

    extensions.hook('onTrafficVehicleAdded', id)
  end
end

local function removeTraffic(id) -- removes vehicles from the traffic table
  if traffic[id] then
    local obj = be:getObjectByID(id)
    local idx = arrayFindValueIndex(trafficAiVehsList, id)
    if idx then table.remove(trafficAiVehsList, idx) end

    if obj then
      traffic[id].role:resetAction()
      obj:setMeshAlpha(1, '')
      obj.playerUsable = true
      obj.uiState = 1
    end

    traffic[id] = nil
    extensions.hook('onTrafficVehicleRemoved', id)
  end

  if trafficPool and not trafficAiVehsList[1] then
    deleteTrafficPool()
  end
end

local function checkPlayer(id) -- checks if the player data needs to be inserted
  if trafficAiVehsList[1] and be:getObjectByID(id) and be:getObjectByID(id):isPlayerControlled() then
    if traffic[id] then
      be:getObjectByID(id):setMeshAlpha(1, '') -- if vehicle was invisible, show it
    else
      insertTraffic(id, true)
    end
  end
end

local function onVehicleSpawned(id)
  if traffic[id] then -- if vehicle is replaced, update its traffic role and properties
    traffic[id]:applyModelConfigData()
    traffic[id]:setRole(traffic[id].autoRole)
    traffic[id]:resetAll()
  end
end

local function onVehicleSwitched(_, id)
  checkPlayer(id)
end

local function onVehicleResetted(id)
  checkPlayer(id)
  if traffic[id] then
    traffic[id]:onVehicleResetted()
  end
end

local function onVehicleDestroyed(id)
  removeTraffic(id)
end

local function deleteVehicles(ignoreParked) -- deletes all traffic vehicles
  for _, veh in ipairs(getAllVehiclesByType()) do
    local id = veh:getId()
    if traffic[id] and traffic[id].isAi or tonumber(veh.isTraffic) == 1 then
      removeTraffic(id)
      veh:delete()
    end
  end

  if not ignoreParked and gameplay_parking.getState() then -- also deletes parked vehicles
    gameplay_parking.deleteVehicles()
  end
end

local function activate(vehList) -- activates traffic mode, and adds specified vehicles to the traffic table
  -- backwards compatible stuff
  if type(vehList) ~= 'table' then
    vehList = {}
    for _, v in ipairs(getAllVehiclesByType()) do
      if not v.isParked then
        table.insert(vehList, v:getID())
      end
    end
  end

  if not vehList[1] then
    log('W', logTag, 'No vehicles found; unable to start traffic!')
    return
  end

  table.sort(vehList, function(a, b) return a < b end)

  for _, id in ipairs(vehList) do
    if type(id) == 'number' then
      map.request(id, -1) -- force mapmgr to read map
      insertTraffic(id, be:getObjectByID(id):isPlayerControlled())
    end
  end
end

local function deactivate(stopAi) -- deactivates traffic mode for all vehicles
  if getNumOfTraffic(true) == 0 then return end

  for _, id in ipairs(shallowcopy(trafficAiVehsList)) do
    removeTraffic(id)
    if stopAi and be:getObjectByID(id) then
      be:getObjectByID(id):queueLuaCommand('ai.setMode("stop")')
    end
  end
end

local function createBaseGroupParams() -- returns base group generation parameters
  return {filters = {Type = {car = 1, truck = 0.75}, ["Derby Class"] = {["heavy truck"] = 0, other = 1}}, country = getCountry(), maxYear = 0, minPop = 50}
end

local function createTrafficGroup(amount, allMods, allConfigs, simpleVehs) -- creates a traffic group with the use of some player settings
  if allMods == nil then allMods = settings.getValue('trafficAllowMods') end
  if allConfigs == nil then allConfigs = settings.getValue('trafficSmartSelections') end
  if simpleVehs == nil then simpleVehs = settings.getValue('trafficSimpleVehicles') end

  local params = createBaseGroupParams()
  params.allMods = allMods
  params.modelPopPower = 0.5
  params.configPopPower = 1

  if simpleVehs then
    params.allConfigs = true
    params.filters.Type = {proptraffic = 1}
    params.minPop = 0
  else
    params.allConfigs = allConfigs
    params.filters['Config Type'] = {Police = 0, other = 1} -- no police cars

    if params.allMods and params.filters.Type then
      params.filters.Type.automation = 1
      params.minPop = 0
    end
  end

  return core_multiSpawn.createGroup(amount, params)
end

local function createPoliceGroup(amount, allMods) -- creates a group of police vehicles
  if allMods == nil then allMods = settings.getValue('trafficAllowMods') end

  local params = createBaseGroupParams()

  params.allMods = allMods
  params.allConfigs = true
  params.minPop = 0
  params.modelPopPower = 0.5
  params.configPopPower = 1

  if params.allMods and params.filters.Type then
    params.filters.Type.automation = 1
  end
  if params.country ~= 'default' then
    params.filters.Country = {[params.country] = 100, other = 0.1} -- other is 0.1 (not 0) just in case no country matches
  end
  params.filters['Config Type'] = {police = 1}

  return core_multiSpawn.createGroup(amount, params)
end

local function spawnTraffic(amount, group) -- spawns a defined group of vehicles and sets them as traffic
  amount = amount or max(1, getAmountFromSettings() - #getAllVehiclesByType())
  group = group or core_multiSpawn.createGroup(amount)
  state = 'spawning'

  return core_multiSpawn.spawnGroup(group, amount, {name = 'autoTraffic', mode = 'traffic', ignoreJobSystem = not worldLoaded, ignoreAdjust = not worldLoaded})
end

local function setupTraffic(maxAmount, policeRatio, extraAmount, parkedAmount, options) -- prepares a group of vehicles for traffic
  maxAmount = maxAmount or -1
  policeRatio = policeRatio or 0
  extraAmount = extraAmount or -1
  parkedAmount = parkedAmount or -1
  options = options or {}

  if not options.ignoreDelete then
    deleteVehicles() -- clear current traffic
  end
  deleteTrafficPool()
  setTrafficVars({aiMode = 'traffic'})

  local trafficGroup, policeGroup
  local policeAmount = 0

  if maxAmount == -1 then
    maxAmount = getIdealSpawnAmount(getAmountFromSettings()) -- maxAmount automatically accounts for currently spawned non-traffic vehicles
  else
    if not options.ignoreAutoAmount then
      maxAmount = getIdealSpawnAmount(maxAmount) -- adjust for amount of existing active vehicles
    end
  end

  if extraAmount == -1 then
    if settings.getValue('trafficExtraVehicles') then
      local customExtraAmount = settings.getValue('trafficExtraAmount')
      if customExtraAmount == 0 then
        extraAmount = clamp(getAmountFromSettings(), 2, 8)
      else
        extraAmount = customExtraAmount
      end
    else
      extraAmount = 0
    end
  end

  if policeRatio > 0 then
    local country = getCountry()
    policeAmount = min(maxAmount, math.ceil(maxAmount * policeRatio))
    policeGroup = createPoliceGroup(policeAmount)

    if policeAmount > 0 and not policeGroup[1] then
      table.insert(policeGroup, 1, defaultPoliceCar)
    end
  end

  if maxAmount > 0 then
    --ui_message('ui.traffic.spawnLoad', 3, 'traffic')
    trafficGroup = createTrafficGroup(maxAmount + extraAmount - policeAmount, options.allMods, options.allConfigs, options.simpleVehs)

    if policeGroup then
      local groupIdx = 1
      while #trafficGroup < maxAmount + extraAmount do
        groupIdx = policeGroup[groupIdx + 1] and groupIdx + 1 or 1
        table.insert(trafficGroup, policeGroup[groupIdx]) -- insert police vehicle into main group until full
      end
    end
  end

  if not trafficGroup or not trafficGroup[1] then
    trafficGroup = {defaultTrafficCar}
  end

  if parkedAmount == -1 then
    parkedAmount = settings.getValue('trafficParkedVehicles') and settings.getValue('trafficParkedAmount') or 0
  end

  if parkedAmount > 0 then
    local parkingSpots = gameplay_parking.getParkingSpots()
    if parkingSpots then
      parkedAmount = min(parkedAmount, #parkingSpots.sorted) -- amount should be defined in settings
    else
      parkedAmount = 0
      log('W', logTag, 'Unable to find any valid parking spots from the main sites data')
    end
  end

  if maxAmount + parkedAmount > 0 then
    vars.activeAmount = extraAmount > 0 and maxAmount or math.huge
    spawnProcess.group = trafficGroup
    spawnProcess.amount = maxAmount + extraAmount
    spawnProcess.parkedAmount = parkedAmount
    state = 'loading'
    return true
  else
    log('W', logTag, 'Traffic amount to spawn is zero!')
    ui_message('ui.traffic.spawnLimit', 5, 'traffic', 'traffic')
    guihooks.trigger('app:waiting', false)
    return false
  end
end

local function setupTrafficWaitForUi(maxAmount, policeRatio) -- displays the loading icon; intended to be used by radial menu
  spawnProcess.amount = maxAmount or -1
  spawnProcess.policeRatio = policeRatio or 0
  spawnProcess.uiWait = true
  guihooks.trigger('menuHide')
  guihooks.trigger('app:waiting', true) -- shows the loading icon
end

local function setupCustomTraffic(amount, params) -- spawns a group of vehicles for traffic, with custom parameters
  if type(params) ~= 'table' then params = {} end
  if not amount or amount < 0 then amount = getAmountFromSettings() end
  params.country = params.country or getCountry()

  spawnTraffic(amount, core_multiSpawn.createGroup(amount, params))
end

-- spawns and de-spawns traffic vehicles in freeroam
-- keepInMemory allows instantenous reactivation at the expense of ram consumption when traffic is disabled
local function toggle(keepInMemory)
  if core_gamestate.state.state == 'freeroam' then
    if state == 'off' then
      setupTraffic(getAmountFromSettings())
    elseif state == 'on' then
      if keepInMemory then
        if vars.activeAmount == 0 then
          vars.activeAmount = getAmountFromSettings() -- value is set directly to allow for the next line to override the default behavior
          updateTrafficPool(true)
        else
          vars.activeAmount = 0
          updateTrafficPool(true)
        end
      else
        deleteVehicles()
      end
    end
  end
end

local function freezeState() -- stops the traffic and parking systems, and returns the state data
  return M.onSerialize(), gameplay_parking.onSerialize()
end

local function unfreezeState(trafficData, parkingData) -- reverts the traffic and parking systems
  if not trafficData and not parkingData then
    log('W', logTag, 'No data provided to revert state!')
    return
  end
  if trafficData then
    M.onDeserialized(trafficData)
    forceTeleportAll()
  end
  if parkingData then
    gameplay_parking.onDeserialized(parkingData)
  end
end

local function doTraffic(dt, dtSim) -- various logic for traffic; also handles when to respawn traffic
  if not trafficPool then createTrafficPool() end
  if trafficPool.maxActiveVehs > 0 and not trafficPool.activeVehs[1] and trafficPool.inactiveVehs[1] then -- if there are no active vehicles, try to use one
    -- this is important, just in case the max active amount changes from zero but vehicles could not be placed yet
    local vehId = getNextVehFromPool()
    if vehId then
      local veh = traffic[vehId]
      if veh.sleepTimer <= 0 then
        veh.forceTeleport = true
        veh:tryRespawn()
      end
    end
  end

  if not player.pos then
    player.pos, player.camPos, player.camDirVec = vec3(), vec3(), vec3()
  end

  player.camPos:set(getCameraPosition())
  player.camDirVec:set(getCameraForward())
  if be:getPlayerVehicle(0) then
    player.pos:set(be:getPlayerVehicle(0):getPosition())
  else
    player.pos = player.camPos
  end

  local vehCount = 0
  for i, v in ipairs(getAllVehiclesByType()) do -- ensures consistent order of vehicles
    vehCount = vehCount + 1
    local id = v:getID()
    local veh = traffic[id]
    if veh then
      local obj = be:getObjectByID(id)
      veh.playerData = player
      veh:onUpdate(dt, dtSim)

      if (obj:getActive() or veh.forceTeleport) and not veh.isPlayerControlled then
        if veh.state == 'reset' or veh.state == 'new' then
          local isReset = veh.state == 'reset'
          veh:onRefresh()

          if vars.enableRandomEvents and vars.aiMode == 'traffic' and veh.isAi and isReset then
            veh.role:tryRandomEvent()
          end
        end

        if i == queuedVehicle then -- checks one vehicle per frame, as an optimization
          if veh.state == 'active' then
            veh:tryRespawn(#trafficAiVehsList)
          elseif veh.state == 'queued' then
            processNextSpawn(veh)
          end

          veh.otherCollisionFlag = nil
        end
      end
    end
  end

  queuedVehicle = queuedVehicle + 1
  if queuedVehicle > vehCount then
    queuedVehicle = 1
  end

  if respawnTicks > 0 then
    respawnTicks = respawnTicks - 1 -- optimization to prevent rapid succession of respawning vehicles
  end
end

local function doDebug() -- general debug visuals
  for id, veh in pairs(traffic) do
    local obj = be:getObjectByID(id)
    if obj:getActive() then
      local lineColor = veh.camVisible and debugColors.green or debugColors.white
      local txtColor = debugColors.white
      local bgColor = veh.isPlayerControlled and debugColors.greenAlt or debugColors.blackAlt
      if veh.state == 'fadeIn' then lineColor = debugColors.red end

      if veh.debugLine then
        local focusPos = vec3(veh.focusPos)
        local z = be:getSurfaceHeightBelow((focusPos + vecUp * 4))

        if z >= -1e6 then
          focusPos.z = z
        elseif core_terrain.getTerrain() then
          focusPos.z = core_terrain.getTerrainHeight(focusPos)
        end

        debugDrawer:drawLine(veh.pos, player.camPos + player.camDirVec - vecUp, lineColor)
        debugDrawer:drawSphere(focusPos, 0.25, debugColors.green)
      end

      if veh.debugText then
        debugDrawer:drawTextAdvanced(veh.pos, String('['..veh.id..']: '..math.floor(veh.distCam)..' m, '..math.ceil(veh.respawn.readyValue * 100)..'%, '..math.floor((veh.speed or 0) * 3.6)..' km/h'), txtColor, true, false, bgColor)
        if veh.pursuit.mode ~= 0 then
          debugDrawer:drawTextAdvanced(veh.pos, String('[PURSUIT]: mode = '..veh.pursuit.mode..', score = '..math.ceil(veh.pursuit.score)..', offenses = '..veh.pursuit.uniqueOffensesCount), txtColor, true, false, bgColor)
        end
      end
    end
  end
end

local function onSettingsChanged()
  refreshVehicles()
end

local function trackAIAllVeh(mode) -- triggers when the player sets an AI mode for all vehicles
  vars.aiMode = string.lower(mode)
  refreshVehicles()
end

local function onVehicleMapmgrUpdate(id) -- if using vehicle pooling, vehicle must be set as inactive only after this resolves
  if trafficPool and spawnProcess.vehList and spawnProcess.vehList[#spawnProcess.vehList] == id then -- last vehicle
    if not worldLoaded then
      trafficPool:setMaxActiveVehs(0)
      log('I', logTag, 'Temporarily hid all traffic vehicles')
      worldLoaded = true
    end

    trafficPool:setMaxActiveVehs(vars.activeAmount)
    table.clear(spawnProcess)
  end
end

local function onParkingVehiclesActivated()
  if state == 'spawning' then
    guihooks.trigger('app:waiting', false)
    guihooks.trigger('QuickAccessMenu')
    if spawnProcess.vehList then
      activate(spawnProcess.vehList)
    else
      state = 'off'
    end
  end
end

local function onVehicleGroupSpawned(vehList, gid, gName)
  if state == 'spawning' and gName == 'autoTraffic' then
    spawnProcess.vehList = vehList

    if spawnProcess.parkedAmount and spawnProcess.parkedAmount > 0 then
      gameplay_parking.setupVehicles(spawnProcess.parkedAmount)
    else
      guihooks.trigger('app:waiting', false)
      guihooks.trigger('QuickAccessMenu')
      activate(spawnProcess.vehList)
    end
  end
end

local function onUpdate(dtReal, dtSim)
  if state == 'loading' then
    if spawnProcess.amount and spawnProcess.amount > 0 then
      spawnTraffic(spawnProcess.amount, spawnProcess.group)
    else
      if spawnProcess.parkedAmount and spawnProcess.parkedAmount > 0 then
        state = 'spawning'
        gameplay_parking.setupVehicles(spawnProcess.parkedAmount)
      else
        guihooks.trigger('app:waiting', false)
        guihooks.trigger('QuickAccessMenu')
        state = 'off'
      end
    end
  end

  if trafficPool and trafficPool._updateFlag then
    updateTrafficPool()
    trafficPool._updateFlag = nil
  end

  -- these hooks activate the frame after the first or last traffic vehicle gets inserted or removed
  if state ~= 'on' and trafficAiVehsList[1] then
    for _, veh in ipairs(getAllVehiclesByType()) do -- check for player vehicles to insert into traffic
      checkPlayer(veh:getID())
    end
    extensions.hook('onTrafficStarted')
  end
  if state == 'on' and not trafficAiVehsList[1] then
    extensions.hook('onTrafficStopped')
  end

  if state == 'on' then
    if M.queueTeleport then
      forceTeleportAll()
      M.queueTeleport = false
    end
    if be:getEnabled() and not freeroam_bigMapMode.bigMapActive() then
      doTraffic(dtReal, dtSim)
    end
  end

  if positionsCache[1] then table.clear(positionsCache) end
end

local function onPreRender(dt)
  if M.debugMode then
    doDebug()
  end
end

local function onTrafficStarted()
  setMapData()
  state = 'on'
  trafficPool._updateFlag = true -- acts like a frame delay for the vehicle pooling system
end

local function onTrafficStopped()
  deleteTrafficPool()
  table.clear(traffic)
  table.clear(trafficAiVehsList)
  table.clear(player)
  state = 'off'
end

local function onClientStartMission()
  if state == 'off' then
    worldLoaded = true
  end
end

local function onClientEndMission()
  onTrafficStopped()
  resetTrafficVars()
  worldLoaded = false
end

local function onUiWaitingState()
  if spawnProcess.uiWait then
    setupTraffic(spawnProcess.amount, spawnProcess.policeRatio)
    spawnProcess.uiWait = false
  end
end

local function onSerialize()
  local trafficData = {}
  for _, veh in pairs(traffic) do
    table.insert(trafficData, veh:onSerialize())
  end
  local data = {state = state, traffic = deepcopy(trafficData), vars = deepcopy(vars)}
  onTrafficStopped()
  resetTrafficVars()
  mapNodes, mapRules = nil, nil
  return data
end

local function onDeserialized(data)
  worldLoaded = true
  if data.state == 'on' and data.traffic then
    for _, veh in pairs(data.traffic) do
      traffic[veh.id] = trafficVehicle({id = veh.id})
      if traffic[veh.id] then
        traffic[veh.id]:onDeserialized(veh)
        if veh.isAi then
          traffic[veh.id]:setAiMode(vars.aiMode)
          table.insert(trafficAiVehsList, veh.id)

          if not trafficPool then
            vars.activeAmount = data.vars.activeAmount
            createTrafficPool()
          end
          trafficPool:insertVeh(veh.id)
        end
      end
    end
    vars = data.vars
  end
end

---- getter functions ----

local function getState() -- returns traffic system state
  return state
end

local function getTrafficPool()
  return core_vehiclePoolingManager and core_vehiclePoolingManager.getPoolById(trafficPoolId) -- returns current vehicle pool object used for traffic
end

local function getTrafficAiVehsList() -- returns traffic list of ids
  return trafficAiVehsList
end

local function getTrafficData() -- returns the full traffic table
  return traffic
end

local function getPursuitData() -- DEPRECATED; returns the current player pursuit data
  return extensions.gameplay_police.getPursuitData()
end

local function getTrafficVars()
  return vars
end

-- public interface
M.spawnTraffic = spawnTraffic
M.setupTraffic = setupTraffic
M.setupTrafficWaitForUi = setupTrafficWaitForUi
M.createTrafficGroup = createTrafficGroup
M.createPoliceGroup = createPoliceGroup
M.setupCustomTraffic = setupCustomTraffic
M.insertTraffic = insertTraffic
M.removeTraffic = removeTraffic
M.deleteVehicles = deleteVehicles
M.activate = activate
M.deactivate = deactivate
M.toggle = toggle
M.refreshVehicles = refreshVehicles

M.getRandomPaint = getRandomPaint
M.forceTeleport = forceTeleport
M.forceTeleportAll = forceTeleportAll
M.findSpawnPoint = findSpawnPoint
M.getRoleConstructor = getRoleConstructor
M.setPursuitMode = setPursuitMode
M.setDebugMode = setDebugMode
M.getTrafficPool = getTrafficPool
M.setTrafficPool = setTrafficPool
M.getTrafficVars = getTrafficVars
M.setTrafficVars = setTrafficVars
M.getAmountFromSettings = getAmountFromSettings
M.getIdealSpawnAmount = getIdealSpawnAmount

M.getState = getState
M.freezeState = freezeState
M.unfreezeState = unfreezeState
M.getNumOfTraffic = getNumOfTraffic
M.getTrafficList = getTrafficAiVehsList
M.getTrafficData = getTrafficData
M.getTraffic = getTrafficData
M.getPursuitData = getPursuitData

M.onUpdate = onUpdate
M.onPreRender = onPreRender
M.trackAIAllVeh = trackAIAllVeh
M.onSettingsChanged = onSettingsChanged
M.onVehicleMapmgrUpdate = onVehicleMapmgrUpdate
M.onVehicleSpawned = onVehicleSpawned
M.onVehicleSwitched = onVehicleSwitched
M.onVehicleResetted = onVehicleResetted
M.onVehicleDestroyed = onVehicleDestroyed
M.onParkingVehiclesActivated = onParkingVehiclesActivated
M.onVehicleGroupSpawned = onVehicleGroupSpawned
M.onTrafficStarted = onTrafficStarted
M.onTrafficStopped = onTrafficStopped
M.onClientStartMission = onClientStartMission
M.onClientEndMission = onClientEndMission
M.onUiWaitingState = onUiWaitingState
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

return M
