-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'Particle Emitter'
C.description = 'Creates and manages a particle emitter.'
C.category = 'repeat_instant'
C.author = 'BeamNG'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'clear', description = 'When receiving flow, clears particle emitter.', impulse = true },
  { dir = 'in', type = 'vec3', name = 'position', description = 'Defines the position of the particle emitter.' },
  { dir = 'in', type = 'quat', name = 'rotation', description = 'Defines the rotation of the particle emitter.' },
  { dir = 'in', type = 'color', name = 'color', description = 'Defines the color of the particle emitter.' },
}
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.tags = {}

function C:init(mgr, ...)
  self.position = {}
  self.radius = {}
  self.clr = {}
  self.object = nil
  self.shown = false
end


function C:createObject(objectName)
  local object =  createObject('ParticleEmitterNode')
  object:setPosition(vec3(0, 0, 0))
  object.scale = vec3(1, 1, 1)
  object:setField('rotation', 0, '1 0 0 0')
  object:setField('emitter', 0, "BNGP_confetti")
  object:setField('dataBlock', 0, 'lightExampleEmitterNodeData1')

  object.canSave = false
  object:registerObject(objectName)
  return object
end


-- creates objects of a certain kind until a given amount is reached.
-- will hide excess objects instead of removing them.
function C:showObject()

  if self.object then
    self.object.hidden = false
    self.object.obj.hidden = false
  else
    self.object = {
      hidden = false,
      position = vec3(0,0,0),
      alphaMult = 1
    }
    local nm = "_" .. tostring(os.time()) .. "_" .. self.id
    self.object.obj = self:createObject("particles_"..nm)
    dump("Added Object")
    scenetree.MissionGroup:addObject(self.object.obj.obj)
  end
  self.shown = true
end

-- removes all the objects and then removes the list.
function C:hideObject()
  -- show/hide the corrent amount of objects
  self.object.hidden = true
  self.object.obj.hidden = true

  self.shown = false
end

function C:_afterTrigger()
  if self.pinIn.flow.value == false and self.shown then
    self:hideobject()
  end
end

function C:_executionStopped()
  if not self.object then return end
  if self.object.obj then
    if editor and editor.onRemoveSceneTreeObjects then
      editor.onRemoveSceneTreeObjects({self.object.obj:getId()})
    end
    self.object.obj:delete()
  end

  self.object = nil
  self.shown = false
end

function C:fillFields()
  local posIn = self.pinIn.position.value
  local radIn = self.pinIn.radius.value
  local clrIn = self.pinIn.color.value
  if not clrIn or clrIn == {} then clrIn = {1,0,0,0.8} end
  if not radIn then radIn = 2 end
  if not posIn then return end
  self.position = posIn
  self.radius = radIn
  self.clr = clrIn

end

function C:setPosition()
  -- if position is not a table, then only one object is needed.
    if self.object.obj and self.object.objBase then
      self:fillFields()
      self.object.position = vec3(self.position)
      self.object.obj:setPosition(vec3(self.position))
      self.object.obj:setScale(vec3(self.radius, self.radius, 50))
    end
end




function C:work()
  if self.object == nil then
    self:showObject()
  end

  if self.object ~= nil then
    if self.pinIn.flow.value == true then
      --create object
      self:showObject()
      self:setPosition()
      self.pinOut.flow.value = true
    end
    if self.pinIn.clear.value == true then
      --remove object
      self:hideObject()
      self.pinOut.flow.value = false
    end
  end
end

function C:onClientEndMission()
  self:_executionStopped()
end


function C:destroy()
  self:_executionStopped()
end


return _flowgraph_createNode(C)
