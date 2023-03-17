-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local logTag = 'signals'
local intersections, controllers, signalMetadata = {}, {}, {}
local signalsFileDefault = 'settings/trafficSignalsDefault.json'
local defaultSignalType = 'lightsBasic'
local instanceStr = 'instanceColor' -- for traffic signal object
local lightOff, lightOn = '0 0 0 1', '1 1 1 1'
local mapNodes, signalsDict, objectsDict
local defaultDuration = 1
local nextObjId = 0
local timer = 0
local loaded = false
local active = false
local debug = 0
local viewDistSq = 90000
local vecUp = vec3(0, 0, 1)

local queue = require('graphpath').newMinheap()

local function getNextId()
  nextObjId = nextObjId + 1
  return nextObjId
end

-- Intersection
-- Contains main position, signal control data, traffic light objects, and directional signal nodes with phases
local Intersection = {}
Intersection.__index = Intersection

-- Signal Controller
-- Contains signal type and timing data; used within intersection object
local SignalController = {}
SignalController.__index = SignalController

function Intersection:new(data)
  local o = {}
  data = data or {}
  setmetatable(o, self)

  o.id = getNextId()
  o.name = data.name
  o.pos = data.pos or getCameraPosition()
  o.controllerName = data.controllerName
  o.signalNodes = data.signalNodes or {}

  for _, v in ipairs(o.signalNodes) do
    v.id = getNextId()
  end

  return o
end

function Intersection:addSignalNode(data)
  data = data or {}
  local new = {
    id = getNextId(),
    pos = data.pos or getCameraPosition(),
    signalIdx = data.signalIdx or 1
  }
  table.insert(self.signalNodes, new)
end

function Intersection:deleteSignalNode(idx)
  if not self.signalNodes[idx] then return end
  table.remove(self.signalNodes, idx)
end

function Intersection:updateLights(idx, lights)
  local node = self.signalNodes[idx]
  if node then
    for _, v in ipairs(node._objIds) do -- actual traffic signal objects
      local obj = scenetree.findObjectById(v)
      if obj then
        for i, v in ipairs(lights) do -- dynamic light instances of the traffic light object
          local field = i > 1 and instanceStr..tostring(i - 1) or instanceStr -- 'instanceColor', 'instanceColor1', etc.
          if type(v) == 'table' and v[1] + v[2] + v[3] ~= 0 then
            obj:setField(field, '0', lightOn)
          else
            obj:setField(field, '0', lightOff)
          end
        end
      end
    end
  end
end

function Intersection:onSerialize()
  local data = {
    name = self.name,
    pos = self.pos:toTable(),
    controllerName = self.controllerName,
    signalNodes = {}
  }
  for _, v in ipairs(self.signalNodes) do
    table.insert(data.signalNodes, {pos = v.pos:toTable(), signalIdx = v.signalIdx})
  end
  return data
end

function Intersection:onDeserialized(data)
  if not data then return end

  for k, v in pairs(data) do
    self[k] = v
  end
  self.id = getNextId()
  self.pos = vec3(self.pos)

  for _, v in ipairs(self.signalNodes) do
    v.id = getNextId()
    v.pos = vec3(v.pos)
  end
end

function SignalController:new(data)
  local o = {}
  data = data or {}
  setmetatable(o, self)

  o.name = data.name
  o.signalStartIdx = data.signalStartIdx or 1
  o.lightStartIdx = data.lightStartIdx or 1
  o.startTime = data.startTime or 0
  o.skipStart = type(data.skipStart) == 'boolean' and data.skipStart or false
  o.skipTimer = type(data.skipTimer) == 'boolean' and data.skipTimer or false
  o.customTimings = type(data.customTimings) == 'boolean' and data.customTimings or false
  o.signalIdx = o.signalStartIdx
  o.signals = data.signals or {}

  return o
end

function SignalController:addSignal(data)
  data = data or {}
  data.signalType = data.signalType or defaultSignalType
  local signalProto = signalMetadata.types[data.signalType] or signalMetadata.types[defaultSignalType]
  local new = {
    prototype = data.signalType,
    lightIdx = 0,
    lightDefaultIdx = data.lightDefaultIdx or signalProto.defaultIdx,
    timings = data.timings or deepcopy(signalProto.timings),
    action = signalProto.action
  }
  table.insert(self.signals, new)
end

function SignalController:deleteSignal(idx)
  if not self.signals[idx] then return end
  table.remove(self.signals, idx)
end

function SignalController:getMetadata(sigIdx) -- returns a table of the linked signal type, action, and light instances
  sigIdx = sigIdx or self.signalIdx
  local sig = self.signals[sigIdx]
  if sig then
    local sigType, action, lights

    if sig.timings then
      sigType = sig.timings[sig.lightIdx] and sig.timings[sig.lightIdx].type or 'none'
      if signalMetadata.states[sigType] then
        action = signalMetadata.states[sigType].action
        lights = signalMetadata.states[sigType].lights
      else
        action = 1
        lights = {}

        local altType = sig.timings[1] and sig.timings[1].type
        if altType and signalMetadata.states[altType] then
          for i = 1, #signalMetadata.states[altType].lights do
            table.insert(lights, 'black') -- set all light components to off
          end
        end
      end
    else
      sigType = sig.type or 'none'
      action = sig.action or 1
      lights = {}
    end

    return {type = sigType, action = action, lights = lights}
  end
end

function SignalController:autoSetTimings(sigIdx) -- automatically calculate and set basic timings of the signals
  -- currently, these timing values assume the "permissive yellow" rule
  -- http://onlinepubs.trb.org/Onlinepubs/trr/1985/1027/1027-005.pdf
  local sig = self.signals[sigIdx]
  if sig and sig.timings then
    local bestRadius = 3
    local bestSpeedLimit = 10

    for _, inter in pairs(intersections) do
      for _, sNode in ipairs(inter.signalNodes) do -- best radius
        local n1, n2 = sNode.mapNode, sNode.prevMapNode
        local radius = sNode.pos:distance(inter.pos)
        local link = mapNodes[n1].links[n2] or mapNodes[n2].links[n1]

        if radius > bestRadius then
          bestRadius = radius
        end
        if link.speedLimit > bestSpeedLimit then
          bestSpeedLimit = link.speedLimit
        end
      end
    end

    for _, v in ipairs(sig.timings) do
      if v.type == 'green' then
        v.duration = clamp(bestSpeedLimit * 0.7 + bestRadius * 1.2, 10, 40) -- approximate values based on speed and intersection size
      elseif v.type == 'yellow' then
        v.duration = clamp(1 + (bestSpeedLimit - 4.167) / 3.27, 3, 7) -- simplified extended kinematic equation (3.27 = 9.81 * 0.333)
      elseif v.type == 'red' then
        v.duration = clamp((bestRadius * 2 + 6) / bestSpeedLimit, 0.5, 2) -- full width of intersection plus assumed vehicle length, divided by speed
      end
    end
  end
end

function SignalController:onSignalUpdate(sigIdx) -- updates traffic signal objects and sends new data
  sigIdx = sigIdx or self.signalIdx
  local sig = self.signals[sigIdx]
  if sig then
    local md = self:getMetadata(sigIdx)
    if not md then return end

    for _, inter in pairs(intersections) do
      if inter.controllerName == self.name then
        inter:updateLights(sigIdx, md.lights)

        for _, sNode in ipairs(inter.signalNodes) do
          if sNode.mapNode and sNode.signalIdx == sigIdx then
            if signalsDict and signalsDict.nodes[sNode.mapNode] then
              for i, dNode in ipairs(signalsDict.nodes[sNode.mapNode]) do
                if dNode.id == sNode.id then
                  dNode.action = md.action -- local signalsDict update

                  for _, veh in ipairs(getAllVehiclesByType()) do -- valid vehicles only
                    veh:queueLuaCommand(string.format('mapmgr.updateSignal(%q, %d, %g)', sNode.mapNode, i, md.action or 1))
                  end
                end
              end
            end
          end
        end
      end
    end

    if self._queueId then
      self._queueId = self._queueId + 1
      if sig.timings and sig.timings[sig.lightIdx] then
        queue:insert(timer + sig.timings[sig.lightIdx].duration, {self.name, self._queueId}) -- name & unique id
      end
    end

    extensions.hook('onTrafficSignalUpdate', {name = self.name, signal = sigIdx, light = sig.lightIdx, action = md.action}) -- info from controller
  end
end

function SignalController:setSignal(sIdx, lIdx) -- manual setting of signal and light indexes
  if not sIdx then return end
  self.signalIdx = self.signals[sIdx] and sIdx or 1
  local sig = self.signals[self.signalIdx]
  if sig and sig.timings then
    sig.lightIdx = lIdx
  end

  self:onSignalUpdate(sIdx)
end

function SignalController:advance() -- advances to next signal and/or light
  local sig = self.signals[self.signalIdx]
  if sig and sig.timings then
    if sig.lightIdx > 0 then
      if sig.timings[sig.lightIdx + 1] then -- next light index
        sig.lightIdx = sig.lightIdx + 1
      else -- next signal index, and reset light
        self.signalIdx = self.signals[self.signalIdx + 1] and self.signalIdx + 1 or 1
        sig = self.signals[self.signalIdx]
        sig.lightIdx = 1
      end
    end

    self:onSignalUpdate()
  end
end

function SignalController:activate() -- inserts controller into the main queue
  self._queueId = 0

  if self.signals[1] then
    self.signalIdx = self.signals[self.signalStartIdx] and self.signalStartIdx or 1 -- initial signal

    for i, signal in ipairs(self.signals) do
      if self.signalIdx == i then
        signal.lightIdx = self.lightStartIdx or 1 -- initial light
      else
        signal.lightIdx = signal.lightDefaultIdx or 1 -- sets all signals to default state (red light)
      end

      if signal.timings and not self.customTimings then
        self:autoSetTimings(i)
      end

      self:onSignalUpdate(i, true)
    end

    local sig = self.signals[self.signalIdx]
    sig.lightIdx = self.lightStartIdx

    if sig.timings and sig.timings[sig.lightIdx] then
      self._queueId = self._queueId + 1
      queue:insert(timer + sig.timings[sig.lightIdx].duration - self.startTime, {self.name, self._queueId})
    end
  end
end

function SignalController:deactivate() -- disables the signal
  for i, sig in ipairs(self.signals) do
    sig.lightIdx = 0
    self:onSignalUpdate(i)
  end
end

function SignalController:ignoreTimer(val) -- enables or disables the default timing sequence from updating the signal controller
  if self.skipTimer and not val then self:advance() end
  self.skipTimer = val and true or false
end

function SignalController:onSerialize()
  local data = {
    name = self.name,
    signalStartIdx = self.signalStartIdx,
    lightStartIdx = self.lightStartIdx,
    startTime = self.startTime,
    skipStart = self.skipStart,
    skipTimer = self.skipTimer,
    customTimings = self.customTimings,
    signalIdx = self.signalIdx,
    signals = deepcopy(self.signals)
  }
  for k, v in ipairs(data.signals) do
    if string.startswith(k, '_') then v[k] = nil end
  end
  return data
end

function SignalController:onDeserialized(data)
  if not data then return end

  for k, v in pairs(data) do
    self[k] = v
  end
end

local function newIntersection(data)
  return Intersection:new(data)
end

local function newSignalController(data)
  return SignalController:new(data)
end

local function defaultSignalController() -- basic signal controller
  local new = SignalController:new({name = 'default'})
  for i = 1, 2 do
    new:addSignal() -- two signals for standard intersections
  end
  return new
end

local function getIntersections()
  return intersections
end

local function getControllers()
  return controllers
end

local function getSignalMetadata()
  return signalMetadata
end

local function getValues() -- main values of this module
  return {loaded = loaded, active = active, timer = timer, nextTime = not queue:empty() and queue:peekKey() or 0}
end

local function resetTimer() -- resets the timer & queue, and activates the controllers
  timer = 0
  active = true
  queue:clear()

  for k, v in pairs(controllers) do
    if v.skipStart then
      v:deactivate()
    else
      v:activate()
    end
  end
end

local function setActive(val) -- sets the timer active state
  active = val and true or false
end

local function setDebugLevel(num) -- sets the debug state (includes basic shape visuals for the signals)
  -- 0 = off, 1 = basic, 2 = advanced
  debug = num or 0
end

local function getBestNodes(pos, dir) -- gets the best first & second nodes closest to the position; direction vector is optional
  local n1, n2, dist = map.findClosestRoad(pos)
  if n1 then
    local pos1, pos2 = mapNodes[n1].pos, mapNodes[n2].pos

    if dir then -- n1 = closest node at tail of dir (n1 -> n2)
      if (pos1 - pos2):dot(dir) <= 0 then
        n1, n2 = n2, n1
      end
    else -- n1 = closest node
      if pos2:squaredDistance(pos) < pos1:squaredDistance(pos) then
        n1, n2 = n2, n1
      end
    end

    return n1, n2
  end
end

local function setupSignalObjects()
  objectsDict = {}

  local statics = getObjectsByClass('TSStatic')
  if statics then
    for _, v in ipairs(statics) do -- search for static objects with signal controller dynamic data
      local interName = v.intersection
      local phaseNum = v.signalNum or v.phaseNum
      if interName and phaseNum then
        objectsDict[interName] = objectsDict[interName] or {}
        objectsDict[interName][phaseNum] = objectsDict[interName][phaseNum] or {}
        table.insert(objectsDict[interName][phaseNum], v:getId())
      end
    end
  end
end

local function getSignalObjects(interName, sigIdx) -- gets all signal objects with valid dynamic fields and values
  if sigIdx then sigIdx = tostring(sigIdx) end
  setupSignalObjects() -- starts from refreshed table
  return objectsDict[interName] and objectsDict[interName][sigIdx] or {}
end

local function buildSignalsDict() -- returns a dict of nodes, with references to signal nodes and actions to send to mapmgr
  signalsDict = {nodes = {}}
  local nodes = signalsDict.nodes
  for _, inter in pairs(intersections) do
    if inter.control and inter.signalNodes[1] then
      for i, sNode in ipairs(inter.signalNodes) do
        if sNode.mapNode then
          if not nodes[sNode.mapNode] then
            nodes[sNode.mapNode] = {}
          end

          local data = {id = sNode.id, pos = sNode.pos, dir = sNode.dir}
          local sig = inter.control.signals[sNode.signalIdx]

          if sig then
            if sig.timings and sig.timings[sig.lightIdx] then
              data.action = signalMetadata.states[sig.timings[sig.lightIdx].type].action
            else
              data.action = signalMetadata.types[sig.prototype].action -- no signal dependent timings
            end
          end

          table.insert(nodes[sNode.mapNode], data)
        end
      end
    end
  end
end

local function getSignalsDict() -- returns the built signals dict
  return signalsDict
end

local function setupSignalMetadata(data) -- loads default and custom signal metadata (signal definitions)
  local json = jsonReadFile(signalsFileDefault)
  signalMetadata = deepcopy(json)

  if data and data.metadata then
    local md = data.metadata -- maybe validate this?
    for k, v in pairs(md.states) do
      signalMetadata.states[k] = v
    end
    for k, v in pairs(md.types) do
      signalMetadata.types[k] = v
    end
  end
end

local function setupSignals(data) -- sets up intersections and controllers, and enables the system
  if not be then return end
  mapNodes = map.getMap().nodes
  loaded = false

  if data then
    setupSignalMetadata(data)
    setupSignalObjects()
    table.clear(intersections)
    table.clear(controllers)

    for _, v in ipairs(data.controllers) do
      controllers[v.name] = SignalController:new(v)
    end

    local tmpVec = vec3()
    for _, v in ipairs(data.intersections) do
      local pos = vec3(v.pos)
      local mapNode = getBestNodes(pos) -- should always be processed just before activation (map node names may not be persistent)
      if mapNode and controllers[v.controllerName] then -- controller and root node need to exist
        intersections[v.name] = Intersection:new(v)
        local inter = intersections[v.name]
        inter.pos = pos
        inter.mapNode = mapNode
        inter.control = controllers[v.controllerName] -- current controller
        inter._visible = true

        for i, sNode in ipairs(v.signalNodes) do
          sNode.pos = vec3(sNode.pos)
          tmpVec:set(inter.pos)
          tmpVec:setSub(sNode.pos)
          sNode.mapNode, sNode.prevMapNode = getBestNodes(sNode.pos, tmpVec)
          if sNode.mapNode then
            tmpVec:set(mapNodes[sNode.mapNode].pos)
            tmpVec:setSub(mapNodes[sNode.prevMapNode].pos)
          end
          sNode.dir = tmpVec:normalized()
          sNode._objIds = getSignalObjects(v.name, i)
        end
      end
    end

    if next(intersections) and next(controllers) then
      resetTimer()
      buildSignalsDict()
      objectsDict = nil
      loaded = true
    end
  end
end

local function loadSignals(filePath) -- loads signals json file from given file path or default file path
  if not filePath then
    local levelDir = path.split(getMissionFilename())
    if levelDir then filePath = levelDir..'signals.json' end
  end

  if filePath then
    setupSignals(jsonReadFile(filePath))
  end
end

local function onExtensionLoaded()
  setupSignalMetadata()
end

local function onUpdate(dt, dtSim)
  if not loaded then return end

  if active then
    while not queue:empty() and queue:peekKey() <= timer do -- while loop handles any concurrent timings, if any
      local _, val = queue:pop()
      local ctrl = controllers[val[1]]

      if ctrl then
        local sig = ctrl.signals[ctrl.signalIdx]
        if sig and sig.timings[sig.lightIdx] then
          if not ctrl.skipTimer and ctrl._queueId == val[2] then
            ctrl:advance()
          end
        end
      end
    end

    timer = timer + dtSim
  end

  for _, inter in pairs(intersections) do
    if inter.control then
      -- TODO: use a quadtree for this instead!
      local validDist = getCameraPosition():squaredDistance(inter.pos) <= viewDistSq -- checks if camera is close enough to intersection
      local changed

      if not inter._visible and validDist then
        changed = true
        inter._visible = true
      elseif inter._visible and not validDist then
        changed = true
        inter._visible = false
      end

      if debug > 0 and inter._visible then -- basic debug signal spheres
        if debug == 2 then
          debugDrawer:drawText(inter.pos, String(inter.name..' ('..inter.controllerName..')'), ColorF(0, 0, 0, 1))
        end

        for _, node in ipairs(inter.signalNodes) do
          local sig = inter.control.signals[node.signalIdx]
          if sig then
            local basePos = node.pos + vecUp * 4
            local md = inter.control:getMetadata(node.signalIdx)

            if md then
              for i, v in ipairs(md.lights) do
                local lightPos = basePos - vecUp * (i * 0.5)
                local color = type(v) == 'table' and ColorF(v[1], v[2], v[3], 0.6) or ColorF(0, 0, 0, 0.6)
                debugDrawer:drawSphere(lightPos, 0.25, color)
              end
            end

            if debug == 2 then
              debugDrawer:drawSquarePrism(node.pos + node.dir * 2, node.pos, Point2F(0.5, 0), Point2F(0.5, 1), ColorF(0.25, 1, 0.25, 0.4))
              debugDrawer:drawText(node.pos, String('phase #'..node.signalIdx), ColorF(0, 0, 0, 1))
            end
          end
        end
      end
    end
  end
end

local function onClientEndMission()
  intersections, controllers, signalMetadata = {}, {}, {}
  loaded, active = false, false
end

local function onSerialize()
  local intersectionsData, controllersData = {}, {}

  for k, v in pairs(intersections) do
    intersectionsData[k] = v:onSerialize()
  end
  for k, v in pairs(controllers) do
    controllersData[k] = v:onSerialize()
  end

  return {intersections = intersectionsData, controllers = controllersData, active = active, debugLevel = debug}
end

local function onDeserialized(data)
  for k, v in pairs(data.intersections) do
    local new = Intersection:new()
    intersections[k] = new:onDeserialized(v)
  end
  for k, v in pairs(data.controllers) do
    local new = SignalController:new()
    controllers[k] = new:onDeserialized(v)

    if active then controllers[k]:activate() end
  end

  active = data.active
  debug = data.debugLevel or 0
end

-- public interface
M.newIntersection = newIntersection
M.newSignalController = newSignalController
M.defaultSignalController = defaultSignalController
M.getIntersections = getIntersections
M.getControllers = getControllers
M.getSignalControllers = getControllers
M.getSignalMetadata = getSignalMetadata
M.getSignalObjects = getSignalObjects
M.getSignalsDict = getSignalsDict
M.loadSignals = loadSignals
M.setupSignals = setupSignals
M.getValues = getValues
M.resetTimer = resetTimer
M.setActive = setActive
M.setDebugLevel = setDebugLevel

M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate
M.onClientEndMission = onClientEndMission
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

return M