-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = 'Move Vehicle Group'
C.description = 'Moves all vehicles in a vehicle group to a new position, rotation, and formation.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.tags = {'spawn', 'respawn', 'teleport', 'vehicle', 'group', 'traffic', 'multispawn'}

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow' },
  { dir = 'in', type = 'flow', name = 'reset', impulse = 'true' },
  { dir = 'in', type = 'table', name = 'vehicleIds', tableType = 'vehicleIds', description = 'Table of vehicle ids.' },

  { dir = 'in', type = 'bool', name = 'shuffle', hidden = true, description = 'If true, randomize the order of the group array.' },
  { dir = 'in', type = 'string', name = 'spawnMode', default = 'road', description = 'Spawn mode; see Node Properties for list.' },
  { dir = 'in', type = 'number', name = 'spawnGap', default = 15, description = 'Distance between vehicle spawn points.' },
  { dir = 'in', type = 'vec3', name = 'startPos', description = '(Optional) Position for group formation.' },
  { dir = 'in', type = 'quat', name = 'startRot', description = '(Optional) Rotation for group formation.' },

  { dir = 'out', type = 'flow', name = 'flow' },
  { dir = 'out', type = 'flow', name = 'moved', impulse = true, description = 'Flows when the vehicle group is teleported.' }
}

local spawnModes = {'roadAhead', 'roadBehind', 'traffic', 'lineAhead', 'lineBehind', 'lineLeft', 'lineRight', 'lineAbove', 'raceGrid', 'raceGridAlt'}

function C:init()
  self:onNodeReset()
  self.data.instantTeleport = false
end

function C:_executionStopped()
  self:onNodeReset()
end

function C:onNodeReset()
  self.state = 0
  self.vehIds = nil
end

function C:postInit()
  local t = {}
  for _, v in ipairs(spawnModes) do
    table.insert(t, {value = v})
  end
  self.pinInLocal.spawnMode.hardTemplates = t
end

function C:onVehicleGroupRespawned(vehIds)
  if self.state == 1 and self.vehIds and self.vehIds[1] == vehIds[1] then
    self.state = 2
  end
end

function C:work()
  if self.pinIn.reset.value then
    self:onNodeReset()
  end

  if self.pinIn.flow.value then
    if self.state == 0 then
      self.vehIds = self.pinIn.vehicleIds.value

      if self.pinIn.shuffle.value then
        self.vehIds = arrayShuffle(deepcopy(self.vehIds))
      end

      local pos = self.pinIn.startPos.value and vec3(self.pinIn.startPos.value)
      local rot = self.pinIn.startRot.value and quat(self.pinIn.startRot.value)

      core_multiSpawn.placeGroup(self.vehIds, {mode = self.pinIn.spawnMode.value, gap = self.pinIn.spawnGap.value, pos = pos, rot = rot, instant = self.data.instantTeleport})
      self.state = 1
    end
  end

  if self.state == 2 then
    self.pinOut.moved.value = true
    self.state = 3
  else
    self.pinOut.moved.value = false
  end

  if self.state >= 2 then
    self.pinOut.flow.value = self.pinIn.flow.value
  end
end

return _flowgraph_createNode(C)