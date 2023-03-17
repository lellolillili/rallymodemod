-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = "busRouteManager"
local busLines={routes={}}

local function logtagFN(fn)
  if fn == nil then return logTag end
  return logTag.."."..fn
end

local function vehicleCommand(id,cmd,arg)
  -- log("E", logTag, "vehicleCommand id='"..tostring(id).."' cmd='"..tostring(cmd).."' arg='"..dumps(arg).."'")
  if arg ==nil then arg =""end
  if id then
    local veh = be:getObjectByID(id)
    if veh then
      veh:queueLuaCommand("controller.onGameplayEvent('"..cmd.."',"..serialize(arg)..")")
    else
      log("E", logTag, "vehicle ID '"..tostring(id).."' is invalid  cmd='"..tostring(cmd).."'")
    end
  end
end

local function load(mapFolder)
  local jFiles = FS:findFiles(mapFolder.."/buslines/", '*.buslines.json', -1, true, false)
  for _,jFilename in pairs(jFiles) do
    local data = jsonReadFile(jFilename)
    if data == nil then log('E', logTag, "Error while loading file "..jFilename)
    else
      --log('I',logtagFN("load"),"Loaded "..jFilename)
      if data.version == 1 then
        for k,v in pairs(data.routes) do table.insert( busLines.routes, v ) end
      end
      -- log('I',logtagFN("load"),"data.routes= "..dumps(data.routes))
    end
  end

  --get trigers pos
  local triggerPos = {}
  local triggerFolder = scenetree.findObject("busstops")
  if triggerFolder and triggerFolder:getClassName() == "SimGroup" then
    for i=0, triggerFolder:getCount() - 1, 1 do
      local trigger = triggerFolder:getObject(i)
      if trigger and trigger:getClassName() == "BeamNGTrigger" then
        trigger = Sim.upcast(trigger)  --cast again from cpp to lua wrapper
        if trigger.type == "busstop" then
          triggerPos[trigger.name] = {trigger.name,trigger.stopName, vec3(trigger:getPosition()):toTable(), quat(trigger:getRotation()):toTable(), vec3(trigger:getScale()):toTable()}
        end
      end
    end
  end
  -- log('E',logtagFN("load"),"triggerNames="..dumps(triggerNames))
  -- log('E',logtagFN("load"),"triggerPos="..dumps(triggerPos))


  --checking triggers exist
  for _,route in pairs(busLines.routes) do
    local task_data = {}
    for i,task in pairs(route.tasklist) do
      if triggerPos[task] then
        table.insert( task_data, triggerPos[task])
      else log("E", logtagFN("load.chkTrigger"), "Trigger '"..tostring(task).."' doesn't exist on this map or type != 'busstop'")
      end
    end
    route.tasklist = task_data
  end
  -- log('E',logtagFN("load"),"after CHK, busLines="..dumps(busLines))
end

local function init()
  busLines={routes={}}
  local missionFile = getMissionFilename()
  local levelDir, filename, ext = path.split(missionFile, "(.-)([^/]-([^%.]*))$")
  --print("levelDir="..levelDir.."  filename=".. filename)
  load(levelDir)
end

--from GE core_busLine.getLine(nil,42,"a")
--from veh
local function setLine(vehId, routeID, variance)
  for k,v in pairs(busLines.routes) do
    if (v.routeID == routeID and v.variance == variance) then
      if vehId then
        vehicleCommand(vehId,"bus_setLineInfo",v)
      end
      return v
    end
  end
  log('E',logtagFN("getLine"),"could not find the line "..dumps(routeID).." "..dumps(variance))
  return nil
end

local function onAtStop(data)
  --log("E",logTag,"onAtStop data="..dumps(data))
  -- guihooks.trigger('Message', {ttl = 3, msg = 'onAtStop', icon = 'directions_bus'})
  vehicleCommand(data.subjectID,"bus_onAtStop",data)
end

local function onDepartedStop(data)
  -- guihooks.trigger('Message', {ttl = 5, msg = 'onDepartedStop', icon = 'directions_bus'})
  vehicleCommand(data.subjectID,"bus_onDepartedStop",data)
end

local function onBeamNGTrigger(data)
  if data.type and data.type == "busstop" then
    -- log("E",logTag,"onBeamNGTrigger data="..dumps(data))
    if data.event == "enter" then onAtStop(data) end
    if data.event == "exit" then onDepartedStop(data) end
    if data.event == "tick" then
      vehicleCommand(data.subjectID,"bus_onTriggerTick",data)
    end
  end

end

local function onBusUpdate(state)
  -- local data = {}
  -- data.texture = 'art/arrow_waypoint_1.dds'
  -- data.position = state.pos
  -- data.color = ColorF(0.2, 0.53, 1, alpha )
  -- data.forwardVec = normal
  -- data.scale = vec3(stepDistance, stepDistance, 1.5)
  -- Engine.Render.DynamicDecalMgr.addDecal(data)

  if scenario_busdriver then
    scenario_busdriver.onBusUpdate(state)
  end

end

M.onClientStartMission = init
M.onExtensionLoaded = init
M.onBusUpdate = onBusUpdate
M.setLine = setLine
M.onAtStop = onAtStop
M.onBeamNGTrigger = onBeamNGTrigger

return M
