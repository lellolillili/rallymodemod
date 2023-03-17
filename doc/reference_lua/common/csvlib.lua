-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
--
-- Usage:
--
-- local csvfile = require('csvlib').newCSV("c1", "c2", "c3")  -- or .newTSV("c1", "c2", "c3") for Tab Separated Values
-- csvfile:add(1,2,3)
-- csvfile:add(5,6,7)
-- ...
--
-- csvfile:write()              -- writes csv_DATETIME.csv
-- csvfile:write("myname")      -- writes myname_DATETIME.csv
-- csvfile:write("myname.csv")  -- writes myname.csv

local M = {}

local buffer = require('string.buffer')
local byte = string.byte

local csvWriter = {}
csvWriter.__index = csvWriter

local function newXSV(delim, ...)
  local self = setmetatable({buf = buffer.new(), linedelim = "", delim = delim, delimnum = byte(delim, 1)}, csvWriter)
  local headercount = select('#', ...)
  if headercount ~= 0 then
    self:add(...)
    local header = {...}
    for i = 1, headercount do
      header[i] = #header[i] > 0 and tostring(header[i]):sub(1, 1) or "_"
    end
    self.headernym = table.concat(header)
  end
  return self
end

local function newCSV(...)
  return newXSV(",", ...)
end

local function newTSV(...)
  return newXSV("\t", ...)
end

function csvWriter:add(...)
  local delim, rundelim, buf = self.delim, self.linedelim, self.buf

  for i = 1, select('#', ...) do
    buf:put(rundelim)
    rundelim = delim

    local v = select(i, ...)
    local vtype = type(v)
    if vtype == 'number' then
      buf:putf('%.9g', v)
    elseif vtype == 'boolean' then
      buf:put(v and 1 or 0)
    else
      v = tostring(v)
      local raw = true
      for i1 = 1, #v do
        if byte(v, i1) == self.delimnum then
          buf:put( (v:gsub(delim, "  ")) ) -- gsub returns 2 values, parens are needed
          raw = false
          break
        end
      end
      if raw then buf:put( v ) end
    end
  end
  self.linedelim = '\n'
end

function csvWriter:dump()
  return tostring(self.buf)
end

function csvWriter:write(filename)
  local format = self.delim == ',' and 'csv' or 'tsv'
  filename = filename or self.headernym or format
  if filename:sub(-4, -4) ~= '.' then
    filename = string.format("%s_%s.%s", filename, os.date("%Y-%d-%mT%H_%M_%S"), format)
  end
  writeFile(filename, self:dump())
end

M.newCSV = newCSV
M.newTSV = newTSV
return M