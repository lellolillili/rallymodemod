--[[
This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
If a copy of the bCDDL was not distributed with this
file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
This module contains a set of functions which manipulate behaviours of vehicles.
]]

-- this function provides various construction functions for wheels

local M = {}

local jbeamUtils = require("jbeam/utils")

-- these are defined in C, do not change the values
local NORMALTYPE = 0
local NONCOLLIDABLE = 2
local BEAM_ANISOTROPIC = 1
local BEAM_PRESSURED = 3
local BEAM_LBEAM = 4
local BEAM_SUPPORT = 7

local function addWheel(vehicle, wheelKey, wheel)
  --log('D', "jbeam.addWheel","wheel jbeam.")
  --dump(wheel)
  local node1   = vehicle.nodes[wheel.node1]
  local node2   = vehicle.nodes[wheel.node2]
  local nodeArm = vehicle.nodes[wheel.nodeArm]

  if node1 == nil or node2 == nil then
    log('W', "jbeam.addWheel","invalid wheel")
    return
  end

  local nodebase = vehicle.maxIDs.nodes

  if wheel.radius == nil then wheel.radius = 0.5 end
  if wheel.numRays == nil then wheel.numRays = 10 end

  -- add collision to the wheels nodes ;)
  wheel.collision = true

  -- fix it like this
  local node1_pos = vec3(node1.pos)
  local node2_pos = vec3(node2.pos)

  --log('D', "jbeam.addWheel","n1 = " .. tostring(node1_pos) .. " , n2 = " .. tostring(node2_pos))

  local width = node1_pos:distance(node2_pos)
  --log('D', "jbeam.addWheel","wheel width: "..width)

  -- swap nodes?
  if node1_pos.z > node2_pos.z then
    --log('D', "jbeam.addWheel","swapping wheel nodes ...")
    node1, node2 = node2, node1
  end

  -- calculate axis
  local axis = node2_pos - node1_pos
  axis:normalize()

  local midpoint = (node2_pos + node1_pos) * 0.5
  if wheel.wheelOffset ~= nil then
    local offset = wheelOffset
    midpoint = midpoint + axis * offset
  end

  --log('D', "jbeam.addWheel","wheel axis:" .. tostring(axis))


  local rayVec = axis:perpendicularN() * wheel.radius
  --log('D', "jbeam.addWheel","rayVector: " .. tostring(rayVec))

  local rayRot = quatFromAxisAngle(axis, 2 * math.pi / (wheel.numRays* 2))
  --log('D', "jbeam.addWheel","rayRot: " .. tostring(rayRot))

  if wheel.tireWidth ~= nil then
    local halfWidth = 0.5 * wheel.tireWidth
    node1_pos = midpoint - axis * halfWidth
    node2_pos = midpoint + axis * halfWidth
  end

  -- add nodes first
  local wheelNodes = {}
  local n = 0
  for i = 0, wheel.numRays - 1, 1 do
    -- outer
    local rayPoint = node1_pos + rayVec
    rayVec = rayRot * rayVec
    n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, wheel)
    table.insert(wheelNodes, n)

    -- inner
    rayPoint = node2_pos + rayVec
    rayVec = rayRot * rayVec
    n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, wheel)
    table.insert(wheelNodes, n)
  end

  -- then add the beams
  --local wheelBeams = {}
  local b = 0

  local sideOptions = deepcopy(wheel)
  sideOptions.beamSpring   = sideOptions.wheelSideBeamSpring
  sideOptions.beamDamp     = sideOptions.wheelSideBeamDamp
  sideOptions.beamDeform   = sideOptions.wheelSideBeamDeform
  sideOptions.beamStrength = sideOptions.wheelSideBeamStrength

  local reinforcementOptions = deepcopy(wheel)
  reinforcementOptions.beamSpring   = reinforcementOptions.wheelReinforcementBeamSpring
  reinforcementOptions.beamDamp     = reinforcementOptions.wheelReinforcementBeamDamp
  reinforcementOptions.beamDeform   = reinforcementOptions.wheelReinforcementBeamDeform
  reinforcementOptions.beamStrength = reinforcementOptions.wheelReinforcementBeamStrength
  reinforcementOptions.springExpansion = reinforcementOptions.wheelReinforcementBeamSpringExpansion
  reinforcementOptions.dampExpansion   = reinforcementOptions.wheelReinforcementBeamDampExpansion

  local treadOptions = deepcopy(wheel)
  treadOptions.beamSpring      = treadOptions.wheelTreadBeamSpring
  treadOptions.beamDamp        = treadOptions.wheelTreadBeamDamp
  treadOptions.beamDeform      = treadOptions.wheelTreadBeamDeform
  treadOptions.beamStrength    = treadOptions.wheelTreadBeamStrength
  treadOptions.springExpansion = treadOptions.wheelTreadBeamSpringExpansion
  treadOptions.dampExpansion   = treadOptions.wheelTreadBeamDampExpansion

  local peripheryOptions     = deepcopy(treadOptions)
  if peripheryOptions.wheelPeripheryBeamSpring ~=nil then peripheryOptions.beamSpring = peripheryOptions.wheelPeripheryBeamSpring end
  if peripheryOptions.wheelPeripheryBeamDamp ~= nil then peripheryOptions.beamDamp = peripheryOptions.wheelPeripheryBeamDamp end
  if peripheryOptions.wheelPeripheryBeamDeform ~= nil then peripheryOptions.beamDeform = peripheryOptions.wheelPeripheryBeamDeform end
  if peripheryOptions.wheelPeripheryBeamStrength ~= nil then peripheryOptions.beamStrength = peripheryOptions.wheelPeripheryBeamStrength end

  --dump(wheel)
  -- the rest
  for i = 0, wheel.numRays - 1, 1 do
    local intirenode = nodebase + 2*i
    local outtirenode = intirenode + 1
    local nextintirenode = nodebase + 2*((i+1)%wheel.numRays)
    local nextouttirenode = nextintirenode + 1
    -- sides
    b = jbeamUtils.addBeamWithOptions(vehicle, wheel.node1, intirenode,  BEAM_ANISOTROPIC, sideOptions)
    --table.insert(wheelBeams, b.cid)
    b = jbeamUtils.addBeamWithOptions(vehicle, wheel.node2, outtirenode, BEAM_ANISOTROPIC, sideOptions)
    --table.insert(wheelBeams, b.cid)

    -- reinforcement (X) beams
    b = jbeamUtils.addBeamWithOptions(vehicle, wheel.node2, intirenode,   BEAM_ANISOTROPIC,    reinforcementOptions)
    --table.insert(wheelBeams, b.cid)
    b = jbeamUtils.addBeamWithOptions(vehicle, wheel.node1, outtirenode, BEAM_ANISOTROPIC,    reinforcementOptions)
    --table.insert(wheelBeams, b.cid)

    -- tread
    b = jbeamUtils.addBeamWithOptions(vehicle, intirenode, outtirenode,  BEAM_ANISOTROPIC, treadOptions)
    --table.insert(wheelBeams, b.cid)
    -- Periphery beam
    b = jbeamUtils.addBeamWithOptions(vehicle, intirenode, nextintirenode, NORMALTYPE, peripheryOptions)
    --table.insert(wheelBeams, b.cid)
    -- Periphery beam
    b = jbeamUtils.addBeamWithOptions(vehicle, outtirenode, nextouttirenode, NORMALTYPE, peripheryOptions)
    --table.insert(wheelBeams, b.cid)
    b = jbeamUtils.addBeamWithOptions(vehicle, outtirenode, nextintirenode, BEAM_ANISOTROPIC, treadOptions)
    --table.insert(wheelBeams, b.cid)
  end

  -- record the wheel nodes
  wheel.nodes = wheelNodes
  -- record the wheel beams
  -- vehicle.wheels[wheelKey].beams = wheelBeams
end

local function addMonoHubWheel(vehicle, wheelKey, wheel)
  --log('D', "jbeam.addMonoHubWheel","wheel jbeam.")
  --dump(wheel)
  local node1   = vehicle.nodes[wheel.node1]
  local node2   = vehicle.nodes[wheel.node2]
  local nodeArm = vehicle.nodes[wheel.nodeArm]

  if node1 == nil or node2 == nil then
    log('W', "jbeam.addMonoHubWheel","invalid monohub wheel")
    return
  end

  if wheel.radius == nil then    wheel.radius = 0.5 end
  if wheel.hubRadius == nil then wheel.hubRadius = 0.65 * wheel.radius end
  if wheel.numRays == nil then wheel.numRays = 10 end

  local nodebase = vehicle.maxIDs.nodes

  -- add collision to the wheels nodes ;)
  wheel.collision = true

  -- fix it like this
  local node1_pos = vec3(node1.pos)
  local node2_pos = vec3(node2.pos)

  --log('D', "jbeam.addMonoHubWheel","n1 = " .. tostring(node1_pos) .. " , n2 = " .. tostring(node2_pos))

  local width = node1_pos:distance(node2_pos)
  --log('D', "jbeam.addMonoHubWheel","monohub wheel width: "..width)

  -- swap nodes?
  if node1_pos.z > node2_pos.z then
    --log('D', "jbeam.addMonoHubWheel","swapping monohub wheel nodes ...")
    node1, node2 = node2, node1
  end

  -- calculate axis
  local axis = node2_pos - node1_pos
  axis:normalize()

  local midpoint = (node2_pos + node1_pos) * 0.5
  if wheel.wheelOffset ~= nil then
    local offset = wheel.wheelOffset
    midpoint = midpoint + axis * offset
  end

  --log('D', "jbeam.addMonoHubWheel","wheel axis:" .. tostring(axis))

  local rayVec = axis:perpendicularN() * wheel.radius
  --log('D', "jbeam.addMonoHubWheel","rayVector: " .. tostring(rayVec))

  local rayRot = quatFromAxisAngle(axis, 2 * math.pi / (wheel.numRays* 2))

  --log('D', "jbeam.addMonoHubWheel","rayRot: " .. tostring(rayRot))

  if wheel.tireWidth ~= nil then
    local halfWidth = 0.5 * wheel.tireWidth
    node1_pos = midpoint - axis * halfWidth
    node2_pos = midpoint + axis * halfWidth
  end

  -- add nodes first
  for i = 0, wheel.numRays - 1, 1 do
    -- outer
    local rayPoint = node1_pos + rayVec
    rayVec = rayRot * rayVec
    local n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, wheel)

    -- inner
    rayPoint = node2_pos + rayVec
    rayVec = rayRot * rayVec
    n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, wheel)
  end

  -- then add the beams

  local sideOptions = deepcopy(wheel)
  sideOptions.beamSpring   = sideOptions.wheelSideBeamSpring
  sideOptions.beamDamp     = sideOptions.wheelSideBeamDamp
  sideOptions.beamDeform   = sideOptions.wheelSideBeamDeform
  sideOptions.beamStrength = sideOptions.wheelSideBeamStrength

  local treadOptions = deepcopy(wheel)
  treadOptions.beamSpring      = treadOptions.wheelTreadBeamSpring
  treadOptions.beamDamp        = treadOptions.wheelTreadBeamDamp
  treadOptions.beamDeform      = treadOptions.wheelTreadBeamDeform
  treadOptions.beamStrength    = treadOptions.wheelTreadBeamStrength
  treadOptions.springExpansion = treadOptions.wheelTreadBeamSpringExpansion
  treadOptions.dampExpansion   = treadOptions.wheelTreadBeamDampExpansion

  local peripheryOptions     = deepcopy(treadOptions)
  if peripheryOptions.wheelPeripheryBeamSpring ~=nil then peripheryOptions.beamSpring = peripheryOptions.wheelPeripheryBeamSpring end
  if peripheryOptions.wheelPeripheryBeamDamp ~= nil then peripheryOptions.beamDamp = peripheryOptions.wheelPeripheryBeamDamp end
  if peripheryOptions.wheelPeripheryBeamDeform ~= nil then peripheryOptions.beamDeform = peripheryOptions.wheelPeripheryBeamDeform end
  if peripheryOptions.wheelPeripheryBeamStrength ~= nil then peripheryOptions.beamStrength = peripheryOptions.wheelPeripheryBeamStrength end

  local hubOptions = deepcopy(wheel)
  if hubOptions.hubNodeWeight ~= nil then hubOptions.nodeWeight = hubOptions.hubNodeWeight end
  if hubOptions.hubCollision ~= nil then hubOptions.collision = hubOptions.hubCollision end
  if hubOptions.hubNodeMaterial ~= nil then hubOptions.nodeMaterial = hubOptions.hubNodeMaterial end
  if hubOptions.hubFrictionCoef ~= nil then hubOptions.frictionCoef = hubOptions.hubFrictionCoef end

  local supportOptions = deepcopy(hubOptions)
  supportOptions.beamPrecompression = (0.75 * wheel.hubRadius / wheel.radius) + 0.25

  for i = 0, wheel.numRays - 1, 1 do
    local intirenode = nodebase + 2*i
    local outtirenode = intirenode + 1
    local nextintirenode = nodebase + 2*((i+1)%wheel.numRays)
    local nextouttirenode = nextintirenode + 1
    -- Sides
    jbeamUtils.addBeamWithOptions(vehicle, wheel.node1, intirenode,  BEAM_ANISOTROPIC, sideOptions)
    jbeamUtils.addBeamWithOptions(vehicle, wheel.node2, outtirenode, BEAM_ANISOTROPIC, sideOptions)
    -- Tire tread
    jbeamUtils.addBeamWithOptions(vehicle, intirenode,  outtirenode,    BEAM_ANISOTROPIC, treadOptions)
    jbeamUtils.addBeamWithOptions(vehicle, outtirenode, nextintirenode, BEAM_ANISOTROPIC, treadOptions)
    -- Periphery beams
    jbeamUtils.addBeamWithOptions(vehicle, intirenode,  nextintirenode,  NORMALTYPE, peripheryOptions)
    jbeamUtils.addBeamWithOptions(vehicle, outtirenode, nextouttirenode, NORMALTYPE, peripheryOptions)
    -- Support beams
    jbeamUtils.addBeamWithOptions(vehicle, wheel.node1, intirenode,  BEAM_SUPPORT, supportOptions)
    jbeamUtils.addBeamWithOptions(vehicle, wheel.node2, outtirenode, BEAM_SUPPORT, supportOptions)
  end

  -- monoHub
  local rayVec = axis:perpendicularN() * wheel.hubRadius

  -- initial rotation
  local tmpRot = quatFromAxisAngle(axis, 2 * math.pi / (wheel.numRays * 4))

  rayVec = tmpRot * rayVec
  -- all hub node rotation
  rayRot = quatFromAxisAngle(axis, 2 * math.pi / (wheel.numRays))
  --log('D', "jbeam.addMonoHubWheel","rayVector: " .. tostring(rayVec))

  -- add monoHub nodes
  local hubNodes = {}
  local hubnodebase = vehicle.maxIDs.nodes

  for i = 0, wheel.numRays - 1, 1 do
    -- outer
    local rayPoint = midpoint + rayVec
    local n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, hubOptions)
    rayVec = rayRot * rayVec
    table.insert(hubNodes, n)
  end

  if hubOptions.hubBeamSpring ~= nil then hubOptions.beamSpring = hubOptions.hubBeamSpring end
  if hubOptions.hubBeamDamp ~= nil then hubOptions.beamDamp = hubOptions.hubBeamDamp end
  if hubOptions.hubBeamDeform ~= nil then hubOptions.beamDeform = hubOptions.hubBeamDeform end
  if hubOptions.hubBeamStrength ~=nil then hubOptions.beamStrength = hubOptions.hubBeamStrength end

  -- hub-tire beams options
  local reinforcementOptions = deepcopy(wheel)
  reinforcementOptions.beamSpring   = reinforcementOptions.wheelReinforcementBeamSpring
  reinforcementOptions.beamDamp     = reinforcementOptions.wheelReinforcementBeamDamp
  reinforcementOptions.beamDeform   = reinforcementOptions.wheelReinforcementBeamDeform
  reinforcementOptions.beamStrength = reinforcementOptions.wheelReinforcementBeamStrength
  reinforcementOptions.springExpansion = reinforcementOptions.wheelReinforcementBeamSpringExpansion
  reinforcementOptions.dampExpansion   = reinforcementOptions.wheelReinforcementBeamDampExpansion

  for i = 0, wheel.numRays - 1, 1 do
    local hubnode = hubnodebase + i
    local nexthubnode = hubnodebase + ((i+1)%wheel.numRays)
    local intirenode = nodebase + 2*i
    local outtirenode = intirenode + 1
    local nextintirenode = nodebase + 2*((i+1)%wheel.numRays)
    -- hub-axis beams
    jbeamUtils.addBeamWithOptions(vehicle, wheel.node2, hubnode, NORMALTYPE, hubOptions)
    jbeamUtils.addBeamWithOptions(vehicle, wheel.node1, hubnode, NORMALTYPE, hubOptions)
    -- hub periphery beams
    jbeamUtils.addBeamWithOptions(vehicle, hubnode, nexthubnode, NORMALTYPE, hubOptions)

    -- hub-tire beams
    jbeamUtils.addBeamWithOptions(vehicle, hubnode, intirenode,  BEAM_ANISOTROPIC, reinforcementOptions)
    jbeamUtils.addBeamWithOptions(vehicle, hubnode, outtirenode, BEAM_ANISOTROPIC, reinforcementOptions)
    jbeamUtils.addBeamWithOptions(vehicle, hubnode, nextintirenode,  BEAM_ANISOTROPIC, reinforcementOptions)
    jbeamUtils.addBeamWithOptions(vehicle, outtirenode, nexthubnode, BEAM_ANISOTROPIC, reinforcementOptions)

  end

  wheel.nodes = hubNodes
end

local function addHubWheelTSV(vehicle, wheelKey, wheel)
  local node1   = vehicle.nodes[wheel.node1]
  local node2   = vehicle.nodes[wheel.node2]
  local nodeArm = vehicle.nodes[wheel.nodeArm]

  if node1 == nil or node2 == nil then
    log('W', "jbeam.addHubWheelTSV","invalid hubWheel")
    return
  end

  local nodebase = vehicle.maxIDs.nodes
  wheel.treadCoef = wheel.treadCoef or 1
  if wheel.radius == nil then    wheel.radius = 0.5 end
  if wheel.hubRadius == nil then wheel.hubRadius = 0.65 * wheel.radius end
  if wheel.numRays == nil then wheel.numRays = 10 end

  -- add collision to the wheels nodes ;)
  wheel.collision = true

  -- fix it like this
  local node1_pos = vec3(node1.pos)
  local node2_pos = vec3(node2.pos)

  local width = node1_pos:distance(node2_pos)

  -- swap nodes?
  if node1_pos.z > node2_pos.z then
    --log('D', "jbeam.addHubWheelTSV","swapping hubWheel nodes ...")
    node1, node2 = node2, node1
  end

  -- calculate axis
  local axis = node2_pos - node1_pos
  axis:normalize()

  local midpoint = (node2_pos + node1_pos) * 0.5
  if wheel.wheelOffset ~= nil then
    local offset = wheel.wheelOffset
    midpoint = midpoint + axis * offset
  end

  if wheel.tireWidth ~= nil then
    local halfWidth = 0.5 * wheel.tireWidth
    node1_pos = midpoint - axis * halfWidth
    node2_pos = midpoint + axis * halfWidth
  end

  local rayVec = axis:perpendicularN() * wheel.radius
  local rayRot = quatFromAxisAngle(axis, 2 * math.pi / (wheel.numRays* 2))

  -- add nodes first
  local n = 0
  for i = 0, wheel.numRays - 1, 1 do
    -- outer
    local rayPoint = node1_pos + rayVec
    rayVec = rayRot * rayVec
    n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, wheel)

    -- inner
    rayPoint = node2_pos + rayVec
    rayVec = rayRot * rayVec
    n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, wheel)
  end

  -- add Hub nodes
  local hubNodes = {}
  local n = 0
  local hubnodebase = vehicle.maxIDs.nodes

  local hubOptions = deepcopy(wheel)
  if hubOptions.hubBeamSpring ~= nil then hubOptions.beamSpring = hubOptions.hubBeamSpring end
  if hubOptions.hubBeamDamp ~= nil then hubOptions.beamDamp = hubOptions.hubBeamDamp end
  if hubOptions.hubBeamDeform ~= nil then hubOptions.beamDeform = hubOptions.hubBeamDeform end
  if hubOptions.hubBeamStrength ~=nil then hubOptions.beamStrength = hubOptions.hubBeamStrength end
  if hubOptions.hubNodeWeight ~= nil then hubOptions.nodeWeight = hubOptions.hubNodeWeight end
  if hubOptions.hubCollision ~= nil then hubOptions.collision = hubOptions.hubCollision end
  if hubOptions.hubNodeMaterial ~= nil then hubOptions.nodeMaterial = hubOptions.hubNodeMaterial end
  if hubOptions.hubFrictionCoef ~= nil then hubOptions.frictionCoef = hubOptions.hubFrictionCoef end

  rayVec = axis:perpendicularN() * wheel.hubRadius

  if wheel.hubWidth ~= nil then
    local halfWidth = 0.5 * wheel.hubWidth
    node1_pos = midpoint - axis * halfWidth
    node2_pos = midpoint + axis * halfWidth
  end

  local n = 0
  for i = 0, wheel.numRays - 1, 1 do
    -- inner
    rayPoint = node2_pos + rayVec
    rayVec = rayRot * rayVec
    n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, hubOptions)
    table.insert(hubNodes, n)

    -- outer
    local rayPoint = node1_pos + rayVec
    rayVec = rayRot * rayVec
    n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, hubOptions)
    table.insert(hubNodes, n)
  end

  local sideOptions = deepcopy(wheel)
  sideOptions.beamSpring   = sideOptions.wheelSideBeamSpring
  sideOptions.beamDamp     = sideOptions.wheelSideBeamDamp
  sideOptions.beamDeform   = sideOptions.wheelSideBeamDeform
  sideOptions.beamStrength = sideOptions.wheelSideBeamStrength

  -- hub-tire beams options
  local reinforcementOptions = deepcopy(wheel)
  reinforcementOptions.beamSpring   = reinforcementOptions.wheelReinforcementBeamSpring
  reinforcementOptions.beamDamp     = reinforcementOptions.wheelReinforcementBeamDamp
  reinforcementOptions.beamDeform   = reinforcementOptions.wheelReinforcementBeamDeform
  reinforcementOptions.beamStrength = reinforcementOptions.wheelReinforcementBeamStrength
  reinforcementOptions.springExpansion = reinforcementOptions.wheelReinforcementBeamSpringExpansion
  reinforcementOptions.dampExpansion   = reinforcementOptions.wheelReinforcementBeamDampExpansion

  local treadOptions = deepcopy(wheel)
  treadOptions.beamSpring      = treadOptions.wheelTreadBeamSpring
  treadOptions.beamDamp        = treadOptions.wheelTreadBeamDamp
  treadOptions.beamDeform      = treadOptions.wheelTreadBeamDeform
  treadOptions.beamStrength    = treadOptions.wheelTreadBeamStrength
  treadOptions.springExpansion = treadOptions.wheelTreadBeamSpringExpansion
  treadOptions.dampExpansion   = treadOptions.wheelTreadBeamDampExpansion

  local peripheryOptions     = deepcopy(treadOptions)
  if peripheryOptions.wheelPeripheryBeamSpring ~=nil then peripheryOptions.beamSpring = peripheryOptions.wheelPeripheryBeamSpring end
  if peripheryOptions.wheelPeripheryBeamDamp ~= nil then peripheryOptions.beamDamp = peripheryOptions.wheelPeripheryBeamDamp end
  if peripheryOptions.wheelPeripheryBeamDeform ~= nil then peripheryOptions.beamDeform = peripheryOptions.wheelPeripheryBeamDeform end
  if peripheryOptions.wheelPeripheryBeamStrength ~= nil then peripheryOptions.beamStrength = peripheryOptions.wheelPeripheryBeamStrength end

  local supportOptions = deepcopy(hubOptions)
  supportOptions.beamPrecompression = (0.75 * wheel.hubRadius / wheel.radius) + 0.25

  local reinforcementBeams = {}
  local sideBeams = {}
  local treadBeams = {}

  for i = 0, wheel.numRays - 1, 1 do
    local i2 = 2*i
    local nextdelta = 2*((i+1)%wheel.numRays)
    local outhubnode = hubnodebase + i2
    local inhubnode = outhubnode + 1
    local nextouthubnode = hubnodebase + nextdelta
    local nextinhubnode = nextouthubnode + 1
    local intirenode = nodebase + i2
    local outtirenode = intirenode + 1
    local nextintirenode = nodebase + nextdelta
    local nextouttirenode = nextintirenode + 1
    --tire tread
    table.insert( treadBeams,
      jbeamUtils.addBeamWithOptions(vehicle, intirenode,  outtirenode,    BEAM_ANISOTROPIC, treadOptions) )
    table.insert( treadBeams,
      jbeamUtils.addBeamWithOptions(vehicle, outtirenode, nextintirenode, BEAM_ANISOTROPIC, treadOptions) )
    -- Periphery beams
    jbeamUtils.addBeamWithOptions(vehicle, intirenode,  nextintirenode,  NORMALTYPE, peripheryOptions)
    jbeamUtils.addBeamWithOptions(vehicle, outtirenode, nextouttirenode, NORMALTYPE, peripheryOptions)

    --hub tread
    jbeamUtils.addBeamWithOptions(vehicle, outhubnode, inhubnode,      NORMALTYPE, hubOptions)
    jbeamUtils.addBeamWithOptions(vehicle, inhubnode,  nextouthubnode, NORMALTYPE, hubOptions)
    --hub periphery beams
    jbeamUtils.addBeamWithOptions(vehicle, outhubnode, nextouthubnode, NORMALTYPE, hubOptions)
    jbeamUtils.addBeamWithOptions(vehicle, inhubnode,  nextinhubnode,  NORMALTYPE, hubOptions)

    --hub axis beams
    jbeamUtils.addBeamWithOptions(vehicle, outhubnode, wheel.node1, NORMALTYPE, hubOptions)
    jbeamUtils.addBeamWithOptions(vehicle, outhubnode, wheel.node2, NORMALTYPE, hubOptions)
    jbeamUtils.addBeamWithOptions(vehicle, inhubnode,  wheel.node1, NORMALTYPE, hubOptions)
    jbeamUtils.addBeamWithOptions(vehicle, inhubnode,  wheel.node2, NORMALTYPE, hubOptions)

    --hub tire beams
    table.insert( reinforcementBeams,
      jbeamUtils.addBeamWithOptions(vehicle, outhubnode,  intirenode,     BEAM_ANISOTROPIC, reinforcementOptions) )
    table.insert( reinforcementBeams,
      jbeamUtils.addBeamWithOptions(vehicle, inhubnode,   outtirenode,    BEAM_ANISOTROPIC, reinforcementOptions) )
    table.insert( sideBeams,
      jbeamUtils.addBeamWithOptions(vehicle, outhubnode,  outtirenode,    BEAM_ANISOTROPIC, sideOptions) )
    table.insert( sideBeams,
      jbeamUtils.addBeamWithOptions(vehicle, outtirenode, nextouthubnode, BEAM_ANISOTROPIC, sideOptions) )
    table.insert( sideBeams,
      jbeamUtils.addBeamWithOptions(vehicle, inhubnode,   intirenode,     BEAM_ANISOTROPIC, sideOptions) )
    table.insert( sideBeams,
      jbeamUtils.addBeamWithOptions(vehicle, inhubnode,   nextintirenode, BEAM_ANISOTROPIC, sideOptions) )

    -- Support beams
    if wheel.enableTireSideSupportBeams then
      jbeamUtils.addBeamWithOptions(vehicle, wheel.node1, intirenode,  BEAM_SUPPORT, supportOptions)
      jbeamUtils.addBeamWithOptions(vehicle, wheel.node2, outtirenode, BEAM_SUPPORT, supportOptions)
    end
  end

  wheel.nodes = hubNodes
  wheel.reinforcementBeams = reinforcementBeams
  wheel.sideBeams = sideBeams
  wheel.treadBeams = treadBeams
end

local function addHubWheelTSI(vehicle, wheelKey, wheel)
  local node1   = vehicle.nodes[wheel.node1]
  local node2   = vehicle.nodes[wheel.node2]
  local nodeArm = vehicle.nodes[wheel.nodeArm]

  if node1 == nil or node2 == nil then
    log('W', "jbeam.addHubWheelTSI","invalid hubWheel")
    return
  end

  local nodebase = vehicle.maxIDs.nodes
  wheel.treadCoef = wheel.treadCoef or 1
  if wheel.radius == nil then    wheel.radius = 0.5 end
  if wheel.hubRadius == nil then wheel.hubRadius = 0.65 * wheel.radius end
  if wheel.numRays == nil then wheel.numRays = 10 end

  -- add collision to the wheels nodes ;)
  wheel.collision = true

  -- fix it like this
  local node1_pos = vec3(node1.pos)
  local node2_pos = vec3(node2.pos)
  local width = node1_pos:distance(node2_pos)

  -- swap nodes?
  if node1_pos.z > node2_pos.z then
    --log('D', "jbeam.addHubWheelTSI","swapping hubWheel nodes ...")
    node1, node2 = node2, node1
  end

  -- calculate axis
  local axis = node2_pos - node1_pos
  axis:normalize()

  local midpoint = (node2_pos + node1_pos) * 0.5
  if wheel.wheelOffset ~= nil then
    local offset = wheel.wheelOffset
    midpoint = midpoint + axis * offset
  end

  if wheel.tireWidth ~= nil then
    local halfWidth = 0.5 * wheel.tireWidth
    node1_pos = midpoint - axis * halfWidth
    node2_pos = midpoint + axis * halfWidth
  else
    wheel.tireWidth = width
  end

  local rayVec = axis:perpendicularN() * wheel.radius
  local rayRot = quatFromAxisAngle(axis, 2 * math.pi / (wheel.numRays* 2))

  -- add nodes first
  local n = 0
  for i = 0, wheel.numRays - 1, 1 do
    -- outer
    local rayPoint = node1_pos + rayVec
    rayVec = rayRot * rayVec
    n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, wheel)

    -- inner
    rayPoint = node2_pos + rayVec
    rayVec = rayRot * rayVec
    n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, wheel)
  end

  -- add Hub nodes
  local hubNodes = {}
  local n = 0
  local hubnodebase = vehicle.maxIDs.nodes

  local hubOptions = deepcopy(wheel)
  if hubOptions.hubBeamSpring ~= nil then hubOptions.beamSpring = hubOptions.hubBeamSpring end
  if hubOptions.hubBeamDamp ~= nil then hubOptions.beamDamp = hubOptions.hubBeamDamp end
  if hubOptions.hubBeamDeform ~= nil then hubOptions.beamDeform = hubOptions.hubBeamDeform end
  if hubOptions.hubBeamStrength ~=nil then hubOptions.beamStrength = hubOptions.hubBeamStrength end
  if hubOptions.hubNodeWeight ~= nil then hubOptions.nodeWeight = hubOptions.hubNodeWeight end
  if hubOptions.hubCollision ~= nil then hubOptions.collision = hubOptions.hubCollision end
  if hubOptions.hubNodeMaterial ~= nil then hubOptions.nodeMaterial = hubOptions.hubNodeMaterial end
  if hubOptions.hubFrictionCoef ~= nil then hubOptions.frictionCoef = hubOptions.hubFrictionCoef end

  rayVec = axis:perpendicularN() * wheel.hubRadius

  if wheel.hubWidth ~= nil then
    local halfWidth = 0.5 * wheel.hubWidth
    node1_pos = midpoint - axis * halfWidth
    node2_pos = midpoint + axis * halfWidth
  else
    wheel.hubWidth = width
  end

  local n = 0
  for i = 0, wheel.numRays - 1, 1 do
    -- outer
    local rayPoint = node1_pos + rayVec
    rayVec = rayRot * rayVec
    n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, hubOptions)
    table.insert(hubNodes, n)

    -- inner
    rayPoint = node2_pos + rayVec
    rayVec = rayRot * rayVec
    n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, hubOptions)
    table.insert(hubNodes, n)
  end

  local sideOptions = deepcopy(wheel)
  sideOptions.beamSpring   = sideOptions.wheelSideBeamSpring
  sideOptions.beamDamp     = sideOptions.wheelSideBeamDamp
  sideOptions.beamDeform   = sideOptions.wheelSideBeamDeform
  sideOptions.beamStrength = sideOptions.wheelSideBeamStrength

  -- hub-tire beams options
  local reinforcementOptions = deepcopy(wheel)
  reinforcementOptions.beamSpring   = reinforcementOptions.wheelReinforcementBeamSpring
  reinforcementOptions.beamDamp     = reinforcementOptions.wheelReinforcementBeamDamp
  reinforcementOptions.beamDeform   = reinforcementOptions.wheelReinforcementBeamDeform
  reinforcementOptions.beamStrength = reinforcementOptions.wheelReinforcementBeamStrength
  reinforcementOptions.springExpansion = reinforcementOptions.wheelReinforcementBeamSpringExpansion
  reinforcementOptions.dampExpansion   = reinforcementOptions.wheelReinforcementBeamDampExpansion

  local treadOptions = deepcopy(wheel)
  treadOptions.beamSpring      = treadOptions.wheelTreadBeamSpring
  treadOptions.beamDamp        = treadOptions.wheelTreadBeamDamp
  treadOptions.beamDeform      = treadOptions.wheelTreadBeamDeform
  treadOptions.beamStrength    = treadOptions.wheelTreadBeamStrength
  treadOptions.springExpansion = treadOptions.wheelTreadBeamSpringExpansion
  treadOptions.dampExpansion   = treadOptions.wheelTreadBeamDampExpansion

  local peripheryOptions     = deepcopy(treadOptions)
  if peripheryOptions.wheelPeripheryBeamSpring ~=nil then peripheryOptions.beamSpring = peripheryOptions.wheelPeripheryBeamSpring end
  if peripheryOptions.wheelPeripheryBeamDamp ~= nil then peripheryOptions.beamDamp = peripheryOptions.wheelPeripheryBeamDamp end
  if peripheryOptions.wheelPeripheryBeamDeform ~= nil then peripheryOptions.beamDeform = peripheryOptions.wheelPeripheryBeamDeform end
  if peripheryOptions.wheelPeripheryBeamStrength ~= nil then peripheryOptions.beamStrength = peripheryOptions.wheelPeripheryBeamStrength end

  local supportOptions = deepcopy(hubOptions)
  supportOptions.beamPrecompression = (0.75 * wheel.hubRadius / wheel.radius) + 0.25

  local pressuredOptions = deepcopy(reinforcementOptions)
  pressuredOptions.pressurePSI = pressuredOptions.pressurePSI or 30
  pressuredOptions.beamSpring = pressuredOptions.pressureSpring or pressuredOptions.springExpansion
  pressuredOptions.beamDamp = pressuredOptions.pressureDamp or pressuredOptions.dampExpansion
  pressuredOptions.volumeCoef = 1 / (wheel.numRays * 6)
  pressuredOptions.surface = math.pi * (
                wheel.radius * wheel.tireWidth + wheel.hubRadius * wheel.hubWidth
                + wheel.radius * wheel.radius - wheel.hubRadius * wheel.hubRadius) / (wheel.numRays * 6)

  local reinfPressureOptions = deepcopy(pressuredOptions)
  reinfPressureOptions.pressurePSI = reinfPressureOptions.reinforcementPressurePSI or reinfPressureOptions.pressurePSI
  reinfPressureOptions.beamSpring = reinfPressureOptions.reinforcementPressureSpring or reinfPressureOptions.beamSpring
  reinfPressureOptions.beamDamp = reinfPressureOptions.reinforcementPressureDamp or reinfPressureOptions.beamDamp

  local pressuredBeams = {}
  local treadBeams = {}
  local reinforcementBeams = {}

  for i = 0, wheel.numRays - 1, 1 do
    local i2 = 2*i
    local nextdelta = 2*((i+1)%wheel.numRays)
    local inhubnode = hubnodebase + i2
    local outhubnode = inhubnode + 1
    local nextinhubnode = hubnodebase + nextdelta
    local nextouthubnode = nextinhubnode + 1
    local intirenode = nodebase + i2
    local outtirenode = intirenode + 1
    local nextintirenode = nodebase + nextdelta
    local nextouttirenode = nextintirenode + 1

    --tire tread
    table.insert( treadBeams,
      jbeamUtils.addBeamWithOptions(vehicle, intirenode,  outtirenode,    BEAM_ANISOTROPIC, treadOptions) )
    table.insert( treadBeams,
      jbeamUtils.addBeamWithOptions(vehicle, outtirenode, nextintirenode, BEAM_ANISOTROPIC, treadOptions) )

    -- paired treadnodes
    vehicle.nodes[intirenode].pairedNode = outtirenode
    vehicle.nodes[outtirenode].pairedNode = nextintirenode

    -- Periphery beams
    jbeamUtils.addBeamWithOptions(vehicle, intirenode,  nextintirenode,  NORMALTYPE, peripheryOptions)
    jbeamUtils.addBeamWithOptions(vehicle, outtirenode, nextouttirenode, NORMALTYPE, peripheryOptions)

    --hub tread
    jbeamUtils.addBeamWithOptions(vehicle, inhubnode,  outhubnode,    NORMALTYPE, hubOptions)
    jbeamUtils.addBeamWithOptions(vehicle, outhubnode, nextinhubnode, NORMALTYPE, hubOptions)

    --hub periphery beams
    jbeamUtils.addBeamWithOptions(vehicle, outhubnode, nextouthubnode, NORMALTYPE, hubOptions)
    jbeamUtils.addBeamWithOptions(vehicle, inhubnode,  nextinhubnode,  NORMALTYPE, hubOptions)

    --hub axis beams
    jbeamUtils.addBeamWithOptions(vehicle, inhubnode,  wheel.node1, NORMALTYPE, hubOptions)
    jbeamUtils.addBeamWithOptions(vehicle, inhubnode,  wheel.node2, NORMALTYPE, hubOptions)
    jbeamUtils.addBeamWithOptions(vehicle, outhubnode, wheel.node1, NORMALTYPE, hubOptions)
    jbeamUtils.addBeamWithOptions(vehicle, outhubnode, wheel.node2, NORMALTYPE, hubOptions)

    --hub tire beams
    -- table.insert( sideBeams,
    --     self:jbeamUtils.addBeamWithOptions(vehicle, inhubnode,   intirenode,     BEAM_ANISOTROPIC, sideOptions) )
    -- table.insert( sideBeams,
    --     self:jbeamUtils.addBeamWithOptions(vehicle, outhubnode,  outtirenode,    BEAM_ANISOTROPIC, sideOptions) )
    -- table.insert( reinforcementBeams,
    --     self:jbeamUtils.addBeamWithOptions(vehicle, intirenode,  outhubnode,     BEAM_ANISOTROPIC, reinforcementOptions)    )
    -- table.insert( reinforcementBeams,
    --     self:jbeamUtils.addBeamWithOptions(vehicle, inhubnode,   outtirenode,    BEAM_ANISOTROPIC, reinforcementOptions) )
    -- table.insert( reinforcementBeams,
    --     self:jbeamUtils.addBeamWithOptions(vehicle, outtirenode, nextinhubnode,  BEAM_ANISOTROPIC, reinforcementOptions) )
    -- table.insert( reinforcementBeams,
    --     self:jbeamUtils.addBeamWithOptions(vehicle, outhubnode,  nextintirenode, BEAM_ANISOTROPIC, reinforcementOptions)    )

    table.insert( pressuredBeams,
      jbeamUtils.addBeamWithOptions(vehicle, inhubnode,   intirenode,     BEAM_PRESSURED, pressuredOptions) )
    table.insert( pressuredBeams,
      jbeamUtils.addBeamWithOptions(vehicle, outhubnode,  outtirenode,    BEAM_PRESSURED, pressuredOptions) )
    table.insert( pressuredBeams,
      jbeamUtils.addBeamWithOptions(vehicle, intirenode,  outhubnode,     BEAM_PRESSURED, reinfPressureOptions)    )
    table.insert( pressuredBeams,
      jbeamUtils.addBeamWithOptions(vehicle, inhubnode,   outtirenode,    BEAM_PRESSURED, reinfPressureOptions) )
    table.insert( pressuredBeams,
      jbeamUtils.addBeamWithOptions(vehicle, outtirenode, nextinhubnode,  BEAM_PRESSURED, reinfPressureOptions) )
    table.insert( pressuredBeams,
      jbeamUtils.addBeamWithOptions(vehicle, outhubnode,  nextintirenode, BEAM_PRESSURED, reinfPressureOptions) )

    --tire side V beams
    -- if wheel.enableTireSideVBeams ~= nil and wheel.enableTireSideVBeams == true then
    --     self:jbeamUtils.addBeamWithOptions(vehicle, outtirenode,    nextouthubnode,  BEAM_ANISOTROPIC, sideOptions)
    --     self:jbeamUtils.addBeamWithOptions(vehicle, outhubnode,     nextouttirenode, BEAM_ANISOTROPIC, sideOptions)
    --     self:jbeamUtils.addBeamWithOptions(vehicle, nextintirenode, inhubnode,       BEAM_ANISOTROPIC, sideOptions)
    --     self:jbeamUtils.addBeamWithOptions(vehicle, nextinhubnode,  intirenode,      BEAM_ANISOTROPIC, sideOptions)
    -- end

    -- Support beams
    if wheel.enableTireSideSupportBeams then
      jbeamUtils.addBeamWithOptions(vehicle, wheel.node1, intirenode,  BEAM_SUPPORT, supportOptions)
      jbeamUtils.addBeamWithOptions(vehicle, wheel.node2, outtirenode, BEAM_SUPPORT, supportOptions)
    end
  end

  wheel.nodes = hubNodes
  wheel.pressuredBeams = pressuredBeams
  -- wheel.treadBeams = treadBeams
end

local function addHubWheel(vehicle, wheelKey, wheel)
  local node1   = vehicle.nodes[wheel.node1]
  local node2   = vehicle.nodes[wheel.node2]
  local nodeArm = vehicle.nodes[wheel.nodeArm]
  if node1 == nil or node2 == nil then
    log('W', "jbeam.addHubWheel","invalid hubWheel")
    return
  end

  local nodebase = vehicle.maxIDs.nodes
  wheel.treadCoef = wheel.treadCoef or 1

  if wheel.radius == nil then    wheel.radius = 0.5 end
  if wheel.hubRadius == nil then wheel.hubRadius = 0.65 * wheel.radius end
  if wheel.numRays == nil then wheel.numRays = 10    end

  -- add collision to the wheels nodes ;)
  wheel.collision = true

  -- fix it like this
  local node1_pos = vec3(node1.pos)
  local node2_pos = vec3(node2.pos)

  --log('D', "jbeam.addHubWheel","n1 = " .. tostring(node1_pos) .. " , n2 = " .. tostring(node2_pos))

  local tireWidth = node1_pos:distance(node2_pos)
  local hubWidth = tireWidth
  --log('D', "jbeam.addHubWheel","hubWheel width: "..width)

  -- swap nodes?
  if node1_pos.z > node2_pos.z then
    --log('D', "jbeam.addHubWheel","swapping hubWheel nodes ...")
    node1, node2 = node2, node1
  end

  -- calculate axis
  local axis = node2_pos - node1_pos
  local axisLength = axis:length()
  axis:normalize()

  local midpoint = (node2_pos + node1_pos) * 0.5
  if wheel.wheelOffset ~= nil then
    local offset = wheel.wheelOffset
    midpoint = midpoint + axis * offset
  end

  if wheel.tireWidth ~= nil then
    tireWidth = wheel.tireWidth
    local halfWidth = 0.5 * wheel.tireWidth
    node1_pos = midpoint - axis * halfWidth
    node2_pos = midpoint + axis * halfWidth
  end

  --log('D', "jbeam.addHubWheel","wheel axis:" .. tostring(axis))

  local rayVec = axis:perpendicularN() * wheel.radius
  --log('D', "jbeam.addHubWheel","rayVector: " .. tostring(rayVec))

  local rayRot = quatFromAxisAngle(axis, 2 * math.pi / (wheel.numRays* 2))
  --log('D', "jbeam.addHubWheel","rayRot: " .. tostring(rayRot))

  -- add tire nodes first
  local n = 0
  local rayPoint
  for i = 0, wheel.numRays - 1, 1 do
    -- outer
    rayPoint = node1_pos + rayVec
    rayVec = rayRot * rayVec
    n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, wheel)

    -- inner
    rayPoint = node2_pos + rayVec
    rayVec = rayRot * rayVec
    n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, wheel)
  end

  -- add Hub nodes
  local hubNodes = {}
  local n = 0
  local hubnodebase = vehicle.maxIDs.nodes

  local hubOptions = deepcopy(wheel)
  hubOptions.beamSpring = hubOptions.hubBeamSpring or hubOptions.beamSpring
  hubOptions.beamDamp = hubOptions.hubBeamDamp or hubOptions.beamDamp
  hubOptions.beamDeform = hubOptions.hubBeamDeform or hubOptions.beamDeform
  hubOptions.beamStrength = hubOptions.hubBeamStrength or hubOptions.beamStrength
  hubOptions.nodeWeight = hubOptions.hubNodeWeight or hubOptions.nodeWeight
  hubOptions.collision = hubOptions.hubCollision or hubOptions.collision
  hubOptions.nodeMaterial = hubOptions.hubNodeMaterial or hubOptions.nodeMaterial
  hubOptions.frictionCoef = hubOptions.hubFrictionCoef or hubOptions.frictionCoef

  rayVec = axis:perpendicularN() * wheel.hubRadius

  if wheel.hubWidth ~= nil then
    hubWidth = wheel.hubWidth
    local halfWidth = 0.5 * wheel.hubWidth
    node1_pos = midpoint - axis * halfWidth
    node2_pos = midpoint + axis * halfWidth
  end

  local n = 0
  for i = 0, wheel.numRays - 1, 1 do
    -- outer
    rayPoint = node1_pos + rayVec
    rayVec = rayRot * rayVec
    n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, hubOptions)
    table.insert(hubNodes, n)

    -- inner
    rayPoint = node2_pos + rayVec
    rayVec = rayRot * rayVec
    n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, hubOptions)
    table.insert(hubNodes, n)
  end

  -- Hub Cap
  local hubcapOptions = deepcopy(wheel)
  hubcapOptions.beamSpring = hubcapOptions.hubcapBeamSpring or hubcapOptions.beamSpring
  hubcapOptions.beamDamp = hubcapOptions.hubcapBeamDamp or hubcapOptions.beamDamp
  hubcapOptions.beamDeform = hubcapOptions.hubcapBeamDeform or hubcapOptions.beamDeform
  hubcapOptions.beamStrength = hubcapOptions.hubcapBeamStrength or hubcapOptions.beamStrength
  hubcapOptions.nodeWeight = hubcapOptions.hubcapNodeWeight or hubcapOptions.nodeWeight
  hubcapOptions.collision = hubcapOptions.hubcapCollision or hubcapOptions.collision
  hubcapOptions.nodeMaterial = hubcapOptions.hubcapNodeMaterial or hubcapOptions.nodeMaterial
  hubcapOptions.frictionCoef = hubcapOptions.hubcapFrictionCoef or hubcapOptions.frictionCoef
  hubcapOptions.hubcapRadius = hubcapOptions.hubcapRadius or hubcapOptions.hubRadius
  hubcapOptions.group = hubcapOptions.hubcapGroup or hubcapOptions.group
  hubcapOptions.wheelID = nil

  local hubcapnodebase
  if wheel.enableHubcaps ~= nil and wheel.enableHubcaps == true and wheel.numRays%2 ~= 1 then
    local hubcapOffset
    if wheel.hubcapOffset ~= nil then
      hubcapOffset = wheel.hubcapOffset
      hubcapOffset = axis * hubcapOffset
    end

    local n = 0
    hubcapnodebase = vehicle.maxIDs.nodes

    local hubCapNumRays = wheel.numRays/2
    rayVec = axis:perpendicularN() * hubcapOptions.hubcapRadius

    local tmpRot = quatFromAxisAngle(axis, 2 * math.pi / (hubCapNumRays * 4))

    rayVec = tmpRot * rayVec
    -- all hub node rotation
    rayRot = quatFromAxisAngle(axis, 2 * math.pi / (hubCapNumRays))

    for i = 0, hubCapNumRays -1, 1 do
      local rayPoint = node1_pos + rayVec - hubcapOffset
      rayVec = rayRot * rayVec
      n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, hubcapOptions)
    end

    --hubcapOptions.collision = false
    --hubcapOptions.selfCollision = false
    hubcapOptions.nodeWeight = wheel.hubcapCenterNodeWeight
    --make the center rigidifying node
    local hubcapAxis = node1_pos + axis * wheel.hubcapWidth
    n = jbeamUtils.addNodeWithOptions(vehicle, hubcapAxis, NORMALTYPE, hubcapOptions)

    --hubcapOptions.collision = nil
    --hubcapOptions.selfCollision = nil
    hubcapOptions.nodeWeight = nil
  end

  local hubcapAttachOptions = deepcopy(wheel)
  hubcapAttachOptions.beamSpring = hubcapAttachOptions.hubcapAttachBeamSpring or hubcapAttachOptions.beamSpring
  hubcapAttachOptions.beamDamp = hubcapAttachOptions.hubcapAttachBeamDamp or hubcapAttachOptions.beamDamp
  hubcapAttachOptions.beamDeform = hubcapAttachOptions.hubcapAttachBeamDeform or hubcapAttachOptions.beamDeform
  hubcapAttachOptions.beamStrength = hubcapAttachOptions.hubcapAttachBeamStrength or hubcapAttachOptions.beamStrength
  hubcapAttachOptions.breakGroup = hubcapAttachOptions.hubcapBreakGroup or hubcapAttachOptions.breakGroup
  hubcapAttachOptions.wheelID = nil

  -- hub-tire beams options
  local treadOptions = deepcopy(wheel)
  treadOptions.beamSpring      = treadOptions.wheelTreadBeamSpring or treadOptions.beamSpring
  treadOptions.beamDamp        = treadOptions.wheelTreadBeamDamp or treadOptions.beamDamp
  treadOptions.beamDeform      = treadOptions.wheelTreadBeamDeform or treadOptions.beamDeform
  treadOptions.beamStrength    = treadOptions.wheelTreadBeamStrength or treadOptions.beamStrength
  treadOptions.springExpansion = treadOptions.wheelTreadBeamSpringExpansion or treadOptions.springExpansion
  treadOptions.dampExpansion   = treadOptions.wheelTreadBeamDampExpansion or treadOptions.dampExpansion

  local enableTreadReinforcementBeams = false
  if wheel.enableTreadReinforcementBeams ~= nil and wheel.enableTreadReinforcementBeams == true then
    enableTreadReinforcementBeams = true
  end

  local treadReinfOptions           = deepcopy(treadOptions)
  treadReinfOptions.beamSpring      = treadReinfOptions.wheelTreadReinforcementBeamSpring or treadReinfOptions.beamSpring
  treadReinfOptions.beamDamp        = treadReinfOptions.wheelTreadReinforcementBeamDamp or treadReinfOptions.beamDamp
  treadReinfOptions.beamDeform      = treadReinfOptions.wheelTreadReinforcementBeamDeform or treadReinfOptions.beamDeform
  treadReinfOptions.beamStrength    = treadReinfOptions.wheelTreadReinforcementBeamStrength or treadReinfOptions.beamStrength

  local peripheryOptions     = deepcopy(treadOptions)
  peripheryOptions.beamSpring = peripheryOptions.wheelPeripheryBeamSpring or peripheryOptions.beamSpring
  peripheryOptions.beamDamp = peripheryOptions.wheelPeripheryBeamDamp or peripheryOptions.beamDamp
  peripheryOptions.beamDeform = peripheryOptions.wheelPeripheryBeamDeform or peripheryOptions.beamDeform
  peripheryOptions.beamStrength = peripheryOptions.wheelPeripheryBeamStrength or peripheryOptions.beamStrength

  local supportOptions = deepcopy(hubOptions)
  supportOptions.beamPrecompression = (0.75 * wheel.hubRadius / wheel.radius) + 0.25

  -- Pressured Beam options
  local sideBeamLength =     wheel.radius - wheel.hubRadius
  local reinfBeamLength = math.sqrt(sideBeamLength * sideBeamLength + axisLength * axisLength)
  local pressuredOptions = deepcopy(wheel)
  pressuredOptions.pressurePSI = pressuredOptions.pressurePSI or 30
  pressuredOptions.beamSpring = pressuredOptions.pressureSpring or pressuredOptions.springExpansion
  pressuredOptions.beamDamp = pressuredOptions.pressureDamp or pressuredOptions.dampExpansion
  pressuredOptions.beamStrength = pressuredOptions.pressureStrength or pressuredOptions.beamStrength
  pressuredOptions.beamDeform = pressuredOptions.pressureDeform or pressuredOptions.beamDeform
  pressuredOptions.volumeCoef = 1 --2 * sideBeamLength / (wheel.numRays * sideBeamLength) --sideBeamLength / (wheel.numRays * (2 * sideBeamLength + 4 * reinfBeamLength))
  pressuredOptions.surface = math.pi * (wheel.radius * tireWidth + wheel.hubRadius * hubWidth) / (wheel.numRays*2)

  local reinfPressureOptions = deepcopy(pressuredOptions)
  reinfPressureOptions.pressurePSI = reinfPressureOptions.reinforcementPressurePSI or reinfPressureOptions.pressurePSI
  reinfPressureOptions.beamSpring = reinfPressureOptions.reinforcementPressureSpring or reinfPressureOptions.pressureSpring
  reinfPressureOptions.beamDamp = reinfPressureOptions.reinforcementPressureDamp or reinfPressureOptions.pressureDamp
  reinfPressureOptions.beamStrength = reinfPressureOptions.reinforcementPressureStrength or reinfPressureOptions.pressureStrength
  reinfPressureOptions.beamDeform = reinfPressureOptions.reinforcementPressureDeform or reinfPressureOptions.pressureDeform
  reinfPressureOptions.volumeCoef = 1 --reinfBeamLength / (wheel.numRays * (2 * sideBeamLength + 4 * reinfBeamLength))
  reinfPressureOptions.surface = math.pi * (wheel.radius*wheel.radius - wheel.hubRadius*wheel.hubRadius) / (wheel.numRays*4)

  local sideOptions = deepcopy(wheel)
  sideOptions.beamSpring   = sideOptions.wheelSideBeamSpring or 0
  sideOptions.beamDamp     = sideOptions.wheelSideBeamDamp or 0
  sideOptions.beamDeform   = sideOptions.wheelSideBeamDeform or sideOptions.beamDeform
  sideOptions.beamStrength = sideOptions.wheelSideBeamStrength or sideOptions.beamStrength
  sideOptions.springExpansion = sideOptions.wheelSideBeamSpringExpansion or sideOptions.springExpansion
  sideOptions.dampExpansion   = sideOptions.wheelSideBeamDampExpansion or sideOptions.dampExpansion

  local VDisplacement = wheel.wheelSideDisplacement or 1

  local enableVbeams = false
  if wheel.enableTireSideVBeams ~= nil and wheel.enableTireSideVBeams == true then
    enableVbeams = true
  end

  local pressuredBeams = {}
  local treadBeams = {}
  local b = 0
  for i = 0, wheel.numRays - 1, 1 do
    local i2 = 2*i
    local nextdelta = 2*((i+1)%wheel.numRays)
    local inhubnode = hubnodebase + i2
    local outhubnode = inhubnode + 1
    local nextinhubnode = hubnodebase + nextdelta
    local nextouthubnode = nextinhubnode + 1
    local intirenode = nodebase + i2
    local outtirenode = intirenode + 1
    local nextintirenode = nodebase + nextdelta
    local nextouttirenode = nextintirenode + 1

    if wheel.enableHubcaps ~= nil and wheel.enableHubcaps == true and wheel.numRays%2 ~= 1 and i < ((wheel.numRays)/2) then
      local hubcapnode = hubcapnodebase + i
      local nexthubcapnode = hubcapnodebase + ((i+1)%(wheel.numRays/2))
      local nextnexthubcapnode = hubcapnodebase + ((i+2)%(wheel.numRays/2))
      local hubcapaxisnode = hubcapnode + (wheel.numRays/2) - i
      local hubcapinhubnode = inhubnode + i2
      local nexthubcapinhubnode = hubcapinhubnode + 2
      local hubcapouthubnode = hubcapinhubnode + 1

      --hubcap periphery
      b = jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, nexthubcapnode,    NORMALTYPE, hubcapOptions)
      --attach to center node
      b = jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, hubcapaxisnode,    NORMALTYPE, hubcapOptions)
      --attach to axis
      if wheel.enableExtraHubcapBeams == true then
        jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, wheel.node1, NORMALTYPE, hubcapOptions)
        jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, wheel.node2, NORMALTYPE, hubcapOptions)
        if i == 1 then
          jbeamUtils.addBeamWithOptions(vehicle, hubcapaxisnode, wheel.node1, NORMALTYPE, hubcapOptions)
          jbeamUtils.addBeamWithOptions(vehicle, hubcapaxisnode, wheel.node2, NORMALTYPE, hubcapOptions)
        end
      end

      --span beams
      b = jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, nextnexthubcapnode,    NORMALTYPE, hubcapOptions)

      --attach it
      b = jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, hubcapinhubnode,    NORMALTYPE, hubcapAttachOptions)
      b = jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, nexthubcapinhubnode,    NORMALTYPE, hubcapAttachOptions)
      b = jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, hubcapouthubnode,    BEAM_SUPPORT, hubcapAttachOptions)

      --self:jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, wheel.node1,    NORMALTYPE, hubcapAttachOptions)
      --self:jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, wheel.node2,    NORMALTYPE, hubcapAttachOptions)
    end

    --tire tread
    table.insert( treadBeams,
      jbeamUtils.addBeamWithOptions(vehicle, intirenode,  outtirenode,    BEAM_ANISOTROPIC, treadOptions) )
    table.insert( treadBeams,
      jbeamUtils.addBeamWithOptions(vehicle, outtirenode, nextintirenode, BEAM_ANISOTROPIC, treadOptions) )

    -- paired treadnodes
    vehicle.nodes[intirenode].pairedNode = outtirenode
    vehicle.nodes[outtirenode].pairedNode = nextintirenode

    -- Periphery beams
    b = jbeamUtils.addBeamWithOptions(vehicle, intirenode,  nextintirenode,  NORMALTYPE, peripheryOptions)
    b = jbeamUtils.addBeamWithOptions(vehicle, outtirenode, nextouttirenode, NORMALTYPE, peripheryOptions)

    --hub tread
    b = jbeamUtils.addBeamWithOptions(vehicle, inhubnode,  outhubnode,      NORMALTYPE, hubOptions)
    b = jbeamUtils.addBeamWithOptions(vehicle, outhubnode, nextinhubnode, NORMALTYPE, hubOptions)

    --hub periphery beams
    b = jbeamUtils.addBeamWithOptions(vehicle, outhubnode, nextouthubnode, NORMALTYPE, hubOptions)
    b = jbeamUtils.addBeamWithOptions(vehicle, inhubnode,  nextinhubnode,  NORMALTYPE, hubOptions)

    --hub axis beams
    b = jbeamUtils.addBeamWithOptions(vehicle, inhubnode,  wheel.node1, NORMALTYPE, hubOptions)
    b = jbeamUtils.addBeamWithOptions(vehicle, inhubnode,  wheel.node2, NORMALTYPE, hubOptions)
    b = jbeamUtils.addBeamWithOptions(vehicle, outhubnode, wheel.node1, NORMALTYPE, hubOptions)
    b = jbeamUtils.addBeamWithOptions(vehicle, outhubnode, wheel.node2, NORMALTYPE, hubOptions)

    --hub tire beams
    table.insert( pressuredBeams,
      jbeamUtils.addBeamWithOptions(vehicle, inhubnode,   intirenode,     BEAM_PRESSURED, pressuredOptions) )
    table.insert( pressuredBeams,
      jbeamUtils.addBeamWithOptions(vehicle, outhubnode,  outtirenode,    BEAM_PRESSURED, pressuredOptions) )
    table.insert( pressuredBeams,
      jbeamUtils.addBeamWithOptions(vehicle, intirenode,  outhubnode,     BEAM_PRESSURED, reinfPressureOptions)    )
    table.insert( pressuredBeams,
      jbeamUtils.addBeamWithOptions(vehicle, inhubnode,   outtirenode,    BEAM_PRESSURED, reinfPressureOptions) )
    table.insert( pressuredBeams,
      jbeamUtils.addBeamWithOptions(vehicle, outtirenode, nextinhubnode,  BEAM_PRESSURED, reinfPressureOptions) )
    table.insert( pressuredBeams,
      jbeamUtils.addBeamWithOptions(vehicle, outhubnode,  nextintirenode, BEAM_PRESSURED, reinfPressureOptions) )

    --tire side V beams
    if enableVbeams then
      local inhubDnode = hubnodebase + 2*((i+1-VDisplacement)%wheel.numRays)
      local outhubDnode = inhubDnode + 1
      local nextinhubDnode = hubnodebase + 2*((i+VDisplacement)%wheel.numRays)
      local nextouthubDnode = nextinhubDnode + 1
      b = jbeamUtils.addBeamWithOptions(vehicle, outtirenode,  nextouthubDnode,  BEAM_ANISOTROPIC, sideOptions)
      b = jbeamUtils.addBeamWithOptions(vehicle, outhubDnode,   nextouttirenode, BEAM_ANISOTROPIC, sideOptions)
      b = jbeamUtils.addBeamWithOptions(vehicle, nextintirenode, inhubDnode,  BEAM_ANISOTROPIC, sideOptions)
      b = jbeamUtils.addBeamWithOptions(vehicle, nextinhubDnode,  intirenode, BEAM_ANISOTROPIC, sideOptions)
    end

    if enableTreadReinforcementBeams then
      local intirenode2 = nodebase + 2*((i+2)%wheel.numRays)
      local outtirenode2 = intirenode2 + 1
      table.insert( treadBeams,
        jbeamUtils.addBeamWithOptions(vehicle, intirenode,  outtirenode2, NORMALTYPE, treadReinfOptions) )
      table.insert( treadBeams,
        jbeamUtils.addBeamWithOptions(vehicle, outtirenode, intirenode2, NORMALTYPE, treadReinfOptions) )
    end

    -- Support beams
    if wheel.enableTireSideSupportBeams then
      jbeamUtils.addBeamWithOptions(vehicle, wheel.node1, intirenode,  BEAM_SUPPORT, supportOptions)
      jbeamUtils.addBeamWithOptions(vehicle, wheel.node2, outtirenode, BEAM_SUPPORT, supportOptions)
    end
  end

  wheel.nodes = hubNodes
  wheel.pressuredBeams = pressuredBeams
end

local function cleanupWheelOptions(options)
  options.hubBeamSpring = nil
  options.hubBeamDamp = nil
  options.hubBeamDampCutoffHz = nil
  options.hubBeamDeform = nil
  options.hubBeamStrength = nil
  options.hubNodeWeight = nil
  options.hubCollision = nil
  options.hubNodeMaterial = nil
  options.hubFrictionCoef = nil
  options.hubGroup = nil
  options.disableHubMeshBreaking = nil
  options.hubSideBeamSpring = nil
  options.hubSideBeamDamp = nil
  options.hubSideBeamDeform = nil
  options.hubSideBeamStrength = nil
  options.hubSideBeamDampCutoffHz = nil
  options.hubReinfBeamSpring = nil
  options.hubReinfBeamDamp = nil
  options.hubReinfBeamDeform = nil
  options.hubReinfBeamStrength = nil
  options.hubReinfBeamDampCutoffHz = nil
  options.hubTreadBeamSpring = nil
  options.hubTreadBeamDamp = nil
  options.hubTreadBeamDeform = nil
  options.hubTreadBeamStrength = nil
  options.hubTreadBeamDampCutoffHz = nil
  options.hubPeripheryBeamSpring = nil
  options.hubPeripheryBeamDamp = nil
  options.hubPeripheryBeamDeform = nil
  options.hubPeripheryBeamStrength = nil
  options.hubPeripheryBeamDampCutoffHz = nil
  options.hubStabilizerBeamSpring = nil
  options.hubStabilizerBeamDamp = nil
  options.hubStabilizerBeamDeform = nil
  options.hubStabilizerBeamStrength = nil
  options.hubcapBeamSpring = nil
  options.hubcapBeamDamp = nil
  options.hubcapBeamDeform = nil
  options.hubcapBeamStrength = nil
  options.hubcapNodeWeight = nil
  options.hubcapCollision = nil
  options.hubcapNodeMaterial = nil
  options.hubcapFrictionCoef = nil
  options.hubcapGroup = nil
  options.disableHubcapMeshBreaking = nil
  options.hubcapAttachBeamSpring = nil
  options.hubcapAttachBeamDamp = nil
  options.hubcapAttachBeamDeform = nil
  options.hubcapAttachBeamStrength = nil
  options.hubcapBreakGroup = nil
  options.wheelSideBeamSpring = nil
  options.wheelSideBeamDamp = nil
  options.wheelSideBeamDeform = nil
  options.wheelSideBeamStrength = nil
  options.wheelSideBeamSpringExpansion = nil
  options.wheelSideBeamDampExpansion = nil
  options.wheelSideTransitionZone = nil
  options.wheelSideBeamPrecompression = nil
  options.wheelSideReinfBeamSpring = nil
  options.wheelSideReinfBeamDamp = nil
  options.wheelSideReinfBeamDeform = nil
  options.wheelSideReinfBeamStrength = nil
  options.wheelSideReinfBeamSpringExpansion = nil
  options.wheelSideReinfBeamDampExpansion = nil
  options.wheelSideReinfTransitionZone = nil
  options.wheelSideReinfBeamPrecompression = nil
  options.wheelReinfBeamSpring = nil
  options.wheelReinfBeamDamp = nil
  options.wheelReinfBeamSpringExpansion = nil
  options.wheelReinfBeamDampExpansion = nil
  options.wheelReinfBeamDeform = nil
  options.wheelReinfBeamStrength = nil
  options.wheelReinfBeamPrecompression = nil
  options.wheelReinfBeamDampCutoffHz = nil
  options.wheelTreadBeamSpring = nil
  options.wheelTreadBeamDamp = nil
  options.wheelTreadBeamDeform = nil
  options.wheelTreadBeamStrength = nil
  options.wheelTreadBeamPrecompression = nil
  options.wheelTreadBeamDampCutoffHz = nil
  options.wheelTreadReinfBeamSpring = nil
  options.wheelTreadReinfBeamDamp = nil
  options.wheelTreadReinfBeamDeform = nil
  options.wheelTreadReinfBeamStrength = nil
  options.wheelTreadReinfBeamPrecompression = nil
  options.wheelTreadReinfBeamDampCutoffHz = nil
  options.wheelPeripheryBeamSpring = nil
  options.wheelPeripheryBeamDamp = nil
  options.wheelPeripheryBeamDeform = nil
  options.wheelPeripheryBeamStrength = nil
  options.wheelPeripheryBeamPrecompression = nil
  options.wheelPeripheryBeamDampCutoffHz = nil
  options.wheelPeripheryReinfBeamSpring = nil
  options.wheelPeripheryReinfBeamDamp = nil
  options.wheelPeripheryReinfBeamDeform = nil
  options.wheelPeripheryReinfBeamStrength = nil
  options.wheelPeripheryReinfBeamPrecompression = nil
  options.wheelPeripheryReinfBeamDampCutoffHz = nil
  options.hubRadius = nil
  options.hubWidth = nil
  options.tireWidth = nil
  options.name = nil
  options.wheelOffset = nil
  options.radius = nil
  options.rotorMaterial = nil
  options.numRays = nil
  options.torqueArm = nil
  options.torqueArm2 = nil
  options.wheelDir = nil
  options.padMaterial = nil
  options.pressurePSI = nil
  options.parkingTorque = nil
  options.steerAxisDown = nil

  return options
end

local function cleanupBeamOptions(options)
  options.selfCollision = nil
  options.frictionCoef = nil
  options.loadSensitivitySlope = nil
  options.treadCoef = nil
  options.fullLoadCoef = nil
  options.collision = nil
  options.slidingFrictionCoef = nil

  return options
end

local function addPressTri(tris, presGroup, presPSI, n1, n2, n3, dCoef, tType, sDragCoef)
  table.insert(tris, {
      id1 = n1, id2 = n2, id3 = n3,
      dragCoef = dCoef, triangleType = tType,
      pressureGroup = presGroup, pressurePSI = presPSI, skinDragCoef = sDragCoef
    })
end

local function addTri(tris, n1, n2, n3, dCoef, tType)
  table.insert(tris, {
      id1 = n1, id2 = n2, id3 = n3,
      dragCoef = dCoef, triangleType = tType
    })
end

local function addPressureWheel(vehicle, wheelKey, wheel)
  local node1   = vehicle.nodes[wheel.node1]
  local node2   = vehicle.nodes[wheel.node2]

  -- Stabilizer
  wheel.nodeStabilizer = wheel.nodeStabilizer or wheel.nodeS
  wheel.treadCoef = wheel.treadCoef or 1
  wheel.nodeS = nil
  local nodeStabilizerExists = false
  local wheelAngleRad = math.rad(wheel.wheelAngle or 0)

  if wheel.nodeStabilizer and wheel.nodeStabilizer ~= 9999 and vehicle.nodes[wheel.nodeStabilizer] then
    nodeStabilizerExists = true
  else
    wheel.nodeStabilizer = nil
  end

  if node1 == nil or node2 == nil then
    log('W', "jbeam.addPressureWheel","invalid pressureWheel")
    return
  end

  local nodebase = vehicle.maxIDs.nodes

  local tireExists = true
  if wheel.radius == nil then
    tireExists = false
    wheel.radius = 0.5
  end

  if wheel.pressurePSI == nil then
    tireExists = false
  end

  if wheel.hasTire ~= nil and wheel.hasTire == false then
    tireExists = false
  end

  if wheel.hubRadius == nil then wheel.hubRadius = 0.65 * wheel.radius end
  if wheel.numRays == nil then wheel.numRays = 10 end

  -- add collision to the wheels nodes ;)
  wheel.collision = true

  -- calculate surface
  -- if tireExists and wheel.tireWidth and wheel.hubWidth and wheel.radius and wheel.hubRadius then
  --   wheel._surface = math.pi * (2 * (wheel.tireWidth * wheel.radius + wheel.hubWidth * wheel.hubRadius) +
  --     (wheel.radius + wheel.hubRadius) * math.sqrt(square(wheel.radius - wheel.hubRadius) + square(wheel.tireWidth - wheel.hubRadius)))
  -- end

  local node1_pos = vec3(node1.pos)
  local node2_pos = vec3(node2.pos)

  -- calculate axis
  local axis = node2_pos - node1_pos
  axis:normalize()

  local midpoint = (node2_pos + node1_pos) * 0.5
  if wheel.wheelOffset ~= nil then
    local offset = wheel.wheelOffset
    midpoint = midpoint + axis * offset
  end

  if wheel.tireWidth ~= nil then
    local halfWidth = 0.5 * wheel.tireWidth
    node1_pos = midpoint - axis * halfWidth
    node2_pos = midpoint + axis * halfWidth
  end

  local cleanwheel = deepcopy(wheel)
  cleanwheel.axleBeams = nil
  cleanwheel.childParts = nil
  cleanwheel.slotType = nil
  cleanwheel.enableABS = nil
  cleanwheel.enableBrakeThermals = nil
  cleanwheel.enableHubcaps = nil
  cleanwheel.enableTireLbeams = nil
  cleanwheel.enableTirePeripheryReinfBeams = nil
  cleanwheel.enableTireReinfBeams = nil
  cleanwheel.enableTireSideReinfBeams = nil
  cleanwheel.enableTreadReinfBeams = nil
  cleanwheel.hasTire = nil
  cleanwheel.brakeDiameter = nil
  cleanwheel.brakeInputSplit = nil
  cleanwheel.brakeMass = nil
  cleanwheel.brakeSplitCoef = nil
  cleanwheel.brakeSpring = nil
  cleanwheel.brakeTorque = nil
  cleanwheel.brakeType = nil
  cleanwheel.brakeVentingCoef = nil
  cleanwheel.heatCoefNodeToEnv = nil
  cleanwheel.heatCoefEnvMultStationary = nil
  cleanwheel.heatCoefEnvTerminalSpeed = nil
  cleanwheel.heatCoefNodeToCore = nil
  cleanwheel.heatCoefCoreToNodes = nil
  cleanwheel.heatCoefNodeToSurface = nil
  cleanwheel.heatCoefFriction = nil
  cleanwheel.heatCoefFlashFriction = nil
  cleanwheel.heatCoefStrain = nil
  cleanwheel.heatAffectsPressure = nil
  cleanwheel.smokingTemp = nil
  cleanwheel.meltingTemp = nil
  cleanwheel.frictionLowTemp = nil
  cleanwheel.frictionHighTemp = nil
  cleanwheel.frictionLowSlope = nil
  cleanwheel.frictionHighSlope = nil
  cleanwheel.frictionSlopeSmoothCoef = nil
  cleanwheel.frictionCoefLow = nil
  cleanwheel.frictionCoefMiddle = nil
  cleanwheel.frictionCoefHigh = nil

  local wheelNodes = cleanupWheelOptions(deepcopy(cleanwheel))

  local rayRot = quatFromAxisAngle(axis, 2 * math.pi / (wheel.numRays* 2))
  local rayVec
  local treadNodes = {}
  if tireExists then
    rayVec = axis:perpendicularN() * wheel.radius
    rayVec = quatFromAxisAngle(axis, -wheelAngleRad) * rayVec
    local hasEvenRayCount = wheel.numRays % 2 == 0
    -- add nodes first
    for i = 0, wheel.numRays - 1, 1 do
      -- outer
      local rayPoint = node1_pos + rayVec
      rayVec = rayRot * rayVec
      local n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, wheelNodes)
      table.insert(treadNodes, vehicle.nodes[n])
      if hasEvenRayCount then
        --safe opposite tread node for dynamic tire radius measurement
        vehicle.nodes[n].oppositeTreadNodeCid = (i <= (wheel.numRays - 1) / 2) and (n + wheel.numRays) or (n - wheel.numRays)
      end

      -- inner
      rayPoint = node2_pos + rayVec
      rayVec = rayRot * rayVec
      n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, wheelNodes)
      table.insert(treadNodes, vehicle.nodes[n])
      if hasEvenRayCount then
        --safe opposite tread node for dynamic tire radius measurement
        vehicle.nodes[n].oppositeTreadNodeCid = (i <= (wheel.numRays - 1) / 2) and (n + wheel.numRays) or (n - wheel.numRays)
      end
    end
  end

  -- add Hub nodes
  local hubNodes = {}
  local n = 0
  local hubnodebase = vehicle.maxIDs.nodes

  local hubOptions = deepcopy(cleanwheel)
  hubOptions.beamSpring = hubOptions.hubBeamSpring or hubOptions.beamSpring
  hubOptions.beamDamp = hubOptions.hubBeamDamp or hubOptions.beamDamp
  hubOptions.beamDeform = hubOptions.hubBeamDeform or hubOptions.beamDeform
  hubOptions.beamStrength = hubOptions.hubBeamStrength or hubOptions.beamStrength
  hubOptions.dampCutoffHz = hubOptions.hubBeamDampCutoffHz or nil
  hubOptions.nodeWeight = hubOptions.hubNodeWeight or hubOptions.nodeWeight
  hubOptions.collision = hubOptions.hubCollision or hubOptions.collision
  hubOptions.nodeMaterial = hubOptions.hubNodeMaterial or hubOptions.nodeMaterial
  hubOptions.frictionCoef = hubOptions.hubFrictionCoef or hubOptions.frictionCoef
  hubOptions.group = hubOptions.hubGroup or hubOptions.group
  hubOptions.disableMeshBreaking = hubOptions.disableHubMeshBreaking or hubOptions.disableMeshBreaking

  local hubSideOptions = deepcopy(hubOptions)
  hubSideOptions.beamSpring = hubSideOptions.hubSideBeamSpring or hubSideOptions.beamSpring
  hubSideOptions.beamDamp = hubSideOptions.hubSideBeamDamp or hubSideOptions.beamDamp
  hubSideOptions.beamDeform = hubSideOptions.hubSideBeamDeform or hubSideOptions.beamDeform
  hubSideOptions.beamStrength = hubSideOptions.hubSideBeamStrength or hubSideOptions.beamStrength
  hubSideOptions.dampCutoffHz = hubSideOptions.hubSideBeamDampCutoffHz or hubOptions.dampCutoffHz

  local hubReinfOptions = deepcopy(hubSideOptions)
  hubReinfOptions.beamSpring = hubReinfOptions.hubReinfBeamSpring or hubReinfOptions.beamSpring
  hubReinfOptions.beamDamp = hubReinfOptions.hubReinfBeamDamp or hubReinfOptions.beamDamp
  hubReinfOptions.beamDeform = hubReinfOptions.hubReinfBeamDeform or hubReinfOptions.beamDeform
  hubReinfOptions.beamStrength = hubReinfOptions.hubReinfBeamStrength or hubReinfOptions.beamStrength
  hubReinfOptions.dampCutoffHz = hubReinfOptions.hubReinfBeamDampCutoffHz or hubOptions.dampCutoffHz

  local hubTreadOptions = deepcopy(hubOptions)
  hubTreadOptions.beamSpring = hubTreadOptions.hubTreadBeamSpring or hubTreadOptions.beamSpring
  hubTreadOptions.beamDamp = hubTreadOptions.hubTreadBeamDamp or hubTreadOptions.beamDamp
  hubTreadOptions.beamDeform = hubTreadOptions.hubTreadBeamDeform or hubTreadOptions.beamDeform
  hubTreadOptions.beamStrength = hubTreadOptions.hubTreadBeamStrength or hubTreadOptions.beamStrength
  hubTreadOptions.dampCutoffHz = hubTreadOptions.hubTreadBeamDampCutoffHz or hubOptions.dampCutoffHz

  local hubPeripheryOptions = deepcopy(hubOptions)
  hubPeripheryOptions.beamSpring = hubPeripheryOptions.hubPeripheryBeamSpring or hubPeripheryOptions.beamSpring
  hubPeripheryOptions.beamDamp = hubPeripheryOptions.hubPeripheryBeamDamp or hubPeripheryOptions.beamDamp
  hubPeripheryOptions.beamDeform = hubPeripheryOptions.hubPeripheryBeamDeform or hubPeripheryOptions.beamDeform
  hubPeripheryOptions.beamStrength = hubPeripheryOptions.hubPeripheryBeamStrength or hubPeripheryOptions.beamStrength
  hubPeripheryOptions.dampCutoffHz = hubPeripheryOptions.hubPeripheryBeamDampCutoffHz or hubOptions.dampCutoffHz

  local hubStabilizerOptions = deepcopy(hubSideOptions)
  hubStabilizerOptions.beamSpring = hubStabilizerOptions.hubStabilizerBeamSpring or hubStabilizerOptions.beamSpring
  hubStabilizerOptions.beamDamp = hubStabilizerOptions.hubStabilizerBeamDamp or hubStabilizerOptions.beamDamp
  hubStabilizerOptions.beamDeform = hubStabilizerOptions.hubStabilizerBeamDeform or hubStabilizerOptions.beamDeform
  hubStabilizerOptions.beamStrength = hubStabilizerOptions.hubStabilizerBeamStrength or hubStabilizerOptions.beamStrength
  hubStabilizerOptions.dampCutoffHz = hubStabilizerOptions.hubStabilizerBeamDampCutoffHz or hubOptions.dampCutoffHz

  cleanupWheelOptions(hubOptions) -- used for nodes
  cleanupBeamOptions(cleanupWheelOptions(hubSideOptions))
  cleanupBeamOptions(cleanupWheelOptions(hubReinfOptions))
  cleanupBeamOptions(cleanupWheelOptions(hubTreadOptions))
  cleanupBeamOptions(cleanupWheelOptions(hubPeripheryOptions))
  cleanupBeamOptions(cleanupWheelOptions(hubStabilizerOptions))

  if wheel.hubWidth ~= nil then
    local halfWidth = 0.5 * wheel.hubWidth
    node1_pos = midpoint - axis * halfWidth
    node2_pos = midpoint + axis * halfWidth
  end

  rayVec = axis:perpendicularN() * wheel.hubRadius
  rayVec = quatFromAxisAngle(axis, -wheelAngleRad) * rayVec

  for i = 0, wheel.numRays - 1, 1 do
    -- inner
    local rayPoint = node2_pos + rayVec
    rayVec = rayRot * rayVec
    local n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, hubOptions)
    table.insert(hubNodes, n)

    -- outer
    rayPoint = node1_pos + rayVec
    rayVec = rayRot * rayVec
    n = jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, hubOptions)
    table.insert(hubNodes, n)
  end

-- Hub Cap
  local hubcapOptions = deepcopy(cleanwheel)
  hubcapOptions.beamSpring = hubcapOptions.hubcapBeamSpring or hubcapOptions.beamSpring
  hubcapOptions.beamDamp = hubcapOptions.hubcapBeamDamp or hubcapOptions.beamDamp
  hubcapOptions.beamDeform = hubcapOptions.hubcapBeamDeform or hubcapOptions.beamDeform
  hubcapOptions.beamStrength = hubcapOptions.hubcapBeamStrength or hubcapOptions.beamStrength
  hubcapOptions.nodeWeight = hubcapOptions.hubcapNodeWeight or hubcapOptions.nodeWeight
  hubcapOptions.collision = hubcapOptions.hubcapCollision or hubcapOptions.collision
  hubcapOptions.nodeMaterial = hubcapOptions.hubcapNodeMaterial or hubcapOptions.nodeMaterial
  hubcapOptions.frictionCoef = hubcapOptions.hubcapFrictionCoef or hubcapOptions.frictionCoef
  hubcapOptions.hubcapRadius = hubcapOptions.hubcapRadius or hubcapOptions.hubRadius
  hubcapOptions.group = hubcapOptions.hubcapGroup or hubcapOptions.group
  hubcapOptions.disableMeshBreaking = hubcapOptions.disableHubcapMeshBreaking or hubOptions.disableMeshBreaking
  hubcapOptions.wheelID = nil

  cleanupWheelOptions(hubcapOptions) -- used for nodes

  local hubcapnodebase
  if wheel.enableHubcaps ~= nil and wheel.enableHubcaps == true and wheel.numRays%2 ~= 1 then
    local hubcapOffset
    if wheel.hubcapOffset ~= nil then
      hubcapOffset = wheel.hubcapOffset
      hubcapOffset = axis * hubcapOffset
    end

    hubcapnodebase = vehicle.maxIDs.nodes

    local hubCapNumRays = wheel.numRays/2
    rayVec = axis:perpendicularN() * hubcapOptions.hubcapRadius
    --rayVec = quatFromAxisAngle(axis, - wheelAngleRad + 2 * math.pi / (hubCapNumRays * 4)) * rayVec
    rayRot = quatFromAxisAngle(axis, 2 * math.pi / hubCapNumRays)

    for i = 0, hubCapNumRays -1, 1 do
      local rayPoint = node1_pos + rayVec - hubcapOffset
      rayVec = rayRot * rayVec
      jbeamUtils.addNodeWithOptions(vehicle, rayPoint, NORMALTYPE, hubcapOptions)
    end

    --hubcapOptions.collision = false
    --hubcapOptions.selfCollision = false
    hubcapOptions.nodeWeight = wheel.hubcapCenterNodeWeight
    --make the center rigidifying node
    local hubcapAxis = node1_pos + axis * wheel.hubcapWidth
    jbeamUtils.addNodeWithOptions(vehicle, hubcapAxis, NORMALTYPE, hubcapOptions)

    --hubcapOptions.collision = nil
    --hubcapOptions.selfCollision = nil
    hubcapOptions.nodeWeight = nil
  end

  local hubcapAttachOptions = deepcopy(cleanwheel)
  hubcapAttachOptions.beamSpring = hubcapAttachOptions.hubcapAttachBeamSpring or hubcapAttachOptions.beamSpring
  hubcapAttachOptions.beamDamp = hubcapAttachOptions.hubcapAttachBeamDamp or hubcapAttachOptions.beamDamp
  hubcapAttachOptions.beamDeform = hubcapAttachOptions.hubcapAttachBeamDeform or hubcapAttachOptions.beamDeform
  hubcapAttachOptions.beamStrength = hubcapAttachOptions.hubcapAttachBeamStrength or hubcapAttachOptions.beamStrength
  hubcapAttachOptions.breakGroup = hubcapAttachOptions.hubcapBreakGroup or hubcapAttachOptions.breakGroup
  hubcapAttachOptions.wheelID = nil
  hubcapAttachOptions.disableMeshBreaking = true

  local hubcapSupportOptions = deepcopy(hubcapAttachOptions)
  hubcapSupportOptions.beamSpring = hubcapSupportOptions.hubcapSupportBeamSpring or hubcapSupportOptions.beamSpring
  hubcapSupportOptions.beamDamp = hubcapSupportOptions.hubcapSupportBeamDamp or hubcapSupportOptions.beamDamp
  hubcapSupportOptions.beamDeform = hubcapSupportOptions.hubcapSupportBeamDeform or hubcapSupportOptions.beamDeform
  hubcapSupportOptions.beamStrength = hubcapSupportOptions.hubcapSupportBeamStrength or hubcapSupportOptions.beamStrength
  hubcapSupportOptions.breakGroup = nil
  hubcapSupportOptions.wheelID = nil
  hubcapSupportOptions.disableMeshBreaking = true

  local sideOptions = deepcopy(cleanwheel)
  sideOptions.beamSpring = sideOptions.wheelSideBeamSpring or 0
  sideOptions.beamDamp = sideOptions.wheelSideBeamDamp or 0
  sideOptions.beamDeform = sideOptions.wheelSideBeamDeform or sideOptions.beamDeform
  sideOptions.beamStrength = sideOptions.wheelSideBeamStrength or sideOptions.beamStrength
  sideOptions.springExpansion = sideOptions.wheelSideBeamSpringExpansion or sideOptions.springExpansion
  sideOptions.dampExpansion = sideOptions.wheelSideBeamDampExpansion or sideOptions.dampExpansion
  sideOptions.transitionZone = sideOptions.wheelSideTransitionZone or sideOptions.transitionZone
  sideOptions.beamPrecompression = sideOptions.wheelSideBeamPrecompression or 1

  local sideReinfOptions = deepcopy(sideOptions)
  sideReinfOptions.beamSpring = sideOptions.wheelSideReinfBeamSpring or 0
  sideReinfOptions.beamDamp = sideOptions.wheelSideReinfBeamDamp or 0
  sideReinfOptions.beamDeform = sideOptions.wheelSideReinfBeamDeform or sideOptions.beamDeform
  sideReinfOptions.beamStrength = sideOptions.wheelSideReinfBeamStrength or sideOptions.beamStrength
  sideReinfOptions.springExpansion = sideOptions.wheelSideReinfBeamSpringExpansion or sideOptions.springExpansion
  sideReinfOptions.dampExpansion = sideOptions.wheelSideReinfBeamDampExpansion or sideOptions.dampExpansion
  sideReinfOptions.transitionZone = sideOptions.wheelSideReinfTransitionZone or sideOptions.transitionZone
  sideReinfOptions.beamPrecompression = sideOptions.wheelSideReinfBeamPrecompression or 1
  sideReinfOptions.disableMeshBreaking = true

  local reinfOptions = deepcopy(cleanwheel)
  reinfOptions.beamSpring = reinfOptions.wheelReinfBeamSpring or 0
  reinfOptions.beamDamp = reinfOptions.wheelReinfBeamDamp or 0
  reinfOptions.springExpansion = reinfOptions.wheelReinfBeamSpringExpansion
  reinfOptions.dampExpansion = reinfOptions.wheelReinfBeamDampExpansion
  reinfOptions.beamDeform = reinfOptions.wheelReinfBeamDeform or reinfOptions.beamDeform
  reinfOptions.beamStrength = reinfOptions.wheelReinfBeamStrength or reinfOptions.beamStrength
  reinfOptions.beamPrecompression = reinfOptions.wheelReinfBeamPrecompression or 1
  reinfOptions.dampCutoffHz = reinfOptions.wheelReinfBeamDampCutoffHz or nil
  reinfOptions.disableMeshBreaking = true

  local treadOptions = deepcopy(cleanwheel)
  treadOptions.beamSpring = treadOptions.wheelTreadBeamSpring or treadOptions.beamSpring
  treadOptions.beamDamp = treadOptions.wheelTreadBeamDamp or treadOptions.beamDamp
  treadOptions.beamDeform = treadOptions.wheelTreadBeamDeform or treadOptions.beamDeform
  treadOptions.beamStrength = treadOptions.wheelTreadBeamStrength or treadOptions.beamStrength
  treadOptions.beamPrecompression = treadOptions.wheelTreadBeamPrecompression or 1
  treadOptions.dampCutoffHz = treadOptions.wheelTreadBeamDampCutoffHz or nil
  treadOptions.disableMeshBreaking = true

  local treadReinfOptions = deepcopy(treadOptions)
  treadReinfOptions.beamSpring = treadOptions.wheelTreadReinfBeamSpring or treadOptions.beamSpring
  treadReinfOptions.beamDamp = treadOptions.wheelTreadReinfBeamDamp or treadOptions.beamDamp
  treadReinfOptions.beamDeform = treadOptions.wheelTreadReinfBeamDeform or treadOptions.beamDeform
  treadReinfOptions.beamStrength = treadOptions.wheelTreadReinfBeamStrength or treadOptions.beamStrength
  treadReinfOptions.beamPrecompression = treadOptions.wheelTreadReinfBeamPrecompression or 1
  treadReinfOptions.dampCutoffHz = treadOptions.wheelTreadReinfBeamDampCutoffHz or nil
  treadReinfOptions.disableMeshBreaking = true

  local peripheryOptions = deepcopy(treadOptions)
  peripheryOptions.beamSpring = peripheryOptions.wheelPeripheryBeamSpring or peripheryOptions.beamSpring
  peripheryOptions.beamDamp = peripheryOptions.wheelPeripheryBeamDamp or peripheryOptions.beamDamp
  peripheryOptions.beamDeform = peripheryOptions.wheelPeripheryBeamDeform or peripheryOptions.beamDeform
  peripheryOptions.beamStrength = peripheryOptions.wheelPeripheryBeamStrength or peripheryOptions.beamStrength
  peripheryOptions.beamPrecompression = peripheryOptions.wheelPeripheryBeamPrecompression or 1
  peripheryOptions.dampCutoffHz = peripheryOptions.wheelPeripheryBeamDampCutoffHz or nil

  local peripheryReinfOptions = deepcopy(peripheryOptions)
  peripheryReinfOptions.beamSpring = peripheryReinfOptions.wheelPeripheryReinfBeamSpring or peripheryOptions.beamSpring
  peripheryReinfOptions.beamDamp = peripheryReinfOptions.wheelPeripheryReinfBeamDamp or peripheryOptions.beamDamp
  peripheryReinfOptions.beamDeform = peripheryReinfOptions.wheelPeripheryReinfBeamDeform or peripheryOptions.beamDeform
  peripheryReinfOptions.beamStrength = peripheryReinfOptions.wheelPeripheryReinfBeamStrength or peripheryOptions.beamStrength
  peripheryReinfOptions.beamPrecompression = peripheryReinfOptions.wheelPeripheryReinfBeamPrecompression or 1
  peripheryReinfOptions.dampCutoffHz = peripheryOptions.wheelPeripheryReinfBeamDampCutoffHz or nil

  cleanupBeamOptions(cleanupWheelOptions(hubcapAttachOptions))
  cleanupBeamOptions(cleanupWheelOptions(sideOptions))
  cleanupBeamOptions(cleanupWheelOptions(sideReinfOptions))
  cleanupBeamOptions(cleanupWheelOptions(reinfOptions))
  cleanupBeamOptions(cleanupWheelOptions(treadOptions))
  cleanupBeamOptions(cleanupWheelOptions(treadReinfOptions))
  cleanupBeamOptions(cleanupWheelOptions(peripheryOptions))
  cleanupBeamOptions(cleanupWheelOptions(peripheryReinfOptions))

  vehicle.triangles = vehicle.triangles or {}
  local pressureGroupName = '_wheelPressureGroup' .. wheel.wheelID
  local wheelPressure = wheel.pressurePSI or 10
  local wheelDragCoef = wheel.dragCoef or 100
  local wheelSkinDragCoef = wheel.skinDragCoef
  local wheelTreadTriangleType = NORMALTYPE
  local wheelSide1TriangleType = NORMALTYPE
  local wheelSide2TriangleType = NORMALTYPE

  if (wheel.triangleCollision or false) == false then
    wheelTreadTriangleType = NONCOLLIDABLE
    wheelSide1TriangleType = NONCOLLIDABLE
    wheelSide2TriangleType = NONCOLLIDABLE
  end

  if wheel.treadTriangleCollision == false then
    wheelTreadTriangleType = NONCOLLIDABLE
  end

  if wheel.side1TriangleCollision == false then
    wheelSide1TriangleType = NONCOLLIDABLE
  end

  if wheel.side2TriangleCollision == false then
    wheelSide2TriangleType = NONCOLLIDABLE
  end

  local hubTriangleCollision = wheel.hubTriangleCollision == true and true or false
  local hubSide1TriangleCollision = wheel.hubSide1TriangleCollision == true and true or false
  local hubSide2TriangleCollision = wheel.hubSide2TriangleCollision == true and true or false

  local sideBeams = {}
  local peripheryBeams = {}
  local treadBeams = {}
  local reinfBeams = {}

  local inaxisnode = wheel.node1
  local outaxisnode = wheel.node2
  local vTris = vehicle.triangles

  for i = 0, wheel.numRays - 1 do
    local i2 = 2*i
    local nextdelta = 2*((i+1)%wheel.numRays)
    local outhubnode = hubnodebase + i2
    local inhubnode = outhubnode + 1
    local nextouthubnode = hubnodebase + nextdelta
    local nextinhubnode = nextouthubnode + 1
    local previntirenode = nodebase + 2 *((i + wheel.numRays - 1)%wheel.numRays)
    local intirenode = nodebase + i2
    local prevouttirenode = previntirenode + 1
    local outtirenode = intirenode + 1
    local nextintirenode = nodebase + nextdelta
    local nextouttirenode = nextintirenode + 1
    local nextnextintirenode = nodebase + 2*((i+2)%wheel.numRays)
    local nextnextouttirenode = nextnextintirenode + 1
    -- Hub caps
    if wheel.enableHubcaps and wheel.numRays%2 ~= 1 and i < ((wheel.numRays)/2) then
      local hubcapnode = hubcapnodebase + i
      local nexthubcapnode = hubcapnodebase + ((i+1)%(wheel.numRays/2))
      local nextnexthubcapnode = hubcapnodebase + ((i+2)%(wheel.numRays/2))
      local hubcapaxisnode = hubcapnode + (wheel.numRays/2) - i
      local hubcapinhubnode = inhubnode + i2
      local prevhubcaphubnode = hubnodebase + 2 *((i2 + wheel.numRays - 1)%wheel.numRays)+1
      local nexthubcapinhubnode = hubcapinhubnode + 2
      local hubcapouthubnode = hubcapinhubnode - 1

      --hubcap periphery
      jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, nexthubcapnode,    NORMALTYPE, hubcapOptions)
      --attach to center node
      jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, hubcapaxisnode,    NORMALTYPE, hubcapOptions)
      --attach to axis
      if wheel.enableExtraHubcapBeams == true then
        --jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, wheel.node1, NORMALTYPE, hubcapAttachOptions)
        --jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, wheel.node2, NORMALTYPE, hubcapAttachOptions)
        if i == 1 then
          jbeamUtils.addBeamWithOptions(vehicle, hubcapaxisnode, wheel.node1, NORMALTYPE, hubcapAttachOptions)
          jbeamUtils.addBeamWithOptions(vehicle, hubcapaxisnode, wheel.node2, NORMALTYPE, hubcapAttachOptions)
        end
      end

      --span beams
      jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, nextnexthubcapnode,    NORMALTYPE, hubcapOptions)

      --attach it
      jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, hubcapinhubnode,   NORMALTYPE,   hubcapAttachOptions)
      jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, prevhubcaphubnode, NORMALTYPE,   hubcapAttachOptions)
      jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, hubcapouthubnode,  NORMALTYPE,   hubcapAttachOptions)
      jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, hubcapouthubnode,  BEAM_SUPPORT, hubcapSupportOptions)

      --self:jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, wheel.node1,    NORMALTYPE, hubcapAttachOptions)
      --self:jbeamUtils.addBeamWithOptions(vehicle, hubcapnode, wheel.node2,    NORMALTYPE, hubcapAttachOptions)
    end

    --hub tread
    jbeamUtils.addBeamWithOptions(vehicle, outhubnode, inhubnode,      NORMALTYPE, hubTreadOptions)
    jbeamUtils.addBeamWithOptions(vehicle, inhubnode,  nextouthubnode, NORMALTYPE, hubTreadOptions)

    --hub periphery beams
    jbeamUtils.addBeamWithOptions(vehicle, outhubnode, nextouthubnode, NORMALTYPE, hubPeripheryOptions)
    jbeamUtils.addBeamWithOptions(vehicle, inhubnode,  nextinhubnode,  NORMALTYPE, hubPeripheryOptions)

    --hub axis beams
    jbeamUtils.addBeamWithOptions(vehicle, outhubnode, inaxisnode, NORMALTYPE, hubReinfOptions)
    jbeamUtils.addBeamWithOptions(vehicle, outhubnode, outaxisnode, NORMALTYPE, hubSideOptions)
    jbeamUtils.addBeamWithOptions(vehicle, inhubnode,  inaxisnode, NORMALTYPE, hubSideOptions)
    jbeamUtils.addBeamWithOptions(vehicle, inhubnode,  outaxisnode, NORMALTYPE, hubReinfOptions)

    --Beams to stability node
    if nodeStabilizerExists then
      jbeamUtils.addBeamWithOptions(vehicle, outhubnode,  wheel.nodeStabilizer, NORMALTYPE, hubStabilizerOptions)
    end

    if hubSide1TriangleCollision then
      addTri(vTris, nextouthubnode, outhubnode, outaxisnode, wheelDragCoef * 0.5, NORMALTYPE)
    end

    if hubSide2TriangleCollision then
      addTri(vTris, inhubnode, nextinhubnode, inaxisnode, wheelDragCoef * 0.5, NORMALTYPE)
    end

    if tireExists then
      --tire tread
      table.insert( treadBeams,
        jbeamUtils.addBeamWithOptions(vehicle, intirenode,  outtirenode,    NORMALTYPE, treadOptions) )
      table.insert( treadBeams,
        jbeamUtils.addBeamWithOptions(vehicle, outtirenode, nextintirenode, NORMALTYPE, treadOptions) )

      --tread reinforcement
      if wheel.enableTreadReinfBeams then
        table.insert( treadBeams,
          jbeamUtils.addBeamWithOptions(vehicle, intirenode, nextouttirenode, NORMALTYPE, treadReinfOptions) )
        table.insert( treadBeams,
          jbeamUtils.addBeamWithOptions(vehicle, outtirenode, nextnextintirenode, NORMALTYPE, treadReinfOptions) )
      end

      -- paired treadnodes
      vehicle.nodes[intirenode].pairedNode = outtirenode
      vehicle.nodes[intirenode].pairedNode2 = prevouttirenode
      vehicle.nodes[outtirenode].pairedNode = nextintirenode
      vehicle.nodes[outtirenode].pairedNode2 = intirenode

      -- Periphery beams
      table.insert(peripheryBeams,
        jbeamUtils.addBeamWithOptions(vehicle, intirenode,  nextintirenode,  NORMALTYPE, peripheryOptions) )
      table.insert(peripheryBeams,
        jbeamUtils.addBeamWithOptions(vehicle, outtirenode, nextouttirenode, NORMALTYPE, peripheryOptions) )

      --hub tire beams
      table.insert( sideBeams,
        jbeamUtils.addBeamWithOptions(vehicle, outhubnode,  outtirenode,    BEAM_ANISOTROPIC, sideOptions) )
      table.insert( sideBeams,
        jbeamUtils.addBeamWithOptions(vehicle, outtirenode, nextouthubnode, BEAM_ANISOTROPIC, sideOptions) )
      table.insert( sideBeams,
        jbeamUtils.addBeamWithOptions(vehicle, inhubnode,   intirenode,     BEAM_ANISOTROPIC, sideOptions) )
      table.insert( sideBeams,
        jbeamUtils.addBeamWithOptions(vehicle, inhubnode,   nextintirenode, BEAM_ANISOTROPIC, sideOptions) )

      --reinf beams
      if wheel.enableTireReinfBeams then
        table.insert( reinfBeams,
          jbeamUtils.addBeamWithOptions(vehicle, intirenode,  outhubnode,     NORMALTYPE, reinfOptions) )
        table.insert( reinfBeams,
          jbeamUtils.addBeamWithOptions(vehicle, inhubnode,   outtirenode,    NORMALTYPE, reinfOptions) )
      elseif wheel.enableTireLbeams then
          table.insert( reinfBeams,
            jbeamUtils.addBeamWithOptions(vehicle, intirenode,  outhubnode,     BEAM_LBEAM, reinfOptions, inhubnode ))
          table.insert( reinfBeams,
            jbeamUtils.addBeamWithOptions(vehicle, inhubnode,   outtirenode,    BEAM_LBEAM, reinfOptions, outhubnode ))
      end

      --side reinf beams
      if wheel.enableTireSideReinfBeams then
        table.insert( sideBeams,
          jbeamUtils.addBeamWithOptions(vehicle, outhubnode, nextouttirenode, BEAM_ANISOTROPIC, sideReinfOptions) )
        table.insert( sideBeams,
          jbeamUtils.addBeamWithOptions(vehicle, outtirenode, hubnodebase + 2*((i+2)%wheel.numRays), BEAM_ANISOTROPIC, sideReinfOptions) )
        table.insert( sideBeams,
          jbeamUtils.addBeamWithOptions(vehicle, intirenode, nextinhubnode, BEAM_ANISOTROPIC, sideReinfOptions) )
        table.insert( sideBeams,
          jbeamUtils.addBeamWithOptions(vehicle, inhubnode, nodebase + 2*((i+2)%wheel.numRays), BEAM_ANISOTROPIC, sideReinfOptions) )
      end

      if wheel.enableTirePeripheryReinfBeams then
          jbeamUtils.addBeamWithOptions(vehicle, intirenode, nextnextintirenode, NORMALTYPE, peripheryReinfOptions)
          jbeamUtils.addBeamWithOptions(vehicle, outtirenode, nextnextouttirenode, NORMALTYPE, peripheryReinfOptions)
      end

      -- hub pressure tris
      addPressTri(vTris, pressureGroupName, wheelPressure, inhubnode, nextouthubnode, outhubnode, wheelDragCoef * 0.1, NONCOLLIDABLE)
      addPressTri(vTris, pressureGroupName, wheelPressure, inhubnode, nextinhubnode, nextouthubnode, wheelDragCoef * 0.1, NONCOLLIDABLE)

      -- tread pressure tris
      addPressTri(vTris, pressureGroupName, wheelPressure, intirenode, outtirenode, nextintirenode, wheelDragCoef * 0.2, wheelTreadTriangleType, wheelSkinDragCoef)
      addPressTri(vTris, pressureGroupName, wheelPressure, nextintirenode, outtirenode, nextouttirenode, wheelDragCoef * 0.2, wheelTreadTriangleType, wheelSkinDragCoef)

      -- outside pressure tris
      addPressTri(vTris, pressureGroupName, wheelPressure, outtirenode, outhubnode, nextouthubnode, wheelDragCoef * 0.5, wheelSide1TriangleType)
      addPressTri(vTris, pressureGroupName, wheelPressure, outtirenode, nextouthubnode, nextouttirenode, wheelDragCoef * 0.5, wheelSide1TriangleType)

      -- inside pressure tris
      addPressTri(vTris, pressureGroupName, wheelPressure, inhubnode, intirenode, nextintirenode, wheelDragCoef * 0.5, wheelSide2TriangleType)
      addPressTri(vTris, pressureGroupName, wheelPressure, nextinhubnode, inhubnode, nextintirenode, wheelDragCoef * 0.5, wheelSide2TriangleType)
    else
      if hubTriangleCollision then
        -- hub tris
        addTri(vTris, nextouthubnode, inhubnode, outhubnode, wheelDragCoef * 0.1, NORMALTYPE)
        addTri(vTris, nextinhubnode, inhubnode, nextouthubnode, wheelDragCoef * 0.1, NORMALTYPE)
      end
    end
  end

  wheel.nodes = hubNodes
  wheel.treadNodes = treadNodes
  wheel.sideBeams = sideBeams
  wheel.peripheryBeams = peripheryBeams
  --wheel.reinfBeams = reinfBeams
  wheel.treadBeams = treadBeams
  wheel.pressureGroup = pressureGroupName
end

local function processWheel(vehicle, wheelSection, wheelCreationFunction)
  if vehicle[wheelSection] ~= nil then
    for k, v in pairs(vehicle[wheelSection]) do
      --log('D', "jbeam.processWheel"," * "..tostring(k).." = "..tostring(v).." ["..type(v).."]")
      if v.numRays == nil or v.numRays > 0 then
        local wheelID = jbeamUtils.increaseMax(vehicle, 'wheels')
        v.wheelID = wheelID
        wheelCreationFunction(vehicle, k, v)
        vehicle.wheels[wheelID] = v
        vehicle[wheelSection][k] = nil -- everything is in wheels now
      end
    end
  end
  if not tableIsEmpty(vehicle[wheelSection]) then
    --log('D', "jbeam.processWheel"," - processed "..tableSize(vehicle[wheelSection]).." of "..wheelSection.."(s)")
  end
end

local function processWheels(vehicle)
  profilerPushEvent('jbeam/wheels.processWheels')
  if vehicle.wheels ~= nil  then
    local tmpwheels = vehicle.wheels
    vehicle.wheels = {}
    vehicle.maxIDs.wheels = nil
  end

  if vehicle.wheels == nil then vehicle.wheels = {} end

  processWheel(vehicle, "wheels", addWheel)
  processWheel(vehicle, "monoHubWheels", addMonoHubWheel)
  processWheel(vehicle, "hubWheelsTSV", addHubWheelTSV)
  processWheel(vehicle, "hubWheelsTSI", addHubWheelTSI)
  processWheel(vehicle, "hubWheels", addHubWheel)
  processWheel(vehicle, "pressureWheels", addPressureWheel)

  profilerPopEvent() -- jbeam/wheels.processWheels
  return true
end

local function processRotators(vehicle)
  if vehicle.rotators ~= nil then
    for rotId, rotData in pairs(vehicle.rotators) do
      --log('D', "jbeam.postProcess"," * "..tostring(k).." = "..tostring(v).." ["..type(v).."]")
      local wheelID = jbeamUtils.increaseMax(vehicle, 'wheels')
      rotData.wheelID = wheelID
      jbeamUtils.addRotator(vehicle, rotId, rotData)
      vehicle.wheels[wheelID] = rotData
    end
  end
  if not tableIsEmpty(vehicle.rotators) then
    --log('D', "jbeam.postProcess"," - processed "..tableSize(vehicle.rotators).." of rotator(s)")
  end

  -- remove wheels with no nodes and renumber the cids
  local newWheels = {}
  local wheelId = 0
  for wheelKey, wheel in pairs(vehicle.wheels) do
    if wheel.nodes == nil or next(wheel.nodes) == nil then
      log('W', "jbeam.pushToPhysics","*** wheel: "..wheel.name.." doesn't have any node bindings")
    else
      newWheels[wheelId] = wheel
      wheel.cid = wheelId
      wheelId = wheelId + 1
    end
  end
  vehicle.wheels = newWheels
end

M.processWheels = processWheels
M.processRotators = processRotators

return M
