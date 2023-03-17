-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui

local C = {}
C.windowDescription = 'Tools'
local posOffset, rotOffset, sclOffset = im.ArrayFloat(3),im.ArrayFloat(3),im.ArrayFloat(3)
local shapeNameLeft,shapeNameRight = "art/shapes/race/sign_checkpoint.dae", "art/shapes/race/sign_checkpoint.dae"
local shapeInputLeft,shapeInputRight = im.ArrayChar(1024, shapeNameLeft), im.ArrayChar(1024, shapeNameRight)
local alignMode = 'terrain'
local alignModes = {'terrain','pathnode','absolute'}
local leftMode, rightMode = nil,nil
local lastGroup = nil

local nodeSize = im.FloatPtr(5)
local previewEnabled = im.BoolPtr(false)

function C:init(raceEditor)
  self.raceEditor = raceEditor
  posOffset[0] = 0
  posOffset[1] = 0
  posOffset[2] = 0.2
  rotOffset[0] = 0
  rotOffset[1] = 15
  rotOffset[2] = 0
  sclOffset[0] = 1
  sclOffset[1] = 1
  sclOffset[2] = 1
end

function C:setPath(path)
  self.path = path
end
function C:selected() end
function C:unselect() end

function C:draw()
  self:drawGeneralInfo()
end

function C:createDecoration(transforms)
  local groupName = self.path.name.."_decoration"
  local group = scenetree.findObject(groupName)

  if group then
    local groupCounter = 1
    while group do
      groupCounter = groupCounter + 1
      group = scenetree.findObject(groupName .. groupCounter)
    end
    groupName = groupName .. groupCounter
  end

  group = createObject('SimGroup')
  group:registerObject(groupName)
  scenetree.MissionGroup:addObject(group.obj)

  for i, t in ipairs(transforms) do
    local mode, obj = "none", "none"
    if t.side == 'r' then
      mode, obj = rightMode, shapeNameRight
    elseif t.side == 'l' then
      mode, obj = leftMode, shapeNameLeft
    end

    local objName = groupName.."_dec_"..t.side..'_'..i
    local decoration = nil
    if mode == 'dae' then
      decoration = createObject('TSStatic')
      decoration:setField('shapeName', 0, obj)
      decoration:registerObject(objName)
      decoration:setPosRot(t.pos.x, t.pos.y, t.pos.z, t.rot.x, t.rot.y, t.rot.z, t.rot.w)
      decoration.scale = vec3(t.scl.x, t.scl.y, t.scl.z)
      decoration.canSave = true
      decoration = decoration.obj
    elseif mode == 'prefab' then
      local r = quat(t.rot)
      r = r:toTorqueQuat()
      decoration = spawnPrefab(objName, obj,
        t.pos.x.." "..t.pos.y.." "..t.pos.z,
        r.x.." "..r.y.." "..r.z.." "..r.w,
        t.scl.x.." "..t.scl.y.." "..t.scl.z    )
    end
    if decoration then
      group:addObject(decoration)
    end
  end
  lastGroup = group
end

function C:existsIcon(f)
  if FS:fileExists(f) then
    editor.uiIconImage(editor.icons.check, im.ImVec2(24, 24))
    im.tooltip("Found file at "..f)
  else
    editor.uiIconImage(editor.icons.error_outline, im.ImVec2(24, 24))
    im.tooltip("No file at "..f)
  end
end

local function setFieldsUndo(data)
  for idx, _ in ipairs(data.oldDataMap) do
    data.self.path.pathnodes.objects[idx][data.field] = data.oldDataMap[idx]
  end
end
local function setFieldsRedo(data)
  for idx, _ in pairs(data.newDataMap) do
    data.self.path.pathnodes.objects[idx][data.field] = data.newDataMap[idx]
  end
end

function C:changeFieldMulti(field,  newDataMap)
  local oldDataMap = {}
  for idx, _ in pairs(newDataMap) do
    oldDataMap[idx] = self.path.pathnodes.objects[idx][field]
  end
  editor.history:commitAction("Changed multiple Pathnodes field " .. field.. " of Path",
    {self = self, oldDataMap = oldDataMap, newDataMap = newDataMap, field = field},
    setFieldsUndo, setFieldsRedo)
end

function C:getSideTransformParameters()
  return  vec3(posOffset[0],posOffset[1], posOffset[2]),
          vec3(rotOffset[0],rotOffset[1], rotOffset[2])*(math.pi/180),
          vec3(sclOffset[0],sclOffset[1], sclOffset[2]),
          alignMode
end
function C:drawGeneralInfo()
  im.BeginChild1("Tools", im.ImVec2(0, 0), im.WindowFlags_ChildWindow)
  im.Text("Side Decorators")
  im.InputFloat3("Position Offset",posOffset)
  im.InputFloat3("Rotation Offset",rotOffset)
  im.InputFloat3("Scale Offset",sclOffset)

  if im.BeginCombo('Rotation Mode', alignMode) then
    for _, m in ipairs(alignModes) do
      if im.Selectable1(m, m == alignMode) then
        alignMode = m
      end
    end
    im.EndCombo()
  end

  local editEnded = im.BoolPtr(false)
  im.Text("Left/Right object:")
  editor.uiInputText("##lopath", shapeInputLeft, 1024, nil, nil, nil, editEnded)
  if editEnded[0] then shapeNameLeft = ffi.string(shapeInputLeft) end
  im.SameLine()
  if im.Button(" ... ##leftSelector") then
    extensions.editor_fileDialog.openFile(
      function(data)
        shapeNameLeft = data.filepath
        shapeInputLeft = im.ArrayChar(1024, data.filepath)
      end, {{'dae files','dae'},{'prefab files','prefab'},{'prefab json files','prefab.json'}}, false,'/art/shapes/race/')
  end im.SameLine()
  self:existsIcon(shapeNameLeft)


  editor.uiInputText("##roPath", shapeInputRight, 1024, nil, nil, nil, editEnded)
  if editEnded[0] then shapeNameRight = ffi.string(shapeInputRight) end
  im.SameLine()
  if im.Button(" ... ##rightSelector") then
    extensions.editor_fileDialog.openFile(
      function(data)
        shapeNameRight = data.filepath
        shapeInputRight = im.ArrayChar(1024, data.filepath)
      end, {{'dae files','dae'},{'prefab files','prefab'},{'prefab json files','prefab.json'}}, false,'/art/shapes/race/')
  end im.SameLine()
  self:existsIcon(shapeNameRight)

  local dir, filename, ext  = path.split(shapeNameLeft, true)
  leftMode = "unknown"
  if ext == 'dae' then leftMode = 'dae' end
  if ext == 'prefab' or ext == 'prefab.json' then leftMode = 'prefab' end
  dir, filename, ext  = path.split(shapeNameRight, true)
  rightMode = "none"
  if ext == 'dae' then rightMode = 'dae' end
  if ext == 'prefab' or ext == 'prefab.json' then rightMode = 'prefab' end




  im.Dummy(im.ImVec2(0,10))
  if lastGroup then
    im.Text("Created Group: " .. lastGroup.name)
  else
    im.Text("Created Group: None")
  end

  im.Checkbox("Draw Preview", previewEnabled)
  -- drawing preview
  if previewEnabled[0] then
    local allTransforms = {}
    for _, pn in pairs(self.path.pathnodes.objects) do
      local transforms = pn:getSideTransforms(self:getSideTransformParameters())
      for _, e in ipairs(transforms) do
        if e then
          table.insert(allTransforms, e)
          debugDrawer:drawLine(vec3(e.pos), vec3(e.pos + e.rot * vec3(e.scl.x,0,0)), ColorF(1,0,0,1))
          debugDrawer:drawLine(vec3(e.pos), vec3(e.pos + e.rot * vec3(0,e.scl.y,0)), ColorF(0,1,0,1))
          debugDrawer:drawLine(vec3(e.pos), vec3(e.pos + e.rot * vec3(0,0,e.scl.z)), ColorF(0,0,1,1))
        end
      end
    end
    if im.Button("Create") then
      self:createDecoration(allTransforms)
    end im.tooltip("Creates a new group with the decoration")
    if lastGroup then
      im.SameLine()
      if im.Button("Replace") then
        lastGroup:delete()
        lastGroup = nil
        self:createDecoration(allTransforms)
      end im.tooltip("Removes the old group and creates a new one.") im.SameLine()

      if im.Button("Remove") then
        lastGroup:delete()
        lastGroup = nil
      end if lastGroup then im.tooltip("Removes " .. lastGroup.name) end
    end
  end

  im.Separator()
  im.Text("Pathnode Tools")
  if im.Button("Drop all pathnodes to terrain height") then
    local newDataMap = {}
    for _, node in pairs(self.path.pathnodes.objects) do
      newDataMap[node.id] = core_terrain.getTerrainHeight(node.pos)
    end
    self:changeFieldMulti('pos', newDataMap)
  end
  if im.Button("Align all pathnode normals to terrain height") then
    local newDataMap = {}
    for _, node in pairs(self.path.pathnodes.objects) do
      if node.hasNormal then
        local normalTip = node.pos + node.normal*node.radius
        normalTip = vec3(normalTip.x, normalTip.y, core_terrain.getTerrainHeight(normalTip))
        newDataMap[node.id] = normalTip - node.pos
      end
    end
    self:changeFieldMulti('normal', newDataMap)
  end
  im.PushItemWidth(80)
  if im.InputFloat("##nodeSize", nodeSize) then
    if nodeSize[0] < 0.1 then nodeSize[0] = 0.1 end
  end
  im.SameLine()
  if im.Button("Set all pathnode sizes") then
    local newDataMap = {}
    for _, node in pairs(self.path.pathnodes.objects) do
      newDataMap[node.id] = nodeSize[0]
    end
    self:changeFieldMulti('radius', newDataMap)
  end
  if im.Button("Remove all BeamnNGWaypoints with same name as Pathnodes") then
    for _, node in pairs(self.path.pathnodes.objects) do
      if scenetree.findObject(node.name) then
        scenetree.findObject(node.name):delete()
      end
    end
  end

  im.Separator()
  im.Text("Debug Tools")
  if im.Button("Open Test Race Window") then
    self.raceEditor.setupRace()
  end im.SameLine() im.tooltip("Opens as separate windows to test the current track.\nThe test track will only have debug visualizations.\nYou can return to this editor by closing the test window.")
  if im.Button("Dump Path [Debug]") then
    dumpz(self.path,2)
  end

  if im.Button("Dump Auto Config [Debug]") then
    self.path:autoConfig()
    dumpz(self.path.config,4)
  end im.SameLine()
  if im.Button("Dump Auto Config Reverse [Debug]") then
    self.path:autoConfig(true)
    dumpz(self.path.config,4)
  end
  im.EndChild()
end

function C:displayClassification(classification, name, field, tt)
  local cpx = im.GetCursorPosX()
  im.Text(name) im.SameLine() im.SetCursorPosX(cpx + 90) im.tooltip(tt or "")
  if classification[field] then
    editor.uiIconImage(editor.icons.check, im.ImVec2(24, 24))
  else
    editor.uiIconImage(editor.icons.close, im.ImVec2(24, 24))
  end
  im.tooltip(tt or "")
end



function C:selector(name, objects, fieldName, clrI, tt)
  if not objects.objects[self.path[fieldName]].missing then
    debugDrawer:drawTextAdvanced(objects.objects[self.path[fieldName]].pos,
      String(name),
      ColorF(1,1,1,1),true, false,
      clrI or ColorI(0,0,0,0.7*255))
  end

  if im.BeginCombo(name..'##'..fieldName, objects.objects[self.path[fieldName]].name) then
    if im.Selectable1('#'..0 .. " - None", value == -1) then
      self:changeField(fieldName,-1)
    end
    for i, sp in ipairs(objects.sorted) do
      if im.Selectable1('#'..i .. " - " .. sp.name, value == sp.id) then
        self:changeField(fieldName,sp.id)
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
  im.tooltip(tt or "")
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
