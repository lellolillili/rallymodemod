-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Is Walking'
C.description = 'Checks if the player is in walking mode or not.'
C.color = ui_flowgraph_editor.nodeColors.walking
C.icon = ui_flowgraph_editor.nodeIcons.walking
C.category = 'repeat_instant'

C.pinSchema = {
    { dir = 'out', type = 'flow', name = 'walking', description = "Outflow when the player is currently walking." },
    { dir = 'out', type = 'flow', name = 'nonWalking', description = "Outflow when the player is currently not walking.", hidden = true },
    { dir = 'out', type = 'flow', name = 'enteredWalking', description = "Outflow once when the player entered walking mode.", hidden = true, impulse = true },
    { dir = 'out', type = 'flow', name = 'exitedWalking', description = "Outflow once when the player exited walking mode.", hidden = true, impulse = true },
}
C.dependencies = {'gameplay_walk'}

function C:_executionStarted()
  self.prevWalk = gameplay_walk.isWalking()
end

function C:work(args)
  local walk = gameplay_walk.isWalking()
  self.pinOut.walking.value = walk
  self.pinOut.nonWalking.value = not walk
  self.pinOut.enteredWalking.value = not self.prevWalk and walk
  self.pinOut.exitedWalking.value = self.prevWalk and not walk
end

function C:drawMiddle(builder, style)
  builder:Middle()
  if gameplay_walk then
    editor.uiIconImage(editor.icons.directions_walk, im.ImVec2(40, 40), gameplay_walk.isWalking() and im.ImVec4(0.3,1,0.3,1) or im.ImVec4(1,1,1,0.3))
  end
end

return _flowgraph_createNode(C)
