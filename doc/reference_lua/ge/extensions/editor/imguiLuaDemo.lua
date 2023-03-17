-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local logTag = 'editor_imgui_lua_demo'
local im = ui_imgui
local windowOpen = im.BoolPtr(false)
local ffi = require('ffi')
local M = {}
local imguiVersion = "1.62 WIP"

local tobit = bit.tobit
local band = bit.band
local bor = bit.bor
local bxor = bit.bxor
local bnot = bit.bnot
local blshift = bit.lshift

local show_app_main_menu_bar = im.BoolPtr(false)
local show_app_console = im.BoolPtr(true)
local show_app_log = im.BoolPtr(false)
local show_app_layout = im.BoolPtr(false)
local show_app_property_editor = im.BoolPtr(false)
local show_app_long_text = im.BoolPtr(false)
local show_app_auto_resize = im.BoolPtr(false)
local show_app_constrained_resize = im.BoolPtr(false)
local show_app_simple_overlay = im.BoolPtr(false)
local show_app_window_titles = im.BoolPtr(false)
local show_app_custom_rendering = im.BoolPtr(false)
local show_app_metrics = im.BoolPtr(false)
local show_app_about = im.BoolPtr(false)
local show_app_style_editor = im.BoolPtr(false)


-- OptionsMenu values
local optionsEnabled = im.BoolTrue
-- SliderFloat values
local sliderVal = im.FloatPtr(0.5)
-- InputFloat values
local inputFloatVal = im.FloatPtr(0.5)
-- -- Combo values
local comboCurrentItem = im.IntPtr(0)
-- Checkbox values
local checkboxVal = im.BoolPtr(true)

-- Colors Menu values
local colorsMenuCursorPos = im.ImVec2Ptr(800,200)
local imguiCol_Count = tonumber(im.Col_COUNT)
-- Add Rect Filled values
local vec2B = im.ImVec2(200, 20)
-- PlotLines example values
local plot_lines_window_open = im.BoolPtr(false)
local imgui_windowFlag_MenuBar = im.WindowFlags_MenuBar
local plotLineArray = im.ArrayFloat(8)
plotLineArray[0] = 1
plotLineArray[1] = 5
plotLineArray[2] = 4
plotLineArray[3] = 1
plotLineArray[4] = 3
plotLineArray[5] = 1
plotLineArray[6] = 4
plotLineArray[7] = 0
local plotLineTable = im.CreateTable(100)
local v = 0
local sin = 0
local plotLinesWindowSize = im.ImVec2( 200, 100 )
-- Buttons example values
local buttons_window_open = im.BoolPtr(false)
local buttonsSameLinePosX = im.Float(0)
local buttonsSameLineSpacingW = im.Float(50)
-- mouse button values
local spaceKeyIndex = im.Int(32)
local keyPressedRepeatDelay = im.Float(0.005)
local keyPressedRate = im.Float(0.001)
local LMB = im.IntZero
local RMB = im.IntOne
local MMB = im.Int(2)
-- Dummy values
local dummy = im.ImVec2Ptr(10, 40)
-- ExampleAppWindowTitles values
local nextWindowPos = im.ImVec2(100, 100)
local nextWindowPosCond = im.Cond_FirstUseEver
local nextWindowSize = im.ImVec2(500, 440)
local nextWindowSizeCond = im.Cond_FirstUseEver
-- ExampleAppLayout values
local appLayoutWindowOpen = im.BoolPtr(true)
local appLayoutWindowLeftPanel = im.ImVec2(150, 0)
local appLayoutWindowRightPanel = im.ImVec2(150, 0)
local appLayoutWindowLeftPanelLabel = im.ArrayChar(128)
local appLayoutWindowRightPanelLabel = im.ArrayChar(128)
local appLayoutWindowLeftPanelSelected = 0
-- Groundmodel Debug values
local groundmodelDebugGroundmodelPanel = im.ImVec2(150, 0)
local groundmodelDebugColorsPanel = im.ImVec2(150, 0)
-- Text Example values
local textExampleWindowOpen = im.BoolPtr(true)
local textColoredColor = im.ImVec4(1.0, 0.0, 0.0, 1.0)
-- Debug Window values
local debugWindowOpen = im.BoolPtr(true)
  -- DragFloat
local dragFloatVal = im.FloatPtr(1)
local dragFloatValSpeed im.Float(1)
local dragFloatValMin = im.Float(0.0)
local dragFloatValMax = im.Float(0.0)
local dragFloatFormat = "%.1f"
local dragFloatPower = im.Float(1.0)
local dragFloat2Val = im.ArrayFloat(2)
dragFloat2Val[0] = im.Float(0.0)
dragFloat2Val[1] = im.Float(1.0)
local dragFloat3Val = im.ArrayFloat(3)
dragFloat3Val[0] = im.Float(2.0)
dragFloat3Val[1] = im.Float(3.0)
dragFloat3Val[2] = im.Float(4.0)
local dragFloat4Val = im.ArrayFloat(4)
dragFloat4Val[0] = im.Float(5.0)
dragFloat4Val[1] = im.Float(6.0)
dragFloat4Val[2] = im.Float(7.0)
dragFloat4Val[3] = im.Float(8.0)
local dragFloatRange2ValMin = im.FloatPtr(0.0)
local dragFloatRange2ValMax = im.FloatPtr(10.0)
  -- DragInt
local dragIntVal = im.IntPtr(1)
local dragIntValSpeed im.Float(1.0)
local dragIntValMin = im.Int(-500)
local dragIntValMax = im.Int(500)
local dragIntFormat = "%d"
local dragInt2Val = im.ArrayInt(2)
dragInt2Val[0] = im.Int(0)
dragInt2Val[1] = im.Int(1)
local dragInt3Val = im.ArrayInt(3)
dragInt3Val[0] = im.Int(2)
dragInt3Val[1] = im.Int(3)
dragInt3Val[2] = im.Int(4)
local dragInt4Val = im.ArrayInt(4)
dragInt4Val[0] = im.Int(5)
dragInt4Val[1] = im.Int(6)
dragInt4Val[2] = im.Int(7)
dragInt4Val[3] = im.Int(8)
local dragIntRange2ValMin = im.IntPtr(0)
local dragIntRange2ValMax = im.IntPtr(10)
  -- DragScalar
local dragScalarVal = ffi.new("voidPtr")
local dragScalarDragSpeed = im.Float(1.0)

local function ShowExampleMenuFile()
  im.MenuItem1("(dummy menu)", "", im.BoolFalse, im.BoolFalse)
  if im.MenuItem1("New", "", im.BoolFalse, im.BoolTrue) then end
  if im.MenuItem1("Open", "Ctrl+O", im.BoolFalse, im.BoolTrue) then end

  if im.BeginMenu("Open Recent", im.BoolTrue) then
    im.MenuItem1("fish_hat.c", "", im.BoolFalse, im.BoolTrue)
    im.MenuItem1("fish_hat.inl", "", im.BoolFalse, im.BoolTrue)
    im.MenuItem1("fish_hat.h", "", im.BoolFalse, im.BoolTrue)
    if im.BeginMenu("More..", im.BoolTrue) then
      im.MenuItem1("Hello", "", im.BoolFalse, im.BoolTrue)
      im.MenuItem1("Sailor", "", im.BoolFalse, im.BoolTrue)
      if im.BeginMenu("Recurse..", im.BoolTrue) then
        ShowExampleMenuFile()
        im.EndMenu()
      end
      im.EndMenu()
    end
    im.EndMenu()
  end
  if im.MenuItem1("Save", "Ctrl+S", im.BoolFalse, im.BoolTrue) then end
  if im.MenuItem1("Save As..", "", im.BoolFalse, im.BoolTrue) then end
  im.Separator()
  if im.BeginMenu("Options", im.BoolTrue) then
    im.MenuItem1("Enabled", "", optionsEnabled, im.BoolTrue)
    im.BeginChild1("child", im.ImVec2Ptr(0, 60), im.BoolTrue, 0)
      for i = 0, 10, 1 do--for (int i = 0; i < 10; i++)
        im.Text("Scrolling Text %d", i)
      end
    im.EndChild()
    im.SliderFloat("SliderFloat", sliderVal, 0.0, 1.0)
    im.InputFloat("InputFloat", inputFloatVal, 0.1)
    im.Combo2("Combo2", comboCurrentItem, "Yes\0No\0Maybe\0\0")
    im.Checkbox("Checkbox", checkboxVal)
    im.EndMenu()
  end

  if im.BeginMenu("Colors", im.BoolTrue) then
    local sz = im.GetTextLineHeight()
    for i = 0, tonumber(im.Col_COUNT) do
      local name = ffi.string(im.GetStyleColorName(i))
      local p = im.GetCursorScreenPos()
      im.ImDrawList_AddRectFilled(im.GetWindowDrawList(), p, im.ImVec2(p.x + sz, p.y + sz), im.GetColorU321( im.ImGuiCol(i), 1.0 ))
      im.Dummy(im.ImVec2(sz, sz))
      im.SameLine()
      im.MenuItem1(name)
    end
    im.EndMenu()
  end
  -- if (im.BeginMenu("Disabled", im.BoolFalse)) // Disabled
  -- {
  --     IM_ASSERT(0)
  -- }
  if im.MenuItem1("Checked", "", im.BoolTrue, im.BoolFalse) then end
  if im.MenuItem1("Quit", "Alt+F4", im.BoolTrue, im.BoolFalse) then end
end

-- Demonstrate using "##" and "###" in identifiers to manipulate ID generation.
-- This apply to regular items as well. Read FAQ section "How can I have multiple widgets with the same label? Can I have widget without a label? (Yes). A primer on the purpose of labels/IDs." for details.
local function ShowExampleAppWindowTitles()
  -- By default, Windows are uniquely identified by their title.
  -- You can use the "##" and "###" markers to manipulate the display/ID.

  -- Using "##" to display same title but have unique identifier.
  im.SetNextWindowPos(nextWindowPos, nextWindowPosCond)
  im.Begin("Same title as another window##1")
  im.Text("This is window 1.\nMy title is the same as window 2, but my identifier is unique.")
  im.End()

  im.SetNextWindowPos(nextWindowPos, nextWindowPosCond)
  im.Begin("Same title as another window##2")
  im.Text("This is window 2.\nMy title is the same as window 1, but my identifier is unique.")
  im.End()

  -- Using "###" to display a changing title but keep a static identifier "AnimatedTitle"
  -- char buf[128]
  -- sprintf(buf, "Animated title %c %d###AnimatedTitle", "|/-\\"[(int)(im.GetTime()/0.25f)&3], im.GetFrameCount())
  im.SetNextWindowPos(im.ImVec2(100,300), nextWindowPosCond)
  im.Begin("window###3")
  -- im.Begin(buf)
  im.Text("This window has a changing title.")
  im.End()
end

-- Demonstrate create a window with multiple child windows.
local function ShowExampleAppLayout()
  im.SetNextWindowSize(nextWindowSize, im.Cond_FirstUseEver)
  if im.Begin("Example: Layout", appLayoutWindowOpen, im.WindowFlags_MenuBar) then
    -- MenuBar
    if im.BeginMenuBar() then
      if im.BeginMenu("File") then
        if im.MenuItem1("Close") then
          print("Close")
          appLayoutWindowOpen = im.BoolPtr(false)
        end
        im.EndMenu()
      end
    im.EndMenuBar()
    end

  -- left
    im.BeginChild1("left panel", appLayoutWindowLeftPanel, im.BoolTrue)
    for i = 0, 99 do
      appLayoutWindowLeftPanelLabel = "MyObject " .. tostring(i)
      if im.Selectable1(appLayoutWindowLeftPanelLabel, appLayoutWindowLeftPanelSelected == i and im.BoolTrue or im.BoolFalse) then
        appLayoutWindowLeftPanelSelected = i
      end
    end
    im.EndChild()
    im.SameLine()

  -- right
    im.BeginGroup()
      im.BeginChild1("item view", im.ImVec2(0, -im.GetFrameHeightWithSpacing())); -- Leave room for 1 line below us
      im.Text("MyObject: " .. tostring(appLayoutWindowLeftPanelSelected))
      im.Separator()
      im.TextWrapped("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. ")
      im.EndChild()
      if im.Button("Revert") then end
      im.SameLine()
      if im.Button("Save") then end
    im.EndGroup()
  end
  im.End()
end

-- Demonstrate creating a fullscreen menu bar and populating it.
local function ShowExampleAppMainMenuBar()
  if im.BeginMainMenuBar() then
    if im.BeginMenu("File", ffi.new("bool", im.BoolTrue())) then
      ShowExampleMenuFile()
      im.EndMenu()
    end
    if im.BeginMenu("Edit", im.BoolTrue()) then
      if im.MenuItem1("Undo", "CTRL+Z", im.BoolFalse(), im.BoolTrue()) then end
      if im.MenuItem1("Redo", "CTRL+Y", im.BoolFalse(), im.BoolFalse()) then end  -- Disabled item
      im.Separator()
      if im.MenuItem1("Cut", "CTRL+X", im.BoolFalse(), im.BoolTrue()) then end
      if im.MenuItem1("Copy", "CTRL+C", im.BoolFalse(), im.BoolTrue()) then end
      if im.MenuItem1("Paste", "CTRL+V", im.BoolFalse(), im.BoolTrue()) then end
      im.EndMenu()
    end
    im.EndMainMenuBar()
  end
end

local function ShowAppAbout()
  im.Begin("About Dear ImGui", im.BoolPtr(true), ImGuiWindowFlags_AlwaysAutoResize)
    im.Text("Dear ImGui, " .. ffi.string(im.GetVersion()))
    im.Separator()
    im.Text("By Omar Cornut and all dear imgui contributors.")
    im.Text("Dear ImGui is licensed under the MIT License, see LICENSE for more information.")
  im.End()
end

local function ShowUserGuide()
  im.BulletText("Double-click on title bar to collapse window.")
  im.BulletText("Click and drag on lower right corner to resize window\n(double-click to auto fit window to its contents).")
  im.BulletText("Click and drag on any empty space to move window.")
  im.BulletText("TAB/SHIFT+TAB to cycle through keyboard editable fields.")
  im.BulletText("CTRL+Click on a slider or drag box to input value as text.")
  if im.GetIO().FontAllowUserScaling == true then
    im.BulletText("CTRL+Mouse Wheel to zoom window contents.")
  end
  im.BulletText("Mouse Wheel to scroll.")
  im.BulletText("While editing text:\n")
  im.Indent()
  im.BulletText("Hold SHIFT or use mouse to select text.")
  im.BulletText("CTRL+Left/Right to word jump.")
  im.BulletText("CTRL+A or double-click to select all.")
  im.BulletText("CTRL+X,CTRL+C,CTRL+V to use clipboard.")
  im.BulletText("CTRL+Z,CTRL+Y to undo/redo.")
  im.BulletText("ESCAPE to revert.")
  im.BulletText("You can apply arithmetic operators +,*,/ on numerical values.\nUse +- to subtract.")
  im.Unindent()
end

-- Widgets values
local var = {}
-- Widgets: Basic
local widgetsBasicButtonClicked = 0
local widgetsBasicCheckbox = im.BoolPtr(false)
local widgetsBasicRadioButtonVal = im.IntPtr(0)
local style = ffi.new("ImGuiStyle[1]")
-- print(style)
-- local widgetsBasicArrowButtonSpacing = im.GetStyle(style).ItemInnerSpacing.x
local widgetsBasicTooltipTbl = {0.6, 0.1, 1.0, 0.5, 0.92, 0.1, 0.2}
local widgetsBasicTooltipArray = im.TableToArrayFloat(widgetsBasicTooltipTbl)
local widgetsBasicComboItemCurrent = im.IntPtr(0)
local widgetsBasicComboItemsTbl = {"AAAA", "BBBB", "CCCC", "DDDD", "EEEE", "FFFF", "GGGG", "HHHH", "IIII", "JJJJ", "KKKK", "LLLLLLL", "MMMM", "OOOOOOO"}
local widgetsBasicComboItems = im.ArrayCharPtrByTbl(widgetsBasicComboItemsTbl)
local widgetsBasicInputText = im.ArrayChar(128)
local widgetsBasicInputInt = im.IntPtr(123)
local widgetsBasicInputFloat = im.FloatPtr(0.001)
local widgetsBasicInputDouble = im.DoublePtr(999999.00000001)
local widgetsBasicInputScientific = im.FloatPtr(1.0e10)
local widgetsBasicInputFloat3 = im.ArrayFloat(3)
widgetsBasicInputFloat3[0] = im.Float(0.1)
widgetsBasicInputFloat3[1] = im.Float(0.2)
widgetsBasicInputFloat3[2] = im.Float(0.3)
local widgetsBasicDragIntA = im.IntPtr(50)
local widgetsBasicDragIntB = im.IntPtr(42)
local widgetsBasicDragFloatA = im.FloatPtr(1.0)
local widgetsBasicDragFloatB = im.FloatPtr(0.0067)
local widgetsBasicDragFloatB = im.FloatPtr(0.0067)
local widgetsBasicSliderInt = im.IntPtr(0)
local widgetsBasicSliderFloatA = im.FloatPtr(0.123)
local widgetsBasicSliderFloatB = im.FloatPtr(0.0)
local widgetsBasicSliderAngle = im.FloatPtr(0.0)
local widgetsBasicColorEdit3 = im.ArrayFloat(3)
widgetsBasicColorEdit3[0] = im.Float(1.0)
widgetsBasicColorEdit3[1] = im.Float(0.0)
widgetsBasicColorEdit3[2] = im.Float(0.2)
local widgetsBasicColorEdit4 = ffi.new("float[4]", {[0] = 0.4, 0.7, 0.0, 0.5})
local widgetsBasicListBoxItemsTbl = { "Apple", "Banana", "Cherry", "Kiwi", "Mango", "Orange", "Pineapple", "Strawberry", "Watermelon" }
local widgetsBasicListBoxItems = im.ArrayCharPtrByTbl(widgetsBasicListBoxItemsTbl)
local widgetsBasicListBoxItemCurrent = im.IntPtr(1)
-- Window options
var.imguiDemoWindowOpen = im.BoolPtr(false)
var.imguiDemoWindowFlags = im.Int(0)
-- Demonstrate the various window flags. Typically you would just use the default!
var.no_titlebar = im.BoolPtr(false)
var.no_scrollbar = im.BoolPtr(false)
var.no_menu = im.BoolPtr(false)
var.no_move = im.BoolPtr(false)
var.no_resize = im.BoolPtr(false)
var.no_collapse = im.BoolPtr(false)
var.no_close = im.BoolPtr(false)
var.no_nav = im.BoolPtr(false)
-- Widgets: Trees / Advanced with Selectable nodes
var.align_label_with_current_x_position = im.BoolPtr(false)
var.node_clicked = -1
var.node_open = im.Bool(false);
-- Widgets: CollapsingHeader
var.closable_group = im.BoolPtr(true)
-- Widgets: Text
var.pos = im.ImVec2Ptr(0,0)
var.wrap_width = im.FloatPtr(200.0)
var.buf = im.ArrayChar(32)
var.buf = im.CharPtr("\xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e")
-- static char buf[32] = "\xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e"
var.flags = im.IntPtr(0)
var.itemsTbl = { "AAAA", "BBBB", "CCCC", "DDDD", "EEEE", "FFFF", "GGGG", "HHHH", "IIII", "JJJJ", "KKKK", "LLLLLLL", "MMMM", "OOOOOOO" }
var.items = im.ArrayCharPtrByTbl(var.itemsTbl)
var.item_current = var.itemsTbl[1]
var.itemsLength = im.ArraySize(var.items) - 1
var.item_current_2 = im.IntPtr(0)
var.item_current_3 = im.IntPtr(-1)
var.selection = ffi.new("bool[?]", 5)
var.selection[0] = false
var.selection[1] = true
var.selection[2] = false
var.selection[3] = false
var.selection[4] = false
var.selected = -1
var.selection_2 = im.ArrayBoolByTbl({false, true, false, true, false})
var.selected_2 = im.ArrayBoolByTbl({ false, false, true })
var.selected_3 = ffi.new("bool[?]", 16)
var.selected_4 = im.ArrayBoolByTbl({ true, false, false, false, false, true, false, false, false, false, true, false, false, false, false, true })
var.buf1 = im.ArrayChar(64)
var.buf2 = im.ArrayChar(64)
var.buf3 = im.ArrayChar(64)
var.buf4 = im.ArrayChar(64)
var.buf5 = im.ArrayChar(64)
var.bufpass = im.ArrayChar(64)
ffi.copy(var.bufpass, "password123")
var.read_only = im.BoolPtr(false)
var.text = im.ArrayChar(1024*16)
var.str = "/*\nThe Pentium F00F bug, shorthand for F0 0F C7 C8,\nthe hexadecimal encoding of one offending instruction,\nmore formally, the invalid operand with locked CMPXCHG8B\ninstruction bug, is a design flaw in the majority of\nIntel Pentium, Pentium MMX, and Pentium OverDrive\nprocessors (all in the P5 microarchitecture).\n*/\n\nlabel:\n\tlock cmpxchg8b eax\n"
ffi.copy(var.text, var.str)
var.animate = im.BoolPtr(true)
var.arr = im.ArrayFloatByTbl({ 0.6, 0.1, 1.0, 0.5, 0.92, 0.1, 0.2 })
var.values = im.ArrayFloat(90)
var.values_offset = 0
var.refresh_time = 0.0
var.progress = 0.0
var.progress_dir = 1.0
var.progress_saturated = 0
var.phase = 0.0
var.func_type = im.IntPtr(0)
var.display_count = im.IntPtr(70)
--Widgets Images
var.pressed_count = 0

local colorPicker = {}
-- ImVec4
colorPicker.color = im.ImColorByRGB(114, 144, 154, 200).Value
-- float*
colorPicker.color2 = im.ImVec4ToFloatPtr(colorPicker.color)
local col
colorPicker.alpha_preview = im.BoolPtr(true)
colorPicker.alpha_half_preview = im.BoolPtr(false)
colorPicker.options_menu = im.BoolPtr(true)
colorPicker.hdr = im.BoolPtr(false)
colorPicker.saved_palette_inited = im.BoolPtr(false)
colorPicker.saved_palette = im.ArrayImVec4(32)
colorPicker.backup_color = im.ImVec4Ptr(0, 0, 0, 0)
colorPicker.open_popup = im.BoolPtr(false)
local rangeWidgets = {}
rangeWidgets.beginF = im.FloatPtr(10)
rangeWidgets.endF = im.FloatPtr(90)
rangeWidgets.beginI = im.IntPtr(100)
rangeWidgets.endI = im.IntPtr(1000)

local function Widgets_Basic()
  if im.TreeNode1("Basic") then
    if im.Button("Button") then
      widgetsBasicButtonClicked = widgetsBasicButtonClicked + 1
    end
    if widgetsBasicButtonClicked == 1 then
      im.SameLine()
      im.Text("Thanks for clicking me!")
    end
    im.Checkbox("Checkbox", widgetsBasicCheckbox)
    im.SameLine()
    im.Text(tostring(widgetsBasicCheckbox[0]))

    im.RadioButton2("Radio A", widgetsBasicRadioButtonVal, im.IntZero)
    im.SameLine()
    im.RadioButton2("Radio B", widgetsBasicRadioButtonVal, im.IntOne)
    im.SameLine()
    im.RadioButton2("Radio C", widgetsBasicRadioButtonVal, im.Int(2))
    im.SameLine()
    im.Text("RadioButton: " .. widgetsBasicRadioButtonVal[0])

    -- Color buttons, demonstrate using PushID() to add unique identifier in the ID stack, and changing style.
    for i = 0, 6 do
      if i > 0 then
        im.SameLine()
      end
      im.PushID4(i)
      im.PushStyleColor2(im.Col_Button, im.ColorConvertHSVtoRGB( i/7.0, 0.6, 0.6, 1.0))
      im.PushStyleColor2(im.Col_ButtonHovered, im.ColorConvertHSVtoRGB( i/7.0, 0.7, 0.7))
      im.PushStyleColor2(im.Col_ButtonActive, im.ColorConvertHSVtoRGB( i/7.0, 0.8, 0.8))
      im.Button("Click")
      im.PopStyleColor(im.Int(3))
      im.PopID()
    end

    -- ARROW BUTTONS
    local spacing = im.ImVec2Ptr(0,0)
    im.ImGuiStyle_ItemInnerSpacing(spacing)
    if im.ArrowButton("##left", im.Dir_Left) then end
    im.SameLine(0.0, spacing[1].x)
    if im.ArrowButton("##left", im.Dir_Right) then end

    im.Text("Hover over me")
    if im.IsItemHovered() then
      im.SetTooltip("I am a tooltip")
    end

    im.SameLine()
    im.Text("- or me")
    if im.IsItemHovered() then
      im.BeginTooltip()
      im.Text("I am a fancy tooltip")
      im.PlotLines1("Curve", widgetsBasicTooltipArray, im.GetLengthArrayFloat(widgetsBasicTooltipArray))
      im.EndTooltip()
    end

    im.Separator()
    -- LABEL TEXT
    im.LabelText("label", "Value")
    -- COMBO
    -- Using the _simplified_ one-liner Combo() api here
    im.Combo1("combo", widgetsBasicComboItemCurrent, widgetsBasicComboItems)
    -- im.Combo1("combo", widgetsBasicComboItemCurrent, widgetsBasicComboItems, im.ArraySize(widgetsBasicComboItems) - 1)
    im.SameLine()
    im.ShowHelpMarker("Refer to the \"Combo\" section below for an explanation of the full BeginCombo/EndCombo API, and demonstration of various flags.\n")
    -- INPUT TEXT
    im.InputText("input text", widgetsBasicInputText)
    im.SameLine()
    im.ShowHelpMarker("Hold SHIFT or use mouse to select text.\nCTRL+Left/Right to word jump.\nCTRL+A or double-click to select all.\nCTRL+X,CTRL+C,CTRL+V clipboard.\nCTRL+Z,CTRL+Y undo/redo.\nESCAPE to revert.\n")
    -- INPUT INT
    im.InputInt("input int", widgetsBasicInputInt)
    im.SameLine()
    im.ShowHelpMarker("You can apply arithmetic operators +,*,/ on numerical values.\n  e.g. [ 100 ], input \'*2\', result becomes [ 200 ]\nUse +- to subtract.\n")
    -- INPUT FLOAT
    im.InputFloat("input float", widgetsBasicInputFloat, 0.01, 1.0)
    -- INPUT DOUBLE
    im.InputDouble("input double", widgetsBasicInputDouble, 0.1, 1.0, "%.8f")
    -- INPUT SCIENTIFIC
    im.InputFloat("input scientific", widgetsBasicInputScientific, 0.0, 0.0, "%e")
    im.SameLine()
    im.ShowHelpMarker("You can input value using the scientific notation,\n  e.g. \"1e+8\" becomes \"100000000\".\n")
    -- INPUT FLOAT 3
    im.InputFloat3("input float3", widgetsBasicInputFloat3)
    -- DRAG INT
    im.DragInt("drag int", widgetsBasicDragIntA, 1)
    im.SameLine()
    im.ShowHelpMarker("Click and drag to edit value.\nHold SHIFT/ALT for faster/slower edit.\nDouble-click or CTRL+click to input value.")
    im.DragInt("drag int 0..100", widgetsBasicDragIntB, 1, 0, 100, "%d%%")
    -- DRAG FLOAT
    im.DragFloat("drag float", widgetsBasicDragFloatA, 0.005)
    im.DragFloat("drag small float", widgetsBasicDragFloatB, 0.0001, 0.0, 0.0, "%.06f ns")
    -- SLIDER INT
    im.SliderInt("slider int", widgetsBasicSliderInt, -1, 3)
    im.SameLine()
    im.ShowHelpMarker("CTRL+click to input value.")
    -- SLIDER FLOAT
    im.SliderFloat("slider float", widgetsBasicSliderFloatA, 0.0, 1.0, "ratio = %.3f")
    im.SliderFloat("slider float (curve)", widgetsBasicSliderFloatB, -10.0, 10.0, "%.4f", 2.0)
    -- SLIDER ANGLE
    im.SliderAngle("slider angle", widgetsBasicSliderAngle)
    -- COLOR EDIT 3
    im.ColorEdit3("color 1", widgetsBasicColorEdit3)
    im.SameLine()
    im.ShowHelpMarker("Click on the colored square to open a color picker.\nRight-click on the colored square to show options.\nCTRL+click on individual component to input value.\n")
    -- COLOR EDIT 4
    im.ColorEdit4("color 2", widgetsBasicColorEdit4)
    -- LIST BOX
    im.ListBox("listbox\n(single select)", widgetsBasicListBoxItemCurrent, widgetsBasicListBoxItems, im.ArraySize(widgetsBasicListBoxItems) - 1, 4)

    -- //static int listbox_item_current2 = 2
    -- //im.PushItemWidth(-1)
    -- //im.ListBox("##listbox2", &listbox_item_current2, listbox_items, IM_ARRAYSIZE(listbox_items), 4)
    -- //im.PopItemWidth()
    im.TreePop()
  end
end

local function Widgets_Trees()
  if im.TreeNode1("Trees") then
    if im.TreeNode1("Basic trees") then
      for i = 0, 4 do
        if im.TreeNode3(im.voidPtr, "Child " .. i) then
          im.Text("blah blah")
          im.SameLine()
          if im.SmallButton("button") then end
          im.TreePop()
        end
      end
    im.TreePop()
    end

    if im.TreeNode1("Advanced, with Selectable nodes") then
      im.ShowHelpMarker("This is a more standard looking tree with selectable nodes.\nClick to select, CTRL+Click to toggle, click on arrows or double-click to open.")
      im.Checkbox("Align label with current X position", var.align_label_with_current_x_position)
      im.Text("Hello!")
      if var.align_label_with_current_x_position[0] then
        im.Unindent(im.GetTreeNodeToLabelSpacing())
      end
      local selection_mask = bit.lshift(1, 2) -- Dumb representation of what may be user-side selection state. You may carry selection state inside or outside your objects in whatever format you see fit.
      im.PushStyleVar1(im.StyleVar_IndentSpacing, im.GetFontSize()*3); -- Increase spacing to differentiate leaves from expanded contents.
      for i = 0, 5 do
        -- Disable the default open on single-click behavior and pass in Selected flag according to our selection state.
        -- ImGuiTreeNodeFlags node_flags = ImGuiTreeNodeFlags_OpenOnArrow | ImGuiTreeNodeFlags_OpenOnDoubleClick | ((selection_mask & (1 << i)) ? ImGuiTreeNodeFlags_Selected : 0)
        local node_flags = bor(im.TreeNodeFlags_OpenOnArrow, im.TreeNodeFlags_OpenOnDoubleClick, (band(selection_mask, blshift(1, i)) > 0) and im.TreeNodeFlags_Selected or 0)
        if i < 3 then
          -- Node
          var.node_open = im.TreeNodeEx3(im.voidPtr, node_flags, "Selectable Node " .. i)
          if im.IsItemClicked() then
            -- TODO: Following line is somehow crashing the game :)
            -- var.node_clicked = i
          end
          if var.node_open then
            im.Text("Blah blah\nBlah Blah")
            im.TreePop()
          end
        else
          -- Leaf: The only reason we have a TreeNode at all is to allow selection of the leaf. Otherwise we can use BulletText() or TreeAdvanceToLabelPos()+Text().\
          node_flags = node_flags or im.TreeNodeFlags_Leaf -- | ImGuiTreeNodeFlags_Bullet
          im.TreeNodeEx3(im.voidPtr, node_flags, "Selectable Leaf " .. i)
          if im.IsItemClicked() then
            -- var.node_clicked = i
          end
        end
      end
      if var.node_clicked == -1 then
      else
        -- Update selection state. Process outside of tree loop to avoid visual inconsistencies during the clicking-frame.
        if im.GetIO().KeyCtrl then
          bit.bxor(selection_mask, bit.lshift(1, var.node_clicked)) -- CTRL+click to toggle
        else -- //if (!(selection_mask & (1 << node_clicked))) // Depending on selection behavior you want, this commented bit preserve selection when clicking on item that is part of the selection
          selection_mask = bit.lshift(1, var.node_clicked) -- Click to single-select
        end
      end
      im.PopStyleVar()
      if align_label_with_current_x_position then
        im.Indent(im.GetTreeNodeToLabelSpacing())
      end
      im.TreePop()
    end
    im.TreePop()
  end
end

local function Widgets_CollapsingHeaders()
  if im.TreeNode1("Collapsing Headers") then
    im.Checkbox("Enable extra group", var.closable_group)
    if im.CollapsingHeader1("Header") then
      im.Text("IsItemHovered: %d", im.IsItemHovered())
      for i = 0, 4 do
        im.Text("Some content ".. i)
      end
    end
    if im.CollapsingHeader2("Header with a close button", var.closable_group) then
      im.Text("IsItemHovered: %d", im.IsItemHovered())
      for i = 0, 5 do
        im.Text("More content " .. i)
      end
    end
    im.TreePop()
  end
end

local function Widgets_Bullets()
  if im.TreeNode1("Bullets") then
    im.BulletText("Bullet point 1")
    im.BulletText("Bullet point 2\nOn multiple lines")
    im.Bullet()
    im.Text("Bullet point 3 (two calls)")
    im.Bullet()
    im.SmallButton("Button")
    im.TreePop()
  end
end

local function Widgets_Text()
  if im.TreeNode1("Text") then
    if (im.TreeNode1("Colored Text")) then
      -- Using shortcut. You can use PushStyleColor()/PopStyleColor() for more flexibility.
      im.TextColored(im.ImVec4(1.0, 0.0, 1.0, 1.0), "Pink")
      im.TextColored(im.ImVec4(1.0, 1.0, 0.0, 1.0), "Yellow")
      im.TextDisabled("Disabled")
      im.SameLine()
      im.ShowHelpMarker("The TextDisabled color is stored in ImGuiStyle.")
      im.TreePop()
    end

    if im.TreeNode1("Word Wrapping") then
      -- Using shortcut. You can use PushTextWrapPos()/PopTextWrapPos() for more flexibility.
      im.TextWrapped("This text should automatically wrap on the edge of the window. The current implementation for text wrapping follows simple rules suitable for English and possibly other languages.")
      im.Spacing()

      im.SliderFloat("Wrap width", var.wrap_width, -20, 600, "%.0f")

      im.Text("Test paragraph 1:")
      local los = im.GetCursorScreenPos()
      im.ImDrawList_AddRectFilled(im.GetWindowDrawList(), im.ImVec2(pos.x + var.wrap_width[0], pos.y), im.ImVec2(pos.x + var.wrap_width[0] + 10, pos.y + im.GetTextLineHeight()), im.GetColorU322( im.ImVec4(1, 0, 1, 1)))
      im.PushTextWrapPos(im.GetCursorPosX() + var.wrap_width[0])
      im.Text("The lazy dog is a good dog. This paragraph is made to fit within %.0f pixels. Testing a 1 character word. The quick brown fox jumps over the lazy dog.", var.wrap_width[0])
      local itemRectMin = im.GetItemRectMin()
      local itemRectMax = im.GetItemRectMax()
      im.ImDrawList_AddRect(im.GetWindowDrawList(), itemRectMin, itemRectMax, im.GetColorU322( im.ImVec4(1, 1, 0, 1)))
      im.PopTextWrapPos()

      im.Text("Test paragraph 2:")
      pos = im.GetCursorScreenPos()
      im.ImDrawList_AddRectFilled(im.GetWindowDrawList(), im.ImVec2(pos.x + var.wrap_width[0], pos.y), im.ImVec2(pos.x + var.wrap_width[0] + 10, pos.y + im.GetTextLineHeight()), im.GetColorU322( im.ImVec4(1, 0, 1, 1)))
      im.PushTextWrapPos(im.GetCursorPosX() + var.wrap_width[0])
      im.Text("aaaaaaaa bbbbbbbb, c cccccccc,dddddddd. d eeeeeeee   ffffffff. gggggggg!hhhhhhhh")
      itemRectMin = im.GetItemRectMin()
      itemRectMax = im.GetItemRectMax()
      im.ImDrawList_AddRect(im.GetWindowDrawList(), itemRectMin, itemRectMax, im.GetColorU322( im.ImVec4(1, 1, 0, 1)))
      im.PopTextWrapPos()

      im.TreePop()
    end

    if im.TreeNode1("UTF-8 Text") then
      -- UTF-8 test with Japanese characters
      -- (Needs a suitable font, try Noto, or Arial Unicode, or M+ fonts. Read misc/fonts/README.txt for details.)
      -- - From C++11 you can use the u8"my text" syntax to encode literal strings as UTF-8
      -- - For earlier compiler, you may be able to encode your sources as UTF-8 (e.g. Visual Studio save your file as 'UTF-8 without signature')
      -- - FOR THIS DEMO FILE ONLY, BECAUSE WE WANT TO SUPPORT OLD COMPILERS, WE ARE *NOT* INCLUDING RAW UTF-8 CHARACTERS IN THIS SOURCE FILE.
      --   Instead we are encoding a few strings with hexadecimal constants. Don't do this in your application!
      --   Please use u8"text in any language" in your application!
      -- Note that characters values are preserved even by InputText() if the font cannot be displayed, so you can safely copy & paste garbled characters into another application.
      im.TextWrapped("CJK text will only appears if the font was loaded with the appropriate CJK character ranges. Call io.Font->LoadFromFileTTF() manually to load extra character ranges. Read misc/fonts/README.txt for details.")
      im.Text("Hiragana: \xe3\x81\x8b\xe3\x81\x8d\xe3\x81\x8f\xe3\x81\x91\xe3\x81\x93 (kakikukeko)"); -- Normally we would use u8"blah blah" with the proper characters directly in the string.
      im.Text("Kanjis: \xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e (nihongo)")

      -- static char buf[32] = u8"NIHONGO"; // <- this is how you would write it with C++11, using real kanjis
      im.InputText("UTF-8 input", var.buf)
      im.TreePop()
    end
    im.TreePop()
  end
end

local function Widgets_Images()
  if im.TreeNode1("Images") then

    -- im.GetIO(var.io)
    -- print(var.io)
  --   im.TextWrapped("Below we are displaying the font texture (which is the only texture we have access to in this demo). Use the 'ImTextureID' type as storage to pass pointers or identifier to your own texture data. Hover the texture for a zoomed view!")
  -- -- Here we are grabbing the font texture because that's the only one we have access to inside the demo code.
  -- -- Remember that ImTextureID is just storage for whatever you want it to be, it is essentially a value that will be passed to the render function inside the ImDrawCmd structure.
  -- -- If you use one of the default imgui_impl_XXXX.cpp renderer, they all have comments at the top of their file to specify what they expect to be stored in ImTextureID.
  -- -- (for example, the imgui_impl_dx11.cpp renderer expect a 'ID3D11ShaderResourceView*' pointer. The imgui_impl_glfw_gl3.cpp renderer expect a GLuint OpenGL texture identifier etc.)
  -- -- If you decided that ImTextureID = MyEngineTexture*, then you can pass your MyEngineTexture* pointers to im.Image(), and gather width/height through your own functions, etc.
  -- -- Using ShowMetricsWindow() as a "debugger" to inspect the draw data that are being passed to your render will help you debug issues if you are confused about this.
  -- -- Consider using the lower-level ImDrawList::AddImage() API, via im.GetWindowDrawList()->AddImage().
  --   local my_tex_id = im.ImGuiIO_Fonts_TexID(var.io)
  --   local my_tex_w = im.ImGuiIO_Fonts_TexWidth(var.io)
  --   local my_tex_h = im.ImGuiIO_Fonts_TexHeight(var.io)

  --   im.Text(string.format("%.0fx%.0f", my_tex_w, my_tex_h))
  --   local pos = im.GetCursorScreenPos()
  --   im.Image(my_tex_id, im.ImVec2(my_tex_w, my_tex_h), im.ImVec2Zero, im.ImVec2One, im.ImColorByRGB(255,255,255,255).Value, im.ImColorByRGB(255,255,255,128).Value)
  --   if im.IsItemHovered() then
  --     im.BeginTooltip()
  --     local region_sz = 32.0
  --     local region_x = im.ImGuiIO_MousePos(var.io).x - pos.x - region_sz * 0.5
  --     -- print(im.ImGuiIO_MousePos(var.io).x)
  --     -- print(pos.x)

  --     if region_x < 0.0 then
  --       region_x = 0.0
  --     elseif region_x > (my_tex_w - region_sz) then
  --       region_x = my_tex_w - region_sz
  --     end
  --     local region_y = im.ImGuiIO_MousePos(var.io).y - pos.y - region_sz * 0.5
  --     if region_y < 0.0 then
  --       region_y = 0.0
  --     elseif region_y > (my_tex_h - region_sz) then
  --       region_y = my_tex_h - region_sz
  --     end
  --     local zoom = 4.0

  --     im.Text(string.format("Min: (%.2f, %.2f)", region_x, region_y))
  --     im.Text(string.format("Max: (%.2f, %.2f)", region_x + region_sz, region_y + region_sz))
  --     local uv0 = im.ImVec2((region_x) / my_tex_w, (region_y) / my_tex_h)
  --     local uv1 = im.ImVec2((region_x + region_sz) / my_tex_w, (region_y + region_sz) / my_tex_h)
  --     im.Image(my_tex_id, im.ImVec2(region_sz * zoom, region_sz * zoom), uv0, uv1, im.ImColorByRGB(255,255,255,255).Value, im.ImColorByRGB(255,255,255,128).Value)
  --     im.EndTooltip()
  --   end
  --   im.TextWrapped("And now some textured buttons..")

  --   for i = 0, 7 do
  --     im.PushID4(i)
  --     local frame_padding = -1 + i -- -1 = uses default padding
  --     if im.ImageButton(my_tex_id, im.ImVec2(32,32), im.ImVec2Zero, im.ImVec2(32.0 / my_tex_w, 32 / my_tex_h), frame_padding, im.ImColorByRGB(0,0,0,255).Value) then
  --       var.pressed_count = var.pressed_count + 1
  --     end
  --     im.PopID()
  --     im.SameLine()
  --   end
  --   im.NewLine()
  --   im.Text(string.format("Pressed %d times.", var.pressed_count))
    im.TreePop()
  end
end

local function Widgets_Combo()
  if im.TreeNode1("Combo") then
    -- Expose flags as checkbox for the demo
    im.CheckboxFlags("ImGuiComboFlags_PopupAlignLeft", var.flags, im.ComboFlags_PopupAlignLeft)
    if im.CheckboxFlags("ImGuiComboFlags_NoArrowButton", var.flags, im.ComboFlags_NoArrowButton) then
      -- flags &=   ~ImGuiComboFlags_NoPreview;     // Clear the other flag, as we cannot combine both
      var.flags[0] = bit.band(var.flags[1], bit.bnot(bit.tobit(im.ComboFlags_NoPreview))) -- Clear the other flag, as we cannot combine both
    end
    if im.CheckboxFlags("ImGuiComboFlags_NoPreview", var.flags, im.ComboFlags_NoPreview) then
      -- flags &= ~ImGuiComboFlags_NoArrowButton; // Clear the other flag, as we cannot combine both
      var.flags[0] = bit.band(tonumber(var.flags[1]), bit.bnot(bit.tobit(im.ComboFlags_NoArrowButton))) -- Clear the other flag, as we cannot combine both
    end


    -- General BeginCombo() API, you have full control over your selection data and display type.
    -- (your selection data could be an index, a pointer to the object, an id for the object, a flag stored in the object itself, etc.)
    -- static const char* item_current = items[0];            // Here our selection is a single pointer stored outside the object.
    if im.BeginCombo("combo 1", var.item_current, var.flags[1]) then -- The second parameter is the label previewed before opening the combo.
      for n = 1, var.itemsLength do
        local is_selected = (var.item_current == var.itemsTbl[n]) and true or false
        if im.Selectable1(var.itemsTbl[n], is_selected) then
          var.item_current = var.itemsTbl[n]
        end
        if is_selected then
          im.SetItemDefaultFocus() -- Set the initial focus when opening the combo (scrolling + for keyboard navigation support in the upcoming navigation branch)
        end
      end
      im.EndCombo()
    end

    -- Simplified one-liner Combo() API, using values packed in a single constant string
    im.Combo2("combo 2 (one-liner)", var.item_current_2, "aaaa\0bbbb\0cccc\0dddd\0eeee\0\0")

    -- Simplified one-liner Combo() using an array of const char*
    im.Combo1("combo 3 (array)", var.item_current_3, var.items)

    -- Simplified one-liner Combo() using an accessor function
    -- TODO
    -- NOT IMPLEMENTED YET
    -- struct FuncHolder { local ItemGetter(void* data, int idx, const char** out_str) { *out_str = ffi.new("bool", ((const char**)data)[idx]) return true; } }
    -- static int item_current_4 = 0
    -- im.Combo("combo 4 (function)", &item_current_4, &FuncHolder::ItemGetter, items, IM_ARRAYSIZE(items))

    im.TreePop()
  end
end

local function Widgets_Selectables()
  if im.TreeNode1("Selectables") then
    -- Selectable() has 2 overloads:
    -- - The one taking "bool selected" as a read-only selection information. When Selectable() has been clicked is returns true and you can alter selection state accordingly.
    -- - The one taking "bool* p_selected" as a read-write selection information (convenient in some cases)
    -- The earlier is more flexible, as in real application your selection may be stored in a different manner (in flags within objects, as an external list, etc).
    if im.TreeNode1("Basic") then
      im.Selectable1("1. I am selectable", var.selection[0])
        im.Selectable1("2. I am selectable", var.selection[1])
        im.Text("3. I am not selectable")
        im.Selectable1("4. I am selectable", var.selection[3])
        if im.Selectable1("5. I am double clickable", var.selection[4], im.SelectableFlags_AllowDoubleClick) then
          if im.IsMouseDoubleClicked(0) then
            -- var.selection[4] = (var.selection[4] == true) and false or true
            if var.selection[4] == true then var.selection[4] = false else var.selection[4] = true end
          end
        end
      im.TreePop()
    end
    if im.TreeNode1("Selection State: Single Selection") then
      for n = 0, 4 do
        local buf = "Object " .. n
        if im.Selectable1(buf, var.selected == n) then
          var.selected = n
        end
      end
      im.TreePop()
    end
    if im.TreeNode1("Selection State: Multiple Selection") then
      im.ShowHelpMarker("Hold CTRL and click to select multiple items.")
      for n = 0, 4 do
        local buf = "Object " .. n
        if im.Selectable1(buf, var.selection_2[n]) then
          if not im.GetIO().KeyCtrl then -- Clear selection when CTRL is not held
            for k = 0, im.GetLengthArrayBool(var.selection_2) - 1 do
              var.selection_2[k] = false
            end
          end
          if var.selection_2[n] == true then var.selection_2[n] = false else var.selection_2[n] = true end
        end
      end
      im.TreePop()
    end
    if im.TreeNode1("Rendering more text into the same line") then
      -- Using the Selectable() override that takes "bool* p_selected" parameter and toggle your booleans automatically.
      if im.Selectable1("main.c", var.selected_2[0]) then if var.selected_2[0] == true then var.selected_2[0]=false else var.selected_2[0]=true end end
      im.SameLine(300)
      im.Text(" 2,345 bytes")

      if im.Selectable1("Hello.cpp", var.selected_2[1]) then if var.selected_2[1] == true then var.selected_2[1]=false else var.selected_2[1]=true end end
      im.SameLine(300)
      im.Text("12,345 bytes")

      if im.Selectable1("Hello.h", var.selected_2[2]) then if var.selected_2[2] == true then var.selected_2[2]=false else var.selected_2[2]=true end end
      im.SameLine(300)
      im.Text(" 2,345 bytes")
      im.TreePop()
    end

    if im.TreeNode1("In columns") then
      im.Columns(3, nil, false)
      for i = 0, 15 do
        local label = "Item " .. i
        if im.Selectable1(label, var.selected_3[i]) then if var.selected_3[i] == true then var.selected_3[i]=false else var.selected_3[i]=true end end
        im.NextColumn()
      end
      im.Columns(1)
      im.TreePop()
    end

    if im.TreeNode1("Grid") then
      for i = 0, 15 do
        im.PushID4(i)
        if im.Selectable1("Sailor", var.selected_4[i], 0, im.ImVec2(50,50)) then
          if var.selected_4[i] == true then var.selected_4[i]=false else var.selected_4[i]=true end
          local x = i % 4
          local y = i / 4
          if x > 0 then var.selected_4[i - 1] = bit.bxor(var.selected_4[i - 1] and 1 or 0, 1) end
          if x < 3 then var.selected_4[i + 1] = bit.bxor(var.selected_4[i - 1] and 1 or 0, 1) end
          if y > 0 then var.selected_4[i - 4] = bit.bxor(var.selected_4[i - 1] and 1 or 0, 1) end
          if y < 3 then var.selected_4[i + 4] = bit.bxor(var.selected_4[i - 1] and 1 or 0, 1) end
        end
        if (i % 4) < 3 then im.SameLine() end
        im.PopID()
      end
      im.TreePop()
    end
    im.TreePop()
  end
end

local function Widgets_Plots()
  if im.TreeNode1("Plots Widgets") then
    im.Checkbox("Animate", var.animate)

    im.PlotLines1("Frame Times", var.arr, im.GetLengthArrayFloat(var.arr))

    -- Create a dummy array of contiguous float values to plot
    -- Tip: If your float aren't contiguous but part of a structure, you can pass a pointer to your first float and the sizeof() of your structure in the Stride parameter.
    if var.animate[0] == false or refresh_time == 0.0 then var.refresh_time = im.GetTime() end
    while var.refresh_time < im.GetTime() do -- Create dummy data at fixed 60 hz rate for the demo
      var.values[var.values_offset] = math.cos(var.phase)
      var.values_offset = (var.values_offset + 1) % (im.GetLengthArrayFloat(var.values) - 1)
      var.phase = var.phase + 0.10 * var.values_offset
      var.refresh_time = var.refresh_time + 1.0 / 60.0
    end

    im.PlotLines1("Lines", var.values, im.GetLengthArrayFloat(var.values), var.values_offset, "avg 0.0", -1.0, 1.0, im.ImVec2(0,80))
    im.PlotHistogram1("Histogram", var.arr, im.GetLengthArrayFloat(var.arr), 0, nil, 0.0, 1.0, im.ImVec2(0,80))

    -- Use functions to generate output
    -- FIXME: This is rather awkward because current plot API only pass in indices. We probably want an API passing floats and user provide sample rate/count.
    --   struct Funcs
    --   {
    --       static float Sin(void*, int i) { return sinf(i * 0.1f); }
    --       static float Saw(void*, int i) { return (i & 1) ? 1.0f : -1.0f; }
    --   }

    im.Separator()
    im.PushItemWidth(100)
    im.Combo2("func", var.func_type, "Sin\0Saw\0")
    im.PopItemWidth()
    im.SameLine()
    im.SliderInt("Sample count", var.display_count, 1, 400)
    -- float (*func)(void*, int) = (func_type == 0) ? Funcs::Sin : Funcs::Saw
    local values = ffi.new("float[?]", var.display_count[0])
    if var.func_type[0] == 0 then
      for i = 0, var.display_count[0] - 1 do
        values[i] = math.sin(i * 0.1)
      end
    else
      for i = 0, var.display_count[0] - 1 do
        values[i] = (i % 2 == 0) and -1.0 or 1.0
      end
    end
    im.PlotLines1("Lines", values, var.display_count[0], 0, nil, -1.0, 1.0, im.ImVec2(0,80))
    im.PlotHistogram1("Lines", values, var.display_count[0], 0, nil, -1.0, 1.0, im.ImVec2(0,80))

    im.Separator()

    -- Animate a simple progress bar
    if var.animate[0] then
      -- print(im.ImGuiIO_DeltaTime())
      var.progress = var.progress + var.progress_dir * 0.4 * im.ImGuiIO_DeltaTime()
      if var.progress >= 1.1 then
        var.progress = 1.1
        var.progress_dir = var.progress_dir * -1.0;
      end
      if var.progress <= -0.1 then
        var.progress = -0.1
        var.progress_dir = var.progress_dir * -1.0
      end
    end

    im.Text("Progress Bar")
    -- Typically we would use ImVec2(-1.0f,0.0f) to use all available width, or ImVec2(width,0.0f) for a specified width. ImVec2(0.0f,0.0f) uses ItemWidth.
    im.ProgressBar(var.progress, im.ImVec2Zero)
    -- im.SameLine(0.0, im.ImGuiStyle_ItemInnerSpacing(c).x)
    var.progress_saturated = (var.progress < 0.0) and 0.0 or ((var.progress > 1.0) and 1.0 or var.progress)
    im.ProgressBar(var.progress, im.ImVec2Zero, string.format( "%d/%d",var.progress_saturated*1753, 1753 ))
    im.TreePop()
  end
end


local function Widgets_FilteredTextInput()
  if im.TreeNode1("Filtered Text Input") then

    im.InputText("default", var.buf1, 64)
    im.InputText("decimal", var.buf2, 64, im.InputTextFlags_CharsDecimal)
    im.InputText("hexadecimal", var.buf3, 64, im.flags(im.InputTextFlags_CharsHexadecimal, im.InputTextFlags_CharsUppercase ))
    im.InputText("uppercase", var.buf4, 64, im.InputTextFlags_CharsUppercase)
    im.InputText("no blank", var.buf5, 64, im.InputTextFlags_CharsNoBlank)

    -- TODO
    -- struct TextFilters { static int FilterImGuiLetters(ImGuiTextEditCallbackData* data) { if (data->EventChar < 256 && strchr("imgui", (char)data->EventChar)) return 0; return 1; } }
    -- static char buf6[64] = ""; im.InputText("\"imgui\" letters", buf6, 64, ImGuiInputTextFlags_CallbackCharFilter, TextFilters::FilterImGuiLetters)

    im.Text("Password input")

    im.InputText("password", var.bufpass, 64, im.flags(im.InputTextFlags_Password, im.InputTextFlags_CharsNoBlank ))
    im.SameLine()
    im.ShowHelpMarker("Display all characters as '*'.\nDisable clipboard cut and copy.\nDisable logging.\n")
    im.InputText("password (clear)", var.bufpass, 64, im.InputTextFlags_CharsNoBlank)

  im.TreePop()
  end
end

local function Widgets_MultiLineTextInput()
  if im.TreeNode1("Multi-line Text Input") then
    im.PushStyleVar2(im.StyleVar_FramePadding, im.ImVec2(0,0))
    im.Checkbox("Read-only", var.read_only)
    im.PopStyleVar()
    local flag
    if var.read_only[0] then flag = im.InputTextFlags_ReadOnly else flag = 0 end
    im.InputTextMultiline("##source", var.text, im.GetLengthArrayCharPtr(var.text), im.ImVec2(-1.0, im.GetTextLineHeight() * 16), im.flags(im.InputTextFlags_AllowTabInput, flag))
    im.TreePop()
  end
end

local function Widgets_ColorPicker()
  if im.TreeNode1("Color/Picker Widgets") then

    im.Checkbox("With Alpha Preview", colorPicker.alpha_preview)
    im.Checkbox("With Half Alpha Preview", colorPicker.alpha_half_preview)
    im.Checkbox("With Options Menu", colorPicker.options_menu)
    im.SameLine()
    im.ShowHelpMarker("Right-click on the individual color widget to show options.")
    im.Checkbox("With HDR", colorPicker.hdr)
    im.SameLine()
    im.ShowHelpMarker("Currently all this does is to lift the 0..1 limits on dragging widgets.")

    local misc_flags = bor(
      colorPicker.hdr[0] and im.ColorEditFlags_HDR or 0,
      colorPicker.alpha_half_preview[0] and im.ColorEditFlags_AlphaPreviewHalf or (colorPicker.alpha_preview[0] and im.ColorEditFlags_AlphaPreview or 0),
      (colorPicker.options_menu[0] and 0 or im.ColorEditFlags_NoOptions)
    )
    im.Text("Color widget:")
    im.SameLine()
    im.ShowHelpMarker("Click on the colored square to open a color picker.\nCTRL+click on individual component to input value.\n")
    im.ColorEdit3("MyColor##1", colorPicker.color2, misc_flags)

    im.Text("Color widget HSV with Alpha:")
    im.ColorEdit4("MyColor##2", colorPicker.color2, bor(im.ColorEditFlags_HSV, misc_flags))

    im.Text("Color widget with Float Display:")
    im.ColorEdit4("MyColor##2f", colorPicker.color2, bor(im.ColorEditFlags_Float, misc_flags))

    im.Text("Color button with Picker:")
    im.SameLine()
    im.ShowHelpMarker("With the ImGuiColorEditFlags_NoInputs flag you can hide all the slider/text inputs.\nWith the ImGuiColorEditFlags_NoLabel flag you can pass a non-empty label which will only be used for the tooltip and picker popup.")
    im.ColorEdit4("MyColor##3", colorPicker.color2, bor(im.ColorEditFlags_NoInputs, im.ColorEditFlags_NoLabel, misc_flags))

    im.Text("Color button with Custom Picker Popup:")

    -- Generate a dummy palette
    if colorPicker.saved_palette_inited[0] == false then
      for n = 0, im.GetLengthArrayImVec4(colorPicker.saved_palette) - 1 do
        colorPicker.saved_palette[n] =  im.ColorConvertHSVtoRGB(n / 31.0, 0.8, 0.8, 1)
      end
    end
    colorPicker.saved_palette_inited[0] = true

    -- TODO: Fix casting from ImVec4 to flaot* and back
    local open_popup = im.ColorButton("MyColor##3b", colorPicker.color, misc_flags)
    im.SameLine()
    open_popup = bor((open_popup and 1 or 0), (im.Button("Palette") and 1 or 0))
    if open_popup == 1 then
      im.OpenPopup("mypicker")
      colorPicker.backup_color = colorPicker.color
    end
    if im.BeginPopup("mypicker") then
      -- FIXME: Adding a drag and drop example here would be perfect!
      im.Text("MY CUSTOM COLOR PICKER WITH AN AMAZING PALETTE!")
      im.Separator()
      im.ColorPicker4("##picker", colorPicker.color2, bor(misc_flags, im.ColorEditFlags_NoSidePreview, im.ColorEditFlags_NoSmallPreview))
      im.SameLine()
      im.BeginGroup()
      im.Text("Current")
      im.ColorButton("##current", colorPicker.color, bor(im.ColorEditFlags_NoPicker, im.ColorEditFlags_AlphaPreviewHalf), im.ImVec2(60,40))
      im.Text("Previous")
      if im.ColorButton("##previous", colorPicker.backup_color, bor(im.ColorEditFlags_NoPicker, im.ColorEditFlags_AlphaPreviewHalf), im.ImVec2(60,40)) then
        colorPicker.color = colorPicker.backup_color
      end
      im.Separator()
      im.Text("Palette")
      for n = 0, im.GetLengthArrayImVec4(colorPicker.saved_palette) - 1 do
        im.PushID4(n)
        if (n % 8) ~= 0 then
          local vec2 = im.ImVec2Ptr()
          --im.GetStyle().ItemSpacing = vec2
          im.SameLine(0.0, vec2[0].y)
        end
        if im.ColorButton("##palette", colorPicker.saved_palette[n], bor(im.ColorEditFlags_NoAlpha, im.ColorEditFlags_NoPicker, im.ColorEditFlags_NoTooltip), im.ImVec2(20,20)) then
          colorPicker.color = im.ImVec4(colorPicker.saved_palette[n].x, colorPicker.saved_palette[n].y, colorPicker.saved_palette[n].z, colorPicker.color.w); -- Preserve alpha!
        end
  --                   if (im.BeginDragDropTarget())
  --                   {
  --                       if (const ImGuiPayload* payload = AcceptDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_3F))
  --                           memcpy((float*)&saved_palette[n], payload->Data, sizeof(float) * 3)
  --                       if (const ImGuiPayload* payload = AcceptDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_4F))
  --                           memcpy((float*)&saved_palette[n], payload->Data, sizeof(float) * 4)
  --                       EndDragDropTarget()
  --                   }

  --                   im.PopID()
      end
      im.EndGroup()
      im.EndPopup()
    end

  --           im.Text("Color button only:")
  --           im.ColorButton("MyColor##3c", *(ImVec4*)&color, misc_flags, ImVec2(80,80))

  --           im.Text("Color picker:")
  --           local alpha = ffi.new("bool", true)
  --           local alpha_bar = ffi.new("bool", true)
  --           local side_preview = ffi.new("bool", true)
  --           local ref_color = ffi.new("bool", false)
  --           static ImVec4 ref_color_v(1.0f,0.0f,1.0f,0.5f)
  --           static int inputs_mode = 2
  --           static int picker_mode = 0
  --           im.Checkbox("With Alpha", &alpha)
  --           im.Checkbox("With Alpha Bar", &alpha_bar)
  --           im.Checkbox("With Side Preview", &side_preview)
  --           if (side_preview)
  --           {
  --               im.SameLine()
  --               im.Checkbox("With Ref Color", &ref_color)
  --               if (ref_color)
  --               {
  --                   im.SameLine()
  --                   im.ColorEdit4("##RefColor", &ref_color_v.x, ImGuiColorEditFlags_NoInputs | misc_flags)
  --               }
  --           }
  --           im.Combo("Inputs Mode", &inputs_mode, "All Inputs\0No Inputs\0RGB Input\0HSV Input\0HEX Input\0")
  --           im.Combo("Picker Mode", &picker_mode, "Auto/Current\0Hue bar + SV rect\0Hue wheel + SV triangle\0")
  --           im.SameLine(); ShowHelpMarker("User can right-click the picker to change mode.")
  --           ImGuiColorEditFlags flags = misc_flags
  --           if (!alpha) flags |= ImGuiColorEditFlags_NoAlpha; // This is by default if you call ColorPicker3() instead of ColorPicker4()
  --           if (alpha_bar) flags |= ImGuiColorEditFlags_AlphaBar
  --           if (!side_preview) flags |= ImGuiColorEditFlags_NoSidePreview
  --           if (picker_mode == 1) flags |= ImGuiColorEditFlags_PickerHueBar
  --           if (picker_mode == 2) flags |= ImGuiColorEditFlags_PickerHueWheel
  --           if (inputs_mode == 1) flags |= ImGuiColorEditFlags_NoInputs
  --           if (inputs_mode == 2) flags |= ImGuiColorEditFlags_RGB
  --           if (inputs_mode == 3) flags |= ImGuiColorEditFlags_HSV
  --           if (inputs_mode == 4) flags |= ImGuiColorEditFlags_HEX
  --           im.ColorPicker4("MyColor##4", (float*)&color, flags, ref_color ? &ref_color_v.x : NULL)

  --           im.Text("Programmatically set defaults:")
  --           im.SameLine(); ShowHelpMarker("SetColorEditOptions() is designed to allow you to set boot-time default.\nWe don't have Push/Pop functions because you can force options on a per-widget basis if needed, and the user can change non-forced ones with the options menu.\nWe don't have a getter to avoid encouraging you to persistently save values that aren't forward-compatible.")
  --           if (im.Button("Default: Uint8 + HSV + Hue Bar"))
  --               im.SetColorEditOptions(ImGuiColorEditFlags_Uint8 | ImGuiColorEditFlags_HSV | ImGuiColorEditFlags_PickerHueBar)
  --           if (im.Button("Default: Float + HDR + Hue Wheel"))
  --               im.SetColorEditOptions(ImGuiColorEditFlags_Float | ImGuiColorEditFlags_HDR | ImGuiColorEditFlags_PickerHueWheel)

    im.TreePop()
  end
end

local function Widgets_RangeWidgets()
  if im.TreeNode1("Range Widgets") then
    im.DragFloatRange2("range", rangeWidgets.beginF, rangeWidgets.endF, 0.25, 0.0, 100.0, "Min: %.1f %%", "Max: %.1f %%")
    im.DragIntRange2("range int (no bounds)", rangeWidgets.beginI, rangeWidgets.endI, 5, 0, 0, "Min: %d units", "Max: %d units")
    im.TreePop()
  end
end

local dataTypes = {}
dataTypes.s32_zero = ffi.new("ImS32[1]", 0)      dataTypes.s32_one = ffi.new("ImS32[1]", 1)     dataTypes.s32_fifty = ffi.new("ImS32[1]", 50)                  dataTypes.s32_min = ffi.new("ImS32[1]", -32767 / 2)                dataTypes.s32_max = ffi.new("ImS32[1]", 32767 / 2)                 dataTypes.s32_hi_a = ffi.new("ImS32[1]", 32767 / 2 - 100)                dataTypes.s32_hi_b = ffi.new("ImS32[1]", 32767 / 2)
dataTypes.u32_zero = ffi.new("ImU32[1]", 0)      dataTypes.u32_one = ffi.new("ImU32[1]", 1)     dataTypes.u32_fifty = ffi.new("ImU32[1]", 50)                  dataTypes.u32_min = ffi.new("ImU32[1]", 0)                         dataTypes.u32_max = ffi.new("ImU32[1]", 65535 / 2)                 dataTypes.u32_hi_a = ffi.new("ImU32[1]", 65535 / 2 - 100)                dataTypes.u32_hi_b = ffi.new("ImU32[1]", 65535 / 2)
dataTypes.s64_zero = ffi.new("ImS64[1]", 0)      dataTypes.s64_one = ffi.new("ImS64[1]", 1)     dataTypes.s64_fifty = ffi.new("ImS64[1]", 50)                  dataTypes.s64_min = ffi.new("ImS64[1]", -9223372036854775807 / 2)  dataTypes.s64_max = ffi.new("ImS64[1]", 9223372036854775807 / 2)   dataTypes.s64_hi_a = ffi.new("ImS64[1]", 9223372036854775807 / 2 - 100)  dataTypes.s64_hi_b = ffi.new("ImS64[1]", 9223372036854775807 / 2)
dataTypes.u64_zero = ffi.new("ImU64[1]", 0)      dataTypes.u64_one = ffi.new("ImU64[1]", 1)     dataTypes.u64_fifty = ffi.new("ImU64[1]", 50)                  dataTypes.u64_min = ffi.new("ImU64[1]", 0)                         dataTypes.u64_max = ffi.new("ImU64[1]", 18446744073709551615 / 2)  dataTypes.u64_hi_a = ffi.new("ImU64[1]", 18446744073709551615 / 2 - 100) dataTypes.u64_hi_b = ffi.new("ImU64[1]", 18446744073709551615 / 2)
dataTypes.f32_zero = ffi.new("float[1]", 0.0)    dataTypes.f32_one = ffi.new("float[1]", 1.0)   dataTypes.f32_lo_a  = ffi.new("float[1]", -10000000000.0)      dataTypes.f32_hi_a = ffi.new("float[1]", 10000000000.0)
dataTypes.f64_zero = ffi.new("double[1]", 0.0)   dataTypes.f64_one = ffi.new("double[1]", 1.0)  dataTypes.f64_lo_a  = ffi.new("double[1]", -1000000000000000)  dataTypes.f64_hi_a = ffi.new("double[1]", 1000000000000000)
-- State
dataTypes.s32_v = ffi.new("ImS32[1]", -1)
dataTypes.u32_v = ffi.new("ImU32[1]", -1)
dataTypes.s64_v = ffi.new("ImS64[1]", -1)
dataTypes.u64_v = ffi.new("ImU64[1]", -1)
dataTypes.f32_v = ffi.new("float[1]", 0.123)
dataTypes.f64_v = ffi.new("double[1]", 90000.01234567890123456789)
dataTypes.drag_speed = 0.2
dataTypes.drag_clamp = im.BoolPtr(false)
dataTypes.inputs_step = ffi.new("bool[1]", true)

local function Widgets_DataTypes()
  if im.TreeNode1("Data Types") then
    -- The DragScalar, InputScalar, SliderScalar functions allow manipulating most common data types: signed/unsigned int/long long and float/double
    -- To avoid polluting the public API with all possible combinations, we use the ImGuiDataType enum to pass the type, and argument-by-values are turned into argument-by-address.
    -- This is the reason the test code below creates local variables to hold "zero" "one" etc. for each types.
    -- In practice, if you frequently use a given type that is not covered by the normal API entry points, you may want to wrap it yourself inside a 1 line function
    -- which can take typed values argument instead of void*, and then pass their address to the generic function. For example:
    --   bool SliderU64(const char *label, u64* value, u64 min = 0, u64 max = 0, const char* format = "%lld") { return SliderScalar(label, ImGuiDataType_U64, value, &min, &max, format); }
    -- Below are helper variables we can take the address of to work-around this:
    -- Note that the SliderScalar function has a maximum usable range of half the natural type maximum, hence the /2 below.

    im.Text("Drags:")
    im.Checkbox("Clamp integers to 0..50", dataTypes.drag_clamp) im.SameLine() im.ShowHelpMarker("As with every widgets in dear imgui, we never modify values unless there is a user interaction.\nYou can override the clamping limits by using CTRL+Click to input a value.")
    im.DragScalar("drag s32",       im.DataType_S32,    dataTypes.s32_v, dataTypes.drag_speed,  dataTypes.drag_clamp[0] and dataTypes.s32_zero or nil,  dataTypes.drag_clamp[0] and dataTypes.s32_fifty or nil)
    im.DragScalar("drag u32",       im.DataType_U32,    dataTypes.u32_v, dataTypes.drag_speed,  dataTypes.drag_clamp[0] and dataTypes.u32_zero or nil,  dataTypes.drag_clamp[0] and dataTypes.u32_fifty or nil, "%u ms")
    im.DragScalar("drag s64",       im.DataType_S64,    dataTypes.s64_v, dataTypes.drag_speed,  dataTypes.drag_clamp[0] and dataTypes.s64_zero or nil,  dataTypes.drag_clamp[0] and dataTypes.s64_fifty or nil)
    im.DragScalar("drag u64",       im.DataType_U64,    dataTypes.u64_v, dataTypes.drag_speed,  dataTypes.drag_clamp[0] and dataTypes.u64_zero or nil,  dataTypes.drag_clamp[0] and dataTypes.u64_fifty or nil)
    im.DragScalar("drag float",     im.DataType_Float,  dataTypes.f32_v, 0.005,                 dataTypes.f32_zero,                                     dataTypes.f32_one,                                      "%f",           1.0)
    im.DragScalar("drag float ^2",  im.DataType_Float,  dataTypes.f32_v, 0.005,                 dataTypes.f32_zero,                                     dataTypes.f32_one,                                      "%f",           2.0)  im.SameLine() im.ShowHelpMarker("You can use the 'power' parameter to increase tweaking precision on one side of the range.")
    im.DragScalar("drag double",    im.DataType_Double, dataTypes.f64_v, 0.0005,                dataTypes.f64_zero,                                     nil,                                                    "%.10f grams",  1.0)
    im.DragScalar("drag double ^2", im.DataType_Double, dataTypes.f64_v, 0.0005,                dataTypes.f64_zero,                                     dataTypes.f64_one,                                      "0 < %.10f < 1", 2.0)

    im.Text("Sliders")
    im.SliderScalar("slider s32 low",     im.DataType_S32,    dataTypes.s32_v, dataTypes.s32_zero, dataTypes.s32_fifty,"%d")
    im.SliderScalar("slider s32 high",    im.DataType_S32,    dataTypes.s32_v, dataTypes.s32_hi_a, dataTypes.s32_hi_b, "%d")
    im.SliderScalar("slider s32 full",    im.DataType_S32,    dataTypes.s32_v, dataTypes.s32_min,  dataTypes.s32_max,  "%d")
    im.SliderScalar("slider u32 low",     im.DataType_U32,    dataTypes.u32_v, dataTypes.u32_zero, dataTypes.u32_fifty,"%u")
    im.SliderScalar("slider u32 high",    im.DataType_U32,    dataTypes.u32_v, dataTypes.u32_hi_a, dataTypes.u32_hi_b, "%u")
    im.SliderScalar("slider u32 full",    im.DataType_U32,    dataTypes.u32_v, dataTypes.u32_min,  dataTypes.u32_max,  "%u")
    im.SliderScalar("slider s64 low",     im.DataType_S64,    dataTypes.s64_v, dataTypes.s64_zero, dataTypes.s64_fifty,"%I64d")
    im.SliderScalar("slider s64 high",    im.DataType_S64,    dataTypes.s64_v, dataTypes.s64_hi_a, dataTypes.s64_hi_b, "%I64d")
    im.SliderScalar("slider s64 full",    im.DataType_S64,    dataTypes.s64_v, dataTypes.s64_min,  dataTypes.s64_max,  "%I64d")
    im.SliderScalar("slider u64 low",     im.DataType_U64,    dataTypes.u64_v, dataTypes.u64_zero, dataTypes.u64_fifty,"%I64u ms")
    im.SliderScalar("slider u64 high",    im.DataType_U64,    dataTypes.u64_v, dataTypes.u64_hi_a, dataTypes.u64_hi_b, "%I64u ms")
    im.SliderScalar("slider u64 full",    im.DataType_U64,    dataTypes.u64_v, dataTypes.u64_min,  dataTypes.u64_max,  "%I64u ms")
    im.SliderScalar("slider float low",   im.DataType_Float,  dataTypes.f32_v, dataTypes.f32_zero, dataTypes.f32_one)
    im.SliderScalar("slider float low^2", im.DataType_Float,  dataTypes.f32_v, dataTypes.f32_zero, dataTypes.f32_one,  "%.10f", 2.0)
    im.SliderScalar("slider float high",  im.DataType_Float,  dataTypes.f32_v, dataTypes.f32_lo_a, dataTypes.f32_hi_a, "%e")
    im.SliderScalar("slider double low",  im.DataType_Double, dataTypes.f64_v, dataTypes.f64_zero, dataTypes.f64_one,  "%.10f grams", 1.0)
    im.SliderScalar("slider double low^2",im.DataType_Double, dataTypes.f64_v, dataTypes.f64_zero, dataTypes.f64_one,  "%.10f", 2.0)
    im.SliderScalar("slider double high", im.DataType_Double, dataTypes.f64_v, dataTypes.f64_lo_a, dataTypes.f64_hi_a, "%e grams", 1.0)


    im.Text("Inputs")
    im.Checkbox("Show step buttons", dataTypes.inputs_step)
    im.InputScalar("input s32",     im.DataType_S32,    dataTypes.s32_v, dataTypes.inputs_step and dataTypes.s32_one or nil, nil, "%d")
    im.InputScalar("input s32 hex", im.DataType_S32,    dataTypes.s32_v, dataTypes.inputs_step and dataTypes.s32_one or nil, nil, "%08X", im.InputTextFlags_CharsHexadecimal)
    im.InputScalar("input u32",     im.DataType_U32,    dataTypes.u32_v, dataTypes.inputs_step and dataTypes.u32_one or nil, nil, "%u")
    im.InputScalar("input u32 hex", im.DataType_U32,    dataTypes.u32_v, dataTypes.inputs_step and dataTypes.u32_one or nil, nil, "%08X", im.InputTextFlags_CharsHexadecimal)
    im.InputScalar("input s64",     im.DataType_S64,    dataTypes.s64_v, dataTypes.inputs_step and dataTypes.s64_one or nil)
    im.InputScalar("input u64",     im.DataType_U64,    dataTypes.u64_v, dataTypes.inputs_step and dataTypes.u64_one or nil)
    im.InputScalar("input float",   im.DataType_Float,  dataTypes.f32_v, dataTypes.inputs_step and dataTypes.f32_one or nil)
    im.InputScalar("input double",  im.DataType_Double, dataTypes.f64_v, dataTypes.inputs_step and dataTypes.f64_one or nil)

    im.TreePop()
  end
end

local multiCom = {}
multiCom.vec4f = ffi.new("float[4]", {0.10, 0.20, 0.30, 0.44})
multiCom.vec4i = ffi.new("int[4]", { 1, 5, 100, 255 })

local function Widgets_MultiComponent()
  if im.TreeNode1("Multi-component Widgets") then

    im.InputFloat2("input float2", multiCom.vec4f)
    im.DragFloat2("drag float2", multiCom.vec4f, 0.01, 0.0, 1.0)
    im.SliderFloat2("slider float2", multiCom.vec4f, 0.0, 1.0)
    im.InputInt2("input int2", multiCom.vec4i)
    im.DragInt2("drag int2", multiCom.vec4i, 1, 0, 255)
    im.SliderInt2("slider int2", multiCom.vec4i, 0, 255)
    im.Spacing()

    im.InputFloat3("input float3", multiCom.vec4f)
    im.DragFloat3("drag float3", multiCom.vec4f, 0.01, 0.0, 1.0)
    im.SliderFloat3("slider float3", multiCom.vec4f, 0.0, 1.0)
    im.InputInt3("input int3", multiCom.vec4i)
    im.DragInt3("drag int3", multiCom.vec4i, 1, 0, 255)
    im.SliderInt3("slider int3", multiCom.vec4i, 0, 255)
    im.Spacing()

    im.InputFloat4("input float4", multiCom.vec4f)
    im.DragFloat4("drag float4", multiCom.vec4f, 0.01, 0.0, 1.0)
    im.SliderFloat4("slider float4", multiCom.vec4f, 0.0, 1.0)
    im.InputInt4("input int4", multiCom.vec4i)
    im.DragInt4("drag int4", multiCom.vec4i, 1, 0, 255)
    im.SliderInt4("slider int4", multiCom.vec4i, 0, 255)

    im.TreePop()
  end
end

local vertSlider = {}
vertSlider.spacing = 4
vertSlider.int_value = im.IntPtr(0)
vertSlider.values = ffi.new('float*[7]')
vertSlider.values[0] = ffi.new('float[1]', 0.0)
vertSlider.values[1] = ffi.new('float[1]', 0.6)
vertSlider.values[2] = ffi.new('float[1]', 0.35)
vertSlider.values[3] = ffi.new('float[1]', 0.9)
vertSlider.values[4] = ffi.new('float[1]', 0.7)
vertSlider.values[5] = ffi.new('float[1]', 0.2)
vertSlider.values[6] = ffi.new('float[1]', 0.0)

vertSlider.values2 = ffi.new("float*[4]")
vertSlider.values2[0] = ffi.new('float[1]', 0.2)
vertSlider.values2[1] = ffi.new('float[1]', 0.8)
vertSlider.values2[2] = ffi.new('float[1]', 0.4)
vertSlider.values2[3] = ffi.new('float[1]', 0.25)

vertSlider.rows = 3
vertSlider.small_slider_size = im.ImVec2Ptr(18, (160.0-(vertSlider.rows-1)*vertSlider.spacing)/vertSlider.rows)

local function Widgets_VerticalSlider()
  if im.TreeNode1("Vertical Sliders") then

    im.PushStyleVar2(im.StyleVar_ItemSpacing, im.ImVec2(vertSlider.spacing, vertSlider.spacing))

    im.VSliderInt("##int", im.ImVec2(18,160), vertSlider.int_value, 0, 5)
    im.SameLine()

    im.PushID1("set1")
    for i = 0, 6 do
      if i > 0 then im.SameLine() end

      im.PushID4(i)
      local col = im.ImVec4Ptr(0,0,0,0)
      col = im.ColorConvertHSVtoRGB(i/7.0, 0.5, 0.5)
      im.PushStyleColor2(im.Col_FrameBg, col)
      col = im.ColorConvertHSVtoRGB(i/7.0, 0.6, 0.5)
      im.PushStyleColor2(im.Col_FrameBgHovered, col)
      col = im.ColorConvertHSVtoRGB(i/7.0, 0.7, 0.5)
      im.PushStyleColor2(im.Col_FrameBgActive, col)
      col = im.ColorConvertHSVtoRGB(i/7.0, 0.9, 0.9)
      im.PushStyleColor2(im.Col_SliderGrab, col)
      im.VSliderFloat("##v", im.ImVec2(18,160), vertSlider.values[i], 0.0, 1.0, "")

      if im.IsItemActive() or im.IsItemHovered() then
        im.SetTooltip("%.3f", vertSlider.values[i][0])
      end
      im.PopStyleColor(4)
      im.PopID()
    end
    im.PopID()

    im.SameLine()
    im.PushID1("set2")

    for nx = 0, 3 do
      if nx > 0 then im.SameLine() end
      im.BeginGroup()
      for ny = 0, vertSlider.rows-1 do
        im.PushID4(nx*vertSlider.rows+ny)
        im.VSliderFloat("##v", vertSlider.small_slider_size, vertSlider.values2[nx], 0.0, 1.0, "")
        if im.IsItemActive() or im.IsItemHovered() then
          im.SetTooltip("%.3f", vertSlider.values2[nx])
        end
        im.PopID()
      end
      im.EndGroup()
    end
    im.PopID()

    im.SameLine()
    im.PushID1("set3")
    for i = 0, 3 do
      if i > 0 then im.SameLine() end
      im.PushID4(i)
      im.PushStyleVar1(im.StyleVar_GrabMinSize, 40)
      im.VSliderFloat("##v", im.ImVec2(40,160), vertSlider.values[i], 0.0, 1.0, "%.2f\nsec")
      im.PopStyleVar()
      im.PopID()
    end
    im.PopID()
    im.PopStyleVar()
    im.TreePop()
  end
end

local focused = {}

focused.item_type = im.IntPtr(1)
focused.b = im.BoolPtr(false)
-- focused.col4f = ffi.new("float[4]", {[0] = 1.0, 0.5, 0.0, 1.0})
focused.col4f = ffi.new('float[1]', 0.5)
focused.col4f2 = ffi.new('float[4]')
focused.col4f2[0] = ffi.new('float', 1.0)
focused.col4f2[1] = ffi.new('float', 0.5)
focused.col4f2[2] = ffi.new('float', 0.0)
focused.col4f2[3] = ffi.new('float', 1.0)
focused.ret = false
focused.items = im.ArrayCharPtrByTbl({ "Apple", "Banana", "Cherry", "Kiwi" })
focused.current = im.IntPtr(1)
focused.embed_all_inside_a_child_window = im.BoolPtr(false)

local function Widgets_Focused()
  if im.TreeNode1("Active, Focused, Hovered & Focused Tests") then
  -- Display the value of IsItemHovered() and other common item state functions. Note that the flags can be combined.
  -- (because BulletText is an item itself and that would affect the output of IsItemHovered() we pass all state in a single call to simplify the code).

    im.RadioButton2("Text", focused.item_type, 0)        im.SameLine()
    im.RadioButton2("Button", focused.item_type, 1)      im.SameLine()
    im.RadioButton2("CheckBox", focused.item_type, 2)    im.SameLine()
    im.RadioButton2("SliderFloat", focused.item_type, 3) im.SameLine()
    im.RadioButton2("ColorEdit4", focused.item_type, 4)  im.SameLine()
    im.RadioButton2("ListBox", focused.item_type, 5)

    if focused.item_type[0] == 0 then im.Text("ITEM: Text") end                                           -- Testing text items with no identifier/interaction
    if focused.item_type[0] == 1 then focused.ret = im.Button("ITEM: Button") end                               -- Testing button
    if focused.item_type[0] == 2 then focused.ret = im.Checkbox("ITEM: CheckBox", focused.b) end                       -- Testing checkbox
    if focused.item_type[0] == 3 then focused.ret = im.SliderFloat("ITEM: SliderFloat", focused.col4f, 0.0, 1.0) end  -- Testing basic item
    if focused.item_type[0] == 4 then focused.ret = im.ColorEdit4("ITEM: ColorEdit4", focused.col4f2) end                     -- Testing multi-component items (IsItemXXX flags are reported merged)
    if focused.item_type[0] == 5 then
      focused.ret = im.ListBox("ITEM: ListBox", focused.current, focused.items, im.ArraySize(focused.items) -1, im.ArraySize(focused.items) - 1);
    end
    im.BulletText(
      [[Return value = %d
      IsItemFocused() = %d
      IsItemHovered() = %d
      IsItemHovered(_AllowWhenBlockedByPopup) = %d
      IsItemHovered(_AllowWhenBlockedByActiveItem) = %d
      IsItemHovered(_AllowWhenOverlapped) = %d
      IsItemHovered(_RectOnly) = %d
      IsItemActive() = %d
      IsItemDeactivated() = %d
      IsItemDeactivatedAfterChange() = %d
      IsItemVisible() = %d]],
      ret,
      im.IsItemFocused(),
      im.IsItemHovered(),
      im.IsItemHovered(im.HoveredFlags_AllowWhenBlockedByPopup),
      im.IsItemHovered(im.HoveredFlags_AllowWhenBlockedByActiveItem),
      im.IsItemHovered(im.HoveredFlags_AllowWhenOverlapped),
      im.IsItemHovered(im.HoveredFlags_RectOnly),
      im.IsItemActive(),
      im.IsItemDeactivated(),
      im.IsItemDeactivatedAfterChange(),
      im.IsItemVisible()
    )

    im.Checkbox("Embed everything inside a child window (for additional testing)", focused.embed_all_inside_a_child_window)
    if focused.embed_all_inside_a_child_window[0] then
      im.BeginChild1("outer_child", im.ImVec2(0, im.GetFontSize() * 20), true)
    end

    -- Testing IsWindowFocused() function with its various flags. Note that the flags can be combined.
    im.BulletText(
      [[IsWindowFocused() = %d
      IsWindowFocused(_ChildWindows) = %d
      IsWindowFocused(_ChildWindows|_RootWindow) = %d
      IsWindowFocused(_RootWindow) = %d
      IsWindowFocused(_AnyWindow) = %d]],
      im.IsWindowFocused(),
      im.IsWindowFocused(im.FocusedFlags_ChildWindows),
      im.IsWindowFocused(bor(im.FocusedFlags_ChildWindows, im.FocusedFlags_RootWindow)),
      im.IsWindowFocused(im.FocusedFlags_RootWindow),
      im.IsWindowFocused(im.FocusedFlags_AnyWindow)
    )

    -- Testing IsWindowHovered() function with its various flags. Note that the flags can be combined.
    im.BulletText(
        [[IsWindowHovered() = %d
        IsWindowHovered(_AllowWhenBlockedByPopup) = %d
        IsWindowHovered(_AllowWhenBlockedByActiveItem) = %d
        IsWindowHovered(_ChildWindows) = %d
        IsWindowHovered(_ChildWindows|_RootWindow) = %d
        IsWindowHovered(_RootWindow) = %d
        IsWindowHovered(_AnyWindow) = %d]],
        im.IsWindowHovered(),
        im.IsWindowHovered(im.HoveredFlags_AllowWhenBlockedByPopup),
        im.IsWindowHovered(im.HoveredFlags_AllowWhenBlockedByActiveItem),
        im.IsWindowHovered(im.HoveredFlags_ChildWindows),
        im.IsWindowHovered(bor(im.HoveredFlags_ChildWindows, im.HoveredFlags_RootWindow)),
        im.IsWindowHovered(im.HoveredFlags_RootWindow),
        im.IsWindowHovered(im.HoveredFlags_AnyWindow)
    )
    im.BeginChild1("child", im.ImVec2(0, 50), true);
    im.Text("This is another child window for testing with the _ChildWindows flag.")
    im.EndChild()
    if focused.embed_all_inside_a_child_window[0] then
      im.EndChild()
    end

    im.TreePop();
  end
end

local childRegions = {}
childRegions.disable_mouse_wheel = im.BoolPtr(false)
childRegions.disable_menu = im.BoolPtr(false)
childRegions.line = im.IntPtr(50)

local function Layout_ChildRegions()
  if im.TreeNode1("Child regions") then

    im.Checkbox("Disable Mouse Wheel", childRegions.disable_mouse_wheel)
    im.Checkbox("Disable Menu", childRegions.disable_menu)

    local goto_line = im.Button("Goto")
    im.SameLine()
    im.PushItemWidth(100)
    goto_line = (bor((goto_line) and 1 or 0, (im.InputInt("##Line", childRegions.line, 0, 0, im.InputTextFlags_EnterReturnsTrue)) and 1 or 0) == 1) and true or false
    im.PopItemWidth()

    -- Child 1: no border, enable horizontal scrollbar
    im.BeginChild1("Child1", im.ImVec2(im.GetWindowContentRegionWidth() * 0.5, 300), false, bor(im.WindowFlags_HorizontalScrollbar, (childRegions.disable_mouse_wheel[0] and im.WindowFlags_NoScrollWithMouse or 0)))
    for i = 0, 99 do
      im.Text(string.format("%04d: scrollable region", i))
      if goto_line and childRegions.line[0] == i then
        im.SetScrollHere()
      end
    end
    if goto_line and childRegions.line[0] >= 100 then
      im.SetScrollHere()
    end
    im.EndChild()

    im.SameLine()

    -- Child 2: rounded border
    im.PushStyleVar1(im.StyleVar_ChildRounding, 5.0)
    im.BeginChild1("Child2", im.ImVec2(0,300), true, bor( (childRegions.disable_mouse_wheel[0] and im.WindowFlags_NoScrollWithMouse or 0) , (childRegions.disable_menu[0] and 0 or im.WindowFlags_MenuBar) ) )
    if not childRegions.disable_menu[0] and im.BeginMenuBar() then
      if im.BeginMenu("Menu") then
        ShowExampleMenuFile()
        im.EndMenu()
      end
      im.EndMenuBar()
    end
    im.Columns(2)
    for i = 0, 99 do

      -- sprintf(buf, "%08x", i*5731)
      im.Button(string.format("%03d", i), im.ImVec2(-1.0, 0.0))
      im.NextColumn()
    end
    im.EndChild()
    im.PopStyleVar()
    im.TreePop()
  end
end

local widgetWidth = {}
widgetWidth.f = im.FloatPtr(0.0)

local function Layout_WidgetsWidth()
  if im.TreeNode1("Widgets Width") then
        im.Text("PushItemWidth(100)")
        im.SameLine(); im.ShowHelpMarker("Fixed width.")
        im.PushItemWidth(100)
        im.DragFloat("float##1", widgetWidth.f)
        im.PopItemWidth()

        im.Text("PushItemWidth(GetWindowWidth() * 0.5f)")
        im.SameLine(); im.ShowHelpMarker("Half of window width.")
        im.PushItemWidth(im.GetWindowWidth() * 0.5)
        im.DragFloat("float##2", widgetWidth.f)
        im.PopItemWidth()

        im.Text("PushItemWidth(GetContentRegionAvailWidth() * 0.5f)")
        im.SameLine(); im.ShowHelpMarker("Half of available width.\n(~ right-cursor_pos)\n(works within a column set)")
        im.PushItemWidth(im.GetContentRegionAvailWidth() * 0.5)
        im.DragFloat("float##3", widgetWidth.f)
        im.PopItemWidth()

        im.Text("PushItemWidth(-100)")
        im.SameLine(); im.ShowHelpMarker("Align to right edge minus 100")
        im.PushItemWidth(-100)
        im.DragFloat("float##4", widgetWidth.f)
        im.PopItemWidth()

        im.Text("PushItemWidth(-1)")
        im.SameLine(); im.ShowHelpMarker("Align to right edge")
        im.PushItemWidth(-1)
        im.DragFloat("float##5", widgetWidth.f)
        im.PopItemWidth()

    im.TreePop()
  end
end

local horLayout = {}
horLayout.c1 = im.BoolPtr(false)
horLayout.c2 = im.BoolPtr(false)
horLayout.c3 = im.BoolPtr(false)
horLayout.c4 = im.BoolPtr(false)
horLayout.f0 = im.FloatPtr(1.0)
horLayout.f1 = im.FloatPtr(2.0)
horLayout.f2 = im.FloatPtr(3.0)
horLayout.items = im.ArrayCharPtrByTbl({ "AAAA", "BBBB", "CCCC", "DDDD" })
horLayout.item = im.IntPtr(-1)
horLayout.selection = im.ArrayIntPtrByTbl({ 0, 1, 2, 3 })
horLayout.sz = im.ImVec2(30,30)

local function Layout_BasicHorizontalLayout()
  if im.TreeNode1("Basic Horizontal Layout") then
        im.TextWrapped("(Use im.SameLine() to keep adding items to the right of the preceding item)")

        --  Text
        im.Text("Two items: Hello"); im.SameLine()
        im.TextColored(im.ImVec4(1,1,0,1), "Sailor")

        -- Adjust spacing
        im.Text("More spacing: Hello"); im.SameLine(0, 20)
        im.TextColored(im.ImVec4(1,1,0,1), "Sailor")

        -- Button
        im.AlignTextToFramePadding()
        im.Text("Normal buttons"); im.SameLine()
        im.Button("Banana"); im.SameLine()
        im.Button("Apple"); im.SameLine()
        im.Button("Corniflower")

        -- Button
        im.Text("Small buttons"); im.SameLine()
        im.SmallButton("Like this one"); im.SameLine()
        im.Text("can fit within a text block.")

        -- Aligned to arbitrary position. Easy/cheap column.
        im.Text("Aligned")
        im.SameLine(150); im.Text("x=150")
        im.SameLine(300); im.Text("x=300")
        im.Text("Aligned")
        im.SameLine(150); im.SmallButton("x=150")
        im.SameLine(300); im.SmallButton("x=300")

        -- Checkbox
        im.Checkbox("My", horLayout.c1); im.SameLine()
        im.Checkbox("Tailor", horLayout.c2); im.SameLine()
        im.Checkbox("Is", horLayout.c3); im.SameLine()
        im.Checkbox("Rich", horLayout.c4)

        -- Various
        im.PushItemWidth(80)


        im.Combo1("Combo", horLayout.item, horLayout.items); im.SameLine()
        im.SliderFloat("X", horLayout.f0, 0.0,5.0); im.SameLine()
        im.SliderFloat("Y", horLayout.f1, 0.0,5.0); im.SameLine()
        im.SliderFloat("Z", horLayout.f2, 0.0,5.0)
        im.PopItemWidth()

        im.PushItemWidth(80)
        im.Text("Lists:")

        for i = 0, 3 do
          if i > 0 then im.SameLine() end
          im.PushID4(i)
          -- im.ListBox("", horLayout.selection, horLayout.items, im.GetLengthArrayInt(horLayout.items) - 1)
          im.PopID()
          -- if (im.IsItemHovered()) im.SetTooltip("ListBox %d hovered", i)
        end
        im.PopItemWidth()

        -- Dummy

        im.Button("A", horLayout.sz); im.SameLine()
        im.Dummy(horLayout.sz); im.SameLine()
        im.Button("B", horLayout.sz)

    im.TreePop()
  end
end

local groups = {}
groups.values = im.TableToArrayFloat({ 0.5, 0.20, 0.80, 0.60, 0.25 })
groups.valuesSize = im.GetLengthArrayFloat(groups.values)
groups.style = ffi.new("ImGuiStyle[1]")

local function Layout_Groups()
  if im.TreeNode1("Groups") then
        im.TextWrapped("(Using im.BeginGroup()/EndGroup() to layout items. BeginGroup() basically locks the horizontal position. EndGroup() bundles the whole group so that you can use functions such as IsItemHovered() on it.)")
        im.BeginGroup()
        -- {
          im.BeginGroup()
          im.Button("AAA")
          im.SameLine()
          im.Button("BBB")
          im.SameLine()
          im.BeginGroup()
          im.Button("CCC")
          im.Button("DDD")
          im.EndGroup()
          im.SameLine()
          im.Button("EEE")
          im.EndGroup()
          if im.IsItemHovered() then im.SetTooltip("First group hovered") end
        -- }
        -- Capture the group size and create widgets using the same size
        local size = im.GetItemRectSize()

        im.PlotHistogram1("##values", groups.values, groups.valuesSize, 0, nil, 0.0, 1.0, size)

        im.GetStyle(groups.style)
        im.Button("ACTION", im.ImVec2((size.x - groups.style[0].ItemSpacing.x) * 0.5,size.y))
        im.SameLine()
        im.Button("REACTION", im.ImVec2((size.x - groups.style[0].ItemSpacing.x) * 0.5,size.y))
        im.EndGroup()
        im.SameLine()

        im.Button("LEVERAGE\nBUZZWORD", size)
        im.SameLine()

        if im.ListBoxHeader1("List", size) then
          im.Selectable1("Selected", true)
          im.Selectable1("Not Selected", false)
          im.ListBoxFooter()
        end
    im.TreePop()
  end
end

local textAlign = {}
textAlign.spacing = im.ImVec2Ptr()
--im.GetStyle().ItemSpacing = textAlign.spacing
textAlign.spacing = textAlign.spacing[0].x

local function Layout_TextBaselineAlignment()
  if im.TreeNode1("Text Baseline Alignment") then
    im.TextWrapped("(This is testing the vertical alignment that occurs on text to keep it at the same baseline as widgets. Lines only composed of text or \"small\" widgets fit in less vertical spaces than lines with normal widgets)")

    im.Text("One\nTwo\nThree"); im.SameLine()
    im.Text("Hello\nWorld"); im.SameLine()
    im.Text("Banana")

    im.Text("Banana"); im.SameLine()
    im.Text("Hello\nWorld"); im.SameLine()
    im.Text("One\nTwo\nThree")

    im.Button("HOP##1"); im.SameLine()
    im.Text("Banana"); im.SameLine()
    im.Text("Hello\nWorld"); im.SameLine()
    im.Text("Banana")

    im.Button("HOP##2"); im.SameLine()
    im.Text("Hello\nWorld"); im.SameLine()
    im.Text("Banana")

    im.Button("TEST##1"); im.SameLine()
    im.Text("TEST"); im.SameLine()
    im.SmallButton("TEST##2")

    im.AlignTextToFramePadding(); -- If your line starts with text, call this to align it to upcoming widgets.
    im.Text("Text aligned to Widget"); im.SameLine()
    im.Button("Widget##1"); im.SameLine()
    im.Text("Widget"); im.SameLine()
    im.SmallButton("Widget##2"); im.SameLine()
    im.Button("Widget##3")

    -- Tree
    im.Button("Button##1")
    im.SameLine(0.0, textAlign.spacing)
    if im.TreeNode1("Node##1") then  -- Dummy tree data
      for i = 0, 5 do
        im.BulletText(string.format("Item %d..", i))
      end
      im.TreePop()
    end

    im.AlignTextToFramePadding() -- Vertically align text node a bit lower so it'll be vertically centered with upcoming widget. Otherwise you can use SmallButton (smaller fit).
    local node_open = im.TreeNode1("Node##2") -- Common mistake to avoid: if we want to SameLine after TreeNode we need to do it before we add child content.
    im.SameLine(0.0, textAlign.spacing)
    im.Button("Button##2")
    if node_open then -- Dummy tree data
      for i = 0, 5 do
        im.BulletText(string.format("Item %d..", i))
      end
      im.TreePop()
    end

    -- Bullet
    im.Button("Button##3")
    im.SameLine(0.0, textAlign.spacing)
    im.BulletText("Bullet text")

    im.AlignTextToFramePadding()
    im.BulletText("Node")
    im.SameLine(0.0, textAlign.spacing)
    im.Button("Button##4")

    im.TreePop()
  end
end

local scrolling = {}
scrolling.track = im.BoolPtr(true)
scrolling.track_line = im.IntPtr(50)
scrolling.scroll_to = false
scrolling.scroll_to_px = im.IntPtr(200)
scrolling.scroll_y = 0
scrolling.scroll_max_y = 0

local function Layout_Scrolling()
  if im.TreeNode1("Scrolling") then
    im.TextWrapped("(Use SetScrollHere() or SetScrollFromPosY() to scroll to a given position.)")

    im.Checkbox("Track", scrolling.track)
    im.PushItemWidth(100)
    im.SameLine(130)
    scrolling.track[0] = (bor(scrolling.track[0] and 1 or 0, (im.DragInt("##line", scrolling.track_line, 0.25, 0, 99, "Line = %d")) and 1 or 0)) and true or false
    scrolling.scroll_to = im.Button("Scroll To Pos")
    im.SameLine(130)
    scrolling.scroll_to = (bor(scrolling.scroll_to and 1 or 0, (im.DragInt("##pos_y", scrolling.scroll_to_px, 1.00, 0, 9999, "Y = %d px")) and 1 or 0)) and true or false
    im.PopItemWidth()
    if scrolling.scroll_to then scrolling.track[0] = false end
    for i = 0, 4 do
        if i > 0 then im.SameLine() end
        im.BeginGroup()
        im.Text("%s", (i == 0) and "Top" or (i == 1) and "25%" or (i == 2) and "Center" or (i == 3) and "75%" or "Bottom")
        -- im.BeginChild(im.GetID((void*)(intptr_t)i), im.ImVec2(im.GetWindowWidth() * 0.17, 200.0), true)
        -- im.BeginChild2(im.GetID3(ffi.cast('void*', ffi.new('intptr_t', i))), im.ImVec2(im.GetWindowWidth() * 0.17, 200.0), true)
        im.BeginChild1("imgui", im.ImVec2(im.GetWindowWidth() * 0.17, 200.0), true)
        if scrolling.scroll_to then
          local cursorStartPos = im.GetCursorStartPos()
          im.SetScrollFromPosY(cursorStartPos.y + im.Float(scrolling.scroll_to_px[0]), im.Float(i * 0.25))
        end
        for line = 0, 99 do
          if scrolling.track[0] and line == scrolling.track_line[0] then
            im.TextColored(ffi.new('ImColor', im.ImVec4(255,255,0, 255)), "Line %d", line)
            im.SetScrollHere(i * 0.25) -- 0.0f:top, 0.5f:center, 1.0f:bottom
          else
            im.Text(string.format("Line %d", line))
          end
        end
        scrolling.scroll_y = im.GetScrollY()
        scrolling.scroll_max_y = im.GetScrollMaxY()
        im.EndChild()
        im.Text("%.0f/%0.f", scroll_y, scroll_max_y)
      im.EndGroup()
    end
    im.TreePop()
  end
end

local horScroll = {}
horScroll.lines = im.IntPtr(7)
horScroll.scroll_x = 0
horScroll.scroll_max_x = 0
horScroll.scroll_x_delta = 0.0

local function Layout_HorizontalScrolling()
  if im.TreeNode1("Horizontal Scrolling") then
    im.Bullet()
    im.TextWrapped("Horizontal scrolling for a window has to be enabled explicitly via the ImGuiWindowFlags_HorizontalScrollbar flag.")
    im.Bullet()
    im.TextWrapped("You may want to explicitly specify content width by calling SetNextWindowContentWidth() before Begin().")
    im.SliderInt("Lines", horScroll.lines, 1, 15)
    im.PushStyleVar1(im.StyleVar_FrameRounding, 3.0)
    im.PushStyleVar2(im.StyleVar_FramePadding, im.ImVec2(2.0, 1.0))
    im.BeginChild1("scrolling", im.ImVec2(0, im.GetFrameHeightWithSpacing()*7 + 30), true, im.WindowFlags_HorizontalScrollbar)
    for line = 0, horScroll.lines[0] - 1 do
      -- Display random stuff (for the sake of this trivial demo we are using basic Button+SameLine. If you want to create your own time line for a real application you may be better off
      -- manipulating the cursor position yourself, aka using SetCursorPos/SetCursorScreenPos to position the widgets yourself. You may also want to use the lower-level ImDrawList API)
      local num_buttons = 10 + ((line%2 == 1) and (line * 9) or (line * 3))
      for n = 0, num_buttons-1 do
        if n > 0 then im.SameLine() end
        im.PushID4(n + line * 1000)
        local label = ( (n%15 ~= 0) and "FizzBuzz" or ((n%3 ~= 0) and "Fizz" or ((n%5 ~=0) and "Buzz" or tostring(n))))
        local hue = n*0.05
        im.PushStyleColor2(im.Col_Button, im.ImVec4(hue, 0.6, 0.6, 1))
        im.PushStyleColor2(im.Col_ButtonHovered, im.ImVec4(hue, 0.7, 0.7, 1))
        im.PushStyleColor2(im.Col_ButtonActive, im.ImVec4(hue, 0.8, 0.8, 1))
        im.Button(label, im.ImVec2(40.0 + math.sin(line + n) * 20.0, 0.0))
        im.PopStyleColor(3)
        im.PopID()
      end
    end
    horScroll.scroll_x = im.GetScrollX()
    horScroll.scroll_max_x = im.GetScrollMaxX()
    im.EndChild()
    im.PopStyleVar(2)
    horScroll.scroll_x_delta = 0.0
    im.SmallButton("<<")
    if im.IsItemActive() then
      horScroll.scroll_x_delta = -im.GetIO().DeltaTime * 1000.0
    end
    im.SameLine()
    im.Text("Scroll from code")
    im.SameLine()
    im.SmallButton(">>")
    if im.IsItemActive() then
      horScroll.scroll_x_delta = im.GetIO().DeltaTime * 1000.0
    end
    im.SameLine()
    im.Text(string.format("%.0f/%.0f", horScroll.scroll_x, horScroll.scroll_max_x))
    if horScroll.scroll_x_delta ~= 0.0 then
      im.BeginChild1("scrolling"); -- Demonstrate a trick: you can use Begin to set yourself in the context of another window (here we are already out of your child window)
      im.SetScrollX(im.GetScrollX() + horScroll.scroll_x_delta)
      im.End()
    end
    im.TreePop()
  end
end

local clipping = {}
clipping.size = im.ImVec2Ptr(100,100)
clipping.offset = im.ImVec2Ptr(50,20)
clipping.pos = im.ImVec2Ptr(0,0)
clipping.col1 = im.GetColorU322( im.ImVec4(0.35, 0.35, 0.468, 1))

local function Layout_Clipping()
  if im.TreeNode1("Clipping") then
    im.TextWrapped("On a per-widget basis we are occasionally clipping text CPU-side if it won't fit in its frame. Otherwise we are doing coarser clipping + passing a scissor rectangle to the renderer. The system is designed to try minimizing both execution and CPU/GPU rendering cost.")
    im.DragFloat2("size", ffi.cast('float*', clipping.size), 0.5, 0.0, 200.0, "%.0f")
    im.TextWrapped("(Click and drag)")
    im.GetCursorScreenPos(clipping.pos)
    clipping.clip_rect = im.ImVec4Ptr(clipping.pos[0].x, clipping.pos[0].y, clipping.pos[0].x + clipping.size[0].x, clipping.pos[0].y + clipping.size[0].y)
    im.InvisibleButton("##dummy", clipping.size)
    if im.IsItemActive() and im.IsMouseDragging(0) then
      local io = im.GetIO()
      clipping.offset[0].x = clipping.offset[0].x + io.MouseDelta.x
      clipping.offset[0].y = clipping.offset[0].y + io.MouseDelta.y
    end
    im.ImDrawList_AddRectFilled(im.GetWindowDrawList(), clipping.pos, im.ImVec2(clipping.pos[0].x + clipping.size[0].x, clipping.pos[0].y + clipping.size[0].y), clipping.col1)
    im.ImDrawList_AddText2(im.GetWindowDrawList(), im.GetFont(), im.GetFontSize()*2.0, im.ImVec2(clipping.pos[0].x + clipping.offset[0].x, clipping.pos[0].y + clipping.offset[0].y), im.GetColorU322( im.ImVec4(1, 1, 1, 1)), "Line 1 hello\nLine 2 clip me!", nil, 0.0, clipping.clip_rect)

    im.TreePop()
  end
end

local popups = {}
popups.selected_fish = -1
popups.names = im.ArrayCharPtrByTbl({ "Bream", "Haddock", "Mackerel", "Pollock", "Tilefish" })
popups.toggles = im.ArrayBoolPtrByTbl({ true, false, false, false, false })

local function Popups_Popups()
  if im.TreeNode1("Popups") then
    im.TextWrapped("When a popup is active, it inhibits interacting with windows that are behind the popup. Clicking outside the popup closes it.")
      -- Simple selection popup
      -- (If you want to show the current selection inside the Button itself, you may want to build a string using the "###" operator to preserve a constant ID with a variable label)
      if im.Button("Select..") then im.OpenPopup("select") end
      im.SameLine()
      im.TextUnformatted((popups.selected_fish == -1) and "<None>" or popups.names[popups.selected_fish])
      if im.BeginPopup("select") then
        im.Text("Aquarium")
        im.Separator()
          for i = 0, im.GetLengthArrayCharPtr(popups.names) - 1 do
            if im.Selectable1(popups.names[i]) then
              popups.selected_fish = i
            end
          end
        im.EndPopup()
      end

      -- Showing a menu with toggles
      if im.Button("Toggle..") then im.OpenPopup("toggle") end
      if im.BeginPopup("toggle") then
        for i = 0, im.GetLengthArrayCharPtr(popups.names) - 1 do
          im.MenuItem2(popups.names[i], "", popups.toggles[i])
        end
        if im.BeginMenu("Sub-menu") then
          im.MenuItem1("Click me")
          im.EndMenu()
        end

        im.Separator()
        im.Text("Tooltip here")
        if im.IsItemHovered() then
          im.SetTooltip("I am a tooltip over a popup")
        end

        if im.Button("Stacked Popup") then
          im.OpenPopup("another popup")
        end

        if im.BeginPopup("another popup") then
          for i = 0, im.GetLengthArrayCharPtr(popups.names) - 1 do
            im.MenuItem2(popups.names[i], "", popups.toggles[i])
          end
          if im.BeginMenu("Sub-menu") then
            im.MenuItem1("Click me")
            im.EndMenu()
          end
          im.EndPopup()
        end
        im.EndPopup()
      end

      if im.Button("Popup Menu..") then im.OpenPopup("FilePopup") end
      if im.BeginPopup("FilePopup") then
        ShowExampleMenuFile()
        im.EndPopup()
      end
    im.TreePop()
  end
end

local contextMenus = {}
contextMenus.value = im.FloatPtr(0.5)
-- contextMenus.name = im.ArrayChar("Label1")
-- contextMenus.name = "Label1"
contextMenus.name = im.ArrayChar(64)
ffi.copy(contextMenus.name, "Label1")
contextMenus.buf = string.format("Button: %s###Button", ffi.string(contextMenus.name)) -- ### operator override ID ignoring the preceding label

local function Popups_ContextMenus()
  if im.TreeNode1("Context menus") then
      -- BeginPopupContextItem() is a helper to provide common/simple popup behavior of essentially doing:
      --    if (IsItemHovered() && IsMouseClicked(0))
      --       OpenPopup(id)
      --    return BeginPopup(id)
      -- For more advanced uses you may want to replicate and cuztomize this code. This the comments inside BeginPopupContextItem() implementation.

      im.Text(string.format("Value = %.3f (<-- right-click here)", contextMenus.value[0]))
      if im.BeginPopupContextItem("item context menu") then
          if im.Selectable1("Set to zero") then contextMenus.value[0] = 0.0 end
          if im.Selectable1("Set to PI") then contextMenus.value[0] = 3.1415 end
          im.PushItemWidth(-1)
          im.DragFloat("##Value", contextMenus.value, 0.1, 0.0, 0.0)
          im.PopItemWidth()
          im.EndPopup()
      end

      im.Button(contextMenus.buf)
      if im.BeginPopupContextItem() then -- When used after an item that has an ID (here the Button), we can skip providing an ID to BeginPopupContextItem().
        im.Text("Edit name:")
        im.InputText("##edit", contextMenus.name)
        if im.Button("Close") then im.CloseCurrentPopup() end
        im.EndPopup()
      end
      im.SameLine()
      im.Text("(<-- right-click here)")
    im.TreePop()
  end
end

local modals = {}
modals.dont_ask_me_next_time = im.BoolPtr(false)
modals.item = im.IntPtr(1)
modals.color = im.ArrayFloatByTbl({ 0.4,0.7,0.0,0.5 })

local function Popups_Modals()
  if im.TreeNode1("Modals") then
    im.TextWrapped("Modal windows are like popups but the user cannot close them by clicking outside the window.")

    if im.Button("Delete..") then im.OpenPopup("Delete?") end
      if im.BeginPopupModal("Delete?", nil, ImGuiWindowFlags_AlwaysAutoResize) then
        im.Text("All those beautiful files will be deleted.\nThis operation cannot be undone!\n\n")
        im.Separator()
        -- static int dummy_i = 0
        -- im.Combo("Combo", &dummy_i, "Delete\0Delete harder\0")
        im.PushStyleVar2(im.StyleVar_FramePadding, im.ImVec2(0,0))
        im.Checkbox("Don't ask me next time", modals.dont_ask_me_next_time)
        im.PopStyleVar()

        if im.Button("OK", im.ImVec2(120,0)) then im.CloseCurrentPopup() end
        im.SetItemDefaultFocus()
        im.SameLine()
        if im.Button("Cancel", im.ImVec2(120,0)) then im.CloseCurrentPopup() end
        im.EndPopup()
      end

      if im.Button("Stacked modals..") then im.OpenPopup("Stacked 1") end
      if im.BeginPopupModal("Stacked 1") then
        im.Text("Hello from Stacked The First\nUsing style.Colors[ImGuiCol_ModalWindowDarkening] for darkening.")
        im.Combo2("Combo", modals.item, "aaaa\0bbbb\0cccc\0dddd\0eeee\0\0")
        im.ColorEdit4("color", modals.color)  -- This is to test behavior of stacked regular popups over a modal
        if im.Button("Add another modal..") then im.OpenPopup("Stacked 2") end
        if im.BeginPopupModal("Stacked 2") then
          im.Text("Hello from Stacked The Second!")
          if im.Button("Close") then im.CloseCurrentPopup() end
          im.EndPopup()
        end

        if im.Button("Close") then im.CloseCurrentPopup() end
        im.EndPopup()
      end

    im.TreePop()
  end
end

local function Popups_Menus()
  if im.TreeNode1("Menus inside a regular window") then
    im.TextWrapped("Below we are testing adding menu items to a regular window. It's rather unusual but should work!")
    im.Separator()
    -- NB: As a quirk in this very specific example, we want to differentiate the parent of this menu from the parent of the various popup menus above.
    -- To do so we are encloding the items in a PushID()/PopID() block to make them two different menusets. If we don't, opening any popup above and hovering our menu here
    -- would open it. This is because once a menu is active, we allow to switch to a sibling menu by just hovering on it, which is the desired behavior for regular menus.
    im.PushID1("foo")
    im.MenuItem1("Menu item", "CTRL+M")
    if im.BeginMenu("Menu inside a regular window") then
      ShowExampleMenuFile()
      im.EndMenu()
    end
    im.PopID()
    im.Separator()
    im.TreePop()
  end
end

local columnsBasic = {}
columnsBasic.names = im.ArrayCharPtrByTbl({ "One", "Two", "Three" })
columnsBasic.paths = im.ArrayCharPtrByTbl({ "/path/one", "/path/two", "/path/three" })
columnsBasic.selected = im.IntPtr(-1)

local function Columns_Basic()
  -- Basic columns
  if im.TreeNode1("Basic") then
    im.Text("Without border:")
    im.Columns(3, "mycolumns3", false) -- 3-ways, no border
    im.Separator()
    for n = 0, 13 do
      local label = string.format("Item %d", n)
      if im.Selectable1(label) then end
      --if (im.Button(label, ImVec2(-1,0))) {}
      im.NextColumn()
    end
    im.Columns(1)
    im.Separator()

    im.Text("With border:")
    im.Columns(4, "mycolumns") -- 4-ways, with border
    im.Separator()
    im.Text("ID")       im.NextColumn()
    im.Text("Name")     im.NextColumn()
    im.Text("Path")     im.NextColumn()
    im.Text("Hovered")  im.NextColumn()
    im.Separator()

    for i = 0, 2 do
      local label = string.format("%04d", i)
      if im.Selectable1(label, columnsBasic.selected[0] == i, im.SelectableFlags_SpanAllColumns) then columnsBasic.selected[0] = i end
      local hovered = im.IsItemHovered()
      im.NextColumn()
      im.Text(columnsBasic.names[i])          im.NextColumn()
      im.Text(columnsBasic.paths[i])          im.NextColumn()
      im.Text(hovered and 'true' or 'false')  im.NextColumn()
    end
    im.Columns(1)
    im.Separator()
    im.TreePop()
  end
end

local mixedItems = {}
mixedItems.foo = im.FloatPtr(1.0)
mixedItems.bar = im.FloatPtr(1.0)

local function Columns_MixedItems()
  -- Create multiple items in a same cell before switching to next column
  if im.TreeNode1("Mixed items") then
    im.Columns(3, "mixed")
    im.Separator()

    im.Text("Hello")
    im.Button("Banana")
    im.NextColumn()

    im.Text("ImGui")
    im.Button("Apple")

    im.InputFloat("red", mixedItems.foo, 0.05, 0, "%.3f")
    im.Text("An extra line here.")
    im.NextColumn()

    im.Text("Sailor")
    im.Button("Corniflower")

    im.InputFloat("blue", mixedItems.bar, 0.05, 0, "%.3f")
    im.NextColumn()

    if im.CollapsingHeader1("Category A") then im.Text("Blah blah blah") end im.NextColumn()
    if im.CollapsingHeader1("Category B") then im.Text("Blah blah blah") end im.NextColumn()
    if im.CollapsingHeader1("Category C") then im.Text("Blah blah blah") end im.NextColumn()
    im.Columns(1)
    im.Separator()

    im.TreePop()
  end
end

local function Columns_WordWrapping()
  -- Word wrapping
  if im.TreeNode1("Word-wrapping") then
    im.Columns(2, "word-wrapping")
    im.Separator()
    im.TextWrapped("The quick brown fox jumps over the lazy dog.")
    im.TextWrapped("Hello Left")
    im.NextColumn()
    im.TextWrapped("The quick brown fox jumps over the lazy dog.")
    im.TextWrapped("Hello Right")
    im.Columns(1)
    im.Separator()
    im.TreePop()
  end
end

local borders = {}
borders.h_borders = im.BoolPtr(true)
borders.v_borders = im.BoolPtr(true)

local function Columns_Borders()
  if im.TreeNode1("Borders") then
    -- NB: Future columns API should allow automatic horizontal borders.
    im.Checkbox("horizontal", borders.h_borders)
    im.SameLine()
    im.Checkbox("vertical", borders.v_borders)
    im.Columns(4, nil, borders.v_borders[0])
    for i = 0, 4*3-1 do
      if borders.h_borders[0] and im.GetColumnIndex() == 0 then im.Separator() end
      im.Text(string.format("%d%d%d", i, i, i))
      im.Text(string.format("Width %.2f\nOffset %.2f", im.GetColumnWidth(), im.GetColumnOffset()))
      im.NextColumn()
    end
    im.Columns(1)
    if borders.h_borders[0] then im.Separator() end
    im.TreePop()
  end
end

local function Columns_VerticalScrolling()
  -- Scrolling columns
  if im.TreeNode1("Vertical Scrolling") then
    im.BeginChild("##header", im.ImVec2(0, im.GetTextLineHeightWithSpacing()+im.GetStyle().ItemSpacing.y))
    im.Columns(3)
    im.Text("ID")    im.NextColumn()
    im.Text("Name")  im.NextColumn()
    im.Text("Path")  im.NextColumn()
    im.Columns(1)
    im.Separator()
    im.EndChild()
    im.BeginChild("##scrollingregion", im.ImVec2(0, 60))
    im.Columns(3)
    for i = 0, 9 do
      im.Text(string.format("%04d", i))               im.NextColumn()
      im.Text("Foobar")                               im.NextColumn()
      im.Text(string.format("/path/foobar/%04d/", i)) im.NextColumn()
    end
    im.Columns(1)
    im.EndChild()
    im.TreePop()
  end
end

local colHorScroll = {}
colHorScroll.ITEMS_COUNT = 2000
colHorScroll.clipper = ffi.new('ImGuiListClipper[1]')
-- ImGuiListClipper clipper(ITEMS_COUNT) -- Also demonstrate using the clipper for large list


local function Columns_HorizontalScrolling()
  if im.TreeNode1("Horizontal Scrolling") then
    im.SetNextWindowContentSize(im.ImVec2(1500.0, 0.0))
    im.BeginChild1("##ScrollingRegion", im.ImVec2(0, im.GetFontSize() * 20), false, im.WindowFlags_HorizontalScrollbar)
    im.Columns(10)

    -- while (clipper.Step())
    -- {
    --     for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++)
    --         for (int j = 0; j < 10; j++)
    --         {
    --             im.Text("Line %d Column %d...", i, j)
    --             im.NextColumn()
    --         }
    -- }
    im.Columns(1)
    im.EndChild()
    im.TreePop()
  end
end

local treeSingleCell = {}
treeSingleCell.node_open = false

local function Columns_TreeWithinSingleCell()
  treeSingleCell.node_open = im.TreeNode1("Tree within single cell")
  im.SameLine()
  im.ShowHelpMarker("NB: Tree node must be poped before ending the cell. There's no storage of state per-cell.")
  if treeSingleCell.node_open then
    im.Columns(2, "tree items")
    im.Separator()
    if im.TreeNode1("Hello") then im.BulletText("Sailor") im.TreePop() end im.NextColumn()
    if im.TreeNode1("Bonjour")then im.BulletText("Marin") im.TreePop() end im.NextColumn()
    im.Columns(1)
    im.Separator()
    im.TreePop()
  end
  im.PopID()
  im.TreePop()
end

local function Menu()
  if im.BeginMenuBar() then
    if im.BeginMenu("Menu") then
      ShowExampleMenuFile()
      im.EndMenu()
    end
    if im.BeginMenu("Examples") then
      if im.MenuItem1("Main menu bar", nil, show_app_main_menu_bar)                    then show_app_main_menu_bar[0] = true end
      if im.MenuItem1("Console", nil, show_app_console)                                then show_app_console[0] = true end
      if im.MenuItem1("Log", nil, show_app_log)                                        then show_app_log[0] = true end
      if im.MenuItem1("Simple layout", nil, show_app_layout)                           then show_app_layout[0] = true end
      if im.MenuItem1("Property editor", nil, show_app_property_editor)                then show_app_property_editor[0] = true end
      if im.MenuItem1("Long text display", nil, show_app_long_text)                    then show_app_long_text[0] = true end
      if im.MenuItem1("Auto-resizing window", nil, show_app_auto_resize)               then show_app_auto_resize[0] = true end
      if im.MenuItem1("Constrained-resizing window", nil, show_app_constrained_resize) then show_app_constrained_resize[0] = true end
      if im.MenuItem1("Simple overlay", nil, show_app_simple_overlay)                  then show_app_simple_overlay[0] = true end
      if im.MenuItem1("Manipulating window titles", nil, show_app_window_titles)       then show_app_window_titles[0] = true end
      if im.MenuItem1("Custom rendering", nil, show_app_custom_rendering)              then show_app_custom_rendering[0] = true end
      im.EndMenu()
    end
    if im.BeginMenu("Help") then
      if im.MenuItem1("Metrics", nil, show_app_metrics)                                then show_app_metrics = true end
      if im.MenuItem1("Style Editor", nil, show_app_style_editor)                      then show_app_style_editor = true end
      if im.MenuItem1("About Dear ImGui", nil, show_app_about)                         then show_app_about = true end
      im.EndMenu()
    end
    im.EndMenuBar()
  end
end

local function Help()
  if im.CollapsingHeader1("Help") then
    im.TextWrapped("This window is being created by the ShowDemoWindow() function. Please refer to the code in imgui_demo.cpp for reference.\n\n");
    im.Text("USER GUIDE:");
    ShowUserGuide();
  end
end

local function WindowOptions()
  if im.CollapsingHeader1("Window options") then
    im.Checkbox("No titlebar", var.no_titlebar)
    im.SameLine(150)
    im.Checkbox("No scrollbar", var.no_scrollbar)
    im.SameLine(300)
    im.Checkbox("No menu", var.no_menu)
    im.Checkbox("No move", var.no_move)
    im.SameLine(150)
    im.Checkbox("No resize", var.no_resize)
    im.SameLine(300)
    im.Checkbox("No collapse", var.no_collapse)
    im.Checkbox("No close", var.no_close)
    -- TODO: no ImGuiWindowFlag for 'no_nav' existent
    -- im.SameLine(150)
    -- im.Checkbox("No nav", var.no_nav)
    if im.TreeNode1("Style") then
      im.ShowStyleEditor()
      im.TreePop()
    end
    if im.TreeNode1("Capture/Logging") then
      im.TextWrapped("The logging API redirects all text output so you can easily capture the content of a window or a block. Tree nodes can be automatically expanded. You can also call im.LogText() to output directly to the log without a visual output.")
      im.LogButtons()
      im.TreePop()
    end
  end
end

local function Widgets()
  if im.CollapsingHeader1("Widgets") then
    Widgets_Basic()
    Widgets_Trees()
    Widgets_CollapsingHeaders()
    Widgets_Bullets()
    Widgets_Text()
    Widgets_Images()
    Widgets_Combo()
    Widgets_Selectables()
    Widgets_FilteredTextInput()
    Widgets_MultiLineTextInput()
    Widgets_Plots()
    Widgets_ColorPicker()
    Widgets_RangeWidgets()
    Widgets_DataTypes()
    Widgets_MultiComponent()
    Widgets_VerticalSlider()
    Widgets_Focused()
  end
end

local function Layout()
  if im.CollapsingHeader1("Layout") then
    Layout_ChildRegions()
    Layout_WidgetsWidth()
    Layout_BasicHorizontalLayout()
    Layout_Groups()
    Layout_TextBaselineAlignment()
    Layout_Scrolling()
    Layout_HorizontalScrolling()
    Layout_Clipping()
  end
end

local function Popups()
  if im.CollapsingHeader1("Popups & Modal windows") then
    Popups_Popups()
    Popups_ContextMenus()
    Popups_Modals()
    Popups_Menus()
  end
end

local function Columns()
  if im.CollapsingHeader1("Columns") then
    Columns_Basic()
    Columns_MixedItems()
    Columns_WordWrapping()
    Columns_Borders()
    -- Columns_VerticalScrolling()
    Columns_HorizontalScrolling()
    Columns_TreeWithinSingleCell()
  end
end

local filtering = {}
filtering.filter = ffi.new('ImGuiTextFilter[1]')
filtering.lines = im.ArrayCharPtrByTbl({ "aaa1.c", "bbb1.c", "ccc1.c", "aaa2.cpp", "bbb2.cpp", "ccc2.cpp", "abc.h", "hello, world" })

local function Filtering()
  if im.CollapsingHeader1("Filtering") then
    im.Text([[Filter usage:\n
                  \"\"         display all lines\n"
                  \"xxx\"      display lines containing \"xxx\"\n"
                  \"xxx,yyy\"  display lines containing \"xxx\" or \"yyy\"\n"
                  \"-xxx\"     hide lines containing \"xxx\"]])
    im.ImGuiTextFilter_Draw(filtering.filter[0])
    for i = 0, im.GetLengthArrayCharPtr(filtering.lines) - 1 do
      -- if (filter.PassFilter(lines[i])) then
        im.BulletText(ffi.string(filtering.lines[i]))
      -- end
    end

  end
end

local function ImGuiDemo()
  if show_app_console[0] == true then                ShowExampleAppMainMenuBar() end
  -- if show_app_console[0] == true then             ShowExampleAppConsole() end
  -- if show_app_log[0] == true then                 ShowExampleAppLog() end
  if show_app_layout[0] == true then                 ShowExampleAppLayout() end
  -- if show_app_property_editor[0] == true then     ShowExampleAppPropertyEditor() end
  -- if show_app_long_text[0] == true then           ShowExampleAppLongText() end
  -- if show_app_auto_resize[0] == true then         ShowExampleAppAutoResize() end
  -- if show_app_constrained_resize[0] == true then  ShowExampleAppConstrainedResize() end
  -- if show_app_simple_overlay[0] == true then      ShowExampleAppSimpleOverlay() end
  if show_app_window_titles[0] == true then          ShowExampleAppWindowTitles() end
  -- if show_app_custom_rendering[0] == true then    ShowExampleAppCustomRendering() end
  if show_app_metrics[0] == true then                im.ShowMetricsWindow() end
  if show_app_about[0] == true then                  ShowAppAbout() end

  if show_app_style_editor[0] == true then
    im.Begin("Style Editor", show_app_style_editor)
    im.ShowStyleEditor()
    im.End()
  end

  -- Demonstrate the various window flags. Typically you would just use the default.
  var.imguiDemoWindowFlags = 0
  if var.no_titlebar[0] then  var.imguiDemoWindowFlags = im.flags(var.imguiDemoWindowFlags, im.WindowFlags_NoTitleBar) end
  if var.no_scrollbar[0] then var.imguiDemoWindowFlags = im.flags(var.imguiDemoWindowFlags, im.WindowFlags_NoScrollbar) end
  if not var.no_menu[0] then  var.imguiDemoWindowFlags = im.flags(var.imguiDemoWindowFlags, im.WindowFlags_MenuBar) end
  if var.no_move[0] then      var.imguiDemoWindowFlags = im.flags(var.imguiDemoWindowFlags, im.WindowFlags_NoMove) end
  if var.no_resize[0] then    var.imguiDemoWindowFlags = im.flags(var.imguiDemoWindowFlags, im.WindowFlags_NoResize) end
  if var.no_collapse[0] then  var.imguiDemoWindowFlags = im.flags(var.imguiDemoWindowFlags, im.WindowFlags_NoCollapse) end
  if var.no_nav[0] then       var.imguiDemoWindowFlags = im.flags(var.imguiDemoWindowFlags, im.WindowFlags_NoNav) end
  if var.no_close[0] then     var.imguiDemoWindowOpen = nil end

  -- We specify a default size in case there's no data in the .ini file. Typically this isn't required! We only do it to make the Demo applications a little more welcoming.
  im.SetNextWindowSize(im.ImVec2(550,680), im.Cond_FirstUseEver)

  -- -- Main body of the Demo window starts here.
  -- if not im.Begin("My ImGui Demo", p_open, var.imguiDemoWindowFlags) then
  --   -- Early out if the window is collapsed, as an optimization.
  --   im.End()
  --   return
  -- end

  im.Begin("BeamNG.drive ImGui Demo", windowOpen, var.imguiDemoWindowFlags)

  im.Text("dear imgui says hello. (" .. imguiVersion .. ")")

  -- Most "big" widgets share a common width settings by default.
  -- ImGui::PushItemWidth(ImGui::GetWindowWidth() * 0.65f);    -- Use 2/3 of the space for widgets and 1/3 for labels (default)
  im.PushItemWidth(im.GetFontSize() * -12);

  -- Menu
  Menu()

  im.Spacing()

  -- Collapsing Headers
  Help()
  WindowOptions()
  Widgets()
  Layout()
  Popups()
  Columns()
  Filtering()

  im.End()

end

local function onEditorGui()
  if windowOpen[0] ~= true then return end

  ImGuiDemo()

  -- this is the C demo: im.ShowDemoWindow()

  -- PlotLinesExample()


  --[[
{
  //IMGUI DEMO

  if (im.CollapsingHeader("Filtering"))
  {
      static ImGuiTextFilter filter
      im.Text("Filter usage:\n"
                  "  \"\"         display all lines\n"
                  "  \"xxx\"      display lines containing \"xxx\"\n"
                  "  \"xxx,yyy\"  display lines containing \"xxx\" or \"yyy\"\n"
                  "  \"-xxx\"     hide lines containing \"xxx\"")
      filter.Draw()
      const char* lines[] = { "aaa1.c", "bbb1.c", "ccc1.c", "aaa2.cpp", "bbb2.cpp", "ccc2.cpp", "abc.h", "hello, world" }
      for (int i = 0; i < IM_ARRAYSIZE(lines); i++)
          if (filter.PassFilter(lines[i]))
              im.BulletText("%s", lines[i])
  }

  if (im.CollapsingHeader("Inputs, Navigation & Focus"))
  {
      ImGuiIO& io = im.GetIO()

      im.Text("WantCaptureMouse: %d", io.WantCaptureMouse)
      im.Text("WantCaptureKeyboard: %d", io.WantCaptureKeyboard)
      im.Text("WantTextInput: %d", io.WantTextInput)
      im.Text("WantSetMousePos: %d", io.WantSetMousePos)
      im.Text("NavActive: %d, NavVisible: %d", io.NavActive, io.NavVisible)

      im.Checkbox("io.MouseDrawCursor", &io.MouseDrawCursor)
      im.SameLine(); ShowHelpMarker("Instruct ImGui to render a mouse cursor for you in software. Note that a mouse cursor rendered via your application GPU rendering path will feel more laggy than hardware cursor, but will be more in sync with your other visuals.\n\nSome desktop applications may use both kinds of cursors (e.g. enable software cursor only when resizing/dragging something).")

      im.CheckboxFlags("io.ConfigFlags: NavEnableGamepad [beta]", (unsigned int *)&io.ConfigFlags, ImGuiConfigFlags_NavEnableGamepad)
      im.CheckboxFlags("io.ConfigFlags: NavEnableKeyboard [beta]", (unsigned int *)&io.ConfigFlags, ImGuiConfigFlags_NavEnableKeyboard)
      im.CheckboxFlags("io.ConfigFlags: NavEnableSetMousePos", (unsigned int *)&io.ConfigFlags, ImGuiConfigFlags_NavEnableSetMousePos)
      im.SameLine(); ShowHelpMarker("Instruct navigation to move the mouse cursor. See comment for ImGuiConfigFlags_NavEnableSetMousePos.")
      im.CheckboxFlags("io.ConfigFlags: NoMouseCursorChange", (unsigned int *)&io.ConfigFlags, ImGuiConfigFlags_NoMouseCursorChange)
      im.SameLine(); ShowHelpMarker("Instruct back-end to not alter mouse cursor shape and visibility.")

      if (im.TreeNode("Keyboard, Mouse & Navigation State"))
      {
          if (im.IsMousePosValid())
              im.Text("Mouse pos: (%g, %g)", io.MousePos.x, io.MousePos.y)
          else
              im.Text("Mouse pos: <INVALID>")
          im.Text("Mouse delta: (%g, %g)", io.MouseDelta.x, io.MouseDelta.y)
          im.Text("Mouse down:");     for (int i = 0; i < IM_ARRAYSIZE(io.MouseDown); i++) if (io.MouseDownDuration[i] >= 0.0f)   { im.SameLine(); im.Text("b%d (%.02f secs)", i, io.MouseDownDuration[i]); }
          im.Text("Mouse clicked:");  for (int i = 0; i < IM_ARRAYSIZE(io.MouseDown); i++) if (im.IsMouseClicked(i))          { im.SameLine(); im.Text("b%d", i); }
          im.Text("Mouse dbl-clicked:"); for (int i = 0; i < IM_ARRAYSIZE(io.MouseDown); i++) if (im.IsMouseDoubleClicked(i)) { im.SameLine(); im.Text("b%d", i); }
          im.Text("Mouse released:"); for (int i = 0; i < IM_ARRAYSIZE(io.MouseDown); i++) if (im.IsMouseReleased(i))         { im.SameLine(); im.Text("b%d", i); }
          im.Text("Mouse wheel: %.1f", io.MouseWheel)

          im.Text("Keys down:");      for (int i = 0; i < IM_ARRAYSIZE(io.KeysDown); i++) if (io.KeysDownDuration[i] >= 0.0f)     { im.SameLine(); im.Text("%d (%.02f secs)", i, io.KeysDownDuration[i]); }
          im.Text("Keys pressed:");   for (int i = 0; i < IM_ARRAYSIZE(io.KeysDown); i++) if (im.IsKeyPressed(i))             { im.SameLine(); im.Text("%d", i); }
          im.Text("Keys release:");   for (int i = 0; i < IM_ARRAYSIZE(io.KeysDown); i++) if (im.IsKeyReleased(i))            { im.SameLine(); im.Text("%d", i); }
          im.Text("Keys mods: %s%s%s%s", io.KeyCtrl ? "CTRL " : "", io.KeyShift ? "SHIFT " : "", io.KeyAlt ? "ALT " : "", io.KeySuper ? "SUPER " : "")

          im.Text("NavInputs down:"); for (int i = 0; i < IM_ARRAYSIZE(io.NavInputs); i++) if (io.NavInputs[i] > 0.0f)                    { im.SameLine(); im.Text("[%d] %.2f", i, io.NavInputs[i]); }
          im.Text("NavInputs pressed:"); for (int i = 0; i < IM_ARRAYSIZE(io.NavInputs); i++) if (io.NavInputsDownDuration[i] == 0.0f)    { im.SameLine(); im.Text("[%d]", i); }
          im.Text("NavInputs duration:"); for (int i = 0; i < IM_ARRAYSIZE(io.NavInputs); i++) if (io.NavInputsDownDuration[i] >= 0.0f)   { im.SameLine(); im.Text("[%d] %.2f", i, io.NavInputsDownDuration[i]); }

          im.Button("Hovering me sets the\nkeyboard capture flag")
          if (im.IsItemHovered())
              im.CaptureKeyboardFromApp(true)
          im.SameLine()
          im.Button("Holding me clears the\nthe keyboard capture flag")
          if (im.IsItemActive())
              im.CaptureKeyboardFromApp(false)

          im.TreePop()
      }

      if (im.TreeNode("Tabbing"))
      {
          im.Text("Use TAB/SHIFT+TAB to cycle through keyboard editable fields.")
          static char buf[32] = "dummy"
          im.InputText("1", buf, IM_ARRAYSIZE(buf))
          im.InputText("2", buf, IM_ARRAYSIZE(buf))
          im.InputText("3", buf, IM_ARRAYSIZE(buf))
          im.PushAllowKeyboardFocus(false)
          im.InputText("4 (tab skip)", buf, IM_ARRAYSIZE(buf))
          //im.SameLine(); ShowHelperMarker("Use im.PushAllowKeyboardFocus(bool)\nto disable tabbing through certain widgets.")
          im.PopAllowKeyboardFocus()
          im.InputText("5", buf, IM_ARRAYSIZE(buf))
          im.TreePop()
      }

      if (im.TreeNode("Focus from code"))
      {
          bool focus_1 = im.Button("Focus on 1"); im.SameLine()
          bool focus_2 = im.Button("Focus on 2"); im.SameLine()
          bool focus_3 = im.Button("Focus on 3")
          int has_focus = 0
          static char buf[128] = "click on a button to set focus"

          if (focus_1) im.SetKeyboardFocusHere()
          im.InputText("1", buf, IM_ARRAYSIZE(buf))
          if (im.IsItemActive()) has_focus = 1

          if (focus_2) im.SetKeyboardFocusHere()
          im.InputText("2", buf, IM_ARRAYSIZE(buf))
          if (im.IsItemActive()) has_focus = 2

          im.PushAllowKeyboardFocus(false)
          if (focus_3) im.SetKeyboardFocusHere()
          im.InputText("3 (tab skip)", buf, IM_ARRAYSIZE(buf))
          if (im.IsItemActive()) has_focus = 3
          im.PopAllowKeyboardFocus()

          if (has_focus)
              im.Text("Item with focus: %d", has_focus)
          else
              im.Text("Item with focus: <none>")

          // Use >= 0 parameter to SetKeyboardFocusHere() to focus an upcoming item
          static float f3[3] = { 0.0f, 0.0f, 0.0f }
          int focus_ahead = -1
          if (im.Button("Focus on X")) focus_ahead = 0; im.SameLine()
          if (im.Button("Focus on Y")) focus_ahead = 1; im.SameLine()
          if (im.Button("Focus on Z")) focus_ahead = 2
          if (focus_ahead != -1) im.SetKeyboardFocusHere(focus_ahead)
          im.SliderFloat3("Float3", &f3[0], 0.0f, 1.0f)

          im.TextWrapped("NB: Cursor & selection are preserved when refocusing last used item in code.")
          im.TreePop()
      }

      if (im.TreeNode("Focused & Hovered Test"))
      {
          local embed_all_inside_a_child_window = ffi.new("bool", false)
          im.Checkbox("Embed everything inside a child window (for additional testing)", &embed_all_inside_a_child_window)
          if (embed_all_inside_a_child_window)
              im.BeginChild("embeddingchild", ImVec2(0, im.GetFontSize() * 25), true)

          // Testing IsWindowFocused() function with its various flags (note that the flags can be combined)
          im.BulletText(
              "IsWindowFocused() = %d\n"
              "IsWindowFocused(_ChildWindows) = %d\n"
              "IsWindowFocused(_ChildWindows|_RootWindow) = %d\n"
              "IsWindowFocused(_RootWindow) = %d\n"
              "IsWindowFocused(_AnyWindow) = %d\n",
              im.IsWindowFocused(),
              im.IsWindowFocused(ImGuiFocusedFlags_ChildWindows),
              im.IsWindowFocused(ImGuiFocusedFlags_ChildWindows | ImGuiFocusedFlags_RootWindow),
              im.IsWindowFocused(ImGuiFocusedFlags_RootWindow),
              im.IsWindowFocused(ImGuiFocusedFlags_AnyWindow))

          // Testing IsWindowHovered() function with its various flags (note that the flags can be combined)
          im.BulletText(
              "IsWindowHovered() = %d\n"
              "IsWindowHovered(_AllowWhenBlockedByPopup) = %d\n"
              "IsWindowHovered(_AllowWhenBlockedByActiveItem) = %d\n"
              "IsWindowHovered(_ChildWindows) = %d\n"
              "IsWindowHovered(_ChildWindows|_RootWindow) = %d\n"
              "IsWindowHovered(_RootWindow) = %d\n"
              "IsWindowHovered(_AnyWindow) = %d\n",
              im.IsWindowHovered(),
              im.IsWindowHovered(ImGuiHoveredFlags_AllowWhenBlockedByPopup),
              im.IsWindowHovered(ImGuiHoveredFlags_AllowWhenBlockedByActiveItem),
              im.IsWindowHovered(ImGuiHoveredFlags_ChildWindows),
              im.IsWindowHovered(ImGuiHoveredFlags_ChildWindows | ImGuiHoveredFlags_RootWindow),
              im.IsWindowHovered(ImGuiHoveredFlags_RootWindow),
              im.IsWindowHovered(ImGuiHoveredFlags_AnyWindow))

          // Testing IsItemHovered() function (because BulletText is an item itself and that would affect the output of IsItemHovered, we pass all lines in a single items to shorten the code)
          im.Button("ITEM")
          im.BulletText(
              "IsItemHovered() = %d\n"
              "IsItemHovered(_AllowWhenBlockedByPopup) = %d\n"
              "IsItemHovered(_AllowWhenBlockedByActiveItem) = %d\n"
              "IsItemHovered(_AllowWhenOverlapped) = %d\n"
              "IsItemhovered(_RectOnly) = %d\n",
              im.IsItemHovered(),
              im.IsItemHovered(ImGuiHoveredFlags_AllowWhenBlockedByPopup),
              im.IsItemHovered(ImGuiHoveredFlags_AllowWhenBlockedByActiveItem),
              im.IsItemHovered(ImGuiHoveredFlags_AllowWhenOverlapped),
              im.IsItemHovered(ImGuiHoveredFlags_RectOnly))

          im.BeginChild("child", ImVec2(0,50), true)
          im.Text("This is another child window for testing IsWindowHovered() flags.")
          im.EndChild()

          if (embed_all_inside_a_child_window)
              EndChild()

          im.TreePop()
      }

      if (im.TreeNode("Dragging"))
      {
          im.TextWrapped("You can use im.GetMouseDragDelta(0) to query for the dragged amount on any widget.")
          for (int button = 0; button < 3; button++)
              im.Text("IsMouseDragging(%d):\n  w/ default threshold: %d,\n  w/ zero threshold: %d\n  w/ large threshold: %d",
                  button, im.IsMouseDragging(button), im.IsMouseDragging(button, 0.0f), im.IsMouseDragging(button, 20.0f))
          im.Button("Drag Me")
          if (im.IsItemActive())
          {
              // Draw a line between the button and the mouse cursor
              ImDrawList* draw_list = im.GetWindowDrawList()
              draw_list->PushClipRectFullScreen()
              draw_list->AddLine(io.MouseClickedPos[0], io.MousePos, im.GetColorU32(ImGuiCol_Button), 4.0f)
              draw_list->PopClipRect()

              // Drag operations gets "unlocked" when the mouse has moved past a certain threshold (the default threshold is stored in io.MouseDragThreshold)
              // You can request a lower or higher threshold using the second parameter of IsMouseDragging(0) and GetMouseDragDelta()
              ImVec2 value_raw = im.GetMouseDragDelta(0, 0.0f)
              ImVec2 value_with_lock_threshold = im.GetMouseDragDelta(0)
              ImVec2 mouse_delta = io.MouseDelta
              im.SameLine(); im.Text("Raw (%.1f, %.1f), WithLockThresold (%.1f, %.1f), MouseDelta (%.1f, %.1f)", value_raw.x, value_raw.y, value_with_lock_threshold.x, value_with_lock_threshold.y, mouse_delta.x, mouse_delta.y)
          }
          im.TreePop()
      }

      if (im.TreeNode("Mouse cursors"))
      {
          const char* mouse_cursors_names[] = { "Arrow", "TextInput", "Move", "ResizeNS", "ResizeEW", "ResizeNESW", "ResizeNWSE" }
          IM_ASSERT(IM_ARRAYSIZE(mouse_cursors_names) == ImGuiMouseCursor_COUNT)

          im.Text("Current mouse cursor = %d: %s", im.GetMouseCursor(), mouse_cursors_names[im.GetMouseCursor()])
          im.Text("Hover to see mouse cursors:")
          im.SameLine(); ShowHelpMarker("Your application can render a different mouse cursor based on what im.GetMouseCursor() returns. If software cursor rendering (io.MouseDrawCursor) is set ImGui will draw the right cursor for you, otherwise your backend needs to handle it.")
          for (int i = 0; i < ImGuiMouseCursor_COUNT; i++)
          {
              char label[32]
              sprintf(label, "Mouse cursor %d: %s", i, mouse_cursors_names[i])
              im.Bullet(); im.Selectable(label, false)
              if (im.IsItemHovered() || im.IsItemFocused())
                  im.SetMouseCursor(i)
          }
          im.TreePop()
      }
  }

  im.End()
  }

  // Demo helper function to select among default colors. See ShowStyleEditor() for more advanced options.
  // Here we use the simplified Combo() api that packs items into a single literal string. Useful for quick combo boxes where the choices are known locally.
  bool im.ShowStyleSelector(const char* label)
  {
  static int style_idx = -1
  if (im.Combo(label, &style_idx, "Classic\0Dark\0Light\0"))
  {
      switch (style_idx)
      {
      case 0: im.StyleColorsClassic(); break
      case 1: im.StyleColorsDark(); break
      case 2: im.StyleColorsLight(); break
      }
      return true
  }
  return false
  }

  // Demo helper function to select among loaded fonts.
  // Here we use the regular BeginCombo()/EndCombo() api which is more the more flexible one.
  void im.ShowFontSelector(const char* label)
  {
  ImGuiIO& io = im.GetIO()
  ImFont* font_current = im.GetFont()
  if (im.BeginCombo(label, font_current->GetDebugName()))
  {
      for (int n = 0; n < io.Fonts->Fonts.Size; n++)
          if (im.Selectable(io.Fonts->Fonts[n]->GetDebugName(), io.Fonts->Fonts[n] == font_current))
              io.FontDefault = io.Fonts->Fonts[n]
      im.EndCombo()
  }
  im.SameLine()
  ShowHelpMarker(
      "- Load additional fonts with io.Fonts->AddFontFromFileTTF().\n"
      "- The font atlas is built when calling io.Fonts->GetTexDataAsXXXX() or io.Fonts->Build().\n"
      "- Read FAQ and documentation in misc/fonts/ for more details.\n"
      "- If you need to add/remove fonts at runtime (e.g. for DPI change), do it before calling NewFrame().")
  }

  void im.ShowStyleEditor(ImGuiStyle* ref)
  {
  // You can pass in a reference ImGuiStyle structure to compare to, revert to and save to (else it compares to an internally stored reference)
  ImGuiStyle& style = im.GetStyle()
  static ImGuiStyle ref_saved_style

  // Default to using internal storage as reference
  local init = ffi.new("bool", true)
  if (init && ref == NULL)
      ref_saved_style = style
  init = false
  if (ref == NULL)
      ref = &ref_saved_style

  im.PushItemWidth(im.GetWindowWidth() * 0.50f)

  if (im.ShowStyleSelector("Colors##Selector"))
      ref_saved_style = style
  im.ShowFontSelector("Fonts##Selector")

  // Simplified Settings
  if (im.SliderFloat("FrameRounding", &style.FrameRounding, 0.0f, 12.0f, "%.0f"))
      style.GrabRounding = style.FrameRounding; // Make GrabRounding always the same value as FrameRounding
  { bool window_border = (style.WindowBorderSize > 0.0f); if (im.Checkbox("WindowBorder", &window_border)) style.WindowBorderSize = window_border ? 1.0f : 0.0f; }
  im.SameLine()
  { bool frame_border = (style.FrameBorderSize > 0.0f); if (im.Checkbox("FrameBorder", &frame_border)) style.FrameBorderSize = frame_border ? 1.0f : 0.0f; }
  im.SameLine()
  { bool popup_border = (style.PopupBorderSize > 0.0f); if (im.Checkbox("PopupBorder", &popup_border)) style.PopupBorderSize = popup_border ? 1.0f : 0.0f; }

  // Save/Revert button
  if (im.Button("Save Ref"))
      *ref = ref_saved_style = style
  im.SameLine()
  if (im.Button("Revert Ref"))
      style = *ref
  im.SameLine()
  ShowHelpMarker("Save/Revert in local non-persistent storage. Default Colors definition are not affected. Use \"Export Colors\" below to save them somewhere.")

  if (im.TreeNode("Rendering"))
  {
      im.Checkbox("Anti-aliased lines", &style.AntiAliasedLines); im.SameLine(); ShowHelpMarker("When disabling anti-aliasing lines, you'll probably want to disable borders in your style as well.")
      im.Checkbox("Anti-aliased fill", &style.AntiAliasedFill)
      im.PushItemWidth(100)
      im.DragFloat("Curve Tessellation Tolerance", &style.CurveTessellationTol, 0.02f, 0.10f, FLT_MAX, NULL, 2.0f)
      if (style.CurveTessellationTol < 0.0f) style.CurveTessellationTol = 0.10f
      im.DragFloat("Global Alpha", &style.Alpha, 0.005f, 0.20f, 1.0f, "%.2f"); // Not exposing zero here so user doesn't "lose" the UI (zero alpha clips all widgets). But application code could have a toggle to switch between zero and non-zero.
      im.PopItemWidth()
      im.TreePop()
  }

  if (im.TreeNode("Settings"))
  {
      im.SliderFloat2("WindowPadding", (float*)&style.WindowPadding, 0.0f, 20.0f, "%.0f")
      im.SliderFloat("PopupRounding", &style.PopupRounding, 0.0f, 16.0f, "%.0f")
      im.SliderFloat2("FramePadding", (float*)&style.FramePadding, 0.0f, 20.0f, "%.0f")
      im.SliderFloat2("ItemSpacing", (float*)&style.ItemSpacing, 0.0f, 20.0f, "%.0f")
      im.SliderFloat2("ItemInnerSpacing", (float*)&style.ItemInnerSpacing, 0.0f, 20.0f, "%.0f")
      im.SliderFloat2("TouchExtraPadding", (float*)&style.TouchExtraPadding, 0.0f, 10.0f, "%.0f")
      im.SliderFloat("IndentSpacing", &style.IndentSpacing, 0.0f, 30.0f, "%.0f")
      im.SliderFloat("ScrollbarSize", &style.ScrollbarSize, 1.0f, 20.0f, "%.0f")
      im.SliderFloat("GrabMinSize", &style.GrabMinSize, 1.0f, 20.0f, "%.0f")
      im.Text("BorderSize")
      im.SliderFloat("WindowBorderSize", &style.WindowBorderSize, 0.0f, 1.0f, "%.0f")
      im.SliderFloat("ChildBorderSize", &style.ChildBorderSize, 0.0f, 1.0f, "%.0f")
      im.SliderFloat("PopupBorderSize", &style.PopupBorderSize, 0.0f, 1.0f, "%.0f")
      im.SliderFloat("FrameBorderSize", &style.FrameBorderSize, 0.0f, 1.0f, "%.0f")
      im.Text("Rounding")
      im.SliderFloat("WindowRounding", &style.WindowRounding, 0.0f, 14.0f, "%.0f")
      im.SliderFloat("ChildRounding", &style.ChildRounding, 0.0f, 16.0f, "%.0f")
      im.SliderFloat("FrameRounding", &style.FrameRounding, 0.0f, 12.0f, "%.0f")
      im.SliderFloat("ScrollbarRounding", &style.ScrollbarRounding, 0.0f, 12.0f, "%.0f")
      im.SliderFloat("GrabRounding", &style.GrabRounding, 0.0f, 12.0f, "%.0f")
      im.Text("Alignment")
      im.SliderFloat2("WindowTitleAlign", (float*)&style.WindowTitleAlign, 0.0f, 1.0f, "%.2f")
      im.SliderFloat2("ButtonTextAlign", (float*)&style.ButtonTextAlign, 0.0f, 1.0f, "%.2f"); im.SameLine(); ShowHelpMarker("Alignment applies when a button is larger than its text content.")
      im.Text("Safe Area Padding"); im.SameLine(); ShowHelpMarker("Adjust if you cannot see the edges of your screen (e.g. on a TV where scaling has not been configured).")
      im.SliderFloat2("DisplaySafeAreaPadding", (float*)&style.DisplaySafeAreaPadding, 0.0f, 30.0f, "%.0f")
      im.TreePop()
  }

  if (im.TreeNode("Colors"))
  {
      static int output_dest = 0
      local output_only_modified = ffi.new("bool", true)
      if (im.Button("Export Unsaved"))
      {
          if (output_dest == 0)
              im.LogToClipboard()
          else
              im.LogToTTY()
          im.LogText("ImVec4* colors = im.GetStyle().Colors;" IM_NEWLINE)
          for (int i = 0; i < ImGuiCol_COUNT; i++)
          {
              const ImVec4& col = style.Colors[i]
              const char* name = im.GetStyleColorName(i)
              if (!output_only_modified || memcmp(&col, &ref->Colors[i], sizeof(ImVec4)) != 0)
                  im.LogText("colors[ImGuiCol_%s]%*s= ImVec4(%.2ff, %.2ff, %.2ff, %.2ff);" IM_NEWLINE, name, 23-(int)strlen(name), "", col.x, col.y, col.z, col.w)
          }
          im.LogFinish()
      }
      im.SameLine(); im.PushItemWidth(120); im.Combo("##output_type", &output_dest, "To Clipboard\0To TTY\0"); im.PopItemWidth()
      im.SameLine(); im.Checkbox("Only Modified Colors", &output_only_modified)

      im.Text("Tip: Left-click on colored square to open color picker,\nRight-click to open edit options menu.")

      static ImGuiTextFilter filter
      filter.Draw("Filter colors", 200)

      static ImGuiColorEditFlags alpha_flags = 0
      im.RadioButton("Opaque", &alpha_flags, 0); im.SameLine()
      im.RadioButton("Alpha", &alpha_flags, ImGuiColorEditFlags_AlphaPreview); im.SameLine()
      im.RadioButton("Both", &alpha_flags, ImGuiColorEditFlags_AlphaPreviewHalf)

      im.BeginChild("#colors", ImVec2(0, 300), true, ImGuiWindowFlags_AlwaysVerticalScrollbar | ImGuiWindowFlags_AlwaysHorizontalScrollbar | ImGuiWindowFlags_NavFlattened)
      im.PushItemWidth(-160)
      for (int i = 0; i < ImGuiCol_COUNT; i++)
      {
          const char* name = im.GetStyleColorName(i)
          if (!filter.PassFilter(name))
              continue
          im.PushID(i)
          im.ColorEdit4("##color", (float*)&style.Colors[i], ImGuiColorEditFlags_AlphaBar | alpha_flags)
          if (memcmp(&style.Colors[i], &ref->Colors[i], sizeof(ImVec4)) != 0)
          {
              // Tips: in a real user application, you may want to merge and use an icon font into the main font, so instead of "Save"/"Revert" you'd use icons.
              // Read the FAQ and misc/fonts/README.txt about using icon fonts. It's really easy and super convenient!
              im.SameLine(0.0f, style.ItemInnerSpacing.x); if (im.Button("Save")) ref->Colors[i] = style.Colors[i]
              im.SameLine(0.0f, style.ItemInnerSpacing.x); if (im.Button("Revert")) style.Colors[i] = ref->Colors[i]
          }
          im.SameLine(0.0f, style.ItemInnerSpacing.x)
          im.TextUnformatted(name)
          im.PopID()
      }
      im.PopItemWidth()
      im.EndChild()

      im.TreePop()
  }

  bool fonts_opened = im.TreeNode("Fonts", "Fonts (%d)", im.GetIO().Fonts->Fonts.Size)
  if (fonts_opened)
  {
      ImFontAtlas* atlas = im.GetIO().Fonts
      if (im.TreeNode("Atlas texture", "Atlas texture (%dx%d pixels)", atlas->TexWidth, atlas->TexHeight))
      {
          im.Image(atlas->TexID, ImVec2((float)atlas->TexWidth, (float)atlas->TexHeight), ImVec2(0,0), ImVec2(1,1), ImColor(255,255,255,255), ImColor(255,255,255,128))
          im.TreePop()
      }
      im.PushItemWidth(100)
      for (int i = 0; i < atlas->Fonts.Size; i++)
      {
          ImFont* font = atlas->Fonts[i]
          im.PushID(font)
          bool font_details_opened = im.TreeNode(font, "Font %d: \'%s\', %.2f px, %d glyphs", i, font->ConfigData ? font->ConfigData[0].Name : "", font->FontSize, font->Glyphs.Size)
          im.SameLine(); if (im.SmallButton("Set as default")) im.GetIO().FontDefault = font
          if (font_details_opened)
          {
              im.PushFont(font)
              im.Text("The quick brown fox jumps over the lazy dog")
              im.PopFont()
              im.DragFloat("Font scale", &font->Scale, 0.005f, 0.3f, 2.0f, "%.1f");   // Scale only this font
              im.InputFloat("Font offset", &font->DisplayOffset.y, 1, 1, 0)
              im.SameLine(); ShowHelpMarker("Note than the default embedded font is NOT meant to be scaled.\n\nFont are currently rendered into bitmaps at a given size at the time of building the atlas. You may oversample them to get some flexibility with scaling. You can also render at multiple sizes and select which one to use at runtime.\n\n(Glimmer of hope: the atlas system should hopefully be rewritten in the future to make scaling more natural and automatic.)")
              im.Text("Ascent: %f, Descent: %f, Height: %f", font->Ascent, font->Descent, font->Ascent - font->Descent)
              im.Text("Fallback character: '%c' (%d)", font->FallbackChar, font->FallbackChar)
              im.Text("Texture surface: %d pixels (approx) ~ %dx%d", font->MetricsTotalSurface, (int)sqrtf((float)font->MetricsTotalSurface), (int)sqrtf((float)font->MetricsTotalSurface))
              for (int config_i = 0; config_i < font->ConfigDataCount; config_i++)
                  if (ImFontConfig* cfg = &font->ConfigData[config_i])
                      im.BulletText("Input %d: \'%s\', Oversample: (%d,%d), PixelSnapH: %d", config_i, cfg->Name, cfg->OversampleH, cfg->OversampleV, cfg->PixelSnapH)
              if (im.TreeNode("Glyphs", "Glyphs (%d)", font->Glyphs.Size))
              {
                  // Display all glyphs of the fonts in separate pages of 256 characters
                  for (int base = 0; base < 0x10000; base += 256)
                  {
                      int count = 0
                      for (int n = 0; n < 256; n++)
                          count += font->FindGlyphNoFallback((ImWchar)(base + n)) ? 1 : 0
                      if (count > 0 && im.TreeNode((void*)(intptr_t)base, "U+%04X..U+%04X (%d %s)", base, base+255, count, count > 1 ? "glyphs" : "glyph"))
                      {
                          float cell_size = font->FontSize * 1
                          float cell_spacing = style.ItemSpacing.y
                          ImVec2 base_pos = im.GetCursorScreenPos()
                          ImDrawList* draw_list = im.GetWindowDrawList()
                          for (int n = 0; n < 256; n++)
                          {
                              ImVec2 cell_p1(base_pos.x + (n % 16) * (cell_size + cell_spacing), base_pos.y + (n / 16) * (cell_size + cell_spacing))
                              ImVec2 cell_p2(cell_p1.x + cell_size, cell_p1.y + cell_size)
                              const ImFontGlyph* glyph = font->FindGlyphNoFallback((ImWchar)(base+n))
                              draw_list->AddRect(cell_p1, cell_p2, glyph ? IM_COL32(255,255,255,100) : IM_COL32(255,255,255,50))
                              if (glyph)
                                  font->RenderChar(draw_list, cell_size, cell_p1, im.GetColorU32(ImGuiCol_Text), (ImWchar)(base+n)); // We use ImFont::RenderChar as a shortcut because we don't have UTF-8 conversion functions available to generate a string.
                              if (glyph && im.IsMouseHoveringRect(cell_p1, cell_p2))
                              {
                                  im.BeginTooltip()
                                  im.Text("Codepoint: U+%04X", base+n)
                                  im.Separator()
                                  im.Text("AdvanceX: %.1f", glyph->AdvanceX)
                                  im.Text("Pos: (%.2f,%.2f)->(%.2f,%.2f)", glyph->X0, glyph->Y0, glyph->X1, glyph->Y1)
                                  im.Text("UV: (%.3f,%.3f)->(%.3f,%.3f)", glyph->U0, glyph->V0, glyph->U1, glyph->V1)
                                  im.EndTooltip()
                              }
                          }
                          im.Dummy(ImVec2((cell_size + cell_spacing) * 16, (cell_size + cell_spacing) * 16))
                          im.TreePop()
                      }
                  }
                  im.TreePop()
              }
              im.TreePop()
          }
          im.PopID()
      }
      static float window_scale = 1.0f
      im.DragFloat("this window scale", &window_scale, 0.005f, 0.3f, 2.0f, "%.1f");              // scale only this window
      im.DragFloat("global scale", &im.GetIO().FontGlobalScale, 0.005f, 0.3f, 2.0f, "%.1f"); // scale everything
      im.PopItemWidth()
      im.SetWindowFontScale(window_scale)
      im.TreePop()
  }

  im.PopItemWidth()
  }




  // Demonstrate creating a window which gets auto-resized according to its content.
  static void ShowExampleAppAutoResize(bool* p_open)
  {
  if (!im.Begin("Example: Auto-resizing window", p_open, ImGuiWindowFlags_AlwaysAutoResize))
  {
      im.End()
      return
  }

  static int lines = 10
  im.Text("Window will resize every-frame to the size of its content.\nNote that you probably don't want to query the window size to\noutput your content because that would create a feedback loop.")
  im.SliderInt("Number of lines", &lines, 1, 20)
  for (int i = 0; i < lines; i++)
      im.Text("%*sThis is line %d", i*4, "", i); // Pad with space to extend size horizontally
  im.End()
  }

  // Demonstrate creating a window with custom resize constraints.
  static void ShowExampleAppConstrainedResize(bool* p_open)
  {
  struct CustomConstraints // Helper functions to demonstrate programmatic constraints
  {
      static void Square(ImGuiSizeCallbackData* data) { data->DesiredSize = ImVec2(IM_MAX(data->DesiredSize.x, data->DesiredSize.y), IM_MAX(data->DesiredSize.x, data->DesiredSize.y)); }
      static void Step(ImGuiSizeCallbackData* data)   { float step = (float)(int)(intptr_t)data->UserData; data->DesiredSize = ImVec2((int)(data->DesiredSize.x / step + 0.5f) * step, (int)(data->DesiredSize.y / step + 0.5f) * step); }
  }

  local auto_resize = ffi.new("bool", false)
  static int type = 0
  static int display_lines = 10
  if (type == 0) im.SetNextWindowSizeConstraints(ImVec2(-1, 0),    ImVec2(-1, FLT_MAX));      // Vertical only
  if (type == 1) im.SetNextWindowSizeConstraints(ImVec2(0, -1),    ImVec2(FLT_MAX, -1));      // Horizontal only
  if (type == 2) im.SetNextWindowSizeConstraints(ImVec2(100, 100), ImVec2(FLT_MAX, FLT_MAX)); // Width > 100, Height > 100
  if (type == 3) im.SetNextWindowSizeConstraints(ImVec2(400, -1),  ImVec2(500, -1));          // Width 400-500
  if (type == 4) im.SetNextWindowSizeConstraints(ImVec2(-1, 400),  ImVec2(-1, 500));          // Height 400-500
  if (type == 5) im.SetNextWindowSizeConstraints(ImVec2(0, 0),     ImVec2(FLT_MAX, FLT_MAX), CustomConstraints::Square);          // Always Square
  if (type == 6) im.SetNextWindowSizeConstraints(ImVec2(0, 0),     ImVec2(FLT_MAX, FLT_MAX), CustomConstraints::Step, (void*)100);// Fixed Step

  ImGuiWindowFlags flags = auto_resize ? ImGuiWindowFlags_AlwaysAutoResize : 0
  if (im.Begin("Example: Constrained Resize", p_open, flags))
  {
      const char* desc[] =
      {
          "Resize vertical only",
          "Resize horizontal only",
          "Width > 100, Height > 100",
          "Width 400-500",
          "Height 400-500",
          "Custom: Always Square",
          "Custom: Fixed Steps (100)",
      }
      if (im.Button("200x200")) { im.SetWindowSize(ImVec2(200, 200)); } im.SameLine()
      if (im.Button("500x500")) { im.SetWindowSize(ImVec2(500, 500)); } im.SameLine()
      if (im.Button("800x200")) { im.SetWindowSize(ImVec2(800, 200)); }
      im.PushItemWidth(200)
      im.Combo("Constraint", &type, desc, IM_ARRAYSIZE(desc))
      im.DragInt("Lines", &display_lines, 0.2f, 1, 100)
      im.PopItemWidth()
      im.Checkbox("Auto-resize", &auto_resize)
      for (int i = 0; i < display_lines; i++)
          im.Text("%*sHello, sailor! Making this line long enough for the example.", i * 4, "")
  }
  im.End()
  }

  // Demonstrate creating a simple static window with no decoration + a context-menu to choose which corner of the screen to use.
  static void ShowExampleAppSimpleOverlay(bool* p_open)
  {
  const float DISTANCE = 10.0f
  static int corner = 0
  ImVec2 window_pos = ImVec2((corner & 1) ? im.GetIO().DisplaySize.x - DISTANCE : DISTANCE, (corner & 2) ? im.GetIO().DisplaySize.y - DISTANCE : DISTANCE)
  ImVec2 window_pos_pivot = ImVec2((corner & 1) ? 1.0f : 0.0f, (corner & 2) ? 1.0f : 0.0f)
  if (corner != -1)
      im.SetNextWindowPos(window_pos, ImGuiCond_Always, window_pos_pivot)
  im.SetNextWindowBgAlpha(0.3f); // Transparent background
  if (im.Begin("Example: Simple Overlay", p_open, (corner != -1 ? ImGuiWindowFlags_NoMove : 0) | ImGuiWindowFlags_NoTitleBar|ImGuiWindowFlags_NoResize|ImGuiWindowFlags_AlwaysAutoResize|ImGuiWindowFlags_NoSavedSettings|ImGuiWindowFlags_NoFocusOnAppearing|ImGuiWindowFlags_NoNav))
  {
      im.Text("Simple overlay\n" "in the corner of the screen.\n" "(right-click to change position)")
      im.Separator()
      if (im.IsMousePosValid())
          im.Text("Mouse Position: (%.1f,%.1f)", im.GetIO().MousePos.x, im.GetIO().MousePos.y)
      else
          im.Text("Mouse Position: <invalid>")
      if (im.BeginPopupContextWindow())
      {
          if (im.MenuItem("Custom", NULL, corner == -1)) corner = -1
          if (im.MenuItem("Top-left", NULL, corner == 0)) corner = 0
          if (im.MenuItem("Top-right", NULL, corner == 1)) corner = 1
          if (im.MenuItem("Bottom-left", NULL, corner == 2)) corner = 2
          if (im.MenuItem("Bottom-right", NULL, corner == 3)) corner = 3
          if (p_open && im.MenuItem("Close")) *p_open = false
          im.EndPopup()
      }
      im.End()
  }
  }


  // Demonstrate using the low-level ImDrawList to draw custom shapes.
  static void ShowExampleAppCustomRendering(bool* p_open)
  {
  im.SetNextWindowSize(ImVec2(350,560), ImGuiCond_FirstUseEver)
  if (!im.Begin("Example: Custom rendering", p_open))
  {
      im.End()
      return
  }

  // Tip: If you do a lot of custom rendering, you probably want to use your own geometrical types and benefit of overloaded operators, etc.
  // Define IM_VEC2_CLASS_EXTRA in imconfig.h to create implicit conversions between your types and ImVec2/ImVec4.
  // ImGui defines overloaded operators but they are internal to imgui.cpp and not exposed outside (to avoid messing with your types)
  // In this example we are not using the maths operators!
  ImDrawList* draw_list = im.GetWindowDrawList()

  // Primitives
  im.Text("Primitives")
  static float sz = 36.0f
  static float thickness = 4.0f
  static ImVec4 col = ImVec4(1.0f,1.0f,0.4f,1.0f)
  im.DragFloat("Size", &sz, 0.2f, 2.0f, 72.0f, "%.0f")
  im.DragFloat("Thickness", &thickness, 0.05f, 1.0f, 8.0f, "%.02f")
  im.ColorEdit3("Color", &col.x)
  {
      const ImVec2 p = im.GetCursorScreenPos()
      const ImU32 col32 = ImColor(col)
      float x = p.x + 4.0f, y = p.y + 4.0f, spacing = 8.0f
      for (int n = 0; n < 2; n++)
      {
          float curr_thickness = (n == 0) ? 1.0f : thickness
          draw_list->AddCircle(ImVec2(x+sz*0.5f, y+sz*0.5f), sz*0.5f, col32, 20, curr_thickness); x += sz+spacing
          draw_list->AddRect(ImVec2(x, y), ImVec2(x+sz, y+sz), col32, 0.0f, ImDrawCornerFlags_All, curr_thickness); x += sz+spacing
          draw_list->AddRect(ImVec2(x, y), ImVec2(x+sz, y+sz), col32, 10.0f, ImDrawCornerFlags_All, curr_thickness); x += sz+spacing
          draw_list->AddRect(ImVec2(x, y), ImVec2(x+sz, y+sz), col32, 10.0f, ImDrawCornerFlags_TopLeft|ImDrawCornerFlags_BotRight, curr_thickness); x += sz+spacing
          draw_list->AddTriangle(ImVec2(x+sz*0.5f, y), ImVec2(x+sz,y+sz-0.5f), ImVec2(x,y+sz-0.5f), col32, curr_thickness); x += sz+spacing
          draw_list->AddLine(ImVec2(x, y), ImVec2(x+sz, y   ), col32, curr_thickness); x += sz+spacing; // Horizontal line (note: drawing a filled rectangle will be faster!)
          draw_list->AddLine(ImVec2(x, y), ImVec2(x,    y+sz), col32, curr_thickness); x += spacing;    // Vertical line (note: drawing a filled rectangle will be faster!)
          draw_list->AddLine(ImVec2(x, y), ImVec2(x+sz, y+sz), col32, curr_thickness); x += sz+spacing; // Diagonal line
          draw_list->AddBezierCurve(ImVec2(x, y), ImVec2(x+sz*1.3f,y+sz*0.3f), ImVec2(x+sz-sz*1.3f,y+sz-sz*0.3f), ImVec2(x+sz, y+sz), col32, curr_thickness)
          x = p.x + 4
          y += sz+spacing
      }
      draw_list->AddCircleFilled(ImVec2(x+sz*0.5f, y+sz*0.5f), sz*0.5f, col32, 32); x += sz+spacing
      draw_list->AddRectFilled(ImVec2(x, y), ImVec2(x+sz, y+sz), col32); x += sz+spacing
      draw_list->AddRectFilled(ImVec2(x, y), ImVec2(x+sz, y+sz), col32, 10.0f); x += sz+spacing
      draw_list->AddRectFilled(ImVec2(x, y), ImVec2(x+sz, y+sz), col32, 10.0f, ImDrawCornerFlags_TopLeft|ImDrawCornerFlags_BotRight); x += sz+spacing
      draw_list->AddTriangleFilled(ImVec2(x+sz*0.5f, y), ImVec2(x+sz,y+sz-0.5f), ImVec2(x,y+sz-0.5f), col32); x += sz+spacing
      draw_list->AddRectFilled(ImVec2(x, y), ImVec2(x+sz, y+thickness), col32); x += sz+spacing;          // Horizontal line (faster than AddLine, but only handle integer thickness)
      draw_list->AddRectFilled(ImVec2(x, y), ImVec2(x+thickness, y+sz), col32); x += spacing+spacing;     // Vertical line (faster than AddLine, but only handle integer thickness)
      draw_list->AddRectFilled(ImVec2(x, y), ImVec2(x+1, y+1), col32);          x += sz;                  // Pixel (faster than AddLine)
      draw_list->AddRectFilledMultiColor(ImVec2(x, y), ImVec2(x+sz, y+sz), IM_COL32(0,0,0,255), IM_COL32(255,0,0,255), IM_COL32(255,255,0,255), IM_COL32(0,255,0,255))
      im.Dummy(ImVec2((sz+spacing)*8, (sz+spacing)*3))
  }
  im.Separator()
  {
      static ImVector<ImVec2> points
      local adding_line = ffi.new("bool", false)
      im.Text("Canvas example")
      if (im.Button("Clear")) points.clear()
      if (points.Size >= 2) { im.SameLine(); if (im.Button("Undo")) { points.pop_back(); points.pop_back(); } }
      im.Text("Left-click and drag to add lines,\nRight-click to undo")

      // Here we are using InvisibleButton() as a convenience to 1) advance the cursor and 2) allows us to use IsItemHovered()
      // But you can also draw directly and poll mouse/keyboard by yourself. You can manipulate the cursor using GetCursorPos() and SetCursorPos().
      // If you only use the ImDrawList API, you can notify the owner window of its extends by using SetCursorPos(max).
      ImVec2 canvas_pos = im.GetCursorScreenPos();            // ImDrawList API uses screen coordinates!
      ImVec2 canvas_size = im.GetContentRegionAvail();        // Resize canvas to what's available
      if (canvas_size.x < 50.0f) canvas_size.x = 50.0f
      if (canvas_size.y < 50.0f) canvas_size.y = 50.0f
      draw_list->AddRectFilledMultiColor(canvas_pos, ImVec2(canvas_pos.x + canvas_size.x, canvas_pos.y + canvas_size.y), IM_COL32(50,50,50,255), IM_COL32(50,50,60,255), IM_COL32(60,60,70,255), IM_COL32(50,50,60,255))
      draw_list->AddRect(canvas_pos, ImVec2(canvas_pos.x + canvas_size.x, canvas_pos.y + canvas_size.y), IM_COL32(255,255,255,255))

      bool adding_preview = false
      im.InvisibleButton("canvas", canvas_size)
      ImVec2 mouse_pos_in_canvas = ImVec2(im.GetIO().MousePos.x - canvas_pos.x, im.GetIO().MousePos.y - canvas_pos.y)
      if (adding_line)
      {
          adding_preview = true
          points.push_back(mouse_pos_in_canvas)
          if (!im.IsMouseDown(0))
              adding_line = adding_preview = false
      }
      if (im.IsItemHovered())
      {
          if (!adding_line && im.IsMouseClicked(0))
          {
              points.push_back(mouse_pos_in_canvas)
              adding_line = true
          }
          if (im.IsMouseClicked(1) && !points.empty())
          {
              adding_line = adding_preview = false
              points.pop_back()
              points.pop_back()
          }
      }
      draw_list->PushClipRect(canvas_pos, ImVec2(canvas_pos.x+canvas_size.x, canvas_pos.y+canvas_size.y), true);      // clip lines within the canvas (if we resize it, etc.)
      for (int i = 0; i < points.Size - 1; i += 2)
          draw_list->AddLine(ImVec2(canvas_pos.x + points[i].x, canvas_pos.y + points[i].y), ImVec2(canvas_pos.x + points[i+1].x, canvas_pos.y + points[i+1].y), IM_COL32(255,255,0,255), 2.0f)
      draw_list->PopClipRect()
      if (adding_preview)
          points.pop_back()
  }
  im.End()
  }

  // Demonstrating creating a simple console window, with scrolling, filtering, completion and history.
  // For the console example, here we are using a more C++ like approach of declaring a class to hold the data and the functions.
  struct ExampleAppConsole
  {
  char                  InputBuf[256]
  ImVector<char*>       Items
  bool                  ScrollToBottom
  ImVector<char*>       History
  int                   HistoryPos;    // -1: new line, 0..History.Size-1 browsing history.
  ImVector<const char*> Commands

  ExampleAppConsole()
  {
      ClearLog()
      memset(InputBuf, 0, sizeof(InputBuf))
      HistoryPos = -1
      Commands.push_back("HELP")
      Commands.push_back("HISTORY")
      Commands.push_back("CLEAR")
      Commands.push_back("CLASSIFY");  // "classify" is here to provide an example of "C"+[tab] completing to "CL" and displaying matches.
      AddLog("Welcome to Dear ImGui!")
  }
  ~ExampleAppConsole()
  {
      ClearLog()
      for (int i = 0; i < History.Size; i++)
          free(History[i])
  }

  // Portable helpers
  static int   Stricmp(const char* str1, const char* str2)         { int d; while ((d = toupper(*str2) - toupper(*str1)) == 0 && *str1) { str1++; str2++; } return d; }
  static int   Strnicmp(const char* str1, const char* str2, int n) { int d = 0; while (n > 0 && (d = toupper(*str2) - toupper(*str1)) == 0 && *str1) { str1++; str2++; n--; } return d; }
  static char* Strdup(const char *str)                             { size_t len = strlen(str) + 1; void* buff = malloc(len); return (char*)memcpy(buff, (const void*)str, len); }
  static void  Strtrim(char* str)                                  { char* str_end = str + strlen(str); while (str_end > str && str_end[-1] == ' ') str_end--; *str_end = 0; }

  void    ClearLog()
  {
      for (int i = 0; i < Items.Size; i++)
          free(Items[i])
      Items.clear()
      ScrollToBottom = true
  }

  void    AddLog(const char* fmt, ...) IM_FMTARGS(2)
  {
      // FIXME-OPT
      char buf[1024]
      va_list args
      va_start(args, fmt)
      vsnprintf(buf, IM_ARRAYSIZE(buf), fmt, args)
      buf[IM_ARRAYSIZE(buf)-1] = 0
      va_end(args)
      Items.push_back(Strdup(buf))
      ScrollToBottom = true
  }

  void    Draw(const char* title, bool* p_open)
  {
      im.SetNextWindowSize(ImVec2(520,600), ImGuiCond_FirstUseEver)
      if (!im.Begin(title, p_open))
      {
          im.End()
          return
      }

      // As a specific feature guaranteed by the library, after calling Begin() the last Item represent the title bar. So e.g. IsItemHovered() will return true when hovering the title bar.
      // Here we create a context menu only available from the title bar.
      if (im.BeginPopupContextItem())
      {
          if (im.MenuItem("Close"))
              *p_open = false
          im.EndPopup()
      }

      im.TextWrapped("This example implements a console with basic coloring, completion and history. A more elaborate implementation may want to store entries along with extra data such as timestamp, emitter, etc.")
      im.TextWrapped("Enter 'HELP' for help, press TAB to use text completion.")

      // TODO: display items starting from the bottom

      if (im.SmallButton("Add Dummy Text")) { AddLog("%d some text", Items.Size); AddLog("some more text"); AddLog("display very important message here!"); } im.SameLine()
      if (im.SmallButton("Add Dummy Error")) { AddLog("[error] something went wrong"); } im.SameLine()
      if (im.SmallButton("Clear")) { ClearLog(); } im.SameLine()
      bool copy_to_clipboard = im.SmallButton("Copy"); im.SameLine()
      if (im.SmallButton("Scroll to bottom")) ScrollToBottom = true
      //static float t = 0.0f; if (im.GetTime() - t > 0.02f) { t = im.GetTime(); AddLog("Spam %f", t); }

      im.Separator()

      im.PushStyleVar(ImGuiStyleVar_FramePadding, ImVec2(0,0))
      static ImGuiTextFilter filter
      filter.Draw("Filter (\"incl,-excl\") (\"error\")", 180)
      im.PopStyleVar()
      im.Separator()

      const float footer_height_to_reserve = im.GetStyle().ItemSpacing.y + im.GetFrameHeightWithSpacing(); // 1 separator, 1 input text
      im.BeginChild("ScrollingRegion", ImVec2(0, -footer_height_to_reserve), false, ImGuiWindowFlags_HorizontalScrollbar); // Leave room for 1 separator + 1 InputText
      if (im.BeginPopupContextWindow())
      {
          if (im.Selectable("Clear")) ClearLog()
          im.EndPopup()
      }

      // Display every line as a separate entry so we can change their color or add custom widgets. If you only want raw text you can use im.TextUnformatted(log.begin(), log.end())
      // NB- if you have thousands of entries this approach may be too inefficient and may require user-side clipping to only process visible items.
      // You can seek and display only the lines that are visible using the ImGuiListClipper helper, if your elements are evenly spaced and you have cheap random access to the elements.
      // To use the clipper we could replace the 'for (int i = 0; i < Items.Size; i++)' loop with:
      //     ImGuiListClipper clipper(Items.Size)
      //     while (clipper.Step())
      //         for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++)
      // However, note that you can not use this code as is if a filter is active because it breaks the 'cheap random-access' property. We would need random-access on the post-filtered list.
      // A typical application wanting coarse clipping and filtering may want to pre-compute an array of indices that passed the filtering test, recomputing this array when user changes the filter,
      // and appending newly elements as they are inserted. This is left as a task to the user until we can manage to improve this example code!
      // If your items are of variable size you may want to implement code similar to what ImGuiListClipper does. Or split your data into fixed height items to allow random-seeking into your list.
      im.PushStyleVar(ImGuiStyleVar_ItemSpacing, ImVec2(4,1)); // Tighten spacing
      if (copy_to_clipboard)
          im.LogToClipboard()
      ImVec4 col_default_text = im.GetStyleColorVec4(ImGuiCol_Text)
      for (int i = 0; i < Items.Size; i++)
      {
          const char* item = Items[i]
          if (!filter.PassFilter(item))
              continue
          ImVec4 col = col_default_text
          if (strstr(item, "[error]")) col = ImColor(1.0f,0.4f,0.4f,1.0f)
          else if (strncmp(item, "# ", 2) == 0) col = ImColor(1.0f,0.78f,0.58f,1.0f)
          im.PushStyleColor(ImGuiCol_Text, col)
          im.TextUnformatted(item)
          im.PopStyleColor()
      }
      if (copy_to_clipboard)
          im.LogFinish()
      if (ScrollToBottom)
          im.SetScrollHere(1.0f)
      ScrollToBottom = false
      im.PopStyleVar()
      im.EndChild()
      im.Separator()

      // Command-line
      bool reclaim_focus = false
      if (im.InputText("Input", InputBuf, IM_ARRAYSIZE(InputBuf), ImGuiInputTextFlags_EnterReturnsTrue|ImGuiInputTextFlags_CallbackCompletion|ImGuiInputTextFlags_CallbackHistory, &TextEditCallbackStub, (void*)this))
      {
          Strtrim(InputBuf)
          if (InputBuf[0])
              ExecCommand(InputBuf)
          strcpy(InputBuf, "")
          reclaim_focus = true
      }

      // Demonstrate keeping focus on the input box
      im.SetItemDefaultFocus()
      if (reclaim_focus)
          im.SetKeyboardFocusHere(-1); // Auto focus previous widget

      im.End()
  }

  void    ExecCommand(const char* command_line)
  {
      AddLog("# %s\n", command_line)

      // Insert into history. First find match and delete it so it can be pushed to the back. This isn't trying to be smart or optimal.
      HistoryPos = -1
      for (int i = History.Size-1; i >= 0; i--)
          if (Stricmp(History[i], command_line) == 0)
          {
              free(History[i])
              History.erase(History.begin() + i)
              break
          }
      History.push_back(Strdup(command_line))

      // Process command
      if (Stricmp(command_line, "CLEAR") == 0)
      {
          ClearLog()
      }
      else if (Stricmp(command_line, "HELP") == 0)
      {
          AddLog("Commands:")
          for (int i = 0; i < Commands.Size; i++)
              AddLog("- %s", Commands[i])
      }
      else if (Stricmp(command_line, "HISTORY") == 0)
      {
          int first = History.Size - 10
          for (int i = first > 0 ? first : 0; i < History.Size; i++)
              AddLog("%3d: %s\n", i, History[i])
      }
      else
      {
          AddLog("Unknown command: '%s'\n", command_line)
      }
  }

  static int TextEditCallbackStub(ImGuiTextEditCallbackData* data) // In C++11 you are better off using lambdas for this sort of forwarding callbacks
  {
      ExampleAppConsole* console = (ExampleAppConsole*)data->UserData
      return console->TextEditCallback(data)
  }

  int     TextEditCallback(ImGuiTextEditCallbackData* data)
  {
      //AddLog("cursor: %d, selection: %d-%d", data->CursorPos, data->SelectionStart, data->SelectionEnd)
      switch (data->EventFlag)
      {
      case ImGuiInputTextFlags_CallbackCompletion:
          {
              // Example of TEXT COMPLETION

              // Locate beginning of current word
              const char* word_end = data->Buf + data->CursorPos
              const char* word_start = word_end
              while (word_start > data->Buf)
              {
                  const char c = word_start[-1]
                  if (c == ' ' || c == '\t' || c == ',' || c == ';')
                      break
                  word_start--
              }

              // Build a list of candidates
              ImVector<const char*> candidates
              for (int i = 0; i < Commands.Size; i++)
                  if (Strnicmp(Commands[i], word_start, (int)(word_end-word_start)) == 0)
                      candidates.push_back(Commands[i])

              if (candidates.Size == 0)
              {
                  // No match
                  AddLog("No match for \"%.*s\"!\n", (int)(word_end-word_start), word_start)
              }
              else if (candidates.Size == 1)
              {
                  // Single match. Delete the beginning of the word and replace it entirely so we've got nice casing
                  data->DeleteChars((int)(word_start-data->Buf), (int)(word_end-word_start))
                  data->InsertChars(data->CursorPos, candidates[0])
                  data->InsertChars(data->CursorPos, " ")
              }
              else
              {
                  // Multiple matches. Complete as much as we can, so inputing "C" will complete to "CL" and display "CLEAR" and "CLASSIFY"
                  int match_len = (int)(word_end - word_start)
                  for (;;)
                  {
                      int c = 0
                      bool all_candidates_matches = true
                      for (int i = 0; i < candidates.Size && all_candidates_matches; i++)
                          if (i == 0)
                              c = toupper(candidates[i][match_len])
                          else if (c == 0 || c != toupper(candidates[i][match_len]))
                              all_candidates_matches = false
                      if (!all_candidates_matches)
                          break
                      match_len++
                  }

                  if (match_len > 0)
                  {
                      data->DeleteChars((int)(word_start - data->Buf), (int)(word_end-word_start))
                      data->InsertChars(data->CursorPos, candidates[0], candidates[0] + match_len)
                  }

                  // List matches
                  AddLog("Possible matches:\n")
                  for (int i = 0; i < candidates.Size; i++)
                      AddLog("- %s\n", candidates[i])
              }

              break
          }
      case ImGuiInputTextFlags_CallbackHistory:
          {
              // Example of HISTORY
              const int prev_history_pos = HistoryPos
              if (data->EventKey == ImGuiKey_UpArrow)
              {
                  if (HistoryPos == -1)
                      HistoryPos = History.Size - 1
                  else if (HistoryPos > 0)
                      HistoryPos--
              }
              else if (data->EventKey == ImGuiKey_DownArrow)
              {
                  if (HistoryPos != -1)
                      if (++HistoryPos >= History.Size)
                          HistoryPos = -1
              }

              // A better implementation would preserve the data on the current input line along with cursor position.
              if (prev_history_pos != HistoryPos)
              {
                  data->CursorPos = data->SelectionStart = data->SelectionEnd = data->BufTextLen = (int)snprintf(data->Buf, (size_t)data->BufSize, "%s", (HistoryPos >= 0) ? History[HistoryPos] : "")
                  data->BufDirty = true
              }
          }
      }
      return 0
  }
  }

  static void ShowExampleAppConsole(bool* p_open)
  {
  static ExampleAppConsole console
  console.Draw("Example: Console", p_open)
  }

  // Usage:
  //  static ExampleAppLog my_log
  //  my_log.AddLog("Hello %d world\n", 123)
  //  my_log.Draw("title")
  struct ExampleAppLog
  {
  ImGuiTextBuffer     Buf
  ImGuiTextFilter     Filter
  ImVector<int>       LineOffsets;        // Index to lines offset
  bool                ScrollToBottom

  void    Clear()     { Buf.clear(); LineOffsets.clear(); }

  void    AddLog(const char* fmt, ...) IM_FMTARGS(2)
  {
      int old_size = Buf.size()
      va_list args
      va_start(args, fmt)
      Buf.appendfv(fmt, args)
      va_end(args)
      for (int new_size = Buf.size(); old_size < new_size; old_size++)
          if (Buf[old_size] == '\n')
              LineOffsets.push_back(old_size)
      ScrollToBottom = true
  }

  void    Draw(const char* title, bool* p_open = NULL)
  {
      im.SetNextWindowSize(ImVec2(500,400), ImGuiCond_FirstUseEver)
      im.Begin(title, p_open)
      if (im.Button("Clear")) Clear()
      im.SameLine()
      bool copy = im.Button("Copy")
      im.SameLine()
      Filter.Draw("Filter", -100.0f)
      im.Separator()
      im.BeginChild("scrolling", ImVec2(0,0), false, ImGuiWindowFlags_HorizontalScrollbar)
      if (copy) im.LogToClipboard()

      if (Filter.IsActive())
      {
          const char* buf_begin = Buf.begin()
          const char* line = buf_begin
          for (int line_no = 0; line != NULL; line_no++)
          {
              const char* line_end = (line_no < LineOffsets.Size) ? buf_begin + LineOffsets[line_no] : NULL
              if (Filter.PassFilter(line, line_end))
                  im.TextUnformatted(line, line_end)
              line = line_end && line_end[1] ? line_end + 1 : NULL
          }
      }
      else
      {
          im.TextUnformatted(Buf.begin())
      }

      if (ScrollToBottom)
          im.SetScrollHere(1.0f)
      ScrollToBottom = false
      im.EndChild()
      im.End()
  }
  }

  // Demonstrate creating a simple log window with basic filtering.
  static void ShowExampleAppLog(bool* p_open)
  {
  static ExampleAppLog log

  // Demo: add random items (unless Ctrl is held)
  static float last_time = -1.0f
  float time = im.GetTime()
  if (time - last_time >= 0.20f && !im.GetIO().KeyCtrl)
  {
      const char* random_words[] = { "system", "info", "warning", "error", "fatal", "notice", "log" }
      log.AddLog("[%s] Hello, time is %.1f, frame count is %d\n", random_words[rand() % IM_ARRAYSIZE(random_words)], time, im.GetFrameCount())
      last_time = time
  }

  log.Draw("Example: Log", p_open)
  }


  // Demonstrate create a simple property editor.
  static void ShowExampleAppPropertyEditor(bool* p_open)
  {
  im.SetNextWindowSize(ImVec2(430,450), ImGuiCond_FirstUseEver)
  if (!im.Begin("Example: Property editor", p_open))
  {
      im.End()
      return
  }

  ShowHelpMarker("This example shows how you may implement a property editor using two columns.\nAll objects/fields data are dummies here.\nRemember that in many simple cases, you can use im.SameLine(xxx) to position\nyour cursor horizontally instead of using the Columns() API.")

  im.PushStyleVar(ImGuiStyleVar_FramePadding, ImVec2(2,2))
  im.Columns(2)
  im.Separator()

  struct funcs
  {
      static void ShowDummyObject(const char* prefix, int uid)
      {
          im.PushID(uid);                      // Use object uid as identifier. Most commonly you could also use the object pointer as a base ID.
          im.AlignTextToFramePadding();  // Text and Tree nodes are less high than regular widgets, here we add vertical spacing to make the tree lines equal high.
          bool node_open = im.TreeNode("Object", "%s_%u", prefix, uid)
          im.NextColumn()
          im.AlignTextToFramePadding()
          im.Text("my sailor is rich")
          im.NextColumn()
          if (node_open)
          {
              static float dummy_members[8] = { 0.0f,0.0f,1.0f,3.1416f,100.0f,999.0f }
              for (int i = 0; i < 8; i++)
              {
                  im.PushID(i); // Use field index as identifier.
                  if (i < 2)
                  {
                      ShowDummyObject("Child", 424242)
                  }
                  else
                  {
                      // Here we use a TreeNode to highlight on hover (we could use e.g. Selectable as well)
                      im.AlignTextToFramePadding()
                      im.TreeNodeEx("Field", ImGuiTreeNodeFlags_Leaf | ImGuiTreeNodeFlags_Bullet, "Field_%d", i)
                      im.NextColumn()
                      im.PushItemWidth(-1)
                      if (i >= 5)
                          im.InputFloat("##value", &dummy_members[i], 1.0f)
                      else
                          im.DragFloat("##value", &dummy_members[i], 0.01f)
                      im.PopItemWidth()
                      im.NextColumn()
                  }
                  im.PopID()
              }
              im.TreePop()
          }
          im.PopID()
      }
  }

  // Iterate dummy objects with dummy members (all the same data)
  for (int obj_i = 0; obj_i < 3; obj_i++)
      funcs::ShowDummyObject("Object", obj_i)

  im.Columns(1)
  im.Separator()
  im.PopStyleVar()
  im.End()
  }

  // Demonstrate/test rendering huge amount of text, and the incidence of clipping.
  static void ShowExampleAppLongText(bool* p_open)
  {
  im.SetNextWindowSize(ImVec2(520,600), ImGuiCond_FirstUseEver)
  if (!im.Begin("Example: Long text display", p_open))
  {
      im.End()
      return
  }

  static int test_type = 0
  static ImGuiTextBuffer log
  static int lines = 0
  im.Text("Printing unusually long amount of text.")
  im.Combo("Test type", &test_type, "Single call to TextUnformatted()\0Multiple calls to Text(), clipped manually\0Multiple calls to Text(), not clipped (slow)\0")
  im.Text("Buffer contents: %d lines, %d bytes", lines, log.size())
  if (im.Button("Clear")) { log.clear(); lines = 0; }
  im.SameLine()
  if (im.Button("Add 1000 lines"))
  {
      for (int i = 0; i < 1000; i++)
          log.appendf("%i The quick brown fox jumps over the lazy dog\n", lines+i)
      lines += 1000
  }
  im.BeginChild("Log")
  switch (test_type)
  {
  case 0:
      // Single call to TextUnformatted() with a big buffer
      im.TextUnformatted(log.begin(), log.end())
      break
  case 1:
      {
          // Multiple calls to Text(), manually coarsely clipped - demonstrate how to use the ImGuiListClipper helper.
          im.PushStyleVar(ImGuiStyleVar_ItemSpacing, ImVec2(0,0))
          ImGuiListClipper clipper(lines)
          while (clipper.Step())
              for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++)
                  im.Text("%i The quick brown fox jumps over the lazy dog", i)
          im.PopStyleVar()
          break
      }
  case 2:
      // Multiple calls to Text(), not clipped (slow)
      im.PushStyleVar(ImGuiStyleVar_ItemSpacing, ImVec2(0,0))
      for (int i = 0; i < lines; i++)
          im.Text("%i The quick brown fox jumps over the lazy dog", i)
      im.PopStyleVar()
      break
  }
  im.EndChild()
  im.End()
  }
  --]]
end

local function onWindowMenuItem()
  windowOpen[0] = true
end

local function onEditorInitialized()
  editor.addWindowMenuItem("ImGui Lua Demo", onWindowMenuItem, {groupMenuName = 'Experimental'})
end

M.onEditorInitialized = onEditorInitialized
M.onEditorGui = onEditorGui

return M
