-- Run from the client root: lua Interface/AddOns/FrameGambit/tests/ForeverLetterbox.lua
local frames = {}
local function frame(name, parent)
    local f = {name = name, parent = parent, alpha = 1, shown = true, scale = 1, points = {}, scripts = {}, events = {}}
    function f:GetParent() return self.parent end
    function f:GetEffectiveScale() return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1) end
    function f:SetScale(scale) self.scale = scale end
    function f:GetHeight() return self.height end
    function f:SetHeight(height) self.height = height end
    function f:SetAlpha(alpha) self.alpha = alpha end
    function f:GetEffectiveAlpha() return self.alpha * (self.parent and self.parent:GetEffectiveAlpha() or 1) end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(shown) self.shown = shown end
    function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function f:SetPoint(...) self.points[#self.points + 1] = {...} end
    function f:SetFrameStrata(strata) self.strata = strata end
    function f:SetFrameLevel(level) self.level = level end
    function f:EnableMouse(enabled) self.mouse = enabled end
    function f:RegisterEvent(event) self.events[event] = true end
    function f:SetScript(script, fn) self.scripts[script] = fn end
    function f:CreateTexture()
        self.texture = {
            SetAllPoints = function() end,
            SetColorTexture = function(_, r, g, b, a) self.color = {r, g, b, a} end,
        }
        return self.texture
    end
    frames[#frames + 1] = f
    return f
end
UIParent = frame('UIParent')
UIParent.height = 1350
UIParent.scale = 0.8
CreateFrame = function(_, name, parent) return frame(name, parent) end
C_Timer = {After = function(_, fn) fn() end}
FrameGambitDB = {cinematic = {letterboxEnabled = true, letterboxHeight = 0.04}}
local active = true
local ns = {IsCinematicActive = function() return active end}
assert(loadfile('Interface/AddOns/FrameGambit/CinematicLetterbox.lua'))('FrameGambit', ns)
local watcher = frames[#frames]
ns:RefreshCinematicLetterbox()
local top, bottom = ns.CinematicLetterboxTop, ns.CinematicLetterboxBottom
local function checkVisible()
    for _, bar in ipairs({top, bottom}) do
        assert(bar:IsVisible(), 'Cinematic border disappeared with the HUD')
        assert(bar:GetEffectiveAlpha() == 1, 'Cinematic border inherited the HUD fade')
        assert(bar:GetEffectiveScale() == UIParent:GetEffectiveScale(), 'UI scale mismatch')
        assert(bar.strata == 'LOW' and bar.level == 1 and bar.mouse == false)
        assert(bar.color[1] == 0 and bar.color[2] == 0 and bar.color[3] == 0 and bar.color[4] == 1)
        assert(ns:IsCinematicLetterboxFrame(bar), 'Border must remain exempt from Frame Gambit fading')
    end
end
checkVisible()
assert(top.height == 54 and bottom.height == 54)
assert(top.points[1][1] == 'TOPLEFT' and top.points[2][1] == 'TOPRIGHT')
assert(bottom.points[1][1] == 'BOTTOMLEFT' and bottom.points[2][1] == 'BOTTOMRIGHT')
assert(top.points[1][2] == UIParent and bottom.points[1][2] == UIParent)
local count = #frames

-- DialogueUI fades UIParent first, then either hides it or leaves alpha at 0
-- with UIModeUtil. Both paths must preserve the borders without a refresh.
for _, alpha in ipairs({1, 0.75, 0.25, 0}) do
    UIParent:SetAlpha(alpha)
    checkVisible()
end
UIParent:SetAlpha(1)
UIParent:Hide()
checkVisible()
UIParent:SetAlpha(0)
checkVisible()

-- Display/scale updates retain the physical screen-height percentage.
UIParent.scale = 0.64
UIParent.height = 1687.5
watcher.scripts.OnEvent(watcher, 'UI_SCALE_CHANGED')
checkVisible()
assert(math.abs(top.height * top:GetEffectiveScale() - 1080 * 0.04) < 0.65)
assert(#frames == count, 'Refresh created duplicate borders')

active = false
ns:RefreshCinematicLetterbox()
assert(not top:IsVisible() and not bottom:IsVisible())
UIParent:Show()
UIParent:SetAlpha(1)
assert(not top:IsVisible() and not bottom:IsVisible(), 'Closing dialogue restored disabled borders')
active = true
ns:RefreshCinematicLetterbox()
checkVisible()
UIParent:Hide()
ns:SetCinematicLetterboxEnabled(false)
assert(not top:IsVisible() and not bottom:IsVisible())
ns:SetCinematicLetterboxEnabled(true)
checkVisible()
ns:SetCinematicLetterboxHeight(0)
assert(not top:IsVisible() and not bottom:IsVisible())
ns:SetCinematicLetterboxHeight(0.1)
checkVisible()
assert(FrameGambitDB.cinematic.letterboxHeight == 0.1)
assert(not UIParent:IsVisible() and UIParent.alpha == 1, 'Letterbox changed the HUD state')
print('PASS: cinematic borders survive DialogueUI HUD fade/hide, retain scale/geometry, and obey mode and letterbox settings')
