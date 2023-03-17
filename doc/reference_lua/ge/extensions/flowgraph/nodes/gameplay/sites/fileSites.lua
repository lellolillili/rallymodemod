-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'File Sites'
C.description = 'Loads a Sites file.'
C.category = 'once_p_duration'
C.color = ui_flowgraph_editor.nodeColors.sites

C.pinSchema = {
  {dir = 'in', type = 'string', name = 'file', description = 'File of the sites'},
  {dir = 'out', type = 'table', name = 'sitesData', tableType = "sitesData", description = 'Data from the sites for other nodes to process.', matchName = true}
}

C.tags = {'scenario'}
C.dependencies = {'gameplay_sites_sitesManager'}

function C:init(mgr, ...)
  self.sites = nil
  self.clearOutPinsOnStart = false
end

function C:postInit()
  self.pinInLocal.file.allowFiles = {
    {"Sites Files",".sites.json"},
  }
end

function C:drawCustomProperties()
  if im.Button("Open Sites Editor") then
    if editor_sitesEditor then
      editor_sitesEditor.show()
    end
  end
  if editor_sitesEditor then
    local cSites = editor_sitesEditor.getCurrentSites()
    if cSites.dir then
      im.Text("Currently open file in editor:")
      im.Text(cSites.dir .. cSites.name)
      if im.Button("Hardcode to File Pin") then
        self:_setHardcodedDummyInputPin(self.pinInLocal.file, cSites.dir..cSites.name)
      end
    end
  end
end

function C:onNodeReset()
  self.sites = nil
end

function C:_executionStopped()
  self.sites = nil
end

function C:work(args)
  if self.sites == nil then
    local file, valid = self.mgr:getRelativeAbsolutePath({self.pinIn.file.value, self.pinIn.file.value..'.sites.json'})
    if not valid then
      self:__setNodeError('file', 'unable to find sites file: '..file)
      return
    end

    local sites = gameplay_sites_sitesManager.loadSites(file, true, true)
    sites:finalizeSites()
    self.sites = sites
    self.pinOut.sitesData.value = sites
  end
end

return _flowgraph_createNode(C)
