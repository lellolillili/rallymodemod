-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this 'just' plays the credits music in the background using fmod

local M = {}

local creditsSoundId = nil
local soundParams = nil

local function onExtensionLoaded()
  soundParams = SFXParameterGroup("CreditsSoundParams")
  creditsSoundId = Engine.Audio.createSource('AudioGui', 'event:>Music>credits')
  local snd = scenetree.findObjectById(creditsSoundId)
  if snd then
    snd:play(-1)
    soundParams:addSource(snd.obj)
  end
end

local function onExtensionUnloaded()
  if creditsSoundId then
    Engine.Audio.deleteSource(creditsSoundId)
    creditsSoundId = nil
  end
end

M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded

return M