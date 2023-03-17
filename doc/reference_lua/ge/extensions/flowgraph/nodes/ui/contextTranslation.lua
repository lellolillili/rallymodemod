-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Context Translation'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.description = "Creates a context-sensitive translation object."
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'string', name = 'translationString', description = 'Translation String.', fixed = true},
  { dir = 'out', type = 'table', name = 'value', tableType = 'translationObject', description = 'Translation Object.' },
}

C.tags = {}
C.allowedManualPinTypes = {
  flow = false,
  string = true,
  number = true,
  bool = true,
  any = true,
  table = true,
  vec3 = true,
  quat = true,
  color = true,
}

function C:init()
  self.savePins = true
  self.allowCustomInPins = true
end

function C:work()
  self.pinOut.value.value = { txt = self.pinIn.translationString.value, context = {} }
  for nm, pin in pairs(self.pinInLocal) do
    if nm ~= 'flow' and nm ~= 'translationString' then
      self.pinOut.value.value.context[nm] = self.pinIn[nm].value
    end
  end
end

function C:drawCustomProperties()
  local reason = nil
  if self.pinInLocal.translationString.pinMode == 'hardcoded' then
    local translationString = nil
    im.Text("Translation String:")
    im.SameLine()

    -- draw translate icon depending on state
    if self.variablesState == 1 then
      editor.uiIconImage(editor.icons.translate, im.ImVec2(24, 24), im.ImVec4(1, 0, 0, 1))
      im.tooltip("No context found for this translationString!")
    elseif self.variablesState == 2 then
      editor.uiIconImage(editor.icons.translate, im.ImVec2(24, 24), im.ImVec4(0, 1, 0, 1))
      im.tooltip("Variables loaded successfully")
    else
      editor.uiIconImage(editor.icons.translate, im.ImVec2(24, 24), im.ImVec4(1, 1, 1, 1))
      im.tooltip("Put in translationString to load variables")
    end


    im.SameLine()
    if im.Button("Load Variables", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then

      -- remove old pins
      if self.variablesState == 2 then
        for nm, pin in pairs(self.pinInLocal) do
          if nm ~= 'flow' and nm ~= 'translationString' then
            self:removePin(pin)
          end
        end
      end

      -- do translation
      self.string = self.pinIn["translationString"].value or ""
      translationString = translateLanguage(self.string, self.string)

      dump("string:"..self.string)
      -- update state
      if self.string == "" then
        self.variablesState = 0
      elseif translationString == self.string then
        self.variablesState = 1
      else
        self.variablesState = 2
        for v in string.gmatch(translationString, "{{%a+}}") do
          self:createPin('in', 'string', v:sub(3, -3), nil, '')
        end
      end
    end
  end
  return reason
end

return _flowgraph_createNode(C)
