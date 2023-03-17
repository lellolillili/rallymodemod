--[[
This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
If a copy of the bCDDL was not distributed with this
file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
This module contains a set of functions which manipulate behaviours of vehicles.
]]

local M = {}

M.ignoreSections = {maxIDs=true, options=true}

-- these are defined in C, do not change the values
local NORMALTYPE = 0
local BEAM_LBEAM = 4

local function increaseMax(vehicle, name)
  local res = vehicle.maxIDs[name] or 0
  vehicle.maxIDs[name] = res + 1
  return res
end

local function addNodeWithOptions(vehicle, pos, ntype, options)
  local n
  if type(options) == 'table' then
    n = deepcopy(options)
  else
    n = {}
  end

  local nextID = increaseMax(vehicle, 'nodes')
  n.cid     = nextID
  n.pos     = pos
  n.ntype   = ntype

  --log('D', "jbeam.addNodeWithOptions","adding node "..(nextID)..".")
  table.insert(vehicle.nodes, n)
  return nextID
end

local function addNode(vehicle, pos, ntype)
  return addNodeWithOptions(vehicle, pos, ntype, vehicle.options)
end

local function addBeamWithOptions(vehicle, id1, id2, beamType, options, id3)
  id1 = id1 or options.id1
  id2 = id2 or options.id2

  -- check if nodes are valid
  local node1 = vehicle.nodes[id1]
  local node2 = vehicle.nodes[id2]
  if node1 == nil or node2 == nil then
    if node1 == nil then
      log('W', "jbeam.addBeamWithOptions","invalid node "..tostring(id1).." for new beam between "..tostring(id1).."->"..tostring(id2))
      return
    end
    if node2 == nil then
      log('W', "jbeam.addBeamWithOptions","invalid node "..tostring(id2).." for new beam between "..tostring(id1).."->"..tostring(id2))
      return
    end
  end

  -- increase counters
  local nextID = increaseMax(vehicle, 'beams')

  local b
  if type(options) == 'table' then
    b = deepcopy(options)
  else
    b = {}
  end

  if id3 ~= nil then
    local node3 = vehicle.nodes[id3]
    if node3 == nil then
      log('W', "jbeam.addBeamWithOptions","invalid node "..tostring(id3).." for new beam between "..tostring(id1).."->"..tostring(id2))
      return
    else
      beamType = BEAM_LBEAM
    end
    b.id3 = node3.cid
  end

  b.cid      = nextID
  b.id1      = node1.cid
  b.id2      = node2.cid
  b.beamType = beamType

  -- add the beam
  table.insert(vehicle.beams, b)
  return b
end

local function addBeam(vehicle, id1, id2)
  return addBeamWithOptions(vehicle, id1, id2, NORMALTYPE, vehicle.options)
end

local function addRotator(vehicle, wheelKey, wheel)
  wheel.frictionCoef = wheel.frictionCoef or 1

  local nodes = {}
  if wheel._group_nodes ~= nil then
    arrayConcat(nodes, wheel._group_nodes)
  end

  if wheel._rotatorGroup_nodes ~= nil then
    arrayConcat(nodes, _rotatorGroup_nodes)
  end

  if next(nodes) ~= nil then
    wheel.nodes = nodes
  end
end

M.addNodeWithOptions = addNodeWithOptions
M.addNode = addNode
M.increaseMax = increaseMax
M.addBeamWithOptions = addBeamWithOptions
M.addBeam = addBeam
M.addRotator = addRotator

return M