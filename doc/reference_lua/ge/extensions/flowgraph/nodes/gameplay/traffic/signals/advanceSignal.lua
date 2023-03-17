-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Advance Signal'
C.description = 'Advances the signal controller to its next light state.'
C.color = ui_flowgraph_editor.nodeColors.signals
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'once_instant'
C.tags = {'traffic', 'signals'}


C.pinSchema = {
  {dir = 'in', type = 'table', name = 'controllerData', tableType = 'signalControllerData', description = 'Signal controller data from an intersection.'}
}

C.dependencies = {'core_trafficSignals'}

function C:workOnce()
  local ctrl = self.pinIn.controllerData.value
  if ctrl and ctrl.advance then
    self.pinIn.controllerData.value:advance()
  end
end

return _flowgraph_createNode(C)