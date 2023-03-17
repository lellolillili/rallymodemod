-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this extension executes certain tasks that are predefined in a json input file

local M = {}

local N = {} -- work items

local frame = 0
local jobfile = '/work.json'
local workItems = nil
local queued = false

-- -lua extensions.load('util_worker') -console -nouserpath

local function loadMaterialsInPath(path)
  -- old material.cs support
  local matFiles = FS:findFiles( path, 'materials.cs', -1, true, false)
  for k,v in pairs(matFiles) do
    TorqueScriptLua.exec(v)
  end
  local matFiles = FS:findFiles( path, '*materials.json', -1, true, false)
  for k,v in pairs(matFiles) do
    loadJsonMaterialsFile(v)
  end
end

local function compileDae(daePath)
  if not FS:fileExists(daePath) then
    log('E', 'util_worker.compileDae', 'filename not existing: ' .. tostring(daePath))
    return false
  end
  local dir, filename, ext = path.split(daePath)
  local src = daePath
  local dst = dir .. filename:sub(1, -4) .. 'cdae'
  local dstData = dir .. filename:sub(1, -4) .. 'meshes.json'

  if compileCollada(src, dst, dstData) == 0 then
    log('I', 'util_worker.compileDae', ' compiled: ' .. tostring(src) .. ' > ' .. tostring(dst))
  else
    log('E', 'util_worker.compileDae', 'unable to compile file: ' .. tostring(src))
  end
  Engine.Render.updateImposters(false)
  return true
end

N.compileMesh = function(w)
  if not w.filename then
    log('E', 'util_worker.compileMesh', 'filename missing: ' .. dumps(w))
    return
  end
  local dir, filename, ext = path.split(w.filename)
  loadMaterialsInPath(dir)
  compileDae(w.filename)
end

N.testImage = function(w)
  if not FS:fileExists(w.filename) then
    log('E', 'util_worker.testImage', 'filename not existing: ' .. tostring(w.filename))
    return false
  end

  -- TODO: test with w.filename

end

N.compileImposters = function(w)
  local levels = w.levels
  log('D', 'worker', 'Queueing imposter compilation for: ' .. dumps(levels))
  util_compileImposters.compileImposters(levels)
end

N.testMod = function(w)
  extensions.test_testMods.work(w.tagid, w.resource_version_id, w.disableSpinScr)
end

N.renderVehiclePreview = function(w)
  dump(w.vehicles)
  test_renderVehiclePreview.renderVehiclePreview(w.vehicles)
end

N.testVehiclesPerformances = function(w)
  log('I', 'worker', "testVehiclesPerformances: " .. dumps(w.pcFile))
  util_saveDynamicData.work(w.pcFile, w.vehicle)
  log('I', 'worker', "testVehiclesPerformances DONE")
end

N.calibrateESC = function(w)
  log('I', 'worker', "calibrateESC: " .. dumps(w.pcFile))
  util_calibrateESC.work(w.pcFile, w.vehicle)
  log('I', 'worker', "calibrateESC DONE")
end

local function onJobDone(job, totalRunning)
  -- log('E', 'util_worker', 'onJobDone : ' .. dumps(job) .. ', # = ' .. tostring(totalRunning))
  if queued and totalRunning == 0 then
    shutdown(0)
  end
end

local function loadWork()
  --log('I', 'util_worker', 'working: ' .. tostring(jobfile))
  --TorqueScript.eval("$disableTerrainMaterialCollisionWarning=1;$disableCachedColladaNotification=1;")
  workItems = jsonReadFile(jobfile)
  if not workItems then
    log('E', 'worker', 'unable to read work items from file: ' .. tostring(jobfile))
  end
  log('I', 'util_worker', tostring(#workItems) .. " items to work off from file " .. tostring(jobfile) .. " ...") -- .. dumps(workItems))
end

local function onExtensionLoaded()
  log('I', 'util_worker', 'loaded')
  registerCoreModule('util/worker')
  extensions.load('test/renderVehiclePreview')
  extensions.load('util/saveDynamicData')
  extensions.load('util/calibrateESC')
  extensions.load('util/compileImposters')

  loadWork()
end

M.onPreRender = function(dt)
  if frame < 120 then
    frame = frame + 1
    return
  end

  if workItems ~= nil then
    -- this calls the helper functions in N
    for i = 1, #workItems do
      local w = workItems[i]
      if w.type then
        if N[w.type] then
          N[w.type](w)
        else
          log('E', 'util_worker', " - unknown work type: " .. dumps(w))
        end
      else
        log('E', 'util_worker', " - unknown work type: " .. dumps(w))
      end
    end
    workItems = nil
    queued = true
  end

  if queued and core_jobsystem.getRunningJobCount() == 0 then
    -- no jobs? no problem! :)
    shutdown(0)
  end
end

-- interface
M.onExtensionLoaded = onExtensionLoaded
M.onJobDone = onJobDone

return M
