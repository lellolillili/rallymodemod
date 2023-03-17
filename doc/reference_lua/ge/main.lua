-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

--- you can use this to turn of Just In Time compilation for debugging purposes:
--jit.off()
jit.opt.start('minstitch=10000000')

vmType = 'game'

package.path = 'lua/ge/?.lua;lua/gui/?.lua;lua/common/?.lua;lua/common/libs/?/init.lua;lua/common/libs/luasocket/?.lua;lua/?.lua;core/scripts/?.lua;scripts/?.lua;?.lua'
package.cpath = ''
require('luaCore')

require_optional('replayInterpolation')

local traceLongLogs = false
log = function(a, b, c, ...)
  Lua:log(a, b, c, ...)
  if traceLongLogs and (
    (type(a) == "string" and string.len(a) > 1000) or
    (type(b) == "string" and string.len(b) > 1000) or
    (type(c) == "string" and string.len(c) > 1000) ) then
    log("W", b, "The long log message above has been triggered by:")
    print(debug.tracesimple())
  end
end

print = function(...)
  local args = { n = select("#", ...), ... }
  local s_args = {}
  for i = 1, args.n do
    table.insert(s_args, tostring(args[i]))
  end
  log('A', "print", table.concat(s_args, ', '))
  -- if you want to find out, where the print was used:
  -- log('A', "print", debug.traceback())
end
log("I", "", "============== Game Engine Lua VM started ==============")


require('mathlib')
Point3F = vec3
require("utils")
require("devUtils")
require("ge_utils")
require('ge_deprecated')
require("luaProfiler")
local STP = require "libs/StackTracePlus/StackTracePlus"
debug.traceback = STP.stacktrace
debug.tracesimple = STP.stacktraceSimple

json = require("json")
guihooks = require("guihooks")
screenshot = require("screenshot")
bullettime = require("simTimeAuthority")
extensions = require("extensions")
extensions.addModulePath("lua/ge/extensions/")
extensions.addModulePath("lua/common/extensions/")
map = require("map")
settings = extensions.core_settings_settings
perf = require("utils/perf")
spawn = require("spawn")
setSpawnpoint= require ("setSpawnpoint")
serverConnection = require("serverConnection")
server = require("server/server")
commands = require("server/commands")
editor = {}
worldReadyState = -1 -- tracks if the level loading is done yet: 0 = no, 1 = yes, load play ui, 2 = all done

sailingTheHighSeas = the_high_sea_crap_detector()
photoModeOpen = false
levelLoaded = nil

gameConnection = nil -- backward compatibility, not a sceneobject anymore
function getGame() return gameConnection end -- backward compatibility

-- how to log into a json file:
--globalJsonLog = LogSink()
--globalJsonLog:open('/gamelog.json')

--[[
-- function to trace the memory usage
local maxMemUsage = 0
local function trace_mem(event, line)
  local s = debug.getinfo(2)
  local m, _ = gcinfo()
  if m > maxMemUsage then
    maxMemUsage = m
  end
  Lua:log('D', 'luaperf', tostring(event) .. ' = ' .. tostring(s.what) .. '_' .. tostring(s.source) .. ':' .. tostring(s.linedefined) .. ' / memory usage: ' .. tostring(m) .. ' (max: ' .. tostring(maxMemUsage) .. ')')
end
debug.sethook(trace_mem, "c")
--]]


local ffi = require("ffi")

math.randomseed(os.time())
local cmdArgs = Engine.getStartingArgs()

--Lua:enableStackTraceFile("lua.ge.stack.txt", true)

logAlways=print

local _isSafeMode = tableFindKey(cmdArgs, '-safemode')
function isSafeMode()
  return _isSafeMode
end

function convertCStoJson(filenames, newExtSuffix)
  log('I', 'convertCStoJson', 'Conversion started: '..dumps(filenames or {}))

  local persistenceMgr = PersistenceManager()
  persistenceMgr:registerObject('convert_PersistManager')

  for _, fn in pairs(filenames or {}) do
    log('I', 'resaveCSFiles', 'converting ts script: ' .. tostring(fn) )
    -- record known things
    local knownObjects = scenetree.getAllObjects()
    log('I', 'convertCStoJson', 'knownObjects: '..dumps(knownObjects))
    -- convert to map
    local newKnownObjects = {}
    for k, v in pairs(knownObjects) do
      newKnownObjects[v] = 1
    end
    knownObjects = newKnownObjects

    -- load the file
    TorqueScriptLua.exec(fn)

    -- figure out what objects were loaded from that file by diffing with the known objects above
    local knownObjects2 = scenetree.getAllObjects()
    local newObjects = {}
    for _, oName in pairs(knownObjects2) do
      if not knownObjects[oName] then
        local obj = scenetree.findObject(oName)
        log('I', '', ' adding :  ' .. tostring(oName))
        if obj then
          newObjects[oName] = obj
        end
      end
    end
    log('I', 'convertCStoJson', 'newObjects: '..dumps(newObjects))

    for _, obj in pairs(newObjects) do
      log('I', '', ' * ' .. tostring(obj:getClassName()) .. ' - ' .. tostring(obj:getName()) )
      persistenceMgr:setDirty(obj, '')
    end
    persistenceMgr:saveDirtyNewFormat()

    for _, obj in pairs(newObjects) do
      local className = obj:getClassName()
      if not className or (className and className ~= "SimSet" and className ~= "SimGroup") then
        log('I', '', ' *Deleting:  ' .. tostring(className) .. ' - ' .. tostring(obj:getName()) )
        obj:delete()
      end
    end
  end
  persistenceMgr:delete()
  log('I', 'convertCStoJson', 'Conversion all done.')
end

-- immediate command line arguments
-- worked off before anything else
-- called when the world is init'ed
local function handleCommandLineFirstFrame()
  if tableFindKey(cmdArgs, '-flowgraph') then
    if getMissionFilename() == "" then
      freeroam_freeroam.startFreeroam("levels/smallgrid/main.level.json")
      extensions.load('editor_flowgraphEditor')
      editor_flowgraphEditor.requestedEditor = true
      --core_levels.startLevel("levels/smallgrid/main.level.json")
    end
  end

  if tableFindKey(cmdArgs, '-convertCSMaterials') then
    local function resaveCSFiles(pattern, fnSuffix)
      local persistenceMgr = PersistenceManager()
      persistenceMgr:registerObject('matConvert_PersistManager')

      local filenames = FS:findFiles('/', pattern, -1, true, false)
      -- dump(filenames)
      for _, fn in pairs(filenames) do
        log('I', 'resaveCSFiles', 'converting ts script: ' .. tostring(fn) )
        -- record known things
        local knownObjects = scenetree.getAllObjects()
        -- convert to map
        local newKnownObjects = {}
        for k, v in pairs(knownObjects) do
          newKnownObjects[v] = 1
        end
        knownObjects = newKnownObjects

        -- load the file
        TorqueScriptLua.exec(fn)

        -- figure out what objects were loaded from that file by diffing with the known objects above
        local knownObjects2 = scenetree.getAllObjects()
        local newObjects = {}
        for _, oName in pairs(knownObjects2) do
          if not knownObjects[oName] then
            local obj = scenetree.findObject(oName)
            log('I', '', ' adding :  ' .. tostring(oName))
            if obj then
              newObjects[oName] = obj
            end
          end
        end

        for _, obj in pairs(newObjects) do
          log('I', '', ' * ' .. tostring(obj:getClassName()) .. ' - ' .. tostring(obj:getName()) )
          persistenceMgr:setDirty(obj, '')
        end
        persistenceMgr:saveDirtyNewFormat()

        for _, obj in pairs(newObjects) do
          local className = obj:getClassName()
          if not className or (className and className ~= "SimSet" and className ~= "SimGroup") then
            log('I', '', ' *Deleting:  ' .. tostring(className) .. ' - ' .. tostring(obj:getName()) )
            obj:delete()
          end
        end
      end
      persistenceMgr:delete()
    end

    resaveCSFiles('materials.cs', '.materials.json')
    resaveCSFiles('*Data.cs', '.datablock.json')
    log('I', 'convertCSMaterials', 'All done, exiting gracefully.')
    shutdown(0)
  end

  if tableFindKey(cmdArgs, '-deps') then
    extensions.util_dependencyTree.test()
    print('done')
    shutdown(0)
  end

  if tableFindKey(cmdArgs, '-disableDynamicCollision') then
    settings.setValue('disableDynamicCollision', true)
  end
end

local coreModules =  {'ui_audio', 'ui_apps', 'ui_visibility', 'scenario_scenariosLoader', 'campaign_campaignsLoader', 'freeroam_freeroam', 'core_levels',
                        'scenario_quickRaceLoader', 'core_highscores', 'core_replay', 'core_vehicles', 'core_vehicle_colors', 'core_settings_settings', 'core_settings_graphic',
                        'core_jobsystem', 'core_modmanager', 'core_hardwareinfo',
                        'core_commandhandler', 'core_remoteController', 'core_gamestate', 'core_online',
                        'core_paths', 'core_sounds', 'core_audio', 'ui_imgui', 'core_environment', 'core_metrics',
                        'core_inventory', 'core_terrain', 'core_forest', 'editor_main', 'trackbuilder_trackBuilder', 'core_input_actions', 'core_input_bindings', 'core_input_virtualInput', 'core_input_vehicleSwitching',
                        'core_settings_audio', 'core_input_categories', 'core_input_deprecatedActions', 'core_multiseat', 'core_multiseatCamera',
                        'core_quickAccess', 'core_camera', 'core_input_actionFilter', 'core_multiSpawn', 'core_trafficSignals',
                        'ui_flowgraph_editor', 'core_flowgraphManager', 'core_vehicle_manager', 'ui_missionInfo', 'ui_fadeScreen', 'core_vehicleBridge', 'core_gameContext', 'core_vehiclePoolingManager',
                        'gameplay_missions_missionEnter', 'gameplay_missions_missionManager', 'gameplay_missions_startTrigger', 'freeroam_bigMapMode',
                        'freeroam_facilities', 'gameplay_missions_missions', 'gameplay_missions_progress',
                        'gameplay_missions_unlocks', 'gameplay_missions_clustering', 'core_groundMarkers', 'gameplay_garageMode', 'gameplay_city', 'gameplay_traffic',
                        'render_hdr', 'career_saveSystem', 'career_career', 'career_branches', 'gameplay_traffic'
                    }

local sharedModules = { 'core_weather', 'core_trailerRespawn', 'util_richPresence', 'core_checkpoints', 'core_collectables', 'gameplay_walk' }

local extraUserRequestedExtensions = {}

function loadCoreExtensions()
  extensions.load(coreModules)
end

function loadGameModeModules(...)
  extensions.unloadExcept(coreModules)
  extensions.load(sharedModules, extraUserRequestedExtensions, ...)
  extraUserRequestedExtensions = {}
  extensions.hookExcept(coreModules, 'onInit')
end

function unloadGameModules()
  extensions.unloadExcept(coreModules)
end

function registerCoreModule(modulePath)
  local moduleExtName = extensions.luaPathToExtName(modulePath)
  for _, modExtName in ipairs(coreModules) do
    if modExtName == moduleExtName then return end
  end
  table.insert(coreModules, moduleExtName)
end

function endActiveGameMode(callback)
  local endCallback = function ()
    unloadGameModules()

    if type(callback) == 'function' then
      callback()
    end
  end
  -- NOTE: We have to use a callback to serverConnection.disconnect because is it updated in a
  --       State machine
  serverConnection.disconnect(endCallback)
end

function queueExtensionToLoad(modulePath)
  -- log('I', 'main', "queueExtensionToLoad called...."..modulePath)
  table.insert(extraUserRequestedExtensions, modulePath)
end

-- called before the Mission Resources are loaded
function clientPreStartMission(levelPath)
  worldReadyState = 0
  extensions.hook('onClientPreStartMission', levelPath)
  guihooks.trigger('PreStartMission')
  core_levels.maybeLoadDefaultVehicle()
end

-- called when level, car etc. are completely loaded (after clientPreStartMission)
function clientPostStartMission(levelPath)
  --default game state, will get overriden by each mode
  core_gamestate.setGameState('freeroam', 'freeroam', 'freeroam')
  extensions.hook('onClientPostStartMission', levelPath)
end

-- called when the level items are already loaded (after clientPostStartMission)
function clientStartMission(levelPath)
  log("D", "clientStartMission", "starting levelPath: " .. tostring(levelPath))
  extensions.hookNotify('onClientStartMission', levelPath)
  map.assureLoad() --> needs to be after extensions.hook('onClientStartMission', levelPath)
  guihooks.trigger('MenuHide')
 -- SteamLicensePlateVehicleId = nil
end

function clientEndMission(levelPath)
  -- core_gamestate.requestGameState()
  -- log("D", "clientEndMission", "ending levelPath: " .. tostring(levelPath))
  be:physicsStopSimulation()
  bullettime.pause(false)
  extensions.hookNotify('onClientEndMission', levelPath)
end

function returnToMainMenu()
  endActiveGameMode()
end

function editorEnabled(enabled)
  --print('editorEnabled', enabled)
  extensions.hook('onEditorEnabled', enabled)
  map.setEditorState(enabled)
end

local luaPreRenderMaterialCheckDuration = 0

-- called from c++ side whenever a performance check log is wanted
local geluaProfiler
function requestGeluaProfile()
  geluaProfiler = LuaProfiler("update() and luaPreRender() gelua function calls")
  extensions.setProfiler(geluaProfiler)
end
-- this function is called right before the rendering, and after running the physics
function luaPreRender(dtReal, dtSim, dtRaw)
  if geluaProfiler then geluaProfiler:start() end
  map.updateGFX(dtReal)
  if geluaProfiler then geluaProfiler:add("luaPreRender map update") end
  extensions.hook('onPreRender', dtReal, dtSim, dtRaw)
  if geluaProfiler then geluaProfiler:add("luaPreRender extensions") end

  if extensions.hookCount('onDrawDebug') > 0 then
    extensions.hook('onDrawDebug', Lua.lastDebugFocusPos, dtReal, dtSim, dtRaw)
  end
  if geluaProfiler then geluaProfiler:add("luaPreRender drawdebug") end

  -- will be used for ge streams later
  -- guihooks.frameUpdated(dtReal)

  -- detect if we need to switch the UI around
  if worldReadyState == 1 then
    -- log('I', 'gamestate', 'Checking if vehicle is done rendering material') -- this is far too verbose and seriously slows down the debugging
    luaPreRenderMaterialCheckDuration = luaPreRenderMaterialCheckDuration + dtRaw
    local playerVehicle = be:getPlayerVehicle(0) or nil

    local allReady = (not playerVehicle) or (playerVehicle and playerVehicle:isRenderMaterialsReady())
    if allReady or luaPreRenderMaterialCheckDuration > 5 then
      log('D', 'gamestate', 'Checking material finished loading')
      core_gamestate.requestExitLoadingScreen('worldReadyState')
      -- switch the UI to play mode
      --guihooks.trigger('ChangeState', 'menu', {'loading', 'backgroundImage.mainmenu'})
      worldReadyState = 2
      luaPreRenderMaterialCheckDuration = 0
      extensions.hook('onWorldReadyState', worldReadyState)
    end
  end
  if geluaProfiler then geluaProfiler:add("luaPreRender ending") end
end

local lastTimeSinceLastMouseMoved = 0
local lastTimeSinceLastRadialMoved = 0 -- for radial menu app (moved by gamepad usually)

function updateFirstFrame()
  -- completeIntegrityChunk("base") -- unused for now
  extensions.hook('onFirstUpdate')
  settings.finalizeInit()

  editorEnabled(Engine.getEditorEnabled()) -- make sure the editing tools are in the correct state
  handleCommandLineFirstFrame()
end

-- this function is called after input and before physics
function update(dtReal, dtSim, dtRaw)
  if geluaProfiler then geluaProfiler:start() end
  --local used_memory_bytes, _ = gcinfo()
  --log('D', "update", "Lua memory usage: " .. tostring(used_memory_bytes/1024) .. "kB")
  profilerPushEvent("GE Main Update")

  -- We do not implement the onUpdate hook because we want to control when we tick settings to do its thing.
  settings.settingsTick(dtReal, dtSim, dtRaw)

  extensions.core_input_bindings.updateGFX(dtRaw)
  bullettime.update(dtReal)
  screenshot.updateGFX()
  if geluaProfiler then geluaProfiler:add("update beginning") end

  extensions.hook('onUpdate', dtReal, dtSim, dtRaw)
  if geluaProfiler then geluaProfiler:add("update extensions") end
  if be:getUpdateUIflag() then
    extensions.hook('onGuiUpdate', dtReal, dtSim, dtRaw)
    if geluaProfiler then geluaProfiler:add("update onGuiUpdate") end
  end
  perf.update()

  local timeSinceLastMouse = Engine.Platform.getSystemTimeMS() - getMovedMouseLastTimeMs()
  if timeSinceLastMouse - lastTimeSinceLastMouseMoved < 0 then
    guihooks.trigger('MenuFocusShow', false)
  end
  lastTimeSinceLastMouseMoved = timeSinceLastMouse

  if core_quickAccess then
    local timeSinceLastRadial = Engine.Platform.getSystemTimeMS() - core_quickAccess.getMovedRadialLastTimeMs()
    if timeSinceLastRadial - lastTimeSinceLastRadialMoved < 0 then
      guihooks.trigger('MenuFocusShow', false)
    end
    lastTimeSinceLastRadialMoved = timeSinceLastRadial
  end

  if geluaProfiler then geluaProfiler:add("update ending") end
  if geluaProfiler then
    geluaProfiler:finish(true)
    geluaProfiler = nil
    extensions.setProfiler(geluaProfiler)
  end
  profilerPopEvent()
end

-- called when the UI is up and running
function uiReady()
  extensions.hook('onUiReady')
end

-- Also called on reload (Control-L)
function init(reason)
  settings.initSettings(reason)

  --log('D', "init", 'GameEngine Lua (re)loaded')
  flowGraphEditor_ffi_cdef_loaded = false

  -- be sensitive about global writes from now on
  detectGlobalWrites()

  extensions.load(coreModules)

  extraUserRequestedExtensions = {}

  core_online.openSession() -- try to connect to online services

  -- import state last
  importPersistentData()

  -- request the UI ready state
  guihooks.trigger('isUIReady')

  map.assureLoad()

  -- world ready to do sth
  if worldReadyState ~= -1 then  -- Do not change to zero when we are sitting in the Main menu on a fresh start of the game
    worldReadyState = 0
  end

  -- put the mods folder in clear view, so users don't put stuff in the wrong place
  if not FS:directoryExists("mods") then FS:directoryCreate("mods") end

  if not FS:directoryExists("trackEditor") or not string.startswith(FS:getFileRealPath("trackEditor"), getUserPath())  then FS:directoryCreate("trackEditor") end
end

function onBeamNGWaypoint(args)
  map.onWaypoint(args)
  extensions.hook('onBeamNGWaypoint', args)
end

-- do not delete - this is the default function name for the BeamNGTrigger from the c++ side
function onBeamNGTrigger(data)
  extensions.hook('onBeamNGTrigger', data)
end

function onFileChanged(files)
  --print("onFileChanged: " .. dumps(files))
  settings.onFilesChanged(files)
  map.onFilesChanged(files)
  extensions.hook('onFilesChanged', files)

  for _,v in pairs(files) do
    --print("onFileChanged: " .. tostring(v.filename) .. ' : ' .. tostring(v.type))
    extensions.hook('onFileChanged', v.filename, v.type)
  end
  extensions.hook('onFileChangedEnd')
end

function physicsEngineEvent(...)
  local args = unpack({...})
  extensions.hook('onPhysicsEngineEvent', args)
end

function vehicleSpawned(vid)
  local v = be:getObjectByID(vid)
  if not v then return end

  -- update the gravity of the vehicle
  if core_environment then
    v:queueLuaCommand("obj:setGravity("..core_environment.getGravity()..")")
  end

  invalidateVehicleCache()
  extensions.hook('onVehicleSpawned', vid, v)
end

-- when the player is switching vehicles
function vehicleSwitched(oldVehicle, newVehicle, player)
  local oid = oldVehicle and oldVehicle:getId() or -1
  local nid = newVehicle and newVehicle:getId() or -1
  -- local oldinfo = oldVehicle and ("id "..dumps(oid).." ("..oldVehicle:getPath()..")") or dumps(oldVehicle)
  -- local newinfo = newVehicle and ("id "..dumps(nid).." ("..newVehicle:getPath()..")") or dumps(newVehicle)
  --log('I', 'main', "Player #"..dumps(player).." vehicle switched from: "..oldinfo.." to: "..newinfo)
  --Steam.setStat('meters_driven', 1)
  extensions.hook('onVehicleSwitched', oid, nid, player)
  guihooks.trigger('VehicleFocusChanged', {id = nid, mode = true})
end

function vehicleReset(vehicleID)
  extensions.hook('onVehicleResetted', vehicleID)
end

-- Callback when vehicles are activated or deactivated (e.g. by the traffic pooling system)
-- This is unrelated to tabbing into other cars (that would be the vehicleSwitched() function)
function vehicleActiveChanged(vehicleID, active)
  extensions.hook('onVehicleActiveChanged', vehicleID, active)
end

function onMouseLocked(locked)
  extensions.hook('onMouseLocked', locked)
end

function vehicleDestroyed(vid)
  invalidateVehicleCache()
  extensions.hook('onVehicleDestroyed', vid)
end

function onCouplerAttached(objId1, objId2, nodeId, obj2nodeId)
  if objId1 ~= objId2 and settings.getValue("couplerCameraModifier", false) then
    local isEnabled = core_couplerCameraModifier ~= nil
    extensions.load('core_couplerCameraModifier')
    if isEnabled == false and core_couplerCameraModifier.checkForTrailer(objId1, objId2) == false then
      extensions.unload('core_couplerCameraModifier')
    end
  end
  extensions.hook('onCouplerAttached', objId1, objId2, nodeId, obj2nodeId)
end

function onCouplerDetached(objId1, objId2)
  extensions.hook('onCouplerDetached', objId1, objId2)
  if core_couplerCameraModifier ~= nil then
    extensions.unload('core_couplerCameraModifier')
  end
end

--Trigered when trailer coupler is detached by the user
function onCouplerDetach(objId, nodeId)
  extensions.hook('onCouplerDetach', objId, nodeId)
end

function onAiModeChange(vehicleID, newAiMode)
  extensions.hook('onAiModeChange', vehicleID, newAiMode)
end

function prefabLoaded(id, prefabName, prefabPath)
  --log('D', 'main', 'prefabLoaded: ' .. dumps(id)..',' ..dumps(prefabName))
  if prefabLogic then
    prefabLogic.prefabLoaded(id, prefabName, prefabPath)
  end
end

function prefabUnloaded(id, prefabName, prefabPath)
  --log('D', 'main', 'prefabUnloaded: ' .. dumps(id)..',' ..dumps(prefabName))
  if prefabLogic then
    prefabLogic.prefabUnloaded(id, prefabName, prefabPath)
  end
end

function replayStateChanged(...)
  core_replay.stateChanged(...)
end

-- only the vehicle and config are necessary here (the rest of parameters will be set during regular playback anyway, no point duplicating them here too)
function replaySpawnVehicle(jbeamFilename, partConfigData)
  return spawn.spawnVehicle(jbeamFilename, partConfigData, vec3(), quat(), nil, nil, nil)
end

function replayStartLevel(levelPath)
  core_replay.startLevel(levelPath)
end

function exportPersistentData()
  if not be then return end
  local d = serializePackages()
  d.levelLoaded = levelLoaded
  -- log('D', 'main', 'persistent data exported: ' .. dumps(d))
  be.persistenceLuaData = serialize(d)
end

function importPersistentData()
  if not be then return end
  local s = be.persistenceLuaData
  -- log('D', 'main', 'persistent data imported: ' .. tostring(s))
  -- deserialize extensions first, so the extensions are loaded before they are trying to get deserialized
  local data = deserialize(s)
  -- TODO(AK): Remove this stuff post completing serialization work
  -- writeFile("ge_exportPersistentData.txt", dumps(data))
  deserializePackages(data)
  if data then
    rawset(_G, 'levelLoaded', data.levelLoaded)
  end
end

function physicsStateChanged(val)
  guihooks.trigger('physicsStateChanged', val)
  if val then
    extensions.hook('onPhysicsUnpaused')
  else
    extensions.hook('onPhysicsPaused')
  end
end

function updateTranslations()
  -- unmount if in use, so we can update the file
  if FS:isMounted('mods/translations.zip') then
    FS:unmount('mods/translations.zip')
  end

  extensions.core_repository.installMod('locales.zip', 'translations.zip', 'mods/', function(data)
    log('D', 'updateTranslations', 'translations download done: mods/translations.zip')
    -- reload the settings to activate the new files
    settings.newTranslationsAvailable = true -- this enforces the UI refresh, fixes some state problems
    settings.load(true)
  end)
end

function enableCommunityTranslations()
  settings.setState( { communityTranslations = 'enable' } )
  updateTranslations()
end

function onInstabilityDetected(jbeamFilename)
  bullettime.pause(true)
  log('E', "", "Instability detected for vehicle " .. tostring(jbeamFilename))
  ui_message({txt="vehicle.main.instability", context={vehicle=tostring(jbeamFilename)}}, 10, 'instability', "warning")
end

function resetGameplay(playerID)
  extensions.hook('onResetGameplay', playerID)
end

function sendUIModules()
  local ok = xpcall(function()
    guihooks.trigger('onUIBootstrap', FS:directoryList('/ui/modModules/', false, true))
  end, debug.traceback)
  if not ok then
    log('E', '', 'UI Bootstrap failed, using fallback')
    guihooks.trigger('onUIBootstrap', {})
  end
end

function loadDirRec(dir)
  local foundfiles = FS:findFiles(dir, "*materials.cs\t*materials.json\t*datablocks.json", -1, true, false)
  local csMaterialFiles = {}
  local datablockFiles = {}
  local jsonMaterialFiles = {}

  for _, filename in ipairs(foundfiles) do
    if string.find(filename, 'datablocks.json') then
      table.insert(datablockFiles, filename)
    elseif string.find(filename, 'materials.json') then
      table.insert(jsonMaterialFiles, filename)
    elseif string.find(filename, 'materials.cs') then
      table.insert(csMaterialFiles, filename)
    end
  end

  -- load old CS materials first:
  for _, filename in ipairs(csMaterialFiles) do
    TorqueScriptLua.exec(filename)
  end

  -- then the new ones
  for _, filename in ipairs(jsonMaterialFiles) do
    loadJsonMaterialsFile(filename)
  end

  -- datablocks
  for _, filename in ipairs(datablockFiles) do
    loadJsonMaterialsFile(filename)
  end
end

local function loadModScriptsRec(dir)
  --print("Loading ModScripts on " .. dir)
  local filefilter = dir .. "/*/modScript.cs"
  local fileC = findFirstFile(filefilter)

  repeat
    if fileC ~= "" then
      --print(" * loading mod script file: " .. fileC)
      require(fileC)
    end
    fileC = findNextFile(filefilter)
  until fileC == ""
end

------------------------------ Entry point code ------------------------------
function onPreStart()
  -- log('I', 'main', 'onPreStart called...')
end

local function onStart()
  -- onStart invoked from onGameEngineStartup().
end

function onPreWindowClose()
  extensions.hook('onPreWindowClose')
end

function onPreExit()
  extensions.hook('onPreExit')
end

function onExit()
  -- onExit is called directly from C++ code
    extensions.hook('onExit')

    -- scripts_main.onExit()
    -- Ensure that we are disconnected and/or the server is destroyed.
    -- This prevents crashes due to the SceneGraph being deleted before
    -- the objects it contains.
    serverConnection.noLoadingScreenDisconnect()

    -- Destroy the physics plugin.
    PhysicsPlugin.destroy()

    -- TODO(AK) 18/08/2021: check which calls to replace this Parent::onExit with.
    -- Parent::onExit();

    local mainEventManager = scenetree.findObject("MainEventManager")
    if mainEventManager then
      mainEventManager:postEvent("onExit", 0)
    else
      log("E","", "Couldn't find event manager 'MainEventManager'")
    end

    postFxModule.savePresetFile('settings/postfxSettings.postfx')
    settings.exit()
end

function onGameEngineStartup()
  -- log('I', "main", "onGameEngineStartup called.....")

  -- make sure some important paths exist
  if not FS:directoryExists("settings/") then FS:directoryCreate("settings/") end
  if not FS:directoryExists("screenshots/") then FS:directoryCreate("screenshots/") end

  -- Set profile directory
  setConsoleVariable("$Pref::Video::ProfilePath", "core/profile")

  local mainEventManager = createObject("EventManager")
  if mainEventManager then
    -- log("I","", "mainEventManager = "..dumps(mainEventManager))
    mainEventManager.queue = "mainEventManagerQueue"
    mainEventManager:registerEvent("onExit")
    mainEventManager:registerEvent("onStart")
    mainEventManager:registerEvent("onPreStart")
    mainEventManager:registerObject("MainEventManager")
  else
    log("E","", "Couldn't create event manager 'MainEventManager'")
  end

  local parseArgs = require("core/parseArgs")
  parseArgs.defaultParseArgs()

  onPreStartCallback()

  ---------------------------------------------------------
  -- Either display the help message or startup the app.
  -- This is emulating what mainEventManager:postEvent("onPreStart", 0) call would do for all listeners. However, in the entire codebase we
  -- don't have a single CS file responding to this message. We should delete it.
  -- if scripts_main.onPreStart and type(scripts_main.onPreStart) == 'function' then
  --   scripts_main.onPreStart()
  -- end

  -- TODO(AK) 16/08/2021: This is for Torque Script cs files to hook into. Maybe re-enable after removing CS scripts involved in start up
  -- mainEventManager:postEvent("onPreStart", 0)
  ---------------------------------------------------------
  onStart()

  -- core_main.onStart()
  -- Initialise Core stuff.
  local clientCore = require("client/core")
  clientCore.initializeCore()

  -- log('I', "main", "Initialized Core...")

  -- first check if we have a level file to load
  local levelToLoad = getConsoleVariable("$levelToLoad")
  if levelToLoad ~= "" then
    -- Clear out the $levelToLoad so we don't attempt to load the level again later on.
    setConsoleVariable("$levelToLoad", "")
    local levelFile = "levels/" .. levelToLoad
    freeroam_freeroam.startFreeroam(levelFile)
  end

  -- scripts_main.onStart()
  setConsoleVariable("$pref::Directories::Terrain", "levels/")

  -- log('I', "main", "--------- Initializing Directory: scripts---------");

  -- Load the scripts that start it all...
  local client_init = require("client/init")

  -- Init the physics plugin.
  PhysicsPlugin.init("")

  client_init.initClient()

  if mainEventManager then
    mainEventManager:postEvent("onStart", 0)
  end

  log("I", "main", "============== Engine initialized ==============")

  -- Automatically start up the appropriate editor, if any
  if getConsoleBoolVariable("$startWorldEditor") then
    local canvas = scenetree.findObject("Canvas")
    local cursor = scenetree.findObject("DefaultCursor")
    local editorChooseLevelGui = scenetree.findObject("EditorChooseLevelGui")
    if canvas and cursor then
      canvas:setCursor(cursor)
      canvas:setContent(editorChooseLevelGui)
    end
  end
end

function onLuaReloaded()
  -- log('I', "main", "onLuaReloaded called.....")

  onStart()

  -- Initialise Core stuff.
  local clientCore = require("client/core")
  clientCore.reloadCore()

  -- log('I', "main", "Reloaded Core...")

  -- log('I', "main", "--------- Initializing Directory: scripts---------");
  -- Load the scripts that start it all...
  local client_init = require("client/init")
  client_init.reloadClient()

  log("I", "main", "============== Engine reloaded ==============")
end

function updateLoadingProgress(val, txt)
  local msg = string.format("[{val: %u%%, txt: %s}]", math.floor(100 * val), txt)

  guihooks.trigger("UpdateProgress", msg) -- the Json object is inside an array as it is the first argument of the function :)

  local loadingLevel = TorqueScriptLua.getBoolVar("$loadingLevel")

  if loadingLevel then
    local canvas = scenetree.findObject("Canvas")
    if canvas then
      canvas:repaintUI(1000/30) -- 30 fps
    end
  end
  setConsoleVariable("$lastProgress", val)
  setConsoleVariable("$$lastProgressTxt", txt)
end

function updateTSShapeLoadProgressDynamic(progress, msg)
  if updateTSShapeLoadProgress then
    -- usually the case if the editor is loaded, it usually calls updateLoadingProgress in it then
    updateTSShapeLoadProgress(progress, msg)
  else
    -- usually the case if the editor is NOT loaded
    -- %msg = translate("ui.loading.spawn.collada", "Importing 3D stuff") .. " ...";
    updateLoadingProgress(progress, msg)
  end
end

