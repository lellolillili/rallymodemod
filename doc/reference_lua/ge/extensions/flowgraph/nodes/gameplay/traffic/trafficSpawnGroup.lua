-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = 'Spawn Vehicle Group'
C.description = 'Spawns a group of vehicles; use the Set Vehicle Group node for the group data.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.tags = {'spawn', 'vehicle', 'group', 'traffic', 'multispawn'}

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow'},
  { dir = 'in', type = 'flow', name = 'reset', impulse = 'true', description = 'Deletes group vehicles and resets this node.' },
  { dir = 'in', type = 'table', name = 'group', tableType = 'vehicleGroupData', description = 'Vehicle group data; if none given, the default traffic group will spawn.' },
  { dir = 'in', type = 'number', name = 'quantity', description = 'Number of new vehicles to spawn; set to -1 to use traffic value from the game settings.' },
  { dir = 'in', type = 'bool', name = 'shuffle', description = 'If true, randomize the spawning order of the group.' },
  { dir = 'in', type = 'string', name = 'spawnMode', default = 'road', description = 'Spawn mode; see Node Properties for list.' },
  { dir = 'in', type = 'number', name = 'spawnGap', default = 15, description = 'Distance between vehicle spawn points.' },
  { dir = 'in', type = 'vec3', name = 'startPos', hidden = true, description = 'Base position to start spawning from.' },
  { dir = 'in', type = 'quat', name = 'startRot', hidden = true, description = 'Base rotation to start spawning from.' },
  { dir = 'in', type = 'bool', name = 'randomColors', hidden = true, description = 'If true, vehicles will spawn with randomly selected colors.' },
  { dir = 'in', type = 'bool', name = 'dontDelete', hidden = true, default = false, description = 'If true, the vehicle will not be deleted when you stop the project.' },

  { dir = 'out', type = 'flow', name = 'flow' },
  { dir = 'out', type = 'flow', name = 'loaded', impulse = true, description = 'Flows when the vehicle group is loaded.' },
  { dir = 'out', type = 'table', name = 'vehicleIds', tableType = 'vehicleIds', description = 'Table of newly spawned vehicle ids.' }
}
C.legacyPins = {
  out = {
    newIds = 'vehicleIds'
  }
}

local spawnModes = {'roadAhead', 'roadBehind', 'traffic', 'lineAhead', 'lineBehind', 'lineLeft', 'lineRight', 'lineAbove', 'raceGrid', 'raceGridAlt'}

function C:init()
  self:resetState()
end

function C:_executionStopped()
  self:resetState()
end

function C:onNodeReset()
  for _, id in ipairs(self.vehicleIds) do
    local obj = scenetree.findObjectById(id)
    if obj then
      if editor and editor.onRemoveSceneTreeObjects then
        editor.onRemoveSceneTreeObjects({obj:getId()})
      end
      obj:delete()
    end
  end

  self:resetState()
end

function C:resetState()
  self.state = 0
  self.groupId = 0
  self.vehicleIds = {}
  self.pinOut.flow.value = false
end

function C:postInit()
  local t = {}
  for _, v in ipairs(spawnModes) do
    table.insert(t, {value = v})
  end
  self.pinInLocal.spawnMode.hardTemplates = t
end

function C:onVehicleGroupSpawned(vehIds, groupId)
  if self.state == 1 and self.groupId == groupId then
    for _, v in ipairs(vehIds) do
      self.mgr.modules.vehicle:addVehicle(be:getObjectByID(v), {dontDelete = self.dontDelete})
    end
    self.vehicleIds = deepcopy(vehIds)
    self.pinIn.flow.value = true
    self.pinOut.vehicleIds.value = self.vehicleIds
    self.state = 2
    self.groupId = nil
  end
end

function C:work()
  self.dontDelete = self.pinIn.dontDelete.value and true or false

  if self.pinIn.reset.value then
    self:onNodeReset()
  end

  if self.pinIn.flow.value then
    if self.state == 0 then
      local group = self.pinIn.group.value and deepcopy(self.pinIn.group.value) or {data = gameplay_traffic.createTrafficGroup()} -- if no given group, create a default traffic group
      if self.pinIn.randomColors.value then
        for _, v in ipairs(group.data) do
          v.paintName = 'random'
        end
      end

      local quantity = self.pinIn.quantity.value
      if not quantity or quantity < 0 then
        local newQuantity = core_settings_settings.getValue('trafficAmount')
        if newQuantity == 0 then newQuantity = -1 end
        quantity = gameplay_traffic.getIdealSpawnAmount(newQuantity)
      end
      if quantity == 0 then
        self.pinOut.flow.value = true
        self.state = 3
      else
        local shuffle = self.pinIn.shuffle.value and true or false
        local pos = self.pinIn.startPos.value and vec3(self.pinIn.startPos.value)
        local rot = self.pinIn.startRot.value and quat(self.pinIn.startRot.value)

        self.groupId = core_multiSpawn.spawnGroup(group.data, quantity, {name = group.name, order = not shuffle, mode = self.pinIn.spawnMode.value, gap = self.pinIn.spawnGap.value, pos = pos, rot = rot})
        self.state = 1
      end
    end
  end

  if self.state == 2 then
    self.pinOut.loaded.value = true
    self.state = 3
  else
    self.pinOut.loaded.value = false
  end

  if self.state >= 2 then
    self.pinOut.flow.value = self.pinIn.flow.value
  end
end

return _flowgraph_createNode(C)