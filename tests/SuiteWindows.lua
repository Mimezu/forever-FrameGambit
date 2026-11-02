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
WorldFrame = frame("WorldFrame")
BindCardsFrame = frame("BindCardsFrame", UIParent, 0.85)
local child = frame(nil, BindCardsFrame, 0.6)
ResonanceMinimapButton = frame("ResonanceMinimapButton", UIParent, 0.9)
local hud = ResonanceMinimapButton
local roots = { BindCardsFrame, hud }
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/SuiteWindows.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/Targets.lua"))("FrameGambit", ns)
local cinematic = true
ns.IsCinematicActive = function() return cinematic end
ns.IsFrameGambitFrame = function() return false end
ns.RefreshCinematicExemptions = function() end
ns.GetUIParentFrameRoots = function() return roots end
ns.GetCinematicNestedBlackoutFrames = function() return { child } end
local profile = { targets = {} }
ns.Profile = function() return profile end
ns.Wake = function() end
ns.RefreshOptions = function() end
ns.NextReactionID = function() return 1 end
assert(ns:IsCinematicBlackoutExempt(BindCardsFrame))
assert(ns:IsCinematicBlackoutExempt(child))
ns:BeginCinematicBlackout()
assert(BindCardsFrame.alpha == .85 and child.alpha == .6)
assert(hud.alpha == 0, "Suite minimap button must remain HUD")
-- Hidden window created after entry remains exempt before slash-command Show.
WardrobeTimeCapsuleFrame = frame("WardrobeTimeCapsuleFrame", UIParent, .95)
roots[#roots+1] = WardrobeTimeCapsuleFrame
ns:BeginCinematicBlackout()
assert(WardrobeTimeCapsuleFrame.alpha == .95)
assert(ns:IsCinematicSuiteWindow(frame(nil, WardrobeTimeCapsuleFrame)))
-- Registered anonymous dialogs and recycled HUD frames release stale leases.
assert(FrameGambitAPI.RegisterCinematicWindow(hud))
now = now + 1
ns:UpdateCinematicBlackout()
assert(hud.alpha == .9)
assert(not FrameGambitAPI.RegisterCinematicWindow(UIParent))
assert(not FrameGambitAPI.RegisterCinematicWindow(secret))
assert(not ns:IsCinematicSuiteWindow(secret))
local cycle = frame(nil); cycle.parent = cycle
assert(not ns:IsCinematicSuiteWindow(cycle))
local fake = frame("BindCardsFrame", UIParent)
assert(not ns:IsCinematicSuiteWindow(fake), "Only actual global identity is exempt")
ns:RegisterTarget({ id="suite_test", label="Test dialog", names={"BindCardsFrame"} })
local settings = ns:GetTargetSettings("suite_test", true)
settings.atRest, settings.reactions, settings.fadeInDuration, settings.fadeOutDuration = 0, {}, .05, .05
ns:ApplyTarget("suite_test", now)
assert(BindCardsFrame.alpha == .85, "Explicit rule cannot hide suite window in Cinematic")
cinematic = false
ns:ApplyTarget("suite_test", now)
now = now + 3; ns:ApplyTarget("suite_test", now)
assert(BindCardsFrame.alpha == 0, "Normal profile behavior preserved")
cinematic = true
ns:ApplyTarget("suite_test", now)
assert(BindCardsFrame.alpha == .85, "Cinematic returns dialog to native ownership")
print("PASS: suite windows, late slash-command dialogs, descendants, rule bypass, HUD exclusions and restoration")
