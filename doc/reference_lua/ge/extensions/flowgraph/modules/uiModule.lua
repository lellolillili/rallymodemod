-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local C = {}
C.moduleOrder = 1000 -- low first, high later
C.idCounter = 0
function C:getFreeId()
  self.idCounter = self.idCounter + 1
  return self.idCounter
end

function C:init()
  self:clear()
end

function C:clear()
  self.nextLayout = nil
  self.resetState = nil
  self.uiLayout = nil
end

function C:setGameState(layout, menu)
  self.nextLayout = { layout = layout, menu = menu }
end

function C:startUIBuilding(uiMode)
  self.uiLayout = { mode = uiMode, layout = { {} } }
  self.pageCounter = 1
  self.isBuilding = true
end

function C:finishUIBuilding()
  if not self.isBuilding then
    return
  end

  self.isBuilding = false

  log("I", "", dumps(self.uiLayout))

  if self.uiLayout.mode == 'startScreen' then
    for _,page in ipairs(self.uiLayout.layout) do
      for _,elem in ipairs(page) do
        -- BUILD UI
      end
    end
  elseif self.uiLayout.mode == 'failureScreen' then
    for _,page in ipairs(self.uiLayout.layout) do
      for _,elem in ipairs(page) do
        -- BUILD UI
      end
    end
  elseif self.uiLayout.mode == 'successScreen' then
    for _,page in ipairs(self.uiLayout.layout) do
      for _,elem in ipairs(page) do
        -- BUILD UI
      end
    end
  end
end

function C:addUIElement(elementType, elementData)
  if self.isBuilding then
    table.insert(self.uiLayout.layout[self.pageCounter], {type = elementType, data = elementData})
  end
end

-- will probably only be used by startPage
function C:nextPage()
  self.pageCounter = self.pageCounter + 1
  table.insert(self.uiLayout.layout,self.pageCounter,{})
end


return _flowgraph_createModule(C)