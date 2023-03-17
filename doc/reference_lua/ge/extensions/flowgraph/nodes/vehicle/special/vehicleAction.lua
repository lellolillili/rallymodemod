-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Vehicle Action'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.behaviour = { duration = true }
C.description = [[Allows to call a vehicles action which is specified in the input_actions.json of a vehicle.]]
C.category = 'repeat_p_duration'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'The Id of the vehicle which will receive the lua action.' },
  { dir = 'in', type = 'number', name = 'val', description = 'VALUE that will be used for this action.' },
  { dir = 'in', type = 'number', name = 'inputFilter', hidden = true, default = 0, hardcoded = true, description = 'INPUTFILTER used for actions that use it.' },
  { dir = 'in', type = 'number', name = 'angle', hidden = true, default = 0, hardcoded = true, description = 'ANGLE used for actions that use it.' },
  { dir = 'in', type = 'flow', name = 'down', description = 'This simulates a key being pressed also known as the, "onDown" action.' },
  { dir = 'in', type = 'flow', name = 'change', description = 'onChange of action.' },
  { dir = 'in', type = 'flow', name = 'up', description = 'This simulates a key being pressed also known as the, "onUp" action.' },
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}
C.tags = {'destroy','funstuff'}

local vehicleActionMaps = {}

function C:init()
  self.models = {}
  self.model = ""
  self.vehType = 'Car'
  self.modelName = ""
  self.sortedActionNames = {}
  self.action = {
    none = true,
    title = "No Action"
  }

end

function C:loadActions(key, file)
  if vehicleActionMaps[key] then return end
  file = file or "vehicles/"..key.."/input_actions.json"
  local actions = readJsonFile(file) or {}
  local sorted = {}
  if actions then
    for name, act in pairs(actions) do
      if not act.ctx or act.ctx == 'vlua' then
        table.insert(sorted, name)
        if not act.title then act.title = name end
        act.fgSource = key
        act.origName = name
      end
    end
    table.sort(sorted, function(a,b) return actions[a].order < actions[b].order end)
  end
  vehicleActionMaps[key] = {
    actions = actions,
    sorted = sorted
  }
end



function C:drawCustomProperties()
  local reason = nil
  reason = ui_flowgraph_editor.vehicleSelector(self, true)
  if self.model and self.model ~= "" then
    if not vehicleActionMaps[self.model] then
      if im.Button("Load Actions") then
        self:loadActions(self.model)
      end
    else
      im.TextWrapped(#vehicleActionMaps[self.model].sorted .. " Actions loaded.")
    end
  else
    im.TextWrapped("Select a model to load vehicle specific actions.")
  end
  im.Separator()
  self:loadActions('allVehicles', "lua/ge/extensions/core/input/actions/vehicle.json")
  im.PushItemWidth(im.GetContentRegionAvailWidth())
  if im.BeginCombo("##transformMode" .. self.id, self.action.title, im.ComboFlags_HeightLarge) then
    local modelA, allA = vehicleActionMaps[self.model], vehicleActionMaps['allVehicles']
    if self.model and modelA then
      for i, name in ipairs(modelA.sorted) do
        local action = modelA.actions[name]
        if im.Selectable1(action.title, self.action == action) then
          self.action = action
        end
        im.tooltip(action.desc)
      end
      im.Separator()
    end
    for i, name in ipairs(allA.sorted) do
      local action = allA.actions[name]
      if im.Selectable1(action.title, self.action == action) then
        self.action = action
      end
      im.tooltip(action.desc)
    end
    im.EndCombo()
  end
  im.Separator()
  if im.TreeNode1("Action Info Detail") then
    im.Columns(2)
    im.Text("Name")
    im.NextColumn()
    im.TextWrapped(self.action.origName or "")
    im.NextColumn()

    im.Text("Title")
    im.NextColumn()
    im.TextWrapped(self.action.title or "")
    im.NextColumn()

    im.Text("Desc")
    im.NextColumn()
    im.TextWrapped(self.action.desc or "")
    im.NextColumn()

    im.Text("onDown")
    im.NextColumn()
    im.TextWrapped(self.action.onDown or "")
    im.NextColumn()

    im.Text("onChange")
    im.NextColumn()
    im.TextWrapped(self.action.onChange or "")
    im.NextColumn()

    im.Text("onUp")
    im.NextColumn()
    im.TextWrapped(self.action.onUp or "")
    im.NextColumn()

    im.Columns()
  end
  return reason
end



function C:formatCommand(cmd)
  local c = cmd:gsub("VALUE",tostring(self.pinIn.val.value or 0))
  c = c:gsub("FILTERTYPE",tostring(self.pinIn.inputFilter.value or 0))
  c = c:gsub("ANGLE",tostring(self.pinIn.angle.value or 0))
  return c
end

function C:work()
  local veh
  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  end
  if not veh then
    return
  end
  local str = ""
  if self.pinIn.down.value and self.action.onDown then
    veh:queueLuaCommand(self:formatCommand(self.action.onDown))
  end
  if self.pinIn.change.value and self.action.onChange then
    veh:queueLuaCommand(self:formatCommand(self.action.onChange))
  end
  if self.pinIn.up.value and self.action.onUp then
    veh:queueLuaCommand(self:formatCommand(self.action.onUp))
  end
end

function C:_onSerialize(res)
  res.model = self.model
  res.vehType = self.vehType
  res.modelName = self.modelName
  res.action = self.action
end

function C:_onDeserialized(nodeData)
  self.model = nodeData.model
  self.vehType = nodeData.vehType
  self.modelName = nodeData.modelName
  self.action = nodeData.action or {none = true, title = "No Action"}
end

return _flowgraph_createNode(C)
