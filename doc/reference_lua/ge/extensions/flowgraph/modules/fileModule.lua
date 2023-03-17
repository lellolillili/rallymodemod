-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local C = {}
C.moduleOrder = 000 -- low first, high later
local savePath = "settings/cloud/flowgraphSaveData"
local ext = ".save.json"
local defaultFile = {lastModified = 0, data = {}}

function C:init()
  self:clear()
end

function C:clear()
  self.files = {}
  self.changed = {}
end

function C:forceReload(file)
  self.files[file] = nil
end

function C:getFile(file)
  if not self.files[file] then
    local p = savePath .. file .. ext
    self.mgr:logEvent("Loading file " .. file,"I", "File " .. p .. " has been loaded.")
    if FS:fileExists(p) then
      self.files[file] = readJsonFile(p) or deepcopy(defaultFile)
    else
      self.files[file] = deepcopy(defaultFile)
    end
    if not self.files[file].data then
      self.files[file] = {lastModified = 0, data = self.files[file]}
    end
  end

  if self.files[file] then return self.files[file] end
end

function C:write(file, field, value)
  local f = self:getFile(file)
  f.data[field] = value
  f.lastModified = os.time()
  self.changed[file] = true
end

function C:read(file, field)
  return self:getFile(file).data[field]
end

function C:afterTrigger()
  for file, _ in pairs(self.changed) do
    local p = savePath .. file .. ext
    self.mgr:logEvent("Saving file " .. file,"I", "File " .. p .. " has been saved.")
    jsonWriteFile(p, self:getFile(file), true)
  end
  table.clear(self.changed)
end

function C:executionStopped()
  self:clear()
end

function C:executionStarted()
  self:clear()
end

return _flowgraph_createModule(C)