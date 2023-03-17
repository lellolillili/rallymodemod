-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Get Cam Path'
C.description = "Lets the camera follow the path defined by a CameraPath object."
C.behaviour = { duration = true, once = true }
C.category = 'once_f_duration'
C.pinSchema = {
    { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
    { dir = 'in', type = 'flow', name = 'reset', description = 'Resets this node', impulse = true },
    { dir = 'in', type = 'number', name = 'id', description = 'Id of the camera path. If not set, uses the currently active camera path.' },

    { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
    { dir = 'out', type = 'flow', name = 'inactive', description = 'Outflow if the campath is not active or no campath is running.', hidden = true },

    { dir = 'out', type = 'flow', name = 'complete', description = 'Outflow if the campath is complete.' },
    { dir = 'out', type = 'flow', name = 'completed', impulse = true, description = 'Outflow once when the campath is complete.', hidden = true },
    { dir = 'out', type = 'flow', name = 'incomplete', description = 'Outflow once when the campath is active, but not complete.', hidden = true },
    { dir = 'out', type = 'number', name = 'duration', description = 'Duration of the path', hidden = true },

}

C.tags = {'campath','pathcam','path','camera'}
C.color = ui_flowgraph_editor.nodeColors.camera
C.icon = ui_flowgraph_editor.nodeIcons.camera
function C:init()
end

function C:_executionStarted()
    self.done = false
    self.completedFlag = nil
end

function C:_executionStopped()
end

function C:work()
    if self.pinIn.reset.value then
        self:_executionStarted()
    end
    self.pinOut.flow.value = self.pinIn.flow.value
    local active = self.mgr.modules.camera.activePathId and self.pinIn.id.value == self.mgr.modules.camera.activePathId
    local id = -1
    if active then
        id = self.pinIn.id.value or self.mgr.modules.camera.activePathId
    end
    if not self.pinIn.id.value then
        active = self.mgr.modules.camera.activePathId ~= nil
    end
    if self.pinIn.flow.value then

        if not active then
            self.pinOut.inactive.value = true
            self.pinOut.complete.value = false
            self.pinOut.completed.value = false
            self.pinOut.incomplete.value = false
            self.pinOut.duration.value = 0
        else
            self.pinOut.inactive.value = false
            self.pinOut.complete.value = self.mgr.modules.camera:isPathComplete(id)
            self.pinOut.completed.value = false
            if not self.completedFlag and self.pinOut.complete.value then
                self.pinOut.completed.value = true
                self.completedFlag = true
            end
            self.pinOut.incomplete.value = not self.pinOut.complete.value
            self.pinOut.duration.value = self.mgr.modules.camera:getPathDuration(id)
        end

    end
end

function C:drawMiddle(builder, style)
    builder:Middle()

end

return _flowgraph_createNode(C)
