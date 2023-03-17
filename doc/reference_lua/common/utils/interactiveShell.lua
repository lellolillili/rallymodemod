-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this is an interactive lua shell inside lua, quite handy
-- created by BeamNG
-- used for the console.x64.exe: require('utils/interactiveShell').start()

local M = {}

--- helper things ---
function spawnObjects(n, v)
    local v = v or "pickup"
    local n = n or 1
    --print("spawning "..n.." objects ...")
    BeamEngine:deleteAllObjects()
    for i=1,n,1
    do
        BeamEngine:spawnObject("vehicles/"..v, nil, vec3(0, 3 * n, 0)) -- this assumes that the object is max. 3 meters high
    end
    if BeamEngine:getSlotCount() ~= n then
        print ("error: " .. BeamEngine:getSlotCount() .. " vehicles spawned of " .. n .. " requested")
    end
end
sp = spawnObjects

function updateOnce(n)
    BeamEngine:update(1/2000, 1/2000)
end

function updateLoop(n)
    local n = n or 10
    --print("updating "..n.." frames.")
    for i=0,n,1
    do
        BeamEngine:update(1/2000, 1/2000)
    end
end
ul = updateLoop

--- the main functions ---
local execTimer = nil
local function exec(cmd)
  local func, err  = loadstring(cmd)
  if func then
    if type(debug.traceback) ~= "function" then
      print("*** LUA TRACEBACK BROKEN ***")
    end
    if execTimer then execTimer:reset() end
    local ok, result = xpcall(func, debug.traceback)
    if not ok then
      print("Error: "..result)
    else
      if result then
        print(tostring(result))
      end
    end
    if execTimer then
      print("Executed in "..execTimer:stop().." ms")
    end
  else
    print("Error: "..err)
  end
end

local function start()
    --print("*** Entering BeamNG LUA Shell ***")
    while true
    do
        if type(updateLuaCore) == 'function' then updateLuaCore() end -- try to do garbage collection and cleanups
        io.write("> ")
        local cmd = io.read()

        -- some shortcuts
        local cc = string.byte(cmd)
        if cc == 4 or cmd == "exit" or cmd == "quit" then
            break
        elseif cmd == "help" then
            print("This is an interactive lua shell. Following shortcuts exists:")
            print("* tracktime - enables command timing")
            print("* luaut  - starts lua unit testing")
            print("* unittest   - executes the tests/test.lua script")
            print("* reload - forces reloading of the scripts")
            print("* sp(<optional:number>, <optional:vehicle_name>) - spawns N vehicles")
            print("* ul(<optional:number>) - class update for N frames")
            print("* quit / exit - closes the console")
            goto continue
        elseif cmd == "tracktime" then
            execTimer = HighPerfTimer()
            goto continue
        elseif cmd == "unittests" or cmd == "ut" then
            cmd = 'rerequire("lua/tests/unittests")'
        elseif cmd == "reload" then
            reloadLua()
            goto continue
        elseif cmd == "testenv" then
            cmd = 'rerequire("lua/vehicle/beamng") ; rerequire("lua/tests/test")'
        end
        --print(cmd)
        exec(cmd)

        ::continue::
    end
    print "*** Exiting BeamNG LUA Shell ***"
end

-- public interface
M.start = start
return M