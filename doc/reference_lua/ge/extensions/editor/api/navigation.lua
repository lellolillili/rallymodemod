-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local editor

local function createNavMesh(navMeshInfo)
  --TODO
end

local function deleteNavMesh(navMeshObjectId)
  --TODO
end

local function createOffMeshLink(navMeshObjectId, linkInfo)
  --TODO
end

local function deleteOffMeshLink(linkId)
  --TODO
end

local function createCover(coverInfo)
  --TODO
end

local function deleteCover(coverObjectId)
  --TODO
end

local function getNavMeshes()
  --TODO
end

local function getCovers(navMeshObjectId)
  --TODO
end

local function getOffMeshLinks()
  --TODO
end

local function initialize(editorInstance)
  editor = editorInstance
  editor.createNavMesh = createNavMesh
  editor.deleteNavMesh = deleteNavMesh
  editor.createOffMeshLink = createOffMeshLink
  editor.deleteOffMeshLink = deleteOffMeshLink
  editor.createCover = createCover
  editor.deleteCover = deleteCover
  editor.getNavMeshes = getNavMeshes
  editor.getCovers = getCovers
  editor.getOffMeshLinks = getOffMeshLinks
end

local M = {}
M.initialize = initialize

return M