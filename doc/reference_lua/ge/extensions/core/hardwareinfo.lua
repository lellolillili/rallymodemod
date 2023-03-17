-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local diskUsage = nil
local diskUsageRunning = false

local function getFallbackReason()
  local cmdArgs = Engine.getStartingArgs()
  local fallbackIndex = tableFindKey(cmdArgs, '-fallback')
  if fallbackIndex ~= nil and #cmdArgs >= fallbackIndex + 1 then
  --print("fallback: " .. cmdArgs[fallbackIndex + 1])
  return cmdArgs[fallbackIndex + 1]
  end
  return nil
end

local function getInfo()
  local res = {}

  local fb = getFallbackReason()

  res.os = Engine.Platform.getOSInfo()
  res.pwr = Engine.Platform.getPowerInfo()
  res.os.warnings = {}
  res.mem = Engine.Platform.getMemoryInfo()
  res.mem.warnings = {}

  -- warning tests:
  --fb = 'memory'

  if fb == 'win7' then
    table.insert(res.os.warnings, {type = 'error', msg = 'oldwin7'})
    print("win 7 warn")
  elseif fb == '32bitos' then
    -- well, 32 bit windows, not going to warn
  elseif fb == '64missing' then
    table.insert(res.mem.warnings, {type = 'error', msg = 'missing64binary'})
  elseif fb == 'memory' then
    table.insert(res.mem.warnings, {type = 'warn', msg = 'toolessmemoryfor64bit'})
  elseif fb == 'lavasoft' then
    table.insert(res.mem.warnings, {type = 'error', msg = 'thirdpartysoftware'})
  end

  -- enhance the memory information
  if res.os.gamearch == 'x64' then
    res.mem.processPhysUsedPercent = res.mem.processPhysUsed / res.mem.osPhysAvailable
    res.mem.osPhysUsedPercent = res.mem.osPhysUsed / res.mem.osPhysAvailable
    res.mem.processVirtUsedPercent = res.mem.processVirtUsed / res.mem.osVirtAvailable
    res.mem.osVirtUsedPercent = res.mem.osVirtUsed / res.mem.osVirtAvailable
  end


  if res.os.type == 'windows' then
    local xinput_available = Engine.Platform.getXInputSupport()
    -- warning test
    --xinput_available = false
    if not xinput_available then
      table.insert(res.os.warnings, {type = 'error', msg = 'xinput'})
    end

    local dinput_available = Engine.Platform.getDirectInputSupport()
    --dinput_available = false
    if not dinput_available then
      table.insert(res.os.warnings, {type = 'error', msg = 'dinput'})
    end
  end

  -- warning test:
  --res.mem.osPhysAvailable = 6000000000
  --res.mem.osPhysUsedPercent = 0.9

  if res.os.gamearch == 'x64' then
    if res.mem.osPhysAvailable > 4000000000 and res.mem.osPhysAvailable < 8000000000 then
      table.insert(res.mem.warnings, {type = 'warn', msg = 'lowmem'})
    elseif res.mem.osPhysAvailable < 4000000000 then
      table.insert(res.mem.warnings, {type = 'error', msg = 'minmem'})
    end

    -- memory usage only works reliable on x64
    if res.mem.osPhysUsedPercent > 0.8 then
      table.insert(res.mem.warnings, {type = 'warn', msg = 'memused'})
    end
    if res.mem.osPhysAvailable >= 4000000000 then
      -- only warn if we have enough memory in the first place
      if res.mem.osPhysAvailable - res.mem.osPhysUsed < 2000000000 then
        table.insert(res.mem.warnings, {type = 'warn', msg = 'freememlow'})
      end
    end
  elseif res.os.gamearch == 'x86' and fb == nil then
    if res.mem.osPhysAvailable < 4000000000 then
      table.insert(res.mem.warnings, {type = 'error', msg = 'minmem'})
    end
  end

  -- CPU
  res.cpu = Engine.Platform.getCPUInfo()
  res.cpu.warnings = {}

  -- warning test:
  --res.cpu.coresPhysical = 2
  --res.cpu.clockSpeed = 1800
  --res.cpu.arch = 'x32'

  local cores = res.cpu.coresPhysical
  if res.cpu.vendor == "AuthenticAMD" then
    -- AMD CPUs don't have Hyper Threading but use a modul system. Therefore logical cores should be checked.
    cores = res.cpu.coresLogical
  end
  if cores <= 1 then
    table.insert(res.cpu.warnings, {type = 'error', msg = 'cpuonecore'})
  elseif cores > 1 and cores < 4 then
    table.insert(res.cpu.warnings, {type = 'warn', msg = 'cpuquadcore'})
  end
  if res.cpu.clockSpeed <= 1950 then -- the hw information can have some differences
    table.insert(res.cpu.warnings, {type = 'warn', msg = 'cpulowclock'})
  end
  if res.cpu.arch ~= 'x64' then
    table.insert(res.cpu.warnings, {type = 'warn', msg = 'cpu64bits'})
  end

  -- GPU
  res.gpu = Engine.Platform.getGPUInfo()
  res.gpu.warnings = {}

  -- warning test:
  --res.gpu.name = 'Intel HD'
  --res.gpu.name = 'AMD Radeon R9 M295X'
  --res.gpu.memoryMB = 256

  local lowercaseGpuName = res.gpu.name:lower()
  if lowercaseGpuName:find('rdpudd') then
    table.insert(res.gpu.warnings, {type = 'warn', msg = 'remotedesktop'})
  end
  if lowercaseGpuName:find('intel') and not lowercaseGpuName:find('arc%(tm%)') then
    table.insert(res.gpu.warnings, {type = 'error', msg = 'intelgpu'})
  end

  -- nvidia series detection
  local gtx_ver, gtx_type = res.gpu.name:match("NVIDIA GeForce GTX (%d+)(.*)") --ascii
  if gtx_ver == nil and gtx_type == nil then
    gtx_ver, gtx_type = res.gpu.name:match("NVIDIA GeForce GTX (%d+)(.*)") --utf8
  end
  if gtx_ver and tonumber(gtx_ver) ~= nil and tonumber(gtx_ver) < 550 then
    table.insert(res.gpu.warnings, {type = 'warn', msg = 'geforcemin'})
  end

  --amd_ver, amd_type = res.gpu.name:match("AMD Radeon HD (%d+)(.*)")
  --if amd_ver and tonumber(amd_ver) ~= nil and tonumber(amd_ver) < 550 then
  --  table.insert(res.gpu.warnings, {type = 'warn', msg = 'amdhd'})
  --end

  --amd_vernew = res.gpu.name:match("AMD Radeon R(%d)")
  --if amd_vernew and tonumber(amd_vernew) ~= nil and tonumber(amd_vernew) < 8 then
  --  table.insert(res.gpu.warnings, {type = 'warn', msg = 'amdradeon'})
  --end

  -- gpu memory reporting is not reliable yet
  --if res.gpu.memoryMB < 512 then
  --  table.insert(res.gpu.warnings, {type = 'error', 'gpulowmem'})
  --elseif res.gpu.memoryMB < 2048 then
  --  table.insert(res.gpu.warnings, {type = 'warn', msg = 'gpurecmem'})
  --end


  if res.os.bits == 32 then
    if res.cpu.arch == 'x64' then
      table.insert(res.cpu.warnings, {type = 'warn', msg = 'os32bits'})
    end
  end

  if res.os.gamearch == 'x86' then
    -- below windows 8 we switch to 32 bit mode
    if res.os.type == 'windows' and res.os.versionMajor < 6 then
      table.insert(res.os.warnings, {type = 'warn', msg = 'oswin8'})
    else
      table.insert(res.os.warnings, {type = 'warn', msg = 'app32'})
    end
  end

  -- warning tests:
  --res.pwr.batteryPresent = true
  --res.pwr.ACOnline = false
  --res.pwr.batteryState = 'critical'
  --res.os.versionMajor = 5
  --res.os.shortname = 'WindowsXP'
  --res.os.type = 'os_type'
  -- res.os.shortname = 'random'
  -- res.os.fullname = 'fullname'

  if res.pwr.batteryPresent then
    if not res.pwr.ACOnline then
      table.insert(res.os.warnings, {type = 'error', msg = 'powerdisconnected'})
    end
    --if not res.pwr.batteryCharging then
    --  table.insert(osWarnings, {'warn', "Battery not charging"})
    --end
    if res.pwr.batteryState == 'low' then
      table.insert(res.os.warnings, {type = 'warn', msg = 'batterylow'})
    elseif res.pwr.batteryState == 'critical' then
      table.insert(res.os.warnings, {type = 'error', msg = 'batterycritical'})
    end
  end

  if res.os.versionMajor < 6 and res.os.type == 'windows' then
    table.insert(res.os.warnings, {type = 'warn', msg = 'win8rec'})
  end

  if res.os.type == 'linux' then
    if res.os.shortname == "Ubuntu" then
      if not res.os.fullname:find("20.04") then
        table.insert(res.os.warnings, {type = 'warn', msg = 'ubuntuver'})
      end
    elseif res.os.shortname ~= "SteamOS" and beamng_appname == "BeamNG.drive" then
      table.insert(res.os.warnings, {type = 'warn', msg = 'unsupportedlinuxdist'})
      log("E","core_hwinfo","unsupported linux distribution\n"..dumps(res.os))
    end
  end



  if core_modmanager.isReady() then
    res.mods = core_modmanager.getStats()
    res.mods.warnings = {}
    if res.mods.unpacked > 20 or res.mods.zip > 150 then
      table.insert(res.mods.warnings, {type = 'error', msg = 'toomanymods'})
    elseif res.mods.unpacked > 10 or res.mods.zip > 100 then
      table.insert(res.mods.warnings, {type = 'warn', msg = 'toomanymods'})
    end
  end

  if sailingTheHighSeas then
    res.hs = {warnings={}}
    table.insert(res.hs.warnings, {type = 'warn', msg = 'highseas'})
  end

  res.disk={}
  res.disk.warnings = {}
  res.disk.freeSpace = Engine.Platform.getDiskFreeSpace()
  res.disk.usage = diskUsage
  if res.disk.freeSpace.root < 1073741824 or res.disk.freeSpace.user < 1073741824 then --minimun on each disk 1 GB free
    table.insert(res.disk.warnings, {type = 'warn', msg = 'lowfreespace'})
  end

  local originalSize = -1
  if FS:fileExists("integrity.json") then
    local manifest = jsonReadFile("integrity.json")
    if manifest and manifest.format == 1 and manifest.integritydata then
      for _,v in pairs(manifest.integritydata) do
        originalSize = originalSize + v[2]
      end
    end
  end

  if res.disk.usage and diskUsage and originalSize>0 then
    M.runDiskUsage() --send the data we saved
    local rootsize = nil
    for _,v in pairs(diskUsage) do
      if v.name == "rootpath" then
        rootsize = v.size
        break
      end
    end
    log('D', 'hardwareinfo.disk', ' originalSize='..tostring(originalSize).."   rootsize="..tostring(rootsize) )
    if sailingTheHighSeas or (rootsize and (originalSize - 10485760 > rootsize or rootsize > originalSize + 268435456)) then -- allow a size difference of -100mb and +256mb because of `_CommonRedist`
      table.insert(res.disk.warnings, {type = 'warn', msg = 'rootmodified'})
    end
  end
  if string.find( getUserPath(), ".:\\Users\\.-\\OneDrive") then
    table.insert(res.disk.warnings, {type = 'warn', msg = 'onedrive'})
  end

  local cache = FS:findFiles("/", "cache.*", 1, false, true )
  if #cache > 5 then
    table.insert(res.disk.warnings, {type = 'warn', msg = 'toomanycache'})
  end

  local stateLevels = { ['ok'] = 1, ['warn'] = 2, ['error'] = 3 }
  res.globalState = 'ok'
  for k, v in pairs(res) do
    if type(v) == 'table' then
      v.state = 'ok'
      if v.warnings and #v.warnings > 0 then
        for k2,v2 in pairs(v.warnings) do
          if settings.getValue('PerformanceWarnings.' .. tostring(v2.msg)) then
            v2.ack = true
          end
          if stateLevels[v2.type] > stateLevels[v.state] then
            v.state = v2.type
          end
          if stateLevels[v2.type] > stateLevels[res.globalState] then
            res.globalState = v2.type
          end
        end
      end
    end
  end

  res.sailingTheHighSeas = sailingTheHighSeas
  if res.mods == nil then res.mods = {state="load"} end

  return res
end

local function requestInfo()
  local res = getInfo()

  --dump(res)
  guihooks.trigger('HardwareInfo', res)
end

local function logInfo(filename)
  local hw = {
    mem = Engine.Platform.getMemoryInfo(),
    cpu = Engine.Platform.getCPUInfo(),
    gpu = Engine.Platform.getGPUInfo(),
    os = Engine.Platform.getOSInfo(),
    pwr = Engine.Platform.getPowerInfo(),
  }
  jsonWriteFile(filename, res, true)
end

local function runPhysicsBenchmark()
  --local fn = '/temp/bananabench.json'
  log('D', 'hardwareinfo.runPhysicsBenchmark', 'runPhysicsBenchmark()')
  local fn = 'bananabench.json'
  FS:removeFile(fn)
  Engine.Platform.runBananaBench(fn)
end

local function onBananaBenchReady(outFilename)
  -- this is called once the banchmark is done
  log('D', 'hardwareinfo.onBananaBenchReady', 'onBananaBenchReady: ' .. tostring(outFilename))
  if not FS:fileExists(outFilename) then
    guihooks.trigger('BananaBenchReady', nil)
    return nil
  end
  local data = jsonReadFile(outFilename)
  guihooks.trigger('BananaBenchReady', data)
end

local function readBananabenchFile()
  return jsonReadFile('bananabench.json')
end

local function latestBenchmarkExists()
  return FS:fileExists('bananabench.json')
end

local function acknowledgeWarning(warning)
  settings.setValue('PerformanceWarnings.' .. warning, true)
  requestInfo()
end

local function onModManagerReady()
  requestInfo()
end

local function diskInfoCallback(data)
  -- log('D', 'hardwareinfo.diskInfoCallback', 'data: ' .. dumps(data))
  guihooks.trigger('diskInfoCallback', data)
  if not data.running then
    diskUsage = diskUsage or {}
    table.insert(diskUsage,data)
    diskUsageRunning = false
    requestInfo()
    --log('D', 'hardwareinfo.diskInfoCallback', 'diskUsage: ' .. dumps(diskUsage))
  else
    diskUsageRunning = true
  end
end

local function runDiskUsage()
  if diskUsage or diskUsageRunning then
    --log('E', 'hardwareinfo.diskInfoCallback', 'DATA: ')
    if diskUsage then
      for _,v in pairs(diskUsage) do
        guihooks.trigger('diskInfoCallback', v)
      end
    end
  else
    --log('E', 'hardwareinfo.diskInfoCallback', 'RUN: ')
    Engine.Platform.runDiskUsage()
    diskUsageRunning = true
  end
end

M.getInfo = getInfo
M.requestInfo = requestInfo
M.logInfo = logInfo
M.runPhysicsBenchmark = runPhysicsBenchmark
M.onBananaBenchReady = onBananaBenchReady
M.latestBananbench = readBananabenchFile
M.latestBenchmarkExists = latestBenchmarkExists
M.acknowledgeWarning = acknowledgeWarning
M.onModManagerReady = onModManagerReady
M.diskInfoCallback = diskInfoCallback
M.runDiskUsage = runDiskUsage

return M
