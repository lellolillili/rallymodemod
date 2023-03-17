-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Custom Parts Config Provider'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle

C.description = [[Lets you create a custom parts configuration for a vehicle.]]
C.category = 'provider'

C.pinSchema = {
  { dir = 'out', type = 'string', name = 'model', description = 'The model of the selected vehicle.' },
  { dir = 'out', type = 'table', tableType = 'vehicleConfig', name = 'config', description = 'The config of the selected vehicle.' },
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

  self.partConfig = {
    parts = {},
    vars = {}
  }
  self.sortedKeys = {
    parts = {},
    vars = {}
  }
end

function C:drawCustomProperties()
  local reason = nil
  if im.TreeNode2("Load from File","Load from File") then
    reason = ui_flowgraph_editor.vehicleSelector(self)
    if self.configPath then
      if im.Button("Load Config") then
        self.partConfig = jsonReadFile(self.configPath) or {parts = {},vars = {}}
        if not tableIsEmpty(self.partConfig.parts) then
          self.partConfig.partConfigFilename = self.configPath
        end
        self:sortKeys()
      end
    end
    im.TreePop()
  end

  if im.TreeNode2('cv',"Current Vehicle") then
    local veh = be:getPlayerVehicle(0)
    if veh then
      if string.endswith(veh.partConfig, ".pc") then
        im.Text("Part Config File: ")
        im.Text(veh.partConfig)
        if im.Button("Read from File") then
          self.partConfig = jsonReadFile(veh.partConfig) or {parts = {},vars = {}}
          if not tableIsEmpty(self.partConfig.parts) then
            self.partConfig.partConfigFilename = self.configPath
          end
          self.model = veh.JBeam
          self.modelName = veh.JBeam
          self.config = veh.partConfig
          self.configName = veh.partConfig
          if self.model then
            self.configs = core_vehicles.getModel(self.model).configs
          end
          self:sortKeys()
        end
      else
        if im.Button("Copy from Vehicle") then
          self.partConfig = deserialize(veh.partConfig) or {parts = {},vars = {}}
          self.model = veh.JBeam
          self.modelName = veh.JBeam
          self:sortKeys()
        end
        if im.Button("Copy only Parts") then
          self.partConfig.parts = deserialize(veh.partConfig).parts or {}
          self.model = veh.JBeam
          self.modelName = veh.JBeam
          self:sortKeys()
        end
        if im.Button("Copy only Vars") then
          self.partConfig.vars = deserialize(veh.partConfig).vars or {}
          self.model = veh.JBeam
          self.modelName = veh.JBeam
          self:sortKeys()
        end
        if not self._opened then
          im.ImGuiStorage_SetInt(im.GetStateStorage(),im.GetID1("Part Config Custom:"), 0)
        end
        if im.TreeNodeEx1("Part Config Custom:") then
          self._opened = true
          im.Text(dumps(deserialize(veh.partConfig)))
          im.TreePop()
        end
      end
    else
      im.Text("No Vehicle Selected.")
    end
    im.TreePop()
  end
  if self.partConfig ~= nil then
    im.Separator()
    self:showKVPairs("Parts","parts",'string')
    im.Separator()
    self:showKVPairs("Vars","vars",'number')
  end
  return reason
end

function C:showKVPairs(name, field, tpe)
  if im.TreeNode2(field..'tree',name..' ('..#self.sortedKeys[field]..' Items)') then
    if im.Button("Sort", im.ImVec2(im.GetContentRegionAvailWidth(),0)) then
      self:sortKeys()
    end
    im.Columns(2)
    local rem = nil
    for i, key in ipairs(self.sortedKeys[field]) do
      local keyText = im.ArrayChar(128, key)
      im.PushItemWidth(im.GetContentRegionAvailWidth())
      if im.InputText("##inputKeyPart" .. i .. field, keyText, nil, im.InputTextFlags_EnterReturnsTrue) then
        local oldVal = self.partConfig[field][old]
        self.sortedKeys[field][i] = ffi.string(keyText)
        self.partConfig[field][old] = nil
        self.partConfig[field][ffi.string(keyText)] = oldVal
      end
      im.NextColumn()
      im.PushItemWidth(im.GetContentRegionAvailWidth()-20)
      if tpe == 'string' then
        local valText = im.ArrayChar(128, self.partConfig[field][key])
        if im.InputText("##inputValPart" .. i ..field, valText, nil, im.InputTextFlags_EnterReturnsTrue) then
          self.partConfig[field][ffi.string(keyText)] = ffi.string(valText)
        end
      elseif tpe == 'number' then
        local valNum = im.FloatPtr(self.partConfig[field][key])
        if im.InputFloat("##inputValPart" .. i ..field, valNum, nil,nil,nil, im.InputTextFlags_EnterReturnsTrue) then
          self.partConfig[field][ffi.string(keyText)] = valNum[0]
        end
      end
      im.SameLine()
      if editor.uiIconImageButton(editor.icons.delete_forever,im.ImVec2(20, 20)) then
        rem = i
      end
      im.NextColumn()
    end
    if rem then
      self.partConfig.vars[self.sortedKeys[field][rem]] = nil
      for i = rem, #self.sortedKeys[field] do
        self.sortedKeys[field][i] = self.sortedKeys[field][i+1]
      end
    end
    im.Separator()
    self._keyText = self._keyText or im.ArrayChar(128, "")
    im.PushItemWidth(im.GetContentRegionAvailWidth())
    im.InputText("##AddKeyPart", self._keyText)
    im.NextColumn()
    im.PushItemWidth(im.GetContentRegionAvailWidth()-20)
    if tpe == 'string' then
      self._valText = self._valText or im.ArrayChar(128, "")
      im.InputText("##AddValPart", self._valText)
      im.SameLine()
      if editor.uiIconImageButton(editor.icons.add,im.ImVec2(20, 20)) then
        self.partConfig[field][ffi.string(self._keyText)] = ffi.string(self._valText)
        table.insert(self.sortedKeys[field], ffi.string(self._keyText))
        self._keyText = nil
        self._valText = nil
      end
    elseif tpe == 'number' then
      self._valNum = self._valNum or im.FloatPtr(0)
      im.InputFloat("##AddValPart", self._valNum)
      im.SameLine()
      if editor.uiIconImageButton(editor.icons.add,im.ImVec2(20, 20)) then
        self.partConfig[field][ffi.string(self._keyText)] = self._valNum[0]
        table.insert(self.sortedKeys[field], ffi.string(self._keyText))
        self._keyText = nil
        self._valNum = nil
      end
    end
    im.NextColumn()
    --im.PopItemWidth()
    im.Columns(1)
    im.TreePop()
  end
end

function C:sortKeys()
  local keys = {
    parts = {},
    vars = {}
  }
  for k,_ in pairs(self.partConfig.parts) do
    table.insert(keys.parts, k)
  end
  for k,_ in pairs(self.partConfig.vars) do
    table.insert(keys.vars, k)
  end
  table.sort(keys.parts)
  table.sort(keys.vars)
  self.sortedKeys = keys
  --dump(self.sortedKeys)
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text(tostring(self.modelName))
  im.Text(#self.sortedKeys.parts .. " Parts, " ..#self.sortedKeys.vars .. " Vars")
end

function C:work()
  self.pinOut.config.value = self.partConfig
  self.pinOut.model.value = self.model
end

function C:_onSerialize(res)
  res.model = self.model
  res.config = self.config
  res.configPath = self.configPath
  res.vehType = self.vehType
  res.modelName = self.modelName
  res.configName = self.configName
  res.partConfig = self.partConfig
end

function C:_onDeserialized(nodeData)
  self.model = nodeData.model
  self.config = nodeData.config
  self.configPath = nodeData.configPath
  self.vehType = nodeData.vehType
  self.modelName = nodeData.modelName
  self.configName = nodeData.configName
  self.partConfig = nodeData.partConfig or {
    parts = {},
    vars = {}
  }
  self:sortKeys()
end

return _flowgraph_createNode(C)
