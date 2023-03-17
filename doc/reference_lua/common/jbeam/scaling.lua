--[[
This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
If a copy of the bCDDL was not distributed with this
file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
This module contains a set of functions which manipulate behaviours of vehicles.
]]

local M = {}

local str_byte, str_sub = string.byte, string.sub
local jbeamUtils = require("jbeam/utils")

local function process(vehicle)
  profilerPushEvent('jbeam/scaling.process')

  local stack = {}
  for keyEntry, entry in pairs(vehicle) do
    if type(entry) == "table" and tableIsDict(entry) and not jbeamUtils.ignoreSections[keyEntry] then
      stack[1] = entry
      local stackidx = 2

      while stackidx > 1 do
        stackidx = stackidx - 1
        local data = stack[stackidx]
        for key, v in pairs(data) do
          local typev = type(v)
          if typev == 'number' then
            if type(key) == 'string' and str_byte(key,1)==115 and str_byte(key,2)==99 and str_byte(key,3)==97 and str_byte(key,4)==108 and
                str_byte(key,5)==101 and str_byte(key,6)~=nil then --scale
              -- look for scaled key
              local keytoscale = str_sub(key, 6)
              local dataval = data[keytoscale]
              if type(dataval) == "number" then
                data[keytoscale] = dataval * v
              end
              data[key] = nil
            end
          elseif typev == 'table' then
            stack[stackidx] = v
            stackidx = stackidx + 1
          end
        end
      end
    end
  end

  profilerPopEvent() -- jbeam/scaling.process
end

M.process = process

return M