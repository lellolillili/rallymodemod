-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui
local nameText = im.ArrayChar(1024, "")
local capsulePosition = im.ArrayFloat(3)
local capsuleRadius = im.FloatPtr(0)

local C = {}
C.windowDescription = 'Segments'

function C:init(raceEditor)
  self.raceEditor = raceEditor
  self.index = nil
  self.capsuleIndex = nil
end

function C:setPath(path)
  self.path = path
end

function C:selected()
  self.index = nil
  self.capsuleIndex = nil
  if not self.path then return end
  for _, seg in pairs(self.path.segments.objects) do
    seg._drawMode = 'normal'
  end
end
function C:unselect()
  --self:selectSegment(nil)
  for _, seg in pairs(self.path.segments.objects) do
    seg._drawMode = 'faded'
  end
  editor.editModes.raceEditMode.auxShortcuts[editor.AuxControl_Shift] = nil
  editor.editModes.raceEditMode.auxShortcuts[editor.AuxControl_Alt] = nil
end

function C:selectSegment(index)
  self.index = index
  self.capsuleIndex = nil
  for _, seg in pairs(self.path.segments.objects) do
    seg._drawMode = (index == seg.id) and 'highlight' or 'normal'
  end
  if index then
    nameText = im.ArrayChar(1024, self.path.segments.objects[self.index].name)
    editor.editModes.raceEditMode.auxShortcuts[editor.AuxControl_Shift] = "Set Target"
    editor.editModes.raceEditMode.auxShortcuts[editor.AuxControl_Alt] = "Set Source"
  else
    editor.editModes.raceEditMode.auxShortcuts[editor.AuxControl_Shift] = nil
    editor.editModes.raceEditMode.auxShortcuts[editor.AuxControl_Alt] = nil
  end

  for _, n in pairs(self.path.pacenotes.objects) do
    if index and index ~= -1 and n.segment == index then
      n._drawMode = 'normal'
    else
      n._drawMode = 'none'
    end
  end
end

function C:selectCapsule(index)
  self.capsuleIndex = index
  self:updateTransform()
end

function C:updateTransform()
  if not self.raceEditor.allowGizmo() then return end
  if not self.capsuleIndex then return end
  local cap = self.path.segments.objects[self.index].capsulePoints[self.capsuleIndex]
  if cap then
    local rotation = QuatF(0,0,0,1)

    local transform = rotation:getMatrix()
    transform:setPosition(cap.pos)
    editor.setAxisGizmoTransform(transform)
  end
end

function C:beginDrag()
  if not self.capsuleIndex then return end
  local cap = self.path.segments.objects[self.index].capsulePoints[self.capsuleIndex]
  self.beginDragRadius = cap.radius
  self.beginDragSegmentData = self.path.segments.objects[self.index]:onSerialize()
end

function C:dragging()
  if not self.capsuleIndex then return end
  local cap = self.path.segments.objects[self.index].capsulePoints[self.capsuleIndex]
  -- update/save our gizmo matrix
  if editor.getAxisGizmoMode() == editor.AxisGizmoMode_Translate then
    cap.pos = vec3(editor.getAxisGizmoTransform():getColumn(3))
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
    cap.radius = self.beginDragRadius * scl
  end
end

function C:endDragging()
  if not self.capsuleIndex then return end
  editor.history:commitAction("Manipulated Capsule Node via Gizmo",
    {old = self.beginDragSegmentData,
     new = self.path.segments.objects[self.index]:onSerialize(),
     index = self.index, capIndex = self.capsuleIndex,
     self = self
   }, serializedUndo, serializedRedo)
end

local function serializedUndo(data)
  local seg = data.self.path.segments.objects[data.index]
  seg:onDeserialized(data.old)
  data.self:selectSegment(data.index)
  data.self:selectCapsule(data.capIndex)
end
local function serializedRedo(data)
  local seg = data.self.path.segments.objects[data.index]
  seg:onDeserialized(data.new)
  data.self:selectSegment(data.index)
  data.self:selectCapsule(data.capIndex)
end

function C:addHistory(name, old)
  editor.history:commitAction(name,
   {old = old, new = self.path.segments.objects[self.index]:onSerialize(),
    index = self.index, capIndex = self.capsuleIndex, self = self},
    serializedUndo, serializedRedo)
end

function C:draw(mouseInfo)
  self.mouseInfo = mouseInfo
  if self.raceEditor.allowGizmo() then
    editor.updateAxisGizmo(function() self:beginDrag() end, function() self:endDragging() end, function() self:dragging() end)
    self:input()
  end
  self:drawSegmentList()
end

function C:input()
  if not self.mouseInfo.valid then return end
  if not self.index then return end
  local active = false

  local txt = nil
  if editor.keyModifiers.alt then
    txt = "Click to set source of segment."
  end
  if editor.keyModifiers.shift then
    txt = "Click to set target of segment."
  end
  if txt then
    local selected = self.mouseInfo.closestNodeHovered
    if selected then
      txt = txt .. " (" .. selected.name..")"
    else
      txt = txt .. " No node hovered."
    end
    debugDrawer:drawTextAdvanced((vec3(self.mouseInfo.rayCast.pos)), String(txt), ColorF(1,1,1,1),true, false, ColorI(0,0,0,255))
    if selected then
      if self.mouseInfo.down  then
        local old = self.path.segments.objects[self.index]:onSerialize()
        if editor.keyModifiers.alt then
          self.path.segments.objects[self.index]:setFrom(selected.id)
          self:addHistory("Changed Source of Segment",old)
        elseif editor.keyModifiers.shift then
          self.path.segments.objects[self.index]:setTo(selected.id)
          self:addHistory("Changed Target of Segment",old)
        end
      end
    end
  end

  local segment = self.path.segments.objects[self.index]

  if segment.mode == 'capsules' then
    local closest = nil
    for i, cap in ipairs(segment.capsulePoints) do
      local dist = self:mouseDistanceTo(cap, self.mouseInfo)
      if dist > 0 and (not closest or closest.dist > dist) then
        closest = {dist = dist, index = i}
      end
    end
    if closest and self.mouseInfo.down then
      self:selectCapsule(closest.index)
    end

    closest = nil
    if editor.keyModifiers.ctrl then
      for i = 1, segment:getCapsuleCount()-1 do
        local a, b = segment:getCapsuleNode(i), segment:getCapsuleNode(i+1)
        local center = (a.pos+b.pos)/2
        debugDrawer:drawSphere((center), 3, ColorF(1,1,0.2,0.75))
        local dist = self:mouseDistanceTo({pos = center, radius = 3}, self.mouseInfo)
        if dist > 0 and (not closest or closest.dist > dist) then
          closest = {pos = center, radius = (a.radius+b.radius)/2, index = i, dist = dist}
        end
      end
      if closest then
        if self.mouseInfo.down then
          local old = segment:onSerialize()
          segment:addCapsule(closest.pos, closest.radius,"new capsulepoint", closest.index)
          self:selectCapsule(closest.index)
          self:addHistory("Added Capsule", old)
        end
      end
    end
  end
end

function C:mouseDistanceTo(point, mouseInfo)
  local minNodeDist = 4294967295

  local distNodeToCam = (point.pos - mouseInfo.camPos):length()
  local nodeRayDistance = (point.pos - mouseInfo.camPos):cross(mouseInfo.rayDir):length() / mouseInfo.rayDir:length()
  local sphereRadius = point.radius
  if nodeRayDistance <= sphereRadius then
    if distNodeToCam < minNodeDist then
      return distNodeToCam
    end
  end
  return -1
end

local function moveSegmentUndo(data) data.self.path.segments:move(data.index, -data.dir) end
local function moveSegmentRedo(data) data.self.path.segments:move(data.index,  data.dir) end

function C:drawSegmentList()
  local avail = im.GetContentRegionAvail()
  im.BeginChild1("segments", im.ImVec2(125 * im.uiscale[0], 0), im.WindowFlags_ChildWindow)
  for i, segment in ipairs(self.path.segments.sorted) do
    local problem = (segment:getFrom().missing or segment:getTo().missing) and " (!)" or ""
    if im.Selectable1(segment.name .. problem, segment.id == self.index) then
      self:selectSegment(segment.id)
    end
  end
  im.Separator()
  if im.Selectable1('Create', false) then
    editor.history:commitAction("Create Segment",
      {self = self, index = self.index},
      function(data)
        if data.segId then
          data.self.path.segments:remove(data.segId)
        end
        data.self:selectSegment(data.index)
      end,
      function(data)
        local seg = data.self.path.segments:create(nil, data.segId or nil)
        data.segId = seg.id
        data.self:selectSegment(seg.id)
      end)
  end
  im.EndChild()

  im.SameLine()
  im.BeginChild1("currentSegment", im.ImVec2(0, 0), im.WindowFlags_ChildWindow)
    if self.index then
      local segment = self.path.segments.objects[self.index]
      im.Text("Current Segment: #" .. self.index)
      im.SameLine()
      if im.Button("Delete") then
        editor.history:commitAction("Delete Segment",
          {self = self, index = self.index},
          function(data)
            local seg = data.self.path.segments:create(nil, data.old.oldId or nil)
            seg:onDeserialized(data.old)
            data.self:selectSegment(data.index)
          end,
          function(data)
            data.old = data.self.path.segments.objects[data.index]:onSerialize()
            data.self.path.segments:remove(data.index)
            data.self:selectSegment(nil)
          end)
      end
      im.SameLine()
      if im.Button("Move Up") then
        editor.history:commitAction("Move Segment in List",
          {index = self.index, self = self, dir = -1},
          moveSegmentUndo, moveSegmentRedo)
      end
      im.SameLine()
      if im.Button("Move Down") then
        editor.history:commitAction("Move Segment in List",
          {index = self.index, self = self, dir = 1},
          moveSegmentUndo, moveSegmentRedo)
      end
      im.BeginChild1("currentSegmentInner", im.ImVec2(0, 0), im.WindowFlags_ChildWindow)
      local editEnded = im.BoolPtr(false)
      editor.uiInputText("Name", nameText, nil, nil, nil, nil, editEnded)
      if editEnded[0] then
        local old = segment:onSerialize()
        segment.name = ffi.string(nameText)
        self:addHistory("Changed Name of Segment", old)
      end

      if im.BeginCombo("From:##fromSegment", segment:getFrom().name) then
        for i, node in ipairs(self.path.pathnodes.sorted) do
          if im.Selectable1('#'..i .. " - " .. node.name, segment:getFrom().id == node.id) then
            local old = segment:onSerialize()
            segment:setFrom(node.id)
            self:addHistory("Changed Source of Segment", old)
          end
        end
        im.EndCombo()
      end
      if im.BeginCombo("To:##fromSegment", segment:getTo().name) then
        for i, node in ipairs(self.path.pathnodes.sorted) do
          if im.Selectable1('#'..i .. " - " .. node.name, segment:getTo().id == node.id) then
            local old = segment:onSerialize()
            segment:setTo(node.id)
            self:addHistory("Changed Target of Segment", old)
          end
        end
        im.EndCombo()
      end
      if im.BeginCombo("Mode:##fromSegment", segment.mode) then
        local newMode = nil
        if im.Selectable1('waypoint', segment.mode == 'waypoint') then
          newMode = 'waypoint'
        end
        if im.Selectable1('capsules', segment.mode == 'capsules') then
          newMode = 'capsules'
        end
        if segment:getBeNavpath() and im.Selectable1('navpath', segment.mode == 'navpath') then
          newMode = 'navpath'
        end
        if newMode then
          local old = segment:onSerialize()
          segment:setMode(newMode)
          self:addHistory("Changed Mode of Segment", old)
          end
        im.EndCombo()
      end
      if segment.mode == 'capsules' then
        im.BeginChild1("capsules", im.ImVec2(125 * im.uiscale[0], 0), im.WindowFlags_ChildWindow)
        for i, cap in ipairs(segment.capsulePoints) do
          if im.Selectable1("# " .. i, i == self.capsuleIndex) then
            self:selectCapsule(i)
            self:updateTransform()
          end
        end
        if #segment.capsulePoints == 0 then
          if im.Selectable1("Create", false) then
            local old = segment:onSerialize()
            segment:addCapsule(
              (segment:getFrom().pos + segment:getTo().pos)/2,
              (segment:getFrom().radius + segment:getTo().radius)/2,
              "new capsulepoint",
              1)
            self:selectCapsule(1)
            self:addHistory("Added Capsule", old)
          end
        end
        im.EndChild()
        im.SameLine()
        im.BeginChild1("currentCapsule", im.ImVec2(0, 0), im.WindowFlags_ChildWindow)
        local cap = segment.capsulePoints[self.capsuleIndex]
        if cap then
          if self.raceEditor.allowGizmo() then
            editor.drawAxisGizmo()
          end
          capsulePosition[0] = cap.pos.x
          capsulePosition[1] = cap.pos.y
          capsulePosition[2] = cap.pos.z
          if im.InputFloat3("Position", capsulePosition, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
            local old = segment:onSerialize()
            cap.pos = vec3(capsulePosition[0], capsulePosition[1], capsulePosition[2])
            self:updateTransform()
            self:addHistory("Moved Capsule", old)
          end

          capsuleRadius[0] = cap.radius
          if im.InputFloat("Radius", capsuleRadius, 0.1, 0.5, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
            local old = segment:onSerialize()
            if capsuleRadius[0] < 0 then
              capsuleRadius[0] = 0
            end
            cap.radius = capsuleRadius[0]
            self:updateTransform()
            self:addHistory("Scaled Capsule", old)
          end

          if im.Button("Add Before") then
            local old = segment:onSerialize()
            segment:addCapsule(
              (segment:getCapsuleNode(self.capsuleIndex).pos + segment:getCapsuleNode(self.capsuleIndex+1).pos)/2,
              (segment:getCapsuleNode(self.capsuleIndex).radius + segment:getCapsuleNode(self.capsuleIndex+1).radius)/2,
              "new capsulepoint",
              self.capsuleIndex)
            self:selectCapsule(self.capsuleIndex)
            self:addHistory("Added Capsule", old)
          end
          im.SameLine()
          if im.Button("Add After") then
            local old = segment:onSerialize()
            segment:addCapsule(
              (segment:getCapsuleNode(self.capsuleIndex+1).pos + segment:getCapsuleNode(self.capsuleIndex+2).pos)/2,
              (segment:getCapsuleNode(self.capsuleIndex+1).radius + segment:getCapsuleNode(self.capsuleIndex+2).radius)/2,
              "new capsulepoint",
              self.capsuleIndex+1)
            self:selectCapsule(self.capsuleIndex+1)
            self:addHistory("Added Capsule", old)
          end
          im.SameLine()
          if im.Button("Remove") then
            local old = segment:onSerialize()
            segment:removeCapsule(self.capsuleIndex)
            if #segment.capsulePoints == 0 then
              self:selectCapsule(nil)
            elseif self.capsuleIndex > #segment.capsulePoints then
              self:selectCapsule(#segment.capsulePoints)
            else
              self:selectCapsule(self.capsuleIndex)
            end
            self:addHistory("Added Capsule", old)
          end
        end
        im.EndChild()
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
