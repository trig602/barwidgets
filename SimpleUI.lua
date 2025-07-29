

function widget:GetInfo()
  return {
    name      = "Simple UI",
    desc      = "Minimal RmlUi example",
    author    = "You",
    date      = "2025",
    license   = "MIT",
    layer     = 0,
    enabled   = true,
  }
end

local document = nil

local rmlFile = "LuaUI/Widgets/RmlUI/simple_ui.rml"


local screenSizeX, screenSizeY  = Spring.GetWindowGeometry()

local buttonPosX = screenSizeX * 0.7  .. "px"
local buttonPosY = screenSizeY - 70 .. "px"

function PrintFunction()
      Spring.Echo("BUTTON CLICKED YO")
    end

  local dm = {
    buttonPosX = buttonPosX,
    buttonPosY = buttonPosY,
    PrintFunction = PrintFunction,
    styleString = styleString
  }

function widget:Initialize()
  if not RmlUi then
    Spring.Echo("RmlUi not available")
    return
  end

  RmlUi.LoadFontFace("fonts/FreeSansBold.otf")
  widget.rmlContext = RmlUi.CreateContext("simple_ui_context")  

    local dmHandle = widget.rmlContext:OpenDataModel("datamodel", dm)
  if not dmHandle then
    Spring.Echo("Failed to open RmlUi data model")
    return
  end

  document = widget.rmlContext:LoadDocument(rmlFile, widget)
  if not document then
    Spring.Echo("Failed to load RML document:", rmlFile)
    return
  end

  document:Show()
  
end

function widget:Shutdown()
  if document then
    document:Close()
  end
  if widget.rmlContext then
    RmlUi.RemoveContext("simple_ui_context")
  end
end

function widget:Layout()
  if widget.rmlContext then
    widget.rmlContext:Update()
    widget.rmlContext:Render()
  end
end
