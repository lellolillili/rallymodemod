-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {'gameplay_sites_sitesManager'}
local logTag = 'levelMetadata'
local vehGroupFieldName = 'vehicleGroup'
local prioFieldName = 'priority'
local suffixes = {'', '1', '2', '3', '4'} -- allow up to 5 groups per zone
local sites

local function getZonesByPrioForPosition(pos) -- returns a dict of zones that contain the position, and the highest priority value to use as a key
  local zonesByPrio = { [-math.huge] = {}}
  local highestPrio = -math.huge

  if not sites then return zonesByPrio, highestPrio end

  for _, zone in ipairs(sites:getZonesForPosition(pos)) do
    local prio = zone.customFields:get(prioFieldName) or 0
    zonesByPrio[prio] = zonesByPrio[prio] or {}
    table.insert(zonesByPrio[prio], zone)
    highestPrio = math.max(highestPrio, prio)
  end

  return zonesByPrio, highestPrio
end

local function getHighestPrioZone(pos) -- returns the first highest priority zone that contains the position
  local zonesByPrio, highestPrio = getZonesByPrioForPosition(pos)
  return zonesByPrio[highestPrio][1]
end

local function getMergedFieldsFromZones(pos, fieldName) -- returns an array of values from zone custom fields, given the position and field names
  if not pos or not fieldName then return {} end

  local fieldNameFiles = {}
  for _, zone in ipairs(getHighestPrioZone(pos)) do
    for _, suf in ipairs(suffixes) do
      if zone.customFields:has(fieldName..suf) then
        fieldNameFiles[zone.customFields:get(fieldName..suf)] = true -- ensures that results are unique
      end
    end
  end
  return tableKeysSorted(fieldNameFiles)
end

local function getRandomParkingSpots(minDist, startName) -- returns parking spot & zone names (start & destination) with a minimum distance
  -- startName is optional
  minDist = minDist or 300
  local spots = sites.parkingSpots
  local names = tableKeys(spots.byName)
  if not names[2] then -- needs at least two parking spots
    log('W', logTag, 'Minimum 2 parking spots needed to return a start and finish result!')
    return
  end

  -- randomize parkingspot names
  names = arrayShuffle(names)
  local nameA, nameB = names[1], names[2]
  if startName and spots.byName[startName] then
    nameA = startName
  end

  local pA, pB = spots.byName[nameA], spots.byName[nameB]
  local i = 2
  while nameB and pA.pos:distance(pB.pos) < minDist do
    pB = spots.byName[names[i]]
    nameB = names[i]
    i = i + 1
  end

  if not nameB then -- no destination beyond distance found
    log('W', logTag, 'No destination parking spot found within given distance')
    return
  end

  table.sort(pA.zones, function(a,b) return (a.customFields.values.priority or 0) > (b.customFields.values.priority or 0) end)
  table.sort(pB.zones, function(a,b) return (a.customFields.values.priority or 0) > (b.customFields.values.priority or 0) end)

  return nameA, nameB, pA.zones[1].name, pB.zones[1].name
end

local function loadSites(file)
  if not file then -- load default sites of map
    if sites then return end -- current site already exists

    local dir, filename, ext = path.split(getMissionFilename())
    if dir then
      file = dir.."city.sites.json"
    end
  end
  if not file then return end

  sites = gameplay_sites_sitesManager.loadSites(file)
end

local function getSites()
  return sites
end

local function reset()
  sites = nil
end

local function onClientStartMission(levelPath)
  reset()
end

local function onClientEndMission(levelPath)
  reset()
end

M.reset = reset
M.loadSites = loadSites
M.getSites = getSites
M.getZonesByPrioForPosition = getZonesByPrioForPosition
M.getHighestPrioZone = getHighestPrioZone
M.getMergedFieldsFromZones = getMergedFieldsFromZones
M.getRandomParkingSpots = getRandomParkingSpots

M.onClientStartMission = onClientStartMission
M.onClientEndMission = onClientEndMission

return M
