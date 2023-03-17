-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Select Heist Spots'
C.description = 'Selects the different spots needed for the mission.'
C.category = 'once_p_duration'
C.author = 'BeamNG'

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = 'In flow pin to trigger this node'},
  {dir = 'in', type = 'flow', name = 'reset', hindexStartden = true, description = 'Reset the node.', impulse = true },

  {dir = 'out', type = 'flow', name = 'flow', default = false, description= 'Continues flow only when the sites are found.'},
  {dir = 'out', type = 'flow', name = 'loaded', default = false, description= 'Triggers once after the sites are founded.', impulse = true},

  {dir = 'in', type = 'vec3', name = 'position', description = '' },
  {dir = 'in', type = 'table', name = 'sitesData', description = ''},

  {dir = 'out', type = 'string', name = 'start', description = ''},
  {dir = 'out', type = 'string', name = 'hiest', description = ''},
  {dir = 'out', type = 'string', name = 'escape', description = ''},
  {dir = 'out', type = 'string', name = 'startLocation', description = ''},
  {dir = 'out', type = 'string', name = 'hiestLocation', description = ''},
  {dir = 'out', type = 'string', name = 'escapeLocation', description = ''},
}
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.tags = {}

function C:init()
  self.spots = {}
  self.names = {}
  self.startLoc = {}
  self.hiestLoc = {}
  self.escapeLoc = {}
  self.start = nil
  self.hiest = nil
  self.escape = nil
  self.state = 1
  self.indexStart = 1

  self.pinOut.flow.value = false
  self.pinOut.loaded.value = false

  self.pinOut.start.value = nil
  self.pinOut.hiest.value = nil
  self.pinOut.escape.value = nil
end

function C:_executionStarted()
  self:resetData()
end

function C:resetData()
  self.spots = {}
  self.names = {}
  self.startLoc = {}
  self.hiestLoc = {}
  self.escapeLoc = {}
  self.start = nil
  self.hiest = nil
  self.escape = nil

  self.pinOut.flow.value = false
  self.pinOut.loaded.value = false
  self.state = 1
  self.indexStart = 1

  self.pinOut.start.value = nil
  self.pinOut.hiest.value = nil
  self.pinOut.escape.value = nil
end

function C:work()
  if self.pinIn.reset.value then
    self:resetData()
    return
  end
  if self.pinIn.flow.value then
    if self.state == 1 then
      self.spots = self.pinIn.sitesData.value.parkingSpots
      self.names = tableKeys(self.spots.byName)
      --SPLIT THE SPOTS USING TAGS
      for s,_ in ipairs(self.names) do
        if string.find(self.spots.byName[self.names[s]].customFields.sortedTags[1], "start") then
          table.insert(self.startLoc, self.names[s])
        elseif string.find(self.spots.byName[self.names[s]].customFields.sortedTags[1], "hiest") then
          table.insert(self.hiestLoc, self.names[s])
        elseif string.find(self.spots.byName[self.names[s]].customFields.sortedTags[1], "escape") then
          table.insert(self.escapeLoc, self.names[s])
        end
      end

      --RANDOMIZE ALL THE TABLES
      for i = #self.startLoc, 2, -1 do
        local j = math.random(i)
        self.startLoc[i], self.startLoc[j] = self.startLoc[j], self.startLoc[i]
      end
      for i = #self.hiestLoc, 2, -1 do
        local j = math.random(i)
        self.hiestLoc[i], self.hiestLoc[j] = self.hiestLoc[j], self.hiestLoc[i]
      end
      for i = #self.escapeLoc, 2, -1 do
        local j = math.random(i)
        self.escapeLoc[i], self.escapeLoc[j] = self.escapeLoc[j], self.escapeLoc[i]
      end

      --Assign the initial spots
      self.start, self.hiest, self.escape = self.spots.byName[self.startLoc[1]], self.spots.byName[self.hiestLoc[1]], self.spots.byName[self.escapeLoc[1]]
      self.state = 2
    elseif self.state == 2 then
      local vPos = vec3(self.pinIn.position.value)
      dump((self.start.pos - vPos):length())
      if (self.start.pos - vPos):length() > 400 then
        self.indexStart = self.indexStart + 1
        dump("skipping start...")
        self.start = self.spots.byName[self.startLoc[self.indexStart]]
      else
        self.pinOut.start.value = self.start.name
        self.state = 3
        self.indexStart = 1
      end
    elseif self.state == 3 then
      if (self.start.pos - self.hiest.pos):length() < 250 then
        self.indexStart = self.indexStart + 1
        dump("skipping hiest...")
        self.hiest = self.spots.byName[self.hiestLoc[self.indexStart]]
      else
        self.pinOut.hiest.value = self.hiest.name
        self.state = 4
        self.indexStart = 1
      end
    elseif self.state == 4 then
      if (self.hiest.pos - self.escape.pos):length() < 300 then
        self.indexStart = self.indexStart + 1
        dump("skipping escape...")
        self.escape = self.spots.byName[self.names[self.indexStart]]
      else
        self.pinOut.escape.value = self.escape.name
        self.state = 5
      end
    elseif self.state == 5 then
      table.sort(self.start.zones, function(a,b) return (a.customFields.values.prio or 1) < (b.customFields.values.prio or 1) end)
      table.sort(self.hiest.zones, function(a,b) return (a.customFields.values.prio or 1) < (b.customFields.values.prio or 1) end)
      table.sort(self.escape.zones, function(a,b) return (a.customFields.values.prio or 1) < (b.customFields.values.prio or 1) end)

      self.pinOut.startLocation.value = self.start.zones[1].name
      self.pinOut.hiestLocation.value = self.hiest.zones[1].name
      self.pinOut.escapeLocation.value = self.escape.zones[1].name

      self.pinOut.flow.value = true
      self.pinOut.loaded.value = true
      self.state = 6
    elseif self.state == 6 then
      self.pinOut.flow.value = true
      self.pinOut.loaded.value = false
    end
  end
end

return _flowgraph_createNode(C)
