local ADDON, ns = ...

-- Ellesmere Chat keeps Blizzard ChatFrame1 as its secure data plane, but its
-- visible messages, panel, tabs and chrome are separate UIParent surfaces.
-- The ordinary ChatFrame1 adapter therefore fades the wrong object.  This
-- proxy delegates final visibility to EUI's exported top-level chat authority
-- while leaving every EUI layout, style, message and interaction setting
-- untouched.  When Frame Gambit releases the target, EUI immediately
-- re-derives its own visibility from its current configuration.
--
-- EUI intentionally owns the physical animation in SetChatAlpha.  Its public
-- API accepts a target opacity only; it does not accept a caller-provided
-- duration or an immediate/per-step mode.  Do not reach into EUI's private
-- animation locals or write the individual surfaces to imitate one: that
-- would fight its visibility and idle-fade system.  This adapter therefore
-- explicitly advertises host-owned timing for Core/Options to present
-- honestly, while Frame Gambit still owns condition priority and fade-out
-- delay.

local state = { active = false, applied = 1, hooked = false, guard = false }
local proxy = {}
local fallbackRelease = ns.TargetByID and ns.TargetByID.chat and ns.TargetByID.chat.release

local function Secret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function Module()
    local eui = _G.EllesmereUI
    local module = eui and type(eui._ModuleNS) == "table" and eui._ModuleNS.EllesmereUIChat
    local chat = module and module.ECHAT
    if type(chat) == "table" and type(chat.SetChatAlpha) == "function" then return module, chat end
end

local function Rect(frame)
    if not frame then return nil end
    local ok, left, bottom, width, height = pcall(function() return frame:GetRect() end)
    if ok and type(left) == "number" and type(bottom) == "number" and type(width) == "number" and type(height) == "number"
        and not Secret(left) and not Secret(bottom) and not Secret(width) and not Secret(height)
        and left == left and bottom == bottom and width == width and height == height and width > 0 and height > 0 then
        return left, bottom, width, height
    end
end

local function VisualFrame()
    local module = Module()
    local cf = _G.ChatFrame1
    local cfd = _G.EllesmereUI and _G.EllesmereUI._chatCFD
    if module and cf and type(cfd) == "function" then
        local ok, data = pcall(cfd, cf)
        if ok and type(data) == "table" and data.bg then return data.bg end
    end
    return cf
end

local function VisualAlpha()
    local frame = VisualFrame()
    if not frame then return nil end
    local ok, alpha = pcall(function() return frame:GetAlpha() end)
    if ok and type(alpha) == "number" and not Secret(alpha) and alpha == alpha and alpha >= 0 and alpha <= 1 then
        return alpha
    end
end

local function Reassert()
    if not state.active or state.guard then return end
    local _, chat = Module()
    if not chat then return end
    state.guard = true
    pcall(chat.SetChatAlpha, state.applied)
    state.guard = false
end

local function HookAuthority()
    local _, chat = Module()
    if state.hooked == chat and chat then return true end
    if not chat or type(hooksecurefunc) ~= "function" then return false end
    local okAlpha = pcall(hooksecurefunc, chat, "SetChatAlpha", function()
        if state.active and not state.guard then Reassert() end
    end)
    local okIdle = true
    if type(chat.SetIdleFadeAlpha) == "function" then
        okIdle = pcall(hooksecurefunc, chat, "SetIdleFadeAlpha", function()
            if state.active and not state.guard then Reassert() end
        end)
    end
    state.hooked = okAlpha and okIdle and chat or nil
    return state.hooked
end

function proxy:GetFrameGambitVisualFrame()
    return VisualFrame()
end

function proxy:GetFrameGambitCinematicFrames()
    -- Ellesmere's supported alpha authority owns a bounded composite rather
    -- than one parented tree. Publish every current surface so Cinematic's
    -- generic blackout exempts them instead of undoing ECHAT:SetChatAlpha.
    local module = Module()
    local cfd = _G.EllesmereUI and _G.EllesmereUI._chatCFD
    if not module or type(cfd) ~= "function" then return {} end
    local frames, seen = {}, {}
    local function Add(frame)
        if frame and not seen[frame] then seen[frame] = true; frames[#frames + 1] = frame end
    end
    local names, known = {}, {}
    for _, name in pairs(CHAT_FRAMES or {}) do
        if type(name) == "string" and not known[name] then names[#names + 1] = name; known[name] = true end
    end
    for index = 1, NUM_CHAT_WINDOWS or 10 do
        local name = "ChatFrame" .. index
        if not known[name] then names[#names + 1] = name end
    end
    for _, name in ipairs(names) do
        local chatFrame = _G[name]
        if chatFrame then
            Add(chatFrame)
            Add(_G[name .. "EditBox"])
            local ok, data = pcall(cfd, chatFrame)
            if ok and type(data) == "table" then
                Add(data.bg)
                Add(data.resizeGrip)
                Add(data.sidebar)
                Add(data.scrollBtn)
            end
        end
    end
    Add(module._chatTabStrip)
    Add(module._chatBgExt)
    Add(module._chatPanelBorder)
    Add(module._sidebarSeparateBorder)
    Add(module._chatHoverOverlay)
    return frames
end

function proxy:GetRect()
    return Rect(VisualFrame())
end

function proxy:GetEffectiveScale()
    local frame = VisualFrame()
    return frame and frame:GetEffectiveScale()
end

function proxy:IsShown()
    local frame = VisualFrame()
    if not frame then return false end
    -- EUI intentionally Hide()s its own stack when its top-level alpha reaches
    -- zero. That is an output of this proxy, not an independent host hide; if
    -- reported back to Core as host-hidden, Mouseover could never reveal chat
    -- again. Availability of the semantic stack is the proxy's shown state.
    return Module() ~= nil
end

function proxy:GetAlpha()
    -- Before acquisition, expose the actual surface so Core captures an honest
    -- starting point. While controlled, expose the last requested authority:
    -- EUI may still be animating toward it, and that physical travel must not
    -- be mistaken for a new host-owned alpha on every evaluator tick.
    return state.active and state.applied or VisualAlpha() or state.applied
end

-- Public adapter contract for host-owned animated surfaces. These methods are
-- deliberately informational: calling EUI's supported SetChatAlpha remains
-- the only safe way to affect the complete chat stack.
function proxy:GetFrameGambitTimingOwner()
    return "Ellesmere Chat"
end

function proxy:GetFrameGambitTimingNote()
    return "Ellesmere owns fade speed; Frame Gambit controls rule priority and wait."
end

function proxy:SetAlpha(value)
    if type(value) ~= "number" or Secret(value) or value ~= value or value < 0 or value > 1 then return end
    local _, chat = Module()
    if not chat then error("Frame Gambit could not resolve Ellesmere Chat.", 0) end
    state.applied = value
    state.guard = true
    local ok = pcall(chat.SetChatAlpha, value)
    state.guard = false
    if not ok then error("Frame Gambit could not fade Ellesmere Chat.", 0) end
end

local function Acquire(frame)
    if frame ~= proxy or not Module() or not VisualFrame() then return false end
    state.applied = VisualAlpha() or state.applied
    state.active = true
    HookAuthority()
    return true
end

local function Release(frame)
    if frame ~= proxy then
        if fallbackRelease then fallbackRelease(frame) end
        return
    end
    if frame ~= proxy or not state.active then return end
    state.active = false
    state.applied = 1
    local _, chat = Module()
    if chat and type(chat.RefreshVisibility) == "function" then
        pcall(chat.RefreshVisibility)
    elseif chat then
        pcall(chat.SetChatAlpha, 1)
    end
end

local function Install()
    local target = ns.TargetByID and ns.TargetByID.chat
    if not target or not Module() then return false end
    target.source = "Ellesmere Chat"
    target.resolve = function() return Module() and VisualFrame() and proxy or nil end
    target.acquire = Acquire
    target.release = Release
    target.skipManagedAlphaHook = true
    target.timingOwner = "host"
    target.timingLabel = "EUI fade"
    target.timingNote = proxy:GetFrameGambitTimingNote()
    target.capability = "Complete Ellesmere chat"
    target.capabilityTone = "teal"
    target.capabilityNote = "Fades Ellesmere's messages, panel, tabs, sidebar and chrome together. Ellesmere keeps styling, chat data, layout, interaction behavior, and physical fade duration."
    return true
end

Install()

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, addonName)
    if addonName ~= "EllesmereUIChat" or not Install() then return end
    if ns.RefreshOptions then ns:RefreshOptions() end
    if ns.Wake then ns:Wake() end
    if ns.IsCinematicActive and ns:IsCinematicActive() then
        -- The target may have been acquired through the Blizzard fallback
        -- before Ellesmere Chat finished loading. Swap ownership immediately
        -- so the full EUI chat surface becomes the controlled/exempt visual.
        if ns.ReconcileCinematicOwnership then ns:ReconcileCinematicOwnership() end
        if ns.Wake then ns:Wake() end
    end
end)
