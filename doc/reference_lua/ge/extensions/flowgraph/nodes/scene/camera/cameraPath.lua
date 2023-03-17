-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Simple Cam Path'
C.description = "Lets the camera follow the path defined by a CameraPath object."
C.category = 'once_f_duration'

C.pinSchema = {
  { dir = 'in', type = 'string', name = 'pathName', description = 'Path to load camera path from.' },
  { dir = 'in', type = 'bool', name = 'loop', description = 'If the path should loop.', hardcoded = true, default = false },
  { dir = 'out', type = 'flow', name = 'activated', description = 'Outflow once when the path has been started.', impulse = true, hidden = true },
  { dir = 'out', type = 'flow', name = 'inactive', description = 'Outflow if the campath is not active or no campath is running.', hidden = true },
  { dir = 'out', type = 'number', name = 'duration', description = 'Duration of the path', hidden = true },
  { dir = 'out', type = 'number', name = 'id', description = 'Id of the camera path.' },
}
C.tags = {'campath','pathcam','path','camera'}
C.color = ui_flowgraph_editor.nodeColors.camera
C.icon = ui_flowgraph_editor.nodeIcons.camera

C.legacyPins = {
  out = {
    finished = 'complete',
    stopped = 'inactive'
  },
  _in = {
    start = 'flow',
  }
}

function C:init()
end

function C:postInit()
  self.pinInLocal.pathName.allowFiles = {
    {"Camera Path Files",".camPath.json"}
  }
end

function C:_executionStarted()
  self.activatedFlag = nil
  self:setDurationState('inactive')
end

function C:onNodeReset()
  self.activatedFlag = nil
  self:setDurationState('inactive')
end

function C:workOnce()
  local id = self.mgr.modules.camera:findPath(self.pinIn.pathName.value)
  self.mgr.modules.camera:startPath(id, self.pinIn.loop.value)
  self.pinOut.id.value = id
  self.pinOut.activated.value = true
  self.activatedFlag = true
  self:setDurationState('started')
end

function C:work()
  if self.durationState == 'started' then
    if not self.activatedFlag then
      self.pinOut.activated.value = false
    else
      self.activatedFlag = false
    end
    local active = self.mgr.modules.camera.activePathId and self.pinOut.id.value == self.mgr.modules.camera.activePathId
    local id = self.pinOut.id.value
    if not active then
      self.pinOut.inactive.value = true
      self.pinOut.duration.value = 0
    else
      self.pinOut.inactive.value = false
      if self.mgr.modules.camera:isPathComplete(id) then
        self:setDurationState('finished')
      end
      self.pinOut.duration.value = self.mgr.modules.camera:getPathDuration(id)
    end
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
end
function C:_onDeserialized(data)
  if data.data.loop ~= nil then
    self:_setHardcodedDummyInputPin(self.pinInLocal.loop, data.data.loop)
  end
end

return _flowgraph_createNode(C)