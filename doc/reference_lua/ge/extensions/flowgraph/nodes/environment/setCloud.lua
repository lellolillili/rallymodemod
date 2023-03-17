-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Set Cloud by ID'
C.icon = "simobject_scatter_sky"
C.description = "Sets various cloud parameters."
C.category = 'dynamic_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'objectId', description = "Defines the ID of cloud object to look for." },
  { dir = 'in', type = 'number', name = 'coverage', description = "Defines how much of the sky is covered by this cloud." },
  { dir = 'in', type = 'number', name = 'exposure', description = "Defines the brightness scale of the cloud." },
  { dir = 'in', type = 'number', name = 'windSpeed', description = "Defines how fast the cloud texture will scroll." },
  { dir = 'in', type = 'number', name = 'height', description = "Defines the height of cloud in the sky." },
}

C.tags = { 'cloud' }

function C:init(mgr)
  self.data.restoreCloud = true
end

function C:postInit()
  self.pinInLocal.coverage.numericSetup = {
    min = 0,
    max = 1,
    type = 'float',
    gizmo = 'slider',
  }
end

function C:_executionStarted()
  --self.storedcloudCoverage = core_environment.getCloudCoverByID(self.pinIn.objectId.value)
  --self.storedcloudExposure = core_environment.getCloudExposureByID(self.pinIn.objectId.value)
  --self.storedcloudWindSpeed = core_environment.getCloudWindSpeedByID(self.pinIn.objectId.value)
  --self.storedcloudHeight = core_environment.getCloudHeightByID(self.pinIn.objectId.value)

  --self.storedCloud = true
end
function C:_executionStopped()
  --if self.data.restoreCloud and self.storedCloud then
  --  core_environment.setCloudCoverByID(self.pinIn.objectId.value, self.storedcloudCoverage)
  --  core_environment.setCloudExposureByID(self.pinIn.objectId.value, self.storedcloudExposure)
  -- core_environment.setCloudWindByID(self.pinIn.objectId.value, self.storedcloudWindSpeed)
  --  core_environment.setCloudHeightByID(self.pinIn.objectId.value, self.storedcloudHeight)
  --end
end

function C:workOnce()
  self:setCloudParameters()
end

function C:work()
  if self.dynamicMode == 'repeat' then
    self:setCloudParameters()
  end
end

function C:setCloudParameters()
  core_environment.setCloudCoverByID(self.pinIn.objectId.value, self.pinIn.coverage.value)
  core_environment.setCloudExposureByID(self.pinIn.objectId.value, self.pinIn.exposure.value)
  core_environment.setCloudWindByID(self.pinIn.objectId.value, self.pinIn.windSpeed.value)
  core_environment.setCloudHeightByID(self.pinIn.objectId.value, self.pinIn.height.value)
end

return _flowgraph_createNode(C)
