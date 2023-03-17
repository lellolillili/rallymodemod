-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui
local _idCounter = 0
local C = {}
local imVec24x24 = im.ImVec2(24,24)
local imVec16x16 = im.ImVec2(16,16)
local imVec4Red = im.ImVec4(1,0,0,1)
local imVec4Yellow = im.ImVec4(1,1,0,1)
local imVec4Green = im.ImVec4(0,1,0,1)
local imVec4TransparentWhite = im.ImVec4(1,1,1,0.25)
local hoveredElement
local columnWidth = 150



function C:addCustomElement(label, getNewFunction, setMissionFunction, drawFunction)
  return self:addElement({type = 'custom', label = label, getNewFunction = getNewFunction or nop, setMissionFunction = setMissionFunction or nop, drawFunction = drawFunction or nop})
end
function C:addNumeric(label, fieldName, defaultValue, displayOptions)
  defaultValue = defaultValue or 0
  return self:addElement({type = 'numeric', label = label, fieldName = fieldName, defaultValue = defaultValue, ptr = im.FloatPtr(defaultValue), displayOptions = displayOptions})
end
function C:addString(label, fieldName, defaultValue, len, displayOptions)
  defaultValue = defaultValue or ""
  len = len or 1024
  return self:addElement({type = 'string', label = label, fieldName = fieldName, defaultValue = defaultValue, ac = im.ArrayChar(len, defaultValue), len = len , displayOptions = displayOptions})
end

function C:addBool(label, fieldName, defaultValue, hideElementList, displayOptions)
  defaultValue = defaultValue or false
  local elem = self:addElement({type = 'bool', label = label, fieldName = fieldName, defaultValue = defaultValue, ptr = im.BoolPtr(defaultValue) , displayOptions = displayOptions})

  if hideElementList then
    elem.valueChangedCallback  = function(e)
      for _, element in ipairs(hideElementList) do
        element.hidden = not e.ptr[0]
      end
    end
    -- move hideElement list to after the elem
    for _, e in ipairs(hideElementList) do
      local idx = arrayFindValueIndex(self.elements, e)
      if idx then
        table.remove(self.elements, idx)
        self:addElement(e)
      end
    end
  end
  return elem
end

--function C:addTransform(label, fieldName, {defaultPos, defaultRot, defaultScl, hasPos, hasRot, hasScl, oneDimScale}, {drawMode, drawColor, ...})
function C:addTransform(label, fieldName, valueOptions, displayOptions)
  valueOptions = valueOptions or {}
  displayOptions = displayOptions or {}
  local elem = {type = 'transform', label = label, fieldName = fieldName, displayOptions = displayOptions}
  elem.drawMode = displayOptions.drawMode or "sphere" -- 'vehicle', 'sphereDir', 'halfBox', 'fullBox'
  elem.drawColor = displayOptions.drawColor or {1,0.25,0,0.5}
  elem.defaultPos = valueOptions.defaultPos or vec3()
  elem.defaultRot = valueOptions.defaultRot or quat(0,0,0,1)

  if valueOptions.oneDimScale == nil and valueOptions.defaultScl then valueOptions.oneDimScale = type(valueOptions.defaultScl)=='number' end
  elem.oneDimScale = valueOptions.oneDimScale or false
  elem.defaultScl = valueOptions.defaultScl or (elem.oneDimScale and 1 or vec3(1,1,1))
  if valueOptions.hasPos == nil and valueOptions.defaultPos then valueOptions.hasPos = true end
  if valueOptions.hasRot == nil and valueOptions.defaultRot then valueOptions.hasRot = true end
  if valueOptions.hasScl == nil and valueOptions.defaultScl then valueOptions.hasScl = true end

  elem.hasPos = (valueOptions.hasPos == nil and true) or valueOptions.hasPos or false
  elem.hasRot = (valueOptions.hasRot == nil and true) or valueOptions.hasRot or false
  elem.hasScl = (valueOptions.hasScl == nil and true) or valueOptions.hasScl or false
  elem.transform = require('/lua/ge/extensions/editor/util/transformUtil')(elem.label, elem.label)
  elem.transform.allowTranslate = elem.hasPos
  elem.transform.allowRotate = elem.hasRot
  elem.transform.allowScale = elem.hasScl
  elem.transform:setOneDimensionalScale(elem.oneDimScale)
  elem.transform:set(elem.defaultPos, elem.defaultRot, elem.defaultScl)
  elem.fieldNamePos = elem.fieldName .. 'Pos'
  elem.fieldNameRot = elem.fieldName .. 'Rot'
  elem.fieldNameScl = elem.fieldName .. 'Scl'
  elem.switchRotation = true -- rotate by 180 degrees

  elem.clickable = true

  return self:addElement(elem)
end



--function C:addModelConfig(label, fieldName, defaultModel, defaultConfig)
function C:addModelConfig(label, fieldName, defaultModel, defaultConfig, displayOptions)
  local elem = {type = 'modelconfig', label = label, fieldName = fieldName, displayOptions = displayOptions}
  elem.defaultModel = defaultModel or "sbr"
  elem.defaultConfig = defaultConfig or "TT_RWD_S_M"
  elem.defaultConfigPath = "/vehicles/"..elem.defaultModel.."/"..elem.defaultConfig..'.pc'
  elem.mc = {model = elem.defaultModel, config = elem.defaultConfig, configPath = elem.defaultConfigPath}
  elem.fieldNameModel = fieldName.."Model"
  elem.fieldNameConfig = fieldName.."Config"
  elem.fieldNameConfigPath = fieldName.."ConfigPath"
  return self:addElement(elem)
end
function C:addFile(label, fieldName, defaultValue, allowedExtensions, displayOptions)
  defaultValue = defaultValue or ""
  local fileTags = {}
  for _, e in ipairs(allowedExtensions or {}) do
    local dir, fn, ext = path.split(e[2], true)
    fileTags[ext] = true
  end
  return self:addElement({type = 'file', label = label, fieldName = fieldName, defaultValue = defaultValue, ac = im.ArrayChar(1024,defaultValue) , len = 1024, fileTags = fileTags, displayOptions = displayOptions})
end
function C:addFixedFile(label, filepathsInMissionfolder, displayOptions)
  local fileTags = {}
  -- filepath can be a table, allowing for one of the files to be required
  if type(filepathsInMissionfolder) == 'string' then
    filepathsInMissionfolder = {filepathsInMissionfolder}
  end
  for _, file in ipairs(filepathsInMissionfolder) do
    local dir, fn, ext = path.split(file, true)
    fileTags[ext] = file
  end
  return self:addElement({type = 'fixedFile', label = label, filepathsInMissionfolder = filepathsInMissionfolder, foundFile = nil, displayOptions = displayOptions, fileTags = fileTags})
end
function C:addRace(label, fieldName, defaultValue, ...)
  local elem = self:addFile(label, fieldName, defaultValue, {{"Racepath File","*.path.json"}}, ...)
  elem.type = 'race'
  return elem
end
function C:addSimpleLapConfig(label, fieldName, displayOptions)
  local elem = {type = 'simpleLapConfig', label = label, fieldName = fieldName, displayOptions = displayOptions, defaultValue = {}}
  elem.lapConfig = require('/lua/ge/extensions/editor/util/lapConfigUtil')(elem.label, elem.label)
  return self:addElement(elem)
end

function C:addSites(label, fieldName, defaultValue)
  local elem = self:addFile(label, fieldName, defaultValue, {{"Sites File","*.sites.json"}})
  elem.type = 'sites'
  return elem
end
function C:addLeaderboard(label, fieldName, defaultCount, defaultBest, defaultMedium, defaultWorst)
  local elem = {type = 'leaderboard', label = label, fieldName = fieldName}
  elem.defaultCount = defaultCount or 10
  elem.defaultBest = defaultBest or 80
  elem.defaultMedium = defaultMedium or 120
  elem.defaultWorst = defaultWorst or 200

  elem.fieldNameCount = fieldName .. "Count"
  elem.fieldNameBest = fieldName.."BestResult"
  elem.fieldNameMedium = fieldName.."MediumResult"
  elem.fieldNameWorst = fieldName.."WorstResult"

  elem.count = im.IntPtr(elem.defaultCount)
  elem.best = im.FloatPtr(elem.defaultBest)
  elem.medium = im.FloatPtr(elem.defaultMedium)
  elem.worst = im.FloatPtr(elem.defaultWorst)

  elem.fixedCount = false
  return self:addElement(elem)
end
function C:addReward(label, fieldName, defaultValue)
  local e = self:addNumeric(label, fieldName, defaultValue)
  e.type = 'reward'
  return e
end
function C:addDropdown(label, fieldName, values, defaultValue, valueTooltips)
  local elem = {type = 'dropdown', label = label, fieldName = fieldName}
  values = values or {}
  if #values == 0 then values = {'issues Values!'} end
  elem.values = values
  elem.defaultValue = defaultValue or values[1]
  elem.valueTooltips = valueTooltips or {}
  return self:addElement(elem)
end

function C:addMissionId(label, fieldName, defaultValue, displayOptions)
  defaultValue = defaultValue or "(none)"
  return self:addElement({type = 'missionId', label = label, fieldName = fieldName, value = defaultValue, defaultValue = defaultValue , displayOptions = displayOptions})
end



-- decorators
local defaultColors = {
  default = im.ImVec4(1,0.6,0,8,0.75),
  orange = im.ImVec4(1,0.6,0,8,0.75),
  red = im.ImVec4(1,0,0,8,0.75),
  green = im.ImVec4(0,1,0,0.75),
  blue = im.ImVec4(0,0,1,0.75),
  white = im.ImVec4(1,1,1,0.75),
  black = im.ImVec4(0,0,0,0.75),
}
function C:addDecoHeader(text, color) return self:addElement({type = 'decoHeader', text = text or "", color = defaultColors[color or 'default'] or defaultColors['default']}) end
function C:addDecoText(text, tooltip) return self:addElement({type = 'decoText', text = text or "", tooltip = tooltip}) end
function C:addDecoSeparator() return self:addElement({type = 'decoSeparator'}) end
function C:addDecoSpacer() return self:addElement({type = 'decoDummy', height = 4}) end
function C:addDecoDummy(height) return self:addElement({type = 'decoDummy', height = height or 1}) end
function C:addElement(element)
  element._id = _idCounter
  _idCounter = _idCounter+1
  element.displayOptions = element.displayOptions or {}
  if element.displayOptions.associatedStars and type(element.displayOptions.associatedStars) == 'string' then
    local key = element.displayOptions.associatedStars
    element.displayOptions.associatedStars = {}
    element.displayOptions.associatedStars[key] = true
  end
  table.insert(self.elements, element)
  return element
end

function C:clear()
  table.clear(self.elements)
end



------------- new data functions ---------------

local function customGetNewData(e) return e.getNewFunction(e) end
local function defaultValueGetNewData(e) return {{fieldName = e.fieldName, value = deepcopy(e.defaultValue)}} end
local function transformGetNewData(e)
  return {
    {fieldName = e.fieldName.."Pos", value = e.hasPos and e.defaultPos:toTable()},
    {fieldName = e.fieldName.."Rot", value = e.hasRot and e.defaultRot:toTable()},
    {fieldName = e.fieldName.."Scl", value = e.hasScl and (e.oneDimScale and e.defaultScl or e.defaultScl:toTable())},
  }
end
local function modelConfigGetNewData(e) return
  {
    {fieldName = e.fieldNameModel, value = e.defaultModel},
    {fieldName = e.fieldNameConfig, value = e.defaultConfig},
    {fieldName = e.fieldNameConfigPath, value = e.defaultConfigPath}
  }
end
local function leaderboardGetNewData(e) return {
  {fieldName = e.fieldNameBest, value = e.defaultBest},
  {fieldName = e.fieldNameMedium, value = e.defaultMedium},
  {fieldName = e.fieldNameWorst, value = e.defaultWorst}
} end
local newDataFunctions = {
  custom = customGetNewData,
  numeric = defaultValueGetNewData,
  string = defaultValueGetNewData,
  bool = defaultValueGetNewData,
  transform = transformGetNewData,
  modelconfig = modelConfigGetNewData,
  file = defaultValueGetNewData,
  race = defaultValueGetNewData,
  sites = defaultValueGetNewData,
  leaderboard = leaderboardGetNewData,
  reward = defaultValue,
  dropdown = defaultValue,
  simpleLapConfig = defaultValue,
  missionId = defaultValue,
}
function C:getNewData()
  local ret = {}
  -- gather all default fields for all self:elements
  for _, element in ipairs(self.elements) do
    for _, val in ipairs((newDataFunctions[element.type] or nop)(element) or {}) do
      ret[val.fieldName] = val.value
    end
  end
  return ret
end

function C:checkMission(m, fix)
  self.mission = m
  local mtd = m.missionTypeData
  local issues = {}
  for _, element in ipairs(self.elements) do
    for _, val in ipairs((newDataFunctions[element.type] or nop)(element) or {}) do
      if mtd[val.fieldName] == nil then
        table.insert(issues, {type = 'Missing Missiontype Value: ' .. val.fieldName, data = val})
      end
    end
  end
  if fix then
    for _, val in ipairs(issues) do
      mtd[val.data.fieldName] = val.data.value
    end
    if #issues > 0 then
      m._dirty = true
    end
  end
  return issues
end



------------ set mission functions ----------------
local function customSetMission(e, mtd) e.setMissionFunction(e, mtd) end
local function numericSetMission(e, mtd) e.ptr[0] = mtd[e.fieldName] or e.defaultValue end
local function stringSetMission(e, mtd) e.ac = im.ArrayChar(e.len, mtd[e.fieldName] or e.defaultValue) e._translated = nil end
local function boolSetMission(e, mtd) if mtd[e.fieldName] == nil then e.ptr[0] = e.defaultValue else e.ptr[0] = mtd[e.fieldName] end end
local function transformSetMission(e, mtd) e.transform:set(vec3(mtd[e.fieldNamePos] or e.defaultPos), quat(mtd[e.fieldNameRot] or e.defaultRot), e.oneDimScale and (mtd[e.fieldNameScl] or e.defaultScl) or (vec3(mtd[e.fieldNameScl] or e.defaultScl))) end
local function modelConfigSetMission(e, mtd) e.mc.model = mtd[e.fieldNameModel] or e.defaultModel e.mc.config = mtd[e.fieldNameConfig] or e.defaultConfig e.mc.configPath = mtd[e.fieldNameConfigPath] or e.defaultConfigPath ui_flowgraph_editor.vehicleSelectorRefresh(e.mc) end
local function fileSetMission(e, mtd) stringSetMission(e, mtd) e.foundFile = nil end
local function fixedFileSetMission(e, mtd) e.foundFile= nil end
local function leaderboardSetMission(e, mtd) e.best[0] = mtd[e.fieldNameBest] or e.defaultBest e.medium[0] = mtd[e.fieldNameMedium] or e.defaultMedium e.worst[0] = mtd[e.fieldNameWorst] or e.defaultWorst e.count[0] = mtd[e.fieldNameCount] or e.defaultCount end
local function simpleLapConfigSetMission(e, mtd) e.lapConfig:set(mtd[e.fieldName] or deepcopy(e.defaultPos)) end
local function missionIdSetMission(e, mtd) e.value = mtd.value or e.defaultValue end
local setMissionFuntions = {
  custom = customSetMission,
  numeric = numericSetMission,
  string = stringSetMission,
  bool = boolSetMission,
  transform = transformSetMission,
  modelconfig = modelConfigSetMission,
  file = fileSetMission,
  fixedFile = fixedFileSetMission,
  race = fileSetMission,
  sites = fileSetMission,
  leaderboard = leaderboardSetMission,
  reward = numericSetMission,
  simpleLapConfig = simpleLapConfigSetMission,
  missionId = missionIdSetMission,
}
function C:setMission(m)
  self.mission = m
  for _, element in ipairs(self.elements) do
    (setMissionFuntions[element.type] or nop)(element, m.missionTypeData)
    if element.valueChangedCallback then element:valueChangedCallback(self.mission.missionTypeData) end
  end
end




C.setMissionBaseFunction = C.setMission

local whiteColorF = ColorF(1,1,1,1)
local blackColorI = ColorI(0,0,0,192)
----------- drawing helper functions ---------------
local function label(e)
  im.Columns(2) im.SetColumnWidth(0,columnWidth)
  im.TextWrapped(e.label)
  if e.displayOptions.tooltip then
    im.tooltip(e.displayOptions.tooltip)
  end
  if e.displayOptions.associatedStars then
    im.SameLine()
    editor.uiIconImage(editor.icons.star, imVec16x16 ,imVec4TransparentWhite)
    im.tooltip("Associated to star " .. dumps(e.displayOptions.associatedStars))
  end
  im.NextColumn()
end
----------- drawing functions ---------------

local editEnded
local function customDraw(e, mtd, mission) return e.drawFunction(e, mtd, mission) end
local function numericDraw(e, mtd)
  label(e)
  im.PushItemWidth(im.GetContentRegionAvailWidth())
  editEnded[0] = im.InputFloat('##'..e.fieldName, e.ptr, 1, 5, nil, im.InputTextFlags_EnterReturnsTrue)
  if editEnded[0] then
    if e.displayOptions.min and e.ptr[0] < e.displayOptions.min then
      e.ptr[0] = e.displayOptions.min
    end
    if e.displayOptions.max and e.ptr[0] > e.displayOptions.max then
      e.ptr[0] = e.displayOptions.max
    end
    mtd[e.fieldName] = e.ptr[0]
  end
  if e.displayOptions.unit == 'velocity' then
    im.BeginDisabled()
    im.Text(string.format("%0.2f m/s = %0.2f %s",e.ptr[0],translateVelocity(e.ptr[0], true)))
    im.EndDisabled()
  end
  if e.displayOptions.unit == 'distance' then
    im.BeginDisabled()
    im.Text(string.format("%0.2f m = %0.2f %s",e.ptr[0],translateDistance(e.ptr[0], true)))
    im.EndDisabled()
  end
  if e.displayOptions.unit == 'time' then
    im.BeginDisabled()
    local t = e.ptr[0]
    im.Text(string.format("%0.2f s = %d:%02d.%02d mm:ss.mmm",t,(t-(t%60))/60, math.floor(t%60), 100*(t%1)))
    im.EndDisabled()
  end
  im.PopItemWidth()
  im.Columns(1)
  return editEnded[0]
end

local noTranslation = "No Translation found!"
local function stringDraw(e, mtd)
  label(e)
  local hasTranslate = e.displayOptions.isTranslation
  local hasDropdown = e.displayOptions.dropdownValues

  local width = im.GetContentRegionAvailWidth() - (hasTranslate and 35 or 0) - (hasDropdown and 45 or 0) - (hasTranslate and hasDropdown and 10 or 0)

  im.PushItemWidth(width)
  editor.uiInputText('##'..e.fieldName, e.ac, e.len, im.InputTextFlags_EnterReturnsTrue, nil, nil, editEnded)
  if hasTranslate then
    im.SameLine()
    if not e._translated then
      e._translated = translateLanguage(ffi.string(e.ac), noTranslation)
    end
    editor.uiIconImage(editor.icons.translate, imVec24x24 , (e._translated or noTranslation) == noTranslation and imVec4Red or imVec4Green)
    if im.IsItemHovered() then
      im.tooltip(e._translated)
    end
  end
  if hasDropdown then
    im.SameLine()
    local ret = nil
    im.PushItemWidth(35)
    if im.BeginCombo('##dropdown'..e.fieldName, "") then
      for _, v in ipairs(e.displayOptions.dropdownValues) do
        if im.Selectable1(v, v == mtd[e.fieldName]) then
          e.ac = im.ArrayChar(e.len, v)
          editEnded[0] = true
        end
        if e.displayOptions.valueTooltips and e.displayOptions.valueTooltips[v] then
          im.tooltip(e.valueTooltips[v])
        end
      end
      im.EndCombo()
    end
    im.PopItemWidth()
  end
  im.PopItemWidth()
  im.Columns(1)
  if editEnded[0] then e._translated = nil mtd[e.fieldName] = ffi.string(e.ac) return true end
  return false
end
local function boolDraw(e, mtd)
  label(e)
  local ret = false
  local boxText = e.displayOptions.boxText or ""
  if im.Checkbox(boxText..'##'..e.fieldName, e.ptr) then mtd[e.fieldName] = e.ptr[0] ret=true end
  im.Columns(1)
  return ret
end
local function transformDraw(e, mtd, m, mouseInfo)
  local ret = false
  label(e)
  e.transform.drawWidgetCondensed = true
  e.transform.switchRotationForMouse = true
  if e.transform:update(mouseInfo) then
    mtd[e.fieldNamePos] = e.hasPos and (e.transform.pos:toTable())
    mtd[e.fieldNameRot] = e.hasRot and (e.transform.rot:toTable())
    mtd[e.fieldNameScl] = e.hasScl and (e.oneDimScale and e.transform.scl or e.transform.scl:toTable())
    ret = true
  end
  --if not e.drawMode == 'hidden' then
    debugDrawer:drawTextAdvanced(vec3(e.transform.pos), String(e.label), whiteColorF, true, false, blackColorI)
  --end
  if e.drawMode == 'sphere' then
    debugDrawer:drawSphere(e.transform.pos, e.oneDimScale and e.transform.scl or e.transform.scl.x, ColorF(e.drawColor[1], e.drawColor[2], e.drawColor[3], e.drawColor[4]))
  elseif e.drawMode == 'sphereDir' then
    C:drawTransformAsSphereDir(e)
  elseif e.drawMode == 'vehicle' then
    C:drawTransformAsVehicle(e)
  elseif e.drawMode == 'halfBox' then
    local x, y, z = e.transform.rot * vec3(e.transform.scl.x,0,0), e.transform.rot * vec3(0,e.transform.scl.y,0), e.transform.rot * vec3(0,0,e.transform.scl.z)
    local scl = (x+y+z)/2
    C:drawAxisBox((-scl+e.transform.pos),x,y,z,ColorI(e.drawColor[1]*255, e.drawColor[2]*255, e.drawColor[3]*255, e.drawColor[4]*255))
  elseif e.drawMode == 'fullBox' then
    local x, y, z = e.transform.rot * vec3(e.transform.scl.x,0,0), e.transform.rot * vec3(0,e.transform.scl.y,0), e.transform.rot * vec3(0,0,e.transform.scl.z)
    local scl = (x+y+z)
    C:drawAxisBox((-scl+e.transform.pos),x*2,y*2,z*2,ColorI(e.drawColor[1]*255, e.drawColor[2]*255, e.drawColor[3]*255, e.drawColor[4]*255))
  end
  im.Columns(1)
  return ret
end

local function modelConfigDraw(e, mtd)
  label(e)

  if ui_flowgraph_editor.vehicleSelector(e.mc) then
    mtd[e.fieldNameModel] = e.mc.model
    mtd[e.fieldNameConfig] = e.mc.config
    mtd[e.fieldNameConfigPath] = e.mc.configPath
    im.Columns(1)
    return true
  end

  im.Columns(1)
  return false
end

local function fileDraw(e, mtd, mission)
  label(e)
  editor.uiInputText("##file"..e.label, e.ac, e.len, nil, nil, nil, editEnded)
  if editEnded[0] then
    mtd[e.fieldName] = ffi.string(e.ac)
    e.foundFile = nil
  end im.SameLine()
  if im.Button(" ... ##file"..e.label.."...") then
    extensions.editor_fileDialog.openFile(
      function(data)
        mtd[e.fieldName] = data.filepath
        e.ac = im.ArrayChar(e.len, data.filepath)
        e.foundFile = nil
        editEnded[0] = true
      end, e.allowedExtensions, false, mission.missionFolder)
  end im.SameLine()
  local file = ffi.string(e.ac)
  if e.foundFile == nil then
    e.foundFile = file ~= "" and (FS:fileExists(file) or  FS:fileExists(mission.missionFolder..'/'..file))
  end
  if e.foundFile then
    editor.uiIconImage(editor.icons.check, imVec24x24, imVec4Green)
    im.tooltip("Found file at " .. file)
  else
    editor.uiIconImage(editor.icons.error_outline, imVec24x24, imVec4Red)
    im.tooltip("No file at " .. file)
  end
  im.Columns(1)
  return editEnded[0]
end

local function fixedFileDraw(e, mtd, mission)
  label(e)
  --local file = mission.missionFolder..e.filepathInMissionfolder
  if e.foundFile == nil then
    for _, file in ipairs(e.filepathsInMissionfolder) do
      if FS:fileExists(mission.missionFolder .. file) then
        e.foundFile = mission.missionFolder .. file
      end
      if not e.foundFile then
        local fp, fn, ext = path.split(mission.missionFolder .. file, true)
        local files = FS:findFiles(fp, fn, -1, true, false)
        e.foundFile = files[1]
      end
    end
  end
  if im.Button("...##..." .. e._id) then
    --print("Editor Helper File Context Menu " .. e._id)
    im.OpenPopup("Editor Helper File Context Menu " .. e._id)
  end
  if im.BeginPopup("Editor Helper File Context Menu " .. e._id) then
    if im.Selectable1("Show in Explorer...") then
      Engine.Platform.exploreFolder(mission.missionFolder.."/")
    end
    if not e.foundFile and im.Selectable1("Check for File again") then
      e.foundFile = nil
    end

    if e.fileTags['race.json'] then
      im.Separator()
      if im.Selectable1("Open Race Editor") then
        if editor_raceEditor then
          editor_raceEditor.show()
        end
      end
      if not e.foundFile then im.BeginDisabled() end
      if im.Selectable1("Load File into Race Editor") then
        if editor_raceEditor then
          if not editor.active then
            editor.setEditorActive(true)
          end
          editor_raceEditor.show()
          editor_raceEditor.loadRace(e.foundFile)
        end
      end
      if not e.foundFile then im.EndDisabled() end
    end
    if e.fileTags['camPath.json'] then
      im.Separator()
      if im.Selectable1("Open Cam Path Editor") then
        editor.selectEditMode(editor.editModes.camPathEditMode)
      end
      if not e.foundFile then im.BeginDisabled() end
      if im.Selectable1("Load File into Cam Path Editor") then
        editor.selectEditMode(editor.editModes.camPathEditMode)
        local cedit = editor_camPathEditor
        editor_camPathEditor.selectPath(core_paths.loadPath(e.foundFile))
      end
      if not e.foundFile then im.EndDisabled() end
      if not (editor_camPathEditor and editor_camPathEditor.currentPath) then im.BeginDisabled() end
      for _, fl in ipairs(e.filepathsInMissionfolder) do
        if im.Selectable1("Save current campath from editor to " .. fl) then
          local cedit = editor_camPathEditor
          core_paths.savePath(editor_camPathEditor.currentPath, mission.missionFolder .. fl)
        end
      end
      if not (editor_camPathEditor and editor_camPathEditor.currentPath) then im.EndDisabled() end
    end
    if e.fileTags['sites.json'] then
      im.Separator()
      if im.Selectable1("Open Sites Editor") then
        if editor_sitesEditor then
          editor_sitesEditor.show()
        end
      end
      if not e.foundFile then im.BeginDisabled() end
      if im.Selectable1("Load File into Sites Editor") then
        if editor_sitesEditor then
          if not editor.active then
            editor.setEditorActive(true)
          end
          editor_sitesEditor.show()
          editor_sitesEditor.loadSites(e.foundFile)
        end
      end
      if not e.foundFile then im.EndDisabled() end
    end
    if e.fileTags['prefab.json'] or e.fileTags['prefab'] then
      if im.Selectable1("Open Scenetree") then
        editor_sceneTree.openSceneTree()
      end
      if not e.foundFile then im.BeginDisabled() end
      if im.Selectable1("Spawn Prefab at Origin") then
        local prefab = spawnPrefab(Sim.getUniqueName(mission.id.." - " .. e.label),e.foundFile,"0 0 0","0 0 0 1","1 1 1")
        if prefab then
          prefab.loadMode = 0
          scenetree.MissionGroup:addObject(prefab.obj)
          editor.selectObjectById(prefab.obj:getId())
        end
      end
      if not e.foundFile then im.EndDisabled() end
    end
    if e.fileTags['flow.json'] then
      if im.Selectable1("Open Flowgraph Editor") then
        editor_flowgraphEditor.open()
      end
      if not e.foundFile then im.BeginDisabled() end
      if im.Selectable1("Open Flowgraph Project in Flowgraph Editor") then
        editor_flowgraphEditor.open()
        editor_flowgraphEditor.openFile({filepath = e.foundFile}, true)
      end
      if not e.foundFile then im.EndDisabled() end
      if not e.foundFile then
        local template = nil
        if im.BeginMenu("Create New and Open Flowgraph Project...") then
          if im.Selectable1("Empty Project") then template = "empty" end
          if im.Selectable1("Barebones Mission Template") then template = "barebonesTemplate.flow.json" end
          if im.Selectable1("Simple Scenariolike Template") then template = "simpleScenarioTemplate.flow.json" end
          im.EndMenu()
        end
        if template then
          editor_flowgraphEditor.open()
          local mgr
          if template == "empty" then
            mgr = core_flowgraphManager.addManager()
          else
            mgr = core_flowgraphManager.loadManager("gameplay/missionTypes/flowgraph/"..template)
          end
          mgr.name = mission.name
          editor_flowgraphEditor.setManager(mgr, true)
          local fileName = e.filepathsInMissionfolder[1]
          if fileName:find("*") then
            fileName = "/project.flow.json"
          end
          editor_flowgraphEditor.saveAsFile({filepath = mission.missionFolder .. fileName})
        end
      end
    end
    if e.fileTags['vehGroup.json'] then
      im.Separator()
      if im.Selectable1("Open Vehicle Group Manager") then
        if editor_multiSpawnManager then
          editor_multiSpawnManager.onWindowMenuItem()
        end
      end
      if not e.foundFile then im.BeginDisabled() end
      if im.Selectable1("Load File into Vehicle Group Manager") then
        if editor_multiSpawnManager then
          if editor_multiSpawnManager then
            editor_multiSpawnManager.onWindowMenuItem()
          end
          editor_multiSpawnManager.importGroup(e.foundFile)
        end
      end
      if not e.foundFile then im.EndDisabled() end
    end
    im.EndPopup()
  end
  im.SameLine()


  if e.foundFile then
    editor.uiIconImage(editor.icons.check, imVec24x24, imVec4Green)
    im.tooltip(e.foundFile)
    im.SameLine()
    im.Text(e.foundFile)
  else
    local files = table.concat(e.filepathsInMissionfolder, ' or ')
    if e.displayOptions.optional then
      editor.uiIconImage(editor.icons.warning, imVec24x24,imVec4Yellow )
      im.tooltip("This file is optional: "..files)
      im.SameLine()
      im.Text("Optional: ".. files)
    else
      editor.uiIconImage(editor.icons.error_outline, imVec24x24,imVec4Red )
      im.tooltip("Requiring one of these files: " .. files)
      im.SameLine()
      im.Text("Required: ".. files)
    end
  end

  im.Columns(1)
end

local function raceDraw(e, mtd, mission)
  fileDraw(e, mtd, mission)
  if im.Button("Open Race Editor") then
    if editor_raceEditor then
      editor_raceEditor.show()
    end
  end
  if im.Button("Load Race into Race Editor") then
    if editor_raceEditor then
      if not editor.active then
        editor.setEditorActive(true)
      end
      editor_raceEditor.show()
      editor_raceEditor.loadRace(ffi.string(e.ac))
    end
  end
  if im.Button("Save Race Editor Race to File") then
    if editor_raceEditor then
      editor_raceEditor.show()
      editor_raceEditor.saveRace(nil, ffi.string(e.ac))
      e.foundFile = nil
    end
  end
  im.tooltip("Saves to " .. ffi.string(e.ac))
end

local function sitesDraw(e, mtd, mission)
  fileDraw(e, mtd, mission)
  if im.Button("Open Sites Editor") then
    if editor_sitesEditor then
      editor_sitesEditor.show()
    end
  end
  if im.Button("Load Sites into Sites Editor") then
    if editor_sitesEditor then
      if not editor.active then
        editor.setEditorActive(true)
      end
      editor_sitesEditor.show()
      editor_sitesEditor.loadSites(ffi.string(e.ac))
    end
  end
  if im.Button("Save Sites Editor Sites to File") then
    if editor_sitesEditor then
      editor_sitesEditor.show()
      editor_sitesEditor.saveSites(nil, ffi.string(e.ac))
      e.foundFile = nil
    end
  end
  im.tooltip("Saves to " .. ffi.string(e.ac))
end

local function leaderboardDraw(e, mtd)
  im.Text(e.label)
  if not e.fixedCount then
    editEnded[0] = im.InputInt(e.label.." Entry Count", e.count) or editEnded[0]
    e.count[0] = math.max(1,e.count[0])
  end
  im.BeginChild1("LB",im.ImVec2(im.GetContentRegionAvailWidth()*0.66, 62), true)
  im.Columns(3)
  im.Text("Best Result") im.NextColumn()
  im.Text("Medium Result") im.NextColumn()
  im.Text("Worst Result") im.NextColumn()
  im.Separator()
  editEnded[0] = im.InputFloat("##Best Result", e.best) or editEnded[0] im.NextColumn()
  editEnded[0] = im.InputFloat("##Medium Result", e.medium) or editEnded[0] im.NextColumn()
  editEnded[0] = im.InputFloat("##Worst Result", e.worst) or editEnded[0] im.NextColumn()
  im.Columns(1)
  im.EndChild()

  if editEnded[0] then
    mtd[e.fieldNameCount] = e.count[0]
    mtd[e.fieldNameBest] = e.best[0]
    mtd[e.fieldNameMedium] = e.medium[0]
    mtd[e.fieldNameWorst] = e.worst[0]
  end
  return editEnded[0]
end

local function simpleLapConfigDraw(e, mtd)
  local ret = false
  label(e)

  if e.lapConfig:update(mouseInfo) then
    ret = true
  end

  im.Columns(1)
  return ret
end

local function rewardDraw(e, mtd)
  local ret = numericDraw(e, mtd)
  --local budgets = career_career.getBudgets(e.ptr[0])
  --im.TextDisabled(string.format("%0.2f Reward = %0.2f B$ and %d Reputation", e.ptr[0], budgets.moneyBudget, budgets.reputationBudget))
  return ret
end

local function dropdownDraw(e, mtd, mission)
  label(e)
  local ret = nil
  if im.BeginCombo('##'..e.fieldName, mtd[e.fieldName] or "(None!)") then
    for _, v in ipairs(e.values) do
      if im.Selectable1(v, v == mtd[e.fieldName]) then
        mtd[e.fieldName] = v
        ret = true
      end
      if e.valueTooltips[v] then
        im.tooltip(e.valueTooltips[v])
      end
    end
    im.EndCombo()
  end
  im.Columns(1)
  return ret
end

local search = require('/lua/ge/extensions/editor/util/searchUtil')()
local function missionIdDraw(e, mtd, mission)
  label(e)
  local ids = gameplay_missions_missions.getAllIds()
  table.insert(ids, 1,"(none)")
  local ret = search:beginSearchableSimpleCombo(im, '##'..e.fieldName..'missionIdSelect', mtd[e.fieldName], ids)
  if ret then
    mtd[e.fieldName] = ret
  end
  im.Columns(1)
  return ret ~= nil
end

local function decoHeaderDraw(e, mtd) im.PushFont3("cairo_regular_medium") im.TextColored(e.color, e.text) im.PopFont() end
local function decoTextDraw(e, mtd) im.Columns(2) im.SetColumnWidth(0,columnWidth) im.Dummy(im.ImVec2(1,1)) im.NextColumn() im.TextWrapped(e.text) if e.tooltip then im.tooltip(e.tooltip) end im.Columns(1) end
local separatorColor = im.GetColorU322(im.ImVec4(1,1,1,0.5))
local separatorDummySize = im.ImVec2(0,5)
local function decoSeparatorDraw(e, mtd) im.Dummy(separatorDummySize) im.ImDrawList_AddLine(im.GetWindowDrawList(), im.GetCursorScreenPos(), im.ImVec2(im.GetCursorScreenPos().x+im.GetContentRegionAvailWidth(), im.GetCursorScreenPos().y), separatorColor, 1) im.Dummy(separatorDummySize) end
local function decoDummyDraw(e, mtd) im.Dummy(im.ImVec2(0,e.height)) end
local drawFunctions = {
  custom = customDraw,
  numeric = numericDraw,
  string = stringDraw,
  bool = boolDraw,
  transform = transformDraw,
  modelconfig = modelConfigDraw,
  file = fileDraw,
  fixedFile = fixedFileDraw,
  race = raceDraw,
  sites = sitesDraw,
  leaderboard = leaderboardDraw,
  reward = rewardDraw,
  dropdown = dropdownDraw,
  decoHeader = decoHeaderDraw,
  decoText = decoTextDraw,
  decoSeparator = decoSeparatorDraw,
  decoDummy = decoDummyDraw,
  simpleLapConfig = simpleLapConfigDraw,
  missionId = missionIdDraw,
}


function C:updateMouseInfo(mission)
  if not self.mouseInfo then self.mouseInfo = {} end
  if core_forest.getForestObject() then core_forest.getForestObject():disableCollision() end
  self.mouseInfo.camPos = getCameraPosition()
  self.mouseInfo.ray = getCameraMouseRay()
  self.mouseInfo.rayDir = vec3(self.mouseInfo.ray.dir)
  self.mouseInfo.rayCast = cameraMouseRayCast()
  self.mouseInfo.valid = self.mouseInfo.rayCast and true or false

  if core_forest.getForestObject() then core_forest.getForestObject():enableCollision() end
  if not self.mouseInfo.valid then
    self.mouseInfo.down = false
    self.mouseInfo.hold = false
    self.mouseInfo.up   = false
    self.mouseInfo.closestNodeHovered = nil
  else
    self.mouseInfo.down =  im.IsMouseClicked(0) and not im.GetIO().WantCaptureMouse
    self.mouseInfo.hold = im.IsMouseDown(0) and not im.GetIO().WantCaptureMouse
    self.mouseInfo.up =  im.IsMouseReleased(0) and not im.GetIO().WantCaptureMouse
    if self.mouseInfo.down then
      self.mouseInfo.hold = false
      self.mouseInfo._downPos = vec3(self.mouseInfo.rayCast.pos)
      self.mouseInfo._downNormal = vec3(self.mouseInfo.rayCast.normal)
    end
    if self.mouseInfo.hold then
      self.mouseInfo._holdPos = vec3(self.mouseInfo.rayCast.pos)
      self.mouseInfo._holdNormal = vec3(self.mouseInfo.rayCast.normal)
    end
    if self.mouseInfo.up then
      self.mouseInfo._upPos = vec3(self.mouseInfo.rayCast.pos)
      self.mouseInfo._upNormal = vec3(self.mouseInfo.rayCast.normal)
    end


    self.mouseInfo.closestElementsHovered = nil
    local closestDistance = math.huge
    local transformsToCheck = {}

    for _, e in ipairs(self.elements) do
      if e.clickable then
        table.insert(transformsToCheck, e)
      end
    end
    local startTriggerTransform = extensions.editor_missionEditor.getStartTriggerWindow():getStartTriggerTransform()
    if startTriggerTransform then
      table.insert(transformsToCheck, {label = "Start Trigger", transform = startTriggerTransform})
    end

    for _, e in ipairs(transformsToCheck) do

      local radius = e.transform.oneDimensionalScale and e.transform.scl or (math.min(e.transform.scl.x, math.min(e.transform.scl.y, e.transform.scl.z)))

      local distElementToCam = (e.transform.pos - self.mouseInfo.camPos):length()
      if distElementToCam < closestDistance then
        local elementRayDistance = (e.transform.pos - self.mouseInfo.camPos):cross(self.mouseInfo.rayDir):length() / self.mouseInfo.rayDir:length()
        if elementRayDistance <= radius then
          self.mouseInfo.closestElementsHovered = e
          closestDistance = distElementToCam
        end
      end

    end
  end
end

function C:editingAnyTransform()
  for _, e in ipairs(self.elements) do
    if e.transform and e.transform:correctEditMode() then
      return true
    end
  end
  local startTriggerTransform = extensions.editor_missionEditor.getStartTriggerWindow():getStartTriggerTransform()
  if startTriggerTransform and startTriggerTransform:correctEditMode() then
    return true
  end
  return false
end

function C:draw(filterOptions)
  self:updateMouseInfo(self.mission)
  if not self:editingAnyTransform() and editor.editMode == editor.editModes.objectSelect then
    if self.mouseInfo.closestElementsHovered and self.mouseInfo.valid then
      debugDrawer:drawTextAdvanced(vec3(self.mouseInfo.rayCast.pos), String("Click to Edit: " .. self.mouseInfo.closestElementsHovered.label), ColorF(1,1,1,1),true, false, ColorI(0,128,0,255))
      if self.mouseInfo.down then
        self.mouseInfo.closestElementsHovered.transform:enableEditing()
      end
    end
  end


  editEnded = im.BoolPtr(false)
  for index, element in ipairs(self.elements) do
    local show = not filterOptions
    if filterOptions then
      if filterOptions.onlyStar then
        if element.displayOptions.associatedStars and element.displayOptions.associatedStars[filterOptions.onlyStar] then
          show = true
        end
      end
    end


    if show then
      editEnded[0] = false
      --im.Text(string.format("%d - %s", index, dumps(element.hidden)))
      if not element.hidden and (drawFunctions[element.type] or nop)(element, self.mission.missionTypeData, self.mission, self.mouseInfo) then
        if element.valueChangedCallback then element:valueChangedCallback(self.mission.missionTypeData) end
        self.mission._dirty = true
      end
    end
  end
--[[
  if hoveredElement then
    hoveredElement.drawColor = previousColor
  end
  ]]
end

C.drawBaseFunction = C.draw

function C:drawTransformAsSphereDir(e)
  local radius = e.oneDimScale and e.transform.scl or e.transform.scl.x
  debugDrawer:drawSphere(e.transform.pos, radius, ColorF(e.drawColor[1], e.drawColor[2], e.drawColor[3], e.drawColor[4]))
  local normal = e.transform.rot * vec3(0,1,0)
  debugDrawer:drawSquarePrism(
      e.transform.pos,
      (e.transform.pos + radius * normal),
      Point2F(1,radius/2),
      Point2F(0,0),
      ColorF(e.drawColor[1], e.drawColor[2], e.drawColor[3], e.drawColor[4]*0.66))
    debugDrawer:drawSquarePrism(
      e.transform.pos,
      (e.transform.pos + 0.25 * normal),
      Point2F(5,radius*2),
      Point2F(0,0),
      ColorF(e.drawColor[1], e.drawColor[2], e.drawColor[3], e.drawColor[4]*0.5))

  --[[
  local pos = e.transform.pos
  local rot = e.transform.rot
  local xn, yn, zn = rot * vec3(1,0,0), rot * vec3(0,1,0), rot * vec3(0,0,1)
  if not e.switchRotation then yn = -yn end
  local corner = (-xn-1*yn-0.3*zn)+pos
  local x, y, z = xn*2, yn*4.2, zn*1.8
  local clr = ColorI(e.drawColor[1]*255, e.drawColor[2]*255, e.drawColor[3]*255, e.drawColor[4]*255)
  debugDrawer:drawTriSolid(
    vec3(pos+xn/2    ),
    vec3(pos-xn/2    ),
    vec3(pos+yn/2    ),
    blackColorI)
  debugDrawer:drawTriSolid(
    vec3(pos-xn/2    ),
    vec3(pos+xn/2    ),
    vec3(pos+yn/2    ),
    blackColorI)
    ]]
end

-- other helper functions
function C:drawTransformAsVehicle(e)
  local pos = e.transform.pos
  local rot = e.transform.rot
  local xn, yn, zn = rot * vec3(1,0,0), rot * vec3(0,1,0), rot * vec3(0,0,1)
  if not e.switchRotation then yn = -yn end
  local corner = (-xn-1*yn-0.3*zn)+pos
  local x, y, z = xn*2, yn*4.2, zn*1.8
  local clr = ColorI(e.drawColor[1]*255, e.drawColor[2]*255, e.drawColor[3]*255, e.drawColor[4]*255)
  debugDrawer:drawTriSolid(
    vec3(pos+xn/2    ),
    vec3(pos-xn/2    ),
    vec3(pos-yn/2    ),
    blackColorI)
   debugDrawer:drawTriSolid(
    vec3(pos-xn/2    ),
    vec3(pos+xn/2    ),
    vec3(pos-yn/2    ),
    blackColorI)

  -- draw all faces in a loop
  for _, face in ipairs({{x,y,z},{x,z,y},{y,z,x}}) do
    local a,b,c = face[1],face[2],face[3]
    -- spokes
    debugDrawer:drawLine((corner    ), (corner+c    ), whiteColorF)
    debugDrawer:drawLine((corner+a  ), (corner+c+a  ), whiteColorF)
    debugDrawer:drawLine((corner+b  ), (corner+c+b  ), whiteColorF)
    debugDrawer:drawLine((corner+a+b), (corner+c+a+b), whiteColorF)
    -- first side
    debugDrawer:drawTriSolid(
      vec3(corner    ),
      vec3(corner+a  ),
      vec3(corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(corner+b  ),
      vec3(corner    ),
      vec3(corner+a+b),
      clr)
    -- back of first side
    debugDrawer:drawTriSolid(
      vec3(corner+a  ),
      vec3(corner    ),
      vec3(corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(corner    ),
      vec3(corner+b  ),
      vec3(corner+a+b),
      clr)
    -- other side
    debugDrawer:drawTriSolid(
      vec3(c+corner    ),
      vec3(c+corner+a  ),
      vec3(c+corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(c+corner+b  ),
      vec3(c+corner    ),
      vec3(c+corner+a+b),
      clr)
    -- back of other side
    debugDrawer:drawTriSolid(
      vec3(c+corner+a  ),
      vec3(c+corner    ),
      vec3(c+corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(c+corner    ),
      vec3(c+corner+b  ),
      vec3(c+corner+a+b),
      clr)
  end
end

function C:drawAxisBox(corner, x, y, z, clr)
  -- draw all faces in a loop
  for _, face in ipairs({{x,y,z},{x,z,y},{y,z,x}}) do
    local a,b,c = face[1],face[2],face[3]
    -- spokes
    debugDrawer:drawLine((corner    ), (corner+c    ), ColorF(0,0,0,0.75))
    debugDrawer:drawLine((corner+a  ), (corner+c+a  ), ColorF(0,0,0,0.75))
    debugDrawer:drawLine((corner+b  ), (corner+c+b  ), ColorF(0,0,0,0.75))
    debugDrawer:drawLine((corner+a+b), (corner+c+a+b), ColorF(0,0,0,0.75))
    -- first side
    debugDrawer:drawTriSolid(
      vec3(corner    ),
      vec3(corner+a  ),
      vec3(corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(corner+b  ),
      vec3(corner    ),
      vec3(corner+a+b),
      clr)
    -- back of first side
    debugDrawer:drawTriSolid(
      vec3(corner+a  ),
      vec3(corner    ),
      vec3(corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(corner    ),
      vec3(corner+b  ),
      vec3(corner+a+b),
      clr)
    -- other side
    debugDrawer:drawTriSolid(
      vec3(c+corner    ),
      vec3(c+corner+a  ),
      vec3(c+corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(c+corner+b  ),
      vec3(c+corner    ),
      vec3(c+corner+a+b),
      clr)
    -- back of other side
    debugDrawer:drawTriSolid(
      vec3(c+corner+a  ),
      vec3(c+corner    ),
      vec3(c+corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(c+corner    ),
      vec3(c+corner+b  ),
      vec3(c+corner+a+b),
      clr)
  end
end

local function transformCustomFieldNameTypeGetter(e)
  local ret = {}
  if e.hasPos then table.insert(ret, {fieldName = e.fieldNamePos, elemLabel = e.label, type = "vec3"}) end
  if e.hasRot then table.insert(ret, {fieldName = e.fieldNameRot, elemLabel = e.label, type = "quat"}) end
  if e.hasScl then table.insert(ret, {fieldName = e.fieldNameScl, elemLabel = e.label, type = e.oneDimScale and "number" or "vec3"}) end
  return ret
end

local function genericFieldNameTypeGetter(elem)
  local ret = {}
  if elem.fieldName then
    local customFnCount = 0
    local sortedKeys = tableKeys(elem)
    table.sort(sortedKeys)
    for _, key in pairs(sortedKeys) do
      if key ~= "fieldName" and string.startswith(key, "fieldName") then
        customFnCount = customFnCount+1
      end
    end
    if customFnCount == 0 then
      table.insert(ret, {label = elem.type, fieldName = elem.fieldName, elemLabel = elem.label})
    else
      -- find all field with fieldname
      for _, key in pairs(sortedKeys) do
        if key ~= "fieldName" and string.startswith(key, "fieldName") then
          table.insert(ret, {label = string.sub(key, 10), fieldName = elem[key], elemLabel = elem.label})
        end
      end
    end
  end
  for _, field in ipairs(ret) do
    field.type = ui_flowgraph_editor.getAutoTypeFromName(field.label)
    --print(string.format("%s (%s) from %s", field.fieldName, field.type, field.elemLabel))
  end
  return ret
end


-- field getter
local customFieldNameTypeFunctions = {
  transform = transformCustomFieldNameTypeGetter
}

function C:getAllFieldNames()
  local fieldNamesWithType = {}
  for _, elem in ipairs(self.elements) do
    for _, fnElem in ipairs((customFieldNameTypeFunctions[elem.type] or genericFieldNameTypeGetter)(elem) or {}) do
      table.insert(fieldNamesWithType, fnElem)
    end
  end
  return fieldNamesWithType
end

function C:setAutoAdditionalAttributes(key, auto)
  if auto == nil then
    auto = true
  end

  self.autoAdditionalAttributes[key] = auto
end

return function(derivedClass, ...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  for k, v in pairs(derivedClass) do
    o[k] = v
  end
  o.elements = {}
  o.autoAdditionalAttributes = {}
  if o.init then
    o:init()
  end
  return o
end
