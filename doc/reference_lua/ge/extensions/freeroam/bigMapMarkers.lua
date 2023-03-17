-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}


local updateData = {}
local decals = {}
local visibleIds, visibleIdsSorted = {}, {}

local flatPoiList, poisById, poiIdList = nil, nil, nil
local clusterSettingsCounter = 0
local clusterSettingsById = {}
local currentClusterSettingsId = nil
local markersByClusterId = {}

local function buildPoiList()
  --log("E","","Building Poi List")
  flatPoiList = gameplay_missions_clustering.getRawPoiListByLevel(getCurrentLevelIdentifier())
  poisById = {}
  poiIdList = {}
  for i, elem in ipairs(flatPoiList) do
    poisById[elem.id] = elem
    poiIdList[i] = elem.id
  end
  M.clearFilters()
end

local function clearFilters()
  --log("E","","Clearing Filters.")
  for id, s in pairs(clusterSettingsById) do
    gameplay_missions_clustering.clearBySettings(s)
  end
  for _, marker in pairs(markersByClusterId) do
    marker:clearObjects()
  end
  markersByClusterId = {}
  clusterSettingsById = {}
  clusterSettingsCounter = 0
  currentClusterSettingsId = nil
end

local radiusStep = 5
local function setupFilter(validIds, mergeRadius)
  local elementsInFilter = {}
  --TODO: filter elements
  validIds = validIds or {}
  for i, id in ipairs(validIds) do
    elementsInFilter[i] = poisById[id]
  end

  if mergeRadius then
    mergeRadius = round(mergeRadius/radiusStep) * radiusStep
  else
    mergeRadius = 20
  end

  local settingsId = mergeRadius.."#-"
  table.sort(validIds)
  for _, e in ipairs(validIds) do
    settingsId = settingsId .. e
  end

  local clusterSettings = {mergeRadius = mergeRadius, elements = elementsInFilter, id = settingsId}
  clusterSettingsById[clusterSettings.id] = clusterSettings
  currentClusterSettingsId = clusterSettings.id
end


local function displayBigMapMarkers(dtReal)
  profilerPopEvent("BigMapMarkers parkingSpeedFactor")
  -- put reference for icon manager in
  updateData.dt = dtReal
  updateData.bigmapTransitionActive = freeroam_bigMapMode.isTransitionActive()
  updateData.camPos = getCameraPosition()

  local clusterSettingsIdsSorted = tableKeysSorted(clusterSettingsById)

  for _, csId in ipairs(clusterSettingsIdsSorted) do
    local clusterSettings = clusterSettingsById[csId]
    local isActiveSettings = clusterSettings.id == currentClusterSettingsId
    local clusters = gameplay_missions_clustering.getAllClusters(clusterSettings)
    for _, cluster in ipairs(clusters) do
      local marker = M.getClusterMarker(cluster)
      if marker then
        -- Check if the marker should be visible
        if isActiveSettings then
          marker:show()
        else
          marker:hide()
        end
        marker:update(updateData)
      end
    end
  end
end


local yVector = vec3(0,1,0)
local function pointRayDistance(point, rayPos, rayDir)
  return (point - rayPos):cross(rayDir):length() / rayDir:length()
end
local function handleMouse(camMode, uiPopupOpen, mouseMoved)
  local clusterIconRenderer = scenetree.findObject("markerIconRenderer")
  if not clusterIconRenderer then return end
  local ray
  if mouseMoved then
    ray = getCameraMouseRay()
  else
    local camDir = quat(getCameraQuat()) * yVector
    ray = {pos = getCameraPosition(), dir = camDir}
  end
  local clusterSettings = clusterSettingsById[currentClusterSettingsId]
  for i, cluster in ipairs(gameplay_missions_clustering.getAllClusters(clusterSettings)) do
    local iconInfo = clusterIconRenderer:getIconByName(cluster.clusterId .. "bigMap")

    if iconInfo then
      local iconPos = iconInfo.worldPosition
      local sphereRadius = iconPos:distance(getCameraPosition()) * 0.0006 * camMode.manualzoom.fov
      if not uiPopupOpen and pointRayDistance(iconPos, ray.pos, ray.dir) <= sphereRadius then
        return cluster.containedIds[1]
        --local marker = M.getClusterMarker(cluster)
        --if marker.visibleInBigmap then
        --  marker.hovered = true
        --return marker
        --end
      end
    end
  end
end

local function getIdsFromHoveredPoiId(id)
  local clusterSettings = clusterSettingsById[currentClusterSettingsId]
  for i, cluster in ipairs(gameplay_missions_clustering.getAllClusters(clusterSettings)) do
    if cluster.containedIdsLookup[id] then
      return cluster.containedIds
    end
  end
end


local function getClusterMarker(cluster)
  if not markersByClusterId[cluster.clusterId] then
    local marker = require('lua/ge/extensions/gameplay/missions/markers/bigmapMarker')()
    local playModeIconName, bigMapIconName = gameplay_missions_clustering.getIconNamesForCluster(cluster)
    marker:setup({pos = cluster.pos, radius = cluster.radius, clusterId = cluster.clusterId, bigMapIconName = bigMapIconName, cluster = cluster })
    markersByClusterId[cluster.clusterId] = marker
  end
  return markersByClusterId[cluster.clusterId]
end
M.displayBigMapMarkers = displayBigMapMarkers
M.handleMouse = handleMouse
M.getIdsFromHoveredPoiId = getIdsFromHoveredPoiId
M.getClusterMarker = getClusterMarker
M.setupFilter = setupFilter
M.clearFilters = clearFilters
M.buildPoiList = buildPoiList

return M
