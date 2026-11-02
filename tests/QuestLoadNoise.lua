-- Quest-log refreshes while logging in, reloading and zoning are not "Quest updated".
-- Run from the addon folder: lua5.1 tests/QuestLoadNoise.lua .
local root = arg and arg[1] or "Interface/AddOns/FrameGambit"
local now, driver = 10
GetTime = function() return now end
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
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
ns.IsCinematicActive = function() return false end
local moments = ns.runtime.moments
local function event(name, ...) driver.scripts.OnEvent(driver, name, ...) end

-- Before the login event nothing counts (events during addon load).
event("QUEST_LOG_UPDATE")
assert(moments.quest_update == nil, "quest log refresh before login is ignored")

-- The refresh right after entering the world is ignored too, and clears earlier ones.
event("PLAYER_ENTERING_WORLD")
now = 11
event("QUEST_LOG_UPDATE"); event("QUEST_WATCH_UPDATE")
assert(moments.quest_update == nil and moments.quest_objective == nil, "loading refreshes are ignored")
now = 15.9
event("QUEST_LOG_UPDATE")
assert(moments.quest_update == nil, "still inside the settle window")

-- Real quest changes are never ignored: accept / turn in count even during loading.
now = 12
event("QUEST_ACCEPTED")
assert(moments.quest_accepted == 12 and moments.quest_update == 12, "accepting a quest counts at any time")

-- Afterwards refreshes count again.
moments.quest_update, moments.quest_accepted = nil, nil
now = 16.5
event("QUEST_LOG_UPDATE")
assert(moments.quest_update == 16.5, "a quest log update after the settle window counts")
event("QUEST_WATCH_UPDATE")
assert(moments.quest_objective == 16.5, "objective progress after the settle window counts")

-- Zoning (a new loading screen) starts a new settle window and clears stale moments.
now = 40
event("PLAYER_ENTERING_WORLD")
assert(moments.quest_update == nil and moments.quest_objective == nil, "zoning clears refresh moments")
now = 41
event("QUEST_LOG_UPDATE")
assert(moments.quest_update == nil, "refresh right after zoning is ignored")
now = 47
event("QUEST_LOG_UPDATE")
assert(moments.quest_update == 47, "counts again after zoning has settled")
-- Entering the world does not mark it ready: only the loading-screen event does
-- (a short fallback used to end the minimap hold during slow loading screens).
ns.runtime.worldReadyAt = nil
event("LOADING_SCREEN_ENABLED")
now = 60
event("PLAYER_ENTERING_WORLD")
assert(ns.runtime.worldReadyAt == nil, "entering the world alone is not ready")
now = 65
event("LOADING_SCREEN_DISABLED")
assert(ns.runtime.worldReadyAt == 65, "the loading screen going away is")
print("PASS: quest log refreshes during login, reload and zoning do not count as Quest updated; real quest changes always do")
