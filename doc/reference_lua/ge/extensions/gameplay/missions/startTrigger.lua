-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}


-- the required fields for start trigger types.
local startTriggerRequiredFields = {
  level = {'level'},
  coordinates = {'level','pos','radius'},
}

local function defaultLocationCheck(location, level, playerPosition, mission)

  return location.level == level and location.pos and location.radius and playerPosition:distance(location.pos) <= location.radius
end

local function defaultLocationDisplayMarker(location, playerPosition)
  local canBeStarted = true--gameplay_missions_missionManager.canBeStarted(mission)

  local color = {1,0,0,1}
  if playerPosition:distance(location.pos) < location.radius then color = canBeStarted and {0,1,0,1} or {0.5,0.5,0.5,1} end

  local posDown = location.pos + vec3(0,0,-2)
  local posUp = location.pos + vec3(0,0,0.25)
  local colorf = ColorF(0.3*color[1], 0.3*color[2], 0.3*color[3], 0.2)
  debugDrawer:drawCylinder(posDown, posUp, location.radius, colorf)

  local posUp = location.pos + vec3(0,0,5)
  local colorf = ColorF(0.6*color[1], 0.6*color[2], 0.6*color[3], 0.4)
  debugDrawer:drawCylinder(posDown, posUp, 0.4, colorf)

  posDown = posUp
  local posUp = location.pos + vec3(0,0,5)
  local colorf = ColorF(1.0*color[1], 1.0*color[2], 1.0*color[3], 1.0)
  debugDrawer:drawCylinder(posDown, posUp, 0.2, colorf)
end

M.defaultLocationCheck = defaultLocationCheck
M.defaultLocationDisplayMarker = defaultLocationDisplayMarker




  -- mission will always be active when you are in any of the specified levels.
local function levelTriggerList(trigger,locations)
  if type(trigger.level) == 'string' then
    table.insert(locations, {level=trigger.level, pos=nil, radius=nil, check=defaultLocationCheck, displayMarker=defaultLocationDisplayMarker})
  elseif type(trigger.level) == 'table' then
    for _, lvl in ipairs(trigger.level) do
      table.insert(locations, {level=lvl, pos=nil, radius=nil, check=defaultLocationCheck, displayMarker=defaultLocationDisplayMarker})
    end
  end
end

  -- mission can be accepted when you are at a specific point within one level.
local function coordinatesTriggerList(trigger,locations)
  table.insert(locations, {type='coordinates', level=trigger.level, pos=vec3(trigger.pos), rot=quat(trigger.rot or {0,0,0,1}), radius=trigger.radius, check=defaultLocationCheck, displayMarker=defaultLocationDisplayMarker})
end



-- the available start trigger types, with functions which will put locations for that mission into a the cache.
local startTriggerTypes = {
  level = levelTriggerList,
  coordinates = coordinatesTriggerList,
}

-- creates a list of locations from a start trigger.
local function parseMission(mission)
  local locations = {}
  local trigger = mission.startTrigger -- we can safely assume this exists because it is checked before this function is called
  if trigger.type and startTriggerTypes[trigger.type] then
    local requirementsMet = true
    local missingFields = {}
    for _, field in ipairs(startTriggerRequiredFields[trigger.type] or {}) do
      if trigger[field] == nil then
        requirementsMet = false
        table.insert(missingFields, field)
      end
    end
    if requirementsMet then
      startTriggerTypes[trigger.type](trigger, locations, mission)
      return locations, nil
    else
      return {}, "Missing fields for type " .. trigger.type .. ": " .. dumps(missingFields)
    end
  else
    return {}, "Type invalid: " .. dumps(trigger.type)
  end
end

-- merges all elements of a cluster into a location
local function merge(allClusters, cluster, mergeRadius)
  if #cluster == 1 then
    local c = cluster[1]
    table.insert(allClusters, {type='coordinates', level=c.level, pos=c.pos, rot=c.rot, radius=c.radius, check=defaultLocationCheck, displayMarker=defaultLocationDisplayMarker, missionIds = {c.missionId}, clusterId = c.missionId})
  else
    local missionIds = {}
    local weightedCenter = vec3()
    local sumRadii = 0
    local clusterId = ""
    for _, c in ipairs(cluster) do
      weightedCenter = weightedCenter + c.radius * c.pos
      sumRadii = sumRadii + c.radius
      missionIds[c.missionId] = true
      clusterId = clusterId .. c.missionId
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

    table.insert(allClusters, {type='coordinates', level=cluster[1].level, pos=newCenter, rot=cluster[1].rot, radius=radius, check=defaultLocationCheck, displayMarker=defaultLocationDisplayMarker, missionIds = tableKeys(missionIds), clusterId = clusterId})
  end
end


local function idSort(a,b) return a.id<b.id end
local quadtree = require('quadtree')
local missionClusterCacheByRadius = {}
local function getMissionClusters(mergeRadius)

  if not missionClusterCacheByRadius[mergeRadius or -1] then
    -- first get all mission locations, sorted in buckets by level
    local missions = gameplay_missions_missions.get()
    local locationsByLevel = {}
    for _, m in ipairs(missions) do
      local isVisible = true -- gameplay_missions_missionManager.isVisible(m)
      if isVisible then
        local locs = gameplay_missions_missions.getLocations(m)
        for i, l in ipairs(locs) do
          if l.type == 'coordinates' then
            l.id = m.id.."-"..i
            l.missionId = m.id
            locationsByLevel[l.level] = locationsByLevel[l.level] or {}
            table.insert(locationsByLevel[l.level], l)
          end
        end
      end
    end
    -- get the clusters for each level
    local allClusters = {}
    local cluster = {}
    for level, locations in pairs(locationsByLevel) do
      local qt = quadtree.newQuadtree()
      table.sort(locations, idSort)
      local count = 0
      for i, loc in ipairs(locations) do
        qt:preLoad(i, quadtree.pointBBox(loc.pos.x, loc.pos.y, (mergeRadius or loc.radius)))
        count = i
      end
      qt:build()
      -- go from the start to the end of the list
      for index = 1, count do
        local cur = locations[index]
        if cur then
          table.clear(cluster)
          -- find all the locations that potentially overlap with cur, and get all the ones that actually overlap into cluster list
          for id in qt:query(quadtree.pointBBox(cur.pos.x, cur.pos.y, mergeRadius or cur.radius)) do
            local candidate = locations[id]
            candidate._qtId = id
            if cur.pos:squaredDistance(candidate.pos) < square(cur.radius+(mergeRadius or candidate.radius)) then
              table.insert(cluster, candidate)
            end
          end
          -- remove all the elements in the cluster from the qt and the locations list
          for _, c in ipairs(cluster) do
            qt:remove(c._qtId, locations[c._qtId].pos.x, locations[c._qtId].pos.y)
            locations[c._qtId] = false
          end
          table.sort(cluster, idSort)
          merge(allClusters, cluster, mergeRadius)
        end
      end
    end
    missionClusterCacheByRadius[mergeRadius or -1] = allClusters
  end
  return missionClusterCacheByRadius[mergeRadius or -1]
end

M.onAnyMissionChanged = function() missionClusterCacheByRadius = {} end

M.getMissionClusters = getMissionClusters
M.parseMission = parseMission
return M
