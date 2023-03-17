-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = 'Groundmarkers'
C.icon = "navigation"
C.description = 'Creates markers that show the way to the chosen waypoint.'
C.category = 'repeat_instant'

C.color = im.ImVec4(1, 1, 0, 0.75)
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'clear', description = "Reset the markers", impulse = true },
  { dir = 'in', type = { 'string', 'table', 'vec3' }, tableType = 'navgraphPath', name = 'target', description = "The target to navigate to. Can be a waypoint name, position or list of these things." },
  { dir = 'in', type = 'color', name = 'color', hidden = true, default = { 0.2, 0.53, 1, 1 }, hardcoded = true, description = "Color of the markings (Optional)" },
  { dir = 'in', type = 'number', name = 'cutOffDrivability', hidden = true, description = "The drivability value, above which the road is penalized in planning (Optional)" },
  { dir = 'in', type = 'number', name = 'penaltyAboveCutoff', hidden = true, description = "The penalty above the cutoff drivability (Optional)" },
  { dir = 'in', type = 'number', name = 'penaltyBelowCutoff', hidden = true, description = "The penalty below the cutoff drivability (Optional)" }
}
C.legacyPins = {
  _in = {
    pos = 'target',
    waypoint = 'target',
    reset = 'clear'
  }
}
C.tags = { 'arrow', 'path', 'destination', 'navigation' }
C.dependencies = { 'core_groundMarkers' }

function C:init(mgr, ...)
  self.data.step = 8
  self.data.fadeStart = 100
  self.data.fadeEnd = 150
  self.data.color = { 0.2, 0.53, 1, 1 }
end

function C:drawMiddle(builder, style)
end

function C:work(args)
  if self.pinIn.clear.value then
    core_groundMarkers.resetAll()
    self.lastTarget = nil
  end

  if self.pinIn.flow.value then
    if self.lastTarget ~= self.pinIn.target.value then
      self.lastTarget = self.pinIn.target.value
      local target = {}
      if type(self.lastTarget) == 'table' and type(self.lastTarget[1]) == 'number' then
        target = vec3(self.lastTarget)
      else
        target = self.lastTarget
      end
      core_groundMarkers.setFocus(target, self.data.step, self.data.fadeStart,
          self.data.fadeEnd, ep, nil, self.pinIn.color.value, self.pinIn.cutOffDrivability.value,
          self.pinIn.penaltyAboveCutoff.value, self.pinIn.penaltyBelowCutoff.value)
    end
  end
end

function C:sameTable(a, b)
  if type(a) ~= type(b) then
    return false
  else
    if type(a) == 'number' then
      return math.abs(a - b) < 0.001
    end
    if type(a) == 'string' then
      return a == b
    end
    if type(a) == 'table' then
      if #a ~= #b then
        return false
      end
      local ret = true
      for i = 1, #a do
        if not self:sameTable(a[i], b[i]) then
          return false
        end
      end
      return true
    end
    return true
  end


end

function C:_executionStopped()
  if core_groundMarkers then
    core_groundMarkers.resetAll()
  end
end
function C:_executionStarted()
  self.lastTarget = nil

end

return _flowgraph_createNode(C)
