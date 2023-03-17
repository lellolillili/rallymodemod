-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this is a little helper for the level people, so they can mark things :)

local M = {}

local im = ui_imgui
local imUtils = require('ui/imguiUtils')
local toolWindowName = "physicsReloader"

local function openWindow()
  editor.showWindow(toolWindowName)
end

local function onEditorGui( )
  if editor.beginWindow(toolWindowName, "Physics Reloader") then
    if BeamEngine and im.Button("destroyPhysics") then
      Engine.destroyPhysics()
      BeamEngine = nil
      be = nil
    end
    if not BeamEngine and im.Button("createPhysics") then
      im.TextUnformatted("Please replace libbeamng.dll now")
      BeamEngine = Engine.createPhysics()
      be = BeamEngine
    end
  end
  editor.endWindow()
end

local function onWindowMenuItem()
  openWindow()
end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(300, 500))
  editor.addWindowMenuItem("Physics Reloader", onWindowMenuItem)
end

-- public interface
M.openWindow = openWindow
M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized

return M