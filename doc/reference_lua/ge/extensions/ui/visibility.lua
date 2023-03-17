-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = { state={} }
M.state.cefVisible = true
M.state.imguiVisible = Engine.imgui.isEnabled()

-- CEF ui visibility
local function getCef()
  return M.state.cefVisible
end
local function setCef(visible)
  visible = visible and true or false
  if visible ~= M.state.cefVisible then
    guihooks.trigger('onCefVisibilityChanged', visible)
    extensions.hook('onCefVisibilityChanged', visible)
  end
  M.state.cefVisible = visible
end

local function toggleCef()
  setCef(not getCef())
end

-- IMGUI ui visibility
local function setImgui(visible)
  visible = visible and true or false
  if visible ~= M.state.imguiVisible then
    Engine.imgui.setEnabled(visible)
  end
  M.state.imguiVisible = visible
end

local function getImgui()
  return M.state.imguiVisible
end

-- general ui visibility
local function set(visible)
  visible = visible and true or false
  setCef(visible)
  setImgui(visible)
end

local function get()
  return M.state.cefVisible
end

local function toggle()
  set(not get())
end


M.toggle = toggle
M.set = set
M.get = get

M.toggleCef = toggleCef
M.setCef = setCef
M.getCef = getCef

M.setImgui = setImgui
M.getImgui = getImgui
return M
