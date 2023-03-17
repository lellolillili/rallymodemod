-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this tiny module helps setting the steam rich presence

local M = {}

-- How to use: print(extensions.util_richPresence.set('yolo'))
M.state = { levelName = "", vehicleName = "" ,levelIdentifier=""}

local internal = not shipping_build or not string.match(beamng_windowtitle, "RELEASE")

--discord assets
local vehAssets = {"pickup"}
local lvlAssets = {
  "automation_test_track",
  "cliff",
  "derby",
  "driver_training",
  "east_coast_usa",
  "glow_city",
  "gridmap",
  "hirochi_raceway",
  "industrial",
  "italy",
  "jungle_rock_island",
  "small_island",
  "smallgrid",
  "utah",
  "west_coast_usa",
}


local function msgFormat()
  local fgActivityId = gameplay_missions_missionManager.getForegroundMissionId()
  local mission = gameplay_missions_missions.getMissionById(fgActivityId)

  local msg = ""
  local appendLevel, appendVehicle
  if editor and editor.isEditorActive() then
    msg = "Using World Editor"
    appendLevel, appendVehicle = true, false
  elseif fgActivityId and mission then
    msg = "Playing " .. translateLanguage(mission.name, mission.name, true) -- suppress errors for translations
    appendLevel, appendVehicle = true, true
  elseif scenario_scenarios and scenario_scenarios.getScenario() then
    local scenario = scenario_scenarios.getScenario()
    if scenario.name then
      msg = "Playing " .. translateLanguage(scenario.name, scenario.name, true)
    elseif scenario.isQuickRace then
      msg = "Playing Time Trials"
    else
      msg = "Playing Scenario"
    end
    appendLevel, appendVehicle = true, true
  elseif M.state.vehicleName == 'Unicycle' then
    msg = "Walking around"
    appendLevel, appendVehicle = true, false
  else
    msg = "Playing"
    if extensions.core_gamestate.state.state then
      msg = msg.. " " ..tostring((core_gamestate.state.state:gsub("^%l", string.upper)) )
    end
    appendLevel, appendVehicle = true, true
  end

  if msg ~= "" then
    -- append level and vehicle if possible
    if appendLevel and M.state.levelName ~= "" then
      msg = msg .. " on " .. M.state.levelName
    end

    if appendVehicle and M.state.vehicleName ~= "" and M.state.vehicleName ~= "Unicycle" then
      msg = msg .. " with " .. M.state.vehicleName
    end

    M.set(msg)
    -- only set discord state is there is a msg for steam
    if Discord and Discord.isWorking() then
      local dActivity = {state="Playing ",details="",asset_largeimg="",asset_largetxt="",asset_smallimg="",asset_smalltxt=""}
      -- discord will use the same message as steam
      dActivity.state = msg

      if M.state.levelName ~= "" then
        dActivity.details = M.state.levelName
        dActivity.asset_largetxt = M.state.levelName
      end
      if M.state.vehicleName ~= "" then
        dActivity.asset_smalltxt = M.state.vehicleName
        dActivity.details = M.state.vehicleName
      end
      if M.state.levelIdentifier and M.state.levelIdentifier ~= "" and tableContains(lvlAssets,M.state.levelIdentifier)then
        dActivity.asset_largeimg= "lvl_"..M.state.levelIdentifier
      else
        dActivity.asset_largeimg="missingnormaltexture"
      end
      -- if M.state.vehicleJbeam and M.state.vehicleJbeam ~= "" and tableContains(vehAssets,M.state.vehicleJbeam) then
      --   dActivity.asset_smallimg= M.state.vehicleJbeam
      -- else
      --   dActivity.asset_smallimg= "warnmat"
      -- end
      --log("E","msgFormat", dumps(dActivity))
      Discord.setActivity(dActivity)
    end
  end
end

local function onVehicleSwitched(oldId, newId, player)
  local currentVehicle = core_vehicles.getCurrentVehicleDetails()
  if currentVehicle.model and currentVehicle.model.Name then
    if currentVehicle.model.Brand then
      M.state.vehicleName = currentVehicle.model.Brand .. " " .. currentVehicle.model.Name
    else
      M.state.vehicleName = currentVehicle.model.Name
    end
  end
  M.state.vehicleJbeam = currentVehicle.current.key
  msgFormat()
end

local function onClientPostStartMission(levelPath)
  local currentLevel = getCurrentLevelIdentifier() or ''
  M.state.levelIdentifier = string.lower(currentLevel)
  if currentLevel ~= "" then
    M.state.levelName = currentLevel:gsub("^%l", string.upper)
    M.state.levelName = M.state.levelName:gsub("_", " ")
    M.state.levelName = string.gsub(" "..M.state.levelName, "%W%l", string.upper):sub(2)
    msgFormat()
  end
end
--[[
-- this was the old editor
local function onEditorEnabled(enabled)
  if enabled then
    M.set('Level editing')
  else
    msgFormat()
  end
end
]]

local function onEditorActivated()
  msgFormat()
end

local function onEditorDeactivated()
  msgFormat()
end

local function onGameStateUpdate(state)
  msgFormat()
end

local function onAnyMissionChanged()
  msgFormat()
end

local function onExtensionLoaded()
  if not internal and settings.getValue('richPresence') then
    if Steam then
      Steam.setRichPresence('steam_display', '#BNGGSW') -- BNGGSW = BeamNG Generic Status Wrapper
      Steam.setRichPresence('status', beamng_windowtitle) -- will show up in the 'view game info' dialog in the Steam friends list.
      Steam.setRichPresence('b', "   ")
    end
    if Discord then
      Discord.setEnabled(settings.getValue('richPresenceDiscord'))
    end
  end
end

local function onExtensionUnloaded()
  if Steam then
    Steam.setRichPresence('b', "   ")
    -- Steam.clearRichPresence() --not working
  end
  if Discord then
    Discord.clearActivity()
  end
end

-- returns true on success
local function set(v)
  log("D","Rich Presence", tostring(v))
  if Steam then
    return Steam.setRichPresence('b', tostring(v))
  end
end

local toggleableFunctions = {
  onVehicleSwitched = onVehicleSwitched,
  onClientPostStartMission = onClientPostStartMission,
  --onEditorEnabled = onEditorEnabled,
  onGameStateUpdate = onGameStateUpdate,
  onAnyMissionChanged = onAnyMissionChanged,
  onEditorActivated = onEditorActivated,
  onEditorDeactivated = onEditorDeactivated,
  set = set
}

local function enableToggleableFunctions(enabled)
  for k, v in pairs(toggleableFunctions) do
    M[k] = enabled and v or nop
  end
end

local function onSettingsChanged()
  if internal or not settings.getValue('richPresence') then
    -- log("D","Rich Presence", "Rich Presence is disabled.")
    if Steam then
      Steam.setRichPresence('b', "   ")
      -- Steam.clearRichPresence() --not working
    end
    if Discord then
      Discord.setEnabled(false)
    end
    enableToggleableFunctions(false)
  elseif M.set == nop and settings.getValue('richPresence') then --re-enabled
    log("D","Rich Presence", "Rich Presence is enabled.")
    Steam.setRichPresence('steam_display', '#BNGGSW')
    Steam.setRichPresence('status', beamng_windowtitle)
    Steam.setRichPresence('b', "   ")
    enableToggleableFunctions(true)
    if Discord then
      Discord.setEnabled(settings.getValue('richPresenceDiscord'))
    end
    msgFormat()
  end
end

M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onSettingsChanged = onSettingsChanged
M.onAnyMissionChanged = onAnyMissionChanged
M.onDeserialized    = nop -- do not remove

if not internal then
  enableToggleableFunctions(true)
else
  enableToggleableFunctions(false)

  if Steam then
    Steam.setRichPresence('b', "   ")
    --Steam.clearRichPresence()
  end
end

return M
