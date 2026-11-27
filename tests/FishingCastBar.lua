-- The fishing float (GamepadCompanion) is the cast bar while you fish: Cinematic
-- keeps the float and the cast bar's Casting row stays dark meanwhile.
local root = arg[1] or "Interface/AddOns/FrameGambit"
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
SlashCmdList = {}
C_Timer = { After = function() end }
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
FrameGambitDB = { profile = "Default", profiles = { Default = { targets = {} } } }
ns.runtime.context = { casting = true }

local hides = false
GamepadCompanionAPI = { version = 1, FishingHidesCastBar = function() return hides end }
assert(ns:ConditionIsMet("casting", "eui_castbar"), "a cast shows the cast bar")
hides = true
assert(not ns:ConditionIsMet("casting", "eui_castbar"), "the float stands in while fishing")
assert(ns:ConditionIsMet("casting", "player_frame"), "other frames still see the cast")
GamepadCompanionAPI.FishingHidesCastBar = function() error("boom") end
assert(ns:ConditionIsMet("casting", "eui_castbar"), "a broken provider never hides the bar")
GamepadCompanionAPI = nil
assert(ns:ConditionIsMet("casting", "eui_castbar"), "without the companion nothing changes")

ns.IsFrameGambitFrame = function() return false end
local float = { GetName = function() return "GamepadCompanionLure" end }
assert(ns:IsCinematicBlackoutExempt(float), "the float stays in Cinematic")
print("PASS: fishing float kept in Cinematic, cast bar dark while it stands in")
