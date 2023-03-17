-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- extensions.load('test_asioUDP')

local M = {}

local socket


local time = 0
local timeLastPrint = 0
local totalPackages = 0
local lastTotalPackages = 0
local totalBytes = 0
local lastTotalBytes = 0

local function onExtensionLoaded()
  print("loaded :D")
  socket = createNetworkServer('udp', 6000)
end

local function onPreRender(dtReal, dtSim, dtRaw)
  time = time + dtReal

  local res = socket:receive()
  if not res then return end

  totalPackages = totalPackages + #res
  for k, v in ipairs(res) do
    totalBytes = totalBytes + string.len(v[2])
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
