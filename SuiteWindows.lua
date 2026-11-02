local _, ns = ...

-- Editor/dialog roots only. Do not whitelist entire addon prefixes: their
-- minimap buttons, action bars and other HUD widgets remain configurable.
local windowNames = {
    "BindCardsFrame", "BindCardsAppearancePopover", "BindCardsAbilityInspector",
    "BindCardsBindingCapture", "BindCardsHeaderMenu", "BindCardsModal",
    "BindCardsModalOverlay", "BindCardsProfileManager", "BindCardsProfileTransfer",
    "BindCardsProfileTransferOverlay",
    "WardrobeTimeCapsuleFrame", "WardrobeTimeCapsuleMainWindow",
    "WardrobeTimeCapsuleHelpWindow", "WardrobeTimeCapsuleQuickCapture",
    "ResonanceOptionsPanel", "ResonanceHelpWindow", "ResonanceSoundPicker",
    "ResonanceSoundSetWindow", "ResonanceTutorialOverlay", "ResonanceForeverEditor",
    "ResonanceForeverLibrary", "ResonanceForeverSets",
    "ForeverNamesOptions", "ForeverNamesOptionsB", "CompanionJournalOptions", "CompanionJournalBook", "GamepadCompanionLayoutPanel",
    "MuscleMemoryAtlasFrame", "MuscleMemoryAtlasHelpFrame",
    "CPULoadManagerManualDropdown",
    -- Suite extensions embedded in Blizzard settings use these native dialogs.
    "SettingsPanel", "InterfaceOptionsFrame", "CooldownViewerSettings",
    "CooldownViewerSettingsEditAlert",
}
local names = {}
for _, name in ipairs(windowNames) do names[name] = true end
local registered = setmetatable({}, { __mode = "k" })
local function IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

function ns:IsCinematicSuiteWindow(frame)
    for _ = 1, 64 do
        if IsSecret(frame) or not frame then return false end
        if frame == UIParent or frame == WorldFrame then return false end
        if registered[frame] then return true end
        local ok, name = pcall(function() return frame:GetName() end)
        if ok and not IsSecret(name) and type(name) == "string" and names[name]
            and _G[name] == frame then return true end
        local parentOK, parent = pcall(function() return frame:GetParent() end)
        if not parentOK or IsSecret(parent) or parent == frame then return false end
        frame = parent
    end
    return false
end

-- Future suite dialogs can opt in without changing their parenting or strata.
FrameGambitAPI = FrameGambitAPI or {}
function FrameGambitAPI.RegisterCinematicWindow(frame)
    if IsSecret(frame) or not frame or frame == UIParent or frame == WorldFrame then return false end
    local ok, valid = pcall(function() return type(frame.GetParent) == "function" and type(frame.GetName) == "function" end)
    if not ok or not valid then return false end
    registered[frame] = true
    if ns.Wake then ns:Wake() end
    return true
end
