local ADDON, ns = ...

-- A semantic container: chat tabs can move between independent dock roots,
-- so never change Blizzard's hierarchy. Only alpha roots
-- (and descendants which ignore parent alpha) receive our multiplier.
local proxy = {}
local active, multiplier, refreshing = false, 1, false
local owned, hooked, guards = {}, {}, {}
local surfaces = {}
local Refresh
local dirty = true

local function Method(frame, key, ...)
    if not frame then return nil end
    local ok, fn = pcall(function() return frame[key] end)
    if not ok or type(fn) ~= "function" then return nil end
    local success, value = pcall(fn, frame, ...)
    if success and not (issecretvalue and issecretvalue(value)) then return value end
end

local function ValidAlpha(value)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
        and value == value and value >= 0 and value <= 1
end

local function Write(frame, value)
    guards[frame] = true
    local ok = pcall(frame.SetAlpha, frame, value)
    guards[frame] = nil
    return ok
end

local function Apply(frame, record)
    local value = record.base * multiplier
    if Write(frame, value) then
        -- The client can round alpha on write. Compare future audits with the
        -- readback, never treat that rounding as a new native baseline.
        local readback = Method(frame, "GetAlpha")
        record.applied = ValidAlpha(readback) and readback or value
    end
end

local function Restore(frame, record)
    -- Preserve external writes if a hook could not be installed.
    local alpha = Method(frame, "GetAlpha")
    if not ValidAlpha(alpha) then return false end
    if record.applied == nil or alpha == record.applied then
        return Write(frame, record.base)
    end
    return true
end

local function Hook(frame)
    if hooked[frame] or type(hooksecurefunc) ~= "function" then return end
    hooked[frame] = pcall(hooksecurefunc, frame, "SetAlpha", function(_, value)
        local record = owned[frame]
        if guards[frame] or not record or not active then return end
        if not ValidAlpha(value) then return end
        record.base = value
        Apply(frame, record)
    end)
end

local function Collect()
    local list, seen = {}, {}
    local function Add(frame)
        if frame and not seen[frame] and type(frame.SetAlpha) == "function" then
            seen[frame] = true
            list[#list + 1] = frame
        end
    end
    local function Chat(name)
        local frame = _G[name]
        if not frame then return end
        Add(frame)
        for _, suffix in ipairs({ "Tab", "EditBox", "ButtonFrame", "Minimized" }) do
            Add(_G[name .. suffix])
        end
        Add(frame.editBox)
        Add(frame.buttonFrame)
        Add(frame.minFrame)
    end
    -- CHAT_FRAMES includes temporary windows beyond NUM_CHAT_WINDOWS; no cap.
    for _, name in pairs(CHAT_FRAMES or {}) do
        if type(name) == "string" then Chat(name) end
    end
    for index = 1, (NUM_CHAT_WINDOWS or 10) do Chat("ChatFrame" .. index) end
    Add(GeneralDockManager)
    Add(GENERAL_CHAT_DOCK)
    Add(ChatFrameMenuButton)
    Add(ChatFrameChannelButton)
    Add(ChatFrameToggleVoiceDeafenButton)
    Add(ChatFrameToggleVoiceMuteButton)
    -- Discover alpha escapees, including unnamed/pool-created chrome.
    local budget = 1024
    local function Walk(frame, depth)
        if depth > 12 or budget <= 0 then return end
        for _, getter in ipairs({ "GetChildren", "GetRegions" }) do
            if type(frame[getter]) == "function" then
                local values = { pcall(frame[getter], frame) }
                if table.remove(values, 1) then
                    for _, child in ipairs(values) do
                        if not seen[child] then
                            seen[child] = true
                            budget = budget - 1
                            if budget < 0 then return end
                            if Method(child, "IsIgnoringParentAlpha") then list[#list + 1] = child end
                            Walk(child, depth + 1)
                        end
                    end
                end
            end
        end
    end
    for _, frame in ipairs(list) do Walk(frame, 0) end
    local candidates, roots = {}, {}
    for _, frame in ipairs(list) do candidates[frame] = true end
    for _, frame in ipairs(list) do
        local parent, covered, visited = frame, false, {}
        while parent and not visited[parent] do
            visited[parent] = true
            if Method(parent, "IsIgnoringParentAlpha") then break end
            parent = Method(parent, "GetParent")
            if candidates[parent] then covered = true; break end
        end
        if not covered then roots[frame] = true end
    end
    return list, roots
end

Refresh = function()
    if refreshing then return end
    refreshing = true
    dirty = false
    local roots
    surfaces, roots = Collect()
    if active then
        -- Restore former roots BEFORE claiming new ones after docking changes.
        for frame, record in pairs(owned) do
            if not roots[frame] and Restore(frame, record) then owned[frame] = nil end
        end
        for frame in pairs(roots) do
            local record = owned[frame]
            if not record then
                local alpha = Method(frame, "GetAlpha")
                if ValidAlpha(alpha) then
                    record = { base = alpha }
                    owned[frame] = record
                    Hook(frame)
                end
            end
            if record then
                local alpha = Method(frame, "GetAlpha")
                if ValidAlpha(alpha) and record.applied and alpha ~= record.applied then record.base = alpha end
                Apply(frame, record)
            end
        end
    else
        for frame, record in pairs(owned) do
            if Restore(frame, record) then owned[frame] = nil end
        end
    end
    refreshing = false
end

function proxy:GetAlpha() return multiplier end
function proxy:SetAlpha(value)
    if not ValidAlpha(value) then return end
    multiplier = value
    if active then
        for frame, record in pairs(owned) do Apply(frame, record) end
    end
end
function proxy:IsShown() return ChatFrame1 ~= nil end
function proxy:GetFrameGambitVisualFrame() return ChatFrame1 end
function proxy:GetFrameGambitCinematicFrames()
    Refresh()
    return surfaces
end
function proxy:GetEffectiveScale() return Method(UIParent, "GetEffectiveScale") or 1 end
function proxy:GetRect()
    local left, bottom, right, top
    local scale = self:GetEffectiveScale()
    for _, frame in ipairs(surfaces) do
        if Method(frame, "IsShown") and type(frame.GetRect) == "function" then
            local ok, x, y, w, h = pcall(frame.GetRect, frame)
            local usable = ok
            for _, value in ipairs({ x, y, w, h }) do
                if (issecretvalue and issecretvalue(value)) or type(value) ~= "number" then usable = false end
            end
            if usable and x and y and w and h and w > 0 and h > 0 then
                local ratio = (Method(frame, "GetEffectiveScale") or scale) / scale
                x, y, w, h = x * ratio, y * ratio, w * ratio, h * ratio
                left = left and math.min(left, x) or x
                bottom = bottom and math.min(bottom, y) or y
                right = right and math.max(right, x + w) or x + w
                top = top and math.max(top, y + h) or y + h
            end
        end
    end
    if left then return left, bottom, right - left, top - bottom end
end

local target = ns.TargetByID.chat
target.resolve = function()
    if dirty or #surfaces == 0 then Refresh() end
    return ChatFrame1 and proxy or nil
end
target.acquire = function(frame)
    if frame ~= proxy then return false end
    active, multiplier = true, 1
    Refresh()
    return true
end
target.release = function(frame)
    if frame ~= proxy then return end
    active, multiplier = false, 1
    Refresh()
    if next(owned) then error("Chat alpha restoration pending", 0) end
end
target.skipManagedAlphaHook = true
target.source = "Blizzard whole chat / Ellesmere Chat"
target.capabilityNote = "All chat windows, including future whispers, tabs, input, dock and attached controls share one opacity. Native docking and styling are preserved."

local lifecycleHooks = {}
local function Lifecycle()
    dirty = true
    if active or next(owned) then Refresh() end
    if active and ns.Wake then ns:Wake() end
end
local function InstallHooks()
    if type(hooksecurefunc) ~= "function" then return end
    for _, name in ipairs({ "FCF_OpenTemporaryWindow", "FCF_OpenNewWindow", "FCF_DockFrame",
        "FCF_UnDockFrame", "FCF_Close", "FCF_MinimizeFrame", "FCF_MaximizeFrame",
        "FCF_SetFullScreenFrame", "FCF_ClearFullScreenFrame" }) do
        if not lifecycleHooks[name] and type(_G[name]) == "function" then
            lifecycleHooks[name] = pcall(hooksecurefunc, name, Lifecycle)
        end
    end
end
local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "ADDON_LOADED", "PLAYER_REGEN_ENABLED", "UPDATE_CHAT_WINDOWS" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function() InstallHooks(); Lifecycle() end)
-- Lifecycle signals discover new windows and recycled chrome. Core may also
-- call this bounded shared audit while its evaluator is already awake.
local nextAudit = 0
function ns:RefreshChatStack()
    if not active and not next(owned) then return end
    local now = GetTime()
    if now < nextAudit then return end
    nextAudit = now + 0.5
    Refresh()
end
InstallHooks()
