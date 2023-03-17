-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = 'Set Input Actions'
C.description = 'Enables or disables various actions, like a scenario does.'
C.color = im.ImVec4(0, 0.3, 1, 0.75)
C.icon = "videogame_asset"
C.category = 'once_instant'

C.pinSchema = {
    { dir = 'in', type = 'bool', name = 'block', description = 'If true, the actions will be blocked. If false or not set, the actions will be unblocked.', hidden = true, default = true, hardcoded = true },
    { dir = 'in', type = 'bool', name = 'ignoreUnrestriced', description = 'If true, this node will be ignored if Competetive Scenario Conditions are disabled.', hidden = true, default = true, hardcoded = true },
    { dir = 'in', type = 'number', name = 'id', description = 'Id of this set of actions, so you can un-do a specific set of actions. If set, will attempt to use that list instead of the ones set in the node properties.', hidden = true },
    { dir = 'out', type = 'number', name = 'id', description = 'Id of this set of actions, so you can un-do a specific set of actions.', hidden = true },
}
C.dependencies = { 'core_input_actionFilter' }
C.tags = { 'blacklist', 'whitelist', 'allow', 'deny', 'block', 'unblock', 'disallow', 'command', 'control' }

local presets = {
    { name = "Empty", desc = "No Actions.", list = {} },
    { name = "Scenario", desc = "Default Scenario actions.", list = { "switch_next_vehicle", "switch_previous_vehicle", "loadHome", "saveHome", "recover_vehicle", "reload_vehicle", "reload_all_vehicles", "vehicle_selector", "parts_selector", "dropPlayerAtCamera", "nodegrabberRender", "slower_motion", "faster_motion", "toggle_slow_motion", "toggleWalkingMode", "toggleCamera", "toggleTraffic", "toggleAITraffic" } }

}

function C:init()
    self.list = {}
    for _, e in ipairs(presets[2].list) do
        table.insert(self.list, e)
    end
    self.search = require('/lua/ge/extensions/editor/util/searchUtil')()
    self.searchText = im.ArrayChar(128)
    self.results = {}
end

local allActions, allCategories, sortedCategories
local function getActions()
    if not allActions then
        allActions = core_input_actions.getActiveActions()
        allCategories = {}
        for name, info in pairs(allActions) do
            allCategories[info.cat] = allCategories[info.cat] or {}
            table.insert(allCategories[info.cat], name)
            info.title = translateLanguage(info.title, info.title)
            info.desc = translateLanguage(info.desc, info.desc)
        end
        sortedCategories = tableKeys(allCategories)
        local orderSort = function(a, b)
            return allActions[a].order < allActions[b].order
        end
        table.sort(sortedCategories)
    end
end

function C:drawSearchInput()
    if im.InputText("##searchInProject", self.searchText, nil, im.InputTextFlags_AutoSelectAll) then
        self.searchChanged = true
    end
    im.SameLine()
    if im.Button("X") then
        self.searchChanged = true
        self.searchText = im.ArrayChar(128)
    end
    if self.searchChanged then
        --self.search:setFrecencyData({})
        self.search:startSearch(ffi.string(self.searchText))
        --    self.search:setSameScoreResolvingFunction(sortFun)
        for name, info in pairs(allActions) do
            self.search:queryElement({
                id = name,
                name = info.cat .. ": " .. info.title .. " (" .. name .. ")",
                info = info,
                frecencyId = id,
            })
        end
        self.results = self.search:finishSearch()
        self.searchChanged = false
    end
end

local matchColor = im.ImVec4(1, 0.5, 0, 1)
function C:highlightText(label, highlightText)
    im.PushStyleVar2(im.StyleVar_ItemSpacing, im.ImVec2(0, 0))
    local pos1 = 1
    local pos2 = 0
    local labelLower = label:lower()
    local highlightLower = highlightText:lower()
    local highlightLowerLen = string.len(highlightLower) - 1
    for i = 0, 6 do
        -- up to 6 matches overall ...
        pos2 = labelLower:find(highlightLower, pos1, true)
        if not pos2 then
            im.Text(label:sub(pos1))
            break
        elseif pos1 < pos2 then
            im.Text(label:sub(pos1, pos2 - 1))
            im.SameLine()
        end

        local pos3 = pos2 + highlightLowerLen
        im.TextColored(matchColor, label:sub(pos2, pos3))
        im.SameLine()
        pos1 = pos3 + 1
    end
    im.PopStyleVar()
end

function C:drawCustomProperties()
    local reason = nil
    im.Text("This node contains " .. #self.list .. " Actions.")
    getActions()
    local listKeys = tableValuesAsLookupDict(self.list)
    local toggled = false
    im.PushItemWidth(im.GetContentRegionAvailWidth())
    if im.BeginCombo("##presets" .. self.id, "Presets...") then
        for _, preset in ipairs(presets) do
            im.Text(preset.name)
            im.tooltip("(" .. #preset.list .. " Actions) " .. preset.desc)
            im.SameLine()
            if im.Button("Set##setact" .. self.id) then
                self.list = deepcopy(preset.list)
                reason = "Set actions to preset " .. preset.name
            end
            im.tooltip("Sets the list to exactly this preset.")
            im.SameLine()
            if im.Button("Add##addact" .. self.id) then
                for _, a in ipairs(preset.list) do
                    listKeys[a] = true
                    toggled = true
                    reason = "Added actions from preset " .. preset.name
                end
            end
            im.tooltip("Adds all actions from this preset to the nodes list.")
            im.SameLine()
            if im.Button("Remove##rmact" .. self.id) then
                for _, a in ipairs(preset.list) do
                    listKeys[a] = false
                    toggled = true
                    reason = "Removed actions from preset " .. preset.name
                end
            end
            im.tooltip("Removes all actions from this preset to the nodes list.")
        end
        im.EndCombo()
    end

    if im.BeginCombo("##actions" .. self.id, "Add Action...", im.ComboFlags_HeightLarge) then
        self:drawSearchInput()
        im.BeginChild1("all", im.ImVec2(im.GetContentRegionAvailWidth(), 400 * editor.getPreference("ui.general.scale")))
        if self.search.matchString ~= "" then
            for _, result in ipairs(self.results) do
                im.BeginChild1(result.id, im.ImVec2(im.GetContentRegionAvailWidth(), 22 * editor.getPreference("ui.general.scale") + 2))
                im.Checkbox("##cba" .. result.id, im.BoolPtr(listKeys[result.id] or false))
                im.SameLine()
                im.BeginDisabled()
                --dumpz(result, 2)
                self:highlightText(result.info.cat .. ":", self.search.matchString)
                im.EndDisabled()
                im.SameLine()
                self:highlightText(result.info.title, self.search.matchString)
                im.SameLine()
                im.BeginDisabled()
                self:highlightText(result.id, self.search.matchString)
                im.EndDisabled()
                im.EndChild()
                if im.IsItemClicked() then
                    listKeys[result.id] = not listKeys[result.id]
                    toggled = true
                    reason = "Added action " .. result.id
                end
                im.tooltip(result.info.desc)
            end
        else
            for i, cat in ipairs(sortedCategories) do
                local allSelected = true
                for i, name in ipairs(allCategories[cat]) do
                    allSelected = allSelected and listKeys[name]
                end
                if im.Selectable1("----- Category: " .. cat .. " -----", allSelected, im.SelectableFlags_DontClosePopups) then
                    for i, name in ipairs(allCategories[cat]) do
                        listKeys[name] = not allSelected
                    end
                    toggled = true
                end
                table.sort(allCategories[cat], orderSort)
                for i, name in ipairs(allCategories[cat]) do
                    im.BeginChild1(name, im.ImVec2(im.GetContentRegionAvailWidth(), 22 * editor.getPreference("ui.general.scale") + 2))
                    local clk = im.Checkbox("##cba" .. name .. "-" .. cat .. "-" .. self.id, im.BoolPtr(listKeys[name] or false))
                    im.SameLine()
                    im.Text(allActions[name].title)
                    im.BeginDisabled()
                    im.SameLine()
                    im.Text(name)
                    im.EndDisabled()
                    im.EndChild()
                    if clk or im.IsItemClicked() then
                        listKeys[name] = not listKeys[name]
                        toggled = true
                        reason = "Added action " .. name
                    end
                    im.tooltip(allActions[name].desc)
                end
                im.Separator()
            end
        end
        im.EndChild()
        im.EndCombo()
    else
        self.searchChanged = true
        self.searchText = im.ArrayChar(128)
    end
    if toggled then
        self.list = {}
        for k, v in pairs(listKeys) do
            if v then
                table.insert(self.list, k)
            end
        end
    end
    im.PopItemWidth()
    if im.TreeNode1("Actions") then
        local rem = nil
        table.sort(self.list)
        for i, e in ipairs(self.list) do
            if im.SmallButton("X##" .. i) then
                rem = i
            end
            im.SameLine()
            im.BeginDisabled()
            im.Text(allActions[e].cat .. ": ")
            im.EndDisabled()
            im.SameLine()
            im.Text(allActions[e].title)
            im.SameLine()
            im.BeginDisabled()
            im.Text(e)
            im.EndDisabled()
        end
        --print(rem)
        if rem then
            table.remove(self.list, rem)
            reason = "Removed Action"
        end

    end
    return reason
end

function C:_onSerialize(res)
    res.list = self.list
end

function C:_onDeserialized(data)
    self.list = data.list or self.list
    if data.data.ignoreWhenUnrestricted ~= nil then
        self:_setHardcodedDummyInputPin(self.pinInLocal.ignoreUnrestriced, data.data.ignoreWhenUnrestricted)
    end
end

function C:drawMiddle(builder, style)
    builder:Middle()
    im.Text("[" .. #self.list .. "]")
    self.name = "Set Input Actions"
    if self.pinInLocal.block.pinMode == 'hardcoded' then
        editor.uiIconImage(self.pinIn.block.value and editor.icons.block or editor.icons.check)
        self.name = (self.pinIn.block.value and "Block" or "Allow") .. " Input Actions"
    end

end

function C:workOnce()
    local list = self.list
    if self.pinIn.ignoreUnrestriced.value and (not settings.getValue('restrictScenarios', true)) then
        list = {}
        log('W', logTag, '**** Restrictions on Scenario Turned off in game settings. Ignoring Set Input Actions actions. ****')
    end

    if not self.pinOut.id.value then
        self.pinOut.id.value = self.mgr.modules.action:registerList(list)
    end
    local id = self.pinIn.id.value or self.pinOut.id.value
    if self.pinIn.block.value then
        self.mgr.modules.action:blockActions(id)
    else
        self.mgr.modules.action:allowActions(id)
    end
end

return _flowgraph_createNode(C)
