-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local udpSocket = nil
local port = 22137

local function onFirstUpdate()
    udpSocket = socket.udp()
    if udpSocket:setsockname('127.0.0.1', port) == nil then
        log('W', "schemeCommandServer", "Unable to open UDP Socket")
        udpSocket = nil
        return false
    end
    udpSocket:settimeout(0)
    log('D', "schemeCommandServer", "started")
end

local function onUpdate()
    if not udpSocket then return end

    local data, ip, port = udpSocket:receivefrom(4096)
    if not data then return end

    log('D', "schemeCommandServer", "got '" .. tostring(data) .. "' from "..tostring(ip) .. ":" .. tostring(port))

    if string.startswith(data, 'beamng:') then
        commandhandler.onSchemeCommand(data:sub(8))
    end
end

M.onUpdate = onUpdate
M.onFirstUpdate = onFirstUpdate

return M