-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-------------------------------------------------------------------------------
-- Exposed event hooks
-------------------------------------------------------------------------------
-- onEditorTerrainCreated
-- onEditorTerrainDelete
-- onEditorTerrainHeightBrushChanged
-- onEditorTerrainHeightChanged
-- onEditorTerrainCleared
-- onEditorTerrainRestored

local editor

local function createTerrain(terrainInfo)
  --TODO
end

local function deleteTerrain(terrainObjectId)
  --TODO
end

local function importTerrainHeightmap(importInfo)
  --TODO
end

local function exportTerrainHeightmap(terrainObjectId, filename)
  --TODO
end

local function setTerrainHeightBrush(brush)
  --TODO
end

local function saveTerrainHeightBrushPreset(name)
  --TODO
end

local function applyTerrainHeightBrushPreset(name)
  --TODO
end

local function deleteTerrainHeightBrushPreset(name)
  --TODO
end

local function getTerrainHeightBrushPresets()
  --TODO
end

local function grabTerrain(x, y, amount)
  --TODO
end

local function raiseTerrain(x, y, amount)
  --TODO
end

local function lowerTerrain(x, y, amount)
  --TODO
end

local function smoothTerrain(x, y, amount)
  --TODO
end

local function smoothSlopeTerrain(x, y, amount)
  --TODO
end

local function averageSmoothTerrain(x, y, amount)
  --TODO
end

local function noiseTerrain(x, y, amount)
  --TODO
end

local function flattenTerrain(x, y, amount)
  --TODO
end

local function setTerrainHeight(x, y, amount)
  --TODO
end

local function clearTerrain(x, y)
  --TODO
end

local function restoreTerrain(x, y)
  --TODO
end

local function alignTerrainWithMesh(x, y, topOrBottom, amount)
  --TODO
end

local function subtractMeshFromTerrain(x, y)
  --TODO
end

local function selectTerrainPaintMaterial(mtl)
  --TODO
end

local function createTerrainPaintMaterial(mtl)
  --TODO
end

local function paintTerrain(x, y)
  --TODO
end

local function setTerrainPaintBrush(brush)
  --TODO
end

local function saveTerrainPaintBrushPreset(name)
  --TODO
end

local function loadTerrainPaintBrushPreset(name)
  --TODO
end

local function deleteTerrainPaintBrushPreset(name)
  --TODO
end

local function getTerrainPaintBrushPresets()
  --TODO
end

local function createFoliageGroup(name)
  --TODO
end

local function deleteFoliageGroup(name)
  --TODO
end

local function createFoliageMesh(foliageMesh)
  --TODO
end

local function deleteFoliageMesh(foliageMeshName)
  --TODO
end

local function getFoliageMeshes()
  --TODO
end

local function addFoliageBrushToGroup(groupName, foliageBrush)
  --TODO
end

local function deleteFoliageBrush(name)
  --TODO
end

local function setFoliageBrushGroup(name)
  --TODO
end

local function setFoliageBrush(brushName)
  --TODO
end

local function setFoliagePaintBrushSettings(brush)
  --TODO
end

local function paintFoliage(x, y)
  --TODO
end

local function eraseFoliage(x, y)
  --TODO
end

local function eraseSetFoliageBrushOrGroup(x, y)
  --TODO
end

local function translateFoliageSelection(delta)
  --TODO
end

local function rotateFoliageSelection(delta)
  --TODO
end

local function scaleFoliageSelection(delta)
  --TODO
end

local function selectFoliage(x, y)
  --TODO
end

local function initialize(editorInstance)
  editor = editorInstance
  editor.createTerrain = createTerrain
  editor.deleteTerrain = deleteTerrain
  editor.importTerrainHeightmap = importTerrainHeightmap
  editor.exportTerrainHeightmap = exportTerrainHeightmap
  editor.setTerrainHeightBrush = setTerrainHeightBrush
  editor.saveTerrainHeightBrushPreset = saveTerrainHeightBrushPreset
  editor.applyTerrainHeightBrushPreset = applyTerrainHeightBrushPreset
  editor.deleteTerrainHeightBrushPreset = deleteTerrainHeightBrushPreset
  editor.getTerrainHeightBrushPresets = getTerrainHeightBrushPresets
  editor.grabTerrain = grabTerrain
  editor.raiseTerrain = raiseTerrain
  editor.lowerTerrain = lowerTerrain
  editor.smoothTerrain = smoothTerrain
  editor.smoothSlopeTerrain = smoothSlopeTerrain
  editor.averageSmoothTerrain = averageSmoothTerrain
  editor.noiseTerrain = noiseTerrain
  editor.flattenTerrain = flattenTerrain
  editor.setTerrainHeight = setTerrainHeight
  editor.clearTerrain = clearTerrain
  editor.restoreTerrain = restoreTerrain
  editor.alignTerrainWithMesh = alignTerrainWithMesh
  editor.subtractMeshFromTerrain = subtractMeshFromTerrain
  editor.selectTerrainPaintMaterial = selectTerrainPaintMaterial
  editor.createTerrainPaintMaterial = createTerrainPaintMaterial
  editor.paintTerrain = paintTerrain
  editor.setTerrainPaintBrush = setTerrainPaintBrush
  editor.saveTerrainPaintBrushPreset = saveTerrainPaintBrushPreset
  editor.loadTerrainPaintBrushPreset = loadTerrainPaintBrushPreset
  editor.deleteTerrainPaintBrushPreset = deleteTerrainPaintBrushPreset
  editor.getTerrainPaintBrushPresets = getTerrainPaintBrushPresets
  editor.createFoliageGroup = createFoliageGroup
  editor.deleteFoliageGroup = deleteFoliageGroup
  editor.createFoliageMesh = createFoliageMesh
  editor.deleteFoliageMesh = deleteFoliageMesh
  editor.getFoliageMeshes = getFoliageMeshes
  editor.addFoliageBrushToGroup = addFoliageBrushToGroup
  editor.deleteFoliageBrush = deleteFoliageBrush
  editor.setFoliageBrushGroup = setFoliageBrushGroup
  editor.setFoliageBrush = setFoliageBrush
  editor.setFoliagePaintBrushSettings = setFoliagePaintBrushSettings
  editor.paintFoliage = paintFoliage
  editor.eraseFoliage = eraseFoliage
  editor.eraseSetFoliageBrushOrGroup = eraseSetFoliageBrushOrGroup
  editor.translateFoliageSelection = translateFoliageSelection
  editor.rotateFoliageSelection = rotateFoliageSelection
  editor.scaleFoliageSelection = scaleFoliageSelection
  editor.selectFoliage = selectFoliage
end

local M = {}
M.initialize = initialize

return M