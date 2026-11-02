local root = arg[1] or "Interface/AddOns/FrameGambit"
local events, timers, active, cinematic = {}, {}, nil, true
CreateFrame = function()
    local f = { RegisterEvent = function() end, RegisterUnitEvent = function() end }
    function f:SetScript(key, value) self[key] = value end
    events[#events + 1] = f
    return f
end
GetTime = function() return 1 end
InCombatLockdown = function() return false end
SlashCmdList = {}
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
hooksecurefunc = function(object, key, callback)
    local original = object[key]
    object[key] = function(...) original(...); callback(...) end
end
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/Targets.lua"))("FrameGambit", ns)
ns.IsCinematicActive = function() return cinematic end
ns.Wake = function() end
ns.InvalidateTargetTransition = function() end
local edit = { alpha = 0.35 }
ChatFrame1EditBox = edit
function edit:GetName() return "ChatFrame1EditBox" end
function edit:GetAlpha() return self.alpha end
function edit:SetAlpha(value) self.alpha = value end
function edit:IsShown() return true end
function edit:HookScript() end
ChatFrameUtil = {
    GetActiveWindow = function() return active end,
    ActivateChat = function(box) active = box; box:SetAlpha(1) end,
    DeactivateChat = function(box) active = nil; box:SetAlpha(0.35) end,
}
ChatEdit_GetActiveWindow = nil -- Forever exposes only the namespaced getter.
assert(loadfile(root .. "/CinematicChat.lua"))("FrameGambit", ns)
events[#events].OnEvent()
for _ = 1, 3 do
    ChatFrameUtil.ActivateChat(edit)
    assert(ns.runtime.cinematicChatInput and edit.alpha == 1)
    ns.runtime.cinematicOpenWindows[edit] = true
    ChatFrameUtil.DeactivateChat(edit)
    for _, callback in ipairs(timers) do callback() end
    timers = {}
    assert(not ns.runtime.cinematicChatInput)
    assert(edit.alpha == 0, "inactive IM border must disappear")
    assert(not ns.runtime.cinematicOpenWindows[edit])
end
ns:EndCinematicBlackout()
assert(edit.alpha == 0.35, "restore native inactive opacity when leaving Cinematic")
cinematic = false
ChatFrameUtil.ActivateChat(edit)
ChatFrameUtil.DeactivateChat(edit)
for _, callback in ipairs(timers) do callback() end
assert(edit.alpha == 0.35, "normal mode retains native chat behavior")
print("PASS: Forever chat send/close clears typing override and idle border; normal opacity restores")
