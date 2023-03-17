-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Raycast'
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = "flare"
C.description = "Casts a ray and hits the first static collision object, like TSStatics or Terrain."
C.category = 'repeat_instant'

C.pinSchema = {
    { dir = 'in', type = 'vec3', name = 'pos', description = 'Start of the raycast.' },
    { dir = 'in', type = 'vec3', name = 'dir', description = 'Direction of the raycast.' },
    { dir = 'in', type = 'number', name = 'dist', description = 'Distance of the raycast. If not given, will use the length of the dir vector.', hidden = true, default = 1000, hardcoded = true },
    { dir = 'out', type = 'flow', name = 'hit', description = 'Outflow if the raycast hit something.' },
    { dir = 'out', type = 'flow', name = 'miss', description = 'Outflow if the raycast did not hit anything, meanign the distance is >= dist pin value.', hidden = true },
    { dir = 'out', type = 'vec3', name = 'pos', description = 'Hit position of the raycast.' },
    { dir = 'out', type = 'number', name = 'dist', description = 'Distance to the origin of the raycast.' },
    --{dir = 'in', type = 'vec3', name = 'normal', description = 'Normal of the point hit.'},
}

C.tags = {'util', 'draw'}

function C:init()
  self.data.debug = false
end

function C:work()
  if not self.pinIn.pos.value then return end
  if not self.pinIn.dir.value then return end
  local pos = vec3(self.pinIn.pos.value)
  local dir = vec3(self.pinIn.dir.value)
  local dist = self.pinIn.dist.value or dir:length()
  local hitDist = castRayStatic(pos, dir, dist)
  local hitPos = pos + dir:normalized() * hitDist
  if self.data.debug then
    debugDrawer:drawSphere(vec3(pos), 0.25, ColorF(1,0,0,0.5))
    debugDrawer:drawSphere(vec3(hitPos), 0.25, ColorF(0,1,0,0.5))
    debugDrawer:drawLine(vec3(pos), vec3(hitPos), ColorF(0,0,1,0.5))
    debugDrawer:drawTextAdvanced(hitPos, String(string.format("%0.3f",hitDist)), ColorF(1,1,1,1), true, false, ColorI(0,0,0,192))
  end
  self.pinOut.hit.value = hitDist < dist
  self.pinOut.miss.value = hitDist >= dist
  self.pinOut.pos.value = hitPos:toTable()
  self.pinOut.dist.value = hitDist
end

return _flowgraph_createNode(C)

