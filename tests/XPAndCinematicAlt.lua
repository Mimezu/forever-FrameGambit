local root = arg and arg[1] or "Interface/AddOns/FrameGambit"
local now, xp, alt = 10, 100, false
local driver
GetTime = function() return now end
UnitXP = function() return xp end
IsAltKeyDown = function() return alt end
InCombatLockdown = function() return false end
SlashCmdList = {}
C_Timer = { After = function() end }
CreateFrame = function()
    driver = { scripts = {}, events = {} }
    function driver:RegisterEvent(event) self.events[event] = true end
    driver.RegisterUnitEvent = driver.RegisterEvent
    function driver:SetScript(event, fn) self.scripts[event] = fn end
    function driver:GetScript(event) return self.scripts[event] end
    return driver
end
hooksecurefunc = function(frame, method, hook)
    local original = frame[method]
    frame[method] = function(self, ...) original(self, ...); hook(self, ...) end
end
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
ns.IsCinematicActive = function() return false end
local function event(name, ...) driver.scripts.OnEvent(driver, name, ...) end
assert(driver.events.PLAYER_XP_UPDATE and driver.events.PLAYER_LEVEL_UP)
event("PLAYER_ENTERING_WORLD")
assert(not ns.runtime.moments.xp_gained)
event("PLAYER_XP_UPDATE", "player")
assert(not ns.runtime.moments.xp_gained)
xp = 150
event("PLAYER_XP_UPDATE", "party1")
assert(not ns.runtime.moments.xp_gained)
event("PLAYER_XP_UPDATE", "player")
assert(ns.runtime.moments.xp_gained == 10)
local reaction = { condition = "xp_gained", duration = 2 }
assert(ns:ConditionIsMet("xp_gained", nil, reaction, false, 11))
assert(not ns:ConditionIsMet("xp_gained", nil, reaction, false, 13))
now = 14
xp = 160
event("PLAYER_XP_UPDATE", "player")
assert(ns.runtime.moments.xp_gained == 14)
now, xp = 15, 0
event("PLAYER_XP_UPDATE", "player")
assert(ns.runtime.moments.xp_gained == 14)
event("PLAYER_LEVEL_UP", 2)
assert(ns.runtime.moments.xp_gained == 15)
now, xp = 20, 500
event("PLAYER_ENTERING_WORLD")
event("PLAYER_XP_UPDATE", "player")
assert(ns.runtime.moments.xp_gained == 15)
xp = "unreadable"
event("PLAYER_XP_UPDATE", "player")
xp = 600
event("PLAYER_XP_UPDATE", "player")
assert(ns.runtime.moments.xp_gained == 15)
assert(ns.CONDITION_INFO.xp_gained.category == "moment")
assert(ns.CONDITION_INFO.xp_gained.duration == 5)

ns.IsCinematicActive = function() return true end
ns.IsCinematicBlackoutExempt = function() return false end
ns.RememberCinematicOpenWindow = function() return false end
local frame = { alpha = 0, scripts = {} }
function frame:GetAlpha() return self.alpha end
function frame:SetAlpha(value) self.alpha = value end
function frame:HookScript(name, fn) self.scripts[name] = fn end
ns.runtime.cinematicBlackout[frame] = { baseAlpha = 0.8, appliedAlpha = 0 }
ns:HookCinematicRoot(frame)
alt = true
ns:UpdateCinematicBlackout(true)
assert(frame.alpha == 0, "Alt must not reveal unmanaged roots")
frame:SetAlpha(0.7)
assert(frame.alpha == 0, "Alt must not bypass host alpha enforcement")
frame.alpha = 0.7
frame.scripts.OnShow(frame)
assert(frame.alpha == 0, "Alt must not bypass OnShow enforcement")
ns.runtime.context.alt = true
assert(ns:ConditionIsMet("alt"), "Explicit Alt gambits still work")
ns.runtime.cinematicPickerReveal = true
ns:UpdateCinematicBlackout(true)
assert(frame.alpha == 0.7, "Picker reveal still works")
ns.runtime.cinematicPickerReveal = nil
ns:UpdateCinematicBlackout(true)
assert(frame.alpha == 0, "Closing picker restores blackout even with Alt held")
print("PASS: XP gains, duration, refresh, level-up, baseline, and Cinematic Alt/picker behavior")
