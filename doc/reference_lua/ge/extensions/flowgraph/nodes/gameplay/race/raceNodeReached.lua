-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Race Pathnode Reached'
C.description = 'Lets the flow through when a vehicle reaches any pathnode.'
C.category = 'logic'

C.color = im.ImVec4(1, 1, 0, 0.75)
C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.'},
  {dir = 'in', type = 'table', name = 'raceData', tableType = 'raceData', description = 'Data from the race for other nodes to process.'},
  {dir = 'in', type = 'number', name = 'vehId', description = 'The Vehicle that should be tracked.'},
  {dir = 'out', type = 'flow', name = 'flow', description = 'Outflow from this node.', fixed = true},
  {dir = 'out', type = 'string', name = 'nodeName', description = 'Name of the node that has been reached.', fixed = true},
}

C.tags = {'scenario'}

C.allowedManualPinTypes = {
  flow = false,
  string = true,
  number = true,
  bool = false,
  any = false,
  table = false,
  vec3 = false,
  quat = false,
  color = false,
}
function C:init(mgr, ...)
  self.data.detailed = false
  self.allowCustomOutPins = true
  self.savePins = true
end

function C:drawMiddle(builder, style)

end

function C:work(args)
  self.race = self.pinIn.raceData.value
  if not self.race or not self.pinIn.vehId.value then return end
  local events = self.race.states[self.pinIn.vehId.value].events
  if not events then return end
  if events.pathnodeReached then
    local pn = self.race.path.pathnodes.objects[events.pathnodeReachedId]
    self.pinOut.flow.value = true
    self.pinOut.nodeName.value = pn.name

    for name, pin in pairs(self.pinOut) do
      if not pin.fixed then
        local val, valType, succ = pn.customFields:get(name)
        if succ and pin.type == valType then
          pin.value = val
        end
      end
    end
  else
    self.pinOut.flow.value = false
    self.pinOut.nodeName.value = nil
    for name, pin in pairs(self.pinOut) do
      if not pin.fixed then pin.value = nil end
    end
  end
end




return _flowgraph_createNode(C)
