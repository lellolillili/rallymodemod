-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

--Spawn point offset
--positive X is toward left of the screen, positive Y is toward the bottom of the screen
local X, Y, Z = 2000, 2000, 100
local containers = {}
local camRot
local camPos
local plPos
local pl
local diffPos
local zoneRight, zoneLeft = 8.5, -8.5
local propDespawn, bottom, top, right, left, spawnLine = 11, 3, -42, 10, -10, -48
local score = 0
local coins = 0 --coins are used to unlock repair buff
local repairBuffCost = 4
local totalBonusScore = 0
local lanesPos = {
  7.565 + X,
  4.679 + X,
  1.900 + X,
  -1.147 + X,
  -4.574 + X
}
local props = {}
local buffs = {}
local propsInfo = {} --This is where corrected rotations, offsets, decals drawn etc will be stored, for each prop
local propPool
local activeProps = {}
local inactiveProps = {}

local arrowDecalPath = "art/vizhelper/arrow.png"

local green = {0.35, 1, 0.4, 1}
local orange = {1, 0.57, 0.2, 1}
local red = {1, 0.2, 0.2, 1}
local transparent = {0, 0, 0 ,0}

--Score stuff
local ballFirstPos --Used to calculate points when pushing the ball
local ballPoint = 0.07 --Every meter pushed
local ballDistThreshold = 3-- After that much moved, the points will be counted
local rampJumpPoints = 5
local gateCrushedPoints = 3

local cannonProp
local ballProp
local lilRocksProp

C.name = 'ARunForLife'
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.description = "Plays my little scenario"
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'flow', impulse = true, name = 'reset', description = "New game"},
  { dir = 'in', type = 'number', name = 'plId', description = "The player ID"},

  { dir = 'in', type = 'number', name = 'minPropLine', description = "The minimum amount of prop that will be spawned on a horizontal line"},
  { dir = 'in', type = 'number', name = 'maxPropLine', description = "The maximum amount of prop that will be spawned on a horizontal line"},
  { dir = 'in', type = 'number', name = 'baseTimeToNextLine', description = "The average time it will take for another line to be spawned"},
  { dir = 'in', type = 'number', name = 'lineSpawnRandom', description = "The baseTimeToNextLine will be randomized +/- (lineSpawnRandom * 100) %"},
  { dir = 'in', type = 'number', name = 'spawnLine', description = "How far is the spawn line for the props"},
  { dir = 'in', type = 'number', name = 'despawnLine', description = "How much behind is the line to despawn props"},
  { dir = 'in', type = 'number', name = 'startCamSpeed', description = "After the initial acceleration, how fast the camera will go"},
  { dir = 'in', type = 'number', name = 'camNaturalAccel', description = "After the initial acceleration, how fast the camera will accelerate"},
  { dir = 'in', type = 'number', name = 'maxCamSpeed', description = "The maximum speed the camera can go"},
  { dir = 'in', type = 'number', name = 'gatePoints', description = "Points given when crashing through the gate prop"},
  { dir = 'in', type = 'number', name = 'ballPoint', description = "Points given for every meter the ball is pushed"},
  { dir = 'in', type = 'number', name = 'jumpPoints', description = "Points given for jumping over the metal ramp"},
  { dir = 'in', type = 'number', name = 'coinTime', description = "How fast a coin will re appear"},
  { dir = 'in', type = 'number', name = 'repairBuffCost', description = "How many coins to unlock the repair buff"},

  { dir = 'in', type = 'number', name = 'bronze', description = ""},
  { dir = 'in', type = 'number', name = 'silver', description = ""},
  { dir = 'in', type = 'number', name = 'gold', description = ""},

  { dir = 'in', type = 'number', name = 'cont1id', description = "A container ID"},
  { dir = 'in', type = 'number', name = 'cont2id', description = "A container ID"},
  { dir = 'in', type = 'number', name = 'cont3id', description = "A container ID"},
  { dir = 'in', type = 'number', name = 'cont4id', description = "A container ID"},
  { dir = 'in', type = 'number', name = 'cont5id', description = "A container ID"},
  { dir = 'in', type = 'number', name = 'cont6id', description = "A container ID"},
  { dir = 'in', type = 'number', name = 'cont7id', description = "A container ID"},
  { dir = 'in', type = 'number', name = 'cont8id', description = "A container ID"},
  { dir = 'in', type = 'number', name = 'cont9id', description = "A container ID"},
  { dir = 'in', type = 'number', name = 'cont10id', description = "A container ID"},
  { dir = 'in', type = 'table', name = 'pool', description = "The pool containing every prop"},

  { dir = 'in', type = 'flow', impulse = true, name = 'cannon', description = "When the player enters the cannon range"},
  { dir = 'in', type = 'flow', impulse = true, name = 'jumpRamp', description = "When the player has jumped over the ramp"},
  { dir = 'in', type = 'flow', impulse = true, name = 'crashGate', description = "When the player has crashed through gate"},
  { dir = 'in', type = 'flow', impulse = true, name = 'coinTrigger', description = "When the player has entered the coin trigger"},
  { dir = 'in', type = 'flow', impulse = true, name = 'repairTrigger', description = "When the player has entered the repair trigger"},

  { dir = 'out', type = 'number', name = 'score', description = "The current score"},
  { dir = 'out', type = 'number', name = 'totalBonusScore', description = "The total amount of points earned via jumps/ball etc"},
  { dir = 'out', type = 'number', name = 'timeLeftToLose', description = "Time left to lose"},
  { dir = 'out', type = 'number', name = 'camSpeed', description = "The camera speed"},
  { dir = 'out', type = 'number', name = 'ballPoints', description = "Points for pushing the ball"},
  { dir = 'out', type = 'number', name = 'repairBuffCost', description = "Coins needed to spawn a repair buff"},

  { dir = 'out', type = 'vec3', name = 'rampPos', description = "Ramp position for trigger"},
  { dir = 'out', type = 'vec3', name = 'gatePos', description = "Gate position for trigger"},
  { dir = 'out', type = 'vec3', name = 'cannonPos', description = "Cannon position for triggering fire"},
  { dir = 'out', type = 'vec3', name = 'repairTriggerPos', description = "Trigger position for the repair buff"},
  { dir = 'out', type = 'vec3', name = 'coinTriggerPos', description = "Trigger position for the coin buff"},
  { dir = 'out', type = 'number', name = 'jumpPoints', description = "The amount of point for jumping"},
  { dir = 'out', type = 'number', name = 'gatePoints', description = "The amount of point for gate"},
  { dir = 'out', type = 'number', name = 'coins', description = "The amount of coins"},
  { dir = 'out', type = 'number', name = 'nextScore', description = ""},
  { dir = 'out', type = 'string', name = 'currMedal', description = ""},

  { dir = 'out', type = 'flow', name = 'repairSpawned', impulse = true, description = "Emits signal when a repair buff is spawned" },
  { dir = 'out', type = 'flow', name = 'coinEarnt', impulse = true, description = "Emits signal when a coin is earnt" },
  { dir = 'out', type = 'flow', name = 'lost', impulse = true, description = "Emits signal when lost." },
  { dir = 'out', type = 'flow', name = 'repaired', impulse = true, description = "Emits signal when the vehicle is repaired from the repair buff" },
  { dir = 'out', type = 'flow', name = 'drawCannon', description = "" },

}

C.tags = {'util', 'draw'}

function C:init(mgr, ...)
end

--Because every props rotation are different, because some props are special, here i'm defining some of the "corrected properties"
--or why they're special
function C:linkProps()
  props = propPool:getVehs();

  local veh
  local id
  for i = 1, #props do
    id = props[i]
    veh = scenetree.findObjectById(id)
    local flag = false
    if veh.jbeam == "metal_ramp" then
      flag = true
      propsInfo[id] = {
        decal = {
          draw = true,
          path = arrowDecalPath,
          yOffset = 13,
          xOffset = 1.4,
          color = green
        }
      }
    elseif veh.jbeam == "gate" then
      flag = true
      propsInfo[id] = {
        decal = {
          draw = true,
          path = arrowDecalPath,
          yOffset = 3,
          xOffset = 1.4,
          color = green
        }
      }
    elseif veh.jbeam == "ball" then
      flag = true
      ballProp = veh
      propsInfo[id] = {
        decal = {
          draw = true,
          path = arrowDecalPath,
          yOffset = 3,
          xOffset = 0,
          color = green
        }
      }
    elseif veh.jbeam == "cannon" then
      flag = true
      cannonProp = veh
      propsInfo[id] = {
        correctedRot = {0,0,0},
        decal = {
          draw = true,
        }
      }
    elseif veh.jbeam == "caravan" then
      flag = true
      lilRocksProp = veh
      propsInfo[id] = {
        correctedRot = {0,0,math.pi/180*90},
      }
    elseif veh.jbeam == "woodcrate" or veh.jbeam == "woodplanks" or veh.jbeam == "haybale" then
      flag = true
      propsInfo[id] = {
        correctedRot = {0,0,math.pi/180*90},
      }
    end
    if flag then
      tableMerge(propsInfo[id], {id = id, name = veh.jbeam})
    end

    pl = scenetree.findObjectById(self.pinIn.plId.value)
  end
end

local contTpDist
function C:linkContainers()
  if self.pinIn.cont1id.value then table.insert(containers, self.pinIn.cont1id.value) end
  if self.pinIn.cont2id.value then table.insert(containers, self.pinIn.cont2id.value) end
  if self.pinIn.cont3id.value then table.insert(containers, self.pinIn.cont3id.value) end
  if self.pinIn.cont4id.value then table.insert(containers, self.pinIn.cont4id.value) end
  if self.pinIn.cont5id.value then table.insert(containers, self.pinIn.cont5id.value) end
  if self.pinIn.cont6id.value then table.insert(containers, self.pinIn.cont6id.value) end
  if self.pinIn.cont7id.value then table.insert(containers, self.pinIn.cont7id.value) end
  if self.pinIn.cont8id.value then table.insert(containers, self.pinIn.cont8id.value) end
  if self.pinIn.cont9id.value then table.insert(containers, self.pinIn.cont9id.value) end
  if self.pinIn.cont10id.value then table.insert(containers, self.pinIn.cont10id.value) end
  contTpDist = #containers / 2 * 13.25
end

--At the beginning of the game, the camera speeds up at startCamAccel until reaching the speed of startCamSpeed
--Then once reaching startCamSpeed, the camera will keep on accelerating at afterCamAccel
local startCamAccel = 3
local pipckupSpeed = 1.8
local slowDownSpeed = 5
local afterCamAccel = 0.05
local startCamSpeed = 2
local maxCamSpeed = 20
local currCamSpeed = 0
local currMaxCamSpeed = 0
local slowdownCar = false
local catchUp = false
function C:moveCamera()
  if slowdownCar then
    catchUp = true
    local temp = currCamSpeed - (currMaxCamSpeed / slowDownSpeed) * self.mgr.dtSim * 3
    if temp > 0 then
      currCamSpeed = temp
    end
  else
    if catchUp then
      if currCamSpeed < currMaxCamSpeed then
        currCamSpeed = currCamSpeed + pipckupSpeed * self.mgr.dtSim
      else
        catchUp = false
      end
    else
      if currCamSpeed < startCamSpeed then
        currCamSpeed = currCamSpeed + startCamAccel * self.mgr.dtSim
      elseif currCamSpeed < maxCamSpeed then
        currCamSpeed = currCamSpeed + afterCamAccel * self.mgr.dtSim
      end
      currMaxCamSpeed = currCamSpeed
    end
  end

  setCameraPosRot(
   camPos.x, camPos.y - currCamSpeed * self.mgr.dtSim, camPos.z,
   camRot.x, camRot.y, camRot.z, camRot.w)

  self.pinOut.camSpeed.value = currCamSpeed
end

function C:tpContainers()
  local vehPos
  local i = 0
  for _, id in pairs(containers) do
    local veh = scenetree.findObjectById(id)
    if not veh then return end
    vehPos = veh:getPosition()
    if vehPos.y - camPos.y > bottom then
      veh:setPosRot(((i % 2 == 0) and right + X) or left + X, vehPos.y - contTpDist, Z, 0, 0, 0, 0)
    end
     i = i + 1
  end
end

function C:doScore()
  score = score + linearScale(diffPos.y, bottom, top, 1, 3) * currCamSpeed * self.mgr.dtSim * 0.1
  self.pinOut.score.value = score
end

local timeToLose = 5
local currTimeToLose = 0
function C:checkLose()
  if diffPos.x > zoneRight or diffPos.x < zoneLeft or diffPos.y > bottom or diffPos.y < top then
    currTimeToLose = currTimeToLose + self.mgr.dtSim
    self.pinOut.timeLeftToLose.value = timeToLose - currTimeToLose
    if currTimeToLose > timeToLose then
      self.pinOut.lost.value = true
    end
  elseif self.pinOut.timeLeftToLose.value ~= -1 then
    currTimeToLose = 0
    self.pinOut.timeLeftToLose.value = -1
  end
end

local lastBallPos
local totalBallDist = 0 -- that is used to know the total distance travelled by the ball and not just the distance from its origin
local lastBallPoints = 0
local ballPropInfo
local pos
local dist
function C:pushBall()
  if ballProp:getActive() then
    if not ballPropInfo then
      ballPropInfo = self:getPropByName("ball")
    end
    pos = ballProp:getPosition()
    dist = pos:distance(ballFirstPos)
    if dist > ballDistThreshold then
      ballPropInfo.decal.draw = false
      totalBallDist = totalBallDist + lastBallPos:distance(pos)
      local currScore = math.ceil(totalBallDist * ballPoint)
      self.pinOut.ballPoints.value = currScore
      score = score + (currScore - lastBallPoints)
      totalBonusScore = totalBonusScore + (currScore - lastBallPoints)
      lastBallPoints = currScore
    end
    lastBallPos = pos
  end
end

local repairAvailable = false
local coinAvailable = false
function C:checkBuffAvailabilty()
  repairAvailable = false
  coinAvailable = false
  for id, t in pairs(buffs) do
    if t.available then
      if t.name == "repair" then
        repairAvailable = true
      elseif t.name == "coin" and coins < repairBuffCost then
        coinAvailable = true
      end
    end
  end
end

function C:doBuffsTime()
  for id, t in pairs(buffs) do
    if t.useTime then --make sure the current buff actually uses timers
      if not t.onScreen and not t.available then
        t.currTime = t.currTime + self.mgr.dtSim
        if t.currTime > t.time then
          t.available = true
        end
      else
        t.available = false
      end
    end
  end
end

function C:checkCoinForRepair()
  if coins >= repairBuffCost then
    coins = coins - repairBuffCost
    self:getBuffByName("repair").available = true
    self.pinOut.repairSpawned.value = true
  end
end

function C:deactivateBuff(buff)
  buff.onScreen = false
  buff.available = false
  buff.currTime = 0
  buff.pos = {-1,0,0} --used -1 only so it's not 0,0,0 and not ignore by the FG
  if buff.name == "repair" then
    self.pinOut.repairTriggerPos.value = {-1,0,0}
  elseif buff.name == "coin" then
    self.pinOut.coinTriggerPos.value = {-1,0,0}
  end
end

local buffTimeRandom = 0.25
function C:getBuffNextTime(baseTime)
  return math.random(baseTime * ( 1 - buffTimeRandom), baseTime * ( 1 + buffTimeRandom))
end

function C:activateBuff(buff, pos)
  buff.onScreen = true
  buff.available = false
  if buff.useTime then
    buff.time = self:getBuffNextTime(buff.baseTime)
  end
  buff.pos = {pos.x,pos.y,pos.z}
  if buff.name == "repair" then
    self.pinOut.repairTriggerPos.value = {pos.x,pos.y,pos.z}
  elseif buff.name == "coin" then
    self.pinOut.coinTriggerPos.value = {pos.x,pos.y,pos.z}
  end
  self:checkBuffAvailabilty()
end

function C:deactivateProp(propName)
  local temp = self:getPropByName(propName)
  if temp and temp.decal then
    temp.decal.draw = true
  end
end

--Will deactivate props that are out of the camera
function C:deactivatePropsAndBuffs()
  for i = 1, #props do
    local prop = scenetree.findObjectById(props[i])
    if prop and prop:getActive() and prop:getPosition().y - camPos.y > propDespawn then

      if prop.jbeam == "ball" then
        totalBallDist = 0
        self.pinOut.ballPoints.value = -1
        lastBallPoints = 0
      end

      propPool:setVeh(props[i], false)
      self:deactivateProp(prop.jbeam)
      table.insert(inactiveProps, props[i])
      table.remove(activeProps, tableFindKey(activeProps, props[i]))
    end
  end

  for id, t in pairs(buffs) do
    if t.onScreen and t.pos[2] - camPos.y > propDespawn then
      self:deactivateBuff(t)
    end
  end
end

function C:getBuffByName(name)
  for id, t in pairs(buffs) do
    if t.name == name then
      return t
    end
  end
end

function C:getPropByName(name)
  for id, t in pairs(propsInfo) do
    if t.name == name then
      return t
    end
  end
end

local baseTimeToNext = 4 --will be randomized by timeRandom
local randomTimeToNextLine = baseTimeToNext
local timeRandom = 0.7
local currTime = 0
local maxPropLine = 5
local minPropLine = 3

local isPlacing = false
local currIndex = 0
local willPlace = 0
local listLaneDone
local actualPos
local buff
local veh
function C:activatePropsAndBuffs()
  currTime = currTime + self.mgr.dtSim
  if currTime > randomTimeToNextLine and not isPlacing then
    willPlace = math.min(#inactiveProps, #lanesPos, math.random(minPropLine, maxPropLine))
    if willPlace > 0 then
      isPlacing = true
      -- to make sure we don't spawn twice in the same lane
      listLaneDone = deepcopy(lanesPos)
    end
  end


  if repairAvailable then
    buff = self:getBuffByName("repair")
    actualPos = vec3(lanesPos[buff.lane],  camPos.y + spawnLine, Z)
    self:activateBuff(buff, actualPos)
    randomTimeToNextLine = buff.deadZoneTime
    return
  end

  --can't use a for loop, or the props will sometimes overlap despite the safeTeleport, need a frame delay
  if isPlacing then
    local randomLanePos = listLaneDone[math.random(1, #listLaneDone)]

    if coinAvailable then
      actualPos = vec3(randomLanePos,  camPos.y + spawnLine, Z)
      self:activateBuff(self:getBuffByName("coin"), actualPos)
    else
      local randomPropId = inactiveProps[math.random(1, #inactiveProps)]

      veh = scenetree.findObjectById(randomPropId)
      propPool:setVeh(randomPropId, true)

      table.insert(activeProps, randomPropId)
      table.remove(inactiveProps, tableFindKey(inactiveProps, randomPropId))

      --compensate for prop origin
      local oobb = veh:getSpawnWorldOOBB()
      local oobbCenter = (vec3(oobb:getPoint(0)) + vec3(oobb:getPoint(3)) + vec3(oobb:getPoint(7)) + vec3(oobb:getPoint(4))) / 4
      local diff = oobbCenter - veh:getPosition()
      actualPos = vec3(randomLanePos,  camPos.y + spawnLine, Z) - diff

      local rot = quat(0,0,0,0)
      if propsInfo[randomPropId] then
        local newRot = propsInfo[randomPropId].correctedRot
        if newRot then rot = quatFromEuler(unpack(newRot)) end
      end

      spawn.safeTeleport(veh, vec3(actualPos), rot)

      --Do something when props are initiated
      if veh.jbeam == "ball" then
        ballFirstPos = veh:getPosition()
      end
    end
    currIndex = currIndex + 1

    if currIndex >= willPlace then
      currTime = 0
      randomTimeToNextLine = math.random(baseTimeToNext * (1 - timeRandom), baseTimeToNext * (1 + timeRandom))
      isPlacing = false
      currIndex = 0
    end

    table.remove(listLaneDone, tableFindKey(listLaneDone, randomLanePos))
  end
end

--it's a hack, didn't want to deal with a frame delay
local pos
function C:moveTriggers()
  for i = 1, #props do
    veh = scenetree.findObjectById(props[i])
    pos = veh:getPosition()
    if veh and veh:getActive() then
      if veh.jbeam == "gate" then
        self.pinOut.gatePos.value = {pos.x, pos.y, pos.z}
      elseif veh.jbeam == "metal_ramp" then
        self.pinOut.rampPos.value = {pos.x, pos.y, pos.z}
      elseif veh.jbeam == "cannon" then
        self.pinOut.cannonPos.value = {pos.x, pos.y, pos.z}
      end
    end
  end
end

local zero = {0,0,0}

function C:updateValues()
  self.pinOut.ballPoints.value = -1
  self.pinOut.repairTriggerPos.value = zero
  self.pinOut.coinTriggerPos.value = zero
  self.pinOut.rampPos.value = zero
  self.pinOut.gatePos.value = zero
  self.pinOut.cannonPos.value = zero
  self.pinOut.repaired.value = false
  self.pinOut.repairBuffCost.value = repairBuffCost
  self.pinOut.coinEarnt.value = false
  self.pinOut.repairSpawned.value = false

  camRot = getCameraQuat()
  camPos = getCameraPosition()

  if not pl then return end
  plPos = pl:getPosition()
  diffPos = plPos - camPos

  self.pinOut.jumpPoints.value = rampJumpPoints
  self.pinOut.gatePoints.value = gateCrushedPoints
  self.pinOut.totalBonusScore.value = totalBonusScore
  self.pinOut.coins.value = coins
end

function C:setReferences()
  propPool = self.pinIn.pool.value
  self:linkContainers()
  self:linkProps()

  --Update active and inactive prop list
  for i = 1, #props do
    local pl = scenetree.findObjectById(props[i])
    if pl then
      if pl:getActive() then
        table.insert(activeProps, props[i])
      else
        table.insert(inactiveProps, props[i])
      end
    end
  end
end

local function getNewData()
  -- create decals
  return {
    texture = 'art/shapes/arrows/t_arrow_opaque_d.color.png',
    position = vec3(0, 0, 0),
    forwardVec = vec3(0, 0, 0),
    color = ColorF(1, 0, 0, 1 ),
    scale = vec3(1, 1, 4),
    fadeStart = 100,
    fadeEnd = 150,
  }
end

local decals = {}
function C:increaseDecalPool(amount)
  for i = 1, amount do
    table.insert(decals, getNewData())
  end
end

function C:createDecalPool()
  local i = 0
  for id, t in pairs(propsInfo) do
    if t.decal then
      i = i + 1
    end
  end
  self:increaseDecalPool(i + 1)--the + 1 here is for when the player falls behind the camera, an arrow will show where the player is so one has better chance of making it back within view
end

local forwardVec = vec3(0, -1, 0)
local anotherForwardVec = vec3(0, 1, 0)
local scaleVec = vec3(7, 8, 5)
local anotherScaleVec = vec3(10, 12, 5)
local drawPos
local color
local propPos
--Draw arrows and crosses
function C:drawDecals()
  local o = 0
  local data

  for id, t in pairs(propsInfo) do
    if t.decal then
      local prop = scenetree.findObjectById(t.id)

      if prop then
        if prop:getActive() and t.decal.draw and prop.jbeam ~= "cannon" then

          data = decals[o + 1]

          propPos = prop:getPosition()

          drawPos = vec3(propPos.x + t.decal.xOffset, propPos.y + t.decal.yOffset, Z)
          color = t.decal.color

          data.color = ColorF(unpack(color))
          data.position = drawPos
          data.forwardVec = forwardVec
          data.texture = t.decal.path
          data.scale = scaleVec

          o = o + 1
        else
          table.insert(decals, #decals, table.remove(decals, i))
        end
      end
    end
  end

  -- if the player falls out of the camera, draw arrow
  if diffPos.y > bottom then
    data = decals[o + 1]
    data.color = ColorF(unpack(red))
    data.position = vec3(plPos.x, camPos.y, Z)
    data.forwardVec = anotherForwardVec
    data.texture = arrowDecalPath
    data.scale = anotherScaleVec
    o = o + 1
  end

  Engine.Render.DynamicDecalMgr.addDecals(decals, o)
end

function C:slowDownCar()
  if slowdownCar then
    local vehicleData = map.objects[pl:getId()]
    if vehicleData then
      if vehicleData.vel:length() < 0.1 then
        self.pinOut.repaired.value = true
        slowdownCar = false
        core_vehicleBridge.executeAction(pl,'setFreeze', false)
      end
    end
  end
end

function C:repairBuff()
  core_vehicleBridge.executeAction(pl,'setFreeze', true)
  self:deactivateBuff(self:getBuffByName("repair"))
  slowdownCar = true
end

function C:coinBuff()
  coins = coins + 1
  self:deactivateBuff(self:getBuffByName("coin"))
  if coins < repairBuffCost then --otherwise two flash messages gets displayed at the same time
    self.pinOut.coinEarnt.value = true
  end
end

--Check the different triggers (jump, gate, buffs)
function C:checkTriggers()
  --Firing cannon
  if self.pinIn.cannon.value then
    cannonProp:queueLuaCommand("custom_input.fire(1)")
    self:getPropByName("cannon").decal.draw = false
  end

  --Jumping over the ramp
  if self.pinIn.jumpRamp.value then
    score = score + rampJumpPoints
    totalBonusScore = totalBonusScore + rampJumpPoints
    self:getPropByName("metal_ramp").decal.draw = false
  end

  --Crashing through the gate
  if self.pinIn.crashGate.value then
    score = score + gateCrushedPoints
    totalBonusScore = totalBonusScore + gateCrushedPoints
    self:getPropByName("gate").decal.draw = false
  end

  --Repairs
  if self.pinIn.repairTrigger.value then
    self:repairBuff()
  end

  if self.pinIn.coinTrigger.value then
    self:coinBuff()
  end
end

function C:calcMedal()
  if score >= self.pinIn.gold.value then
    self.pinOut.nextScore.value = self.pinIn.gold.value
    self.pinOut.currMedal.value = "Gold"
  elseif score >= self.pinIn.silver.value then
    self.pinOut.nextScore.value = self.pinIn.gold.value
    self.pinOut.currMedal.value = "Silver"
  elseif score >= self.pinIn.bronze.value then
    self.pinOut.nextScore.value = self.pinIn.silver.value
    self.pinOut.currMedal.value = "Bronze"
  else
    self.pinOut.nextScore.value = self.pinIn.bronze.value
    self.pinOut.currMedal.value = "Wood"
  end
end

local once = false
function C:resetValues()
  currCamSpeed = 0
  score = 0
  activeProps = {}
  inactiveProps = {}
  once = false
  decals = {}
  totalBonusScore = 0
  propsInfo = {}
  slowdownCar = false
  currMaxCamSpeed = 0
  catchUp = false
  ballPropInfo = nil
  isPlacing = false
  currIndex = 0
  coins = 0
  containers = {}
  buffs = {
    {
      name = "repair",
      pos = {0,0,0},
      useTime = false,
      available = false,
      onScreen = false,
      deadZoneTime = 10, -- fox X seconds, no prop will appear after
      lane = 3 -- will always spawn in the middle
    },
    {
      name = "coin",
      useTime = true,
      available = false,
      onScreen = false,
      currTime = 0,
    }
  }
end

function C:setParameters()
  if self.pinIn.minPropLine.value then minPropLine = self.pinIn.minPropLine.value end
  if self.pinIn.maxPropLine.value then maxPropLine = self.pinIn.maxPropLine.value end
  if self.pinIn.baseTimeToNextLine.value then baseTimeToNext = self.pinIn.baseTimeToNextLine.value end
  if self.pinIn.lineSpawnRandom.value then timeRandom = self.pinIn.lineSpawnRandom.value end
  if self.pinIn.spawnLine.value then spawnLine = self.pinIn.spawnLine.value end
  if self.pinIn.despawnLine.value then bottom = self.pinIn.despawnLine.value end
  if self.pinIn.startCamSpeed.value then startCamSpeed = self.pinIn.startCamSpeed.value end
  if self.pinIn.camNaturalAccel.value then afterCamAccel = self.pinIn.camNaturalAccel.value end
  if self.pinIn.maxCamSpeed.value then maxCamSpeed = self.pinIn.maxCamSpeed.value end
  if self.pinIn.gatePoints.value then gateCrushedPoints = self.pinIn.gatePoints.value end
  if self.pinIn.ballPoint.value then ballPoint = self.pinIn.ballPoint.value end
  if self.pinIn.jumpPoints.value then rampJumpPoints = self.pinIn.jumpPoints.value end
  if self.pinIn.coinTime.value then
    local coin = self:getBuffByName("coin")
    coin.baseTime = self.pinIn.coinTime.value
    coin.time = self:getBuffNextTime(coin.baseTime)
  end
  if self.pinIn.repairBuffCost.value then repairBuffCost = self.pinIn.repairBuffCost.value end
end

function C:work()
  if self.pinIn.reset.value then
    self:resetValues()
  end
  if not once then
    self:setParameters()
    self:setReferences()
    self:createDecalPool()
    once = true
  end

  self:updateValues()
  self:tpContainers()
  self:moveCamera()
  self:doScore()
  self:checkLose()
  self:checkTriggers()
  self:deactivatePropsAndBuffs()
  self:activatePropsAndBuffs()
  self:doBuffsTime()
  self:checkBuffAvailabilty()
  self:pushBall()
  self:moveTriggers()
  self:drawDecals()
  self:calcMedal()

  self:checkCoinForRepair()

  self:slowDownCar()
  self.pinOut.drawCannon.value = self:getPropByName("cannon").decal.draw
end

return _flowgraph_createNode(C)