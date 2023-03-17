-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Parking Spot'
C.description = 'Unwraps a Parking Spot for further inspection.'
C.category = 'repeat_instant'

C.color = ui_flowgraph_editor.nodeColors.sites
C.pinSchema = {
  {dir = 'in', type = 'table', name = 'spot', tableType = 'parkingSpotData', description = 'Parking spot Data.'},
  {dir = 'out', type = 'string', name = 'name', description = 'Name of the parking spot'},
  {dir = 'out', type = 'vec3', name = 'pos', description = 'Position of the parking spot'},
  {dir = 'out', type = 'quat', name = 'rot', description = 'Rotation of the parking spot'},
  {dir = 'out', type = 'vec3', name = 'scl', description = 'Scale of the parking spot'},
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
  self._spot = nil
end

function C:work(args)
  if self.pinIn.spot.value then
    local loc = self.pinIn.spot.value
    if loc ~= self._spot then
      self._spot = loc
    end
  end
  if self._spot and not self._spot.missing then
    self.pinOut.name.value = self._spot.name
    self.pinOut.pos.value = self._spot.pos:toTable()
    self.pinOut.rot.value = self._spot.rot:toTable()
    self.pinOut.scl.value = self._spot.scl:toTable()
    self.pinOut.scl.value[3] = 10
    for _, o in ipairs(self.options) do
      self.pinOut[o].value = self._spot.customFields.values[o]
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
