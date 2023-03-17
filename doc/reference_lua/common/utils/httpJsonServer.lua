-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- simple server that can be used to implement a quick and dirty REST server
-- created by BeamNG

--[[ example usage:

local function handleServerRequest(request)
    --print("got request:")
    --dump(request)
    if not request.uri then return end -- returns 500

    if request.uri.path == 'v1/ping' then
        return {ok = true}

    elseif request.uri.path == 'v1/getData' then
        local data = prepareEditorData()
        --dump(data)
        return data
    end
    -- returning nil results in 500 error
end

local httpJsonServer = require('utils/httpJsonServer')

local port = 23512
local bindHost = 'localhost'
httpJsonServer.init(bindHost, port, handleServerRequest)

--]]

local M = {}

local bindhost = 'localhost'
local bindport = 23512
local callback = function() end

local tcp_socket = nil

local socket = require("socket.socket")
local url    = require("socket.url")
local ltn12  = require("ltn12")

ltn12.BLOCKSIZE = 4096

local clients_read = {}
local clients_write = {}
local sinks = {}

local function init(_bindhost, _bindport, _callback)
    bindhost = _bindhost
    bindport = _bindport
    callback = _callback

    tcp_socket = socket.tcp()
    res, err = tcp_socket:bind(bindhost, bindport)
    if res == nil then
        log('E', 'httpJsonServer', "unable to create webserver: " .. err)
    end
    tcp_socket:settimeout(0, 't')
    tcp_socket:listen()
    log('D', 'httpJsonServer', "Json HTTP WebServer running on port "..bindport)
end

local function receiveRequest(c)
    -- receive first line only
    local line, err = c:receive()
    if err then
        -- 'timeout'
        -- TODO: FIXME: close and remove the connection also from our side
        if err == 'closed' then return end
        log('E', 'httpJsonServer', "client.receive error: " .. tostring(err))
        return
    end
    -- process URI's in that
    for uri in string.gmatch(line, "GET /([^ ]*) HTTP/[0-9].[0-9]") do
        local headers = {}
        while true do
            local line, err = c:receive()
            if err then
                -- 'timeout'
                -- TODO: FIXME: close and remove the connection also from our side
                if err == 'closed' then return end
                log('E', 'httpJsonServer', "client.receive error: " .. tostring(err))
                return nil
            end
            if line == '' then
                break
            end
            local args = split(line, ':', 1)
            if #args == 2 then
                local key = string.lower(trim(args[1]))
                local value = trim(args[2])
                headers[key] = value
            end
        end
        local uri_parsed = url.parse(uri)
        return {uri = uri_parsed, headers = headers}
    end
    return nil
end

local function update()
    if not tcp_socket then return end

    -- accept new connections
    while true do
        local new_client = tcp_socket:accept()
        if new_client then
            --new_client:settimeout(0.1, 't')
            table.insert(clients_read,  new_client)
            table.insert(clients_write, new_client)
        else
            break
        end
    end

    local read, write, _ = socket.select(clients_read, clients_write, 0) -- _ = 'timeout' or nil, does not matter for our non-blocking usecase

    for _, c in ipairs(read) do
        if write[c] == nil then
            goto continue
        end

        c:settimeout(0.1, 't')

        local request = receiveRequest(c)
        if request == nil then
            goto continue
        end


        local reply = callback(request)
        if reply == nil then
            reply = {ok = false, error = 500}
        end
        local srcSink = ltn12.source.string(jsonEncode(reply))
        local sink = socket.sink('close-when-done', c)
        table.insert(sinks, {c, srcSink, sink})
        ::continue::
    end

    -- now pump the data
    local newList = {}
    for i, sinkData in ipairs(sinks) do
        if write[sinkData[1]] then
            local res, err = ltn12.pump.step(sinkData[2], sinkData[3])
            --print(tostring(res))
            --print(tostring(err))
            if res then
                table.insert(newList, sinkData)
            end
        end
    end
    sinks = newList
end

-- public interface
M.init   = init
M.update = update

return M