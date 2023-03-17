-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt


-- do not use this file/extensions directly, use ui_imgui instead

-- this file needs to be in sync with imgui_api.h


local ffi = require('ffi')

-- base requirement for imgui_gen.h
ffi.cdef([[
typedef struct ImVector {
  int Size;
  int Capacity;
  void* Data;
} ImVector;

typedef struct ImVec2 {
  float x;
  float y;
} ImVec2;
typedef struct ImVec4 {
  float x;
  float y;
  float z;
  float w;
} ImVec4;
]])
ffi.cdef(readFile('lua/common/extensions/ui/imgui_gen.h'))
ffi.cdef(readFile('lua/common/extensions/ui/imgui_custom.h'))

local M = {}

M.ctx = nil -- global lua imgui context

require('/common/extensions/ui/imgui_gen')(M)
require('/common/extensions/ui/imgui_custom')(M)

return M