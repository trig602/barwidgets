function widget:GetInfo()
    return {
        name    = "WaitCommands",
        desc    = "Creates shortcuts for wait commands",
        author  = "trig602",
        date    = "2025-08-12",
        license = "MIT",
        enabled = true,
    }
end

--Squad and time wait only makes sense as a queued command so having the shortcut be Shift+key is something I HIGHLY recommend.
local squadWaitKey = "Shift+g"
local timeWaitKey = "Shift+t"
local deathWaitKey = "Shift+b"
local gatherWaitKey = "Shift+h"

function widget:KeyPress(key, mods, isRepeat, label, unicode, scanCode, actions)
    if label == squadWaitKey then
        Spring.SetActiveCommand("SquadWait")
        return true
    elseif label == timeWaitKey then
        Spring.SetActiveCommand("TimeWait")
        return true
    elseif label == deathWaitKey then
        Spring.SetActiveCommand("DeathWait")
        return true
    elseif label == gatherWaitKey then
        Spring.SetActiveCommand("GatherWait")
        return true
    end
end
