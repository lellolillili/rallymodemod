-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Move Veh to Start Pos'
C.description = 'Moves a vehicle to a starting position of a path.'
C.category = 'repeat_instant'
C.color = im.ImVec4(1, 1, 0, 0.75)

C.pinSchema = {
  {dir = 'in', type = 'number', name = 'vehId', description = 'Id of vehicle to move.'},
  {dir = 'in', type = 'string', name = 'name', description = 'Name of the start position to get. no Value will use default.'},
  {dir = 'in', type = 'bool', name = 'lowPrecision', hidden=true, default = false, hardcoded=true, description = 'Use Low Prio if you want to move the vehicle in the first frame of it being spawned.'},
  {dir = 'in', type = 'table', name = 'pathData', tableType = 'pathData',  description = 'Data from the path for other nodes to process.'},
  {dir = 'in', type = 'number', name = 'id',  description = 'If ID is given, will use that starting position instead'},
  {dir = 'in', type = 'bool', name = 'reverse', hidden=true, default = false, hardcoded=true, description = 'Use the default reverse position instead.'},
  {dir = 'in', type = 'bool', name = 'rolling', hidden=true, default = false, hardcoded=true, description = 'Use the default rolling position instead.'},

  { dir = 'out', type = 'vec3', name = 'pos', description = "Position." },
  { dir = 'out', type = 'quat', name = 'rot', description = "Rotation" },
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}
C.tags = {'scenario'}


function C:init(mgr, ...)
  self.path = nil
  self.clearOutPinsOnStart = false
end

function C:_executionStarted()
  self.path = nil
end


function C:work(args)
  self.path = self.pinIn.pathData.value
  if self.path ~= nil then
    local spId = self.path.defaultStartPosition
    if self.pinIn.id.value then
      spId = self.pinIn.id.value
    else
      if self.pinIn.reverse.value then
        if self.pinIn.rolling.value then
          spId = self.path.rollingReverseStartPosition
        else
          spId = self.path.reverseStartPosition
        end
      else
        if self.pinIn.rolling.value then
          spId = self.path.rollingStartPosition
        else
          spId = self.path.defaultStartPosition
        end
      end
    end
    local sp = self.path.startPositions.objects[spId]

    if self.pinIn.name.value then
      sp = self.path:findStartPositionByName(self.pinIn.name.value)
    end
    if sp == nil then return end
    if self.pinIn.vehId.value then
      print("Move to start position")
      local pos, rot = sp:moveResetVehicleTo(self.pinIn.vehId.value, self.pinIn.lowPrecision.value or false)
      self.pinOut.pos.value = pos:toTable()
      self.pinOut.rot.value = rot:toTable()
    end
  end
end




return _flowgraph_createNode(C)
