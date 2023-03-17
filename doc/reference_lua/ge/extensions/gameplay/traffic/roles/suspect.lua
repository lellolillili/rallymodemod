-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

function C:init()
  self.personalityModifiers = {
    aggression = {offset = 0.2},
    lawfulness = {offset = -0.5}
  }
  self.actions = {
    speed = function ()
      if self.veh.isAi then
        be:getObjectByID(self.veh.id):queueLuaCommand('ai.setSpeedMode("off")')
      end
    end,
    reckless = function ()
      if self.veh.isAi then
        be:getObjectByID(self.veh.id):queueLuaCommand('ai.setAvoidCars("off")')
      end
    end,
    watchPolice = function ()
      self.state = 'wanted'
      self.flags.flee = nil
    end,
    fleePolice = function ()
      if self.veh.isAi then
        be:getObjectByID(self.veh.id):queueLuaCommand('controller.setFreeze(0)')
        be:getObjectByID(self.veh.id):queueLuaCommand('ai.setMode("flee")')
        be:getObjectByID(self.veh.id):queueLuaCommand('ai.driveInLane("off")')
      end
      self.veh:modifyRespawnValues(1200, 50)
      self.state = 'flee'
      self.flags.flee = 1
      self.flags.busy = 1
    end,
    arrest = function ()
      be:getObjectByID(self.veh.id):queueLuaCommand('controller.setFreeze(1)')
      self.flags.freeze = 1
      self.state = 'stop'
    end,
    postArrest = function ()
      be:getObjectByID(self.veh.id):queueLuaCommand('controller.setFreeze(0)')
      self.flags.freeze = nil
      self.flags.flee = nil
      self.flags.busy = nil
      self.state = 'none'
    end
  }
end

function C:onRoleEnded()
  if gameplay_traffic.showMessages and be:getPlayerVehicleID(0) == self.targetId then
    ui_message('ui.traffic.suspectEvade', 5, 'traffic', 'traffic')
  end
end

function C:onTrafficTick(tickTime)
  local sightThreshold = self.veh.isAi and 0.25 or 1
  if self.state == 'wanted' and self.veh.pursuit.sightValue >= sightThreshold then
    for id, veh in pairs(gameplay_police.getPoliceVehicles()) do
      if not veh.role.flags.pursuit and not veh.role.flags.reset and veh:getInteractiveDistance(self.veh.pos, true) <= square(100) then
        gameplay_police.setPursuitMode(2, self.veh.id, id)
        self:setTarget(id)
        break
      end
    end
  end
end

function C:onUpdate(dt, dtSim)

end

return function(...) return require('/lua/ge/extensions/gameplay/traffic/baseRole')(C, ...) end