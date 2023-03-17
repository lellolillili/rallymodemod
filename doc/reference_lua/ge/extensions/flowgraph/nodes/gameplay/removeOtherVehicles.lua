-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

local pinName = 'idToIgnore_'

C.name = 'Remove Other Vehicles'
C.description = 'Will remove every vehicles except from the one(s) specified'
C.todo = "Vehicles spawned outside the FG won't be removed"
C.category = 'once_instant'

C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.pinSchema = {
  {dir = 'in', type = 'number', name = pinName..'1', description= "Vehicle id that won't be removed"},
}


function C:init()
  self.count = 1
end

function C:drawCustomProperties()
  local reason = nil
  im.PushID1("LAYOUT_COLUMNS")
  im.Columns(2, "layoutColumns")
  im.Text("Count")
  im.NextColumn()
  local ptr = im.IntPtr(self.count)
  if im.InputInt('##count'..self.id, ptr) then
    if ptr[0] < 1 then ptr[0] = 1 end
    self:updatePins(self.count, ptr[0])
    reason = "Changed Value count to " .. ptr[0]
  end
  im.Columns(1)
  im.PopID()
  return reason
end

function C:updatePins(old, new)
  if new < old then
    for i = old, new+1, -1 do
      for _, lnk in pairs(self.graph.links) do
        if lnk.targetPin == self.pinInLocal[pinName..i] then
          self.graph:deleteLink(lnk)
        end
      end
      self:removePin(self.pinInLocal[pinName..i])
    end
  else
    for i = old+1, new do
      --direction, type, name, default, description, autoNumber
      self:createPin('in','number',pinName..i)
    end
  end
  self.count = new
end

function C:workOnce()
  local everyVehicleId = self.mgr.modules.vehicle:getSpawnedVehicles()

  gameplay_traffic.deleteVehicles()

  if #everyVehicleId == 0 then
    return
  end

  for _, id in ipairs(everyVehicleId) do
    local delete = true

    -- if there's at least one value to ignore
    if self.pinIn[pinName..1].value or self.count >= 1 then
      for i = 1, self.count do
        if self.pinIn[pinName..i].value == id then
          delete = false
          break;
        end
      end
    end

    if delete then
      local source = scenetree.findObjectById(id)

      if source then
        if editor and editor.onRemoveSceneTreeObjects then
          editor.onRemoveSceneTreeObjects({source:getId()})
        end
        source:delete()
      end
    end
  end
end

return _flowgraph_createNode(C)
