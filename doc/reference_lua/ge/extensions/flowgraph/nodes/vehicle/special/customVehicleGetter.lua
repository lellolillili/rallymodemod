-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Get Custom Vehicle Value'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.description = 'Gets a custom value from a vehicle. Outflow is delayed for a few frame.'
C.behaviour = { duration = true, once = true }
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'reset', description = 'Resets this node.', impulse = true },
  { dir = 'in', type = 'number', name = 'VehId', description = 'ID of the vehicle. If empty, the Player vehicle will be used' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
  { dir = 'out', type = 'any', name = 'value', description = 'Returns the requested value, raw.' },
  { dir = 'out', type = 'bool', name = 'valBool', description = 'Converts the requested value into a boolean, if a number: 0 to false, 1 to true' },
}

C.tags = {}

local functions = {
    {
      name = "Ignition",
      description = "Returns the ignition status.",
      fun = "electrics.values.ignition"
    },
    {
      name = "Hazard Light",
      description = "Returns the hazard light status.",
      fun = "electrics.values.hazard_enabled"
    },
  }

function C:init()
  self.data.fun = functions[1].fun
end

function C:drawCustomProperties()
  local reason = nil
  im.Text("Mode: ")
  im.SameLine()
  im.PushItemWidth(im.GetContentRegionAvailWidth())
  local currentFun = "Custom Function"
  for _, f in ipairs(functions) do
    if f.fun == self.data.fun then
      currentFun = f.name
    end
  end
  if im.BeginCombo("##currentFunc" .. self.id, currentFun) then
    for _, fun in ipairs(functions) do
      if im.Selectable1(fun.name, fun.fun == self.data.fun) then
        self.data.fun = fun.fun
        self._cdata = nil
        reason = "Changed function to " .. fun.name
      end
      ui_flowgraph_editor.tooltip(fun.description or "")
    end
    im.EndCombo()
  end
  return reason
end

function C:work()
  self.pinOut.flow.value = false
  local veh
  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end
  if not veh then
    return
  end
  if self.pinIn.reset.value then
    self.done = nil
  end
  if not self.done then
    veh:queueLuaCommand(self:getCmd())
    self.done = true
  end
  if self.returnedValue ~= nil then
    self.pinOut.flow.value = true
    self.pinOut.value.value = self.returnedValue

    if type(self.returnedValue) == 'number' then
      self.pinOut.valBool.value = self.returnedValue ~= 0
    else
      self.pinOut.valBool.value = nil
    end
  end
end

function C:_executionStarted()
  self.returnedValue = nil
  self.done = nil
end

function C:getCmd()
  return 'obj:queueGameEngineLua("core_flowgraphManager.getManagerByID('..self.mgr.id..').graphs['..self.graph.id..'].nodes['..self.id..']:returnValue(\'"..serialize('..self.data.fun..').."\')")'
end

function C:returnValue(value)
  self.returnedValue = deserialize(value)
end

return _flowgraph_createNode(C)
