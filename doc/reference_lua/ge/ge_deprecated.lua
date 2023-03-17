-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

function setfov(...)
  log('E', "", "setFov() is deprecated. Please use setCameraFovDeg() instead.")
  -- fallback
  setCameraFovDeg(...)
end

encodeJson = jsonEncode
jsonEncodePretty = jsonEncodePretty
serializeJsonToFile = jsonWriteFile
writeJsonFile = jsonWriteFile
readJsonFile = jsonReadFile
