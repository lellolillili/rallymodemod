-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local min = math.min
local max = math.max
local pow = math.pow
local ceil = math.ceil
local floor = math.floor
local random = math.random
local huge = math.huge

local M = {}

local logTag = 'multiSpawn'

local vecUp = vec3(0, 0, 1)
local vecY = vec3(0, 1, 0)

local savedGroup
local groupId = 0
local spawningBusy = false
local queue = {}
local defaultOptions = {model = 'pickup'}
local defaultPaint = createVehiclePaint({x = 1, y = 1, z = 1, w = 1})
local defaultFilters = {Type = {car = 1, truck = 1}}

M.startEngines = true -- this system will always spawn vehicles with their engines on by default

local function shuffleIntegers(num, total) -- creates and shuffles list of integers
  local array, list = {}, {}
  for i = 1, num do
    table.insert(array, i)
  end
  array = arrayShuffle(array)

  for i = 1, total do
    local mod = i % num
    local idx = i <= num and i or (mod > 0 and mod or num) -- looping index
    table.insert(list, array[idx])
  end
  return list
end

local function binarySearchRange(tbl, key, target) -- returns the index of the target range (binary search)
  local l, n = 1, #tbl
  local m

  while l <= n do
    m = floor((l + n) * 0.5)
    local range = tbl[m][key]

    if range[2] <= target then -- rangeMax
      l = m + 1
    elseif range[1] > target then -- rangeMin
      n = m - 1
    else
      return m
    end
  end
  return m
end

local function getNewId() -- returns the unique id of the current group spawn job
  groupId = groupId + 1
  return groupId
end

local function getIndexRandomPop(data) -- returns the index by using a random population value and finding the corresponding data value
  local randNum = random() * data.popTotal
  for i, v in ipairs(data) do
    if randNum < v.pop then
      return i
    else
      randNum = randNum - v.pop
    end
  end
end

local function getOtherVehicles(includePlayer) -- DEPRECATED; returns all other vehicles vehicle ids
  local others = {}

  for _, v in ipairs(getAllVehicles()) do
    local id = v:getID()
    if includePlayer or id ~= be:getPlayerVehicleID(0) then
      table.insert(others, id)
    end
  end
  return others
end

local function setGroup(data, name) -- DEPRECATED; sets a custom vehicle group to use next
  if type(name) == 'table' then -- backwards compatible
    data, name = name, data
  end
  if not data or not data[1] then
    log('W', logTag, 'Vehicle group is empty!')
  else
    savedGroup = data
  end
end

local function getPopulationFactor(modelData, configData, params) -- returns the weighted factor from the given filters
  params = params or {}
  params.filters = params.filters or {}
  local factor = 1

  if params.maxYear then
    local vehYear
    local maxYear = params.maxYear
    local validYear = true

    configData.Years = configData.Years or modelData.Years
    if type(configData.Years) == 'table' and type(configData.Years.max) == 'number' then
      vehYear = configData.Years.max
    end

    if vehYear then
      if maxYear > 0 then
        validYear = vehYear <= maxYear
      else
        maxYear = 2000 -- what?
      end

      factor = validYear and factor * min(1, square((100 - max(0, maxYear - vehYear)) / 100)) or 0
    end
  end

  for k, v in pairs(params.filters) do -- each inner table pair should have a coefficient: {Type = {car = 1, truck = 0.4}}
    if configData[k] then
      local configKey = configData[k]
      if type(configKey) == 'string' then configKey = string.lower(configKey) end

      if type(v[configKey]) == 'number' then -- filter value
        factor = factor * v[configKey]
      else
        factor = type(v.other) == 'number' and factor * v.other or 0 -- if 'other' exists, use it
      end
    end

    if factor <= 0 then return 0 end
  end
  return factor
end

local function isOfficialSource(data) -- checks if vehicle model or config is official
  return (data and data.aggregates and data.aggregates.Source and data.aggregates.Source['BeamNG - Official'])
end

local function getInstalledVehicleData(params) -- gets all vehicles and creates the initial data
  params = params or {allMods = false, allConfigs = true}
  params.filters = params.filters or deepcopy(defaultFilters)
  local minPop = params.minPop or 0
  local data = {countryRatios = {}}
  local countryEntries = 0

  for _, model in pairs(core_vehicles.getModelList().models) do
    local officialModel = isOfficialSource(model)
    if params.allMods or officialModel then
      local configData = {}
      local vehType = model.Type and string.lower(model.Type)
      local country = model.Country and string.lower(model.Country) or 'default'
      local defaultConfig = model.default_pc
      local defaultPop, defaultPopFactor = 0, 1

      if country ~= 'default' then
        countryEntries = countryEntries + 1
        data.countryRatios[country] = (data.countryRatios[country] or 0) + 1 -- counts up country of origin entries
      end

      for _, config in pairs(core_vehicles.getModel(model.key).configs) do
        local officialConfig = isOfficialSource(config)
        if params.allMods or officialConfig then
          local popValue = config.Population
          if not popValue or (popValue and popValue >= minPop) then
            config.Country = country
            config.Type = config.Type and string.lower(config.Type) or vehType
            config['Derby Class'] = model['Derby Class']
            if not popValue then
              if not officialModel or not officialConfig then
                popValue = 1000 -- temp population value
              else
                popValue = 0
              end
            end
            local popFactor = getPopulationFactor(model, config, params)

            if popFactor > 0 then
              if popValue > defaultPop then -- searches for the maximum population value to apply to model data
                defaultPop = popValue
                defaultPopFactor = popFactor
              end

              if params.allConfigs or config.key == defaultConfig then
                table.insert(configData, {
                  config = config.key,
                  popBase = popValue,
                  popFactor = popFactor
                })
              end
            end
          end
        end
      end

      if configData[1] then
        table.insert(data, {
          model = model.key,
          country = country,
          popBase = defaultPop,
          popFactor = defaultPopFactor,
          configData = configData
        })
      end
    end
  end

  for k, v in pairs(data.countryRatios) do
    data.countryRatios[k] = v / max(1, countryEntries) -- this value is used to improve probability bias of vehicles with a rarer country of origin
  end
  return data
end

local function setPopulationData(data, country, popPower) -- sets the relative population value for each vehicle
  if not popPower or popPower <= 0 then
    popPower = 1
  else
    popPower = min(1.5, popPower)
  end
  data.popTotal = 0

  for _, v in ipairs(data) do
    local countryCoef = 1
    if country then
      if data.countryRatios and data.countryRatios[country] and v.country == country then
        local power = 2 - math.log(v.popBase, 10) / 5 -- population based modification to apply to countryCoef
        countryCoef = max(1, (1 / pow(data.countryRatios[country], power)) * v.popFactor) -- this increases the probability weight of vehicles from the given country
      end
    end

    if v.popBase * v.popFactor > 0 then
      v.pop = round(pow(v.popBase * v.popFactor, popPower) * countryCoef) -- popPower modifies the probability weight of each vehicle to improve the randomness of selections
      data.popTotal = data.popTotal + v.pop
    else
      v.pop = 0
    end
  end

  return data
end

local function buildGroup(data, amount, modelPopPower, configPopPower) -- randomly builds the vehicle group from the installed vehicle data
  local newGroup, list = {}, {}
  local modelIdx, configIdx

  -- if not population power value, use simple randomization; else, use range-based randomization
  if not modelPopPower or modelPopPower <= 0 then
    list = shuffleIntegers(#data, amount)
  else
    table.sort(data, function(a, b) return a.pop > b.pop end) -- for optimized index searching
  end

  for i = 1, amount do
    if not modelPopPower then -- first, randomly pick model
      modelIdx = list[i] or 1
    else
      modelIdx = getIndexRandomPop(data)
      -- modelIdx = binarySearchRange(data, 'range', data[#data]['range'][2] * random())
    end
    local model = data[modelIdx]
    if model then
      local cLength = #model.configData

      if not configPopPower or configPopPower <= 0 then -- then, randomly pick config
        configIdx = random(cLength)
      else
        table.sort(model.configData, function(a, b) return a.pop > b.pop end)
        configIdx = getIndexRandomPop(model.configData)
        -- configIdx = cLength > 0 and binarySearchRange(model.configData, 'range', model.configData[cLength]['range'][2] * random()) or 1
      end
      table.insert(newGroup, {model = model.model, config = model.configData[configIdx].config, pop = model.configData[configIdx].pop})

      if model.pop > 1 then -- unless value is 1, recude the inserted vehicle's population value to lower the probability of it getting selected again
        local newPop = ceil(model.pop * 0.05) -- 5% of old population
        data.popTotal = data.popTotal - (model.pop - newPop)
        model.pop = newPop
      end
    end
  end

  return newGroup
end

local function createGroup(amount, params) -- creates a new spawn group from a table of parameters
  -- params = {allMods, allConfigs, filters, country, modelPopPower, configPopPower}
  params = params or {}
  amount = amount or 10 -- default group size
  params.filters = params.filters or deepcopy(defaultFilters)
  -- default filters: Type = selects valid road vehicles
  -- special filters: maxYear = latest year to allow for selection

  if params.country then params.country = string.lower(params.country) end
  local vehicleData = getInstalledVehicleData(params)

  if not vehicleData[1] then
    log('W', logTag, 'No vehicle data found from filters!')
    return {}
  end

  -- set population data for models, then for its configs
  vehicleData = setPopulationData(vehicleData, params.country, params.modelPopPower)
  for _, v in ipairs(vehicleData) do
    v.configData = setPopulationData(v.configData, nil, params.configPopPower)
  end

  return buildGroup(vehicleData, amount, params.modelPopPower, params.configPopPower)
end

local function vehIdsToGroup(vehIds) -- converts a list of vehicle ids to the vehicle group format
  local res = {}
  if not vehIds then return res end

  for _, id in ipairs(vehIds) do
    local data = {}
    local vehData = core_vehicle_manager.getVehicleData(id)
    if vehData then
      local config = vehData.config
      data.model = config.model or string.match(config.partConfigFilename, 'vehicles/([%w|_|%-|%s]+)') -- model might be nil for some reason

      if data.model then
        data.config = string.match(config.partConfigFilename, '/*([%w_%-]+).pc')
        data.paint, data.paint2, data.paint3 = config.paints[1], config.paints[2], config.paints[3]
        data.paintName, data.paintName2, data.paintName3 = 'custom', 'custom', 'custom' -- assumes custom paints (?)
        table.insert(res, data)
      end
    end
  end

  return res
end

local function spawnedVehsToGroup(ignorePlayer) -- converts all currently spawned vehicles to the vehicle group format
  local vehIds = {}

  for _, v in ipairs(getAllVehiclesByType()) do
    if not (ignorePlayer and v:getID() == be:getPlayerVehicleID(0)) then
      table.insert(vehIds, v:getID())
    end
  end

  return vehIdsToGroup(vehIds)
end

local function getLinePoint(pos, rot, ignoreSnap) -- returns a spawn point on any terrain
  if ignoreSnap then return pos, rot end

  local z = be:getSurfaceHeightBelow((pos + vecUp * 4))

  if z >= -1e6 then
    pos.z = z
  elseif core_terrain.getTerrain() then
    pos.z = core_terrain.getTerrainHeight(pos)
  end
  return pos, rot
end

local function getRoadPoint(path, dist, side, legalSide, dir) -- returns a spawn point on a road
  local pos, rot

  if not (path.pos1 and path.pos2) then
    legalSide = legalSide or 1
    local mapNodes = map.getMap().nodes

    local n1, n2, xnorm = map.getNodesFromPathDist(path, dist)
    local p1, p2 = mapNodes[n1].pos, mapNodes[n2].pos
    local radius = lerp(mapNodes[n1].radius, mapNodes[n2].radius, xnorm)

    local baseRot = (p2 - p1):normalized()
    rot = vec3(baseRot)

    if dir then
      rot = rot * dir
    else -- smart direction
      local link = mapNodes[n1].links[n2] or mapNodes[n2].links[n1]
      if link.oneWay then
        rot = link.inNode == n1 and rot or -rot
      else
        rot = rot * sign2(side * legalSide)
      end
    end

    pos = linePointFromXnorm(p1, p2, xnorm) + baseRot:z0():normalized():cross(vecUp) * radius * side
  else
    rot = (path.pos2 - path.pos1):normalized()
    pos, rot = getLinePoint(path.pos1 + rot * dist + rot:cross(vecUp) * (2 * sign2(side) - 2), rot)
  end

  return pos, rot
end

local spawnModes = {
  roadAhead = function (data) -- road ahead, facing away from start
    return getRoadPoint(data.path, data.dist + data.idx * data.gap, data.legalSide * 0.5, 1, 1)
  end,
  roadBehind = function (data) -- road behind, facing towards start
    return getRoadPoint(data.path, data.dist + data.idx * data.gap, data.legalSide * -0.5, 1, -1)
  end,
  roadAheadAlt = function (data) -- road ahead, facing towards start
    return getRoadPoint(data.path, data.dist + data.idx * data.gap, data.legalSide * -0.5, 1, -1)
  end,
  roadBehindAlt = function (data) -- road ahead, facing away from start
    return getRoadPoint(data.path, data.dist + data.idx * data.gap, data.legalSide * 0.5, 1, 1)
  end,
  traffic = function (data) -- smart traffic formation
    return getRoadPoint(data.path, data.dist + data.idx * data.gap, data.laneSide * 0.5, data.legalSide)
  end,
  raceGrid = function (data) -- race grid formation
    return getRoadPoint(data.path, data.dist + floor(data.idx / 2) * data.gap, data.laneSide * 0.5, 1, 1)
  end,
  raceGridAlt = function (data) -- race grid formation, shifted so that the next point is diagonal
    return getRoadPoint(data.path, data.dist + data.idx * data.gap, data.laneSide * 0.5, 1, 1)
  end,
  lineLeft = function (data)
    return getLinePoint(data.pos - data.rot:z0():cross(vecUp) * data.idx * data.gap, data.rot)
  end,
  lineRight = function (data)
    return getLinePoint(data.pos + data.rot:z0():cross(vecUp) * data.idx * data.gap, data.rot)
  end,
  lineBehind = function (data)
    return getLinePoint(data.pos - data.rot * data.idx * data.gap, data.rot)
  end,
  lineAbove = function (data)
    return getLinePoint(data.pos + vecUp * data.idx * data.gap, data.rot, true)
  end,
  lineAhead = function (data)
    return getLinePoint(data.pos + data.rot * data.idx * data.gap, data.rot)
  end
}

local function adjustVehicles(vehIds, ignoreSafe) -- refines vehicle positions after spawning
  for _, v in ipairs(vehIds) do
    local obj = be:getObjectByID(v)
    if obj then
      local pos = obj:getPosition()
      local rot = quat(0, 0, 1, 0) * quat(obj:getRotation())
      --local bbCenter = vec3(obj.initialNodePosBB:getCenter()):z0()
      local offset = obj:getInitialNodePosition(obj:getRefNodeId())
      offset = offset:rotated(rot):z0()
      pos:setSub(offset)

      if not ignoreSafe then
        spawn.safeTeleport(obj, pos, rot)
      else
        rot = quat(0, 0, 1, 0) * rot
        obj:setPosRot(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
      end

      obj:queueLuaCommand('recovery.saveHome()') -- saves the adjusted position so it can be used for resets
    end
  end
end

local function workSpawnVehicles(job, spawnData, spawnOptions) -- processes vehicles to be spawned
  local vehIds = {}
  for i, data in ipairs(spawnData) do
    log('I', logTag, 'Vehicle group spawning in progress ('..i..' / '..#spawnData..')')
    local veh = spawn.spawnVehicle(data.model, data.config, data.pos, data.rot, data)
    if job then
      job.yield()
    end

    if veh then
      table.insert(vehIds, veh:getId())
      veh:setDynDataFieldbyName('vehicleGroup', 0, tostring(spawnOptions.name))
    else
      log('W', logTag, 'Vehicle failed to load; skipping this group entry')
    end
  end

  if not spawnOptions.ignoreAdjust then
    local cling = spawnOptions.cling and true or false
    adjustVehicles(vehIds, not cling)
  end

  if job then
    job.sleep(0.001) -- final frame delay, to ensure vehicle positions are ready
  end

  spawningBusy = false
  log('I', logTag, 'Vehicle group spawning completed: '..tostring(spawnOptions.name))
  extensions.hook('onVehicleGroupSpawned', vehIds, groupId, spawnOptions.name)

  if queue[1] then -- next vehicle group to instantly spawn
    local args = queue[1]
    table.remove(queue, 1)
    M.spawnGroup(unpack(args))
  end
end

local function createSpawnPositions(amount, options) -- creates a list of smart spawn positions for vehicles to use
  options = options or {}
  amount = amount or 20
  local transformData = {}

  local mode = options.mode or 'roadAhead'
  local gap = options.gap or 15
  if options.func or mode == 'road' then mode = 'roadAhead' end

  local playerFocus = false
  local rot, pos
  local camPos = getCameraPosition()
  local camDir = getCameraForward()
  local mapNodes = map.getMap().nodes

  local veh = be:getPlayerVehicle(0)
  if veh then
    if commands.isFreeCamera() then
      playerFocus = veh:getPosition():distance(camPos) <= 15 -- focus point can be at player vehicle or camera depending on camera mode
    else
      playerFocus = true
    end
  end

  local start
  if options.pos then
    pos = options.pos
    rot = options.rot or quat(getCameraQuat()) -- quaternion
    rot = vecY:rotated(rot)
    start = 0
  else
    if playerFocus then
      pos = veh:getPosition() + veh:getInitialNodePosition(veh:getRefNodeId()) -- centered
      rot = veh:getDirectionVector()
      start = 1 -- avoids spawning at the player's position
    else
      pos = camPos
      rot = camDir
      start = 0
    end
  end

  start = options.startIndex or start -- custom start index

  local path, origin
  local maxLength = 100 + gap * amount
  local dist = 0
  local lane = 1
  local n1, n2 = map.findClosestRoad(pos)
  local legalSide = map.getRoadRules().rightHandDrive and -1 or 1

  if mode == 'roadBehind' or mode == 'roadBehindAlt' then
    rot = -rot
  end

  if n1 then
    local p1, p2 = mapNodes[n1].pos, mapNodes[n2].pos
    if (p2 - p1):dot(rot) < 0 then
      n1, n2 = n2, n1
      p1, p2 = p2, p1
    end

    path = map.getGraphpath():getRandomPathG(n1, rot, maxLength, nil, nil, false)
    if path then
      p1, p2 = mapNodes[path[1]].pos, mapNodes[path[2]].pos
      origin = linePointFromXnorm(p1, p2, clamp(pos:xnormOnLine(p1, p2), 0, 1))
      dist = origin:distance(p1)
      lane = rot:z0():cross(vecUp):dot((pos - origin):z0()) >= 0 and 1 or -1
    else
      path = {pos1 = pos, pos2 = pos + rot}
    end
  else
    path = {pos1 = pos, pos2 = pos + rot}
  end

  if (mode == 'raceGrid' or mode == 'raceGridAlt') and path[1] and mapNodes[path[1]].radius + mapNodes[path[2]].radius < 4.8 then -- road is presumably too narrow for the modes
    log('W', logTag, 'Road too narrow, switching to default road spawn method')
    mode = 'roadAhead'
  end

  for i = 1, amount do
    local newPos, newRot
    local idx = i + start - 1 -- idx starts at zero if group starts spawning exactly at given pos
    local laneSide = idx % 2 == 0 and lane or -lane
    local funcData = {idx = idx, path = path, dist = dist, gap = gap, laneSide = laneSide, legalSide = legalSide, pos = pos, rot = rot}

    if options.func then -- custom spawn function
      newPos, newRot = options.func(funcData)
    elseif spawnModes[mode] then -- predefined spawn function
      newPos, newRot = spawnModes[mode](funcData)
    else -- default line method
      newPos, newRot = getLinePoint(pos + rot * idx * gap, rot)
    end

    newRot = quatFromDir(vecY:rotated(quatFromDir(newRot:z0(), vecUp)), vecUp)

    transformData[i] = {pos = newPos, rot = newRot}
  end

  return transformData
end

local function spawnProcessedGroup(spawnData, spawnOptions) -- sets the spawn points of multiple vehicles
  if not scenetree.MissionGroup then
    log('W', logTag, 'MissionGroup does not exist!')
    return
  end

  if not spawnData or not next(spawnData) then
    log('W', logTag, 'Vehicle spawn options array is empty!')
    return
  end

  if spawnOptions.mode == 'road' then spawnOptions.mode = 'roadAhead' end
  if spawnOptions.mode == 'lineAbove' then spawnOptions.cling = false end

  local transformData
  if spawnOptions and type(spawnOptions.customTransforms) == 'table' and #spawnOptions.customTransforms >= #spawnData then
    transformData = spawnOptions.customTransforms
  else
    transformData = createSpawnPositions(#spawnData, spawnOptions)
  end

  for i, v in ipairs(spawnData) do
    v.cling = spawnOptions.cling
    v.autoEnterVehicle = false
    spawnData[i] = sanitizeVehicleSpawnOptions(v.model, spawnData[i])
    spawnData[i].visibilityPoint = nil
    v.pos = transformData[i].pos
    v.rot = transformData[i].rot
  end

  groupId = getNewId()

  -- NOTE: if ignoring the job system, the vehicles will spawn before the group id is able to be returned from this function!
  if not spawnOptions.instant then
    extensions.core_jobsystem.create(workSpawnVehicles, 0.5, spawnData, spawnOptions)
  else
    workSpawnVehicles(nil, spawnData, spawnOptions)
  end
  return groupId
end

local function workPlaceVehicles(job, vehIds, transformData, options) -- processes vehicles to be teleported
  options = options or {}
  for i, v in ipairs(vehIds) do
    local obj = be:getObjectByID(v)
    if obj then
      local pos = transformData[i].pos
      local rot = transformData[i].rot
      if not options.ignoreAdjust then
        local offset = obj:getInitialNodePosition(obj:getRefNodeId())
        offset = offset:rotated(rot)
        pos:setSub(offset)
      end

      if not options.ignoreSafe then
        spawn.safeTeleport(obj, pos, rot)
      else
        rot = quat(0, 0, 1, 0) * rot
        obj:setPosRot(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
      end

      if job then
        job.sleep(0.05) -- what value should be used here? The goal is to reduce lag spikes from respawning vehicles, but also be fast
      end
    end
  end

  log('I', logTag, 'Vehicle group placing completed')
  extensions.hook('onVehicleGroupRespawned', vehIds)
end

local function placeGroup(vehIds, options) -- teleports a group of active vehicles into a new formation
  if not vehIds or not vehIds[1] then return end

  local transformData
  local instant = options and options.instant
  if options and type(options.customTransforms) == 'table' and #options.customTransforms >= #vehIds then
    transformData = options.customTransforms
  else
    transformData = createSpawnPositions(#vehIds, options)
  end

  if not instant then
    extensions.core_jobsystem.create(workPlaceVehicles, 1, vehIds, transformData, options)
  else
    workPlaceVehicles(nil, vehIds, transformData, options)
  end
end

local function fitGroup(group, amount) -- fits a group to the given table size
  local groupSize = #group
  if groupSize == 0 then return group end
  amount = amount or groupSize
  local nextIndex = 0

  if groupSize < amount then
    for i = groupSize, amount - 1 do
      nextIndex = nextIndex + 1
      if (nextIndex % (groupSize + 1)) == 0 then
        nextIndex = 1
      end

      table.insert(group, deepcopy(group[nextIndex]))
    end
  elseif groupSize > amount then
    for i = groupSize, amount + 1, -1 do
      table.remove(group, i)
    end
  end

  return group
end

local function setVehicleSpawnData(group, amount) -- parses and sets the vehicle data from the spawn group
  if not group or not group[1] then
    log('W', logTag, 'Vehicle group is empty!')
    return
  end

  local spawnData = {}
  local groupCopy = deepcopy(group)
  groupCopy = fitGroup(groupCopy, amount)

  for i, options in ipairs(groupCopy) do
    if options[1] then -- old array format
      options = {model = options[1], config = options[2], color1 = options[3], color2 = options[4], color3 = options[5]}
    end

    local modelData = core_vehicles.getModel(options.model)
    if modelData and next(modelData) then
      if not options.config or options.config == 'base' then
        options.config = modelData.model.default_pc
      end

      local paints = modelData.model.paints or {}
      local paintNames = tableKeys(paints)
      local paintCount = tableSize(paintNames)
      local paintLayerKeys = {'paint', 'paint2', 'paint3'}

      for j, color in ipairs({'color1', 'color2', 'color3'}) do -- convert old colors to paints
        if options[color] then
          local values = stringToTable(options[color])
          if values[4] then
            options[paintLayerKeys[j]] = createVehiclePaint({x = values[1], y = values[2], z = values[3], w = values[4]})
          end
        end
        options[color] = nil
      end

      for j, pName in ipairs({'paintName', 'paintName2', 'paintName3'}) do
        local pKey = paintLayerKeys[j]
        if options[pName] and options[pName] == 'random' then
          options[pKey] = paints[paintNames[random(paintCount)]]
        else
          if not options[pKey] then
            options[pKey] = paints[options[pKey]]
          end
        end
      end

      spawnData[i] = options
    else
      log('E', logTag, 'Vehicle model not found: '..options.model)
      spawnData[i] = deepcopy(defaultOptions)
    end
  end
  return spawnData
end

local function spawnGroup(group, amount, options) -- spawns a given vehicle group
  if not amount or amount <= 0 then
    log('W', logTag, 'Spawn amount is zero!')
    return
  end

  if spawningBusy then
    table.insert(queue, {group, amount, options})
    log('I', logTag, 'Added vehicle group to queue, it will spawn when ready')
    return
  end

  if not group or not group[1] then
    log('W', logTag, 'Could not parse vehicle group data, now creating default group...')
    group = createGroup()
  end

  options = options or {}
  options.name = options.name or 'custom' -- group name
  options.mode = options.mode or 'roadAhead' -- vehicle spawning method
  options.gap = options.gap or 15 -- spacing between spawn positions

  if not options.order then -- vehicle group order
    group = arrayShuffle(deepcopy(group))
  end

  spawningBusy = true
  log('I', logTag, 'Spawning vehicle group with '..amount..' vehicles: '..tostring(options.name))
  return spawnProcessedGroup(setVehicleSpawnData(group, amount), options) -- returns unique group id
end

local function setupVehicles(amount, order, spawnMode, spawnGap) -- DEPRECATED, please use function spawnGroup instead
  return spawnGroup(savedGroup, amount, {order = order, mode = spawnMode, gap = spawnGap})
end

local function deleteVehicles(amount, onlyCars, deletePlayer) -- deletes other vehicles
  local others = onlyCars and getAllVehiclesByType() or getAllVehicles()
  local count = 0
  for i = 1, #others do
    if not deletePlayer and others[i]:getId() ~= be:getPlayerVehicleID(0) then
      others[i]:delete()
      count = count + 1
    end
    if amount and count >= amount then break end
  end
end

local function onSpawnCCallback(id)
  if spawningBusy then -- this is the best solution for now ._.
    core_vehicle_manager.queueAdditionalVehicleData({spawnWithEngineRunning = M.startEngines}, id) -- start with engines running by default
  end
end

-- public interface
M.deleteVehicles = deleteVehicles
M.setupVehicles = setupVehicles
M.getOtherVehicles = getOtherVehicles
M.getNewVehicles = getOtherVehicles
M.getInstalledVehicleData = getInstalledVehicleData
M.vehIdsToGroup = vehIdsToGroup
M.spawnedVehsToGroup = spawnedVehsToGroup

M.setGroup = setGroup
M.createGroup = createGroup
M.spawnGroup = spawnGroup
M.spawnProcessedGroup = spawnProcessedGroup
M.fitGroup = fitGroup
M.placeGroup = placeGroup
M.teleportGroup = placeGroup
M.setVehicleSpawnData = setVehicleSpawnData

M.onSpawnCCallback = onSpawnCCallback

return M