-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local function onFirstUpdate()
  local soundsJson = jsonReadFile("ui/soundClasses.json")
  M.ui_sound_classes = soundsJson or {}
end

local function playEventSound(className, eventName)
  local sound_class = M.ui_sound_classes[className] or {}
  local event = sound_class[eventName]
  if event then
    Engine.Audio.playOnce('AudioGui', event.sfx)
  end
end

M.onFirstUpdate = onFirstUpdate
M.playEventSound = playEventSound

return M