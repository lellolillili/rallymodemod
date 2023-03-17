-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- Description: A k-d tree for 3D points

--[[ Usage
  local kdTreeP3d = require('kdtreepoint3d')

  -- Initialize a new empty kdTree (the itemCount argument is optional for space pre-allocation of the items table)
  local kdT = kdTreeP3d.new(itemCount)

  -- Preload items: Populates the self.items table
  for (item in items) do
    kdT:preload(item_id, x, y, z)
  end

  -- Build the tree: creates the tree from the preloaded items, i.e. it populates the self.tree table
  kdT:build()

  -- Range Query: Get all items within a querry box
  Two ways to range query the items in the tree. Both query function return iterators (to be used in for .. do constructs)

  1) queries that are not nested
  for item_id in kdT:queryNotNested(query_xmin, query_ymin, query_xmax, query_ymax) do
    -- do something with item_id --
  end

  2) for nested queries (also works for non nested queries but will be slower and create garbage)
  for item1 in kdT:query(query_xmin, query_ymin, query_xmax, query_ymax) do -- for all the items in the tree that intersect the querry area
    for item2 in kdT:query(item1_xmin, item1_ymin, item1_xmax, item2_ymax) do
      -- do stuff --
    end
  end

  -- Point query: get point in tree closest to a query point
  local item_id, dist = kdT:findNearest(query_x, query_y, query_z)

  -- Importing/Exporting: Import an exported tree :P
  local exportedTree = kdT:export()
  local kdT2 = kdTreeP3d.new(itemCount)
  kdT2:import(exportedTree)
--]]

local min, max, floor, ceil, log10, huge = math.min, math.max, math.floor, math.ceil, math.log10, math.huge
local tableInsert, tableRemove = table.insert, table.remove

local M = {}
local kdTree = {}
kdTree.__index = kdTree

local axis4Next = {2, 3, 1}

local function lefSelect(items, dim, left, right)
  -- A linear time selection algorithm with in place array re-ordering.
  -- Adapted here from https://www.beamng.com/game/news/blog/a-faster-selection-algorithm/
  -- for use with multidiamensional data

  local dim_ = dim - 4
  local k = ceil((right + left) * 0.125) * 4
  local l, m, i, j = left, right, left, right
  while l < m do
    if items[k+dim_] < items[i+dim_] then
      items[k-3], items[i-3] = items[i-3], items[k-3]
      items[k-2], items[i-2] = items[i-2], items[k-2]
      items[k-1], items[i-1] = items[i-1], items[k-1]
      items[k], items[i] = items[i], items[k]
    end
    if items[j+dim_] < items[i+dim_] then
      items[j-3], items[i-3] = items[i-3], items[j-3]
      items[j-2], items[i-2] = items[i-2], items[j-2]
      items[j-1], items[i-1] = items[i-1], items[j-1]
      items[j], items[i] = items[i], items[j]
    end
    if items[j+dim_] < items[k+dim_] then
      items[j-3], items[k-3] = items[k-3], items[j-3]
      items[j-2], items[k-2] = items[k-2], items[j-2]
      items[j-1], items[k-1] = items[k-1], items[j-1]
      items[j], items[k] = items[k], items[j]
    end
    local pivotV = items[k+dim_]
    while j > k and i < k do
      repeat i = i + 4 until items[i+dim_] >= pivotV
      repeat j = j - 4 until items[j+dim_] <= pivotV
      items[i-3], items[j-3] = items[j-3], items[i-3]
      items[i-2], items[j-2] = items[j-2], items[i-2]
      items[i-1], items[j-1] = items[j-1], items[i-1]
      items[i], items[j] = items[j], items[i]
    end

    i, j = i + 4, j - 4
    if j < k then
      while items[i+dim_] < pivotV do i = i + 4 end
      l, j = i, m
    end
    if k < i then
      while pivotV < items[j+dim_] do j = j - 4 end
      m, i = j, l
    end
  end

  return k
end

local function new(itemCount)
  return setmetatable({
    tree = nil,
    nonLeafLimIdx = nil,
    items = table.new((itemCount or 0)*4, 0),
    itemCount = 0,
    queryArea = table.new(6, 0),
    stack = {},
    stackIdx = 0,
    curNodeIdx = 4,
    curAxis = 1,
    itmIdx = -1,
    qPoint = table.new(3, 0)
  }, kdTree)
end

function kdTree:export()
  return {
    tree = self.tree,
    nonLeafLimIdx = self.nonLeafLimIdx,
    items = self.items,
    itemCount = self.itemCount
  }
end

function kdTree:import(kdTreeData)
  self.tree = kdTreeData.tree
  self.nonLeafLimIdx = kdTreeData.nonLeafLimIdx
  self.items = kdTreeData.items
  self.itemCount = kdTreeData.itemCount
end

function kdTree:preLoad(id, x, y, z)
  local itemCount = self.itemCount + 4
  self.items[itemCount], self.items[itemCount-1], self.items[itemCount-2], self.items[itemCount-3] = id, z, y, x
  self.itemCount = itemCount
end

function kdTree:_build(axis, left, right, treeIdx)
  if treeIdx > self.nonLeafLimIdx then
    self.tree[treeIdx-3], self.tree[treeIdx-2], self.tree[treeIdx-1], self.tree[treeIdx] = huge, left, huge, right

    local xMin, yMin, zMin, xMax, yMax, zMax = huge, huge, huge, -huge, -huge, -huge
    for i = left, right, 4 do
      xMin, xMax = min(xMin, self.items[i-3]), max(xMax, self.items[i-3])
      yMin, yMax = min(yMin, self.items[i-2]), max(yMax, self.items[i-2])
      zMin, zMax = min(zMin, self.items[i-1]), max(zMax, self.items[i-1])
    end

    return xMin, yMin, zMin, xMax, yMax, zMax
  end

  local medianIdx = lefSelect(self.items, axis, left, right)

  local newAxis = axis4Next[axis]
  local lminX, lminY, lminZ, lmaxX, lmaxY, lmaxZ = self:_build(newAxis, left, medianIdx-4, 2*treeIdx)
  local rminX, rminY, rminZ, rmaxX, rmaxY, rmaxZ = self:_build(newAxis, medianIdx, right, 2*treeIdx+4)

  if axis == 1 then
    self.tree[treeIdx-3], self.tree[treeIdx-2], self.tree[treeIdx-1], self.tree[treeIdx] = lminX, lmaxX, rminX, rmaxX
    return lminX, min(lminY, rminY), min(lminZ, rminZ), rmaxX, max(lmaxY, rmaxY), max(lmaxZ, rmaxZ)
  elseif axis == 2 then
    self.tree[treeIdx-3], self.tree[treeIdx-2], self.tree[treeIdx-1], self.tree[treeIdx] = lminY, lmaxY, rminY, rmaxY
    return min(lminX, rminX), lminY, min(lminZ, rminZ), max(lmaxX, rmaxX), rmaxY, max(lmaxZ, rmaxZ)
  else
    self.tree[treeIdx-3], self.tree[treeIdx-2], self.tree[treeIdx-1], self.tree[treeIdx] = lminZ, lmaxZ, rminZ, rmaxZ
    return min(lminX, rminX), min(lminY, rminY), lminZ, max(lmaxX, rmaxX), max(lmaxY, rmaxY), rmaxZ
  end

  --return min(lminX, rminX), min(lminY, rminY), min(lminZ, rminZ), max(lmaxX, rmaxX), max(lmaxY, rmaxY), max(lmaxZ, rmaxZ)
end

function kdTree:build()
  self.itemCount = self.itemCount / 4
  local maxDepth = floor(log10(self.itemCount) / log10(2)) + 1 -- max depth that can accomodate all items while being full (root is depth 1)
  local treeNodeCount = 2 * ceil(self.itemCount / maxDepth) - 1 -- optimize node count so that tree depth ~ # of items in each node
  self.tree = table.new(4 * treeNodeCount, 0)
  self.nonLeafLimIdx = 4 * floor(treeNodeCount * 0.5)
  self:_build(1, 4, self.itemCount * 4, 4)
end

local function query_it(st)
  local tree, nonLeafLimIdx = st.tree, st.nonLeafLimIdx
  local queryArea = st.queryArea
  local stack = st.stack
  local nodeIdx, axis = st.curNodeIdx, st.curAxis

  if nodeIdx > nonLeafLimIdx then
    for i = max(tree[nodeIdx-2], st.itmIdx), tree[nodeIdx], 4 do
      if st.items[i-3] >= queryArea[1] and st.items[i-3] <= queryArea[4] and st.items[i-2] >= queryArea[2] and st.items[i-2] <= queryArea[5] and st.items[i-1] >= queryArea[3] and st.items[i-1] <= queryArea[6] then
        st.itmIdx = i + 4 -- update
        return st.items[i]
      end
    end
    axis = tableRemove(stack)
    nodeIdx = tableRemove(stack)
    st.curNodeIdx, st.curAxis = nodeIdx, axis
    st.itmIdx = -1 -- reset

    if not nodeIdx then return end
  end

  repeat
    local queryMin, queryMax = queryArea[axis], queryArea[axis+3]
    if tree[nodeIdx-2] >= queryMin and tree[nodeIdx-3] <= queryMax then -- left subtree
      axis = axis4Next[axis]
      if tree[nodeIdx] >= queryMin and tree[nodeIdx-1] <= queryMax then -- right subtree
        tableInsert(stack, 2*nodeIdx+4)
        tableInsert(stack, axis)
      end
      nodeIdx = 2 * nodeIdx
    elseif tree[nodeIdx] >= queryMin and tree[nodeIdx-1] <= queryMax then -- right subtree
      axis = axis4Next[axis]
      nodeIdx = 2 * nodeIdx + 4
    else
      if nodeIdx > nonLeafLimIdx then
        for i = max(tree[nodeIdx-2], st.itmIdx), tree[nodeIdx], 4 do
          if st.items[i-3] >= queryArea[1] and st.items[i-3] <= queryArea[4] and st.items[i-2] >= queryArea[2] and st.items[i-2] <= queryArea[5] and st.items[i-1] >= queryArea[3] and st.items[i-1] <= queryArea[6] then
            st.itmIdx = i + 4 -- update
            return st.items[i]
          end
        end
      end
      axis = tableRemove(stack)
      nodeIdx = tableRemove(stack)
      st.itmIdx = -1 -- reset
    end
    st.curNodeIdx, st.curAxis = nodeIdx, axis
  until not nodeIdx
end

function kdTree:query(query_xmin, query_ymin, query_zmin, query_xmax, query_ymax, query_zmax)
  return query_it, {
    tree = self.tree,
    items = self.items,
    nonLeafLimIdx = self.nonLeafLimIdx,
    queryArea = {query_xmin, query_ymin, query_zmin, query_xmax, query_ymax, query_zmax},
    stack = {},
    curNodeIdx = 4,
    curAxis = 1,
    itmIdx = -1
  }
end

function kdTree:queryNotNested(query_xmin, query_ymin, query_zmin, query_xmax, query_ymax, query_zmax)
  self.queryArea[1], self.queryArea[2], self.queryArea[3], self.queryArea[4], self.queryArea[5], self.queryArea[6] = query_xmin, query_ymin, query_zmin, query_xmax, query_ymax, query_zmax
  table.clear(self.stack)
  self.stackIdx = 0
  self.curNodeIdx = 4
  self.curAxis = 1
  self.itmIdx = -1

  return query_it, self
end

function kdTree:findNearest(x, y, z)
  local point, tree, nonLeafLimIdx, items, stack = self.qPoint, self.tree, self.nonLeafLimIdx, self.items, self.stack
  point[1], point[2], point[3] = x, y, z
  table.clear(stack)
  local nodeIdx, axis = 4, 1
  local k = ceil((self.itemCount + 1) * 0.5) * 4 -- use median point for first best dist estimate
  local bestDist = square(items[k-3] - point[1]) + square(items[k-2] - point[2]) + square(items[k-1] - point[3]) -- best dist estimate
  local bestPointId = items[k]

  repeat
    while nodeIdx <= nonLeafLimIdx do -- while not a leaf node
      if tree[nodeIdx-1] <= point[axis] then
        tableInsert(stack, 2*nodeIdx) -- insert current node's left child to stack
        tableInsert(stack, axis) -- insert current node's axis to stack
        nodeIdx = 2 * nodeIdx + 4 -- continue to right child
        axis = axis4Next[axis] -- subtree axis
      else
        nodeIdx = 2 * nodeIdx -- continue to left child
        tableInsert(stack, nodeIdx+4) -- insert current node's right child to stack
        tableInsert(stack, axis) -- insert current node's axis to stack
        axis = axis4Next[axis] -- subtree axis
      end
    end

    for i = tree[nodeIdx-2], tree[nodeIdx], 4 do
      local dist = square(items[i-3] - point[1]) + square(items[i-2] - point[2]) + square(items[i-1] - point[3])
      if dist < bestDist then
        bestDist, bestPointId = dist, items[i]
      end
    end

    nodeIdx, axis = nil, nil
    while stack[2] do
      axis = tableRemove(stack)
      local childIdx = tableRemove(stack)
      if square(tree[floor(childIdx*0.125)*4-1] - point[axis]) < bestDist then -- floor(childIdx * 0.125) * 4 is the idx of the parent of childIdx
        nodeIdx = childIdx
        axis = axis4Next[axis]
        break
      end
    end

  until not nodeIdx

  return bestPointId, math.sqrt(bestDist)
end

function kdTree:analytics()
  print('Tree Depth = '..ceil(log10(#self.tree / 4 + 1) / log10(2)))
  print('Number of tree Nodes = '..#self.tree / 4)
  print('Number of leaf nodes (nodes containing items) = '..(#self.tree - self.nonLeafLimIdx) / 4)
  print('Number of items in tree = '..self.itemCount)
  print('Average number of items in leaf nodes = '..self.itemCount / ((#self.tree - self.nonLeafLimIdx) / 4))
end

M.new = new
return M
