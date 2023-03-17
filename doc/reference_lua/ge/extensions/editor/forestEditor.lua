 -- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local debug = false

local M = {}
local var = {}
local im = ui_imgui
local toolWindowName = "forestEditor"
local editModeName = "Edit Forest"
local colorWhite = ColorF(1,1,1,1)
local colorBlue =  ColorF(0,0,1,0.5)
local colorGreen =  ColorF(0,1,0,0.5)
local colorRed =  ColorF(1,0,0,0.5)
local colorYellow =  ColorF(1,1,0,0.5)

local valueInspector = require("editor/api/valueInspector")()
local objectHistoryActions = require("editor/api/objectHistoryActions")()
local roadRiverGui = extensions.editor_roadRiverGui
local yellow = im.ImVec4(1, 1, 0, 1)
local copyItemsArray = {}

local mouseDragStartPos
local itemsInRect = {}
local forestTable = {}

local selectionCentroid

local isMouseDragging

local deletedItems = {}
local snappedItems = {}
local lastHitPos
local deserializeBrushes = true

local fItemPos = im.ArrayFloat(3)
local fItemRot = im.ArrayFloat(3)
local fieldValueCached = nil

local createForestPopupShown = false

local changeBrushSizeAutoRepeatOn = false
local changeBrushSizeTimer = 0
local changeBrushSizeDirection = 0

local dataBlockNameFilter = im.ImGuiTextFilter()
local noDataBlockString = "<None>"
local noValueString = "<None>"
local clearButtonSize = im.ImVec2(24, 24)
local filteredFieldPopupSize = im.ImVec2(500, 500)
local dataBlocksTbl = {}
local dataBlockNames = {}
local tooltipLongTextLength = 70

local transformToolSettingsOpen = false
local selectionStylePopupPos =  im.ImVec2(0, 0)
local u_32_max_int = 4294967295

var.forestEditorWindowSize = nil
var.forestEditorWindowMinWidth = nil

var.dirtyBrushes = false

var.levelPath = nil
var.style = nil
var.fontSize = nil

-- styling
-- var.buttonColor_active = im.GetStyleColorVec4(im.Col_Button)
var.buttonColor_active = im.GetStyleColorVec4(im.Col_ButtonActive)
var.buttonColor_inactive = im.GetStyleColorVec4(im.Col_Button)

-- initialized in initialize()
local forest = nil
var.forestData = nil
var.forestBrushTool = nil
var.gui3DMouseEvent = nil
var.forestBrushes = nil
var.forestBrushesMap = nil
var.forestBrushElementNames = nil
var.forestItemData = nil
var.tools = nil
var.brushes = nil
var.enum_forestObjType = {forestBrush = 1, forestBrushElement = 2, forestItemData = 3}
-- selected tool or brush
var.selectedTool = nil
var.selectedForestBrushes = nil
var.selectedForestItemDatas = nil
var.enum_toolType = {transformTool = 1, brush = 2}

var.editingObject = nil
var.editingNameCharPtr = nil
var.highlightInputText = false

var.enum_toolMode = {select = 1, translate = 2, rotate = 3, scale = 4, lassoSelect = 5}
var.enum_brushMode = {paint = 0, snap = 1, erase = 2, eraseSelected = 3}
var.enum_lassoSelectMode = {freehand = 0, polyline = 1}

var.transformToolSelectionMode =  var.enum_toolMode.select

var.lassoPLNodes = {}
var.lassoPLLineSegments = {}
var.lassoHoveredNodeIndex = nil
var.lassoPLSelectedNodeIndex = nil
var.lassoFHLastMousePos = nil
var.lassoFHLineSegments = {}
var.lassoSelectionEnded = false
var.lassoSelectionItemsCalculated = false
var.mouseButtonHeldOnPLLassoNode = false
var.lassoSelectMode = var.enum_lassoSelectMode.freehand

var.enum_tabType = {brushes = 1, meshes = 2}
var.selectedTab = var.enum_tabType.brushes

var.meshPreview = ShapePreview()
var.meshPreviewDimRdr = RectI(0,0,256,256)
var.meshPreviewRenderSize = {256,256}

var.legendCurrentActionNames = {}

-- Debug
M.dumpForestBrushes = function()
  print("###### Forest Brushes #####")
  dump(var.forestBrushes)
  print("###### Forest Brushes End #####")
end

M.dumpForestBrushesMap = function()
  print("###### Forest Brushes Map #####")
  dump(var.forestBrushesMap)
  print("###### Forest Brushes Map End #####")
end

M.dumpBrushProperties = function()
  print("##### Brush Properties #####")
  print("Size: " .. tostring(var.forestBrushTool:getSize()))
  print("Pressure: " .. tostring(var.forestBrushTool:getPressure()))
  print("Hardness: " .. tostring(var.forestBrushTool:getHardness()))
  print("##### Brush Properties End #####")
end
-- // Debug

local forestItemSortByNameFunc = function(a, b)
  local aObj = scenetree.findObjectById(a.id)
  local bObj = scenetree.findObjectById(b.id)
  return string.lower(aObj.internalName or "unnamed") < string.lower(bObj.internalName or "unnamed")
end

local forestBrushElemSortByNameFunc = function(a, b)
  local aObj = scenetree.findObjectById(a.id)
  local bObj = scenetree.findObjectById(b.id)
  return string.lower(aObj.internalName) < string.lower(bObj.internalName)
end

local function updateAutoRepeatChangeBrushSize()
  changeBrushSizeTimer = changeBrushSizeTimer + editor.getDeltaTime()
  if changeBrushSizeTimer >= editor.getPreference("forestEditor.general.brushSizeChangeIntervalWithKeys") then
    changeBrushSizeTimer = 0
    editor_forestEditor.changeBrush(changeBrushSizeDirection, editor.getPreference("forestEditor.general.brushSizeChangeStepWithKeys"))
  end
end

local function updateCentroid()
  selectionCentroid = vec3(0, 0, 0)
  local bbox = Box3F()
  bbox:setExtents(vec3(-1e10 - 1e10, -1e10 - 1e10, -1e10 - 1e10))
  bbox:setCenter(vec3(0, 0, 0))

  if not editor.selection.forestItem[1] then
    return
  end

  for _, item in ipairs(editor.selection.forestItem) do
    local obj = var.forestData:getItem(item:getKey(), item:getPosition())
    if obj and obj.getTransform then
      local mat = obj:getTransform()
      local wPos = mat:getColumn(3)

      selectionCentroid.x = selectionCentroid.x + wPos.x
      selectionCentroid.y = selectionCentroid.y + wPos.y
      selectionCentroid.z = selectionCentroid.z + wPos.z

      local objBounds = obj:getWorldBox()
      bbox:extend(objBounds.minExtents)
      bbox:extend(objBounds.maxExtents)
    end
  end

  local numObjects = tableSize(editor.selection.forestItem)
  selectionCentroid.x = selectionCentroid.x / numObjects;
  selectionCentroid.y = selectionCentroid.y / numObjects;
  selectionCentroid.z = selectionCentroid.z / numObjects;
end

local function selectForestItems(forestItems, addToSelection)
  if not addToSelection or not editor.selection or not editor.selection.forestItem then
    editor.selection = {}
    editor.selection.forestItem = {}
  end
  if not forestItems then return end

  for _, item in ipairs(forestItems) do
    table.insert(editor.selection.forestItem, item)
  end

  if table.getn(forestItems) > 0 then
    updateCentroid()
  end

  if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local and #forestItems == 1 then
    editor.setAxisGizmoTransform(forestItems[1]:getTransform(), vec3(1,1,1))
  else
    local mat = MatrixF(true)
    mat:setColumn(3, selectionCentroid)
    editor.setAxisGizmoTransform(mat, vec3(1,1,1))
  end

  if not tableIsEmpty(editor.selection.forestItem) then
    local shapeFilename = tostring(editor.selection.forestItem[#editor.selection.forestItem]:getData().shapeFile)
    var.meshPreview:setObjectModel(shapeFilename)
    var.meshPreview:fitToShape()
    var.meshPreview:setRenderState(false,false,false,false,false,true)
  end

  extensions.hook("onEditorObjectSelectionChanged")
end

-- Add Items
local function addItemsActionUndo(actionData)
  for _, item in ipairs(actionData.items) do
    editor.removeForestItem(var.forestData, item)
  end
  selectForestItems()
end

local function addItemsActionRedo(actionData)
  for _, item in ipairs(actionData.items) do
    editor.addForestItem(var.forestData, item)
  end
  if var.lassoSelectionEnded and var.lassoSelectionItemsCalculated then
    var.lassoSelectionItemsCalculated = false
  end
end

local function addItems(items, dontCallRedo)
  if dontCallRedo == nil then dontCallRedo = false end
  return editor.history:commitAction("AddForestItems", {items = items}, addItemsActionUndo, addItemsActionRedo, dontCallRedo)
end

-- Remove Items
local removeItemsActionUndo = addItemsActionRedo
local removeItemsActionRedo = addItemsActionUndo

local function removeItems(items, dontCallRedo)
  if tableIsEmpty(items) then return end
  if dontCallRedo == nil then dontCallRedo = false end
  return editor.history:commitAction("RemoveForestItems", {items = items}, removeItemsActionUndo, removeItemsActionRedo, dontCallRedo)
end

-- Set item transform
local function setItemTransformUndo(actionData)
  for index, item in ipairs(actionData.items) do
    actionData.items[index] = editor.updateForestItem(var.forestData, item:getKey(), item:getPosition(), item:getData(), editor.tableToMatrix(actionData.oldTransforms[index]), actionData.oldScales[index])
  end
  if var.selectedTool.type == var.enum_toolType.transformTool then
    selectForestItems(actionData.items)
  end
end

local function setItemTransformRedo(actionData)
  for index, item in ipairs(actionData.items) do
    actionData.items[index] = editor.updateForestItem(var.forestData, item:getKey(), item:getPosition(), item:getData(), editor.tableToMatrix(actionData.newTransforms[index]), actionData.newScales[index])
  end
  if var.selectedTool.type == var.enum_toolType.transformTool then
    selectForestItems(actionData.items)
  end
end

local function updateLegendCurrentActionNames(toolType)
  if toolType == var.enum_toolMode.lassoSelect then
    var.legendCurrentActionNames[bit.bor(editor.AuxControl_LMB, editor.AuxControl_Alt)] = "Add Polyline Lasso Node"
    var.legendCurrentActionNames["LMB Drag"] = "Draw Freehand Lasso"
    var.legendCurrentActionNames["esc"] = "Clear Current Lasso"
  else
    var.legendCurrentActionNames= {}
  end
end

-- ##### FUNCTIONS #####

-- selects a tool or brush
local function selectTool(tool)
  var.legendCurrentActionNames = {}
  if var.selectedTool then
    if (var.selectedTool.type ~= tool.type) then
      if (var.selectedTool.type == var.enum_toolType.transformTool) then
        if #var.selectedForestBrushes == 1 then
          editor.selectObjectById(var.selectedForestBrushes[1].id) -- Select the brush again that was selected before
        end
        editor.selection.forestItem = {}
      end
      if (tool.type == var.enum_toolType.transformTool) then
        editor.selection = {}
        if var.transformToolSelectionMode == var.enum_toolMode.lassoSelect then
          updateLegendCurrentActionNames(var.transformToolSelectionMode)
          if var.lassoSelectionEnded and var.lassoSelectionItemsCalculated then
            var.lassoSelectionItemsCalculated = false
          end
        end
      end
      extensions.hook("onEditorEditModeChanged", nil, nil)
    end
  end

  if (tool.type == var.enum_toolType.brush) then
    editor.showWindow(toolWindowName)
  end

  if tool.fn then
    tool.fn()
  end

  var.selectedTool = tool
  var.forestBrushTool.mode = tool.mode
end


local function selectToolByName(toolName)
  for _, tool in ipairs(var.tools) do
    if tool.label == toolName then
      selectTool(tool)
      return
    end
  end

  for _, brush in ipairs(var.brushes) do
    if brush.label == toolName then
      selectTool(brush)
      return
    end
  end

  log('W', '', "Cannot find tool with name '" .. toolName .. "'!")
end

local function toggleForestBrushTreeNode(forestBrush)
  forestBrush.open = not forestBrush.open
end

local function selectForestBrush(item, addToSelection)
  editor.selection = {}
  if addToSelection then
    item.selected = not item.selected
  else
    for k, brush in ipairs(var.selectedForestBrushes) do
      brush.selected = false
    end
    var.selectedForestBrushes = {}
    item.selected = true
  end

  if item.selected then
    table.insert(var.selectedForestBrushes, item)
  else
    for i, brush in ipairs(var.selectedForestBrushes) do
      if brush.id == item.id then
        table.remove(var.selectedForestBrushes, i)
        break
      end
    end
  end

  if var.editingObject then
    var.editingObject = nil
  end

  if tableSize(var.selectedForestBrushes) == 1 then
    editor.selectObjectById(var.selectedForestBrushes[1].id)
    local obj = scenetree.findObjectById(var.selectedForestBrushes[1].id)
    local shapeFilename = ""

    if obj and obj.getClassName and obj:getClassName() == "ForestBrushElement" and obj.forestItemData then
      local forestItemData = Sim.findObjectByIdNoUpcast(dataBlocksTbl[obj.forestItemData:getName()])
      if forestItemData then
        shapeFilename = tostring(forestItemData.shapeFile)
      end
    end

    var.meshPreview:setObjectModel(shapeFilename)
    var.meshPreview:fitToShape()
    var.meshPreview:setRenderState(false,false,false,false,false,true)
  end
end

local function selectForestItemData(item, addToSelection)
  editor.selection = {}
  if addToSelection then
    item.selected = not item.selected
  else
    for _, mesh in ipairs(var.selectedForestItemDatas) do
      mesh.selected = false
    end
    var.selectedForestItemDatas = {}
    item.selected = true
  end

  if item.selected then
    table.insert(var.selectedForestItemDatas, item)
  else
    for i, itemData in ipairs(var.selectedForestItemDatas) do
      if itemData.id == item.id then
        table.remove(var.selectedForestItemDatas, i)
        break
      end
    end
  end

  if var.editingObject then
    var.editingObject = nil
  end

  if tableSize(var.selectedForestItemDatas) == 1 then
    editor.selectObjectById(var.selectedForestItemDatas[1].id)
    local obj = scenetree.findObjectById(var.selectedForestItemDatas[1].id)
    local shapeFilename = ""

    if obj then
      shapeFilename = tostring(obj.shapeFile)
      var.meshPreview:setObjectModel(shapeFilename)
      var.meshPreview:fitToShape()
      var.meshPreview:setRenderState(false,false,false,false,false,true)
    end
  end
end

local function initializeDataBlockTables()
  local grp = Sim.getDataBlockSet()
  dataBlocksTbl = {}
  dataBlockNames = {}
  if not grp then return end
  for i = 0, grp:size() - 1 do
    local obj = grp:at(i)
    if obj and obj:getName() ~= "" then
      -- the data block names are unique across all data block types, no need to check if duplicate already added
      dataBlocksTbl[obj:getName()] = obj:getId()
      table.insert(dataBlockNames, obj:getName())
    end
  end
  table.sort(dataBlockNames)
  table.insert(dataBlockNames, 1, noDataBlockString)
end

local function removeItemRedo(actionData)
  local item = actionData.item
  if item.parentBrush then
    -- Remove brush element from the brushes element list
    for i, element in ipairs(item.parentBrush.elements) do
      if element.id == item.id then
        actionData.brushElementIndex = i
        table.remove(item.parentBrush.elements, i)
        var.forestBrushElementNames[item.internalName] = nil
        break
      end
    end
  end

  for i, brush in ipairs(var.forestBrushes) do
    if brush.id == item.id then
      actionData.forestBrushesIndex = i
      table.remove(var.forestBrushes, i)
      break
    end
  end

  for i, otherItem in ipairs(var.forestItemData) do
    if item.id == otherItem.id then
      actionData.forestItemDataIndex = i
      table.remove(var.forestItemData, i)
      break
    end
  end
  table.sort(var.forestItemData, forestItemSortByNameFunc)
  initializeDataBlockTables()
end

local function removeItemUndo(actionData)
  local item = actionData.item
  if item.parentBrush and actionData.brushElementIndex then
    table.insert(item.parentBrush.elements, actionData.brushElementIndex, item)
    table.sort(item.parentBrush.elements, forestBrushElemSortByNameFunc)
  end

  if actionData.forestBrushesIndex then
    table.insert(var.forestBrushes, actionData.forestBrushesIndex, item)
    selectForestBrush(item)
  end

  if actionData.forestItemDataIndex then
    table.insert(var.forestItemData, actionData.forestItemDataIndex, item)
    table.sort(var.forestItemData, forestItemSortByNameFunc)
    selectForestItemData(item)
  end

  initializeDataBlockTables()
end

local addItemRedo = removeItemUndo
local addItemUndo = removeItemRedo

local function forestBrushesHasBrush(name)
  if var.forestBrushes == nil then
    var.forestBrushes = {}
  end
  for _, fb in ipairs(var.forestBrushes) do
    if fb.internalName == name then
      return true
    end
  end
  return false
end

local function getUniqueForestBrushInternalName()
  local name = "Brush"
  local incr = -1
  while forestBrushesHasBrush(name) == true do
    incr = incr + 1
    name = "Brush" .. tostring(incr)
  end
  return name
end

local function forestBrushElementHasBrush(name)
  return var.forestBrushElementNames and var.forestBrushElementNames[name]
end

local function getUniqueForestBrushElementInternalName()
  local name = "Element"
  local incr = -1
  while forestBrushElementHasBrush(name) == true do
    incr = incr + 1
    name = "Element" .. tostring(incr)
  end
  return name
end

local function newForestBrush()
  if not var.forestBrushGroup then
    log("E", "", "There is no forestBrushGroup to add the forest brush to.")
    editor.openModalWindow("noForestBrushGroupMsgDlg")
    return
  end
  local fb = ForestBrush()
  local internalName = getUniqueForestBrushInternalName()
  fb:setName(Sim.getUniqueName("ForestBrush_" .. internalName))
  fb:setInternalName(internalName)
  fb:registerObject(fb:getName())
  var.forestBrushGroup:add(fb)

  local item = {
    id = fb:getId(),
    internalName = internalName,
    type = var.enum_forestObjType.forestBrush,
    elements = {},
    open = false,
    selected = false
  }

  table.insert(var.forestBrushes, item)
  var.forestBrushesMap[item.internalName] = (var.forestBrushGroup:size())

  selectForestBrush(item)

  var.dirtyBrushes = true
  editor.setDirty()
  table.sort(var.forestBrushes, forestBrushElemSortByNameFunc)
end

local function newForestBrushElement()
  local fbe = ForestBrushElement()
  local internalName = Sim.getUniqueName(getUniqueForestBrushElementInternalName())

  fbe:setInternalName(internalName)
  fbe:registerObject("")

  local group

  -- Check if any of the selected items is a ForestBrush.
  for i = #var.selectedForestBrushes, 1, -1 do
    if var.selectedForestBrushes[i].type == var.enum_forestObjType.forestBrush then
      group = var.selectedForestBrushes[i]
      group.open = true
      break
    end
  end

  local element = {
    id = fbe:getId(),
    internalName = internalName,
    type = var.enum_forestObjType.forestBrushElement,
    selected = false
  }

  -- Add to the selected ForestBrush.
  if group then
    local obj = scenetree.findObjectById(group.id)
    if obj then
      table.insert(group.elements, element)
      obj:add(fbe)
      element.parentBrush = group
      table.sort(element.parentBrush.elements, forestBrushElemSortByNameFunc)
    end
  -- There is no ForestBrush selected, add the element to the ForestBrushGroup object.
  elseif var.forestBrushGroup then
    if var.forestBrushes == nil then
      var.forestBrushes = {}
    end
    table.insert(var.forestBrushes, element)
    var.forestBrushGroup:add(fbe)
    table.sort(var.forestBrushes, forestBrushElemSortByNameFunc)
  end

  if var.forestBrushElementNames == nil then
    var.forestBrushElementNames = {}
  end
  var.forestBrushElementNames[internalName] = true

  var.dirtyBrushes = true
  editor.setDirty()
end

local function newForestItemData(data)
  local name = Sim.getUniqueName(data.filename:match("(.+)%."))
  local objId = editor.createDataBlock(name, "TSForestItemData", nil, editor.levelPath .. "art/forest/managedItemData.json")
  local obj = scenetree.findObjectById(objId)
  obj:setName(name)
  obj:setInternalName(name)
  obj:setField('shapeFile', '', data.filepath)
  local item = {
    pos = #var.forestItemData + 1,
    id = obj:getId(),
    dirty = false,
    type = var.enum_forestObjType.forestItemData,
    selected = false
  }
  table.insert(var.forestItemData, item)
  table.sort(var.forestItemData, forestItemSortByNameFunc)
  editor.setDirty()
  valueInspector:initializeTables(true)
  selectForestItemData(item)

  editor.history:beginTransaction("CreateForestItemData")
  editor.history:commitAction("CreateItem", {objectId = item.id}, objectHistoryActions.deleteObjectRedo, objectHistoryActions.deleteObjectUndo)
  editor.history:commitAction("AddItem", {item = item}, addItemUndo, addItemRedo)
  editor.history:endTransaction(true)
  initializeDataBlockTables()
end
-- ##### FUNCTIONS END #####

local function castRayDown(startPoint, endPoint)
  if not endPoint then
    endPoint = startPoint - vec3(0,0,100)
  end
  local res = Engine.castRay((startPoint + vec3(0,0,1)), endPoint, true, false)
  if not res then
    res = Engine.castRay((startPoint + vec3(0,0,100)), (startPoint - vec3(0,0,1000)), true, false)
  end
  return res
end

-- ##### DRAGGING FUNCTIONS #####
local objectHeights = {}
local originalTransforms = {}
local originalTransformsLua = {}
local originalScales = {}
local dragAndDuplicate
local duplicationDrag

local function gizmoBeginDrag()
  objectHeights = {}
  originalTransforms = {}
  originalTransformsLua = {}
  originalScales = {}

  local objectBBs = {}
  for index, item in ipairs(editor.selection.forestItem) do
    table.insert(originalTransforms, item:getTransform())
    table.insert(originalTransformsLua, editor.matrixToTable(item:getTransform()))
    table.insert(objectBBs, item:getWorldBox())
    table.insert(objectHeights, item:getObjBox().maxExtents.z)
    table.insert(originalScales, item:getScale())
  end

  -- lets check if we want to drag and duplicate the selection
  local shiftDown = editor.keyModifiers.shift
  if shiftDown and editor.selection.forestItem[1] then
    dragAndDuplicate = true
  end

  if editor.getAxisGizmoMode() == editor.AxisGizmoMode_Translate then
    editor.beginGizmoTranslate(originalTransforms, objectBBs, objectHeights, forestTable)
  end
end

local function gizmoDragging()
  if dragAndDuplicate and editor.keyModifiers.shift then
    -- ok, we duplicate
    dragAndDuplicate = false
    duplicationDrag = true
    editor.duplicate()
  end
  if var.selectedTool.type == var.enum_toolType.transformTool then
    -- translating
    if editor.getAxisGizmoMode() == editor.AxisGizmoMode_Translate then
      local newTransforms = editor.getTransformsGizmoTranslate(forestTable, objectHeights)
      for index, transform in ipairs(newTransforms) do
        local item = editor.selection.forestItem[index]
        editor.selection.forestItem[index] = editor.updateForestItem(var.forestData, item:getKey(), item:getPosition(), item:getData(), transform, item:getScale())
      end

    -- rotation
    elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Rotate then
      local delta = vec3(worldEditorCppApi.getAxisGizmoTotalRotateOffset())
      editor.rotateForestSelection(var.forestData, delta, selectionCentroid, originalTransforms)

    -- scaling
    elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Scale then
      for index, obj in ipairs(editor.selection.forestItem) do
        local delta = vec3(worldEditorCppApi.getAxisGizmoScaleOffset())
        local mul = (delta.x < 0) and -1 or ((delta.y < 0) and -1 or (delta.z < 0 and -1 or 1))
        local deltaMax = math.max(math.abs(delta.x), math.abs(delta.y), math.abs(delta.z))
        -- clamp the deltaMax value
        deltaMax = math.min(deltaMax, 0.1) * mul
        local scale = obj:getScale() + deltaMax
        if obj then
          editor.selection.forestItem[index] = editor.updateForestItem(var.forestData, obj:getKey(), obj:getPosition(), obj:getData(), obj:getTransform(), scale)
        end
      end
    end
  end
end

local function gizmoEndDrag()
  local newTransforms = {}
  local newScales = {}
  for index, item in ipairs(editor.selection.forestItem) do
    table.insert(newTransforms, editor.matrixToTable(item:getTransform()))
    table.insert(newScales, item:getScale())
  end

  if duplicationDrag then
    addItems(editor.selection.forestItem, true)
    duplicationDrag = false
  else
    editor.history:commitAction("SetForestItemTransform", {items = editor.selection.forestItem, newTransforms = newTransforms, oldTransforms = originalTransformsLua, newScales = newScales, oldScales = originalScales}, setItemTransformUndo, setItemTransformRedo)
  end
end
-- ##### DRAGGING FUNCTIONS END #####

local function setDirty(item)
  editor.setDirty()
  if item.type == var.enum_forestObjType.forestBrushElement then
    var.dirtyBrushes = true
  end
  item.dirty = true
end

-- ##### INSPECTOR GUI #####
local function inspectorField_String(key, value)
  im.TextUnformatted(key)
  im.NextColumn()
  im.TextUnformatted(value)
  im.NextColumn()
end

local function forestItemScaleActionUndo(actionData)
  local forestItem = nil
  for _, item in ipairs(var.forestData:getItems()) do
    if item:getKey() == actionData.itemKey then
      forestItem = item
      break
    end
  end
  if forestItem then
    forestItem:setScale(actionData.oldScale)
    editor.selection.forestItem[1] = editor.updateForestItem(var.forestData, forestItem:getKey(), forestItem:getPosition(), forestItem:getData(), forestItem:getTransform(), actionData.oldScale)
  end
end

local function forestItemScaleActionRedo(actionData)
  local forestItem = nil
  for _, item in ipairs(var.forestData:getItems()) do
    if item:getKey() == actionData.itemKey then
      forestItem = item
      break
    end
  end
  if forestItem then
    forestItem:setScale(actionData.newScale)
    editor.selection.forestItem[1] = editor.updateForestItem(var.forestData, forestItem:getKey(), forestItem:getPosition(), forestItem:getData(), forestItem:getTransform(), actionData.newScale)
  end
end

local PI = 3.14159265358979323846

local function degToRad(d)
  return (d * PI) / 180.0
end

local function radToDeg(r)
  return (r * 180.0) / PI;
end

local function assetInspectorGuiForestItem(inspectorInfo)
  if editor.selection.forestItem[1] then
    local item = editor.selection.forestItem[1]
    im.TextUnformatted("ForestItem")
    im.Columns(2)
    inspectorField_String("key", tostring(item:getKey()))
    -- im.Columns(1)
    if item:getKey() == 0 then
      im.TextColored(im.ImVec4(1.0, 0.0, 0.0, 1.0), 'Invalid item!')
      return
    end
    im.TextUnformatted("Position")
    im.NextColumn()
    local posItem = item:getPosition()
    fItemPos[0] = posItem.x
    fItemPos[1] = posItem.y
    fItemPos[2] = posItem.z
    if im.InputFloat3("##Position", fItemPos, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
      posItem.x = fItemPos[0]
      posItem.y = fItemPos[1]
      posItem.z = fItemPos[2]
      item:setPosition(posItem)
    end
    im.NextColumn()
    im.TextUnformatted("Rotation")
    im.NextColumn()
    local eulerRotation = item:getTransform():toEuler()
    fItemRot[0] = radToDeg(eulerRotation.x)
    fItemRot[1] = radToDeg(eulerRotation.y)
    fItemRot[2] = radToDeg(eulerRotation.z)
    if im.InputFloat3("##Rotation", fItemRot, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
      eulerRotation.x = degToRad(fItemRot[0])
      eulerRotation.y = degToRad(fItemRot[1])
      eulerRotation.z = degToRad(fItemRot[2])
      local transform = MatrixF(true)
      transform:setFromEuler(vec3(eulerRotation.x, eulerRotation.y, eulerRotation.z))
      transform:setPosition(item:getPosition())
      editor.history:commitAction("RotateForestItem",
            {items = {item}, newTransforms = {editor.matrixToTable(transform)},
            oldTransforms = {editor.matrixToTable(item:getTransform())},
            newScales = {item:getScale()}, oldScales = {item:getScale()}},
            setItemTransformUndo, setItemTransformRedo)
    end
    im.NextColumn()
    -- im.TextUnformatted("Pos : "..tostring (item:getPosition()))
    im.TextUnformatted("Scale")
    im.NextColumn()
    im.PushItemWidth(im.GetContentRegionAvailWidth())
    local editEnded = im.BoolPtr(false)
    local scaleFL = im.FloatPtr(item:getScale())
    if editor.uiInputFloat("##forestitemscale", scaleFL, 0.01, 2, "%1.2f", nil, editEnded) then
      fieldValueCached = scaleFL[0]
    end
    if editEnded[0] == true then
      editor.history:commitAction("ScaleForestItem", {itemKey = item:getKey(), oldScale = item:getScale(), newScale = fieldValueCached or scaleFL[0]}, forestItemScaleActionUndo, forestItemScaleActionRedo)
    end
    im.PopItemWidth()
    im.NextColumn()
    --inspectorField_String("Scale", tostring(item:getScale()))

    -- im.TextUnformatted("Tr : "..tostring (item:getTransform()))
    -- el = item:getTransform():toEuler()
    -- im.TextUnformatted("Tr el: "..tostring (el))
    inspectorField_String("Shape", tostring(item:getData():getShapeFile()))

    im.Columns(1)
    if im.Button("Select ForestItemData") then
      for _, forestItemData in ipairs(var.forestItemData) do
        local forestItemDataId = item:getData():getID()
        if forestItemDataId == forestItemData.id then
          selectForestItemData(forestItemData)
          return
        end
      end
    end

    local size = im.GetContentRegionAvailWidth()
    var.meshPreviewDimRdr.point = Point2I(0, 0)
    var.meshPreviewDimRdr.extent = Point2I(size,size)
    var.meshPreviewRenderSize[1] = size
    var.meshPreviewRenderSize[2] = size
    var.meshPreview:renderWorld(var.meshPreviewDimRdr)
    im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(0,0))
    if im.BeginChild1("MeshPreviewChild", im.ImVec2(size,size), true, im.WindowFlags_NoScrollWithMouse) then
      var.meshPreview:ImGui_Image(var.meshPreviewRenderSize[1],var.meshPreviewRenderSize[2])
      im.EndChild()
    end
    im.PopStyleVar()
  end
end
-- ##### INSPECTOR GUI END #####

-- ##### GUI TOOLBAR #####
local function sliderFloat(text, id, val, vmin, vmax, format, power, editEnded, fn, tooltip, mouseWheelPower)
  im.TextUnformatted(text)
  im.SameLine()
  local res = editor.uiSliderFloat(id, val, vmin, vmax, format, power, editEnded)
  if tooltip then
    im.tooltip(tooltip)
  end
  return res
end

local function setBrushSize()
  var.forestBrushTool:setSize(editor.getPreference("forestEditor.general.brushSize") / 2)
end

local function setBrushPressure()
  var.forestBrushTool:setPressure(editor.getPreference("forestEditor.general.brushPressure") / 100)
end

local function setBrushHardness()
  var.forestBrushTool:setHardness(editor.getPreference("forestEditor.general.brushHardness") / 100)
end

local function changeBrushSize(value, step)
  if value == 1 then
    editor.setPreference("forestEditor.general.brushSize", editor.getPreference("forestEditor.general.brushSize") + step)
  elseif value == 0 then
    editor.setPreference("forestEditor.general.brushSize", editor.getPreference("forestEditor.general.brushSize") - step)
  end

  if value == 1 or value == 0 then
    editor.setPreference("forestEditor.general.brushSize", clamp(editor.getPreference("forestEditor.general.brushSize"), 1, 150))
    setBrushSize()
  end
end

local function changeBrushPressure(value, step)
  if value == 1 then
    editor.setPreference("forestEditor.general.brushPressure", editor.getPreference("forestEditor.general.brushPressure") + step)
  elseif value == 0 then
    editor.setPreference("forestEditor.general.brushPressure", editor.getPreference("forestEditor.general.brushPressure") - step)
  end

  if value == 1 or value == 0 then
    editor.setPreference("forestEditor.general.brushPressure", clamp(editor.getPreference("forestEditor.general.brushPressure"), 1, 100))
    setBrushPressure()
  end
end

local function changeBrush(value, step)
  if editor.keyModifiers.ctrl then
    changeBrushPressure(value, step)
  else
    changeBrushSize(value, step)
  end
end

-- draws a tool's icon to the toolbar
local function toolbarToolIcon(tool, type)
  if tool.disabled == true then
    im.BeginDisabled()
  end
  local bgColor = (tool == var.selectedTool) and im.GetStyleColorVec4(im.Col_ButtonActive) or nil
  if editor.uiIconImageButton(tool.icon, nil, nil, nil, bgColor, tool.label) then
    selectTool(tool, type)
  end
  im.tooltip(tool.tooltip)
  im.SameLine()
  if tool.disabled == true then
    im.EndDisabled()
  end
  if tool.type == var.enum_toolType.transformTool and im.IsItemHovered() and im.IsMouseClicked(1) then
    transformToolSettingsOpen = not transformToolSettingsOpen
    selectionStylePopupPos = im.ImVec2(im.GetWindowPos().x + im.GetCursorPosX(), im.GetWindowPos().y + im.GetCursorPosY() + 30)
  end
end


-- ##### GUI TOOLBAR END #####

-- ##### INITIALIZE #####
local function initializeForestBrushes()
  -- Dont delete brushes if lua was just reloaded
  if deserializeBrushes then
    -- Destroy all existing ForestBrushElements before creating the ones from the main.forestbrush4.json
    -- file.
    local objNames = scenetree.findClassObjects("ForestBrushElement")
    for _, id in ipairs(objNames) do
      local obj = scenetree.findObject(id)
      if obj then
        obj:delete()
      end
    end

    -- -- Also we have to delete the ForestBrush cause there might be remnants from old cs files.
    objNames = scenetree.findClassObjects("ForestBrush")
    for _, id in ipairs(objNames) do
      local obj = scenetree.findObject(id)
      if obj then
        obj:delete()
      end
    end
  end

  -- ForestItemData
  local forestItemDataNames = scenetree.findClassObjects("TSForestItemData")
  var.forestItemData = {}
  for k, forestItemDataId in ipairs(forestItemDataNames) do
    local cobj = scenetree.findObject(forestItemDataId)
    if cobj then
      local item = {
        pos = k,
        id = cobj:getId(),
        dirty = false,
        type = var.enum_forestObjType.forestItemData,
        selected = false
      }
      table.insert(var.forestItemData, item)
    end
  end

  if deserializeBrushes then
    -- Instantiate ForestBrush objects
    local brushPath = var.levelPath .. "/main.forestbrushes4.json"
    if FS:fileExists(brushPath) then
      Sim.deserializeLineObjects(brushPath, true)
    else
      log("W", "", "There's no forest brushes file.")
    end
  end
  deserializeBrushes = true

  -- ForestBrushGroup
  var.forestBrushGroup = scenetree.findObject("ForestBrushGroup")
  if not var.forestBrushGroup then
    log('W', '', "There's no ForestBrushGroup object.")
    return
  end
  -- ~ForestBrushGroup

  -- ForestBrushes
  var.forestBrushElementNames = {}

  var.forestBrushes = {}
  var.forestBrushesMap = {}
  for i = 0, var.forestBrushGroup:size() - 1 do
    local obj = var.forestBrushGroup:at(i)
    local internalName = obj:getInternalName()
    if internalName then
      local item = {
        id = obj:getId(),
        internalName = internalName,
        type = (obj:getClassName() == "ForestBrush") and var.enum_forestObjType.forestBrush or var.enum_forestObjType.forestBrushElement,
        elements = {},
        open = false,
        selected = false
      }
      table.insert(var.forestBrushes, item)
      var.forestBrushesMap[item.internalName] = (i+1)

      if item.type == var.enum_forestObjType.forestBrushElement then
        var.forestBrushElementNames[internalName] = true
      end
    end
  end
  -- ~ForestBrushes

  -- ForestBrushElements
  local forestBrushElementIds = scenetree.findClassObjects("ForestBrushElement")
  for _, id in ipairs(forestBrushElementIds) do
    local fbe = scenetree.findObject(id)
    if fbe then
      local group = fbe:getGroup():getInternalName()
      local fbeName = fbe:getInternalName()

      if group and var.forestBrushesMap[group] then
        table.insert(var.forestBrushes[var.forestBrushesMap[group]].elements, {
          id = fbe:getId(),
          internalName = fbeName,
          type = var.enum_forestObjType.forestBrushElement,
          selected = false,
          parentBrush = var.forestBrushes[var.forestBrushesMap[group]]
        })
        table.sort(var.forestBrushes[var.forestBrushesMap[group]].elements, forestBrushElemSortByNameFunc)
      else
        -- todo: check if the object is already instantiated
      end

      var.forestBrushElementNames[fbeName] = true
    else
      editor.logWarn("Missing forest brush element ID: " .. tostring(id))
    end
  end
  -- ~ForestBrushElements

  table.sort(var.forestBrushes, function(a,b) return string.lower(a.internalName) < string.lower(b.internalName) end)
  table.sort(var.forestItemData, forestItemSortByNameFunc)
end

local function initialize()
  var.levelPath = '/levels/'
  local i = 1
  for str in string.gmatch(getMissionFilename(),"([^/]+)") do
    if i == 2 then
      var.levelPath = var.levelPath .. str
    end
    i = i + 1
  end

  var.forestBrushTool = ForestBrushTool()

  -- get the Forest object
  forest = core_forest.getForestObject()
  forestTable[1] = forest
  if forest then
    var.forestData = forest:getData()
    var.forestBrushTool:setActiveForest(forest)
  else
    log('I', '', "There's no Forest object.")
  end

  var.gui3DMouseEvent = Gui3DMouseEvent()

  --initialize tools
  var.tools = {
    {
      label = "select",
      type = var.enum_toolType.transformTool,
      tooltip = "Select Item. Right click for options.",
      description = "Select forest items",
      icon = editor.icons.forest_select,
      mode = var.enum_toolMode.select
    }
  }

  --initialize brushes
  var.brushes = {
    {
      label = "paint",
      type = var.enum_toolType.brush,
      tooltip = "Paint",
      description = "Paint Tool - This brush creates Items based on Elements you have selected.",
      icon = editor.icons.forest_paint,
      mode = var.enum_brushMode.paint
    },
    {
      label = "erase",
      type = var.enum_toolType.brush,
      tooltip = "Erase",
      description = "Erase Tool - This brush erases Items of any Mesh type.",
      icon = editor.icons.forest_erase,
      mode = var.enum_brushMode.erase,
      destructive = true
    },
    {
      label = "eraseSelected",
      type = var.enum_toolType.brush,
      tooltip = "Erase Selected",
      description = "Erase Selected Tool - This brush erases Items based on the Elements you have selected.",
      icon = editor.icons.forest_erase_selected,
      mode = var.enum_brushMode.eraseSelected,
      destructive = true
    },
    {
      label = "snap",
      type = var.enum_toolType.brush,
      tooltip = "Snap To Terrain",
      description = "Snap To Terrain Tool - This brush snaps selected ForestItems to the TerrainBlock.",
      icon = editor.icons.forest_snap_terrain,
      mode = var.enum_brushMode.snap
    }
  }

  initializeForestBrushes()

  var.selectedForestBrushes = {}
  var.selectedForestItemDatas = {}
  if not var.selectedTool then
    selectToolByName("paint")
  end
end
-- ##### INITIALIZE END #####

local function createForestBrushGroup(createNewBrush)
  var.forestBrushGroup = worldEditorCppApi.createObject("SimGroup")
  var.forestBrushGroup:registerObject("")
  var.forestBrushGroup:setName("ForestBrushGroup")
  scenetree.LevelLoadingGroup:addObject(var.forestBrushGroup)
  initializeForestBrushes()
  if createNewBrush then
    newForestBrush()
  end
  editor.setDirty()
end

local function createForestObject()
  if not forest then
    forest = worldEditorCppApi.createObject("Forest")
    forest:registerObject("")
    forest:setName("theForest")
    scenetree.MissionGroup:addObject(forest)
    createForestBrushGroup()
    editor.setDirty()
  end
end

local function forestToolsEditModeToolbar()
  -- draw toolbar icons for the tools
  for _, tool in ipairs(var.tools) do
    toolbarToolIcon(tool)
  end

  if transformToolSettingsOpen then
    local transformTool = nil

    for _, tool in ipairs(var.tools) do
      if tool.type == var.enum_toolType.transformTool then
        transformTool = tool
        break
      end
    end

    if transformTool then
      local selectionModeChanged = false
      local selectionModeValue = im.IntPtr(0)
      if var.transformToolSelectionMode == var.enum_toolMode.lassoSelect then
        selectionModeValue = im.IntPtr(1)
      end

      im.SetNextWindowPos(selectionStylePopupPos, im.Cond_Appearing)
      local wndOpen = im.BoolPtr(transformToolSettingsOpen)
      im.Begin("Item Selection Style", wndOpen, im.WindowFlags_NoCollapse)

      if im.RadioButton2("Rectangle Select", selectionModeValue, im.Int(0)) then
        var.transformToolSelectionMode = var.enum_toolMode.select
        selectionModeChanged = true
      end

      if im.RadioButton2("Lasso Select", selectionModeValue, im.Int(1)) then
        var.transformToolSelectionMode = var.enum_toolMode.lassoSelect
        selectionModeChanged = true
        if var.lassoSelectionEnded and var.lassoSelectionItemsCalculated then
          var.lassoSelectionItemsCalculated = false
        end
      end
      im.End()
      if not wndOpen[0] then
        transformToolSettingsOpen = false
      end
      if selectionModeChanged and var.selectedTool.type == var.enum_toolType.transformTool then
        updateLegendCurrentActionNames(var.transformToolSelectionMode)
        extensions.hook("onEditorEditModeChanged", nil, nil)
      end

    end
  end

  -- add some spacing between tools and brushes
  if var.style then
    im.SetCursorPosX(im.GetCursorPosX() + var.style.ItemSpacing.x)
  end

  -- draw toolbar icons for the brushes
  for _, brush in ipairs(var.brushes) do
    toolbarToolIcon(brush)
  end

  if not forest then
    editor.uiVertSeparator(32)
    if editor.uiIconImageButton(editor.icons.forest_add_brushgroup, nil, nil, nil, nil, "Create Forest Object") then
      createForestObject()
    end
    im.tooltip("Create Forest Object (in the root group)")
  end

  if var.selectedTool and var.selectedTool.type == var.enum_toolType.brush then
    editor.uiVertSeparator(32)
    if var.fontSize then
      im.SetCursorPos(im.ImVec2(im.GetCursorPosX() + var.style.ItemSpacing.x, im.GetCursorPosY() + (32/2 - var.fontSize/2)))
    end
    im.TextUnformatted("Brush Settings: \t")
    im.SameLine()
    local brushSizeEditEnded = im.BoolPtr(false)
    local brushPressureEditEnded = im.BoolPtr(false)
    local brushSize = im.FloatPtr(editor.getPreference("forestEditor.general.brushSize"))
    local brushPressure = im.FloatPtr(editor.getPreference("forestEditor.general.brushPressure"))
    im.PushItemWidth(120)
    if sliderFloat("Size", "##BrushSize", brushSize, 1, 150, "%.1f", nil, brushSizeEditEnded, setBrushSize, "Brush Size\nUse the mouse wheel to adjust the value.", 0.5) then
      editor.setPreference("forestEditor.general.brushSize", brushSize[0])
    end
    im.SameLine()
    if sliderFloat("Density", "##BrushPressure", brushPressure, 1, 100, "%.0f%", nil, brushPressureEditEnded, setBrushPressure, "Brush Density") then
      editor.setPreference("forestEditor.general.brushPressure", brushPressure[0])
    end
    im.PopItemWidth()

    if brushSizeEditEnded[0] then
      setBrushSize()
    end

    if brushPressureEditEnded[0] then
      setBrushPressure()
    end
  end

  if debug == true then
    editor.uiVertSeparator(32)
    im.SameLine()
    if im.SmallButton("ForestBrushes") then
      M.dumpForestBrushes()
    end

    im.SameLine()
    if im.SmallButton("ForestBrushes Map") then
      M.dumpForestBrushesMap()
    end

    im.SameLine()
    if im.SmallButton("Brush Properties") then
      M.dumpBrushProperties()
    end

    im.SameLine()
    if im.SmallButton("Test") then
      print("var.forestBrushGroup:size()")
      print(var.forestBrushGroup:size())
    end

    im.SameLine()
    if im.SmallButton("Forest Brush Group") then
      print("ForestBrushGroup")
      dump(getmetatable(var.forestBrushGroup))
    end

    im.SameLine()
    if im.SmallButton("Save") then
      Sim.serializeToLineObjectsFile('ForestBrushGroup', editor.levelPath .. 'main.forestbrushes4.json')
    end
  end
end

local function forestBrushItemButton(item)
  local cPos = im.GetCursorPos()
  if var.editingObject == item then
    im.PushStyleVar2(im.StyleVar_FramePadding, im.ImVec2(var.style.FramePadding.x, 0))
    im.PushItemWidth(im.GetContentRegionAvailWidth())
    if var.highlightInputText == true then
      im.SetKeyboardFocusHere()
      var.highlightInputText = false
    end
    if im.InputText("##" .. item.internalName .. "_inputText_FB_" .. tostring(item.id), var.editingNameCharPtr, nil, im.InputTextFlags_EnterReturnsTrue) then
      local internalName = ffi.string(var.editingNameCharPtr)
      if internalName ~= item.internalName then
        local obj = scenetree.findObjectById(item.id)
        if obj then
          obj:setInternalName(internalName)
          item.internalName = internalName
          var.dirtyBrushes = true
          editor.setDirty()
        end
      end
      var.editingObject = nil
    end
    if im.IsKeyReleased(im.GetKeyIndex(im.Key_Escape)) == true then
      var.editingObject = nil
    end
    if im.IsItemHovered() == false and (im.IsMouseClicked(0) or im.IsMouseClicked(1)) then
      var.editingObject = nil
    end
    im.PopItemWidth()
    im.PopStyleVar()
  else
    im.PushStyleColor2(im.Col_Button, (item.selected == true) and var.buttonColor_active or var.buttonColor_inactive)
    local id = item.type == var.enum_forestObjType.forestBrush and ("##" .. item.internalName .. "_button_FB_" .. tostring(item.id)) or ("##" .. item.internalName .. "_button_FBE_" .. tostring(item.id))
    if im.Button(id, im.ImVec2(im.GetContentRegionAvailWidth(), var.fontSize)) then
      -- add to selection if ctrl is held
      selectForestBrush(item, editor.keyModifiers.ctrl)
    end
    if editor.IsItemDoubleClicked() == true then
      var.editingObject = item
      var.editingNameCharPtr = im.ArrayChar(32, item.internalName)
      var.highlightInputText = true
    end
    im.PopStyleColor()
    im.SetCursorPos(im.ImVec2(cPos.x + var.style.FramePadding.x, cPos.y))
    im.TextUnformatted(item.internalName)
  end
end

-- ##### GUI #####
local function forestBrushTreeNode(forestBrush)
  -- Forest Brush
  if forestBrush.type == var.enum_forestObjType.forestBrush then
    if editor.uiIconImageButton((forestBrush.open == true) and editor.icons.keyboard_arrow_down or editor.icons.keyboard_arrow_right, im.ImVec2(var.fontSize, var.fontSize), nil, nil, var.buttonColor_inactive) then
      toggleForestBrushTreeNode(forestBrush)
    end
    im.SameLine()
    editor.uiIconImage(editor.icons.forest_brushgroup, im.ImVec2(var.fontSize, var.fontSize))
    im.SameLine()

    local cursorPos = im.GetCursorPos()
    forestBrushItemButton(forestBrush)

    if forestBrush.open == true then
      for _, element in ipairs(forestBrush.elements) do
        im.SetCursorPosX(cursorPos.x + var.style.FramePadding.x - var.fontSize)
        editor.uiIconImage(editor.icons.forest_brushelement, im.ImVec2(var.fontSize, var.fontSize))
        im.SameLine()
        forestBrushItemButton(element)
      end
    end
  -- Forest Brush Element
  else
    im.SetCursorPosX(im.GetCursorPosX() + var.fontSize + var.style.ItemSpacing.x)
    editor.uiIconImage(editor.icons.forest_brushelement, im.ImVec2(var.fontSize, var.fontSize))
    im.SameLine()
    forestBrushItemButton(forestBrush)
  end
end

local function forestItemDataTreeNode(item)
  local obj = scenetree.findObjectById(item.id)
  if not obj then return end

  editor.uiIconImage(editor.icons.forest_brushelement, im.ImVec2(var.fontSize, var.fontSize))
  im.SameLine()
  local cPos = im.GetCursorPos()
  im.PushStyleColor2(im.Col_Button, (item.selected == true) and var.buttonColor_active or var.buttonColor_inactive)
  --TODO: make sure to make a better nil check for internalName
  if im.Button("##" .. (obj.internalName or "unnamed") .. "_button_FID_" .. tostring(item.id), im.ImVec2(im.GetContentRegionAvailWidth(), var.fontSize)) then
    -- add to selection if ctrl is held
    selectForestItemData(item, editor.keyModifiers.ctrl)
  end
  im.PopStyleColor()
  im.SetCursorPos(im.ImVec2(cPos.x + var.style.FramePadding.x, cPos.y))
  im.TextUnformatted(obj.name)
end

local function onEditorGui()
  if not editor.editMode or (editor.editMode.displayName ~= editModeName) then
    return
  end

  --TODO: nicusor: make a generic input action repeater
  if changeBrushSizeAutoRepeatOn then
    updateAutoRepeatChangeBrushSize()
  end

  -- get the Forest object
  --TODO: should we do this every frame ?
  forest = core_forest.getForestObject()
  forestTable[1] = forest
  if forest then
    var.forestData = forest:getData()
    var.forestBrushTool:setActiveForest(forest)
  end
  --TODO: should we do this every frame ?
  var.forestBrushGroup = scenetree.findObject("ForestBrushGroup")

  var.style = im.GetStyle()
  var.fontSize = math.ceil(im.GetFontSize())

  if editor.isWindowVisible(toolWindowName) == true then
    if var.forestEditorWindowSize and var.forestEditorWindowMinWidth then
      if var.forestEditorWindowSize.x < var.forestEditorWindowMinWidth then
        im.SetNextWindowSize(im.ImVec2(var.forestEditorWindowMinWidth, 0))
      end
    end
  end

  if var.selectedTool.type == var.enum_toolType.brush then
    if editor.beginWindow(toolWindowName, "Forest Editor##Window", 0, true) then
      var.forestEditorWindowSize = im.GetWindowSize()

      local cursorPos = im.GetCursorPos()
      local tabIconWidth = var.fontSize + 2 * var.style.FramePadding.y - 3
      local tabIconSize = im.ImVec2(tabIconWidth, tabIconWidth)

      if im.BeginTabBar("ForestEditorTabBar") then
        if im.BeginTabItem("Brushes##Tab") then
          if var.selectedTab == var.enum_tabType.meshes then
            var.selectedTab = var.enum_tabType.brushes
            if #var.selectedForestBrushes == 1 then
              selectForestBrush(var.selectedForestBrushes[1]) -- Select the brush again that was selected before
            end
          end
          if im.BeginChild1("BrushesChild") then
            if var.forestBrushes then
              for _, brush in ipairs(var.forestBrushes) do
                forestBrushTreeNode(brush)
              end
            end
          end
          im.EndChild()
          im.EndTabItem()
        end
        if im.BeginTabItem("Meshes##Tab") then
          if var.selectedTab == var.enum_tabType.brushes then
            var.selectedTab = var.enum_tabType.meshes
            if #var.selectedForestItemDatas == 1 then
              selectForestItemData(var.selectedForestItemDatas[1]) -- Select the forestItemData again that was selected before
            end
          end
          if im.BeginChild1("MeshesChild") then
            for _, item in ipairs(var.forestItemData) do
              forestItemDataTreeNode(item)
            end
          end
          im.EndChild()
          im.EndTabItem()
        end
        im.SetCursorPos(im.ImVec2(
          cursorPos.x + im.CalcTextSize("BrushesMeshes").x + 4 * var.style.FramePadding.x + var.style.ItemInnerSpacing.x + 2*var.style.ItemSpacing.x,
          cursorPos.y
        ))
        im.PushStyleVar2(im.StyleVar_ItemSpacing, im.ImVec2(4,4))

        if var.selectedTab == var.enum_tabType.brushes then
          if editor.uiIconImageButton(editor.icons.forest_add_brushgroup, tabIconSize, nil, nil, nil, "addNewBrushGroupIcon", nil) then
            newForestBrush()
          end
          im.tooltip("Add New Brush Group")
          im.SameLine()

          if editor.uiIconImageButton(editor.icons.forest_add_brushelement, tabIconSize, nil, nil, nil, "addNewBrushElementIcon", nil) then
            newForestBrushElement()
          end
          im.tooltip("Add New Brush Element")
          im.SameLine()

          if editor.uiIconImageButton(editor.icons.forest_delete_selected, tabIconSize, nil, nil, nil, "deleteSelectedBrushIcon", nil) then
            editor.deleteSelection()
          end
          im.tooltip("Delete Selected")
        elseif  var.selectedTab == var.enum_tabType.meshes then
          if editor.uiIconImageButton(editor.icons.forest_add_brushelement, tabIconSize, nil, nil, nil, "addNewMeshIcon", nil) then
            editor_fileDialog.openFile(newForestItemData, {{"mesh files", {".dae", ".dts"}}}, false, "/")
          end
          im.tooltip("Add New Mesh")
          im.SameLine()

          if editor.uiIconImageButton(editor.icons.forest_delete_selected, tabIconSize, nil, nil, nil, "deleteSelectedMeshIcon", nil) then
            editor.deleteSelection()
          end
          im.tooltip("Delete Selected")
        end

        if not forest then
          im.SameLine()
          im.TextColored(yellow, "No forest object present. Please create one.")
        end

        if not var.forestEditorWindowMinWidth then
          im.SameLine()
          var.forestEditorWindowMinWidth = im.GetCursorPosX()
        end
        im.PopStyleVar()
        im.EndTabBar()
      end
    end
    editor.endWindow()
  end

  if not forest and not createForestPopupShown then
    editor.openModalWindow("noForestMsgDlg")
    createForestPopupShown = true
  end

  if editor.beginModalWindow("noForestMsgDlg", "No Forest Object") then
    im.Spacing()
    im.Text("There is no Forest object to render forest items, create one ?")
    im.Spacing()
    im.Separator()
    im.Spacing()
    im.Spacing()
    im.Spacing()
    if im.Button("Yes") then
      createForestObject()
      editor.closeModalWindow("noForestMsgDlg")
    end
    im.SameLine()
    if im.Button("No") then
      editor.closeModalWindow("noForestMsgDlg")
    end
  end
  editor.endModalWindow()

  if editor.beginModalWindow("noForestBrushGroupMsgDlg", "No Forest Brush Group") then
    im.Spacing()
    im.Text("There is no Forest Brush Group to add Forest Brushes to, create one ?")
    im.Spacing()
    im.Separator()
    im.Spacing()
    im.Spacing()
    im.Spacing()
    if im.Button("Yes") then
      createForestBrushGroup(true)
      editor.closeModalWindow("noForestBrushGroupMsgDlg")
    end
    im.SameLine()
    if im.Button("No") then
      editor.closeModalWindow("noForestBrushGroupMsgDlg")
    end
  end
  editor.endModalWindow()
end
-- ##### GUI END #####

local function drawFrustumRect(frustum)
  local topLeftFrustum = vec3(frustum:getNearLeft() * 2, frustum:getNearDist() * 2, frustum:getNearTop() * 2)
  local topRightFrustum = vec3(frustum:getNearRight() * 2, frustum:getNearDist() * 2, frustum:getNearTop() * 2)
  local bottomLeftFrustum = vec3(frustum:getNearLeft() * 2, frustum:getNearDist() * 2, frustum:getNearBottom() * 2)
  local bottomRightFrustum = vec3(frustum:getNearRight() * 2, frustum:getNearDist() * 2, frustum:getNearBottom() * 2)

  local pos = getCameraPosition()
  local q = quat(getCameraQuat())
  local topLeftWorld, bottomRightWorld = (q * topLeftFrustum) + pos, (q * bottomRightFrustum) + pos
  local topRightWorld, bottomLeftWorld = (q * topRightFrustum) + pos, (q * bottomLeftFrustum) + pos

  -- Draw the selection rectangle
  debugDrawer:drawLine(topLeftWorld, topRightWorld, ColorF(1, 0, 0, 1))
  debugDrawer:drawLine(topRightWorld, bottomRightWorld, ColorF(1, 0, 0, 1))
  debugDrawer:drawLine(bottomRightWorld, bottomLeftWorld, ColorF(1, 0, 0, 1))
  debugDrawer:drawLine(bottomLeftWorld, topLeftWorld, ColorF(1, 0, 0, 1))
end

local function getForestBrushElementsFromSelection()
  local forestBrushElements = {}
  for k, item in ipairs(var.selectedForestBrushes) do
    if item.type == var.enum_forestObjType.forestBrush then
      for k, element in ipairs(item.elements) do
        forestBrushElements[element.id] = element.internalName
      end
    -- Forest Brush Element
    else
      forestBrushElements[item.id] = item.internalName
    end
  end
  return forestBrushElements
end

local function calculateLassoSelection()
  local lassoNodes2D = {}
  if var.lassoSelectMode == var.enum_lassoSelectMode.polyline then
    for _, node in ipairs(var.lassoPLNodes) do
      table.insert(lassoNodes2D, Point2F(node.pos.x, node.pos.y))
    end
  else
    for _, node in ipairs(var.lassoFHLineSegments) do
      table.insert(lassoNodes2D, Point2F(node.x, node.y))
    end
  end

  local forestItems = var.forestData:getItemsPolygon(lassoNodes2D)
  selectForestItems(forestItems)
  var.lassoSelectionItemsCalculated = true
end

local function getLassoNodeUnderCursor()
  local camPos = getCameraPosition()
  local ray = getCameraMouseRay()
  local rayDir = ray.dir
  local minNodeDist = u_32_max_int
  local hoveredNodeIndex = nil

  if var.lassoSelectMode == var.enum_lassoSelectMode.polyline then
    for index, node in ipairs(var.lassoPLNodes) do
      local distNodeToCam = (node.pos - camPos):length()
      if distNodeToCam < minNodeDist then
        local nodeRayDistance = (node.pos - camPos):cross(rayDir):length() / rayDir:length()
        local sphereRadius = (camPos - node.pos):length() * roadRiverGui.nodeSizeFactor
        if nodeRayDistance <= sphereRadius then
          hoveredNodeIndex = index
          minNodeDist = distNodeToCam
        end
      end
    end
  elseif var.lassoSelectMode == var.enum_lassoSelectMode.freehand then
    if not tableIsEmpty(var.lassoFHLineSegments) then
      local nodeRayDistance = (var.lassoFHLineSegments[1] - camPos):cross(rayDir):length() / rayDir:length()
      local sphereRadius = (camPos - var.lassoFHLineSegments[1]):length() * roadRiverGui.nodeSizeFactor
      if nodeRayDistance <= sphereRadius then
        hoveredNodeIndex = 1
      end
    end
  end
  return hoveredNodeIndex
end

local function drawLassoLineSegmented(originNode, targetNode)
  local length = (originNode.pos - targetNode.pos):length()
  local segmentsCount = length / 4.0
  local directionVector = (targetNode.pos - originNode.pos):normalized()

  local lastPos = originNode.pos
  local lineSegments = {}
  for index = 1, segmentsCount + 1, 1 do
    local tempTarget = (index < segmentsCount) and (lastPos + (directionVector * 4.0)) or targetNode.pos
    local tempLineBegin = lastPos
    local tempLineEnd = tempTarget

    if originNode.isUpdated or targetNode.isUpdated then
      local rayCastBegin = castRayDown(lastPos + vec3(0,0,100))
      local rayCastEnd = castRayDown(tempTarget + vec3(0,0,100))
      if rayCastBegin then
        tempLineBegin = vec3(lastPos.x,lastPos.y,rayCastBegin.pt.z)
      end
      if rayCastEnd then
        tempLineEnd = vec3(tempTarget.x,tempTarget.y,rayCastEnd.pt.z)
      end
    else
      if var.lassoPLLineSegments[originNode.nodeID] then
        local currentLassoSegments = var.lassoPLLineSegments[originNode.nodeID]
        if currentLassoSegments[index] then
          tempLineBegin = currentLassoSegments[index].startPos
          tempLineEnd = currentLassoSegments[index].endPos
        end
      end
    end

    if originNode.isUpdated or targetNode.isUpdated then
      local segment = {startPos = tempLineBegin, endPos = tempLineEnd}
      table.insert(lineSegments, segment)
    end
    debugDrawer:drawLineInstance(tempLineBegin, tempLineEnd, 50, colorBlue, 50, colorBlue, colorBlue, colorBlue, 0, false)
    lastPos = lastPos + (directionVector * 4.0)
  end
  -- cache segments bw updated nodes so that we don't raycast on every frame
  -- when there is no update in node positions
  if originNode.isUpdated or targetNode.isUpdated then
    var.lassoPLLineSegments[originNode.nodeID] = lineSegments
  end
end

local function drawLassoPolyline()
  local numNodes = #var.lassoPLNodes
  local shouldRenderCompletionSphere = false
  if var.lassoHoveredNodeIndex == 1 and numNodes > 2 then
    if var.lassoSelectionEnded then
      shouldRenderCompletionSphere = false;
    else
      if editor.keyModifiers.alt then
        shouldRenderCompletionSphere = true;
      else
        shouldRenderCompletionSphere = false;
      end
    end
  end

  -- draw cursor sphere
  if var.lassoSelectionEnded == false and editor.keyModifiers.alt and not shouldRenderCompletionSphere then
    local hit
    if im.GetIO().WantCaptureMouse == false then
      hit = cameraMouseRayCast(false, im.flags(SOTTerrain))
    end
    if hit then
      local sphereRadius = (getCameraPosition() - hit.pos):length() * roadRiverGui.nodeSizeFactor
      debugDrawer:drawSphere(hit.pos, sphereRadius, roadRiverGui.highlightColors.node, false)
      if not tableIsEmpty(var.lassoPLNodes) then
        local tempNode = {pos = hit.pos, isUpdated = true}
        drawLassoLineSegmented(var.lassoPLNodes[numNodes], tempNode, true)
      end
    end
  end

  if tableIsEmpty(var.lassoPLNodes) then return end

  for index, node in ipairs(var.lassoPLNodes) do
    local nodeColor = roadRiverGui.highlightColors.node
    if var.lassoHoveredNodeIndex == index then
      nodeColor = roadRiverGui.highlightColors.hoveredNode
    elseif var.lassoPLSelectedNodeIndex == index then
      nodeColor = roadRiverGui.highlightColors.selectedNode
    end
    -- Skip first node if we should render completion sphere
    if index == 1 and shouldRenderCompletionSphere then
      goto continue
    else
      local sphereRadius = (getCameraPosition() - node.pos):length() * roadRiverGui.nodeSizeFactor
      debugDrawer:drawSphere(node.pos, sphereRadius, nodeColor, false)
    end
    if index > 1 then
      drawLassoLineSegmented(var.lassoPLNodes[index - 1], node)
    end
    ::continue::
  end

  -- finally draw the closing line if selection ended
  if var.lassoSelectionEnded then
    drawLassoLineSegmented(var.lassoPLNodes[numNodes], var.lassoPLNodes[1])
  end

  -- draw completion line and sphere
  if var.lassoSelectionEnded == false and editor.keyModifiers.alt then
    if shouldRenderCompletionSphere then
      local sphereRadius = (getCameraPosition() - var.lassoPLNodes[1].pos):length() * roadRiverGui.nodeSizeFactor * 2
      debugDrawer:drawSphere(var.lassoPLNodes[1].pos, sphereRadius,  colorGreen, false)
      drawLassoLineSegmented(var.lassoPLNodes[numNodes], var.lassoPLNodes[1])
    end
  end

  for _, node in ipairs(var.lassoPLNodes) do
    node.isUpdated = false
  end
end

local function drawLassoFreehand()
  if var.lassoFHLastMousePos ~= nil and not var.lassoSelectionEnded then
    local sphereRadius = (getCameraPosition() - var.lassoFHLastMousePos):length() * roadRiverGui.nodeSizeFactor
    debugDrawer:drawSphere(var.lassoFHLastMousePos, sphereRadius, colorRed, false)
  end

  if tableIsEmpty(var.lassoFHLineSegments) then return end
  for index, segmentPos in ipairs(var.lassoFHLineSegments) do
    if index == 1 and not var.lassoSelectionEnded then
      local sphereRadius = (getCameraPosition() - segmentPos):length() * roadRiverGui.nodeSizeFactor
      local sphereColor = colorRed
      if var.lassoHoveredNodeIndex then
        sphereColor = colorGreen
        sphereRadius = sphereRadius * 2
      end
      debugDrawer:drawSphere(segmentPos, sphereRadius, sphereColor, false)
    elseif index > 1 then
      debugDrawer:drawLineInstance(var.lassoFHLineSegments[index - 1], var.lassoFHLineSegments[index], 50, colorBlue, 50,colorBlue, colorBlue, colorBlue, 0, false)
    end
  end

  if var.lassoSelectionEnded then
    debugDrawer:drawLineInstance(var.lassoFHLineSegments[#var.lassoFHLineSegments], var.lassoFHLineSegments[1], 50, colorBlue, 50, colorBlue, colorBlue, colorBlue, 0, false)
  end
end

local function forestToolsEditModeUpdate()
  local rayRange = editor.getPreference("forestEditor.general.toolWorkingDistance")
  if not forest then return end
  if var.selectedTool ~= nil then
    -- brush selected
    if var.selectedTool.type == var.enum_toolType.brush then
      if im.GetIO().WantCaptureMouse == false then
        if (var.selectedForestBrushes and #var.selectedForestBrushes > 0) or
        ((var.selectedTool.type == var.enum_toolType.brush) and (var.selectedTool.mode == var.enum_brushMode.erase)) then
          forest:disableCollision()
          local hit = cameraMouseRayCast(false, nil, rayRange)
          forest:enableCollision()
          if hit then
            local newItems
            local color = nil
            if not var.selectedTool.destructive then
              color = editor.getPreference("gizmos.brush.createBrushColor")
            else
              color = editor.getPreference("gizmos.brush.deleteBrushColor")
            end
            editor.drawBrush('ellipse', hit.pos, editor.getPreference("forestEditor.general.brushSize") / 2, nil, color, core_terrain.getTerrain())
            local cam = getCameraMouseRay()
            var.gui3DMouseEvent.pos = cam.pos
            var.gui3DMouseEvent.vec = cam.dir
            if im.IsMouseClicked(0) then
              if var.selectedTool.label == "erase" or var.selectedTool.label == "eraseSelected" then
                lastHitPos = hit.pos
                local before = var.forestData:getItemsCircle(hit.pos, editor.getPreference("forestEditor.general.brushSize") / 2)
                for _, item in ipairs(before) do
                  deletedItems[item:getKey()] = item
                end
              end
              if var.selectedTool.label == "snap" then
                local items = var.forestData:getItemsCircle(hit.pos, editor.getPreference("forestEditor.general.brushSize") / 2)
                for _, item in ipairs(items) do
                  snappedItems[item:getKey()] = item:getTransform()
                end
              end

              newItems = var.forestBrushTool:on3DMouseDown(var.gui3DMouseEvent, getForestBrushElementsFromSelection())

              if var.selectedTool.label == "erase" or var.selectedTool.label == "eraseSelected" then
                local after = var.forestData:getItemsCircle(hit.pos, editor.getPreference("forestEditor.general.brushSize") / 2)
                for _, item in ipairs(after) do
                  if deletedItems[item:getKey()] then
                    deletedItems[item:getKey()] = nil
                  end
                end
              end
            end
            if im.GetIO().MouseDelta.x ~= 0 or im.GetIO().MouseDelta.y ~= 0 then
              if im.IsMouseDown(0) then

                if var.selectedTool.label == "erase" or var.selectedTool.label == "eraseSelected" then
                  local after = var.forestData:getItemsCircle(lastHitPos, editor.getPreference("forestEditor.general.brushSize") / 2)
                  for _, item in ipairs(after) do
                    if deletedItems[item:getKey()] then
                      deletedItems[item:getKey()] = nil
                    end
                  end

                  lastHitPos = hit.pos
                  local before = var.forestData:getItemsCircle(hit.pos, editor.getPreference("forestEditor.general.brushSize") / 2)
                  for _, item in ipairs(before) do
                    deletedItems[item:getKey()] = item
                  end
                end

                if var.selectedTool.label == "snap" then
                  local items = var.forestData:getItemsCircle(hit.pos, editor.getPreference("forestEditor.general.brushSize") / 2)
                  for _, item in ipairs(items) do
                    if not snappedItems[item:getKey()] then
                      snappedItems[item:getKey()] = item:getTransform()
                    end
                  end
                end

                newItems = var.forestBrushTool:on3DMouseDragged(var.gui3DMouseEvent)
              else
                var.forestBrushTool:on3DMouseMove(var.gui3DMouseEvent)
              end
            end

            -- Rotate the items relative to the ground
            if editor.getPreference("snapping.terrain.enabled") and editor.getPreference("snapping.terrain.relRotation") and newItems and var.selectedTool.label == "paint" then
              forest:disableCollision()
              for _, item in ipairs(newItems) do
                local pos = vec3(item:getPosition())
                local height = item:getSize().z
                pos.z = pos.z + height * 0.5
                local rayCastRes = castRayDown(pos, pos - vec3(0,0,height))
                if rayCastRes then
                  local rotation = QuatF(0,0,0,1)
                  rotation:setFromMatrix(item:getTransform())

                  local normal = vec3(rayCastRes.norm)
                  local rot = quat(rotation) * vec3(0,0,1):getRotationTo(normal)
                  local trans = QuatF(rot.x, rot.y, rot.z, rot.w):getMatrix()
                  trans:setColumn(3, item:getPosition())

                  editor.updateForestItem(var.forestData, item:getKey(), item:getPosition(), item:getData(), trans, item:getScale())
                end
              end
              forest:enableCollision()
            end

            if im.IsMouseReleased(0) then
              if var.selectedTool.label == "erase" or var.selectedTool.label == "eraseSelected" then
                local after = var.forestData:getItemsCircle(lastHitPos, editor.getPreference("forestEditor.general.brushSize") / 2)
                for _, item in ipairs(after) do
                  if deletedItems[item:getKey()] then
                    deletedItems[item:getKey()] = nil
                  end
                end
              end

              local items = var.forestBrushTool:on3DMouseUp(var.gui3DMouseEvent)

              if var.selectedTool.label == "paint" then
                addItems(items, true)
              elseif var.selectedTool.label == "erase" or var.selectedTool.label == "eraseSelected" then
                local delItems = {}
                for _, item in pairs(deletedItems) do
                  table.insert(delItems, item)
                end
                removeItems(delItems, true)
                deletedItems = {}
              elseif var.selectedTool.label == "snap" then
                local oldTransforms = {}
                local newTransforms = {}
                local scales = {}
                for _, item in ipairs(items) do
                  table.insert(oldTransforms, snappedItems[item:getKey()])
                  table.insert(newTransforms, item:getTransform())
                  table.insert(scales, item:getScale())
                end
                editor.history:commitAction("SetForestItemTransform",
                      {items = items, newTransforms = newTransforms, oldTransforms = oldTransforms,
                      newScales = scales, oldScales = scales},
                      setItemTransformUndo, setItemTransformRedo, true)
                snappedItems = {}
              end

              editor.forestDirty = true
              editor.setDirty()
            end
          end
        end
      end
    -- transform tools selected
    else
      -- lasso selection
      if var.transformToolSelectionMode == var.enum_toolMode.lassoSelect and var.selectedTool.type == var.enum_toolType.transformTool then
        -- draw the gizmo
        if editor.selection.forestItem and editor.selection.forestItem[1] then
          editor.updateAxisGizmo(gizmoBeginDrag, gizmoEndDrag, gizmoDragging)
          editor.drawAxisGizmo()
        end
        if im.IsKeyReleased(im.GetKeyIndex(im.Key_Escape)) then
          var.lassoPLNodes = {}
          var.lassoPLLineSegments = {}
          var.lassoSelectionEnded =false
          var.lassoSelectionItemsCalculated = false
          var.lassoHoveredNodeIndex = nil
          var.lassoPLSelectedNodeIndex = nil
          var.mouseButtonHeldOnLassoNode = false

          var.lassoFHLastMousePos = nil
          var.lassoFHLineSegments = {}
          var.lassoSelectMode = var.enum_lassoSelectMode.freehand
        end

        if var.lassoSelectMode == var.enum_lassoSelectMode.polyline then
          drawLassoPolyline()
        elseif var.lassoSelectMode == var.enum_lassoSelectMode.freehand then
          drawLassoFreehand()
        end

        local hit
        if im.GetIO().WantCaptureMouse == false then
          hit = cameraMouseRayCast(false, im.flags(SOTTerrain))
        end

        if var.lassoSelectionItemsCalculated then
          if hit and var.lassoSelectMode == var.enum_lassoSelectMode.polyline then
            var.lassoHoveredNodeIndex = getLassoNodeUnderCursor()
            if im.IsMouseClicked(0)
                and editor.isViewportHovered()
                and not editor.isAxisGizmoHovered() then
              if var.lassoHoveredNodeIndex ~= nil then
                var.mouseButtonHeldOnLassoNode = true
                var.lassoPLSelectedNodeIndex = var.lassoHoveredNodeIndex
              end
            end

            if im.IsMouseReleased(0) then
              var.mouseButtonHeldOnLassoNode = false
            end

            if var.mouseButtonHeldOnLassoNode and im.IsMouseDragging(0) then
              var.lassoPLNodes[var.lassoPLSelectedNodeIndex].pos = hit.pos
              var.lassoPLNodes[var.lassoPLSelectedNodeIndex].isUpdated = true
              calculateLassoSelection()
            end
          end
        elseif var.lassoSelectionEnded and var.lassoSelectionItemsCalculated == false then
          calculateLassoSelection()
        else
          var.lassoHoveredNodeIndex = getLassoNodeUnderCursor()
          if editor.keyModifiers.alt then
            var.lassoSelectMode = var.enum_lassoSelectMode.polyline
            if im.IsMouseClicked(0)
                and editor.isViewportHovered()
                and not editor.isAxisGizmoHovered() then
              if var.lassoHoveredNodeIndex == 1 and #var.lassoPLNodes > 2 then
                var.lassoSelectionEnded = true
              else
                local node = {
                  nodeID    = #var.lassoPLNodes + 1,
                  pos       = hit.pos,
                  isUpdated = false
                }
                table.insert(var.lassoPLNodes, node)
              end
            end
          else
            if tableIsEmpty(var.lassoPLNodes) then
              var.lassoSelectMode = var.enum_lassoSelectMode.freehand
            else
              var.lassoSelectMode = var.enum_lassoSelectMode.polyline
            end

            if var.lassoSelectMode == var.enum_lassoSelectMode.polyline then
              if hit then
                if im.IsMouseClicked(0)
                    and editor.isViewportHovered()
                    and not editor.isAxisGizmoHovered() then
                  if var.lassoHoveredNodeIndex ~= nil then
                    var.mouseButtonHeldOnLassoNode = true
                    var.lassoPLSelectedNodeIndex = var.lassoHoveredNodeIndex
                  end
                end

                if im.IsMouseReleased(0) then
                  var.mouseButtonHeldOnLassoNode = false
                end

                if var.mouseButtonHeldOnLassoNode and im.IsMouseDragging(0) then
                  var.lassoPLNodes[var.lassoPLSelectedNodeIndex].pos = hit.pos
                  var.lassoPLNodes[var.lassoPLSelectedNodeIndex].isUpdated = true
                end
              end
            elseif var.lassoSelectMode == var.enum_lassoSelectMode.freehand then
              if hit then
                if im.IsMouseDown(0) and var.lassoFHLastMousePos == nil then
                  var.lassoFHLastMousePos = hit.pos
                end

                if im.IsMouseReleased(0) then
                  if getLassoNodeUnderCursor() then
                    var.lassoSelectionEnded = true
                  else
                    var.lassoFHLastMousePos = nil
                    var.lassoFHLineSegments = {}
                  end
                end

                if im.IsMouseDragging(0) and var.lassoFHLastMousePos ~= nil then
                  local dragLength = (hit.pos - var.lassoFHLastMousePos):length()
                  if  dragLength > 1 then
                    -- Insert first segment start point
                    if tableIsEmpty(var.lassoFHLineSegments) then
                      table.insert(var.lassoFHLineSegments, var.lassoFHLastMousePos)
                    end
                    table.insert(var.lassoFHLineSegments, hit.pos)
                    var.lassoFHLastMousePos = hit.pos
                  end
                end
              end
            end
          end
        end
      else
        -- draw the gizmo
        if editor.selection.forestItem and editor.selection.forestItem[1] then
          -- todo: rather do this once instead of every frame
          -- editor.setAxisGizmoAlignment(editor.AxisGizmoAlignment_Local)
          editor.updateAxisGizmo(gizmoBeginDrag, gizmoEndDrag, gizmoDragging)
          editor.drawAxisGizmo()
        end

        local cam = getCameraMouseRay()
        var.gui3DMouseEvent.pos = cam.pos
        var.gui3DMouseEvent.vec = cam.dir
        local forestItem = forest:castRayRendered(cam.pos, cam.pos + cam.dir * rayRange).forestItem
        if forestItem then
          worldEditorCppApi.renderForestBBs({forestItem}, colorWhite)
        end
        if im.IsMouseClicked(0)
            and editor.isViewportHovered()
            and not editor.isAxisGizmoHovered() then

          if forestItem and editor.isAxisGizmoHovered() == false then
            selectForestItems({forestItem}, editor.keyModifiers.ctrl)
          elseif not editor.keyModifiers.ctrl then
            selectForestItems()
          end
          mouseDragStartPos = im.GetMousePos()
        end

        if im.IsMouseDragging(0) and mouseDragStartPos then
          isMouseDragging = true
          local delta = im.GetMouseDragDelta(0)
          local topLeft2I = editor.screenToClient(Point2I(mouseDragStartPos.x, mouseDragStartPos.y))
          local topLeft = vec3(topLeft2I.x, topLeft2I.y, 0)
          local bottomRight = (topLeft + vec3(delta.x, delta.y, 0))

          local frustum
          itemsInRect, frustum = editor.getObjectsByRectangle({topLeft = topLeft, bottomRight = bottomRight}, var.forestData)
          drawFrustumRect(frustum)
          worldEditorCppApi.renderForestBBs(itemsInRect, colorWhite)
        end

        if im.IsMouseReleased(0) then
          if mouseDragStartPos and isMouseDragging then
            selectForestItems(itemsInRect, editor.keyModifiers.ctrl)
            itemsInRect = {}
          end
          mouseDragStartPos = nil
          isMouseDragging = false
        end
      end
    end
  end

  if editor.selection.forestItem then
    worldEditorCppApi.renderForestBBs(editor.selection.forestItem, colorWhite)
  end
end

local function onDeselect()
  selectForestItems()
end

local function onDeleteSelection()
  if var.selectedTool.label == "select" then
    -- forest items
    removeItems(editor.selection.forestItem)
  else
    -- brush element
    editor.history:beginTransaction("DeleteItem")
    if var.selectedTab == var.enum_tabType.brushes then
      for k, item in ipairs(var.selectedForestBrushes) do
        objectHistoryActions.deleteObjectWithUndo(item.id)
        editor.history:commitAction("RemoveItem", {item = item}, removeItemUndo, removeItemRedo)
      end
      var.selectedForestBrushes = {}
    else
      for k, item in ipairs(var.selectedForestItemDatas) do
        objectHistoryActions.deleteObjectWithUndo(item.id)
        editor.history:commitAction("RemoveItem", {item = item}, removeItemUndo, removeItemRedo)
      end
      var.selectedForestItemDatas = {}
    end
    editor.history:endTransaction()

    var.dirtyBrushes = true
    editor.setDirty()
  end
end

local function onEditorAxisGizmoAligmentChanged()
  if editor.selection.forestItem then
    if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local and #editor.selection.forestItem == 1 then
      editor.setAxisGizmoTransform(editor.selection.forestItem[1]:getTransform(), vec3(1,1,1))
    elseif selectionCentroid then
      local mat = MatrixF(true)
      mat:setColumn(3, selectionCentroid)
      editor.setAxisGizmoTransform(mat, vec3(1,1,1))
    end
  end
end

local function duplicateForestItems(items)
  local newItems = {}
  for i, item in ipairs(items) do
    newItems[i] = var.forestData:createNewItem(item:getData(), item:getTransform(), item:getScale())
  end
  return newItems
end

local function onDuplicate()
  if not editor.isViewportFocused() then return end
  if editor.selection.forestItem and editor.selection.forestItem[1] then
    selectForestItems(duplicateForestItems(editor.selection.forestItem))
    if not im.IsMouseDown(0) then
      addItems(editor.selection.forestItem, true)
    end
    editor.forestDirty = true
    editor.setDirty()
  end
end

local function onCopy()
  if editor.selection.forestItem[1] then
    table.clear(copyItemsArray)
    for i, item in ipairs(editor.selection.forestItem) do
      copyItemsArray[i] = {itemDataId = item:getData():getID(), transform = editor.matrixToTable(item:getTransform()), scale = item:getScale()}
    end
  end
end

local function onPaste()
  local newItems = {}
  for i, item in ipairs(copyItemsArray) do
    newItems[i] = var.forestData:createNewItem(scenetree.findObjectById(item.itemDataId), editor.tableToMatrix(item.transform), item.scale)
  end
  addItems(newItems, true)
  selectForestItems(newItems)
end

local function forestEditModeActivate()
  if not forest then
    editor.logWarn("No Forest object present, please create one by pressing the Create Forest button in the forest editor toolbar")
  end
end

local function forestEditModeDeactivate()
  createForestPopupShown = false
end

local shapeFilenameChanged = false
local shapeFilename = ""
local function forestItemShapeFileCustomFieldEditor(objectIds, fieldValue, fieldName, fieldLabel, fieldDesc, fieldType, fieldTypeName, customData, pasteCallback, contextMenuUI)
  local extension = {"Collada", {".dae"}}

  if im.Button("...") then
    local dir, fn, ext = path.split(fieldValue)
    local fileSpec = {{"All Files","*"}}
    if extension then fileSpec = {extension, {"All Files","*"}} end

    editor_fileDialog.openFile(function(data)
      if data.filepath ~= "" then
        shapeFilenameChanged = true
        shapeFilename = data.filepath
      end
    end, fileSpec, false, dir)
  end

  if shapeFilenameChanged then
    shapeFilenameChanged = false
    return {fieldValue = shapeFilename, editEnded = true}
  end

  im.SameLine()
  im.PushItemWidth(im.GetContentRegionAvailWidth())

  local shapeFileInputTextValue = im.ArrayChar(2048, fieldValue)
  if im.InputText("##shapeFile", shapeFileInputTextValue, nil, im.InputTextFlags_EnterReturnsTrue) then
    return {fieldValue = ffi.string(shapeFileInputTextValue), editEnded = true}
  end

  local size = im.GetContentRegionAvailWidth()
  var.meshPreviewDimRdr.point = Point2I(0, 0)
  var.meshPreviewDimRdr.extent = Point2I(size,size)
  var.meshPreviewRenderSize[1] = size
  var.meshPreviewRenderSize[2] = size
  var.meshPreview:renderWorld(var.meshPreviewDimRdr)
  im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(0,0))
  if im.BeginChild1(fieldName .. "MeshPreviewChild", im.ImVec2(size,size), true, im.WindowFlags_NoScrollWithMouse) then
    var.meshPreview:ImGui_Image(var.meshPreviewRenderSize[1],var.meshPreviewRenderSize[2])
    im.EndChild()
  end
  im.PopStyleVar()

end


local brushElementForestItemDataChanged = false
local brushElementForestItemDataName = ""
local function brushElementForestItemDataCustomFieldEditor(objectIds, fieldValue, fieldName, fieldLabel, fieldDesc, fieldType, fieldTypeName, customData, pasteCallback, contextMenuUI)
  if im.Button("...") then
    im.OpenPopup("##" .. fieldName .. "DataBlockPopup")
  end
  im.SameLine()
  if fieldValue == "" then
    im.Text(noValueString)
  else
    im.Text(fieldValue)
  end
  if im.BeginPopup("##" .. fieldName .. "DataBlockPopup") then
    im.PushID1("##" .. fieldName .. "DataBlockNameFilter")
    im.ImGuiTextFilter_Draw(dataBlockNameFilter, "", 200)
    im.PopID()
    im.SameLine()
    if im.Button("X###" .. fieldName, clearButtonSize) then
      im.ImGuiTextFilter_Clear(dataBlockNameFilter)
    end
    if im.IsItemHovered() then
      im.SetTooltip("Clear Search Filter")
    end
    im.BeginChild1(fieldName .. "DataBlockNames", filteredFieldPopupSize)

    local dbFieldType = worldEditorCppApi.findDerivedDatablockClassname(fieldType)
    local dbIsVisible = true

    for i, dbName in ipairs(dataBlockNames) do
      if im.ImGuiTextFilter_PassFilter(dataBlockNameFilter, dbName) then
        dbIsVisible = true
        if i ~= 1 then
          local dblock = Sim.findObjectByIdNoUpcast(dataBlocksTbl[dbName])
          if not dblock or not dblock:isSubClassOf(dbFieldType) then
            dbIsVisible = false
          end
        end

        if dbIsVisible then
          local isSelected = (fieldValue == dbName)
          if im.Selectable1(dbName, isSelected) then
            im.CloseCurrentPopup()
            fieldValue = dbName

            if fieldValue == noDataBlockString then
              fieldValue = ""
            end
            brushElementForestItemDataName = fieldValue
            brushElementForestItemDataChanged = true
          end
          if im.IsItemHovered() and string.len(dbName) >= tooltipLongTextLength then
            im.SetTooltip(dbName)
          end
          if isSelected then
            -- set the initial focus when opening the combo
            im.SetItemDefaultFocus()
          end
        end

      end
    end
    im.EndChild()
    im.EndPopup()
  end

  local size = im.GetContentRegionAvailWidth()
  var.meshPreviewDimRdr.point = Point2I(0, 0)
  var.meshPreviewDimRdr.extent = Point2I(size,size)
  var.meshPreviewRenderSize[1] = size
  var.meshPreviewRenderSize[2] = size
  var.meshPreview:renderWorld(var.meshPreviewDimRdr)
  im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(0,0))
  if im.BeginChild1(fieldName .. "MeshPreviewChild", im.ImVec2(size,size), true, im.WindowFlags_NoScrollWithMouse) then
    var.meshPreview:ImGui_Image(var.meshPreviewRenderSize[1],var.meshPreviewRenderSize[2])
    im.EndChild()
  end
  im.PopStyleVar()

  if brushElementForestItemDataChanged then
    brushElementForestItemDataChanged = false
    return {fieldValue = brushElementForestItemDataName, editEnded = true}
  end

end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(220,320), nil, true)
  editor.registerModalWindow("noForestMsgDlg")
  editor.registerModalWindow("noForestBrushGroupMsgDlg")
  editor.registerInspectorTypeHandler("forestItem", assetInspectorGuiForestItem)
  editor.registerCustomFieldInspectorEditor("TSForestItemData", "shapeFile", forestItemShapeFileCustomFieldEditor)
  editor.registerCustomFieldInspectorEditor("ForestBrushElement", "ForestItemData", brushElementForestItemDataCustomFieldEditor)
  editor.editModes.forestToolsEditMode =
  {
    displayName = editModeName,
    onUpdate = forestToolsEditModeUpdate,
    onActivate = forestEditModeActivate,
    onDeactivate = forestEditModeDeactivate,
    onToolbar = forestToolsEditModeToolbar,
    onDeselect = onDeselect,
    onDeleteSelection = onDeleteSelection,
    onDuplicate = onDuplicate,
    onCopy = onCopy,
    onPaste = onPaste,
    actionMap = "forestTools", -- if available, not required
    icon = editor.icons.create_forest,
    iconTooltip = "Forest Tools",
    hideObjectIcons = true,
    getLegendCurrentActionNames = function()
      return var.legendCurrentActionNames
    end,
  }
  initialize()
  setBrushSize()
  setBrushPressure()
  setBrushHardness()
  initializeDataBlockTables()
end

local function onEditorAfterSaveLevel()
  forest = core_forest.getForestObject()
  -- log('I', '', 'forestEditor.onEditorAfterSaveLevel()')
  if var.dirtyBrushes == true then
    Sim.serializeToLineObjectsFile('ForestBrushGroup', editor.levelPath .. 'main.forestbrushes4.json')
    var.dirtyBrushes = false
  end

  if editor.forestDirty and forest then
    forest:saveForest()
    editor.forestDirty = false
  end

  for _, item in ipairs(var.forestItemData) do
    local obj = scenetree.findObjectById(item.id)
    if obj and editor.isDataBlockDirty(obj) then
      obj:setName(obj.name)
      editor.saveDataBlockToFile(obj)
    end
  end
end

local function onEditorInspectorFieldChanged(selectedIds, fieldName, fieldValue, arrayIndex)
  if tableSize(selectedIds) == 1 then
    local object = scenetree.findObjectById(selectedIds[1])
    if object and object:getClassName() == "ForestBrushElement" or object:getClassName() == "ForestBrush" then
      var.dirtyBrushes = true
    end
    local fieldNameLower = string.lower(fieldName)
    if object and object:getClassName() == "TSForestItemData" and fieldNameLower == "shapefile" then
      local shapeFilename = tostring(object.shapeFile)
      var.meshPreview:setObjectModel(shapeFilename)
      var.meshPreview:fitToShape()
      -- setRenderState args: ghost, nodes, bounds, objbox, col, grid
      var.meshPreview:setRenderState(false,false,false,false,false,true)
    elseif object and object:getClassName() == "ForestBrushElement" and fieldNameLower == "forestitemdata" then
      local forestItemData = Sim.findObjectByIdNoUpcast(dataBlocksTbl[object.forestItemData:getName()])
      if forestItemData then
        local shapeFilename = tostring(forestItemData.shapeFile)
        var.meshPreview:setObjectModel(shapeFilename)
        var.meshPreview:fitToShape()
        -- setRenderState args: ghost, nodes, bounds, objbox, col, grid
        var.meshPreview:setRenderState(false,false,false,false,false,true)
      end
    end
  end
end

local function onEditorRegisterPreferences(prefsRegistry)
  prefsRegistry:registerCategory("forestEditor")
  prefsRegistry:registerSubCategory("forestEditor", "general", nil,
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {brushSize = {"float", 5}},
    {brushSizeChangeIntervalWithKeys = {"float", 0.001, "When using [ ] keys to resize brush, time in seconds between two steps", nil, 0.0001, 1}},
    {brushSizeChangeStepWithKeys = {"float", 0.5, "When using [ ] keys to resize brush", nil, 0.01, 100}},
    {brushSizeChangeStepWithWheel = {"float", 1, "When using mouse wheel to resize brush", nil, 0.01, 100}},
    {brushPressureChangeStepWithKeys = {"float", 5, "When using [ ] keys to resize brush", nil, 0.01, 100}},
    {brushPressureChangeStepWithWheel = {"float", 5, "When using mouse wheel to resize brush", nil, 0.01, 100}},
    {brushPressure = {"float", 10, nil, "Brush Density"}},
    {brushHardness = {"float", 100}},
    {toolWorkingDistance = {"float", 2000, "Max. working distance when using forest tool", nil, 1000, 50000}},
  })
end

local function onEditorAxisGizmoModeChanged(mode)
  if not editor.editMode or (editor.editMode.displayName ~= editModeName) then
    return
  end
  if not var.selectedTool or var.selectedTool.label ~= "select" then
    selectToolByName("select")
  end
end

local function selectBrushByIndex(index)
  selectTool(var.brushes[index])
end

local function onDeserialize(data)
  deserializeBrushes = false
end

local function onSerialize()
  return true -- this is just so onDeserialize will be triggered on a lua reload
end

-- hooks
M.onEditorInitialized = onEditorInitialized
M.onEditorGui = onEditorGui
M.onEditorAfterSaveLevel  = onEditorAfterSaveLevel
M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onEditorAxisGizmoAligmentChanged = onEditorAxisGizmoAligmentChanged
M.onEditorAxisGizmoModeChanged = onEditorAxisGizmoModeChanged
M.onEditorInspectorFieldChanged = onEditorInspectorFieldChanged
M.onDeserialize = onDeserialize
M.onSerialize = onSerialize

M.changeBrush = changeBrush
M.selectBrushByIndex = selectBrushByIndex
M.beginChangeBrushSizeWithKeys = function (direction) changeBrushSizeAutoRepeatOn = true changeBrushSizeTimer = 0 changeBrushSizeDirection = direction end
M.endChangeBrushSizeWithKeys = function () changeBrushSizeAutoRepeatOn = false changeBrushSizeTimer = 0 end
M.selectForestItems = selectForestItems
M.selectToolByName = selectToolByName

return M