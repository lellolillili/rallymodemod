-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local returns = {}
local buf = {}

--known problems: swallows nil's: `c.ProgressBar(0.4, nil, "FOO")` > `c.ProgressBar(0.4, "FOO")`


local function generateId(t, idCache)
  local id = ''
  for _, j in ipairs(t) do
    id = id .. '|' .. tostring(j)
  end
  if idCache[id] then
    idCache[id] = idCache[id] + 1
  else
    idCache[id] = 0
  end
  id = id .. '|' .. idCache[id]
  return id
end

local resIDCache = {}

local function funcWrap(name)
  M[name] = function(...)
    local args = {...}
    table.insert(args, 1, name) -- add function name
    table.insert(buf, args) -- add args
    local id = generateId(args, resIDCache)
    return unpack(returns[id] or {false})
  end
end

extensions.load('ui_imgui')
for k, v in pairs(ui_imgui) do
  funcWrap(k)
end

local function execute(buf)
  --jsonWriteFile('imgui_wire_test.json', buf, true)
  local resIDs = {}
  local results = {}
  for k, v in ipairs(buf) do
    local funcName = v[1]
    local id = generateId(v, resIDs)
    table.remove(v, 1) -- name
    local res = { ui_imgui[funcName](unpack(v)) }
    if #res > 0 then
      results[id] = res
    end
  end
  --dump(results)
  return results
end

M.clear = function()
  -- send buf to GE
  -- GE: execute
  returns = execute(buf)
  buf = {}
  resIDCache = {}
end

return M