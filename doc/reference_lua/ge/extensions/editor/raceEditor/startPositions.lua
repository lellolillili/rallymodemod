-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui
local spPosition = im.ArrayFloat(3)
local nameText
local C = {}
C.windowDescription = 'Start Positions'

function C:init(raceEditor)
  self.raceEditor = raceEditor
  self.index = nil
end

function C:setPath(path)
  self.path = path
end
function C:selected()
  self.index = nil
  if not self.path then return end
  for _, sp in pairs(self.path.startPositions.objects) do
    sp._drawMode = 'normal'
  end
  editor.editModes.raceEditMode.auxShortcuts[editor.AuxControl_Shift] = "Add New"
end
function C:unselect()
  --self:selectStartPosition(nil)
  for _, sp in pairs(self.path.startPositions.objects) do
    sp._drawMode = 'faded'
  end
  editor.editModes.raceEditMode.auxShortcuts[editor.AuxControl_Shift] = nil
end
function C:selectStartPosition(id)
  self.index = id
  for _, sp in pairs(self.path.startPositions.objects) do
    sp._drawMode = (id == sp.id) and 'highlight' or 'normal'
  end
  if id then
    local sp = self.path.startPositions.objects[id]
    nameText = im.ArrayChar(1024, sp.name)
    self:updateTransform(id)
  end
end

function C:updateTransform(index)
  if not self.raceEditor.allowGizmo() then return end
  local sp = self.path.startPositions.objects[index]
  local rotation = QuatF(0,0,0,1)

  if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local then
    local q = sp.rot
    rotation = QuatF(q.x, q.y, q.z, q.w)
  else
    rotation = QuatF(0, 0, 0, 1)
  end

  local transform = rotation:getMatrix()
  transform:setPosition(sp.pos)
  editor.setAxisGizmoTransform(transform)
end

function C:hoveringStartPosition()
  local minDist = 4294967295
  local closestSP = nil
  for idx, sp in pairs(self.path.startPositions.objects) do
    local distToCam = (sp.pos - self.mouseInfo.camPos):length()
    local rayDistance = (sp.pos - self.mouseInfo.camPos):cross(self.mouseInfo.rayDir):length() / self.mouseInfo.rayDir:length()
    local sphereRadius = 3
    if rayDistance <= sphereRadius then
      if distToCam < minDist then
        minDist = distToCam
        closestSP = sp
      end
    end
  end
  return closestSP
end

function C:input()
  if not self.mouseInfo.valid then return end
  if editor.keyModifiers.shift then
    self:createStartPosition()
  else
    local selected = self:hoveringStartPosition()
    if self.mouseInfo.down and not editor.isAxisGizmoHovered() then
      if selected then
        self:selectStartPosition(selected.id)
      else
        self:selectStartPosition(nil)
      end
    end
  end
end

function C:beginDrag()
  local sp = self.path.startPositions.objects[self.index]
  if sp.missing then return end
  self.beginDragRotation = deepcopy(sp.rot)
  self.beginDragData = sp:onSerialize()
end

function C:dragging()
  local sp = self.path.startPositions.objects[self.index]
  if sp.missing then return end
  -- update/save our gizmo matrix
  if editor.getAxisGizmoMode() == editor.AxisGizmoMode_Translate then
    sp.pos = vec3(editor.getAxisGizmoTransform():getColumn(3))
  elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Rotate then
    local rotation = QuatF(0,0,0,1)
    rotation:setFromMatrix(editor.getAxisGizmoTransform())
    if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local then
      sp.rot = quat(rotation)
    else
      sp.rot = self.beginDragRotation * quat(rotation)
    end
  end
end

function C:endDragging()
  local sp = self.path.startPositions.objects[self.index]
  if sp.missing then return end
  self:addHistory("Moved Start Position by Gizmo", self.beginDragData)
end

local function serializedUndo(data)
  local sp = data.self.path.startPositions.objects[data.index]
  sp:onDeserialized(data.old)
  data.self:selectStartPosition(data.index)
end
local function serializedRedo(data)
  local sp = data.self.path.startPositions.objects[data.index]
  sp:onDeserialized(data.new)
  data.self:selectStartPosition(data.index)
end
function C:addHistory(name, old)
  editor.history:commitAction(name,
    {old = old, new = self.path.startPositions.objects[self.index]:onSerialize(),
    index = self.index, self = self},
    serializedUndo, serializedRedo)
end

function C:createStartPosition()
  if not self.mouseInfo.rayCast then
    return
  end
  local txt = "Add Start Position (Drag for Rotation)"
  debugDrawer:drawTextAdvanced(vec3(self.mouseInfo.rayCast.pos), String(txt), ColorF(1,1,1,1),true, false, ColorI(0,0,0,255))
  if self.mouseInfo.hold then

    local normal = (self.mouseInfo._holdPos - self.mouseInfo._downPos):normalized()

    local q = quatFromDir(normal, vec3(0,0,1))
    local x, y, z = q * vec3(1,0,0), q * vec3(0,3,0), q * vec3(0,0,1)
    debugDrawer:drawSquarePrism(
      vec3(self.mouseInfo._downPos + x),
      vec3(self.mouseInfo._downPos - x),
      Point2F(2,0),
      Point2F(2,0),
      ColorF(1,1,1,0.5))
    debugDrawer:drawSquarePrism(
      vec3(self.mouseInfo._downPos + x),
      vec3(self.mouseInfo._downPos + x - y),
      Point2F(2,0),
      Point2F(0,0),
      ColorF(1,1,1,0.5))
    debugDrawer:drawSquarePrism(
      vec3(self.mouseInfo._downPos - x),
      vec3(self.mouseInfo._downPos - x - y),
      Point2F(2,0),
      Point2F(0,0),
      ColorF(1,1,1,0.5))

  else
    if self.mouseInfo.up then

      editor.history:commitAction("Create Start Position",
      {self = self, index = self.index, mouseInfo = deepcopy(self.mouseInfo)},
      function(data)
        if data.spid then
          data.self.path.startPositions:remove(data.spid)
        end
        data.self:selectStartPosition(nil)
      end,
      function(data)
        local sp = data.self.path.startPositions:create(nil, data.spid or nil)
        sp:set(data.mouseInfo._downPos,
        quatFromDir(data.mouseInfo._upPos - data.mouseInfo._downPos):normalized(), vec3(0,0,1))
        data.spid = sp.id
        data.self:selectStartPosition(sp.id)
      end)

    end
  end
end

function C:onEditModeActivate()
  if self.index then
    self:selectStartPosition(self.index)
  end
end
function C:draw(mouseInfo)
  self.mouseInfo = mouseInfo
  if self.raceEditor.allowGizmo() then
    editor.updateAxisGizmo(function() self:beginDrag() end, function() self:endDragging() end, function() self:dragging() end)
    self:input()
  end
  self:drawStartPositions()
end
local function moveSPUndo(data) data.self.path.startPositions:move(data.index, -data.dir) end
local function moveSPRedo(data) data.self.path.startPositions:move(data.index,  data.dir) end

function C:drawStartPositions()
  local avail = im.GetContentRegionAvail()
  --dumpz(self.path,2)
  im.BeginChild1("sp", im.ImVec2(125 * im.uiscale[0], 0 ), im.WindowFlags_ChildWindow)
  for i, sp in ipairs(self.path.startPositions.sorted) do
    if im.Selectable1(sp.name, sp.id == self.index) then
      self:selectStartPosition(sp.id)
    end
  end
  im.Separator()
  if im.Selectable1('New...', self.index == nil) then
    self:selectStartPosition(nil)
  end
  im.tooltip("Shift-Drag in the world to create a new starting position.")
  im.EndChild()

  im.SameLine()
  im.BeginChild1("currentSP", im.ImVec2(0, 0 ), im.WindowFlags_ChildWindow)
    if self.index then
      local sp = self.path.startPositions.objects[self.index]
      if self.raceEditor.allowGizmo() then
        editor.drawAxisGizmo()
      end
      im.Text("Current Start Position: #" .. self.index)
      im.SameLine()
      if im.Button("Delete") then
        editor.history:commitAction("Delete Start Position",
          {self = self, index = self.index},
          function(data)
            local sp = data.self.path.startPositions:create(nil, data.old.oldId or nil)
            sp:onDeserialized(data.old)
            data.self:selectStartPosition(data.index)
          end,
          function(data)
            data.old = data.self.path.startPositions.objects[data.index]:onSerialize()
            data.self.path.startPositions:remove(data.index)
            data.self:selectStartPosition(nil)
          end)
      end
      im.SameLine()
      if im.Button("Move Up") then
        editor.history:commitAction("Move Start Position in List",
          {index = self.index, self = self, dir = -1},
          moveSPUndo, moveSPRedo)
      end
      im.SameLine()
      if im.Button("Move Down") then
        editor.history:commitAction("Move Start Position in List",
          {index = self.index, self = self, dir = 1},
          moveSPUndo, moveSPRedo)
      end

      im.BeginChild1("self.indexInner", im.ImVec2(0, 0), im.WindowFlags_ChildWindow)
      local editEnded = im.BoolPtr(false)
      editor.uiInputText("Name", nameText, nil, nil, nil, nil, editEnded)
      if editEnded[0] then
        local old = sp:onSerialize()
        sp.name = ffi.string(nameText)
        self:addHistory("Renamed Start Position", old)
      end

      spPosition[0] = sp.pos.x
      spPosition[1] = sp.pos.y
      spPosition[2] = sp.pos.z
      if im.InputFloat3("Position", spPosition, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
        local old = sp:onSerialize()
        sp.pos = vec3(spPosition[0], spPosition[1], spPosition[2])
        self:updateTransform(self.index)
        self:addHistory("Moved Start Position", old)
      end
      if scenetree.findClassObjects("TerrainBlock") and im.Button("Down to Terrain") then
        local old = sp:onSerialize()
        sp.pos = vec3(spPosition[0], spPosition[1], core_terrain.getTerrainHeight(sp.pos))
        self:updateTransform(self.index)
        self:addHistory("Dropped Start Position to Terrain", old)
      end
      if scenetree.findClassObjects("TerrainBlock") and im.Button("Align with Terrain") then
        local old = sp:onSerialize()
        local normalTip = sp.pos + sp.rot*vec3(0,-4.5, 0)
        normalTip = vec3(normalTip.x, normalTip.y, core_terrain.getTerrainHeight(normalTip))
        sp.rot = quatFromDir((sp.pos - normalTip):normalized(), vec3(0,0,1))
        self:updateTransform(self.index)
        self:addHistory("Aligned Start Position with Terrain", old)
      end
      if im.Button("Move Veh To") then
        sp:moveResetVehicleTo(be:getPlayerVehicleID(0))
      end
      if im.Button("Set to Current Vehicle") then
        sp:setToVehicle(be:getPlayerVehicleID(0))
      end
      im.EndChild()
    end
  im.EndChild()
end



return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
