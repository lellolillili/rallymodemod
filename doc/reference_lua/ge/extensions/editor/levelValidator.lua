-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_levelValidator'
local im = ui_imgui
local toolWindowName = "levelValidator"
local columnsSetCounter = 0
local selected
local logColors = {I = im.ImVec4(0,1,0,1), W = im.ImVec4(1,1,0,1), E = im.ImVec4(1,0,0,1), D = im.ImVec4(1,1,1,1)}
local logLevelFilters = {E = true, W = true, I = true, D = true}

local currentColumnSizes = {}
local wantedColumnSizes

local sceneObjectNodes = {}
local forestItemNodes = {}
local unplantedObjects = {}
local terrainSize
local terrainMinExtents
local terrainMaxExtents

local forestData
local objectLogs = {}
local numberOfIssues = 0
local checkFinished
local levelLogs
local filteredLogs

local removedForestItems = {}
local logsToRemove = {}

local sortingFunctions = {}

function sortingFunctions.LogLevel(a,b)
  local logLevelA = a.logLevel or ""
  local logLevelB = b.logLevel or ""
  return logLevelA < logLevelB
end

function sortingFunctions.Code(a,b)
  local uniqueErrorCodeA = a.uniqueErrorCode or 0
  local uniqueErrorCodeB = b.uniqueErrorCode or 0
  return uniqueErrorCodeA < uniqueErrorCodeB
end

function sortingFunctions.Description(a,b)
  local messageA = a.message or ""
  local messageB = b.message or ""
  return messageA < messageB
end

function sortingFunctions.Origin(a,b)
  local originA = a.origin or ""
  local originB = b.origin or ""
  return originA < originB
end

function sortingFunctions.ObjectName(a,b)
  local nameA = ""
  local nameB = ""
  if a.object and a.object:getName() then nameA = a.object:getName() end
  if b.object and b.object:getName() then nameB = b.object:getName() end
  return nameA < nameB
end

function sortingFunctions.File(a,b)
  local filenameA = a.filename or ""
  local filenameB = b.filename or ""
  return filenameA < filenameB
end

function sortingFunctions.Line(a,b)
  local lineNumberA = a.lineNumber or 0
  local lineNumberB = b.lineNumber or 0
  return lineNumberA < lineNumberB
end

local sortingParam
local sortBackwards = false

local function reverse(list)
  local i, j = 1, #list
  while i < j do
    list[i], list[j] = list[j], list[i]
    i = i + 1
    j = j - 1
  end
end

local function onActivate()
  log('I', logTag, "onActivate")
end

local function tableFilter(t, filters)
  local result = {}
  for _, value in ipairs(t) do
    local filterPassed = false
    for _, filter in ipairs(filters) do
      if filter(value) then
        filterPassed = true
        break
      end
    end
    if filterPassed then table.insert(result, value) end
  end
  return result
end

local function filterLogLevel(level)
  return function(logItem)
    return logItem.logLevel == level
  end
end

-- Delete SimObject
local function deleteObjectUndo(actionData)
  SimObject.setForcedId(actionData.objectId)
  Sim.deserializeObjectsFromText(actionData.serializedData, true)
  table.insert(levelLogs, actionData.logItem)
end

local function deleteObjectRedo(actionData)
  local obj = Sim.findObjectById(actionData.objectId)
  if obj then
    actionData.serializedData = "[" .. obj:serialize(false, -1) .. "]"
    obj:deleteObject()
    logsToRemove[actionData.logIndex] = true
  end
end

local function deleteForestItemRedo(actionData)
  editor.removeForestItem(forestData, actionData.forestItem)
  logsToRemove[actionData.logIndex] = true
  editor_forestEditor.selectForestItems()
end

local function deleteForestItemUndo(actionData)
  editor.addForestItem(forestData, actionData.forestItem)
  table.insert(levelLogs, actionData.logItem)
end

local function isBoxTooBig(box)
  local extents = box:getExtents()
  return (extents.x >= terrainSize) or (extents.y >= terrainSize)
end

local function getBBMinDiff(bb)
  local bbMax = bb.maxExtents.z
  local bbMin = bb.minExtents.z
  local minDiff = math.huge
  local terrainHeights = {}
  table.insert(terrainHeights, core_terrain.getTerrainHeight(bb:getCenter()) or 0)
  table.insert(terrainHeights, core_terrain.getTerrainHeight(bb.minExtents) or 0)
  table.insert(terrainHeights, core_terrain.getTerrainHeight(bb.maxExtents) or 0)
  table.insert(terrainHeights, core_terrain.getTerrainHeight(vec3(bb.minExtents.x, bb.maxExtents.y, 0)) or 0)
  table.insert(terrainHeights, core_terrain.getTerrainHeight(vec3(bb.maxExtents.x, bb.minExtents.y, 0)) or 0)
  local firstSignPositive = (bbMax - terrainHeights[1]) > 0
  for _, terrainHeight in ipairs(terrainHeights) do
    local diffTop = bbMax - terrainHeight
    local diffBottom = bbMin - terrainHeight
    if ((diffTop > 0) ~= firstSignPositive) or ((diffBottom > 0) ~= firstSignPositive) then
      return 0
    end
    local localMinDiff = math.min(math.abs(diffTop), math.abs(diffBottom))
    minDiff = math.min(localMinDiff, minDiff)
  end
  return minDiff
end

local function buildNodes(job)
  local objects = findAllObjects(SOTStaticShape)

  for _, obj in ipairs(objects) do
    if obj:isSubClassOf("TSStatic") then
      local bb = obj:getWorldBox()
      if not isBoxTooBig(bb) then
        local minDiff = getBBMinDiff(bb)
        if (minDiff < 1) then
          sceneObjectNodes[obj:getId()] = {obj = obj, edges = {}, planted = true}
        else
          sceneObjectNodes[obj:getId()] = {obj = obj, edges = {}, planted = false}
          table.insert(unplantedObjects, obj)
        end
      end
    end
    job.yield()
  end

  -- get the Forest object
  if core_forest.getForestObject() then
    forestData = core_forest.getForestObject():getData()
    for i, forestItem in ipairs(forestData:getItems()) do
      if forestItem:getPosition().x < terrainMaxExtents.x and forestItem:getPosition().x > terrainMinExtents.x
         and forestItem:getPosition().y < terrainMaxExtents.y and forestItem:getPosition().y > terrainMinExtents.y then
        local bb = forestItem:getWorldBox()
        local minDiff = getBBMinDiff(bb)
        if (minDiff < 1) then
          forestItemNodes[forestItem:getKey()] = {obj = forestItem, edges = {}, planted = true}
        else
          forestItemNodes[forestItem:getKey()] = {obj = forestItem, edges = {}, planted = false}
          table.insert(unplantedObjects, forestItem)
        end
      end
      job.yield()
    end
  else
    log('I', '', "There's no Forest object.")
  end
end

local function setNodesPlanted(node)
  for i, otherNode in ipairs(node.edges) do
    if not otherNode.planted then
      otherNode.planted = true
      setNodesPlanted(otherNode)
    end
  end
end

local function getAdjustedBoundingBox(originalBB)
  local bb = Box3F()
  bb:setExtents(originalBB:getExtents())
  bb:scale(1.1) -- Make the bb a little bigger for a bit of leeway
  bb:setCenter(originalBB:getCenter())
  return bb
end

local function sortData(data)
  if type(data) ~= "table" then
    return data
  end
  local sortedFields = {}
  for field, _ in pairs(data) do
    table.insert(sortedFields, field)
  end
  table.sort(sortedFields)
  local sortedData = {}
  for i, field in ipairs(sortedFields) do
    table.insert(sortedData, data[field])
    if type(sortedData[i]) == "table" then
      if sortedData[i][1] then
        for i2, value in ipairs(sortedData[i]) do
          sortedData[i][i2] = sortData(value)
        end
      else
        sortedData[i] = sortData(sortedData[i])
      end
    end
  end
  return sortedData
end

local function prepareData(data)
  if data.position then
    if data.position[1] then
      data.position[1] = round(100*data.position[1])/100
      data.position[2] = round(100*data.position[2])/100
      data.position[3] = round(100*data.position[3])/100
    else
      data.position = nil
    end
  end
  if data.rotationMatrix then
    if data.rotationMatrix[1] then
      data.rotationMatrix[1] = round(100*data.rotationMatrix[1])/100
      data.rotationMatrix[2] = round(100*data.rotationMatrix[2])/100
      data.rotationMatrix[3] = round(100*data.rotationMatrix[3])/100
      data.rotationMatrix[4] = round(100*data.rotationMatrix[4])/100
      data.rotationMatrix[5] = round(100*data.rotationMatrix[5])/100
      data.rotationMatrix[6] = round(100*data.rotationMatrix[6])/100
      data.rotationMatrix[7] = round(100*data.rotationMatrix[7])/100
      data.rotationMatrix[8] = round(100*data.rotationMatrix[8])/100
      data.rotationMatrix[9] = round(100*data.rotationMatrix[9])/100
    else
      data.rotationMatrix = nil
    end
  end
  data.name = nil
  data.internalName = nil
  data.persistentId = nil
  data.__parent = nil
  return sortData(data)
end

local function testObjects(job)
  -- Create graph
  -- Loop tsstatics and forest items
  for i, unplantedObj in ipairs(unplantedObjects) do
    local unplantedNode = unplantedObj.getKey and forestItemNodes[unplantedObj:getKey()] or sceneObjectNodes[unplantedObj:getID()]
    local bb = getAdjustedBoundingBox(unplantedObj:getWorldBox())

    local objects = findObjectList(bb, SOTStaticShape, 0)
    for _, otherObj in ipairs(objects) do
      local otherNode = sceneObjectNodes[otherObj:getID()]
      if otherNode then
        table.insert(unplantedNode.edges, otherNode)
        table.insert(otherNode.edges, unplantedNode)
      end
    end
    job.yield()
    if forestData then
      local items = forestData:getItemsBox(bb)
      for _, item in ipairs(items) do
        local otherNode = forestItemNodes[item:getKey()]
        if otherNode then
          table.insert(unplantedNode.edges, otherNode)
          table.insert(otherNode.edges, unplantedNode)
        end
      end
    end
    job.yield()
  end

  -- Check which sceneObjectNodes are planted
  for i, node in pairs(sceneObjectNodes) do
    if node.planted then
      setNodesPlanted(node)
      job.yield()
    end
  end
  job.yield()

  for i, node in pairs(forestItemNodes) do
    if node.planted then
      setNodesPlanted(node)
      job.yield()
    end
  end

  for id, node in pairs(sceneObjectNodes) do
    if not node.planted then
      local object = scenetree.findObjectById(id)
      local prefab = Prefab.getPrefabByChild(object)
      if prefab then
        table.insert(objectLogs, {logLevel = "W", type = "floating", objectId = prefab:getID(), prefabChildId = id, message = "An object inside this prefab is floating: " .. prefab:getID(), onCheck = true})
      else
        table.insert(objectLogs, {logLevel = "W", type = "floating", objectId = id, message = "This object is floating: " .. id, onCheck = true})
      end
      numberOfIssues = numberOfIssues + 1
      job.yield()
    end
  end
  job.yield()
  for _, node in pairs(forestItemNodes) do
    if not node.planted then
      table.insert(objectLogs, {logLevel = "W", type = "floating", forestItem = node.obj, message = "This forest item is floating: " .. node.obj:getKey(), onCheck = true})
      numberOfIssues = numberOfIssues + 1
      job.yield()
    end
  end

  -- Loop all objects
  job.yield()
  local objectHashes = {}
  for _, name in ipairs(scenetree.getAllObjects()) do
    local object = scenetree.findObject(name)
    if object then
      local class = object:getClassName()
      if object:isSubClassOf("SceneObject") and object:getClassName() ~= "ProceduralMesh" then -- Skip procedural meshes for now as they will always produce false positives
        -- Check decal roads, mesh roads, rivers for not enough nodes
        if (class == "DecalRoad" or class == "MeshRoad" or class == "River") and object:getNodeCount() < 2 then
          table.insert(objectLogs, {logLevel = "E", type = "spline", objectId = object:getID(), message = "This " ..  object:getClassName() .. " has less than 2 nodes: " .. object:getID(), onCheck = true})
          numberOfIssues = numberOfIssues + 1
          job.yield()
        end

        -- Check for duplicate objects
        local data = object:serialize(true, -1)
        data = jsonDecode(data)
        data = prepareData(data)
        local hash = hashStringSHA256(serialize(data))

        local foundDuplicate = false
        for id2, hash2 in pairs(objectHashes) do
          if hash == hash2 then
            local prefab = Prefab.getPrefabByChild(object)
            if prefab then
              table.insert(objectLogs, {logLevel = "W", type = "duplicate", objectId = prefab:getID(), prefabChildId = object:getID(), message = "An object inside this prefab " .. prefab:getID() .. " is identical to another object. (Might be in the same prefab)", onCheck = true})
            else
              table.insert(objectLogs, {logLevel = "W", type = "duplicate", objectId = object:getID(), message = "This object " .. object:getID() .. " and this object " .. id2 .. " are identical", onCheck = true})
            end

            numberOfIssues = numberOfIssues + 1
            job.yield()
            foundDuplicate = true
            break
          end
        end
        if not foundDuplicate then
          objectHashes[object:getID()] = hash
        end
      end
    end
  end

  -- Loop forest items and check for duplicates
  if forestData then
    local mapTransformToForestItemKey = {} -- save one item per transform that wont get deleted when "deleting all duplicates"

    -- loop all forest items
    for i1, forestItem1 in ipairs(forestData:getItems()) do
      local forestItem1TransformString = forestItem1:getTransform():__tostring()
      if mapTransformToForestItemKey[forestItem1TransformString] ~= forestItem1:getKey() then
        local forestItem1ShapeFile = forestItem1:getData():getShapeFile()

        -- loop all items that are close to forestItem1
        for i2, forestItem2 in ipairs(forestData:getItemsCircle(forestItem1:getPosition(), 0.1)) do
          if forestItem1:getKey() ~= forestItem2:getKey() then

            -- if shape file, scale and transform are the same, assume the items are identical
            if forestItem1ShapeFile == forestItem2:getData():getShapeFile()
            and forestItem1:getScale() == forestItem2:getScale() then
              local forestItem2TransformString = forestItem2:getTransform():__tostring()
              if forestItem1TransformString == forestItem2TransformString then
                table.insert(objectLogs, {logLevel = "W", type = "duplicate", forestItem = forestItem1, message = "This forest item is identical to another: " .. forestItem1:getKey(), onCheck = true})
                numberOfIssues = numberOfIssues + 1
                if not mapTransformToForestItemKey[forestItem2TransformString] then
                  mapTransformToForestItemKey[forestItem2TransformString] = forestItem2:getKey()
                end
                break
              end
            end
            job.yield()
          end
        end
      end
    end
  end
end

local function checkLevel(job)
  editor.log("Finding issues...")
  numberOfIssues = 0
  sceneObjectNodes = {}
  objectLogs = {}
  unplantedObjects = {}

  local terrains = scenetree.findClassObjects("TerrainBlock")
  if terrains[1] then
    local terrain = scenetree.findObject(terrains[1])
    terrainMinExtents = terrain:getWorldBox().minExtents
    terrainMaxExtents = terrain:getWorldBox().maxExtents
    terrainSize = terrain:getWorldBlockSize() or 300
  else
    terrainMinExtents = -math.huge
    terrainMaxExtents = math.huge
    terrainSize = 300
  end

  buildNodes(job)
  testObjects(job)

  for i = #levelLogs, 1, -1 do
    if levelLogs[i].onCheck then
      table.remove(levelLogs, i)
    end
  end
  for _, log in ipairs(objectLogs) do
    table.insert(levelLogs, log)
  end
  checkFinished = 2
  editor.log("Found " .. numberOfIssues .. " issues.")
end

local function filterButton(logLevel, name)
  local buttonActive = false
  if logLevelFilters[logLevel] then
    im.PushStyleColor2(im.Col_Button, im.GetStyleColorVec4(im.Col_ButtonActive))
    buttonActive = true
  end
  if im.Button(name) then
    if logLevelFilters[logLevel] then logLevelFilters[logLevel] = nil else logLevelFilters[logLevel] = true end
  end
  if buttonActive then
    im.PopStyleColor()
  end
end

local function rowHeader(title, functionName)
  if sortingParam == functionName then
    if sortBackwards then
      title = title .. " ↑"
    else
      title = title .. " ↓"
    end
  end

  if im.Selectable1(title, false, 0) then
    if functionName == sortingParam then
      sortBackwards = not sortBackwards
    else
      sortingParam = functionName
      sortBackwards = false
    end
  end
end

local function onEditorGui()
  if editor.beginWindow(toolWindowName, "Level Validator") then
    if im.Button("Find issues with the level (May take a few seconds)") then
      extensions.core_jobsystem.create(checkLevel, 0.04)
      checkFinished = 1
    end

    if checkFinished then
      im.SameLine()

      if checkFinished == 1 then
        im.TextColored(im.ImVec4(1, 1, 0, 1.0), "Searching for issues...")
      elseif checkFinished == 2 then
        im.TextColored(im.ImVec4(0, 1, 0, 1.0), "Check finished. Found " .. numberOfIssues .. " issues.")
        im.SameLine()
        if im.Button("Delete all duplicates") then
          editor.history:beginTransaction("DeleteDuplicates")
          for i, logItem in ipairs(levelLogs) do
            if logItem.onCheck and logItem.type == "duplicate" and not logItem.prefabChildId then
              if logItem.forestItem then
                editor.history:commitAction("DeleteForestItem", {forestItem = logItem.forestItem, logItem = logItem, logIndex = i}, deleteForestItemUndo, deleteForestItemRedo)
                editor.forestDirty = true
              elseif logItem.objectId then
                editor.history:commitAction("DeleteObject", {objectId = logItem.objectId, logItem = logItem, logIndex = i}, deleteObjectUndo, deleteObjectRedo)
              end
            end
          end
          editor.history:endTransaction()
          editor.setDirty()
        end
      end
    end

    filterButton('E', "Errors")
    im.SameLine()
    filterButton('W', "Warnings")
    im.SameLine()
    filterButton('I', "Info")
    im.SameLine()
    filterButton('D', "Debug")

    local filterFunctions = {}
    for logLevel, _ in pairs(logLevelFilters) do
      table.insert(filterFunctions, filterLogLevel(logLevel))
    end

    if not levelLogs then levelLogs = getLevelLogs() end
    filteredLogs = tableFilter(levelLogs, filterFunctions)
    if sortingParam then
      table.sort(filteredLogs, sortingFunctions[sortingParam])
      if sortBackwards then
        reverse(filteredLogs)
      end
    end

    im.Columns(7)

    local columnSizes = editor.getPreference("levelValidator.general.columnSizes")

    if im.IsMouseDragging(0) then
      for i = 1, 6 do
        columnSizes[i] = im.GetColumnWidth(i - 1)
      end
      editor.setPreference("levelValidator.general.columnSizes", columnSizes)
    end

    if columnsSetCounter == 1 then
      for i = 1, 6 do
        im.SetColumnWidth(i - 1, columnSizes[i])
      end
    end
    if columnsSetCounter < 2 then
      columnsSetCounter = columnsSetCounter + 1
    end

    -- Categories
    rowHeader(" ", "LogLevel")
    im.NextColumn()
    rowHeader("Code", "Code")
    im.NextColumn()
    rowHeader("Description", "Description")
    im.NextColumn()
    rowHeader("Origin", "Origin")
    im.NextColumn()
    rowHeader("Object Name", "ObjectName")
    im.NextColumn()
    rowHeader("File", "File")
    im.NextColumn()
    rowHeader("Line", "Line")
    im.NextColumn()
    im.Separator()
    im.Columns(1)

    im.BeginChild1("logsTable", im.ImVec2(0,0), false)
    im.Columns(7, nil, false)
    for i = 1, 6 do
      im.SetColumnWidth(i - 1, columnSizes[i])
    end

    for i, logItem in ipairs(filteredLogs) do
      local object
      if logItem.objectId then object = scenetree.findObjectById(logItem.objectId) end
      local logColor = logColors[(logItem.logLevel or "")] or im.ImVec4(1,1,1,1)
      im.PushStyleColor2(im.Col_Text, logColor)
      local textSize = im.CalcTextSize(logItem.message:sub(1, 1000) or "", nil, nil, im.GetColumnWidth(2) - im.GetStyle().ItemSpacing.x)
      if im.Selectable1(" " .. (logItem.logLevel or "") .. "##" .. i, selected == i, im.SelectableFlags_SpanAllColumns, im.ImVec2(0, textSize.y + 5)) then
      end
      im.SetItemAllowOverlap()
      im.PopStyleColor()
      if editor.IsItemClicked() then
        selected = i
        if object then
          editor.selectObjectById(logItem.objectId)
        end
      end
      if editor.IsItemDoubleClicked() then
        if object then
          if logItem.prefabChildId then
            editor.selectObjectById(logItem.prefabChildId)
          end
          editor.fitViewToSelection()
          if logItem.prefabChildId then
            editor.selectObjectById(logItem.objectId)
          end
        elseif logItem.forestItem then
          if editor_forestEditor and editor.editMode.displayName == editor.editModes.forestToolsEditMode.displayName then
            editor_forestEditor.selectToolByName("select")
            editor_forestEditor.selectForestItems({logItem.forestItem})
            editor.fitViewToSelection()
          else
            local pos = logItem.forestItem:getPosition()
            editor.fitViewToSelection(pos)
          end
        end
      end
      im.NextColumn()
      im.Text("" .. (logItem.uniqueErrorCode or ""))
      im.NextColumn()

      im.PushTextWrapPos(im.GetCursorPosX() + im.GetColumnWidth() - im.GetStyle().ItemSpacing.x)
      im.TextWrapped(logItem.message:sub(1, 1000) or "") -- TODO
      im.PopTextWrapPos()

      im.SameLine()
      if (logItem.forestItem or object) and logItem.onCheck and not logItem.prefabChildId then
        if im.Button("Delete Object##" .. i) then
        end
        if editor.IsItemClicked() then -- Need to use isItemClicked because the im.Button doesnt always work on top of the im.Selectable
          if logItem.forestItem then
            editor.history:commitAction("DeleteForestItem", {forestItem = logItem.forestItem, logItem = logItem, logIndex = i}, deleteForestItemUndo, deleteForestItemRedo)
            editor.forestDirty = true
            editor.setDirty()
          elseif logItem.objectId then
            editor.history:commitAction("DeleteObject", {objectId = logItem.objectId, logItem = logItem, logIndex = i}, deleteObjectUndo, deleteObjectRedo)
            editor.setDirty()
          end
        end
      end

      im.NextColumn()
      im.Text(logItem.origin or "")
      im.NextColumn()
      im.Text(object and (object:getName() or "No Name") or "")
      im.NextColumn()
      im.Text(logItem.filename or "")
      im.NextColumn()
      im.Text("" .. (logItem.lineNumber or ""))
      im.NextColumn()
    end
    if not tableIsEmpty(logsToRemove) then
      for i = tableSize(levelLogs), 1, -1 do
        if logsToRemove[i] then
          table.remove(levelLogs, i)
        end
      end
      logsToRemove = {}
    end

    im.EndChild()
    im.Columns(1)
  end
  editor.endWindow()
end

local function onWindowMenuItem()
  editor.showWindow(toolWindowName)
end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(200, 400))
  editor.addWindowMenuItem("Level Validator", onWindowMenuItem)
end

local function onExtensionLoaded()
  log('D', logTag, "initialized")
end

local function onEditorRegisterPreferences(prefsRegistry)
  prefsRegistry:registerCategory("levelValidator")
  prefsRegistry:registerSubCategory("levelValidator", "general", nil,
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    -- hidden
    {columnSizes = {"table", {29, 53, 391, 89, 97, 81}, "", nil, nil, nil, true}},
  })
end

local function onClientStartMission()
  terrainSize = nil
  terrainMinExtents = nil
  terrainMaxExtents = nil
end

M.onClientStartMission = onClientStartMission
M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized
M.onExtensionLoaded = onExtensionLoaded
M.onEditorRegisterPreferences = onEditorRegisterPreferences

return M