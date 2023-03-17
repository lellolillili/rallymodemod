-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}

C.name = 'Template Node'

C.description = [[This is a template node.
It demonstrates all functionality that is currently
available for programmers when creating new nodes.]]
C.category = 'repeat_instant'
--[[
Categories can be:
- repeat_instant:
  -> keep on providing their functionality as long as they receive flow and provide their functionality instantly (no timer or loading)
  -> Example: This node
- repeat_p_duration:
  -> keep on providing their functionality as long as they receive flow and take time to load something before they provide their functionality
  -> Example: getAIMode.lua
- repeat_f_duration:
  -> keep on providing their functionality as long as they receive flow and take time because their functionality has a temporal component (like a timer) (! this category rarely makes sense)
  -> Example: No example (since repeat_f_duration doesn't make sense)

- once_instant:
  -> provide their functionality only once (until reset) and provide their functionality instantly (no timer or loading)
  -> Example: blacklistAction.lua
- once_p_duration:
  -> provide their functionality only once (until reset) and take time to load something before they provide their functionality
  -> Example: spawnVehicle.lua
- once_f_duration:
  -> provide their functionality only once (until reset) and take time because their functionality has a temporal component (like a timer)
  -> Example: countdown.lua

- dynamic_instant:
  -> can switch between providing their functionality once or repeatedly and provide their functionality instantly (no timer or loading)
  -> Example: log.lua
- dynamic_p_duration:
  -> can switch between providing their functionality once or repeatedly and take time to load something before they provide their functionality
  -> Example: directionalGravity.lua (p_duration because of queueLuaCommand)
- dynamic_f_duration:
  -> can switch between providing their functionality once or repeatedly and take time because their functionality has a temporal component (like a timer)(! this category rarely makes sense)
  -> Example: No example (since repeat_f_duration doesn't make sense, this also doesn't make sense)

- simple:
  -> don't need flow (for ease of use)
  -> Example: math.lua
- provider:
  -> don't need flow and don't have input pins
  -> Example: string.lua
- logic:
  -> focus on controlling the flowgraph and managing flow
  -> Example: once.lua
--]]

C.todo = "Some things that should be known about the node or have to be done."

-- dir: Direction can be in or out.
-- type: Can be flow, number, bool, string, vec3, quat, color, table or any. Can also be multi-type, like {'vec3','color'}.
--       vec3, quat and color should be transmitted as lists. For example: vec(1,2,3) => {1,2,3}

-- name: Display name of the pin. If the name is flow or value, it will be hidden, useful for nodes with few pins.
-- default: The default value of pins.
--          For in-pins,  this value will be the default input value when the user choses locked pins.
--                        Multi, Any or Table pins do not support this yet.
--          For out-pins, this will be the default value.
-- description: Description of this pin.
C.pinSchema = {
  {dir = 'in', type = 'flow',             name = 'flow',    default = true,           description = "This is a flow pin."},
  {dir = 'in', type = 'number',           name = 'number',  default = 42,             description = "this is a number pin."},
  {dir = 'in', type = 'number',           name = 'hidNum',  default = 42,             description = "this is a hidden number pin.", hidden = true},
  {dir = 'in', type = 'number',           name = 'fixNum',  default = 42,             description = "this is a hardcoded number pin.", hardcoded = true},
  {dir = 'in', type = 'bool',             name = 'bool',    default = true,           description = "This is a bool pin."},
  {dir = 'in', type = 'string',           name = 'string',  default = "Text",         description = "this is a string pin."},
  {dir = 'in', type = 'vec3',             name = 'vec3',    default = {1,2,3},        description = "this is a 3D vector pin."},
  {dir = 'in', type = 'quat',             name = 'quat',    default = {0,0,0,1},      description = "this is a quaternion pin."},
  {dir = 'in', type = 'color',            name = 'color',   default = {1,1,1,0.5},    description = "this is a color pin."},
  {dir = 'in', type = 'table',            name = 'table',   default = nil,            description = "this is a table pin."},
  {dir = 'in', type = 'any',              name = 'any',     default = nil,            description = "this is an any pin."},
  {dir = 'in', type = {'number','bool'},  name = 'multi',   default = nil,            description = "this is a multi pin."},

  {dir = 'out', type = 'flow',             name = 'flow',   description = "This is a flow pin."},
  {dir = 'out', type = 'number',           name = 'number', description = "this is a number pin."},
  {dir = 'out', type = 'bool',             name = 'bool',   description = "This is a bool pin."},
  {dir = 'out', type = 'string',           name = 'string', description = "this is a string pin."},
  {dir = 'out', type = 'vec3',             name = 'vec3',   description = "this is a 3D vector pin."},
  {dir = 'out', type = 'quat',             name = 'quat',   description = "this is a quaternion pin."},
  {dir = 'out', type = 'color',            name = 'color',  description = "this is a color pin."},
  {dir = 'out', type = 'table',            name = 'table',  description = "this is a table pin.", tableType = 'generic'},
  {dir = 'out', type = 'any',              name = 'any',    description = "this is an any pin."},
  {dir = 'out', type = {'number','bool'},  name = 'multi',  description = "this is a multi pin."}
}

-- add extensions you require in here, instead of loading them through "extensions.foo". this will increase performance
C.dependencies = {}

-- when adding a new node "family", create a new color entry in lua/common/extensions/ui/flowgraph/editor.lua
C.color = ui_flowgraph_editor.nodeColors.default

C.type = 'node' -- can also be 'simple', then it wont have a header

-- this lets the user search for your node. You dont need to include
-- the name of the node or any of the folder names in here.
C.tags = {'template','basic'}


-- This gets called when the node has been created for the first time. Init field here
function C:init(mgr)
  print("This node was initalized!")
  self.myField = "My Field"
  self.data = {
    str = 'Some String',
    int = 123,
    boo = true
  }
  self.sliderWidth = im.IntPtr(5)
end

-- gets called when the project of this node starts execution (before any work)
function C:_executionStarted()
  print("Started Execution.")
end
-- This gets called when the node should execute it's actual function in the flowgraph.
function C:work()
  print("Doing my work...")
end

-- gets called when the project of this node stops execution.
function C:_executionStopped()
  print("Stopped Execution.")
end

-- gets called when the node needs to be cleared. usually before serialization, before starting etc. by default, calls the _executionStopped function.
function C:_onClear()
  --self:_executionStopped() -- default call
  print("cleared.")
end

-- called when the properties are shown
function C:showProperties()
  print("Showing Properties" )
end

-- write custom imgui code here that gets displayed in the property window when the node is selected.
-- return a string so a history point will be created (redo/undo)
function C:drawCustomProperties()
  local reason = nil
  local imText = im.ArrayChar(64, self.myField)
  if im.InputText("##mf" .. self.id, imText, nil, im.InputTextFlags_EnterReturnsTrue) then
    self.myField = ffi.string(imText)
    reason = "Changed Text"
  end
  im.SliderInt("Slider",self.sliderWidth,5,400)
  return reason
end

-- called when the properties are no longer shown
function C:hideProperties()
  print("Hiding Properties")
end

-- write custom imgui code here that gets displayed within the node.
-- always start with builder:Middle()
function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text("I'm a template!")
  im.Text("data.str = " .. self.data.str)
  im.Text("[")
  im.SameLine()
  im.Dummy(im.ImVec2(self.sliderWidth[0],0))
  im.SameLine()

  im.Text("]")
  --im.BeginChild1("child",im.ImVec2(self.sliderWidth[0],50), true)
end


-- Serialize (saving) custom fields into res here.
-- You dont need to serialize fields in self.data
function C:_onSerialize(res)
  print("Serializing Template Node.")
  res.myField = self.myField
end

-- Deserialize (loading) custo fields from data here.
-- self.data will be restored automatically.
function C:_onDeserialized(data)
  print("deserializing Template Node.")
  self.myField = data.myField
end

-- This gets called when the node has been deleted.
function C:destroy()
  print("This node was destroyed!")
end

return _flowgraph_createNode(C)
