-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

require("utils")

local actionsCache = {} -- both vehicle-specific and normal actions, [true] for active ones, [false] for inactive ones
local normalActionsCache = {}                     -- normal actions, [true] for active ones, [false] for inactive ones

local M = {}
M.dependencies = { "core_input_categories", "core_input_deprecatedActions", "tech_license" }

-- mangle the action name, needed to prevent collisions with other vehicles' action names
local function nameToUniqueName(actionName, vehicleName)
  local uniqueActionName = actionName
  if vehicleName then uniqueActionName = vehicleName.."__"..uniqueActionName end
  return uniqueActionName
end

local function uniqueNameToName(uniqueActionName, vehicleName)
  local actionName = uniqueActionName
  if vehicleName then
    local prefix = vehicleName.."__"
    if string.startswith(actionName, prefix) then
       actionName = string.sub(actionName, 1+string.len(prefix))
    end
  end
  return actionName
end

-- read the actions from the specified file
-- vehicle-specific actions have certain defaults, to aid modders get it right easily
local function readActionsFile(path, vehicleName)
  local actions = {}
  local vehiclesActions = jsonReadFile(path)
  if vehiclesActions == nil then
    log("E", "input_actions", 'unable to read json file: ' .. tostring(path))
  end
  for k,v in pairs(vehiclesActions or {}) do
    if vehicleName then
      v.vehicle = vehicleName
      v.cat = v.cat or "vehicle_specific"
      v.ctx = v.ctx or "vlua"
    end
    actions[nameToUniqueName(k, vehicleName)] = v
  end
  return actions
end

-- read the actions for the specified vehicle, or global actions otherwise
-- if active is true, only active actions are returned
-- if active is false, only inactive actions are returned (due to e.g. beamng.tech license)
local function readVehicleActionsFromDisk(vehicleName, active)
  local directory = vehicleName and ("vehicles/"..vehicleName) or "lua/ge/extensions/core/input/actions/"
  local pattern = vehicleName and "input_actions*.json" or "*.json"
  local result = {}
  for _,path in pairs(FS:findFiles(directory, pattern, 0, false, false)) do
    if active == tech_license.isAllowedActionsPath(path) then
      tableMerge(result, readActionsFile(path, vehicleName))
    end
  end
  return result
end

-- actions that are not vehicle-specific
local function getNormalActions(active)
  normalActionsCache[active] = normalActionsCache[active] or readVehicleActionsFromDisk(nil, active)
  return normalActionsCache[active]
end

local function readActionsFromDisk(active)
  -- re-read all vehicle-specific actions, then merge with the non-vehicle-specific actions
  local vehiclesActions = {}
  for _,vehicle in ipairs(getAllVehicles()) do
    local vehicleName = vehicle:getJBeamFilename()
    vehiclesActions[vehicleName] = readVehicleActionsFromDisk(vehicleName, active)
  end

  -- merge all global actions and per-vehicle actions together
  local result = {}
  for _,a in pairs(vehiclesActions) do
    for k,v in pairs(a) do
      result[k] = v
    end
  end
  for k,v in pairs(getNormalActions(active)) do
    if result[k] then log("E", "", "Vehicle specific action '"..k.."' already exists as a normal (active="..dumsp(active)..") action, and will be ignored") end
    result[k] = v
  end
  return result
end

-- actions that are either active, or inactive, at the current time (for example, including BeamNG.tech actions if the tech license is valid)
local function getActions(active)
  actionsCache[active] = actionsCache[active] or readActionsFromDisk(active)
  return actionsCache[active]
end

-- check if an action has been deprecated or replaced, and return the new version when possible
local function upgradeAction(action)
  if action == nil then
    log('E', 'bindings', "Cannot parse null action")
    return
  end
  if getActions(true)[action] == nil then
    if getActions(false)[action] ~= nil then
      -- ignoring action, as it's currently inactive
      return
    end

    if core_input_deprecatedActions[action] == nil then
      log('E', 'bindings', "Couldn't find action "..action.." in actions lookup table")
      return
    end

    if core_input_deprecatedActions[action]["replacement"] ~= nil then
      log('D', 'bindings', "Replacing deprecated action "..action.." with new action "..core_input_deprecatedActions[action]["replacement"]);
      return upgradeAction(core_input_deprecatedActions[action]["replacement"])
    end
    if core_input_deprecatedActions[action]["obsolete"] == true then
      log('D', 'bindings', "Ignoring deprecated action: "..action)
      return
    end
    log('E', 'bindings', "Couldn't process deprecated action "..action..": "..dumps(core_input_deprecatedActions[action]))
    return
  end
  return action
end

local function actionToCommands(action)
  -- retrieve the code/parameters that will be used by GameEngine when a binding triggers this action
  local actionMap       = "Normal"
  local actsOnChange    = false
  local     onChange    = ""
  local actsOnDown      = false
  local     onDown      = ""
  local actsOnUp        = false
  local     onUp        = ""
  local isRelative      = false
  local ctx             = ActionMapCommandContext()
  ctx.type = COMMAND_CONTEXT_TLUA
  local isCentered      = false

  local ctxStr = 'tlua'

  local c = getActions(true)[action]
  if c["cat"]      =='menu' then actionMap = "Menu" end
  if c["ctx"]      =='vlua' then actionMap = "VehicleCommon" end
  if c["actionMap"]  ~= nil then actionMap = c["actionMap"]; end
  if c["vehicle"]    ~= nil then actionMap = "VehicleSpecific" end
  if c["onChange"]   ~= nil then onChange = c["onChange"]; actsOnChange = true; end
  if c["onRelative"] ~= nil then onChange = c["onRelative"]; actsOnChange = true; isRelative = true; end
  if c["onDown"]     ~= nil then onDown = c["onDown"]; actsOnDown = true; end
  if c["onUp"]       ~= nil then onUp = c["onUp"]; actsOnUp = true; end
  if c["isCentered"] ~= nil then isCentered= c["isCentered"]; end
  if c["ctx"]        ~= nil then ctxStr = c["ctx"]; end

  if core_input_categories[c.cat] == nil then
    log('W', 'bindings', 'Invalid category '..dumps(c.cat)..' defined for '..dumps(action).."' action. Suggested fix: modify the 'cat' action field to a valid category, or add the category to categories.lua")
  end
  if ctxStr == 'slua' then
    ctxStr = 'elua'
    log('E', 'bindings', 'Replacing deprecated "slua" context with "elua", for action: '..dumps(action))
  end
  if     ctxStr == 'ts'    then
    log("E", "", "The 'ts' context is deprecated. please use tlua. Action: "..dumps(action))
    ctx.type = COMMAND_CONTEXT_TS
  elseif ctxStr == 'ui'    then
    log("E", "", "The ui context is deprecated. please use tlua and guihooks. Action: "..dumps(action))
  elseif ctxStr == 'vlua'  then ctx.type = COMMAND_CONTEXT_VLUA
  elseif ctxStr == 'elua'  then ctx.type = COMMAND_CONTEXT_ELUA
  elseif ctxStr == 'tlua'  then ctx.type = COMMAND_CONTEXT_TLUA
  elseif ctxStr == 'bvlua' then ctx.type = COMMAND_CONTEXT_BVLUA end

  return true, actionMap, actsOnChange, onChange, actsOnDown, onDown, actsOnUp, onUp, isRelative, ctx, isCentered
end

local function onFirstUpdate()
  table.clear(actionsCache)
end

local function onVehicleSwitched(oldId, newId, player)
  local oldVehicle = be:getObjectByID(oldId)
  local newVehicle = be:getObjectByID(newId)
  local oldName = oldVehicle and oldVehicle:getJBeamFilename() or "<none>"
  local newName = newVehicle and newVehicle:getJBeamFilename() or "<none>"
  if oldName ~= newName then
    table.clear(actionsCache)
  end
end

local function onFileChanged(filename)
  local actionsModified = string.startswith(filename, "/lua/ge/extensions/core/input/actions") and string.endswith(filename, ".json")
  if actionsModified then
    table.clear(normalActionsCache)
    table.clear(actionsCache)
  end
end

M.onFirstUpdate = onFirstUpdate
M.onVehicleSwitched = onVehicleSwitched
M.onFileChanged = onFileChanged

M.getActiveActions = function() return getActions(true) end
M.upgradeAction = upgradeAction
M.actionToCommands = actionToCommands
M.uniqueNameToName = uniqueNameToName
M.nameToUniqueName = nameToUniqueName
return M
