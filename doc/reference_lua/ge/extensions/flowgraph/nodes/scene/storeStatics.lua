-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'Store Statics'
C.description = 'Creates and manages spawning TSStatic objects.'
C.author = 'BeamNG'
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'reset', description = 'Clears all objects, when receiving flow.', impulse = true },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },

}

C.legacyPins = {
  _in = {
    clear = 'reset'
  }
}
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.tags = {}

function C:init(mgr, ...)
  self.objects = {}
  self.storedObjects = {}
end

function C:drawCustomProperties()
  local reason = nil
  local sortedObjectIds = {}
  for _, v in ipairs(editor.selection.object or {}) do
    if scenetree[v] and scenetree[v].className == 'TSStatic' then
      table.insert(sortedObjectIds, v)
    end
  end
  table.sort(sortedObjectIds)
  im.Text(#sortedObjectIds .. " Objects Selected.")
  if #sortedObjectIds == 0 then
    im.BeginDisabled()
  end
  if im.Button("Store "..#sortedObjectIds.." Selected Objects") then
    self:updateStoredObjects(sortedObjectIds)
    self._objectesExistedBeforeStart = true
  end
  local hoverStore = im.IsItemHovered()
  if #sortedObjectIds == 0 then
    im.EndDisabled()
  end

  if im.Button("Spawn All") then
    self:spawnObjects(true)
    self._objectesExistedBeforeStart = true
  end
  im.SameLine()
  if im.Button("Despawn All") then
    self:clearObjects()
    self._objectesExistedBeforeStart = false
  end

  if im.Button("Select All") then
    local ids = {}
    for _, o in ipairs(self.storedObjects) do
      if o.currentId and o.currentId ~= -1 then
        table.insert(ids, o.currentId)
      end
    end
    if editor then
      editor.selectObjects(ids)
    end
  end
  im.SameLine()
  if im.Button("Clear Storage") then
    self.storedObjects = {}
    self.objects = {}
  end

  im.Columns(3)
  im.SetColumnWidth(0, 30)
  im.SetColumnWidth(1, 90)
  im.Text("#")
  im.NextColumn()
  im.Text("Spawned")
  im.NextColumn()
  im.Text("Shape")
  im.NextColumn()
  im.Separator()

  local remove = nil
  for i, e in ipairs(self.storedObjects) do
    if hoverStore then
      if tableContains(sortedObjectIds, e.currentId) then
        editor.uiIconImage(editor.icons.check_box,im.ImVec2(20, 20))
      else
        editor.uiIconImage(editor.icons.delete_forever,im.ImVec2(20, 20),im.ImVec4(1,0.25,0.25,1))
      end
    else
      im.Text(""..i)
    end
    im.NextColumn()
    local obj = e.currentId and scenetree[e.currentId]
    if obj then
      editor.uiIconImage(editor.icons.check,im.ImVec2(20, 20))
      if im.IsItemHovered() and editor_flowgraphEditor.allowTooltip then
        im.tooltip("ID: " .. e.currentId)
      end
      im.SameLine()
      if editor.uiIconImageButton(editor.icons.search,im.ImVec2(20, 20)) then
        editor.selectObjects({e.currentId})
        editor.fitViewToSelection()
      end
      if im.IsItemHovered() and editor_flowgraphEditor.allowTooltip then
        im.tooltip("Show")
      end
    else
      editor.uiIconImage(editor.icons.check_box_outline_blank,im.ImVec2(20, 20))
    end
    im.SameLine()
    if editor.uiIconImageButton(editor.icons.delete_forever,im.ImVec2(20, 20)) then
      remove = i
    end
    if im.IsItemHovered() and editor_flowgraphEditor.allowTooltip then
      im.tooltip("Remove")
    end
    im.NextColumn()
    local dir, filename, ext = path.split(e.shapeName)
    im.Text(filename)
    if im.IsItemHovered() and editor_flowgraphEditor.allowTooltip then
      im.tooltip(e.shapeName)
    end
    im.NextColumn()
  end
  im.Columns(1)
  if remove then
    table.remove(self.storedObjects, remove)
  end

  return reason
end

function C:updateStoredObjects(ids)
  --dump("Updating")
  table.clear(self.storedObjects)
  local newObjects = {}
  for _, id in ipairs(ids) do
    local obj = scenetree[id]
    if obj then
      local entry = {
        pos = vec3(obj:getPosition()):toTable(),
        rot = quat(obj:getRotation()):toTable(),
        scl = vec3(obj:getScale()):toTable(),
        shapeName = obj.shapeName,
        --currentId = id
      }
      table.insert(newObjects, obj)
      table.insert(self.storedObjects, entry)
    end
  end
  -- remove originals.
  if editor and editor.onRemoveSceneTreeObjects then
    editor.deselectObjectSelection()
  end
  for _, id in ipairs(ids) do
    local obj = scenetree[id]
    if obj then
      -- remvoe object from objects list if needed
      --if tableContains(self.objects, obj) then
        local idx = nil
        for i,o in ipairs(self.objects) do
          if o:getId() == obj:getId() then
            idx = i
          end
        end
        if idx then
          --log('E', "logTag", "Removing from Objects: " .. obj:getId())
          table.remove(self.objects, idx)
        end
      --end
      -- actual removing
      if editor and editor.onRemoveSceneTreeObjects then
        editor.onRemoveSceneTreeObjects({obj:getId()})
      end
      obj:delete()
    end
  end
  -- spawn new objects
  self:spawnObjects(true)
end

function C:createObject(pos, rot, scl, shape)
  local object =  createObject("TSStatic")

  -- shape
  object.shapeName = shape

  -- position
  pos = vec3(pos[1],pos[2],pos[3])
  object:setPosition(pos)

  -- scale
  scl = vec3(scl[1],scl[2],scl[3])
  object:setScale(scl)

  -- rotation
  rot = quat(rot[1],rot[2],rot[3],rot[4])
  rot = rot:toTorqueQuat()
  object:setField('rotation', 0, rot.x .. ' ' .. rot.y .. ' ' .. rot.z .. ' ' .. rot.w)


  -- additional Info
  object.canSave = false

  -- name will be generated to avoid duplicate names
  local name = "spawnedObj_" .. tostring(os.time()) .. "_" .. self.id..'_'.. #self.objects
  object:registerObject(name)
  table.insert(self.objects, object)
  return object:getId()
end

function C:_executionStarted()
  for _, o in ipairs(self.storedObjects) do
    if o.currentId and scenetree and scenetree[o.currentId] then
      self._objectesExistedBeforeStart = true
      return
    end
  end
end

function C:_executionStopped()
  if not self._objectesExistedBeforeStart then
    self:clearObjects()
  end
end

function C:clearObjects()
  self._objectesExistedBeforeStart = nil
  --dump("Clearing.")
  --if #self.objects == 0 then return end
  if editor and editor.onRemoveSceneTreeObjects then
    editor.deselectObjectSelection()
  end
  --log('E', "logTag", "Boo! :D ")

  for _, obj in ipairs(self.objects) do
    if obj then
      --log('E', "logTag", "Object: " .. obj:getId())
      if editor and editor.onRemoveSceneTreeObjects then
        editor.onRemoveSceneTreeObjects({obj:getId()})
      end
      --log('E', "logTag", "Deleting: " .. obj:getId())
      obj:delete()
      --log('E', "logTag", "Complete: " .. obj:getId())
    end
  end
  table.clear(self.objects)
  for _, v in ipairs(self.storedObjects) do
    v.currentId = nil
  end
end

function C:spawnObjects(force)
  --dump("Spawning")
  if not force and #self.objects > 0 then
    return
  end
  if force then
    self:clearObjects()
  end
  local ids = {}
  --dump("Preparuing to spawn.")
  for _, o in ipairs(self.storedObjects) do
    o.currentId = self:createObject(o.pos, o.rot, o.scl, o.shapeName)
    table.insert(ids, o.currentId)
  end
  --dump("Spawn Done.")
  --dump(ids)

  if editor then
    if self.mgr.runningState == 'stopped' and editor.selectObjects then
      editor.selectObjects(ids)
    end
    if editor.onAddSceneTreeObjects then
      editor.onAddSceneTreeObjects(ids)
    end
  end
end

function C:work()
  self.pinOut.flow.value = false
  if self.pinIn.clear.value then
    self:clearObjects()
    return
  else
    if self.pinIn.flow.value then
      self.pinOut.flow.value = true
      self:spawnObjects()
    end
  end
end

function C:onClientEndMission()
  self:clearObjects()
end

function C:destroy()
  dump("Destroy")
  dump(self._objectesExistedBeforeStart)
  if not self._objectesExistedBeforeStart then
    self:clearObjects()
  end
end

function C:_onSerialize(res)
  res.storedObjects = self.storedObjects
end

function C:_onDeserialized(nodeData)
  self.storedObjects = nodeData.storedObjects or {}
  for _, v in ipairs(self.storedObjects) do
    v.currentId = nil
  end
end

return _flowgraph_createNode(C)
