

function widget:GetInfo()
  return {
    name      = "MineField",
    desc      = "MineField",
    author    = "You",
    date      = "2025",
    license   = "MIT",
    layer     = 0,
    enabled   = true,
  }
end

local document = nil
local rmlFile = "luaui/Widgets/MineField.rml"


local screenSizeX, screenSizeY

local startCorner
local endCorner
local midCorner1Height
local midCorner2Height

local buttonPosX
local buttonPosY
local dm

local areaPlacementToolState = 0
-- 0 = tool not in use
-- 1 = tool selected
-- 2 = tool dragging



function MineFieldButtonFunction()

  areaPlacementToolState = 1
  Spring.Echo("Selecting Area Placement Tool")

end


local function beginPlacingArea(mouseX, mouseY)

  startCorner = nil
  endCorner = nil

  local desc, pos = Spring.TraceScreenRay(mouseX, mouseY, true)
  if desc == nil then
    return
  end

  Spring.Echo("Beginning Area Placement")
  areaPlacementToolState = 2
  startCorner = pos

end


local function endPlacingArea(mouseX,mouseY)

  Spring.Echo("Finishing Area Placement")
  areaPlacementToolState = 1
  
end


local function resizePlacementArea(mouseX,mouseY)
  
  local desc, pos = Spring.TraceScreenRay(mouseX, mouseY, true)
  if desc == nil then
    return
  end

  endCorner = pos

  midCorner1Height = Spring.GetGroundHeight(startCorner[1],endCorner[3])
  midCorner2Height = Spring.GetGroundHeight(endCorner[1],startCorner[3])
  
end


local function drawBox()

  gl.DepthTest(false)
	gl.LineWidth(10)
	gl.Color(1, 1, 0, 0.45)

  local function MakeLine(x1, y1, z1, x2, y2, z2)
	  gl.Vertex(x1, y1, z1)
	  gl.Vertex(x2, y2, z2)
  end
  
  gl.BeginEnd(GL.LINE_STRIP, MakeLine, startCorner[1], startCorner[2], startCorner[3], endCorner[1], midCorner2Height, startCorner[3])
  gl.BeginEnd(GL.LINE_STRIP, MakeLine, endCorner[1], midCorner2Height, startCorner[3], endCorner[1], endCorner[2], endCorner[3])
  gl.BeginEnd(GL.LINE_STRIP, MakeLine, startCorner[1], startCorner[2], startCorner[3], startCorner[1], midCorner1Height, endCorner[3])
  gl.BeginEnd(GL.LINE_STRIP, MakeLine, startCorner[1], midCorner1Height, endCorner[3], endCorner[1], endCorner[2], endCorner[3])  

end




local function setupVars()
  
  screenSizeX, screenSizeY  = Spring.GetWindowGeometry()
  buttonPosX = screenSizeX * 0.7  .. "px"
  buttonPosY = screenSizeY - 70 .. "px"

  dm = {
    buttonPosX = buttonPosX,
    buttonPosY = buttonPosY,
    MineFieldButtonFunction = MineFieldButtonFunction,
  }


end


local function setupUI()
  if not RmlUi then
    Spring.Echo("RmlUi not available")
    return
  end
  RmlUi.LoadFontFace("fonts/FreeSansBold.otf")
  widget.rmlContext = RmlUi.CreateContext("simple_ui_context")  

    local dmHandle = widget.rmlContext:OpenDataModel("minefieldDatamodel", dm)
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

function widget:Initialize()

  setupVars()
  setupUI()

end


function widget:MousePress(mouseX, mouseY, button)
  
    if areaPlacementToolState == 1 and button == 1 then

      beginPlacingArea(mouseX, mouseY)    

    elseif areaPlacementToolState == 1 and button == 3 then
      Spring.Echo("Deselecting Area Placement Tool")
      areaPlacementToolState = 0

    elseif areaPlacementToolState == 2 and button == 3 then
      Spring.Echo("Cancelling Area Placement")
      startCorner = nil
      endCorner = nil
      areaPlacementToolState = 1
    end

    if areaPlacementToolState ~= 0 then
      return true
    end

end

function widget:MouseRelease(mouseX, mouseY, button)

    if areaPlacementToolState == 2 and button == 1 then

      endPlacingArea(mouseX,mouseY)
    end

end

function widget:MouseMove(mouseX, mouseY, dx, dy, button)

  if areaPlacementToolState == 2 then
    resizePlacementArea(mouseX,mouseY)
  end

  Spring.Echo(endCorner[1].." "..endCorner[3])
end


function widget:Shutdown()
  if document then
    document:Close()
  end
  if widget.rmlContext then
    RmlUi.RemoveContext("simple_ui_context")
  end
end

function widget:DrawWorld()

  if WG.DrawUnitShapeGL4 and startCorner and endCorner then
    drawBox()
  end
end



function widget:Layout()
  if widget.rmlContext then
    widget.rmlContext:Update()
    widget.rmlContext:Render()
  end
end
