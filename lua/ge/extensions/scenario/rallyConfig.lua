-- Editable configuration options will go in this table
local rcfg = {}
local rallyInfo = {}

local function stats()
  local total = stageLength()
  local from = getFromStart()
  local to = getToFinish()
  local s = tostring(tokm(from) .. " / " .. tokm(total) .. " (km)")
  log("I", logTag, "Stats: " .. s)
  guihooks.trigger('Message',
    { ttl = 5, msg = s, category = "align", icon = "flag" })
end

local function checkConfig(c)
  -- TODO: this is used to check config of the ini file, and to check config
  -- from the UI. It should probably be a bit more sophisticated.

  if c == nil then return false end
  if rcfg == nil then return false end

  local b = false

  if type(c.breathLength) == "number" then
    b = true
  elseif type(c.timeOffset) == "number" then
    b = true
  elseif type(c.visual) == "bool" then
    b = true
  elseif type(c.volume) == "number" then
    b = true
  elseif type(c.iconSize) == "number" then
    b = true
  elseif type(c.iconPad) == "number" then
    b = true
  else
    b = false
  end
  return b
end

local function readCfgFromIni()
  -- Reads config from "rallyConfig.ini"
  log("I", logTag, [[========= Pacenote Director Started ========]])
  local c = loadIni(rallyCfgFile)
  rcfg.hideMarkers = c.hideMarkers
  rcfg.timeOffset = c.timeOffset
  rcfg.posOffset = c.posOffset
  rcfg.cutoff = c.cutoff
  rcfg.linkWord = c.linkWord
  rcfg.breathLength = c.breathLength
  rcfg.recce = c.recce
  rcfg.visual = c.visual
  rcfg.firstTime = c.firstTime
  rcfg.codriverDir = c.codriverDir
  rcfg.volume = c.volume
  rcfg.iconSize = c.iconSize
  rcfg.iconPad = c.iconPad
  if (checkConfig(rcfg) == false) then
    log("E", logTag, "Bad configuration file. Delete your local config file. Using some reasonable defaults instead.")
    rcfg.breathLength = 0.1
    rcfg.codriverDir = "Stu"
    rcfg.cutoff = 30
    rcfg.hideMarkers = true
    rcfg.linkWord = "into"
    rcfg.posOffset = 0
    rcfg.recce = true
    rcfg.timeOffset = 3.8
    rcfg.visual = true
    rcfg.firstTime = true
    rcfg.volume = 8
    rcfg.iconSize = 100
    rcfg.iconPad = 0
  else
    log("I", logTag, "Config file loaded.")
  end
end

local function getPacenoteFile()
  return ((getCurrentLevelIdentifier() .. ".pnt") or nil)
end

local function buildRally()
  -- All we need is already stored in rallyWaypoints. This uses
  -- that structure to generate parameters that are useful to the co-driver.
  -- Splitting those two things adds more flexibility while we're not sure
  -- whether we'll have a custom class for rally waypoints yet.
  local t = {}
  rallyEnd = #rallyWaypoints
  print("rallyend: " .. rallyEnd)
  for i = 1, rallyEnd, 1 do
    -- NOTE: what's default? It might be something I've been meaning to
    -- implement. I'll leave for now in case I'll see it again and remember.
    local isMarker = false
    if getMarkerFromWp(i) then isMarker = true end
    local r = {
      wpName = getWaypointName(i),
      marker = isMarker,
      options = getOptionsFromWp(i),
      pos = getWaypointPos(i),
      default = true
    }
    local s = getCallFromWp(i)
    if (s ~= nil) and (s ~= "empty") then
      for i, v in pairs(corners) do
        s = s:gsub(i, v)
      end

      r["call"] = s
      r["linked"] = isLinked(s)
      r["slow"] = isSlow(s)

      table.insert(t, r)
    else
      table.insert(t, r)
    end
  end

  local f = getPacenoteFile()
  local cfname = f
  local f = io.open(f, "r")
  if f then
    log("I", logTag,
      "Found a custom pacenotes file (\"" .. cfname ..
      "\"). \nDefault pacenotes will be overwritten wherever an alternative\
    is provided."
    )
    local d = {}
    for line in f:lines() do
      if string.len(line) > 0 then
        local firstChar = string.sub(line, 1, 1)
        if firstChar ~= '#' then
          local ind = tonumber(line:match("^%s*(%d+)%s*%-.*$"))
          if ind then
            local mrk = line:find("^%s*%d+%s*%-%s*marker")
            if mrk == nil then
              local s = line:match("^%s*%d+%s*%-%s*(.*)%s*;%s*.*")
              local opt = line:match("^%s*%d+%s*%-%s*.*%s*;%s*(.*)$") or ""
              if (s ~= nil) and (s ~= "empty") then

                for i, v in pairs(corners) do
                  s = s:gsub(i, v)
                end
                t[ind].call = s
                t[ind].options = opt
              end
            else
              t[ind].marker = true
            end
          end
        end
      end
    end
    f:close()
  else
    log("I", logTag,
      "No custom pacenotes not found (\"" .. cfname .. "\").\
    Using default pacenotes."
    )
  end
  return t
end

  -- -- TODO: I don't think this works. wtf is that
  -- for k, v in ipairs(rally) do
  --   if v.call then
  --     local wds = stringToWords(v.call)
  --     dump(wds)
  --     getPhrasesFromWords(wds)
  --     dump(currentSentence)
  --     local mat = 0
  --     for _, m in ipairs(wds) do
  --       mat = mat + #(wds)
  --     end
  --     if mat ~= #(wds) then
  --       log("W", logTag,
  --         "Fix pacenotes or codriver. Problems with: " .. tostring(k) ..
  --         " - " .. v.call .. ". Pacenotes will malfunction."
  --       )
  --     end
  --     clearCurrentSentence()
  --   end

local function writeCfgToIni()
  -- Need to convert tables into strings, and store back as table.
  if rcfg == nil then return end
  local t = deepcopy(rcfg)
  local s = ''
  for _, v in ipairs(t.slowCorners) do
    s = s .. v .. ','
  end
  t.slowCorners = s:sub(1, -2)
  log("I", logTag, "Writing config to" .. rallyCfgFile)
  saveIni(rallyCfgFile, t)
end

local function dumpDebug()
  dumpToFile("pacenoteDirector_rally.log", rally)
  dumpToFile("pacenoteDirector_codriver.log", codriver)
end
