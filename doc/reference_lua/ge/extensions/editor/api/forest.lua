-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local editor

local function copyMat(mat)
  return mat * MatrixF(true)
end

--- Rotate forest items selection.
-- @param forestData the ForestData C++ class where the forest items are hold
-- @param deltaEulerRotation eurler rotation to be added
-- @param centerPoint center point around where rotation will happen
-- @param originalTransforms the previous transforms of the forest items
local function rotateForestSelection(forestData, deltaEulerRotation, centerPoint, originalTransforms)
  -- single selections will rotate around own axis, multiple about world
  if tableSize(editor.selection.forestItem) == 1 then
    local object = editor.selection.forestItem[1]
    if object then
      local rotMtx = MatrixF(true)
      rotMtx:setFromEuler(deltaEulerRotation)
      if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_World then
        rotMtx:mul(originalTransforms[1])
        rotMtx:setColumn(3, originalTransforms[1]:getColumn(3))
        editor.selection.forestItem[1] = forestData:updateItem(object:getKey(), object:getPosition(), object:getData(), rotMtx, object:getScale())
      else
        editor.selection.forestItem[1] =
        forestData:updateItem(object:getKey(), object:getPosition(), object:getData(), originalTransforms[1] * rotMtx, object:getScale())
      end
    end
  else
    local rotMtx = MatrixF(true)
    for i, object in ipairs(editor.selection.forestItem) do
      rotMtx:set(deltaEulerRotation, centerPoint)
      local objTrans = copyMat(originalTransforms[i])
      objTrans:setColumn(3, objTrans:getColumn(3) - centerPoint)
      rotMtx:mul(objTrans)
      editor.selection.forestItem[i] = forestData:updateItem(object:getKey(), object:getPosition(), object:getData(), rotMtx, object:getScale())
    end
  end
end

--- Add a new forest item to the forest data.
-- @param forestData the ForestData C++ class where to add the item
-- @param item the C++ ForestItem to be added
local function addForestItem(forestData, item)
  forestData:addItem(item)
  editor.forestDirty = true
  editor.setDirty()
end

--- Remove a forest item
-- @param forestData the ForestData C++ class from where to remove the item
-- @param item the C++ ForestItem to be removed
local function removeForestItem(forestData, item)
  forestData:removeItem(item)
  editor.forestDirty = true
  editor.setDirty()
end

--- Update a forest item instance information
-- TODOC:
-- @param forestData
-- @param key
-- @param keyPos
-- @param newData
-- @param newTrans
-- @param newScale
local function updateForestItem(forestData, key, keyPos, newData, newTrans, newScale)
  editor.forestDirty = true
  editor.setDirty()
  return forestData:updateItem(key, keyPos, newData, newTrans, newScale)
end

local function initialize(editorInstance)
  editor = editorInstance
  editor.rotateForestSelection = rotateForestSelection
  editor.addForestItem = addForestItem
  editor.removeForestItem = removeForestItem
  editor.updateForestItem = updateForestItem
end

local M = {}
M.initialize = initialize

return M