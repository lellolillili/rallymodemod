-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
local borderPrefix = "PlaymodeMarkerBorder_"
local decalRoadPrefix = "PlaymodeMarkerDecalRoad_"
local columnPrefix = "PlaymodeMarkerColumn_"
local baseShape = "art/shapes/interface/checkpoint_marker_base.dae"
local columnShape = "art/shapes/interface/single_faded_column.dae"
local bigMapColumnShape = "art/shapes/interface/single_faded_column_b.dae"
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
local markerAlphaRate = 1/0.75
local markerShowDistance = 25
-- how quickly and where the icon should fade
local iconAlphaRate = 1/0.4
local iconShowDistance = 70
-- how quickly the cruising smoother should transition
local cruisingSmootherRate = 1/0.4
local cruisingRadius = 0.25
local markerFullRadiusDistance = 10
-- how quickly to fade out everything because we are in bigmap
local bigmapAlphaRate = 1/0.4

-- called when this object is created. initialize variables here (but dont spawn objects)
function C:init()
  self.id = idCounter
  idCounter = idCounter + 1

  -- abstract data for center, border etc
  self.pos = nil
  self.border = nil

  -- ids of spawned objects
  self.borderObj = nil
  self.decalRoadObj = nil
  self.columnObj = nil
  self.iconRendererObj = nil
  self.markerAlphaSmoother = newTemporalSmoothing()
  self.bigMapSmoother = newTemporalSmoothing()
  self.iconAlphaSmoother = newTemporalSmoothing()
  self.stretchSmoother = newTemporalSmoothing()
  self.cruisingSmoother = newTemporalSmoothing()

  self.visible = true
end

local function inverseLerp(min, max, value)
 if math.abs(max - min) < 1e-30 then return min end
 return (value - min) / (max - min)
end

local playModeIconColor = ColorF(0,0,1,1):asLinear4F()
local playModeColumnColor = ColorF(1.5,1.5,1.5,1):asLinear4F()

local camPos2d, markerPos2d = vec3(), vec3()
local tmpVec = vec3()
local vecZero = vec3(0,0,0)

local playModeColorI = ColorI(255,255,255,255)

-- called every frame to update the visuals.
function C:update(data)
  if not self.visible then return end
  profilerPushEvent("Playmode Marker")

  profilerPushEvent("Playmode Marker PreCalculation")
  -- get the 2d distance to the marker to adjust the height
  camPos2d:set(data.camPos)
  camPos2d.z = 0
  markerPos2d:set(self.pos)
  markerPos2d.z = 0
  local distance2d = math.max(0,camPos2d:distance(markerPos2d) - self.radius)

  -- desired height is the actual height of the icon
  local desiredHeight = (1+1*clamp(inverseLerp(20,70, distance2d), 0,1)) * columnHeight
  local bigMapActive = data.bigMapActive

  -- 3d distance to the marker
  local distanceFromMarker = math.max(0,self.pos:distance(commands.isFreeCamera() and data.camPos or data.playerPosition) - self.radius)
  local distanceToCamera = self.pos:distance(data.camPos)

  -- alpha values for the icon and marker
  local playModeIconAlphaDist = ((distanceFromMarker <= (self.forceVisible and iconShowDistance*2 or iconShowDistance)) and 0.7 or 0)
  local iconInfo = self.iconDataById[self.playModeIconId]
  if iconInfo then
    tmpVec:set(iconInfo.worldPosition)
    tmpVec:setSub(data.camPos)
    local rayLength = tmpVec:length()
    local hitDist = castRayStatic(data.camPos, tmpVec, rayLength, nil)
    if hitDist < rayLength then
      playModeIconAlphaDist = 0
    end
  end

  -- this is a global alpha scale for all markers. goes to 0 when in bigmap
  local bigMapAlpha = clamp(self.bigMapSmoother:getWithRateUncapped(bigMapActive and 0 or 1, data.dt, bigmapAlphaRate), 0,1)

  local playModeIconAlpha = clamp(self.iconAlphaSmoother:getWithRateUncapped(playModeIconAlphaDist * data.globalAlpha, data.dt, iconAlphaRate), 0,1) * bigMapAlpha
  local markerAlphaSample = (0.7 * (distanceFromMarker <= self.radius and 1 or 0) * data.parkingSpeedFactor)
                          + (0.3 * (distanceFromMarker <= markerShowDistance and 1 or 0))
  markerAlphaSample = markerAlphaSample * data.globalAlpha * bigMapAlpha

  local playModeMarkerAlpha = clamp(self.markerAlphaSmoother:getWithRateUncapped((bigMapActive or not self.visibleInPlayMode) and 0 or markerAlphaSample, data.dt, markerAlphaRate),0,1) * bigMapAlpha


  local radiusInterpolationDest = distanceFromMarker > math.max(markerFullRadiusDistance, self.radius) and 1 or data.cruisingSpeedFactor
  local smoothedCruisingFactor = self.cruisingSmoother:getWithRateUncapped(radiusInterpolationDest, data.dt, cruisingSmootherRate)
  local shownRadius = (1-smoothedCruisingFactor)*self.radius + smoothedCruisingFactor*cruisingRadius

  profilerPopEvent("Playmode Marker PreCalculation")
  -- updating the actual objects
  if self.borderObj and (playModeMarkerAlpha > 0 or self.playModeMarkerAlphaLastFrame > 0) then
    playModeIconColor.w = playModeMarkerAlpha -- use W instead of alpha because asLinear4F
    self.borderObj.instanceColor = playModeIconColor
    self.borderObj:setScaleXYZ(shownRadius*2, shownRadius*2, self.radius*2)
    self.borderObj:updateInstanceRenderData()
  end
  if self.groundDecalData and (playModeMarkerAlpha > 0 and self.playModeMarkerAlphaLastFrame > 0) then
    self.groundDecalData.color.alpha = clamp(playModeMarkerAlpha*2.5,0,1)*(1-smoothedCruisingFactor)
  end
  -- interpolating the middle columns size and radius so it has the same on-screen size
  if self.columnObj and (playModeIconAlpha > 0 or self.playModeIconAlphaLastFrame > 0) then
    playModeColumnColor.w = playModeIconAlpha -- use W instead of alpha because asLinear4F
    self.columnObj.instanceColor = playModeColumnColor
    self.columnObj:setPositionXYZ(self.pos.x, self.pos.y, self.pos.z - desiredHeight/2)
    local sideRadius = math.max(distanceToCamera/30,0.15)
    self.columnObj:setScaleXYZ(sideRadius, sideRadius, 1.5*desiredHeight*columnScl)
    self.columnObj:updateInstanceRenderData()
  end

  profilerPushEvent("Playmode Marker Icons")
  -- updating the icons
  if self.playModeIconId and (playModeIconAlpha > 0 or self.playModeIconAlphaLastFrame > 0) then
    local iconInfo = self.iconDataById[self.playModeIconId]
    if iconInfo then
      tmpVec:set(0,0,desiredHeight)
      tmpVec:setAdd(self.pos)
      iconInfo.worldPosition = tmpVec
      playModeColorI.alpha = playModeIconAlpha * 255
      iconInfo.color = playModeColorI
    end
  end

  profilerPopEvent("Playmode Marker Icons")

  self.playModeMarkerAlphaLastFrame = playModeMarkerAlpha
  self.playModeIconAlphaLastFrame = playModeIconAlpha
  profilerPopEvent("Playmode Marker")
end


function C:setup(data)
  -- some old code for procedural borders
  local border = {}
  local segments = data.radius * 6
  for i = 0, segments do
    local rad = i*math.pi*2 / segments
    table.insert(border,vec3(math.cos(rad)*data.radius, -math.sin(rad)*data.radius,0))
  end
  self.radius = data.radius
  self.border = border
  self.pos = data.pos
  self.visibleInBigmap = false
  --self:dropBorderToTerrain()
  --self:updateBorder()

  -- setting the objects to the correct position/size
  if self.borderObj then
    self.borderObj:setPosition(vec3(self.pos))
    self.borderObj:setScale(vec3(data.radius*2, data.radius*2, data.radius*2))
    self.borderObj.instanceColor = ColorF(0,0,1,1):asLinear4F()
    self.borderObj:updateInstanceRenderData()
  end
  if self.columnObj then
    self.columnObj:setPosition(vec3(self.pos - vec3(0,0,columnHeight/2)))
    self.columnObj:setScale(vec3(0.1,0.1, 1.5*columnHeight*columnScl))
    self.columnObj.instanceColor = ColorF(1,1,1,1):asLinear4F()
    self.columnObj:updateInstanceRenderData()
  end

  -- setting up the icon
  if data.clusterId then
    if self.iconRendererObj then
      self.iconDataById = {}
      if data.playModeIconName then
        self.playModeIconId = self.iconRendererObj:addIcon(data.clusterId .. "playMode", data.playModeIconName, self.pos + vec3(0,0,columnHeight))
        local iconInfo = self.iconRendererObj:getIconById(self.playModeIconId)
        iconInfo.color = ColorI(255,255,255,255)
        iconInfo.customSize = iconWorldSize
        iconInfo.drawIconShadow = false
        self.iconDataById[self.playModeIconId] = iconInfo
      end

    end
    self.visibleInPlayMode = data.visibleInPlayMode
    self.cluster = data.cluster
  end

  -- setting up the smoothers
  self.markerAlphaSmoother:set(0)
  self.iconAlphaSmoother:set(0)
  self.stretchSmoother:set(0)
  self.cruisingSmoother:set(1)
  self.bigMapSmoother:set(0)

  self.playModeMarkerAlphaLastFrame = 1
  self.playModeIconAlphaLastFrame = 1

  --setting up the label
  self.label = translateLanguage(data.label or "", data.label or "Some Mission..?", true)

  -- setting up the ground decal
  self.groundDecalData = {
    texture = 'art/shapes/missions/dotted_ring_5m.png',
    position = data.pos,
    forwardVec = vec3(1, 0, 0),
    color = ColorF(1.5,1.5,1.5,0 ),
    scale = vec3(data.radius*2.25, data.radius*2.25, 3),
    fadeStart = 100,
    fadeEnd = 200
  }
end

-- marker management
function C:createObject(shapeName, objectName)
  local marker = createObject('TSStatic')
  marker:setField('shapeName', 0, shapeName)
  marker:setPosition(vec3(0, 0, 0))
  marker.scale = vec3(1, 1, 1)
  marker:setField('rotation', 0, '1 0 0 0')
  marker.useInstanceRenderData = true
  marker:setField('instanceColor', 0, '1 1 1 1')
  marker.canSave = false
  --marker.hidden = true
  marker:registerObject(objectName)

  return marker
end

-- creates neccesary objects
function C:createObjects()
  self:clearObjects()
  self._ids = {}
  if not self.borderObj then
    --self.borderObj = self:createProcMesh()
    self.borderObj = self:createObject(baseShape,borderPrefix..self.id)
    table.insert(self._ids, self.borderObj:getId())
  end

  if not self.columnObj then
    self.columnObj = self:createObject(columnShape, columnPrefix..self.id)
    table.insert(self._ids, self.columnObj:getId())
  end
  --global (for this file) renderer
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
  self.iconDataById = {}
end

function C:setHidden(value)
end

function C:hide()
  if not self.visible then return end
  self.visible = false
  self.markerAlphaSmoother:reset()
  self.iconAlphaSmoother:reset()
  self.stretchSmoother:reset()

   -- hiding all that there is
  local linearInvisible = ColorF(0,0,0,0):asLinear4F()
  if self.borderObj then
    self.borderObj.instanceColor = linearInvisible
    self.borderObj:updateInstanceRenderData()
  end

  if self.columnObj then
    self.columnObj.instanceColor = linearInvisible
    self.columnObj:updateInstanceRenderData()
  end

  -- updating the icon
  if self.iconRendererObj then
    for id, data in pairs(self.iconDataById or {}) do
      data.color = ColorI(0,0,0,0)
    end
  end
end

function C:show()
  if self.visible then return end
  self.visible = true
end

function C:instantFade(visible)
end

function C:setVisibilityInBigmap(vis, instant)
end

-- destorys/cleans up all objects created by this
function C:clearObjects()
  for _, id in ipairs(self._ids or {}) do
    local obj = scenetree.findObjectById(id)
    if obj then
      obj:delete()
    end
  end

  if self.iconRendererObj then
    for id, _ in pairs(self.iconDataById or {}) do
      self.iconRendererObj:removeIconById(id)
    end
  end

  self.playModeIconId = nil
  self._ids = nil
  self.borderObj = nil
  self.decalObj = nil

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