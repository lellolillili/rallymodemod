-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Set Fog'
C.icon = "simobject_scatter_sky"
C.description = "Sets various fog parameters."
C.category = 'dynamic_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'density', description = "Set fog density." },
  { dir = 'in', type = 'number', name = 'densityOffset', description = "Distance from the camera at which the fog will start to appear." },
  { dir = 'in', type = 'number', name = 'atmosphereHeight', description = "Atmospheric fog height." },
}

C.legacyPins = {
  _in = {
    fog = 'density'
  }
}

C.tags = { 'tod' }

function C:init(mgr)
  self.data.restoreTod = true
end

function C:postInit()
  self.pinInLocal.density.numericSetup = {
    min = 0,
    max = 1,
    type = 'float',
    gizmo = 'slider',
  }
end

function C:_executionStarted()
  self.storedfogDensity = core_environment.getFogDensity()
  self.storedfogDensityOffset = core_environment.getFogDensityOffset()
  self.storedfogAtmosphereHeight = core_environment.getFogAtmosphereHeight()
  self.storedfog = true
end

function C:_executionStopped()
  if self.data.restoreTod and self.storedfog then
    core_environment.setFogDensity(self.storedfogDensity)
    core_environment.setFogDensityOffset(self.storedfogDensityOffset)
    core_environment.setFogAtmosphereHeight(self.storedfogAtmosphereHeight)
    self.storedfog = nil
  end
end

function C:workOnce()
  self:setFogParameters()
end

function C:work()
  if self.dynamicMode == 'repeat' then
    self:setFogParameters()
  end
end

function C:setFogParameters()
  core_environment.setFogDensity(self.pinIn.density.value)
  core_environment.setFogDensityOffset(self.pinIn.densityOffset.value)
  core_environment.setFogAtmosphereHeight(self.pinIn.atmosphereHeight.value)
end

return _flowgraph_createNode(C)
