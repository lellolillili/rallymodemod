-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local delayedData = {}
local delayCounter = 1
local function start(fade)
  fade = fade or 1
  local data = {fadeIn = fade, pause = 1e6, fadeOut = 0} -- fade to and stop on black
  guihooks.trigger('ChangeState', {state = 'fadeScreen', params = data})
end

local function stop(fade)
  fade = fade or 1
  local data = {fadeIn = 0, pause = 0, fadeOut = fade} -- fade from black
  guihooks.trigger('ChangeState', {state = 'fadeScreen', params = data})
end

local function cycle(fadeIn, pause, fadeOut) -- fade to black, pause, then fade from black
  fadeIn = fadeIn or 1
  pause = pause or 0
  fadeOut = fadeOut or fadeIn
  local data = {fadeIn = fadeIn, pause = pause, fadeOut = fadeOut}
  guihooks.trigger('ChangeState', {state = 'fadeScreen', params = data})
end

-- this delay is needed so we can be sure that the screen is completely black before moving on.
local function onScreenFadeStateDelayed(state)
  table.insert(delayedData, state)
  delayCounter = 1
end

local function onGuiUpdate()
  if delayedData[1] then
    if delayCounter <= 0 then
      for _, v in ipairs(delayedData) do
        extensions.hook("onScreenFadeState",v)
      end
      table.clear(delayedData)
    end
    delayCounter = delayCounter - 1
  end
end

-- public interface
M.start = start
M.stop = stop
M.cycle = cycle
M.onScreenFadeStateDelayed = onScreenFadeStateDelayed
M.onGuiUpdate = onGuiUpdate
return M