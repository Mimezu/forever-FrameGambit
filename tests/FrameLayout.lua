-- Experimental size and position rules.
-- Run from the addon folder with Lua 5.1 or LuaJIT: lua5.1 tests/FrameLayout.lua .
local root = arg and arg[1] or "."
unpack = unpack or table.unpack
local now, combat, lockdown, inDungeon = 1, false, false, false
local cursorX, cursorY = 0, 0
local timers = {}
GetTime = function() return now end
InCombatLockdown = function() return lockdown end
IsInInstance = function() return inDungeon, inDungeon and "party" or "none" end
GetCursorPosition = function() return cursorX * 0.8, cursorY * 0.8 end
SlashCmdList = {}
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
CreateFrame = function()
    return { RegisterEvent = function() end, RegisterUnitEvent = function() end,
        SetScript = function() end, GetScript = function() end }
end
local blockedWrites = 0
hooksecurefunc = function(object, name, hook)
    local original = assert(object[name])
    object[name] = function(self, ...) original(self, ...); hook(self, ...) end
end

local FACTORS = {
    TOPLEFT = { -0.5, 0.5 }, TOP = { 0, 0.5 }, TOPRIGHT = { 0.5, 0.5 },
    LEFT = { -0.5, 0 }, CENTER = { 0, 0 }, RIGHT = { 0.5, 0 },
    BOTTOMLEFT = { -0.5, -0.5 }, BOTTOM = { 0, -0.5 }, BOTTOMRIGHT = { 0.5, -0.5 },
}

-- Geometry model: an anchor offset is in the frame's own effective units,
-- so its screen distance is offset * effective scale.
local function Frame(name, parent, width, height)
    local methods = {}
    local f = setmetatable({ name = name, parent = parent, width = width, height = height, scale = 1, points = {},
        shown = true, alpha = 1, protected = false, writes = 0 }, { __index = methods })
    local realF = f
    f = methods
    function f:GetName() return self.name end
    function f:GetParent() return self.parent end
    function f:GetScale() return self.scale end
    function f:GetEffectiveScale() return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1) end
    function f:GetSize() return self.width, self.height end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown end
    function f:IsProtected() return self.protected, self.protected end
    function f:IsForbidden() return false end
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(a) self.alpha = a end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i) local p = self.points[i or 1]; if p then return p[1], p[2], p[3], p[4], p[5] end end
    local function Guard(self)
        if lockdown and self.protected then blockedWrites = blockedWrites + 1; error("blocked") end
        self.writes = self.writes + 1
    end
    function f:SetPoint(point, relTo, relPoint, x, y)
        Guard(self)
        for index, p in ipairs(self.points) do
            if p[1] == point then self.points[index] = { point, relTo, relPoint, x, y }; return end
        end
        self.points[#self.points + 1] = { point, relTo, relPoint, x, y }
    end
    function f:ClearAllPoints() Guard(self); self.points = {} end
    function f:SetAllPoints(relTo) Guard(self); self.points = { { "TOPLEFT", relTo, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", relTo, "BOTTOMRIGHT", 0, 0 } } end
    function f:SetScale(s) Guard(self); self.scale = s end
    -- Screen rectangle in pixels.
    function f:ScreenRect()
        if not self.parent then return 0, 0, self.width * self.scale, self.height * self.scale end
        local p = assert(self.points[1], "no anchor")
        local rel = p[2] or self.parent
        local rl, rb, rw, rh = rel:ScreenRect()
        local rf = FACTORS[p[3]]
        local ax, ay = rl + rw / 2 + rf[1] * rw, rb + rh / 2 + rf[2] * rh
        local e = self:GetEffectiveScale()
        ax, ay = ax + p[4] * e, ay + p[5] * e
        local ff = FACTORS[p[1]]
        local w, h = self.width * e, self.height * e
        local cx, cy = ax - ff[1] * w, ay - ff[2] * h
        return cx - w / 2, cy - h / 2, w, h
    end
    function f:GetRect()
        local l, b, w, h = self:ScreenRect()
        local e = self:GetEffectiveScale()
        return l / e, b / e, w / e, h / e
    end
    return realF
end

UIParent = Frame("UIParent", nil, 2400, 1350)
UIParent.scale = 0.8
function UIParent:ScreenRect() return 0, 0, 1920, 1080 end
EditModeManagerFrame = { active = false }
function EditModeManagerFrame:IsEditModeActive() return self.active end

local party = Frame("TestPartyFrame", UIParent, 200, 100)
party.protected = true
party.points = { { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 100, 50 } }
_G.TestPartyFrame = party
local nested = Frame("TestNestedHost", UIParent, 300, 300)
nested.scale = 0.9
nested.points = { { "CENTER", UIParent, "CENTER", 0, 0 } }
local minimap = Frame("TestMinimap", nested, 140, 140)
minimap.scale = 1.25
minimap.points = { { "TOPRIGHT", nested, "TOPRIGHT", -10, -10 } }
_G.TestMinimap = minimap
local stretched = Frame("TestStretched", UIParent, 10, 10)
stretched.points = { { "TOPLEFT", UIParent, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0 } }
_G.TestStretched = stretched

local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/Targets.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/FrameLayout.lua"))("FrameGambit", ns)
for _, id in ipairs({ "TestPartyFrame", "TestMinimap", "TestStretched" }) do
    ns.TargetByID[id] = { id = id, label = id, names = { id }, protected = id == "TestPartyFrame" }
end
ns.Wake = function() end
ns.RefreshOptions = function() end

local function near(actual, expected, label, tolerance)
    assert(math.abs(actual - expected) < (tolerance or 0.001), label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function center(frame)
    local l, b, w, h = frame:ScreenRect()
    return (l + w / 2) / 0.8, (b + h / 2) / 0.8, w / 0.8, h / 0.8 -- UIParent units
end
local function runTimers()
    local pending = timers; timers = {}
    for _, callback in ipairs(pending) do callback() end
end
local function context()
    local c = ns.runtime.context
    for key in pairs(c) do c[key] = nil end
    c.combat, c.out_of_combat, c.dungeon = combat, not combat, inDungeon
end
local function tick(at)
    now = at or now
    context()
    ns:UpdateHover()
    for id in pairs(ns:Profile().targets) do ns:ApplyTarget(id, now) end
    ns:UpdateFrameLayouts(now)
end

FrameGambitDB = { profile = "Default", profiles = { Default = { targets = {}, groups = {}, links = {}, visibilityLinks = {}, nextReactionID = 100, nextGroupID = 1 } } }
local settings = ns:GetTargetSettings("TestPartyFrame", true)
settings.atRest, settings.fadeInDuration, settings.fadeOutDuration, settings.fadeDelay = 0.12, 0.2, 0.4, 0
settings.reactions = {
    { id = 1, condition = "mouseover", opacity = 1, scale = 1.5, offsetX = 30, offsetY = 30, layoutLine = true },
    { id = 2, condition = "combat", opacity = 1, scale = 1.2, layoutLine = true },
    { id = 3, condition = "dungeon", opacity = 0.5, keepOpacity = true, scale = 1.1, offsetX = 0, offsetY = 40, layoutLine = true },
}
ns.runtime.normalized[settings] = nil
ns:GetTargetSettings("TestPartyFrame")
assert(settings.reactions[1].offsetX == nil and settings.reactions[1].scale == 1.5, "mouseover rules never move")
assert(settings.reactions[3].keepOpacity == true and settings.reactions[3].layoutLine == true, "keep opacity normalized")

-- Nothing set yet on another frame: geometry is never touched.
local untouched = ns:GetTargetSettings("TestMinimap", true)
untouched.reactions = { { id = 9, condition = "combat", opacity = 1 } }
ns.runtime.normalized[untouched] = nil
local baseX, baseY, baseW = center(party)
local minimapX, minimapY, minimapW = center(minimap)
ns.runtime.immediateApply.TestPartyFrame = true
tick(1)
assert(minimap.writes == 0, "a frame without size or position rules is never written")
near(party.alpha, 0.12, "Otherwise opacity")
local x, y, w = center(party)
near(x, baseX, "Otherwise keeps the host centre x"); near(y, baseY, "Otherwise keeps the host centre y"); near(w, baseW, "Otherwise keeps the host size")

-- In a dungeon: size and position from the Keep opacity rule, opacity from Otherwise.
inDungeon = true
ns.runtime.immediateApply.TestPartyFrame = true
tick(2)
near(party.alpha, 0.12, "Keep opacity rule leaves opacity to Otherwise")
now = 2.2; tick(2.2) -- fade-in time 0.2 s
x, y, w = center(party)
near(w, baseW * 1.1, "dungeon size"); near(x, baseX, "scaled around the centre"); near(y, baseY + 40, "moved up 40 UI units")
local record = ns.runtime.layout.records.TestPartyFrame
assert(record.scaleIndex == 3 and record.positionIndex == 3, "dungeon rule decides size and position")

-- In combat as well: combat rule wins size and opacity, dungeon keeps the position.
combat = true
tick(3); tick(3.3)
x, y, w = center(party)
near(party.alpha, 1, "combat opacity")
near(w, baseW * 1.2, "combat size"); near(y, baseY + 40, "position still from dungeon rule")
assert(record.scaleIndex == 2 and record.positionIndex == 3, "independent first matches")

-- Changes toward a rule use the fade-in time (0.2 s), even between rules.
combat = false
tick(4)
tick(4.1) -- halfway
x, y, w = center(party)
near(w, baseW * 1.15, "halfway back to the dungeon size")
tick(4.5)
x, y, w = center(party)
near(w, baseW * 1.1, "back to the dungeon size")

-- Hover: a Mouseover size rule grows the frame; its normal rectangle still counts as hovered.
cursorX, cursorY = baseX, baseY + 40
tick(5); tick(5.3)
x, y, w = center(party)
near(w, baseW * 1.5, "mouseover size")
near(y, baseY + 40, "mouseover never moves the frame")
assert(ns.runtime.hovered.TestPartyFrame, "hovered")

-- The host (Edit Mode) moves the frame: follow its new place, keep our layout.
cursorX, cursorY = -1000, -1000
tick(6); tick(6.5)
party.points = party.points -- host write through the hooked SetPoint:
party:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 300, 50)
runTimers()
x, y, w = center(party)
near(x, baseX + 200 , "host move adopted"); near(y, baseY + 40, "our offset kept on top of the host move"); near(w, baseW * 1.1, "our size kept")
assert(record.base.x == 300, "new host anchor is the base")
-- Host rescale.
party:SetScale(0.5)
runTimers()
x, y, w = center(party)
near(w, baseW * 0.5 * 1.1, "host scale adopted under our size")

-- Edit Mode open: back to the host layout; closed: rules again.
EditModeManagerFrame.active = true
tick(7)
local hostX, hostY, hostW = center(party)
near(hostW, baseW * 0.5, "Edit Mode shows the normal size")
assert(party.points[1][4] == 300 and party.points[1][5] == 50 and party.scale == 0.5, "exact host anchor while Edit Mode is open")
EditModeManagerFrame.active = false
tick(8); tick(8.3) -- eases back in over the fade-in time
x, y, w = center(party)
near(w, hostW * 1.1, "rules again after Edit Mode")
near(x, hostX, "centre kept after Edit Mode"); near(y, hostY + 40, "offset in UI units after Edit Mode")

-- Combat: protected frames are never written during lockdown.
inDungeon = false
settings.reactions[2].scale = 1.3
combat, lockdown = true, true
blockedWrites = 0
tick(9); tick(9.5)
assert(blockedWrites == 0, "no protected writes in combat")
assert(record.waiting, "change waits for combat to end")
combat, lockdown = false, false
tick(10); tick(10.5)
assert(not record.waiting, "applied after combat")
x, y, w = center(party)
near(w, baseW * 0.5, "Otherwise after combat")

-- Combat start: PLAYER_REGEN_DISABLED runs before lockdown and snaps protected frames.
ns:OnLayoutCombatStart()
x, y, w = center(party)
near(w, baseW * 0.5 * 1.3, "combat size applied at combat start, no animation")
assert(ns.runtime.layoutCombatStarting == nil, "combat-start flag cleared")
lockdown = true
ns:OnLayoutCombatStart() -- already locked: does nothing
lockdown = false

-- Minimap nested in a scaled parent: scale around the centre, offset in UI units.
untouched.restScale, untouched.restOffsetX, untouched.restOffsetY = 1.5, -20, 10
tick(11)
x, y, w = center(minimap)
near(w, minimapW * 1.5, "nested size", 0.01); near(x, minimapX - 20, "nested x", 0.01); near(y, minimapY + 10, "nested y", 0.01)

-- Removing the rules writes back the exact host layout.
untouched.restScale, untouched.restOffsetX, untouched.restOffsetY = nil, nil, nil
tick(12)
assert(minimap.points[1][4] == -10 and minimap.points[1][5] == -10 and minimap.scale == 1.25, "exact restore")
assert(not ns.runtime.layout.records.TestMinimap, "released")

-- Frames held by two anchors can only fade.
local stretchedSettings = ns:GetTargetSettings("TestStretched", true)
stretchedSettings.restScale = 1.2
tick(13)
assert(stretched.writes == 0 and ns.runtime.layout.status.TestStretched, "stretched frame is left alone")
assert(not ns:GetFrameLayoutSupport("TestStretched"), "no support for stretched frames")
assert(not ns:GetFrameLayoutSupport("chat"), "chat stays opacity only")
ns:RemoveTarget("TestStretched")

-- Keep opacity Mouseover rows are not the reveal row of a hover group.
assert(ns:CountUnconditionalMouseover({ reactions = { { condition = "mouseover", keepOpacity = true } } }) == 0, "keep row does not reveal")

-- Copy / paste carries every size and position setting.
settings.restScale, settings.restOffsetX, settings.restOffsetY, settings.restLayoutLine = 0.9, 5, -5, true
assert(ns:CopyTargetRules("TestPartyFrame"))
assert(ns:PasteTargetRules("TestMinimap"))
local pasted = ns:GetTargetSettings("TestMinimap")
assert(pasted.restScale == 0.9 and pasted.restOffsetX == 5 and pasted.restOffsetY == -5, "Otherwise layout pasted")
assert(pasted.reactions[3].keepOpacity and pasted.reactions[3].offsetY == 40, "rule layout pasted")

-- Export / import round trip.
local export = assert(ns:ExportProfile("Default"))
assert(export:find("\nK|TestPartyFrame|3|1", 1, true), "keep opacity exported")
assert(export:find("\nZ|TestPartyFrame|3|1.1|0|40", 1, true), "rule layout exported")
assert(export:find("\nY|TestPartyFrame|0.9|5|-5", 1, true), "Otherwise layout exported")
local imported = assert(ns:ParseProfileImport(export))
local target = imported.targets.TestPartyFrame
assert(target.restScale == 0.9 and target.restOffsetX == 5 and target.restLayoutLine, "Otherwise imported")
local byID = {}
for _, reaction in ipairs(target.reactions) do byID[reaction.id] = reaction end
assert(byID[3].keepOpacity and byID[3].scale == 1.1 and byID[3].offsetY == 40 and byID[3].layoutLine, "rule imported")
assert(byID[1].scale == 1.5 and byID[1].offsetX == nil, "mouseover size imported")
assert(byID[2].scale == 1.3 and byID[2].offsetX == nil, "size only imported")
local function payload(body)
    local checksum = 0
    for i = 1, #body do checksum = (checksum + body:byte(i) * i) % 65521 end
    return "FrameGambit-1:" .. string.format("%04X", checksum) .. "\n" .. body
end
local head = "PF1\nT|TestPartyFrame|1|0.12|0.2|0|0.4\nR|TestPartyFrame|5|mouseover|1||\n"
assert(not ns:ParseProfileImport(payload(head .. "Z|TestPartyFrame|5|-|10|10")), "mouseover rows cannot move")
assert(not ns:ParseProfileImport(payload(head .. "Z|TestPartyFrame|5|9|-|-")), "size out of range")
assert(not ns:ParseProfileImport(payload(head .. "Z|TestPartyFrame|5|-|-|-")), "empty layout record")
assert(ns:ParseProfileImport(payload(head .. "Z|TestPartyFrame|5|1.25|-|-")), "mouseover size accepted")
assert(ns:ParseProfileImport(payload("PF1\nT|TestPartyFrame|1|0.12|0.2|0|0.4\nR|TestPartyFrame|5|combat|1||")), "old exports still import")

-- Owner move not yet taken in when the rules go away: keep the move, undo our scale.
local bar = Frame("TestBar", UIParent, 100, 20)
bar.points = { { "CENTER", UIParent, "CENTER", 0, -200 } }
_G.TestBar = bar
ns.TargetByID.TestBar = { id = "TestBar", label = "TestBar", names = { "TestBar" } }
local barSettings = ns:GetTargetSettings("TestBar", true)
barSettings.reactions, barSettings.restScale = {}, 2
tick(20)
assert(bar.scale == 2, "Otherwise size applied")
bar:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
barSettings.restScale = nil
tick(21)
assert(bar.scale == 1 and bar.points[1][5] == -100 and #bar.points == 1, "owner move kept, our scale undone")
runTimers()
-- The owner switches to two anchors: the frame is handed back at its own scale.
barSettings.restScale = 2
tick(22)
assert(bar.scale == 2, "taken over again")
bar:SetPoint("TOP", UIParent, "TOP", 0, 0)
runTimers()
assert(bar.scale == 1 and not ns.runtime.layout.records.TestBar, "two anchors hand the frame back")
-- Rules removed during combat: a protected frame is restored once combat ends.
bar.points = { { "CENTER", UIParent, "CENTER", 0, -200 } }
bar.protected = true
tick(23)
assert(bar.scale == 2, "protected frame sized out of combat")
lockdown = true
barSettings.restScale = nil
tick(24)
assert(bar.scale == 2 and ns.runtime.layout.records.TestBar.releasing, "restore waits for combat")
lockdown = false
tick(25)
assert(bar.scale == 1 and bar.points[1][5] == -200 and not ns.runtime.layout.records.TestBar, "restored after combat")

-- Edit Mode systems wrap SetPoint / SetScale in Lua that notifies the Edit
-- Mode manager. Frame Gambit must write through the engine methods only.
local notified = 0
local system = Frame("TestEditModeSystem", UIParent, 180, 60)
system.points = { { "BOTTOM", UIParent, "BOTTOM", 0, 120 } }
system.SetPointBase, system.SetScaleBase = system.SetPoint, system.SetScale
function system:SetPoint(...) self:SetPointBase(...); notified = notified + 1 end
function system:SetScale(scale) self:SetScaleBase(scale); notified = notified + 1 end
_G.TestEditModeSystem = system
ns.TargetByID.TestEditModeSystem = { id = "TestEditModeSystem", label = "System", names = { "TestEditModeSystem" } }
local systemSettings = ns:GetTargetSettings("TestEditModeSystem", true)
systemSettings.reactions, systemSettings.restScale, systemSettings.restOffsetX, systemSettings.restOffsetY = {}, 1.2, 0, 30
tick(30)
assert(system.scale == 1.2 and notified == 0, "our writes skip the Edit Mode wrappers")
system:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 200) -- Edit Mode applies a new anchor
assert(notified == 1, "host write went through its wrapper")
runTimers()
assert(notified == 1 and ns.runtime.layout.records.TestEditModeSystem.base.y == 200, "host anchor adopted without calling the wrapper")
systemSettings.restScale, systemSettings.restOffsetX, systemSettings.restOffsetY = nil, nil, nil
tick(31)
assert(system.scale == 1 and system.points[1][5] == 200 and notified == 1, "restored through the engine methods")

-- Instant: the rule taking effect decides; no fade time and no wait before returning.
local snap = Frame("TestSnap", UIParent, 100, 40)
snap.points = { { "CENTER", UIParent, "CENTER", 0, -300 } }
_G.TestSnap = snap
ns.TargetByID.TestSnap = { id = "TestSnap", label = "TestSnap", names = { "TestSnap" } }
local snapSettings = ns:GetTargetSettings("TestSnap", true)
snapSettings.fadeInDuration, snapSettings.fadeOutDuration, snapSettings.fadeDelay = 1, 1, 2
snapSettings.reactions = {
    { id = 200, condition = "combat", opacity = 1, scale = 1.5, layoutLine = true, layoutInstant = true },
    { id = 201, condition = "dungeon", opacity = 1, scale = 1.2, layoutLine = true },
}
ns.runtime.normalized[snapSettings] = nil
ns:GetTargetSettings("TestSnap")
assert(snapSettings.reactions[1].layoutInstant and not snapSettings.reactions[2].layoutInstant, "flag kept per rule")
local snapW = select(3, center(snap))
combat, inDungeon = false, false
tick(40)
combat = true
tick(41)
near(select(3, center(snap)), snapW * 1.5, "instant rule applies at once")
combat = false
tick(42) -- back to Otherwise, whose Instant is off: waits 2 s, then fades over 1 s
near(select(3, center(snap)), snapW * 1.5, "return still waits (Otherwise is not instant)")
tick(44.5); tick(45)
near(select(3, center(snap)), snapW * 1.25, "return eases with the fade time", 0.01)
snapSettings.restLayoutLine, snapSettings.restLayoutInstant = true, true
snapSettings.restScale = 1.05
tick(50); tick(51)
near(select(3, center(snap)), snapW * 1.05, "instant Otherwise applies at once")
inDungeon = true
tick(52) -- dungeon rule is not instant: eases toward it over the 1 s fade-in
near(select(3, center(snap)), snapW * 1.05 + (snapW * 1.2 - snapW * 1.05) * 0, "starts easing", 0.01)
tick(52.5)
near(select(3, center(snap)), snapW * 1.125, "halfway to the dungeon size", 0.01)
tick(53.1)
near(select(3, center(snap)), snapW * 1.2, "dungeon size reached")
inDungeon = false
tick(54)
near(select(3, center(snap)), snapW * 1.05, "back to an instant Otherwise with no wait")
-- Copy / paste and export carry the flags.
assert(ns:CopyTargetRules("TestSnap")); assert(ns:PasteTargetRules("TestBar"))
local copied = ns:GetTargetSettings("TestBar")
assert(copied.restLayoutInstant and copied.reactions[1].layoutInstant and not copied.reactions[2].layoutInstant, "pasted")
ns:Profile().targets.TestBar = nil
local snapExport = assert(ns:ExportProfile("Default"))
assert(snapExport:find("\nI|TestSnap|200|1", 1, true) and snapExport:find("\nN|TestSnap|1", 1, true), "exported")
local snapImported = assert(ns:ParseProfileImport(snapExport)).targets.TestSnap
assert(snapImported.restLayoutInstant and snapImported.reactions[1].layoutInstant, "imported")
assert(not ns:ParseProfileImport(payload("PF1\nT|TestSnap|1|0.12|0.2|0|0.4\nR|TestSnap|5|combat|1||\nI|TestSnap|5|0")), "bad instant value")
assert(not ns:ParseProfileImport(payload("PF1\nT|TestSnap|1|0.12|0.2|0|0.4\nI|TestSnap|9|1")), "instant for a missing rule")
ns:RemoveTarget("TestSnap")

-- Grow from: the chosen point of the frame stays where it is on screen.
local pivotFrame = Frame("TestPivot", UIParent, 200, 100)
pivotFrame.scale = 0.9
pivotFrame.points = { { "CENTER", UIParent, "CENTER", 150, -80 } }
_G.TestPivot = pivotFrame
ns.TargetByID.TestPivot = { id = "TestPivot", label = "TestPivot", names = { "TestPivot" } }
local pivotSettings = ns:GetTargetSettings("TestPivot", true)
pivotSettings.reactions = {}
pivotSettings.restScale, pivotSettings.restLayoutLine = 1.5, true
pivotSettings.fadeDelay = 0
local function corner(frame, fx, fy)
    local l, b, w, h = frame:ScreenRect()
    return l + (0.5 + fx) * w, b + (0.5 + fy) * h
end
local FACTOR = {
    TOPLEFT = { -0.5, 0.5 }, TOP = { 0, 0.5 }, TOPRIGHT = { 0.5, 0.5 }, LEFT = { -0.5, 0 }, CENTER = { 0, 0 },
    RIGHT = { 0.5, 0 }, BOTTOMLEFT = { -0.5, -0.5 }, BOTTOM = { 0, -0.5 }, BOTTOMRIGHT = { 0.5, -0.5 },
}
ns.runtime.immediateApply.TestPivot = true
for point, f in pairs(FACTOR) do
    pivotSettings.restScale, pivotSettings.layoutPivot = 1, point ~= "CENTER" and point or nil
    ns:GetTargetSettings("TestPivot")
    ns.runtime.normalized[pivotSettings] = nil
    ns:GetTargetSettings("TestPivot")
    pivotSettings.restScale = 1.5
    tick(60); tick(61)
    local wantX, wantY = corner(pivotFrame, f[1], f[2])
    -- Undo the size to find where the point was: release and measure.
    ns:ReleaseFrameLayout("TestPivot")
    local homeX, homeY = corner(pivotFrame, f[1], f[2])
    near(wantX, homeX, point .. " pivot x stays put", 0.01); near(wantY, homeY, point .. " pivot y stays put", 0.01)
    local _, _, w = center(pivotFrame)
    tick(62); tick(63)
    local _, _, grown = center(pivotFrame)
    near(grown, w * 1.5, point .. " grows by the size", 0.01)
end

-- Offsets stack on top of the pivot.
pivotSettings.layoutPivot, pivotSettings.restScale = "BOTTOMRIGHT", 2
pivotSettings.restOffsetX, pivotSettings.restOffsetY = 25, -15
tick(70); tick(71)
ns:GetTargetSettings("TestPivot")
local grownX, grownY = corner(pivotFrame, 0.5, -0.5)
ns:ReleaseFrameLayout("TestPivot")
local homeX, homeY = corner(pivotFrame, 0.5, -0.5)
near(grownX, homeX + 25 * 0.8, "bottom right corner plus the x offset", 0.01)
near(grownY, homeY - 15 * 0.8, "bottom right corner plus the y offset", 0.01)
tick(72); tick(73)

-- Changing the pivot re-places the frame at once.
pivotSettings.layoutPivot = "TOPLEFT"
tick(74)
local topLeftX, topLeftY = corner(pivotFrame, -0.5, 0.5)
ns:ReleaseFrameLayout("TestPivot")
local homeTLX, homeTLY = corner(pivotFrame, -0.5, 0.5)
near(topLeftX, homeTLX + 25 * 0.8, "new pivot applied on the next tick", 0.01)
tick(75); tick(76)

-- Hover extra area is the frame's Otherwise rectangle. Here a combat rule shrinks
-- the frame to normal size while Otherwise is 2x from the top-left pivot, so the
-- larger Otherwise area still counts as hovered (no flicker), and nothing beyond.
pivotSettings.reactions = { { id = 300, condition = "combat", opacity = 1, scale = 1, layoutLine = true, layoutInstant = true } }
ns.runtime.normalized[pivotSettings] = nil
ns:GetTargetSettings("TestPivot")
combat = true
tick(77); tick(78)
combat = false
combat = true
tick(79)
local shrunk = ns.runtime.layout.records.TestPivot.applied
assert(shrunk.scale == 1, "combat rule applied")
local sl, sb, sw, sh = pivotFrame:ScreenRect()               -- current (normal size) rectangle
local pivotPxX, pivotPxY = sl, sb + sh                          -- top-left pivot
local restLeft, restTop = pivotPxX, pivotPxY                       -- the combat rule sets size only: the offset (25, -15) is already applied
assert(ns:FrameLayoutHoverContains("TestPivot", (restLeft + sw * 2 - 4) / 0.8, (restTop - sh * 2 + 4) / 0.8), "inside the larger Otherwise area")
assert(not ns:FrameLayoutHoverContains("TestPivot", (restLeft + sw * 2 + 40) / 0.8, (restTop - sh * 2 - 40) / 0.8), "beyond the Otherwise area")
combat = false
pivotSettings.reactions = {}
ns:ReleaseFrameLayout("TestPivot")

-- Mouseover grows a small frame: only the small resting area starts it, the large area keeps it.
local grow = Frame("TestGrow", UIParent, 200, 100)
grow.points = { { "CENTER", UIParent, "CENTER", 0, 0 } }
_G.TestGrow = grow
ns.TargetByID.TestGrow = { id = "TestGrow", label = "TestGrow", names = { "TestGrow" } }
local growSettings = ns:GetTargetSettings("TestGrow", true)
growSettings.fadeDelay = 0
growSettings.restScale, growSettings.restLayoutLine, growSettings.restLayoutInstant = 0.75, true, true
growSettings.reactions = { { id = 310, condition = "mouseover", opacity = 1, scale = 1, layoutLine = true, layoutInstant = true } }
ns.runtime.normalized[growSettings] = nil
ns:GetTargetSettings("TestGrow")
local function halfWidth(frame) local _, _, w = center(frame); return w / 2 end
cursorX, cursorY = -5000, -5000
tick(90)
near(halfWidth(grow) * 2, 150, "resting at 75%", 0.01)
local gx, gy = center(grow)
cursorX, cursorY = gx - 90, gy - 45                        -- inside the large (100%) area, outside the small one
tick(91)
near(halfWidth(grow) * 2, 150, "large area alone does not grow the resting frame", 0.01)
cursorX, cursorY = gx + 60, gy + 30                        -- inside the small (75%) area
tick(92)
near(halfWidth(grow) * 2, 200, "small area grows it", 0.01)
cursorX, cursorY = gx - 90, gy - 45                        -- inside the large area only
tick(93); tick(94)
near(halfWidth(grow) * 2, 200, "large area keeps it grown", 0.01)
cursorX, cursorY = gx + 130, gy                            -- beyond the large area
tick(95)
near(halfWidth(grow) * 2, 150, "leaving the large area shrinks it back", 0.01)
cursorX, cursorY = gx - 90, gy - 45
tick(96)
near(halfWidth(grow) * 2, 150, "and the large area alone still does not regrow it", 0.01)
-- A rule that shrinks the frame does not flicker: Otherwise 100%, Mouseover 75%.
growSettings.restScale, growSettings.restLayoutLine = nil, nil
growSettings.reactions[1].scale = 0.75
ns.runtime.normalized[growSettings] = nil
ns:GetTargetSettings("TestGrow")
cursorX, cursorY = gx + 60, gy + 30
tick(97); tick(98)
near(halfWidth(grow) * 2, 150, "mouseover shrinks it", 0.01)
cursorX, cursorY = gx + 90, gy + 45                        -- outside the shrunk frame, inside the resting one
tick(99); tick(100)
near(halfWidth(grow) * 2, 150, "no flicker while still over the resting area", 0.01)
cursorX, cursorY = -5000, -5000
ns:RemoveTarget("TestGrow")

-- Copy / paste and export carry the pivot; bad values are refused.
pivotSettings.layoutPivot, pivotSettings.restScale = "TOPRIGHT", 1.3
ns.runtime.normalized[pivotSettings] = nil
ns:GetTargetSettings("TestPivot")
assert(ns:CopyTargetRules("TestPivot")); assert(ns:PasteTargetRules("TestBar"))
assert(ns:GetTargetSettings("TestBar").layoutPivot == "TOPRIGHT", "pivot pasted")
ns:Profile().targets.TestBar = nil
local pivotExport = assert(ns:ExportProfile("Default"))
assert(pivotExport:find("\nO|TestPivot|TOPRIGHT", 1, true), "pivot exported")
assert(assert(ns:ParseProfileImport(pivotExport)).targets.TestPivot.layoutPivot == "TOPRIGHT", "pivot imported")
assert(not ns:ParseProfileImport(payload("PF1\nT|TestPivot|1|0.12|0.2|0|0.4\nO|TestPivot|MIDDLE")), "unknown pivot refused")
assert(not ns:ParseProfileImport(payload("PF1\nT|TestPivot|1|0.12|0.2|0|0.4\nO|TestPivot|CENTER")), "center is stored as nothing")
pivotSettings.layoutPivot = "sideways"
ns.runtime.normalized[pivotSettings] = nil
ns:GetTargetSettings("TestPivot")
assert(pivotSettings.layoutPivot == nil, "invalid saved pivot dropped")
ns:RemoveTarget("TestPivot")

-- Smoothness: between 20 Hz evaluator ticks, a running transition advances every frame.
local smooth = Frame("TestSmooth", UIParent, 200, 100)
smooth.points = { { "CENTER", UIParent, "CENTER", 0, 200 } }
_G.TestSmooth = smooth
ns.TargetByID.TestSmooth = { id = "TestSmooth", label = "TestSmooth", names = { "TestSmooth" } }
local smoothSettings = ns:GetTargetSettings("TestSmooth", true)
smoothSettings.fadeInDuration, smoothSettings.fadeOutDuration, smoothSettings.fadeDelay = 1, 1, 0
smoothSettings.reactions = { { id = 320, condition = "combat", opacity = 1, scale = 1.5, layoutLine = true } }
ns.runtime.normalized[smoothSettings] = nil
ns:GetTargetSettings("TestSmooth")
combat = false
tick(200)
local smoothW = select(3, center(smooth))
assert(ns.runtime.layout.animating.TestSmooth == nil, "nothing animating at rest")
local writesAtRest = smooth.writes
for frameTime = 200.01, 200.2, 0.01 do ns:StepFrameLayouts(frameTime) end
assert(smooth.writes == writesAtRest, "no work per frame when nothing animates")
combat = true
tick(201)                                                       -- transition starts at t=201 (1 s to 150%)
assert(ns.runtime.layout.animating.TestSmooth, "transition registered")
local before = smooth.writes
local last = select(3, center(smooth))
local steps, monotonic = 0, true
for frameTime = 201.016, 201.99, 0.016 do                       -- ~60 fps, no evaluator tick in between
    ns:StepFrameLayouts(frameTime)
    local w = select(3, center(smooth))
    if w < last - 1e-9 then monotonic = false end
    if w > last + 1e-9 then steps = steps + 1 end
    last = w
end
assert(monotonic and steps >= 55, "size changed on ~60 separate frames, not 20 steps per second (" .. steps .. ")")
near(select(3, center(smooth)), smoothW * 1.5, "close to the target just before the end", smoothW * 0.02)
ns:StepFrameLayouts(202)
near(select(3, center(smooth)), smoothW * 1.5, "target reached")
assert(ns.runtime.layout.animating.TestSmooth == nil, "finished transitions are dropped")
local finished = smooth.writes
ns:StepFrameLayouts(202.05); ns:StepFrameLayouts(202.1)
assert(smooth.writes == finished, "no writes after it finished")
-- A host move during the transition is left to the full pass.
combat = false
tick(203)
smooth:SetPoint("CENTER", UIParent, "CENTER", 0, 150)              -- owner move mid-transition
local writesBefore = smooth.writes
ns:StepFrameLayouts(203.016)
assert(smooth.writes == writesBefore, "per-frame step waits for the full pass after a host move")
runTimers()
combat = false
tick(204); tick(205)
near(select(3, center(smooth)), smoothW, "back to the normal size")
ns:RemoveTarget("TestSmooth")

-- Login / loading-screen priming settles opacity only; sizes and positions wait for the normal passes.
local primed = Frame("TestPrimed", UIParent, 200, 100)
primed.points = { { "CENTER", UIParent, "CENTER", 0, -350 } }
_G.TestPrimed = primed
ns.TargetByID.TestPrimed = { id = "TestPrimed", label = "TestPrimed", names = { "TestPrimed" } }
local primedSettings = ns:GetTargetSettings("TestPrimed", true)
primedSettings.reactions, primedSettings.restScale, primedSettings.restLayoutLine = {}, 1.5, true
primedSettings.atRest = 0
ns:PrimeProfileTargets(true)
assert(primed.writes == 0 and primed.scale == 1, "priming for login does not resize or move frames")
assert(primed.alpha == 0, "but it does settle opacity")
ns:PrimeProfileTargets()
assert(primed.scale == 1.5, "a full prime (leaving Cinematic) applies layouts")
ns:RemoveTarget("TestPrimed")

-- Profile switch and logout write the host layout back.
ns:ReleaseAllFrameLayouts()
assert(not next(ns.runtime.layout.records), "all released")
assert(party.points[1][4] == 300 and party.scale == 0.5, "host layout restored at logout")

print("PASS: size and position rules, Keep opacity, centre scaling, host moves, Edit Mode, combat, restore, copy/paste and export")
