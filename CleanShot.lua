-- Clean screenshot: one key hides the whole interface (the same switch as
-- Alt+Z), takes the game's own screenshot, and puts the interface back as soon
-- as the game reports the picture saved (or failed).
-- The hide and the Screenshot() call happen in the same frame, so the picture
-- is of the very next frame drawn: no delay, no fade.
-- If the interface was already hidden (you pressed Alt+Z yourself), it stays
-- hidden afterwards.
-- Names over characters (red enemy names included) are not part of the
-- in-world interface: their settings go to 0 for the shot and come back after
-- (out of combat only). The camera framing settings are put back after the
-- shot too: outside gamepad mode the game recenters the character when the
-- interface comes back.

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

local pending -- { ui = true if we hid UIParent, world = true if we hid nameplates, names = {}, camera = {} }

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
    if p.ui and not UIParent:IsShown() then pcall(SetUIVisibility, true) end
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
    if UIParent:IsShown() and SetUIVisibility then
        pcall(SetUIVisibility, false)
        p.ui = not UIParent:IsShown()
    end
    if SetInWorldUIVisibility then p.world = pcall(SetInWorldUIVisibility, false) end
    if not pcall(Screenshot) then Restore(); return end
    C_Timer.After(SAFETY, function() if pending == p then Restore() end end)
end
