-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local modActivated = false
local currentJob = nil
local logCooldown = 600
local frame = 0

M.onInit = function()
  registerCoreModule('util/compileImposters')
end

local function sleep(job, seconds)
  local startTime = Engine.Platform.getSystemTimeMS()
  while Engine.Platform.getSystemTimeMS() - startTime < (seconds * 1000) do
    job.yield()
  end
end

local function escapePattern(x)
  return (x:gsub('%%', '%%%%')
           :gsub('^%^', '%%^')
           :gsub('%$$', '%%$')
           :gsub('%(', '%%(')
           :gsub('%)', '%%)')
           :gsub('%.', '%%.')
           :gsub('%[', '%%[')
           :gsub('%]', '%%]')
           :gsub('%*', '%%*')
           :gsub('%+', '%%+')
           :gsub('%-', '%%-')
           :gsub('%?', '%%?'))
end

local function work(job, queue)
  while not core_levels or not freeroam_freeroam do
    log('D', 'compileImposters', 'Level/Freeroam system not initialized yet...')
    job.yield()
  end

  while not modActivated do
    log('D', 'compileImposters', 'Waiting for mods to be activated...')
    job.yield()
  end

  sleep(job, 10)

  for i, levelName in ipairs(queue) do
    log('D', 'compileImposters', 'Loading level for compilation: ' .. levelName)
    while not freeroam_freeroam.startFreeroamByName(levelName) do
      sleep(job, 8)
    end

    local playerVehicle = be:getPlayerVehicle(0)
    while not string.find(string.lower(getMissionFilename()), escapePattern(string.lower(levelName))) and not playerVehicle do
      log('D', 'compileImposters', 'Level not loaded yet: ' .. getMissionFilename() .. ' : ' .. levelName)
      sleep(job, 8)
    end

    sleep(job, 120)

    log('D', 'compileImposters', 'Level loaded. Updating imposters.')

    while logCooldown > 0 do
      sleep(job, 1)
    end

    Engine.Render.updateImposters(true)
    sleep(job, 20)

    while logCooldown > 0 do
      sleep(job, 1)
    end

    log('D', 'compileImposters', 'Moving on to next level.')
    job.yield()

    ::continue::
  end

  log('D', 'compileImposters', 'Finished with current job.')
  currentJob = nil
  return nil
end

M.compileImposters = function(queue)
  if currentJob ~= nil then
    log('E', 'compileImposters', 'There is already a queue of imposter requests being worked on.')
    return false
  end

  currentJob = core_jobsystem.create(work, nil, queue)
end

M.onPreRender = function(dt)
  if currentJob == nil then
    return
  end

  if logCooldown > 0 then
    logCooldown = logCooldown - 1
  end

  frame = frame + 1
  if frame > 6000 then
    log('I', 'compileImposters', 'Shutting down due to timeout.')
    shutdown(0)
  end
end

M.onModManagerReady = function(mod)
  modActivated = true
end

M.onConsoleLog = function(timer, lvl, origin, line)
  logCooldown = 6000
end

return M
