-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- beamng:v1/openMap/{level:"levels/gridmap/info.json",camPos:[58.7832,%20-181.106,%20604.187],camRot:[%200.501691,%20-0.498205,%200.498303,%200.501789],futureOptionalArg:"crepe"}

local M = {}

local mapName = nil
local args = nil -- table, other options
local ignoreStartupCmd = false --GE reload will reexecute

local function errorMsg(src, m)
  log("E", src, m)
  guihooks.trigger("toastrMsg", {type="error", title="loadMapCmd Error", msg=m})
end

local function parseMapPath(a)
  local tmp = split(a, '/')
  if #tmp< 2 then log("E","parseMapPath","Wrong argument for map!"); return nil end
  if tmp[1]=="" then
    return tmp[2].."/"..tmp[3].."/"
  else
    return tmp[1].."/"..tmp[2].."/"
  end
end

local function changeMap()
  if not args or not args.mapName then
    errorMsg("changeMap","map is undefined")
    return
  end
  if not FS:directoryExists(args.mapName) and not FS:fileExists(args.mapName)  then
    errorMsg("changeMap","map not found, you may need to add a mod")
    return
  end
  if core_gamestate and core_gamestate.state.state == "freeroam" and freeroam_freeroam and freeroam_freeroam.state.freeroamActive then
    if parseMapPath(getMissionFilename()) == args.mapName then
      log("D", "changeMap", "map already loaded")
      args.mapName = nil
      M.onWorldReadyState(2) -- execute the event our self because the map is probably already loaded
      return
    end
  end
  log("I", "changeMap", "starting in ="..tostring(args.mapName))
  freeroam_freeroam.startFreeroam(args.mapName)
  args.mapName = nil
end

local function set(data, startCmd)
  if not data then return end
  -- log("I", "set", "map ="..tostring(mname).."   a="..dumps(a))
  -- log("I", "set", "startCmd ="..tostring(startCmd).." ignoreStartupCmd="..dumps(ignoreStartupCmd))
  if startCmd and ignoreStartupCmd then
    log("D", "set", "launch cmd ignored !!!!!")
    return
  end

  args = data
  args.mapName = parseMapPath(args.level)

  if core_modmanager.isReady() then
    changeMap()
  end
end

local function onExtensionLoaded()
end

local function onExtensionUnloaded()
end

local function onModManagerReady()
  if args and args.mapName then
    changeMap()
  end
end

local function onClientPostStartMission()

end

local function onWorldReadyState(state)
  if state == 2 then
    if args and args.camPos and args.camRot then
      -- commands.setFreeCameraTransformJson(args.camTransform)

      local fcam = commands.getFreeCamera()
      if fcam == nil then
        log("E","teleportCamera","fCam nil")
        return
      end

      commands.setFreeCamera()
      fcam:setPosRot(args.camPos[1], args.camPos[2], args.camPos[3], args.camRot[1], args.camRot[2], args.camRot[3], args.camRot[4])
      args.camPos = nil

      guihooks.trigger("toastrMsg", {type="info", title="Jumped to position", msg="Successfully jumped to position"})

      if args.track then
        local tb = extensions['util/trackBuilder/splineTrack']
        tb.load(args.track, true)
      end
    end
    -- extensions.unload("core_loadMapCmd")
    args = nil
  end
end

local function onSerialize()
  return {ignoreStartupCmd = true}
end

local function onDeserialized(d)
  ignoreStartupCmd = d.ignoreStartupCmd or false
end

M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onSerialize         = onSerialize
M.onDeserialized      = onDeserialized
M.set = set
M.onModManagerReady = onModManagerReady
M.onClientPostStartMission = onClientPostStartMission
M.onWorldReadyState = onWorldReadyState

return M
