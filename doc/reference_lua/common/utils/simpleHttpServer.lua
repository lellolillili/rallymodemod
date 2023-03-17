-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this is a tiny HTTP server
-- IT IS NOT WRITTEN FOR SECURITY: only run it in safe environments
-- IT IS NOT WRITTEN FOR PERFORMANCE: it is slow, will only serve small files and it will break easily

--[[ example usage:
    -- start
    local ws = require('utils/simpleHttpServer')
    local listenHost = '127.0.0.1'
    local httpListenPort = 8080
    ws.start(listenHost, httpListenPort, '/', nil, function(req, path)
      return {
        httpPort = httpListenPort,
        wsPort = httpListenPort + 1,
        host = listenHost,
      }
    end)
    print('created http server')

--]]

local M = {}

local bindhost = 'localhost'
local bindport = 23512
local fileroot = nil

local tcp_socket = nil

local socket = require("socket.socket")
local url  = require("socket.url")
local ltn12  = require("ltn12")
local templatingSystem = require("libs/resty/template")
--templatingSystem:caching(false)

ltn12.BLOCKSIZE = 32768 -- 4096

local clients_read = {}
local clients_write = {}
local sinks = {}
local handlers = {}
local argsCallback = nil

-- super hacky mime type detection based on file extensions
local mimetypes = {
  html = 'text/html',
  htmlt = 'text/html', -- our templating system
  js = 'application/x-javascript',
  jst = 'application/x-javascript',  -- our templating system
  css = 'text/css',
  jpg = 'image/jpeg',
  gif = 'image/gif',
  png = 'image/png',
  pdf = 'application/pdf',
  txt = 'text/plain',
  json = 'application/json',
  otf = 'font/opentype',
  eot = 'application/vnd.ms-fontobject',
  ttf = 'application/x-font-truetype',
  svg = 'image/svg+xml',
  woff = 'application/font-woff',
  woff2 = 'application/font-woff2',
}

local function start(_bindhost, _bindport, _fileroot, _handlers, _argsCallback)
  bindhost = _bindhost
  bindport = _bindport
  fileroot = _fileroot
  handlers = _handlers or {}
  argsCallback = _argsCallback

  tcp_socket = socket.tcp()
  local res, err = tcp_socket:bind(bindhost, bindport)
  if res == nil then
    log('E', 'simpleHttpServer', "unable to create webserver: " .. err)
    if tcp_socket then
      tcp_socket:close()
    end
    tcp_socket = nil
    return
  end
  tcp_socket:settimeout(0, 't')
  tcp_socket:listen()
  log('I', 'simpleHttpServer', "Simple HTTP WebServer running on port "..bindport)
end

local function stop()
  if tcp_socket then
    tcp_socket:close()
  end
  log('D', 'simpleHttpServer', "Simple HTTP WebServer closed on port "..bindport)
end

local function receiveRequest(c)
  -- receive first line only
  local line, err = c:receive()
  if err then
    -- 'timeout'
    -- TODO: FIXME: close and remove the connection also from our side
    if err == 'closed' then return end
    log('E', 'simpleHttpServer', "client.receive error: " .. tostring(err))
    return
  end
  -- process URI's in that
  for uri in string.gmatch(line, "GET (/[^ ]*) HTTP/[0-9].[0-9]") do
    local headers = {}
    while true do
      local line, err = c:receive()
      if err then
        -- 'timeout'
        -- TODO: FIXME: close and remove the connection also from our side
        if err == 'closed' then return end
        log('E', 'simpleHttpServer', "client.receive error: " .. tostring(err))
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

local function response_error(state, message)
  return [[
HTTP/1.1 ]] .. (state or '404 Not Found') .. [[

Server: BeamNG.web/0.1.0
Connection: close

]] .. message or 'File not found'
end

local function get_file_extension(fn)
  local base, filename, ext = path.split(fn)
  if not ext then return end
  ext = string.lower(ext)
  return ext
end

local function get_mime_type(ext)
  if mimetypes[ext] then
    return mimetypes[ext]
  end
  return 'application/octet-stream'
end

local function serve_file(req, path)
  local fn = fileroot .. path
  if not FS:fileExists(fn) then
    -- existing?
    return response_error('404 Not Found', 'File not found: ' .. tostring(fn))
  end
  local s = FS:stat(fn)
  if not s then
    return response_error('500 Internal Server Error', 'Internal Server Error: unable to stat file: ' .. tostring(fn))
  end
  local ext = get_file_extension(fn)
  local mimetype = get_mime_type(ext)
  if not mimetype then
    return response_error('500 Internal Server Error', 'Internal Server Error: unable to get mime type: ' .. tostring(fn))
  end

  -- compile the response
  local body
  if ext == 'htmlt' or ext == 'jst' and argsCallback then
    body = templatingSystem.renderReturn(fn, argsCallback(req, path))
  else
    body = readFile(fn)
  end

  return [[
HTTP/1.1 200 OK
Server: BeamNG.web/0.1.0
Connection: close
Content-Length: ]] .. string.len(body) .. [[

Content-Type: ]] .. mimetype .. [[


]] .. body
end

local function serve_json(data)
  local s = jsonEncode(data)
  return [[
HTTP/1.1 200 OK
Server: BeamNG.web/0.1.0
Connection: close
Content-Length: ]] .. string.len(s) .. [[
Content-Type: application/json

]] .. s
end

local function handle(req)
  --print('new request: ' .. dumps(req))

  if not req.uri or not req.uri.path or req.uri.path == '/' then
    -- serve index.html
    req.uri = { path = '/index.html'}
  end
  -- pseudosecurity
  req.uri.path = req.uri.path:gsub("\\.\\.", '') -- replace any '..' with ''
  req.uri.path = req.uri.path:gsub("//", '/') -- replace any '//' with '/'

  -- simple file server
  for _, v in pairs(handlers) do
    --print("** " .. tostring(req.uri.path) .. ' ~= ' .. tostring(v[1]))
    local res = {string.match(req.uri.path, v[1])}
    if #res > 0 then
      local res = v[2](req, res)
      if type(res) == 'table' then
        return serve_json(res)
      end
      return res
    end
  end

  -- clean up potential problems
  return serve_file(req, req.uri.path)
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

    local response = handle(request)
    local srcSink = ltn12.source.string(response)
    local sink = socket.sink('close-when-done', c)
    table.insert(sinks, {c, srcSink, sink})
    ::continue::
  end

  -- now pump the data
  local newList = {}
  for i, sinkData in ipairs(sinks) do
    if write[sinkData[1]] then
      local res, err = ltn12.pump.step(sinkData[2], sinkData[3])
      if res then
        table.insert(newList, sinkData)
      end
    end
  end
  sinks = newList
end

-- public interface
M.start = start
M.stop = stop
M.update = update

return M


--[[
handler example:
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
    }
  end},
}
--]]

