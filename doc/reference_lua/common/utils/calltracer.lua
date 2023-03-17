 -- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

--[[

Utility created by BeamNG

traces calls during its activation time and outputs a file that can be analysed by yed (https://www.yworks.com/products/yed)

how to use:

calltracer = require('utils/calltracer')
...

calltracer.reset() -- if you want to have a summary, comment this
calltracer.start()

-- your code to be examined

calltracer.stop()
calltracer.save('callgraph.tgf')

]]


local M = {}

local nodes = {}

-- s1 = immediate caller
-- s2 = caller of caller
local function trace(event, line)
  local s1 = debug.getinfo(2)
  local s2 = debug.getinfo(3)

  -- do not trace C functions
  if s1.what == 'C' or not s2 or s2.what == 'C' or not s1.name or not s2.name then return end

  -- do not trace calls to the common functions
  --if s1.source:find('@lua/common/') or s2.source:find('@lua/common/') then return end

  local s1n = (s1.name or '') .. s1.source .. ':' .. s1.linedefined
  local s2n = (s2.name or '') .. s2.source .. ':' .. s2.linedefined

  if not nodes[s2n] then nodes[s2n] = {} end
  if not nodes[s1n] then nodes[s1n] = {} end

  nodes[s2n][s1n] = 1
end

local function start()
  debug.sethook(trace, "c")
end

local function stop()
  debug.sethook()
end

-- exports a tgf file that you can open with yed
local function save(filename)
  --dump(nodes)
  local txt = ''

  local c = 0
  local nodeMap = {}

  for k, _ in pairs(nodes) do
    nodeMap[k] = c
    txt = txt .. c .. ' ' ..  k .. '\n'
    c = c + 1
  end

  txt = txt ..'#\n'

  for k, callTable in pairs(nodes) do
    for callNode, _ in pairs(callTable) do
        txt = txt ..  '' .. nodeMap[k] .. ' ' .. nodeMap[callNode] .. '\n'
    end
  end

  writeFile(filename, txt)

end

local function reset()
  nodes = {}
end

-- public interface
M.start = start
M.stop = stop
M.reset = reset
M.save = save

return M
