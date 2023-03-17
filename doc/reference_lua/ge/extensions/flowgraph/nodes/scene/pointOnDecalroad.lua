-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Point on Decalroad'
C.description = 'Checks if a point is on a decalroad.'
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.category = 'repeat_instant'

C.pinSchema = {
    { dir = 'out', type = 'flow', name = 'inside', description = 'Outflow when point is on the road.' },
    { dir = 'out', type = 'flow', name = 'outside', description = 'Outflow when point is not on the road.' },
    { dir = 'out', type = 'bool', name = 'onRoad', description = 'Boolean for if the point is on the road or not.' },
    { dir = 'out', type = 'number', name = 'closestIdx', description = 'Closest control point index.' },
    { dir = 'out', type = 'number', name = 'maxIdx', description = 'Control point count.' },

    { dir = 'in', type = 'vec3', name = 'point', description = 'Point to be checked' },
    { dir = 'in', type = 'number', name = 'roadId', description = 'ID of the decalroad' },
}

C.tags = {}
function C:init()
  self.point = vec3(0,0,0)
  self.pz = 0
end

function C:_executionStarted()
  self.oldRoadId = -1
  self.roadObj = nil
  for _, p in pairs(self.pinOut) do
    p.value = nil
  end
end

function C:work()
  if not self.pinIn.roadId.value or not self.pinIn.point.value then return end

  if self.pinIn.roadId.value ~= self.oldRoadId then
    self.roadObj = scenetree.findObjectById(self.pinIn.roadId.value)

    if not self.roadObj then return end
    self.oldRoadId = self.pinIn.roadId.value
    self.pz = self.roadObj:getNodePosition(0).z
    self.pinOut.maxIdx.value = self.roadObj:getNodeCount()-1
  end

  if not self.roadObj then return end
  self.point.x = self.pinIn.point.value[1]
  self.point.y = self.pinIn.point.value[2]
  self.point.z = self.pz

  local idx = self.roadObj:containsPoint(self.point)
  --local idx = -1
  self.pinOut.closestIdx.value = idx
  self.pinOut.onRoad.value = idx ~= -1
  self.pinOut.inside.value = self.pinOut.onRoad.value
  self.pinOut.outside.value = not self.pinOut.inside.value
end


return _flowgraph_createNode(C)
