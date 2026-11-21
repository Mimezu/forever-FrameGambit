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
-- The minimap's icons (arrows, pins, quest markers) are drawn on their own
-- layer that ignores opacity: the minimap is hidden for the shot when the
-- game allows it (the same lease as MinimapStack's renderer hide).
-- Opacity 0 on the interface misses what is not under it: one sweep of every
-- frame also takes to 0 the visible frames parented to nothing or to the
-- world, and the frames and textures that ignore their parent's opacity.
-- Each goes back to its own opacity after the shot.

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

local function Call(object, method, ...)
    local fn = object and object[method]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, object, ...)
    if ok and (not issecretvalue or not issecretvalue(value)) then return value end
end
local function Fade(p, object)
    if p.faded[object] then return end
    -- In combat a protected frame is left alone (nameplates go with the world UI).
    if InCombatLockdown and InCombatLockdown() and Call(object, "IsProtected") then return end
    local alpha = Call(object, "GetAlpha")
    if type(alpha) ~= "number" or alpha == 0 then return end
    if pcall(object.SetAlpha, object, 0) then p.faded[object] = alpha end
end
-- Everything that would still show at interface opacity 0.
local function Sweep(p)
    p.faded = {}
    if type(EnumerateFrames) ~= "function" then return end
    local world = WorldFrame
    local frame = EnumerateFrames()
    while frame do
        if frame ~= UIParent and frame ~= world and Call(frame, "IsForbidden") ~= true and Call(frame, "IsVisible") == true then
            local parent = Call(frame, "GetParent")
            if parent == nil or parent == world or Call(frame, "IsIgnoringParentAlpha") == true then Fade(p, frame) end
            -- Textures and text that ignore their frame's opacity.
            local regions = {pcall(frame.GetRegions, frame)}
            if regions[1] then
                for i = 2, #regions do
                    local region = regions[i]
                    if Call(region, "IsIgnoringParentAlpha") == true and Call(region, "IsVisible") == true then Fade(p, region) end
                end
            end
        end
        frame = EnumerateFrames(frame)
    end
end
local function Unsweep(p)
    for object, alpha in pairs(p.faded or {}) do
        -- Something that changed its own opacity meanwhile keeps it.
        if Call(object, "GetAlpha") == 0 then pcall(object.SetAlpha, object, alpha) end
    end
end

local function HideMinimap(p)
    local map = Minimap
    if not map or type(map.Hide) ~= "function" or not map:IsShown() then return end
    local ok, protected = pcall(map.IsProtected, map)
    if not ok or protected ~= false then return end
    if pcall(map.Hide, map) and not map:IsShown() then p.minimap = map end
end

local function Restore()
    local p = pending
    if not p then return end
    pending = nil
    RestoreNames(p)
    if p.world and SetInWorldUIVisibility then pcall(SetInWorldUIVisibility, true) end
    if p.alpha then pcall(UIParent.SetAlpha, UIParent, p.alpha) end
    if p.minimap and not p.minimap:IsShown() then pcall(p.minimap.Show, p.minimap) end
    Unsweep(p)
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
    HideMinimap(p)
    if p.alpha then Sweep(p) end
    -- (names and bars over the world: not in combat, where the game blocks it)
    if SetInWorldUIVisibility and not (InCombatLockdown and InCombatLockdown()) then p.world = pcall(SetInWorldUIVisibility, false) end
    if not pcall(Screenshot) then Restore(); return end
    C_Timer.After(SAFETY, function() if pending == p then Restore() end end)
end
