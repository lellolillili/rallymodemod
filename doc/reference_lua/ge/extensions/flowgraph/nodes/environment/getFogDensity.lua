-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Get Fog'
C.icon = "simobject_scatter_sky"
C.description = "Get the current fog parameters."
C.category = 'provider'

C.pinSchema = {
  { dir = 'out', type = 'number', name = 'density', description = "The current fog density." },
  { dir = 'out', type = 'number', name = 'densityOffset', description = "Distance from the camera at which the fog will start to appear." },
  { dir = 'out', type = 'number', name = 'atmosphereHeight', description = "Atmospheric fog height." },
}

C.legacyPins = {
  _in = {
    fog = 'density'
  }
}


C.tags = {'tod'}

function C:work()
  local fogDensity = core_environment.getFogDensity()
  local fogDensityOffset = core_environment.getFogDensityOffset()
  local fogAtmosphereHeight = core_environment.getFogAtmosphereHeight()

  self.pinOut.density.value = fogDensity
  self.pinOut.densityOffset.value = fogDensityOffset
  self.pinOut.atmosphereHeight.value = fogAtmosphereHeight
end

return _flowgraph_createNode(C)