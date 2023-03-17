-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

-- holds all known menu items

local menuTree = {}

local callStack = {} -- contains the history of menus so one can go 'back' or 'up' the menus again

-- transitional state: these values can change whereas the UI is not visible yet, use uiVisible to check if the UI is shown
local currentLevel = nil -- level that the menu is in right now
local currentMenuItems = nil -- items that are displaying
local uiVisible = false
local vehicleMenuItems = {}

local vehicleWaitFrames = 0 -- counter for timeout waiting for vehicle menu items

local titles = {"ui.radialmenu2.main_menu"}
local contexts = {nil}
local initilized = false

-- if its shown
local function isEnabled()
  return uiVisible
end

--[[
- definition:
 * items = items inside a menu
 * entries : a single thing that should produce one ore more menu entries
]]

-- this function adds a new menu entry
local function addEntry(_args)
  local args = deepcopy(_args) -- do not modify the outside table by any chance
  if  type(args.generator) ~= 'function' and (type(args.title) ~= 'string' or (type(args.onSelect) ~= 'function' and type(args.goto) ~= 'string')) then
    -- TODO: add proper warning/error
    log('W', 'quickaccess', 'Menu item needs at least a title and an onSelect function callback: ' .. dumps(args))
    --return false
  end

  -- defaults
  if args.level == nil then args.level = '/' end
  if args.desc == nil then args.desc = '' end

  if type(args.level) ~= 'string' then
    log('E', 'quickaccess', 'Menu item level incorrect, needs to be a string: ' .. dumps(args))
    return false
  end
  if string.sub(args.level, string.len(args.level)) ~= '/' then args.level = args.level .. '/' end -- make sure there is always a trailing slash in the level

  if menuTree[args.level] == nil then
    -- add new level if not existing
    menuTree[args.level] = {}
  end

  if args.uniqueID then
    -- make this entry unique in this level
    local replaced = false
    for k, v in pairs(menuTree[args.level]) do
      if v.uniqueID == args.uniqueID then
        menuTree[args.level][k] = args
        replaced = true
        break
      end
    end
    if not replaced then
      table.insert(menuTree[args.level], args)
    end
  else
    -- always insert
    table.insert(menuTree[args.level], args)
  end

  return true
end

local function pushTitle(t, c)
  table.insert(titles, t)
  table.insert(contexts, c)
end

local function resetTitle()
  titles = {"ui.radialmenu2.main_menu"}
  contexts = {nil}
end

local function registerDefaultMenus()
  -- switch to other vehicles
  addEntry({ level = '/manage/', generator = function(entries)
    if not core_input_actionFilter.isActionBlocked("switch_next_vehicle") then
      if be:getObjectCount() > 0 then
        table.insert(entries,{ level = '/manage/', title = 'ui.radialmenu2.Manage.Remove', icon='material_delete_forever', onSelect = function() core_vehicles.removeCurrent() extensions.hook("trackNewVeh") return {'hide'} end} )
        table.insert(entries,{ level = '/manage/', title = 'ui.radialmenu2.Manage.Clone', icon='radial_clone', onSelect = function() core_vehicles.cloneCurrent() extensions.hook("trackNewVeh") return {'hide'} end} )
      end

      if be:getObjectCount() < 2 then
        return
      elseif be:getObjectCount() == 2 then
        table.insert(entries, { title = 'ui.radialmenu2.Manage.Switch', icon = 'material_swap_horiz', onSelect = function()
          be:enterNextVehicle(0, 1)
          return {'reload'}
        end})
      elseif be:getObjectCount() > 2 then
        table.insert(entries, { title = 'ui.radialmenu2.Manage.Switch', icon = 'material_swap_horiz', goto = '/switch_vehicles/'})
      end
    end
  end})

  -- vehicle list menu
  addEntry({ level = '/switch_vehicles/', icon = 'radial_switch', generator = function(entries)
    if be:getObjectCount() == 0 or core_input_actionFilter.isActionBlocked("switch_next_vehicle") then return end
    local vid = be:getPlayerVehicleID(0) or -1 -- matches all

    local function switchToVehicle(objid)
      local veh = be:getObjectByID(objid)
      if veh then
        be:enterVehicle(0, veh)
        return true
      end
    end

    for i = 0, be:getObjectCount()-1 do
      local veh = be:getObject(i)
      if veh:getId() ~= vid then
        local vehicleName = veh:getJBeamFilename()
        local vehicleNameSTR = vehicleName --default name use jbeam folder
        local filePath = "/vehicles/"..vehicleName.."/info.json"
        local vicon = "material_directions_car"
        if FS:fileExists(filePath) then --check for main info
          local mainInfo = jsonReadFile(filePath)
          veh = scenetree.findObjectById(veh:getId())
          local vehConfig = string.match(veh.partConfig, "([^./]*).pc")
          --print("vehConfig = "..dumps(veh.partConfig) .. "   v="..dumps(vehConfig))
          if veh.partConfig:sub(1,1) == "{" or veh.partConfig:sub(1,1) == "[" then
            vehConfig = "*custom*"
          elseif not vehConfig or string.len(vehConfig) ==0 then
            vehConfig = mainInfo["default_pc"]
            if vehConfig == nil then vehConfig = "" end
          end
          filePath = "/vehicles/"..vehicleName.."/info_"..(vehConfig or "")..".json"
          if FS:fileExists(filePath) then --check info of pc
            local InfoConfig = jsonReadFile(filePath)
            if InfoConfig["Type"]=="PropParked" or InfoConfig["Type"]=="PropTraffic" then goto skipObj end
            vehicleNameSTR = mainInfo["Name"] .. "\\n" .. (InfoConfig["Configuration"] or "")
            -- vicon = "vehicles/"..vehicleName.."/".. vehConfig .."_garage_side.png"
          else
            vehicleNameSTR = mainInfo["Name"] .. "\\n" .. vehConfig
            --vicon = "Body Style"
          end
          -- if not FS:fileExists(vicon) then vicon = "material_directions_car" end --if picture doesn't exist, avoid nasty CEF no picture
          -- print("vehicleName="..vehicleName.."  vehConfig="..dumps(vehConfig).."\ttype="..dumps(mainInfo["Type"]))
          if mainInfo["Type"] then
            if mainInfo["Type"]== "Trailer" then vicon = "radial_couplers" end
            if mainInfo["Type"]== "Prop" then vicon = "radial_prop" end
          end
        end
        local objid = veh:getId()
        table.insert(entries, {
          title = vehicleNameSTR,
          icon = vicon,
          onSelect = function()
            switchToVehicle(objid)
            return {'reload'}
          end
        })
      end
      ::skipObj::
    end
  end
  })

  -- manage menu
  addEntry({ level = '/', title = 'ui.radialmenu2.Manage', goto = '/manage/', icon = 'material_build'} )

  addEntry({ level = '/manage/', generator = function(entries)
    if not core_input_actionFilter.isActionBlocked("vehicle_selector") then
      local e = {title = 'ui.radialmenu2.Manage.Select', icon = 'material_directions_car',  onSelect = function() guihooks.trigger('ChangeState', {state = 'menu.vehicles'}) ; return {'hideMeOnly'} end}
      table.insert(entries, e)
    end
  end})

  addEntry({ level = '/funstuff/', generator = function(entries)
    if not core_input_actionFilter.isActionBlocked("forceField") then
      local e = {title = 'ui.radialmenu2.funstuff.ForceField', icon = 'radial_boom',  onSelect = function() extensions.gameplay_forceField.toggleActive() return {"reload"} end}
      if extensions.gameplay_forceField.isActive() then e.color = '#ff6600' end
      table.insert(entries, e)
    end
  end})

  addEntry({ level = '/ai/', generator = function(entries)
    table.insert(entries, { title = 'ui.radialmenu2.traffic', priority = 53, goto = '/ai/traffic/', icon = 'material_traffic' })
  end})

  addEntry({ level = '/ai/traffic/', generator = function(entries)
    if not core_input_actionFilter.isActionBlocked("toggleTraffic") then
      table.insert(entries, { title = 'ui.radialmenu2.traffic.stop', icon = 'radial_stop', onSelect = function()
        extensions.gameplay_traffic.deactivate(true)
        extensions.hook("stopTracking", ({Name = "TrafficEnabled"}))
        return {"hide"}
      end})
      table.insert(entries, { title = 'ui.radialmenu2.traffic.remove', priority = 62, icon = 'material_delete', onSelect = function()
        extensions.gameplay_traffic.deleteVehicles()
        extensions.hook("stopTracking", ({Name = "TrafficEnabled"}))
        return {"hide"}
      end})
      table.insert(entries, { title = 'ui.radialmenu2.traffic.spawnNormal', priority = 63, icon = 'material_directions_car', onSelect = function()
        extensions.gameplay_traffic.setupTrafficWaitForUi()
        extensions.hook("startTracking", ({Name = "TrafficEnabled"}))
        return {"hide"}
      end})
      table.insert(entries, { title = 'ui.radialmenu2.traffic.spawnPolice', priority = 64, icon = 'radial_chase_me', onSelect = function()
        extensions.gameplay_traffic.setupTrafficWaitForUi(nil, 0.4)
        extensions.hook("startTracking", ({Name = "TrafficEnabled"}))
        return {"hide"}
      end})
      if be:getObjectCount() > 1 then
        table.insert(entries, { title = 'ui.radialmenu2.traffic.start', priority = 65, icon = 'material_play_circle_filled', onSelect = function()
          extensions.gameplay_traffic.setTrafficVars({aiMode = "traffic"})
          extensions.gameplay_traffic.activate()
          extensions.hook("startTracking", ({Name = "TrafficEnabled"}))
          return {"hide"}
        end})
      end
    end
  end})
  --dump(menuTree)
end

-- we got all the data required, show the menu
local function _assembleMenuComplete()
  if not currentMenuItems then return end
  --log('D', 'quickaccess', '_assembleMenuComplete: ' .. dumps(currentMenuItems))

  local objID = be:getPlayerVehicleID(0)
  if objID >= 0 and vehicleMenuItems[objID] then
    -- first: remove any items that are from this object from the current list first
    for i = #currentMenuItems, 1, -1 do
      if type(currentMenuItems[i].objID) == 'number' and currentMenuItems[i].objID == objID then
        table.remove(currentMenuItems, i)
      end
    end
    -- second: add the current ones
    for itmKey, itm in pairs(vehicleMenuItems[objID]) do
      itm.objID = objID
      itm.orgMenuID = itmKey
      table.insert(currentMenuItems, itm)
    end
  end

  -- sort the entries
  table.sort(currentMenuItems, function(a, b)
      --print("SORT: >> " .. dumps(a) .. ' / ' .. dumps(b))
      if a.priority == b.priority then
        if type(a.title) == 'string' and type(b.title) == 'string' then
          return a.title:upper() < b.title:upper()
        end
        -- no title, put at the end
        return 99
      end
      -- prevent nils
      local av = a.priority
      if av == nil then av = 999 end
      local bv = b.priority
      if bv == nil then bv = 999 end
      return av < bv
    end)

  --log('D', 'quickaccess', 'opening menu: ' .. dumps(currentMenuItems))
  if #callStack > 0 then
    local haveBackBtn = -1
    for k,v in pairs(currentMenuItems) do
      if v.title == 'ui.radialmenu2.back' and v.icon == 'material_arrow_back' then
        --log('I', 'quickAccess', "remove "..dumps(k) )
        table.remove(currentMenuItems,k)--remove the back button to be sure it's always in the center. avoid trouble with the switch vehicule
        break
      end
    end
    local mid = math.floor(#currentMenuItems/2)+1
    local lvl = "/"--currentMenuItems[#currentMenuItems]['level']
    table.insert(currentMenuItems, mid, {level=lvl, title = 'ui.radialmenu2.back', icon='material_arrow_back', onSelect = function() return {'back'} end})

  end

  uiVisible = true
  local data = {
    canGoBack = #callStack > 0,
    items = currentMenuItems,
    title = titles,
    context = contexts,
  }
  --log('E', 'quickaccess', 'opening menu: ' .. dumps(currentMenuItems))
  guihooks.trigger('QuickAccessMenu', data)
end

local function vehicleItemsCallback(objID, level, items)
  --log('D', 'quickAccess.vehicleItemsCallback', 'got items from id: ' .. tostring(objID) .. ' for level ' .. tostring(level) .. ' : ' .. dumps(items))

  if currentLevel == nil then
    --log('E', 'quickaccess', 'vehicle delivered items, even though the menu is inactive: ' .. tostring(objID))
    return
  end
  --print(">>> vehicleItemsCallback "..tostring(objID) .. '/' .. dumps(items))
  vehicleMenuItems[objID] = items
  -- no need to wait anymore
  vehicleWaitFrames = 0
  _assembleMenuComplete()
end

-- open the menu in a specific level
local function show(level)
  if type(level) ~= 'string' then level = '/' end -- default to the root

  if level == '/' then
    resetTitle()
  end

  local entries = deepcopy(menuTree[level] or {}) -- make a copy, the generators modify the menu below, this should not be persistent
  currentMenuItems = {}
  currentLevel = level
  --log('D', 'currentLevel-show', tostring(currentLevel))

  for _, e in pairs(entries) do
    if type(e) == 'table' then
      if type(e.generator) == 'function' then
        e.generator(entries)
      else
        table.insert(currentMenuItems, e)
      end
    end
  end

  -- now ask the active vehicle for any items
  local vehicle = be:getPlayerVehicle(0)
  if vehicle then
    --print(">>>>> REQUESTING ITEMS from ID: " .. tostring(veh:getId()))
    vehicle:queueLuaCommand('extensions.core_quickAccess.requestItems("' .. tostring(currentLevel) .. '")')
    -- we give the vehicle 4 gfx frames to add items
    vehicleWaitFrames = 4
  else
    -- no vehicle -- no need to wait, show menu directly
    _assembleMenuComplete()
  end

  return true
end

-- go to another level, saving the history
local function gotoLevel(level)
  --log('D', 'quickaccess', 'gotoLevel: ' .. tostring(currentLevel))
  if currentLevel ~= nil then
    table.insert(callStack, currentLevel)
  end
  return show(level)
end

local function hide()
  currentMenuItems = nil
  currentLevel = nil
  vehicleWaitFrames = 0
  --log('D', 'currentLevel-hide', tostring(currentLevel))
  uiVisible = false
  guihooks.trigger('QuickAccessMenu') -- nil = disabled
  resetTitle()
end

local function reload()
  if currentLevel then show(currentLevel) end
end

local function back()
  --log('D', 'quickaccess', 'back action: ' .. dumps(callStack))
  if currentLevel == nil then return end -- not visible: no way to go back, return
  if not callStack or #callStack == 0 then
    -- at top to the history: close?
    --return hide()
    return false
  end

  table.remove(titles, #titles)
  table.remove(contexts, #contexts)
  local oldLevel = callStack[#callStack]
  table.remove(callStack, #callStack)
  show(oldLevel)
end

local function itemSelectCallback(actionResult)
  log('D', 'quickaccess.itemSelectCallback', 'called: ' .. dumps(actionResult))
  if type(actionResult) ~= 'table' then
    log('E', 'quickaccess.itemSelectCallback', 'invalid item result args: ' .. dumps(actionResult))
    return
  end
  if actionResult[1] == 'hide' then
    hide()
    guihooks.trigger('MenuHide')
  elseif actionResult[1] == 'reload' then
    reload()
  elseif actionResult[1] == 'goto' then
    gotoLevel(actionResult[2])
  elseif actionResult[1] == 'back' then
    back()
  elseif actionResult[1] == 'hideMeOnly' then
    hide()
  end
end

local function itemAction(item)
  if item == nil then return end
  --log('D', 'quickAccess', "itemAction" .. dumps(item))

  -- remote item? call vehicle then
  if item.objID then
    local veh = be:getObjectByID(item.objID)
    if not veh then
      log('E', 'quickaccess', 'unable to select item. vehicle got missing: ' .. tostring(objID) .. ' - menu item: ' .. dumps(item))
      return
    end
    veh:queueLuaCommand('extensions.core_quickAccess.selectItem(' .. serialize(item.orgMenuID) .. ')')
    return
  end

  -- goto = dive into this new sub menu
  if type(item.goto) == 'string' then
    table.insert(titles, item.title)
    itemSelectCallback({'goto', item.goto})
    return true

  elseif type(item.onSelect) == 'function' then
    itemSelectCallback(item.onSelect(item))
    return true
  end
  -- default: no idea how to handle this
  log('E', 'quickAccess.itemAction', 'Item selected with no idea on what to do. "onSelect" missing? ' .. dumps(item))
  itemSelectCallback({'error', 'unknown_action'})
  return false
end

local function onInit()
  if not initilized then
    registerDefaultMenus()
    initilized = true
  end
  hide()
  --print("Menu function tree:")
  --dump(menuHooks)
end

-- callback from the
local function selectItem(id)
  if type(id) ~= 'number' then return end
  if currentMenuItems == nil then return end
  local m = currentMenuItems[id]
  if m == nil then
    log('E', 'quickAccess.selectItem', 'item not found: ' .. tostring(id))
  end
  itemAction(m)
end

local function setEnabled(enabled, centerMouse)
  if enabled then
    --guihooks.trigger('ChangeState', 'play') -- ensure we're not in menus, since UI apps are hidden while in menus
    callStack = {} -- reset the callstack
    show()
  else
    hide()
  end
  guihooks.trigger('quickAccessEnabled', enabled, centerMouse)
end


local lastTimeMoved = 0

local function getMovedRadialLastTimeMs()
  return lastTimeMoved
end


local function moved()
  lastTimeMoved = Engine.Platform.getSystemTimeMS()
end

local function onUpdate()
  -- logic for the menu assembling timeout
  if vehicleWaitFrames > 0 then
    --print(vehicleWaitFrames)
    vehicleWaitFrames = vehicleWaitFrames - 1
    if vehicleWaitFrames == 0 then
      log('E', 'quickaccess', 'vehicle didn\'t respond in time with menu items, showing menu anyways ...')
      _assembleMenuComplete()
    end
  end
end

local function vehicleItemSelectCallback(objID, args)
  log('D', 'quickAccess.vehicleItemSelectCallback', 'got result from id: ' .. tostring(objID) .. ' : ' .. dumps(args))
  --we don't need objID for now
  itemSelectCallback(args)
end

local function onVehicleSwitched()
  -- if switchign vehicles while the menu is show, reload it
  if uiVisible and currentLevel then
    reload()
  end
end

local function centerMouseCallback(x, y)
  -- broken
  --setMouseCursorPosition(x, y)
end

-- public interface
M.onInit = onInit
M.vehicleItemsCallback = vehicleItemsCallback
M.vehicleItemSelectCallback = vehicleItemSelectCallback
M.onUpdate = onUpdate
M.onVehicleSwitched = onVehicleSwitched
M.pushTitle = pushTitle
M.resetTitle = resetTitle

-- public API
M.addEntry = addEntry
M.registerMenu = function() log('E', 'quickAccess', 'registerMenu is deprecated. Please use quickAccess.addEntry: ' .. debug.traceback()) end

-- API towards the UI
M.selectItem = selectItem
M.back = back
M.isEnabled = isEnabled
M.moved = moved
M.getMovedRadialLastTimeMs = getMovedRadialLastTimeMs
M.centerMouseCallback = centerMouseCallback

-- input map
M.setEnabled = setEnabled

return M
