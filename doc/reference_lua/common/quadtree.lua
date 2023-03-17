-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- Description
  -- This module implements a quadtree data structure with insert, remove, query and compress facilities.
  -- The query function is remove-safe i.e. if an item is removed while a query is active, the query traversal is not affected.

  -- Data structure description:
  -- Each element in the array self.tree represents a tree node and contains the items in that node. The root node is index 1 i.e. self.tree[1] is the root node.
  -- A tree node that contains items (it might not) takes up a table value, otherwise it is nil.

  -- Every item is made up of five attributes (itm_id, itm_xmin, itm_xmax, itm_ymin, itm_ymax) which are contained in the node table in sequence "unwrapped",
  -- so each item in a node takes up five concecutive places in the node table.
  -- A node table also holds the number of entries in that table in the key itemCount, so that the number of items in a node table can
  -- be calculated by itemCount / 5, ex. the number of items in node_i is self.tree[node_i].itemCount / 5

  -- Each entry in the array self.children indicates the tree index of the first child of that node (subsequent child indices being +1, +2, +3) or nil if the node has no children.
  -- ex. self.children[2] contains the tree index of the first child of node 2, so if we want to grab the items contained in the first child of node 2 (provided that node 2 has children)
  -- we can do that by self.tree[self.children[2]]

-- created by BeamNG

--[[ Usage
  -- Initialize a new empty quadtree
    q = newQuadtree()

  -- Preload items. This step is necessary to gauge the size of the tree canvas.
    for (items in list) do
      q:preLoad(itm_id, itm_xmin, itm_ymin, itm_xmax, itm_ymax)
    end

  -- Build the tree
    q:build(maxDepth) -- The maxDepth argument is optional and defaults to 10 (root node is at depth 1).

    The build function inserts the preloaded items in the tree.
    After a tree build, the tree canvas size (bounding box of root node) does not change.
    Items outside the bounds of the canvas can still be inserted, removed and querried as per usual (without affecting canvas bounds).

  -- Compress (optional)
    q:compress()

    The compress function can be optionally used to optimize memory usage after a build.
    Item insertions after a compress call on the quadtree might be slower.

  -- Insert (items after a build) or remove items from the tree.
    q:insert(itm_id, itm_xmin, itm_ymin, itm_xmax, itm_ymax)
    q:remove(itm_id, itm_x, itm_y) -- where itm_x and itm_y is the item center

  -- The query function returns an iterator.
    for item_id in q:query(query_xmin, query_ymin, query_xmax, query_ymax) do
      -- do something with item_id --
    end

  -- Example: Create table containing all item_ids of items in a query area
    for item_id in q:query(query_xmin, query_ymin, query_xmax, query_ymax) do table.insert(results, item_id) end
--]]

local M = {}
local quadTree = {}
quadTree.__index = quadTree

-- Cache often-used functions from other modules in upvalues
local max, min, tableInsert = math.max, math.min, table.insert

local ok, _ = pcall(require, "table.new")
if not ok then
  table.new = function() return {} end
end

local function pointBBox(x, y, radius)
  return x - radius, y - radius, x + radius, y + radius
end

local function lineBBox(x1, y1, x2, y2, radius)
  local enlarge = radius or 0
  return min(x1, x2) - enlarge, min(y1, y2) - enlarge, max(x1, x2) + enlarge, max(y1, y2) + enlarge
end

local emptyNode = {itemCount = 0}

local function newQuadtree(numOfItems)
  return setmetatable({
    tree = {},
    children = {},
    itm_preld = table.new((numOfItems or 0) * 5, 0),
    itm_preldLen = 0,
    nodeCount = 0,
    maxDepth = 10,
    xmin = math.huge, xmax = -math.huge, ymin = math.huge, ymax = -math.huge,
    query_xmin = 0,
    query_ymin = 0,
    query_xmax = 0,
    query_ymax = 0,
    stack = table.new(100, 0),
    currentNode = 0,
    stackidx = 1,
    i = 1
  }, quadTree)
end

function quadTree:export()
  return {
    tree = self.tree,
    children = self.children,
    nodeCount = self.nodeCount,
    maxDepth = self.maxDepth,
    xmin = self.xmin,
    xmax = self.xmax,
    ymin = self.ymin,
    ymax = self.ymax,
  }
end

function quadTree:import(quadTreeData)
  self.tree = quadTreeData.tree
  self.children = quadTreeData.children
  self.nodeCount = quadTreeData.nodeCount
  self.maxDepth = quadTreeData.maxDepth
  self.xmin, self.xmax, self.ymin, self.ymax = quadTreeData.xmin, quadTreeData.xmax, quadTreeData.ymin, quadTreeData.ymax
  self.itm_preld = nil
  self.itm_preldLen = nil
end

function quadTree:preLoad(itm_id, itm_xmin, itm_ymin, itm_xmax, itm_ymax)
  local itm_preld = self.itm_preld
  local len = self.itm_preldLen + 5
  itm_preld[len-4], itm_preld[len-3], itm_preld[len-2], itm_preld[len-1], itm_preld[len] = itm_id, itm_xmin, itm_ymin, itm_xmax, itm_ymax
  self.itm_preldLen = len

  self.xmin = min(self.xmin, itm_xmin)
  self.xmax = max(self.xmax, itm_xmax)
  self.ymin = min(self.ymin, itm_ymin)
  self.ymax = max(self.ymax, itm_ymax)
end

local function createChildNodes(self, node_i)
  -- creates children for node_i
  local scount = self.nodeCount + 1
  self.children[node_i] = scount
  self.nodeCount = scount + 3
  return scount -- returns node index of the first child of node_i
end

function quadTree:insert(itm_id, itm_xmin, itm_ymin, itm_xmax, itm_ymax)
  local node_i = 1
  local children = self.children
  local node_xmin, node_xmax, node_ymin, node_ymax = self.xmin, self.xmax, self.ymin, self.ymax
  local cup_itm_ymax = max(min(itm_ymax, node_ymax), node_ymin)
  local cup_itm_ymin = min(max(itm_ymin, node_ymin), node_ymax)
  for _ = 1, self.maxDepth-1 do
    local node_xmid = (node_xmin + node_xmax) * 0.5
    local node_ymid = (node_ymin + node_ymax) * 0.5
    if cup_itm_ymax < node_ymid then -- check if item is contained in lower half space
      if itm_xmax < node_xmid then -- check if item is contained in left half space
        node_i = children[node_i] or createChildNodes(self, node_i)
        node_xmax = node_xmid
        node_ymax = node_ymid
      elseif itm_xmin > node_xmid then -- check if item is contained in right half space
        node_i = (children[node_i] or createChildNodes(self, node_i)) + 1
        node_xmin = node_xmid
        node_ymax = node_ymid
      else
        break -- item is not contained in either left or right half spaces
      end
    elseif cup_itm_ymin > node_ymid then -- check if item is contained in upper half space
      if itm_xmin > node_xmid then -- check if item is contained in right half space
        node_i = (children[node_i] or createChildNodes(self, node_i)) + 2
        node_xmin = node_xmid
        node_ymin = node_ymid
      elseif itm_xmax < node_xmid then -- check if item is contained in left half space
        node_i = (children[node_i] or createChildNodes(self, node_i)) + 3
        node_xmax = node_xmid
        node_ymin = node_ymid
      else
        break -- item is not contained in either left or right half spaces
      end
    else
      break -- item is not contained in either upper or lower half spaces
    end
  end

  local tree = self.tree
  if not tree[node_i] then tree[node_i] = {itemCount = 0} end -- there is no need to increase the node count here, node_i is already in the nodeCount.

  local itemCount = tree[node_i].itemCount + 5
  tree[node_i][itemCount] = itm_ymax
  tree[node_i][itemCount-1] = itm_ymin
  tree[node_i][itemCount-2] = itm_xmax
  tree[node_i][itemCount-3] = itm_xmin
  tree[node_i][itemCount-4] = itm_id
  tree[node_i].itemCount = itemCount
end

function quadTree:remove(itm_id, itm_x, itm_y)
  local node_i = 1
  local node_xmin, node_xmax, node_ymin, node_ymax = self.xmin, self.xmax, self.ymin, self.ymax
  local tree, children = self.tree, self.children
  for _ = 1, self.maxDepth do
    -- look for the item in the current node
    for j = 1, (tree[node_i] or emptyNode).itemCount, 5 do
      local node = tree[node_i]
      if node[j] == itm_id and square((node[j+1] + node[j+2]) * 0.5 - itm_x) + square((node[j+3] + node[j+4]) * 0.5 - itm_y) < 1e-8 then
        local itemCount = node.itemCount
        local tmp_items = table.new(itemCount-5, 1) -- allows us to remove items while a in an active query
        for i = 1, j-1 do tmp_items[i] = node[i] end
        for i = j+5, itemCount do tmp_items[i-5] = node[i] end
        tmp_items.itemCount = node.itemCount - 5
        tree[node_i] = tmp_items
        return
      end
    end

    -- if the item was not in the current node continue in one of its children
    if children[node_i] then
      local node_xmid = (node_xmin + node_xmax) * 0.5
      local node_ymid = (node_ymin + node_ymax) * 0.5
      if itm_y <= node_ymid then -- check if item center is in the lower half space
        if itm_x <= node_xmid then -- check if item center is in left half space
          node_i = children[node_i]
          node_xmax = node_xmid
          node_ymax = node_ymid
        else -- if item is not in parent node and item center is in the lower half space but not in the left half space then it must be within the lower right quad.
          node_i = children[node_i] + 1
          node_xmin = node_xmid
          node_ymax = node_ymid
        end
      else
        if itm_x >= node_xmid then -- check if item is contained in right half space
          node_i = children[node_i] + 2
          node_xmin = node_xmid
          node_ymin = node_ymid
        else -- check if item is contained in right half space
          node_i = children[node_i] + 3
          node_xmax = node_xmid
          node_ymin = node_ymid
        end
      end
    else
      break
    end
  end
end

function quadTree:build(maxDepth)
  if maxDepth then self.maxDepth = maxDepth end
  self.tree[1] = {itemCount = 0}
  self.nodeCount = 1
  local itm_preld = self.itm_preld
  for i = 1, self.itm_preldLen, 5 do
    self:insert(itm_preld[i], itm_preld[i+1], itm_preld[i+2], itm_preld[i+3], itm_preld[i+4])
  end
  self.itm_preld = nil
  self.itm_preldLen = nil
end

local function query_it(ctx)
  local tree = ctx.tree
  local children = ctx.children
  local query_xmin, query_ymin, query_xmax, query_ymax = ctx.query_xmin, ctx.query_ymin, ctx.query_xmax, ctx.query_ymax
  local stack = ctx.stack
  local stackidx = ctx.stackidx
  local i = ctx.i

  repeat
    local node = ctx.currentNode
    for j = i, (node or emptyNode).itemCount, 5 do
      if query_xmin <= node[j+2] and query_xmax >= node[j+1] and query_ymin <= node[j+4] and query_ymax >= node[j+3] then
        ctx.i = j + 5 -- save next item index since we will need to continue the search in this node
        return node[j] -- return item id
      end
    end

    local childIdx = children[stack[stackidx]]
    if childIdx then
      local nodeXmin, nodeXmax, nodeYmin, nodeYmax = stack[stackidx+1], stack[stackidx+2], stack[stackidx+3], stack[stackidx+4]
      local node_xmid = (nodeXmin + nodeXmax) * 0.5
      local node_ymid = (nodeYmin + nodeYmax) * 0.5
      if node_ymid >= query_ymin then
        if node_xmid >= query_xmin and (children[childIdx] or tree[childIdx]) then
          stack[stackidx], stack[stackidx+1], stack[stackidx+2], stack[stackidx+3], stack[stackidx+4] = childIdx, nodeXmin, node_xmid, nodeYmin, node_ymid
          stackidx = stackidx + 5
        end
        if node_xmid <= query_xmax and (children[childIdx+1] or tree[childIdx+1]) then
          stack[stackidx], stack[stackidx+1], stack[stackidx+2], stack[stackidx+3], stack[stackidx+4] = childIdx + 1, node_xmid, nodeXmax, nodeYmin, node_ymid
          stackidx = stackidx + 5
        end
      end
      if node_ymid <= query_ymax then
        if node_xmid <= query_xmax and (children[childIdx+2] or tree[childIdx+2]) then
          stack[stackidx], stack[stackidx+1], stack[stackidx+2], stack[stackidx+3], stack[stackidx+4] = childIdx + 2, node_xmid, nodeXmax, node_ymid, nodeYmax
          stackidx = stackidx + 5
        end
        if node_xmid >= query_xmin and (children[childIdx+3] or tree[childIdx+3]) then
          stack[stackidx], stack[stackidx+1], stack[stackidx+2], stack[stackidx+3], stack[stackidx+4] = childIdx + 3, nodeXmin, node_xmid, node_ymid, nodeYmax
          stackidx = stackidx + 5
        end
      end
    end

    -- get the next node from the stack to continue the search
    stackidx = stackidx - 5
    ctx.stackidx = stackidx
    ctx.currentNode = tree[stack[stackidx]]
    i = 1
  until stackidx < 1

  return nil
end

function quadTree:query(query_xmin, query_ymin, query_xmax, query_ymax)
  local stack = table.new(100, 0)
  -- initialize the stack with the root node (tree index 1) and root node (tree) bounds
  stack[1], stack[2], stack[3], stack[4], stack[5] = 1, self.xmin, self.xmax, self.ymin, self.ymax

  return query_it, {
    tree = self.tree,
    children = self.children,
    query_xmin = query_xmin,
    query_ymin = query_ymin,
    query_xmax = query_xmax,
    query_ymax = query_ymax,
    stack = stack,
    stackidx = 1,
    currentNode = self.tree[1], -- allows us to remove (quadTree:remove) items from the node while searching it
    i = 1 -- indexes the items of the node we are currently looking into
  }
end

function quadTree:queryNotNested(query_xmin, query_ymin, query_xmax, query_ymax)
  self.query_xmin = query_xmin
  self.query_ymin = query_ymin
  self.query_xmax = query_xmax
  self.query_ymax = query_ymax

  local stack = self.stack
  table.clear(stack)
  -- initialize the stack with the root node (tree index 1) and root node (tree) bounds
  stack[1], stack[2], stack[3], stack[4], stack[5] = 1, self.xmin, self.xmax, self.ymin, self.ymax

  self.currentNode = self.tree[1] -- allows us to remove (quadTree:remove) items from the node while searching it
  self.stackidx = 1
  self.i = 1 -- indexes the items of the node we are currently looking into

  return query_it, self
end

function quadTree:compress()
  -- O(n + N) complexity. n = # of tree nodes, N = total # of items in tree
  local tree = self.tree
  for i, node in pairs(tree) do
    local itemCount = node.itemCount
    local tmp = table.new(itemCount, 1)
    tmp.itemCount = itemCount
    for j = 1, itemCount do
      tmp[j] = node[j]
    end
    tree[i] = tmp
  end
end

function quadTree:analytics()
  print('Tree depth = '..math.ceil(math.log10(3 * self.nodeCount + 1) / math.log10(4)))
  print('Number of Tree Nodes = '..self.nodeCount)

  local occupiedNodes, itemCount = 0, 0
  for _, v in pairs(self.tree) do occupiedNodes, itemCount = occupiedNodes + 1, itemCount + v.itemCount end

  print('Number of Occupied Nodes = '..occupiedNodes)
  print('Ratio of Occupied Nodes = '..occupiedNodes / self.nodeCount)
  print('Average number of items in occupied nodes = '..itemCount * 0.2 / occupiedNodes)

  --[[ TODO
  -- median node items
  -- item distibution
  -- center of mass
  -- second momment of inertia
  -- average number of children, either occupied or that themselves have children
  -- average number of items in leaf nodes, kai standard deviation
  -- number children in non leaf nodes
  -- ta leafs na isoapexoune apo to route
  -- distance of leafs from root (average and standard deviation)
  -- average hopes of leafs pos recovered from pos front 1 (min an max hopes average)
  -- equal distribution of items on leafs
  -- distribution of items in an internal nodes children
  --]]
end

M.newQuadtree = newQuadtree
M.pointBBox = pointBBox
M.lineBBox = lineBBox
return M
