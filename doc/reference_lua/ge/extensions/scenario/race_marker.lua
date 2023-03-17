-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
-- markerNames to list of indices
local markers = {}
local idToMarker = {}
local createMarker = require("scenario/raceMarkers/sideColumnMarker")
local markers_index = 0
local function getNewMarkerId() markers_index = markers_index+1 return markers_index end
local markerListName = 'markers'
local function hide(b)
  for _, m in pairs(idToMarker) do
    m:hide()
  end
end

local function createRaceMarker(detached, type)
  local cm = createMarker
  if type then cm = require("scenario/raceMarkers/"..type) end
  local marker = cm(getNewMarkerId())
  marker:createMarkers()
  if not detached then
    idToMarker[marker.id] = marker
  end
  return marker
end

-- removes all the markers and then removes the list.
local function clearMarkerList(name)
  --if not markers[name] then return end
  for id, marker in pairs(markers[name] or {}) do
    marker:clearMarkers()
  end
  idToMarker = {}
  markers[name] = nil
end

local function init()
  -- clear previous markers.
  clearMarkerList(markerListName)
  -- hide them in the beginning.
  hide(true)
end

local function setupMarkers(wps, marker)
  if marker then
    createMarker = require("scenario/raceMarkers/"..marker)
  else
    createMarker = require("scenario/raceMarkers/sideColumnMarker")
  end
  if not createMarker then
    createMarker = require("scenario/raceMarkers/sideColumnMarker")
  end
  clearMarkerList(markerListName)
  markers[markerListName] = {}
  for _, wp in ipairs(wps) do
    local marker = createRaceMarker()
    markers[markerListName][wp.name] = marker
    marker:createMarkers()
    marker:setToCheckpoint(wp)
  end
end

local function render(dt, dtSim)
   -- blend all markers.
  for _, m in pairs(idToMarker) do
    m:update(dt, dtSim)
  end
end

local function setModes(wpModes)
  for name, marker in pairs(markers[markerListName] or {}) do
    marker:setMode(wpModes[name] or 'hidden')
  end
end
local function setToCheckpoints(data)
  for name, marker in pairs(markers[markerListName] or {}) do
    if data[name] then
      marker:setToCheckpoint(data[name])
    end
  end
end

local function onClientEndMission()
  -- clear previous markers.
  clearMarkerList(markerListName)
end

M.onClientEndMission = onClientEndMission
M.init = init
M.render = render
M.hide = hide
M.setPosition = setPosition
M.setNextPosition = setNextPosition
M.setFinalMarkerPosition = setFinalMarkerPosition
M.setToCheckpoints = setToCheckpoints
M.removeFinalMarker = removeFinalMarker
M.createRaceMarker = createRaceMarker
M.setupMarkers = setupMarkers
M.setModes = setModes
M.idToMarker = idToMarker
return M
