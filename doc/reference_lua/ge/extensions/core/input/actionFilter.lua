-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local actionGroups = {}
local blockedActionGroups = {}
local blockedActions = {}

local actionTemplates = {}

local function createActionTemplate(templateNames, actionWhitelist, actionBlackList)
  local template = {}
  for _, entry in ipairs(templateNames) do
    if actionTemplates[entry] then
      if not actionWhitelist or not tableContains(actionWhitelist, actionTemplates[entry]) then
        arrayConcat(template, actionTemplates[entry])
      end
    end
  end
  if actionBlackList then
    arrayConcat(template, actionBlackList)
  end
  return template
end

actionTemplates.vehicleTeleporting = {"dropPlayerAtCamera", "dropPlayerAtCameraNoReset", "recover_vehicle", "recover_vehicle_alt", "recover_to_last_road", "reload_vehicle", "reload_all_vehicles", "loadHome", "saveHome", "reset_all_physics", "goto_checkpoint", "set_checkpoint"} -- no "reset_physics" as this is often used as a normal reset in scenarios
actionTemplates.vehicleMenues = {"vehicle_selector", "parts_selector"}
actionTemplates.physicsControls = {"slower_motion", "faster_motion", "toggle_slow_motion", "nodegrabberAction", "nodegrabberGrab", "nodegrabberRender", "nodegrabberStrength"}
actionTemplates.aiControls = {"toggleTraffic", "toggleAITraffic"}
actionTemplates.vehicleSwitching = {"switch_next_vehicle", "switch_previous_vehicle", "switch_next_vehicle_multiseat"}
actionTemplates.editor = {"editorToggle", "objectEditorToggle", "editorSafeModeToggle"}
actionTemplates.freeCam = {"toggleCamera", "dropCameraAtPlayer"}
if shipping_build then
  arrayConcat(actionTemplates.freeCam, actionTemplates.editor)
end
actionTemplates.gameCam = {"camera_1","camera_10","camera_2","camera_3","camera_4","camera_5","camera_6","camera_7","camera_8","camera_9", "center_camera", "look_back", "rotate_camera_down","rotate_camera_horizontal", "rotate_camera_hz_mouse", "rotate_camera_left", "rotate_camera_right", "rotate_camera_up", "rotate_camera_vertical", "rotate_camera_vt_mouse", "switch_camera_next", "switch_camera_prev", "changeCameraSpeed", "movedown", "movefast", "moveup", "rollAbs", "xAxisAbs", "yAxisAbs", "yawAbs", "zAxisAbs", "pitchAbs"}
actionTemplates.funStuff = {"forceField", "funBoom", "funBreak", "funExtinguish", "funFire", "funHinges", "funTires", "funRandomTire"}
actionTemplates.walkingMode = {"toggleWalkingMode"}
actionTemplates.photoMode = {"openPhotomode", "photomode"}
actionTemplates.trackBuilder = {"toggleTrackBuilder"}
actionTemplates.bigMap = {"toggleBigMap"}
actionTemplates.couplers = {"couplersLock", "couplersToggle", "couplersUnlock"}
actionTemplates.vehicleTriggers = {"triggerAction0", "triggerAction1", "triggerAction2"}
actionTemplates.radialMenu = {"menu_item_radial_x", "menu_item_radial_y"}
actionTemplates.pause = {"pause"}
actionTemplates.missionPopup = {"accept", "decline"}
actionTemplates.resetPhysics = {"reset_physics"}
actionTemplates.appedit = {"appedit"}
actionTemplates.miniMap = {"toggle_minimap"}

actionTemplates.competitive = createActionTemplate({"vehicleTeleporting", "vehicleMenues", "physicsControls", "aiControls", "vehicleSwitching", "freeCam", "funStuff"})


local function addToFilter(filter, actionName, filtered)
  if type(actionGroups[actionName]) == 'table' then
    for i, a in ipairs(actionGroups[actionName]) do
      ActionMap.addToFilter(filter, a, filtered )
      blockedActions[filter][a] = filtered
    end
  else
    ActionMap.addToFilter(filter, actionName, filtered)
    blockedActions[filter][actionName] = filtered
  end
end

local function clearCFilter(filter)
  ActionMap.clearFilters(filter)
  blockedActions[filter] = {}
end

local function updateFilters(filter)
  clearCFilter(filter)
  for actionGroupName, filtered in pairs(blockedActionGroups[filter]) do
    if filtered then
      addToFilter(filter, actionGroupName, filtered)
    end
  end
end

local function addAction(filter, actionName, filtered)
  blockedActionGroups[filter] = blockedActionGroups[filter] or {}
  blockedActionGroups[filter][actionName] = filtered
  updateFilters(filter)
end

local function clear(filter)
  clearCFilter(filter)
  blockedActionGroups[filter] = {}
end

local function setGroup(name, arrayValues)
  actionGroups[name] = arrayValues
end

local function getGroup(name)
  return actionGroups[name]
end

local function isActionBlocked(actionName)
  for filter, actions in pairs(blockedActions) do
    if actions[actionName] then
      return true
    end
  end
end

local function onSerialize()
  local data = {}
  data.actionGroups = actionGroups
  data.blockedActionGroups = blockedActionGroups
  return data
end

local function onDeserialized(v)
  actionGroups = v.actionGroups
  blockedActionGroups = v.blockedActionGroups
end

local function getActionTemplates()
  return actionTemplates
end

M.addAction = addAction
M.clear = clear
M.setGroup = setGroup
M.getGroup = getGroup
M.isActionBlocked = isActionBlocked
M.createActionTemplate = createActionTemplate
M.getActionTemplates = getActionTemplates

M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

return M
