-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local prefabPath = "art/prefabs/garage_simple.prefab"
local prefab
local position

local function getSuitablePosition()
  return vec3(0,0,1000)
end

local function load()
  --TODO should detect if the prefab is already spawned and reuse it. For example, to not leak prefabs on LUA reloads, to transparently use an artist-placed prefab if the map has one, etc
  local pos = getSuitablePosition()
  prefab = spawnPrefab(Sim.getUniqueName("Showroom"),prefabPath,string.format("%d %d %d", pos.x, pos.y, pos.z) ,"0 0 0 1","1 1 1", true)
  if not prefab then
    log("E", "", "Unable to load prefab "..dumps(prefabPath).." at "..dumps(position))
    return
  end
  position = pos
  be:reloadCollision()
end

local function unload()
  if not prefab then return end
  prefab:delete()
  prefab = nil
  position = nil
  be:reloadCollision()
end

local function localToWorld(pos)
  if not prefab then load() end
  return position + pos
end

local function getPosRot()
  return localToWorld(vec3(0,0,0)), quat(0,0,0,1)
end
local function moveInside(veh)
  local pos,rot = getPosRot()
  veh:setPosRot(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
  veh:autoplace(false)
  --spawn.safeTeleport(veh, localToWorld(vec3(0,0,0)), quat(0,0,0,1))
end

local function isInside(pos)
  if not pos then
    local playerVehicle = be:getPlayerVehicle(0)
    pos = vec3(playerVehicle and playerVehicle:getPosition() or getCameraPosition())
  end
  --TODO do proper test against a BB or whatever method is appropriate
  return prefab and position:distance(pos) < 20
end

M.moveInside = moveInside
M.isInside = isInside
M.getPosRot = getPosRot
M.onClientEndMission = unload

return M
