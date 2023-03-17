-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = "serverConnection"

local function onCameraHandlerSetInitial()
  if worldReadyState == 0 then
    local canvas = scenetree.findObject("Canvas")
    if canvas then
      canvas:enableCursorHideIfMouseInactive(true)
    else
      log('E', logTag, 'canvas not found')
    end
    -- The first control object has been set by the server
    -- and we are now ready to go.

    log('D', logTag, 'Everything should be loaded setting worldReadyState to 1')
    worldReadyState = 1 -- should be ready, wait for the vehicle to be done, then switch. stage 2 is in the frame update
    extensions.hook('onWorldReadyState', worldReadyState)
  end
end

--trigger by starting game and then starting a new level
local function disconnectActual(callback, loadingScreen)
  -- We need to stop the client side simulation
  -- else physics resources will not cleanup properly.
  be:physicsStopSimulation()
  local canvas = scenetree.findObject("Canvas")
  if not canvas then
    log('E', logTag, 'canvas not found')
  end
  canvas:enableCursorHideIfMouseInactive(false);

  -- Disable mission lighting if it's going, this is here
  -- in case we're disconnected while the mission is loading.

  TorqueScriptLua.setVar("$lightingMission", "false")
  TorqueScriptLua.setVar("$sceneLighting::terminateLighting", "true")

  -- Call destroyServer in case we're hosting
  server:destroy()
  setMissionFilename("")
  if loadingScreen then core_gamestate.requestExitLoadingScreen(logTag) end
  if callback then
    return callback()
  end
end

local function disconnectWrapper (callback, loadingScreen)
  if loadingScreen == nil then loadingScreen = true end
  local function help ()
    disconnectActual(callback, loadingScreen)
  end
  if loadingScreen then
    core_gamestate.requestEnterLoadingScreen(logTag, help)
  else
    help()
  end
end

-- TODO: clean this up, but not call disconnectActual directly it just will result in the gamestate getting mixed messages
local function noLoadingScreenDisconnect ()
  disconnectWrapper(nop, false)
end

M.onCameraHandlerSetInitial = onCameraHandlerSetInitial
M.disconnect = disconnectWrapper
M.noLoadingScreenDisconnect = noLoadingScreenDisconnect -- used in .cs
return M