-- Run from the addon folder: lua tests/GamepadSafeCinematic.lua .
-- Entering Cinematic Mode must never call Blizzard's window or popup code:
-- on Forever that code runs the gamepad window manager under this addon's
-- taint, and later window opens/closes fail (jump/back stop until /reload).
local root = arg and arg[1] or "."
local driver
GetTime = function() return 10 end
InCombatLockdown = function() return false end
SlashCmdList = {}
C_Timer = { After = function() end, NewTicker = function() return { Cancel = function() end } end }
CreateFrame = function()
    driver = { scripts = {}, events = {} }
    function driver:RegisterEvent(event) self.events[event] = true end
    driver.RegisterUnitEvent = driver.RegisterEvent
    function driver:SetScript(event, fn) self.scripts[event] = fn end
    function driver:GetScript(event) return self.scripts[event] end
    return driver
end
hooksecurefunc = function(object, method, hook)
    local original = assert(object[method])
    object[method] = function(self, ...) original(self, ...); hook(self, ...) end
end
-- Record calls too: the old code wrapped CloseAllWindows in pcall.
local called = {}
local function Forbidden(name)
    return function()
        called[#called + 1] = name
        error("Frame Gambit called Blizzard's " .. name .. " from addon code", 2)
    end
end
CloseAllWindows = Forbidden("CloseAllWindows")
CloseWindows = Forbidden("CloseWindows")
HideUIPanel = Forbidden("HideUIPanel")
ShowUIPanel = Forbidden("ShowUIPanel")
StaticPopup_Hide = Forbidden("StaticPopup_Hide")

local function frame(name, parent, shown)
    local f = { name = name, parent = parent, alpha = 1, shown = shown, strata = "MEDIUM", hooks = {} }
    function f:GetName() return self.name end
    function f:GetParent() return self.parent end
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(value) self.alpha = value end
    function f:IsShown() return self.shown end
    function f:GetFrameStrata() return self.strata end
    function f:IsMouseEnabled() return true end
    function f:HookScript(script, fn)
        self.hooks[script] = self.hooks[script] or {}
        table.insert(self.hooks[script], fn)
    end
    function f:Show() error("Host Show forbidden") end
    function f:Hide() error("Host Hide forbidden") end
    return f
end
local function Fire(f, script)
    for _, fn in ipairs(f.hooks[script] or {}) do fn(f) end
end

UIParent = frame("UIParent", nil, true)
WorldFrame = frame("WorldFrame", nil, true)
local addonWindow = frame("SomeAddonWindow", UIParent, true)
local lateWindow = frame("LateAddonWindow", UIParent, false)
local hud = frame("SomeHUD", UIParent, true)
UISpecialFrames = { "SomeAddonWindow", "LateAddonWindow" }
UIPanelWindows = {}

local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)

-- 1. Entering Cinematic Mode leaves windows open and calls no Blizzard closers.
FrameGambitDB = { profile = "Default", profiles = { Default = {}, ["Cinematic Mode"] = {} }, cinematic = {} }
ns.EnsureCinematicProfile = function() return "Cinematic Mode" end
ns.SelectProfile = function(_, name) FrameGambitDB.profile = name; return true end
ns.PrimeCinematicTargets = function() end
ns.SetCinematicUIMode = function() return true end
local blackouts = 0
local realBlackout = ns.BeginCinematicBlackout
ns.BeginCinematicBlackout = function() blackouts = blackouts + 1; return true end
local ok, reason, entered = ns:ToggleCinematic()
assert(ok and entered and FrameGambitDB.profile == "Cinematic Mode", "Cinematic entry failed: " .. tostring(reason))
assert(blackouts == 1)
assert(#called == 0, "Cinematic entry called Blizzard's " .. tostring(called[1]))
ns.BeginCinematicBlackout = realBlackout

-- 2. An open Escape-closable window stays visible; ordinary HUD still fades.
ns.IsCinematicActive = function() return true end
ns.IsFrameGambitFrame = function() return false end
ns.GetUIParentFrameRoots = function() return { addonWindow, lateWindow, hud } end
ns.GetFramePickerRoot = function(_, f)
    while f and f.parent and f.parent ~= UIParent do f = f.parent end
    return f
end
ns.GetCinematicProfile = function() return { targets = {} } end
assert(ns:BeginCinematicBlackout())
assert(addonWindow.alpha == 1, "An open Escape-closable window must stay visible")
assert(hud.alpha == 0, "HUD still fades in Cinematic Mode")
assert(lateWindow.alpha == 0, "A closed window is part of the scene until it opens")

-- 3. A window opened during the scene surfaces at its own opacity.
lateWindow.shown = true
Fire(lateWindow, "OnShow")
assert(lateWindow.alpha == 1, "An Escape-closable window opened in Cinematic Mode must be visible")

-- 4. The Cinematic camera never hides Blizzard's experimental-CVar popup.
local cvars = { cameraFov = "90", test_cameraOverShoulder = "0", CameraKeepCharacterCentered = "1",
    CameraReduceUnexpectedMovement = "0" }
C_CVar = {
    GetCVar = function(name) return cvars[name] end,
    SetCVar = function(name, value) cvars[name] = tostring(value); return true end,
}
GetCameraZoom = function() return 8 end
UnitRace = function() return "Human", "Human", 1 end
IsMounted = function() return false end
local unregistered = {}
UIParent.UnregisterEvent = function(_, event) unregistered[event] = true end
GameEvent = { UnregisterInternalEvent = function(event) unregistered["game:" .. event] = true end }
FrameGambitDB.cinematic = { cameraFOV = 80, cameraOffsetDefault = false }
assert(loadfile(root .. "/CinematicCamera.lua"))("FrameGambit", ns)
assert(ns:AcquireCinematicCamera())
assert(unregistered.EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED and unregistered["game:EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED"])
assert(cvars.cameraFov == "80", "Cinematic field of view applied")
assert(#called == 0, "Cinematic camera called Blizzard's " .. tostring(called[1]))

print("PASS: Cinematic entry keeps windows open without Blizzard closers; Escape-closable windows stay visible; camera leaves Blizzard popups alone")
