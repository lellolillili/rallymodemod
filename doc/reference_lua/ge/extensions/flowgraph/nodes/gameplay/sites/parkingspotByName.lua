-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Parking Spot by Name'
C.description = 'Finds a single Parking Spot by Name.'
C.color = ui_flowgraph_editor.nodeColors.sites
C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.'},
  {dir = 'in', type = 'table', name = 'sitesData', tableType = 'sitesData', description = 'Sites Data.'},
  {dir = 'in', type = 'string', name = 'spotName', description = 'Name of the Zone'},
  {dir = 'out', type = 'flow', name = 'flow', description = 'Outflow from this node.'},
  {dir = 'out', type = 'bool', name = 'exists', description = 'True if the spot is missing or cannot be found.', hidden=true},
  {dir = 'out', type = 'table', name = 'spot', tableType = 'parkingSpotData', description = 'Parking Spot Data.'},
}

C.tags = {'scenario'}


function C:init(mgr, ...)

end
function C:drawCustomProperties()
  if im.Button("Open Sites Editor") then
    if editor_sitesEditor then
      editor_sitesEditor.show()
    end
  end
end

function C:_executionStarted()
  self._spot = nil
end

function C:work(args)
  if self.pinIn.flow.value then
    if self.pinIn.spotName.value then
      local loc = self.pinIn.sitesData.value.parkingSpots.byName[self.pinIn.spotName.value]
      if loc ~= self._spot then
        self._spot = loc
      end
    end
  end
  self.pinOut.spot.value = self._spot
  self.pinOut.flow.value = false
  if self._spot and not self._spot.missing then
    self.pinOut.flow.value = true
  end
  self.pinOut.exists.value = self.pinOut.flow.value
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.TextUnformatted((self._spot and (not self._spot.missing)) and "S" or "X")
end



return _flowgraph_createNode(C)
