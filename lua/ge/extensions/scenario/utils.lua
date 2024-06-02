local M = {}

local raceMarker = require("scenario/race_marker")

local rallyInitd = false
local rallyPaused = false

local logTag = "rallyMode"
local rallyCfgFile = "/settings/rallyconfig.ini"
local symbolsDir = "/art/symbols/"
local last = 0
local rallyEnd = 0
local prefix = ""
local suffix = ""
local nosuffix = false
local speakTimer = -1
local codriver = {}
local rally = {}
local allowedDists = {}
local corners = {}

-- Editable configuration options will go in this table
local rcfg = {}
local rallyInfo = {}

-- From http://lua-users.org/wiki/CsvUtils
local function fromCSV(s)
  s = s .. ',' -- ending comma
  local t = {} -- table to collect fields
  local fieldstart = 1
  repeat
    -- next field is quoted? (start with `"'?)
    if string.find(s, '^"', fieldstart) then
      local a, c
      local i = fieldstart
      repeat
        -- find closing quote
        a, i, c = string.find(s, '"("?)', i + 1)
      until c ~= '"' -- quote not followed by quote?
      if not i then error('unmatched "') end
      local f = string.sub(s, fieldstart + 1, i - 1)
      table.insert(t, (string.gsub(f, '""', '"')))
      fieldstart = string.find(s, ',', i) + 1
    else -- unquoted; find next comma
      local nexti = string.find(s, ',', fieldstart)
      table.insert(t, string.sub(s, fieldstart, nexti - 1))
      fieldstart = nexti + 1
    end
  until fieldstart > string.len(s)
  return t
end

local function fileExists(f)
  local f = io.open(f, "r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

local function strToBool(s)
  local b
  if s == "true" then
    b = true
  elseif s == "false" then
    b = false
  end
  return b
end

local function getPlayerPos()
  return core_vehicles.getCurrentVehicleDetails().current.position
end

local function getPlayerVelocity()
  -- Returns the velocity vector. Components are in m/s
  local playerVehicle = scenetree.findObject(be:getPlayerVehicleID(0))
  return playerVehicle:getVelocity()
end

local function getPlayerSpeed()
  -- Returns the norm of the velocity vector
  local playerVehicle = scenetree.findObject(be:getPlayerVehicleID(0))
  local velocity = playerVehicle:getVelocity()
  return velocity:lengthGuarded()
end

local function stageLength()
  return getDistBtw(1, rallyEnd)
end

local function getToFinish()
  return getDistFrom(rallyEnd)
end

local function getFromStart()
  return stageLength() - getToFinish()
end

local function tokm(x)
  local xkm = x / 1000
  return string.format("%.1f", xkm)
end

local function stringToWords(s)
  if s then
    local words = {}
    for w in s:gmatch("%S+") do table.insert(words, w) end
    return words
  end
end
