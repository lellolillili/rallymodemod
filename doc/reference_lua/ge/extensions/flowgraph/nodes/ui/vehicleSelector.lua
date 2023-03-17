-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Vehicle Selector'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.description = "Lets the player select from every vehicle in the game."
C.todo = "Showing two of these at the same time will break everything."
C.behaviour = {singleActive = true}
C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.'},
  {dir = 'in', type = 'flow', name = 'reset', description = 'Resets this node.'},
  {dir = 'in', type = 'flow', name = 'clearVeh', description = 'Clears the selected vehicle'},
  {dir = 'in', type = 'string', name = 'title', description = 'Title.'},
  {dir = 'in', type = {'string','table'}, tableType = 'multiTranslationObject', name = 'text', description = 'Subtext of the menu.'},
  {dir = 'in', type = 'string', name = 'start', description= 'Text for the start button.', hidden=true},
  {dir = 'in', type = 'string', name = 'exit', description= 'Text for the exit button. If no value is given, then the button will be hidden.', hidden=true},
  {dir = 'in', type = 'string', name = 'selectionText', description= 'Text for the selection button. If no value is gived, button will show "Select Vehicle"', hidden=true},
  --{dir = 'in', type = 'string', name = 'model', description= 'Default model to show in the selector.'},
  --{dir = 'in', type = 'string', name = 'config', description= 'Default config to show in the selector.'},

  {dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.'},
  {dir = 'out', type = 'flow', name = 'exit', description = 'Flows when the exit button is pressed.'},
  {dir = 'out', type = 'flow', name = 'ready', description = 'Flows immediately after a vehicle is selected.'},
  {dir = 'out', type = 'flow', name = 'selected', impulse = true, hidden = true, description = 'Sends a pulse after a vehicle is selected.'},
  {dir = 'out', type = 'string', name = 'model', description= 'The model of the selected vehicle.'},
  {dir = 'out', type = 'string', name = 'config', description= 'The config of the selected vehicle.'},
  {dir = 'out', type = 'string', name = 'color', description= 'The color of the selected vehicle.'},
}
C.dependencies = {'core_input_bindings'}

function C:init()
  self.open = false
  self.done = false
  self.selected = false
end

function C:_executionStarted()
  for _, p in pairs(self.pinOut) do
    p.value = false
  end
  self.open = false
  self.done = false
  self.selected = false
  self._active = false
  self._selectedFullData = nil
  self._selectedVehData = nil
end

function C:_executionStopped()
  if self.open then
    self:closeDialogue()
  end
  self:reset()
  self._selectedFullData = nil
  self._selectedVehData = nil
end

function C:reset()
  self.done = false
  self.open = false
  self.selected = false
  self._active = false
end

function C:buttonPushed(action)
  for nm, pn in pairs(self.pinOut) do
    self.pinOut[nm].value = nm == action
  end
end

function C:getCmd(action)
  return 'core_flowgraphManager.getManagerByID('..self.mgr.id..').graphs['..self.graph.id..'].nodes['..self.id..']:buttonPushed("'..action..'")'
end

function C:closeDialogue()
  --core_gamestate.setGameState('freeroam', 'freeroam', 'freeroam')
  guihooks.trigger('MenuHide')
  guihooks.trigger('ChangeState', 'menu')
  self.open = false
  self._active = false
end

function C:onVehicleSelectedInitially(vehData, fullData)
  self._selectedVehData = vehData
  self._selectedFullData = fullData
end

function C:onVehicleSelected(vehData, fullData)
  --dump("selected vehicle: ")
  --dump(vehData)
  --dump(fullData)
  self._selectedVehData = vehData
  self._selectedFullData = fullData
  self.pinOut.ready.value = true
  self.selected = true
end

function C:attemptFillFullData()
  -- TODO: fill data with user selection from pins
end

function C:openDialogue()
  self.open = true

  local data = {}
  --data.showDataImmediately = true
  data.introType = 'selectableVehicle'
  data.description = self.pinIn.text.value or ""
  data.name = self.pinIn.title.value or ""
  data.portraitText = data.description
  data.portraitImg = {}
  data.portraitImg.start = self.pinIn.portraitImg.value or nil
  data.callObj = 'core_flowgraphManager.getManagerByID('..self.mgr.id..').graphs['..self.graph.id..'].nodes['..self.id..']'
  data.readyHook = data.callObj .. ':started()'
  data.exitHook = data.callObj .. ':exited()'
  data.selectionText = self.pinIn.selectionText.value or "ui.quickrace.selectVehicle"
  data.buttonText = self.pinIn.start.value
  data.exitButtonText = self.pinIn.exit.value
  --if self.pinIn.config.value and self.pinIn.model.value then
  --  local _, configFn, _ = path.splitWithoutExt(self.pinIn.config.value)
  --  data.vehicle = {
  --    model = self.pinIn.model.value,
  --    config = configFn
  --  }
  --end
  if self._selectedFullData == nil then
    self:attemptFillFullData()
  end
  data.vehicle = self._selectedFullData
  --{{label='ui.common.retry', cmd='scenario_scenarios.uiEventRetry()', active = scenario.result.failed}, {label='ui.scenarios.end.freeroam', cmd='scenario_scenarios.uiEventFreeRoam()'}, {label='ui.common.menu', cmd='openMenu'}, {label='ui.quickrace.changeConfig', cmd='openLightRunner'}}
  --if core_input_bindings.isMenuActive then guihooks.trigger('MenuItemNavigation', 'toggleMenues') end
  self._storedData = data
  self._active = true
  guihooks.trigger('ChangeState', {state = 'scenario-start', params = {data = data}})
end

function C:onScenarioUIReady(state)
  if self._active then
    guihooks.trigger('ScenarioChange',  self._storedData);
  end
end

function C:closed()
  self.done = true
  self._active = false
end

function C:started()
  self:closeDialogue()
  self.pinOut.flow.value = true
  self.done = true
  self._active = false
end


function C:exited()
  self:closeDialogue()
  self.pinOut.exit.value = true
  self.done = true
  self._active = false
end

function C:onFilteredInputChanged(devName, action, value)

end

function C:onClientEndMission()
  self.open = false
  self._active = false
end

function C:work()
  if self.pinIn.reset.value == true then
    if self.open then
      self:closeDialogue()
    end
    self:reset()
    for _,pn in pairs(self.pinOut) do
      pn.value = false
    end
    return
  end
  if self.pinIn.clearVeh.value then
    self._selectedVehData = nil
    self._selectedFullData = nil
  end
  if self.pinIn.flow.value then
    if self._selectedVehData then
      self.pinOut.model.value = self._selectedVehData.model
      self.pinOut.config.value = self._selectedVehData.config or ""
      self.pinOut.color.value = {}
      if self._selectedVehData.color then
        for substring in self._selectedVehData.color:gmatch("%S+") do
           table.insert(self.pinOut.color.value, substring)
        end
      end
    else
      self.pinOut.model.value = nil
      self.pinOut.config.value = nil
      self.pinOut.color.value = nil
    end
    if self.done then return end
    if not self.open then
      self:openDialogue()
    end

    if self.pinOut.selected.value then -- impulse
      self.selected = false
      self.pinOut.selected.value = false
    end
    if self.selected then
      self.pinOut.selected.value = true
    end
  end
end

return _flowgraph_createNode(C)
