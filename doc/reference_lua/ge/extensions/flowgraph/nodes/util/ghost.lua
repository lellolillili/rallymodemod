-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'GHOST'
C.category = 'logic'
C.pinSchema = {}
C.tags = {'util'}
C.hidden = true


function C:init()
  self.formerNodeType = "NOT GHOST"
end

function C:work()

end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text("Former node type: " .. self.formerNodeType)
  if im.Button("Dump ghost data") then
    dump(self.ghostData)
  end
end

function C:__onSerialize()
  return self.ghostData
end

function C:_onDeserialized(nodeData)
  self:__setNodeError('work', 'Error while deserializing node\nNode ' .. nodeData.type .. " doesn't exist!")
  self.formerNodeType = nodeData.type
  local path = {}
  for k,v in string.gmatch(nodeData.type, "%a+") do
    table.insert(path, k)
  end
  self.name = "[GHOST]" .. path[#path]
  self.ghostData = nodeData
end

return _flowgraph_createNode(C)