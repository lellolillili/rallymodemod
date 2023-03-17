-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Vehicle Config Provider'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.behaviour = { simple = true }
C.description = [[Lets you easily select a configuration of vehicles.]]
C.category = 'provider'

C.pinSchema = {
  { dir = 'out', type = 'string', name = 'model', description = 'The model of the selected vehicle.' },
  { dir = 'out', type = 'string', name = 'config', description = 'The config of the selected vehicle.' },
  { dir = 'out', type = 'string', name = 'modelName', description = 'The model name of the selected vehicle.', hidden = true },
  { dir = 'out', type = 'string', name = 'configName', description = 'The config name of the selected vehicle.', hidden = true },

}

C.tags = {}

function C:init()
  self.models = {}
  self.configs = {}
  self.model = ""
  self.config = ""
  self.vehType = 'Car'
  self.modelName = ""
  self.configName = ""
end

function C:drawCustomProperties()
  local reason = nil
  reason = ui_flowgraph_editor.vehicleSelector(self)
  return reason
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text(tostring(self.modelName))
  im.Text(tostring(self.configName))

end

function C:work()
  self.pinOut.config.value = self.configPath
  self.pinOut.model.value = self.model
  self.pinOut.modelName.value = self.modelName
  self.pinOut.configName.value = self.configName
end

function C:_onSerialize(res)
  res.model = self.model
  res.config = self.config
  res.configPath = self.configPath
  res.vehType = self.vehType
  res.modelName = self.modelName
  res.configName = self.configName
end

function C:_onDeserialized(nodeData)
  self.model = nodeData.model
  self.config = nodeData.config
  self.configPath = nodeData.configPath
  self.vehType = nodeData.vehType
  self.modelName = nodeData.modelName
  self.configName = nodeData.configName
end

return _flowgraph_createNode(C)
