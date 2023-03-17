-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'File Traffic Signals'
C.description = 'Loads a Traffic Signals file, and sends out data.'
C.category = 'once_p_duration'
C.color = ui_flowgraph_editor.nodeColors.signals
C.icon = ui_flowgraph_editor.nodeIcons.traffic

C.pinSchema = {
  {dir = 'in', type = 'string', name = 'file', description = 'File of the traffic signals.'},
  {dir = 'out', type = 'table', name = 'signalsData', tableType = 'signalsData', description = 'Traffic signals data, to be used with other nodes.'}
}

C.tags = {'traffic', 'signals'}
C.dependencies = {'core_trafficSignals'}

function C:init()
  self.signalsData = nil
  self.data.useDefault = false
end

function C:postInit()
  self.pinInLocal.file.allowFiles = {
    {'Signals Files', '.json'}
  }
end

function C:drawCustomProperties()
  if im.Button('Open Traffic Signals Editor') then
    if editor_trafficSignalsEditor then
      editor_trafficSignalsEditor.onWindowMenuItem()
    end
  end

  local var = im.BoolPtr(self.data.useDefault)
  if im.Checkbox('Use Default Signals File From Map', var) then
    self.data.useDefault = var[0]
  end
end

function C:onNodeReset()
  self.signalsData = nil
end

function C:_executionStopped()
  self.signalsData = nil
  if core_trafficSignals then
    core_trafficSignals.loadSignals() -- reload default signals file for the map
  end
end

function C:work()
  if not self.signalsData then
    local file = self.pinIn.file.value
    if self.data.useDefault then
      core_trafficSignals.loadSignals()
    elseif file then
      core_trafficSignals.loadSignals(file)
    end

    if core_trafficSignals.getValues().loaded then
      self.signalsData = {
        intersections = core_trafficSignals.getIntersections(),
        controllers = core_trafficSignals.getControllers(),
        signalMetadata = core_trafficSignals.getSignalMetadata()
      }
      self.pinOut.signalsData.value = self.signalsData
    else
      self:__setNodeError('signals', 'signals data loading failed')
    end
  end
end

return _flowgraph_createNode(C)