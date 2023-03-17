-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local im = ui_imgui
local toolWindowName = "roadTemplateEditor"

local templateDialogOpen = im.BoolPtr(false)
local decalRoads = {}
local decorations = {}
local decals = {}
local chosenTemplateName = ""
local saveName = im.ArrayChar(30)
local saveDialog = im.BoolPtr(false)
local decalRoadSelectionIndex = im.IntPtr(0)
local decorationSelectionIndex = im.IntPtr(0)
local decalSelectionIndex = im.IntPtr(0)


local function deselectTemplate()
  local clearSelection = false
  for _, id in ipairs(decalRoads) do
    editor.deleteRoad(id)
    clearSelection = true
  end
  for _, id in ipairs(decorations) do
    scenetree.findObjectById(id):deleteObject()
    clearSelection = true
  end
  for _, id in ipairs(decals) do
    editor.deleteRoad(id)
    clearSelection = true
  end
  decalRoads = {}
  decorations = {}
  decals = {}
  chosenTemplateName = ""
  if clearSelection then editor.clearObjectSelection() end
end


local function saveAsJson(templateName, data)
  local filename = "levels/".. editor.getLevelName() .. "/roadtemplates/" .. templateName .. ".road.json"
  if jsonWriteFile(filename, data, true) then
    log('I', logTag, "Creation of file \"" .. filename .. "\" successful")
  else
    log('E', logTag, "Creation of file \"" .. filename .. "\" failed")
  end
  editor_roadUtils.reloadTemplates()
end


local function saveTemplate(name)
  local data = {}
  data.header = {
    type = "roadTemplate",
    version = 1.1
  }

  data.roads = {}
  data.decorations = {}
  data.decals = {}
  for i, id in ipairs(decalRoads) do
    local roadInfo = {}
    roadInfo = editor.copyFields(id)
    table.insert(data.roads, roadInfo)
  end

  for i, id in ipairs(decorations) do
    local decoInfo = {}
    local decoObject = scenetree.findObjectById(id)
    for _, field in ipairs(decoObject:getDynamicFields()) do
      decoInfo[field] = decoObject:getField(field, "")
    end
    table.insert(data.decorations, decoInfo)
  end

  for i, id in ipairs(decals) do
    local decalInfo = {}
    decalInfo = editor.copyFields(id)
    table.insert(data.decals, decalInfo)
  end
  saveAsJson(name, data)
end


local decoCounter = 0
local function createDecoObject()
  -- Create the decoration object
  local decoObject = createObject('SimGroup')
  decoObject:registerObject("deco" .. tostring(decoCounter))
  decoCounter = decoCounter + 1
  local decoID = decoObject:getID()

  -- Set the fields for the decoration
  editor.setDynamicFieldValue(decoID, "shapeName", "noshape", false)
  editor.setDynamicFieldValue(decoID, "distance", 2, false)
  editor.setDynamicFieldValue(decoID, "period", 26, false)
  editor.setDynamicFieldValue(decoID, "rotation", 0, false)
  editor.setDynamicFieldValue(decoID, "zOff", 0, false)
  editor.setDynamicFieldValue(decoID, "align", "true", false)
  editor.setDynamicFieldValue(decoID, "randomFactor", 0, false)

  return decoID
end


local function loadTemplate(name)
  deselectTemplate()
  local jsonData = jsonReadFile("levels/".. editor.getLevelName() .. "/roadtemplates/" .. name .. ".road.json")

  -- Create the roads
  for i=1, table.getn(jsonData.roads) do
    local roadID = editor.createRoad({}, jsonData.roads[i])
    table.insert(decalRoads, roadID)
  end

  -- Load the decorations
  for i=1, table.getn(jsonData.decorations) do
    local decoID = createDecoObject()

    -- Set the fields for the decoration
    for field, value in pairs(jsonData.decorations[i]) do
      editor.setDynamicFieldValue(decoID, field, value, false)
    end
    table.insert(decorations, decoID)
  end

  -- Create the decals
  for i=1, table.getn(jsonData.decals) do
    local decalID = editor.createRoad({}, jsonData.decals[i])
    table.insert(decals, decalID)
  end

  chosenTemplateName = name
  editor.selectObjectById(decalRoads[1])
end


local function templateSelectionDialog()
  if templateDialogOpen[0] then
    --TODO: convert to editor.beginWindow/endWindow
    im.Begin("Templates", templateDialogOpen, 0)
      for i=1, #editor_roadUtils.getMaterials() do
        -- Load a template as a set of temporary decal roads
        im.PushID1(string.format('template_%d', i))
        if im.ImageButton(editor_roadUtils.getMaterials()[i].texId, im.ImVec2(128, 128), im.ImVec2Zero, im.ImVec2One, 1,
                          im.ImColorByRGB(0,0,0,255).Value, im.ImColorByRGB(255,255,255,255).Value) then
          templateDialogOpen[0] = false

          -- Extract the template name
          local _, _, name = string.find(editor_roadUtils.getRoadTemplateFiles()[i], "/(%w+)%.road%.json")
          loadTemplate(name)
        end

        if im.IsItemHovered() then
          im.BeginTooltip()
          im.PushTextWrapPos(im.GetFontSize() * 35.0)
          im.TextUnformatted(string.format("%d x %d", editor_roadUtils.getMaterials()[i].size.x, editor_roadUtils.getMaterials()[i].size.y))
          im.TextUnformatted(string.format("%s", editor_roadUtils.getRoadTemplateFiles()[i]))
          im.PopTextWrapPos()
          im.EndTooltip()
        end
        im.PopID()
        if i%4 ~= 0 then im.SameLine() end
      end
    im.End()
  end
end


local function newTemplate()
  deselectTemplate()
  local roadID = editor.createRoad({}, {})
  table.insert(decalRoads, roadID)
  editor.selectObjectById(decalRoads[1])
  chosenTemplateName = "NewTemplate"
end


local function onEditorGui()
  if not editor.isWindowVisible(toolWindowName) then
    deselectTemplate()
    return
  end

  if editor.beginWindow(toolWindowName, "Road Templates") then
    im.BeginChild1("templates", im.ImVec2(0, im.GetFontSize() * 7.2), true)
    im.Text("Road Templates")

    im.Text("Chosen Template: " .. chosenTemplateName)
    if im.Button("Choose Template") then
      templateDialogOpen[0] = true
      editor_roadUtils.reloadTemplates()
    end

    if im.Button("Save") then
      saveTemplate(chosenTemplateName)
    end
    im.SameLine()

    if im.Button("Save as...") then
      saveDialog[0] = true
    end
    im.SameLine()

    if im.Button("New##Template") then
      newTemplate()
    end
    im.SameLine()

    if im.Button("Delete##Template") then
      os.remove("roadtemplates/" .. chosenTemplateName .. ".road.json")
      deselectTemplate()
    end

    im.EndChild()

    -- Save dialog
    if saveDialog[0] then
      im.Begin("Save as...", saveDialog, 0)
      im.InputText("Template Name", saveName)
      if im.Button("Save") then
        local name = ffi.string(ffi.cast("char*",saveName))
        saveTemplate(name)
        chosenTemplateName = name
        saveDialog[0] = false
      end
      im.End()
    end

    templateSelectionDialog()

    im.BeginChild1("decalroads", im.ImVec2(0, im.GetFontSize() * 10), true)
    im.Text("Template Decal Roads")

    -- Selection box for decal roads
    local roadNames = {}
    for i, id in ipairs(decalRoads) do
      local name = editor.getFieldValue(id, "Material")
      if name == "" then name = "No Material" end
      table.insert(roadNames, name)
    end

    if im.ListBox1("", decalRoadSelectionIndex, im.ArrayCharPtrByTbl(roadNames), table.getn(roadNames), 4) then
      editor.selectObjectById(decalRoads[decalRoadSelectionIndex[0]+1])
    end

    -- Decal Road Buttons
    if chosenTemplateName ~= "" then
      if im.Button("New##Road") then
        local roadID = editor.createRoad({}, {})

        editor.setFieldValue(roadID, "improvedSpline", "true", false)
        editor.setDynamicFieldValue(roadID, "horizPosRelative", 0, false)
        editor.setDynamicFieldValue(roadID, "width", 0.1, false)
        editor.setDynamicFieldValue(roadID, "isWidthRelative", "true", false)

        table.insert(decalRoads, roadID)
        editor.selectObjectById(roadID)
        decalRoadSelectionIndex[0] = table.getn(decalRoads) - 1
      end
      im.SameLine()

      if im.Button("Clone##Road") then
        local roadID = editor.createRoad({}, editor.copyFields(decalRoads[decalRoadSelectionIndex[0]+1]))

        if editor.getFieldValue(roadID, "horizPosRelative") == "" and editor.getFieldValue(roadID, "width") == "" then
          editor.setDynamicFieldValue(roadID, "horizPosRelative", 0, false)
          editor.setDynamicFieldValue(roadID, "width", 0.1, false)
          editor.setDynamicFieldValue(roadID, "isWidthRelative", "true", false)
        end

        table.insert(decalRoads, roadID)
        editor.selectObjectById(roadID)
        decalRoadSelectionIndex[0] = table.getn(decalRoads) - 1
      end
      im.SameLine()

      if im.Button("Delete##Road") then
        -- Delete the selected road
        editor.deleteRoad(decalRoads[decalRoadSelectionIndex[0]+1])
        table.remove(decalRoads, decalRoadSelectionIndex[0]+1)

        -- Select the one before
        decalRoadSelectionIndex[0] = math.max(decalRoadSelectionIndex[0] - 1, 1)
        editor.selectObjectById(decalRoads[decalRoadSelectionIndex[0]+1])
      end
    end
    im.EndChild()


    im.BeginChild1("decorations", im.ImVec2(0, im.GetFontSize() * 10), true)
    im.Text("Template Decorations")

    -- Selection box for decorations
    local decoNames = {}
    for i, id in ipairs(decorations) do
      local shapePath = editor.getFieldValue(id, "shapeName")
      local shapeName = string.match(shapePath, ".+/(.*%.dae)")
      if not shapeName then shapeName = "No Shape" end
      table.insert(decoNames, shapeName)
    end

    if im.ListBox1("", decorationSelectionIndex, im.ArrayCharPtrByTbl(decoNames), table.getn(decoNames), 4) then
      editor.selectObjectById(decorations[decorationSelectionIndex[0]+1])
    end

    -- Decoration Buttons
    if chosenTemplateName ~= "" then
      if im.Button("New##Decoration") then
        local decoID = createDecoObject()
        table.insert(decorations, decoID)
        editor.selectObjectById(decoID)
        decorationSelectionIndex[0] = table.getn(decorations) - 1
      end
      im.SameLine()

      if im.Button("Clone##Decoration") then
        local selectedDeco = scenetree.findObjectById(decorations[decorationSelectionIndex[0]+1])
        local cloneID = createDecoObject()
        for _, field in ipairs(selectedDeco:getDynamicFields()) do
          editor.setDynamicFieldValue(cloneID, field, editor.getFieldValue(selectedDeco:getID(), field))
        end
        table.insert(decorations, cloneID)
        decorationSelectionIndex[0] = table.getn(decorations) - 1
      end
      im.SameLine()

      if im.Button("Delete##Decoration") then

        -- Delete the selected deco object
        scenetree.findObjectById(decorations[decorationSelectionIndex[0]+1]):deleteObject()
        table.remove(decorations, decorationSelectionIndex[0]+1)

        -- Select the one before
        decorationSelectionIndex[0] = math.max(decorationSelectionIndex[0] - 1, 1)
        editor.selectObjectById(decorations[decorationSelectionIndex[0]+1])
      end
    end
    im.EndChild()

    im.BeginChild1("decals", im.ImVec2(0, im.GetFontSize() * 10), true)
    im.Text("Template Random Decals")

    -- Selection box for decals
    local decalNames = {}
    for i, id in ipairs(decals) do
      local name = editor.getFieldValue(id, "Material")
      if name == "" then name = "No Material" end
      table.insert(decalNames, name)
    end

    if im.ListBox1("", decalSelectionIndex, im.ArrayCharPtrByTbl(decalNames), table.getn(decalNames), 4) then
      editor.selectObjectById(decals[decalSelectionIndex[0]+1])
    end

    -- Decal Buttons
    if chosenTemplateName ~= "" then
      if im.Button("New##Decal") then
        local decalID = editor.createRoad({}, {})

        editor.setFieldValue(decalID, "improvedSpline", "true", false)
        editor.setDynamicFieldValue(decalID, "minLength", 10, false)
        editor.setDynamicFieldValue(decalID, "maxLength", 20, false)
        editor.setDynamicFieldValue(decalID, "minWidth", 3, false)
        editor.setDynamicFieldValue(decalID, "maxWidth", 3, false)
        editor.setDynamicFieldValue(decalID, "maxHorizOffset", 0.5, false)
        editor.setDynamicFieldValue(decalID, "probability", 0.2, false)

        table.insert(decals, decalID)
        editor.selectObjectById(decalID)
        decalSelectionIndex[0] = table.getn(decals) - 1
      end
      im.SameLine()

      if im.Button("Clone##Decal") then
        local decalID = editor.createRoad({}, editor.copyFields(decals[decalSelectionIndex[0]+1]))

        table.insert(decals, decalID)
        editor.selectObjectById(decalID)
        decalSelectionIndex[0] = table.getn(decals) - 1
      end
      im.SameLine()

      if im.Button("Delete##Decal") then
        -- Delete the selected decal
        editor.deleteRoad(decals[decalSelectionIndex[0]+1])
        table.remove(decals, decalSelectionIndex[0]+1)

        -- Select the one before
        decalSelectionIndex[0] = math.max(decalSelectionIndex[0] - 1, 1)
        editor.selectObjectById(decals[decalSelectionIndex[0]+1])
      end
    end
    im.EndChild()
    im.Text("Use Inspector Window for looking at/changing fields.")
  end
  editor.endWindow()
end

local function onWindowMenuItem()
  editor.showWindow(toolWindowName)
end

local function onEditorInitialized()
  editor.addWindowMenuItem("Road Template Editor", onWindowMenuItem, {groupMenuName = 'Experimental'})
  editor.registerWindow(toolWindowName, im.ImVec2(200, 400))
end

local function onEditorRegisterPreferences(prefsRegistry)
  prefsRegistry:registerCategory("roadTemplates")
  prefsRegistry:registerSubCategory("roadTemplates", "general", nil,
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {loadTemplates = {"bool", false, "Load road templates on startup (longer initialization time)"}}
  })
end

M.dependencies = {"editor_roadEditor"}
M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized
M.onEditorRegisterPreferences = onEditorRegisterPreferences

return M