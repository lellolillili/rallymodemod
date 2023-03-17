-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Pursuit Roadblock'
C.description = 'Places vehicles in a roadblock formation.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'once_instant'
C.tags = {'police', 'cops', 'pursuit', 'traffic', 'ai'}

C.pinSchema = {
  {dir = 'in', type = 'number', name = 'vehId1', description = 'Vehicle id to use for the first position of the roadblock.'},
  {dir = 'in', type = 'number', name = 'vehId2', description = '(Optional) Vehicle id to use for the second position of the roadblock.'},
  {dir = 'in', type = 'number', name = 'vehId3', hidden = true, description = '(Optional) Vehicle id to use for the third position of the roadblock.'},
  {dir = 'in', type = 'vec3', name = 'pos', description = 'Roadblock center position.'},
  {dir = 'in', type = 'quat', name = 'rot', description = 'Roadblock forwards rotation.'},
  {dir = 'in', type = 'number', name = 'width', description = '(Optional) Full width of the roadblock; vehicles will be spaced apart according to this.'},
  {dir = 'in', type = 'number', name = 'angle', description = '(Optional) Vehicle angle offset, in degrees.'},
  {dir = 'in', type = 'number', name = 'centerAngle', hidden = true, description = '(Optional) Vehicle angle offset, in degrees.'},
  {dir = 'in', type = 'bool', name = 'checkWidth', hidden = true, description = 'If true, checks if the vehicles will fit before placing them.'}
}

function C:workOnce()
  local vehIds = {}
  for _, v in ipairs({'vehId1', 'vehId2', 'vehId3'}) do
    if self.pinIn[v].value then
      table.insert(vehIds, self.pinIn[v].value)
    end
  end
  local params = {angle = self.pinIn.angle.value, centerAngle = self.pinIn.centerAngle.value, width = self.pinIn.width.value}
  gameplay_police.placeRoadblock(vehIds, vec3(self.pinIn.pos.value), quat(self.pinIn.rot.value), params)
end

return _flowgraph_createNode(C)