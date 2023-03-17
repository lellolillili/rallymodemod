-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui
local detailedTimes = false
local C = {}
C.windowDescription = 'General'

function C:init(raceEditor)
  self.raceEditor = raceEditor
  self.startIndex = -1
  self.state = 'setup'
end

function C:setPath(path)
  self.path = path
end

function C:setupRace()
  local oldLap = self.race and self.race.lapCount or 1
  self.race = require('/lua/ge/extensions/gameplay/race/race')()
  self.race:setPath(self.path)
  self.race.lapCount = oldLap
  self.race.useDebugDraw = true
  self.race:setVehicleIds({be:getPlayerVehicleID(0)})
end

function C:draw(dt)
  if self.state == 'setup' then
    self:drawSetup()
  elseif self.state == 'race' then
    self.race:onUpdate(dt)
    self:drawRace()
  elseif self.state == 'stopped' then
    self:drawStopped()
  end

end

function C:drawSetup()
  local lapCount = im.IntPtr(self.race.lapCount or 1)
  if im.InputInt("Lap Count", lapCount) then
    self.race.lapCount = math.max(1,lapCount[0])
  end
  --if self.path.defaultStartPosition ~= -1 then
    for i, sp in ipairs(self.path.startPositions.sorted) do
      if im.SmallButton("Move to " .. sp.name) then
        sp:moveResetVehicleTo(be:getPlayerVehicleID(0))
      end
    end
  --end

  if im.Button("Start") then
    editor.setEditorActive(false)
    self.race.path.config.rollingStart = false
    self.state = 'race'
    self.race:startRace()
  end
  if im.Button("Start Rolling") then
    editor.setEditorActive(false)
    self.race.path.config.rollingStart = true
    self.state = 'race'
    self.race:startRace()
  end

  im.Separator()

  if im.Button("AI Drive Test Current Vehicle") then
    local veh = be:getPlayerVehicle(0)
    self.path:getAiPath()
    veh:queueLuaCommand('ai.driveUsingPath({wpTargetList = ' .. serialize(self.path.aiPath) .. ', wpSpeeds = ' .. serialize({}) .. ', noOfLaps = ' .. self.race.lapCount .. ', aggression = 1})')
  end

  if im.Button("Place all vehicles in scene onto starting positions") then
    local vehs = getObjectsByClass("BeamNGVehicle")
    for i, veh in ipairs(vehs) do
      local sp = self.path.startPositions.sorted[i]
      if sp and not sp.missing then
        sp:moveResetVehicleTo(veh:getId())
      end
    end
  end

  if im.Button("AI Drive all vehicles in scene") then
    local veh = be:getPlayerVehicle(0)
    self.path:getAiPath()
    local vehs = getObjectsByClass("BeamNGVehicle")
    for _, veh in ipairs(vehs) do
      local isClose = false
      for i, sp in ipairs(self.path.startPositions.sorted) do
        if (vec3(sp.pos) - veh:getPosition()):length() < 10 then
          isClose = true
        end
      end
      if isClose then
        veh:queueLuaCommand('ai.driveUsingPath({wpTargetList = ' .. serialize(self.path.aiPath) .. ', wpSpeeds = ' .. serialize({}) .. ', noOfLaps = ' .. self.race.lapCount .. ', aggression = 1})')
        dump('ai.driveUsingPath({wpTargetList = ' .. serialize(self.path.aiPath) .. ', wpSpeeds = ' .. serialize({}) .. ', noOfLaps = ' .. self.race.lapCount .. ', aggression = 1})')
      end
    end
  end
end

function C:drawRace(dt)
  if im.Button("Stop") then
    self.race:abortRace(self.race.vehIds[1])
    editor.setEditorActive(true)
    self.state = 'stopped'
    self.raceEditor.show()
  end
  im.SameLine()
  if im.Button("State") then
    dump(self.race.states[self.race.vehIds[1]])
  end
  im.SameLine()
  if im.Button("Recover") then
    self.race:requestRecover(self.race.vehIds[1])
  end
  self:drawTimes()
  self:drawEventLog()
end

function C:drawStopped()
  if im.Button("Restart") then
    self:setupRace()
    self.state = 'setup'
  else
    self:drawEventLog()
    self:drawTimes()
  end
end

function C:drawTimes()
  local avail = im.GetContentRegionAvail()
  im.BeginChild1("Times", im.ImVec2(avail.x, avail.y/2-5), 0, im.WindowFlags_AlwaysVerticalScrollbar)

  if self.race:inDrawTimes(self.race.vehIds[1], im, detailedTimes) then
    detailedTimes = not detailedTimes
  end
  im.EndChild()

end

function C:drawEventLog()
  local avail = im.GetContentRegionAvail()
  im.BeginChild1("EventLog", im.ImVec2(avail.x, avail.y-5), 0, im.WindowFlags_AlwaysVerticalScrollbar)
  self.race:inDrawEventlog(self.race.vehIds[1], im)
  im.EndChild()
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
