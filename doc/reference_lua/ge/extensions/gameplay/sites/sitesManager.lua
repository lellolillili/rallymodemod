-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}

local ffi = require('ffi')
local sitesByFilepath = {}
local sitesByLevelByName = {}
local sitesByLevel = {}
local currentLevel = nil

M.onModManagerReady = function()
  M.loadAllLevelSites()
end

M.loadAllLevelSites = function()
  -- load all poi.sites.json per level
  table.clear(sitesByLevel)
  for _, info in ipairs(core_levels.getList()) do
    local level = info.levelName
    sitesByLevel[level] = {}
    local sites = FS:findFiles(info.misFilePath, '*.sites.json', 0, false, false)
    for _,sitePath in ipairs(sites) do
      table.insert(sitesByLevel[level], M.loadSites(sitePath, true))
    end
    for _, site in ipairs(sitesByLevel[level]) do
      --[[ -- deactivated because career zone visualizations are not driven by fence resolution
      if site.filename == 'garages.sites.json' then
        for _, zone in pairs(site.zones.objects) do zone:makeHighResolutionFence() end
      end
      ]]
      site:finalizeSites()
      sitesByFilepath[site.dir..site.filename] = site
      sitesByLevelByName[level] = sitesByLevelByName[level] or {}

      sitesByLevelByName[level][string.sub(site.filename,0,-12)] = site
    end
  end
end

M.loadSites = function (filepath, force, ignoreCache)
  if sitesByFilepath[filepath] and not force then
    return sitesByFilepath[filepath]
  else
    local data = jsonReadFile(filepath)
    if data then
      local dir, filename, ext = path.split(filepath)
      local site = require('/lua/ge/extensions/gameplay/sites/sites')()
      site:onDeserialized(data)
      site.dir = dir
      site.filename = filename
      if not ignoreCache then
        sitesByFilepath[filepath] = site
      end
      site:finalizeSites()
      -- log("D", "Load Sites", "Loaded Sites: " .. filepath)
      return site
    else
      --log("E", "Load Sites", "Could not find file " .. filepath)
    end
    return nil
  end
end

M.onLoadingScreenFadeout = function(mission)
  currentLevel = getCurrentLevelIdentifier()
end

M.onSerialize = function()
  local ret = {
    sitesByLevel = {},
    currentLevel = currentLevel,
    sitesByFilepath = {}
  }
  local done = {}
  for level, sites in pairs(sitesByLevel) do
    ret.sitesByLevel[level] = {}
    for _, site in ipairs(sites) do
      table.insert(ret.sitesByLevel[level],site:onSerialize())
      done[site.dir..site.filename] = 1
    end
  end
  for fp, site in pairs(sitesByFilepath) do
    if not done[fp] then
      table.insert(ret.sitesByFilepath, site:onSerialize())
    end
  end
  return ret
end

M.onDeserialized = function(data)
  table.clear(sitesByLevel)
  currentLevel = data.currentLevel or getCurrentLevelIdentifier()
  for level, sites in pairs(data.sitesByLevel) do
    sitesByLevel[level] = {}
    sitesByLevelByName[level] = sitesByLevelByName[level] or {}
    for _, s in ipairs(sites) do
      local site = require('/lua/ge/extensions/gameplay/sites/sites')()
      site:onDeserialized(s)
      site:finalizeSites()
      table.insert(sitesByLevel[level], site)
      sitesByFilepath[site.dir..site.filename] = site
      sitesByLevelByName[level][string.sub(site.filename,0,-12)] = site
    end
  end
  for fp, s in pairs(data.sitesByFilepath) do
    local site = require('/lua/ge/extensions/gameplay/sites/sites')()
    site:onDeserialized(s)
    site:finalizeSites()
    sitesByFilepath[fp] = site
  end
end

M.getSitesByLevel = function() return sitesByLevel end
M.getCurrentLevelSites = function() return sitesByLevel[getCurrentLevelIdentifier()] or {} end
M.getCurrentLevelSitesByName = function(name) return (sitesByLevelByName[getCurrentLevelIdentifier()] or {})[name] end
M.getSitesByFilepath = function() return sitesByFilepath end
return M
