-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Set Signal Values'
C.description = 'Set signal controller phase, light, and other values.'
C.color = ui_flowgraph_editor.nodeColors.signals
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'once_instant'
C.tags = {'traffic', 'signals'}


C.pinSchema = {
  {dir = 'in', type = 'table', name = 'controllerData', tableType = 'signalControllerData', description = 'Signal controller data from an intersection.'},
  {dir = 'in', type = 'number', name = 'phaseIndex', description = 'Controller phase index; if none given, the currently active phase will be used.'},
  {dir = 'in', type = 'number', name = 'lightIndex', description = 'Signal light index (by default, 1 = green, 2 = yellow, and 3 = red).'},
  {dir = 'in', type = 'bool', name = 'pauseTimer', description = 'Pause or unpause the automatic timer that sets the next light.'}
}

C.dependencies = {'core_trafficSignals'}

function C:workOnce()
  local ctrl = self.pinIn.controllerData.value
  if ctrl and ctrl.setSignal then
    local signalIdx = self.pinIn.phaseIndex.value or ctrl.signalIdx
    local lightIdx = self.pinIn.lightIndex.value

    if lightIdx then
      ctrl:setSignal(signalIdx, lightIdx)
    end
    if type(self.pinIn.pauseTimer.value) == 'boolean' then
      ctrl:ignoreTimer(self.pinIn.pauseTimer.value)
    end
  end
end

return _flowgraph_createNode(C)