local ADDON, ns = ...

-- Semantic providers keep the core independent from any one UI addon. A role
-- describes what the visual means; optional providers supply the live roots.
-- Missing providers simply contribute nothing, and Blizzard fallbacks remain.

local sceneProviders = {}
ns.SceneProviders = sceneProviders

function ns:RegisterSceneProvider(definition)
    if type(definition) ~= "table" or type(definition.id) ~= "string" or definition.id == ""
        or type(definition.role) ~= "string" or definition.role == ""
        or type(definition.resolve) ~= "function" then
        return false, "Scene providers require id, role, and resolve()."
    end
    if sceneProviders[definition.id] then return false, "That scene provider is already registered." end
    sceneProviders[definition.id] = {
        id = definition.id,
        role = definition.role,
        resolve = definition.resolve,
        cinematicKeep = definition.cinematicKeep == true,
    }
    if self.IsCinematicActive and self:IsCinematicActive() and self.BeginCinematicBlackout then
        C_Timer.After(0, function()
            if ns:IsCinematicActive() then ns:BeginCinematicBlackout() end
        end)
    end
    return true
end

local function AddProviderFrame(frames, frame)
    if not frame then return end
    local ok, getParent = pcall(function() return frame.GetParent end)
    if not ok or type(getParent) ~= "function" then return end
    frames[frame] = true
    local root = ns.GetFramePickerRoot and ns:GetFramePickerRoot(frame)
    if root then frames[root] = true end
end

function ns:AddSceneProviderExemptions(frames)
    for _, provider in pairs(sceneProviders) do
        if provider.cinematicKeep then
            local ok, result = pcall(provider.resolve)
            if ok and result then
                local methodOK, getParent = pcall(function() return result.GetParent end)
                if methodOK and type(getParent) == "function" then
                    AddProviderFrame(frames, result)
                elseif type(result) == "table" then
                    for _, frame in pairs(result) do AddProviderFrame(frames, frame) end
                end
            end
        end
    end
end

-- Quest-conversation role: prefer DialogueUI when it owns the interaction;
-- native frames remain registered as a no-addon fallback.
ns:RegisterSceneProvider({
    id = "dialogueui_quest",
    role = "quest_dialogue",
    cinematicKeep = true,
    resolve = function() return _G.DUIQuestFrame end,
})
ns:RegisterSceneProvider({
    id = "blizzard_quest",
    role = "quest_dialogue",
    cinematicKeep = true,
    resolve = function() return { _G.QuestFrame, _G.GossipFrame } end,
})

-- Quick-action role. OPie's anonymous renderer still uses its dedicated
-- structural resolver; Quickdraw has one stable public visual root.
ns:RegisterSceneProvider({
    id = "eui_quickdraw",
    role = "quick_actions",
    cinematicKeep = true,
    resolve = function() return _G.EUIQuickdrawFrame end,
})

local euiDamageRegistered = false
local function EUIDamageNamespace()
    local eui = _G.EllesmereUI
    local modules = eui and eui._ModuleNS
    return type(modules) == "table" and modules["EllesmereUIDamageMeters"] or nil
end

local function EUIDamageFrame(index)
    local module = EUIDamageNamespace()
    local windows = module and module._windows
    local window = type(windows) == "table" and windows[index] or nil
    local frame = type(window) == "table" and window.frame or nil
    return frame
end

local function RegisterEUIDamageMeters()
    if euiDamageRegistered or not EUIDamageNamespace() then return end
    euiDamageRegistered = true
    for index = 1, 5 do
        local slot = index
        ns:RegisterTarget({
            id = "eui_damage_meter_" .. slot,
            label = "Ellesmere Damage Meter " .. slot,
            source = "Ellesmere Damage Meters",
            resolve = function() return EUIDamageFrame(slot) end,
            protected = false,
            capability = "Complete EUI meter",
            capabilityTone = "teal",
            capabilityNote = "Fades this current Ellesmere damage-meter window. Ellesmere keeps its data, visibility mode, styling, layout, and window lifecycle.",
        })
    end
end

RegisterEUIDamageMeters()

function ns:GetSemanticProviderTargetForFrame(frame)
    local current, seen, depth = frame, {}, 0
    while current and not seen[current] and depth < 16 do
        seen[current] = true
        if current == _G.DamageMeterSessionWindow1 then return "blizzard_damage_meter" end
        for index = 1, 5 do
            if current == EUIDamageFrame(index) then return "eui_damage_meter_" .. index end
        end
        local ok, parent = pcall(function() return current:GetParent() end)
        current = ok and parent or nil
        depth = depth + 1
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, addonName)
    if addonName == "EllesmereUIDamageMeters" or addonName == "EllesmereUI" then
        RegisterEUIDamageMeters()
        if ns.IsCinematicActive and ns:IsCinematicActive() and ns.BeginCinematicBlackout then
            ns:BeginCinematicBlackout()
        end
    end
end)

FrameGambitAPI = FrameGambitAPI or {}
FrameGambitAPI.version = 2
function FrameGambitAPI.RegisterSceneProvider(definition)
    return ns:RegisterSceneProvider(definition)
end
PriorityFaderAPI = FrameGambitAPI
