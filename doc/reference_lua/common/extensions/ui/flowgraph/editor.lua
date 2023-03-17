-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local im = ui_imgui
if not flowGraphEditor_ffi_cdef_loaded then
  ffi.cdef(readFile('lua/common/extensions/ui/flowgraph/editor_api.h'))
  flowGraphEditor_ffi_cdef_loaded = true
end
require('/common/extensions/ui/flowgraph/editor_api')(M)

--print("EDITOR API LOADED")
M.flowgraphVersion = 0.2
-- 0.1: up until release april 2021
-- 0.2: changed to flat lists for graphs. need to adjust
-- custom


M.nodeColors = {
  ai = im.ImVec4(0.4, 0.9, 1.0, 0.9),
  debug = im.ImVec4(1, 0, 1, 0.75),
  vehicle = im.ImVec4(1, 0.4, 0, 0.75),
  event = im.ImVec4(1, 0, 0, 0.75),
  ui = im.ImVec4(0.23, 0.8, 0.32, 0.7),
  camera = im.ImVec4(0.63, 0.8, 0.32, 0.6),
  scene = im.ImVec4(0.3, 0.5, 0.75, 0.6),
  timeline = im.ImVec4(0.0, 0.0, 0.75, 0.6),
  tool = im.ImVec4(0.2, 1, 0.65, 0.9),
  default = im.ImVec4(0.55, 0.55, 0.55, 0.9),
  career = im.ImVec4(0.7, 0.6, 0.55, 0.9),
  sites = im.ImVec4(0.4, 0.9, 0.6, 0.9),
  traffic = im.ImVec4(0.45, 0.5, 0.7, 0.9),
  signals = im.ImVec4(0.4, 0.65, 0.75, 0.9),
  string = im.ImVec4(0.486, 0.0824, 0.6, 1),
  walking = im.ImVec4(0.586, 0.824, 0.4, 0.7),
  projectMacro = im.ImVec4(0.9, 1, 0.5, 1),
  state = im.ImVec4(0.8, 0.8, 1, 1), -- grayish white
  thread = im.ImVec4(0.5, 0.5, 1, 1), -- grayish white
  groupstate = im.ImVec4(0.5, 0.6, 1, 1), -- bluer-ish white
  button = im.ImVec4(0.1, 0.9, 0.5, 0.7), -- slight variation from the ui color
  timer = im.ImVec4(0.5, 0.9, 0.1, 0.7),
  file = im.ImVec4(0, 0.6, 1, 0.7),
}

M.nodeIcons = {
  vehicle = "simobject_bng_vehicle",
  ai = "adb",
  camera = "simobject_camera",
  walking = "directions_walk",
  ui = "fg_ui",
  event = "simobject_lightning",
  scene = "public",
  state = "developer_board",
  thread = "wifi",
  logic = "extension",
  traffic = "traffic",
  debug = "goat",
  button = "mouse",
  timer = "timer",
  file = 'save'
}

local typeColors = {
  ['flow'] = im.ImVec4(1, 1, 1, 1), -- white
  ['chainFlow'] = im.ImVec4(0.57, 0.83, 0.89, 1), -- light blue
  ['impulse'] = im.ImVec4(1, 0.85, 0.7, 1), -- orange
  ['string'] = im.ImVec4(0.486, 0.0824, 0.6, 1), -- purple
  ['number'] = im.ImVec4(0.576, 0.886, 0.29, 1), -- green
  ['bool'] = im.ImVec4(0.863, 0.188, 0.188, 1), -- red
  ['any'] = im.ImVec4(0.75, 0.75, 0.75, 1), -- white
  ['table'] = im.ImVec4(0.57, 0.83, 0.89, 1), -- light blue
  ['vec3'] = im.ImVec4(1, 1, 0.2, 1), -- yellwo
  ['quat'] = im.ImVec4(1, 0.6, 0.2, 1), -- orange
  ['color'] = im.ImVec4(0.2, 0.6, 1, 1), -- blue
  ['state'] = im.ImVec4(0.8, 0.8, 1, 1), -- blueish white

}
M.defaultTypeIconSize = 18
M.detaultIconType = "fg_type_circle"
local typeIcons = {
  -- Flow, Circle, Square, Grid, RoundSquare, Diamond
  ['flow'] = "fg_type_flow_constant",
  ['chainFlow'] = "fg_type_flow_constant",
  ['impulse'] = "fg_type_flow_impulse",
  ['number'] = "fg_type_circle",
  ['bool'] = "fg_type_circle",
  ['string'] = "fg_type_circle",
  ['table'] = "fg_type_grid",
  ['vec3'] = "fg_type_square",
  ['quat'] = "fg_type_square",
  ['color'] = "fg_type_square",
  ['any'] = "fg_type_round_square",
  ['state'] = "fg_type_diamond"
}

local fgIcons = {
  ''
}

local types = {}
for type, color in pairs(typeColors) do
  types[type] = { ['color'] = color }
  types[type].icon = typeIcons[type] or M.IconType_Circle
end

local graphTypes = {
  state = {
    name = "State",
    color = im.ImVec4(0.2, 0.2, 0.4, 1),
    tabColor = im.ImVec4(0.15, 0.15, 0.4, 1),
    tabHovered = im.ImVec4(0.4, 0.4, 0.75, 1),
    tabSelected = im.ImVec4(0.4, 0.4, 0.75, 1),
    tabUnfocused = im.ImVec4(0.15, 0.15, 0.4, 1),
    tabUnfocusedActive = im.ImVec4(0.25, 0.25, 0.6, 1),

    gridColor = im.ImVec4(0.4, 0.4, 1, 0.4),
    abbreviation = '[S]'
  },
  graph = {
    name = "Graph",
    color = im.ImVec4(1, 1, 1, 1),
    tabColor = im.ImVec4(1, 0.5, 0.5, 1),
    gridColor = im.ImVec4(0.5, 0.5, 0.5, 0.25),
    abbreviation = ''
  },
  macro = {
    name = "Macro",
    color = im.ImVec4(0.4, 0.6, 1, 1),
    tabColor = im.ImVec4(0, 0.25, 1.5, 1),
    gridColor = im.ImVec4(0.3, 0.6, 1, 0.25),
    abbreviation = '[M] '
  },
  instance = {
    name = "Instance",
    color = im.ImVec4(1, 0.5, 0.5, 1),
    tabColor = im.ImVec4(0.5, 1, 0.5, 1),
    gridColor = im.ImVec4(1, 0.25, 0.25, 0.25),
    abbreviation = '[I] '
  }
}

local lerpVec4 = function(a, b, t)
  return im.ImVec4(a.x * t + b.x * (1 - t), a.y * t + b.y * (1 - t), a.z * t + b.z * (1 - t), a.w * t + b.w * (1 - t))
end
-- some style setup
for g, info in pairs(graphTypes) do
  info.tabColor = info.tabColor or lerpVec4(info.color, im.ImVec4(1, 1, 1, 1), 0.4)
  info.tabHovered = info.tabHovered or lerpVec4(info.color, im.ImVec4(1, 1, 1, 1), 0.7)
  info.tabSelected = info.tabSelected or lerpVec4(info.color, im.ImVec4(1, 1, 1, 1), 0.6)
  info.tabUnfocused = info.tabUnfocused or lerpVec4(info.color, im.ImVec4(0, 0, 0, 1), 0.6)
  info.tabUnfocusedActive = info.tabUnfocusedActive or lerpVec4(info.color, im.ImVec4(0, 0, 0, 1), 0.4)
  --im.SetStyle(stle)
end

local function getSimpleTypes()
  return { 'number', 'bool', 'string', 'vec3', 'quat', 'color' }
end

local function getTypes()
  return types
end

local function tooltip(message)
  if editor_flowgraphEditor.allowTooltip then
    if im.IsItemHovered() then
      im.BeginTooltip()
      im.Text(message)
      im.EndTooltip()
    end
  end
end

local function getTypeColor(dataType)
  return typeColors[dataType] or im.ImVec4(0.45, 0.35, 0.1, 1) -- brown
end

local function getTypeIcon(dataType)
  return typeIcons[dataType] or M.detaultIconType
end

local function getGraphTypes()
  return graphTypes
end

local function shortValueString(value, tpe)
  if value == nil then
    return ("(nil)")
  end
  if tpe == nil or type(tpe) == 'table' or tpe == 'any' then
    -- guess type
    if type(value) == 'bool' or type(value) == 'string' or type(value) == 'number' then
      tpe = type(value)
    elseif type(value) == 'table' then
      if #value == 3 then
        tpe = 'vec3'
      elseif #value == 4 then
        tpe = 'quat'
      end
    else
      tpe = 'string' -- treat as generic usin "tostring"
    end
  end

  if tpe == 'flow' then
    return (value and "Flowing" or "Not Flowing")
  elseif tpe == 'string' or tpe == 'bool' then
    return (tostring(value):sub(0, 10) .. (tostring(value):len() > 10 and "..." or ""))
  elseif tpe == 'number' then
    return (string.format("%0.2f", value))
  elseif tpe == 'vec3' then
    return (string.format("{%0.1f, %0.1f, %0.1f}", value[1], value[2], value[3]))
  elseif tpe == 'quat' then
    return (string.format("{%0.1f, %0.1f, %0.1f, %0.1f}", value[1], value[2], value[3], value[4]))
  elseif tpe == 'color' then
    return (string.format("{%0.1f, %0.1f, %0.1f, %0.1f}", value[1], value[2], value[3], value[4]))
  end
  return "???"
end

local function shortDisplay(value, tpe)
  if value == nil then
    im.Text("nil")
    return
  end
  if tpe == 'color' then
    local clr = im.ImVec4(value[1], value[2], value[3], value[4])
    editor.uiIconImageButton(editor.icons.stop, im.ImVec2(20, 20), clr, nil, clr)
    im.SameLine()
  end
  im.Text(M.shortValueString(value, tpe))
end

local function fullValueString(value, tpe)
  if value == nil then
    return ("nil")
  end
  if tpe == nil or type(tpe) == 'table' or tpe == 'any' then
    -- guess type
    if type(value) == 'bool' or type(value) == 'string' or type(value) == 'number' then
      tpe = type(value)
    elseif type(value) == 'table' then
      if #value == 3 then
        tpe = 'vec3'
      elseif #value == 4 then
        tpe = 'quat'
      end
    else
      tpe = 'string' -- treat as generic usin "tostring"
    end
  end

  if tpe == 'flow' then
    return (value and "Flowing" or "Not Flowing")
  elseif tpe == 'string' or tpe == 'bool' then
    return (tostring(value))
  elseif tpe == 'number' then
    return (string.format("%f", value))
  elseif tpe == 'vec3' then
    return (string.format("{%f, %f, %f}", value[1], value[2], value[3]))
  elseif tpe == 'quat' then
    return (string.format("{%f, %f, %f, %f}", value[1], value[2], value[3], value[4]))
  elseif tpe == 'color' then
    return (string.format("{%f, %f, %f, %f}", value[1], value[2], value[3], value[4]))
  end
  return "???"
end

local function fullDisplay(value, tpe)
  if value == nil then
    im.Text("nil")
    return
  end
  if tpe == 'color' then
    local clr = im.ImVec4(value[1], value[2], value[3], value[4])
    editor.uiIconImageButton(editor.icons.stop, im.ImVec2(20, 20), clr, nil, clr)
    im.SameLine()
  end
  im.Text(M.fullValueString(value, tpe))
end

local function variableEditor(source, name, displayOptions)
  local variable = source:getFull(name)
  if not variable then
    im.Text("Variable " .. tostring(name) .. " not found!")
    return
  end
  -- setup display options.
  if not displayOptions then
    displayOptions = {}
  end
  displayOptions.global = displayOptions.global or false
  if displayOptions.allowEditing == nil then
    displayOptions.allowEditing = source.mgr.allowEditing
  end

  im.PushID1("VariablesColumns")
  local totalWidth = im.GetContentRegionAvailWidth()

  local textSize = im.GetCursorPosX()
  if displayOptions.onlyValue then
    im.Text(name)
  else
    im.Text("Value")
  end
  im.SameLine()
  local textSize = im.GetCursorPosX() - textSize

  --local global = self.global
  --local target  = self.global and self.mgr.variables or self.graph.variables

  im.PushItemWidth(totalWidth - 80 - textSize)
  if variable.type == 'string' then
    local imVal = im.ArrayChar(2048, displayOptions.allowEditing and variable.baseValue or variable.value)
    if im.InputText("##input" .. name, imVal, nil, im.InputTextFlags_EnterReturnsTrue) then
      if displayOptions.allowEditing then
        source:changeBase(name, ffi.string(imVal))
        source.mgr.fgEditor.addHistory("Changed Variable " .. name)
      else
        source:changeInstant(name, ffi.string(imVal))
      end
    end
  elseif variable.type == 'number' then
    local imVal = im.FloatPtr(displayOptions.allowEditing and variable.baseValue or variable.value)
    if im.InputFloat("##input" .. name, imVal, nil, nil, nil, im.InputTextFlags_EnterReturnsTrue) then
      if displayOptions.allowEditing then
        source:changeBase(name, imVal[0])
        source.mgr.fgEditor.addHistory("Changed Variable " .. name)
      else
        source:changeInstant(name, imVal[0])
      end
    end
  elseif variable.type == 'bool' then
    local imVal = im.BoolPtr(false)
    if displayOptions.allowEditing then
      imVal[0] = variable.baseValue
    else
      imVal[0] = variable.value
    end
    if im.Checkbox("##input" .. name, imVal) then
      if displayOptions.allowEditing then
        source:changeBase(name, imVal[0])
        source.mgr.fgEditor.addHistory("Changed Variable " .. name)
      else
        source:changeInstant(name, imVal[0])
      end
    end
  elseif variable.type == 'vec3' then
    local imVal = im.ArrayFloat(3)
    local val = displayOptions.allowEditing and variable.baseValue or variable.value
    imVal[0] = im.Float(val[1])
    imVal[1] = im.Float(val[2])
    imVal[2] = im.Float(val[3])
    if im.InputFloat3("##input" .. name, imVal, nil, im.InputTextFlags_EnterReturnsTrue) then
      local tbl = { imVal[0], imVal[1], imVal[2] }
      if displayOptions.allowEditing then
        source:changeBase(name, tbl)
        source.mgr.fgEditor.addHistory("Changed Variable " .. name)
      else
        source:changeInstant(name, tbl)
      end
    end
  elseif variable.type == 'quat' then
    local imVal = im.ArrayFloat(4)
    local val = displayOptions.allowEditing and variable.baseValue or variable.value
    imVal[0] = im.Float(val[1])
    imVal[1] = im.Float(val[2])
    imVal[2] = im.Float(val[3])
    imVal[3] = im.Float(val[4])
    if im.InputFloat4("##input" .. name, imVal, nil, im.InputTextFlags_EnterReturnsTrue) then
      local tbl = { imVal[0], imVal[1], imVal[2], imVal[3] }
      if displayOptions.allowEditing then
        source:changeBase(name, tbl)
        source.mgr.fgEditor.addHistory("Changed Variable " .. name)
      else
        source:changeInstant(name, tbl)
      end
    end
  elseif variable.type == 'color' then
    local imVal = im.ArrayFloat(4)
    local val = displayOptions.allowEditing and variable.baseValue or variable.value
    imVal[0] = im.Float(val[1])
    imVal[1] = im.Float(val[2])
    imVal[2] = im.Float(val[3])
    imVal[3] = im.Float(val[4])
    if im.ColorEdit4("##input" .. name, imVal, nil, im.InputTextFlags_EnterReturnsTrue) then
      local tbl = { imVal[0], imVal[1], imVal[2], imVal[3] }
      if displayOptions.allowEditing then
        source:changeBase(name, tbl)
        source.mgr.fgEditor.addHistory("Changed Variable " .. name)
      else
        source:changeInstant(name, tbl)
      end
    end
  end
  im.SameLine()
  im.SetCursorPosX(totalWidth - 22 * im.uiscale[0])
  if editor.uiIconImageButton(editor.icons.settings, im.ImVec2(22, 22)) then
    im.OpenPopup(source.id .. "-" .. name)
  end
  im.PopItemWidth()
  if im.BeginPopup(source.id .. "-" .. name) then
    im.PushItemWidth(100)
    if not displayOptions.onlyValue then

      if displayOptions.allowEditing then

        -- type
        if not variable.fixedType then
          im.Text("Type")
          im.SameLine()
          if im.BeginCombo("##type" .. variable.index .. name, variable.type) then
            for _, type in ipairs(source:getTypes()) do
              source.mgr:DrawTypeIcon(type.name, true, 1)
              im.SameLine()
              if im.Selectable1(type.name, type.name == variable.type) then
                source:updateType(name, type.name)
                source.mgr.fgEditor.addHistory("Changed Variable " .. name .. " type to " .. type.name)
              end
            end
            im.EndCombo()
          end
        else
          im.Text("Locked Type")
          ui_flowgraph_editor.tooltip("Type Locked (viewmode to debug to change)")
          im.SameLine()
          im.Text(tostring(variable.type))
        end
        if editor.getPreference("flowgraph.debug.editorDebug") then
          local fixedTypeBool = im.BoolPtr(variable.fixedType or false)
          if im.Checkbox("##fix" .. name, fixedTypeBool) then
            source:setFixedType(name, fixedTypeBool[0])
            source.mgr.fgEditor.addHistory("Fixed Variable type " .. name)
          end
        end

        if editor.getPreference("flowgraph.debug.editorDebug") then
          im.Text("Merging")
          ui_flowgraph_editor.tooltip("Dictates what happens when multiple values will be set in the same frame.")
          im.SameLine()
          -- merge strategies
          if im.BeginCombo("##mergeStrat" .. variable.index .. name, variable.mergeStrat) then
            for _, strat in ipairs(source:getMergeStrats(variable.type)) do
              if im.Selectable1(strat.name, variable.mergeStrat == strat.name) then
                source:setMergeStrat(name, strat.name)
                source.mgr.fgEditor.addHistory("Changed Variable " .. name .. " mergestrat to " .. strat.name)
              end
            end
            im.EndCombo()
          end

        end

      end
      if editor.getPreference("flowgraph.debug.editorDebug") then
        im.Text("Monitor")
        im.SameLine()
        local monitor = im.BoolPtr(variable.monitored or false)
        if im.Checkbox("##monitor" .. name, monitor) then
          source:setMonitor(name, monitor[0])
          source.mgr.fgEditor.addHistory("Changed Monitoring of " .. name)
        end
        ui_flowgraph_editor.tooltip("Checking this will show this variable in the Tool Window.")

        im.Text("KeepAfterStop")
        im.SameLine()
        local stop = im.BoolPtr(variable.keepAfterStop or false)
        if im.Checkbox("##keepAfterStop" .. name, stop) then
          source:setKeepAfterStop(name, stop[0])
          source.mgr.fgEditor.addHistory("Changed KeepAfterStop " .. name)
        end
        ui_flowgraph_editor.tooltip("Checking this will keep the variables value after stopping the execution, instead of resetting to its base value.")

        im.Text("Activity Attempt")
        local attemptTooltip = "If this flowgraph is used with Activiy nodes and this checkbox is enabled, this variable will be stored as part of the Activity attempts (see Tools > Activity Manager)"
        if im.IsItemHovered() then
          im.BeginTooltip()
          im.Text(attemptTooltip)
          im.EndTooltip()
        end
        im.SameLine()
        local activityAttemptData = im.BoolPtr(variable.activityAttemptData or false)
        if im.Checkbox("##activityAttemptData" .. name, activityAttemptData) then
          source:setActivityAttemptData(name, activityAttemptData[0])
          source.mgr.fgEditor.addHistory("Changed activityAttemptData " .. name)
        end
        ui_flowgraph_editor.tooltip(attemptTooltip)

      end

      if displayOptions.allowDelete then
        if source.mgr.allowEditing then
          -- delete
          if not variable.undeletable and im.Button("Delete Variable") then
            source:removeVariable(name)
            source.mgr.fgEditor.addHistory("Deleted Variable " .. name)
          end
        end
      end
    end
    im.EndPopup()
  end
  --im.NextColumn()
  --im.Columns(1)
  im.PopID()
end

local function vehicleSelectorRefresh(self, onlyModel)
  self.modelName = ""
  if self.models and self.model then
    for _, m in ipairs(self.models) do
      if m.key == self.model then
        self.modelName = dumps(m.Name)
      end
    end
  end

  self.configName = ""
  if self.model and self.config and self.configs then
    self.configs = core_vehicles.getModel(self.model).configs
    -- non-indexed table has to be wrapped, to be able to iterate in sorted order later
    local sortedConfigs = { }
    for k, v in pairs(self.configs) do
      table.insert(sortedConfigs, { key = k, value = v })
    end
    table.sort(sortedConfigs, function(c1, c2)
      return (c1.value.Name or "") < (c2.value.Name or "")
    end)
    self.configs = sortedConfigs
    for _, m in ipairs(self.configs) do
      if m.key == self.config then
        self.configName = dumps(m.value.Name)
      end
    end
  end
end

local uniqueIdCounter = 0
local function vehicleSelector(self, onlyModel)
  local reason = nil
  if not self._imguiId then
    self._imguiId = uniqueIdCounter .. "_childVehicleSelector"
    uniqueIdCounter = uniqueIdCounter + 1
  end
  self.model = self.model or ""
  self.config = self.config or ""
  self.vehType = self.vehType or 'Car'
  self.modelName = self.modelName or ""
  self.configName = self.configName or ""
  local availWidth = im.GetContentRegionAvailWidth()
  local scale = editor.getPreference("ui.general.scale")
  local spacing, elemHeight = 0, im.GetFrameHeightWithSpacing()
  local elemCount = 3
  local height = elemCount * elemHeight + (elemCount - 2) * spacing

  im.BeginChild1(self._imguiId, im.ImVec2(-1, height), false, im.WindowFlags_NoScrollWithMouse)
  if self.models == nil or next(self.models) == nil then
    if im.Button("Load Models and Configs") then
      self.models = core_vehicles.getModelList(true).models
      table.sort(self.models, function(m1, m2)
        return (m1.Name or "") < (m2.Name or "")
      end)
      if not onlyModel then
        if self.model and self.model ~= "" then
          local mdl = core_vehicles.getModel(self.model)
          if mdl then
            self.modelName = dumps(mdl.model.Name)
            self.configs = mdl.configs
            if self.configs[self.config] then
              self.configName = self.configs[self.config].Name or ""
            end
          end
        end
      end
    end
  end
  im.Columns(2)
  im.SetColumnWidth(0, 60)
  if self.models == nil or next(self.models) == nil then
    im.Text("Model")
    im.NextColumn()
    if self.modelName and self.modelName ~= "" then
      im.Text(tostring(self.modelName))
    elseif self.model and self.model ~= "" then
      im.Text(tostring(self.model))
    else
      im.Text(tostring("No Model Selected"))
    end
    im.NextColumn()
    if not onlyModel then
      im.Text("Config")
      im.NextColumn()
      if self.configName and self.configName ~= "" then
        im.Text(tostring(self.configName))
      elseif self.config and self.config ~= "" then
        im.Text(tostring(self.config))
      else
        im.Text(tostring("No Config Selected"))
      end
    end
    im.Columns(1)
  else
    im.Text("Type")
    im.NextColumn()
    im.PushItemWidth(im.GetContentRegionAvailWidth())
    if im.BeginCombo("##vehType" .. dumps(self.id), self.vehType) then
      for _, t in ipairs({ 'Car', 'Truck', 'Prop', 'Trailer', 'Utility', 'Traffic' }) do
        if im.Selectable1(t, t == self.vehType) then
          if t ~= self.vehType then
            self.vehType = t
            self.model = ""
            self.modelName = ""
            if not onlyModel then
              self.config = ""
              self.configName = ""
            end
            reason = "Changed Type to " .. t
          end
        end
      end
      im.EndCombo()
    end

    im.NextColumn()
    im.Text("Model")
    im.NextColumn()
    im.PushItemWidth(im.GetContentRegionAvailWidth())
    if im.BeginCombo("##models" .. dumps(self.id), self.modelName .. " [" .. self.model .. "]") then
      for _, m in ipairs(self.models) do
        if m.Type == self.vehType then
          if im.Selectable1(m.Name and (m.Name .. " [" .. m.key .. "]") or m.key, m.key == self.model) then
            if self.model ~= m.key then
              self.model = m.key
              self.modelName = dumps(m.Name)
              if not onlyModel then
                self.configs = core_vehicles.getModel(m.key).configs
                -- non-indexed table has to be wrapped, to be able to iterate in sorted order later
                local sortedConfigs = { }
                for k, v in pairs(self.configs) do
                  table.insert(sortedConfigs, { key = k, value = v })
                end
                table.sort(sortedConfigs, function(c1, c2)
                  return (c1.value.Name or "") < (c2.value.Name or "")
                end)
                self.configs = sortedConfigs
                self.config = ""
                self.configName = ""
              end
              reason = "Changed Model to " .. dumps(m.Name)
            end
          end
        end
      end
      im.EndCombo()
    end
    im.NextColumn()
    if not onlyModel then
      im.Text("Config")
      im.NextColumn()
      if self.configs and self.configs ~= {} then
        im.PushItemWidth(im.GetContentRegionAvailWidth())
        if im.BeginCombo("##configs" .. dumps(self.id), self.configName .. " [" .. self.config .. "]") then
          for _, m in ipairs(self.configs) do
            if im.Selectable1((dumps(m.value.Name) .. " [" .. m.key .. "]"), m.key == self.config) then
              self.config = m.key
              self.configName = dumps(m.value.Name)
              self.configPath = "vehicles/" .. self.model .. "/" .. m.key .. ".pc"
              reason = "Changed Vehicle to " .. dumps(m.value.Name)
            end
          end
          im.EndCombo()
        end
      end
    end

  end
  im.NextColumn()
  im.Columns(1, "aasdf")
  im.EndChild()
  return reason
end

local function isFunctionalNode(category)
  return category == 'repeat_instant'
          or category == 'once_instant'
          or category == 'dynamic_instant'
          or category == 'repeat_p_duration'
          or category == 'once_p_duration'
          or category == 'dynamic_p_duration'
          or category == 'repeat_f_duration'
          or category == 'once_f_duration'
          or category == 'dynamic_f_duration'
          or category == 'simple'
          or category == 'provider'
end

local function isSimpleNode(category)
  return category == 'simple'
          or category == 'provider'
end

local function isDurationNode(category)
  return category == 'repeat_p_duration'
          or category == 'once_p_duration'
          or category == 'dynamic_p_duration'
          or category == 'repeat_f_duration'
          or category == 'once_f_duration'
          or category == 'dynamic_f_duration'
end

local function isF_DurationNode(category)
  return category == 'repeat_f_duration'
          or category == 'once_f_duration'
          or category == 'dynamic_f_duration'
end

local function isOnceNode(category)
  return category == 'once_instant'
          or category == 'once_p_duration'
          or category == 'once_f_duration'
end

local function isDynamicNode(category)
  return category == 'dynamic_instant'
          or category == 'dynamic_p_duration'
          or category == 'dynamic_f_duration'
end

local behaviourIcons = { once = "refresh", duration = "hourglass_empty", simple = "widgets", singleActive = "error_outline", obsolete = "timer_off" }
local behaviourDescription = { once = "This node only provides its functionality once, then has to be reset.",
                               duration = "This node takes longer than one frame to provide its functionality.",
                               simple = "This node does not require flow to function.",
                               singleActive = "There should be only one active instance of this nodetype at a time.",
                               obsolete = "This node is obsolete, it might not work properly." }

local function getBehaviourIcon(behaviour)
  return behaviourIcons[behaviour]
end

local function getBehaviourDescription(behaviour)
  return behaviourDescription[behaviour]
end

local function getAutoTypeFromName(name)
  local n = string.lower(name)
  if string.endswith(n, "pos") or
          string.startswith(n, "pos") or
          string.endswith(n, "scl") or
          string.startswith(n, "scl") or
          string.endswith(n, "vec") or
          string.startswith(n, "vec") or
          string.endswith(n, "vec3") or
          string.startswith(n, "vec3") or
          string.find(n, "position") or
          string.find(n, "scale") or
          string.find(n, "vector")
  then
    return "vec3"
  elseif
  string.endswith(n, "rot") or
          string.startswith(n, "rot") or
          string.endswith(n, "quat") or
          string.startswith(n, "quat") or
          string.find(n, "rotation") or
          string.find(n, "quaternion") or
          string.find(n, "orientation")
  then
    return "quat"
  elseif
  string.endswith(n, "clr") or
          string.startswith(n, "clr") or
          string.find(n, "color")
  then
    return "color"
  elseif
  string.endswith(n, "rot") or
          string.startswith(n, "rot") or
          string.endswith(n, "quat") or
          string.startswith(n, "quat") or
          string.find(n, "rotation") or
          string.find(n, "quaternion") or
          string.find(n, "orientation")
  then
    return "quat"
  elseif
  string.endswith(n, "num") or
          string.startswith(n, "num") or
          string.endswith(n, "id") or
          string.find(n, "number") or
          string.find(n, "amount") or
          string.find(n, "score") or
          string.find(n, "count") or
          string.find(n, "time") or
          string.find(n, "duration") or
          string.find(n, "length") or
          string.find(n, "distance") or
          string.find(n, "dist") or
          string.find(n, "points") or
          string.find(n, "threshold") or
          string.find(n, "velocity")
  then
    return "number"
  elseif
  string.find(n, "bool") or
          string.find(n, "enabled") or
          string.find(n, "disabled") or
          string.find(n, "contains") or
          string.startswith(n, "has") or
          string.startswith(n, "uses") or
          string.startswith(n, "with")
  then
    return "bool"
  else
    return "string"
  end
end
M.vehicleSelectorRefresh = vehicleSelectorRefresh
M.vehicleSelector = vehicleSelector
M.shortDisplay = shortDisplay
M.shortValueString = shortValueString
M.fullDisplay = fullDisplay
M.fullValueString = fullValueString

M.variableEditor = variableEditor

M.getSimpleTypes = getSimpleTypes
M.getTypes = getTypes
M.getTypeColor = getTypeColor
M.getGraphTypes = getGraphTypes
M.getTypeIcon = getTypeIcon
M.tooltip = tooltip

M.isFunctionalNode = isFunctionalNode
M.isSimpleNode = isSimpleNode
M.isDurationNode = isDurationNode
M.isF_DurationNode = isF_DurationNode
M.isOnceNode = isOnceNode
M.isDynamicNode = isDynamicNode
M.getBehaviourIcon = getBehaviourIcon
M.getBehaviourDescription = getBehaviourDescription

M.getAutoTypeFromName = getAutoTypeFromName

return M
