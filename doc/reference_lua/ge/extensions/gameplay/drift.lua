local M = {}

local vehId
local resetFlag = false
local stopFlag = false 

local currDriftCoolDown = 0
local currCompleteCoolDown = 0
local currDamagePointsCoolDown = 0
local isDrifting
local currDegAngle

local driftScore = {}
local driftActiveData = nil
local scoreOptions = {}
local driftOptions = {}

local function stop()
  stopFlag = true
end

local function reset()
  driftOptions = {
    allowDrift = true,
    minAngle = 20,
    minVelocity = 4,
    crashDamageThreshold = 150,
    allowDonut = false,
    allowTightDrifts = true,
    totalDriftAngleModulo = true,
    raycastHeight = 0.5,
    raycastDist = 1.8,
    raycastInwardOffset = 0.650,
  }

  scoreOptions = {
    wallDetectionLength = 2,
    multiMinAngle = 2,
    multiMaxAngle = 5,
    driftCoolDownTime = 1.5,
    driftCompleteTime = 2,
    maxCombo = 10,
    maxTightDriftScore = 4500,
    donutScore = 1800,
    damagePointsCoolDown = 1, --when you crash, start counting point after x seconds
  }

  driftScore = {
    cachedScore = 0,
    score = 0,
    combo = 1,
  }

  driftActiveData = nil

  stopFlag = false 
  resetFlag = true
end

--------- GARBAGE COLLECTION VARIABLES -----------
local velDir
local isInTheAir
local wallMulti
local driftAngleScore
local veh
local vehicleData
local currentAngle
local dir
local pos
local hitDist
local hitPos
local dirVec
local radAngle
local corner_FL
local corner_FR 
local corner_BR
local corner_BL
local center
local oobb 
--------------------------------------------------

local function newDriftActiveData(vehicleData)
  driftActiveData = {
    closestWallDistance = 0,
    currDegAngle = 0,
    driftComplete = false,
    startOrientation = velDir,
    lastFrameVelDir = vec3(velDir),
    totalDriftAngle = 0,
    angleVelocity = 0,
    angles = {},
    totalDonutsInRow = 0,
    totalDriftDistance = 0,
    lastPos = vec3(vehicleData.pos),
    totalDriftTime = 0,
    avgDriftAngle = 0,
    driftUniformity = 0,
  }
end

local function resetCacheScore()
  driftScore.cachedScore = 0
  driftScore.combo = 1
end


local function resetDonut()
  if driftActiveData then
    driftActiveData.totalDriftAngle = 0
    driftActiveData.totalDonutsInRow = 0
  end
end


local function throwRaycast(startPosition, direction)
  dir = direction - startPosition
  pos = direction + vec3(0,0, driftOptions.raycastHeight) - dir:normalized() * driftOptions.raycastInwardOffset

  hitDist = castRayStatic(pos, dir, scoreOptions.wallDetectionLength)
  hitPos = pos + dir:normalized() * hitDist
  return hitDist
end


local function calculateDriftAngle(vehData)
  dirVec = vehData.dirVec

  radAngle = math.acos(dirVec:dot(vehData.vel:normalized()) / (dirVec:length() * vehData.vel:normalized():length()))
  currDegAngle = math.deg(radAngle)
end


local function calculateDriftCombo(vehData, dtSim)
  if not driftActiveData.driftComplete then
    currCompleteCoolDown = currCompleteCoolDown - dtSim
    if currCompleteCoolDown < 0 then
      driftScore.combo = driftScore.combo + 1
      driftActiveData.driftComplete = true
    end
  end
end


local function calculateVehCenterAndWheels(veh)
  oobb = veh:getSpawnWorldOOBB()
  corner_FL = vec3(oobb:getPoint(0))
  corner_FR = vec3(oobb:getPoint(3))
  corner_BR = vec3(oobb:getPoint(7))
  corner_BL = vec3(oobb:getPoint(4))

  center = vec3(
    (corner_FL.x + corner_FR.x + corner_BL.x + corner_BR.x) / 4,
    (corner_FL.y + corner_FR.y + corner_BL.y + corner_BR.y) / 4,
    (corner_FL.z + corner_FR.z + corner_BL.z + corner_BR.z) / 4
  )
end


local function calculateDistWall()
  --[[closest wall--]]
  driftActiveData.closestWallDistance = math.min(
    throwRaycast(center, corner_FL),
    throwRaycast(center, corner_FR),
    throwRaycast(center, corner_BL),
    throwRaycast(center, corner_BR)
  )
end

local minDamageThreshold = 10
local damageAtStart = 0
local damageFlag = false
local lastFrameDamage = 0
local frameDelay = 5
local currFrameDelay = 0
local function manageDamages(vehData)
  local thisFrameDamage = vehData.damage
  --Beginning of a crash
  if thisFrameDamage > (lastFrameDamage + minDamageThreshold) and not damageFlag then
    damageFlag = true
    damageAtStart = thisFrameDamage
  end

  --End of a crash
  if thisFrameDamage == lastFrameDamage and damageFlag then
    currFrameDelay = currFrameDelay + 1
    if currFrameDelay == frameDelay then

      local damageTaken = vehData.damage - damageAtStart
      if damageTaken >= driftOptions.crashDamageThreshold then
        extensions.hook('onDriftCrash')
      else
        extensions.hook('onDriftTap')
      end

      damageFlag = false
      damageAtStart = 0
      currFrameDelay = 0
    end
  end

  lastFrameDamage = vehData.damage
end

local tightDriftZone
local tightFlag = true
local function detectTightDrift(vehicleData)
  if driftOptions.allowTightDrifts and tightDriftZone then
    local inside = containsOBB_point(tightDriftZone.pos, tightDriftZone.x, tightDriftZone.y, tightDriftZone.z, vehicleData.pos)
    if inside then
      if tightFlag then
        local score = math.floor(linearScale(90 - math.abs(90 - driftActiveData.currDegAngle), 0, 90, 0, scoreOptions.maxTightDriftScore))  
        driftScore.cachedScore = driftScore.cachedScore + score
        extensions.hook('onTightDrift', score)
        tightFlag = false
      end
    else
      tightFlag = true
    end
  end
end

local function detectDonut()
  if driftOptions.allowDonut then
    local totalDonuts = math.floor(driftActiveData.totalDriftAngle / 360)

    -- counts donuts and sends impulse every donut done
    if totalDonuts ~= driftActiveData.totalDonutsInRow then
      driftScore.cachedScore = driftScore.cachedScore + scoreOptions.donutScore
      extensions.hook('onDriftDonut', scoreOptions.donutScore)
      driftActiveData.totalDonutsInRow = totalDonuts
    end
  end
end

local function activeDrifting(vehicleData, dtSim)
  velDir = vehicleData.vel:normalized()
  isInTheAir = throwRaycast(center + vec3(0,0,0.5), center + vec3(0,0,-0.5)) > 0.9
  
  isDrifting = 
  not isInTheAir 
  and vehicleData.vel:length() >= driftOptions.minVelocity 
  and currDegAngle >= driftOptions.minAngle 
  and currDegAngle <= 180 - driftOptions.minAngle
  and currDamagePointsCoolDown <= 0

  if isDrifting then
    if not driftActiveData then
      newDriftActiveData(vehicleData)

      currCompleteCoolDown = scoreOptions.driftCompleteTime
    else
      currDriftCoolDown = scoreOptions.driftCoolDownTime

      currentAngle = math.deg(math.acos(velDir:cosAngle(driftActiveData.lastFrameVelDir))) -- angle in deg

      driftActiveData.angleVelocity = currentAngle / dtSim
      driftActiveData.totalDriftAngle = driftActiveData.totalDriftAngle + currentAngle
      driftActiveData.lastFrameVelDir = vec3(velDir)

      detectDonut()
      detectTightDrift(vehicleData)

      -- total drifting distance
      driftActiveData.totalDriftDistance = driftActiveData.totalDriftDistance + (driftActiveData.lastPos - vehicleData.pos):length()
      driftActiveData.lastPos = vec3(vehicleData.pos)

      -- total drift time
      driftActiveData.totalDriftTime = driftActiveData.totalDriftTime + dtSim

      table.insert(driftActiveData.angles, currDegAngle)

      -- avg drift angle
      local sum = 0
      for _, v in ipairs(driftActiveData.angles) do sum = sum + v end
      driftActiveData.avgDriftAngle = sum / #driftActiveData.angles

    end
  else --if just stopped drifting
    if driftActiveData then
      driftActiveData = nil
    end
  end
end


local function driftScoring(dtSim)
  wallMulti = linearScale(driftActiveData.closestWallDistance, scoreOptions.wallDetectionLength, 0, 1, 5)
  driftAngleScore = linearScale(driftActiveData.currDegAngle, driftOptions.minAngle, 180 - driftOptions.minAngle, scoreOptions.multiMinAngle, scoreOptions.multiMaxAngle)

  driftScore.cachedScore = driftScore.cachedScore + driftAngleScore * driftScore.combo * wallMulti * dtSim * 30 --arbitrary value
end


local function driftCoolDown(dtSim)
  if currDriftCoolDown > 0 then
    currDriftCoolDown = currDriftCoolDown - dtSim
    if currDriftCoolDown < 0 and driftScore.cachedScore > 0 then
      extensions.hook('onDriftCompleted', driftScore.cachedScore)
      driftScore.score = driftScore.score + math.floor(driftScore.cachedScore)
      resetCacheScore()
    end
  end
end


local function onUpdate(dtReal, dtSim, dtRaw)
  if not driftOptions.allowDrift then return end
  if not resetFlag then reset() end
  
  if vehId then
    veh = scenetree.findObjectById(vehId)
  else
    veh = be:getPlayerVehicle(0)
  end

  if not veh then return end
  vehId = veh:getId()

  vehicleData = map.objects[vehId]
  if not vehicleData then return end

  calculateVehCenterAndWheels(veh)
  calculateDriftAngle(vehicleData)
  
  activeDrifting(vehicleData, dtSim)
  manageDamages(vehicleData)
  if isDrifting then
    calculateDistWall()
    calculateDriftCombo(vehicleData, dtSim)
    driftScoring(dtSim)

    driftActiveData.currDegAngle = currDegAngle
  else
    driftCoolDown(dtSim)
  end

  if currDamagePointsCoolDown > 0 then
    currDamagePointsCoolDown = currDamagePointsCoolDown - dtSim
  end
end

local function onDriftCrash()
  resetCacheScore()
  currDamagePointsCoolDown = scoreOptions.damagePointsCoolDown
end

local function getScore()
  return driftScore
end

local function getActiveDriftData()
  return driftActiveData
end

local function getDriftOptions()
  return {
    driftCoolDownTime = scoreOptions.driftCoolDownTime,
    maxCombo = scoreOptions.maxCombo,
    allowDonut = driftOptions.allowDonut,
    allowTightDrifts = driftOptions.allowTightDrifts,
    raycastDist = driftOptions.raycastDist
  }
end

local function setAllowDonut(value)
  driftOptions.allowDonut = value
end

local function setAllowTightDrift(value)
  driftOptions.allowTightDrifts = value
end

local function setAllowDrift(value)
  driftOptions.allowDrift = value
end

local function setVehId(newVehId)
  vehId = newVehId
end

local function setTightDriftZone(newZone)
  tightDriftZone = newZone
end

local function getVehId()
  return vehId
end

M.onDriftTap = onDriftTap
M.onDriftCrash = onDriftCrash
M.onDriftDonut = onDriftDonut
M.onDriftCompleted = onDriftCompleted

M.onUpdate = onUpdate

M.resetDonut = resetDonut
M.reset = reset
M.stop = stop

M.getScore = getScore
M.getActiveDriftData = getActiveDriftData
M.getDriftOptions = getDriftOptions
M.getVehId = getVehId

M.setDriftOptions = setDriftOptions
M.setVehId = setVehId
M.setTightDriftZone = setTightDriftZone
M.setAllowDrift = setAllowDrift
M.setAllowTightDrift = setAllowTightDrift
M.setAllowDonut = setAllowDonut
return M