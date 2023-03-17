-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- How to use: extensions.load('ui_extApp')

local M = {}

local port = 8084
local protocolName = 'bng-ext-app-v1'

local wsUtils = require('utils/wsUtils')
local sm = getStreamManager()
local jsonEncodeFull = require('libs/lunajson/lunajson').encode -- slow but conform encoder

local server
local chosenAddress

local function updateUIData()
  local url = 'http://' .. chosenAddress .. ':'.. tostring(port)
  guihooks.trigger('externalUIURL', url)
end

local function onExtensionLoaded()
  server, chosenAddress = wsUtils.createOrGetWS('any', port, './', protocolName, '/ui/entrypoints/main/index.html')
  print('ext app webserver running at: http://' .. chosenAddress .. ':' .. tostring(port) .. ' (listening on all addresses)')
  updateUIData()
end

local function onExtensionUnloaded()
  if server then
    BNGWebWSServer.destroy(server)
    server = nil
  end
  guihooks.trigger('externalUIURL')
end

local function _handleData(evt, data)
  -- all stream data handles in c++ now
  log('E', '', 'unknown command: ' .. dumps(data))
end

local function onUpdate()
  if not server then return end

  -- collect ws events
  local events = server:getPeerEvents()
  if #events == 0 then return end

  for _, evt in ipairs(events) do
    --dump({"event: ", evt})
    if evt.type == 'D' and evt.msg ~= '' then
      local data = jsonDecode(evt.msg)
      if data then
        _handleData(evt, data)
      else
        log('E', '', 'Unable to decode json in ws data: ' .. dumps(evt))
      end
    end
  end
end

-- check if we need to enable/disable ourself
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onUpdate = onUpdate
M.requestUIData = updateUIData

return M
