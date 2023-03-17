-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui
local imu = require('ui/imguiUtils')
local nameText = im.ArrayChar(1024, "")
local descText = im.ArrayChar(2048, "")
local authorsText = im.ArrayChar(2048, "")
local previewOpen = im.BoolPtr(false)
local previewTex = nil
local C = {}
C.windowDescription = 'Time Trials'

local difficulties = {'Easy','Medium','Hard','Very Hard'}
local function intDiffToString(iDiff)
  return difficulties[clamp(math.floor(iDiff / 25) + 1, 1, 4)]
end
local prefabData = {
  { name = 'Prefabs', fieldName = 'prefabs', prefix = '', tt = 'These prefabs will always be loaded automatically.'  },
  { name = 'Forward Prefabs', fieldName = 'forwardPrefabs', prefix = '_forward', tt = 'These prefabs will only be loaded when the track is played in forward direction.'  },
  { name = ' ReversePrefabs', fieldName = 'reversePrefabs', prefix = '_reverse', tt = 'These prefabs will only be loaded when the track is played in reverse direction.'  },
}

function C:init(raceEditor)
  self.pathEditor = raceEditor
end

function C:setPath(path)
  self.path = path
  self:selected()
end
function C:selected()
  nameText = im.ArrayChar(1024, self.path.name)
  descText = im.ArrayChar(2048, self.path.description)
  authorsText = im.ArrayChar(2048, self.path.authors)
  self.filenames = {}
  for _, pn in ipairs(prefabData) do
    self.filenames[pn.fieldName] = {}
    for _, p in ipairs(self.path[pn.fieldName] or {}) do
      table.insert(self.filenames[pn.fieldName], im.ArrayChar(2048, p or ""))
    end
  end
  self.previewPath = self.path._dir .. self.path._fnWithoutExt .. '.jpg'
  self:findPreview()

end

function C:findPreview()
  self.previewPath = self.path._dir .. self.path._fnWithoutExt .. '.jpg'
  if FS:fileExists(self.previewPath) then
    previewTex = imu.texObj(self.previewPath)
  else
    previewTex = nil
  end
end
function C:unselect() end

function C:draw()
  self:drawGeneralInfo()
end

local function setFieldUndo(data) data.self.path[data.field] = data.old data.self:selected() end
local function setFieldRedo(data) data.self.path[data.field] = data.new data.self:selected() end

function C:changeField(field,  new, add)
  if new ~= self.path[field] then
    add = add and ("("..add..")") or ""
    editor.history:commitAction("Changed Field " .. field.. " of Path " .. add,
    {self = self, old = self.path[field], new = new, field = field},
    setFieldUndo, setFieldRedo)
  end
end

function C:drawGeneralInfo()
  im.BeginChild1("General", im.ImVec2(0, 0), im.WindowFlags_ChildWindow)

  local editEnded = im.BoolPtr(false)
  if editor.uiInputText("Name", nameText, 1024, nil, nil, nil, editEnded) then
  end im.tooltip("The name of the track.")
  if editEnded[0] then
    self:changeField("name",ffi.string(nameText))
  end

  editEnded = im.BoolPtr(false)
  if editor.uiInputTextMultiline("Description", descText, 2048, im.ImVec2(0,60), nil, nil, nil, editEnded) then
  end im.tooltip("The description of the track.")
  if editEnded[0] then
    self:changeField("description",ffi.string(descText))
  end

  editEnded = im.BoolPtr(false)
  if editor.uiInputText("Authors", authorsText, 1024, nil, nil, nil, editEnded) then
  end im.tooltip("Who made this track.")
  if editEnded[0] then
    self:changeField("authors",ffi.string(authorsText))
  end
  if im.BeginCombo("Difficulty", intDiffToString(self.path.difficulty)) then
    for i, d in ipairs(difficulties) do
      if im.Selectable1(d, d == intDiffToString(self.path.difficulty)) then
        self:changeField("difficulty", (i - 1) * 25 + 12)
      end
    end
    im.EndCombo()
  end im.tooltip("How difficult this track is.")

  local classification = self.path:classify()
  self:displayClassification(classification, "Reversible: ", 'reversible', "If this track can be reversed. Possible if both the Default Starting Position\nand Reverse Starting Positions are set, as well as the End Node for open tracks.")
  im.SameLine()
  self:displayClassification(classification, "Rolling Start: ", 'allowRollingStart', "If this track can be started from from a distance. Possible if Rolling Start Position is set.\nIf the track is reversible, also Reverse Rolling Start has to be set.")
  im.SameLine()
  im.Text("Preview:")
  im.SameLine()
  local hovered = false
  if previewTex then
    editor.uiIconImage(editor.icons.check, im.ImVec2(24, 24))
    if im.IsItemHovered() then
      hovered = true
    end
    im.tooltip("Found at " .. self.previewPath.."\nClick to refresh.")
  else
    editor.uiIconImage(editor.icons.error_outline, im.ImVec2(24, 24))
    im.tooltip("None found at " .. self.previewPath.."\nClick to refresh.")
  end
  if im.IsItemClicked() then
    self:findPreview()
  end
  if hovered and previewTex then
    im.Separator()
    local size = im.ImVec2(previewTex.size.x, previewTex.size.y)
    local avail = im.GetContentRegionAvail()
    if avail.x < size.x and size.x ~= 0 and avail.x ~= 0 then
      local fac = avail.x/size.x
      size.x = size.x * fac
      size.y = size.y * fac
    end
    im.Image(previewTex.texId, size)
    im.Separator()
  end
  for i, pn in ipairs(prefabData) do
    im.Separator()
    im.Text(pn.name) im.tooltip(pn.tt)
    self:drawPrefabs(pn.fieldName, self.path._fnWithoutExt..pn.prefix..'.prefab')
  end


  im.EndChild()
end
function C:displayClassification(classification, name, field, tt)
  im.Text(name) im.SameLine() im.tooltip(tt or "")
  if classification[field] then
    editor.uiIconImage(editor.icons.check, im.ImVec2(24, 24))
  else
    editor.uiIconImage(editor.icons.close, im.ImVec2(24, 24))
  end
  im.tooltip(tt or "")
end


function C:existsIcon(f, inPathFolder)
  local lvl = path.levelFromPath(self.path._dir)
  local levelPath = self.path._dir
  if lvl then
    local levelPath = '/levels/'..path.levelFromPath(self.path._dir)..'/'
    if inPathFolder then
      levelPath = self.path._dir
    end
  end

  local files = {}
  if type(f) == 'string' then
    files = {f, f..'.prefab', f..'.prefab.json',f..'.json',
        (levelPath)..f,(levelPath)..f..'.prefab',(levelPath)..f..'.prefab.json',(levelPath)..f..'.json'}
  else
    files = f
  end

  local at = nil
  for i, f in ipairs(files) do
    if f ~= "" and FS:fileExists(f) then
      at = f
    end
  end
  if at then
    editor.uiIconImage(editor.icons.check, im.ImVec2(24, 24))
    im.tooltip("Found file at " .. at)
  else
    editor.uiIconImage(editor.icons.error_outline, im.ImVec2(24, 24))
    local str = "No file at:"
    for _,f in ipairs(files) do str = str.."\n - " .. f end

    im.tooltip(str)
  end
end

function C:drawPrefabs(fieldName, default)
  local rem = nil
  local editEnded = im.BoolPtr(false)
  local list = self.path[fieldName]
  local filenameList = self.filenames[fieldName]
  im.PushItemWidth(232)
  editor.uiInputText("##prefab"..default..fieldName, im.ArrayChar(1024,default), 1024) im.tooltip("This Prefab is always loaded automatically if existing.")
  im.SameLine() self:existsIcon(default, true)


  for i, prefab in ipairs(list) do
    if editor.uiIconImageButton(editor.icons.delete_forever, im.ImVec2(24, 24), nil, nil, nil,'##rem'..prefab..i) then
      rem = i
    end
    im.SameLine()
    im.PushItemWidth(200)
    editEnded[0] = false
    editor.uiInputText("##prefab"..i, filenameList[i], 2048, nil, nil, nil, editEnded)
    if editEnded[0] then
      local newPrefabs = deepcopy(self.path[fieldName])
      newPrefabs[i] = ffi.string(filenameList[i])
      self:changeField(fieldName, newPrefabs,"changed entry")
    end
    im.SameLine()
    if im.Button(" ... ##prefab"..i) then
      extensions.editor_fileDialog.openFile(
        function(data)
          local newPrefabs = deepcopy(self.path[fieldName])
          newPrefabs[i] = data.filepath
          self:changeField(fieldName, newPrefabs,"changed entry")
        end, {{"Prefab",".prefab.json"}, {"Prefab",".prefab"}}, false, self.path._dir)
    end
    im.SameLine()
    self:existsIcon(list[i])
  end
  if rem then
    local newPrefabs = deepcopy(self.path[fieldName])
    table.remove(newPrefabs, rem)
    self:changeField(fieldName, newPrefabs,"removed entry")
  end
  if im.Button("Add##prefabs") then
    local newPrefabs = deepcopy(self.path[fieldName])
    table.insert(newPrefabs,"/")
    self:changeField(fieldName, newPrefabs,"added entry")
  end
end


return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
