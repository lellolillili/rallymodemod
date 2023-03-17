-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this utility loads and resaves all materials

local M = {}

local function getSimObjects(fileName)
  local ret = {}
  local objs = scenetree.getAllObjects()
  --log('E', '', '# objects existing: ' .. tostring(#scenetree.getAllObjects()))
  for _, objName in ipairs(objs) do
    local o = scenetree.findObject(objName)
    if o then
      if o:getFileName() == fileName then
        table.insert(ret, o)
      end
    end
  end
  return ret
  --log('E', '', '# objects left: ' .. tostring(#scenetree.getAllObjects()))
end

local function work(job)
  local persistenceMgr = PersistenceManager()
  persistenceMgr:registerObject('matResave_PersistMan')

  -- for now we only convert materials.cs
  local files = FS:findFiles('/', 'materials.cs\tmanaged*Data.csNOP', -1, true, false)
  for _, fn in ipairs(files) do
    local dir, basefilename, ext = path.splitWithoutExt(fn)
    local objects = {}

    if getFileSize(fn) > 0 then
      TorqueScriptLua.exec(fn)
      objects = getSimObjects(fn)
    end

    if not tableIsEmpty(objects) then
      log('I', '', 'parsing materials file: ' .. tostring(fn))

      for _, obj in ipairs(objects) do
        -- the old material files can also contain other stuff ...
        log('I', '', ' * ' .. tostring(obj:getClassName()) .. ' - ' .. tostring(obj:getName()) )
        persistenceMgr:setDirty(obj, '')
      end
      persistenceMgr:saveDirtyNewFormat()

      for _, obj in ipairs(objects) do
        obj:delete()
      end
      ---persistenceMgr:clearAll()
    end
  end

  persistenceMgr:delete()
  log('I', '', 'DONE')
  --shutdown(0)
end

local function onExtensionLoaded()
  settings.setValue("IngameConsoleLogBlacklist", "DA")
  settings.setValue("WinConsoleLogBlacklist", "DA")
  extensions.core_jobsystem.create(work, 1) -- yield every second, good for background tasks
end

-- interface
M.onExtensionLoaded = onExtensionLoaded
M.work = work

return M
