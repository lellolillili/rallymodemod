-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Set ScatterSky'
C.icon = "simobject_scatter_sky"
C.description = "Sets various ScatterSky parameters."
C.category = 'dynamic_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'skyBrightness', description = "Global sky brightness." },
  { dir = 'in', type = 'string', name = 'colorizeGradientFile', hardcoded = true, hidden = true, description = "Texture used to modulate the sky color." },
  { dir = 'in', type = 'string', name = 'sunScaleGradientFile', hardcoded = true, hidden = true, description = "Texture used to modulate the sun color." },
  { dir = 'in', type = 'string', name = 'ambientScaleGradientFile', hardcoded = true, hidden = true, description = "Texture used to modulate the ambient color." },
  { dir = 'in', type = 'string', name = 'fogScaleGradientFile', hardcoded = true, hidden = true,  description = "Texture used to modulate the fog color." },
  { dir = 'in', type = 'string', name = 'nightGradientFile', hardcoded = true, hidden = true, description = "Texture used to modulate the ambient color at night time." },
  { dir = 'in', type = 'string', name = 'nightFogGradientFile', hardcoded = true, hidden = true, description = "Texture used to modulate the fog color at night time." },
  { dir = 'in', type = 'number', name = 'shadowDistance', description = "Maximum distance from the camera at which shadows will be visible." },
  { dir = 'in', type = 'number', name = 'shadowSoftness', description = "How soft shadows will appear." },
  { dir = 'in', type = 'number', name = 'logWeight',description = "Balance between shadow distance and quality. Higher values will make shadows appear sharper closer to the camera, at cost of drawing distance" },
}

C.tags = { 'tod' }

function C:init(mgr)
  self.data.restoreScatterSky = true
end

function C:postInit()
  self.pinInLocal.logWeight.numericSetup = {
    min = 0,
    max = 1,
    type = 'float',
    gizmo = 'slider',
  }
end

function C:_executionStarted()
  self.storedskyBrightness = core_environment.getSkyBrightness()

  self.storedcolorizeGradientFile = core_environment.getColorizeGradientFile()
  self.storedsunScaleGradientFile = core_environment.getSunScaleGradientFile()
  self.storedambientScaleGradientFile = core_environment.getAmbientScaleGradientFile()
  self.storedfogScaleGradientFile = core_environment.getFogScaleGradientFile()
  self.storednightGradientFile = core_environment.getNightGradientFile()
  self.storednightFogGradientFile = core_environment.getNightFogGradientFile()

  self.storedshadowDistance = core_environment.getShadowDistance()
  self.storedshadowSoftness = core_environment.getShadowSoftness()
  self.storedlogWeight = core_environment.getShadowLogWeight()

  self.storedScatterSky = true
end
function C:_executionStopped()
  if self.data.restoreScatterSky and self.storedScatterSky then
    core_environment.setSkyBrightness(self.storedskyBrightness)

    core_environment.setColorizeGradientFile(self.storedcolorizeGradientFile)
    core_environment.setSunScaleGradientFile(self.storedsunScaleGradientFile)
    core_environment.setAmbientScaleGradientFile(self.storedambientScaleGradientFile)
    core_environment.setFogScaleGradientFile(self.storedfogScaleGradientFile)
    core_environment.setNightGradientFile(self.storednightGradientFile)
    core_environment.setNightFogGradientFile(self.storednightFogGradientFile)

    core_environment.setShadowDistance(self.storedshadowDistance)
    core_environment.setShadowSoftness(self.storedshadowSoftness)
    core_environment.setShadowLogWeight(self.storedlogWeight)
  end
end

function C:workOnce()
  self:setScatterSkyParameters()
end

function C:work()
  if self.dynamicMode == 'repeat' then
    self:setScatterSkyParameters()
  end
end

function C:setScatterSkyParameters()
  core_environment.setSkyBrightness(self.pinIn.skyBrightness.value)

  core_environment.setColorizeGradientFile(self.pinIn.colorizeGradientFile.value)
  core_environment.setSunScaleGradientFile(self.pinIn.sunScaleGradientFile.value)
  core_environment.setAmbientScaleGradientFile(self.pinIn.ambientScaleGradientFile.value)
  core_environment.setFogScaleGradientFile(self.pinIn.fogScaleGradientFile.value)
  core_environment.setNightGradientFile(self.pinIn.nightGradientFile.value)
  core_environment.setNightFogGradientFile(self.pinIn.nightFogGradientFile.value)

  dump(self.pinIn.shadowDistance.value)
  core_environment.setShadowDistance(self.pinIn.shadowDistance.value)
  core_environment.setShadowSoftness(self.pinIn.shadowSoftness.value)
  core_environment.setShadowLogWeight(self.pinIn.logWeight.value)

  --  This is needed to update the gradients
  local tod = core_environment.getTimeOfDay()
  core_environment.setTimeOfDay(tod)
end

return _flowgraph_createNode(C)
