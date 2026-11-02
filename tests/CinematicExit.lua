local root = arg and arg[1] or "Interface/AddOns/FrameGambit"
GetTime = function() return 1 end
InCombatLockdown = function() return false end
SlashCmdList = {}
C_Timer = { After = function() end }
CreateFrame = function() return { RegisterEvent = function() end, RegisterUnitEvent = function() end, SetScript = function() end } end
local function frame()
    local f = { alpha = 1 }
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(value) if self.rejectAlpha then error("blocked") end; self.alpha = value end
    function f:IsShown() return true end
    function f:GetRect() return 0, 0, 100, 20 end
    return f
end
ExitHidden, ExitVisible = frame(), frame()
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/Targets.lua"))("FrameGambit", ns)
assert(ns:RegisterTarget({ id = "exit_hidden", label = "Hidden", names = { "ExitHidden" } }))
assert(ns:RegisterTarget({ id = "exit_visible", label = "Visible", names = { "ExitVisible" } }))
local function settings(opacity, reactions)
    return { enabled = true, atRest = opacity, fadeDelay = 10, fadeInDuration = 2, fadeOutDuration = 2, reactions = reactions or {} }
end
FrameGambitDB = { profile = "Cinematic Mode", cinematic = { profileName = "Cinematic Mode" }, profiles = {
    ["Cinematic Mode"] = { targets = { exit_hidden = settings(0), exit_visible = settings(0) } },
    Default = { targets = { exit_hidden = settings(0), exit_visible = settings(0, { { condition = "player_health", percentageOperator = "<", percentageThreshold = 70, opacity = 0.5 } }) } },
} }
UnitExists = function(unit) return unit == "player" end
UnitHealth, UnitHealthMax = function() return 40 end, function() return 100 end
ns.Wake, ns.RefreshOptions = function() end, function() end
ns.SetCinematicUIMode = function() return true end
local contextCount, hoverCount = 0, 0
local build = ns.BuildStateContext
ns.BuildStateContext = function(self) contextCount = contextCount + 1; return build(self) end
ns.UpdateHover = function() hoverCount = hoverCount + 1 end
ns:PrimeCinematicTargets()
assert(ExitHidden.alpha == 0 and ExitVisible.alpha == 0)
contextCount, hoverCount = 0, 0
assert(ns:SelectProfile("Default", true))
assert(ExitHidden.alpha == 0, "hidden target must settle before SelectProfile returns")
assert(ExitVisible.alpha == 0.5, "evaluate active rules, not only resting opacity")
assert(contextCount == 1 and hoverCount == 1, "one shared snapshot at exit")
assert(not next(ns.runtime.transitions) and not next(ns.runtime.fadeOutStarted), "no reveal-then-fade on exit")
ns:RestoreControlledFrame("exit_hidden")
assert(ExitHidden.alpha == 1, "preserve native baseline across immediate switch")
-- A blocked native restore must retain the destination's immediate-apply flag.
assert(ns:SelectProfile("Cinematic Mode", true))
ns:PrimeCinematicTargets()
ExitHidden.rejectAlpha = true
assert(ns:SelectProfile("Default", true))
assert(ns.runtime.pendingRestore[ExitHidden])
assert(ns.runtime.immediateApply.exit_hidden)
ExitHidden.rejectAlpha = false
ns:ApplyTarget("exit_hidden", 1)
assert(ExitHidden.alpha == 0 and not ns.runtime.pendingRestore[ExitHidden])
assert(not ns.runtime.immediateApply.exit_hidden)
print("Cinematic exit settles current rules synchronously; deferred restoration stays immediate")
