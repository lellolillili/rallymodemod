-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local imgui = ui_imgui

M.dependencies = {'career_saveSystem'}

local careerActive = false
local careerModules = {}
local careerModuleDirectory = '/lua/ge/extensions/career/modules/'
local saveFile = "general.json"
local levelName = "west_coast_usa"
local defaultLevel = "/levels/west_coast_usa/main.level.json"
local debugActive = true
local closeAfterSaving

local blockedActions = core_input_actionFilter.createActionTemplate({"vehicleTeleporting", "vehicleMenues", "physicsControls", "aiControls", "vehicleSwitching", "funStuff"})

-- TODO maybe save whenever we go into the esc menu

local function blockInputActions(block)
  if shipping_build then
    core_input_actionFilter.setGroup('careerBlockedActions', blockedActions)
    core_input_actionFilter.addAction(0, 'careerBlockedActions', block)
  end
end

local function debugMenu()
  if not careerActive then return end
  imgui.SetNextWindowSize(imgui.ImVec2(300, 300), imgui.Cond_FirstUseEver)
  imgui.Begin("Career Debug")

  imgui.Text("Money: " .. career_modules_playerAttributes.getAttribute("money").value)
  imgui.SameLine()
  if imgui.Button("+1000##money") then career_modules_playerAttributes.addAttribute("money", 1000) end
  imgui.SameLine()
  if imgui.Button("-1000##money") then career_modules_playerAttributes.addAttribute("money", -1000) end

  imgui.Text("BeamXP: " .. career_modules_playerAttributes.getAttribute("beamXP").value)
  imgui.SameLine()
  if imgui.Button("+1000##beamXP") then career_modules_playerAttributes.addAttribute("beamXP", 1000) end
  imgui.SameLine()
  if imgui.Button("-1000##beamXP") then career_modules_playerAttributes.addAttribute("beamXP", -1000) end
  for _, branch in ipairs(career_branches.getSortedBranches()) do
    imgui.Text(branch.name ..": " .. career_modules_playerAttributes.getAttribute(branch.attributeKey).value.. " ( Level "..career_branches.getBranchLevel(branch.id).." )")
    imgui.SameLine()
    if imgui.Button("+100##"..branch.name) then career_modules_playerAttributes.addAttribute(branch.attributeKey,100) end
    imgui.SameLine()
    if imgui.Button("+500##"..branch.name) then career_modules_playerAttributes.addAttribute(branch.attributeKey,500) end
  end
  if imgui.Button("Reload Missions") then gameplay_missions_missions.reloadCompleteMissionSystem() end
  if imgui.Button("Make All Missions Startable") then
    for _, m in ipairs(gameplay_missions_missions.getFilesData()) do
      instance = gameplay_missions_missions.getMissionById(m.id)
      instance.unlocks.startable = true
      instance.unlocks.visible = true
    end
    gameplay_missions_clustering.clear()
  end
  if imgui.Button("Open Quest UI")then
    career_modules_questUI.openQuests()
  end
  if imgui.Button("Enter Garage Mode##dasdasd") then
    gameplay_garageMode.start(true)
  end

  if gameplay_garageMode.isActive() then
    if imgui.Button("Exit Garage Mode") then
      gameplay_garageMode.stop()
    end
  end
  if imgui.Button("Save Career") then
    career_saveSystem.saveCurrent()
  end
  local endCareerMode = false
  if imgui.Button("Exit Career Mode") then
    endCareerMode = true
  end

  if imgui.Button("Add this Vehicle as new vehicle to inventory") then
    local vehId = career_modules_inventory.addVehicle(be:getPlayerVehicleID(0))
    career_modules_inventory.enterVehicle(vehId)
  end

  local currentVehicle = career_modules_inventory.getCurrentVehicle()

  if imgui.Button("Overwrite players vehicle with this one") then
    local vehId = career_modules_inventory.addVehicle(be:getPlayerVehicleID(0), currentVehicle)
    career_modules_inventory.enterVehicle(vehId)
  end

  if currentVehicle then
    imgui.Text("Current Vehicle: " .. currentVehicle .. " (" .. career_modules_inventory.vehicles[currentVehicle].model .. ")")
  end
  if imgui.BeginChild1("Owned Vehicles", imgui.ImVec2(0, 150), true) then
    imgui.Text("Change to one of your vehicles")
    local vehicleToRemove
    for id, data in pairs(career_modules_inventory.vehicles) do
      if imgui.Button("id " .. id .. " (" .. data.model .. ")") then
        career_modules_inventory.enterVehicle(id)
      end
      imgui.SameLine()

      if imgui.Button("remove##" .. id) then
        vehicleToRemove = id
      end
    end
  end
  imgui.EndChild()

  if career_modules_partShopping.isShoppingSessionActive() then
    imgui.Text("Parts in Shop")
    if imgui.BeginChild1("Shopping##parts", imgui.ImVec2(0, 200), true) then
      for partName, part in pairs(career_modules_partShopping.getPartInfos().partsInShop) do
        if imgui.Button(partName .. " (" .. part.value .. ")") then
          career_modules_partShopping.installPartById(part.id)
        end
      end
    end
    imgui.EndChild()
    imgui.Text("Shopping Cart")
    if imgui.BeginChild1("Shopping Cart", imgui.ImVec2(0, 150), true) then
      imgui.Columns(3, "shopping cart")
      imgui.Separator()
      imgui.Text("Slot")
      imgui.NextColumn()
      imgui.Text("Parts In")
      imgui.NextColumn()
      imgui.Text("Parts Out")
      imgui.Separator()
      imgui.NextColumn()

      local shoppingCart = career_modules_partShopping.getShoppingCart()
      local partsInList = shoppingCart.partsInList
      local partsOutList = shoppingCart.partsOutList
      local slotList = shoppingCart.slotList
      for i, slot in ipairs(slotList) do
        imgui.Text(slot)
        imgui.NextColumn()
        if partsInList[i] then
          imgui.Text(partsInList[i].name .. " (" .. partsInList[i].value .. ")")
        end
        imgui.NextColumn()
        if partsOutList[i] then
          imgui.Text(partsOutList[i].name .. " (" .. partsOutList[i].value .. ")")
        end
        imgui.NextColumn()
      end

      imgui.Columns(1)
      imgui.Text("Total: " .. shoppingCart.total)
    end
    imgui.EndChild()
    if imgui.Button("Apply Shopping") then
      career_modules_partShopping.applyShopping()
    end
    imgui.SameLine()
    if imgui.Button("Cancel Shopping") then
      career_modules_partShopping.cancelShopping()
    end
  else
    if imgui.Button("Start Part Shopping") then
      career_modules_partShopping.startShopping()
    end
  end

  --[[if career_modules_vehicleShopping.isShoppingSessionActive() then
    imgui.Text("Vehicles in Shop")
    if imgui.BeginChild1("Shopping##vehicles", imgui.ImVec2(0, 200), true) then
      for index, vehicle in ipairs(career_modules_vehicleShopping.getVehiclesInShop()) do
        if imgui.Button(vehicle.spawnData.model .. " " .. vehicle.spawnData.config .. " (" .. vehicle.value .. ")##" .. index) then
          career_modules_vehicleShopping.spawnVehicle(index)
        end
      end
    end
    imgui.EndChild()

    local chosenVehicle = career_modules_vehicleShopping.getVehiclesInShop()[career_modules_vehicleShopping.getSelectedVehicleIndex()]
    if chosenVehicle then
      imgui.Text("Chosen Vehicle: ")
      imgui.SameLine()
      imgui.Text(chosenVehicle.spawnData.model .. " " .. chosenVehicle.spawnData.config .. " (" .. chosenVehicle.value .. ")")
    end

    if imgui.Button("Buy vehicle") then
      career_modules_vehicleShopping.applyShopping()
    end
    imgui.SameLine()
    if imgui.Button("Cancel Shopping") then
      career_modules_vehicleShopping.cancelShopping()
    end
  else
    if imgui.Button("Start Vehicle Shopping") then
      career_modules_vehicleShopping.startShopping()
    end
  end--]]

  if imgui.Button("Fuel") then
    career_modules_fuel.startTransaction()
  end

  imgui.End()

  if vehicleToRemove then
    career_modules_inventory.removeVehicle(vehicleToRemove)
  end

  if endCareerMode then
    M.deactivateCareer()
    return true
  end
end

local function onCareerActivatedWhileLevelLoaded()
  blockInputActions(true)
  bullettime.pause(false)
end

local function toggleCareerModules(active, alreadyInLevel)
  if active then
    table.clear(careerModules)
    local extensionFiles = {}
    local files = FS:findFiles(careerModuleDirectory, '*.lua', 0, false, false)
    for i = 1, tableSize(files) do
      extensions.luaPathToExtName(modulePath)
      local extensionFile = string.gsub(files[i], "/lua/ge/extensions/", "")
      extensionFile = string.gsub(extensionFile, ".lua", "")
      table.insert(extensionFiles, extensionFile)
      table.insert(careerModules, extensions.luaPathToExtName(extensionFile))
    end
    extensions.load(careerModules)

    -- register modules as core modules so they dont get unloaded when switching level
    for _, module in ipairs(extensionFiles) do
      registerCoreModule(module)
    end

    if alreadyInLevel then
      -- call this when the career was started with the level already loaded
      for _, moduleName in ipairs(careerModules) do
        if extensions[moduleName].onCareerActivatedWhileLevelLoaded then
          extensions[moduleName].onCareerActivatedWhileLevelLoaded()
        end
      end
      onCareerActivatedWhileLevelLoaded()
    end
  else
    for _, name in ipairs(careerModules) do
      extensions.unload(name)
    end
    table.clear(careerModules)
  end
end


local function onUpdate(dtReal, dtSim, dtRaw)
  if not careerActive then return end
  if not shipping_build then
    if debugMenu() then
      return
    end
  end
end

local function activateCareer(removeVehicles)
  if careerActive then return end
  -- load career
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot then return end

  if removeVehicles == nil then
    removeVehicles = true
  end
  careerActive = true
  log("I", "Loading career from " .. savePath .. "/career/" .. saveFile)
  local careerData = jsonReadFile(savePath .. "/career/" .. saveFile) or {}
  local levelToLoad = careerData.level or levelName

  if not getCurrentLevelIdentifier() or (getCurrentLevelIdentifier() ~= levelToLoad) then
    freeroam_freeroam.startFreeroam(path.getPathLevelMain(levelToLoad))
    toggleCareerModules(true)
  else
    if removeVehicles then
      core_vehicles.removeAll()
    end
    toggleCareerModules(true, true)
    M.onUpdate = onUpdate
  end

  gameplay_missions_clustering.clear()
  extensions.hook("onCareerActive", true)
end

local function deactivateCareer(saveCareer)
  if not careerActive then return end
  M.onUpdate = nil
  if saveCareer then
    --career_saveSystem.saveCurrent(true) -- not sure if we want to allow saving here
  end
  toggleCareerModules(false)
  blockInputActions(false)
  careerActive = false
  gameplay_missions_clustering.clear()

  extensions.hook("onCareerActive", false)
end

local function deactivateCareerAndReloadLevel(saveCareer)
  if not careerActive then return end
  deactivateCareer(saveCareer)
  freeroam_freeroam.startFreeroam(path.getPathLevelMain(getCurrentLevelIdentifier()))
end

local function isCareerActive()
  return careerActive
end

local function createOrLoadCareerAndStart(name, specificAutosave)
  if career_saveSystem.setSaveSlot(name, specificAutosave) then
    activateCareer()
    return true
  end
  return false
end

local function onSaveCurrentSaveSlot(currentSavePath)
  if not careerActive then return end

  local filePath = currentSavePath .. "/career/" .. saveFile
  -- read the info file
  local data = {}

  data.level = getCurrentLevelIdentifier()

  jsonWriteFile(filePath, data, true)
end

local function onBeforeSetSaveSlot(currentSavePath, currentSaveSlot)
  if isCareerActive() then
    deactivateCareer()
  end
end

local function onClientStartMission(levelPath)
  if careerActive then
    M.onUpdate = onUpdate
    onCareerActivatedWhileLevelLoaded()
  end
end

local beamXPLevels ={
    {requiredValue = 0}, -- to reach lvl 1
    {requiredValue = 100},-- to reach lvl 2
    {requiredValue = 300},-- to reach lvl 3
    {requiredValue = 600},-- to reach lvl 4
    {requiredValue = 1000},-- to reach lvl 5
}
local function getBeamXPLevel(xp)
  local level = -1
  local neededForNext = -1
  local curLvlProgress = -1
  for i, lvl in ipairs(beamXPLevels) do
    if xp >= lvl.requiredValue then
      level = i
    end
  end
  if beamXPLevels[level+1] then
    neededForNext = beamXPLevels[level+1].requiredValue
    curLvlProgress = xp - beamXPLevels[level].requiredValue
  end
  return level, curLvlProgress, neededForNext
end

local function formatSaveSlotForUi(saveSlot)
  local autosavePath = career_saveSystem.getAutosave(career_saveSystem.getSaveRootDirectory() .. saveSlot)
  local attData = jsonReadFile(autosavePath .. "/career/playerAttributes.json")
  local infoData = jsonReadFile(autosavePath .. "/info.json")
  local inventoryData = jsonReadFile(autosavePath .. "/career/inventory.json")
  if attData then
    local data = {
      id = saveSlot
    }
    data.id = saveSlot

    data.money = deepcopy(attData.money)
    data.beamXP = deepcopy(attData.beamXP)
    data.beamXP.level, data.beamXP.curLvlProgress, data.beamXP.neededForNext = getBeamXPLevel(data.beamXP.value)
    for bId, br in pairs(career_branches.getBranches()) do
      local attKey = br.attributeKey
      data[attKey] = deepcopy(attData[attKey])
      data[attKey].level, data[attKey].curLvlProgress, data[attKey].neededForNext = career_branches.calcBranchLevelFromValue(data[attKey].value, bId)
    end

    -- add the infoData raw
    if infoData then
      tableMerge(data, infoData)
    end

    if inventoryData.currentVehicle then
      local vehicleData = jsonReadFile(autosavePath .. "/career/vehicles/" .. inventoryData.currentVehicle .. ".json")
      if vehicleData then
        local modelData = core_vehicles.getModel(vehicleData.model)
        if modelData and modelData.model then
          data.currentVehicle = (modelData.model.Brand or "") .. " " .. modelData.model.Name
        end
      end
    end
    return data
  end
end

local function sendAllCareerSaveSlotsData()
  local res = {}
  for _, saveSlot in ipairs(career_saveSystem.getAllSaveSlots()) do
    local saveSlotData = formatSaveSlotForUi(saveSlot)
    if saveSlotData then
      table.insert(res, saveSlotData)
    end
  end

  table.sort(res, function(a,b) return (a.creationDate or "Z") < (b.creationDate or "Z") end)
  guihooks.trigger("allCareerSaveSlots", res)
  return res
end

local function sendCurrentSaveSlotData()
  if not careerActive then return end
  local saveSlot = career_saveSystem.getCurrentSaveSlot()
  if saveSlot then
    local data = formatSaveSlotForUi(saveSlot)
    if data then
      guihooks.trigger("sendCurrentSaveSlotData", data)
      return data
    end
  end
end

local function getAutosavesForSaveSlot(saveSlot)
  local res = {}
  for _, saveData in ipairs(career_saveSystem.getAllAutosaves(saveSlot)) do
    local data = jsonReadFile(career_saveSystem.getSaveRootDirectory() .. saveSlot .. "/" .. saveData.name .. "/career/playerAttributes.json")
    if data then
      data.id = saveSlot
      data.autosaveName = saveData.name
      table.insert(res, data)
    end
  end
  guihooks.trigger("allCareerAutosaves", res)
  return res
end

local function onClientEndMission(levelPath)
  if not careerActive then return end
  local levelNameToLoad = path.levelFromPath(levelPath)
  if levelNameToLoad == levelName then
    deactivateCareer()
  end
end

local function onSerialize()
  local data = {}
  if careerActive then
    data.reactivate = true
    deactivateCareer()
  end
  return data
end

local function onDeserialized(v)
  if v.reactivate then
    activateCareer(false)
  end
end

local function sendCurrentSaveSlotName()
  guihooks.trigger("currentSaveSlotName", {saveSlot = career_saveSystem.getCurrentSaveSlot()})
end

local function onVehicleSaveFinished()
  if closeAfterSaving then
    shutdown(0)
  end
end

local function onPreWindowClose()
  if careerActive then
    Engine.cancelShutdown()
    closeAfterSaving = true
    career_saveSystem.saveCurrent()
  end
end

local function onPreExit()
  if isCareerActive() then
    --career_saveSystem.saveCurrent(true) -- TODO we need to delay the exit until the vehicle stuff is saved (check editor exit popup)
  end
end

local function saveNewVehicleToInventory()
  if not careerActive then return end
  local vehId = career_modules_inventory.addVehicle(be:getPlayerVehicleID(0))
  career_modules_inventory.enterVehicle(vehId, true)
  gameplay_garageMode.setVehicleDirty(false)
  ui_message("ui.career.garage.saveVehiclePopup")
end

local function saveCurrentVehicleToInventory()
  if not careerActive then return end
  local currentVehicle = career_modules_inventory.getCurrentVehicle()
  local vehId = career_modules_inventory.addVehicle(be:getPlayerVehicleID(0), currentVehicle)
  career_modules_inventory.enterVehicle(vehId, true)
  gameplay_garageMode.setVehicleDirty(false)
  ui_message("ui.career.garage.saveVehiclePopup")
end

local function onAnyMissionChanged(state, mission)
  if not careerActive then return end
  if mission then
    if state == "stopped" then
      blockInputActions(true)
    elseif state == "started" then
      blockInputActions(false)
    end
  end
end

local physicsPausedFromOutside = false
local function onPhysicsPaused()
  physicsPausedFromOutside = true
end

local function onPhysicsUnpaused()
  physicsPausedFromOutside = false
end

local function requestPause(pause)
  if careerActive then
    if (pause == bullettime.getPause()) or physicsPausedFromOutside then return end
    bullettime.pause(pause)
    physicsPausedFromOutside = false
  end
end

M.createOrLoadCareerAndStart = createOrLoadCareerAndStart
M.activateCareer = activateCareer
M.deactivateCareer = deactivateCareer
M.deactivateCareerAndReloadLevel = deactivateCareerAndReloadLevel
M.isCareerActive = isCareerActive
M.sendAllCareerSaveSlotsData = sendAllCareerSaveSlotsData
M.sendCurrentSaveSlotData = sendCurrentSaveSlotData
M.getAutosavesForSaveSlot = getAutosavesForSaveSlot
M.requestPause = requestPause


M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot
M.onBeforeSetSaveSlot = onBeforeSetSaveSlot
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized
M.onClientStartMission = onClientStartMission
M.onClientEndMission = onClientEndMission
M.onExtensionLoaded = onExtensionLoaded
M.onPreExit = onPreExit
M.onAnyMissionChanged = onAnyMissionChanged
M.onPhysicsPaused = onPhysicsPaused
M.onPhysicsUnpaused = onPhysicsUnpaused
M.onVehicleSaveFinished = onVehicleSaveFinished
M.onPreWindowClose = onPreWindowClose

M.saveNewVehicleToInventory = saveNewVehicleToInventory
M.saveCurrentVehicleToInventory = saveCurrentVehicleToInventory

M.sendCurrentSaveSlotName = sendCurrentSaveSlotName

return M
