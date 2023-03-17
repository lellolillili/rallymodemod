-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- GE do calls `onPreRender()`
-- VEH do calls on `onDebugDraw()`


local M = {}

local ffifound, ffi = pcall(require, 'ffi')
if not ffifound then
  log("E", "parse", "ffi missing")
else
  ffi.cdef[[
    typedef struct { float x, y, z; } Vector3;
  ]]
  ffi.cdef[[
    void BNG_DBG_DRAW_Sphere(float x, float y, float z, float radius, float r, float g, float b, float a);
  ]]
  ffi.cdef[[
    void BNG_DBG_DRAW_Cylinder(float x1, float y1, float z1, float x2, float y2, float z2, float radius, float r, float g, float b, float a);
  ]]
  ffi.cdef[[
    void BNG_DBG_DRAW_Line(float x1, float y1, float z1, float x2, float y2, float z2, float r, float g, float b, float a);
  ]]
  ffi.cdef[[
    void BNG_DBG_DRAW_Text(float x1, float y1, float z1, const char * text, float r, float g, float b, float a);
  ]]
  ffi.cdef[[
    void copy_vehicle_nodes(int vehID, Vector3* nodes, int nodeCount);
  ]]
end

M.Sphere = ffifound and ffi.C.BNG_DBG_DRAW_Sphere or nop
M.Cylinder = ffifound and ffi.C.BNG_DBG_DRAW_Cylinder or nop
M.Line = ffifound and ffi.C.BNG_DBG_DRAW_Line or nop
M.Text = ffifound and ffi.C.BNG_DBG_DRAW_Text or nop
M.copy_vehicle_nodes = ffifound and ffi.C.copy_vehicle_nodes or nop

return M