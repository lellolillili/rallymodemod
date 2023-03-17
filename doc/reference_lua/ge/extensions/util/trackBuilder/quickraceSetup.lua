-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local simpleSplineTrack
local done = false

local function onScenarioLoaded(sc)
  if not done then
    simpleSplineTrack = extensions['util_trackBuilder_splineTrack']

    simpleSplineTrack.unloadAll()
    simpleSplineTrack.load(sc.track.customData.name, true, true, true)

    simpleSplineTrack.addCheckPointPositions(sc.track.reverse)
    simpleSplineTrack.positionVehicle(sc.track.reverse)
    done = true
  end
end

local function onClientStartMission()
  done = false
end

M.onClientStartMission = onClientStartMission
M.onScenarioLoaded = onScenarioLoaded
return M

