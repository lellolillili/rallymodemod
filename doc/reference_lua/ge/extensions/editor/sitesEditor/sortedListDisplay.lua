-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im = ui_imgui

local C = {}
C.windowDescription = 'Sites'

function C:init(sitesEditor, key, elementEditor)
  self.key = key
  self.sitesEditor = sitesEditor
  self.index = nil
  self.mouseInfo = {}
  self.elementEditor = elementEditor
  self.createByShift = true
  self.selectByClick = true
  self.search = im.ArrayChar(256, "")
  editor.selection[self.key] = {}
  self.selections = editor.selection[self.key]
  self.currTags = {}
  self.sharedSelectedTags = {}
end

function C:setSites(sites)
  self.sites = sites
  self.objects = sites[self.key].objects
  self.sorted = sites[self.key].sorted
  self.elementEditor:setSites(sites)

  for _, o in pairs(self.objects) do
    for _, tag in ipairs(o.customFields.sortedTags) do
      if not self.currTags[tag] then
        self.currTags[tag] = 1
      else
        self.currTags[tag] = self.currTags[tag] + 1
      end
    end
  end
end

function C:selected()
  self.index = nil
  table.clear(self.selections)

  if not self.sites then
    return
  end
  for _, o in pairs(self.objects) do
    o._drawMode = 'normal'
  end
end

function C:unselect()
  table.clear(self.selections)

  for _, o in pairs(self.objects) do
    o._drawMode = 'faded'
  end
  -- self.elementEditor:unselect()
end

function C:selectElement(id, mode)
  if not mode then
    table.clear(self.selections)
  end

  local idx = mode ~= 'add' and arrayFindValueIndex(self.selections, id)
  if idx then
    table.remove(self.selections, idx)
    self:updateSharedSelectedTags()
  else
    table.insert(self.selections, id)
    self:updateSharedSelectedTags()
  end
  self.index = self.selections[1]

  for _, o in pairs(self.objects) do
    o._drawMode = 'normal'
    for _, s in ipairs(self.selections) do
      if o.id == s then
        o._drawMode = 'highlight'
      end
    end
  end
  local elem = self.objects[self.selections[1]]
  if not elem or elem.missing then
    elem = nil
  end

  --if self.sitesEditor.allowGizmo() then
  self.elementEditor:select(elem)
  --end

  if elem then
    self.nameText = im.ArrayChar(1024, elem.name)
    self.color = im.ArrayFloat(4)
    self.color[0] = im.Float(elem.color.x)
    self.color[1] = im.Float(elem.color.y)
    self.color[2] = im.Float(elem.color.z)
    self.color[3] = im.Float(1)
    self.fields = {}
    self.addFieldText = im.ArrayChar(256, "")
    self.addTagText = im.ArrayChar(256, "")
  end
end

function C:updateSharedSelectedTags()
  local tmpTags = {}
  -- go through all selections
  for _, id in ipairs(self.selections) do

    -- go through all their tags
    for _, tag in ipairs(self.objects[id].customFields.sortedTags) do

      -- check if already approved tag
      if tmpTags[tag] then
        goto continue
      end

      -- check if all selections share this tag
      for _, compareId in ipairs(self.selections) do
        if not tableContains(self.objects[compareId].customFields.sortedTags, tag) then
          goto continue
        end
      end
      tmpTags[tag] = true

      :: continue ::
    end
  end

  self.sharedSelectedTags = tmpTags
end

function C:draw(mouseInfo)
  if self.sitesEditor.allowGizmo() then
    self.mouseInfo = mouseInfo
    self:input()
  end
  self:drawList()
end

function C:input()
  if not self.mouseInfo.valid then
    return
  end
  if self.selectByClick then
    local selected = self.elementEditor:hitTest(self.mouseInfo, self.objects)
    if editor.keyModifiers.shift and self.createByShift then
      if self.mouseInfo.down and not editor.isAxisGizmoHovered() then
        local elem = self.elementEditor:create(self.mouseInfo._downPos)
        self:selectElement(elem and elem.id)

      end
    else
      if self.mouseInfo.down and not editor.isAxisGizmoHovered() then
        if selected then
          self:selectElement(selected.id)
        else
          self:selectElement(nil)
        end
      end
    end
  else
    if self.elementEditor.input then
      self.elementEditor:input(self.mouseInfo)
    end
  end
end

local function moveElementUndo(data)
  data.sites[data.key]:move(data.index, -data.dir)
end
local function moveElementRedo(data)
  data.sites[data.key]:move(data.index, data.dir)
end

local function setFieldUndo(data)
  for _, id in ipairs(data.sel) do
    data.self.sites[data.key].objects[id][data.field] = data.old
  end
end
local function setFieldRedo(data)
  for _, id in ipairs(data.sel) do
    data.self.sites[data.key].objects[id][data.field] = data.new
  end
end

function C:setField(name, value)
  editor.history:commitAction("Change " .. name .. " of " .. self.key,
          { self = self, key = self.key, sel = deepcopy(self.selections), new = value, field = name },
          setFieldUndo, setFieldRedo)
end

function C:drawList()
  local avail = im.GetContentRegionAvail()
  local disabled = self.selections[2] and true or false

  im.BeginChild1(self.key, im.ImVec2(180 * im.uiscale[0], 0), im.WindowFlags_ChildWindow)
  if editor.uiInputText('', self.search) then
  end
  im.SameLine()
  if im.SmallButton("x") then
    self.search = im.ArrayChar(256, '')
  end
  im.Separator()
  local filter = string.lower(ffi.string(self.search))
  if filter == '' then
    filter = nil
  end
  local remove = nil
  for i, obj in ipairs(self.sorted) do
    if not obj.isProcedural and ((filter == nil) or (filter and string.find(string.lower(obj.name), filter) or self.currentElement == obj)) then
      if tableContains(self.selections, obj.id) then
        if im.SmallButton("X##" .. obj.id) then
          remove = obj
        end
        im.SameLine()
      end
      local selected = arrayFindValueIndex(self.selections, obj.id) and true or false
      local mode
      if editor.keyModifiers.ctrl or editor.keyModifiers.shift then
        mode = "toggle"
      elseif editor.keyModifiers.shift then
        mode = "add"
      end

      if im.Selectable1(obj.name .. '##' .. obj.id, selected) then
        self:selectElement(obj.id, mode)
      end
    end
  end
  if remove then
    self.sites[self.key]:remove(remove)
    self:selectElement(nil)
  end
  im.Separator()
  if self.createByShift then
    if im.Selectable1('New...', self.index == nil) then
      self:selectElement(nil)
    end
    im.tooltip("Shift-Drag in the world to create a new pathnode.")
  else
    if im.Selectable1('Create...', false) then
      local elem = self.elementEditor:create(nil)
      self:selectElement(elem and elem.id)
    end
  end
  im.EndChild()

  im.SameLine()
  im.BeginChild1("currentElement", im.ImVec2(0, 0), im.WindowFlags_ChildWindow)
  if self.index then
    local o = self.objects[self.index]
    local editEnded = im.BoolPtr(false)
    if disabled then
      im.BeginDisabled()
    end

    editor.uiInputText("Name", self.nameText, nil, nil, nil, nil, editEnded)
    if editEnded[0] then
      self:setField('name', ffi.string(self.nameText))
    end
    editEnded = im.BoolPtr(false)
    editor.uiColorEdit3("Color", self.color, nil, editEnded)
    if editEnded[0] then
      self:setField('color', vec3(self.color[0], self.color[1], self.color[2]))
    end

    if disabled then
      im.EndDisabled()
    end

    im.Separator()
    --editor.drawAxisGizmo()
    self.elementEditor:drawElement(o)
    im.Separator()
    self:drawTags(o.customFields)
    im.Separator()
    self:drawCustomFields(o.customFields)

  end
  im.EndChild()
end

function C:drawCustomFields(fields)
  im.Text("Custom Fields")
  local remove
  for i, name in ipairs(fields.names) do
    if fields.types[name] == 'string' then
      if not self.fields[name] then
        self.fields[name] = im.ArrayChar(4096, fields.values[name])
      end
      local editEnded = im.BoolPtr(false)
      editor.uiInputText(name, self.fields[name], nil, nil, nil, nil, editEnded)
      if editEnded[0] then
        for _, id in ipairs(self.selections) do
          self.objects[id].customFields.values[name] = ffi.string(self.fields[name])
        end
      end
    elseif fields.types[name] == 'number' then
      if not self.fields[name] then
        self.fields[name] = im.FloatPtr(fields.values[name])
      end
      local editEnded = im.BoolPtr(false)
      editor.uiInputFloat(name, self.fields[name], nil, nil, nil, nil, editEnded)
      if editEnded[0] then
        for _, id in ipairs(self.selections) do
          self.objects[id].customFields.values[name] = (self.fields[name])[0]
        end
      end
    elseif fields.types[name] == 'vec3' then
      debugDrawer:drawTextAdvanced((fields.values[name]),
              String(name),
              ColorF(1, 1, 1, 1), true, false,
              ColorI(0, 0, 0, 1 * 255))
      debugDrawer:drawSphere((fields.values[name]), 1, ColorF(1, 0, 0, 0.5))
      if not self.fields[name] then
        self.fields[name] = im.ArrayFloat(3)
        self.fields[name][0] = fields.values[name].x
        self.fields[name][1] = fields.values[name].y
        self.fields[name][2] = fields.values[name].z
      end
      local editEnded = im.BoolPtr(false)
      editor.uiInputFloat3(name, self.fields[name], nil, nil, editEnded)
      if editEnded[0] then
        local tbl = { self.fields[name][0], self.fields[name][1], self.fields[name][2] }
        fields.values[name] = vec3(tbl)
      end
    end
    im.SameLine()
    if im.SmallButton("X##" .. i) then
      remove = name
    end
  end
  if remove then
    for _, id in ipairs(self.selections) do
      self.objects[id].customFields:remove(remove)
    end
  end

  editor.uiInputText("##new", self.addFieldText)
  if im.Button("New String") then
    for _, id in ipairs(self.selections) do
      self.objects[id].customFields:add(ffi.string(self.addFieldText), 'string', "value")
    end
    self.addFieldText = im.ArrayChar(256, "")
  end
  im.SameLine()
  if im.Button("New Number") then
    for _, id in ipairs(self.selections) do
      self.objects[id].customFields:add(ffi.string(self.addFieldText), 'number', 0)
    end
    self.addFieldText = im.ArrayChar(256, "")
  end
  im.Separator()

  if im.Button("Copy Fields") then
    self.cfData = fields:onSerialize()
  end
  im.tooltip("Copies the custom fields of this object to use for other objects.")
  im.SameLine()
  if not self.cfData then
    im.BeginDisabled()
  end
  if im.Button("Paste Fields") then
    fields:onDeserialized(self.cfData)
    self:updateSharedSelectedTags()
  end
  if not self.cfData then
    im.EndDisabled()
  end
  im.tooltip("Pastes the stored custom fields into this object.")
  --im.SameLine()
  --if im.Button("Populate Others") then
    --local cfData = fields:onSerialize()
    --for _, o in ipairs(self.sorted) do
      --o.customFields:onDeserialized(cfData)
    --end
  --end
  --im.tooltip("Replaces all other object's custom fields with the contents of this one.")
end

function C:drawTags()
  if #self.selections > 1 then
    im.Text("Shared Tags")
  else
    im.Text("Tags")
  end
  local padding = im.GetStyle().FramePadding
  local totalWidth = im.GetContentRegionAvailWidth()
  local removeTag
  im.BeginChild1("", im.ImVec2(0, 22), false)
  im.SetCursorPosY(im.GetCursorPosY() + 2)
  if not self.sharedSelectedTags or tableSize(self.sharedSelectedTags) == 0 then
    im.Text("No Tags yet")
  else
    for t, _ in pairs(self.sharedSelectedTags or {}) do
      if im.GetCursorPosX() + im.CalcTextSize(t).x + 10 > totalWidth then
        im.EndChild()
        im.BeginChild1(t, im.ImVec2(0, 22), false)
        im.SetCursorPosY(im.GetCursorPosY() + 2)
      end
      if im.SmallButton(t) then
        self.popupTag = t
        im.OpenPopup("TagPopup")
      end
      im.SameLine()
    end
    if self.popupTag and im.BeginPopup("TagPopup") then
      im.Text("Tag: " .. self.popupTag)
      im.Separator()
      if im.Selectable1("Remove Tag") then
        removeTag = self.popupTag
      end
      im.EndPopup()
    end
  end

  im.EndChild()
  if removeTag then
    for _, id in ipairs(self.selections) do
      self.objects[id].customFields:removeTag(removeTag)

      if self.currTags[removeTag] == 1 then
        self.currTags[removeTag] = nil
      else
        self.currTags[removeTag] = self.currTags[removeTag] - 1
      end

      self:updateSharedSelectedTags()
    end
  end
  if editor.uiInputText("##tagInput", self.addTagText, nil, im.InputTextFlags_EnterReturnsTrue) then
    self:addTag()
  end
  im.SameLine()
  if tableSize(self.currTags) >= 1 then
    im.PushItemWidth(45)
    if im.BeginCombo("##tagSelect", "...") then
      for tag, _ in pairs(self.currTags) do
        if im.Selectable1(tag) then
          self.addTagText = im.ArrayChar(256, tag)
          self:addTag()
        end
      end
      im.EndCombo()
    end
    im.PopItemWidth()
  end
  im.SameLine()
  if im.Button("Add Tag") then
    self:addTag()
  end
end

function C:addTag()
  local tag = ffi.string(self.addTagText)
  if tag == '' then
    return
  end

  for _, id in ipairs(self.selections) do
    self.objects[id].customFields:addTag(tag)

    if not self.currTags[tag] then
      self.currTags[tag] = 1
    else
      self.currTags[tag] = self.currTags[tag] + 1
    end
  end
  self:updateSharedSelectedTags()
  self.addTagText = im.ArrayChar(256, "")
end

function C:getCurrentSelected()
  return self.objects and self.objects[self.index] or nil
end
return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end

