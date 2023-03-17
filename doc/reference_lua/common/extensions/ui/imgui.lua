-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local MT = {}
local C = ffi.C

if vmType == 'game' then
  -- in the gameengine, no wrapper is required, directly call everything
  M = require('lua/common/extensions/ui/imgui_api')
end

local function initContext()
  if vmType == 'game' then
    -- get the 1st, initial c++ context that is managed by the game engine
    M.ctx = C.imgui_GetMainContext()
  end
end

-- working on getting the context the first time
local function onImGuiReady()
  initContext()

  Engine.imgui.enableBeamNGStyle()
end

-- working on getting the context on dynamic reload
local function onExtensionLoaded()
  initContext()
end

-- ability to switch the api access on or off
local setEnabled
if vmType == 'game' then
  setEnabled = function(val) log('E', 'imgui', 'imgui cannot be switched on or off in GE lua') end
end

M.flags = bit.bor
M.onImGuiReady = onImGuiReady
M.onExtensionLoaded = onExtensionLoaded
M.setEnabled = setEnabled

setmetatable(M, MT)

return M
