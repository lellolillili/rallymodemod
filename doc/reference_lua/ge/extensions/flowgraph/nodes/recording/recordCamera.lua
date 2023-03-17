-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Record Camera'
C.description = 'Records a Camera path using keyframes.'
C.category = 'repeat_f_duration'

C.todo = "WIP"
C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'snap', description = 'Trigger to create a keyframe.', impulse = true},
  {dir = 'in', type = 'flow', name = 'stop', description = 'Trigger to stop the recording save the path.', impulse = true},
  {dir = 'in', type = 'vec3', name = 'pos', description = 'Position for the keyframe.'},
  {dir = 'in', type = 'quat', name = 'rot', description = 'Rotation for the keyframe.'},
  {dir = 'in', type = 'string', name = 'prefix', description = 'The prefix for the generated object.'},
  {dir = 'out', type = 'string', name = 'filename', description = 'The complete generated filename.'},
}

C.tags = {}

function C:init()
  self:setDurationState('inactive')
  self.path = {}
end

function C:_executionStarted()
  self:setDurationState('inactive')
  self.path = {}
  self.startTime = os.clock()
end

function C:finishUp()
  local currentPath = createObject("SimPath")
  currentPath:registerObject("")
  local name = (self.pinIn.prefix.value or "pathCamera_") .. tostring(os.time())
  currentPath:setField("name", 0, name)
  scenetree.MissionGroup:addObject(currentPath)
  local oldT = self.path[1].time
  for k,v in ipairs(self.path) do
    local currentMarker = createObject("Marker")
    currentMarker:registerObject("")
    local pos = v.pos or {0,0,0}
    pos = vec3(pos[1],pos[2],pos[3])
    currentMarker:setPosition(pos)
    currentMarker:setScale(vec3(0.1,0.1,0.1))

    local rot = v.rot or {0,0,0,0}
    rot = quat(rot[1],rot[2],rot[3],rot[4])
    rot = rot:toTorqueQuat()
    currentMarker:setField('rotation', 0, rot.x .. ' ' .. rot.y .. ' ' .. rot.z .. ' ' .. rot.w)

    currentMarker:setField("name", 0, "maker_"..(k-1))
    local ttn = 0
    if k ~= #self.path then
      ttn = self.path[k+1].time - oldT
      oldT = self.path[k+1].time
    end
    currentMarker:setField("timeToNext", 0, ttn)
    currentPath:addObject(currentMarker)
  end
  self.pinOut.filename.value = name

end

function C:work()
  if self.durationState == 'inactive' then
    if self.pinIn.snap.value then
      print("Starting recording!")
      self:setDurationState('started')
    end
  end
  if self.durationState == 'started' then
    if self.pinIn.snap.value then
      table.insert(self.path, { time = os.clock() - self.startTime, pos = self.pinIn.pos.value, rot = self.pinIn.rot.value})
    end

    if self.pinIn.stop.value then
      self:setDurationState('finished')
      self:finishUp()
    end
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text(self.durationState)
  im.Text(tostring(#self.path))

end


return _flowgraph_createNode(C)
