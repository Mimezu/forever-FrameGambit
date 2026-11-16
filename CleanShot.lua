-- Clean screenshot: one key makes the whole interface invisible, takes the
-- game's own screenshot, and brings the interface back as soon as the game
-- reports the picture saved (or failed).
-- Not Alt+Z: hiding and showing the interface makes the game recenter the
-- camera. The interface stays shown at opacity 0 instead, the way Frame
-- Gambit fades frames, so the camera never moves.
-- The hide and the Screenshot() call happen in the same frame, so the picture
-- is of the very next frame drawn: no delay, no fade.
-- All names go too: nameplates (the in-world interface) and the names over
-- characters, red enemy names included (their settings go to 0 for the shot
-- and come back after; out of combat only). The camera framing settings are
-- put back after the shot as a safety net.

BINDING_NAME_FRAMEGAMBIT_CLEAN_SCREENSHOT = "Screenshot without interface"

local SAFETY = 2 -- seconds: bring the interface back even if no event arrives

local NAMES = {
    "UnitNameOwn", "UnitNameNPC", "UnitNameHostleNPC", "UnitNameInteractiveNPC",
    "UnitNameFriendlySpecialNPCName", "UnitNameNonCombatCreatureName",
    "UnitNameFriendlyPlayerName", "UnitNameEnemyPlayerName",
    "UnitNameFriendlyPetName", "UnitNameFriendlyGuardianName", "UnitNameFriendlyMinionName", "UnitNameFriendlyTotemName",
    "UnitNameEnemyPetName", "UnitNameEnemyGuardianName", "UnitNameEnemyMinionName", "UnitNameEnemyTotemName",
}
local CAMERA = {"CameraKeepCharacterCentered", "CameraReduceUnexpectedMovement", "test_cameraDynamicPitch", "test_cameraOverShoulder"}

local pending -- { alpha = UIParent's opacity before, world = true if we hid nameplates, names = {}, camera = {} }

local function Public(value) return not issecretvalue or not issecretvalue(value) end
local function Get(name)
    if not C_CVar or not C_CVar.GetCVar then return nil end
    local ok, value = pcall(C_CVar.GetCVar, name)
    if ok and Public(value) then return value end
end
local function Set(name, value)
    return C_CVar and C_CVar.SetCVar and pcall(C_CVar.SetCVar, name, value) or false
end

local function HideNames(p)
    p.names = {}
    if InCombatLockdown and InCombatLockdown() then return end
    for _, name in ipairs(NAMES) do
        local value = Get(name)
        if value ~= nil and value ~= "0" and Set(name, "0") then p.names[name] = value end
    end
end
local function RestoreNames(p)
    for name, value in pairs(p.names or {}) do
        -- Something you changed meanwhile wins.
        if Get(name) == "0" then Set(name, value) end
    end
end

local function SaveCamera(p)
    p.camera = {}
    for _, name in ipairs(CAMERA) do p.camera[name] = Get(name) end
end
-- Puts the framing back if the game changed it, then refreshes the camera
-- (zoom by 0: the framing applies again without moving anything).
local function RestoreCamera(p, refresh)
    local changed = false
    for name, value in pairs(p.camera or {}) do
        if Get(name) ~= value and Set(name, value) then changed = true end
    end
    if (changed or refresh) and CameraZoomIn then pcall(CameraZoomIn, 0) end
    return changed
end

local function Restore()
    local p = pending
    if not p then return end
    pending = nil
    RestoreNames(p)
    if p.world and SetInWorldUIVisibility then pcall(SetInWorldUIVisibility, true) end
    if p.alpha then pcall(UIParent.SetAlpha, UIParent, p.alpha) end
    RestoreCamera(p)
    -- The game may reframe once the interface is drawn again: check next frame.
    C_Timer.After(0, function() RestoreCamera(p, true) end)
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("SCREENSHOT_SUCCEEDED")
watcher:RegisterEvent("SCREENSHOT_FAILED")
watcher:SetScript("OnEvent", Restore)

function FrameGambit_CleanScreenshot()
    if pending or type(Screenshot) ~= "function" then return end
    local p = {}
    pending = p
    SaveCamera(p)
    HideNames(p)
    -- Already hidden with Alt+Z: it stays hidden, nothing to bring back.
    if UIParent:IsShown() then
        local ok, alpha = pcall(UIParent.GetAlpha, UIParent)
        if ok and type(alpha) == "number" and pcall(UIParent.SetAlpha, UIParent, 0) then p.alpha = alpha end
    end
    if SetInWorldUIVisibility then p.world = pcall(SetInWorldUIVisibility, false) end
    if not pcall(Screenshot) then Restore(); return end
    C_Timer.After(SAFETY, function() if pending == p then Restore() end end)
end
