-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = "ProcTrack"

local params = nil
-- This function gives you a fresh instance of the default params
local function getDefaultParams()
  -- These are the params for creating a Gymkhana.
  return {
    debug = {
     rects = true, -- spawns rects above the track
      neighbours = true -- prints neighbours
      },
    limits = {
      nodeCreationCounter = 5,
      pathCounter = 15
    },

    rootX = 240, -- root X of the track
    rootY = -20, -- root Y of the track
    rootZ =34.35, -- root Z of the track
    rootAngleRad = 0,
   -- if you need those, preferably set at least the start position through a noSplit rectangle with the start flag.
    start = { -- the closest node to this point will be the starting node, if there is no rect with the start flag set.
      prefX = 0,
      prefY = 10000
    },
    finish = { -- the closest node to this point will be the starting node, if there is no rect with the finish flag set.
      prefX = 0,
      prefY = -10000
    },


    rollingStart = true, -- if false, rolling start for scenario will be false.
    moveVehicleIntoPosition = false, -- if true, will set the vehicle either to the start line or one checkpoint before the start line (depengin on rolling start)
    vehiclePlacement = nil,
    --[[{ -- if not null and moveVehicleIntoPosition, vehicle will be moved to this position facing in dir direction.
      pos = {x=0,y=70,z=34.3},
      dir = {x=0,y=-1,z=0}

    },]]
    -- size and position in the level.
    startingRects = {
    -- filled in gym()


    },


    decoration = {
      gateHeight = 3,
      gateWidth = 4.5,
      circlesHeight = 1,
      pointsHeight = 1
    },
    -- how many base nodes should be placed.
    rectModeParams = {
        minXDist = 15, -- minimum distance between nodes, X-axis. lower value here means tighter roads, and a generyll more random track layout.
        minYDist = 15, -- minimum distance between nodes, Y-axis. lower value here means tighter roads, and a generyll more random track layout.
        cutValueFunction = function ()
          return  (math.random() + math.random()) / 2
        end ,-- where the cut on a rectangle should be made. should return between 0 and 1.
        vertSplitFunction = function (width, height)
          return ((math.random()/2 + math.random()/2) * (width + height)) < width
        end ,-- whether a rectangle should be cut vertically


        minNodes = 6, -- never less nodes than this
        maxNodes = 27, -- never more nodes than this. over 27 sometimes take extremely long to generate
        randomMin = -1, -- minimum random nodecount to add
        randomMax = 1, -- maximum random nodecount to add
        density = .85, -- node^s per 1000m² ( ~= 30m x 30m )
        fixNodes = nil -- if this is a value, node count will be fixed.
    },

      -- information for the windin path.
    path = {
      nodeRadiusFunction = function (closestDist)
        return math.random() *  math.max(0,(closestDist *0.40-2.5))+2
      end,
     -- closestNeighbourDistMultiplier = , -- maximum radius for nodes, as percentage of the distance to the closest neighbour. higher value means bigger circles. values over .5 will likely cause intersections.
      minRadius = 2.5, -- no radius will be smaller than this (except for gates)
      pylonRadiusThreshold =6, -- radii smaller than this will have a pylon in the middle instead of a circle. radii of 0 will make a gate by default.
      minDotForCurve = 0.33, -- min dot product of two consecutive nodes to be considered a curve. higher value means stronger bends are still considered straight.
      curveStepMaxRad = math.pi / 10, -- how fine the steps for curves should be. lower value means more road nodes and more pylons for circles.

      loopMinDot = -.33, -- minumum dot product for two consecutive nodes to allow to be a loop. higher value means angle has to be sharper. values below 0 means wider than 90° can also be looped.
      loopChance = .75, -- the chance of a curved node becoming a looparound
      loopBaseChance = .5, -- base chance for loops
      loopIncChance = .1, -- everytime a node doesnt loop but could, the chance is increased by this amount.

      gateChance =.8, -- the chance of a straight node becoming a gate.
      gateBaseChance = .7, -- the base chance of a straight node becoming a gate.
      gateIncChance = .125, -- every time a node doesnt become a gate but could, the chance is increased by this amount.

      closed = false, -- make a closed circuit track
      lapCount = nil,
      rollingStart = false,



     }
    }
end
-- this function regenerates the whole track. a new seed can be set.
local function reGenerate(seed)
  params.seed = seed
  local newParams = M.getDefaultParams()
  newParams.scenarionParam = params.scenarionParam
  newParams.populateFunction = params.populateFunction
  newParams.decoration.afterFunction = params.decoration.afterFunction
  newParams.seed = seed
  M.makeGymkhana(newParams)
end

-- this is the main function and will create a complete track .
local function makeGymkhana(inParams)
  -- check the params, if everythings ok etc

  params = inParams
  M.checkParams()
  guihooks.trigger("procTrackSeed", params.seed)
  log("I",logTag, "Starting a new Generation. Seed = " ..params.seed .. " SeedWord = ".. M.intToWords(params.seed))

  -- first, we need to have a workable path.
  local path = nil
  local pathCounter = 0
  while path == nil do
    local totalTS = [[
        if(isObject("GymkhanaArena")) {
            GymkhanaArena.delete();
        }

        MissionGroup.add(new SimGroup("GymkhanaArena") {
          position = "]] .. params.rootX .. [[ ]] .. params.rootY .. [[ 0";

        } );
    ]]

    --log('I', logTag, "Arena object created.")
    -- create the baseGraph.
    local nodeCounter = 0
    local baseGraph = {nodes={}}
    while #baseGraph.nodes <  params.rectModeParams.numNodes  do
      TorqueScript.eval(totalTS)
      if nodeCounter > params.limits.nodeCreationCounter then
        log('E', logTag, "Could not create enough Nodes after "..params.limits.nodeCreationCounter.." Iterations. Maybe Settings are bad? Check params.rectModeParams")
        --log('W', logTag, params.rectModeParams)
        return
      end
      baseGraph= M.makeBaseNodePositions()
      nodeCounter = nodeCounter+1

    end
    if pathCounter > params.limits.pathCounter then
      log('E', logTag, "No Path found after "..params.limits.pathCounter.." Iterations. Maybe Settings are bad? Check params.path")
      --log('W', logTag, params.path)
      return
    end

    --log('I', logTag, "Base node positions and neighbours determined.")
    -- try to make a path through the baseGraph.
    path = M.makePath(baseGraph)
    -- did it work?
    if path == nil then
      --log('I', logTag, "No Path found. Restarting. ")
    end
    -- lets try 10 times, if it didnt work then, something went horribly wrong.
    pathCounter = pathCounter +1

  end

  if pathCounter > 1 then
      --log('W', logTag, "Creating nodes and path took more than one attemp (" .. (pathCounter) .." attempts). This should not happen often (<10%?), espacially with  numbers >3.")
      --log('W', logTag, "Check starting rects for thin connectors, check nodeCount being sufficient")
  end

  --log('I', logTag, "Path determined.")
  -- now we create a winding path around the nodes.
  local nodes = M.createWindingPath(path)
  --log('I', logTag, "Winding Path determined.")



  -- now comes the decoration part.

  M.createWindingRoad(nodes)
  --log('I', logTag, "Winding Road created.")
  M.createPylons(nodes)
  --log('I', logTag, "Pylons created.")
  M.decorateStartAndFinish(nodes)
  --log('I', logTag, "Start and Finish created.")

  be:reloadCollision()


  M.createWaypointsForScenario(nodes)

  params.decoration.afterFunction(params.scenarionParam)

  guihooks.trigger('Message', {ttl = 60*60, msg = "Track created: " .. params.seed, category = "fill", icon = "timeline"})
  log("I",logTag, "Done. Seed = " ..params.seed .. " SeedWord = ".. M.intToWords(params.seed))

  local path = {}
  local length = 0
  local loops = 0
  local lefts = 0
  local rights = 0
  local straights = 0
  local gates = 0
  --extract nodes from nodes.
  for i,n in ipairs(nodes) do

    for _,e in ipairs(n.points) do
      path[#path+1] = e
    end
    if n.flipped then
      loops = loops+1
    end
    if n.straight then
      straights = straights+1
      if n.gate then
        gates = gates+1
      end
    elseif n.left then
      lefts = lefts+1
    elseif n.right then
      rights = rights+1
    end


  end
  for i,n in ipairs(path) do
    if i > 1 then
      length = length + M.dist(path[i].x, path[i].y, path[i-1].x, path[i-1].y)
    end
  end
  --log("I",logTag,"Total length of track is " ..string.format("%.2f", length).." meters.")
  --log("I",logTag,"Track has "..#nodes .. " keypoints: " .. straights .. " straights ("..gates.." gates), " .. (lefts+rights) .. " curves ("..lefts.." left, ".. rights.. " right), of which "..loops .. " are looped.")
end

-- this function checks if the parameters are OK.
local function checkParams()

  --dump(totalTS)
  if not params.seed then
    params.seed =  math.floor(os.time())
    math.randomseed(params.seed)
    params.seed = math.random(500*500*500*500)

    -- this limits the available tracks to 62.500.000.000 - about one per second for over 2000 years!
    -- why this instead of simply os.time ? the first few numbers from os.time are the same for a looong time,
    -- resulting in the ever same word string generated by M.intToWords(). This way, we get some variability :)
  end
  math.randomseed(params.seed)

  -- now everything can follow. the seed it set.

  params.populateFunction(params,params.scenarionParam)

  if params.rectModeParams.density then

    if params.rectModeParams.density < 0 then
      params.rectModeParams.density = 0
      log("W",logTag,"Density cant be < 0! Set to 0")
    end
  else
    params.rectModeParams.density = 0.95 + math.random()*0.2
    log("I",logTag,"Set random Density to ".. params.rectModeParams.density)
  end


  local area = 0
  local noSplits = 0
  for _,r in ipairs(params.startingRects) do
    if not r.noSplit then
      area = area + r.width * r.height
    else
      noSplits = noSplits + 1
    end
  end

  if params.rectModeParams.fixNodes then
    params.rectModeParams.numNodes = params.rectModeParams.fixNodes
  else
    params.rectModeParams.numNodes = noSplits + area / (1000 / params.rectModeParams.density)
    params.rectModeParams.numNodes = params.rectModeParams.numNodes + math.random(params.rectModeParams.randomMin, params.rectModeParams.randomMax)
  end
  if params.rectModeParams.numNodes < params.rectModeParams.minNodes then
    log("W",logTag, "Capped node count from "..params.rectModeParams.numNodes .. ' to ' .. params.rectModeParams.minNodes)
    params.rectModeParams.numNodes = params.rectModeParams.minNodes
  elseif params.rectModeParams.numNodes > params.rectModeParams.maxNodes then
    log("W",logTag, "Capped node count from "..params.rectModeParams.numNodes .. ' to ' .. params.rectModeParams.maxNodes)
    params.rectModeParams.numNodes = params.rectModeParams.maxNodes
  end


--  math.random(params.rectModeParams.minNodes,params.rectModeParams.maxNodes)

  local helper = require('util/rectangleGen')

  params.graphGeneratorModule = helper
end


local function makeBaseNodePositions()

  local graph =  params.graphGeneratorModule.getGraph(params)
  if not graph then return end

 if params.debug.neighbours then
  -- debug lines between the nodes.
    for _,r1 in ipairs(graph.nodes) do
      for _,r2i in ipairs(r1.neighbours) do
        local r2 = graph.nodes[r2i.index]
      --dump(r.name .." :  ".. #r.neighbours)
      --for _,n in ipairs(r.neighbours) do
        local roadTS = [[
              GymkhanaArena.add(new DecalRoad() {
              Material = "line_white_transparent";
              textureLength = "5";
              breakAngle = "1";
              renderPriority = "10";
              zBias = "-1";
              startEndFade = "0 0";
              position = "0 0 0";
              rotation = "1 0 0 0";
              scale = "1 1 1";
              canSave = "1";
              canSaveDynamicFields = "1";
              drivability = "-1";
              improvedSpline = "1";
              startTangent = "0";
              endTangent = "0";
              detail = "0.1";
              smoothness ="0.001";
        ]]

        local ret = ""
        local p = M.getPosition(r1.x,r1.y,0);
        ret = ret..'Node="'..p.x..' '..p.y..' 0 1";'
        p = M.getPosition(r2.x,r2.y,0);
        ret = ret..'Node="'..p.x..' '..p.y..' 0 0";'




        roadTS = roadTS .. ret
        roadTS = roadTS..'});';
           --dump(roadTS)


        TorqueScript.eval(roadTS)
      end
    end
  end

  return graph


end


---------------------------------------------------------------------------------
--                                                                             --
--  This is the Part where the path through all the nodes will be determined.  --
--                                                                             --
---------------------------------------------------------------------------------


-- this function finds a random path through the nodes with backtracking.
-- NOTE: currently uses depth first search with backtracking which has a worst case of about O(#edges!) which is very bad. Unfortunately, the hamilton path problem is NP-complete,
-- meaning there is no know algorithm to solve this in polynomial time, although algorithms exist to solve it in exponential time
local function makePath(graph)


  local path = {}
  local nodes = graph.nodes


  -- handle start and end node, if set in params.
  local startNode = graph.start
  local finishNode = graph.finish

  local sortNodes = {}
  for i,n in ipairs(graph.nodes) do
    sortNodes[i] = {x=n.x,y=n.y,i=i}
  end

  if not startNode and params.start then

    table.sort(sortNodes, function(a,b) return (M.dist(a.x,a.y,params.start.prefX,params.start.prefY)) < (M.dist(b.x,b.y,params.start.prefX,params.start.prefY)) end)
    startNode = graph.nodes[sortNodes[1].i]
  elseif not startNode and not params.start then
    startNode = graph.nodes[math.random(1,#graph.nodes)]
  end
  path[1] = startNode

  if not params.path.closed then
    -- unclosed means we just take the noce closest to the finish point
    if not finishNode and params.finish then
        table.sort(sortNodes, function(a,b) return (M.dist(a.x,a.y,params.finish.prefX,params.finish.prefY)) < (M.dist(b.x,b.y,params.finish.prefX,params.finish.prefY)) end)
        finishNode = graph.nodes[sortNodes[1].i]
    end
  else
    -- otherwise, check all neighbours from the starting node, pick one that does not split the whole graph.
    local neighbourOffset = math.random(1,#startNode.neighbours)
    local neighbourIndex =  0
    while neighbourIndex < #startNode.neighbours do
      local candidate = graph.nodes[startNode.neighbours[((neighbourIndex + neighbourOffset) % #startNode.neighbours) +1].index]
      if not M.edgeCreatesSplitGraph(path,candidate,nodes) then
        finishNode =candidate
        neighbourIndex = 1000
      end
   --dump(candidate.name .. " Is Unfit as end node.")
      neighbourIndex = neighbourIndex+1
    end
    if not finishNode then -- all edges from this node will result in a graph split, meaning we can never create a closed track, meaning this graph is garbage.
    --dump("no finish")
      return nil
    end

  end

  local index = 0
  local backTracks = 0
  -- do not stop until path has all the element from nodes.

  while #path < #nodes and index < 100000 do -- 100000 should do!



    --[[--debug output for current stack of nodes.
    local pstr = "["
    for _,p in ipairs(path) do pstr = pstr.. " " .. p.name .. " " end
    log("I",logTag,pstr .. "]")
    ]]

    -- something went horribly wrong.
    if #path == 0 then

       -- log("E",logTag,"Stopped after " ..index .. "  Iterations")

      return nil

    end

    -- take the first node, check if it has not been visited. if so, select a current index for the next element from its neighbors.
    local current = path[#path]
    if current.nextIndex == -1 or not current.nextIndex then
      current.nextIndex = math.random(1,#current.neighbours)
      current.offset = 0
    end

    -- if the index for the next index ecxeeds the number of possible successors, remove this node from stack and reset its successor determination.
    -- this is the backtrack part.
    if current.offset >= #current.neighbours then
   --   dump("doing 0ne back, popping ".. path[#path].name)
      path[#path].nextIndex=-1
      path[#path] = nil
      if #path == 0 then return nil end
      path[#path].offset = path[#path].offset+1
      backTracks = backTracks+1
    else

      -- now we actually try out the successors.
      index = index +1

      -- increase the index of the successor in the list of neighbors until we get a neighbor with is not in the current list of nodes.
      while current.offset < #current.neighbours  and M.currentEdgeNotOK(current,path,nodes,finishNode) do
       -- log("I",logTag,"Can't add Edge to " .. nodes[current.neighbours[((current.nextIndex+current.offset) % #current.neighbours)+1].index].name)
        current.offset = current.offset +1
      end
      -- if the have not exceeded neighbor count, we can add the node in question to the list of nodes.
      if current.offset < #current.neighbours then
         path[#path+1] = nodes[current.neighbours[((current.nextIndex+current.offset) % #current.neighbours)+1].index]
      end

      -- in case that we have not added a node here, the current node will be removed and reset in the next cycle (backtrack)

    end

 end
 --log("E",logTag,"Finished searching for path " ..index .. "  Iterations")
  -- output the final order of the nodes once more.
  local pstr = "["
  for _,p in ipairs(path) do pstr = pstr.. " " .. p.name .. " " end
  --log("I",logTag,pstr .. "]")
  --log("I",logTag," took " .. index .. " iterations ("..backTracks.." backtrackings).")
  -- cleanup :)
  for i,n in ipairs(path) do
    n.nextIndex = nil
    n.offset = nil
    n.floodFilled = nil
    n.neighbours = nil -- dont need that anymore.. i guess?
  end


  -- return our oder.
  return path
end

-- this function checks wether adding the next edge for the node current is allowed or not.
local function currentEdgeNotOK(current, path, nodes, finishNode)
  local nextNode = nodes[current.neighbours[((current.nextIndex+current.offset) % #current.neighbours)+1].index]
  return
    -- the next node from this edge is in the path already
    -- means this edge cant be taken.
    M.isInList(path,nextNode)

    -- alternative: if the path still has more than the last node to add,
    --but the next node would be the finish node
    -- also means this edge cant be taken.
    or ( #path ~= #nodes-1
        and nextNode == finishNode)

    or M.edgeCreatesSplitGraph(path,nextNode,nodes)
end

-- this function checks if the adding of the nextNode would result in splitting the graph.
local function edgeCreatesSplitGraph(path, nextNode, nodes)
  local freeNodes = {}
  -- collect all nodes not in the path or the next node.
  for _,n in ipairs(nodes) do
    if n ~= nextNode and not M.isInList(path,n) then
      freeNodes[#freeNodes+1] = n
      n.floodFilled = false
    end
  end
  --dump("#freeNodes == "..#freeNodes)
  if #freeNodes == 0 then -- no more nodes, no lonely nodes :)

    return false
  end

  -- chek if a floodfill from one of this nodes results in all the free nodes.
  -- if that aint the case, there must be more than one separated group,
  -- which means that the current path cant collect all nodes.

  local open = {}
  open[1] = freeNodes[1]
  local stop = false

  while not stop do
    -- find first node which has not been floodfilled.
    local currentIndex = 1
    while currentIndex <= #open and open[currentIndex].floodFilled  do
      currentIndex = currentIndex+1
    end
    --dump("currentIndex"..currentIndex)
    -- if no such node, we are done.
    if currentIndex > #open then
      stop = true
    else
      -- otherwise add all neighbours, which are not the next node, not in the path and not already floodfilled to the open list.
      for _,n in ipairs(open[currentIndex].neighbours) do
        local neighbour = nodes[n.index]
        if neighbour ~= nextNode and not M.isInList(path,neighbour) and not neighbour.floodFilled and not M.isInList(open,neighbour) then
          open[#open+1] = neighbour
        end
      end
      -- set current node floodfilled.
      open[currentIndex].floodFilled = true
    end
  end
  if #open ~= #freeNodes then
  --dump("Would Create Lonely nodes if we added "..nextNode.name)
  end

  --dump("#open = "..#open .. " #free = "..#freeNodes)
  -- if the number of nodes in the open list is not the number of free nodes, we have a separated group!

  return #open ~= #freeNodes
end

-- checks wether an element is in a list or not.
local function isInList(list, element)
  for _,p in ipairs(list) do
    if p == element then
        return true
    end
  end
  return false
end


---------------------------------------------------------------------------------
--                                                                             --
--  This is the Part where the road through the path will be determined.       --
--                                                                             --
---------------------------------------------------------------------------------

-- this function extracts information such as angle, distance between nodes from the path.
-- then
local function createWindingPath(path)

  if params.path.closed then
    local cPath = {}
    cPath[1] = path[#path]
    for _,p in ipairs(path) do
      cPath[#cPath+1] = p
    end
    cPath[#cPath+1] = path[1]
    path = cPath
  end

  local nodes = {}
  -- gather information about distances, points, vectors, angles etc.
  nodes = M.getBaseInformationFromPath(path)

  if params.path.closed then
    nodes[1] = nodes[#nodes-1]
    nodes[2].flipped = false
    nodes[#nodes] = nodes[2]
  end

  -- determine the in and outangle. See https://en.wikipedia.org/wiki/Belt_problem
  nodes = M.determineInOutAngle(nodes)



  -- determine actual new path nodes for each point on the path.
  nodes = M.getPathRoadNodes(nodes)

  if params.path.closed then
    local cNodes = {}
    for i,n in ipairs(nodes) do
      if i ~= 1 and i ~= #nodes then
        cNodes[#cNodes+1] = n
      end
    end
    --nodes = cNodes
  end

  return nodes
end


-- extracts basic information from the path like angles, distances, normals etc.
local function getBaseInformationFromPath(path)
  local nodes = {}

  --first, loop over all nodes and gather information about distances, points, vectors, angles etc.
  for i,p in ipairs(path) do
    --for all nodes, get the point of the pylon.
    nodes[i] = {
    index = i,
      p = {
        x = p.x,
        y = p.y
      },
      pass = {},
      force = p.force
    }
    -- set the radius for this nodes. this is calculated from the distance of the closest neighbor and params.
    nodes[i].radius = params.path.nodeRadiusFunction(p.closestNeighbourDist)
    if nodes[i].force and nodes[i].force.radius then
      --dump("Forced radius.")
      nodes[i].radius = nodes[i].force.radius
    elseif nodes[i].force and nodes[i].force.radiusPercent then
      --dump("Forced radiusPercent.")
      nodes[i].radius = nodes[i].force.radiusPercent * p.closestNeighbourDist
    end

    if nodes[i].radius < params.path.minRadius then
      nodes[i].radius = params.path.minRadius
    end


    -- start and end nodes have no radius.
    if i == 1 or i == #path then
      nodes[i].radius = 0
    end


    -- for every pair of consecutive nodes, determine vector information from node to node.
    if i > 1 then
      local v = {
        x = nodes[i].p.x - nodes[i-1].p.x,
        y = nodes[i].p.y - nodes[i-1].p.y
      }
      v.length = M.dist(0,0,v.x,v.y)
      local n = {
        x = v.x / v.length,
        y = v.y / v.length
      }
      nodes[i-1].v = v
      nodes[i-1].n = n -- normalized

    end

    -- for every pair of consecutive vectors, determine the angle and the bend (left/right/straight)
    if i > 2 then
      local det = (nodes[i-2].n.x * -nodes[i-1].n.x + nodes[i-2].n.y * -nodes[i-1].n.y)
      nodes[i-1].angleRad = math.acos(det)
      nodes[i-1].angleDeg = (nodes[i-1].angleRad * 180) / math.pi
      nodes[i-1].globAngleDeg = (math.acos(nodes[i-1].n.x ) * 180) / math.pi -- the angle with the x-axis, needed later
      -- fix nodes facing -y direction
      if nodes[i-1].n.y < 0 then
        nodes[i-1].globAngleDeg = 360 - nodes[i-1].globAngleDeg
      end
      -- determine dot product between first vector and 90° rotated second vector to figure out the bend.
      local lrDet = nodes[i-2].n.x * (-nodes[i-1].n.y) + nodes[i-2].n.y * nodes[i-1].n.x


      if lrDet < params.path.minDotForCurve and lrDet > -params.path.minDotForCurve and nodes[i-1].n.x * nodes[i-2].n.x + nodes[i-1].n.y * nodes[i-2].n.y > 0 then
         -- handle straight sections. set the bend to the opposite of the bend before, so we get slaloms in straight parts
        nodes[i-1].straight = true
        nodes[i-1].left = not nodes[i-2].left
        nodes[i-1].right = not nodes[i-2].right
        if nodes[i-2].flipped then
          nodes[i-1].left =  nodes[i-2].left
          nodes[i-1].right = nodes[i-2].right
        end
      elseif lrDet > 0 then
        nodes[i-1].right =  true
      elseif lrDet < 0 then
        nodes[i-1].left = true
      end

      if nodes[i-1].straight then
        --dump(nodes[i-1])
        --dump(lrDet)
        --dump(nodes[i-1].n)
        --dump(nodes[i-2].n)
       if math.random() < params.path.gateChance then
          nodes[i-1].radius = 0
          nodes[i-1].gate = true
          params.path.gateChance = params.path.gateBaseChance
        else
          params.path.gateChance = params.path.gateChance + params.path.gateIncChance
        end
      end

      if nodes[i-1].force and nodes[i-1].force.gate ~= nil then
       -- dump("Forced Gate to "..nodes[i-1].force.gate)
        nodes[i-1].radius = 0
        nodes[i-1].gate = nodes[i-1].force.gate
      end

      -- chance to flip the node, making the path not go around "outside", but "inside", and loop around the node once, only if the angle between nodes is sufficient
      if det > params.path.loopMinDot then
        if math.random() < params.path.loopChance then
          nodes[i-1].flipped = true
          params.path.loopChance = params.path.loopBaseChance
        else
          params.path.loopChance = params.path.loopChance + params.path.loopIncChance
        end
      end

      if nodes[i-1].force and nodes[i-1].force.flip ~= nil then
        --dump("Forced Flip to "..nodes[i-1].force.flip)
        nodes[i-1].flipped = nodes[i-1].force.flip
      end

    end
  end
  return nodes
end

-- determines the in and out angles for circles.
local function determineInOutAngle(nodes)
  for i,n in ipairs(nodes) do
    -- for all pairs of consecutive nodes:
    if i > 1 then

      -- check if the path will go around the same sides of the nodes.
      local same = nodes[i].left and nodes[i-1].left or nodes[i].right and nodes[i-1].right
      if nodes[i].flipped then
        same = not same
      end
      if nodes[i-1].flipped then
        same = not same
      end

      -- depending on that, calculate belt problem with crossing (oxo) or belt problem without crossing (o=o)
      if same then
        nodes[i].pass.sameAsBefore = true
        nodes[i-1].pass.outAngleRad = (  math.acos((nodes[i-1].radius - nodes[i].radius)/ nodes[i-1].v.length ))
        nodes[i].pass.inAngleRad =  math.pi - math.acos((nodes[i-1].radius - nodes[i].radius)/ nodes[i-1].v.length )
      else
        nodes[i].pass.sameAsBefore = false
        nodes[i-1].pass.outAngleRad =  math.acos((nodes[i-1].radius + nodes[i].radius)/ nodes[i-1].v.length )
        nodes[i].pass.inAngleRad =  math.acos((nodes[i-1].radius + nodes[i].radius)/ nodes[i-1].v.length )
      end
    end
  end

  --dump(nodes)
  return nodes
end

-- gets all the nodes needed to create a road around the nodes.
local function getPathRoadNodes(nodes)
  for i,n in ipairs(nodes) do

    local points = {}
    -- this is neither the last nor the first node, having an incoming as well as an outgoing angle. This lets us determine an arc going around the node.
    if nodes[i].pass.outAngleRad and nodes[i].pass.inAngleRad then
      local radius = nodes[i].radius
      if radius == 0 then
        points[#points+1] = {
          x = nodes[i].p.x ,
          y = nodes[i].p.y
        }
      else
        local arcAngleRad = 2*math.pi - ( nodes[i].pass.outAngleRad + nodes[i].pass.inAngleRad + nodes[i].angleRad)
        if nodes[i].flipped then
          arcAngleRad = 2*math.pi - ( nodes[i].pass.outAngleRad + nodes[i].pass.inAngleRad - nodes[i].angleRad)
        end

        local steps = math.ceil((math.abs(arcAngleRad) / (params.path.curveStepMaxRad) ) * math.max(1, radius / 3))
        nodes[i].pass.arcAngleRad = arcAngleRad
        --steps = 2
        --dump(steps)

        for j = 0, steps do

          local angleRad = nodes[i].pass.outAngleRad + arcAngleRad - (arcAngleRad * j/steps)
          if nodes[i].flipped then
            angleRad = -nodes[i].pass.outAngleRad - arcAngleRad + (arcAngleRad * j/steps)
          end
          if nodes[i].left then
            angleRad = -angleRad
          end


          points[#points+1] = {
            x = nodes[i].p.x + (nodes[i].n.x * math.cos(angleRad) - nodes[i].n.y * math.sin(angleRad)) * radius,
            y = nodes[i].p.y + (nodes[i].n.x * math.sin(angleRad) + nodes[i].n.y * math.cos(angleRad)) * radius
          }

        end
      end

    -- this is the first node, only having an outgoing angle, and thus only one node.
    elseif nodes[i].pass.outAngleRad then
        points[#points+1] = {
          x = nodes[i].p.x ,
          y = nodes[i].p.y
        }

    -- this is the last node, only having and ingoign angle and thus only one node.
    elseif nodes[i].pass.inAngleRad then
        points[#points+1] = {
          x = nodes[i].p.x ,
          y = nodes[i].p.y
        }
    else
      -- this shouldnt happen.
      log('E', logTag, "skipped a node! This shouldnt happen")
    end

  nodes[i].points = points

  end
  return nodes
end

---------------------------------------------------------------------------------
--                                                                             --
--  This is the Part where the game objects are being created.                 --
--                                                                             --
---------------------------------------------------------------------------------


-- actually creates the road object.
local function createWindingRoad(nodes)
  local mat = {"road_asphalt_2lane","road_orange_markings"}
  for i,m in ipairs(mat) do
    local path = {}
    --extract nodes from nodes.
    for i,n in ipairs(nodes) do
      if #n.points == 0 then
        --dump("MIssing Points?")
      end
      if params.path.closed and (i ~= 1 and i ~= #nodes) or not params.path.closed then
        for _,e in ipairs(n.points) do
          path[#path+1] = e
        end
      end
    end

    local roadTS = [[
          GymkhanaArena.add(new DecalRoad() {
          Material = "]]..m..[[";
          textureLength = "]]..(5*i)..[[";
          breakAngle = "1";
          renderPriority = "]]..(5-i)..[[";
          zBias = "-1";
          startEndFade = "0 0";
          position = "0 0 0";
          rotation = "1 0 0 0";
          scale = "1 1 1";
          canSave = "1";
          canSaveDynamicFields = "1";
          drivability = "-1";
          improvedSpline = "1";
          startTangent = "0";
          endTangent = "0";
          detail = "1";
          smoothness = "0.01";
      ]]

    if params.path.closed then
      roadTS = roadTS .. [[
          looped = "1";
      ]]
    end

    local ret = ''
    for _,p in ipairs(path) do
      local pos = M.getPosition(p.x,p.y,0)
        ret = ret..'Node="'..pos.x..' '..pos.y..' ' .. pos.z.. ' '
        if p.w ~= nil then
            ret = ret .. p.w
        else
            ret = ret .. '3'
        end
        ret = ret .. '"; '
    end
    roadTS = roadTS .. ret
    roadTS = roadTS..'});';

    TorqueScript.eval(roadTS)
  end
end

-- decorates the start and finish nodes.
local function decorateStartAndFinish(nodes)
  if params.path.closed then
    return
  end

  local spots = {
    {
     p1 = nodes[1].points[1],
     p2 = nodes[2].points[1]
    },
    {
      p1 = nodes[#nodes].points[1],
      p2 = nodes[#nodes-1].points[#(nodes[#nodes-1].points)]
    }
  }



  for i,spot in ipairs(spots) do
    local nv = {
      x = spot.p2.x - spot.p1.x,
      y = spot.p2.y - spot.p1.y
    }
    local length = M.dist(0,0,nv.x,nv.y)
    nv.x = nv.x / length
    nv.y = nv.y / length
    --dump(nv)
    local angle = (math.acos(nv.x) * 180) / math.pi
    if nv.y < 0 then
      angle = 360 - angle
    end

    local off = 0
      M.makePylon( {spot.p1.x + 2.5*nv.y - off*nv.x, spot.p1.y - 2.5*nv.x -off*nv.y, 0}, {1,1,1}, -angle+180)
      M.makePylon( {spot.p1.x - 2.5*nv.y - off*nv.x, spot.p1.y + 2.5*nv.x -off*nv.y, 0}, {1,1,1}, -angle)
      off = 1.6
      M.makePylon( {spot.p1.x + 2.5*nv.y - off*nv.x, spot.p1.y - 2.5*nv.x -off*nv.y, 0}, {1,1,1}, -angle+180)
      M.makePylon( {spot.p1.x - 2.5*nv.y - off*nv.x, spot.p1.y + 2.5*nv.x -off*nv.y, 0}, {1,1,1}, -angle)
      off = -1.6
      M.makePylon( {spot.p1.x + 2.5*nv.y - off*nv.x, spot.p1.y - 2.5*nv.x -off*nv.y, 0}, {1,1,1}, -angle+180)
      M.makePylon( {spot.p1.x - 2.5*nv.y - off*nv.x, spot.p1.y + 2.5*nv.x -off*nv.y, 0}, {1,1,1}, -angle)

      M.makeGate({spot.p1.x , spot.p1.y , 0}, -angle+90)

    if i == 1 then
    --  M.makePylon( {spot.p1.x + 2.5*nv.y + 2.5*nv.x, spot.p1.y - 2.5*nv.x + 2.5*nv.y, 0}, {0.25, 0.25, 1.5},-angle)
     -- M.makePylon( {spot.p1.x - 2.5*nv.y + 2.5*nv.x, spot.p1.y + 2.5*nv.x + 2.5*nv.y, 0}, {0.25, 0.25, 1.5}, -angle)
      nodes[1].gateDir = nv
    else
      --M.makePylon( {spot.p1.x + 2.5*nv.y + 2.5*nv.x, spot.p1.y - 2.5*nv.x + 2.5*nv.y, 0}, {0.25, 0.25, 0.65},-angle)
     -- M.makePylon( {spot.p1.x - 2.5*nv.y + 2.5*nv.x, spot.p1.y + 2.5*nv.x + 2.5*nv.y, 0}, {0.25, 0.25, 0.65}, -angle)
      nodes[#nodes].gateDir = {x = -nv.x, y = -nv.y}
    end
  end
end

-- create pylons, like circles and gates.
local function createPylons(nodes)
 for i,n in ipairs(nodes) do
    if params.path.closed and i ~= 1 and i ~= #nodes or not params.path.closed then
    -- this is neither the last nor the first node, having an incoming as well as an outgoing angle. This lets us determine an arc going around the node.
      if nodes[i].pass.outAngleRad and nodes[i].pass.inAngleRad then

        if not nodes[i].gate then
          local skin = 'L'
          if nodes[i].right and not nodes[i].flipped or nodes[i].left and nodes[i].flipped then
            skin = 'R'
          end

          if nodes[i].radius >= params.path.pylonRadiusThreshold then
           -- create regular circle
           local radius = nodes[i].radius - 2
           local steps = radius *4-1
           local mod = 5
           if nodes[i].pass.arcAngleRad < 1 then
             mod = 10000
           elseif nodes[i].pass.arcAngleRad < 2 then
             mod = 5
           elseif nodes[i].pass.arcAngleRad < 3 then
             mod = 4
           elseif nodes[i].pass.arcAngleRad < 4 then
             mod = 3
           elseif nodes[i].pass.arcAngleRad < 5 then
             mod = 2
           else
             mod = 1
           end
           --dump(nodes[i].pass.arcAngleRad)
           if steps < 8 then steps = 8 end
           steps = math.ceil(steps)
            for j = 0, steps do
              local angleRad = (math.pi / (steps/2)) * j
              local skn = ''

              --dump(nodes[i].pass.arcAngleRad)
              if j % mod == 0 then
                if skin == 'R' then
                  skn = '_L'
                else
                  skn = '_R'
                end
              end
              M.makePylon(
                {nodes[i].p.x + (nodes[i].n.x * math.cos(angleRad) - nodes[i].n.y * math.sin(angleRad)) * radius,
                nodes[i].p.y + (nodes[i].n.x * math.sin(angleRad) + nodes[i].n.y * math.cos(angleRad)) * radius
                ,0}, {1,1,1},
                -nodes[i].globAngleDeg - j * (360/steps) + 90, skn)
            end

          elseif nodes[i].radius < params.path.pylonRadiusThreshold then
            -- create small dot
            if nodes[i].flipped or nodes[i].angleDeg < 120 then
              M.makeBarrel({nodes[i].p.x, nodes[i].p.y, 0}, nodes[i-1].globAngleDeg, skin)
              if nodes[i].radius > params.path.minRadius + 0.5 then
                M.makeConcreteRing({nodes[i].p.x, nodes[i].p.y, 0}, nodes[i].radius-1.5)
              end
            else
              M.makeConcreteRing({nodes[i].p.x, nodes[i].p.y, 0}, nodes[i].radius-1.5)
            end
            -- M.makePylon(
            --     {nodes[i].p.x, nodes[i].p.y, 0}, {.9,.9, params.decoration.pointsHeight * 1.5}, 0)
            -- M.makePylon(
            --   {nodes[i].p.x, nodes[i].p.y, 0}, {.95,.95, params.decoration.pointsHeight * 1}, 45)
            -- M.makePylon(
            --   {nodes[i].p.x, nodes[i].p.y, 0}, {1,1, params.decoration.pointsHeight * .5}, 67.5)
            -- M.makePylon(
            --   {nodes[i].p.x, nodes[i].p.y, 0}, {1,1, params.decoration.pointsHeight * .5}, 22.5)

          end
        elseif nodes[i].gate or nodes[i].radius == 0 then
          -- create gate

          local current = {x = nodes[i].points[1].x, y = nodes[i].points[1].y}
          local plus = { x = nodes[i+1].points[1].x, y= nodes[i+1].points[1].y }
          local minus = {x = nodes[i-1].points[#nodes[i-1].points].x, y = nodes[i-1].points[#nodes[i-1].points].y}

          local len = M.dist(current.x,current.y,plus.x,plus.y)
          plus.x = (plus.x - current.x) / len
          plus.y = (plus.y - current.y)/ len

          len = M.dist(current.x,current.y,minus.x,minus.y)
          minus.x = (minus.x - current.x) / len
          minus.y = (minus.y - current.y) / len

          local inside = {
            x = plus.x + minus.x ,
            y = plus.y + minus.y
                    }
          len = M.dist(0,0,inside.x,inside.y)
          if len ~= 0 then
            inside.x = inside.x / len
            inside.y = inside.y / len
          else
            inside.x = -(plus.y )
            inside.y = (plus.x )
            len = M.dist(0,0,inside.x,inside.y)
            inside.x = inside.x / len
            inside.y = inside.y / len
          end

          local fwd = {x=-inside.y,y=inside.x}
          if fwd.x*plus.x + fwd.y*plus.y < 0 then
            fwd.x = -fwd.x
            fwd.y = -fwd.y
          end



          local angle = (math.acos(inside.x) * 180) / math.pi
          if inside.y < 0 then
            angle = 360 - angle
          end
          nodes[i].gateDir = fwd
        --  M.makePylon(
        --       {nodes[i].p.x + inside.x * params.decoration.gateWidth/2,
        --       nodes[i].p.y + inside.y * params.decoration.gateWidth/2
        --       ,0}, params.decoration.gateHeight,
        --       -angle )
        --   M.makePylon(
        --       {nodes[i].p.x - inside.x * params.decoration.gateWidth/2,
        --       nodes[i].p.y - inside.y * params.decoration.gateWidth/2
        --       ,0}, params.decoration.gateHeight,
        --       -angle )
        --  M.makePylon(
        --       {nodes[i].p.x ,
        --       nodes[i].p.y
        --       ,params.decoration.gateHeight}, {params.decoration.gateWidth + .33,.33,.33},
        --       -angle )

          M.makeGate( {nodes[i].p.x,nodes[i].p.y,0} ,  -angle)



        end
      end
    end
  end
end

-- creates the waypoint positions, angles etc.
local function createWaypointsForScenario(nodes)
  local scenario = scenario_scenarios.getScenario()

  scenario.lapConfig = {}
  scenario.nodes = {}
  for i,n in ipairs(nodes) do
    if params.path.closed and (i ~= 1 and i ~= #nodes) or not params.path.closed then
      local pIndex = math.ceil(#(n.points)/2)
      --dump(pIndex)
      scenario.nodes['gym_'..i] = {}
      local off = {x = n.points[pIndex].x - n.p.x, y = n.points[pIndex].y - n.p.y}
      local offLen = M.dist(0,0,off.x,off.y)
      if offLen == 0 then
        off.x = 0
        off.y = 0
      else
        off.x = off.x/offLen
        off.y = off.y/offLen
      end
      local pos = M.getPosition(n.points[pIndex].x + (off.x)*3, n.points[pIndex].y  +(off.y)*3,0)
      scenario.nodes['gym_'..i].pos = vec3(pos.x,pos.y,pos.z)
      scenario.nodes['gym_'..i].radius = 7
      if n.radius >= params.path.minRadius and n.radius < 4 then
        scenario.nodes['gym_'..i].radius = n.radius +3
      end
      if n.gate or n.radius == 0 then
        scenario.nodes['gym_'..i].radius = 2.5
      end

      scenario.lapConfig[#scenario.lapConfig+1] = 'gym_'..i

      local nv = {}
      if n.gateDir then
        nv = {x = n.gateDir.x, y = n.gateDir.y}
      else
        nv = {
          x = n.points[pIndex].x - n.p.x,
          y = n.points[pIndex].y - n.p.y
        }
        local length = M.dist(0,0,nv.x,nv.y)

        nv.x = (n.points[pIndex].y - n.p.y) / length
        nv.y = -(n.points[pIndex].x - n.p.x) / length
        if n.left then
          nv.x = -nv.x
          nv.y = -nv.y
        end

        if n.flipped then
          nv.x = -nv.x
          nv.y = -nv.y
        end
      end
      -- manual rotation of nv based on params.rotation
      local nvRot = {
          x = (nv.x * math.cos(params.rootAngleRad) - nv.y * math.sin(params.rootAngleRad)) ,
           y = (nv.x * math.sin(params.rootAngleRad) + nv.y * math.cos(params.rootAngleRad)),
      }

      scenario.nodes['gym_'..i].rot = vec3(nvRot.x,nvRot.y,0)


      local checkPoint = createObject('BeamNGWaypoint')
      checkPoint:setPosition(vec3(pos.x,pos.y,pos.z))
      checkPoint.scale = vec3(scenario.nodes['gym_'..i].radius,scenario.nodes['gym_'..i].radius,scenario.nodes['gym_'..i].radius)
      local quat = quatFromEuler(0,0,-math.atan2(nvRot.y, nvRot.x)):toTorqueQuat()
      checkPoint:setField('rotation', 0, quat.x .. ' ' ..quat.y..' '..quat.z..' '..quat.w)
      checkPoint:setField('directionalWaypoint', 0, '1')
      checkPoint:registerObject('gym_'..i)
      scenetree.GymkhanaArena:addObject(checkPoint)


    end
  end




  scenario.lapCount = params.path.lapCount or scenario.lapCount


  --dump(scenario.lapConfig)
  if params.moveVehicleIntoPosition then
    local pos = {}
    local rot = {}
    if not params.vehiclePlacement or params.vehiclePlacement == {} then

      if params.rollingStart then
        pos = scenario.nodes[scenario.lapConfig[#scenario.lapConfig]].pos
        rot = scenario.nodes[scenario.lapConfig[#scenario.lapConfig]].rot
      else
        pos = scenario.nodes[scenario.lapConfig[1]].pos
        rot = scenario.nodes[scenario.lapConfig[1]].rot
      end
    else
      pos = M.getPosition(params.vehiclePlacement.pos.x, params.vehiclePlacement.pos.y, params.vehiclePlacement.pos.z)
      rot = M.getPosition(params.vehiclePlacement.dir.x, params.vehiclePlacement.dir.y, params.vehiclePlacement.dir.z) -- since dir is a normalized vector, we can simply rotate it like one.
      rot.x = rot.x - params.rootX
      rot.y = rot.y - params.rootY
      rot.z = rot.z - params.rootZ
    end

    -- shift all cps forward
    local newLapConfig = {}
    for i,l in ipairs(scenario.lapConfig) do
      newLapConfig[(i+#scenario.lapConfig-2)%#scenario.lapConfig +1] = l
    end

    scenario.lapConfig = newLapConfig

    pos = vec3(pos.x,pos.y,pos.z + .5)
    pos = pos
    rot = quatFromDir(vec3(-rot.x,-rot.y))
    scenario.startingTransforms['scenario_player0'].pos = pos
    scenario.startingTransforms['scenario_player0'].rot = rot
    vehicleSetPositionRotation(scenario.vehicleNameToId['scenario_player0'], pos.x, pos.y, pos.z,  rot.x, rot.y, rot.z, rot.w)
  end


  if params.rollingStart then
    --dump("is Rolling Start")
    scenario.rollingStart = true
    scenario.startTimerCheckpoint = scenario.lapConfig[#scenario.lapConfig]
    scenario.lapConfig[#scenario.lapConfig] = nil
  else
    if not params.path.closed then
       scenario.lapConfig[#scenario.lapConfig] = nil
    end
    --dump("no rolling start")
    scenario.rollingStart = false
    scenario.startTimerCheckpoint = nil
  end

 --dump(scenario.lapConfig)
  scenario.initialLapConfig = deepcopy(scenario.lapConfig)
  scenario.BranchLapConfig = deepcopy(scenario.lapConfig)
end

---------------------------------------------------------------------------------
--                                                                             --
--  This is the Part where all the utility functions live.                     --
--                                                                             --
---------------------------------------------------------------------------------


-- returns the distance from a/b to x/y.
local function dist(a,b,x,y)
  return math.sqrt((a-x)*(a-x) + (b-y)*(b-y))
end

-- makes a pylon (Cube) with parameters.
local function makePylon(pos, size, rot, skin)
  if not size then
    size = {0.33, 0.33, 1}
  elseif type(size) ~= "table" then
    size = {0.33, 0.33, size}
  end
  rot = rot or 0
  skin = skin or ''
  local poss = M.getPosition(pos[1],pos[2],pos[3])
  TorqueScript.eval([[
   GymkhanaArena.add(new TSStatic() {
         shapeName = "levels/driver_training/art/shapes/race/barriersegment]]..skin..[[.dae";
         meshCulling = "0";
         originSort = "0";
         useInstanceRenderData = "0";
         instanceColor = "White";
         collisionType = "Collision Mesh";
         decalType = "Collision Mesh";
         prebuildCollisionData = "0";
         renderNormals = "0";
         forceDetail = "-1";
         position = "]] .. ( poss.x) .. [[ ]] .. (poss.y) .. [[ ]] .. (poss.z) .. [[";
         rotation = "0 0 1 ]]..M.getRotationDeg(rot)..[[";
         scale = "]]..size[1].. " " .. size[2] .. " " .. size[3]..[[";
         mode = "Ignore";
         canSaveDynamicFields = "1";
         allowPlayerStep = "1";
      });

  ]])
end

local function makeGate(pos, rot)
  rot = rot or 0
  local poss = M.getPosition(pos[1],pos[2],pos[3])
  TorqueScript.eval([[
   GymkhanaArena.add(new TSStatic() {
         shapeName = "levels/driver_training/art/shapes/race/gate.dae";
         meshCulling = "0";
         originSort = "0";
         useInstanceRenderData = "0";
         instanceColor = "White";
         collisionType = "Collision Mesh";
         decalType = "Collision Mesh";
         prebuildCollisionData = "0";
         renderNormals = "0";
         forceDetail = "-1";
         position = "]] .. ( poss.x) .. [[ ]] .. (poss.y) .. [[ ]] .. (poss.z) .. [[";
         rotation = "0 0 1 ]]..M.getRotationDeg(rot)..[[";
         scale = "1 1 1";
         mode = "Ignore";
         canSaveDynamicFields = "1";
         allowPlayerStep = "1";
      });

  ]])
end

local function makeConcreteRing(pos, radius)
  --dump("radius = "..radius)
  --radius = radius * 0.66
  if radius < 1 then radius = 1 end
  local poss = M.getPosition(pos[1],pos[2],pos[3])
  TorqueScript.eval([[
   GymkhanaArena.add(new TSStatic() {
         shapeName = "levels/driver_training/art/shapes/race/ring_2m.dae";
         meshCulling = "0";
         originSort = "0";
         useInstanceRenderData = "0";
         instanceColor = "White";
         collisionType = "Collision Mesh";
         decalType = "Collision Mesh";
         prebuildCollisionData = "0";
         renderNormals = "0";
         forceDetail = "-1";
         position = "]] .. ( poss.x) .. [[ ]] .. (poss.y) .. [[ ]] .. (poss.z) .. [[";
         rotation = "0 0 1 0";
         scale = "]]..radius .." " .. radius.." "..(0.84+(math.random()+radius)/10 ).. [[";
         mode = "Ignore";
         canSaveDynamicFields = "1";
         allowPlayerStep = "1";
      });

  ]])
end

local function makeBarrel(pos, rot, skin)
 rot = rot or 0
 rot = rot+180
   local poss = M.getPosition(pos[1],pos[2],pos[3])
  TorqueScript.eval([[
   GymkhanaArena.add(new TSStatic() {
         shapeName = "levels/driver_training/art/shapes/race/barrelmarker_]]..skin..[[.dae";
         meshCulling = "0";
         originSort = "0";
         useInstanceRenderData = "0";
         instanceColor = "White";
         collisionType = "Collision Mesh";
         decalType = "Collision Mesh";
         prebuildCollisionData = "0";
         renderNormals = "0";
         forceDetail = "-1";
         position = "]] .. ( poss.x) .. [[ ]] .. (poss.y) .. [[ ]] .. (poss.z) .. [[";
         rotation = "0 0 -1 ]]..M.getRotationDeg(rot)..[[";
         scale = "1 1 1";
         mode = "Ignore";
         canSaveDynamicFields = "1";
         allowPlayerStep = "1";
      });

  ]])
end

-- this function transforms local angle in rad to global angle in deg.
local function getRotationDeg(dd)
      return  dd - (params.rootAngleRad*180) / math.pi
end
-- this function transforms local position to global position.
local function getPosition(xx,yy,zz)
      return
        {x = params.rootX + (xx * math.cos(params.rootAngleRad) - yy * math.sin(params.rootAngleRad)) ,
         y = params.rootY + (xx * math.sin(params.rootAngleRad) + yy * math.cos(params.rootAngleRad)),
         z = params.rootZ + zz }
end

-- stores the default parameters
M.getDefaultParams = getDefaultParams

-- main call hierachy
M.makeGymkhana = makeGymkhana
  M.checkParams = checkParams
  M.makeBaseNodePositions = makeBaseNodePositions

  M.makePath = makePath
    M.currentEdgeNotOK = currentEdgeNotOK
    M.edgeCreatesSplitGraph = edgeCreatesSplitGraph
    M.isInList = isInList
  M.createWindingPath = createWindingPath
    M.getBaseInformationFromPath = getBaseInformationFromPath
    M.determineInOutAngle = determineInOutAngle
    M.getPathRoadNodes = getPathRoadNodes
  M.createWindingRoad = createWindingRoad
  M.decorateStartAndFinish = decorateStartAndFinish
  M.createPylons = createPylons
  M.createWaypointsForScenario = createWaypointsForScenario

-- utility functions
M.getRotationDeg = getRotationDeg
M.getPosition = getPosition
M.makePylon = makePylon
M.makeGate = makeGate
M.makeConcreteRing = makeConcreteRing
M.makeBarrel = makeBarrel
M.dist = dist
M.reGenerate = reGenerate

M.getSeed = function() return params and params.seed or nil end


------------------------------------------------------------------------------------------


local wordList = {'About','Above','Abuse','Actor','Acute','Admit','Adopt','Adult','After','Again','Agent','Agree','Ahead','Alarm','Album','Alert','Alike','Alive','Allow','Alone','Along','Alter','Among','Anger','Angle','Angry','Apart','Apple','Apply','Arena','Argue','Arise','Array','Aside','Asset','Audio','Audit','Avoid','Award','Aware','Badly','Baker','Bases','Basic','Basis','Beach','Began','Begin','Begun','Being','Below','Bench','Billy','Birth','Black','Blame','Blind','Block','Blood','Board','Boost','Booth','Bound','Brain','Brand','Bread','Break','Breed','Brief','Bring','Broad','Broke','Brown','Build','Built','Buyer','Cable','Calif','Carry','Catch','Cause','Chain','Chair','Chart','Chase','Cheap','Check','Chest','Chief','Child','China','Chose','Civil','Claim','Class','Clean','Clear','Click','Clock','Close','Coach','Coast','Could','Count','Court','Cover','Craft','Crash','Cream','Crime','Cross','Crowd','Crown','Curve','Cycle','Daily','Dance','Dated','Dealt','Death','Debut','Delay','Depth','Doing','Doubt','Dozen','Draft','Drama','Drawn','Dream','Dress','Drill','Drink','Drive','Drove','Dying','Eager','Early','Earth','Eight','Elite','Empty','Enemy','Enjoy','Enter','Entry','Equal','Error','Event','Every','Exact','Exist','Extra','Faith','False','Fault','Fiber','Field','Fifth','Fifty','Fight','Final','First','Fixed','Flash','Fleet','Floor','Fluid','Focus','Force','Forth','Forty','Forum','Found','Frame','Frank','Fraud','Fresh','Front','Fruit','Fully','Funny','Giant','Given','Glass','Globe','Going','Grace','Grade','Grand','Grant','Grass','Great','Green','Gross','Group','Grown','Guard','Guess','Guest','Guide','Happy','Harry','Heart','Heavy','Hence','Henry','Horse','Hotel','House','Human','Ideal','Image','Index','Inner','Input','Issue','Japan','Jimmy','Joint','Jones','Judge','Known','Label','Large','Laser','Later','Laugh','Layer','Learn','Lease','Least','Leave','Legal','Level','Lewis','Light','Limit','Links','Lives','Local','Logic','Loose','Lower','Lucky','Lunch','Lying','Magic','Major','Maker','March','Maria','Match','Maybe','Mayor','Meant','Media','Metal','Might','Minor','Minus','Mixed','Model','Money','Month','Moral','Motor','Mount','Mouse','Mouth','Movie','Music','Needs','Never','Newly','Night','Noise','North','Noted','Novel','Nurse','Occur','Ocean','Offer','Often','Order','Other','Ought','Paint','Panel','Paper','Party','Peace','Peter','Phase','Phone','Photo','Piece','Pilot','Pitch','Place','Plain','Plane','Plant','Plate','Point','Pound','Power','Press','Price','Pride','Prime','Print','Prior','Prize','Proof','Proud','Prove','Queen','Quick','Quiet','Quite','Radio','Raise','Range','Rapid','Ratio','Reach','Ready','Refer','Right','Rival','River','Robin','Roger','Roman','Rough','Round','Route','Royal','Rural','Scale','Scene','Scope','Score','Sense','Serve','Seven','Shall','Shape','Share','Sharp','Sheet','Shelf','Shell','Shift','Shirt','Shock','Shoot','Short','Shown','Sight','Since','Sixth','Sixty','Sized','Skill','Sleep','Slide','Small','Smart','Smile','Smith','Smoke','Solid','Solve','Sorry','Sound','South','Space','Spare','Speak','Speed','Spend','Spent','Split','Spoke','Sport','Staff','Stage','Stake','Stand','Start','State','Steam','Steel','Stick','Still','Stock','Stone','Stood','Store','Storm','Story','Strip','Stuck','Study','Stuff','Style','Sugar','Suite','Super','Sweet','Table','Taken','Taste','Taxes','Teach','Teeth','Terry','Texas','Thank','Theft','Their','Theme','There','These','Thick','Thing','Think','Third','Those','Three','Threw','Throw','Tight','Times','Tired','Title','Today','Topic','Total','Touch','Tough','Tower','Track','Trade','Train','Treat','Trend','Trial','Tried','Tries','Truck','Truly','Trust','Truth','Twice','Under','Undue','Union','Unity','Until','Upper','Upset','Urban','Usage','Usual','Valid','Value','Video','Virus','Visit','Vital','Voice','Waste','Watch','Water','Wheel','Where','Which','While','White','Whole','Whose','Woman','Women','World','Worry','Worse','Worst','Worth','Would','Wound','Write','Wrong','Wrote','Yield','Young','Youth'}

local function wordsToInt(word)

  local ret = 0
  local i = 0
  while i*5 < #word do
    local w = string.sub(word, 1+ i*5, 5+i*5)

    local wordIndex = 1
    while wordIndex < #wordList do
      if wordList[wordIndex] == w then
        ret = ret + (-1 + wordIndex) * math.pow(#wordList,(i))
        --dump("Add" .. (-1 + wordIndex) * math.pow(#wordList,(i)))

        wordIndex = #wordList
      end
      wordIndex = wordIndex+1
    end

    i = i+1
  end

  return ret
end

local function intToWords(int)
  local ret = ''
  while int > 0 do
    --dump((int%(#wordList))+1)
    ret = ret .. wordList[(int%(#wordList))+1]
    int = math.floor(int / #wordList)
  end
  return ret
end

M.wordsToInt = wordsToInt
M.intToWords = intToWords

return M
