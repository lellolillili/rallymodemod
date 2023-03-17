-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_dataBlockEditor'
local im = ui_imgui
local dataBlockEditorWindowName = "dataBlockEditor"
local createDataBlockWindowName = "createDataBlock"

local dataBlockClasses = {}

-- New Datablock stuff
local newDataBlockClass
local newDataBlockName = im.ArrayChar(128)
local dataBlockToCopyName = ""
local dataBlockToCopyID

-- Create Emitter
local function createDataBlockActionUndo(actionData)
  local dataBlock = scenetree.findObjectById(actionData.id)
  editor.clearObjectSelection()
  editor.removeDataBlockFromFile(dataBlock)
  if dataBlock:getFileName() ~= "" then
    editor.saveDirtyDataBlock(dataBlock)
  end
end

local function createDataBlockActionRedo(actionData)
  if not actionData.id then
    actionData.id = editor.createDataBlock(actionData.name, actionData.className)
    if actionData.copyID then
      editor.pasteFields(editor.copyFields(actionData.copyID), actionData.id)
    end
  else
    local dataBlock = scenetree.findObjectById(actionData.id)
    Sim.getDataBlockSet():addObject(dataBlock)
  end
  editor.selectObjectById(actionData.id)
end


-- Delete Emitter
local function deleteDataBlockActionUndo(actionData)
  local dataBlock = scenetree.findObjectById(actionData.id)
  editor.addDataBlockToFile(dataBlock, dataBlock:getFileName())
  if dataBlock:getFileName() ~= "" then
    editor.saveDirtyDataBlock(dataBlock)
  end
  editor.selectObjectById(actionData.id)
end

local function deleteDataBlockActionRedo(actionData)
  local dataBlock = scenetree.findObjectById(actionData.id)
  editor.removeDataBlockFromFile(dataBlock)
  if dataBlock:getFileName() ~= "" then
    editor.saveDirtyDataBlock(dataBlock)
  end
end


local function onWindowMenuItem()
  editor.showWindow(dataBlockEditorWindowName)
end

local function getAllDataBlockClasses()
  local stringList = enumerateConsoleClasses("SimDataBlock")
  local resultTable = {}

  while string.len(stringList) > 0 do
    local first, last, name = string.find(stringList, '(%a+)')
    if name then
      resultTable[name] = {}
      stringList = stringList:sub(last+1)
    else
      stringList = ""
    end
  end

  for index = 0, Sim.getDataBlockSet():size() - 1 do
    local dataBlock = Sim.getDataBlockSet():at(index)
    if dataBlock:getFileName() then
      table.insert(resultTable[dataBlock:getClassName()], dataBlock)
    end
  end

  return resultTable
end

local function onEditorInitialized()
  editor.addWindowMenuItem("DataBlock Editor", onWindowMenuItem)
  editor.registerWindow(dataBlockEditorWindowName, im.ImVec2(200, 400))
  editor.registerWindow(createDataBlockWindowName, im.ImVec2(300, 200))
  dataBlockClasses = getAllDataBlockClasses()
end

local function onExtensionLoaded()
  log('D', logTag, "initialized")
end

local function isDataBlock(objectID)
  for index = 0, Sim.getDataBlockSet():size() - 1 do
    local dataBlock = Sim.getDataBlockSet():at(index)
    if dataBlock:getID() == objectID then return true end
  end
  return false
end

local oldDataBlockSetSize = 0
local confirmationWindowOpen = false

local function onEditorGui()
  if editor.isWindowVisible(dataBlockEditorWindowName) then
    local windowPos
    if Sim.getDataBlockSet():size() ~= oldDataBlockSetSize then
      dataBlockClasses = getAllDataBlockClasses()
      oldDataBlockSetSize = Sim.getDataBlockSet():size()
    end
    if editor.beginWindow(dataBlockEditorWindowName, "DataBlock Editor") then
      windowPos = im.GetWindowPos()
      if im.BeginTabBar("dataBlockEditor##") then
        local inExistingTab = false
        if im.BeginTabItem("Existing") then
          im.BeginChild1("Existing_Child", im.ImVec2(0, 0), false)
            inExistingTab = true
            for className, dataBlocks in pairs(dataBlockClasses) do
              if not tableIsEmpty(dataBlocks) then
                if im.TreeNode1(className) then
                  for _, dataBlock in ipairs(dataBlocks) do
                    local flags = im.TreeNodeFlags_Leaf
                    if editor.selection.object and editor.selection.object[1] then
                      local selected = scenetree.findObjectById(editor.selection.object[1])
                      if selected then
                        flags = bit.bor(flags, (selected:getID() == dataBlock:getID()) and im.TreeNodeFlags_Selected or 0)
                      end
                    end
                    im.TreeNodeEx1(dataBlock:__tostring() .. (editor.isDataBlockDirty(dataBlock) and "*" or ""), flags)
                    im.TreePop()
                    if im.IsItemClicked() then
                      editor.selectObjectById(dataBlock:getID())
                    end
                  end
                  im.TreePop()
                end
              end
            end
          im.EndChild()
          im.EndTabItem()
        end
        if im.BeginTabItem("New") then
          im.BeginChild1("New_Child", im.ImVec2(0, 0), false)
            for className, _ in pairs(dataBlockClasses) do
              im.TreeNodeEx1(className, bit.bor(im.TreeNodeFlags_Leaf))
              im.TreePop()
              if im.IsItemClicked() then
                editor.showWindow(createDataBlockWindowName)
                newDataBlockClass = className
              end
            end
          im.EndChild()
          im.EndTabItem()
        end
        im.EndTabBar()
        if inExistingTab then
          im.SameLine()
          im.Dummy(im.ImVec2(im.GetContentRegionAvailWidth() - 60 * im.uiscale[0], 1))
          im.SameLine()
          if editor.uiIconImageButton(editor.icons.save, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0]), nil, nil, nil) then
            if editor.selection.object and editor.selection.object[1] then
              if isDataBlock(editor.selection.object[1]) then
                editor.saveDataBlockToFile(scenetree.findObjectById(editor.selection.object[1]))
              end
            end
          end
          im.SameLine()
          if editor.uiIconImageButton(editor.icons.delete, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0]), nil, nil, nil) then
            if editor.selection.object and editor.selection.object[1] then
              if isDataBlock(editor.selection.object[1]) then
                editor.history:commitAction("DeleteDataBlock",
                              {id = editor.selection.object[1]}, deleteDataBlockActionUndo, deleteDataBlockActionRedo)
                confirmationWindowOpen = true
              end
            end
          end
        end
      end
    end
    editor.endWindow()

    --TODO: convert to modal popup
    if confirmationWindowOpen then
      im.SetNextWindowPos(im.ImVec2(windowPos.x + 50, windowPos.y + 50), im.Cond_Appearing)
      if im.Begin("DataBlock Deleted", nil , 0) then
        im.Text("The DataBlock has been removed from its file and upon restart will cease to exist" )
        if im.Button("OK") then
          confirmationWindowOpen = false
        end
      end
      im.End()
    end

    if editor.beginWindow(createDataBlockWindowName, "Create new DataBlock") then
      im.Text("Choose a name for the new DataBlock")
      im.InputText("##dataBlockName", newDataBlockName)
      im.Text("Copy values from")
      if im.BeginCombo("##dataBlock", dataBlockToCopyName) then
        for _, dataBlock in ipairs(dataBlockClasses[newDataBlockClass]) do
          if im.Selectable1(dataBlock:__tostring()) then
            dataBlockToCopyID = dataBlock:getID()
            dataBlockToCopyName = dataBlock:__tostring()
          end
        end
        im.EndCombo()
      end
      if im.Button("Create") then
        editor.hideWindow(createDataBlockWindowName)
        editor.history:commitAction("CreateDataBlock",
                {name = ffi.string(newDataBlockName), className = newDataBlockClass, copyID = dataBlockToCopyID}, createDataBlockActionUndo, createDataBlockActionRedo)
        dataBlockToCopyID = nil
        dataBlockToCopyName = ""
        newDataBlockName = im.ArrayChar(128)
      end
    end
    editor.endWindow()
  end
end

local function onEditorInspectorFieldChanged(selectedIds, fieldName, fieldValue, arrayIndex)
  local selectedID = selectedIds[1]
  if isDataBlock(selectedID) then
    editor.setDataBlockDirty(scenetree.findObjectById(selectedID))
  end
end

M.onEditorInspectorFieldChanged = onEditorInspectorFieldChanged
M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized
M.onExtensionLoaded = onExtensionLoaded

return M