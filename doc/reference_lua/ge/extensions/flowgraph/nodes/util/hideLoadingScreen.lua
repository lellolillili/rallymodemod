-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Hide Loading Screen'
C.icon = "public"
C.category = 'once_instant'

C.description = "Hides the loading screen after loading a level. Does nothing if not currently loading a level."
C.pinSchema = {
  { dir = 'out', type = 'flow', name = 'finished', description = 'Outflow for this node.' },
}
C.color = im.ImVec4(0.03,0.3,0.84,0.75)
C.tags = {}

function C:init()
  self.clearOutPinsOnStart = false
end

function C:workOnce()
    self.pinOut.finished.value = false
    --if self.mgr.modules.isLoadingLevel then
    --log("I","","Finishing loading from FG...")
    self.mgr.modules.level:finishedLevelLoading()
    server.fadeoutLoadingScreen(true)
    --log("I","","Finishing loading from FG... NOW DONE")
    --end
end

function C:work()
  if not self.mgr.modules.level.isLoadingLevel then
    self.pinOut.finished.value = true
  end
end

return _flowgraph_createNode(C)
