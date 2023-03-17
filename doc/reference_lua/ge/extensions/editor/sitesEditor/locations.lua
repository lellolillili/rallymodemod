-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui
local pathnodePosition = im.ArrayFloat(3)
local pathnodeNormal = im.ArrayFloat(3)
local pathnodeRadius = im.FloatPtr(0)
local nameText = im.ArrayChar(1024, "")

local C = {}
C.windowDescription = 'Locations'

function C:init(sitesEditor, key)
  self.sitesEditor = sitesEditor
  self.key = key
  self.current = nil
end

function C:setSites(sites)
  self.sites = sites
  self.list = sites[self.key]
  self.current = nil
end

function C:select(loc)
  self.current = loc
  if self.current ~= nil then
    self:updateTransform()
  end
end

function C:hitTest(mouseInfo, objects)
  local minNodeDist = 4294967295
  local closestNode = nil
  for idx, node in pairs(objects) do
    local distNodeToCam = (node.pos - mouseInfo.camPos):length()
    local nodeRayDistance = (node.pos - mouseInfo.camPos):cross(mouseInfo.rayDir):length() / mouseInfo.rayDir:length()
    local sphereRadius = node.radius
    if nodeRayDistance <= sphereRadius then
      if distNodeToCam < minNodeDist then
        minNodeDist = distNodeToCam
        closestNode = node
      end
    end
  end
  return closestNode
end


function C:updateTransform()
  local transform = QuatF(0,0,0,0):getMatrix()
  transform:setPosition(self.current.pos)
  editor.setAxisGizmoTransform(transform)
end


function C:beginDrag()
  self._beginDragRadius = self.current.radius
  if self._beginDragRadius <= 0.1 then
    self._beginDragRadius = 0.1
  end
end

function C:dragging()


  -- update/save our gizmo matrix
  if editor.getAxisGizmoMode() == editor.AxisGizmoMode_Translate then
    self.current.pos = vec3(editor.getAxisGizmoTransform():getColumn(3))
  elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Scale then
    local scl = vec3(worldEditorCppApi.getAxisGizmoScale())
    if scl.x ~= 1 then
      scl = scl.x
    elseif scl.y ~= 1 then
      scl = scl.y
    elseif scl.z ~= 1 then
      scl = scl.z
    else
      scl = 1
    end
    if scl < 0 then
      scl = 0
    end
    self.current.radius = self._beginDragRadius * scl
  end
end

function C:endDragging()
  -- undo action
end



function C:create(pos)
  local loc = self.list:create()
  loc:set(pos, 3)
  return loc
end

function C:drawElement(loc)
  if self.sitesEditor.allowGizmo() then
    self.current = loc
    editor.updateAxisGizmo(function() self:beginDrag() end, function() self:endDragging() end, function() self:dragging() end)
    editor.drawAxisGizmo()
  end
  local avail = im.GetContentRegionAvail()
  im.Text(loc.name)
end



return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
