-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local im = ui_imgui

local function onEditorMainMenuBar(windowSize)
  if not Lua.getDevLogStats then return end

  --TODO: not working anymore
  --im.SameLine(windowSize.x - 110)

  local t = Lua:getDevLogStats()

  im.TextColored(im.ImVec4(0.7, 0.7, 0.7, 1), "\tLogStats: ")

  if type(t.errors) == 'number' and t.errors > 0 then
    im.TextColored(im.ImVec4(1.0, 0.0, 0.0, 1.0), tostring(t.errors) .. 'E ')
    --im.SameLine()
  end
  if type(t.warnings) == 'number' and t.warnings > 0 then
    im.TextColored(im.ImVec4(1.0, 1.0, 0.0, 1.0), tostring(t.warnings) .. 'W')
  end
end

-- public interface
M.onEditorMainMenuBar = onEditorMainMenuBar

return M