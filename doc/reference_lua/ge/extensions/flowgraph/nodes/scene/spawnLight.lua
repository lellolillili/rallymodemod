-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'SpotLight'
C.description = 'Creates and manages a spotlight.'
C.category = 'repeat_instant'
C.author = 'BeamNG'
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'update', description = 'Updates the position of the spotlight, when receiving flow.' },
  { dir = 'in', type = 'flow', name = 'clear', description = 'Clears the spotlight, when receiving flow.', impulse = true },
  --{dir = 'in', type = 'string', name = 'shapeName', description = 'Defines the shape of the spotlight.'},
  { dir = 'in', type = 'vec3', name = 'position', description = 'Defines the position of the spotlight.' },
  { dir = 'in', type = 'quat', name = 'rotation', description = 'Defines the rotation of the spotlight.' },
  { dir = 'in', type = 'number', name = 'range', hidden = true, default = 20, hardcoded = true, description = 'Defines the range of the spotlight.' },
  { dir = 'in', type = 'number', name = 'innerAngle', hidden = true, default = 15, hardcoded = true, description = 'Defines the inner angle of the spotlight.' },
  { dir = 'in', type = 'number', name = 'outerAngle', hidden = true, default = 45, hardcoded = true, description = 'Defines the outer angle of the spotlight.' },
  { dir = 'in', type = 'color', name = 'color', description = 'Defines the color of the spotlight.' },
  { dir = 'in', type = 'number', name = 'brightness', hidden = true, default = 1, hardcoded = true, description = 'Defines the brightness of the spotlight.' },
  { dir = 'out', type = 'flow', name = 'created', description = 'Puts out flow, when spotlight is created.', impulse = true },
  { dir = 'out', type = 'number', name = 'lastId', description = 'ID of the most recently created object.' },
}
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.tags = {}

local counter = 0

function C:init(mgr, ...)
  self.objects = {}
  self.data.maxObjectCount = 1
end

function C:createObject(objectName)
  local object =  worldEditorCppApi.createObject("SpotLight")

  -- position
  local pos = self.pinIn.position.value or {0,0,0}
  pos = vec3(pos[1],pos[2],pos[3])
  object:setPosition(pos)

  -- rotation
  local rot = self.pinIn.rotation.value or {0,0,0,0}
  rot = quat(rot[1],rot[2],rot[3],rot[4])
  rot = rot:toTorqueQuat()
  object:setField('rotation', 0, rot.x .. ' ' .. rot.y .. ' ' .. rot.z .. ' ' .. rot.w)

  object:setField('innerAngle', 0, tostring(self.pinIn.innerAngle.value))
  object:setField('outerAngle', 0, tostring(self.pinIn.outerAngle.value))
  object:setField('brightness', 0, tostring(self.pinIn.brightness.value))
  object:setField('range', 0, tostring(self.pinIn.range.value))

  -- color
  local clr = self.pinIn.color.value or {1,1,1,1}
  object:setField('color', 0, clr[1] .. ' ' .. clr[2] .. ' ' .. clr[3] .. ' ' .. clr[4])


  -- additional Info
  object.canSave = false

  -- name will be generated to avoid duplicate names
  local name = "light_" .. tostring(os.time()) .. "_" .. self.id..'_'.. #self.objects .. '_' .. counter
  counter = counter+1
  --object:registerObject(name)
  table.insert(self.objects, object)
  self.pinOut.lastId.value = object:getId()
  if editor and editor.onAddSceneTreeObjects then
    editor.onAddSceneTreeObjects({object:getId()})
  end
end

function C:_executionStopped()
  self:clearObjects()
end
function C:clearObjects()
  for _, obj in ipairs(self.objects) do
    if obj then
      if editor and editor.onRemoveSceneTreeObjects then
        editor.onRemoveSceneTreeObjects({obj:getId()})
      end
      obj:delete()
    end
  end
  table.clear(self.objects)
end


function C:work()
  self.pinOut.created.value = false
  if self.pinIn.clear.value then
    self:clearObjects()
    return
  end

  if #self.objects < self.data.maxObjectCount then
    self:createObject()
    self.pinOut.created.value = true
  end
  if #self.objects == 1 and self.pinIn.update.value then
    local object =  self.objects[1]

    -- position
    local pos = self.pinIn.position.value or {0,0,0}
    pos = vec3(pos[1],pos[2],pos[3])
    object:setPosition(pos)

    -- rotation
    local rot = self.pinIn.rotation.value or {0,0,0,0}
    rot = quat(rot[1],rot[2],rot[3],rot[4])
    rot = rot:toTorqueQuat()
    object:setField('rotation', 0, rot.x .. ' ' .. rot.y .. ' ' .. rot.z .. ' ' .. rot.w)

    object:setField('innerAngle', 0, tostring(self.pinIn.innerAngle.value))
    object:setField('outerAngle', 0, tostring(self.pinIn.outerAngle.value))
    object:setField('brightness', 0, tostring(self.pinIn.brightness.value))
    object:setField('range', 0, tostring(self.pinIn.range.value))

    -- color
    local clr = self.pinIn.color.value or {1,1,1,1}
    object:setField('color', 0, clr[1] .. ' ' .. clr[2] .. ' ' .. clr[3] .. ' ' .. clr[4])
  end

end

function C:onClientEndMission()
  self:clearObjects()
end


function C:destroy()
  self:clearObjects()
end


return _flowgraph_createNode(C)
