-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this extension will generate json and other resoruces that can then be integrated into our documentation / hugo system

-- extensions.util_docCreator.run()

local jsonEncodeFull = require('libs/lunajson/lunajson').encode -- slow but conform encoder

local M = {}

local outputFolderData = 'doc-out/data/'
local outputFolderResources = 'doc-out/resources/'
local quitOnDone = false

local function changeLanguage(lang)
  Lua.userLanguage = lang
  Lua:reloadLanguages()
end

local function jsonOut(filename, data)
  filename = outputFolderData .. filename
  local f = io.open(filename, "w")
  if not f then return end
  f:write(jsonEncodePretty(data))
  --f:write(jsonEncodeFull(data))
  f:close()
end

local function getLanguagesAvailable()
  local locales = FS:findFiles('/locales/', '*.json', -1, true, false)
  local res = {}
  for _, l in pairs(locales) do
    local key = string.match(l, 'locales/([^\\.]+).json')
    table.insert(res, key)
  end
  return res
end

local function cleanupTable(job, tbl)
  if type(tbl) == 'table' then
    for k, v in pairs(tbl) do
      if type(v) == 'table' then
        cleanupTable(job, v)
      elseif type(v) == 'string' then
        tbl[k] = translateLanguage(v, v)
        v = tbl[k]

        if string.len(v) > 0 and FS:fileExists(v) then
          local orgFilename = v
          local dir, filename, ext = path.split(v)
          ext = ext:lower()
          local newFilename = FS:hashFileSHA1(v) .. '.' .. ext
          local outFilename = outputFolderResources .. newFilename
          if not FS:fileExists(outFilename) then
            FS:copyFile(v, outFilename)
            job.yield()
          end
          tbl[k] = '/game/resources/' .. newFilename
        end
      end
    end
  end
  job.yield()
end


local function exportDataLangSpecific(job, lang)
  print(lang)
  changeLanguage(lang)

  local levels = extensions.core_levels.getList()
  cleanupTable(job, levels)

  for _, level in ipairs(levels) do
    if type(level.size) == 'table' and #level.size > 1 then
      if level.size[1] == -1 and level.size[2] == -1 then
        level.size = nil
      end
    end
    level.openLink = 'beamng:v1/openMap/{"level":"' .. level.fullfilename .. '"}'
  end

  local vehicles = {
    models = extensions.core_vehicles.getModelList(true),
    configs = extensions.core_vehicles.getConfigList(true)
  }
  cleanupTable(job, vehicles)

  jsonOut('levels_' .. lang .. '.json', levels)
  jsonOut('vehicles_' .. lang .. '.json', vehicles)
end

local function exportDataCommon(job)
  -- write some version file so the doc knows where this came from
  local versionInfo = {}
  versionInfo['beamng_versionb'] = beamng_versionb
  versionInfo['beamng_versiond'] = beamng_versiond
  versionInfo['beamng_windowtitle'] = beamng_windowtitle
  versionInfo['beamng_buildtype'] = beamng_buildtype
  versionInfo['beamng_buildinfo'] = beamng_buildinfo
  versionInfo['beamng_arch'] = beamng_arch
  versionInfo['beamng_buildnumber'] = beamng_buildnumber
  versionInfo['beamng_appname'] = beamng_appname
  versionInfo['shipping_build'] = tostring(shipping_build)
  jsonOut('game_version.json', versionInfo)

  -- Materials
  local materials, _ = require("particles").getMaterialsParticlesTable()
  local materialsClean = {}
  for i, m in pairs(materials) do
    table.insert(materialsClean, m.name) -- {m.colorR, m.colorG, m.colorB}
  end
  jsonOut('physics_materials.json', materialsClean)

  -- jbeam defaults
  local loader = require("jbeam/loader")
  local jbeamDefaults = {
    defaultBeamSpring = loader.defaultBeamSpring,
    defaultBeamDeform = loader.defaultBeamDeform,
    defaultBeamDamp = loader.defaultBeamDamp,
    --defaultBeamStrength = loader.defaultBeamStrength,
    defaultNodeWeight = loader.defaultNodeWeight,
  }
  jsonOut('physics_jbeam_defaults.json', jbeamDefaults)

  -- jbeam stats
  jsonOut('jbeam_stats.json', extensions.util_jbeamStats.getStats(), true)
end

local function run(job)
  FS:directoryCreate(outputFolderData)
  FS:directoryCreate(outputFolderResources)
  --exportData('en-US')

  for _, lang in ipairs(getLanguagesAvailable()) do
    exportDataLangSpecific(job, lang)
  end
  exportDataCommon(job)
  print("DONE")
  if quitOnDone then
    shutdown(0)
  end
end

local function runAsync()
  extensions.core_jobsystem.create(run, 1)
end

local function runAsyncAndQuit()
  quitOnDone = true
  extensions.core_jobsystem.create(run, 1)
end

M.run = runAsync
M.runAndQuit = runAsyncAndQuit

return M