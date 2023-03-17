-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local ffi = require('ffi')
local imgui = ui_imgui
local C = {}

local globalsInitialized = false
local comboMenuOpen = false
local inputTextShortStringMaxSize = 1024
local differentValuesColor = imgui.ImVec4(1, 0.2, 0, 1)
local arrayHeaderBgColor = imgui.ImVec4(0.04, 0.15, 0.1, 1)
local annotationsTbl = nil
local annotations = {}
local maxGroupCount = 500
local dataBlocksTbl = {}
local dataBlockNames = {}
local noDataBlockString = "<None>"
local noValueString = "<None>"
local noAnnotationString = "<None>"
local minFloatValue = -1000000000
local maxFloatValue = 1000000000
local filteredFieldPopupSize = imgui.ImVec2(500, 500)
local tooltipLongTextLength = 70
local floatFormat = "%0.2f"
local clearButtonSize = imgui.ImVec2(24, 24)
local simSetNameFilter = imgui.ImGuiTextFilter()
local dataBlockNameFilter = imgui.ImGuiTextFilter()
local simSetWindowFieldId
local texObjs = {}
local customFieldEditors = {}
local customFieldFilters = {}
local fieldValueCached = nil
local filterTypes = {"Name", "Tag"}
local filterTypeIndex = 1
local json
local loadedTextures = 0

local copyPasteMenu = {
  open = false,
  pos = nil,
  fieldName = nil
}

local PI = 3.14159265358979323846

local function degToRad(d)
  return (d * PI) / 180.0
end

local function radToDeg(r)
  return (r * 180.0) / PI;
end

local function jsonDecodeSilent(content, context)
  if not json then json = require("json") end
  local state, data = xpcall(function() return json.decode(content) end, debug.traceback)
  if state == false then
    return nil
  end
  return data
end

local function setCopyPasteMenu(fieldName, fieldType, fieldValue, arrayIndex, customData, pasteCallback, contextMenuUI)
  if imgui.IsItemHovered() and imgui.IsMouseClicked(1) then
    copyPasteMenu.open = true
    copyPasteMenu.pos = imgui.GetMousePos()
    copyPasteMenu.fieldName = fieldName
    copyPasteMenu.fieldType = fieldType
    copyPasteMenu.fieldValue = fieldValue
    copyPasteMenu.arrayIndex = arrayIndex
    copyPasteMenu.customData = customData
    copyPasteMenu.pasteCallback = pasteCallback -- pasteCallback(fieldName, fieldValue, arrayIndex, customData)
    copyPasteMenu.contextMenuUI = contextMenuUI
  end
end

local function handleCopyPasteMenu()
  if copyPasteMenu.open then
    imgui.SetNextWindowPos(copyPasteMenu.pos)
    imgui.Begin("ValueInspectorCopyPasteMenu", nil, imgui.WindowFlags_NoCollapse + imgui.WindowFlags_AlwaysAutoResize + imgui.WindowFlags_NoResize + imgui.WindowFlags_NoTitleBar)
    if imgui.Button("Copy Value") then
      local copiedValue = copyPasteMenu.fieldValue
      local copiedFieldType = copyPasteMenu.fieldType
      copyPasteMenu.open = false
      setClipboard(jsonEncode({copiedValue = copiedValue, copiedFieldType = copiedFieldType}))
    end

    -- we always decode json from system cliboard to use it for disabling the Paste item if field name not compatible
    local tbl = jsonDecodeSilent(getClipboard(), "ValueInspectorCopyPasteMenu")
    local isPasteDisabled = not tbl or copyPasteMenu.fieldType ~= tbl.copiedFieldType

    local destIsString = copyPasteMenu.fieldType == "string"
      or copyPasteMenu.fieldType == "caseString"
      or copyPasteMenu.fieldType == "BString"
      or copyPasteMenu.fieldType == "stdString"

    if not destIsString and isPasteDisabled then
      imgui.BeginDisabled()
    end
    if imgui.Button("Paste Value") and tbl and tbl.copiedValue and copyPasteMenu.pasteCallback then
      copyPasteMenu.open = false
      copyPasteMenu.pasteCallback(copyPasteMenu.fieldName, tbl.copiedValue, copyPasteMenu.arrayIndex, copyPasteMenu.customData)
    end
    if not destIsString and isPasteDisabled then
      imgui.EndDisabled()
    end

    -- show some custom menu items also, if available
    if copyPasteMenu.contextMenuUI then copyPasteMenu.contextMenuUI(copyPasteMenu) end

    if not imgui.IsWindowFocused() then
      copyPasteMenu.open = false
    end
    imgui.End()
  end
end

local function initializeAnnotationsTable()
  if AnnotationManager then
    annotationsTbl = AnnotationManager:getAnnotations()
    annotationsTbl[noAnnotationString] = {r = 0, g = 0, b = 0, a = 0}
    if annotationsTbl then
      local i = 1
      for key, _ in pairs(annotationsTbl) do
        annotations[i] = key
        i = i + 1
      end
    end
    table.sort(annotations)
  end
end

local function initializeDataBlocksTable()
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

local popupWasPositioned = false

function C:displaySimSetPopupList(objectSetArray, fieldName, fieldNameId, fieldValue, selectedIds, val, arrayIndex, className)
  if imgui.Button("  ...  ###" .. fieldNameId) then
    simSetWindowFieldId = fieldNameId
  end
  imgui.SameLine()
  if fieldValue == "" then
    imgui.Text(noValueString)
  else
    imgui.Text(fieldValue)
  end
  if not simSetWindowFieldId or simSetWindowFieldId ~= fieldNameId then return end

  if not popupWasPositioned then
    imgui.SetNextWindowPos(imgui.ImVec2(imgui.GetMousePos().x, imgui.GetMousePos().y))
    popupWasPositioned = true
  end

  if imgui.Begin(fieldNameId .. "SimSetPopup", nil, imgui.WindowFlags_NoTitleBar + imgui.WindowFlags_NoCollapse + imgui.WindowFlags_NoDocking) then
    imgui.PushID1(fieldNameId .. "SimSetNameFilter")
    imgui.ImGuiTextFilter_Draw(simSetNameFilter, "", 200)
    imgui.PopID()
    imgui.SameLine()
    if imgui.Button("X###" .. fieldNameId, clearButtonSize) then
      imgui.ImGuiTextFilter_Clear(simSetNameFilter)
    end
    if imgui.IsItemHovered() then
      imgui.SetTooltip("Clear Search Filter")
    end
    imgui.BeginChild1(fieldNameId .. "SetObjNames", filteredFieldPopupSize)

    local sortedObjectNameAndClass = {}

    for _, objectSet in ipairs(objectSetArray) do
      for i = 0, objectSet:size() - 1 do
        table.insert(sortedObjectNameAndClass,{ name = objectSet:at(i):getName(), className = objectSet:at(i):getClassName()})
      end
    end

    table.sort(sortedObjectNameAndClass, function(a, b) return a.name < b.name end)
    table.insert(sortedObjectNameAndClass, 1, { name = noValueString })

    for i = 1, tableSize(sortedObjectNameAndClass) do
      local objInfo = sortedObjectNameAndClass[i]
      if not className or objInfo.className == className or className == "" or not objInfo.className then
        local objName = objInfo.name
        if objName ~= "" and imgui.ImGuiTextFilter_PassFilter(simSetNameFilter, objName) or not objInfo.className then
          local isSelected = (fieldValue == objName) or (fieldValue == "" and not objInfo.className)
          if imgui.Selectable1(objName, isSelected) then
            fieldValue = objName
            if fieldValue == noValueString then
              fieldValue = ""
            end
            self.setValueCallback(fieldName, fieldValue, arrayIndex, val, true)
            simSetWindowFieldId = nil
            popupWasPositioned = false
          end
          --TODO: maybe something better for longer strings not fitting in the popup width
          if imgui.IsItemHovered() and string.len(objName) >= tooltipLongTextLength then
            imgui.SetTooltip(objName)
          end
          if isSelected then
            -- set the initial focus when opening the combo
            imgui.SetItemDefaultFocus()
          end
        end
      end
    end
    imgui.EndChild()
    if not imgui.IsWindowFocused(imgui.FocusedFlags_RootAndChildWindows) then
      simSetWindowFieldId = nil
      popupWasPositioned = false
    end
    imgui.End()
  end
end

local function getTexObj(absPath)
  if texObjs[absPath] == nil and loadedTextures < 5 then
    local texture = editor.texObj(absPath)
    loadedTextures = loadedTextures + 1
    if texture and not tableIsEmpty(texture) then
      texObjs[absPath] = texture
    else
      texObjs[absPath] = false
    end
  end

  return texObjs[absPath]
end

function C:displayMaterialPopupList(objectSet, fieldName, fieldNameId, fieldValue, selectedIds, val, arrayIndex, className)
  if imgui.Button("  ...  ###" .. fieldNameId) then
    simSetWindowFieldId = fieldNameId
  end
  imgui.SameLine()
  if fieldValue == "" then
    imgui.Text(noValueString)
  else
    imgui.Text(fieldValue)
  end

  if not simSetWindowFieldId or simSetWindowFieldId ~= fieldNameId then return end

  if not popupWasPositioned then
    imgui.SetNextWindowPos(imgui.ImVec2(imgui.GetMousePos().x, imgui.GetMousePos().y))
    popupWasPositioned = true
  end

  -- This emulates a popup window because BeginPopup doesnt work correctly with the "hovered" state of imgui windows
  local windowOpenPtr = imgui.BoolPtr(true)
  if imgui.Begin(fieldNameId .. "MaterialSetPopup", windowOpenPtr, imgui.WindowFlags_NoCollapse + imgui.WindowFlags_NoDocking) then
    loadedTextures = 0
    imgui.PushID1(fieldNameId .. "SimSetNameFilter")
    imgui.ImGuiTextFilter_Draw(simSetNameFilter, "", 200)
    imgui.PopID()
    imgui.SameLine()
    if imgui.Button("X###" .. fieldNameId, clearButtonSize) then
      imgui.ImGuiTextFilter_Clear(simSetNameFilter)
    end
    if imgui.IsItemHovered() then
      imgui.SetTooltip("Clear Search Filter")
    end
    imgui.SameLine()
    imgui.PushItemWidth(imgui.GetContentRegionAvailWidth())
    comboMenuOpen = false
    if imgui.BeginCombo('##filterTypes', filterTypes[filterTypeIndex]) then
      for i, type in ipairs(filterTypes) do
        if imgui.Selectable1(type) then
          filterTypeIndex = i
        end
      end
      comboMenuOpen = true
      imgui.EndCombo()
    end
    imgui.BeginChild1(fieldNameId .. "SetObjNames", filteredFieldPopupSize)
    --TODO: sort by name
    for i = 1, tableSize(objectSet) do
      local obj = objectSet[i]
      if not className or obj:getClassName() == className or className == "" then
        local filterPassed = false
        local objName = obj:getName()
        if filterTypeIndex == 1 then
          filterPassed = imgui.ImGuiTextFilter_PassFilter(simSetNameFilter, objName)
        else
          for tagId = 0, 2 do
            local tag = obj:getField("materialTag", tostring(tagId))
            if tag and imgui.ImGuiTextFilter_PassFilter(simSetNameFilter, tag) then
              filterPassed = true
              break
            end
          end
        end

        if objName ~= "" and filterPassed then
          local skipMaterial = false
          local isSelected = (fieldValue == objName)
          local clickedImage = false
          local mat = scenetree.findObject(objName)
          if mat then
            local imgPath = mat:getField("diffuseMap", 0)
            local absPath = imgPath
            -- Check if path is absolute or relative
            if absPath ~= "" then
              absPath = (string.find(absPath, "/") ~= nil and absPath or (mat:getPath() .. absPath))
            end
            local texture = getTexObj(absPath)
            if texture then
              if not (texture.texId == nil) then
                if imgui.ImageButton(
                  texture.texId,
                  imgui.ImVec2(32, 32),
                  imgui.ImVec2Zero,
                  imgui.ImVec2One,
                  1,
                  imgui.ImColorByRGB(255,255,255,255).Value,
                  imgui.ImColorByRGB(255,255,255,255).Value
                ) then
                  clickedImage = true
                end
                imgui.SameLine()
              end
            else
              skipMaterial = true
            end
            if not skipMaterial then
              if imgui.Selectable1(objName, isSelected) or clickedImage then
                fieldValue = objName
                if fieldValue == noValueString then
                  fieldValue = ""
                end
                self.setValueCallback(fieldName, fieldValue, arrayIndex, val, true)
                simSetWindowFieldId = nil
                popupWasPositioned = false
              end
              --TODO: maybe something better for longer strings not fitting in the popup width
              if imgui.IsItemHovered() and string.len(objName) >= tooltipLongTextLength then
                imgui.SetTooltip(objName)
              end
              if isSelected then
                -- set the initial focus when opening the combo
                imgui.SetItemDefaultFocus()
              end
            end
          end
        end
      end
    end
    imgui.EndChild()
    if not comboMenuOpen and not imgui.IsWindowFocused(imgui.FocusedFlags_RootAndChildWindows) then
      simSetWindowFieldId = nil
      popupWasPositioned = false
    end
    imgui.End()
    if not windowOpenPtr[0] then
      simSetWindowFieldId = nil
      popupWasPositioned = false
    end
  end
end

function C:init()
  self.inputTextShortStringMaxSize = inputTextShortStringMaxSize
  self.inspectorName = "default"
  self.inputTextValue = imgui.ArrayChar(inputTextShortStringMaxSize)
  self.inputLongTextValue = nil
  self.inputLongTextSize = 0
  self.input4IntValue = imgui.ArrayInt(4)
  self.input4FloatValue = imgui.ArrayFloat(4)
  self.inputBoolValue = imgui.BoolPtr(false)
  self.comboIndex = imgui.IntPtr(0)
  self.editEnded = imgui.BoolPtr(false)
  self.setValueCallback = nil -- setValueCallback(fieldName, fieldValue, arrayIndex, customData, editEndedBool)
  self.differentValuesFields = {}
  self.selectionClassName = "" -- the class name of the inspected object selection, used to find custom field editors
  self.addTypeToTooltip = false
end

local function findCustomFieldEditor(fieldName, className)
  local fieldEd = customFieldEditors[fieldName .. className]
  return fieldEd
end

local function findCustomFieldFilter(fieldName, className)
  local fieldFilter = customFieldFilters[fieldName .. className]
  return fieldFilter
end

local function registerCustomFieldEditor(className, fieldName, uiCallback, useArray)
  local key = fieldName .. className
  customFieldEditors[key] = {className = className, fieldName = fieldName, uiCallback = uiCallback, useArray = useArray}
end

local function unregisterCustomFieldEditor(className, fieldName)
  local key = fieldName .. className
  customFieldEditors[key] = nil
end

local function registerCustomFieldFilter(className, fieldName, uiCallback)
  local key = fieldName .. className
  customFieldFilters[key] = {className = className, fieldName = fieldName, uiCallback = uiCallback}
end

local function unregisterCustomFieldFilter(className, fieldName)
  local key = fieldName .. className
  customFieldFilters[key] = nil
end

function C:reinitializeTables()
  globalsInitialized = false
end

function C:initializeTables(force)
  if not globalsInitialized or force then
    initializeAnnotationsTable()
    initializeDataBlocksTable()
    globalsInitialized = true
  end
end

function C:setSimSetWindowFieldId(id)
  simSetWindowFieldId = id
end

function C:deleteTexObjs()
  texObjs = {}
end

local function drawInputFloat3ColoredIndicators(windowPos, cursorPos)
  local drawlist = imgui.GetWindowDrawList()
  local coloredBGHeight = math.ceil(imgui.GetFontSize())
  local textWidth = imgui.CalcTextSize("X").x
  local textPadding = imgui.GetFontSize() - textWidth
  local coloredBGWidth = math.ceil(imgui.GetFontSize()) - textPadding/2 - 4

  local coloredBG_StartPos_Y = windowPos.y + cursorPos.y - imgui.GetScrollY() + 3
  local coloredBG_EndPos_Y = coloredBG_StartPos_Y + coloredBGHeight - 6
  local textPadding_Y = coloredBG_StartPos_Y - 4
  local coloredBG_X_StartPos_X = windowPos.x + cursorPos.x + 2 * math.ceil(imgui.uiscale[0])
  local coloredBG_X_EndPos_X = coloredBG_X_StartPos_X + coloredBGWidth

  local coloredBG_Y_StartPos_X = coloredBG_X_StartPos_X + (imgui.GetContentRegionAvailWidth()/3)
  local coloredBG_Y_EndPos_X = coloredBG_Y_StartPos_X + coloredBGWidth

  local coloredBG_Z_StartPos_X = coloredBG_X_StartPos_X + (imgui.GetContentRegionAvailWidth()/3)*2
  local coloredBG_Z_EndPos_X = coloredBG_Z_StartPos_X + coloredBGWidth

  local p1_X_BG = imgui.ImVec2(coloredBG_X_StartPos_X, coloredBG_StartPos_Y)
  local p2_X_BG = imgui.ImVec2(coloredBG_X_EndPos_X, coloredBG_EndPos_Y)
  local color_X_BG = imgui.GetColorU322(imgui.ImVec4(0.7, 0.0, 0.0, 1.0))
  local p1_X_Text = imgui.ImVec2(coloredBG_X_StartPos_X + textPadding/4 - 2, textPadding_Y)

  local p1_Y_BG = imgui.ImVec2(coloredBG_Y_StartPos_X, coloredBG_StartPos_Y)
  local p2_Y_BG = imgui.ImVec2(coloredBG_Y_EndPos_X, coloredBG_EndPos_Y)
  local color_Y_BG = imgui.GetColorU322(imgui.ImVec4(0.0, 0.7, 0.0, 1.0))
  local p1_Y_Text = imgui.ImVec2(coloredBG_Y_StartPos_X + textPadding/4, textPadding_Y)

  local p1_Z_BG = imgui.ImVec2(coloredBG_Z_StartPos_X, coloredBG_StartPos_Y)
  local p2_Z_BG = imgui.ImVec2(coloredBG_Z_EndPos_X, coloredBG_EndPos_Y)
  local color_Z_BG = imgui.GetColorU322(imgui.ImVec4(0.0, 0.0, 1.0, 1.0))
  local p1_Z_Text = imgui.ImVec2(coloredBG_Z_StartPos_X + textPadding/4, textPadding_Y)

  local labelTextColor = imgui.GetColorU322(imgui.ImVec4(1.0, 1.0, 1.0, 1.0))

  imgui.ImDrawList_AddRectFilled(drawlist, p1_X_BG, p2_X_BG, color_X_BG)
  imgui.ImDrawList_AddText1(drawlist, p1_X_Text, labelTextColor, "X", nil)

  imgui.ImDrawList_AddRectFilled(drawlist, p1_Y_BG, p2_Y_BG, color_Y_BG)
  imgui.ImDrawList_AddText1(drawlist, p1_Y_Text, labelTextColor, "Y", nil)

  imgui.ImDrawList_AddRectFilled(drawlist, p1_Z_BG, p2_Z_BG, color_Z_BG)
  imgui.ImDrawList_AddText1(drawlist, p1_Z_Text, labelTextColor, "Z", nil)
end

function C:valueEditorGui(fieldName, fieldValue, arrayIndex, fieldLabel, fieldDesc, fieldType, fieldTypeName, customData, pasteCallback, contextMenuUI)
  floatFormat = "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f"
  local fieldNameId = "##" .. fieldName .. (arrayIndex or "")
  local isDifferent = self.differentValuesFields[fieldName] == true
  if isDifferent then
    imgui.PushStyleColor2(imgui.Col_Text, differentValuesColor)
    if fieldType ~= "ColorF" and fieldType ~= "ColorI" then
      fieldValue = ""
    end
  end
  imgui.PushID1(self.inspectorName .. "_FIELDS_COLUMN")
  imgui.Columns(2, self.inspectorName .. "FieldsColumn")
  imgui.Text(fieldLabel)

  setCopyPasteMenu(fieldName, fieldType, fieldValue, arrayIndex, customData, pasteCallback, contextMenuUI)

  if imgui.IsItemHovered() and fieldDesc and fieldDesc ~= "" then
    if self.addTypeToTooltip then fieldDesc = fieldDesc .. "\n\nType: " .. fieldType .. "\nTypeName: " .. fieldTypeName end
    imgui.SetTooltip(fieldDesc)
  end

  imgui.NextColumn()
  imgui.PushItemWidth(imgui.GetContentRegionAvailWidth())
  -- check if we have a custom inspector field editor for this class and field name

  local fieldEd = findCustomFieldEditor(fieldName, self.selectionClassName)
  local fieldFilter = findCustomFieldFilter(fieldName, self.selectionClassName)

  if fieldEd then
    local retInfo = fieldEd.uiCallback(self.selectedIds, fieldValue, fieldName, fieldLabel, fieldDesc, fieldType, fieldTypeName, customData, pasteCallback, contextMenuUI)
    if retInfo then
      fieldValue = retInfo.fieldValue
      self.setValueCallback(fieldName, fieldValue, arrayIndex, customData, retInfo.editEnded)
    end
  elseif fieldTypeName == "TypeMaterialName" then
    local materialSet = {}
    if fieldFilter then
      local filteredSet = fieldFilter.uiCallback(Sim.getMaterialSet())
      materialSet = filteredSet
    else
      local materials = Sim.getMaterialSet()
      for i = 0, materials:size() - 1 do
        local mat = materials:at(i)
        table.insert(materialSet, mat)
      end
    end
    self:displayMaterialPopupList(materialSet, fieldName, fieldNameId, fieldValue, self.selectedIds, customData)
  elseif fieldTypeName == "TypeCubemapName" or fieldTypeName == "TypeCubemapData" then
    self:displaySimSetPopupList({Sim.getRootGroup(), Sim.findObject("LevelLoadingGroup")}, fieldName, fieldNameId, fieldValue, self.selectedIds, customData, 0, "CubemapData")
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldTypeName == "TypeCommand" then
    if imgui.Button(fieldValue:sub(1,20)) then
      editor.newTextEditorInstance(self.selectedIds, fieldName)
    end
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "SimPersistId" then
    local obj = Sim.findObjectByPersistID(fieldValue)
    if obj then
      imgui.Text("Name:") imgui.SameLine()
      imgui.Text(obj.name or "<none>")
      imgui.Text("InternalName:") imgui.SameLine()
      imgui.Text(obj.internalName or "<none>")
      imgui.Text("ID:") imgui.SameLine()
      imgui.Text(tostring(obj:getId()))
      imgui.Text("PID:") imgui.SameLine()
      imgui.Text(fieldValue)
    end
    if imgui.Button("Pick...") then
      editor.pickingLinkTo = {}
      editor.pickingLinkTo.child = Sim.findObjectById(self.selectedIds[1])
      editor.pickingLinkTo.selectionObjectIds = deepcopy(self.selectedIds)
    end imgui.SameLine()
    if imgui.Button("Select") then
      if obj then
        editor.selectObjectById(obj:getId())
      end
    end imgui.SameLine()
    if imgui.Button("Clear") then
      self.setValueCallback(fieldName, "", arrayIndex, customData, true)
    end
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldTypeName == "TypeString"
      or fieldTypeName == "TypeName"
      or fieldTypeName == "TypeRealString"
      or fieldTypeName == "TypeF32Vector"
      or fieldTypeName == "TypeS32Vector"
      or fieldTypeName == "TypeBoolVector"
      or fieldType == "string"
      or fieldType == "caseString"
      or fieldType == "BString"
      or fieldType == "stdString"
    then
    local fieldLen = string.len(fieldValue)
    local oldStrRef = nil
    if fieldLen >= inputTextShortStringMaxSize then
      if self.inputLongTextSize < fieldLen then
        self.inputLongTextSize = fieldLen + 1
        self.inputLongTextValue = imgui.ArrayChar(fieldLen + 1)
      end
      oldStrRef = self.inputTextValue
      self.inputTextValue = self.inputLongTextValue
    end
    if fieldValue ~= nil then
      ffi.copy(self.inputTextValue, fieldValue)
    else
      ffi.copy(self.inputTextValue, "")
    end
    local changed = editor.uiInputText(fieldNameId, self.inputTextValue, ffi.sizeof(self.inputTextValue), nil, nil, nil, self.editEnded)

    if changed then
      fieldValueCached = ffi.string(self.inputTextValue)
    end
    if self.editEnded[0] then
      fieldValue = ffi.string(self.inputTextValue)
      local val = fieldValueCached or fieldValue
      local changeAllowed = true
      if fieldName == "name" then
        if scenetree.findObject(val) then
          local msg = "'" .. val .. "' already exists in the scene, please choose another name"
          editor.logWarn(msg)
          editor.showNotification(msg)
          editor.setStatusBar(msg, function() if ui_imgui.Button("Close##duplicate") then editor.hideStatusBar() end end)
          changeAllowed = false
        end
      end
      if changeAllowed then
        -- we call this directly, if the callback nil, then we will get an error in the console, which is visible
        self.setValueCallback(fieldName, val, arrayIndex, customData, self.editEnded[0])
      end
    end
    if nil ~= oldStrRef then self.inputTextValue = oldStrRef end
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "float" or fieldType == "TypeF32" or fieldType == "TypeF64" then
    if fieldValue == "" then
      fieldValue = "0"
    end
    self.input4FloatValue[0] = tonumber(fieldValue)

    local res = false
    if editor.getPreference("ui.general.useSlidersInInspector") then
      res = editor.uiDragFloat(fieldNameId, self.input4FloatValue, 0.1, nil, nil, floatFormat, nil, self.editEnded)
    else
      res = editor.uiInputFloat(fieldNameId, self.input4FloatValue, 0.1, 0.5, floatFormat, nil, self.editEnded)
    end

    if res then
      fieldValue = tostring(self.input4FloatValue[0])
      fieldValueCached = fieldValue
      if editor.getPreference("ui.general.useSlidersInInspector") then
        if not self.startValues and self.selectedIds then
          self.startValues = {}
          for _, id in ipairs(self.selectedIds) do
            table.insert(self.startValues, editor.getFieldValue(id, fieldName, arrayIndex) or "")
          end
        end
        customData.startValues = self.startValues
        self.setValueCallback(fieldName, fieldValue, arrayIndex, customData, false)
      end
    end

    if self.editEnded[0] then
      fieldValue = tostring(self.input4FloatValue[0])
      customData.startValues = self.startValues
      self.setValueCallback(fieldName, fieldValueCached or fieldValue, arrayIndex, customData, self.editEnded[0])
      self.startValues = nil
    end
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "int" or fieldType == "char" or fieldType == "TypeS32" or fieldType == "TypeS8" then
    if fieldValue == "" then
      fieldValue = "0"
    end
    self.input4IntValue[0] = tonumber(fieldValue)

    local res = false
    if editor.getPreference("ui.general.useSlidersInInspector") then
      res = editor.uiDragInt(fieldNameId, self.input4IntValue, 1, nil, nil, nil, nil, self.editEnded)
    else
      res = editor.uiInputInt(fieldNameId, self.input4IntValue, 1, 5, nil, self.editEnded)
    end

    if res then
      fieldValue = tostring(self.input4IntValue[0])
      fieldValueCached = fieldValue
      if editor.getPreference("ui.general.useSlidersInInspector") then
        if not self.startValues and self.selectedIds then
          self.startValues = {}
          for _, id in ipairs(self.selectedIds) do
            table.insert(self.startValues, editor.getFieldValue(id, fieldName, arrayIndex) or "")
          end
        end
        customData.startValues = self.startValues
        self.setValueCallback(fieldName, fieldValue, arrayIndex, customData, false)
      end
    end

    if self.editEnded[0] then
      fieldValue = tostring(self.input4IntValue[0])
      customData.startValues = self.startValues
      self.setValueCallback(fieldName, fieldValueCached or fieldValue, arrayIndex, customData, self.editEnded[0])
      self.startValues = nil
    end
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "bool" or fieldType == "flag" then
    if fieldValue == "" then
      fieldValue = "0"
    end
    self.inputBoolValue[0] = fieldValue == "1" or fieldValue == "true"
    if imgui.Checkbox(fieldNameId, self.inputBoolValue) then
      self.setValueCallback(fieldName, tostring(self.inputBoolValue[0]), arrayIndex, customData, true)
    end
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "filename" then
    local filename = ""
    local extensions = nil

    if fieldTypeName == "TypeShapeFilename" then extensions = {"Collada", {".dae"}} end
    if fieldTypeName == "TypeImageFilename" then extensions = {"Images", {".png", ".dds", ".jpg"}} end
    if fieldTypeName == "TypePrefabFilename" then extensions = {"Prefabs", {".prefab", ".prefab.json"}} end
    if imgui.Button("  ...  " .. fieldNameId) then
      local dir, fn, ext = path.split(fieldValue)
      local fileSpec = {{"All Files","*"}}
      if extensions then fileSpec = {extensions, {"All Files","*"}} end
      editor_fileDialog.openFile(function(data)
        if data.filepath ~= "" then
          fieldValue = data.filepath
          self.setValueCallback(fieldName, fieldValue, arrayIndex, customData, self.editEnded[0] or changed)
        end
      end, fileSpec, false, dir)
    end
    imgui.SameLine()
    imgui.PushItemWidth(imgui.GetContentRegionAvailWidth())
    if fieldValue ~= nil then
      ffi.copy(self.inputTextValue, fieldValue)
    end
    if editor.uiInputText(fieldNameId, self.inputTextValue, ffi.sizeof(self.inputTextValue), nil, nil, nil, self.editEnded) and self.editEnded[0] then
      fieldValue = ffi.string(self.inputTextValue)
      self.setValueCallback(fieldName, fieldValue, arrayIndex, customData, self.editEnded[0])
    end
    imgui.PopItemWidth()
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "Point3F" or fieldType == "vec3" or fieldType == "MatrixPosition" then
    local vec = stringToTable(fieldValue)
    if vec[1] == nil then vec[1] = "0" end
    if vec[2] == nil then vec[2] = "0" end
    if vec[3] == nil then vec[3] = "0" end
    self.input4FloatValue[0] = tonumber(vec[1])
    self.input4FloatValue[1] = tonumber(vec[2])
    self.input4FloatValue[2] = tonumber(vec[3])

    local drawColoredLabelIndicator = false
    local windowPos = imgui.GetWindowPos()
    local cursorPos = imgui.GetCursorPos()
    if customData and customData.coloredLabelIndicator then drawColoredLabelIndicator = true end
    if drawColoredLabelIndicator then imgui.PushStyleVar2(imgui.StyleVar_FramePadding, imgui.ImVec2(imgui.GetFontSize(), 0)) end
    if editor.uiInputFloat3(fieldNameId, self.input4FloatValue, floatFormat, imgui.InputTextFlags_None, self.editEnded) then
      fieldValue =
      tostring(self.input4FloatValue[0]) ..
      " " .. tostring(self.input4FloatValue[1]) .. " " .. tostring(self.input4FloatValue[2])
      fieldValueCached = fieldValue
    end
    if drawColoredLabelIndicator then
      imgui.PopStyleVar()
      drawInputFloat3ColoredIndicators(windowPos, cursorPos)
    end

    if self.editEnded[0] then
      fieldValue =
        tostring(self.input4FloatValue[0]) ..
        " " .. tostring(self.input4FloatValue[1]) .. " " .. tostring(self.input4FloatValue[2])
      self.setValueCallback(fieldName, fieldValueCached or fieldValue, arrayIndex, customData, self.editEnded[0])
    end
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "Point2F" then
    local vec = stringToTable(fieldValue)
    if vec[1] == nil then vec[1] = "0" end
    if vec[2] == nil then vec[2] = "0" end
    self.input4FloatValue[0] = tonumber(vec[1])
    self.input4FloatValue[1] = tonumber(vec[2])

    if editor.uiInputFloat2(fieldNameId, self.input4FloatValue, floatFormat, nil, self.editEnded) then
      fieldValue = tostring(self.input4FloatValue[0]) .. " " .. tostring(self.input4FloatValue[1])
      fieldValueCached = fieldValue
    end

    if self.editEnded[0] then
      fieldValue = tostring(self.input4FloatValue[0]) .. " " .. tostring(self.input4FloatValue[1])
      self.setValueCallback(fieldName, fieldValueCached or fieldValue, arrayIndex, customData, self.editEnded[0])
    end
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "EaseF" then
    local vec = stringToTable(fieldValue)
    if vec[1] == nil then vec[1] = "0" end
    if vec[2] == nil then vec[2] = "0" end
    if vec[3] == nil then vec[3] = "0" end
    if vec[4] == nil then vec[4] = "0" end
    self.input4FloatValue[0] = tonumber(vec[1])
    self.input4FloatValue[1] = tonumber(vec[2])
    self.input4FloatValue[2] = tonumber(vec[3])
    self.input4FloatValue[3] = tonumber(vec[4])

    if editor.uiInputFloat4(fieldNameId, self.input4FloatValue, floatFormat, nil, self.editEnded) then
      fieldValue = tostring(self.input4FloatValue[0]) .. " " .. tostring(self.input4FloatValue[1]) .. " " .. tostring(self.input4FloatValue[2]) .. " " .. tostring(self.input4FloatValue[3])
      fieldValueCached = fieldValue
    end

    if self.editEnded[0] then
      fieldValue = tostring(self.input4FloatValue[0]) .. " " .. tostring(self.input4FloatValue[1]) .. " " .. tostring(self.input4FloatValue[2]) .. " " .. tostring(self.input4FloatValue[3])
      self.setValueCallback(fieldName, fieldValueCached or fieldValue, arrayIndex, customData, self.editEnded[0])
    end
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "Point2I" then
    local vec = stringToTable(fieldValue)
    if vec[1] == nil then vec[1] = "0" end
    if vec[2] == nil then vec[2] = "0" end
    self.input4IntValue[0] = tonumber(vec[1])
    self.input4IntValue[1] = tonumber(vec[2])

    if editor.uiInputInt2(fieldNameId, self.input4IntValue, nil, self.editEnded) then
      fieldValue = tostring(self.input4IntValue[0]) .. " " .. tostring(self.input4IntValue[1])
      fieldValueCached = fieldValue
    end

    if self.editEnded[0] then
      fieldValue = tostring(self.input4IntValue[0]) .. " " .. tostring(self.input4IntValue[1])
      self.setValueCallback(fieldName, fieldValueCached or fieldValue, arrayIndex, customData, self.editEnded[0])
    end
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "EulerRotation" then
      local vec = stringToTable(fieldValue)
      if vec[1] == nil then vec[1] = "0" end
      if vec[2] == nil then vec[2] = "0" end
      if vec[3] == nil then vec[3] = "0" end

      self.input4FloatValue[0] = radToDeg(vec[1])
      self.input4FloatValue[1] = radToDeg(vec[2])
      self.input4FloatValue[2] = radToDeg(vec[3])

      local windowPos = imgui.GetWindowPos()
      local cursorPos = imgui.GetCursorPos()
      local drawColoredLabelIndicator = false
      if customData and customData.coloredLabelIndicator then drawColoredLabelIndicator = true end
      if drawColoredLabelIndicator then imgui.PushStyleVar2(imgui.StyleVar_FramePadding, imgui.ImVec2(imgui.GetFontSize(), 0)) end
      if editor.uiInputFloat3(fieldNameId, self.input4FloatValue, floatFormat, nil, self.editEnded) then
        fieldValue =
               tostring(degToRad(self.input4FloatValue[0])) ..
        " " .. tostring(degToRad(self.input4FloatValue[1])) ..
        " " .. tostring(degToRad(self.input4FloatValue[2]))
        fieldValueCached = fieldValue
      end
      if drawColoredLabelIndicator then
        imgui.PopStyleVar()
        drawInputFloat3ColoredIndicators(windowPos, cursorPos)
      end

      if self.editEnded[0] then
        fieldValue =
               tostring(degToRad(self.input4FloatValue[0])) ..
        " " .. tostring(degToRad(self.input4FloatValue[1])) ..
        " " .. tostring(degToRad(self.input4FloatValue[2]))
        self.setValueCallback(fieldName, fieldValueCached or fieldValue, arrayIndex, customData, self.editEnded[0])
      end
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "Point4F" then
    local vec = stringToTable(fieldValue)
    if vec[1] == nil then vec[1] = "0" end
    if vec[2] == nil then vec[2] = "0" end
    if vec[3] == nil then vec[3] = "0" end
    if vec[4] == nil then vec[4] = "0" end
    self.input4FloatValue[0] = tonumber(vec[1])
    self.input4FloatValue[1] = tonumber(vec[2])
    self.input4FloatValue[2] = tonumber(vec[3])
    self.input4FloatValue[3] = tonumber(vec[4])

    if editor.uiInputFloat4(fieldNameId, self.input4FloatValue, floatFormat, nil, self.editEnded) then
      fieldValue =
        tostring(self.input4FloatValue[0]) ..
        " " .. tostring(self.input4FloatValue[1]) ..
        " " .. tostring(self.input4FloatValue[2]) ..
        " " .. tostring(self.input4FloatValue[3])
      fieldValueCached = fieldValue
    end

    if self.editEnded[0] then
      fieldValue =
        tostring(self.input4FloatValue[0]) ..
        " " .. tostring(self.input4FloatValue[1]) ..
        " " .. tostring(self.input4FloatValue[2]) ..
        " " .. tostring(self.input4FloatValue[3])
      self.setValueCallback(fieldName, fieldValueCached or fieldValue, arrayIndex, customData, self.editEnded[0])
    end
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "ColorF" then
    local color = ColorF(0, 0, 0, 0)
    color:setFromString(fieldValue)
    self.input4FloatValue[0] = color.r
    self.input4FloatValue[1] = color.g
    self.input4FloatValue[2] = color.b
    self.input4FloatValue[3] = color.a
    local flags = 0
    if editor.getPreference("ui.general.hexColorInput") then flags = imgui.ColorEditFlags_HEX end
    if editor.uiColorEdit4(fieldNameId, self.input4FloatValue, flags, self.editEnded) then
      fieldValue =
        tostring(self.input4FloatValue[0]) ..
        " " .. tostring(self.input4FloatValue[1]) ..
        " " .. tostring(self.input4FloatValue[2]) ..
        " " .. tostring(self.input4FloatValue[3])

      if not self.startValues and self.selectedIds then
        self.startValues = {}
        for _, id in ipairs(self.selectedIds) do
          table.insert(self.startValues, editor.getFieldValue(id, fieldName, arrayIndex) or "")
        end
      end

      if self.selectedIds then
        for _, id in ipairs(self.selectedIds) do
          customData.objectId = id
          self.setValueCallback(fieldName, fieldValue, arrayIndex, customData, false)
        end
      else
        self.setValueCallback(fieldName, fieldValue, arrayIndex, customData, false)
      end
    end
    if self.editEnded[0] and self.startValues then
      customData.startValues = self.startValues
      self.setValueCallback(fieldName, fieldValue, arrayIndex, customData, self.editEnded[0])
      self.startValues = nil
    end
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "ColorI" then
    local color = ColorI(0, 0, 0, 0)
    color:setFromString(fieldValue)
    self.input4FloatValue[0] = color.r / 255
    self.input4FloatValue[1] = color.g / 255
    self.input4FloatValue[2] = color.b / 255
    self.input4FloatValue[3] = color.a / 255
    local flags = 0
    if editor.getPreference("ui.general.hexColorInput") then flags = imgui.ColorEditFlags_HEX end
    if editor.uiColorEdit4(fieldNameId, self.input4FloatValue, flags, self.editEnded) then
      fieldValue =
        tostring(math.floor(self.input4FloatValue[0] * 255 + 0.5)) ..
        " " .. tostring(math.floor(self.input4FloatValue[1] * 255 + 0.5)) ..
        " " .. tostring(math.floor(self.input4FloatValue[2] * 255 + 0.5)) ..
        " " .. tostring(math.floor(self.input4FloatValue[3] * 255 + 0.5))

      if not self.startValues and self.selectedIds then
        self.startValues = {}
        for _, id in ipairs(self.selectedIds) do
          table.insert(self.startValues, editor.getFieldValue(id, fieldName, arrayIndex) or "")
        end
      end

      if self.selectedIds then
        for _, id in ipairs(self.selectedIds) do
          customData.objectId = id
          self.setValueCallback(fieldName, fieldValue, arrayIndex, customData, false)
        end
      else
        self.setValueCallback(fieldName, fieldValue, arrayIndex, customData, false)
      end
    end
    if self.editEnded[0] and self.startValues then
      customData.startValues = self.startValues
      self.setValueCallback(fieldName, fieldValue, arrayIndex, customData, self.editEnded[0])
      self.startValues = nil
    end
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "annotation" then
    local bgColor = nil
    if not annotationsTbl or not annotationsTbl[fieldValue] then
      bgColor = imgui.ImVec4(0, 0, 0, 1)
    else
      bgColor =
        imgui.ImVec4(
        annotationsTbl[fieldValue].r / 255,
        annotationsTbl[fieldValue].g / 255,
        annotationsTbl[fieldValue].b / 255,
        1.0)
    end
    imgui.ColorButton("Annotation color", bgColor, 0, imgui.ImVec2(25, 19))
    imgui.SameLine()
    imgui.PushItemWidth(imgui.GetContentRegionAvailWidth())
    if imgui.BeginCombo(fieldNameId, fieldValue, imgui.ComboFlags_HeightLargest) then
      for n = 1, tableSize(annotations) do
        local isSelected = (fieldValue == annotations[n]) and true or false
        local bgColor = nil
        if not annotationsTbl or not annotationsTbl[annotations[n]] then
          bgColor = imgui.ImVec4(0, 0, 0, 1)
        else
          bgColor =
            imgui.ImVec4(
            annotationsTbl[annotations[n]].r / 255,
            annotationsTbl[annotations[n]].g / 255,
            annotationsTbl[annotations[n]].b / 255,
            1.0)
        end
        imgui.ColorButton(fieldNameId, bgColor, 0, imgui.ImVec2(25, 19))
        imgui.SameLine()
        if imgui.Selectable1(annotations[n], isSelected) then
          fieldValue = annotations[n]
          if noAnnotationString == fieldValue then
            fieldValue = ""
          end
          self.setValueCallback(fieldName, fieldValue, arrayIndex, customData, true)
        end
        if isSelected then
          -- set the initial focus when opening the combo
          imgui.SetItemDefaultFocus()
        end
      end
      imgui.EndCombo()
    end
    imgui.PopItemWidth()
  -----------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "SFXSource" then
    self:displaySimSetPopupList({SFXSystem.getSFXSources()}, fieldName, fieldNameId, fieldValue, self.selectedIds, customData)
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "SFXAmbience" then
    self:displaySimSetPopupList({Sim.getSFXAmbienceSet()}, fieldName, fieldNameId, fieldValue, self.selectedIds, customData)
-------------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "SFXState" then
    self:displaySimSetPopupList({Sim.getSFXStateSet()}, fieldName, fieldNameId, fieldValue, self.selectedIds, customData)
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "SFXParameter" then
    self:displaySimSetPopupList({Sim.getSFXParameterGroup()}, fieldName, fieldNameId, fieldValue, self.selectedIds, customData)
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "SFXTrack" then
    self:displaySimSetPopupList({Sim.getSFXTrackSet()}, fieldName, fieldNameId, fieldValue, self.selectedIds, customData)
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "SFXDescription" then
    self:displaySimSetPopupList({Sim.getSFXDescriptionSet()}, fieldName, fieldNameId, fieldValue, self.selectedIds, customData)
  -------------------------------------------------------------------------------------------------------------------------
  elseif fieldType == "SFXEnvironment" then
    self:displaySimSetPopupList({Sim.getSFXEnvironmentSet()}, fieldName, fieldNameId, fieldValue, self.selectedIds, customData)
  -------------------------------------------------------------------------------------------------------------------------
  -- elseif fieldTypeName == "TypeRectUV" then
  --   imgui.Text(fieldValue)
  --   imgui.SameLine()
  --   if imgui.Button("Edit...") then
  --     editUvRectInfo.objectId = customData.objectId
  --     editUvRectInfo.fieldName = fieldName
  --     editUvRectInfo.arrayIndex = arrayIndex
  --     local vec = stringToTable(fieldValue)
  --     if vec[1] == nil then vec[1] = "0" end
  --     if vec[2] == nil then vec[2] = "0" end
  --     if vec[3] == nil then vec[3] = "0" end
  --     if vec[4] == nil then vec[4] = "0" end
  --     editUvRectInfo.uvRect = {}
  --     editUvRectInfo.uvRect[0] = tonumber(vec[1])
  --     editUvRectInfo.uvRect[1] = tonumber(vec[2])
  --     editUvRectInfo.uvRect[2] = tonumber(vec[3])
  --     editUvRectInfo.uvRect[3] = tonumber(vec[4])
  --     editor.openModalWindow(editUvRectDlg)
  --   end
  elseif fieldType == "RectF" then
    local vec = stringToTable(fieldValue)
    if vec[1] == nil then vec[1] = "0" end
    if vec[2] == nil then vec[2] = "0" end
    if vec[3] == nil then vec[3] = "0" end
    if vec[4] == nil then vec[4] = "0" end
    self.input4FloatValue[0] = tonumber(vec[1])
    self.input4FloatValue[1] = tonumber(vec[2])
    self.input4FloatValue[2] = tonumber(vec[3])
    self.input4FloatValue[3] = tonumber(vec[4])

    if editor.uiDragFloat4(fieldNameId, self.input4FloatValue, 0.05, nil, nil, floatFormat, 1, self.editEnded) then
      fieldValue =
        tostring(self.input4FloatValue[0]) .. " " .. tostring(self.input4FloatValue[1]) .. " " .. tostring(self.input4FloatValue[2] .. " " .. tostring(self.input4FloatValue[3]))
      self.setValueCallback(fieldName, fieldValue, arrayIndex, customData, self.editEnded[0])
    end
    if self.editEnded[0] then
      self.setValueCallback(fieldName, fieldValue, arrayIndex, customData, self.editEnded[0])
    end
  -------------------------------------------------------------------------------------------------------------------------
  elseif customData and customData.isDataBlock then
    if imgui.Button("  ...  ###" .. fieldNameId) then
      imgui.OpenPopup(fieldNameId .. "DataBlockPopup")
    end
    imgui.SameLine()
    if fieldValue == "" then
      imgui.Text(noValueString)
    else
      imgui.Text(fieldValue)
    end
    if imgui.BeginPopup(fieldNameId .. "DataBlockPopup") then
      imgui.PushID1(fieldNameId .. "DataBlockNameFilter")
      imgui.ImGuiTextFilter_Draw(dataBlockNameFilter, "", 200)
      imgui.PopID()
      imgui.SameLine()
      if imgui.Button("X###" .. fieldNameId, clearButtonSize) then
        imgui.ImGuiTextFilter_Clear(dataBlockNameFilter)
      end
      if imgui.IsItemHovered() then
        imgui.SetTooltip("Clear Search Filter")
      end
      imgui.BeginChild1(fieldNameId .. "DataBlockNames", filteredFieldPopupSize)

      -- for special case GameBaseData, we will search all of the datablocks
      -- that have the class as the object class name + "Data"
      local searchForClassname = fieldType

      if fieldType == "GameBaseData" then
        local obj = Sim.findObjectById(self.selectedIds[1])
        --searchForClassname = obj:getClassName()
      end

      local dbFieldType = worldEditorCppApi.findDerivedDatablockClassname(searchForClassname)
      local dbIsVisible = true

      for i, dbName in ipairs(dataBlockNames) do
        if imgui.ImGuiTextFilter_PassFilter(dataBlockNameFilter, dbName) then
          dbIsVisible = true
          if i ~= 1 then
            local dblock = Sim.findObjectByIdNoUpcast(dataBlocksTbl[dbName])
            if not dblock or not dblock:isSubClassOf(dbFieldType) then
              dbIsVisible = false
            end
          end

          if dbIsVisible then
            local isSelected = (fieldValue == dbName)
            if imgui.Selectable1(dbName, isSelected) then
              imgui.CloseCurrentPopup()
              fieldValue = dbName

              if fieldValue == noDataBlockString then
                fieldValue = ""
              end

              self.setValueCallback(fieldName, fieldValue, arrayIndex, customData, true)
              -- some exception for particle emitter data
              if fieldType == "ParticleEmitterData" then
                local o = scenetree.findObjectById(self.selectedIds[1])
                if o then
                  local dblock = scenetree.findObjectById(dataBlocksTbl[fieldValue])
                  if dblock then o:setEmitterDataBlock(dblock) end
                end
              end
            end
            --TODO: maybe something better for longer strings not fitting in the popup width
            if imgui.IsItemHovered() and string.len(dbName) >= tooltipLongTextLength then
              imgui.SetTooltip(dbName)
            end
            if isSelected then
              -- set the initial focus when opening the combo
              imgui.SetItemDefaultFocus()
            end
          end
        end
      end
      imgui.EndChild()
      imgui.EndPopup()
    end
  elseif customData and customData.enum ~= nil and tableSize(customData.enum) > 0 then
    local widgetsBasicComboItems = {}
    local oldIndex = 0

    for i = 1, #customData.enum do
      widgetsBasicComboItems[i] = customData.enum[i].name
      if customData.enum[i].name == fieldValue then
        oldIndex = i - 1
      end
    end

    widgetsBasicComboItems = imgui.ArrayCharPtrByTbl(widgetsBasicComboItems)
    self.comboIndex[0] = oldIndex
    if widgetsBasicComboItems then
      if imgui.Combo1(fieldNameId, self.comboIndex, widgetsBasicComboItems) then
        local index = tonumber(self.comboIndex[0] + 1)
        fieldValue = tostring(customData.enum[index].name)
        self.setValueCallback(fieldName, fieldValue, arrayIndex, customData, true)
      end
    end
  -------------------------------------------------------------------------------------------------------------------------
  else
    --editor.logError("Unsupported value type: " .. fieldType .. " (typeName: ".. fieldTypeName ..") " .. " for field: " .. fieldName)
    local fieldLen = string.len(fieldValue)
    local oldStrRef = nil
    if fieldLen >= inputTextShortStringMaxSize then
      if self.inputLongTextSize < fieldLen then
        self.inputLongTextSize = fieldLen + 1
        self.inputLongTextValue = imgui.ArrayChar(fieldLen + 1)
      end
      oldStrRef = self.inputTextValue
      self.inputTextValue = self.inputLongTextValue
    end
    if fieldValue ~= nil then
      ffi.copy(self.inputTextValue, fieldValue)
    else
      ffi.copy(self.inputTextValue, "")
    end

    imgui.PushItemWidth(imgui.GetContentRegionAvailWidth())
    local changed = editor.uiInputText(fieldNameId, self.inputTextValue, ffi.sizeof(self.inputTextValue), nil, nil, nil, self.editEnded)
    if changed then
      fieldValueCached = ffi.string(self.inputTextValue)
    end
    imgui.PopItemWidth()
    if self.editEnded[0] then
      fieldValue = ffi.string(self.inputTextValue)
      local val = fieldValueCached or fieldValue
      -- we call this directly, if the callback nil, then we will get an error in the console, which is visible
      self.setValueCallback(fieldName, val, arrayIndex, customData, self.editEnded[0])
    end
    if nil ~= oldStrRef then self.inputTextValue = oldStrRef end
    imgui.tooltip("This field's type: '".. fieldType .."' is not known by Inspector, hence a default text input editor was provided")
  end
  imgui.PopItemWidth()
  if isDifferent then imgui.PopStyleColor() end
  imgui.Columns(1)
  imgui.PopID()
end

editor.registerCustomFieldInspectorEditor = registerCustomFieldEditor
editor.unregisterCustomFieldInspectorEditor = unregisterCustomFieldEditor
editor.findCustomFieldEditor = findCustomFieldEditor

editor.registerCustomFieldInspectorFilter = registerCustomFieldFilter
editor.unregisterCustomFieldInspectorFilter = unregisterCustomFieldFilter
editor.findCustomFieldFilter = findCustomFieldFilter

editor.valueInspectorCopyPasteMenu = handleCopyPasteMenu

editor.getAnnotations = function() return annotations end
editor.getAnnotationsTbl = function() return annotationsTbl end

return function()
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init()
  return o
end