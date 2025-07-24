function widget:GetInfo()
  return {
    name      = "AutoRez",
    desc      = "AutoRez",
    author    = "trig602",
    date      = "2025-07-23",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true,
  }
end

local idleCheckInterval = 60
local rezIDSet = {}
local rezUnitList = {}
local myTeamID = Spring.GetMyTeamID()
local mapSize = math.max(Game.mapX * 512, Game.mapY * 512)

for unitDefID, unitDef in pairs(UnitDefs) do
    if unitDef.canResurrect then
        rezIDSet[unitDefID] = true
    end
end

function widget:Initialize()
  rezUnitList = {}
  for unitDefID, _ in pairs(rezIDSet) do    
    local unitIDTable = Spring.GetTeamUnitsByDefs(myTeamID,unitDefID)
    for _, unitID in ipairs(unitIDTable) do
      rezUnitList[unitID] = true
    end
  end
end

function widget:MetaUnitAdded(unitID, unitDefID, unitTeam)
  if rezIDSet[unitDefID] and unitTeam == myTeamID then    
      rezUnitList[unitID] = true
  end  
end

function widget:MetaUnitRemoved(unitID, unitDefID, unitTeam)
    rezUnitList[unitID] = nil
end

function widget:GameFrame(frame)

  if frame % idleCheckInterval == 0 then
    for unitID, _ in pairs(rezUnitList) do  

      local commands = Spring.GetUnitCommands(unitID, -1)
        if commands == nil or #commands == 0 then
         local unitPosX, unitPosY, unitPosZ = Spring.GetUnitPosition(unitID)
         Spring.GiveOrderToUnit(unitID,CMD.RESURRECT,{ unitPosX, unitPosY, unitPosZ, mapSize },{})
      end

    end
  end
end

