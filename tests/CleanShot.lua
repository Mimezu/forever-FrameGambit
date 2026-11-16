-- Clean screenshot key: names over characters hidden for the shot, camera
-- framing put back after. Run from the addon folder: lua5.1 tests/CleanShot.lua .
local root = arg and arg[1] or "."
local passed = 0
local function check(ok, label) assert(ok, label); passed = passed + 1 end
local function equal(a, b, label) check(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end

local watcher
function CreateFrame()
    local f = {scripts = {}, events = {}}
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(e, fn) self.scripts[e] = fn end
    watcher = f
    return f
end
local timers = {}
C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
local function RunTimers() local list = timers; timers = {}; for _, fn in ipairs(list) do fn() end end

local cvars = {UnitNameHostleNPC = "1", UnitNameNPC = "0", UnitNameEnemyPlayerName = "1", UnitNameOwn = "1",
    CameraKeepCharacterCentered = "0", CameraReduceUnexpectedMovement = "0", test_cameraDynamicPitch = "1", test_cameraOverShoulder = "0"}
C_CVar = {GetCVar = function(n) return cvars[n] end, SetCVar = function(n, v) cvars[n] = tostring(v); return true end}
local combat = false
function InCombatLockdown() return combat end
local uiShown, worldShown, shots, zooms = true, true, 0, 0
local uiAlpha, altZ = 0.9, 0
UIParent = {IsShown = function() return uiShown end, GetAlpha = function() return uiAlpha end,
    SetAlpha = function(_, a) uiAlpha = a end}
function SetUIVisibility(v) altZ = altZ + 1; uiShown = v end
function SetInWorldUIVisibility(v) worldShown = v end
local seenAtShot
function Screenshot() shots = shots + 1; seenAtShot = {hostile = cvars.UnitNameHostleNPC, alpha = uiAlpha, shown = uiShown, world = worldShown} end
function CameraZoomIn() zooms = zooms + 1 end

assert(loadfile(root .. "/CleanShot.lua"))("FrameGambit", {})
local function Saved() watcher.scripts.OnEvent(watcher, "SCREENSHOT_SUCCEEDED") end

-- The shot: no interface, no names over characters.
FrameGambit_CleanScreenshot()
equal(shots, 1, "screenshot taken")
equal(seenAtShot.hostile, "0", "red enemy names off for the shot")
equal(seenAtShot.alpha, 0, "interface invisible"); equal(seenAtShot.shown, true, "but not hidden: no Alt+Z")
equal(altZ, 0, "Alt+Z never used"); equal(seenAtShot.world, false, "nameplates hidden")
equal(cvars.UnitNameOwn, "0", "every name over characters off")
-- The game recenters the character when the interface comes back.
cvars.CameraKeepCharacterCentered = "1"; cvars.test_cameraDynamicPitch = "0"
Saved()
equal(uiAlpha, 0.9, "interface back at its own opacity"); equal(worldShown, true, "nameplates back")
equal(cvars.UnitNameHostleNPC, "1", "red enemy names back")
equal(cvars.UnitNameEnemyPlayerName, "1", "enemy player names back")
equal(cvars.UnitNameNPC, "0", "a name setting that was off stays off")
equal(cvars.CameraKeepCharacterCentered, "0", "framing put back: not centered")
equal(cvars.test_cameraDynamicPitch, "1", "framing put back: lower character")
check(zooms >= 1, "camera refreshed")
-- Reframed again once the interface is drawn: caught next frame.
cvars.CameraKeepCharacterCentered = "1"
RunTimers()
equal(cvars.CameraKeepCharacterCentered, "0", "next frame: framing put back again")

-- A name setting you change during the shot wins.
FrameGambit_CleanScreenshot()
cvars.UnitNameHostleNPC = "1"; cvars.UnitNameOwn = "0"
Saved(); RunTimers()
equal(cvars.UnitNameOwn, "1", "restored when still off")

-- In combat: interface hidden, name settings left alone.
combat = true
FrameGambit_CleanScreenshot()
equal(seenAtShot.hostile, "1", "combat: name settings untouched")
Saved(); RunTimers()
equal(cvars.UnitNameHostleNPC, "1", "combat: nothing to restore")
combat = false

-- Already hidden with Alt+Z: stays hidden.
uiShown = false
FrameGambit_CleanScreenshot(); Saved(); RunTimers()
equal(uiShown, false, "Alt+Z hidden before: stays hidden"); equal(altZ, 0, "still no Alt+Z")
uiShown = true

print("PASS: " .. passed .. " clean screenshot assertions")
