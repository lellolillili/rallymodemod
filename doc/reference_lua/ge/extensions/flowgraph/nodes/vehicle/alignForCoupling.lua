-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Align for Coupling'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = "link"
C.behaviour = { duration = true, once = true }
C.description = [[Moves a trailer behind another vehicle so they can be couples more easily. Automatically enables coupling after placing.]]
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'reset', description = 'Resets this node.', impulse = true },
  { dir = 'in', type = 'number', name = 'vehId', description = 'ID of the pulling vehicle.' },
  { dir = 'in', type = 'number', name = 'trailerId', description = 'ID of the pulled vehicle, aka the trailer.' },
  { dir = 'in', type = { 'number', 'quat' }, name = 'rot', description = 'Rotation for the trailer. A number will rotate the trailer by n degrees relative to the pulling vehicle. A quaternion will set the trailer so it is rotated like the quaternion.', hidden = true, default = 0 },
  { dir = 'in', type = 'bool', name = 'relativeRotationQuat', description = 'If true, uses relative rotation instead of global rotation for the trailer, when using a quaternion.', hidden = true },
  { dir = 'in', type = 'bool', name = 'ignoreCouple', description = 'If checked, does not automatically enable the coupling for the vehicles.', default = true, hidden = true },


  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node, only when vehicles were successfully coupled.' },
}

C.tags = {'rotation', 'position', 'couple'}

function C:init()

end
function C:_executionStarted()
  self.done = nil
  self.waitForCouple = nil
  self.coupled = nil
end
function C:work()
  if self.pinIn.reset.value then
    self.done = nil
    self.waitForCouple = nil
    self.coupled = nil
    self.pinOut.flow.value = false
  end
  if self.pinIn.flow.value then
    if not self.done then
      local v1, v2
      if self.pinIn.vehId.value then
        v1 = scenetree.findObjectById(self.pinIn.vehId.value)
      end
      if self.pinIn.trailerId.value then
        v2 = scenetree.findObjectById(self.pinIn.trailerId.value)
      end
      if not v1 or not v2 then
        return
      end
      local v1Off = self.mgr.modules.vehicle:getVehicle(v1:getID()).couplerOffset[1]
      local v2Off = self.mgr.modules.vehicle:getVehicle(v2:getID()).couplerOffset[1]
      if not v1Off or not v2Off then
        return
      end
      v1Off = v1Off.v
      v2Off = v2Off.v



      local v1CouplerMatrix = nil
      local v1OffMatrix = MatrixF(true)
      v1OffMatrix:setColumn(3, v1Off)
      v1CouplerMatrix = v1:getRefNodeMatrix() * v1OffMatrix -- matrix to the v1 Coupler Point

      local v2OffMatrix = MatrixF(true)
      v2OffMatrix:setColumn(3, v2Off)

      local v2Ref = v2:getRefNodeMatrix()
      local v2CouplerMatrix = v2Ref * v2OffMatrix

      local rotMatrix = MatrixF(true)
      if self.pinIn.rot.value then
        local desiredRot = quat()
        if type(self.pinIn.rot.value) == 'number' then
          desiredRot = quatFromEuler(0,0,self.pinIn.rot.value/180 * math.pi)
        elseif type(self.pinIn.rot.value) == 'table' then
          desiredRot = quat(self.pinIn.rot.value)
        end
        if self.pinIn.relativeRotationQuat.value then
          desiredRot = desiredRot * quatFromDir(vec3(v1:getDirectionVector()), vec3(v1:getDirectionVectorUp()))
        else
          desiredRot = desiredRot
        end
        rotMatrix:setColumn(0, (desiredRot * vec3(1,0,0)))
        rotMatrix:setColumn(1, (desiredRot * vec3(0,1,0)))
        rotMatrix:setColumn(2, (desiredRot * vec3(0,0,1)))
      end

      --debugDrawer:drawSphere(vec3(v1CouplerMatrix:getColumn(3)), 4, ColorF(1,0.0,0.48,0.5))
      --debugDrawer:drawSphere(vec3(v2CouplerMatrix:getColumn(3)), 4, ColorF(0,0.05,0.48,0.5))

      local res = v1CouplerMatrix * (rotMatrix * v2CouplerMatrix:inverse() * v2:getRefNodeMatrix())
      --debugDrawer:drawSphere(vec3(res:getColumn(3)), 1, ColorF(0.91,1,0.48,0.5))
      if self.pinIn.ignoreCouple.value then
        self.coupled = true
      else
        v2:setTransform(res)
        v2:queueLuaCommand('obj:requestReset(RESET_PHYSICS)')
        v2:resetBrokenFlexMesh()
        v1:queueLuaCommand('beamstate.activateAutoCoupling()')
        self.waitForCouple = true
      end
      self.done = true
    end
    if self.waitForCouple then
      self.coupled = self.mgr.modules.vehicle:isCoupledTo(self.pinIn.vehId.value, self.pinIn.trailerId.value)
      if self.coupled then
        self.waitForCouple = nil
      end
    end
    if self.coupled then
      self.pinOut.flow.value = self.pinIn.flow.value
    end
  end
end



return _flowgraph_createNode(C)
