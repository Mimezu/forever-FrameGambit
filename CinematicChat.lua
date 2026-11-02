local ADDON, ns = ...

-- Chat input drives the public Typing condition and the default Cinematic
-- reveal when no Typing rule has been configured. It never Show/Hide's
-- chat frames directly: Core reveals the canonical Chat target, allowing the
-- Blizzard fallback or Ellesmere whole-chat adapter to retain ownership.

local hooked = false
local activateHooked = false
local deactivateHooked = false

local function Secret(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == true
end

local function ActiveEditBox()
    local getter = type(ChatFrameUtil) == "table" and ChatFrameUtil.GetActiveWindow or ChatEdit_GetActiveWindow
    if type(getter) ~= "function" then return nil, false end
    local ok, editBox = pcall(getter)
    if not ok or Secret(editBox) then return nil, false end
    return editBox, true
end

local function SetInputActive(active)
    if ns.SetCinematicChatInputActive then ns:SetCinematicChatInputActive(active) end
end

function ns:RefreshChatInput()
    local editBox, readable = ActiveEditBox()
    if not readable then return end
    if not editBox then SetInputActive(false); return end
    -- An active IM input can remain selected after focus moves elsewhere.
    -- Check actual keyboard focus; do not inspect message text or keystrokes.
    local ok, focused = pcall(function() return editBox:HasFocus() end)
    if ok and not Secret(focused) then
        SetInputActive(focused == true)
    elseif not ok then
        -- Compatibility with hosts that expose only the activation lifecycle.
        local hasMethod, method = pcall(function() return editBox.HasFocus end)
        if hasMethod and method == nil then SetInputActive(true) end
    end
end

local function OnActivated()
    SetInputActive(true)
    ns:RefreshChatInput()
end

local function OnDeactivated()
    local function ConfirmInactive()
        -- If Retail protects this value, fail visible until the next readable
        -- lifecycle signal rather than hiding chat while the player may type.
        ns:RefreshChatInput()
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, ConfirmInactive)
    else
        ConfirmInactive()
    end
end

local function HookChatLifecycle()
    if hooked or type(hooksecurefunc) ~= "function" then return hooked end
    if type(ChatFrameUtil) == "table" then
        if not activateHooked and type(ChatFrameUtil.ActivateChat) == "function" then
            activateHooked = pcall(hooksecurefunc, ChatFrameUtil, "ActivateChat", OnActivated)
        end
        if not deactivateHooked and type(ChatFrameUtil.DeactivateChat) == "function" then
            deactivateHooked = pcall(hooksecurefunc, ChatFrameUtil, "DeactivateChat", OnDeactivated)
        end
    end
    if not activateHooked and type(ChatEdit_ActivateChat) == "function" then
        activateHooked = pcall(hooksecurefunc, "ChatEdit_ActivateChat", OnActivated)
    end
    if not deactivateHooked and type(ChatEdit_DeactivateChat) == "function" then
        deactivateHooked = pcall(hooksecurefunc, "ChatEdit_DeactivateChat", OnDeactivated)
    end
    hooked = activateHooked and deactivateHooked
    ns:RefreshChatInput()
    return hooked
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function()
    HookChatLifecycle()
end)
