-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'simpleSplineTrack'
local version = "1.1"
--these two regulate the scaling of the track, though not the width oth scaling of the cross section.
local gridScale = 4
local heightScale = 1
local vectorScale = vec3(gridScale, gridScale, heightScale)
local pointsMultiplier = 6
--this creates the actual mesh from the track.
local mesher = require('util/trackBuilder/segmentToProceduralMesh')
local markers = require('util/trackBuilder/markers')
local pieceBuilder = require('util/trackBuilder/pieces')
local obstaclePlacer = require('util/trackBuilder/obstaclePlacer')
local transition = require('util/trackBuilder/cameraTransition')
local materialUtil = require('util/trackBuilder/materialUtil')
local merger = require('util/trackBuilder/multiTrackMerger')
merger.setReferences(mesher.getReferences())
pieceBuilder.splineTrack = M
--abstract info of the track pieces
local subPieces = {}
--more concrete info fo the track.
local subTracks = {{}}
local subTrackIndex = 1
local doSaveOnScreenshot = true
local intersections = {}
--currently selected track element marker
local trackMarker
local currentSelected = 1
local trackClosed = false
local currentCameraFocus = -1

-- cam settings
local camActivated = true
local camDistance = 80

-- if the track is high quality
local highQuality = true

-- if collision rebuilding should be ignored
local ignoreCollision = false

-- stack
local stackedPieces = {}
-- where the origin of the track is in the world.
local subTrackPositions = {{}}
-- whether the markers are shown or not.
local markersShown = true
-- default number of laps
local defaultLaps = 2
-- if the track is reversible
local reversible = false
local fixedCheckpoints = false

local environmentSettings = {
  timeOfDay = 0,
  fogDensity = 0
}
--[[
local history = {
  tracks = {},
  maxSteps = 16,
  currentIndex = 0,
  count = 0
}

local function saveHistory()
  local snapshot = M.exportTrackToTable()

  --shift history, forget oldest when maxSteps reached
  if history.currentIndex == maxSteps then
    for i = 1, history.maxSteps - 1 do
      history.tracks[i] = history.tracks[i + 1]
    end
  else
    history.currentIndex = history.currentIndex + 1
  end
  history.tracks[history.currentIndex] = snapshot
end

local function undo()
  history.currentIndex = history.currentIndex -1
  M.importTrackFromTable(history.tracks[history.currentIndex])
end
]]

local function createNewSubTrack(position, hdg)
  M.switchSubTrack(#subPieces+1)
  M.setTrackPosition(position.x/gridScale, position.y/gridScale ,position.z/heightScale, hdg, #subPieces)
  return #subPieces
end

local function switchSubTrack(index)
  --store current track
  subTrackIndex = index
  if subPieces[index] == nil then
    M.initTrack(true)
  end
end

local function removeSubTrack(index)
  -- cannot remove only subTrack (use remove track instead)
  if #subTracks == 1 then return end
  -- remove all stuff from subTrack
  subPieces[index] = {}
  for _,s in ipairs(subTracks[index]) do
    if not s.noPoints then
      s.mesh:delete()
    end
  end
  -- remove gap
  subTracks[index] = {}
  for i = index, #subTracks do
    subTracks[i] = subTracks[i+1]
    subPieces[i] = subPieces[i+1]
    subTrackPositions[i] = subTrackPositions[i+1]
    if subTracks[i] ~= nil then
      for s, seg in ipairs(subTracks[i]) do
        seg.index = s
        seg.subTrackIndex = i
        if not seg.noPoints then
          seg.mesh:setName('procMesh'..seg.subTrackIndex..'-'..seg.index)
        end
      end
    end
  end
  subTrackIndex = clamp(subTrackIndex,1,#subTracks)
  -- fix intersections
  local newInter = {}
  for i = 1, #intersections do
    local connected = false
    for _,s in ipairs(intersections[i].segments) do
      connected = connected or s.sub == index
    end
    if connected then
      intersections[i].obj:delete()
      intersections[i].obj = nil
    else
      for _,s in ipairs(intersections[i].segments) do
        if s.sub == index then
          s.sub = s.sub-1
        end
      end
      newInter[#newInter+1] = intersections[i]
    end
  end
  intersections = newInter

end

local function sortSegmentsForMultiTrack(segments)
  local centerP = vec3()
  for _,seg in ipairs(segments) do
    centerP = centerP +
      (seg.reverse and seg.segment.points[1].position or seg.segment.points[#seg.segment.points].position)
  end
  centerP = centerP * (1/#segments)
  table.sort(segments, function (a,b)
    local angleA =a.reverse and
      math.atan2((a.segment.points[1].position - centerP).x, (a.segment.points[1].position - centerP).y) or
      math.atan2((a.segment.points[#a.segment.points].position - centerP).x, (a.segment.points[#a.segment.points].position - centerP).y)

    local angleB =b.reverse and
      math.atan2((b.segment.points[1].position - centerP).x, (b.segment.points[1].position - centerP).y) or
      math.atan2((b.segment.points[#b.segment.points].position - centerP).x, (b.segment.points[#b.segment.points].position - centerP).y)
    return (angleA>angleB)
  end)
end

local function mergeMultiTrack(segments, centerMat, borderMat, borderMesh)
  sortSegmentsForMultiTrack(segments)
  local name = "procMerger"
  for _, seg in ipairs(segments) do
    name = name.."-"..(seg.reverse and 'r' or '')..seg.index.."x"..seg.sub
  end
  local inter = {
    segments = segments,
    centerMat = centerMat or segments[1].segment.materialInfo.centerMesh,
    borderMat = borderMat or segments[1].segment.materialInfo.rightMesh,
    borderMesh = borderMesh or segments[1].segment.rightMesh,
    name = name
  }
  inter.obj = merger.mergeMultiTrack(segments, inter.centerMat, inter.borderMat, inter.borderMesh)
  intersections[#intersections+1] = inter
end

local function getIntersectionIndexByName(name)
  for i,inter in ipairs(intersections) do
    if inter.name == name then return i end
  end
  return nil
end

local function removeIntersection(name)
  local index = getIntersectionIndexByName(name)
  intersections[index].obj:delete()
  for i = index, #intersections do
    intersections[i] = intersections[i+1]
  end
end

local function setIntersectionMaterial(name, center, border)
  local index = getIntersectionIndexByName(name)
  if not index then return end
  merger.setMaterials(intersections[index], center, border)
  intersections[index].centerMat = center or intersections[index].centerMat
  intersections[index].borderMat = border or intersections[index].borderMat
end

local function setIntersectionMesh(name, mesh)
  local index = getIntersectionIndexByName(name)
  if not index then return end
  if intersections[index].borderMesh  == mesh then return end
  intersections[index].borderMesh = mesh or intersections[index].borderMesh
  intersections[index].obj:delete()
  intersections[index].obj = merger.mergeMultiTrack(intersections[index].segments, intersections[index].centerMat, intersections[index].borderMat, intersections[index].borderMesh)
end

local function getIntersection(name)
  return intersections[getIntersectionIndexByName(name)]
end



----------------------------------------------
--helper and control functions for the app --
----------------------------------------------

-- helper function that places a checkpoint
local function makeCP(p, scenario, size, position, reverse)
  local rot = p.finalRot or p.rot
  local off = M.rotateVectorByQuat(vec3(0, reverse and - 1 or 1, 0), rot)
  local up = M.rotateVectorByQuat(vec3(0, 0, 1), rot)
  local num = #scenario.lapConfig
  local pos = position and rot:__mul(vec3(position.x, position.y, position.z)) or vec3(0, 0, 0)

  local position = (p.basePosition and vec3(p.basePosition) or vec3(p.position)) + vec3(0, 0, p.zOffset) + pos
  local scale = (size or p.width) / 2 + 1
  local quat = quatFromEuler(0, 0, -math.pi / 2):__mul(rot):toTorqueQuat()

  local checkPoint = createObject('BeamNGWaypoint')
  checkPoint:setPosition(position)
  checkPoint.scale = vec3(scale, scale, scale)
  checkPoint:setField('rotation', 0, quat.x .. ' ' ..quat.y..' '..quat.z..' '..quat.w)
  checkPoint:registerObject('gym_'..num)
  checkPoint:setField('directionalWaypoint', 0, '1')
  scenario.lapConfig[#scenario.lapConfig + 1] = 'gym_'..num

  -- TODO(TS): This can be removed once we do the clean up which makes scenario handle setting up its data after all 'extra' modules
  --           have had a chance to inject their own data and objects into the scene and/or scenario
  scenario.nodes['gym_'..num] = {}
  scenario.nodes['gym_'..num].pos = position
  scenario.nodes['gym_'..num].rot = off
  scenario.nodes['gym_'..num].up = up
  scenario.nodes['gym_'..num].radius = scale
end

--this function creates evenly spaced checkpoints, and adds them to the scenario etc.
local function addCheckPointPositions(reverse)
  if not reverse then reverse = false end

  local track = subTracks[subTrackIndex]
  local totalLength
  if not track[#track].noPoints then
    totalLength = track[#track].points[#track[#track].points].length
  else
    for i = #track, 1, -1 do
      if totalLength == nil then
        if not track[i].noPoints then
          totalLength = track[i].points[#track[i].points].length
        end
      end
    end
  end
  local cpCount = math.ceil(totalLength / 300)
  if cpCount < 3 then
    cpCount = 3
  end
  local dist = totalLength / cpCount
  local cur = dist - 1

  local scenario = scenario_scenarios.getScenario()
  scenario.lapConfig = {}
  scenario.nodes = {}

  local trackStart, trackEnd, trackStep
  local pointsStart, pointsEnd, pointsStep
  if reverse then
    cur = totalLength - cur
    dist = -dist
    trackStart = #track
    trackEnd = 1
    trackStep = -1
  else
    trackStart = 1
    trackEnd = #track
    trackStep = 1
  end
  local fixedCPs = fixedCheckpoints
  if not fixedCPs then
    for i = 2, #track - 1 do
      if track[i].hasCheckPoint then
        fixedCPs = true
      end
    end
  end
  if not fixedCPs then
    track[#track].hasCheckPoint = true
  end

  for i = trackStart, trackEnd, trackStep do
    local segment = track[i]
    if segment.points then
      if reverse then
        pointsStart = #segment.points
        pointsEnd = 1
        pointsStep = -1
      else
        pointsStart = 1
        pointsEnd = #segment.points
        pointsStep = 1
      end

      for j = pointsStart, pointsEnd, pointsStep do
        local p = segment.points[j]
        if (not fixedCPs and p.length > cur ~= reverse) then
          cur = cur + dist
          makeCP(p, scenario, segment.checkpointSize, segment.checkpointPosition, reverse)
        end
      end
    end
    if fixedCPs and segment.hasCheckPoint and i ~= trackStart then
      makeCP(segment.markerInfo, scenario, segment.checkpointSize, segment.checkpointPosition, reverse)
    end
    if fixedCPs and trackClosed and i == trackEnd and not segment.hasCheckPoint then
      makeCP(segment.markerInfo, scenario, segment.checkpointSize, segment.checkpointPosition, reverse)
    end
  end

  scenario.initialLapConfig = scenario.lapConfig
  scenario.BranchLapConfig = scenario.lapConfig
end

local function getAllCheckpoints()
  local ret = {}
  for i, segment in ipairs(subTracks[subTrackIndex]) do
    if segment.hasCheckPoint then
      ret[#ret + 1] = {
        segmentIndex = i,
        checkpointSize = segment.checkpointSize,
        checkpointPosition = segment.checkpointPosition
      }
    end
  end
  return ret
end

--places the players car at the beginning of the track.
local function positionVehicle(reverse, index)
  if not index then index = 1 end
  local point = subTracks[subTrackIndex][index]
  if not point then point = subTracks[subTrackIndex][1] end
  if reverse and not closed then
    point = subTracks[subTrackIndex][#subTracks[subTrackIndex]]
  end

  local rot = quatFromEuler(0, math.pi, math.pi):__mul(point.rot)
  if reverse then
    rot = rot:__mul(quatFromEuler(0, 0, math.pi))
  end

  local off = M.rotateVectorByQuat(vec3(0, -3, 0), rot)
  local pos = vec3(0, 0, 0.25) + point.markerInfo.position + off
  local scenario = scenario_scenarios
  if scenario then
    scenario = scenario.getScenario()
    scenario.startingTransforms['scenario_player0'].pos = pos
    scenario.startingTransforms['scenario_player0'].rot = rot
    vehicleSetPositionRotation(scenario.vehicleNameToId['scenario_player0'], pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
  else
    --dump(scenetree.findObject("thePlayer"))
    --dump(scenetree.findObject("thePlayer"):getID())
    --dump(be:getObjectByID(scenetree.findObject("thePlayer"):getID()))
    local id = scenetree.findObject("thePlayer"):getID()
    vehicleSetPositionRotation(id, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
  end
  if not ignoreCollision then
    be:reloadCollision()
  end
end

-- positions the track 15m in front of the camera. returs false if user is not in free camera mode
local function positionTrackBeforeCamera()

  if not commands.isFreeCamera() then
    return false
  end

  -- calculate position 5m in front of camera
  local cameraPosition = getCameraPosition()
  local position = M.rotateVectorByQuat(vec3(0, 15, 0), quat(getCameraQuat()))
  position = position + cameraPosition
  M.setTrackPosition(position.x / gridScale, position.y / gridScale, position.z)
  return true
end

--rotates the track so that it points into the direction the camera is looking. returs false if user is not in free camera mode
local function rotateTrackToCamera()
  if not commands.isFreeCamera() then
    return false
  end
  local trackPosition = subTrackPositions[subTrackIndex]
  local cameraLook = M.rotateVectorByQuat(vec3(0, 1, 0), quat(getCameraQuat()))
  local cameraAngle = (-math.atan2(cameraLook.y, -cameraLook.x) + math.pi / 2) * 180 / math.pi
  M.setTrackPosition(trackPosition.position.x, trackPosition.position.y, trackPosition.position.z, cameraAngle)
  return true
end

-- positions the track 15m above the player vehicle. returns false if there is no player vehicle
local function positionTrackAboveVehicle()
  local playerVehicle = be:getPlayerVehicle(0)
  if not playerVehicle then
    return false
  end

  local vehiclePos = playerVehicle:getPosition()
  M.setTrackPosition(vehiclePos.x / gridScale, vehiclePos.y / gridScale, vehiclePos.z + 15)
  return true
end

-- positions the track so it looks into the direction of the player vehicle. returns false if there is no player vehicle
local function rotateTrackToTrackVehicle()
  local playerVehicle = be:getPlayerVehicle(0)
  if not playerVehicle then
    return false
  end
  local trackPosition = subTrackPositions[subTrackIndex]
  local vehicleDir = playerVehicle:getDirectionVector()
  M.setTrackPosition(trackPosition.position.x, trackPosition.position.y, trackPosition.position.z, (-math.atan2(vehicleDir.y, -vehicleDir.x) + math.pi / 2) * 180 / math.pi)
  return true
end

--sets the values of the trackPosition field
local function setTrackPosition(x, y, z, hdg, sub)
  sub = sub or subTrackIndex
  local pieces = subPieces[sub]
  local trackPosition = subTrackPositions[sub]
  trackPosition.position = vec3(x, y, z)
  if hdg then
    hdg = (hdg / 180) * math.pi
    trackPosition.hdg = -hdg
    trackPosition.rot = quatFromEuler(0, 0, hdg)
  end
  -- rotated unit vectors for snapping points to a grid
  trackPosition.unitX = quatFromEuler(0, 0, trackPosition.hdg):__mul(vec3(1, 0, 0))
  trackPosition.unitY = quatFromEuler(0, 0, trackPosition.hdg):__mul(vec3(0, 1, 0))
  -- place and rotate the origin piece of the track and invalidate whole track
  pieces[1].position = vec3(x, y, z)
  pieces[1].hdg = trackPosition.hdg
  for i, p in ipairs(pieces) do
    M.invalidatePiece(i)
    p.invalid = true
  end
end

local function setDefaultLaps(laps)
  defaultLaps = laps
end

local function setReversible(rev)
  reversible = rev
end

--gets the values of the trackPosition field.
local function getTrackPosition()
  local trackPosition = subTrackPositions[subTrackIndex]
  return {
    x = trackPosition.position.x,
    y = trackPosition.position.y,
    z = trackPosition.position.z,
    hdg = trackPosition.hdg,
    unitX = trackPosition.unitX,
    unitY = trackPosition.unitY
  }
end

local function getAdditionalData()

end

local function getLastPieceWithMarker(markerName, lastIndex)
  for i = lastIndex or #track, 1, -1 do

    if subTracks[subTrackIndex][i][markerName] ~= nil then return subTracks[subTrackIndex][i] end
  end
  return nil
end

--gets the track table of one singular element thereof.
local function getPieceInfo(index, sub)
  sub = sub or subTrackIndex
  if index then
    return subPieces[sub][index]
  else
    return {
      pieces = subPieces[sub],
      highQuality = highQuality,
      showMarkers = markersShown,
      trackPosition = M.getTrackPosition(),
      currentSelected = currentSelected,
      trackClosed = trackClosed,
      defaultLaps = defaultLaps,
      reversible = reversible,
      subTrackIndex = subTrackIndex
    }
  end
end

local function getSegmentInfo(index, sub)
  sub = sub or subTrackIndex
  return subTracks[sub][index]
end

--sets the track to high quality or not.
local function setHighQuality(hq)
  highQuality = hq
  local quality = hq and 1 or 4
  -- mark all track pieces which a different quality than target quality to be refreshed
  for i = 1, #subTracks do
    for _, segment in ipairs(subTracks[i]) do
      if segment.quality ~= quality then
        segment.quality = quality
        segment.refreshMesh = true
        segment.timer = -1
      end
    end
  end
end
--[[ -- stack code might be removed at some point.
--stacks all the pieces up until the selected piece.
local function stackToCursor()
  M.stack(#pieces - currentSelected)
end

--stacks any number of pieces.
local function stack(count)
  if #pieces <= 2 then return end
  if not count then count = 1 end
  if count <= 0 then return end

  while count > 0 do
    stackedPieces[#stackedPieces + 1] = pieces[#pieces]
    M.revert()
    count = count - 1
    if #pieces <= 0 then
      count = 0
    end
  end
end

--applies any number of pieces from the stack, with the option to keep the stack.
local function applyStack(count, keep)
  if #stackedPieces == 0 then return end
  if not count then count = 1 end
  if count <= 0 then return end

  local to = #stackedPieces - count
  to = to + 1
  if to < 1 then to = 1 end
  for i = #stackedPieces, to, -1 do
    M.addPiece(M.deepcopy(stackedPieces[i]))
    M.invalidatePiece(#pieces)
    pieces[#pieces].fresh = false
    if not keep then
      stackedPieces[#stackedPieces] = nil
    end
  end
end

--helper copy function for stacking.
local function deepcopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in pairs(orig) do
      copy[orig_key] = orig_value
    end
  else --number, string, boolean, etc
    copy = orig
  end
  return copy
end

--gets number of stacked tiles.
local function getStackCount()
  return #stackedPieces
end

--clears the stack.
local function clearStack()
  stackedPieces = {}
end
]]
-- gets the track info the currently selected piece.
local function getSelectedTrackInfo()
  return subTracks[subTrackIndex][currentSelected]
end

----------------------
--marker functions --
----------------------

local function focusCameraOn(index, distance, force)
  if not force and currentCameraFocus == index then return end
  currentCameraFocus = index
  local tip = subTracks[subTrackIndex][index]
  if not tip then return end
  local cQ = getCameraQuat()
  local q = quat(cQ.x, cQ.y, cQ.z, cQ.w)

  local cameraLook = M.rotateVectorByQuat(vec3(0, 1, 0), quat(getCameraQuat()))
  local cameraAngle = (math.atan2(cameraLook.y, -cameraLook.x) - math.pi / 2)
  local cameraUp = math.acos(cameraLook.z) - math.pi / 2

  if cameraUp < math.pi / 4 then cameraUp = math.pi / 4 end
  q = quatFromEuler(cameraUp, 0, 0):__mul(quatFromEuler(0, 0, cameraAngle))

  transition.lerpTo(tip.markerInfo.position + q:__mul(vec3(0, -(distance or M.camDistance), 0)), q, 0.3)
end

local function unselectAll()
  for sub = 1, #subTracks do
    for i, segment in ipairs(subTracks[sub]) do
      if segment.selected then
        segment.selected = false
        segment.materialChanged = true
      end
    end
  end
end
-- this places the track marker on a track element by index.
local function focusMarkerOn(index, dontRefresMaterial, force)
  local tip = subTracks[subTrackIndex][index]
  if not tip then return end
  if not markersShown then
    M.showMarkers(true)
  end

  -- position track marker
  trackMarker:setPosition((subTracks[subTrackIndex][index].markerInfo.position))
  trackMarker:setScale(vec3(2, 2, 2))

  if M.camActivated then
    M.focusCameraOn(index, M.camDistance, force)
  end
  -- change materials of track
  if not dontRefresMaterial then
    for i, segment in ipairs(subTracks[subTrackIndex]) do
      if segment.mesh then
        if segment.selected then
          segment.selected = false
          segment.materialChanged = true
        end
        if i == index then
          segment.selected = true
          segment.materialChanged = true
        end
        if segment.materialChanged then
          --segment.mesh:updateMaterial()
          M.setSegmentMaterial(segment)
          segment.materialChanged = false
        end
      end
    end
  end
  -- set current index
  currentSelected = index
end

-- toggles visibility of markers on or off.
local function showMarkers(show)
  markersShown = show
  if show then
    M.createMarkers()
    M.focusMarkerOn(currentSelected)
  else
    for _, name in ipairs(markers.names) do
      markers.hideMarkers(name)
    end
    if trackMarker then
      trackMarker.scale = vec3(0, 0, 0)
    end
  end

end

-- changes all pieces to asphalt material

--creates and places all the neccesary markers.
local function createMarkers()
  --make the trackMarker visible/create
  if not trackMarker then
    trackMarker = createObject('TSStatic')
    trackMarker:setField('shapeName', 0, "art/shapes/interface/checkpoint_marker_sphere.dae")
    trackMarker:setPosition(vec3(0, 0, 0))
    trackMarker.scale = vec3(1, 1, 1)
    trackMarker:setField('rotation', 0, '0 0 1 0')
    trackMarker.useInstanceRenderData = true
    trackMarker:setField('instanceColor', 0, '1 1 1 1')
    trackMarker:setField('collisionType', 0, "Collision Mesh")
    trackMarker:setField('decalType', 0, "Collision Mesh")
    trackMarker:setField('playAmbient', 0, "1")
    trackMarker:setField('allowPlayerStep', 0, "1")
    trackMarker:setField('canSave', 0, "0")
    trackMarker:setField('canSaveDynamicFields', 0, "1")
    trackMarker:setField('renderNormals', 0, "0")
    trackMarker:setField('meshCulling', 0, "0")
    trackMarker:setField('originSort', 0, "0")
    trackMarker:setField('forceDetail', 0, "-1")
    trackMarker.canSave = false
    trackMarker:registerObject("track_marker")
    scenetree.MissionGroup:addObject(trackMarker)
  else
    trackMarker.scale = vec3(1, 1, 1)
  end

  for _, name in ipairs(markers.names) do
    markers.transformMarkers(name, subTracks)
  end

end

--change a marker of a piece, marks the piece as invalid
local function markerChange(type, index, value)
  if value == nil and index == 1 and (type == 'height' or type == 'width' or type == 'bank') then return end
  if index == nil then index = #subPieces[subTrackIndex] end
  -- donw allow checkpoints on first piece
  if index == 1 and type == 'checkpoint' then return end
  -- if changing the last piece while closed, update the first piece as well so it stays closed.
  local pieces = subPieces[subTrackIndex]

  if trackClosed and (index == 1 or index == #pieces) and value ~= nil and type ~= 'obstacles' then
    -- only change if there is actual change
    if pieces[1][type] ~= value then
      pieces[1][type] = value
      pieces[#pieces][type] = value
      M.invalidatePiece(1, type)
      M.invalidatePiece(#pieces, type)
    end
  else
    -- only change if there is actual change
    if pieces[index][type] ~= value then
      pieces[index][type] = value
      if type == 'obstacles' then
        pieces[index].obstaclesChanged = true
        if subTracks[subTrackIndex][index] then
          subTracks[subTrackIndex][index].obstaclesChanged = true
        end
      end
      M.invalidatePiece(index, type, value == nil)
    end
  end
end

-----------------------------
--track to mesh functions --
-----------------------------

local function setAllPiecesHighQuality()
  for i, segment in ipairs(subTracks[subTrackIndex]) do
    if segment.quality ~= 1 then
      segment.timer = 0
      segment.quality = 1
      if segment.points then
        mesher.materialize(segment, highQuality)
      end
      segment.fresh = false
      segment.refreshMesh = false
    end
  end
end

-- called every frame. when high quality is enabled, manages the timer on low quality track segments so they can be upgraded one after another.
local function onUpdate()
  if not subTracks[subTrackIndex] or not highQuality or not markersShown then return end
  -- fixed dTime means slower framerate causes slower update frequency
  local dTime = 0.01
  local segmentsToMake = {}
  for i, segment in ipairs(subTracks[subTrackIndex]) do
    if segment.timer and segment.timer > 0 and segment.quality ~= 1 then
      segment.timer = segment.timer - dTime
      if segment.timer <= 0 then
        segmentsToMake[#segmentsToMake + 1] = segment
      end
    end
  end

  for _, segment in ipairs(segmentsToMake) do
    if segment.points then
      segment.quality = 1
      mesher.materialize(segment, highQuality)
    end
    segment.fresh = false
    segment.refreshMesh = false
    if segment.selected then
      M.setSegmentMaterial(segment)
    end
  end
end

-- smooth slope interpolation, goes from 0/0 to 1/delta, having horizontal slope at 0 and 1
local function smoothSlope(t, delta)
  if t <= 0 then
    return 0, 0
  elseif t >= 1 then
    return delta, 0
  else
    return (3 - 2 * t) * delta * t * t, (6 - 6 * t) * delta * t
  end
end

-- smoother slope interpolation, goes from 0/0 to 1/delta, having horizontal slope at 0 and 1
local function smootherSlope(t, delta)
  if t <= 0 then
    return 0, 0
  elseif t >= 1 then
    return delta, 0
  else
    return delta * t * t * t * (t * (t * 6 - 15) + 10), delta * 30 * (t - 1) * (t - 1) * t * t
  end
end

local function refreshAllMaterials()
  for i = 1, #subTracks do
    for _, segment in ipairs(subTracks[i]) do
      if segment.materialChanged then
        M.setSegmentMaterial(segment)
        segment.materialChanged = false
      end
    end
  end
end

--makes an actual mesh from the track info.
local function makeTrack(instantHighQuality, ignoreCollision)
  --perf.enable(1)
  if #subPieces[subTrackIndex] == 0 then
    M.unloadAll()
    M.initTrack()
  end
  local track = subTracks[subTrackIndex]
  if instantHighQuality then
    for i, segment in ipairs(track) do
      M.invalidatePiece(i)
    end
  end

  --transform raw track data to actual track info
  M.toSegments()
  -- calculate bezier points or custom points of invalid pieces
  M.convertToSpline()
  -- meause lengths of track pieces for interpolation
  M.measureTrack()

  for i = 2, #track - 1 do
    track[i].meshInfo.forceEndCap = not instantHighQuality
    track[i + 1].meshInfo.forceStartCap = not instantHighQuality
    if instantHighQuality then
      if not track[i].noPoints then
        local hasCap = track[i].meshInfo.forceEndCap
        local addCap = track[i + 1].noPoints
        if hasCap ~= addCap then
          track[i].meshInfo.forceEndCap = addCap
          track[i].refreshMesh = true
        end
      end

      if not track[i + 1].noPoints then
        local hasCap = track[i + 1].meshInfo.forceStartCap
        local addCap = track[i].noPoints

        if hasCap ~= addCap then
          track[i + 1].meshInfo.forceStartCap = addCap
          track[i + 1].refreshMesh = true
        end
      end
    end

  end

  -- interpolate fields
  for _, name in ipairs(markers.names) do
    markers.interpolate(name, track)
  end
  if instantHighQuality then
    markers.caps(track, trackClosed)
  end

  if track[2].meshInfo.forceStartCap == trackClosed then
    track[2].meshInfo.forceStartCap = not trackClosed
    track[2].refreshMesh = true
  end
  if track[#track].meshInfo.forceEndCap == trackClosed then
    track[#track].meshInfo.forceEndCap = not trackClosed
    track[#track].refreshMesh = true
  end

  if M.ignoreCapsForMeshes then
    for i = 2, #track - 1 do
      track[i].meshInfo.forceEndCap = false
      track[i + 1].meshInfo.forceStartCap = false
    end
  end

  -- calculate texture position, final rotation for new points, also calculate position and rotation for markers
  for index, segment in ipairs(track) do
    segment.index = index
    segment.subTrackIndex = subTrackIndex
    if segment.points and segment.refreshMesh then
      for i, point in ipairs(segment.points) do
        point.uvY = point.length
        point.finalRot = quatFromEuler(
          point.pitch,
          -(point.bank / 180) * math.pi + math.pi,
        0)
        :__mul(point.rot)
      end
    end

    segment.markerInfo.rot = quatFromEuler(
      segment.markerInfo.pitch,
      (-segment.markerInfo.bank / 180) * math.pi + math.pi,
    0):__mul(quatFromEuler(0, math.pi, segment.hdg))
    segment.markerInfo.position = segment.markerInfo.basePosition + vec3(0, 0, segment.markerInfo.zOffset)
    segment.invalid = false
  end

  -- update all the meshes that need updating
  local timer = 0.25
  for i, segment in ipairs(track) do
    if segment.refreshMesh or (segment.quality ~= 1 and instantHighQuality) then
      if segment.points then
        if instantHighQuality then
          segment.timer = -1
          segment.quality = 1
        elseif highQuality then
          segment.timer = timer
          timer = timer + 0.1
          segment.quality = 4
        end
        mesher.materialize(segment)
        segment.obstaclesChanged = true
      end
      segment.fresh = false
      segment.refreshMesh = false
    end
    -- set material for currently selected track piece accordingly
    if segment.mesh and currentSelected == i and not instantHighQuality then
      M.setSegmentMaterial(segment, "track_editor_grid")
    end
    -- update material of all segments which material has changed
    if segment.materialChanged then
      M.setSegmentMaterial(segment)
      segment.materialChanged = false
    end
  end

  -- create/position markers if neccesary
  if markersShown then
    M.createMarkers()
  end
  obstaclePlacer.placeObstacles(track)
  --perf.disable()
  --perf.saveDataToCSV('splineTrackPerf.csv')
  -- only refresh collision if the whole track would be updated (like on drive button or quickrace.)
  -- reload collision takes a lot of time on bigger maps

  if instantHighQuality then
    if not ignoreCollision then
      be:reloadCollision()
    end
  end
end

local function setMaterial(index, sub, field, material, fill)
  sub = sub or subTrackIndex
  local track = subTracks[sub]
  local pieces = subPieces[sub]
  if index < 1 or index > #track then return false end
  local originalMaterial = track[index].materialInfo[field]
  if originalMaterial == material then return false end
  if track[index].materialInfo[field] ~= material or pieces[index].materialInfo[field] ~= material then
    pieces[index].materialInfo[field] = material
    track[index].materialInfo[field] = material
    track[index].materialChanged = true
  end

  if fill then
    local found = false
    for i = index + 1, #track do
      if not found and (track[i].materialInfo[field] == originalMaterial or pieces[i].materialInfo[field] == originalMaterial) then
        pieces[i].materialInfo[field] = material
        track[i].materialInfo[field] = material
        track[i].materialChanged = true
      else
        found = true
      end
    end
    found = false
    for i = index - 1, 1, -1 do
      if not found and (track[i].materialInfo[field] == originalMaterial or pieces[i].materialInfo[field] == originalMaterial) then
        pieces[i].materialInfo[field] = material
        track[i].materialInfo[field] = material
        track[i].materialChanged = true
      else
        found = true
      end
    end
  end
  return true
end

local function setMesh(index, field, mesh, fill)
  local track = subTracks[subTrackIndex]
  local pieces = subPieces[subTrackIndex]
  if index < 1 or index > #track then return false end
  local originalMesh = track[index][field]
  if originalMesh == mesh then return false end
  local max, min = -1, -1
  if track[index][field] ~= mesh or pieces[index][field] ~= mesh then
    pieces[index][field] = mesh
    track[index][field] = mesh
    track[index].refreshMesh = true
    max = index + 1
    min = index - 1
  end

  if fill then
    local found = false
    for i = index + 1, #track do
      if not found and track[i][field] == originalMesh and pieces[i][field] == originalMesh then
        pieces[i][field] = mesh
        track[i][field] = mesh
        track[i].refreshMesh = true
      else
        found = true
      end
    end
    found = false
    for i = index - 1, 1, -1 do
      if not found and track[i][field] == originalMesh and pieces[i][field] == originalMesh then
        pieces[i][field] = mesh
        track[i][field] = mesh
        track[i].refreshMesh = true
      else
        found = true
      end
    end
  end

  -- if track[max] then track[max].refreshMesh = true end
  -- if track[min] then track[min].refreshMesh = true end
  return true
end

-- sets the material of a segment and marks it for updating if the material actually changed
local function setSegmentMaterial(segment)
  if segment.noPoints then return end
  for name, index in pairs(segment.submeshIndexes) do
    segment.mesh:setMaterial(index, segment.selected and 'track_editor_grid' or segment.materialInfo[name])
  end
end

-- snaps a given point to the triangular grid, using the unit vectors in the trackPosition field.
local function snapToGrid(point)
  local trackPosition = subTrackPositions[subTrackIndex]
  local adjustedPoint = point - trackPosition.position
  local intX = adjustedPoint:dot(trackPosition.unitX) / (math.sqrt(3) / 2)
  local intY = adjustedPoint:dot(trackPosition.unitY) / 0.5
  local originalZ = adjustedPoint.z
  intX = round(intX)
  intY = round(intY)

  adjustedPoint:set(intX * (math.sqrt(3) / 2) * trackPosition.unitX + intY * 0.5 * trackPosition.unitY)
  adjustedPoint.z = originalZ
  return adjustedPoint + trackPosition.position
end

local function addClosingPiece()
  if trackClosed then return end
  local track = subTracks[subTrackIndex]
  local pieces = subPieces[subTrackIndex]
  local dist = (vec3(track[1].markerInfo.position)
  -vec3(track[#track].markerInfo.position)):length()
  M.addPiece({piece = 'freeBezier', xOff = 0, yOff = 0, dirOff = 0, absolute = true, forwardLen = dist / 16, backwardLen = dist / 16, empty = false})
  trackClosed = true
  markerChange('bank', #pieces, {value = pieces[1].bank.value, interpolation = 'smoothSlope'})
  markerChange('width', #pieces, {value = pieces[1].width.value, interpolation = 'smoothSlope'})
  markerChange('height', #pieces, {value = pieces[1].height.value, interpolation = 'smoothSlope'})
  pieces[#pieces].fresh = false
  M.invalidatePiece(#pieces)
  if #pieces > 1 then
    M.invalidatePiece(#pieces - 1)
  end
end

-- goes through all segments and calculates the points and other infos for them.
local function convertToSpline()
  local track = subTracks[subTrackIndex]
  -- go through all segments that are invalid and update them.
  for i, segment in ipairs(track) do
    if segment.invalid then
      segment.rot = quatFromEuler(math.pi, 0, 0):__mul(quatFromEuler(0, 0, segment.hdg + math.pi))
      --segment.material = "track_editor_base"

      -- snap end points of the segment
      if segment.origin then
        --M.snapToGrid(segment.origin)
      end
      if segment.position then
        --M.snapToGrid(segment.position)
      end

      -- if this segment has points, either by custom points or bezier points, calculate them
      if not segment.noPoints then
        segment.quality = highQuality and 1 or 4
        -- actually calculate the points
        if segment.pointsType == 'bezier' then
          segment.points = M.getBezierPoints(segment)
        elseif segment.pointsType == 'custom' then
          segment.points = M.calculateCustomPoints(segment)
        elseif segment.pointsType == 'arc' then
          segment.points = M.getArcPoints(segment)
        end
        -- make sure that the first and last point are always part ot the mesh
        segment.points[1].quality = {true, true, true, true}
        segment.points[#segment.points].quality = {true, true, true, true}

        -- markerInfo position to last point position
        segment.markerInfo.basePosition = vec3(segment.points[#segment.points].position)
        segment.markerInfo.basePosition = vec3(segment.position):componentMul(vectorScale)
      else
        segment.markerInfo.basePosition = vec3(segment.position):componentMul(vectorScale)
      end
      -- in any case, mesh should be refreshed.
      segment.refreshMesh = true
      segment.hasStartCap = false
      segment.hasEndCap = false
    end
  end

  -- figure out if the track is closed or not
  local lastHeight = 0
  for i = 1, #track do
    if track[i].height ~= nil then
      lastHeight = track[i].height.value
    end
  end

  trackClosed =
  math.abs(track[1].position.x - track[#track].position.x) < 0.1
  and math.abs(track[1].position.y - track[#track].position.y) < 0.1
  --and math.abs(track[1].hdg%math.pi - track[#track].hdg%math.pi) < 0.1
  and math.abs((track[1].height.value + track[1].position.z) - (lastHeight + track[#track].position.z)) < 0.1

  --  if trackClosed then
  --  track[#track].bank = track[1].bank
  --  track[#track].width = track[1].width
  --end
end

local function getArcPoints(segment)
  local points = {}

  local numPoints = segment.polyMult * pointsMultiplier
  if numPoints > 300 then
    numPoints = 300
  end
  numPoints = numPoints - numPoints % 1
  local arcCenter = (segment.position + vec3(-math.sin((segment.hdg - segment.direction * math.pi / 2)), -math.cos((segment.hdg - segment.direction * math.pi / 2)), 0) * math.abs(segment.radius)):componentMul(vectorScale)
  for i = 0, numPoints do
    local t = (i / numPoints)
    local angle = (1 - t) * segment.direction * segment.angle - segment.hdg + (0.5 * segment.direction + 0.5) * math.pi

    -- calculate the angle of the spline directly from the first derivative
    local hdg = angle - (segment.direction * math.pi / 2)

    -- these fields will only be set for points that directly correspond to an original control point.
    -- quality of 4 means that only every 4th point will be in the mesh etc
    local quality = {}
    for q = 1, 4 do
      quality[q] = i % q == 0
    end

    -- fill in the fields.
    points[i + 1] = {
      position = arcCenter + vec3(math.cos(angle), math.sin(angle), 0) * segment.radius * gridScale,
      rot = quatFromEuler(math.pi, 0, 0):__mul(quatFromEuler(0, 0, -hdg - math.pi / 2)),
      quality = quality
    }
  end
  return points
end

-- calculates points on a bezier curve
local function getBezierPoints(segment)
  local bezierPoints = {}

  -- get the control points scaled up by the grid size
  local p0 = segment.origin:componentMul(vectorScale)
  local p3 = segment.position:componentMul(vectorScale)
  local p1 = segment.controlPointA:componentMul(vectorScale) + p0
  local p2 = segment.controlPointB:componentMul(vectorScale) + p3

  -- calculate number of points
  local numPoints = pointsMultiplier * segment.polyMult

  -- cap number of points with 300 and make it to integer
  if numPoints > 300 then
    numPoints = 300
  end
  numPoints = numPoints - numPoints % 1

  for i = 0, numPoints do
    local t = i / numPoints

    -- calculate the weights for each point.
    local t0 = math.pow(1 - t, 3)
    local t1 = 3 * (t - 2 * t * t + t * t * t)
    local t2 = 3 * (t * t - t * t * t)
    local t3 = t * t * t

    -- calculate the weights for the first derivative.
    local d0 = -3 * (1 - t) * (1 - t)
    local d1 = (3 * (1 - t) * (1 - t) - 6 * (1 - t) * t)
    local d2 = (6 * (1 - t) * t - 3 * t * t)
    local d3 = 3 * t * t

    -- calculate the angle of the spline directly from the first derivative
    local hdg = math.atan2(d0 * p0.y + d1 * p1.y + d2 * p2.y + d3 * p3.y, d0 * p0.x + d1 * p1.x + d2 * p2.x + d3 * p3.x)

    -- these fields will only be set for points that directly correspond to an original control point.
    -- quality of 4 means that only every 4th point will be in the mesh etc
    local quality = {}
    for q = 1, 4 do
      quality[q] = i % q == 0
    end

    -- fill in the fields.
    bezierPoints[i + 1] = {
      position = t0 * p0 + t1 * p1 + t2 * p2 + t3 * p3,
      rot = quatFromEuler(math.pi, 0, 0):__mul(quatFromEuler(0, 0, -hdg - math.pi / 2)),
      quality = quality
    }
  end
  return bezierPoints
end

--scales and rotated custom points of a piece.
local function calculateCustomPoints(piece)
  if not piece.customPoints then
    return nil
  end

  local xUnitVector = vec3(math.cos(piece.hdg), -math.sin(piece.hdg), 0)
  local yUnitVector = vec3(math.sin(piece.hdg), math.cos(piece.hdg), 0)

  local points = {}
  for i, p in ipairs(piece.customPoints) do
    local newP = {
      position = vec3(
        (piece.position.x + p.position.x * xUnitVector.x + p.position.y * yUnitVector.x) * gridScale,
        (piece.position.y + p.position.x * xUnitVector.y + p.position.y * yUnitVector.y) * gridScale,
        (piece.position.z + p.position.z) * heightScale
      ),
      rot = p.rot:__mul(quatFromEuler(math.pi, 0, 0):__mul(quatFromEuler(0, 0, piece.hdg + math.pi))),
    quality = {}}
    for q = 1, 4 do
      newP.quality[q] = i % q == 0
    end

    points[#points + 1] = newP
  end
  return points
end

-- measures the length of the track
local function measureTrack()
  -- measure only from the last invalid piece
  local length = 0
  local track = subTracks[subTrackIndex]
  for i = 1, #track do
    if not track[i].invalid then
      length = track[i].endLength
    end
  end
  -- start actually measuring the length
  for i, segment in ipairs(track) do
    if segment.invalid then
      segment.startLength = length
      if segment.points then
        for pointIndex = 1, #segment.points - 1 do
          segment.points[pointIndex].length = length
          length = length + (segment.points[pointIndex].position - segment.points[pointIndex + 1].position):length()
        end
        segment.points[#segment.points].length = length
      end
      segment.endLength = length
    end
  end
end

--marks a piece to be invalidated later, either in general or for a specific type.
local function invalidatePiece(index, types, force)
  if not types then
    types = markers.names
  else
    types = {types}
  end
  for _, t in ipairs(types) do
    markers.addMarkerChange(t, index)
  end
end

--takes the low-level info stored in the pieces-field, and creates the bezier segments or custom point arrays out of it.
local function toSegments()
  local track = subTracks[subTrackIndex]
  local pieces = subPieces[subTrackIndex]
  for i = #pieces, 1, -1 do
    if pieces[i].invalid and track[i] then
      if track[i].mesh then
        track[i].mesh:delete()
      end
      if track[i].procObstacles then
        for _,o in ipairs(track[i].procObstacles) do
          o:delete()
        end
      end
      track[i] = nil
      pieces[i].fresh = true
      --M.invalidatePiece(i)
    end
  end
  --recreate track piece by piece and add infos such as width, height and bank.
  local tip
  for i, p in ipairs(pieces) do
    if p.invalid or track[i] == nil then

      track[i] = pieceBuilder.toSegment(p, tip)
      track[i].index = i
      track[i].parameters = p
      track[i].invalid = true
      track[i].fresh = p.fresh
      track[i].obstaclesChanged = true--p.obstaclesChanged
      p.fresh = false
      p.invalid = false
      track[i].markerInfo = {
        basePosition = vec3(),
        position = vec3(),
        zOffset = 0
      }
      track[i].materialInfo = {
        centerMesh = p.materialInfo.centerMesh or 'track_editor_A_center',
        leftMesh = p.materialInfo.leftMesh or'track_editor_A_border',
        rightMesh = p.materialInfo.rightMesh or'track_editor_A_border',
        leftWall = p.materialInfo.leftWall or'track_editor_A_border',
        rightWall = p.materialInfo.rightWall or'track_editor_A_border',
        ceilingMesh = p.materialInfo.ceilingMesh or'track_editor_A_center'
      }
      track[i].centerMesh = p.centerMesh or 'regular'
      track[i].leftMesh = p.leftMesh or 'regular'
      track[i].rightMesh = p.rightMesh or 'regular'
      track[i].meshInfo = {
        leftWall = {
          active = nil,
          value = nil,
          startCap = false,
          endCap = false
        },
        rightWall = {
          active = nil,
          value = nil,
          startCap = false,
          endCap = false
        },
        ceilingMesh = {
          active = nil,
          value = nil,
          startCap = false,
          endCap = false
        },
        leftMesh = {
          startCap = false,
          endCap = false
        },
        centerMesh = {
          startCap = false,
          endCap = false
        },
        rightMesh = {
          startCap = false,
          endCap = false
        },
        forceStartCap = false,
        forceEndCap = false
      }
      for _, name in ipairs(markers.names) do
        track[i].markerInfo[name] = p[name]
      end
    end
    for _, name in ipairs(markers.names) do
      track[i][name] = p[name]
    end
    track[i].obstacles = p.obstacles
    --track[i].hasCheckPoint = p.hasCheckPoint
    tip = track[i]
  end

end

----------------------------
--track editor functions --
----------------------------

--initializes the track.
local function initTrack(noUnload)
  if not noUnload then
    M.unloadAll()
  end

  local materialInfo = {
    centerMesh = 'track_editor_A_center',
    leftMesh = 'track_editor_A_border',
    rightMesh = 'track_editor_A_border',
    leftWall = 'track_editor_A_border',
    rightWall = 'track_editor_A_border',
    ceilingMesh = 'track_editor_A_center'
  }
  if core_levels.getLevelName(getMissionFilename()) == 'glow_city' then
    materialInfo = {
      centerMesh = 'track_editor_G_center',
      leftMesh = 'track_editor_G_border',
      rightMesh = 'track_editor_G_border',
      leftWall = 'track_editor_G_border',
      rightWall = 'track_editor_G_border',
      ceilingMesh = 'track_editor_G_center'
    }
  end
  subPieces[subTrackIndex] = {
    {
      piece = "init",
      position = vec3(0, 0, 0),
      bank = {value = 0, interpolation = "smoothSlope"},
      height = {value = 0, interpolation = "smoothSlope"},
      width = {value = 10, interpolation = "smoothSlope"},
      centerMesh = "regular",
      leftMesh = "regular",
      rightMesh = "regular",
      materialInfo = materialInfo,
      fresh = true
    }
  }
  subTracks[subTrackIndex] = {}
  -- initial track position
  subTrackPositions[subTrackIndex] = {
    position = vec3(),
    hdg = 0
  }
  -- position track before camera, above vehicle or at origin, depending on availability
  if core_levels.getLevelName(getMissionFilename()) == 'glow_city' then
    M.setTrackPosition(50, -50, 250)
  elseif M.positionTrackBeforeCamera() then
    M.rotateTrackToCamera()
  elseif M.positionTrackAboveVehicle() then
    M.rotateTrackToTrackVehicle()
  else
    M.setTrackPosition(0, 0, 15, 0)
  end
  -- add an initial piece
  M.addForward(3)
end

--clears all the fields.
local function unloadAll()
  subTracks = {{}}
  subPieces = {{}}
  intersections = {}
--  stackedPieces = {}
  trackMarker = nil
  highQuality = true
  markersShown = false
  markers.unloadAll()
  obstaclePlacer.clearReferences()
  if not ignoreCollision then
    be:reloadCollision()
  end
end

--removes the whole track, incl. meshes and markers.
local function removeTrack()
  M.showMarkers(false)
  for s,track in ipairs(subTracks) do
    if track then
      for _, segment in ipairs(track) do
        if segment.mesh then
          segment.mesh:delete()
        end
        if segment.procObstacles then
          for _,o in ipairs(segment.procObstacles) do
            o:delete()
          end
        end
      end
    end
  end
  for _, name in ipairs(markers.names) do
    markers.clearMarkers(name)
  end
  for _,i in ipairs(intersections) do
    i.obj:delete()
  end
  subTracks = {{}}
  subPieces = {{}}
  subTrackIndex = 1
  if not ignoreCollision then
    be:reloadCollision()
  end
end

--returns the last track piece
local function getEndOfTrack()
  return subTracks[subTrackIndex][#subTracks[subTrackIndex]]
end

--destroys the last track element (minimum of two elements remain, because only one element makes no track)
local function revert()
  M.removeAt(#subPieces[subTrackIndex])
end

--removes a piece at a position.
local function removeAt(index)
  local pieces = subPieces[subTrackIndex]
  if #pieces <= 2 or index <= 2 then
    return
  end

  if index < #pieces then
    for i = index, #pieces do
      pieces[i].invalid = true
    end
  end

  --M.invalidatePiece(index-1)
  local existingMarkers = {}
  for i = index, #pieces do
    for _, name in ipairs(markers.names) do
      if pieces[i][name] ~= nil then
        existingMarkers[name] = true
      end
    end
  end

  for _, name in ipairs(markers.names) do
    if pieces[index][name] ~= nil then
      M.invalidatePiece(index - 1, name)
    end
  end
  for i = index, #pieces - 1 do
    pieces[i].invalid = true
    pieces[i] = pieces[i + 1]
    for _, name in ipairs(markers.names) do
      if existingMarkers[name] then
        M.invalidatePiece(i, name)
      end
    end
  end

  pieces[#pieces] = nil
  local track = subTracks[subTrackIndex]
  if track[#track].mesh ~= nil then
    track[#track].mesh:delete()
    track[#track].mesh = nil
  end
  if track[#track].procObstacles then
    for _,o in ipairs(track[#track].procObstacles) do
      o:delete()
    end
  end
  track[#track] = nil

end

--these functions add pieces to the low-level track info stored in pieces.
--adding new types pieces need to be put in:
-- here
-- function to calculate their points
-- function toSegments => call own function with params
-- trackbuilder.js: piece information, parameters
-- trackbuilder.js: getSelectedTrackElementData
local function addForward(len, index, replace) M.addPiece({piece = 'freeForward', length = len}, index, replace) end
local function addCurve(len, hardness, dir, index, replace) M.addPiece({piece = 'hexCurve', direction = dir, length = len, hardness = hardness}, index, replace) end
local function addOffsetCurve(len, off, hardness, index, replace) M.addPiece({piece = 'hexOffsetCurve', length = len, xOffset = off, hardness = hardness}, index, replace) end
local function addSpiral(size, inside, dir, index, replace) M.addPiece({piece = 'hexSpiral', size = size, direction = dir, inside = inside}, index, replace) end
local function addLoop(rad, off, index, replace) M.addPiece({piece = 'hexLoop', radius = rad, xOffset = off}, index, replace) end
local function addEmptyOffset(xOff, yOff, zOff, dirOff, absolute, index, replace) M.addPiece({piece = 'hexEmptyOffset', xOff = xOff, yOff = yOff, zOff = zOff, dirOff = dirOff, absolute = absolute}, index, replace) end

--adds a piece to the piece field, at a given position, can replace others, and handles marking affected pieces as invalid.
local function addPiece(params, index, replace)
  local pieces = subPieces[subTrackIndex]
  if not index then
    index = #pieces + 1
  end
  if not replace then
    if index <= #pieces then
      for i = #pieces + 1, index, -1 do
        pieces[i] = pieces[i - 1]
        pieces[i].invalid = true
        M.invalidatePiece(i, name)
      end
      local existingMarkers = {}
      for i = index, #pieces do
        for _, name in ipairs(markers.names) do
          if pieces[i][name] ~= nil then
            existingMarkers[name] = true
          end
        end
      end
      M.invalidatePiece(index - 1)
    end

  end

  local tmp = {}
  if replace and pieces[index] ~= nil then
    tmp = {
      mesh = pieces[index].mesh
    }
    tmp.obstacles = pieces[index].obstacles
    tmp.materialInfo = pieces[index].materialInfo
    tmp.leftMesh = pieces[index].leftMesh
    tmp.centerMesh = pieces[index].centerMesh
    tmp.rightMesh = pieces[index].rightMesh
    for _, name in ipairs(markers.names) do
      tmp[name] = pieces[index][name]
    end

  end

  pieces[index] = params
  pieces[index].invalid = true

  if not replace and index > 2 then
    pieces[index].leftMesh = pieces[index - 1].leftMesh or 'regular'
    pieces[index].centerMesh = pieces[index - 1].centerMesh or 'regular'
    pieces[index].rightMesh = pieces[index - 1].rightMesh or 'regular'
  else
    pieces[index].leftMesh = tmp.leftMesh or 'regular'
    pieces[index].centerMesh = tmp.centerMesh or 'regular'
    pieces[index].rightMesh = tmp.rightMesh or 'regular'
  end

  if replace then
    for _, name in ipairs(markers.names) do
      pieces[index][name] = tmp[name]
    end
    pieces[index].obstacles = tmp.obstacles
    pieces[index].materialInfo = tmp.materialInfo
    pieces[index].mesh = tmp.mesh
    pieces[index].invalid = true
    --[[for _,name in ipairs(markers.names) do
    if pieces[index][name] then
     M.invalidatePiece(index,name)
    end
  end
  ]]
    if index == #subTracks[subTrackIndex] then
      --dump("isLast")
      pieces[#subTracks[subTrackIndex]].invalid = true
      for _, name in ipairs(markers.names) do
        if pieces[index][name] ~= nil then
          --dump(pieces[index][name])
          M.invalidatePiece(index, name)
        end
      end
    else
      --dump("all")
      local existingMarkers = {}
      for i = index, #pieces do
        for _, name in ipairs(markers.names) do
          if pieces[i][name] ~= nil then
            existingMarkers[name] = true
          end
        end
      end

      for i = index, #pieces do
        for _, name in ipairs(markers.names) do
          if existingMarkers[name] then
            M.invalidatePiece(i, name)
          end
        end
        pieces[i].invalid = true
      end
    end
  end

  if not replace then
    local pieceBefore = pieces[index - 1]
    if pieceBefore and pieceBefore.materialInfo then
      pieces[index].materialInfo = {}
      for key, val in pairs(pieceBefore.materialInfo) do
        pieces[index].materialInfo[key] = val
      end
    end
  end

  pieces[index].fresh = not replace

  if not pieces[index].materialInfo then pieces[index].materialInfo = {} end
  focusMarkerOn(index)
end

--helper function to rotate a vector by a quat.
local function rotateVectorByQuat(v, q)
  return q:__mul(v)
end

-----------------------
--Import and Export --
-----------------------

--exports the current track to a simple lua table.
local function exportTrackToTable()
  local export = {
    subPieces = {},
    subTrackPositions = {},
    connected = trackClosed,
    defaultLaps = defaultLaps,
    reversible = reversible,
    materials = {},
    materialFields = materialUtil.getMaterials(),
    intersections = {}
  }
  for i,tp in ipairs(subTrackPositions) do
    export.subTrackPositions[i] = {
      x = tp.position.x,
      y = tp.position.y,
      z = tp.position.z,
      hdg = tp.hdg
    }
  end
  for s, pieces in ipairs(subPieces) do
    export.subPieces[s] = {}
    for i, p in ipairs(pieces) do
      export.subPieces[s][i] = {
        piece = p.piece,
        length = p.length,
        direction = p.direction,
        hardness = p.hardness,
        xOffset = p.xOffset,
        size = p.size,
        radius = p.radius,
        xOff = p.xOff,
        yOff = p.yOff,
        zOff = p.zOff,
        dirOff = p.dirOff,
        inside = p.inside,
        absolute = p.absolute,
        forwardLen = p.forwardLen,
        backwardLen = p.backwardLen,
        angle = p.angle,
        empty = p.empty,
        centerMesh = p.centerMesh ~= 'regular' and p.centerMesh or nil,
        rightMesh = p.rightMesh ~= 'regular' and p.rightMesh or nil,
        leftMesh = p.leftMesh ~= 'regular' and p.leftMesh or nil
      }
      for _, name in ipairs(markers.names) do
        export.subPieces[s][i][name] = p[name]
      end
      if p.obstacles and #p.obstacles > 0 then
        local obstacles = {}
        for _, o in ipairs(p.obstacles) do
          local e = {
            value = o.value,
            variant = o.variant,
            offset = o.offset,
            anchor = o.anchor,
            scale = {x = o.scale.x, y = o.scale.y, z = o.scale.z},
            extra = {x = o.extra.x, y = o.extra.y, z = o.extra.z},
            position = {x = o.position.x, y = o.position.y, z = o.position.z},
            rotationEuler = {x = o.rotationEuler.x, y = o.rotationEuler.y, z = o.rotationEuler.z},
            material = o.material
          }
          obstacles[#obstacles + 1] = e
        end
        export.subPieces[s][i].obstacles = obstacles
      end
      for key, val in pairs(p.materialInfo) do
      if not export.materials[s] then export.materials[s] = {} end
        if not export.materials[s][key] then export.materials[s][key] = {} end
        if not export.materials[s][key][val] then export.materials[s][key][val] = {} end
        export.materials[s][key][val][#export.materials[s][key][val] + 1] = i
      end
    end
  end
  for i,s in ipairs(intersections) do
    local segs = {}
    for j,seg in ipairs(s.segments) do
      segs[j] = {index = seg.index, sub = seg.sub, reverse = seg.reverse}
    end
    export.intersections[i] = {
      segments = segs,
      centerMat = s.centerMat,
      borderMat = s.borderMat,
      borderMesh = s.borderMesh
    }
  end

  return export
end

local function upgradeObstacles(obstacles)
  for i, o in ipairs(obstacles) do
    if not o.extra then o.extra = {x=1,y=1,z=1} end
    if o.value == "cube" then
      if o.variant == 1 then
        o.position.z = o.position.z + o.scale.z/2
      elseif o.variant == 2 then
        o.position.z = o.position.z + o.scale.z
        o.scale.x = o.scale.x * 2
        o.scale.y = o.scale.y * 2
        o.scale.z = o.scale.z * 2
      elseif o.variant == 3 then
        o.position.z = o.position.z + o.scale.z*2
        o.scale.x = o.scale.x * 4
        o.scale.y = o.scale.y * 4
        o.scale.z = o.scale.z * 4
      elseif o.variant == 4 then
        o.position.z = o.position.z + o.scale.z*4
        o.scale.x = o.scale.x * 8
        o.scale.y = o.scale.y * 8
        o.scale.z = o.scale.z * 8
      end
    elseif o.value == "bump" then
      if o.variant ==1 then
        o.extra.x = o.scale.x * 3.5
        o.extra.y = o.scale.y * 0.25
        o.scale.x = o.scale.x * 4
        o.scale.y = o.scale.y * 2
        o.scale.z = o.scale.z * 0.5
      elseif o.variant == 2 then
        o.extra.x = o.scale.x * 3
        o.extra.y = o.scale.y * 0.25
        o.scale.x = o.scale.x * 4
        o.scale.y = o.scale.y * 4
        o.scale.z = o.scale.z * 1

      elseif o.variant == 3 then
        o.extra.x = o.scale.x * 3
        o.extra.y = o.scale.y * 0.25
        o.scale.x = o.scale.x * 4
        o.scale.y = o.scale.y * 8
        o.scale.z = o.scale.z * 0.5
      end

    elseif o.value == "ramp" then
      if o.variant ==1 then
        o.extra.x = 0.9
        o.extra.y = 1.5
        o.scale.x = o.scale.x * 4
        o.scale.y = o.scale.y * 10
        o.scale.z = o.scale.z * 1.5
      elseif o.variant == 2 then
        o.extra.x = 0.9
        o.extra.y = 1.8
        o.scale.x = o.scale.x * 4
        o.scale.y = o.scale.y * 10
        o.scale.z = o.scale.z * 2
      elseif o.variant == 3 then
        o.extra.x = 0.9
        o.extra.y = 2
        o.scale.x = o.scale.x * 4
        o.scale.y = o.scale.y * 10
        o.scale.z = o.scale.z * 5
      elseif o.variant == 4 then
        o.extra.x = 0.9
        o.extra.y = 2
        o.scale.x = o.scale.x * 1
        o.scale.y = o.scale.y * 3
        o.scale.z = o.scale.z * 1
      end

    end
  end
  return obstacles
end

--imports the track from a table. destroys current track.
local function importTrackFromTable(import)
  M.removeTrack()
  currentSelected = 1
  subPieces = {{}}
  subTrackPositions = {{}}
  subTracks = {{}}
  intersections = {}
  if import.version == "1.0" then
    import.subPieces = {import.pieces}
    import.subTrackPositions = {import.trackPosition}
    import.materials = {import.materials}
  end
  subPieces = import.subPieces

  defaultLaps = import.defaultLaps or 2
  reversible = import.reversible or false
  fixedCheckpoints = import.fixedCheckpoints or false
  local zOff = 0
  if pieces and pieces[1].z == 15 then
    zOff = 15
  end

  for s, tp in ipairs(import.subTrackPositions) do
    subTrackPositions[s] = {}
    M.setTrackPosition(tp.x, tp.y, tp.z + zOff, -tp.hdg / math.pi * 180, s)
  end
  for s,pieces in ipairs(subPieces) do
    subTracks[s] = {}
    for _, p in ipairs(pieces) do
      if not p.materialInfo then p.materialInfo = {} end
      if p.obstacles then
        if import.version == "1.0" then
          p.obstacles = upgradeObstacles(p.obstacles)
        end
        for i, o in ipairs(p.obstacles) do
          if not o.extra then o.extra = {x=1,y=1,z=1} end
          o.position = vec3(o.position.x, o.position.y, o.position.z)
          o.scale = vec3(o.scale.x, o.scale.y, o.scale.z)
          o.extra = vec3(o.extra.x, o.extra.y, o.extra.z)
          o.rotationEuler = vec3(o.rotationEuler.x, o.rotationEuler.y, o.rotationEuler.z)
          o.rotation = quatFromEuler(o.rotationEuler.x / 180 * math.pi, o.rotationEuler.y / 180 * math.pi, (o.rotationEuler.z) / 180 * math.pi)
          o.material = o.material
        end
      end
      if p.centerMesh == nil then
        p.centerMesh = "regular"
      end
      if p.leftMesh == nil then
        p.leftMesh = "regular"
      end
      if p.rightMesh == nil then
        p.rightMesh = "regular"
      end
    end
  end
  if import.materials then
    for s,subMats in ipairs(import.materials) do
      for field, mats in pairs(subMats) do
        for mat, list in pairs(mats) do
          for _, index in pairs(list) do
            subPieces[s][index].materialInfo[field] = mat
          end
        end
      end
    end
  end

  for s,pieces in ipairs(subPieces) do
    for _, p in ipairs(pieces) do
      p.invalid = true
      --invalidatePiece(i)
    end
  end
  materialUtil.setMaterials(import.materialFields or {A = {}, B = {}, C = {}, D = {}, E = {}, F = {}, G = {}, H = {}}, true)
  local lvlName = core_levels.getLevelName(getMissionFilename())
  if import.environment and lvlName ~= 'glow_city' and lvlName == import.level then
    core_environment.setTimeOfDay(import.environment.tod)
    core_environment.setFogDensity(import.environment.fog)
  end
end

--restores the track from the given file by name
local function load(originalFilename, instantHighQuality, increasePointMult, clearShapes, silent, ignoreCol)
  local read = nil
  ignoreCollision = ignoreCol
  if type(originalFilename) == "table" then
    read = originalFilename
  else
    local filename = 'trackEditor/'..originalFilename..'.json'
    if FS:fileExists(filename) then
      read = readJsonFile(filename)
      if not read then
        log('I', logTag, 'No track found in file Documents/BeamNG.drive/'..filename)
        return
      end
    end
  end
  if read then
    M.importTrackFromTable(read)
    --finally, create the track.
    local oldPointMult = pointsMultiplier
    local oldLUT = mesher.settings.LUTDetail
    if increasePointMult and not read.keepPointMultiplier then
      pointsMultiplier = pointsMultiplier * 1.5
    end

    for i = 1, #subPieces do
      M.switchSubTrack(i)
      for i, p in ipairs(subPieces[subTrackIndex]) do
        for _, m in ipairs(markers.names) do
          markers.addMarkerChange(m, i)
        end
      end
      M.makeTrack(true, ignoreCollision)
    end
    M.setHighQuality(true)
    -- add intersections after the track is built

    for _,inter in ipairs(read.intersections or {}) do
      for _,s in ipairs(inter.segments) do
        if s.index == 1 then s.index = 2 end
        s.segment = subTracks[s.sub][s.index]
      end
      M.mergeMultiTrack(inter.segments, inter.centerMat, inter.borderMat, inter.borderMesh)
    end

    pointsMultiplier = oldPointMult
    if clearShapes then
      mesher.clearShapes()
    end
  else
    log('I', logTag, 'Could not find file Documents/BeamNG.drive/'..filename)
  end
  if not silent then
    if type(originalFilename) == "table" then
      guihooks.trigger('Message', {ttl = 10, msg = 'Succesfully loaded track', category = "fill", icon = "check_circle"})
    else
      guihooks.trigger('Message', {ttl = 10, msg = 'Succesfully loaded '..originalFilename, category = "fill", icon = "check_circle"})
    end
  end
end

--only loads the json of a track (for getting infos such as length and author)
local function loadJSON(originalFilename)
  local filename = 'trackEditor/'..originalFilename..'.json'

  if FS:fileExists(filename) then
    local read = readJsonFile(filename)
    if not read then
      log('I', logTag, 'No track found in file Documents/BeamNG.drive/'..filename)
      return nil
    end
    return read
  else
    log('I', logTag, 'Could not find file Documents/BeamNG.drive/'..filename)
    return nil
  end
end

--saves the track to the given file by name
local function save(filename, saveOptions)
  --dump(saveOptions)
  local date = os.date("*t")
  local exported = M.exportTrackToTable()
  if not saveOptions then saveOptions = {} end
  --additional info, not important for track generation
  exported.version = version
  local playerVehicle = be:getPlayerVehicle(0)
  if playerVehicle then
    exported.author = core_vehicles.getVehicleLicenseText(playerVehicle)
  else
    exported.author = "Anonymous"
  end
  exported.date = os.time() .. ""
  exported.length = subTracks[subTrackIndex][#subTracks[subTrackIndex]].endLength
  exported.connected = trackClosed

  if saveOptions.saveForThisMap then
    exported.level = core_levels.getLevelName(getMissionFilename())
  else
    exported.level = nil
  end

  if saveOptions.saveEnvironment then
    exported.environment = {
      tod = core_environment.getTimeOfDay(),
    fog = core_environment.getFogDensity()}
  else
    exported.environment = nil
  end

  if saveOptions.difficulty then
    exported.difficulty = saveOptions.difficulty
  else
    exported.difficulty = 37
  end

  if saveOptions.description and saveOptions.description ~= "" then
    exported.description = saveOptions.description
  else
    exported.description = nil
  end

  if filename ~= nil then
    local name
    if filename == "" then
      name = string.format("%.4d-%.2d-%.2d_%.2d-%.2d-%.2d", date.year, date.month, date.day, date.hour, date.min, date.sec)
    else
      name = filename
    end
    filename = 'trackEditor/'..name..'.json';
    serializeJsonToFile(filename, exported, true)
    log('I', logTag, 'Serialized track to file Documents/BeamNG.drive/'..filename)
    guihooks.trigger('Message', {ttl = 10, msg = 'Serialized track to file Documents/BeamNG.drive/'..filename, category = "fill", icon = "save"})
    return exported, name
  else
    guihooks.trigger('Message', {ttl = 10, msg = 'Saved track without serializing it', category = "fill", icon = "save"})
    return exported
  end
end

--renames a file
local function rename(oldName, newName)
  local pre = 'trackEditor/'
  if not FS:fileExists(pre..oldName..'.json') then
    log('I', logTag, 'Failed renaming '..oldName..' to '..newName..': File not found')
    return
  end
  FS:renameFile(pre..oldName..'.json', pre..newName..'.json')
  FS:removeFile(pre..oldName..'.json')
  log('I', logTag, 'Succesfully renamed '..oldName..' to '..newName..'')
  guihooks.trigger('Message', {ttl = 10, msg = 'Succesfully renamed '..oldName..' to '..newName..'', category = "fill", icon = "save"})
end

--reloads the list of all available tracks, sends those to the app
local function getCustomTracks()
  local tracks = {}
  local previews = {}
  for i, file in ipairs(FS:findFiles('trackEditor/', '*.json', -1, true, false)) do
    local _, fn, e = path.split(file)
    local name = fn:sub(1, #fn - #e - 1)
    local read = loadJSON(name)
    --dump(name)
    --dump(read)
    if read then
      if read.version == nil then
        --dump(read)
        log('I', logTag, "The file 'trackEditor/"..name..".json' uses an old format that is no longer supported.")
      else
        tracks[#tracks + 1] = name
      end
    end
  end
  return tracks
end

local function getPreviewNames()
  local previews = {}
  for i, file in ipairs(FS:findFiles('trackEditor/', '*.png', -1, true, false)) do
    local _, fn, e = path.split(file)
    previews[i] = fn:sub(1, #fn - #e - 1)
  end
  for i, file in ipairs(FS:findFiles('trackEditor/', '*.jpg', -1, true, false)) do
    local _, fn, e = path.split(file)
    previews[i] = fn:sub(1, #fn - #e - 1)
  end
  return previews
end

-- Hook for deleting the track when the level is unloaded.
local function onClientEndMission()
  M.unloadAll()
end
local function start()
  positionVehicle()
end

local function onUploadScreenshot(metadata)
  --if not doSaveOnScreenshot or not track or #track == 0  then return false end
  --metadata.track = M.save(nil, false)
end

--positioning
M.addCheckPointPositions = addCheckPointPositions
M.positionVehicle = positionVehicle
M.setTrackPosition = setTrackPosition
M.getTrackPosition = getTrackPosition
M.positionTrackAboveVehicle = positionTrackAboveVehicle
M.positionTrackBeforeCamera = positionTrackBeforeCamera
M.rotateTrackToCamera = rotateTrackToCamera
M.rotateTrackToTrackVehicle = rotateTrackToTrackVehicle

M.getLastPieceWithMarker = getLastPieceWithMarker
M.getPieceInfo = getPieceInfo
M.showMarkers = showMarkers
M.setAllPiecesToAsphalt = setAllPiecesToAsphalt
M.setHighQuality = setHighQuality
M.stackToCursor = stackToCursor
M.stack = stack
M.applyStack = applyStack
M.deepcopy = deepcopy
M.getStackCount = getStackCount
M.clearStack = clearStack
M.getSelectedTrackInfo = getSelectedTrackInfo
M.setDefaultLaps = setDefaultLaps
M.setReversible = setReversible
M.getSegmentInfo = getSegmentInfo
M.setMesh = setMesh

M.getHdgVector = getHdgVector
M.setAllPiecesHighQuality = setAllPiecesHighQuality
M.onUpdate = onUpdate
--marker functions
M.focusCameraOn = focusCameraOn
M.unselectAll = unselectAll
M.focusMarkerOn = focusMarkerOn
M.createMarkers = createMarkers
M.markerChange = markerChange
M.interpolateSegment = interpolateSegment
--track to mesh functions
M.refreshAllMaterials = refreshAllMaterials
M.makeTrack = makeTrack

-- cam settings
M.camDistance = camDistance

M.invalidatePiece = invalidatePiece
M.toSegments = toSegments
M.calculateCustomPoints = calculateCustomPoints
M.convertToSpline = convertToSpline
M.getArcPoints = getArcPoints

--track editor functions
M.initTrack = initTrack
M.unloadAll = unloadAll
M.removeTrack = removeTrack
M.getEndOfTrack = getEndOfTrack
M.revert = revert
M.removeAt = removeAt
M.addForward = addForward
M.addCurve = addCurve
M.addOffsetCurve = addOffsetCurve
M.addSpiral = addSpiral
M.addLoop = addLoop
M.addPiece = addPiece
M.addEmptyOffset = addEmptyOffset

M.initialTrackPiece = initialTrackPiece
M.forward = forward
M.curve = curve
M.offsetCurve = offsetCurve
M.spiral = spiral
M.fresnelSC = fresnelSC
M.loop = loop
M.emptyOffset = emptyOffset

M.rotateVectorByQuat = rotateVectorByQuat
M.setMaterial = setMaterial
M.setSegmentMaterial = setSegmentMaterial
--Import and Export
M.exportTrackToTable = exportTrackToTable
M.importTrackFromTable = importTrackFromTable
M.load = load
M.loadJSON = loadJSON
M.save = save
M.rename = rename
M.getCustomTracks = getCustomTracks
M.getPreviewNames = getPreviewNames
M.onClientEndMission = onClientEndMission
M.interpolateField = interpolateField
M.snapToGrid = snapToGrid
M.measureTrack = measureTrack

M.materialUtil = materialUtil
M.getAllCheckpoints = getAllCheckpoints
M.addClosingPiece = addClosingPiece
M.getBezierPoints = getBezierPoints
M.initTrack()
M.onUploadScreenshot = onUploadScreenshot
M.onPreRender = function(dt) transition.onPreRender(dt) end

M.saveHistory = saveHistory
M.undo = M.undo
M.switchSubTrack = switchSubTrack
M.createNewSubTrack = createNewSubTrack
M.removeSubTrack = removeSubTrack
M.mergeMultiTrack = mergeMultiTrack
M.setIntersectionMesh = setIntersectionMesh
M.setIntersectionMaterial = setIntersectionMaterial
M.getIntersection = getIntersection
M.removeIntersection = removeIntersection
return M

