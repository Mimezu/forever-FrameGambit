local root = arg[1] or "Interface/AddOns/FrameGambit"
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
SlashCmdList = {}
C_Timer = { After = function() end }
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/Targets.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/GamepadIntegration.lua"))("FrameGambit", ns)
local state = { available = true, enabled = true, gameplay = true, ltHeld = true, rtHeld = false }
GamepadCompanionAPI = { version = 1, GetState = function() return state end }
local bar = { SetAlpha = function() end, GetAlpha = function() return 1 end }
function bar:IsShown() return true end
function bar:GetRect() return 0, 0, 100, 100 end
GamepadCompanionAPI.GetBarFrame = function() return bar end
local reaction = { id = 1, condition = "gamepad_lt_held", gamepadExpected = true,
    opacity = 1, enabled = true, requirements = { "gamepad_rt_held_no", "gamepad_mode_yes" } }
assert(ns:ReactionIsMet(reaction, "gamepad_base"))
state.rtHeld = true
assert(not ns:ReactionIsMet(reaction, "gamepad_base"))
state.rtHeld = nil
assert(not ns:ReactionIsMet(reaction, "gamepad_base"), "unknown input must not match No")
state.rtHeld = false
assert(ns:GetRequirementConflict(reaction, "gamepad_rt_held_yes") == "gamepad_rt_held_no")
assert(ns:GetRequirementConflict(reaction, "gamepad_lt_held_no") == "gamepad_lt_held")
assert(not ns:GetRequirementConflict(reaction, "gamepad_both_held_no"))
reaction.gamepadExpected = false
state.ltHeld = false
assert(ns:ReactionIsMet(reaction, "gamepad_base"), "requirements must keep their own answers")
FrameGambitDB = { profile = "Default", profiles = { Default = { targets = {} } } }
local profile = ns:Profile()
profile.targets.gamepad_base = { enabled = true, atRest = 0.5, reactions = { reaction } }
local exported = assert(ns:ExportProfile("Default"))
local imported, err = ns:ParseProfileImport(exported)
assert(imported, err)
local restored = imported.targets.gamepad_base.reactions[1]
assert(restored.requirements[1] == "gamepad_rt_held_no")
assert(restored.requirements[2] == "gamepad_mode_yes")
assert(restored.gamepadExpected == false)
assert(ns:ReactionIsMet(restored, "gamepad_base"))
for _, entry in ipairs({
    { "gamepad_left_shoulder_held", "leftShoulderHeld" },
    { "gamepad_right_shoulder_held", "rightShoulderHeld" },
    { "gamepad_both_shoulders_held", "bothShouldersHeld" },
}) do
    local condition, field = entry[1], entry[2]
    state[field] = true
    assert(ns:ConditionIsMet(condition, "gamepad_base", { gamepadExpected = true }))
    assert(ns:ConditionIsMet(condition .. "_yes", "gamepad_base", reaction, true))
    state[field] = false
    assert(ns:ConditionIsMet(condition, "gamepad_base", { gamepadExpected = false }))
    assert(ns:ConditionIsMet(condition .. "_no", "gamepad_base", reaction, true))
    state[field] = nil
    assert(not ns:ConditionIsMet(condition .. "_no", "gamepad_base", reaction, true))
    state[field], state.gameplay = true, false
    assert(not ns:ConditionIsMet(condition .. "_yes", "gamepad_base", reaction, true))
    state.gameplay = true
end
print("PASS: independent gamepad requirements, unknown state, conflicts and profile round trip")

-- Chat/menu input contexts must not release managed bar alpha.
GetTime = function() return 1 end
InCombatLockdown = function() return false end
bar.alpha = 1
function bar:SetAlpha(value) self.alpha = value end
function bar:GetAlpha() return self.alpha end
profile.targets.gamepad_base.reactions = {}
profile.targets.gamepad_base.atRest = 0
for _, gameplay in ipairs({ true, false, true, false }) do
    state.gameplay = gameplay
    for _, id in ipairs({ "gamepad_base", "gamepad_lt", "gamepad_rt", "gamepad_both" }) do
        assert(ns:ResolveTarget(id) == bar, "menu/chat must keep bar resolvable")
    end
    ns.runtime.immediateApply.gamepad_base = true
    ns:ApplyTarget("gamepad_base", 1)
    assert(bar.alpha == 0, "menu/chat must preserve Otherwise opacity")
end
state.enabled = false
ns:ApplyTarget("gamepad_base", 1)
assert(bar.alpha == 1, "disabling companion must still restore native opacity")
print("PASS: menu/chat preserves bar opacity; disabling integration restores it")
state.enabled, state.editing = true, true
ns:ApplyTarget("gamepad_base", 1)
assert(bar.alpha == 1, "GPC editor overrides Otherwise zero")
assert(ns:IsGamepadEditingTarget("gamepad_shoulder_left"))
assert(not ns:IsGamepadEditingTarget("player"))
state.editing = false
ns.runtime.immediateApply.gamepad_base = true
ns:ApplyTarget("gamepad_base", 1)
assert(bar.alpha == 0, "closing GPC restores configured opacity")
assert(profile.targets.gamepad_base.atRest == 0)
print("PASS: temporary GPC opacity override preserves rules")
