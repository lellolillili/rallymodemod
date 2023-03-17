-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local logTag = "lua"

-------------------------------------------------------------------------------
-- Scenetree START
scenetree = {}

-- allows users to find Objects via name: scenetree.findObject('myname')
scenetree.findObject = function(objectName)
  return Sim.findObject(objectName)
end

--findObjectByIdAsTable
scenetree.findObjectById = function(objectId)
  return Sim.findObjectById(objectId)
end

scenetree.objectExists = function(objectId)
  return Sim.objectExists(objectId)
end

scenetree.objectExistsById = function(objectId)
  return Sim.objectExistsById(objectId)
end

-- allows users to find Objects via classname: scenetree.findClassObjects('BeamNGTrigger')
scenetree.findClassObjects = function(className)
  local res_table = {}
  if Lua:findObjectsByClassAsTable(className, res_table) then
    return res_table
  end
  return nil
end

scenetree.getAllObjects = function()
  local res_table = {}
  if Lua:getAllObjects(res_table) then
    return res_table
  end
  return nil
end

-- used on scenetree object lookups
scenetree.__index = function(class_table, memberName)
  --log('E', logTag,'scenetree.__index('..tostring(class_table) .. ', ' .. tostring(memberName)..')')
  --dump(class_table)
  -- 1. deal with methods on the actual lua object: like get/set below
  if getmetatable(class_table)[memberName] then
    return getmetatable(class_table)[memberName]
  end
  if memberName == 'findClassObjects' then
    return getmetatable(class_table).findClassObjects(memberName)
  end
  -- 2. use findObject to collect the object otherwise
  -- TODO: cache the object!
  return getmetatable(class_table).findObject(memberName)
end
-- the scenetree is read only
scenetree.__newindex = function(...) end -- disallow any assignments
-- scenetree is a singleton, no more than one 'instance' at any time, so hardcode the creation
scenetree = setmetatable({}, scenetree)

-- Scenetree END
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------




-- tests from thomas
-- TODO: convert to proper unit-tests :)
function scenetree_tests()
  -- scenetree tests:
  log('D', logTag,"scenetree - test #1 = " .. tostring(scenetree.sunsky.shadowDistance))
  log('D', logTag,"scenetree - test #2 = " .. tostring(scenetree.sunsky:getDeclarationLine()))
  log('D', logTag,"scenetree - test #3 = " .. tostring(scenetree['sunsky']:getDeclarationLine()))

  -- manually find the object, working around scenetree
  local obj = scenetree.findObject('sunsky')
  --dump(obj)

  -- getter tests
  log('D', logTag,"-getter tests")
  log('D', logTag,"shadowDistance - getter #1 = " .. tostring(obj.shadowDistance))
  log('D', logTag,"shadowDistance - getter #2 = " .. tostring(obj['shadowDistance']))
  log('D', logTag,"shadowDistance - getter #3 = " .. tostring(obj:get('shadowDistance')))
  if obj.shadowDistanceNonExisting == nil then
    log('D', logTag,"shadowDistance - getter #4 is nil ")
  else
    log('D', logTag,"shadowDistanceNonExisting - getter #4 ERROR = " .. tostring(obj.shadowDistanceNonExisting))
  end

  -- setter tests
  log('D', logTag,"-setter tests")
  obj:set('shadowDistance', 123)
  obj.shadowDistance = 123
  obj['shadowDistance'] = 123

  -- usage tests
  log('D', logTag,"-usage tests")
  log('D', logTag,">> shadowDistance = " .. tostring(obj.shadowDistance))
  obj.shadowDistance = 123
  log('D', logTag,">> shadowDistance = " .. tostring(obj.shadowDistance))

  -- testing protected fields [canSave]
  log('D', logTag,"-protected fields tests")
  log('D', logTag,">> canSave = " .. tostring(obj.canSave))
  log('D', logTag,">> canSave set to false")
  obj.canSave = false
  log('D', logTag,">> canSave = " .. tostring(obj.canSave))
  obj.canSave = true
  log('D', logTag,">> canSave set to true")

  -- test if function to object forwarding works:
  --log('D', logTag,obj:getDataFieldbyIndex(0, 0, 0))
  log('D', logTag,obj:getDeclarationLine())
  --obj:delete(1,2,3, vec3(1,2,3), "test")
end

function scenetree_test_fields()
  print('testing fields of "thePlayer": ' .. tostring(scenetree.thePlayer))
  local player = scenetree.thePlayer
  local fields = player:getFields()
  for k, f in pairs(fields) do
    if k ~= 'dataBlock' and k ~= 'parentGroup' then -- why do we need to exclude these?
      local val = player[k]
      if val == nil then
        print(' N ' .. tostring(k) .. ' = NIL [' .. (f.type or 'unknown') .. ']')
      else
        print(' * ' .. tostring(k) .. ' = ' .. tostring(player[k]) .. ' [Types| Lua: ' .. type(val) .. ', C: ' .. (f.type or 'unknown') .. ']')
      end
    else
      print(' x UNSUPPORTED TYPE: ' .. tostring(k) .. ' [' .. (f.type or 'unknown') .. ']')

    end
  end
end
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

function test_GE_fields()


  local obj = SimFieldTestObject("TestObj")
  --dump(obj)

  local value_s32 = -5
  obj.staticFieldS32 = value_s32
  assert( obj.staticFieldS32 == value_s32 )
  obj.protectedFieldS32 = value_s32
  assert( obj.protectedFieldS32 == value_s32 )
  obj.dynFieldS32 = value_s32
  assert( obj.dynFieldS32 == value_s32 )

  local value_f32 = -33.330000000000
  obj.staticFieldF32 = value_f32
  assert( math.abs(obj.staticFieldF32 - value_f32) < 0.0001 )
  obj.protectedFieldF32 = value_f32
  assert( math.abs(obj.protectedFieldF32 - value_f32) < 0.0001 )
  obj.dynFieldF32 = value_f32
  assert( math.abs(obj.dynFieldF32 - value_f32) < 0.0001 )

  local value_f64 = -66.660000000000
  obj.staticFieldF64 = value_f64
  assert( math.abs(obj.staticFieldF64 - value_f64) < 0.0001 )
  obj.protectedFieldF64 = value_f64
  assert( math.abs(obj.protectedFieldF64 - value_f64) < 0.0001 )
  obj.dynFieldF64 = value_f64
  assert( math.abs(obj.dynFieldF64 - value_f64) < 0.0001 )

  value_cstring = "CString"
  obj.staticFieldCString = value_cstring
  assert( obj.staticFieldCString == value_cstring )
  obj.protectedFieldCString = value_cstring
  assert( obj.protectedFieldCString == value_cstring )
  obj.dynFieldCString = value_cstring
  assert( obj.dynFieldCString == value_cstring )

  value_string = "String"
  obj.staticFieldString = value_string
  assert( obj.staticFieldString == value_string )
  obj.protectedFieldString = value_string
  assert( obj.protectedFieldString == value_string )
  obj.dynFieldString = value_string
  assert( obj.dynFieldString == value_string )

  obj.staticFieldSimObjectPtr = obj
  assert( obj.staticFieldSimObjectPtr.staticFieldString == obj.staticFieldString )
  obj.protectedFieldSimObjectPtr = obj
  assert( obj.protectedFieldSimObjectPtr.staticFieldString == obj.staticFieldString )
  obj.dynFieldSimObjectPtr = obj
  assert( obj.dynFieldSimObjectPtr.staticFieldString == obj.staticFieldString )

  obj:delete()
end

function replace_char(pos, str, r)
  return str:sub(1, pos-1) .. r .. str:sub(pos+1)
end

function testGBitmap()
  --print("testGBitmap...")

  local bitmap = GBitmap()

  -- GBitmap:init( uint width, uint heigt )
    -- create a RGBA image of widthXheight dimension
  bitmap:init(16, 16)
  -- test size
  -- uint GBitmap::getWidth - return the width of the image
  assert( bitmap:getWidth() == 16 )
  -- uint GBitmap::getHeight - return the height of the image
  assert( bitmap:getHeight() == 16 )

  local colorWhite = ColorI(255,255,255,255)
  local colorBlack = ColorI(0, 0, 0, 255)
  assert( colorBlack == colorBlack )
  assert( colorWhite == colorWhite )
  assert( colorBlack ~= colorWhite )

  -- GBitmap:fillColor( ColotI color )
  --    set color for all pixels in the image
  bitmap:fillColor( colorWhite )

  local col = colorBlack

  -- bool GBitmap::setColor( uint pixelAtWidth, uint pixelAtHeight, ColorI color )
  --    set color at requested pixel position.
  --    Return: Bool - false on failed
  bitmap:setColor(8,8, col)

  -- bool GBitmap::getColor( uint pixelAtWidth, uint pixelAtHeight, OUT ColorI color )
  --    set color at requested pixel position.
  --    Return: Bool - false on failed
  --    OUT color - the requested color
  assert( bitmap:getColor( 8, 8, col ) )
  assert( col == colorBlack )
  assert( bitmap:getColor( 0, 0, col ) )
  assert( col == colorWhite )

  --print("testGBitmap... loading/saving")
  local filePath = "test/GBitmap.png"

  -- bool GBitmap::saveFile( string filePath )
  bitmap:saveFile( filePath )
  bitmap:fillColor( ColorI(0, 0, 0, 0) )

  -- bool GBitmap::loadFile( string filePath )
  bitmap:loadFile( filePath )

  assert( bitmap:getColor( 8, 8, col ) )
  assert( col == colorBlack )
  assert( bitmap:getColor( 0, 0, col ) )
  assert( col == colorWhite )
end

function deleteObject(name)
  local sg = scenetree[name]
  if(sg) then
    sg:delete()
  end
end

TorqueScriptLua = {}
TorqueScriptLua.call = function( functor, ...)
  local arg = {...}
  local argsStr = ""
  local separator = ""
  for i,v in ipairs(arg) do
    argsStr = argsStr..separator

    if type(v) == 'string' then
      argsStr = argsStr .. '"' .. v .. '"'
    else
      argsStr = argsStr .. tostring(v)
    end

    separator = ','
  end

  --print( functor..'('..argsStr..')' )
  return TorqueScript.eval( 'return '..functor..'('..argsStr..');' )
end

-- TODO: how is this diferent from TorqueScriptLua.call?
TorqueScriptLua.callNoReturn = function( functor, ...)
  local arg = {...}
  local argsStr = ""
  local separator = ""
  for i,v in ipairs(arg) do
    argsStr = argsStr..separator

    if type(v) == 'string' then
      argsStr = argsStr .. '"' .. v .. '"'
    else
      argsStr = argsStr .. tostring(v)
    end

    separator = ','
  end

  --print( functor..'('..argsStr..')' )
  return TorqueScript.eval( functor..'('..argsStr..');' )
end

TorqueScriptLua.exec = function(filePath)
  return TorqueScript.exec(filePath)
end

TorqueScriptLua.getBoolVar = function( name )
  -- emulate the same conversion performed by C++ side function "Con::getBoolVariable"
  local stringValue = getConsoleVariable( name )
  local numberValue = tonumber(stringValue) or 0
  return string.lower(stringValue) == "true" or numberValue ~= 0
end

TorqueScriptLua.getVar = function( name )
  return getConsoleVariable( name )
end

TorqueScriptLua.setVar = function( name, value )
  -- booleans need a special care becouse "true" and "false" dont exist on TS
  if value == false then
    value = 0
  elseif value == true then
    value = 1
  end
  setConsoleVariable( name, tostring(value) )
end

function testZIP()

  local zip = ZipArchive()

  -- openArchiveName( pathSrc, mode )
  zip:openArchiveName('testZIP/testZIP.zip', 'w')

  -- addFile( path [, pathInZIP, overrideFile] )
  zip:addFile( 'torque3d.log', 'logs/torque3d.log', true )
  zip:addFile( settings.impl.pathTorquescript )
  zip:addFile( settings.impl.pathLocal )
  zip:addFile( settings.impl.pathCloud )
  zip:close()

  zip = ZipArchive()
  zip:openArchiveName('testZIP/testZIP.zip', 'r')
  local files = zip:getFileList()
  dump(files)
  for i,v in ipairs(files) do
    -- extractFile( pathInZIP [, pathDst ] )
    zip:extractFile( v, 'testZIP/testZIP.zip.content/'..v )
  end
  zip:close()

  zip = ZipArchive()
  zip:openArchiveName('testZIP/testZIP.zip', 'r')
  files = zip:getFileList()
  print("Hash of files in testZIP/testZIP.zip ")
  for i, v in ipairs( files ) do
    print( '  '..zip:getFileEntryHashByIdx(i)..' '..v)
  end
  zip:close()
end

function testHWInfo()
  local mem = memory_info_t()
  if Engine.Platform.getMemoryInfo(mem) then
    local byteToGB = 1 / (1024 * 1024 * 1024)
    print('Memory.osVirtAvailable: '..mem.osVirtAvailable * byteToGB)
    print('Memory.osVirtUsed: '   ..mem.osVirtUsed * byteToGB)
    print('Memory.osPhysAvailable: '..mem.osPhysAvailable * byteToGB)
    print('Memory.osPhysUsed: '   ..mem.osPhysUsed * byteToGB)
    print('Memory.processVirtUsed: '..mem.processVirtUsed * byteToGB)
    print('Memory.processPhysUsed: '..mem.processPhysUsed * byteToGB)
  end

  local cpu = cpu_info_t()
  if Engine.Platform.getCPUInfo(cpu) then
    print('CPU.name: '..cpu.name)
    print('CPU.cores: '..cpu.cores)
    print('CPU.clockSpeed: '..cpu.clockSpeed)
    print('CPU.measuredSpeed: '..cpu.measuredSpeed)
  end

  local gpu = gpu_info_t()
  if Engine.Platform.getGPUInfo(gpu) then
    print('GPU.name: '..gpu.name)
    print('GPU.version: '..gpu.version)
    print('GPU.memoryMB: '..gpu.memoryMB)
  end

  print('OS: '..Engine.Platform.getWindowsVersionName())
end


-- helper function that can determine if an object is part of a simgroup
function prefabIsChildOfGroup(obj, groupName)
  if not obj then
    return false
  end

  local group = scenetree.findObject(groupName)
  if not group then
    return false
  end

  if obj:isChildOfGroup(group.obj) then
    return true
  end

  local parentPrefab = Prefab.getPrefabByChild( obj )
  if parentPrefab and parentPrefab:isChildOfGroup(group.obj) then
    return true
  end
  return false
end


--function testLicensePlate()
  --local v = playerVehicle
  --v:createUITexture("@licenseplate", "local://local/ui/simple/licenseplate.html", 128, 64, UI_TEXTURE_USAGE_AUTOMATIC, 1)
  --playerVehicle:queueJSUITexture("@licenseplate", 'setPlateText("ABCDE");')
  --v:destroyUITexture("@licenseplate")
--end


function createObject(className)
  if _G[className] == nil then
    log('E', 'scenetree', 'Unable to create object: unknown class: ' .. tostring(className))
    return nil
  end
  local obj = _G[className]()

  -- print('Creation object of class ' .. tostring(className) .. ' resulted in type ' .. tostring(getmetatable(obj).___type))

  obj:incRefCount()
  return obj
end

function collisionReloadTest()
  local h = hptimer()
  be:reloadCollision()
  print("reloading the collision took: " .. h:stop() .. ' ms')
end

function vehicleSetPositionRotation(id, px, py, pz, rx, ry, rz, rw)
  local bo = be:getObjectByID(id)
  if bo then
    bo:setPositionRotation(px, py, pz, rx, ry, rz, rw)
  else
    log('E', "vehicleSetPositionRotation", 'vehicle not found: ' .. tostring(id))
  end
end

local function colorTableToRoundedColorString(color, metallicData)
  local x = round(color.x*100)/100
  local y = round(color.y*100)/100
  local z = round(color.z*100)/100
  local w = round(color.w*100)/100 -- this is because the TS version was only up to the second decimal
  local x1 = round(metallicData.x*100)/100
  local y1 = round(metallicData.y*100)/100
  local z1 = round(metallicData.z*100)/100
  local w1 = round(metallicData.w*100)/100
  return tostring(x).." "..tostring(y).." "..tostring(z).." "..tostring(w).." "..tostring(x1).." "..tostring(y1).." "..tostring(z1).." "..tostring(w1) -- the TS sequence was like this
end

--[[getVehicleColor
@param vehicleID int, optional
@return vehicle color in form of a string or table
]]
function getVehicleColor(vehicleID)
  local vehicle
  if vehicleID then
    vehicle = scenetree.findObjectById(vehicleID)
  else
    vehicle = be:getPlayerVehicle(0) -- TODO: add a check whether the game is running?
  end
  if not vehicle then return "" end
  return colorTableToRoundedColorString(vehicle.color, vehicle.metallicPaintData)
end

function getVehicleColorPalette(index, vehicleID)
  local vehicle
  if vehicleID then
    vehicle = scenetree.findObjectById(vehicleID)
  else
    vehicle = be:getPlayerVehicle(0) -- TODO: add a check whether the game is running?
  end
  if not vehicle then return end
  return colorTableToRoundedColorString(vehicle["colorPalette"..index], vehicle.metallicPaintData)
end

local allVehiclesCache
local allVehiclesIdCache
function invalidateVehicleCache()
  allVehiclesCache = nil
  allVehiclesIdCache = nil
end

-- returns a list of all BeamNGVehicle objects currently spawned in the level
function getAllVehicles()
  if not allVehiclesCache then
    allVehiclesCache = {}
    allVehiclesIdCache = {}
    for i = 0, be:getObjectCount()-1 do
      local veh = be:getObject(i)
      table.insert(allVehiclesCache, veh)
      table.insert(allVehiclesIdCache, veh:getId())
    end
  end
  return allVehiclesCache
end

-- returns a list of all BeamNGVehicle objects, filtered by their type
local defaultTypes = {"Car", "Truck", "Automation", "Traffic"}
function getAllVehiclesByType(typeList)
  local res = {}
  typeList = typeList or defaultTypes

  for _, veh in ipairs(getAllVehicles()) do
    local model = core_vehicles.getModel(veh.jbeam).model
    if arrayFindValueIndex(typeList, model.Type) then
      table.insert(res, veh)
    end
  end
  return res
end

function activeVehiclesIterator()
  if not allVehiclesCache then
    getAllVehicles()
  end
  local vehiclesIndex = 0
  local vehiclesCount = table.getn(allVehiclesCache)

  return function()
    while(vehiclesIndex < vehiclesCount) do
      vehiclesIndex = vehiclesIndex + 1
      local veh = allVehiclesCache[vehiclesIndex]
      if veh and veh:getActive() then
        return allVehiclesIdCache[vehiclesIndex], veh
      end
    end
  end
end

function getClosestVehicle(requesterID, callbackfct)
  local vehr = be:getObjectByID(requesterID)
  if not vehr then return end
  local pos1 = vec3(vehr:getPosition())

  local minDist = 9999999
  local minVehId = nil
  for tid, veh in activeVehiclesIterator() do
    if tid ~= requesterID then
      local pos2 = veh:getPosition()
      local dist = (pos1 - pos2):length()
      if dist < minDist then
        minDist = dist
        minVehId = tid
      end
    end
  end
  if not minVehId then
  vehr:queueLuaCommand(callbackfct .. '(-1, -1)')
  else
  vehr:queueLuaCommand(callbackfct .. '(' .. minVehId .. ',' .. minDist .. ')')
  end
end

function forEachAudioChannel(callback)
  local audioChannels = scenetree.findClassObjects('SFXSourceChannel')
  for k, name in ipairs(audioChannels) do
    local channel = scenetree.findObject(name)
    if channel then
      channel = Sim.upcast(channel)
      callback(name, channel)
    end
  end
end

function getAudioChannelsVolume()
  local lastVolumes = {}
  local callback = function(name, audio)
    lastVolumes[name] = audio.getVolume()
  end
  forEachAudioChannel(callback)
  return lastVolumes
end

function setAudioChannelsVolume(data)
  for k, v in pairs(data) do
    local AudioChannel = scenetree[k]
    if AudioChannel then AudioChannel:setVolume(v) end
  end
end

-- TODO remove
function testSounds()
  paramGroupG = SFXParameterGroup()
  paramGroupG:setPrefixFilter('global_')
  paramGroupG:registerObject('')

  paramGroupA = SFXParameterGroup()
  paramGroupA:registerObject('')

  paramGroupB = SFXParameterGroup()
  paramGroupB:registerObject('')

  soundA = Engine.Audio.createSource2('AudioGui', 'event:>TestGroup>TestEvent')
  paramGroupA:addSource(soundA)
  soundB = Engine.Audio.createSource2('AudioGui', 'event:>TestGroup>TestEvent')
  paramGroupB:addSource(soundB)

  soundA:play(-1)
  soundB:play(-1)

  paramGroupA:setParameterValue('test0', 0)
  paramGroupB:setParameterValue('test0', 0)
end

-- returns first hit with the correct class. Example: getObjectByClass("TimeOfDay")
function getObjectByClass(className)
  local o = scenetree.findClassObjects(className)
  if not o or #o == 0 then return nil end
  o = scenetree.findObject(o[1])
  if not o then return nil end
  return o
end

-- returns all hit with the correct class. Example: getObjectsByClass("CloudLayer")
function getObjectsByClass(className)
  local res = {}
  local o = scenetree.findClassObjects(className)
  if not o or #o == 0 then return nil end
  for _, v in pairs(o) do
    table.insert(res, scenetree.findObject(v))
  end
  return res
end

-- returns our time of the day, if not possible, nil
-- uses 24h time format
function getTimeOfDay(asString)
  local tod = getObjectByClass("TimeOfDay")
  if not tod then return nil end
  local seconds = ((tod.time + 0.5) % 1) * 86400
  local hours = math.floor(seconds / 3600)
  local mins = math.floor(seconds / 60 - (hours * 60))
  local secs = math.floor(seconds - hours * 3600 - mins * 60)
  if asString then
    return string.format("%02.f", hours) .. ":" .. string.format("%02.f", mins) .. ":" .. string.format("%02.f", secs)
  else
    return {hours = hours, mins = mins, secs = secs}
  end
end

-- sets the time. example: setTimeOfDay('13:00')
-- uses 24h time format
function setTimeOfDay(inp)
  local tod = getObjectByClass("TimeOfDay")
  if not tod then return false end

  if type(inp) == 'string' then
    -- parse the string then
    local h, m, s = string.match(inp, "([0-9]*):?([0-9]*):?([0-9]*)")
    inp = {
      hours = tonumber(h) or 0,
      mins = tonumber(m) or 0,
      secs = tonumber(s) or 0
    }
  end
  --dump(inp)
  tod.time = (((inp.hours * 3600 + inp.mins * 60 + inp.secs) / 86400) + 0.5) % 1
end

function addPrefab(objName, objFileName, objPos, objRotation, objScale, useGlobalTranslation)
  local obj = scenetree[objName]
  if not obj then
    log('D', logTag, 'adding prefab '..objName)
    local p = createObject('Prefab')
    p.filename = String(objFileName)
    p.loadMode = 1 --'Manual'
    p:setField('position', '', objPos)
    p:setField('rotation', '', objRotation)
    p:setField('scale', '', objScale)
    p.canSave  = true
    p.canSaveDynamicFields = true
    p.useGlobalTranslation = useGlobalTranslation or false
    p:registerObject(objName)
    --MissionCleanup.add(%p)
    return p
  else
    log('E', logTag, 'Object already exists: '..objName)
    return nil
  end
end

function spawnPrefab(objName, objFileName, objPos, objRotation, objScale)
  local p = addPrefab(objName, objFileName, objPos, objRotation, objScale)
  if p then
    log('D', logTag, 'loading prefab '..objName)
    p:load();
  end
  return p
end

function removePrefab(objName)
    local obj = scenetree[objName]
    if obj then
      log('D', logTag, 'unloading prefab '..objName)
      obj:unload()
      obj:delete()
    end
end

function pushActionMap (map)
  local o = scenetree[map .. "ActionMap"]
  if o then return o:push() end
  return false
end

function pushActionMapHighestPriority(map)
  local o = scenetree[map .. "ActionMap"]
  if o then return o:pushFirst() end
  return false
end

function popActionMap (map)
  local o = scenetree[map .. "ActionMap"]
  if o then return o:pop() end
  return false
end

function queueCallbackInVehicle(veh, geluaFunctionName, vluaCommand, ...)
  if not veh or not geluaFunctionName or not vluaCommand then
    log("E", "", "Unable to queue callback, invalid parameters: "..dumps(veh, geluaFunctionName, vluaCommand))
    return
  end

  local geluaCommand = string.format('local args = %s; %s(unpack(args, 1, table.maxn(args)))', 'deserialize(%q)', geluaFunctionName)
  local cmd = string.format('obj:queueGameEngineLua(string.format(%q, serialize({%s, unpack(%s)})))', geluaCommand, vluaCommand, serialize({...}))
  veh:queueLuaCommand(cmd)
end

-- returns the radius of a scene object beamng waypoint
function getSceneWaypointRadius(o)
  local oScale = o:getScale()
  return math.max(oScale.x, oScale.y, oScale.z)
end

function checkVehicleProperty(vid, propertyName, value)
  local sceneVehicle = scenetree.findObjectById(vid)
  return sceneVehicle and sceneVehicle[propertyName] == value
end

function setVehicleProperty(vid, propertyName, value)
  local sceneVehicle = scenetree.findObjectById(vid)
  if sceneVehicle then
    sceneVehicle[propertyName] = value
  end
end

 -- gets estimated maximum amount of vehicles to run based on CPU
function getMaxVehicleAmount(cap)
  return Engine.Platform.getCPUInfo() and clamp(Engine.Platform.getCPUInfo().coresPhysical or 1, 1, cap or math.huge) or 4
end


------------------------------------------------------------------------------

local function new_SimObject(t)
  local obj = SimGroup()
  for k, v in pairs(t) do
    obj[k] = v
  end
  obj:registerObject(t.name)
  return obj
end

function test_lua()
  local obj2 = new_SimObject {
    name = 'hey',
    internalName = 2
  }
  dump(obj2.internalName)

  obj2 = Sim.findObject('hey')
  obj2:findObjectById(3)

  obj2:deleteObject()
end

function convertVehicleColorsToPaints(colorTable)
  if type(colorTable) ~= 'table' then
    log('W','vehiclePaint','colorTable parameter should be a table of colors. type = '..type(colors)..' colors = '..dumps(colors))
    colorTable = {}
  end

  local paints = {}
  local colorTableSize = tableSize(colorTable)
  for i = 1, colorTableSize do
    local paint = createVehiclePaint({x = colorTable[i][1], y = colorTable[i][2], z = colorTable[i][3], w = colorTable[i][4]}, {})
    validateVehiclePaint(paint)
    table.insert(paints, paint)
  end
  return paints
end

function createVehiclePaint(color, metallicData)
  if type(metallicData) ~= 'table' then
    metallicData = {}
  end

  local metallic            = metallicData.metallic or tonumber(metallicData[1]) or 0.2
  local roughness           = metallicData.roughness or tonumber(metallicData[2]) or 0.5
  local clearcoat           = metallicData.clearcoat or tonumber(metallicData[3]) or 0.8
  local clearcoatRoughness  = metallicData.clearcoatRoughness or tonumber(metallicData[4]) or 0.0

   local paint = {baseColor = {color.x, color.y, color.z, color.w},
                  metallic  = metallic,
                  roughness = roughness,
                  clearcoat = clearcoat,
                  clearcoatRoughness = clearcoatRoughness
                }
  return paint
end

function getVehiclePaint(vehicleId)
  local vehicle
  if vehicleID then
    vehicle = scenetree.findObjectById(vehicleId)
  else
    vehicle = be:getPlayerVehicle(0) -- scenetree.findObjectById() -- TODO: add a check whether the game is running?
  end
  if not vehicle then return nil end
  return createVehiclePaint(vehicle.color, vehicle.metallicPaintData)
end

function validateVehiclePaint(paint)
  if type(paint) ~= 'table' then
    log('W','validateVehiclePaint','paint parameter should be a table.')
    paint = {}
  end
  paint.baseColor           = paint.baseColor or {1, 1, 1, 1}
  paint.metallic            = paint.metallic or 0.2
  paint.roughness           = paint.roughness or 0.5
  paint.clearcoat           = paint.clearcoat or 0.8
  paint.clearcoatRoughness  = paint.clearcoatRoughness or 0.0
  return paint
end

function vehicleMetallicPaintDataFromColor(colorTable)
  if type(colorTable) ~= 'table' then
    log('W','vehicleMetallicPaintDataFromColor','colorTable parameter should be a table.')
    colorTable = {}
  end
  local metallic            = tonumber(colorTable[5]) or 0.2
  local roughness           = tonumber(colorTable[6]) or 0.5
  local clearcoat           = tonumber(colorTable[7]) or 0.8
  local clearcoatRoughness  = tonumber(colorTable[8]) or 0.0
  -- log('I','vehicleColor','metallic data: metallic = '..metallic..' roughness = '..roughness..' clearcoat = '..clearcoat..' clearcoatRoughness = '..clearcoatRoughness)
  return metallic, roughness, clearcoat, clearcoatRoughness
end

function vehicleMetallicPaintString(metallic, roughness, clearcoat, clearcoatRoughness)
  local metallicPaintData = string.format("%s %s %s %s", metallic, roughness, clearcoat, clearcoatRoughness)
  return metallicPaintData
end

function validateVehicleDataColor(color)
  local validatedColor = color or "1 1 1 1"
  if type(color) == 'string' then
    local components = string.split(validatedColor)
    validatedColor = string.format("%0.2f %0.2f %0.2f %0.2f", tonumber(components[1]), tonumber(components[2]), tonumber(components[3]), tonumber(components[4]))
  elseif type(color) == 'table' then
    validatedColor = string.format("%0.2f %0.2f %0.2f %0.2f", color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
  end
  return validatedColor
end

function fillVehicleSpawnOptionDefaults(modelName, opt)
  local model = core_vehicles.getModel(modelName)

  if not opt then
    opt = {}
  end
  -- log('I', 'vehicle', 'spawnFilldefaults: opt Before = '..dumps(opt))
  local config
  if type(opt.config) == 'string' then
    if string.endswith(opt.config, '.pc') then
      local configName = string.match(opt.config, "([^./]*).pc")
      if model.configs[configName] then
        config = model.configs[configName] or {}
        opt.config = configName
      else
        config = jsonReadFile(opt.config) or {}
      end
    else
      config = model.configs[opt.config] or {}
    end
  else
    config = opt.config or {}
  end

  opt.model = opt.model or modelName

  local isColor4 = function(color)
    local components = stringToTable(color)
    local countNumericEntries = 0
    for _,v in ipairs(components) do
      if type(tonumber(v)) == 'number' then
        countNumericEntries = countNumericEntries + 1
      end
    end
    return countNumericEntries == #components
  end

  local color4StringToPaint = function(colorStr)
    local components = stringToTable(colorStr)
    local paint = createVehiclePaint({x = tonumber(components[1]), y = tonumber(components[2]), z = tonumber(components[3]), w = tonumber(components[4])})
    return paint
  end
  if opt.color and type(opt.color) == 'string' then
    if not opt.paintName and not isColor4(opt.color) then
      opt.paintName = opt.color
    else
      opt.paint = color4StringToPaint(opt.color)
    end
  end

  if opt.color2 and type(opt.color2) == 'string' then
    if not opt.paintName2 and not isColor4(opt.color2) then
      opt.paintName2 = opt.color2
    else
      opt.paint2 = color4StringToPaint(opt.color2)
    end
  end

  if opt.color3 and type(opt.color3) == 'string' then
    if not opt.paintName3 and not isColor4(opt.color3) then
      opt.paintName3 = opt.color3
    else
      opt.paint3 = color4StringToPaint(opt.color3)
    end
  end

  local modelPaints = model.model.paints
  if modelPaints then
    if not opt.paint then
      if not opt.paintName then
        opt.paintName = config.defaultPaintName1
      end

      if opt.paintName and type(opt.paintName) == 'string' then
        opt.paint = modelPaints[opt.paintName] or modelPaints[config.defaultPaintName1]
      end
    end

    if not opt.paint2 then
     if not opt.paintName2 then
        opt.paintName2 = config.defaultPaintName2
      end

      if opt.paintName2 and type(opt.paintName2) == 'string' then
        opt.paint2 = modelPaints[opt.paintName2] or modelPaints[config.defaultPaintName2]
      end
    end

    if not opt.paint3 then
     if not opt.paintName3 then
        opt.paintName3 = config.defaultPaintName3
      end

      if opt.paintName3 and type(opt.paintName3) == 'string' then
        opt.paint3 = modelPaints[opt.paintName3] or modelPaints[config.defaultPaintName3]
      end
    end
  end

  if not opt.paint and config then
    opt.paint = config.defaultPaint
  end

  if not opt.paint then
    opt.paint = model.model.defaultPaint
  end

  if not opt.config then
    opt.config = 'vehicles/' .. modelName .. '/' .. model.model.default_pc .. '.pc'
  elseif type(opt.config) == 'string' and not string.find(opt.config, '.pc') and FS:fileExists('/vehicles/' .. modelName .. '/' .. opt.config .. '.pc') then
    opt.config = 'vehicles/' .. modelName .. '/' .. opt.config .. '.pc'
  end
  -- log('I', 'vehicle', 'spawnFilldefaults: opt After = '..dumps(opt))
  return opt
end

function sanitizeVehicleSpawnOptions(model, opt)
  -- NOTE(AK): 09/11/2021 There is a final sanitizing on parts config data in C++ function BeamNGVehicle::spawnObject.
  --                      Look for comment "IMPORTANT Sanitizing the entire parts config data" in the function
  local options = fillVehicleSpawnOptionDefaults(model, opt)
  if options.paint then
    options.paint = validateVehiclePaint(options.paint)
  end

  if options.paint2 then
    options.paint2 = validateVehiclePaint(options.paint2)
  else
    options.paint2 = options.paint
  end

  if options.paint3 then
    options.paint3 = validateVehiclePaint(options.paint3)
  else
    options.paint3 = options.paint
  end

  options.licenseText = opt.licenseText
  options.vehicleName = opt.vehicleName

  local playerVehicle = nil
  if not options.pos or not options.rot then
    playerVehicle = be:getPlayerVehicle(0)
  end

  if not options.pos then
    if commands.isFreeCamera() or not playerVehicle then
      options.pos = getCameraPosition()
    else
      -- Spawn the vehicle on the left of the player vehicle
      local dir = vec3(playerVehicle:getDirectionVector()):normalized()
      local offset = vec3(-dir.y, dir.x, 0)
      local position = vec3(playerVehicle:getPosition())
      options.pos = position + offset * 5

      options.visibilityPoint = position
    end
  end

  if not options.rot then
    if commands.isFreeCamera() or not playerVehicle then
      local camDir = quat(getCameraQuat()) * vec3(0,1,0)
      camDir.z = 0
      options.rot = quatFromDir(camDir)
    else
      options.rot = quatFromDir(vec3(playerVehicle:getDirectionVector()):normalized(), vec3(playerVehicle:getDirectionVectorUp()):normalized())
    end
  end

  return options
end

function createPlayerSpawningData(model, config, color, licenseText, vehicleName, pos, rot)
  local spawningData = {options={}}

  if not model then
    log('W',logTag, 'createPlayerSpawningData - No model supplied.')
  end

  if not config then
    log('W',logTag, 'createPlayerSpawningData - No config supplied.')
  end

  if color then
    local colorStr = validateVehicleDataColor(color)
    color = stringToTable(colorStr)
    spawningData.options.paint = createVehiclePaint({x=color[1], y=color[2], z=color[3], w=color[4]})
  end

  spawningData.model = model
  spawningData.options.config = config
  spawningData.options.licenseText = licenseText
  spawningData.options.vehicleName = vehicleName
  spawningData.options.pos = pos
  spawningData.options.rot = rot

  return spawningData
end

function extractVehicleData(vid)
  local campaign = campaign_campaigns and campaign_campaigns.getCampaign()
  local vehicleData = campaign and campaign.state.userVehicle
  if not vehicleData then
    local vehicle = scenetree.findObjectById(vid)
    if not vehicle then
      log('W',logTag, 'there is no vehicle with id: '..tostring(vid))
      return
    end
    if not vehicle:isSubClassOf('BeamNGVehicle') then
      log('W',logTag, 'Invalid vehicle id detected. id: '..tostring(vid))
      return
    end

    vehicleData = {}
    local _, config, _ = path.splitWithoutExt(vehicle.partConfig)
    vehicleData.config = config
    vehicleData.licenseText = vehicle:getDynDataFieldbyName("licenseText", 0)
    vehicleData.color = string.format("%0.2f %0.2f %0.2f %0.2f", vehicle.color.x, vehicle.color.y, vehicle.color.z, vehicle.color.w)
    vehicleData.model = vehicle.JBeam
    vehicleData.vehicleName = vehicle:getField('name', '')
  end

  return vehicleData
end

-- little helper for the raycasting function
-- returns nil on no hit, otherwise table
function castRay(origin, target, includeTerrain, renderGeometry)
  if includeTerrain == nil then includeTerrain = false end
  if renderGeometry == nil then renderGeometry = false end

  local res = Engine.castRay(origin, target, includeTerrain, renderGeometry)
  if not res then return res end

  res.pt = vec3(res.pt)
  res.norm = vec3(res.norm)
  return res
end

-- same as castRay, but with debug drawing
function castRayDebug(origin, target, includeTerrain, renderGeometry)
  if includeTerrain == nil then includeTerrain = false end
  if renderGeometry == nil then renderGeometry = false end

  -- ray line
  debugDrawer:drawSphere(origin, 0.1, ColorF(1,0,0,1))
  debugDrawer:drawSphere(target, 0.1, ColorF(0,0,1,1))

  local res = castRay(origin, target, includeTerrain, renderGeometry)

  -- the ray line
  local col = ColorF(0,1,0,1)
  if not res then col = ColorF(1,0,0,1) end
  debugDrawer:drawLine(origin, target, col)

  if not res then return end

  -- draw the collision and the normal of it
  debugDrawer:drawSphere(res.pt, 0.1, ColorF(0,1,0,1))
  debugDrawer:drawLine(res.pt, (res.pt + res.norm), col)

  return res
end

local castRayTest = 0
function testRaycasting(dtReal)
  castRayTest = castRayTest + dtReal

  local a = vec3(4 + math.sin(castRayTest) * 3,-2+math.cos(castRayTest) * 3,10)
  local b = vec3(4 + math.cos(castRayTest) * 3,-2+math.sin(castRayTest) * 3,-10)
  castRayDebug(a, b, false, false)
end

function convertVehicleIdKeysToVehicleNameKeys(data)
  local result
  if data and type(data) == 'table' then
    result = {}
    for vid,v in pairs(data) do
      local vehicle = be:getObjectByID(vid)
      if vehicle then
        local name = vehicle:getField('name', '')
        if not name then
          name = ("vehicle_by_Id_"..vehicle:getID())
          log("W", "", "Vehicle does not have name, using id as string instead: "..dumps(vid) .." -> " .. dumps(name))
        end
        result[name] = v
      else
        log("E", "", "Cannot convert vehicleID to vehicleName, vid does not exist: "..dumps(vid))
      end
    end
  else
    log("E", "", "Cannot convert table from vehicleIDs to vehicleNames, not a table: "..dumps(data))
  end
  return result
end

function convertVehicleNameKeysToVehicleIdKeys(data)
  local result = {}
  if data and type(data) == 'table' then
    result = {}
    for vehicleName,v in pairs(data) do
      local vehicle = scenetree.findObject(vehicleName)
      if vehicle then
        result[vehicle:getId()] = v
      else
        log("E", "", "Cannot convert vehicleID to vehicleName, vid does not exist: "..dumps(vid))
      end
    end
  else
    log("E", "", "Cannot convert table from vehicleNames to vehicleIDs, not a table: "..dumps(data))
  end
  return result
end

function isOfficialContent(path)
  return string.startswith(path, FS:getGamePath())
end

function isOfficialContentVPath(vpath)
  return string.startswith(FS:getFileRealPath(vpath), FS:getGamePath())
end

function isPlayerVehConfig(vpath)
  local osSep = package.config:sub(1,1)
  if not shipping_build and FS:getGamePath() == FS:getUserPath() then return false end --make sure you don't delete official config
  return string.startswith(FS:getFileRealPath(vpath), FS:getUserPath().."vehicles"..osSep) and string.endswith(vpath, ".pc")
end

function imageExistsDefault(path, fallbackPath)
  if path ~= nil and FS:fileExists(path) then
    return path
  else
    return fallbackPath or '/ui/images/appDefault.png'
  end
end

function dirContent(path)
  return FS:findFiles(path, '*', -1, false, false)
end

function fileExistsOrNil(path)
  if type(path) == 'string' and FS:fileExists(path) then
    return path
  end
  return nil
end

function getDirs(path, recursiveLevels)
  local files = FS:findFiles(path, '*', recursiveLevels, false, true)
  local res = {}
  local resMap = {}
  local residx = 1
  for _, value in pairs(files) do
    -- because for some reason there are files inside the result if recursive level is >0
    if not resMap[value] and not string.match(value, '^.*/.*%..*$') then
      res[residx] = value
      resMap[value] = true
      residx = residx + 1
    end
  end

  return res
end

function getFileSize(filename)
  local res = -1
  local f = io.open(filename, "r")
  if f == nil then
    return res
  end
  res = f:seek("end")
  f:close()
  return res
end

-- Return the string 'str', with all magic (pattern) characters escaped.
function escape_magic(str)
  assert(type(str) == "string", "utils.escape: Argument 'str' is not a string.")
  local escaped = str:gsub('[%-%.%+%[%]%(%)%^%%%?%*%^%$]','%%%1')
  return escaped
end

-- returns translated value, unit, system, big
local metersInMiles = 1609.344
function translateDistance(value, big)
  local target = settings.getValue('uiUnitLength')
  value = value or 0
  if target == 'metric' then
    if big == "auto" then
      big = value >= 1000
    end
    if big then
      return value*0.001, "km", target, true
    else
      return value, "m", target, false
    end
  elseif target == 'imperial' then
    if big == "auto" then
      big = value >= metersInMiles
    end
    if big then
      return value * 0.00062137, "mi", target, true
    else
      return value * 3.2808, "ft", target, false
    end
  end
end

-- returns translated value, unit, system, big
function translateVelocity(value, big)
  local value, unit, system = translateDistance(value, big)
  if system == 'metric' then
    if big then
      return value*3600, "km/h", system, big
    else
      return value, "m/s", system, big
    end
  else
    if big then
      return value*3600, "mph", system, big
    else
      return value, "ft/s", system, big
    end
  end
end

local __randomWasSeeded = false
function tableChooseRandomKey(t)
  if t == nil then return nil end
  if not __randomWasSeeded then
    math.randomseed(os.time())
    __randomWasSeeded = true
  end
  local randval = math.random(1, tableSize(t))
  local n = 0
  for k, v in pairs(t) do
    n = n + 1
    if n == randval then
      return k
    end
  end
  return nil
end

function randomASCIIString(len)
  if not __randomWasSeeded then
    math.randomseed(os.time())
    __randomWasSeeded = true
  end
  local res = ''
  local ascii = '01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
  local sl = string.len(ascii)
  for i = 1, len do
    local k = math.random(1, sl)
    res = res .. string.sub(ascii, k, k)
  end
  return res
end

-- converts string str separated with separator sep to table
function stringToTable(str, sep)
  if sep == nil then
    sep = "%s"
  end

  local t = {}
  local i = 1
  for s in string.gmatch(str, "([^"..sep.."]+)") do
    t[i] = s
    i = i + 1
  end
  return t
end

local spaceSepTable = {}
function spaceSeparated4Values(a,b,c,d)
  spaceSepTable[1], spaceSepTable[2], spaceSepTable[3], spaceSepTable[4] = a,b,c,d
  return table.concat(spaceSepTable, " ")
end

function copyfile(src, dst)
  local infile = io.open(src, "r")
  if not infile then return nil end
  local outfile = io.open(dst, "w")
  if not outfile then return nil end
  outfile:write(infile:read("*a"))
  infile:close()
  outfile:close()
end

-- returns a list of immidiate directories with full path in given path
function getDirectories(path)
  local files = FS:findFiles(path,"*", 0, true, true)
  local dirs = {}
  for _,v in pairs(files) do
    if FS:directoryExists(v) and not FS:fileExists(v) then
      table.insert(dirs, v)
    end
  end
  return dirs
end


-- FPS limiter utility. How to use:
--[[
local fpsLimiter = newFPSLimiter(20)

local function onPreRender(dtReal, dtSim, dtRaw)
  if(fpsLimiter:update(dtReal)) then
     ... do somthging here at 20 FPS ...
  end
  ...
--]]
function newFPSLimiter(targetFPS)
  local targetTime = 1 / targetFPS
  local FPSLimiter = {}
  FPSLimiter.__index = FPSLimiter
  FPSLimiter.update = function(self, dt)
    self.time = self.time + dt
    if self.time > targetTime then
      self.time = self.time % targetTime
      return true
    end
    return false
  end
  return setmetatable({ time = 0 }, FPSLimiter)
end

function the_high_sea_crap_detector()
  -- this function only shows a message to entice people to get the game.
  -- please support development of BeamNG.drive and leave this in here :)
  local files = FS:findFiles('/', '*.url', 0, false, false)
  local knownHashes = {
    ['24cc61dd875c262b4bbdd0d07e448015ae47b678'] = 1,
    ['a42eba9d2cf366fb52589517f7f260c401c99925'] = 1
  }
  for _, f in pairs(files) do
    --print( ' - ' .. string.upper(f) .. ' = ' .. hashStringSHA1(string.upper(f)))
    if knownHashes[hashStringSHA1(string.upper(f))] then
      log('I', 'highSeas','Ahoy!')
      return true
    end
  end
  return false
end

-- returns the function parameter names and if its variadic
-- SLOW uses only very sparingly
function getFunctionParameters(func)
  local f = debug.getinfo(func, 'u')
  local parameters = {}
  for i = 1, f.nparams do
    table.insert(parameters, debug.getlocal(func, i))
  end
  return parameters, f.isvararg
end

function generateObjectNameForClass(className, objectName)
  local name = objectName
  local maxId = 0
  local objects = scenetree.findClassObjects(className)
  for _, objName in ipairs(objects) do
    local object = scenetree.findObject(objName)
    local id = object and object:getId() or 0
    if id > maxId then
      maxId = id
    end
  end
  name = objectName..tostring(maxId + 1)
  return name
end
local function eq(a,b) return a==b end
local function lt(a,b) return a<b  end
local function gt(a,b) return a>b  end
local function lte(a,b) return a<=b end
local function gte(a,b) return a>=b end
local function neq(a,b) return a~=b end
local comparisonOps = {
  {opSymbol = '==', op = function(a,b) return a==b end,  opName = 'Equal To',                 opNameLc = "equal to"},
  {opSymbol = '<',  op = lt,  opName = 'Less Than',                opNameLc = "less than"},
  {opSymbol = '>',  op = gt,  opName = 'Greater Than',             opNameLc = 'greater than'},
  {opSymbol = '<=', op = lte, opName = 'Less Than or Equal To',    opNameLc = 'less than or equal to'},
  {opSymbol = '>=', op = gte, opName = 'Greater Than or Equal To', opNameLc = 'greater than or equal to'},
  {opSymbol = '~=', op = neq, opName = 'Not Equal To',             opNameLc = 'not equal to'},
}
function getComparisonOps() return comparisonOps end

--== Package loaders ==--
-- test for writing our own package loader
local function advancedModuleLoader(modulename)
  local modulepath = string.gsub(modulename, "%.", "/")
  for path in string.gmatch(package.path, "([^;]+)") do
    local filename = string.gsub(path, "%?", modulepath)
    filename = filename:gsub('//', '/') -- prevent having double slashes in the lookup path
    local file = io.open(filename, "rb")
    if file then
      local content = file:read("*a")
      file:close()
      --print(">>>>> load <<<< " .. tostring(modulename) .. ' = ' .. tostring(filename))
      if string.find(filename, '/extensions/') then
        local modulenameVirt = string.gsub(modulename, "/", '_')
        -- the trick to not screw with line numbers: everything needs to be in the same line. Otherwise the line numbers for the debuggers won't fit anymore
        content = "local logTag = '"..modulenameVirt.."'; local log = function(level, origin, msg) log(level, msg and ('"..modulenameVirt..".'..origin) or origin, msg) end;" .. content --if using all 3 logging args, then prefix the module name into 'origin'
        --print(content)
      end
      -- Compile and return the module
      return loadstring(content, filename)
    end
    --errmsg = errmsg.."\n\tno file '"..filename.."' (checked with custom loader)"
  end
  return nil
end

-- Install the loader so that it's called just before the normal Lua loader
if vmType == 'game' then
  table.insert(package.loaders, 2, advancedModuleLoader)
end

-- backward compatibility below
string.c_str = function(self) return self end
