-- Run from the client directory with Lua 5.1 or LuaJIT.
local addonRoot = arg and arg[1] or "Interface/AddOns/FrameGambit"
CreateFrame = function()
    return { RegisterEvent = function() end, RegisterUnitEvent = function() end,
        SetScript = function() end, GetScript = function() end }
end
SlashCmdList = {}
C_Timer = { After = function() end }
local now = 1
GetTime = function() return now end
local secret = {}
issecretvalue = function(value) return value == secret end
local ns = {}
assert(loadfile(addonRoot .. "/Core.lua"))("FrameGambit", ns)
assert(loadfile(addonRoot .. "/Targets.lua"))("FrameGambit", ns)
local function frame(parent, scale, rect)
    local f = { parent = parent, scale = scale, rect = rect, children = {}, shown = true }
    if parent then parent.children[#parent.children + 1] = f end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown end
    function f:GetParent() return self.parent end
    function f:GetChildren() return unpack(self.children) end
    function f:GetRect() return unpack(self.rect) end
    function f:GetEffectiveScale()
        if self.failScale then error("unreadable") end
        if self.overrideScale ~= nil then return self.overrideScale end
        return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1)
    end
    return f
end
local function rectEquals(f, expected, descendants)
    local actual
    if descendants then actual = { ns:GetFrameInteractionRect(f, true) }
    else actual = { ns:GetUsableFrameRect(f) } end
    for i = 1, 4 do
        assert(actual[i] and math.abs(actual[i] - expected[i]) < 0.00001,
            "rect coordinate " .. i .. ": got " .. tostring(actual[i]) .. ", expected " .. expected[i])
    end
end
UIParent = frame(nil, 0.8, { 0, 0, 1920, 1080 })
local rawX, rawY = 0, 0
GetCursorPosition = function() return rawX, rawY end
local function cursor(x, y)
    rawX, rawY = x * UIParent:GetEffectiveScale(), y * UIParent:GetEffectiveScale()
end
-- A reduced vertical bar: the old raw outline was larger and farther up.
local bags = frame(UIParent, 0.75, { 8, 280, 80, 640 })
rectEquals(bags, { 6, 210, 60, 480 })
cursor(36, 230)
assert(ns:FrameContainsCursor(bags), "Cursor on the real bottom of the bar must hit")
assert(ns:FrameInteractionContainsCursor(bags, false))
cursor(36, 800)
assert(not ns:FrameContainsCursor(bags), "Old displaced outline must not trigger hover")
assert(not ns:FrameInteractionContainsCursor(bags, false))
-- Nested scale changes, including a minimap with independent Edit Mode scale.
local holder = frame(UIParent, 1.2, { 0, 0, 100, 100 })
local map = frame(holder, 0.5, { 1600, 800, 300, 300 })
rectEquals(map, { 960, 480, 180, 180 })
assert(ns:FrameContainsCursor(map, 970, 490))
assert(not ns:FrameContainsCursor(map, 1700, 900))
local extra = frame(map, 2, { 950, 400, 25, 25 })
rectEquals(map, { 960, 480, 210, 180 }, true)
assert(ns:FrameInteractionContainsCursor(map, true, 1160, 490), "Scaled minimap child hover")
-- A zero-sized logical container derives one union in the same coordinate space.
local logical = frame(UIParent, 1, { 0, 0, 0, 0 })
frame(logical, 2, { 10, 20, 30, 40 })
frame(logical, 0.5, { 200, 100, 40, 60 })
local union = { ns:GetFrameInteractionRect(logical, false) }
for i, value in ipairs({ 20, 40, 100, 80 }) do assert(math.abs(union[i] - value) < 0.00001) end
-- Uniform UI scaling cancels out; later target scale changes are read afresh.
UIParent.scale = 0.64
rectEquals(bags, { 6, 210, 60, 480 })
bags.scale = 1
rectEquals(bags, { 8, 280, 80, 640 })
bags.scale = 1.5
rectEquals(bags, { 12, 420, 120, 960 })
-- Invalid or secret scales must not be used for arithmetic or hit testing.
for _, value in ipairs({ 0, -1, math.huge, 0/0, secret, "bad" }) do
    bags.overrideScale = value
    assert(ns:GetUsableFrameRect(bags) == nil)
    assert(not ns:FrameContainsCursor(bags, 20, 500))
end
bags.overrideScale = nil
bags.failScale = true
assert(ns:GetUsableFrameRect(bags) == nil)
bags.failScale = false
UIParent.overrideScale = 0
assert(ns:GetUsableFrameRect(bags) == nil)
UIParent.overrideScale = nil
bags.shown = false
assert(ns:GetUsableFrameRect(bags) == nil)
print("PASS: scaled geometry, bag/minimap hover, mixed-scale descendants and unreadable scales")
