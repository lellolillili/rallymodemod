-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Location'
C.description = 'Unwraps a location for further inspection.'
C.category = 'repeat_instant'

C.color = ui_flowgraph_editor.nodeColors.sites
C.pinSchema = {
  {dir = 'in', type = 'table', name = 'location', tableType = 'locationData', description = 'Location Data.'},
  {dir = 'out', type = 'string', name = 'name', description = 'Name of the Location'},
  {dir = 'out', type = 'vec3', name = 'pos', description = 'Original Position of the Location'},
  {dir = 'out', type = 'flow', name = 'hasNavPos', description = 'If this location has a position on the navgraph.', hidden=true},
  {dir = 'out', type = 'vec3', name = 'navPos', description = 'Position projected onto the closest road. will be same as pos if no road can be found.'},
  {dir = 'out', type = 'vec3', name = 'roadSide', description = 'Position on the side of the road (2m from the side).'},
  {dir = 'out', type = 'quat', name = 'roadDir', description = 'Direction of the road'},
  {dir = 'out', type = 'number', name = 'navRadius', description = 'Radius of the position projected onto the closest road. will be 5 if no road can be found.'},

}

C.tags = {'scenario'}


function C:init(mgr, ...)
  self.options = {"key"}
end

function C:postInit()
  self:updateKeys()
end

function C:updateKeys()
  local flowLinks = {}
  local strLinks = {}
  for _, lnk in pairs(self.graph.links) do
    if lnk.sourceNode == self and tableContains(self.oldOptions, lnk.sourcePin.name) then
      table.insert(flowLinks, lnk)
    end
  end
  local outPins = {}
  for _, pn in pairs(self.pinOut) do
    if tableContains(self.oldOptions or {}, pn.name) then
      table.insert(outPins, pn)
    end
  end
  for _, pn in pairs(outPins) do
    self:removePin(pn)
  end

  self.oldOptions = {}
  for i, btn in ipairs(self.options) do
    self:createPin("out", {'string','number'}, btn)
    self.oldOptions[i] = btn
  end

  for _, lnk in ipairs(flowLinks) do
    if lnk.sourcePin.name and self.pinOut[lnk.sourcePin.name] then
      self.graph:createLink(self.pinOut[lnk.sourcePin.name], lnk.targetPin)
    end
  end
end

function C:drawCustomProperties()
  if im.Button("Open Sites Editor") then
    if editor_sitesEditor then
      editor_sitesEditor.show()
    end
  end
  if editor_sitesEditor then
    local loc = editor_sitesEditor.getCurrentLocation()
    if loc then
      im.Text("Currently selected Location in editor:")
      im.Text(loc.name)
      if im.Button("Copy over Fields") then
      end
    end
  end
  im.Separator()
  local reason
  local remove = nil
  for i, btn in ipairs(self.options) do
    local txt = im.ArrayChar(64, btn)
    if im.InputText("##btn" .. i, txt, nil, im.InputTextFlags_EnterReturnsTrue) then
      if ffi.string(txt) == '' then
        remove = i
      else
        self.options[i] = ffi.string(txt)
        reason = "renamed button to" .. self.options[i]
      end
    end
  end
  if remove then
    for i = remove, #self.options do
      self.options[i] = self.options[i+1]
    end
    reason = "Removed an option."
  end
  if im.Button("add") then
    table.insert(self.options, "btn_"..(#self.options+1))
    reason = "added Button"
  end
  im.SameLine()
  if im.Button("rem") then
    self.options[#self.options] = nil
    reason = "removed Button"
  end
  if reason then
    self:updateKeys()
  end
end

function C:_executionStarted()
  self._location = nil
end

function C:work(args)
  if self.pinIn.location.value then
    local loc = self.pinIn.location.value
    if loc ~= self._location then
      self._location = loc
      if not self._location.missing then
        self.pinOut.name.value = self._location.name
        self.pinOut.pos.value = self._location.pos:toTable()
        local closest = self._location:findClosestRoadInfo()
        if closest then
          self.pinOut.hasNavPos.value = true
          self.pinOut.navPos.value = closest.pos:toTable()
          self.pinOut.navRadius.value = closest.radius
          self.pinOut.roadSide.value = (closest.pos + (self._location.pos - closest.pos):normalized() * (closest.radius-2)):toTable()
          self.pinOut.roadDir.value = quatFromDir(closest.a.pos - closest.b.pos, vec3(0,0,1)):toTable()
        else
          self.pinOut.hasNavPos.value = false
          self.pinOut.navPos.value = self.pinOut.pos.value
          self.pinOut.navRadius.value = 5
          self.pinOut.roadSide.value = self.pinOut.pos.value
          self.pinOut.roadDir.value = {0,0,0,0}
        end
        for _, o in ipairs(self.options) do
          self.pinOut[o].value = self._location.customFields.values[o]
        end
      end
    end
  end
end

function C:_onSerialize(res)
  res.options = deepcopy(self.options)
end

function C:_onDeserialized(nodeData)
  self.options = nodeData.options or {"key"}
  self:updateKeys()
end



return _flowgraph_createNode(C)
