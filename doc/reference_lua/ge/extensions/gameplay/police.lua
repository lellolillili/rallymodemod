-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local logTag = 'police'

local defaultScoreLevels = {100, 500, 2000}
local policeVehs = {}
local policePropIds = {}
local vars

-- common functions --
local min = math.min
local max = math.max
local random = math.random

M.enabled = true -- if false, runtime police logic won't run

local function checkRoadblock(vehIds, rbWidth, useLength) -- checks how many of the input vehicles can fit in a roadblock
  -- useLength can be nil
  if type(vehIds) ~= 'table' then return end
  rbWidth = rbWidth or 10 -- maximum roadblock width

  local validVehIds = {}
  local temp = {}
  local totalLength = 0

  for _, id in ipairs(vehIds) do
    local veh = be:getObjectByID(id)
    if veh then
      local length
      if useLength == nil then
        length = max(veh.initialNodePosBB:getExtents().x, veh.initialNodePosBB:getExtents().y) -- automatically uses best axis
      else
        length = useLength and veh.initialNodePosBB:getExtents().y or veh.initialNodePosBB:getExtents().x
      end
      table.insert(temp, {id, length})
    end

    table.sort(temp, function(a, b) return a[2] < b[2] end) -- smallest to largest length
  end

  for _, v in ipairs(temp) do
    rbWidth = rbWidth - v[2]

    if rbWidth < 0 then break end
    totalLength = totalLength + v[2]
    table.insert(validVehIds, v[1])
  end

  return validVehIds, totalLength
end

local function placeRoadblock(vehIds, pos, rot, placeData) -- places a roadblock
  if type(vehIds) ~= 'table' or not pos or not rot then return end
  placeData = placeData or {}
  placeData.width = placeData.width or 10 -- available width of roadblock
  placeData.angle = placeData.angle or 0 -- angle offset for vehicles, in degrees

  local dirVec = vec3(0, 1, 0):rotated(rot)
  local upVec = map.surfaceNormal(pos, 1)
  local rightVec = dirVec:cross(upVec)
  local amount = #vehIds
  local transforms = {}

  for i, id in ipairs(vehIds) do
    local veh = be:getObjectByID(id)
    if veh then
      local nPos = veh:getInitialNodePosition(veh:getRefNodeId())

      -- make sure that the available space is validated
      local sideSeg = placeData.width / amount
      local sideDisp = lerp(sideSeg * (i - 1), sideSeg * i, 0.5) - placeData.width * 0.5
      local sideVec = rightVec * sideDisp
      local dir = sign2(sideDisp)
      local angle = placeData.angle
      if placeData.centerAngle and sideDisp == 0 then -- unique rotation for center object
        angle = placeData.centerAngle
      end

      local newQuat = quatFromDir(rightVec * dir, upVec) * quatFromAxisAngle(upVec, math.rad(angle * dir))
      local offset = nPos:rotated(newQuat)

      local newPos = pos + sideVec - vec3(offset.x, offset.y, -nPos.z)
      table.insert(transforms, {pos = newPos, rot = newQuat})
      --spawn.safeTeleport(veh, newPos, newQuat, true)
    end
  end

  core_multiSpawn.placeGroup(vehIds, {ignoreAdjust = true, ignoreSafe = true, customTransforms = transforms}) -- delays some frames to improve performance
end

local function setPropsActive(active, reset)
  for _, v in ipairs(policePropIds) do
    be:getObjectByID(v):setActive(active and 1 or 0)
    if reset then
      be:getObjectByID(v):queueLuaCommand("recovery.loadHome()")
    end
  end
end

local function insertProp(propId) -- adds a prop to use for roadblocks
  local veh = be:getObjectByID(propId or 0)
  if veh and not gameplay_traffic.getTrafficData()[propId] and not arrayFindValueIndex(policePropIds, propId) then
    table.insert(policePropIds, propId)
  end
end

local function removeProp(propId) -- removes a prop from the props list
  local idx = arrayFindValueIndex(policePropIds, propId or 0)
  if idx then
    table.remove(policePropIds, idx)
  end
end

local function resetPursuitVars() -- resets pursuit variables to default
  vars = {
    scoreLevels = deepcopy(defaultScoreLevels),
    strictness = 0.5,
    arrestLimit = 5,
    arrestRadius = 30,
    evadeLimit = 45,
    evadeRadius = 80,
    roadblockFrequency = 0.5
  }
end
resetPursuitVars()

local function setPursuitVars(data) -- sets various traffic variables
  if type(data) ~= 'table' then return end
  vars = tableMerge(vars, data)
end

local function getPoliceVehicles()
  return policeVehs
end

local function setPursuitMode(mode, targetId, policeId) -- sets pursuit mode; -1 = busted, 0 = off, 1 and higher = pursuit level
  targetId = targetId or be:getPlayerVehicleID(0) -- target is player vehicle by default
  if not targetId then return end

  local traffic = gameplay_traffic.getTrafficData()
  local targetVeh = traffic[targetId]
  if not traffic[targetId] or targetId == policeId then return end
  local pursuit = targetVeh.pursuit

  mode = clamp(mode or 0, -1, 3)
  local lastMode = pursuit.mode

  if mode == -1 then
    targetVeh.role:setAction('arrest')
    pursuit.timers.main = 0
    pursuit.timers.arrest = 0

    for id, veh in pairs(traffic) do
      if id ~= targetId and veh.pursuit.mode == 1 then -- temporarily forgive other vehicles with low pursuit mode
        setPursuitMode(0, id)
      end
    end
  elseif mode == 0 then -- reset pursuit data
    targetVeh.role:setAction('postArrest')
    targetVeh.role:resetAction()
    targetVeh:resetAll()

    if targetVeh.role.name == 'suspect' then
      targetVeh:setRole(targetVeh.autoRole)
    end
    if lastMode == -1 then
      targetVeh.role.driver.behavioral.askInsurance = false
      targetVeh.pursuit.cooldown = true
    end
  else
    if targetVeh.role.name ~= 'suspect' then
      targetVeh:setRole('suspect')
    end

    if targetVeh.role.state ~= 'flee' then
      if targetVeh.role.state == 'wanted' then -- "wanted" vehicles will always try to flee
        local policePlayer = be:getPlayerVehicleID(0) == policeId and policeVehs[policeId]
        if gameplay_traffic.showMessages and policePlayer and not policePlayer.role.flags.busy then
          local str = translateLanguage('ui.traffic.suspectFlee', 'A suspect is fleeing from you! Vehicle:')
          str = str..' '..targetVeh.model.name
          ui_message(str, 5, 'traffic', 'traffic')
        end

        targetVeh.role:setAction('fleePolice')
      else
        if targetVeh.isAi then
          if targetVeh.role.driver.personality.lawfulness < 0.25 then targetVeh.role:setAction('fleePolice') end -- if is AI, car can flee or pull over
        else
          targetVeh.role:setAction('fleePolice')
          if gameplay_traffic.showMessages and be:getPlayerVehicleID(0) == targetId then
            ui_message('ui.traffic.policePursuit', 5, 'traffic', 'traffic')
          end
        end
      end
    end
  end

  pursuit.mode = mode

  for id, veh in pairs(policeVehs) do
    if veh.role.state ~= 'disabled' and (not policeId or id == policeId) then
      if mode == -1 then -- player is busted
        if veh.role.targetId == targetId then
          veh.role:setAction('pursuitEnd')
        end
      elseif mode == 0 then
        if veh.role.targetId == targetId then
          veh.role:resetAction()
        end
      elseif mode >= 1 then
        veh.role:setTarget(targetId)
        veh.role:setAction('pursuitStart', {mode = mode, targetId = targetId})
        pursuit.score = lastMode <= mode and max(pursuit.score, vars.scoreLevels[mode]) or min(pursuit.score, vars.scoreLevels[mode])
        pursuit.cooldown = false
      end
    end
  end

  extensions.hook('onPursuitModeUpdate', targetId, {mode = mode})
end

local function setSuspect(id)
  local veh = gameplay_traffic.getTrafficData()[id or 0]
  if veh then
    veh.tempRole = 'suspect'
    veh:setRole('suspect')
    veh.role:setAction('watchPolice')
  end
end

local function getPursuitData(id) -- returns pursuit data from the given vehicle, or the player vehicle by default
  -- exists for backwards compatibility
  id = id or be:getPlayerVehicleID(0)
  local veh = id and gameplay_traffic.getTrafficData()[id]
  if veh then
    return veh.pursuit
  end
end

local function getPursuitVars()
  return vars
end

local function onTrafficAction(id, data)
  if gameplay_traffic.getTrafficData()[id] then
    if data.name == 'rolePolice' then
      if not policeVehs[id] then
        policeVehs[id] = gameplay_traffic.getTrafficData()[id]
      end
    elseif data.prevName == 'rolePolice' then
       if policeVehs[id] then
        policeVehs[id] = nil
      end
    end
  end
end

local function onTrafficVehicleAdded(id)
  if gameplay_traffic.getTrafficData()[id].role.name == 'police' then
    policeVehs[id] = gameplay_traffic.getTrafficData()[id]
  end
end

local function onTrafficVehicleRemoved(id)
  if policeVehs[id] then
    policeVehs[id] = nil
  end
end

local function onTrafficStopped()
  table.clear(policeVehs)
end

local function onClientEndMission()
  table.clear(policeVehs)
  resetPursuitVars()
end

local function onUpdate(dt, dtSim)
  if not M.enabled or not be:getEnabled() or gameplay_traffic.getState() ~= 'on' or not next(policeVehs) then return end

  for id, veh in pairs(gameplay_traffic.getTrafficData()) do
    local pursuit = veh.pursuit
    local bestDist, bestInterDist = math.huge, math.huge
    local bestPoliceId

    for otherId, otherVeh in pairs(policeVehs) do -- check for visible targets from police
      if be:getObjectByID(otherId):getActive() then
        local data = otherVeh.role.validTargets[id]
        if data and data.dist < bestDist then
          bestDist = data.dist
          bestInterDist = data.interDist
          if data.visible then
            bestPoliceId = otherId
          end
        end
      end
    end

    local addSightValue
    local sightCoef = pursuit.mode >= 1 and 5 or 2
    if not bestPoliceId then
      addSightValue = -dtSim * 0.25
    else
      local targetDist = min(bestDist, bestInterDist) -- police look ahead dist or police vehicle dist, whichever is better
      addSightValue = (100 / targetDist) * dtSim * vars.strictness * sightCoef -- increments faster when nearer
    end
    pursuit.sightValue = clamp(pursuit.sightValue + addSightValue, 0, 1)
    pursuit.policeVisible = pursuit.sightValue >= 0.5

    if not pursuit.cooldown then
      local addScore = 0
      if pursuit.addScore > 0 then
        addScore = pursuit.addScore -- add score from pursuit infraction
      else
        if pursuit.mode >= 1 then
          addScore = vars.strictness * min(10, veh.speed) * dtSim * 2 -- gradual increase during pursuit
        end
      end
      pursuit.score = max(0, pursuit.score + addScore)
    else
      if veh.speed >= 9 then -- enable pursuits again
        pursuit.cooldown = false
      end
    end

    pursuit.addScore = 0

    -- pursuit mode processing
    if pursuit.mode >= 0 then
      for i, score in ipairs(vars.scoreLevels) do
        if pursuit.mode < i and pursuit.score >= score then
          if pursuit.mode == 0 then -- activates only nearest police vehicle at start of pursuit
            if not veh.queuedFuncs.pursuitStart then
              veh.queuedFuncs.pursuitStart = {timer = 1, func = setPursuitMode, args = {i, id, bestPoliceId}} -- small delay for lights & sirens
            end
            local tempData = deepcopy(pursuit)
            tempData.type = 'start'
            extensions.hook('onPursuitAction', id, tempData)
          else
            setPursuitMode(i, id)
          end
          break
        end
      end
    end

    -- active pursuit
    if pursuit.mode ~= 0 then
      local legalSide = map.getRoadRules().rightHandDrive and -1 or 1
      local arrestDist = pursuit.policeVisible and vars.arrestRadius or 5

      pursuit.policeAttack = pursuit.timers.evadeValue == 0 or pursuit.policeVisible -- true if police are actively in range of player

      -- arrest action
      if pursuit.mode >= 1 and pursuit.timers.arrest >= vars.arrestLimit then
        if gameplay_traffic.showMessages then
          if be:getPlayerVehicleID(0) == id then
            local str = pursuit.mode == 1 and 'ui.traffic.policeTicket' or 'ui.traffic.policeArrest'
            ui_message(str, 4, 'traffic', 'traffic')

            if pursuit.offensesList[1] then
              local temp = {}
              for _, v in ipairs(pursuit.offensesList) do
                table.insert(temp, translateLanguage('ui.traffic.infractions.'..v, v))
              end

              str = translateLanguage('ui.traffic.infractions.title', 'Infractions:')
              str = str..' '..table.concat(temp, ', ')
              ui_message(str, 5, 'trafficInfractions', 'traffic')
            end
          elseif be:getPlayerVehicleID(0) == veh.role.targetId or policeVehs[be:getPlayerVehicleID(0)] then
            ui_message('ui.traffic.suspectArrest', 5, 'traffic', 'traffic')
          end
        end
        local tempData = deepcopy(pursuit)
        tempData.type = 'arrest'
        extensions.hook('onPursuitAction', id, tempData)
        setPursuitMode(-1, id)
      end

      -- post arrest action
      if pursuit.mode == -1 and (pursuit.timers.arrest <= -5 or not veh.role.flags.freeze) then
        if gameplay_traffic.showMessages and be:getPlayerVehicleID(0) == id then
          ui_message('ui.traffic.driveAway', 5, 'traffic', 'traffic')
        end

        setPursuitMode(0, id)
      end

      -- visible and within arrest distance
      if bestPoliceId and bestDist < square(arrestDist) then
        if pursuit.mode >= 1 then
          if veh.speed <= 2.5 and policeVehs[bestPoliceId].speed <= 9 and bestDist < square(arrestDist) then
            pursuit.timers.arrest = min(vars.arrestLimit, pursuit.timers.arrest + dtSim)
          else
            pursuit.timers.arrest = 0
          end
        else
          pursuit.timers.arrest = max(-5, pursuit.timers.arrest - dtSim)
        end

        pursuit.timers.evade = 0
      else
        if pursuit.timers.evade >= vars.evadeLimit then
          local tempData = deepcopy(pursuit)
          tempData.type = 'evade'
          extensions.hook('onPursuitAction', id, tempData)
          setPursuitMode(0, id)

          if gameplay_traffic.showMessages and be:getPlayerVehicleID(0) == id then
            ui_message('ui.traffic.policeEvade', 5, 'traffic', 'traffic')
          end
        end

        if pursuit.mode == 3 then
          -- roadblock logic
          if vars.roadblockFrequency > 0 and pursuit.timers.roadblock == 0 then
            local vehIds = {}
            local count = 0
            local spawnData

            if not pursuit.roadblockPos or (pursuit.roadblockPos and veh.pos:squaredDistance(pursuit.roadblockPos) > 400) then
              for otherId, otherVeh in pairs(policeVehs) do -- first, check for police vehicles that are out of sight
                if be:getObjectByID(otherId):getActive() and otherVeh.role.validTargets[id] and otherVeh.role.validTargets[id].dist > 10000
                and otherVeh.pos:squaredDistance(getCameraPosition()) > 10000 and otherVeh.respawn.sightDirValue < 100 then
                  table.insert(vehIds, otherId)
                end
                count = count + 1
              end
            end

            if vehIds[min(2, count)] then -- at least 2 vehicles, or 1 if it is the only one
              spawnData = gameplay_traffic.findSpawnPoint(getCameraPosition(), getCameraForward(), 100, 240, {pathRandom = 0})
              if spawnData then
                local rbWidth = spawnData.radius * 2 + 1 -- plus a small margin
                local newVehIds, totalLength = checkRoadblock(vehIds, rbWidth) -- returns vehicles that can fit in the roadblock
                local maxPropLength = 0
                local newPropIds

                if policePropIds[1] then
                  for i = #policePropIds, 1, -1 do -- validation
                    if not be:getObjectByID(policePropIds[i]) then
                      removeProp(policePropIds[i])
                    end
                  end

                  newPropIds = checkRoadblock(policePropIds, rbWidth, false)
                  for _, v in ipairs(newPropIds) do
                    maxPropLength = max(maxPropLength, be:getObjectByID(v).initialNodePosBB:getExtents().y)
                  end
                end

                local tempData = deepcopy(pursuit)
                tempData.type = 'roadblock'
                tempData.targetPos = spawnData.pos
                extensions.hook('onPursuitAction', id, tempData)

                pursuit.roadblockPos = vec3(spawnData.pos)
                pursuit.roadblockNear = false

                for _, vid in ipairs(newVehIds) do -- prevents the vehicles from respawning too quickly
                  local vehData = policeVehs[vid]
                  if vehData.state == 'fadeIn' or vehData.state == 'fadeOut' then
                    be:getObjectByID(vid):setMeshAlpha(1, '')
                    vehData.alpha = 1
                    vehData.state = 'active'
                  end
                  vehData:modifyRespawnValues(500)
                  vehData.role:setAction('roadblock')
                end

                local angle = 0 -- guessed angles
                if rbWidth - totalLength > 2 then
                  angle = random(-20, 20)
                elseif rbWidth - totalLength < 1 then
                  angle = random(30, 50) * sign2(random() - 0.5)
                else
                  angle = random(-5, 5)
                end

                placeRoadblock(newVehIds, spawnData.pos, quatFromDir(spawnData.rot, spawnData.normal), {angle = angle, centerAngle = 0, width = rbWidth})
                if newPropIds then
                  placeRoadblock(policePropIds, spawnData.pos - spawnData.rot * (maxPropLength * 0.5 + 2), quatFromDir(spawnData.rot, spawnData.normal), {angle = -90, width = rbWidth})
                end
              end
            end

            if spawnData then -- valid roadblock
              pursuit.timers.roadblock = max(10, 60 - vars.roadblockFrequency * 60) -- time interval to test for the next roadblock
              if count == 1 then
                pursuit.timers.roadblock = pursuit.timers.roadblock + 20
              end
            else
              pursuit.timers.roadblock = 1 -- bounce time until next roadblock check
            end
          end
        end

        if not pursuit.policeAttack or bestDist > square(vars.evadeRadius) then
          pursuit.timers.evade = min(vars.evadeLimit, pursuit.timers.evade + dtSim)
        else
          pursuit.timers.evade = 0
        end
        pursuit.timers.arrest = 0
      end

      if pursuit.mode == 3 and pursuit.timers.evadeValue < 0.5 then
        pursuit.timers.roadblock = max(0, pursuit.timers.roadblock - dtSim)
      else
        pursuit.timers.roadblock = 1
      end

      if not pursuit.roadblockNear and pursuit.roadblockPos and veh.pos:squaredDistance(pursuit.roadblockPos) <= 400 then -- increment roadblock counter
        pursuit.roadblocks = pursuit.roadblocks + 1
        pursuit.roadblockNear = true
      end

      if pursuit.mode >= 1 then
        pursuit.timers.main = pursuit.timers.main + dtSim
      end
    end

    pursuit.timers.arrestValue = pursuit.mode ~= -1 and clamp(pursuit.timers.arrest / max(1e-12, vars.arrestLimit), 0, 1) or 1
    pursuit.timers.evadeValue = clamp(pursuit.timers.evade / max(1e-12, vars.evadeLimit), 0, 1)
  end
end

local function onSerialize()
  return {vars = vars, propIds = policePropIds}
end

local function onDeserialized(data)
  vars = data.vars
  policePropIds = data.propIds
end

-- public interface
M.insertProp = insertProp
M.removeProp = removeProp
M.setPropsActive = setPropsActive
M.checkRoadblock = checkRoadblock
M.placeRoadblock = placeRoadblock
M.setPursuitMode = setPursuitMode
M.setPursuitVars = setPursuitVars
M.setPoliceVars = setPursuitVars
M.setSuspect = setSuspect
M.getPursuitData = getPursuitData
M.getPursuitVars = getPursuitVars
M.getPoliceVars = getPursuitVars
M.getPoliceVehicles = getPoliceVehicles

M.onTrafficAction = onTrafficAction
M.onTrafficVehicleAdded = onTrafficVehicleAdded
M.onTrafficVehicleRemoved = onTrafficVehicleRemoved
M.onTrafficStopped = onTrafficStopped
M.onClientEndMission = onClientEndMission
M.onUpdate = onUpdate
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

return M