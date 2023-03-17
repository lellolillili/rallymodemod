-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_preferences'
local imgui = ui_imgui
local toolWindowName = "preferences"
local imguiUtils = require('ui/imguiUtils')
local imguiIO = imgui.GetIO()
local currentCategoryName = nil
local defaultUiScale = 0.92
local valueInspector = require("editor/api/valueInspector")()
local prefItemNameFilter = imgui.ImGuiTextFilter()
local preferencesPagesSortIndex
local preferencesPages
local sortedByIndex = {}
local sortedByName = {}

local function sortPageNames(a, b)
  local indexA = preferencesPagesSortIndex[a]
  local indexB = preferencesPagesSortIndex[b]
  return indexA > indexB
end

local function pageListGui(items)
  local keys = deepcopy(items)

  sortedByIndex = {}
  sortedByName = {}
  table.sort(keys)

  for key, val in pairs(keys) do
    if preferencesPagesSortIndex[key] then
      table.insert(sortedByIndex, key)
    else
      table.insert(sortedByName, key)
    end
  end

  table.sort(sortedByIndex, sortPageNames)
  table.sort(sortedByName)

  local function pageItemGui(pageName, pageLabel)
    local cPos = imgui.GetCursorPos()
    if imgui.Selectable1("  " .. pageLabel, currentCategoryName == pageName) then
      currentCategoryName = pageName
    end
    if currentCategoryName == pageName then
      local windowPos = imgui.GetWindowPos()
      local style = imgui.GetStyle()
      imgui.ImDrawList_AddRectFilled(
        imgui.GetWindowDrawList(),
        imgui.ImVec2(windowPos.x + cPos.x - style.ItemSpacing.x/2, windowPos.y + cPos.y - math.floor(style.ItemSpacing.y/2)),
        imgui.ImVec2(
          windowPos.x + cPos.x - style.ItemSpacing.x/2 + 5,
          windowPos.y + cPos.y + math.ceil(imgui.GetFontSize() + style.ItemSpacing.y/2)
        ),
        imgui.GetColorU321(imgui.Col_HeaderActive)
      )
    end
  end

  -- find the first displayed category name in the list if nil
  if not currentCategoryName or not preferencesPages[currentCategoryName] then
    if #sortedByIndex then
      currentCategoryName = sortedByIndex[1]
    end
    if #sortedByName and (not currentCategoryName or not preferencesPages[currentCategoryName]) then
      currentCategoryName = sortedByName[1]
    end
  end

  for _, pageName in ipairs(sortedByIndex) do
    pageItemGui(pageName, preferencesPages[pageName])
  end

  for _, pageName in ipairs(sortedByName) do
    pageItemGui(pageName, preferencesPages[pageName])
  end
end

local function pastePrefValue(fieldName, copiedValue, arrayIndex, customData)
  editor.setPreference(customData.path, editor.preferencesRegistry:itemValueFromString(customData, copiedValue))
end

local function contextMenuUI(copyPasteMenu)
  if imgui.Button("Reset Value") then
    copyPasteMenu.open = false
    editor.preferencesRegistry:resetItemToDefault(copyPasteMenu.customData.path)
  end
  if imgui.Button("Copy Preference Path") then
    copyPasteMenu.open = false
    setClipboard(copyPasteMenu.customData.path)
  end
end

local function customItemUi(selectedIds, fieldValue, fieldName, fieldLabel, fieldDesc, fieldType, fieldTypeName, customData, pasteCallback, contextMenuUI)
  customData.customUiFunc(customData.catName, customData.subCatName, customData)
end

local function itemGui(cat, subCat, item)
  local fieldValue = editor.preferencesRegistry:getAsString(item.path)
  local desc = item.description

  if not desc or desc == "" then desc = "<No description>" end

  desc = desc .. "\n\nPath: " .. item.path .. "\nType: " .. item.type .. "\nDefault Value: " .. editor.preferencesRegistry:itemValueToString(item, item.defaultValue)

  if item.customUiFunc and not item.catName then
    -- used in customItemUi
    item.catName = cat.name
    item.subCatName = subCat.name
    editor.registerCustomFieldInspectorEditor("Preferences", item.name, customItemUi)
  end
  valueInspector:valueEditorGui(item.name, fieldValue or "", 0, item.label, desc, item.type or "", item.typeName or "", item, pastePrefValue, contextMenuUI)
end

local function importExportUi(catName)
  imgui.PushID1(catName .. "impExpResetCategory")
  if not imgui.ImGuiTextFilter_IsActive(prefItemNameFilter) then
    if imgui.Button("Export...") then
      editor_fileDialog.saveFile(
        function(data) editor.preferencesRegistry:saveCategory(catName, data.filepath) end,
        {{"Preferences Files",".json"}}, false, "/")
    end
    if imgui.IsItemHovered() then imgui.SetTooltip("Export the current category page preferences to a file, for sharing and backup") end

    imgui.SameLine()
    if imgui.Button("Import...") then
      editor_fileDialog.openFile(
        function(data) editor.preferencesRegistry:loadCategory(catName, data.filepath) end,
        {{"Preferences Files",".json"}}, false, "/")
    end
    if imgui.IsItemHovered() then imgui.SetTooltip("Import the current category page preferences from a file (overwriting current values)") end
    imgui.SameLine()

    if imgui.Button("Reset Category To Defaults") then
      imgui.OpenPopup("Reset Category Preferences To Defaults")
    end

    if imgui.IsItemHovered() then imgui.SetTooltip("Reset the current category preferences values to defaults") end

    if imgui.BeginPopupModal("Reset Category Preferences To Defaults", nil, imgui.WindowFlags_AlwaysAutoResize) then
      imgui.Text("Do you really want to reset this category preferences to default values ?\n"..
                "Warning: This operation is not undoable.\n\n\n")
      imgui.Separator()
      if imgui.Button("Yes", imgui.ImVec2(120,0)) then imgui.CloseCurrentPopup() editor.preferencesRegistry:resetToDefaults(catName) end
      imgui.SameLine()
      if imgui.Button("No", imgui.ImVec2(120,0)) then imgui.CloseCurrentPopup() end
      imgui.EndPopup()
    end
  end
  imgui.PopID()
end

local function pageGui(cat)
  if not cat then return end
  local nodeFlags = imgui.TreeNodeFlags_DefaultOpen
  local hasVisibleItems = false

  -- prefilter the subcategories for the search term, if no items visible/match then do not show the subcategory
  for _, subCat in ipairs(cat.subcategories) do
    subCat.visibleOnSearch = false
    for i = 1, #subCat.items do
      if (imgui.ImGuiTextFilter_PassFilter(prefItemNameFilter, subCat.items[i].label)
        or imgui.ImGuiTextFilter_PassFilter(prefItemNameFilter, subCat.items[i].name))
        and not subCat.items[i].hidden
      then
        subCat.visibleOnSearch = true
        subCat.items[i].visibleOnSearch = true
        hasVisibleItems = true
      else
        subCat.items[i].visibleOnSearch = false
      end
    end
  end

  if not hasVisibleItems then return end

  imgui.Spacing()
  imgui.Spacing()
  imgui.Spacing()
  imgui.Columns(2, valueInspector.inspectorName .. "FieldsColumn")
  imgui.PushFont3("cairo_regular_medium")
  imgui.TextColored(imgui.GetStyleColorVec4(imgui.Col_NavHighlight), cat.label .. " Preferences")
  imgui.PopFont()
  imgui.NextColumn()
  imgui.PushItemWidth(imgui.GetContentRegionAvailWidth())
  importExportUi(cat.name)
  imgui.PopItemWidth()
  imgui.Columns(1)

  -- show the visible subcategories and their items
  for _, subCat in ipairs(cat.subcategories) do
    if subCat.visibleOnSearch and imgui.CollapsingHeader1(subCat.label, nodeFlags) then
      imgui.Indent(15)
      imgui.PushID1(subCat.name .. "_PREF_ITEMS")
      for i = 1, #subCat.items do
        if subCat.items[i].visibleOnSearch and not subCat.items[i].hidden then
          itemGui(cat, subCat, subCat.items[i])
        end
      end
      imgui.PopID()
      imgui.Unindent(15)
      imgui.Separator()
    end
  end

end

local function onEditorGui()
  if editor.beginWindow(toolWindowName, "Preferences") then
    local bottom_margin = 48 * imgui.uiscale[0];  -- Scaled bottom margin for window sections
    -- the left side list of pref pages
    imgui.BeginChild1("Preferences Pages", imgui.ImVec2(imgui.uiscale[0] * 160, -bottom_margin), true)
    pageListGui(preferencesPages)
    imgui.EndChild()
    imgui.SameLine()

    imgui.BeginChild1("Preferences Page", imgui.ImVec2(0, -bottom_margin), true)
    if editor.uiInputSearchTextFilter("##prefItemNameSearchFilter", prefItemNameFilter, 200, nil, editEnded) then
      if ffi.string(imgui.TextFilter_GetInputBuf(prefItemNameFilter)) == "" then
        imgui.ImGuiTextFilter_Clear(prefItemNameFilter)
      end
    end

    -- the current pref page
    imgui.BeginChild1("Preferences Page Items")

    if currentCategoryName ~= "all" then
      pageGui(editor.preferencesRegistry:findCategory(currentCategoryName))
    else
      for _, pageName in ipairs(sortedByIndex) do
        if pageName ~= "all" then
          pageGui(editor.preferencesRegistry:findCategory(pageName))
        end
      end

      for _, pageName in ipairs(sortedByName) do
        pageGui(editor.preferencesRegistry:findCategory(pageName))
      end
    end

    imgui.EndChild()
    imgui.EndChild()

    if not imgui.ImGuiTextFilter_IsActive(prefItemNameFilter) then
      imgui.BeginChild1("Preferences Actions")  -- Bottom area for common action buttons
      --  Right alignment
      imgui.Spacing(imgui.ImVec2(0, 0))
      local prefWindowCurrWidth = imgui.GetContentRegionAvailWidth();
      imgui.SameLine(prefWindowCurrWidth - 150 * imgui.uiscale[0])
      if imgui.Button("Reset All To Defaults") then
        imgui.OpenPopup("Reset All To Defaults")
      end
      if imgui.IsItemHovered() then imgui.SetTooltip("Reset all preferences to their default values") end
      -- Reset-all confirmation
      if imgui.BeginPopupModal("Reset All To Defaults", nil, imgui.WindowFlags_AlwaysAutoResize) then
        imgui.Text("Do you really want to reset all preferences to default values ?\n"..
                  "Warning: This operation is not undoable.\n\n\n")
        imgui.Separator()
        if imgui.Button("Yes", imgui.ImVec2(120,0)) then imgui.CloseCurrentPopup() editor.preferencesRegistry:resetToDefaults() end
        imgui.SameLine()
        if imgui.Button("No", imgui.ImVec2(120,0)) then imgui.CloseCurrentPopup() end
        imgui.EndPopup()
      end
      imgui.EndChild()
    end
  end
  editor.endWindow()
end

local function showPreferences(categoryName)
  if categoryName then currentCategoryName = categoryName end
  editor.showWindow(toolWindowName)
end

local function onExtensionLoaded()
end

local function setPrefWithOldValues(customData, fieldName, fieldValue, startValues, arrayIndex, editEnded)
  --TODO?
end

local function setPrefValue(customData, fieldName, fieldValue, arrayIndex, editEnded)
  -- TODO: UNDO support!
  editor.setPreference(customData.path, fieldValue)
end

local function onEditorPreferenceValueChanged(path, value)
  if path == "ui.general.scale" then imguiUtils.changeUIScale(value) end
  if path == "ui.general.iconButtonSize" then editor.setDefaultIconButtonSize(value) end
  if path == "ui.general.showCompleteSceneTree" then editor.refreshSceneTreeWindow() end
  if path == "camera.general.smoothCameraMove" then editor.setSmoothCameraMove(value) end
  if path == "camera.general.smoothCameraRotate" then editor.setSmoothCameraRotate(value) end
  if path == "camera.general.freeCameraMoveSmoothness" then
    editor.setSmoothCameraDragNormalized(value)
  end
  if path == "camera.general.freeCameraRotateSmoothness" then
    editor.setSmoothCameraAngularDragNormalized(value)
  end
end

local function myUi(cat, subCat, item)
  imgui.Text(tostring(editor.getPreference(item.path)))
end

local function onEditorRegisterPreferences(prefsRegistry)
  prefsRegistry:registerCategory("general")
  prefsRegistry:registerCategory("camera")
  prefsRegistry:registerCategory("ui", "User Interface")

  prefsRegistry:registerSubCategory("general", "internal", nil,
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    -- hidden
    {cleanExit = {"bool", true, "If true, the game exited properly and level was saved ok, used for autosave backups", nil, nil, nil, true}},
    {lastLevel = {"string", "", "The last edited level", nil, nil, nil, true}},
  })

  prefsRegistry:registerSubCategory("ui", "general", nil,
  {
    {floatDigitCount = {"int", 3, "The float numbers decimal precision"}},
    {hexColorInput = {"bool", true, "Use hex format for color input in field/value inspector"}},
    {scale = {"float", defaultUiScale, "The global UI scale for editor widgets", nil, 0.4, 3}},
    {iconButtonSize = {"float", 28, "The size of the icon buttons found in the toolbars"}},
    {singleLineToolbar = {"bool", false, "Arrange toolbar buttons on a single row, otherwise use another row for the current edit mode buttons"}},
    {enableVehicleControls = {"bool", true, "Enable driving the vehicle while editor is active"}},
    {sceneMetric = {"bool", true, "Display scene metrics"}},
    {useSlidersInInspector = {"bool", false, "Use sliders instead of +/- buttons in the inspector."}},
    {showCompleteSceneTree = {"bool", false, "Show all of the scene tree nodes, use for advanced debugging."}},
    {showInternalName = {"bool", false, "Displays the InternalName of a node if the Name is empty."}},
    })

  prefsRegistry:registerSubCategory("camera", "general", nil,
  {
    {freeCameraMoveSmoothness = {"float", 0.3, "The free camera's move smoothness", nil, 0, 1}},
    {freeCameraRotateSmoothness = {"float", 0.3, "The free camera's angular smoothness", nil, 0, 1}},
    {smoothCameraMove = {"bool", true, "Newtonian free camera smooth movement damping"}},
    {smoothCameraRotate = {"bool", true, "Newtonian free camera smooth rotation damping"}},
    {setVehicleCameraWhenExitingEditor = {"bool", true, "Set the vehicle camera when exiting the editor"}},
  })
end

local function updatePreferencePages()
  -- we register a default general category so the code doesnt need to check for invalid category name on UI show
  editor.preferencesRegistry:registerCategory("general", "General")

  -- fill up the pref pages
  preferencesPages = {}
  for _, cat in ipairs(editor.preferencesRegistry.categories) do
    -- check to see if it has any visible subcateg items
    local hasVisibleItems = false
    for _, subCat in ipairs(cat.subcategories) do
      for _, item in ipairs(subCat.items) do
        if not item.hidden then hasVisibleItems = true break end
      end
    end
    if hasVisibleItems then
      preferencesPages[cat.name] = cat.label
    end
  end

  preferencesPages["all"] = "All"
end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, imgui.ImVec2(800, 600))
  valueInspector.inspectorName = "preferencesInspector"
  valueInspector.selectionClassName = "Preferences" -- used as a tag for custom pref ui
  -- delete the various material/texture thumbs from previous editor show
  valueInspector:deleteTexObjs()
  -- set the value callback func, called when the edited value was changed in the value editor widgets
  valueInspector.setValueCallback = function(fieldName, fieldValue, arrayIndex, customData, editEnded)
    -- the incoming value is stringify, so make it a real value
    fieldValue = editor.preferencesRegistry:itemValueFromString(customData, fieldValue)
    if customData and customData.startValues then
      setPrefWithOldValues(customData, fieldName, fieldValue, customData.startValues, arrayIndex, editEnded)
    else
      setPrefValue(customData, fieldName, fieldValue, arrayIndex, editEnded)
    end
  end

  preferencesPagesSortIndex = { all = 10000, general = 9999 } -- the highest is listed first in the page name list
  updatePreferencePages()
  editor.updatePreferencePages = updatePreferencePages
  editor.showPreferences = showPreferences
end

local function onSerialize(state)
  return { currentCategoryName = currentCategoryName }
end

local function onDeserialized(state)
  currentCategoryName = state.currentCategoryName
end

local function onEditorDeactivated()
  imguiUtils.changeUIScale(1)
  if editor.getPreference("camera.general.setVehicleCameraWhenExitingEditor") and not editor.isGameFreeCamera then
    editor.selectCamera(editor.CameraType_Game)
  end
end

local function onEditorActivated()
  imguiUtils.changeUIScale(editor.getPreference("ui.general.scale"))
end

M.onEditorGui = onEditorGui
M.onExtensionLoaded = onExtensionLoaded
M.onEditorInitialized = onEditorInitialized
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized
M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onEditorPreferenceValueChanged = onEditorPreferenceValueChanged
M.onEditorDeactivated = onEditorDeactivated
M.onEditorActivated = onEditorActivated

return M