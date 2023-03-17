-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Race Start Transform'
C.description = 'Gives the Start Positions Transform of a Path. Useful for creating custom triggers..'
C.category = 'repeat_instant'

C.color = im.ImVec4(1, 1, 0, 0.75)
C.pinSchema = {
  {dir = 'in', type = 'table', name = 'pathData', tableType = 'pathData', description = 'Data from the path for other nodes to process.'},
  {dir = 'in', type = {'name', 'number'}, name = 'name', description = 'Name of the start position to get. no Value will use default.'},
  {dir = 'out', type = 'bool', name = 'existing', description = 'True of the transform was found'},
  {dir = 'out', type = 'vec3', name = 'pos', description= 'The position of this transform.'},
  {dir = 'out', type = 'vec3', name = 'origPos', hidden=true, description= 'The position of this transform.'},
  {dir = 'out', type = 'quat', name = 'rot', description= 'The rotation of this transform.'},
  {dir = 'out', type = 'vec3', name = 'scl', description= 'The scale of this transform.'},
}

C.tags = {'scenario'}


function C:init(mgr, ...)
  self.path = nil
  self.clearOutPinsOnStart = false
  self.data.width = 4
  self.data.length = 6
  self.data.height = 6
end


function C:_executionStopped()
  self.path = nil
end

function C:work(args)
  if self.path == nil then
    self.path = self.pinIn.pathData.value

    local sp = self.path.startPositions.objects[self.path.defaultStartPosition]
    dump(self.pinIn.name.value)
    if self.pinIn.name.value then
      if type(self.pinIn.name.value) == 'string' then
        sp = self.path:findStartPositionByName(self.pinIn.name.value)
      elseif type(self.pinIn.name.value) == 'number' then
        dump("by name")
        dumpz(self.path.startPositions, 3)
        sp = self.path.startPositions.objects[self.pinIn.name.value]
      end
    end
    self.pinOut.existing.value = false
    dumpz(sp, 2)
    if sp == nil or sp.missing then return end
    local rot = sp.rot --* quatFromEuler(0,0,math.pi/2)
    self.pinOut.rot.value = {rot.x, rot.y, rot.z, rot.w}
    self.pinOut.scl.value = {self.data.width,self.data.length,10}
    local x, y, z = rot * vec3(1,0,0), rot * vec3(0,1,0), rot * vec3(0,0,1)
    self.pinOut.pos.value = vec3(sp.pos - (self.data.length/2)*y + 4*z):toTable()
    self.pinOut.origPos.value = sp.pos:toTable()
    self.pinOut.existing.value = not sp.missing
  end
end




return _flowgraph_createNode(C)
