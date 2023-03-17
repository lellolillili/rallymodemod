-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'Spawn Prefab'
C.description = 'Creates and manages a prefab.'
C.author = 'BeamNG'
C.behaviour = { once = true }
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'resetVeh', description = 'Resets the vehicles inside this prefab.', impulse = true },
  { dir = 'in', type = 'string', name = 'path', description = 'Path to load prefab from.' },
  { dir = 'in', type = 'vec3', name = 'pos', description = 'Position to load prefab in.' },
  { dir = 'in', type = 'bool', name = 'useGlobalTranslation', hidden = true, default = true, description = 'Should the prefab use global translation.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
  { dir = 'out', type = 'flow', name = 'created', description = 'Puts out flow, when the prefab is created.', impulse = true },
  { dir = 'out', type = 'number', name = 'id', description = 'Id of the prefab in the SceneTree.' },
  { dir = 'out', type = 'number', name = 'origVehId', description = 'Id of the player vehicle before spawning the prefab. Spawning a prefab with vehicles switches the players vehicle.' },
  --{dir = 'out', type = 'table', name = 'resetData', description = 'Data needed to reset the prefab.'},
}
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.tags = {}

function C:init(mgr, ...)
  self.objects = {}
  self.origPositions = {}
end

function C:postInit()
  self.pinInLocal.path.allowFiles = {
    {"Json Prefab Files",".prefab.json"},
    {"Old Prefab Files",".prefab"},
  }
end

function C:createObject()
  local pos = vec3(0,0,0)
  if self.pinIn.pos.value then
    pos = vec3(self.pinIn.pos.value)
  end

  self.pinOut.origVehId.value = be:getPlayerVehicleID(0)

  local file, succ = self.mgr:getRelativeAbsolutePath({self.pinIn.path.value, self.pinIn.path.value .. '.prefab', self.pinIn.path.value .. '.prefab.json'})
  if succ then
    local name = generateObjectNameForClass('Prefab', "prefab_" .. self.id)
    local scenetreeObject = spawnPrefab(name , file, pos.x .. " " .. pos.y .. " " .. pos.z, "0 0 1", "1 1 1", self.pinIn.useGlobalTranslation.value)
    scenetreeObject.canSave = false
    table.insert(self.objects, scenetreeObject:getID())
    if scenetree.MissionGroup then
      scenetree.MissionGroup:add(scenetreeObject)
    end
    self.pinOut.id.value = scenetreeObject:getID()

    self.mgr.modules.prefab:addPrefab(scenetreeObject:getID())
  end
end

function C:_executionStopped()
  self:clearObjects()
end

function C:clearObjects()
  table.clear(self.objects)
end

function C:work()
  self.pinOut.created.value = false
  self.pinOut.flow.value = false
  if self.pinIn.reset.value then
    self:clearObjects()
    return
  end
  if self.pinIn.resetVeh.value then
    for _, id in ipairs(self.objects) do
      self.mgr.modules.prefab:restoreVehiclePositions(id)
    end
  end
  if self.pinIn.flow.value then
    self.pinOut.flow.value = true
    if #self.objects < 1 then
      self:createObject()
      self.pinOut.created.value = true
    end
  end
end

function C:onClientEndMission()
  self:clearObjects()
end

function C:destroy()
  self:clearObjects()
end

return _flowgraph_createNode(C)
