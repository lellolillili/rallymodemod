-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Settings:

-- Settings END, please do not change anything below
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local min = math.min
local max = math.max
local random = math.random

local qrencode = require("libs/luaqrcode/qrencode")

local M = {}

local logTag = 'remoteController'
local udpSocket = nil
local receive_sockets = {}

local ffi = require_optional('ffi')
if ffi then
  ffi.cdef[[
  typedef struct { float w, x, y, z; } ori_t;
  ]]
end

local listenPort = 4444 -- listening port for new conenctions and the port the apps listen on for UI packages
local appPort = listenPort + 1 -- port where the apps receive data on

local udpSocket = nil

-- Table of connected devices.
--  The keys are a string of the IP address
--  The values are the virtual devices instance id, and a control state dictionary ( button2=0, axis0=0.873, etc)
local virtualDevices = {}

-- The time of the last package received by each IP address
local lastPackageTimes = {}

-- The player number of each dev.deviceInst
local assignedPlayers = {}

local prevX = -1
local prevY = -1
local code = random(10000, 99999)
--local iosCode = 232664


local function getQRCode()
  if udpSocket == nil then
    udpSocket = socket.udp()
    if udpSocket:setsockname('*', listenPort) == nil then
      log('W', logTag, "Unable to open UDP Socket")
      udpSocket = nil
      return false
    end
    --ip, port = udpSocket:getsockname()
    udpSocket:settimeout(0)
    receive_sockets[0] = udpSocket
    log('I', logTag, "started with code "..code)
  end
  return code
end

local function onUpdate()
  -- TODO: move to 1 fps
  if not udpSocket then return end

  local currentTime = Engine.Platform.getSystemTimeMS()

  for ip, lastPackageTime in pairs(lastPackageTimes) do
    -- Unplug controller after a 10 seconds timeout
    if virtualDevices[ip] ~= nil and currentTime - lastPackageTime > 10000 then
      extensions.core_input_virtualInput.deleteDevice(virtualDevices[ip].deviceInst)
      virtualDevices[ip] = nil
    end
  end

  while true do
    --log('D', logTag, "getting data from ".. tostring(listenPort))
    local data, ip, listenPort = udpSocket:receivefrom(128)

    if not data then
      --log('D', logTag, "No data")
      return
    end
    lastPackageTimes[ip] = currentTime

    --udpSocket:setpeername(ip, port)
    --log('D', logTag, "got '" .. tostring(data) .. "' from "..tostring(ip) .. ":" .. tostring(listenPort))
    if(data:sub(0, 6) == 'beamng') then -- new device trying to connect
      local args = split(data, '|')
      --log('D', logTag, "data: " .. args[1] .. " : " .. args[2] .. " : " .. args[3])
      local deviceName = args[2]
      if deviceName == "" then
        deviceName = "Unknown"
      end
      log('D', logTag, "Got discovery package from device " .. deviceName ..  " with code " .. args[3])
      if not (args[3] == tostring(code)) then
        log('D', logTag, "Code doesn't match "..code..", ignoring package.")
      else
        if not virtualDevices[ip] then
          local nAxes = 1
          local nButtons = 2
          local nPovs = 0
          local deviceInst = extensions.core_input_virtualInput.createDevice(deviceName, "bngremotectrlv1", nAxes, nButtons, nPovs)
          if not deviceInst or deviceInst < 0 then
            log('E', logTag, 'unable to create remote controller input')
          else
            virtualDevices[ip] = { deviceInst = deviceInst, state = {} }
          end
        end
        if virtualDevices[ip] ~= nil then
          log('D', logTag, 'sending hello back to: ' .. ip .. ':' .. appPort)
          local response = "beamng|" .. args[3]
          udpSocket:sendto(response, ip, appPort)
        end
      end
    elseif virtualDevices[ip] ~= nil then
      local orientation = ffi.new("ori_t")
      -- notice the reverse - for the network endian byte order
      ffi.copy(orientation, data:reverse(), ffi.sizeof(orientation))


      --log('D', logTag, 'got data: ' .. orientation.x .. ', ' .. orientation.y .. ', ' .. orientation.z.. ', ' .. orientation.w)

      --log('D', logTag, "Got input package")
      --log('D', logTag, "Orientation: "..floor(orientation.x * 100)..", "..floor(orientation.y*100)..", "..floor(orientation.z*100))
      --log('D', logTag, string.format("Orientation: %0.2f, %0.2f, %0.2f", orientation.x, orientation.y, orientation.z))

      local dev = virtualDevices[ip]

      -- ask the vehicle to send the UI data to the target
      local vehicle = assignedPlayers[dev.deviceInst] and be:getPlayerVehicle(assignedPlayers[dev.deviceInst]) or nil
      if vehicle then
        -- we reuse the outgauge extension for updating the user interface of the app
        vehicle:queueLuaCommand('if outgauge then outgauge.sendPackage("' .. ip .. '", ' .. appPort .. ', ' .. orientation.w .. ') end')
      end

      -- normalize data
      orientation.x = min(1, max(0, orientation.x))
      orientation.y = min(1, max(0, orientation.y))
      orientation.z = min(1, max(0, orientation.z))

      -- send the received input events to the vehicle
      local state = {
        button0 = (orientation.x > 0.5) and 1 or 0,
        button1 = (orientation.y > 0.5) and 1 or 0,
        axis0 = orientation.z
      }
      if dev.state.button0 ~= state.button0 then extensions.core_input_virtualInput.emit(dev.deviceInst, "button", 0, (state.button0 > 0.5) and "down" or "up", state.button0) end
      if dev.state.button1 ~= state.button1 then extensions.core_input_virtualInput.emit(dev.deviceInst, "button", 1, (state.button1 > 0.5) and "down" or "up", state.button1) end
      if dev.state.axis0   ~= state.axis0   then extensions.core_input_virtualInput.emit(dev.deviceInst,   "axis", 0,                                 "change", state.axis0  ) end
      dev.state = state
    end
  end
end

local function onExtensionLoaded()
  if not ffi then
    log('E', logTag, 'remote controller requires FFi to work')
    return false
  end
  return true
end

local function onInputBindingsChanged(players)
  for device, player in pairs(players) do
    for _, dev in pairs(virtualDevices) do
      if "vinput"..dev.deviceInst == device then
        assignedPlayers[dev.deviceInst] = player
      end
    end
  end
end

local function devicesConnected ()
  return not tableIsEmpty(virtualDevices)
end

M.onUpdate = onUpdate
M.onExtensionLoaded = onExtensionLoaded
M.onFirstUpdate = onFirstUpdate
M.onInputBindingsChanged = onInputBindingsChanged
M.getQRCode = getQRCode
M.devicesConnected = devicesConnected

return M
