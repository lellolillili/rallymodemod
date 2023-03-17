-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local editor
local defaultFilename = "art/datablocks/managedDatablocks.json";

--- Create a new data block.
-- @param name the data block unique name
-- @param type the data block type
-- @param copyFrom the data block to be copied, can be nil
-- @param filename the data block filename
local function createDataBlock(name, type, copyFrom, filename)
  local dataBlock = worldEditorCppApi.createObject(type)
  dataBlock:registerObject("")
  local dataBlockGroup = scenetree.findObject("dataBlockGroup")
  if dataBlockGroup then
    dataBlockGroup:addObject(dataBlock)
  end

  if copyFrom and copyFrom ~= "" then
    local copiedDataBlock = scenetree.findObject(copyFrom)
    if copiedDataBlock then
      editor.pasteFields(editor.copyFields(copiedDataBlock:getID()), dataBlock:getID())
    end
  end

  if name then
    dataBlock:setName(name)
  end
  Sim.getDataBlockSet():addObject(dataBlock)

  editor.setDirty()
  scenetree.dataBlockPersistMan:setDirty(dataBlock, filename or defaultFilename)
  dataBlock:setFileName(filename or defaultFilename)
  return dataBlock:getID()
end

--- Save a modified data block.
-- @param dataBlock the data block object to be saved if dirty (modified)
local function saveDirtyDataBlock(dataBlock)
  scenetree.dataBlockPersistMan:saveDirtyObject(dataBlock)
end

--- Delete a data block from its containing file.
-- @param dataBlock the data block object to be removed from the file
local function removeDataBlockFromFile(dataBlock)
  Sim.getDataBlockSet():removeObject(dataBlock)
  if dataBlock:getFileName() ~= "" then
    scenetree.dataBlockPersistMan:removeObjectFromFileLua(dataBlock)
  end
end

--- Add a data block to a file.
-- @param dataBlock the data block to be added to the file
-- @param filename the file where to add the data block
local function addDatablockToFile(dataBlock, filename)
  Sim.getDataBlockSet():addObject(dataBlock)
  scenetree.dataBlockPersistMan:setDirty(dataBlock, filename or dataBlock:getFileName())
end

--- Save a data block to a file.
-- @param dataBlock the data block to be saved into the file
-- @param filename the file where to save the data block
local function saveDataBlockToFile(dataBlock, filename)
  scenetree.dataBlockPersistMan:setDirty(dataBlock, filename or dataBlock:getFileName())
  scenetree.dataBlockPersistMan:saveDirtyObject(dataBlock)
end

--- Returns true if data block was modified
local function isDataBlockDirty(dataBlock)
  return scenetree.dataBlockPersistMan:isDirty(dataBlock)
end

--- Set the dirty state (was modified) of the data block.
-- @param dataBlock the datablock to report as modified
local function setDataBlockDirty(dataBlock)
  scenetree.dataBlockPersistMan:setDirty(dataBlock, dataBlock:getFileName() or defaultFilename)
end

--- Returns the data block objects array
local function getDataBlocks()
  return Sim.getDataBlockSet()
end

--- Returns the datablock object by its name, or nil if none found
-- @param name the name of the data block to find
local function findDataBlock(name)
  for index = 0, Sim.getDataBlockSet():size() - 1 do
    local dataBlock = Sim.getDataBlockSet():at(index)
    if dataBlock:getName() == name then return dataBlock end
  end
end

local function initialize(editorInstance)
  if not scenetree.dataBlockPersistMan then
    local persistenceMgr = PersistenceManager()
    persistenceMgr:registerObject("dataBlockPersistMan")
  end

  editor = editorInstance
  editor.createDataBlock = createDataBlock
  editor.removeDataBlockFromFile = removeDataBlockFromFile
  editor.saveDirtyDataBlock = saveDirtyDataBlock
  editor.getDataBlocks = getDataBlocks
  editor.findDataBlock = findDataBlock
  editor.addDataBlockToFile = addDataBlockToFile
  editor.saveDataBlockToFile = saveDataBlockToFile
  editor.isDataBlockDirty = isDataBlockDirty
  editor.setDataBlockDirty = setDataBlockDirty
end

local M = {}
M.initialize = initialize

return M