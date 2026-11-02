local now, combat = 1, false
GetTime = function() return now end
InCombatLockdown = function() return combat end
SlashCmdList = {}
CreateFrame = function()
    return { RegisterEvent = function() end, RegisterUnitEvent = function() end,
        SetScript = function() end, GetScript = function() end }
end
hooksecurefunc = function(object, name, hook)
    local old = assert(object[name])
    object[name] = function(self, ...) old(self, ...); hook(self, ...) end
end
local function frame(parent)
    local f = { parent = parent, shown = true, alpha = 1, hides = 0 }
    function f:GetParent() return self.parent end
    function f:GetChildren() end
    function f:GetRegions() end
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(v) self.alpha = v end
    function f:GetRect() return 100, 100, 200, 200 end
    function f:GetEffectiveScale() return 1 end
    function f:IsShown() return self.shown end
    function f:IsProtected() return self.protected or false end
    function f:Show() if self.rejectShow then error("rejected") end; self.shown = true end
    function f:Hide() self.shown = false; self.hides = self.hides + 1 end
    return f
end
UIParent = frame()
MinimapCluster = frame(UIParent)
Minimap = frame(MinimapCluster)
Minimap.iconScale = 1
function Minimap:GetIconScale() return self.iconScale end
function Minimap:SetIconScale(v) self.iconScale = v end
local ns = {}
assert(loadfile("Interface/AddOns/FrameGambit/Core.lua"))("FrameGambit", ns)
assert(loadfile("Interface/AddOns/FrameGambit/MinimapStack.lua"))("FrameGambit", ns)
local settings = { enabled = true, nativeMarkerMode = "keep" }
ns.GetTargetSettings = function() return settings end
local function fade(alpha, direct)
    ns.runtime.active = { map = { alpha = alpha } }
    ns.runtime.frameByID = { map = direct and Minimap or MinimapCluster }
    ns.runtime.managedIDByFrame = { [ns.runtime.frameByID.map] = "map" }
    now = now + 0.3
    ns:UpdateMinimapStack(true)
end
fade(0)
assert(not Minimap:IsShown() and MinimapCluster:IsShown())
assert(ns:FrameContainsCursor(MinimapCluster, 150, 150))
assert(ns:FrameContainsCursor(Minimap, 150, 150), "retain direct-map hover while renderer is suspended")
local hides = Minimap.hides
ns:UpdateMinimapStack(false)
assert(Minimap.hides == hides, "no repeated Hide calls during stable zero")
Minimap:Show() -- Native quest selection rebuild tries to show the renderer.
assert(not Minimap:IsShown())
fade(0.01)
assert(Minimap:IsShown(), "show at the start of reveal, not only at 100%")
for _, opacity in ipairs({ 0.12, 0.30 }) do
    fade(opacity)
    assert(Minimap:IsShown(), "low-opacity terrain must remain visible")
    assert(Minimap.iconScale == 0, "markers hide at or below 30 percent")
end
fade(0.301)
assert(Minimap:IsShown() and Minimap.iconScale == 1, "markers return above cutoff")
fade(0, true)
assert(not Minimap:IsShown())
fade(0.5, true)
assert(Minimap:IsShown())
fade(0)
Minimap:Hide() -- A host decision while suppressed must survive release.
assert(ns:ReleaseMinimapStack())
assert(not Minimap:IsShown() and not ns:IsMinimapRendererSuppressed(Minimap))
assert(not ns:FrameContainsCursor(Minimap, 150, 150))
Minimap:Show()
fade(0)
Minimap.rejectShow = true
assert(not ns:ReleaseMinimapStack())
assert(ns:HasMinimapStackPendingWork())
Minimap.rejectShow = nil
ns.runtime.active, ns.runtime.frameByID, ns.runtime.managedIDByFrame = {}, {}, {}
ns:UpdateMinimapStack(false)
assert(Minimap:IsShown() and not ns:HasMinimapStackPendingWork())
-- Only unprotected frames are eligible, even before combat starts.
Minimap.protected = true
fade(0)
assert(Minimap:IsShown())
Minimap.protected = false
combat = true
fade(0)
assert(not Minimap:IsShown())
fade(1)
assert(Minimap:IsShown())
-- A new map object releases the old lease.
fade(0)
local old = Minimap
Minimap = frame(MinimapCluster)
Minimap.GetIconScale, Minimap.SetIconScale = old.GetIconScale, old.SetIconScale
Minimap.iconScale = 1
fade(0)
assert(old:IsShown() and not Minimap:IsShown())
assert(ns:ReleaseMinimapStack())
assert(Minimap:IsShown())
print("PASS: native renderer zero gate, early reveal, hover, host visibility, retries, protection and replacement")
