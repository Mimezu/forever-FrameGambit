local ADDON, ns = ...

-- A Details meter is not one ordinary frame. Its title/background lives on
-- DetailsBaseFrameN while its visible bars live on the UIParent sibling
-- DetailsRowFrameN. Treating either one as the target leaves half the meter
-- behind, so this adapter presents both as one logical Priority Fader target.
-- Details remains the owner of layout, styling, data, and interaction.

local proxies = {}
local memberOwner = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local guarded = setmetatable({}, { __mode = "k" })
local pendingRestore = setmetatable({}, { __mode = "k" })

local function Secret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function Alpha(frame)
    if not frame then return nil end
    local ok, value = pcall(function() return frame:GetAlpha() end)
    if ok and type(value) == "number" and not Secret(value) and value == value and value >= 0 and value <= 1 then
        return value
    end
end

local function SetAlpha(frame, value)
    if not frame or type(value) ~= "number" then return false end
    guarded[frame] = true
    local ok = pcall(function() frame:SetAlpha(value) end)
    guarded[frame] = nil
    return ok
end

local function Shown(frame)
    if not frame then return false end
    local ok, value = pcall(function() return frame:IsShown() end)
    return ok and not Secret(value) and value == true
end

local function Usable(frame)
    if not frame then return false end
    local ok, getAlpha, setAlpha, getRect, isShown = pcall(function()
        return frame.GetAlpha, frame.SetAlpha, frame.GetRect, frame.IsShown
    end)
    return ok and type(getAlpha) == "function" and type(setAlpha) == "function"
        and type(getRect) == "function" and type(isShown) == "function"
end

local function ProcessPending()
    if InCombatLockdown and InCombatLockdown() then return end
    for frame, record in pairs(pendingRestore) do
        local live = Alpha(frame)
        if live ~= nil and math.abs(live - record.lastApplied) > 0.001 then
            pendingRestore[frame] = nil
        elseif live ~= nil and SetAlpha(frame, record.base) then
            pendingRestore[frame] = nil
        end
    end
end

local function CaptureBase(frame)
    local live = Alpha(frame)
    if live == nil then return nil end
    local pending = pendingRestore[frame]
    if pending then
        if math.abs(live - pending.lastApplied) <= 0.001 then live = pending.base end
        pendingRestore[frame] = nil
    end
    return live
end

local function RestoreMember(state, frame)
    local record = state.records[frame]
    if not record then return end
    local live = Alpha(frame)
    if live == nil then
        pendingRestore[frame] = { base = record.base, lastApplied = record.lastApplied }
    elseif math.abs(live - record.lastApplied) <= 0.001 and not SetAlpha(frame, record.base) then
        pendingRestore[frame] = { base = record.base, lastApplied = record.lastApplied }
    end
    state.records[frame] = nil
    if memberOwner[frame] == state then memberOwner[frame] = nil end
end

local function HostAlphaChanged(frame, value)
    local state = memberOwner[frame]
    if not state or not state.active or guarded[frame] then return end
    local record = state.records[frame]
    if not record then return end
    if type(value) == "number" and not Secret(value) and value == value and value >= 0 and value <= 1 then
        record.base = value
    end
    if SetAlpha(frame, state.applied) then record.lastApplied = state.applied end
end

local function Hook(frame)
    if hooked[frame] then return true end
    if type(hooksecurefunc) == "function" and pcall(hooksecurefunc, frame, "SetAlpha", HostAlphaChanged) then
        hooked[frame] = true
    end
    return hooked[frame] == true
end

local function GetInstance(index)
    local details = _G.Details
    if details and type(details.GetInstance) == "function" then
        local ok, instance = pcall(function() return details:GetInstance(index) end)
        if ok and type(instance) == "table" then
            if type(instance.IsEnabled) == "function" then
                local enabledOK, enabled = pcall(instance.IsEnabled, instance)
                if enabledOK and enabled == false then return nil end
            end
            return instance
        end
    end
end

local function CurrentMembers(index)
    local instance = GetInstance(index)
    -- Named frames can survive a disabled/deleted Details instance. The
    -- instance API is authoritative; never resurrect one through stale globals.
    if not instance then return nil end
    local base = instance.baseframe
    local rows = instance.rowframe
    local members, seen = {}, {}
    for _, frame in ipairs({ base, rows }) do
        if Usable(frame) and not seen[frame] then
            seen[frame] = true
            members[#members + 1] = frame
        end
    end
    if #members == 0 then return nil end
    local geometry = {}
    for _, frame in ipairs({ base, rows, base and base.titleBar, base and base.UPFrame }) do
        if frame and not seen[frame] then
            local ok, getRect = pcall(function() return frame.GetRect end)
            if ok and type(getRect) == "function" then geometry[#geometry + 1] = frame end
        elseif frame then
            geometry[#geometry + 1] = frame
        end
    end
    return members, members[1], geometry
end

local function Refresh(state)
    -- ResolveTarget, IsShown, GetAlpha and hover geometry can all consult the
    -- same composite proxy during one evaluator pass. Collapse only those
    -- back-to-back reads; the 10 ms window is far below the 50 ms evaluator
    -- cadence and never delays a meaningful Details instance rebuild.
    local now = GetTime()
    if state.refreshAt and now - state.refreshAt < 0.01 then return state.refreshOK end
    local function Finish(ok)
        state.refreshAt, state.refreshOK = now, ok
        return ok
    end
    ProcessPending()
    local members, visual, geometry = CurrentMembers(state.index)
    if not members then return Finish(false) end
    local current = {}
    for _, frame in ipairs(members) do current[frame] = true end
    if state.active then
        for _, old in ipairs(state.members) do
            if not current[old] then RestoreMember(state, old) end
        end
        for _, frame in ipairs(members) do
            if not state.records[frame] then
                local base = CaptureBase(frame)
                if base == nil then return Finish(false) end
                state.records[frame] = { base = base, lastApplied = state.applied }
                memberOwner[frame] = state
                Hook(frame)
                if not SetAlpha(frame, state.applied) then return Finish(false) end
            elseif not hooked[frame] then
                local live = Alpha(frame)
                if live == nil then return Finish(false) end
                if math.abs(live - state.applied) > 0.001 then
                    state.records[frame].base = live
                    if not SetAlpha(frame, state.applied) then return Finish(false) end
                end
            end
            state.records[frame].lastApplied = state.applied
        end
    end
    state.members, state.visual, state.geometry = members, visual, geometry
    return Finish(true)
end

local function UnionRect(frames)
    local left, bottom, right, top
    for _, frame in ipairs(frames or {}) do
        -- Members can have different scales; union them in UIParent units.
        local ok, x, y, width, height = pcall(ns.GetUsableFrameRect, ns, frame)
        if ok and type(x) == "number" and type(y) == "number" and type(width) == "number" and type(height) == "number"
            and not Secret(x) and not Secret(y) and not Secret(width) and not Secret(height)
            and x == x and y == y and width == width and height == height and width > 0 and height > 0 then
            left = left and math.min(left, x) or x
            bottom = bottom and math.min(bottom, y) or y
            right = right and math.max(right, x + width) or x + width
            top = top and math.max(top, y + height) or y + height
        end
    end
    if left then return left, bottom, right - left, top - bottom end
end

local function MakeProxy(index)
    local state = { index = index, active = false, applied = 1, members = {}, records = setmetatable({}, { __mode = "k" }) }
    local proxy = {}
    state.proxy = proxy

    function proxy:GetFrameGambitVisualFrame()
        Refresh(state)
        return state.visual
    end
    function proxy:GetFrameGambitCinematicFrames()
        if not Refresh(state) then return nil end
        return state.members
    end
    function proxy:GetRect()
        if not Refresh(state) then return nil end
        return UnionRect(state.geometry or state.members)
    end
    function proxy:GetEffectiveScale()
        return UIParent:GetEffectiveScale()
    end
    function proxy:IsShown()
        if not Refresh(state) then return false end
        for _, frame in ipairs(state.members) do if Shown(frame) then return true end end
        return false
    end
    function proxy:GetAlpha()
        if not Refresh(state) then return nil end
        return state.active and state.applied or Alpha(state.visual)
    end
    function proxy:SetAlpha(value)
        if type(value) ~= "number" or Secret(value) or value ~= value or value < 0 or value > 1 then return end
        if not Refresh(state) then error("Frame Gambit could not resolve this Details window.", 0) end
        for _, frame in ipairs(state.members) do
            if not SetAlpha(frame, value) then error("Frame Gambit could not fade this Details window.", 0) end
        end
        state.applied = value
        for _, frame in ipairs(state.members) do
            if state.records[frame] then state.records[frame].lastApplied = value end
        end
    end

    function state:Acquire(frame)
        if frame ~= proxy or not Refresh(self) then return false end
        if not self.active then
            local first
            for _, member in ipairs(self.members) do
                local base = CaptureBase(member)
                if base == nil then return false end
                self.records[member] = { base = base, lastApplied = base }
                memberOwner[member] = self
                Hook(member)
                first = first or base
            end
            self.applied, self.active = first or 1, true
        end
        return true
    end

    function state:Release(frame)
        if frame ~= proxy or not self.active then return end
        for _, member in ipairs(self.members) do RestoreMember(self, member) end
        self.active = false
    end
    return state
end

local function RegisterDetailsTargets()
    if not _G.Details then return end
    local registeredAny = false
    local wasBatching = ns._batchRegistering
    ns._batchRegistering = true
    for index = 1, 5 do
        local slot = index
        local id = "details_window_" .. slot
        if not ns.TargetByID[id] then
            local registered = ns:RegisterTarget({
                id = id,
                label = "Details window " .. slot,
                source = "Details",
                resolve = function() return nil end,
                protected = false,
            })
            registeredAny = registeredAny or registered == true
        end
        local target = ns.TargetByID and ns.TargetByID[id]
        if target and not proxies[slot] then
            local state = MakeProxy(slot)
            proxies[slot] = state
            target.names = nil
            target.resolve = function() return Refresh(state) and state.proxy or nil end
            target.acquire = function(frame) return state:Acquire(frame) end
            target.release = function(frame) return state:Release(frame) end
            target.skipManagedAlphaHook = true
            target.capability = "Complete Details window"
            target.capabilityTone = "teal"
            target.capabilityNote = "Fades the title, controls, background, and meter rows together. Details keeps its data, styling, layout, and interactions."
        end
    end
    ns._batchRegistering = wasBatching
    if registeredAny and not wasBatching and ns.RefreshOptions then ns:RefreshOptions() end
end

RegisterDetailsTargets()

function ns:GetDetailsTargetForFrame(frame)
    if not frame then return nil end
    local current, seen, depth = frame, {}, 0
    while current and not seen[current] and depth < 16 do
        seen[current] = true
        for index, state in ipairs(proxies) do
            if Refresh(state) then
                for _, member in ipairs(state.members) do
                    if current == member then return "details_window_" .. index end
                end
            end
        end
        local ok, parent = pcall(function() return current:GetParent() end)
        current = ok and parent or nil
        depth = depth + 1
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, addonName)
    if event == "PLAYER_REGEN_ENABLED" then
        ProcessPending()
    elseif addonName == "Details" then
        RegisterDetailsTargets()
    end
end)
