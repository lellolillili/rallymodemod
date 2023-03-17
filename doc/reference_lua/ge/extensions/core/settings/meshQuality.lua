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

M.qualityLevels.Lowest["$pref::TS::maxDecalCount"] = 2000
M.qualityLevels.Lowest["$pref::TS::detailAdjust"] = 0.5
M.qualityLevels.Lowest["$pref::TS::skipRenderDLs"] = 0
M.qualityLevels.Lowest["$pref::Terrain::lodScale"] = 2.0
M.qualityLevels.Lowest["$pref::GroundCover::densityScale"] = 0

M.qualityLevels.Low["$pref::TS::maxDecalCount"] = 3000
M.qualityLevels.Low["$pref::TS::detailAdjust"] = 0.75
M.qualityLevels.Low["$pref::TS::skipRenderDLs"] = 0
M.qualityLevels.Low["$pref::Terrain::lodScale"] = 1.5
M.qualityLevels.Low["$pref::GroundCover::densityScale"] = 0.50

M.qualityLevels.Normal["$pref::TS::maxDecalCount"] = 4000
M.qualityLevels.Normal["$pref::TS::detailAdjust"] = 1.0
M.qualityLevels.Normal["$pref::TS::skipRenderDLs"] = 0
M.qualityLevels.Normal["$pref::Terrain::lodScale"] = 1.0
M.qualityLevels.Normal["$pref::GroundCover::densityScale"] = 0.75

M.qualityLevels.High["$pref::TS::maxDecalCount"] = 6000
M.qualityLevels.High["$pref::TS::detailAdjust"] = 1.5
M.qualityLevels.High["$pref::TS::skipRenderDLs"] = 0
M.qualityLevels.High["$pref::Terrain::lodScale"] = 0.75
M.qualityLevels.High["$pref::GroundCover::densityScale"] = 1.0

return M