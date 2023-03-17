-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

local basePersonality = {aggression = 0.5, anger = 0.5, patience = 0.5, bravery = 0.5, lawfulness = 0.5}

function C:init(veh, name, data)
  data = data or {}
  self.veh = veh
  self.name = name or 'none'
  self.class = 'none'
  self.actionName = 'none' -- specific action name
  self.actionTimer = 0
  self.state = 'none' -- generic state name
  self.randomActionProbability = 0 -- if random actions are enabled, this is the threshold for doing a special action after refresh
  self.useStaticPersonality = data.useStaticPersonality or false -- if true, personality values do not get randomized and stay neutral
  self.keepPersonalityOnRefresh = data.keepPersonalityOnRefresh or false
  self.keepActionOnRefresh = data.keepActionOnRefresh or false
  self.lockAction = false
  self.targetVisible = false
  self.targetNear = false

  self.personalityModifiers = {}
  self.driver = {
    personality = deepcopy(basePersonality),
    aggression = veh.vars.baseAggression
  }
  self.flags = {}
  self.actions = {}
  self.baseActions = {
    pullOver = function (args)
      args = args or {}
      if self.veh.isAi then
        local legalSide = map.getRoadRules().rightHandDrive and -1 or 1
        local changeLaneDist = args.dist or self.veh:getBrakingDistance() -- uses expected braking distance
        local sideDist = legalSide * 5 -- should be distance to side
        if args.useWarnSignal then
          be:getObjectByID(self.veh.id):queueLuaCommand('electrics.set_warn_signal(1)')
        end

        self.veh:setAiMode('traffic')
        self.veh.queuedFuncs.laneChange = {timer = 0.25, vLua = 'ai.laneChange(nil, '..changeLaneDist..', '..sideDist..')'}
        self.veh.queuedFuncs.setStopPoint = {timer = 0.25, vLua = 'ai.setStopPoint(nil, '..(changeLaneDist + 20)..')'}
      end

      self.flags.pullOver = true
      self.state = 'pullOver'
    end,
    driveToTarget = function (args)
      args = args or {}
      if self.veh.isAi and args.target then
        if type(args.target) == 'string' then -- waypoint
          be:getObjectByID(self.veh.id):queueLuaCommand('ai.setMode("manual")')
          be:getObjectByID(self.veh.id):queueLuaCommand('ai.setTarget("'..args.target..'")')
        else
          -- position
        end
        self.mapTarget = args.target
      end
      self.state = 'driveToTarget'
    end,
    disabled = function ()
      if self.veh.isAi then
        self.veh:setAiMode('stop')
        be:getObjectByID(self.veh.id):queueLuaCommand('electrics.set_warn_signal(1)')
      end
      self.state = 'disabled'
    end
  }
end

function C:postInit()
  if not self.keepActionOnRefresh then
    self:resetAction()
  end
  if not self.keepPersonalityOnRefresh then
    self:applyPersonality(self:generatePersonality())
  end
  self:onRefresh()
end

function C:setupFlowgraph(fgFile, varData)
  local path = FS:fileExists(fgFile or '')
  if not fgFile then
    log('E', 'traffic', 'Flowgraph file not found: '..dumps(fgFile))
    return
  end

  --varName = type(varName) == 'string' and varName or 'vehicleId'
  -- load the flowgraph and set its variables
  self.flowgraph = core_flowgraphManager.loadManager(fgFile)
  self.flowgraph.transient = true -- prevent flowgraph from restarting flowgraphs after ctrl+L
  for key, value in pairs(varData or {}) do
    if self.flowgraph.variables:variableExists(key) then
      self.flowgraph.variables:changeBase(key, value)
    else
      log('W', 'traffic', 'Flowgraph missing required variable when setting up baserole: '..dumps(key) .. " -> " .. dumps(value))
    end
  end
  self.flowgraph.vehicle = self.veh
  self.flowgraph.vehId = self.veh.id
  self.flowgraph:setRunning(true)
  self.flowgraph.modules.traffic.keepTrafficState = true
  self.veh:setAiMode('disabled') -- this sets self.isAi to false, preventing respawning and auto actions
  self.lockAction = true
end

function C:clearFlowgraph()
  if self.flowgraph then
    self.flowgraph:setRunning(false, true)
    self.flowgraph = nil
    self.veh:setAiMode()
    self.lockAction = false
  end
end

function C:setTarget(id)
  local obj = be:getObjectByID(self.veh.id)
  if id and be:getObjectByID(id) then
    self.targetId = id
    if self.veh.isAi then
      obj:queueLuaCommand('ai.setTargetObjectID('..self.targetId..')')
    end
  end
end

function C:setAction(name, args)
  if name and self.actions[name] then
    if not self.lockAction then
      self.actions[name](args)
      self.actionName = name
      extensions.hook('onTrafficAction', self.veh.id, {targetId = self.targetId or 0, name = name, data = args or {}})
    end
  else
    log('E', 'traffic', 'Traffic role action not found: '..tostring(name))
  end
end

function C:resetAction()
  if self.lockAction then return end
  if self.veh.isAi then
    self.veh:setAiMode() -- reset AI mode to whatever the main mode was
    self.veh:setAiAware()
    self.veh:resetElectrics()
  end
  table.clear(self.flags)
  self.state = 'none'
  self.actionName = 'none'
  self.targetId = nil
  self.mapTarget = nil
end

function C:generatePersonality() -- returns a randomly generated personality
  if not self.veh.isAi then return end

  local data = {}
  local params = {aggression = 'gauss', anger = 'linear', patience = 'linear', bravery = 'linear', lawfulness = 'linear'}

  for k, v in pairs(params) do
    local mod = self.driver.personalityModifiers or {} -- contains: {{trait = {offset = value, min = value, max = value}}, ...}
    local randomValue = 0.5
    if not self.useStaticPersonality then
      randomValue = v == 'gauss' and randomGauss3() / 3 or math.random()
    end

    data[k] = clamp(randomValue + (mod.offset or 0), mod.min or 0, mod.max or 1) -- Gaussian distribution
  end

  return data
end

function C:applyPersonality(data) -- sends parameters to ai.lua
  if type(data) ~= 'table' then
    self.driver.personality = deepcopy(basePersonality)
    return
  end
  local obj = be:getObjectByID(self.veh.id)

  self.driver.personality = tableMerge(self.driver.personality, data)
  self.driver.aggression = clamp(self.veh.vars.baseAggression + (self.driver.personality.aggression - 0.5) * 0.4, 0.25, 1)
  obj:queueLuaCommand('ai.setAggression('..self.driver.aggression..')')

  local params = {
    trafficWaitTime = data.lawfulness >= 0.1 and data.patience * 3 or 0, -- intersection & horn waiting time
    trafficActionTime = math.max(0.1, data.anger - data.patience * 0.5) * 2, -- horn duration
    trafficSideCoef = data.bravery * 2 -- side avoidance coef (not implemented yet)
  }
  obj:queueLuaCommand('ai.setParameters('..serialize(params)..')')
end

function C:checkTargetVisible(id)
  local visible = false
  local targetId = id or self.targetId
  local targetVeh = targetId and gameplay_traffic.getTrafficData()[targetId]
  if targetVeh then
    visible = self.veh:checkRayCast(targetVeh.pos + vec3(0, 0, 1))
  end

  return visible
end

function C:tryRandomEvent()
end

function C:onRefresh()
end

function C:onRoleStarted()
end

function C:onRoleEnded()
end

function C:onCrashDamage(data)
end

function C:onOtherCrashDamage(otherId, data)
end

function C:onCollision(otherId, data)
end

function C:onOtherCollision(id1, id2, data)
end

function C:onTrafficTick(tickTime)
end

function C:onUpdate(dt, dtSim)
end

function C:onSerialize()
  local data = {
    id = self.veh.id,
    name = self.name,
    state = self.state,
    actionName = self.actionName,
    targetId = self.targetId
  }
  return data
end

function C:onDeserialized(data)
  self.veh = gameplay_traffic.getTrafficData()[data.id]
  self.name = data.name
  self.state = data.state
  self.actionName = data.actionName
  self.targetId = data.targetId
end

return function(derivedClass, ...)
  local o = ... or {}
  setmetatable(o, C)
  C.__index = C
  o:init(o.veh, o.name)

  for k, v in pairs(derivedClass) do
    o[k] = v
  end

  o:init()
  o:postInit()
  return o
end
