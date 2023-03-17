-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'Sevensegment Display'
C.description = 'Creates and manages a sevensegment display.'
C.category = 'repeat_instant'

C.author = 'BeamNG'
C.pinSchema = {
    { dir = 'in', type = 'flow', name = 'clear', description = 'When receiving flow, clears the display.', impulse = true },
    { dir = 'in', type = 'vec3', name = 'position', description = 'Defines the position of the display.' },
    { dir = 'in', type = 'quat', name = 'rotation', description = 'Defines the rotation of the display.' },
    { dir = 'in', type = 'number', name = 'number', description = 'The number to be displayed.' },
    { dir = 'out', type = 'number', name = 'number', description = 'Displayed number.' },
}

C.modes = { 'number', 'minutes', 'hours' }
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.tags = {}

function C:init(mgr, ...)
    self.objects = {}
    self.displayMode = ''
    self.data.mode = 'minutes'
    self.data.scaling = 1
    self.data.count = 5
    self.data.decimals = 3
    self.data.decimalOffset = 1
    self.data.spacing = 5
    self.data.shapeFolder = "art/shapes/quarter_mile_display/display_"
    self.data.showLeadingZeroes = false
    self.extension = '.dae'
    self.spawned = false
end

function C:createObjects(objectName)
    self.rot = self.pinIn.rotation.value or { 0, 0, 0, 0 }
    self.rot = quat(self.rot[1], self.rot[2], self.rot[3], self.rot[4])
    self.tRot = self.rot:toTorqueQuat()
    self.scl = vec3(self.data.scaling, self.data.scaling, self.data.scaling)

    for i = 1, self.data.count do
        local object = createObject("TSStatic")
        object.shapeName = self.data.shapeFolder .. '8' .. self.extension

        local pos = self.pinIn.position.value or { 0, 0, 0 }
        pos = vec3(pos)
        local off = -self.data.spacing * (self.data.count - 1) / 2 + self.data.spacing * (i - 1)
        pos = pos + (self.rot:__mul(vec3(-off, 0, 0)))
        pos = vec3(pos.x, pos.y, pos.z)
        object:setPosition(pos)

        object:setScale(self.scl)
        object:setField('rotation', 0, self.tRot.x .. ' ' .. self.tRot.y .. ' ' .. self.tRot.z .. ' ' .. self.tRot.w)
        object.canSave = false

        -- name will be generated to avoid duplicate names
        local name = "ssDisplay_" .. tostring(os.time()) .. "_" .. self.id .. '_' .. i
        object:registerObject(name)
        self.objects["" .. i] = object
    end
    if self.data.decimals > 0 and self.data.decimals <= self.data.count then
        self:makeDot(vec3(-self.data.spacing * (self.data.count - 1) / 2 + self.data.spacing * (self.data.decimals - 1) - self.data.decimalOffset, 0, 0), 'decimal')
    end

    if self.data.mode == 'minutes' then
        if self.data.decimals + 2 < self.data.count then
            self:makeDot(vec3(-self.data.spacing * (self.data.count - 1) / 2 + self.data.spacing * (self.data.decimals + 1) - self.data.decimalOffset, 0, 3 * self.scl.z / 100), 'm_1')
            self:makeDot(vec3(-self.data.spacing * (self.data.count - 1) / 2 + self.data.spacing * (self.data.decimals + 1) - self.data.decimalOffset, 0, 8 * self.scl.z / 100), 'm_2')
        end
    end
    self.spawned = true
end

function C:makeDot(offset, name)
    local object = createObject("TSStatic")
    object.shapeName = self.data.shapeFolder .. 'period' .. self.extension

    local pos = self.pinIn.position.value or { 0, 0, 0 }
    pos = vec3(pos)
    pos = pos + (self.rot:__mul(offset))
    pos = vec3(pos.x, pos.y, pos.z)
    object:setPosition(pos)

    object:setScale(self.scl)
    object:setField('rotation', 0, self.tRot.x .. ' ' .. self.tRot.y .. ' ' .. self.tRot.z .. ' ' .. self.tRot.w)
    object.canSave = false

    -- name will be generated to avoid duplicate names
    local name = "ssDisplay_" .. tostring(os.time()) .. "_" .. self.id .. '_' .. 'dot_' .. name
    object:registerObject(name)
    self.objects['dot_' .. name] = object
end

function C:updateNumbers()
    self.oldNumber = self.pinIn.number.value
    local leadingZeroes = true
    for i = 1, self.data.count do
        local m = math.pow(10, (self.data.count - self.data.decimals) - i)
        local n = math.floor(self.oldNumber / m)
        if i == self.data.count then
            n = math.floor(self.oldNumber / m + 0.5)
        end
        n = n % 10
        local obj = self.objects['' .. i]
        local sName = self.data.shapeFolder .. 'empty' .. self.extension

        if n >= 0 and n < 10 then
            sName = self.data.shapeFolder .. n .. self.extension
        end
        if not self.data.showLeadingZeroes then
            if leadingZeroes and m > 1 and n == 0 then
                sName = self.data.shapeFolder .. 'empty' .. self.extension
            else
                leadingZeroes = false
            end
        end
        obj:preApply()
        obj:setField('shapeName', 0, sName)
        obj:postApply()
    end

end

function C:_executionStopped()
    self:clearObjects()
end

function C:_executionStarted()
    self.oldNumber = nil
end

function C:clearObjects()
    for _, obj in pairs(self.objects) do
        if obj then
            if editor and editor.onRemoveSceneTreeObjects then
                editor.onRemoveSceneTreeObjects({ obj:getId() })
            end
            obj:delete()
        end
    end
    table.clear(self.objects)
    self.spawned = false
end

function C:work()
    if self.pinIn.clear.value then
        self:clearObjects()
        return
    end
    if not self.spawned then
        self:createObjects()
    end
    if self.oldNumber ~= self.pinIn.number.value then
        self:updateNumbers()
    end
end

function C:onClientEndMission()
    self:clearObjects()
end

function C:destroy()
    self:clearObjects()
end

return _flowgraph_createNode(C)
