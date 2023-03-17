-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Set Pursuit Mode'
C.description = 'Sets the police pursuit mode; traffic must be enabled.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'once_instant'
C.tags = {'police', 'cops', 'pursuit', 'chase', 'traffic', 'ai'}


C.pinSchema = {
  { dir = 'in', type = 'number', name = 'mode', description = 'Pursuit mode; 0 = off, 1 to 3 = on, -1 = busted.' },
  { dir = 'in', type = 'number', name = 'targetId', description = 'Target id; if none given, the current player vehicle is used.' },
  { dir = 'in', type = 'number', name = 'policeId', hidden = true, description = 'Police id; if none given, all police vehicles get activated.' }
}

function C:workOnce()
  if gameplay_traffic.getState() == 'on' then
    gameplay_police.setPursuitMode(self.pinIn.mode.value or 0, self.pinIn.targetId.value, self.pinIn.policeId.value)
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  if gameplay_traffic and gameplay_traffic.getState() ~= 'on' then
    im.TextUnformatted('Traffic not active!')
  end
end

return _flowgraph_createNode(C)