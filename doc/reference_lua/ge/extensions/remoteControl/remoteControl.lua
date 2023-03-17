-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local ws

local ip = '0.0.0.0'
local port = 8081

local vim -- virtual input manager
local deviceInst

local buttonState = false

local function onExtensionLoaded()
  ws = require('utils/simpleHttpServer')
  local httpListenPort = 8081
  local handlers = {
    -- example on how to handle arguments
    {'/hello/(%d+)', function(req, res)
      return 'hello world: ' .. tostring(res[1])
    end},
    -- example of simple json responding function
    {'/api/getInfo/', function()
      return {
        v = beamng_version,
        arch = beamng_arch,
        ip = ip,
        port = port,
      }
    end},
    {'/api/ping', function() return {'pong'} end},
    {'/api/btn', function()
      buttonState = not buttonState
      vim:emitEvent('vinput', deviceInst, "button", 0, "change", buttonState and 1 or 0)
      return {}
    end},
  }

  ws.start(ip, port, '/lua/ge/extensions/remoteControl/', handlers)
end

local timer = 0
local function onUpdate(dtReal, dtSim, dtRaw)
  timer = timer + dtReal
  ws.update()
  if vim then
    vim:emitEvent('vinput', deviceInst, "axis", 0, "change", (math.sin(timer) + 1) / 2)
  else
    vim = getVirtualInputManager()

    deviceInst = vim:registerDevice('httpcontrollerv1', 'bngremotectrlv1', 1, 2, 0)

    vim:emitEvent('vinput', deviceInst, "button", 0, "down", 1)
    vim:emitEvent('vinput', deviceInst, "button", 0, "up", 1)
    vim:emitEvent('vinput', deviceInst, "axis", 0, "change", 0.5)
  end
end

local function onExtensionUnloaded()
  if vim and deviceInst then
    vim:unregisterDevice('vinput' .. tostring(deviceInst))
  end
end

-- public interface
M.onExtensionUnloaded = onExtensionUnloaded
M.onExtensionLoaded = onExtensionLoaded
M.onFirstUpdate = onFirstUpdate
M.onUpdate = onUpdate

return M