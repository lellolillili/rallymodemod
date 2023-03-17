-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

C.name = 'New Node Template'
C.description = "Basic template for a new node"
-- C.color = ui_flowgraph_editor.nodeColors.    -> set node color
-- C.icon = ui_flowgraph_editor.nodeIcons.      -> set node icon
-- C.category = ''                              -> set node category
-- C.tags = { '' }                              -> set node tags


C.pinSchema = {
{dir = 'in', type = 'flow',             name = 'flow',    default = true,           description = "This is a flow pin."},
{dir = 'in', type = 'number',           name = 'number',  default = 42,             description = "this is a number pin."},
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




function C:work()
end


return _flowgraph_createNode(C)
