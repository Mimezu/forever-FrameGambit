-- Run from the client directory, optionally passing another addon directory.
local root = arg and arg[1] or "Interface/AddOns/FrameGambit"
unpack = unpack or table.unpack
CreateFrame = function()
    return { RegisterEvent = function() end, RegisterUnitEvent = function() end,
        SetScript = function() end, GetScript = function() end }
end
SlashCmdList = {}
C_Timer = { After = function() end }
local now, combat = 1, false
GetTime = function() return now end
InCombatLockdown = function() return combat end
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/Targets.lua"))("FrameGambit", ns)
local function frame(parent, scale, rect)
    local f = { parent = parent, scale = scale, rect = rect, alpha = 0.12, shown = true }
    function f:GetRect() return unpack(self.rect) end
    function f:GetEffectiveScale() return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1) end
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(value) self.alpha = value end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown end
    function f:GetChildren() end
    return f
end
local function near(a, b) assert(a and math.abs(a - b) < 0.00001, tostring(a) .. " ~= " .. b) end
UIParent = frame(nil, 0.8, { 0, 0, 1920, 1080 })
PlayerFrame = frame(UIParent, 1.2, { 100, 50, 200, 80 })
TargetFrame = frame(UIParent, 0.75, { 700, 50, 200, 80 })
assert(loadfile(root .. "/EUIUnitVisibility.lua"))("FrameGambit", ns)
FrameGambitDB = { profile = "Default", profiles = { Default = { targets = {} } } }
local profile = ns:Profile()
for _, id in ipairs({ "eui_player", "eui_target" }) do
    profile.targets[id] = { enabled = true, atRest = 0.12, reactions = {
        { id = 1, enabled = true, condition = "mouseover", opacity = 1 },
    } }
end
local x, y = 0, 0
GetCursorPosition = function() return x * UIParent:GetEffectiveScale(), y * UIParent:GetEffectiveScale() end
local function hover(id, inside)
    local target = assert(ns:ResolveTarget(id))
    local left, bottom, width, height = ns:GetUsableFrameRect(target)
    assert(left, id .. " adapter must expose readable scaled geometry")
    x, y = left + width / 2, bottom + height / 2
    if not inside then x = left + width + 50 end
    ns:UpdateHover()
    assert(ns.runtime.hovered[id] == inside, id .. " hover state")
    near(ns:Evaluate(id, profile.targets[id]), inside and 1 or 0.12)
end
-- Exercise the exact right-side outline method, not merely picker geometry.
local file = assert(io.open(root .. "/Options.lua", "r"))
local source = file:read("*a"); file:close()
local first = assert(source:find("function ns:RefreshSelectionOutline()", 1, true))
local last = assert(source:find("\nfunction ns:", first + 1, true))
assert((loadstring or load)("local ns, C = ...\n" .. source:sub(first, last - 1)))(ns, ns.COLORS)
local outline = { scripts = {} }
function outline:SetScript(key, value) self.scripts[key] = value end
function outline:GetScript(key) return self.scripts[key] end
function outline:Hide() self.shown = false end
function outline:Show() self.shown = true end
function outline:ClearAllPoints() end
function outline:SetPoint(_, _, _, left, bottom) self.left, self.bottom = left, bottom end
function outline:SetSize(width, height) self.width, self.height = width, height end
function outline:SetBackdropBorderColor() end
ns.SelectionOutline = outline
ns.Options = { IsVisible = function() return true end, selectionOutlineEnabled = true }
local function checkOutline(id)
    ns.Options.selected = id
    ns:RefreshSelectionOutline()
    assert(outline.shown, id .. " right-side outline must be shown")
    local left, bottom, width, height = ns:GetUsableFrameRect(ns:ResolveTarget(id))
    near(outline.left, left - 3); near(outline.bottom, bottom - 3)
    near(outline.width, width + 6); near(outline.height, height + 6)
end
for _, inCombat in ipairs({ false, true }) do
    combat = inCombat
    for _, id in ipairs({ "eui_player", "eui_target" }) do
        hover(id, true); hover(id, false); checkOutline(id)
    end
end
combat = false
-- The player's visibility wrapper can cover the screen. Geometry must use
-- the visual unit frame and its scale, never the wrapper's rectangle/scale.
local wrapper = frame(UIParent, 2, { 0, 0, 1920, 1080 })
EllesmereUIUnitFrames_Player = frame(wrapper, 0.5, { 300, 200, 220, 90 })
EllesmereUIUnitFrames_Player._visWrap = wrapper
hover("eui_player", true); checkOutline("eui_player")
local proxy = assert(ns:ResolveTarget("eui_player"))
near(proxy:GetEffectiveScale(), EllesmereUIUnitFrames_Player:GetEffectiveScale())
-- Other adapters implement the same coordinate contract.
ChatFrame1 = frame(UIParent, 0.7, { 50, 50, 300, 180 })
EllesmereUI = { _ModuleNS = { EUIChat = { ECHAT = { SetChatAlpha = function() end } } } }
-- EUI's module names are resolved below using the adapter's real contract.
EllesmereUI._ModuleNS.EllesmereUIChat = EllesmereUI._ModuleNS.EUIChat
assert(loadfile(root .. "/EUIChatVisibility.lua"))("FrameGambit", ns)
local chat = assert(ns:ResolveTarget("chat"))
assert(ns:GetUsableFrameRect(chat))
local base = frame(UIParent, 0.5, { 100, 100, 200, 100 })
local rows = frame(UIParent, 1, { 100, 100, 200, 100 })
Details = { GetInstance = function(_, index) if index == 1 then return { baseframe = base, rowframe = rows } end end }
assert(loadfile(root .. "/DetailsAdapter.lua"))("FrameGambit", ns)
local meter = assert(ns:ResolveTarget("details_window_1"))
local left, bottom, width, height = ns:GetUsableFrameRect(meter)
near(left, 50); near(bottom, 50); near(width, 250); near(height, 150)
for _, id in ipairs({ "chat", "details_window_1" }) do
    profile.targets[id] = profile.targets.eui_target
    hover(id, true); hover(id, false); checkOutline(id)
end
-- Forever-only native controller composites have the same adapter contract.
local shoulders = loadfile(root .. "/GamepadShoulders.lua")
if shoulders then
    GamepadMainActionBarFrame = { PageUnit = {
        LeftShoulderBackground = frame(UIParent, 0.5, { 100, 100, 50, 30 }),
        LeftShoulderIcon = frame(UIParent, 0.5, { 100, 100, 50, 30 }),
        LeftShoulderHighlight = frame(UIParent, 0.5, { 100, 100, 50, 30 }),
    } }
    shoulders("FrameGambit", ns)
    profile.targets.gamepad_shoulder_left = profile.targets.eui_target
    hover("gamepad_shoulder_left", true); checkOutline("gamepad_shoulder_left")
    GamepadPersistentInputLegend = frame(UIParent, 1, { 0, 0, 0, 0 })
    GamepadPersistentInputLegend.groups = { GAMEPLAY = { base, rows } }
    assert(loadfile(root .. "/GamepadLegend.lua"))("FrameGambit", ns)
    profile.targets.gamepad_input_legend = profile.targets.eui_target
    hover("gamepad_input_legend", true); checkOutline("gamepad_input_legend")
end
print("PASS: real player/target hover evaluation, right-side outlines, combat, wrappers and composite scales")
