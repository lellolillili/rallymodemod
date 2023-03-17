-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'im Vehicle Selector'
C.description = 'Vehicle selector ui made in imgui'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'out', type = 'string', name = 'model', description = 'The model of the selected vehicle.' },
  { dir = 'out', type = 'string', name = 'config', description = 'The config of the selected vehicle.' },
}

C.tags = {}

function C:init()
end


function C:_executionStarted()
  self.models =  core_vehicles.getModelList(true).models
  self.configs = {}
  self.model = ""
  self.config = ""
  self.vehType = 'Car'
  self.modelName = ""
  self.configName = ""
  self.open = false
  self.done = false
  self.pinOut.flow.value = false
end

function C:drawMiddle(builder, style)
  builder:Middle()
end

function C:displayWindow()
  im.Begin("Vehicle Select##"..self.id, im.BoolPtr(true))
  im.Columns(2)
  if self.models == nil or next(self.models) == nil then
    im.Text("Model")
    im.NextColumn()
    im.Text(tostring(self.modelName))
    im.NextColumn()
    im.Text("Config")
    im.NextColumn()
    im.Text(tostring(self.configName))
    im.Columns(1)
    return
  end
  im.Text("Type")
  im.NextColumn()
  if im.BeginCombo("##vehType" .. self.id, self.vehType) then
    for _, t in ipairs({'Car','Truck','Prop','Trailer','Utility', 'Traffic'}) do
      if im.Selectable1(t, t == self.vehType) then
        if t ~= self.vehType then
          self.vehType = t
          self.model = ""
          self.modelName = ""
          self.config = ""
          self.configName = ""
        end
      end
    end
    im.EndCombo()
  end

  im.NextColumn()
  im.Text("Model")
  im.NextColumn()
  if im.BeginCombo("##models" .. self.id, self.model) then
    for _, m in ipairs(self.models) do
      if m.Type == self.vehType then
        if im.Selectable1(m.Name and (m.Name .. " ["..m.key.."]") or m.key, m.key == self.model) then
          if self.model ~= m.key then
            self.model = m.key
            self.modelName = m.Name
            self.configs = core_vehicles.getModel(m.key).configs
            self.config = ""
            self.configName = ""
          end
        end
      end
    end
    im.EndCombo()
  end
  im.Text(tostring(self.modelName))
  im.NextColumn()
  im.Text("Config")
  im.NextColumn()
  if self.configs and self.configs ~= {} then
    if im.BeginCombo("##configs" .. self.id, self.config) then
      for c, m in pairs(self.configs) do
        if im.Selectable1((m.Name .. " ["..c.."]"), c == self.config) then
          self.config = c
          self.configName = m.Name
          self.configPath = "vehicles/"..self.model.."/"..c..".pc"
        end
      end
      im.EndCombo()
    end
  end
  im.Text(tostring(self.configName))
  im.Columns(1)
  if im.Button("Select") then
    self.done = true
    self.open = false
    self.pinOut.config.value = self.configPath
    self.pinOut.model.value = self.model
    self.pinOut.flow.value = true
  end

  im.End()
end

function C:onNodeReset()
  self.open = false
end

function C:workOnce()
  self.open = true
end

function C:work()
  if self.open then
    self:displayWindow()
  end
end


return _flowgraph_createNode(C)
