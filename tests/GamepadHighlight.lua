local root = arg[1] or "Interface/AddOns/FrameGambit"
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
SlashCmdList = {}
C_Timer = { After = function() end }
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/Targets.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/GamepadIntegration.lua"))("FrameGambit", ns)
local function frame(parent)
    return { GetParent = function() return parent end, IsForbidden = function() return false end }
end
local quest, other = frame(), frame()
local button, sibling = frame(quest), frame(quest)
local manager = { isUIFocused = true, focusedFrame = quest }
function manager:GetActiveFrame() return self.focusedFrame end
GamepadMode = { FrameControlsManager = manager }
local enabled = true
InputUtil = { IsGamepadUIEnabled = function() return enabled end }
SmartNavigation = { visible = true, currentButton = button }
function SmartNavigation:IsVisible() return self.visible end
function SmartNavigation:GetCurrentButton() return self.currentButton end
local targets = { quest = quest, button = button, sibling = sibling, other = other }
function ns:ResolveTarget(id) return targets[id] end
local key = "gamepad_frame_highlighted"
local function expect(id, value)
    assert(ns:GetGamepadConditionActivity(key, id) == value, id .. ": wrong focus state")
    assert(ns:ConditionIsMet(key, id, { gamepadExpected = true }) == (value == true))
    assert(ns:ConditionIsMet(key, id, { gamepadExpected = false }) == (value == false))
    assert(ns:ConditionIsMet(key .. "_yes", id, {}, true) == (value == true))
    assert(ns:ConditionIsMet(key .. "_no", id, {}, true) == (value == false))
end
-- No companion installed, and menus need no gameplay input state.
expect("quest", true)
expect("button", true)
expect("sibling", false)
expect("other", false)
manager.focusedFrame = button
expect("quest", true)
manager.focusedFrame, SmartNavigation.currentButton = other, other
expect("quest", false)
manager.focusedFrame, SmartNavigation.currentButton = quest, button
manager.isUIFocused = false
expect("quest", false) -- stale native focus must not keep the tracker revealed
manager.isUIFocused = true
enabled = false
expect("quest", false)
enabled = true
SmartNavigation.isCursorSuspended = true
expect("button", false)
SmartNavigation.isCursorSuspended, SmartNavigation.visible = false, false
expect("button", false)
SmartNavigation.visible = true
targets.proxy = { GetFrameGambitVisualFrame = function() return quest end }
expect("proxy", true)
expect("missing", nil)
-- Group targeting bypasses ordinary UI focus. Check the real containment shape
-- PartyFrame -> CompactPartyFrame -> member, without any unit/target queries.
local party = frame()
local compact = frame(party)
local member, second = frame(compact), frame(compact)
targets.party_frames, targets.compact, targets.member, targets.second = party, compact, member, second
GroupTargeting = { active = true }
function GroupTargeting:IsActive() return self.active end
manager.isUIFocused, SmartNavigation.currentButton = false, member
expect("party_frames", true)
expect("compact", true)
expect("member", true)
expect("second", false)
expect("quest", false)
SmartNavigation.currentButton = second
expect("party_frames", true)
expect("member", false)
expect("second", true)
SmartNavigation.currentButton = other -- raid/other container does not reveal party
expect("party_frames", false)
SmartNavigation.currentButton = member
SmartNavigation.visible = false
expect("party_frames", false)
SmartNavigation.visible, SmartNavigation.isCursorSuspended = true, true
expect("party_frames", false)
SmartNavigation.isCursorSuspended = false
enabled = false
expect("party_frames", false)
enabled, GroupTargeting.active = true, false
expect("party_frames", false) -- retained selection after leaving targeting
GroupTargeting.active, SmartNavigation.currentButton = true, nil
expect("party_frames", false)
GroupTargeting.active = false
manager.isUIFocused = true
local secret = {}
issecretvalue = function(value) return value == secret end
GroupTargeting.active = secret
expect("party_frames", nil)
GroupTargeting.active, SmartNavigation.currentButton = true, secret
expect("party_frames", nil)
GroupTargeting.active, SmartNavigation.currentButton = false, button
manager.isUIFocused = secret
expect("quest", nil)
manager.isUIFocused, manager.focusedFrame, SmartNavigation.currentButton = true, secret, nil
expect("quest", nil)
manager.focusedFrame = frame()
manager.focusedFrame.IsForbidden = function() return true end
expect("quest", nil)
manager.focusedFrame = frame()
manager.focusedFrame.GetParent = function(self) return self end
expect("quest", nil)
manager.GetActiveFrame = function() error("restricted focus") end
expect("quest", nil)
GamepadMode = nil
expect("quest", nil)
print("PASS: gamepad highlight, child focus, menus, stale focus, adapters and unavailable state")
