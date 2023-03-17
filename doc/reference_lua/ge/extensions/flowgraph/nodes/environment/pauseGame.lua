-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Pause Game'
C.description = 'Pause or unpause the simulation'
C.color = ui_flowgraph_editor.nodeColors.ui
C.category = 'once_p_duration'
C.icon = 'pause'
C.author = 'BeamNG'

C.pinSchema = {
  { dir = 'in', type = 'bool', name = 'value', description = 'If the game should be paused or not.' },
}

C.tags = {'pause', 'freeze', 'halt', 'stop', 'interrupt'}

function C:_executionStarted()
  self._pauseGame = false
end

function C:workOnce()
  self._pauseGame = true
end

function C:_afterTrigger()
  if self._pauseGame then
    if bullettime.pause ~= self._pauseGame then
      bullettime.pause(self._pauseGame)
    end
    self._pauseGame = false
  end
end


return _flowgraph_createNode(C)
