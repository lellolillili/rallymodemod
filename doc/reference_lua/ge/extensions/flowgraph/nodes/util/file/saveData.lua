-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Save Data'
C.color = ui_flowgraph_editor.nodeColors.file
C.icon = ui_flowgraph_editor.nodeIcons.file
C.description = "Saves simple data into a file to be re-used in multiple sessions."
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'string', name = 'file', description = "Name of the file to save into. Extension not needed.", fixed = true },
}

C.allowedManualPinTypes = {
  flow = false,
  string = true,
  number = true,
  bool = true,
  any = true,
  table = true,
  vec3 = true,
  quat = true,
  color = true,
}
C.tags = {}

function C:init(mgr)
  self.savePins = true
  self.allowCustomInPins = true
end

function C:workOnce()
  if self.pinIn.file.value then
    for name, pin in pairs(self.pinIn) do
      if name ~= 'flow' and name ~= 'reset' and name ~= 'file' then
        self.mgr.modules.file:write(self.pinIn.file.value, name, self.pinIn[name].value)
      end
    end
  end
end

return _flowgraph_createNode(C)
