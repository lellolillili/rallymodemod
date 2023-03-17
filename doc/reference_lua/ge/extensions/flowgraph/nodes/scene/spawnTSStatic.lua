-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'Spawn TSStatic'
C.description = 'Creates and manages spawning TSStatic objects.'
C.category = 'once_instant'
C.author = 'BeamNG'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'reset', description = 'Clears the spawned object, when receiving flow.', impulse = true },
  { dir = 'in', type = 'string', name = 'shapeName', description = 'Defines the name of the shape of the object.' },
  { dir = 'in', type = 'vec3', name = 'position', description = 'Defines the position of the object.' },
  { dir = 'in', type = 'quat', name = 'rotation', description = 'Defines the rotation of the object.' },
  { dir = 'in', type = 'vec3', name = 'scale', description = 'Defines the scale of the object.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
  { dir = 'out', type = 'flow', name = 'created', description = 'Puts out flow, when the object was created.', impulse = true },
  { dir = 'out', type = 'number', name = 'lastId', description = 'ID of the most recently created object.' },
}
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.tags = {}

C.legacyPins = {
  _in = {
    clear = 'reset'
  }
}

function C:init(mgr, ...)
  self.objects = {}
  self.data.maxObjectCount = 1
end


function C:createObject(objectName)
  local object =  createObject("TSStatic")

  -- shape
  object.shapeName = self.pinIn.shapeName.value or ""

  -- position
  local pos = self.pinIn.position.value or {0,0,0}
  pos = vec3(pos[1],pos[2],pos[3])
  object:setPosition(pos)

  -- scale
  local scl = self.pinIn.scale.value or {1,1,1}
  scl = vec3(scl[1],scl[2],scl[3])
  object:setScale(scl)

  -- rotation
  local rot = self.pinIn.rotation.value or {0,0,0,0}
  rot = quat(rot[1],rot[2],rot[3],rot[4])
  rot = rot:toTorqueQuat()
  object:setField('rotation', 0, rot.x .. ' ' .. rot.y .. ' ' .. rot.z .. ' ' .. rot.w)


  --[[
  -- this code will spawn the object with an offset relative to the given rotation
  -- mind you have to add an offset pin or hardcode thse values
  local off = self.pinIn.offset.value or {10,0,0}
  off = vec3(off)

  -- getting the rotation again
  rot = self.pinIn.rotation.value or {0,0,0,0}
  rot = quat(rot[1],rot[2],rot[3],rot[4])

  -- rotating offset by our rotation
  off = rot*off

  -- getting position again
  pos = self.pinIn.position.value or {0,0,0}
  pos = vec3(pos)

  --adding our rotated offset to the positon and setting it for the object
  pos = pos + off
  pos = vec3(pos[1],pos[2],pos[3])
  object:setPosition(pos)
  ]]

  -- additional Info
  object.canSave = false

  -- name will be generated to avoid duplicate names
  local name = "spawnedObj_" .. tostring(os.time()) .. "_" .. self.id..'_'.. #self.objects
  object:registerObject(name)
  table.insert(self.objects, object)
  self.pinOut.lastId.value = object:getId()
  if editor and editor.onAddSceneTreeObjects then
    editor.onAddSceneTreeObjects({ object:getId() })
  end
end

function C:_executionStopped()
  self:onNodeReset()
end

function C:onNodeReset()
  for _, obj in ipairs(self.objects) do
    if obj then
      if editor and editor.onRemoveSceneTreeObjects then
        editor.onRemoveSceneTreeObjects({ obj:getId() })
      end
      obj:delete()
    end
  end
  table.clear(self.objects)
end

function C:workOnce()
  self:createObject()
  self.pinOut.created.value = true
end

function C:work()
  if self.createdFlag then
    -- createFlag is needed for turning impulse off after 1 frame
    self.pinOut.created.value = false
    self.createdFlag = false
  end
  if self.pinOut.created.value then
    self.createdFlag = true
  end
end

function C:onClientEndMission()
  self:onNodeReset()
end

function C:destroy()
  self:onNodeReset()
end


return _flowgraph_createNode(C)
