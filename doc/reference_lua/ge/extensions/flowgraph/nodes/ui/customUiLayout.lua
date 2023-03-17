-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Custom UI Layout'
C.description = 'Lets you save and restore a custom UI layout.'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.category = 'provider'

C.pinSchema = {
  { dir = 'out', type = 'table',tableType = 'layoutData', name = 'layout', default = 'scenario', description = 'The stored layout.' },
}

C.tags = {}

function C:init()

end

function C:_executionStarted()
  self.pinOut.layout.value = {apps = self.storedLayout, layoutName = 'procedural Layout ' .. self.id}
end

function C:uniqueId() return self.mgr.id.."_"..self.id end
function C:drawCustomProperties()
  local reason = nil
  if im.Button("Capture") then
    self.storedLayout = nil
    guihooks.trigger('getCurrentLayoutToLua', self:getCmd())
    reason = "Captured new layout."
  end
  im.tooltip("Saves the current layout into the node.")
  if im.Button("Clear") then
    self.storedLayout = nil
    reason = "Cleared Layout."
  end
  im.tooltip("Clears the currently stored layout.")
  if self.storedLayout then
    if im.Button("Load Stored Layout") then
      core_gamestate.setGameState("temp_fg_"..self:uniqueId(),self.storedLayout)
    end
    im.tooltip("Loads the currently stored layout.")
  end
  if im.Button("Load Freeroam layout") then
    core_gamestate.setGameState("freeroam","freeroam")
  end
  im.tooltip("Saves the default freeroam layout.")

  im.Text(self.storedLayout and string.format("Stored Layout (%d Elements)", #self.storedLayout) or "No Layout!")
  if im.BeginCombo("loadlayout","Copy Layout from...") then
    local layouts = {} -- ui_apps.getLayouts()
    local sorted = {}
    for key, layout in pairs(layouts) do
      if type(layout) == "table" and #layout > 0 then
        table.insert(sorted, key)
      end
    end
    table.sort(sorted)
    for _, key in ipairs(sorted) do
      if im.Selectable1(key) then
        self.storedLayout = deepcopy(layouts[key])
        reason = "Copied layout " ..key .."."
      end
    end
    im.EndCombo()
  end
  im.tooltip("Makes a copy of an existing layout and stores it in the node.")

  return reason
end

function C:setLayout(data)

  self.storedLayout = data.apps
  dump(data)
end

function C:getCmd(action)
  return 'core_flowgraphManager.getManagerByID('..self.mgr.id..').graphs['..self.graph.id..'].nodes['..self.id..']:setLayout'
end

function C:_onSerialize(res)
  res.storedLayout = self.storedLayout
end

function C:_onDeserialized(data)
  self.storedLayout = data.storedLayout or nil
end


return _flowgraph_createNode(C)
