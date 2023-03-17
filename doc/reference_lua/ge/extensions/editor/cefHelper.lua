-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- This little tool disables the CEF UI in the imgui editor mode

local M = {}

local function onEditorDeactivated()
  -- disabled for release due to bugs with the track editor
  --scenetree.maincef.visible = true
end

local function onEditorActivated()
  -- disabled for release due to bugs with the track editor
  --scenetree.maincef.visible = false
end

-- public interface
M.onEditorDeactivated = onEditorDeactivated
M.onEditorActivated = onEditorActivated

return M