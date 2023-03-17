-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Career Active'
C.description = 'Checks if Career is active and enabled.'
C.color = im.ImVec4(0.03,0.41,0.64,0.75)
C.category = 'repeat_instant'

C.pinSchema = {
    { dir = 'out', type = 'flow', name = 'enabled', description = "Outflow when career is active and enabled." },
    { dir = 'out', type = 'flow', name = 'disabled', description = "Outflow when career is not active",},
    { dir = 'out', type = 'bool', name = 'active', description = "If career is active and enabled", hidden = true },
}
C.dependencies = {'gameplay_walk'}



function C:work(args)
  self.pinOut.flow.value = true
  self.pinOut.enabled.value = (career_career and career_career.isCareerActive()) or false
  self.pinOut.disabled.value = not self.pinOut.enabled.value
  self.pinOut.active.value = self.pinOut.enabled.value
end

function C:drawMiddle(builder, style)
  builder:Middle()

    editor.uiIconImage(editor.icons[(career_career and career_career.isCareerActive()) and 'check' or 'close'], im.ImVec2(40, 40), (career_career and career_career.isCareerActive()) and im.ImVec4(0.3,1,0.3,1) or im.ImVec4(1,1,1,0.3))

end

return _flowgraph_createNode(C)
