-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'Reset Prefab'
C.description = 'Resets a prefab, restoring the '
C.category = 'once_instant'
C.author = 'BeamNG'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'id', description = 'Defines the id of prefab to reset.' },
  --{dir = 'in', type = 'table', name = 'resetData', description = 'Data needed to reset the prefab.'},
}
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.tags = {}

function C:workOnce()
  self.mgr.modules.prefab:restoreVehiclePositions(self.pinIn.id.value)
end

return _flowgraph_createNode(C)
