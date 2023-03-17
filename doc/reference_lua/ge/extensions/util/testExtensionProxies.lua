-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local ExtensionProxyTester = {}
ExtensionProxyTester.__index = ExtensionProxyTester

local function newExtensionProxyTester()
  local res = {}
  setmetatable(res, ExtensionProxyTester)
  return res
end

function ExtensionProxyTester:onUpdate(dtReal, dtSim, dtRaw)
  print('ExtensionProxyTester:onUpdate called: ' .. tostring(self.id) .. ', ' .. tostring(dtReal))
end

local extProxy

local function onExtensionUnloaded()
  log('I', '', "module unloaded")
  extProxy:destroy() -- ideally, you call this manually, but the extension system also cleans up after you
end

local function onExtensionLoaded()
  log('I', '', "module loaded")
  local testInstances = {}
  for i = 0, 10 do
    local e = newExtensionProxyTester(id)
    e.id = i
    table.insert(testInstances, e)
  end
  --print(' == testInstances ==')
  --dump(testInstances)

  extProxy = newExtensionProxy(M) -- newExtensionProxy(nil, 'foobar')
  extProxy:submitEventSinks(testInstances)

  --extProxy.hookProxies.onUpdate(123)
end

M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded

return M