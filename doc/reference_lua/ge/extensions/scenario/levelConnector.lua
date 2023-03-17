-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local function saveVehicle()
  local veh = be:getPlayerVehicle(0)--get vehicle that drove into trigger see data next: figure out how to transport truck with trailerS
  local vehicleName = string.match(veh:getPath(), "vehicles/([^/]*)/")
  TorqueScriptLua.setVar( '$beamngVehicle', vehicleName )
  local mycolor = getVehicleColor()
  TorqueScriptLua.setVar("$beamngVehicleColor", mycolor)
  local licenseName = core_vehicles.getVehicleLicenseText(veh)
  TorqueScriptLua.setVar( '$beamngVehicleLicenseName', licenseName )
end

local function onBeamNGTrigger(data)
  if data.event ~= "enter" then return end
  -- trigger that loads a new scenario
  if data.levelLoadScenario then
    scenario_scenariosLoader.startByPath(data.levelLoadScenario)
  -- trigger that loads a new level
  elseif data.nextlevel then
     local dir = FS:openDirectory('levels')
      if dir then
        if FS:directoryExists('levels/'..data.nextlevel) then
          if not data.spawnpoint then data.spawnpoint = "" end
          if data.nextlevel:find(".main.level.json") then
            data.nextlevel = data.nextlevel:gsub(".main.level.json","")
          end
          setSpawnpoint.setDefaultSP(data.spawnpoint,data.nextlevel)
          data.nextlevel = "levels/"..data.nextlevel.."/"..data.nextlevel.."./main.level.json"
          saveVehicle()
          core_levels.startLevel(data.nextlevel)
        else
          log('E',logTag,data.nextlevel .." not exist")
        end
      end
  end
end


M.onBeamNGTrigger = onBeamNGTrigger

return M
