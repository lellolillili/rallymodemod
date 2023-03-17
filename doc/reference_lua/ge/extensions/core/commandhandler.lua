-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this module is used to execute asnc tasks that are put upon us.
-- i.e. protocol scheme commands

local M = {}

local logTag = 'commandhandler'
local uiReady = false
local cachedSchemes = {}
local ignoreStartupCmd = false --GE reload will reexecute

local hex_to_char = function(x)
  return string.char(tonumber(x, 16))
end

local unescape = function(url)
  return url:gsub("%%(%x%x)", hex_to_char)
end

local function onSchemeCommand(scheme, isStartingArg)
  log('D', logTag, 'new scheme command: ' .. tostring(scheme))
  if not uiReady then
    table.insert(cachedSchemes, {sc = scheme, startArg = isStartingArg} )
    return
  end
  scheme = unescape(scheme) -- "%20" -> " "
  local args = split(scheme, '/', 2)
  if #args < 2  then
    log('E', 'scheme', 'invalid/unsupported starting command: ' .. dumps(args))
    return
  end

  log('D', 'scheme', "invoked by scheme: " .. tostring(scheme) .. ' = ' .. dumps(args))

  local version = args[1]
  local cmd     = args[2]
  local data    = args[3]

  --log('E', 'scheme', ' === === === === === === === === ===')
  --dump(args)

  if cmd == 'showMod' and version == 'v1' then
    -- args = { "v1", "subscriptionMod", "MKA5UZHYS/6902/spanishpoliceroamerpack.zip" }
    local filename = split(data, '/')
    filename = filename[#filename]
    log('I', logTag, 'show mod: ' .. tostring(data))
    extensions.core_repository.uiShowMod(data)
    return
  elseif cmd == 'subscriptionMod' and version == 'v1' then
    -- args = { "v1", "subscriptionMod", "MKA5UZHYS/6902/spanishpoliceroamerpack.zip" }
    local filename = split(data, '/')
    filename = filename[#filename]
    log('I', logTag, 'subscription mod: ' .. tostring(data))
    extensions.core_repository.uiShowRepo()
    extensions.core_repository.modSubscribe(data)
    return
  elseif cmd == 'downloadMod' and version == 'v1' then
    -- args = { "v1", "downloadMod", "MKA5UZHYS/6902/spanishpoliceroamerpack.zip" }
    local filename = split(data, '/')
    filename = filename[#filename]
    log('I', logTag, 'downloading mod: ' .. tostring(data))
    extensions.core_repository.installMod(data, filename, 'mods/repo/')
    return
  elseif cmd == "updateZipMod" and version == "v1" then
    -- args = { "v1", "updateZipMod", "crepe.zip", "crepe.zip.tmp" }
    local tmp = split(data, '/')
    if #tmp < 2 then
      log("E","commandhandler","Wrong argument count!")
      return
    end
    log('I', logTag, "updateZipMod '" .. tostring(tmp[1]).. "' with new '"..tostring(tmp[2]) .."'")
    extensions.core_modmanager.updateZipMod(tmp[1], tmp[2])
    return
  elseif cmd == "openMap" and version == "v1" then
    -- args = { "v1", "openMap", "levels/gridmap/info.json" }
    local jsondata = jsonDecode(data, nil)
    -- if core_loadMapCmd then extensions.unload("core_loadMapCmd") end --if we are already going somewhere, remove previous 'queued' commands
    extensions.load("core_loadMapCmd")
    registerCoreModule("core/loadMapCmd")
    core_loadMapCmd.set(jsondata, isStartingArg)
    return
  end

  log('E', 'scheme', 'unsupported scheme command: ' .. dumps(args))
end

local function onUiReady()
  uiReady = true
  for k, v in pairs(cachedSchemes) do
    onSchemeCommand(v.sc, v.startArg)
  end
  cachedSchemes = {}
end

local function onFirstUpdate()
  if ignoreStartupCmd then
    log('D', logTag, 'module reloaded: Startup command ignored')
    return
  end
  local cmdArgs = Engine.getStartingArgs()
  for i = 1, #cmdArgs do
    local arg = cmdArgs[i]
    arg = arg:stripcharsFrontBack('"')
    if arg == '-command' and i + 1 <= #cmdArgs then
      local arg1 = cmdArgs[i + 1]
      if arg1 then
      arg1 = arg1:stripcharsFrontBack('"\'')
      if arg1:startswith('beamng:') then
        onSchemeCommand(arg1:sub(8), true) -- strip 'beamng:'
        break
      else
        log('E', logTag, 'unknown scheme: ' ..tostring(arg1))
      end
      end
    end
  end
end

local function onSerialize()
  return {ignoreStartupCmd = true}
end

local function onDeserialized(d)
  ignoreStartupCmd = d.ignoreStartupCmd or false
end


-- public interface
M.onExtensionLoaded = nop--onExtensionLoaded
M.onSchemeCommand = onSchemeCommand
M.onFirstUpdate = onFirstUpdate
M.onUiReady = onUiReady
M.onSerialize         = onSerialize
M.onDeserialized      = onDeserialized

return M
