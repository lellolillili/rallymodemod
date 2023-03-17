-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- various tools for libWebsocket

local M = {}

local function generateRandomData(size)
  local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
  local charTable = {}
  for c in chars:gmatch"." do
      table.insert(charTable, c)
  end
  local res = ''
  for i = 1, size do
    res = res .. charTable[math.random(1, #charTable)]
  end
  return res
end

local function testWSConnection(server, serverAddr, port, path, protocol)
  --BNGWebMgmt.setDebugEnabled(true)
  -- create some test Data
  local magicUp = generateRandomData(32)
  local magicDown = generateRandomData(32)

  -- create a test client and send some magic to the server
  local client = BNGWSClient.getOrCreate(serverAddr, port, path, protocol)
  client:sendData(magicUp)
  -- give the client and server time to establish the connection ...
  for i = 0, 3 do
    client:update()
    server:update()
  end
  -- look if the server received the magic
  local events = server:getPeerEvents()
  --dump({'server events: ', events})
  local res = false
  for _, e in ipairs(events) do
    if e.type == 'D' and e.msg == magicUp then
      -- received magic, send some back
      --print(">>> upload successful, testing download ...")
      server:sendData(e.peerId, magicDown)
      res = true
      break
    end
  end
  if not res then
    BNGWSClient.destroy(client)
    return false
  end
  -- give time to process
  for i = 0, 3 do
    client:update()
    server:update()
  end
  events = client:getPeerEvents()
  --dump({'client events: ', events})
  res = false
  for _, e in ipairs(events) do
    if e.type == 'D' and e.msg == magicDown then
      -- received magic, send some back
      --print(">>> download successful")
      res = true
      break
    end
  end
  if not res then
    BNGWSClient.destroy(client)
    return false
  end
  BNGWSClient.destroy(client)
  return res
end

local function createOrGetWS(listenAddr, port, path, protocolName, redirPage)
  local server = BNGWebWSServer.getOrCreate(listenAddr, port, path, protocolName, redirPage, false)

  local addresses = BNGWebWSServer.getNetworkAdapterAddresses()
  local chosenAddress = 'localhost'
  for _, addr in ipairs(addresses) do
    local desc = addr.description:lower()
    if desc:find('virtualbox') or desc:find('vmware') then
      goto continue
    end
    if testWSConnection(server, addr.ipv4Addr, port, '/', protocolName) then
      chosenAddress = addr.ipv4Addr
    end
    ::continue::
  end

  server:enableDataStreams()

  return server, chosenAddress
end


M.createOrGetWS = createOrGetWS

return M