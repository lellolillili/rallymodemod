-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local active

local updateTime = 0.05

local range = 100
local planetRadius = 5
local mass = -60000000000000
local forceMultiplier = 1

local function activate()
  if active then return end
  ui_message("ui.radialmenu2.funstuff.ForceField.activated", nil, "forceField")
  active = true
end

local function deactivate()
  if not active then return end
  for i = 0, be:getObjectCount()-1 do
    local veh = be:getObject(i)
    veh:queueLuaCommand("obj:setPlanets({})")
  end
  ui_message("ui.radialmenu2.funstuff.ForceField.deactivated", nil, "forceField")
  active = false
end

local function toggleActive()
  if active then
    deactivate()
  else
    activate()
  end
end

local lastUpdateTimer = updateTime
local function onUpdate(dtReal, dtSim, dtRaw)
  lastUpdateTimer = lastUpdateTimer + dtSim
  if not active or lastUpdateTimer < updateTime then return end
  local vehicle = be:getPlayerVehicle(0)
  local boundingBox = vehicle:getSpawnWorldOOBB()
  local halfExtents = boundingBox:getHalfExtents()
  local center = boundingBox:getCenter()
  local longestHalfExtent = math.max(math.max(halfExtents.x, halfExtents.y), halfExtents.y)
  local vehicleSizeFactor = longestHalfExtent/3

  local command = string.format('obj:setPlanets({%f, %f, %f, %d, %f})', center.x, center.y, center.z, planetRadius, mass * vehicleSizeFactor * forceMultiplier)

  for i = 0, be:getObjectCount()-1 do
    local veh = be:getObject(i)
    if veh:getId() ~= vehicle:getID() then
      veh:queueLuaCommand(command)
    end
  end
  lastUpdateTimer = 0
end

local function onClientEndMission()
  deactivate()
end

local function onVehicleSwitched()
  deactivate()
end

local function isActive()
  return active
end

local function onSerialize()
  deactivate()
end

local function onDeserialized()
end

local function onCareerActive(enabled)
  if enabled then
    deactivate()
  end
end

local function setForceMultiplier(factor)
  forceMultiplier = factor
end

local function getForceMultiplier()
  return forceMultiplier
end

M.activate = activate
M.deactivate = deactivate
M.toggleActive = toggleActive
M.isActive = isActive
M.setForceMultiplier = setForceMultiplier
M.getForceMultiplier = getForceMultiplier

M.onUpdate = onUpdate
M.onClientEndMission = onClientEndMission
M.onVehicleSwitched = onVehicleSwitched
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized
M.onCareerActive = onCareerActive

return M