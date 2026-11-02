local root = arg[1] or "Interface/AddOns/FrameGambit"
CreateFrame = function() return { RegisterEvent = function() end, GetScript = function() end, SetScript = function() end } end
SlashCmdList = {}
C_Timer = { After = function() end }
GetTime = function() return 1 end
InCombatLockdown = function() return false end
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/Targets.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/GamepadIntegration.lua"))("FrameGambit", ns)
local function bar()
    return { alpha = 0, SetAlpha = function(self, a) self.alpha = a end,
        GetAlpha = function(self) return self.alpha end,
        IsShown = function() return true end, GetRect = function() return 0, 0, 100, 100 end }
end
local stance, base, unrelated = bar(), bar(), bar()
local page = { actionBars = { base = base }, TopCenteredAnchor = { StanceBar = stance } }
function page:GetActiveBar() return self.active end
GamepadMainActionBarFrame = { PageUnit = page }
local state = { available = true, enabled = true, gameplay = true, activeLayer = "base" }
local notify
GamepadCompanionAPI = { version = 1, GetState = function() return state end,
    GetBarFrame = function() return base end,
    Subscribe = function(_, callback) notify = callback end }
ns.TargetByID.picked_stance = { id = "picked_stance", resolve = function() return stance end }
ns.TargetByID.picked_base = { id = "picked_base", resolve = function() return base end }
ns.TargetByID.unrelated = { id = "unrelated", resolve = function() return unrelated end }
local reaction = { id = 1, enabled = true, condition = "gamepad_bar_active", gamepadExpected = true, opacity = 1 }
FrameGambitDB = { profile = "Default", profiles = { Default = { targets = {
    picked_stance = { enabled = true, atRest = 0, reactions = { reaction } },
} } } }
ns.runtime.inputProfilesReady = true
ns.BuildStateContext = function() end
ns:RefreshGamepadIntegration()
page.active = base
assert(ns:GetGamepadConditionActivity("gamepad_bar_active", "picked_stance") == false)
assert(ns:GetGamepadConditionActivity("gamepad_bar_active", "picked_base") == true)
assert(ns:GetGamepadConditionActivity("gamepad_bar_active", "gamepad_base") == true)
assert(ns:GetGamepadConditionActivity("gamepad_bar_active", "unrelated") == nil)
page.active, state.activeLayer = stance, nil
assert(ns:ReactionIsMet(reaction, "picked_stance"), "selected stance must match Yes")
notify(nil, "native-bar")
assert(stance.alpha == 1, "trigger press must immediately reveal the picked stance bar")
ns.runtime.revealGoal.picked_stance = 1
ns.runtime.fadeOutStarted.picked_stance = 1
ns.runtime.transitions.picked_stance = {}
page.active, state.activeLayer = base, "base"
notify(nil, "native-bar")
assert(stance.alpha == 0, "trigger release must immediately restore Otherwise opacity")
assert(ns.runtime.revealGoal.picked_stance == nil)
assert(ns.runtime.fadeOutStarted.picked_stance == nil)
assert(ns.runtime.transitions.picked_stance == nil)
page.active = stance
state.editing = true
assert(ns:IsGamepadEditingTarget("picked_stance"), "Companion editor must reveal the managed stance bar")
assert(not ns:IsGamepadEditingTarget("unrelated"))
state.editing = false
state.gameplay = false
assert(ns:GetGamepadConditionActivity("gamepad_bar_active", "picked_stance") == nil)
state.gameplay = true
page.active = nil
assert(ns:GetGamepadConditionActivity("gamepad_bar_active", "picked_stance") == nil)
page.GetActiveBar = function() error("unavailable") end
assert(ns:GetGamepadConditionActivity("gamepad_bar_active", "picked_stance") == nil)
print("PASS: picked stance activity, immediate trigger opacity, ordinary bars and unavailable input")
