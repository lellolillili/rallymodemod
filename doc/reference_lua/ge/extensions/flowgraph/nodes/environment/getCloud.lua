-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Get Cloud by ID'
C.icon = "simobject_scatter_sky"
C.description = "Get a specific cloud object settings."
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'objectId', description = 'ID of cloud object to look for.' },
  { dir = 'out', type = 'number', name = 'coverage', description = "How much of the sky is covered by this cloud." },
  { dir = 'out', type = 'number', name = 'exposure', description = "Brightness scale of the cloud." },
  { dir = 'out', type = 'number', name = 'windSpeed', description = "How fast the cloud texture will scroll." },
  { dir = 'out', type = 'number', name = 'height', description = "Height of cloud in the sky." },
}

C.tags = {'tod'}

function C:work()
  if not self.pinIn.objectId.value then return end
  cloudObject = self.pinIn.objectId.value
  local coverage = core_environment.getCloudCoverByID(cloudObject)
  local exposure = core_environment.getCloudExposureByID(cloudObject)
  local windSpeed = core_environment.getCloudWindByID(cloudObject)
  local height = core_environment.getCloudHeightByID(cloudObject)

  self.pinOut.coverage.value = coverage
  self.pinOut.exposure.value = exposure
  self.pinOut.windSpeed.value = windSpeed
  self.pinOut.height.value = height
end

return _flowgraph_createNode(C)