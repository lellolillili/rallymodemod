-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Start Screen'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.description = "Shows the start screen of a scenario."
C.todo = "Showing two of these at the same time will break everything."
C.behaviour = { once = true, singleActive = true}
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'reset', description = 'Resets this node.', impulse = true },
  { dir = 'in', type = 'string', name = 'layout', description = 'Layout of the start screen' },
  { dir = 'in', type = {'string', 'table'}, name = 'title', description = 'Title.' },
  { dir = 'in', type = {'string', 'table'}, tableType = 'multiTranslationObject', name = 'text', description = 'Subtext of the menu.' },
  { dir = 'in', type = 'string', name = 'buttonText', hardcoded = true, hidden = true, default = 'ui.scenarios.start.start', description = 'Text to display on the button.' },
  { dir = 'in', type = 'string', name = 'portraitImg', hidden = true, description = 'Portrait file path.' },
  { dir = 'in', type = 'bool', name = 'showProgress', hidden = true, description = 'If true, shows the progress for this mission.' },
  { dir = 'in', type = 'string', name = 'progressKey', hidden = true, description = 'If set, uses a custom progress key instead of the current one.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
}
C.dependencies = {'core_input_bindings'}

function C:init()
  self.open = false
  self.done = false
end

function C:_executionStarted()
  for _, p in pairs(self.pinOut) do
    p.value = false
  end
  self.open = false
  self.done = false
  self._active = false
end

function C:postInit()
  self.pinInLocal.layout.hardTemplates = {
    {label = "portrait", value = "portrait"},
    {label = "htmlOnly", value = "htmlOnly"},
  }
end

function C:_executionStarted()
  for _, p in pairs(self.pinOut) do
    p.value = false
  end
  self._active = false
end

function C:_executionStopped()
  if self.open then
    self:closeDialogue()
  end
  self:reset()
end

function C:reset()
  self.done = false
  self.open = false
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
  -- dump("closing dialogue!")
  --core_gamestate.setGameState('freeroam', 'freeroam', 'freeroam')
  --guihooks.trigger('MenuHide')
  --guihooks.trigger('ChangeState', 'play')
  setCEFFocus(false) -- focus the game now
  self.open = false
  self._active = false
end

function C:openDialogue()
  self.open = true
  -- dump("opening dialogue!")

  local data = {}
  data.showDataImmediately = true
  data.introType = self.pinIn.layout.value or 'htmlOnly'
  if type(self.pinIn.text.value) == 'table' and #self.pinIn.text.value > 0 then
    data.multiDescription = self.pinIn.text.value
  else
    data.description = self.pinIn.text.value
  end
  data.buttonText = self.pinIn.buttonText.value or "ui.scenarios.start.start"
  data.name = self.pinIn.title.value or ""
  data.portraitText = data.description
  data.portraitImg = {}
  data.portraitImg.start = self.pinIn.portraitImg.value or nil
  data.callObj = 'core_flowgraphManager.getManagerByID('..self.mgr.id..').graphs['..self.graph.id..'].nodes['..self.id..']'
  data.readyHook = data.callObj .. ':started()'


  if self.pinIn.showProgress.value and self.mgr.activity then
    local key = self.pinIn.progressKey.value or self.mgr.activity.currentProgressKey or "default"
    local format = gameplay_missions_progress.formatSaveDataForUi(self.mgr.activity.id, key)
    data.formattedProgress = format.formattedProgressByKey[key]
    data.progressKeyTranslations = format.progressKeyTranslations
    data.formattedProgressKey = key
    data.leaderboardKey = self.mgr.activity.defaultLeaderboardKey or 'recent'
    data.formattedStars = gameplay_missions_progress.formatStars(self.mgr.activity)
  end


  --data.extraButtons = {{label = "Vehicle Config", cmd = "guihooks.trigger('MenuOpenModule','vehicleconfig')"}, {label = "Vehicle Select", cmd = "guihooks.trigger('MenuOpenModule','vehicleselect')"}}
  --{{label='ui.common.retry', cmd='scenario_scenarios.uiEventRetry()', active = scenario.result.failed}, {label='ui.scenarios.end.freeroam', cmd='scenario_scenarios.uiEventFreeRoam()'}, {label='ui.common.menu', cmd='openMenu'}, {label='ui.quickrace.changeConfig', cmd='openLightRunner'}}
  --if core_input_bindings.isMenuActive then guihooks.trigger('', 'toggleMenues') end
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

function C:onFilteredInputChanged(devName, action, value)

end

function C:started()
  self:closeDialogue()
  self.pinOut.flow.value = true
  self.done = true
  self._active = false
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
  else
    if self.done then return end
    if self.pinIn.flow.value and not self.open then
      self:openDialogue()
    end
  end
end

function C:_onDeserialized(data)
  local hasOldFormat = data.hardcodedPins.portraitMode
  if hasOldFormat then
    local isPortrait = data.hardcodedPins.portraitMode
    self:_setHardcodedDummyInputPin(self.pinInLocal.layout, isPortrait and "portrait" or "htmlOnly")
  end
end

return _flowgraph_createNode(C)
