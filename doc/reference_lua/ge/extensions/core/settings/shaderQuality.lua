-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local C = {}
local M = {}

M.qualityLevels = {
  Lowest = {
    caseSensitive = 1,
  },
  Low = {
    caseSensitive = 1,
  },
  Normal = {
    caseSensitive = 1,
  },
  High = {
    caseSensitive = 1,
  },
}

M.qualityLevels.Lowest["$pref::Video::disablePixSpecular"] = 0
M.qualityLevels.Lowest["$pref::Video::disableNormalmapping"] = 0
M.qualityLevels.Lowest["$pref::Video::disableParallaxMapping"] = 1
M.qualityLevels.Lowest["$pref::Water::disableTrueReflections"] = 1
M.qualityLevels.Lowest["$pref::Video::ShaderQualityGroup"] = "Lowest"

M.qualityLevels.Low["$pref::Video::disablePixSpecular"] = 0
M.qualityLevels.Low["$pref::Video::disableNormalmapping"] = 0
M.qualityLevels.Low["$pref::Video::disableParallaxMapping"] = 1
M.qualityLevels.Low["$pref::Water::disableTrueReflections"] = 1
M.qualityLevels.Low["$pref::Video::ShaderQualityGroup"] = "Low"

M.qualityLevels.Normal["$pref::Video::disablePixSpecular"] = 0
M.qualityLevels.Normal["$pref::Video::disableNormalmapping"] = 0
M.qualityLevels.Normal["$pref::Video::disableParallaxMapping"] = 0
M.qualityLevels.Normal["$pref::Water::disableTrueReflections"] = 0
M.qualityLevels.Normal["$pref::Video::ShaderQualityGroup"] = "Normal"

M.qualityLevels.High["$pref::Video::disablePixSpecular"] = 0
M.qualityLevels.High["$pref::Video::disableNormalmapping"] = 0
M.qualityLevels.High["$pref::Video::disableParallaxMapping"] = 0
M.qualityLevels.High["$pref::Water::disableTrueReflections"] = 0
M.qualityLevels.High["$pref::Video::ShaderQualityGroup"] = "High"

return M