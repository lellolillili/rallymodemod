-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui
local pathnodePosition = im.ArrayFloat(3)
local pathnodeNormal = im.ArrayFloat(3)
local pathnodeRadius = im.FloatPtr(0)
local nameText = im.ArrayChar(1024, "")

local C = {}
C.windowDescription = 'Pathnodes'

local function selectPathnodeUndo(data) data.self:selectPathnode(data.old) end
local function selectPathnodeRedo(data) data.self:selectPathnode(data.new) end

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
  for _, n in pairs(self.path.pathnodes.objects) do
    n._drawMode = 'normal'
  end
  editor.editModes.raceEditMode.auxShortcuts[editor.AuxControl_Shift] = "Add New"
  self.map = map.getMap()
  self.fields = {}
  self.addFieldText = im.ArrayChar(256, "")
end
function C:unselect()
  --self:selectPathnode(nil)
  for _, n in pairs(self.path.pathnodes.objects) do
    n._drawMode = 'faded'
  end
  editor.editModes.raceEditMode.auxShortcuts[editor.AuxControl_Shift] = nil
  self.fields = {}
  self.addFieldText = im.ArrayChar(256, "")
end

function C:selectPathnode(id)
  self.index = id
  for _, node in pairs(self.path.pathnodes.objects) do
    node._drawMode = (id == node.id) and 'highlight' or 'normal'
  end
  if id then
    local node = self.path.pathnodes.objects[id]
    nameText = im.ArrayChar(1024, node.name)
    self:updateTransform(id)
  end
  self.fields = {}
  self.addFieldText = im.ArrayChar(256, "")
end

function C:updateTransform(index)
  if not self.raceEditor.allowGizmo() then return end
  local node = self.path.pathnodes.objects[index]
  local rotation = QuatF(0,0,0,1)

  if node.hasNormal then
    if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local then
      local q = quatFromDir(node.normal, vec3(0,0,1))
      rotation = QuatF(q.x, q.y, q.z, q.w)
    else
      rotation = QuatF(0, 0, 0, 1)
    end
  end

  local transform = rotation:getMatrix()
  transform:setPosition(node.pos)
  editor.setAxisGizmoTransform(transform)
end


function C:beginDrag()
  local node = self.path.pathnodes.objects[self.index]
  if not node or node.missing then return end
  self.beginDragNodeData = node:onSerialize()
  if node.normal then
    self.beginDragRotation = deepcopy(quatFromDir(node.normal, vec3(0,0,1)))
  end

  self.beginDragRadius = node.radius
  if node.mode == 'navgraph' then
    self.beginDragRadius = node.navRadiusScale
  end
end

function C:dragging()
  local node = self.path.pathnodes.objects[self.index]
  if not node or node.missing then return end

  -- update/save our gizmo matrix
  if editor.getAxisGizmoMode() == editor.AxisGizmoMode_Translate then
    if node.mode == 'manual' then
      node.pos = vec3(editor.getAxisGizmoTransform():getColumn(3))
    elseif node.mode == 'navgraph' then
      debugDrawer:drawTextAdvanced((node.pos),
        "Set node to manual to move via Gizmo.",
        ColorF(1,1,1,1),true, false, ColorI(0,0,0,255))
    end
  elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Rotate then
    if not node.hasNormal then
      debugDrawer:drawTextAdvanced((node.pos),
        "This node has no normal to edit.",
        ColorF(1,1,1,1),true, false, ColorI(0,0,0,255))
    else
      local gizmoTransform = editor.getAxisGizmoTransform()
      local rotation = QuatF(0,0,0,1)
      if node.normal then
        rotation:setFromMatrix(gizmoTransform)

        if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local then
          node.normal = quat(rotation)*vec3(0,1,0)
        else
          node.normal = self.beginDragRotation * quat(rotation)*vec3(0,1,0)
        end
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
    if node.mode == 'manual' then
      node.radius = self.beginDragRadius * scl
    elseif node.mode == 'navgraph' then
      node:setNavRadiusScale(beself.beginDragRadiusginDragRadius * scl)
    end
  end
end

function C:endDragging()
  local node = self.path.pathnodes.objects[self.index]
  if not node or node.missing then return end
  editor.history:commitAction("Manipulated Node via Gizmo",
    {old = self.beginDragNodeData,
     new = node:onSerialize(),
     index = self.index, self = self},
    function(data) -- undo
      local node = self.path.pathnodes.objects[data.index]
      node:onDeserialized(data.old)
      data.self:selectPathnode(data.index)
    end,
    function(data) --redo
      local node = self.path.pathnodes.objects[data.index]
      node:onDeserialized(data.new)
      data.self:selectPathnode(data.index)
    end)
end

function C:onEditModeActivate()
  if self.node then
    self:selectPathnode(self.node.id)
  end
end

function C:draw(mouseInfo)
  self.mouseInfo = mouseInfo
  if self.raceEditor.allowGizmo() then
    editor.updateAxisGizmo(function() self:beginDrag() end, function() self:endDragging() end, function() self:dragging() end)
    self:input()
  end
  self:drawPathnodeList()
end

function C:createManualPathnode()
  if not self.mouseInfo.rayCast then
    return
  end
  local txt = "Add manual Pathnode (Drag for Size)"
  debugDrawer:drawTextAdvanced(vec3(self.mouseInfo.rayCast.pos), String(txt), ColorF(1,1,1,1),true, false, ColorI(0,0,0,255))
  if self.mouseInfo.hold then

    local radius = (self.mouseInfo._downPos - self.mouseInfo._holdPos):length()
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
      editor.history:commitAction("Create Manual Node",
      {mouseInfo = deepcopy(self.mouseInfo), index = self.index, self = self,
      normal = editor.getPreference("raceEditor.general.directionalNodes") and (self.mouseInfo._upPos - self.mouseInfo._downPos)},
      function(data) -- undo

        if data.nodeId then
          data.self.path.pathnodes:remove(data.nodeId)
        end
        if data.segId then
          data.self.path.segments:remove(data.segId)
        end
        data.self:selectPathnode(data.index)
      end,
      function(data) --redo
        local node = data.self.path.pathnodes:create(nil, data.nodeId or nil)
        data.nodeId = node.id
        local normal = data.normal
        node:setManual(data.mouseInfo._downPos, (data.mouseInfo._downPos - data.mouseInfo._upPos):length(), normal )
        if data.index ~= nil then
          local seg = data.self.path.segments:create(nil, data.segId or nil)
          seg:setFrom(data.index)
          seg:setTo(node.id)
          data.segId = seg.id
        end
        data.self:selectPathnode(node.id)
      end)
    end
  end
end

function C:selectNavgraphNode()
  local color = ColorF(1,1,1,0.1)
  local radScale = 1
  if self.mouseInfo.rayCast and self.mouseInfo.rayCast.pos and not im.GetIO().WantCaptureMouse then
    local txt = "Add Pathnode from Navgraph"
    debugDrawer:drawTextAdvanced((vec3(self.mouseInfo.rayCast.pos)), String(txt), ColorF(1,1,1,1),true, false, ColorI(0,0,0,255))
  end
  local target = nil
  local minNodeDist = 4294967295
  for name, n in pairs(map.getManualWaypoints()) do
    local node = self.map.nodes[name]
    if node then
      local distNodeToCam = (node.pos - self.mouseInfo.camPos):length()
      color = ColorF(1,0.5,0.2,0.5)
      radScale = 0.8
    --if distNodeToCam < minNodeDist then
      --color.alpha = 0.75
      local nodeRayDistance = (node.pos - self.mouseInfo.camPos):cross(self.mouseInfo.rayDir):length() / self.mouseInfo.rayDir:length()
      color.alpha = color.alpha + clamp((50-nodeRayDistance)/50,0,1) * 0.2
      local sphereRadius = node.radius
      if nodeRayDistance <= sphereRadius then
        if distNodeToCam < minNodeDist then
          minNodeDist = distNodeToCam
          target = {name = name, node = node}
          radScale = 1
        end
      end
      debugDrawer:drawSphere(node.pos, node.radius*radScale, color)
    end
  end

  if target then
    debugDrawer:drawSphere(target.node.pos, target.node.radius, ColorF(1,1,1,1))
    if self.mouseInfo.down then

      editor.history:commitAction("Create Navgraph Node",
      {index = self.index, self = self, target = target},
      function(data) -- undo

        if data.nodeId then
          data.self.path.pathnodes:remove(data.nodeId)
        end
        if data.segId then
          data.self.path.segments:remove(data.segId)
        end
        data.self:selectPathnode(data.index)
      end,
      function(data) --redo
        local node = data.self.path.pathnodes:create(nil, data.nodeId or nil)
        data.nodeId = node.id
        node:setNavgraph(target.name)
        if data.index ~= nil then
          local seg = data.self.path.segments:create(nil, data.segId or nil)
          seg:setFrom(data.index)
          seg:setTo(node.id)
          if seg:getFrom().mode == 'navgraph' and seg:getTo().mode == 'navgraph' then
            seg:setMode('navpath')
          end
          data.segId = seg.id
        end
        data.self:selectPathnode(node.id)
      end)
    end
  end
end

function C:mouseOverPathnodes()
  local minNodeDist = 4294967295
  local closestNode = nil
  for idx, node in pairs(self.path.pathnodes.objects) do
    local distNodeToCam = (node.pos - self.mouseInfo.camPos):length()
    local nodeRayDistance = (node.pos - self.mouseInfo.camPos):cross(self.mouseInfo.rayDir):length() / self.mouseInfo.rayDir:length()
    local sphereRadius = node.radius
    if nodeRayDistance <= sphereRadius then
      if distNodeToCam < minNodeDist then
        minNodeDist = distNodeToCam
        closestNode = node
      end
    end
  end
  return closestNode
end

function C:input()
  if not self.mouseInfo.valid then return end
  if editor.keyModifiers.alt then
    self:selectNavgraphNode()
  elseif editor.keyModifiers.shift then
    self:createManualPathnode()
  else
    local selected = self:mouseOverPathnodes()
    if self.mouseInfo.down and not editor.isAxisGizmoHovered() then
      if selected then
        self:selectPathnode(selected.id)
      else
        self:selectPathnode(nil)
      end
    end
  end
end

local function movePathnodeUndo(data) data.self.path.pathnodes:move(data.index, -data.dir) end
local function movePathnodeRedo(data) data.self.path.pathnodes:move(data.index,  data.dir) end

local function setFieldUndo(data) data.self.path.pathnodes.objects[data.index][data.field] = data.old data.self:updateTransform(data.index) end
local function setFieldRedo(data) data.self.path.pathnodes.objects[data.index][data.field] = data.new data.self:updateTransform(data.index) end

local function setNormalUndo(data) data.self.path.pathnodes.objects[data.index]:setNormal(data.old) data.self:updateTransform(data.index) end
local function setNormalRedo(data) data.self.path.pathnodes.objects[data.index]:setNormal(data.new) data.self:updateTransform(data.index) end

function C:drawPathnodeList()
  local avail = im.GetContentRegionAvail()
  im.BeginChild1("keynodes", im.ImVec2(125 * im.uiscale[0], 0 ), im.WindowFlags_ChildWindow)
  for i, node in ipairs(self.path.pathnodes.sorted) do
    if im.Selectable1(node.name, node.id == self.index) then
      editor.history:commitAction("Select Pathnode",
        {old = self.index, new = node.id, self = self},
        selectPathnodeUndo, selectPathnodeRedo)
    end
  end
  im.Separator()
  if im.Selectable1('New...', self.index == nil) then
    self:selectPathnode(nil)
  end
  im.tooltip("Shift-Drag in the world to create a new pathnode.")
  im.EndChild()

  im.SameLine()
  im.BeginChild1("currentPathnode", im.ImVec2(0, 0 ), im.WindowFlags_ChildWindow)
    if self.index then
      local node = self.path.pathnodes.objects[self.index]
      if self.raceEditor.allowGizmo() then
        editor.drawAxisGizmo()
      end
      im.Text("Current Pathnode: #" .. self.index)
      im.SameLine()
      if im.Button("Delete") then
        editor.history:commitAction("Delete Node",
        {index = self.index, self = self},
        function(data) -- undo
          local node = self.path.pathnodes:create(nil, data.nodeData.oldId)
          node:onDeserialized(data.nodeData)
          self:selectPathnode(data.index)
        end,function(data) --redo
          data.nodeData = self.path.pathnodes.objects[data.index]:onSerialize()
          self.path.pathnodes:remove(data.index)
          self:selectPathnode(nil)
        end)
      end
      im.SameLine()
      if im.Button("Move Up") then
        editor.history:commitAction("Move Pathnode in List",
          {index = self.index, self = self, dir = -1},
          movePathnodeUndo, movePathnodeRedo)
      end
      im.SameLine()
      if im.Button("Move Down") then
        editor.history:commitAction("Move Pathnode in List",
          {index = self.index, self = self, dir = 1},
          movePathnodeUndo, movePathnodeRedo)
      end

      im.BeginChild1("self.indexInner", im.ImVec2(0, 0), im.WindowFlags_ChildWindow)
      local editEnded = im.BoolPtr(false)
      editor.uiInputText("Name", nameText, nil, nil, nil, nil, editEnded)
      if editEnded[0] then
        editor.history:commitAction("Change Name of Node",
          {index = self.index, self = self, old = node.name, new = ffi.string(nameText), field = 'name'},
          setFieldUndo, setFieldRedo)
        --node.name = ffi.string(nameText)
      end
      im.Text("Mode: " .. node.mode)
      im.SameLine()
      if im.Button("Toggle Mode") then
        if node.mode == 'navgraph' then
          editor.history:commitAction("Change Node Mode",
          {index = self.index, self = self, oldData = node:onSerialize()},
          function(data)
            data.self.path.pathnodes.objects[data.index]:onDeserialized(data.oldData)
            data.self:updateTransform(data.index)
          end, function(data)
            local node = data.self.path.pathnodes.objects[data.index]
            node:setManual(node.pos, node.radius, node.normal)
            data.self:updateTransform(data.index)
          end)
        else
          -- find the closest manual WP to set this node to.
          local wps = {}
          for name, node in pairs(map.getManualWaypoints()) do
            local nd = self.map.nodes[name]
            if nd then
              table.insert(wps, {name = name, node = nd})
            end
          end
          if #wps > 0 then
            table.sort(wps, function(a,b) return (a.node.pos - node.pos):length() < (b.node.pos - node.pos):length() end)
            editor.history:commitAction("Change Node Mode",
              {index = self.index, node = node, self = self, oldData = node:onSerialize(), wpName = wps[1].name},
              function(data)
                data.self.path.pathnodes.objects[data.index]:onDeserialized(data.oldData)
                data.self:updateTransform(data.index)
              end, function(data)
                data.self.path.pathnodes.objects[data.index]:setNavgraph(data.wpName)
                data.self:updateTransform(data.index)
              end)
          end
        end
      end
      im.Separator()
      if node.mode == "navgraph" then
        if im.Button("Load Navgraph") then
          sortedWaypointsNames = {}
          for n,_ in pairs(map.getManualWaypoints()) do
            table.insert(sortedWaypointsNames,n)
          end
          table.sort(sortedWaypointsNames)
        end
        if im.BeginCombo("Target:##fromSegment", node.navgraphName) then
          for _, name in pairs(sortedWaypointsNames or {}) do
            local nd = self.map.nodes[name]
            if nd then
              if im.Selectable1(name, name == node.navgraphName) then
                editor.history:commitAction("Change Node Mode",
                  {index = self.index, self = self, oldData = node:onSerialize(), wpName = wps[1].name},
                  function(data)
                    data.self.path.pathnodes.objects[data.index]:onDeserialized(data.oldData)
                    data.self:updateTransform(data.index)
                  end, function(data)
                    data.self.path.pathnodes.objects[data.index]:setNavgraph(data.wpName)
                    data.self:updateTransform(data.index)
                  end)
                  end
              if im.IsItemHovered() then
                local pos = node.pos
                debugDrawer:drawTextAdvanced((pos), String(">>>"..name.."<<<"), ColorF(1,1,1,1),true, false, ColorI(0,0,0,255))
                debugDrawer:drawCylinder((pos + vec3(0,0,-10000)), (pos + vec3(0,0,10000)), 1, ColorF(1,1,1,0.8))
              end
            end
          end
          im.EndCombo()
        end
        pathnodeRadius[0] = node.navRadiusScale
        if im.InputFloat("Radius Multiplier",pathnodeRadius, 0.01, 0.1, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
          if pathnodeRadius[0] < 0 then
            pathnodeRadius[0] = 0
          end
          editor.history:commitAction("Change Node Mode",
            {index = self.index, self = self, old = node.navRadiusScale, new = pathnodeRadius[0]},
            function(data)
              data.self.path.pathnodes.objects[data.index]:setNavRadiusScale(data.old)
              data.self:updateTransform(data.index)
            end, function(data)
              data.self.path.pathnodes.objects[data.index]:setNavRadiusScale(data.new)
              data.self:updateTransform(data.index)
            end)
        end
      else
        pathnodePosition[0] = node.pos.x
        pathnodePosition[1] = node.pos.y
        pathnodePosition[2] = node.pos.z
        if im.InputFloat3("Position", pathnodePosition, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
          editor.history:commitAction("Change node Position",
            {index = self.index, old = node.pos, new = vec3(pathnodePosition[0], pathnodePosition[1], pathnodePosition[2]), field = 'pos', self = self},
            setFieldUndo, setFieldRedo)
        end
        if scenetree.findClassObjects("TerrainBlock") and im.Button("Down to Terrain") then
          editor.history:commitAction("Drop Node to Ground",
            {index = self.index, old = node.pos,self = self, new = vec3(pathnodePosition[0], pathnodePosition[1], core_terrain.getTerrainHeight(node.pos)), field = 'pos'},
            setFieldUndo, setFieldRedo)

        end
        pathnodeRadius[0] = node.radius
        if im.InputFloat("Radius",pathnodeRadius, 0.1, 0.5, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
          if pathnodeRadius[0] < 0 then
            pathnodeRadius[0] = 0
          end
          editor.history:commitAction("Change Node Size",
            {index = self.index, old = node.radius, new = pathnodeRadius[0], self = self, field = 'radius'},
            setFieldUndo, setFieldRedo)
        end
      end
      local useNormal = im.BoolPtr(node.hasNormal)
      if im.Checkbox("Use Normal", useNormal) then
        local new = nil
        if useNormal[0] then
          new = quat(getCameraQuat())*vec3(0,1,0)
          local tip = node.pos + new*node.radius
          new = vec3(tip.x, tip.y, core_terrain.getTerrainHeight(tip))-node.pos
        end
        editor.history:commitAction("Change Normal",
          {index = self.index, old = node.normal, new = new ,self = self},
          setNormalUndo, setNormalRedo)
      end
      if node.hasNormal then
        pathnodeNormal[0] = node.normal.x
        pathnodeNormal[1] = node.normal.y
        pathnodeNormal[2] = node.normal.z
        if im.InputFloat3("Normal", pathnodeNormal, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
          editor.history:commitAction("Change Normal",
            {index = self.index, old = node.normal, self = self, new = vec3(pathnodeNormal[0], pathnodeNormal[1], pathnodeNormal[2])},
            setNormalUndo, setNormalRedo)
        end
        if scenetree.findClassObjects("TerrainBlock") and im.Button("Align Normal with Terrain") then
          local normalTip = node.pos + node.normal*node.radius
          normalTip = vec3(normalTip.x, normalTip.y, core_terrain.getTerrainHeight(normalTip))
          editor.history:commitAction("Align Normal with Terrain",
            {index = self.index, old = node.normal, self = self, new = normalTip - node.pos},
            setNormalUndo, setNormalRedo)
        end

        local transforms = node:getSideTransforms(self.raceEditor.getToolsWindow():getSideTransformParameters())
        for _, e in ipairs(transforms) do
          if e then
            debugDrawer:drawLine(vec3(e.pos), vec3(e.pos + e.rot * vec3(1,0,0)), ColorF(1,0,0,1))
            debugDrawer:drawLine(vec3(e.pos), vec3(e.pos + e.rot * vec3(0,1,0)), ColorF(0,1,0,1))
            debugDrawer:drawLine(vec3(e.pos), vec3(e.pos + e.rot * vec3(0,0,1)), ColorF(0,0,1,1))
          end
        end
      end

      local visible = im.BoolPtr(node.visible)
      if im.Checkbox("Visible Marker", visible) then
        editor.history:commitAction("Changed Node Visibility",
          {index = self.index, self = self, old = node.visible, new = visible[0], field = 'visible'},
          setFieldUndo, setFieldRedo)
      end

      self:selector("Forward Recovery Position", "recovery", ColorI(30,30,80,200),"This is where the vehicle will be positioned for reverse rolling start mode.")
      self:selector("Reverse Recovery Position", "reverseRecovery", ColorI(80,30,30,200),"This is where the vehicle will be positioned for reverse rolling start mode.")


      self:drawCustomFields(node.customFields)

      im.EndChild()
    end
  im.EndChild()
end


function C:drawCustomFields(fields)
  im.Text("Custom Fields")

  local remove
  for i, name in ipairs(fields.names) do
    if fields.types[name] == 'string' then
      if not self.fields[name] then self.fields[name] = im.ArrayChar(4096, fields.values[name]) end
      local editEnded = im.BoolPtr(false)
      editor.uiInputText(name, self.fields[name], nil, nil, nil, nil, editEnded)
      if editEnded[0] then
        fields.values[name] = ffi.string(self.fields[name])
      end
    elseif fields.types[name] == 'number' then
      if not self.fields[name] then self.fields[name] = im.FloatPtr(fields.values[name]) end
      local editEnded = im.BoolPtr(false)
      editor.uiInputFloat(name, self.fields[name], nil, nil, nil, nil, editEnded)
      if editEnded[0] then
        fields.values[name] = (self.fields[name])[0]
      end
    elseif fields.types[name] == 'vec3' then
      debugDrawer:drawTextAdvanced((fields.values[name]),
      String(name),
      ColorF(1,1,1,1),true, false,
      ColorI(0,0,0,1*255))
      debugDrawer:drawSphere((fields.values[name]), 1, ColorF(1,0,0,0.5))
      if not self.fields[name] then
        self.fields[name] = im.ArrayFloat(3)
        self.fields[name][0] = fields.values[name].x
        self.fields[name][1] = fields.values[name].y
        self.fields[name][2] = fields.values[name].z
      end
      local editEnded = im.BoolPtr(false)
      editor.uiInputFloat3(name, self.fields[name], nil, nil, editEnded)
      if editEnded[0] then
        local tbl = {self.fields[name][0],self.fields[name][1],self.fields[name][2]}
        fields.values[name] = vec3(tbl)
      end
    end
    im.SameLine()
    if im.SmallButton("X##"..i) then
      remove = name
    end
  end
  if remove then
    fields:remove(remove)
  end

  editor.uiInputText("##new", self.addFieldText)
  if im.Button("New String") then
    fields:add(ffi.string(self.addFieldText),'string',"value")
    self.addFieldText = im.ArrayChar(256,"")
  end
  im.SameLine()
  if im.Button("New Number") then
    fields:add(ffi.string(self.addFieldText),'number',0)
    self.addFieldText = im.ArrayChar(256,"")
  end
  im.Separator()
  if im.Button("Populate Others") then
    local cfData = fields:onSerialize()
    for _, o in ipairs(self.sorted) do
      o.customFields:onDeserialized(cfData)
    end
  end
  im.tooltip("Replaces all other object's custom fields with the contents of this one.")
end


function C:autoRecoverPos(reverse)
  local node = self.path.pathnodes.objects[self.index]
  editor.history:commitAction("Auto-Create recovery position",
    {self = self, index = self.index, pos = vec3(node.pos), normal = vec3(node.normal) * (reverse and -1 or 1), field = reverse and 'reverseRecovery' or 'recovery'},
    function(data)
      if data.segId then
        data.self.path.startPositions:remove(data.segId)
      end
      data.self.path.pathnodes.objects[data.index][data.field] = -1
    end,
    function(data)
      local sp = data.self.path.startPositions:create(nil, data.spid or nil)
      sp:set(data.pos, quatFromDir(data.normal):normalized())
      sp.name = node.name .. " Recovery"
      data.spid = sp.id
      data.self.path.pathnodes.objects[data.index][data.field] = sp.id
    end)

end


function C:selector(name, fieldName, clrI, tt)
  local node = self.path.pathnodes.objects[self.index]
  local objects = self.path.startPositions.objects
  if not objects[node[fieldName]].missing then
    debugDrawer:drawTextAdvanced(objects[node[fieldName]].pos,
      String(name),
      ColorF(1,1,1,1),true, false,
      clrI or ColorI(0,0,0,0.7*255))
  end

  if im.BeginCombo(name..'##'..fieldName, objects[node[fieldName]].name) then
    if im.Selectable1('#'..0 .. " - None", node[fieldName] == -1) then
      editor.history:commitAction("Removed Recovery Position",
        {index = self.index, self = self, old = node[fieldName], new = -1, field = fieldName},
        setFieldUndo, setFieldRedo)
    end
    for i, sp in ipairs(self.path.startPositions.sorted) do
      if im.Selectable1('#'..i .. " - " .. sp.name, node[fieldName] == sp.id) then
              editor.history:commitAction("Removed Recovery Position",
        {index = self.index, self = self, old = node[fieldName], new = sp.id, field = fieldName},
        setFieldUndo, setFieldRedo)
      end
      if im.IsItemHovered() then
        debugDrawer:drawTextAdvanced(sp.pos,
          String(sp.name),
          ColorF(1,1,1,0.5),true, false,
          ColorI(0,0,0,0.5*255))
      end
    end
    im.EndCombo()
  end
  if node.hasNormal and node[fieldName] == -1 then
    if im.Button("Auto-Place "..name) then
      self:autoRecoverPos(fieldName == 'reverseRecovery')
    end
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
