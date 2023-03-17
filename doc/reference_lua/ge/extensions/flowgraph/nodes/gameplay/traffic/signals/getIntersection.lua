-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Get Intersection'
C.description = 'Gets intersection properties.'
C.color = ui_flowgraph_editor.nodeColors.signals
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'repeat_instant'
C.tags = {'traffic', 'signals'}


C.pinSchema = {
  {dir = 'in', type = 'table', name = 'signalsData', tableType = 'signalsData', description = 'Table of traffic signals data; use the File Traffic Signals node.'},
  {dir = 'in', type = 'string', name = 'name', description = 'Name of the intersection.'},
  {dir = 'in', type = 'number', name = 'nodeIndex', description = 'Intersection signal node index; if none given, the first one will be used.'},
  {dir = 'in', type = 'number', name = 'vehId', hidden = true, description = 'Vehicle Id to track for the intersection; sets and overrides the signal node index.'},
  {dir = 'out', type = 'vec3', name = 'pos', description = 'Intersection center position.'},
  {dir = 'out', type = 'vec3', name = 'stopPos', description = 'Intersection signal node position.'},
  {dir = 'out', type = 'vec3', name = 'dirVec', description = 'Intersection signal node direction vector.'},
  {dir = 'out', type = 'table', name = 'controllerData', tableType = 'signalControllerData', description = 'Signal controller data, to use with other signal nodes.'},
  {dir = 'out', type = 'number', name = 'phaseIndex', description = 'Current phase number of the signal controller.'}
}

C.dependencies = {'core_trafficSignals'}

function C:work(args)
  if self.pinIn.signalsData.value and self.pinIn.name.value then
    local signals = self.pinIn.signalsData.value
    if signals.intersections and signals.intersections[self.pinIn.name.value] then
      local inter = signals.intersections[self.pinIn.name.value]
      local idx = self.pinIn.nodeIndex.value or 1

      if self.pinIn.vehId.value then
        local veh = be:getObjectByID(self.pinIn.vehId.value)
        if veh then
          -- local vehPos = veh:getPosition() -- not sure if needed
          local vehDirVec = veh:getDirectionVector()
          local bestDot = -1

          for i, v in ipairs(inter.signalNodes) do
            if vehDirVec:dot(v.dir) > bestDot then
              bestDot = vehDirVec:dot(v.dir)
              idx = i
            end
          end
        end
      end

      local node = inter.signalNodes[idx]

      self.pinOut.pos.value = inter.pos
      self.pinOut.stopPos.value = node and node.pos or inter.pos
      self.pinOut.dirVec.value = node and node.dir or vec3(0, 0, 1)
      self.pinOut.controllerData.value = inter.control or {}
      self.pinOut.phaseIndex.value = node and node.signalIdx or 1
    end
  end
end

return _flowgraph_createNode(C)