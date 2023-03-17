-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this is a little helper for the level people, so they can mark things :)

local M = {}

local function onWindowMenuItem()
  extensions.util_createThumbnails.openWindow()
end

local function onEditorInitialized()
  editor.addWindowMenuItem("Vehicle Thumbnails (OLD) - use screenshot creator", onWindowMenuItem, {groupMenuName = 'Experimental'})
end

-- public interface
M.onEditorInitialized = onEditorInitialized

return M