function widget:GetInfo()
  return {
    name      = "Infestation",
    desc      = "Infestation",
    author    = "trig602",
    date      = "2025-07-07",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true,
  }
end



local infestorUnitDef = UnitDefNames["leginfestor"]
if not infestorUnitDef then
  error("[Infestation Widget] Legion not enabled — disabling widget.")
end

local edgeGuardDistance = 200
local unitCapPercent = 0.85
local minResourcePercent = 0.05

local myTeamID = Spring.GetMyTeamID()
local mapWidth = Game.mapX * 512
local mapHeight = Game.mapY * 512
local myTeamUnitLimit = Spring.GetTeamMaxUnits(myTeamID)

local function clamp(val, min, max)
  if val < min then return min end
  if val > max then return max end
  return val
end


-- Searches for a nearby point that is above the water line.
-- Will retry up to 10000 times until it finds one.

local function GetNearbyOrderPoint(posX, posZ, range)

    local attempts = 0
    local maxAttempts = 10000
    local originalRange = range

    while attempts < maxAttempts do

      local targetRange = math.random(originalRange, range)
      local angle = math.random() * 2 * math.pi
      local offsetX = math.cos(angle) * targetRange
      local offsetZ = math.sin(angle) * targetRange
      local clampedX = clamp(posX + offsetX,edgeGuardDistance,mapWidth - edgeGuardDistance)
      local clampedZ = clamp(posZ + offsetZ,edgeGuardDistance,mapHeight - edgeGuardDistance)
      local height =  Spring.GetGroundHeight (clampedX,clampedZ)

      if Spring.TestMoveOrder(infestorUnitDef.id, clampedX, height, clampedZ) then
        return clampedX, height ,clampedZ
      end

      range = range + 25
      attempts = attempts + 1

    end

    error("Infestation - Failed to find valid position above water near (" .. posX .. ", " .. posZ .. ") after " .. maxAttempts .. " attempts.")

end

-- Supresses gaurd commands on newly created infestors
function widget:UnitFinished(unitID, unitDefID, unitTeam)
  if (unitDefID == infestorUnitDef.id and unitTeam == myTeamID) then
    local commands = Spring.GetUnitCommands(unitID, -1)
      if commands and #commands > 0 then
      local currentCmd = commands[1]
        if currentCmd.id == CMD.GUARD then
          Spring.GiveOrderToUnit(unitID,CMD.STOP,{},{})
      end
    end
  end 
end


-- Orders idle infestors to either construct a new infestor or fight to a nearby position.
-- The chance to choose between building and fighting is proportional to your lowest resource storage level.
-- Won't build above 85% of your unit cap (unitCapPercent)

function widget:UnitIdle(unitID, unitDefID, unitTeam)

  if (unitDefID == infestorUnitDef.id and unitTeam == myTeamID) then

    local energy = {Spring.GetTeamResources(myTeamID,"energy")}
    local metal = {Spring.GetTeamResources(myTeamID,"metal")}
    local metalStorageFill = metal[2] > 0 and (metal[1] / metal[2]) or 0
    local energyStorageFill = energy[2] > 0 and (energy[1] / energy[2]) or 0
    local minResource = math.min(metalStorageFill,energyStorageFill) - minResourcePercent
    
    local unitPosX, _, unitPosZ = Spring.GetUnitPosition(unitID)

    if math.random() < minResource and Spring.GetTeamUnitCount(myTeamID) < (myTeamUnitLimit * unitCapPercent) then      

        Spring.GiveOrderToUnit(unitID,-(infestorUnitDef.id),{ GetNearbyOrderPoint(unitPosX, unitPosZ,75) },{})
    else
        Spring.GiveOrderToUnit(unitID,CMD.FIGHT,{ GetNearbyOrderPoint(unitPosX, unitPosZ,300) },{})
    end    
  end
end


