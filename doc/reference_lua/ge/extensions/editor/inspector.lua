-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = "editor_inspector"
local ffi = require("ffi")
local guiInstancer = require("editor/api/guiInstancer")()
local valueInspector = require("editor/api/valueInspector")()
local objectHistoryActions = require("editor/api/objectHistoryActions")()
local imgui = ui_imgui

local inspectorWindowNamePrefix = "inspector"
local maxGroupCount = 500
local lockedInspectorColor = imgui.ImVec4(1, 0.8, 0, 1)
local differentValuesColor = imgui.ImVec4(1, 0.2, 0, 1)
local inspectorTypeHandlers = {}
local inspectorFieldModifiers = {}
local collapseGroups = {}
local arrayHeaderBgColor = imgui.ImVec4(0.04, 0.15, 0.1, 1)
local headerMenus = {
  {
    groupName = "Transform",
    open = false,
    pos = nil
  }
}

local function checkEditorDirtyFlag()
  if editor.getObjectSelection and not editor.dirty then
    for k, v in ipairs(editor.getObjectSelection()) do
      local obj = scenetree.findObjectById(v)
      -- we call inspectUpdate so the objects compute internal things and return true if inspector needs to be refreshed
      -- but inspector is refreshing its UI continuously, so that bool is not really needed, but the call is kept
      -- for that internal update some objects might need
      if obj and obj.inspectUpdate and (obj:inspectUpdate() or obj:isEditorDirty()) then
        -- something changed, dirty editor, needs save level
        editor.setDirty()
      end
    end
  end
end

local function createInspectorContext()
  return {
    newFieldName = imgui.ArrayChar(1024),
    matchedFilterStaticFields = true,
    inspectorCurrentFieldNames = {},
    firstObjectId = nil,
    firstObjectFieldValues = {},
    editEnded = imgui.BoolPtr(false),
    inputTextValue = imgui.ArrayChar(valueInspector.inputTextShortStringMaxSize),
    fields = {}
  }
end

-- this is the shared context, used by all inspector non locked instances
-- locked inspectors will use a custom context for each of the locked instances
local sharedCtx = createInspectorContext()

local function addInspectorInstance(selection)
  -- note: idx is a string key, not a number, because it gets serialized to json as key
  local idx = guiInstancer:addInstance()
  guiInstancer.instances[idx].selection = deepcopy(selection)
  guiInstancer.instances[idx].previousSelectedIds = {}
  guiInstancer.instances[idx].fieldNameFilter = imgui.ImGuiTextFilter()

  -- if this instance is locked, also create a new context for that inspector instance
  -- needed so that instance can handle the locked selection fields editing undisturbed by the
  -- current selection and other shared inspectors
  if selection then
    guiInstancer.instances[idx].ctx = createInspectorContext()
  end

  local wndName = inspectorWindowNamePrefix .. tostring(idx)
  editor.registerWindow(wndName, imgui.ImVec2(300, 500))
  editor.showWindow(wndName)
  return idx
end

local function openInspector()
  if not tableIsEmpty(guiInstancer.instances) then return end
  addInspectorInstance()
end

local function closeInspectorInstance(idx)
  local wndName = inspectorWindowNamePrefix .. tostring(idx)
  editor.unregisterWindow(wndName)
  guiInstancer:removeInstance(idx)
end

local function getInspectorInstances()
  return guiInstancer.instances
end

local function getInspectorTypeHandlers()
  return inspectorTypeHandlers
end

local function registerInspectorTypeHandler(typeName, guiCallback)
  inspectorTypeHandlers[typeName] = {
    typeName = typeName,
    guiCallback = guiCallback
  }
end

local function unregisterInspectorTypeHandler(typeName)
  inspectorTypeHandlers[typeName] = nil
end

local function registerInspectorFieldModifier(uniqueName, callback)
  inspectorFieldModifiers[uniqueName] = {
    callback = callback
  }
end

local function unregisterInspectorFieldModifier(uniqueName)
  inspectorFieldModifiers[uniqueName] = nil
end

local function setMultiSelectionFieldValue(selectedIds, fieldName, fieldValue, arrayIndex, editEnded)
  if editEnded == nil then editEnded = true end
  if editEnded then
    editor.history:beginTransaction("ChangeFieldValue")
    objectHistoryActions.changeObjectFieldWithUndo(selectedIds, fieldName, fieldValue, arrayIndex)
    editor.history:endTransaction()
  else
    for i = 1, tableSize(selectedIds) do
      editor.setFieldValue(selectedIds[i], fieldName, fieldValue, arrayIndex)
    end
  end
  if editEnded then
    editor.setDirty()
  end
end

local function setMultiSelectionFieldWithOldValues(selectedIds, fieldName, fieldValue, oldValues, arrayIndex, editEnded)
  if editEnded == nil then editEnded = true end
  if editEnded then
    objectHistoryActions.changeObjectFieldWithOldValues(selectedIds, fieldName, fieldValue, oldValues, arrayIndex)
  else
    for i = 1, tableSize(selectedIds) do
      editor.setFieldValue(selectedIds[i], fieldName, fieldValue, arrayIndex)
    end
  end
  if editEnded then
    editor.setDirty()
  end
end

local function setMultiSelectionDynamicFieldValue(selectedIds, fieldName, fieldValue, arrayIndex, editEnded)
  if editEnded == nil then editEnded = true end
  if editEnded then
    editor.history:beginTransaction("ChangeDynamicFieldValue")
    objectHistoryActions.changeObjectDynFieldWithUndo(selectedIds, fieldName, fieldValue, arrayIndex)
    editor.history:endTransaction()
  else
    for i = 1, tableSize(selectedIds) do
      editor.setDynamicFieldValue(selectedIds[i], fieldName, fieldValue, arrayIndex)
    end
  end
  if editEnded then
    editor.setDirty()
  end
end

-- callback for the value inspector copy paste menu
local function pasteFieldValue(fieldName, fieldValue, arrayIndex, customData)
  setMultiSelectionFieldValue(valueInspector.selectedIds, fieldName, fieldValue, arrayIndex)
  editor.updateObjectSelectionAxisGizmo()
end

local function resetFieldValue(fieldName, fieldType)
    local fieldVal = ""
    if fieldType == "Point3F" or fieldType == "vec3" or fieldType == "MatrixPosition" then
      if string.lower(fieldName) == "scale" then
        fieldVal = "1 1 1"
      else
        fieldVal = "0 0 0"
      end
    elseif fieldType == "MatrixRotation" then
      fieldVal = "0 0 0 0"
    elseif fieldType == "EulerRotation" then
      fieldVal = "0 0 0"
    else
      assert(false,"resetFieldValue not yet implemented for type " .. fieldType)
    end

    setMultiSelectionFieldValue(valueInspector.selectedIds, fieldName, fieldVal, 0)
    editor.updateObjectSelectionAxisGizmo()
end

local function objectInspectorGui(inspectorInfo)
  valueInspector.selectedIds = nil

  -- if we have a locked inspector, ctx will be valid, else use the shared context
  local ctx = inspectorInfo.ctx or sharedCtx

  if inspectorInfo.selection then
    inspectorInfo.selection.object = editor.removeInvalidObjects(inspectorInfo.selection.object)
    valueInspector.selectedIds = inspectorInfo.selection.object
  else
    editor.selection.object = editor.removeInvalidObjects(editor.selection.object)
    valueInspector.selectedIds = editor.selection.object
    ctx.inspectorCurrentFieldNames = {}
  end

  if not valueInspector.selectedIds or 0 == tableSize(valueInspector.selectedIds) then
    imgui.Text("No selection")
    return
  end

  if tableSize(valueInspector.selectedIds) > 1 then
    imgui.Text(tostring(tableSize(valueInspector.selectedIds)) .. " selected object(s)")
  end

  if not setEqual(valueInspector.selectedIds, inspectorInfo.previousSelectedIds) then
    imgui.ClearActiveID()
    inspectorInfo.previousSelectedIds = valueInspector.selectedIds
  end

  local firstObj = scenetree.findObjectById(valueInspector.selectedIds[1])

  if firstObj then
    if firstObj.getClassName then
      valueInspector.selectionClassName = firstObj:getClassName()
    end
  else
    editor.logError("Object with this ID does not exists in the scene: " .. tostring(valueInspector.selectedIds[1]))
    return
  end

  ctx.firstObjectFieldValues = {}
  valueInspector.differentValuesFields = {}
  ctx.firstObjectId = valueInspector.selectedIds[1]

  -- find common fields in all the selected objects
  local commonFields = {}

  for fldName, field in pairs(ctx.fields) do
    if field.useCount == tableSize(valueInspector.selectedIds) then
      if nil == tableFindKey(commonFields, fldName) then
        commonFields[fldName] = field
      end
      if not field.isArray then
        ctx.firstObjectFieldValues[fldName] = editor.getFieldValue(valueInspector.selectedIds[1], fldName)
      end
    end
  end

  if tableSize(editor.selection.object) > 1 then commonFields["name"] = nil end

  -- make it our main fields list again
  ctx.fields = commonFields
  -- now find the fields with different values across the selected objects
  -- these will show as blank values in their field edit widgets
  local fieldVal = nil
  for key, val in pairs(ctx.fields) do
    -- we start at the second object, since the first one we keep as reference
    for i = 2, tableSize(valueInspector.selectedIds) do
      if not val.isArray then
        fieldVal = editor.getFieldValue(valueInspector.selectedIds[i], key)
        if ctx.firstObjectFieldValues[key] ~= fieldVal then
          valueInspector.differentValuesFields[key] = true
          -- break at first different field value
          break
        end
      end
    end
  end

  -- if we got no fields, just return
  if not ctx.fields then
    return
  end

  local sortedFields = {}

  -- set the sorted fields array and sort the array fields
  for _, field in pairs(ctx.fields) do
    if field.type == "beginArray" then
      -- sort the array fields by ID in a new array table
      field.sortedFields = {}
      for _, fld in pairs(field.fields) do table.insert(field.sortedFields, fld) end
      table.sort(field.sortedFields, function(a, b) return a.id < b.id end)
    end
    table.insert(sortedFields, field)
  end

  -- sort by id value (order of declaration in the C++ vector, the id is the index in the fields vector)
  table.sort(sortedFields, function(a, b) return a.id < b.id end)

  local groupedSortedFields = {}

  if editor.uiInputSearchTextFilter("##fieldNameSearchFilter", inspectorInfo.fieldNameFilter, 200, nil, ctx.editEnded) then
    if ffi.string(imgui.TextFilter_GetInputBuf(inspectorInfo.fieldNameFilter)) == "" then
      imgui.ImGuiTextFilter_Clear(inspectorInfo.fieldNameFilter)
    end
  end

  -- put the fields in a grouped table
  local groupIndex = 1
  local groupIndexLUT = {} -- a look up table with the order index for each group

  for i = 1, tableSize(sortedFields) do
    local val = sortedFields[i]

    if val then
      for k, v in pairs(inspectorFieldModifiers) do
        if v.callback then
          local ret = v.callback(val, valueInspector.selectionClassName)
          if ret then val = ret end
        end
      end
    end

    if val and not val.hideInInspector then
      -- only gather field names for unlocked inspectors
      if not inspectorInfo.selection then
        ctx.inspectorCurrentFieldNames[val.name] = true
      end
      -- add group table if not existing in the LUT
      if val.groupName and not groupIndexLUT[val.groupName] then
        groupIndexLUT[val.groupName] = groupIndex
        groupedSortedFields[groupIndex] = {
          groupName = val.groupName,
          isExpanded = true, -- TODO: get from val.groupExpand from C++?
          fields = {}
        }
        groupIndex = groupIndex + 1
      end
      if groupIndexLUT[val.groupName] then
        -- render colored label indicators for Transform group
        if val.groupName == "Transform" then
          val.coloredLabelIndicator = true
        end
        table.insert(groupedSortedFields[groupIndexLUT[val.groupName]].fields, val)
      end
    end
  end

  -- general and transform groups come first
  local general = groupedSortedFields[groupIndexLUT["Ungrouped"]] or {}
  local xform = groupedSortedFields[groupIndexLUT["Transform"]] or {}
  local fieldIndent = 15

  local function displayFields(fields)
    for _, val in ipairs(fields) do
      -- simple field
      if not val.isArray and not val.hidden then
        if val.elementCount == 1 then
          val.value = editor.getFieldValue(valueInspector.selectedIds[#valueInspector.selectedIds], val.name, 0)
          valueInspector:valueEditorGui(val.name, val.value or "", 0, val.name, val.fieldDocs, val.type, val.typeName, val, pasteFieldValue)
        else
          local customFieldEditor = editor.findCustomFieldEditor(val.name, valueInspector.selectionClassName)
          if customFieldEditor and customFieldEditor.useArray then
            valueInspector:valueEditorGui(val.name, val.value or "", 0, val.name, val.fieldDocs, val.type, val.typeName, val, pasteFieldValue)
          else
            local nodeFlags = imgui.TreeNodeFlags_DefaultClosed
            imgui.PushStyleColor2(imgui.Col_Header, arrayHeaderBgColor)
            if imgui.CollapsingHeader1(val.name, nodeFlags) then
              imgui.Indent(fieldIndent)
              for i = 0, val.elementCount - 1 do
                local value = editor.getFieldValue(valueInspector.selectedIds[#valueInspector.selectedIds], val.name, i)
                valueInspector:valueEditorGui(val.name, value or "", i, val.name .. "["..tostring(i).."]", val.fieldDocs, val.type, val.typeName, val, pasteFieldValue)
              end
              imgui.Unindent(fieldIndent)
              imgui.Separator()
            end
            imgui.PopStyleColor()
          end
        end
      -- if its and array of fields
      elseif val.isArray then
        local nodeFlags = imgui.TreeNodeFlags_DefaultClosed
        imgui.PushStyleColor2(imgui.Col_Header, arrayHeaderBgColor)
        if imgui.CollapsingHeader1(val.arrayName, nodeFlags) then
          imgui.Indent(fieldIndent)
          for i = 0, val.elementCount - 1 do
            imgui.PushID1(val.arrayName .. "_ARRAY_ITEMS_" .. i)
            if imgui.CollapsingHeader1("[" .. tostring(i) .. "]", nodeFlags) then
              for _, arrayField in ipairs(val.sortedFields) do
                local arrayFieldName = arrayField.name
                if not arrayField.hidden then
                  arrayField.value = editor.getFieldValue(valueInspector.selectedIds[#valueInspector.selectedIds], arrayField.name, i)
                  valueInspector:valueEditorGui(arrayField.name, arrayField.value or "", i, arrayField.name, arrayField.fieldDocs, arrayField.type, arrayField.typeName, arrayField, pasteFieldValue)
                end
              end
            end
            imgui.PopID()
          end
          imgui.Unindent(fieldIndent)
          imgui.Separator()
        end
        imgui.PopStyleColor()
      end
    end
  end

  local function setHeaderMenu(groupName)
    for _, headerMenu in ipairs(headerMenus) do
      if string.lower(headerMenu.groupName) == string.lower(groupName) then
        if imgui.Button("...") then
          if headerMenu.open then
            headerMenu.open = false
          else
            headerMenu.open = true
          end
          headerMenu.pos = imgui.ImVec2(imgui.GetMousePos().x - 150 * editor.getPreference("ui.general.scale"), imgui.GetMousePos().y + 10)
        end
        break
      end
    end
  end

  local function getFieldType(fieldName, fields)
    for _, field in ipairs(fields) do
      if string.lower(field.name) == string.lower(fieldName) then
        return field.type
      end
    end
    return nil
  end

  local function headerMenu(groupName, fields)
    local menu = nil
    local menuFound = false
    for _, headerMenu in ipairs(headerMenus) do
      if string.lower(headerMenu.groupName) == string.lower(groupName) then
        menuFound = true
        menu = headerMenu
        break
      end
    end
    if not menuFound then return end
    if menu.open then
      imgui.SetNextWindowPos(menu.pos)
      imgui.Begin(groupName.."HeaderMenu", nil, imgui.WindowFlags_NoCollapse + imgui.WindowFlags_AlwaysAutoResize + imgui.WindowFlags_NoResize + imgui.WindowFlags_NoTitleBar)
      if groupName == "Transform" then
        local posFieldType = getFieldType("position", fields)
        if not posFieldType then
          imgui.BeginDisabled()
        end
        if imgui.Button("Reset Position") then
          resetFieldValue("position", posFieldType)
          menu.open = false
        end
        if not posFieldType then
          imgui.EndDisabled()
        end

        local rotFieldType = getFieldType("rotation", fields)
        if not rotFieldType then
          imgui.BeginDisabled()
        end
        if imgui.Button("Reset Rotation") then
          resetFieldValue("rotation", rotFieldType)
          menu.open = false
        end
        if not rotFieldType then
          imgui.EndDisabled()
        end

        local scaleFieldType = getFieldType("scale", fields)
        if not scaleFieldType then
          imgui.BeginDisabled()
        end
        if imgui.Button("Reset Scale") then
          resetFieldValue("scale", scaleFieldType)
          menu.open = false
        end
        if not scaleFieldType then
          imgui.EndDisabled()
        end

        if not rotFieldType or not scaleFieldType then
          imgui.BeginDisabled()
        end
        if imgui.Button("Reset Rotation & Scale") then
          resetFieldValue("rotation", rotFieldType)
          resetFieldValue("scale", scaleFieldType)
          menu.open = false
        end
        if not rotFieldType or not scaleFieldType then
          imgui.EndDisabled()
        end
      end
      if not imgui.IsWindowFocused() then
        menu.open = false
      end
      imgui.End()
    end
  end

  local function collapsingHeaderMenu(groupName, fields)
    local groupHeaderMenuFound = false
    for _, val in ipairs(headerMenus) do
      if string.lower(val.groupName) == string.lower(groupName) then
        groupHeaderMenuFound = true
        break
      end
    end
    if not groupHeaderMenuFound then
      return
    end
    imgui.SameLine(imgui.GetWindowWidth() - 40 * editor.getPreference("ui.general.scale"));
    imgui.SetItemAllowOverlap()
    setHeaderMenu(groupName)
    headerMenu(groupName, fields)
  end

  local function displayGroup(groupName, fields, ctx)
    local nodeFlags = imgui.TreeNodeFlags_DefaultOpen
    if not fields then return end
    -- check if any of its fields are filtered
    local passFilter = false
    for _, val in ipairs(fields) do
      if imgui.ImGuiTextFilter_PassFilter(inspectorInfo.fieldNameFilter, val.name) then
        passFilter = true
        val.hidden = false
      else
        val.hidden = true
      end
    end
    if not passFilter then return end
    ctx.matchedFilterStaticFields = true
    local res = imgui.CollapsingHeader1(groupName, nodeFlags)
    collapsingHeaderMenu(groupName, fields)
    if res then
      displayFields(fields)
    end
  end

  --
  -- Static fields
  --
  ctx.matchedFilterStaticFields = true
  -- a bit of info about the selection
  if general and general.fields then
    if valueInspector.selectedIds and #valueInspector.selectedIds == 1 and valueInspector.selectedIds[1] ~= 0 then
      local firstId = valueInspector.selectedIds[1]
      local obj = scenetree.findObjectById(firstId)
      if obj then
        local textColor = imgui.GetStyleColorVec4(imgui.Col_Text)
        imgui.TextUnformatted("Class:") imgui.SameLine() imgui.TextColored(textColor, valueInspector.selectionClassName)
        if #valueInspector.selectedIds == 1 then
          imgui.SameLine()
          imgui.Text("    ")
          imgui.SameLine()
          imgui.TextUnformatted("ID:") imgui.SameLine() imgui.TextColored(textColor, tostring(obj:getId()))
          imgui.tooltip("PID: " .. tostring(obj:getOrCreatePersistentID()))
          imgui.SameLine()
          if imgui.Button("Copy ID") then
            setClipboard(tostring(obj:getOrCreatePersistentID()))
          end
          imgui.SameLine()
          if imgui.Button("Copy PID") then
            setClipboard(tostring(obj:getId()))
          end
          local grp = obj:getGroup()
          if grp then
            imgui.TextUnformatted("Parent:") imgui.SameLine() imgui.TextColored(textColor, tostring(grp:getName()))
          end
        end
      end
    end
    displayGroup("General", general.fields, ctx)
  end

  if xform and xform.fields then
    displayGroup("Transform", xform.fields, ctx)
  end

  -- display the groups and their fields
  for _, group in ipairs(groupedSortedFields) do
    if group ~= general and group ~= xform then
      displayGroup(group.groupName, group.fields, ctx)
    end
  end

  if not ctx.matchedFilterStaticFields then
    imgui.PushStyleColor2(imgui.Col_Text, imgui.ImVec4(1, 0.5, 0, 1))
    imgui.Text("<No search matches>")
    imgui.PopStyleColor()
  end

  --
  -- Dynamic fields
  --
  local dynFields = {}
  -- if only one object selected, then just get its dynamic fields
  if #valueInspector.selectedIds == 1 then
    if ctx.firstObjectId == 0 then
      dynFields = {}
    else
      dynFields = editor.getDynamicFields(ctx.firstObjectId)
    end
  else
    -- if multiselection, then find all the commond dynamic fields to the selection
    local dynFieldUsage = {}
    -- count the usage for each dynamic field of each object
    for i = 1, #valueInspector.selectedIds do
      local objDynFields = editor.getDynamicFields(valueInspector.selectedIds[i])
      for j = 1, #objDynFields do
        local fieldName = objDynFields[j]
        if not dynFieldUsage[fieldName] then
          dynFieldUsage[fieldName] = 1
        else
          dynFieldUsage[fieldName] = dynFieldUsage[fieldName] + 1
        end
      end
    end
    -- add the dynamic field whom usage is equal to the selection count
    -- meaning that is used by every object in the selection so its common to all
    -- otherwise we skip it, since it would not make sense when not common
    for key, val in pairs(dynFieldUsage) do
      if val == #valueInspector.selectedIds then
        table.insert(dynFields, key)
      end
    end
  end

  -- show the dynamic fields editors
  if dynFields ~= nil and imgui.CollapsingHeader1("Dynamic Fields") then
    local arrayIndex = 0
    -- if multiselection and no common dynamic fields
    if #dynFields == 0 and #valueInspector.selectedIds > 1 then
        imgui.TextUnformatted("No common dynamic fields")
    else
      local fieldValue = ""
      local passedFilter = false
      for i = 1, #dynFields do
        if imgui.ImGuiTextFilter_PassFilter(inspectorInfo.fieldNameFilter, dynFields[i]) then
          passedFilter = true
          fieldValue = editor.getFieldValue(ctx.firstObjectId, dynFields[i])
          if fieldValue ~= nil then
            ffi.copy(ctx.inputTextValue, fieldValue)
          end
          imgui.PushID1("FIELDS_COL")
          imgui.Columns(2, "FieldsColumn")
          imgui.Text(dynFields[i])
          imgui.NextColumn()
          local fieldNameId = "##" .. dynFields[i]
          -- if dynamic field value is changed and the value it's not empty string then update it
          if editor.uiInputText(fieldNameId, ctx.inputTextValue, ffi.sizeof(ctx.inputTextValue), nil, nil, nil, ctx.editEnded) and ctx.editEnded[0] and ffi.string(ctx.inputTextValue) ~= "" then
            fieldValue = ffi.string(ctx.inputTextValue)
            setMultiSelectionDynamicFieldValue(valueInspector.selectedIds, dynFields[i], fieldValue, arrayIndex)
          end
          imgui.SameLine()
          imgui.PushID4(i)
          -- delete dynamic field button
          if imgui.Button("X") then
            -- just set to empty string will delete it
            setMultiSelectionDynamicFieldValue(valueInspector.selectedIds, dynFields[i], "", arrayIndex)
          end
          imgui.PopID()
          imgui.Columns(1)
          imgui.PopID()
        end
      end
      if #dynFields > 0 and not passedFilter then
        imgui.PushStyleColor2(imgui.Col_Text, imgui.ImVec4(1, 0.5, 0, 1))
        imgui.Text("<No search matches>")
        imgui.PopStyleColor()
      end
    end

    local wantsToAddField = false

    imgui.Text("Add new field named:")
    if imgui.InputText("##newDynField", ctx.newFieldName, ffi.sizeof(ctx.newFieldName), imgui.InputTextFlags_EnterReturnsTrue) then
      wantsToAddField = true
    end
    imgui.SameLine()
    if imgui.Button("Add") then
      wantsToAddField = true
    end

    if wantsToAddField then
      local fieldValue = ffi.string(ctx.newFieldName)
      setMultiSelectionDynamicFieldValue(valueInspector.selectedIds, fieldValue, "0", arrayIndex)
      ffi.copy(ctx.newFieldName, "")
    end
  end
end

local function inspectorHasField(fieldName)
  return sharedCtx.inspectorCurrentFieldNames[fieldName] ~= nil
end

local function registerApi()
  editor.addInspectorInstance = addInspectorInstance
  editor.closeInspectorInstance = closeInspectorInstance
  editor.getInspectorInstances = getInspectorInstances
  editor.registerInspectorTypeHandler = registerInspectorTypeHandler
  editor.unregisterInspectorTypeHandler = unregisterInspectorTypeHandler
  editor.getInspectorTypeHandlers = getInspectorTypeHandlers
  editor.registerInspectorFieldModifier = registerInspectorFieldModifier
  editor.unregisterInspectorFieldModifier = unregisterInspectorFieldModifier
  editor.inspectorHasField = inspectorHasField
end

local function onExtensionLoaded()
  for i = 1, maxGroupCount do
    table.insert(collapseGroups, i, imgui.BoolPtr(false))
  end

  registerApi()
end

local function onEditorGui()
  if guiInstancer.instances then
    for key, inspectorInfo in pairs(guiInstancer.instances) do
      local wndName = inspectorWindowNamePrefix .. key
      if editor.beginWindow(wndName, "Inspector##" .. key, imgui.WindowFlags_AlwaysVerticalScrollbar) then
        if not editor.isWindowVisible(wndName) then
          editor.closeInspectorInstance(key)
        end
        if inspectorInfo.selection then
          if editor.uiIconImageButton(editor.icons.lock, imgui.ImVec2(24, 24)) then
            inspectorInfo.selection = nil
            inspectorInfo.ctx = nil
          end
          if imgui.IsItemHovered() then imgui.SetTooltip("Unlock Inspector Window") end
        elseif editor.uiIconImageButton(editor.icons.lock_open, imgui.ImVec2(24, 24)) and (not tableIsEmpty(editor.selection)) then
          inspectorInfo.selection = deepcopy(editor.selection)
          inspectorInfo.ctx = createInspectorContext()
          inspectorInfo.ctx.fields = deepcopy(sharedCtx.fields)
        end
        imgui.tooltip("Lock this Inspector to the currently selected object(s)")
        imgui.SameLine()
        local numKeys = 0
        if editor.uiIconImageButton(editor.icons.fiber_new, imgui.ImVec2(24, 24)) then
          editor.addInspectorInstance()
        end
        if imgui.IsItemHovered() then imgui.SetTooltip("New Inspector Window") end
        if inspectorInfo.selection then
          imgui.SameLine()
          imgui.PushStyleColor2(imgui.Col_Text, lockedInspectorColor)
          imgui.Text("[Locked]")
          imgui.PopStyleColor()
        else
          -- first lets check if we have multiple selection types
          for key, val in pairs(editor.selection) do
            if not tableIsEmpty(val) then
              numKeys = numKeys + 1
              if numKeys == 2 then
                break
              end
            end
          end
        end
        if numKeys == 2 then
          imgui.Text("Multiple types selected:")
          for key, val in pairs(editor.selection) do
            imgui.Text(#val .. " " .. key .. "(s)")
          end
        else
          -- allow various tools to render custom specific UI in the header of the object inspector window
          extensions.hook("onEditorInspectorHeaderGui", inspectorInfo)
          -- inspector has multiple view types, like object inspector, editor settings, asset properties etc.
          -- so we provide a function for the current mode, the default is object inspector objectInspectorGui function
          for typeName, typeHandler in pairs(inspectorTypeHandlers) do
            -- if we have a locked inspector, use its selection
            if inspectorInfo.selection ~= nil then
              -- if we found this type to have something selected, show ui
              if inspectorInfo.selection[typeHandler.typeName] ~= nil then
                if typeHandler.guiCallback then
                  typeHandler.guiCallback(inspectorInfo)
                  break -- stop at first viable type handler, just show this type inspector ui
                end
              end
            elseif editor.selection[typeName] ~= nil then
              if typeHandler.guiCallback then
                typeHandler.guiCallback(inspectorInfo)
                break -- stop at first viable type handler, just show this type inspector ui
              end
            end
          end
        end
      else
        if not editor.isWindowVisible(wndName) then
          editor.closeInspectorInstance(key)
        end
      end
      editor.endWindow()
    end
  end
  checkEditorDirtyFlag()
end

local function onWindowMenuItem()
  openInspector()
end

local function onEditorActivated()
  valueInspector:initializeTables()
  sharedCtx = createInspectorContext()
  M.onEditorObjectSelectionChanged()
end

local function onEditorDeactivated()
end

local function onEditorLoadGuiInstancerState(state)
  guiInstancer:deserialize("inspectorInstances", state)
  for key, val in pairs(guiInstancer.instances) do
    editor.registerWindow(inspectorWindowNamePrefix .. tostring(key), imgui.ImVec2(300, 500))
    val.fieldNameFilter = imgui.ImGuiTextFilter()
  end
end

local function onEditorSaveGuiInstancerState(state)
  guiInstancer:serialize("inspectorInstances", state)
end

local metallicValuePtrs = {}
metallicValuePtrs[0] = imgui.FloatPtr(0)
metallicValuePtrs[1] = imgui.FloatPtr(0)
metallicValuePtrs[2] = imgui.FloatPtr(0)
metallicValuePtrs[3] = imgui.FloatPtr(0)

local metallicLabels = {}
metallicLabels[0] = "Metallic"
metallicLabels[1] = "Roughness"
metallicLabels[2] = "Clearcoat"
metallicLabels[3] = "Cc Roughness"

local function customVehicleMetallicFieldEditor(objectIds, fieldValue, fieldName, fieldLabel, fieldDesc, fieldType, fieldTypeName, customData, pasteCallback, contextMenuUI)
  if imgui.CollapsingHeader1(fieldName) then
    local floatFormat = "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f"
    for colorIndex = 0, 2 do
      imgui.Text("Paint " .. colorIndex+1)
      local fieldValue = editor.getFieldValue(valueInspector.selectedIds[#valueInspector.selectedIds], fieldName, colorIndex)
      local metallicValues = stringToTable(fieldValue)
      metallicValuePtrs[0][0] = tonumber(metallicValues[1])
      metallicValuePtrs[1][0] = tonumber(metallicValues[2])
      metallicValuePtrs[2][0] = tonumber(metallicValues[3])
      metallicValuePtrs[3][0] = tonumber(metallicValues[4])
      for propertyIndex = 0, 3 do
        imgui.PushItemWidth(imgui.GetContentRegionAvailWidth() - imgui.CalcTextSize(metallicLabels[3]).x)
        if editor.getPreference("ui.general.useSlidersInInspector") then
          editor.uiDragFloat(metallicLabels[propertyIndex] .. "##" .. colorIndex, metallicValuePtrs[propertyIndex], 0.1, 0, 1, floatFormat, nil, sharedCtx.editEnded)
        else
          editor.uiInputFloat(metallicLabels[propertyIndex] .. "##" .. colorIndex, metallicValuePtrs[propertyIndex], 0.1, 0.5, floatFormat, nil, sharedCtx.editEnded)
        end

        if sharedCtx.editEnded[0] then
          objectHistoryActions.changeObjectFieldWithUndo({valueInspector.selectedIds[#valueInspector.selectedIds]}, fieldName, metallicValuePtrs[0][0] .. " " .. metallicValuePtrs[1][0] .. " " .. metallicValuePtrs[2][0] .. " " .. metallicValuePtrs[3][0], colorIndex)
        end
      end
    end
  end
end

local function onEditorRegisterApi()
  editor.checkEditorDirtyFlag = checkEditorDirtyFlag
end

local function onEditorInitialized()
  valueInspector:reinitializeTables()
  registerInspectorTypeHandler("object", objectInspectorGui)
  editor.addWindowMenuItem("Inspector", onWindowMenuItem, nil, true)
  valueInspector.inspectorName = "mainInspector"
  valueInspector.addTypeToTooltip = true -- shows type in field description tooltip
  -- delete the various material/texture thumbs from previous editor show
  valueInspector:deleteTexObjs()
  -- set the value callback func, called when the edited value was changed in the value editor widgets
  valueInspector.setValueCallback = function(fieldName, fieldValue, arrayIndex, customData, editEnded)
    if customData.startValues then
      setMultiSelectionFieldWithOldValues(valueInspector.selectedIds, fieldName, fieldValue, customData.startValues, arrayIndex, editEnded)
    else
      setMultiSelectionFieldValue(valueInspector.selectedIds, fieldName, fieldValue, arrayIndex, editEnded)
    end
  end

  editor.registerCustomFieldInspectorEditor("BeamNGVehicle", "metallicPaintData", customVehicleMetallicFieldEditor, true)
end

local function onEditorObjectSelectionChanged()
  if editor.pickingLinkTo and #editor.selection.object then
    local pid = Sim.findObjectById(editor.selection.object[1]):getOrCreatePersistentID()
    editor.pickingLinkTo.child:setField("linkToParent", 0, pid)
    editor.selection.object = deepcopy(editor.pickingLinkTo.selectionObjectIds)
    editor.pickingLinkTo = nil
    return
  end

  table.clear(sharedCtx.fields)

  -- get all fields from all selected objects
  for i = 1, tableSize(editor.selection.object) do
    local objFields = editor.getFields(editor.selection.object[i])
    if objFields then
      for fldName, field in pairs(objFields) do
        if sharedCtx.fields[fldName] == nil then
          sharedCtx.fields[fldName] = field
          sharedCtx.fields[fldName].useCount = 1
        else
          sharedCtx.fields[fldName].useCount = sharedCtx.fields[fldName].useCount + 1
        end
      end
    end
  end
  valueInspector:setSimSetWindowFieldId(nil)
end

local function onEditorAfterOpenLevel()
  -- we do this to update the datablock lists to show in dropdowns
  valueInspector:initializeTables(true)
end

M.onEditorGui = onEditorGui
M.onEditorRegisterApi = onEditorRegisterApi
M.onEditorAfterOpenLevel = onEditorAfterOpenLevel
M.onExtensionLoaded = onExtensionLoaded
M.onEditorInitialized = onEditorInitialized
M.onEditorActivated = onEditorActivated
M.onEditorDeactivated = onEditorDeactivated
M.onEditorLoadGuiInstancerState = onEditorLoadGuiInstancerState
M.onEditorSaveGuiInstancerState = onEditorSaveGuiInstancerState
M.onEditorObjectSelectionChanged = onEditorObjectSelectionChanged

return M
