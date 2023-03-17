-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = 'Procedural Direct Campath'
C.description = "Creates a campath that shows you the direct path from one position to another."
C.pinSchema = {
    { dir = 'in', type = 'vec3', name = 'from', description = 'Start of the path.' },
    { dir = 'in', type = 'vec3', name = 'to', description = 'End of the path.' },
    { dir = 'in', type = 'bool', name = 'loop', description = 'If the path should loop.', hardcoded = true, default = false, hidden = true },
    { dir = 'in', type = 'number', name = 'duration', description = 'Total duration', hardcoded = true, default = 14, hidden = true },
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
    local duration = self.pinIn.duration.value or 14
    -- some helper values.
    local fwd = vec3(self.pinIn.to.value) - vec3(self.pinIn.from.value)
    fwd.z = 0
    local fLen = clamp(fwd:length(), 300, 1000)
    fwd = fwd:normalized()
    local fq = quatFromEuler(math.pi / 4, 0, 0) * quatFromDir(fwd)
    local d = fq * vec3(0, -12, 0)

    local from = deepcopy(m)
    from.pos = vec3(deepcopy(self.pinIn.from.value)) + d
    from.rot = fq
    from.time = duration / 14 * 1
    from.movingStart = false

    local from2 = deepcopy(m)
    from2.pos = vec3(deepcopy(self.pinIn.from.value)) + d * 1.25
    from2.rot = fq
    from2.time = duration / 14 * 3
    from2.movingStart = false

    local mid = deepcopy(m)
    mid.pos = (vec3(self.pinIn.from.value)) + vec3(0, 0, 180) + d * 3

    -- some helper vectors to get the correct rotation
    local tt = (vec3(deepcopy(self.pinIn.to.value)) - mid.pos):normalized()
    local tx = tt:cross(vec3(0, 0, 1))
    local tu = tx:cross(tt)

    mid.rot = (quatFromEuler(math.pi * 0.3, 0, 0) * quatFromDir(fwd)):slerp(quatFromDir(tt, tu), 1)
    mid.time = duration / 14 * 7
    mid.movingStart = false

    local mid2 = deepcopy(m)
    mid2.pos = mid.pos
    mid2.rot = quatFromDir(tt, tu)
    mid2.time = duration / 14 * 10.5
    mid2.fov = 50
    mid2.movingEnd = false

    local to = deepcopy(m)
    to.pos = mid2.pos
    to.rot = mid2.rot
    to.time = duration / 14 * 12.5
    to.fov = 30
    to.movingEnd = false
    to.movingStart = false

    local to2 = deepcopy(m)
    to2.pos = mid2.pos
    to2.rot = mid2.rot
    to2.time = duration / 14 * 14
    to2.fov = 30
    to2.movingEnd = false
    to2.movingStart = false

    path.markers = { from, from2, mid2, to, to2 }

    if self.pinIn.loop.value then

        local out = deepcopy(m)
        out.pos = mid.pos
        out.rot = quatFromDir(tt, tu)
        out.time = duration / 14 * 15.5
        out.fov = 50
        out.movingEnd = false
        table.insert(path.markers, out)

        local back = deepcopy(m)
        back.pos = vec3(deepcopy(self.pinIn.from.value)) + d * 5 + vec3(0, 0, 90)
        back.rot = fq
        back.time = duration / 14 * 17.5
        back.movingStart = false
        back.movingEnd = false
        table.insert(path.markers, back)

        local back2 = deepcopy(m)
        back2.pos = vec3(deepcopy(self.pinIn.from.value)) + d
        back2.rot = fq
        back2.time = duration / 14 * 19
        back2.movingStart = false
        table.insert(path.markers, back2)
    end

    local name = self.mgr.modules.camera:getUniqueName(self.id .. "pcp")
    local id = self.mgr.modules.camera:addCustomPath(name, path, true)
    self.pinOut.pathName.value = name

end

return _flowgraph_createNode(C)