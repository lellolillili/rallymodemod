-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local initialized = false

local function onFirstUpdate()
    if initialized then return end
    local adapterCount = GFXInit.getAdapterCount()
    if adapterCount == 1 and GFXInit.getAdapterName(0) == "GFX Null Device" then
      log('E','1stUpd',"Null graphics device detected, skipping initialization.")
      return
    end

    local postEffectBrightPassObj = scenetree.findObject("PostEffectBrightPassObject")
    if not postEffectBrightPassObj then
        postEffectBrightPassObj = createObject("PostEffectBrightPass")
        postEffectBrightPassObj:setField("renderTime", 0, "PFXBeforeBin")
        postEffectBrightPassObj:setField("renderBin", 0, "AfterPostFX")
        postEffectBrightPassObj:setField("targetScale", 0, "0.5 0.5")
        postEffectBrightPassObj:registerObject("PostEffectBrightPassObject")
    end

    local postEffectDownScaleObj = scenetree.findObject("PostEffectDownScaleObject")
    if not postEffectDownScaleObj then
        postEffectDownScaleObj = createObject("PostEffectDownScale")
        postEffectDownScaleObj:setField("targetScale", 0, "0.5 0.5")
        postEffectDownScaleObj:registerObject("PostEffectDownScaleObject")
        postEffectBrightPassObj:addObject(postEffectDownScaleObj)
    end

    local postEffectLuminance = scenetree.findObject("PostEffectLuminanceObject")
    if not postEffectLuminance then
        postEffectLuminance = createObject("PostEffectLuminance")
        postEffectLuminance:registerObject("PostEffectLuminanceObject")
        postEffectBrightPassObj:addObject(postEffectLuminance)
    end

    local postEffectCombinePass = scenetree.findObject("PostEffectCombinePassObject")
    if not postEffectCombinePass then
        postEffectCombinePass = createObject("PostEffectCombinePass")
        postEffectCombinePass:registerObject("PostEffectCombinePassObject")
        postEffectBrightPassObj:addObject(postEffectCombinePass)
    end
end

local function onSerialize()
    return {initialized = true}
end

local function onDeserialized(data)
    if data.initialized then
        initialized = true
    end
end

M.onFirstUpdate = onFirstUpdate
M.onSerialize       = onSerialize
M.onDeserialized    = onDeserialized

return M
