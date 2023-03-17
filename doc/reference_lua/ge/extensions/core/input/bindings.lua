-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

require("utils")
local json = require("json")
local imgui = ui_imgui
local M = {}
M.dependencies = { "core_input_actions", "core_input_categories", "core_multiseat", "tech_license" }
M.isMenuActive = false
M.devices = {}
local actionToControl = nil

-- when bindings go through the UI, javascript side is introducing bugs in their fields; we attempt to clean that up here
local function fixBuggyBindingFromUISide(binding)
  -- delete unrelated fields that are injected by UI side
  binding.icon = nil
  binding.desc = nil
  binding.title = nil

  -- delete ffb fields that should only happen for bindings with force feedback
  if binding.action ~= "steering" then
    binding.ffb = nil
    binding.ffbUpdateType = nil
  end

  -- fix numbers that are sent as strings by UI side (typically md-select widgets are messing this up)
  binding.filterType = tonumber(binding.filterType)
  binding.lockType = tonumber(binding.lockType)
  binding.ffbUpdateType = tonumber(binding.ffbUpdateType)
  if binding.ffb then
    binding.ffb.frequency = tonumber(binding.ffb.frequency)
  end
end

local function fillNormalizeBindingDefaults(binding)
  local binding = deepcopy(binding)
  fixBuggyBindingFromUISide(binding)
  -- populate any possible missing binding parameter with sensible default values, and upgrade old bindings
  binding.isLinear = nil -- remove deprecated field
  binding.scale  = nil -- remove deprecated field
  binding.isRanged = nil -- remove deprecated field
  if binding.deadzone      == nil then binding.deadzone = { ["end"] = 0 } end
  binding.deadzone.begin = nil -- remove deprecated field
  if binding.deadzone["end"] then binding.deadzone["end"] = tonumber(binding.deadzone["end"]) end
  if binding.deadzone["end"] and not binding.deadzoneResting then binding.deadzoneResting = binding.deadzone["end"] end
  if binding.deadzoneResting then binding.deadzoneResting = tonumber(binding.deadzoneResting) end
  if binding.deadzoneEnd   then binding.deadzoneEnd   = tonumber(binding.deadzoneEnd)   end
  binding.deadzone = nil -- remove deprecated field
  if binding.deadzoneResting == nil then binding.deadzoneResting = 0 end
  if binding.deadzoneEnd   == nil then binding.deadzoneEnd = 0 end
  if binding.control       ~= nil then binding.control = string.lower(binding.control) end
  if binding.linearity     == nil then binding.linearity = 1 end
  if binding.isInverted    == nil then binding.isInverted = false end
  if binding.isForceEnabled  == nil then binding.isForceEnabled = false end
  if binding.isForceInverted == nil then binding.isForceInverted = false end
  if binding.ffbUpdateType   == nil then binding.ffbUpdateType = 0 end
  if binding.ffb           == nil then binding.ffb = {} end
  if binding.ffb.forceCoef == nil then binding.ffb.forceCoef = 200 end
  if binding.ffb.smoothing == nil then binding.ffb.smoothing = 150 end
  binding.ffb.smoothingHF = nil -- remove deprecated field
  if binding.ffb.forceLimit then binding.ffb.forceCoef = (binding.ffb.forceCoef * binding.ffb.forceLimit) / 10 end -- downscale forceCoef proportionally to the removal of forceLimit (which will bump it from whichever current value, up to "10")
  binding.ffb.forceLimit = nil -- remove deprecated field
  if binding.ffb.frequency   == nil then binding.ffb.frequency = 0 end
  if binding.ffb.gforceCoef  == nil then binding.ffb.gforceCoef = 0 end
  if binding.ffb.responseCurve==nil then binding.ffb.responseCurve = { {0, 0}, {1, 1} } end
  if binding.ffb.responseCorrected==nil then binding.ffb.responseCorrected = false end
  if binding.ffb.lowspeedCoef== nil then binding.ffb.lowspeedCoef = true end
  if binding.ffb.softlockEnabled == true then binding.ffb.softlockForce = 1 end
  if binding.ffb.softlockEnabled == false then binding.ffb.softlockForce = 0 end
  binding.ffb.smoothing2automatic = binding.ffb.smoothing2automatic ~= false
  -- IMPORTANT: these equations exist in 3 places in hydros.lua, 2 places in options.js, and 1 place in bindings.lua
  if binding.ffb.smoothing2 == nil then binding.ffb.smoothing2 = (math.max(5000, (500 - binding.ffb.smoothing*0.7)*100+5000)-500)/109 end
  binding.ffb.softlockEnabled = nil
  if binding.ffb.softlockForce == nil then binding.ffb.softlockForce = 1 end
  binding.ffb.softlockForce = clamp(binding.ffb.softlockForce, 0, 1)
  binding.ffb.forceCoefLowSpeed = nil -- remove deprecated field
  if binding.filterType    == nil then binding.filterType = -1 end
  if binding.angle       == nil then binding.angle = 0 end
  if binding.lockType    == nil then binding.lockType = 1 end
  return binding
end

local defaultBinding = fillNormalizeBindingDefaults({})

-- From: https://web.archive.org/web/20131225070434/http://snippets.luacode.org/snippets/Deep_Comparison_of_Two_Values_3
-- available under MIT/X11
local function deepcompare(t1,t2)
  local ty1 = type(t1)
  local ty2 = type(t2)
  if ty1 ~= ty2 then return false end
  -- non-table types can be directly compared
  if ty1 ~= 'table' then return t1 == t2 end

  local testedKeys = {}
  for k1, v1 in pairs(t1) do
    local v2 = t2[k1]
    if v2 == nil or not deepcompare(v1, v2) then return false end
    testedKeys[k1] = true
  end
  for k2, v2 in pairs(t2) do
    if not testedKeys[k2] then
      local v1 = t1[k2]
      if v1 == nil or not deepcompare(v1, v2) then return false end
    end
  end
  return true
end

local function cleanBindingDefaults(binding)
  -- strip the binding settings that are default (leaving only the custom settings)
  local result = deepcopy(binding)
  for k, v in pairs(defaultBinding) do
    if deepcompare(result[k],v) then
      result[k] = nil
    end
  end
  return result
end

local function dumpbinding(binding)
  if binding == nil then return dumps(binding) end
  return dumps(cleanBindingDefaults(deepcopy(binding))):gsub("\n", " "):gsub(" +", " ")
end

local function sendBindingsToGE(devname, bindings, player)
  -- upload the provided bindings data into torque3d, associated with an specific device name
  if bindings == nil then
    log('E', 'bindings', "Error parsing bindings for device "..devname..": bindings is nil")
    return false
  end
  local count = 0
  for i,binding in pairs(bindings) do
    local b = deepcopy(binding)
    b.action = core_input_actions.upgradeAction(b.action)
    if not b.action then
      log('E', 'bindings', "Skipping invalid 'action' field on binding "..i.." in device "..devname..": "..dumpbinding(binding))
      goto continue
    end

    local success, actionMap, actsOnChange, onChange, actsOnDown, onDown, actsOnUp, onUp, isRelative, ctx, isCentered
    success, actionMap, actsOnChange, onChange, actsOnDown, onDown, actsOnUp, onUp, isRelative, ctx, isCentered = core_input_actions.actionToCommands(b["action"])
    if not success then
      log('E', 'bindings', "Couldn't load action "..b["action"])
      goto continue
    end

    b = fillNormalizeBindingDefaults(b)

    local actionMapName = actionMap.."ActionMap"
    local am = scenetree.findObject(actionMapName)
    if not am then
      am = ActionMap(actionMapName)
      --log('D', 'bindings', "Registered new action map: "..actionMapName)
    end
    am:bind(devname, b.action, b.control, isCentered, b.deadzoneResting, b.deadzoneEnd, b.linearity, b.angle, b.lockType, b.isInverted, b.isForceEnabled, b.isForceInverted, b.ffbUpdateType, jsonEncode(b.ffb), actsOnChange, onChange, actsOnDown, onDown, actsOnUp, onUp, b.filterType, isRelative, player, ctx)
    count = count + 1
    ::continue::
  end
  log('D', 'bindings', "Loaded "..count.." bindings for device "..devname)
  return true
end
local function readBindingsFromDisk(paths, vehicleName, ignoreRemoved)
  local result = { bindings = {}, removed = {} }
  for _,path in ipairs(paths) do
    -- read and normalize/upgrade bindings from a single file on disk
    local fileData
    local f = readFile(path)
    if f then
      local success
      success, fileData = pcall(json.decode, f)
      if not success then
        log('E', 'bindings', "Error decoding json content from file "..dumps(path)..": "..dumps(fileData))
        fileData = nil
      end
    else
      log('E', 'bindings', "Error parsing bindings in file "..path..": cannot open file")
    end
    for k,v in pairs(fileData or {}) do
      if k == "bindings" then
        for i, b in ipairs(v) do
          if b.control == nil then
            log('E', 'bindings', "Missing 'control' field on binding "..i.." in file "..path..": "..dumpbinding(b))
            goto nextBinding
          end
          b = fillNormalizeBindingDefaults(b)
          local action = core_input_actions.nameToUniqueName(b.action, vehicleName) -- this name-mangling is needed to prevent collisions with other vehicles' action names
          action = core_input_actions.upgradeAction(action)
          if not action then
            log('D', 'bindings', "Skipping invalid 'action' field on binding "..i.." in file "..path..": "..dumpbinding(b))
            goto nextBinding
          end
          b.action = action
          table.insert(result.bindings, b)
          ::nextBinding::
        end
      elseif  k == "removed" then
        for i, b in ipairs(v) do
          if ignoreRemoved then
            log('E', 'bindings', "Ignoring 'removed' binding in file "..dumps(path).." that shouldn't contain any 'removed' binding: "..dumpbinding(b))
            goto nextRemoved
          end
          if b.control == nil then
            log('E', 'bindings', "Missing 'control' field on removed binding "..i.." in file "..path..": "..dumpbinding(b))
            goto nextRemoved
          end
          local action = core_input_actions.nameToUniqueName(b.action, vehicleName) -- this name-mangling is needed to prevent collisions with other vehicles' action names
          action = core_input_actions.upgradeAction(action)
          if not action then
            log('D', 'bindings', "Skipping invalid 'action' field on removed binding "..i.." in file "..path..": "..dumpbinding(b))
            goto nextRemoved
          end
          b.action = action
          table.insert(result.removed, b)
          ::nextRemoved::
        end
      else
        if result[k] and (result[k] ~= v) then
          log("W", "", "Overwriting inputmap field "..dumps(k)..": "..dumps(result[k]).." --> "..dumps(v).." (new value read from "..dumps(path)..")")
        end
        result[k] = v
      end
    end
  end
  return result
end

local function bindingListToDict(list)
  -- convert from a binding list, to a dictionary with control\0action as keys
  local result = {}
  if list == nil then return result end
  for _,v in pairs(list) do
    if v.action  == nil then log("W", "bindings", "Binding is missing the 'action' field: " ..dumpbinding(v)) end
    if v.control == nil then log("W", "bindings", "Binding is missing the 'control' field: "..dumpbinding(v)) end
    if v.action and v.control then
      if result[v.control.."\0"..v.action] then
        log("W", "", "Found duplicate binding. The last seen binding will override earlier bindings: "..dumps(v.control, v.action))
      end
      result[v.control.."\0"..v.action] = cleanBindingDefaults(v)
    end
  end
  return result
end

local function createBindingsDiff(old, new)
  -- create an empty diff, populate it with non-bindings information (guid, devtype, productname, etc)
  local result = { bindings = {}, removed = {}, version = 1 }
  for k,v in pairs(old) do
    if k ~= "bindings" and k ~= "removed" then result[k] = v end
  end

  -- duplicate provided bindings as dicts (to leave originals untouched, and for easier processing)
  local dictOld = bindingListToDict(old.bindings)
  local dictNew = bindingListToDict(new.bindings)

  -- mark bindings that are to be removed
  local markedForRemoval = {}
  for k,v in pairs(dictOld) do
    if dictNew[k] == nil then
      markedForRemoval[k] = v
    end
  end

  -- process removed bindings
  for k,v in pairs(markedForRemoval) do
    log('D', 'bindings', "Removed binding (added to list): "..dumps(v.control).." : "..dumps(v.action))
    table.insert(result.removed, { control = v.control, action = v.action } )
    dictOld[k] = nil
  end

  -- process modified/new bindings
  for k,v in pairs(dictNew) do
    if dumps(dictOld[k]) ~= dumps(v) then
      if dictOld[k] then log('D', 'bindings', "Modified binding (added to list): "..dumps(v.control).." : "..dumps(v.action))
      else           log('D', 'bindings',    "New binding (added to list): "..dumps(v.control).." : "..dumps(v.action)) end
      table.insert(result.bindings, cleanBindingDefaults(v) )
    end
  end
  -- remove empty lists
  if tableIsEmpty(result.removed) then result.removed  = nil end
  if tableIsEmpty(result.bindings) then result.bindings = nil end
  if result.bindings == nil and result.removed == nil then result = nil end

  return result
end

local function applyResponseCurve(contents, path, curveInverted)
  for i,binding in pairs(contents.bindings) do
    if binding.ffb and binding.ffb.responseCorrected then
      local f = readFile(path)
      if not f then
        log('E', 'bindings', "Error parsing response curve in file "..path..": cannot open file")
        return contents
      end
      local xcolumn = nil
      local ycolumn = nil
      local responseCurve = {}
      for line in f:gmatch("([^\n\r]*)") do
        if line ~= "" then
          local x = nil
          local y = nil
          local column = 0
          for field in line:gmatch("([^,|]*)") do
            field = field:match("^%s*(.-)%s*$")
            if field ~= "" then
              local v = tonumber(field)
              if v then
                if xcolumn == nil or ycolumn == nil then
                  log("W", "", "Cannot recognize column headers in FFB response curve file: "..dumps(path))
                  if xcolumn == nil then
                    log("W", "", "Assuming X column is at: "..dumps(column))
                    xcolumn = column
                  else
                    if ycolumn == nil then
                    log("W", "", "Assuming Y column is at: "..dumps(column))
                    ycolumn = column
                    end
                  end
                end
                if column == xcolumn then x = v end
                if column == ycolumn then y = v end
              else
                if field == "force"     then xcolumn = column end
                if field == "LinearForce" then xcolumn = column end
                if field == "deltaX"          then ycolumn = column end
                if field == "Linear Force Response" then ycolumn = column end
              end
            end
            column = column + 1
          end
          if x ~= nil and y ~= nil then
            table.insert(responseCurve, {x, y})
            --log("I", "", dumps({x,y}))
          else
            log("D", "bindings", "Skipping invalid datapoint line in FFB response curve file: \""..line.."\"")
          end
        end
      end
      if curveInverted then
        log("D", "", "Inverting curve path: "..dumps(path))
        for n,v in ipairs(responseCurve) do
        v[2], v[1] = v[1], v[2]
        end
      end
      --log("I", "", "Response curve: "..dumps(responseCurve))
      binding.ffb.responseCurve = responseCurve
    end
  end
  return contents
end

local function applyBindingsDiff(base, diff)
  -- duplicate provided bindings as dicts (to leave originals untouched, and for easier processing)
  diff = diff
  base = base
  local version = diff.version or base.version or 0
  local dictBase       = bindingListToDict(base.bindings)
  local dictDiffReplaced = bindingListToDict(diff.bindings)
  local dictDiffRemoved  = bindingListToDict(diff.removed )
  -- upgrade old diff format that had no support for duplicate bindings
  local allowDuplicates = version >= 1
  if not allowDuplicates then
      for k,v in pairs(dictDiffReplaced) do
        for kk,vv in pairs(dictBase) do
          if vv.control == v.control then
            log("I", "bindings", "Upgrading inputmap from old v0 format - Removing duplicate binding: "..dumps(v.control).." : "..dumps(v.action))
            dictDiffRemoved[kk] = vv
          end
        end
      end
  end

  -- merge removed bindings
  for k,v in pairs(dictDiffRemoved) do
    if dictBase[k] == nil then
      log("D", "bindings", "Merge: trying to remove a binding that is not there anymore: "..dumps(v))
    end
    dictBase[k] = nil
  end

  -- merge new/modified bindings
  for k,v in pairs(dictDiffReplaced) do
    dictBase[k] = v
  end

  -- convert back to list
  local result = { bindings = {} }
  for _,v in pairs(dictBase) do table.insert(result.bindings, cleanBindingDefaults(v)) end
  return result
end

local function getWritingDir(vehicleName)
  if vehicleName then return "settings/inputmaps/"..vehicleName
  else          return "settings/inputmaps" end
end

local function getWritingPath(vehicleName, devicetype, pidvid)
  -- find out the most appropriate path to write an inputmap file
  local basedir = getWritingDir(vehicleName)
  if devicetype == "mouse" or devicetype == "keyboard" then
    return basedir.."/" .. devicetype .. ".diff"
  end
  return basedir.."/" .. pidvid:lower() .. ".diff"
end

local function getDeviceInfo(device)
  -- ask T3D information about the provided devname
  local guid = WinInput.getProductGUID(device)
  local productName = WinInput.getProductName(device)
  local pidvid = WinInput.getVendorIDProductID(device)
  --local battery = WinInput.getBatteryLevel(device)
  return guid, productName, pidvid, battery
end

-- locate all existing inputmap files for the specific device & vehicle
local function getInputmapPaths(devname, guid, productName, pidvid, vehicleName, suffix)
  local dirs = {
    vehicleName and ("vehicles/"..vehicleName.."/inputmaps") or "settings/inputmaps",
    vehicleName and ("settings/inputmaps/"..vehicleName) or nil,
  }
  local devicetype = string.split(devname, "%D+")[1] -- strip trailing number, if it exists (xinput0 -> xinput)
  local prefixes = { pidvid:lower(), devicetype:lower() }

  local result = {}
  for _,dir in ipairs(dirs) do
    for _,prefix in ipairs(prefixes) do
      for _,path in ipairs(FS:findFiles(dir, prefix:lower().."*."..suffix, 0, true, false)) do
        if tech_license.isAllowedInputmapPath(path) then
          table.insert(result, path)
        end
      end
    end
  end
  return result
end

local function ListToSet(list)
  -- {'a', 'b', 'c'} ==> {a=true, b=true, c=true}
  local res = {}
  for _,e in ipairs(list) do
    res[e] = true
  end
  return res
end
local function updateDevicesList(oldDevices)
  -- refreshes the list of plugged input devices, notifying UI of new/removed devices
  local newDevicesList = WinInput.getRegisteredDevices()
  local newDevicesSet = ListToSet(newDevicesList)
  local newDevices = {}
  -- first check for new or modified devices (using devname as the id)
  for _,device in ipairs(newDevicesList) do
    local guid, productName, pidvid, battery = getDeviceInfo(device)
    newDevices[device] = {guid, productName, pidvid}
    if oldDevices[device] == nil then
      -- a new devname was found: user just plugged it
      local msg = "Controller connected: "..productName
      local isCommonDevice = device == 'mouse0' or device == 'keyboard0'

      if not isCommonDevice then
        log("I", "bindings", msg.." ("..device.."/0x"..pidvid..")")
      end
      if string.startswith(device, "xinput") then
        local n = string.sub(device, -1, -1) -- get controller number (xinput3 -> 3)
        local event = {controller = n, connected = true}
        guihooks.trigger('XInputControllerUpdated', event)
      elseif not isCommonDevice then
        ui_message(msg)
      end
    else
      if oldDevices[device][3] ~= pidvid then
        -- the pidvid of a devname has changed! new drivers have been loaded by Windows, or user has replaced a device veeery quickly
        local msg = "Controller changed: "..productName
        log("I", "bindings", msg.." ("..device.."/0x"..pidvid..")")
        ui_message(msg)
      end
    end
  end
  -- now check for removed devices
  for device,_ in pairs(oldDevices) do
    if newDevicesSet[device] == nil then
      local guid = oldDevices[device][1]
      local productName = oldDevices[device][2]
      local pidvid = oldDevices[device][3]
      local msg =  "Controller unplugged: "..productName
      log("I", "bindings", msg.." ("..device.."/0x"..pidvid..")")
      if string.startswith(device, "xinput") then
        local n = string.sub(device, -1, -1) -- get controller number (xinput3 -> 3)
        local event = {controller = n, connected = false}
        guihooks.trigger('XInputControllerUpdated', event)
      else
        ui_message(msg)
      end
    end
  end
  return newDevices
end

-- read the default bindings, then custom diff bindings (if not "default"), join them, and return the resulting (full) list of bindings
local function getBindings(devname, guid, productName, pidvid, vehicleName, default)
  local curvePath = nil -- response curve correction file (lut/log/fcm/csv)
  local curveInverted = false
  if not default then
    -- hardcoded 'wheel' in file search, as some ffb steering wheels identify themselves as 'joystick', and users don't know what that implies
    curvePath = curvePath or getInputmapPaths("wheel", guid, productName, pidvid, vehicleName, "lut")[1]
    if curvePath then curveInverted = true end -- only for LUT files
    curvePath = curvePath or getInputmapPaths("wheel", guid, productName, pidvid, vehicleName, "log")[1]
    curvePath = curvePath or getInputmapPaths("wheel", guid, productName, pidvid, vehicleName, "fcm")[1]
    curvePath = curvePath or getInputmapPaths("wheel", guid, productName, pidvid, vehicleName, "csv")[1]
  end

  local devicetype = string.split(devname, "%D+")[1] -- strip trailing number, if it exists (xinput0 -> xinput)

  local diffPaths = {}
  if not default then diffPaths = getInputmapPaths(devicetype, guid, productName, pidvid, vehicleName, "diff") end
  local               basePaths = getInputmapPaths(devicetype, guid, productName, pidvid, vehicleName, "json")

  local base = readBindingsFromDisk(basePaths, vehicleName, true)
  local diff = readBindingsFromDisk(diffPaths, vehicleName, false)

  local result = applyBindingsDiff(base, diff)
  if curvePath then result = applyResponseCurve(result, curvePath, curveInverted) end
  result.guid, result.vidpid, result.name, result.devicetype = guid, pidvid, productName, devicetype
  return result
end

local function getAllBindings(devices, assignedPlayers)
  local result = {}

  -- temp fix for having force feedback: wheel0 is before xinput0
  local sortedNodeKeys = tableKeys(devices)
  table.sort(sortedNodeKeys)

  for i, devname in ipairs(sortedNodeKeys) do
    local info = devices[devname]
    local player = assignedPlayers[devname]

    -- normal bindings
    local contents = getBindings(devname, info[1], info[2], info[3], nil, false)

    -- vehicle specific bindings
    local vehicle = be:getPlayerVehicle(player)
    if vehicle then
      local vehicleName = vehicle:getJBeamFilename()
      local vehicleContents = getBindings(devname, info[1], info[2], info[3], vehicleName, false)

      -- fill/rewrite metadata (all except bindings themselves: guid, devtype...)
      for k,v in pairs(vehicleContents) do
        if k ~= "bindings" then contents[k] = v end
      end

      -- now append all new bindings
      for _,b in ipairs(vehicleContents.bindings) do
        table.insert(contents.bindings, deepcopy(b))
      end
    end

    for _,b in ipairs(contents.bindings) do b.player = player end
    table.insert(result, {devname = devname, contents = contents})
  end

  return result
end

local function getControlForAction(actionName)
  if not actionToControl then
    actionToControl = {}
    for _, device in ipairs(M.bindings) do
      for _, binding in ipairs(device.contents.bindings) do
        if not actionToControl[binding.action] then
          actionToControl[binding.action] = binding.control
        end
      end
    end
  end
  return actionToControl[actionName]
end

-- send current state of ffb checks to the UI side
local ffbUnsafeFrequency -- stores information about the last known state of ffb update rate safetiness
local ffbUnsafeFrequencyToasterNotified -- used to avoid constantly hitting the user with the toaster warning
local function ffbUnsafeFrequencyNotifyUI()
  if not ffbUnsafeFrequencyToasterNotified and ffbUnsafeFrequency and not ffbUnsafeFrequency.isSafe then
    guihooks.trigger("toastrMsg", {type="warning", title="Possible performance issue", msg="More details in Options > Controls > Force Feedback", config={timeOut=20000}})
    ffbUnsafeFrequencyToasterNotified = true
  end
  guihooks.trigger('ffbUnsafeFrequency', ffbUnsafeFrequency)
end

-- will re-check the safety of ffb update rate from scratch
local function ffbUnsafeFrequencyRequest()
  ffbUnsafeFrequency = nil
  be:queueAllObjectLua("hydros.notifyUIffbUnsafe()")
  ffbUnsafeFrequencyNotifyUI()
end

local function notifyUI(reason)
  ffbUnsafeFrequencyRequest()
  guihooks.triggerRawJS('ControllersChanged', WinInput.getControllersInfoJson())
  guihooks.trigger('AssignedPlayersChanged', M.assignedPlayers)

  -- strip actions from vehicles other than currently focused one (since those will show up with no bindings)
  local vehicle = be:getPlayerVehicle(0)
  local vehicleName = vehicle and vehicle:getJBeamFilename()
  local currentActions = {}
  for actionName,action in pairs(core_input_actions.getActiveActions()) do
    if action.vehicle == nil or action.vehicle == vehicleName then
      currentActions[actionName] = action
    end
  end

  local result = { actionCategories= core_input_categories,
               actions       = currentActions,
               bindingTemplate = fillNormalizeBindingDefaults({}),
               bindings      = M.bindings }
  guihooks.trigger('InputBindingsChanged', result)
end

local filechangeTimeout = nil -- seconds
-- filesystem notifications are unreliable on some platforms. since the input system relies on them in order to know when bindings have changed, this function allows to emulate a notification that we can trigger in certain cases where we know for sure (due to our own code) that a FS notification should be triggering
local function forceRefresh(seconds)
  filechangeTimeout = seconds or 0
end

-- remove custom user bindings of the desired device, reverting back to defaults
local function resetDeviceBindings(devname, guid, name, pidvid, vehicleName)
  for _,suffix in ipairs({"json", "diff"}) do
    for _,path in ipairs(getInputmapPaths(devname, guid, name, pidvid, vehicleName, suffix)) do
      FS:removeFile(path) -- will only be removed if stored in user folder (game install folder is read-only)
      forceRefresh()
    end
  end
end

-- take a full set of customized bindings, compare them to the defaults (if they exist), and save the resulting diff on disk
local function saveBindingsFileToDisk(data, vehicleName)
  -- compute diff from default to desired data
  resetDeviceBindings(data.devicetype, data.guid, data.name, data.vidpid, vehicleName) -- revert to defaults (so we can read them and use as reference for diff)
  local defaultData = getBindings(data.devicetype, data.guid, data.name, data.vidpid, vehicleName, true)
  local diffData = createBindingsDiff(defaultData, data)

  -- write the diff to disk
  if diffData == nil then return false end
  -- convert from vehicle__actionname to actionname. this name-mangling is needed to prevent collisions with other vehicles' action names
  for _,b in pairs(diffData.bindings or {}) do b.action = core_input_actions.uniqueNameToName(b.action, vehicleName) end
  for _,b in pairs(diffData.removed  or {}) do b.action = core_input_actions.uniqueNameToName(b.action, vehicleName) end

  local path = getWritingPath(vehicleName, data.devicetype, data.vidpid)
  if not jsonWriteFile(path, diffData, true) then -- some simple indentation
    log('E', 'bindings', "Couldn't write bindings file to: "..path)
    return false
  end
  forceRefresh()
  log("D", "bindings", "Custom bindings for "..data.name.." ("..data.devicetype.."/"..data.vidpid..") at: "..path)
end

-- data bindings may have mixed vehicle/generic bindings. split them up and save in separate files when necessary
local function saveBindingsToDisk(data)
  for _,binding in ipairs(data.bindings or {}) do
    fixBuggyBindingFromUISide(binding)
  end
  local inputmapTemplate = deepcopy(data)
  inputmapTemplate.bindings = {}

  -- 'inputmaps' will hold the generic ("none") bindings as well as each vehicle's bindings

  -- first we initialize them as empty. this forces empty inputmaps to be saved too (instead of being ignored because UI didn't mention the vehicle in incoming data)
  local inputmaps = { none=deepcopy(inputmapTemplate) }
  local vehicle = be:getPlayerVehicle(0)
  if vehicle then
    inputmaps[vehicle:getJBeamFilename()] = deepcopy(inputmapTemplate)
  end

  -- then we add them with whatever 'data' came from the UI side
  for _,b in ipairs(data.bindings) do
    local vehicleName = core_input_actions.getActiveActions()[b.action].vehicle
    local vehicleNameStr = vehicleName or "none" -- temporarily rename to 'none' for during this function
    b.player = nil -- clear variable used to let UI know which player's binding this is
    table.insert(inputmaps[vehicleNameStr].bindings, b)
  end

  -- save each of the computed split inputmaps to a separate file
  for vehicleNameStr,v in pairs(inputmaps) do
    local vehicleName = vehicleNameStr
    if vehicleName == "none" then vehicleName = nil end
    log("D", "bindings", "Saving "..tableSize(v.bindings).." bindings for vehicle: "..dumps(vehicleName))
    saveBindingsFileToDisk(v, vehicleName)
  end
end

local function notifyGE(reason)
  actionToControl = nil
  for i,s in pairs(ActionMap:getList())do
    for j,v in ipairs(s) do
      if v.name:endswith("ActionMap") then -- skip the editor (and similar) action maps
        scenetree[v.name]:clear()
      end
    end
  end

  for _,data in pairs(M.bindings) do
    sendBindingsToGE(data.devname, data.contents.bindings, M.assignedPlayers[data.devname])
  end

  if imgui then
    imgui.readGlobalActions()
  end
end

local function notifyHydros(veh, ffbConfig)
  veh:queueLuaCommand("hydros.onFFBConfigChanged("..serialize(ffbConfig)..")")
end

local function notifyFFB(reason)
  WinInput.updateFFBBindingParameters()
  local action = "steering"
  for _,veh in ipairs(getAllVehicles()) do
    local FFBID = veh:getFFBID(action) -- will automatically return -1 if no player is seated there with an ffb input controller
    if FFBID < 0 then
      notifyHydros(veh, nil)
      goto cont
    end
    local ffbConfigString = be:getFFBConfig(FFBID)
    local state, ffbConfig = pcall(json.decode, ffbConfigString)
    if state == false then
      log('E', "", "Couldn't decode ffbconfig JSON: "..tostring(ffbConfig))
      notifyHydros(veh, nil)
      goto cont
    end
    if ffbConfig == nil then
      log("E", "", "Got a nil ffbConfig for vehicle with ID "..dumps(veh:getId())..", ffb action "..dumps(action).." and FFFBID "..dumps(FFBID))
      notifyHydros(veh, nil)
      goto cont
    end
    local state, ffbparams = pcall(json.decode, ffbConfig.ffbParams)
    if state ~= true then
      log("E", "", "Couldn't parse FFB params:"..dumps(state).." & "..dumps(ffbparams).."\n"..dumps(ffbConfig.ffbParams))
      notifyHydros(veh, nil)
      goto cont
    end
    ffbConfig.ffbParams = ffbparams
    local response = {}
    response[action] = ffbConfig
    response[action]["FFBID"] = FFBID
    notifyHydros(veh, response)
    ::cont::
  end
end

M.bindings = {}
M.assignedPlayers = {}
local function notifyExtensions(reason)
  extensions.hook('onInputBindingsChanged', M.assignedPlayers)
end
local function notifyAll(reason)
  notifyGE(reason)
  notifyFFB(reason) -- must happen after notifyGE
  notifyUI(reason) -- must happen after notifyFFB
  notifyExtensions(reason)
end

local function resetAllBindings()
  -- remove all custom user bindings of currently plugged devices, reverting back to beamng-provided defaults

  -- normal bindings
  for devname,info in pairs(M.devices) do
    resetDeviceBindings(devname, info[1], info[2], info[3], nil)
  end
  FS:removeFile(getWritingDir(nil))
  forceRefresh()

  -- vehicle specific bindings
  for devname,info in pairs(M.devices) do
    local vehicle = be:getPlayerVehicle(M.assignedPlayers[devname])
    if vehicle then
      local vehicleName = vehicle:getJBeamFilename()
      resetDeviceBindings(devname, info[1], info[2], info[3], vehicleName)
      FS:removeFile(getWritingDir(vehicleName))
      forceRefresh()
    end
  end
end

-- is called whenever player switches to a new vehicle, or to an existing vehicle, or exits a vehicle is not driving anymore
-- new vehicle may have been added to the level, or it may be replacing an existing vehicle (which gets removed)
-- that's why we simply re-read all vehicles' actions, instead of keeping track of which vehicle went away and which didn't
local function onVehicleSwitched(oldId, newId, player)
  local oldVehicle = be:getObjectByID(oldId)
  local newVehicle = be:getObjectByID(newId)
  local oldName = oldVehicle and oldVehicle:getJBeamFilename() or "<none>"
  local newName = newVehicle and newVehicle:getJBeamFilename() or "<none>"
  if oldName ~= newName then
    M.assignedPlayers = core_multiseat.getAssignedPlayers(M.devices, true)
    M.bindings = getAllBindings(M.devices, M.assignedPlayers)
  end
  notifyAll("player #"..player.." switched from "..oldName.." to "..newName)
end

local function setMenuActionMapEnabled(enabled)
  if not scenetree.MenuActionMap then return end
  scenetree.MenuActionMap:setEnabled(enabled)
  M.isMenuActive = enabled
end

local function getAssignedPlayers()
  return M.assignedPlayers
end

local wasWalking
local function updateGFX(dtRaw)
  if filechangeTimeout then
    filechangeTimeout = filechangeTimeout - dtRaw
    if filechangeTimeout <= 0 then
      M.bindings = getAllBindings(M.devices, M.assignedPlayers)
      notifyAll("some inputmap file changed")
      filechangeTimeout = nil
    end
  end
  local isWalking = core_vehicle_manager and core_vehicle_manager.getPlayerVehicleData() and core_vehicle_manager.getPlayerVehicleData().mainPartName == "unicycle" and commands.isFreeCamera()
  if isWalking ~= wasWalking then
    wasWalking = isWalking
    local o = scenetree.findObject("VehicleSpecificActionMap")
    if o then o:setEnabled(not isWalking) end
  end
end

local function onFileChanged(filename, t)
  local actionsModified = string.startswith(filename, "/lua/ge/extensions/core/input/actions") and string.endswith(filename, "json")
  local bindingsModified = string.startswith(filename, "/settings/inputmaps/")
  if actionsModified or bindingsModified then
    forceRefresh(0.1)
  end
end
local function onDeviceChanged()
  M.devices = updateDevicesList(M.devices)
  M.assignedPlayers = core_multiseat.getAssignedPlayers(M.devices, true, true)
  M.bindings = getAllBindings(M.devices, M.assignedPlayers)
  notifyAll("a device changed")
end

local multiseatEnabled
local function onSettingsChanged()
  local newMultiseatEnabled = settings.getValue("multiseat")
  if newMultiseatEnabled == multiseatEnabled then return end
  multiseatEnabled = newMultiseatEnabled
  M.assignedPlayers = core_multiseat.getAssignedPlayers(M.devices, true, true)
  M.bindings = getAllBindings(M.devices, M.assignedPlayers)
  notifyAll("multiseat changed")
end

local function deprecatedNotifyAll(reason)
  log("W", "", "bindings.notifyAll has been deprecated in favour of bindings.notifyUI, please rewrite that call. Provided context was: "..dumps(reason))
  notifyUI("DEPRECATED "..dumps(reason))
end
local function deprecatedMenuActive(enabled)
  log("E", "", "bindings.menuActive has been deprecated in favour of the 'menuActionMapEnabled' boolean flag on javascript side (see main.js for examples). The default behaviour is probably working correctly already, in which case you can simply delete the call to menuActive. Stacktrace provided below so you can update the relevant code:")
  print(debug.tracesimple())
  M.setMenuActionMapEnabled(enabled)
end

local function onFirstUpdate()
  M.devices = updateDevicesList(M.devices)
  M.assignedPlayers = core_multiseat.getAssignedPlayers(M.devices, true)
  M.bindings = getAllBindings(M.devices, M.assignedPlayers)
  notifyAll("input_bindings.lua init")
end

-- used by vlua side to notify gelua about state of ffb update rate safety
local function ffbUnsafeFrequencySet(data)
  if not ffbUnsafeFrequency -- if this is the first info we receive...
      or (data and not data.isSafe) then -- or if it's not the first but the ffb rate is unsafe...
    ffbUnsafeFrequency = data -- then note it down
  end
  ffbUnsafeFrequencyNotifyUI()
end


M.onFirstUpdate = onFirstUpdate
M.resetAllBindings = resetAllBindings
M.saveBindingsToDisk = saveBindingsToDisk
M.notifyAll = deprecatedNotifyAll
M.notifyUI = notifyUI
M.menuActive = deprecatedMenuActive
M.setMenuActionMapEnabled = setMenuActionMapEnabled
M.getAssignedPlayers= getAssignedPlayers
M.onFileChanged = onFileChanged
M.onDeviceChanged = onDeviceChanged
M.onSettingsChanged = onSettingsChanged
M.onVehicleSwitched = onVehicleSwitched
M.updateGFX = updateGFX
M.getControlForAction = getControlForAction
M.ffbUnsafeFrequencySet = ffbUnsafeFrequencySet
M.ffbUnsafeFrequencyRequest = ffbUnsafeFrequencyRequest

return M
