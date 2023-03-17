-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- Description: A k-d tree for 2D boxes i.e. 4 diamensions (ex: xmin, ymin, xmax, ymax)

--[[ Usage
  local kdTreeB2d = require('kdtreebox2d')

  -- Initialize a new empty kdTree (the itemCount argument is optional for space pre-allocation of the items table)
  local kdT = kdTreeB2d.new(itemCount)

  -- Preload items: Populates the self.items table
  for (item in items) do
    kdT:preload(item_id, item_xmin, item_ymin, item_xmax, item_ymax)
  end

  -- Build the tree: creates the tree from the preloaded items, i.e. it populates the self.tree table
  kdT:build()

  -- Querring:
  Two ways to query the items in the tree. Both query function return iterators (to be used in for .. do constructs)

  1) queries that are not nested
  for item_id in kdT:queryNotNested(query_xmin, query_ymin, query_xmax, query_ymax) do
    -- do something with item_id --
  end

  2) for nested queries (obviously also works for non nested queries but will be slower and create garbage)
  for item1 in kdT:query(query_xmin, query_ymin, query_xmax, query_ymax) do -- for all the items in the tree that intersect the querry area
    for item2 in kdT:query(item1_xmin, item1_ymin, item1_xmax, item1_ymax) do
      -- do stuff --
    end
  end

  -- Importing/Exporting: Import an exported tree
  local exportedTree = kdT:export()
  local kdT2 = kdTreeB2d.new(itemCount)
  kdT2:import(exportedTree)
--]]

local min, max, floor, ceil, log10, huge = math.min, math.max, math.floor, math.ceil, math.log10, math.huge

local M = {}
local kdTree = {}
kdTree.__index = kdTree

local axis4Next = {2, 3, 4, 1}
local minAxisT = {1, 2, 1, 2}

local function lefSelect(items, dim, left, right)
  -- A linear time selection algorithm with in place array re-ordering.
  -- Adapted here from https://www.beamng.com/game/news/blog/a-faster-selection-algorithm/
  -- for use with serially stored 4+1 diamensional (xmin, ymin, xmax, ymax, id) data

  local _dim = dim - 5
  local k = ceil((right + left) * 0.1) * 5
  local l, m, i, j = left, right, left, right
  while l < m do
    if items[k+_dim] < items[i+_dim] then
      items[k-4], items[i-4] = items[i-4], items[k-4]
      items[k-3], items[i-3] = items[i-3], items[k-3]
      items[k-2], items[i-2] = items[i-2], items[k-2]
      items[k-1], items[i-1] = items[i-1], items[k-1]
      items[k], items[i] = items[i], items[k]
    end
    if items[j+_dim] < items[i+_dim] then
      items[j-4], items[i-4] = items[i-4], items[j-4]
      items[j-3], items[i-3] = items[i-3], items[j-3]
      items[j-2], items[i-2] = items[i-2], items[j-2]
      items[j-1], items[i-1] = items[i-1], items[j-1]
      items[j], items[i] = items[i], items[j]
    end
    if items[j+_dim] < items[k+_dim] then
      items[j-4], items[k-4] = items[k-4], items[j-4]
      items[j-3], items[k-3] = items[k-3], items[j-3]
      items[j-2], items[k-2] = items[k-2], items[j-2]
      items[j-1], items[k-1] = items[k-1], items[j-1]
      items[j], items[k] = items[k], items[j]
    end
    local pivotV = items[k+_dim]
    while j > k and i < k do
      repeat i = i + 5 until items[i+_dim] >= pivotV
      repeat j = j - 5 until items[j+_dim] <= pivotV
      items[i-4], items[j-4] = items[j-4], items[i-4]
      items[i-3], items[j-3] = items[j-3], items[i-3]
      items[i-2], items[j-2] = items[j-2], items[i-2]
      items[i-1], items[j-1] = items[j-1], items[i-1]
      items[i], items[j] = items[j], items[i]
    end

    i, j = i + 5, j - 5
    if j < k then
      while items[i+_dim] < pivotV do i = i + 5 end
      l, j = i, m
    end
    if k < i then
      while pivotV < items[j+_dim] do j = j - 5 end
      m, i = j, l
    end
  end

  return k
end

local function new(itemCount)
  return setmetatable({
    tree = nil,
    nonLeafLimIdx = nil,
    items = table.new((itemCount or 0)*5, 0),
    itemCount = 0,
    queryArea = table.new(4, 0),
    stack = {},
    stackIdx = 0,
    curNodeIdx = 1,
    curAxis = 1,
    itmIdx = -1
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

function kdTree:preLoad(id, xmin, ymin, xmax, ymax)
  local itemCount = self.itemCount + 5
  self.items[itemCount], self.items[itemCount-1], self.items[itemCount-2], self.items[itemCount-3], self.items[itemCount-4] = id, ymax, xmax, ymin, xmin
  self.itemCount = itemCount
end

function kdTree:_build(axis, left, right, treeIdx)
  if treeIdx > self.nonLeafLimIdx then
    self.tree[treeIdx], self.tree[treeIdx+1], self.tree[treeIdx+2], self.tree[treeIdx+3] = huge, left, huge, right

    local xMin, yMin, xMax, yMax = huge, huge, -huge, -huge
    for i = left, right, 5 do
      xMin, yMin, xMax, yMax = min(xMin, self.items[i-4]), min(yMin, self.items[i-3]), max(xMax, self.items[i-2]), max(yMax, self.items[i-1])
    end

    return xMin, yMin, xMax, yMax
  end

  local medianIdx = lefSelect(self.items, axis, left, right)

  local newaxis = axis4Next[axis]
  local lminX, lminY, lmaxX, lmaxY = self:_build(newaxis, left, medianIdx-5, 2*treeIdx+3)
  local rminX, rminY, rmaxX, rmaxY = self:_build(newaxis, medianIdx, right, 2*treeIdx+7)

  if minAxisT[axis] == 1 then
    self.tree[treeIdx], self.tree[treeIdx+1], self.tree[treeIdx+2], self.tree[treeIdx+3] = lminX, lmaxX, rminX, rmaxX
  else
    self.tree[treeIdx], self.tree[treeIdx+1], self.tree[treeIdx+2], self.tree[treeIdx+3] = lminY, lmaxY, rminY, rmaxY
  end

  return min(lminX, rminX), min(lminY, rminY), max(lmaxX, rmaxX), max(lmaxY, rmaxY)
end

function kdTree:build()
  self.itemCount = self.itemCount / 5
  local maxDepth = floor(log10(self.itemCount) / log10(2)) + 1 -- max depth that can accomodate all items while being full (0 indexed)
  local treeNodeCount = 2 * ceil(self.itemCount / maxDepth) - 1 -- optimize node count so that tree depth ~ # of items in each node
  self.tree = table.new(4 * treeNodeCount, 0)
  self.nonLeafLimIdx = 4 * floor(treeNodeCount * 0.5)
  self:_build(1, 5, self.itemCount * 5, 1)
end

local function query_it(st)
  local tree, nonLeafLimIdx, items = st.tree, st.nonLeafLimIdx, st.items
  local queryArea = st.queryArea
  local stack = st.stack
  local nodeIdx, axis = st.curNodeIdx, st.curAxis

  if nodeIdx > nonLeafLimIdx then
    local queryXmin, queryYmin, queryXmax, queryYmax = queryArea[1], queryArea[2], queryArea[3], queryArea[4]
    for i = max(tree[nodeIdx+1], st.itmIdx), tree[nodeIdx+3], 5 do
      if st.items[i-4] <= queryXmax and st.items[i-3] <= queryYmax and st.items[i-2] >= queryXmin and st.items[i-1] >= queryYmin then
        st.itmIdx = i + 5
        return st.items[i]
      end
    end

    nodeIdx, axis = stack[st.stackIdx-1], stack[st.stackIdx]
    st.stackIdx = st.stackIdx - 2
    st.itmIdx = -1
    st.curNodeIdx, st.curAxis = nodeIdx, axis

    if not nodeIdx then return end
  end

  repeat
    local queryMin, queryMax = queryArea[axis], queryArea[axis+2]
    if tree[nodeIdx] <= queryMax and tree[nodeIdx+1] >= queryMin then -- left child
      axis = 3 - axis
      if tree[nodeIdx+2] <= queryMax and tree[nodeIdx+3] >= queryMin then -- right child
        st.stackIdx = st.stackIdx + 2
        stack[st.stackIdx-1], stack[st.stackIdx] = 2 * nodeIdx + 7, axis
      end
      nodeIdx = 2 * nodeIdx + 3 -- descend into left subtree
    elseif tree[nodeIdx+2] <= queryMax and tree[nodeIdx+3] >= queryMin then -- right child
      axis = 3 - axis
      nodeIdx = 2 * nodeIdx + 7 -- descend into right subtree
    else
      if nodeIdx > nonLeafLimIdx then
        local queryXmin, queryYmin, queryXmax, queryYmax = queryArea[1], queryArea[2], queryArea[3], queryArea[4]
        for i = max(tree[nodeIdx+1], st.itmIdx), tree[nodeIdx+3], 5 do
          if st.items[i-4] <= queryXmax and st.items[i-3] <= queryYmax and st.items[i-2] >= queryXmin and st.items[i-1] >= queryYmin then
            st.itmIdx = i + 5
            return st.items[i]
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

function kdTree:query(query_xmin, query_ymin, query_xmax, query_ymax)
  return query_it, {
    tree = self.tree,
    items = self.items,
    nonLeafLimIdx = self.nonLeafLimIdx,
    queryArea = {query_xmin, query_ymin, query_xmax, query_ymax},
    stack = table.new(20, 0),
    stackIdx = 0,
    curNodeIdx = 1,
    curAxis = 1,
    itmIdx = -1
  }
end

function kdTree:queryNotNested(query_xmin, query_ymin, query_xmax, query_ymax)
  self.queryArea[1], self.queryArea[2], self.queryArea[3], self.queryArea[4] = query_xmin, query_ymin, query_xmax, query_ymax
  table.clear(self.stack)
  self.stackIdx = 0
  self.curNodeIdx = 1
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
