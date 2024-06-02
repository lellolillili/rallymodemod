local raceMarker = require("scenario/race_marker")

local function getRallyWaypoints(prefix)
  -- I should probably use findclassobject instead
  for i = 1, maxIndex do
    local objectName = prefix .. i
    local obj = scenetree.findObject(objectName)
    if obj then
      local wp = {
                  name = obj:getName(),
                  pacenote = obj:getDynDataFieldbyName("pacenote", 0),
                  marker = obj:getDynDataFieldbyName("marker ", 0),
                  options = obj:getDynDataFieldbyName("options", 0),
                  group = obj:getGroup(),
                  id = obj:getId(),
                  Id = obj:getID(),
                  filename = obj:getFileName(),
                  position = obj:getPosition(),
                  positionXYZ = obj:getPositionXYZ(),
                  waypoint = obj
                 }
      rallyWaypoints[i] = wp
      consecutiveMisses = 0
    else
      consecutiveMisses = consecutiveMisses + 1
      if consecutiveMisses > maxHoleSize then
        break
      end
    end
  end
end

local function getDistFromByName(position, name)
  -- Gets distance between player and n-th waypoint
  -- TODO: get this from the rally data structure
  local wPos = scenetree.findObject(name):getPosition()
  local d = position:distance(wPos)
  return d
end

local function getClosestWaypoint()
  local wps = scenetree.findClassObjects('BeamNGWaypoint')
  local closest
  local mindist = 9999999999999999
  local playerPos = scenetree.findObject('thePlayer'):getPosition()
  for i, v in ipairs(wps) do
    local d = getDistFromByName(playerPos, v)
    if d < mindist then
      mindist = d
      closest = i
    end
  end
  if closest then
    local str = wps[closest]
    if str then
      local p, n = string.match(str, "(.-)(%d+)$")
      return {index = tonumber(n), prefix = p}
    else
      log("E", logTag, "Can't find closest waypoint string.")
    end
  else
    log("E", logTag, "Can't find closest waypoint.")
  end
end

-- this still grabs all the waypoints (which is probably useful), but it sets
-- the rally start to the correct one
local function getWaypointsFromHere()
  last = 0
  local closestWp = getClosestWaypoint()
  if closestWp then
    getRallyWaypoints(closestWp.prefix)
    last = closestWp.index
  end
end

-- TODO!!!: remove all game logic and/or make it conditional.
--   local max = #sc.BranchLapConfig must go!

-- This is mostly so that my quickraces don't break, but it makes sense that for
-- different game modes we might want to use different strategies to grab the
-- pacenotes.
local function getRallyWaypointsQuickrace()
  local wps = sc.BranchLapConfig
  for i, v in ipairs(wps) do
    local obj = scenetree.findObject(v)
    local wp = {
                name = obj:getName(),
                pacenote = obj:getDynDataFieldbyName("pacenote", 0),
                marker = obj:getDynDataFieldbyName("marker ", 0),
                options = obj:getDynDataFieldbyName("options", 0),
                group = obj:getGroup(),
                id = obj:getId(),
                Id = obj:getID(),
                filename = obj:getFileName(),
                position = obj:getPosition(),
                positionXYZ = obj:getPositionXYZ(),
                waypoint = obj
               }

    rallyWaypoints[i] = wp
  end
end

-- why, yes, this is silly, but because It's not clear to me if storing rally
-- data in waypoints is the way to go, I'll put all the getters in the same
-- place so we know what to change if we need to
local function getWaypointName(i)
  return rallyWaypoints[i].name
end

local function getWaypointPos(i)
  return rallyWaypoints[i].position
end

local function getCallFromWp(i)
  return rallyWaypoints[i].pacenote or "empty"
end

local function getOptionsFromWp(i)
  return rallyWaypoints[i].options or ""
end

local function getMarkerFromWp(i)
  return rallyWaypoints[i].marker
end

local function getDistBtw(m, n)
  -- Returns dist between the m-th and n-th waypoints
  local d = 0
  for i = m, n - 1, 1 do
    local a = getWaypointPos(i)
    local b = getWaypointPos(i + 1)
    d = d + a:distance(b)
  end
  return d
end

local function getCall(i)
  if rally[i] then return rally[i].call end
end

local function getMarker(i)
  if rally[i] then return rally[i].marker end
end

local function getOptions(i)
  if rally[i] then return rally[i].options end
end

local function getDistFrom(n)
  -- Gets distance between player and n-th waypoint
  -- TODO: get this from the rally data structure
  -- local i = getLastWaypointIndex() + 1
  local i = last + 1
  local wPos = getWaypointPos(i)
  local pPos = getPlayerPos()
  local d = pPos:distance(wPos) + getDistBtw(i, n)
  return d
end
