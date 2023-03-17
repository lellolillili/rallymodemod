-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- extensions.load('test_asioTCP')

local M = {}

local server


local time = 0
local timeLastPrint = 0
local totalPackages = 0
local lastTotalPackages = 0
local totalBytes = 0
local lastTotalBytes = 0

local function onExtensionLoaded()
  print("loaded :D")
  server = createNetworkServer('tcp', 7000)
end

local function onPreRender(dtReal, dtSim, dtRaw)
  time = time + dtReal

  local res = server:receive()
  if not res then return end

  --dump(res)

  totalPackages = totalPackages + #res
  local bytesThisFrame = 0
  for connection, dataChunks in pairs(res) do
    for _, data in ipairs(dataChunks) do
      bytesThisFrame = bytesThisFrame + string.len(data)
    end
    totalBytes = totalBytes + bytesThisFrame
    connection:send('ok, received ' .. tostring(bytesThisFrame) .. ' bytes from you :)')
  end

  local dt = time - timeLastPrint
  if dt > 1 then
    timeLastPrint = time
    local packageDiff = totalPackages - lastTotalPackages
    lastTotalPackages = totalPackages
    local byteDiff = totalBytes - lastTotalBytes
    lastTotalBytes = totalBytes
    dump({'received data: ', packageDiff, bytes_to_string(byteDiff), bytes_to_string(byteDiff / dt) .. '/s'})
  end
end

M.onExtensionLoaded = onExtensionLoaded
M.onPreRender = onPreRender

return M
