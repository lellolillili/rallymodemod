-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-------------------------------------------------------------------------------
-- Exposed event hooks
-------------------------------------------------------------------------------
-- onEditorSketchCreated
-- onEditorSketchDelete
-- onEditorSketchChanged

local editor

local function createSketch(position, size)
  --TODO
end

local function deleteSketch(sketchObjectId)
  --TODO
end

local function getSketches()
  --TODO
end

local function initialize(editorInstance)
  editor = editorInstance
  editor.createSketch = createSketch
  editor.deleteSketch = deleteSketch
  editor.getSketches = getSketches
end

local M = {}
M.initialize = initialize

return M