-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Traffic Signals Settings'
C.description = 'Applies settings for the traffic signals system.'
C.color = ui_flowgraph_editor.nodeColors.signals
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'once_instant'
C.tags = {'traffic', 'signals'}


C.pinSchema = {
  {dir = 'in', type = 'bool', name = 'signalsActive', description = 'Enable or disable the running logic of the traffic signals system.'},
  {dir = 'in', type = 'bool', name = 'simpleLights', description = 'Enable or disable simple visuals that act like signal lights.'},
}

C.dependencies = {'core_trafficSignals'}

function C:_executionStopped()
  if core_trafficSignals then -- reset settings to default
    core_trafficSignals.setActive(true)
    core_trafficSignals.setDebugLevel(0)
  end
end

function C:workOnce(args)
  if core_trafficSignals.getValues().loaded then
    if type(self.pinIn.signalsActive.value) == 'boolean' then
      core_trafficSignals.setActive(self.pinIn.signalsActive.value)
    end
    if type(self.pinIn.simpleLights.value) == 'boolean' then
      core_trafficSignals.setDebugLevel(self.pinIn.simpleLights.value and 1 or 0)
    end
  end
end

return _flowgraph_createNode(C)