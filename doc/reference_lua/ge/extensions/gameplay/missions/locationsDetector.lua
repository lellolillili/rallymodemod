-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local function defaultLocationCheck(location, level, playerPosition, mission)
  return location.pos and location.radius and playerPosition:distance(location.pos) <= location.radius
end

local function getMissionsAtLocation(level, playerPosition, nearbyLocations, accessible)
  local changed = false
  accessible = true -- keeping this for later, when we have bg activities again
  if p then p:add("getMissionsAtLocation") end
  for _, cluster in ipairs(gameplay_missions_clustering.getAllClusters(freeroam_bigMapMode.bigMapActive() and freeroam_bigMapMode.clusterMergeRadius)) do
    if defaultLocationCheck(cluster, level, playerPosition) then
      for i, mId in ipairs(cluster.containedIds) do
        table.insert(nearbyLocations.missions, {type = cluster.elemData[i].type, mission = gameplay_missions_missions.getMissionById(cluster.elemData[i].missionId), location = cluster, id = mId})
      end
    end
  end
  --[[
  for _,mission in ipairs(gameplay_missions_missions.get()) do
    local isNearby = false
    if accessible and gameplay_missions_missionManager.isVisible(mission) and not gameplay_missions_missionManager.isOngoing(mission) then
      for _,location in ipairs(gameplay_missions_missions.getLocations(mission)) do
        isNearby = location.check(location, level, playerPosition, mission)
      end
    end
    nearbyLocations.nearbyMissions = nearbyLocations.nearbyMissions or {}
    changed = changed or nearbyLocations.nearbyMissions[mission.id] ~= isNearby
    nearbyLocations.nearbyMissions[mission.id] = isNearby
    if isNearby then
      table.insert(nearbyLocations.missions, {type = 'mission', mission = mission, location = location, id = mission.id})
    end
  end
  ]]
  if p then p:add("Missions complete") end
  return changed
end

local nearbyLocations = { missions = {} }
local function getNearbyLocations(level, playerPosition)
  table.clear(nearbyLocations.missions)
  nearbyLocations.missionsChanged = false

  --local accessible = not gameplay_missions_missionManager.getForegroundMissionId()

  nearbyLocations.missionsChanged = getMissionsAtLocation(level, playerPosition, nearbyLocations, accessible)
  return nearbyLocations
end

M.onPoiTriggered = onPoiTriggered
M.getNearbyLocations = getNearbyLocations
M.isEnabled = isEnabled

return M
