-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_particleEditor'
local im = ui_imgui
local defaultEmitterFile = "art/shapes/particles/managedParticleEmitterData.json"
local defaultParticleFile = "art/shapes/particles/managedParticleData.json"

local particleEmitterID
local particleEmitters = {}
local editableEmitterNode

local currentEmitter
local oldEmitterFields
local requestedEmitter

local particleDatas = {}
local currentParticle
local oldParticleFields
local requestedParticle

local function updateDatablockList()
  particleEmitters = {}
  particleDatas = {}
  for index=0, Sim.getDataBlockSet():size()-1 do
    local dataBlock = Sim.getDataBlockSet():at(index)
    if dataBlock:getClassName() == "ParticleEmitterData" then
      table.insert(particleEmitters, dataBlock)
    elseif dataBlock:getClassName() == "ParticleData" then
      table.insert(particleDatas, dataBlock)
    end
  end
end

local function selectEmitter(emitter)
  currentEmitter = emitter
  editableEmitterNode:setField("emitter", 0, currentEmitter:getName())
  editableEmitterNode:setEmitterDataBlock(currentEmitter)
  oldEmitterFields = editor.copyFields(currentEmitter:getID())
end

local function selectEmitterFromMenu(emitter)
  if currentEmitter and editor.isDataBlockDirty(currentEmitter) then
    requestedEmitter = emitter
  else
    selectEmitter(emitter)
  end
end

local function selectParticle(particle)
  currentParticle = particle
  oldParticleFields = editor.copyFields(currentEmitter:getID())
end

local function selectParticleFromMenu(particle)
  if currentParticle and editor.isDataBlockDirty(currentParticle) then
    requestedParticle = particle
  else
    selectParticle(particle)
  end
end

local function resetEditableEmitterNode()
  if scenetree.findObject("editableEmitterNode") then
    scenetree.findObject("editableEmitterNode"):delete()
  end

  editableEmitterNode = worldEditorCppApi.createObject("ParticleEmitterNode")
  editableEmitterNode:setField("dataBlock", 0, "lightExampleEmitterNodeData1")
  editableEmitterNode:registerObject("")
  editableEmitterNode:setField("name", 0, "editableEmitterNode")
  selectEmitter(Sim.upcast(particleEmitters[1]))
  local direction = editor.getCamera():getTransform():getColumn(1)
  direction = direction * 7
  editableEmitterNode:setPosition(getCameraPosition() + direction)
  -- add it to the currently selected group in the scene tree
  editor.getSceneTreeSelectedGroup():addObject(editableEmitterNode)
end

-- Call a function for each ParticleData of an emitter
local function loopParticles(emitter, fct)
  local stringList = emitter:getField("particles","")

  while string.len(stringList) > 0 do
    local first, last, particleDataName = string.find(stringList, '(%S+)')

    if particleDataName then
      stringList = stringList:sub(last+1)
      local particleData = scenetree.findObject(particleDataName)
      if particleData then
        fct(particleData)
      end
    else
      stringList = ""
    end
  end
end

local function getParticleCount(emitter)
  local index = 0
  local stringList = emitter:getField("particles","")

  while string.len(stringList) > 0 do
    local first, last, particleDataName = string.find(stringList, '(%S+)')

    if particleDataName then
      stringList = stringList:sub(last+1)
    else
      stringList = ""
    end
    index = index + 1
  end
  return index
end

local function cleanTabs(str)
  str = string.gsub(str, "\t+", "\t")
  str = string.gsub(str, "\t$", "")
  return string.gsub(str, "^\t", "")
end

-- Create Emitter
local function createEmitterActionUndo(actionData)
  local emitter = scenetree.findObjectById(actionData.id)
  editor.removeDataBlockFromFile(emitter)
  updateDatablockList()
  if emitter:getFileName() ~= "" then
    editor.saveDirtyDataBlock(emitter)
  end
  selectEmitter(Sim.upcast(particleEmitters[1]))
end

local function createEmitterActionRedo(actionData)
  local emitter
  if not actionData.id then
    local newEmitterName = Sim.getUniqueName("newEmitter")
    actionData.id = editor.createDataBlock(newEmitterName, "ParticleEmitterData", "DefaultEmitter", defaultEmitterFile)
    emitter = scenetree.findObjectById(actionData.id)
  else
    emitter = scenetree.findObjectById(actionData.id)
    Sim.getDataBlockSet():addObject(emitter)
  end
  updateDatablockList()
  emitter:reload()
  selectEmitter(emitter)
end


-- Delete Emitter
local function deleteEmitterActionUndo(actionData)
  local emitter = scenetree.findObjectById(actionData.id)
  editor.addDataBlockToFile(emitter, emitter:getFileName())
  if emitter:getFileName() ~= "" then
    editor.saveDirtyDataBlock(emitter)
  end
  updateDatablockList()
  emitter:reload()
  selectEmitter(emitter)
end

local function deleteEmitterActionRedo(actionData)
  local emitter = scenetree.findObjectById(actionData.id)
  editor.removeDataBlockFromFile(emitter)
  if emitter:getFileName() ~= "" then
    editor.saveDirtyDataBlock(emitter)
  end
  updateDatablockList()
  selectEmitter(Sim.upcast(particleEmitters[1]))
end


-- Create Particle
local function createParticleActionUndo(actionData)
  local particle = scenetree.findObjectById(actionData.particleID)
  local emitter = scenetree.findObjectById(actionData.emitterID)

  local particles = emitter:getField("particles","")
  particles = string.gsub(particles, particle:getName(), "")
  particles = cleanTabs(particles)
  emitter:setField("particles", "", particles)
  emitter:reload()
  selectParticle(scenetree.findObject(string.match(emitter:getField("particles", ""), '(%S+)')))
end

local function createParticleActionRedo(actionData)
  local particle
  local emitter
  if not actionData.particleID then
    local newParticleName = Sim.getUniqueName("newParticle")
    actionData.particleID = editor.createDataBlock(newParticleName, "ParticleData", "DefaultParticle", defaultParticleFile)
    emitter = currentEmitter
    emitter:setField("particles", "", emitter:getField("particles", "") .. "\t" .. newParticleName)
    actionData.emitterID = emitter:getID()
    particle = scenetree.findObjectById(actionData.particleID)
  else
    particle = scenetree.findObjectById(actionData.particleID)
    emitter = scenetree.findObjectById(actionData.emitterID)
    Sim.getDataBlockSet():addObject(particle)
    emitter:setField("particles", "", emitter:getField("particles", "") .. "\t" .. particle:getName())
  end
  selectParticle(particle)
  emitter:reload()
  updateDatablockList()
end


-- Delete Particle
local function deleteParticleActionUndo(actionData)
  local particle = scenetree.findObjectById(actionData.particleID)
  local emitter = scenetree.findObjectById(actionData.emitterID)
  emitter:setField("particles", "", emitter:getField("particles", "") .. "\t" .. particle:getName())
  editor.addDataBlockToFile(particle, particle:getFileName())
  if particle:getFileName() ~= "" then
    editor.saveDirtyDataBlock(particle)
  end
  emitter:reload()
end

local function deleteParticleActionRedo(actionData)
  local particle = scenetree.findObjectById(actionData.particleID)
  local emitter = scenetree.findObjectById(actionData.emitterID)

  local particles = emitter:getField("particles","")
  local first, last, _ = string.find(particles, "(" .. particle:getName() .. ")")
  local newParticles = string.sub(particles, 1, first-1)
  newParticles = newParticles .. string.sub(particles, last+1)
  newParticles = cleanTabs(newParticles)
  emitter:setField("particles", "", newParticles)

  editor.removeDataBlockFromFile(particle)
  if particle:getFileName() ~= "" then
    editor.saveDirtyDataBlock(particle)
  end
  emitter:reload()
end


local function onActivate()
  log('I', logTag, "onActivate")
  updateDatablockList()
  resetEditableEmitterNode()
end

local function onDeactivate()
  if editableEmitterNode then
    editableEmitterNode:delete()
    editableEmitterNode = nil
  end
end

local function newEmitter()
  editor.history:commitAction("CreateParticleEmitter", {}, createEmitterActionUndo, createEmitterActionRedo)
end

local function newParticle()
  editor.history:commitAction("CreateParticle", {}, createParticleActionUndo, createParticleActionRedo)
end

local function deleteParticle(particle)
  editor.history:commitAction("DeleteParticle", {particleID = particle:getID(), emitterID = currentEmitter:getID()}, deleteParticleActionUndo, deleteParticleActionRedo)
end

local function deleteEmitter(emitter)
  editor.history:commitAction("DeleteParticleEmitter", {id = emitter:getID()}, deleteEmitterActionUndo, deleteEmitterActionRedo)
end

local function saveEmitter(emitter)
  editor.saveDataBlockToFile(emitter)
  loopParticles(emitter, editor.saveDataBlockToFile)
end

local function saveParticleToLevel(particle)
  local levelPath, levelName, _ = path.split(getMissionFilename())
  editor.saveDataBlockToFile(particle, levelPath .. defaultParticleFile)
  editor.showNotification("Saved particle to file: " .. levelPath .. defaultParticleFile)
end

local function saveEmitterToLevel(emitter)
  local levelPath, levelName, _ = path.split(getMissionFilename())
  editor.saveDataBlockToFile(emitter, levelPath .. defaultEmitterFile)
  loopParticles(emitter, saveParticleToLevel)
  editor.showNotification("Saved emitter to file: " .. levelPath .. defaultEmitterFile)
end

local lastFrameEmitterID
local confirmationWindowOpen = false
local windowPos

local function onEditorInspectorHeaderGui()
  if not editor.editMode or (editor.editMode.displayName ~= editor.editModes.particleEditMode.displayName) then
    return
  end
  windowPos = im.GetWindowPos()

  if im.BeginTabBar("particle editor##") then
    local flags = editor.isDataBlockDirty(currentEmitter) and im.TabItemFlags_UnsavedDocument or 0
    if im.BeginTabItem("Emitter", nil, flags) then
      if im.BeginCombo("##emitter", currentEmitter:getName()) then
        for _, emitter in ipairs(particleEmitters) do
          if im.Selectable1(emitter:__tostring()) then
            selectEmitterFromMenu(Sim.upcast(emitter))
          end
        end
        im.EndCombo()
      end
      im.SameLine()
      if editor.uiIconImageButton(editor.icons.add_circle, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0]), nil, nil, nil) then
        newEmitter()
      end
      im.tooltip("Create a new Emitter")

      im.SameLine()
      if editor.uiIconImageButton(editor.icons.material_save_current, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0]), nil, nil, nil) then
        saveEmitter(currentEmitter)
      end
      im.tooltip("Save Emitter to its file")

      im.SameLine()
      if editor.uiIconImageButton(editor.icons.material_save_all, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0]), nil, nil, nil) then
        saveEmitterToLevel(currentEmitter)
      end
      im.tooltip("Save Emitter to current level")

      im.SameLine()
      local disabled = false
      if currentEmitter:getName() == "DefaultEmitter" then
        im.BeginDisabled()
        disabled = true
      end
      if editor.uiIconImageButton(editor.icons.delete, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0]), nil, nil, nil) then
        deleteEmitter(currentEmitter)
        confirmationWindowOpen = true
      end
      im.tooltip("Delete Emitter")
      if disabled then im.EndDisabled() end

      if not editor.selection.object or (editor.selection.object[1] ~= currentEmitter:getID()) then
        editor.selectObjectById(currentEmitter:getID())
      end
      im.EndTabItem()
    end

    if lastFrameEmitterID ~= currentEmitter:getID() then
      currentParticle = scenetree.findObject(string.match(currentEmitter:getField("particles", ""), '(%S+)'))
      lastFrameEmitterID = currentEmitter:getID()
    end

    local flags = (currentParticle and editor.isDataBlockDirty(currentParticle)) and im.TabItemFlags_UnsavedDocument or 0
    if im.BeginTabItem("Particle", nil, flags) then
      if im.BeginCombo("##particle", currentParticle and currentParticle:getName() or "") then
        loopParticles(currentEmitter, function(particle)
          if im.Selectable1(particle:getName()) then
            selectParticleFromMenu(particle)
          end
        end)
        im.EndCombo()
      end

      im.SameLine()
      local disabled = false
      local particleCount = getParticleCount(currentEmitter)
      if particleCount >= 4 then im.BeginDisabled() disabled = true end
      if editor.uiIconImageButton(editor.icons.add_circle, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0]), nil, nil, nil) then
        newParticle()
      end
      if disabled then im.EndDisabled() disabled = false end
      im.SameLine()
      if not currentParticle then im.BeginDisabled() disabled = true end
      if editor.uiIconImageButton(editor.icons.material_save_current, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0]), nil, nil, nil) then
        editor.saveDataBlockToFile(currentParticle)
      end
      if disabled then im.EndDisabled() disabled = false end
      im.SameLine()
      if not currentParticle or particleCount <= 1 then im.BeginDisabled() disabled = true end
      if editor.uiIconImageButton(editor.icons.delete, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0]), nil, nil, nil) then
        deleteParticle(currentParticle)
        selectParticle(scenetree.findObject(string.match(currentEmitter:getField("particles", ""), '(%S+)')))
        confirmationWindowOpen = true
      end
      if disabled then im.EndDisabled() end

      if currentParticle then
        if not editor.selection.object or (editor.selection.object[1] ~= currentParticle:getID()) then
          editor.selectObjectById(currentParticle:getID())
        end
      else
        editor.deselectObjectSelection()
      end
      im.EndTabItem()
    end
    im.EndTabBar()
  end

  if confirmationWindowOpen then
    im.SetNextWindowPos(im.ImVec2(windowPos.x+50, windowPos.y+50), im.Cond_Appearing)
    --TODO: convert to modal popup
    if im.Begin("DataBlock Deleted", nil , 0) then
      im.Text("The DataBlock has been removed from its file and upon restart will cease to exist" )
      if im.Button("OK") then
        confirmationWindowOpen = false
      end
    end
    im.End()
  end

  if requestedEmitter then
    im.SetNextWindowPos(im.ImVec2(windowPos.x+50, windowPos.y+50), im.Cond_Appearing)
    --TODO: convert to modal popup
    if im.Begin("Save existing emitter?", nil , 0) then
      im.Text("Do you want to save changes to " ..  currentEmitter:getName() .. "?")
      if im.Button("Yes") then
        saveEmitter(currentEmitter)
        selectEmitter(requestedEmitter)
        requestedEmitter = nil
      end
      im.SameLine()
      if im.Button("No") then
        editor.pasteFields(oldEmitterFields, currentEmitter:getID())
        selectEmitter(requestedEmitter)
        requestedEmitter = nil
      end
      im.SameLine()
      if im.Button("Cancel") then
        requestedEmitter = nil
      end
    end
    im.End()
  end

  if requestedParticle then
    im.SetNextWindowPos(im.ImVec2(windowPos.x+50, windowPos.y+50), im.Cond_Appearing)
    --TODO: convert to modal popup
    if im.Begin("Save existing particle?", nil , 0) then
      im.Text("Do you want to save changes to " ..  currentParticle:getName() .. "?")
      if im.Button("Yes") then
        editor.saveDataBlockToFile(currentParticle)
        selectParticle(requestedParticle)
        requestedParticle = nil
      end
      im.SameLine()
      if im.Button("No") then
        editor.pasteFields(oldParticleFields, currentParticle:getID())
        selectParticle(requestedParticle)
        requestedParticle = nil
      end
      im.SameLine()
      if im.Button("Cancel") then
        requestedParticle = nil
      end
    end
    im.End()
  end
end

local function onEditorInspectorFieldChanged(selectedIds, fieldName, fieldValue, arrayIndex)
  local selectedID = selectedIds[1]
  if currentEmitter and currentEmitter:getID() == selectedID then
    editor.setDataBlockDirty(currentEmitter)
    currentEmitter:reload()
    updateDatablockList()
  elseif currentParticle and currentParticle:getID() == selectedID then
    editor.setDataBlockDirty(currentParticle)
    currentParticle:reload()
    updateDatablockList()
  end
end

local function customParticlesFieldEditor(objectIds, fieldValue, fieldName, fieldLabel, fieldDesc, fieldType, fieldTypeName, customData, pasteCallback, contextMenuUI)
  local valueChanged = false
  local particleNames = {}
  for s in fieldValue:gmatch("[^\t]+") do
    table.insert(particleNames, s)
  end
  for i = 1, 4 do
    local disabled
    if i > #particleNames + 1 then im.BeginDisabled() disabled = true end
    im.PushItemWidth(im.GetContentRegionAvailWidth() - 2 * (22 * im.uiscale[0]))
    if im.BeginCombo("##particles" .. i, particleNames[i] or "") then
      for _, particleData in ipairs(particleDatas) do
        if im.Selectable1(particleData:getName()) then
          particleNames[i] = particleData:getName()
          selectParticle(particleData)
          valueChanged = true
        end
      end
      im.EndCombo()
    end
    if not disabled then
      im.SameLine()
      if editor.uiIconImageButton(editor.icons.add_circle, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0]), nil, nil, nil) then
        local newParticleName = Sim.getUniqueName("newParticle")
        editor.createDataBlock(newParticleName, "ParticleData", "DefaultParticle", defaultParticleFile)
        particleNames[i] = newParticleName
        selectParticle(scenetree.findObject(newParticleName))
        valueChanged = true
      end
    end
    if particleNames[i] then
      im.SameLine()
      if editor.uiIconImageButton(editor.icons.remove_circle, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0]), nil, nil, nil) then
        table.remove(particleNames, i)
        selectParticle(scenetree.findObject(particleNames[1] or ""))
        valueChanged = true
      end
    end
    if disabled then im.EndDisabled() end
  end
  if valueChanged then
    local newFieldValue = particleNames[1] or ""
    for i = 2, #particleNames do
      newFieldValue = newFieldValue .. "\t" .. particleNames[i]
    end
    return {fieldValue = newFieldValue, editEnded = true}
  end
end

local particleTextureFileOpenPath = ""
local particleTextureFileOpenPathChanged = false

local function customTextureFieldEditor(objectIds, fieldValue, fieldName, fieldLabel, fieldDesc, fieldType, fieldTypeName, customData, pasteCallback, contextMenuUI)
  if im.Button("...") then
    editor_fileDialog.openFile(function(data)
      if data.filepath ~= "" then
        particleTextureFileOpenPath = data.filepath
        particleTextureFileOpenPathChanged = true
      end
    end, {{"All Files","*"}}, false, dir)
  end

  if particleTextureFileOpenPathChanged == true then
    particleTextureFileOpenPathChanged = false
    return {fieldValue = particleTextureFileOpenPath, editEnded = true}
  end

  im.SameLine()
  local imText = im.ArrayChar(2048, fieldValue)
  if im.InputText("##particleTexture", imText, nil, im.InputTextFlags_EnterReturnsTrue) then
    return {fieldValue = ffi.string(imText), editEnded = true}
  end
end

local function onEditorInitialized()
  editor.editModes.particleEditMode =
  {
    displayName = "Particle Editor",
    onActivate = onActivate,
    onDeactivate = onDeactivate,
    actionMap = nil,
    onUpdate = nop,
    onCopy = nil,
    onPaste = nil,
    icon = editor.icons.simobject_particle_emitter_node,
    iconTooltip = "Particle Editor"
  }
  editor.registerCustomFieldInspectorEditor("ParticleEmitterData", "particles", customParticlesFieldEditor)
  editor.registerCustomFieldInspectorEditor("ParticleData", "textureName", customTextureFieldEditor)
end

local function onExtensionLoaded()
  log('D', logTag, "initialized")
end

local function onExtensionUnloaded()
  if editableEmitterNode then
    editableEmitterNode:delete()
    editableEmitterNode = nil
  end
end

M.onEditorInitialized = onEditorInitialized
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onEditorInspectorHeaderGui = onEditorInspectorHeaderGui
M.onEditorInspectorFieldChanged = onEditorInspectorFieldChanged

return M