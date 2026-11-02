local root = arg and arg[1] or "."
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

FrameGambitDB = { profile = "Default", profiles = { Default = { targets = {
    minimap = { enabled = true, atRest = 0, fadeDuration = 0.65, fadeDelay = 0, reactions = {} },
} } } }
ns.Wake = function() end
ns.RefreshOptions = function() end
local function near(a, b, label)
    assert(math.abs(a - b) < 0.00001, label .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
local settings = ns:GetTargetSettings("minimap")
near(settings.fadeInDuration, 0.65, "legacy fade in")
near(settings.fadeOutDuration, 0.65, "legacy fade out")
settings.fadeInDuration, settings.fadeOutDuration = 0.3, nil
ns:GetTargetSettings("minimap")
near(settings.fadeInDuration, 0.3, "keep explicit fade in")
near(settings.fadeOutDuration, 0.65, "missing fade out fallback")
settings.fadeInDuration, settings.fadeOutDuration = nil, 1.2
ns:GetTargetSettings("minimap")
near(settings.fadeInDuration, 0.65, "missing fade in fallback")
near(settings.fadeOutDuration, 1.2, "keep explicit fade out")
settings.fadeInDuration, settings.fadeOutDuration = 0.2, 0.8
assert(ns:CopyTargetRules("minimap"))
assert(ns:PasteTargetRules("cluster_test"))
local pasted = ns:GetTargetSettings("cluster_test")
near(pasted.fadeInDuration, 0.2, "paste fade in")
near(pasted.fadeOutDuration, 0.8, "paste fade out")
ns:Profile().targets.cluster_test = nil
local imported = assert(ns:ParseProfileImport(assert(ns:ExportProfile("Default"))))
near(imported.targets.minimap.fadeInDuration, 0.2, "round trip fade in")
near(imported.targets.minimap.fadeOutDuration, 0.8, "round trip fade out")
local function payload(body)
    local checksum = 0
    for i = 1, #body do checksum = (checksum + body:byte(i) * i) % 65521 end
    return "FrameGambit-1:" .. string.format("%04X", checksum) .. "\n" .. body
end
local legacy = assert(ns:ParseProfileImport(payload("PF1\nT|minimap|1|0|0.75|0")))
near(legacy.targets.minimap.fadeInDuration, 0.75, "legacy import fade in")
near(legacy.targets.minimap.fadeOutDuration, 0.75, "legacy import fade out")
assert(not ns:ParseProfileImport(payload("PF1\nT|minimap|1|0|0.75|0|bad")))
assert(not ns:ParseProfileImport(payload("PF1\nT|minimap|1|0|0.75|0|3")))
for _, width in ipairs({ 2, 4 }) do
    local escaped = payload("PF1\nT|minimap|1|0|0.2|0|0.8"):gsub("|", string.rep("|", width))
    local decoded = assert(ns:ParseProfileImport(escaped))
    near(decoded.targets.minimap.fadeInDuration, 0.2, "escaped separate fade in")
    near(decoded.targets.minimap.fadeOutDuration, 0.8, "escaped separate fade out")
    local oldEscaped = payload("PF1\nT|minimap|1|0|0.75|0"):gsub("|", string.rep("|", width))
    local oldDecoded = assert(ns:ParseProfileImport(oldEscaped))
    near(oldDecoded.targets.minimap.fadeOutDuration, 0.75, "escaped legacy fade")
end
local function tick(at, alpha)
    now = at
    if alpha ~= nil then settings.atRest = alpha end
    ns:ApplyTarget("minimap", now)
    return ns.runtime.currentAlpha[Minimap]
end
ns.runtime.immediateApply.minimap = true
tick(1, 0)
tick(2, 1)
near(tick(2.1), 0.5, "fade in halfway")
near(tick(2.2), 1, "fade in complete")
tick(3, 0)
near(tick(3.4), 0.5, "fade out halfway")
near(tick(3.8), 0, "fade out complete")
settings.fadeDelay = 0.4
tick(4, 1)
near(tick(4.2), 1, "fade in ignores fade-out wait")
tick(5, 0)
near(tick(5.2), 1, "fade out waits")
near(tick(5.4), 1, "fade out starts after wait")
near(tick(5.8), 0.5, "delayed fade out halfway")
near(tick(6.2), 0, "delayed fade out complete")
-- Fades advance every frame between 20 Hz evaluator ticks.
settings.fadeInDuration, settings.fadeOutDuration, settings.fadeDelay = 1, 1, 0
tick(20, 0); tick(21, 0)
assert(next(ns.runtime.transitions) == nil, "nothing fading")
local idleWrites, realSetAlpha = 0, Minimap.SetAlpha
Minimap.SetAlpha = function(self, a) idleWrites = idleWrites + 1; realSetAlpha(self, a) end
for t = 21.01, 21.2, 0.01 do ns:StepAlphaTransitions(t) end
assert(idleWrites == 0, "no per-frame work while nothing fades")
tick(22, 1)                                                     -- fade-in starts at t=22 (1 s)
assert(next(ns.runtime.transitions), "fade registered")
local last, changes, monotonic = ns.runtime.currentAlpha[Minimap], 0, true
for t = 22.016, 22.99, 0.016 do                                 -- ~60 fps, no evaluator tick in between
    ns:StepAlphaTransitions(t)
    local a = ns.runtime.currentAlpha[Minimap]
    if a < last - 1e-9 then monotonic = false end
    if a > last + 1e-9 then changes = changes + 1 end
    last = a
end
assert(monotonic and changes >= 55, "opacity moved on ~60 separate frames (" .. changes .. ")")
assert(math.abs(ns.runtime.currentAlpha[Minimap] - 0.976) < 0.005, "linear: 97.6% at t=22.976")
ns:StepAlphaTransitions(23)
near(ns.runtime.currentAlpha[Minimap], 1, "fade completes")
assert(next(ns.runtime.transitions) == nil, "finished fade dropped")
local doneWrites = idleWrites
ns:StepAlphaTransitions(23.05); ns:StepAlphaTransitions(23.1)
assert(idleWrites == doneWrites, "no writes after the fade ended")
Minimap.SetAlpha = realSetAlpha
tick(24, 1)
near(ns.runtime.currentAlpha[Minimap], 1, "the evaluator and the per-frame step agree")
-- First capture: a frame Frame Gambit has never controlled starts in its rule state
-- (0% with a long wait), instead of appearing at full opacity until the wait ends.
FirstCapture = frame("FirstCapture", UIParent, 1)
ns.TargetByID.first_capture = { id = "first_capture", names = { "FirstCapture" }, protected = false }
local first = ns:GetTargetSettings("first_capture", true)
first.atRest, first.fadeInDuration, first.fadeOutDuration, first.fadeDelay, first.reactions = 0, 0.2, 0.2, 3.9, {}
ns.runtime.normalized[first] = nil
now = 50
ns:ApplyTarget("first_capture", now)
assert(FirstCapture.alpha == 0, "first capture snaps to the rule state (alpha " .. tostring(FirstCapture.alpha) .. ")")
assert(next({ [1] = ns.runtime.transitions.first_capture }) == nil, "no fade was started")
-- Re-capturing the same frame later (for example after a profile switch) still fades gently.
ns:RestoreControlledFrame("first_capture")
assert(FirstCapture.alpha == 1, "restored to the host alpha")
now = 60
ns:ApplyTarget("first_capture", now)
assert(FirstCapture.alpha == 1, "re-capture waits before fading out")
now = 64
ns:ApplyTarget("first_capture", now)
now = 64.1
ns:ApplyTarget("first_capture", now)
assert(FirstCapture.alpha < 1, "and fades out after the wait")
ns:RemoveTarget("first_capture")
-- The frame containing the minimap stays at its host opacity until the loading screen
-- is gone and the map has drawn, then snaps to its rule state (no wait, no fade).
ns.TargetByID.cluster_hold = { id = "cluster_hold", names = { "MinimapCluster" }, protected = false }
local hold = ns:GetTargetSettings("cluster_hold", true)
hold.atRest, hold.fadeInDuration, hold.fadeOutDuration, hold.fadeDelay, hold.reactions = 0.5, 0.2, 0.2, 3.9, {}
ns.runtime.normalized[hold] = nil
assert(ns:FrameContainsMinimap(MinimapCluster) and ns:FrameContainsMinimap(Minimap), "cluster and map count")
MinimapCluster.alpha = 1
ns.runtime.worldReadyAt = nil                                 -- loading screen still up
now = 100
ns:PrimeProfileTargets(true)
assert(MinimapCluster.alpha == 1, "login priming leaves the minimap frame at its host opacity")
ns:ApplyTarget("cluster_hold", now)
now = 110
ns:ApplyTarget("cluster_hold", now)
assert(MinimapCluster.alpha == 1, "held at full opacity while the loading screen is up")
-- Zoom nudge must happen while the map is still at full opacity.
Minimap.zoom, Minimap.zoomLog = 2, {}
function Minimap:GetZoom() return self.zoom end
function Minimap:GetZoomLevels() return 6 end
function Minimap:SetZoom(z) self.zoom = z; self.zoomLog[#self.zoomLog + 1] = { zoom = z, alpha = MinimapCluster.alpha } end
now = 130                                                     -- a slow loading screen: still no event
ns:ApplyTarget("cluster_hold", now)
assert(MinimapCluster.alpha == 1 and #Minimap.zoomLog == 0, "a long loading screen keeps it held (no early fallback)")
ns.runtime.worldReadyAt = 130                                 -- loading screen gone
now = 130.3
ns:ApplyTarget("cluster_hold", now)
assert(MinimapCluster.alpha == 1 and #Minimap.zoomLog == 0, "still held for a moment so the map can draw")
now = 130.55
ns:ApplyTarget("cluster_hold", now)
assert(#Minimap.zoomLog == 1 and Minimap.zoomLog[1].zoom == 3 and Minimap.zoomLog[1].alpha == 1, "zoom nudged while at full opacity")
assert(MinimapCluster.alpha == 1, "held while the map redraws")
now = 131.1
ns:ApplyTarget("cluster_hold", now)
assert(math.abs(MinimapCluster.alpha - 0.5) < 0.01, "then snaps to Otherwise at once, ignoring the 3.9 s wait (" .. MinimapCluster.alpha .. ")")
assert(ns.runtime.transitions.cluster_hold == nil and ns.runtime.captureHold.cluster_hold == nil, "no fade, hold released")
ns:RemoveTarget("cluster_hold")
print("PASS: legacy and partial timing migration, copy/paste, old/new exports, separate animation durations and fade-out delay")
