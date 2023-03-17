-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = 'Locations by Tags'
C.description = 'Finds a maximum number of locations that have a certain tag and are a min/max distance away.'
C.category = 'once_instant'

C.color = ui_flowgraph_editor.nodeColors.sites
C.pinSchema = {
  { dir = 'in', type = 'table', name = 'sitesData', tableType = "sitesData", description = 'Sites Data.' },
  { dir = 'in', type = 'string', name = 'tag', description = 'name of the tag' },
  { dir = 'in', type = 'vec3', name = 'pos', hidden = true, description = 'Position to search from if distance is used.' },
  { dir = 'in', type = 'number', name = 'minDist', default = -1, hidden = true, hardcoded = true, description = 'minimum Distance of nodes. -1 for no miminum.' },
  { dir = 'in', type = 'number', name = 'maxDist', default = -1, hidden = true, hardcoded = true, description = 'max Distance of nodes. -1 for no maximum.' },
  { dir = 'in', type = 'number', name = 'amount', description = 'max number of locations to find. -1 for max.', hidden = true, default = -1, hardcoded = true },
  { dir = 'out', type = 'number', name = 'count', description = 'How many locations are actually found.' },
  { dir = 'out', type = 'flow', name = 'found_1', description = 'If a location has been found.', hidden = true },
  { dir = 'out', type = 'table', name = 'loc_1', tableType = 'locationData', description = 'Location Data.' },
}

C.legacyPins = {
  _in = {
    new = 'reset'
  }
}

C.tags = { 'scenario' }

function C:init(mgr, ...)
  self.count = 1
end
function C:drawCustomProperties()
  if im.Button("Open Sites Editor") then
    if editor_sitesEditor then
      editor_sitesEditor.show()
    end
  end
  im.Separator()
  local ptr = im.IntPtr(self.count)
  if im.InputInt('##count' .. self.id, ptr) then
    if ptr[0] < 1 then
      ptr[0] = 1
    end
    self:updatePins(self.count, ptr[0])
    reason = "Changed Pin count to " .. ptr[0]
  end
end
function C:updatePins(old, new)
  if new < old then
    for i = old, new + 1, -1 do
      self:removePin(self.pinOut['found_' .. i])
      self:removePin(self.pinOut['loc_' .. i])
    end
  else
    for i = old + 1, new do
      self:createPin('out', 'flow', 'found_' .. i)
      local locPin = self:createPin('out', 'table', 'loc_' .. i)
      locPin.tableType = 'locationData'
    end
  end
  self.count = new
end

local function shuffle(tbl)
  for i = #tbl, 2, -1 do
    local j = math.random(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
  return tbl
end

function C:workOnce()
  local all = {}
  if not self.pinIn.pos.value or
      (not self.pinIn.minDist.value and not self.pinIn.maxDist.value)
      or (self.pinIn.minDist.value <= 0 and self.pinIn.maxDist.value < 0) then
    -- if we have no distance constraints, we can use tagsToLocations field
    for _, loc in ipairs(self.pinIn.sitesData.value.tagsToLocations[self.pinIn.tag.value] or {}) do
      table.insert(all, loc)
    end
  else

    -- otherwise we have to query the quadtree and then check for tags ourselves.
    for _, elem in ipairs(self.pinIn.sitesData.value:getRadialLocations(vec3(self.pinIn.pos.value), self.pinIn.minDist.value, self.pinIn.maxDist.value)) do
      local loc = elem.loc
      if loc.customFields.tags[self.pinIn.tag.value] then
        table.insert(all, loc)
      end
    end
  end
  shuffle(all)
  local found = 0
  local max = self.pinIn.amount.value or self.count
  if max == -1 or max > self.count then
    max = self.count
  end
  local locs = {}
  for i = 1, max do
    table.insert(locs, all[i])
  end
  if self.pinIn.pos.value then
    table.sort(locs, function(a, b)
      return (vec3(self.pinIn.pos.value) - a.pos):length() < (vec3(self.pinIn.pos.value) - b.pos):length()
    end)
  end

  for i = 1, self.count do
    if locs[i] and i <= max then
      self.pinOut['found_' .. i].value = true
      self.pinOut['loc_' .. i].value = locs[i]
      found = found + 1
    else
      self.pinOut['found_' .. i].value = false
      self.pinOut['loc_' .. i].value = nil
    end
  end
  self.pinOut.count.value = found
end

function C:_onSerialize(res)
  res.count = self.count
end

function C:_onDeserialized(res)
  self.count = res.count or 1
  self:updatePins(1, self.count)
end

return _flowgraph_createNode(C)
