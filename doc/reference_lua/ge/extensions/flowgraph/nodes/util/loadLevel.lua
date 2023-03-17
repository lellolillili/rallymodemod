-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor

local C = {}
local logTag = 'LoadLevel'
C.name = 'Load Level'
C.icon = "public"
C.description = "Loads a level. path is relative to levels/. Automatically adds the /info.json file ending."
C.color = im.ImVec4(0.03, 0.3, 0.84, 0.75)
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
  { dir = 'in', type = 'string', name = 'levelPath', description = 'Defines the path to load the level from.' },
}

C.tags = {'gameplay', 'utils'}

function C:init()
  self.state = 1
  self.pinOut.flow.value = false
  self.data.preventPlayerSpawning = true
  self.data.forceLevelLoad = true
  self.data.delayBufferFrames = 0
  self.data.stopRunningOnClientEndMission = false
  self.data.noLoadInEdit = true
  self.data.customLoadingScreen = false
end

function C:_executionStarted()
  self.state = 1
  self.pinOut.flow.value = false
  self.mgr.__delayedLoadingScreenFunctions =  nil
end

function C:postInit()
  local levels = getAllLevelIdentifiers()
  table.sort(levels)
  local ht = {}
  for _, lvl in ipairs(levels) do
    table.insert(ht, {value = lvl, name = "displayed name"})
  end

  self.pinInLocal.levelPath.hardTemplates = ht
end

function C:onLoadingScreenFadeout(missionFile)
  if self.state == 4 then return end
  self.state = 3
  self.bufferDelay = self.data.delayBufferFrames
end

function C:work()
  if self.state ~= 4 then
    --log("I","","Working " .. self.state .. " " .. dumps(self.primed))
    self.primed = nil
    local levelPath = ("/levels/"..self.pinIn.levelPath.value.."/"):lower()
    local loadedMissionFile = getMissionFilename()
    local dirM  = path.split(loadedMissionFile)
    --log('I', logTag, "missionDir: "..tostring(dirM))

    -- scenarioData.mission = 'levels/'..scenarioData.levelName..'/main.level.json'
    if self.state == 1 then
      if (dirM == levelPath) and
              (not self.data.forceLevelLoad or (editor and editor.active and self.data.noLoadInEdit)) then
        self.state = 4
        self.pinOut.flow.value = true
      else
        if self.pinIn.levelPath.value  then
          -- yes, change level, but disable the player autospawning
          log('D', logTag, 'Loading level from Flowgraph: ' .. tostring(levelPath))
          spawn.preventPlayerSpawning = self.data.preventPlayerSpawning
          self._storedStop = self.mgr.stopRunningOnClientEndMission
          if self.data.stopRunningOnClientEndMission then
            self.mgr.stopRunningOnClientEndMission = self.stopRunningOnClientEndMission
          end
          local editorWasActive = editor.active
          if editor and editor.shutdown then editor.shutdown() end
          if self.data.customLoadingScreen then
            self.mgr.modules.level:beginLoadingLevel()
            core_levels.startLevel(levelPath, false, function()
              log('D', logTag, 'Delayed loading screen fadeout. Make sure to use the "Hide Loading Screen" node to hide it manually.')
              self.state = 3
              self.bufferDelay = self.data.delayBufferFrames
            end)
          else
            core_levels.startLevel(levelPath, false)
            self.mgr:logEvent("Load Level: " .. levelPath,"", "", {type = "node", node = self})
          end
          if editor and editorWasActive then editor.setEditorActive(true) end
        end
        self.state = 2
      end
    elseif self.state == 3 then

      if self.bufferDelay <= 0 then
        extensions.hook('onClientPostStartMission', levelPath)
        extensions.hookNotify('onClientStartMission', levelPath)
        map.assureLoad() -- ensure that map data is up to date if loading flowgraphs between different maps
        --map.load()
        self.mgr.stopRunningOnClientEndMission = self._storedStop
        self.pinOut.flow.value = true
        if self.data.preventPlayerSpawning then
          spawn.preventPlayerSpawning = nil
        end
        self.state = 4
      else
        self.bufferDelay = self.bufferDelay -1
      end
    end
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text(self.state .. " " )
end

return _flowgraph_createNode(C)
