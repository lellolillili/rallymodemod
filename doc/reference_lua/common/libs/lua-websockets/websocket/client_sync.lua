local socket = require'libs/luasocket/socket'
local sync = require'libs/lua-websockets/websocket.sync'
local tools = require'libs/lua-websockets/websocket.tools'
local ssl = nil -- require'libs/luasec/ssl'

local new = function(ws)
  ws =  ws or {}
  local self = {}

  self.sock_connect = function(self,host,port)
    self.sock = socket.tcp()
    if ws.timeout ~= nil then
      self.sock:settimeout(ws.timeout)
    end
    local _,err = self.sock:connect(host,port)
    if err then
      self.sock:close()
      return nil,err
    end
  end

  self.sock_send = function(self,...)
    return self.sock:send(...)
  end

  self.sock_receive = function(self,...)
    return self.sock:receive(...)
  end

  self.sock_close = function(self)
    --self.sock:shutdown() Causes errors?
    self.sock:close()
  end

  self.dohandshake = function(self,ssl_params)
    self.sock = ssl.wrap(self.sock, ssl_params)
    self.sock:dohandshake()
    return self.sock
  end

  self = sync.extend(self)
  return self
end

return new
