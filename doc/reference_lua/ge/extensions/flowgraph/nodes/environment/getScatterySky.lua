-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Get ScatterSky'
C.icon = "simobject_scatter_sky"
C.description = "Get the current ScatterSky parameters."
C.category = 'provider'

C.pinSchema = {
    { dir = 'out', type = 'number', name = 'skyBrightness', description = "Global sky brightness." },
    { dir = 'out', type = 'string', name = 'colorizeGradientFile', hidden = true, description = "Texture used to modulate the sky color." },
    { dir = 'out', type = 'string', name = 'sunScaleGradientFile', hidden = true,description = "Texture used to modulate the sun color." },
    { dir = 'out', type = 'string', name = 'ambientScaleGradientFile', hidden = true,description = "Texture used to modulate the ambient color." },
    { dir = 'out', type = 'string', name = 'fogScaleGradientFile', hidden = true,description = "Texture used to modulate the fog color." },
    { dir = 'out', type = 'string', name = 'nightGradientFile', hidden = true,description = "Texture used to modulate the ambient color at night time." },
    { dir = 'out', type = 'string', name = 'nightFogGradientFile', hidden = true,description = "Texture used to modulate the fog color at night time." },
    { dir = 'out', type = 'number', name = 'shadowDistance', description = "Maximum distance from the camera at which shadows will be visible." },
    { dir = 'out', type = 'number', name = 'shadowSoftness', description = "How soft shadows will appear." },
  { dir = 'out', type = 'number', name = 'logWeight', description = "Balance between shadow distance and quality. Higher values will make shadows appear sharper closer to the camera, at cost of drawing distance" },
}

C.tags = {'tod'}

function C:work()
  local skyBrightness = core_environment.getSkyBrightness()

  local colorizeGradientFile = core_environment.getColorizeGradientFile()
  local sunScaleGradientFile = core_environment.getSunScaleGradientFile()
  local ambientScaleGradientFile = core_environment.getAmbientScaleGradientFile()
  local fogScaleGradientFile = core_environment.getFogScaleGradientFile()
  local nightGradientFile = core_environment.getNightGradientFile()
  local nightFogGradientFile = core_environment.getNightFogGradientFile()

  local shadowDistance = core_environment.getShadowDistance()
  local shadowSoftness = core_environment.getShadowSoftness()
  local logWeight = core_environment.getShadowLogWeight()

  self.pinOut.skyBrightness.value = skyBrightness

  self.pinOut.colorizeGradientFile.value = colorizeGradientFile
  self.pinOut.sunScaleGradientFile.value = sunScaleGradientFile
  self.pinOut.ambientScaleGradientFile.value = ambientScaleGradientFile
  self.pinOut.fogScaleGradientFile.value = fogScaleGradientFile
  self.pinOut.nightGradientFile.value = nightGradientFile
  self.pinOut.nightFogGradientFile.value = nightFogGradientFile

  self.pinOut.shadowDistance.value = shadowDistance
  self.pinOut.shadowSoftness.value = shadowSoftness
  self.pinOut.logWeight.value = logWeight
end

return _flowgraph_createNode(C)