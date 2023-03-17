-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this file adds core language features we use everywhere

-- tiny compatibility layer depending on if it is run
-- in plain Lua 5.1 - 5.3 or LuaJIT

loadstring = loadstring or load
unpack = unpack or table.unpack

-- notes for developers:
-- string.gfind = string.gmatch
-- table.getn = #

--== lua language core features below ==--

-- this function can load an optional module
function require_optional(module)
  local ok, m = pcall(require, module)
  if ok then return m end
  return nil
end

-- unload a package/module
function unrequire(m)
  package.loaded[m] = nil
  _G[m] = nil
end

-- little snippet that enforces reloading of files
function rerequire(module)
  package.loaded[module] = nil
  local m = require(module)
  if not m then
    log('W', "rerequire", ">>> Module failed to load: " .. tostring(module).." <<<")
  end
  return m
end

-- use luajit extension table.clear and new if they exist, otherwise fallback to lua implementations
ffi = require_optional('ffi') -- this sets the global ffi variable

if not pcall(require, "table.clear") then
  table.clear = function(tab) for k, _ in pairs(tab) do tab[k] = nil end end
end

if not pcall(require, "table.new") then
  table.new = function() return {} end
end

function nop()
end
