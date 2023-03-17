-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Position in Zone'
C.description = 'Checks if a position is inside of a zone, by using Sites data.'
C.category = 'repeat_instant'

C.color = ui_flowgraph_editor.nodeColors.sites
C.pinSchema = {
  { dir = 'in', type = 'table', name = 'sitesData', tableType = "sitesData", description = 'Data from the sites.', matchName = true },
  { dir = 'in', type = 'string', name = 'zoneName', description = 'Name of the Zone' },
  { dir = 'in', type = 'vec3', name = 'pos', description = 'Position to be tested' },
  { dir = 'out', type = 'flow', name = 'enter', description = 'When pos was outside last frame and inside this frame.', impulse = true },
  { dir = 'out', type = 'flow', name = 'inside', description = 'When pos is inside zone.' },
  { dir = 'out', type = 'flow', name = 'exit', description = 'When pos was inside last frame and outside this frame.', impulse = true },
  { dir = 'out', type = 'flow', name = 'outside', description = 'When pos is outside of zone.' }
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
  if editor_sitesEditor then
    local cZone = editor_sitesEditor.getCurrentZone()
    if cZone then
      im.Text("Currently selected Zone in editor:")
      im.Text(cZone.name)
      if im.Button("Hardcode to zoneName Pin") then
        self:_setHardcodedDummyInputPin(self.pinInLocal.zoneName, cZone.name)
      end
    end
  end
end

function C:_executionStarted()
  self._lastInside = nil
end

function C:work(args)
  if self.pinIn.sitesData.value then
    local zone = self.pinIn.sitesData.value.zones.byName[self.pinIn.zoneName.value]
    if not zone.missing then
      local inside = zone:containsPoint2D(vec3(self.pinIn.pos.value))
      self.pinOut.inside.value = inside
      self.pinOut.outside.value = not inside

      if self._lastInside ~= nil then
        if self._lastInside == true and not inside then
          self.pinOut.enter.value = false
          self.pinOut.exit.value = true
        elseif self._lastInside == false and inside then
          self.pinOut.enter.value = true
          self.pinOut.exit.value = false
        else
          self.pinOut.enter.value = false
          self.pinOut.exit.value = false
        end
      end
      self._lastInside = inside
    else
      dump("Zone Missing: " .. self.pinIn.zoneName.value)
    end
  else
     dump("No Zonedata")
  end
end

return _flowgraph_createNode(C)
