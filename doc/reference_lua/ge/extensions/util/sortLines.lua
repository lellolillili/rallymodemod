-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local _log = log

local function log(level, msg)
  _log(level, 'sortLines', msg)
end

local function lineCmp(a, b)
  return a[1] < b[1]
end

M.handleFile = function(path)
  log('I', 'Handling file: ' .. path)
  local content = readFile(path)
  local lines = {}
  for line in content:gmatch('([^\n]*)\n?') do
    local obj = jsonDecode(line)
    local name = ''
    if obj.name then
      name = obj.name
    end
    table.insert(lines, {name, line})
  end

  table.sort(lines, lineCmp)

  local handle = io.open(path, 'w')
  for i, line in ipairs(lines) do
    if string.len(line[2]) > 0 then
      handle:write(line[2] .. '\n')
    end
  end
  handle:close()
end

M.handleLevel = function(level)
  local path = '/levels/' .. level .. '/main/MissionGroup/Audio/'
  log('I', 'Handling files in: ' .. path)
  local targets = FS:findFiles(path, '*.json', 1, true, true)
  for i, target in ipairs(targets) do
    M.handleFile(target)
  end
end

return M