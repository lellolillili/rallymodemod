-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'Collection Marker'
C.description = 'Creates a simple BeamNG-themed, colorable token.'
C.category = 'repeat_instant'
C.author = 'BeamNG'
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = "Inflow for this node." },
  { dir = 'out', type = 'flow', name = 'flow', description = "Outflow for this node." },
  { dir = 'in', type = 'flow', name = 'reset', description = "Triggering this will remove the marker.", impulse = true },
  { dir = 'in', type = 'vec3', name = 'pos', description = "The position of this marker." },
  { dir = 'in', type = { 'number', 'color' }, name = 'color', description = "Optional coloring. Can use 0-1 to blend from Orange to Green." },

}
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.tags = {}

function C:init(mgr, ...)

end

-- removes all the markers and then removes the list.
function C:hideMarker()
  if self.marker then
    self.marker:delete()
  end

  if self.light then
    self.light:delete()
  end
  self.marker = nil
  self.light = nil
end

function C:_executionStopped()
  self:hideMarker()
end


function C:work()
  if self.pinIn.reset.value then
    self:clearMarkers()
  end
  if self.pinIn.flow.value then
    if not self.marker then
      local marker =  createObject('TSStatic')
      marker:setField('shapeName', 0, 'art/shapes/collectible/s_marker_BNG.dae')
      marker:setPosition(vec3(0, 0, 0))
      marker.scale = vec3(2, 2, 2)
      marker:registerObject(self.id.."marker")
      self.marker = marker

      self.light =  worldEditorCppApi.createObject("PointLight")

      self.light:registerObject(self.id.."lighgt")

    end

    if self.marker then
      local pos = vec3(self.pinIn.pos.value)

      pos = pos + (vec3(0,0,math.sin(self.mgr.modules.timer.globalTime.real*1.5) * 0.15))
      self.marker:setPosition(pos)
      local rot = quatFromEuler(0,0,(self.mgr.modules.timer.globalTime.real*1.75)):toTorqueQuat()
      self.marker:setField('rotation', 0, rot.x .. ' ' .. rot.y .. ' ' .. rot.z .. ' ' .. rot.w)
      local clr = self.pinIn.color.value or {1,1,1,1}

      if type(clr) == 'number' then
        clr = rainbowColor(36,(0.8-(0.75*clr))*12, 1)
      end

      self.marker.instanceColor = ColorF(clr[1],clr[2],clr[3],1):asLinear4F()
      self.marker:updateInstanceRenderData()

      self.light:setField('color', 0, clr[1] .. ' ' .. clr[2] .. ' ' .. clr[3] .. ' ' .. clr[4])
      self.light:setField('radius', 0, 3)
      self.light:setPosition(pos)
    end
  end
end

function C:onClientEndMission()
  self:_executionStopped()
end


function C:destroy()
  self:_executionStopped()
end


return _flowgraph_createNode(C)
