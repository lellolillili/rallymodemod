-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui
local nameText = im.ArrayChar(1024, "")
local descText = im.ArrayChar(2048, "")
local C = {}
C.windowDescription = 'Tags'


function C:init(sitesEditor, key)
  self.sitesEditor = sitesEditor
  self.key = key
end

function C:setSites(sites)
  self.sites = sites

end
function C:selected()
  --self.sites:finalizeSites()
  self.tag = nil
  self.sortedTags = {}
  self.tags = {}
  for _, elem in ipairs(self.sites[self.key].sorted) do
    for _, t in ipairs(elem.customFields.sortedTags) do
      self.tags[t] = 1
    end
  end
  for k, _ in pairs(self.tags) do
    table.insert(self.sortedTags, k)
  end
  table.sort(self.sortedTags)
end
function C:unselect() end

function C:draw()
  self:drawGeneralInfo()
end

function C:selectTag(tag)
  self.tag = tag
  self.hasTag = {}
  self.noTag = {}
  for _, elem in ipairs(self.sites[self.key].sorted) do
    if elem.customFields.tags[tag] then
      table.insert(self.hasTag, elem)
    else
      table.insert(self.noTag, elem)
    end
  end

end


function C:drawGeneralInfo()
  im.BeginChild1("Tags", im.ImVec2(125 * im.uiscale[0], 0 ), im.WindowFlags_ChildWindow)
  for i, tag in ipairs(self.sortedTags) do
    if im.Selectable1(tag..'##'..i, self.tag == tag) then
      self:selectTag(tag)
    end
  end
  im.EndChild()

  im.SameLine()
  im.BeginChild1("currentElement", im.ImVec2(0, 0 ), im.WindowFlags_ChildWindow)

  if self.tag then
    im.Text(self.tag)
    local width = im.GetContentRegionAvail().x/2 - 20
    im.Columns(3,'tags',false)
    im.SetColumnWidth(0,width)
    im.SetColumnWidth(1,30)
    im.SetColumnWidth(2,width)
    im.Text("Has Tag:")
    im.NextColumn()
    im.NextColumn()
    im.Text("Doesn't have:")
    im.NextColumn()
    im.BeginChild1("hasTags", nil, im.WindowFlags_ChildWindow)
    local flip = nil
    for i, elem in ipairs(self.hasTag) do
      if im.Selectable1(elem.name..'##'..i) then
        flip = {elem = elem, dir = 'rem', i = i}
      end
      if im.IsItemHovered() then
        elem:drawDebug('highlight',{0,1,0,1})
      end
    end
    im.EndChild()
    im.NextColumn()
    if im.Button(">") then
      for _,elem in ipairs(self.hasTag) do
        table.insert(self.noTag, elem)
        elem.customFields:removeTag(self.tag)
      end
      table.clear(self.hasTag)
    end
    if im.Button("<") then
      for _,elem in ipairs(self.noTag) do
        table.insert(self.hasTag, elem)
        elem.customFields:addTag(self.tag)
      end
      table.clear(self.noTag)
    end
    im.NextColumn()
    im.BeginChild1("NoTags", nil, im.WindowFlags_ChildWindow)
    for i, elem in ipairs(self.noTag) do
      if im.Selectable1(elem.name..'##'..i) then
        flip = {elem = elem, dir = 'add', i = i}
      end
      if im.IsItemHovered() then
        elem:drawDebug('highlight',{1,0,0,1})
      end
    end
    im.EndChild()
    if flip then
      if flip.dir == 'add' then
        table.remove(self.noTag, flip.i)
        table.insert(self.hasTag, flip.elem)
        flip.elem.customFields:addTag(self.tag)
      else
        table.remove(self.hasTag, flip.i)
        table.insert(self.noTag, flip.elem)
        flip.elem.customFields:removeTag(self.tag)
      end
    end
  end
  im.EndChild()
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
