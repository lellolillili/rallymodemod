-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {
  blurRects = {}
}

local counter = 0

local function addToGroup (group, rect)
  if M.blurRects[group] == nil then
    M.blurRects[group] = {}
  end

  if counter > 10000 then
    counter = 0
  end

  counter = counter + 1

  M.blurRects[group][counter] = rect

  return counter
end

local function removeFromGroup (group, id)
  M.blurRects[group][id] = nil
end

local function replaceGroup (group, data)
  M.blurRects[group] = data
end

local function removeGroup (group)
  M.blurRects[group] = nil
end

local function removeAllGroups ()
  M.blurRects = {}
end


-- Blur api:
-- (0, 0) is top left corner; (1, 1) bottom right
-- maskedBlurFX.obj:addFrameBlurRect(0, 0.15, 1, 0.8, ColorF(1, 1, 1, 1))

local function onPreRender()
  if not extensions.ui_visibility.getCef() then return end
  local maskedBlurFX = scenetree.ScreenBlurFX
  if maskedBlurFX then

    for _, list in pairs(M.blurRects) do
      for _, data in pairs(list) do
        maskedBlurFX.obj:addFrameBlurRect(data[1], data[2], data[3], data[4], ColorF(1, 1, 1, data[5]))
      end
    end

  end
end


M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onPreRender = onPreRender

M.replaceGroup = replaceGroup
M.removeGroup = removeGroup
M.removeAllGroups = removeAllGroups
M.setColor = setColor

return M