return setmetatable({},{__index = function(self, name)
  if name ~= 'copas' and name ~= 'ev' then return end -- we do random lookups here, so do not try to load random files there ...
  local backend = require("libs/lua-websockets/websocket/server_" .. name)
  self[name] = backend
  return backend
end})
