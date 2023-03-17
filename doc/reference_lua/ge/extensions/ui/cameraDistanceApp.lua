-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local sphereColor = ColorF(1, 0, 0, 1)
local textColor = ColorF(1, 1, 1, 0.9)
local textBackgroundColor = ColorI(0, 0, 0, 128)

local function onUpdate(dtReal, dtSim, dtRaw)
  -- TODO: convert into stream
  local veh = be:getPlayerVehicle(0)
  if not veh then
    guihooks.trigger('cameraDistance', -1, "no vehicle")
    return
  end

  local vehPos = veh:getPosition()
  local camPos = getCameraPosition()

  debugDrawer:drawSphere(vehPos, 0.5, sphereColor)
  debugDrawer:drawTextAdvanced(vehPos, "camera distance target", textColor, true, false, textBackgroundColor)

  local distance = vehPos:distance(camPos)

  guihooks.trigger('cameraDistance', distance)
end

-- public interface
M.onUpdate = onUpdate

return M
