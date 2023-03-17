--[[
This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
If a copy of the bCDDL was not distributed with this
file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
This module contains a set of functions which manipulate behaviours of vehicles.
]]

local M = {}

local jbeamUtils = require("jbeam/utils")

-- these are defined in C, do not change the values
local NORMALTYPE = 0
local BEAM_ANISOTROPIC = 1
local BEAM_HYDRO = 6

local function processNodes(vehicle)
  if not vehicle.nodes then return end
  for k, v in pairs(vehicle.nodes) do
    if v.nodeOffset and type(v.nodeOffset) == 'table' and v.nodeOffset.x and v.nodeOffset.y and v.nodeOffset.z then
      v.posX = v.posX + sign(v.posX) * v.nodeOffset.x
      v.posY = v.posY + v.nodeOffset.y
      v.posZ = v.posZ + v.nodeOffset.z
    end
    if v.nodeMove and type(v.nodeMove) == 'table' and v.nodeMove.x and v.nodeMove.y and v.nodeMove.z then
      v.posX = v.posX + v.nodeMove.x
      v.posY = v.posY + v.nodeMove.y
      v.posZ = v.posZ + v.nodeMove.z
    end
    vehicle.nodes[k]['pos'] = vec3(v.posX, v.posY, v.posZ)

    -- TODO: REMOVE AGAIN
    v.posX=nil
    v.posY=nil
    v.posZ=nil
  end
end

local function processHydros(vehicle)
  if not vehicle.hydros then return end
  for i, hydro in pairs(vehicle.hydros) do
    hydro.beamType = BEAM_HYDRO
    hydro.beam = jbeamUtils.addBeamWithOptions(vehicle, nil, nil, BEAM_HYDRO, hydro)
    local bL = vec3(vehicle.nodes[hydro.id1].pos):distance(vehicle.nodes[hydro.id2].pos)

    hydro.inRate = hydro.inRate or 2
    hydro.outRate = hydro.outRate or hydro.inRate
    hydro.autoCenterRate = hydro.autoCenterRate or hydro.inRate

    if type(hydro.inExtent) == 'number' then
      hydro.inLimit = hydro.inExtent / (bL + 1e-30)
    end

    if type(hydro.outExtent) == 'number' then
      hydro.outLimit = hydro.outExtent / (bL + 1e-30)
    end

    hydro.inLimit = hydro.inLimit or 0
    hydro.outLimit = hydro.outLimit or 2
    hydro.inputSource = hydro.inputSource or "steering"
    hydro.inputCenter = hydro.inputCenter or 0
    hydro.inputInLimit = hydro.inputInLimit or -1
    hydro.inputOutLimit = hydro.inputOutLimit or 1
    hydro.inputFactor = hydro.inputFactor or 1

    if type(hydro.extentFactor) == 'number' then
      hydro.factor = hydro.extentFactor / (bL + 1e-30)
    end

    if type(hydro.factor) == 'number' then
      hydro.inLimit = 1 - math.abs(hydro.factor)
      hydro.outLimit = 1 + math.abs(hydro.factor)
      hydro.inputFactor = sign2(hydro.factor)
    end
    hydro.analogue = false
  end
end

local function processRopes(vehicle)
  if not vehicle.ropes then return end
  for i, rope in pairs(vehicle.ropes) do
    rope.segments = rope.segments or 1
    if rope.segments < 1 then rope.segments = 1 end
    rope.length = rope.length or 1
    rope.nodeWeight = rope.nodeWeight or 5
    rope.springExpansion = rope.springExpansion or rope.beamSpring
    rope.dampExpansion = rope.dampExpansion or rope.beamDamp
    rope.beamLongBound = rope.beamLongBound or math.huge

    -- figure out where the rope is going
    local startPos = vec3(vehicle.nodes[rope.id1].pos)
    local endPos = startPos + vec3(rope.length, 0, 0)
    if rope.id2 then
      endPos = vec3(vehicle.nodes[rope.id2].pos)
      rope.length = (endPos - startPos):length()
    end
    local vecDiff = (endPos - startPos) / rope.segments
    local nPos = vec3(startPos)

    local lastNodeId = rope.id1
    rope.nodes = nil
    rope.beams = nil
    local ropenodes = {}
    local ropebeams = {}
    local ropecopy = deepcopy(rope)
    ropecopy.length = nil
    ropecopy.id2 = nil
    ropecopy.segments = nil

    -- create the segments
    for si = 1, rope.segments do
      nPos = nPos + vecDiff
      -- if the last step, connect to target node?
      local nid2
      if si == rope.segments and rope.id2 then
        -- last node (id2)
        nid2 = rope.id2
      else
        -- insert new node
        nid2 = jbeamUtils.addNodeWithOptions(vehicle, nPos:toDict(), NORMALTYPE, ropecopy)
      end
      table.insert(ropenodes, nid2)
      table.insert(ropebeams, jbeamUtils.addBeamWithOptions(vehicle, lastNodeId, nid2, BEAM_ANISOTROPIC, ropecopy))
      lastNodeId = nid2
    end
    rope.nodes = ropenodes
    rope.beams = ropebeams
  end
end

local function processQuads(vehicle)
  if not vehicle.quads then return end
  vehicle.maxIDs.triangles = vehicle.maxIDs.triangles or 0
  if vehicle.triangles == nil then vehicle.triangles = {} end
  -- quads are a way of placing two tris at the same time
  for _, quad in pairs(vehicle.quads) do
    local tri1 = deepcopy(quad)
    tri1.cid = vehicle.maxIDs.triangles
    vehicle.maxIDs.triangles = vehicle.maxIDs.triangles + 1
    table.insert(vehicle.triangles, tri1)
    tri1.id4 = nil

    local tri2 = deepcopy(quad)
    tri2.cid = vehicle.maxIDs.triangles
    vehicle.maxIDs.triangles = vehicle.maxIDs.triangles + 1
    tri2.id1 = quad.id3
    tri2.id2 = quad.id4
    tri2.id3 = quad.id1
    tri2.id4 = nil
    table.insert(vehicle.triangles, tri2)
  end
  vehicle.quads = nil -- not needed anymore
end


local function process(vehicle)
  profilerPushEvent('jbeam/nodeBeam.process')
  processNodes(vehicle)
  processHydros(vehicle)
  processRopes(vehicle)
  processQuads(vehicle)

  if vehicle.refNodes == nil then
    vehicle.refNodes = {}
  end
  if vehicle.refNodes[0] == nil then
    log('E', "jbeam.pushToPhysics", "Reference nodes missing. Please add them")
    vehicle.refNodes[0] = {ref = 0, back = 1, left = 2, up = 0}
  end

  profilerPopEvent() -- jbeam/nodeBeam.process
end

M.process = process

return M