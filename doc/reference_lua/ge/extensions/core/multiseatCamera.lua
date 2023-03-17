-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

require("utils")
local M = {}

local lastLocation = vec3(0, 0, 0);

local function onUpdate()
  local i = 0
  local meanLocation = vec3(0, 0, 0)
  local meanDirection = vec3(0, 0, 0)
  local maxDistance = 0
  local pos = vec3(0, 0, 0)
  local plvehicles = tableValuesAsLookupDict(extensions.core_input_bindings.getAssignedPlayers())

  -- avg position
  for pid, _ in pairs(plvehicles) do
    local k = be:getPlayerVehicleID(pid)
    local v = map.objects[k]
    if v ~= nil then
      meanLocation = meanLocation + v.pos
      if be:getPlayerVehicleID(0) == k then
        pos = v.pos
      end
      i = i + 1
    end
  end
  meanLocation = meanLocation / math.max(1, i)

  -- max distance
  for k, _ in pairs(plvehicles) do
    local v = map.objects[be:getPlayerVehicleID(k)]
    if v ~= nil then
      maxDistance = math.max(maxDistance, meanLocation:squaredDistance(v.pos))
    end
  end
  maxDistance = math.sqrt(maxDistance) * 2 + 10

  meanDirection = meanLocation - lastLocation - pos
  lastLocation = meanLocation

  local targetCenter = meanLocation-pos

  local left = vec3(-meanDirection.y, meanDirection.x, targetCenter.z)
  local back = vec3(meanDirection.x, -meanDirection.y, targetCenter.z)

  if core_camera then
    local vid = be:getPlayerVehicleID(0)
    core_camera.setTargetMode(vid, 'notCenter', vec3(0, 0, 0))
    core_camera.setDistance(vid, maxDistance)
    core_camera.setFOV(vid, 40)
    core_camera.setRef(vid, targetCenter, left, back)
  end
end

local function setEnabled(enabled)
  M.onUpdate = enabled and onUpdate or nop
  if not core_camera then return end
  if enabled then
    core_camera.resetCameraByID(be:getPlayerVehicleID(0))
  else
    for k, v in ipairs(getAllVehicles()) do
      local vid = v:getId()
      core_camera.resetConfiguration()
      core_camera.setRef(vid, nil, nil, nil)
      core_camera.resetCameraByID(vid)
    end
  end
end

local multiseatEnabled
local function onSettingsChanged()
  local newMultiseatEnabled = settings.getValue("multiseat")
  if newMultiseatEnabled == multiseatEnabled then return end
  multiseatEnabled = newMultiseatEnabled
  setEnabled(multiseatEnabled)
end

M.onSettingsChanged = onSettingsChanged
M.onUpdate = nop

return M
