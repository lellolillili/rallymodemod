-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local saveRoot = 'settings/cloud/saves/'
local infoFile = 'info.json'
local saveSystemVersion = 2
local numberOfAutosaves = 3
local saveDateOfCurrentAutoSave
local creationDateOfCurrentSaveSlot

local currentSaveSlot
local currentSavePath

local function getAllAutosaves(slotName)
  local res = {}
  local folders = FS:directoryList(saveRoot .. slotName, false, true)
  for i = 1, tableSize(folders) do
    local dir, filename, ext = path.split(folders[i])
    local data = jsonReadFile(dir .. filename .. "/info.json")
    if data then
      data.name = filename
      table.insert(res, data)
    end
  end

  table.sort(res, function(a,b) return a.date < b.date end)
  return res
end

local function getAutosave(path, oldest)
  local resultDate = oldest and "A" or "0"
  local resultSave = ""
  local folders = FS:directoryList(path, false, true)
  -- TODO use getAllAutosaves to get the newest or oldest save
  if (tableSize(folders) < numberOfAutosaves) and oldest then
    resultSave = path .. "/autosave" .. (tableSize(folders) + 1)
    resultDate = "0"
  else
    for i = 1, tableSize(folders) do
      local data = jsonReadFile(folders[i] .. "/info.json")
      if data then
        if (oldest and (data.date < resultDate)) or (not oldest and (data.date > resultDate)) then
          resultSave = folders[i]
          resultDate = data.date
        end
      end
    end
  end
  return resultSave, resultDate
end

local function isLegalDirectoryName(name)
  return not string.match(name, '[<>:"/\\|?*]')
end

local function setSaveSlot(slotName, specificAutosave)
  extensions.hook("onBeforeSetSaveSlot")
  if not slotName then
    currentSavePath = nil
    currentSaveSlot = nil
    creationDateOfCurrentSaveSlot = nil
    extensions.hook("onSetSaveSlot", nil, nil)
    return false
  end
  if not isLegalDirectoryName(slotName) then
    return false
  end
  currentSavePath = specificAutosave and (saveRoot .. slotName .. "/" .. specificAutosave) or getAutosave(saveRoot .. slotName, false) -- get newest autosave
  currentSaveSlot = slotName

  local data = jsonReadFile(currentSavePath .. "/info.json")
  if data then
    creationDateOfCurrentSaveSlot = data.creationDate
  else
    creationDateOfCurrentSaveSlot = nil
  end
  extensions.hook("onSetSaveSlot", currentSavePath, slotName)
  return true
end

local function removeSaveSlot(slotName)
  if currentSaveSlot == slotName then
    if not career_career.isCareerActive() then
      setSaveSlot(nil)
      FS:directoryRemove(saveRoot .. slotName)
    end
  else
    FS:directoryRemove(saveRoot .. slotName)
  end
end

local function renameFolderRec(oldName, newName, oldNameLength)
  local success = true
  local folders = FS:directoryList(oldName, true, true)
  for i = 1, tableSize(folders) do
    if FS:directoryExists(folders[i]) then
      if not renameFolderRec(folders[i], newName, oldNameLength) then
        success = false
      end
    else
      local newPath = string.sub(folders[i], oldNameLength + 2)
      newPath = newName .. newPath
      if FS:renameFile(folders[i], newPath) == -1 then
        success = false
      end
    end
  end
  return success
end

local function renameFolder(oldName, newName)
  local oldNameLength = string.len(oldName)
  if renameFolderRec(oldName, newName, oldNameLength) then
    -- If the renaming of all files was successful, remove the old folder
    FS:directoryRemove(oldName)
    return true
  end
end

local function renameSaveSlot(slotName, newName)
  if not isLegalDirectoryName(slotName) or not FS:directoryExists(saveRoot .. slotName)
  or FS:directoryExists(saveRoot .. newName) then
    return false
  end

  if currentSaveSlot == slotName then
    if not career_career.isCareerActive() then
      setSaveSlot(nil)
      return renameFolder(saveRoot .. slotName, saveRoot .. newName)
    end
  else
    return renameFolder(saveRoot .. slotName, saveRoot .. newName)
  end
end

local function getCurrentSaveSlot()
  return currentSaveSlot, currentSavePath
end

local function saveCurrent(forceSyncSave)
  if not currentSaveSlot then return end
  local oldestSave, saveDate = getAutosave(saveRoot .. currentSaveSlot, true) -- get oldest autosave to overwrite

  local infoData = {}
  infoData.version = saveSystemVersion
  infoData.date = os.date("!%Y-%m-%dT%XZ") -- UTC time
  creationDateOfCurrentSaveSlot = creationDateOfCurrentSaveSlot or infoData.date
  infoData.creationDate = creationDateOfCurrentSaveSlot

  jsonWriteFile(oldestSave .. "/info.json", infoData, true)
  currentSavePath = oldestSave -- update the currentSavePath
  saveDateOfCurrentAutoSave = infoData.date
  extensions.hook("onSaveCurrentSaveSlot", oldestSave, saveDate, forceSyncSave)
  log("I", "Saved to " .. oldestSave)
end

local function getAllSaveSlots()
  local res = {}
  local folders = FS:directoryList(saveRoot, false, true)
  for i = 1, tableSize(folders) do
    local dir, filename, ext = path.split(folders[i])
    table.insert(res, filename)
  end
  return res
end

local function getSaveDateOfCurrentAutoSave()
  return saveDateOfCurrentAutoSave
end

local function onExtensionLoaded()
end

local function getSaveRootDirectory()
  return saveRoot
end

local function onSerialize()
  local data = {}
  data.currentSaveSlot = currentSaveSlot
  data.currentSavePath = currentSavePath
  data.creationDateOfCurrentSaveSlot = creationDateOfCurrentSaveSlot
  data.saveDateOfCurrentAutoSave = saveDateOfCurrentAutoSave
  return data
end

local function onDeserialized(v)
  currentSaveSlot = v.currentSaveSlot
  currentSavePath = v.currentSavePath
  creationDateOfCurrentSaveSlot = v.creationDateOfCurrentSaveSlot
  saveDateOfCurrentAutoSave = v.saveDateOfCurrentAutoSave
end

M.setSaveSlot = setSaveSlot
M.removeSaveSlot = removeSaveSlot
M.renameSaveSlot = renameSaveSlot
M.getCurrentSaveSlot = getCurrentSaveSlot
M.saveCurrent = saveCurrent
M.getAllSaveSlots = getAllSaveSlots
M.getSaveDateOfCurrentAutoSave = getSaveDateOfCurrentAutoSave
M.getSaveRootDirectory = getSaveRootDirectory
M.getAutosave = getAutosave
M.getAllAutosaves = getAllAutosaves

M.onExtensionLoaded = onExtensionLoaded
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

return M