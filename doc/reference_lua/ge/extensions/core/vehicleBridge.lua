-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- This file is meant as a blackbock-communications extension for communicating with vlua.
-- all gameplay-related vlua-requests/functions should go through here.
-- see gameplayInterface.lua on vlua side.
local M = {}
M.vehicleData = {}

-- gets a new unique ID which can be used for callbacks from vlua.
local callbackId = 0
local function getNewCallbackId()
  callbackId = callbackId + 1
  return callbackId
end

local function valueChangedCallback(vehId, data)
  if not M.vehicleData[vehId] then return end
  for key, value in pairs(data) do
    M.vehicleData[vehId].data[key] = value
  end
end

-- gets called from vlua with the id of the callback and the requested data.
local callbacks = {}
local function callbackFromVlua(vehId, callbackId, ...)
  local deserializedData = deserialize(...)
  if deserializedData.failReason then
    log("E","","Callback with id " .. callbackId.." failed to execute on vehicle side: " .. dumps(deserializedData.failReason))
  end

  if callbackId == -2 then
    valueChangedCallback(vehId, deserializedData)
    return
  end
  if callbacks[callbackId] then
    callbacks[callbackId](deserializedData)
  end
  callbacks[callbackId] = nil
end

local function requestValue(veh, callback, ...)
  if not veh then
    log("E","","Tried requesting value without a vehicle!")
    return
  end
  local id = getNewCallbackId()
  callbacks[id] = callback
  local params = {}
  for k, p in ipairs({...}) do
    params[k] = serialize(p)
  end
  local cmd = string.format("extensions.gameplayInterface.getSystemData(0, %d, %s)", id, table.concat(params, ", "))
  log("D","","Sent request value to Vlua: " .. cmd)

  veh:queueLuaCommand(cmd)
end

local function registerValueChangeNotification(veh, electricsKey)
  if not veh then
    log("E","","Tried registerValueChangeNotification without a vehicle!")
    return
  end
  local vehicleId = veh:getId()
  if not M.vehicleData[vehicleId] then
    M.vehicleData[vehicleId] = {
      data = {},
      registeredCallbacks = {}
    }
  end
  if M.vehicleData[vehicleId].registeredCallbacks[electricsKey] then
    return
  end
  local id = getNewCallbackId()
  M.vehicleData[vehicleId].registeredCallbacks[electricsKey] = id
  local cmd = string.format("extensions.gameplayInterface.registerValueChangeNotification(0,%d,'%s')", id, electricsKey)
  log("D","","Registering for value change notification: " .. cmd)
  veh:queueLuaCommand(cmd)
end

local function unregisterValueChangeNotification(veh, electricsKey)
  if not veh then
    log("E","","Tried unregisterValueChangeNotification without a vehicle!")
    return
  end
  local vehicleId = veh:getId()
  if not M.vehicleData[vehicleId] then
    return
  end
  local id = M.vehicleData[vehicleId].registeredCallbacks[electricsKey]
  if id then
    local cmd = string.format("extensions.gameplayInterface.unregisterValueChangeNotification(0,%d,'%s')", id, electricsKey)
    log("D","","Unregistering for value change notification: " .. cmd)
    veh:queueLuaCommand(cmd)
    M.vehicleData[vehicleId].registeredCallbacks[electricsKey] = nil
  end
end

local function executeAction(veh, ...)
  if not veh then
    log("E","","Tried executing action without a vehicle!")
    return
  end
  local id = getNewCallbackId()
  local params = {}
  for k, p in ipairs({...}) do
    params[k] = serialize(p)
  end
  --if params[1] == 'setFreeze' then
    --print(debug.tracesimple())
  --end
  local cmd = string.format("extensions.gameplayInterface.executeAction(0,%d, %s)", id, table.concat(params, ", "))
  log("D","","Sent execute action to Vlua: " .. cmd)

  veh:queueLuaCommand(cmd)
end

local function getCachedVehicleData(vehId, key)
  if not M.vehicleData[vehId] then return nil end
  return M.vehicleData[vehId].data[key]
end

M.getCachedVehicleData = getCachedVehicleData
M.requestValue = requestValue
M.executeAction = executeAction
M.callbackFromVlua = callbackFromVlua
M.registerValueChangeNotification = registerValueChangeNotification
M.unregisterValueChangeNotification = unregisterValueChangeNotification
M.onVehicleDestroyed = function(id) M.vehicleData[id] = nil end
M.onVehicleReplaced = function(id) M.vehicleData[id] = nil end
return M