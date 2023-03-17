local im  = ui_imgui
local C = {}

C.name = 'Reset drift'

C.description = "Reset the scores and other systems"
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'flow', impulse = true, name = 'resetDrift', description = "Will fire when a tight drift is detected"},
}

C.tags = {'gameplay', 'utils'}

local callbacks
function C:work()
  if self.pinIn.resetDrift.value then
    self.mgr.modules.drift:resetExtension()
    self.mgr.modules.drift:resetModule()
  end
end

return _flowgraph_createNode(C)