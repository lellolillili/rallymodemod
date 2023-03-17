-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

-- this function calculates the position of the keypoints. it does so by dividing a rectangle into ever smaller rectangles.
local function getGraph(params)

  local rectangles = {}
  for _,r in ipairs(params.startingRects) do
    if not r.noSplit then
      rectangles[#rectangles+1] = {
      x = r.x,
      y = r.y,
      width = r.width,
      height = r.height,
      force = r.force
    }
    end
  end

  local stop = false
  while  #rectangles < params.rectModeParams.numNodes and not stop do

    local canCut = false
    local currentRect
    local currentIndex = 1
    local cutVertically
    while not canCut do
      canCut = true
      if currentIndex > #rectangles then
        --log("E","RectangleGen","Can't split any more rects! stopping at ".. #rectangles .. " instead of "..params.rectModeParams.numNodes )
        stop = true
      end
      if not stop then
        currentRect = rectangles[currentIndex]
        -- this determines wether to cut the current rect vertically or not
        cutVertically = params.rectModeParams.vertSplitFunction(currentRect.width, currentRect.height)
        if not cutVertically and currentRect.height/2 < params.rectModeParams.minYDist or cutVertically and currentRect.width/2 < params.rectModeParams.minXDist then
          canCut = false
          currentIndex = currentIndex+1
        end
      end
    end
    if not stop then
      local cutValue = params.rectModeParams.cutValueFunction()
      local r1, r2 -- the new rectangles to be created.

      if cutVertically then
        cutValue = (0.5 * (params.rectModeParams.minXDist / currentRect.width)) + (1-(params.rectModeParams.minXDist / currentRect.width)) * cutValue

        r1 = {
          x = currentRect.x,
          y = currentRect.y,
          width = currentRect.width * cutValue,
          height = currentRect.height,
          force = currentRect.force
        }
        r2 = {
          x = currentRect.x + r1.width,
          y = currentRect.y,
          width = currentRect.width - r1.width,
          height = currentRect.height,
          force = currentRect.force
        }
      else
        cutValue = (0.5 * (params.rectModeParams.minYDist / currentRect.height)) + (1-(params.rectModeParams.minYDist / currentRect.height)) * cutValue
        r1 = {
          x = currentRect.x,
          y = currentRect.y,
          width = currentRect.width,
          height = currentRect.height * cutValue,
          force = currentRect.force
        }
        r2 = {
          x = currentRect.x,
          y = currentRect.y + r1.height,
          width = currentRect.width,
          height = currentRect.height - r1.height,
          force = currentRect.force
        }
      end
      --add new rects, sort so the the biggest is first.
      rectangles[currentIndex] = r1
      rectangles[#rectangles+1] = r2
      table.sort(rectangles, function(a,b)
        return
        (a.width*a.height)
        >
        (b.width*b.height)
        end)

    end
  end


  for _,r in ipairs(params.startingRects) do
    if r.noSplit then
      rectangles[#rectangles+1] = {
      x = r.x,
      y = r.y,
      width = r.width,
      height = r.height,
      start = r.start,
      finish = r.finish,
      force = r.force
    }
    end
  end

  local graph = {
    nodes = {},
    start = nil,
    finish = nil
  }

  -- get neighbours
  for _,rect in ipairs(rectangles) do

    local neighbours = {}

    for i,other in ipairs(rectangles) do
      if other ~= rect then
        if math.abs((other.x + other.width) - rect.x)<.001 or math.abs(other.x - (rect.x + rect.width))<.001 then
          -- other is left or right of rect
          if other.y <= rect.y+rect.height and other.y+other.height >= rect.y then
            neighbours[#neighbours+1] = {
              dist = M.dist(rect.x + rect.width/2,rect.y + rect.height/2,other.x + other.width/2,other.y + other.height/2),
              rect = other,
              index = i
            }
          end
        elseif math.abs(other.y - (rect.y+rect.height))<.001 or math.abs((other.y+ other.height) - rect.y) < .001 then
          -- other is over or under rect
          if other.x <= rect.x+rect.width and other.x+other.width >= rect.x then
            neighbours[#neighbours+1] = {
              dist = M.dist(rect.x + rect.width/2,rect.y + rect.height/2,other.x + other.width/2,other.y + other.height/2),
              rect = other,
              index = i
            }
          end
        end
      end
    end

    rect.neighbours = neighbours
    -- one rect has no neighbours? not good. also, for closed tracks, one neighbour is also bad.
    if #rect.neighbours == 0 or (params.path.closed and #rect.neighbours == 1) then
      --return graph
    end
  end




  -- set center points and fill nodes from graph.
  for i,r in ipairs(rectangles) do

    r.x = r.x + r.width/2
    r.x = r.x - r.x%1
    r.y = r.y + r.height/2
    r.y = r.y - r.y%1
    r.name = "rect_"..i

    graph.nodes[i] = {x = r.x, y = r.y, neighbours = {}, name =r.name, force = r.force}
    if r.start then
      graph.start = graph.nodes[i]
    end
    if r.finish then
      graph.finish = graph.nodes[i]
    end
  end


  -- set neighbours for graph nodes.

  for i,r in ipairs(rectangles) do
    for _,n in ipairs(r.neighbours) do
      graph.nodes[i].neighbours[#graph.nodes[i].neighbours+1]= {index = n.index, dist = n.dist }
    end
  end
  -- determine closest neighbours and add to graph nodes.
  for i,r in ipairs(rectangles) do
    r.closestNeighbourDist = 1000000
    for _,n in ipairs(r.neighbours) do
      if n.dist < r.closestNeighbourDist then
        r.closestNeighbourDist = n.dist
      end
    end
    graph.nodes[i].closestNeighbourDist = r.closestNeighbourDist
  end
  return graph
end

local function dist(a,b,x,y)
  return math.sqrt((a-x)*(a-x) + (b-y)*(b-y))
end



M.dist = dist
M.getGraph = getGraph
return M