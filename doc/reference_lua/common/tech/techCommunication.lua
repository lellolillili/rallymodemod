-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local mp = require('libs/lua-MessagePack/MessagePack')
local socket = require('libs/luasocket/socket.socket')

local recvBufs = {}   -- used only when recieving messages.
local BUF_SIZE = 131072
local HEADER_SIZE = 4

M.protocolVersion = 'v1.20'

local function packUnsignedInt32Network(n)
  return string.char(math.floor(n / 0x1000000), math.floor(n / 0x10000) % 0x100, math.floor(n / 0x100) % 0x100, n % 0x100)
end

local function unpackUnsignedInt32Network(c)
  local b1, b2, b3, b4 = c:byte(1, 4)
  return ((b1 * 0x100 + b2) * 0x100 + b3) * 0x100 + b4
end

-- Simple set implementation from the LuaSocket samples
M.newSet = function()
  local reverse = {}
  local set = {}
  return setmetatable(set, {__index = {
    insert = function(set, value)
      if not reverse[value] then
        table.insert(set, value)
        reverse[value] = #set
      end
    end,
    remove = function(set, value)
      local index = reverse[value]
      if index then
        reverse[value] = nil
        local top = table.remove(set)
        if top ~= value then
          reverse[top] = index
          set[index] = top
        end
      end
    end
  }})
end

M.checkForClients = function(servers)
  local ret = {}
  local readable, _, err = socket.select(servers, nil, 0)
  for _, input in ipairs(readable) do
    local client = input:accept()
    table.insert(ret, client)
  end
  return ret
end

M.receive = function(skt)
  local lengthPacked, err = skt:receive(4)

  if err then
    log('E', 'ResearchCom', 'Error reading from socket: '..tostring(err))
    return nil, err
  end

  table.clear(recvBufs)

  local length = unpackUnsignedInt32Network(lengthPacked)
  if length == 808464432 then -- potentially a client with an old version of BeamNGpy, 808464432 = '0000' unpacked as uint32
    local received, err = skt:receive(12) -- length used to be encoded in first 16 bytes as a string
    local lengthRest = tonumber(received)
    if err then
      log('E', 'ResearchCom', 'Error reading from socket: '..tostring(err))
      return nil, err
    end

    if lengthRest == 34 then -- the length of a Hello message from an old client
      log('E', 'ResearchCom', 'Unsupported client version. Disconnecting client.')
      M.sendLegacyError(skt, 'Unsupported client version. Please use the version of BeamNGpy corresponding to this release of BeamNG.')
      return nil, err
    else -- it was not a Hello message, add the data to the received buffer
      table.insert(recvBufs, received)
      length = length - #received
    end
  end

  while true do
    local received, err = skt:receive(math.min(length, BUF_SIZE))
    if err then
      log('E', 'ResearchCom', 'Error reading from socket: '..tostring(err))
      return nil, err
    end

    table.insert(recvBufs, received)
    length = length - #received
    if length <= 0 then
      break
    end
  end
  if err then
    log('E', 'ResearchCom', 'Error reading from socket: '..tostring(err))
    return nil, err
  end

  return table.concat(recvBufs), nil
end

local Request = {}

M.checkMessages = function(E, clients)
  local message
  local readable, writable, err = socket.select(clients, clients, 0)
  local ret = true

  for i = 1, #readable do
    local skt = readable[i]

    if writable[skt] == nil then
      goto continue
    end

    message, err = M.receive(skt)

    if err ~= nil then
      clients:remove(skt)
      log('E', 'ResearchCom', 'Error reading from socket: ' .. tostring(skt) .. ' - ' .. tostring(err))
      goto continue
    end

    if message ~= nil then
      local request = Request:new(mp.unpack(message), skt)
      local msgType = request['type']
      if msgType ~= nil then
        msgType = 'handle' .. msgType
        local handler = E[msgType]
        if handler ~= nil then
          if handler(request) == false then
            ret = false
          end
        else
          extensions.hook('onSocketMessage', request)
        end
      else
        log('E', 'ResearchCom', 'Got message without message type: ' .. tostring(message))
        goto continue
      end
    end

    ::continue::
  end
  if #readable > 0 then
    return ret
  else
    return false
  end
end

M.sanitizeTable = function(tab)
  local ret = {}

  for k, v in pairs(tab) do
    k = type(k) == 'number' and k or tostring(k)

    local t =  type(v)

    if t == 'table' then
      ret[k] = M.sanitizeTable(v)
    end

    if t == 'vec3' then
      ret[k] = {v.x, v.y, v.z}
    end

    if t == 'quat' then
      ret[k] = {v.x, v.y, v.z, v.w}
    end

    if t == 'number' or t == 'boolean' or t == 'string' then
      ret[k] = v
    end
  end

  return ret
end

local function sendAll(skt, data, length)
  local index = 1
  while index < length do
    local sent, err = skt:send(data, index, length)
    if sent == nil then
      return err
    end
    index = sent + 1
  end
  return nil
end

M.sendLegacyError = function(skt, error) -- send an error to a legacy BeamNGpy client so the client can parse it
  local message = mp.pack({bngError = error})

  local length = #message
  local stringLength = string.format('%016d', length)
  message = stringLength .. message
  local err = sendAll(skt, message, #message)
  if err then
    log('E', 'ResearchCom', 'Error writing to socket: ' .. tostring(err))
    return
  end
end

M.sendMessage = function(skt, message)
  if skt == nil then
    return
  end

  message = mp.pack(message)
  local length = #message
  local lenPrefix = packUnsignedInt32Network(length)
  if length < 9000 then -- 6 * MTU
    message = lenPrefix .. message
    length = length + HEADER_SIZE
  else
    local err = sendAll(skt, lenPrefix, HEADER_SIZE)
    if err then
      log('E', 'ResearchCom', 'Error writing to socket: ' .. tostring(err))
      return
    end
  end

  local err = sendAll(skt, message, length)
  if err then
    log('E', 'ResearchCom', 'Error writing to socket: ' .. tostring(err))
    return
  end
end

function Request:new(o, skt)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  o.skt = skt
  return o
end

function Request:sendResponse(message)
  message['_id'] = self['_id']
  M.sendMessage(self.skt, message)
end

function Request:sendACK(type)
  local message = {type = type}
  self:sendResponse(message)
end

function Request:sendBNGError(message)
  local message = {bngError = message}
  self:sendResponse(message)
end

function Request:sendBNGValueError(message)
  local message = {bngValueError = message}
  self:sendResponse(message)
end

M.openServer = function(port)
  local server = assert(socket.bind('*', port))
  return server
end

return M
