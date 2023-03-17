-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

--require('/lua/vehicle/controller')

local C = {}

C.name = 'KnockAway Check'
--C.color = ui_flowgraph_editor.nodeColors.ai
--C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Detects if vehicles from a prefab have been knocked away.'
C.todo = ""
C.category = 'repeat_instant'

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = "Inflow for this node."},
  {dir = 'in', type = 'flow', name = 'reset', description = "Reset this node", impulse=true},
  {dir = 'in', type = 'number', name = 'prefabId', description = 'Id of the prefab.'},
  {dir = 'in', type = 'bool', name = 'considerTipping', description = 'If true, vehicles will be considered knocked away if they are tipped.', hardcoded=true, default=true, hidden=true},
  {dir = 'in', type = 'number', name = 'tippingMinAngle', description = 'minimum tipping amount in angles.', hardcoded=true, hidden=true, default = 45},
  {dir = 'in', type = 'bool', name = 'considerMoving', description = 'If true, vehicles will be considered knocked away if they are moved from their original position.',default=true, hardcoded=true, hidden=true},
  {dir = 'in', type = 'number', name = 'movingMinDist', description = 'minimum moving distance in meters.', hardcoded=true, hidden=true, default = 1},


  {dir = 'in', type = 'bool', name = 'showMarkers', description = 'If true, shows a marker above the target.', hardcoded=true, default=true, hidden=true},
  --{dir = 'in', type = 'number', name = 'markerHeight', description = 'distance of the markers.', hardcoded=true, hidden=true, default = 2},
  {dir = 'out', type = 'flow', name = 'flow', description = "Outflow for this node."},
  {dir = 'out', type = 'flow', name = 'done', description = "Outflow when all vehicles have been knocked away."},
  {dir = 'out', type = 'number', name = 'count', description = "Number of vehicles knocked away."},
  {dir = 'out', type = 'number', name = 'total', description = "Total number of vehicles detected."},
  {dir = 'in', type = 'number', name = 'defaultPoints', description = "Default Points per vehicle", hidden=true},
  {dir = 'out', type = 'number', name = 'points', description = "Number of vehicles knocked away.", hidden=true},
  {dir = 'out', type = 'number', name = 'maxPoints', description = "Total number of vehicles detected.", hidden=true},

}

function C:_executionStarted()

end

function C:init()
  self.data.zOffset = 0
end

function C:_executionStopped()
  if self.markers then
    self.markers.onClientEndMission()
    self.markers = nil
  end
end

function C:getOriginalVehicleTransforms(data)
  local transforms = {}
  for _, id in ipairs(data.allChildrenIds['BeamNGVehicle'] or {}) do
    local veh = scenetree.findObjectById(id)
    if veh then
      veh = Sim.upcast(veh)
      transforms[id] = {
        pos = veh:getPosition(),
        rot = quat(veh:getRotation()),
        up = veh:getDirectionVectorUp()
      }
      self.mgr.modules.vehicle:addVehicle(veh)
    end
  end
  return transforms
end

function C:work()
  if self.pinIn.reset.value then
    self.done = false
    self:_executionStopped()
  end

  if self.pinIn.flow.value and self.pinIn.prefabId.value then
    local prefabData = self.mgr.modules.prefab:getPrefab(self.pinIn.prefabId.value)
    if not self.done then
      self.vehicleHit = {}
      self.vehiclePoints = {}
      self.totalCount = 0
      self.hitCount = 0
      self.currentPoints = 0
      self.pinOut.maxPoints.value = 0
      self.originalVehicleTransforms = self:getOriginalVehicleTransforms(prefabData)
      for id, val in pairs(prefabData.originalVehicleTransforms) do
        if be:getObjectByID(id) then
          self.vehicleHit[id] = false
          local veh = scenetree.findObjectById(id)
          local pts = tonumber(veh:getDynDataFieldbyName("knockAwayPoints", 0)) or self.pinIn.defaulPoints.value or 1
          self.vehiclePoints[id] = pts
          self.pinOut.maxPoints.value = self.pinOut.maxPoints.value + pts
          self.totalCount = self.totalCount + 1
        end
      end

      if self.pinIn.showMarkers.value and self.markers == nil then
        self.markers = require('scenario/race_marker')
        self.markers.init()
        local wps = {}
        local modes = {}
        for id, val in pairs(self.originalVehicleTransforms) do
          table.insert(wps, {name = id, pos = val.pos + vec3(0,0,self.data.zOffset), radius = 1})
          modes[id] = 'default'
        end
        self.markers.setupMarkers(wps,'overhead')
        self.markers.setModes(modes)
      end

      self.done = true
    end
    --dump(resetData)
    local change, changed  = {}, false
    for id, val in pairs(self.originalVehicleTransforms) do
      change[id] = 'hidden'
      if not self.vehicleHit[id] and be:getObjectByID(id) then
        local mapData = map.objects[id]
        if not mapData then
          be:getObjectByID(id):queueLuaCommand('mapmgr.enableTracking()')
        end
        if mapData then
          local tipped = false
          if self.pinIn.considerTipping.value then
            local up = mapData.dirVecUp
            if up:dot(val.up) < (math.pi * self.pinIn.tippingMinAngle.value / 180) then
              tipped = true
            end
          end
          if self.pinIn.considerMoving.value then
            if (mapData.pos - val.pos):length() > self.pinIn.movingMinDist.value then
              tipped = true
            end
          end
          if tipped then
            self.vehicleHit[id] = true
            self.hitCount = self.hitCount+1
            self.currentPoints = self.currentPoints + (self.vehiclePoints[id] or 1)
            changed = true
            change[id] = 'hidden'
          else
            change[id] = 'default'
          end
        else
          print("no mapdata!")
        end
      end
    end
    if self.markers and changed then
      self.markers.setModes(change)
    end
  end
  self.pinOut.count.value = self.hitCount or 0
  self.pinOut.total.value = self.totalCount or -1
  self.pinOut.points.value = self.currentPoints or 0
  self.pinOut.done.value = self.hitCount == self.totalCount
  self.pinOut.flow.value = self.pinIn.flow.value
end

function C:onPreRender(dt, dtSim)
  if self.markers then
    self.markers.render(dt, dtSim)
  end
end

return _flowgraph_createNode(C)
