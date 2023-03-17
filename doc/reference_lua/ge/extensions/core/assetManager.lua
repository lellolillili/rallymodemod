-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local sql = require "ljsqlite3"

local dbFilename = '/temp/assets.db'

local conn

-- DB statements
local insertStmt
local updateStmt
local deleteStmt
local findhashStmt
local insertAliasStmt
local findFileStmt
local findAliasStmt

local findFilesByPathStmt
local findFilesByBasenameStmt
local findFilesByPathAndBasenameStmt

local findAliasesByPathStmt
local findAliasesByBasenameStmt
local findAliasesByPathAndBasenameStmt

-- jobs
local generateJob
local refreshJob

-- migration = versioning of databases: how to get from version X to version Y: apply all the steps in the middle
local function migrateDatabaseInternal()
  -- we use the 'PRAGMA user_version' to version our database
  local dbVersion = tonumber(conn:rowexec('PRAGMA user_version'))
  if dbVersion == 0 then
    -- initial schema needs to be created
    log('I', 'DB_Migration', 'Migrating DB from version 0 to 1')
    conn:exec[[
      CREATE TABLE files(
        files_sourcefilename text,
        files_basename text,
        files_extension text,
        files_directory text,
        files_filesize INTEGER,
        files_hash text,
        files_modtime INTEGER,
        files_createtime INTEGER
      );
      CREATE TABLE aliases(
        file_id integer,
        aliases_alias text,
        aliases_basename text,
        aliases_extension text,
        aliases_directory text
      );
      CREATE INDEX files_hash_index ON files (files_hash);
      PRAGMA user_version = 1;
      ]]
    return 1

  elseif dbVersion == 1 then
    log('I', 'DB_Migration', 'Migrating DB from version 1 to 2')
    -- sqlite version of migration: rename DB, create new schema, then copy the data and drop the old data
    --conn:exec[[
    --  ALTER TABLE files RENAME TO tmp;
    --  CREATE TABLE files(id BLOB, num REAL);
    --  INSERT INTO tmp(id, num) SELECT id, num FROM tmp;
    --  DROP TABLE tmp;
    --  PRAGMA user_version = 2;
    --  ]]
    conn:exec[[
      PRAGMA user_version = 2;
      ]]
    return 1

  elseif dbVersion == 2 then
    -- all ok, this is the current version
    return 0
  end
  log('E', 'DB_Migration', 'unsupported database version: ' .. tostring(dbVersion) .. '. Consider deleting the file to force recreation: ' .. dbFilename)
  return -1
end

local function migrateDatabase()
  -- this prevents an endless loop trying to upgrade the DB ...
  local res
  for i = 0, 20 do
    -- 1 = continue, 0 = end, -1 = fatal error
    res = migrateDatabaseInternal()
    if res <= 0 then break end
  end
  return res
end

local function _findRelevantFiles()
  return FS:findFiles('/', '*.dds\t*.dae\t*.png\t*.jpg\t*.mkv\t*.flac\t*.ogg\t*.tga\t*.wav\t*.bmp\t*.dts\t*.ter', -1, true, false)
end

local function _generate(job)
  log('I', '', "generating DB ...")
  job.progress = 0
  local timer = hptimer()
  local foundFiles = _findRelevantFiles()
  --dump(foundFiles)
  conn 'BEGIN TRANSACTION;'
  local foundFilesSize = #foundFiles
  local sourcefilename
  local hash

  local fileCount = 0
  local fileSizeSum = 0
  local dupeSize = 0
  local dupeCount = 0
  for i = 1, foundFilesSize do
    sourcefilename = string.lower(foundFiles[i])
    if not string.startswith(sourcefilename, '/cache.') and not string.startswith(sourcefilename, '/mods/unpacked/')  then
      --print(string.format('%0.2f %%', (i / foundFilesSize) * 100))
      local t = FS:stat(sourcefilename)
      if t.filetype == 'file' then
        hash = FS:hashFileSHA1(sourcefilename)
        if hash == "" then log("E", "gen", "Failed hash: " .. dumps(sourcefilename)) end
        local extension = string.lower(string.match(sourcefilename, "[^.]*$"))
        local filenameWExt = string.lower(string.match(sourcefilename, "[^/]*$"))
        local filename = string.sub(filenameWExt, 1, #filenameWExt - (#extension+1))
        local path = string.sub(sourcefilename, 1, #sourcefilename - #filenameWExt)

        -- try to find if the hash is in use
        local foundFile = findhashStmt:reset():bind(hash):step()
        if not foundFile then
          insertStmt:reset():bind(sourcefilename, filename, extension, path, t.filesize, hash, t.modtime, t.createtime):step()
          --print(' * ' .. sourcefilename .. ' = ' .. dumps(t))
          fileCount = fileCount + 1
          fileSizeSum = fileSizeSum + t.filesize
        else
          local fileId = foundFile[1]
          insertAliasStmt:reset():bind(fileId, sourcefilename, filename, extension, path):step()
          dupeCount = dupeCount + 1
          dupeSize = dupeSize + t.filesize
          --print('   > Alias ' .. sourcefilename .. ' = ' .. dumps(t))
        end
      end
    end
    job.yield()
    job.progress = (i / foundFilesSize)
  end
  conn 'COMMIT;'
  local timetaken = timer:stop() / 1000
  log('I', '', 'generate done in ' .. string.format('%0.1f', timetaken) .. ' seconds. Performance: ' .. bytes_to_string((fileSizeSum+dupeSize) / timetaken) .. '/s')
  log('I', '', 'Processed ' .. tostring(fileCount) .. ' files: ' .. tostring(bytes_to_string(fileSizeSum)))
  log('I', '', tostring(dupeCount) .. ' duplicates: ' .. tostring(bytes_to_string(dupeSize)))
  job.progress = 1
end

local function generate()
  generateJob = extensions.core_jobsystem.create(_generate, 0.05)
end

local function _refresh(job)
  log('I', '', "refreshing DB ...")
  job.progress = 0
  local timer = hptimer()

  -- find deleted or modified files first
  local res = conn:exec("SELECT * FROM files") -- Records are by column.
  conn 'BEGIN TRANSACTION;'

  local resSize = #res.files_sourcefilename
  local filemap = {}
  local sourcefilename
  local fileSizeSum = 0
  local fileCount = 0

  for i = 1, resSize do
    sourcefilename = res.files_sourcefilename[i]
    fileSizeSum = fileSizeSum + tonumber(res.files_filesize[i])
    fileCount = fileCount + 1
    filemap[sourcefilename] = true
    --print(' * ' .. tostring(sourcefilename))
    if not FS:fileExists(sourcefilename) then
      log('I', '', 'file gone: ' .. tostring(sourcefilename))

      deleteStmt:reset():bind(sourcefilename):step()
    else
      local t = FS:stat(sourcefilename)
      if t.filesize ~= res.files_filesize[i] or t.modtime ~= res.files_modtime[i] or t.createtime ~= res.files_createtime[i] then
        local t = FS:stat(sourcefilename)
        if t.filetype == 'file' then
          log('I', '', 'file changed: ' .. tostring(sourcefilename))
          local hash = FS:hashFileSHA1(sourcefilename)
          updateStmt:reset():bind(t.filesize, hash, t.modtime, t.createtime, sourcefilename):step()
        end
      end
    end
    job.yield()
    job.progress = (i / resSize) * 0.95
  end

  -- find new files:
  local foundFiles = _findRelevantFiles()
  local foundFilesSize = #foundFiles
  for i = 1, foundFilesSize do
    sourcefilename = string.lower(foundFiles[i])
    if not string.startswith(sourcefilename, '/cache.') and not string.startswith(sourcefilename, '/mods/unpacked/') then
      if not filemap[sourcefilename] then
        local t = FS:stat(sourcefilename)
        fileSizeSum = fileSizeSum + tonumber(t.filesize)
        fileCount = fileCount + 1
        if t.filetype == 'file' then
          log('I', '', 'new file: ' .. sourcefilename)
          local hash = FS:hashFileSHA1(sourcefilename)
          if hash == "" then log("E","refresh", "Failed hash "..dumps(sourcefilename)) end
          insertStmt:reset():bind(sourcefilename, 'filename' , '222', 'path', t.filesize, hash, t.modtime, t.createtime):step()
        end
      end
    end
    job.yield()
    job.progress = 0.95 + (i / foundFilesSize) * 0.05
  end

  conn 'COMMIT;'
  local timetaken = timer:stop() / 1000
  log('I', '', 'refresh done in ' .. string.format('%0.1f', timetaken) .. ' seconds. ' .. tostring(fileCount) .. ' files. Theoretical performance: ' .. bytes_to_string(fileSizeSum / timetaken) .. '/s')
  job.progress = 1
end

local function refresh()
  refreshJob = extensions.core_jobsystem.create(_refresh, 0.05)
end

local function onExtensionLoaded()
  conn = sql.open(dbFilename)

  -- upgrade database potentially
  if migrateDatabase() ~= 0 then return false end

  insertStmt = conn:prepare("INSERT INTO files (files_sourcefilename, files_basename, files_extension, files_directory, files_filesize, files_hash, files_modtime, files_createtime) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
  updateStmt = conn:prepare("UPDATE files SET files_filesize=?, files_hash=?, files_modtime=?, files_createtime=? where files_sourcefilename=?")
  deleteStmt = conn:prepare("delete from files where files_sourcefilename = ?")
  findhashStmt = conn:prepare("select rowid, * from files where files_hash = ?")
  insertAliasStmt = conn:prepare("INSERT INTO aliases (file_id, aliases_alias, aliases_basename, aliases_extension, aliases_directory) VALUES (?, ?, ?, ?, ?)")

  findFileStmt = conn:prepare("select rowid, * from files where files_sourcefilename = ?")
  findAliasStmt = conn:prepare("select files.*, aliases.aliases_alias as alias from files left join aliases on files.rowid = aliases.file_id where alias = ?")

  findFilesByPathStmt = conn:prepare("SELECT rowid, * FROM files WHERE files.files_directory = ?")
  findFilesByBasenameStmt = conn:prepare("SELECT rowid, * FROM files WHERE files.files_basename LIKE ?")
  findFilesByPathAndBasenameStmt = conn:prepare("SELECT rowid, * FROM files WHERE files.files_directory = ? AND files.files_basename LIKE ?")

  findAliasesByPathStmt = conn:prepare("SELECT * FROM aliases LEFT JOIN files ON aliases.file_id = files.rowid WHERE aliases.aliases_directory = ?")
  findAliasesByBasenameStmt = conn:prepare("SELECT * FROM aliases LEFT JOIN files ON aliases.file_id = files.rowid WHERE aliases.aliases_basename LIKE ?")
  findAliasesByPathAndBasenameStmt = conn:prepare("SELECT * FROM aliases LEFT JOIN files ON aliases.file_id = files.rowid WHERE aliases.aliases_directory = ? AND aliases.aliases_basename LIKE ?")

  local numRows = conn:rowexec("SELECT count(files_sourcefilename) FROM files")
  if numRows == 0 then
    generate()
  else
    refresh()
  end
end

local function onExtensionUnloaded()
  if conn then
    conn:close()
    conn = nil
  end
end

local function onFileChanged(fn, type)
  if string.startswith(fn, '/temp/') or string.startswith(fn, '/settings/') or string.startswith(fn, 'settings/') or string.startswith(fn, '/mods/unpacked/') then return end

  -- figure out if this file type is interesting to us...
  local _, _, ext = path.splitWithoutExt(fn)
  ext = string.lower(ext)
  if ext ~= 'dds' and ext ~= 'dae' and ext ~= 'png' and ext ~= 'jpg' and ext ~= 'mkv' and ext ~= 'flac'
   and ext ~= 'ogg' and ext ~= 'tga' and ext ~= 'wav' and ext ~= 'bmp' and ext ~= 'dts' and ext ~= 'ter' then return end

  log('I', '', 'sourcefilename = ' .. tostring(fn) .. ' / ' .. tostring(type))

  if type == 'deleted' then
    --print('file deleted: ' .. tostring(fn))
    deleteStmt:reset():bind(fn):step()

  elseif type == 'modified' then
    local t = FS:stat(fn)
    if t.filetype == 'file' then
      --print('file changed: ' .. tostring(fn))
      local hash = FS:hashFileSHA1(fn)
      if hash == "" then log("E","fChanged", "Failed hash "..dumps(fn)) end
      local resCount = tonumber(conn:rowexec("SELECT count(files_sourcefilename) FROM files WHERE sourcefilename == '" .. tostring(fn) .. "'"))
      if resCount == 0 then
        insertStmt:reset():bind(fn, '333', t.filesize, hash, t.modtime, t.createtime):step()
      else
        updateStmt:reset():bind(t.filesize, hash, t.modtime, t.createtime, fn):step()
      end
    end
  end
end

local function isReady()
  local busy = true
  if refreshJob then busy = busy and refreshJob.running end
  if generateJob then busy = busy and generateJob.running end
  return not busy
end

local function getProgress()
  if refreshJob and refreshJob.running then
    return { job = 'refresh', progress = refreshJob.progress}
  end
  if generateJob and generateJob.running then
    return { job = 'generate', progress = generateJob.progress}
  end
  return { job = 'idle' }
end

-- todo: add some metadata to result
local function getFiles(path, name)
  local bndFiles
  local bndAlias
  if (path and not name) then
    bndFiles = findFilesByPathStmt:reset():bind(path)
    bndAlias = findAliasesByPathStmt:reset():bind(path)
  elseif (not path and name) then
    bndFiles = findFilesByBasenameStmt:reset():bind('%'..name..'%')
    bndAlias = findAliasesByBasenameStmt:reset():bind('%'..name..'%')
  elseif (path and name) then
    bndFiles = findFilesByPathAndBasenameStmt:reset():bind(path, '%'..name..'%')
    bndAlias = findAliasesByPathAndBasenameStmt:reset():bind(path, '%'..name..'%')
  else
    log('W', '', "Neither 'path' nor 'name' has been defined.")
    return
  end

  local res = {}
  local step = bndFiles:step()
  while step ~= nil do
    table.insert( res, {
      id = tonumber(step[1]),
      files_sourcefilename = step[2],
      files_basename = step[3],
      files_extension = step[4],
      files_directory = step[5],
      files_filesize = tonumber(step[6]),
      files_hash = step[7],
      files_modtime = tonumber(step[8]),
      files_createtime = tonumber(step[9])
    })
    step = bndFiles:step()
  end

  step = bndAlias:step()
  while step ~= nil do
    table.insert( res, {
      file_id = tonumber(step[1]),
      aliases_alias = step[2],
      aliases_basename = step[3],
      aliases_extension = step[4],
      aliases_directory = step[5],
      files_sourcefilename = step[6],
      files_basename = step[7],
      files_extension = step[8],
      files_directory = step[9],
      files_filesize = tonumber(step[10]),
      files_hash = step[11],
      files_modtime = tonumber(step[12]),
      files_createtime = tonumber(step[13])
    })
    step = bndAlias:step()
  end
  return res
end

local function getTableInfo(tbl)
  local res = conn:exec("PRAGMA table_info(" .. tbl .. ");")
  return res
end

local function resolve(inFilename)
  -- if file exists, always use it
  if FS:fileExists(inFilename) then return inFilename end

  local inBaseFN, inHash = string.match('^([^#]*)#?(.*)$')
  if inHash ~= '' then
    -- prioritize the hash
    local foundFile = findhashStmt:reset():bind(inHash):step()
    if foundFile then
      local outFilename = foundFile[1]
      if FS:fileExists(outFilename) then
        if outFilename ~= inFilename then
          log('W', '', 'File moved: ' .. tostring(inFilename) .. ' > ' .. tostring(outFilename))
        end
        return outFilename
      end
    else
      log('E', '', 'File with hash not found: ' .. tostring(inFilename))
    end
  end

  -- now look via filename
  local foundFile = findFileStmt:reset():bind(inBaseFN):step()
  if foundFile then
    return foundFile[1]
  end

  -- try the aliases
  foundFile = findAliasStmt:reset():bind(inBaseFN):step()
  if foundFile then
    local outFilename = foundFile[1]
    if outFilename ~= inBaseFN then
      log('W', '', 'File moved: ' .. tostring(inFilename) .. ' > ' .. tostring(outFilename))
    end
    return outFilename
  end

  -- fallback: return the input
  return inFilename
end

-- callbacks for it to work
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onFileChanged = onFileChanged

-- functions for the UI
M.isReady = isReady -- returns true when all jobs are done
M.getProgress = getProgress -- returns a table with the work item and progress info
M.getFiles = getFiles
M.getTableInfo = getTableInfo

-- API functions
M.resolve = resolve

return M



