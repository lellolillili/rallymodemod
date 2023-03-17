-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

local upVector = vec3(0,0,1)

local idCounter = 0

-- icon renderer
local iconRendererName = "markerIconRenderer"
local iconWorldSize = 20

-- default height for columns
local columnHeight = 3.5 --m
-- factor because the columnObject is not 1m high
local columnScl = 1/30
-- how quickly and where the marker should fade
local markerAlphaRate = 1/0.2
local markerShowDistance = 25
-- how quickly and where the icon should fade
local iconAlphaRate = 1/0.4
local iconShowDistance = 70
-- how quickly the cruising smoother should transition
local cruisingSmootherRate = 1/0.4
local cruisingRadius = 0.25
local markerFullRadiusDistance = 10

-- called when this object is created. initialize variables here (but dont spawn objects)
function C:init()
  self.id = idCounter
  idCounter = idCounter + 1

  -- ids of spawned objects
  self.iconRendererObj = nil

  self.bigMapMarkerAlphaSmoother = newTemporalSmoothing()

  self.visible = true
  self.visibleInBigmap = false
end

local function inverseLerp(min, max, value)
 if math.abs(max - min) < 1e-30 then return min end
 return (value - min) / (max - min)
end



local camPos2d, markerPos2d = vec3(), vec3()
local tmpVec = vec3()
local vecZero = vec3(0,0,0)

local bigMapModeColorI = ColorI(255,255,255,255)

-- called every frame to update the visuals.
function C:update(data)
  --if not self.visible then return end
  profilerPushEvent("BigMap Marker")
  --debugDrawer:drawTextAdvanced(self.pos, String(self.bigMapIconId), ColorF(1,1,1,1), true, false, ColorI(0,0,0,192))
  -- desired height is the actual height of the icon
  local bigMapActive = self.visible and not data.bigmapTransitionActive

  local bigMapMarkerAlpha = clamp(self.bigMapMarkerAlphaSmoother:getWithRateUncapped(bigMapActive and 1 or 0, data.dt, markerAlphaRate),0,1)
  bigMapMarkerAlpha = 1-((1-bigMapMarkerAlpha)*(1-bigMapMarkerAlpha))

  if bigMapMarkerAlpha > 0 or self.visibleLastFrame then
    self.visibleLastFrame = true
    profilerPopEvent("BigMap Marker PreCalculation")
    local resolutionFactor = 800 / freeroam_bigMapMode.getVerticalResolution()
    local camQuat = quat(getCameraQuat())
    local camUp = camQuat * upVector
    local camToCluster = self.pos - data.camPos
    local camToClusterLeft = camUp:cross(camToCluster):normalized()
    local camToUpperPoint = quatFromAxisAngle(camToClusterLeft, (resolutionFactor * 0.05 * getCameraFovRad())):__mul(camToCluster)
    local iconPos = quatFromAxisAngle(camToClusterLeft, (resolutionFactor * 0.02 * getCameraFovRad())):__mul(camToUpperPoint)
    local iconPosColumn = quatFromAxisAngle(camToClusterLeft, (resolutionFactor * -0.03 * getCameraFovRad())):__mul(camToUpperPoint * 1.1)
    self.selected = self.cluster.containedIdsLookup[freeroam_bigMapMode.selectedPoiId]
    self.hovered = self.cluster.containedIdsLookup[freeroam_bigMapMode.hoveredPoiId]
    self.hoveredListItem = self.cluster.containedIdsLookup[freeroam_bigMapMode.hoveredListItem]
    profilerPushEvent("BigMap Marker Icons")
    -- updating the icons
    if self.bigMapIconId then
      local iconInfo = self.iconDataById[self.bigMapIconId]
      if iconInfo then
        bigMapModeColorI.alpha = bigMapMarkerAlpha *255
        iconInfo.color = bigMapModeColorI
        tmpVec:set(data.camPos)
        tmpVec:setAdd(iconPos or vecZero)
        iconInfo.worldPosition = tmpVec
        if self.hovered or self.selected or self.hoveredListItem then
          iconInfo.customSizeFactor = 1.5
        else
          iconInfo.customSizeFactor = 1
        end
      end
    end

    if self.bigMapColumnIconId then
      local iconInfo = self.iconDataById[self.bigMapColumnIconId]
      if iconInfo then
        tmpVec:set(data.camPos)
        tmpVec:setAdd(iconPosColumn or vecZero)
        iconInfo.worldPosition = tmpVec
        bigMapModeColorI.alpha = bigMapMarkerAlpha *255
        iconInfo.color = bigMapModeColorI
      end
    end
  else
    self.visibleLastFrame = false
  end
  self.hovered = false
  profilerPopEvent("BigMap Marker")
end


function C:setup(data)
  self.pos = data.pos

  self.iconRendererObj = scenetree.findObject(iconRendererName)
  if not self.iconRendererObj then
    local iconRenderer = createObject("BeamNGWorldIconsRenderer")
    iconRenderer:registerObject(iconRendererName);
    iconRenderer.maxIconScale = 2
    iconRenderer.mConstantSizeIcons = true
    iconRenderer.canSave = false
    iconRenderer:loadIconAtlas("core/art/gui/images/iconAtlas.png", "core/art/gui/images/iconAtlas.json");
    self.iconRendererObj = iconRenderer
  end

  -- setting up the icon
  if data.clusterId then
    if self.iconRendererObj then
      self.iconDataById = {}

      self.bigMapIconId = self.iconRendererObj:addIcon(data.clusterId .. "bigMap", data.bigMapIconName or "mission_primary_01", self.pos + vec3(0,0,columnHeight))
      local iconInfo = self.iconRendererObj:getIconById(self.bigMapIconId)
      iconInfo.color = ColorI(255,255,255,0)
      iconInfo.customSize = iconWorldSize
      iconInfo.drawIconShadow = false
      self.iconDataById[self.bigMapIconId] = iconInfo

      self.bigMapColumnIconId = self.iconRendererObj:addIcon(data.clusterId .. "bigMapColumn", "marker_column", self.pos + vec3(0,0,columnHeight))
      local iconInfo = self.iconRendererObj:getIconById(self.bigMapColumnIconId)
      iconInfo.color = ColorI(255,255,255,0)
      iconInfo.customSize = iconWorldSize
      iconInfo.drawIconShadow = false
      self.iconDataById[self.bigMapColumnIconId] = iconInfo
    end

    self.cluster = data.cluster
  end
  -- setting up the smoothers
  self.bigMapMarkerAlphaSmoother:set(0)

  --setting up the label
  self.label = translateLanguage(data.label or "", data.label or "Some Mission..?", true)
end


function C:setHidden(value)
end

function C:hide()
  self.visible = false
end

function C:show()
  self.visible = true

end

function C:instantFade(visible)

end

function C:setVisibilityInBigmap(vis, instant)

end


-- destorys/cleans up all objects created by this
function C:clearObjects()
  if self.iconRendererObj then
    for id, _ in pairs(self.iconDataById or {}) do
      self.iconRendererObj:removeIconById(id)
    end
  end
  self.bigMapIconId = nil
  self.playModeIconId = nil
  self._ids = nil
  self.borderObj = nil
  self.decalObj = nil
  self.bigMapColumnObj = nil
  self.iconRendererObj = nil
  self.iconDataById = {}
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end