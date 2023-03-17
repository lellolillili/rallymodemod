-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local quadtree = require('quadtree')
local missionClusterCacheByCacheId = {}
local quadtreeCacheByCacheId = {}
local allClustersCache = {}
local rawPoiListByLevel = {}
--local levelIdentifier

local function getClusterById(id)
  --return allClustersCache[id]
end

local function settingsToId(settings)
  return string.format("%0.2f-%s", settings.mergeRadius or 5, settings.levelIdentifier or "noLevel")
end

local function sanitizeSettings(settings)
  settings.mergeRadius = settings.mergeRadius or 5
  settings.levelIdentifier = settings.levelIdentifier or "noLevel"
  settings.id = settings.id or settingsToId(settings)

  return settings
end

local function getCacheIdBySettings(settings)
  if settings.id then return settings.id end
  sanitizeSettings(settings)
  return settingsToId(settings)
end

local function makeSettings(mergeRadius, levelIdentifier)
  return sanitizeSettings({mergeRadius = mergeRadius, levelIdentifier = levelIdentifier})
end

local function getClusterAsQuadtree(settings)
  settings = settings or {mergeRadius = nil, levelIdentifier = getCurrentLevelIdentifier()}
  sanitizeSettings(settings)
  local cacheId = getCacheIdBySettings(settings)
  if not quadtreeCacheByCacheId[cacheId] then
    local clusters = M.getAllClusters(settings)
    local clusterById = {}
    local qt = quadtree.newQuadtree()
    for _, cluster in ipairs(clusters) do
      qt:preLoad(cluster.clusterId, quadtree.pointBBox(cluster.pos.x, cluster.pos.y, cluster.radius))
      clusterById[cluster.clusterId] = cluster
    end
    qt:build()
    quadtreeCacheByCacheId[cacheId] = {
      quadtree = qt,
      clusterById = clusterById,
      ids = tableKeys(clusterById)
    }
  end
  return quadtreeCacheByCacheId[cacheId]
end


local function extractZoneData(zoneNames)
  local success = false
  local zones = {}
  local pos, radius = vec3(), 5
  local garageSites = gameplay_sites_sitesManager.getCurrentLevelSitesByName('garages')
  if garageSites and zoneNames then
    local aabb = {
      xMin = math.huge, xMax = -math.huge,
      yMin = math.huge, yMax = -math.huge,
      zMin = math.huge, zMax = -math.huge,
      invalid = true}
    for _, zoneName in ipairs(zoneNames or {}) do
      local zone = garageSites.zones.byName[zoneName]
      if zone and not zone.missing then
        table.insert(zones, zone)
        for i, v in ipairs(zone.vertices) do
          aabb.xMin = math.min(aabb.xMin, v.pos.x)
          aabb.xMax = math.max(aabb.xMax, v.pos.x)
          aabb.yMin = math.min(aabb.yMin, v.pos.y)
          aabb.yMax = math.max(aabb.yMax, v.pos.y)
          aabb.zMin = math.min(aabb.zMin, v.pos.z)
          aabb.zMax = math.max(aabb.zMax, v.pos.z)
          aabb.invalid = false
        end
      end
    end
    if not aabb.invalid then
      pos = vec3((aabb.xMin + aabb.xMax)/2, (aabb.yMin + aabb.yMax)/2, (aabb.zMin + aabb.zMax)/2)
      pos.z = core_terrain.getTerrainHeight(pos) or pos.z
      radius = math.sqrt(((aabb.xMax - aabb.xMin)/2) * ((aabb.xMax - aabb.xMin)/2) + ((aabb.yMax - aabb.yMin)/2) * ((aabb.yMax - aabb.yMin)/2))
      success =true
    end
  end
  return success, pos, radius, zones
end



local function getRawPoiListByLevel(levelIdentifier)
  if not rawPoiListByLevel[levelIdentifier] then
    local elements = {}
    -- first add all missions of the current level
    local missions = gameplay_missions_missions.get() or {}

    local locationsByLevel = {}
    for _, m in ipairs(missions) do

      local addToClustering = m.unlocks.startable and m.unlocks.visible
      if addToClustering then
        --dump("Adding to clustering: " .. m.id)
        --dumpz(m.unlocks, 2)
        local locs = gameplay_missions_missions.getLocations(m)

        for i, l in ipairs(locs) do
          if l.type == 'coordinates' then
            l.id = m.id..(#locs > 1 and ("-"..i) or '')
            l.missionId = m.id
            locationsByLevel[l.level] = locationsByLevel[l.level] or {}
            table.insert(locationsByLevel[l.level], l)
          end
        end
      end
    end
    for _, elem in ipairs(locationsByLevel[levelIdentifier] or {}) do
      table.insert(elements,  {
        id = elem.id,
        pos = elem.pos,
        rot = elem.rot,
        radius = elem.radius,
        data = { type = "mission", missionId = elem.missionId}
      })
    end

    local levelInfo = {}
    for _, level in ipairs(core_levels.getList()) do
      if string.lower(level.levelName) == string.lower(levelIdentifier) then
        levelInfo = level
      end
    end

    for i, spawnPoint in ipairs(levelInfo.spawnPoints or {}) do
      if spawnPoint.objectname then
        if not career_career.isCareerActive() or career_modules_spawnPoints.isSpawnPointDiscovered(levelInfo.levelName, spawnPoint.objectname) then
          local obj = scenetree.findObject(spawnPoint.objectname)
          if obj then
            local data = deepcopy(spawnPoint)
            data.type = "spawnPoint"
            data.id = data.objectname or ("spawnPoint-"..i)
            table.insert(elements,  {
              id = data.id,
              objectname = data.objectname,
              pos = obj:getPosition(),
              radius = 3,
              data = data
            })
          else
            log("W","","Could not find spawnpoint object! " .. dumps(spawnPoint.objectname))
          end
        end
      end
    end

    if career_career.isCareerActive() then
      for i, garagePoint in ipairs(levelInfo.garagePoints or {}) do
        local data = deepcopy(garagePoint)
        local success, pos, radius, zones = extractZoneData(data.zoneNames)
        if success then
          data.type = "garagePoint"
          data.id = data.id or ("garagePoint-"..i)
          table.insert(elements, {
            id = data.id,
            pos = pos,
            radius = radius,
            data = data,
            hasZones = next(zones) and true or false,
            zones = zones,
          })
        else
          log("W","","Could not load garage zone data! " .. dumps(garagePoint.id))
        end
      end
    end

    for i, gasStationPoint in ipairs(levelInfo.gasStationPoints or {}) do
      local data = deepcopy(gasStationPoint)
      local success, pos, radius, zones = extractZoneData(data.zoneNames)
      if success then
        data.type = "gasStationPoint"
        data.id = data.id or ("gasStationPoint-"..i)
        table.insert(elements, {
          id = data.id,
          pos = pos,
          radius = radius,
          data = data,
          hasZones = next(zones) and true or false,
          zones = zones,
        })
      else
        log("W","","Could not load gas station zone data! " .. dumps(gasStationPoint.id))
      end
    end
    rawPoiListByLevel[levelIdentifier] = elements
  end
  return rawPoiListByLevel[levelIdentifier]
end

local function getAllClusters(settings)
  settings = settings or {mergeRadius = nil, levelIdentifier = getCurrentLevelIdentifier()}
  sanitizeSettings(settings)
  local cacheId = getCacheIdBySettings(settings)
  if not missionClusterCacheByCacheId[cacheId] then
    -- first create a list of all elements we want to cluster
    local elements = settings.elements or deepcopy(M.getRawPoiListByLevel(settings.levelIdentifier))
    --log("E","","Getting new AllClusters: " .. settings.id)
    --dump(elements)
    missionClusterCacheByCacheId[cacheId] = M.getClusteredTransforms(elements, settings)
    --[[for _, cluster in ipairs(missionClusterCacheByCacheId[cacheId]) do
      allClustersCache[cluster.clusterId] = cluster
    end]]
  end
  return missionClusterCacheByCacheId[cacheId]
end

-- merges all elements of a cluster into a location
local function merge(allClusters, cluster, settings)
  --dump("mergeing:")
  --dump(cluster)
  if #cluster == 1 then
    local c = cluster[1]
    local hasType = {}
    hasType[c.data.type] = true
    local typeCount = {}
    typeCount[c.data.type] = 1

    local insert = {
      pos=c.pos,
      rot=c.rot,
      radius=c.radius,
      containedIds = {(c.data.type == "mission" and c.data.missionId) or c.id},
      containedIdsLookup = {[(c.data.type == "mission" and c.data.missionId) or c.id] = true},
      clusterId = settings.id..'#'..c.id,
      elemData = {c.data},
      hasType = hasType,
      typeCount = typeCount,

      hasZones = c.hasZones,
      zones = c.zones,
    }

    table.insert(allClusters, insert)
  else
    local elemIds = {}
    local elemIdsLookup = {}
    local weightedCenter = vec3()
    local sumRadii = 0
    local clusterId = ""
    local elemData = {}

    local hasType = {}
    local typeCount = {}
    local zoneSum = {}
    local firstRot = nil
    for i, c in ipairs(cluster) do
      weightedCenter = weightedCenter + c.radius * c.pos
      sumRadii = sumRadii + c.radius
      elemIds[i] = (c.data.type == "mission" and c.data.missionId) or c.id
      elemIdsLookup[(c.data.type == "mission" and c.data.missionId) or c.id] = true
      hasType[c.data.type] = true
      typeCount[c.data.type] = (typeCount[c.data.type] or 0) + 1
      clusterId = clusterId .. c.id
      firstRot = firstRot or c.rot
      for _, z in ipairs(cluster.zones or {}) do
        table.insert(zoneSum, z)
      end
      table.insert(elemData, c.data)
    end

    -- weighted center
    weightedCenter = weightedCenter / sumRadii
    local newCenter = vec3()
    local sumWeights = 0
    for _, c in ipairs(cluster) do
      local w = weightedCenter:distance(c.pos) + 1
      sumWeights = sumWeights + w
      newCenter = newCenter + w * c.pos
    end
    newCenter = newCenter / sumWeights

    local radius = 0
    for _, c in ipairs(cluster) do
      radius = math.max(radius, c.radius + newCenter:distance(c.pos))
    end
    radius = radius-1

    table.insert(allClusters, {
      pos=newCenter,
      rot=firstRot or quat(),
      radius=radius,
      containedIds = elemIds,
      containedIdsLookup = elemIdsLookup,
      clusterId = settings.id..'#'..clusterId,
      elemData = elemData,
      hasType = hasType,
      typeCount = typeCount,
      zones = zoneSum,
      hasZones = next(zoneSum) and true or false,
    })
  end
end


local function idSort(a,b) return a.id<b.id end

local function getClusteredTransforms(elementList, settings)
  -- elem = {id, pos, (rot), scl = radius, data/metadata = {missionData.../ spawnpointData...}}

  -- first get all mission locations, sorted in buckets by level
  -- get the clusters for each level
  local allClusters = {}
  local cluster = {}
  --dump(settings)
  --print(debug.tracesimple())

  local qt = quadtree.newQuadtree()
  table.sort(elementList, idSort)
  local count = 0
  for i, elem in ipairs(elementList) do
    qt:preLoad(i, quadtree.pointBBox(elem.pos.x, elem.pos.y, (settings.mergeRadius or elem.radius)))
    count = i
  end
  qt:build()
  -- go from the start to the end of the list
  for index = 1, count do
    local cur = elementList[index]
    if cur then
      table.clear(cluster)
      -- find all the elementList that potentially overlap with cur, and get all the ones that actually overlap into cluster list
      for id in qt:query(quadtree.pointBBox(cur.pos.x, cur.pos.y, settings.mergeRadius or cur.radius)) do
        local candidate = elementList[id]
        candidate._qtId = id
        if cur.pos:squaredDistance(candidate.pos) < square(cur.radius+(settings.mergeRadius or candidate.radius)) then
          table.insert(cluster, candidate)
        end
      end
      -- remove all the elements in the cluster from the qt and the locations list
      for _, c in ipairs(cluster) do
        qt:remove(c._qtId, elementList[c._qtId].pos.x, elementList[c._qtId].pos.y)
        elementList[c._qtId] = false
      end

      table.sort(cluster, idSort)
      merge(allClusters, cluster, settings)
    end
  end
  return allClusters
end



local iconPriority = { garagePoint = 1000, gasStationPoint = 100, spawnPoint = 10, mission = 1 }
local function sortIconByPrio(a,b) return iconPriority[a] > iconPriority[b] end
local function getIconNamesForCluster(cluster)
  local bigMapIconName = "mission_primary_01"
  local playModeIconName = nil
  if tableIsEmpty(cluster.elemData) then
    return playModeIconName, bigMapIconName
  end

  if tableSize(cluster.elemData) == 1 then
    -- sinlge-element cluster
    if cluster.hasType['garagePoint'] then
      bigMapIconName = "map_mission_garage"
      playModeIconName = "map_mission_garage"
    elseif cluster.hasType['gasStationPoint'] then
      bigMapIconName = "map_mission_fuelstation1"
      playModeIconName = "map_mission_fuelstation1"
    elseif cluster.hasType['spawnPoint'] then
      bigMapIconName = "poi_quicktravel"
    elseif cluster.hasType['mission'] then
      local mission = gameplay_missions_missions.getMissionById(cluster.elemData[1].missionId)
      playModeIconName = mission.bigMapIcon.icon
      bigMapIconName = mission.bigMapIcon.icon
    end
  else

    local iconTypes = tableKeys(cluster.hasType)
    table.sort(iconTypes, sortIconByPrio)
    if iconTypes[1] == 'mission' then
      -- if there's only missions, use that.
      bigMapIconName = "mission_primary_n" .. math.min(tableSize(cluster.elemData), 9)
      playModeIconName = bigMapIconName
    else
      if iconTypes[1] == 'garagePoint' or iconTypes[1] == 'gasStationPoint' then
        -- if there is a garagePoint, use that icon for bigmap and playmode.
        bigMapIconName = "poi_quicktravel_n" .. math.min(tableSize(cluster.elemData), 9) -- TODO: change to garage icon
        playModeIconName = "poi_quicktravel_n" .. math.min(tableSize(cluster.elemData), 9) -- TODO: change to garage icon
      elseif iconTypes[1] == 'spawnPoint' then
        -- if there is no garage but a spawnpoint, use that icon for bigmap.
        bigMapIconName = "poi_quicktravel_n" .. math.min(tableSize(cluster.elemData), 9)

        -- if there's any more missions, use that mission icon for playmode.
        if cluster.typeCount['mission'] > 1 then
          -- if there is more than 1 mission, use n+ icon
          playModeIconName = "mission_primary_n" .. math.min(cluster.typeCount['mission'], 9)
        else
          -- otherwise, find the first mission and use that icon.
          for _, elem in ipairs(cluster.elemData) do
            local mission = gameplay_missions_missions.getMissionById(elem.missionId)
            if mission then
              playModeIconName = mission.bigMapIcon.icon
            end
          end
        end
      end
    end
  end

  return playModeIconName, bigMapIconName
end

M.clearBySettings = function(settings)
  settings = settings or {mergeRadius = nil, levelIdentifier = getCurrentLevelIdentifier()}
  sanitizeSettings(settings)
  missionClusterCacheByCacheId[settings.id] = nil
  quadtreeCacheByCacheId[settings.id] = nil
end

local function onClientStartMission(levelPath)
  M.clear()
end

M.clear = function()
  log("D","","Cleared Clusteting.")
  missionClusterCacheByCacheId = {}
  quadtreeCacheByCacheId = {}
  allClustersCache = {}
  rawPoiListByLevel = {}
end

M.showMissionMarkersToggled = function(s) M.clear() end

M.getClusterById = getClusterById
M.getClusterAsQuadtree = getClusterAsQuadtree
M.getClusteredTransforms = getClusteredTransforms
M.getAllClusters = getAllClusters
M.getRawPoiListByLevel = getRawPoiListByLevel
M.onClientStartMission = onClientStartMission
M.getIconNamesForCluster = getIconNamesForCluster
return M
