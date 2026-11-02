local _, ns = ...
local target = ns.TargetByID.party_frames
local regionHooks, guards = setmetatable({}, { __mode = "k" }), {}
local states = setmetatable({}, { __mode = "k" })
local memberPrefixes = { "CompactPartyFrameMember", "CompactPartyFramePet" }

local function Call(frame, method)
    local ok, value = pcall(function() return frame[method](frame) end)
    if ok and not (issecretvalue and issecretvalue(value)) then return value end
end

local function Alpha(frame)
    local value = Call(frame, "GetAlpha")
    if type(value) == "number" and value == value and value >= 0 and value <= 1 then return value end
end

local function RootAlpha(root)
    -- The root SetAlpha hook runs before Core stores the protected result.
    local ok, value = pcall(root.GetAlpha, root)
    if ok and issecretvalue and issecretvalue(value) then return { value = value } end
    return Alpha(root)
end

local function Scaled(opacity, base, root)
    -- A late-created border can already have an opaque alpha aspect. Keep
    -- that native value for restoration; while leased use the owner's alpha.
    if type(base) == "table" then
        if type(opacity) == "table" then return opacity.value end
        return opacity
    end
    if type(opacity) == "table" then
        -- Forward native alpha-1 borders directly. Curve:Evaluate(secret) is
        -- forbidden in addon execution, even though SetAlpha accepts it.
        if base == 1 then return opacity.value end
        return ns:GetManagedScaledPercentageOpacity(root, base)
    end
    return base * opacity
end

local function Write(region, record, value)
    if type(value) == "table" and value.opaqueAlpha then value = value.value end
    local public = not (issecretvalue and issecretvalue(value)) and type(value) == "number"
    -- Retain the requested value separately from the engine's quantized readback.
    -- Never compare protected values or skip a failed/native-changed write.
    if public and record.requested == value and record.last ~= nil and Alpha(region) == record.last then
        return true
    end
    guards[region] = true
    local ok, err = pcall(region.SetAlpha, region, value)
    record.writeError = not ok and not (issecretvalue and issecretvalue(err)) and tostring(err) or nil
    guards[region] = nil
    record.requested = ok and public and value or nil
    if ok then record.last = Alpha(region); return true end
end

-- Compact unit selection textures deliberately ignore parent alpha so that
-- range fading does not dim the selected unit. Keep that native behavior and
-- apply only the managed party root's opacity directly to those textures.
local function Sync(root)
    local state = states[root]
    if not state or not state.active or state.syncing then return end
    local opacity = RootAlpha(root)
    if opacity == nil then return end
    state.syncing = true
    local seen, visited, budget = {}, {}, 128
    local function Visit(frame, depth)
        if budget <= 0 or visited[frame] then return end
        visited[frame] = true
        budget = budget - 1
        local region = frame.selectionHighlight
        if region and Call(region, "IsIgnoringParentAlpha") == true then
            seen[region] = true
            local live = Alpha(region)
            local baseline = live
            if baseline == nil and not state.regions[region] then
                local ok, value = pcall(region.GetAlpha, region)
                if ok and issecretvalue and issecretvalue(value) then baseline = { opaqueAlpha = true, value = value } end
            end
            if baseline ~= nil or state.regions[region] then
                local record = state.regions[region]
                if not record then record = { base = baseline }; state.regions[region] = record end
                -- Pooled highlights may be repainted between root fades. Capture
                -- native writes immediately, including writes equal to our output.
                if not regionHooks[region] and not InCombatLockdown() and type(hooksecurefunc) == "function" then
                    regionHooks[region] = pcall(hooksecurefunc, region, "SetAlpha", function(_, value)
                        if guards[region] then return end
                        if issecretvalue and issecretvalue(value) then return end
                        if type(value) ~= "number" or value ~= value or value < 0 or value > 1 then return end
                        for owner, current in pairs(states) do
                            local held = current.active and current.regions[region]
                            if held then
                                held.base = value
                                local alpha = RootAlpha(owner)
                                if alpha then
                                    local ok, scaled = pcall(Scaled, alpha, value, owner)
                                    if ok then Write(region, held, scaled) end
                                end
                            end
                        end
                    end)
                end
                if live and record.last and math.abs(live - record.last) > 0.001 then record.base = live end
                if Write(region, record, Scaled(opacity, record.base, root)) then
                    record.protected = type(opacity) == "table" or type(record.base) == "table"
                end
            end
        end
        if budget > 0 and depth > 0 and frame.GetChildren then
            local children = { frame:GetChildren() }
            for _, child in ipairs(children) do
                if budget <= 0 then break end
                Visit(child, depth - 1)
            end
        end
    end
    -- PartyFrame -> CompactPartyFrame -> member/pet frames. Bound traversal
    -- and contain protected/secret reads without changing unit-frame scripts.
    local function Scan()
        -- Unit buttons can contain hundreds of aura/status children. Visit
        -- the ten known member/pet buttons first, before any generic subtree.
        for index = 1, 5 do
            for _, prefix in ipairs(memberPrefixes) do
                local member = _G[prefix .. index]
                local current, underRoot = member, false
                for _ = 1, 12 do
                    if not current then break end
                    if current == root then underRoot = true; break end
                    current = Call(current, "GetParent")
                end
                if underRoot then Visit(member, 0) end
            end
        end
        Visit(root, 4)
    end
    local complete, err = pcall(Scan)
    state.visited = 128 - budget
    state.lastError = not complete and not (issecretvalue and issecretvalue(err)) and tostring(err) or nil
    if complete and budget > 0 then
        for region, record in pairs(state.regions) do
            if not seen[region] then
                local live = Alpha(region)
                if record.protected or (live ~= nil and live == record.last) then Write(region, record, record.base) end
                state.regions[region] = nil
            end
        end
    end
    state.syncing = nil
end

function ns:PrintPartySelectionDiagnostics()
    local root = self.runtime and self.runtime.frameByID.party_frames
    local state = root and states[root]
    print("Frame Gambit border:", root and Call(root, "GetName") or "no managed party root",
        "active", state and state.active or false, "visited", state and state.visited or 0)
    if state and state.lastError then print("Scan error:", state.lastError) end
    for index = 1, 5 do
        local member = _G["CompactPartyFrameMember" .. index]
        local region = member and member.selectionHighlight
        local record = region and state and state.regions[region]
        print("Member", index, "tracked", record ~= nil, "ignores parent", region and Call(region, "IsIgnoringParentAlpha"),
            "base", record and (type(record.base) == "table" and "protected" or record.base), "border alpha", region and Alpha(region))
        if record and record.writeError then print("Write error:", record.writeError) end
    end
end

local function Hook(root)
    local state = states[root]
    if state and not state.hooked and not InCombatLockdown() and type(hooksecurefunc) == "function" then
        state.hooked = pcall(hooksecurefunc, root, "SetAlpha", function() Sync(root) end)
    end
end

target.acquire = function(root)
    local state = states[root]
    if not state then state = { regions = {} }; states[root] = state end
    state.active = true
    Hook(root)
    Sync(root)
    return true
end

target.release = function(root)
    local state = states[root]
    if not state then return end
    state.active = false
    for region, record in pairs(state.regions) do
        local live = Alpha(region)
        if live == nil and not record.protected then error("Party selection alpha restoration pending", 0) end
        if record.protected or (record.last and math.abs(live - record.last) <= 0.001) then
            if not Write(region, record, record.base) then error("Party selection alpha restoration pending", 0) end
        end
        state.regions[region] = nil
    end
end

target.resolve = function()
    local fallback
    for _, name in ipairs(target.names) do
        local root = _G[name]
        if root then
            fallback = fallback or root
            if Call(root, "IsShown") == true then fallback = root; break end
        end
    end
    if fallback then
        -- Also discovers party members created while the root is already faded,
        -- and reconciles writes when hooks cannot yet be installed in combat.
        Hook(fallback)
        Sync(fallback)
    end
    return fallback
end
