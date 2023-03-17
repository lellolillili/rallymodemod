-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

require("utils")
local M = {}

-- returns how many players can be using cars at the same time
local function getMaxPlayersAmount(multiseat)
    if multiseat then return 64 -- TODO hardcoded, should be same as steering fastpath limit in t3d side
    else return 1 end
end

-- returns a list of which player is controlling each input device
-- e.g. { "keyboard": 0, "xinput0": 1, "mouse": 0 }
local lastMultiseat = false
local function getAssignedPlayers(devices, logEnabled, seatPlayers)
  -- push/pop the multiseat actinomap
  local multiseat = settings.getValue("multiseat")
  local changed = multiseat ~= lastMultiseat
  if changed then
    local o = scenetree.findObject("MultiseatActionMap")
    if o then
      if multiseat then o:push()
      else o:pop() end
    else
      log("E", "", "No multiseat action map found")
    end
  end
  lastMultiseat = multiseat

  -- assign each input device to a different player (except keyboard and mouse, those go to the same player)
  local maxPlayers = getMaxPlayersAmount(multiseat)
  local nVehicles = tableSize(getAllVehicles())
  local nControllers = tableSize(devices) - 1 -- assume mouse goes together with keyboard
  local players = math.max(1,math.min(maxPlayers, nControllers))
  if logEnabled and players > 1 then log("D", "multiseat", "Settled for "..players.." players:  supported="..maxPlayers..", vehicles="..nVehicles..", devices="..nControllers.." (& mouse)") end
  local devnames = tableKeys(devices)
  table.sort(devnames)
  local lastPlayer = 0
  lastPlayer = (lastPlayer + 1) % players -- skip the first player, it will be used by keyboard and mouse anyway
  local result = {}
  for _,devname in ipairs(devnames) do
    if devname:startswith("keyboard") or devname:startswith("mouse") then
      result[devname] = 0
    else
      result[devname] = lastPlayer
      lastPlayer = (lastPlayer + 1) % players
    end
  end
  if logEnabled and players > 1 then log((players>1) and "I" or "D", "", "Assigned players: "..dumps(result):gsub("\n", ""):gsub("  ", " ")) end

  -- re-seat all players in vehicles when requested
  local potentialSeatChanges = changed or multiseat -- skip re-seating players when there's no chance they'll end in a different car
  if potentialSeatChanges and seatPlayers then
    -- locate all vehicles
    local usedVehicles = {}
    for id, vehicle in activeVehiclesIterator() do
      usedVehicles[id] = 0
    end
    -- count amount of seats used on each vehicle
    for player=0, players-1 do
      local veh = be:getPlayerVehicle(player)
      if veh then
        local id = veh:getId()
        usedVehicles[id] = usedVehicles[id] + 1
      end
    end
    -- assign players on foot to vehicles (favour the least occupied vehicles)
    for player=0, maxPlayers-1 do
      if player > players-1 then
        be:exitVehicle(player)
      else
        local veh = be:getPlayerVehicle(player)
        if not veh then -- player has no vehicle, is on foot
          -- locate least occupied vehicle
          local leastUsedId = nil
          local leastUsedN = math.huge
          for id,n in pairs(usedVehicles) do
            if n < leastUsedN then
              leastUsedId = id
              leastUsedN = n
            end
          end
          -- seat this player in the vehicle we found
          if leastUsedId then
            local vehicle = be:getObjectByID(leastUsedId)
            be:enterVehicle(player, vehicle)
            -- update vehicle occupation counters
            usedVehicles[leastUsedId] = usedVehicles[leastUsedId] + 1
          end
        end
      end
    end
  end
  return result
end

local function getActiveVehicles()
  local res = {}
  for id, veh in activeVehiclesIterator() do
    table.insert(res, veh)
  end
  return res
end

local function enterNextVehicle(player, step)
  step = step or 0
  local curVehicle = be:getPlayerVehicle(player)
  local curId = curVehicle and curVehicle:getID()
  local vehicles = getActiveVehicles()
  if player ~= 0 then
    table.insert(vehicles, false) -- allow multiseat players/controllers to not be assigned any vehicle, aka 'false'
  end
  local curIndex = #vehicles
  for index,vehicle in ipairs(vehicles) do
    local id = vehicle and vehicle:getID()
    if curId == id then
      curIndex = index
      break
    end
  end
  local nextIndex = (curIndex) % #vehicles + 1
  local nextVehicle = vehicles[nextIndex]
  if nextVehicle then
    be:enterVehicle(player, nextVehicle)
  else
    be:exitVehicle(player)
  end
end
M.getAssignedPlayers = getAssignedPlayers
M.enterNextVehicle = enterNextVehicle

return M
