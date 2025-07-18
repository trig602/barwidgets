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

local myTeam = Spring.GetMyTeamID()
local mapWidth = Game.mapX * 512
local mapHeight = Game.mapY * 512
local edgeGuardDistance = 200
local infestorUnitDef = UnitDefNames["leginfestor"]

local function clamp(val, min, max)
  if val < min then return min end
  if val > max then return max end
  return val
end

local function GetPointOnCircle(posX, posZ, range)
    local angle = math.random() * 2 * math.pi
    local offsetX = math.cos(angle) * range
    local offsetZ = math.sin(angle) * range
    local clampedX = clamp(posX + offsetX,edgeGuardDistance,mapWidth - edgeGuardDistance)
    local clampedZ = clamp(posZ + offsetZ,edgeGuardDistance,mapHeight - edgeGuardDistance)
    return clampedX, clampedZ
end

-- Supresses gaurd commands on newly created infestors
function widget:UnitFinished(unitID, unitDefID, unitTeam)
  if (unitDefID == infestorUnitDef.id and unitTeam == myTeam) then
    local commands = Spring.GetUnitCommands(unitID, -1)
      if commands and #commands > 0 then
      local currentCmd = commands[1]
        if currentCmd.id == CMD.GUARD then
          Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {})
      end
    end
  end 
end

--Orders idle infestors to either construct a new infestor or fight to a nearby position.
function widget:UnitIdle(unitID, unitDefID, unitTeam)

  if (unitDefID == infestorUnitDef.id and unitTeam == myTeam) then

    local energy = {Spring.GetTeamResources(myTeam,"energy")}
    local metal = {Spring.GetTeamResources(myTeam,"metal")}
    local metalStorageFill = metal[1]/metal[2]
    local energyStorageFill = energy[1]/energy[2]
    local minResourse = math.min(metalStorageFill,energyStorageFill)
    local random = math.random()
    local unitPosX, unitPosZ
    local unitOrderX, unitOrderZ

    unitPosX, _ ,unitPosZ = Spring.GetUnitPosition(unitID)   
    
    if random < minResourse and random < 0.85 then
      unitOrderX, unitOrderZ = GetPointOnCircle(unitPosX,unitPosZ,75)
      Spring.GiveOrderToUnit(unitID,-(infestorUnitDef.id),{unitOrderX,Spring.GetGroundHeight(unitOrderX,unitOrderZ),unitOrderZ},{})
    else
      unitOrderX, unitOrderZ = GetPointOnCircle(unitPosX,unitPosZ,300)
      Spring.GiveOrderToUnit(unitID,CMD.FIGHT,{unitOrderX,Spring.GetGroundHeight(unitOrderX,unitOrderZ),unitOrderZ},{})
    end
  end
end

