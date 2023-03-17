-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = { state = {} }
M.state.cefVisible = true

local hit
local t = 0

local enabled = true
local cursorVisible = true

local fpsLimiter = newFPSLimiter(20)

local function isAnyControllerConnected()
  local inputDevices = WinInput.getRegisteredDevices()
  for _, d in ipairs(inputDevices) do
    if d ~= 'mouse0' and d ~= 'keyboard0' then
      return true
    end
  end
  return false
end

local function onPreRender(dtReal, dtSim, dtRaw)
  if not M.state.cefVisible then return end

  local shouldBeEnabled = not photoModeOpen and (cursorVisible or (isAnyControllerConnected() and core_camera.timeSinceLastRotation() < 1000))

  VehicleTrigger.renderFilterObjectId = 0
  local isUnicycle = core_vehicle_manager and core_vehicle_manager.getPlayerVehicleData() and core_vehicle_manager.getPlayerVehicleData().mainPartName == "unicycle"
  if not isUnicycle then
    local playerVId = be:getPlayerVehicleID(0)
    VehicleTrigger.renderFilterObjectId = playerVId
  end

  VehicleTrigger.renderingEnabled = shouldBeEnabled
  enabled = shouldBeEnabled

  if not enabled then return end

  if fpsLimiter:update(dtReal) then
    -- allow the c++ classes to draw the alpha according to the distance to this ray
    be:triggerRaycastClosest(cursorVisible)
  end
end

local function queueCmd(vehId, cmd)
  local vehObj = scenetree.findObject(vehId)
  if vehObj then
    vehObj:queueLuaCommand(cmd)
  end
end

local function triggerEvent(actionStr, actionValue, hit, t, vdata)
  if not vdata.triggerEventLinksDict
    or type(vdata.triggerEventLinksDict[hit.t]) ~= 'table'
    or type(vdata.triggerEventLinksDict[hit.t][actionStr]) ~= 'table' then
      return
  end

  -- TODO: this is overly simplistic and serves as a prototype :)
  for _, lnk in pairs(vdata.triggerEventLinksDict[hit.t][actionStr] or {}) do
    local evt = lnk.targetEvent
    if evt.onDown and actionValue == 1 then
      queueCmd(hit.v, evt.onDown)
    elseif evt.onUp and actionValue == 0 then
      queueCmd(hit.v, evt.onUp)
    elseif evt.onChange then
      local cmdStr = evt.onChange:gsub("VALUE", tostring(actionValue))
      queueCmd(hit.v, cmdStr)
    end
  end
end

local function onActionEvent(num, state)
  if not enabled then return end
  hit = be:triggerRaycastClosest(cursorVisible)
  if not hit then return end

  local vData = extensions.core_vehicle_manager.getVehicleData(hit.v)
  if vData and vData.vdata and type(vData.vdata.triggers) == 'table' then
    local trigger = vData.vdata.triggers[hit.t]
    if trigger then
      triggerEvent('action' .. tostring(num), state, hit, trigger, vData.vdata)
    end
  end
end

local function onCursorVisibilityChanged(visible)
  if VehicleTrigger.debug then visible = true end -- always visible in debug mode
  cursorVisible = visible
end

local function onCefVisibilityChanged(cefVisible)
  M.state.cefVisible = cefVisible
  VehicleTrigger.renderingEnabled = M.state.cefVisible
end

M.onCefVisibilityChanged = onCefVisibilityChanged
M.onPreRender = onPreRender
M.onActionEvent = onActionEvent
M.onCursorVisibilityChanged = onCursorVisibilityChanged

return M
