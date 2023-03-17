-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Get Point on Decalroad'
C.description = 'Gives the Position of a point on a decalroad.'
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'roadId', description = 'ID of the decalroad' },
  { dir = 'in', type = 'number', name = 'idx', description = 'ID of the point.' },
  { dir = 'out', type = 'vec3', name = 'pos', description = 'Position of the point.' },
  { dir = 'out', type = 'quat', name = 'rot', description = 'rotation of this point in forward direction. This is only an approximation!' },
}

C.tags = {}
function C:init()

end

function C:_executionStarted()
  self.oldRoadId = -1
  self.oldIdx = -1
  self.roadObj = nil
  for _, p in pairs(self.pinOut) do
    p.value = nil
  end
end

function C:work()
  if not self.pinIn.roadId.value or not self.pinIn.idx.value then return end

  if self.pinIn.roadId.value ~= self.oldRoadId then
    self.roadObj = scenetree.findObjectById(self.pinIn.roadId.value)

    if not self.roadObj then return end
    self.oldRoadId = self.pinIn.roadId.value
    self.maxIdx = self.roadObj:getNodeCount()-1
    self.looped = self.roadObj:getField("looped",0) == '1'

  end
  if self.pinIn.idx.value ~= self.oldIdx then
    if self.pinIn.idx.value < 0 or self.pinIn.idx.value > self.maxIdx then return end
    local point = self.roadObj:getNodePosition(self.pinIn.idx.value)
    self.pinOut.pos.value = {point.x, point.y, point.z}

    local prevIdx = self.pinIn.idx.value - 1
    if prevIdx < 0 then
      if self.looped then
        prevIdx = self.maxIdx
      else
        prevIdx = 0
      end
    end
    local nextIdx = self.pinIn.idx.value + 1
    if nextIdx > self.maxIdx then
      if self.looped then
        nextIdx = 0
      else
        nextIdx =self. maxIdx
      end
    end
    local forward = vec3(self.roadObj:getNodePosition(prevIdx) - self.roadObj:getNodePosition(nextIdx)):normalized()

    local q = quatFromDir(forward, vec3(0,0,1))
    self.pinOut.rot.value = {q.x,q.y,q.z,q.w}
    self.oldIdx = self.pinIn.idx.value
  end
end


return _flowgraph_createNode(C)
