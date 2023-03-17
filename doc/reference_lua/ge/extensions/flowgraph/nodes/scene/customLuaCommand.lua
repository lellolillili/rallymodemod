-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Custom Lua Command'
C.description = "Input Custom Lua Command"
C.category = 'once_instant'

C.pinSchema = {
    { dir = 'in', type = 'string', name = 'func', description = 'The function that will be called in Lua.' },
    { dir = 'out', type = 'any', name = 'return', description = 'return value' },
}
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.tags = {}

function C:init()
    self.clearOutPinsOnStart = false
end

function C:_executionStarted()
    self.pinOut['return'].value = nil
end

function C:workOnce()
    if self.pinIn.func.value then
        local functionToExecute = loadstring(self.pinIn.func.value)
        local status, ret = pcall(functionToExecute)
        self.pinOut.flow.value = status
        self.pinOut['return'].value = ret
    end
end

function C:_onDeserialized(data)
    if data.data.func then
        data.hardcodedPins = {
            func = { value = data.data.func, type = 'string' }
        }
    end
    self.data.func = nil
end

return _flowgraph_createNode(C)
