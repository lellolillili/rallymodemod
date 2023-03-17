-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this extension draws the debug representation of paths

local M = {}

local defaultSplineSmoothing = 0.5

local debugEnabled = false
local paths = {}

local function getUniquePathName(name)
  local names = {}
  for _, path in ipairs(paths) do
    names[path.name] = true
  end

  local testName = name
  local nameCounter = 1
  while names[testName] do
    testName = name .. nameCounter
    nameCounter = nameCounter + 1
  end
  return testName
end

local function getMarkerIds(path, idx)
  local markerCount = #path.markers
  local index1 = math.max(idx - 1, 1)
  local index2 = idx
  local index3 = math.min(idx + 1, markerCount)
  local index4 = math.min(idx + 2, markerCount)
  if path.looped then
    index1 = ((idx - 2) % markerCount) + 1
    index2 = ((idx - 1) % markerCount) + 1
    index3 = ((idx) % markerCount) + 1
    index4 = ((idx + 1) % markerCount) + 1
  end
  if path.markers[index1].cut then index1 = index2 end
  if path.markers[index3].cut then index4 = index3 end

  return index1, index2, index3, index4
end

local function createPath(name)
  table.insert(paths, {name = name, markers = {}, manualFov = true, dirty = true})
  return paths[#paths]
end

local function deletePath(path)
  local deletionIndex
  for i, p in ipairs(paths) do
    if p.name == path.name then
      deletionIndex = i
      break
    end
  end

  if deletionIndex then
    table.remove(paths, deletionIndex)
  end
end

local function getPaths()
  return paths
end

local function getEndIdx(path)
  if path.looped then
    return #path.markers
  else
    return #path.markers - 1
  end
end

local function savePath(cameraPath, filename)
  local pathCopy = deepcopy(cameraPath)
  for index, marker in ipairs(pathCopy.markers) do
    marker.pos = {x = marker.pos.x, y = marker.pos.y, z = marker.pos.z}
    marker.rot = {x = marker.rot.x, y = marker.rot.y, z = marker.rot.z, w = marker.rot.w}
    marker.fov = marker.fov or 60
    marker.trackPosition = marker.trackPosition or false
    if marker.positionSmooth == defaultSplineSmoothing then
      marker.positionSmooth = nil
    end
    if marker.bullettime == 1 then
      marker.bullettime = nil
    end
  end

  -- Filter out things that dont have to be saved
  pathCopy.filename = nil
  pathCopy.dirty = nil

  pathCopy.version = "6"
  pathCopy.manualFov = pathCopy.manualFov or false
  pathCopy.looped = pathCopy.looped or false

  jsonWriteFile(filename, pathCopy, true)
  cameraPath.filename = filename
  cameraPath.dirty = false
end

local function loadPath(pathFileName)
  if not pathFileName then
    return
  end
  for _, path in ipairs(paths) do
    if path.filename == pathFileName then
      log('I', 'core_paths.loadPath', 'Returning path because it was already loaded: ' .. tostring(pathFileName))
      return path
    end
  end

  local pathJsonObj = readJsonFile(pathFileName)
  if not pathJsonObj then
    log('E', 'core_paths.loadPath', 'unable to find path file: ' .. tostring(pathFileName))
    return
  end

  local res = { markers = {}}

  res.looped = pathJsonObj.looped or false

  -- extract all its markers
  for i, markerData in ipairs(pathJsonObj.markers) do
    local marker = {
      pos = vec3(markerData.pos.x, markerData.pos.y, markerData.pos.z),
      rot = quat(markerData.rot.x, markerData.rot.y, markerData.rot.z, markerData.rot.w),
      time = markerData.time,
      fov = markerData.fov,
      trackPosition = markerData.trackPosition,
      positionSmooth = markerData.positionSmooth or defaultSplineSmoothing,
      bullettime = markerData.bullettime or 1,
      cut = markerData.cut,
      movingStart = markerData.movingStart or true,
      movingEnd = markerData.movingEnd or true
    }
    table.insert(res.markers, marker)
  end
  -- fix up the rotations
  local markerCount = tableSize(pathJsonObj.markers)
  for i = 2, markerCount do
    if res.markers[i] then
      if res.markers[i].rot:dot(res.markers[i - 1].rot) < 0 then
        res.markers[i].rot = -res.markers[i].rot
      end
    end
  end
  res.rotFixId = markerCount

  res.filename = pathFileName
  res.replay = pathJsonObj.replay
  res.name = pathJsonObj.name
  table.insert(paths, res)
  return res
end

local function addPath(path)
  table.insert(paths, path)
end

local function onExtensionLoaded()
end

local function onSerialize()
  return {
    paths = deepcopy(paths)
  }
end

local function onDeserialized(data)
  paths = deepcopy(data.paths)
end

local function onClientStartMission()
  local camPathFolder = (path.split(getMissionFilename()) or '') .. "camPaths"
  local camPathFiles = FS:findFiles(camPathFolder, "*.camPath.json", 0, true, true)

  paths = {}
  local counter = 0
  local namesCounter = {}
  for _, filename in pairs(camPathFiles) do
    local path = loadPath(filename)

    if not namesCounter[path.name] then namesCounter[path.name] = 0 end
    namesCounter[path.name] = namesCounter[path.name] + 1
    if namesCounter[path.name] > 1 then
      path.name = path.name .. "(" .. namesCounter[path.name] .. ")"
    end

    counter = counter + 1
  end

  if counter > 0 then
    log('I', 'core_paths.loadPath', "" .. counter .. " Camera Path(s) loaded.")
  end
end

local function getPath_Deprecated(pathName)
  -- find any path (chooses first)
  if not pathName then
    local objNames = scenetree.findClassObjects('SimPath')
    if not objNames or #objNames == 0 then
      -- if not SimPath on level return
      --log('E', 'core_paths.getPath', 'unable to find any path')
      return
    end
    pathName = objNames[1]
  end
  local pathObj = scenetree.findObject(pathName)
  if not pathObj then
    log('E', 'core_paths.getPath', 'unable to find path: ' .. tostring(pathName))
    return
  end

  local res = { markers = {}}

  res.looped = false
  if pathObj.looped then
    res.looped = pathObj.looped == '1'
  end

  -- extract all its markers
  --pathObj:sortMarkers()
  res.nodeCount = pathObj:size()
  for i = 0, res.nodeCount do
    local markerId = pathObj:idAt(i)
    if markerId >= 0 then
      local marker = scenetree.findObjectById(markerId)
      if marker then
        local d = {
          pos = vec3(marker:getPosition()),
          rot = quat(marker:getRotation()),
          time = marker.timeToNext or marker.seconds,
          positionSmooth = marker.positionSmooth
        }
        res.markers[marker.seqNum + 1] = d
      end
    end
  end
  -- fix up the rotations
  for i = 2, res.nodeCount - 1 do
    if res.markers[i].rot:dot(res.markers[i - 1].rot) < 0 then
      res.markers[i].rot = -res.markers[i].rot
    end
  end

  return res
end

local function playPath(path, offset, initData)
  -- exit free cam
  if commands.isFreeCamera() then
    commands.setGameCamera()
  end
  local initData = initData or {}
  initData.useJsonVersion = true
  initData.hasIntro = true
  initData.path = path
  initData.offset = offset or 0
  initData.reset = initData.reset or (function(this) end)
  initData.getNextPath = initData.getNextPath or (function(this) return initData.path end)

  core_camera.setByName(0, "path", false, initData)
end

local function stopCurrentPath()
  -- set the path of the camera to nil
  local initData = {}
  initData.useJsonVersion = true
  initData.hasIntro = false
  initData.path = nil
  initData.reset = function (this) end
  initData.getNextPath = function(this) return nil end
  core_camera.setByName(0, "path", false, initData)

  -- switch to free cam
  if not commands.isFreeCamera() then
    commands.setFreeCamera()
  end
end

-- callbacks
M.onClientStartMission = onClientStartMission
M.onExtensionLoaded = onExtensionLoaded
M.loadPath = loadPath
M.savePath = savePath
M.getPaths = getPaths
M.addPath = addPath
M.createPath = createPath
M.deletePath = deletePath
M.getUniquePathName = getUniquePathName
M.getMarkerIds = getMarkerIds
M.getEndIdx = getEndIdx
M.playPath = playPath
M.stopCurrentPath = stopCurrentPath

M.onSerialize = onSerialize
M.onDeserialized = onDeserialized
M.getPath = getPath_Deprecated

return M
