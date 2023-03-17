-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im = ui_imgui
local pathnodePosition = im.ArrayFloat(3)
local pathnodeNormal = im.ArrayFloat(3)
local pathnodeRadius = im.FloatPtr(0)
local nameText = im.ArrayChar(1024, "")
local transformUtil
local psVehScales = {
  Car = vec3(2.5, 6, 3),
  Bus = vec3(4, 14, 8)
}

local C = {}
C.windowDescription = 'Parking Spots'

function C:init(sitesEditor, key)
  self.sitesEditor = sitesEditor
  self.key = key
  self.current = nil

  -- multiSpot data
  self.isMultiSpot = im.BoolPtr(false)
  self.multiSpotData = { spotAmount = im.IntPtr(1), spotOffset = im.FloatPtr(0), spotDirection = "Left", spotRotation = im.FloatPtr(0) }
  transformUtil = require('/lua/ge/extensions/editor/util/transformUtil')("Edit Sites", "Transform")
end

function C:setSites(sites)
  self.sites = sites
  self.list = sites[self.key]
  self.current = nil
end

function C:select(ps)
  self.current = ps
  if self.current ~= nil then
    self:updateTransform()
    self.isMultiSpot[0] = self.current.isMultiSpot or false
    self.multiSpotData.spotAmount[0] = self.current.multiSpotData.spotAmount or 1
    self.multiSpotData.spotOffset[0] = self.current.multiSpotData.spotOffset or 0
    self.multiSpotData.spotDirection = self.current.multiSpotData.spotDirection or "Left"
    self.multiSpotData.spotRotation[0] = self.current.multiSpotData.spotRotation or 0
  end
end

function C:hitTest(mouseInfo, objects)
  self.mouseInfo = mouseInfo

  local minNodeDist = 4294967295
  local closestNode = nil
  if mouseInfo.down then
    for idx, node in pairs(objects) do
      local tmpSpotAmount = 1
      if node.isMultiSpot then
        tmpSpotAmount = node.multiSpotData.spotAmount or 1
      end
      for i = 0, tmpSpotAmount - 1 do
        local rot = node.rot
        local dirVec
        if node.multiSpotData.spotDirection == "Left" then
          dirVec = rot * vec3(-i * (node.scl.x + node.multiSpotData.spotOffset), 0, 0)
        elseif node.multiSpotData.spotDirection == "Right" then
          dirVec = rot * vec3(i * (node.scl.x + node.multiSpotData.spotOffset), 0, 0)
        elseif node.multiSpotData.spotDirection == "Front" then
          dirVec = rot * vec3(0, i * (node.scl.y + node.multiSpotData.spotOffset), 0)
        elseif node.multiSpotData.spotDirection == "Back" then
          dirVec = rot * vec3(0, -i * (node.scl.y + node.multiSpotData.spotOffset), 0)
        end
        rot = quatFromEuler(0, 0, node.multiSpotData.spotRotation) * rot
        local pos = node.pos + dirVec
        local rotated = (node.scl * 0.5):rotated(rot)
        local minDist, maxDist = intersectsRay_OBB(mouseInfo.camPos, mouseInfo.rayDir:normalized(), pos, vec3(rotated.x, 0, 0), vec3(0, rotated.y, 0), vec3(0, 0, rotated.z))
        if minDist < maxDist and minDist < minNodeDist then
          minNodeDist = minDist
          closestNode = node
        end
      end
    end
    return closestNode
  end
end

function C:updateTransform()
  transformUtil:set(self.current.pos, self.current.rot, self.current.scl)
end

function C:create(pos)
  local ps = self.list:create()
  ps:set(pos, nil, psVehScales["Car"])
  editor.setAxisGizmoMode(editor.AxisGizmoMode_Rotate)
  return ps
end

function C:update()
  if self.current then
    self.current.pos = transformUtil.pos
    self.current.rot = transformUtil.rot
    self.current.scl = transformUtil.scl
    self.current.isMultiSpot = self.isMultiSpot[0]
    self.current.multiSpotData.spotAmount = self.multiSpotData.spotAmount[0]
    self.current.multiSpotData.spotOffset = self.multiSpotData.spotOffset[0]
    self.current.multiSpotData.spotDirection = self.multiSpotData.spotDirection
    self.current.multiSpotData.spotRotation = self.multiSpotData.spotRotation[0]
  end
end

function C:drawElement(loc)
  local dirty = false
  self.current = loc
  transformUtil:update(self.mouseInfo)
  self:update()
  im.PushItemWidth(90)

  local currScale = "Custom"
  for name, vehScale in pairs(psVehScales) do
    if self.current.scl == vehScale then
      currScale = name
      break
    end
  end
  if im.BeginCombo("##psScaleSelect", currScale) then
    for name, vehScale in pairs(psVehScales) do
      if im.Selectable1(name) then
        currScale = name
        self.current.scl = vehScale
        self:updateTransform()
        dirty = true
      end
    end
    im.EndCombo()
  end
  im.PopItemWidth()

  im.Spacing()
  if im.Checkbox("Is MultiSpot", self.isMultiSpot) then
    dirty = true
  end

  if self.isMultiSpot[0] then
    im.PushItemWidth(90)
    if im.BeginCombo("##spotDirectionSelect", self.multiSpotData.spotDirection) then
      for _, dir in ipairs({ "Left", "Right", "Front", "Back" }) do
        if im.Selectable1(dir) then
          self.multiSpotData.spotDirection = dir
          dirty = true
        end
      end
      im.EndCombo()
    end
    im.PopItemWidth()
    im.SameLine()
    im.Text("Direction")
    if im.SliderInt("Amount of Spots", self.multiSpotData.spotAmount, 1, 25) then
      dirty = true
    end

    if im.SliderFloat("Offset", self.multiSpotData.spotOffset, 0, 5, "%.3f", 0.001) then
      dirty = true
    end

    if im.SliderFloat("Spot Rotation", self.multiSpotData.spotRotation, -1.55, 1.55, "%.2f", 0.01) then
      dirty = true
    end

  end

  if dirty then
    self:update()
  end
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
