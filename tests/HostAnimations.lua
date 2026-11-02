-- Host fade animations (Blizzard's status bar fade-in) change alpha without SetAlpha.
-- Frame Gambit must put the rule's opacity back as soon as they end, and must not
-- treat the change as a fade-out with its wait.
-- Run from the addon folder: lua5.1 tests/HostAnimations.lua .
local root = arg and arg[1] or "."
unpack = unpack or table.unpack
local now = 1
GetTime = function() return now end
InCombatLockdown = function() return false end
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
local function Script(owner)
    owner.handlers = {}
    function owner:HookScript(event, fn) self.handlers[event] = self.handlers[event] or {}; table.insert(self.handlers[event], fn) end
    function owner:Fire(event) for _, fn in ipairs(self.handlers[event] or {}) do fn(self) end end
end
local function frame(name, parent)
    local f = { name = name, parent = parent, alpha = 1, groups = {}, shown = true }
    function f:GetName() return self.name end
    function f:GetParent() return self.parent end
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(a) self.alpha = a end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown end
    function f:GetRect() return 100, 100, 200, 20 end
    function f:GetEffectiveScale() return 1 end
    function f:GetAnimationGroups() return unpack(self.groups) end
    return f
end
local function alphaGroup(target)
    local group = {}
    Script(group)
    local animation = { target = target }
    function animation:GetObjectType() return "Alpha" end
    function animation:GetTarget() return self.target end
    function group:GetAnimations() return animation end
    return group
end
UIParent = frame("UIParent")
TestBar = frame("TestBar", UIParent)
TestBar.alpha = 0                                             -- Blizzard's template starts at alpha 0, hidden
local fadeIn = alphaGroup(TestBar)
local translate = {}; Script(translate)
function translate:GetAnimations() return { GetObjectType = function() return "Translation" end } end
TestBar.groups = { fadeIn, translate }

local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/Targets.lua"))("FrameGambit", ns)
ns.runtime.worldReadyAt = -1000
ns.TargetByID.test_bar = { id = "test_bar", names = { "TestBar" }, protected = false }
ns.Wake = function() end
ns.RefreshOptions = function() end
FrameGambitDB = { profile = "Default", profiles = { Default = { targets = {
    test_bar = { enabled = true, atRest = 0, fadeInDuration = 0.2, fadeOutDuration = 0.2, fadeDelay = 0.8, reactions = {} },
}, groups = {}, links = {}, visibilityLinks = {}, nextReactionID = 10, nextGroupID = 1 } } }

ns:ApplyTarget("test_bar", now)
assert(TestBar.alpha == 0, "starts at the rule's 0%")
assert(fadeIn.handlers.OnPlay and fadeIn.handlers.OnFinished and fadeIn.handlers.OnStop, "alpha animation hooked")
assert(not translate.handlers.OnPlay, "non-alpha animations are left alone")

-- Blizzard plays its fade-in: the animation drives alpha up without SetAlpha.
now = 2
fadeIn:Fire("OnPlay")
assert(ns.runtime.hostAnimating[TestBar], "animation noticed")
rawset(TestBar, "alpha", 0.6)                                 -- animated value this frame
ns:HoldAgainstHostAnimations()
assert(TestBar.alpha == 0, "the rule's opacity is written every frame while it plays")

-- It ends with setToFinalAlpha: alpha 1, again without SetAlpha.
rawset(TestBar, "alpha", 1)
fadeIn:Fire("OnFinished")
assert(TestBar.alpha == 0, "the rule's opacity is back the moment the animation ends (" .. TestBar.alpha .. ")")
assert(not ns.runtime.hostAnimating[TestBar], "no longer animating")
assert(ns.runtime.baseAlpha[TestBar] == 1, "the host's final alpha is kept for restoring")

-- A silent host change found by the audit also goes straight back, without the 0.8 s wait.
rawset(TestBar, "alpha", 1)
now = 10
ns:ApplyTarget("test_bar", now)
assert(TestBar.alpha == 0, "audit puts the rule's opacity back at once (" .. TestBar.alpha .. ")")
assert(ns.runtime.fadeOutStarted.test_bar == nil and ns.runtime.transitions.test_bar == nil, "no wait, no fade")

-- Releasing the frame restores the host's alpha.
ns:RemoveTarget("test_bar")
assert(TestBar.alpha == 1, "host alpha restored on release")
print("PASS: host fade animations are held and undone at once; silent host changes snap back; release restores the host alpha")
