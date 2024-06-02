local logTag = "rallyMode"
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

local rallyInitd = false
local rallyPaused = false

local rallyCfgFile = "/settings/rallyconfig.ini"
local symbolsDir = "/art/symbols/"


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

local function onScenarioChange()
  if rcfg.hideMarkers then raceMarker.hide(true) end
  guihooks.trigger("cfgToUI", rcfg)
  guihooks.trigger("infoToUI", rallyInfo)
  -- if rallyInitd == false or rallyInitd == nil then
  --   rallyInit()
  -- end
end

local function onScenarioRestarted()
  rallyInitd = false
  rallyInit()
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


--- UI stuff


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
