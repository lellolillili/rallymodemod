-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local imgui = ui_imgui
local ffi = require("ffi")

local function setupEditorGuiTheme()
  local Col_Button = imgui.GetStyleColorVec4(imgui.Col_Button)

  editor.color = {
    beamng = imgui.ImColorByRGB(255,102,0,255),
    black = imgui.ImColorByRGB(0,0,0,255),
    buttonInactive = imgui.ImColorByRGB(Col_Button.x * 255, Col_Button.y * 255, Col_Button.z * 255, Col_Button.w * 255 / 2),
    darkgrey = imgui.ImColorByRGB(64,64,64,255),
    gold = imgui.ImColorByRGB(254,216,25,255),
    green = imgui.ImColorByRGB(60,179,113, 255),
    grey = imgui.ImColorByRGB(128,128,128,255),
    lightgrey = imgui.ImColorByRGB(192,192,192,255),
    transparent = imgui.ImColorByRGB(255,0,0,0),
    warning = imgui.ImColorByRGB(255,204,0,255),
    white = imgui.ImColorByRGB(255,255,255,255)
  }
end

editor.setupEditorGuiTheme = setupEditorGuiTheme