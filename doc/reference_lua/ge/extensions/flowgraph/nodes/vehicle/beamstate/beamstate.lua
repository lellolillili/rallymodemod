-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Beamstate'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle

C.description = [[Provides a selection of nonparametric Beamstate functions.]]
C.category = 'once_p_duration'
C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Defines the id of the vehicle to apply function to.' },
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}
C.tags = {'destroy','funstuff'}

function C:init()
  self.functions = {
    'breakAllBreakgroups',
    'breakHinges',
    'deflateTires'
  }
  self.selected = 'breakAllBreakgroups'
end

function C:drawCustomProperties()
  local reason = nil
  if im.BeginCombo("##beamFunc" .. self.id, self.selected) then
    for _, fun in ipairs(self.functions) do
      if im.Selectable1(fun, fun == self.selected) then
        self.selected = fun
        reason = "Changed function to " .. fun
      end
    end
    im.EndCombo()
  end
  return
end

function C:workOnce()
  local veh
  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  end
  if not veh then
    return
  end
  veh:queueLuaCommand("beamstate."..self.selected.."()")
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text(tostring(self.selected))
end


function C:_onSerialize(res)
  res.selected = self.selected
end

function C:_onDeserialized(nodeData)
  self.selected = nodeData.selected or ""
end

return _flowgraph_createNode(C)
