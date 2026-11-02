local ADDON, ns = ...

-- Some Minimap descendants deliberately ignore parent alpha (notably pooled
-- pins and addon chrome), while EUI can keep its grouped addon-button panel as
-- a UIParent sibling. The normal Minimap target remains the real Minimap frame
-- for Cinematic ownership and hover behavior. This helper only composes its PF
-- opacity onto visuals that can escape that parent fade.

local owned = setmetatable({}, { __mode = "k" })
local hostAlpha = setmetatable({}, { __mode = "k" })
local appliedAlpha = setmetatable({}, { __mode = "k" })
local guarded = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local pending = setmetatable({}, { __mode = "k" })
local hoverExcluded = setmetatable({}, { __mode = "k" })
local multiplier = 1
local scan
local stackRoot
local stackTargetID
local nativeMarkerScale
-- The native marker compositor is separate from the Minimap alpha tree. Keep
-- its baseline unknown by default: some layouts use a non-default icon scale
-- and SetIconScale has no portable getter. Only an explicitly selected
-- experimental mode may opt into the documented 100% fallback.
local nativeMarkerHostScale
local nativeMarkerBaselineAssumed = false
local nativeMarkerMode
local nativeMarkerAlpha = 1
local nativeMarkerGuard = false
local nativeMarkerHooked = false
local nativeMarkerAuditAt = 0
local nativeMarkerRestorePending = false

ns.MINIMAP_NATIVE_MARKER_MODES = {
    keep = "Leave unchanged",
    hide_zero = "Hide at 30% or below",
    scale = "Scale with map",
}
ns.MINIMAP_NATIVE_MARKER_ORDER = { "keep", "hide_zero", "scale" }

local function IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function ValidAlpha(value)
    return type(value) == "number" and not IsSecret(value) and value == value
        and value >= 0 and value <= 1
end

-- Unlike alpha, an icon scale is not bounded to 1.  Keep the validation
-- intentionally permissive so a host's legitimate large scale survives our
-- temporary compositor override and its later restoration.
local function ValidScale(value)
    return type(value) == "number" and not IsSecret(value) and value == value
        and value >= 0 and value < math.huge
end

local function Method(object, name, ...)
    if not object then return nil end
    local okMethod, callback = pcall(function() return object[name] end)
    if not okMethod or type(callback) ~= "function" then return nil end
    local ok, value = pcall(callback, object, ...)
    if not ok or IsSecret(value) then return nil end
    return value
end

local function Alpha(frame)
    local value = Method(frame, "GetAlpha")
    return ValidAlpha(value) and value or nil
end

-- Blob fills and rings are native compositor channels, not child frames.
-- See Blizzard's MinimapFrameAPI: Quest/Task/Arch x Inside/Outside/Ring.
local blobStates = setmetatable({}, { __mode = "k" })
local blobMethods = {}
-- Native blob alpha uses byte opacity; ordinary frame alpha uses 0..1.
local function ValidBlobAlpha(value)
    return type(value) == "number" and not IsSecret(value) and value == value
        and value >= 0 and value <= 255
end
for _, kind in ipairs({ "Quest", "Task", "Arch" }) do
    for _, part in ipairs({ "Inside", "Outside", "Ring" }) do
        blobMethods[#blobMethods + 1] = kind .. "Blob" .. part .. "Alpha"
    end
end

local function WriteBlob(map, state, channel, value)
    state.guard = true
    local ok = pcall(function() map["Set" .. channel.name](map, value) end)
    state.guard = false
    if ok then
        channel.applied = value
        channel.dirty = state.active and true or nil
    end
    return ok
end

local function ObserveBlobs(map)
    if not map then return end
    local state = blobStates[map]
    if not state then
        state = { channels = {}, alpha = 1 }
        blobStates[map] = state
    end
    -- Runs every evaluator tick. Once every available setter is hooked there
    -- is nothing left to discover: the map's method set does not change.
    if state.observed then return state end
    local complete = true
    for _, name in ipairs(blobMethods) do
        local ok, setter = pcall(function() return map["Set" .. name] end)
        if ok and type(setter) == "function" then
            local channel = state.channels[name]
            if not channel then
                channel = { name = name }
                state.channels[name] = channel
            end
            if not channel.hooked and type(hooksecurefunc) == "function" then
                channel.hooked = pcall(hooksecurefunc, map, "Set" .. name, function(_, value)
                    if state.guard or not ValidBlobAlpha(value) then return end
                    channel.base, channel.applied = value, value
                    if state.active then
                        WriteBlob(map, state, channel, value * state.alpha)
                    else
                        -- A host write supersedes even a failed restoration.
                        channel.dirty = nil
                    end
                end)
            end
            if not channel.hooked then complete = false end
        elseif not ok then
            complete = false
        end
    end
    state.observed = complete or nil
    return state
end

local function RestoreBlobs(exceptMap)
    local complete = true
    for map, state in pairs(blobStates) do
        if map ~= exceptMap then
            state.active, state.alpha = false, 1
            for _, channel in pairs(state.channels) do
                if channel.dirty and not WriteBlob(map, state, channel, channel.base) then
                    complete = false
                end
            end
        end
    end
    return complete
end

local function UpdateBlobs(map, alpha)
    RestoreBlobs(map)
    local state = ObserveBlobs(map)
    if not state then return end
    state.active, state.alpha = true, alpha
    local now = GetTime()
    local audit = alpha < 1 and now - (state.auditAt or 0) >= 0.25
    for _, channel in pairs(state.channels) do
        if channel.base == nil then
            local value = Method(map, "Get" .. channel.name)
            -- Most clients expose setters only. Capture host writes from
            -- module load; otherwise assume full opacity. This cannot recover
            -- a skin's unobservable pre-load override (see validation notes).
            channel.base = ValidBlobAlpha(value) and value or 255
        end
        local wanted = math.floor(channel.base * alpha + 0.5)
        -- Leave untouched channels alone at full opacity. Audit faded native
        -- layers after rebuilds, and retry rejected writes on later updates.
        if audit or (channel.applied ~= nil and math.abs(channel.applied - wanted) > 0.001)
            or (channel.applied == nil and alpha < 1) then
            WriteBlob(map, state, channel, wanted)
        end
    end
    if audit then state.auditAt = now end
end

local function BlobsPending()
    for _, state in pairs(blobStates) do
        if not state.active then
            for _, channel in pairs(state.channels) do
                if channel.dirty then return true end
            end
        end
    end
    return false
end

-- Observe skin preferences even before a minimap gambit is enabled.
ObserveBlobs(_G.Minimap)

-- Selected/native quest areas can escape the nine alpha channels. At exact
-- zero, suspend the native minimap renderer itself. Keep the cluster shown
-- and retain the map's geometry for mouseover reveal. No reparenting or CVars.
local rendererStates = setmetatable({}, { __mode = "k" })

local function SetRendererShown(map, state, shown)
    -- Never take a Show/Hide lease that could become impossible to restore
    -- during combat. Alpha-only handling remains the fallback for protected
    -- minimaps and clients without readable protection status.
    if Method(map, "IsProtected") ~= false then return false end
    state.guard = true
    local ok = pcall(function()
        if shown then map:Show() else map:Hide() end
    end)
    state.guard = false
    return ok and Method(map, "IsShown") == shown
end

local function RestoreRenderers(exceptMap)
    local complete = true
    for map, state in pairs(rendererStates) do
        if map ~= exceptMap then
            state.active = false
            if state.hidden then
                if Method(map, "IsShown") == state.hostShown
                    or SetRendererShown(map, state, state.hostShown) then
                    state.hidden = nil
                else
                    complete = false
                end
            end
        end
    end
    return complete
end

local function UpdateRenderer(map, alpha)
    if alpha > 0 then RestoreRenderers(); return end
    RestoreRenderers(map)
    if Method(map, "IsProtected") ~= false or type(hooksecurefunc) ~= "function" then return end
    local state = rendererStates[map]
    if not state then
        state = {}
        rendererStates[map] = state
    end
    for _, method in ipairs({ "Show", "Hide" }) do
        if not state[method] then
            local hostShown = method == "Show"
            state[method] = pcall(hooksecurefunc, map, method, function()
                if state.guard or not (state.active or state.hidden) then return end
                -- Respect a later native/skin visibility decision on release.
                state.hostShown = hostShown
                if state.active and hostShown then
                    if SetRendererShown(map, state, false) then state.hidden = true end
                elseif not state.active then
                    state.hidden = nil
                end
            end)
        end
    end
    if not state.Show or not state.Hide then return end
    if not state.active and not state.hidden then
        local shown = Method(map, "IsShown")
        if type(shown) ~= "boolean" then return end
        state.hostShown = shown
    end
    state.active = true
    if state.hostShown and Method(map, "IsShown") ~= false
        and SetRendererShown(map, state, false) then state.hidden = true end
end

local function RendererPending()
    for _, state in pairs(rendererStates) do
        if state.hidden and not state.active then return true end
    end
    return false
end

function ns:IsMinimapRendererSuppressed(frame)
    local state = frame and rendererStates[frame]
    return state and state.hidden == true and state.hostShown == true or false
end

local function SetAlpha(frame, value)
    if not ValidAlpha(value) then return false end
    guarded[frame] = true
    local ok = pcall(function() frame:SetAlpha(value) end)
    guarded[frame] = nil
    if ok then appliedAlpha[frame] = Alpha(frame) or value end
    return ok
end

local function Apply(frame)
    local base = hostAlpha[frame]
    return owned[frame] and ValidAlpha(base) and SetAlpha(frame, base * multiplier) or false
end

local function HostAlphaChanged(frame, value)
    if guarded[frame] or not owned[frame] then return end
    if not ValidAlpha(value) then
        Apply(frame)
        return
    end
    hostAlpha[frame] = value
    Apply(frame)
end

local function Hook(frame)
    if hooked[frame] or type(hooksecurefunc) ~= "function" then return end
    if pcall(hooksecurefunc, frame, "SetAlpha", function(_, value) HostAlphaChanged(frame, value) end) then
        hooked[frame] = true
    end
end

local function Claim(frame)
    if not frame or owned[frame] then return end
    local base = Alpha(frame)
    if base == nil then return end
    local restore = pending[frame]
    if restore then
        if math.abs(base - restore.lastApplied) <= 0.001 then base = restore.base end
        pending[frame] = nil
    end
    owned[frame] = true
    hostAlpha[frame] = base
    Hook(frame)
    Apply(frame)
end

local function Release(frame)
    if not owned[frame] then return end
    local base, last = hostAlpha[frame], appliedAlpha[frame]
    local live = Alpha(frame)
    if base ~= nil and last ~= nil and live ~= nil and math.abs(live - last) <= 0.001 then
        if not SetAlpha(frame, base) then pending[frame] = { base = base, lastApplied = last } end
    elseif live == nil and base ~= nil and last ~= nil then
        pending[frame] = { base = base, lastApplied = last }
    end
    owned[frame] = nil
    hostAlpha[frame] = nil
    appliedAlpha[frame] = nil
end

local function IsDescendant(frame, ancestor)
    local current, seen, depth = frame, {}, 0
    while current and depth < 20 and not seen[current] do
        if current == ancestor then return true end
        seen[current] = true
        current = Method(current, "GetParent")
        depth = depth + 1
    end
    return false
end

local function Children(frame)
    if not frame then return {} end
    local okMethod, callback = pcall(function() return frame.GetChildren end)
    if not okMethod or type(callback) ~= "function" then return {} end
    local values = { pcall(callback, frame) }
    if not table.remove(values, 1) then return {} end
    return values
end

local function Regions(frame)
    if not frame then return {} end
    local okMethod, callback = pcall(function() return frame.GetRegions end)
    if not okMethod or type(callback) ~= "function" then return {} end
    local values = { pcall(callback, frame) }
    if not table.remove(values, 1) then return {} end
    return values
end

local function VisualChildren(frame)
    local values = Children(frame)
    for _, region in ipairs(Regions(frame)) do values[#values + 1] = region end
    return values
end

local function AddEUIFlyoutPanels(result, minimap)
    -- EUI's grouped addon buttons can live in one anonymous UIParent flyout
    -- rather than beneath Minimap. Claim that small shared panel, not each
    -- button and not an arbitrary addon's original UI root.
    local parents = {}
    for _, button in pairs(type(_G._EBS_CachedAddonButtons) == "table" and _G._EBS_CachedAddonButtons or {}) do
        local parent = Method(button, "GetParent")
        if parent and parent ~= UIParent and not IsDescendant(parent, minimap)
            and Method(parent, "GetParent") == UIParent and Method(parent, "GetName") == nil
            and Method(parent, "GetFrameStrata") == "DIALOG" then
            parents[parent] = (parents[parent] or 0) + 1
        end
    end
    for parent, count in pairs(parents) do
        -- Requiring a shared anonymous direct UIParent parent prevents a stale
        -- cached button from making PF claim an unrelated addon container.
        if count >= 1 then
            result[parent] = true
            -- The panel itself inherits PF's multiplier, but some third-party
            -- buttons deliberately ignore parent alpha. Lease only those
            -- escapees (and nested escapees), avoiding a double multiplier on
            -- ordinary children that already inherit the panel correctly.
            local queue, seen, index = VisualChildren(parent), {}, 1
            while index <= #queue and index <= 256 do
                local child = queue[index]
                index = index + 1
                if child and not seen[child] then
                    seen[child] = true
                    if Method(child, "IsIgnoringParentAlpha") == true then result[child] = true end
                    for _, nested in ipairs(VisualChildren(child)) do
                        if not seen[nested] then queue[#queue + 1] = nested end
                    end
                end
            end
        end
    end
end

local function HasClaimedAncestor(result, frame)
    local current, seen, depth = Method(frame, "GetParent"), {}, 0
    while current and depth < 20 and not seen[current] do
        if result[current] then return true end
        seen[current] = true
        current = Method(current, "GetParent")
        depth = depth + 1
    end
    return false
end

local function AddSemanticFrame(result, frame, minimap)
    if not frame or frame == minimap then return end
    local ignoresParent = Method(frame, "IsIgnoringParentAlpha") == true
    -- Ordinary Minimap children already inherit its opacity. Only claim the
    -- unusual children that explicitly opt out of parent alpha.
    if IsDescendant(frame, minimap) then
        if ignoresParent then result[frame] = true end
        return
    end
    -- If a semantic container is already leased, its normal descendants must
    -- not receive the multiplier twice. Descendants that ignore parent alpha
    -- remain separate leases by design.
    if HasClaimedAncestor(result, frame) then
        if ignoresParent then result[frame] = true end
        return
    end
    result[frame] = true
end

local function AddAlphaEscapingDescendants(result, root, minimap)
    -- Super Tracking owns a small, UIParent-level directional presentation.
    -- Its individual native regions can opt out of their root's alpha, so a
    -- root-only lease leaves the clamped quest-direction arc visible when the
    -- Minimap rests at zero. Walk only this known, narrow tree and claim those
    -- explicit alpha escapees; normal children still inherit the root once.
    local queue, seen, index = VisualChildren(root), {}, 1
    while index <= #queue and index <= 96 do
        local child = queue[index]
        index = index + 1
        if child and not seen[child] then
            seen[child] = true
            if Method(child, "IsIgnoringParentAlpha") == true then
                AddSemanticFrame(result, child, minimap)
            end
            for _, nested in ipairs(VisualChildren(child)) do
                if not seen[nested] then queue[#queue + 1] = nested end
            end
        end
    end
end

local function AddSemanticMinimapFrames(result, minimap)
    AddEUIFlyoutPanels(result, minimap)

    -- Retail's visible minimap is not one alpha tree. Mail, tracking and other
    -- indicators are commonly siblings of Minimap under MinimapCluster.
    local cluster = _G.MinimapCluster
    local indicator = cluster and cluster.IndicatorFrame
    AddSemanticFrame(result, indicator, minimap)
    AddSemanticFrame(result, cluster and cluster.Tracking, minimap)
    AddSemanticFrame(result, cluster and cluster.InstanceDifficulty, minimap)
    AddSemanticFrame(result, cluster and cluster.DielFrame, minimap)

    -- Stable Blizzard minimap surfaces which may move between Minimap,
    -- MinimapCluster and UIParent across layouts/skins.
    local known = {
        _G.AddonCompartmentFrame,
        _G.ExpansionLandingPageMinimapButton,
        _G.QueueStatusButton,
        _G.GameTimeFrame,
        _G.MiniMapTracking,
        _G.MiniMapMailFrame,
    }
    -- Optional globals leave holes on Forever; ipairs would stop at the first.
    for _, frame in pairs(known) do AddSemanticFrame(result, frame, minimap) end

    -- The navigation/super-tracking presentation is a UIParent root rather
    -- than a Minimap child. It belongs to the same visual stack but must not
    -- enlarge the minimap's mouseover hit area if Blizzard gives it a broad
    -- layout rectangle.
    local superTracked = _G.SuperTrackedFrame
    AddSemanticFrame(result, superTracked, minimap)
    if superTracked then
        hoverExcluded[superTracked] = true
        AddAlphaEscapingDescendants(result, superTracked, minimap)
    end

    -- LibDBIcon is the canonical registry for third-party minimap buttons.
    -- Querying its object table is both cheaper and more accurate than guessing
    -- ownership from names or screen position after another addon reparents it.
    local lib
    if type(_G.LibStub) == "table" or type(_G.LibStub) == "function" then
        local ok, value = pcall(_G.LibStub, "LibDBIcon-1.0", true)
        if ok and type(value) == "table" then lib = value end
    end
    for _, button in pairs(lib and type(lib.objects) == "table" and lib.objects or {}) do
        AddSemanticFrame(result, button, minimap)
    end

    -- EUI publishes the buttons it has collected even while their current
    -- parent changes between Minimap and its anonymous flyout.
    for _, button in pairs(type(_G._EBS_CachedAddonButtons) == "table" and _G._EBS_CachedAddonButtons or {}) do
        AddSemanticFrame(result, button, minimap)
    end
end

local function BeginScan(minimap)
    -- Minimap POIs are frequently Texture/Region objects rather than child
    -- Frames. Some deliberately ignore their pin or Minimap parent's alpha.
    -- Regions still expose GetAlpha/SetAlpha and can safely participate in the
    -- same composed visibility lease.
    scan = { minimap = minimap, queue = VisualChildren(minimap), index = 1, seen = {}, found = {} }
    AddSemanticMinimapFrames(scan.found, minimap)
end

local function ContinueScan(minimap)
    if not scan or scan.minimap ~= minimap then BeginScan(minimap) end
    local processed = 0
    local started = type(debugprofilestop) == "function" and debugprofilestop() or nil
    while scan.index <= #scan.queue and processed < 48
        and (processed == 0 or not started or debugprofilestop() - started < 0.60) do
        local child = scan.queue[scan.index]
        scan.index = scan.index + 1
        processed = processed + 1
        if child and not scan.seen[child] then
            scan.seen[child] = true
            if Method(child, "IsIgnoringParentAlpha") == true then scan.found[child] = true end
            for _, nested in ipairs(VisualChildren(child)) do
                if not scan.seen[nested] then scan.queue[#scan.queue + 1] = nested end
            end
        end
    end
    if scan.index <= #scan.queue then return nil end
    AddSemanticMinimapFrames(scan.found, minimap)
    local result = scan.found
    scan = nil
    return result
end

local function ProcessPending()
    if InCombatLockdown() then return end
    for frame, record in pairs(pending) do
        local live = Alpha(frame)
        if live ~= nil and math.abs(live - record.lastApplied) > 0.001 then
            pending[frame] = nil
        elseif live ~= nil and SetAlpha(frame, record.base) then
            pending[frame] = nil
            appliedAlpha[frame] = nil
        end
    end
end

local function ReadNativeMarkerScale(minimap)
    -- GetIconScale is available on current Retail builds, but it is deliberately
    -- optional here: UI skins and older client variants do not all publish it.
    -- A future host SetIconScale call is the other authoritative source.
    local value = Method(minimap, "GetIconScale")
    return ValidScale(value) and value or nil
end

local function CaptureNativeMarkerHostScale(minimap, allowAssumedDefault)
    if nativeMarkerHostScale ~= nil then return nativeMarkerHostScale end
    local value = ReadNativeMarkerScale(minimap)
    if value ~= nil then
        nativeMarkerHostScale = value
        nativeMarkerBaselineAssumed = false
    elseif allowAssumedDefault then
        -- Some Retail builds expose only SetIconScale. Selecting an
        -- experimental marker mode is the user's explicit opt-in to use the
        -- native 100% scale as the temporary restoration baseline. The
        -- default "Leave unchanged" mode never reaches this path.
        nativeMarkerHostScale = 1
        nativeMarkerBaselineAssumed = true
    end
    return nativeMarkerHostScale
end

local function HasNativeMarkerSetter(minimap)
    if not minimap then return false end
    local ok, setter = pcall(function() return minimap.SetIconScale end)
    return ok and type(setter) == "function"
end

local function SetNativeMarkerScale(minimap, value)
    if not minimap or not ValidScale(value) then return false end
    local okMethod, setter = pcall(function() return minimap.SetIconScale end)
    if not okMethod or type(setter) ~= "function" then return false end
    nativeMarkerGuard = true
    local ok = pcall(setter, minimap, value)
    nativeMarkerGuard = false
    return ok
end

local function HookNativeMarkers(minimap)
    if nativeMarkerHooked or not minimap or type(hooksecurefunc) ~= "function" then return end
    local ok = pcall(hooksecurefunc, minimap, "SetIconScale", function(_, value)
        if nativeMarkerGuard or not ValidScale(value) then return end
        nativeMarkerHostScale = value
        nativeMarkerBaselineAssumed = false
        nativeMarkerScale = value
        nativeMarkerRestorePending = false
        local wanted
        if nativeMarkerMode == "scale" then
            wanted = value * nativeMarkerAlpha
        elseif nativeMarkerMode == "hide_zero" then
            wanted = nativeMarkerAlpha <= 0.001 and 0 or value
        end
        if wanted ~= nil and math.abs(value - wanted) > 0.001 then
            if SetNativeMarkerScale(minimap, wanted) then
                nativeMarkerScale = wanted
                nativeMarkerAuditAt = GetTime()
            end
        end
    end)
    if ok then nativeMarkerHooked = true end
end

local function RestoreNativeMarkers(minimap)
    -- If an override was never applied there is nothing to put back.  Clear
    -- immediately rather than attempting to "restore" an assumed scale.
    if nativeMarkerScale == nil then
        nativeMarkerMode = nil
        nativeMarkerAlpha = 1
        nativeMarkerRestorePending = false
        nativeMarkerAuditAt = 0
        return true
    end

    -- Stop composing immediately, even if the host setter is temporarily
    -- unavailable.  A later host SetIconScale call must become the new host
    -- baseline instead of being transformed by the old fade mode.
    nativeMarkerMode = nil
    nativeMarkerAlpha = 1
    local restore = CaptureNativeMarkerHostScale(minimap)
    if restore == nil then
        -- We never overwrite an unknown host scale.  Keep retrying in case the
        -- client later exposes a getter or the host calls SetIconScale.
        nativeMarkerRestorePending = true
        return false
    end

    if math.abs(nativeMarkerScale - restore) > 0.001 and not SetNativeMarkerScale(minimap, restore) then
        -- Failed setters are transient during client rebuilds/lockdown.  Do
        -- not lose the original host scale; the next update will retry.
        nativeMarkerRestorePending = true
        return false
    end

    nativeMarkerScale = nil
    -- Keep the last authoritative host baseline. Some Retail builds expose
    -- SetIconScale without a matching getter, so forgetting a value announced
    -- by the host would make the safe experimental modes unavailable again on
    -- the very next keep-mode update. A later host setter refreshes this value
    -- through HookNativeMarkers.
    nativeMarkerRestorePending = false
    nativeMarkerAuditAt = 0
    return true
end

local function UpdateNativeMarkers(minimap, alpha, mode)
    if mode ~= "hide_zero" and mode ~= "scale" then
        RestoreNativeMarkers(minimap)
        return
    end
    HookNativeMarkers(minimap)
    local hostScale = CaptureNativeMarkerHostScale(minimap, true)
    if hostScale == nil then
        -- The setter itself is unavailable or rejected. Keep the requested
        -- mode recorded, but do not claim that a visual change was applied.
        nativeMarkerMode = mode
        nativeMarkerAlpha = alpha
        return
    end
    nativeMarkerMode = mode
    nativeMarkerAlpha = alpha
    nativeMarkerRestorePending = false
    local wanted = mode == "scale" and (hostScale * alpha)
        or (alpha <= 0.001 and 0 or hostScale)
    local now = GetTime()
    -- Blizzard's native blip compositor can rebuild without making a Lua
    -- SetIconScale call. Reassert at a low rate so a rebuilt quest/service-pin
    -- layer cannot remain visible while the Minimap is fully faded.
    local auditDue = wanted <= 0.001 and now - nativeMarkerAuditAt >= 0.25
    if auditDue or nativeMarkerScale == nil or math.abs(nativeMarkerScale - wanted) > 0.001 then
        if SetNativeMarkerScale(minimap, wanted) then
            nativeMarkerScale = wanted
            nativeMarkerAuditAt = now
        end
    end
end

function ns:GetMinimapNativeMarkerAvailability(mode)
    local minimap = _G.Minimap
    if not minimap then return false, "The native Minimap is not available." end
    if not HasNativeMarkerSetter(minimap) then
        return false, "This WoW build does not expose native marker scaling."
    end
    -- Install the read-only post-hook even while leaving markers unchanged. If
    -- Blizzard or the owning UI later announces a scale, experimental modes
    -- can become available without guessing or requiring a reload.
    HookNativeMarkers(minimap)
    if CaptureNativeMarkerHostScale(minimap) ~= nil then
        if nativeMarkerBaselineAssumed then
            return true, "This WoW build cannot read the current native marker scale. Because an experimental marker mode is selected, Frame Gambit is using 100% as its restoration baseline until Blizzard or the owning UI announces another value."
        end
        return true
    end
    local note = "This WoW build cannot read the current native marker scale. Choosing an experimental marker mode will explicitly use 100% as its restoration baseline; Leave unchanged never writes it."
    if mode == "hide_zero" or mode == "scale" then
        CaptureNativeMarkerHostScale(minimap, true)
    end
    return true, note
end

function ns:ReleaseMinimapStack()
    local frames = {}
    for frame in pairs(owned) do frames[#frames + 1] = frame end
    for _, frame in ipairs(frames) do Release(frame) end
    multiplier, scan, stackRoot, stackTargetID = 1, nil, nil, nil
    RestoreNativeMarkers(_G.Minimap)
    local blobsRestored = RestoreBlobs()
    local rendererRestored = RestoreRenderers()
    ProcessPending()
    return next(pending) == nil and not nativeMarkerRestorePending and blobsRestored and rendererRestored
end

local function ActiveTargetForFrame(self, frame)
    if not frame then return end
    local runtime = self.runtime
    local id = runtime and runtime.managedIDByFrame and runtime.managedIDByFrame[frame]
    if not id and frame == _G.Minimap then id = "minimap" end
    local active = id and runtime and runtime.active and runtime.active[id]
    local settings = id and self.GetTargetSettings and self:GetTargetSettings(id)
    if active and ValidAlpha(active.alpha) and runtime.frameByID
        and runtime.frameByID[id] == frame and settings and settings.enabled ~= false then
        return id, active.alpha, settings
    end
end

function ns:HasMinimapStackPendingWork()
    return nativeMarkerRestorePending == true or scan ~= nil or next(pending) ~= nil or BlobsPending() or RendererPending()
end

function ns:UpdateMinimapStack(rescan)
    ProcessPending()
    local minimap = _G.Minimap
    local mapID, mapAlpha, mapSettings = ActiveTargetForFrame(self, minimap)
    local clusterID, clusterAlpha, clusterSettings = ActiveTargetForFrame(self, _G.MinimapCluster)
    local id, nextMultiplier, settings = mapID, mapAlpha, mapSettings
    local root = minimap
    if clusterID and IsDescendant(minimap, _G.MinimapCluster) then
        id, nextMultiplier, settings = clusterID, clusterAlpha, clusterSettings
        root = _G.MinimapCluster
    end
    if root ~= stackRoot or id ~= stackTargetID or not id then
        if next(owned) then
            local frames = {}
            for frame in pairs(owned) do frames[#frames + 1] = frame end
            for _, frame in ipairs(frames) do Release(frame) end
        end
        multiplier = 1
        scan = nil
        stackRoot, stackTargetID = root, id
        rescan = true
    end
    if not minimap or not id then
        RestoreNativeMarkers(minimap or _G.Minimap)
        RestoreBlobs()
        RestoreRenderers()
        ObserveBlobs(minimap)
        return
    end
    -- Custom MinimapCluster targets predate the marker control. Match the
    -- requested Forever default without rewriting saved profiles.
    local markerMode = settings.nativeMarkerMode or "hide_zero"
    local markerAlpha = nextMultiplier
    if clusterID and mapID and root ~= minimap then markerAlpha = markerAlpha * mapAlpha end
    -- Hide native icons/controllable blobs early without suppressing terrain.
    -- The renderer fallback below must use the real opacity, not this cutoff.
    local hideMarkers = markerAlpha <= 0.30
    UpdateNativeMarkers(minimap, hideMarkers and 0 or markerAlpha, hideMarkers and "hide_zero" or markerMode)
    UpdateBlobs(minimap, hideMarkers and 0 or markerAlpha)
    UpdateRenderer(minimap, markerAlpha)
    local changed = math.abs(multiplier - nextMultiplier) > 0.001
    multiplier = nextMultiplier
    if rescan and not scan then BeginScan(root) end
    if rescan then
        -- The EUI flyout is a tiny, exact adapter and should become a
        -- Cinematic exemption immediately; descendant pin discovery can keep
        -- progressing incrementally without delaying the visible button stack.
        local semantic = {}
        AddSemanticMinimapFrames(semantic, root)
        for frame in pairs(semantic) do
            local otherID = self.runtime.managedIDByFrame and self.runtime.managedIDByFrame[frame]
            if not otherID then Claim(frame) end
        end
    end
    if scan then
        local discovered = ContinueScan(root)
        if discovered then
        local current = {}
        for frame in pairs(discovered) do
            local otherID = self.runtime.managedIDByFrame and self.runtime.managedIDByFrame[frame]
            if not otherID then
                current[frame] = true
                Claim(frame)
            end
        end
        local retired = {}
        for frame in pairs(owned) do if not current[frame] then retired[#retired + 1] = frame end end
        for _, frame in ipairs(retired) do Release(frame) end
        end
    end
    -- Target ownership can change without Minimap topology changing. Never
    -- compose the stack multiplier onto a frame now controlled explicitly by
    -- another Priority Fader target.
    -- Runs every evaluator tick; conflicts are rare, so allocate only when one exists.
    local conflicted
    for frame in pairs(owned) do
        local otherID = self.runtime.managedIDByFrame and self.runtime.managedIDByFrame[frame]
        if otherID then
            conflicted = conflicted or {}
            conflicted[#conflicted + 1] = frame
        end
    end
    if conflicted then
        for _, frame in ipairs(conflicted) do Release(frame) end
    end
    for frame in pairs(owned) do
        local last = appliedAlpha[frame]
        if not hooked[frame] then
            local live = Alpha(frame)
            if live ~= nil and last ~= nil and math.abs(live - last) > 0.001 then hostAlpha[frame] = live end
        end
        local wanted = hostAlpha[frame] and hostAlpha[frame] * multiplier
        if wanted and (changed or last == nil or math.abs(wanted - last) > 0.001) then Apply(frame) end
    end
end

function ns:IsMinimapStackFrame(frame)
    return frame and owned[frame] == true or false
end

function ns:MinimapStackContainsCursor(x, y)
    for frame in pairs(owned) do
        if not hoverExcluded[frame] and self:FrameContainsCursor(frame, x, y) then return true end
    end
    return false
end

-- /fg minimapdebug: print the state that decides how the minimap looks.
function ns:PrintMinimapDiagnostics()
    -- The lines are saved to FrameGambitDB.minimapDebug (kept: the last four
    -- runs), so they can be read from the saved-variables file after a /reload.
    local lines = {}
    local function print(text) lines[#lines + 1] = text end
    local function Num(value)
        if value == nil then return "nil" end
        if IsSecret(value) then return "secret" end
        if type(value) == "number" then return string.format("%.3f", value) end
        return tostring(value)
    end
    local function Frame(label, frame)
        if not frame then print("  " .. label .. ": missing"); return end
        print(string.format("  %s: shown=%s alpha=%s effectiveAlpha=%s scale=%s effScale=%s",
            label, Num(Method(frame, "IsShown")), Num(Method(frame, "GetAlpha")), Num(Method(frame, "GetEffectiveAlpha")),
            Num(Method(frame, "GetScale")), Num(Method(frame, "GetEffectiveScale"))))
    end
    print("Frame Gambit minimap state (" .. (self.VERSION or "?") .. "):")
    Frame("Minimap", _G.Minimap)
    Frame("MinimapCluster", _G.MinimapCluster)
    Frame("MinimapContainer", _G.MinimapContainer)
    local minimap = _G.Minimap
    local mapID, mapAlpha = ActiveTargetForFrame(self, minimap)
    local clusterID, clusterAlpha = ActiveTargetForFrame(self, _G.MinimapCluster)
    print(string.format("  stack: root=%s target=%s multiplier=%s | Minimap rule=%s(%s) Cluster rule=%s(%s)",
        tostring(stackRoot and (Method(stackRoot, "GetName") or "?")), tostring(stackTargetID), Num(multiplier),
        tostring(mapID), Num(mapAlpha), tostring(clusterID), Num(clusterAlpha)))
    local ownedCount = 0
    for _ in pairs(owned) do ownedCount = ownedCount + 1 end
    print("  frames claimed by the stack: " .. ownedCount)
    for map, state in pairs(rendererStates) do
        print(string.format("  renderer gate: active=%s hidden=%s hostShown=%s mapShown=%s",
            tostring(state.active), tostring(state.hidden), tostring(state.hostShown), Num(Method(map, "IsShown"))))
    end
    for map, state in pairs(blobStates) do
        print(string.format("  blobs: active=%s alpha=%s", tostring(state.active), Num(state.alpha)))
        local names = {}
        for name in pairs(state.channels) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do
            local channel = state.channels[name]
            print(string.format("    %-22s base=%s applied=%s dirty=%s", name, Num(channel.base), Num(channel.applied), tostring(channel.dirty)))
        end
    end
    print("  zoom=" .. Num(Method(minimap, "GetZoom")))
    if type(FrameGambitDB) == "table" then
        local runs = type(FrameGambitDB.minimapDebug) == "table" and FrameGambitDB.minimapDebug or {}
        FrameGambitDB.minimapDebug = runs
        runs[#runs + 1] = { at = type(date) == "function" and date("%H:%M:%S") or tostring(GetTime()), lines = lines }
        while #runs > 4 do table.remove(runs, 1) end
    end
    _G.print("Frame Gambit: minimap state saved (run " .. tostring(type(FrameGambitDB) == "table" and #FrameGambitDB.minimapDebug or 0)
        .. "). Zoom once and run it again, then /reload so the game writes it to disk.")
end
