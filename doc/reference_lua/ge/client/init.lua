-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-------------------------------------------------------------------------------
-- Variables used by client scripts & code.  The ones marked with (c)
-- are accessed from code.  Variables preceeded by Pref:: are client
-- preferences and stored automatically in the ~/client/prefs.cs file
-- in between sessions.
--
--    (c) Client::MissionFile             Mission file name
--    ( ) Client::Password                Password for server join
--    (c) pref::Master[n]                 List of master servers
--    (c) pref::Net::RegionMask
--    (c) pref::Client::ServerFavoriteCount
--    (c) pref::Client::ServerFavorite[FavoriteCount]
--    .. Many more prefs... need to finish this off

-- Moves, not finished with this either...
--    $mv*Action...

-------------------------------------------------------------------------------
-- These are variables used to control the shell scripts and
-- can be overriden by mods:
-------------------------------------------------------------------------------
local M = {}
--initBaseClient was taken from core/scripts/client/client.cs
local function initBaseClient()
  -- log('I','client', "initBaseClient start...")
  -- dumps(debug.tracesimple())

  -- Base client functionality
  local postFxModule = require("client/postFx")
  rawset(_G, "postFxModule", postFxModule)

  -- TorqueScriptLua.exec("/core/scripts/client/postFx.cs")

  local renderManagerModule = require("client/renderManager")
  -- TorqueScriptLua.exec("/core/scripts/client/renderManager.cs")

  local lightingModule = require("client/lighting")
  -- TorqueScriptLua.exec("/core/scripts/client/lighting.cs")

  -- print("initRenderManager");
  renderManagerModule.initRenderManager()
  -- TorqueScript.eval("initRenderManager();")

  -- print("initLightingSystems");
  lightingModule.initLightingSystems()
  -- TorqueScript.eval("initLightingSystems();")

  local adapterCount = GFXInit.getAdapterCount()
  if adapterCount == 1 and GFXInit.getAdapterName(0) == "GFX Null Device" then
    log('E','client',"Null graphics device detected, skipping PostFX initialization.")
    return
  end

  -- -- Initialize all core post effects.
  -- log('I','client', "Initialize the post effect manager")
  postFxModule.initPostEffects()
  -- TorqueScript.eval("initPostEffects();")

  -- Get the default preset settings
  -- TorqueScript.eval("PostFXManager.settingsApplyDefaultPreset();")
  postFxModule.applyDefaultPreset()

  -- log('I','client', "... initBaseClient done")
end

--reloadBaseClient was taken from core/scripts/client/client.cs
local function reloadBaseClient()
  log('I','client', "reloadBaseClient start...");
  -- dumps(debug.tracesimple())

  -- Base client functionality
  local postFxModule = require("client/postFx");
  rawset(_G, "postFxModule", postFxModule)
  -- TorqueScriptLua.exec("/core/scripts/client/postFx.cs")

  local renderManagerModule = require("client/renderManager");
  -- TorqueScriptLua.exec("/core/scripts/client/renderManager.cs")

  local lightingModule = require("client/lighting");
  -- TorqueScriptLua.exec("/core/scripts/client/lighting.cs")

  -- print("initLightingSystems");
  lightingModule.reloadLightingSystems();
  -- TorqueScript.eval("initLightingSystems();")

  local adapterCount = GFXInit.getAdapterCount()
  if adapterCount == 1 and GFXInit.getAdapterName(0) == "GFX Null Device" then
    log('E','client',"Null graphics device detected, skipping PostFX initialization.")
    return
  end

  -- -- Initialize all core post effects.
  -- log('I','client', "Initialize the post effect manager")
  postFxModule.reloadPostEffects()
  -- TorqueScript.eval("initPostEffects();")

  -- log('I','client', "... initBaseClient done")
end

M.loadMainMenu = function()
  -- Startup the client with the Main menu...
  local onlyGui = scenetree.findObject("OnlyGui")
  local canvas = scenetree.findObject("Canvas")
  local cursor = scenetree.findObject("DefaultCursor")
  if onlyGui and canvas and cursor then
    canvas:setContent(onlyGui)
    canvas:setCursor(cursor)
  end
end

local function createGameViewportCtrl()
  local onlyGui = createObject("GameViewportCtrl")
  onlyGui.forceFOV = 0
  onlyGui.reflectPriority = 1
  onlyGui:setField("margin", 0, "0 0 0 0")
  onlyGui:setField("padding", 0, "0 0 0 0")
  onlyGui:setField("anchorTop", 0, "1")
  onlyGui:setField("anchorBottom", 0, "0")
  onlyGui:setField("anchorLeft", 0, "1")
  onlyGui:setField("anchorRight", 0, "0")
  onlyGui:setField("position", 0, "0 0")
  onlyGui:setField("extent", 0, "1024 768")
  onlyGui:setField("minExtent", 0, "8 8")
  onlyGui:setField("horizSizing", 0, "right")
  onlyGui:setField("vertSizing", 0, "bottom")
  onlyGui:setField("profile", 0, "GuiDefaultProfile")
  onlyGui:setField("tooltipProfile", 0, "GuiToolTipProfile")
  onlyGui:setField("hovertime", 0, "1000")
  onlyGui:setField("helpTag", 0, "0")
  onlyGui:setField("noCursor", 0, "0")
  onlyGui.visible = 1
  onlyGui.active = 1
  onlyGui.isContainer = 1
  onlyGui.canSave = 1
  onlyGui.canSaveDynamicFields = 1
  onlyGui.enabled = 1
  onlyGui:registerObject("OnlyGui")

  -- DO NOT RENAME maincef, its name is hardcoded in c++
  local maincef = createObject("CefGui")
  maincef:setField("docking", 0, "Client")
  maincef:setField("margin", 0, "0 0 0 0")
  maincef:setField("padding", 0, "0 0 0 0")
  maincef:setField("anchorTop", 0, "1")
  maincef:setField("anchorBottom", 0, "0")
  maincef:setField("anchorLeft", 0, "1")
  maincef:setField("anchorRight", 0, "0")
  maincef:setField("position", 0, "0 0")
  maincef:setField("extent", 0, "1024 768")
  maincef:setField("minExtent", 0, "8 2")
  maincef:setField("horizSizing", 0, "right")
  maincef:setField("vertSizing", 0, "bottom")
  maincef:setField("profile", 0, "GuiCEFProfile")
  maincef:setField("tooltipProfile", 0, "GuiToolTipProfile")
  maincef:setField("hovertime", 0, "1000")
  maincef:setField("StartURL", 0, "local://local/ui/entrypoints/main/index.html")
  maincef.visible = 1
  maincef.active = 1
  maincef.isContainer = 1
  maincef.canSave = 1
  maincef.canSaveDynamicFields = 0
  maincef:registerObject("maincef")

  onlyGui:add(maincef)
end

local cmdArgs = Engine.getStartingArgs()

M.initClient = function()
  -- log('I','client', "initClient start...")

  -- These should be game specific GuiProfiles.  Custom profiles are saved out
  -- from the Gui Editor.  Either of these may override any that already exist.
  -- NOTE(AK) 22/03/2022: These are not used, left as comment so we know the delete them
  -- TorqueScriptLua.exec("art/gui/gameProfiles.cs")
  -- TorqueScriptLua.exec("art/gui/customProfiles.cs")

  -- The common module provides basic client functionality
  initBaseClient()

  createGameViewportCtrl()

  -- default cubemap for levels without LevelInfo.globalEnviromentMap
  setConsoleVariable("$defaultLevelEnviromentMap", "BNG_Sky_02_cubemap")

  if not tableFindKey(cmdArgs, '-convertCSMaterials') then   
    loadDirRec("core/art/datablocks/")
    loadDirRec("art/")

    --TODO: check funcs
    if FS:fileExists(FS:expandFilename("./audioData.cs")) then
      TorqueScriptLua.exec( "./audioData.cs" )
    end
  end

  -- Start up the main menu... this is separated out into a
  -- method for easier mod override.
  -- log('I','main_entry','$startWorldEditor = '..tostring(getConsoleBoolVariable("$startWorldEditor")))
  if getConsoleBoolVariable("$startWorldEditor") then
    -- Editor GUI's will start up in the primary main.lua once
    -- engine is initialized.
    return
  end

  -- Otherwise go to the splash screen.
  local canvas = scenetree.findObject("Canvas")
  -- log('I','main_entry','scenetree.findObject("Canvas") = '..dumps(canvas))
  if canvas then
    local cursor = scenetree.findObject("DefaultCursor")
    if cursor then
      -- log('I','main_entry','scenetree.findObject("DefaultCursor") = '..dumps(cursor))
      canvas:setCursor(cursor)
    end
  end

  --loadStartup();
  -- BEAMNG: load the menu directly
  M.loadMainMenu()

  -- print("... initClient done")
end

M.reloadClient = function()
  -- log('I','client', "reloadClient start...")

  -- The common module provides basic client functionality
  reloadBaseClient()

  --[[ -- After porting thest cs files to lua, check if there is a need to run them again when we reload lua
  TorqueScriptLua.exec("core/art/datablocks/datablockExec.cs")
  loadDirRec("art/")

  --TODO: check funcs
  if FS:fileExists(FS:expandFilename("./audioData.cs")) then
    TorqueScriptLua.exec( "./audioData.cs" )
  end
  ]]
end
return M
