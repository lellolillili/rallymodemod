-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Blacklist Walking'
C.description = 'Allows or denies a vehicle to be entered from walking mode.'
C.color = ui_flowgraph_editor.nodeColors.walking
C.icon = ui_flowgraph_editor.nodeIcons.walking
-- C.category = 'rework_needed'
C.pinSchema = {
    { dir = 'in', type = 'flow', name = 'flow', description = "Inflow for this node." },
    { dir = 'in', type = 'flow', name = 'allow', description = "Removes this vehicle from the blacklist, so it can be entered." },
    { dir = 'in', type = 'flow', name = 'deny', description = "Adds this vehicle to the blacklist, so it cannot be entered." },
    { dir = 'in', type = 'number', name = 'vehId', description = "The Id of the vehicle that should be allowed/denied." },
    { dir = 'in', type = 'flow', name = 'clear', description = "Removes all vehicles from the blacklist.", hidden = true, impulse = true },
    { dir = 'in', type = 'flow', name = 'fill', description = "Adds all vehicles currently managed by the current project to the blacklist.", hidden = true },
    { dir = 'in', type = 'flow', name = 'fillAll', description = "Adds all vehicles available in the scenetree to the blacklist.", hidden = true },
    { dir = 'out', type = 'flow', name = 'flow', description = "Outflow for this node." },
}
C.dependencies = {'gameplay_walk'}
function C:init(mgr, ...)
end

function C:work(args)
  if self.pinIn.flow.value then
    if self.pinIn.vehId.value then
      if self.pinIn.allow.value then
        gameplay_walk.removeVehicleFromBlacklist(self.pinIn.vehId.value)
      end
      if self.pinIn.deny.value then
        gameplay_walk.addVehicleToBlacklist(self.pinIn.vehId.value)
      end
    end
    if self.pinIn.clear.value then
      gameplay_walk.clearBlacklist()
    end
    if self.pinIn.fill.value then
      gameplay_walk.clearBlacklist()
      for _, id in ipairs(self.mgr.modules.vehicle.sortedIds) do
        gameplay_walk.addVehicleToBlacklist(sortedIds)
      end
    end
    if self.pinIn.fillAll.value then
      gameplay_walk.clearBlacklist()
      for _, name in ipairs(scenetree.findClassObjects("BeamNGVehicle")) do
        local obj = scenetree.findObject(name)
        if obj then
          gameplay_walk.addVehicleToBlacklist(obj:getId())
        end
      end
    end
  end
  self.pinOut.flow.value = self.pinIn.flow.value
end

return _flowgraph_createNode(C)
