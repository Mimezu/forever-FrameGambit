-- The bundled Showcase profile is seeded once, beside the player's profiles.
local root = arg and arg[1] or "."
GetTime = function() return 0 end
InCombatLockdown = function() return false end
SlashCmdList = {}
C_Timer = { After = function() end }
CreateFrame = function()
    return { RegisterEvent = function() end, RegisterUnitEvent = function() end,
        SetScript = function(self, name, callback) self[name] = callback end }
end
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/ShowcaseProfile.lua"))("FrameGambit", ns)
assert(ns.SHOWCASE_PROFILE_NAME == "Showcase")
assert(next(ns.SHOWCASE_PROFILE.targets), "showcase has frames")
for id in pairs(ns.SHOWCASE_PROFILE.targets) do
    if id:match("^custom_frame_") then assert(ns.SHOWCASE_CUSTOM_TARGETS[id], "custom frame shipped: " .. id) end
end

FrameGambitDB = { profile = "Default", profiles = { Default = { targets = {} } } }
assert(ns:EnsureShowcaseProfile() == true)
local copy = FrameGambitDB.profiles.Showcase
assert(copy and copy ~= ns.SHOWCASE_PROFILE and copy.targets ~= ns.SHOWCASE_PROFILE.targets, "seeded as a copy")
assert(FrameGambitDB.profile == "Default", "not selected for the player")
assert(FrameGambitDB.customTargets.custom_frame_421152822.name == "MinimapCluster")

-- Deleted by the player: it stays gone.
FrameGambitDB.profiles.Showcase = nil
assert(ns:EnsureShowcaseProfile() == false and FrameGambitDB.profiles.Showcase == nil)

-- A player profile already named showcase is left alone.
FrameGambitDB = { profiles = { showcase = { targets = { mine = {} } } } }
assert(ns:EnsureShowcaseProfile() == false and FrameGambitDB.profiles.showcase.targets.mine)
print("ShowcaseProfile: ok")
