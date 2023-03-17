-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Race End Screen'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.description = "Shows the end screen of a scenario with customizable buttons."
-- C.category = 'once_instant'
C.todo = "Showing two of these at the same time will break everything."
C.behaviour = { once = true, singleActive = true }
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'reset', description = 'Resets this node.', impulse = true },
  { dir = 'in', type = 'string', name = 'title', description = 'Title of the menu.' },
  { dir = 'in', type = {'string','table'}, name = 'text', description = 'Subtext of the menu.' },


  --{dir = 'in', type = 'table', name = 'stats', description = 'Stats for endscreen. Use endStats node.'},
  {dir = 'in', type = 'number', name = 'vehId', description = 'Id of the vehicle to show detailled stats for.' },
  {dir = 'in', type = 'table', name = 'stats', tableType = "endStats", description = 'Stats for endscreen. Use endStats node.'},
}


function C:init()
  self.open = false
  self.done = false
  self.oldOptions = {}
  self.options = {}
  self.data.includeScenarioButton = false
  self.data.includeRetryButton = true
end

function C:postInit()
  self.options = {'cont'}
  self:updateButtons()
  self:_setHardcodedDummyInputPin(self.pinInLocal.cont, "Continue")

end

function C:_executionStarted()
  for _, p in pairs(self.pinOut) do
    p.value = false
  end
  self.open = false
  self.done = false
end


function C:drawCustomProperties()
  local reason = nil
  local remove = nil
  for i, btn in ipairs(self.options) do
    local txt = im.ArrayChar(64, btn)
    if im.InputText("##btn" .. i, txt, nil, im.InputTextFlags_EnterReturnsTrue) then
      if ffi.string(txt) == '' then
        remove = i
      else
        self.options[i] = ffi.string(txt)
        reason = "renamed button to" .. self.options[i]
      end
    end
  end
  if remove then
    for i = remove, #self.options do
      self.options[i] = self.options[i+1]
    end
    reason = "Removed an option."
  end
  if im.Button("add") then
    table.insert(self.options, "btn_"..(#self.options+1))
    reason = "added Button"
  end
  im.SameLine()
  if im.Button("rem") then
    self.options[#self.options] = nil
    reason = "removed Button"
  end
  if reason then
    self:updateButtons()
  end
  return reason
end

function C:updateButtons()
  local flowLinks = {}
  local strLinks = {}
  for _, lnk in pairs(self.graph.links) do
    if lnk.sourceNode == self then
      table.insert(flowLinks, lnk)
    end
    if lnk.targetNode == self and tableContains(self.oldOptions, lnk.targetPin.name) then
      table.insert(flowLinks, lnk)
    end
  end
  local outPins = {}
  for _, pn in pairs(self.pinOut) do
    table.insert(outPins, pn)
  end
  for _, pn in pairs(outPins) do
    self:removePin(pn)
  end
  local inPins = {}
  for _, pn in pairs(self.pinInLocal) do
    if tableContains(self.oldOptions, pn.name) then
      table.insert(inPins, pn)
    end
  end
  for _, pn in pairs(inPins) do
    self:removePin(pn)
  end
  self.oldOptions = {}
  for i, btn in ipairs(self.options) do
    self:createPin("in", "string", btn, btn)
    self:createPin("out", "flow", btn)
    self.oldOptions[i] = btn
  end

  for _, lnk in ipairs(flowLinks) do
    if lnk.sourcePin.name and self.pinOut[lnk.sourcePin.name] then
      self.graph:createLink(self.pinOut[lnk.sourcePin.name], lnk.targetPin)
    end
  end
  for _, lnk in ipairs(strLinks) do
    if lnk.targetPin.name and self.pinInLocal[lnk.targetPin.name] then
      self.graph:createLink(lnk.sourcePin, self.pinInLocal[lnk.targetPin.name])
    end
  end
end


function C:_onSerialize(res)
  res.options = deepcopy(self.options)
end

function C:_onDeserialized(nodeData)
  self.options = nodeData.options or {}
  self:updateButtons()
end

function C:_executionStopped()
  if self.open then
    self:closeDialogue()
  end
  self:reset()
end

function C:_afterTrigger()
  --if self.pinIn.flow.value == false and self.open then
  --  self:closeDialogue()
  --end
end

function C:reset()
  self.done = false
  self.open = false
end

function C:buttonPushed(action)
  for nm, pn in pairs(self.pinOut) do
    self.pinOut[nm].value = nm == action
  end
  self:closeDialogue()
  self.done = true
end

function C:getCmd(action)
  return 'core_flowgraphManager.getManagerByID('..self.mgr.id..').graphs['..self.graph.id..'].nodes['..self.id..']:buttonPushed("'..action..'")'
end

function C:onResetGameplay()
  if self.open and self.data.includeRetryButton then
    log("I","","Closing End Screen because of reset!")
    self:closeDialogue()
    self.done = true
  end
end
function C:closeDialogue()
  if self.open then
    --core_gamestate.setGameState('freeroam', 'freeroam', 'freeroam')
    --guihooks.trigger('MenuHide')
    --guihooks.trigger('ChangeState', 'menu')
    self.open = false
  end
end
function C:onClientEndMission()
  self.open = false
end

local function getConfigKey(rolling, reverse, laps, race)



  if rolling == nil then rolling = race.path.config.rollingStart end
  if reverse == nil then reverse = race.path.isReversed end
  if laps == nil then laps = race.lapCount end

  local mode = "standing"

  if rolling then mode = "rolling" end
  if reverse then mode = mode.."Reverse" end
  if laps then mode = mode .. laps end

  return mode
end

function C:openDialogue()
  self.open = true
  local statsData = {}

  local buttonsTable = {}
  if self.data.includeRetryButton then
    table.insert(buttonsTable,{label='ui.common.retry', cmd='extensions.hook("onResetGameplay")'})
  end
  for _, btn in ipairs(self.options) do
    if self.pinIn[btn].value and self.pinIn[btn].value ~= "" then
      table.insert(buttonsTable, {active = #buttonsTable == 0, label = self.pinIn[btn].value, cmd = self:getCmd(btn)})
    end
  end
  if self.data.includeScenarioButton then
    table.insert(buttonsTable,{label='ui.dashboard.scenarios', cmd='openScenarios'})
  end
  statsData.buttons = buttonsTable

  --statsData.time = self.pinIn.timeStr.value or ""
  statsData.text = ""
  statsData.overall = {}
  --statsData.overall = {
  --  failed = self.pinIn.failed.value or false,
  --  medal = self.pinIn.medal.value or "none",
  --  points = self.pinIn.points.value or nil,
  --  maxPoints = self.pinIn.maxPoints.value or nil,
 -- }
  --statsData.customSuccess = self.pinIn.successString.value
  --statsData.customFail = self.pinIn.failString.value

  --if self.pinIn.autoPoints.value then
  --  local points, max = 0,0
  --  for k, v in ipairs(self.pinIn.stats.value or {}) do
  --    points = points + v.points or 0
  --    max = max + v.maxPoints or 0
  --  end
  --  statsData.overall.points = points
  --  statsData.overall.maxPoints = max
  --end

  --if statsData.overall.failed then
  --  statsData.overall.medal = 'wood'
  --end
  --local portrait = {}
  --portrait.fail = self.pinIn.portraitFail.value or nil
  --portrait.success = self.pinIn.portraitSuccess.value or nil
  --statsData.stats = self.pinIn.stats.value or nil
  --{{label='ui.common.retry', cmd='scenario_scenarios.uiEventRetry()', active = scenario.result.failed}, {label='ui.scenarios.end.freeroam', cmd='scenario_scenarios.uiEventFreeRoam()'}, {label='ui.common.menu', cmd='openMenu'}, {label='ui.quickrace.changeConfig', cmd='openLightRunner'}}


  local race = self.pinIn.stats.value
  local vehStats = race.states[self.pinIn.vehId.value]
  statsData.title = race.path.name
  local scenario = {
    detailedTimes = core_hotlapping.getTimeInfo()
  }

  local hs = vehStats.raceComepleteHighscores
  if hs then
    local scores = hs.scores
    local place = hs.place
    if scenario.highscores == nil then
      scenario.highscores = {}
    end
    scenario.highscores.scores = scores
    if place ~= -1 then
      scenario.highscores.scores[place].current = true
    end
    scenario.highscores.place = place
    --[[scenario.highscores.singleScores = core_highscores.getScenarioHighscores(getCurrentLevelIdentifier(), self.mgr.activity.missionTypeData.trackName, getConfigKey(false,nil,0,race))
    for _,v in ipairs(scenario.highscores.singleRound) do
      if v <= #(scenario.highscores.singleScores) then
        scenario.highscores.singleScores[v].current = true
      end
    end]]
    scenario.viewDetailed = 0
    if place == -1 then
      scenario.detailedRecord = {
        playerName = core_vehicles.getVehicleLicenseText(vehicle),
        vehicleBrand = scenario.vehicle.file.Brand,
        vehicleName = scenario.vehicle.file.Name,
        place = " / ",
        formattedTimestamp = os.date("!%c",os.time())
      }
    else
      scenario.detailedRecord = scores[place]
    end
  end

  --dumpz(self.pinIn.stats.value, 2)

  guihooks.trigger('ChangeState', {state = 'quickrace-end', params = {stats = statsData, mockScenario = scenario}});
end

function C:closed()
  self.done = true
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

return _flowgraph_createNode(C)
