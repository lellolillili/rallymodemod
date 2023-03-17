-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'File Vehicle Group'
C.description = 'Loads a Vehicle Group file.'
C.category = 'once_p_duration'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic

C.pinSchema = {
  {dir = 'in', type = 'string', name = 'file', description = 'File of the vehicle group.'},
  {dir = 'out', type = 'table', name = 'group', tableType = 'vehicleGroupData', description = 'Vehicle group data, to be used with other nodes.'}
}

C.tags = {'traffic', 'vehicle', 'group', 'multispawn'}

function C:init()
  self.vehGroup = nil
end

function C:postInit()
  self.pinInLocal.file.allowFiles = {
    {'Vehicle Group Files', '.vehGroup.json'}
  }
end

function C:onNodeReset()
  self.vehGroup = nil
end

function C:_executionStopped()
  self.vehGroup = nil
end

function C:work()
  if self.vehGroup == nil then
    local file, valid = self.mgr:getRelativeAbsolutePath({self.pinIn.file.value, self.pinIn.file.value..'.vehGroup.json'})
    if not valid then
      self:__setNodeError('file', 'unable to find vehicle group file: '..file)
      return
    end

    self.vehGroup = jsonReadFile(file)
    if self.vehGroup.generator or not self.vehGroup.data then -- group generator exists, or custom data not exists
      local amount = self.vehGroup.generator and self.vehGroup.generator.amount or 10
      self.vehGroup.data = core_multiSpawn.createGroup(amount, self.vehGroup.generator)
    end
    self.pinOut.group.value = self.vehGroup
  end
end

return _flowgraph_createNode(C)