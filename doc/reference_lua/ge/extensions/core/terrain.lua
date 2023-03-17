-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt


local M = {}
local terrainId = nil

local function getTerrain()
  local terrain = terrainId and scenetree.findObjectById(terrainId)
  if not terrain then
    local terrains = scenetree.findClassObjects("TerrainBlock")
    if next(terrains) then
      terrain = scenetree.findObject(terrains[1])
      terrainId = terrain:getId()
    end
  end
  return terrain
end

local function getTerrainHeight(point)
  local terrain = getTerrain()
  if terrain then
    return terrain:getHeight(point)
  end
end

local function getTerrainNormal(point)
  local terrain = getTerrain()
  if terrain then
    return terrain:getNormal(point, true, true)
  end
end

local function getTerrainSmoothNormal(point)
  local terrain = getTerrain()
  if terrain then
    return terrain:getSmoothNormal(point, true, true)
  end
end

-- public interface
M.getTerrain = getTerrain
M.getTerrainHeight = getTerrainHeight
M.getTerrainNormal = getTerrainNormal
M.getTerrainSmoothNormal = getTerrainSmoothNormal

return M
