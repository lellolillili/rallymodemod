-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local stateCache = nil

local function isValid()
  if stateCache == nil then
    stateCache = ResearchVerifier.isTechLicenseVerified() or false
  end
  return stateCache
end

local function requestState()
  guihooks.trigger('TechLicenseState', isValid())
end

-- returns true if it makes sense to load this inputmap
local function isAllowedInputmapPath(path)
  if isValid() then return true end
  return string.find(path, "_beamng.tech") == nil
end

-- returns true if it makes sense to load this inputmap
local function isAllowedActionsPath(path)
  if isValid() then return true end
  return string.find(path, "_beamng.tech") == nil
end

M.isValid = isValid
M.requestState = requestState
M.isAllowedInputmapPath = isAllowedInputmapPath
M.isAllowedActionsPath  = isAllowedActionsPath

return M

