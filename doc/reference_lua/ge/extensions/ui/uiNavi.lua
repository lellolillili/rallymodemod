-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local objSpeed_smooth = newExponentialSmoothing(60)

local function findClosestRoad (x, y, z)
  return map.findClosestRoad(vec3(x, y, z))
end

local function getSpawnpoints ()
  -- spawn points
  -- TODO: make this available if the level is not loaded yet, so we can use the spawnpoint positions in the levelselector
  local spawnpoints = scenetree.findClassObjects("SpawnSphere")
  local spawnPointAdditionalInfo = {}
  local res = {}

  if FS:fileExists(getMissionFilename()) then
    info = jsonReadFile(getMissionFilename())
    if info.spawnPoints then
      for _, point in pairs(info.spawnPoints) do
        spawnPointAdditionalInfo[point.objectname] = point
      end
    end
  end

  for _, pid in pairs(spawnpoints) do
    local o = scenetree.findObject(pid)
    if o then
      local tmp = {}
      if spawnPointAdditionalInfo[o.name] then
        tmp = spawnPointAdditionalInfo[o.name]
      end
      tmp.pos = vec3(o:getPosition()):toTable()
      table.insert(res, tmp)
    end
  end

  return res
end

local function getPointsOfInterest ()
  -- points of interest
  local poi_set = scenetree.PointOfInterestSet
  local pois = {}
  if poi_set then
  local poios = poi_set:getObjects() or {}
  for _, pid in pairs(poios) do
    local o = scenetree.findObject(pid)
    if o then
      table.insert(pois, {name = o.name, pos = vec3(o:getPosition()):toTable(), desc = o.desc, title = o.title, type = o.type})
    end
  end
  return pois
 end
end

local function requestPoi ()
  guihooks.trigger('MapPointsOfInterest', getPointsOfInterest())
end

local missions = {
  -- {
  --   pos = {569.385, 175.0835, 0},
  --   desc =  "campaigns.utah.chapter_1.cliffjump.title",
  --   title =  "campaigns.utah.chapter_1.cliffjump.title",
  --   state =  "ready",
  --   new = true,
  --   objectives =  {
  --     bla1 =  true,
  --     bla2 =  false,
  --     bla3 =  false
  --   },
  --   type =  "delivery"
  -- },
  -- {
  --   pos = {-10.2638, 509, 0},
  --   desc =  "campaigns.training.training.training_acceleration_braking.description",
  --   title =  "campaigns.training.training.training_acceleration_braking.title",
  --   state =  "ready",
  --   new = false,
  --   objectives =  {
  --     bla1 =  true,
  --     bla2 =  false,
  --     bla3 =  false
  --   },
  --   type =  "training"
  -- },
  -- {
  --   pos = {136.2955, 488.8725, 0},
  --   desc =  "campaigns.utah.chapter_1.highway.title",
  --   title =  "campaigns.utah.chapter_1.highway.title",
  --   state =  "failed",
  --   new = false,
  --   objectives =  {
  --     bla1 =  true,
  --     bla2 =  false,
  --     bla3 =  false
  --   },
  --   type =  "race"
  -- },
  -- {
  --   pos = {215.064, 427.08, 0},
  --   desc =  "campaigns.training.training.training_acceleration_braking.description",
  --   title =  "campaigns.training.training.training_acceleration_braking.title",
  --   state =  "bronze",
  --   new = false,
  --   objectives =  {
  --     bla1 =  true,
  --     bla2 =  false,
  --     bla3 =  false
  --   },
  --   type =  "training"
  -- }
}

local function getMissions ()
  return missions
end

local function sendMissions ()
  guihooks.trigger('MapMissions', getMissions())
end

local function setMissions (m)
  missions = m
  sendMissions()
end

local lastPlayerPosition
local destination = nil
local destinationPos = nil

-- // WARNING: multiseat might result in several active players (?)
-- // in this case we will currently only render the path for the last player.
-- // in the future we might want to support rendering several paths
local function route_start (wp, pos)
  core_groundMarkers.setFocus(wp)
  destination = wp
  destinationPos = vec3(pos[1], pos[2], pos[3])
end

local function route_end ()
  destination = nil
  destinationPos = nil
  core_groundMarkers.setFocus(nil)
  guihooks.trigger('RouteUpdate', {})
  guihooks.trigger('RouteEnded')
end

local function route_inprogress ()
  return destination ~= nil
end

-- // TODO: figure out good distance
local function route_update (oldPos, newPos)
  if not route_inprogress() then return end

  local route = map.getPath(findClosestRoad(newPos), destination)
  if oldPos:distance(newPos) > 0.1 then
    core_groundMarkers.setFocus(destination)
    guihooks.trigger('RouteUpdate', route) -- TODO: convert into stream
    if newPos:distance(destinationPos) < 50 then
      guihooks.trigger('RouteReachedDestination')
      route_end()
    end
  end
end

local function planRoute (posX, posY)
  local x = vec3(posX[1], posX[2], posX[3])
  local y = vec3(posY[1], posY[2], posY[3])

  local startPoint = findClosestRoad(x)
  local endPoint = findClosestRoad(y)

  local route = map.getPath(startPoint, endPoint)
  guihooks.trigger('RoutePlanned', route)
end

local function getBusStops ()
  local stops = scenetree.findClassObjects("BeamNGTrigger")
  local interm = {}
  local res = {}

  for _, pid in pairs(stops) do
    local o = scenetree.findObject(pid)
    if o and o.type == 'busstop' then
      table.insert(interm,  vec3(o:getPosition()))
    end
  end

  -- quick and dirty merge of bus stops that are on different sides of the road
  local foundCoresponding = {}
  for id, vec in pairs(interm) do
    for id2, vec2 in pairs(interm) do
      if id < id2 and vec:distance(vec2) < 70 then
        local tmp = {}
        local merged = vec - (vec - vec2) / 2
        foundCoresponding[id] = true
        foundCoresponding[id2] = true
        tmp.pos = merged:toTable()
        table.insert(res, tmp)
      end
    end
    -- sometimes there is only one bus station
    if not foundCoresponding[id] then
      table.insert(res, {pos = vec:toTable()})
    end
  end

  -- for id, vec in pairs(interm) do
  --   table.insert(res, {pos = vec:toTable()})
  -- end

  return res
end

local camPos = vec3()
local camPosPrev = vec3()
local mapObjects = {}
local dir
local xPlus, yMinus = vec3(1,0,0), vec3(0,-1,0)
local controlId, cameraHandler
local function onGuiUpdate(dtReal, dtSim, dtRaw)
  table.clear(mapObjects)
  for k, v in pairs(map.getTrackedObjects() or {}) do
    if v.uiState ~= 0 then
      dir = v.dirVec:normalized()
      mapObjects[k] = {
        pos = v.pos:toTable(),
      --v.vel = v.vel:toTable()
        rot = math.deg(math.atan2(dir:dot(xPlus), dir:dot(yMinus))),
      --v.dirVec = v.dirVec:toTable()
        speed = v.vel:length(),
        type = 'BeamNGVehicle', -- vehicle
        state = v.uiState or 1
      }
    end
  end

  controlId = be:getPlayerVehicleID(0)
  if not controlId or not mapObjects[controlId] or commands.isFreeCamera() then --fly mode
    cameraHandler = getCamera()
    if cameraHandler then
      -- if no vehicle is being driven, then fallback to camera position/rotation
      controlId = cameraHandler:getID()
      local sobj = scenetree[controlId]

      local matrix = sobj:getTransform()
      local forVec = vec3(matrix:getColumn(1))
      local heading = math.atan2(forVec.x, -forVec.y) * 180 / math.pi

      camPos:set(sobj:getPosition())
      local vel = ((camPosPrev or camPos) - camPos) / dtSim
      camPosPrev:set(camPos)

      mapObjects[controlId] = {
        pos = camPos:toTable(),
        --vel = vel:toTable(),
        speed = objSpeed_smooth:get(vel:length()),
        rot = heading,
        --dirvec = forVec:toTable(),
        type = sobj.className
      }
    end
  end
  -- guard agains sending wrong data in the first frame, when there is no camera - but a vehicle, that is not tracked by the map yet
  if not mapObjects[controlId] then return end
  guihooks.trigger('NavigationMapUpdate', {controlID=controlId, objects=mapObjects})  -- TODO: convert into stream
  --guihooks.triggerStream('NavigationMapUpdate', {controlID=controlId, objects=mapObjects})
end

local function getNodesMinified ()
  -- WARNIGN: use with caution
  -- the problem with this function is that as soon as you want to use the navigation to somewhere you don't have the correct name anymore, unless you either send them here as well or store this here :/
  local tmpmap = map.getMap()
  -- local tmpmap = deepcopy(m) -- since we are always just create a new object out of primitive data types in the function below we don't need this copy here
  local oldSize = tostring(string.len(jsonEncode(tmpmap.nodes)))
  local newNodes = {}
  local counter = 1
  local nameMap = {}

  -- we are just renaming the nodes and references inside the links here since we don't care about the names anyway
  for k, _ in pairs(tmpmap.nodes) do
    nameMap[k] = counter
    counter = counter + 1
  end

  for k, v in pairs(tmpmap.nodes) do
    newNodes[nameMap[k]] = {
      -- pos = {math.floor(v.pos.x * 1000) / 1000, math.floor(v.pos.y * 1000) / 1000}, -- v.pos.z}, 3d is not used in ui atm anyway
      pos = {v.pos.x, v.pos.y}, -- v.pos.z}, 3d is not used in ui atm anyway
      rad = v.radius
    }
    newNodes[nameMap[k]].to = {}
    for j, w in pairs(v.links) do
      table.insert(newNodes[nameMap[k]].to, {nameMap[j], w.drivability, w.oneWay})
    end
  end
  -- print('new node list size (char): ' .. tostring(string.len(jsonEncode(newNodes))) .. ' (used to be: ' .. oldSize .. ', nr nodes: '.. tostring(counter - 2) .. ')')
  return newNodes
end

local function getNodes ()
  local tmpmap = map.getMap()
  -- local tmpmap = deepcopy(m) -- since we are always just create a new object out of primitive data types in the function below we don't need this copy here
  local newNodes = {}

  for k, v in pairs(tmpmap.nodes) do
    if not v.hiddenInNavi then
      newNodes[k] = {
        pos = {v.pos.x, v.pos.y}, -- v.pos.z}, 3d is not used in ui atm anyway
        radius = v.radius
      }
      newNodes[k].links = {}
      for j, w in pairs(v.links) do
        if not w.hiddenInNavi then
          newNodes[k].links[j] = {drivability = w.drivability, oneWay = w.oneWay}
        end
      end
    end
  end
  return newNodes
end

local function requestUIDashboardMap()
  print("Requesting UI Dashboard Map...")
  local d = {}
  d.nodes = getNodes()

  local terr = getObjectByClass("TerrainBlock")
  if terr then
    d.terrainOffset = vec3(terr:getPosition()):toTable()
    local blockSize = terr:getWorldBlockSize()
    d.terrainSize = vec3(blockSize, blockSize, terr.maxHeight):toTable()
    local minimapImage = terr.minimapImage -- minimapImage is a BString
    if minimapImage:startswith("/") then
      minimapImage = minimapImage:sub(2)
    end
    d.minimapImage = minimapImage -- minimapImage is a BString
    d.squareSize = terr:getSquareSize()
  end

  local tmp = getPointsOfInterest()
  if tmp then d.poi = tmp end
  guihooks.trigger('NavigationMap', d)
end

local function requestVehicleDashboardMap(dashboard, initmap)
  if not dashboard then return end
  local playerVehicle = be:getPlayerVehicle(0)
  if playerVehicle then
    local nodes = getNodes()
    local terr = getObjectByClass("TerrainBlock")
    if not terr then
      return
    end
    local minimapImage = terr.minimapImage -- minimapImage is a BString
    local blockSize = terr:getWorldBlockSize()
    if minimapImage:startswith("/") then
      minimapImage = minimapImage:sub(2)
    end

    local mapTable = {
      minimapImage = minimapImage,
      nodes = nodes,
      terrainOffset = vec3(terr:getPosition()):toTable(),
      terrainSize = vec3(blockSize, blockSize, terr.maxHeight):toTable(),
      squareSize = terr:getSquareSize(),
      time = os.date("%H") .. ":" .. os.date("%M") -- done to prevent seconds from being sent.
    }

    playerVehicle:queueJSUITexture(dashboard, string.format("%s(%s)", initmap or "map.setData", jsonEncode(mapTable)))
  end
end

local function onVehicleSwitched(oid, nid)
  -- we need the tracking information for the ui navigation, so enable it
  --if oid ~= -1 then
  --  local veh = scenetree.findObject(oid)
  --  if veh then
  --    veh:queueLuaCommand("mapmgr.enableTracking()")
  --  end
  --end
  --if nid ~= -1 then
   -- local veh = scenetree.findObject(nid)
   -- if veh then
      --veh:queueLuaCommand("mapmgr.enableTracking()")
   -- end
  --end
end

local function onExtensionLoaded ()
  guihooks.trigger('RouteUpdate', {})
end

-- public interface
M.onGuiUpdate = onGuiUpdate
M.onVehicleSwitched = onVehicleSwitched


M.requestUIDashboardMap = requestUIDashboardMap
M.requestVehicleDashboardMap = requestVehicleDashboardMap

M.findClosestRoad = findClosestRoad
M.route_start = route_start
M.route_end = route_end
M.route_requestStatus = route_update

-- dev things
M.planRoute = planRoute
M.getBusStops = getBusStops

M.getSpawnpoints = getSpawnpoints
M.getPointsOfInterest = getPointsOfInterest
M.requestMissions = sendMissions
M.getMissions = getMissions
M.setMissions = setMissions
M.requestPoi = requestPoi

M.onExtensionLoaded = onExtensionLoaded

return M
