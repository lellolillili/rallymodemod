-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'Single Marker'
C.description = 'Displays a single Marker. Needs to be manually reset when no longer used. Will only update the transparency depending on camera if continous flow is supplied.'
C.author = 'BeamNG'
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = "Inflow for this node." },
  { dir = 'in', type = 'flow', name = 'reset', description = "Triggering this will remove the marker.", impulse = true },
  { dir = 'in', type = 'vec3', name = 'position', description = "The position of this marker." },
  { dir = 'in', type = { 'number', 'vec3' }, name = 'radius', description = "The radius of this marker." },
  { dir = 'in', type = 'string', name = 'markerType', hidden = true, description = "(Optional) The type of marker to use." },
  { dir = 'in', type = 'color', name = 'color', hidden = true, hardcoded = true, default = { 1, 1, 1, 1 }, description = "The color of this marker. If no value is given, uses white as default." },
  { dir = 'in', type = 'number', name = 'fadeNearDist', hidden = true, description = "(Optional) The minimum distance for the marker color alpha." },
  { dir = 'in', type = 'number', name = 'fadeFarDist', hidden = true, description = "(Optional) The maximum distance for the marker color alpha." },

  { dir = 'out', type = 'flow', name = 'flow', description = "Outflow for this node." }
}
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.tags = {}

C.legacyPins = {
  _in = {
    clear = 'reset'
  }
}

local markerTypes = {'overhead', 'ringMarker', 'sideColumnMarker', 'sideMarker', 'cylinderMarker'}

function C:init(mgr, ...)
  self.position = {}
  self.radius = {}
  self.clr = {}
  self.marker = nil
  self.shown = false
  self.data.zOffset = 0
end

function C:postInit()
  local t = {}
  for _, v in ipairs(markerTypes) do
    table.insert(t, {value = v})
  end
  self.pinInLocal.markerType.hardTemplates = t
end

-- removes all the markers and then removes the list.
function C:hideMarker()
  if self.marker ~= nil then
    self.marker:clearMarkers()
  end
  self.marker = nil
end

function C:_afterTrigger()
  if self.pinIn.flow.value == false and self.shown then
    self:hideMarker()
  end
end

function C:_executionStopped()
  self:hideMarker()
end

local posIn, radIn
local oldPosIn, oldRadIn = nil, nil
function C:_executionStarted()
  oldPosIn, oldRadIn = nil, nil
end
function C:fillFields()
  posIn = self.pinIn.position.value
  radIn = self.pinIn.radius.value
  if oldPosIn ~= posIn or oldRadIn ~= radIn then
    oldRadIn = radIn
    oldPosIn = posIn
    if type(radIn) == 'table' then
      radIn = radIn[1]
    end
    --dumpz(self.pinIn.radius,2)
    local clrIn = self.pinIn.color.value
    if not clrIn or clrIn == {} then clrIn = {1,0,0,0.8} end
    if not radIn then radIn = 2 end
    if not posIn then return true end
    self.position = deepcopy(posIn)
    self.position[3] = self.position[3] + self.data.zOffset
    self.radius = radIn
    self.clr = clrIn
    return true
  else
    return false
  end
end

function C:blend()

end

local sendTable = {pos = vec3(), radius = 0}
local fieldsChanged = false
function C:work()
  if self.pinIn.reset.value then
    --remove marker
    self:hideMarker()
    --self.marker.obj:updateInstanceRenderData()
    --self.marker.objBase:updateInstanceRenderData()
    self.pinOut.flow.value = false
    return
  end

  if self.pinIn.flow.value then
    fieldsChanged = self:fillFields()
    if self.marker == nil then
      self.marker = require("scenario/race_marker").createRaceMarker(true, self.pinIn.markerType.value)
      self.marker:setToCheckpoint({pos = vec3(self.position), radius = self.radius, fadeNear = self.pinIn.fadeNearDist.value, fadeFar = self.pinIn.fadeFarDist.value})
      self.marker:setMode('default')
    end
    if self.marker ~= nil then
      if fieldsChanged then
        sendTable.pos:set(self.position[1],self.position[2], self.position[3])
        sendTable.radius = self.radius
        self.marker:setToCheckpoint(sendTable)
      end
      if self.marker.modeInfos then
        self.marker.modeInfos.default.color = self.clr
      end
      self.marker:update(self.mgr.dtReal, self.mgr.dtSim)
      self.pinOut.flow.value = true
    end
  end
end

function C:onClientEndMission()
  self:_executionStopped()
end

function C:destroy()
  self:_executionStopped()
end

return _flowgraph_createNode(C)
