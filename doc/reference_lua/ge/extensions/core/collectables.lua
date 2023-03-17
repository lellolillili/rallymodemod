-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'collectables'

M.state = {}

local itemsDone = {} -- over all levels
local itemsDoneLevel = {}
local itemsDoneLevelCounter = 0
local currentLocation = ''

local itemsTodo = {}
local itemsTodoCounter = 0
local persistencyFilename = ""
local collectionDistance = 2
local disabledMinimapHints = false
local globalCount = 0
local achievement = ''
local collectableName = ''

-- this is heavy on performance
local function findObjects(meshName)
  local sceneObjects = scenetree.findClassObjects('TSStatic')
  local res = {}
  for _, o in ipairs(sceneObjects) do
    o = scenetree.findObject(o)
    if o and o.shapeName:find(meshName) then
      -- Need to get coordinates of each Bonus doll so they can be displayed in UI
      local pos = o:getPosition()
      res[o.name or Prefab.getPrefabByChild(o).name] = {pos.x, pos.y}
    end
  end
  return res
end

local function save()
  jsonWriteFile(persistencyFilename, itemsDone)
end

local function load()
  itemsDone = jsonReadFile(persistencyFilename) or {}

  if not itemsDone[currentLocation] then
    itemsDone[currentLocation] = {}
  end

  itemsDoneLevel = itemsDone[currentLocation]
  itemsDoneLevelCounter = tableSize(itemsDoneLevel)
end

local function createCollectableExtras(obj,configData)
  local soundEventName = configData.sound
  local soundId = Engine.Audio.createSource('AudioDefaultLoop2D', soundEventName)
  if not soundId then log("E",logTag, "cound not load sound") end
  local sound = scenetree.findObjectById(soundId)
  if sound then
    sound:setTransform(obj:getTransform())
    sound:setParameter("distance_vehicle", 10000)
    sound:setVolume(1)
    sound:play(-1)
  end

  local base =  createObject('TSStatic')
  base:setTransform(obj:getTransform())
  base:setField('shapeName', 0, "art/shapes/interface/checkpoint_marker_base.dae")
  base.scale = vec3(2, 2, 2)
  base.useInstanceRenderData = true
  base:setField('instanceColor', 0, configData.instanceColour)
  base:setField('collisionType', 0, "Collision Mesh")
  base:setField('decalType', 0, "Collision Mesh")
  base.canSave = false
  base:registerObject('')

  local particles = createObject('ParticleEmitterNode')
  local explosion_particle = configData.particle
  particles:setTransform(obj:getTransform())
  particles:setPosition(obj:getPosition() + vec3(0, 0, 1.8))
  particles:setField('emitter', 0, explosion_particle)
  particles:setField('dataBlock', 0, 'lightExampleEmitterNodeData1')
  particles:setActive(false)
  particles:registerObject('')

  return { soundId = soundId, baseId = base:getID(), particlesId = particles:getID() }
end

local function informUser()
  local message = nil
  local totalCollecatables = itemsTodoCounter + itemsDoneLevelCounter

  if itemsDoneLevelCounter < totalCollecatables then
    if itemsDoneLevelCounter > 1 then
      message = 'Collected '.. tostring(itemsDoneLevelCounter) ..' '.. collectableName .. 's, ' .. tostring(itemsTodoCounter) .. ' to go!'
    else
      message = 'Collected '.. tostring(itemsDoneLevelCounter) ..' '.. collectableName .. ', ' .. tostring(itemsTodoCounter) .. ' to go!'
    end
  else
    -- new message if all bonus dolls have been collected
    message = 'You have found all the '..collectableName..'s on this map, well done!'
  end

  -- overall check
  local doneGlobal = 0
  for _, v in pairs(itemsDone) do
    doneGlobal = doneGlobal + tableSize(v)
  end
  if achievement and doneGlobal > 0 then
    Steam.advanceAchievement(achievement, doneGlobal, globalCount)
    if doneGlobal >= globalCount then
      message = 'You have found the required number of '..collectableName..'s - Congratulations!'
      Steam.unlockAchievement(achievement)
    end
  end

  ui_message(message, 10, 'bonus_collection', nil)
end

local function sendUIState()
  -- Send bonus doll locations to UI
  local totalCollecatables = itemsTodoCounter + itemsDoneLevelCounter
  guihooks.trigger('CollectablesInit', {collectableItems = itemsTodo, collectableAmount = totalCollecatables, collectableCurrent = itemsDoneLevelCounter})
end

local function collectObject(objName)

  if not itemsTodo[objName] then
    log('E', logTag, 'item not on the TODO list? ' .. tostring(objName))
  end
  scenetree.findObject(objName).hidden = true
  itemsDoneLevel[objName] = 1

  local itemExtras = itemsTodo[objName].extras
  local sound = scenetree.findObjectById(itemExtras.soundId)
  if sound then
    sound:stop(-1)
  end

  local base = scenetree.findObjectById(itemExtras.baseId)
  if base then
    base.hidden = true
  end

  local particles = scenetree.findObjectById(itemExtras.particlesId)

  if particles then
    particles:setActive(true)
  end


  itemsTodo[objName] = nil

  itemsDoneLevelCounter = tableSize(itemsDoneLevel)
  itemsTodoCounter = tableSize(itemsTodo)

  save()

  -- Send collected bonus doll name to UI
  guihooks.trigger('CollectablesUpdate', {collectableName = objName, collectableAmount = itemsDoneLevelCounter})

  informUser()
end

local function onUpdate(dtReal, dtSim, dtRaw)
  if not be then return end
  -- log('I', logTag, "onUpdate called....")

  local freeCam = commands.isFreeCamera()
  if freeCam and not disabledMinimapHints then
    guihooks.trigger('CollectablesInit', {})
    disabledMinimapHints = true
  elseif not freeCam and disabledMinimapHints then
    disabledMinimapHints = false
    sendUIState()
  end

  for o, t in pairs(itemsTodo) do
    if scenetree.findObject(o) then
      local opos = scenetree.findObject(o):getPosition()
      vehicle = vehicle or be:getPlayerVehicle(0)
      if not vehicle then return end
      vpos = vpos or vehicle:getPosition()

      local dist = (opos - vpos):length()

      local sound = scenetree.findObjectById(t.extras.soundId)
      if sound then sound:setParameter("distance_vehicle", dist) end

      if dist < collectionDistance then
        collectObject(o)
        break
      end
    end
  end
end

local function initLogic(configData)
  load()
  -- change freeroam layout when mod is enabled so that nav map is visible by default.
  core_gamestate.setGameState(configData.gameState and configData.gameState or 'scenario', 'collectionEvent')

  -- reset values or else they persist on level change
  itemsTodo = {}
  itemsTodoCounter = 0;
  local meshName = configData.target
  local objects = findObjects(meshName)

  log('D', logTag, ' ** level ' .. tostring(currentLocation) .. ' = ' .. dumps(tableKeys(objects)))
  log('D', logTag, ' ** visited objects: ' .. dumps(tableKeys(itemsDoneLevel)))
  for k, o in pairs(objects) do
    if itemsDoneLevel[k] then
      scenetree.findObject(k).hidden = true
    else
      local obj = scenetree.findObject(k)
      itemsTodo[k] = {o[1], o[2], extras=createCollectableExtras(obj,configData)}
      itemsTodoCounter = itemsTodoCounter + 1
      obj.hidden = false
    end
  end

  log('D', logTag, ' ** todo objects: ' .. dumps(tableKeys(itemsTodo)))
  informUser()

  local navPresent = extensions.ui_apps.isAppOnLayout('navigation', 'scenario')
  if navPresent then log('D', logTag, 'BonusDoll_collection_OK_nav'); return end
  log('D', logTag, 'BonusDoll_collection_no_nav')
  ui_message('You may need to use the Navigation app to find the'..collectableName..'s more easily', 20, 'christmas_collection_no_nav', nil)
end

local function shutdown()
  -- log('I', logTag, 'shutdown called....')

  if M.state.enable then
    -- Destroy all the collectable extras
    for _,item in pairs(itemsTodo) do
      local sound = scenetree.findObjectById(item.extras.soundId)
      if sound then
        sound:stop(-1)
        Engine.Audio.deleteSource(item.extras.soundId)
      end

      local base = scenetree.findObjectById(item.extras.baseId)
      if base then
        base.hidden = true
        base:deleteObject()
      end

      local particles = scenetree.findObjectById(item.extras.particlesId)
      if particles then
          particles:setActive(false)
          particles:deleteObject()
      end
    end
    itemsDone = {}
    itemsDoneLevel = {}
    itemsDoneLevelCounter = 0
    currentLocation = ''
    itemsTodo = {}
    itemsTodoCounter = 0
    persistencyFilename = ""
    disabledMinimapHints = false
    globalCount = 0
    achievement = ''
    collectableName =''

    M.state.enable = false
    M.onUpdate = nop
  end
end

local function setupCollectables(configData)
  local prefabfile = configData and configData.prefab

  if prefabfile and not scenetree.Bonus_Doll and FS:fileExists(prefabfile) then
    local levelPath = getMissionFilename()
    if not levelPath then
      log('E', logTag, "No mission filename specified")
      return
    end
    log('I', logTag, "level loaded: " .. levelPath)
    TorqueScriptLua.exec(configData.dataBlocks)

    local currentLevel = core_levels.getLevelName(levelPath) or ''

    if campaign_campaigns and campaign_campaigns.getCampaignActive() then
      currentLocation = campaign_campaigns.getCurrentLocation()
    elseif scenario_scenarios then
      currentLocation = scenario_scenarios.getscenarioName()
    else
      currentLocation = currentLevel
    end

    local prefab = createObject('Prefab')
    prefab.filename = String(prefabfile)
    prefab.canSave = false
    prefab:setPosition(vec3(0,0,0))
    prefab:registerObject("Bonus_Doll");
    scenetree.MissionGroup:addObject(prefab.obj)
    initLogic(configData)
    M.state.enable = true
    M.onUpdate = onUpdate
  else
    log('D', logTag, "Level does not have collectables - "..tostring(prefabfile))
    shutdown()
  end
end

local function initialise(configData)
  if configData then
    persistencyFilename = configData.filename
    achievement = configData.prize
    globalCount = configData.count
    collectableName = configData.doll
    setupCollectables(configData)
  else
    log("D", logTag, "No collectables defined. Disabling logic")
    shutdown()
  end
end

local function onClientEndMission(levelPath)
  -- log("D", logTag, "onClientEndMission called.....")
  shutdown()
end

M.onUpdate              = onUpdate
M.sendUIState           = sendUIState
M.initialise            = initialise
M.onClientEndMission    = onClientEndMission

-- cheats :D
M.collectObject = collectObject

return M

-- extensions['scripts/christmas/minigame'].collectObject('s_is_1')
