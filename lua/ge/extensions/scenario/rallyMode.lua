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

-- instead of relying on the branchlapconfig, we manually extract the prefab.
-- this works from the console
-- scenetree.findObject('jv_loop_forward')
-- but i think i need to spawn it first. not sure
-- As long as something's inside a prefab (packed or not), we can access it
-- wp = scenetree.findObject('jvl_wp5')
-- then, the pacenote is retrieved as
-- obj:getDynDataFieldbyName("pacenote", 0)
-- it should be possible to put all the rallies in the rallies group, and
-- retrieve them. I think i saw a method that gets by "group", which should be
-- the folder. Also, you can access the prefab with scenetree.rallies. Folders
-- in the scene tree are "SimGroup" classes.
-- methods that seem useful: isChildOfGroup

local function strToBool(s)
  local b
  if s == "true" then
    b = true
  elseif s == "false" then
    b = false
  end
  return b
end

-- I am sure there's a neater way to do this, but for now I'm just prototyping
-- and I don't want to spend too much time testing the methods in the scenetree.
-- In fact, I'm not even sure that what I need is a scenetree method at all.

local rallyWaypoints = {}
local maxIndex = 500
local maxHoleSize = 100
local consecutiveMisses = 0

--findClassObjects does not work on prefabs

local rallyPrefabs = {}

local function getRallyWaypoints(prefix)
  -- I should probably use findclassobject instead
  for i = 1, maxIndex do
    local objectName = prefix .. i
    local obj = scenetree.findObject(objectName)
    if obj then
      local wp = {
                  name = obj:getName(),
                  pacenote = obj:getDynDataFieldbyName("pacenote", 0),
                  marker = obj:getDynDataFieldbyName("marker ", 0),
                  options = obj:getDynDataFieldbyName("options", 0),
                  group = obj:getGroup(),
                  id = obj:getId(),
                  Id = obj:getID(),
                  filename = obj:getFileName(),
                  position = obj:getPosition(),
                  positionXYZ = obj:getPositionXYZ(),
                  waypoint = obj
                 }
      rallyWaypoints[i] = wp
      consecutiveMisses = 0
    else
      consecutiveMisses = consecutiveMisses + 1
      if consecutiveMisses > maxHoleSize then
        break
      end
    end
  end
end

local function getDistFromByName(position, name)
  -- Gets distance between player and n-th waypoint
  -- TODO: get this from the rally data structure
  local wPos = scenetree.findObject(name):getPosition()
  local d = position:distance(wPos)
  return d
end

local function getClosestWaypoint()
  local wps = scenetree.findClassObjects('BeamNGWaypoint')
  local closest
  local mindist = 9999999999999999
  local playerPos = scenetree.findObject('thePlayer'):getPosition()
  for i, v in ipairs(wps) do
    local d = getDistFromByName(playerPos, v)
    if d < mindist then
      mindist = d
      closest = i
    end
  end
  if closest then
    local str = wps[closest]
    if str then
      local p, n = string.match(str, "(.-)(%d+)$")
      return {index = tonumber(n), prefix = p}
    else
      log("E", logTag, "Can't find closest waypoint string.")
    end
  else
    log("E", logTag, "Can't find closest waypoint.")
  end
end

-- this still grabs all the waypoints (which is probably useful), but it sets
-- the rally start to the correct one
local function getWaypointsFromHere()
  last = 0
  local closestWp = getClosestWaypoint()
  if closestWp then
    getRallyWaypoints(closestWp.prefix)
    last = closestWp.index
  end
end

-- TODO!!!: remove all game logic and/or make it conditional.
--   local max = #sc.BranchLapConfig must go!

-- This is mostly so that my quickraces don't break, but it makes sense that for
-- different game modes we might want to use different strategies to grab the
-- pacenotes.
local function getRallyWaypointsQuickrace()
  local wps = sc.BranchLapConfig
  for i, v in ipairs(wps) do
    local obj = scenetree.findObject(v)
    local wp = {
                name = obj:getName(),
                pacenote = obj:getDynDataFieldbyName("pacenote", 0),
                marker = obj:getDynDataFieldbyName("marker ", 0),
                options = obj:getDynDataFieldbyName("options", 0),
                group = obj:getGroup(),
                id = obj:getId(),
                Id = obj:getID(),
                filename = obj:getFileName(),
                position = obj:getPosition(),
                positionXYZ = obj:getPositionXYZ(),
                waypoint = obj
               }

    rallyWaypoints[i] = wp
  end
end

-- why, yes, this is silly, but because It's not clear to me if storing rally
-- data in waypoints is the way to go, I'll put all the getters in the same
-- place so we know what to change if we need to
local function getWaypointName(i)
  return rallyWaypoints[i].name
end

local function getWaypointPos(i)
  return rallyWaypoints[i].position
end

local function getCallFromWp(i)
  return rallyWaypoints[i].pacenote or "empty"
end

local function getOptionsFromWp(i)
  return rallyWaypoints[i].options or ""
end

local function getMarkerFromWp(i)
  return rallyWaypoints[i].marker
end

local function isSlow(s)
  -- True if s is a slow corner
  for _, v in ipairs(rcfg.slowCorners) do
    if s:find(v) then
      return true
    end
  end
end

local function isLinked(s)
  -- True if s has a link word in it
  if rcfg.linkWord == s:match("(%w+)") then
    return true
  end
end

local function distOrLink(d)
  -- Outputs rounded distance or linkWords when below cutoff
  local M = tonumber(allowedDists[#allowedDists])
  if d > M then
    return M
  end
  if d < rcfg.cutoff then
    return ""
  else
    for i, v in ipairs(allowedDists) do
      -- The + 3 means we're rounding conservatively
      print(v)
      if d + 3 < tonumber(v) then
        return allowedDists[i - 1]
      end
    end
  end
end

local function getDistBtw(m, n)
  -- Returns dist between the m-th and n-th waypoints
  local d = 0
  for i = m, n - 1, 1 do
    local a = getWaypointPos(i)
    local b = getWaypointPos(i + 1)
    d = d + a:distance(b)
  end
  return d
end

local function getCall(i)
  if rally[i] then return rally[i].call end
end

local function getMarker(i)
  if rally[i] then return rally[i].marker end
end

local function getOptions(i)
  if rally[i] then return rally[i].options end
end

local function getPacenoteAfter(i)
  -- Gets next nonempty pacenote after "i" and its options
  -- TODO: for now, rallies go until the end, but if we want to finish early we
  -- should update this.
  local max = #rally
  local inext = i + 1
  for k = inext, max, 1 do
    local pCall = getCall(k)
    if k >= max then
      --TODO: not sure what this does anymore
      return { index = max, call = pCall }
    end
    if pCall ~= nil then
      if pCall ~= "empty" then
        local pnote = {
          index = k,
          call = pCall,
          opts = getOptions(k)
        }
        if isSlow(pCall) then
          pnote.opts = pnote.opts .. "pause"
        end
        return pnote
      end
    end
  end
end

local function getDistCall(p)
  -- Gets the distance call to append to the next call, or a linkword if the
  -- next corner is closer than the cutoff
  local pFinal = getPacenoteAfter(p).index
  if (pFinal == p + 1) then
    local dist = getDistBtw(p, pFinal)
    return distOrLink(dist)
  elseif pFinal > p + 1 then
    for i = pFinal - 1, p + 1, -1 do
      if getMarker(i) ~= nil then
        p = i
      end
    end
    local dist = getDistBtw(p, pFinal)
    return distOrLink(dist)
  elseif pFinal <= p then
    log("E", logTag, "Next waypoint index is <= than the previous.")
  elseif pFinal == nil then
    log("E", logTag, "Could not get next waypoint index.")
  end
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

local function getDistFrom(n)
  -- Gets distance between player and n-th waypoint
  -- TODO: get this from the rally data structure
  -- local i = getLastWaypointIndex() + 1
  local i = last + 1
  local wPos = getWaypointPos(i)
  local pPos = getPlayerPos()
  local d = pPos:distance(wPos) + getDistBtw(i, n)
  return d
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

-- local function getLastWaypoint()
--   local wIndex = getLastWaypointIndex()
--   local wCall = getCall(wIndex)
--   if wCall == nil then
--     wCall = "empty"
--   end
--   local pName = getWaypointName(wIndex)
--   return { index = wIndex, call = wCall, name = wName }
-- end

local function tokm(x)
  local xkm = x / 1000
  return string.format("%.1f", xkm)
end

local function stats()
  local total = stageLength()
  local from = getFromStart()
  local to = getToFinish()
  local s = tostring(tokm(from) .. " / " .. tokm(total) .. " (km)")
  log("I", logTag, "Stats: " .. s)
  guihooks.trigger('Message',
    { ttl = 5, msg = s, category = "align", icon = "flag" })
end

local currentSentence = {}
local function updateCurrentSentence(phrase)
  if phrase ~= nil and phrase ~= "" then
    table.insert(currentSentence, trim(phrase))
  else
    log("E", logTag, "Trying to apppend an empty phrase.")
  end
end

local function clearCurrentSentence(phrase)
  currentSentence = {}
end

local function getPhrasesFromWords(words)
  local phrase = ""
  local match = ""
  for i, v in ipairs(words) do
    phrase = phrase .. v .. ' '
    if codriver[trim(phrase)] then
      match = phrase
    end
  end
  for i = 1, #string.split(match), 1 do
    table.remove(words, 1)
  end
  if match == "" then
    return
  end
  updateCurrentSentence(match)
  getPhrasesFromWords(words)
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

local function stringToWords(s)
  if s then
    local words = {}
    for w in s:gmatch("%S+") do table.insert(words, w) end
    return words
  end
end

local function getPhrasesFromWords(words)
  local phrase = ""
  local match = ""
  for i, v in ipairs(words) do
    phrase = phrase .. v .. ' '
    if codriver[trim(phrase)] then
      match = phrase
    end
  end
  for i = 1, #string.split(match), 1 do
    table.remove(words, 1)
  end
  if match == "" then
    return
  end
  updateCurrentSentence(match)
  getPhrasesFromWords(words)
end

-- You can use up to 20 alternative samples
local altSuffixes = {}
for i = 1, 20 do altSuffixes[i] = '_' .. tostring(i) end

local function buildCodriver(f)
  local dir = f
  if (not fileExists(dir .. "/codriver.ini")) then
    log("E", logTag, "Codriver file not found. Expecting \"" .. dir .. "/codriver.ini\".")
    return
  end
  local d = {}
  local f = io.open(dir .. "/codriver.ini", "r")
  for line in f:lines() do
    if string.len(line) > 0 then
      local firstChar = string.sub(line, 1, 1)
      if firstChar ~= '#' and firstChar ~= ';' and firstChar ~= '/' then
        if line:find("slowCorners=") then
          local sc = line:match("slowCorners=(.*)$")
          rcfg.slowCorners = fromCSV(sc)
        elseif line:find("LR") then
          local cstring
          local sample
          cstring, sample = line:match("^(%d*%u)%s%-%s(.*)$")
          corners["L" .. cstring] = sample:gsub("LR", "left")
          corners["R" .. cstring] = sample:gsub("LR", "right")
        else
          local key
          local sub
          if line:find("%>%>%>") then
            key, sub = line:match("^(.*)%>%>%>(.*)$")
            key = trim(key)
            sub = trim(sub)
          else
            key = trim(line:match("^(.+)$"))
          end
          d[key] = {}
          local mainSample = dir ..
            '/samples/' .. (sub or key) .. '.ogg'
          if fileExists(mainSample) then
            d[key]["samples"] = {}
            table.insert(d[key]["samples"], mainSample)
            for _, v in ipairs(altSuffixes) do
              local altSample = dir ..
                '/samples/alts/' .. (sub or key) .. v .. '.ogg'
              -- Dont search for the i+1-th and following
              -- alternative samples if you can't find the i-th
              -- sample. This avoids a lot of useless, very
              -- slow, file searches.  The filenames must not
              -- skip any numbers though.
              if not fileExists(altSample) then break end
              table.insert(d[key]["samples"], altSample)
            end
          end

         local pf = symbolsDir .. (sub or key) .. '.svg'
          if fileExists(pf) then
            d[key]["pics"] = {}
            table.insert(d[key]["pics"], pf)
          end
        end
      end
    end
  end
  f:close()

  local fs = io.open(dir .. "/symbols.ini", "r")
  for line in fs:lines() do
    if string.len(line) > 0 then
      local firstChar = string.sub(line, 1, 1)
      if firstChar ~= '#' and firstChar ~= ';' and firstChar ~= '/' then
        if line:find("%>%>%>") then
          local key
          local sub = nil
          key, sub = line:match("^(.*)%>%>%>(.*)$")
          key = trim(key)
          sub = fromCSV(sub)
          if d[key] then
            d[key].pics = {}
            for _, v in ipairs(sub) do
              local pf = symbolsDir .. trim(v) .. '.svg'
              if fileExists(pf) then
                table.insert(d[key].pics, pf)
              else
                log("W", logTag, pf .. " - Symbol substitution was specified,\
                but symbol file \"" .. pf .. "\" was not found. You might be missing a picture.")
              end
            end
          else
            log("W", logTag, "Symbol substitution was specified,\
            but key \"" .. key .. "\" was not found in the codriver. You might be missing the audio sample.")
          end
        end
      end
    end
  end
  fs:close()

  local dists = { 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130,
    140, 150, 160, 170, 180, 190, 200, 250, 300, 350, 400, 450, 500, 550,
    600, 650, 700, 750, 800, 850, 900, 1000, 1500, 2000 }
  for _, v in ipairs(dists) do
    if d[tostring(v)] then
      table.insert(allowedDists, v)
    end
  end

  d["_"] = nil

  return d
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

local function rallyPreInit()
-- TODO: there should probably be a rallypreinit function that checks if there are rally prefabs in the map, loads / spawns them as needed.
-- Alternatively, we could just include the rally prefabs in the map, but we should probably have some preInit functions either way, especially for free roam.
-- * check how many rallies are available in the map
-- * check how close you are to one
-- * possibly more...
end

local function rallyInitScenarios()
  -- this is meant to be used with scenarios. note that it always sets the rally
  -- beginning to 0
  readCfgFromIni()
  local sc = scenario_scenarios.getScenario()
  if sc.isQuickRace then
    getRallyWaypointsQuickrace()
  else
    getRallyWaypoints(getWpPrefix())
  end
  codriver = buildCodriver("/art/codrivers/" .. rcfg.codriverDir)
  rally = buildRally()
  if rcfg.hideMarkers then raceMarker.hide(true) end
  last = 0
  prefix = ""
  suffix = ""
  nosuffix = false
  speakTimer = -1
  rallyInitd = true
  rallyInfo.pacenoteFile = getPacenoteFile()
end

local function rallyInit()
  -- for now this is for manual initialization. I will likely merge with the one
  -- above at some point.
  if (not rallyWaypoints) then return end
  readCfgFromIni()
  getWaypointsFromHere()
  codriver = buildCodriver("/art/codrivers/" .. rcfg.codriverDir)
  rally = buildRally()
  if rcfg.hideMarkers then raceMarker.hide(true) end
  prefix = ""
  suffix = ""
  nosuffix = false
  speakTimer = -1
  if rally then
    rallyInitd = true
    log("I", logTag, "Rally was initialized.")
  else
    rallyInitd = false
    log("E", logTag, "Rally not found.")
  end
  rallyInfo.pacenoteFile = getPacenoteFile()
end

local function onScenarioRestarted()
  rallyInitd = false
  rallyInit()
end

--- Hooks --
------------

local function onScenarioChange()
  if rcfg.hideMarkers then raceMarker.hide(true) end
  guihooks.trigger("cfgToUI", rcfg)
  guihooks.trigger("infoToUI", rallyInfo)
  -- if rallyInitd == false or rallyInitd == nil then
  --   rallyInit()
  -- end
end

local function onRaceStart()
  if rcfg == nil then return end
  if rcfg.firstTime == true then
    local str = "Rally Mode Mod by Lello Lillili\
          ================================\
          Quick Start Guide\
          =================\
          1) Enable Rally Mode UI \
          [ Shift+Alt+U > Add App > Rally Mode UI ]\
          2) Pause Physics (J) to open config/info menu\
          3) Play around with the options\
          4) Save (always save after changing the config)\
          5) Unpause (J)\
          6) To Hide this message,\
          tick \"Welcome message\" from the pause menu\
          (may take effect after changing map or restarting the game)\
          "
    guihooks.trigger('Message',
      { ttl = 120, msg = str, category = "align", icon = "flag" })
  end
  guihooks.trigger("cfgToUI", rcfg)
  guihooks.trigger("infoToUI", rallyInfo)
  guihooks.trigger("showOpts")
  guihooks.trigger("hideUiOpts")
end

local function onRaceWaypointReached(data)
  if rcfg.hideMarkers then raceMarker.hide(true) end
  -- if rcfg.recce then
  --   print('W[ ' .. tostring(i) .. ' ] - ' .. name)
  -- end
end

local playQueue = {}

local function speak()
  if tableIsEmpty(playQueue) then return 0 end
  local ph = codriver[playQueue[1]].samples
  local sample = ph[math.random(1, #ph)]
  local out = Engine.Audio.playOnce('AudioGui', sample, { volume = rcfg.volume })
  table.remove(playQueue, 1)
  return out.len
end

local function queuePhrase(s)
  if s == "" then return end
  local words = stringToWords(s)
  words._ = nil
  getPhrasesFromWords(words)
  for _, v in ipairs(currentSentence) do
    -- Only add phrases to the current sentence if they have a sample.
    -- For example, a user may provide an empty phrase as a
    -- substitution if they just want the co-driver to ignore a
    -- pacenote.
    if codriver[v].samples then
      table.insert(playQueue, v)
    end
  end
  if rcfg.visual == true then
    local pics = {}
    for _, v in ipairs(currentSentence) do
      if codriver[v].pics then
        for __, vv in ipairs(codriver[v].pics) do
          guihooks.trigger("pnotesQueueSymbol", {
            i = last, pics = vv
          })
        end
      end
    end
  end
  clearCurrentSentence()
end

local function breathe(t)
  -- TODO: not sure oneTenth is actually one tenth of a second
  -- local oneTenth = 0.0001
  -- for i=0, t, 1 do
  --   speakTimer = speakTimer + t*oneTenth
  -- end
end

-- TODO: make this waypoint agnostic.

-- Need to create a new entity, similar to a waypoint that stores pacenotes. For
-- now, I'm relying on onRaceWaypointReached to increment the waypoint index.
-- The code below checks if we've passed the waypoint and if it's time to speak.
-- I think this can be redesigned easily.
-- 1. Store the pacenotes wherever, as long as they have a call and a
-- coordinate. Let's call this a rallyWaypoint.
-- 2. Interpolate the coordinates to get the distance (already here, somewhere)
-- and divide into sections by distance INSTEAD of relying on waypoints to do
-- this.
-- 3. Instead of incrementing onRaceWaypointReached, increment as soon as you
-- enter a new section.
--   rallyInfo.lastRallyWaypointN = i
--   rallyInfo.lastRallyWaypoint = name
-- That should be it. The code below stays untouched, pretty much. You just need
-- to adjust all the calls to waypoint related stuff.

local function getCodriver()
  return codriver
end

local function getRally()
  return rally
end

local function getRallyWps()
  return rallyWaypoints
end

local function onPreRender(dtReal, dtSim, dtRaw)
  -- TODO: not sure if this is useful, but it should short-circuit everything
  -- until the rally is initialized.
  if (not rally) or (rallyInitd == false) or (rallyPaused == true) then return end
  if speakTimer < 0 then
    speakTimer = speak(speakTimer)
  end
  speakTimer = speakTimer - dtReal
  local speed = getPlayerSpeed()
  local timeOffset = rcfg.timeOffset
  local posOffset = rcfg.posOffset
  local breathLength = rcfg.breathLength
  local pred = posOffset + speed * timeOffset
  local pnote = getPacenoteAfter(last)

  local i = pnote.index
  if i == nil then return end
  local rally = getRally()
  if last ~= 0 then
    if rally[last].call then
        rallyInfo.lastPacenote = last .. ' - ' .. rally[last].call .. '; ' .. rally[last].options
    end
  end

  if i > last and i < rallyEnd and (rally[i].call ~= nil) then
    rallyInfo.nextPacenote = i .. ' - ' ..
      rally[i].call .. '; ' .. rally[i].options

    local dist = getDistFrom(i)
    if (dist < pred) and i > last and i < rallyEnd then
      suffix = getDistCall(i)
      -- If last pacenote's automatic suffix was disabled,
      -- then also disable this pacenotes's automatic prefix.
      if nosuffix then
        prefix = ""
      end
      nosuffix = false
      if rcfg.recce then
        local name = getWaypointName(i)
      end
      queuePhrase(prefix .. ' ' .. pnote.call)
      -- TODO: all these breaththings must be double checked. No idea
      -- wtf they do.
      if pnote.opts then
        if pnote.opts:find("nosuffix") then
          breathe(breathLength)
          nosuffix = true
        elseif pnote.opts:find("nopause") then
          breathe(breathLength)
          queuePhrase(tostring(suffix))
          breathe(breathLength)
        elseif pnote.opts:find("shortpause") then
          breathe(round(0.5 * timeOffset * 10))
          queuePhrase(tostring(suffix))
          breathe(breathLength)
        elseif pnote.opts:find("verylongpause") then
          breathe(round(2 * timeOffset * 10))
          queuePhrase(tostring(suffix))
          breathe(breathLength)
        elseif pnote.opts:find("longpause") then
          breathe(round(1.5 * timeOffset * 10))
          queuePhrase(tostring(suffix))
          breathe(breathLength)
        elseif pnote.opts:find("pause") then
          breathe(round(timeOffset * 10))
          queuePhrase(tostring(suffix))
          breathe(breathLength)
        else
          breathe(breathLength)
          queuePhrase(tostring(suffix))
          breathe(breathLength)
        end
      else
        breathe(breathLength)
        queuePhrase(tostring(suffix))
      end
      -- If the distance call is too close to get called,
      -- then prepend a linkword (e.g. "into") to the next call.
      if suffix == "" then
        prefix = rcfg.linkWord
      else
        prefix = ""
      end
      last = i
      -- TODO: probably need something better than this
      guihooks.trigger("pnotesHideSymbol", i - 1)
    end
  end
end

-- UI stuff --
--------------

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

local function onPhysicsUnpaused()
  if rallyInitd == false or rallyInitd == nil then return end
  if rcfg == nil then return end
  guihooks.trigger("hideUiOpts")
  rallyPaused = false
end

local function onPhysicsPaused()
  rallyPaused = true
  if rallyInitd == false or rallyInitd == nil then return end
  if rcfg == nil then return end
  guihooks.trigger("cfgToUI", rcfg)
  guihooks.trigger("infoToUI", rallyInfo)
  guihooks.trigger("showOpts")
end

local function dumpDebug()
  dumpToFile("pacenoteDirector_rally.log", rally)
  dumpToFile("pacenoteDirector_codriver.log", codriver)
end


-- Debugging (and eventually practice mode)
local function showWaypoint(i)
  -- TODO: I'm giving up for now
  local pos = getWaypointPos(i)
  debugDrawer:drawSphere(0.25, pos, color(0,0,255,255))
end

local function movePlayer(i)
  -- TODO: I'm giving up for now
  local player = scenetree.findObject('thePlayer')
  player:setPosition(getWaypointPos(i))
end

local function startFromHere()
  getWaypointsFromHere()
  local closest = getClosestWaypoint()
  -- movePlayer(closest.index)
  rallyInit()
end

local function startFrom(i)
  getWaypointsFromHere()
  last = i
  movePlayer(i)
  rallyInit()
end


local function quickdebug()
  getRallyPrefabs()
  -- for i, _ in ipairs(rallyWaypoints) do
  --   showWaypoint(i)
  -- end
end

local function uiToConfig(s)
  -- TODO: this is really lazy
  if rcfg == nil then return end
  local opts      = fromCSV(s)
  local tmpcfg    = {}
  tmpcfg.breathLength = tonumber(opts[1])
  tmpcfg.timeOffset   = tonumber(opts[2])
  tmpcfg.visual     = strToBool(opts[3])
  tmpcfg.firstTime  = strToBool(opts[4])
  tmpcfg.volume     = tonumber(opts[5])
  tmpcfg.iconSize   = tonumber(opts[6])
  tmpcfg.iconPad    = tonumber(opts[7])
  local check     = checkConfig(tmpcfg)
  if check == true then
    log("I", logTag,
      "Options parsed from the UI are good.\
       Updating current game's rally config.")
    for k, v in pairs(tmpcfg) do
      rcfg[k] = v
    end
  else
    log("I", logTag,
      "Options parsed from the UI are bad.\
       Keeping current game's rally config.")
  end
  if (check == true) and (tableSize(rcfg) == 14) then
    log("I", logTag, "Configuration is good.")
    writeCfgToIni()
  else
    log("I", logTag,
      "Problem with options. Not writing to file.")
  end
end

-- Initialization stuff, including UI --
----------------------------------------

-- Loads a custom version of the scenario_waypoints extension
M.onScenarioLoaded = function()
  scenario_waypoints = extensions.scenario_waypointsNoSound
end

local function onUiReady()
  if rcfg == nil then return end
  guihooks.trigger("cfgToUI", rcfg)
  guihooks.trigger("infoToUI", rallyInfo)
end

-- Example
--
-- unloading extensions
--
-- local function uiHotlappingAppDestroyed()
--   --log("I",logTag,"uiHotlappingAppDestroyed called.....")
--   if not scenario_scenarios or not (scenario_scenarios and scenario_scenarios.getScenario()) then
--   extensions.unload('core_hotlapping');
--   end
-- end
--
-- Interface --
---------------

M.onRaceStart = onRaceStart
M.onPreRender = onPreRender
M.onPhysicsPaused = onPhysicsPaused
M.onPhysicsUnpaused = onPhysicsUnpaused
M.onRaceWaypointReached = onRaceWaypointReached
M.onScenarioChange = onScenarioChange
M.onScenarioRestarted = onScenarioRestarted
M.getRally = getRally
M.getRallyWps = getRallyWps
M.getCodriver = getCodriver
M.stats = stats
M.dumpDebug = dumpDebug
M.uiToConfig = uiToConfig
M.getPacenoteFile = getPacenoteFile
M.quickdebug = quickdebug
M.getRallyWaypoints = getRallyWaypoints
M.rallyInit = rallyInit
M.rallyInitScenarios = rallyInitScenarios
M.getWaypointsFromHere = getWaypointsFromHere
M.buildRally = buildRally
M.startFrom = startFrom
return M
