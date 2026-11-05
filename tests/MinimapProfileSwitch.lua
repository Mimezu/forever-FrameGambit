local root = arg and arg[1] or "Interface/AddOns/FrameGambit"
local normalID = arg and arg[2] == "retail" and "minimap" or "cluster_test"
unpack = unpack or table.unpack
local now = 1
GetTime = function() return now end
InCombatLockdown = function() return false end
IsAltKeyDown = function() return false end
SlashCmdList = {}
C_Timer = { After = function() end }
CreateFrame = function()
    return { RegisterEvent = function() end, RegisterUnitEvent = function() end,
        GetScript = function() end, SetScript = function() end }
end
hooksecurefunc = function(object, name, hook)
    local original = assert(object[name])
    object[name] = function(self, ...) original(self, ...); hook(self, ...) end
end
local function frame(name, parent, alpha)
    local f = { name = name, parent = parent, alpha = alpha or 1, children = {}, ignored = false }
    if parent then parent.children[#parent.children + 1] = f end
    function f:GetName() return self.name end
    function f:GetParent() return self.parent end
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(a) if self.rejectAlpha then error("rejected alpha") end; self.alpha = math.floor(a * 255) / 255 end
    function f:GetEffectiveAlpha() return self.alpha * (not self.ignored and self.parent and self.parent:GetEffectiveAlpha() or 1) end
    function f:IsShown() return true end
    function f:IsVisible() return true end
    function f:GetRect() return 100, 100, 200, 200 end
    function f:GetEffectiveScale() return 1 end
    function f:GetChildren() return unpack(self.children) end
    function f:GetRegions() end
    function f:IsIgnoringParentAlpha() return self.ignored end
    function f:SetIgnoreParentAlpha(v) self.ignored = v end
    return f
end
UIParent = frame("UIParent")
MinimapCluster = frame("MinimapCluster", UIParent)
Minimap = frame("Minimap", frame("MinimapContainer", MinimapCluster))
MinimapCluster.DielFrame = frame(nil, MinimapCluster)
GameTimeFrame = frame("GameTimeFrame", MinimapCluster)
AddonCompartmentFrame = GameTimeFrame
local decoration = frame("decoration", Minimap)
decoration.ignored = true
Minimap.iconScale = 1.3
function Minimap:SetIconScale(s) self.iconScale = s end
function Minimap:GetIconScale() return self.iconScale end
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
ns.runtime.worldReadyAt = -1000 -- already in the world (loading screen gone)
assert(loadfile(root .. "/Targets.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/MinimapStack.lua"))("FrameGambit", ns)
ns.TargetByID.cluster_test = { id = "cluster_test", names = { "MinimapCluster" }, protected = false }
local function settings(alpha)
    return { enabled = true, atRest = alpha, fadeDuration = 0.2, fadeDelay = 0, reactions = {}, nativeMarkerMode = "hide_zero" }
end
FrameGambitDB = { profile = "Default", cinematic = { profileName = "Cinematic Mode" }, profiles = {
    Default = { targets = { [normalID] = settings(0.12) } },
    ["Cinematic Mode"] = { targets = { minimap = settings(0) } },
} }
-- Stub only UI/event setup; use real target leases, profile switches and blackout.
ns.Wake = function() end
ns.RefreshOptions = function() end
ns.BuildStateContext = function() end
ns.UpdateHover = function() end
ns.EnsureCinematicProfile = function() return "Cinematic Mode", FrameGambitDB.profiles["Cinematic Mode"] end
local function apply(alpha, immediate)
    local id = FrameGambitDB.profile == "Default" and normalID or "minimap"
    if alpha then ns:Profile().targets[id].atRest = alpha end
    now = now + 0.06
    if immediate then ns.runtime.immediateApply[id] = true end
    ns:ApplyTarget(id, now)
    ns:UpdateMinimapStack(true)
    ns:UpdateCinematicBlackout(true)
end
local function near(a, b, label)
    assert(math.abs(a - b) < 0.00001, label .. ": " .. a .. " ~= " .. b)
end
apply(0.12, true)
for _ = 1, 5 do
    assert(ns:SelectProfile("Cinematic Mode", true))
    ns:PrimeCinematicTargets()
    ns:BeginCinematicBlackout()
    apply(1, true)
    near(Minimap:GetEffectiveAlpha(), 1, "cinematic reveal must restore faded normal-profile ancestors")
    for _ = 1, 10 do apply(0) end
    near(Minimap:GetEffectiveAlpha(), 0, "cinematic hidden")
    assert(ns:SelectProfile("Default", true))
    near(GameTimeFrame:GetEffectiveAlpha(), Minimap:GetEffectiveAlpha(), "helper already in destination profile")
    near(decoration:GetAlpha(), Minimap:GetEffectiveAlpha(), "escape texture already in destination profile")
    for _ = 1, 10 do apply(1) end
    near(MinimapCluster:GetEffectiveAlpha(), 1, "cluster reveal")
    near(Minimap:GetEffectiveAlpha(), 1, "map reveal")
    near(GameTimeFrame:GetEffectiveAlpha(), 1, "clock reveal")
    near(decoration:GetEffectiveAlpha(), 1, "decoration reveal")
    apply(0.12, true)
end
-- Rejected restoration must not expose the next profile to a faded baseline.
assert(ns:SelectProfile("Cinematic Mode", true))
apply(0, true)
GameTimeFrame.rejectAlpha = true
local switched = ns:SelectProfile("Default", true)
assert(switched == false and FrameGambitDB.profile == "Cinematic Mode")
GameTimeFrame.rejectAlpha = false
assert(ns:SelectProfile("Default", true))
for _ = 1, 12 do apply(1) end
near(Minimap:GetEffectiveAlpha(), 1, "full map opacity after restore retry")
near(GameTimeFrame:GetEffectiveAlpha(), 1, "full clock opacity after restore retry")
for ticks = 0, 6 do
    apply(0.45, true)
    assert(ns:SelectProfile("Cinematic Mode", true))
    ns:PrimeCinematicTargets()
    ns:BeginCinematicBlackout()
    for _ = 1, ticks do apply(0) end
    assert(ns:SelectProfile("Default", true))
    for _ = 1, 12 do apply(1) end
    near(Minimap:GetEffectiveAlpha(), 1, "interrupted fade reveal " .. ticks)
end
print("PASS: repeated and interrupted Cinematic profile switches restore full opacity")
