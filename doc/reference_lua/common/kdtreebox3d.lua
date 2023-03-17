-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- Description: A k-d tree for 3D boxes i.e. 6 diamensions (ex: xmin, ymin, zmin, xmax, ymax, zmax)

--[[ Usage
  local kdTreeB3d = require('kdtreebox3d')

  -- Initialize a new empty kdTree (the itemCount argument is optional for space pre-allocation of the items table)
  local kdT = kdTreeB3d.new(itemCount)

  -- Preload items: Populates the self.items table
  for (item in items) do
    kdT:preload(item_id, item_xmin, item_ymin, item_zmin, item_xmax, item_ymax, item_zmax)
  end

  -- Build the tree: creates the tree from the preloaded items, i.e. it populates the self.tree table
  kdT:build()

  -- Querring:
  Two ways to query the items in the tree. Both query function return iterators (to be used in for .. do constructs)

  1) queries that are not nested
  for item_id in kdT:queryNotNested(query_xmin, query_ymin, query_zmin, query_xmax, query_ymax, query_zmax) do
    -- do something with item_id --
  end

  2) for nested queries (obviously also works for non nested queries but will be slower and create garbage)
  for item1 in kdT:query(query_xmin, query_ymin, query_zmin, query_xmax, query_ymax, query_zmax) do -- for all the items in the tree that intersect the querry area
    for item2 in kdT:query(item1_xmin, item1_ymin, item1_zmin, item1_xmax, item1_ymax, item1_zmax) do
      -- do stuff --
    end
  end

  -- Importing/Exporting: Import an exported tree
  local exportedTree = kdT:export()
  local kdT2 = kdTreeB3d.new()
  kdT2:import(exportedTree)
--]]

local min, max, floor, ceil, log10, huge = math.min, math.max, math.floor, math.ceil, math.log10, math.huge

local M = {}
local kdTree = {}
kdTree.__index = kdTree

local axis4Next = {2, 3, 4, 5, 6, 1}
local minAxisT = {1, 2, 3, 1, 2, 3}
local axis4NextQ = {2, 3, 1}

local function lefSelect(items, dim, left, right)
  -- A linear time selection algorithm with in place array re-ordering.
  -- Adapted here from https://www.beamng.com/game/news/blog/a-faster-selection-algorithm/
  -- for use with serially stored 6+1 diamensional (xmin, ymin, zmin, xmax, ymax, zmax, id) data

  local _dim = dim - 7
  local k = ceil((right + left) / 14) * 7 -- median index
  local l, m, i, j = left, right, left, right
  while l < m do
    if items[k+_dim] < items[i+_dim] then
      items[k-6], items[i-6] = items[i-6], items[k-6]
      items[k-5], items[i-5] = items[i-5], items[k-5]
      items[k-4], items[i-4] = items[i-4], items[k-4]
      items[k-3], items[i-3] = items[i-3], items[k-3]
      items[k-2], items[i-2] = items[i-2], items[k-2]
      items[k-1], items[i-1] = items[i-1], items[k-1]
      items[k], items[i] = items[i], items[k]
    end
    if items[j+_dim] < items[i+_dim] then
      items[j-6], items[i-6] = items[i-6], items[j-6]
      items[j-5], items[i-5] = items[i-5], items[j-5]
      items[j-4], items[i-4] = items[i-4], items[j-4]
      items[j-3], items[i-3] = items[i-3], items[j-3]
      items[j-2], items[i-2] = items[i-2], items[j-2]
      items[j-1], items[i-1] = items[i-1], items[j-1]
      items[j], items[i] = items[i], items[j]
    end
    if items[j+_dim] < items[k+_dim] then
      items[j-6], items[k-6] = items[k-6], items[j-6]
      items[j-5], items[k-5] = items[k-5], items[j-5]
      items[j-4], items[k-4] = items[k-4], items[j-4]
      items[j-3], items[k-3] = items[k-3], items[j-3]
      items[j-2], items[k-2] = items[k-2], items[j-2]
      items[j-1], items[k-1] = items[k-1], items[j-1]
      items[j], items[k] = items[k], items[j]
    end
    local pivotV = items[k+_dim]
    while j > k and i < k do
      repeat i = i + 7 until items[i+_dim] >= pivotV
      repeat j = j - 7 until items[j+_dim] <= pivotV
      items[i-6], items[j-6] = items[j-6], items[i-6]
      items[i-5], items[j-5] = items[j-5], items[i-5]
      items[i-4], items[j-4] = items[j-4], items[i-4]
      items[i-3], items[j-3] = items[j-3], items[i-3]
      items[i-2], items[j-2] = items[j-2], items[i-2]
      items[i-1], items[j-1] = items[j-1], items[i-1]
      items[i], items[j] = items[j], items[i]
    end

    i, j = i + 7, j - 7
    if j < k then
      while items[i+_dim] < pivotV do i = i + 7 end
      l, j = i, m
    end
    if k < i then
      while pivotV < items[j+_dim] do j = j - 7 end
      m, i = j, l
    end
  end

  return k
end

local function new(itemCount)
  return setmetatable({
    tree = nil,
    nonLeafLimIdx = nil,
    items = table.new((itemCount or 0)*7, 0),
    itemCount = 0,
    queryArea = table.new(6, 0),
    stack = {},
    stackIdx = nil,
    curNodeIdx = nil,
    curAxis = nil,
    itmIdx = nil
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

function kdTree:preLoad(id, xmin, ymin, zmin, xmax, ymax, zmax)
  local itemCount = self.itemCount + 7
  self.items[itemCount] = id
  self.items[itemCount-1] = zmax
  self.items[itemCount-2] = ymax
  self.items[itemCount-3] = xmax
  self.items[itemCount-4] = zmin
  self.items[itemCount-5] = ymin
  self.items[itemCount-6] = xmin
  self.itemCount = itemCount
end

function kdTree:_build(axis, left, right, treeIdx)
  -- every tree node occupies 4 tree array entries (lmin, lmax, rmin, rmax).
  -- Use last element index (i.e. 4, 8, 12, 16...) as node index alias (treeIdx).
  -- This simplifies index arithmetic in calculating child node indices of a node (2*treeIdx and 2*treeIdx+4) or parent node index of a node.

  if treeIdx > self.nonLeafLimIdx then
    self.tree[treeIdx-3], self.tree[treeIdx-2], self.tree[treeIdx-1], self.tree[treeIdx] = huge, left, huge, right

    local xMin, yMin, zMin, xMax, yMax, zMax = huge, huge, huge, -huge, -huge, -huge
    for i = left, right, 7 do
      xMin, yMin, zMin = min(xMin, self.items[i-6]), min(yMin, self.items[i-5]), min(zMin, self.items[i-4])
      xMax, yMax, zMax = max(xMax, self.items[i-3]), max(yMax, self.items[i-2]), max(zMax, self.items[i-1])
    end

    return xMin, yMin, zMin, xMax, yMax, zMax
  end

  local medianIdx = lefSelect(self.items, axis, left, right)

  local newaxis = axis4Next[axis]
  local lminX, lminY, lminZ, lmaxX, lmaxY, lmaxZ = self:_build(newaxis, left, medianIdx-7, 2*treeIdx)
  local rminX, rminY, rminZ, rmaxX, rmaxY, rmaxZ = self:_build(newaxis, medianIdx, right, 2*treeIdx+4)

  if minAxisT[axis] == 1 then
    self.tree[treeIdx-3], self.tree[treeIdx-2], self.tree[treeIdx-1], self.tree[treeIdx] = lminX, lmaxX, rminX, rmaxX
  elseif minAxisT[axis] == 2 then
    self.tree[treeIdx-3], self.tree[treeIdx-2], self.tree[treeIdx-1], self.tree[treeIdx] = lminY, lmaxY, rminY, rmaxY
  else
    self.tree[treeIdx-3], self.tree[treeIdx-2], self.tree[treeIdx-1], self.tree[treeIdx] = lminZ, lmaxZ, rminZ, rmaxZ
  end

  return min(lminX, rminX), min(lminY, rminY), min(lminZ, rminZ), max(lmaxX, rmaxX), max(lmaxY, rmaxY), max(lmaxZ, rmaxZ)
end

function kdTree:build()
  self.itemCount = self.itemCount / 7
  local maxDepth = floor(log10(self.itemCount) / log10(2)) + 1 -- max depth that can accomodate all items while being full (root is depth 1)
  local treeNodeCount = 2 * ceil(self.itemCount / maxDepth) - 1 -- optimize node count so that tree depth ~ # of items in each node
  self.tree = table.new(4 * treeNodeCount, 0)
  self.nonLeafLimIdx = 4 * floor(treeNodeCount * 0.5)
  self:_build(1, 7, self.itemCount * 7, 4)
end

local function query_it(st)
  local tree, nonLeafLimIdx, items = st.tree, st.nonLeafLimIdx, st.items
  local queryArea = st.queryArea
  local stack = st.stack
  local nodeIdx, axis = st.curNodeIdx, st.curAxis

  if nodeIdx > nonLeafLimIdx then
    local queryXmin, queryYmin, queryZmin = queryArea[1], queryArea[2], queryArea[3]
    local queryXmax, queryYmax, queryZmax = queryArea[4], queryArea[5], queryArea[6]
    for i = max(tree[nodeIdx-2], st.itmIdx), tree[nodeIdx], 7 do
      if items[i-6] <= queryXmax and items[i-5] <= queryYmax and items[i-4] <= queryZmax and items[i-3] >= queryXmin and items[i-2] >= queryYmin and items[i-1] >= queryZmin then
        st.itmIdx = i + 7
        return items[i]
      end
    end

    nodeIdx, axis = stack[st.stackIdx-1], stack[st.stackIdx]
    st.stackIdx = st.stackIdx - 2
    st.itmIdx = -1
    st.curNodeIdx, st.curAxis = nodeIdx, axis

    if not nodeIdx then return end
  end

  repeat
    local queryMin, queryMax = queryArea[axis], queryArea[axis+3]
    if tree[nodeIdx-2] >= queryMin and tree[nodeIdx-3] <= queryMax then -- left child
      axis = axis4NextQ[axis]
      if tree[nodeIdx] >= queryMin and tree[nodeIdx-1] <= queryMax then -- right child
        st.stackIdx = st.stackIdx + 2
        stack[st.stackIdx-1], stack[st.stackIdx] = 2 * nodeIdx + 4, axis -- insert right subtree in the stack
      end
      nodeIdx = 2 * nodeIdx -- descend into left subtree
    elseif tree[nodeIdx] >= queryMin and tree[nodeIdx-1] <= queryMax then -- right child
      axis = axis4NextQ[axis]
      nodeIdx = 2 * nodeIdx + 4 -- descend into right subtree
    else
      if nodeIdx > nonLeafLimIdx then
        local queryXmin, queryYmin, queryZmin = queryArea[1], queryArea[2], queryArea[3]
        local queryXmax, queryYmax, queryZmax = queryArea[4], queryArea[5], queryArea[6]
        for i = max(tree[nodeIdx-2], st.itmIdx), tree[nodeIdx], 7 do
          if items[i-6] <= queryXmax and items[i-5] <= queryYmax and items[i-4] <= queryZmax and items[i-3] >= queryXmin and items[i-2] >= queryYmin and items[i-1] >= queryZmin then
            st.itmIdx = i + 7
            return items[i]
          end
        end
      end
      nodeIdx, axis = stack[st.stackIdx-1], stack[st.stackIdx]
      st.stackIdx = st.stackIdx - 2
      st.itmIdx = -1
    end

    st.curNodeIdx, st.curAxis = nodeIdx, axis
  until not nodeIdx

  return
end

function kdTree:query(query_xmin, query_ymin, query_zmin, query_xmax, query_ymax, query_zmax)
  return query_it, {
    tree = self.tree,
    items = self.items,
    nonLeafLimIdx = self.nonLeafLimIdx,
    queryArea = {query_xmin, query_ymin, query_zmin, query_xmax, query_ymax, query_zmax},
    stack = table.new(20, 0),
    stackIdx = 0,
    curNodeIdx = 4,
    curAxis = 1,
    itmIdx = -1
  }
end

function kdTree:queryNotNested(query_xmin, query_ymin, query_zmin, query_xmax, query_ymax, query_zmax)
  self.queryArea[1], self.queryArea[2], self.queryArea[3] = query_xmin, query_ymin, query_zmin
  self.queryArea[4], self.queryArea[5], self.queryArea[6] = query_xmax, query_ymax, query_zmax
  table.clear(self.stack)
  self.stackIdx = 0
  self.curNodeIdx = 4
  self.curAxis = 1
  self.itmIdx = -1

  return query_it, self
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
