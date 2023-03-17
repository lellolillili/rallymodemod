-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'AI Arrive'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Drives toward a target waypoint.'
C.category = 'once_f_duration'
C.behaviour = { duration = true }


C.pinSchema = {
  { dir = 'in', type = 'number', name = 'aiVehId', description = 'The AI vehicle. Uses player vehicle if no value given.' },
  { dir = 'in', type = 'string', name = 'waypointName', description = 'Name of waypoint to be driven to.' },
  { dir = 'in', type = 'number', name = 'checkDistance', hidden = true, default = 1, description = 'If the vehicle is closer than this distance, it is considered arrived. Keep empty for default waypoint width.'
  },
  { dir = 'in', type = 'number', name = 'checkVelocity', hidden = true, default = 0.1, hardcoded = true, description = 'If given, vehicle has to be slower than this to be considered arrived.' },
  { dir = 'out', type = 'number', name = 'distance', hidden = true, description = 'Distance to the center of the target waypoint.' }
}


C.legacyPins = {
  _in = {
    inRadius = 'complete'
  }
}

C.tags = {'manual', 'driveTo'}

function C:init()
  self.sentCommand = false
  self.data.autoDisableOnArrive = true
  self:setDurationState('inactive')
end

function C:onNodeReset()
  self.sentCommand = false
  self:setDurationState('inactive')
end

function C:_executionStopped()
  self:onNodeReset()
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text("State: "..self.durationState)
  im.Text("Command sent: "..(self.sentCommand and 'yes' or 'no'))
end

function C:findVehicle()
  local source
  if self.pinIn.aiVehId.value and self.pinIn.aiVehId.value ~= 0 then
    source = scenetree.findObjectById(self.pinIn.aiVehId.value)
  else
    source = be:getPlayerVehicle(0)
  end
  return source
end

function C:work()

  if self.pinIn.flow.value == true then
    if self.durationState == 'finished' then return end

    if self.pinIn.waypointName.value then
      local node = map.getMap().nodes[self.pinIn.waypointName.value]
      if not node then
        self:__setNodeError("work", "No target waypoint of name " .. self.pinIn.waypointName.value .. " found!")
        return
      end

      local source = self:findVehicle()
      if source then
        local radius = self.pinIn.checkDistance.value
        if not radius or radius == 0 then
          radius = node.radius
        end
        local frontPos = linePointFromXnorm(vec3(source:getCornerPosition(0)), vec3(source:getCornerPosition(1)), 0.5)
        local dist = (frontPos - node.pos):length()
        self.pinOut.distance.value = dist

        if dist < radius and map.objects[source:getID()].vel:length() < (self.pinIn.checkVelocity.value or 10000) then
          self:setDurationState('finished')
          if self.data.autoDisableOnArrive then
            source:queueLuaCommand('ai.setState({mode = "disabled"})')
          end
        end
        if not self.sentCommand then
          print("Command sent to arrive to: " .. self.pinIn.waypointName.value)
          source:queueLuaCommand('ai.setState({mode = "manual"})')
          source:queueLuaCommand('ai.setTarget("'..self.pinIn.waypointName.value..'")')
          self.sentCommand = true
          self:setDurationState('started')
        end
      end
    else
      self:__setNodeError("work", "No target waypoint name given!")
    end
  end
end

return _flowgraph_createNode(C)
