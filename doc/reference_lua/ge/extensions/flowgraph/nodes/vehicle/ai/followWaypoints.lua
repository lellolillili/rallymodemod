-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = 'AI Follow Waypoints'
C.description = 'Sets a vehicle to follow a list of waypoints.'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.category = 'once_f_duration'
C.tags = { 'ai', 'path', 'route', 'waypoint', 'race' }


C.pinSchema = {
  { dir = 'in', type = 'table', name = 'navgraphPath', tableType = 'navgraphPath', description = 'Navgraph path for the AI to follow.' },
  { dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle id to set the AI for; if not given, uses the player vehicle.' },
  { dir = 'in', type = 'number', name = 'lapCount', hidden = true, default = 1, description = 'Number of laps for the AI to drive.' },
  { dir = 'in', type = 'bool', name = 'stopAtFinish', hidden = true, default = true, description = 'If true, AI stops precisely at the last waypoint.' },
  { dir = 'out', type = 'string', name = 'finalWp', hidden = true, description = 'Name of the final waypoint in the route.' }
}
C.legacyPins = {
  _in = {
    waypointData = 'navgraphPath'
  }
}

function C:init()
  self:onNodeReset()
end

function C:_executionStopped()
  self:onNodeReset()
end

function C:onNodeReset()
  self.aiPath = {}
  self.lapsDone = 0
  self.lapCount = 0
  self.lapFlag = true
  self.pinOut.finalWp.value = nil
  self:setDurationState('inactive')
end

function C:workOnce()
  if self.pinIn.navgraphPath.value then
    self.aiPath = self.pinIn.navgraphPath.value.aiPath or self.pinIn.navgraphPath.value -- backwards compatibility
  end

  if not self.aiPath[1] then
    return
  end

  local veh
  if self.pinIn.vehId.value and self.pinIn.vehId.value ~= 0 then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end

  self.lapCount = math.max(1, self.pinIn.lapCount.value or 1)
  self.pinOut.finalWp.value = self.aiPath[#self.aiPath]
  local aiPath = shallowcopy(self.aiPath)
  if self.lapCount > 1 then
    table.insert(aiPath, aiPath[1]) -- allows AI to continue to the next lap
  end

  local wpSpeeds = {}
  if not self.pinIn.stopAtFinish.value then
    wpSpeeds[self.pinOut.finalWp.value] = 100 -- last waypoint
  end

  veh:queueLuaCommand('ai.driveUsingPath({wpTargetList = ' .. serialize(aiPath) .. ', wpSpeeds = ' .. serialize(wpSpeeds) .. ', noOfLaps = ' .. self.lapCount .. ', aggression = 1})')

  self:setDurationState('started')

end

function C:work()
  if self.durationState == 'started' then
    local veh
    local mapNodes = map.getMap().nodes

    if self.pinIn.vehId.value and self.pinIn.vehId.value ~= 0 then
      veh = scenetree.findObjectById(self.pinIn.vehId.value)
    else
      veh = be:getPlayerVehicle(0)
    end

    local vehPos = veh:getPosition()
    if not self.lapFlag and vehPos:squaredDistance(mapNodes[self.pinOut.finalWp.value].pos) < square(mapNodes[self.pinOut.finalWp.value].radius) then
      -- vehicle is within radius of final waypoint
      self.lapsDone = self.lapsDone + 1
      self.lapFlag = true
    end
    if self.lapFlag and vehPos:squaredDistance(mapNodes[self.aiPath[1]].pos) < vehPos:squaredDistance(mapNodes[self.pinOut.finalWp.value].pos) then
      -- vehicle is closer to 1st waypoint than to lap waypoint
      self.lapFlag = false
    end

    if self.lapsDone == self.lapCount then
      self:setDurationState('finished')
    end
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text('State: ' .. tostring(self.durationState))
  if self.durationState ~= 'inactive' then
    if not self.aiPath or not self.aiPath[1] then
      im.Text('No path found!')
    else
      im.Text('# of Waypoints: ' .. #self.aiPath)
      im.Text('Final Target: ' .. self.pinOut.finalWp.value)
    end
  end
end

return _flowgraph_createNode(C)
