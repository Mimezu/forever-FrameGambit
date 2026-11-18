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
local mapShown, mapProtected = true, false
Minimap = {IsShown = function() return mapShown end, Hide = function() mapShown = false end,
    Show = function() mapShown = true end, IsProtected = function() return mapProtected end}
-- Frames for the sweep: under the interface, outside it, ignoring opacity.
WorldFrame = {}
local function Obj(parent, opts)
    opts = opts or {}
    local o = {alpha = opts.alpha or 1, parent = parent, visible = opts.visible ~= false, ignore = opts.ignore,
        protected = opts.protected, regions = opts.regions or {}}
    function o:GetAlpha() return self.alpha end
    function o:SetAlpha(a) self.alpha = a end
    function o:GetParent() return self.parent end
    function o:IsVisible() return self.visible end
    function o:IsIgnoringParentAlpha() return self.ignore end
    function o:IsProtected() return self.protected end
    function o:IsForbidden() return false end
    function o:GetRegions() return unpack(self.regions) end
    return o
end
local normal = Obj(UIParent)
local loose = Obj(nil, {alpha = 0.8})                    -- parented to nothing
local onWorld = Obj(WorldFrame)                          -- a name drawn on the world
local escaping = Obj(normal, {ignore = true, alpha = 0.6}) -- ignores the interface's opacity
local escapingText = Obj(nil, {ignore = true})
local plainText = Obj(nil)
normal.regions = {escapingText, plainText}
local hiddenLoose = Obj(nil, {visible = false})
local plate = Obj(WorldFrame, {protected = true})
local all = {UIParent, WorldFrame, normal, loose, onWorld, escaping, hiddenLoose, plate}
function EnumerateFrames(after)
    if after == nil then return all[1] end
    for i, f in ipairs(all) do if f == after then return all[i + 1] end end
end
UIParent.IsVisible = function() return uiShown end
UIParent.GetParent = function() return nil end
local seenAtShot
function Screenshot() shots = shots + 1; seenAtShot = {hostile = cvars.UnitNameHostleNPC, alpha = uiAlpha, shown = uiShown, world = worldShown, map = mapShown,
    loose = loose.alpha, onWorld = onWorld.alpha, escaping = escaping.alpha, escapingText = escapingText.alpha,
    plainText = plainText.alpha, normal = normal.alpha, hiddenLoose = hiddenLoose.alpha, plate = plate.alpha} end
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
equal(seenAtShot.map, false, "minimap hidden: its icons ignore opacity")
equal(seenAtShot.loose, 0, "a frame outside the interface: gone")
equal(seenAtShot.onWorld, 0, "a frame on the world: gone")
equal(seenAtShot.escaping, 0, "a frame ignoring the interface's opacity: gone")
equal(seenAtShot.escapingText, 0, "a texture ignoring its frame's opacity: gone")
equal(seenAtShot.plainText, 1, "ordinary textures left to the interface's opacity")
equal(seenAtShot.normal, 1, "ordinary frames left to the interface's opacity")
equal(seenAtShot.hiddenLoose, 1, "hidden frames untouched")
-- The game recenters the character when the interface comes back.
cvars.CameraKeepCharacterCentered = "1"; cvars.test_cameraDynamicPitch = "0"
Saved()
equal(uiAlpha, 0.9, "interface back at its own opacity"); equal(worldShown, true, "nameplates back")
equal(mapShown, true, "minimap back")
equal(loose.alpha, 0.8, "outside frame back at its own opacity"); equal(onWorld.alpha, 1, "world frame back")
equal(escaping.alpha, 0.6, "escaping frame back"); equal(escapingText.alpha, 1, "escaping texture back")
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

-- In combat a protected frame on the world is left alone.
combat = true
FrameGambit_CleanScreenshot(); equal(seenAtShot.plate, 1, "combat: protected frame untouched"); equal(seenAtShot.loose, 0, "combat: others still go")
Saved(); RunTimers(); combat = false

-- A protected minimap (combat) is left alone; a hidden one stays hidden.
mapProtected = true
FrameGambit_CleanScreenshot(); equal(seenAtShot.map, true, "protected minimap untouched"); Saved(); RunTimers()
mapProtected, mapShown = false, false
FrameGambit_CleanScreenshot(); Saved(); RunTimers()
equal(mapShown, false, "a minimap you hid stays hidden")
mapShown = true

-- Already hidden with Alt+Z: stays hidden.
uiShown = false
FrameGambit_CleanScreenshot(); Saved(); RunTimers()
equal(uiShown, false, "Alt+Z hidden before: stays hidden"); equal(altZ, 0, "still no Alt+Z")
uiShown = true

print("PASS: " .. passed .. " clean screenshot assertions")
