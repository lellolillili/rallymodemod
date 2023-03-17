-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui
local pacenotePosition = im.ArrayFloat(3)
local pacenoteNormal = im.ArrayFloat(3)
local pacenoteRadius = im.FloatPtr(0)
local nameText = im.ArrayChar(1024, "")
local noteText = im.ArrayChar(2048, "")

local C = {}
C.windowDescription = 'Pacenotes'

local function selectPacenoteUndo(data) data.self:selectPacenote(data.old) end
local function selectPacenoteRedo(data) data.self:selectPacenote(data.new) end

function C:init(raceEditor)
  self.raceEditor = raceEditor
  self.index = nil
  self.mouseInfo = {}
end

function C:setPath(path)
  self.path = path
end

function C:selected()
  self.index = nil
  if not self.path then return end
  for _, n in pairs(self.path.pacenotes.objects) do
    n._drawMode = 'normal'
  end
  editor.editModes.raceEditMode.auxShortcuts[editor.AuxControl_Shift] = "Add New"
  self.map = map.getMap()

  for _, seg in pairs(self.path.segments.objects) do
    seg._drawMode = 'faded'
  end

end
function C:unselect()
  --self:selectPacenote(nil)
  for _, n in pairs(self.path.pacenotes.objects) do
    n._drawMode = 'none'
  end
  editor.editModes.raceEditMode.auxShortcuts[editor.AuxControl_Shift] = nil
end

function C:selectPacenote(id)
  self.index = id
  for _, note in pairs(self.path.pacenotes.objects) do
    note._drawMode = (id == note.id) and 'highlight' or 'normal'
  end
  if id then
    local note = self.path.pacenotes.objects[id]
    nameText = im.ArrayChar(1024, note.name)
    self:updateTransform(id)
    noteText = im.ArrayChar(2048, note.note)
  else
    for _, seg in pairs(self.path.segments.objects) do
      seg._drawMode = 'faded'
    end
    noteText = im.ArrayChar(2048, "")
  end
end

function C:updateTransform(index)
  if not self.raceEditor.allowGizmo() then return end
  local note = self.path.pacenotes.objects[index]
  local rotation = QuatF(0,0,0,1)


    if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local then
      local q = quatFromDir(note.normal, vec3(0,0,1))
      rotation = QuatF(q.x, q.y, q.z, q.w)
    else
      rotation = QuatF(0, 0, 0, 1)
    end


  local transform = rotation:getMatrix()
  transform:setPosition(note.pos)
  editor.setAxisGizmoTransform(transform)
end


function C:beginDrag()
  local note = self.path.pacenotes.objects[self.index]
  if not note or note.missing then return end
  self.beginDragNoteData = note:onSerialize()
  if note.normal then
    self.beginDragRotation = deepcopy(quatFromDir(note.normal, vec3(0,0,1)))
  end

  self.beginDragRadius = note.radius
  if note.mode == 'navgraph' then
    self.beginDragRadius = note.navRadiusScale
  end
end

function C:dragging()
  local note = self.path.pacenotes.objects[self.index]
  if not note or note.missing then return end

  -- update/save our gizmo matrix
  if editor.getAxisGizmoMode() == editor.AxisGizmoMode_Translate then

    note.pos = vec3(editor.getAxisGizmoTransform():getColumn(3))

  elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Rotate then

    local gizmoTransform = editor.getAxisGizmoTransform()
    local rotation = QuatF(0,0,0,1)
    if note.normal then
      rotation:setFromMatrix(gizmoTransform)
      if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local then
        note.normal = quat(rotation)*vec3(0,1,0)
      else
        note.normal = self.beginDragRotation * quat(rotation)*vec3(0,1,0)
      end
    end
  elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Scale then
    local scl = vec3(worldEditorCppApi.getAxisGizmoScale())
    if scl.x ~= 1 then
      scl = scl.x
    elseif scl.y ~= 1 then
      scl = scl.y
    elseif scl.z ~= 1 then
      scl = scl.z
    else
      scl = 1
    end
    if scl < 0 then
      scl = 0
    end
    note.radius = self.beginDragRadius * scl
  end
end

function C:endDragging()
  local note = self.path.pacenotes.objects[self.index]
  if not note or note.missing then return end
  editor.history:commitAction("Manipulated Note via Gizmo",
    {old = self.beginDragNoteData,
     new = note:onSerialize(),
     index = self.index, self = self},
    function(data) -- undo
      local note = self.path.pacenotes.objects[data.index]
      note:onDeserialized(data.old)
      data.self:selectPacenote(data.index)
    end,
    function(data) --redo
      local note = self.path.pacenotes.objects[data.index]
      note:onDeserialized(data.new)
      data.self:selectPacenote(data.index)
    end)
end

function C:onEditModeActivate()
  if self.note then
    self:selectPacenote(self.note.id)
  end
end

function C:draw(mouseInfo)
  self.mouseInfo = mouseInfo
  if self.raceEditor.allowGizmo() then
    editor.updateAxisGizmo(function() self:beginDrag() end, function() self:endDragging() end, function() self:dragging() end)
    self:input()
  end
  self:drawPacenoteList()
end

function C:createManualPacenote()
  if not self.mouseInfo.rayCast then
    return
  end
  local txt = "Add manual Pacenote (Drag for Size)"
  debugDrawer:drawTextAdvanced(vec3(self.mouseInfo.rayCast.pos), String(txt), ColorF(1,1,1,1),true, false, ColorI(0,0,0,255))
  if self.mouseInfo.hold then

    local radius = (self.mouseInfo._downPos - self.mouseInfo._holdPos):length()
    if radius <= 1 then
      radius = 5
    end
    debugDrawer:drawSphere((self.mouseInfo._downPos), radius, ColorF(1,1,1,0.8))
    local normal = (self.mouseInfo._holdPos - self.mouseInfo._downPos):normalized()
    debugDrawer:drawSquarePrism(
      (self.mouseInfo._downPos),
      ((self.mouseInfo._downPos) + radius * normal),
      Point2F(1,radius/2),
      Point2F(0,0),
      ColorF(1,1,1,0.5))
    debugDrawer:drawSquarePrism(
      (self.mouseInfo._downPos),
      ((self.mouseInfo._downPos) + 0.25 * normal),
      Point2F(2,radius*2),
      Point2F(0,0),
      ColorF(1,1,1,0.4))
  else
    if self.mouseInfo.up then
      editor.history:commitAction("Create Manual Note",
      {mouseInfo = deepcopy(self.mouseInfo), index = self.index, self = self,
      normal =(self.mouseInfo._upPos - self.mouseInfo._downPos)},
      function(data) -- undo

        if data.noteId then
          data.self.path.pacenotes:remove(data.noteId)
        end

        data.self:selectPacenote(data.index)
      end,
      function(data) --redo
        local note = data.self.path.pacenotes:create(nil, data.noteId or nil)
        data.noteId = note.id
        local normal = data.normal
        local radius = (data.mouseInfo._downPos - data.mouseInfo._upPos):length()
        if radius <= 1 then
          radius = 5
        end
        note:setManual(data.mouseInfo._downPos, radius, normal )

        data.self:selectPacenote(note.id)
      end)
    end
  end
end


function C:mouseOverPacenotes()
  local minNoteDist = 4294967295
  local closestNote = nil
  for idx, note in pairs(self.path.pacenotes.objects) do
    local distNoteToCam = (note.pos - self.mouseInfo.camPos):length()
    local noteRayDistance = (note.pos - self.mouseInfo.camPos):cross(self.mouseInfo.rayDir):length() / self.mouseInfo.rayDir:length()
    local sphereRadius = note.radius
    if noteRayDistance <= sphereRadius then
      if distNoteToCam < minNoteDist then
        minNoteDist = distNoteToCam
        closestNote = note
      end
    end
  end
  return closestNote
end

function C:input()
  if not self.mouseInfo.valid then return end

  if editor.keyModifiers.shift then
    self:createManualPacenote()
  else
    local selected = self:mouseOverPacenotes()
    if self.mouseInfo.down and not editor.isAxisGizmoHovered() then
      if selected then
        self:selectPacenote(selected.id)
      else
        self:selectPacenote(nil)
      end
    end
  end
end

local function movePacenoteUndo(data) data.self.path.pacenotes:move(data.index, -data.dir) end
local function movePacenoteRedo(data) data.self.path.pacenotes:move(data.index,  data.dir) end

local function setFieldUndo(data) data.self.path.pacenotes.objects[data.index][data.field] = data.old data.self:updateTransform(data.index) end
local function setFieldRedo(data) data.self.path.pacenotes.objects[data.index][data.field] = data.new data.self:updateTransform(data.index) end

local function setNormalUndo(data) data.self.path.pacenotes.objects[data.index]:setNormal(data.old) data.self:updateTransform(data.index) end
local function setNormalRedo(data) data.self.path.pacenotes.objects[data.index]:setNormal(data.new) data.self:updateTransform(data.index) end

function C:drawPacenoteList()
  local avail = im.GetContentRegionAvail()
  im.BeginChild1("keynotes", im.ImVec2(125 * im.uiscale[0], 0 ), im.WindowFlags_ChildWindow)
  for i, note in ipairs(self.path.pacenotes.sorted) do
    if im.Selectable1(note.name, note.id == self.index) then
      editor.history:commitAction("Select Pacenote",
        {old = self.index, new = note.id, self = self},
        selectPacenoteUndo, selectPacenoteRedo)
    end
  end
  im.Separator()
  if im.Selectable1('New...', self.index == nil) then
    self:selectPacenote(nil)
  end
  im.tooltip("Shift-Drag in the world to create a new pacenote.")
  im.EndChild()

  im.SameLine()
  im.BeginChild1("currentPacenote", im.ImVec2(0, 0 ), im.WindowFlags_ChildWindow)
    if self.index then
      local note = self.path.pacenotes.objects[self.index]
      if self.raceEditor.allowGizmo() then
        editor.drawAxisGizmo()
      end
      im.Text("Current Pacenote: #" .. self.index)
      im.SameLine()
      if im.Button("Delete") then
        editor.history:commitAction("Delete Note",
        {index = self.index, self = self},
        function(data) -- undo
          local note = self.path.pacenotes:create(nil, data.noteData.oldId)
          note:onDeserialized(data.noteData)
          self:selectPacenote(data.index)
        end,function(data) --redo
          data.noteData = self.path.pacenotes.objects[data.index]:onSerialize()
          self.path.pacenotes:remove(data.index)
          self:selectPacenote(nil)
        end)
      end
      im.SameLine()
      if im.Button("Move Up") then
        editor.history:commitAction("Move Pacenote in List",
          {index = self.index, self = self, dir = -1},
          movePacenoteUndo, movePacenoteRedo)
      end
      im.SameLine()
      if im.Button("Move Down") then
        editor.history:commitAction("Move Pacenote in List",
          {index = self.index, self = self, dir = 1},
          movePacenoteUndo, movePacenoteRedo)
      end

      im.BeginChild1("self.indexInner", im.ImVec2(0, 0), im.WindowFlags_ChildWindow)
      local editEnded = im.BoolPtr(false)
      editor.uiInputText("Name", nameText, nil, nil, nil, nil, editEnded)
      if editEnded[0] then
        editor.history:commitAction("Change Name of Note",
          {index = self.index, self = self, old = note.name, new = ffi.string(nameText), field = 'name'},
          setFieldUndo, setFieldRedo)
        --note.name = ffi.string(nameText)
      end

      im.Separator()

      pacenotePosition[0] = note.pos.x
      pacenotePosition[1] = note.pos.y
      pacenotePosition[2] = note.pos.z
      if im.InputFloat3("Position", pacenotePosition, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
        editor.history:commitAction("Change note Position",
          {index = self.index, old = note.pos, new = vec3(pacenotePosition[0], pacenotePosition[1], pacenotePosition[2]), field = 'pos', self = self},
          setFieldUndo, setFieldRedo)
      end
      if scenetree.findClassObjects("TerrainBlock") and im.Button("Down to Terrain") then
        editor.history:commitAction("Drop Note to Ground",
          {index = self.index, old = note.pos,self = self, new = vec3(pacenotePosition[0], pacenotePosition[1], core_terrain.getTerrainHeight(note.pos)), field = 'pos'},
          setFieldUndo, setFieldRedo)

      end
      pacenoteRadius[0] = note.radius
      if im.InputFloat("Radius",pacenoteRadius, 0.1, 0.5, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
        if pacenoteRadius[0] < 0 then
          pacenoteRadius[0] = 0
        end
        editor.history:commitAction("Change Note Size",
          {index = self.index, old = note.radius, new = pacenoteRadius[0], self = self, field = 'radius'},
          setFieldUndo, setFieldRedo)
      end


      pacenoteNormal[0] = note.normal.x
      pacenoteNormal[1] = note.normal.y
      pacenoteNormal[2] = note.normal.z
      if im.InputFloat3("Normal", pacenoteNormal, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
        editor.history:commitAction("Change Normal",
          {index = self.index, old = note.normal, self = self, new = vec3(pacenoteNormal[0], pacenoteNormal[1], pacenoteNormal[2])},
          setNormalUndo, setNormalRedo)
      end
      if scenetree.findClassObjects("TerrainBlock") and im.Button("Align Normal with Terrain") then
        local normalTip = note.pos + note.normal*note.radius
        normalTip = vec3(normalTip.x, normalTip.y, core_terrain.getTerrainHeight(normalTip))
        editor.history:commitAction("Align Normal with Terrain",
          {index = self.index, old = note.normal, self = self, new = normalTip - note.pos},
          setNormalUndo, setNormalRedo)
      end

      self:selector('Segment','segment', 'Associated Segment')
      for _, seg in pairs(self.path.segments.objects) do
        seg._drawMode = note.segment == -1 and 'normal' or (note.segment == seg.id and 'normal' or 'faded')
      end

      editEnded = im.BoolPtr(false)
      editor.uiInputText("Note", noteText, nil, nil, nil, nil, editEnded)
      if editEnded[0] then
        editor.history:commitAction("Change Note of Pacenote",
          {index = self.index, self = self, old = note.note, new = ffi.string(noteText), field = 'note'},
          setFieldUndo, setFieldRedo)
        --note.name = ffi.string(nameText)
      end




      im.EndChild()
    end
  im.EndChild()
end


function C:selector(name, fieldName, tt)
  local node = self.path.pacenotes.objects[self.index]
  local objects = self.path.segments.objects


  if im.BeginCombo(name..'##'..fieldName, objects[node[fieldName]].name) then
    if im.Selectable1('#'..0 .. " - None", node[fieldName] == -1) then
      editor.history:commitAction("Removed Segment for pacenote",
        {index = self.index, self = self, old = node[fieldName], new = -1, field = fieldName},
        setFieldUndo, setFieldRedo)
    end
    for i, sp in ipairs(self.path.segments.sorted) do
      if im.Selectable1('#'..i .. " - " .. sp.name, node[fieldName] == sp.id) then
              editor.history:commitAction("Changed Segment for pacenote",
        {index = self.index, self = self, old = node[fieldName], new = sp.id, field = fieldName},
        setFieldUndo, setFieldRedo)
      end
    end
    im.EndCombo()
  end

  im.tooltip(tt or "")
end


return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
