-- Key setters, minimap button and the Options > AddOns page.
-- Run from the addon folder: lua5.1 tests/KeysAndMinimap.lua .
local root = arg and arg[1] or "."

-- Generic fake frame: unknown methods are no-ops; scripts and points recorded.
local frames = {}
local function FakeFrame(kind, name, parent)
    local f = { kind = kind, name = name, parent = parent, scripts = {}, shown = true, events = {}, width = 140 }
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:GetScript(event) return self.scripts[event] end
    function f:HookScript() end
    function f:RegisterEvent(event) self.events[event] = true end
    function f:GetParent() return self.parent end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown end
    function f:SetPoint(...) self.point = { ... } end
    function f:ClearAllPoints() self.point = nil end
    function f:GetWidth() return self.width end
    function f:GetFrameLevel() return 2 end
    function f:IsIgnoringParentAlpha() return self.ignoreParentAlpha == true end
    function f:SetIgnoreParentAlpha(v) self.ignoreParentAlpha = v end
    function f:SetText(t) self.text = t end
    function f:GetText() return self.text end
    function f:SetChecked(v) self.checked = v end
    function f:GetChecked() return self.checked end
    function f:EnableKeyboard(v) self.keyboard = v end
    function f:CreateTexture() return FakeFrame("Texture", nil, self) end
    function f:CreateFontString() return FakeFrame("FontString", nil, self) end
    setmetatable(f, { __index = function() return function() end end })
    if kind == "CheckButton" then f.Text = FakeFrame("FontString", nil, f) end
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end

GetTime = function() return 0 end
local combat = false
InCombatLockdown = function() return combat end
SlashCmdList = {}
C_Timer = { After = function() end }
CreateFrame = function(kind, name, parent) return FakeFrame(kind, name, parent) end

-- Binding API double.
local bindings, saveFails = {}, false
local modifiers = {}
GetBindingKey = function(action)
    local keys = {}
    for key, bound in pairs(bindings) do if bound == action then keys[#keys + 1] = key end end
    table.sort(keys)
    return keys[1], keys[2]
end
GetBindingAction = function(key) return bindings[key] or "" end
SetBinding = function(key, action) bindings[key] = action; return true end
SaveBindings = function() return not saveFails end
GetCurrentBindingSet = function() return 1 end
GetBindingText = function(key) return key end
IsShiftKeyDown = function() return modifiers.shift end
IsControlKeyDown = function() return modifiers.ctrl end
IsAltKeyDown = function() return modifiers.alt end

local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)

-- Every binding in Bindings.xml has a name and appears in KEY_ACTIONS.
local xml = assert(io.open(root .. "/Bindings.xml")):read("*a")
local listed = 0
for action in xml:gmatch('<Binding name="([%w_]+)"') do
    listed = listed + 1
    local found
    for _, entry in ipairs(ns.KEY_ACTIONS) do if entry.action == action then found = entry end end
    assert(found, "KEY_ACTIONS misses " .. action)
    assert(ns.KEY_ACTIONS[found.id] == found, "KEY_ACTIONS id lookup")
end
assert(listed == #ns.KEY_ACTIONS, "Bindings.xml and KEY_ACTIONS differ")
assert(BINDING_NAME_FRAMEGAMBIT_TOGGLE_WINDOW, "window binding needs a name")
assert(type(FrameGambit_ToggleWindow) == "function", "window binding needs a handler")

-- Chords: modifiers combine, modifier-only and Escape are ignored.
assert(ns.KeyChord("LSHIFT") == nil and ns.KeyChord("ESCAPE") == nil)
modifiers = { ctrl = true, shift = true }
assert(ns.KeyChord("K") == "CTRL-SHIFT-K", ns.KeyChord("K"))
modifiers = {}
assert(ns.KeyText("CTRL-SHIFT-K") == "Ctrl + Shift + K", ns.KeyText("CTRL-SHIFT-K"))

-- Setting a key: replaces the action's old keys and reports conflicts.
local window = ns.KEY_ACTIONS.window.action
bindings = { F5 = window, J = "TOGGLEQUESTLOG" }
assert(ns:KeyConflict("J", window) == "TOGGLEQUESTLOG")
assert(ns:KeyConflict("F5", window) == nil and ns:KeyConflict("Q", window) == nil)
assert(ns:SetActionBinding(window, "J"))
assert(bindings.J == window and bindings.F5 == nil, "old key dropped, new key bound")
-- Clearing.
assert(ns:SetActionBinding(window, nil))
assert(ns:GetActionKey(window) == nil)
-- Combat refusal leaves bindings untouched.
bindings = { F5 = window }
combat = true
local ok, reason = ns:SetActionBinding(window, "J")
assert(not ok and reason == "Not in combat" and bindings.F5 == window and bindings.J == nil)
combat = false
-- A failed save rolls back.
bindings = { F5 = window, J = "TOGGLEQUESTLOG" }
saveFails = true
ok, reason = ns:SetActionBinding(window, "J")
assert(not ok and reason == "Shortcut not saved")
assert(bindings.F5 == window and bindings.J == "TOGGLEQUESTLOG", "rollback restores both keys")
saveFails = false
-- The old Cinematic setters still go through the shared setter.
assert(ns:SetCinematicBinding("F7") and ns:GetCinematicBinding() == "F7")

-- Minimap button.
Minimap = FakeFrame("Frame", "Minimap")
function Minimap:GetCenter() return 100, 100 end
function Minimap:GetEffectiveScale() return 1 end
GetCursorPosition = function() return 100, 200 end
GameTooltip = FakeFrame("Frame", "GameTooltip")
FrameGambitDB = { minimapButton = { hide = false, angle = 200 } }
local opened = 0
ns.ToggleOptions = function() opened = opened + 1 end
local before = #frames
assert(loadfile(root .. "/MinimapButton.lua"))("FrameGambit", ns)
local loader = frames[before + 1]
loader.scripts.OnEvent(loader, "PLAYER_LOGIN")
local button = ns.MinimapButton
assert(button and button.parent == Minimap, "button is a Minimap child")
assert(not button:IsIgnoringParentAlpha(), "button inherits the Minimap fade")
assert(button.point and button.point[2] == Minimap)
button.scripts.OnClick(button, "LeftButton")
assert(opened == 1, "click opens the window")
-- Drag: cursor straight above the centre -> 90 degrees, saved.
button.scripts.OnDragStart(button)
button.scripts.OnUpdate(button, 0)
button.scripts.OnDragStop(button)
assert(math.abs(FrameGambitDB.minimapButton.angle - 90) < 0.001, FrameGambitDB.minimapButton.angle)
local x, y = ns.MinimapButtonOffset(90, 76, false)
assert(math.abs(x) < 0.001 and math.abs(y - 76) < 0.001)
x, y = ns.MinimapButtonOffset(45, 74, true)
assert(math.abs(x - 74) < 0.001 and math.abs(y - 74) < 0.001, "square maps use the corner")
assert(math.abs(ns.MinimapButtonAngle(0, 10, 10, 10) - 180) < 0.001)
-- Toggle is saved.
ns:SetMinimapButtonShown(false)
assert(FrameGambitDB.minimapButton.hide == true and not button:IsShown() and not ns:IsMinimapButtonShown())
ns:SetMinimapButtonShown(true)
assert(FrameGambitDB.minimapButton.hide == false and button:IsShown())
-- Hidden by save: no button on login.
local savedButton = ns.MinimapButton
FrameGambitDB = { minimapButton = { hide = true } }
assert(not ns:IsMinimapButtonShown())

-- Options > AddOns page.
local registered
Settings = {
    RegisterCanvasLayoutCategory = function(frame, name) registered = { frame = frame, name = name }; return registered end,
    RegisterAddOnCategory = function(category) category.addon = true end,
}
FrameGambitDB = { minimapButton = { hide = false, angle = 90 } }
ns.CreateOptions = function(self) self.Options = self.Options or FakeFrame("Frame") ; self.Options.shown = false end
before = #frames
assert(loadfile(root .. "/SettingsPage.lua"))("FrameGambit", ns)
local pageLoader = frames[before + 1]
pageLoader.scripts.OnEvent(pageLoader, "PLAYER_LOGIN")
assert(registered and registered.addon and registered.name == "Frame Gambit", "page registered under the addon title")
local page = registered.frame
assert(#page.keys == #ns.KEY_ACTIONS, "one keycap per key")
page.scripts.OnShow(page)
assert(page.minimap.checked == true)
-- Minimap checkbox writes the saved toggle.
page.minimap.checked = false
page.minimap.scripts.OnClick(page.minimap)
assert(FrameGambitDB.minimapButton.hide == true and not savedButton:IsShown())
assert(page.minimap.checked == false)
-- Keycap: click listens, a chord binds and reports the replaced action.
bindings = { J = "TOGGLEQUESTLOG" }
local row = page.keys[1]
row.keycap.scripts.OnClick(row.keycap)
assert(row.keycap.keyboard == true and row.keycap.text == "Press a key")
modifiers = { alt = true }
row.keycap.scripts.OnKeyDown(row.keycap, "LALT")
assert(row.keycap.keyboard == true, "modifier alone keeps listening")
row.keycap.scripts.OnKeyDown(row.keycap, "J")
modifiers = {}
assert(bindings["ALT-J"] == row.entry.action and row.keycap.keyboard == false)
row.keycap.scripts.OnClick(row.keycap)
row.keycap.scripts.OnKeyDown(row.keycap, "ESCAPE")
assert(bindings["ALT-J"] == row.entry.action and row.keycap.keyboard == false, "Esc cancels")
bindings.J = "TOGGLEQUESTLOG"
row.keycap.scripts.OnClick(row.keycap)
row.keycap.scripts.OnKeyDown(row.keycap, "J")
assert(bindings.J == row.entry.action and bindings["ALT-J"] == nil)
assert(page.status.text == "Replaced TOGGLEQUESTLOG", tostring(page.status.text))
row.keycap.scripts.OnClick(row.keycap)
row.keycap.scripts.OnKeyDown(row.keycap, "DELETE")
assert(ns:GetActionKey(row.entry.action) == nil, "Del clears")
-- Combat: no listening.
combat = true
row.keycap.scripts.OnClick(row.keycap)
assert(row.keycap.keyboard == false and page.status.text == "Not in combat")
combat = false

print("PASS: key setters, conflicts, rollback, minimap button (Minimap child, drag, saved toggle) and Options > AddOns page")
