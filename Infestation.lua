function widget:GetInfo()
  return {
    name    = "Infestation",
    desc    = "Makes infestors more true to thier namesake and multiply aggressively when left idle",
    author  = "trig602",
    date    = "2025-07-07",
    license = "GNU GPL, v2 or later",
    layer   = 0,
    enabled = true,
  }
end

local dataModelName = "infestation_DataModel"
local rmlFile       = "luaui/Widgets/Infestation.rml"
local rmlVerified   = false1
local rmlCode       = [[
<rml>
  <head>
    <style>
      button {
        position: absolute;
        font-family: "FreeSans";
        box-sizing: border-box;
        border-color: rgb(32, 32, 32);
        opacity: 0.8;
        cursor: pointer;
      }

      button.active {
        background-color: rgb(79, 185, 46);
      }

      button.active:hover {
        background-color: rgb(52, 145, 33);
      }

      button.active:active {
        background-color: rgb(39, 114, 24);
      }

      button.inactive {
        background-color: rgb(24, 66, 16);
      }


      button.inactive:hover {
        background-color: rgb(18, 53, 12);
      }

      button.inactive:active {
        background-color: rgb(14, 43, 7);
      }


      button span {
        display: block;
        font-family: "FreeSans";
        width: 100%;
        color: rgb(0, 0, 0);
        opacity: 1;
        text-align: center;
      }
    </style>
  </head>

  <body>
    <div data-model="]] .. dataModelName .. [[">
      <button data-class-active="InfestationActive" data-class-inactive="!InfestationActive"
        data-style-left="buttonPosX" data-style-top="buttonPosY" data-style-width="buttonSize"
        data-style-height="buttonSize" data-style-padding="buttonPadding" data-style-border-width="buttonBorderWidth"
        data-style-border-radius="buttonBorderRadius" onclick="widget:InfestorToggleFunction()">
        <span data-style-font-size="buttonLabelSize">Infest</span>
        <span data-style-font-size="buttonLabelSize">Toggle</span>
        <span data-style-font-size="buttonStatusSize">{{InfestationActive ? 'On' : 'Off'}}</span>
      </button>
    </div>
  </body>
</rml>
]]


-- I get it... But why ship two files when I could ship one?
local function ensureRmlFile()
  local readContents = nil

  local readFile = io.open(rmlFile, "r")
  if readFile then
    readContents = readFile:read("*a")
    readFile:close()
  end

  if readContents ~= rmlCode then
    Spring.Echo("verifying RML file")
    local writeFile = io.open(rmlFile, "w")
    if writeFile then
      writeFile:write(rmlCode)
      writeFile:close()
      rmlVerified = true
    else
      Spring.Echo("Could Not Write RML File")
    end
  else
    rmlVerified = true
  end
end

ensureRmlFile()


local function scaleValueRange(input, minIn, maxIn, minOut, maxOut)
  local normalizeValue = (math.clamp(input, minIn, maxIn) - minIn) / (maxIn - minIn)
  local scaledValue = minOut + normalizeValue * (maxOut - minOut)

  return scaledValue
end


local assistanceRange                   = 500  -- range to call build assitance from with the fight command
local assistanceOrderDistance           = 200  -- distance that fight order should be placed from unit
local buildRange                        = 75   -- distance that build orders are placed from unit
local edgeGuardDistance                 = 200  -- distance to keep infestors from the edge of the map
local unitCapPercent                    = 0.85 -- percent of unit cap that infestors will fill up to
local minResourcePercent                = 0.05 -- min metal reserves were chance will be 0. It's just an offset so it will cut the percent off the top too.

local screenSizeX, screenSizeY          = Spring.GetWindowGeometry()

local contextName                       = "infestion_context"

local document                          = nil
local uiScale                           = Spring.GetConfigFloat("ui_scale", 1)

local idleWorkerButtonScreenHeightRatio = 0.045                                                                       -- A magic number used for scaling the button's size
local buttonSize                        = screenSizeY * idleWorkerButtonScreenHeightRatio * uiScale
local buttonPosX                        = scaleValueRange(uiScale, 0.8, 1.3, screenSizeY * 0.997, screenSizeY * 1.65) -- 0.8 - 1.3 is the range of the UI scale slider. 1.65 is a bit more that 1.3/0.8
local buttonPosY                        = screenSizeY - buttonSize

local infestorUnitDef                   = UnitDefNames["leginfestor"]
if not infestorUnitDef then
  error("[Infestation Widget] Legion not enabled — disabling widget.")
end

local myTeamID               = Spring.GetMyTeamID()
local mapWidth               = Game.mapX * 512
local mapHeight              = Game.mapY * 512
local myTeamUnitLimit        = Spring.GetTeamMaxUnits(myTeamID)
local waterLevel             = tonumber(Spring.GetModOptions().map_waterlevel) or 0

local infestorIdleList       = {}
local infestorIdleIndexMap   = {}
local infestorIndex          = 0

local dmHandle
local dataModel              = {}
dataModel.InfestationActive  = true
dataModel.buttonSize         = buttonSize .. "px"
dataModel.buttonPosX         = buttonPosX .. "px"
dataModel.buttonPosY         = buttonPosY .. "px"
dataModel.buttonPadding      = (buttonSize * 0.04) .. "px 0px"
dataModel.buttonLabelSize    = (buttonSize * 0.20) .. "px"
dataModel.buttonStatusSize   = (buttonSize * 0.29) .. "px"
dataModel.buttonBorderWidth  = (buttonSize * 0.06) .. "px"
dataModel.buttonBorderRadius = (buttonSize * 0.08) .. "px"


local function setupUI()
  if not RmlUi then
    Spring.Echo("RmlUi not available")
    return
  end

  if not rmlVerified then
    Spring.Echo("RML File could not be verified")
    return
  end

  RmlUi.LoadFontFace("fonts/FreeSansBold.otf")
  widget.rmlContext = RmlUi.CreateContext(contextName)

  dmHandle = widget.rmlContext:OpenDataModel(dataModelName, dataModel)
  if not dmHandle then
    Spring.Echo("Failed to open RmlUi data model")
    return
  end

  document = widget.rmlContext:LoadDocument(rmlFile, widget)

  if not document then
    Spring.Echo("Failed to load RML document:", rmlFile)
    return
  end
end

function widget:Initialize()
  setupUI()
end

-- I maintain both an indexed list and a keyed list of idle Infestor unitIDs.
-- The keyed list has unitIDs as the keys and index positions of the ID from the indexed list as values.
-- I do this for very fast lookups as well as being able to pick IDs one at a time by index.

local function addInfestorToLists(unitID)
  local newIndex = #infestorIdleList + 1
  infestorIdleList[newIndex] = unitID
  infestorIdleIndexMap[unitID] = newIndex
end


-- uses the swap n pop method
local function removeInfestorFromLists(unitID)
  if not unitID then return end
  local i = infestorIdleIndexMap[unitID]
  if not i then return end

  local size = #infestorIdleList
  if i ~= size then
    local last = infestorIdleList[size]
    infestorIdleList[i] = last
    infestorIdleIndexMap[last] = i
  end
  infestorIdleList[size] = nil
  infestorIdleIndexMap[unitID] = nil
end

local function getNextIdleInfestor()
  local size = #infestorIdleList
  if size == 0 then return nil end
  if infestorIndex < size then
    infestorIndex = infestorIndex + 1
  else
    infestorIndex = 1
  end
  return infestorIdleList[infestorIndex]
end


-- Searches for a nearby build point.
-- Will retry up to 10000 times until it finds one.

local function GetNearbyBuildPoint(posX, posZ, range)
  local attempts = 0
  local maxAttempts = 10000
  local originalRange = range

  while attempts < maxAttempts do
    local targetRange = math.random(originalRange, range)
    local angle = math.random() * 2 * math.pi
    local offsetX = math.cos(angle) * targetRange
    local offsetZ = math.sin(angle) * targetRange
    local clampedX = math.clamp(posX + offsetX, edgeGuardDistance, mapWidth - edgeGuardDistance)
    local clampedZ = math.clamp(posZ + offsetZ, edgeGuardDistance, mapHeight - edgeGuardDistance)
    local height = Spring.GetGroundHeight(clampedX, clampedZ)

    if height > waterLevel then
      return clampedX, height, clampedZ
    elseif Spring.TestBuildOrder(infestorUnitDef.id, clampedX, height, clampedZ, 0) > 1 then
      return clampedX, height, clampedZ
    end

    range = range + 25
    attempts = attempts + 1
  end

  error("Infestation - Failed to find valid position above water near (" ..
    posX .. ", " .. posZ .. ") after " .. maxAttempts .. " attempts.")
end


-- Gets a point perpendicular to the build target for fight assistance. Does not order into deep water.
local function getPerpendicularOrderPoint(unitPosX, unitPosZ, targetPosX, targetPosZ, distance)
  local perpendicularZ = targetPosX - unitPosX
  local perpendicularX = -(targetPosZ - unitPosZ)

  local length = math.sqrt(perpendicularX ^ 2 + perpendicularZ ^ 2)
  local offsetX = perpendicularX / length * distance
  local offsetZ = perpendicularZ / length * distance

  local orderPosX = math.clamp(unitPosX + offsetX, edgeGuardDistance, mapWidth - edgeGuardDistance)
  local orderPosZ = math.clamp(unitPosZ + offsetZ, edgeGuardDistance, mapHeight - edgeGuardDistance)

  local height = Spring.GetGroundHeight(orderPosX, orderPosZ)

  if height > waterLevel then
    return orderPosX, height, orderPosZ
  elseif Spring.TestMoveOrder(infestorUnitDef.id, orderPosX, height, orderPosZ) then
    return orderPosX, height, orderPosZ
  else
    return unitPosX, Spring.GetGroundHeight(unitPosX, unitPosZ), unitPosZ
  end
end

-- Orders nearby idle infestors to do a fight command nearby for assitance.
-- Many infestors slowly solo building will crash the ecomony.

local function orderNearbyAssistance(posX, posZ, issuingUnitID)
  local units = Spring.GetUnitsInCylinder(posX, posZ, assistanceRange, myTeamID)

  for i, unit in ipairs(units) do
    local unitDefID = Spring.GetUnitDefID(unit)
    if unitDefID == infestorUnitDef.id and unit ~= issuingUnitID then
      local commands = Spring.GetUnitCommands(unit, -1)
      if commands == nil or #commands == 0 then
        local unitPosX, _, unitPosZ = Spring.GetUnitPosition(unit)
        local orderPointX, OrderPointY, OrderPointZ = getPerpendicularOrderPoint(unitPosX, unitPosZ, posX, posZ,
          assistanceOrderDistance)
        Spring.GiveOrderToUnit(unit, CMD.FIGHT, { orderPointX, OrderPointY, OrderPointZ }, {})
      end
    end
  end
end


local function buildInfestor(unitID)
  local unitPosX, _, unitPosZ = Spring.GetUnitPosition(unitID)
  if unitPosX == nil or unitPosZ == nil then return end
  local orderPointX, orderPointY, orderPointZ = GetNearbyBuildPoint(unitPosX, unitPosZ, buildRange)
  Spring.GiveOrderToUnit(unitID, -(infestorUnitDef.id), { orderPointX, orderPointY, orderPointZ }, {})
  orderNearbyAssistance(orderPointX, orderPointZ, unitID)
end

-- Build chance is metal reserves -5%

local function rollBuildChance()
  local energy = { Spring.GetTeamResources(myTeamID, "energy") }
  local energyStorageFill = energy[2] > 0 and (energy[1] / energy[2]) or 0
  if energyStorageFill < minResourcePercent then return false end -- Chance is 0 during an energy stall.

  local metal = { Spring.GetTeamResources(myTeamID, "metal") }
  local metalStorageFill = metal[2] > 0 and (metal[1] / metal[2]) or 0
  local resourceChance = metalStorageFill - minResourcePercent

  if math.random() < resourceChance then
    return true
  end
  return false
end


local function tryBuildInfestor(unitID)
  if not Spring.ValidUnitID(unitID) then return end
  if Spring.GetTeamUnitCount(myTeamID) < (myTeamUnitLimit * unitCapPercent) then
    if rollBuildChance() then
      buildInfestor(unitID)
    end
  end
end


function widget:SelectionChanged(selectedUnits)
  for i, unitID in ipairs(selectedUnits) do
    if Spring.GetUnitDefID(unitID) == infestorUnitDef.id then
      document:Show()
      return
    end
  end
  document:Hide()
end

function widget:UnitIdle(unitID, unitDefID, unitTeam)
  if unitDefID == infestorUnitDef.id and unitTeam == myTeamID and infestorIdleIndexMap[unitID] == nil then
    addInfestorToLists(unitID)
  end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdId, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
  if unitDefID == infestorUnitDef.id and unitTeam == myTeamID then
    removeInfestorFromLists(unitID)
  end
end

function widget:MetaUnitRemoved(unitID, unitDefID, unitTeam)
  if unitDefID == infestorUnitDef.id and unitTeam == myTeamID then
    removeInfestorFromLists(unitID)
  end
end

-- 30 times per second we attempted to order an infestor to build another based on build probability
function widget:GameFrame(frame)
  if dmHandle.InfestationActive then
    if #infestorIdleList > 0 then
      local infestor = getNextIdleInfestor()
      tryBuildInfestor(infestor)
    end
  end
end

-- Replaces gaurd commands on newly created infestors with fight commands
function widget:UnitFinished(unitID, unitDefID, unitTeam)
  if (unitDefID == infestorUnitDef.id and unitTeam == myTeamID) then
    -- increaseBuildChance() -- Build chance is increased only on unit completion
    local commands = Spring.GetUnitCommands(unitID, -1)
    if commands and #commands > 0 then
      local currentCmd = commands[1]
      if currentCmd.id == CMD.GUARD then
        if dmHandle.InfestationActive then
          local unitPosX, _, unitPosZ = Spring.GetUnitPosition(unitID)
          Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { GetNearbyBuildPoint(unitPosX, unitPosZ, assistanceOrderDistance) },
            {})
        else
          Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {})
        end
      end
    end
  end
end

function widget:InfestorToggleFunction()
  dmHandle.InfestationActive = not dmHandle.InfestationActive
end

function widget:Shutdown()
  if document then
    document:Close()
  end
  if widget.rmlContext then
    RmlUi.RemoveContext(contextName)
  end
  if dmHandle then
    widget.rmlContext:RemoveDataModel(dataModelName)
  end
end
