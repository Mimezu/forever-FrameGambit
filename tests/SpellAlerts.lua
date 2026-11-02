local root = arg and arg[1] or "."
local now = 10
GetTime = function() return now end
InCombatLockdown = function() return false end
SlashCmdList = {}
C_Timer = { After = function() end }
CreateFrame = function()
    return { RegisterEvent = function() end, RegisterUnitEvent = function() end,
        SetScript = function() end, GetScript = function() end }
end
hooksecurefunc = function(object, method, hook)
    local original = assert(object[method])
    object[method] = function(self, ...) original(self, ...); hook(self, ...) end
end
local secret = {}
issecretvalue = function(value) return value == secret end
local function frame(name, parent, alpha)
    local f = { name = name, parent = parent, alpha = alpha or 1, writes = 0, shown = false }
    function f:GetName() return self.name end
    function f:GetParent() return self.parent end
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(value) self.alpha = value; self.writes = self.writes + 1 end
    function f:GetEffectiveAlpha() return self.alpha * (self.parent and self.parent:GetEffectiveAlpha() or 1) end
    function f:IsShown() return self.shown end
    function f:GetRect() return 100, 100, 200, 200 end
    function f:HookScript() end
    function f:Show() error("Host Show forbidden") end
    function f:Hide() error("Host Hide forbidden") end
    function f:SetParent() error("Host reparent forbidden") end
    return f
end
UIParent = frame("UIParent")
SpellActivationOverlayFrame = frame("SpellActivationOverlayFrame", UIParent, 0.7)
local overlay = SpellActivationOverlayFrame
local child = frame(nil, overlay, 0.4)
local hud = frame("UnrelatedHUD", UIParent, 0.8)
local pooled = frame(nil, UIParent, 0.6)
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/Targets.lua"))("FrameGambit", ns)
ns.IsCinematicActive = function() return true end
ns.IsFrameGambitFrame = function() return false end
ns.RefreshCinematicExemptions = function() end
ns.GetUIParentFrameRoots = function() return { overlay, hud, pooled } end
ns.GetCinematicNestedBlackoutFrames = function() return { child } end
local profile = { targets = {} }
ns.Profile = function() return profile end
ns.Wake = function() end
ns.RefreshOptions = function() end
ns.NextReactionID = function() return 1 end
assert(ns.TargetByID.proc_overlay.label == "Spell Proc Overlay")
assert(ns:ResolveTarget("proc_overlay") == overlay)
assert(ns:IsCinematicBlackoutExempt(overlay))
assert(ns:IsCinematicBlackoutExempt(child))
ns:BeginCinematicBlackout()
assert(overlay.alpha == 0.7 and overlay.writes == 0, "Host opacity stays untouched by Cinematic")
assert(child.alpha == 0.4 and child.writes == 0, "Overlay animation opacity stays untouched")
assert(hud.alpha == 0 and pooled.alpha == 0, "Unrelated HUD still blacks out")
local late = frame(nil, frame(nil, overlay), 0.5)
assert(ns:IsCinematicBlackoutExempt(late), "Late anonymous descendants inherit the exemption")
pooled.parent = overlay -- Simulate host pool reuse, never an addon reparent.
now = 11
ns:UpdateCinematicBlackout()
assert(pooled.alpha == 0.6 and not ns.runtime.cinematicBlackout[pooled], "Release an old lease on pool reuse without a forced scan")
assert(not ns:IsCinematicBlackoutExempt(frame(nil, secret)), "Unreadable parents fail closed")
local cyclic = frame(nil)
cyclic.parent = cyclic
assert(not ns:IsCinematicBlackoutExempt(cyclic), "Broken ancestry is bounded")
local settings = ns:GetTargetSettings("proc_overlay", true)
assert(settings.atRest == 0.12, "Existing target defaults stay unchanged")
settings.atRest, settings.reactions = 0, { { condition = "combat", opacity = 1, enabled = true } }
ns.runtime.context.combat = false
ns:ApplyTarget("proc_overlay", now)
assert(overlay.alpha == 0 and child:GetEffectiveAlpha() == 0, "An explicit Otherwise rule controls the whole group")
ns:UpdateCinematicBlackout(true)
assert(overlay.alpha == 0, "The default exemption never overrides explicit rules")
ns.runtime.context.combat = true
ns:ApplyTarget("proc_overlay", now)
assert(overlay.alpha == 1 and child:GetEffectiveAlpha() == 0.4, "Combat condition reveals the group without changing child animation alpha")
assert(child.writes == 0 and late.writes == 0)
ns:RestoreControlledFrame("proc_overlay")
assert(overlay.alpha == 0.7, "Rule ownership restores original host opacity")
assert(ns:GetTargetSettings("proc_overlay").atRest == 0, "Existing configured opacity is preserved")
ns:ApplyTarget("proc_overlay", now)
overlay:SetAlpha(0.35) -- Native Spell Alert Opacity setting changes during ownership.
ns:RestoreControlledFrame("proc_overlay")
assert(overlay.alpha == 0.35, "Release preserves the latest native opacity")
ns:EndCinematicBlackout()
assert(hud.alpha == 0.8 and pooled.alpha == 0.6, "Scene exit restores only its remaining leases")
print("PASS: Spell Alerts default visibility, late/pool descendants, explicit conditions, host opacity, and restoration")
