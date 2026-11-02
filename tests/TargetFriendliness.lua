local root = "Interface/AddOns/FrameGambit"
CreateFrame = function()
    return { RegisterEvent = function() end, RegisterUnitEvent = function() end,
        SetScript = function() end, GetScript = function() end }
end
SlashCmdList = {}
GetTime = function() return 1 end
C_Timer = { After = function() end }
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
local settings = { enabled = true, atRest = 0, reactions = {
    { condition = "target_hostile", opacity = 0.5 },
    { condition = "target_friendly", opacity = 0.3 },
} }
FrameGambitDB = { profile = "Default", profiles = { Default = { targets = { player = settings } } } }
local target = {}
UnitExists = function(unit) assert(unit == "target"); return target.exists end
UnitCanAttack = function(_, unit) assert(unit == "target"); return target.hostile end
UnitIsFriend = function(_, unit) assert(unit == "target"); return target.friendly end
UnitCanAssist = function() error("Friendliness must not depend on helpful-spell eligibility") end
local function check(value, opacity)
    target = value
    ns:BuildStateContext()
    assert(ns:Evaluate("player", settings) == opacity)
end
check({ exists = true, friendly = true, hostile = false }, 0.3) -- Friendly vendor.
check({ exists = true, friendly = false, hostile = true }, 0.5)
check({ exists = true, friendly = false, hostile = false }, 0) -- Neutral, not attackable.
check({ exists = false }, 0) -- Clear previously matched state.
UnitIsFriend = function() error("unavailable") end
check({ exists = true, hostile = false }, 0)
print("PASS: friendly vendor, hostile target, neutral target, cleared target and unreadable friendliness")
