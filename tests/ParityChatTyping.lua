local root = arg and arg[1] or "Interface/AddOns/FrameGambit"
local drivers, timers, active, cinematic = {}, {}, nil, false
CreateFrame = function()
    local f = { RegisterEvent = function() end, RegisterUnitEvent = function() end }
    function f:SetScript(k, v) self[k] = v end
    function f:GetScript(k) return self[k] end
    drivers[#drivers + 1] = f
    return f
end
GetTime = function() return 1 end
InCombatLockdown = function() return false end
SlashCmdList = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
hooksecurefunc = function(object, name, fn)
    local old = object[name]
    object[name] = function(...) old(...); fn(...) end
end
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
ns.IsCinematicActive = function() return cinematic end
ns.Wake = function() end
ns.UpdateCinematicBlackout = function() end
ns.InvalidateTargetTransition = function() end
local settings = { enabled = true, atRest = 0.1, fadeInDuration = 0, fadeOutDuration = 0,
    fadeDelay = 0, reactions = { { id = 1, condition = "chat_typing", opacity = 0.65 } } }
FrameGambitDB = { profile = "Default", profiles = { Default = { targets = { chat = settings } } } }
local edit = { focused = false }
function edit:HasFocus() return self.focused end
ChatFrameUtil = {
    GetActiveWindow = function() return active end,
    ActivateChat = function(box) active = box; box.focused = true end,
    DeactivateChat = function(box) box.focused = false; active = nil end,
}
assert(loadfile(root .. "/CinematicChat.lua"))("FrameGambit", ns)
drivers[#drivers].OnEvent()
local function check(typing, opacity)
    ns:BuildStateContext()
    assert(ns:ConditionIsMet("chat_typing", "chat") == typing)
    assert(ns:Evaluate("chat", settings) == opacity)
end
check(false, 0.1)
ChatFrameUtil.ActivateChat(edit) -- Empty box is enough; no text access required.
check(true, 0.65)
edit.focused = false -- Active window pointer remains set after focus loss.
check(false, 0.1)
edit.focused = true
check(true, 0.65)
ChatFrameUtil.DeactivateChat(edit)
for _, fn in ipairs(timers) do fn() end
timers = {}
check(false, 0.1)
-- Switching to another whisper box during deferred deactivation stays active.
local whisper = { HasFocus = edit.HasFocus }
ChatFrameUtil.ActivateChat(edit)
ChatFrameUtil.DeactivateChat(edit)
ChatFrameUtil.ActivateChat(whisper)
for _, fn in ipairs(timers) do fn() end
check(true, 0.65)
-- User-selected opacity must also survive the Cinematic fallback override.
local f = { alpha = 1 }
function f:GetAlpha() return self.alpha end
function f:SetAlpha(a) self.alpha = a end
function f:IsShown() return true end
function f:IsProtected() return false end
ns.ResolveTarget = function() return f, { skipManagedAlphaHook = true } end
cinematic = true
ns:ApplyTarget("chat", 1)
assert(ns.runtime.active.chat.desired == 0.65)
settings.reactions = {}
ns:ApplyTarget("chat", 2)
assert(ns.runtime.active.chat.desired == 1, "default Cinematic typing reveal retained")
settings.reactions = { { id = 1, condition = "chat_typing", opacity = 0.65 } }
local parsed = assert(ns:ParseProfileImport(assert(ns:ExportProfile("Default"))))
assert(parsed.targets.chat.reactions[1].condition == "chat_typing")
assert(parsed.targets.chat.reactions[1].opacity == 0.65)
for _, key in ipairs({ "chat_typing", "chat_private", "chat_guild", "chat_group", "chat_general" }) do
    assert(ns.CONDITION_INFO[key].category == "chat")
    assert(not ns.CONDITION_INFO[key].internal)
end
-- Beyond the original twenty numbered windows: named and anonymous edit boxes.
CHAT_FRAMES = { "ChatFrame27", "AddonWhisper" }
ChatFrame27 = {}; ChatFrame27EditBox = {}
AddonWhisper = { editBox = {} }
ns.runtime.cinematicOpenWindows[ChatFrame27EditBox] = true
ns.runtime.cinematicOpenWindows[AddonWhisper.editBox] = true
ns.IsCinematicBlackoutExempt = function() return true end
ns:SetCinematicChatInputActive(false)
assert(ns.runtime.cinematicOpenWindows[ChatFrame27EditBox] == nil)
assert(ns.runtime.cinematicOpenWindows[AddonWhisper.editBox] == nil)
-- The existing evaluator owns chat audits, without a second frame tick loop.
local audits = 0
ns.RefreshChatStack = function() audits = audits + 1 end
ns:BuildStateContext()
assert(audits == 1)
print("PASS: shared chat audit and dynamic named/anonymous editbox cleanup beyond twenty windows")


