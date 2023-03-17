-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.state = {goals={}}

local logTag = 'raceGoals'

local helper = require('scenario/scenariohelper')

local goalSchema= {
  timeLimit      ={msg="localizedString",maxTime="number",countdown="number",waitTime="number"},
  nomove         ={msg="localizedString",triggerEndOnly="boolean"},
  position       ={msg="localizedString",purpose="string",endPoint="string"},
  damage         ={msg="localizedString",purpose="string",damageLimit="number",damageThreshold="number"},
  distance       ={msg="localizedString",purpose="string",maxDistance="number",minDistance="number",distanceEnable="number",target="string"},
  speed          ={msg="localizedString",purpose="string",maxSpeed="number",minSpeed="number",maxTimeout="number",wayPointNum="table",delay="number"},
  drift          ={msg="localizedString",failMsg="localizedString",minDrift="number",maxDrift="number",timeAllowance="number"},
  finishRace     ={passed="localizedString",failed="localizedString", mustWin="boolean"},
  wayPointAction ={wayPointNum="table",wayPointMsg="table"},
}


-- to check if the goals written in JSON file is the same as those in goal_table
-- to be sure that they are the same
local function checkGoalItem( goalSchema, id, gkey, val)
  local success = false
  local invalidType = false
  local invalidKey = false
  local invalidValue = false
  for k,g in pairs(goalSchema) do
    invalidKey=false
    invalidType = false
    for kl,vl in pairs(g) do
      invalidValue = false
      if k == id and kl==gkey then
        if vl==type(val) then
          return
        end
        if vl=="localizedString" then
          if type(val) == "table" and type(val.txt)=="string" then
            return
          end
          if type(val) == "string" then
            if not string.startswith(val, "scenarios.") then
              log("W", "", "Possible missing localization for '"..dumps(gkey).."' in scenario goal: "..dumps(val))
            end
            return
          end
        end
      end
      if k~=id then
        invalidKey = true
      end
      if kl~=gkey then
        invalidValue = true
        invalidKey = false
      end
      if vl~=type(val) then
        invalidType = true
      end
    end
  end
  local reason
  if invalidKey   then reason = 'invalid key: '  ..dumps(  id) end
  if invalidType  then reason = 'invalid type: ' ..dumps(gkey) end
  if invalidValue then reason = 'invalid value: '..dumps(gkey)..', or its value is not related to "'..dumps(id) .. '"' end
  log("E", logTag, "Schema error in scenario json: "..reason)
end

---checks if goals names in json file are correct names
local function validateGoalSchema()
  local scenario = scenario_scenarios.getScenario()
  if not scenario then return end

  for _,v in ipairs(scenario.goals.vehicles) do
    if type(v.value) == "table" then
      for gkey,val in pairs(v.value) do
        checkGoalItem(goalSchema, v.id, gkey, val)
      end
    end
  end
end
--[[
this function checks if the passing param is table or array
@param t table
]]
local function istable(t)
    for k, _ in pairs(t) do
        if type(k) ~= "number" then
            return true
        end
    end
    return false
end

local function loadGoals(scenario)
  -- log("D", logTag, 'LoadGoals called...')
  M.state.goals = {}
  local goals = M.state.goals
  for _,instance in ipairs(scenario.goals.vehicles) do
    local goalName = instance.id
    local goalPaths = {'scenario/'..goalName, 'scenario/'..goalName..'goal'}
    local goal = goals[goalName]
    if not goal then
      for _, file in ipairs(goalPaths) do
        if FS:fileExists('lua/ge/extensions/'..file..'.lua') then
          goal = require(file)
          log("D", logTag, 'Loaded goal: '..file)
          goals[goalName] = goal
          goto continue
        end
      end
      ::continue::
      if not goal then
        log("E", logTag, 'Cannot find goal: '..dumps(goalPaths))
      end
    end
  end

  for _, goal in pairs(goals) do
    goal.init(scenario)
  end
  -- log("D", logTag, 'LoadGoals ended...'..dumps(M.state.goals))
end

local function initialiseGoals()
  local scenario = scenario_scenarios.getScenario()
  if not scenario then return end
  -- log("D", logTag, 'initialiseGoals..')

  scenario.targetName= ""
  -- setup the goals tables
  scenario.goals = {}
  scenario.goals.vehicles = {}

  -- vehicle goals
  if scenario.vehicles then
    -- iterate over all vehicles in the scene and find if goals exist
    for vName, vObjId in pairs(scenario.vehicleNameToId) do
      local tempGoals = nil

      if scenario.vehicles[vName] then
        if scenario.vehicles[vName].goal then
          tempGoals= scenario.vehicles[vName].goal
        end
      elseif scenario.vehicles['*'] and scenario.vehicles['*'].goal then
        tempGoals = scenario.vehicles['*'].goal
      end

       if tempGoals then
        for k, v in pairs(tempGoals) do
          local goal = {}
          goal.vehicleName = vName
          goal.vId = vObjId
          local isTable = istable(tempGoals)
          if not isTable then
            goal.id = tempGoals[k]
            goal.value = {msg = "you hit something"}
          else
            goal.id = k
            goal.value= v
          end
          goal.status = {}
          local fobj = be:getObjectByID(vObjId)
          if fobj then
            goal.startPos = fobj:getPosition()
          end
          table.insert(scenario.goals.vehicles, goal)
        end
         --dump(scenario.goals.vehicles)
      end
    end
  end
  validateGoalSchema()
  loadGoals(scenario)

  extensions.hook('onRaceGoalsInitilised', scenario)
end

local function updateGoalsFinalStatus()
  local scenario = scenario_scenarios.getScenario()
  if not scenario then return end

  local goals = M.state.goals
  for i, goal in pairs(goals) do
    goal.updateFinalStatus(scenario)
  end
end

local function onRaceStart()
  local scenario = scenario_scenarios.getScenario()
  if not scenario then return end
  local goals = M.state.goals
  for i, goal in pairs(goals) do
    goal.processState(scenario, 'onRaceStart')
  end
end

local function onRaceInit()
  local scenario = scenario_scenarios.getScenario()
  if not scenario then return end
  local goals = M.state.goals
  for i, goal in pairs(goals) do
    goal.processState(scenario, 'onRaceInit')
  end
end

local function onRaceWaypointReached(data)
  local scenario = scenario_scenarios.getScenario()
  if not scenario then return end
  local goals = M.state.goals
  for i, goal in pairs(goals) do
    goal.processState(scenario, 'onRaceWaypointReached', data)
  end
end

local function onRaceTick(raceTickTime, scenarioTimer)
  local scenario = scenario_scenarios.getScenario()
  if not scenario then return end
  local data = {raceTickTime=raceTickTime, scenarioTimer=scenarioTimer}
  local goals = M.state.goals
  for i, goal in pairs(goals) do
    goal.processState(scenario, 'onRaceTick', data)
  end
end

local function onRaceResult(status)
  local scenario = scenario_scenarios.getScenario()
  if not scenario then return end

  scenario.finalStatus = status
  local goals = M.state.goals
  for i, goal in pairs(goals) do
    goal.processState(scenario, 'onRaceResult')
  end
end

local function onCountdownEnded()
  local scenario = scenario_scenarios.getScenario()
  if not scenario then return end
  local goals = M.state.goals
  for i, goal in pairs(goals) do
    goal.processState(scenario, 'onCountdownEnded')
  end
end

M.onRaceWaypointReached = onRaceWaypointReached
M.onRaceTick = onRaceTick
M.onRaceResult = onRaceResult
M.onRaceInit = onRaceInit
M.onRaceStart = onRaceStart
M.onRaceEnd = onRaceEnd
M.updateGoalsFinalStatus = updateGoalsFinalStatus
M.onCountdownEnded = onCountdownEnded
M.initialiseGoals = initialiseGoals

return M
