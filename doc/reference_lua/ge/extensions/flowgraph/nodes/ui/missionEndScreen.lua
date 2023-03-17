-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Mission End Screen'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.description = "Shows the end screen of a scenario with customizable buttons."
C.category = 'once_instant'
C.todo = "Showing two of these at the same time will break everything."
C.behaviour = {singleActive = true}

C.pinSchema = {
  --{ dir = 'in', type = 'string', name = 'title', description = 'Title of the menu.' },
  { dir = 'in', type = {'string','table'},  name = 'text', description = 'Subtext of the menu.' },
  { dir = 'in', type = 'bool', name = 'failed', hidden = true, description = 'If the player failed.' },
  { dir = 'in', type = 'table', name = 'change', description = 'Change from the attempt. use aggregate attempt node (test only)'},
  { dir = 'in', type = 'string', name = 'progressKey', description = 'Key for the attempt'},
  { dir = 'in', type = 'bool', name = 'useProvidedVehicle', description = 'If the players car is provided by the mission or their own.'},
  { dir = 'in', type = 'bool', name = 'customBtnsFirst', hidden = true, description = 'If true, the custom buttons will show before the default buttons.' },
  { dir = 'out', type = 'flow', name = 'contStart', description = 'When the player pressed "Continue at mission Start". Always available.'},
  { dir = 'out', type = 'flow', name = 'contHere', description = 'When the player pressed "Continue Here". Only available in career if using your own vehicle.'},
}


function C:init()
  self.open = false
  self.oldOptions = {}
  self.options = {}
  self.data.includeRetryButton = true
end

function C:postInit()
  self.options = {}
  self:updateButtons()
end

function C:_executionStarted()
  for _, p in pairs(self.pinOut) do
    p.value = false
  end
  self.open = false
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
    if lnk.sourceNode == self and tableContains(self.oldOptions, lnk.sourcePin.name) then
      table.insert(flowLinks, lnk)
    end
    if lnk.targetNode == self and tableContains(self.oldOptions, lnk.targetPin.name) then
      table.insert(strLinks, lnk)
    end
  end
  local outPins = {}
  for _, pn in pairs(self.pinOut) do
    if tableContains(self.oldOptions, pn.name) then
      table.insert(outPins, pn)
    end
  end
  for _, pn in pairs(outPins) do
    self:removePin(pn)
  end
  local inPins = {}
  for _, pn in pairs(self.pinInLocal) do
    local contained = false
    for _, op in ipairs(self.oldOptions) do
      if pn.name == op or pn.name == op.."_active" then
        contained = true
      end
    end
    if contained then
      table.insert(inPins, pn)
    end
  end
  for _, pn in pairs(inPins) do
    self:removePin(pn)
  end
  self.oldOptions = {}
  for i, btn in ipairs(self.options) do
    self:createPin("in", "string", btn, btn)
    self:createPin("in", "bool", btn.."_active", true).hidden=true
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
  self:closeDialogue()
end

function C:_afterTrigger()
  --if self.pinIn.flow.value == false and self.open then
  --  self:closeDialogue()
  --end
end

function C:buttonPushed(action)
  for nm, pn in pairs(self.pinOut) do
    if nm == action then
        self.pinOut[nm].value = true
    end
  end

  self:closeDialogue()
end

function C:getCmd(action)
  return 'core_flowgraphManager.getManagerByID('..self.mgr.id..').graphs['..self.graph.id..'].nodes['..self.id..']:buttonPushed("'..action..'")'
end

function C:onResetGameplay()
  if self.open and self.data.includeRetryButton then
    log("I","","Closing End Screen because of reset!")
    self:closeDialogue()
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

function C:openDialogue()
  self.open = true

  local customBtns, defaultBtns = {},{}
  -- WIP mission Button Stuff
  if self.mgr.activity and self.mgr.activity.nextMissions then
    for _, mid in ipairs(self.mgr.activity.nextMissions or {}) do
      local mission = gameplay_missions_missions.getMissionById(mid)
      if mission then
        table.insert(defaultBtns,{label="Start Next Mission '" .. translateLanguage(mission.name, mission.name).."'" , cmd='gameplay_missions_missionManager.startFromWithinActivity(gameplay_missions_missions.getMissionById("'..mid..'"))', disabled = not mission.unlocks.startable})
      end
    end
  end

  if self.data.includeRetryButton then
    table.insert(defaultBtns,{label='ui.common.retry', cmd='extensions.hook("onResetGameplay")'})
  end

  if not self.mgr.startedAsScenario then
    table.insert(defaultBtns,{label='missions.missions.general.end.continueAtStart', cmd=self:getCmd("contStart")})
  else
    table.insert(defaultBtns,{label='ui.dashboard.scenarios', cmd='openScenarios'})
  end



  --only allow cont. here if:
  -- the user uses their own vehicle and career is active.
  -- career is not active
  if (not career_career) or (not career_career.isCareerActive()) or (not self.pinIn.useProvidedVehicle.value and career_career and career_career.isCareerActive()) then
    table.insert(defaultBtns,{label='missions.missions.general.end.continueHere', cmd=self:getCmd("contHere")})
  end

  for _, btn in ipairs(self.options) do
    if self.pinIn[btn..'_active'].value and self.pinIn[btn].value and self.pinIn[btn].value ~= "" then
      table.insert(customBtns, {label = self.pinIn[btn].value, cmd = self:getCmd(btn)})
    end
  end
  if self.data.includeScenarioButton then
    table.insert(defaultBtns,{label='ui.dashboard.scenarios', cmd='openScenarios'})
  end


  local buttonsTable = {}
  if self.pinIn.customBtnsFirst.value then
    for _, btn in ipairs(customBtns)  do table.insert(buttonsTable, btn) end
    for _, btn in ipairs(defaultBtns) do table.insert(buttonsTable, btn) end
  else
    for _, btn in ipairs(defaultBtns) do table.insert(buttonsTable, btn) end
    for _, btn in ipairs(customBtns)  do table.insert(buttonsTable, btn) end
  end

  if buttonsTable[1] then
    buttonsTable[1].focus = true
    buttonsTable[1].active = true
  end

  local statsData = {
    overall = {failed = self.pinIn.failed.value or false, medal="none"}
  }
  statsData.buttons = buttonsTable
  statsData.title = ""--self.pinIn.title.value or ""
  statsData.time = ""--self.pinIn.timeStr.value or ""
  statsData.text = ""
  if type(self.pinIn.text.value) == 'table' then
    statsData.multiDescription = self.pinIn.text.value
  else
    statsData.text = self.pinIn.text.value or ""
  end

  local missionData = nil
  if self.mgr.activity and self.pinIn.change.value then
    missionData = {}
    missionData.aggregateChange = self.pinIn.change.value
    --missionData.attempt = self.pinIn.attempt.value
    --missionData.progressKey = self.pinIn.progressKey.value or self.mgr.activity.currentProgressKey
    local key = self.pinIn.progressKey.value or self.mgr.activity.currentProgressKey or "default"
    missionData.leaderboardKey = self.mgr.activity.defaultLeaderboardKey or 'recent'
    missionData.progressKey = key
    missionData.leaderboardChangeKeys = gameplay_missions_progress.getLeaderboardChangeKeys(self.mgr.activity.id)
    local dnq = missionData.leaderboardKey == 'highscore' and not missionData.aggregateChange.aggregateChange.newBestKeysByKey[missionData.leaderboardChangeKeys['highscore']]
    local formatted = gameplay_missions_progress.formatSaveDataForUi(self.mgr.activity.id, key, dnq)
    missionData.formattedProgress = formatted.formattedProgressByKey[key]
    missionData.progressKeyTranslations = formatted.progressKeyTranslations
    if dnq then
      -- fixed amount shown hack for dnq
      missionData.aggregateChange.aggregateChange.newBestKeysByKey[missionData.leaderboardChangeKeys['highscore']] = 6
    end
    missionData.formattedStars = gameplay_missions_progress.formatStars(self.mgr.activity)

  end

  guihooks.trigger('ChangeState', {state = 'scenario-end', params = {missionData = missionData, stats = statsData, portrait = portrait}});
end

function C:onNodeReset()
    self:closeDialogue()
    for _,pn in pairs(self.pinOut) do
      pn.value = false
    end
end

function C:workOnce()
    self:openDialogue()
end

return _flowgraph_createNode(C)
