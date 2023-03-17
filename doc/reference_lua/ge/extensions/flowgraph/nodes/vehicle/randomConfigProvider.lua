-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Random Config Provider'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.description = [[Gives you a random vehicle configuration from a selection.]]
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'out', type = 'string', name = 'model', description = 'The model of the selected vehicle.' },
  { dir = 'out', type = 'string', name = 'config', description = 'The config of the selected vehicle.' },
  { dir = 'out', type = 'string', name = 'name', description = 'The model name of the selected vehicle.', hidden = true },
  { dir = 'out', type = 'color', name = 'color', description = 'The model name of the selected vehicle.', hidden = true },
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


  return reason
end

function C:drawMiddle(builder, style)
  builder:Middle()

end

function C:_executionStarted()
  if self.options == nil then
    local vehs =  core_vehicles.getVehicleList().vehicles
    self.options = {}
    for _, v in ipairs(vehs) do
      if v.model.Type == 'Car' then
        local model = {
          model = v.model.key,
          configs = {},
          paints = tableKeys(tableValuesAsLookupDict(v.model.paints or {}))
        }
        for _, c in pairs(v.configs) do
          if c["Top Speed"] and c["Top Speed"] > 10 then
            table.insert(model.configs, {
              config = c.key,
              name = c.Name,
            })
          end
        end
        if #model.configs > 0 then
          table.insert(self.options, model)
        end
      end
    end
    --dump(self.options)
  end
end

function C:workOnce()
  local opt = self.options[math.floor(#self.options * math.random())+1]
  local cnf = opt.configs[math.floor(#opt.configs * math.random())+1]
  self.pinOut.config.value = cnf.config
  self.pinOut.model.value = opt.model
  self.pinOut.name.value = cnf.name
  --dump(opt.colors)
  if opt.paints and #opt.paints > 0 then
    self.pinOut.color.value = opt.paints[math.floor(#opt.paints * math.random())+1]
  else
    self.pinOut.color.value = nil
  end
end

function C:_onSerialize(res)

end

function C:_onDeserialized(nodeData)

end

return _flowgraph_createNode(C)
