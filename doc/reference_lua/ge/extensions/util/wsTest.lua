-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- How to use: extensions.load('util_wsTest')

local M = {}

local port = 8083
local protocolName = 'bng-test'

local wsUtils = require('utils/wsUtils')

local server
local chosenAddress

local function onExtensionLoaded()
  server, chosenAddress = wsUtils.createOrGetWS('any', port, './ui/entrypoints/util_wsTest/', protocolName, '/ui/entrypoints/util_wsTest/index.html')
  print('wsTest webserver running at: http://' .. chosenAddress .. ':' .. tostring(port) .. ' (listening on all addresses)')
  --openWebBrowser('http://' .. chosenAddress .. ':'.. tostring(port))
end

local function onExtensionUnloaded()
  if server then
    BNGWebWSServer.destroy(server)
    server = nil
  end
end

local function exec(cmd)
  local func, err  = loadstring("return " .. cmd)
  if func then
    if type(debug.traceback) ~= "function" then
      print("*** LUA TRACEBACK BROKEN ***")
    end
    local ok, result = xpcall(func, debug.traceback)
    if not ok then
      return "Error: " .. result
    else
      return result
    end
  else
    return "Error: " .. err
  end
end

local function _handleData(evt, data)
  if data.type == 'execGELua' then
    local cmdRes = exec(data.cmd)
    server:sendData(evt.peerId, jsonEncode({ result = cmdRes}))
  elseif data.type == 'reloadGELua' then
    Lua:requestReload()
  elseif data.type == 'reloadCEF' then
    reloadUI()
  elseif data.type == 'toggleCEFDevConsole' then
    toggleCEFDevConsole()
  elseif data.type == 'bandwidthDown' then
    server:sendData(evt.peerId, "ack")
  elseif data.type == 'bandwidthUpStart' then
    server:sendData(evt.peerId, "ack")
    local testDataChunk = generateRandomData(data.size / 100)
    local testData = ''
    for i = 0, 10 do
      testData = testData .. testDataChunk
    end
    server:sendData(evt.peerId, jsonEncode({ type = "bandwidthUp", data = testData}))
    server:sendData(evt.peerId, "done")
  else
    log('E', '', 'unknown command: ' .. dumps(data))
  end
end

local function onUpdate()
  if not server then return end
  local events = server:getPeerEvents()
  if #events == 0 then return end
  for _, evt in ipairs(events) do
    if evt.type == 'D' and evt.msg ~= '' then
      --dump({"event: ", evt})
      if evt.msg == 'ping' then
        server:sendData(evt.peerId, "pong")
      else
        local data = jsonDecode(evt.msg)
        if data then
          _handleData(evt, data)
        else
          log('E', '', 'Unable to decode json in ws data: ' .. dumps(e))
        end
      end
    end
    --server:sendData(e.peerId, "got data: " .. e.type .. ' / ' .. tostring(e.msg) .. ' / you are client: ' .. tostring(e.peerId))
  end
  server:update()
end


-- check if we need to enable/disable ourself
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onUpdate = onUpdate

return M
