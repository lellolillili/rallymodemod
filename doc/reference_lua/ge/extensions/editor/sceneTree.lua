-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_scene_tree'
local imgui = ui_imgui
local sceneTreeWindowNamePrefix = "scenetree"
local nameFilterText = ""
local editEnded = imgui.BoolPtr(false)
local comboIndex = imgui.IntPtr(0)
local inputTextValue = imgui.ArrayChar(500)
local iconSize = imgui.ImVec2(20, 20)
local nodeIconColor = imgui.ImColorByRGB(255,255,0,255)
local nodeTextColor = imgui.ImColorByRGB(255,255,255,255)
local selectedNodeIconColor = imgui.ImColorByRGB(0,255,255,255)
local selectedNodeTextColor = imgui.ImColorByRGB(0,255,255,255)
local selectedObjectNodeIconColor = imgui.ImColorByRGB(0,255,255,255)
local objectNodeIconColor = imgui.ImColorByRGB(180, 120, 0, 255)
local transparentColor = imgui.ImVec4(0,0,0,0)
local defaultObjectNodeIcon = nil -- inited in onEditorInitialized
local objectClassIcons = nil -- inited in onEditorInitialized
local dragDropBGColor = imgui.GetColorU322(imgui.ImVec4(1, 1, 1, 0.25), 1)
local guiInstancer = require("editor/api/guiInstancer")()
local objectHistoryActions = require("editor/api/objectHistoryActions")()
local socket = require("socket")
local editingNodeName = nil
local deleteNodes = false

local SelectMode_Range = 0

local MaxGroupNestingLevel = 30

local hasDragDropPayload = false
local clickedOnNode

local nodeIdToOpen = nil
local onClickSelected = false
local nodeWasDblClicked

local mouseDragRange
local dragSelectionList = {}

-- vars for virtual scrolling
local entrySize

local searchTypesComboItems

local SearchMode_Name = 0
local SearchMode_ID = 1
local SearchMode_Class = 2
local SearchMode_All = 3
local searchNodeMode = SearchMode_All
local searchMatches = { bit.lshift(1, 0), bit.lshift(1, 1), bit.lshift(1, 2), bit.lshift(1, 3)} -- displayname, name, id, class

local searchRange = -1
local searchRangeTimer = hptimer()
local searchRangeTime = -1

local cameraPositionCache
local showGroups = true -- shows/hides groups. Used for search results
local searchResults = {}
local searchResultsMode = false
local prefabSaveFolder = "/"
local currentSceneTreeInstanceIndex = nil

-- Registered extended scene tree object menu items
local extendedSceneTreeObjectMenuItems = {}

local function getRootGroup()
  if editor.getPreference("ui.general.showCompleteSceneTree") then return Sim.getRootGroup() end
  return scenetree.MissionGroup
end

local function getNodeName(object)
  if not object or not object["getName"] or not object["getClassName"] then return "<unsupported>" end
  if object:getName() == "" then
    return object:getClassName()
  else
    return object:getName()
  end
end

local function getNameOrInternalName(object)
  if not object or not object["getName"] or not object["getClassName"] then return "<unsupported>" end
  if (object:getName() == "" or object:getName() == nil) and object["getInternalName"] and object:getInternalName() ~= "" and object:getInternalName() ~= nil then
    return object:getInternalName()
  else
    return getNodeName(object)
  end
end

local function getNodeDisplayName(object)
  if not object or not object["getName"] or not object["getClassName"] then return "<unsupported>" end
  local displayName
  local className = object:getClassName()
  if className == 'TSStatic' then
    -- TSStatics will trail with the shapeName
    local shapeName = object.shapeName
    if shapeName then
      local _, shapeNameRes, _ = path.split(shapeName)
      displayName = shapeNameRes
    end
  elseif className == 'DecalRoad' then
    -- DecalRoads will trail with the material name
    displayName = object.material
  elseif editor.getPreference("ui.general.showInternalName") then
    return getNameOrInternalName(object)
  else
    -- otherwise, use the actual name, internal name or classname
    return getNodeName(object)
  end

  -- if we have a trailing string, the prefix will be the name
  -- we do custom checking for names and internal names here, so we only use Name or InternalName as a prefix, not the ClassName.
  if object:getName() ~= "" and object:getName() ~= nil then
    return object:getName() .. " (" .. displayName .. ")"
  elseif editor.getPreference("ui.general.showInternalName") and object["getInternalName"] and object:getInternalName() ~= "" and object:getInternalName() ~= nil then
    return object:getInternalName() .. " (" .. displayName .. ")"
  end
  return displayName
end

local function getObjectNodeIcon(className)
  local iconName = objectClassIcons[className]

  if not iconName then
    return defaultObjectNodeIcon
  else
    return editor.icons[iconName]
  end
end

local function getGroupNodeIcon(node)
  local object = scenetree.findObjectById(node.id)
  if object and object:getField("unpacked_prefab", "") == "1" then
    return editor.icons[objectClassIcons["unpacked_prefab"]]
  end
  if node.open or node.openOnSearch then
    return editor.icons.folder_open
  end
  return editor.icons.folder
end

local function getSceneTreeSelectedGroup(instance)
  if instance and #instance.selectedNodes ~= 0 then
    if #instance.selectedNodes == 1 then
      if instance.selectedNodes[1].isGroup then return scenetree.findObjectById(instance.selectedNodes[1].id) end
    end
    if instance.selectedNodes[1].parent then return scenetree.findObjectById(instance.selectedNodes[1].parent.id) end
  end
  return scenetree.MissionGroup
end

local function getNodeSize(instance, node)
  local size = 0
  if node then
    if not instance.rootNodeSizeCache then
      node.listIndex = nil
    end
    if not node.hidden then
      size = 1
      if not instance.rootNodeSizeCache then
        node.listIndex = instance.listIndex
        instance.listIndex = instance.listIndex + 1
      end
      if node.isGroup and (not showGroups or node.open or node.openOnSearch) and node.children and #node.children > 0 then
        for _, child in ipairs(node.children) do
          size = size + getNodeSize(instance, child)
        end
      end
    end
  end
  return size
end

local function findNodeByObject(instance, parentNode, object)
  if not object then return end
  if not parentNode then parentNode = instance.rootNode end
  if parentNode.id == object:getID() then return parentNode end
  if parentNode.children then
    for _, node in ipairs(parentNode.children) do
      if node.id == object:getID() then return node end
      local child = findNodeByObject(instance, node, object)
      if child then return child end
    end
  end
end

local function getRootNodeSize(instance)
  if not instance.rootNodeSizeCache then
    instance.listIndex = 1
    instance.rootNodeSizeCache = getNodeSize(instance, instance.rootNode)
  end
  return instance.rootNodeSizeCache
end

local function cacheGroupNode(instance, node, addObjectIds, nestingLevel)
  if not node then node = instance.rootNode end
  if not node then return end
  if not node.size then node.size = 0 end
  if nestingLevel > MaxGroupNestingLevel then
    editor.logError("Scene tree depth too high, probably cyclic group reference")
  end
  if node.isGroup and addObjectIds then
    for _, objId in ipairs(addObjectIds) do
      local obj = scenetree.findObjectById(objId)
      if obj and obj.getGroup and obj:getGroup() and obj:getGroup():getID() == node.id then
        local object = obj
        local className = object:getClassName() or ""
        local isGroup = object:isSubClassOf("SimSet") or object:isSubClassOf("SimGroup")
        if not object["getID"] then editor.logError(className .. ": not even the SimObject has getID") end
        local id = object:getID()
        local child = {
          id = id,
          order = order,--TODO we need to save order in undo, so we know where to place the node
          name = getNodeName(object),
          displayName = getNodeDisplayName(object),
          className = className,
          icon = getObjectNodeIcon(className, object),
          open = false,
          selected = false,
          isGroup = isGroup,
          parent = node }
        table.insert(node.children, child)
        -- also cache this node if its a group
        -- this happens if the newly added group missed the addition of its children objects (in the case of prefab packing for example)
        if child.isGroup then
          cacheGroupNode(instance, child, nil, nestingLevel + 1)
        end
      end
    end
  end

  -- if this is a group and there are no children nodes, fill the array
  if not node.children and node.isGroup then
    node.children = {}
    local object = scenetree.findObjectById(node.id)
    if object then
      local count = object:size() - 1
      for i = 0, count do
        local object = object:at(i)
        local className = object:getClassName() or ""
        local isGroup = object:isSubClassOf("SimSet") or object:isSubClassOf("SimGroup")
        if not object["getID"] then editor.logError(className .. ": not even the SimObject doesnt have getID") end
        local id = object:getID()
        local child = {
          id = id,
          order = i,
          name = getNodeName(object),
          displayName = getNodeDisplayName(object),
          className = className,
          icon = getObjectNodeIcon(className, object),
          open = false,
          selected = false,
          isGroup = isGroup,
          parent = node }
        table.insert(node.children, child)
        if child.isGroup then cacheGroupNode(instance, child, addObjectIds, nestingLevel + 1) end
      end
    end
  else
    if node.children then
      for _, child in ipairs(node.children) do
        cacheGroupNode(instance, child, addObjectIds, nestingLevel + 1)
      end
    end
  end
  if node.children == nil then
    node.size = 1
  end
  if node.parent then
    node.parent.size = node.parent.size + node.size
  end
end

local function removeNodeByObjectId(node, objId)
  if node.id == objId then
    if node.parent then
      local index = arrayFindValueIndex(node.parent.children, node)
      table.remove(node.parent.children, index)
      return
    end
  end

  if node.children then
    for _, child in ipairs(node.children) do
      removeNodeByObjectId(child, objId)
    end
  end
end

local function removeNodesByObjectIds(instance, objectIds)
  if not instance.rootNode then return end
  if not objectIds or tableIsEmpty(objectIds) then return end
  for _, id in ipairs(objectIds) do
    removeNodeByObjectId(instance.rootNode, id)
  end
end

local function deleteSelectedNodes(instance)
  if not instance.selectedNodes or tableIsEmpty(instance.selectedNodes) then return end
  for _, node in ipairs(instance.selectedNodes) do
    if node.parent then
      for i, _ in pairs(node.parent.children) do
        if node.parent.children[i] == node then
          table.remove(node.parent.children, i)
          node = nil
          break
        end
      end
    end
  end
  instance.selectedNodes = {}
end

local function applyFilterRecursive(instance, node)
  if not node then node = rootNode end
  if not node then return end

  node.hidden = false
  node.openOnSearch = nil
  node.filterResult = 0
  local passed = false

  if nameFilterText ~= "" then
    -- searching
    if searchNodeMode == SearchMode_Name then
      if imgui.ImGuiTextFilter_PassFilter(instance.nameFilter, node.displayName) then
        node.filterResult = searchMatches[1]
      end
      if imgui.ImGuiTextFilter_PassFilter(instance.nameFilter, node.name) then
        node.filterResult = node.filterResult + searchMatches[2]
      end
      passed = node.filterResult ~= 0
    elseif searchNodeMode == SearchMode_ID then
      if imgui.ImGuiTextFilter_PassFilter(instance.nameFilter, tostring(node.id)) then
        node.filterResult = searchMatches[3]
      end
      passed = node.filterResult ~= 0
    elseif searchNodeMode == SearchMode_Class then
      if imgui.ImGuiTextFilter_PassFilter(instance.nameFilter, node.className) then
        node.filterResult = searchMatches[4]
      end
      passed = node.filterResult ~= 0
    elseif searchNodeMode == SearchMode_All then
      if imgui.ImGuiTextFilter_PassFilter(instance.nameFilter, node.displayName) then
        node.filterResult = searchMatches[1]
      end
      if imgui.ImGuiTextFilter_PassFilter(instance.nameFilter, node.name) then
        node.filterResult = node.filterResult + searchMatches[2]
      end
      if imgui.ImGuiTextFilter_PassFilter(instance.nameFilter, tostring(node.id)) then
        node.filterResult = node.filterResult + searchMatches[3]
      end
      if imgui.ImGuiTextFilter_PassFilter(instance.nameFilter, node.className) then
        node.filterResult = node.filterResult + searchMatches[4]
      end
      passed = node.filterResult ~= 0
    end
  else
    -- not searching
    passed = true
  end

  if passed and searchRange > 0 then
    local object = scenetree.findObjectById(node.id)
    node.cameraDistance = math.huge
    if object and type(object.getPosition) == 'function' then
      local nodePos = object:getPosition()
      node.cameraDistance = math.abs((cameraPositionCache - nodePos):length())
      passed = node.cameraDistance < searchRange
    else
      passed = false
    end
  else
    node.cameraDistance = nil
  end

  if passed then
    table.insert(searchResults, node)
  end

  if passed and nameFilterText ~= "" then
    if node.isGroup then
      node.hidden = false
      if node.parent then node.parent.openOnSearch = true end
    elseif node.parent then
      node.hidden = false
      node.parent.hidden = false
      node.parent.openOnSearch = true
    end
  end
  if not passed then
    node.hidden = true
  end

  if node.children and tableSize(node.children) then
    for _, child in ipairs(node.children) do
      applyFilterRecursive(instance, child)
    end
  end

  if node.openOnSearch then
    if node.parent then
      node.parent.hidden = false
      node.parent.openOnSearch = true
    end
  end
end

local function applyFilter(instance, node)
  searchResults = {}
  cameraPositionCache = getCameraPosition()
  nameFilterText = ffi.string(imgui.TextFilter_GetInputBuf(instance.nameFilter))
  applyFilterRecursive(instance, node)
  instance.rootNodeSizeCache = nil

  -- now sort the results
  if searchRange > 0 then
    table.sort(searchResults, function(n1, n2)
      return n1.cameraDistance < n2.cameraDistance
    end)
  end

  searchResultsMode = searchRange > 0 or nameFilterText ~= ''
end

local function refreshNodeCache(instance)
  applyFilter(instance, instance.rootNode)
end

local function selectNode(instance, node, selectMode)
  if not node then return end
  if not selectMode then selectMode = editor.SelectMode_New end
  if selectMode == SelectMode_Range then
    if #instance.selectedNodes > 0 then
      instance.selectionRange = {}
      for i = math.min(instance.lastSelectedIndex, node.listIndex), math.max(instance.lastSelectedIndex, node.listIndex) do
        instance.selectionRange[i] = true
      end
    else
      instance.lastSelectedIndex = node.listIndex
      selectMode = editor.SelectMode_New
    end
    instance.currentListIndex = node.listIndex
  elseif selectMode == editor.SelectMode_New then
    instance.lastSelectedIndex = node.listIndex
    instance.currentListIndex = node.listIndex
  end

  editor.selectObjectById(node.id, selectMode)
  editor.updateObjectSelectionAxisGizmo()

  if node.name ~= "MissionGroup" then
    local current = node
    while current.parent and current.parent.name ~= "MissionGroup" do
      current.parent.open = true
      current = current.parent
    end
  end

  --TODO: jump to new selection in the other unlocked scene tree window instances
end

local function createSimGroupActionUndo(actionData)
  local sceneTreeInstance = guiInstancer.instances[currentSceneTreeInstanceIndex]
  removeNodeByObjectId(sceneTreeInstance.rootNode, actionData.objectID)
  sceneTreeInstance.selectedNodes = {}
  local obj = scenetree.findObjectById(actionData.objectID)
  if obj then obj:deleteObject() end
end

local function createSimGroupActionRedo(actionData)
  local sceneTreeInstance = guiInstancer.instances[currentSceneTreeInstanceIndex]
  if actionData.objectID then
    SimObject.setForcedId(actionData.objectID)
  end
  local grp = worldEditorCppApi.createObject("SimGroup")
  grp:registerObject("")

  if actionData.addToRoot or not actionData.groupParentID then
    scenetree.MissionGroup:addObject(grp)
  else
    local parentObject = scenetree.findObjectById(actionData.groupParentID)
    if parentObject then
      parentObject:addObject(grp)
    end
  end

  local grpNode = findNodeByObject(sceneTreeInstance, nil, grp)
  selectNode(sceneTreeInstance, grpNode)
  sceneTreeInstance.scrollToNode = true
  actionData.objectID = grpNode.id
  actionData.grp = grp
end

local function getChangeOrderActionData(instance, newGroup)
  local objects = {}
  local placeholderObjects = {}
  local oldGroups = {}
  for _, node in ipairs(instance.selectedNodes) do
    local object = scenetree.findObjectById(node.id)
    if object then
      table.insert(objects, node.id)
      local nextObject = object:getGroup():getObject(object:getGroup():getObjectIndex(object) + 1)
      if nextObject then
        table.insert(placeholderObjects, nextObject:getID())
      end
      table.insert(oldGroups, node.parent.id)
    end
  end
  return {objects = objects, placeholderObjects = placeholderObjects, oldGroups = oldGroups, newGroup = newGroup}
end

local function getNodeOpenStatus(node, res)
  if not res then res = {} end
  res[node.id] = node.open
  if node.children then
    for _, child in ipairs(node.children) do
      getNodeOpenStatus(child, res)
    end
  end
  return res
end

local function applyNodeOpenStatus(node, openStatus)
  node.open = openStatus[node.id]
  if node.children then
    for _, child in ipairs(node.children) do
      applyNodeOpenStatus(child, openStatus)
    end
  end
end

local function recacheAllNodes(incomingObjectIds, keepOpenStatus)
  local rootGrp = getRootGroup()
  for index, instance in pairs(guiInstancer.instances) do
    local openStatus
    if keepOpenStatus and instance.rootNode then
      openStatus = getNodeOpenStatus(instance.rootNode)
    end
    instance.rootNode = nil
    if rootGrp then
      instance.rootNode = {
        id = rootGrp:getID(),
        object = rootGrp,
        className = rootGrp:getClassName(),
        upcastedObject = Sim.upcast(rootGrp),
        open = true,
        selected = false,
        isGroup = true,
        parent = nil,
        name = getNodeName(rootGrp),
        displayName = getNodeDisplayName(object),
        children = nil}
    end

    cacheGroupNode(instance, instance.rootNode, incomingObjectIds, 0)
    instance.rootNodeSizeCache = nil
    if openStatus and instance.rootNode then
      applyNodeOpenStatus(instance.rootNode, openStatus)
    end
  end
end

local function openNode(node)
  if node.parent then
    node.parent.open = true
    for index, instance in pairs(guiInstancer.instances) do
      instance.rootNodeSizeCache = nil
    end
    openNode(node.parent)
  end
end

local function updateNodeSelection(instance, node)
  if not editor.selection or not editor.selection.object or not node then return end
  if tableContains(editor.selection.object, node.id) then
    table.insert(instance.selectedNodes, node)
    node.selected = true
    openNode(node)
    if not instance.noScrollToSelection then
      instance.scrollToNode = editor.selection.object[1]
    end
  end
  if node.children then
    for _, child in pairs(node.children) do
      updateNodeSelection(instance, child)
    end
  end
end

local function changeNodeName(node, name)
  local searchedObj = scenetree.findObject(name)
  -- if its a different object, but has same name with out new name, then error
  if searchedObj and searchedObj:getID() ~= node.id then
    local msg = "'" .. name .. "' already exists in the scene, please choose another name"
    editor.logWarn(msg)
    editor.showNotification(msg)
    editor.setStatusBar(msg, function() if imgui.Button("Close##duplicate") then editor.hideStatusBar() end end)
    return
  end
  objectHistoryActions.changeObjectFieldWithUndo({node.id}, "name", name, 0)
  node.name = name
end

local function onEditorObjectSelectionChanged()
  for index, instance in pairs(guiInstancer.instances) do
    if instance.selectedNodes then
      for _, node in pairs(instance.selectedNodes) do
        node.selected = false
      end
    end
    instance.selectedNodes = {}
    if instance.rootNode then
      updateNodeSelection(instance, instance.rootNode)
      getRootNodeSize(instance)
    end
    instance.noScrollToSelection = nil
    if not clickedOnNode and #instance.selectedNodes > 0 then
      instance.lastSelectedIndex = instance.selectedNodes[#instance.selectedNodes].listIndex
    end
  end

  -- Apply last nodes' new name
  if editingNodeName then
    local newName = ffi.string(inputTextValue)
    local object = scenetree.findObjectById(editingNodeName.id)
    if object then
      changeNodeName(editingNodeName, newName)
    end
    editingNodeName = nil
  end
end

-- Change Ordering
local function changeOrderActionUndo(actionData)
  if not actionData.objects then
    return
  end
  for i = #actionData.objects, 1, -1 do
    local object = scenetree.findObjectById(actionData.objects[i])
    if object then
      local oldGroup = scenetree.findObjectById(actionData.oldGroups[i])
      if oldGroup then
        oldGroup:add(object)
        if actionData.placeholderObjects[i] then
          local placeholderObject = scenetree.findObjectById(actionData.placeholderObjects[i])
          if placeholderObject then
            oldGroup:reorderChild(object, placeholderObject)
          end
        end
      end
    end
  end
  recacheAllNodes(nil, true)
  onEditorObjectSelectionChanged()
end

local function changeOrderActionRedo(actionData)
  if not actionData.objects then
    editor.selectObjects({actionData.newGroup}, editor.SelectMode_New)
    return
  end
  local newGroup = scenetree.findObjectById(actionData.newGroup)
  if not newGroup then return end
  if actionData.destObject then
    local destObject = scenetree.findObjectById(actionData.destObject)
    for i = 1, #actionData.objects do
      local object = scenetree.findObjectById(actionData.objects[i])
      if object then
        newGroup:add(object)
        if destObject then
          newGroup:reorderChild(object, destObject)
        end
      end
    end
  else
    for i = #actionData.objects, 1, -1 do
      local object = scenetree.findObjectById(actionData.objects[i])
      if object and newGroup.add and newGroup.bringToFront then
        newGroup:add(object)
        newGroup:bringToFront(object)
      end
    end
  end
  recacheAllNodes(nil, true)
  onEditorObjectSelectionChanged()
end

local function createSimGroupRedo(actionData)
  local objId = objectHistoryActions.createObjectRedo({name = "", className = "SimGroup", objectId = actionData.newGroup, parentId = actionData.parentId})
  if not actionData.newGroup then
    actionData.newGroup = objId
  end
  changeOrderActionRedo(actionData)
end

local function createSimGroupUndo(actionData)
  changeOrderActionUndo(actionData)
  objectHistoryActions.createObjectUndo({objectId = actionData.newGroup})
end

local function getNodeLevelRec(node, level)
  if node.parent then
    level = level + 1
    return getNodeLevelRec(node.parent, level)
  end
  return level
end

local function getNodeLevel(node)
  return getNodeLevelRec(node, 0)
end

local function getHighestNode(nodes)
  local levelHighestNode = math.huge
  local highestNode
  for i, node in ipairs(nodes) do
    local level = getNodeLevel(node)
    if level < levelHighestNode then
      levelHighestNode = level
      highestNode = node
    end
  end
  return highestNode
end

local function addNewGroupToSceneTree(instance, groupParentID, addSelectedObjects)
  if not groupParentID then
    local selNode = getHighestNode(instance.selectedNodes)
    local object = scenetree.findObjectById(selNode.id)
    if selNode.isGroup and not addSelectedObjects then
      if object then
        groupParentID = object:getID()
      end
    else
      if object then
        local parent = object:getGroup()
        if parent then
          groupParentID = parent:getID()
        end
      end
    end
  end

  if not groupParentID then
    groupParentID = scenetree.MissionGroup:getID()
  end

  local actionInfo = addSelectedObjects and getChangeOrderActionData(instance) or {}
  actionInfo.parentId = groupParentID
  editor.history:commitAction("CreateGroup", actionInfo, createSimGroupUndo, createSimGroupRedo)
  editor.setDirty()

  return grp
end

local function addNewGroupToSceneTreeFromSelection(instance)
  local grp = addNewGroupToSceneTree(instance, nil, true)
  if not grp then return end
  return grp
end

local function toggleNode(node)
  if node.isGroup then
    node.open = not node.open
    editingNodeName = nil
    for index, instance in pairs(guiInstancer.instances) do
      instance.rootNodeSizeCache = nil
    end
  end
end

local function editNodeName(node)
  editingNodeName = node
  node.setFocus = true
  if node.name then
    ffi.copy(inputTextValue, node.name)
  end
end

local function nodeIsInTheSelection(instance, node)
  for i = 1, tableSize(instance.selectedNodes) do
    if instance.selectedNodes[i].id == node.id then return true end
  end
  return false
end

local function moveSelectionIndex(up)
  for index, instance in pairs(guiInstancer.instances) do
    if instance.focused and instance.currentListIndex then
      instance.newListIndex = instance.currentListIndex + (up and -1 or 1)
    end
  end
end

local function isGroupChildOfSelection(instance, group)
  local parent = group.parent
  if parent then
    for _, node in pairs(instance.selectedNodes) do
      if parent.id == node.id then
        return true
      end
    end
    return isGroupChildOfSelection(instance, parent)
  end
  return false
end

local function refreshAllNodes(incomingObjectIds)
  for _, instance in pairs(guiInstancer.instances) do
    cacheGroupNode(instance, instance.rootNode, incomingObjectIds, 0)
    instance.rootNodeSizeCache = nil
  end
end

local function sortGroupNode(instance, node, recursive)
  local object = scenetree.findObjectById(node.id)
  if node.isGroup and object then
    object:sortByName(false, false)
    -- we clear the children list so it will recreate it sorted
    node.children = nil
    cacheGroupNode(instance, node, nil, 0)

    if recursive then
      for _, child in ipairs(node.children) do
        sortGroupNode(instance, child, recursive)
      end
    end
  end
end

local function collapseNode(node)
  if not node.children then return end
  for _, child in ipairs(node.children) do
    child.open = false
    collapseNode(child)
  end
end

local function collapseAllSceneTree(instance)
  collapseNode(instance.rootNode)
end

--TODO: check if we can do the scene tree populate directly with no Lua tables
local function onAddObjectToSet(object, simset)
  refreshAllNodes({object:getID()})
  for index, instance in pairs(guiInstancer.instances) do
    refreshNodeCache(instance)
  end
end

local function onRemoveObjectFromSet(object, simset)
  for _, instance in pairs(guiInstancer.instances) do
    removeNodesByObjectIds(instance, {object:getID()})
  end
  refreshAllNodes()
  for index, instance in pairs(guiInstancer.instances) do
    refreshNodeCache(instance)
  end
end

local function onClearObjectsFromSet(simset)
  recacheAllNodes(nil, true)
end

local function selectChildrenRecursive(instance, parent, objectIDs)
  for _, node in pairs(parent.children) do
    if node.isGroup then
      selectChildrenRecursive(instance, node, objectIDs)
    else
      table.insert(objectIDs, node.id)
    end
  end
end

local function selectChildren(instance, node)
  local objectIDs = {}
  selectChildrenRecursive(instance, node, objectIDs)
  editor.selectObjects(objectIDs, editor.SelectMode_New)
end

local function rangesIntersect(r1, r2)
  return r1.min < r2.max and r1.max > r2.min
end

local function boolFieldButton(instance, node, field, iconOn, iconOff)
  local object = scenetree.findObjectById(node.id)
  if not object then return end
  local value = object:getField(field, 0) == "1"
  local icon = value and iconOn or iconOff
  local newValue = not value

  local function setFieldRec(node, v, objectIDs)
    table.insert(objectIDs, node.id)
    for _, n in ipairs(node.children or {}) do
      setFieldRec(n, v, objectIDs)
    end
  end

  if editor.uiIconImageButton(icon, iconSize, iconColor, "", nil, nil, iconColor, node.textBG, activateOnRelease) then
    local objectIDs = {}
    table.insert(objectIDs, node.id)
    if node.selected then
      for _, n in ipairs(instance.selectedNodes) do
        setFieldRec(n, newValue, objectIDs)
      end
    end
    for _, n in ipairs(node.children or {}) do
      setFieldRec(n, newValue, objectIDs)
    end
    objectHistoryActions.changeObjectFieldWithUndo(objectIDs, field, tostring(newValue), 0)
    editor.setDirty()
    return true
  end
end

local disableHoverColor
local drewDragSeparator

local function nodeSelectable(instance, node, icon, iconSize, selectionColor, label, textColor, triggerOnRelease, highlightText)
  editor.uiIconImage(icon, iconSize, nil)
  imgui.SameLine()
  imgui.PushStyleColor2(imgui.Col_Header, selectionColor)
  if node.selected or node.dragSelected then
    imgui.PushStyleColor2(imgui.Col_HeaderHovered, selectionColor)
  elseif hasDragDropPayload and (disableHoverColor or not node.isGroup) then
    imgui.PushStyleColor2(imgui.Col_HeaderHovered, imgui.ImVec4(0,0,0,0))
  end
  imgui.Selectable1("##" .. label, node.selected or node.dragSelected, imgui.SelectableFlags_SpanAllColumns)
  imgui.SetItemAllowOverlap()
  local selectableHovered = imgui.IsItemHovered()
  if node.selected or node.dragSelected then
    imgui.PopStyleColor()
  elseif hasDragDropPayload and (disableHoverColor or not node.isGroup) then
    imgui.PopStyleColor()
  end
  imgui.PopStyleColor()

  imgui.SameLine()
  editor.uiHighlightedText(label, highlightText, textColor)
  local textHovered = imgui.IsItemHovered()

  if hasDragDropPayload then
    -- Check if hovering between items
    local mousePosY = imgui.GetMousePos().y
    local itemRect = {min = imgui.GetItemRectMin(), max = imgui.GetItemRectMax()}
    local middlePoint = itemRect.min.y - imgui.GetStyle().FramePadding.y/2
    if mousePosY < middlePoint + entrySize/5 and mousePosY > middlePoint - entrySize/5 and imgui.IsWindowHovered(imgui.HoveredFlags_RootAndChildWindows) then
      local p1 = imgui.ImVec2(imgui.GetWindowPos().x, itemRect.min.y - imgui.GetStyle().FramePadding.y/2)
      local winSize = imgui.GetWindowSize()
      local p2 = imgui.ImVec2(imgui.GetWindowPos().x + winSize.x*2, p1.y)
      local dl = imgui.GetWindowDrawList()
      imgui.ImDrawList_AddLine(dl, p1, p2, imgui.GetColorU322(imgui.ImVec4(1,1,1,1)), 3)

      local parent = scenetree.findObjectById(node.parent.id)
      if imgui.IsMouseReleased(0) and parent and not node.parent.selected and not isGroupChildOfSelection(instance, parent) then
        local objects = {}
        local placeholderObjects = {}
        local oldGroups = {}
        for _, node in ipairs(instance.selectedNodes) do
          local object = scenetree.findObjectById(node.id)
          local parent = scenetree.findObjectById(node.parent.id)
          if object and parent then
            table.insert(objects, node.id)
            local nextObject = parent:getObject(parent:getObjectIndex(object) + 1)
            if nextObject then
              table.insert(placeholderObjects, nextObject:getID())
            end
            table.insert(oldGroups, node.parent.id)
          end
        end
        local actionInfo = {objects = objects, placeholderObjects = placeholderObjects, oldGroups = oldGroups, newGroup = node.parent.id, destObject = node.id}
        editor.history:commitAction("ChangeOrder", actionInfo, changeOrderActionUndo, changeOrderActionRedo)
        editor.setDirty()
      end
      drewDragSeparator = true
    elseif selectableHovered then
      if imgui.IsMouseReleased(0) then
        if node.isGroup and not node.hidden and not disableHoverColor then
          if not node.selected and not isGroupChildOfSelection(instance, node) then
            local actionInfo = getChangeOrderActionData(instance, node.id)
            editor.history:commitAction("ChangeOrder", actionInfo, changeOrderActionUndo, changeOrderActionRedo)
            editor.setDirty()
            nodeIdToOpen = node.id
          end
        end
      end
    end
  end

  imgui.TableNextColumn()
  -- ==============================
  -- following are the buttons for the table

  local object = scenetree.findObjectById(node.id)
  -- hide/unhide
  if object and object.isHidden then
    if boolFieldButton(instance, node, "hidden", editor.icons.visibility_off, editor.icons.visibility) then
      clickedOnNode = true
    end
    if imgui.IsItemHovered() then selectableHovered = false end
    if object.isLocked then imgui.SameLine() end
  end

  -- lock/unlock
  if object and object.isLocked then
    if boolFieldButton(instance, node, "locked", editor.icons.lock, editor.icons.lock_open) then
      clickedOnNode = true
    end
    if imgui.IsItemHovered() then selectableHovered = false end
  end

  if selectableHovered then
    if imgui.IsMouseDoubleClicked(0) then
      node.renameRequestTime = nil
      nodeWasDblClicked = true
      if node.isGroup then
        toggleNode(node)
      else
        editor.fitViewToSelectionSmooth()
      end
    end
    if imgui.IsMouseClicked(0) then
      clickedOnNode = true
    end
    if imgui.IsMouseDragging(0) then
      if clickedOnNode and not mouseDragRange and (triggerOnRelease or textHovered) then
        hasDragDropPayload = true
      end
      node.renameRequestTime = nil
    end
    if imgui.IsMouseClicked(1) then
      if not node.isGroup then
        imgui.SetWindowFocus1()
      end
    end
    if imgui.IsMouseReleased(1) then
      imgui.OpenPopup("##sceneItemPopupMenu"..node.id)
    end

    if triggerOnRelease then
      if imgui.IsMouseReleased(0) and not imgui.IsMouseDragging(0) then
        return true
      else
        return false
      end
    elseif imgui.IsMouseClicked(0) then
      return true
    end
  end
end

local deleteNodes = false
local hideSelectionClicked = false
local showSelectionClicked = false
local lockSelectionClicked = false
local unlockSelectionClicked = false
local objectRemoved = false

local function renderSceneGroup(instance, node, selectMode)
  if not showGroups then return end
  local icon = getGroupNodeIcon(node)
  local selectionColor = imgui.GetStyleColorVec4(imgui.Col_ButtonActive)

  local arrowIcon = node.open and editor.icons.keyboard_arrow_down or editor.icons.keyboard_arrow_right
  imgui.PushStyleColor2(imgui.Col_Button, transparentColor)
  if editor.uiIconImageButton(arrowIcon, iconSize, nil, nil, nil, nil, selectionColor) then
    toggleNode(node)
  end
  imgui.PopStyleColor()
  imgui.SameLine()

  local nodeLabel = node.displayName

  if node.filterResult then
    if bit.band(node.filterResult, searchMatches[2]) ~= 0 and node.name ~= node.displayName then
      nodeLabel = nodeLabel .. ' [name: ' .. node.name .. ']'
    end
    if bit.band(node.filterResult, searchMatches[3]) ~= 0 then
      nodeLabel = nodeLabel .. ' [id: ' .. tostring(node.id) .. ']'
    end
    if bit.band(node.filterResult, searchMatches[4]) ~= 0 then
      nodeLabel = nodeLabel .. ' [class: ' .. node.className .. ']'
    end
  end

  if node.selected then
    if nodeSelectable(instance, node, icon, iconSize, selectionColor, nodeLabel, nil, not onClickSelected, nameFilterText) then
      if (onClickSelected or clickedOnNode) and not hasDragDropPayload then
        if tableSize(editor.selection.object) == 1 and not nodeWasDblClicked then
          node.renameRequestTime = socket.gettime()
        end
        -- just reset selection to this one
        selectNode(instance, node, selectMode)
        nodeWasDblClicked = nil
      end
    end
  else
    if nodeSelectable(instance, node, icon, iconSize, selectionColor, nodeLabel, nil, nil, nameFilterText) then
      onClickSelected = true
      selectNode(instance, node, selectMode)
    end
  end

  node.textBG = nil

  if imgui.BeginPopup("##sceneItemPopupMenu"..node.id) then
    if not nodeIsInTheSelection(instance, node) then
      selectNode(instance, node, editor.SelectMode_New)
    end
    if imgui.Selectable1("New Group") then
      local grp = addNewGroupToSceneTree(instance)
      editor.selectObjectById(grp:getID())
    end
    if imgui.Selectable1("Delete Group") then
      if not tableIsEmpty(instance.selectedNodes) then
        deleteNodes = true
      end
    end
    if imgui.Selectable1("Put Into New Group") then
      local grp = addNewGroupToSceneTreeFromSelection(instance)
      local grpNode = findNodeByObject(instance, nil, grp)
      selectNode(instance, grpNode)
    end
    imgui.Separator()
    if not tableIsEmpty(instance.selectedNodes) then
      if imgui.Selectable1("Hide Selection") then
        hideSelectionClicked = true
      end
      if imgui.Selectable1("Show Selection") then
        showSelectionClicked = true
      end
    end
    imgui.Separator()
    if not tableIsEmpty(instance.selectedNodes) then
      if imgui.Selectable1("Lock Selection") then
        lockSelectionClicked = true
      end
      if imgui.Selectable1("Unlock Selection") then
        unlockSelectionClicked = true
      end
    end
    imgui.Separator()
    if imgui.Selectable1("Sort Group") then
      sortGroupNode(instance, node)
    end
    if imgui.Selectable1("Sort Group Recursive") then
      sortGroupNode(instance, node, true)
    end
    imgui.Separator()
    local object = scenetree.findObjectById(node.id)
    if object and node.className ~= "Prefab" then
      if imgui.Selectable1("Pack Prefab") then
        --TODO: check JSON save, load, replace cs to json save load
        if object:getField("prefab_filename", "") ~= "" then
          local prefab = editor.createPrefabFromObjectSelection(object:getField("prefab_filename", ""), object:getField("prefab_name", ""))
          local prefabNode = findNodeByObject(instance, nil, prefab)
          selectNode(instance, prefabNode)
          imgui.EndPopup()
          objectRemoved = true
          return
        else
          extensions.editor_fileDialog.saveFile(function(data)
            local prefab = editor.createPrefabFromObjectSelection(data.filepath, node.name, "auto")
            local prefabNode = findNodeByObject(instance, nil, prefab)
            selectNode(instance, prefabNode) end,
            {{"Prefab Files (CS)",".prefab"}, {"[Experimental] Prefab Files (JSON)",".prefab.json"}}, false,
              FS:directoryExists(prefabSaveFolder) and prefabSaveFolder or "/")
          imgui.EndPopup()
          objectRemoved = true
          return
        end
      end
    end

    if imgui.Selectable1("Select Children") then
      if tableSize(instance.selectedNodes) == 1 then
        local parentNode = instance.selectedNodes[1]
        selectChildren(instance, parentNode)
      end
    end
    imgui.Separator()
    if imgui.Selectable1("Collapse Parent Group") then
      local parentNode = node.parent
      if parentNode then parentNode.open = false end
    end
    if imgui.Selectable1("Collapse All Scene Tree") then
      collapseAllSceneTree(instance)
    end
    imgui.EndPopup()
  end
end

local function renderSceneNode(instance, node, selectMode)
  if node.hidden then return end

  local selectionColor = imgui.GetStyleColorVec4(imgui.Col_ButtonActive)
  local activateOnRelease = node.selected and not onClickSelected

  imgui.Spacing()
  imgui.SameLine()

  local nodeLabel = node.displayName

  if node.filterResult then
    if bit.band(node.filterResult, searchMatches[2]) ~= 0 and node.name ~= node.displayName then
      nodeLabel = nodeLabel .. ' [name: ' .. node.name .. ']'
    end
    if bit.band(node.filterResult, searchMatches[3]) ~= 0 then
      nodeLabel = nodeLabel .. ' [id: ' .. tostring(node.id) .. ']'
    end
    if bit.band(node.filterResult, searchMatches[4]) ~= 0 then
      nodeLabel = nodeLabel .. ' [class: ' .. node.className .. ']'
    end
  end

  if nodeSelectable(instance, node, node.icon or defaultObjectNodeIcon, iconSize, selectionColor, nodeLabel, nil, activateOnRelease, nameFilterText) then
    if (not activateOnRelease or clickedOnNode) and not hasDragDropPayload then
      if node.selected and not (ctrlDown or shiftDown) then
        if tableSize(editor.selection.object) == 1 and not nodeWasDblClicked then
          node.renameRequestTime = socket.gettime()
        end
        selectNode(instance, node, selectMode)
        nodeWasDblClicked = nil
      else
        selectNode(instance, node, selectMode)
        onClickSelected = true
      end
      instance.noScrollToSelection = true
    end
  end

  if searchRange > 0 and node.cameraDistance then
    imgui.TableNextColumn()
    imgui.TextUnformatted(string.format('%0.1f', node.cameraDistance) .. 'm')
  end

  if imgui.BeginPopup("##sceneItemPopupMenu"..node.id) then
    if not nodeIsInTheSelection(instance, node) then
      selectNode(instance, node, editor.SelectMode_New)
    end
    if imgui.Selectable1("Clone") then
      if not tableIsEmpty(instance.selectedNodes) then
        editor.duplicate()
      end
    end
    if imgui.Selectable1("Delete Object(s)") then
      if not tableIsEmpty(instance.selectedNodes) then
        deleteNodes = true
      end
    end
    imgui.Separator()
    if not tableIsEmpty(instance.selectedNodes) then
      if imgui.Selectable1("Hide Selection") then
        hideSelectionClicked = true
      end
      if imgui.Selectable1("Show Selection") then
        showSelectionClicked = true
      end
    end
    imgui.Separator()
    if not tableIsEmpty(instance.selectedNodes) then
      if imgui.Selectable1("Lock Selection") then
        lockSelectionClicked = true
      end
      if imgui.Selectable1("Unlock Selection") then
        unlockSelectionClicked = true
      end
    end
    imgui.Separator()
    if imgui.Selectable1("Put Into New Group") then
      local grp = addNewGroupToSceneTreeFromSelection(instance)
      local grpNode = findNodeByObject(instance, nil, grp)
      selectNode(instance, grpNode)
    end
    if imgui.Selectable1("Pack Into Prefab") then
      extensions.editor_fileDialog.saveFile(function(data)
        local prefab = editor.createPrefabFromObjectSelection(data.filepath, node.name, "auto")
        local prefabNode = findNodeByObject(instance, nil, prefab)
        selectNode(instance, prefabNode) end,
        {{"Prefab Files (CS)",".prefab"}, {"[Experimental] Prefab Files (JSON)",".prefab.json"}}, false,
          FS:directoryExists(prefabSaveFolder) and prefabSaveFolder or "/")
    end
    if node.className == "Prefab" then
      if imgui.Selectable1("Unpack Prefab") then
        local groups = editor.explodeSelectedPrefab()
        if tableSize(groups) then
          local grpNode = findNodeByObject(instance, nil, groups[1])
          selectNode(instance, grpNode)
          -- node is now nil/invalid since it was deleted by unpacking, assign group node
          node = grpNode
        end
        objectRemoved = true
      end
    end
    imgui.Separator()
    if imgui.Selectable1("Collapse Parent Group") then
      local parentNode = node.parent
      if parentNode then parentNode.open = false end
    end
    if imgui.Selectable1("Collapse All Scene Tree") then
      collapseAllSceneTree(instance)
    end

    if imgui.Selectable1("Inspect in new Window") then
      editor.addInspectorInstance(editor.selection)
    end
    if imgui.IsItemHovered() then imgui.SetTooltip("New Inspector Window for the selected object(s)") end

    imgui.Separator()
    --  Extended menu items generation
    --  Items are "registered" via the `editor.addExtendedSceneTreeObjectMenuItem` method
    --  They are displayed in a "More >" submenu.
    if #extendedSceneTreeObjectMenuItems > 0 then
      --  Constructs valid custom items
      local validCustomMenuItems = {}
      for _, item in ipairs(extendedSceneTreeObjectMenuItems) do
        local validator = item.validator or function(obj) return true end
        if validator(node) then
          table.insert(validCustomMenuItems, item)
        end
      end
      if #validCustomMenuItems > 0 then
        imgui.Separator()
        local generateExtendedSceneTreeObjectMenuItems = function(items)
          for _, item in ipairs(items) do
            if item.title and imgui.Selectable1(item.title) and item.extendedSceneTreeObjectMenuItems then
              item.extendedSceneTreeObjectMenuItems(node)
            end
          end
        end
        -- Generates the "More >" submenu
        if imgui.BeginMenu("More", imgui_true) then
          generateExtendedSceneTreeObjectMenuItems(validCustomMenuItems)
          imgui.EndMenu()
        end
      end
    end
    imgui.EndPopup()
  end
end

local function renderSceneTreeGui(instance, node, recursiveDisplay)
  if not node then return end
  if not node.id then return end
  local object = scenetree.findObjectById(node.id)

  local selectMode = editor.SelectMode_New

  local ctrlDown = editor.keyModifiers.ctrl
  local shiftDown = editor.keyModifiers.shift
  local altDown = editor.keyModifiers.alt

  if ctrlDown then selectMode = editor.SelectMode_Toggle end
  if altDown then selectMode = editor.SelectMode_Remove end
  if shiftDown then selectMode = SelectMode_Range end

  -- skip root node from showing in the scene tree
  if node ~= instance.rootNode then
  if instance.newListIndex and node.listIndex == instance.newListIndex then
    selectNode(instance, node, selectMode)
    instance.newListIndex = nil
    if imgui.GetCursorPosY() + entrySize > (imgui.GetScrollY() + imgui.GetWindowHeight()) or imgui.GetCursorPosY() < imgui.GetScrollY() then
      imgui.SetScrollY(imgui.GetCursorPosY() - imgui.GetWindowHeight()/2)
    end
  end
  if instance.scrollToNode and instance.scrollToNode == node.id then
    if not node.hidden then
      if imgui.GetCursorPosY() > (imgui.GetScrollY() + imgui.GetWindowHeight()) or imgui.GetCursorPosY() + entrySize < imgui.GetScrollY() then
        imgui.SetScrollY(node.listIndex * entrySize - imgui.GetWindowHeight()/2)
      end
    end
    instance.scrollToNode = nil
  end

  if instance.selectionRange then
    if instance.selectionRange[node.listIndex] then
      if not instance.objectsToSelect then instance.objectsToSelect = {} end
      table.insert(instance.objectsToSelect, node.id)
      instance.selectionRange[node.listIndex] = nil
    end
    if tableIsEmpty(instance.selectionRange) then
      instance.selectionRange = nil
      editor.selectObjects(instance.objectsToSelect)
      instance.objectsToSelect = nil
    end
  end
  local wasSelected = node.selected

  local skipGui = false
  if not node.hidden and imgui.GetCursorPosY() + entrySize < imgui.GetScrollY() then
    imgui.SetCursorPosY(imgui.GetCursorPosY() + entrySize)
    skipGui = true
  end

  if imgui.GetCursorPosY() > (imgui.GetScrollY() + imgui.GetWindowHeight()) and not instance.scrollToNode then
    imgui.SetCursorPosY(instance.scenetreeSize)
    return
  end

  if not skipGui and not node.hidden then
    imgui.TableNextRow()
    imgui.TableNextColumn()

    if nodeIdToOpen and nodeIdToOpen == node.id then
      node.open = true
      nodeIdToOpen = nil
    end

    -- Turn the name into a text field for name editing
    if editingNodeName == node then
      local icon = node.icon
      if node.isGroup then
        icon = getGroupNodeIcon(node)
        local arrowIcon = node.open and editor.icons.keyboard_arrow_down or editor.icons.keyboard_arrow_right
        imgui.PushStyleColor2(imgui.Col_Button, transparentColor)
        editor.uiIconImageButton(arrowIcon, iconSize, iconColor, nil, nil, nil, iconColor)
        imgui.PopStyleColor()
        imgui.SameLine()
      end
      editor.uiIconImageButton(icon, iconSize, imgui.GetStyleColorVec4(imgui.Col_Text))
      imgui.SameLine()
      if node.setFocus then
        imgui.SetKeyboardFocusHere()
      end
      local changed = editor.uiInputText("", inputTextValue, ffi.sizeof(inputTextValue), imgui.InputTextFlags_AutoSelectAll, nil, nil, editEnded)
      if editEnded[0] or (not imgui.IsItemActive() and not node.setFocus) then
        local newName = ffi.string(inputTextValue)
        if object then
          changeNodeName(node, newName)
        end
        editingNodeName = nil
      end
      if node.setFocus then
        node.setFocus = nil
      end

    elseif node.isGroup and not node.hidden then
      renderSceneGroup(instance, node, selectMode)
    else
      renderSceneNode(instance, node, selectMode)
    end
    local nodeHovered = imgui.IsItemHovered()

    if objectRemoved then node = nil objectRemoved = false end
    if not node then return end

    if tableSize(editor.selection.object) == 1
        and node.renameRequestTime
        and not imgui.IsMouseDown(0)
        and (socket.gettime() - node.renameRequestTime) > imgui.GetIO().MouseDoubleClickTime
        and node.name ~= "MissionGroup" then
      editNodeName(node)
      node.renameRequestTime = nil
    end

    node.dragSelected = false
    if mouseDragRange and node.listIndex then
      dragSelectionList[node.listIndex] = nil
      local itemRectRange = {min = imgui.GetItemRectMin().y, max = imgui.GetItemRectMax().y}
      itemRectRange.min = itemRectRange.min - 2
      itemRectRange.max = itemRectRange.max + 2
      if rangesIntersect(mouseDragRange, itemRectRange) then
        dragSelectionList[node.listIndex] = true
        node.dragSelected = true
      end
    end
  end
  end -- end skip root node if

  if recursiveDisplay and node.isGroup and (not showGroups or node.open or node.openOnSearch) then
    if showGroups and node ~= instance.rootNode then imgui.Indent() end
    for _, child in ipairs(node.children) do
      renderSceneTreeGui(instance, child, recursiveDisplay)
    end
    if showGroups and node ~= instance.rootNode then imgui.Unindent() end
  end

  if hasDragDropPayload then
    if imgui.IsKeyDown(imgui.GetKeyIndex(imgui.Key_Escape)) then
      hasDragDropPayload = false
    else
      imgui.SetMouseCursor(2) -- ResizeAll cursor
    end
  end

  if hideSelectionClicked then
    editor.hideObjectSelection()
  end

  if showSelectionClicked then
    editor.showObjectSelection()
  end

  if lockSelectionClicked then
    editor.lockObjectSelection()
  end

  if unlockSelectionClicked then
    editor.unlockObjectSelection()
  end

  if deleteNodes then
    editor.deleteSelection()
  end

  deleteNodes = false
  hideSelectionClicked = false
  showSelectionClicked = false
  lockSelectionClicked = false
  unlockSelectionClicked = false
end

local function addNewSceneTreeInstance()
  local index = guiInstancer:addInstance()
  local wndName = sceneTreeWindowNamePrefix .. index
  guiInstancer.instances[index].locked = true -- will not scroll to the new selection, will stay at its scroll position
  guiInstancer.instances[index].nameFilter = imgui.ImGuiTextFilter()
  guiInstancer.instances[index].selectedNodes = {}
  guiInstancer.instances[index].windowName = wndName
  recacheAllNodes()
  editor.registerWindow(wndName, imgui.ImVec2(300, 500))
  editor.showWindow(wndName)
end

local function openSceneTree()
  --TODO: this will force 1 instance only of the scene tree
  if tableSize(guiInstancer.instances) == 1 then return end
  addNewSceneTreeInstance()
end

local function onEditorGui()
  drewDragSeparator = false
  entrySize = round(math.max(imgui.CalcTextSize("W").y, iconSize.y * imgui.uiscale[0]) + imgui.GetStyle().FramePadding.y + 1) + 4
  for index, instance in pairs(guiInstancer.instances) do
    currentSceneTreeInstanceIndex = index
    local wndName = instance.windowName
    imgui.PushStyleColor2(imgui.Col_Button, imgui.ImVec4(0,0,0,0))
    if editor.beginWindow(wndName, "SceneTree##" .. index) then
      if not editor.isWindowVisible(wndName) then
        guiInstancer:removeInstance(index)
        editor.unregisterWindow(wndName)
      else
        -- SceneTree toolbar
        local filterTypeComboWidth = 100
        local style = imgui.GetStyle()
        local searchRangeIconWidth = 24
        local searchFilterWidth = imgui.GetContentRegionAvailWidth() - (filterTypeComboWidth + 2 * searchRangeIconWidth * imgui.uiscale[0] + 2 * style.ItemSpacing.x)

        if editor.uiIconImageButton(editor.icons.create_new_folder, imgui.ImVec2(24, 24)) then
          addNewGroupToSceneTree(instance)
        end
        if imgui.IsItemHovered() then imgui.SetTooltip("New subgroup (folder) in the selected group") end
        imgui.SameLine()
        imgui.PushID1("SceneSearchFilter")
        if editor.uiInputSearchTextFilter("##nodeNameSearchFilter", instance.nameFilter, searchFilterWidth, nil, nil, editEnded) then
          if ffi.string(imgui.TextFilter_GetInputBuf(instance.nameFilter)) == "" then
            imgui.ImGuiTextFilter_Clear(instance.nameFilter)
          end
          refreshNodeCache(instance)
        end
        imgui.PopID()
        if imgui.IsItemHovered() then imgui.SetTooltip("Search text") end
        imgui.SameLine()
        imgui.PushItemWidth(filterTypeComboWidth)
        comboIndex[0] = searchNodeMode
        if imgui.Combo1("##filterType", comboIndex, searchTypesComboItems) then
          searchNodeMode = comboIndex[0]
        end
        if imgui.IsItemHovered() then imgui.SetTooltip("Search filter mode") end
        imgui.PopItemWidth()

        imgui.SameLine()

        local bgColor = nil
        if searchRange > 0 then bgColor = imgui.GetStyleColorVec4(imgui.Col_ButtonActive) end
        if editor.uiIconImageButton(editor.icons.wifi_tethering, imgui.ImVec2(searchRangeIconWidth, searchRangeIconWidth), nil, nil, bgColor) then
          if searchRange > 0 then
            searchRange = -1
          else
            searchRange = 200
          end
          showGroups = searchRange < 0
          applyFilter(instance, instance.rootNode)
        end
        if imgui.IsItemHovered() then imgui.SetTooltip("Only show near objects") end

        local maxTreeHeight = imgui.GetContentRegionAvail().y - entrySize - (imgui.GetStyle().FramePadding.y * 2 + imgui.GetStyle().ItemInnerSpacing.y + 2 * imgui.GetStyle().ItemSpacing.y) - 5

        imgui.BeginChild1("Scene Tree Child", imgui.ImVec2(0, searchResultsMode and maxTreeHeight or 0), false)
        if searchResultsMode then
          instance.scenetreeSize = #searchResults * entrySize
          instance.rootNodeSizeCache = instance.scenetreeSize
          instance.listIndex = 1
        else
          instance.scenetreeSize = getRootNodeSize(instance) * entrySize
        end

        -- Renders alternate rows on all window
        local tableFlags = bit.bor(imgui.TableFlags_ScrollY, imgui.TableFlags_BordersV, imgui.TableFlags_BordersOuterH, imgui.TableFlags_Resizable, imgui.TableFlags_RowBg, imgui.TableFlags_NoBordersInBody)

        local colCount = 2
        if searchRange > 0 then colCount = colCount + 1 end

        if imgui.BeginTable('##scenetreetable', colCount, tableFlags) then
          -- The first column will use the default _WidthStretch when ScrollX is Off and _WidthFixed when ScrollX is On
          local textBaseWidth = imgui.CalcTextSize('A').x
          imgui.TableSetupScrollFreeze(0, 1) -- Make top row always visible
          imgui.TableSetupColumn('Tree', imgui.TableColumnFlags_NoHide)
          if searchRange > 0 then
            imgui.TableSetupColumn('Distance', imgui.TableColumnFlags_WidthFixed, textBaseWidth * 6)
          end
          imgui.TableSetupColumn('Controls', imgui.TableColumnFlags_WidthFixed, textBaseWidth * 6)
          imgui.TableHeadersRow()

          --  SceneTree list
          if searchResultsMode then
            -- refreshNodeCache every half second
            searchRangeTime = searchRangeTime + searchRangeTimer:stopAndReset()
            if searchRangeTime > 500 then
              searchRangeTime = math.fmod(searchRangeTime, 500)
              refreshNodeCache(instance)
            end

            for li, n in ipairs(searchResults) do
              n.listIndex = li
              instance.listIndex = instance.listIndex + 1
              renderSceneTreeGui(instance, n, false)
            end
          else
            renderSceneTreeGui(instance, instance.rootNode, true)
          end

          imgui.EndTable()
        end

        if imgui.IsMouseClicked(0) and imgui.IsWindowHovered(imgui.HoveredFlags_RootAndChildWindows) then
          if not clickedOnNode and not editor.keyModifiers.ctrl then
            editor.clearObjectSelection()
          end
          local mousePos = imgui.GetMousePos()
          if mousePos.x < imgui.GetWindowPos().x + imgui.GetWindowWidth() - 16 then
            instance.mouseDragStartPos = mousePos
            instance.mouseDragStartScrollY = imgui.GetScrollY()
          end
        end

        if imgui.IsMouseDragging(0) and instance.mouseDragStartPos and not hasDragDropPayload then
          if not editor.keyModifiers.ctrl then
            editor.clearObjectSelection()
          end
          local mouseDragEndPos = imgui.GetMousePos()
          local scrollYDiff = imgui.GetScrollY() - instance.mouseDragStartScrollY
          mouseDragRange = {min = math.min(instance.mouseDragStartPos.y - scrollYDiff, mouseDragEndPos.y),
                           max = math.max(instance.mouseDragStartPos.y - scrollYDiff, mouseDragEndPos.y)}

          local localMouseDragStartPos = imgui.ImVec2(instance.mouseDragStartPos.x, instance.mouseDragStartPos.y - scrollYDiff)
          local winPos = imgui.GetWindowPos()
          local winSize = imgui.GetWindowSize()

          if mouseDragEndPos.y < winPos.y then
            imgui.SetScrollY(imgui.GetScrollY() - 10)
          end
          if mouseDragEndPos.y > winPos.y + winSize.y then
            imgui.SetScrollY(imgui.GetScrollY() + 10)
          end

          imgui.ImDrawList_AddRect(imgui.GetWindowDrawList(), localMouseDragStartPos, mouseDragEndPos, imgui.GetColorU322(imgui.ImVec4(1, 1, 0, 1)))
        end

        if imgui.IsMouseReleased(0) and instance.mouseDragStartPos then
          if not hasDragDropPayload then
            local maxIndex = -1
            local minIndex = math.huge
            instance.selectionRange = {}
            for nodeListIndex, _ in pairs(dragSelectionList) do
              instance.selectionRange[nodeListIndex] = true
              if nodeListIndex > maxIndex then maxIndex = nodeListIndex end
              if nodeListIndex < minIndex then minIndex = nodeListIndex end
            end
            if not tableIsEmpty(dragSelectionList) then
              instance.lastSelectedIndex = minIndex
              instance.currentListIndex = maxIndex
            end
          end
          instance.noScrollToSelection = true
          instance.mouseDragStartPos = nil
          dragSelectionList = {}
        end

        imgui.EndChild()

        -- footer
        if searchResultsMode then
          editor.uiIconImage(editor.icons.find_in_page, imVec24x24)
          imgui.SameLine()
          --imgui.Dummy(imgui.ImVec2(5, imgui.GetStyle().ItemSpacing.y))
          local label = tostring(#searchResults) .. ' matches'
          if searchRange > 0 then
            label = label .. ' in ' .. string.format('%g', searchRange) .. 'm'
          end
          imgui.TextUnformatted(label)
        end
      end
    end
    editor.endWindow()
    imgui.PopStyleColor()
  end

  if imgui.IsMouseReleased(0) then
    onClickSelected = false
    clickedOnNode = false
    mouseDragRange = nil
  end

  if hasDragDropPayload then
    selectedNodeTextColor = imgui.ImColorByRGB(0,255,255,150)
    if imgui.IsMouseReleased(0) then
      selectedNodeTextColor = imgui.ImColorByRGB(0,255,255,255)
      hasDragDropPayload = false
    end
  end

  -- disable hover coloring when the cursor is between two items
  disableHoverColor = drewDragSeparator
end

local function onExtensionLoaded()
  log('D', logTag, "initialized")
  local searchTypesComboItemsTbl = {"By Name", "By ID", "By Class", "All"}
  searchTypesComboItems = imgui.ArrayCharPtrByTbl(searchTypesComboItemsTbl)

  editor.addExtendedSceneTreeObjectMenuItem = function(item)
    -- Expected item format:
    -- {
    -- title = string                                               -- required menu item title
    -- onExtendedSceneTreeObjectMenuItemSelected = function(node)   -- function to applu extension behavior on sceneTree
    -- validator = function(node) or nil                            -- optional function to check if menu applicable to sceneTree node
    -- }
    -- No validation for now
    table.insert(extendedSceneTreeObjectMenuItems, item)
  end
end

local function onWindowMenuItem()
  openSceneTree()
end

local function onEditorLoadGuiInstancerState(state)
  guiInstancer:deserialize("scenetreeInstances", state)
  recacheAllNodes()
  for key, instance in pairs(guiInstancer.instances) do
    instance.nameFilter = imgui.ImGuiTextFilter()
    instance.selectedNodes = {}
    instance.windowName = sceneTreeWindowNamePrefix .. key
    editor.registerWindow(instance.windowName, imgui.ImVec2(300, 500))
  end
end

local function onEditorSaveGuiInstancerState(state)
  local instancesCopy = deepcopy(guiInstancer.instances)
  for key, instance in pairs(guiInstancer.instances) do
    instance.nameFilter = nil
    instance.selectedNodes = nil
    instance.rootNode = nil
    instance.scenetreeSize = nil
    instance.currentListIndex = nil
    instance.newListIndex = nil
  end
  guiInstancer:serialize("scenetreeInstances", state)
  guiInstancer.instances = instancesCopy
end

local function onEditorActivated()
  onEditorObjectSelectionChanged()
end

local function onEditorAfterOpenLevel()
  recacheAllNodes()
  for index, instance in pairs(guiInstancer.instances) do
    instance.selectedNodes = {}
    imgui.ImGuiTextFilter_Clear(instance.nameFilter)
    applyFilter(instance, instance.rootNode)
  end
end

local function onEditorInitialized()
  defaultObjectNodeIcon = editor.icons.brightness_1
  objectClassIcons = worldEditorCppApi.getObjectClassIcons()
  recacheAllNodes()
  for index, instance in pairs(guiInstancer.instances) do
    instance.selectedNodes = {}
  end

  editor.onAddObjectToSet = onAddObjectToSet
  editor.onRemoveObjectFromSet = onRemoveObjectFromSet
  editor.onClearObjectsFromSet = onClearObjectsFromSet
  editor.getSelectedSceneTreeNodes = function()
    if tableSize(guiInstancer.instances) then
      --TODO: remove the "0" key, was a wrong decision to use 0-based indices
      if guiInstancer.instances["0"] then
        return guiInstancer.instances["0"].selectedNodes
      else
        return guiInstancer.instances[tostring(guiInstancer.nextInstanceIndex - 1)].selectedNodes
      end
    end
  end
  editor.getSceneTreeSelectedGroup = getSceneTreeSelectedGroup
  editor.refreshSceneTreeWindow = function () recacheAllNodes() end
  editor.addWindowMenuItem("Scene Tree", onWindowMenuItem, nil, true)
  editor.hideAllSceneTreeInstances = function()
    for _, wnd in pairs(guiInstancer.instances) do
      editor.hideWindow(wnd.windowName)
    end
  end
  editor.showAllSceneTreeInstances = function()
    for _, wnd in pairs(guiInstancer.instances) do
      editor.showWindow(wnd.windowName)
    end
  end
  if path.split(getMissionFilename()) then
    prefabSaveFolder = path.split(getMissionFilename()).."art/prefabs/"
  end
end

local function onWindowGotFocus(windowName)
  for index, instance in pairs(guiInstancer.instances) do
    if windowName == sceneTreeWindowNamePrefix .. index then
      editor.selectEditMode(editor.editModes.objectSelect)
      instance.focused = true
      pushActionMap("SceneTree")
      return
    end
  end
end

local function onWindowLostFocus(windowName)
  local allLostFocus = true
  for index, instance in pairs(guiInstancer.instances) do
    if windowName == sceneTreeWindowNamePrefix .. index then
      instance.focused = false
    end
    if instance.focused then
      allLostFocus = false
    end
  end
  if allLostFocus then
    popActionMap("SceneTree")
  end
end

local itemCount = 0
local function setOrder(object)
  local obj = Sim.upcast(object)
  table.insert(editor.orderTable, obj:getId())
  itemCount = itemCount + 1
  local isGroup = obj:isSubClassOf("SimSet") or obj:isSubClassOf("SimGroup")
  if isGroup then
    local count = obj:size() - 1
    for i = 0, count do
      local child = obj:at(i)
      setOrder(child)
    end
  end
end

local function onEditorBeforeSaveLevel()
  itemCount = 0
  local rootGrp = Sim.findObject("MissionGroup")
  editor.orderTable = {}
  if rootGrp then
    setOrder(rootGrp)
  end
end

local function onEditorObjectAdded()
  recacheAllNodes(nil, true)
  for index, instance in pairs(guiInstancer.instances) do
    refreshNodeCache(instance)
  end
end

--TODO: check if we can do the scene tree populate directly with no Lua tables
local function refreshNodeNames(objectIds)
  if not objectIds then return end
  for index, instance in pairs(guiInstancer.instances) do
    local renamer = function(func, node, objectIds)
      if tableContains(objectIds, node.id) then
        local object = scenetree.findObjectById(node.id)
        node.name = getNodeName(object)
        node.displayName = getNodeDisplayName(object)
      end
      if node.isGroup then
        for _, child in ipairs(node.children) do
          func(func, child, objectIds)
        end
      end
    end
    if instance and instance.rootNode then
      renamer(renamer, instance.rootNode, objectIds)
    end
  end
end

local function onEditorInspectorFieldChanged(selectedIds)
  refreshNodeNames(selectedIds)
end

M.onEditorInitialized = onEditorInitialized
M.onEditorActivated = onEditorActivated
M.onEditorGui = onEditorGui
M.onEditorSaveGuiInstancerState = onEditorSaveGuiInstancerState
M.onEditorLoadGuiInstancerState = onEditorLoadGuiInstancerState
M.onExtensionLoaded = onExtensionLoaded
M.onEditorAfterOpenLevel = onEditorAfterOpenLevel
M.onEditorObjectSelectionChanged = onEditorObjectSelectionChanged
M.onEditorToolWindowGotFocus = onWindowGotFocus
M.onEditorToolWindowLostFocus = onWindowLostFocus
M.onEditorBeforeSaveLevel = onEditorBeforeSaveLevel
M.onEditorObjectAdded = onEditorObjectAdded
M.onEditorInspectorFieldChanged = onEditorInspectorFieldChanged

M.moveSelectionIndex = moveSelectionIndex
M.refreshNodeNames = refreshNodeNames

return M