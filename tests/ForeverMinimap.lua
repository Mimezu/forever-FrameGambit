-- Run from the client directory with Lua 5.1 or LuaJIT.
local function near(actual, expected, label)
    assert(math.abs(actual - expected) < 0.00001,
        (label or "value") .. ": expected " .. expected .. ", got " .. actual)
end
local now = 1
GetTime = function() return now end
InCombatLockdown = function() return false end
hooksecurefunc = function(object, method, hook)
    local original = assert(object[method])
    object[method] = function(self, ...)
        original(self, ...)
        hook(self, ...)
    end
end
local function frame(parent, alpha, ignored)
    local f = { parent = parent, alpha = alpha or 1, ignored = ignored or false, children = {}, regions = {} }
    if parent then parent.children[#parent.children + 1] = f end
    function f:GetParent() return self.parent end
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(value)
        if self.rejectAlpha then error("blocked") end
        self.alpha = value
    end
    function f:IsIgnoringParentAlpha() return self.ignored end
    function f:SetIgnoreParentAlpha(value)
        if self.rejectInheritance then error("blocked") end
        self.ignored = value
    end
    function f:GetChildren() return unpack(self.children) end
    function f:GetRegions() return unpack(self.regions) end
    function f:GetEffectiveAlpha()
        return self.alpha * (not self.ignored and self.parent and self.parent:GetEffectiveAlpha() or 1)
    end
    return f
end
UIParent = frame()
MinimapCluster = frame(UIParent)
local container = frame(MinimapCluster)
Minimap = frame(container, 0.8)
Minimap.iconScale = 1.4
function Minimap:GetIconScale() return self.iconScale end
function Minimap:SetIconScale(value)
    if self.rejectScale then error("blocked") end
    self.iconScale = value
end
local terrainChild = frame(Minimap, 0.6)
local ring = frame(Minimap, 0.7, true)
local clusterOverlay = frame(MinimapCluster, 0.9, true)
-- A Texture returned only by GetRegions must be discovered, too.
MinimapCluster.children[#MinimapCluster.children] = nil
MinimapCluster.regions[1] = clusterOverlay
MinimapCluster.DielFrame = frame(MinimapCluster, 0.75)
GameTimeFrame = frame(UIParent, 0.8)
local ns = { runtime = { active = {}, frameByID = {}, managedIDByFrame = {} } }
local settings = {}
function ns:GetTargetSettings(id) return settings[id] end
assert(loadfile("Interface/AddOns/FrameGambit/MinimapStack.lua"))("FrameGambit", ns)
local function manage(id, f, alpha, mode)
    settings[id] = { enabled = true, nativeMarkerMode = mode }
    ns.runtime.active[id] = { alpha = alpha }
    ns.runtime.frameByID[id] = f
    ns.runtime.managedIDByFrame[f] = id
    f:SetAlpha(alpha)
end
local function fade(id, value)
    ns.runtime.active[id].alpha = value
    ns.runtime.frameByID[id]:SetAlpha(value)
    now = now + 0.3
    ns:UpdateMinimapStack(true)
end
local function unmanage(id)
    local f = ns.runtime.frameByID[id]
    ns.runtime.managedIDByFrame[f] = nil
    ns.runtime.frameByID[id] = nil
    ns.runtime.active[id] = nil
    settings[id] = nil
end
manage("custom_cluster", MinimapCluster, 0)
ns:UpdateMinimapStack(true)
near(Minimap:GetEffectiveAlpha(), 0, "inherited map alpha")
near(Minimap.alpha, 0.8, "cluster fading never overwrites map alpha")
near(ring.alpha, 0, "map escape texture")
near(clusterOverlay.alpha, 0, "cluster escape texture")
near(Minimap.iconScale, 0, "hidden icons")
assert(not Minimap.ignored)
fade("custom_cluster", 0.5)
near(Minimap:GetEffectiveAlpha(), 0.4, "terrain fades once")
near(terrainChild:GetEffectiveAlpha(), 0.24, "child fades once")
near(ring.alpha, 0.35)
near(clusterOverlay.alpha, 0.45)
near(MinimapCluster.DielFrame:GetEffectiveAlpha(), 0.375, "day/night inherits once")
near(GameTimeFrame.alpha, 0.4, "optional globals after nil holes")
near(Minimap.iconScale, 1.4, "icons return at partial opacity")
ring:SetAlpha(0.6)
near(ring.alpha, 0.3, "host repaint composed")
fade("custom_cluster", 0)
Minimap:SetIconScale(1.8)
near(Minimap.iconScale, 0, "host scale stays hidden")
Minimap.iconScale = 1 -- Simulate native compositor rebuilding without a Lua call.
now = now + 0.3
ns:UpdateMinimapStack(false)
near(Minimap.iconScale, 0, "native rebuild audit")
fade("custom_cluster", 1)
near(Minimap.iconScale, 1.8, "latest host scale restored")
near(Minimap.alpha, 0.8)
unmanage("custom_cluster")
ring.rejectAlpha = true
ns:UpdateMinimapStack(true)
assert(ns:HasMinimapStackPendingWork())
ring.rejectAlpha = false
ns:UpdateMinimapStack(false)
assert(not Minimap.ignored)
near(Minimap.alpha, 0.8, "host map alpha restored")
near(ring.alpha, 0.6, "latest host texture alpha restored")
near(clusterOverlay.alpha, 0.9)
near(GameTimeFrame.alpha, 0.8)
assert(not ns:HasMinimapStackPendingWork())
-- Existing retail controls remain effective, including explicit keep/scale.
manage("minimap", Minimap, 0, "keep")
ns:UpdateMinimapStack(true)
near(Minimap.iconScale, 0, "low-opacity marker cutoff overrides keep")
settings.minimap.nativeMarkerMode = "scale"
fade("minimap", 0.5)
near(Minimap.iconScale, 0.9, "scale with map")
unmanage("minimap")
Minimap.rejectScale = true
ns:UpdateMinimapStack(false)
assert(ns:HasMinimapStackPendingWork())
Minimap.rejectScale = false
ns:UpdateMinimapStack(false)
near(Minimap.iconScale, 1.8, "rejected restoration retried")
-- A separate map target must capture the untouched host alpha.
Minimap:SetAlpha(0.8)
manage("custom_cluster", MinimapCluster, 0)
ns:UpdateMinimapStack(true)
near(Minimap.alpha, 0.8, "handoff baseline")
assert(not Minimap.ignored)
manage("minimap", Minimap, 1, "hide_zero")
ns:UpdateMinimapStack(true)
near(Minimap.iconScale, 0, "cluster still hides separately controlled icons")
near(Minimap.alpha, 1, "separate map target not leased")
unmanage("custom_cluster")
MinimapCluster:SetAlpha(1)
ns:UpdateMinimapStack(true)
near(Minimap.iconScale, 1.8)
unmanage("minimap")
ns:UpdateMinimapStack(true)
-- A setter-only client uses the retail fallback, then tracks host changes.
Minimap.GetIconScale = nil
ns = { runtime = { active = {}, frameByID = {}, managedIDByFrame = {} }, GetTargetSettings = ns.GetTargetSettings }
assert(loadfile("Interface/AddOns/FrameGambit/MinimapStack.lua"))("FrameGambit", ns)
manage("custom_cluster", MinimapCluster, 0)
ns:UpdateMinimapStack(true)
near(Minimap.iconScale, 0)
fade("custom_cluster", 1)
near(Minimap.iconScale, 1, "setter-only restoration")
-- Late-created overlays are discovered while the map is already hidden.
fade("custom_cluster", 0)
local lateOverlay = frame(MinimapCluster, 0.65, true)
ns:UpdateMinimapStack(true)
near(lateOverlay.alpha, 0)
unmanage("custom_cluster")
lateOverlay.rejectAlpha = true
ns:UpdateMinimapStack(false)
assert(ns:HasMinimapStackPendingWork())
lateOverlay.rejectAlpha = false
ns:UpdateMinimapStack(false)
near(lateOverlay.alpha, 0.65)
assert(not Minimap.ignored)
assert(not ns:HasMinimapStackPendingWork())
-- Missing optional client APIs must not stop texture fading or error.
Minimap.SetIconScale = nil
Minimap.SetIgnoreParentAlpha = nil
manage("custom_cluster", MinimapCluster, 0)
ns:UpdateMinimapStack(true)
near(clusterOverlay.alpha, 0)
local available = ns:GetMinimapNativeMarkerAvailability("hide_zero")
assert(available == false)
unmanage("custom_cluster")
ns:UpdateMinimapStack(true)
-- /fg minimapdebug must never error, whatever the state, and saves its lines.
do
    local realPrint = print
    print = function() end
    FrameGambitDB = type(FrameGambitDB) == "table" and FrameGambitDB or {}
    local ok, err = pcall(function() ns:PrintMinimapDiagnostics(); ns:PrintMinimapDiagnostics() end)
    print = realPrint
    assert(ok, "minimapdebug failed: " .. tostring(err))
    local runs = FrameGambitDB.minimapDebug
    assert(#runs == 2 and #runs[2].lines >= 6, "minimapdebug saved its state")
end
print("PASS: Forever minimap cluster fading, native markers, restoration and ownership")
