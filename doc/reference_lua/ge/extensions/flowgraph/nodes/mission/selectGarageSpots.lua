-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Select Garage Spots'
C.description = 'Selects the different spots needed for the mission.'
C.category = 'once_p_duration'
C.author = 'BeamNG'

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = 'In flow pin to trigger this node'},
  {dir = 'in', type = 'flow', name = 'reset', description = 'Reset the node.', impulse = true },

  {dir = 'out', type = 'flow', name = 'flow', default = false, description= 'Continues flow only when the sites are found.'},
  {dir = 'out', type = 'flow', name = 'loaded', default = false, description= 'Triggers once after the sites are founded.', impulse = true},

  {dir = 'in', type = 'table', name = 'sitesData', description = ''},
  {dir = 'in', type = 'number', name = 'minDist', description = '' },
  {dir = 'in', type = 'number', name = 'maxDist', description = '' },
  {dir = 'in', type = 'string', name = 'zone', description = '' },
  {dir = 'in', type = 'bool', name = 'isLocal', description = '' },

  {dir = 'out', type = 'string', name = 'startSpot', description = ''},
  {dir = 'out', type = 'string', name = 'endSpot', description = ''},
  {dir = 'out', type = 'string', name = 'startLocation', description = ''},
  {dir = 'out', type = 'string', name = 'endLocation', description = ''},
}
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.tags = {}

function C:init()
  self.spots = {}
  self.names = {}
  self.startSpot = nil
  self.endSpot = nil
  self.state = 1
  self.indexStart = 1

  self.pinOut.flow.value = false
  self.pinOut.loaded.value = false

  self.pinOut.startSpot.value = nil
  self.pinOut.endSpot.value = nil
end

function C:_executionStarted()
  self:resetData()
end

function C:resetData()
  self.usedStartingSpotNames = {}
  self.spots = {}
  self.names = {}
  self.startSpot = nil
  self.endSpot = nil
  self.state = 1
  self.indexStart = 1

  self.pinOut.flow.value = false
  self.pinOut.loaded.value = false

  self.pinOut.startSpot.value = nil
  self.pinOut.endSpot.value = nil
end

function C:workOnce()
  self:resetData()
end

--local route = require('/lua/ge/extensions/gameplay/route/route')()
function C:findEndSpotForStartingSpot(startSpot)
  -- get all the endsSpots and shuffle them
  local possibleEndSpots = tableKeys(self.spots.byName)
  for i = #possibleEndSpots, 2, -1 do
    local j = math.random(i)
    possibleEndSpots[i], possibleEndSpots[j] = possibleEndSpots[j], possibleEndSpots[i]
  end

  -- best result if we find none that fit
  local bestCandidate = nil
  local bestOverDistance = nil
  -- go through all the endspots
  for i = 1, #possibleEndSpots do

    local endSpot = self.spots.byName[possibleEndSpots[i]]
    if endSpot.name ~= startSpot.name then
      -- check the distance to the startSpot
      --route:clear()
      --route:setupPath(startSpot.pos,endSpot.pos)
      local distance = (startSpot.pos - endSpot.pos):length()--(route.path[1] or {distToTarget = math.huge}).distToTarget

      -- return early if it fits our criteria
      if distance > self.pinIn.minDist.value and distance < self.pinIn.maxDist.value then
        log("D","","Found a good candidate after " .. i.. " tries")
        return endSpot
      else
        -- otherwise, keep track of the best result
        if not bestCandidate then
          bestCandidate, bestOverDistance = endSpot, distance - self.pinIn.maxDist.value
        else
          if distance - self.pinIn.maxDist.value < bestOverDistance then
            bestCandidate, bestOverDistance = endSpot, distance - self.pinIn.maxDist.value
          end
        end
      end
    end
  end
  log("D","","Could not find endSpot withing acceptable distance! using best bestCandidate")
  --return best result otherwise
  return bestCandidate
end

function C:work()
  if self.pinIn.flow.value then
    --local count = 100
    if self.state == 1 then
      self.spots = self.pinIn.sitesData.value.parkingSpots
      self.names = tableKeys(self.spots.byName)

      -- build a list of all possible starting spot names
      local possibleStartingSpots = {}
      local isLocal = self.pinIn.isLocal.value
      for name, spot in pairs(self.spots.byName) do
        if isLocal then
          table.sort(spot.zones, function(a,b) return (a.customFields.values.prio or 1) < (b.customFields.values.prio or 1) end)
          local zoneName = (spot.zones[1] or {name = 'none!'}).name
          if zoneName == self.pinIn.zone.value then
            table.insert(possibleStartingSpots, name)
          end
        else
          table.insert(possibleStartingSpots, name)
        end
      end

      -- prevent dupliocate starting positions
      if #possibleStartingSpots == #self.usedStartingSpotNames then
        table.clear(self.usedStartingSpotNames)
        log("D","","cleared used starting spots. can now use the all of them again")
      end
      local tmp = deepcopy(possibleStartingSpots)
      local usedSpotsByName = tableValuesAsLookupDict(self.usedStartingSpotNames)
      table.clear(possibleStartingSpots)
      for _, name in ipairs(tmp) do
        if not usedSpotsByName[name] then
          table.insert(possibleStartingSpots, name)
        end
      end

      -- shuffle starting spots, find end spot for it
      for i = #possibleStartingSpots, 2, -1 do
        local j = math.random(i)
        possibleStartingSpots[i], possibleStartingSpots[j] = possibleStartingSpots[j], possibleStartingSpots[i]
      end
      self.startSpot = self.spots.byName[possibleStartingSpots[1]]
      self.endSpot = self:findEndSpotForStartingSpot(self.startSpot)
      -- keep track of used starting spots
      table.insert(self.usedStartingSpotNames, self.startSpot.name)


      -- setup out pin values
      table.sort(self.startSpot.zones, function(a,b) return (a.customFields.values.prio or 1) < (b.customFields.values.prio or 1) end)
      table.sort(self.endSpot.zones, function(a,b) return (a.customFields.values.prio or 1) < (b.customFields.values.prio or 1) end)

      self.pinOut.startSpot.value = self.startSpot.name
      self.pinOut.endSpot.value = self.endSpot.name

      self.pinOut.startLocation.value = self.startSpot.zones[1] and self.startSpot.zones[1].name or ""
      self.pinOut.endLocation.value = self.endSpot.zones[1] and self.endSpot.zones[1].name or ""

      self.pinOut.flow.value = true
      self.pinOut.loaded.value = true

      log("I","",string.format("G2G Route: %s/%s to %s/%s direct distance: %0.1f", self.pinOut.startSpot.value, self.pinOut.startLocation.value, self.pinOut.endSpot.value, self.pinOut.endLocation.value, (self.startSpot.pos - self.endSpot.pos):length()))
      self.state = 2
    elseif self.state == 2 then
      self.pinOut.flow.value = true
      self.pinOut.loaded.value = false
      --if count > 0 then
      --  self.state = 1
      --end
      --count = count -1
    end
  end
end

return _flowgraph_createNode(C)
