-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui
local imguiUtils = require('ui/imguiUtils')
local C = {}

function C:init(missionEditor)
  self.missionEditor = missionEditor
end

function C:setMission(mission)
  self.mission = mission
  self.previewFound = false
  self.previewFile = nil
  self:checkPreview()
end

function C:checkPreview()
  self.previewFile = self.mission.previewFile or gameplay_missions_missions.getMissionPreviewFilepath(self.mission)
  self.previewFound = self.previewFile ~= gameplay_missions_missions.getNoPreviewFilepath()
  self.previewImage = imguiUtils.texObj(self.previewFile)

  self.thumbFile = self.mission.thumbnailFile or gameplay_missions_missions.getThumbnailFilepath(self.mission)
  self.thumbFound = self.thumbFile ~= gameplay_missions_missions.getNoThumbFilepath() and self.thumbFile ~= self.previewFile
  self.thumbImage = imguiUtils.texObj(self.thumbFile)

end

function C:getMissionIssues(m)
  self:setMission(m)
  local issues = {}
  if not self.previewFound then
    table.insert(issues, {type = 'Missing Preview File!'})
  else
    if self.previewImage.size.x ~= 1920 or self.previewImage.size.y == 1080 then
      table.insert(issues, {type = string.format('Preview file dimensions off! %d x %d instead of 1920 x 1080!', self.previewImage.size.x, self.previewImage.size.y)})
    end
  end
  if not self.thumbFound and not self.previewFound then
    table.insert(issues, {type = 'Missing Thumbnail File!'})
  else
    if self.thumbImage.size.x < 200 or self.thumbImage.size.x > 800 or self.thumbImage.size.x ~= self.thumbImage.size.y then
      table.insert(issues, {type = string.format('Thumbnail file dimensions off! %d x %d instead of 200 < X < 800 square!', self.thumbImage.size.x, self.thumbImage.size.y)})
    end
  end
  return issues
end
local imVec24x24 = im.ImVec2(24,24)
local imVec4Red = im.ImVec4(1,0,0,1)
local imVec4Green = im.ImVec4(0,1,0,1)
local imVec4Yellow = im.ImVec4(1,1,0,1)
function C:draw()
  im.Columns(2)
  im.SetColumnWidth(0,150)

  im.Text("Preview")
  im.NextColumn()

  if im.Button("...") then
    Engine.Platform.exploreFolder(self.mission.missionFolder)
  end
  if self.previewFound then
    editor.uiIconImage(editor.icons.check, imVec24x24, imVec4Green)
    im.tooltip(self.previewFile)
    im.SameLine()
    if self.previewImage.size.x == 1920 and self.previewImage.size.y == 1080 then
      editor.uiIconImage(editor.icons.check, imVec24x24, imVec4Green)
    else
      editor.uiIconImage(editor.icons.warning, imVec24x24, imVec4Yellow)
    end
    im.tooltip("Correct Size for preview image should be 1920 x 1080 px, is " .. self.previewImage.size.x .." x " .. self.previewImage.size.y .." px.")
  else
    editor.uiIconImage(editor.icons.error_outline, imVec24x24, imVec4Red)
    im.tooltip("Requires a .png, .jpg or .jpeg file named 'preview' in the mission folder")
  end

  im.SameLine()

  im.Button("Preview")
  if im.IsItemHovered() then
    im.BeginTooltip()
    im.Image(self.previewImage.texId, self.previewImage.size, im.ImVec2(0, 0), im.ImVec2(1, 1))
    im.EndTooltip()
  end
  im.SameLine()
  im.Text("Required: preview.png, preview.jpg or preview.jpeg")

  if self.thumbFound then
    editor.uiIconImage(editor.icons.check, imVec24x24, imVec4Green)
    im.tooltip(self.thumbFile)
    im.SameLine()
    if self.thumbImage.size.y == 200 and self.thumbImage.size.y == 200 then
      editor.uiIconImage(editor.icons.check, imVec24x24, imVec4Green)
    else
      editor.uiIconImage(editor.icons.warning, imVec24x24, imVec4Yellow)
    end
    im.tooltip("Correct Size for thumbnail image should be 200 x 200 px, is " .. self.thumbImage.size.x .." x " .. self.thumbImage.size.y .." px.")
  else
    editor.uiIconImage(editor.icons.error_outline, imVec24x24, imVec4Red)
    im.tooltip("Requires a .png, .jpg or .jpeg file named 'thumbnail' in the mission folder. Will use Preview otherwise.")
  end
  im.SameLine()
  im.Button("Thumbnail")
  if im.IsItemHovered() then
    im.BeginTooltip()
    im.Image(self.thumbImage.texId, self.thumbImage.size, im.ImVec2(0, 0), im.ImVec2(1, 1))
    im.EndTooltip()
  end
  im.SameLine()
  im.Text("Required: thumbnail.png, thumbnail.jpg or thumbnail.jpeg, otherwise using Preview.")
  local alwaysShowScreenshots = editor.getPreference("missionEditor.general.alwaysShowScreenshots") or false
  if im.Checkbox('Always show Preview', im.BoolPtr(alwaysShowScreenshots)) then
    alwaysShowScreenshots = not alwaysShowScreenshots
    editor.setPreference("missionEditor.general.alwaysShowScreenshots", alwaysShowScreenshots)
  end
  if alwaysShowScreenshots then
    local size = vec3(self.previewImage.size.x, self.previewImage.size.y, 0)
    if size.x > im.GetContentRegionAvailWidth() then
      size = size * im.GetContentRegionAvailWidth() / size.x
    end
    im.Image(self.previewImage.texId, im.ImVec2(size.x, size.y), im.ImVec2(0, 0), im.ImVec2(1, 1))
     size = vec3(self.thumbImage.size.x, self.thumbImage.size.y, 0)
    if size.x > im.GetContentRegionAvailWidth() then
      size = size * im.GetContentRegionAvailWidth() / size.x
    end
    im.Image(self.thumbImage.texId, im.ImVec2(size.x, size.y), im.ImVec2(0, 0), im.ImVec2(1, 1))
  end

  im.Columns(1)
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
