local ADDON, ns = ...

-- Ellesmere gives the player unit frame a separate, anonymous visibility
-- wrapper.  Its layout rectangle is full-screen, so it is unsuitable for
-- hover and preview, but its alpha is the authoritative visibility switch.
-- This proxy keeps interaction geometry on the actual unit frame and applies
-- Priority Fader's final opacity at the wrapper without modifying EUI data.

local proxy = {}
local active, visual, owner, portrait
local hostAlpha, portraitHostAlpha, appliedAlpha = 1, 1, 1
local guarded = false
local hooked = setmetatable({}, { __mode = "k" })
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

local function CaptureBase(frame)
    local live = Alpha(frame)
    if live == nil then return nil end
    local restore = pendingRestore[frame]
    if restore then
        if math.abs(live - restore.lastApplied) <= 0.001 then live = restore.base end
        pendingRestore[frame] = nil
    end
    return live
end

local function SetFrameAlpha(frame, value)
    if not frame or type(value) ~= "number" then return false end
    guarded = true
    local ok = pcall(function() frame:SetAlpha(value) end)
    guarded = false
    return ok
end

local function SetOwnerAlpha(value)
    return SetFrameAlpha(owner, value)
end

local function ProcessPending()
    if InCombatLockdown and InCombatLockdown() then return end
    for frame, record in pairs(pendingRestore) do
        local live = Alpha(frame)
        if live ~= nil and math.abs(live - record.lastApplied) > 0.001 then
            pendingRestore[frame] = nil
        elseif live ~= nil and SetFrameAlpha(frame, record.base) then
            pendingRestore[frame] = nil
        end
    end
end

local function RestoreFrame(frame, base)
    if not frame then return end
    local live = Alpha(frame)
    -- Do not overwrite a newer EUI value if it reclaimed the wrapper through
    -- a path on which a post-hook could not run.
    if live == nil then
        pendingRestore[frame] = { base = base, lastApplied = appliedAlpha }
    elseif math.abs(live - appliedAlpha) <= 0.001 and not SetFrameAlpha(frame, base) then
        pendingRestore[frame] = { base = base, lastApplied = appliedAlpha }
    end
end

local function RestoreOldOwner()
    RestoreFrame(owner, hostAlpha)
    RestoreFrame(portrait, portraitHostAlpha)
end

local function OwnerAlphaChanged(frame, value)
    if guarded or not active or (frame ~= owner and frame ~= portrait) then return end
    if type(value) == "number" and not Secret(value) and value == value and value >= 0 and value <= 1 then
        if frame == owner then hostAlpha = value else portraitHostAlpha = value end
    end
    SetFrameAlpha(frame, appliedAlpha)
end

local function Hook(frame)
    if not frame then return false end
    if hooked[frame] then return true end
    if type(hooksecurefunc) ~= "function" then return false end
    if pcall(hooksecurefunc, frame, "SetAlpha", OwnerAlphaChanged) then hooked[frame] = true end
    return hooked[frame] == true
end

local function ResolveFrames()
    ProcessPending()
    local nextVisual = _G.EllesmereUIUnitFrames_Player or _G.PlayerFrame
    if not nextVisual then return nil end
    local ok, wrapper = pcall(function() return nextVisual._visWrap end)
    local nextOwner = ok and wrapper or nil
    if not nextOwner then nextOwner = nextVisual end
    if nextOwner ~= owner then
        local live = CaptureBase(nextOwner)
        -- Do not commit a half-initialized owner. A secret/temporarily
        -- unreadable wrapper is retried on the next resolver pass.
        if live == nil then return nil end
        if active then RestoreOldOwner() end
        visual, owner, portrait = nextVisual, nextOwner, nil
        hostAlpha = live
        Hook(owner)
    else
        visual = nextVisual
    end
    local okPortrait, nextPortrait = pcall(function()
        return visual.Portrait and visual.Portrait.backdrop and visual.Portrait.backdrop._3d
    end)
    if not okPortrait then nextPortrait = nil end
    if nextPortrait ~= portrait then
        local nextPortraitAlpha = nextPortrait and CaptureBase(nextPortrait) or nil
        if portrait and active then RestoreFrame(portrait, portraitHostAlpha) end
        portrait = nextPortraitAlpha ~= nil and nextPortrait or nil
        if portrait then
            portraitHostAlpha = nextPortraitAlpha
            Hook(portrait)
        end
    end
    if active then
        local ownerLive = Alpha(owner)
        if ownerLive == nil then return nil end
        if math.abs(ownerLive - appliedAlpha) > 0.001 then
            if not hooked[owner] then hostAlpha = ownerLive end
            if not SetOwnerAlpha(appliedAlpha) then return nil end
        end
        if portrait then
            local portraitLive = Alpha(portrait)
            if portraitLive == nil then return nil end
            if math.abs(portraitLive - appliedAlpha) > 0.001 then
                if not hooked[portrait] then portraitHostAlpha = portraitLive end
                if not SetFrameAlpha(portrait, appliedAlpha) then return nil end
            end
        end
    end
    return visual, owner
end

function proxy:GetFrameGambitVisualFrame()
    ResolveFrames()
    return visual
end

function proxy:GetRect()
    local frame = ResolveFrames()
    if not frame then return nil end
    return frame:GetRect()
end

function proxy:GetEffectiveScale()
    local frame = ResolveFrames()
    if not frame then return nil end
    return frame:GetEffectiveScale()
end

function proxy:IsShown()
    local frame = ResolveFrames()
    return frame and frame:IsShown() or false
end

function proxy:GetAlpha()
    if not ResolveFrames() then return nil end
    return active and appliedAlpha or Alpha(owner)
end

function proxy:SetAlpha(value)
    if type(value) ~= "number" or Secret(value) or value ~= value or value < 0 or value > 1 then return end
    if not ResolveFrames() then return end
    local ownerOK = SetOwnerAlpha(value)
    local portraitOK = not portrait or SetFrameAlpha(portrait, value)
    if not ownerOK or not portraitOK then error("Frame Gambit could not apply the Ellesmere Player Frame visibility overlay.", 0) end
    appliedAlpha = value
end

local function Acquire(frame)
    if frame ~= proxy or not ResolveFrames() then return false end
    if not active then
        local live = CaptureBase(owner)
        if live == nil then return false end
        hostAlpha, appliedAlpha, active = live, live, true
        Hook(owner)
        if portrait then
            portraitHostAlpha = CaptureBase(portrait) or portraitHostAlpha
            Hook(portrait)
        end
    end
    return true
end

local function Release(frame)
    if frame ~= proxy or not active then return end
    RestoreOldOwner()
    active = false
end

local target = ns.TargetByID and ns.TargetByID.eui_player
if target then
    target.names = nil
    target.resolve = function()
        return ResolveFrames() and proxy or nil
    end
    target.acquire = Acquire
    target.release = Release
    target.skipManagedAlphaHook = true
    target.capability = "EUI visibility overlay"
    target.capabilityTone = "teal"
    target.capabilityNote = "Frame Gambit changes only opacity. Ellesmere keeps the Player frame's layout and behavior."
end
