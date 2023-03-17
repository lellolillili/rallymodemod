-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'AI Go To The End Line'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Go to the selected end line, can be a position or a trigger/waypoint.'
-- C.category = 'once_f_duration'
C.behaviour = { duration = true }
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'reset', description = 'Reset pin for this node.', impulse = true },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node, once the destination has been reached and the vehicle is slowe than check velocity.' },

  { dir = 'out', type = 'number', name = 'distance', hidden = true, description = 'Distance to the target waypoints center.' },
  { dir = 'in', type = 'number', name = 'aiVehId', description = 'The AI vehicle. Uses player vehicle if no value given.' },
  { dir = 'in', type = 'vec3', name = 'endLinePosition', hidden = true, description = 'Position of end line to be driven to.' },
  { dir = 'in', type = 'number', name = 'checkDistance', hidden = true, default = 1, description = 'If the vehicle is closer than this distance, it is considered arrived. Keep empty for default waypoint width.'},
  { dir = 'in', type = 'number', name = 'checkVelocity', hidden = true, default = 0.1, hardcoded = true, description = 'If given, vehicle has to be slower than this to be considered arrived.' },
}

C.tags = {'manual','driveTo'}

function C:init()
  self.previousVehicle = nil
  self.data.autoDisableOnArrive = true
  self:onNodeReset()
end

function C:onNodeReset()
  self.complete = false
  self.sentCommand = false
end

function C:_executionStopped()
  self:onNodeReset()
end

function C:findVehicle()
  local source
  if self.pinIn.aiVehId.value and self.pinIn.aiVehId.value ~= 0 then
    source = scenetree.findObjectById(self.pinIn.aiVehId.value)
    self.previousVehicle = self.pinIn.aiVehId.value
  else
    source = be:getPlayerVehicle(0)
    self.previousVehicle = -1
  end
  return source
end

function C:work()
  if self.pinIn.reset.value then
    self:onNodeReset()
  end

  if self.pinIn.flow.value then
    if self.complete then
      self.pinOut.flow.value = true
      self.pinOut.inRadius.value = true
      return
    end

    if self.pinIn.endLinePosition.value then
      local source = self:findVehicle()
      if source then
        local vData = map.objects[source:getID()]

        local rad = self.pinIn.checkDistance.value
        if not rad or rad == 0 then
          rad = 1
        end
        local frontPos = linePointFromXnorm(vec3(source:getCornerPosition(0)), vec3(source:getCornerPosition(1)), 0.5)
        local dist = (frontPos - self.pinIn.endLinePosition.value):length()
        self.pinOut.distance.value = dist
        if dist < rad then
          self.pinOut.inRadius.value = true
          self.complete = vData.vel:length() < (self.pinIn.checkVelocity.value or 10000)
        end
        if self.complete then
          if self.data.autoDisableOnArrive then
            source:queueLuaCommand('ai.setState({mode = "disabled"})')
          end
          return
        end
        if not self.sentCommand then
          source:queueLuaCommand('ai.setState({mode = "manual"})')
          self.sentCommand = true
        end
      end
    else
      self:__setNodeError("work","No target name or position given!")
    end
  end

end

return _flowgraph_createNode(C)