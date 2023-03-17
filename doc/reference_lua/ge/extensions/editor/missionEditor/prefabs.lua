-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui
local C = {}

function C:init(missionEditor)
  self.missionEditor = missionEditor
  self.prefabsRequireCollisionReload = im.BoolPtr(false)
  self.filenames = {}
end

function C:setMission(mission)
  self.mission = mission
  self.prefabsRequireCollisionReload = im.BoolPtr(mission.prefabsRequireCollisionReload or false)
  table.clear(self.filenames)
  for _, p in ipairs(mission.prefabs or {}) do
    table.insert(self.filenames, im.ArrayChar(2048, p or ""))
  end
end

function C:draw()
  im.Columns(2)
  im.SetColumnWidth(0,150)

  im.Text("Prefabs")
  im.NextColumn()
  local rem = nil
  local editEnded = im.BoolPtr(false)
  for i, prefab in ipairs(self.filenames) do
    local originalPrefabName = self.mission.prefabs[i]
    if editor.uiIconImageButton(editor.icons.delete_forever, im.ImVec2(24, 24), nil, nil, nil,'##rem'..originalPrefabName..i) then
      rem = i
    end
    im.SameLine()
    im.PushItemWidth(200)
    editor.uiInputText("##prefab"..i, prefab, 2048, nil, nil, nil, editEnded)
    if editEnded[0] then
      self.mission.prefabs[i] = ffi.string(prefab)
      self.mission._dirty = true
    end
    im.SameLine()
    if im.Button(" ... ##prefab"..i) then
      extensions.editor_fileDialog.openFile(
        function(data)
          self.mission.prefabs[i] = data.filepath
          self.filenames[i] = im.ArrayChar(1024, data.filepath)
          self.mission._dirty = true
        end, {{"Prefab",".prefab.json"}, {"Prefab",".prefab"}}, false, self.mission.missionFolder)
    end
    im.SameLine()
    local file = self.mission.prefabs[i]
    local foundFile = file ~= "" and FS:fileExists(file)
    if foundFile then
      editor.uiIconImage(editor.icons.check, im.ImVec2(24, 24))
      im.tooltip("Found file at " .. file)
      im.SameLine()
      if im.Button("Spawn##prefab"..i) then
        local dir, filename, ext = path.split(file)
        local p = spawnPrefab(Sim.getUniqueName(self.mission.id.."-"..filename),file,"0 0 0","0 0 0 1","1 1 1")
        if p then
          p.loadMode = 0
          scenetree.MissionGroup:addObject(p.obj)
          editor.selectObjectById(p.obj:getId())
        end
      end
    else
      editor.uiIconImage(editor.icons.error_outline, im.ImVec2(24, 24))
      im.tooltip("No file at " .. file)
    end
  end
  if rem then
    table.remove(self.filenames, rem)
    table.remove(self.mission.prefabs, rem)
    self.mission._dirty = true
  end
  if im.Button("Add##prefabs") then
    table.insert(self.filenames, im.ArrayChar(2048, "/"))
    table.insert(self.mission.prefabs,"/")
    self.mission._dirty = true
  end
  if #self.filenames > 0 then
    if im.Checkbox("Requires collision reload", self.prefabsRequireCollisionReload) then
      self.mission.prefabsRequireCollisionReload = self.prefabsRequireCollisionReload[0]
      self.mission._dirty = true
    end
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
