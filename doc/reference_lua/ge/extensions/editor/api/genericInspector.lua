-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local ffi = require('ffi')
local imgui = ui_imgui
local C = {}

local genericInspectorCount = 0

local function tableIsArray(tbl)
  if type(tbl) ~= "table" then return false end
  local count = 0
  for k, v in pairs(tbl) do
    if type(k) ~= "number" then return false else count = count + 1 end
  end
  for i = 1, count do
    if not tbl[i] and type(tbl[i]) ~= "nil" then return false end
  end
  return true
end

function C:inspectorGuiWithFieldCallback(fieldCallback)
  local fields = {}
  local maxFieldCount = 1000
  for i = 1, maxFieldCount do
    local fld = fieldCallback(i)
    if not fld then break end
    if i == maxFieldCount then
      editor.logWarn("You have more than " .. maxFieldCount .. " fields in the generic inspector " .. self.valueInspector.inspectorName)
    end
    table.insert(fields, fld)
  end
  if #fields then self:inspectorGui(fields) end
end

function C:inspectorGui(fields)
  -- if we got no fields, just return
  if not fields then
    return
  end

  local sortedFields = {}
  local lastGrpName = "General"
  -- set the sorted fields array and sort the array fields
  for _, field in pairs(fields) do
    if tableIsArray(field.value) then field.elementCount = #field.value end
    if field.type == "beginArray" then
      -- sort the array fields by ID in a new array table
      field.sortedFields = {}
      for _, fld in pairs(field.fields) do
        if tableIsArray(fld.value) then fld.elementCount = #fld.value end
        table.insert(field.sortedFields, fld)
      end
      table.sort(field.sortedFields, function(a, b) if not a.id or not b.id then return false end return a.id < b.id end)
    end
    if field.groupName then lastGrpName = field.groupName end
    field.groupName = lastGrpName
    table.insert(sortedFields, field)
  end

  -- sort by id value (order of declaration in the C++ vector, the id is the index in the fields vector)
  table.sort(sortedFields, function(a, b) if not a.id or not b.id then return false end return a.id < b.id end)

  local groupedSortedFields = {}
  imgui.PushID1("genericFieldNameSearchFilter" .. self.valueInspector.inspectorName)
  if editor.uiInputSearchTextFilter("", self.fieldNameFilter, 200, nil, self.editEnded) then
    if ffi.string(imgui.TextFilter_GetInputBuf(self.fieldNameFilter)) == "" then
      imgui.ImGuiTextFilter_Clear(self.fieldNameFilter)
    end
  end
  imgui.PopID()

  -- put the fields in a grouped table
  local groupIndex = 1
  local groupIndexLUT = {} -- a look up table with the order index for each group

  for i = 1, tableSize(sortedFields) do
    local val = sortedFields[i]

    if val then
      --TODO: use modifiers from the main editor inspector
      for k, v in pairs(self.inspectorFieldModifiers) do
        if v.callback then
          local ret = v.callback(val, self.valueInspector.selectionClassName)
          if ret then val = ret end
        end
      end
    end

    if val and not val.hideInInspector then
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
        table.insert(groupedSortedFields[groupIndexLUT[val.groupName]].fields, val)
      end
    end
  end

  local fieldIndent = 15

  local function contextMenuUI(copyPasteMenu)
    if copyPasteMenu.customData and copyPasteMenu.customData.defaultValue ~= nil then
      if imgui.Button("Reset Value") then
        copyPasteMenu.open = false
        copyPasteMenu.customData.value = copyPasteMenu.customData.defaultValue
      end
    end
  end

  local function displayFields(fields)
    for _, val in ipairs(fields) do
      -- simple field
      if not val.isArray and not val.hidden then
        if val.elementCount == nil or val.elementCount == 1 then
          self.valueInspector:valueEditorGui(val.name, val.value or "", 0, val.name, val.fieldDocs, val.type, val.typeName, val, function (fieldName, fieldValue, arrayIndex, customData) self.fieldSetter(fieldName, fieldValue, arrayIndex, customData, true) end, contextMenuUI)
        else
          local customFieldEditor = editor.findCustomFieldEditor(val.name, self.valueInspector.selectionClassName)
          if customFieldEditor and customFieldEditor.useArray then
            self.valueInspector:valueEditorGui(val.name, val.value or "", 0, val.name, val.fieldDocs, val.type, val.typeName, val, function (fieldName, fieldValue, arrayIndex, customData) self.fieldSetter(fieldName, fieldValue, arrayIndex, customData, true) end, contextMenuUI)
          else
            local nodeFlags = imgui.TreeNodeFlags_DefaultClosed
            imgui.PushStyleColor2(imgui.Col_Header, self.arrayHeaderBgColor)
            if imgui.CollapsingHeader1(val.name.."##Array" .. self.valueInspector.inspectorName, nodeFlags) then
              imgui.Indent(fieldIndent)
              for i = 1, val.elementCount do
                self.valueInspector:valueEditorGui(val.name, val.value[i] or "", i, val.name .. "["..tostring(i - 1).."]", val.fieldDocs, val.type, val.typeName, val, function (fieldName, fieldValue, arrayIndex, customData) self.fieldSetter(fieldName, fieldValue, arrayIndex, customData, true) end, contextMenuUI)
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
        imgui.PushStyleColor2(imgui.Col_Header, self.arrayHeaderBgColor)
        if imgui.CollapsingHeader1(val.arrayName, nodeFlags) then
          imgui.Indent(fieldIndent)
          for i = 1, val.elementCount do
            imgui.PushID1(val.arrayName .. "_ARRAY_ITEMS_" .. i)
            if imgui.CollapsingHeader1("[" .. tostring(i - 1) .. "]", nodeFlags) then
              for _, arrayField in ipairs(val.sortedFields) do
                local arrayFieldName = arrayField.name
                if not arrayField.hidden then
                  self.valueInspector:valueEditorGui(arrayField.name, arrayField.value[i] or "", i, arrayField.name, arrayField.fieldDocs, arrayField.type, arrayField.typeName, arrayField, function (fieldName, fieldValue, arrayIndex, customData) self.fieldSetter(fieldName, fieldValue, arrayIndex, customData, true) end, contextMenuUI)
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

  local function getFieldType(fieldName, fields)
    for _, field in ipairs(fields) do
      if string.lower(field.name) == string.lower(fieldName) then
        return field.type
      end
    end
    return nil
  end

  local function displayGroup(groupName, fields)
    local nodeFlags = imgui.TreeNodeFlags_DefaultOpen
    if not fields then return end
    -- check if any of its fields are filtered
    local passFilter = false
    for _, val in ipairs(fields) do
      if imgui.ImGuiTextFilter_PassFilter(self.fieldNameFilter, val.name) then
        passFilter = true
        val.hidden = false
      else
        val.hidden = true
      end
    end
    if not passFilter then return end
    self.matchedFilterStaticFields = true
    local res = imgui.CollapsingHeader1(groupName, nodeFlags)
    if res then
      displayFields(fields)
    end
  end

  self.matchedFilterStaticFields = false

  -- display the groups and their fields
  for _, group in ipairs(groupedSortedFields) do
    displayGroup(group.groupName, group.fields)
  end

  if not self.matchedFilterStaticFields then
    imgui.PushStyleColor2(imgui.Col_Text, imgui.ImVec4(1, 0.5, 0, 1))
    imgui.Text("<No search matches>")
    imgui.PopStyleColor()
  end
  self.matchedFilterStaticFields = nil
end

function C:initialize(fieldSetter)
  self.valueInspector = require("editor/api/valueInspector")()
  self.fieldSetter = fieldSetter
  self.fieldNameFilter = imgui.ImGuiTextFilter()
  self.newFieldName = imgui.ArrayChar(1024)
  self.matchedFilterStaticFields = true
  self.inspectorTypeHandlers = {}
  self.inspectorFieldModifiers = {}
  self.inspectorCurrentFieldNames = {}
  self.firstObjectId = nil
  self.firstObjectFieldValues = {}
  self.editEnded = imgui.BoolPtr(false)
  self.inputTextValue = imgui.ArrayChar(self.valueInspector.inputTextShortStringMaxSize)
  self.collapseGroups = {}
  self.fields = {}
  self.maxGroupCount = 500
  self.arrayHeaderBgColor = imgui.ImVec4(0.04, 0.15, 0.1, 1)

  for i = 1, self.maxGroupCount do
    table.insert(self.collapseGroups, i, imgui.BoolPtr(false))
  end

  self.valueInspector:initializeTables()
  self.valueInspector.inspectorName = "genericInspector" .. tostring(genericInspectorCount)
  genericInspectorCount = genericInspectorCount + 1
  self.valueInspector.addTypeToTooltip = true -- shows type in field description tooltip
  -- delete the various material/texture thumbs from previous editor show
  self.valueInspector:deleteTexObjs()
  -- set the value callback func, called when the edited value was changed in the value editor widgets
  self.valueInspector.setValueCallback =
    function(fieldName, fieldValue, arrayIndex, customData, editEnded)
      self.fieldSetter(fieldName, fieldValue, arrayIndex, customData, editEnded)
    end
end

return function()
  local o = {}
  setmetatable(o, C)
  C.__index = C
  return o
end