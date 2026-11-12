local _, ns = ...

-- Forever only. The companion owns native input observation and layout;
-- Frame Gambit leases alpha through its existing host-restoring ledger.
local layers = { gamepad_base = "base", gamepad_lt = "lt", gamepad_rt = "rt", gamepad_both = "both" }
local subscribed
local fields = { gamepad_mode = "enabled", gamepad_lt_held = "ltHeld", gamepad_rt_held = "rtHeld", gamepad_both_held = "bothHeld" }
fields.gamepad_left_shoulder_held = "leftShoulderHeld"
fields.gamepad_right_shoulder_held = "rightShoulderHeld"
fields.gamepad_both_shoulders_held = "bothShouldersHeld"

local function Secret(value)
    return issecretvalue and issecretvalue(value)
end

local function Provider()
    local api = _G.GamepadCompanionAPI
    if type(api) == "table" and not Secret(api.version) and api.version == 1
        and type(api.GetState) == "function" then return api end
end

local function State()
    local api = Provider()
    if not api then return nil end
    local ok, state = pcall(api.GetState)
    if not ok or Secret(state) or type(state) ~= "table" then return nil end
    if Secret(state.available) or state.available ~= true then return nil end
    return state
end

local function Gameplay(state)
    return state and not Secret(state.enabled) and state.enabled == true
        and not Secret(state.gameplay) and state.gameplay == true
end

-- Picked native bars have generated target IDs, not the four semantic IDs.
-- Resolve by identity so saved and session-only selections behave alike.
local function NativeTargetBar(id)
    local root = _G.GamepadMainActionBarFrame
    local page = root and root.PageUnit
    -- Asked for every target on every evaluator tick (IsGamepadEditingTarget);
    -- reuse the tick's resolve instead of a second full lookup per target.
    local frame = page and ns:ResolveTargetThisTick(id)
    if not frame then return nil end
    for _, bar in pairs(page.actionBars or {}) do
        if frame == bar then return frame, page end
    end
    local anchor = page.TopCenteredAnchor
    local stance = anchor and anchor.StanceBar or _G.GamepadMainActionBarFramePageUnitTopCenteredAnchorStanceBar
    if stance and frame == stance then return frame, page end
end

function ns:IsGamepadEditingTarget(id)
    if not layers[id] and id ~= "gamepad_shoulder_left" and id ~= "gamepad_shoulder_right"
        and id ~= "gamepad_input_legend" and not NativeTargetBar(id) then return false end
    local state = State()
    return state and not Secret(state.editing) and state.editing == true
end

-- Read native focus without hooking or writing the secure navigation manager.
-- A focused child reveals its containing target, but a focused parent does not
-- make every independently managed child count as highlighted.
local function ContainsFocus(target, focus)
    for _ = 1, 64 do
        if Secret(focus) then return nil end
        if focus == nil then return false end
        if type(focus.IsForbidden) == "function" then
            local forbidden = focus:IsForbidden()
            if Secret(forbidden) or forbidden then return nil end
        end
        if focus == target then return true end
        if type(focus.GetParent) ~= "function" then return nil end
        focus = focus:GetParent()
    end
    return nil -- Malformed/cyclic ancestry is unavailable, not a No answer.
end

local function FrameHighlighted(id)
    if not InputUtil or type(InputUtil.IsGamepadUIEnabled) ~= "function" then return nil end
    local enabled = InputUtil.IsGamepadUIEnabled()
    if Secret(enabled) or type(enabled) ~= "boolean" then return nil end
    if not enabled then return false end

    local target = ns:ResolveTargetThisTick(id)
    if Secret(target) or not target then return nil end
    if type(target.GetFrameGambitVisualFrame) == "function" then
        target = target:GetFrameGambitVisualFrame()
        if Secret(target) or not target then return nil end
    end
    -- Group targeting opens SmartNavigation directly, without setting the
    -- ordinary window manager's isUIFocused flag. Its current member button
    -- still belongs to the party/raid container, so ancestry reveals the whole
    -- container as well as an independently managed selected member. Do not
    -- use currentFrameSelected: GroupTargeting retains it after targeting ends.
    if GroupTargeting and type(GroupTargeting.IsActive) == "function" then
        local active = GroupTargeting:IsActive()
        if Secret(active) or type(active) ~= "boolean" then return nil end
        if active then
            local nav = SmartNavigation
            if not nav or type(nav.IsVisible) ~= "function" or type(nav.GetCurrentButton) ~= "function" then return nil end
            local visible, suspended = nav:IsVisible(), nav.isCursorSuspended
            if Secret(visible) or Secret(suspended) or type(visible) ~= "boolean" then return nil end
            if not visible or suspended then return false end
            return ContainsFocus(target, nav:GetCurrentButton())
        end
    end
    local manager = GamepadMode and GamepadMode.FrameControlsManager
    if not manager or type(manager.GetActiveFrame) ~= "function" then return nil end
    local focused = manager.isUIFocused
    if Secret(focused) or type(focused) ~= "boolean" then return nil end
    -- GetActiveFrame can retain a frame after returning to player control.
    if not focused then return false end

    local matched = ContainsFocus(target, manager:GetActiveFrame())
    if matched == true then return true end
    local nav = SmartNavigation
    if nav and type(nav.IsVisible) == "function" and type(nav.GetCurrentButton) == "function" then
        local visible, suspended = nav:IsVisible(), nav.isCursorSuspended
        if Secret(visible) or Secret(suspended) then return nil end
        if visible == true and not suspended then
            local buttonMatched = ContainsFocus(target, nav:GetCurrentButton())
            if buttonMatched == true then return true end
            if buttonMatched == nil then return nil end
        end
    end
    return matched
end

function ns:GetGamepadConditionActivity(condition, targetID)
    if condition == "gamepad_frame_highlighted" then
        local ok, active = pcall(FrameHighlighted, targetID)
        if ok and not Secret(active) and type(active) == "boolean" then return active end
        return nil
    end
    local state = State()
    if not state then return nil end
    if condition ~= "gamepad_mode" and not Gameplay(state) then return nil end
    if condition == "gamepad_mode" then
        local nativeEnabled = state.nativeEnabled
        if Secret(nativeEnabled) then return nil end
        if nativeEnabled ~= nil then
            if type(nativeEnabled) == "boolean" then return nativeEnabled end
            return nil
        end
        -- Earlier v1 providers exposed only enabled.
    end
    if condition == "gamepad_bar_active" then
        local layer, active = layers[targetID], state.activeLayer
        if not layer then
            local frame, page = NativeTargetBar(targetID)
            if not frame or type(page.GetActiveBar) ~= "function" then return nil end
            local ok, selected = pcall(page.GetActiveBar, page)
            if not ok or Secret(selected) or selected == nil then return nil end
            return frame == selected
        end
        if not layer or Secret(active) or (active ~= "base" and active ~= "lt" and active ~= "rt" and active ~= "both") then return nil end
        return layer == active
    end
    local field = fields[condition]
    local value = field and state[field]
    if Secret(value) or type(value) ~= "boolean" then return nil end
    return value
end

local cards = {
    { "gamepad_mode", "Gamepad mode", nil },
    { "gamepad_lt_held", "LT held", nil },
    { "gamepad_rt_held", "RT held", nil },
    { "gamepad_both_held", "Both held", nil },
    { "gamepad_left_shoulder_held", "Left shoulder held", nil },
    { "gamepad_right_shoulder_held", "Right shoulder held", nil },
    { "gamepad_both_shoulders_held", "Both shoulders held", nil },
    { "gamepad_bar_active", "Bar active", nil },
    { "gamepad_frame_highlighted", "Frame highlighted", nil, native = true },
}
-- Keep CHAT in the final category slot after Gamepad.
local categoryIndex = #ns.CONDITION_CATEGORY_ORDER + 1
for index, category in ipairs(ns.CONDITION_CATEGORY_ORDER) do
    if category.id == "chat" then categoryIndex = index; break end
end
table.insert(ns.CONDITION_CATEGORY_ORDER, categoryIndex, { id = "gamepad", label = "Gamepad" })
for index, card in ipairs(cards) do
    local help = not card.native and "Needs Gamepad Companion" or nil
    ns.CONDITION_INFO[card[1]] = {
        label = card[2], category = "gamepad", kind = "state", pickerOrder = index,
        gamepad = true, booleanField = "gamepadExpected",
        help = help,
    }
    for answer = 1, 2 do
        local expected = answer == 1
        ns.CONDITION_INFO[card[1] .. (expected and "_yes" or "_no")] = {
            label = card[2] .. (expected and ": Yes" or ": No"),
            category = "gamepad", kind = "state", pickerOrder = index * 2 + answer,
            requirementOnly = true, requirementCondition = card[1], requirementExpected = expected,
            help = help,
        }
    end
end

for _, entry in ipairs({ { "base", "Base" }, { "lt", "LT" }, { "rt", "RT" }, { "both", "LT + RT" } }) do
    local layer = entry[1]
    local target = {
        id = "gamepad_" .. layer, label = "Gamepad - " .. entry[2], source = "Blizzard / Gamepad Companion",
        protected = true, capability = "Opacity only", capabilityTone = "teal",
        capabilityNote = "Use Bar active",
        resolve = function()
            local api, state = Provider(), State()
            -- Menus/chat suspend gameplay input, not ownership of the HUD's
            -- opacity. Releasing here restores every bar's native alpha.
            if not api or not state or Secret(state.enabled) or state.enabled ~= true
                or type(api.GetBarFrame) ~= "function" then return nil end
            return api.GetBarFrame(layer)
        end,
    }
    -- Register before the editor is constructed; no profile is implicitly enabled.
    ns.Targets[#ns.Targets + 1] = target
    ns.TargetByID[target.id] = target
end

-- Native bar selection finishes its own sizing before the companion publishes
-- this notification. Apply ordinary and explicitly picked native bars in the same call stack;
-- no global Tick(), native geometry or input-manager callback is involved.
function ns:ApplyNativeGamepadOpacity()
    local runtime, db = self.runtime, FrameGambitDB
    if not runtime or not runtime.inputProfilesReady or runtime.gamepadApplying
        or type(db) ~= "table" or type(db.profiles) ~= "table" then return end
    local profile = db.profiles[db.profile]
    if type(profile) ~= "table" or type(profile.targets) ~= "table" then return end
    runtime.gamepadApplying = true
    local applyingID
    local ok, message = pcall(function()
        self:BuildStateContext()
        local now = GetTime()
        for id, settings in pairs(profile.targets) do
            if settings and settings.enabled and (layers[id] or NativeTargetBar(id)) then
                applyingID = id
                -- A trigger release must cancel a previously committed reveal,
                -- as well as the normal fade delay/duration, before evaluation.
                runtime.revealGoal[id] = nil
                runtime.fadeOutStarted[id] = nil
                runtime.transitions[id] = nil
                runtime.immediateApply[id] = true
                self:ApplyTarget(id, now)
                runtime.immediateApply[id] = nil
                applyingID = nil
            end
        end
    end)
    runtime.gamepadApplying = nil
    if not ok then
        if applyingID then runtime.immediateApply[applyingID] = nil end
        error(message, 0)
    end
end

function ns:RefreshGamepadIntegration()
    local api = Provider()
    if subscribed == api then return end
    if subscribed and type(subscribed.Unsubscribe) == "function" then pcall(subscribed.Unsubscribe, "FrameGambit") end
    subscribed = nil
    if api and type(api.Subscribe) == "function" then
        local ok, result = pcall(api.Subscribe, "FrameGambit", function(_, reason)
            if reason == "native-bar" then ns:ApplyNativeGamepadOpacity() end
            ns:Wake()
        end)
        if ok and result ~= false then subscribed = api end
    end
    self:Wake()
end
