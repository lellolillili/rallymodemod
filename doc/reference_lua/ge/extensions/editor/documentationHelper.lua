-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_extension_dochelper'

local function openHelp(contextPageName)
  openWebBrowser("https://documentation.beamng.com/world_editor/".. (contextPageName or "index") .. ".html")
end

local function openCodingHelp(contextPageName)
  openWebBrowser("https://documentation.beamng.com/world_editor/api_reference/".. (contextPageName or "index") .. ".html")
end

local function onEditorInitialized()
  editor.openHelp = openHelp
  editor.openCodingHelp = openCodingHelp
end

M.onEditorInitialized = onEditorInitialized

return M