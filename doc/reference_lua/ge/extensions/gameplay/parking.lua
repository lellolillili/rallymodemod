-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local logTag = "parking"

local areaRadius = 200 -- radius to search within for parking spots
local lookDist = 300 -- distance ahead of camera to start query of parking spots
local stepDist = 50 -- distance until the next parking spot query refresh
local parkedVehIds, parkedVehData = {}, {}
local trackedVehData = {}
local currParkingSpots = {}
local queuedIndex = 1
-- local defaultProbability = 0.75 -- this could be used, I guess

-- common functions --
local min = math.min
local max = math.max
local random = math.random

local sites
local playerPos, camPos, camDirVec, focusPos = vec3(), vec3(), vec3(), vec3()
local active = false
local worldLoaded = false
local parkingSpotsAmount = 0
local respawnTicks = 0
local debugLevel = 0

M.precision = 0.8 -- parking precision required for valid parking
M.neatness = 0 -- generated parked vehicle precision
M.parkingDelay = 0.5 -- time delay until a vehicle is considered parked

local function loadSites() -- loads sites data containing parking spots
  -- by default, the file "city.sites.json" in the root folder of the current level will be used
  extensions.load("gameplay_city")
  gameplay_city.loadSites()
  sites = gameplay_city.getSites()
  parkingSpotsAmount = sites and #sites.parkingSpots.sorted or 0
end

local function setSites(data) -- sets sites data, can override the default sites data
  if type(data) == "string" then
    if FS:fileExists(data) then
      sites = gameplay_sites_sitesManager.loadSites(data)
    end
  elseif type(data) == "table" then -- assuming that given data is valid sites data
    sites = data
  else
    sites = nil
  end
  parkingSpotsAmount = sites and #sites.parkingSpots.sorted or 0
end

local function setState(val) -- activates or deactivates the parking system
  active = val and true or false
  if active and not sites then
    loadSites()
  end
end

local function getState()
  return active
end

local function setDebugLevel(val) -- sets the debug level (from 0 to 3)
  -- 0 = off, 1 = parking spot boxes, 2 = parking spot corners, 3 = to be done
  debugLevel = val or 0
  if type(debugLevel) ~= "number" then
    debugLevel = 1
  end

  if debugLevel > 0 then
    log("I", logTag, "Vehicle switching enabled for parked vehicles")
  end

  for _, v in ipairs(parkedVehIds) do
    be:getObjectByID(v).playerUsable = debugLevel > 0
  end
end

local function getParkingSpots() -- returns a table of all current parking spots
  if not sites then
    loadSites()
  end
  return sites and sites.parkingSpots
end

local function moveToParkingSpot(vehId, parkingSpot, lowPrecision) -- assigns a parked vehicle to a parking spot
  local obj = be:getObjectByID(vehId)
  local width, length = obj.initialNodePosBB:getExtents().x - 0.1, obj.initialNodePosBB:getExtents().y
  local backwards, offsetPos, offsetRot

  if parkingSpot.customFields.tags.forwards then
    backwards = false
  elseif parkingSpot.customFields.tags.backwards then
    backwards = true
  else
    backwards = random() > 0.75 + M.neatness * 0.25
  end

  if not parkingSpot.customFields.tags.perfect then -- randomize position and rotation slightly
    local offsetVal = 1 - square(M.neatness)
    local xGap, yGap = max(0, parkingSpot.scl.x - width), max(0, parkingSpot.scl.y - length)
    local xRandom, yRandom = randomGauss3() / 3 - 0.5, clamp(randomGauss3() / 3 - (backwards and 0.75 or 0.25), -0.5, 0.5)
    offsetPos = vec3(xRandom * offsetVal * xGap, yRandom * offsetVal * yGap, 0)
    offsetRot = quatFromEuler(0, 0, (randomGauss3() / 3 - 0.5) * offsetVal * 0.25)
  end

  parkingSpot:moveResetVehicleTo(vehId, lowPrecision, backwards, offsetPos, offsetRot)
  if debugLevel > 0 then
    log("I", logTag, "Teleported vehId "..vehId.." to parking spot "..parkingSpot.id)
  end

  --core_vehicleBridge.executeAction(be:getObjectByID(vehId), "setIgnitionLevel", 0)
  be:getObjectByID(vehId):queueLuaCommand("electrics.setIgnitionLevel(0)")
  core_vehicle_manager.setVehiclePaintsNames(vehId, {gameplay_traffic.getRandomPaint(vehId, 0.75)})

  if parkedVehData[vehId] then
    if parkedVehData[vehId].hidden then
      be:getObjectByID(vehId):setActive(1)
      parkedVehData[vehId].hidden = nil
    end

    if parkedVehData[vehId].parkingSpotId then
      sites.parkingSpots.objects[parkedVehData[vehId].parkingSpotId].vehId = nil
    end

    if parkingSpot.customFields.tags.street then -- enables tracking, so that AI can try to avoid this vehicle
      if not map.objects[vehId] then be:getObjectByID(vehId):queueLuaCommand("mapmgr.enableTracking()") end
    else -- disables tracking, to optimize performance
      be:getObjectByID(vehId):queueLuaCommand("mapmgr.disableTracking()")
    end

    parkingSpot.vehId = vehId -- parking spot contains this vehicle
    parkedVehData[vehId].parkingSpotId = parkingSpot.id -- vehicle is assigned to this parking spot

    parkedVehData[vehId].radiusCoef = 1
    respawnTicks = 5
  end
end

local defaultParkingSpotSize = vec3(2.5, 6, 3)
local function checkDimensions(vehId) -- checks if the vehicle would fit in a standard sized parking spot
  local obj = be:getObjectByID(vehId)
  if not obj then return false end

  local extents = obj.initialNodePosBB:getExtents()
  return  extents.x <= defaultParkingSpotSize.x and
          extents.y <= defaultParkingSpotSize.y and
          extents.z <= defaultParkingSpotSize.z
end

local function checkParkingSpot(vehId, parkingSpot) -- checks if a parking spot is ready to use for a parked vehicle
  local obj = be:getObjectByID(vehId or 0)
  if parkingSpot.vehId or parkingSpot.ignoreOthers or parkingSpot.customFields.tags.ignoreOthers or not obj then
    return false
  end

  if parkingSpot:vehicleFits(obj) then
    -- ensures that the parking spot is not too oversized for the vehicle
    local size = obj.initialNodePosBB:getExtents()
    local psSize = parkingSpot.scl
    if size.x / psSize.x < 0.5 or size.y / psSize.y < 0.5 then
      return false
    end
  else
    return false
  end

  for _, v in ipairs(getAllVehicles()) do
    local sqRadius = v:getID() == be:getPlayerVehicleID(0) and 25 or 4 -- arbitrary, for now
    if not v.isParkingOnly and parkingSpot.pos:squaredDistance(v:getPosition()) <= sqRadius then
      return false
    end
  end
  return true
end

local function findParkingSpots(pos, minRadius, maxRadius) -- finds and returns a sorted array having the squared distances and parking spot objects
  if not sites then return end
  pos = pos or getCameraPosition()
  minRadius = minRadius or 0
  maxRadius = maxRadius or areaRadius

  local psList = sites:getRadialParkingSpots(pos, 0, maxRadius)

  if debugLevel > 0 then
    log("I", logTag, "Found and validated "..#psList.." parking spots in area")
  end
  table.sort(psList, function(a, b) return a.squaredDistance < b.squaredDistance end) -- sorts from closest to farthest

  return psList
end

local function refreshParkingSpots(psList, pos) -- refreshes the nearest parking spots in the cached list
  for i, v in ipairs(psList) do
    psList[i].squaredDistance = pos:squaredDistance(v.ps.pos)
  end

  table.sort(psList, function(a, b) return a.squaredDistance < b.squaredDistance end) -- sorts from closest to farthest
  return psList
end

local emptyFilters = {}
local defaultFilters = {useProbability = true}
local function filterParkingSpots(psList, filters) -- filters the sorted list of parking spots (as returned by findParkingSpots)
  if not psList or type(psList[1]) ~= "table" then return psList end
  filters = filters or defaultFilters

  local psCount = #psList
  local timeDay = 0

  if filters.useProbability then
    local timeObj = core_environment.getTimeOfDay()
    if timeObj and timeObj.time then
      timeDay = timeObj.time
    end
  end

  for i = psCount, 1, -1 do
    local ps = psList[i].ps

    if filters.useProbability then
      local prob = ps.customFields:has("probability") and ps.customFields:get("probability") or 1
      if type(prob) ~= "number" then prob = 1 end
      local dayValue = 0.25 + math.abs(timeDay - 0.5) * 1.5 -- max 1 for midday, min 0.25 for midnight
      local timeDayCoef = dayValue

      if ps.customFields.tags.nightTime then
        local nightValue = 1 - math.abs(timeDay - 0.5) * 1.5 -- opposite of dayValue
        if ps.customFields.tags.dayTime then
          timeDayCoef = max(timeDayCoef, nightValue)
        else
          timeDayCoef = nightValue
        end
      end
      prob = prob * timeDayCoef

      if prob <= random() then
        table.remove(psList, i)
      end
    end
  end

  if debugLevel > 0 then
    log("I", logTag, "Filtered and accepted "..#psList.." / "..psCount.." parking spots")
  end

  return psList
end

local function scatterParkedCars(vehIds) -- randomly teleports all parked vehicles to parking spots
  if not sites then return end
  local radius = 100
  local psList, psCount
  vehIds = vehIds or parkedVehIds
  local vehCount = #vehIds

  repeat
    psList = findParkingSpots(getCameraPosition(), 0, radius)
    psList = filterParkingSpots(psList)
    psCount = #psList
    radius = radius * 2
  until psCount >= vehCount or radius >= 10000

  if vehCount == 0 or psCount == 0 or radius >= 10000 then return end

  if psCount / vehCount >= 5 then -- parking spot final index limited by ratio of parking spots to vehicles
    psCount = vehCount * 5
  end

  local numList = {}
  for i = 1, vehCount do
    local linearRange = psCount / min(psCount, vehCount * 2)
    local new
    if i * linearRange - psCount * square(i / vehCount) >= 0 then -- linear range
      new = math.ceil(lerp((i - 1) * linearRange, i * linearRange, random()))
    else -- exponential range
      new = math.ceil(lerp(psCount * square((i - 1) / vehCount), psCount * square(i / vehCount), random()))
    end
    table.insert(numList, new)

    if numList[i - 1] and numList[i - 1] == new then
      numList[i] = min(psCount, numList[i] + 1)
    end
  end
  if debugLevel > 0 then dump(numList) end

  for i, id in ipairs(vehIds) do
    if parkedVehData[id].parkingSpotId then
      sites.parkingSpots.objects[parkedVehData[id].parkingSpotId].vehId = nil
      parkedVehData[id].parkingSpotId = nil
    end

    local ps = psList[numList[i]].ps
    if checkParkingSpot(id, ps, true) then
      moveToParkingSpot(id, ps, not be:getObjectByID(id):isReady())
    else
      parkedVehData[id].hidden = true
      be:getObjectByID(id):setActive(0) -- if no valid spot found, hide vehicle
    end
  end
end

local function enableTracking(vehId, autoDisable) -- enables parking spot tracking for a driving vehicle
  vehId = vehId or be:getPlayerVehicleID(0)
  if not be:getObjectByID(vehId) then return end

  trackedVehData[vehId] = {
    isOversized = checkDimensions(vehId),
    autoDisableTracking = autoDisable and true or false,
    inside = false,
    parked = false,
    event = "none",
    focusPos = vec3(),
    maxDist = 80,
    parkingTimer = 0
  }
end

local function disableTracking(vehId) -- disables parking spot tracking for a driving vehicle
  vehId = vehId or be:getPlayerVehicleID(0)
  trackedVehData[vehId] = nil
end

local function getTrackingData()
  return trackedVehData
end

local function trackParking(vehId) -- tracks parking status of a driving vehicle
  local valid = false
  local result = {
    cornerCount = 0
  }
  local obj = be:getObjectByID(vehId or 0)
  if not obj then return valid, result end

  local vehData = trackedVehData[vehId]
  local vehBB = obj:getSpawnWorldOOBB()
  local pos = linePointFromXnorm(vehBB:getCenter(), (vehBB:getPoint(0) + vehBB:getPoint(3)) / 2, 0.5) -- front position

  if vehData.focusPos:squaredDistance(pos) >= square(vehData.maxDist * 0.5) then
    vehData.psList = findParkingSpots(pos, 0, vehData.maxDist)
    vehData.psList = filterParkingSpots(vehData.psList, emptyFilters)
    vehData.focusPos = vec3(pos)
  end

  vehData.psList = refreshParkingSpots(vehData.psList, pos)

  if debugLevel > 0 then
    for _, v in ipairs(vehData.psList) do
      local ps = v.ps
      local dColor = ps.vehId and ColorF(1, 0.5, 0.5, 0.2) or ColorF(1, 1, 1, 0.2)
      if ps.vehId == vehId then dColor = ColorF(0.5, 1, 0.5, 0.2) end
      debugDrawer:drawSquarePrism(ps.pos - ps.dirVec * ps.scl.y * 0.5, ps.pos + ps.dirVec * ps.scl.y * 0.5, Point2F(0.6, ps.scl.x), Point2F(0.6, ps.scl.x), dColor)
    end
  end

  local bestPs
  for _, v in ipairs(vehData.psList) do -- nearest parking spot
    if v.ps:vehicleFits(obj) and (not v.ps.vehId or v.ps.vehId == vehId) then
      bestPs = v.ps
      break
    end
  end

  if bestPs then
    result.parkingSpotId = bestPs.id
    result.parkingSpot = bestPs

    if not bestPs.vertices[1] then bestPs:calcVerts() end

    valid, result.corners = bestPs:checkParking(be:getPlayerVehicleID(0), M.precision)

    for _, v in ipairs(result.corners) do
      if v then
        result.cornerCount = result.cornerCount + 1
      end
    end

    if debugLevel >= 2 then
      for i, v in ipairs(result.corners) do
        local dColor = v and ColorF(0.3, 1, 0.3, 0.5) or ColorF(1, 0.3, 0.3, 0.5)
        debugDrawer:drawCylinder(bestPs.vertices[i], bestPs.vertices[i] + vec3(0, 0, 10), 0.05, dColor)
      end
    end
  end

  return valid, result
end

local function processVehicles(vehIds, ignoreScatter) -- activates a group of vehicles, to allow them to teleport to new parking spots
  table.clear(parkedVehIds)
  table.clear(parkedVehData)
  if not vehIds then return end

  setState(true)
  if not sites then return end

  for _, id in ipairs(vehIds) do
    local obj = be:getObjectByID(id)
    if obj then
      parkedVehData[id] = {
        radiusCoef = 1 -- coefficient for keeping the vehicle at its current spot
      }

      obj.uiState = 0
      obj.playerUsable = false
      obj:setDynDataFieldbyName("ignoreTraffic", 0, "true")
      obj:setDynDataFieldbyName("isParkingOnly", 0, "true")
      gameplay_walk.addVehicleToBlacklist(id)

      table.insert(parkedVehIds, id)
    end
  end

  if worldLoaded and not ignoreScatter then
    scatterParkedCars(vehIds)
  end
  extensions.hook("onParkingVehiclesActivated", parkedVehIds)
  log("I", logTag, "Processed and teleported "..#parkedVehIds.." parked vehicles")
end

local function deleteVehicles(amount)
  amount = amount or #parkedVehIds
  for i = amount, 1, -1 do
    local id = parkedVehIds[i] or 0
    local obj = be:getObjectByID(id)
    if obj then
      obj:delete()
      table.remove(parkedVehIds, i)
      parkedVehData[id] = nil
    end
  end
end

local function setupVehicles(amount, ignoreDelete) -- spawns and prepares simple parked vehicles
  if not ignoreDelete then
    deleteVehicles()
  end

  amount = amount or 10
  if amount <= 0 then return false end
  local params = {filters = {}}

  params.allConfigs = true
  params.filters.Type = {propparked = 1}
  params.minPop = 0

  local group = core_multiSpawn.createGroup(amount, params)
  core_multiSpawn.spawnGroup(group, amount, {name = "autoParking", mode = "roadBehind", gap = 50, instant = not worldLoaded, ignoreAdjust = not worldLoaded})
  return true
end

local function getParkedCarsList()
  return parkedVehIds
end

local function getParkedCarsData()
  return parkedVehData
end

local function resetAll() -- resets everything
  active = false
  sites = nil
  parkingSpotsAmount = 0
  table.clear(parkedVehIds)
  table.clear(parkedVehData)
  table.clear(trackedVehData)
end

local function onVehicleGroupSpawned(vehList, gid, gName)
  if gName == "autoParking" then
    processVehicles(vehList)
  end
end

local function onVehicleDestroyed(id)
  if parkedVehData[id] then
    table.remove(parkedVehIds, arrayFindValueIndex(parkedVehIds, id))
    if sites and parkedVehData[id].parkingSpotId then
      sites.parkingSpots.objects[parkedVehData[id].parkingSpotId].vehId = nil
    end
    parkedVehData[id] = nil
  end
  if trackedVehData[id] then
    disableTracking(id)
  end
end

local function onUpdate(dt, dtSim)
  if not active or not sites or not be:getEnabled() or freeroam_bigMapMode.bigMapActive() then return end

  camPos:set(getCameraPosition())
  camDirVec:set(getCameraForward())

  if not worldLoaded and parkedVehIds[1] and camPos.z ~= 0 then
    scatterParkedCars()
    worldLoaded = true
  end

  if be:getPlayerVehicleID(0) ~= -1 then -- it would be good to track the positions of all player controlled vehicles here
    playerPos:set(be:getPlayerVehicle(0):getPosition())
  else
    playerPos = camPos
  end

  for id, data in pairs(trackedVehData) do
    local valid, pData = trackParking(id)
    data.parkingSpotId = pData.parkingSpotId
    data.parkingSpot = pData.parkingSpot

    if not valid then
      data.parkingTimer = 0
    end

    if pData.cornerCount >= 2 then -- at least two corners
      data.lastParkingSpotId = data.parkingSpotId
    end

    if not data.inside and pData.cornerCount > 0 then -- entered parking spot bounds
      data.inside = true
      data.event = "enter"
      extensions.hook("onVehicleParkingStatus", id, data)
    elseif data.inside and pData.cornerCount == 0 then -- exited parking spot bounds
      data.inside = false
      data.event = "exit"
      extensions.hook("onVehicleParkingStatus", id, data)
    end

    if data.lastParkingSpotId then
      if not data.parked and valid then
        data.parkingTimer = data.parkingTimer + dtSim
        if data.parkingTimer >= M.parkingDelay then -- valid parking (after a small delay)
          data.parked = true
          data.event = "valid"
          sites.parkingSpots.objects[data.lastParkingSpotId].vehId = id
          extensions.hook("onVehicleParkingStatus", id, data)

          if data.autoDisableTracking then
            disableTracking(id)
          end
        end
      elseif data.parked and not valid then -- invalid parking
        data.parked = false
        data.event = data.inside and "invalid" or "exit"
        sites.parkingSpots.objects[data.lastParkingSpotId].vehId = nil
        extensions.hook("onVehicleParkingStatus", id, data)
      end
    end
  end

  local parkedVehCount = #parkedVehIds
  if not parkedVehIds[1] or parkedVehCount >= parkingSpotsAmount then return end -- unable to teleport vehicles to new parking spots

  -- only search for parking spots whenever needed
  if focusPos:squaredDistance(camPos) >= square(stepDist) then
    -- consider using a smoother for the look direction, similar to the traffic system
    local aheadPos = camPos + camDirVec:z0():normalized() * (lookDist + stepDist) + camDirVec:cross(vec3(0, 0, 1)):z0():normalized() * random(-50, 50)
    currParkingSpots = findParkingSpots(aheadPos, 0, areaRadius)
    currParkingSpots = filterParkingSpots(currParkingSpots)
    focusPos = vec3(camPos)
    stepDist = clamp(lerp(stepDist, 50 - #currParkingSpots * 0.5, 0.5), 10, 50) -- smaller step distance if there are more parking spots

    for _, id in ipairs(parkedVehIds) do
      parkedVehData[id].searchFlag = false -- reset search flag for all vehicles
    end
  end

  -- cycle through array of parked vehicles one at a time, to save on performance
  local currId = parkedVehIds[queuedIndex]
  local currVeh = parkedVehData[currId]
  local obj = be:getObjectByID(currId or 0)
  if obj then
    local pos = obj:getPosition()
    local dtCoef = max(0.4, parkedVehCount * 0.1)
    currVeh.radiusCoef = lerp(currVeh.radiusCoef, clamp(80 / pos:distance(camPos + camDirVec * 15), 1, 6), dtSim * dtCoef) -- stronger value while player or camera is near target

    -- this feature may need more consideration
    if not currVeh.searchFlag and currParkingSpots[1] then
      local dirValue = max(0, camDirVec:dot((pos - camPos):normalized()) * areaRadius) -- higher value while looking at target vehicle
      if pos:squaredDistance(camPos) > square(areaRadius * currVeh.radiusCoef * 0.5 + dirValue) and pos:squaredDistance(playerPos) > square(areaRadius * 0.5) then
        local psCount = #currParkingSpots
        local startIdx = math.ceil(psCount * square(random())) -- bias towards lower start index, and therefore closest parking spots to target point
        for i = startIdx, psCount + startIdx - 1 do
          local idx = i % psCount
          if idx == 0 then idx = psCount end
          local ps = currParkingSpots[idx].ps
          -- consider using a static raycast
          if ps.pos:squaredDistance(camPos) > square(areaRadius * 0.5) and checkParkingSpot(currId, ps) then
            moveToParkingSpot(currId, ps)
            break
          end
        end
      end

      currVeh.searchFlag = true -- stop searching until next parking spot query
    end
  end

  queuedIndex = queuedIndex + 1
  if queuedIndex > parkedVehCount then
    queuedIndex = 1
  end

  if respawnTicks > 0 then
    respawnTicks = respawnTicks - 1 -- optimization to prevent rapid succession of respawning vehicles
  end
end

local function onClientStartMission()
  if not sites then
    worldLoaded = true
  end
end

local function onClientEndMission()
  resetAll()
  worldLoaded = false
end

local function onSerialize()
  local data = {active = active, debugLevel = debugLevel, parkedVehIds = deepcopy(parkedVehIds), trackedVehIds = tableKeys(trackedVehData), precision = M.precision, neatness = M.neatness, parkingDelay = M.parkingDelay}
  resetAll()
  return data
end

local function onDeserialized(data)
  worldLoaded = true
  processVehicles(data.parkedVehIds, true)
  for _, v in ipairs(data.trackedVehIds) do
    enableTracking(v)
  end
  active = data.active
  debugLevel = data.debugLevel
  M.precision = data.precision
  M.neatness = data.neatness
  M.parkingDelay = data.parkingDelay
end

-- public interface
M.setSites = setSites
M.setState = setState
M.getState = getState
M.setDebugLevel = setDebugLevel
M.setupVehicles = setupVehicles
M.processVehicles = processVehicles
M.deleteVehicles = deleteVehicles
M.getParkedCarsList = getParkedCarsList
M.getParkedCarsData = getParkedCarsData
M.enableTracking = enableTracking
M.disableTracking = disableTracking
M.resetAll = resetAll
M.getTrackingData = getTrackingData
M.getParkingSpots = getParkingSpots
M.findParkingSpots = findParkingSpots
M.filterParkingSpots = filterParkingSpots
M.checkParkingSpot = checkParkingSpot
M.moveToParkingSpot = moveToParkingSpot
M.scatterParkedCars = scatterParkedCars

M.onUpdate = onUpdate
M.onVehicleDestroyed = onVehicleDestroyed
M.onVehicleGroupSpawned = onVehicleGroupSpawned
M.onClientStartMission = onClientStartMission
M.onClientEndMission = onClientEndMission
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

return M