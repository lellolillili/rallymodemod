-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local tbFunctions = {}
local logTag = 'editor_trackBuilder'

-- most important stuff first
local im = ui_imgui
local guiModule = require("ge/extensions/editor/api/gui")
local tb = nil
local screenshot = nil
local isOnGlowCity = false
-- window/imgui related stuff
local open = im.BoolPtr(false)
local trackSpawned = false
local wasOpen = false
local initialized = false
local camDistanceChanged = im.BoolPtr(false)
local hiddenForScreenshotTimer = 0
local screenshotTaken = false
local stopDrivingWindowOpen = im.BoolPtr(false)
local exitButtonWindowOpen = im.BoolPtr(true)
local menuSettings = {
  hideModifiers = {value = im.BoolPtr(true), type="bool"},
  hidePieces = {value=im.BoolPtr(true), type="bool"},
  camActivated = {value=im.BoolPtr(true), type="bool"},
  camDistance = {value=im.FloatPtr(80), type="float"}
}

local clickInputModes = {
  leftMesh = im.BoolPtr(true),
  centerMesh = im.BoolPtr(false),
  rightMesh = im.BoolPtr(true),
}

local materialWindowWasOpen = false
local borderWindowWasOpen = false

local paintModes = nil
local paintModesSorted = {"Select", "Paint", "ChangeMesh"}
local driving = false

local menuItems = nil
local additionalMenuItems = nil

-- design/style related stuff
local windowsState = {}

local style = {
  textColor = im.ImVec4(1.0, 1.0, 0.0, 1.0),
  buttonColorBase = im.ImVec4(0,0,0,1.0),
  buttonColorBG = im.ImVec4(0,0,0,1),
  buttonColorBGSelected = im.ImVec4(0,0,0,1),
  colorYellow = im.ImVec4(1,1,0,1),
  colorRed = im.ImVec4(1,0,0,1),
  colorGreen =im.ImVec4(0,1,0,1),
  selectedPieceColor = im.ImVec4(0.5, 0.75, 1, 1.0),
  initialWindowSize = im.ImVec2(400, 300),
  nextWindowPos = im.ImVec2(600, 200),
  buttonSize = im.ImVec2(44,44),
  thinButtonSize = im.ImVec2(44,22),
  slimButtonSize = im.ImVec2(22,44)
}

style.fullToolbarsWidth = nil
style.toolbarWidth = nil
style.paintToolbarWidth = nil
style.displaySize = nil
style.toolbarSpacing = 50

local menuItemsSorted = nil
local additionalMenuItemsSorted = nil

-- track builder related stuff
local currentIndex = 1
local subTrackIndex = im.IntPtr(1)

local difficultyTbl = {'Easy','Medium','Hard','Very Hard'}
local difficulty = im.ArrayCharPtrByTbl(difficultyTbl)
local interpolationsTbl = {'smoothSlope','smootherSlope','linear','pow2','pow3','pow4'}
local interpolations = im.ArrayCharPtrByTbl(interpolationsTbl)
local bordersTbl = { 'regular','bevel','wideBevel','highBevel','smallDiagonal','bigDiagonal','rail','none',"demoConvex","smoothedRect", 'racetrack' }
local borders = im.ArrayCharPtrByTbl(bordersTbl)
local centersTbl = { 'regular', 'flat' ,'demoConvex'}
local centers = im.ArrayCharPtrByTbl(centersTbl)
local obstaclesTbl = { 'cube','bump','sharp','ramp', 'obstacle','ring','cylinder','cone'}
local obstacles = im.ArrayCharPtrByTbl(obstaclesTbl)
local anchorsTbl = {'Left Border','Center', 'Right Border' }
local anchors = im.ArrayCharPtrByTbl(anchorsTbl)

local modifierValues = {
  bank   = { value = im.IntPtr(0),  interpolation = im.IntPtr(0), inverted = im.BoolPtr(false)},
  width  = { value = im.IntPtr(10), interpolation = im.IntPtr(0), inverted = im.BoolPtr(false)},
  height = { value =im.FloatPtr(0), interpolation = im.IntPtr(0), inverted = im.BoolPtr(false),
    customSlope = im.BoolPtr(false), customSlopeValue = im.IntPtr(0),
    },

  leftMesh = { value = im.IntPtr(0), table = bordersTbl, meshName = 'leftMesh' },
  centerMesh  = { value = im.IntPtr(0), table = centersTbl, meshName = 'centerMesh'},
  rightMesh = { value = im.IntPtr(0), table = bordersTbl, meshName = 'rightMesh'},

  checkpoint = { size = im.FloatPtr(4), position = im.ArrayFloat(3), active = im.BoolPtr(false)},
  leftWall = {value = im.FloatPtr(1), active = im.BoolPtr(false), interpolation = im.IntPtr(0), inverted = im.BoolPtr(false) },
  rightWall = {value = im.FloatPtr(1), active = im.BoolPtr(false), interpolation = im.IntPtr(0), inverted = im.BoolPtr(false) },
  ceilingMesh = {value = im.FloatPtr(7), active = im.BoolPtr(false), interpolation = im.IntPtr(0), inverted = im.BoolPtr(false) },
  obstacles = { list = {}},
}
local obstacleInfo = {
  cube = {
    variants = 2,
    dimensions = 3,
    scale = {3,3,3}
  },
  bump = {
    variants = 0,
    dimensions = 5,
    scale = {6,3,1,4,0.5}
  },
  sharp = {
    variants = 2,
    dimensions = 3,
    scale = {1,1,1}
  },
  ramp = {
    variants = 0,
    dimensions = 5,
    scale = {5,10,3,0.9,1.5}
  },
  obstacle = {
    variants = 2,
    dimensions = 3,
    scale = {1,1,1}
  },
  ring = {
    variants = 0,
    dimensions = 2,
    scale = {2.5,1}
  },
  cylinder = {
    variants = 0,
    dimensions = 2,
    scale = {1,5}
  },
  cone = {
    variants = 0,
    dimensions = 2,
    scale = {3,5}
  }
}

local obstacleMatNames = {}
local obstacleMatDisplayNames = im.ArrayCharPtrByTbl({
  'Material A Border','Material A Center','Material B Border', 'Material B Center','Material C Border', 'Material C Center','Material D Border', 'Material D Center',
  'Material E Border','Material E Center','Material F Border', 'Material F Center','Material G Border', 'Material G Center','Material H Border', 'Material H Center'
  })
local trackPositionValues = {position = im.ArrayFloat(3), rotation = im.FloatPtr(0) }
trackPositionValues.position[0] = im.Float(0)
trackPositionValues.position[1] = im.Float(0)
trackPositionValues.position[2] = im.Float(15)

local currentMergeList = {}

local currentCheckpointList = {}
local currentPieceName = ''
local pieceInfo = {
  free = {
    curve = {
      radius = im.FloatPtr(3),
      length = im.FloatPtr(45),
      direction = im.IntPtr(-1),
      piece = 'freeCurve'
    },
    forward = {
      length = im.FloatPtr(3),
      piece = 'freeForward'
    },
    scurve = {
      length = im.FloatPtr(6),
      xOffset = im.FloatPtr(2),
      hardness = im.FloatPtr(0),
      piece = 'freeOffsetCurve'
    },
    loop = {
      radius = im.FloatPtr(8),
      xOffset = im.FloatPtr(4),
      piece = 'freeLoop'
    },
    bezier = {
      xOff = im.FloatPtr(4),
      yOff = im.FloatPtr(8),
      dirOff = im.FloatPtr(90),
      forwardLen = im.FloatPtr(4),
      backwardLen = im.FloatPtr(4),
      absolute = im.BoolPtr(false),
      empty = im.BoolPtr(false),
      piece = 'freeBezier'
    },
    spiral = {
      size = im.FloatPtr(3),
      angle = im.FloatPtr(30),
      inside = im.BoolPtr(false),
      direction = im.IntPtr(-1),
      piece = 'freeSpiral'
    }
  }
}

-- set up obstacles
for i = 1, 10 do
  modifierValues.obstacles.list[i] =
    { value = im.IntPtr(0), variant = im.IntPtr(1), anchor = im.IntPtr(1), offset = im.FloatPtr(1), position = im.ArrayFloat(3), rotation = im.ArrayFloat(3), scale = im.ArrayFloat(3), extra = im.ArrayFloat(3), show = false, material = im.IntPtr(0)}
  modifierValues.obstacles.list[i].scale[0] = 1
  modifierValues.obstacles.list[i].scale[1] = 1
  modifierValues.obstacles.list[i].scale[2] = 1
  modifierValues.obstacles.list[i].extra[0] = 1
  modifierValues.obstacles.list[i].extra[1] = 1
  modifierValues.obstacles.list[i].extra[2] = 1
end

local saveSettings = nil

-- material editor stuff
local loadFilesFilter = im.ImGuiTextFilter()
local materials = {
  materialInfo = {
    leftMesh = { value = im.IntPtr(0), table = "border", paint = im.BoolPtr(true)},
    centerMesh = { value = im.IntPtr(0), table = "center", paint = im.BoolPtr(true)},
    rightMesh = { value = im.IntPtr(0), table = "border", paint = im.BoolPtr(true)},
    leftWall = { value = im.IntPtr(0), table = "border", paint = im.BoolPtr(true)},
    rightWall = { value = im.IntPtr(0), table = "border", paint = im.BoolPtr(true)},
    ceilingMesh = { value = im.IntPtr(0), table = "border", paint = im.BoolPtr(true)}
  },
  matNames = {'track_editor_A_','track_editor_B_','track_editor_C_','track_editor_D_','track_editor_E_','track_editor_F_','track_editor_G_','track_editor_H_'},
  displayNames = {'Material A','Material B','Material C','Material D','Material E','Material F','Material G','Material H'}
}
materials.matNameArray = im.ArrayCharPtrByTbl(materials.displayNames)
local materialSettings = {
  -- fs
  directory = "core/art/trackBuilder",
  -- materials
  nullMat = nil,
  base = nil,
  center = nil,
  border = nil,
  centerBaseColor = ffi.new("float[4]", {1.0, 1.0, 1.0, 1.0}),
  borderBaseColor = ffi.new("float[4]", {1.0, 1.0, 1.0, 1.0}),
  centerGlowColor = ffi.new("float[4]", {1.0, 1.0, 1.0, 1.0}),
  borderGlowColor = ffi.new("float[4]", {1.0, 1.0, 1.0, 1.0}),
  centerGlow = im.BoolPtr(true),
  borderGlow = im.BoolPtr(true),
  groundModel = im.IntPtr(0),
  materials = {
    center = {},
    border = {}
  },

  selectedMaterial = im.IntPtr(0),
  -- textures
  textureSets = {},
  texteSetsSize = 0,
  glowMaps = {},
  glowMapsSize = 0,
  -- drag'n'drop
  dragging = false,
  dragDropData = nil,
  dragDropImage = nil,

  groundModels = nil,
  groundModelNames = nil,
  groundModelNamesPtr = nil,
  groundModelHasChanged = false
}

-- helper functions

-- returns the index of a value in a table or -1 if it is not contained.
local function indexOf(table, value)
  for i,v in ipairs(table) do
    if v == value then return i end
  end
  return -1
end

-- returns the index of a mesh from its name.
local function meshNameToIndex(name)
  if not string.startswith(name,"procMesh") then return -1,-1 end
  local dashIndex = string.find(name,"-")
  return tonumber(string.match (name, "%d+",dashIndex)),tonumber(string.match (name, "%d+"))
end

-- selects a mode for the mouse: Select, Paint or ChangeMesh
local function selectMode(name)
  for k,v in pairs(paintModes) do
    if k == name then
      v.active[0] = true
      if name == "Paint" then
        menuItems.materialEditor.isOpen[0] = true
      elseif name == "ChangeMesh" then
        menuItems.borders.isOpen[0] = true
      end
    else
      v.active[0] = false
    end
  end
end

local function debug()
  if im.Button("Make") then tb.makeTrack() end
  im.Text("currentIndex " .. currentIndex)
end

-- selects/deselects all parts when using the Paint mouse mode.
local function setAllPaintModes(active)
  for name, tbl in pairs(materials.materialInfo) do
    tbl.paint[0] = active
  end
end

-- partitions a width into n equal parts
local function partitionWidth(totalWidth, itemWidth, itemCount)
  local ret = {}
  local spacePerItem = totalWidth/(itemCount)
  for i = 1, itemCount do
    ret[i] = spacePerItem * i -spacePerItem/2 - itemWidth/2
  end
  return ret
end

-- creates a navigation row with camera icon
local function navigationRow()
  local piecePositions = partitionWidth(im.GetWindowWidth(), 46, 5)
  im.SetCursorPosX(piecePositions[1]+10)
  if im.Button("|<",style.thinButtonSize) then tbFunctions.navigate('first') end
  im.tooltip(translateLanguage("ui.trackBuilder.selection.first", "Select First Piece"))
  im.SameLine()
  im.SetCursorPosX(piecePositions[2]+10)
  if im.Button("<",style.thinButtonSize) then tbFunctions.navigate(-1) end
  im.tooltip(translateLanguage("ui.trackBuilder.selection.previous", "Select Previous Piece"))
  im.SameLine()
  im.SetCursorPosX(piecePositions[3] + 10)
  if editor.uiIconImageButton(editor.icons.videocam, im.ImVec2(22,22), style.buttonColorBase) then
    tb.focusCameraOn(currentIndex,nil, true)
  end
  im.tooltip(translateLanguage("ui.trackBuilder.camera.focus", 'Focus camera on selected piece'))
  im.SameLine()
  im.SetCursorPosX(piecePositions[4]-10)
  if im.Button(">",style.thinButtonSize) then tbFunctions.navigate(1) end
  im.tooltip(translateLanguage("ui.trackBuilder.selection.next", "Select Next Piece"))
  im.SameLine()
  im.SetCursorPosX(piecePositions[5]-10)
  if im.Button(">|",style.thinButtonSize) then tbFunctions.navigate('last') end
  im.tooltip(translateLanguage("ui.trackBuilder.selection.last", "Select Last Piece"))
end

-- creates a row of modifier buttons (modify, delete, reset)
local function modifierButtons(name, resetValue, hasInterpolation, size)
  --if im.SmallButton("m##"..name) then
  if editor.uiIconImageButton(editor.icons.adjust, size or im.ImVec2(20,20), style.colorYellow) then
    tbFunctions.modifierChange(name)
  end
  im.tooltip(translateLanguage("ui.trackBuilder.tooltip.modify", "Modify"))
  im.SameLine()
  --if im.SmallButton("x##"..name) then
  if editor.uiIconImageButton(editor.icons.delete, size or im.ImVec2(20,20), style.colorRed) then
    tbFunctions.modifierRemove(name)
  end
  im.tooltip(translateLanguage("ui.trackBuilder.tooltip.remove", "Remove"))
  im.SameLine()
  --if im.SmallButton("r##"..name) then
  if editor.uiIconImageButton(editor.icons.undo, size or im.ImVec2(20,20), style.colorGreen) then
    modifierValues[name].value[0] = resetValue
    tbFunctions.modifierChange(name)
  end
  im.tooltip(translateLanguage("ui.trackBuilder.tooltip.reset", "Reset"))
  if hasInterpolation then
    if im.Combo1("##"..name, modifierValues[name].interpolation, interpolations) then
      tbFunctions.modifierChange(name)
    end

    im.SameLine()
    if im.Checkbox(translateLanguage("ui.trackBuilder.modifier.inverted", "Inverted") .. "##"..name, modifierValues[name].inverted) then
      tbFunctions.modifierChange(name)
    end
  end
end
-- Materials Editor

local function addFileToTextureSet(file, name, type)
  if not materialSettings.textureSets[name] then
    materialSettings.textureSets[name] = {}
    materialSettings.texteSetsSize = materialSettings.texteSetsSize + 1
  end
  materialSettings.textureSets[name][type] = file
end

local function setupTextures()
  for _, file in pairs(FS:findFiles(materialSettings.directory, "*.dds", -1, true, false)) do
    local fileWithoutExtension = string.sub(file, 1, string.len(file) - 4)
    local textureType = string.sub(fileWithoutExtension, string.len(fileWithoutExtension) - 1, string.len(fileWithoutExtension))
    local path = {}
    for str in string.gmatch(string.sub(fileWithoutExtension, 1, string.len(fileWithoutExtension) - 2), "([^'/']+)") do
      table.insert( path, str )
    end

    local name = path[#path]
    if textureType == '_d' then -- diffuse map
      addFileToTextureSet(file, name , 'd')
    elseif textureType == '_n' then -- normal map
      addFileToTextureSet(file, name , 'n')
    elseif textureType == '_s' then -- specular map
      addFileToTextureSet(file, name , 's')
   else -- glow map
      local texType = string.sub(fileWithoutExtension, string.len(fileWithoutExtension) - 4, string.len(fileWithoutExtension))
      if texType == "decal" then
        local path = {}
        for str in string.gmatch(string.sub(fileWithoutExtension, 1, string.len(fileWithoutExtension) - 6), "([^'/']+)") do
          table.insert( path, str )
        end
        materialSettings.glowMaps[path[#path]] = {file=file, tex=editor.texObj(file)}
        materialSettings.glowMapsSize = materialSettings.glowMapsSize + 1
      end
    end
  end

  for _, set in pairs(materialSettings.textureSets) do
    if set.d then set.tex = editor.texObj(set.d)
    elseif set.s then set.tex = editor.texObj(set.s)
    elseif set.n then set.tex = editor.texObj(set.n)
    end
  end
end

local function setupGroundmodels()
  local gMNames = tableKeys(core_environment.groundModels)
  table.sort(gMNames, sortFunc)
  materialSettings.groundModels = core_environment.groundModels
  materialSettings.groundModelNames = deepcopy(gMNames)
  materialSettings.groundModelNamesPtr = im.ArrayCharPtrByTbl(materialSettings.groundModelNames)
end

local function setupMaterials()
  setupTextures()
  setupGroundmodels()
end

local function colorToFloatArray(color)
  local res = {}
  local t = {}
  local i = 1
  for str in string.gmatch(color, "([^' ']+)") do
    t[i] = tonumber(str)
    i = i + 1
  end

  if #t == 4 then
    res = ffi.new("float[4]", {t[1], t[2], t[3], t[4]})
  elseif #res == 0 then
    --if debug then log('I', logTag, "Get stock color of " .. color) end
    local col = getStockColor(color)
    if col ~= nil then
      col[4] = 1.0
      res = ffi.new("float[4]", col)
    else
      log('E', logTag, "Cannot find stock color " .. color .. "! Fallback to white.")
      res = ffi.new("float[4]", {1.0, 1.0, 1.0, 1.0})
    end
  else
    log('E', logTag, "Wrong color value! Fallback to white.")
    res = ffi.new("float[4]", {1.0, 1.0, 1.0, 1.0})
  end

  return res
end

local function toBool(val)
  if type(val) == "string" then
    if val == "0" then return false elseif val == "1" then return true end
  elseif type(val) == "number" then
    if val == 0 then return false elseif val == 1 then return true end
  else
    log('E', logTag, "Type " .. type(val) .. " not supported by toBool() function!")
  end
end

local function getGroundModelKeyByValue(groundmodel)
  for k, gm in pairs(materialSettings.groundModelNames) do
    if gm == groundmodel then return k end
  end
  return 1
end

local function updateMaterialFields()
  materialSettings.base = editor.texObj(materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:getField('colorMap', 0))
  materialSettings.center = editor.texObj(materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:getField('colorMap', 1))
  materialSettings.border = editor.texObj(materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:getField('colorMap', 1))
  materialSettings.centerBaseColor = colorToFloatArray(materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:getField('diffuseColor', 0))
  materialSettings.borderBaseColor = colorToFloatArray(materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:getField('diffuseColor', 0))
  materialSettings.centerGlowColor = colorToFloatArray(materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:getField('diffuseColor', 1))
  materialSettings.borderGlowColor = colorToFloatArray(materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:getField('diffuseColor', 1))
  materialSettings.centerGlow = im.BoolPtr(toBool(materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:getField('glow', 1)))
  materialSettings.borderGlow = im.BoolPtr(toBool(materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:getField('glow', 1)))
  local groundModelKey = materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:getField('groundtype', 0)
  if groundModelKey ~= "" then materialSettings.groundModel[0] = getGroundModelKeyByValue(groundModelKey) - 1 else materialSettings.groundModel[0] = 0 end
end

local function textureTooltip(tex)
  if im.IsItemHovered() then
    if #tex.path > 0 then
      im.BeginTooltip()
      im.PushTextWrapPos(im.GetFontSize() * 35.0)
      im.TextUnformatted(tex.path)
      im.TextUnformatted(string.format("%d x %d", tex.size.x, tex.size.y))
      im.PopTextWrapPos()
      im.EndTooltip()
    end
  end
end

local function saveMaterial()
  scenetree.trackBuilder_PersistMan:setDirty(materialSettings.materials.center[materialSettings.selectedMaterial[0]+1], '')
  scenetree.trackBuilder_PersistMan:setDirty(materialSettings.materials.border[materialSettings.selectedMaterial[0]+1], '')
  scenetree.trackBuilder_PersistMan:saveDirty()
end

local function setTexture(map, texture)
  if map == 'base' then
    materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:setField('colorMap', 0, texture)
    materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:setField('colorMap', 0, texture)
  elseif map == 'center' then
    materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:setField('colorMap', 1, texture)
  elseif map == 'border' then
    materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:setField('colorMap', 1, texture)
  else
    log('E', 'editortrackbuilder', 'Wrong map type!')
  end
  materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:flush()
  materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:reload()
  materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:flush()
  materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:reload()
  updateMaterialFields()
end

local function setColor(mat, color)
  local value = string.format('%f %f %f %f', color[0], color[1], color[2], color[3])
  if mat == 'center_base' then
    materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:setField('diffuseColor', 0, value)
  elseif mat == 'border_base' then
    materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:setField('diffuseColor', 0, value)
  elseif mat == 'center_glow' then
    materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:setField('diffuseColor', 1, value)
  elseif mat == 'border_glow' then
    materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:setField('diffuseColor', 1, value)
  else
    log('E', 'editortrackbuilder', 'Wrong material type!')
  end
  materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:flush()
  materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:reload()
  materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:flush()
  materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:reload()
  updateMaterialFields()
end

local function setGlow(mat, active)
  local value
  if active == false then value = '0' elseif active == true then value = '1' end
  if mat == 'center' then
    materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:setField('glow', 1, value)
    materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:setField('emissive', 1, value)
  elseif mat == 'border' then
    materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:setField('glow', 1, value)
    materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:setField('emissive', 1, value)
  else
    log('E', 'editortrackbuilder', 'Wrong material type!')
  end
  materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:flush()
  materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:reload()
  materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:flush()
  materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:reload()
  updateMaterialFields()
end

local function setGroundmodel(groundmodel)
  materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:setField('groundType', 0, groundmodel)
  materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:setField('groundType', 0, groundmodel)
  materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:flush()
  materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:reload()
  materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:flush()
  materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:reload()
  materialSettings.groundModelHasChanged = true
end

local function onDragStarted()
  -- log(logTag, 'I', 'Drag started')
end

local function onDrag()
  if not materialSettings.dragging then
    onDragStarted()
    materialSettings.dragging = true
  end
end

local function onDragEnded()
  -- log(logTag, 'I', 'Drag ended!')
  materialSettings.dragDropData = nil
  materialSettings.dragDropImage = nil
  materialSettings.dragging = false
end

local function applyTextureSet(textureSet)
  if textureSet.d then
    materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:setField('colorMap', 0, textureSet.d)
    materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:setField('colorMap', 0, textureSet.d)
  elseif textureSet.s then
    materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:setField('specularMap', 0, textureSet.s)
    materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:setField('specularMap', 0, textureSet.s)
  elseif textureSet.n then
    materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:setField('normalMap', 0, textureSet.n)
    materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:setField('normalMap', 0, textureSet.n)
  end
  materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:flush()
  materialSettings.materials.center[materialSettings.selectedMaterial[0]+1]:reload()
  materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:flush()
  materialSettings.materials.border[materialSettings.selectedMaterial[0]+1]:reload()
  updateMaterialFields()
end

local function dragDropSource(texture)
  if im.BeginDragDropSource() then
    onDrag()
    if not materialSettings.dragDropData then materialSettings.dragDropData = ffi.new('char[64]', texture.path) end
    if not materialSettings.dragDropImage then materialSettings.dragDropImage = editor.texObj(texture.path) end
    im.SetDragDropPayload("TrackBuilderMaterialPayload", materialSettings.dragDropData, ffi.sizeof'char[64]', im.Cond_Once );
    im.Image(materialSettings.dragDropImage.texId, im.ImVec2(50, 50), im.ImVec2Zero, im.ImVec2One, im.ImColorByRGB(255,255,255,255).Value, im.ImColorByRGB(255,255,255,255).Value)
    im.EndDragDropSource()
  end
end

local function dragDropTarget(map)
  if im.BeginDragDropTarget() then
    local payload = im.AcceptDragDropPayload("TrackBuilderMaterialPayload")
    if payload~=nil then
      assert(payload.DataSize == ffi.sizeof"char[64]");
      local texture = ffi.string(ffi.cast("char*",payload.Data))
      setTexture(map, texture)
    end
    im.EndDragDropTarget();
  end
end

local function dragDropSourceTextureSet(name, set)
  if im.BeginDragDropSource() then
    onDrag()
    if not materialSettings.dragDropData then materialSettings.dragDropData = ffi.new('char[64]', name) end
    if not materialSettings.dragDropImage then materialSettings.dragDropImage = set.tex end
    im.SetDragDropPayload("TrackBuilderTextureSetPayload", materialSettings.dragDropData, ffi.sizeof'char[64]', im.Cond_Once );
    im.Image(materialSettings.dragDropImage.texId, im.ImVec2(50, 50), im.ImVec2Zero, im.ImVec2One, im.ImColorByRGB(255,255,255,255).Value, im.ImColorByRGB(255,255,255,255).Value)
    im.EndDragDropSource()
  end
end

local function dragDropTargetTextureSet()
  if im.BeginDragDropTarget() then
    local payload = im.AcceptDragDropPayload("TrackBuilderTextureSetPayload")
    if payload~=nil then
      assert(payload.DataSize == ffi.sizeof"char[64]");
      local textureSet = ffi.string(ffi.cast("char*",payload.Data))
      applyTextureSet(materialSettings.textureSets[textureSet])
    end
    im.EndDragDropTarget();
  end
end

local function dragDropSourceGlowMap(name, glowMap)
  if im.BeginDragDropSource() then
    onDrag()
    if not materialSettings.dragDropData then materialSettings.dragDropData = ffi.new('char[64]', name) end
    if not materialSettings.dragDropImage then materialSettings.dragDropImage = glowMap.tex end
    im.SetDragDropPayload("TrackBuilderGlowMapPayload", materialSettings.dragDropData, ffi.sizeof'char[64]', im.Cond_Once );
    im.Image(materialSettings.dragDropImage.texId, im.ImVec2(50, 50), im.ImVec2Zero, im.ImVec2One, im.ImColorByRGB(255,255,255,255).Value, im.ImColorByRGB(255,255,255,255).Value)
    im.EndDragDropSource()
  end
end

local function dragDropTargetGlowMap(map)
  if im.BeginDragDropTarget() then
    local payload = im.AcceptDragDropPayload("TrackBuilderGlowMapPayload")
    if payload~=nil then
      dump(payload.DataSize)
      assert(payload.DataSize == ffi.sizeof"char[64]");
      local glowMap = ffi.string(ffi.cast("char*",payload.Data))
      setTexture(map, materialSettings.glowMaps[glowMap].file)
    end
    im.EndDragDropTarget();
  end
end

local function materialEditor()
  if materialSettings.dragging and im.IsMouseReleased(0) then
    onDragEnded()
  end
  im.PushItemWidth(160)
  if im.Combo1("Material", materialSettings.selectedMaterial, materials.matNameArray) then
    log('I', logTag, 'Material has changed!')
    updateMaterialFields()
  end
  im.PopItemWidth()
  im.SameLine()
  if editor.uiIconImageButton(editor.icons.save, im.ImVec2(16,16), style.buttonColorBase, nil, nil, "saveButton") then saveMaterial() end
  im.SameLine()
  if editor.uiIconImageButton(editor.icons.undo, im.ImVec2(16,16), style.buttonColorBase, nil, nil, "resetMaterialButton") then
    local materialLetter = string.sub(materials.matNames[materialSettings.selectedMaterial[0]+1],14,14)
    tb.materialUtil.resetMaterialsToDefault(materialLetter)
    updateMaterialFields()
  end

  im.Columns(3, "Maps", false) --, 3, im.flags(im.ColumnsFlags_NoResize, im.ColumnsFlags_NoBorder))
  im.SetColumnWidth(0, 115)
  im.SetColumnWidth(1, 85)
  im.SetColumnWidth(2, 85)

  im.TextColored(style.textColor,translateLanguage("ui.trackBuilder.matEditor.texture", 'Texture'))
  im.TextColored(style.textColor,translateLanguage("ui.trackBuilder.matEditor.base", 'Base'))
  if im.ImageButton(materialSettings.base.texId, im.ImVec2(64,64), im.ImVec2Zero, im.ImVec2One, 0, im.ImColorByRGB(0,0,0,0).Value, im.ImColorByRGB(255,255,255,255).Value) then end
  dragDropTarget('base')
  dragDropTargetTextureSet()
  textureTooltip(materialSettings.base)
  if im.ColorEdit4("Center###centerBaseColor", materialSettings.centerBaseColor, im.flags(im.ColorEditFlags_AlphaPreviewHalf, im.ColorEditFlags_NoInputs, im.ColorEditFlags_AlphaBar)) then
    setColor('center_base', materialSettings.centerBaseColor)
  end
  if im.ColorEdit4("Border###borderBaseColor", materialSettings.borderBaseColor, im.flags(im.ColorEditFlags_AlphaPreviewHalf, im.ColorEditFlags_NoInputs, im.ColorEditFlags_AlphaBar)) then
    setColor('border_base', materialSettings.borderBaseColor)
  end
  im.NextColumn()

  im.TextColored(style.textColor,translateLanguage("ui.trackBuilder.matEditor.decal", "Decal"))
  im.TextColored(style.textColor,translateLanguage("ui.trackBuilder.matEditor.center", "Center"))
  if im.ImageButton(materialSettings.center.texId, im.ImVec2(64,64), im.ImVec2Zero, im.ImVec2One, 0, im.ImColorByRGB(255,0,0,0).Value, im.ImColorByRGB(255,255,255,255).Value) then end
  dragDropTarget('center')
  dragDropTargetGlowMap('center')
  textureTooltip(materialSettings.center)
  if im.Checkbox("Glow###center", materialSettings.centerGlow) then
    setGlow('center', materialSettings.centerGlow[0])
  end
  if im.ColorEdit4("Color###centerGlowColor", materialSettings.centerGlowColor, im.flags(im.ColorEditFlags_AlphaPreviewHalf, im.ColorEditFlags_NoInputs, im.ColorEditFlags_AlphaBar)) then
    setColor('center_glow', materialSettings.centerGlowColor)
  end
  im.NextColumn()

  im.TextColored(style.textColor,"")
  im.TextColored(style.textColor,translateLanguage("ui.trackBuilder.matEditor.border", "Border"))
  if im.ImageButton(materialSettings.border.texId, im.ImVec2(64,64), im.ImVec2Zero, im.ImVec2One, 0, im.ImColorByRGB(0,0,0,0).Value, im.ImColorByRGB(255,255,255,255).Value) then end
  dragDropTarget('border')
  dragDropTargetGlowMap('border')
  textureTooltip(materialSettings.border)
  if im.Checkbox("Glow###border", materialSettings.borderGlow) then
    setGlow('border', materialSettings.borderGlow[0])
  end
  if im.ColorEdit4("Color###borderGlowColor", materialSettings.borderGlowColor, im.flags(im.ColorEditFlags_AlphaPreviewHalf, im.ColorEditFlags_NoInputs, im.ColorEditFlags_AlphaBar)) then
    setColor('border_glow', materialSettings.borderGlowColor)
  end
  im.Columns(1)

  -- GroundModel
  im.PushItemWidth(180)
  if im.Combo1("Groundmodel", materialSettings.groundModel, materialSettings.groundModelNamesPtr) then
    setGroundmodel(materialSettings.groundModelNames[materialSettings.groundModel[0] + 1])
  end
  im.PopItemWidth()
  if materialSettings.groundModelHasChanged then im.TextColored(im.ImVec4(1.0, 0.0, 0.0, 1.0), "Groundmodel has been modified.\nHit DRIVE to apply changes to the track.") end

  if im.TreeNode1(translateLanguage("ui.trackBuilder.matEditor.paint", 'Paint')) then
    local changed = false
    if im.SmallButton(translateLanguage("ui.trackBuilder.matEditor.selectAll", "Select All")) then setAllPaintModes(true) changed = true end
    im.SameLine()
    if im.SmallButton(translateLanguage("ui.trackBuilder.matEditor.deselectAll", "Deselect All")) then setAllPaintModes(false) changed = true end

    if im.Checkbox(translateLanguage("ui.trackBuilder.matEditor.drawLeftBorder", "Draw Left Border"), materials.materialInfo.leftMesh.paint) then changed = true end
    if im.Checkbox(translateLanguage("ui.trackBuilder.matEditor.drawCenter", "Draw Center"), materials.materialInfo.centerMesh.paint) then changed = true end
    if im.Checkbox(translateLanguage("ui.trackBuilder.matEditor.drawRightBorder", "Draw Right Border"), materials.materialInfo.rightMesh.paint) then changed = true end

    if im.Checkbox(translateLanguage("ui.trackBuilder.matEditor.drawLeftWall", "Draw Left Wall"), materials.materialInfo.leftWall.paint) then changed = true end
    if im.Checkbox(translateLanguage("ui.trackBuilder.matEditor.drawCeiling", "Draw Ceiling"), materials.materialInfo.ceilingMesh.paint) then changed = true end
    if im.Checkbox(translateLanguage("ui.trackBuilder.matEditor.drawRightWall", "Draw Right Wall"), materials.materialInfo.rightWall.paint) then changed = true end
    if changed then
      local any = false
      any = any or materials.materialInfo.leftMesh.paint[0]
      any = any or materials.materialInfo.centerMesh.paint[0]
      any = any or materials.materialInfo.rightMesh.paint[0]
      any = any or materials.materialInfo.leftWall.paint[0]
      any = any or materials.materialInfo.ceilingMesh.paint[0]
      any = any or materials.materialInfo.rightWall.paint[0]
      if any then
        selectMode("Paint")
      else
        selectMode("Select")
      end
    end

    im.TreePop()
  end

  if im.TreeNode1(translateLanguage("ui.trackBuilder.matEditor.baseTextures", "Base Textures")) then
    im.BeginChild1("baseTextureChild", im.ImVec2(-1,160))
    local i = 1
    for name, set in pairs(materialSettings.textureSets) do
      if im.ImageButton(set.tex.texId, im.ImVec2(64,64), im.ImVec2Zero, im.ImVec2One, 1, im.ImColorByRGB(0,0,0,255).Value, im.ImColorByRGB(255,255,255,255).Value) then print("Image") end
      dragDropSourceTextureSet(name, set)
      im.tooltip(name)
      if i % 3 ~= 0 and i ~= materialSettings.texteSetsSize then im.SameLine() end
      i = i + 1
    end
    im.EndChild()
    im.TreePop()
  end

  if im.TreeNode1(translateLanguage("ui.trackBuilder.matEditor.decalTextures", "Decal Textures")) then
    im.BeginChild1("decalTextureChild",im.ImVec2(-1,160))
    local i = 1
    for name, glowMap in pairs(materialSettings.glowMaps) do
      if im.ImageButton(glowMap.tex.texId, im.ImVec2(64,64), im.ImVec2Zero, im.ImVec2One, 1, im.ImColorByRGB(0,0,0,255).Value, im.ImColorByRGB(255,255,255,255).Value) then print("Image") end
      dragDropSourceGlowMap(name, glowMap)
      im.tooltip(name)
      if i % 3 ~= 0 and i ~= materialSettings.glowMapsSize then im.SameLine() end
      i = i + 1
    end
    im.EndChild()
    im.TreePop()
  end
end

local function onMaterialEditorOpened()
  selectMode("Paint")
end

local function onMaterialEditorClosed()
  if paintModes.Paint.active[0] then
    selectMode("Select")
  end
end

-- Borders and Center

-- creates a checkbox and selector for one border
local function borderDrawSelector(displayName, name, table, nameTable, width)
  im.TextColored(style.textColor, displayName)
  if im.Checkbox("Draw##"..name,clickInputModes[name]) then
    local anySelected = false
    anySelected = anySelected or clickInputModes['rightMesh'][0] or clickInputModes['leftMesh'][0]
    if anySelected then
      selectMode("ChangeMesh")
    else
      selectMode("Select")
    end
  end
  im.SameLine()
  if width then im.PushItemWidth(width) end
  im.Combo1("Shape##"..name, modifierValues[name].value, table)
  if width then im.PopItemWidth() end
end

-- creates the borders (and centers) window
local function bordersAndCenters()
  borderDrawSelector(translateLanguage("ui.trackBuilder.borders.leftBorderShape", 'Left Border Shape'),'leftMesh',borders, bordersTbl, 130)
  im.Separator()
  borderDrawSelector(translateLanguage("ui.trackBuilder.borders.rightBorderShape", 'Right Border Shape'),'rightMesh',borders, bordersTbl, 130)
  im.Separator()
  borderDrawSelector("center", 'centerMesh',centers, centersTbl, 130)
end

local function onBordersAndCentersOpened()
  selectMode("ChangeMesh")
end

local function onBordersAndCentersClosed()
  if paintModes.ChangeMesh.active[0] then
    selectMode("Select")
  end
end

-- Walls and Ceiling

-- creates the walls and ceiling window
local function wallsAndCeiling()
  im.PushItemWidth(120)
  im.TextColored(style.textColor, translateLanguage("ui.trackBuilder.wallsCeiling.leftWall", "Left Wall"))
  if im.Checkbox(translateLanguage("ui.trackBuilder.wallsCeiling.active", "Active") .. "##leftWall", modifierValues.leftWall.active) then
      tbFunctions.modifierChange("leftWall")
  end
  local x = im.GetCursorPosX()
  if im.DragFloat(translateLanguage("ui.trackBuilder.wallsCeiling.height", "Height") .. "##left", modifierValues.leftWall.value,0.1) then
    if modifierValues.leftWall.value[0] > 50 then
      modifierValues.leftWall.value[0] = 50
    elseif modifierValues.leftWall.value[0] < 0 then
      modifierValues.leftWall.value[0] = 0
    end
   tbFunctions.modifierChange('leftWall')
  end
  im.SameLine()
  im.SetCursorPosX(x + 191)
  modifierButtons('leftWall',0,true)

  im.Separator()
  im.TextColored(style.textColor, translateLanguage("ui.trackBuilder.wallsCeiling.rightWall", "Right Wall"))
  if im.Checkbox(translateLanguage("ui.trackBuilder.wallsCeiling.active", "Active") .. "##rightWall", modifierValues.rightWall.active) then
    tbFunctions.modifierChange("rightWall")
  end

  x = im.GetCursorPosX()
  if im.DragFloat(translateLanguage("ui.trackBuilder.wallsCeiling.height", "Height") .. "##right", modifierValues.rightWall.value,0.1) then
    if modifierValues.rightWall.value[0] > 50 then
      modifierValues.rightWall.value[0] = 50
    elseif modifierValues.rightWall.value[0] < 0 then
      modifierValues.rightWall.value[0] = 0
    end
      tbFunctions.modifierChange('rightWall')
  end
  im.SameLine()
  im.SetCursorPosX(x + 191)
  modifierButtons('rightWall',0,true)

  im.Separator()
  im.TextColored(style.textColor, translateLanguage("ui.trackBuilder.wallsCeiling.ceiling", "Ceiling"))
  if im.Checkbox(translateLanguage("ui.trackBuilder.wallsCeiling.active", "Active") .. "##ceilingMesh", modifierValues.ceilingMesh.active) then
    tbFunctions.modifierChange("ceilingMesh")
  end

  x = im.GetCursorPosX()
  if im.DragFloat(translateLanguage("ui.trackBuilder.wallsCeiling.height", "Height") .. "##ceil", modifierValues.ceilingMesh.value,0.1) then
    if modifierValues.ceilingMesh.value[0] > 50 then
      modifierValues.ceilingMesh.value[0] = 50
    elseif modifierValues.ceilingMesh.value[0] < 0 then
      modifierValues.ceilingMesh.value[0] = 0
    end
    tbFunctions.modifierChange('ceilingMesh')
  end
  im.SameLine()
  im.SetCursorPosX(x + 191)
  modifierButtons('ceilingMesh',0,true)

  im.PopItemWidth()
end

-- advancedModifiers

-- creates a list of buttons to set a modifier to their value, or change them relatively to their value
local function smallSetButtons(name, values, size, relative, displayNames)
  local pos = partitionWidth(im.GetWindowWidth(), size.x, #values)
  local old
  for i, v  in ipairs(values) do
    im.SetCursorPosX(pos[i])
    if im.Button((displayNames and displayNames[i] or v)..'##'..name, size) then
      old = relative and modifierValues[name].value[0] or 0
      modifierValues[name].value[0] = v + old
      tbFunctions.modifierChange(name)
    end
    im.SameLine()
  end
end

-- creates a modifier change button with different steps when you hold ctrl or shift
local function CtrlShiftButton(currentValue, normalStep, littleStep, bigStep, min, max, sign)
  local shift = im.GetIO().KeyShift
  local ctrl  = im.GetIO().KeyCtrl
  local ret = currentValue
  if ctrl then
    ret = currentValue + littleStep * sign
  elseif shift then
    ret = currentValue + bigStep * sign
  else
    local m = math.floor(currentValue / normalStep)
    ret = m * normalStep + normalStep * sign
  end
  return clamp(ret,min,max)
end

-- creates the advance modifiers window
local function advancedModifiers()
  navigationRow()
  im.Separator()

  im.TextColored(style.textColor,string.format(translateLanguage("ui.trackBuilder.base.banking", "Banking") .. ": %.1f°", modifierValues.bank.value[0]))

  smallSetButtons("bank",{-75,-45,-15,15,45,75},im.ImVec2(40,0))
  im.NewLine()
  smallSetButtons("bank2",{-90,-60,-30,30,60,90},im.ImVec2(40,0))
  im.NewLine()

  im.SetCursorPosX(62)

  if im.Button("<##bank",style.slimButtonSize) then tbFunctions.modifierShift('bank',-1) end
  im.tooltip('Shift Modifier Back')
  im.SameLine()
  if editor.uiIconImageButton(editor.icons.tb_bank_left or editor.icons.stop,style.buttonSize,style.buttonColorBase) then modifierValues.bank.value[0] = CtrlShiftButton(modifierValues.bank.value[0],15,1,60,-720,720,-1) tbFunctions.modifierChange('bank') end
  im.SameLine()
  if editor.uiIconImageButton(editor.icons.tb_bank_right or editor.icons.stop,style.buttonSize,style.buttonColorBase) then modifierValues.bank.value[0] = CtrlShiftButton(modifierValues.bank.value[0],15,1,60,-720,720,1) tbFunctions.modifierChange('bank') end
  im.SameLine()
  if im.Button(">##bank",style.slimButtonSize) then tbFunctions.modifierShift('bank',1) end
  im.tooltip('Shift Modifier Forward')

  im.PushItemWidth(130)
  local x = im.GetCursorPosX()
  if im.DragInt("Bank", modifierValues.bank.value) then
    tbFunctions.modifierChange('bank')
  end
  im.SameLine()
  im.SetCursorPosX(x + 191)
  modifierButtons('bank',0,true)

  im.Separator()

  im.TextColored(style.textColor,string.format(translateLanguage("ui.trackBuilder.base.height", "Height") .. ": %.1fm", modifierValues.height.value[0]))

  smallSetButtons("height",{-25,-10,-5,5,10,25},im.ImVec2(35,0), true, {'-25','-10','-5','+5','+10','+25'})
  im.NewLine()
  im.SetCursorPosX(62)

  if im.Button("<##height",style.slimButtonSize) then tbFunctions.modifierShift('height',-1) end
  im.tooltip('Shift Modifier Back')
  im.SameLine()
  if editor.uiIconImageButton(editor.icons.tb_height_lower or editor.icons.stop,style.buttonSize,style.buttonColorBase) then modifierValues.height.value[0] = CtrlShiftButton(modifierValues.height.value[0],1,5,25,-500,2000,-1) tbFunctions.modifierChange('height') end
  im.SameLine()
  if editor.uiIconImageButton(editor.icons.tb_height_higher or editor.icons.stop,style.buttonSize,style.buttonColorBase)   then modifierValues.height.value[0] = CtrlShiftButton(modifierValues.height.value[0],1,5,25,-500,2000,1) tbFunctions.modifierChange('height') end
  im.SameLine()
  if im.Button(">##height",style.slimButtonSize) then tbFunctions.modifierShift('height',1) end
  im.tooltip('Shift Modifier Forward')

  x = im.GetCursorPosX()
  if im.DragFloat("Height", modifierValues.height.value,0.1, nil, nil, "%.1f") then
     tbFunctions.modifierChange('height')
  end
  im.SameLine()
  im.SetCursorPosX(x + 191)
  modifierButtons('height',0)

  -- add own interpolations input, so we can react to changes
  if im.Combo1("##"..'height', modifierValues['height'].interpolation, interpolations) then
    modifierValues.height.customSlope[0] = modifierValues['height'].interpolation[0] > 1
    tbFunctions.modifierChange('height')
  end

  im.SameLine()
  if im.Checkbox(translateLanguage("ui.trackBuilder.modifier.inverted", "Inverted") .. "##"..'height', modifierValues['height'].inverted) then
    tbFunctions.modifierChange('height')
  end

  if modifierValues.height.customSlope[0] then
    if im.DragInt("Slope Angle", modifierValues.height.customSlopeValue) then
      tbFunctions.modifierChange("height")
    end
  end

  im.Separator()

  im.TextColored(style.textColor,translateLanguage("ui.trackBuilder.base.width", "Width") .. ": " .. modifierValues.width.value[0]..'m')
  smallSetButtons("width",{0,1,2,5,10,15,20},im.ImVec2(30,0))
  im.NewLine()

  im.SetCursorPosX(62)
  if im.Button("<##width",style.slimButtonSize) then tbFunctions.modifierShift('width',-1) end
  im.tooltip('Shift Modifier Back')
  im.SameLine()
  if editor.uiIconImageButton(editor.icons.tb_width_slimmer or editor.icons.stop,style.buttonSize,style.buttonColorBase) then modifierValues.width.value[0] = CtrlShiftButton(modifierValues.width.value[0],1,5,10,0,50,-1) tbFunctions.modifierChange('width') end
  im.SameLine()
  if editor.uiIconImageButton(editor.icons.tb_width_wider or editor.icons.stop,style.buttonSize,style.buttonColorBase) then  modifierValues.width.value[0] = CtrlShiftButton(modifierValues.width.value[0],1,5,10,0,50,1) tbFunctions.modifierChange('width') end
  im.SameLine()
  if im.Button(">##width",style.slimButtonSize) then tbFunctions.modifierShift('width',1) end
  im.tooltip('Shift Modifier Forward')

  x = im.GetCursorPosX()

  if im.SliderInt("Width", modifierValues.width.value, 0, 50) then
    if modifierValues.width.value[0] > 50 then modifierValues.width.value[0] = 50 elseif modifierValues.width.value[0] < 0 then modifierValues.width.value[0] = 0 end
     tbFunctions.modifierChange('width')
  end
  im.SameLine()
  im.SetCursorPosX(x + 191)
  modifierButtons('width',10,true)

  im.PopItemWidth()
end

-- general settings

-- creates the time, fog and azimuth settings.
local function timeSettings()
  local tod = core_environment.getTimeOfDay()
  core_environment.setTimeOfDay(tod)
  saveSettings.timeOfDay[0] = tod.time
  local fog = core_environment.getFogDensity()
  core_environment.setFogDensity(fog)
  saveSettings.fogValue[0] = fog
  im.TextColored(style.textColor,translateLanguage("ui.trackBuilder.trackSettings.environmentSettings", "Environment settings"))

  im.TextColored(style.textColor,translateLanguage("ui.trackBuilder.trackSettings.time", 'Time'))
  if im.SliderFloat(translateLanguage("ui.trackBuilder.trackSettings.time", "Time"),saveSettings.timeOfDay , 00, 1, "%.2f") then
    tod.time = saveSettings.timeOfDay[0]
    core_environment.setTimeOfDay(tod)
  end

  if editor.uiIconImageButton(editor.icons.wb_sunny, im.ImVec2(30,30),style.buttonColorBase) then
    saveSettings.timeOfDay[0]= 0.2
    tod.time = saveSettings.timeOfDay[0]
    core_environment.setTimeOfDay(tod)
  end
  im.tooltip(translateLanguage("ui.trackBuilder.tooltip.morning", "Morning"))

  im.SameLine()
  if editor.uiIconImageButton(editor.icons.access_time or editor.icons.stop,im.ImVec2(30,30),style.buttonColorBase) then
    saveSettings.timeOfDay[0] = 0.1
    tod.time = saveSettings.timeOfDay[0]
    core_environment.setTimeOfDay(tod)
  end
  im.tooltip(translateLanguage("ui.trackBuilder.tooltip.noon", "Noon"))

  im.SameLine()
  if editor.uiIconImageButton(editor.icons.brightness_3,im.ImVec2(30,30),style.buttonColorBase) then
    saveSettings.timeOfDay[0]= 0.5
    tod.time = saveSettings.timeOfDay[0]
    core_environment.setTimeOfDay(tod)
  end
  im.tooltip(translateLanguage("ui.trackBuilder.tooltip.night", "Night"))
  im.TextColored(style.textColor,translateLanguage("ui.trackBuilder.trackSettings.azimuth", 'Azimuth'))
  if im.SliderFloat(translateLanguage("ui.trackBuilder.trackSettings.azimuth", 'Azimuth'),saveSettings.azimuthValue,0,2*math.pi,"%.2f") then
    if saveSettings.azimuthValue[0] ~=0  then
      -- local sky = scenetree.findObject("sunsky")
    --  local azi= sky:getAzimuth()
      tod.azimuthOverride = saveSettings.azimuthValue[0]
      core_environment.setTimeOfDay(tod)
    end
  end

  im.TextColored(style.textColor,translateLanguage("ui.trackBuilder.trackSettings.fog", 'Fog'))
  if im.SliderFloat(translateLanguage("ui.trackBuilder.trackSettings.fog", 'Fog'),saveSettings.fogValue, 0, 0.5, "%.8f",6) then
    core_environment.setFogDensity(saveSettings.fogValue[0])
  end

end

-- creates the race settings (lapCount and reversible)
local function raceSettings()
  im.TextColored(style.textColor,translateLanguage("ui.trackBuilder.trackSettings.raceSettings", 'Race Settings'))
  if im.Checkbox(translateLanguage("ui.trackBuilder.trackSettings.reversible", "Reversible"),saveSettings.allowReverse) then
    tb.setReversible(saveSettings.allowReverse[0])
  end
  if im.InputInt(translateLanguage("ui.trackBuilder.trackSettings.defaultLaps", "Default Laps"),saveSettings.lapCount) then
    if saveSettings.lapCount[0] < 1 then saveSettings.lapCount[0] = 1 end
    tb.setDefaultLaps(saveSettings.lapCount[0])
  end
end

-- creates the track position settings, including the buttons to position the track.
local function trackPositionSettings()
  im.TextColored(style.textColor, translateLanguage("ui.trackBuilder.trackSettings.trackTransform", "Track Transform"))

  if im.DragFloat3(translateLanguage("ui.trackBuilder.trackSettings.position", "Position"),trackPositionValues.position,0.1) then
    tb.setTrackPosition(trackPositionValues.position[0],trackPositionValues.position[1],trackPositionValues.position[2],trackPositionValues.rotation[0])
    tb.makeTrack()
    tb.focusMarkerOn(currentIndex)
  end
  if im.DragFloat(translateLanguage("ui.trackBuilder.trackSettings.rotation", "Rotation"),trackPositionValues.rotation) then
    tb.setTrackPosition(trackPositionValues.position[0],trackPositionValues.position[1],trackPositionValues.position[2],trackPositionValues.rotation[0])
    tb.makeTrack()
    tb.focusMarkerOn(currentIndex)
  end
  im.Separator()
  local size = im.ImVec2(im.GetWindowWidth()-2,24)
  if im.Button(translateLanguage("ui.trackBuilder.trackSettings.alignTrackToCam", "Align Track to Camera"),size) then
    tb.rotateTrackToCamera()
    tb.makeTrack()
    tbFunctions.refreshTrackPositionRotation()
    --tb.focusMarkerOn(currentIndex)
  end
  if im.Button(translateLanguage("ui.trackBuilder.trackSettings.positionTrackBeforeCam", "Position Track before Camera"),size) then
    tb.positionTrackBeforeCamera()
    tb.makeTrack()
    --tb.focusMarkerOn(currentIndex)
    tbFunctions.refreshTrackPositionRotation()
  end
  im.Separator()
  if im.Button(translateLanguage("ui.trackBuilder.trackSettings.alignTrackToVehicle", "Align Track to Vehicle"),size) then
    tb.rotateTrackToTrackVehicle()
    tb.makeTrack()
    --tb.focusMarkerOn(currentIndex)
    tbFunctions.refreshTrackPositionRotation()
  end
  if im.Button(translateLanguage("ui.trackBuilder.trackSettings.positionTrackAboveVehicle", "Position Track above Vehicle"),size) then
    tb.positionTrackAboveVehicle()
    tb.makeTrack()
    --tb.focusMarkerOn(currentIndex)
    tbFunctions.refreshTrackPositionRotation()
  end
end

-- creates the settings window
local function generalSettings()
  if not isOnGlowCity then
    timeSettings()
    im.Separator()
  end

  raceSettings()
  im.Separator()

  trackPositionSettings()
end

-- save and load

-- creates the file name input, the save, preview and packToMod buttons.
local function saveInputButtons()
  im.TextColored(style.textColor, translateLanguage("ui.trackBuilder.saveLoad.saveTrack", "Save Track"))
  im.InputText(translateLanguage("ui.trackBuilder.saveLoad.filename", "Filename"),saveSettings.saveStr)

  local text = translateLanguage("ui.trackBuilder.saveLoad.save", "Save Track")
  local previewText = translateLanguage("ui.trackBuilder.saveLoad.createPreview", "Create Preview")
  local name = ffi.string(saveSettings.saveStr)
  local allowScreenshot = false
  local allowPacking = false
  -- check wether track exists, or we can save preview/pack to mod
  for _,file in ipairs(saveSettings.trackNames) do
    if file == name then
      text = translateLanguage("ui.trackBuilder.saveLoad.overwrite", "Overwrite Track")
      allowScreenshot = true
      for _,preview in ipairs(saveSettings.previewNames) do
        if preview == name then
          previewText = translateLanguage("ui.trackBuilder.saveLoad.overwritePreview", "Overwrite Preview")
          allowPacking = true
        end
      end
    end
  end

  -- actual save button
  if im.Button(text, im.ImVec2(128,20)) then
    local exp, filename = tb.save(
      ffi.string(saveSettings.saveStr),
      {
        saveForThisMap  = saveSettings.saveOnMap[0],
        saveEnvironment = saveSettings.saveEnvironment[0],
        description     = string.gsub(ffi.string(saveSettings.description),"\n", "\\n"),
        difficulty      = 12 + 25*saveSettings.difficulty[0]
      })
    ffi.copy(saveSettings.saveStr, filename)
    saveSettings.trackNames = tb.getCustomTracks()
    saveSettings.previewNames = tb.getPreviewNames()
    saveSettings.infoText = translateLanguage("ui.trackBuilder.saveLoad.trackWrittenTo", "Successfully saved track to ") .."'/trackEditor/"..ffi.string(saveSettings.saveStr)..".json'!"
  end
  -- screenshot button, if track is saved
  if allowScreenshot then
    im.SameLine()
    if im.Button(previewText, im.ImVec2(128,20)) then
      hiddenForScreenshotTimer = 1
      tb.showMarkers(false)
      tb.unselectAll()
      tb.makeTrack()
      screenshotTaken = false
      saveSettings.infoText = translateLanguage("ui.trackBuilder.saveLoad.previewCreated", "Successfully created preview ") .."'/trackEditor/".. ffi.string(saveSettings.saveStr)..".jpg'!"
    end
  end
  -- pack to mod button, if has preview
  if allowPacking then
    if im.Button(translateLanguage("ui.trackBuilder.saveLoad.packToMod", "Pack to Mod"), im.ImVec2(264,20)) then
      local modName = "mods/TrackBuilder_" .. ffi.string(saveSettings.saveStr)..".zip"
      local zip = ZipArchive()
      zip:openArchiveName(modName, 'w')

      -- addFile( path [, pathInZIP, overrideFile] )
      zip:addFile( 'trackEditor/'..ffi.string(saveSettings.saveStr)..'.json' )
      zip:addFile( 'trackEditor/'..ffi.string(saveSettings.saveStr)..'.jpg' )
      zip:close()
      saveSettings.infoText = translateLanguage("ui.trackBuilder.saveLoad.modSaved", "Successfully packed track and preview to mod file  ") .."'/"..modName.."'!"
    end
  end
end

-- creates the description, saveOnMap and saveTimeSettings inputs.
local function additionalSaveSettings()
  im.TextColored(style.textColor, translateLanguage("ui.trackBuilder.saveLoad.description", "Description"))
  im.InputTextMultiline("##description", saveSettings.description, im.GetLengthArrayCharPtr(saveSettings.description), im.ImVec2(-1.0, im.GetTextLineHeight() * 3))
  im.Combo1(translateLanguage("ui.trackBuilder.saveLoad.difficulty", 'Difficulty'), saveSettings.difficulty, difficulty)

  if not isOnGlowCity then
    im.Checkbox(translateLanguage("ui.trackBuilder.saveLoad.saveTimeSettings", 'Save time settings'),saveSettings.saveEnvironment)
  end

  im.Checkbox(translateLanguage("ui.trackBuilder.saveLoad.saveOnThisMap", "Save on this map"),saveSettings.saveOnMap)
end

-- creates the track loading list and handles loading.
local function loadTrackList()
  im.TextColored(style.textColor, translateLanguage("ui.trackBuilder.saveLoad.loadTrack", "Load Track"))
  if im.Button('X ') then im.ImGuiTextFilter_Clear(loadFilesFilter) end
  im.SameLine()
  im.ImGuiTextFilter_Draw(loadFilesFilter, translateLanguage("ui.trackBuilder.saveLoad.search", "Search"), 120)
  im.BeginChild1("LoadBox")
  for _,file in ipairs(saveSettings.trackNames) do
    if im.ImGuiTextFilter_PassFilter(loadFilesFilter, file) then
      if im.Button(file) then
        tb.load(file,false,false,false)
        local json = tb.loadJSON(file)
        if json then
          ffi.copy(saveSettings.description, string.gsub(json.description or "", "\\n", "\n"))
          saveSettings.saveOnMap[0] = json.level == getCurrentLevelIdentifier()--core_levels.getLevelName(getMissionFilename())
          saveSettings.saveEnvironment[0] = json.environment ~= nil
          saveSettings.difficulty[0] = (json.difficulty or 35)/25

        end
        tbFunctions.switchSubTrack(1)
        currentIndex = 2
        tb.focusMarkerOn(2)

        local tp = tb.getTrackPosition()
        tbFunctions.refreshTrackPositionRotation()
        ffi.copy(saveSettings.saveStr, file)
        saveSettings.infoText = translateLanguage("ui.trackBuilder.saveLoad.trackLoaded", "Loaded track ") .."'"..ffi.string(saveSettings.saveStr).."'!"
      end
    end
  end
  im.EndChild()
end

-- creates the save and load window.
local function saveAndLoad()
  if saveSettings.infoText ~= "" then
    im.TextWrapped(saveSettings.infoText)
    im.Separator()
  end
  if saveSettings.trackNames == nil then
    saveSettings.trackNames = tb.getCustomTracks()
    saveSettings.previewNames = tb.getPreviewNames()
    loadFilesFilter = im.ImGuiTextFilter()
  end

  saveInputButtons()
  additionalSaveSettings()
  loadTrackList()
end

-- obstacles

local function addObstacles()
  local activeCount = 0
  local copy = nil
  local variants = 0
  local dimensions = 1
  local name
  for i, o in ipairs(modifierValues.obstacles.list) do
    if o.active then
      activeCount = activeCount +1
      im.BeginChild1("ObstacleChild", im.ImVec2(0,430), true)
      if im.TreeNodeEx1('Obstacle '..activeCount,im.TreeNodeFlags_DefaultOpen) then
        name = obstaclesTbl[o.value[0]+1]
        variants = obstacleInfo[name].variants or 0
        im.PushItemWidth(125)
        if im.Combo1("Type##o"..i, o.value, obstacles) then
          variants = obstacleInfo[obstaclesTbl[o.value[0]+1]].variants or 0
          name = obstaclesTbl[o.value[0]+1]
          o.variant[0] = 1
          o.scale[0] = obstacleInfo[name].scale[1] or 1
          o.scale[1] = obstacleInfo[name].scale[2] or 1
          o.scale[2] = obstacleInfo[name].scale[3] or 1
          o.extra[0] = obstacleInfo[name].scale[4] or 1
          o.extra[1] = obstacleInfo[name].scale[5] or 1
          o.extra[2] = obstacleInfo[name].scale[6] or 1
          tbFunctions.modifierChange('obstacles')
        end
        if variants > 0 then
          if im.InputInt("Variant##o"..i,o.variant) then
            if o.variant[0] < 1 then
              o.variant[0] = variants
            elseif o.variant[0] > variants then
              o.variant[0] = 1
            end
            tbFunctions.modifierChange('obstacles')
          end
        end
        if im.Combo1("Anchor##o"..i,o.anchor,anchors) then
          tbFunctions.modifierChange('obstacles')
        end
        if im.SliderFloat("Offset##o"..i,o.offset,0,1) then
          tbFunctions.modifierChange('obstacles')
        end

        if im.DragFloat3("Position##o"..i,o.position,0.05, nil, nil, "%.2f") then tbFunctions.modifierChange('obstacles') end
        im.SameLine()
       -- if im.SmallButton("r##op"..i) then
        if editor.uiIconImageButton(editor.icons.undo, im.ImVec2(20,20), style.colorGreen) then
          o.position[0] = 0
          o.position[1] = 0
          o.position[2] = 0
          tbFunctions.modifierChange('obstacles')
        end
        im.tooltip(translateLanguage("ui.trackBuilder.tooltip.reset", "Reset"))
        dimensions = obstacleInfo[name].dimensions or 3
        if dimensions == 1 then
          if im.DragFloat("Scale   ##o"..i,o.scale,0.01, nil, nil, "%.2f") then tbFunctions.modifierChange('obstacles') end
        elseif dimensions == 2 then
          if im.DragFloat2("Scale   ##o"..i,o.scale,0.01, nil, nil, "%.2f") then tbFunctions.modifierChange('obstacles') end
        elseif dimensions == 3 then
          if im.DragFloat3("Scale   ##o"..i,o.scale,0.01, nil, nil, "%.2f") then tbFunctions.modifierChange('obstacles') end
        elseif dimensions == 4 then
          if im.DragFloat3("   ##o"..i,o.scale,0.01, nil, nil, "%.2f") then tbFunctions.modifierChange('obstacles') end
          if im.DragFloat("Scale   ##xo"..i,o.extra,0.01, nil, nil, "%.2f") then tbFunctions.modifierChange('obstacles') end
        elseif dimensions == 5 then
          if im.DragFloat3("   ##o"..i,o.scale,0.01, nil, nil, "%.2f") then tbFunctions.modifierChange('obstacles') end
          if im.DragFloat2("Scale   ##xo"..i,o.extra,0.01, nil, nil, "%.2f") then tbFunctions.modifierChange('obstacles') end
        elseif dimensions == 6 then
          if im.DragFloat3("   ##o"..i,o.scale,0.01, nil, nil, "%.2f") then tbFunctions.modifierChange('obstacles') end
          if im.DragFloat3("Scale   ##xo"..i,o.extra,0.01, nil, nil, "%.2f") then tbFunctions.modifierChange('obstacles') end
        end
        im.SameLine()
      --  if im.SmallButton("r##os"..i) then

        if editor.uiIconImageButton(editor.icons.undo, im.ImVec2(20,20), style.colorGreen) then
          o.scale[0] = obstacleInfo[name].scale[1] or 1
          o.scale[1] = obstacleInfo[name].scale[2] or 1
          o.scale[2] = obstacleInfo[name].scale[3] or 1
          o.extra[0] = obstacleInfo[name].scale[4] or 1
          o.extra[1] = obstacleInfo[name].scale[5] or 1
          o.extra[2] = obstacleInfo[name].scale[6] or 1
          tbFunctions.modifierChange('obstacles')
        end
        im.tooltip(translateLanguage("ui.trackBuilder.tooltip.reset", "Reset"))


        if im.DragFloat3("Rotation ##o"..i,o.rotation, 1, nil, nil, "%.2f") then tbFunctions.modifierChange('obstacles') end
        im.SameLine()
       -- if im.SmallButton("r##or"..i) then
        if editor.uiIconImageButton(editor.icons.undo, im.ImVec2(20,20), style.colorGreen) then
          o.rotation[0] = 0
          o.rotation[1] = 0
          o.rotation[2] = 0
          tbFunctions.modifierChange('obstacles')
        end
        im.tooltip(translateLanguage("ui.trackBuilder.tooltip.reset", "Reset"))

        if im.Combo1("Material ##o"..i, o.material, obstacleMatDisplayNames) then
          tbFunctions.modifierChange('obstacles')
        end

        if im.Button(translateLanguage("ui.trackBuilder.obstacles.remove", "Remove") .. "##o"..i) then
          o.active = false
          tbFunctions.modifierChange('obstacles')
          tbFunctions.refreshPieceInfo()
        end
        im.SameLine()
        if im.Button(translateLanguage("ui.trackBuilder.obstacles.copy", "Copy") .. "##o"..i) then
          copy = o
        end
        im.Separator()
        im.PopItemWidth()
        im.TreePop()
      end
      im.EndChild()
    end
  end

  if activeCount < 10 then
    if copy then
      modifierValues.obstacles.list[activeCount+1].active = true

      modifierValues.obstacles.list[activeCount+1].value[0] = copy.value[0]
      modifierValues.obstacles.list[activeCount+1].variant[0] = copy.variant[0]
      modifierValues.obstacles.list[activeCount+1].offset[0] = copy.offset[0]
      modifierValues.obstacles.list[activeCount+1].anchor[0] = copy.anchor[0]

      modifierValues.obstacles.list[activeCount+1].position[0] = copy.position[0]
      modifierValues.obstacles.list[activeCount+1].position[1] = copy.position[1]
      modifierValues.obstacles.list[activeCount+1].position[2] = copy.position[2]
      modifierValues.obstacles.list[activeCount+1].rotation[0] = copy.rotation[0]
      modifierValues.obstacles.list[activeCount+1].rotation[1] = copy.rotation[1]
      modifierValues.obstacles.list[activeCount+1].rotation[2] = copy.rotation[2]
      modifierValues.obstacles.list[activeCount+1].scale[0] = copy.scale[0]
      modifierValues.obstacles.list[activeCount+1].scale[1] = copy.scale[1]
      modifierValues.obstacles.list[activeCount+1].scale[2] = copy.scale[2]
      modifierValues.obstacles.list[activeCount+1].extra[0] = copy.extra[0]
      modifierValues.obstacles.list[activeCount+1].extra[1] = copy.extra[1]
      modifierValues.obstacles.list[activeCount+1].extra[2] = copy.extra[2]

      modifierValues.obstacles.list[activeCount+1].material[0] = copy.material[0]

      tbFunctions.modifierChange('obstacles')
      tbFunctions.refreshPieceInfo()
    elseif editor.uiIconImageButton(editor.icons.add_box or editor.icons.stop, im.ImVec2(35,35), style.buttonColorBase) then
      modifierValues.obstacles.list[activeCount+1].active = true
      tbFunctions.modifierChange('obstacles')
    end
    im.tooltip(translateLanguage("ui.trackBuilder.tooltip.addObstacle", "Add obstacle"))
  end
end

-- checkpoints
-- creates the input for a single checkpoint.
local function checkPointInput()
  if im.DragFloat("Size##cp",modifierValues.checkpoint.size, 0.25) then
    if modifierValues.checkpoint.size[0] > 50 then
      modifierValues.checkpoint.size[0] = 50
    elseif modifierValues.checkpoint.size[0] < 1 then
      modifierValues.checkpoint.size[0] = 1
    end
    tbFunctions.modifierChange('checkpoint')
  end
  im.SameLine()
  im.SetCursorPosX(im.GetWindowWidth()-25)
  if editor.uiIconImageButton(editor.icons.undo, size or im.ImVec2(20,20), style.colorGreen) then
    local currentPiece = tb.getSelectedTrackInfo()
    modifierValues.checkpoint.size[0] = currentPiece.markerInfo.width
    tbFunctions.modifierChange('checkpoint')
  end
  if im.DragFloat3("Position##cp", modifierValues.checkpoint.position, 0.05) then
     tbFunctions.modifierChange('checkpoint')
  end
  im.SameLine()
  im.SetCursorPosX(im.GetWindowWidth()-25)
  if editor.uiIconImageButton(editor.icons.undo, size or im.ImVec2(20,20), style.colorGreen) then
    modifierValues.checkpoint.position[0] = 0
    modifierValues.checkpoint.position[1] = 0
    modifierValues.checkpoint.position[2] = 0
    tbFunctions.modifierChange('checkpoint')
  end
  if im.Button("<##cp") then tbFunctions.modifierShift("checkpoint",-1) end
  im.SameLine()
  if im.Button(">##cp") then tbFunctions.modifierShift("checkpoint",1) end
end

-- creates the list of checkpoints that are in the track.
local function checkPointUIList()
  im.Columns(3, "Checkpoints") --im.flags(im.ColumnsFlags_NoResize))
  im.SetColumnWidth(0, 35)
  im.SetColumnWidth(1, 50)
  im.SetColumnWidth(2, im.GetWindowWidth() - 85)
  im.Text("#")
  im.NextColumn()
  im.Text("Piece")
  im.NextColumn()
  im.Text("Move")
  im.NextColumn()
  for i,cp in ipairs(currentCheckpointList) do
    if currentIndex == cp.segmentIndex then
      im.TextColored(style.textColor,'#'..i.."")
      im.NextColumn()
      im.TextColored(style.textColor,cp.segmentIndex.."")
      im.NextColumn()
    else
      im.Text("#" .. i)
      im.NextColumn()
      im.Text(cp.segmentIndex.."")
      im.NextColumn()
    end
    if im.Button("<##cp"..i) then
      currentIndex = cp.segmentIndex
      tbFunctions.modifierShift("checkpoint",-1)
    end
    im.SameLine()
    if im.Button("Select##cp"..i) then
      currentIndex = cp.segmentIndex
      tb.focusMarkerOn(currentIndex)
    end
    im.SameLine()
    if im.Button(">##cp"..i) then
      currentIndex = cp.segmentIndex
      tbFunctions.modifierShift("checkpoint",1)
    end
    im.SameLine()
    im.Text(" ")
    im.SameLine()
    if im.Button("Remove##cp"..i) then
      currentIndex = cp.segmentIndex
      tbFunctions.modifierRemove("checkpoint")
      tbFunctions.refreshPieceInfo()
    end
    im.NextColumn()
  end
  im.Columns(1)
end

-- creates the checkpoints window.
local function checkPoints()
  if im.Checkbox(translateLanguage("ui.trackBuilder.checkpoints.active", "Active") .. "##cp",modifierValues.checkpoint.active) then
    if modifierValues.checkpoint.active[0] then
      local currentPiece = tb.getSelectedTrackInfo()
      modifierValues.checkpoint.size[0] = currentPiece.markerInfo.width
    end
    tbFunctions.modifierChange('checkpoint')
    --currentCheckpointList = tb.getAllCheckpoints()
    tbFunctions.refreshPieceInfo()
  end
  if modifierValues.checkpoint.active[0] then
    checkPointInput()
  end

  if #currentCheckpointList == 0 then
    im.TextWrapped(translateLanguage("ui.trackBuilder.checkpoints.info", "If you don't add any checkpoints, they will be automatically created when playing this track through the Time Trials game mode."))
  else
    checkPointUIList()
  end
end

-- advancedPieces

-- splits a curve or straight into two equal pieces.
local function splitPiece()
  local piece = tb.getSelectedTrackInfo()
  local info = piece.parameters
  if not info then return end
  if info.piece == 'freeForward' then
    if info.length < 1 then return end
    tb.addPiece({
      piece = 'freeForward',
      length = info.length/2
    }, currentIndex,true)
    tb.addPiece(
    {
      piece = 'freeForward',
      length = info.length/2
    },currentIndex,false)
  elseif info.piece == 'freeCurve' then
    if info.length < 2 then return end
    tb.addPiece({
      piece = 'freeCurve',
      length = info.length/2,
      radius = info.radius,
      direction = info.direction
    }, currentIndex,true)
    tb.addPiece(
    {
      piece = 'freeCurve',
      length = info.length/2,
      radius = info.radius,
      direction = info.direction
    },currentIndex,false)
  end
  currentIndex = currentIndex+1
  tb.makeTrack()
  tbFunctions.refreshPieceInfo()
  tb.focusMarkerOn(currentIndex)
end

-- creates the parameter buttons for curves.
local function curveParameters(includeSplit)
  local p = pieceInfo.free.curve
  local xPositions = partitionWidth(im.GetWindowWidth(),48,includeSplit and 5 or 4)
  local side = p.direction[0] == -1 and "left" or "right"

  im.SetCursorPosX(xPositions[1])
  im.TextColored(style.textColor,translateLanguage("ui.trackBuilder.base.radius", "Radius") .. ": " .. (p.radius[0]*4)..'m')
  im.SameLine()
  im.SetCursorPosX(xPositions[3])
  im.TextColored(style.textColor, translateLanguage("ui.trackBuilder.base.length", "Length") .. ": " .. p.length[0]..'°')

  im.SetCursorPosX(xPositions[1])
  if editor.uiIconImageButton(editor.icons['tb_'..side..'_curve_thinner'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.radius[0] = CtrlShiftButton(p.radius[0],1,0.25,5,1,50,-1)
    tbFunctions.pieceUpdated(true)
  end
  im.SameLine()
  im.SetCursorPosX(xPositions[2])
  if editor.uiIconImageButton(editor.icons['tb_'..side..'_curve_wider'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.radius[0] = CtrlShiftButton(p.radius[0],1,0.25,5,1,50,1)
    tbFunctions.pieceUpdated(true)
  end
  im.SameLine()
  im.SetCursorPosX(xPositions[3])
  if editor.uiIconImageButton(editor.icons['tb_'..side..'_curve_shorter'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.length[0] = CtrlShiftButton(p.length[0],15,1,45,1,180,-1)
    tbFunctions.pieceUpdated(true)
  end
  im.SameLine()
  im.SetCursorPosX(xPositions[4])
  if editor.uiIconImageButton(editor.icons['tb_'..side..'_curve_longer'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.length[0] = CtrlShiftButton(p.length[0],15,1,45,1,180,1)
    tbFunctions.pieceUpdated(true)
  end
  if includeSplit then
    im.SameLine()
    im.SetCursorPosX(xPositions[5])
    if editor.uiIconImageButton(editor.icons.content_cut,style.buttonSize,style.buttonColorBase) then
      splitPiece()
    end
    im.tooltip(translateLanguage("ui.trackBuilder.advanced.splitPiece", "Split Piece"))
  end
end

-- creates the parameter buttons for straights.
local function straightParameters(includeSplit)
  local xPositions = partitionWidth(im.GetWindowWidth(),48,includeSplit and 3 or 2)
  local p = pieceInfo.free.forward

  im.SetCursorPosX(xPositions[1])
  im.TextColored(style.textColor, translateLanguage("ui.trackBuilder.base.length", "Length") .. ": " .. (p.length[0]*4)..'m')

  im.SetCursorPosX(xPositions[1])
  if editor.uiIconImageButton(editor.icons['tb_forward_shorter'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.length[0] = CtrlShiftButton(p.length[0],1,0.25,5,1,50,-1)
    tbFunctions.pieceUpdated(true)
  end
  im.SameLine()
  im.SetCursorPosX(xPositions[2])
  if editor.uiIconImageButton(editor.icons['tb_forward_longer'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.length[0] = CtrlShiftButton(p.length[0],1,0.25,5,1,50,1)
    tbFunctions.pieceUpdated(true)
  end
  if includeSplit then
    im.SameLine()
    im.SetCursorPosX(xPositions[3])
    if editor.uiIconImageButton(editor.icons.content_cut,style.buttonSize,style.buttonColorBase) then
      splitPiece()
    end
    im.tooltip(translateLanguage("ui.trackBuilder.advanced.splitPiece", "Split Piece"))
    im.tooltip("Split Piece")
  end
end

-- creates the parameter buttons for spirals.
local function spiralParameters()
  local p = pieceInfo.free.spiral
  local xPositions = partitionWidth(im.GetWindowWidth(),48,4)
  local side = p.direction[0] == -1 and "left" or "right"

  im.SetCursorPosX(xPositions[1])
  im.TextColored(style.textColor, translateLanguage("ui.trackBuilder.base.radius", "Radius") .. ": " .. (p.size[0]*4)..'m')
  im.SameLine()
  im.SetCursorPosX(xPositions[3])
  im.TextColored(style.textColor,translateLanguage("ui.trackBuilder.base.length", "Length") .. ": " .. p.angle[0]..'°')

  im.SetCursorPosX(xPositions[1])
  if editor.uiIconImageButton(editor.icons['tb_'..side..'_curve_thinner'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.size[0] = CtrlShiftButton(p.size[0],1,0.25,5,1,50,-1)
    tbFunctions.pieceUpdated(true)
  end
  im.SameLine()
  im.SetCursorPosX(xPositions[2])
  if editor.uiIconImageButton(editor.icons['tb_'..side..'_curve_wider'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.size[0] = CtrlShiftButton(p.size[0],1,0.25,5,1,50,1)
    tbFunctions.pieceUpdated(true)
  end
  im.SameLine()
  im.SetCursorPosX(xPositions[3])
  if editor.uiIconImageButton(editor.icons['tb_'..side..'_curve_shorter'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.angle[0] = CtrlShiftButton(p.angle[0],15,15,15,30,75,-1)
    tbFunctions.pieceUpdated(true)
  end
  im.SameLine()
  im.SetCursorPosX(xPositions[4])
  if editor.uiIconImageButton(editor.icons['tb_'..side..'_curve_longer'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.angle[0] = CtrlShiftButton(p.angle[0],15,15,15,30,75,1)
    tbFunctions.pieceUpdated(true)
  end
  im.SetCursorPosX(xPositions[1])
  im.TextColored(style.textColor,(p.inside[0] and 'Outward' or 'Inward'))
  im.SameLine()

  im.SetCursorPosX(xPositions[3])
  if editor.uiIconImageButton(editor.icons['tb_spiral_'..side..'_' .. (p.inside[0] and 'inside' or 'outside')] or editor.icons.stop,style.buttonSize) then
    p.inside[0] = not p.inside[0]
    tbFunctions.pieceUpdated(true)
  end
end

-- creates the parameter buttons for S-Curves.
local function sCurveParameters()
  local p = pieceInfo.free.scurve
  local xPositions = partitionWidth(im.GetWindowWidth(),48,4)
  im.SetCursorPosX(xPositions[1])
  im.TextColored(style.textColor,"yOffset: " .. (p.length[0]*4)..'m')
  im.SameLine()
  im.SetCursorPosX(xPositions[3])
  im.TextColored(style.textColor,"xOffset: " .. (p.xOffset[0]*4)..'m')

  im.SetCursorPosX(xPositions[1])
  if editor.uiIconImageButton(editor.icons['tb_arrow_down'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.length[0] = CtrlShiftButton(p.length[0],1,0.25,5,-100,100,-1)
    tbFunctions.pieceUpdated(true)
  end
  im.SameLine()
  im.SetCursorPosX(xPositions[2])
  if editor.uiIconImageButton(editor.icons['tb_arrow_up'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.length[0] = CtrlShiftButton(p.length[0],1,0.25,5,-100,100,1)
    tbFunctions.pieceUpdated(true)
  end

  im.SameLine()
  im.SetCursorPosX(xPositions[3])
  if editor.uiIconImageButton(editor.icons['tb_arrow_left'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.xOffset[0] = CtrlShiftButton(p.xOffset[0],1,0.25,5,-100,100,-1)
    tbFunctions.pieceUpdated(true)
  end
  im.SameLine()
  im.SetCursorPosX(xPositions[4])
  if editor.uiIconImageButton(editor.icons['tb_arrow_right'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.xOffset[0] = CtrlShiftButton(p.xOffset[0],1,0.25,5,-100,100,1)
    tbFunctions.pieceUpdated(true)
  end
  im.SetCursorPosX(xPositions[2])
  im.TextColored(style.textColor,"Hardness: " .. (p.hardness[0]))

  im.SetCursorPosX(xPositions[2])
  if editor.uiIconImageButton(editor.icons['tb_scurve_softer'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.hardness[0] = CtrlShiftButton(p.hardness[0],1,0.1,3,-3,8,-1)
    tbFunctions.pieceUpdated(true)
  end
  im.SameLine()
  im.SetCursorPosX(xPositions[3])
  if editor.uiIconImageButton(editor.icons['tb_scurve_harder'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.hardness[0] = CtrlShiftButton(p.hardness[0],1,0.1,3,-3,8,1)
    tbFunctions.pieceUpdated(true)
  end
end

-- creates the parameter buttons for loops.
local function loopParameters()
  local p = pieceInfo.free.loop
  local xPositions = partitionWidth(im.GetWindowWidth(),48,4)
  im.SetCursorPosX(xPositions[1])
  im.TextColored(style.textColor,translateLanguage("ui.trackBuilder.base.radius", "Radius") .. ": " .. (p.radius[0]*4)..'m')
  im.SameLine()
  im.SetCursorPosX(xPositions[3])
  im.TextColored(style.textColor,"xOffset: " .. (p.xOffset[0]*4)..'m')

  im.SetCursorPosX(xPositions[1])
  if editor.uiIconImageButton(editor.icons['tb_loop_smaller'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.radius[0] = CtrlShiftButton(p.radius[0],1,0.25,5,3,30,-1)
    tbFunctions.pieceUpdated(true)
  end
  im.SameLine()
  im.SetCursorPosX(xPositions[2])
  if editor.uiIconImageButton(editor.icons['tb_loop_bigger'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.radius[0] = CtrlShiftButton(p.radius[0],1,0.25,5,3,30,1)
    tbFunctions.pieceUpdated(true)
  end

  im.SameLine()
  im.SetCursorPosX(xPositions[3])
  if editor.uiIconImageButton(editor.icons['tb_arrow_left'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.xOffset[0] = CtrlShiftButton(p.xOffset[0],1,0.25,5,-100,100,-1)
    tbFunctions.pieceUpdated(true)
  end
  im.SameLine()
  im.SetCursorPosX(xPositions[4])
  if editor.uiIconImageButton(editor.icons['tb_arrow_right'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.xOffset[0] = CtrlShiftButton(p.xOffset[0],1,0.25,5,-100,100,1)
    tbFunctions.pieceUpdated(true)
  end
end

-- creates the parameter buttons for bezier pieces.
local function bezierParameters()
  local p = pieceInfo.free.bezier
  local xPositions = partitionWidth(im.GetWindowWidth(),50,4)

  im.SetCursorPosX(xPositions[1])
  im.TextColored(style.textColor,"yOffset: " .. (p.yOff[0]*4)..'m')
  im.SameLine()
  im.SetCursorPosX(xPositions[3])
  im.TextColored(style.textColor,"xOffset: " .. (p.xOff[0]*4)..'m')

  im.SetCursorPosX(xPositions[1])
  if editor.uiIconImageButton(editor.icons['tb_arrow_down'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.yOff[0] = CtrlShiftButton(p.yOff[0],1,0.25,5,-10000,10000,-1)
    tbFunctions.pieceUpdated(true)
  end
  im.SameLine()
  im.SetCursorPosX(xPositions[2])
  if editor.uiIconImageButton(editor.icons['tb_arrow_up'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.yOff[0] = CtrlShiftButton(p.yOff[0],1,0.25,5,-10000,10000,1)
    tbFunctions.pieceUpdated(true)
  end

  im.SameLine()
  im.SetCursorPosX(xPositions[3])
  if editor.uiIconImageButton(editor.icons['tb_arrow_left'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.xOff[0] = CtrlShiftButton(p.xOff[0],1,0.25,5,-10000,10000,-1)
    tbFunctions.pieceUpdated(true)
  end
  im.SameLine()
  im.SetCursorPosX(xPositions[4])
  if editor.uiIconImageButton(editor.icons['tb_arrow_right'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.xOff[0] = CtrlShiftButton(p.xOff[0],1,0.25,5,-10000,10000,1)
    tbFunctions.pieceUpdated(true)
  end

  im.SetCursorPosX(xPositions[1])
  im.TextColored(style.textColor,"fwdLen: " .. (p.forwardLen[0])..'')
  im.SameLine()
  im.SetCursorPosX(xPositions[3])
  im.TextColored(style.textColor,"bckLen: " .. (p.backwardLen[0])..'')

  im.SetCursorPosX(xPositions[1])
  if editor.uiIconImageButton(editor.icons['tb_bezier_back_dec'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.forwardLen[0] = CtrlShiftButton(p.forwardLen[0],1,0.25,5,1,50000,-1)
    tbFunctions.pieceUpdated(true)
  end
  im.SameLine()
  im.SetCursorPosX(xPositions[2])
  if editor.uiIconImageButton(editor.icons['tb_bezier_back_inc'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.forwardLen[0] = CtrlShiftButton(p.forwardLen[0],1,0.25,5,1,50000,1)
    tbFunctions.pieceUpdated(true)
  end

  im.SameLine()
  im.SetCursorPosX(xPositions[3])
  if editor.uiIconImageButton(editor.icons['tb_bezier_fwd_dec'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.backwardLen[0] = CtrlShiftButton(p.backwardLen[0],1,0.25,5,1,50000,-1)
    tbFunctions.pieceUpdated(true)
  end
  im.SameLine()
  im.SetCursorPosX(xPositions[4])
  if editor.uiIconImageButton(editor.icons['tb_bezier_fwd_inc'],style.buttonSize,style.buttonColorBase) then
    p.backwardLen[0] = CtrlShiftButton(p.backwardLen[0],1,0.25,5,1,50000,1)
    tbFunctions.pieceUpdated(true)
  end

  im.SetCursorPosX(xPositions[1])
  im.TextColored(style.textColor,"dirOff: " .. (p.dirOff[0])..'°')
  im.SameLine()
  im.SetCursorPosX(xPositions[3])
  im.TextColored(style.textColor,(p.absolute[0] and 'global' or 'local'))
  im.SameLine()
  im.SetCursorPosX(xPositions[4])
  im.TextColored(style.textColor,(p.empty[0] and 'empty' or 'solid'))

  im.SetCursorPosX(xPositions[1])
  if editor.uiIconImageButton(editor.icons['tb_rotate_left'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.dirOff[0] = CtrlShiftButton(p.dirOff[0],15,1,90,-180,180,-1)
    tbFunctions.pieceUpdated(true)
  end
  im.SameLine()
  im.SetCursorPosX(xPositions[2])
  if editor.uiIconImageButton(editor.icons['tb_rotate_right'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.dirOff[0] = CtrlShiftButton(p.dirOff[0],15,1,90,-180,180,1)
    tbFunctions.pieceUpdated(true)
  end

  im.SameLine()
  im.SetCursorPosX(xPositions[3])
  if editor.uiIconImageButton(editor.icons[p.absolute[0] and 'tb_bezier_absolute_yes' or 'tb_bezier_absolute_no'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.absolute[0] = not p.absolute[0]

    if not im.GetIO().KeyCtrl then
      local info = tb.getSelectedTrackInfo()

      if p.absolute[0] then
        p.xOff[0] = info.globalPosition.x
        p.yOff[0] = info.globalPosition.y
        p.dirOff[0] = info.globalHdg / math.pi * 180
      else
        p.xOff[0] = info.localPosition.x
        p.yOff[0] = info.localPosition.y
        p.dirOff[0] = info.localHdg / math.pi * 180
      end
    end
    tbFunctions.pieceUpdated(true)
  end
  im.SameLine()
  im.SetCursorPosX(xPositions[4])
  if editor.uiIconImageButton(editor.icons[p.empty[0] and 'tb_bezier_empty_yes' or 'tb_bezier_empty_no'] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then
    p.empty[0] = not p.empty[0]
    tbFunctions.pieceUpdated(true)
  end
end

-- creates the parameters accoring to the currently selected piece.
local function pieceParameters(piece, includeSplit)
  if piece == 'freeCurve' then
    curveParameters(includeSplit)
  elseif piece == 'freeForward' then
    straightParameters(includeSplit)
  elseif piece == 'freeOffsetCurve' then
    sCurveParameters()
  elseif piece == 'freeLoop' then
    loopParameters()
  elseif piece == 'freeBezier' then
    bezierParameters()
  elseif piece == 'freeSpiral' then
    spiralParameters()
  end
end

local function leftCurveButton()
  if editor.uiIconImageButton(editor.icons['tb_left_curve'] or editor.icons.stop,style.buttonSize,
    currentPieceName == 'freeCurve' and pieceInfo.free.curve.direction[0] == -1  and style.selectedPieceColor or style.buttonColorBase)
  then
    currentPieceName = 'freeCurve'
    pieceInfo.free.curve.direction[0] = -1
    tbFunctions.pieceUpdated()
  end
end

local function rightCurveButton()
  if editor.uiIconImageButton(editor.icons['tb_right_curve'] or editor.icons.stop,style.buttonSize,
    currentPieceName == 'freeCurve' and pieceInfo.free.curve.direction[0] == 1  and style.selectedPieceColor or style.buttonColorBase)
  then
    currentPieceName = 'freeCurve'
    pieceInfo.free.curve.direction[0] = 1
    tbFunctions.pieceUpdated()
  end
end

local function straightButton()
  if editor.uiIconImageButton(editor.icons['tb_forward'] or editor.icons.stop,style.buttonSize,
    currentPieceName == 'freeForward' and style.selectedPieceColor or style.buttonColorBase)
  then
    currentPieceName = 'freeForward'
    tbFunctions.pieceUpdated()
  end
end

local function leftSpiralButton()
  if editor.uiIconImageButton(editor.icons['tb_spiral_left'] or editor.icons.stop,style.buttonSize,
    currentPieceName == 'freeSpiral' and pieceInfo.free.spiral.direction[0] == -1  and style.selectedPieceColor or style.buttonColorBase)
  then
    currentPieceName = 'freeSpiral'
    pieceInfo.free.spiral.direction[0] = -1
    tbFunctions.pieceUpdated()
  end
end

local function rightSpiralButton()
  if editor.uiIconImageButton(editor.icons['tb_spiral_right'] or editor.icons.stop,style.buttonSize,
    currentPieceName == 'freeSpiral' and pieceInfo.free.spiral.direction[0] == 1  and style.selectedPieceColor or style.buttonColorBase)
  then
    currentPieceName = 'freeSpiral'
    pieceInfo.free.spiral.direction[0] = 1
    tbFunctions.pieceUpdated()
  end
end

local function scurveButton()
  if editor.uiIconImageButton(editor.icons['tb_scurve'] or editor.icons.stop,style.buttonSize,
    currentPieceName == 'freeOffsetCurve' and style.selectedPieceColor or style.buttonColorBase)
  then
    currentPieceName = 'freeOffsetCurve'
    tbFunctions.pieceUpdated()
  end
end

local function loopButton()
  if editor.uiIconImageButton(editor.icons['tb_loop'] or editor.icons.stop,style.buttonSize,
    currentPieceName == 'freeLoop' and style.selectedPieceColor or style.buttonColorBase)
  then
    currentPieceName = 'freeLoop'
    tbFunctions.pieceUpdated()
  end
end

local function bezierButton()
  if editor.uiIconImageButton(editor.icons['tb_bezier'] or editor.icons.stop,style.buttonSize,
    currentPieceName == 'freeBezier' and style.selectedPieceColor or style.buttonColorBase)
  then
    currentPieceName = 'freeBezier'
    pieceInfo.free.bezier.absolute[0] = false
    tbFunctions.pieceUpdated()
  end
end

local function deleteButton()
  if editor.uiIconImageButton(editor.icons.delete,style.buttonSize,style.buttonColorBase) then
    tbFunctions.pieceDeleted()
  end
  im.tooltip(translateLanguage("ui.trackBuilder.base.delete", "Delete Current Segment"))
end

local function closeTrackButton()
  if editor.uiIconImageButton(editor.icons['tb_close_track'] or editor.icons.stop,style.buttonSize, style.buttonColorBase) then
    tb.addClosingPiece()
    tb.makeTrack()
    currentIndex = 1
    tb.focusMarkerOn(currentIndex)
    tbFunctions.refreshPieceInfo()
  end
  im.tooltip(translateLanguage("ui.trackBuilder.base.closeTrack", "Close Track"))
end


local mergeMode = 'merge' -- 'merge' 'delete'
local addSubtrackParams = {
  distance = im.FloatPtr(0),
  radius = im.FloatPtr(20),
  count = im.IntPtr(2),
  angle = im.FloatPtr(45),
  angleOffset = im.FloatPtr(90),
  mode = im.IntPtr(0),
  noInter = im.BoolPtr(false),
  modes =im.ArrayCharPtrByTbl({"Star","Angle","Split"})
}
-- creates the subTrack window

local function displaySubTrackPositions()
  local pieceCount = #tb.getPieceInfo(nil, sub).pieces
  local lastPoint = tb.getSegmentInfo(pieceCount, sub).points[#tb.getSegmentInfo(pieceCount, sub).points]
  local inter = lastPoint.position + vec3(0,0,lastPoint.zOffset)
        + lastPoint.orientation.ny*(addSubtrackParams.distance[0] )
  local center = lastPoint.position + vec3(0,0,lastPoint.zOffset)
        + lastPoint.orientation.ny*(addSubtrackParams.distance[0] + addSubtrackParams.radius[0])
  debugDrawer:drawSphere(inter, 0.2, ColorF(1, 1, 0, 1))
  debugDrawer:drawSphere(center, 1, ColorF(1, 0, 0, 1))
  debugDrawer:drawLine((lastPoint.position + vec3(0,0,lastPoint.zOffset)), inter,ColorF(1, 1, 0, 1))
  debugDrawer:drawLine(center, inter,ColorF(1, 0, 0, 1))

  local angles = {}
  if addSubtrackParams.mode[0] == 0 then
    for i= 1, addSubtrackParams.count[0] do
      angles[i] = i * (360/(addSubtrackParams.count[0]+1))
    end
  end

  if addSubtrackParams.mode[0] == 1 or addSubtrackParams.mode[0] == 2 then
    local ang = addSubtrackParams.angle[0]
    local off = addSubtrackParams.angleOffset[0]
    if addSubtrackParams.count[0] <= 1 then
      addSubtrackParams.count[0] = 1
    end
    if addSubtrackParams.mode[0] == 2 then
      ang = ang*2
      off = 180 - ang/2
      ang = ang / math.max((addSubtrackParams.count[0]-1),1)
    end

    for i= 1, addSubtrackParams.count[0] do
      angles[i] = (i-1) * ang + off
    end
  end



  for _, a in ipairs(angles) do
    local p = a/180 * math.pi + math.pi

    local nx = vec3(lastPoint.orientation.nx.x*math.cos(p)- lastPoint.orientation.nx.y * math.sin(p),
                    lastPoint.orientation.nx.y*math.cos(p)+ lastPoint.orientation.nx.x * math.sin(p),0)
    local ny = vec3(lastPoint.orientation.ny.x*math.cos(p)- lastPoint.orientation.ny.y * math.sin(p),
                    lastPoint.orientation.ny.y*math.cos(p)+ lastPoint.orientation.ny.x * math.sin(p),0)

    local target = center + ny *addSubtrackParams.radius[0]

    debugDrawer:drawSphere(target , 0.5, ColorF(1, 0, 0, 1))
    debugDrawer:drawLine((target + nx*5), (target-nx*5),ColorF(1, 0, 0, 1))
    debugDrawer:drawLine(target, center,ColorF(1, 0, 0, 1))
  end

  if im.Button("Create") then
    local mergeList = {}
    table.insert(mergeList,{sub = subTrackIndex[0], index =  #tb.getPieceInfo(nil, sub).pieces, segment = tb.getSegmentInfo(pieceCount, sub), reverse = false})
    for _, a in ipairs(angles) do

      local p = a/180 * math.pi + math.pi

      local nx = vec3(lastPoint.orientation.nx.x*math.cos(p)- lastPoint.orientation.nx.y * math.sin(p),
                      lastPoint.orientation.nx.y*math.cos(p)+ lastPoint.orientation.nx.x * math.sin(p),0)
      local ny = vec3(lastPoint.orientation.ny.x*math.cos(p)- lastPoint.orientation.ny.y * math.sin(p),
                      lastPoint.orientation.ny.y*math.cos(p)+ lastPoint.orientation.ny.x * math.sin(p),0)

      local target = center + ny *addSubtrackParams.radius[0]


      local hdg = (-math.atan2(lastPoint.orientation.ny.y, -lastPoint.orientation.ny.x) + math.pi / 2) * 180 / math.pi
      local newIndex = tb.createNewSubTrack(target, hdg + a - 180)
      tbFunctions.switchSubTrack(newIndex)

      tb.makeTrack(true)
      table.insert(mergeList,{sub = newIndex, index =  1, reverse = true, segment = tb.getSegmentInfo(2, newIndex)})
    end
    if not addSubtrackParams.noInter[0] then
      tbFunctions.mergeMultiTrack(mergeList)
    end
  end
  im.SameLine()
  im.Checkbox("No Intersection", addSubtrackParams.noInter)

  if im.Button("Delete SubTrack") then
    tb.removeSubTrack(subTrackIndex[0])
    if subTrackIndex[0] > 1 then subTrackIndex[0] = subTrackIndex[0]-1 end
    tbFunctions.switchSubTrack(subTrackIndex[0])
  end


end


local function subTracks()
  if im.InputInt("Index", subTrackIndex) then
    --dump("Switched subtrack to: " .. subTrackIndex[0])
    tbFunctions.switchSubTrack(subTrackIndex[0])
  end
  if im.TreeNode1("Create Intersection") then
    im.Combo1("Mode",addSubtrackParams.mode,addSubtrackParams.modes)
    im.DragFloat("Distance",addSubtrackParams.distance,0.1)
    if im.DragFloat("Radius",addSubtrackParams.radius,0.1) then
      addSubtrackParams.radius[0] = math.max(0,addSubtrackParams.radius[0])
    end
    if im.InputInt("Count", addSubtrackParams.count) then
      if addSubtrackParams.count[0] < 1 then addSubtrackParams.count[0] = 1 end
    end
    if addSubtrackParams.mode[0] == 1 or addSubtrackParams.mode[0] == 2 then
      im.DragFloat("Angle", addSubtrackParams.angle, 1)
    end
    if addSubtrackParams.mode[0] == 1 then
      im.DragFloat("Offset", addSubtrackParams.angleOffset, 1)
    end

    displaySubTrackPositions()

    im.TreePop()
  end
  if im.TreeNode1("Merge Tracks") then
    if not paintModes.Merge.active[0] then
      currentMergeList = {}
      mergeMode = "merge"
      if im.Button("Start Merging") then
        currentMergeList = {}
        mergeMode = "merge"
        selectMode("Merge")
      end
      if im.Button("Delete Intersection") then
        mergeMode = "delete"
        selectMode("Merge")
      end
    else
      if mergeMode == "merge" then
        if im.Button("Merge Selected Pieces") then
          if #currentMergeList > 1 then
            tbFunctions.mergeMultiTrack(currentMergeList)
            currentMergeList = {}
              selectMode("Select")
          end
        end
        if im.Button("Stop Merging") then
          currentMergeList = {}
          selectMode("Select")
        end
        im.Text("Number of Pieces:" .. #currentMergeList)
        for _, seg in ipairs(currentMergeList) do
          if seg.reverse then
            debugDrawer:drawSphere((seg.segment.points[1].position + (vec3(0,0,seg.segment.points[1].zOffset))), 3, ColorF(1, 0, 0, 0.75))
          else
            debugDrawer:drawSphere((seg.segment.points[#seg.segment.points].position + (vec3(0,0,seg.segment.points[#seg.segment.points].zOffset))), 3, ColorF(1, 0, 0, 0.75))
          end
        end
      elseif mergeMode == "delete" then
        if im.Button("Stop Deleting") then
          selectMode("Select")
        end
      end
    end

    im.TreePop()
  else
    if mergeMode == "delete" or mergeMode == "merge" then
      selectMode("Select")
    end
  end
  --if im.Button("Load!") then tb.load("mulzi",false,false,false) end
end

local function onSubTracksClosed()
  if paintModes.Merge.active[0] then
    selectMode("Select")
  end
end

-- creates the advanced pieces window.
local function advancedPieces()
  navigationRow()
  im.Separator()

  local piecePositions = partitionWidth(im.GetWindowWidth(), 48, 5)
  -- first row
  im.SetCursorPosX(piecePositions[1]+1)
  deleteButton()
  im.SameLine()
  im.SetCursorPosX(piecePositions[2]+1)
  leftCurveButton()
  im.SameLine()
  im.SetCursorPosX(piecePositions[3]+1)
  straightButton()
  im.SameLine()
  im.SetCursorPosX(piecePositions[4]+1)
  rightCurveButton()
  im.SameLine()
  im.SetCursorPosX(piecePositions[5]+1)
  closeTrackButton()

  -- second row
  im.SetCursorPosX(piecePositions[1]+1)
  bezierButton()
  im.SameLine()
  im.SetCursorPosX(piecePositions[2]+1)
  leftSpiralButton()
  im.SameLine()
  im.SetCursorPosX(piecePositions[3]+1)
  scurveButton()
  im.SameLine()
  im.SetCursorPosX(piecePositions[4]+1)
  rightSpiralButton()
  im.SameLine()
  im.SetCursorPosX(piecePositions[5]+1)
  loopButton()

  -- add piece parameters
  im.Separator()
  pieceParameters(currentPieceName, true)
end

-- writes the settings of the editor to disk.
local function serializeSettings()
  local settings = {}
  for name,v in pairs(menuSettings) do
    if v.type == "bool" then
      if v.value[0] == true then
        settings[name] = {value=true, type="bool"}
      else
        settings[name] = {value=false, type="bool"}
      end
    elseif v.type == "float" then
      settings[name] = {value = v.value[0], type = "float"}
    end
  end
  jsonWriteFile("settings/trackBuilderSettings.json", settings, true)
end

-- reads the settings of the editor from disk.
local function deserializeSettings()
  local settings = jsonReadFile("settings/trackBuilderSettings.json")
  if not settings then return end
  for name, v in pairs(settings) do
    if menuSettings[name] then
      if v.type == "bool" then
        menuSettings[name] = {value = im.BoolPtr(v.value), type == "bool"}
      elseif v.type == "float" then
        menuSettings[name] = {value = im.FloatPtr(v.value), type == "bool"}
      end
    end
  end
end

-- creates the stop driving window at the top of the screen.
local function stopDrivingWindow()
  --im.SetNextWindowPos(im.ImVec2(style.displaySize.x/2-108, 0))
  im.SetNextWindowSize(im.ImVec2(216, 76))
  im.Begin("StopDrivingWindow", stopDrivingWindowOpen, im.flags(im.WindowFlags_NoResize, im.WindowFlags_NoScrollbar))
    if im.Button("Stop Driving", im.ImVec2(200,60)) then
      driving = false
      tbFunctions.unDrive()
      selectMode('Select')
    end
  im.End()
end

-- check if windows are out of bounds and move them accordingly
local function CheckWindows()
  -- local i = 0
  -- local fixedWindowCount = 0
  -- local windowPositions = {}
  -- while im.GetWindow(i) ~= nil do
  --   local window = im.GetWindow(i)
  --   if window[0].Pos.x < 0 then window[0].Pos.x = 20 end
  --   if window[0].Pos.y < 0 then window[0].Pos.y = 20 end
  --   if window[0].Pos.x + window[0].Size.x > style.displaySize.x then window[0].Pos.x = style.displaySize.x - window[0].Size.x - 20 end
  --   if window[0].Pos.y + window[0].Size.y > style.displaySize.y  then window[0].Pos.y = style.displaySize.y - window[0].Size.y - 20 end

  --   local collision = false
  --   for j, p in ipairs(windowPositions) do
  --     if math.abs(window[0].Pos.x - p.x) < 5 and math.abs(window[0].Pos.y - p.y) < 5 then
  --       window[0].Pos.x = window[0].Pos.x + 15
  --       window[0].Pos.y = window[0].Pos.y + 15
  --     end
  --   end
  --   windowPositions[i+1] = {x = window[0].Pos.x, y = window[0].Pos.y }
  --   i = i + 1
  -- end
end

--creates the toolbar for a given set of items.
local function toolbarFromMenuItems(items,sorted)
  for _, v in pairs(sorted) do
    if items[v].icon then
      if items[v].isOpen[0]==true then
        if editor.uiIconImageButton(items[v].icon or editor.icons.stop, nil, style.buttonColorBase,nil, style.buttonColorBGSelected) then
          items[v].isOpen[0]=false
          if items[v].onCloseFunction ~= nil then
            items[v].onCloseFunction()
          end
        end
      else
        if editor.uiIconImageButton(items[v].icon or editor.icons.stop, nil, style.buttonColorBase,nil, style.buttonColorBG) then
          items[v].isOpen[0]=true
          if items[v].onOpenFunction ~= nil then
            items[v].onOpenFunction()
          end
        end
      end
      if im.IsItemHovered() then im.tooltip(items[v].name) end
    end
    im.SameLine()
  end
end

-- creates the toolbar for the windows at the top of the screen.
local function toolbar()
  im.SetNextWindowSize(im.ImVec2(style.toolbarWidth, 72))
 -- im.SetNextWindowPos(im.ImVec2(style.displaySize.x/2 - style.fullToolbarsWidth/2,0))
  im.Begin( translateLanguage("ui.trackBuilder.toolbar.title", "Toolbar"), nil, im.flags(im.WindowFlags_NoScrollbar, im.WindowFlags_NoResize, im.WindowFlags_NoCollapse, im.WindowFlags_NoDocking))
  if driving then
    --im.SetCursorPosX(style.toolbarWidth/2 - 100)
    if im.Button("Stop Driving", im.ImVec2(-1,-1)) then
      driving = false
      tbFunctions.unDrive()
      selectMode('Select')
    end
  else
    toolbarFromMenuItems(menuItems,menuItemsSorted)

    local pos = im.GetWindowPos()
    local p = im.ImVec2(pos.x + im.GetCursorPosX() - 4 ,pos.y + im.GetCursorPosY()-4)
    local col = im.GetColorU322(im.ImVec4(0.5,0.5,0.5,1))
    im.ImDrawList_AddRectFilled(im.GetWindowDrawList(), p, im.ImVec2(p.x+1,p.y+40), col)
    im.SetCursorPosX(im.GetCursorPosX() + 1)

    toolbarFromMenuItems(additionalMenuItems,additionalMenuItemsSorted)

    pos = im.GetWindowPos()
    p = im.ImVec2(pos.x + im.GetCursorPosX() - 4 ,pos.y + im.GetCursorPosY()-4)
    im.ImDrawList_AddRectFilled(im.GetWindowDrawList(), p, im.ImVec2(p.x+1,p.y+40), col)
    im.SetCursorPosX(im.GetCursorPosX() + 1)

    for _, name in pairs(paintModesSorted) do
      if paintModes[name].active[0] == true then
        editor.uiIconImageButton(paintModes[name].icon or editor.icons.stop, nil,style.buttonColorBase,nil, style.buttonColorBGSelected)
      else
        if editor.uiIconImageButton(paintModes[name].icon or editor.icons.stop, nil, style.buttonColorBase,nil, style.buttonColorBG) then
          selectMode(name)
        end
      end
      if im.IsItemHovered() then im.tooltip(paintModes[name].tooltip) end
      im.SameLine()
    end
  end
  im.End()
end

local function mainModifiers(name,leftIcon,rightIcon,step,small,big,min,max)

  if im.Button("<##"..name,style.slimButtonSize) then tbFunctions.modifierShift(name,-1) end
    im.tooltip(translateLanguage("ui.trackBuilder.tooltip.shiftBack", "Shift Modifier Back"))
    im.SameLine()
    if editor.uiIconImageButton(editor.icons[leftIcon] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then modifierValues[name].value[0] = CtrlShiftButton(modifierValues[name].value[0],step,small,big,min,max,-1) tbFunctions.modifierChange(name) end
    im.SameLine()
    if editor.uiIconImageButton(editor.icons[rightIcon] or editor.icons.stop,style.buttonSize,style.buttonColorBase) then modifierValues[name].value[0] = CtrlShiftButton(modifierValues[name].value[0],step,small,big,min,max,1) tbFunctions.modifierChange(name) end
    im.SameLine()
    if im.Button(">##"..name,style.slimButtonSize) then tbFunctions.modifierShift(name,1) end
    im.tooltip(translateLanguage("ui.trackBuilder.tooltip.shiftForward", "Shift Modifier Forward"))
    im.SameLine()
    im.SetCursorPosY(im.GetCursorPosY() + 8)
    modifierButtons(name,0, false,im.ImVec2(29,29))

end

-- creates the main window.
local function mainWindow()
  navigationRow()
  im.Spacing()
  im.Separator()

  if not menuItems.advancedPieces.isOpen[0] or not menuSettings.hidePieces.value[0] then
    local piecePositions = partitionWidth(im.GetWindowWidth(), 48, 5)
    im.SetCursorPosX(piecePositions[1]+1)
    deleteButton()
    im.SameLine()
    im.SetCursorPosX(piecePositions[2]+1)
    leftCurveButton()
    im.SameLine()
    im.SetCursorPosX(piecePositions[3]+1)
    straightButton()
    im.SameLine()
    im.SetCursorPosX(piecePositions[4]+1)
    rightCurveButton()
    im.SameLine()
    im.SetCursorPosX(piecePositions[5]+1)
    closeTrackButton()

    if currentPieceName == 'freeCurve' or currentPieceName == 'freeForward' then
      pieceParameters(currentPieceName)
    else
      im.Spacing()
      im.SetCursorPosX(im.GetWindowWidth()/2 - 100)
      if im.Button(translateLanguage("ui.trackbuilder.menus.openAdvancedPieces","Open Advanced Pieces"),im.ImVec2(200,50)) then
        menuItems.advancedPieces.isOpen[0] = true
      end
    end
    im.Spacing()
    im.Separator()
  end

  if not menuItems.advancedModifiers.isOpen[0] or not menuSettings.hideModifiers.value[0] then
    im.Spacing()
    im.TextColored(style.textColor,string.format(translateLanguage("ui.trackbuilder.base.banking", "Banking") .. ": %.1f°", modifierValues.bank.value[0]))
    mainModifiers('bank','tb_bank_left','tb_bank_right',15,1,60,-720,720)
    im.Spacing()

    im.TextColored(style.textColor,string.format(translateLanguage("ui.trackBuilder.base.height", "Height") .. ": %.1fm", modifierValues.height.value[0]))
    mainModifiers('height','tb_height_lower','tb_height_higher',1,5,25,-50000,50000)
    im.Spacing()

    im.TextColored(style.textColor, translateLanguage("ui.trackBuilder.base.width", "Width") .. ": " .. modifierValues.width.value[0]..'m')
    mainModifiers('width','tb_width_slimmer','tb_width_wider',1,5,10,0,50)
    im.Spacing()
    im.Separator()
  end
  im.Spacing()

  local selectorPositions = partitionWidth(im.GetWindowWidth(), 100, 2)
  im.SetCursorPosX(selectorPositions[1])
  if im.Button(translateLanguage("ui.trackBuilder.base.drive","Drive"),im.ImVec2(100,24)) then
    tbFunctions.drive()
  end
  im.SameLine()
  im.SetCursorPosX(selectorPositions[2])
  if im.Button(translateLanguage("ui.trackBuilder.base.test","Test"),im.ImVec2(100,24)) then
    tbFunctions.drive(currentIndex-1)
  end
  im.tooltip(translateLanguage("ui.trackBuilder.base.testDrive",'Starts from the selected Piece'))

end

-- creates the menu bar for the main window.
local function menuBar()
  if im.BeginMenuBar() then
    if im.BeginMenu(translateLanguage("ui.trackbuilder.menus.windows","Windows")) then
      for k,v in pairs(menuItemsSorted) do
        if im.MenuItem2(menuItems[v].name, "", menuItems[v].isOpen) then
          if menuItems[v].isOpen[0] and menuItems[v].onOpenFunction ~= nil then
            menuItems[v].onOpenFunction()
          end
          if not menuItems[v].isOpen[0] and menuItems[v].onCloseFunction ~= nil then
            menuItems[v].onCloseFunction()
          end
        end
      end
      im.Separator()
      for k,v in pairs(additionalMenuItemsSorted) do
        im.MenuItem2(additionalMenuItems[v].name, "", additionalMenuItems[v].isOpen)
      end
      --im.MenuItem2("Help",nil,helpOpen)
      im.EndMenu()
    end
    if im.BeginMenu(translateLanguage("ui.trackbuilder.menus.editorSettings", "Editor Settings")) then
      if im.MenuItem1(translateLanguage("ui.trackbuilder.menus.removeTrack","Remove Track")) then
        toggleTrackBuilder()
        tb.removeTrack()
      end
      if im.MenuItem1(translateLanguage("ui.trackbuilder.menus.resetTrack", "Reset Track")) then
        tb.removeTrack()
        currentIndex = 2
        tb.initTrack()
        tb.setHighQuality(true)
        tb.makeTrack(true)
        tb.focusMarkerOn(2)
        tbFunctions.refreshPieceInfo()
      end
      im.Separator()
      if im.MenuItem2(translateLanguage("ui.trackbuilder.menus.onlyOnePiecesWindow","Only one Pieces Window"),"",menuSettings.hidePieces.value) then serializeSettings() end
      if im.MenuItem2(translateLanguage("ui.trackbuilder.menus.onlyOneModifierWindow", "Only one Modifier Window"),"",menuSettings.hideModifiers.value) then serializeSettings() end
      if im.MenuItem2(translateLanguage("ui.trackBuilder.settings.cameraFollow", "Automatic camera follow"),"",menuSettings.camActivated.value) then
        tb.camActivated = menuSettings.camActivated.value[0]
        serializeSettings()
      end
      if editor.uiSliderFloat(translateLanguage("ui.trackBuilder.settings.cameraFollowDistance", "Follow Distance"),menuSettings.camDistance.value, 10, 200, "%.1f", nil, camDistanceChanged) then tb.camDistance = menuSettings.camDistance.value[0] end
      if camDistanceChanged[0] == true then serializeSettings() end
      im.EndMenu()
    end
    im.EndMenuBar()
  end
end

-- shows the sub windows if they are opened, and calls function when they are closed/opened.
local function showSubWindows()
  for k,v in pairs(menuItems) do
    if v.wasOpen == true and v.isOpen[0] == false then
      v.wasOpen = false
      -- window has been closed
    end
    if v.isOpen[0] then
      local closed = false
      if v.size then im.SetNextWindowSize(v.size) end
      if im.Begin(v.name,v.isOpen) then
        if v.wasOpen == false then
          -- window has been opened
          v.wasOpen = true
          CheckWindows()
        end
        v.functionName()
        if not v.isOpen[0] and v.onCloseFunction ~= nil then v.onCloseFunction() end
      end
      im.End()
    end
  end
  for k,v in pairs(additionalMenuItems) do
    if v.wasOpen == true and v.isOpen[0] == false then
      v.wasOpen = false
      -- window has been closed
    end
    if v.isOpen[0] then
      if v.size then im.SetNextWindowSize(v.size) end
      if im.Begin(v.name,v.isOpen) then
        if v.wasOpen == false then
          -- window has been opened
          v.wasOpen = true
          CheckWindows()
        end
        v.functionName()
        if not v.isOpen[0] and v.onCloseFunction ~= nil then v.onCloseFunction() end
      end
      im.End()
    end
  end
end

-- sets up the track.
local function setupTrack()
  if #tb.getPieceInfo().pieces == 0 then tb.initTrack() end
  tb.setHighQuality(true)
  tb.makeTrack(true)

  tb.positionVehicle()

  commands.setFreeCamera()
  currentIndex = 2
  tb.focusMarkerOn(currentIndex)
  tb.focusCameraOn(currentIndex,nil,true)

  CheckWindows()
  tbFunctions.refreshTrackPositionRotation()
  trackSpawned = true
end

-- draws the editor itself (not the drive window)
local function drawTrackBuilderUI()
  im.SetNextWindowSize(im.ImVec2(280,0))
  local flags = trackSpawned and im.flags(im.WindowFlags_MenuBar, im.WindowFlags_NoResize) or im.flags(im.WindowFlags_NoResize)
  -- only show X to close when not started
  local open = nil
  if not trackSpawned then
    open = im.BoolPtr(true)
  end

  if im.Begin(translateLanguage("ui.trackbuilder.menus.trackBuilder", "Track Builder"), open, flags) then
    style.toolbarWidth = (#menuItemsSorted + #additionalMenuItemsSorted) * 32 + 16 + (#menuItemsSorted + #additionalMenuItemsSorted - 1) * 8 +  (#paintModesSorted) * 32 + 16 + (#paintModesSorted - 1) * 8 - 4
    style.paintToolbarWidth = (#paintModesSorted) * 32 + 16 + (#paintModesSorted - 1) * 8
    style.fullToolbarsWidth = (style.toolbarWidth + style.toolbarSpacing + style.paintToolbarWidth)
    -- auto accept if there is actually track already
    if #tb.getPieceInfo().pieces > 2 then
      trackSpawned = true
    end
    --paintModeToolbar()
    if not trackSpawned then
      if im.Button(translateLanguage("ui.trackbuilder.menus.startTrackBuilder", "Start Track Builder Here"), im.ImVec2(-1,0)) then
        trackSpawned = true
        -- spawn actual track
        setupTrack()
      end
      if im.Button(translateLanguage("ui.trackbuilder.menus.startTrackBuilderOnGlowCity", "Switch to Glow City"), im.ImVec2(-1,0)) then
        freeroam_freeroam.startTrackBuilder('glow_city',true)
      end
    elseif trackSpawned then
      menuBar()
      mainWindow()
    end
    im.End()
  end
  if trackSpawned then
    toolbar()
    showSubWindows()
  end

  if open and not open[0] then
    M.hideTrackBuilder()
    return
  end



end



local function addMergeSegment(index, sub)
  -- check if segment is contained, remove if found
  local pieceCount = #tb.getPieceInfo(nil, sub).pieces
  local found = false
  local done = false
  for i = 1, #currentMergeList do
    if not done then
      if not found and currentMergeList[i].sub == sub and currentMergeList[i].index == index then
        found = true
      end
      if found then
        if pieceCount == 2 and currentMergeList[i].reverse then
          currentMergeList[i].reverse = false
          done = true
        else
          currentMergeList[i] = currentMergeList[i+1]
        end
      end
    end
  end
  if found then return end
    -- check if the segment is first or last in its list, otherwise ignore it

  if index ~= 2 and index ~= pieceCount then return end
  -- else add it to the list. "first" pieces go reverse.
  currentMergeList[#currentMergeList+1] = {
    sub = sub,
    index = index,
    reverse = index == 2,
    segment = tb.getSegmentInfo(index, sub)
  }


end

local function mergeMeshMouseUpdate(res)
  if im.IsMouseClicked(0) then
    if res and res.object and not im.GetIO().WantCaptureMouse then
      if mergeMode == 'merge' then
        local index, sub = meshNameToIndex(res.object:getName())
        if index ~= -1 then
          addMergeSegment(index, sub)
        end
      elseif mergeMode == 'delete' then
        if string.startswith(res.object:getName(),"procMerger") then
          tb.removeIntersection(res.object:getName())
        end
      end
    end
  end
end

local function selectMouseUpdate(res)
  if im.IsMouseClicked(0) then
    if res and res.object and not im.GetIO().WantCaptureMouse then
      local index, sub = meshNameToIndex(res.object:getName())
      if index ~= -1 then
        if sub ~= subTrackIndex[0] then
          tbFunctions.switchSubTrack(sub)
          subTrackIndex[0] = sub
        end
        currentIndex = index
        tb.focusMarkerOn(index)
        tbFunctions.refreshPieceInfo()
      end
    end
  end
end

local function paintSegment(index,sub,doFill,pipette)
  if pipette then
    local mat = tb.getPieceInfo(index, sub).materialInfo.centerMesh or 'track_editor_A_center'
    mat = string.sub(mat, 0, 15)
    materialSettings.selectedMaterial[0] = indexOf(materials.matNames,mat)-1
    updateMaterialFields()
  else
    local change = false
    for name,val in pairs(materials.materialInfo) do
      if val.paint[0] then
        change = tb.setMaterial(index, sub,name,
          materials.matNames[materialSettings.selectedMaterial[0]+1] .. val.table,
          -- materials[materials.materialInfo[name].table].matNames[materials.materialInfo[name].value[0]+1],
          doFill) or change
      end
    end
    if change then
      tb.unselectAll()
      tb.refreshAllMaterials()
    end
  end
end


local function paintObstacle(segIndex, obsIndex, doFill, pipette)
  local obstacles = tb.getPieceInfo(segIndex).obstacles
  local indexes = tb.getSegmentInfo(segIndex).procObstacleIndexes
  --dump(obstacles)
  --dump(procObstacleIndexes)

end

local function obstacleNameToIndex(name)
  if not string.startswith(name,"procObstacle") then return -1,-1 end
  local dashIndex = string.find(name,"x")
  return tonumber(string.match (name, "%d+")),tonumber(string.match (name, "%d+",dashIndex))
end

local function paintIntersection(name, pipette)
  if pipette then
    local mat = tb.getIntersection(name).centerMat or 'track_editor_A_center'
    mat = string.sub(mat, 0, 15)
    materialSettings.selectedMaterial[0] = indexOf(materials.matNames,mat)-1
    updateMaterialFields()
  else
    tb.setIntersectionMaterial(name,
      (materials.materialInfo['centerMesh'].paint[0] and (materials.matNames[materialSettings.selectedMaterial[0]+1] .. 'center') or nil),
      (materials.materialInfo['rightMesh'].paint[0] and (materials.matNames[materialSettings.selectedMaterial[0]+1] .. 'border') or nil)
      )
  end
end

local function paintMouseUpdate(res)
  local doPaint = false
  for name,val in pairs(materials.materialInfo) do
    doPaint = doPaint or val.paint[0]
  end
  if doPaint then
    if res and res.pos and not im.GetIO().WantCaptureMouse then
      res.pos = vec3(res.pos)
      --debugDrawer:drawSphere(res.pos, 0.6, ColorF(1,0,0,0.5))
      local doFill = not im.GetIO().KeyShift and im.GetIO().KeyCtrl and im.IsMouseClicked(0,false)
      local holdAndPaint = not im.GetIO().KeyShift and not im.GetIO().KeyCtrl and im.IsMouseDown(0)
      local pipette = im.GetIO().KeyShift and not im.GetIO().KeyCtrl and im.IsMouseClicked(0,false)
      --dump(res)
      if (doFill or holdAndPaint or pipette) and res.object then
        local txt = '[' .. tostring(res.object:getId()) .. ']'
        --dump(txt)
      --dump(res.object:getName())
        local index, sub = meshNameToIndex(res.object:getName())
        local segIndex, obsIndex = obstacleNameToIndex(res.object:getName())
        if index ~= -1 then
          paintSegment(index,sub,doFill,pipette)
        elseif segIndex ~= -1 then
          paintObstacle(index,sub,doFill,pipette)
        elseif string.startswith(res.object:getName(),"procMerger") then
          paintIntersection(res.object:getName())
        end
      end
    end
  end
end

local function setSegmentMesh(index, sub, doFill,pipette)
  if pipette then
    local pieceInfo = tb.getPieceInfo(index)
    modifierValues.centerMesh.value[0] = indexOf(modifierValues.centerMesh.table, pieceInfo.centerMesh or 'regular')-1
    modifierValues.rightMesh.value[0] = indexOf(modifierValues.rightMesh.table, pieceInfo.rightMesh or 'regular')-1
    modifierValues.leftMesh.value[0] = indexOf(modifierValues.leftMesh.table, pieceInfo.leftMesh or 'regular')-1
  else
    local change = false
    for name, borderPaint in pairs(clickInputModes) do
      if borderPaint[0] == true then
        change = tb.setMesh(index,name,modifierValues[name].table[modifierValues[name].value[0]+1],im.GetIO().KeyCtrl) or change
      end
    end
    if change then
      tb.makeTrack()
    end
  end
end

local function setIntersectionMesh(name)
  if pipette then
    local mesh = tb.getIntersection(name).borderMesh or 'regular'
    modifierValues.rightMesh.value[0] = indexOf(modifierValues.leftMesh.table, mesh)-1
    modifierValues.leftMesh.value[0] = indexOf(modifierValues.leftMesh.table, mesh)-1
  else
    tb.setIntersectionMesh(name,
      (clickInputModes['rightMesh'][0] and modifierValues['rightMesh'].table[modifierValues['rightMesh'].value[0]+1] or nil) )
  end
end

local function meshMouseUpdate(res)
  if res and res.pos and not im.GetIO().WantCaptureMouse then
    res.pos = vec3(res.pos)
    -- debugDrawer:drawSphere(res.pos, 0.3, ColorF(1,0,0,0.5))
    local doFill = not im.GetIO().KeyShift and im.GetIO().KeyCtrl and im.IsMouseClicked(0,false)
    local holdAndPaint = not im.GetIO().KeyShift and not im.GetIO().KeyCtrl and im.IsMouseDown(0)
    local pipette = im.GetIO().KeyShift and not im.GetIO().KeyCtrl and im.IsMouseClicked(0,false)
    if (doFill or holdAndPaint or pipette) and res.object then
      local index, sub = meshNameToIndex(res.object:getName())
      if index ~= -1 then
        setSegmentMesh(index, sub, doFill, pipette)
      elseif string.startswith(res.object:getName(),"procMerger") then
        setIntersectionMesh(res.object:getName())
      end
    end
  end
end

local function trackBuilderEditModeUpdate()
  if driving then return end
  local res = cameraMouseRayCast(true)
  if paintModes.Select.active[0] == true then
    selectMouseUpdate(res)
  elseif paintModes.Paint.active[0] == true then
    paintMouseUpdate(res)
  elseif paintModes.ChangeMesh.active[0] == true then
    meshMouseUpdate(res)
  elseif paintModes.Merge.active[0] == true then
    mergeMeshMouseUpdate(res)
  end
end

-- shows either the main window, the drive window or nothing when a screenshot is taken.
local function onUpdate()

  if not initialized then return end
  if hiddenForScreenshotTimer > 0 then
    hiddenForScreenshotTimer = hiddenForScreenshotTimer - im.GetIO().DeltaTime

    if not screenshotTaken and hiddenForScreenshotTimer < 0.5 then
      createScreenshot("trackEditor/"..ffi.string(saveSettings.saveStr))
      screenshotTaken = true
    end

    if hiddenForScreenshotTimer <= 0 then
      tb.focusMarkerOn(currentIndex)
      saveSettings.previewNames = tb.getPreviewNames()
      --tb.showMarkers(false)
    end
  else
    editor.checkWindowResize()
    if driving then
    --  stopDrivingWindow()
      if initialized then toolbar() end
    else
      if open[0] and initialized then
        drawTrackBuilderUI()
        trackBuilderEditModeUpdate()
        if not open[0] then
          --editor.hideTrackBuilder()
        end
      end
    end
  end

end

local function trackBuilderEditModeToolbar()
  -- for _, v in pairs(menuItemsSorted) do
  --   if menuItems[v].icon then
  --     if menuItems[v].value[0]==true then
  --       if editor.uiIconImageButton(menuItems[v].icon) then
  --         if menuItems[v].value[0]==true then menuItems[v].value[0]=false else menuItems[v].value[0]=true end
  --       end
  --     else
  --       if editor.uiIconImageButton(menuItems[v].icon, nil, nil, nil, im.ImColorByRGB(0,0,0,255).Value) then
  --         if menuItems[v].value[0]==true then menuItems[v].value[0]=false else menuItems[v].value[0]=true end
  --       end
  --     end
  --     if im.IsItemHovered() then im.tooltip(menuItems[v].name) end
  --   end
  -- end
  -- im.Separator()
  -- for _, v in pairs(additionalMenuItemsSorted) do
  --   if additionalMenuItems[v].icon then
  --     if additionalMenuItems[v].value[0]==true then
  --       if editor.uiIconImageButton(additionalMenuItems[v].icon) then
  --         if additionalMenuItems[v].value[0]==true then additionalMenuItems[v].value[0]=false else additionalMenuItems[v].value[0]=true end
  --       end
  --     else
  --       if editor.uiIconImageButton(additionalMenuItems[v].icon, nil, nil, nil, im.ImColorByRGB(0,0,0,255).Value) then
  --         if additionalMenuItems[v].value[0]==true then additionalMenuItems[v].value[0]=false else additionalMenuItems[v].value[0]=true end
  --       end
  --     end
  --     if im.IsItemHovered() then im.tooltip(additionalMenuItems[v].name) end
  --   end
  -- end
end


--------------------------------
-- track builder functions -----
--------------------------------

-- moved the cursor by a given amount.
tbFunctions.navigate = function(off)
  if off == 1 then
    currentIndex = currentIndex+1
    if currentIndex > #tb.getPieceInfo().pieces then currentIndex = 1  end
  elseif off == -1 then
    currentIndex = currentIndex-1
    if currentIndex <= 0 then currentIndex = #tb.getPieceInfo().pieces  end
  elseif off == 'first' then
    currentIndex = 1
  elseif off == 'last' then
    currentIndex = #tb.getPieceInfo().pieces
  end
    tb.focusMarkerOn(currentIndex)
    tbFunctions.refreshPieceInfo()
end

-- reads all the infos of the current piece, including modifiers.
tbFunctions.refreshPieceInfo = function()
  tbFunctions.refreshTrackPositionRotation()
  currentCheckpointList = tb.getAllCheckpoints()
  local piece = tb.getSelectedTrackInfo()
  --dump(piece)
  local info = piece.parameters
  if not info then return end
  if info.piece ~= 'init' then
    local found = false
    for nm, pc in pairs(pieceInfo.free) do
      if pc.piece == info.piece then
        for key, val in pairs(pc) do
          if key ~= 'piece' then
            val[0] = info[key]
          end
        end
        currentPieceName = pc.piece
      end
    end
  end

  for key, mod in pairs(modifierValues) do
    if not mod.noFill then
      if mod.forceFill then
        mod.fillerFunction(mod,piece[key])
      else
        local lastPiece = tb.getLastPieceWithMarker(key, currentIndex)

        if lastPiece then
          mod.fillerFunction(mod,lastPiece[key])
        end
      end
    end
  end
end

-- attempts to delete a piece.
tbFunctions.pieceDeleted = function()
  if currentIndex > 2 then
    tb.removeAt(currentIndex)
    tb.makeTrack()
    currentIndex = currentIndex-1
    tb.focusMarkerOn(currentIndex)
    tbFunctions.refreshPieceInfo()
  end
end

-- called when a parameter of a piece is changed.
tbFunctions.pieceUpdated = function(replace)
  if replace == nil then
    if im.GetIO().KeyCtrl then
      replace = true
    elseif  im.GetIO().KeyShift then
      replace = false
    else
      currentIndex = #tb.getPieceInfo().pieces
      replace = false
    end
  end
  if currentIndex == 1 then return end
  local params = {}

  for nm, pc in pairs(pieceInfo.free) do
    if pc.piece == currentPieceName then
      for key, val in pairs(pc) do
        if key ~= 'piece' then
          params[key] = val[0]
        end
      end
      params.piece = pc.piece
    end
  end
  local closedBefore = tb.getPieceInfo().trackClosed

  tb.addPiece(params,currentIndex + (replace and 0 or 1),replace)
  tb.makeTrack()
  if not replace then
    currentIndex = currentIndex+1
  end
  if not closedBefore and tb.getPieceInfo().trackClosed then
    currentIndex = 1
  end
  tb.focusMarkerOn(currentIndex)
  tbFunctions.refreshPieceInfo()
end

-- called after a modifier is changed.
tbFunctions.modifierChange = function(field)
  local v = modifierValues[field].valueFunction(modifierValues[field])
  tb.markerChange(field,currentIndex,v)
  tb.makeTrack()
  tb.focusMarkerOn(currentIndex)
end

-- called when a modifier is removed.
tbFunctions.modifierRemove = function(field)
  tb.markerChange(field,currentIndex,nil)
  tb.makeTrack()
  tb.focusMarkerOn(currentIndex)
end

-- shifts a modifier forward or backward.
tbFunctions.modifierShift = function(name,offset)
  tb.markerChange(name,currentIndex,nil)
  if offset == 1 then
    currentIndex = currentIndex+1
    if currentIndex > #tb.getPieceInfo().pieces then currentIndex = 1  end
  elseif offset == -1 then
    currentIndex = currentIndex-1
    if currentIndex <= 0 then currentIndex = #tb.getPieceInfo().pieces  end
  end
  local v = modifierValues[name].valueFunction(modifierValues[name])
  tb.markerChange(name, currentIndex,v)
  tb.makeTrack()
  tb.focusMarkerOn(currentIndex)
  tbFunctions.refreshPieceInfo()
end

-- starts the drive mode.
tbFunctions.drive = function(index)
  driving = true
  materialSettings.groundModelHasChanged = false
  tb.setHighQuality(true)
  tb.makeTrack(true)
  tb.showMarkers(false)
  tb.unselectAll()
  tb.refreshAllMaterials()
  be:resetVehicle(0)
  tb.positionVehicle(false,index)
  guihooks.trigger('ShowApps', true)
  commands.setGameCamera()
end

-- ends the drive mode.
tbFunctions.unDrive = function()
  commands.setFreeCamera()
  tb.showMarkers(true)
  tb.focusMarkerOn(currentIndex)
  tbFunctions.refreshPieceInfo()
  selectMode("Select")
  guihooks.trigger('ShowApps', false)
end

-- refreshes the track position and rotation.
tbFunctions.refreshTrackPositionRotation = function()
  local vals = tb.getTrackPosition()
  trackPositionValues.position[0] = vals.x
  trackPositionValues.position[1] = vals.y
  trackPositionValues.position[2] = vals.z
  trackPositionValues.rotation[0] = -vals.hdg / math.pi * 180
end

tbFunctions.switchSubTrack = function(index)
  tb.setAllPiecesHighQuality()
  tb.unselectAll()
  tb.refreshAllMaterials()
  tb.switchSubTrack(index)
  subTrackIndex[0] = index
  tb.makeTrack(true)
  currentIndex = #tb.getPieceInfo().pieces
  tb.focusMarkerOn(currentIndex)
  tbFunctions.refreshPieceInfo()
  tbFunctions.refreshTrackPositionRotation()
end

tbFunctions.mergeMultiTrack = function(segments)
  tb.mergeMultiTrack(segments)
end


---------------------------------------------------
-- Filler Functions for Modifiers, Obstacles etc --
---------------------------------------------------

local function fillInterpolateable(from, to)
  from.value[0] = to.value
  from.interpolation[0] = indexOf(interpolationsTbl,to.interpolation)-1
  from.inverted[0] = to.inverted or false
  if from.customSlope ~= nil then
    from.customSlope[0] = to.customSlope ~= nil
    from.customSlopeValue[0] = from.customSlope[0] and to.customSlope or from.customSlopeValue[0]
  end
end

local function fillMesh(from, to)
  from.value[0] = indexOf(from.table, to or 'regular')-1
end

local function fillWall(from, to)
  from.value[0] = to.value or 0
  from.active[0] = to.active or false
  from.interpolation[0] = indexOf(interpolationsTbl,to.interpolation)-1
  from.inverted[0] = to.inverted or false
end

local function fillCheckpoint(from, to)
  if not to then
    from.position[0] = 0
    from.position[1] = 0
    from.position[2] = 0
    from.size[0] = 4
    from.active[0] = false
  else
    from.position[0] = to.position.x
    from.position[1] = to.position.y
    from.position[2] = to.position.z
    from.size[0] = to.size
    from.active[0] = true
  end
end

local function fillObstacles(from, to)
  for i = 1, 10 do
    if not to or not to[i] then
      from.list[i].value[0] = 0
      from.list[i].variant[0] = 1
      from.list[i].offset[0] = 1
      from.list[i].anchor[0] = 1
      from.list[i].position[0] = 0
      from.list[i].position[1] = 0
      from.list[i].position[2] = 0
      from.list[i].scale[0] = 1
      from.list[i].scale[1] = 1
      from.list[i].scale[2] = 1
      from.list[i].extra[0] = 1
      from.list[i].extra[1] = 1
      from.list[i].extra[2] = 1
      from.list[i].rotation[0] = 0
      from.list[i].rotation[1] = 0
      from.list[i].rotation[2] = 0
      from.list[i].active = false
      from.list[i].material[0] = 0
    else
      local name = string.match(to[i].value,"%l+")
      from.list[i].value[0] = indexOf(obstaclesTbl,name)-1
      from.list[i].variant[0] = to[i].variant or 1
      from.list[i].offset[0] = to[i].offset or 1
      from.list[i].anchor[0] = to[i].anchor or 1
      from.list[i].position[0] = to[i].position.x or 0
      from.list[i].position[1] = to[i].position.y or 0
      from.list[i].position[2] = to[i].position.z or 0
      from.list[i].scale[0] = to[i].scale.x or 1
      from.list[i].scale[1] = to[i].scale.y or 1
      from.list[i].scale[2] = to[i].scale.z or 1
      from.list[i].extra[0] = to[i].extra.x or 1
      from.list[i].extra[1] = to[i].extra.y or 1
      from.list[i].extra[2] = to[i].extra.z or 1
      from.list[i].rotation[0] = to[i].rotationEuler.x or 0
      from.list[i].rotation[1] = to[i].rotationEuler.y or 0
      from.list[i].rotation[2] = to[i].rotationEuler.z or 0
      from.list[i].material[0] = indexOf(obstacleMatNames,to[i].material)-1
      from.list[i].active = true
    end
  end
end

local function fillMaterials( to)
  if not to then return end
  for name, mat in pairs(materials.materialInfo) do
    mat.value[0] = indexOf(materials[mat.table].matNames,to[name])-1
  end
end

local function interpolateableValue(from)
  return {
    value = from.value[0],
    interpolation = interpolationsTbl[from.interpolation[0]+1],
    inverted = from.inverted[0],
    customSlope = from.customSlope ~= nil and from.customSlope[0] and from.customSlopeValue[0] or nil,
  }
end

local function checkpointValue(from)
  if not from.active[0] then return nil end
  return {
    size = from.size[0],
    position = {x = from.position[0], y=from.position[1], z = from.position[2]}
  }
end

local function wallValue(from)
  return {
    value = from.value[0],
    active = from.active[0],
    inverted = from.inverted[0],
    interpolation = interpolationsTbl[from.interpolation[0]+1]
  }
end

local function obstacleValue(from)
  local obstacles = {}
  for i, o in ipairs(from.list) do
    if o.active then
      obstacles[#obstacles+1] = {
        value = obstaclesTbl[o.value[0]+1],
        variant = obstacleInfo[obstaclesTbl[o.value[0]+1]].variants and o.variant[0] or 1,
        position = vec3(o.position[0],o.position[1],o.position[2]),
        scale = vec3(o.scale[0],o.scale[1],o.scale[2]),
        extra = vec3(o.extra[0],o.extra[1],o.extra[2]),
        rotation = quatFromEuler(o.rotation[0]/180 * math.pi,o.rotation[1]/180 * math.pi,(o.rotation[2])/180 * math.pi),
        rotationEuler = vec3(o.rotation[0],o.rotation[1],o.rotation[2]),
        offset = o.offset[0],
        anchor = o.anchor[0],
        material = obstacleMatNames[o.material[0]+1]
      }
    end
  end
  return obstacles
end

modifierValues.bank.valueFunction   = interpolateableValue
modifierValues.bank.fillerFunction  = fillInterpolateable
modifierValues.width.valueFunction  = interpolateableValue
modifierValues.width.fillerFunction  = fillInterpolateable
modifierValues.height.valueFunction = interpolateableValue
modifierValues.height.fillerFunction  = fillInterpolateable

modifierValues.leftMesh.fillerFunction = fillMesh
modifierValues.leftMesh.forceFill = true
modifierValues.centerMesh.fillerFunction  = fillMesh
modifierValues.centerMesh.forceFill = true
modifierValues.rightMesh.fillerFunction = fillMesh
modifierValues.rightMesh.forceFill = true

modifierValues.checkpoint.valueFunction = checkpointValue
modifierValues.checkpoint.fillerFunction = fillCheckpoint
modifierValues.checkpoint.forceFill = true

modifierValues.leftWall.valueFunction = wallValue
modifierValues.leftWall.fillerFunction = fillWall
modifierValues.rightWall.valueFunction = wallValue
modifierValues.rightWall.fillerFunction = fillWall
modifierValues.ceilingMesh.valueFunction = wallValue
modifierValues.ceilingMesh.fillerFunction = fillWall

modifierValues.obstacles.valueFunction = obstacleValue
modifierValues.obstacles.fillerFunction = fillObstacles
modifierValues.obstacles.forceFill = true

local function setupUIStyle()
  if isOnGlowCity then
    style.textColor = im.ImVec4(0.3, 0.3, 1, 1.0)
    style.buttonColorBase = im.ImVec4(0.2,0.2,0.2,1.0)
    style.buttonColorBG = im.ImVec4(0.9,0.9,0.9,1)
    style.buttonColorBGSelected = im.ImVec4(170/255,204/255,244/255,1)
    style.selectedPieceColor = im.ImVec4(1, 0.9,0.25, 1.0)
    style.colorYellow, style.colorRed, style.colorGreen = im.ImVec4(0.6,0.5,0,1),im.ImVec4(0.8,0,0,1),im.ImVec4(0,0.5,0,1)
    im.StyleColorsLight(im.GetStyle())
  else
    style.textColor = im.ImVec4(1.0, 1.0, 0.0, 1.0)
    style.buttonColorBase = im.ImVec4(0.9,0.9,0.9,1.0)
    style.buttonColorBG = im.ImVec4(0.3,0.3,0.3,1)
    style.buttonColorBGSelected = im.ImVec4(35/255,68/255,108/255,1)
    style.selectedPieceColor = im.ImVec4(0.5, 0.75, 1, 1.0)
    style.colorYellow, style.colorRed, style.colorGreen = im.ImVec4(1,1,0,1),im.ImVec4(1,0,0,1),im.ImVec4(0,1,0,1)

    Engine.imgui.enableBeamNGStyle()
  end
  local stle = ffi.new("ImGuiStyle[1]")
  im.GetStyle(stle)
  stle[0].FrameBorderSize = im.Float(1.0)
  --im.SetStyle(stle)
end

local function onWindowResized(size)
  style.displaySize = {x=size.x, y=size.y}
end

local function initialize()
  initialized = true
  screenshot = require("screenshot")
  guiModule.initialize(editor)
  saveSettings = {
    saveOnMap = im.BoolPtr(true),
    saveEnvironment = im.BoolPtr(true),
    lapCount = im.IntPtr(2),
    allowReverse = im.BoolPtr(false),
    trackNames = nil,
    previewNames = nil,
    saveStr = im.ArrayChar(128),
    infoText = "",
    description = im.ArrayChar(256*16),
    difficulty = im.IntPtr(1),
    timeOfDay = im.FloatPtr(0),
    fogValue = im.FloatPtr(0),
    azimuthValue = im.FloatPtr(0)
  }

  paintModes = {
    Select = {tooltip=translateLanguage("ui.trackBuilder.toolbar.select", "Select segment"), active=im.BoolPtr(true), icon=editor.icons.near_me},
    Paint = {tooltip=translateLanguage("ui.trackBuilder.toolbar.paint", "Paint material"), active=im.BoolPtr(false), icon=editor.icons.brush},
    ChangeMesh = {tooltip=translateLanguage("ui.trackBuilder.toolbar.changeShape", "Change track shapes"), active=im.BoolPtr(false), icon=editor.icons['tb_shapes'] or editor.icons.stop},
    Merge = {tooltip=translateLanguage("ui.trackBuilder.toolbar.merge", "Merge"), active=im.BoolPtr(false), icon=editor.icons.extension},
  }

  --TODO: this must be done everytime level changed? since scenetree will be different
  for i, matName in pairs(materials.matNames) do
    table.insert( materialSettings.materials.center, scenetree.findObject(matName .. 'center') )
    table.insert( materialSettings.materials.border, scenetree.findObject(matName .. 'border') )
    obstacleMatNames[#obstacleMatNames+1] = matName..'border'
    obstacleMatNames[#obstacleMatNames+1] = matName..'center'
  end

  if not scenetree.trackBuilder_PersistMan then
    local persistenceMgr = PersistenceManager()
    persistenceMgr:registerObject('trackBuilder_PersistMan')
  end

  materialSettings.nullMat = editor.texObj("")
  menuItems = {
    advancedModifiers = {
      name = translateLanguage("ui.trackBuilder.menus.advancedModifiers", "Advanced Modifiers"),
      isOpen = im.BoolPtr(false), wasOpen = false, size = im.ImVec2(280,0), icon = editor.icons.adjust
    },
    advancedPieces = {
      name = translateLanguage("ui.trackBuilder.menus.advancedPieces", "Advanced Pieces"),
      isOpen = im.BoolPtr(false), wasOpen = false, size = im.ImVec2(280,0), icon = editor.icons['tb_loop'] or editor.icons.stop
    },
    borders = {
      name = translateLanguage("ui.trackBuilder.menus.trackShape", "Track Shape"),
      isOpen = im.BoolPtr(false), wasOpen = false, size = im.ImVec2(280,0), icon = editor.icons['tb_shapes'] or editor.icons.stop,
      onOpenFunction = onBordersAndCentersOpened, onCloseFunction = onBordersAndCentersClosed
    },
    sidewalls = {
      name =translateLanguage("ui.trackBuilder.menus.wallsCeiling", "Walls and Ceiling"),
      isOpen = im.BoolPtr(false), wasOpen = false, size = im.ImVec2(280,0), icon = editor.icons['tb_tunnel'] or editor.icons.stop
    },
    obstacles = {
      name = translateLanguage("ui.trackBuilder.menus.obstacles", "Obstacles"),
      isOpen = im.BoolPtr(false), wasOpen = false, size = im.ImVec2(280,504), icon = editor.icons.remove_circle_outline
    },
    materialEditor = {
      name = translateLanguage("ui.trackBuilder.menus.materialEditor", "Material Editor"),
      isOpen = im.BoolPtr(false), wasOpen = false, size = im.ImVec2(280,0), icon = editor.icons.brush,
      onOpenFunction = onMaterialEditorOpened, onCloseFunction = onMaterialEditorClosed
    },
    --[[
    subTracks = {
      name = 'SubTrack',
      isOpen = im.BoolPtr(true), wasOpen = false, size = im.ImVec2(280,0), icon = editor.icons.extension,
      onCloseFunction = onSubTracksClosed
    }]]

  }
  additionalMenuItems = {
    checkpoints = {name = translateLanguage("ui.trackBuilder.menus.checkpoints", "CheckPoints"), isOpen = im.BoolPtr(false), wasOpen = false, size = im.ImVec2(280,0), icon = editor.icons.flag},
    postionrotation = {name = translateLanguage("ui.trackBuilder.menus.trackSettings", "Track Settings"),  isOpen = im.BoolPtr(false), wasOpen = false, size = im.ImVec2(280,0), icon = editor.icons.settings},
    saveload = {name= translateLanguage("ui.trackBuilder.menus.saveLoad", "Save and Load"),isOpen = im.BoolPtr(false), wasOpen = false, size = im.ImVec2(280,420), icon = editor.icons.save},
    --debug = {name = 'debug', value = im.BoolPtr(false), icon = editor.icons.bug_report}
  }

  menuItemsSorted = tableKeys(menuItems)
  table.sort(menuItemsSorted)
  additionalMenuItemsSorted = tableKeys(additionalMenuItems)
  table.sort(additionalMenuItemsSorted)

  menuItems.borders.functionName = bordersAndCenters
  --menuItems.materialWindow.functionName = materialWindow
  menuItems.sidewalls.functionName = wallsAndCeiling
  menuItems.obstacles.functionName = addObstacles
  menuItems.advancedPieces.functionName = advancedPieces
  menuItems.advancedModifiers.functionName = advancedModifiers
  menuItems.materialEditor.functionName = materialEditor
  --menuItems.subTracks.functionName = subTracks

  additionalMenuItems.saveload.functionName = saveAndLoad
  additionalMenuItems.postionrotation.functionName = generalSettings
  additionalMenuItems.checkpoints.functionName = checkPoints

  setupMaterials()
  updateMaterialFields()

  isOnGlowCity = core_levels.getLevelName(getMissionFilename()) =='glow_city'
  -- editor.editModes.trackBuilderEditMode = {
  --   onActivate = trackBuilderEditModeActivate,
  --   onDeactivate = trackBuilderEditModeDeactivate,
  --   onUpdate = trackBuilderEditModeUpdate,
  --   -- onToolbar = trackBuilderEditModeToolbar,
  --   onToolbar = nil,
  --   actionMap = "trackBuilder", -- if available, not required
  --   -- icon = editor.icons.bug_report,
  --   icon = nil,
  --   iconTooltip = "trackBuilder"
  -- }

  local imguiIO = im.GetIO(imguiIO)
  if not style.displaySize then style.displaySize = {x=imguiIO.DisplaySize.x, y=imguiIO.DisplaySize.y} end
  deserializeSettings()
  --if tb == nil then
  --  tb = extensions['util_trackBuilder_splineTrack']
  --  tb.setHighQuality(true)
  --end

  -- TODO is this still needed ? ui scale is set in preferences.lua on after prefs load
  -- local imguiUtils = require('ui/imguiUtils')
  -- imguiUtils.changeUIScale(1)
  -- imguiUtils = nil
  local style = ffi.new('ImGuiStyle[1]')
  im.GetStyle(style)
end

local function showTrackBuilderWindow(show)
  if not initialized then
    initialize()
  end

  if tb == nil then
    tb = extensions['util_trackBuilder_splineTrack']
    tb.setHighQuality(true)
    tb.camDistance = menuSettings.camDistance.value[0]
    tb.camActivated = menuSettings.camActivated.value[0]
  end
  open[0] = show
  if show then
    setupUIStyle()
    guihooks.trigger('ShowApps', false)
    if isOnGlowCity then
      setupTrack()

    end
  end
  if not show then
    tb.unselectAll()
    tb.refreshAllMaterials()
    tb.showMarkers(false)
    guihooks.trigger('ShowApps', true)
    trackSpawned = false
    if not isOnGlowCity and #tb.getPieceInfo().pieces <= 2 then
      tb.removeTrack()
      open[0] = false
    end
  end
end

local function showTrackBuilder()
  local freeCam = commands.isFreeCamera()
  if not freeCam then
    commands.setGameCamera()
  end
  M.showTrackBuilderWindow(true)
end

local function hideTrackBuilder()
  if not initialized then return end

  M.showTrackBuilderWindow(false)

  Engine.imgui.enableBeamNGStyle()

  initialized = false
  tb = nil
end


local function toggleTrackBuilder()
  local freeCam = commands.isFreeCamera()
  if not freeCam and active then
    commands.setGameCamera()
  end
  local active = open[0]
  showTrackBuilderWindow(not active)
  if active then
    extensions.hook("stopTracking", {Name = "TrackBuilder"})
  else
    extensions.hook("startTracking", {Name = "TrackBuilder"})
  end
end


M.showTrackBuilder = showTrackBuilder
M.hideTrackBuilder = hideTrackBuilder
M.toggleTrackBuilder = toggleTrackBuilder

M.showTrackBuilderWindow = showTrackBuilderWindow
M.onWindowResized = onWindowResized
M.onUpdate = onUpdate
M.onClientEndMission = hideTrackBuilder

return M