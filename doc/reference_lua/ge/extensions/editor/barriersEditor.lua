  -- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local im = ui_imgui
local ffi = require('ffi')

local toolWindowName = "Barriers Selector"
local searchText = im.ArrayChar(1024, "*barrier*")

local prefabsIndex = {}
local prefabList = {}
local editModeName = 'Barriers Selection'

local function loadPrefabs(level, searchTerm)
  searchTerm = searchTerm or "*barrier*"
  prefabList = {}
  local directory = "/levels/"..level.."/"
  local levelPartLength = (directory:len())+1
  for _, f in ipairs(FS:findFiles("/levels/"..level.."/", searchTerm..".prefab", -1, true,true)) do
    if not prefabsIndex[f] then
      local dir, filename, ext = path.splitWithoutExt(f)
      local scenetreeObject = spawnPrefab("prefab_temp_" .. filename ..os.time(), f, "0 0 0 ", "0 0 1", "1 1 1")
      local short = f:sub(levelPartLength)
      local dirInLevel, _,_ = path.splitWithoutExt(short)
      dirInLevel = dirInLevel or ""
      dirInLevel = dirInLevel..filename
      --scenetree.MissionGroup:add(scenetreeObject)
      local objects = {}
      local center = vec3()
      for i = 0, scenetreeObject:size() - 1 do
        local obj = scenetreeObject:at(i)
        local name = obj:getClassName()
        if obj then
          if name == 'TSStatic' then
            obj = Sim.upcast(obj)
            local pos = vec3(obj:getPosition())
            pos = pos + quat(obj:getRotation())*vec3(0,0,0.5)
            table.insert(objects,pos)
            center = center + pos
          end
        end
      end
      scenetreeObject:delete()
      if #objects > 0 then
        center = center / #objects
        table.insert(prefabList, {
          objects = objects,
          center = center,
          file = f,
          dir = dir,
          filename = filename,
          ext = ext,
          selected = false,
          dirInLevel = dirInLevel
        })
        prefabsIndex[f] = true
      end
    end
  end
end

local function displayPrefab(prefab, highlight)
  local mult = highlight and 1 or 0.3
  debugDrawer:drawTextAdvanced(prefab.center, String(tostring(prefab.filename)), ColorF(1,1,1,1*mult), true, false, ColorI(0,0,0,220*mult))

  local color = ColorF(0,1,0, highlight and 0.9 or 0.25)
  if prefab.selected then
    color = ColorF(1,0,0,highlight and 0.9 or 0.66)
  end
  for _, obj in ipairs(prefab.objects) do
    debugDrawer:drawSphere(obj, 1.5, color)
  end
end

local function onEditorGui()
  if editor.beginWindow(toolWindowName,toolWindowName, im.WindowFlags_MenuBar) then
    if im.BeginMenuBar() then
      if im.BeginMenu("Load...") then
        im.InputText("File pattern", searchText, 1024)
        local level = getCurrentLevelIdentifier()
        if im.MenuItem1("Find for level " .. level) then
          loadPrefabs(level, ffi.string(searchText))
        end
        if im.MenuItem1("Clear results") then
          prefabList = {}
          prefabsIndex = {}
        end
        im.EndMenu()
      end
      if im.BeginMenu("Race Editor") then
        if editor_raceEditor then
          if not editor_raceEditor.isVisible() then
            if im.MenuItem1("Open Race Editor") then
              editor_raceEditor.show()
            end
          else
            if im.MenuItem1("Add Selection to Race Editor") then
              local path = editor_raceEditor.getCurrentPath()
              local contained = {}
              for _, elem in ipairs(path.prefabs) do
                contained[elem] = true
              end
              if path then
                for _, elem in ipairs(prefabList) do
                  if not contained[elem.dirInLevel] and elem.selected then
                    table.insert(path.prefabs, elem.dirInLevel)
                  end
                end
              end
              editor_raceEditor.changedFromExternal()
            end im.tooltip("Adds all selected prefabs to the race, if they are not contained already.")
            if im.MenuItem1("Set Selection exactly to Race Editor") then
              local path = editor_raceEditor.getCurrentPath()
              local contained = {}
              for _, elem in ipairs(path.prefabs) do
                contained[elem] = true
              end
              if path then
                for _, elem in ipairs(prefabList) do
                  if not contained[elem.dirInLevel] and elem.selected then
                    table.insert(path.prefabs, elem.dirInLevel)
                  end
                  if contained[elem.dirInLevel] and not elem.selected then
                    table.remove(path.prefabs,arrayFindValueIndex(path.prefabs, elem.dirInLevel))
                  end
                end
              end
              editor_raceEditor.changedFromExternal()
            end im.tooltip("Adds all selected prefabs to the race and removed non-selected prefabs from the race")
            if im.MenuItem1("Copy Selection from Race Editor") then
              local path = editor_raceEditor.getCurrentPath()
              local contained = {}
              for _, elem in ipairs(path.prefabs) do
                contained[elem] = true
              end
              if path then
                for _, elem in ipairs(prefabList) do
                  elem.selected = contained[elem.dirInLevel] or false
                end
              end
              editor_raceEditor.changedFromExternal()
            end im.tooltip("Sets the currently selected prefebs to the one contained in the race.")
          end
        end
        if im.BeginMenu("Prefabs") then
          if im.MenuItem1("Load Selected Prefabs") then
            for _, elem in ipairs(prefabList) do
              if elem.selected then
                local scenetreeObject = spawnPrefab("prefab_temp_" .. filename .."__"..os.time(), f, "0 0 0 ", "0 0 1", "1 1 1")
                if scenetree and scenetreeObject and scenetree.MissionGroup then
                  scenetree.MissionGroup:add(scenetreeObject)
                end
              end
            end
          end
          im.EndMenu()
        end

        im.EndMenu()
      end
      im.EndMenuBar()
    end

    if not editor.editMode or editor.editMode.displayName ~= editModeName then
      if im.Button("Enable Mouse Selection", im.ImVec2(im.GetContentRegionAvailWidth(),0)) then
        editor.selectEditMode(editor.editModes[editModeName])
      end
    end

    local width = im.GetContentRegionAvail().x/2 - 20
    im.Columns(3,'tags',false)
    im.SetColumnWidth(0,width)
    im.SetColumnWidth(1,30)
    im.SetColumnWidth(2,width)
    im.PushStyleColor2(im.Col_Text, im.ImVec4(0,1,0,1))
    im.Text("Unselected Barriers:")
    im.PopStyleColor()
    im.NextColumn()
    im.NextColumn()
    im.PushStyleColor2(im.Col_Text, im.ImVec4(1,0,0,1))
    im.Text("Selected Barriers:")
    im.PopStyleColor()
    im.NextColumn()
    im.BeginChild1("hasTags", nil, im.WindowFlags_ChildWindow)
    local flip = nil
    for i, elem in ipairs(prefabList) do
      if not elem.selected then
        if im.Selectable1(elem.filename..'##'..i) then
          flip = {elem = elem, dir = 'add', i = i}
        end
        im.tooltip(elem.dirInLevel)
        displayPrefab(elem, im.IsItemHovered())
      end
    end
    im.EndChild()
    im.NextColumn()
    if im.Button(">") then
      for _,elem in ipairs(prefabList) do
        elem.selected = true
      end
    end
    if im.Button("<") then
      for _,elem in ipairs(prefabList) do
        elem.selected = false
      end
    end
    im.NextColumn()
    im.BeginChild1("NoTags", nil, im.WindowFlags_ChildWindow)
    for i, elem in ipairs(prefabList) do
      if elem.selected then
        if im.Selectable1(elem.filename..'##'..i) then
          flip = {elem = elem, dir = 'rem', i = i}
        end
        im.tooltip(elem.dirInLevel)
        displayPrefab(elem, im.IsItemHovered())
      end
    end
    im.EndChild()
    if flip then
      if flip.dir == 'add' then
        flip.elem.selected = true
      else
        flip.elem.selected = false
      end
    end
    editor.endWindow()
  end
end


local function updateEdit()

  local down =  im.IsMouseClicked(0) and not im.GetIO().WantCaptureMouse
  local hold = im.IsMouseDown(0) and not im.GetIO().WantCaptureMouse

  local shift = editor.keyModifiers.shift
  local alt = editor.keyModifiers.alt



  local camPos = getCameraPosition()
  local rayDir = vec3(getCameraMouseRay().dir):normalized()
  local minNodeDist = math.huge
  local closestElem = nil
  local useElem = true
  for idx, prefab in ipairs(prefabList) do
    if shift then
      useElem = not prefab.selected
    elseif alt then
      useElem = prefab.selected
    end
    if useElem then
      for _, pos in ipairs(prefab.objects) do
        local t1,t2 = intersectsRay_Sphere(camPos, rayDir, pos, 1.5)
        if t1>0 and t1 ~= math.huge then
          if t1 < minNodeDist then
            minNodeDist = t1
            closestElem = prefab
          end
        end
      end
    end
  end
  if closestElem then
    for _, obj in ipairs(closestElem.objects) do
      debugDrawer:drawSphere(obj, 1.25, ColorF(0,0,1,0.25))
    end
    if down then
      if shift then
        closestElem.selected = true
      elseif alt then
        closestElem.selected = false
      else
        closestElem.selected = not closestElem.selected
      end
    end
  end


end

local function show()
  editor.clearObjectSelection()
  editor.showWindow(toolWindowName)
end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(1500,700))
  editor.addWindowMenuItem("Barriers Editor", function() show() end, {groupMenuName="Gameplay"})
  editor.editModes[editModeName] =
  {
    displayName = editModeName,
    onUpdate = updateEdit,
    auxShortcuts = {}
  }
  editor.editModes[editModeName].auxShortcuts[editor.AuxControl_LMB] = "Toggle"
  editor.editModes[editModeName].auxShortcuts[bit.bor(editor.AuxControl_LMB, editor.AuxControl_Shift)] = "Only Add"
  editor.editModes[editModeName].auxShortcuts[bit.bor(editor.AuxControl_LMB, editor.AuxControl_Alt)] = "Only Remove"
end

local function onSerialize()
end

local function onDeserialized(data)
end

M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

M.show = show

M.onEditorInitialized = onEditorInitialized
M.onExtensionLoaded = onExtensionLoaded
M.onEditorGui = onEditorGui

return M