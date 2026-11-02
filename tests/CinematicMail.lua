local root = assert(arg[1], "Pass the FrameGambit addon directory")
local combat, active = false, true
GetTime = function() return 10 end
InCombatLockdown = function() return combat end
SlashCmdList = {}
CreateFrame = function()
    return { RegisterEvent = function() end, RegisterUnitEvent = function() end,
        SetScript = function() end, GetScript = function() end }
end
hooksecurefunc = function(object, method, hook)
    local original = assert(object[method])
    object[method] = function(self, ...) original(self, ...); hook(self, ...) end
end
local function frame(name, parent, alpha)
    local f = { name = name, parent = parent, alpha = alpha, shown = false, hooks = {} }
    function f:GetName() return self.name end
    function f:GetParent() return self.parent end
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(value) self.alpha = value end
    function f:IsShown() return self.shown end
    function f:GetFrameStrata() return "MEDIUM" end
    function f:HookScript(event, fn)
        self.hooks[event] = self.hooks[event] or {}
        table.insert(self.hooks[event], fn)
    end
    function f:SetParent() error("Must not reparent host frames") end
    function f:Show() error("Must not show host frames") end
    function f:Hide() error("Must not hide host frames") end
    return f
end
local function hostShown(f, shown)
    f.shown = shown
    for _, fn in ipairs(f.hooks[shown and "OnShow" or "OnHide"] or {}) do fn(f) end
end
UIParent = frame("UIParent", nil, 1)
MailFrame = frame("MailFrame", UIParent, .9)
OpenMailFrame = frame("OpenMailFrame", UIParent, .8)
local hud = frame("TestHUD", UIParent, .7)
UIPanelWindows = { MailFrame = {} } -- The letter is a separate, unregistered root.
local roots = { MailFrame, OpenMailFrame, hud }
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
ns.IsCinematicActive = function() return active end
ns.IsFrameGambitFrame = function() return false end
ns.GetUIParentFrameRoots = function() return roots end
ns.GetFramePickerRoot = function(_, f) return f end
ns.GetCinematicProfile = function() return { targets = {} } end
ns:BeginCinematicBlackout()
assert(hud.alpha == 0)
hostShown(MailFrame, true)
hostShown(OpenMailFrame, true)
assert(MailFrame.alpha == .9)
assert(OpenMailFrame.alpha == .8, "Opening a letter must immediately restore its native alpha")
OpenMailFrame:SetAlpha(.65)
assert(OpenMailFrame.alpha == .65, "Host repaint must retain its requested alpha")
hostShown(OpenMailFrame, false)
ns:BeginCinematicBlackout()
assert(OpenMailFrame.alpha == 0)
combat = true
hostShown(OpenMailFrame, true)
assert(OpenMailFrame.alpha == .65, "Reopening during combat must release the letter blackout")
assert(hud.alpha == 0, "Mail must not reveal unrelated HUD")
combat = false
ns:EndCinematicBlackout()
assert(hud.alpha == .7 and OpenMailFrame.alpha == .65)
-- Entry/reload with a letter already open.
ns:BeginCinematicBlackout()
assert(OpenMailFrame.alpha == .65 and hud.alpha == 0)
ns:EndCinematicBlackout()
-- A lazily created letter is recognized by the next existing discovery scan.
OpenMailFrame = frame("OpenMailFrame", UIParent, .75)
roots[2] = OpenMailFrame
hostShown(OpenMailFrame, true)
ns:BeginCinematicBlackout()
assert(OpenMailFrame.alpha == .75)
ns:EndCinematicBlackout()
active = false
hostShown(OpenMailFrame, false)
hostShown(OpenMailFrame, true)
assert(OpenMailFrame.alpha == .75, "Normal mode leaves mail untouched")
print("PASS: Cinematic mail open/reopen, combat, host repaint, entry, late discovery and restoration")
