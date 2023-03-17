-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Set Time of Day'
C.icon = "simobject_timeofday"
C.description = "Sets the current Time of Day settings."
C.category = 'dynamic_instant'

C.pinSchema = {
    { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
    { dir = 'in', type = 'number', name = 'time', description = "Time of day on a scale from 0 to 1. 0/1 is midday, 0.5 is midnight ." },
    { dir = 'in', type = 'bool', name = 'play', description = "Play or pause the ToD progression." },
    { dir = 'in', type = 'number', name = 'dayScale', hidden = true, description = "Scalar applied to time that elapses while the sun is up." },
    { dir = 'in', type = 'number', name = 'nightScale', hidden = true, description = "Scalar applied to time that elapses while the sun is down." },
    { dir = 'in', type = 'number', name = 'dayLength', hidden = true, description = "length of day in real world seconds." },
    { dir = 'in', type = 'number', name = 'azimuthOverride', hidden = true, description = "Used to specify an azimuth that will stay constant throughout the day cycle." }
}

C.tags = {'tod'}

function C:init(mgr)
  self.data.restoreTod = true
end

function C:postInit()
  self.pinInLocal.time.numericSetup = {
    min = 0,
    max = 1,
    type = 'float',
    gizmo = 'slider',
  }

  self.pinInLocal.time.hardTemplates = {
    {label = "Midday", value = 0},
    {label = "Evening", value = 0.25},
    {label = "Midnight", value = 0.5},
    {label = "Morning", value = 0.75},
  }
end

function C:_executionStarted()
    --self.storedTod = core_environment.getTimeOfDay()
end
function C:_executionStopped()
    --if self.data.restoreTod and self.storedTod then
        --core_environment.setTimeOfDay(self.storedTod)
    --    self.storedTod = nil
    --end
end

function C:workOnce()
    self:setTimeOfDay()
end

function C:work()
    if self.dynamicMode == 'repeat' then
        self:setTimeOfDay()
    end
end

function C:setTimeOfDay()
    self.mgr.modules.mission.todChanged = true
    core_environment.setTimeOfDay({
        time = self.pinIn.time.value % 1,
        play = self.pinIn.play.value,
        dayScale = self.pinIn.dayScale.value,
        nightScale = self.pinIn.nightScale.value,
        dayLength = self.pinIn.dayLength.value,
        azimuthOverride = self.pinIn.azimuthOverride.value,
    })
end

return _flowgraph_createNode(C)
