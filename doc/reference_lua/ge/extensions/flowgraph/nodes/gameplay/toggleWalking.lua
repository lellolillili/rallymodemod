-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = 'Toggle Walking'
C.description = 'Enters or exits the walking mode.'
C.color = ui_flowgraph_editor.nodeColors.walking
C.icon = ui_flowgraph_editor.nodeIcons.walking
C.category = 'repeat_instant'
C.pinSchema = {
    { dir = 'in', type = 'flow', name = 'enterWalking', description = "Attempts to enter walking mode. No effect if the player is already walking, cannot leave the vehicle or other reasons that would prevent the player from entering walking mode.", impulse = true },
    { dir = 'in', type = 'flow', name = 'exitWalking', description = "Attempts to exit walking mode by entering the closest vehicle. No Effect if there is not stationary vehicle, or the player can't enter a vehicle for other reasons.", impulse = true },
    { dir = 'in', type = 'vec3', name = 'pos', description = 'The position when entering walking mode. Optional.', hidden = true },
    { dir = 'in', type = 'quat', name = 'rot', description = 'The rotation when entering walking mode. Optional.', hidden = true },
    { dir = 'out', type = 'flow', name = 'success', impulse = true, description = "Outflow if the player successfully entered or exited the vehicle." },
    { dir = 'out', type = 'flow', name = 'fail', impulse = true, description = "Outflow if the player could not enter or exit the vehicle for any reason." },
}
C.dependencies = { 'gameplay_walk' }

function C:work(args)
    self.pinOut.success.value = false
    self.pinOut.fail.value = false
    if self.pinIn.enterWalking.value then
        local pos = self.pinIn.pos.value and vec3(self.pinIn.pos.value) or nil
        local rot = self.pinIn.rot.value and quat(self.pinIn.rot.value) or nil
        local succ, id = gameplay_walk.setWalkingMode(true, pos, rot)
        if succ then
            if id then
                self.mgr.modules.vehicle:addVehicle(scenetree.findObjectById(id), { ignoreReadyUp = true })
            end
        end
        self.pinOut.success.value = succ
        self.pinOut.fail.value = not succ
    end
    if self.pinIn.exitWalking.value then
        local succ, id = gameplay_walk.setWalkingMode(false)
        self.pinOut.success.value = succ
        self.pinOut.fail.value = not succ
    end
end

return _flowgraph_createNode(C)
