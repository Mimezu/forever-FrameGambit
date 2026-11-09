local ADDON, ns = ...

-- These are explicit, human-named adapters.  We deliberately do not save or
-- execute arbitrary global-frame paths: an adapter either resolves safely or
-- is simply unavailable on this character/UI setup.
ns.Targets = {
    { id = "eui_main", label = "Main Action Bar", source = "Ellesmere / Blizzard", names = { "EABBar_MainBar", "MainActionBar", "MainMenuBar" }, protected = true },
    { id = "eui_bar2", label = "Action Bar 2", source = "Ellesmere / Blizzard", names = { "EABBar_Bar2", "MultiBarBottomLeft" }, protected = true },
    { id = "eui_bar3", label = "Action Bar 3", source = "Ellesmere / Blizzard", names = { "EABBar_Bar3", "MultiBarBottomRight" }, protected = true },
    { id = "eui_bar4", label = "Action Bar 4", source = "Ellesmere / Blizzard", names = { "EABBar_Bar4", "MultiBarRight" }, protected = true },
    { id = "eui_bar5", label = "Action Bar 5", source = "Ellesmere / Blizzard", names = { "EABBar_Bar5", "MultiBarLeft" }, protected = true },
    { id = "eui_bar6", label = "Action Bar 6", source = "Ellesmere / Blizzard", names = { "EABBar_Bar6", "MultiBar5" }, protected = true },
    { id = "eui_bar7", label = "Action Bar 7", source = "Ellesmere / Blizzard", names = { "EABBar_Bar7", "MultiBar6" }, protected = true },
    { id = "eui_bar8", label = "Action Bar 8", source = "Ellesmere / Blizzard", names = { "EABBar_Bar8", "MultiBar7" }, protected = true },
    { id = "eui_bar9", label = "Action Bar 9", source = "Ellesmere", names = { "EABBar_Bar9" }, protected = true },
    { id = "totem_bar", label = "Totem Bar", source = "Blizzard", names = { "MultiCastActionBarFrame" }, protected = true },
    { id = "swing_mainhand", label = "Main-hand Swing Timer", source = "Blizzard", names = { "SwingTimerMainHandFrame" }, protected = true },
    { id = "swing_offhand", label = "Off-hand Swing Timer", source = "Blizzard", names = { "SwingTimerOffHandFrame" }, protected = true },
    { id = "swing_ranged", label = "Ranged Swing Timer", source = "Blizzard", names = { "SwingTimerRangedFrame" }, protected = true },
    { id = "pet_action_bar", label = "Pet Action Bar", source = "Ellesmere / Blizzard", names = { "EABBar_PetBar", "PetActionBar", "PetActionBarFrame" }, protected = true },
    { id = "stance_bar", label = "Stance Bar", source = "Ellesmere / Blizzard", names = { "EABBar_StanceBar", "StanceBar", "StanceBarFrame" }, protected = true },
    { id = "extra_abilities", label = "Extra Abilities", source = "Ellesmere / Blizzard", names = { "EllesmereEAB_ExtraActionButton", "ExtraAbilityContainer", "ExtraActionBarFrame", "ZoneAbilityFrame" }, protected = true },
    { id = "eui_castbar", label = "Cast Bar", source = "Ellesmere / Blizzard", names = { "ERB_CastBarFrame", "PlayerCastingBarFrame" }, protected = true,
        capability = "Opacity only", capabilityTone = "teal", capabilityNote = "Frame Gambit changes only opacity. Ellesmere or Blizzard keeps the bar's layout and behavior." },
    { id = "eui_resourcebars", label = "Resource Bars", source = "Ellesmere", names = { "EllesmereUIResourceBarsFrame" }, protected = false,
        capability = "Whole group", capabilityTone = "teal", capabilityNote = "All Resource Bars fade together. Ellesmere keeps their layout and behavior." },
    { id = "cdm_cooldowns", label = "CDM - Cooldowns", source = "Blizzard CDM / Ellesmere", names = { "EssentialCooldownViewer" }, protected = true,
        capability = "Whole viewer", capabilityTone = "teal", capabilityNote = "The complete Cooldowns viewer fades together. Its layout and alerts stay unchanged." },
    { id = "cdm_utility", label = "CDM - Utility", source = "Blizzard CDM / Ellesmere", names = { "UtilityCooldownViewer" }, protected = true,
        capability = "Whole viewer", capabilityTone = "teal", capabilityNote = "The complete Utility viewer fades together, including Ellesmere bars in that category." },
    { id = "cdm_buffs", label = "CDM - Buffs / auras", source = "Blizzard CDM / Ellesmere", names = { "BuffIconCooldownViewer" }, protected = true,
        capability = "Whole viewer", capabilityTone = "teal", capabilityNote = "The complete Buff Icons viewer fades together. Icon styling and alerts stay unchanged." },
    { id = "cdm_buff_bars", label = "CDM - Buff bars", source = "Blizzard CDM / Ellesmere", names = { "BuffBarCooldownViewer" }, protected = true,
        capability = "Whole viewer", capabilityTone = "teal", capabilityNote = "The complete Buff Bars viewer fades together. Its layout and alerts stay unchanged." },
    { id = "player_buffs", label = "Player Buffs", source = "Blizzard", names = { "BuffFrame" }, protected = true,
        capability = "Blizzard buffs", capabilityTone = "teal", capabilityNote = "Controls Blizzard's player buff icons, not Cooldown Manager's tracked buffs." },
    { id = "player_debuffs", label = "Player Debuffs", source = "Blizzard", names = { "DebuffFrame" }, protected = true,
        capability = "Blizzard debuffs", capabilityTone = "teal", capabilityNote = "Controls Blizzard's player debuff icons, not Cooldown Manager's tracked buffs." },
    { id = "eui_player", label = "Player Frame", source = "Ellesmere / Blizzard", names = { "EllesmereUIUnitFrames_Player", "PlayerFrame" }, protected = true },
    { id = "eui_target", label = "Target Frame", source = "Ellesmere / Blizzard", names = { "EllesmereUIUnitFrames_Target", "TargetFrame" }, protected = true },
    { id = "eui_focus", label = "Focus Frame", source = "Ellesmere / Blizzard", names = { "EllesmereUIUnitFrames_Focus", "FocusFrame" }, protected = true },
    { id = "eui_pet", label = "Pet Frame", source = "Ellesmere / Blizzard", names = { "EllesmereUIUnitFrames_Pet", "PetFrame" }, protected = true },
    { id = "eui_targettarget", label = "Target of Target", source = "Ellesmere / Blizzard", names = { "EllesmereUIUnitFrames_TargetTarget", "TargetFrameToT" }, protected = true },
    { id = "eui_focustarget", label = "Focus Target", source = "Ellesmere / Blizzard", names = { "EllesmereUIUnitFrames_FocusTarget", "FocusFrameToT" }, protected = true },
    { id = "eui_boss1", label = "Boss Frame 1", source = "Ellesmere / Blizzard", names = { "EllesmereUIUnitFrames_Boss1", "Boss1TargetFrame" }, protected = true },
    { id = "eui_boss2", label = "Boss Frame 2", source = "Ellesmere / Blizzard", names = { "EllesmereUIUnitFrames_Boss2", "Boss2TargetFrame" }, protected = true },
    { id = "eui_boss3", label = "Boss Frame 3", source = "Ellesmere / Blizzard", names = { "EllesmereUIUnitFrames_Boss3", "Boss3TargetFrame" }, protected = true },
    { id = "eui_boss4", label = "Boss Frame 4", source = "Ellesmere / Blizzard", names = { "EllesmereUIUnitFrames_Boss4", "Boss4TargetFrame" }, protected = true },
    { id = "eui_boss5", label = "Boss Frame 5", source = "Ellesmere / Blizzard", names = { "EllesmereUIUnitFrames_Boss5", "Boss5TargetFrame" }, protected = true },
    { id = "party_frames", label = "Party Frames", source = "Blizzard", names = { "PartyFrame", "CompactPartyFrame" }, protected = true },
    { id = "eui_raid", label = "Raid Frames", source = "Ellesmere / Blizzard", names = { "EllesmereUIRaidFrameContainer", "CompactRaidFrameContainer" }, protected = true },
    { id = "arena_frames", label = "Arena Frames", source = "Blizzard", names = {}, protected = true,
        capability = "Unavailable", capabilityTone = "muted", capabilityNote = "Arena frames are not available in this beta." },
    { id = "chat", label = "Chat", source = "Ellesmere Chat / Blizzard", names = { "ChatFrame1" }, protected = false,
        capability = "Whole chat", capabilityTone = "teal", capabilityNote = "Controls all chat windows, future whisper tabs, input and attached controls together." },
    { id = "bags_bar", label = "Bag Bar", source = "Ellesmere / Blizzard", names = { "EllesmereEAB_BagBar", "BagsBar" }, protected = true },
    { id = "micro_menu", label = "Micro Menu", source = "Ellesmere / Blizzard", names = { "EllesmereEAB_MicroBar", "EllesmereUIMicroMenu", "MicroMenuContainer" }, protected = true },
    { id = "minimap", label = "Minimap", source = "Blizzard", names = { "Minimap" }, protected = false },
    { id = "objectives", label = "Objectives", source = "Blizzard", names = { "ObjectiveTrackerFrame" }, protected = false },
    { id = "encounter_bar", label = "Encounter Bar", source = "Ellesmere / Blizzard", names = { "EllesmereEAB_EncounterBar", "EncounterBar" }, protected = false },
    { id = "widgets_top", label = "Top-center Widgets", source = "Blizzard", names = { "UIWidgetTopCenterContainerFrame" }, protected = false },
    { id = "widgets_center", label = "Center-screen Widgets", source = "Blizzard", names = { "UIWidgetCenterScreenContainerFrame" }, protected = false },
    { id = "status_bar_primary", label = "Primary Status Bar", source = "Ellesmere / Blizzard", names = { "EllesmereEAB_XPBar", "MainStatusTrackingBarContainer" }, protected = false },
    { id = "status_bar_secondary", label = "Secondary Status Bar", source = "Ellesmere / Blizzard", names = { "EllesmereEAB_RepBar", "SecondaryStatusTrackingBarContainer" }, protected = false },
    { id = "proc_overlay", label = "Spell Proc Overlay", source = "Blizzard", names = { "SpellActivationOverlayFrame" }, protected = false },
    { id = "ui_errors", label = "Error Messages", source = "Blizzard", names = { "UIErrorsFrame" }, protected = false },
    { id = "talking_head", label = "Talking Head", source = "Blizzard", names = { "TalkingHeadFrame" }, protected = false },
    { id = "loot_rolls", label = "Loot Rolls", source = "Blizzard", names = { "GroupLootContainer" }, protected = false,
        capability = "All roll windows", capabilityTone = "teal", capabilityNote = "The Need / Greed / Pass windows fade, resize and move together. The game shows them only while a roll is open." },
    { id = "timers", label = "Timers", source = "Blizzard", names = { "TimerTracker" }, protected = false },
    { id = "blizzard_damage_meter", label = "Blizzard Damage Meter", source = "Blizzard", names = { "DamageMeterSessionWindow1" }, protected = false,
        capability = "Whole window", capabilityTone = "teal", capabilityNote = "The complete Blizzard Damage Meter fades together. Its data and layout stay unchanged." },
}

ns.TargetByID = {}
for _, target in ipairs(ns.Targets) do
    ns.TargetByID[target.id] = target
end

local function ReadFrameMethods(frame)
    return frame.GetRect, frame.SetAlpha, frame.IsShown, frame.GetAlpha
end

local function IsUsableTargetFrame(frame)
    if not frame then return false end
    local ok, getRect, setAlpha, isShown, getAlpha = pcall(ReadFrameMethods, frame)
    return ok and type(getRect) == "function" and type(setAlpha) == "function"
        and type(isShown) == "function" and type(getAlpha) == "function"
end

-- Public integration point for UI authors.  Priority Fader deliberately keeps
-- its own saved variables; providers only supply a stable resolver and a
-- human-facing capability label.  It never reads another addon's database.
function ns:RegisterTarget(definition)
    if type(definition) ~= "table" or type(definition.id) ~= "string" or definition.id == "" then
        return false, "Target requires a stable string id."
    end
    if self.TargetByID[definition.id] then return false, "That target id is already registered." end
    if type(definition.label) ~= "string" or definition.label == "" or #definition.label > 64 then
        return false, "Target requires a label of 64 characters or fewer."
    end
    if definition.capability ~= nil and (type(definition.capability) ~= "string" or #definition.capability > 48) then
        return false, "Capability must be a concise label of 48 characters or fewer."
    end
    if definition.capabilityNote ~= nil and (type(definition.capabilityNote) ~= "string" or #definition.capabilityNote > 240) then
        return false, "Capability note must be 240 characters or fewer."
    end
    if definition.source ~= nil and (type(definition.source) ~= "string" or #definition.source > 64) then
        return false, "Source must be a label of 64 characters or fewer."
    end
    if definition.capabilityTone ~= nil and definition.capabilityTone ~= "teal" and definition.capabilityTone ~= "accent"
        and definition.capabilityTone ~= "amber" and definition.capabilityTone ~= "muted" then
        return false, "Capability tone must be teal, accent, amber, or muted."
    end
    if definition.timingOwner ~= nil and definition.timingOwner ~= "host" then
        return false, "Timing owner must be host when supplied."
    end
    if definition.timingLabel ~= nil and (type(definition.timingLabel) ~= "string" or #definition.timingLabel > 48) then
        return false, "Timing label must be 48 characters or fewer."
    end
    if definition.timingNote ~= nil and (type(definition.timingNote) ~= "string" or #definition.timingNote > 240) then
        return false, "Timing note must be 240 characters or fewer."
    end
    if definition.acquire ~= nil and type(definition.acquire) ~= "function" then
        return false, "Target acquire must be a function."
    end
    if definition.release ~= nil and type(definition.release) ~= "function" then
        return false, "Target release must be a function."
    end
    if type(definition.resolve) ~= "function" and (type(definition.names) ~= "table" or #definition.names == 0) then
        return false, "Target requires resolve() or one or more global frame names."
    end
    if definition.names then
        for _, name in ipairs(definition.names) do
            if type(name) ~= "string" or name == "" then return false, "Frame names must be non-empty strings." end
        end
    end
    local target = {
        id = definition.id,
        label = definition.label,
        source = type(definition.source) == "string" and definition.source or "External UI",
        protected = definition.protected == true,
        capability = definition.capability,
        capabilityTone = definition.capabilityTone,
        capabilityNote = definition.capabilityNote,
        timingOwner = definition.timingOwner,
        timingLabel = definition.timingLabel,
        timingNote = definition.timingNote,
        names = definition.names,
        resolve = definition.resolve,
        acquire = definition.acquire,
        release = definition.release,
        skipManagedAlphaHook = definition.skipManagedAlphaHook == true,
        layout = definition.layout == false and false or nil,
        external = true,
    }
    self.Targets[#self.Targets + 1] = target
    self.TargetByID[target.id] = target
    -- A visible-UI scan can register a number of roots at once.  Let that
    -- short, read-only discovery pass request one final redraw instead of
    -- rebuilding the editor for every individual root.
    if self.RefreshOptions and not self._batchRegistering then self:RefreshOptions() end
    return true
end

function ns:GetTargetCapability(target)
    if not target then return "Unavailable", "This frame is not currently available.", "amber" end
    if type(target.capability) == "string" and target.capability ~= "" then
        local tone = target.capabilityTone
        if tone ~= "teal" and tone ~= "accent" and tone ~= "amber" and tone ~= "muted" then tone = target.protected and "teal" or "accent" end
        local fallback = "This frame comes from " .. (target.source or "another UI") .. "."
        local note = type(target.capabilityNote) == "string" and target.capabilityNote ~= "" and target.capabilityNote or fallback
        return target.capability, note, tone
    end
    if target.protected then
        return "Live fade in combat", "This UI can fade while fighting. It is never moved, hidden, or reconfigured in combat.", "teal"
    end
    return "Opacity only", "Frame Gambit changes this frame's opacity. Size and position change only if you turn them on for a rule.", "accent"
end

function ns:ResolveTarget(id)
    local target = self.TargetByID[id]
    if not target then return nil end
    if target.resolve then
        local ok, frame = pcall(target.resolve)
        if ok and IsUsableTargetFrame(frame) then
            if self.PrepareGamepadClassTarget then self:PrepareGamepadClassTarget(frame, target) end
            return frame, target
        end
    end
    local fallback
    for _, name in ipairs(target.names or {}) do
        local frame = _G[name]
        if IsUsableTargetFrame(frame) then
            if self.PrepareGamepadClassTarget then self:PrepareGamepadClassTarget(frame, target) end
            fallback = fallback or frame
            local shownOK, shown = pcall(frame.IsShown, frame)
            if shownOK and not (issecretvalue and issecretvalue(shown)) and shown == true then
                return frame, target
            end
        end
    end
    -- Alternatives often represent mutually exclusive Blizzard and addon UI
    -- modes. Prefer the implementation that is actually on screen, but keep a
    -- dormant frame resolvable so its alpha is ready before its owner shows it.
    return fallback, target
end

-- Separate availability from capability. A target may be supported while its
-- frame is absent for the current UI state (for example, a boss frame outside
-- an encounter). The editor can explain that instead of silently omitting it.
function ns:GetTargetAvailability(targetOrID)
    local target = type(targetOrID) == "table" and targetOrID or self.TargetByID[targetOrID]
    if not target then return false, nil, "Unavailable", "This frame is no longer available.", "amber" end
    local frame = self:ResolveTarget(target.id)
    if frame then return true, frame, "Available", "This frame is currently available for selection.", "teal" end
    local source = target.source or "this UI"
    local note
    if target.external then
        note = source .. " is not loaded yet. Enable it, open that part of the UI, then try again."
    else
        note = "This " .. source .. " frame is not visible yet. Open that part of the UI, then try again."
    end
    return false, nil, "Unavailable", note, "amber"
end

-- Tiny, versioned global surface.  Deliberately no configuration or profile
-- access: a provider can register a frame, but cannot alter user rules.
FrameGambitAPI = FrameGambitAPI or {}
FrameGambitAPI.version = 1
function FrameGambitAPI.RegisterTarget(definition)
    return ns:RegisterTarget(definition)
end
-- Kept for already-shipped integrations; new integrations use FrameGambitAPI.
PriorityFaderAPI = FrameGambitAPI

function ns:GetAvailableTargets()
    local available = {}
    for _, target in ipairs(self.Targets) do
        local frame = self:ResolveTarget(target.id)
        if frame then available[#available + 1] = target end
    end
    return available
end

-- Frame discovery is deliberately read-only.  It lets the picker inspect the
-- live UI stack without changing another addon's layout, scripts, or settings.
-- A selected named root becomes a persistent PF target; an anonymous root is
-- available for the current UI session only.
local STRATA_ORDER = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local PICKER_OVERVIEW_LIMIT = 120

local function SafeMethod(frame, method, ...)
    if not frame then return nil end
    local methodOK, func = pcall(function() return frame[method] end)
    if not methodOK or type(func) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(func, frame, ...)
    -- The frame walker touches UI owned by Blizzard and other addons.  Some
    -- modern UI APIs expose secret values while protected UI is active; never
    -- pass one on to sorting, string matching, or coordinate arithmetic.
    if ok and not ((issecretvalue and issecretvalue(a)) or (issecretvalue and issecretvalue(b))
        or (issecretvalue and issecretvalue(c)) or (issecretvalue and issecretvalue(d))) then
        return a, b, c, d
    end
end

local function IsForbiddenFrame(frame)
    return SafeMethod(frame, "IsForbidden") == true
end

function ns:IsFrameGambitFrame(frame)
    if not frame then return false end
    local current, seen = frame, {}
    while current and not seen[current] do
        if current == self.Options or current == self.Picker
            or current == self.SelectionOutline
            or current == self.HelpCenter or current == self.TutorialCard or current == self.TutorialOutline
            or current == self.PeekBar
            or (self.IsCinematicLetterboxFrame and self:IsCinematicLetterboxFrame(current))
            or current == self.ReactionPalette or current == self.OpacityPicker
            or current == self.ProfilePicker or current == self.CinematicKeyCapture then return true end
        seen[current] = true
        current = SafeMethod(current, "GetParent")
    end
    return false
end

function ns:GetFramePickerRoot(frame)
    if not frame or frame == UIParent or frame == WorldFrame or IsForbiddenFrame(frame) or self:IsFrameGambitFrame(frame) then return nil end
    local current, seen = frame, {}
    while current and not seen[current] do
        seen[current] = true
        local parent = SafeMethod(current, "GetParent")
        if parent == WorldFrame then return nil end -- never manage world/nameplate trees
        if not parent or parent == UIParent then break end
        current = parent
    end
    if current == UIParent or current == WorldFrame or IsForbiddenFrame(current) or self:IsFrameGambitFrame(current) then return nil end
    return current
end

local function UIParentChildren()
    if not UIParent or type(UIParent.GetChildren) ~= "function" then return {} end
    local ok, children = pcall(function() return { UIParent:GetChildren() } end)
    return ok and type(children) == "table" and children or {}
end

local function NearlyEqual(a, b, tolerance)
    return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tolerance or 0.01)
end

-- OPie's visible ring is intentionally anonymous.  Resolve that one renderer
-- from its exact named proxy and structural contract; do not exempt every
-- fullscreen frame or every frame whose name happens to begin with OPie.
function ns:RefreshOPieFrames()
    local proxy = _G.OPieVisualElementsProxy
    if not proxy or self:GetFramePickerRoot(proxy) ~= proxy then
        self._opieProxy, self._opieMainFrame = nil, nil
        self._opieResolvedAt = GetTime and GetTime() or 0
        return false
    end
    if self._opieProxy == proxy and self._opieMainFrame
        and SafeMethod(self._opieMainFrame, "GetParent") == UIParent then return true end
    self._opieProxy = proxy
    local proxyScale = SafeMethod(proxy, "GetScale")
    local proxyAlpha = SafeMethod(proxy, "GetAlpha")
    local proxyShown = SafeMethod(proxy, "IsShown")
    local proxyX, proxyY = SafeMethod(proxy, "GetCenter")
    local match
    for _, frame in ipairs(UIParentChildren()) do
        if frame ~= proxy and SafeMethod(frame, "GetParent") == UIParent
            and SafeMethod(frame, "GetName") == nil
            and SafeMethod(frame, "GetFrameStrata") == "FULLSCREEN"
            and SafeMethod(frame, "GetFrameLevel") == 100
            and NearlyEqual(SafeMethod(frame, "GetWidth"), 150, 0.1)
            and NearlyEqual(SafeMethod(frame, "GetHeight"), 150, 0.1)
            and (tonumber(SafeMethod(frame, "GetNumChildren")) or 0) >= 4
            and (type(proxyScale) ~= "number" or NearlyEqual(SafeMethod(frame, "GetScale"), proxyScale, 0.001))
            and (type(proxyShown) ~= "boolean" or SafeMethod(frame, "IsShown") == proxyShown) then
            local alpha = SafeMethod(frame, "GetAlpha")
            local x, y = SafeMethod(frame, "GetCenter")
            if (type(proxyAlpha) ~= "number" or NearlyEqual(alpha, proxyAlpha, 0.01))
                and (type(proxyX) ~= "number" or (NearlyEqual(x, proxyX, 1) and NearlyEqual(y, proxyY, 1))) then
                match = frame
                break
            end
        end
    end
    self._opieMainFrame = match
    self._opieResolvedAt = GetTime and GetTime() or 0
    if not self._opieProxyHooked and type(proxy.HookScript) == "function" then
        local ok = pcall(proxy.HookScript, proxy, "OnShow", function() ns:RefreshOPieFrames() end)
        if ok then self._opieProxyHooked = true end
    end
    return match ~= nil
end

function ns:IsOPieSceneFrame(frame)
    if not frame then return false end
    if frame == self._opieProxy or frame == self._opieMainFrame then return true end
    local now = GetTime and GetTime() or 0
    if not InCombatLockdown() and not self._opieMainFrame
        and now - (self._opieResolvedAt or 0) >= 1 then
        self:RefreshOPieFrames()
    end
    return frame == self._opieProxy or frame == self._opieMainFrame
end

-- SpeedyAutoLoot's compact loot feed is an anonymous UIParent sibling anchored
-- to one exact named frame. Preserve that presentation without reading or
-- changing the addon's settings.
function ns:RefreshLootSceneFrames()
    local anchor = _G.SpeedyAutoLoot_LootDisplayAnchor
    self._lootDisplayAnchor, self._lootDisplayFrame = anchor, nil
    self._lootResolvedAt = GetTime and GetTime() or 0
    if not anchor then return false end
    local anchorWidth = SafeMethod(anchor, "GetWidth")
    for _, frame in ipairs(UIParentChildren()) do
        local _, relativeTo = SafeMethod(frame, "GetPoint", 1)
        if frame ~= anchor and SafeMethod(frame, "GetParent") == UIParent
            and SafeMethod(frame, "GetName") == nil
            and SafeMethod(frame, "GetFrameStrata") == "MEDIUM"
            and SafeMethod(frame, "GetFrameLevel") == 10
            and (tonumber(SafeMethod(frame, "GetNumChildren")) or 0) >= 10
            and relativeTo == anchor
            and (type(anchorWidth) ~= "number" or NearlyEqual(SafeMethod(frame, "GetWidth"), anchorWidth, 1)) then
            self._lootDisplayFrame = frame
            break
        end
    end
    return self._lootDisplayFrame ~= nil
end

function ns:IsLootSceneFrame(frame)
    if not frame then return false end
    if frame == self._lootDisplayAnchor or frame == self._lootDisplayFrame then return true end
    local anchor = _G.SpeedyAutoLoot_LootDisplayAnchor
    local now = GetTime and GetTime() or 0
    if not InCombatLockdown() and (anchor ~= self._lootDisplayAnchor or (not self._lootDisplayFrame and now - (self._lootResolvedAt or 0) >= 1)) then
        self:RefreshLootSceneFrames()
    end
    return frame == self._lootDisplayAnchor or frame == self._lootDisplayFrame
end

local function DiscoveredLabel(name)
    if name:match("^Details") then return "Details: " .. name end
    if name:match("^EllesmereUI") or name:match("^EAB") or name:match("^EUI") then return "Ellesmere UI: " .. name end
    if name:match("^ChatFrame") then return "Chat" end
    if name:match("^Buff") or name:match("^TempEnchant") then return "Buffs / auras: " .. name end
    if name:match("^DataBar") or name:match("^EUIData") then return "Data bar: " .. name end
    return name
end

local function PickerDisplayLabel(name)
    if type(name) ~= "string" then return nil end
    if name:match("CDMBar") or name:lower():match("cooldown") then return "Cooldown Bar" end
    if name == "ContainerFrameContainer" then return "Bag Windows" end
    if name == "GroupLootContainer" or name:match("^GroupLootFrame%d$") then return "Loot Rolls" end
    if name:match("GlobalFX.*ModelScene") or name:match("BackgroundModelScene") then return "Full-screen Visual Effect" end
    if name:match("ModelScene") then return "3D Visual Effect" end
    if name:match("^Timer") or name == "Timers" then return "Timers" end
    if name:match("^ChatFrame") then return "Chat" end
    return DiscoveredLabel(name)
end

local function DiscoveredSource(name)
    if type(name) ~= "string" then return "Live UI frame (session only)" end
    if name:match("^Details") then return "Details" end
    if name:match("^EllesmereUI") or name:match("^EAB") or name:match("^EUI") then return "Ellesmere UI" end
    if name:match("^DUI") then return "Dialogue UI" end
    if name:match("^OPie") then return "OPie" end
    return "Live UI frame"
end

local function FrameDepth(frame, root)
    local current, depth, seen = frame, 0, {}
    while current and current ~= root and depth < 24 and not seen[current] do
        seen[current] = true
        current = SafeMethod(current, "GetParent")
        depth = depth + 1
    end
    return current == root and depth or 0
end

local function FrameTreeVisible(frame)
    local current, seen, depth = frame, {}, 0
    while current and current ~= UIParent and depth < 32 and not seen[current] do
        if SafeMethod(current, "IsShown") ~= true then return false end
        seen[current] = true
        current = SafeMethod(current, "GetParent")
        depth = depth + 1
    end
    return current == UIParent
end

local function PickerChildren(frame)
    if not frame then return {} end
    local methodOK, getChildren = pcall(function() return frame.GetChildren end)
    if not methodOK or type(getChildren) ~= "function" then return {} end
    local ok, children = pcall(function() return { getChildren(frame) } end)
    return ok and type(children) == "table" and children or {}
end

local function UpdatePickerClassification(entry)
    if not entry then return end
    local uiWidth = tonumber(SafeMethod(UIParent, "GetWidth")) or 0
    local uiHeight = tonumber(SafeMethod(UIParent, "GetHeight")) or 0
    local screenArea = math.max(1, uiWidth * uiHeight)
    local ratio = type(entry.area) == "number" and entry.area < math.huge and entry.area / screenArea or 0
    local frameName = entry.name or entry.debugName or ""
    local technicalReason
    if frameName:match("ModelScene") or frameName:match("^GlobalFX") then
        technicalReason = "Visual-effect layer"
    elseif ratio >= 0.82 then
        technicalReason = "Full-screen UI layer"
    end
    entry.screenRatio = ratio
    entry.technical = technicalReason ~= nil
    entry.technicalReason = technicalReason
    entry.broad = not entry.technical and ratio >= 0.35
end

local function CandidateSort(a, b)
    -- Put likely control surfaces ahead of full-screen render layers and broad
    -- layout containers. Technical candidates stay available through the
    -- picker's explicit toggle; they simply stop obscuring the useful answer.
    if (a.technical == true) ~= (b.technical == true) then return a.technical ~= true end
    if (a.broad == true) ~= (b.broad == true) then return a.broad ~= true end
    if (a.targetID ~= nil) ~= (b.targetID ~= nil) then return a.targetID ~= nil end
    if (a.isRoot == true) ~= (b.isRoot == true) then return a.isRoot == true end
    if (a.name ~= nil) ~= (b.name ~= nil) then return a.name ~= nil end
    if (a.mouseEnabled == true) ~= (b.mouseEnabled == true) then return a.mouseEnabled == true end
    if a.area ~= b.area then return a.area < b.area end
    if a.strata ~= b.strata then return a.strata > b.strata end
    if a.level ~= b.level then return a.level > b.level end
    if a.depth ~= b.depth then return a.depth > b.depth end
    local aName, bName = a.name or "", b.name or ""
    if aName ~= bName then return aName < bName end
    return (a.serial or 0) < (b.serial or 0)
end

function ns:GetUICursorPosition()
    if type(GetCursorPosition) ~= "function" then return nil end
    local ok, x, y = pcall(GetCursorPosition)
    local scale = UIParent and SafeMethod(UIParent, "GetEffectiveScale")
    if not ok or (issecretvalue and (issecretvalue(x) or issecretvalue(y) or issecretvalue(scale)))
        or type(x) ~= "number" or type(y) ~= "number" or type(scale) ~= "number" or scale <= 0 then return nil end
    return x / scale, y / scale
end

function ns:BuildPickerCandidate(frame)
    if not frame or self:IsFrameGambitFrame(frame) or IsForbiddenFrame(frame) then return nil end
    -- Reject dormant branches before any ancestry walk or geometry reads.
    -- This is the main cost control on UIs with large hidden configuration
    -- trees and pooled widgets.
    local visible = FrameTreeVisible(frame)
    if not visible then return nil end
    local root = self:GetFramePickerRoot(frame)
    if not root then return nil end
    local left, bottom, width, height = self:GetUsableFrameRect(frame)
    local name = SafeMethod(frame, "GetName")
    if type(name) ~= "string" or name == "" then name = nil end
    local isRoot = frame == root
    local mouseEnabled = SafeMethod(frame, "IsMouseEnabled") == true
    -- IsShown only describes the frame's own flag. IsVisible also accounts for
    -- hidden parents, which prevents dormant addon trees from filling the atlas
    -- with boxes the player cannot currently see.
    if left and (width < 3 or height < 3) then left, bottom, width, height = nil, nil, nil, nil end
    if not left and not isRoot and not name then return nil end
    -- Anonymous decorative children make a frame map unreadable and are not a
    -- useful persistence boundary. Keep roots, named frames, and real mouse
    -- regions; their named/anonymous parents remain available through wheel.
    if not isRoot and not name and not mouseEnabled then return nil end
    local persistentName = name and _G[name] == frame and name or nil
    local depth = FrameDepth(frame, root)
    local candidate = {
        frame = frame,
        root = root,
        name = persistentName,
        debugName = name,
        label = name and DiscoveredLabel(name) or (isRoot and "Unnamed window" or "Unnamed frame"),
        displayLabel = name and PickerDisplayLabel(name) or (isRoot and "Unnamed window" or "Unnamed frame"),
        source = DiscoveredSource(name),
        left = left,
        bottom = bottom,
        width = width,
        height = height,
        area = left and width * height or math.huge,
        depth = depth,
        isRoot = isRoot,
        mouseEnabled = mouseEnabled,
        strata = STRATA_ORDER[SafeMethod(frame, "GetFrameStrata") or "MEDIUM"] or 3,
        level = tonumber(SafeMethod(frame, "GetFrameLevel")) or 0,
    }
    UpdatePickerClassification(candidate)
    return candidate
end

-- The live picker builds one frozen map over several render frames. Cursor
-- movement afterwards is just arithmetic against cached rectangles: no
-- EnumerateFrames loop, no repeated protected geometry calls, and no FPS cliff.
function ns:BeginPickerAtlas()
    local atlas = {
        queue = UIParentChildren(),
        queueIndex = 1,
        inspected = 0,
        eligible = 0,
        entries = {},
        seeded = setmetatable({}, { __mode = "k" }),
        seen = setmetatable({}, { __mode = "k" }),
        done = false,
        scanDone = false,
        unavailable = not UIParent,
    }
    -- Anything the normal editor can already resolve and preview must be a
    -- picker guide even if a third-party parent has unusual child traversal.
    -- The hierarchy walk below then adds unregistered inner scopes around it.
    for _, target in ipairs(self:GetAvailableTargets()) do
        local frame = self:ResolveTarget(target.id)
        local candidate = frame and self:BuildPickerCandidate(frame)
        if candidate and candidate.left then
            candidate.label = target.label
            candidate.displayLabel = target.label
            candidate.source = target.source or candidate.source
            candidate.targetID = target.id
            candidate.serial = -(#atlas.entries + 1)
            atlas.entries[#atlas.entries + 1] = candidate
            atlas.eligible = atlas.eligible + 1
            atlas.seeded[frame] = true
        end
    end
    return atlas
end

function ns:FinalizePickerAtlas(atlas)
    if not atlas or atlas.finalized then return atlas end
    atlas.finalizing = true
    local byFrame = {}
    for _, entry in ipairs(atlas.entries) do byFrame[entry.frame] = entry end
    -- Some addons expose a useful logical container with no rectangle of its
    -- own. Give that named/root node the union of readable descendant boxes so
    -- it remains a visible, selectable scope in the hierarchy.
    for _, child in ipairs(atlas.entries) do
        if child.left then
            local current, seen, depth = SafeMethod(child.frame, "GetParent"), {}, 0
            while current and current ~= UIParent and depth < 24 and not seen[current] do
                seen[current] = true
                local parentEntry = byFrame[current]
                if parentEntry and not parentEntry.left then
                    local right, top = child.left + child.width, child.bottom + child.height
                    if not parentEntry._unionLeft then
                        parentEntry._unionLeft, parentEntry._unionBottom = child.left, child.bottom
                        parentEntry._unionRight, parentEntry._unionTop = right, top
                    else
                        parentEntry._unionLeft = math.min(parentEntry._unionLeft, child.left)
                        parentEntry._unionBottom = math.min(parentEntry._unionBottom, child.bottom)
                        parentEntry._unionRight = math.max(parentEntry._unionRight, right)
                        parentEntry._unionTop = math.max(parentEntry._unionTop, top)
                    end
                end
                current = SafeMethod(current, "GetParent")
                depth = depth + 1
            end
        end
    end
    local readable = {}
    for _, entry in ipairs(atlas.entries) do
        if not entry.left and entry._unionLeft then
            entry.left, entry.bottom = entry._unionLeft, entry._unionBottom
            entry.width, entry.height = entry._unionRight - entry._unionLeft, entry._unionTop - entry._unionBottom
            entry.area = entry.width * entry.height
            entry.derivedRect = true
        end
        UpdatePickerClassification(entry)
        entry._unionLeft, entry._unionBottom, entry._unionRight, entry._unionTop = nil, nil, nil, nil
        if entry.left and entry.width >= 3 and entry.height >= 3 then readable[#readable + 1] = entry end
    end
    atlas.entries = readable
    table.sort(atlas.entries, CandidateSort)
    atlas.gridSize, atlas.grid, atlas.largeEntries = 128, {}, {}
    for _, entry in ipairs(atlas.entries) do
        local firstX, lastX = math.floor(entry.left / atlas.gridSize), math.floor((entry.left + entry.width) / atlas.gridSize)
        local firstY, lastY = math.floor(entry.bottom / atlas.gridSize), math.floor((entry.bottom + entry.height) / atlas.gridSize)
        local cells = (lastX - firstX + 1) * (lastY - firstY + 1)
        if cells > 0 and cells <= 36 then
            for gridX = firstX, lastX do
                for gridY = firstY, lastY do
                    local key = gridX .. ":" .. gridY
                    local bucket = atlas.grid[key]
                    if not bucket then bucket = {}; atlas.grid[key] = bucket end
                    bucket[#bucket + 1] = entry
                end
            end
        else
            atlas.largeEntries[#atlas.largeEntries + 1] = entry
        end
    end
    -- Publish a bounded, de-duplicated guide map for orientation. The picker
    -- paints these regions in muted lavender; only the active candidate uses
    -- teal. Keeping the map separate from the local candidate stack avoids
    -- making every outline look selected.
    local uiWidth = tonumber(SafeMethod(UIParent, "GetWidth")) or 0
    local uiHeight = tonumber(SafeMethod(UIParent, "GetHeight")) or 0
    local screenArea = math.max(1, uiWidth * uiHeight)
    local ranked, rects = {}, {}
    for _, entry in ipairs(atlas.entries) do
        if entry.area < screenArea * 0.92 then
            local key = math.floor(entry.left + 0.5) .. ":" .. math.floor(entry.bottom + 0.5) .. ":"
                .. math.floor(entry.width + 0.5) .. ":" .. math.floor(entry.height + 0.5)
            local score = (entry.isRoot and 10000 or 0) + (entry.name and 2500 or 0)
                + (entry.mouseEnabled and 500 or 0) - entry.depth * 10
            local previous = rects[key]
            if not previous or score > previous.score then rects[key] = { entry = entry, score = score } end
        end
    end
    for _, item in pairs(rects) do ranked[#ranked + 1] = item end
    table.sort(ranked, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        if a.entry.area ~= b.entry.area then return a.entry.area > b.entry.area end
        return (a.entry.serial or 0) < (b.entry.serial or 0)
    end)
    atlas.overview = {}
    for index = 1, math.min(PICKER_OVERVIEW_LIMIT, #ranked) do atlas.overview[index] = ranked[index].entry end
    atlas.finalizing = nil
    atlas.finalized = true
    return atlas
end

function ns:ContinuePickerAtlas(atlas, budget)
    if not atlas or atlas.done then return true end
    if atlas.unavailable then
        atlas.scanDone = true
    end
    if not atlas.scanDone then
        budget = math.max(1, math.min(200, tonumber(budget) or 64))
        local processed = 0
        local started = type(debugprofilestop) == "function" and debugprofilestop() or nil
        while processed < budget
            and (processed == 0 or not started or debugprofilestop() - started < 1.25) do
            local frame = atlas.queue and atlas.queue[atlas.queueIndex]
            if not frame then atlas.scanDone = true; break end
            atlas.queueIndex = atlas.queueIndex + 1
            atlas.inspected = atlas.inspected + 1
            processed = processed + 1
            if not atlas.seen[frame] then
                atlas.seen[frame] = true
                local visible = FrameTreeVisible(frame)
                if visible and frame ~= WorldFrame and not self:IsFrameGambitFrame(frame) then
                    local candidate = self:BuildPickerCandidate(frame)
                    if candidate and not atlas.seeded[frame] then
                        candidate.serial = atlas.inspected
                        atlas.entries[#atlas.entries + 1] = candidate
                        atlas.eligible = (atlas.eligible or 0) + 1
                    end
                    for _, child in ipairs(PickerChildren(frame)) do
                        if not atlas.seen[child] then atlas.queue[#atlas.queue + 1] = child end
                    end
                end
            end
        end
    end
    if atlas.scanDone and not atlas.finalized then
        self:FinalizePickerAtlas(atlas)
        atlas.queue, atlas.queueIndex = nil, nil
    end
    if atlas.finalized then atlas.done = true end
    return atlas.done
end

function ns:GetPickerAtlasCandidates(atlas, x, y)
    local result = {}
    if not atlas or not atlas.finalized or type(x) ~= "number" or type(y) ~= "number" then return result end
    local key = math.floor(x / (atlas.gridSize or 128)) .. ":" .. math.floor(y / (atlas.gridSize or 128))
    local candidates, seen = {}, {}
    for _, entry in ipairs(atlas.grid and atlas.grid[key] or {}) do
        candidates[#candidates + 1] = entry
        seen[entry] = true
    end
    for _, entry in ipairs(atlas.largeEntries or {}) do
        if not seen[entry] then candidates[#candidates + 1] = entry end
    end
    table.sort(candidates, CandidateSort)
    for _, entry in ipairs(candidates) do
        if x >= entry.left and x <= entry.left + entry.width and y >= entry.bottom and y <= entry.bottom + entry.height then
            result[#result + 1] = entry
            if #result >= 80 then break end
        end
    end
    return result
end

local interactionRectCache = setmetatable({}, { __mode = "k" })

local function SafeChildren(frame)
    local methodOK, getChildren = pcall(function() return frame and frame.GetChildren end)
    if not methodOK or type(getChildren) ~= "function" then return {} end
    local ok, children = pcall(function() return { getChildren(frame) } end)
    return ok and type(children) == "table" and children or {}
end

function ns:GetFrameInteractionRect(frame, includeDescendants)
    local left, bottom, width, height = self:GetUsableFrameRect(frame)
    if left and not includeDescendants then return left, bottom, width, height end
    local now = GetTime and GetTime() or 0
    local cached = interactionRectCache[frame]
    local cacheFor = includeDescendants and 0.50 or 0.20
    if cached and cached.includeDescendants == (includeDescendants == true) and now - cached.at < cacheFor then
        return cached.left, cached.bottom, cached.width, cached.height
    end
    -- Logical addon containers are sometimes intentionally 0x0 while their
    -- children draw the real window. Build a short-lived visible-descendant
    -- union so a saved container remains hoverable after the picker closes.
    local queue, depths, seen, index, inspected = SafeChildren(frame), {}, {}, 1, 0
    for childIndex = 1, #queue do depths[childIndex] = 1 end
    local maxDepth = includeDescendants and 2 or 12
    local maxFrames = includeDescendants and 120 or 800
    local unionLeft, unionBottom, unionRight, unionTop
    if left then
        unionLeft, unionBottom = left, bottom
        unionRight, unionTop = left + width, bottom + height
    end
    while index <= #queue and inspected < maxFrames do
        local child = queue[index]
        local depth = depths[index] or 1
        index, inspected = index + 1, inspected + 1
        if child and not seen[child] then
            seen[child] = true
            if SafeMethod(child, "IsVisible") == true then
                local childLeft, childBottom, childWidth, childHeight = self:GetUsableFrameRect(child)
                if childLeft then
                    local right, top = childLeft + childWidth, childBottom + childHeight
                    unionLeft = unionLeft and math.min(unionLeft, childLeft) or childLeft
                    unionBottom = unionBottom and math.min(unionBottom, childBottom) or childBottom
                    unionRight = unionRight and math.max(unionRight, right) or right
                    unionTop = unionTop and math.max(unionTop, top) or top
                end
                if depth < maxDepth then
                    for _, descendant in ipairs(SafeChildren(child)) do
                        queue[#queue + 1] = descendant
                        depths[#queue] = depth + 1
                    end
                end
            end
        end
    end
    cached = { at = now, includeDescendants = includeDescendants == true }
    if unionLeft then
        cached.left, cached.bottom = unionLeft, unionBottom
        cached.width, cached.height = unionRight - unionLeft, unionTop - unionBottom
    end
    interactionRectCache[frame] = cached
    return cached.left, cached.bottom, cached.width, cached.height
end

function ns:FrameInteractionContainsCursor(frame, includeDescendants, x, y)
    local left, bottom, width, height = self:GetFrameInteractionRect(frame, includeDescendants)
    if type(x) ~= "number" or type(y) ~= "number" then x, y = self:GetUICursorPosition() end
    if not left or not x or not y then return false end
    return x >= left and x <= left + width and y >= bottom and y <= bottom + height
end

-- Kept as a compatibility helper for integrations that used the 2.1 picker
-- method. It performs one bounded snapshot, never a permanent live scan.
function ns:GetFramesUnderCursor()
    local atlas = self:BeginPickerAtlas()
    while not self:ContinuePickerAtlas(atlas, 500) do end
    local x, y = self:GetUICursorPosition()
    return self:GetPickerAtlasCandidates(atlas, x, y)
end

function ns:GetUIParentFrameRoots(includeHidden)
    local result = {}
    for _, root in ipairs(UIParentChildren()) do
        if root and root ~= WorldFrame and not IsForbiddenFrame(root) and not self:IsFrameGambitFrame(root) then
            local left
            if not includeHidden then
                left = self:GetUsableFrameRect(root)
                local name = SafeMethod(root, "GetName")
                if not left and type(name) == "string" then left = self:GetFrameInteractionRect(root) end
            end
            -- Cinematic pre-leases hidden anonymous roots too. Their OnShow and
            -- SetAlpha post-hooks are then already installed before combat or a
            -- late addon repaint can make them flash at full opacity.
            if includeHidden or left then
                result[#result + 1] = root
            end
        end
    end
    return result
end

-- Ellesmere's unit buttons deliberately share one full-screen secure hider.
-- That structural parent must stay visible so player/target can use PF rules,
-- while the other unit buttons are faded independently by Cinematic Mode.
local EUI_UNIT_HIDER = "EllesmereUIUnitFrames_Hider"
local EUI_UNIT_CHILDREN = {
    "EllesmereUIUnitFrames_Player", "EllesmereUIUnitFrames_Target",
    "EllesmereUIUnitFrames_Focus", "EllesmereUIUnitFrames_Pet",
    "EllesmereUIUnitFrames_TargetTarget", "EllesmereUIUnitFrames_FocusTarget",
    "EllesmereUIUnitFrames_Boss1", "EllesmereUIUnitFrames_Boss2",
    "EllesmereUIUnitFrames_Boss3", "EllesmereUIUnitFrames_Boss4",
    "EllesmereUIUnitFrames_Boss5",
}

function ns:GetEUIUnitFrameBoundary(frame)
    local unwrap = frame and SafeMethod(frame, "GetFrameGambitVisualFrame")
    if unwrap then frame = unwrap end
    local hider = _G[EUI_UNIT_HIDER]
    if not frame or not hider then return nil end
    local current, seen, depth = frame, {}, 0
    while current and depth < 12 and not seen[current] do
        if current == hider then return hider end
        seen[current] = true
        current = SafeMethod(current, "GetParent")
        depth = depth + 1
    end
end

function ns:GetEUIUnitFrameOwner(frame)
    local unwrap = frame and SafeMethod(frame, "GetFrameGambitVisualFrame")
    if unwrap then frame = unwrap end
    local hider = self:GetEUIUnitFrameBoundary(frame)
    if not hider then return nil end
    local current, seen, depth = frame, {}, 0
    while current and depth < 12 and not seen[current] do
        seen[current] = true
        local parent = SafeMethod(current, "GetParent")
        if parent == hider then return current end
        current = parent
        depth = depth + 1
    end
end

function ns:GetCinematicNestedBlackoutFrames()
    local hider = _G[EUI_UNIT_HIDER]
    local result = {}
    if not hider then return result end
    for _, name in ipairs(EUI_UNIT_CHILDREN) do
        local frame = _G[name]
        if frame and self:GetEUIUnitFrameBoundary(frame) == hider and not IsForbiddenFrame(frame) then
            result[#result + 1] = frame
        end
    end
    return result
end

function ns:GetVisibleFrameRoots()
    return self:GetUIParentFrameRoots(false)
end

local function StableFrameID(name)
    local checksum = 0
    for index = 1, #name do checksum = (checksum * 33 + string.byte(name, index)) % 2147483647 end
    return "custom_frame_" .. checksum
end

function ns:RegisterDiscoveredFrame(frame, label, exactFrame)
    if self.GetDetailsTargetForFrame then
        local detailsID = self:GetDetailsTargetForFrame(frame)
        if detailsID then return detailsID end
    end
    if self.GetSemanticProviderTargetForFrame then
        local providerID = self:GetSemanticProviderTargetForFrame(frame)
        if providerID then return providerID end
    end
    local root = self:GetFramePickerRoot(frame)
    if not root then return nil, "That frame cannot be managed safely." end
    local managed = exactFrame and frame or root
    if not IsUsableTargetFrame(managed) or IsForbiddenFrame(managed) or self:IsFrameGambitFrame(managed) then
        return nil, "That frame cannot be managed safely."
    end
    for _, target in ipairs(self.Targets) do
        local existing = self:ResolveTarget(target.id)
        local visual = existing and SafeMethod(existing, "GetFrameGambitVisualFrame")
        if existing == managed or visual == managed then return target.id end
    end
    -- A container and its descendants may have separate rules. Only the same
    -- resolved frame is a duplicate (handled above); native parent opacity
    -- inheritance still applies regardless of the order they are added.
    local name = SafeMethod(managed, "GetName")
    if type(name) == "string" and name ~= "" and _G[name] == managed then
        local id = StableFrameID(name)
        if not self.TargetByID[id] then
            local registered, reason = self:RegisterTarget({
                id = id,
                label = (type(label) == "string" and label ~= "" and label or name):sub(1, 64),
                source = "Frame picker",
                names = { name },
                protected = true,
                capability = exactFrame and "Saved frame" or "Saved window",
                capabilityNote = "This selection remains available after reload. Frame Gambit changes only its opacity.",
                capabilityTone = "teal",
            })
            if not registered then return nil, reason end
        end
        FrameGambitDB.customTargets = type(FrameGambitDB.customTargets) == "table" and FrameGambitDB.customTargets or {}
        FrameGambitDB.customTargets[id] = {
            name = name,
            label = (type(label) == "string" and label ~= "" and label or name):sub(1, 64),
            exact = exactFrame == true,
        }
        return id
    end
    self._sessionFrameSerial = (self._sessionFrameSerial or 0) + 1
    local id = "session_frame_" .. self._sessionFrameSerial
    local registered, reason = self:RegisterTarget({
        id = id,
        label = (type(label) == "string" and label ~= "" and label or (exactFrame and "Unnamed frame" or "Unnamed window")):sub(1, 64),
        source = "Frame picker (session only)",
        resolve = function() return managed end,
        protected = true,
        capability = exactFrame and "Temporary frame" or "Temporary window",
        capabilityNote = "This unnamed frame can fade until you reload. Named addon frames are saved automatically.",
        capabilityTone = "amber",
    })
    return registered and id or nil, reason
end

function ns:RegisterStoredCustomFrames()
    local stored = FrameGambitDB and FrameGambitDB.customTargets
    if type(stored) ~= "table" then return end
    for id, entry in pairs(stored) do
        if type(id) == "string" and type(entry) == "table" and type(entry.name) == "string"
            and not self.TargetByID[id] then
            self:RegisterTarget({
                id = id,
                label = (type(entry.label) == "string" and entry.label ~= "" and entry.label or entry.name):sub(1, 64),
                source = "Frame picker",
                names = { entry.name },
                protected = true,
                capability = entry.exact == true and "Saved frame" or "Saved window",
                capabilityNote = "This selection remains available after reload. Frame Gambit changes only its opacity.",
                capabilityTone = "teal",
            })
        end
    end
end

function ns:CanForgetCustomTarget(id)
    if type(id) ~= "string" then return false end
    local stored = FrameGambitDB and FrameGambitDB.customTargets
    return (type(stored) == "table" and stored[id] ~= nil)
        or id:match("^session_frame_") ~= nil
end

local function RemoveTargetFromSavedProfile(profile, id)
    if type(profile) ~= "table" then return end
    profile.targets = type(profile.targets) == "table" and profile.targets or {}
    profile.groups = type(profile.groups) == "table" and profile.groups or {}
    profile.links = type(profile.links) == "table" and profile.links or {}
    profile.visibilityLinks = type(profile.visibilityLinks) == "table" and profile.visibilityLinks or {}
    profile.targets[id] = nil
    for groupID, group in pairs(profile.groups) do
        if type(group) ~= "table" or type(group.members) ~= "table" then
            profile.groups[groupID] = nil
        else
            group.members[id] = nil
            local count = 0
            for memberID, enabled in pairs(group.members) do
                if type(memberID) == "string" and enabled == true then count = count + 1 end
            end
            if count < 2 then profile.groups[groupID] = nil end
        end
    end
    profile.links[id] = nil
    for parentID, children in pairs(profile.links) do
        if type(children) ~= "table" then
            profile.links[parentID] = nil
        else
            children[id] = nil
            if not next(children) then profile.links[parentID] = nil end
        end
    end
    profile.visibilityLinks[id] = nil
    for parentID, children in pairs(profile.visibilityLinks) do
        if type(children) ~= "table" then
            profile.visibilityLinks[parentID] = nil
        else
            children[id] = nil
            if not next(children) then profile.visibilityLinks[parentID] = nil end
        end
    end
end

function ns:ForgetCustomTarget(id)
    if not self:CanForgetCustomTarget(id) then
        return false, "Built-in frames and frames added by other addons cannot be removed here."
    end
    -- Restore the live frame before removing its resolver and catalog entry.
    if self.Profile and self:Profile().targets[id] then self:RemoveTarget(id) end
    local db = FrameGambitDB
    for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
        RemoveTargetFromSavedProfile(profile, id)
    end
    if type(db.customTargets) == "table" then db.customTargets[id] = nil end
    for index = #self.Targets, 1, -1 do
        if self.Targets[index].id == id then table.remove(self.Targets, index) end
    end
    self.TargetByID[id] = nil
    if self.Options and self.Options.selected == id then self.Options.selected = nil end
    if self.ReconcileCinematicOwnership then self:ReconcileCinematicOwnership() end
    self:RefreshOptions()
    return true, "Frame removed from the catalog and every profile."
end

function ns:DiscoverVisibleFrameRoots()
    local added, firstID = 0, nil
    self._batchRegistering = true
    for _, root in ipairs(self:GetVisibleFrameRoots()) do
        local name = SafeMethod(root, "GetName")
        if type(name) == "string" and name ~= "" and not name:match("^StaticPopup")
            and not name:match("^NamePlate") and not name:match("^OPie") then
            local beforeCount = #self.Targets
            local id = self:RegisterDiscoveredFrame(root, DiscoveredLabel(name))
            if id then
                if #self.Targets > beforeCount then added = added + 1 end
                firstID = firstID or id
            end
        end
    end
    self._batchRegistering = nil
    return added, firstID
end
