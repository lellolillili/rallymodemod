-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = 'Procedural Static CamPath'
C.description = "Creates a campath that shows a static position."
C.pinSchema = {
    { dir = 'in', type = 'vec3', name = 'pos', description = 'Position' },
    { dir = 'in', type = 'quat', name = 'rot', description = 'rotation' },
    { dir = 'out', type = 'string', name = 'pathName', description = 'Name of the camera path.' },
}
C.category = 'once_p_duration' -- technically f_duration, but no callback for completion right now

C.tags = {}
C.color = ui_flowgraph_editor.nodeColors.camera
C.icon = ui_flowgraph_editor.nodeIcons.camera

function C:workOnce()
    -- default values for path and marker.
    local m = { fov = 60, movingEnd = true, movingStart = true, pos = {}, rot = {}, time = 0, trackPosition = false }
    local path = { looped = false, manualFov = false, markers = {} }
    local duration = 1000

    local from = deepcopy(m)
    from.pos = vec3(self.pinIn.pos.value)
    from.rot = quat(self.pinIn.rot.value)
    from.time = duration

    path.markers = { deepcopy(from), deepcopy(from) }

    local name = self.mgr.modules.camera:getUniqueName(self.id .. "pcp")
    local id = self.mgr.modules.camera:addCustomPath(name, path, true)
    self.pinOut.pathName.value = name

end

return _flowgraph_createNode(C)