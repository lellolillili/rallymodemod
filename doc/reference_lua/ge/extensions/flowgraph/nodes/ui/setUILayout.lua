-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Set UI Layout'
C.description = 'Sets the ui app layout.'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.u
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'reset', description = 'Resets this node. Needed to be able to trigger the layout again.', impulse = true },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
  { dir = 'in', type = { 'string', 'table' }, tableType = 'layoutData', name = 'layout', default = 'scenario', description = 'for now, can only be scenario or freeroam.' },
  { dir = 'in', type = 'string', name = 'menu', default = 'scenario', description = 'for now, can only be scenario or freeroam.' },
}

C.tags = {}

function C:init()
  self.useFreeroamMenuWhenUnrestricted = true
end

function C:postInit()
  local layout_options = {} -- extensions.ui_apps.getLayouts()
  table.sort(layout_options)

  local layout = {}
  for tmp, _ in pairs(layout_options) do
    table.insert(layout, {value = tmp})
  end

  self.pinInLocal.layout.hardTemplates = layout

  local menu = {}
  for tmp, _ in pairs(layout_options) do
    table.insert(menu, {value = tmp})
  end

  self.pinInLocal.menu.hardTemplates = menu
end

function C:_executionStopped()
    core_gamestate.setGameState('freeroam','freeroam','freeroam')
end

function C:drawMiddle(builder, style)
  builder:Middle()
end

function C:afterTrigger()
  if self.pinIn.flow.value then
    self.active = true
  else
    self.active = false
  end
end

function C:workOnce()
  local menuState = self.pinIn.menu.value or nil
  if self.useFreeroamMenuWhenUnrestricted and (not settings.getValue('restrictScenarios', true)) then
    menuState = 'freeroam'
    log('W', logTag, '**** Restrictions on Scenario Turned off in game settings. Using Freeroam menu as default. ****')
  end

  core_gamestate.setGameState("temp_fg_"..self.mgr.id.."_"..self.id,self.pinIn.layout.value or nil, menuState)

  self.active = true
end

function C:onClientPostStartMission()
  -- TEMP FIX: the game overrides the state, so we need to set it again :|
  core_gamestate.setGameState("temp_fg_"..self.mgr.id.."_"..self.id,self.pinIn.layout.value or nil, menuState)
end

function C:onUiChangedState(cur, prev)
  if self.active then
    if cur == 'menu' and self.pinIn.layout.value == 'quickraceScenario' then
      guihooks.trigger('setQuickRaceMode')
      guihooks.trigger("HotlappingResetApp")
    end
  end
end

return _flowgraph_createNode(C)
