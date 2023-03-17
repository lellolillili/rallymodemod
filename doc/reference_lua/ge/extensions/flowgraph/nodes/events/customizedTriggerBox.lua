-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local triggerTypeNames = {"Box", "Sphere"}

local C = {}

C.name = 'Custom Trigger'
C.color = ui_flowgraph_editor.nodeColors.event
C.icon = ui_flowgraph_editor.nodeIcons.event
C.description = 'Creates a trigger for the time of the execution of the project.'
C.category = 'repeat_instant'

C.todo = "Maybe this should be merges with the onBeamNGTrigger node. Currently only works when a vehicle ID is supplied."
C.pinSchema = {
  {dir = 'in', type = 'vec3', name = 'position', description = "The position of this trigger."},
  {dir = 'in', type = 'quat', name = 'rotation', description = "The orientation of this trigger (if box)"},
  {dir = 'in', type = {'number','vec3'}, name = 'scale', description = "The scale of this trigger."},
  {dir = 'in', type = 'number', name = 'vehId', description = "The ID of the target vehicle. These kind of trigger each only work on exactly one vehicle at a time."},
  {dir = 'out', type = 'flow', name = 'enter', description = "Triggers once when the vehicle enters the trigger.", impulse = true},
  {dir = 'out', type = 'flow', name = 'inside', description = "Gives flow as long as the vehicle is inside the trigger."},
  {dir = 'out', type = 'flow', name = 'outside', description = "Gives flow as long as the vehicle is outside the trigger."},
  {dir = 'out', type = 'flow', name = 'exit', description = "Triggers once when the vehicle exits the trigger.", impulse = true},
  {dir = 'out', type = 'number', name = 'vehId', description = "The vehicle this trigger is for."},
}
C.legacyPins = {
  _in = {
    vehicleId = 'vehId'
  },
  out = {
    vehicleId = 'vehId'
  }
}

C.tags = {}

function C:init(mgr, ...)
  self.enterFlag = false
  self.exitFlag = false
  self.vehInside = false
  self.oldPos = nil
  self.oldScl = nil
  self.triggerType = triggerTypeNames[1]
  self.data.debug = false
end

function C:_executionStarted()
  self.enterFlag = false
  self.exitFlag = false
  self.vehInside = false
  self.dirty = true
  self.wheelOffsets = nil
  self.currentCorners = nil
  self.previousCorners = nil
end

function C:_executionStopped()
  self.oldPos = nil
  self.oldScl = nil
  self._points = nil
end


function C:checkIntersections()
  local inside = false
  for i = 1, #self.currentCorners do
    local cPos = self.currentCorners[1]
    if self.trigger.type == 'Box' then
      --debugDrawer:drawSphere(vec3(cPos), 0.5, ColorF(0.91,0.05,0.48,0.5))
      inside = inside or containsOBB_point(self.trigger.pos, self.trigger.x, self.trigger.y, self.trigger.z, cPos)
    else
      --dump("Checking: " .. dumps(cPos))
      --dump("Against: " ..dumps(self.trigger.pos) .. " X: " .. dumps(self.trigger.x) .. "  Y: " .. dumps(self.trigger.y) .. "  Z:".. dumps(self.trigger.z))
      --dump("Result is: " .. (containsEllipsoid_Point(self.trigger.pos, self.trigger.x, self.trigger.y, self.trigger.z, cPos) and "True" or "False"))
      inside = inside or containsEllipsoid_Point(self.trigger.pos, self.trigger.x, self.trigger.y, self.trigger.z, cPos)
    end
    if inside then break end
  end

  self.enterFlag = false
  self.exitFlag = false

  if not self.vehInside and inside then
    self.enterFlag = true
  end
  if self.vehInside and not inside then
    self.exitFlag = true
  end
  self.vehInside = inside
end

function C:work(args)
  if self.pinIn.position.value and self.oldPos and self.oldPos ~= self.pinIn.position.value then
      self.dirty = true
  end
  if self.pinIn.scale.value and self.oldScl and self.pinIn.scale.value ~= self.oldScl then
      self.dirty = true
  end
  if self.pinIn.rotation.value and self.oldRot and self.pinIn.rotation.value ~= self.oldRot then
      self.dirty = true
  end

  if self.dirty then
    local trigger = {
      pos = vec3(self.pinIn.position.value or {0,0,0}),
      rot = quat(self.pinIn.rotation.value or {0,0,0,0})
    }
    local scl = self.pinIn.scale.value or 1
    if type(scl) == 'table' then
      trigger.scl = vec3(self.pinIn.scale.value)
    else
      trigger.scl = vec3(self.pinIn.scale.value, self.pinIn.scale.value, self.pinIn.scale.value)
    end
    trigger.type = self.triggerType
    --if trigger.type == 'Box' then
      trigger.x = trigger.rot * vec3(trigger.scl.x,0,0)
      trigger.y = trigger.rot * vec3(0,trigger.scl.y,0)
      trigger.z = trigger.rot * vec3(0,0,trigger.scl.z)
    --end
    self.oldPos = self.pinIn.position.value
    self.oldRot = self.pinIn.rotation.value
    self.oldScl = self.pinIn.scale.value
    self.dirty = false
    self.trigger = trigger
  end
  local vehId = self.pinIn.vehId.value or be:getPlayerVehicleID(0)
  if vehId then
    local vehicle = map.objects[vehId]

    if vehicle then
      if not self.wheelOffsets then
        self.wheelOffsets = {}
        self.currentCorners = {}
        self.previousCorners = {}
        --[[
        local wCount = vehicle:getWheelCount()-1
        if wCount > 0 then
          local vehiclePos = vehicle:getPosition()
          local vRot = quatFromDir(vehicle:getDirectionVector(), vehicle:getDirectionVectorUp())
          local x,y,z = vRot * vec3(1,0,0),vRot * vec3(0,1,0),vRot * vec3(0,0,1)
          --local oobbz = vec3(vehicle:getSpawnWorldOOBB():getHalfExtents()).z/2
          for i=0, wCount do
            local axisNodes = vehicle:getWheelAxisNodes(i)
            local nodePos = vec3(vehicle:getNodePosition(axisNodes[1]))
            local pos = vec3(nodePos:dot(x), nodePos:dot(y), nodePos:dot(z))
            table.insert(self.wheelOffsets, pos)
            table.insert(self.currentCorners, vRot*pos + vehiclePos)
            --table.insert(self.previousCorners, vRot*pos + vehiclePos)
          end
        end]]
      end

      --local vPos = vehicle:getPosition()
      --local vRot = quatFromDir(vehicle:getDirectionVector(), vehicle:getDirectionVectorUp())
      --for i, corner in ipairs(self.wheelOffsets) do
        --self.previousCorners[i]:set(self.currentCorners[i])
      --  self.currentCorners[i]:set(vPos + vRot*corner)
      --end
      --self.currentCorners = {}
      self.currentCorners[1] = vehicle.pos
      self:checkIntersections()
    else
      self.wheelOffsets = nil
      self.currentCorners = nil
      self.previousCorners = nil
    end
  else
    self.wheelOffsets = nil
    self.currentCorners = nil
    self.previousCorners = nil
  end

  self.pinOut.inside.value = self.vehInside
  self.pinOut.outside.value = not self.vehInside
  self.pinOut.enter.value = self.enterFlag
  self.pinOut.exit.value = self.exitFlag
  self.pinOut.vehId.value = vehId

  if self.trigger and self.data.debug then
    if self.trigger.type == 'Box' then
      self:drawAxisBox(self.trigger.pos - (self.trigger.x + self.trigger.y + self.trigger.z), self.trigger.x*2, self.trigger.y*2, self.trigger.z*2, ColorI(255, 128, 128, 64))
    elseif self.trigger.type == 'Sphere' then
      debugDrawer:drawSphere(self.trigger.pos, self.trigger.x:length(), ColorF(1,0.5,0.5,0.25))
    end
  end
end


function C:drawAxisBox(corner, x, y, z, clr)
  -- draw all faces in a loop
  for _, face in ipairs({{x,y,z},{x,z,y},{y,z,x}}) do
    local a,b,c = face[1],face[2],face[3]
    -- spokes
    debugDrawer:drawLine((corner    ), (corner+c    ), ColorF(0,0,0,0.75))
    debugDrawer:drawLine((corner+a  ), (corner+c+a  ), ColorF(0,0,0,0.75))
    debugDrawer:drawLine((corner+b  ), (corner+c+b  ), ColorF(0,0,0,0.75))
    debugDrawer:drawLine((corner+a+b), (corner+c+a+b), ColorF(0,0,0,0.75))
    -- first side
    debugDrawer:drawTriSolid(
      vec3(corner    ),
      vec3(corner+a  ),
      vec3(corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(corner+b  ),
      vec3(corner    ),
      vec3(corner+a+b),
      clr)
    -- back of first side
    debugDrawer:drawTriSolid(
      vec3(corner+a  ),
      vec3(corner    ),
      vec3(corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(corner    ),
      vec3(corner+b  ),
      vec3(corner+a+b),
      clr)
    -- other side
    debugDrawer:drawTriSolid(
      vec3(c+corner    ),
      vec3(c+corner+a  ),
      vec3(c+corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(c+corner+b  ),
      vec3(c+corner    ),
      vec3(c+corner+a+b),
      clr)
    -- back of other side
    debugDrawer:drawTriSolid(
      vec3(c+corner+a  ),
      vec3(c+corner    ),
      vec3(c+corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(c+corner    ),
      vec3(c+corner+b  ),
      vec3(c+corner+a+b),
      clr)
  end
end


function C:drawCustomProperties()
  local reason = nil
  im.PushID1("LAYOUT_COLUMNS")
  im.Columns(2, "layoutColumns")
  im.Text("Status")
  im.NextColumn()
  if im.BeginCombo("##triggerType", self.triggerType) then
    for _,triggerType in ipairs(triggerTypeNames) do
      if im.Selectable1(triggerType, triggerType == self.triggerType) then
        self.triggerType = triggerType
        reason = "Changed Trigger Type to " .. triggerType
      end
    end
    im.EndCombo()
  end
  im.Columns(1)
  im.PopID()
  return reason
end

function C:drawMiddle(builder, style)
  builder:Middle()
end

function C:_onSerialize(res)
  res.triggerType = self.triggerType
end

function C:_onDeserialized(res)
  if res.triggerType then
    self.triggerType = res.triggerType
  end
end

return _flowgraph_createNode(C)
