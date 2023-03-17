-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = 'AI Random'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Causes the AI to take random paths.'
C.category = 'once_p_duration'

C.pinSchema = {
    { dir = 'in', type = 'number', name = 'aiVehId', description = 'Defines the id of the vehicle to activate the AI on.' },
}

C.tags = {}

function C:workOnce()
    local source
    if self.pinIn.aiVehId.value and self.pinIn.aiVehId.value ~= 0 then
        source = scenetree.findObjectById(self.pinIn.aiVehId.value)
    else
        source = be:getPlayerVehicle(0)
    end

    source:queueLuaCommand('ai.setState({mode = "random"})')
end

return _flowgraph_createNode(C)
